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

- `lib/logic/` - BLoC/Cubit business logic layer
  - `captioning/` - Caption generation management
  - `image_operations/` - Image processing (crop/resize)
  - `images_list/` - Image navigation and list management
  - `llm_config/` - LLM API configuration
- `lib/models/` - Data models (AppImage, CaptionData, LlmConfig)
- `lib/repositories/` - Data access layer (API calls, file I/O)
- `lib/services/` - Business services and DI setup
- `lib/screens/` - UI components (home, main view, sidebar, settings)
- `lib/utils/` - Utility functions
- `lib/helpers/` - Test helpers

### State Management Flow

1. User actions trigger UI events
2. BLoCs/Cubits handle business logic and emit state changes
3. UI rebuilds based on new state
4. Repositories handle external API calls and file system operations

**Primary BLoCs:**
- `ImageListCubit` - Image loading, navigation, sorting, filtering
- `CaptioningCubit` - AI caption generation (current/missing/all images)
- `ImageOperationsCubit` - Crop and resize operations
- `LlmConfigsCubit` - Manages LLM API configurations

### Dependency Injection

Services and repositories are registered as singletons in `lib/services/service_locator.dart`. Access via `locator<Type>()`.

```dart
// Example usage
final captionService = locator<CaptionService>();
```

### Data Models

- `AppImage` - Core image data structure with file path, caption, and metadata
- `CaptionData` - Caption persistence model
- `LlmConfig` - LLM service configuration (API endpoint, model, key)

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
