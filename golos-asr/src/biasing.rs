//! Contextual biasing (CTC-WS-подобный) поверх CTC-логитов GigaAM.
//!
//! Идея: greedy-декод часто ломает редкие слова (имена, термины, англицизмы).
//! Мы отдельно ищем в матрице лог-вероятностей `[T, V]` заданные термины методом
//! forced-alignment подпоследовательности (Viterbi), и если термин уверенно
//! «прозвучал» на каком-то интервале кадров — подменяем им greedy-гипотезу на этом
//! интервале. Термины, которые не токенизируются вокабуляром, тихо пропускаются
//! (их закрывает детерминированный словарь замен на стороне Swift).
//!
//! Модуль не зависит от `ort`/модели — работает с готовой матрицей логитов,
//! поэтому полностью юнит-тестируется на синтетических данных.

use std::collections::HashMap;

/// Маркер начала слова в SentencePiece-вокабуляре GigaAM.
const WORD_PREFIX: char = '\u{2581}'; // ▁

/// Найденный интервал термина.
#[derive(Debug, Clone, PartialEq)]
pub struct Spot {
    /// Токены термина (id вокабуляра), которыми заменяем greedy-гипотезу.
    pub tokens: Vec<i64>,
    /// Первый и последний кадр интервала (включительно).
    pub start_frame: usize,
    pub end_frame: usize,
    /// Средняя лог-вероятность на кадр внутри интервала (мера уверенности, ≤ 0).
    pub mean_logp: f32,
}

/// Обратный индекс: строка токена → id. Строится один раз из вокабуляра.
pub fn build_lookup(vocab: &[String]) -> HashMap<String, i64> {
    vocab
        .iter()
        .enumerate()
        .map(|(i, s)| (s.clone(), i as i64))
        .collect()
}

/// Токенизировать термин в последовательность id вокабуляра (greedy longest-match,
/// как в SentencePiece). Слова разделяются пробелом → каждый начинается с `▁`.
/// Возвращает `None`, если хоть один фрагмент не покрыт вокабуляром.
pub fn tokenize_term(term: &str, lookup: &HashMap<String, i64>) -> Option<Vec<i64>> {
    // Собираем ▁-строку: "нью йорк" → "▁нью▁йорк".
    let mut s = String::new();
    for word in term.split_whitespace() {
        s.push(WORD_PREFIX);
        s.push_str(word);
    }
    if s.is_empty() {
        return None;
    }

    let chars: Vec<char> = s.chars().collect();
    let n = chars.len();
    let mut tokens = Vec::new();
    let mut i = 0;
    // Максимальная длина куска в вокабуляре редко > нескольких символов, но не
    // ограничиваем — просто идём от самого длинного префикса к короткому.
    while i < n {
        let mut matched = false;
        let mut j = n;
        while j > i {
            let piece: String = chars[i..j].iter().collect();
            if let Some(&id) = lookup.get(&piece) {
                tokens.push(id);
                i = j;
                matched = true;
                break;
            }
            j -= 1;
        }
        if !matched {
            return None; // фрагмент не покрыт вокабуляром — термин биасить нельзя
        }
    }
    Some(tokens)
}

/// Forced-alignment подпоследовательности: ищет лучший интервал кадров, на котором
/// последовательность `tokens` выравнивается по CTC поверх `log_probs [T, V]`.
///
/// «Подпоследовательность» = свободный старт (термин может начаться на любом кадре)
/// и свободный конец. Возвращает `Spot` с интервалом и средней лог-вероятностью на
/// кадр, либо `None` если кадров/токенов нет.
pub fn spot(log_probs: &[Vec<f32>], tokens: &[i64], blank: i64) -> Option<Spot> {
    let t_frames = log_probs.len();
    if t_frames == 0 || tokens.is_empty() {
        return None;
    }
    let k = tokens.len();

    // Расширенная разметка ext = [c0, blk, c1, blk, ..., c_{k-1}] — блэнки только
    // МЕЖДУ токенами (для разделения повторов). Ведущий/замыкающий блэнк не нужен,
    // т.к. ищем подстроку. Позиции чётные = токены, нечётные = блэнк.
    let ext_len = 2 * k - 1;
    let label = |s: usize| -> i64 {
        if s % 2 == 0 {
            tokens[s / 2]
        } else {
            blank
        }
    };

    let emit = |t: usize, x: i64| -> f32 { log_probs[t][x as usize] };

    const NEG: f32 = f32::NEG_INFINITY;
    // dp[s] = (лучший score пути, оканчивающегося на позиции s в текущем кадре;
    //          кадр старта этого пути).
    let mut prev: Vec<(f32, usize)> = vec![(NEG, 0); ext_len];
    let mut best: Option<(f32, usize, usize)> = None; // (score, start, end)

    for t in 0..t_frames {
        let mut cur: Vec<(f32, usize)> = vec![(NEG, 0); ext_len];
        for s in 0..ext_len {
            let x = label(s);
            let e = emit(t, x);

            // Кандидаты-предшественники (тот же кадр t-1):
            let mut bscore = NEG;
            let mut bstart = t;

            // stay на позиции s
            if prev[s].0 > NEG {
                let sc = prev[s].0 + e;
                if sc > bscore {
                    bscore = sc;
                    bstart = prev[s].1;
                }
            }
            // move с s-1
            if s >= 1 && prev[s - 1].0 > NEG {
                let sc = prev[s - 1].0 + e;
                if sc > bscore {
                    bscore = sc;
                    bstart = prev[s - 1].1;
                }
            }
            // skip с s-2 (только на токен, отличный от токена s-2)
            if s >= 2 && s % 2 == 0 && label(s) != label(s - 2) && prev[s - 2].0 > NEG {
                let sc = prev[s - 2].0 + e;
                if sc > bscore {
                    bscore = sc;
                    bstart = prev[s - 2].1;
                }
            }
            // свежий старт на первом токене (s == 0) на любом кадре
            if s == 0 {
                let sc = e;
                if sc > bscore {
                    bscore = sc;
                    bstart = t;
                }
            }

            cur[s] = (bscore, bstart);
        }

        // Завершение: путь, покрывший последний токен (позиция ext_len-1, это токен
        // c_{k-1}, т.к. ext_len нечётна). Кандидат на лучший спот, оканчивающийся на t.
        let last = ext_len - 1;
        if cur[last].0 > NEG {
            let start = cur[last].1;
            let frames = (t - start + 1) as f32;
            let mean = cur[last].0 / frames;
            match best {
                Some((bm, _, _)) if bm >= mean => {}
                _ => best = Some((mean, start, t)),
            }
        }

        prev = cur;
    }

    best.map(|(mean, start, end)| Spot {
        tokens: tokens.to_vec(),
        start_frame: start,
        end_frame: end,
        mean_logp: mean,
    })
}

/// Применить биасинг к greedy-результату.
///
/// `greedy` — токены и их кадры (как из `ctc_greedy_decode`). `spots` — найденные
/// термины (уже отфильтрованные по порогу уверенности). Термины сортируются по
/// уверенности и накладываются без пересечений (первый — самый уверенный). Токены
/// greedy, попавшие в интервал термина, заменяются токенами термина.
///
/// Возвращает финальную последовательность id токенов (для `sentencepiece_to_text`).
pub fn apply(greedy_tokens: &[i64], greedy_frames: &[i32], mut spots: Vec<Spot>) -> Vec<i64> {
    debug_assert_eq!(greedy_tokens.len(), greedy_frames.len());
    if spots.is_empty() {
        return greedy_tokens.to_vec();
    }
    // Самые уверенные — первыми; они «застолбят» свои интервалы.
    spots.sort_by(|a, b| b.mean_logp.partial_cmp(&a.mean_logp).unwrap());

    // Отбрасываем пересекающиеся по кадрам споты (жадно).
    let mut accepted: Vec<Spot> = Vec::new();
    for sp in spots {
        let overlaps = accepted.iter().any(|a| {
            sp.start_frame <= a.end_frame && a.start_frame <= sp.end_frame
        });
        if !overlaps {
            accepted.push(sp);
        }
    }
    // Для сборки идём слева направо.
    accepted.sort_by_key(|s| s.start_frame);

    let mut out: Vec<i64> = Vec::new();
    let mut gi = 0; // индекс по greedy
    for sp in &accepted {
        // Копируем greedy-токены до начала интервала (по кадру).
        while gi < greedy_tokens.len() && (greedy_frames[gi] as usize) < sp.start_frame {
            out.push(greedy_tokens[gi]);
            gi += 1;
        }
        // Вставляем токены термина.
        out.extend_from_slice(&sp.tokens);
        // Пропускаем greedy-токены внутри интервала.
        while gi < greedy_tokens.len() && (greedy_frames[gi] as usize) <= sp.end_frame {
            gi += 1;
        }
    }
    // Хвост.
    while gi < greedy_tokens.len() {
        out.push(greedy_tokens[gi]);
        gi += 1;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vocab() -> Vec<String> {
        // 0=a 1=b 2=c 3=▁ 4=blk (blank последним, как в реальном e2e_ctc)
        vec![
            "a".into(),
            "b".into(),
            "c".into(),
            "\u{2581}".into(),
            "<blk>".into(),
        ]
    }
    const BLANK: i64 = 4;

    #[test]
    fn tokenize_simple_word() {
        let lut = build_lookup(&vocab());
        // "ab" → ▁ a b
        assert_eq!(tokenize_term("ab", &lut), Some(vec![3, 0, 1]));
    }

    #[test]
    fn tokenize_phrase_two_words() {
        let lut = build_lookup(&vocab());
        // "a b" → ▁ a ▁ b
        assert_eq!(tokenize_term("a b", &lut), Some(vec![3, 0, 3, 1]));
    }

    #[test]
    fn tokenize_unknown_char_returns_none() {
        let lut = build_lookup(&vocab());
        assert_eq!(tokenize_term("az", &lut), None); // 'z' нет в вокабуляре
    }

    /// Матрица кадров: на каждом кадре пик у одного токена. Строим удобный helper.
    fn frame(peak: i64, vsize: usize) -> Vec<f32> {
        let mut f = vec![-10.0f32; vsize];
        f[peak as usize] = -0.01; // почти лог(1)
        f
    }

    #[test]
    fn spot_finds_term_in_middle() {
        let v = vocab().len();
        // Кадры: blk, a, b, blk   — термин "ab" (токены [0,1]) звучит на кадрах 1..2.
        let lp = vec![frame(BLANK, v), frame(0, v), frame(1, v), frame(BLANK, v)];
        let sp = spot(&lp, &[0, 1], BLANK).unwrap();
        assert_eq!((sp.start_frame, sp.end_frame), (1, 2));
        assert!(sp.mean_logp > -1.0, "уверенный матч, mean_logp={}", sp.mean_logp);
    }

    #[test]
    fn spot_absent_term_has_low_score() {
        let v = vocab().len();
        // Ни одного кадра с 'c' — термин [2] нигде уверенно не звучит.
        let lp = vec![frame(0, v), frame(1, v), frame(0, v)];
        let sp = spot(&lp, &[2], BLANK).unwrap();
        assert!(sp.mean_logp < -5.0, "отсутствующий термин, mean_logp={}", sp.mean_logp);
    }

    #[test]
    fn spot_handles_repeated_token_with_blank() {
        let v = vocab().len();
        // "aa" требует блэнк между повторами: a, blk, a
        let lp = vec![frame(0, v), frame(BLANK, v), frame(0, v)];
        let sp = spot(&lp, &[0, 0], BLANK).unwrap();
        assert_eq!((sp.start_frame, sp.end_frame), (0, 2));
        assert!(sp.mean_logp > -1.0);
    }

    #[test]
    fn apply_splices_term_over_greedy_span() {
        // greedy выдал [c] на кадре 1 (id2), а термин "ab" ([0,1]) звучит на кадрах 1..2.
        let greedy_tokens = vec![2i64];
        let greedy_frames = vec![1i32];
        let sp = Spot { tokens: vec![0, 1], start_frame: 1, end_frame: 2, mean_logp: -0.1 };
        let out = apply(&greedy_tokens, &greedy_frames, vec![sp]);
        assert_eq!(out, vec![0, 1]); // 'c' заменён на "ab"
    }

    #[test]
    fn apply_preserves_tokens_outside_span() {
        // greedy: [a@0, c@2, b@5]; термин звучит на кадрах 2..3 → заменяет только c@2.
        let greedy_tokens = vec![0i64, 2, 1];
        let greedy_frames = vec![0i32, 2, 5];
        let sp = Spot { tokens: vec![0, 0], start_frame: 2, end_frame: 3, mean_logp: -0.1 };
        let out = apply(&greedy_tokens, &greedy_frames, vec![sp]);
        assert_eq!(out, vec![0, 0, 0, 1]); // a, (aa вместо c), b
    }

    #[test]
    fn apply_drops_overlapping_lower_confidence_spot() {
        let greedy_tokens = vec![2i64];
        let greedy_frames = vec![1i32];
        let strong = Spot { tokens: vec![0], start_frame: 1, end_frame: 2, mean_logp: -0.1 };
        let weak = Spot { tokens: vec![1], start_frame: 2, end_frame: 3, mean_logp: -0.5 };
        let out = apply(&greedy_tokens, &greedy_frames, vec![weak, strong]);
        assert_eq!(out, vec![0]); // победил уверенный, пересекающийся отброшен
    }

    #[test]
    fn apply_without_spots_is_identity() {
        let out = apply(&[0, 1, 2], &[0, 1, 2], vec![]);
        assert_eq!(out, vec![0, 1, 2]);
    }
}
