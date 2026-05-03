# Hermes on Android

![Android 7.0+](https://img.shields.io/badge/Android-7.0%2B-brightgreen)
![Termux](https://img.shields.io/badge/Termux-Required-orange)
![Python 3.11+](https://img.shields.io/badge/Python-3.11%2B-blue)
![License MIT](https://img.shields.io/badge/license-MIT-blue)

Run **[hermes-agent](https://github.com/rodrigoelias/hermes-agent)** natively on Android via Termux — no proot, no emulation. The installer wraps `setup-hermes.sh` from upstream, adds Android-specific build env, and provides a single `ha` CLI for status / update / backup.

## Why this exists

`hermes-agent` already ships its own Termux setup (`setup-hermes.sh` and `android/install.sh`), but you still have to:

1. Install Termux from F-Droid
2. Run `pkg update && pkg upgrade`
3. Install `python`, `git`, `rust`, `clang`, `openssl`, `libffi`, `pkg-config`, ...
4. Clone `hermes-agent`
5. Set `OPENSSL_DIR`, `ANDROID_API_LEVEL`
6. Run `setup-hermes.sh` and hope nothing fails halfway through
7. Wire up a runit service if you want the gateway in the background

This repo turns all of that into a single `curl | bash`. It mirrors the architecture of [openclaw-android](https://github.com/AidanPark/openclaw-android) — platform-aware orchestrators, mirror fallbacks for restricted networks, a `ha` management CLI — but for the Python-native hermes-agent stack instead of the Node.js/glibc OpenClaw stack.

## Architecture

```
┌───────────────────────────────────────────────────┐
│ Linux Kernel                                      │
│ ┌───────────────────────────────────────────────┐ │
│ │ Android · Bionic libc · Termux                │ │
│ │ ┌───────────────────────────────────────────┐ │ │
│ │ │ Termux Python (Bionic-native, no glibc)   │ │ │
│ │ │   venv → hermes-agent                     │ │ │
│ │ │   pip install -e .[termux]                │ │ │
│ │ │   constraints-termux.txt                  │ │ │
│ │ └───────────────────────────────────────────┘ │ │
│ └───────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────┘
```

Hermes-agent is pure Python (with native extensions like `pydantic-core`, `cryptography`, `aiohttp`). On Termux these are compiled from source against Bionic — the installer pulls in `rust + clang + openssl + libffi` via `pkg` and lets `setup-hermes.sh` do the rest.

## Requirements

- Android 7.0 or higher (Android 10+ recommended)
- ~2GB free storage (build toolchain + venv + native wheels)
- Wi-Fi or mobile data connection
- Termux from [F-Droid](https://f-droid.org/packages/com.termux/) — **not** the outdated Google Play version

## Quick install

In Termux:

```bash
curl -sL https://raw.githubusercontent.com/rodrigoelias/hermes-android/main/bootstrap.sh | bash
```

This downloads the installer, installs Python + the build toolchain, clones `hermes-agent`, and runs `setup-hermes.sh`. First-run takes 5–15 minutes (mostly Rust compiling `pydantic-core`).

When it finishes:

```bash
hermes setup    # configure API keys
hermes          # start chatting
```

## What gets installed

| Component | Where | Purpose |
|---|---|---|
| Termux Python 3.11+ | `$PREFIX/bin/python` | runtime |
| Build toolchain | `$PREFIX/bin/{rustc,clang,...}` | compile native wheels |
| `hermes-agent` repo | `~/.hermes-android/hermes-agent` | source checkout |
| Python venv | `~/.hermes-android/hermes-agent/venv` | isolated deps |
| `hermes` CLI | `$PREFIX/bin/hermes` (symlink → venv) | user entry point |
| `ha` CLI | `$PREFIX/bin/ha` | management (update / status / backup) |
| `haupdate` | `$PREFIX/bin/haupdate` | update wrapper |
| Hermes data | `~/.hermes/` | config, memory, skills, sessions |
| Optional: `hermes-gateway` runit service | `$PREFIX/var/service/hermes-gateway` | background gateway |

## The `ha` CLI

```
ha --status         Show installed components, versions, repo HEAD
ha --update         Pull latest hermes-agent + hermes-android scripts
ha --install        Install optional tools (tmux, ttyd, gateway service, ...)
ha --backup         Tar up ~/.hermes/ to ~/.hermes-android/backup/
ha --restore        Restore from a previous backup
ha --uninstall      Remove everything (asks before deleting ~/.hermes)
ha --version        Show version + check for updates
```

## Step-by-step setup

### 1. Install Termux

Install [Termux](https://f-droid.org/packages/com.termux/) from F-Droid.

Optional but recommended: disable Android's phantom process killer so the gateway doesn't get nuked. See [docs/disable-phantom-process-killer.md](docs/disable-phantom-process-killer.md).

### 2. Initial Termux setup

```bash
termux-change-repo    # pick a fast mirror near you
pkg update && pkg upgrade
pkg install curl
```

### 3. Install Hermes

```bash
curl -sL https://raw.githubusercontent.com/rodrigoelias/hermes-android/main/bootstrap.sh | bash
```

The installer is interactive — it asks about optional tools (tmux, ttyd, runit service for the gateway, etc.). You can accept all defaults safely.

### 4. Configure API keys

```bash
hermes setup
```

This is upstream `hermes setup` — it walks you through provider selection (OpenAI, Anthropic, OpenRouter, Gemini, ...) and writes `~/.hermes/config.yaml`.

### 5. Start chatting

```bash
hermes                    # interactive TUI
```

Or run the messaging gateway (Telegram / Discord / Slack / Matrix):

```bash
hermes gateway run        # foreground
sv up hermes-gateway      # if you installed the runit service
```

## Updating

```bash
ha --update
```

This pulls the latest `hermes-android` scripts and the latest `hermes-agent` from upstream, then re-runs `pip install -e .[termux]` to pick up new dependencies.

## Uninstalling

```bash
ha --uninstall
```

Or directly:

```bash
~/.hermes-android/uninstall.sh
```

## SSH access from your Mac/PC

```bash
# In Termux:
pkg install openssh
passwd            # set a password
sshd              # start the daemon (port 8022 by default)
ifconfig wlan0    # find your phone's IP

# From your Mac/PC:
ssh -p 8022 <user>@<phone-ip>
```

See [docs/termux-ssh-guide.md](docs/termux-ssh-guide.md) for keys / autostart.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues.

Two crashes that are worth knowing about up front:

- **`pip install` killed (signal 9) during `pydantic-core` build** — Android's low-memory killer. Run `termux-wake-lock` first, close Chrome, retry.
- **`hermes` not found after install** — your `.bashrc` wasn't reloaded. Run `source ~/.bashrc` or open a new Termux session.

## Repository layout

```
hermes-android/
├── bootstrap.sh                  # curl|bash entry point
├── install.sh                    # main installer (8 steps)
├── ha.sh                         # management CLI
├── update.sh / update-core.sh    # update entry + core
├── uninstall.sh                  # uninstaller
├── post-setup.sh                 # standalone bootstrap (used by APK)
├── install-tools.sh              # optional tools installer
├── platforms/hermes-agent/       # platform-specific install/update/...
│   ├── config.env                # platform metadata (NEEDS_PYTHON, etc.)
│   ├── install.sh                # clone repo + run setup-hermes.sh
│   ├── update.sh                 # git pull + pip install --upgrade
│   ├── uninstall.sh              # remove repo, venv, symlinks
│   ├── env.sh                    # exported env vars (HERMES_HOME)
│   ├── status.sh                 # status detail (versions, paths)
│   └── verify.sh                 # post-install sanity checks
├── scripts/
│   ├── lib.sh                    # shared functions, constants
│   ├── check-env.sh              # Termux + arch + disk check
│   ├── setup-paths.sh            # mkdir tmp + project dir
│   ├── setup-env.sh              # write .bashrc env block
│   ├── install-infra-deps.sh     # curl + git + openssh
│   ├── install-python.sh         # pkg install python
│   ├── install-build-tools.sh    # rust + clang + openssl headers
│   ├── install-gateway-service.sh # configure runit service
│   └── backup.sh                 # backup/restore for ~/.hermes
├── tests/
│   └── verify-install.sh         # post-install verification
├── docs/                         # user-facing docs
├── android/                      # standalone APK (Kotlin) — see android/README.md
└── .github/workflows/            # CI: shellcheck, ktlint, APK build
```

## Relationship to upstream

- This repo wraps [`rodrigoelias/hermes-agent`](https://github.com/rodrigoelias/hermes-agent) — the actual agent code lives there.
- The architecture is modeled on [`AidanPark/openclaw-android`](https://github.com/AidanPark/openclaw-android) — same orchestrator pattern, simpler runtime stack (Python on Bionic, no glibc/Node.js).
- Bug reports for hermes itself → [hermes-agent issues](https://github.com/rodrigoelias/hermes-agent/issues). Bug reports for the Android install path → this repo.

## Status

Early. The install / update / uninstall flow works. The standalone APK (`android/`) is inherited from openclaw-android and has not yet been adapted to bundle hermes-agent (see `android/README.md` for current state).

## License

MIT — see [LICENSE](LICENSE).
