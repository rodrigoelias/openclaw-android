# Troubleshooting

Common issues and solutions when running hermes-agent on Termux via the `hermes-android` installer.

## `pip install` killed during native wheel build

```
Killed
ERROR: Could not build wheels for pydantic-core (or jiter, cryptography, ...)
```

### Cause

Android's low-memory killer terminates the Rust/clang compiler when free RAM drops too low. `pydantic-core` and `cryptography` need 1–2 GB of RAM during their compile phase.

### Solution

1. Acquire a wake lock so the kernel doesn't aggressively reclaim RAM:

   ```bash
   termux-wake-lock
   ```

2. Close other apps (Chrome, social apps).
3. Re-run the installer:

   ```bash
   ha --update
   ```

If it keeps failing, install the upstream pre-built wheels from `hermes-agent/android/wheels/` (see `hermes-agent/android/README.md`).

## `hermes` command not found

### Cause

Your shell hasn't picked up the `~/.bashrc` env block, or the symlink wasn't created.

### Solution

```bash
source ~/.bashrc
which hermes
```

If `which hermes` is empty, recreate the symlink:

```bash
ln -sf "$HOME/.hermes-android/hermes-agent/venv/bin/hermes" "$PREFIX/bin/hermes"
```

## `hermes setup` hangs at "fetching providers"

### Cause

Network blocked or PyPI unreachable.

### Solution

Check connectivity and override the PyPI mirror:

```bash
export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple/
ha --update
```

`ha --update` will cache the chosen mirror to `~/.hermes-android/.pypi-index` for future shells.

## Gateway gets killed in the background

```
sv: warning: hermes-gateway: down
```

### Cause

Android 12+ phantom-process killer or aggressive battery optimization.

### Solution

Follow the steps in [disable-phantom-process-killer.md](disable-phantom-process-killer.md). For background reliability, prefer the runit service over `hermes gateway run` in a foreground SSH session:

```bash
ha --install   # tick the "hermes-gateway runit service" option
sv up hermes-gateway
```

## SSH connection refused after Termux reopens

```
ssh: connect to host 192.168.x.y port 8022: Connection refused
```

### Cause

Termux's `sshd` doesn't autostart. Closing the app stops it.

### Solution

Add this to the bottom of `~/.bashrc` (or use `termux-services` for proper supervision):

```bash
sshd 2>/dev/null
```

Then re-open Termux, verify `pgrep sshd`, and reconnect.

See [termux-ssh-guide.md](termux-ssh-guide.md) for the full setup with key-based auth.

## "ImportError: failed to load lib" after a Python upgrade

### Cause

`pkg upgrade python` rebuilt the Python interpreter, but the venv still references the old `libpython`.

### Solution

Recreate the venv:

```bash
rm -rf ~/.hermes-android/hermes-agent/venv
ha --update
```

`ha --update` will re-run `setup-hermes.sh`, which recreates the venv against the new Python.

## `cryptography` build fails with "openssl/ssl.h not found"

### Cause

`OPENSSL_DIR` not exported, or `pkg install openssl` did not include headers.

### Solution

```bash
pkg install openssl libffi pkg-config
export OPENSSL_DIR="$PREFIX"
ha --update
```

## Backup / restore complains about `gzip: not found`

### Cause

Termux's minimal bootstrap doesn't always include `gzip`.

### Solution

```bash
pkg install gzip
ha --backup
```

## Hermes prints "no config" on first run

```
hermes: no config found at ~/.hermes/config.yaml
```

### Cause

You haven't run `hermes setup` yet (the installer doesn't run it interactively).

### Solution

```bash
hermes setup
```
