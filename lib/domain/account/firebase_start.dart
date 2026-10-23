enum FirebaseStart { notConfigured, ready, failed }

/// Turns Firebase on only for a build that asked for it, and treats a failed
/// native start as local play.
Future<FirebaseStart> startFirebase({
  required bool enabled,
  required Future<void> Function() initialize,
}) async {
  if (!enabled) return FirebaseStart.notConfigured;
  try {
    await initialize();
    return FirebaseStart.ready;
  } catch (_) {
    return FirebaseStart.failed;
  }
}
