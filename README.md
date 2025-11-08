<img src="assets/logo.png" alt="Yofardev Captioner Logo" width="20%">

# Yofardev Captioner (MacOS & Linux)

A desktop application for managing and captioning image files.

![Screenshot of Yofardev Captioner](assets/screenshot.png)

# Project Overview

This is a Flutter desktop application for MacOS, Linux, and Windows that allows users to manage and caption image files. The application provides a user interface to select a folder of images, view them one by one, and add/edit captions for each image. The captions are saved as `.txt` files with the same name as the image.

The application uses a third-party API for generating captions automatically. The user can configure the API endpoint, model, and API key in the application settings.

## Run on Desktop

For MacOS & Linux, directly download the latest version of the app in [Releases](https://github.com/YofarDev/yofardev_captioner_flutter/releases/).

## Build & Run with Flutter

To run this application, ensure you have Flutter installed.

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/yofardev_captioner.git
   cd yofardev_captioner
   ```
2. Get dependencies:

   ```bash
   flutter pub get
   ```
3. Run the application:

   ```bash
   flutter run
   ```
