import 'dart:math' as math;

import '../ink/engine.dart';
import '../parcels/models.dart';
import '../threads/engine.dart';
import '../threads/models.dart';
import '../trace/engine.dart';

/// How much work a board asks of a person. Campaigns are ordered by this, and
/// a test recomputes it, so difficulty never falls from one level to the next.

/// Search budgets shared by the generator and the catalog proof.
const parcelProofBudget = 400000;
const traceProofBudget = 120000;
const inkProofBudget = 120000;
const threadProofBudget = 180000;

double _searchCost(int nodes) => math.log(nodes + 1) / math.ln2 * 2;

/// Plays the board with the deductions a person uses, cheapest first, and
/// charges for each harder one. [deduction] is that cost alone, without the
/// size of the board.
({double effort, double deduction}) parcelEffort(
  ParcelPuzzle puzzle,
  List<GridRect> solution,
) {
  final rows = puzzle.rows;
  final cols = puzzle.cols;
  final clues = puzzle.clues;
  final all = (BigInt.one << (rows * cols)) - BigInt.one;
  BigInt mask(GridRect rect) {
    var bits = BigInt.zero;
    for (var row = rect.r1; row <= rect.r2; row++) {
      for (var col = rect.c1; col <= rect.c2; col++) {
        bits |= BigInt.one << (row * cols + col);
      }
    }
    return bits;
  }

  final alive = <List<BigInt>>[];
  for (final clue in clues) {
    final options = <BigInt>[];
    for (var height = 1; height <= clue.value; height++) {
      if (clue.value % height != 0) continue;
      final width = clue.value ~/ height;
      for (var r1 = clue.row - height + 1; r1 <= clue.row; r1++) {
        for (var c1 = clue.col - width + 1; c1 <= clue.col; c1++) {
          final rect = GridRect(r1, c1, r1 + height - 1, c1 + width - 1);
          if (!rect.inside(rows, cols)) continue;
          var inside = 0;
          for (final other in clues) {
            if (rect.containsCell(other.row, other.col)) inside++;
          }
          if (inside == 1) options.add(mask(rect));
        }
      }
    }
    alive.add(options);
  }
  final initiallyForced = alive.where((list) => list.length == 1).length;
  final fixed = List<bool>.filled(clues.length, false);
  var hidden = 0;
  var shared = 0;
  var lookahead = 0;
  var guesses = 0;

  void place(int index, BigInt rect) {
    alive[index] = [rect];
    fixed[index] = true;
    for (var j = 0; j < alive.length; j++) {
      if (j != index) {
        alive[j].removeWhere((other) => other & rect != BigInt.zero);
      }
    }
  }

  bool dead(List<List<BigInt>> options) {
    var reach = BigInt.zero;
    for (final list in options) {
      if (list.isEmpty) return true;
      for (final option in list) {
        reach |= option;
      }
    }
    return reach != all;
  }

  bool step() {
    for (var i = 0; i < alive.length; i++) {
      if (!fixed[i] && alive[i].length == 1) {
        place(i, alive[i].first);
        return true;
      }
    }
    for (var cell = 0; cell < rows * cols; cell++) {
      final bit = BigInt.one << cell;
      var owner = -1;
      var owners = 0;
      for (var i = 0; i < alive.length; i++) {
        if (alive[i].any((option) => option & bit != BigInt.zero)) {
          owner = i;
          owners++;
        }
      }
      if (owners == 1 &&
          alive[owner].any((option) => option & bit == BigInt.zero)) {
        alive[owner].removeWhere((option) => option & bit == BigInt.zero);
        hidden++;
        return true;
      }
    }
    for (var i = 0; i < alive.length; i++) {
      if (fixed[i] || alive[i].isEmpty) continue;
      var common = alive[i].first;
      for (final option in alive[i]) {
        common &= option;
      }
      if (common == BigInt.zero) continue;
      var removed = false;
      for (var j = 0; j < alive.length; j++) {
        if (j == i) continue;
        final before = alive[j].length;
        alive[j].removeWhere((option) => option & common != BigInt.zero);
        if (alive[j].length != before) removed = true;
      }
      if (removed) {
        shared++;
        return true;
      }
    }
    for (var i = 0; i < alive.length; i++) {
      if (fixed[i] || alive[i].length < 2) continue;
      for (final option in List<BigInt>.from(alive[i])) {
        final trial = [
          for (var j = 0; j < alive.length; j++)
            j == i
                ? [option]
                : [
                    for (final other in alive[j])
                      if (other & option == BigInt.zero) other,
                  ],
        ];
        if (dead(trial)) {
          alive[i].remove(option);
          lookahead++;
          return true;
        }
      }
    }
    return false;
  }

  while (fixed.contains(false)) {
    if (step()) continue;
    var pick = -1;
    for (var i = 0; i < alive.length; i++) {
      if (fixed[i]) continue;
      if (pick < 0 || alive[i].length < alive[pick].length) pick = i;
    }
    guesses++;
    final clue = clues[pick];
    place(
      pick,
      mask(
        solution.firstWhere((rect) => rect.containsCell(clue.row, clue.col)),
      ),
    );
  }

  final deduction =
      hidden * 1.5 +
      shared * 2.5 +
      lookahead * 4 +
      guesses * 12 +
      (1 - initiallyForced / clues.length) * 6;
  return (effort: rows * cols + deduction, deduction: deduction);
}

/// Larger boards with fewer numbers leave longer stretches to work out.
double traceEffort(TracePuzzle puzzle) {
  final open = puzzle.rows * puzzle.cols - puzzle.blocked.length;
  final solved = solveTrace(
    TraceGeometry(puzzle),
    limit: 2,
    nodeBudget: traceProofBudget,
  );
  final share = puzzle.checkpoints.length / open;
  return open + (1 - share) * open * 0.6 + _searchCost(solved.nodes);
}

/// Single-square numbers are free moves, so fewer of them is harder.
double inkEffort(InkPuzzle puzzle) {
  final cells = puzzle.rows * puzzle.cols;
  final solved = solveInks(
    InkGeometry(puzzle),
    limit: 2,
    nodeBudget: inkProofBudget,
  );
  final ones =
      puzzle.clues.where((clue) => clue.value == 1).length /
      puzzle.clues.length;
  return cells + (1 - ones) * cells * 0.4 + _searchCost(solved.nodes);
}

/// Fewer, longer threads leave more room to go wrong.
double threadEffort(ThreadPuzzle puzzle) {
  final open = puzzle.rows * puzzle.cols - puzzle.blocked.length;
  final solved = solveThreads(
    ThreadGeometry(puzzle),
    limit: 2,
    nodeBudget: threadProofBudget,
  );
  return open + open / puzzle.pairs.length * 2 + _searchCost(solved.nodes);
}
