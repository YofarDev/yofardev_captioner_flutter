# Features-Oriented Architecture Migration Plan (Revised)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate from layer-based architecture (logic/, models/, repositories/, screens/) to feature-oriented architecture (features/ with data/logic/presentation layers per feature) for better code organization, scalability, and maintainability.

**Architecture:** Reorganize code by business feature instead of technical layer. Each feature becomes a self-contained module with its own data (repositories, DTOs), logic (BLoCs/Cubits, business logic), and presentation (UI) layers. Shared utilities live in a core/ module.

**Tech Stack:** Flutter 3.9.2, BLoC pattern, get_it DI, Dart 3.9

---

## Current Structure
```
lib/
├── logic/              # BLoCs (captioning, image_operations, images_list, llm_config)
├── models/             # Data models (app_image, caption, llm_config, etc.)
├── repositories/       # Data access (caption_repository, captioning_repository)
├── services/           # Business services + DI
├── screens/            # UI (home, list, main, settings)
├── utils/              # Utilities
└── res/                # Constants, colors
```

## Target Structure
```
lib/
├── features/
│   ├── image_list/         # Feature: Load, navigate, sort images
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   └── models/
│   │   ├── logic/          # BLoCs/Cubits + states
│   │   └── presentation/
│   │       ├── pages/      # Full-screen widgets
│   │       └── widgets/    # Reusable feature widgets
│   ├── captioning/         # Feature: AI caption generation
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   ├── models/
│   │   │   └── services/   # Feature-specific business services
│   │   ├── logic/
│   │   └── presentation/
│   │       ├── pages/
│   │       └── widgets/
│   ├── image_operations/   # Feature: Crop, resize, convert
│   │   ├── data/
│   │   ├── logic/
│   │   └── presentation/
│   ├── llm_config/         # Feature: LLM settings
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   └── models/
│   │   ├── logic/
│   │   └── presentation/
│   ├── main_area/          # Feature: Main content area
│   │   └── presentation/
│   └── export/             # Feature: Export functionality
│       └── presentation/
├── core/                   # Shared code
│   ├── config/             # DI setup
│   │   └── service_locator.dart
│   ├── constants/          # App-wide constants, colors
│   ├── services/           # Infrastructure (cache, storage)
│   ├── utils/              # Shared utilities
│   ├── widgets/            # Truly reusable widgets
│   └── presentation/       # Core pages (home page)
└── main.dart
```

---

## Phase 0: Pre-Migration Preparation

### Task 0: Setup safety net and baseline

**Goal:** Create rollback point and establish working baseline before migration.

**Step 1: Save current state**

```bash
# Tag current commit for easy rollback
git tag -a pre-migration -m "Before feature-oriented architecture migration"

# Create feature branch
git checkout -b feature/architecture-migration

# Verify we're on clean baseline
flutter pub get
flutter analyze
flutter test
```

Expected: All tests pass, no analysis errors

**Step 2: Document current test state**

```bash
# Save test results
flutter test --coverage > test-baseline.txt

# Document current file count
find lib -name "*.dart" | grep -v ".g.dart" | wc -l > baseline-file-count.txt
```

**Step 3: Commit preparation**

```bash
git add test-baseline.txt baseline-file-count.txt
git commit -m "chore: establish migration baseline"
```

---

## Phase 1: Setup Core Foundation

### Task 1: Create core directory structure

**Files:**
- Create: `lib/core/config/`
- Create: `lib/core/constants/`
- Create: `lib/core/services/`
- Create: `lib/core/utils/`
- Create: `lib/core/widgets/`

**Step 1: Create core directories**

```bash
mkdir -p lib/core/config lib/core/constants lib/core/services lib/core/utils lib/core/widgets
```

Expected: Directories created

**Step 2: Move service locator to core**

```bash
mv lib/services/service_locator.dart lib/core/config/service_locator.dart
```

**Step 3: Move constants to core**

```bash
mv lib/res/app_constants.dart lib/core/constants/app_constants.dart
mv lib/res/app_colors.dart lib/core/constants/app_colors.dart
```

**Step 4: Move truly shared services to core**

**Criteria for core/services:** Infrastructure-level services used by multiple features (cache, storage, logging). NOT feature-specific business services.

```bash
mv lib/services/cache_service.dart lib/core/services/cache_service.dart
```

**Note:** `caption_service.dart` and `llm_config_service.dart` will move to their respective features later.

**Step 5: Move truly shared widgets to core**

**Criteria:** Widgets used across 3+ unrelated features.

```bash
# Check if app_button exists and is widely used
mv lib/screens/widgets/app_button.dart lib/core/widgets/app_button.dart 2>/dev/null || echo "No shared widgets to move"
```

**Step 6: Move shared utils to core**

```bash
mv lib/utils/extensions.dart lib/core/utils/extensions.dart
```

**Step 7: Update service_locator imports**

Read: `lib/core/config/service_locator.dart`

Update imports to reflect new core structure:
- All core imports should use relative paths within core

**Step 8: Commit**

```bash
git add lib/core/
git add lib/services/service_locator.dart lib/res/ lib/screens/widgets/ lib/utils/extensions.dart
git commit -m "refactor: create core module structure and move shared code"
```

---

### Task 2: Update all imports for moved core files

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/**/*.dart`

**Step 1: Update main.dart imports**

Read: `lib/main.dart`

Find and replace:
- `import 'services/service_locator.dart';` → `import 'core/config/service_locator.dart';`
- `import 'res/app_colors.dart';` → `import 'core/constants/app_colors.dart';`
- `import 'res/app_constants.dart';` → `import 'core/constants/app_constants.dart';`

**Step 2: Update service_locator imports in all files**

```bash
grep -r "import.*services/service_locator" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file found:
- `import 'services/service_locator.dart';` → `import 'core/config/service_locator.dart';`
- `import '../services/service_locator.dart';` → `import 'core/config/service_locator.dart';`

**Step 3: Update all imports for app_colors**

```bash
grep -r "import.*res/app_colors" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file:
- `import '../res/app_colors.dart';` → `import 'core/constants/app_colors.dart';`
- `import 'res/app_colors.dart';` → `import 'core/constants/app_colors.dart';`

**Step 4: Update imports for app_constants**

```bash
grep -r "import.*res/app_constants" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update import path to `core/constants/app_constants.dart`.

**Step 5: Update imports for cache_service**

```bash
grep -r "import.*services/cache_service" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `core/services/cache_service.dart`.

**Step 6: Update service_locator registrations**

Read: `lib/core/config/service_locator.dart`

Update all registration paths to match new core structure.

**Step 7: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 8: Run tests**

```bash
flutter test
```

Expected: All tests pass

**Step 9: Commit**

```bash
git add -A
git commit -m "refactor: update imports for core module restructure"
```

---

## Phase 2: Migrate Image List Feature

### Task 3: Create image_list feature structure

**Files:**
- Create: `lib/features/image_list/data/repositories/`
- Create: `lib/features/image_list/data/models/`
- Create: `lib/features/image_list/logic/`
- Create: `lib/features/image_list/presentation/pages/`
- Create: `lib/features/image_list/presentation/widgets/`
- Create: `test/features/image_list/`

**Step 1: Create directories**

```bash
mkdir -p lib/features/image_list/{data/{repositories,models},logic,presentation/{pages,widgets}}
mkdir -p test/features/image_list/{data,logic,presentation}
```

**Step 2: Move image list models**

```bash
mv lib/models/app_image.dart lib/features/image_list/data/models/app_image.dart
mv lib/models/app_image.g.dart lib/features/image_list/data/models/app_image.g.dart 2>/dev/null || true
```

**Step 3: Regenerate JSON serialization**

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

Expected: `app_image.g.dart` regenerated in new location

**Step 4: Move image list BLoC**

```bash
mv lib/logic/images_list/image_list_cubit.dart lib/features/image_list/logic/image_list_cubit.dart
mv lib/logic/images_list/image_list_state.dart lib/features/image_list/logic/image_list_state.dart
```

**Step 5: Move image list UI**

```bash
mv lib/screens/list/images_list_view.dart lib/features/image_list/presentation/pages/images_list_view.dart
mv lib/screens/list/header_widget.dart lib/features/image_list/presentation/widgets/header_widget.dart
mv lib/screens/list/sort_by_widget.dart lib/features/image_list/presentation/widgets/sort_by_widget.dart
```

**Step 6: Move image list utils/repositories**

```bash
mv lib/utils/app_file_utils.dart lib/features/image_list/data/repositories/app_file_utils.dart
```

**Step 7: Move image list tests**

```bash
# Find and move image_list related tests
find test/logic -name "*image_list*" -exec mv {} test/features/image_list/logic/ \; 2>/dev/null || true
find test/models -name "*app_image*" -exec mv {} test/features/image_list/data/ \; 2>/dev/null || true
```

**Step 8: Commit**

```bash
git add lib/features/image_list/ test/features/image_list/
git commit -m "refactor: move image_list feature to new structure"
```

---

### Task 4: Update image_list imports and tests

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/home_page.dart`
- Modify: `lib/core/config/service_locator.dart`
- Modify: `lib/features/image_list/**/*.dart`
- Modify: `test/features/image_list/**/*.dart`
- Modify: All files importing image_list components

**Step 1: Update internal imports within image_list feature**

For each file in `lib/features/image_list/`, update relative imports:

Files to update:
- `lib/features/image_list/presentation/pages/images_list_view.dart`
- `lib/features/image_list/presentation/widgets/header_widget.dart`
- `lib/features/image_list/presentation/widgets/sort_by_widget.dart`
- `lib/features/image_list/logic/image_list_cubit.dart`

Update relative imports:
- To logic: `import '../../logic/image_list_cubit.dart';`
- To models: `import '../../data/models/app_image.dart';`
- To repositories: `import '../../data/repositories/app_file_utils.dart';`

**Step 2: Update main.dart imports**

In `lib/main.dart`:
- `import 'logic/images_list/image_list_cubit.dart';` → `import 'features/image_list/logic/image_list_cubit.dart';`

**Step 3: Update home_page.dart imports**

In `lib/screens/home_page.dart`:
- `import '../logic/images_list/image_list_cubit.dart';` → `import 'features/image_list/logic/image_list_cubit.dart';`
- `import 'list/images_list_view.dart';` → `import 'features/image_list/presentation/pages/images_list_view.dart';`

**Step 4: Update service_locator registrations**

In `lib/core/config/service_locator.dart`:
- Update `ImageListCubit` registration if needed
- Update repository registrations to new paths

**Step 5: Update all external imports to image_list components**

```bash
grep -r "import.*models/app_image" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file:
- Update to: `import 'features/image_list/data/models/app_image.dart';`

```bash
grep -r "import.*logic/images_list" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file:
- Update to: `import 'features/image_list/logic/image_list_cubit.dart';`

**Step 6: Update test imports**

```bash
grep -r "import.*models/app_image" test/ --include="*.dart" | grep -v ".g.dart"
grep -r "import.*logic/images_list" test/ --include="*.dart" | grep -v ".g.dart"
```

For each test file, update imports to match new structure:
- `import 'package:yofardev_captioner/models/app_image.dart';` → `import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';`
- `import 'package:yofardev_captioner/logic/images_list/image_list_cubit.dart';` → `import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';`

**Step 7: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 8: Run image_list tests**

```bash
flutter test test/features/image_list/
```

Expected: All image_list tests pass

**Step 9: Run full test suite**

```bash
flutter test
```

Expected: All tests pass

**Step 10: Smoke test image_list feature**

```bash
flutter run -d macos
```

Test:
1. Drag and drop image folder
2. Navigate between images
3. Sort images
4. Filter images

Expected: Image list functionality works

**Step 11: Commit**

```bash
git add -A
git commit -m "refactor: update imports for image_list feature"
```

---

## Phase 3: Migrate Captioning Feature

### Task 5: Create captioning feature structure

**Files:**
- Create: `lib/features/captioning/data/repositories/`
- Create: `lib/features/captioning/data/models/`
- Create: `lib/features/captioning/data/services/`
- Create: `lib/features/captioning/logic/`
- Create: `lib/features/captioning/presentation/pages/`
- Create: `lib/features/captioning/presentation/widgets/`
- Create: `test/features/captioning/`

**Step 1: Create directories**

```bash
mkdir -p lib/features/captioning/{data/{repositories,models,services},logic,presentation/{pages,widgets}}
mkdir -p test/features/captioning/{data,logic,presentation}
```

**Step 2: Move caption models**

```bash
mv lib/models/caption/ lib/features/captioning/data/models/caption/
mv lib/models/caption_data.dart lib/features/captioning/data/models/caption_data.dart
mv lib/models/caption_database.dart lib/features/captioning/data/models/caption_database.dart
mv lib/models/caption_options.dart lib/features/captioning/data/models/caption_options.dart
```

**Step 3: Move .g.dart files for caption models**

```bash
find lib/models -name "*.g.dart" -exec mv {} lib/features/captioning/data/models/ \; 2>/dev/null || true
```

**Step 4: Regenerate JSON serialization**

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

Expected: All .g.dart files regenerated in new locations

**Step 5: Move caption repositories**

```bash
mv lib/repositories/caption_repository.dart lib/features/captioning/data/repositories/caption_repository.dart
mv lib/repositories/captioning_repository.dart lib/features/captioning/data/repositories/captioning_repository.dart
```

**Step 6: Move caption service to feature (NOT core)**

**Rationale:** `caption_service` is feature-specific business logic, not infrastructure. Keep it in captioning feature.

```bash
mv lib/services/caption_service.dart lib/features/captioning/data/services/caption_service.dart
```

**Step 7: Move captioning BLoC**

```bash
mv lib/logic/captioning/captioning_cubit.dart lib/features/captioning/logic/captioning_cubit.dart
mv lib/logic/captioning/captioning_state.dart lib/features/captioning/logic/captioning_state.dart
```

**Step 8: Move captioning UI**

```bash
mv lib/screens/main/caption_controls.dart lib/features/captioning/presentation/widgets/caption_controls.dart
mv lib/screens/main/caption_text_area.dart lib/features/captioning/presentation/widgets/caption_text_area.dart
```

**Step 9: Move captioning utils**

```bash
mv lib/utils/caption_utils.dart lib/features/captioning/data/repositories/caption_utils.dart
```

**Step 10: Move captioning tests**

```bash
find test/logic -name "*captioning*" -exec mv {} test/features/captioning/logic/ \; 2>/dev/null || true
find test/repositories -name "*caption*" -exec mv {} test/features/captioning/data/ \; 2>/dev/null || true
find test/models -name "*caption*" -exec mv {} test/features/captioning/data/ \; 2>/dev/null || true
```

**Step 11: Commit**

```bash
git add lib/features/captioning/ test/features/captioning/
git commit -m "refactor: move captioning feature to new structure"
```

---

### Task 6: Update captioning imports and service_locator

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/core/config/service_locator.dart`
- Modify: `lib/screens/main/main_area_view.dart`
- Modify: `lib/features/captioning/**/*.dart`
- Modify: `test/features/captioning/**/*.dart`
- Modify: All files importing captioning components

**Step 1: Update internal imports within captioning feature**

For each file in `lib/features/captioning/`, update relative imports:
- Logic to models: `import '../../data/models/...';`
- Logic to repositories: `import '../../data/repositories/...';`
- Logic to services: `import '../../data/services/...';`
- UI to logic: `import '../../logic/...';`

**Step 2: Update main.dart captioning import**

In `lib/main.dart`:
- `import 'logic/captioning/captioning_cubit.dart';` → `import 'features/captioning/logic/captioning_cubit.dart';`

**Step 3: Update main_area_view imports**

In `lib/screens/main/main_area_view.dart`:
- `import '../main/caption_controls.dart';` → `import 'features/captioning/presentation/widgets/caption_controls.dart';`
- `import '../main/caption_text_area.dart';` → `import 'features/captioning/presentation/widgets/caption_text_area.dart';`

**Step 4: Update service_locator registrations**

In `lib/core/config/service_locator.dart`:

Update captioning registrations:
```dart
// Before
import '../repositories/caption_repository.dart';
import '../repositories/captioning_repository.dart';
import '../services/caption_service.dart';

// After
import '../../features/captioning/data/repositories/caption_repository.dart';
import '../../features/captioning/data/repositories/captioning_repository.dart';
import '../../features/captioning/data/services/caption_service.dart';
```

**Step 5: Update all external imports to captioning components**

```bash
grep -r "import.*logic/captioning" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to feature path.

```bash
grep -r "import.*repositories/caption" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/captioning/data/repositories/...`

```bash
grep -r "import.*services/caption_service" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file:
- `import '../services/caption_service.dart';` → `import 'features/captioning/data/services/caption_service.dart';`

```bash
grep -r "import.*models/caption" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/captioning/data/models/...`

```bash
grep -r "import.*utils/caption_utils" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/captioning/data/repositories/caption_utils.dart`

**Step 6: Update test imports**

```bash
grep -r "import.*logic/captioning" test/ --include="*.dart" | grep -v ".g.dart"
grep -r "import.*repositories/caption" test/ --include="*.dart" | grep -v ".g.dart"
grep -r "import.*models/caption" test/ --include="*.dart" | grep -v ".g.dart"
```

For each test file, update imports to new structure.

**Step 7: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 8: Run captioning tests**

```bash
flutter test test/features/captioning/
```

Expected: All captioning tests pass

**Step 9: Run full test suite**

```bash
flutter test
```

Expected: All tests pass

**Step 10: Smoke test captioning feature**

```bash
flutter run -d macos
```

Test:
1. Open an image
2. Add caption manually
3. Generate AI caption
4. Edit caption
5. Navigate to next image (caption saves)

Expected: Captioning functionality works

**Step 11: Commit**

```bash
git add -A
git commit -m "refactor: update imports for captioning feature"
```

---

## Phase 4: Migrate Image Operations Feature

### Task 7: Create image_operations feature structure

**Files:**
- Create: `lib/features/image_operations/data/models/`
- Create: `lib/features/image_operations/data/utils/`
- Create: `lib/features/image_operations/logic/`
- Create: `lib/features/image_operations/presentation/pages/`
- Create: `lib/features/image_operations/presentation/widgets/`
- Create: `test/features/image_operations/`

**Step 1: Create directories**

```bash
mkdir -p lib/features/image_operations/{data/{models,utils},logic,presentation/{pages,widgets}}
mkdir -p test/features/image_operations/{data,logic,presentation}
```

**Step 2: Move image operations models**

```bash
mv lib/models/crop_image.dart lib/features/image_operations/data/models/crop_image.dart
```

**Step 3: Regenerate JSON serialization (if needed)**

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Step 4: Move image operations BLoC**

```bash
mv lib/logic/image_operations/image_operations_cubit.dart lib/features/image_operations/logic/image_operations_cubit.dart
mv lib/logic/image_operations/image_operations_state.dart lib/features/image_operations/logic/image_operations_state.dart
```

**Step 5: Move image operations UI**

```bash
mv lib/screens/main/crop_image_screen.dart lib/features/image_operations/presentation/pages/crop_image_screen.dart
mv lib/screens/main/aspect_ratio_dialog.dart lib/features/image_operations/presentation/pages/aspect_ratio_dialog.dart
mv lib/screens/main/convert_images_dialog.dart lib/features/image_operations/presentation/pages/convert_images_dialog.dart
mv lib/screens/main/controls_view.dart lib/features/image_operations/presentation/widgets/controls_view.dart
mv lib/screens/main/controls_widgets.dart lib/features/image_operations/presentation/widgets/controls_widgets.dart
```

**Step 6: Move image operations utils**

```bash
mv lib/utils/image_utils.dart lib/features/image_operations/data/utils/image_utils.dart
mv lib/utils/bash_scripts_runner.dart lib/features/image_operations/data/utils/bash_scripts_runner.dart
```

**Step 7: Move image_operations tests**

```bash
find test/logic -name "*image_operations*" -exec mv {} test/features/image_operations/logic/ \; 2>/dev/null || true
find test/utils -name "*image*" -exec mv {} test/features/image_operations/data/ \; 2>/dev/null || true
```

**Step 8: Commit**

```bash
git add lib/features/image_operations/ test/features/image_operations/
git commit -m "refactor: move image_operations feature to new structure"
```

---

### Task 8: Update image_operations imports

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/image_operations/**/*.dart`
- Modify: `test/features/image_operations/**/*.dart`
- Modify: All files importing image_operations components

**Step 1: Update internal imports within image_operations feature**

For each file in `lib/features/image_operations/`, update relative imports:
- Logic to models: `import '../../data/models/...';`
- Logic to utils: `import '../../data/utils/...';`
- UI to logic: `import '../../logic/...';`
- UI to utils: `import '../../data/utils/...';`

**Step 2: Update main.dart image_operations import**

In `lib/main.dart`:
- `import 'logic/image_operations/image_operations_cubit.dart';` → `import 'features/image_operations/logic/image_operations_cubit.dart';`

**Step 3: Update all external imports to image_operations components**

```bash
grep -r "import.*logic/image_operations" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to feature path.

```bash
grep -r "import.*models/crop_image" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/image_operations/data/models/...`

```bash
grep -r "import.*utils/image_utils" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/image_operations/data/utils/image_utils.dart`

```bash
grep -r "import.*utils/bash_scripts_runner" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/image_operations/data/utils/bash_scripts_runner.dart`

**Step 4: Update test imports**

```bash
grep -r "import.*logic/image_operations" test/ --include="*.dart" | grep -v ".g.dart"
grep -r "import.*utils/image" test/ --include="*.dart" | grep -v ".g.dart"
```

For each test file, update imports to new structure.

**Step 5: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 6: Run image_operations tests**

```bash
flutter test test/features/image_operations/
```

Expected: All image_operations tests pass

**Step 7: Run full test suite**

```bash
flutter test
```

Expected: All tests pass

**Step 8: Smoke test image_operations feature**

```bash
flutter run -d macos
```

Test:
1. Open an image
2. Crop image
3. Resize image
4. Convert image format
5. Batch convert multiple images

Expected: Image operations work correctly

**Step 9: Commit**

```bash
git add -A
git commit -m "refactor: update imports for image_operations feature"
```

---

## Phase 5: Migrate LLM Config Feature

### Task 9: Create llm_config feature structure

**Files:**
- Create: `lib/features/llm_config/data/models/`
- Create: `lib/features/llm_config/data/repositories/`
- Create: `lib/features/llm_config/logic/`
- Create: `lib/features/llm_config/presentation/pages/`
- Create: `test/features/llm_config/`

**Step 1: Create directories**

```bash
mkdir -p lib/features/llm_config/{data/{models,repositories},logic,presentation/pages}
mkdir -p test/features/llm_config/{data,logic,presentation}
```

**Step 2: Move LLM config models**

```bash
mv lib/models/llm_config.dart lib/features/llm_config/data/models/llm_config.dart
mv lib/models/llm_configs.dart lib/features/llm_config/data/models/llm_configs.dart
mv lib/models/llm_provider_type.dart lib/features/llm_config/data/models/llm_provider_type.dart
```

**Step 3: Regenerate JSON serialization**

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Step 4: Move LLM config service (feature-specific, NOT infrastructure)**

**Rationale:** `llm_config_service` is business logic for LLM configuration, not infrastructure. Keep in feature.

```bash
mv lib/services/llm_config_service.dart lib/features/llm_config/data/repositories/llm_config_service.dart
```

**Step 5: Move LLM config BLoC**

```bash
mv lib/logic/llm_config/llm_configs_cubit.dart lib/features/llm_config/logic/llm_configs_cubit.dart
mv lib/logic/llm_config/llm_configs_state.dart lib/features/llm_config/logic/llm_configs_state.dart
```

**Step 6: Move LLM config UI**

```bash
mv lib/screens/settings/llm_settings_screen.dart lib/features/llm_config/presentation/pages/llm_settings_screen.dart
mv lib/screens/main/llm_config_widget.dart lib/features/llm_config/presentation/pages/llm_config_widget.dart
```

**Step 7: Move llm_config tests**

```bash
find test/logic -name "*llm_config*" -exec mv {} test/features/llm_config/logic/ \; 2>/dev/null || true
find test -name "*llm*" -exec mv {} test/features/llm_config/data/ \; 2>/dev/null || true
```

**Step 8: Commit**

```bash
git add lib/features/llm_config/ test/features/llm_config/
git commit -m "refactor: move llm_config feature to new structure"
```

---

### Task 10: Update llm_config imports and service_locator

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/core/config/service_locator.dart`
- Modify: `lib/features/llm_config/**/*.dart`
- Modify: `test/features/llm_config/**/*.dart`
- Modify: All files importing llm_config components

**Step 1: Update internal imports within llm_config feature**

For each file in `lib/features/llm_config/`, update relative imports:
- Logic to models: `import '../../data/models/...';`
- Logic to repositories: `import '../../data/repositories/...';`
- UI to logic: `import '../../logic/...';`

**Step 2: Update main.dart llm_config import**

In `lib/main.dart`:
- `import 'logic/llm_config/llm_configs_cubit.dart';` → `import 'features/llm_config/logic/llm_configs_cubit.dart';`

**Step 3: Update service_locator imports and registrations**

In `lib/core/config/service_locator.dart`:

Update imports:
```dart
// Before
import '../services/llm_config_service.dart';

// After
import '../../features/llm_config/data/repositories/llm_config_service.dart';
```

Update registration path if needed.

**Step 4: Update all external imports to llm_config components**

```bash
grep -r "import.*models/llm" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/llm_config/data/models/...`

```bash
grep -r "import.*services/llm_config_service" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file:
- Update to `features/llm_config/data/repositories/llm_config_service.dart`

```bash
grep -r "import.*logic/llm_config" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/llm_config/logic/...`

**Step 5: Update test imports**

```bash
grep -r "import.*logic/llm_config" test/ --include="*.dart" | grep -v ".g.dart"
grep -r "import.*models/llm" test/ --include="*.dart" | grep -v ".g.dart"
```

For each test file, update imports to new structure.

**Step 6: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 7: Run llm_config tests**

```bash
flutter test test/features/llm_config/
```

Expected: All llm_config tests pass

**Step 8: Run full test suite**

```bash
flutter test
```

Expected: All tests pass

**Step 9: Smoke test llm_config feature**

```bash
flutter run -d macos
```

Test:
1. Open settings
2. Add new LLM configuration
3. Edit LLM configuration
4. Delete LLM configuration
5. Test caption generation with new config

Expected: LLM configuration works

**Step 10: Commit**

```bash
git add -A
git commit -m "refactor: update imports for llm_config feature"
```

---

## Phase 6: Migrate Remaining UI Components

### Task 11: Move main_area and export features

**Files:**
- Create: `lib/features/main_area/presentation/pages/`
- Create: `lib/features/export/presentation/widgets/`
- Create: `test/features/main_area/`
- Create: `test/features/export/`

**Step 1: Create directories**

```bash
mkdir -p lib/features/main_area/presentation/pages
mkdir -p lib/features/export/presentation/widgets
mkdir -p test/features/main_area/presentation
mkdir -p test/features/export/presentation
```

**Step 2: Move main area components**

```bash
mv lib/screens/main/main_area_view.dart lib/features/main_area/presentation/pages/main_area_view.dart
mv lib/screens/main/current_image_view.dart lib/features/main_area/presentation/pages/current_image_view.dart
mv lib/screens/main/search_and_replace_widget.dart lib/features/main_area/presentation/pages/search_and_replace_widget.dart
```

**Step 3: Move export button**

```bash
mv lib/screens/main/export_button.dart lib/features/export/presentation/widgets/export_button.dart
```

**Step 4: Move tests**

```bash
find test/screens -name "*main*" -o -name "*export*" | xargs -I {} mv {} test/features/main_area/presentation/ 2>/dev/null || true
```

**Step 5: Commit**

```bash
git add lib/features/main_area/ lib/features/export/ test/features/main_area/ test/features/export/
git commit -m "refactor: move main_area and export to features"
```

---

### Task 12: Update imports for main_area and export

**Files:**
- Modify: `lib/screens/home_page.dart`
- Modify: `lib/features/main_area/**/*.dart`
- Modify: `lib/features/export/**/*.dart`
- Modify: All files importing main_area or export components

**Step 1: Update home_page.dart imports**

In `lib/screens/home_page.dart`:
- `import 'main/main_area_view.dart';` → `import 'features/main_area/presentation/pages/main_area_view.dart';`

**Step 2: Update all imports to main_area components**

```bash
grep -r "import.*screens/main" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/main_area/presentation/pages/...`

**Step 3: Update export_button imports**

```bash
grep -r "import.*screens/main/export_button" lib/ --include="*.dart" | grep -v ".g.dart"
```

For each file, update to `features/export/presentation/widgets/export_button.dart`

**Step 4: Update test imports**

```bash
grep -r "import.*screens/main" test/ --include="*.dart" | grep -v ".g.dart"
```

For each test file, update imports.

**Step 5: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 6: Run tests**

```bash
flutter test
```

Expected: All tests pass

**Step 7: Commit**

```bash
git add -A
git commit -m "refactor: update imports for main_area and export features"
```

---

### Task 13: Move home page to core/presentation

**Files:**
- Create: `lib/core/presentation/pages/`
- Create: `test/core/presentation/`

**Step 1: Create directories**

```bash
mkdir -p lib/core/presentation/pages
mkdir -p test/core/presentation
```

**Step 2: Move home page**

```bash
mv lib/screens/home_page.dart lib/core/presentation/pages/home_page.dart
mv test/screens/home_page_test.dart test/core/presentation/home_page_test.dart 2>/dev/null || true
```

**Step 3: Update main.dart import**

In `lib/main.dart`:
- `import 'screens/home_page.dart';` → `import 'core/presentation/pages/home_page.dart';`

**Step 4: Update home_page imports**

Read: `lib/core/presentation/pages/home_page.dart`

Update imports:
- `import '../logic/images_list/image_list_cubit.dart';` → `import 'features/image_list/logic/image_list_cubit.dart';`
- `import '../res/app_colors.dart';` → `import 'core/constants/app_colors.dart';`
- `import 'list/images_list_view.dart';` → `import 'features/image_list/presentation/pages/images_list_view.dart';`
- `import 'main/main_area_view.dart';` → `import 'features/main_area/presentation/pages/main_area_view.dart';`

**Step 5: Update home_page test imports**

If test file exists, update imports to match new structure.

**Step 6: Verify compilation**

```bash
flutter analyze
```

Expected: No import errors

**Step 7: Run tests**

```bash
flutter test
```

Expected: All tests pass

**Step 8: Run app**

```bash
flutter run -d macos
```

Expected: App launches successfully, home page displays correctly

**Step 9: Commit**

```bash
git add -A
git commit -m "refactor: move home page to core/presentation"
```

---

## Phase 7: Final Cleanup and Polish

### Task 14: Remove empty old directories

**Files:**
- Remove: `lib/logic/`
- Remove: `lib/models/`
- Remove: `lib/repositories/`
- Remove: `lib/services/`
- Remove: `lib/screens/`
- Remove: `lib/utils/`
- Remove: `lib/res/`
- Remove: `test/logic/` (if empty)
- Remove: `test/models/` (if empty)
- Remove: `test/repositories/` (if empty)
- Remove: `test/screens/` (if empty)

**Step 1: Check for any remaining files**

```bash
find lib/logic lib/models lib/repositories lib/services lib/screens lib/utils lib/res -type f 2>/dev/null || echo "All lib directories empty"
find test/logic test/models test/repositories test/screens -type f 2>/dev/null || echo "All test directories empty"
```

Expected: No remaining files (only .g.dart which should be regenerated)

**Step 2: Manually verify no files were missed**

```bash
ls -la lib/logic/ 2>/dev/null || echo "lib/logic removed"
ls -la lib/models/ 2>/dev/null || echo "lib/models removed"
ls -la lib/repositories/ 2>/dev/null || echo "lib/repositories removed"
ls -la lib/services/ 2>/dev/null || echo "lib/services removed"
ls -la lib/screens/ 2>/dev/null || echo "lib/screens removed"
ls -la lib/utils/ 2>/dev/null || echo "lib/utils removed"
ls -la lib/res/ 2>/dev/null || echo "lib/res removed"
```

**Step 3: Note any remaining files for manual review**

If any files remain, review them manually to determine where they should go.

**Step 4: Remove empty directories**

```bash
rm -rf lib/logic lib/models lib/repositories lib/services lib/screens lib/utils lib/res
rm -rf test/logic test/models test/repositories test/screens 2>/dev/null || true
```

**Step 5: Verify structure**

```bash
tree lib -L 3 -I '.g.dart'
tree test -L 3 -I '.g.dart'
```

Expected: Clean feature-oriented structure

**Step 6: Regenerate all JSON serialization**

```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

Expected: All .g.dart files regenerated in new locations

**Step 7: Verify compilation**

```bash
flutter analyze
```

Expected: No errors

**Step 8: Run full test suite**

```bash
flutter test --coverage
```

Expected: All tests pass, coverage maintained from baseline

**Step 9: Compare file counts**

```bash
find lib -name "*.dart" | grep -v ".g.dart" | wc -l
cat baseline-file-count.txt
```

Expected: Similar file count (may vary slightly)

**Step 10: Build for macOS (primary platform)**

```bash
flutter build macos --release
```

Expected: Successful build

**Step 11: Commit**

```bash
git add -A
git commit -m "refactor: remove old directory structure"
```

---

### Task 15: Update CLAUDE.md with new structure

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update architecture section**

Read: `CLAUDE.md`

Replace the "Key Directories" section with:

```markdown
### Key Directories

- `lib/features/` - Business features (self-contained modules)
  - `image_list/` - Image loading, navigation, sorting
    - `data/` - Repositories, models
    - `logic/` - BLoC business logic (Cubits + states)
    - `presentation/` - UI components (pages, widgets)
  - `captioning/` - AI caption generation
    - `data/` - Repositories, models, services
    - `logic/` - BLoC business logic
    - `presentation/` - UI widgets
  - `image_operations/` - Crop, resize, convert
    - `data/` - Models, utils
    - `logic/` - BLoC business logic
    - `presentation/` - UI pages and widgets
  - `llm_config/` - LLM API configuration
    - `data/` - Repositories, models
    - `logic/` - BLoC business logic
    - `presentation/` - UI pages
  - `main_area/` - Main content area
    - `presentation/` - UI pages
  - `export/` - Export functionality
    - `presentation/` - UI widgets
- `lib/core/` - Shared code
  - `config/` - Dependency injection setup
  - `constants/` - App-wide constants and colors
  - `services/` - Infrastructure services (cache, storage, logging)
  - `utils/` - Shared utilities
  - `widgets/` - Truly reusable widgets (used by 3+ features)
  - `presentation/` - Core pages (home page)

### State Management Flow

1. User actions trigger UI events in feature/presentation layer
2. Feature BLoCs/Cubits in logic/ handle business logic and emit state changes
3. UI rebuilds based on new state
4. Repositories in data/ handle external API calls and file system operations

**Primary Features:**
- `ImageListCubit` - Image loading, navigation, sorting, filtering (in features/image_list/logic/)
- `CaptioningCubit` - AI caption generation (in features/captioning/logic/)
- `ImageOperationsCubit` - Crop and resize operations (in features/image_operations/logic/)
- `LlmConfigsCubit` - Manages LLM API configurations (in features/llm_config/logic/)
```

**Step 2: Update code organization examples**

Update any examples in CLAUDE.md to use new structure.

**Step 3: Update dependency injection examples**

Update service_locator examples to show new paths.

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for feature-oriented architecture"
```

---

### Task 16: Create barrel exports for cleaner imports

**Rationale:** Barrel files (also called export files) provide a single entry point for each feature, making imports cleaner and refactoring easier.

**Files:**
- Create: `lib/features/image_list/image_list.dart`
- Create: `lib/features/captioning/captioning.dart`
- Create: `lib/features/image_operations/image_operations.dart`
- Create: `lib/features/llm_config/llm_config.dart`
- Create: `lib/features/main_area/main_area.dart`
- Create: `lib/features/export/export.dart`
- Create: `lib/core/core.dart`

**Step 1: Create image_list barrel file**

Write: `lib/features/image_list/image_list.dart`

```dart
// Data layer
export 'data/models/app_image.dart';
export 'data/repositories/app_file_utils.dart';

// Logic layer
export 'logic/image_list_cubit.dart';
export 'logic/image_list_state.dart';

// Presentation layer
export 'presentation/pages/header_widget.dart';
export 'presentation/pages/images_list_view.dart';
export 'presentation/widgets/sort_by_widget.dart';
```

**Step 2: Create captioning barrel file**

Write: `lib/features/captioning/captioning.dart`

```dart
// Data layer
export 'data/models/caption_data.dart';
export 'data/models/caption_database.dart';
export 'data/models/caption_options.dart';
export 'data/repositories/caption_repository.dart';
export 'data/repositories/captioning_repository.dart';
export 'data/repositories/caption_utils.dart';
export 'data/services/caption_service.dart';

// Logic layer
export 'logic/captioning_cubit.dart';
export 'logic/captioning_state.dart';

// Presentation layer
export 'presentation/widgets/caption_controls.dart';
export 'presentation/widgets/caption_text_area.dart';
```

**Step 3: Create image_operations barrel file**

Write: `lib/features/image_operations/image_operations.dart`

```dart
// Data layer
export 'data/models/crop_image.dart';
export 'data/utils/bash_scripts_runner.dart';
export 'data/utils/image_utils.dart';

// Logic layer
export 'logic/image_operations_cubit.dart';
export 'logic/image_operations_state.dart';

// Presentation layer
export 'presentation/pages/aspect_ratio_dialog.dart';
export 'presentation/pages/convert_images_dialog.dart';
export 'presentation/pages/crop_image_screen.dart';
export 'presentation/widgets/controls_view.dart';
export 'presentation/widgets/controls_widgets.dart';
```

**Step 4: Create llm_config barrel file**

Write: `lib/features/llm_config/llm_config.dart`

```dart
// Data layer
export 'data/models/llm_config.dart';
export 'data/models/llm_configs.dart';
export 'data/models/llm_provider_type.dart';
export 'data/repositories/llm_config_service.dart';

// Logic layer
export 'logic/llm_configs_cubit.dart';
export 'logic/llm_configs_state.dart';

// Presentation layer
export 'presentation/pages/llm_config_widget.dart';
export 'presentation/pages/llm_settings_screen.dart';
```

**Step 5: Create main_area barrel file**

Write: `lib/features/main_area/main_area.dart`

```dart
// Presentation layer
export 'presentation/pages/current_image_view.dart';
export 'presentation/pages/main_area_view.dart';
export 'presentation/pages/search_and_replace_widget.dart';
```

**Step 6: Create export barrel file**

Write: `lib/features/export/export.dart`

```dart
// Presentation layer
export 'presentation/widgets/export_button.dart';
```

**Step 7: Create core barrel file**

Write: `lib/core/core.dart`

```dart
// Config
export 'config/service_locator.dart';

// Constants
export 'constants/app_colors.dart';
export 'constants/app_constants.dart';

// Services
export 'services/cache_service.dart';

// Utils
export 'utils/extensions.dart';

// Widgets
export 'widgets/app_button.dart';

// Presentation
export 'presentation/pages/home_page.dart';
```

**Step 8: Verify compilation**

```bash
flutter analyze
```

Expected: No errors

**Step 9: Run tests**

```bash
flutter test
```

Expected: All tests pass

**Step 10: Optional: Refactor imports to use barrel files**

You can now optionally refactor imports to use barrel files:

Before:
```dart
import 'features/image_list/logic/image_list_cubit.dart';
import 'features/image_list/data/models/app_image.dart';
```

After:
```dart
import 'features/image_list/image_list.dart';
```

**Note:** This is optional but recommended for cleaner imports. Can be done incrementally.

**Step 11: Commit**

```bash
git add lib/features/*/lib/core/core.dart
git commit -m "refactor: add barrel exports for cleaner imports"
```

---

### Task 17: Final validation and comprehensive testing

**Step 1: Run full analysis with strict mode**

```bash
flutter analyze --fatal-infos --fatal-warnings
```

Expected: No issues

**Step 2: Run tests with coverage**

```bash
flutter test --coverage
```

Expected: All tests pass, coverage similar to baseline

**Step 3: Compare with baseline**

```bash
echo "=== Test Results ===" && cat test-baseline.txt
echo "=== Current Test Results ===" && flutter test
```

Expected: Similar test results

**Step 4: Build for all desktop platforms**

```bash
flutter build macos --release
# flutter build linux --release  # if Linux environment available
# flutter build windows --release  # if Windows environment available
```

Expected: All builds successful

**Step 5: Comprehensive smoke test**

```bash
flutter run -d macos
```

Test all features systematically:

1. **Image List Feature:**
   - [ ] Drag and drop folder
   - [ ] Navigate between images (previous/next)
   - [ ] Sort images by name/date/size
   - [ ] Filter images
   - [ ] Search images

2. **Captioning Feature:**
   - [ ] Add caption manually
   - [ ] Edit caption
   - [ ] Generate AI caption (current image)
   - [ ] Generate AI captions (missing captions)
   - [ ] Generate AI captions (all images)
   - [ ] Caption saves when navigating

3. **Image Operations Feature:**
   - [ ] Crop image
   - [ ] Resize image
   - [ ] Change aspect ratio
   - [ ] Convert image format
   - [ ] Batch convert multiple images

4. **LLM Config Feature:**
   - [ ] Open settings
   - [ ] Add new LLM configuration
   - [ ] Edit LLM configuration
   - [ ] Delete LLM configuration
   - [ ] Select active LLM config
   - [ ] Test caption generation with different configs

5. **Export Feature:**
   - [ ] Export captions
   - [ ] Export images
   - [ ] Export both

6. **UI/UX:**
   - [ ] Window resizing works
   - [ ] All buttons accessible
   - [ ] Keyboard shortcuts work
   - [ ] Error messages display correctly
   - [ ] Loading states display correctly

Expected: All features work correctly

**Step 6: Performance check**

While app is running:
- Check memory usage is reasonable
- Verify no lag when navigating images
- Verify AI caption generation doesn't block UI

**Step 7: Code formatting**

```bash
dart format .
```

Expected: All files formatted

**Step 8: Final commit**

```bash
git add -A
git commit -m "feat: complete migration to feature-oriented architecture

BREAKING CHANGE: Major architecture restructure

Changes:
- Organized code by business feature instead of technical layer
- Each feature is self-contained (data/logic/presentation)
- Shared code in core/ module
- Added barrel exports for cleaner imports
- Consistent naming: logic/ for BLoCs/Cubits (not domain/blocs/)
- Feature-specific services stay in features (not core)
- Updated service locator registrations
- All tests passing
- All platforms building successfully

Migration path:
- Created rollback tag: pre-migration
- Feature branch: feature/architecture-migration
- Incremental migration with testing after each phase

Benefits:
- High cohesion: Related code grouped by feature
- Low coupling: Features are independent
- Scalability: Easy to add/remove features
- Maintainability: Clear feature boundaries
- Testability: Each feature can be tested independently
"
```

**Step 9: Merge to main branch**

```bash
git checkout main
git merge feature/architecture-migration
```

Expected: Clean merge

**Step 10: Tag completion**

```bash
git tag -a post-migration -m "Completed feature-oriented architecture migration"
git push origin post-migration
```

---

## Migration Complete!

The codebase now follows feature-oriented architecture principles aligned with Flutter best practices:

- **High cohesion**: Related code grouped by feature
- **Low coupling**: Features are independent
- **Scalability**: Easy to add/remove features
- **Maintainability**: Clear feature boundaries
- **Testability**: Each feature can be tested independently
- **Consistency**: Uses logic/ convention (flutter-dev style)
- **Clean separation**: Infrastructure vs business logic

### Next time you add a feature:

1. Create `lib/features/your_feature/`
2. Add subdirectories:
   - `data/` - Models, repositories, feature-specific services
   - `logic/` - BLoCs/Cubits + states
   - `presentation/` - Pages and widgets
3. Create barrel export `your_feature.dart`
4. Update service_locator if needed
5. Update imports using barrel files
6. Write tests in `test/features/your_feature/`

### Feature structure template:

```
lib/features/my_feature/
├── data/
│   ├── models/           # DTOs, entities
│   ├── repositories/     # Data access
│   └── services/         # Feature-specific business services
├── logic/
│   ├── my_feature_cubit.dart
│   └── my_feature_state.dart
├── presentation/
│   ├── pages/            # Full-screen widgets
│   └── widgets/          # Reusable feature widgets
└── my_feature.dart       # Barrel export
```

### What went in features vs core:

**In features:**
- Feature-specific business logic
- Feature-specific UI
- Feature-specific services (e.g., caption_service, llm_config_service)
- Feature-specific repositories

**In core:**
- Infrastructure services (cache, storage, logging)
- App-wide configuration
- Shared constants
- Truly reusable widgets (used by 3+ unrelated features)
- Cross-cutting concerns

### Rollback plan (if needed):

```bash
git checkout main
git tag -d pre-migration post-migration  # Clean up tags
# Or rollback to: git checkout pre-migration
```
