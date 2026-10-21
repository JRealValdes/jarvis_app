# Architecture

Mobile client for [JRealValdes/jarvis](https://github.com/JRealValdes/jarvis).

## Layers (`lib/`)

| Layer | Role |
|-------|------|
| `screens/` / `widgets/` | Presentation |
| `agent/` | Backends + chat orchestration |
| `agent/remote/` | FastAPI client, JWT auth, Firebase URL |
| `domain/` | Pure chat state, prompts, models |
| `data/` | Secure storage + local SQLite history |
| `config/` | Defaults (models, seed message, endpoints) |

```text
ChatScreen
    └─ ChatController
           └─ BackendFactory
                  ├─ LocalJarvisAgent  → OpenAI + sqflite
                  └─ RemoteJarvisApi   → RemoteEndpoint + JWT HTTP
```

`RemoteEndpoint` is the single base-URL resolver (Firebase `jarvis/latest_url`). Auth (`/token`) and chat/admin calls share it; Basic vs Bearer headers stay in their callers.

Session Manager is **remote admin only** (JWT `admin` truthy). Kept until Auto/offline (#5) reshapes ops UX.

## Modes

| Mode | When | Persistence |
|------|------|-------------|
| **Local** (MVP Settings default) | On-device OpenAI | Disk (sqflite) |
| **Remote** | Home/cloud FastAPI | Server checkpointer |
| **Auto / offline failover** | Planned in [#5](https://github.com/JRealValdes/jarvis_app/issues/5) | Offline turns ephemeral |

Histories are **never** merged across modes.

## Remote API contract (audited vs jarvis `main`)

Requires a reachable Jarvis FastAPI whose URL is published to Firebase RTDB `jarvis/latest_url.url`.

| Method | Path | Notes |
|--------|------|-------|
| POST | `/token` | HTTP Basic → `{ access_token, token_type }` |
| GET | `/validate-token` | Bearer JWT |
| POST | `/ask` | Body: `message`, `model_name` (`ModelEnum` name, default app: `GPT_4O_MINI`), optional `thread_id` |
| GET | `/message-history` | Optional `thread_id`; `{ thread_id, messages: [{role,content}] }` |
| POST | `/reset-session` | Optional `{ thread_id }` |
| GET | `/individual-cache-status` | `{ exists }` for JWT `real_name` |
| GET | `/admin/cache-status` | Admin; `sessions` may be Python `str(tuple)` — parsed in `remote_cache_parsing.dart` |
| POST | `/admin/reset-global-memory` | Admin |

JWT claims used by the app: `admin` (bool or legacy `1`), `real_name` (server-side thread default).

Stale tunnel URLs: HTTP **404** or Cloudflare **1016** → refresh Firebase URL and retry once.

## Versioning

- App semver: `pubspec.yaml` (`1.2.0` after #1).
- Checked-in APK under `.app_release/` may lag until rebuilt (#4). Prefer building from source for local-agent builds.
- Android `local.properties` `flutter.versionName` is gitignored and refreshed by Flutter tooling — ignore skew vs pubspec.

## Future simplifications (tracked elsewhere)

- **#5:** Split `SecureStore` into local credentials vs remote session when Auto/offline lands (API key gate + ephemeral offline store).
- **#6:** Trim or fully own the Python ID-protocol / hostile prompt surface in `domain/chat_state.dart` once local prompt parity is decided.
