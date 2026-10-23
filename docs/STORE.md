# Store readiness

This is a checklist for a developer with console access. It is not a statement that Google Play or the App Store will approve the app.

Official references:

- Google Play Developer Program Policies: https://support.google.com/googleplay/android-developer/
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple privacy information: https://developer.apple.com/app-store/app-privacy-details/

## Identity

- App name: Rectora
- Android application id: `com.rectora.rectora`
- Version in `pubspec.yaml`: 1.0.0+1
- Category: logic puzzle. No accounts, no purchases, no ads.
- Audience: general. The rules are suitable for all ages. Confirm the questionnaire in each console; do not assume an automatic rating.

## Android

- Flutter's current default compile SDK and target SDK are 36, which matches the Play requirement that new apps target API 36.
- `minSdk` is Flutter's default (24 on this SDK).
- Release signing is not configured. Create a keystore locally, copy `android/key.properties.example` to `android/key.properties`, and build again. Do not commit either file.
- The local `flutter build apk --release` output is signed with the debug key until that file exists. Play requires an upload key.
- Host the privacy policy at a public URL before submitting. The text is in `docs/PRIVACY_POLICY.md`.
- Data safety: the app does not transmit player data and does not include ads or analytics SDKs. The optional display name and progress remain on device. Android backup can include that local save if the user has device backup enabled. Declare that according to the console questions after reading the merged release manifest. Do not answer "no data stored" if the console asks about data stored on device.
- Debug and profile manifests include `INTERNET` for Flutter tooling. Confirm the release merged manifest does not.
- Provide a support email, screenshots from a phone, a feature graphic, and the content-rating questionnaire in Play Console.
- No in-app purchases and no advertising consent form are required for this build.

## iOS

- The Xcode project exists and the display name is Rectora. A release archive was not built here because this workspace is on Windows.
- On a Mac, open `ios/Runner.xcworkspace`, set a development team, and archive with Xcode.
- App Privacy: data is not collected by the developer and is not used for tracking. The optional display name stays on device. iCloud backup may include the app container if the user enables device backup.
- No account means the account-deletion requirement is not triggered by a Rectora account.
- Confirm the privacy nutrition labels against the archived app's linked SDKs (`shared_preferences` and `audioplayers` only).

## Not done from this workspace

- Play Console and App Store Connect listings
- A real upload keystore and its passwords
- A hosted privacy-policy URL
- Store screenshots from a physical phone
- An iOS archive
- A promise of store approval
