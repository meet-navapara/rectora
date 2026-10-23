import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/account/progress_merge.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/progression/relics.dart';
import 'package:rectora/domain/difficulty/rank.dart';
import 'package:rectora/domain/parcels/geometry.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';

void main() {
  test('a forced cover ranks below a long search', () {
    final geometry = ParcelGeometry(
      const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
    );
    final solved = solveParcels(geometry, limit: 2);
    expect(solved.solutions, 1);
    final easy = rankParcel(
      opening: openingProfile(geometry),
      nodes: solved.nodes,
      backtracked: parcelSearchBacktracked(geometry, solved.nodes),
    );
    final grand = rankParcel(
      opening: const OpeningProfile(
        forcedClues: 0,
        widestChoice: 12,
        choiceTotal: 40,
        clues: 8,
        cells: 64,
      ),
      nodes: 25000,
      backtracked: true,
    );
    expect(easy.index, lessThan(Difficulty.hard.index));
    expect(grand, Difficulty.grandmaster);
  });

  test('mastery points are not awarded twice for the same solve', () {
    var save = SaveGame.fresh().finishLevel(
      id: 'parcel-001',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 1000,
    );
    save = save.copyWith(
      xp: save.xp + masteryXp(Difficulty.easy, perfect: true),
    );
    final once = save.xp;
    save = save.finishLevel(
      id: 'parcel-001',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 800,
    );
    expect(save.parcelRecords['parcel-001']!.bestMs, 800);
    expect(save.xp, once);
  });

  test('the same week cannot claim its bonus twice', () {
    final ids = weeklyLevelIds('2026-10-19', ['a', 'b', 'c', 'd']);
    expect(weeklyLevelIds('2026-10-19', ['a', 'b', 'c', 'd']), ids);
    expect(ids, hasLength(3));
    var save = SaveGame.fresh();
    for (final id in ids) {
      save = save.markWeekly('2026-10-19', id);
    }
    expect(save.weeklyReady('2026-10-19', ids), isTrue);
    save = save.claimWeekly('2026-10-19');
    final claimed = save.xp;
    save = save.claimWeekly('2026-10-19');
    expect(save.xp, claimed);
    expect(claimed, weeklyClearBonus);
  });

  test('merging keeps both solves and does not double points', () {
    final device = SaveGame.fresh().finishLevel(
      id: 'parcel-001',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 5000,
    );
    final account = SaveGame.fresh()
        .finishLevel(
          id: 'parcel-002',
          skipped: false,
          hintsUsed: 1,
          elapsedMs: 9000,
        )
        .copyWith(
          accountKind: 'playGames',
          accountPlayerId: 'player-1',
          drafts: {
            'parcel-003': const PuzzleDraft(
              elapsedMs: 10,
              hintsUsed: 0,
              moves: [
                [0, 0, 1, 1],
              ],
            ),
          },
        );
    final withDraft = device.copyWith(
      drafts: {
        'parcel-003': const PuzzleDraft(
          elapsedMs: 10,
          hintsUsed: 0,
          moves: [
            [0, 0, 1, 1],
            [0, 1, 0, 1],
          ],
        ),
      },
    );
    final plan = mergeProgress(
      device: withDraft,
      account: account,
      difficulty: {
        'parcel-001': Difficulty.easy,
        'parcel-002': Difficulty.hard,
      },
    );
    expect(plan.save.parcelRecords['parcel-001']!.solved, isTrue);
    expect(plan.save.parcelRecords['parcel-002']!.solved, isTrue);
    expect(plan.draftConflicts, ['parcel-003']);
    expect(plan.save.drafts['parcel-003']!.moves, hasLength(2));
    expect(plan.save.accountPlayerId, 'player-1');
    expect(
      plan.save.xp,
      masteryXp(Difficulty.easy, perfect: true) +
          masteryXp(Difficulty.hard, perfect: false),
    );
    final signedOut = plan.save.signOut();
    expect(signedOut.isGuest, isTrue);
    expect(signedOut.parcelRecords['parcel-002'], isNull);
    final restored = signedOut.activateIdentity(
      kind: 'playGames',
      playerId: 'player-1',
    );
    expect(restored.parcelRecords['parcel-002']!.solved, isTrue);
    expect(restored.parcelRecords['parcel-001']!.solved, isTrue);
  });

  test('a weekly attempt does not add mastery when progress is merged', () {
    final device = SaveGame.fresh().finishLevel(
      id: 'weekly@parcel-009',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 1000,
    );
    final plan = mergeProgress(
      device: device,
      account: SaveGame.fresh(),
      difficulty: const {},
    );
    expect(plan.save.parcelRecords['weekly@parcel-009']!.solved, isTrue);
    expect(plan.save.xp, 0);
  });

  test('a chapter bonus and its fragment are awarded once', () {
    var save = SaveGame.fresh().claimChapter('parcel:dawn');
    expect(save.xp, chapterClearBonus);
    save = save.claimChapter('parcel:dawn');
    expect(save.xp, chapterClearBonus);
    final relics = relicsFor(
      stats: save.stats(
        today: DateTime(2026, 10, 21),
        parcelDifficulty: const {},
      ),
      save: save,
      chapters: const [
        PackSummary(id: 'dawn', name: 'Dawn', blurb: 'Open', levelIds: []),
      ],
      mode: 'parcel',
    );
    expect(
      relics.firstWhere((relic) => relic.id == 'parcel:dawn').earned,
      isTrue,
    );
  });

  test('an older save without mastery fields still loads', () {
    const raw =
        '{"v":1,"settings":{"theme":"dark"},"profile":{"name":"Ada","avatar":1},"parcels":{},"threads":{},"drafts":{},"parcelsStarted":[],"threadsStarted":[],"daily":[],"tutorials":[],"lifetimeHints":0}';
    final save = decodeSave(raw);
    expect(save.xp, 0);
    expect(save.isGuest, isTrue);
    expect(save.profile.name, 'Ada');
    expect(save.settings.boardStyle, 'midnight');
  });
}
