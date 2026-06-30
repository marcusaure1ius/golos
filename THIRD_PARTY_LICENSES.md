# Third-Party Licenses

`golos` (the macOS app) and `golos-asr` (the ASR sidecar) bundle and link the
third-party components listed below. golos itself is MIT-licensed (see [LICENSE](LICENSE)).
All third-party components are distributed under permissive licenses
(MIT, Apache-2.0, ISC, Zlib, Unicode-3.0, CDLA-Permissive-2.0) compatible with this project.

## Bundled binary

### ONNX Runtime

The sidecar links a prebuilt **ONNX Runtime** binary, downloaded at build time by
`ort-sys` from the [pyke](https://github.com/pykeio/ort) distribution.
ONNX Runtime is Copyright (c) Microsoft Corporation, licensed under the **MIT License**.
Its NOTICE and license text must accompany binary distributions (e.g. the .dmg).
Source: https://github.com/microsoft/onnxruntime

## Speech model

GigaAM-v3 weights are **not** bundled in this repository; they are downloaded on first
run. The model is published by **SaluteDevices** (Sber) under the **MIT License**
(https://github.com/salute-developers/GigaAM). The weights are fetched in ONNX form from
a third-party MIT-licensed conversion, https://huggingface.co/istupakov/gigaam-v3-onnx,
which attributes the original. MIT permits commercial use and redistribution with
attribution retained.

## Rust crates

The Rust sidecar depends on 149 transitive crates:

| Crate | Version | License | Source |
|-------|---------|---------|--------|
| `aho-corasick` | 1.1.4 | Unlicense OR MIT | [link](https://github.com/BurntSushi/aho-corasick) |
| `anstream` | 1.0.0 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/anstyle.git) |
| `anstyle` | 1.0.14 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/anstyle.git) |
| `anstyle-parse` | 1.0.0 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/anstyle.git) |
| `anstyle-query` | 1.1.5 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/anstyle.git) |
| `anstyle-wincon` | 3.0.11 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/anstyle.git) |
| `anyhow` | 1.0.102 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/anyhow) |
| `autocfg` | 1.5.0 | Apache-2.0 OR MIT | [link](https://github.com/cuviper/autocfg) |
| `base64` | 0.22.1 | MIT OR Apache-2.0 | [link](https://github.com/marshallpierce/rust-base64) |
| `base64ct` | 1.8.3 | Apache-2.0 OR MIT | [link](https://github.com/RustCrypto/formats) |
| `bitflags` | 2.11.1 | MIT OR Apache-2.0 | [link](https://github.com/bitflags/bitflags) |
| `byteorder` | 1.5.0 | Unlicense OR MIT | [link](https://github.com/BurntSushi/byteorder) |
| `bytes` | 1.11.1 | MIT | [link](https://github.com/tokio-rs/bytes) |
| `cc` | 1.2.61 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/cc-rs) |
| `cfg-if` | 1.0.4 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/cfg-if) |
| `clap` | 4.6.1 | MIT OR Apache-2.0 | [link](https://github.com/clap-rs/clap) |
| `clap_builder` | 4.6.0 | MIT OR Apache-2.0 | [link](https://github.com/clap-rs/clap) |
| `clap_derive` | 4.6.1 | MIT OR Apache-2.0 | [link](https://github.com/clap-rs/clap) |
| `clap_lex` | 1.1.0 | MIT OR Apache-2.0 | [link](https://github.com/clap-rs/clap) |
| `colorchoice` | 1.0.5 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/anstyle.git) |
| `core-foundation` | 0.10.1 | MIT OR Apache-2.0 | [link](https://github.com/servo/core-foundation-rs) |
| `core-foundation-sys` | 0.8.7 | MIT OR Apache-2.0 | [link](https://github.com/servo/core-foundation-rs) |
| `darling` | 0.20.11 | MIT | [link](https://github.com/TedDriggs/darling) |
| `darling_core` | 0.20.11 | MIT | [link](https://github.com/TedDriggs/darling) |
| `darling_macro` | 0.20.11 | MIT | [link](https://github.com/TedDriggs/darling) |
| `der` | 0.8.0 | Apache-2.0 OR MIT | [link](https://github.com/RustCrypto/formats) |
| `derive_builder` | 0.20.2 | MIT OR Apache-2.0 | [link](https://github.com/colin-kiegel/rust-derive-builder) |
| `derive_builder_core` | 0.20.2 | MIT OR Apache-2.0 | [link](https://github.com/colin-kiegel/rust-derive-builder) |
| `derive_builder_macro` | 0.20.2 | MIT OR Apache-2.0 | [link](https://github.com/colin-kiegel/rust-derive-builder) |
| `env_logger` | 0.10.2 | MIT OR Apache-2.0 | [link](https://github.com/rust-cli/env_logger) |
| `equivalent` | 1.0.2 | Apache-2.0 OR MIT | [link](https://github.com/indexmap-rs/equivalent) |
| `errno` | 0.3.14 | MIT OR Apache-2.0 | [link](https://github.com/lambda-fairy/rust-errno) |
| `fastrand` | 2.4.1 | Apache-2.0 OR MIT | [link](https://github.com/smol-rs/fastrand) |
| `find-msvc-tools` | 0.1.9 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/cc-rs) |
| `fnv` | 1.0.7 | Apache-2.0 / MIT | [link](https://github.com/servo/rust-fnv) |
| `foldhash` | 0.1.5 | Zlib | [link](https://github.com/orlp/foldhash) |
| `foreign-types` | 0.3.2 | MIT/Apache-2.0 | [link](https://github.com/sfackler/foreign-types) |
| `foreign-types-shared` | 0.1.1 | MIT/Apache-2.0 | [link](https://github.com/sfackler/foreign-types) |
| `getrandom` | 0.4.2 | MIT OR Apache-2.0 | [link](https://github.com/rust-random/getrandom) |
| `hashbrown` | 0.15.5 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/hashbrown) |
| `heck` | 0.5.0 | MIT OR Apache-2.0 | [link](https://github.com/withoutboats/heck) |
| `hermit-abi` | 0.5.2 | MIT OR Apache-2.0 | [link](https://github.com/hermit-os/hermit-rs) |
| `hmac-sha256` | 1.1.14 | ISC | [link](https://github.com/jedisct1/rust-hmac-sha256) |
| `hound` | 3.5.1 | Apache-2.0 | [link](https://github.com/ruuda/hound) |
| `http` | 1.4.0 | MIT OR Apache-2.0 | [link](https://github.com/hyperium/http) |
| `httparse` | 1.10.1 | MIT OR Apache-2.0 | [link](https://github.com/seanmonstar/httparse) |
| `humantime` | 2.3.0 | MIT OR Apache-2.0 | [link](https://github.com/chronotope/humantime) |
| `id-arena` | 2.3.0 | MIT/Apache-2.0 | [link](https://github.com/fitzgen/id-arena) |
| `ident_case` | 1.0.1 | MIT/Apache-2.0 | [link](https://github.com/TedDriggs/ident_case) |
| `indexmap` | 2.14.0 | Apache-2.0 OR MIT | [link](https://github.com/indexmap-rs/indexmap) |
| `is-terminal` | 0.4.17 | MIT | [link](https://github.com/sunfishcode/is-terminal) |
| `is_terminal_polyfill` | 1.70.2 | MIT OR Apache-2.0 | [link](https://github.com/polyfill-rs/is_terminal_polyfill) |
| `itoa` | 1.0.18 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/itoa) |
| `lazy_static` | 1.5.0 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang-nursery/lazy-static.rs) |
| `leb128fmt` | 0.1.0 | MIT OR Apache-2.0 | [link](https://github.com/bluk/leb128fmt) |
| `libc` | 0.2.186 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/libc) |
| `linux-raw-sys` | 0.12.1 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/sunfishcode/linux-raw-sys) |
| `log` | 0.4.29 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/log) |
| `lzma-rust2` | 0.15.7 | Apache-2.0 | [link](https://github.com/hasenbanck/lzma-rust2/) |
| `matchers` | 0.2.0 | MIT | [link](https://github.com/hawkw/matchers) |
| `matrixmultiply` | 0.3.10 | MIT/Apache-2.0 | [link](https://github.com/bluss/matrixmultiply/) |
| `memchr` | 2.8.0 | Unlicense OR MIT | [link](https://github.com/BurntSushi/memchr) |
| `native-tls` | 0.2.18 | MIT OR Apache-2.0 | [link](https://github.com/rust-native-tls/rust-native-tls) |
| `ndarray` | 0.17.2 | MIT OR Apache-2.0 | [link](https://github.com/rust-ndarray/ndarray) |
| `nu-ansi-term` | 0.50.3 | MIT | [link](https://github.com/nushell/nu-ansi-term) |
| `num-complex` | 0.4.6 | MIT OR Apache-2.0 | [link](https://github.com/rust-num/num-complex) |
| `num-integer` | 0.1.46 | MIT OR Apache-2.0 | [link](https://github.com/rust-num/num-integer) |
| `num-traits` | 0.2.19 | MIT OR Apache-2.0 | [link](https://github.com/rust-num/num-traits) |
| `once_cell` | 1.21.4 | MIT OR Apache-2.0 | [link](https://github.com/matklad/once_cell) |
| `once_cell_polyfill` | 1.70.2 | MIT OR Apache-2.0 | [link](https://github.com/polyfill-rs/once_cell_polyfill) |
| `openssl` | 0.10.78 | Apache-2.0 | [link](https://github.com/rust-openssl/rust-openssl) |
| `openssl-macros` | 0.1.1 | MIT/Apache-2.0 | — |
| `openssl-probe` | 0.2.1 | MIT OR Apache-2.0 | [link](https://github.com/rustls/openssl-probe) |
| `openssl-sys` | 0.9.114 | MIT | [link](https://github.com/rust-openssl/rust-openssl) |
| `ort` | 2.0.0-rc.12 | MIT OR Apache-2.0 | [link](https://github.com/pykeio/ort) |
| `ort-sys` | 2.0.0-rc.12 | MIT OR Apache-2.0 | [link](https://github.com/pykeio/ort) |
| `pem-rfc7468` | 1.0.0 | Apache-2.0 OR MIT | [link](https://github.com/RustCrypto/formats) |
| `percent-encoding` | 2.3.2 | MIT OR Apache-2.0 | [link](https://github.com/servo/rust-url/) |
| `pin-project-lite` | 0.2.17 | Apache-2.0 OR MIT | [link](https://github.com/taiki-e/pin-project-lite) |
| `pkg-config` | 0.3.33 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/pkg-config-rs) |
| `portable-atomic` | 1.13.1 | Apache-2.0 OR MIT | [link](https://github.com/taiki-e/portable-atomic) |
| `portable-atomic-util` | 0.2.7 | Apache-2.0 OR MIT | [link](https://github.com/taiki-e/portable-atomic-util) |
| `prettyplease` | 0.2.37 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/prettyplease) |
| `primal-check` | 0.3.4 | MIT OR Apache-2.0 | [link](https://github.com/huonw/primal) |
| `proc-macro2` | 1.0.106 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/proc-macro2) |
| `quote` | 1.0.45 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/quote) |
| `r-efi` | 6.0.0 | MIT OR Apache-2.0 OR LGPL-2.1-or-later | [link](https://github.com/r-efi/r-efi) |
| `rawpointer` | 0.2.1 | MIT/Apache-2.0 | [link](https://github.com/bluss/rawpointer/) |
| `regex` | 1.12.3 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/regex) |
| `regex-automata` | 0.4.14 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/regex) |
| `regex-syntax` | 0.8.10 | MIT OR Apache-2.0 | [link](https://github.com/rust-lang/regex) |
| `rustfft` | 6.4.1 | MIT OR Apache-2.0 | [link](https://github.com/ejmahler/RustFFT) |
| `rustix` | 1.1.4 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/rustix) |
| `rustls-pki-types` | 1.14.1 | MIT OR Apache-2.0 | [link](https://github.com/rustls/pki-types) |
| `schannel` | 0.1.29 | MIT | [link](https://github.com/steffengy/schannel-rs) |
| `security-framework` | 3.7.0 | MIT OR Apache-2.0 | [link](https://github.com/kornelski/rust-security-framework) |
| `security-framework-sys` | 2.17.0 | MIT OR Apache-2.0 | [link](https://github.com/kornelski/rust-security-framework) |
| `semver` | 1.0.28 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/semver) |
| `serde` | 1.0.228 | MIT OR Apache-2.0 | [link](https://github.com/serde-rs/serde) |
| `serde_core` | 1.0.228 | MIT OR Apache-2.0 | [link](https://github.com/serde-rs/serde) |
| `serde_derive` | 1.0.228 | MIT OR Apache-2.0 | [link](https://github.com/serde-rs/serde) |
| `serde_json` | 1.0.149 | MIT OR Apache-2.0 | [link](https://github.com/serde-rs/json) |
| `sharded-slab` | 0.1.7 | MIT | [link](https://github.com/hawkw/sharded-slab) |
| `shlex` | 1.3.0 | MIT OR Apache-2.0 | [link](https://github.com/comex/rust-shlex) |
| `smallvec` | 1.15.1 | MIT OR Apache-2.0 | [link](https://github.com/servo/rust-smallvec) |
| `socks` | 0.3.4 | MIT/Apache-2.0 | [link](https://github.com/sfackler/rust-socks) |
| `strength_reduce` | 0.2.4 | MIT OR Apache-2.0 | [link](http://github.com/ejmahler/strength_reduce) |
| `strsim` | 0.11.1 | MIT | [link](https://github.com/rapidfuzz/strsim-rs) |
| `syn` | 2.0.117 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/syn) |
| `tempfile` | 3.27.0 | MIT OR Apache-2.0 | [link](https://github.com/Stebalien/tempfile) |
| `termcolor` | 1.4.1 | Unlicense OR MIT | [link](https://github.com/BurntSushi/termcolor) |
| `thiserror` | 1.0.69 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/thiserror) |
| `thiserror-impl` | 1.0.69 | MIT OR Apache-2.0 | [link](https://github.com/dtolnay/thiserror) |
| `thread_local` | 1.1.9 | MIT OR Apache-2.0 | [link](https://github.com/Amanieu/thread_local-rs) |
| `tracing` | 0.1.44 | MIT | [link](https://github.com/tokio-rs/tracing) |
| `tracing-attributes` | 0.1.31 | MIT | [link](https://github.com/tokio-rs/tracing) |
| `tracing-core` | 0.1.36 | MIT | [link](https://github.com/tokio-rs/tracing) |
| `tracing-log` | 0.2.0 | MIT | [link](https://github.com/tokio-rs/tracing) |
| `tracing-subscriber` | 0.3.23 | MIT | [link](https://github.com/tokio-rs/tracing) |
| `transcribe-rs` | 0.3.11 | MIT | [link](https://github.com/cjpais/transcribe-rs) |
| `transpose` | 0.2.3 | MIT OR Apache-2.0 | [link](https://github.com/ejmahler/transpose) |
| `unicode-ident` | 1.0.24 | (MIT OR Apache-2.0) AND Unicode-3.0 | [link](https://github.com/dtolnay/unicode-ident) |
| `unicode-xid` | 0.2.6 | MIT OR Apache-2.0 | [link](https://github.com/unicode-rs/unicode-xid) |
| `ureq` | 3.3.0 | MIT OR Apache-2.0 | [link](https://github.com/algesten/ureq) |
| `ureq-proto` | 0.6.0 | MIT OR Apache-2.0 | [link](https://github.com/algesten/ureq-proto) |
| `utf8-zero` | 0.8.1 | MIT OR Apache-2.0 | [link](https://github.com/algesten/utf8-zero) |
| `utf8parse` | 0.2.2 | Apache-2.0 OR MIT | [link](https://github.com/alacritty/vte) |
| `valuable` | 0.1.1 | MIT | [link](https://github.com/tokio-rs/valuable) |
| `vcpkg` | 0.2.15 | MIT/Apache-2.0 | [link](https://github.com/mcgoo/vcpkg-rs) |
| `wasip2` | 1.0.3+wasi-0.2.9 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasi-rs) |
| `wasip3` | 0.4.0+wasi-0.3.0-rc-2026-01-06 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasi-rs) |
| `wasm-encoder` | 0.244.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasm-encoder) |
| `wasm-metadata` | 0.244.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasm-metadata) |
| `wasmparser` | 0.244.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasmparser) |
| `webpki-root-certs` | 1.0.7 | CDLA-Permissive-2.0 | [link](https://github.com/rustls/webpki-roots) |
| `winapi` | 0.3.9 | MIT/Apache-2.0 | [link](https://github.com/retep998/winapi-rs) |
| `winapi-i686-pc-windows-gnu` | 0.4.0 | MIT/Apache-2.0 | [link](https://github.com/retep998/winapi-rs) |
| `winapi-util` | 0.1.11 | Unlicense OR MIT | [link](https://github.com/BurntSushi/winapi-util) |
| `winapi-x86_64-pc-windows-gnu` | 0.4.0 | MIT/Apache-2.0 | [link](https://github.com/retep998/winapi-rs) |
| `windows-link` | 0.2.1 | MIT OR Apache-2.0 | [link](https://github.com/microsoft/windows-rs) |
| `windows-sys` | 0.61.2 | MIT OR Apache-2.0 | [link](https://github.com/microsoft/windows-rs) |
| `wit-bindgen` | 0.51.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wit-bindgen) |
| `wit-bindgen-core` | 0.51.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wit-bindgen) |
| `wit-bindgen-rust` | 0.51.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wit-bindgen) |
| `wit-bindgen-rust-macro` | 0.51.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wit-bindgen) |
| `wit-component` | 0.244.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wit-component) |
| `wit-parser` | 0.244.0 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | [link](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wit-parser) |
| `zeroize` | 1.8.2 | Apache-2.0 OR MIT | [link](https://github.com/RustCrypto/utils) |
| `zmij` | 1.0.21 | MIT | [link](https://github.com/dtolnay/zmij) |

> Generated from `cargo metadata`. To regenerate with full license texts, use
> [`cargo-about`](https://github.com/EmbarkStudios/cargo-about) or
> [`cargo-bundle-licenses`](https://github.com/sstadick/cargo-bundle-licenses).
