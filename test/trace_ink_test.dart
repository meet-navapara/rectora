import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/common/bits.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/trace/engine.dart';

void main() {
  test('trace rejects diagonals, revisits, and wrong order', () {
    const puzzle = TracePuzzle(
      rows: 3,
      cols: 3,
      checkpoints: [0, 1, 2, 5, 4, 3, 6, 7, 8],
    );
    final geometry = TraceGeometry(puzzle);
    expect(geometry.assess([0, 4]).issue, TraceIssue.broken);
    expect(geometry.assess([0, 1, 0]).issue, TraceIssue.revisit);
    expect(geometry.assess([1]).issue, TraceIssue.order);
    expect(geometry.complete([0, 1, 2, 5, 4, 3, 6, 7, 8]), isTrue);
    expect(solveTrace(geometry, limit: 2).solutions, 1);
  });

  test('trace undo and redo restore the path', () {
    final session = TraceSession(
      puzzle: const TracePuzzle(rows: 2, cols: 2, checkpoints: [0, 1, 3, 2]),
    );
    expect(session.dragTo(0), TraceIssue.ok);
    expect(session.dragTo(1), TraceIssue.ok);
    expect(session.undo(), isTrue);
    expect(session.path, [0]);
    expect(session.redo(), isTrue);
    expect(session.path, [0, 1]);
  });

  test('inks accepts a bent region and one completion claim', () {
    final puzzle = InkPuzzle(
      rows: 2,
      cols: 2,
      clues: const [Clue(0, 0, 3), Clue(1, 1, 1)],
    );
    final geometry = InkGeometry(puzzle);
    expect(geometry.assess([0, 1, 2], Bits.zero).accepted, isTrue);
    expect(inkRegionIsRectangle([0, 1, 2], 2), isFalse);
    expect(geometry.assess([0, 1], Bits.zero).issue, InkIssue.clue);
    final session = InkSession(puzzle: puzzle);
    expect(session.commit([0, 1, 2]), InkIssue.ok);
    expect(session.commit([3]), InkIssue.ok);
    expect(session.isComplete, isTrue);
    expect(session.undo(), isTrue);
    expect(session.isComplete, isFalse);
    expect(session.redo(), isTrue);
    expect(session.claimCompletion(), isTrue);
    expect(session.claimCompletion(), isFalse);
  });
}
