//! Точка входа sidecar. Аргументы: `--audio-fd <N>`. Читает stdin построчно,
//! audio-fd — бинарно (Int16 LE сэмплы). Пишет в stdout JSON-lines.

use anyhow::{anyhow, Context, Result};
use clap::Parser;
use golos_asr::audio::read_samples_le;
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
    let samples_read = Arc::new(std::sync::atomic::AtomicU64::new(0));

    // Канал, куда audio thread шлёт уведомление каждый раз, когда счётчик увеличился.
    let (samples_tx, samples_rx) = channel::<u64>();

    // 3. Отдельный тред читает audio-fd и пушит сэмплы в Session::feed_samples.
    let audio_session = Arc::clone(&session);
    let audio_counter = Arc::clone(&samples_read);
    let audio_fd = args.audio_fd;
    thread::spawn(move || {
        if let Err(e) = audio_reader_loop(audio_fd, audio_session, audio_counter, samples_tx) {
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

        // Если EndSession — ждём, что audio thread прочитал столько же сэмплов, сколько Swift послал.
        if let Request::EndSession { samples_total } = req {
            let deadline = std::time::Instant::now() + std::time::Duration::from_millis(500);
            while samples_read.load(std::sync::atomic::Ordering::SeqCst) < samples_total {
                let remaining = deadline.saturating_duration_since(std::time::Instant::now());
                if remaining.is_zero() {
                    tracing::warn!(
                        "EndSession: timed out waiting for samples; have={}, want={}",
                        samples_read.load(std::sync::atomic::Ordering::SeqCst),
                        samples_total
                    );
                    break;
                }
                match samples_rx.recv_timeout(remaining) {
                    Ok(_) => continue,
                    Err(_) => break,
                }
            }
            samples_read.store(0, std::sync::atomic::Ordering::SeqCst);
            let resp = {
                let mut s = session.lock().expect("session mutex poisoned");
                s.handle(Request::EndSession { samples_total })
            };
            write_response(&stdout, &resp)?;
            if is_shutdown { break; }
            continue;
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
    counter: Arc<std::sync::atomic::AtomicU64>,
    notify: Sender<u64>,
) -> Result<()> {
    if fd < 0 { return Err(anyhow!("invalid audio_fd: {}", fd)); }
    let mut file = unsafe { File::from_raw_fd(fd) };
    let mut buf = vec![0i16; AUDIO_CHUNK_SAMPLES];
    loop {
        let n = read_samples_le(&mut file, &mut buf).context("read audio fd")?;
        if n == 0 {
            tracing::info!("audio fd EOF");
            return Ok(());
        }
        {
            let mut s = session.lock().expect("session mutex poisoned");
            s.feed_samples(&buf[..n]);
        }
        let total = counter.fetch_add(n as u64, std::sync::atomic::Ordering::SeqCst) + n as u64;
        let _ = notify.send(total); // если receiver dropped — control loop уже не ждёт.
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

