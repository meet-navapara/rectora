import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/common/bits.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';

ThreadPuzzle corridor() {
  return const ThreadPuzzle(
    rows: 4,
    cols: 4,
    pairs: [ThreadPair(label: 'A', a: 0, b: 15)],
    blocked: [4, 5, 6, 8, 9, 10, 12, 13, 14],
  );
}

void main() {
  test('diagonal steps are rejected and orthogonal steps are not', () {
    final geometry = ThreadGeometry(corridor());
    expect(geometry.orthogonal(0, 1), isTrue);
    expect(geometry.orthogonal(0, 4), isTrue);
    expect(geometry.orthogonal(0, 5), isFalse);
    expect(geometry.orthogonal(0, 2), isFalse);
  });

  test('a corridor has one solution and a bad path does not', () {
    final geometry = ThreadGeometry(corridor());
    final good = [0, 1, 2, 3, 7, 11, 15];
    expect(geometry.assessPath(good, Bits.zero).accepted, isTrue);
    expect(
      geometry.assessPath([0, 1, 2, 3, 7, 11], Bits.zero).issue,
      ThreadIssue.endsMismatch,
    );
    expect(geometry.assessPath([0, 5], Bits.zero).issue, isNot(ThreadIssue.ok));
    final solved = solveThreads(geometry);
    expect(solved.budgetExhausted, isFalse);
    expect(solved.solutions, 1);
    expect(threadsComplete(geometry, solved.solution!), isTrue);
  });

  test('drawing ignores a diagonal jump and accepts a straight jump', () {
    final geometry = ThreadGeometry(
      const ThreadPuzzle(
        rows: 3,
        cols: 3,
        pairs: [ThreadPair(label: 'A', a: 0, b: 8)],
        blocked: [],
      ),
    );
    expect(geometry.extend(path: [0], target: 4, occupied: Bits.zero), [0]);
    expect(geometry.extend(path: [0], target: 2, occupied: Bits.zero), [
      0,
      1,
      2,
    ]);
    expect(geometry.extend(path: [0, 1, 2], target: 1, occupied: Bits.zero), [
      0,
      1,
    ]);
  });

  test('paths cannot cross, and undo restores the previous path', () {
    final puzzle = const ThreadPuzzle(
      rows: 2,
      cols: 2,
      pairs: [
        ThreadPair(label: 'A', a: 0, b: 1),
        ThreadPair(label: 'B', a: 2, b: 3),
      ],
      blocked: [],
    );
    final session = ThreadSession(puzzle: puzzle);
    expect(session.commit([0, 1]), ThreadIssue.ok);
    expect(session.commit([0, 2, 3]), ThreadIssue.overlap);
    expect(session.commit([2, 3]), ThreadIssue.ok);
    expect(session.isComplete, isTrue);
    expect(session.claimCompletion(), isTrue);
    expect(session.claimCompletion(), isFalse);
    expect(session.undo(), isTrue);
    expect(session.paths, hasLength(1));
    session.restart();
    expect(session.paths, isEmpty);
    expect(session.undo(), isTrue);
    expect(session.paths, hasLength(1));
  });

  test('an open board reports more than one solution', () {
    final solved = solveThreads(
      ThreadGeometry(
        const ThreadPuzzle(
          rows: 3,
          cols: 3,
          pairs: [ThreadPair(label: 'A', a: 0, b: 8)],
          blocked: [],
        ),
      ),
    );
    expect(solved.solutions, greaterThan(1));
  });

  test('a hint places a proved path and does not invent one', () {
    final session = ThreadSession(puzzle: corridor());
    final hint = session.proposeHint();
    expect(hint.placesAPath, isTrue);
    expect(session.applyHint(hint), isTrue);
    expect(session.hintsUsed, 1);
    expect(session.isComplete, isTrue);
    expect(session.undo(), isTrue);
    expect(session.hintsUsed, 1);

    final impossible = ThreadSession(
      puzzle: const ThreadPuzzle(
        rows: 3,
        cols: 3,
        pairs: [
          ThreadPair(label: 'A', a: 0, b: 2),
          ThreadPair(label: 'B', a: 6, b: 8),
        ],
        blocked: [1, 3, 4, 5, 7],
      ),
    );
    expect(impossible.geometry.wellFormed, isTrue);
    final refusal = impossible.proposeHint();
    expect(refusal.kind, ThreadHintKind.deadEnd);
    expect(impossible.applyHint(refusal), isFalse);
    expect(impossible.hintsUsed, 0);
  });
}
