// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rectora/domain/difficulty/effort.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/geometry.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/trace/engine.dart';

/// Builds every campaign in two steps.
///
///   dart run tool/build_campaign.dart generate parcels 5 1
///   dart run tool/build_campaign.dart assemble
///
/// `generate` spends the given minutes on each board size and adds what it
/// finds to `build/campaign/<mode>.jsonl`, so runs can be repeated with a new
/// seed. `assemble` keeps the hardest boards of each size, orders them by
/// measured effort, and writes `assets/levels`. Every kept board has exactly
/// one solution. Lessons are the levels already marked `tutorial`.
void main(List<String> args) {
  if (args.first == 'assemble') {
    _assemble();
    return;
  }
  final mode = args[1];
  final minutes = double.parse(args[2]);
  final rng = Random(int.parse(args[3]));
  final spare = args.length > 4 ? int.parse(args[4]) : 3;
  final limit = Duration(milliseconds: (minutes * 60000).round());
  final pool = _Pool(mode);
  final (bands, make) = switch (mode) {
    'parcels' => (_parcelBands, _parcel),
    'traces' => (_traceBands, _trace),
    'inks' => (_inkBands, _ink),
    'threads' => (_threadBands, _thread),
    'daily' => (_dailyBands, _parcel),
    _ => throw ArgumentError(mode),
  };
  for (final band in bands) {
    final clock = Stopwatch()..start();
    var made = 0;
    var tries = 0;
    while (clock.elapsed < limit && made < band.keep * spare) {
      tries++;
      final level = make(rng, band);
      if (level != null && pool.add(level)) made++;
    }
    print('$mode ${band.rows}x${band.cols}: +$made from $tries tries');
  }
}

/// Board size and how many levels of that size the campaign wants.
class _Band {
  const _Band(this.rows, this.cols, this.keep);

  final int rows;
  final int cols;
  final int keep;
}

const _parcelBands = [
  _Band(4, 4, 8),
  _Band(4, 5, 14),
  _Band(5, 5, 22),
  _Band(5, 6, 26),
  _Band(6, 6, 40),
  _Band(6, 7, 40),
  _Band(7, 7, 60),
  _Band(7, 8, 50),
  _Band(8, 8, 60),
  _Band(8, 9, 50),
  _Band(9, 9, 50),
  _Band(9, 10, 30),
  _Band(10, 10, 30),
  _Band(10, 11, 10),
  _Band(11, 11, 8),
];

const _dailyBands = [_Band(7, 7, 40), _Band(7, 8, 40), _Band(8, 8, 40)];

const _traceBands = [
  _Band(3, 4, 18),
  _Band(4, 4, 30),
  _Band(4, 5, 50),
  _Band(5, 5, 60),
  _Band(5, 6, 80),
  _Band(6, 6, 90),
  _Band(6, 7, 70),
  _Band(7, 7, 60),
  _Band(7, 8, 30),
  _Band(8, 8, 10),
];

const _inkBands = [
  _Band(3, 4, 18),
  _Band(4, 4, 40),
  _Band(4, 5, 60),
  _Band(5, 5, 80),
  _Band(5, 6, 90),
  _Band(6, 6, 90),
  _Band(6, 7, 60),
  _Band(7, 7, 40),
  _Band(7, 8, 20),
];

const _threadBands = [
  _Band(4, 4, 30),
  _Band(4, 5, 30),
  _Band(5, 5, 70),
  _Band(5, 6, 70),
  _Band(6, 6, 90),
  _Band(6, 7, 70),
  _Band(7, 7, 70),
  _Band(7, 8, 40),
  _Band(8, 8, 28),
];

/// Candidate boards on disk. A board that repeats another after a rotation or
/// a mirror is refused.
class _Pool {
  _Pool(String mode) : file = File('build/campaign/$mode.jsonl') {
    file.parent.createSync(recursive: true);
    if (!file.existsSync()) return;
    for (final line in file.readAsLinesSync()) {
      seen.add(_key(jsonDecode(line) as Map<String, Object?>));
    }
  }

  final File file;
  final seen = <String>{};

  bool add(Map<String, Object?> level) {
    if (!seen.add(_key(level))) return false;
    file.writeAsStringSync('${jsonEncode(level)}\n', mode: FileMode.append);
    return true;
  }
}

String _key(Map<String, Object?> level) {
  final rows = level['rows'] as int;
  final cols = level['cols'] as int;
  final blocked = {
    for (final cell in (level['blocked'] as List? ?? const []).cast<List>())
      (cell[0] as int, cell[1] as int): 'x',
  };
  if (level['checkpoints'] != null) {
    final marks = (level['checkpoints'] as List).cast<List>();
    String key(Iterable<List> ordered) {
      var index = 0;
      return _canon(rows, cols, {
        ...blocked,
        for (final mark in ordered)
          (mark[0] as int, mark[1] as int): '${index++}',
      });
    }

    final forward = key(marks);
    final backward = key(marks.reversed);
    return forward.compareTo(backward) < 0 ? forward : backward;
  }
  if (level['pairs'] != null) {
    return _canon(rows, cols, {
      ...blocked,
      for (final pair in (level['pairs'] as List).cast<Map>()) ...{
        ((pair['a'] as List)[0] as int, (pair['a'] as List)[1] as int): 'p',
        ((pair['b'] as List)[0] as int, (pair['b'] as List)[1] as int): 'p',
      },
    });
  }
  return _canon(rows, cols, {
    for (final clue in (level['clues'] as List).cast<List>())
      (clue[0] as int, clue[1] as int): '${clue[2]}',
  });
}

String _canon(int rows, int cols, Map<(int, int), String> cells) {
  String? best;
  for (var flip = 0; flip < 2; flip++) {
    for (var turn = 0; turn < 4; turn++) {
      final parts = <String>[];
      cells.forEach((cell, label) {
        var row = cell.$1;
        var col = flip == 1 ? cols - 1 - cell.$2 : cell.$2;
        for (var i = 0; i < turn; i++) {
          final height = i.isEven ? rows : cols;
          final next = col;
          col = height - 1 - row;
          row = next;
        }
        parts.add('$row:$col:$label');
      });
      parts.sort();
      final shape = turn.isEven ? '${rows}x$cols' : '${cols}x$rows';
      final key = '$shape|${parts.join(',')}';
      if (best == null || key.compareTo(best) < 0) best = key;
    }
  }
  return best!;
}

// ---------------------------------------------------------------- Parcels

Map<String, Object?>? _parcel(Random rng, _Band band) {
  final rows = band.rows;
  final cols = band.cols;
  final cells = rows * cols;
  // Bigger boards use bigger rectangles, so fewer numbers carry the board.
  final target = cells ~/ (cells < 36 ? 4.5 : (cells < 64 ? 5.5 : 6.5));
  final parts = _partition(rows, cols, rng, target);
  if (parts == null) return null;
  final clues = <Clue>[];
  for (final part in parts) {
    final spot = rng.nextDouble() < 0.5
        ? (
            rng.nextBool() ? part.r1 : part.r2,
            rng.nextBool() ? part.c1 : part.c2,
          )
        : (
            part.r1 + rng.nextInt(part.height),
            part.c1 + rng.nextInt(part.width),
          );
    clues.add(Clue(spot.$1, spot.$2, part.area));
  }
  final puzzle = ParcelPuzzle(rows: rows, cols: cols, clues: clues);
  final geometry = ParcelGeometry(puzzle);
  if (!geometry.wellFormed || geometry.forcedRatio > 0.4) return null;
  final solved = solveParcels(
    geometry,
    limit: 2,
    nodeBudget: cells >= 56 ? parcelProofBudget : 180000,
  );
  if (solved.budgetExhausted || solved.solutions != 1) return null;
  final measured = parcelEffort(puzzle, parts);
  return {
    'rows': rows,
    'cols': cols,
    'clues': [for (final clue in clues) clue.toList()],
    'solution': [for (final rect in parts) rect.toList()],
    'effort': measured.effort,
    'rank': measured.deduction,
  };
}

List<GridRect>? _partition(int rows, int cols, Random rng, int target) {
  final parts = [GridRect(0, 0, rows - 1, cols - 1)];
  var guard = 0;
  while (parts.length < target && guard++ < 300) {
    final index = rng.nextInt(parts.length);
    final part = parts[index];
    if (part.area < 4) continue;
    final vertical = part.width == 1
        ? false
        : part.height == 1 || rng.nextBool();
    if (vertical) {
      final cut = 1 + rng.nextInt(part.width - 1);
      if (cut * part.height < 2 || (part.width - cut) * part.height < 2) {
        continue;
      }
      parts[index] = GridRect(part.r1, part.c1, part.r2, part.c1 + cut - 1);
      parts.add(GridRect(part.r1, part.c1 + cut, part.r2, part.c2));
    } else {
      final cut = 1 + rng.nextInt(part.height - 1);
      if (cut * part.width < 2 || (part.height - cut) * part.width < 2) {
        continue;
      }
      parts[index] = GridRect(part.r1, part.c1, part.r1 + cut - 1, part.c2);
      parts.add(GridRect(part.r1 + cut, part.c1, part.r2, part.c2));
    }
  }
  return parts.length < target ? null : parts;
}

// ------------------------------------------------------------------ Trace

Map<String, Object?>? _trace(Random rng, _Band band) {
  final rows = band.rows;
  final cols = band.cols;
  final blocked = _blocked(rng, rows, cols);
  final path = _hamilton(rows, cols, rng, blocked);
  if (path == null) return null;
  final total = path.length;
  bool unique(Set<int> marks) {
    final solved = solveTrace(
      TraceGeometry(
        TracePuzzle(
          rows: rows,
          cols: cols,
          checkpoints: [for (final i in marks.toList()..sort()) path[i]],
          blocked: blocked.toList(),
        ),
      ),
      limit: 2,
      nodeBudget: traceProofBudget,
    );
    return !solved.budgetExhausted && solved.solutions == 1;
  }

  // Split the longest gap until the path is forced, then take numbers away
  // again wherever the path stays forced without them.
  final marks = <int>{0, total - 1};
  while (!unique(marks)) {
    if (marks.length >= total) return null;
    final sorted = marks.toList()..sort();
    var at = 0;
    var gap = 0;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] > gap) {
        gap = sorted[i] - sorted[i - 1];
        at = (sorted[i] + sorted[i - 1]) ~/ 2;
      }
    }
    marks.add(at);
  }
  final removable = marks.where((i) => i != 0 && i != total - 1).toList()
    ..shuffle(rng);
  for (final mark in removable) {
    marks.remove(mark);
    if (!unique(marks)) marks.add(mark);
  }
  final ordered = [for (final i in marks.toList()..sort()) path[i]];
  final puzzle = TracePuzzle(
    rows: rows,
    cols: cols,
    checkpoints: ordered,
    blocked: blocked.toList(),
  );
  List<int> cell(int index) => [index ~/ cols, index % cols];
  return {
    'rows': rows,
    'cols': cols,
    'checkpoints': [for (final index in ordered) cell(index)],
    'blocked': [for (final index in blocked) cell(index)],
    'solution': [for (final index in path) cell(index)],
    'effort': traceEffort(puzzle),
  };
}

/// Some larger boards close a few squares, so paths do not all look alike.
Set<int> _blocked(Random rng, int rows, int cols) {
  final cells = rows * cols;
  if (cells < 20 || rng.nextInt(4) != 0) return const {};
  final count = 1 + rng.nextInt(cells ~/ 12 + 1);
  return {for (var i = 0; i < count; i++) rng.nextInt(cells)};
}

List<int>? _hamilton(int rows, int cols, Random rng, Set<int> blocked) {
  final total = rows * cols;
  final open = total - blocked.length;
  final path = <int>[];
  final used = List<bool>.filled(total, false);
  for (final cell in blocked) {
    used[cell] = true;
  }
  List<int> near(int cell) {
    final row = cell ~/ cols;
    final col = cell % cols;
    return [
      if (row > 0) cell - cols,
      if (row + 1 < rows) cell + cols,
      if (col > 0) cell - 1,
      if (col + 1 < cols) cell + 1,
    ];
  }

  int degree(int cell) => near(cell).where((next) => !used[next]).length;
  var nodes = 0;
  bool walk(int cell) {
    if (++nodes > 20000) return false;
    path.add(cell);
    used[cell] = true;
    if (path.length == open) return true;
    final options = near(cell).where((next) => !used[next]).toList()
      ..shuffle(rng)
      ..sort((a, b) => degree(a).compareTo(degree(b)));
    if (options.length > 1 && rng.nextInt(3) == 0) {
      options.insert(1, options.removeAt(0));
    }
    for (final next in options) {
      if (walk(next)) return true;
    }
    path.removeLast();
    used[cell] = false;
    return false;
  }

  var start = rng.nextInt(total);
  while (blocked.contains(start)) {
    start = rng.nextInt(total);
  }
  return walk(start) ? path : null;
}

// ------------------------------------------------------------------- Inks

Map<String, Object?>? _ink(Random rng, _Band band) {
  final rows = band.rows;
  final cols = band.cols;
  final cells = rows * cols;
  final largest = cells >= 30 ? 3 + rng.nextInt(2) : (cells < 25 ? 4 : 5);
  final regions = _tile(rows, cols, rng, largest);
  if (!regions.any((region) => !inkRegionIsRectangle(region, cols))) {
    return null;
  }
  final ones = regions.where((region) => region.length == 1).length;
  if (ones / regions.length > 0.34) return null;
  final clues = <Clue>[
    for (final region in regions)
      () {
        final cell = region[rng.nextInt(region.length)];
        return Clue(cell ~/ cols, cell % cols, region.length);
      }(),
  ];
  final puzzle = InkPuzzle(rows: rows, cols: cols, clues: clues);
  final geometry = InkGeometry(puzzle);
  if (!geometry.wellFormed) return null;
  final solved = solveInks(geometry, limit: 2, nodeBudget: inkProofBudget);
  if (solved.budgetExhausted ||
      solved.solutions != 1 ||
      solved.solution == null) {
    return null;
  }
  return {
    'rows': rows,
    'cols': cols,
    'clues': [
      for (final clue in clues) [clue.row, clue.col, clue.value],
    ],
    'solution': [
      for (final region in solved.solution!)
        [
          for (final cell in region.cells) [cell ~/ cols, cell % cols],
        ],
    ],
    'effort': inkEffort(puzzle),
  };
}

List<List<int>> _tile(int rows, int cols, Random rng, int largest) {
  final total = rows * cols;
  final free = <int>{for (var i = 0; i < total; i++) i};
  final regions = <List<int>>[];
  List<int> near(int cell) {
    final col = cell % cols;
    return [
      if (free.contains(cell - cols)) cell - cols,
      if (free.contains(cell + cols)) cell + cols,
      if (col > 0 && free.contains(cell - 1)) cell - 1,
      if (col + 1 < cols && free.contains(cell + 1)) cell + 1,
    ];
  }

  while (free.isNotEmpty) {
    final start = free.elementAt(rng.nextInt(free.length));
    final want = 2 + rng.nextInt(largest - 1);
    final region = <int>[start];
    while (region.length < want) {
      final frontier = <int>{
        for (final cell in region)
          for (final next in near(cell))
            if (!region.contains(next)) next,
      }.toList();
      if (frontier.isEmpty) break;
      region.add(frontier[rng.nextInt(frontier.length)]);
    }
    regions.add(region);
    free.removeAll(region);
  }
  return regions;
}

// ---------------------------------------------------------------- Threads

Map<String, Object?>? _thread(Random rng, _Band band) {
  final rows = band.rows;
  final cols = band.cols;
  final blocked = _blocked(rng, rows, cols);
  final route = _hamilton(rows, cols, rng, blocked);
  if (route == null) return null;
  final longest = rows * cols >= 30 ? 6 + rng.nextInt(3) : 6;
  final pieces = <List<int>>[];
  var cursor = 0;
  while (cursor < route.length) {
    final remain = route.length - cursor;
    var length = 3 + rng.nextInt(longest - 2);
    if (remain - length < 3) length = remain;
    pieces.add(route.sublist(cursor, cursor + length));
    cursor += length;
  }
  if (pieces.length < 2 || pieces.length > 26) return null;
  final pairs = [
    for (var i = 0; i < pieces.length; i++)
      ThreadPair(
        label: String.fromCharCode(65 + i),
        a: pieces[i].first,
        b: pieces[i].last,
      ),
  ];
  final puzzle = ThreadPuzzle(
    rows: rows,
    cols: cols,
    pairs: pairs,
    blocked: blocked.toList(),
  );
  final geometry = ThreadGeometry(puzzle);
  if (!geometry.wellFormed) return null;
  final solved = solveThreads(
    geometry,
    limit: 2,
    nodeBudget: threadProofBudget,
  );
  if (solved.budgetExhausted || solved.solutions != 1) return null;
  List<int> cell(int index) => [index ~/ cols, index % cols];
  return {
    'rows': rows,
    'cols': cols,
    'pairs': [
      for (final pair in pairs)
        {'label': pair.label, 'a': cell(pair.a), 'b': cell(pair.b)},
    ],
    'blocked': [for (final index in blocked) cell(index)],
    'solution': [
      for (final piece in pieces) [for (final index in piece) cell(index)],
    ],
    'effort': threadEffort(puzzle),
  };
}

// --------------------------------------------------------------- Assembly

class _Chapter {
  const _Chapter(this.id, this.name, this.blurb);

  final String id;
  final String name;
  final String blurb;
}

const _campaignSize = 500;

/// One tier for each ten-chapter campaign, easiest first.
const _tiers = [
  'beginner',
  'easy',
  'medium',
  'medium',
  'hard',
  'hard',
  'expert',
  'expert',
  'master',
  'grandmaster',
];

const _parcelChapters = [
  _Chapter('dawn', 'Dawn', 'Small boards to learn how numbers compete.'),
  _Chapter('paper', 'Warm Paper', 'Most numbers now have more than one shape.'),
  _Chapter('terrace', 'Terrace', 'Numbers start to fight for squares.'),
  _Chapter('inkwell', 'Inkwell', 'Wider boards with fewer free moves.'),
  _Chapter('copper', 'Copper', 'A careless rectangle strands a number.'),
  _Chapter('lantern', 'Lantern', 'Several numbers stay open at once.'),
  _Chapter('keystone', 'Keystone', 'Each rectangle has to be earned.'),
  _Chapter('gallery', 'Gallery', 'Large boards with sparse numbers.'),
  _Chapter('vault', 'Vault', 'Deductions reach across the whole grid.'),
  _Chapter('archive', 'Night Archive', 'The largest and longest boards.'),
];

const _traceChapters = [
  _Chapter('first-step', 'First Step', 'Few numbers, even on small boards.'),
  _Chapter('straight-edge', 'Straight Edge', 'The path must plan its turns.'),
  _Chapter('courtyard', 'Courtyard', 'Corners trap a careless path.'),
  _Chapter('switchback', 'Switchback', 'Numbers are far apart.'),
  _Chapter('gallery', 'Gallery', 'More than one route looks right.'),
  _Chapter('lantern', 'Lantern', 'Long gaps between numbers.'),
  _Chapter('narrow', 'Narrow', 'Closed squares split the board.'),
  _Chapter('copper-path', 'Copper Path', 'Very few numbers to hold on to.'),
  _Chapter('vault-path', 'Vault Path', 'The order is the only guide.'),
  _Chapter('night-path', 'Night Path', 'The largest and sparsest paths.'),
];

const _inkChapters = [
  _Chapter('ink-dawn', 'Dawn Rooms', 'Small regions that already bend.'),
  _Chapter('ink-paper', 'Paper Rooms', 'Regions start to share borders.'),
  _Chapter('ink-terrace', 'Terrace Rooms', 'Bends are no longer optional.'),
  _Chapter('ink-inkwell', 'Inkwell Rooms', 'Regions share longer borders.'),
  _Chapter('ink-lantern', 'Lantern Rooms', 'Several shapes compete.'),
  _Chapter('ink-gallery', 'Gallery Rooms', 'Larger numbers and fewer ones.'),
  _Chapter('ink-copper', 'Copper Rooms', 'Every region depends on the next.'),
  _Chapter('ink-keystone', 'Keystone Rooms', 'Regions interlock.'),
  _Chapter('ink-vault', 'Vault Rooms', 'Little is forced by size alone.'),
  _Chapter('ink-night', 'Night Rooms', 'The largest rooms in the set.'),
];

const _threadChapters = [
  _Chapter('single-strand', 'Single Strand', 'Short paths with clear ends.'),
  _Chapter('crosshatch', 'Crosshatch', 'Paths bend around one another.'),
  _Chapter('loom', 'Loom', 'Longer threads and a few closed squares.'),
  _Chapter('warp', 'Warp', 'Threads have to share tight corners.'),
  _Chapter('weft', 'Weft', 'One wrong turn cuts a pair off.'),
  _Chapter('selvedge', 'Selvedge', 'The edges decide the middle.'),
  _Chapter('tapestry', 'Tapestry', 'Wide boards and long threads.'),
  _Chapter('brocade', 'Brocade', 'Few letters across a large board.'),
  _Chapter('lacework', 'Lacework', 'Every square is contested.'),
  _Chapter('gordian', 'Gordian', 'The longest threads in the set.'),
];

void _assemble() {
  final report = <String, Object?>{
    'schedule': 'rectora-daily-v1',
    'epoch': '2026-01-01',
    'uniqueness': 'solver limit 2, rejected unless exactly one solution',
  };
  report['parcels'] = _build(
    'parcels',
    'parcels',
    _parcelBands,
    _parcelChapters,
    'parcel',
    'Parcel',
  );
  report['traces'] = _build(
    'traces',
    'trace',
    _traceBands,
    _traceChapters,
    'trace',
    'Trace',
  );
  report['inks'] = _build(
    'inks',
    'inks',
    _inkBands,
    _inkChapters,
    'ink',
    'Inks',
  );
  report['threads'] = _build(
    'threads',
    'threads',
    _threadBands,
    _threadChapters,
    'thread',
    'Thread',
  );
  report['daily'] = _buildDaily();
  File('assets/levels/validation_report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  print(report);
}

/// Hardest boards of each size. A size that falls short passes its places to
/// the next smaller size, so the campaign still reaches its full count.
List<Map<String, Object?>> _select(String file, List<_Band> bands, int wanted) {
  final pool = [
    for (final line in File('build/campaign/$file.jsonl').readAsLinesSync())
      jsonDecode(line) as Map<String, Object?>,
  ];
  double rank(Map<String, Object?> level) =>
      ((level['rank'] ?? level['effort']) as num).toDouble();
  final bySize = <String, List<Map<String, Object?>>>{};
  for (final level in pool) {
    bySize
        .putIfAbsent('${level['rows']}x${level['cols']}', () => [])
        .add(level);
  }
  for (final list in bySize.values) {
    list.sort((a, b) => rank(b).compareTo(rank(a)));
  }
  final quota = {
    for (final band in bands) '${band.rows}x${band.cols}': band.keep,
  };
  final chosen = <Map<String, Object?>>[];
  int carry = wanted - quota.values.fold<int>(0, (sum, keep) => sum + keep);
  for (final band in bands.reversed) {
    final size = '${band.rows}x${band.cols}';
    final list = bySize[size] ?? const <Map<String, Object?>>[];
    final int take = min<int>(list.length, band.keep + max<int>(carry, 0));
    chosen.addAll(list.take(take));
    carry = carry + band.keep - take;
    print('$file $size: kept $take of ${list.length} (wanted ${band.keep})');
  }
  return chosen;
}

int _build(
  String file,
  String mode,
  List<_Band> bands,
  List<_Chapter> chapters,
  String prefix,
  String title,
) {
  final current =
      (jsonDecode(File('assets/levels/$file.json').readAsStringSync())
              as Map)['levels']
          as List;
  final lessons = [
    for (final level in current.cast<Map<String, Object?>>())
      if (level['tutorial'] == true) level,
  ];
  final chosen = _select(file, bands, _campaignSize - lessons.length)
    ..sort((a, b) => (a['effort'] as num).compareTo(b['effort'] as num));
  final ordered = [...lessons, ...chosen];
  final size = _campaignSize ~/ chapters.length;
  for (var i = 0; i < ordered.length; i++) {
    final number = i + 1;
    final index = min<int>(i ~/ size, chapters.length - 1);
    final chapter = chapters[index];
    ordered[i]
      ..['id'] = '$prefix-${number.toString().padLeft(3, '0')}'
      ..['number'] = number
      ..['title'] = '$title $number'
      ..['packId'] = chapter.id
      ..['packName'] = chapter.name
      ..['blurb'] = chapter.blurb
      ..['difficulty'] = i < 2 ? 'beginner' : _tiers[index]
      ..['tutorial'] = i < 2
      ..['milestone'] = number % size == 0;
    ordered[i]
      ..remove('effort')
      ..remove('rank');
  }
  File('assets/levels/$file.json').writeAsStringSync(
    jsonEncode({
      'format': 1,
      'game': 'rectora',
      'mode': mode,
      'levels': ordered,
    }),
  );
  print('$file: ${ordered.length}');
  return ordered.length;
}

int _buildDaily() {
  final chosen = _select('daily', _dailyBands, 120)..shuffle(Random(4242));
  for (var i = 0; i < chosen.length; i++) {
    final number = i + 1;
    chosen[i]
      ..['id'] = 'daily-${number.toString().padLeft(3, '0')}'
      ..['number'] = number
      ..['title'] = 'Day $number'
      ..['packId'] = 'daily'
      ..['packName'] = 'Daily'
      ..['blurb'] = 'One puzzle for each day.'
      ..['difficulty'] = 'hard'
      ..['tutorial'] = false
      ..['milestone'] = false;
    chosen[i]
      ..remove('effort')
      ..remove('rank');
  }
  File('assets/levels/daily.json').writeAsStringSync(
    jsonEncode({
      'format': 1,
      'game': 'rectora',
      'mode': 'parcels',
      'schedule': 'rectora-daily-v1',
      'epoch': '2026-01-01',
      'levels': chosen,
    }),
  );
  return chosen.length;
}
