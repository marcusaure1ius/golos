//! Тонкая обёртка вокруг `transcribe-rs` для GigaAM-v3 ONNX.

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::time::Instant;
use transcribe_rs::SpeechModel;
use transcribe_rs::decode::{ctc_greedy_decode, sentencepiece_to_text};
use transcribe_rs::onnx::Quantization;
use transcribe_rs::onnx::gigaam::GigaAMModel;

use crate::biasing;

/// Порог уверенности для contextual biasing: средняя лог-вероятность на кадр внутри
/// интервала термина. Выше порога — термин считается «прозвучавшим» и подменяет
/// greedy-гипотезу. Значение подобрано консервативно; тюнится на реальном аудио.
const BIAS_MIN_MEAN_LOGP: f32 = -1.0;

pub struct Transcriber {
    model: GigaAMModel,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TranscribeResult {
    pub text: String,
    pub duration_ms: u64,
}

impl Transcriber {
    /// Загрузить ONNX-модель GigaAM-v3 из директории.
    pub fn load(model_dir: &Path) -> Result<Self> {
        let model = GigaAMModel::load(&PathBuf::from(model_dir), &Quantization::default())
            .with_context(|| format!("load GigaAM model from {:?}", model_dir))?;
        Ok(Self { model })
    }

    /// Транскрибировать WAV-файл (16kHz mono Int16). Блокирующий вызов.
    ///
    /// `bias_terms` — слова/фразы для contextual biasing (обычно правильные написания
    /// из пользовательского словаря). Пустой список → старый greedy-путь без изменений
    /// (нулевой риск регрессии). Непустой → декод из логитов + подмена терминов.
    pub fn transcribe_wav(&mut self, wav_path: &Path, bias_terms: &[String]) -> Result<TranscribeResult> {
        let started = Instant::now();
        let text = if bias_terms.is_empty() {
            self.model
                .transcribe_file(
                    &PathBuf::from(wav_path),
                    &transcribe_rs::TranscribeOptions::default(),
                )
                .context("transcribe_file")?
                .text
        } else {
            self.transcribe_biased(wav_path, bias_terms)?
        };
        Ok(TranscribeResult {
            text,
            duration_ms: started.elapsed().as_millis() as u64,
        })
    }

    /// Декод из сырых CTC-логитов с contextual biasing. Greedy-база идентична
    /// старому пути (те же сэмплы из `read_wav_samples`, тот же `sentencepiece_to_text`);
    /// меняются только интервалы, где уверенно «прозвучал» термин.
    fn transcribe_biased(&mut self, wav_path: &Path, bias_terms: &[String]) -> Result<String> {
        let samples = transcribe_rs::audio::read_wav_samples(wav_path).context("read_wav_samples")?;
        let log_probs = self.model.infer_log_probs(&samples).context("infer_log_probs")?;
        let num_frames = log_probs.shape()[1] as i64;
        if num_frames == 0 {
            return Ok(String::new());
        }
        let blank = self.model.blank_idx();

        // Greedy-база.
        let greedy = ctc_greedy_decode(&log_probs.view(), &[num_frames], blank);
        let greedy = &greedy[0];

        // Матрица [T, V] для споттера.
        let t = num_frames as usize;
        let v = log_probs.shape()[2];
        let mut lp: Vec<Vec<f32>> = Vec::with_capacity(t);
        for ti in 0..t {
            let mut row = Vec::with_capacity(v);
            for vi in 0..v {
                row.push(log_probs[[0, ti, vi]]);
            }
            lp.push(row);
        }

        // Ищем каждый термин; берём только уверенные споты.
        let lut = biasing::build_lookup(self.model.vocab());
        let mut spots = Vec::new();
        for term in bias_terms {
            let Some(tokens) = biasing::tokenize_term(term, &lut) else {
                tracing::info!("biasing: '{}' — не токенизируется вокабуляром, пропуск", term);
                continue;
            };
            match biasing::spot(&lp, &tokens, blank) {
                Some(sp) if sp.mean_logp >= BIAS_MIN_MEAN_LOGP => {
                    tracing::info!(
                        "biasing: '{}' — СПОТ mean_logp={:.2} кадры {}..{} (порог {:.1}) → применяю",
                        term, sp.mean_logp, sp.start_frame, sp.end_frame, BIAS_MIN_MEAN_LOGP
                    );
                    spots.push(sp);
                }
                Some(sp) => tracing::info!(
                    "biasing: '{}' — mean_logp={:.2} ниже порога {:.1}, пропуск",
                    term, sp.mean_logp, BIAS_MIN_MEAN_LOGP
                ),
                None => {}
            }
        }

        let applied = spots.len();
        let final_ids = biasing::apply(&greedy.tokens, &greedy.timestamps, spots);
        if applied > 0 {
            tracing::info!("biasing: применено спотов: {}", applied);
        }

        // id → строки токенов (фильтруем <unk>, как gigaam/mod.rs), затем в текст.
        let vocab = self.model.vocab();
        let tokens: Vec<&str> = final_ids
            .iter()
            .filter_map(|&id| {
                let idx = id as usize;
                if idx < vocab.len() && vocab[idx] != "<unk>" {
                    Some(vocab[idx].as_str())
                } else {
                    None
                }
            })
            .collect();
        Ok(sentencepiece_to_text(&tokens))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Этот тест требует реальной модели GigaAM на диске. Включается переменной окружения
    /// `GOLOS_ASR_MODEL_DIR` указывающей на распакованный ONNX-bundle. Если переменная
    /// не задана — тест пропускается (вместо false negative в CI без модели).
    #[test]
    fn transcribes_sample_with_loaded_model() {
        let model_dir = match std::env::var("GOLOS_ASR_MODEL_DIR") {
            Ok(s) => s,
            Err(_) => {
                eprintln!("skipping: GOLOS_ASR_MODEL_DIR not set");
                return;
            }
        };
        let mut t = Transcriber::load(Path::new(&model_dir))
            .expect("model should load");
        let wav = Path::new("tests/fixtures/sample_ru_short.wav");
        if !wav.exists() {
            eprintln!("skipping: fixture {:?} missing", wav);
            return;
        }
        let r = t.transcribe_wav(wav, &[]).expect("transcribe should succeed");
        assert!(!r.text.is_empty(), "non-empty text expected");
        let lower = r.text.to_lowercase();
        assert!(
            lower.contains("привет") || lower.contains("тестов") || lower.contains("запис"),
            "expected one of [привет, тестов, запис] tokens in: {:?}",
            r.text
        );
        assert!(r.duration_ms > 0);
    }

    #[test]
    fn load_returns_err_for_missing_model_dir() {
        let r = Transcriber::load(Path::new("/nonexistent/path"));
        assert!(r.is_err());
    }
}
