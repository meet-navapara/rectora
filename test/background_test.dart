import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/parcels/session.dart';
import 'package:rectora/domain/work/background.dart';
import 'package:rectora/ui/widgets/play_clock.dart';

void main() {
  test('a background placement matches the live session', () async {
    final puzzle = ParcelPuzzle(rows: 2, cols: 2, clues: const [Clue(0, 0, 4)]);
    const rect = GridRect(0, 0, 1, 1);
    final away = await parcelPlacementAway(
      puzzle: puzzle,
      strictness: Strictness.basic,
      placed: const [],
      rect: rect,
    );
    final live = ParcelSession(
      puzzle: puzzle,
      strictness: Strictness.basic,
    ).commit(rect);
    expect(away, live);
    expect(away, PlacementIssue.ok);
  });

  test('a background hint matches the live session', () async {
    final puzzle = ParcelPuzzle(rows: 2, cols: 2, clues: const [Clue(0, 0, 4)]);
    final away = await parcelHintAway(
      puzzle: puzzle,
      strictness: Strictness.basic,
      placed: const [],
      hintsUsed: 0,
    );
    final live = ParcelSession(
      puzzle: puzzle,
      strictness: Strictness.basic,
    ).proposeHint();
    expect(away.kind, live.kind);
    expect(away.rect, live.rect);
  });

  test('a fast check does not flash the waiting line', () async {
    var shown = false;
    final value = await showWhenSlow<int>(
      future: Future<int>.value(4),
      mounted: () => true,
      onSlow: () => shown = true,
      onDone: () => shown = false,
    );
    expect(value, 4);
    expect(shown, isFalse);
  });
}
