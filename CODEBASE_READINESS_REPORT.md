# Agent-Ready Codebase Assessment Report

**Project**: openclaw-android
**Date**: 2026-03-20
**Assessed by**: Claude Code (Opus 4.6)
**CI Target**: Local Docker on MacBook M1

---

## Overall Score: 58 / 100 — Developing

| Band | Range | Status |
|------|-------|--------|
| Foundational | 0–34 | |
| Emerging | 35–49 | |
| **Developing** | **50–64** | **← You are here** |
| Capable | 65–79 | |
| Exemplary | 80–100 | |

---

## Dimension Scores

| # | Dimension | Score | Weight | Weighted |
|---|-----------|-------|--------|----------|
| 1 | Testing Infrastructure | 30 | 20% | 6.0 |
| 2 | Code Quality & Static Analysis | 72 | 15% | 10.8 |
| 3 | Build System & Dependencies | 72 | 15% | 10.8 |
| 4 | Documentation & Dev Experience | 70 | 10% | 7.0 |
| 5 | Error Handling & Type Safety | 80 | 10% | 8.0 |
| 6 | CI/CD Pipeline | 40 | 15% | 6.0 |
| 7 | Code Architecture & Modularity | 70 | 10% | 7.0 |
| 8 | Security Practices | 55 | 5% | 2.75 |
| | **Total** | | **100%** | **58.4** |

---

## Dimension Details

### 1. Testing Infrastructure — 30/100

**What exists:**
- 19 JUnit 4 unit tests in `terminal-emulator` module (PTY emulation, cursor, Unicode, key handling, scroll regions)
- `TEST_PLAN.md` with 64 planned test cases across 14 sections
- `tests/verify-install.sh` integration script

**Critical gaps:**
- **Zero tests for the main `app` module** — no `src/test/` or `src/androidTest/` directories
- No UI tests (Espresso, Compose, or Robolectric)
- No test coverage tooling (JaCoCo not configured)
- Tests do NOT run in CI (`android-build.yml` only runs `assembleDebug`)
- No web UI tests (no Vitest, Jest, or Playwright configured for `www/`)

**Impact on AI agents:** Low test coverage means agents cannot verify their changes. This is the single biggest blocker for autonomous development.

### 2. Code Quality & Static Analysis — 72/100

**What exists:**
- **Detekt** 1.23.8 — strict config (`maxIssues: 0`), HTML + SARIF reports
- **ktlint** 14.1.0 — Android mode, `ignoreFailures = false`
- **ESLint** 9.x — React hooks, TypeScript recommended rules
- **EditorConfig** — UTF-8, LF, per-language indentation
- **Pre-commit hooks** (`.githooks/`) — run detekt + ktlint on staged files

**Gaps:**
- Linting does NOT run in CI — PRs can merge with violations
- Git hooks require manual activation (`git config core.hooksPath .githooks`)
- `terminal-emulator` and `terminal-view` modules excluded from linting
- ESLint violations don't block builds
- No `npm run lint` in CI

### 3. Build System & Dependencies — 72/100

**What exists:**
- Gradle 9.3.1 with Kotlin DSL (app module)
- Version catalog (`libs.versions.toml`) with centralized dependency management
- Gradle wrapper pinned
- `package-lock.json` for web UI (npm ci in CI)
- Separate debug/release build types with externalized signing

**Gaps:**
- **`targetSdk = 28`** (2019) — critical for Play Store compliance, security
- No Gradle dependency locking (`gradle.lockfile`)
- No `verification-metadata.xml` for dependency signatures
- Mixed build formats: Groovy DSL in `terminal-*`, Kotlin DSL in `app`
- `compileSdk` mismatch: 36 (app) vs 35 (terminal-*)
- Minification disabled (`isMinifyEnabled = false`)

### 4. Documentation & Dev Experience — 70/100

**What exists:**
- Excellent README.md (architecture diagrams, CLI reference, step-by-step setup)
- CONTRIBUTING.md with per-language code style, git workflow, hook setup
- CHANGELOG.md (semantic versioning)
- Bilingual docs (English + Korean)
- CodeRabbit AI review configured with project-specific rules
- Dependabot for gradle, npm, GitHub Actions

**Gaps:**
- **No CLAUDE.md** — no AI-assisted development guidance
- **No centralized task runner** (Makefile, root npm scripts, Just)
- No PR template (`.github/pull_request_template.md`)
- `REPORT.md` and `TEST_PLAN.md` are Korean-only

### 5. Error Handling & Type Safety — 80/100

**What exists:**
- Structured coroutine error handler (`launchWithErrorHandling()` in JsBridge)
- Consistent try-catch in all I/O operations (network, file, process)
- Kotlin null safety used well (elvis operators, safe casts, defensive checks)
- TypeScript `strict: true` with `noUnusedLocals`, `noUnusedParameters`
- CommandRunner has timeout protection with force-kill
- Graceful fallbacks (GitHub → bundled assets)

**Gaps:**
- No explicit `-Werror` Kotlin compiler flag
- Some silent catches in update checking (`checkForUpdates()`)

### 6. CI/CD Pipeline — 40/100

**What exists:**
- GitHub Actions workflow (`android-build.yml`)
  - `build-www` job: Node 22, npm ci, npm build → www.zip artifact
  - `build-apk` job: Java 21, Gradle cache, `assembleDebug` → APK artifact
  - Release job (manual)
- Gradle + npm caching configured

**Critical gaps:**
- **No test execution in CI**
- **No lint/static analysis in CI**
- **No local CI scripts** — everything depends on GitHub Actions
- No code coverage reporting
- No security scanning (SAST/dependency audit)
- No shell script validation

### 7. Code Architecture & Modularity — 70/100

**What exists:**
- Clean 3-module structure: `app`, `terminal-emulator`, `terminal-view`
- Clear separation of concerns: JsBridge (31 methods, 7 domains), EventBridge, CommandRunner, BootstrapManager
- WebView UI cleanly separated (React/TypeScript with typed bridge wrapper)
- ProGuard rules protect JsBridge interface
- Hash-based routing for single-page web UI

**Gaps:**
- JsBridge.kt has 31 methods in a single file — could benefit from domain-based splitting
- No dependency injection framework
- Hardcoded URLs in BuildConfig

### 8. Security Practices — 55/100

**What exists:**
- SECURITY.md with responsible disclosure process and response timeline
- Security architecture documented (Android sandbox, SELinux, unprivileged user)
- Signing config externalized from VCS
- ProGuard keeps JsBridge methods

**Gaps:**
- **`targetSdk = 28`** misses years of Android security improvements
- No dependency vulnerability scanning
- No SAST in CI
- Minification/obfuscation disabled

---

## Local CI Recommendation (Docker on MacBook M1)

Since CI is entirely local on an M1 MacBook, here's a practical Docker-based setup:

### Recommended Directory Structure

```
ci/
├── Dockerfile.android        # Android build + lint + test
├── Dockerfile.web           # Node build + lint + test
├── docker-compose.ci.yml    # Orchestrates all CI jobs
├── run-ci.sh               # One-command local CI entry point
└── scripts/
    ├── lint.sh              # Run all linters
    ├── test.sh              # Run all tests
    └── build.sh             # Build APK + web
```

### Dockerfile.android

```dockerfile
FROM --platform=linux/arm64 eclipse-temurin:21-jdk

# Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

RUN apt-get update && apt-get install -y unzip wget && \
    mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/tools.zip && \
    unzip -q /tmp/tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    yes | sdkmanager --licenses > /dev/null 2>&1 && \
    sdkmanager "platforms;android-36" "build-tools;36.0.0" "ndk;28.0.13004108" && \
    rm /tmp/tools.zip

WORKDIR /app
```

### Dockerfile.web

```dockerfile
FROM --platform=linux/arm64 node:22-slim
WORKDIR /app/android/www
```

### docker-compose.ci.yml

```yaml
services:
  lint-kotlin:
    build:
      context: .
      dockerfile: ci/Dockerfile.android
    volumes:
      - .:/app:cached
    command: >
      sh -c "cd /app/android &&
        ./gradlew detekt ktlintCheck --no-daemon"

  lint-web:
    build:
      context: .
      dockerfile: ci/Dockerfile.web
    volumes:
      - .:/app:cached
    command: >
      sh -c "npm ci && npm run lint && npx tsc -b --noEmit"

  test-android:
    build:
      context: .
      dockerfile: ci/Dockerfile.android
    volumes:
      - .:/app:cached
    command: >
      sh -c "cd /app/android &&
        ./gradlew test --no-daemon"

  build-web:
    build:
      context: .
      dockerfile: ci/Dockerfile.web
    volumes:
      - .:/app:cached
    command: >
      sh -c "npm ci && npm run build"

  build-apk:
    build:
      context: .
      dockerfile: ci/Dockerfile.android
    volumes:
      - .:/app:cached
    depends_on:
      build-web:
        condition: service_completed_successfully
    command: >
      sh -c "cd /app/android &&
        ./gradlew assembleDebug --no-daemon"
```

### run-ci.sh (Entry Point)

```bash
#!/bin/bash
set -euo pipefail

echo "=== OpenClaw Local CI ==="
echo "Running on: $(uname -m)"

# Phase 1: Lint (parallel)
echo "--- Phase 1: Linting ---"
docker compose -f ci/docker-compose.ci.yml up --build \
  lint-kotlin lint-web \
  --abort-on-container-exit --exit-code-from lint-kotlin

# Phase 2: Test (parallel)
echo "--- Phase 2: Testing ---"
docker compose -f ci/docker-compose.ci.yml up --build \
  test-android \
  --abort-on-container-exit --exit-code-from test-android

# Phase 3: Build (sequential: web → apk)
echo "--- Phase 3: Building ---"
docker compose -f ci/docker-compose.ci.yml up --build \
  build-web build-apk \
  --abort-on-container-exit --exit-code-from build-apk

echo "=== CI PASSED ==="
```

### M1-Specific Notes

- Use `--platform=linux/arm64` in Dockerfiles — avoids Rosetta emulation overhead
- Mount volumes with `:cached` for better I/O on macOS
- Android SDK images are ~3GB; pre-build and tag locally to speed up subsequent runs
- Gradle daemon is disabled (`--no-daemon`) in containers for predictable memory usage
- Consider `GRADLE_OPTS=-Xmx4g` if the M1 MacBook has 16GB+ RAM
- NDK native compilation (terminal-emulator JNI) works natively on arm64

### Makefile (Convenience Wrapper)

```makefile
.PHONY: ci lint test build clean

ci: lint test build

lint:
	docker compose -f ci/docker-compose.ci.yml up --build \
		lint-kotlin lint-web \
		--abort-on-container-exit

test:
	docker compose -f ci/docker-compose.ci.yml up --build \
		test-android \
		--abort-on-container-exit

build:
	docker compose -f ci/docker-compose.ci.yml up --build \
		build-web build-apk \
		--abort-on-container-exit

clean:
	docker compose -f ci/docker-compose.ci.yml down --rmi local -v
```

---

## Improvement Roadmap

### Phase 1 — Quick Wins (1-2 days) → Score: 58 → ~68

| # | Action | Dimension Impact | Effort |
|---|--------|-----------------|--------|
| 1 | Create `CLAUDE.md` with project context, conventions, key files | Documentation +8 | 2h |
| 2 | Add `Makefile` at root with `lint`, `test`, `build`, `ci` targets | Documentation +5, CI +5 | 1h |
| 3 | Activate git hooks automatically in setup script | Code Quality +3 | 30m |
| 4 | Add `./gradlew detekt ktlintCheck` and `npm run lint` to CI | Code Quality +5, CI +5 | 1h |
| 5 | Add `./gradlew test` to CI | Testing +5, CI +3 | 30m |

### Phase 2 — Foundation (1 week) → Score: ~68 → ~78

| # | Action | Dimension Impact | Effort |
|---|--------|-----------------|--------|
| 6 | Create `ci/` directory with Docker-based local CI (see above) | CI +10 | 4h |
| 7 | Add unit tests for `app` module (JsBridge, CommandRunner, UrlResolver) | Testing +15 | 2d |
| 8 | Configure JaCoCo for test coverage reporting | Testing +5 | 2h |
| 9 | Upgrade `targetSdk` to 35+ | Security +10, Build +3 | 4h |
| 10 | Migrate `terminal-*` modules to Kotlin DSL | Build +3 | 2h |

### Phase 3 — Maturity (2-3 weeks) → Score: ~78 → ~88

| # | Action | Dimension Impact | Effort |
|---|--------|-----------------|--------|
| 11 | Add Robolectric tests for Android components | Testing +8 | 3d |
| 12 | Add Vitest for web UI (`www/`) | Testing +5 | 1d |
| 13 | Add Gradle dependency verification (`verification-metadata.xml`) | Build +3, Security +5 | 2h |
| 14 | Enable R8 minification and validate ProGuard rules | Security +5, Build +2 | 4h |
| 15 | Add dependency vulnerability scanning (OWASP or `npm audit`) | Security +5 | 2h |
| 16 | Split JsBridge.kt into domain-specific files | Architecture +5 | 4h |

---

## Key Findings Summary

**Strongest areas:**
- Error handling is comprehensive and consistent (80/100)
- Static analysis tools are well-configured locally (72/100)
- Build system uses modern Gradle with version catalog (72/100)

**Weakest areas:**
- Testing is the #1 blocker — no app module tests, no CI test execution (30/100)
- CI pipeline is build-only — no quality gates (40/100)
- No local CI infrastructure for Docker-based validation (40/100)

**For AI agent readiness specifically:**
- Missing `CLAUDE.md` means agents lack project context
- Missing tests means agents can't verify their changes
- Missing local CI means no fast feedback loop for agent iterations

The path from 58 → 78 is achievable in ~1 week with focused effort on testing and local CI infrastructure.
