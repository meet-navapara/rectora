import 'dart:convert';

import '../daily/streak.dart';
import '../progression/rewards.dart';
import '../parcels/models.dart';
import '../profile/profile.dart';
import '../settings/settings.dart';
import 'records.dart';

const saveVersion = 1;
const saveKey = 'rectora.save.v1';

enum PlayMode { parcel, thread, trace, ink }

class SaveGame {
  const SaveGame({
    required this.settings,
    required this.profile,
    required this.parcelRecords,
    required this.threadRecords,
    required this.drafts,
    required this.parcelsStarted,
    required this.threadsStarted,
    this.traceRecords = const {},
    this.inkRecords = const {},
    this.tracesStarted = const {},
    this.inksStarted = const {},
    required this.dailyCompleted,
    required this.tutorialsSeen,
    required this.lifetimeHints,
    this.lastPlayed,
    this.xp = 0,
    this.weeklySolved = const {},
    this.weeklyClaimed = const {},
    this.claimedChapters = const {},
    this.seenChapters = const {},
    this.accountKind = 'guest',
    this.accountPlayerId,
    this.accountName,
    this.accountEmail,
    this.lastSyncAt,
    this.needsSync = false,
    this.remoteRevision = 0,
    this.entered = false,
    this.shelves = const {},
    this.onboardingVersion = 0,
  });

  factory SaveGame.fresh() {
    return const SaveGame(
      settings: Settings(),
      profile: Profile(),
      parcelRecords: {},
      threadRecords: {},
      drafts: {},
      parcelsStarted: {},
      threadsStarted: {},
      dailyCompleted: {},
      tutorialsSeen: {},
      lifetimeHints: 0,
    );
  }

  final Settings settings;
  final Profile profile;
  final Map<String, LevelRecord> parcelRecords;
  final Map<String, LevelRecord> threadRecords;
  final Map<String, PuzzleDraft> drafts;
  final Set<String> parcelsStarted;
  final Set<String> threadsStarted;
  final Map<String, LevelRecord> traceRecords;
  final Map<String, LevelRecord> inkRecords;
  final Set<String> tracesStarted;
  final Set<String> inksStarted;
  final Set<String> dailyCompleted;
  final Set<String> tutorialsSeen;
  final int lifetimeHints;
  final String? lastPlayed;
  final int xp;
  final Set<String> weeklySolved;
  final Set<String> weeklyClaimed;
  final Set<String> claimedChapters;
  final Set<String> seenChapters;
  final String accountKind;
  final String? accountPlayerId;
  final String? accountName;
  final String? accountEmail;
  final String? lastSyncAt;
  final bool needsSync;
  final int remoteRevision;

  /// True after the player chooses Google or guest on the opening screen.
  final bool entered;

  /// Home-tour revision. Version 1 is the first home-screen guide.
  ///
  /// A future guide should add its own tutorial id. Raise this only when
  /// that new guide must be offered, and do not clear older tutorial ids.
  final int onboardingVersion;

  /// Progress parked for identities that are not the active one.
  ///
  /// Guest and each Google account keep their own solved levels.
  final Map<String, String> shelves;

  String get identityKey {
    if (isGoogle) return 'google:$accountPlayerId';
    if (isPlayGames) return 'playGames:$accountPlayerId';
    return 'guest';
  }

  bool get isGoogle =>
      accountKind == 'google' &&
      accountPlayerId != null &&
      accountPlayerId!.isNotEmpty;

  bool get isPlayGames =>
      accountKind == 'playGames' &&
      accountPlayerId != null &&
      accountPlayerId!.isNotEmpty;

  bool get isGuest => !isGoogle && !isPlayGames;

  SaveGame copyWith({
    Settings? settings,
    Profile? profile,
    Map<String, LevelRecord>? parcelRecords,
    Map<String, LevelRecord>? threadRecords,
    Map<String, PuzzleDraft>? drafts,
    Set<String>? parcelsStarted,
    Set<String>? threadsStarted,
    Map<String, LevelRecord>? traceRecords,
    Map<String, LevelRecord>? inkRecords,
    Set<String>? tracesStarted,
    Set<String>? inksStarted,
    Set<String>? dailyCompleted,
    Set<String>? tutorialsSeen,
    int? lifetimeHints,
    String? lastPlayed,
    bool clearLastPlayed = false,
    int? xp,
    Set<String>? weeklySolved,
    Set<String>? weeklyClaimed,
    Set<String>? claimedChapters,
    Set<String>? seenChapters,
    String? accountKind,
    String? accountPlayerId,
    String? accountName,
    String? accountEmail,
    bool setAccountEmail = false,
    String? lastSyncAt,
    bool setLastSyncAt = false,
    bool? needsSync,
    int? remoteRevision,
    bool clearAccount = false,
    bool clearSync = false,
    bool? entered,
    Map<String, String>? shelves,
    int? onboardingVersion,
  }) {
    return SaveGame(
      settings: settings ?? this.settings,
      profile: profile ?? this.profile,
      parcelRecords: parcelRecords ?? this.parcelRecords,
      threadRecords: threadRecords ?? this.threadRecords,
      drafts: drafts ?? this.drafts,
      parcelsStarted: parcelsStarted ?? this.parcelsStarted,
      threadsStarted: threadsStarted ?? this.threadsStarted,
      traceRecords: traceRecords ?? this.traceRecords,
      inkRecords: inkRecords ?? this.inkRecords,
      tracesStarted: tracesStarted ?? this.tracesStarted,
      inksStarted: inksStarted ?? this.inksStarted,
      dailyCompleted: dailyCompleted ?? this.dailyCompleted,
      tutorialsSeen: tutorialsSeen ?? this.tutorialsSeen,
      lifetimeHints: lifetimeHints ?? this.lifetimeHints,
      lastPlayed: clearLastPlayed ? null : lastPlayed ?? this.lastPlayed,
      xp: xp ?? this.xp,
      weeklySolved: weeklySolved ?? this.weeklySolved,
      weeklyClaimed: weeklyClaimed ?? this.weeklyClaimed,
      claimedChapters: claimedChapters ?? this.claimedChapters,
      seenChapters: seenChapters ?? this.seenChapters,
      accountKind: clearAccount ? 'guest' : accountKind ?? this.accountKind,
      accountPlayerId: clearAccount
          ? null
          : accountPlayerId ?? this.accountPlayerId,
      accountName: clearAccount ? null : accountName ?? this.accountName,
      accountEmail: clearAccount
          ? null
          : setAccountEmail
          ? accountEmail
          : this.accountEmail,
      lastSyncAt: clearSync
          ? null
          : setLastSyncAt
          ? lastSyncAt
          : this.lastSyncAt,
      needsSync: clearSync ? false : needsSync ?? this.needsSync,
      remoteRevision: clearSync ? 0 : remoteRevision ?? this.remoteRevision,
      entered: entered ?? this.entered,
      shelves: shelves ?? this.shelves,
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
    );
  }

  /// Saves the active campaign under the current identity, then loads the
  /// campaign stored for [kind]. A new identity starts with no solved levels.
  SaveGame activateIdentity({
    required String kind,
    String? playerId,
    String? name,
    String? email,
    bool? entered,
  }) {
    final nextKey = identityKeyFor(kind, playerId);
    if (nextKey == identityKey) {
      return copyWith(
        clearAccount: nextKey == 'guest',
        accountKind: nextKey == 'guest' ? null : kind,
        accountPlayerId: nextKey == 'guest' ? null : playerId,
        accountName: name,
        accountEmail: email,
        setAccountEmail: email != null || nextKey == 'guest',
        entered: entered,
        clearSync: nextKey == 'guest',
      );
    }
    final stored = Map<String, String>.from(shelves);
    stored[identityKey] = progressBlob();
    final blob = stored.remove(nextKey);
    final base = blob == null
        ? SaveGame.fresh().copyWith(
            settings: settings,
            profile: profile,
            shelves: stored,
          )
        : _fromProgressBlob(blob, stored);
    return base.copyWith(
      clearAccount: nextKey == 'guest',
      accountKind: nextKey == 'guest' ? null : kind,
      accountPlayerId: nextKey == 'guest' ? null : playerId,
      accountName: name,
      accountEmail: email,
      setAccountEmail: true,
      entered: entered ?? this.entered,
      clearSync: nextKey == 'guest',
      needsSync: nextKey != 'guest',
    );
  }

  SaveGame signOut() => activateIdentity(kind: 'guest', entered: false);

  /// Signs out and drops the progress parked for this account, so a deleted
  /// account leaves nothing on the device. Guest progress is not touched.
  SaveGame deleteIdentity() {
    final key = identityKey;
    final next = signOut();
    return next.copyWith(
      shelves: Map<String, String>.from(next.shelves)..remove(key),
    );
  }

  static String identityKeyFor(String kind, String? playerId) {
    if ((kind == 'google' || kind == 'playGames') &&
        playerId != null &&
        playerId.isNotEmpty) {
      return '$kind:$playerId';
    }
    return 'guest';
  }

  String progressBlob() {
    final json = toJson()
      ..remove('shelves')
      ..remove('settings')
      ..remove('profile')
      ..remove('accountKind')
      ..remove('accountPlayerId')
      ..remove('accountName')
      ..remove('accountEmail')
      ..remove('lastSyncAt')
      ..remove('needsSync')
      ..remove('remoteRevision')
      ..remove('entered');
    return jsonEncode(json);
  }

  SaveGame _fromProgressBlob(String blob, Map<String, String> stored) {
    final decoded = jsonDecode(blob);
    if (decoded is! Map) {
      return SaveGame.fresh().copyWith(
        settings: settings,
        profile: profile,
        shelves: stored,
      );
    }
    final json = Map<String, Object?>.from(decoded);
    json['v'] = saveVersion;
    json['settings'] = settings.toJson();
    json['profile'] = profile.toJson();
    return SaveGame.fromJson(json).copyWith(shelves: stored);
  }

  SaveGame markWeekly(String week, String id) {
    final key = '$week|$id';
    if (weeklySolved.contains(key)) return this;
    return copyWith(weeklySolved: {...weeklySolved, key});
  }

  bool weeklyReady(String week, List<String> ids) {
    return ids.isNotEmpty &&
        ids.every((id) => weeklySolved.contains('$week|$id'));
  }

  /// Awards the chapter bonus once per chapter key.
  SaveGame claimChapter(String key) {
    if (claimedChapters.contains(key) || key.isEmpty) return this;
    return copyWith(
      claimedChapters: {...claimedChapters, key},
      xp: xp + chapterClearBonus,
    );
  }

  SaveGame seeChapters(Iterable<String> keys) {
    final next = {...seenChapters, ...keys};
    if (next.length == seenChapters.length) return this;
    return copyWith(seenChapters: next);
  }

  /// Awards the weekly bonus once per week key.
  SaveGame claimWeekly(String week) {
    if (weeklyClaimed.contains(week) || week.isEmpty) return this;
    return copyWith(
      weeklyClaimed: {...weeklyClaimed, week},
      xp: xp + weeklyClearBonus,
    );
  }

  SaveGame remember(String id) => copyWith(lastPlayed: id);

  SaveGame markStarted({
    bool thread = false,
    PlayMode? mode,
    required String id,
  }) {
    final resolved = mode ?? (thread ? PlayMode.thread : PlayMode.parcel);
    final started = switch (resolved) {
      PlayMode.parcel => parcelsStarted,
      PlayMode.thread => threadsStarted,
      PlayMode.trace => tracesStarted,
      PlayMode.ink => inksStarted,
    };
    if (started.contains(id)) return this;
    final next = {...started, id};
    return switch (resolved) {
      PlayMode.parcel => copyWith(parcelsStarted: next),
      PlayMode.thread => copyWith(threadsStarted: next),
      PlayMode.trace => copyWith(tracesStarted: next),
      PlayMode.ink => copyWith(inksStarted: next),
    };
  }

  SaveGame putDraft(String id, PuzzleDraft? draft) {
    final next = Map<String, PuzzleDraft>.from(drafts);
    if (draft == null) {
      next.remove(id);
    } else {
      next[id] = draft;
    }
    return copyWith(drafts: next);
  }

  /// Records a finished attempt. Replays update best times without counting
  /// another solve. A later real solve replaces a skip.
  SaveGame finishLevel({
    bool thread = false,
    PlayMode? mode,
    required String id,
    required bool skipped,
    required int hintsUsed,
    required int elapsedMs,
  }) {
    final resolved = mode ?? (thread ? PlayMode.thread : PlayMode.parcel);
    final source = switch (resolved) {
      PlayMode.parcel => parcelRecords,
      PlayMode.thread => threadRecords,
      PlayMode.trace => traceRecords,
      PlayMode.ink => inkRecords,
    };
    final previous = source[id];
    var record =
        previous ??
        const LevelRecord(solved: false, skipped: false, hintsOnBestSolve: 0);

    if (skipped) {
      if (!record.solved) {
        record = record.copyWith(skipped: true);
      }
    } else {
      final better = record.bestMs == null || elapsedMs < record.bestMs!;
      final perfectTime =
          hintsUsed == 0 &&
          (record.perfectBestMs == null || elapsedMs < record.perfectBestMs!);
      record = record.copyWith(
        solved: true,
        skipped: false,
        hintsOnBestSolve: previous == null || previous.skipped
            ? hintsUsed
            : record.hintsOnBestSolve,
        bestMs: better ? elapsedMs : record.bestMs,
        perfectBestMs: perfectTime ? elapsedMs : record.perfectBestMs,
      );
    }

    final nextMap = Map<String, LevelRecord>.from(source)..[id] = record;
    final nextDrafts = Map<String, PuzzleDraft>.from(drafts)..remove(id);
    return switch (resolved) {
      PlayMode.parcel => copyWith(
        parcelRecords: nextMap,
        drafts: nextDrafts,
        parcelsStarted: {...parcelsStarted, id},
      ),
      PlayMode.thread => copyWith(
        threadRecords: nextMap,
        drafts: nextDrafts,
        threadsStarted: {...threadsStarted, id},
      ),
      PlayMode.trace => copyWith(
        traceRecords: nextMap,
        drafts: nextDrafts,
        tracesStarted: {...tracesStarted, id},
      ),
      PlayMode.ink => copyWith(
        inkRecords: nextMap,
        drafts: nextDrafts,
        inksStarted: {...inksStarted, id},
      ),
    };
  }

  Map<String, LevelRecord> recordsFor(PlayMode mode) {
    return switch (mode) {
      PlayMode.parcel => parcelRecords,
      PlayMode.thread => threadRecords,
      PlayMode.trace => traceRecords,
      PlayMode.ink => inkRecords,
    };
  }

  /// Skips this mode can still use. Solving a skipped level gives one back.
  int skipsLeft(PlayMode mode) {
    final open = recordsFor(mode).entries.where(
      (entry) =>
          !entry.key.startsWith('daily@') &&
          !entry.key.startsWith('weekly@') &&
          entry.value.skipped &&
          !entry.value.solved,
    );
    return skipAllowance - open.length;
  }

  bool unlocked(PlayMode mode, List<String> orderedIds, String id) =>
      _open(recordsFor(mode), orderedIds, id);

  SaveGame addHints(int count) {
    if (count <= 0) return this;
    return copyWith(lifetimeHints: lifetimeHints + count);
  }

  /// Returns the updated save and whether this date was newly completed.
  (SaveGame, bool) completeDaily(String date) {
    if (dailyCompleted.contains(date)) return (this, false);
    return (copyWith(dailyCompleted: {...dailyCompleted, date}), true);
  }

  SaveGame seeTutorial(String id) {
    if (tutorialsSeen.contains(id)) return this;
    return copyWith(tutorialsSeen: {...tutorialsSeen, id});
  }

  SaveGame skipTutorial(String id) {
    if (tutorialsSeen.contains(id) || tutorialsSeen.contains('$id:skipped')) {
      return this;
    }
    return copyWith(tutorialsSeen: {...tutorialsSeen, '$id:skipped'});
  }

  SaveGame replayTutorials() => copyWith(tutorialsSeen: const {});

  /// Drops one lesson flag so that lesson can play again.
  /// Solved puzzles stay in the campaign records.
  SaveGame forgetTutorial(String id) {
    if (id.isEmpty) return this;
    final next = Set<String>.from(tutorialsSeen)
      ..remove(id)
      ..remove('$id:skipped');
    if (next.length == tutorialsSeen.length) return this;
    return copyWith(tutorialsSeen: next);
  }

  /// Clears puzzles, stats, streaks, and drafts. Settings and the local
  /// profile name stay, because they are preferences rather than progress.
  SaveGame clearProgress() {
    final parked = Map<String, String>.from(shelves)..remove(identityKey);
    return SaveGame(
      settings: settings,
      profile: profile,
      parcelRecords: const {},
      threadRecords: const {},
      drafts: const {},
      parcelsStarted: const {},
      threadsStarted: const {},
      dailyCompleted: const {},
      tutorialsSeen: const {},
      lifetimeHints: 0,
      accountKind: accountKind,
      accountPlayerId: accountPlayerId,
      accountName: accountName,
      accountEmail: accountEmail,
      lastSyncAt: lastSyncAt,
      needsSync: needsSync,
      remoteRevision: remoteRevision,
      entered: entered,
      shelves: parked,
    );
  }

  bool parcelUnlocked(List<String> orderedIds, String id) =>
      _open(parcelRecords, orderedIds, id);

  bool threadUnlocked(List<String> orderedIds, String id) =>
      _open(threadRecords, orderedIds, id);

  /// A level is open when the one before it is finished, or when the player
  /// has already finished it or any later level. Progress from an older order
  /// of levels can leave gaps, and a gap must never lock a level behind it.
  static bool _open(
    Map<String, LevelRecord> records,
    List<String> orderedIds,
    String id,
  ) {
    final index = orderedIds.indexOf(id);
    if (index <= 0) return index == 0;
    for (var i = index - 1; i < orderedIds.length; i++) {
      if (records[orderedIds[i]]?.finished == true) return true;
    }
    return false;
  }

  DerivedStats stats({
    required DateTime today,
    required Map<String, Difficulty> parcelDifficulty,
  }) {
    var parcelsSolved = 0;
    var parcelsSkipped = 0;
    var perfectClears = 0;
    int? bestParcel;
    int? bestPerfect;
    final byDifficulty = {for (final value in Difficulty.values) value: 0};
    for (final entry in parcelRecords.entries) {
      if (entry.key.startsWith('daily@') || entry.key.startsWith('weekly@')) {
        continue;
      }
      final record = entry.value;
      if (record.solved) {
        parcelsSolved++;
        final difficulty = parcelDifficulty[entry.key];
        if (difficulty != null) {
          byDifficulty[difficulty] = byDifficulty[difficulty]! + 1;
        }
      } else if (record.skipped) {
        parcelsSkipped++;
      }
      if (record.perfect) perfectClears++;
      if (record.bestMs != null &&
          (bestParcel == null || record.bestMs! < bestParcel)) {
        bestParcel = record.bestMs;
      }
      if (record.perfectBestMs != null &&
          (bestPerfect == null || record.perfectBestMs! < bestPerfect)) {
        bestPerfect = record.perfectBestMs;
      }
    }
    var tracesSolved = 0;
    var inksSolved = 0;
    for (final entry in traceRecords.entries) {
      if (!entry.value.solved) continue;
      tracesSolved++;
      final difficulty = parcelDifficulty[entry.key];
      if (difficulty != null) {
        byDifficulty[difficulty] = byDifficulty[difficulty]! + 1;
      }
    }
    for (final entry in inkRecords.entries) {
      if (!entry.value.solved) continue;
      inksSolved++;
      final difficulty = parcelDifficulty[entry.key];
      if (difficulty != null) {
        byDifficulty[difficulty] = byDifficulty[difficulty]! + 1;
      }
    }
    var threadsSolved = 0;
    int? bestThread;
    for (final entry in threadRecords.entries) {
      final record = entry.value;
      if (record.solved) {
        threadsSolved++;
        final difficulty = parcelDifficulty[entry.key];
        if (difficulty != null) {
          byDifficulty[difficulty] = byDifficulty[difficulty]! + 1;
        }
      }
      if (record.perfect) perfectClears++;
      if (record.bestMs != null &&
          (bestThread == null || record.bestMs! < bestThread)) {
        bestThread = record.bestMs;
      }
    }
    return DerivedStats(
      parcelsSolved: parcelsSolved,
      threadsSolved: threadsSolved,
      tracesSolved: tracesSolved,
      inksSolved: inksSolved,
      parcelsSkipped: parcelsSkipped,
      perfectClears: perfectClears,
      bestParcelMs: bestParcel,
      bestPerfectParcelMs: bestPerfect,
      bestThreadMs: bestThread,
      parcelStarts: parcelsStarted
          .where((id) => !id.startsWith('daily@') && !id.startsWith('weekly@'))
          .length,
      threadStarts: threadsStarted.length,
      hintsUsed: lifetimeHints,
      solvedByDifficulty: byDifficulty,
      currentStreak: currentStreak(dailyCompleted, today),
      longestStreak: longestStreak(dailyCompleted),
      dailyCompletions: dailyCompleted.length,
    );
  }

  Map<String, Object?> toJson() => {
    'v': saveVersion,
    'settings': settings.toJson(),
    'profile': profile.toJson(),
    'parcels': parcelRecords.map((key, value) => MapEntry(key, value.toJson())),
    'threads': threadRecords.map((key, value) => MapEntry(key, value.toJson())),
    'traces': traceRecords.map((key, value) => MapEntry(key, value.toJson())),
    'inks': inkRecords.map((key, value) => MapEntry(key, value.toJson())),
    'drafts': drafts.map((key, value) => MapEntry(key, value.toJson())),
    'parcelsStarted': parcelsStarted.toList(),
    'threadsStarted': threadsStarted.toList(),
    'tracesStarted': tracesStarted.toList(),
    'inksStarted': inksStarted.toList(),
    'daily': dailyCompleted.toList(),
    'tutorials': tutorialsSeen.toList(),
    'lifetimeHints': lifetimeHints,
    'lastPlayed': lastPlayed,
    'xp': xp,
    'weeklySolved': weeklySolved.toList(),
    'weeklyClaimed': weeklyClaimed.toList(),
    'claimedChapters': claimedChapters.toList(),
    'seenChapters': seenChapters.toList(),
    'accountKind': accountKind,
    if (accountPlayerId != null) 'accountPlayerId': accountPlayerId,
    if (accountName != null) 'accountName': accountName,
    if (accountEmail != null) 'accountEmail': accountEmail,
    if (lastSyncAt != null) 'lastSyncAt': lastSyncAt,
    'needsSync': needsSync,
    'remoteRevision': remoteRevision,
    'entered': entered,
    if (shelves.isNotEmpty) 'shelves': shelves,
    if (onboardingVersion > 0) 'onboardingVersion': onboardingVersion,
  };

  String encode() => jsonEncode(toJson());

  factory SaveGame.fromJson(Map<String, Object?> json) {
    final version = json['v'];
    if (version != saveVersion) {
      throw FormatException('Unsupported save version: $version');
    }
    Map<String, T> mapOf<T>(
      Object? raw,
      T Function(Map<String, Object?>) decode,
    ) {
      if (raw is! Map) return {};
      final result = <String, T>{};
      for (final entry in raw.entries) {
        if (entry.value is Map) {
          result[entry.key.toString()] = decode(
            Map<String, Object?>.from(entry.value as Map),
          );
        }
      }
      return result;
    }

    Set<String> stringSet(Object? raw) {
      if (raw is! List) return {};
      return {for (final value in raw) value.toString()};
    }

    return SaveGame(
      settings: json['settings'] is Map
          ? Settings.fromJson(
              Map<String, Object?>.from(json['settings'] as Map),
            )
          : const Settings(),
      profile: json['profile'] is Map
          ? Profile.fromJson(Map<String, Object?>.from(json['profile'] as Map))
          : const Profile(),
      parcelRecords: mapOf(json['parcels'], LevelRecord.fromJson),
      threadRecords: mapOf(json['threads'], LevelRecord.fromJson),
      traceRecords: mapOf(json['traces'], LevelRecord.fromJson),
      inkRecords: mapOf(json['inks'], LevelRecord.fromJson),
      drafts: mapOf(json['drafts'], PuzzleDraft.fromJson),
      parcelsStarted: stringSet(json['parcelsStarted']),
      threadsStarted: stringSet(json['threadsStarted']),
      tracesStarted: stringSet(json['tracesStarted']),
      inksStarted: stringSet(json['inksStarted']),
      dailyCompleted: stringSet(json['daily']),
      tutorialsSeen: stringSet(json['tutorials']),
      lifetimeHints: json['lifetimeHints'] is int
          ? json['lifetimeHints'] as int
          : 0,
      lastPlayed: json['lastPlayed'] is String
          ? json['lastPlayed'] as String
          : null,
      xp: json['xp'] is int && (json['xp'] as int) > 0 ? json['xp'] as int : 0,
      weeklySolved: stringSet(json['weeklySolved']),
      weeklyClaimed: stringSet(json['weeklyClaimed']),
      claimedChapters: stringSet(json['claimedChapters']),
      seenChapters: stringSet(json['seenChapters']),
      accountKind: switch (json['accountKind']) {
        'google' => 'google',
        'playGames' => 'playGames',
        _ => 'guest',
      },
      accountPlayerId: json['accountPlayerId'] is String
          ? json['accountPlayerId'] as String
          : null,
      accountName: json['accountName'] is String
          ? json['accountName'] as String
          : null,
      accountEmail: json['accountEmail'] is String
          ? json['accountEmail'] as String
          : null,
      lastSyncAt: json['lastSyncAt'] is String
          ? json['lastSyncAt'] as String
          : null,
      needsSync: json['needsSync'] == true,
      remoteRevision: json['remoteRevision'] is int
          ? json['remoteRevision'] as int
          : 0,
      entered: json['entered'] == true,
      shelves: _shelfMap(json['shelves']),
      onboardingVersion: json['onboardingVersion'] is int
          ? json['onboardingVersion'] as int
          : 0,
    );
  }
}

Map<String, String> _shelfMap(Object? raw) {
  if (raw is! Map) return {};
  final result = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is String && value.isNotEmpty) {
      result[entry.key.toString()] = value;
    }
  }
  return result;
}

SaveGame decodeSave(String? raw) {
  if (raw == null || raw.trim().isEmpty) return SaveGame.fresh();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Save data is not an object.');
  }
  return SaveGame.fromJson(Map<String, Object?>.from(decoded));
}
