import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';

const termsText = '''
Rectora terms and conditions

Effective 22 October 2026.

The game
Rectora is a puzzle game with Parcels, Trace, Inks, and Threads. You may play as a guest or sign in with Google. An internet connection is required to open the game. Guest progress stays on the device. A Google sign-in can store a progress record in Firebase for that login.

Your account
If you use Google sign-in, you must follow Google’s account rules. Rectora may refuse a sign-in that Google or Firebase rejects. Removing the saved user record deletes the Firestore row for that login. It does not delete the Google account or the Firebase Authentication user.

Acceptable use
Do not break, overload, or misuse the sign-in or Firebase service, and do not try to read another player’s cloud record.

Ads
This build uses Google’s sample test ads. A rewarded test ad grants an extra hint only when Google reports the reward. Play continues if an ad does not load. These test ads are not a production advertising setup.

Availability
The game and the cloud record are provided as they are. Progress can be lost if the device is cleared, the app is removed, or the cloud write fails.

Contact
Use the support address on the store listing.
''';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Terms'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(termsText),
      ),
    );
  }
}
