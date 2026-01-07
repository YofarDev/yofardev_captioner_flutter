# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Yofardev Captioner is a Flutter desktop application (macOS, Linux, Windows) for managing and captioning image files. Users select folders of images, view them one-by-one, and add/edit captions saved as `.txt` files alongside images. The app supports automatic AI-powered caption generation via configurable third-party LLM APIs.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app (desktop)
flutter run

# Build for release
flutter build macos --release
flutter build linux --release
flutter build windows --release

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage

# Generate JSON serialization code (required after model changes)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## Architecture

This app uses **BLoC (Business Logic Component) pattern** for state management with **Repository pattern** for data access and **get_it** for dependency injection.

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
  - `services/` - Infrastructure (cache, storage, logging)
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

### Dependency Injection

Services and repositories are registered as singletons in `lib/core/config/service_locator.dart`. Access via `locator<Type>()`.

```dart
// Example usage
final captionService = locator<CaptionService>();
```

### Data Models

- `AppImage` - Core image data structure with file path, caption, and metadata (features/image_list/data/models/)
- `CaptionData` - Caption persistence model (features/captioning/data/models/)
- `LlmConfig` - LLM service configuration (features/llm_config/data/models/)

Models use JSON serialization with `json_annotation`. After modifying models, regenerate code with build_runner.

## Code Conventions

### Linting Rules

The project uses strict linting with these notable customizations:
- **Always specify types**: `always_specify_types: true`
- **Use relative imports** within lib directory: `prefer_relative_imports: true`
- **Avoid void async**: Disabled to allow `void async` functions
- **Parameter order**: Disabled to match JSON response order

### File Organization

- Use **part files** for BLoC state separation
- Use **relative imports** for files within lib: `import '../models/app_image.dart';`
- Use **package imports** for external dependencies and when accessing lib from outside

### Testing

- Unit tests for BLoCs use `bloc_test` package
- Mock dependencies with `mockito`
- Test helpers in `lib/helpers/`
- Place tests in `test/` mirroring lib structure

### Important Patterns

- **Equatable**: Use for all state classes for value equality
- **Async error handling**: Always use try/catch with proper error propagation
- **Logging**: Use the Logger service: `locator<Logger>()`
- **Platform-specific**: Code targets macOS, Linux, and Windows

## Key Features Implementation

### Caption Generation Flow

1. User configures LLM API in settings (stored via `LlmConfigService`)
2. `CaptioningCubit` receives request to caption image(s)
3. `CaptioningRepository` makes API call to configured endpoint
4. Response is parsed and saved to `.txt` file alongside image
5. UI updates with new caption

### Image Operations

- Crop: Uses `crop_your_image` package
- Resize: Uses `image` package
- Batch operations: Process multiple images sequentially with progress tracking

### File System Integration

- Drag & drop: `desktop_drop` package
- File picker: `file_picker` package
- macOS secure bookmarks: `macos_secure_bookmarks` for sustained file access
- Last folder caching: `shared_preferences`

## External Dependencies

- **LLM APIs**: Configurable endpoints (user provides API key, endpoint URL, model name)
- **ImageMagick**: Optional shell script in `assets/scripts/` for batch format conversion
- **Platform file access**: Uses platform-specific file dialogs and permissions

## Window Management

App uses `window_manager` for smart window sizing based on screen dimensions (via `screen_retriever`). Initial window size calculated based on display size on startup.

## UI Assets

- Custom fonts: Orbitron (headings), Inter (body)
- Logo and branding in `assets/`
- Shell scripts bundled in `assets/scripts/`
