# Play Console checklist

This is a checklist for the developer with console access. It does not promise approval.

## Identity

- App name: Rectora
- Application id: `com.rectora.rectora`
- Category: Games, Puzzle
- minSdk 24, targetSdk 36

## Store listing

- Short and full description
- 512 x 512 icon: `docs/store/icon-512.png`
- 1024 x 500 feature graphic: `docs/store/feature-graphic-1024x500.png`
- At least two phone screenshots
- Developer website: `https://com-rectora-rectora.web.app`, which AdMob reads `app-ads.txt` from
- Support email
- Privacy policy: `https://com-rectora-rectora.web.app/privacy`

## App content answers

These match what the app does today. Check them again against the console's current wording.

- Ads: yes, once real ad units are compiled in.
- App access: all features are available without an account, as a guest.
- Target audience: 13 and over. The ad SDK collects device data, and no child-directed setting is configured, so do not select younger age groups.
- Content rating: complete the questionnaire. The game has no violence, chat, or user-generated content.
- Advertising ID: yes, used for advertising. The merged manifest includes `AD_ID`.
- Account deletion URL: `https://com-rectora-rectora.web.app/delete-account`

## Data safety answers

- Encrypted in transit: yes.
- Deletion: yes, in the app and at the URL above.
- Name and email address: collected when a player signs in with Google. Used for account management. Optional.
- Game progress (app activity): collected when signed in. Used for app functionality. Optional.
- User IDs (Firebase uid and Google account id): collected when signed in. Used for account management. Optional.
- Device or other IDs: collected by the AdMob SDK. Used for advertising. Shared with Google, as Google's SDK documentation describes.
- App interactions and diagnostics collected by the AdMob SDK: confirm against Google's current Data safety guidance for the Mobile Ads SDK.

## Testing

Personal developer accounts created after 13 November 2023 need at least 12 testers opted in continuously for the 14 days before applying for production access. Check the current numbers in Play Console.

## AdMob

Add `hosting/app-ads.txt` with the line AdMob gives you, deploy hosting, then choose Verify app in the app's AdMob settings. The app cannot fully serve ads until it passes verification and the readiness review.

## Before each upload

1. `flutter analyze` and `flutter test`
2. Build the bundle as in `docs/RELEASE.md`
3. Install a release build on a real phone, then open and finish a level in all four modes
4. Sign in with Google on a build from the Play internal test track, which proves the Play signing SHA-1
5. Deploy hosting if a policy page changed
