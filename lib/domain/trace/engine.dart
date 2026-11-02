import '../common/bits.dart';

/// Trace: one orthogonal path visits every open cell and the numbered
/// checkpoints in order. It is not a letter-pair puzzle and it does not
/// place rectangles.
class TracePuzzle {
  const TracePuzzle({
    required this.rows,
    required this.cols,
    required this.checkpoints,
    this.blocked = const [],
  });

  final int rows;
  final int cols;

  /// Cell indexes of numbers 1, 2, 3... in that order.
  final List<int> checkpoints;
  final List<int> blocked;

  int get cellCount => rows * cols;

  int index(int row, int col) => row * cols + col;

  (int, int) cellOf(int index) => (index ~/ cols, index % cols);
}

enum TraceIssue { ok, malformed, broken, revisit, blocked, order, incomplete }

class TraceAssessment {
  const TraceAssessment(this.issue);
  final TraceIssue issue;
  bool get accepted => issue == TraceIssue.ok;
}

class TraceSolveResult {
  const TraceSolveResult({
    required this.solutions,
    required this.budgetExhausted,
    this.solution,
    this.nodes = 0,
  });

  final int solutions;
  final int nodes;
  final bool budgetExhausted;
  final List<int>? solution;
}

class TraceGeometry {
  TraceGeometry(this.puzzle) {
    final cells = puzzle.cellCount;
    if (puzzle.rows < 2 ||
        puzzle.cols < 2 ||
        cells > Bits.maxIndex + 1 ||
        puzzle.checkpoints.length < 2) {
      problem = 'This trace board is too small or too large.';
      return;
    }
    final seen = <int>{};
    var mask = Bits.zero;
    for (final cell in puzzle.blocked) {
      if (cell < 0 || cell >= cells || !seen.add(cell)) {
        problem = 'A blocked cell is invalid.';
        return;
      }
      mask = mask.set(cell);
    }
    blocked = mask;
    final marks = <int>{};
    for (var i = 0; i < puzzle.checkpoints.length; i++) {
      final cell = puzzle.checkpoints[i];
      if (cell < 0 || cell >= cells || blocked.test(cell) || !marks.add(cell)) {
        problem = 'Checkpoints must be distinct open cells.';
        return;
      }
    }
    openCount = cells - puzzle.blocked.length;
    rank = List<int>.filled(cells, -1);
    for (var i = 0; i < puzzle.checkpoints.length; i++) {
      rank[puzzle.checkpoints[i]] = i;
    }
  }

  final TracePuzzle puzzle;
  String? problem;
  late final Bits blocked;
  late final int openCount;
  late final List<int> rank;

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

  TraceAssessment assess(List<int> path, {bool complete = false}) {
    if (!wellFormed) return const TraceAssessment(TraceIssue.malformed);
    if (path.isEmpty) return const TraceAssessment(TraceIssue.incomplete);
    if (path.first != puzzle.checkpoints.first) {
      return const TraceAssessment(TraceIssue.order);
    }
    var used = Bits.zero;
    var nextMark = 0;
    for (var i = 0; i < path.length; i++) {
      final cell = path[i];
      if (cell < 0 || cell >= puzzle.cellCount) {
        return const TraceAssessment(TraceIssue.broken);
      }
      if (blocked.test(cell)) {
        return const TraceAssessment(TraceIssue.blocked);
      }
      if (used.test(cell)) {
        return const TraceAssessment(TraceIssue.revisit);
      }
      if (i > 0 &&
          (path[i] - path[i - 1]).abs() != 1 &&
          (path[i] - path[i - 1]).abs() != puzzle.cols) {
        return const TraceAssessment(TraceIssue.broken);
      }
      if (i > 0) {
        final previous = path[i - 1];
        final sameRow = previous ~/ puzzle.cols == cell ~/ puzzle.cols;
        final sameCol = previous % puzzle.cols == cell % puzzle.cols;
        if (!sameRow && !sameCol) {
          return const TraceAssessment(TraceIssue.broken);
        }
      }
      final mark = rank[cell];
      if (mark >= 0) {
        if (mark != nextMark) return const TraceAssessment(TraceIssue.order);
        nextMark++;
      }
      used = used.set(cell);
    }
    if (used.count != path.length) {
      return const TraceAssessment(TraceIssue.revisit);
    }
    final finished =
        path.length == openCount && nextMark == puzzle.checkpoints.length;
    if (complete && !finished) {
      return const TraceAssessment(TraceIssue.incomplete);
    }
    if (finished && path.last != puzzle.checkpoints.last) {
      return const TraceAssessment(TraceIssue.order);
    }
    return const TraceAssessment(TraceIssue.ok);
  }

  bool complete(List<int> path) =>
      assess(path, complete: true).accepted && path.length == openCount;
}

TraceSolveResult solveTrace(
  TraceGeometry geometry, {
  List<int> prefix = const [],
  int limit = 2,
  int nodeBudget = 200000,
}) {
  if (!geometry.wellFormed) {
    return const TraceSolveResult(solutions: 0, budgetExhausted: false);
  }
  final start = prefix.isEmpty
      ? <int>[geometry.puzzle.checkpoints.first]
      : List<int>.from(prefix);
  if (geometry.assess(start).issue != TraceIssue.ok &&
      geometry.assess(start).issue != TraceIssue.incomplete) {
    return const TraceSolveResult(solutions: 0, budgetExhausted: false);
  }
  var used = Bits.zero;
  var nextMark = 0;
  for (final cell in start) {
    used = used.set(cell);
    if (geometry.rank[cell] >= 0) nextMark++;
  }
  var nodes = 0;
  var solutions = 0;
  List<int>? found;
  var exhausted = false;

  void walk(List<int> path, Bits mask, int mark) {
    if (solutions >= limit || exhausted) return;
    if (++nodes > nodeBudget) {
      exhausted = true;
      return;
    }
    if (path.length == geometry.openCount) {
      if (mark == geometry.puzzle.checkpoints.length) {
        solutions++;
        found ??= List<int>.from(path);
      }
      return;
    }
    final last = path.last;
    final options = geometry.neighbors(last);
    for (final next in options) {
      if (mask.test(next) || geometry.blocked.test(next)) continue;
      final stamp = geometry.rank[next];
      if (stamp >= 0 && stamp != mark) continue;
      path.add(next);
      walk(path, mask.set(next), stamp >= 0 ? mark + 1 : mark);
      path.removeLast();
      if (solutions >= limit || exhausted) return;
    }
  }

  walk(start, used, nextMark);
  return TraceSolveResult(
    solutions: solutions,
    budgetExhausted: exhausted,
    solution: found,
    nodes: nodes,
  );
}

enum TraceHintKind { forced, ambiguous, deadEnd }

class TraceHint {
  const TraceHint(this.kind, [this.cell]);
  final TraceHintKind kind;
  final int? cell;
}

class TraceSession {
  TraceSession({required this.puzzle, List<int>? draft, this.hintsUsed = 0})
    : geometry = TraceGeometry(puzzle) {
    if (!geometry.wellFormed || draft == null || draft.isEmpty) return;
    if (!geometry.assess(draft).accepted) {
      discardedDraft = true;
      return;
    }
    _path.addAll(draft);
  }

  final TracePuzzle puzzle;
  final TraceGeometry geometry;
  int hintsUsed;
  bool discardedDraft = false;

  final List<int> _path = [];
  final List<List<int>> _undo = [];
  final List<List<int>> _redo = [];
  bool _claimed = false;

  List<int> get path => List.unmodifiable(_path);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isComplete => geometry.wellFormed && geometry.complete(_path);

  TraceIssue extend(int cell) {
    if (!geometry.wellFormed) return TraceIssue.malformed;
    final next = [..._path, cell];
    if (_path.isEmpty) {
      next
        ..clear()
        ..add(cell);
    }
    final issue = geometry.assess(next).issue;
    if (issue != TraceIssue.ok) return issue;
    _remember();
    _path
      ..clear()
      ..addAll(next);
    return TraceIssue.ok;
  }

  /// Drag helper. A diagonal move is rejected. Revisiting the previous cell
  /// shortens the path. Any other illegal cell is refused.
  TraceIssue dragTo(int cell) {
    if (_path.isEmpty) return extend(cell);
    if (cell == _path.last) return TraceIssue.ok;
    if (_path.length >= 2 && cell == _path[_path.length - 2]) {
      _remember();
      _path.removeLast();
      return TraceIssue.ok;
    }
    if (!geometry.neighbors(_path.last).contains(cell)) {
      return TraceIssue.broken;
    }
    return extend(cell);
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(List<int>.from(_path));
    final previous = _undo.removeLast();
    _path
      ..clear()
      ..addAll(previous);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(List<int>.from(_path));
    final next = _redo.removeLast();
    _path
      ..clear()
      ..addAll(next);
    return true;
  }

  void restart() {
    if (_path.isEmpty) return;
    _remember();
    _path.clear();
  }

  void _remember() {
    _undo.add(List<int>.from(_path));
    _redo.clear();
  }

  bool claimCompletion() {
    if (_claimed || !isComplete) return false;
    _claimed = true;
    return true;
  }

  TraceHint proposeHint() {
    if (!geometry.wellFormed || isComplete) {
      return const TraceHint(TraceHintKind.deadEnd);
    }
    final prefix = _path.isEmpty ? <int>[puzzle.checkpoints.first] : _path;
    final last = prefix.last;
    final options = geometry.neighbors(last);
    final usable = <int>[];
    for (final cell in options) {
      final trial = [...prefix, cell];
      if (prefix.length == 1 && prefix.single == cell) continue;
      if (!geometry.assess(trial).accepted) continue;
      final solved = solveTrace(geometry, prefix: trial, limit: 1);
      if (!solved.budgetExhausted && solved.solutions > 0) usable.add(cell);
    }
    if (usable.length == 1) {
      return TraceHint(TraceHintKind.forced, usable.single);
    }
    if (usable.isEmpty) return const TraceHint(TraceHintKind.deadEnd);
    return const TraceHint(TraceHintKind.ambiguous);
  }

  bool applyHint(TraceHint hint) {
    if (hint.kind != TraceHintKind.forced || hint.cell == null) return false;
    if (_path.isEmpty) {
      _remember();
      _path.add(puzzle.checkpoints.first);
    }
    if (extend(hint.cell!) != TraceIssue.ok) return false;
    hintsUsed++;
    return true;
  }
}
