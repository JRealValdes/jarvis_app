# J.A.R.V.I.S. App

Mobile front-end for the Jarvis assistant ([Python backend](https://github.com/JRealValdes/jarvis)).

Supports two execution modes today (manual Settings toggle):

| Mode | How it works |
|------|----------------|
| **Local (MVP default)** | On-device agent: session state, prompts, calc/datetime tools, OpenAI Chat Completions from the phone. No home PC required. |
| **Remote** | FastAPI client: JWT login, Firebase-published base URL, server-side LangGraph agent. |

**Planned:** prefer remote when Jarvis Server is up; on-device OpenAI only as offline failover ([#5](https://github.com/JRealValdes/jarvis_app/issues/5)).

Deeper layout and remote API contract: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

| Issue | Role |
|-------|------|
| [#1](https://github.com/JRealValdes/jarvis_app/issues/1) | On-device agent MVP — **done** |
| [#2](https://github.com/JRealValdes/jarvis_app/issues/2) | Repo sanitation / cleanup |
| [#5](https://github.com/JRealValdes/jarvis_app/issues/5) | Remote-preferred + offline failover |
| [#6](https://github.com/JRealValdes/jarvis_app/issues/6) | Local prompt/tool parity with Python |
| [#3](https://github.com/JRealValdes/jarvis_app/issues/3) | Android emulator / device testing |
| [#4](https://github.com/JRealValdes/jarvis_app/issues/4) | Cursor skill to build APK |

---

## Download

👉 [Download APK](.app_release/jarvis_1.1.3.apk) *(stale name: built as **1.1.3**; app source is **1.2.0** — rebuild before relying on local-agent features; see #4)*

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

3. **Local mode** (MVP default): run the app, complete Setup (OpenAI API key + profile). Firebase is not required.
4. **Remote mode**: add Firebase config at `android/app/google-services.json`, switch to Remote in Settings, then log in against a reachable Jarvis API (`uv run jarvis api` or your tunnel). The API base URL must be published to Firebase RTDB `jarvis/latest_url`.

```bash
flutter run
```

Android SDK / emulator setup is tracked in [#3](https://github.com/JRealValdes/jarvis_app/issues/3).

---

## Local mode & security

- Paste your OpenAI API key once; it is stored with `flutter_secure_storage` (Android Keystore).
- **Never** commit keys or bake them into the APK. Treat builds as personal / sideload until you have a proxy.
- Calculator tool uses a restricted expression parser (not arbitrary code execution).
- After #5: offline failover will **require** this key and will **not** persist offline turns to disk.

---

## Features

- Local on-device Jarvis (welcome flow, disk-backed local history, reset, calc + datetime)
- Settings: Local / Remote, key & profile, remote login/logout
- Remote chat + admin Session Manager (JWT `admin`)
- Remote client aligned with jarvis defaults (`GPT_4O_MINI`, boolean JWT `admin`)

---

## Architecture (short)

```
ChatScreen → ChatController → JarvisBackend
                                ├─ LocalJarvisAgent  (OpenAI + sqflite)
                                └─ RemoteJarvisApi   (agent/remote → FastAPI)
```

Histories are **not** merged when switching modes. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Tech stack

- Flutter (Dart)
- OpenAI Chat Completions (local mode)
- `flutter_secure_storage`, `sqflite`
- Firebase Realtime Database (remote URL only)
- Optional home FastAPI ([jarvis](https://github.com/JRealValdes/jarvis))
