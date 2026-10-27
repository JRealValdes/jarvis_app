# Architecture

Mobile client for [JRealValdes/jarvis](https://github.com/JRealValdes/jarvis).

## Layers (`lib/`)

| Layer | Role |
|-------|------|
| `screens/` / `widgets/` | Presentation |
| `agent/` | Backends + chat orchestration |
| `agent/remote/` | FastAPI client, JWT auth, configured base URL, failure classification |
| `domain/` | Pure chat state, prompts, models |
| `data/` | Secure storage, local credentials / remote session facades, message stores |
| `config/` | Defaults (models, seed message, timeouts, LAN fallback dart-define) |

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

`RemoteEndpoint` resolves the FastAPI base URL from Settings / Login (persisted). Auth (`/token`) and chat/admin calls share it; Basic vs Bearer headers stay in their callers.

Optional NTH: if the primary URL fails with a transport error, one short-timeout retry against `AppConfig.lanFallbackBaseUrl` (`JARVIS_LAN_FALLBACK_URL`, default `http://jarvis-raspberry.local:8000`).

Credentials are split by concern (same Keystore backend):

- `LocalCredentials` — OpenAI key, model, profile
- `RemoteSession` — JWT + login autofill + API base URL

Session Manager is **remote admin only** (JWT `admin` truthy), hidden while Auto is offline.

## Off-LAN reachability (Tailscale) (#11)

The app stores a single operator-configured base URL. It does **not** embed Tailscale, Firebase URL gossip, or ephemeral tunnel clients.

| Path | Base URL examples | Notes |
|------|-------------------|--------|
| Home LAN | `http://192.168.x.x:8000` | Same as #12 |
| Off-LAN (default) | `http://100.x.y.z:8000` or MagicDNS `http://jarvis-raspberry:8000` | Phone + Pi on the same tailnet; Tailscale app auto-connect |
| Alternative | Named Cloudflare Tunnel `https://…` | Documented on the backend only; no quick tunnels |

Auth remains Jarvis JWT against that base. Unreachable Tailscale host → same transport classification as an unreachable LAN host → Auto offline rules (#5) when an OpenAI key is set.

Operator steps: [README — Off-LAN](../README.md#off-lan-remote-access-tailscale) and backend [raspberry-pi-ops — Off-LAN](https://github.com/JRealValdes/jarvis/blob/main/docs/raspberry-pi-ops.md#off-lan-access-tailscale-31) ([jarvis#31](https://github.com/JRealValdes/jarvis/issues/31)).

## Modes

| Mode | When | Persistence |
|------|------|-------------|
| **Auto** (default) | Remote when reachable; offline OpenAI on transport failure | Offline turns ephemeral (memory only) |
| **Local only** | On-device OpenAI | Disk (sqflite) |
| **Remote only** | Home FastAPI (LAN or Tailscale base URL) | Server checkpointer |

Histories are **never** merged across modes or across remote ↔ offline cutover.

### Failover rules (Auto)

| Failure | Behavior |
|---------|----------|
| Timeout / socket / missing base URL | Enter offline if API key present; else Settings CTA |
| 401 / 403 | Auth error — do **not** enter offline |
| Other HTTP (e.g. 500) | Surface as error — do **not** auto-offline |

Persistent banner while offline: messages will not be saved.

Soft wait on `/ask`: after `remoteAskSoftWait` (12s), Auto shows *Keep waiting* / *Go offline*; hard ceiling is `remoteAskTimeout` (120s). Probe/auth/history stay on `remoteTransportTimeout` (8s).

## Remote API contract (audited vs jarvis `main`)

Requires a reachable Jarvis FastAPI at the operator-configured base URL (home LAN or Tailscale MagicDNS / `100.x`; see **#11** / [jarvis#31](https://github.com/JRealValdes/jarvis/issues/31)).

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

Timeouts: transport probe `remoteTransportTimeout` (8s); `/ask` `remoteAskTimeout` (120s) with soft-wait offer at `remoteAskSoftWait` (12s); LAN fallback `lanFallbackTimeout` (2s). Android cleartext HTTP is allowed for LAN and Tailscale `http://` bases.

On-device web search scrapes DuckDuckGo HTML with `jarvisSearchUserAgent` (browser-like); page fetch keeps `jarvisWebUserAgent` (JarvisBot) for robots/policy. Backend search uses the `ddgs` package instead of HTML scraping.

## Versioning

- App semver: `pubspec.yaml` (`1.5.0` after #12).
- Sideload APK: `.app_release/jarvis_<version>.apk` via `tooling/build_apk.ps1` / skill `build-apk`.
- Android `local.properties` `flutter.versionName` is gitignored and refreshed by Flutter tooling — ignore skew vs pubspec.

## Local agent parity (#6)

- Prompts: `domain/prompts.dart` tracks Python language + datetime/web-search rules; hostile path retained.
- On-device tools: calc, datetime, `web_search_tool` (DuckDuckGo HTML + public fetch with Glassdoor/SSRF policy).
- Server-only: calendar, speech, LinkedIn drafts/examples, job-preferences YAML.
- ID-protocol helpers in `chat_state.dart` kept for parity; unused while `validUser` is always true locally.

## Mobile / release tooling

- **#3:** Local emulator recipe — [docs/dev-mobile.md](dev-mobile.md).
- **#4:** Agent APK skill — `.cursor/skills/build-apk/` + `tooling/build_apk.ps1` → `.app_release/jarvis_<version>.apk` (debug-keystore sideload).
