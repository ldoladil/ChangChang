# Chinese App

A Flutter app for learning Chinese with your own vocabulary.

## Overview

`chinese_app` lets you:
- scan Chinese text with the camera using OCR
- translate scanned text
- save vocabulary locally with Hive
- review words using quiz screens and spaced repetition
- use localizations and custom Chinese fonts

## Key features

- `camera` integration for live scanning
- `google_mlkit_text_recognition` for Chinese OCR
- `google_mlkit_translation` for translations
- `hive_flutter` for local vocabulary persistence
- `flutter_localizations` support for internationalization
- `image_picker` for photo selection
- `url_launcher` to open links or external resources
- `flutter_dotenv` for environment variables

## Project structure

- `lib/` — app source code
  - `screens/` — pages such as home, quiz, add word, scan, settings
  - `services/` — OCR, translation, SRS, AI and other business logic
  - `widgets/` — reusable UI components
  - `models/` — data model definitions and adapters
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — platform runners
- `assets/` — fonts and images used by the app
- `.env` — environment variables loaded by `flutter_dotenv`

## Setup

1. Install Flutter SDK.
2. Open `c:\Users\luked\dev\chinese_app`.
3. Run:

```bash
flutter pub get
```

4. Run the app on a device or emulator:

```bash
flutter run
```

## Development workflow

- To generate Hive type adapters:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

- If you need icons updated:

```bash
flutter pub run flutter_launcher_icons:main
```

## Notes

- `assets/images/horse.jpg` is included for app content.
- `.env` is listed as an asset and should contain any private keys or configuration values.
- `pubspec.lock` is included here for reproducible builds.

## Recommended `.gitignore`

Exclude generated build files and local IDE settings:

```gitignore
.build/
.dart_tool/
.packages
.pub/
.idea/
.vscode/
**/build/
**/android/**/build/
**/ios/Pods/
**/ios/Runner.xcworkspace/
**/flutter_export_environment.sh
```

## License

Use this project as needed and add a license file if the repository is public.
