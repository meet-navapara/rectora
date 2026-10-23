import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rectora/data/google_account.dart';
import 'package:rectora/data/http_progress_cloud.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/account/account_binder.dart';
import 'package:rectora/domain/account/auth_types.dart';
import 'package:rectora/domain/account/cloud_types.dart';
import 'package:rectora/domain/account/progress_merge.dart';
import 'package:rectora/domain/account/runtime_config.dart';
import 'package:rectora/domain/account/sync_flow.dart';
import 'package:rectora/domain/campaign/achievements.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/tutorial/home_tour.dart';
import 'package:rectora/domain/common/date_key.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/relics.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/domain/profile/profile.dart';
import 'package:rectora/domain/settings/settings.dart';

class RectoraController extends ChangeNotifier {
  RectoraController({
    required this.catalog,
    required this.store,
    DateTime Function()? clock,
    AccountGateway? accounts,
    ProgressCloud? cloud,
    AccountBinder? firebaseBind,
  }) : clock = clock ?? DateTime.now,
       accounts = accounts ?? GoogleAccountGateway(),
       cloud = cloud ?? HttpProgressCloud(syncBaseUrl),
       firebaseBind = firebaseBind ?? const NoAccountBinder();

  final GameCatalog catalog;
  final KeyValueStore store;
  final DateTime Function() clock;
  final AccountGateway accounts;
  final ProgressCloud cloud;
  final AccountBinder firebaseBind;

  SaveGame save = SaveGame.fresh();
  Object? loadError;
  bool ready = false;
  SyncPhase syncPhase = SyncPhase.localOnly;
  String? accountMessage;
  bool accountMessageIsError = false;
  var homeTourToken = 0;
  var suggestNextMode = false;
  bool authBusy = false;
  bool syncBusy = false;
  String? _idToken;
  Timer? _syncTimer;

  DateTime get now => clock();

  Future<void> bootstrap() async {
    try {
      save = decodeSave(await store.read(saveKey));
      loadError = null;
      ready = true;
      _refreshPhase();
    } on FormatException catch (error) {
      loadError = error;
      ready = true;
    }
    notifyListeners();
    if (save.isGoogle) {
      unawaited(restoreAndSync());
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void onAppResumed() {
    if (save.isGuest || !cloud.configured) return;
    if (syncPhase == SyncPhase.offline ||
        syncPhase == SyncPhase.failed ||
        syncPhase == SyncPhase.signInToSync ||
        save.needsSync) {
      unawaited(syncNow());
    }
  }

  Future<void> replaceDamagedSave() async {
    save = SaveGame.fresh();
    loadError = null;
    await _persist();
  }

  Map<String, Difficulty> get difficulties {
    return {
      for (final level in catalog.parcels) level.id: level.difficulty,
      for (final level in catalog.traces) level.id: level.difficulty,
      for (final level in catalog.inks) level.id: level.difficulty,
      for (final level in catalog.threads) level.id: level.difficulty,
      for (final id in save.parcelRecords.keys)
        if (id.startsWith('daily@')) id: Difficulty.medium,
    };
  }

  DerivedStats get stats =>
      save.stats(today: now, parcelDifficulty: difficulties);

  List<Achievement> get achievements {
    final master = catalog.parcels
        .where((level) => level.difficulty == Difficulty.master)
        .where((level) => save.parcelRecords[level.id]?.solved == true)
        .length;
    return achievementsFor(
      stats: stats,
      save: save,
      parcelPacksCleared: _clearedPacks(threads: false),
      masterSolved: master,
    );
  }

  int _clearedPacks({required bool threads}) {
    var count = 0;
    for (final pack in catalog.packsFor(threads)) {
      final records = threads ? save.threadRecords : save.parcelRecords;
      final cleared = pack.levelIds.every((id) => records[id]?.solved == true);
      if (cleared) count++;
    }
    return count;
  }

  String continueParcelId() {
    final last = save.lastPlayed;
    if (last != null && catalog.parcelById(last) != null) return last;
    for (final level in catalog.parcels) {
      if (save.parcelUnlocked(catalog.parcelIds, level.id) &&
          save.parcelRecords[level.id]?.finished != true) {
        return level.id;
      }
    }
    return catalog.parcels.first.id;
  }

  ParcelLevel? nextParcel(String id) {
    final index = catalog.parcelIds.indexOf(id);
    if (index < 0 || index + 1 >= catalog.parcels.length) return null;
    final next = catalog.parcels[index + 1];
    if (!save.parcelUnlocked(catalog.parcelIds, next.id)) return null;
    return next;
  }

  ThreadLevel? nextThread(String id) {
    final index = catalog.threadIds.indexOf(id);
    if (index < 0 || index + 1 >= catalog.threads.length) return null;
    final next = catalog.threads[index + 1];
    if (!save.threadUnlocked(catalog.threadIds, next.id)) return null;
    return next;
  }

  Future<void> updateSettings(Settings settings) async {
    save = save.copyWith(settings: settings);
    await _persist();
  }

  Future<String?> updateName(String raw) async {
    final name = validateDisplayName(raw);
    if (name == null) {
      return 'Use 1–16 letters, numbers, spaces, or hyphens.';
    }
    save = save.copyWith(profile: save.profile.copyWith(name: name));
    await _persist();
    return null;
  }

  Future<void> updateAvatar(int index) async {
    if (index < 0 || index >= Profile.avatarCount) return;
    save = save.copyWith(profile: save.profile.copyWith(avatar: index));
    await _persist();
  }

  Future<void> remember(String id) async {
    if (save.lastPlayed == id) return;
    save = save.remember(id);
    await _persist();
  }

  Future<void> markStarted({
    required String id,
    bool thread = false,
    PlayMode? mode,
  }) async {
    final next = save
        .markStarted(thread: thread, mode: mode, id: id)
        .remember(id);
    if (identical(next, save)) return;
    save = next;
    await _persist();
  }

  Future<void> saveDraft({
    required String id,
    required PuzzleDraft? draft,
  }) async {
    save = save.putDraft(id, draft).remember(id);
    await _persist();
  }

  Future<LevelRecord> finishLevel({
    required String id,
    bool thread = false,
    PlayMode? mode,
    required bool skipped,
    required int hintsUsed,
    required int elapsedMs,
  }) async {
    final resolved = mode ?? (thread ? PlayMode.thread : PlayMode.parcel);
    final previouslySolved = save.recordsFor(resolved)[id]?.solved == true;
    save = save
        .finishLevel(
          thread: thread,
          mode: resolved,
          id: id,
          skipped: skipped,
          hintsUsed: hintsUsed,
          elapsedMs: elapsedMs,
        )
        .remember(id);
    if (!skipped &&
        !previouslySolved &&
        !id.startsWith('daily@') &&
        !id.startsWith('weekly@')) {
      final difficulty = difficulties[id] ?? Difficulty.medium;
      save = save.copyWith(
        xp: save.xp + masteryXp(difficulty, perfect: hintsUsed == 0),
      );
    }
    final week = weekKey(now);
    final weekly = weeklyLevelIds(week, _weeklyPool());
    if (!skipped && weekly.contains(id)) {
      save = save.markWeekly(week, id);
      if (save.weeklyReady(week, weekly)) {
        save = save.claimWeekly(week);
      }
    }
    _claimFinishedChapters();
    await _persist();
    return save.recordsFor(resolved)[id]!;
  }

  List<String> _weeklyPool() {
    final ids = [
      for (final level in catalog.parcels)
        if (level.difficulty.index >= Difficulty.medium.index) level.id,
    ];
    return ids.isEmpty ? catalog.parcelIds : ids;
  }

  List<String> weeklyIds() => weeklyLevelIds(weekKey(now), _weeklyPool());

  void _claimFinishedChapters() {
    for (final mode in PlayMode.values) {
      final packs = switch (mode) {
        PlayMode.parcel => catalog.parcelChapters,
        PlayMode.thread => catalog.packsFor(true),
        PlayMode.trace => catalog.tracePacks,
        PlayMode.ink => catalog.inkPacks,
      };
      final records = save.recordsFor(mode);
      for (final pack in packs) {
        final key = chapterKey(mode.name, pack.id);
        if (!chapterSolved(pack, records)) continue;
        save = save.claimChapter(key);
      }
    }
  }

  Future<void> seeChapters(Iterable<String> keys) async {
    final next = save.seeChapters(keys);
    if (identical(next, save)) return;
    save = next;
    await _persist();
  }

  Future<void> noteWeekly(String id) async {
    final week = weekKey(now);
    if (!weeklyIds().contains(id)) return;
    save = save.markWeekly(week, id);
    if (save.weeklyReady(week, weeklyIds())) {
      save = save.claimWeekly(week);
    }
    await _persist();
  }

  Future<void> replayTutorials() async {
    save = save.replayTutorials();
    await _persist();
  }

  Future<void> forgetTutorial(String id) async {
    final next = save.forgetTutorial(id);
    if (identical(next, save)) return;
    save = next;
    await _persist();
  }

  TraceLevel? nextTrace(String id) {
    final index = catalog.traceIds.indexOf(id);
    if (index < 0 || index + 1 >= catalog.traces.length) return null;
    final next = catalog.traces[index + 1];
    if (!save.unlocked(PlayMode.trace, catalog.traceIds, next.id)) return null;
    return next;
  }

  InkLevel? nextInk(String id) {
    final index = catalog.inkIds.indexOf(id);
    if (index < 0 || index + 1 >= catalog.inks.length) return null;
    final next = catalog.inks[index + 1];
    if (!save.unlocked(PlayMode.ink, catalog.inkIds, next.id)) return null;
    return next;
  }

  Future<void> noteHints(int count) async {
    final next = save.addHints(count);
    if (identical(next, save)) return;
    save = next;
    await _persist();
  }

  Future<bool> completeDaily(DateTime day) async {
    final updated = save.completeDaily(dateKey(day));
    save = updated.$1;
    await _persist();
    return updated.$2;
  }

  Future<void> seeTutorial(String id) async {
    final next = save.seeTutorial(id);
    if (identical(next, save)) return;
    save = next;
    if (isModeLesson(id)) suggestNextMode = true;
    await _persist();
  }

  Future<void> finishHomeTour() async {
    save = save
        .seeTutorial(homeIntroId)
        .copyWith(onboardingVersion: currentOnboardingVersion);
    await _persist();
  }

  Future<void> skipHomeTour() async {
    save = save
        .skipTutorial(homeIntroId)
        .copyWith(onboardingVersion: currentOnboardingVersion);
    suggestNextMode = false;
    await _persist();
  }

  Future<void> requestHomeTour() async {
    save = save.forgetTutorial(homeIntroId);
    homeTourToken++;
    await _persist();
    notifyListeners();
  }

  void dismissModeOffer() {
    suggestNextMode = false;
    notifyListeners();
  }

  Future<void> enterApp() async {
    if (save.entered) return;
    save = save.copyWith(entered: true);
    await _persist();
    notifyListeners();
  }

  Future<void> skipTutorial(String id) async {
    final next = save.skipTutorial(id);
    if (identical(next, save)) return;
    save = next;
    await _persist();
  }

  Future<void> clearProgress() async {
    _syncTimer?.cancel();
    save = save.clearProgress().copyWith(needsSync: false);
    await _persist(fromSync: true);
  }

  Future<void> signInWithGoogle() async {
    if (authBusy) return;
    authBusy = true;
    accountMessage = null;
    accountMessageIsError = false;
    notifyListeners();
    try {
      final result = await accounts.signIn();
      final identity = result.identity;
      if (identity == null || identity.id.isEmpty) {
        accountMessage = (result.failure ?? AuthFailure.failed).message;
        accountMessageIsError = true;
        return;
      }
      await _acceptIdentity(identity);
    } finally {
      authBusy = false;
      notifyListeners();
    }
  }

  Future<void> restoreAndSync() async {
    if (!save.isGoogle) return;
    final restored = await accounts.restore();
    final identity = restored.identity;
    if (identity == null ||
        identity.id != save.accountPlayerId ||
        identity.id.isEmpty) {
      _refreshPhase();
      notifyListeners();
      return;
    }
    _idToken = identity.idToken;
    if (cloud.configured && (_idToken?.isNotEmpty ?? false)) {
      await syncNow();
      return;
    }
    _refreshPhase();
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (syncBusy || authBusy) return;
    if (save.isGuest) {
      syncPhase = SyncPhase.localOnly;
      notifyListeners();
      return;
    }
    if (!cloud.configured) {
      syncPhase = SyncPhase.notConfigured;
      notifyListeners();
      return;
    }
    if (_idToken == null || _idToken!.isEmpty) {
      final restored = await accounts.restore();
      final identity = restored.identity;
      if (identity != null &&
          identity.id == save.accountPlayerId &&
          (identity.idToken?.isNotEmpty ?? false)) {
        _idToken = identity.idToken;
      }
    }
    if (_idToken == null || _idToken!.isEmpty) {
      syncPhase = SyncPhase.signInToSync;
      accountMessage = 'Sign in again to sync this account.';
      accountMessageIsError = true;
      notifyListeners();
      return;
    }
    syncBusy = true;
    syncPhase = SyncPhase.syncing;
    notifyListeners();
    try {
      final fetch = await cloud.download(_idToken!);
      if (fetch is CloudUnavailable) {
        syncPhase = fetch.offline ? SyncPhase.offline : SyncPhase.failed;
        accountMessage = fetch.offline
            ? 'Internet connection required.'
            : 'Sync failed. Progress stays on this device.';
        accountMessageIsError = true;
        save = save.copyWith(needsSync: true);
        await _persist(fromSync: true);
        return;
      }
      var snapshot = save;
      if (fetch is CloudFound) {
        final SaveGame remote;
        try {
          remote = decodeSave(fetch.record.payload);
        } on FormatException {
          syncPhase = SyncPhase.failed;
          accountMessage = 'Cloud progress could not be read. Progress on this device was kept.';
          accountMessageIsError = true;
          return;
        }
        if (remote.accountPlayerId != null &&
            remote.accountPlayerId != save.accountPlayerId) {
          syncPhase = SyncPhase.failed;
          accountMessage = 'The cloud record did not match this Google account. Nothing was overwritten.';
          accountMessageIsError = true;
          return;
        }
        final plan = mergeProgress(
          device: save,
          account: remote,
          difficulty: difficulties,
        );
        snapshot = plan.save.copyWith(
          needsSync: true,
          remoteRevision: fetch.record.revision,
        );
        if (plan.draftConflicts.isNotEmpty) {
          accountMessage = 'Some unfinished puzzles differed. This device\'s attempt was kept.';
          accountMessageIsError = false;
        }
      }
      save = snapshot;
      final pushed = await _push(snapshot);
      if (pushed && (accountMessage == null || accountMessage!.isEmpty)) {
        accountMessage = 'Signed in and synced.';
        accountMessageIsError = false;
      } else if (!pushed) {
        accountMessage = syncPhase == SyncPhase.offline
            ? 'Internet connection required.'
            : 'Sync failed. Progress stays on this device.';
        accountMessageIsError = true;
      }
    } finally {
      syncBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOutAccount() async {
    await accounts.signOut();
    await firebaseBind.unbind();
    _idToken = null;
    _syncTimer?.cancel();
    save = save.signOut();
    syncPhase = SyncPhase.localOnly;
    accountMessage = 'Signed out. Guest progress is showing. Sign in to show the levels passed on that Google account.';
    accountMessageIsError = false;
    await _persist(fromSync: true);
  }

  Future<void> deleteAccount() async {
    if (save.isGuest || syncBusy) return;
    if (!cloud.configured) {
      accountMessage = 'Account deletion needs the sync service, which is not set up for this build. Progress on this device was kept.';
      accountMessageIsError = true;
      notifyListeners();
      return;
    }
    if (_idToken == null || _idToken!.isEmpty) {
      accountMessage = 'Sign in again before deleting the account.';
      accountMessageIsError = true;
      notifyListeners();
      return;
    }
    syncBusy = true;
    notifyListeners();
    final deleted = await cloud.deleteAccount(_idToken!);
    syncBusy = false;
    if (!deleted) {
      accountMessage = 'The saved user record could not be deleted. Progress on this device was kept.';
      accountMessageIsError = true;
      notifyListeners();
      return;
    }
    _syncTimer?.cancel();
    save = save.copyWith(clearSync: true);
    syncPhase = SyncPhase.synced;
    accountMessage =
        'The saved user record was removed. This Google login is unchanged.';
    accountMessageIsError = false;
    await _persist(fromSync: true);
  }

  Future<void> _acceptIdentity(GoogleIdentity identity) async {
    _idToken = identity.idToken ?? identity.accessToken;
    final linked = await firebaseBind.bind(
      identity.idToken,
      accessToken: identity.accessToken,
    );
    save = save.activateIdentity(
      kind: 'google',
      playerId: identity.id,
      name: identity.name,
      email: identity.email,
      entered: true,
    );
    final canCloud = cloud.configured && (_idToken?.isNotEmpty ?? false);
    final fetch = canCloud
        ? await cloud.download(_idToken!)
        : const CloudEmpty();
    final bound = bindGoogleAccount(
      local: save,
      playerId: identity.id,
      name: identity.name,
      email: identity.email,
      cloudConfigured: cloud.configured,
      missingToken: cloud.configured && !canCloud,
      fetch: fetch,
      difficulty: difficulties,
    );
    save = bound.save;
    syncPhase = bound.phase;
    if (firebaseBind is! NoAccountBinder && !linked) {
      accountMessage = 'Signed in on this device. Firebase Authentication has no user for this account yet. Enable Google under Authentication, then sign out and sign in again.';
      accountMessageIsError = true;
    } else {
      accountMessage = bound.message;
      accountMessageIsError = bound.isError;
    }
    await _persist(fromSync: true);
    if (firebaseBind is! NoAccountBinder && !linked) return;
    if (!bound.shouldUpload) return;
    final pushed = await _push(save);
    if (pushed) {
      syncPhase = SyncPhase.synced;
      if (bound.draftConflicts.isEmpty) {
        accountMessage = 'Signed in and synced.';
      }
      accountMessageIsError = false;
    } else {
      accountMessage = syncPhase == SyncPhase.offline
          ? 'Internet connection required.'
          : 'Sync failed. Progress stays on this device.';
      accountMessageIsError = true;
    }
  }

  Future<bool> _push(SaveGame snapshot) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      syncPhase = SyncPhase.signInToSync;
      return false;
    }
    var current = snapshot;
    for (var attempt = 0; attempt < 2; attempt++) {
      final write = await cloud.upload(
        idToken: token,
        payload: current.copyWith(shelves: const {}).encode(),
        baseRevision: current.remoteRevision,
      );
      if (write.ok && write.record != null) {
        save = current.copyWith(
          needsSync: false,
          setLastSyncAt: true,
          lastSyncAt: now.toUtc().toIso8601String(),
          remoteRevision: write.record!.revision,
        );
        syncPhase = SyncPhase.synced;
        await _persist(fromSync: true);
        return true;
      }
      if (write.conflict && write.record != null && attempt == 0) {
        try {
          final remote = decodeSave(write.record!.payload);
          if (remote.accountPlayerId != null &&
              remote.accountPlayerId != current.accountPlayerId) {
            break;
          }
          final plan = mergeProgress(
            device: current,
            account: remote,
            difficulty: difficulties,
          );
          current = plan.save.copyWith(
            needsSync: true,
            remoteRevision: write.record!.revision,
          );
          save = current;
          continue;
        } on FormatException {
          break;
        }
      }
      syncPhase = write.offline ? SyncPhase.offline : SyncPhase.failed;
      save = current.copyWith(needsSync: true);
      await _persist(fromSync: true);
      return false;
    }
    syncPhase = SyncPhase.failed;
    save = current.copyWith(needsSync: true);
    await _persist(fromSync: true);
    return false;
  }

  void _refreshPhase() {
    if (save.isGuest) {
      syncPhase = SyncPhase.localOnly;
    } else if (!cloud.configured) {
      syncPhase = SyncPhase.notConfigured;
    } else if (_idToken == null || _idToken!.isEmpty) {
      syncPhase = SyncPhase.signInToSync;
    } else if (!save.needsSync && save.lastSyncAt != null) {
      syncPhase = SyncPhase.synced;
    } else {
      syncPhase = SyncPhase.signInToSync;
    }
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      unawaited(syncNow());
    });
  }

  Future<void> _persist({bool fromSync = false}) async {
    if (!fromSync && !save.isGuest && cloud.configured) {
      save = save.copyWith(needsSync: true);
    }
    await store.write(saveKey, save.encode());
    notifyListeners();
    if (!fromSync &&
        !save.isGuest &&
        cloud.configured &&
        (_idToken?.isNotEmpty ?? false)) {
      _scheduleSync();
    }
  }
}
