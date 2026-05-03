# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do NOT open a public GitHub issue for security vulnerabilities.**

Instead, report them via [GitHub Security Advisories](https://github.com/rodrigoelias/hermes-android/security/advisories/new).

### What to include

- Description of the vulnerability
- Steps to reproduce
- Impact assessment
- Suggested fix (if any)

### Response timeline

- **Acknowledgment**: within 48 hours
- **Assessment**: within 1 week
- **Fix**: within 2 weeks for critical issues

## Scope

This repository contains:

- Shell scripts that run in Termux to install and manage hermes-agent on Android
- A standalone Android APK (`android/`, currently inherited from openclaw-android — see `android/README.md`)

### In scope

- Vulnerabilities in this repo's install / update scripts (e.g. command injection, path traversal during extraction, insecure tarball handling).
- Vulnerabilities in the `ha` CLI.
- Insecure defaults in the gateway runit service template.
- Supply-chain risk in the bootstrap flow (mirror handling, tarball verification).

### Out of scope

- Vulnerabilities in `hermes-agent` itself → report to [hermes-agent](https://github.com/rodrigoelias/hermes-agent/security/advisories/new).
- Vulnerabilities in Termux → report to [Termux](https://github.com/termux/termux-app).
- Vulnerabilities in upstream Python packages — report to the affected project (cryptography, pydantic, ...).
- Device-level security (rooted devices, unlocked bootloaders).

## Architecture

```
┌─────────────────────────────────────────────┐
│ Android Kernel (SELinux enforced)            │
│ ┌─────────────────────────────────────────┐ │
│ │ Termux sandbox (/data/data/com.termux)  │ │
│ │ ┌─────────────────────────────────────┐ │ │
│ │ │ Termux Python 3.11+ (Bionic)        │ │ │
│ │ │ venv → hermes-agent                 │ │ │
│ │ └─────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Isolation layers

1. **Android app sandbox** — Termux runs in its own UID; no access to other app data.
2. **SELinux** — Android's mandatory access control applies to all Termux processes.
3. **Unprivileged user** — The entire stack runs as a regular user. No root, no SELinux exemptions.
4. **No proot** — No filesystem translation layer; Python uses Termux paths natively.
5. **venv isolation** — hermes-agent's deps live in `~/.hermes-android/hermes-agent/venv`, not the system Python.
