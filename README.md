# Rectora

Rectora is an offline logic-puzzle game with four modes.

- Parcels covers the board with rectangles. Each rectangle contains one number, and its area equals that number.
- Trace draws one orthogonal path through numbered checkpoints in order and covers every open cell.
- Inks fills the board with connected regions that do not have to be rectangles. Each region contains one number, and its size equals that number.
- Threads joins matching letters with orthogonal paths that do not cross and covers every open cell.

The game does not use an account, advertising, or analytics. Progress stays in local storage on the device.

## Run locally

Install Flutter 3.47 or newer (this project was built with Flutter 3.47.7 and Dart 3.13.5), then:

```powershell
cd c:\Master_mind
flutter pub get
flutter run
```

`flutter run` uses a debug build. The debug Android manifest adds `INTERNET` so the Flutter tool can hot reload. The release manifest does not.

## Tests and release build

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --release
```

The release APK is written to `build\app\outputs\flutter-apk\app-release.apk`.

Until `android\key.properties` exists, that APK is signed with the debug key. It is useful for local installation and is not a Play Store upload. Copy `android\key.properties.example` to `android\key.properties`, point it at a keystore you create yourself, and do not commit the keystore or the real properties file.

Install the local release build with a device connected:

```powershell
flutter install --release
```

Or:

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

An iOS release build needs Xcode on macOS. It was not produced on this Windows machine.

## Content

- 520 parcel campaign levels in `assets\levels\parcels.json`, shown as 10 chapters
- 52 trace campaign levels in `assets\levels\traces.json`
- 53 inks campaign levels in `assets\levels\inks.json`
- 72 thread campaign levels in `assets\levels\threads.json`
- 120 local daily puzzles in `assets\levels\daily.json`
- Schedule id `rectora-daily-v1`, epoch 2026-01-01

Trace and Inks are the first validated campaign. `tool/generate_modes.dart` builds more of those two modes. It keeps a board only when the solver finds exactly one solution.

`flutter test` re-solves every shipped puzzle and requires exactly one solution. The app itself only checks that each stored solution covers the board, so startup does not re-run the solver.

Regenerate catalogs with:

```powershell
dart run tool/generate_campaign.dart
dart run tool/generate_modes.dart
```

Regenerate icons and tones with:

```powershell
dart run tool/write_assets.dart
```

## More detail

- Architecture: `docs\ARCHITECTURE.md`
- Privacy: `docs\PRIVACY_POLICY.md` and Settings → Privacy in the app
- Store checklist: `docs\STORE.md`
