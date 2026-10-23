---
name: run-emulator
description: >-
  Boots the jarvis_phone Android emulator and runs jarvis_app via
  tooling/run_emulator.ps1 for frontend smoke/manual testing. Use when the
  user asks to test the frontend, run the emulator, launch the app on
  emulator/AVD, or phrases like "probar el frontend", "test frontend",
  "run emulator", "abre el emulador".
---

# Run emulator + jarvis_app (frontend test)

## When to use

Operator asks to **test / try the Flutter frontend** on the Android emulator.
This skill is the agent playbook; prefer the script over ad-hoc `flutter run`.

Human recipe: [docs/dev-mobile.md](../../../docs/dev-mobile.md).  
APK sideload builds stay in skill **`build-apk`** (different trigger).

## Debug logs (default: off)

| User intent | Action |
|-------------|--------|
| Unspecified / “probar el frontend” | Run **without** `-DebugLogs` |
| Explicitly wants verbose Flutter output / debug logs | Pass **`-DebugLogs`** |

**Always** when starting a quiet run: briefly remind the user they can ask for **debug logs** (`-DebugLogs`) next time if they need verbose `flutter run -v` output.

Do not enable `-DebugLogs` unless they ask (or clearly want verbose logs).

## Preconditions

1. Work from the **jarvis_app** repo root (this skill lives there).
2. Flutter + Android SDK healthy (`flutter doctor`; see `docs/dev-mobile.md`).
3. AVD `jarvis_phone` exists (or run `tooling/setup_android_sdk.ps1` once).
4. For **Remote / Auto online** smoke against Jarvis Server: API reachable from the emulator (LAN Pi IP, or host machine via `http://10.0.2.2:8000`).

## Preferred command (Windows)

From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1
```

With debug logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -DebugLogs
```

Useful flags:

| Flag | Effect |
|------|--------|
| *(none)* | Quiet `flutter run` (default for this skill) |
| `-DebugLogs` | `flutter run -v` (verbose) |
| `-Uninstall` | Clean install (`adb uninstall com.example.jarvis_app`) before run |
| `-BootOnly` | Start/wait for emulator only; do not `flutter run` |

Long-running: `flutter run` blocks until the user quits (`q`). Run it in a dedicated terminal; do not treat a hanging process as failure while the app is up.

## Agent checklist

```
- [ ] Confirmed jarvis_app root + Flutter/SDK OK (or report what’s missing)
- [ ] Chose quiet vs -DebugLogs (default quiet; reminded user about debug option)
- [ ] Ran tooling/run_emulator.ps1 (add -Uninstall only if clean install requested)
- [ ] Reported emulator device id / that the app launch was started
- [ ] If Remote smoke was in scope: noted API base URL expectation
```

## Chat reply template

After starting (or when handing off to the running terminal):

- Emulator ready / `flutter run` started (device id if known)
- Mode: quiet or debug logs
- Reminder (quiet runs only): you can ask for **debug logs** next time (`-DebugLogs`)
- Hot reload: `r` / restart: `R` / quit: `q` in the Flutter terminal

## Out of scope

- Building release APKs (`build-apk`)
- iOS Simulator
- Changing Jarvis Server secrets or Pi deploy (backend repo)
