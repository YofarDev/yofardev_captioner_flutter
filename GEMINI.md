# Project Overview

This is a Flutter desktop application for MacOS and Linux that allows users to manage and caption image files. The application provides a user interface to select a folder of images, view them one by one, and add/edit captions for each image. The captions are saved as `.txt` files with the same name as the image.

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
* **File Structure:** The project follows the standard Flutter project structure. The `lib` folder contains the source code, which is organized into `logic`, `models`, `repositories`, `res`, `screens`, `services`, and `utils` folders.
