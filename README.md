# J.A.R.V.I.S. App

Mobile front-end for the Jarvis assistant ([Python backend](https://github.com/JRealValdes/jarvis)).

Supports two execution modes:

| Mode | How it works |
|------|----------------|
| **Local (default)** | On-device agent: session state, prompts, calc/datetime tools, OpenAI Chat Completions from the phone. No home PC required. |
| **Remote** | Existing FastAPI client: JWT login, Firebase-published base URL, server-side LangGraph agent. |

Related epic: [issue #1](https://github.com/JRealValdes/jarvis_app/issues/1).

---

## Download

👉 [Download APK](.app_release/jarvis_1.1.3.apk) *(Android; rebuild after local-agent changes)*

You may need to allow installation from unknown sources.

---

## Getting started (dev)

1. Clone the repo and open it in a Flutter IDE.
2. Install deps:

```bash
flutter pub get
```

3. **Local mode** (default): run the app, complete Setup (OpenAI API key + profile). Firebase is not required.
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

---

## Features

- Local on-device Jarvis (welcome flow, memory, reset, calc + datetime tools)
- Settings: switch Local / Remote, edit key & profile
- Remote chat UI (unchanged look) with JWT login
- Recover local history on app reopen
- Admin Session Manager (remote only)

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
