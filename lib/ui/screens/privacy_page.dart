import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';

const privacyPolicyText = '''
Rectora privacy policy

Effective 30 October 2026.

Rectora can be played as a guest. Guest progress stays on this device.

What is stored on this device
- A display name and avatar you choose.
- Puzzle progress, drafts, statistics, tutorial status, and daily and weekly dates.
- Settings such as theme, sound, haptics, and timer.
- If you sign in, the Google account id, and the name and email Google returns. The sign-in token is not written into the save.

Google sign-in and Firebase
Continue with Google sends the sign-in to Google and then to Firebase Authentication. Rectora uses it to recognize the same player. Cancelling sign-in leaves the guest save unchanged.

After sign-in, puzzle progress can be stored in Cloud Firestore under that Firebase user id, in the users collection. Firestore rules allow that user to read and write only their own documents. An optional HTTP sync server is used only when a sync address is compiled into the build. Rectora does not include a separate analytics SDK.

Signing out returns this device to guest progress. The Google account’s solved puzzles stay with that login.

Deleting your account
Settings includes Delete account. It permanently deletes your Firebase Authentication user, your Firestore progress, and the progress saved for that account on this phone. Rectora says it is done only after Firebase confirms the delete. It does not delete your Google account. Instructions that do not need the app: https://com-rectora-rectora.web.app/delete-account

Advertising
Rectora can show ads from Google AdMob. The hint button stays free. An optional extra hint can play a rewarded ad, and the hint is added only after Google confirms the reward. After several completed levels, a full-screen ad may appear once the completion summary is closed. Banner ads can appear on chapter and calendar screens, not on puzzle boards. Lessons do not show that ad. If an ad cannot load, play continues. Google's ad SDK can collect device identifiers, including the advertising ID, and advertising information when an ad request is made. Where the law requires it, Rectora asks for consent first, and Settings lets you change that choice.

Other actions
Clear local data on this device removes solved puzzles, drafts, streaks, and lesson progress stored on this phone. Settings, the display name, and the Google login stay. It does not delete your account. Syncing again can bring a cloud copy back. Uninstalling the app removes the local save.

The app requires an internet connection before play. It requests internet access for that check, sign-in, Firebase, and ads. It does not request contacts, location, camera, microphone, or SMS.

Device backup
Android backup may include the local save. That backup is controlled by the device account, not by a Rectora service.

Children
Rectora is not directed at children under 13 and does not knowingly collect their personal information.

Contact
Use the support address on the store listing.
Privacy policy: https://com-rectora-rectora.web.app/privacy
Terms: https://com-rectora-rectora.web.app/terms
''';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Privacy'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(privacyPolicyText),
      ),
    );
  }
}
