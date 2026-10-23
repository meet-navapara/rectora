import 'bits.dart';
import 'models.dart';

/// Candidate rectangles and placement checks for one puzzle.
///
/// The geometry object is the only place that decides whether a rectangle is
/// legal. Painters and gesture code ask it; they do not reimplement the rules.
class ParcelGeometry {
  ParcelGeometry(this.puzzle)
    : clueAt = List<int>.filled(_allocationCount(puzzle), -1),
      choices = List<List<RegionChoice>>.generate(
        puzzle.clues.length,
        (_) => const [],
      ) {
    final problem = _build();
    this.problem = problem;
    wellFormed = problem == null;
  }

  static int _allocationCount(ParcelPuzzle puzzle) {
    if (puzzle.rows <= 0 ||
        puzzle.cols <= 0 ||
        puzzle.cellCount > Bits.maxIndex + 1) {
      return 0;
    }
    return puzzle.cellCount;
  }

  final ParcelPuzzle puzzle;
  final List<int> clueAt;
  final List<List<RegionChoice>> choices;
  late final bool wellFormed;
  late final String? problem;

  String? _build() {
    if (puzzle.rows <= 0 || puzzle.cols <= 0) {
      return 'The grid needs a positive size.';
    }
    if (puzzle.cellCount > Bits.maxIndex + 1) {
      return 'Grids larger than ${Bits.maxIndex + 1} cells are not supported.';
    }
    if (puzzle.clues.isEmpty) {
      return 'A puzzle needs at least one clue.';
    }
    for (var i = 0; i < puzzle.clues.length; i++) {
      final clue = puzzle.clues[i];
      if (clue.row < 0 ||
          clue.col < 0 ||
          clue.row >= puzzle.rows ||
          clue.col >= puzzle.cols) {
        return 'Clue ${i + 1} sits outside the grid.';
      }
      if (clue.value <= 0) {
        return 'Clue ${i + 1} must be a positive area.';
      }
      final index = cellIndex(clue.row, clue.col);
      if (clueAt[index] != -1) {
        return 'Two clues share a cell.';
      }
      clueAt[index] = i;
    }
    if (puzzle.clueSum != puzzle.cellCount) {
      return 'Clue values add up to ${puzzle.clueSum}, not ${puzzle.cellCount}.';
    }
    for (var i = 0; i < puzzle.clues.length; i++) {
      final built = _choicesFor(i);
      if (built.isEmpty) {
        return 'Clue ${i + 1} has no rectangle of the right area.';
      }
      choices[i] = built;
    }
    return null;
  }

  int cellIndex(int row, int col) => row * puzzle.cols + col;

  Bits maskFor(GridRect rect) {
    var bits = Bits.zero;
    for (var row = rect.r1; row <= rect.r2; row++) {
      for (var col = rect.c1; col <= rect.c2; col++) {
        bits = bits.set(cellIndex(row, col));
      }
    }
    return bits;
  }

  List<RegionChoice> _choicesFor(int clueIndex) {
    final clue = puzzle.clues[clueIndex];
    final found = <RegionChoice>[];
    final value = clue.value;
    for (var height = 1; height <= value; height++) {
      if (value % height != 0) continue;
      final width = value ~/ height;
      final topStart = clue.row - height + 1;
      final leftStart = clue.col - width + 1;
      for (var top = topStart; top <= clue.row; top++) {
        if (top < 0 || top + height > puzzle.rows) continue;
        for (var left = leftStart; left <= clue.col; left++) {
          if (left < 0 || left + width > puzzle.cols) continue;
          final rect = GridRect(top, left, top + height - 1, left + width - 1);
          if (_containsForeignClue(rect, clue)) continue;
          found.add(
            RegionChoice(clueIndex: clueIndex, rect: rect, mask: maskFor(rect)),
          );
        }
      }
    }
    return found;
  }

  bool _containsForeignClue(GridRect rect, Clue owner) {
    for (var row = rect.r1; row <= rect.r2; row++) {
      for (var col = rect.c1; col <= rect.c2; col++) {
        if (clueAt[cellIndex(row, col)] != -1 &&
            (row != owner.row || col != owner.col)) {
          return true;
        }
      }
    }
    return false;
  }

  PlacementAssessment assess(
    GridRect raw,
    Bits occupied, {
    required Strictness strictness,
    bool solveDeadEnds = false,
  }) {
    if (!wellFormed) {
      return const PlacementAssessment(issue: PlacementIssue.malformed);
    }
    final rect = GridRect.fromCorners(raw.r1, raw.c1, raw.r2, raw.c2);
    if (!rect.inside(puzzle.rows, puzzle.cols)) {
      return PlacementAssessment(
        issue: PlacementIssue.outOfBounds,
        rect: rect,
        area: rect.area,
      );
    }
    if (rect.area <= 0) {
      return PlacementAssessment(issue: PlacementIssue.degenerate, rect: rect);
    }

    var cluesInside = 0;
    var clueIndex = -1;
    for (var row = rect.r1; row <= rect.r2; row++) {
      for (var col = rect.c1; col <= rect.c2; col++) {
        final at = clueAt[cellIndex(row, col)];
        if (at != -1) {
          cluesInside++;
          clueIndex = at;
        }
      }
    }
    if (cluesInside != 1) {
      return PlacementAssessment(
        issue: PlacementIssue.clueCount,
        rect: rect,
        area: rect.area,
        cluesInside: cluesInside,
      );
    }
    final clue = puzzle.clues[clueIndex];
    if (clue.value != rect.area) {
      return PlacementAssessment(
        issue: PlacementIssue.valueMismatch,
        rect: rect,
        clueIndex: clueIndex,
        area: rect.area,
        cluesInside: cluesInside,
      );
    }
    final mask = maskFor(rect);
    if (occupied.intersects(mask)) {
      return PlacementAssessment(
        issue: PlacementIssue.overlap,
        rect: rect,
        clueIndex: clueIndex,
        mask: mask,
        area: rect.area,
        cluesInside: cluesInside,
      );
    }

    final next = occupied.union(mask);
    final needsForward = strictness != Strictness.basic;
    if (needsForward && !_remainingCluesHaveRoom(next, clueIndex)) {
      return PlacementAssessment(
        issue: PlacementIssue.deadEnd,
        rect: rect,
        clueIndex: clueIndex,
        mask: mask,
        area: rect.area,
        cluesInside: cluesInside,
      );
    }
    if (strictness == Strictness.solvable && solveDeadEnds) {
      final solved = solveParcels(
        this,
        occupied: next,
        placedClues: {clueIndex, ..._coveredClues(occupied)},
        limit: 1,
        nodeBudget: 80000,
      );
      if (!solved.budgetExhausted && solved.solutions == 0) {
        return PlacementAssessment(
          issue: PlacementIssue.deadEnd,
          rect: rect,
          clueIndex: clueIndex,
          mask: mask,
          area: rect.area,
          cluesInside: cluesInside,
        );
      }
    }
    return PlacementAssessment(
      issue: PlacementIssue.ok,
      rect: rect,
      clueIndex: clueIndex,
      mask: mask,
      area: rect.area,
      cluesInside: cluesInside,
    );
  }

  Set<int> _coveredClues(Bits occupied) {
    final covered = <int>{};
    for (var i = 0; i < puzzle.clues.length; i++) {
      final clue = puzzle.clues[i];
      final bit = Bits.zero.set(cellIndex(clue.row, clue.col));
      if (occupied.intersects(bit)) covered.add(i);
    }
    return covered;
  }

  bool _remainingCluesHaveRoom(Bits occupied, int justPlaced) {
    for (var i = 0; i < choices.length; i++) {
      if (i == justPlaced) continue;
      final clue = puzzle.clues[i];
      final bit = Bits.zero.set(cellIndex(clue.row, clue.col));
      if (occupied.intersects(bit)) continue;
      var room = false;
      for (final choice in choices[i]) {
        if (!occupied.intersects(choice.mask)) {
          room = true;
          break;
        }
      }
      if (!room) return false;
    }
    return true;
  }

  RegionChoice? choiceMatching(GridRect rect) {
    final assessment = assess(rect, Bits.zero, strictness: Strictness.basic);
    if (!assessment.accepted || assessment.clueIndex == null) return null;
    for (final choice in choices[assessment.clueIndex!]) {
      if (choice.rect == assessment.rect) return choice;
    }
    return null;
  }

  double get forcedRatio {
    if (!wellFormed || choices.isEmpty) return 1;
    var forced = 0;
    for (final list in choices) {
      if (list.length <= 1) forced++;
    }
    return forced / choices.length;
  }
}

class SolveResult {
  const SolveResult({
    required this.solutions,
    required this.budgetExhausted,
    this.solution,
    this.nodes = 0,
  });

  final int solutions;
  final bool budgetExhausted;
  final List<GridRect>? solution;
  final int nodes;

  static const none = SolveResult(solutions: 0, budgetExhausted: false);
}

/// Counts completions up to [limit]. Already covered clues in [placedClues]
/// are skipped; their cells must already be set in [occupied].
SolveResult solveParcels(
  ParcelGeometry geometry, {
  Bits occupied = Bits.zero,
  Set<int> placedClues = const {},
  int limit = 2,
  int nodeBudget = 250000,
}) {
  if (!geometry.wellFormed) return SolveResult.none;
  final clueCount = geometry.puzzle.clues.length;
  final placed = List<bool>.filled(clueCount, false);
  for (final index in placedClues) {
    if (index < 0 || index >= clueCount) return SolveResult.none;
    placed[index] = true;
  }
  final chosen = List<RegionChoice?>.filled(clueCount, null);
  var nodes = 0;
  var solutions = 0;
  var budgetExhausted = false;
  List<GridRect>? first;

  bool search(Bits occ) {
    if (solutions >= limit || budgetExhausted) return true;
    if (++nodes > nodeBudget) {
      budgetExhausted = true;
      return true;
    }

    var bestIndex = -1;
    var bestCount = 1 << 30;
    for (var i = 0; i < clueCount; i++) {
      if (placed[i]) continue;
      var feasible = 0;
      for (final choice in geometry.choices[i]) {
        if (!occ.intersects(choice.mask)) feasible++;
      }
      if (feasible < bestCount) {
        bestCount = feasible;
        bestIndex = i;
        if (feasible == 0) break;
      }
    }
    if (bestIndex == -1) {
      if (occ.count != geometry.puzzle.cellCount) return false;
      solutions++;
      if (first == null) {
        final rects = <GridRect>[
          for (var i = 0; i < clueCount; i++)
            if (chosen[i] != null) chosen[i]!.rect,
        ];
        rects.sort((left, right) {
          if (left.r1 != right.r1) return left.r1 - right.r1;
          if (left.c1 != right.c1) return left.c1 - right.c1;
          return left.r2 - right.r2;
        });
        first = rects;
      }
      return solutions >= limit;
    }
    if (bestCount == 0) return false;

    for (final choice in geometry.choices[bestIndex]) {
      if (occ.intersects(choice.mask)) continue;
      placed[bestIndex] = true;
      chosen[bestIndex] = choice;
      final stop = search(occ.union(choice.mask));
      chosen[bestIndex] = null;
      placed[bestIndex] = false;
      if (stop) return true;
    }
    return false;
  }

  search(occupied);
  return SolveResult(
    solutions: solutions,
    budgetExhausted: budgetExhausted,
    solution: first,
    nodes: nodes,
  );
}

/// Replays [rects] from an empty board. This is the completion check used by
/// the session, so a corrupted undo stack cannot report a false win.
bool exactCover(ParcelGeometry geometry, List<GridRect> rects) {
  if (!geometry.wellFormed) return false;
  var occupied = Bits.zero;
  final used = <int>{};
  for (final rect in rects) {
    final assessment = geometry.assess(
      rect,
      occupied,
      strictness: Strictness.basic,
    );
    if (!assessment.accepted ||
        assessment.mask == null ||
        assessment.clueIndex == null) {
      return false;
    }
    occupied = occupied.union(assessment.mask!);
    used.add(assessment.clueIndex!);
  }
  return used.length == geometry.puzzle.clues.length &&
      occupied.count == geometry.puzzle.cellCount;
}

Bits occupancyOf(ParcelGeometry geometry, List<GridRect> rects) {
  var occupied = Bits.zero;
  for (final rect in rects) {
    occupied = occupied.union(geometry.maskFor(rect));
  }
  return occupied;
}
