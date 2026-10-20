# Agent API — embedded local REST API for AI agents

## Goal
Let external agents (Claude Code, ZCode, scripts) caption images with **their own vision** directly into the app's data structure, and read the app's saved prompts. A `shelf` server embedded in the running app, bound to `127.0.0.1` only, authenticated with a random bearer token. Enabled by default (user's choice).

**Why an in-app API instead of agents editing `db.json` directly:** the app rewrites the whole `db.json` from in-memory state on every mutation (`ImageListCubit._saveDb`) and does not watch the filesystem — an external writer gets silently clobbered. Routing writes through the running app eliminates that, keeps the UI live, and exposes prompts (currently stuck in SharedPreferences/`LlmConfigsCubit`).

## Endpoints (all JSON)

| Method + path | Auth | Returns / does |
|---|---|---|
| `GET /api/health` | none | `{"status":"ok","app":"yofardev_captioner","version":"…"}` (version via `package_info_plus`) — lets agents probe |
| `GET /api/prompts` | token | `{"prompts":[…],"selectedPrompt":"…"}` from `LlmConfigsCubit.state.llmConfigs`, falling back to `LlmConfigService.loadLlmConfigs()` |
| `GET /api/folders` | token | Open tabs: `[{id, folderPath, displayName, active}]` |
| `GET /api/images?folder=/abs/path` | token | Categories, activeCategory, and per image: `id, filename, absolute path, captions (per category), tags, guidance`. Works for open tabs (live state) **and** arbitrary folders (disk scan + `AppFileUtils.readDb`) |
| `POST /api/captions` | token | Body `{folder, filename, text, category?=default, model?="agent", tags?=merge}` → writes caption (see write logic below). 404 if image not on disk, 400 with valid categories if unknown category |
| `POST /api/folders/refresh` | token | Body `{folder}` → forces `onFolderPicked(force: true)` on the open tab (picks up externally added/renamed images) |

Auth: `Authorization: Bearer <token>` on everything except `/api/health`; `401` otherwise.

**Discovery file:** on server start, write `<ApplicationSupport>/agent-api.json` with `{"port", "token", "pid"}` (path via `path_provider`); delete on stop. This is how an agent finds port+token without asking. Exact path also shown in the settings panel and documented in `CLAUDE.md`.

## Write logic (`POST /api/captions`) — the core design
1. **Folder open in a tab** (`TabManagerCubit.findTabByFolderPath` → `getCubitForTab`): find image by filename in cubit state, apply `copyWith(captions: {…, category: CaptionEntry(text, model, timestamp: now, isEdited: false)})`, call `updateImage(image)` — in-memory state stays authoritative, UI updates, existing single write path persists.
2. **Folder not open**: direct read-modify-write via `AppFileUtils.readDb` + `writeDb` (match by filename; create `CaptionData` with fresh uuid if the image file exists but has no entry). Safe because no cubit holds that folder; the entry is picked up when the user later opens it.

New `CaptionEntry` fields: `model` from payload (default `"agent"`), `isEdited: false`, `timestamp: now`.

## Files

**New**
- `lib/features/agent_api/data/services/agent_api_service.dart` — lifecycle (start/stop), token/port management, discovery file, `shelf_router` routes, auth middleware, both write paths, logger via `locator<Logger>()`.
- `lib/features/agent_api/presentation/widgets/agent_api_panel.dart` — settings UI: enable toggle (`_PinkSwitch` style), status line (running/stopped + port), port field, token with copy button, ready-to-paste curl example. Local `setState`, no cubit (too small to justify one).
- `test/features/agent_api/data/services/agent_api_service_test.dart` — real server on ephemeral port 0, `http` client, temp-dir fixtures (mirroring `app_file_utils_test`): health w/o auth; 401 with bad/missing token; prompts; image list for unopened folder; caption write to unopened folder asserts db.json content and schema; refresh endpoint.

**Modified**
- `pubspec.yaml` — add `shelf`, `shelf_router`.
- `lib/core/services/cache_service.dart` — keys `agentApiEnabled` (bool, default **true**), `agentApiPort` (int, default 8765), `agentApiToken` (string, generated uuid on first load). Same static getter/setter style.
- `lib/core/config/service_locator.dart` — register `AgentApiService` (lazy singleton) and `AppFileUtils` (lazy singleton, for the direct write path).
- `lib/main.dart` — after `setupLocator()`: if enabled, `locator<AgentApiService>().start()`. In `MyApp`, create `TabManagerCubit` + `LlmConfigsCubit` instances, register them in get_it (guarded with `isRegistered`), then `BlocProvider.value` — this bridges widget-tree cubits to the get_it service. Handlers tolerate "not yet registered" with a 503.
- `lib/features/llm_config/presentation/pages/llm_settings_screen.dart` — add a third tab "Agent API" hosting the panel.
- `CLAUDE.md` — new `## Agent API` section (after Key Features Implementation, matching its H2/H3 style): endpoints, auth, discovery-file location per OS, the write-coordination caveat, and a worked agent workflow ("caption every image in X using prompt Y" via curl).

**No changes needed**: macOS entitlements (app-sandbox is not enabled, so binding localhost is already allowed); Linux/Windows runners have nothing blocking; no `build_runner` run needed (no new json_serializable models — responses hand-encoded, `CaptionEntry.toJson` reused).

## Verification
1. `flutter analyze` and `flutter test` clean.
2. Manual: run app (debug), `curl /api/health`, read token from discovery file, `GET /api/prompts`, POST a caption to a folder open in a tab (verify UI updates live), POST to a folder not open (verify db.json diff), confirm `POST /api/folders/refresh` picks up a newly added image.