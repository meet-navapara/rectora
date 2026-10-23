import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/parcels/bits.dart';
import 'package:rectora/domain/parcels/geometry.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/parcels/session.dart';

void main() {
  test('rectangle area, overlap, and drag directions', () {
    final across = GridRect.fromCorners(1, 2, 0, 0);
    expect(across, const GridRect(0, 0, 1, 2));
    expect(across.width, 3);
    expect(across.height, 2);
    expect(across.area, 6);
    expect(across.overlaps(const GridRect(1, 2, 3, 3)), isTrue);
    expect(across.overlaps(const GridRect(2, 0, 2, 2)), isFalse);
    expect(const GridRect(0, 0, 1, 1).inside(2, 2), isTrue);
    expect(const GridRect(0, 0, 2, 1).inside(2, 2), isFalse);
  });

  test('bit masks cover the high and low chunks', () {
    final low = Bits.zero.set(0).set(61);
    final high = Bits.zero.set(62).set(123);
    expect(low.intersects(high), isFalse);
    expect(low.union(high).count, 4);
    expect(low.union(Bits.zero.set(61)).count, 2);
  });

  test('a single clue accepts only its matching rectangle', () {
    final puzzle = ParcelPuzzle(rows: 2, cols: 2, clues: const [Clue(0, 0, 4)]);
    final geometry = ParcelGeometry(puzzle);
    expect(geometry.wellFormed, isTrue);
    expect(
      geometry
          .assess(
            const GridRect(0, 0, 1, 1),
            Bits.zero,
            strictness: Strictness.basic,
          )
          .accepted,
      isTrue,
    );
    expect(
      geometry
          .assess(
            const GridRect(0, 0, 0, 1),
            Bits.zero,
            strictness: Strictness.basic,
          )
          .issue,
      PlacementIssue.valueMismatch,
    );
    expect(
      geometry
          .assess(
            const GridRect(0, 0, 2, 0),
            Bits.zero,
            strictness: Strictness.basic,
          )
          .issue,
      PlacementIssue.outOfBounds,
    );
  });

  test('regions need exactly one clue and cannot overlap', () {
    final puzzle = ParcelPuzzle(
      rows: 2,
      cols: 2,
      clues: const [Clue(0, 0, 2), Clue(1, 0, 2)],
    );
    final geometry = ParcelGeometry(puzzle);
    final top = geometry.assess(
      const GridRect(0, 0, 0, 1),
      Bits.zero,
      strictness: Strictness.basic,
    );
    expect(top.accepted, isTrue);
    expect(
      geometry
          .assess(
            const GridRect(0, 0, 1, 0),
            Bits.zero,
            strictness: Strictness.basic,
          )
          .issue,
      PlacementIssue.clueCount,
    );
    expect(
      geometry
          .assess(
            const GridRect(1, 0, 1, 1),
            top.mask!,
            strictness: Strictness.basic,
          )
          .accepted,
      isTrue,
    );
    expect(
      geometry
          .assess(
            const GridRect(0, 0, 0, 1),
            top.mask!,
            strictness: Strictness.basic,
          )
          .issue,
      PlacementIssue.overlap,
    );
  });

  test('malformed puzzles are rejected', () {
    expect(
      ParcelGeometry(
        const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 3)]),
      ).wellFormed,
      isFalse,
    );
    expect(
      ParcelGeometry(
        const ParcelPuzzle(
          rows: 2,
          cols: 2,
          clues: [Clue(0, 0, 2), Clue(0, 0, 2)],
        ),
      ).problem,
      contains('share a cell'),
    );
  });

  test('solver distinguishes a unique board from an ambiguous one', () {
    final unique = solveParcels(
      ParcelGeometry(
        const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(1, 1, 4)]),
      ),
    );
    expect(unique.solutions, 1);
    expect(unique.budgetExhausted, isFalse);

    final ambiguous = solveParcels(
      ParcelGeometry(
        const ParcelPuzzle(
          rows: 2,
          cols: 2,
          clues: [Clue(0, 0, 2), Clue(1, 1, 2)],
        ),
      ),
    );
    expect(ambiguous.solutions, 2);
  });

  test('completion, undo, restart, and a single reward claim', () {
    final session = ParcelSession(
      puzzle: const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 1, 4)]),
      strictness: Strictness.basic,
    );
    expect(session.commit(const GridRect(0, 0, 1, 1)), PlacementIssue.ok);
    expect(session.isComplete, isTrue);
    expect(session.claimCompletion(), isTrue);
    expect(session.claimCompletion(), isFalse);

    expect(session.undo(), isTrue);
    expect(session.isComplete, isFalse);
    expect(session.claimCompletion(), isFalse);
    expect(session.undo(), isFalse);

    session.commit(const GridRect(1, 1, 0, 0));
    session.restart();
    expect(session.placed, isEmpty);
    expect(session.undo(), isTrue);
    expect(session.placed, [const GridRect(0, 0, 1, 1)]);
  });

  test('erase and undo do not duplicate or drop a region', () {
    final session = ParcelSession(
      puzzle: const ParcelPuzzle(
        rows: 2,
        cols: 2,
        clues: [Clue(0, 0, 2), Clue(1, 0, 2)],
      ),
      strictness: Strictness.basic,
    );
    session.commit(const GridRect(0, 0, 0, 1));
    session.commit(const GridRect(1, 0, 1, 1));
    expect(session.eraseAt(0, 1), isTrue);
    expect(session.placed, [const GridRect(1, 0, 1, 1)]);
    expect(session.undo(), isTrue);
    expect(session.placed.length, 2);
    expect(session.isComplete, isTrue);
    expect(session.undo(), isTrue);
    expect(session.placed, [const GridRect(0, 0, 0, 1)]);
  });

  test('a damaged draft is discarded instead of half-applied', () {
    final session = ParcelSession(
      puzzle: const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
      strictness: Strictness.basic,
      draft: const [GridRect(0, 0, 0, 0)],
    );
    expect(session.discardedDraft, isTrue);
    expect(session.placed, isEmpty);
  });

  test('higher strictness rejects a locally legal dead end', () {
    final puzzle = const ParcelPuzzle(
      rows: 4,
      cols: 5,
      clues: [
        Clue(1, 0, 4),
        Clue(2, 2, 9),
        Clue(3, 0, 2),
        Clue(3, 3, 3),
        Clue(2, 0, 2),
      ],
    );
    final geometry = ParcelGeometry(puzzle);
    expect(geometry.wellFormed, isTrue);
    expect(solveParcels(geometry).solutions, greaterThan(0));
    const trap = GridRect(1, 0, 1, 3);
    expect(
      geometry.assess(trap, Bits.zero, strictness: Strictness.basic).issue,
      PlacementIssue.ok,
    );
    expect(
      geometry.assess(trap, Bits.zero, strictness: Strictness.forward).issue,
      PlacementIssue.deadEnd,
    );
    expect(
      geometry
          .assess(
            trap,
            Bits.zero,
            strictness: Strictness.solvable,
            solveDeadEnds: true,
          )
          .issue,
      PlacementIssue.deadEnd,
    );

    final easy = ParcelSession(puzzle: puzzle, strictness: Strictness.basic);
    expect(easy.commit(trap), PlacementIssue.ok);
    expect(easy.proposeHint().kind, ParcelHintKind.deadEnd);
    expect(easy.applyHint(easy.proposeHint()), isFalse);
    expect(easy.hintsUsed, 0);

    final medium = ParcelSession(
      puzzle: puzzle,
      strictness: Strictness.forward,
    );
    expect(medium.commit(trap), PlacementIssue.deadEnd);
    expect(medium.placed, isEmpty);
  });

  test('hints follow a forced rectangle and do not fire on a dead end', () {
    final forced = ParcelSession(
      puzzle: const ParcelPuzzle(
        rows: 2,
        cols: 2,
        clues: [Clue(0, 0, 2), Clue(1, 0, 2)],
      ),
      strictness: Strictness.basic,
    );
    final hint = forced.proposeHint();
    expect(hint.kind, ParcelHintKind.forced);
    expect(forced.applyHint(hint), isTrue);
    expect(forced.hintsUsed, 1);
    expect(forced.undo(), isTrue);
    expect(forced.hintsUsed, 1);

    final open = ParcelSession(
      puzzle: const ParcelPuzzle(
        rows: 2,
        cols: 2,
        clues: [Clue(0, 0, 2), Clue(1, 1, 2)],
      ),
      strictness: Strictness.basic,
    );
    open.commit(const GridRect(0, 0, 1, 0));
    final followUp = open.proposeHint();
    expect(followUp.kind, ParcelHintKind.forced);
    expect(open.applyHint(followUp), isTrue);
    expect(open.isComplete, isTrue);
    expect(open.hintsUsed, 1);
  });

  test('a hint rectangle belongs to the proved solution', () {
    final session = ParcelSession(
      puzzle: const ParcelPuzzle(
        rows: 2,
        cols: 2,
        clues: [Clue(0, 0, 2), Clue(1, 0, 2)],
      ),
      strictness: Strictness.basic,
    );
    expect(session.geometry.wellFormed, isTrue);
    final solved = solveParcels(session.geometry);
    expect(solved.solutions, 1);
    final hint = session.proposeHint();
    expect(hint.placesARectangle, isTrue);
    expect(solved.solution, contains(hint.rect));
    expect(session.applyHint(hint), isTrue);
    expect(session.placed, contains(hint.rect));
  });
}
