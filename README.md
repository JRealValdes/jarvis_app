# J.A.R.V.I.S. App

Mobile front-end for the Jarvis assistant ([Python backend](https://github.com/JRealValdes/jarvis)).

| Mode | How it works |
|------|----------------|
| **Auto (default)** | Prefer Jarvis Server when reachable; fall back to on-device OpenAI on transport failure. Offline turns are **ephemeral** (not saved; cleared on restart). |
| **Local only** | On-device agent with disk-backed history. No home PC required. |
| **Remote only** | FastAPI client only: JWT login against an operator-configured API base URL (LAN). No offline failover. |

Offline failover requires an OpenAI API key in Settings. Auth failures (401) do **not** enter offline — log in again instead.

Deeper layout and remote API contract: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

| Issue | Role |
|-------|------|
| [#1](https://github.com/JRealValdes/jarvis_app/issues/1) | On-device agent MVP — **done** |
| [#2](https://github.com/JRealValdes/jarvis_app/issues/2) | Repo sanitation — **done** |
| [#5](https://github.com/JRealValdes/jarvis_app/issues/5) | Remote-preferred + offline failover — **done** |
| [#6](https://github.com/JRealValdes/jarvis_app/issues/6) | Local prompt/tool parity with Python — **done** |
| [#3](https://github.com/JRealValdes/jarvis_app/issues/3) | Android emulator / device testing — **done** |
| [#4](https://github.com/JRealValdes/jarvis_app/issues/4) | Cursor skill to build APK — **done** |
| [#12](https://github.com/JRealValdes/jarvis_app/issues/12) | Remove Firebase URL discovery; configured LAN base URL — **done** |
| [#11](https://github.com/JRealValdes/jarvis_app/issues/11) | Tailscale / off-LAN remote access (after #12) |

Mark a row **done** in this table when that issue ships (same PR / follow-up docs commit). Verification (unit tests + smoke) stays **inside** each issue — no separate test-only issue. Backend mirror: [jarvis#29](https://github.com/JRealValdes/jarvis/issues/29) (Pi/LAN), [#30](https://github.com/JRealValdes/jarvis/issues/30) (drop cloudflared/Firebase — first), [#31](https://github.com/JRealValdes/jarvis/issues/31) (Tailscale — after #30).

---

## Download

👉 [Download APK](.app_release/jarvis_1.5.0.apk)

You may need to allow installation from unknown sources.

---

## Getting started (dev)

1. Clone the repo and open it in a Flutter IDE.
2. Install deps:

```bash
flutter pub get
flutter test
```

On Windows, Flutter plugin builds may require **Developer Mode** (symlink support).

3. **Auto (default):** configure OpenAI key + profile in Setup/Settings for offline capability; set **API base URL** (LAN) in Settings or Login; log in when the server is up.
4. **Local only:** Setup with OpenAI key + profile; no home server required.
5. **Remote only:** reachable Jarvis API (`uv run jarvis api` on the Pi/LAN) and the same configured base URL (e.g. `http://192.168.x.x:8000`).

Optional LAN fallback when the primary URL fails (short timeout): default `http://jarvis-raspberry.local:8000`, override with `--dart-define=JARVIS_LAN_FALLBACK_URL=...` (empty disables). Not a secret.

```bash
flutter run
```

**Phone / emulator on Windows:** see [docs/dev-mobile.md](docs/dev-mobile.md) (SDK bootstrap script, AVD `jarvis_phone`, cold-boot tip, USB debugging).

### How agents run the emulator

Project skill: `.cursor/skills/run-emulator/` (triggers: “probar el frontend”, “test frontend”, “run emulator”, “cierra el emulador”). Default is quiet `flutter run`; ask for **debug logs** (`-DebugLogs`) or **close the emulator** (`-Kill` / `adb emu kill`). Quit Flutter only with `q` to keep the AVD warm.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/run_emulator.ps1 -Kill
```

### How agents build the APK

Project skill: `.cursor/skills/build-apk/` (triggers: “genera un nuevo apk”, “build apk”, “release android”).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/build_apk.ps1 -RemoveOldApks
```

- Uses `flutter build apk --release` with the **debug keystore** (personal sideload).
- Artifact: `.app_release/jarvis_<pubspec-version>.apk` (tracked for convenience).
- Never bake OpenAI keys into the binary; users paste keys at runtime.

### Smoke-test: Auto / offline failover

1. Set mode to **Auto**, save a valid OpenAI key, set API base URL, log in while the server is up → chat stays remote (no offline banner).
2. Stop the server / break reachability → next send shows the offline banner; replies come from on-device OpenAI; restart the app → offline thread is gone.
3. Remove the API key, stop the server → chat shows a Settings CTA (no silent offline).
4. With a bad JWT (401) → auth error / login path; app does **not** flip to offline.

---

## Local mode & security

- Paste your OpenAI API key once; it is stored with `flutter_secure_storage` (Android Keystore).
- **Never** commit keys or bake them into the APK. Treat builds as personal / sideload until you have a proxy.
- Calculator tool uses a restricted expression parser (not arbitrary code execution).
- Offline failover **requires** this key and does **not** persist offline turns to disk.
- API base URL is topology, not a credential; JWT + login password remain the secrets.

---

## Local vs remote tools

| Capability | Local / offline | Remote (Jarvis Server) |
|------------|-----------------|-------------------------|
| Calc + current date/time | Yes | Yes |
| Web search + public page read (DuckDuckGo; no API key) | Yes | Yes |
| LinkedIn draft / reply examples | No | Yes |
| Job preferences YAML | No | Yes |
| Google Calendar | No | Yes |
| Speech-to-text | No | Yes |

Local system prompts follow Python butler + language + datetime/web-search guidance; server-only tools are called out so the on-device model does not invent side-effects.

## Features

- Auto remote-preferred chat with ephemeral offline failover + banner
- Local-only on-device Jarvis (welcome flow, disk history, reset, calc + datetime + web search)
- Settings: Auto / Local / Remote, key & profile, API base URL, remote login/logout
- Remote chat + admin Session Manager (JWT `admin`, remote-only)
- Remote client aligned with jarvis defaults (`GPT_4O_MINI`, boolean JWT `admin`)

---

## Architecture (short)

```
ChatScreen → ChatController → JarvisBackend
                                ├─ FailoverJarvisBackend (Auto)
                                │     ├─ RemoteJarvisApi
                                │     └─ LocalJarvisAgent + MemoryMessageStore
                                ├─ LocalJarvisAgent + sqflite
                                └─ RemoteJarvisApi
```

Histories are **not** merged when switching modes or entering offline. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Tech stack

- Flutter (Dart)
- OpenAI Chat Completions (local / offline)
- `flutter_secure_storage`, `sqflite`
- Optional home FastAPI ([jarvis](https://github.com/JRealValdes/jarvis)) on LAN (Tailscale off-LAN tracked in #11)
