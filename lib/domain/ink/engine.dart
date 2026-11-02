import '../common/bits.dart';
import '../parcels/models.dart';

/// Inks: cover the board with orthogonally connected regions. A region holds
/// exactly one number and has that many cells. The shape does not have to be
/// a rectangle, which is what separates Inks from Parcels.
class InkPuzzle {
  const InkPuzzle({
    required this.rows,
    required this.cols,
    required this.clues,
  });

  final int rows;
  final int cols;
  final List<Clue> clues;

  int get cellCount => rows * cols;

  int index(int row, int col) => row * cols + col;
}

class InkRegion {
  const InkRegion(this.cells);

  final List<int> cells;

  Bits get mask {
    var bits = Bits.zero;
    for (final cell in cells) {
      bits = bits.set(cell);
    }
    return bits;
  }
}

enum InkIssue { ok, malformed, disconnected, clue, overlap, incomplete }

class InkAssessment {
  const InkAssessment(this.issue, [this.region]);
  final InkIssue issue;
  final InkRegion? region;
  bool get accepted => issue == InkIssue.ok;
}

class InkSolveResult {
  const InkSolveResult({
    required this.solutions,
    required this.budgetExhausted,
    this.solution,
    this.nodes = 0,
  });

  final int solutions;
  final int nodes;
  final bool budgetExhausted;
  final List<InkRegion>? solution;
}

class InkGeometry {
  InkGeometry(this.puzzle) {
    final cells = puzzle.cellCount;
    if (puzzle.rows < 2 || puzzle.cols < 2 || cells > Bits.maxIndex + 1) {
      problem = 'This inks board cannot be played.';
      return;
    }
    final seen = <int>{};
    var sum = 0;
    for (final clue in puzzle.clues) {
      if (clue.row < 0 ||
          clue.col < 0 ||
          clue.row >= puzzle.rows ||
          clue.col >= puzzle.cols ||
          clue.value < 1) {
        problem = 'A clue is off the board.';
        return;
      }
      final cell = puzzle.index(clue.row, clue.col);
      if (!seen.add(cell)) {
        problem = 'Two clues share a cell.';
        return;
      }
      sum += clue.value;
    }
    if (sum != cells || puzzle.clues.isEmpty) {
      problem = 'The clues do not add up to the board.';
    }
  }

  final InkPuzzle puzzle;
  String? problem;

  bool get wellFormed => problem == null;

  List<int> neighbors(int cell) {
    final row = cell ~/ puzzle.cols;
    final col = cell % puzzle.cols;
    final next = <int>[];
    if (row > 0) next.add(cell - puzzle.cols);
    if (row + 1 < puzzle.rows) next.add(cell + puzzle.cols);
    if (col > 0) next.add(cell - 1);
    if (col + 1 < puzzle.cols) next.add(cell + 1);
    return next;
  }

  int? clueIndexAt(int cell) {
    for (var i = 0; i < puzzle.clues.length; i++) {
      final clue = puzzle.clues[i];
      if (puzzle.index(clue.row, clue.col) == cell) return i;
    }
    return null;
  }

  InkAssessment assess(List<int> cells, Bits occupied) {
    if (!wellFormed) return const InkAssessment(InkIssue.malformed);
    if (cells.isEmpty) return const InkAssessment(InkIssue.incomplete);
    final unique = <int>[];
    var mask = Bits.zero;
    var clue = -1;
    for (final cell in cells) {
      if (cell < 0 || cell >= puzzle.cellCount || mask.test(cell)) {
        return const InkAssessment(InkIssue.malformed);
      }
      if (occupied.test(cell)) return const InkAssessment(InkIssue.overlap);
      final found = clueIndexAt(cell);
      if (found != null) {
        if (clue >= 0) return const InkAssessment(InkIssue.clue);
        clue = found;
      }
      unique.add(cell);
      mask = mask.set(cell);
    }
    if (clue < 0 || unique.length != puzzle.clues[clue].value) {
      return const InkAssessment(InkIssue.clue);
    }
    if (!_connected(unique)) return const InkAssessment(InkIssue.disconnected);
    return InkAssessment(InkIssue.ok, InkRegion(unique));
  }

  bool _connected(List<int> cells) {
    final look = cells.toSet();
    final stack = <int>[cells.first];
    final seen = <int>{cells.first};
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      for (final next in neighbors(cell)) {
        if (look.contains(next) && seen.add(next)) stack.add(next);
      }
    }
    return seen.length == cells.length;
  }

  bool complete(List<InkRegion> regions) {
    if (!wellFormed || regions.length != puzzle.clues.length) return false;
    var mask = Bits.zero;
    final clues = <int>{};
    for (final region in regions) {
      final assessment = assess(region.cells, mask);
      if (!assessment.accepted) return false;
      final clue = region.cells
          .map(clueIndexAt)
          .firstWhere((index) => index != null);
      if (!clues.add(clue!)) return false;
      mask = mask.union(region.mask);
    }
    return mask.count == puzzle.cellCount;
  }
}

/// True when the cells fill a rectangle. Used to keep harder Inks puzzles
/// from collapsing into Parcels.
bool inkRegionIsRectangle(List<int> cells, int cols) {
  if (cells.isEmpty) return false;
  var minR = 1 << 20;
  var maxR = -1;
  var minC = 1 << 20;
  var maxC = -1;
  final look = cells.toSet();
  for (final cell in look) {
    final row = cell ~/ cols;
    final col = cell % cols;
    if (row < minR) minR = row;
    if (row > maxR) maxR = row;
    if (col < minC) minC = col;
    if (col > maxC) maxC = col;
  }
  return look.length == (maxR - minR + 1) * (maxC - minC + 1);
}

InkSolveResult solveInks(
  InkGeometry geometry, {
  List<InkRegion> placed = const [],
  int limit = 2,
  int nodeBudget = 150000,
}) {
  if (!geometry.wellFormed) {
    return const InkSolveResult(solutions: 0, budgetExhausted: false);
  }
  var occupied = Bits.zero;
  final usedClues = <int>{};
  for (final region in placed) {
    final assessment = geometry.assess(region.cells, occupied);
    if (!assessment.accepted) {
      return const InkSolveResult(solutions: 0, budgetExhausted: false);
    }
    occupied = occupied.union(assessment.region!.mask);
    usedClues.add(
      region.cells
          .map(geometry.clueIndexAt)
          .firstWhere((index) => index != null)!,
    );
  }
  final order =
      <int>[
        for (var i = 0; i < geometry.puzzle.clues.length; i++)
          if (!usedClues.contains(i)) i,
      ]..sort(
        (a, b) => geometry.puzzle.clues[a].value.compareTo(
          geometry.puzzle.clues[b].value,
        ),
      );
  var nodes = 0;
  var solutions = 0;
  List<InkRegion>? found;
  var exhausted = false;

  List<List<int>> shapes(int clueIndex, Bits blocked) {
    final clue = geometry.puzzle.clues[clueIndex];
    final origin = geometry.puzzle.index(clue.row, clue.col);
    final want = clue.value;
    final results = <List<int>>[];
    final seen = <String>{};
    void grow(List<int> cells, Bits mask) {
      if (results.length > 240 || exhausted) return;
      if (cells.length == want) {
        final sorted = [...cells]..sort();
        final key = sorted.join(',');
        if (seen.add(key)) results.add(sorted);
        return;
      }
      final frontier = <int>{};
      for (final cell in cells) {
        for (final next in geometry.neighbors(cell)) {
          if (!mask.test(next) && !blocked.test(next)) frontier.add(next);
        }
      }
      final sorted = frontier.toList()..sort();
      for (final next in sorted) {
        cells.add(next);
        grow(cells, mask.set(next));
        cells.removeLast();
        if (results.length > 240) return;
      }
    }

    if (!blocked.test(origin)) grow([origin], Bits.zero.set(origin));
    for (final shape in results) {
      shape.sort();
    }
    return results;
  }

  void walk(int step, Bits mask, List<InkRegion> built) {
    if (solutions >= limit || exhausted) return;
    if (++nodes > nodeBudget) {
      exhausted = true;
      return;
    }
    if (step == order.length) {
      if (mask.count == geometry.puzzle.cellCount) {
        solutions++;
        found ??= List<InkRegion>.from(built);
      }
      return;
    }
    for (final shape in shapes(order[step], mask)) {
      var next = mask;
      for (final cell in shape) {
        next = next.set(cell);
      }
      built.add(InkRegion(shape));
      walk(step + 1, next, built);
      built.removeLast();
      if (solutions >= limit || exhausted) return;
    }
  }

  walk(0, occupied, []);
  return InkSolveResult(
    solutions: solutions,
    budgetExhausted: exhausted,
    solution: found,
    nodes: nodes,
  );
}

enum InkHintKind { forced, ambiguous, deadEnd }

class InkHint {
  const InkHint(this.kind, [this.cells = const []]);
  final InkHintKind kind;
  final List<int> cells;
}

class InkSession {
  InkSession({required this.puzzle, List<List<int>>? draft, this.hintsUsed = 0})
    : geometry = InkGeometry(puzzle) {
    if (!geometry.wellFormed || draft == null) return;
    var occupied = Bits.zero;
    final restored = <InkRegion>[];
    for (final cells in draft) {
      final assessment = geometry.assess(cells, occupied);
      if (!assessment.accepted || assessment.region == null) {
        discardedDraft = true;
        return;
      }
      restored.add(assessment.region!);
      occupied = occupied.union(assessment.region!.mask);
    }
    _regions.addAll(restored);
  }

  final InkPuzzle puzzle;
  final InkGeometry geometry;
  int hintsUsed;
  bool discardedDraft = false;

  final List<InkRegion> _regions = [];
  final List<List<InkRegion>> _undo = [];
  final List<List<InkRegion>> _redo = [];
  bool _claimed = false;

  List<InkRegion> get regions => List.unmodifiable(_regions);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isComplete => geometry.complete(_regions);

  Bits get occupied {
    var mask = Bits.zero;
    for (final region in _regions) {
      mask = mask.union(region.mask);
    }
    return mask;
  }

  InkIssue commit(List<int> cells) {
    final assessment = geometry.assess(cells, occupied);
    if (!assessment.accepted || assessment.region == null) {
      return assessment.issue;
    }
    _remember();
    _regions.add(assessment.region!);
    return InkIssue.ok;
  }

  bool eraseAt(int cell) {
    final index = _regions.indexWhere((region) => region.cells.contains(cell));
    if (index < 0) return false;
    _remember();
    _regions.removeAt(index);
    return true;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(List<InkRegion>.from(_regions));
    final previous = _undo.removeLast();
    _regions
      ..clear()
      ..addAll(previous);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(List<InkRegion>.from(_regions));
    final next = _redo.removeLast();
    _regions
      ..clear()
      ..addAll(next);
    return true;
  }

  void restart() {
    if (_regions.isEmpty) return;
    _remember();
    _regions.clear();
  }

  void _remember() {
    _undo.add(List<InkRegion>.from(_regions));
    _redo.clear();
  }

  bool claimCompletion() {
    if (_claimed || !isComplete) return false;
    _claimed = true;
    return true;
  }

  InkHint proposeHint() {
    if (!geometry.wellFormed || isComplete) {
      return const InkHint(InkHintKind.deadEnd);
    }
    final solved = solveInks(geometry, placed: _regions, limit: 2);
    if (solved.budgetExhausted) return const InkHint(InkHintKind.ambiguous);
    if (solved.solutions == 0) return const InkHint(InkHintKind.deadEnd);
    if (solved.solutions == 1 && solved.solution != null) {
      final region = solved.solution!.reduce(
        (a, b) => a.cells.length <= b.cells.length ? a : b,
      );
      return InkHint(InkHintKind.forced, region.cells);
    }
    return const InkHint(InkHintKind.ambiguous);
  }

  bool applyHint(InkHint hint) {
    if (hint.kind != InkHintKind.forced || hint.cells.isEmpty) return false;
    if (commit(hint.cells) != InkIssue.ok) return false;
    hintsUsed++;
    return true;
  }
}
