import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rectora/app.dart';
import 'package:rectora/data/flutter_firebase.dart';
import 'package:rectora/data/mobile_ads.dart';
import 'package:rectora/domain/account/firebase_start.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebase = await startFlutterFirebase().timeout(
    const Duration(seconds: 8),
    onTimeout: () => FirebaseStart.failed,
  );
  // The consent form needs a visible activity. Waiting for it before the
  // first frame closes a freshly installed release build.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(startMobileAds());
  });
  runApp(
    RectoraApp(
      cloud: firebase == FirebaseStart.ready
          ? const FirestoreProgressCloud()
          : null,
      firebaseBind: firebase == FirebaseStart.ready
          ? const FirebaseAccountBinder()
          : null,
    ),
  );
}
