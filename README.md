# Rectora

Rectora is a logic-puzzle game with four modes.

- Parcels covers the board with rectangles. Each rectangle contains one number, and its area equals that number.
- Trace draws one orthogonal path through numbered checkpoints in order and covers every open cell.
- Inks fills the board with connected regions that do not have to be rectangles. Each region contains one number, and its size equals that number.
- Threads joins matching letters with orthogonal paths that do not cross and covers every open cell.

Players can use a guest save on the device or sign in with Google to sync through Firebase. The app needs a connection to open, and it can show AdMob ads. It has no analytics SDK.

## Run locally

Install Flutter 3.47 or newer (this project was built with Flutter 3.47.7 and Dart 3.13.5), then:

```powershell
cd c:\Master_mind
flutter pub get
flutter run
```

`flutter run` uses a debug build, which requests Google's sample ads.

## Tests and release build

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --release
```

The release APK is written to `build\app\outputs\flutter-apk\app-release.apk`.

Until `android\key.properties` exists, that APK is signed with the debug key. It is useful for local installation only. A Play bundle refuses to build without that file. See `docs\RELEASE.md`.

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

- 500 levels in each of Parcels, Trace, Inks, and Threads, in 10 chapters of 50
- 120 daily puzzles in `assets\levels\daily.json`
- Schedule id `rectora-daily-v1`, epoch 2026-01-01

Levels open in order, and measured difficulty never falls from one level to the next. No board repeats another after a rotation or mirror. Each puzzle has exactly one solution, one free hint, and no help refusing a legal move. Each mode allows three unsolved skips at a time.

`flutter test` re-solves every shipped puzzle and requires exactly one solution. The app itself only checks that each stored solution covers the board, so startup does not re-run the solver.

Rebuild the catalogs in two steps. Repeat `generate` with a new seed to widen the choice.

```powershell
dart run tool/build_campaign.dart generate parcels 2 1
dart run tool/build_campaign.dart generate traces 2 1
dart run tool/build_campaign.dart generate inks 2 1
dart run tool/build_campaign.dart generate threads 2 1
dart run tool/build_campaign.dart generate daily 1 1
dart run tool/build_campaign.dart assemble
```

Regenerate icons and tones with:

```powershell
dart run tool/write_assets.dart
```

## More detail

- Architecture: `docs\ARCHITECTURE.md`
- Privacy: `docs\PRIVACY_POLICY.md` and Settings → Privacy in the app
- Release steps: `docs\RELEASE.md`
- Store checklist: `docs\STORE.md`
