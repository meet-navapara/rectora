// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/trace/engine.dart';

/// Builds the Trace and Inks campaigns. Every kept puzzle has one solution.
void main() {
  final clock = Stopwatch()..start();
  final traces = <Map<String, Object?>>[];
  final inks = <Map<String, Object?>>[];

  for (final hand in _handTraces()) {
    traces.add(hand);
  }
  for (final hand in _handInks()) {
    inks.add(hand);
  }

  const tracePlan = <(String, String, String, String, int, int, int)>[
    (
      'first-step',
      'First Step',
      'Numbers sit close together.',
      'beginner',
      3,
      3,
      4,
    ),
    (
      'straight-edge',
      'Straight Edge',
      'A few turns on a small board.',
      'easy',
      4,
      4,
      5,
    ),
    (
      'courtyard',
      'Courtyard',
      'The path has to change direction.',
      'easy',
      4,
      4,
      4,
    ),
    (
      'switchback',
      'Switchback',
      'Checkpoints are farther apart.',
      'medium',
      5,
      5,
      5,
    ),
    (
      'gallery',
      'Gallery',
      'More than one route looks plausible.',
      'medium',
      5,
      5,
      4,
    ),
    ('lantern', 'Lantern', 'Longer gaps between numbers.', 'hard', 5, 5, 3),
    ('narrow', 'Narrow', 'A wide board with sparse numbers.', 'hard', 5, 6, 4),
    (
      'copper-path',
      'Copper Path',
      'Expert paths leave fewer anchors.',
      'expert',
      5,
      6,
      3,
    ),
    (
      'vault-path',
      'Vault Path',
      'The order is the only guide.',
      'expert',
      6,
      6,
      4,
    ),
    (
      'night-path',
      'Night Path',
      'Master boards ask for a long deduction.',
      'master',
      6,
      6,
      3,
    ),
  ];
  for (final plan in tracePlan) {
    final count = plan.$4 == 'beginner' || plan.$4 == 'easy' ? 8 : 4;
    final made = _bestChapter(plan.$1, plan.$2, count, (random) {
      return _traces(random, plan, count);
    });
    print('trace ${plan.$2}: ${made.length}');
    traces.addAll(made);
  }

  const inkPlan = <(String, String, String, String, int, int, bool)>[
    (
      'ink-dawn',
      'Dawn Rooms',
      'Small regions, including a bent one.',
      'beginner',
      4,
      4,
      true,
    ),
    ('ink-paper', 'Paper Rooms', 'Easy connected shapes.', 'easy', 4, 4, true),
    (
      'ink-terrace',
      'Terrace Rooms',
      'The bend is no longer optional.',
      'easy',
      4,
      5,
      true,
    ),
    (
      'ink-inkwell',
      'Inkwell Rooms',
      'Regions share longer borders.',
      'medium',
      5,
      5,
      true,
    ),
    (
      'ink-lantern',
      'Lantern Rooms',
      'Several shapes compete.',
      'medium',
      5,
      5,
      true,
    ),
    ('ink-gallery', 'Gallery Rooms', 'Harder area clues.', 'hard', 5, 5, true),
    (
      'ink-copper',
      'Copper Rooms',
      'A wider interdependent board.',
      'hard',
      5,
      6,
      true,
    ),
    (
      'ink-keystone',
      'Keystone Rooms',
      'Expert regions interlock.',
      'expert',
      5,
      6,
      true,
    ),
    (
      'ink-vault',
      'Vault Rooms',
      'Little is forced by size alone.',
      'expert',
      6,
      5,
      true,
    ),
    (
      'ink-night',
      'Night Rooms',
      'Master deductions across the board.',
      'master',
      6,
      6,
      true,
    ),
  ];
  for (final plan in inkPlan) {
    final count = plan.$4 == 'beginner' || plan.$4 == 'easy' ? 8 : 4;
    final made = _bestChapter(plan.$1, plan.$2, count, (random) {
      return _inks(random, plan, count);
    });
    print('inks ${plan.$2}: ${made.length}');
    inks.addAll(made);
  }

  _number(traces, 'trace');
  _number(inks, 'ink');
  Directory('assets/levels').createSync(recursive: true);
  File('assets/levels/traces.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'format': 1,
      'game': 'rectora',
      'mode': 'trace',
      'levels': traces,
    }),
  );
  File('assets/levels/inks.json').writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'format': 1, 'game': 'rectora', 'mode': 'inks', 'levels': inks}),
  );
  final reportFile = File('assets/levels/validation_report.json');
  final report =
      jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
  report['traces'] = traces.length;
  report['inks'] = inks.length;
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  print(
    'traces ${traces.length} inks ${inks.length} in ${clock.elapsed.inSeconds}s',
  );
}

List<Map<String, Object?>> _bestChapter(
  String id,
  String name,
  int count,
  List<Map<String, Object?>> Function(Random random) build,
) {
  var best = <Map<String, Object?>>[];
  for (var salt = 0; salt < 12; salt++) {
    final made = build(Random(20261021 + id.hashCode + salt * 997));
    if (made.length > best.length) best = made;
    if (best.length >= count) break;
  }
  if (best.length < 2) {
    throw StateError('$name produced ${best.length} puzzles.');
  }
  return best;
}

void _number(List<Map<String, Object?>> levels, String prefix) {
  for (var i = 0; i < levels.length; i++) {
    final number = i + 1;
    levels[i]['id'] = '$prefix-${number.toString().padLeft(3, '0')}';
    levels[i]['number'] = number;
    levels[i]['title'] = '${prefix == 'trace' ? 'Trace' : 'Inks'} $number';
    levels[i]['milestone'] = number % 10 == 0;
  }
}

List<Map<String, Object?>> _handTraces() {
  const path = [0, 1, 2, 5, 4, 3, 6, 7, 8];
  final puzzle = TracePuzzle(rows: 3, cols: 3, checkpoints: path);
  final geometry = TraceGeometry(puzzle);
  final solved = solveTrace(geometry, limit: 2);
  if (solved.solutions != 1) {
    throw StateError('Handcrafted trace is not unique.');
  }
  return [
    _traceJson(
      pack: (
        'first-step',
        'First Step',
        'Numbers sit close together.',
        'beginner',
      ),
      rows: 3,
      cols: 3,
      checkpoints: path,
      solution: path,
    ),
  ];
}

List<Map<String, Object?>> _traces(
  Random rng,
  (String, String, String, String, int, int, int) plan,
  int count,
) {
  final made = <Map<String, Object?>>[];
  final seen = <String>{};
  final targetGap = switch (plan.$4) {
    'beginner' => 1,
    'easy' => 2,
    'medium' => 3,
    'hard' => 4,
    'expert' => 5,
    _ => 4,
  };
  var attempts = 0;
  final attemptLimit = plan.$4 == 'master' ? 100 : (count > 4 ? 90 : 50);
  while (made.length < count && attempts < attemptLimit) {
    attempts++;
    final path = _hamilton(plan.$5, plan.$6, rng);
    if (path == null) continue;
    final marks = <int>{path.first, path.last};
    TraceSolveResult? solved;
    var accepted = false;
    for (
      var step = 0;
      step < path.length && marks.length < path.length;
      step++
    ) {
      final ordered = _orderedMarks(path, marks);
      final geometry = TraceGeometry(
        TracePuzzle(rows: plan.$5, cols: plan.$6, checkpoints: ordered),
      );
      solved = solveTrace(geometry, limit: 2, nodeBudget: 80000);
      final gap = _largestGap(path, ordered);
      if (!solved.budgetExhausted && solved.solutions == 1) {
        if (gap >= targetGap && solved.solution != null) accepted = true;
        break;
      }
      if (solved.budgetExhausted && marks.length > path.length * 2 ~/ 3) break;
      final indexes = [for (final cell in ordered) path.indexOf(cell)]..sort();
      var bestAt = 0;
      var bestGap = 0;
      for (var i = 1; i < indexes.length; i++) {
        final span = indexes[i] - indexes[i - 1];
        if (span > bestGap) {
          bestGap = span;
          bestAt = (indexes[i] + indexes[i - 1]) ~/ 2;
        }
      }
      if (bestGap <= 1) break;
      marks.add(path[bestAt]);
    }
    if (!accepted || solved == null || solved.solution == null) continue;
    final ordered = _orderedMarks(path, marks);
    final key = '${plan.$5}x${plan.$6}:${ordered.join('.')}';
    if (!seen.add(key)) continue;
    made.add(
      _traceJson(
        pack: (plan.$1, plan.$2, plan.$3, plan.$4),
        rows: plan.$5,
        cols: plan.$6,
        checkpoints: ordered,
        solution: solved.solution!,
      ),
    );
  }
  return made;
}

List<int> _orderedMarks(List<int> path, Set<int> marks) {
  final indexes = [for (final cell in marks) path.indexOf(cell)]..sort();
  return [for (final index in indexes) path[index]];
}

int _largestGap(List<int> path, List<int> marks) {
  final indexes = [for (final cell in marks) path.indexOf(cell)]..sort();
  var gap = 1;
  for (var i = 1; i < indexes.length; i++) {
    final span = indexes[i] - indexes[i - 1];
    if (span > gap) gap = span;
  }
  return gap;
}

Map<String, Object?> _traceJson({
  required (String, String, String, String) pack,
  required int rows,
  required int cols,
  required List<int> checkpoints,
  required List<int> solution,
}) {
  return {
    'rows': rows,
    'cols': cols,
    'checkpoints': [
      for (final cell in checkpoints) [cell ~/ cols, cell % cols],
    ],
    'blocked': <List<int>>[],
    'solution': [
      for (final cell in solution) [cell ~/ cols, cell % cols],
    ],
    'packId': pack.$1,
    'packName': pack.$2,
    'blurb': pack.$3,
    'difficulty': pack.$4,
  };
}

List<int>? _hamilton(int rows, int cols, Random rng) {
  final total = rows * cols;
  final path = <int>[];
  final used = List<bool>.filled(total, false);
  List<int> neighbors(int cell) {
    final row = cell ~/ cols;
    final col = cell % cols;
    final next = <int>[];
    if (row > 0) next.add(cell - cols);
    if (row + 1 < rows) next.add(cell + cols);
    if (col > 0) next.add(cell - 1);
    if (col + 1 < cols) next.add(cell + 1);
    return next;
  }

  int degree(int cell) {
    var count = 0;
    for (final next in neighbors(cell)) {
      if (!used[next]) count++;
    }
    return count;
  }

  var nodes = 0;
  bool walk(int cell) {
    if (++nodes > 20000) return false;
    path.add(cell);
    used[cell] = true;
    if (path.length == total) return true;
    final options = neighbors(cell).where((next) => !used[next]).toList()
      ..sort((a, b) => degree(a).compareTo(degree(b)));
    if (rng.nextBool() && options.length > 1) {
      final swap = options.removeAt(0);
      options.insert(1, swap);
    }
    for (final next in options) {
      if (walk(next)) return true;
    }
    path.removeLast();
    used[cell] = false;
    return false;
  }

  if (!walk(rng.nextInt(total))) return null;
  return List<int>.from(path);
}

List<Map<String, Object?>> _handInks() {
  final rng = Random(7);
  for (var attempt = 0; attempt < 60; attempt++) {
    final regions = _tile(3, 3, rng, bend: true);
    if (regions == null) continue;
    if (!regions.any((region) => !inkRegionIsRectangle(region, 3))) continue;
    final clues = <Clue>[];
    for (final region in regions) {
      final cell = region.first;
      clues.add(Clue(cell ~/ 3, cell % 3, region.length));
    }
    final geometry = InkGeometry(InkPuzzle(rows: 3, cols: 3, clues: clues));
    final solved = solveInks(geometry, limit: 2, nodeBudget: 40000);
    if (solved.solutions == 1 &&
        !solved.budgetExhausted &&
        solved.solution != null) {
      return [
        _inkJson(
          pack: (
            'ink-dawn',
            'Dawn Rooms',
            'A bent region is legal.',
            'beginner',
          ),
          rows: 3,
          cols: 3,
          clues: clues,
          solution: solved.solution!,
        ),
      ];
    }
  }
  throw StateError('No unique beginner inks puzzle was found.');
}

List<Map<String, Object?>> _inks(
  Random rng,
  (String, String, String, String, int, int, bool) plan,
  int count,
) {
  final made = <Map<String, Object?>>[];
  final seen = <String>{};
  var attempts = 0;
  final hard = plan.$4 == 'hard' || plan.$4 == 'expert' || plan.$4 == 'master';
  final attemptLimit = hard ? 80 : 70;
  while (made.length < count && attempts < attemptLimit) {
    attempts++;
    final regions = _tile(plan.$5, plan.$6, rng, bend: plan.$7);
    if (regions == null) continue;
    final bent = regions.any(
      (region) => !inkRegionIsRectangle(region, plan.$6),
    );
    if (plan.$7 && !bent) continue;
    final clues = <Clue>[];
    for (final region in regions) {
      final cell = region[rng.nextInt(region.length)];
      clues.add(Clue(cell ~/ plan.$6, cell % plan.$6, region.length));
    }
    final key = clues
        .map((clue) => '${clue.row},${clue.col},${clue.value}')
        .join('|');
    if (!seen.add(key)) continue;
    final geometry = InkGeometry(
      InkPuzzle(rows: plan.$5, cols: plan.$6, clues: clues),
    );
    if (!geometry.wellFormed) continue;
    final solved = solveInks(
      geometry,
      limit: 2,
      nodeBudget: hard ? 80000 : 50000,
    );
    if (solved.budgetExhausted ||
        solved.solutions != 1 ||
        solved.solution == null) {
      continue;
    }
    made.add(
      _inkJson(
        pack: (plan.$1, plan.$2, plan.$3, plan.$4),
        rows: plan.$5,
        cols: plan.$6,
        clues: clues,
        solution: solved.solution!,
      ),
    );
  }
  return made;
}

Map<String, Object?> _inkJson({
  required (String, String, String, String) pack,
  required int rows,
  required int cols,
  required List<Clue> clues,
  required List<InkRegion> solution,
}) {
  return {
    'rows': rows,
    'cols': cols,
    'clues': [
      for (final clue in clues) [clue.row, clue.col, clue.value],
    ],
    'solution': [
      for (final region in solution)
        [
          for (final cell in region.cells) [cell ~/ cols, cell % cols],
        ],
    ],
    'packId': pack.$1,
    'packName': pack.$2,
    'blurb': pack.$3,
    'difficulty': pack.$4,
  };
}

List<List<int>>? _tile(int rows, int cols, Random rng, {required bool bend}) {
  final total = rows * cols;
  final free = <int>{for (var i = 0; i < total; i++) i};
  final regions = <List<int>>[];
  if (bend) {
    final row = rng.nextInt(rows - 1);
    final col = rng.nextInt(cols - 1);
    final origin = row * cols + col;
    final elbow = rng.nextBool()
        ? [origin, origin + 1, origin + cols + 1]
        : [origin, origin + cols, origin + cols + 1];
    regions.add(elbow);
    free.removeAll(elbow);
  }
  var guard = 0;
  while (free.isNotEmpty && guard < total * 4) {
    guard++;
    final start = free.elementAt(rng.nextInt(free.length));
    final cap = min(5, free.length);
    List<int>? grown;
    final sizes = [for (var size = cap; size >= 1; size--) size]..shuffle(rng);
    for (final size in sizes) {
      grown = _grow(free, start, size, cols, rng);
      if (grown != null) break;
    }
    if (grown == null) return null;
    regions.add(grown);
    free.removeAll(grown);
  }
  if (free.isNotEmpty) return null;
  return regions;
}

List<int>? _grow(Set<int> free, int start, int size, int cols, Random rng) {
  if (!free.contains(start)) return null;
  final cells = <int>[start];
  final inside = <int>{start};
  while (cells.length < size) {
    final frontier = <int>[];
    for (final cell in cells) {
      for (final next in _near(cell, cols, free)) {
        if (!inside.contains(next)) frontier.add(next);
      }
    }
    if (frontier.isEmpty) return null;
    final pick = frontier[rng.nextInt(frontier.length)];
    cells.add(pick);
    inside.add(pick);
  }
  return cells;
}

List<int> _near(int cell, int cols, Set<int> free) {
  final next = <int>[];
  final col = cell % cols;
  if (free.contains(cell - cols)) next.add(cell - cols);
  if (free.contains(cell + cols)) next.add(cell + cols);
  if (col > 0 && free.contains(cell - 1)) next.add(cell - 1);
  if (col + 1 < cols && free.contains(cell + 1)) next.add(cell + 1);
  return next;
}
