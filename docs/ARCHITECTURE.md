# Architecture

Mobile client for [JRealValdes/jarvis](https://github.com/JRealValdes/jarvis).

## Layers (`lib/`)

| Layer | Role |
|-------|------|
| `screens/` / `widgets/` | Presentation |
| `agent/` | Backends + chat orchestration |
| `agent/remote/` | FastAPI client, JWT auth, Firebase URL, failure classification |
| `domain/` | Pure chat state, prompts, models |
| `data/` | Secure storage, local credentials / remote session facades, message stores |
| `config/` | Defaults (models, seed message, timeouts) |

```text
ChatScreen
    └─ ChatController
           └─ BackendFactory
                  ├─ FailoverJarvisBackend (Auto)
                  │      ├─ RemoteJarvisApi
                  │      └─ LocalJarvisAgent + MemoryMessageStore
                  ├─ LocalJarvisAgent + LocalMessageStore (sqflite)
                  └─ RemoteJarvisApi
```

`RemoteEndpoint` is the single base-URL resolver (Firebase `jarvis/latest_url`). Auth (`/token`) and chat/admin calls share it; Basic vs Bearer headers stay in their callers.

Credentials are split by concern (same Keystore backend):

- `LocalCredentials` — OpenAI key, model, profile
- `RemoteSession` — JWT + login autofill

Session Manager is **remote admin only** (JWT `admin` truthy), hidden while Auto is offline.

## Modes

| Mode | When | Persistence |
|------|------|-------------|
| **Auto** (default) | Remote when reachable; offline OpenAI on transport failure | Offline turns ephemeral (memory only) |
| **Local only** | On-device OpenAI | Disk (sqflite) |
| **Remote only** | Home/cloud FastAPI | Server checkpointer |

Histories are **never** merged across modes or across remote ↔ offline cutover.

### Failover rules (Auto)

| Failure | Behavior |
|---------|----------|
| Timeout / socket / missing Firebase URL / stale tunnel | Enter offline if API key present; else Settings CTA |
| 401 / 403 | Auth error — do **not** enter offline |
| Other HTTP (e.g. 500) | Surface as error — do **not** auto-offline |

Persistent banner while offline: messages will not be saved.

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

Stale tunnel URLs: HTTP **404** or Cloudflare **1016** → refresh Firebase URL and retry once. Transport timeout: `AppConfig.remoteTransportTimeout` (8s).

## Versioning

- App semver: `pubspec.yaml` (`1.4.0` after #6).
- Checked-in APK under `.app_release/` may lag until rebuilt (#4). Prefer building from source for Auto/offline builds.
- Android `local.properties` `flutter.versionName` is gitignored and refreshed by Flutter tooling — ignore skew vs pubspec.

## Local agent parity (#6)

- Prompts: `domain/prompts.dart` tracks Python language + datetime/web-search rules; hostile path retained.
- On-device tools: calc, datetime, `web_search_tool` (DuckDuckGo HTML + public fetch with Glassdoor/SSRF policy).
- Server-only: calendar, speech, LinkedIn drafts/examples, job-preferences YAML.
- ID-protocol helpers in `chat_state.dart` kept for parity; unused while `validUser` is always true locally.

## Mobile / release tooling

- **#3:** Local emulator recipe — [docs/dev-mobile.md](dev-mobile.md).
- **#4:** Cursor skill to build/publish APK (tracked separately).
