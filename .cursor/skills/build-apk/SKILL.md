---
name: build-apk
description: >-
  Builds a personal-sideload Android APK for jarvis_app, stamps it from
  pubspec.yaml, copies it to .app_release/, and updates the README download
  link. Use when the user asks to generate/build a new APK, release Android,
  or says phrases like "genera un nuevo apk", "build apk", "build a new APK",
  or "release android".
---

# Build Android APK (jarvis_app)

## Policy (v1)

- **Personal sideload only** — release build uses the **debug keystore** (see `android/app/build.gradle.kts`). Not Play Store signing.
- APKs under `.app_release/` **are tracked in git** for personal download convenience. Do not commit keystores or API keys.
- **Never** bake an OpenAI API key into the binary. Local/offline keys are entered by the user at runtime (secure storage).

## Preconditions

1. Flutter stable on PATH; Android toolchain healthy (`flutter doctor` — see [docs/dev-mobile.md](../../../docs/dev-mobile.md)).
2. Working tree on the intended branch; prefer a clean tree or commit unrelated WIP first.
3. `pubspec.yaml` `version:` is the source of truth for the artifact name (`1.4.0` → `jarvis_1.4.0.apk`). Do **not** auto-bump unless the user asks.

## Preferred command (Windows)

From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/build_apk.ps1 -RemoveOldApks
```

The script:

1. Reads `version:` from `pubspec.yaml` (name part before `+`).
2. Runs `flutter build apk --release`.
3. Copies `build/app/outputs/flutter-apk/app-release.apk` → `.app_release/jarvis_<version>.apk`.
4. Prints path, version, and size.

Flags:

- `-SkipFlutterBuild` — only copy an already-built `app-release.apk`.
- `-NoUpdateReadme` — leave the README Download link unchanged (default: update it).
- `-RemoveOldApks` — delete other `jarvis_*.apk` files in `.app_release/` before copying.

## Manual equivalent

```powershell
flutter pub get
flutter build apk --release
# version from pubspec, e.g. 1.4.0
New-Item -ItemType Directory -Force -Path .app_release | Out-Null
Copy-Item build\app\outputs\flutter-apk\app-release.apk .app_release\jarvis_1.4.0.apk -Force
```

Update README Download to `.app_release/jarvis_<version>.apk` and drop “stale” notes.

Optional cleanup: remove older `jarvis_*.apk` files in `.app_release/` so only the current sideload artifact remains (confirm before deleting tracked files you still need).

## Agent checklist

Copy and track:

```
- [ ] Preconditions OK (Flutter + Android SDK)
- [ ] Ran tooling/build_apk.ps1 (or manual steps)
- [ ] Artifact at .app_release/jarvis_<version>.apk
- [ ] README Download link matches filename
- [ ] Reported path + version + size in chat
- [ ] No secrets / keystores committed
```

## Chat reply template

After a successful build, tell the user:

- Version (from pubspec)
- Absolute or repo-relative path of the APK
- File size
- Signing: debug keystore / personal sideload
- Remind: install from unknown sources may be required; never redistribute an APK that embeds someone else’s API key

## Out of scope

- Play Store / upload keystore pipelines
- Split-per-ABI unless the user explicitly asks (`flutter build apk --split-per-abi`)
- iOS builds
