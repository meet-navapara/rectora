import '../campaign/records.dart';
import '../campaign/save_game.dart';
import '../parcels/models.dart';
import '../progression/rewards.dart';

class MergePlan {
  const MergePlan({required this.save, required this.draftConflicts});

  /// Merged progress. Where both devices had an unfinished puzzle, the
  /// device copy is kept until the player chooses otherwise.
  final SaveGame save;
  final List<String> draftConflicts;
}

/// Unions completed puzzles, keeps the faster time, and rebuilds mastery
/// points from the merged record so the same solve cannot be counted twice.
///
/// Settings stay with the device. The account name is kept when the device
/// is still using the default name.
MergePlan mergeProgress({
  required SaveGame device,
  required SaveGame account,
  required Map<String, Difficulty> difficulty,
}) {
  final conflicts = <String>[];
  final drafts = Map<String, PuzzleDraft>.from(device.drafts);
  for (final entry in account.drafts.entries) {
    final local = drafts[entry.key];
    if (local == null) {
      drafts[entry.key] = entry.value;
    } else if (local.moves.length != entry.value.moves.length) {
      conflicts.add(entry.key);
    }
  }
  final merged = SaveGame(
    settings: device.settings,
    profile: device.profile.name == 'Traveler'
        ? account.profile
        : device.profile,
    parcelRecords: _mergeMaps(device.parcelRecords, account.parcelRecords),
    threadRecords: _mergeMaps(device.threadRecords, account.threadRecords),
    traceRecords: _mergeMaps(device.traceRecords, account.traceRecords),
    inkRecords: _mergeMaps(device.inkRecords, account.inkRecords),
    drafts: drafts,
    parcelsStarted: {...device.parcelsStarted, ...account.parcelsStarted},
    threadsStarted: {...device.threadsStarted, ...account.threadsStarted},
    tracesStarted: {...device.tracesStarted, ...account.tracesStarted},
    inksStarted: {...device.inksStarted, ...account.inksStarted},
    dailyCompleted: {...device.dailyCompleted, ...account.dailyCompleted},
    tutorialsSeen: {...device.tutorialsSeen, ...account.tutorialsSeen},
    lifetimeHints: device.lifetimeHints > account.lifetimeHints
        ? device.lifetimeHints
        : account.lifetimeHints,
    lastPlayed: device.lastPlayed ?? account.lastPlayed,
    weeklySolved: {...device.weeklySolved, ...account.weeklySolved},
    weeklyClaimed: {...device.weeklyClaimed, ...account.weeklyClaimed},
    claimedChapters: {...device.claimedChapters, ...account.claimedChapters},
    seenChapters: {...device.seenChapters, ...account.seenChapters},
    accountKind: account.accountKind == 'guest'
        ? device.accountKind
        : account.accountKind,
    accountPlayerId: account.accountPlayerId ?? device.accountPlayerId,
    accountName: account.accountName ?? device.accountName,
    accountEmail: account.accountEmail ?? device.accountEmail,
    lastSyncAt: device.lastSyncAt,
    needsSync: device.needsSync,
    remoteRevision: device.remoteRevision,
    entered: device.entered,
    shelves: device.shelves,
    onboardingVersion: device.onboardingVersion > account.onboardingVersion
        ? device.onboardingVersion
        : account.onboardingVersion,
  );
  return MergePlan(
    save: merged.copyWith(xp: xpFromSave(merged, difficulty)),
    draftConflicts: conflicts,
  );
}

int xpFromSave(SaveGame save, Map<String, Difficulty> difficulty) {
  var total = save.weeklyClaimed.length * weeklyClearBonus;
  total += save.claimedChapters.length * chapterClearBonus;
  void add(Map<String, LevelRecord> records) {
    for (final entry in records.entries) {
      if (!entry.value.solved ||
          entry.key.startsWith('daily@') ||
          entry.key.startsWith('weekly@')) {
        continue;
      }
      total += masteryXp(
        difficulty[entry.key] ?? Difficulty.medium,
        perfect: entry.value.perfect,
      );
    }
  }

  add(save.parcelRecords);
  add(save.threadRecords);
  add(save.traceRecords);
  add(save.inkRecords);
  return total;
}

Map<String, LevelRecord> _mergeMaps(
  Map<String, LevelRecord> device,
  Map<String, LevelRecord> account,
) {
  final ids = {...device.keys, ...account.keys};
  return {for (final id in ids) id: _mergeRecord(device[id], account[id])};
}

LevelRecord _mergeRecord(LevelRecord? device, LevelRecord? account) {
  if (device == null) return account!;
  if (account == null) return device;
  final solved = device.solved || account.solved;
  int? faster(int? left, int? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left < right ? left : right;
  }

  final hints = !solved
      ? 0
      : [
          if (device.solved) device.hintsOnBestSolve,
          if (account.solved) account.hintsOnBestSolve,
        ].reduce((left, right) => left < right ? left : right);
  return LevelRecord(
    solved: solved,
    skipped: !solved && (device.skipped || account.skipped),
    hintsOnBestSolve: hints,
    bestMs: faster(device.bestMs, account.bestMs),
    perfectBestMs: faster(device.perfectBestMs, account.perfectBestMs),
  );
}
