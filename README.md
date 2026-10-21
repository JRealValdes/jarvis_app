# J.A.R.V.I.S. App

Mobile front-end for the Jarvis assistant ([Python backend](https://github.com/JRealValdes/jarvis)).

Supports two execution modes today (manual Settings toggle):

| Mode | How it works |
|------|----------------|
| **Local (default in MVP)** | On-device agent: session state, prompts, calc/datetime tools, OpenAI Chat Completions from the phone. No home PC required. |
| **Remote** | FastAPI client: JWT login, Firebase-published base URL, server-side LangGraph agent. |

**Planned product direction** ([issue #5](https://github.com/JRealValdes/jarvis_app/issues/5)): prefer **remote when Jarvis Server is reachable**; use on-device OpenAI only as **offline failover** (API key required; ephemeral in-memory chat; banner that offline turns are not saved). That failover is **not** in the #1 MVP yet.

Tracking:

| Issue | Role |
|-------|------|
| [#1](https://github.com/JRealValdes/jarvis_app/issues/1) | On-device agent **MVP** (dual backends) — merge first |
| [#2](https://github.com/JRealValdes/jarvis_app/issues/2) | Repo sanitation / cleanup — preferred next after #1 |
| [#5](https://github.com/JRealValdes/jarvis_app/issues/5) | Remote-preferred + offline failover |
| [#6](https://github.com/JRealValdes/jarvis_app/issues/6) | Local prompt/tool parity with Python backend |
| [#3](https://github.com/JRealValdes/jarvis_app/issues/3) | Android emulator / device testing |
| [#4](https://github.com/JRealValdes/jarvis_app/issues/4) | Cursor skill to build APK |

---

## Download

👉 [Download APK](.app_release/jarvis_1.1.3.apk) *(Android; rebuild after local-agent changes — app version is **1.2.0** on the feature branch)*

You may need to allow installation from unknown sources.

---

## Getting started (dev)

1. Clone the repo and open it in a Flutter IDE.
2. Install deps:

```bash
flutter pub get
```

On Windows, Flutter plugin builds may require **Developer Mode** (symlink support).

3. **Local mode** (MVP default): run the app, complete Setup (OpenAI API key + profile). Firebase is not required.
4. **Remote mode**: add Firebase config at `android/app/google-services.json`, switch to Remote in Settings, then log in against a reachable Jarvis API.

```bash
flutter run
flutter test
```

---

## Local mode & security

- Paste your OpenAI API key once; it is stored with `flutter_secure_storage` (Android Keystore).
- **Never** commit keys or bake them into the APK. Treat builds as personal / sideload until you have a proxy.
- Do not redistribute an APK that contains someone else’s key.
- Calculator tool uses a restricted expression parser (not arbitrary code execution).
- After #5: offline failover will **require** this key and will **not** persist offline turns to disk.

---

## Features (MVP)

- Local on-device Jarvis (welcome flow, disk-backed local history, reset, calc + datetime tools)
- Settings: switch Local / Remote, edit key & profile
- Remote chat UI with JWT login; admin Session Manager (remote only)
- Remote client aligned with current jarvis defaults (`GPT_4O_MINI`, boolean JWT `admin`)

---

## Architecture (short)

```
ChatScreen → JarvisBackend
               ├─ LocalJarvisAgent  (OpenAI + sqflite)
               └─ RemoteJarvisApi   (home FastAPI)
```

Histories are **not** merged when switching modes.

---

## Tech stack

- Flutter (Dart)
- OpenAI Chat Completions (local mode)
- `flutter_secure_storage`, `sqflite`
- Firebase Realtime Database (remote URL only)
- Optional home FastAPI ([jarvis](https://github.com/JRealValdes/jarvis))
