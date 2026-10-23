# Rectora release notes for this build

This file records what the app actually does. It is not a store submission.

## Guest play

The game starts as a guest. Campaign progress, drafts, settings, daily completions, weekly progress, and mastery points are stored in `rectora.save.v1` on the device. No account is required.

## Google sign-in

Google sign-in and Google Play Games are different systems. This build calls Google Sign-In for the app account. It does not call Play Games. There is no Play Games application id and no `google-services.json`.

The button starts the real Google flow. With no OAuth client, the device reports that Google sign-in is not configured. The app does not invent a signed-in session. Guest play stays available.

To enable sign-in:

1. In Google Cloud, create an Android OAuth client for package `com.rectora.rectora` and the app signing SHA-1.
2. Create a Web OAuth client. That client id is the server client id.
3. Build with `--dart-define=GOOGLE_SERVER_CLIENT_ID=the-web-client-id`.
4. Do not put a service-account JSON file or a client secret in the Flutter project.

The local save stores the Google account id, and the name and email when Google returns them. It does not store the ID token.

## Cloud sync

No sync server is compiled into this build, so progress is not uploaded. Gameplay stays local and works offline.

The client is ready for an HTTPS service passed with `--dart-define=RECTORA_SYNC_URL=https://your-host`. The host must verify the Google ID token and key records by the token subject, not by an id the app sends on its own.

- `GET /v1/progress` with `Authorization: Bearer <id token>`. `404` means no record. `200` returns `{ "revision": number, "payload": "<save json>" }`.
- `PUT /v1/progress` with `{ "baseRevision": number, "payload": "<save json>" }`. `200` returns the stored revision. `409` returns the current record so the client can merge and retry once.
- `DELETE /v1/account` returns `204` only after that account's record is removed.

The same full document is sent again on retry, so a repeated put replaces one record instead of adding a second solve.

`mergeProgress` combines a device save with an account save:

- Completed levels are united.
- The faster time is kept.
- A skip does not erase a solve.
- Mastery points are recalculated from campaign solves. Daily and weekly attempt ids do not add a second reward.
- Achievements are derived from those records, so they are not stored twice.
- Daily and weekly sets are united. A weekly bonus stays once per week.
- Device settings win.
- If both sides have a different unfinished draft, the device draft is kept and the player is told.
- An empty device save does not replace a cloud save. A failed download does not upload.
- Signing out clears the account id and leaves the puzzles on the device.
- Clearing progress on the phone does not upload an empty save over the cloud copy.
- Account deletion runs only after the server confirms it, and then clears local puzzle progress. Without a sync server, the button explains that deletion is unavailable and does not claim success.

## Weekly challenge and rewards

A week is the local Monday date. The same week and catalog pick the same three medium-or-harder parcel ids. Finishing that set awards 50 mastery points once. Replays do not add points. Weekly attempts from the week screen are stored as `weekly@` ids so they do not skip the campaign unlock order.

Board styles unlock from mastery points. They change the parcel highlight color. They do not change puzzle rules.

Reminder preference is stored and does not schedule a notification.

## Difficulty

Tiers are Beginner, Easy, Medium, Hard, Expert, Master, and Grandmaster. `rankParcel` uses opening choices, search nodes, and whether the first open clue had more than one rectangle. Grandmaster requires a long search or a wide set of local choices, not only a large grid. Shipped catalog files still use the tiers written when they were generated. Grandmaster is available to the generator and the ranker. The shipped catalogs do not yet contain a grandmaster chapter.

## Level counts

Validated files on disk:

- Parcels: 520
- Trace: 52
- Inks: 53
- Threads: 72
- Daily: 120

`tool/generate_campaign.dart` and `tool/generate_modes.dart` are the content pipeline. They keep a puzzle only when the solver finds one solution. This build does not contain 1,000 validated levels per mode.

## Firebase

Firebase Core, Firebase Authentication, and Cloud Firestore are in the project. They stay off unless the build uses `--dart-define=RECTORA_FIREBASE=true` and `flutterfire configure` has created a real Android app for `com.rectora.rectora`. There is no `google-services.json` in this workspace, so this build does not connect to a Firebase project.

When that setup exists, Google sign-in exchanges its ID token for a Firebase user. Progress is stored at `users/{firebase uid}/gameProgress/primary` as the existing save JSON, plus `schemaVersion` and `revision`. Rules in `firebase/firestore.rules` allow only that signed-in user to read and write their own documents. They are not deployed. Guest progress is not uploaded. An empty guest save does not replace a cloud save, because the existing merge refuses that. Firestore does not recompute mastery; a trusted check would need Cloud Functions.

App Check, Crashlytics, and Analytics are not included.

## Ads

The Android manifest uses Google's sample test app id unless `-PRECTORA_ADMOB_APP_ID` is passed. Rewarded and interstitial requests use Google's sample unit ids unless `RECTORA_REWARDED_AD_UNIT` and `RECTORA_INTERSTITIAL_AD_UNIT` are compiled in. The hint button does not require an ad. An extra hint is granted only from the rewarded-ad callback. An interstitial is offered after every third completed level, after the summary closes, and never for a lesson or a repeated completion of the same level. A failed ad does not block play. No production ad units are configured, and the AdMob consent message has not been created in a console.

## Purchases

No products or subscriptions are implemented. Do not grant a purchase from a local Boolean.

## Privacy

The privacy page in the app describes local storage. Before a store listing, confirm that page against the real data flows. If accounts are added, add an in-app and web account-deletion path and a public privacy-policy URL. Do not treat this note as a published policy.

## Still required before a Play release

Release keystore, Play Console listing, screenshots, content rating, Data Safety, internal testing on a device, and a crash-reporting choice. The debug-signed APK is not a production upload.
