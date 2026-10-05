# Project Overview

This is a Flutter desktop application for MacOS, Linux and Windows that allows users to manage and caption image files. The application provides a user interface to select a folder of images, view them one by one, and add/edit captions for each image. The captions are saved as `.txt` files with the same name as the image.

The application uses a third-party API for generating captions automatically. The user can configure the API endpoint, model, and API key in the application settings.

## Building and Running

To build and run the project, you need to have Flutter installed.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YofarDev/yofardev_captioner_flutter.git
   cd yofardev_captioner_flutter
   ```
2. **Get dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the application:**
   ```bash
   flutter run
   ```

## Development Conventions

* **State Management:** The application uses the `flutter_bloc` package for state management. The core business logic is encapsulated in Cubits, such as `ImagesCubit` and `LlmConfigsCubit`.
* **Dependency Injection:** The application uses `BlocProvider` to provide the Cubits to the widget tree.
* **Code Style:** The code follows the standard Dart and Flutter style guidelines. The `analysis_options.yaml` file contains the linting rules.
* **Testing:** There are no specific testing practices evident from the codebase. There is a default `widget_test.dart` file, but no other tests are present.
* **File Structure:** The project follows the standard Flutter project structure. The `lib` folder contains the source code, which is organized into the following folders:
    * `logic`: Contains the business logic of the application, using `flutter_bloc` for state management.
    * `models`: Defines the data structures and models used throughout the application.
    * `repositories`: Manages data retrieval from various sources, such as APIs and local storage.
    * `res`: Holds static resources like color schemes, constants, and other assets.
    * `screens`: Contains the UI components for each screen in the application.
    * `services`: Provides specific functionalities, including caching and API communication.
    * `utils`: Includes general utility functions used across the application.
    * `main.dart`: The entry point of the application.
* **Testing:** The `test` folder contains the tests for the application. There are some unit and integration tests, but the coverage is not complete.

## Agent API

The app embeds a local REST API (`lib/features/agent_api/`, `shelf` on `127.0.0.1`, default port 8765) so external AI agents can read saved prompts and write captions with their own vision. Everything except `GET /api/health` requires `Authorization: Bearer <token>`; port and token are published in `agent-api.json` inside the application-support directory while the app runs (macOS: `~/Library/Application Support/fr.yofardev.yofardevCaptioner/`). Endpoints: `/api/prompts`, `/api/folders`, `/api/images?folder=`, `POST /api/captions`, `POST /api/folders/refresh`. Never write a folder's `db.json` from outside the app — it is rewritten from memory and external edits get clobbered; use `POST /api/captions` instead. `tool/captioner_mcp.dart` is an optional stdio MCP server exposing the same API as tools. Full contract: see the "Agent API" section of `CLAUDE.md`.
