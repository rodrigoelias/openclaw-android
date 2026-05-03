# Contributing to Hermes on Android

Thanks for your interest! This repo packages [hermes-agent](https://github.com/rodrigoelias/hermes-agent) as a one-command Termux install. Contributions to the install scripts, docs, and CI are welcome.

## Where to send issues

| Type | Repo |
|---|---|
| Bug in the agent itself (LLM behavior, gateway, skills, etc.) | [hermes-agent](https://github.com/rodrigoelias/hermes-agent/issues) |
| Bug in the Termux install path (`install.sh`, `ha` CLI, ...) | this repo |
| Bug in the standalone APK | this repo (note: APK is inherited from openclaw-android and not yet adapted) |

## Development setup

### Shell scripts

```bash
git clone https://github.com/rodrigoelias/hermes-android.git
cd hermes-android

# Validate syntax
bash -n install.sh
bash -n update-core.sh
bash -n ha.sh

# Lint
shellcheck install.sh update-core.sh ha.sh bootstrap.sh uninstall.sh \
           install-tools.sh post-setup.sh \
           scripts/*.sh platforms/hermes-agent/*.sh tests/*.sh
```

Shell scripts use bash with `set -euo pipefail`, 4-space indentation, and `scripts/lib.sh` for shared functions.

### Testing the install on a real device

The fastest loop is:

1. SSH into a Termux session: `ssh -p 8022 user@phone`
2. `pkg install git curl`
3. Clone your fork: `git clone https://github.com/<you>/hermes-android.git ~/.hermes-android/installer`
4. `bash ~/.hermes-android/installer/install.sh`
5. Iterate: `git pull && bash install.sh`

A clean uninstall is `~/.hermes-android/uninstall.sh && pkg uninstall python rust clang` (the heavyweight bits) before re-running.

### Enabling git hooks

```bash
git config core.hooksPath .githooks
```

The pre-commit hook runs shellcheck on staged `.sh` files and markdownlint on `.md` files.

## Commit style

Imperative present, no prefix:

```
Fix install-python.sh missing pip ensurepip fallback
Add runit service for hermes gateway
Bump HA_VERSION to 0.1.1
```

- Capital letter, no trailing period, ≤ 50 chars on subject line.
- Body wrapped at 72 chars when needed.

## Pull requests

PR against `main`. In the description:
- What changed
- Why it's needed
- How you tested it (real Termux device strongly preferred)

## Things to keep in mind

- **No glibc / Node.js** — Hermes runs on Termux's native Bionic Python. Don't reintroduce the openclaw glibc-runner pattern.
- **Idempotent scripts** — `install.sh` and `update.sh` should be safe to re-run.
- **Long compiles** — `pydantic-core` / `cryptography` take 5–10 min to build on a phone; pre-compute timing assumptions accordingly.
- **Network resilience** — `scripts/lib.sh` includes mirror fallbacks for both GitHub raw and PyPI; use them where relevant.
- **Upstream fidelity** — When in doubt, defer to `hermes-agent`'s own `setup-hermes.sh` rather than duplicating logic here.

## License

By contributing, you agree your contributions are licensed under the MIT License (see [LICENSE](LICENSE)).
