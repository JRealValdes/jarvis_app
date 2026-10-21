# Local mobile testing (Windows)

Recipe to run **jarvis_app** on an Android emulator or physical device. Desktop/web devices are fine for layout experiments, but they are **not** a substitute for secure storage, Firebase Android, or APK-shaped behavior.

## Prerequisites (one-time)

1. **Flutter stable** on PATH (`flutter doctor` should already show Flutter OK).
2. **OpenJDK 17+** (Microsoft Build of OpenJDK works):

```powershell
winget install --id Microsoft.OpenJDK.17 -e --accept-package-agreements
```

3. **Android SDK + AVD** — either run the repo helper, or follow the manual steps below:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/setup_android_sdk.ps1
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
# Feed 'y' until done if any licenses remain:
flutter doctor --android-licenses
flutter doctor
```

Expected: **Android toolchain** is green.  
Optional gap: **Visual Studio** is only needed for *Windows desktop* builds — ignore it for phone testing.

### What the helper installs

| Piece | Location / name |
|-------|-----------------|
| SDK root | `%LOCALAPPDATA%\Android\Sdk` |
| Platforms | android-35, android-36 |
| Build-tools | 28.0.3, 35.0.0, 36.0.0 (Flutter 3.47) |
| System image | `system-images;android-35;google_apis;x86_64` |
| AVD | `jarvis_phone` (Pixel 6 form factor) |
| User env | `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`, PATH additions |

## Start the emulator

```powershell
flutter emulators
flutter emulators --launch jarvis_phone
# wait until:
adb devices   # should show emulator-XXXX  device
```

### If the emulator stays `offline`

On this host, a cold boot with software GPU is reliable:

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
& "$sdk\emulator\emulator.exe" -avd jarvis_phone -no-snapshot-load -no-boot-anim -gpu swiftshader_indirect
```

WHPX acceleration is available (`emulator -accel-check`); snapshot/GPU quirks can still leave ADB offline until a cold boot.

## Run the app

```powershell
flutter pub get
flutter run -d emulator-5554   # or pick the id from `flutter devices`
```

Hot reload: press `r` in the Flutter terminal; hot restart: `R`.

### Smoke-check (Local / Auto offline)

1. App opens Setup (or Settings) when no OpenAI key/profile is stored.
2. Enter API key + Jarvis name → chat loads.
3. Confirm secure storage survives an app restart (key still present).
4. **Remote / Auto online** additionally needs `android/app/google-services.json` and a reachable Jarvis API URL in Firebase RTDB `jarvis/latest_url`.

## Physical device (USB)

1. Enable **Developer options** → **USB debugging** on the phone.
2. Connect USB; accept the RSA prompt.
3. `adb devices` should list the device as `device`.
4. `flutter run` (Flutter picks the phone when it is the only mobile target).

## Secondary layout check (not a replacement)

Chrome DevTools device mode (`flutter run -d chrome`) is useful for quick UI width checks only. It does **not** exercise Android Keystore, Firebase Android, or release APK packaging.

## Android Gradle toolchain (repo)

Aligned with Flutter 3.47’s pre-AGP-9 path:

| Tool | Version in repo |
|------|-----------------|
| Gradle wrapper | 8.14 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |
| `minSdk` / `targetSdk` / `compileSdk` | Flutter defaults (`flutter.*SdkVersion`) |

`android/gradle.properties` keeps `android.builtInKotlin=false` and `android.newDsl=false` until a full AGP 9 migration.

## Verified on this machine (issue #3)

- `flutter doctor` → Android toolchain OK (SDK 36).
- Emulator `jarvis_phone` listed and launchable.
- `flutter build apk --debug` succeeded; APK installed and `MainActivity` resumed on the emulator.
