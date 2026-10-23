import '../campaign/save_game.dart';
import '../parcels/models.dart';
import 'auth_types.dart';
import 'cloud_types.dart';
import 'progress_merge.dart';

class BoundAccount {
  const BoundAccount({
    required this.save,
    required this.shouldUpload,
    required this.phase,
    required this.message,
    required this.draftConflicts,
    required this.isError,
  });

  final SaveGame save;
  final bool shouldUpload;
  final SyncPhase phase;
  final String message;
  final List<String> draftConflicts;
  final bool isError;
}

/// Attaches a confirmed Google id to the device save.
///
/// A cloud copy is merged in. An empty device save does not replace a cloud
/// save, and a failed download does not upload.
BoundAccount bindGoogleAccount({
  required SaveGame local,
  required String playerId,
  String? name,
  String? email,
  required bool cloudConfigured,
  required bool missingToken,
  required CloudFetch fetch,
  required Map<String, Difficulty> difficulty,
}) {
  final identified = local.copyWith(
    accountKind: 'google',
    accountPlayerId: playerId,
    accountName: name,
    accountEmail: email,
    setAccountEmail: true,
  );
  if (!cloudConfigured) {
    return BoundAccount(
      save: identified,
      shouldUpload: false,
      phase: SyncPhase.notConfigured,
      message: 'Signed in. Cloud sync is not set up for this build, so progress stays on this device.',
      draftConflicts: const [],
      isError: false,
    );
  }
  if (missingToken) {
    return BoundAccount(
      save: identified.copyWith(needsSync: true),
      shouldUpload: false,
      phase: SyncPhase.signInToSync,
      message: 'Signed in on this device. Cloud sync needs a configured Google server client before progress can be uploaded.',
      draftConflicts: const [],
      isError: false,
    );
  }
  if (fetch is CloudUnavailable) {
    return BoundAccount(
      save: identified.copyWith(needsSync: true),
      shouldUpload: false,
      phase: fetch.offline ? SyncPhase.offline : SyncPhase.failed,
      message: fetch.offline
          ? 'Signed in. Internet connection required to sync. Progress on this device was kept.'
          : 'Signed in. Sync failed. Progress on this device was kept.',
      draftConflicts: const [],
      isError: true,
    );
  }
  if (fetch is CloudEmpty) {
    return BoundAccount(
      save: identified.copyWith(needsSync: true),
      shouldUpload: true,
      phase: SyncPhase.syncing,
      message:
          'Signed in. Progress on this device will be saved to your account.',
      draftConflicts: const [],
      isError: false,
    );
  }
  if (fetch is! CloudFound) {
    return BoundAccount(
      save: identified.copyWith(needsSync: true),
      shouldUpload: false,
      phase: SyncPhase.failed,
      message: 'Signed in. Sync failed. Progress on this device was kept.',
      draftConflicts: const [],
      isError: true,
    );
  }
  final SaveGame remote;
  try {
    remote = decodeSave(fetch.record.payload);
  } on FormatException {
    return BoundAccount(
      save: identified.copyWith(needsSync: true),
      shouldUpload: false,
      phase: SyncPhase.failed,
      message:
          'Cloud progress could not be read. Progress on this device was kept.',
      draftConflicts: const [],
      isError: true,
    );
  }
  if (remote.accountPlayerId != null && remote.accountPlayerId != playerId) {
    return BoundAccount(
      save: identified.copyWith(needsSync: true),
      shouldUpload: false,
      phase: SyncPhase.failed,
      message: 'The cloud record did not match this Google account. Nothing was overwritten.',
      draftConflicts: const [],
      isError: true,
    );
  }
  final plan = mergeProgress(
    device: identified,
    account: remote.copyWith(
      accountKind: 'google',
      accountPlayerId: playerId,
      accountName: name ?? remote.accountName,
      accountEmail: email ?? remote.accountEmail,
      setAccountEmail: true,
    ),
    difficulty: difficulty,
  );
  final conflict = plan.draftConflicts.isNotEmpty;
  return BoundAccount(
    save: plan.save.copyWith(
      needsSync: true,
      remoteRevision: fetch.record.revision,
    ),
    shouldUpload: true,
    phase: SyncPhase.syncing,
    message: conflict
        ? 'Signed in. Unfinished puzzles that differed kept this device\'s attempt.'
        : 'Signed in. Progress from this device and your account was combined.',
    draftConflicts: plan.draftConflicts,
    isError: false,
  );
}
