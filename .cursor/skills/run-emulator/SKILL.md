---
name: run-emulator
description: >-
  Boots or stops the jarvis_phone Android emulator and runs jarvis_app via
  tooling/run_emulator.ps1. Use when the user asks to test the frontend, run
  the emulator, launch the app on emulator/AVD, close/stop/kill the emulator,
  or phrases like "probar el frontend", "test frontend", "run emulator",
  "abre el emulador", "cierra el emulador", "apaga el emulador", "adb emu kill".
---

# Run / stop emulator + jarvis_app (frontend test)

## When to use

| Intent | Action |
|--------|--------|
| Test / open frontend on emulator | Boot + `flutter run` (see Open) |
| Close / shut down / kill the AVD | `-Kill` (see Close) |
| Quit Flutter only, keep AVD warm | Tell operator to press `q` in the Flutter terminal (or stop that process); **do not** `-Kill` |

Prefer the script over ad-hoc `flutter run` / `adb`.

Human recipe: [docs/dev-mobile.md](../../../docs/dev-mobile.md).  
APK sideload builds stay in skill **`build-apk`** (different trigger).

## Open (start)

### Debug logs (default: off)

| User intent | Action |
|-------------|--------|
| Unspecified / “probar el frontend” | Run **without** `-DebugLogs` |
| Explicitly wants verbose Flutter / debug logs | Pass **`-DebugLogs`** |

Do not enable `-DebugLogs` unless they ask (or clearly want verbose logs).

### Reminders (always, after starting a run)

In the chat reply, briefly remind:

1. They can ask for **debug logs** next time (`-DebugLogs` / `flutter run -v`).
2. They can ask you to **close the emulator** later (“cierra el emulador”) and you will run `-Kill` — no need to remember `adb` by hand.

### Command

From the **jarvis_app** repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -DebugLogs
```

| Flag | Effect |
|------|--------|
| *(none)* | Quiet `flutter run` (default) |
| `-DebugLogs` | `flutter run -v` |
| `-Uninstall` | Clean install before run |
| `-BootOnly` | Start/wait for AVD only; no `flutter run` |

Long-running: `flutter run` blocks until quit. Use a dedicated terminal; a live app is not a failure.

## Close (stop AVD)

Triggers: “cierra el emulador”, “apaga el emulador”, “kill emulator”, “stop the AVD”, etc.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -Kill
```

This runs `adb -s <emulator> emu kill` (powers off the AVD window). Confirm in chat that the emulator is gone (`adb devices` empty of `emulator-*` if useful).

**Flutter vs AVD:**

| Ask | Do |
|-----|-----|
| Close / kill **emulator** | `-Kill` |
| Stop **app / flutter run** only | Operator: `q` in Flutter terminal. Keep AVD up unless they also asked to close the emulator. |

### Manual fallback (if script/`adb` fails)

- Flutter: `q` in the `flutter run` terminal  
- AVD: `adb emu kill` or close the emulator window  

## Preconditions

1. Work from the **jarvis_app** repo root.
2. Flutter + Android SDK healthy (`flutter doctor`; see `docs/dev-mobile.md`).
3. AVD `jarvis_phone` exists (or run `tooling/setup_android_sdk.ps1` once) — required for **open**, not for **kill**.
4. Remote smoke: API reachable from the emulator (LAN Pi IP, or `http://10.0.2.2:8000` for host API).

## Agent checklist

**Open:**

```
- [ ] jarvis_app root + Flutter/SDK OK (or report gap)
- [ ] Quiet vs -DebugLogs (default quiet)
- [ ] Ran run_emulator.ps1
- [ ] Reminded: debug logs option + “ask me to close the emulator”
- [ ] Reported device id / launch started
```

**Close:**

```
- [ ] Ran run_emulator.ps1 -Kill
- [ ] Confirmed AVD stopped (or reported error + manual fallback)
```

## Chat reply templates

**After open:** emulator ready / `flutter run` started; quiet or debug; reminders (debug logs + ask to close); hotkeys `r` / `R` / `q`.

**After close:** AVD killed via `-Kill` (or fallback used).

## Out of scope

- Building release APKs (`build-apk`)
- iOS Simulator
- Jarvis Server secrets / Pi deploy (backend repo)
