import '../common/bits.dart';
import 'models.dart';

/// Rules, drawing, solving, and undo for the Threads mode.
///
/// A path joins one labeled pair with orthogonal steps, never diagonal steps.
/// Paths cannot share a cell or enter a blocked cell. The board is complete
/// when every pair is joined and every open cell belongs to exactly one path.
class ThreadGeometry {
  ThreadGeometry(this.puzzle) {
    problem = _validate();
    wellFormed = problem == null;
    var mask = Bits.zero;
    final owners = List<int>.filled(
      puzzle.rows <= 0 ||
              puzzle.cols <= 0 ||
              puzzle.cellCount > Bits.maxIndex + 1
          ? 0
          : puzzle.cellCount,
      -1,
    );
    if (wellFormed) {
      for (final index in puzzle.blocked) {
        mask = mask.set(index);
      }
      for (var i = 0; i < puzzle.pairs.length; i++) {
        final pair = puzzle.pairs[i];
        owners[pair.a] = i;
        owners[pair.b] = i;
      }
    }
    blocked = mask;
    terminalOwner = owners;
  }

  final ThreadPuzzle puzzle;
  late final bool wellFormed;
  late final String? problem;
  late final Bits blocked;
  late final List<int> terminalOwner;

  String? _validate() {
    if (puzzle.rows <= 0 || puzzle.cols <= 0) {
      return 'The grid needs a positive size.';
    }
    if (puzzle.cellCount > Bits.maxIndex + 1) {
      return 'This grid is larger than the engine supports.';
    }
    if (puzzle.pairs.isEmpty) return 'A thread puzzle needs a pair.';
    final seen = <int>{};
    final labels = <String>{};
    for (final pair in puzzle.pairs) {
      if (pair.label.isEmpty || !labels.add(pair.label)) {
        return 'Each pair needs its own label.';
      }
      for (final end in [pair.a, pair.b]) {
        if (end < 0 || end >= puzzle.cellCount || !seen.add(end)) {
          return 'Pair endpoints must be distinct cells on the grid.';
        }
      }
    }
    for (final index in puzzle.blocked) {
      if (index < 0 || index >= puzzle.cellCount || !seen.add(index)) {
        return 'Blocked cells must be empty cells on the grid.';
      }
    }
    final open = puzzle.cellCount - puzzle.blocked.length;
    if (open < 2) return 'There are not enough open cells to join.';
    return null;
  }

  bool isBlocked(int index) => wellFormed && blocked.test(index);

  bool orthogonal(int from, int to) {
    final cols = puzzle.cols;
    final rowDelta = (to ~/ cols) - (from ~/ cols);
    final colDelta = (to % cols) - (from % cols);
    final sameRow = to ~/ cols == from ~/ cols;
    if (!sameRow && (to % cols) != (from % cols)) return false;
    return (rowDelta.abs() + colDelta.abs()) == 1;
  }

  List<int> neighbors(int index) {
    final cols = puzzle.cols;
    final row = index ~/ cols;
    final col = index % cols;
    final found = <int>[];
    if (row > 0) found.add(index - cols);
    if (row + 1 < puzzle.rows) found.add(index + cols);
    if (col > 0) found.add(index - 1);
    if (col + 1 < cols) found.add(index + 1);
    return found;
  }

  ThreadAssessment assessPath(
    List<int> cells,
    Bits occupied, {
    int? expectedPair,
  }) {
    if (!wellFormed) {
      return const ThreadAssessment(issue: ThreadIssue.malformed);
    }
    if (cells.length < 2) {
      return const ThreadAssessment(issue: ThreadIssue.tooShort);
    }
    final seen = <int>{};
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      if (cell < 0 || cell >= puzzle.cellCount) {
        return const ThreadAssessment(issue: ThreadIssue.endsMismatch);
      }
      if (!seen.add(cell)) {
        return const ThreadAssessment(issue: ThreadIssue.revisit);
      }
      if (blocked.test(cell)) {
        return const ThreadAssessment(issue: ThreadIssue.blocked);
      }
      if (occupied.test(cell)) {
        return const ThreadAssessment(issue: ThreadIssue.overlap);
      }
      if (i > 0 && !orthogonal(cells[i - 1], cell)) {
        return const ThreadAssessment(issue: ThreadIssue.notOrthogonal);
      }
    }
    final startOwner = terminalOwner[cells.first];
    final endOwner = terminalOwner[cells.last];
    if (startOwner < 0 || startOwner != endOwner) {
      return const ThreadAssessment(issue: ThreadIssue.endsMismatch);
    }
    final pair = puzzle.pairs[startOwner];
    final ends = {pair.a, pair.b};
    if (cells.first == cells.last ||
        !ends.contains(cells.first) ||
        !ends.contains(cells.last)) {
      return const ThreadAssessment(issue: ThreadIssue.endsMismatch);
    }
    if (expectedPair != null && expectedPair != startOwner) {
      return const ThreadAssessment(issue: ThreadIssue.endsMismatch);
    }
    for (final cell in cells) {
      final owner = terminalOwner[cell];
      if (owner != -1 && owner != startOwner) {
        return const ThreadAssessment(issue: ThreadIssue.foreignTerminal);
      }
    }
    return ThreadAssessment(
      issue: ThreadIssue.ok,
      path: ThreadPath(
        pairIndex: startOwner,
        cells: List<int>.unmodifiable(cells),
      ),
    );
  }

  /// Extends a gesture path by orthogonal steps only.
  ///
  /// A diagonal jump is ignored. A straight jump fills the cells between the
  /// head and the target when every cell is open. Stepping back shortens the
  /// path.
  List<int> extend({
    required List<int> path,
    required int target,
    required Bits occupied,
  }) {
    if (!wellFormed || path.isEmpty) return path;
    if (target < 0 || target >= puzzle.cellCount) return path;
    if (path.length >= 2 && path[path.length - 2] == target) {
      return path.sublist(0, path.length - 1);
    }
    final existing = path.indexOf(target);
    if (existing >= 0) return path.sublist(0, existing + 1);

    final steps = _straight(path.last, target);
    if (steps == null) return path;
    final next = List<int>.from(path);
    for (final step in steps) {
      if (occupied.test(step) || blocked.test(step)) return path;
      if (next.contains(step)) return path;
      final owner = terminalOwner[step];
      final startOwner = terminalOwner[next.first];
      if (owner != -1 && owner != startOwner) return path;
      if (owner == startOwner &&
          step != puzzle.pairs[startOwner].a &&
          step != puzzle.pairs[startOwner].b) {
        return path;
      }
      next.add(step);
      if (owner == startOwner && step != next.first) break;
    }
    return next;
  }

  List<int>? _straight(int from, int to) {
    final cols = puzzle.cols;
    final fromRow = from ~/ cols;
    final fromCol = from % cols;
    final toRow = to ~/ cols;
    final toCol = to % cols;
    if (fromRow != toRow && fromCol != toCol) return null;
    final steps = <int>[];
    if (fromRow == toRow) {
      final direction = toCol > fromCol ? 1 : -1;
      for (
        var col = fromCol + direction;
        col != toCol + direction;
        col += direction
      ) {
        steps.add(fromRow * cols + col);
      }
    } else {
      final direction = toRow > fromRow ? 1 : -1;
      for (
        var row = fromRow + direction;
        row != toRow + direction;
        row += direction
      ) {
        steps.add(row * cols + fromCol);
      }
    }
    return steps;
  }
}

bool threadsComplete(ThreadGeometry geometry, List<ThreadPath> paths) {
  if (!geometry.wellFormed) return false;
  if (paths.length != geometry.puzzle.pairs.length) return false;
  var occupied = Bits.zero;
  final seenPairs = <int>{};
  for (final path in paths) {
    final assessment = geometry.assessPath(path.cells, occupied);
    if (!assessment.accepted || assessment.path!.pairIndex != path.pairIndex) {
      return false;
    }
    if (!seenPairs.add(path.pairIndex)) return false;
    for (final cell in path.cells) {
      occupied = occupied.set(cell);
    }
  }
  return seenPairs.length == geometry.puzzle.pairs.length &&
      occupied.count + geometry.puzzle.blocked.length ==
          geometry.puzzle.cellCount;
}

ThreadSolveResult solveThreads(
  ThreadGeometry geometry, {
  int limit = 2,
  int nodeBudget = 200000,
  List<ThreadPath> fixed = const [],
}) {
  if (!geometry.wellFormed) return ThreadSolveResult.none;
  var occupied = Bits.zero;
  final done = List<bool>.filled(geometry.puzzle.pairs.length, false);
  for (final path in fixed) {
    final assessment = geometry.assessPath(path.cells, occupied);
    if (!assessment.accepted || assessment.path!.pairIndex != path.pairIndex) {
      return ThreadSolveResult.none;
    }
    done[path.pairIndex] = true;
    for (final cell in path.cells) {
      occupied = occupied.set(cell);
    }
  }

  var nodes = 0;
  var solutions = 0;
  var budgetExhausted = false;
  List<ThreadPath>? first;
  final built = <ThreadPath>[];

  bool connected(Bits occ) {
    final free = <int>[];
    for (var i = 0; i < geometry.puzzle.cellCount; i++) {
      if (!occ.test(i) && !geometry.blocked.test(i)) free.add(i);
    }
    if (free.isEmpty) {
      return done.every((value) => value);
    }
    final allowed = List<bool>.filled(geometry.puzzle.cellCount, false);
    for (final index in free) {
      allowed[index] = true;
    }
    final seen = List<bool>.filled(geometry.puzzle.cellCount, false);
    var reached = 0;
    final queue = <int>[];
    for (var i = 0; i < geometry.puzzle.pairs.length; i++) {
      if (done[i]) continue;
      final pair = geometry.puzzle.pairs[i];
      if (!allowed[pair.a] || !allowed[pair.b]) return false;
      for (final end in [pair.a, pair.b]) {
        if (seen[end]) continue;
        seen[end] = true;
        queue.add(end);
        reached++;
      }
      if (!_reaches(geometry, pair.a, pair.b, allowed)) return false;
    }
    var head = 0;
    while (head < queue.length) {
      final cell = queue[head++];
      for (final next in geometry.neighbors(cell)) {
        if (!allowed[next] || seen[next]) continue;
        seen[next] = true;
        queue.add(next);
        reached++;
      }
    }
    return reached == free.length;
  }

  bool search(Bits occ) {
    if (solutions >= limit || budgetExhausted) return true;
    if (++nodes > nodeBudget) {
      budgetExhausted = true;
      return true;
    }
    var nextPair = -1;
    var bestSpan = 1 << 30;
    for (var i = 0; i < done.length; i++) {
      if (done[i]) continue;
      final pair = geometry.puzzle.pairs[i];
      final span = _manhattan(geometry, pair.a, pair.b);
      if (span < bestSpan) {
        bestSpan = span;
        nextPair = i;
      }
    }
    if (nextPair == -1) {
      if (occ.count + geometry.puzzle.blocked.length !=
          geometry.puzzle.cellCount) {
        return false;
      }
      solutions++;
      first ??= [for (final path in built) path];
      return solutions >= limit;
    }
    if (!connected(occ)) return false;

    final pair = geometry.puzzle.pairs[nextPair];
    final path = <int>[pair.a];
    final visited = List<bool>.filled(geometry.puzzle.cellCount, false);
    visited[pair.a] = true;

    bool walk(int head, Bits walkOcc) {
      if (solutions >= limit || budgetExhausted) return true;
      if (++nodes > nodeBudget) {
        budgetExhausted = true;
        return true;
      }
      for (final next in geometry.neighbors(head)) {
        if (geometry.blocked.test(next) ||
            walkOcc.test(next) ||
            visited[next]) {
          continue;
        }
        final owner = geometry.terminalOwner[next];
        if (owner != -1 && owner != nextPair) continue;
        if (next == pair.b) {
          path.add(next);
          done[nextPair] = true;
          built.add(
            ThreadPath(pairIndex: nextPair, cells: List<int>.from(path)),
          );
          final stop = search(walkOcc.set(next));
          built.removeLast();
          done[nextPair] = false;
          path.removeLast();
          if (stop) return true;
          continue;
        }
        if (owner == nextPair) continue;
        path.add(next);
        visited[next] = true;
        final stop = walk(next, walkOcc.set(next));
        visited[next] = false;
        path.removeLast();
        if (stop) return true;
      }
      return false;
    }

    return walk(pair.a, occ.set(pair.a));
  }

  search(occupied);
  return ThreadSolveResult(
    solutions: solutions,
    budgetExhausted: budgetExhausted,
    solution: first,
  );
}

bool _reaches(
  ThreadGeometry geometry,
  int start,
  int goal,
  List<bool> allowed,
) {
  final seen = List<bool>.filled(geometry.puzzle.cellCount, false);
  final queue = <int>[start];
  seen[start] = true;
  var head = 0;
  while (head < queue.length) {
    final cell = queue[head++];
    if (cell == goal) return true;
    for (final next in geometry.neighbors(cell)) {
      if (!allowed[next] || seen[next]) continue;
      seen[next] = true;
      queue.add(next);
    }
  }
  return false;
}

int _manhattan(ThreadGeometry geometry, int a, int b) {
  final cols = geometry.puzzle.cols;
  return ((a ~/ cols) - (b ~/ cols)).abs() + ((a % cols) - (b % cols)).abs();
}

sealed class ThreadEdit {
  const ThreadEdit();
}

class AddThread extends ThreadEdit {
  const AddThread(this.path);
  final ThreadPath path;
}

class RemoveThread extends ThreadEdit {
  const RemoveThread(this.path);
  final ThreadPath path;
}

class ReplaceThreads extends ThreadEdit {
  const ReplaceThreads(this.previous);
  final List<ThreadPath> previous;
}

class ThreadSession {
  ThreadSession({
    required this.puzzle,
    List<ThreadPath>? draft,
    this.hintsUsed = 0,
  }) : geometry = ThreadGeometry(puzzle) {
    if (!geometry.wellFormed || draft == null) return;
    final restored = <ThreadPath>[];
    var occupied = Bits.zero;
    for (final path in draft) {
      final assessment = geometry.assessPath(path.cells, occupied);
      if (!assessment.accepted || assessment.path == null) {
        discardedDraft = true;
        return;
      }
      restored.add(assessment.path!);
      for (final cell in assessment.path!.cells) {
        occupied = occupied.set(cell);
      }
    }
    _paths.addAll(restored);
  }

  final ThreadPuzzle puzzle;
  final ThreadGeometry geometry;
  int hintsUsed;
  bool discardedDraft = false;

  final List<ThreadPath> _paths = [];
  final List<ThreadEdit> _undo = [];
  final List<ThreadEdit> _redo = [];
  bool _rewardClaimed = false;

  List<ThreadPath> get paths => List.unmodifiable(_paths);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isComplete => threadsComplete(geometry, _paths);

  Bits get occupied {
    var bits = Bits.zero;
    for (final path in _paths) {
      for (final cell in path.cells) {
        bits = bits.set(cell);
      }
    }
    return bits;
  }

  ThreadIssue commit(List<int> cells) {
    final assessment = geometry.assessPath(cells, occupied);
    if (!assessment.accepted || assessment.path == null) {
      return assessment.issue;
    }
    if (_paths.any((path) => path.pairIndex == assessment.path!.pairIndex)) {
      return ThreadIssue.endsMismatch;
    }
    _paths.add(assessment.path!);
    _remember(AddThread(assessment.path!));
    return ThreadIssue.ok;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final edit = _undo.removeLast();
    _invert(edit);
    _redo.add(edit);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final edit = _redo.removeLast();
    _apply(edit);
    _undo.add(edit);
    return true;
  }

  bool erasePair(int pairIndex) {
    final index = _paths.indexWhere((path) => path.pairIndex == pairIndex);
    if (index < 0) return false;
    final path = _paths.removeAt(index);
    _remember(RemoveThread(path));
    return true;
  }

  void restart() {
    if (_paths.isEmpty) return;
    _remember(ReplaceThreads(List<ThreadPath>.from(_paths)));
    _paths.clear();
  }

  void _remember(ThreadEdit edit) {
    _undo.add(edit);
    _redo.clear();
  }

  void _apply(ThreadEdit edit) {
    switch (edit) {
      case AddThread(:final path):
        _paths.add(path);
      case RemoveThread(:final path):
        _paths.remove(path);
      case ReplaceThreads():
        _paths.clear();
    }
  }

  void _invert(ThreadEdit edit) {
    switch (edit) {
      case AddThread(:final path):
        _paths.removeWhere(
          (existing) =>
              existing.pairIndex == path.pairIndex &&
              _sameCells(existing.cells, path.cells),
        );
      case RemoveThread(:final path):
        _paths.add(path);
      case ReplaceThreads(:final previous):
        _paths
          ..clear()
          ..addAll(previous);
    }
  }

  bool claimCompletion() {
    if (_rewardClaimed || !isComplete) return false;
    _rewardClaimed = true;
    return true;
  }

  ThreadHint proposeHint() {
    if (isComplete) return const ThreadHint(kind: ThreadHintKind.alreadyDone);
    final solved = solveThreads(
      geometry,
      fixed: _paths,
      limit: 1,
      nodeBudget: 150000,
    );
    if (!solved.budgetExhausted && solved.solutions == 0) {
      return const ThreadHint(kind: ThreadHintKind.deadEnd);
    }
    final continuation = solved.solution;
    if (!solved.budgetExhausted &&
        continuation != null &&
        continuation.isNotEmpty) {
      final path = continuation.first;
      return ThreadHint(
        kind: ThreadHintKind.required,
        pairIndex: path.pairIndex,
        cells: path.cells,
      );
    }
    return const ThreadHint(kind: ThreadHintKind.ambiguous);
  }

  bool applyHint(ThreadHint hint) {
    if (!hint.placesAPath) return false;
    final issue = commit(hint.cells);
    if (issue != ThreadIssue.ok) return false;
    hintsUsed++;
    return true;
  }
}

bool _sameCells(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
