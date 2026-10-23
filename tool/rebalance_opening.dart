// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rectora/domain/difficulty/rank.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/geometry.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/trace/engine.dart';

/// Replaces Parcels 1–100 and the first two lessons of the other modes.
/// Later campaign levels, ids, and pack names stay in place.
void main() {
  final clock = Stopwatch()..start();
  _retuneParcels();
  _retuneTrace();
  _retuneInks();
  _retuneThreads();
  stderr.writeln('rebalanced opening in ${clock.elapsed.inSeconds}s');
}

void _retuneParcels() {
  final file = File('assets/levels/parcels.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final levels = (root['levels'] as List).cast<Map<String, Object?>>();
  final seen = <String>{};
  for (var i = 100; i < levels.length; i++) {
    seen.add(_signature(levels[i]));
  }
  final fresh = <Map<String, Object?>>[];
  final lesson = _requireParcel(
    rows: 2,
    cols: 3,
    clues: const [Clue(0, 0, 4), Clue(0, 2, 2)],
    solution: const [GridRect(0, 0, 1, 1), GridRect(0, 2, 1, 2)],
    seen: seen,
  );
  fresh.add(lesson);
  final practice = _firstParcel(
    rng: Random(7),
    sizes: const [(4, 4), (3, 4)],
    minPiece: 2,
    maxForced: 0.67,
    minFlexible: 1,
    minRects: 3,
    minRank: Difficulty.beginner,
    seen: seen,
  );
  fresh.add(practice);

  const bands = <_Band>[
    _Band(3, 10, [(4, 4), (3, 4), (4, 3)], 2, 0.6, 1, 3, Difficulty.beginner),
    _Band(11, 25, [(4, 5), (5, 4), (5, 5)], 2, 0.5, 2, 4, Difficulty.easy),
    _Band(26, 50, [(5, 5), (5, 6), (6, 5)], 2, 0.4, 2, 4, Difficulty.medium),
    _Band(51, 75, [(6, 6), (5, 6), (6, 7)], 2, 0.34, 3, 5, Difficulty.hard),
    _Band(76, 100, [(6, 6), (6, 7), (7, 6)], 2, 0.3, 3, 5, Difficulty.hard),
  ];
  for (final band in bands) {
    final rng = Random(1000 + band.from);
    var attempts = 0;
    while (fresh.length < band.to && attempts < 8000) {
      attempts++;
      final size = band.sizes[rng.nextInt(band.sizes.length)];
      final built = _tryParcel(
        rng: rng,
        rows: size.$1,
        cols: size.$2,
        minPiece: band.minPiece,
        maxForced: band.maxForced,
        minFlexible: band.minFlexible,
        minRects: band.minRects,
        minRank: band.minRank,
        seen: seen,
      );
      if (built == null) continue;
      fresh.add(built);
    }
    if (fresh.length < band.to) {
      throw StateError(
        'Parcels stopped at ${fresh.length} for levels ${band.from}-${band.to} '
        'after $attempts attempts.',
      );
    }
    stderr.writeln('parcels through ${band.to}');
  }

  var forcedEarly = 0.0;
  var forcedLate = 0.0;
  for (var i = 0; i < 100; i++) {
    final number = i + 1;
    final level = levels[i];
    final built = fresh[i];
    level
      ..['rows'] = built['rows']
      ..['cols'] = built['cols']
      ..['clues'] = built['clues']
      ..['solution'] = built['solution']
      ..['difficulty'] = built['difficulty']
      ..['tutorial'] = number <= 2;
    final ratio = built['forcedRatio'] as double;
    if (number >= 3 && number <= 10) forcedEarly += ratio;
    if (number >= 76) forcedLate += ratio;
  }
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
  stderr.writeln(
    'parcel forced ratio 3-10 ${(forcedEarly / 8).toStringAsFixed(2)} '
    '76-100 ${(forcedLate / 25).toStringAsFixed(2)}',
  );
}

void _retuneTrace() {
  final file = File('assets/levels/traces.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final levels = (root['levels'] as List).cast<Map<String, Object?>>();
  const traceOne = [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
    [1, 1],
    [1, 0],
  ];
  const traceTwo = [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
    [2, 2],
    [2, 1],
    [1, 1],
    [1, 0],
    [2, 0],
  ];
  final lesson = _traceLesson(
    rows: 2,
    cols: 3,
    checkpoints: traceOne,
    solution: traceOne,
  );
  final practice = _traceLesson(
    rows: 3,
    cols: 3,
    checkpoints: traceTwo,
    solution: traceTwo,
  );
  _swapOpening(levels, [lesson, practice]);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
  stderr.writeln('trace lessons ${levels.length} kept');
}

void _retuneInks() {
  final file = File('assets/levels/inks.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final levels = (root['levels'] as List).cast<Map<String, Object?>>();
  final lesson = _inkLesson(
    rows: 2,
    cols: 3,
    clues: const [
      [1, 0, 3],
      [0, 0, 1],
      [0, 1, 1],
      [0, 2, 1],
    ],
    solution: const [
      [
        [1, 0],
        [1, 1],
        [1, 2],
      ],
      [
        [0, 0],
      ],
      [
        [0, 1],
      ],
      [
        [0, 2],
      ],
    ],
  );
  final practice = _inkLesson(
    rows: 3,
    cols: 3,
    clues: const [
      [0, 0, 2],
      [0, 1, 3],
      [1, 2, 2],
      [2, 0, 2],
    ],
    solution: const [
      [
        [0, 0],
        [1, 0],
      ],
      [
        [0, 1],
        [0, 2],
        [1, 1],
      ],
      [
        [1, 2],
        [2, 2],
      ],
      [
        [2, 0],
        [2, 1],
      ],
    ],
  );
  _swapOpening(levels, [lesson, practice]);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
  stderr.writeln('ink lessons ${levels.length} kept');
}

void _retuneThreads() {
  final file = File('assets/levels/threads.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final levels = (root['levels'] as List).cast<Map<String, Object?>>();
  final lesson = _threadLesson(
    rows: 3,
    cols: 3,
    pairs: const [('A', 0, 2), ('B', 6, 8)],
    blocked: const [3, 4, 5],
    solution: const [
      [0, 1, 2],
      [6, 7, 8],
    ],
  );
  final practice = _threadLesson(
    rows: 4,
    cols: 4,
    pairs: const [('A', 0, 3), ('B', 12, 15), ('C', 4, 7)],
    blocked: const [8, 9, 10, 11],
    solution: const [
      [0, 1, 2, 3],
      [12, 13, 14, 15],
      [4, 5, 6, 7],
    ],
  );
  _swapOpening(levels, [lesson, practice]);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
  stderr.writeln('thread lessons ${levels.length} kept');
}

void _swapOpening(
  List<Map<String, Object?>> levels,
  List<Map<String, Object?>> fresh,
) {
  for (var i = 0; i < fresh.length; i++) {
    final level = levels[i];
    final built = fresh[i];
    built.forEach((key, value) {
      if (key == 'tutorial') return;
      level[key] = value;
    });
    level['tutorial'] = true;
    level['difficulty'] = i == 0 ? 'beginner' : 'easy';
  }
}

Map<String, Object?> _requireParcel({
  required int rows,
  required int cols,
  required List<Clue> clues,
  required List<GridRect> solution,
  required Set<String> seen,
}) {
  final built = _accept(
    clues: clues,
    rows: rows,
    cols: cols,
    solution: solution,
    maxForced: 1,
    minFlexible: 0,
    minRects: 2,
    minRank: Difficulty.beginner,
    seen: seen,
  );
  if (built == null) {
    throw StateError('Handcrafted parcel lesson was rejected.');
  }
  return built;
}

Map<String, Object?> _firstParcel({
  required Random rng,
  required List<(int, int)> sizes,
  required int minPiece,
  required double maxForced,
  required int minFlexible,
  required int minRects,
  required Difficulty minRank,
  required Set<String> seen,
}) {
  for (var attempt = 0; attempt < 2000; attempt++) {
    final size = sizes[rng.nextInt(sizes.length)];
    final built = _tryParcel(
      rng: rng,
      rows: size.$1,
      cols: size.$2,
      minPiece: minPiece,
      maxForced: maxForced,
      minFlexible: minFlexible,
      minRects: minRects,
      minRank: minRank,
      seen: seen,
    );
    if (built != null) return built;
  }
  throw StateError('No practice parcel was found.');
}

class _Band {
  const _Band(
    this.from,
    this.to,
    this.sizes,
    this.minPiece,
    this.maxForced,
    this.minFlexible,
    this.minRects,
    this.minRank,
  );

  final int from;
  final int to;
  final List<(int, int)> sizes;
  final int minPiece;
  final double maxForced;
  final int minFlexible;
  final int minRects;
  final Difficulty minRank;
}

const _flexibleAreas = {4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 24};

Map<String, Object?>? _tryParcel({
  required Random rng,
  required int rows,
  required int cols,
  required int minPiece,
  required double maxForced,
  required int minFlexible,
  required int minRects,
  required Difficulty minRank,
  required Set<String> seen,
}) {
  final target = max(minRects, (rows * cols) ~/ 5);
  final parts = _partition(rows, cols, rng, minPiece, target);
  if (parts == null || parts.length < minRects) return null;
  final clues = <Clue>[];
  for (final part in parts) {
    final spot = _clueSpot(part, rng);
    clues.add(Clue(spot.$1, spot.$2, part.area));
  }
  return _accept(
    clues: clues,
    rows: rows,
    cols: cols,
    solution: parts,
    maxForced: maxForced,
    minFlexible: minFlexible,
    minRects: minRects,
    minRank: minRank,
    seen: seen,
  );
}

Map<String, Object?>? _accept({
  required List<Clue> clues,
  required int rows,
  required int cols,
  required List<GridRect> solution,
  required double maxForced,
  required int minFlexible,
  required int minRects,
  required Difficulty minRank,
  required Set<String> seen,
}) {
  if (solution.length < minRects) return null;
  if (clues.where((clue) => clue.value == 1).length > 1) return null;
  final flexible = solution
      .where((rect) => _flexibleAreas.contains(rect.area))
      .length;
  if (flexible < minFlexible) return null;
  final key = _clueKey(rows, cols, clues);
  if (!seen.add(key)) return null;
  final geometry = ParcelGeometry(
    ParcelPuzzle(rows: rows, cols: cols, clues: clues),
  );
  if (!geometry.wellFormed || geometry.forcedRatio > maxForced + 0.001) {
    seen.remove(key);
    return null;
  }
  if (!exactCover(geometry, solution)) {
    seen.remove(key);
    return null;
  }
  final solved = solveParcels(geometry, limit: 2, nodeBudget: 180000);
  if (solved.budgetExhausted ||
      solved.solutions != 1 ||
      solved.solution == null) {
    seen.remove(key);
    return null;
  }
  final found = solved.solution!.toSet();
  if (found.length != solution.length || !found.containsAll(solution)) {
    seen.remove(key);
    return null;
  }
  final opening = openingProfile(geometry);
  final backtracked = parcelSearchBacktracked(geometry, solved.nodes);
  final rank = rankParcel(
    opening: opening,
    nodes: solved.nodes,
    backtracked: backtracked,
  );
  if (rank.index < minRank.index) {
    seen.remove(key);
    return null;
  }
  return {
    'rows': rows,
    'cols': cols,
    'clues': [for (final clue in clues) clue.toList()],
    'solution': [for (final rect in solution) rect.toList()],
    'difficulty': rank.name,
    'forcedRatio': geometry.forcedRatio,
    'nodes': solved.nodes,
  };
}

String _signature(Map<String, Object?> level) {
  final clues = level['clues'];
  if (clues is! List) return '';
  final parts = [
    for (final clue in clues)
      if (clue is List) clue.join(':'),
  ]..sort();
  return '${level['rows']}x${level['cols']}:${parts.join('|')}';
}

String _clueKey(int rows, int cols, List<Clue> clues) {
  final parts = [
    for (final clue in clues) '${clue.row}:${clue.col}:${clue.value}',
  ]..sort();
  return '${rows}x$cols:${parts.join('|')}';
}

List<GridRect>? _partition(
  int rows,
  int cols,
  Random rng,
  int minPiece,
  int target,
) {
  final parts = [GridRect(0, 0, rows - 1, cols - 1)];
  var guard = 0;
  while (parts.length < target && guard++ < 80) {
    final options = <int>[
      for (var i = 0; i < parts.length; i++)
        if (_canSplit(parts[i], minPiece)) i,
    ];
    if (options.isEmpty) break;
    final index = options[rng.nextInt(options.length)];
    final chosen = _split(parts[index], rng, minPiece);
    if (chosen == null) continue;
    parts[index] = chosen.$1;
    parts.add(chosen.$2);
  }
  return parts.length < 2 ? null : parts;
}

bool _canSplit(GridRect rect, int minPiece) =>
    _split(rect, Random(1), minPiece) != null;

(GridRect, GridRect)? _split(GridRect rect, Random rng, int minPiece) {
  final verticalCuts = <int>[];
  final horizontalCuts = <int>[];
  for (var width = 1; width < rect.width; width++) {
    if (width * rect.height >= minPiece &&
        (rect.width - width) * rect.height >= minPiece) {
      verticalCuts.add(width);
    }
  }
  for (var height = 1; height < rect.height; height++) {
    if (height * rect.width >= minPiece &&
        (rect.height - height) * rect.width >= minPiece) {
      horizontalCuts.add(height);
    }
  }
  if (verticalCuts.isEmpty && horizontalCuts.isEmpty) return null;
  final vertical =
      verticalCuts.isNotEmpty && (horizontalCuts.isEmpty || rng.nextBool());
  if (vertical) {
    final width = verticalCuts[rng.nextInt(verticalCuts.length)];
    return (
      GridRect(rect.r1, rect.c1, rect.r2, rect.c1 + width - 1),
      GridRect(rect.r1, rect.c1 + width, rect.r2, rect.c2),
    );
  }
  final height = horizontalCuts[rng.nextInt(horizontalCuts.length)];
  return (
    GridRect(rect.r1, rect.c1, rect.r1 + height - 1, rect.c2),
    GridRect(rect.r1 + height, rect.c1, rect.r2, rect.c2),
  );
}

(int, int) _clueSpot(GridRect part, Random rng) {
  final corners = [
    (part.r1, part.c1),
    (part.r1, part.c2),
    (part.r2, part.c1),
    (part.r2, part.c2),
  ];
  if (rng.nextDouble() < 0.7) return corners[rng.nextInt(corners.length)];
  return (
    part.r1 + rng.nextInt(part.height),
    part.c1 + rng.nextInt(part.width),
  );
}

Map<String, Object?> _traceLesson({
  required int rows,
  required int cols,
  required List<List<int>> checkpoints,
  required List<List<int>> solution,
}) {
  final puzzle = TracePuzzle(
    rows: rows,
    cols: cols,
    checkpoints: [for (final cell in checkpoints) cell[0] * cols + cell[1]],
  );
  final geometry = TraceGeometry(puzzle);
  final path = [for (final cell in solution) cell[0] * cols + cell[1]];
  if (!geometry.wellFormed || !geometry.complete(path)) {
    throw StateError('Trace lesson does not cover the board.');
  }
  final solved = solveTrace(geometry, limit: 2);
  if (solved.budgetExhausted || solved.solutions != 1) {
    throw StateError('Trace lesson is not unique (${solved.solutions}).');
  }
  return {
    'rows': rows,
    'cols': cols,
    'checkpoints': checkpoints,
    'blocked': <List<int>>[],
    'solution': solution,
  };
}

Map<String, Object?> _inkLesson({
  required int rows,
  required int cols,
  required List<List<int>> clues,
  required List<List<List<int>>> solution,
}) {
  final puzzle = InkPuzzle(
    rows: rows,
    cols: cols,
    clues: [for (final clue in clues) Clue(clue[0], clue[1], clue[2])],
  );
  final geometry = InkGeometry(puzzle);
  final regions = [
    for (final region in solution)
      InkRegion([for (final cell in region) cell[0] * cols + cell[1]]),
  ];
  if (!geometry.wellFormed || !geometry.complete(regions)) {
    throw StateError('Ink lesson does not cover the board.');
  }
  final solved = solveInks(geometry, limit: 2);
  if (solved.budgetExhausted || solved.solutions != 1) {
    throw StateError('Ink lesson is not unique (${solved.solutions}).');
  }
  return {'rows': rows, 'cols': cols, 'clues': clues, 'solution': solution};
}

Map<String, Object?> _threadLesson({
  required int rows,
  required int cols,
  required List<(String, int, int)> pairs,
  required List<int> blocked,
  required List<List<int>> solution,
}) {
  final puzzle = ThreadPuzzle(
    rows: rows,
    cols: cols,
    pairs: [
      for (final pair in pairs)
        ThreadPair(label: pair.$1, a: pair.$2, b: pair.$3),
    ],
    blocked: blocked,
  );
  final geometry = ThreadGeometry(puzzle);
  final paths = [
    for (var i = 0; i < solution.length; i++)
      ThreadPath(pairIndex: i, cells: solution[i]),
  ];
  if (!geometry.wellFormed || !threadsComplete(geometry, paths)) {
    throw StateError('Thread lesson does not cover the board.');
  }
  final solved = solveThreads(geometry, limit: 2, nodeBudget: 80000);
  if (solved.budgetExhausted || solved.solutions != 1) {
    throw StateError('Thread lesson is not unique (${solved.solutions}).');
  }
  return {
    'rows': rows,
    'cols': cols,
    'pairs': [
      for (final pair in pairs)
        {
          'label': pair.$1,
          'a': [pair.$2 ~/ cols, pair.$2 % cols],
          'b': [pair.$3 ~/ cols, pair.$3 % cols],
        },
    ],
    'blocked': [
      for (final index in blocked) [index ~/ cols, index % cols],
    ],
    'solution': [
      for (final path in solution)
        [
          for (final index in path) [index ~/ cols, index % cols],
        ],
    ],
  };
}
