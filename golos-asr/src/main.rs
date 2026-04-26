//! Точка входа sidecar. Аргументы: `--audio-fd <N>`. Читает stdin построчно,
//! audio-fd — бинарно (Int16 LE сэмплы). Пишет в stdout JSON-lines.

use anyhow::{anyhow, Context, Result};
use clap::Parser;
use golos_asr::audio::{read_samples_le, AudioBuffer};
use golos_asr::protocol::{Request, Response};
use golos_asr::session::Session;
use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::os::fd::FromRawFd;
use std::os::unix::io::RawFd;
use std::sync::mpsc::{channel, Sender};
use std::sync::{Arc, Mutex};
use std::thread;

#[derive(Parser, Debug)]
#[command(version, about = "GigaAM-v3 transcription sidecar for golos.app")]
struct Args {
    /// Файловый дескриптор для бинарного потока PCM (Int16 LE, 16kHz mono).
    #[arg(long)]
    audio_fd: RawFd,
}

const AUDIO_CHUNK_SAMPLES: usize = 1600; // ~100ms @16kHz
const _: () = assert!(AUDIO_CHUNK_SAMPLES > 0);

fn main() -> Result<()> {
    init_logging();
    let args = Args::parse();
    tracing::info!("golos-asr starting (audio_fd={})", args.audio_fd);

    // 1. Стандартный output — наш канал ответов. Заворачиваем в Mutex,
    //    чтобы оба треда (main и audio-reader) могли писать.
    let stdout = Arc::new(Mutex::new(std::io::stdout()));
    write_response(&stdout, &Response::Hello {
        version: env!("CARGO_PKG_VERSION").into(),
    })?;

    // 2. Сессия + общий ресурс между audio thread и control loop.
    let session = Arc::new(Mutex::new(Session::new()?));

    // 3. Отдельный тред читает audio-fd и пушит сэмплы в Session::feed_samples.
    let audio_session = Arc::clone(&session);
    let (audio_done_tx, _audio_done_rx) = channel::<()>();
    let audio_fd = args.audio_fd;
    thread::spawn(move || {
        if let Err(e) = audio_reader_loop(audio_fd, audio_session, audio_done_tx) {
            tracing::error!("audio reader exited with error: {:#}", e);
        }
    });

    // 4. Основной цикл — читаем stdin построчно, обрабатываем control messages.
    let stdin = std::io::stdin();
    let reader = BufReader::new(stdin.lock());
    for line in reader.lines() {
        let line = line.context("read stdin line")?;
        if line.trim().is_empty() { continue; }

        let req: Request = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                write_response(&stdout, &Response::Error {
                    kind: "bad_request".into(),
                    message: format!("invalid JSON: {}", e),
                })?;
                continue;
            }
        };

        let is_shutdown = matches!(req, Request::Shutdown);
        // EndSession: дать audio thread шанс прокачать оставшиеся байты из pipe.
        // Без этого race — sidecar финализирует с пустым buffer'ом раньше, чем
        // audio thread успевает прочитать всё, что Swift app записал в pipe.
        if matches!(req, Request::EndSession) {
            std::thread::sleep(std::time::Duration::from_millis(200));
        }
        let resp = {
            let mut s = session.lock().expect("session mutex poisoned");
            s.handle(req)
        };
        write_response(&stdout, &resp)?;
        if is_shutdown { break; }
    }

    tracing::info!("golos-asr exiting");
    Ok(())
}

fn audio_reader_loop(
    fd: RawFd,
    session: Arc<Mutex<Session>>,
    _done: Sender<()>,
) -> Result<()> {
    if fd < 0 {
        return Err(anyhow!("invalid audio_fd: {}", fd));
    }
    // SAFETY: caller (Swift app) гарантирует, что fd валиден до завершения процесса.
    let mut file = unsafe { File::from_raw_fd(fd) };
    let mut buf = vec![0i16; AUDIO_CHUNK_SAMPLES];
    loop {
        let n = read_samples_le(&mut file, &mut buf).context("read audio fd")?;
        if n == 0 {
            tracing::info!("audio fd EOF");
            return Ok(());
        }
        let mut s = session.lock().expect("session mutex poisoned");
        s.feed_samples(&buf[..n]);
    }
}

fn write_response(
    stdout: &Arc<Mutex<std::io::Stdout>>,
    resp: &Response,
) -> Result<()> {
    let line = resp.to_line();
    let mut out = stdout.lock().expect("stdout mutex poisoned");
    out.write_all(line.as_bytes()).context("write stdout")?;
    out.flush().context("flush stdout")?;
    Ok(())
}

fn init_logging() {
    use tracing_subscriber::EnvFilter;
    tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_env_filter(EnvFilter::try_from_env("GOLOS_ASR_LOG")
            .unwrap_or_else(|_| EnvFilter::new("info")))
        .init();
}

// Заглушка — для совместимости с _ в audio_done_rx (который мы не читаем,
// но создан, чтобы tx не дропался преждевременно).
#[allow(dead_code)]
fn _silence_unused() {}
