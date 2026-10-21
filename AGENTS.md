# AGENTS.md

Guidance for ZCode agents working in this repository.

## Project

Yofardev Captioner — a Flutter **desktop-only** app (macOS, Linux, Windows; no mobile/web targets) for browsing folders of images and writing captions, with AI caption generation via user-configured third-party LLM APIs. Captions live in a `db.json` per folder (keyed by category); `.txt` sidecar files are only written on explicit export. Repo: `YofarDev/yofardev_captioner_flutter`.

## Commands

```bash
flutter pub get                                                # deps
flutter run                                                    # run (desktop)
dart run build_runner build --delete-conflicting-outputs       # REQUIRED after editing any json_serializable model
flutter test                                                   # all tests
flutter test test/features/captioning                          # focused: pass a path
dart fix --apply && dart format .                              # before finishing a change
./scripts/fverify.sh                                           # quality gate: format check + analyze + test (run before finishing)
flutter build macos --release                                  # also linux / windows
```

`scripts/` also ships advisory tools: `fimp.sh [--apply]` (fix broken imports; needs `uv`), `fanal.sh` (audit report), `fdead.sh` (possibly unreferenced files), `fcheck.sh` (unused deps). Their findings are heuristic — review before acting.

## Architecture

Feature-first BLoC/Cubit + Repository + get_it:

- `lib/features/<name>/{data,domain,presentation}` — self-contained features: `image_list`, `captioning`, `structured_captioning`, `llm_config`, `image_operations`, `caption_search`, `tab_manager`, `export`, `main_area`, `agent_api`. `data` = repositories/models/services, `domain` = pure models, repository interfaces, and feature services (no Flutter/get_it/bloc imports), `presentation` = `pages/`, `widgets/`, and `bloc/` (cubits + states, part files for state separation).
- Every feature exposes a public barrel `lib/features/<name>/<name>.dart` (domain types + public cubits/screens/widgets; never `data/` internals). Cross-feature imports may only target that barrel — enforced by `test/architecture_test.dart`, whose ratchet (`kKnownViolations` / `kKnownCycles`) may only shrink. Allowlist entries were narrowed to their exact surviving files in Phase 6 — never broaden a prefix; fix the violation or (only in an approved refactor phase) narrow further.
- `lib/core/` — shared code only: `di/service_locator.dart` (DI registration), `models/` (cross-cutting models: AppImage, CaptionEntry/Data/Database, LlmConfig(s), IdeogramCaption, StructuredBatchOverrides), `constants/` (colors etc.), `errors/`, `services/`, `utils/`, `widgets/` (reusable by 3+ features), `presentation/pages/home_page.dart`.
- `lib/helpers/` — helpers shared with tests.

Rules that matter when editing:

- Presentation must not import `data/` directly; go through cubits/repositories (cubits depend on domain repository interfaces such as `ILlmConfigRepository` / `ICaptioningRepository` where practical). Repositories return `Either<Failure, T>` (fpdart) instead of throwing; failures are classified once at the boundary (`lib/core/errors/`) and mapped to user text by `failureMessage`.
- Cross-feature access goes through the target feature's barrel, never its internal files.
- DI: everything registers in `lib/core/di/service_locator.dart` (there is no router — navigation is `home_page` + `routeObserver`). Access via `locator<Type>()`.
- Root cubits (`LlmConfigsCubit`, `TabManagerCubit`) are constructed once in `AppState.initState` (`lib/app.dart`) and provided via `BlocProvider.value` — deliberately NOT registered in the service locator. Live tab/session state for the Agent API flows through `TabSessionRegistry` (registered in the locator, shared with `TabManagerCubit`), never through cubit references.
- States use `Equatable`; models use `json_annotation` (hence the build_runner requirement).

## Conventions

- `analysis_options.yaml`: `always_specify_types: true` (annotate everything), `prefer_relative_imports` within `lib/`, package imports for external deps. Base is `package:lint`.
- Logging: `locator<Logger>()` — never `print` outside the root logger handler.
- Tests: `bloc_test` for cubits, `mockito` (`.mocks.dart` files are generated), `test/` mirrors `lib/`; raw test resources go in `test/test_resources/`.
- UI: dark Material 3 theme with a pink accent; all colors/radii come from `lib/core/constants/app_colors.dart` — no inline hex in widgets. Fonts: Orbitron (headings) / Inter (body).

## Agent API (sensitive area)

`lib/features/agent_api/` embeds a local REST API (shelf; binds `127.0.0.1`, default port 8765, bearer-token auth; port+token discovery file `agent-api.json` under the app's Application Support dir) plus a stdio MCP server at `tool/captioner_mcp.dart`. Historical design notes: `git show 9ea7bbc~1:CLAUDE.md` (the last version before the file was folded into this one). Tests: `test/features/agent_api/`.

**Never write a folder's `db.json` from outside the app while it runs** — the app rewrites the whole file from memory on every save, so external edits get clobbered. External writers must go through `POST /api/captions`.

## Gotchas

- `scripts/` was copied from the FlutterForge template and its README describes template features this app does not have: no l10n (`.arb`/`gen-l10n` — ignore those parts), no `.github/workflows` CI, no `lib/core/router/` (navigation is `home_page` + `routeObserver`). This app DOES have `test/architecture_test.dart` (feature-boundary ratchet) and `lib/core/di/service_locator.dart` — wire new types there. `fgen.sh` scaffolding works, but its printed wiring steps reference template paths — wire into `lib/core/di/service_locator.dart` instead.
- `analysis_options.yaml` excludes `*.g.dart`, `build/`, and the `macos/ linux/ windows/` platform dirs.
- `file_picker` v13: `saveFile` returns a `Uri` (not a String) — platform-specific handling in export code.
- macOS needs secure bookmarks (`macos_secure_bookmarks`) for sustained access to user-picked folders.

## Docs worth reading

- `README.md` — user-facing feature overview (multi-category captions, structured captioning, export).
- `docs/plans/` — design/implementation plans (features-oriented migration, multi-category captions).
- `scripts/README.md` — toolchain reference (see Gotchas for the template mismatch).
