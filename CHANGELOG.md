# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

### Added

- Initial port from [openclaw-android](https://github.com/AidanPark/openclaw-android) targeting [hermes-agent](https://github.com/rodrigoelias/hermes-agent).
- Platform: `platforms/hermes-agent/` (config + install/update/uninstall/env/status/verify).
- `scripts/install-python.sh` — installs Termux Python 3.11+ via `pkg`.
- `scripts/install-build-tools.sh` — installs Rust + clang + OpenSSL/libffi headers for compiling native Python extensions (`pydantic-core`, `cryptography`, `aiohttp`, ...).
- `scripts/install-gateway-service.sh` — configures `hermes gateway run` as a runit service via termux-services.
- `ha` CLI replacing `oa` (status / update / install / backup / restore / uninstall / version).
- `bootstrap.sh` and `post-setup.sh` updated to point at the hermes-android repo.

### Removed

- Node.js / glibc-runner stack — hermes-agent runs on Bionic-native Python; no glibc shim or wrapper script is needed.
- `platforms/openclaw/`, `scripts/install-{glibc,nodejs,chromium,code-server,opencode,playwright}.sh`, `scripts/build-sharp.sh`.
- OpenClaw-specific patches (`patches/glibc-compat.js`, `patches/argon2-stub.js`, `patches/systemctl`, `patches/spawn.h`, `patches/termux-compat.h`, `patches/glibc-libs/`).
- `tests/verify-compat.sh` — replaced with a hermes-flavoured `tests/verify-install.sh`.
- Korean / Chinese README and doc translations (not maintained for this fork).

### Notes

- The standalone Android APK (`android/`) is inherited from openclaw-android and still references OpenClaw Kotlin packages. It is **not** functional for hermes-agent yet — see `android/README.md`. The Termux install path (`bootstrap.sh` / `ha` / etc.) is the supported entry point for now.
