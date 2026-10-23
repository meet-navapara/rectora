// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rectora/domain/parcels/geometry.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';

/// Builds the shipped catalogs. Every accepted puzzle has been solved and
/// proved to have exactly one solution within the search budget.
void main(List<String> args) {
  final parcelTarget = args.isEmpty ? 520 : int.parse(args[0]);
  final threadTarget = args.length < 2 ? 72 : int.parse(args[1]);
  final dailyTarget = args.length < 3 ? 120 : int.parse(args[2]);
  final clock = Stopwatch()..start();

  final parcels = <Map<String, Object?>>[];
  final seen = <String>{};
  for (final hand in _handcraftedParcels()) {
    final level = _acceptParcel(
      clues: hand.clues,
      rows: hand.rows,
      cols: hand.cols,
      solution: hand.solution,
      maxForced: 1,
      minFlexible: 0,
      seen: seen,
    );
    if (level == null) {
      throw StateError(
        'Handcrafted parcel ${hand.rows}x${hand.cols} was rejected.',
      );
    }
    parcels.add(level);
    stderr.writeln('handcrafted parcel ${parcels.length}');
  }

  for (final quota in _parcelQuotas) {
    if (parcels.length >= parcelTarget) break;
    final room = min(quota.count, parcelTarget - parcels.length);
    var made = 0;
    var attempts = 0;
    final rng = Random(quota.seed);
    while (made < room && attempts < room * 500) {
      attempts++;
      final size = quota.sizes[rng.nextInt(quota.sizes.length)];
      final built = _randomParcel(
        rng: rng,
        rows: size.$1,
        cols: size.$2,
        minPiece: quota.minPiece,
        maxForced: quota.maxForced,
        minFlexible: quota.minFlexible,
        seen: seen,
      );
      if (built == null) continue;
      parcels.add(built);
      made++;
      if (parcels.length % 20 == 0) {
        stderr.writeln(
          'parcels ${parcels.length}/$parcelTarget '
          'in ${clock.elapsed.inSeconds}s',
        );
      }
    }
    if (made < room) {
      throw StateError(
        'Only made $made/$room for ${quota.packId} after $attempts attempts.',
      );
    }
  }

  final threads = <Map<String, Object?>>[];
  for (final hand in _handcraftedThreads()) {
    if (!_threadIsUnique(hand)) {
      throw StateError(
        'Handcrafted thread ${hand.rows}x${hand.cols} was rejected.',
      );
    }
    threads.add(_threadJson(hand));
  }
  var threadAttempts = 0;
  final threadRng = Random(9001);
  while (threads.length < threadTarget && threadAttempts < threadTarget * 400) {
    threadAttempts++;
    final spec = _threadSpecFor(threads.length);
    final built = _randomThread(threadRng, spec);
    if (built == null) continue;
    threads.add(_threadJson(built));
    if (threads.length % 8 == 0) {
      stderr.writeln(
        'threads ${threads.length}/$threadTarget '
        'in ${clock.elapsed.inSeconds}s',
      );
    }
  }
  if (threads.length < threadTarget) {
    throw StateError('Only made ${threads.length}/$threadTarget threads.');
  }

  final daily = <Map<String, Object?>>[];
  final dailyRng = Random(4242);
  var dailyAttempts = 0;
  while (daily.length < dailyTarget && dailyAttempts < dailyTarget * 400) {
    dailyAttempts++;
    final size = dailyAttempts.isEven ? (6, 6) : (5, 6);
    final built = _randomParcel(
      rng: dailyRng,
      rows: size.$1,
      cols: size.$2,
      minPiece: 2,
      maxForced: 0.55,
      minFlexible: 2,
      seen: seen,
    );
    if (built == null) continue;
    daily.add(built);
    if (daily.length % 20 == 0) {
      stderr.writeln(
        'daily ${daily.length}/$dailyTarget in ${clock.elapsed.inSeconds}s',
      );
    }
  }
  if (daily.length < dailyTarget) {
    throw StateError('Only made ${daily.length}/$dailyTarget daily puzzles.');
  }

  _numberLevels(parcels, mode: 'parcels', idPrefix: 'parcel');
  _numberLevels(threads, mode: 'threads', idPrefix: 'thread');
  _numberLevels(daily, mode: 'parcels', idPrefix: 'daily');

  final directory = Directory('assets/levels');
  directory.createSync(recursive: true);
  File('assets/levels/parcels.json').writeAsStringSync(
    _encode({
      'format': 1,
      'game': 'rectora',
      'mode': 'parcels',
      'levels': parcels,
    }),
  );
  File('assets/levels/threads.json').writeAsStringSync(
    _encode({
      'format': 1,
      'game': 'rectora',
      'mode': 'threads',
      'levels': threads,
    }),
  );
  File('assets/levels/daily.json').writeAsStringSync(
    _encode({
      'format': 1,
      'game': 'rectora',
      'mode': 'parcels',
      'schedule': 'rectora-daily-v1',
      'epoch': '2026-01-01',
      'levels': daily,
    }),
  );
  final report = {
    'parcels': parcels.length,
    'threads': threads.length,
    'daily': daily.length,
    'schedule': 'rectora-daily-v1',
    'epoch': '2026-01-01',
    'uniqueness': 'solver limit 2, rejected unless exactly one solution',
    'elapsedSeconds': clock.elapsed.inSeconds,
  };
  File('assets/levels/validation_report.json')
      .writeAsStringSync(_encode(report));
  stderr.writeln('wrote catalogs in ${clock.elapsed.inSeconds}s');
  stderr.writeln(report);
}

class _Quota {
  const _Quota({
    required this.packId,
    required this.packName,
    required this.blurb,
    required this.count,
    required this.sizes,
    required this.minPiece,
    required this.maxForced,
    required this.minFlexible,
    required this.difficulty,
    required this.seed,
  });

  final String packId;
  final String packName;
  final String blurb;
  final int count;
  final List<(int, int)> sizes;
  final int minPiece;
  final double maxForced;
  final int minFlexible;
  final Difficulty difficulty;
  final int seed;
}

const _parcelQuotas = [
  _Quota(
    packId: 'first-light',
    packName: 'First Light',
    blurb: 'Small boards and plain numbers.',
    count: 34,
    sizes: [(3, 3), (3, 4), (4, 4)],
    minPiece: 1,
    maxForced: 0.8,
    minFlexible: 0,
    difficulty: Difficulty.easy,
    seed: 11,
  ),
  _Quota(
    packId: 'warm-paper',
    packName: 'Warm Paper',
    blurb: 'A few shapes start to compete.',
    count: 70,
    sizes: [(4, 4), (4, 5), (5, 5)],
    minPiece: 2,
    maxForced: 0.62,
    minFlexible: 1,
    difficulty: Difficulty.easy,
    seed: 22,
  ),
  _Quota(
    packId: 'terrace',
    packName: 'Terrace',
    blurb: 'Longer rectangles and tighter gaps.',
    count: 80,
    sizes: [(5, 5), (5, 6), (6, 6)],
    minPiece: 2,
    maxForced: 0.5,
    minFlexible: 2,
    difficulty: Difficulty.medium,
    seed: 33,
  ),
  _Quota(
    packId: 'inkwell',
    packName: 'Inkwell',
    blurb: 'More than one shape is legal at first glance.',
    count: 100,
    sizes: [(6, 6), (6, 7), (7, 7)],
    minPiece: 2,
    maxForced: 0.45,
    minFlexible: 2,
    difficulty: Difficulty.hard,
    seed: 44,
  ),
  _Quota(
    packId: 'copper',
    packName: 'Copper',
    blurb: 'Boards where a hasty rectangle strands a number.',
    count: 100,
    sizes: [(7, 7), (7, 8)],
    minPiece: 2,
    maxForced: 0.4,
    minFlexible: 3,
    difficulty: Difficulty.expert,
    seed: 55,
  ),
  _Quota(
    packId: 'keystone',
    packName: 'Keystone',
    blurb: 'Large fields with careful counting.',
    count: 70,
    sizes: [(7, 8), (8, 8)],
    minPiece: 2,
    maxForced: 0.38,
    minFlexible: 3,
    difficulty: Difficulty.expert,
    seed: 66,
  ),
  _Quota(
    packId: 'vault',
    packName: 'Vault',
    blurb: 'The longest campaigns in the set.',
    count: 60,
    sizes: [(8, 8)],
    minPiece: 2,
    maxForced: 0.42,
    minFlexible: 3,
    difficulty: Difficulty.master,
    seed: 77,
  ),
];

class _HandParcel {
  const _HandParcel(this.rows, this.cols, this.clues, this.solution);
  final int rows;
  final int cols;
  final List<Clue> clues;
  final List<GridRect> solution;
}

List<_HandParcel> _handcraftedParcels() {
  return const [
    _HandParcel(2, 2, [Clue(0, 0, 4)], [GridRect(0, 0, 1, 1)]),
    _HandParcel(
      2,
      2,
      [Clue(0, 0, 2), Clue(1, 0, 2)],
      [GridRect(0, 0, 0, 1), GridRect(1, 0, 1, 1)],
    ),
    _HandParcel(
      3,
      2,
      [Clue(0, 0, 2), Clue(1, 0, 2), Clue(2, 0, 2)],
      [GridRect(0, 0, 0, 1), GridRect(1, 0, 1, 1), GridRect(2, 0, 2, 1)],
    ),
    _HandParcel(3, 3, [Clue(1, 1, 9)], [GridRect(0, 0, 2, 2)]),
    _HandParcel(
      3,
      3,
      [Clue(0, 0, 3), Clue(0, 1, 3), Clue(0, 2, 3)],
      [GridRect(0, 0, 2, 0), GridRect(0, 1, 2, 1), GridRect(0, 2, 2, 2)],
    ),
    _HandParcel(
      4,
      4,
      [Clue(0, 0, 4), Clue(0, 3, 4), Clue(3, 0, 4), Clue(3, 3, 4)],
      [
        GridRect(0, 0, 1, 1),
        GridRect(0, 2, 1, 3),
        GridRect(2, 0, 3, 1),
        GridRect(2, 2, 3, 3),
      ],
    ),
  ];
}

Map<String, Object?>? _acceptParcel({
  required List<Clue> clues,
  required int rows,
  required int cols,
  required List<GridRect> solution,
  required double maxForced,
  required int minFlexible,
  required Set<String> seen,
}) {
  final ones = clues.where((clue) => clue.value == 1).length;
  if (ones > 2) return null;
  final flexible = solution
      .where((rect) => _flexibleAreas.contains(rect.area))
      .length;
  if (flexible < minFlexible) return null;
  final key =
      (clues.map((clue) => '${clue.row}:${clue.col}:${clue.value}').toList()
            ..sort())
          .join('|');
  if (!seen.add('$rows:$cols:$key')) return null;
  final geometry = ParcelGeometry(
    ParcelPuzzle(rows: rows, cols: cols, clues: clues),
  );
  if (!geometry.wellFormed || geometry.forcedRatio > maxForced + 0.001) {
    seen.remove('$rows:$cols:$key');
    return null;
  }
  if (!exactCover(geometry, solution)) {
    seen.remove('$rows:$cols:$key');
    return null;
  }
  final solved = solveParcels(
    geometry,
    limit: 2,
    nodeBudget: rows * cols >= 56 ? 400000 : 180000,
  );
  if (solved.budgetExhausted || solved.solutions != 1) {
    seen.remove('$rows:$cols:$key');
    return null;
  }
  final found = solved.solution!.toSet();
  if (found.length != solution.length || !found.containsAll(solution)) {
    seen.remove('$rows:$cols:$key');
    return null;
  }
  return {
    'rows': rows,
    'cols': cols,
    'clues': [for (final clue in clues) clue.toList()],
    'solution': [for (final rect in solution) rect.toList()],
  };
}

const _flexibleAreas = {4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 24};

Map<String, Object?>? _randomParcel({
  required Random rng,
  required int rows,
  required int cols,
  required int minPiece,
  required double maxForced,
  required int minFlexible,
  required Set<String> seen,
}) {
  final target = max(2, (rows * cols) ~/ (minPiece == 1 ? 3 : 5));
  final parts = _partition(rows, cols, rng, minPiece, target + rng.nextInt(3));
  if (parts == null || !_covers(parts, rows, cols)) return null;
  final clues = <Clue>[];
  for (final part in parts) {
    final spot = _clueSpot(part, rng);
    clues.add(Clue(spot.$1, spot.$2, part.area));
  }
  return _acceptParcel(
    clues: clues,
    rows: rows,
    cols: cols,
    solution: parts,
    maxForced: maxForced,
    minFlexible: minFlexible,
    seen: seen,
  );
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
    final options = <int>[];
    for (var i = 0; i < parts.length; i++) {
      if (_canSplit(parts[i], minPiece)) options.add(i);
    }
    if (options.isEmpty) break;
    final index = options[rng.nextInt(options.length)];
    final split = _split(parts[index], rng, minPiece);
    if (split == null) continue;
    parts[index] = split.$1;
    parts.add(split.$2);
  }
  if (parts.length < max(2, target - 2)) return null;
  return parts;
}

bool _canSplit(GridRect rect, int minPiece) {
  if (rect.width >= 2) {
    for (var width = 1; width < rect.width; width++) {
      if (width * rect.height >= minPiece &&
          (rect.width - width) * rect.height >= minPiece) {
        return true;
      }
    }
  }
  if (rect.height >= 2) {
    for (var height = 1; height < rect.height; height++) {
      if (height * rect.width >= minPiece &&
          (rect.height - height) * rect.width >= minPiece) {
        return true;
      }
    }
  }
  return false;
}

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
  if (rng.nextDouble() < 0.74) return corners[rng.nextInt(corners.length)];
  return (
    part.r1 + rng.nextInt(part.height),
    part.c1 + rng.nextInt(part.width),
  );
}

bool _covers(List<GridRect> parts, int rows, int cols) {
  final seen = List<int>.filled(rows * cols, 0);
  for (final part in parts) {
    if (!part.inside(rows, cols) || part.area <= 0) return false;
    for (var row = part.r1; row <= part.r2; row++) {
      for (var col = part.c1; col <= part.c2; col++) {
        seen[row * cols + col]++;
      }
    }
  }
  return seen.every((count) => count == 1);
}

class _ThreadDraft {
  const _ThreadDraft({
    required this.rows,
    required this.cols,
    required this.pairs,
    required this.blocked,
    required this.solution,
  });

  final int rows;
  final int cols;
  final List<ThreadPair> pairs;
  final List<int> blocked;
  final List<List<int>> solution;
}

class _ThreadSpec {
  const _ThreadSpec(this.rows, this.cols, this.blocked);
  final int rows;
  final int cols;
  final int blocked;
}

_ThreadSpec _threadSpecFor(int index) {
  if (index < 24) return const _ThreadSpec(4, 4, 0);
  if (index < 48) return const _ThreadSpec(5, 5, 0);
  return const _ThreadSpec(6, 6, 2);
}

List<_ThreadDraft> _handcraftedThreads() {
  return [
    _ThreadDraft(
      rows: 4,
      cols: 4,
      pairs: const [ThreadPair(label: 'A', a: 0, b: 15)],
      blocked: const [4, 5, 6, 8, 9, 10, 12, 13, 14],
      solution: const [
        [0, 1, 2, 3, 7, 11, 15],
      ],
    ),
    const _ThreadDraft(
      rows: 2,
      cols: 2,
      pairs: [
        ThreadPair(label: 'A', a: 0, b: 1),
        ThreadPair(label: 'B', a: 2, b: 3),
      ],
      blocked: [],
      solution: [
        [0, 1],
        [2, 3],
      ],
    ),
  ];
}

bool _threadIsUnique(_ThreadDraft draft) {
  final geometry = ThreadGeometry(
    ThreadPuzzle(
      rows: draft.rows,
      cols: draft.cols,
      pairs: draft.pairs,
      blocked: draft.blocked,
    ),
  );
  if (!geometry.wellFormed) return false;
  final paths = [
    for (var i = 0; i < draft.solution.length; i++)
      ThreadPath(pairIndex: i, cells: draft.solution[i]),
  ];
  if (!threadsComplete(geometry, paths)) return false;
  final solved = solveThreads(geometry, limit: 2, nodeBudget: 120000);
  return !solved.budgetExhausted && solved.solutions == 1;
}

_ThreadDraft? _randomThread(Random rng, _ThreadSpec spec) {
  final blocked = <int>{};
  var guard = 0;
  while (blocked.length < spec.blocked && guard++ < 20) {
    final index = rng.nextInt(spec.rows * spec.cols);
    blocked.add(index);
  }
  if (blocked.length != spec.blocked) return null;
  final route = _hamiltonian(spec.rows, spec.cols, rng, blocked);
  if (route == null) return null;
  final pieces = _splitRoute(route, rng);
  if (pieces.length < 2) return null;
  if (spec.rows > 4 && !pieces.any((piece) => _bends(piece, spec.cols))) {
    return null;
  }
  final pairs = <ThreadPair>[];
  for (var i = 0; i < pieces.length; i++) {
    pairs.add(
      ThreadPair(
        label: String.fromCharCode(65 + i),
        a: pieces[i].first,
        b: pieces[i].last,
      ),
    );
  }
  final draft = _ThreadDraft(
    rows: spec.rows,
    cols: spec.cols,
    pairs: pairs,
    blocked: blocked.toList()..sort(),
    solution: pieces,
  );
  if (!_threadIsUnique(draft)) return null;
  return draft;
}

List<int>? _hamiltonian(int rows, int cols, Random rng, Set<int> blocked) {
  final total = rows * cols;
  final openCount = total - blocked.length;
  if (openCount < 6) return null;
  final startChoices = [
    for (var i = 0; i < total; i++)
      if (!blocked.contains(i)) i,
  ]..shuffle(rng);
  final used = List<bool>.filled(total, false);

  int degree(int index) {
    var count = 0;
    final row = index ~/ cols;
    final col = index % cols;
    void consider(int next) {
      if (!used[next] && !blocked.contains(next)) count++;
    }

    if (col > 0) consider(index - 1);
    if (col + 1 < cols) consider(index + 1);
    if (row > 0) consider(index - cols);
    if (row + 1 < rows) consider(index + cols);
    return count;
  }

  List<int> options(int index) {
    final found = <int>[];
    final row = index ~/ cols;
    final col = index % cols;
    void add(int next) {
      if (!used[next] && !blocked.contains(next)) found.add(next);
    }

    if (col > 0) add(index - 1);
    if (col + 1 < cols) add(index + 1);
    if (row > 0) add(index - cols);
    if (row + 1 < rows) add(index + cols);
    found.sort((a, b) => degree(a).compareTo(degree(b)));
    return found;
  }

  for (final start in startChoices.take(4)) {
    final path = <int>[];
    bool walk(int index) {
      path.add(index);
      used[index] = true;
      if (path.length == openCount) return true;
      for (final next in options(index)) {
        if (walk(next)) return true;
      }
      path.removeLast();
      used[index] = false;
      return false;
    }

    if (walk(start)) return path;
  }
  return null;
}

List<List<int>> _splitRoute(List<int> route, Random rng) {
  final pieces = <List<int>>[];
  var cursor = 0;
  while (cursor < route.length) {
    final remain = route.length - cursor;
    if (remain <= 7) {
      if (remain < 3 && pieces.isNotEmpty) {
        pieces[pieces.length - 1] = [
          ...pieces[pieces.length - 1],
          ...route.sublist(cursor),
        ];
      } else if (remain >= 3) {
        pieces.add(route.sublist(cursor));
      } else {
        return const [];
      }
      break;
    }
    var length = 3 + rng.nextInt(4);
    if (remain - length < 3) length = remain - 3;
    pieces.add(route.sublist(cursor, cursor + length));
    cursor += length;
  }
  return pieces;
}

bool _bends(List<int> path, int cols) {
  for (var i = 1; i < path.length - 1; i++) {
    if (path[i] - path[i - 1] != path[i + 1] - path[i]) return true;
  }
  return false;
}

Map<String, Object?> _threadJson(_ThreadDraft draft) {
  final difficulty = draft.cols <= 4
      ? 'easy'
      : draft.cols == 5
      ? 'medium'
      : 'hard';
  return {
    'rows': draft.rows,
    'cols': draft.cols,
    'difficulty': difficulty,
    'pairs': [
      for (final pair in draft.pairs)
        {
          'label': pair.label,
          'a': [pair.a ~/ draft.cols, pair.a % draft.cols],
          'b': [pair.b ~/ draft.cols, pair.b % draft.cols],
        },
    ],
    'blocked': [
      for (final index in draft.blocked)
        [index ~/ draft.cols, index % draft.cols],
    ],
    'solution': [
      for (final path in draft.solution)
        [
          for (final index in path) [index ~/ draft.cols, index % draft.cols],
        ],
    ],
  };
}

void _numberLevels(
  List<Map<String, Object?>> levels, {
  required String mode,
  required String idPrefix,
}) {
  final milestones = {40, 80, 120, 180, 240, 300, 380, 460, 520};
  for (var i = 0; i < levels.length; i++) {
    final number = i + 1;
    final quota = mode == 'threads' ? _threadPack(number) : _parcelPack(number);
    final raw = levels[i]['difficulty'];
    final existing = raw is String && raw.isNotEmpty ? raw : quota.$4;
    final difficulty = idPrefix == 'daily'
        ? 'medium'
        : mode == 'parcels'
        ? quota.$4
        : existing;
    levels[i] = {
      ...levels[i],
      'id': '$idPrefix-${number.toString().padLeft(3, '0')}',
      'number': number,
      'packId': idPrefix == 'daily' ? 'daily' : quota.$1,
      'packName': idPrefix == 'daily' ? 'Daily' : quota.$2,
      'blurb': idPrefix == 'daily'
          ? 'A local date selects one puzzle from this fixed schedule.'
          : quota.$3,
      'title': idPrefix == 'daily' ? 'Day $number' : _title(mode, number),
      'difficulty': difficulty,
      'milestone': idPrefix == 'parcel' && milestones.contains(number),
    };
  }
}

(String, String, String, String) _parcelPack(int number) {
  if (number <= 40) {
    return (
      'first-light',
      'First Light',
      'Small boards and plain numbers.',
      'easy',
    );
  }
  if (number <= 110) {
    return (
      'warm-paper',
      'Warm Paper',
      'A few shapes start to compete.',
      'easy',
    );
  }
  if (number <= 190) {
    return (
      'terrace',
      'Terrace',
      'Longer rectangles and tighter gaps.',
      'medium',
    );
  }
  if (number <= 290) {
    return (
      'inkwell',
      'Inkwell',
      'More than one shape is legal at first glance.',
      'hard',
    );
  }
  if (number <= 390) {
    return (
      'copper',
      'Copper',
      'Boards where a hasty rectangle strands a number.',
      'expert',
    );
  }
  if (number <= 460) {
    return (
      'keystone',
      'Keystone',
      'Large fields with careful counting.',
      'expert',
    );
  }
  return ('vault', 'Vault', 'The longest campaigns in the set.', 'master');
}

(String, String, String, String) _threadPack(int number) {
  if (number <= 24) {
    return (
      'single-strand',
      'Single Strand',
      'Short paths with obvious ends.',
      'easy',
    );
  }
  if (number <= 48) {
    return (
      'crosshatch',
      'Crosshatch',
      'Paths bend around one another.',
      'medium',
    );
  }
  return ('loom', 'Loom', 'Longer threads and a few closed cells.', 'hard');
}

String _title(String mode, int number) {
  if (mode == 'threads') return 'Thread $number';
  return 'Parcel $number';
}

String _encode(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);
