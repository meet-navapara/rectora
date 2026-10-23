# Rectora privacy policy

The public copy is `hosting/privacy.html`. The same facts are shown in the app under Settings → Privacy policy.

Do not submit an older copy of this file. Rectora now requires internet, offers Google sign-in, stores a Firestore user row, and requests Google’s sample test ads.

Effective date: 22 October 2026.

## Device

The app stores a display name, avatar, puzzle progress, drafts, statistics, tutorial status, daily and weekly dates, and settings on the device. Google sign-in also stores the account id and the name and email Google returns. The sign-in token is not written into the save. Android backup may include the local save.

## Firebase

Google sign-in is exchanged for a Firebase Authentication user in project `com-rectora-rectora`. Progress can be stored in Cloud Firestore under `users/{uid}`. Rules allow that user to access only their own documents. Removing the saved user record deletes that Firestore row. It does not delete the Google account or the Firebase Authentication user.

## Ads and permissions

The current build uses Google’s published sample test ad units. The ad SDK can collect device and advertising data when a request is made. The app requests internet access. It does not request contacts, location, camera, microphone, or SMS. There is no separate analytics SDK.

## Contact

Use the support address on the Google Play listing.
