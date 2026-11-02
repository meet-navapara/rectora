# Releasing Rectora on Google Play

This file records what the app does and what a release still needs from a person with console access.

## Build

Create an upload key once. Keep the file and its passwords somewhere safe, because losing them makes updates harder.

```powershell
keytool -genkeypair -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
copy android\key.properties.example android\key.properties
```

Edit `android\key.properties` with the real passwords. Neither file is committed. `flutter build appbundle` refuses to run without it.

```powershell
flutter build appbundle --release
```

Raise the build number in `pubspec.yaml` for every upload. If the version name changes, change `rectoraVersion` in `lib/ui/screens/settings_page.dart` too. A test checks that they match.

## Ads

Ads appear in every mode: a banner on the chapter, level, daily, and weekly screens, a full-screen ad after every third completed level, and a rewarded ad for a second hint in a puzzle. Release builds use the real AdMob ids in `lib/domain/ads/ad_config.dart` and `android/app/build.gradle.kts`. Debug and profile builds use Google's sample units and sample app id, so testing never touches the real ones. Do not tap live ads on your own phone; add it under Test devices in AdMob. To try sample ads in a release build on your own phone, add `--dart-define=RECTORA_TEST_ADS=true`. Never upload that build.

Real units also need the consent message created in AdMob. Settings shows Ad privacy choices when Google says the player's region needs it.

## Google sign-in

`android/app/google-services.json` only lists the debug key's SHA-1. Sign-in fails for every player until these are added to the Firebase Android app, and the file is downloaded again:

- the upload key's SHA-1
- the App signing key's SHA-1 from Play Console, under Setup, App signing

## Account deletion

Settings, Your data, Delete account removes the Firestore progress, the Firebase Authentication user, and the progress parked for that account on the device. It signs in again silently first, because Firebase needs a recent sign-in. The public page is `hosting/delete-account.html`.

## Firebase and hosting

Deploy after any change to the pages or rules:

```powershell
firebase deploy --only hosting,firestore:rules
```

The public pages are `/privacy`, `/terms`, and `/delete-account` on `com-rectora-rectora.web.app`.

## R8

`android/app/proguard-rules.pro` is required. Without it the release build crashes at launch, or cannot read its save. Debug builds and `flutter test` do not show this, so always launch a release build on a real phone before uploading.

## Levels

`tool/build_campaign.dart` creates the catalogs: `generate` finds candidate boards, and `assemble` keeps the hardest of each size and orders them by the effort in `lib/domain/difficulty/effort.dart`. Every kept puzzle has exactly one solution, and `flutter test` proves it again. It also checks that difficulty never falls within a campaign and that no board repeats another after a rotation or mirror.

Level ids follow the order, so reordering after launch would change what a saved id means. Add new levels to the end of a campaign instead.

## Cloud sync

Signed-in progress is stored at `users/{firebase uid}/gameProgress/primary`. Rules in `firebase/firestore.rules` allow only that user to read and write it. Guest progress stays on the device. `mergeProgress` combines a device save with an account save: solves are united, the faster time is kept, and device settings win. A trusted check of mastery points would need Cloud Functions.

An HTTP sync client also exists, for `--dart-define=RECTORA_SYNC_URL=https://your-host`. It is not used by the normal build.

## Not included

Purchases, Play Games, analytics, and crash reporting. Reminder preference is stored and schedules nothing, and it is not shown in Settings.
