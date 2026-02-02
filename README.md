<img src="assets/logo.png" alt="Yofardev Captioner Logo" width="20%">

# Yofardev Captioner (MacOS, Linux & Windows)

An open-source desktop application for managing and captioning image files.

![Screenshot of Yofardev Captioner](assets/screenshot_.png)

# Project Overview

This is a Flutter desktop application for MacOS, Linux, and Windows that allows users to manage and caption image files. The application provides a user interface to select a folder of images, view them one by one, and add/edit captions for each image. The captions are saved as `.txt` files with the same name as the image.

The application uses a third-party API for generating captions automatically. The user can configure the API endpoint, model, and API key in the application settings.

## Features

- **View and Manage Images**: Select a folder and view images one by one.
- **Edit Captions**: Add, edit, and save captions for each image. Captions are saved as `.txt` files.
- **Automatic Captioning**: Use a third-party API to automatically generate captions for your images.
- **Image Operations**: Crop and resize images.
- **Search and Replace**: Batch search and replace text in captions.
- **Sort and Filter**: Sort images by name, date, or caption length.
- **Multi-Category Captions**: Maintain different types of captions for each image (e.g., short, detailed, tags).

![Screenshot of Settings](assets/screenshot_2.png)

## Multi-Category Captions

The app supports multiple caption categories per image, allowing you to maintain different types of captions for the same dataset.

### Creating Categories

1. Click the **+** button next to the category tabs
2. Enter a category name (e.g., "tags", "short", "detailed")
3. Click **Add**

### Managing Categories

- **Switch categories:** Click on a category tab to view/edit captions for that category
- **Rename category:** Long-press on a category tab → Rename
- **Delete category:** Long-press on a category tab → Delete (cannot delete the last category)

### Exporting by Category

When exporting images as an archive:
1. Click **Export as Archive**
2. Select which caption category to export
3. The app will export images with `.txt` files containing captions from the selected category only

### Migration from Single Captions

If you open a folder with the old single-caption format:
- The app automatically migrates to the new multi-category format
- Existing captions are moved to a "default" category
- You can create additional categories as needed

## Run on Desktop

For MacOS & Linux, directly download the latest version of the app in [Releases](https://github.com/YofarDev/yofardev_captioner_flutter/releases/).

## Build & Run with Flutter

To run this application, ensure you have Flutter installed.

1. Clone the repository:

   ```bash
   git clone https://github.com/YofarDev/yofardev_captioner_flutter.git
   cd yofardev_captioner_flutter
   ```
2. Get dependencies:

   ```bash
   flutter pub get
   ```
3. Run the application:

   ```bash
   flutter run
   ```
