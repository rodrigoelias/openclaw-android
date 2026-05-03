# Android APK (inherited — not yet adapted for Hermes)

This `android/` directory is the standalone APK app inherited from
[openclaw-android](https://github.com/AidanPark/openclaw-android). It is a thin
WebView-based Android wrapper that bundles a terminal emulator and a setup UI,
designed to install and run **OpenClaw** without requiring the user to install
Termux manually.

> **Status: not functional for hermes-agent.**
>
> The Kotlin source still references the `com.openclaw.android` package, the
> WebView UI is wired to the OpenClaw setup flow, and `BootstrapManager.kt`
> downloads the OpenClaw post-setup script. None of this has been re-targeted to
> install hermes-agent yet.
>
> The supported install path today is the Termux-based one documented in the
> [top-level README](../README.md) — `bootstrap.sh` + `ha`. The standalone APK
> is preserved here as scaffolding for a future port. CI for the APK build is
> currently disabled (see `.github/workflows/android-build.yml`).

## What needs to happen to bring this back online

1. Rename the Kotlin package from `com.openclaw.android` to `com.hermes.android`
   (Gradle module IDs, manifest, AndroidX namespace).
2. Replace `app/src/main/assets/post-setup.sh` with the hermes-flavoured one
   (now lives at `../post-setup.sh` in the repo root and points at the
   `rodrigoelias/hermes-android` tarball).
3. Update `BootstrapManager.kt` to download from
   `https://raw.githubusercontent.com/rodrigoelias/hermes-android/main/...`
   rather than the openclaw URL.
4. Strip the OpenClaw setup screens out of `www/src/screens/` and replace them
   with hermes equivalents (or, simpler initial step: drop them entirely and
   let the user run `hermes setup` from the bundled terminal).
5. Re-enable the `android-build.yml` workflow trigger.

## Original architecture (for reference)

```
APK (~5MB)
├── Native: TerminalView (PTY terminal via libtermux.so)
├── WebView: React SPA (setup, dashboard, settings)
├── JsBridge: WebView ↔ Kotlin communication
├── EventBridge: Kotlin → WebView event dispatch
└── OTA: www.zip download + atomic replace
```

## Build (currently builds the OpenClaw-targeted APK)

```bash
cd android
./gradlew assembleDebug
# Output: app/build/outputs/apk/debug/app-debug.apk
```

## License

GPL v3 (inherited from openclaw-android's APK module). The shell scripts at the
repo root are MIT — see `../LICENSE`.
