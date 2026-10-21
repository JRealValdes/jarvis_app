# J.A.R.V.I.S. App

Mobile front-end for the Jarvis assistant ([Python backend](https://github.com/JRealValdes/jarvis)).

| Mode | How it works |
|------|----------------|
| **Auto (default)** | Prefer Jarvis Server when reachable; fall back to on-device OpenAI on transport failure. Offline turns are **ephemeral** (not saved; cleared on restart). |
| **Local only** | On-device agent with disk-backed history. No home PC required. |
| **Remote only** | FastAPI client only: JWT login, Firebase-published base URL. No offline failover. |

Offline failover requires an OpenAI API key in Settings. Auth failures (401) do **not** enter offline — log in again instead.

Deeper layout and remote API contract: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

| Issue | Role |
|-------|------|
| [#1](https://github.com/JRealValdes/jarvis_app/issues/1) | On-device agent MVP — **done** |
| [#2](https://github.com/JRealValdes/jarvis_app/issues/2) | Repo sanitation — **done** |
| [#5](https://github.com/JRealValdes/jarvis_app/issues/5) | Remote-preferred + offline failover |
| [#6](https://github.com/JRealValdes/jarvis_app/issues/6) | Local prompt/tool parity with Python |
| [#3](https://github.com/JRealValdes/jarvis_app/issues/3) | Android emulator / device testing |
| [#4](https://github.com/JRealValdes/jarvis_app/issues/4) | Cursor skill to build APK |

---

## Download

👉 [Download APK](.app_release/jarvis_1.1.3.apk) *(stale name: built as **1.1.3**; app source is **1.3.0** — rebuild before relying on Auto/offline; see #4)*

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

3. **Auto (default):** configure OpenAI key + profile in Setup/Settings for offline capability; add Firebase `android/app/google-services.json` and log in when the server is up.
4. **Local only:** Setup with OpenAI key + profile; Firebase not required.
5. **Remote only:** Firebase config + reachable Jarvis API (`uv run jarvis api` or tunnel). URL must be in Firebase RTDB `jarvis/latest_url`.

```bash
flutter run
```

Android SDK / emulator setup is tracked in [#3](https://github.com/JRealValdes/jarvis_app/issues/3).

### Smoke-test: Auto / offline failover

1. Set mode to **Auto**, save a valid OpenAI key, log in while the server is up → chat stays remote (no offline banner).
2. Stop the server / break the tunnel → next send shows the offline banner; replies come from on-device OpenAI; restart the app → offline thread is gone.
3. Remove the API key, stop the server → chat shows a Settings CTA (no silent offline).
4. With a bad JWT (401) → auth error / login path; app does **not** flip to offline.

---

## Local mode & security

- Paste your OpenAI API key once; it is stored with `flutter_secure_storage` (Android Keystore).
- **Never** commit keys or bake them into the APK. Treat builds as personal / sideload until you have a proxy.
- Calculator tool uses a restricted expression parser (not arbitrary code execution).
- Offline failover **requires** this key and does **not** persist offline turns to disk.

---

## Features

- Auto remote-preferred chat with ephemeral offline failover + banner
- Local-only on-device Jarvis (welcome flow, disk history, reset, calc + datetime)
- Settings: Auto / Local / Remote, key & profile, remote login/logout
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
- Firebase Realtime Database (remote URL only)
- Optional home FastAPI ([jarvis](https://github.com/JRealValdes/jarvis))
