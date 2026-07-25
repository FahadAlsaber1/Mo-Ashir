# MO'ASHIR — Flutter App

A Flutter port of the Sehha (MO'ASHIR) health app, ready to open in Android Studio.

## Setup

1. Make sure Flutter SDK is installed: `flutter --version`
2. In a terminal, create the native scaffolding (android/ios folders) inside this project:
   ```bash
   cd moashir
   flutter create . --project-name moashir --org com.moashir
   ```
   (This adds android/, ios/, etc. without overwriting `lib/` or `pubspec.yaml`.)
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Open the `moashir/` folder in **Android Studio** → *Open* → select the folder.
5. Pick an Android emulator/device and press ▶ Run.

## Screens
- Home (dashboard, upcoming appointment, quick actions)
- Doctors list
- Hospitals list
- Chat
- Profile

All navigation via bottom nav bar. Data is mocked in `lib/data/mock.dart`.
