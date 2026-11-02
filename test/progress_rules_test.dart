import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/common/date_key.dart';
import 'package:rectora/domain/daily/streak.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/profile/profile.dart';
import 'package:rectora/domain/settings/settings.dart';

void main() {
  test('civil dates ignore daylight-saving length', () {
    final before = DateTime(2026, 3, 8);
    final after = DateTime(2026, 3, 9);
    expect(civilDaysBetween(before, after), 1);
    expect(dateKey(DateTime(2026, 10, 21, 23, 30)), '2026-10-21');
  });

  test('October 2026 starts on Thursday in a Sunday-first grid', () {
    expect(DateTime(2026, 10, 1).weekday, DateTime.thursday);
    final cells = monthCells(2026, 10);
    expect(cells[4], DateTime(2026, 10, 1));
    expect(cells.whereType<DateTime>().length, 31);
    expect(monthCells(2026, 2).whereType<DateTime>().length, 28);
  });

  test('the same date selects the same daily puzzle', () {
    final first = dailyPoolIndex(DateTime(2026, 10, 21, 1), 500);
    final later = dailyPoolIndex(DateTime(2026, 10, 21, 23), 500);
    final next = dailyPoolIndex(DateTime(2026, 10, 22), 500);
    expect(first, later);
    expect(next, isNot(first));
    expect(
      dailyPoolIndex(DateTime(2025, 12, 31), 500),
      inInclusiveRange(0, 499),
    );
  });

  test('streaks break after a missed day and ignore duplicate dates', () {
    final today = DateTime(2026, 10, 21);
    expect(currentStreak({'2026-10-19', '2026-10-20', '2026-10-21'}, today), 3);
    expect(currentStreak({'2026-10-20'}, today), 1);
    expect(currentStreak({'2026-10-19'}, today), 0);
    expect(longestStreak({'2026-10-01', '2026-10-02', '2026-10-04'}), 2);
    expect(
      dailyState(
        day: DateTime(2026, 10, 22),
        today: today,
        completed: const {},
      ),
      DailyDayState.future,
    );
    expect(
      dailyState(day: today, today: today, completed: const {}),
      DailyDayState.todayOpen,
    );
  });

  test('settings and profile round-trip and reject unsafe names', () {
    const settings = Settings(
      theme: ThemeChoice.dark,
      haptics: false,
      sound: false,
      showTimer: false,
      showSize: true,
      cornerPlacement: true,
    );
    final restored = Settings.fromJson(settings.toJson());
    expect(restored.theme, ThemeChoice.dark);
    expect(restored.haptics, isFalse);
    expect(restored.showSize, isTrue);
    expect(validateDisplayName('  Ada  Lovelace '), 'Ada Lovelace');
    expect(validateDisplayName(''), isNull);
    expect(validateDisplayName('names\nwith breaks'), isNull);
    expect(validateDisplayName('A very long display name'), isNull);
  });

  test('no difficulty refuses a legal move on the player\'s behalf', () {
    for (final difficulty in Difficulty.values) {
      expect(strictnessFor(difficulty), Strictness.basic);
    }
  });

  test('skips run out, and solving a skipped level gives one back', () {
    var save = SaveGame.fresh();
    expect(save.skipsLeft(PlayMode.parcel), 3);
    for (final id in ['parcel-001', 'parcel-002', 'parcel-003']) {
      save = save.finishLevel(
        id: id,
        skipped: true,
        hintsUsed: 0,
        elapsedMs: 1,
      );
    }
    expect(save.skipsLeft(PlayMode.parcel), 0);
    expect(save.skipsLeft(PlayMode.trace), 3);
    save = save.finishLevel(
      id: 'parcel-002',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 1,
    );
    expect(save.skipsLeft(PlayMode.parcel), 1);
  });

  test('progress unlocks, replays, skips, and restarts stay consistent', () {
    var save = SaveGame.fresh().markStarted(thread: false, id: 'parcel-001');
    save = save.finishLevel(
      thread: false,
      id: 'parcel-001',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 12000,
    );
    save = save.finishLevel(
      thread: false,
      id: 'parcel-002',
      skipped: true,
      hintsUsed: 0,
      elapsedMs: 0,
    );
    expect(
      save.parcelUnlocked([
        'parcel-001',
        'parcel-002',
        'parcel-003',
      ], 'parcel-002'),
      isTrue,
    );
    expect(
      save.parcelUnlocked([
        'parcel-001',
        'parcel-002',
        'parcel-003',
      ], 'parcel-003'),
      isTrue,
    );
    final encoded = decodeSave(save.encode());
    expect(encoded.parcelRecords['parcel-001']!.perfect, isTrue);
    expect(encoded.parcelRecords['parcel-002']!.skipped, isTrue);

    save = encoded.finishLevel(
      thread: false,
      id: 'parcel-001',
      skipped: false,
      hintsUsed: 2,
      elapsedMs: 9000,
    );
    final again = save.parcelRecords['parcel-001']!;
    expect(again.bestMs, 9000);
    expect(again.perfectBestMs, 12000);
    expect(again.hintsOnBestSolve, 0);

    save = save.finishLevel(
      thread: false,
      id: 'parcel-002',
      skipped: false,
      hintsUsed: 1,
      elapsedMs: 4000,
    );
    final stats = save.stats(
      today: DateTime(2026, 10, 21),
      parcelDifficulty: {
        'parcel-001': Difficulty.easy,
        'parcel-002': Difficulty.medium,
      },
    );
    expect(stats.parcelsSolved, 2);
    expect(stats.parcelsSkipped, 0);
    expect(stats.parcelStarts, 2);
    expect(stats.solvedByDifficulty[Difficulty.easy], 1);

    final cleared = save.clearProgress();
    expect(cleared.parcelRecords, isEmpty);
    expect(cleared.settings.showTimer, isTrue);
    expect(() => decodeSave('{'), throwsFormatException);
    expect(() => decodeSave('{"v":99}'), throwsFormatException);
    expect(decodeSave(null).profile.name, 'Traveler');
  });

  test('daily completion is awarded once', () {
    final first = SaveGame.fresh().completeDaily('2026-10-21');
    final second = first.$1.completeDaily('2026-10-21');
    expect(first.$2, isTrue);
    expect(second.$2, isFalse);
    expect(second.$1.dailyCompleted, {'2026-10-21'});
    final withDailySolve = second.$1.finishLevel(
      thread: false,
      id: 'daily@2026-10-21',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 1000,
    );
    expect(
      withDailySolve
          .stats(today: DateTime(2026, 10, 21), parcelDifficulty: {})
          .parcelsSolved,
      0,
    );
    expect(
      withDailySolve
          .stats(today: DateTime(2026, 10, 21), parcelDifficulty: {})
          .dailyCompletions,
      1,
    );
    expect(
      second.$1
          .stats(today: DateTime(2026, 10, 21), parcelDifficulty: {})
          .currentStreak,
      1,
    );
  });

  test('a draft stores rectangles without changing solved totals', () {
    final save = SaveGame.fresh().putDraft(
      'parcel-004',
      const PuzzleDraft(
        elapsedMs: 10,
        hintsUsed: 1,
        moves: [
          [0, 0, 1, 1],
        ],
      ),
    );
    final restored = decodeSave(save.encode());
    expect(restored.drafts['parcel-004']!.moves.single, [0, 0, 1, 1]);
    expect(
      restored
          .stats(today: DateTime(2026, 1, 1), parcelDifficulty: {})
          .parcelsSolved,
      0,
    );
  });
}
