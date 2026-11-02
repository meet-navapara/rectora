import 'dart:convert';

import '../common/date_key.dart';
import '../ink/engine.dart';
import '../parcels/geometry.dart';
import '../parcels/models.dart';
import '../threads/engine.dart';
import '../threads/models.dart';
import '../trace/engine.dart';

const catalogFormat = 1;
const dailyScheduleId = 'rectora-daily-v1';

class ParcelLevel {
  const ParcelLevel({
    required this.id,
    required this.number,
    required this.packId,
    required this.packName,
    required this.packBlurb,
    required this.title,
    required this.difficulty,
    required this.milestone,
    required this.puzzle,
    required this.solution,
    this.tutorial = false,
  });

  final String id;
  final int number;
  final String packId;
  final String packName;
  final String packBlurb;
  final String title;
  final Difficulty difficulty;
  final bool milestone;
  final ParcelPuzzle puzzle;
  final List<GridRect> solution;

  /// True only when the level file marks this board as the mode's lesson.
  final bool tutorial;
}

class ThreadLevel {
  const ThreadLevel({
    required this.id,
    required this.number,
    required this.packId,
    required this.packName,
    required this.packBlurb,
    required this.title,
    required this.difficulty,
    required this.milestone,
    required this.puzzle,
    required this.solution,
    this.tutorial = false,
  });

  final String id;
  final int number;
  final String packId;
  final String packName;
  final String packBlurb;
  final String title;
  final Difficulty difficulty;
  final bool milestone;
  final ThreadPuzzle puzzle;
  final List<List<int>> solution;
  final bool tutorial;
}

class TraceLevel {
  const TraceLevel({
    required this.id,
    required this.number,
    required this.packId,
    required this.packName,
    required this.packBlurb,
    required this.title,
    required this.difficulty,
    required this.milestone,
    required this.puzzle,
    required this.solution,
    this.tutorial = false,
  });

  final String id;
  final int number;
  final String packId;
  final String packName;
  final String packBlurb;
  final String title;
  final Difficulty difficulty;
  final bool milestone;
  final TracePuzzle puzzle;
  final List<int> solution;
  final bool tutorial;
}

class InkLevel {
  const InkLevel({
    required this.id,
    required this.number,
    required this.packId,
    required this.packName,
    required this.packBlurb,
    required this.title,
    required this.difficulty,
    required this.milestone,
    required this.puzzle,
    required this.solution,
    this.tutorial = false,
  });

  final String id;
  final int number;
  final String packId;
  final String packName;
  final String packBlurb;
  final String title;
  final Difficulty difficulty;
  final bool milestone;
  final InkPuzzle puzzle;
  final List<List<int>> solution;
  final bool tutorial;
}

List<PackSummary> packGroups<T>(
  List<T> levels,
  String Function(T level) id,
  String Function(T level) packId,
  String Function(T level) name,
  String Function(T level) blurb,
) {
  final packs = <PackSummary>[];
  String? current;
  for (final level in levels) {
    if (packId(level) == current) continue;
    current = packId(level);
    packs.add(
      PackSummary(
        id: current,
        name: name(level),
        blurb: blurb(level),
        levelIds: [
          for (final item in levels)
            if (packId(item) == current) id(item),
        ],
      ),
    );
  }
  return packs;
}

class PackSummary {
  const PackSummary({
    required this.id,
    required this.name,
    required this.blurb,
    required this.levelIds,
  });

  final String id;
  final String name;
  final String blurb;
  final List<String> levelIds;
}

class GameCatalog {
  const GameCatalog({
    required this.parcels,
    required this.threads,
    required this.daily,
    this.traces = const [],
    this.inks = const [],
  });

  final List<ParcelLevel> parcels;
  final List<ThreadLevel> threads;
  final List<ParcelLevel> daily;
  final List<TraceLevel> traces;
  final List<InkLevel> inks;

  List<String> get parcelIds => [for (final level in parcels) level.id];
  List<String> get threadIds => [for (final level in threads) level.id];
  List<String> get traceIds => [for (final level in traces) level.id];
  List<String> get inkIds => [for (final level in inks) level.id];

  /// The level file names each chapter, so the map and the home screen agree.
  List<PackSummary> get parcelChapters => packsFor(false);

  List<PackSummary> get tracePacks => packGroups(
    traces,
    (level) => level.id,
    (level) => level.packId,
    (level) => level.packName,
    (level) => level.packBlurb,
  );

  List<PackSummary> get inkPacks => packGroups(
    inks,
    (level) => level.id,
    (level) => level.packId,
    (level) => level.packName,
    (level) => level.packBlurb,
  );

  List<PackSummary> packsFor(bool threads) {
    final packs = <PackSummary>[];
    String? current;
    if (threads) {
      for (final level in this.threads) {
        if (level.packId != current) {
          current = level.packId;
          packs.add(
            PackSummary(
              id: level.packId,
              name: level.packName,
              blurb: level.packBlurb,
              levelIds: [
                for (final item in this.threads)
                  if (item.packId == level.packId) item.id,
              ],
            ),
          );
        }
      }
    } else {
      for (final level in parcels) {
        if (level.packId != current) {
          current = level.packId;
          packs.add(
            PackSummary(
              id: level.packId,
              name: level.packName,
              blurb: level.packBlurb,
              levelIds: [
                for (final item in parcels)
                  if (item.packId == level.packId) item.id,
              ],
            ),
          );
        }
      }
    }
    return packs;
  }

  ParcelLevel? parcelById(String id) {
    for (final level in parcels) {
      if (level.id == id) return level;
    }
    return null;
  }

  ThreadLevel? threadById(String id) {
    for (final level in threads) {
      if (level.id == id) return level;
    }
    return null;
  }

  TraceLevel? traceById(String id) {
    for (final level in traces) {
      if (level.id == id) return level;
    }
    return null;
  }

  InkLevel? inkById(String id) {
    for (final level in inks) {
      if (level.id == id) return level;
    }
    return null;
  }

  ParcelLevel dailyLevelFor(DateTime local) {
    if (daily.isEmpty) {
      throw StateError('The daily schedule has no puzzles.');
    }
    final index = _dailyIndex(local, daily.length);
    return daily[index];
  }
}

int _dailyIndex(DateTime local, int length) => dailyPoolIndex(local, length);

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

GameCatalog decodeCatalogs({
  required String parcelsJson,
  required String threadsJson,
  required String dailyJson,
  String? tracesJson,
  String? inksJson,
}) {
  final parcels = _decodeParcels(parcelsJson, 'parcels');
  final threads = _decodeThreads(threadsJson);
  final daily = _decodeParcels(dailyJson, 'daily');
  final traces = tracesJson == null
      ? <TraceLevel>[]
      : _decodeTraces(tracesJson);
  final inks = inksJson == null ? <InkLevel>[] : _decodeInks(inksJson);
  _rejectDuplicateIds([
    ...parcels.map((level) => level.id),
    ...threads.map((level) => level.id),
    ...traces.map((level) => level.id),
    ...inks.map((level) => level.id),
  ]);
  return GameCatalog(
    parcels: parcels,
    threads: threads,
    daily: daily,
    traces: traces,
    inks: inks,
  );
}

List<ParcelLevel> _decodeParcels(String raw, String label) {
  final root = _object(jsonDecode(raw), label);
  if (root['format'] != catalogFormat || root['mode'] != 'parcels') {
    throw CatalogException('$label uses an unsupported catalog format.');
  }
  final levels = root['levels'];
  if (levels is! List || levels.isEmpty) {
    throw CatalogException('$label does not contain any levels.');
  }
  final decoded = <ParcelLevel>[];
  final seen = <String>{};
  for (final entry in levels) {
    if (entry is! Map) {
      throw CatalogException('A $label level is not an object.');
    }
    final json = Map<String, Object?>.from(entry);
    final level = _parcelLevel(json);
    if (!seen.add(level.id)) {
      throw CatalogException('Duplicate level id ${level.id}.');
    }
    _validateParcel(level);
    decoded.add(level);
  }
  for (var i = 0; i < decoded.length; i++) {
    if (decoded[i].number != i + 1) {
      throw CatalogException('$label numbers must be contiguous from 1.');
    }
  }
  return decoded;
}

List<ThreadLevel> _decodeThreads(String raw) {
  final root = _object(jsonDecode(raw), 'threads');
  if (root['format'] != catalogFormat || root['mode'] != 'threads') {
    throw CatalogException('Threads uses an unsupported catalog format.');
  }
  final levels = root['levels'];
  if (levels is! List || levels.isEmpty) {
    throw CatalogException('Threads does not contain any levels.');
  }
  final decoded = <ThreadLevel>[];
  for (final entry in levels) {
    if (entry is! Map) {
      throw CatalogException('A thread level is not an object.');
    }
    final level = _threadLevel(Map<String, Object?>.from(entry));
    _validateThread(level);
    decoded.add(level);
  }
  for (var i = 0; i < decoded.length; i++) {
    if (decoded[i].number != i + 1) {
      throw CatalogException('Thread numbers must be contiguous from 1.');
    }
  }
  return decoded;
}

void _validateParcel(ParcelLevel level) {
  final geometry = ParcelGeometry(level.puzzle);
  if (!geometry.wellFormed) {
    throw CatalogException('${level.id} is malformed: ${geometry.problem}');
  }
  if (!exactCover(geometry, level.solution)) {
    throw CatalogException('${level.id} solution does not cover the board.');
  }
}

void _validateThread(ThreadLevel level) {
  final geometry = ThreadGeometry(level.puzzle);
  if (!geometry.wellFormed) {
    throw CatalogException('${level.id} is malformed: ${geometry.problem}');
  }
  final paths = <ThreadPath>[
    for (var i = 0; i < level.solution.length; i++)
      ThreadPath(pairIndex: i, cells: level.solution[i]),
  ];
  if (!threadsComplete(geometry, paths)) {
    throw CatalogException('${level.id} solution does not complete the board.');
  }
}

/// Re-solves every campaign and daily puzzle. Used by tests and the generator,
/// not during application startup.
void proveCatalogUnique(GameCatalog catalog) {
  for (final level in [...catalog.parcels, ...catalog.daily]) {
    final geometry = ParcelGeometry(level.puzzle);
    final cells = level.puzzle.rows * level.puzzle.cols;
    final solved = solveParcels(
      geometry,
      limit: 2,
      nodeBudget: cells >= 56 ? 400000 : 180000,
    );
    if (solved.budgetExhausted || solved.solutions != 1) {
      throw CatalogException(
        '${level.id} uniqueness check failed '
        '(solutions=${solved.solutions}, budget=${solved.budgetExhausted}).',
      );
    }
    final found = solved.solution!.toSet();
    if (found.length != level.solution.length ||
        !found.containsAll(level.solution)) {
      throw CatalogException(
        '${level.id} stored solution does not match the solver.',
      );
    }
  }
  for (final level in catalog.traces) {
    final geometry = TraceGeometry(level.puzzle);
    final solved = solveTrace(geometry, limit: 2, nodeBudget: 120000);
    if (solved.budgetExhausted || solved.solutions != 1) {
      throw CatalogException(
        '${level.id} uniqueness check failed '
        '(solutions=${solved.solutions}, budget=${solved.budgetExhausted}).',
      );
    }
    if (!_samePath(solved.solution, level.solution)) {
      throw CatalogException(
        '${level.id} stored path does not match the solver.',
      );
    }
  }
  for (final level in catalog.inks) {
    final geometry = InkGeometry(level.puzzle);
    final solved = solveInks(geometry, limit: 2, nodeBudget: 120000);
    if (solved.budgetExhausted ||
        solved.solutions != 1 ||
        solved.solution == null) {
      throw CatalogException(
        '${level.id} uniqueness check failed '
        '(solutions=${solved.solutions}, budget=${solved.budgetExhausted}).',
      );
    }
    if (!geometry.complete([
      for (final cells in level.solution) InkRegion(cells),
    ])) {
      throw CatalogException('${level.id} solution does not cover the board.');
    }
  }
  for (final level in catalog.threads) {
    final geometry = ThreadGeometry(level.puzzle);
    final solved = solveThreads(geometry, limit: 2, nodeBudget: 180000);
    if (solved.budgetExhausted || solved.solutions != 1) {
      throw CatalogException(
        '${level.id} uniqueness check failed '
        '(solutions=${solved.solutions}, budget=${solved.budgetExhausted}).',
      );
    }
  }
}

bool _samePath(List<int>? found, List<int> stored) {
  if (found == null || found.length != stored.length) return false;
  for (var i = 0; i < found.length; i++) {
    if (found[i] != stored[i]) return false;
  }
  return true;
}

List<TraceLevel> _decodeTraces(String raw) {
  final root = _object(jsonDecode(raw), 'traces');
  if (root['format'] != catalogFormat || root['mode'] != 'trace') {
    throw CatalogException('Trace uses an unsupported catalog format.');
  }
  final levels = root['levels'];
  if (levels is! List || levels.isEmpty) {
    throw CatalogException('Trace does not contain any levels.');
  }
  final decoded = <TraceLevel>[];
  for (final entry in levels) {
    if (entry is! Map) {
      throw CatalogException('A trace level is not an object.');
    }
    decoded.add(_traceLevel(Map<String, Object?>.from(entry)));
  }
  for (var i = 0; i < decoded.length; i++) {
    if (decoded[i].number != i + 1) {
      throw CatalogException('Trace numbers must be contiguous from 1.');
    }
    final geometry = TraceGeometry(decoded[i].puzzle);
    if (!geometry.wellFormed || !geometry.complete(decoded[i].solution)) {
      throw CatalogException(
        '${decoded[i].id} solution does not cover the board.',
      );
    }
  }
  return decoded;
}

List<InkLevel> _decodeInks(String raw) {
  final root = _object(jsonDecode(raw), 'inks');
  if (root['format'] != catalogFormat || root['mode'] != 'inks') {
    throw CatalogException('Inks uses an unsupported catalog format.');
  }
  final levels = root['levels'];
  if (levels is! List || levels.isEmpty) {
    throw CatalogException('Inks does not contain any levels.');
  }
  final decoded = <InkLevel>[];
  for (final entry in levels) {
    if (entry is! Map) {
      throw CatalogException('An inks level is not an object.');
    }
    decoded.add(_inkLevel(Map<String, Object?>.from(entry)));
  }
  for (var i = 0; i < decoded.length; i++) {
    if (decoded[i].number != i + 1) {
      throw CatalogException('Inks numbers must be contiguous from 1.');
    }
    final geometry = InkGeometry(decoded[i].puzzle);
    if (!geometry.wellFormed ||
        !geometry.complete([
          for (final cells in decoded[i].solution) InkRegion(cells),
        ])) {
      throw CatalogException(
        '${decoded[i].id} solution does not cover the board.',
      );
    }
  }
  return decoded;
}

TraceLevel _traceLevel(Map<String, Object?> json) {
  final cols = _int(json['cols']);
  return TraceLevel(
    id: _string(json['id']),
    number: _int(json['number']),
    packId: _string(json['packId']),
    packName: _string(json['packName']),
    packBlurb: _string(json['blurb']),
    title: _string(json['title']),
    difficulty: _difficulty(json['difficulty']),
    milestone: json['milestone'] == true,
    tutorial: json['tutorial'] == true,
    puzzle: TracePuzzle(
      rows: _int(json['rows']),
      cols: cols,
      checkpoints: _cells(json['checkpoints'], cols),
      blocked: _cells(json['blocked'], cols),
    ),
    solution: _cells(json['solution'], cols),
  );
}

InkLevel _inkLevel(Map<String, Object?> json) {
  final cols = _int(json['cols']);
  final clues = _matrix(json['clues'], 3, 'clue');
  final solutionRaw = json['solution'];
  if (solutionRaw is! List || solutionRaw.isEmpty) {
    throw CatalogException('An inks solution is missing.');
  }
  final solution = <List<int>>[];
  for (final region in solutionRaw) {
    solution.add(_cells(region, cols));
  }
  return InkLevel(
    id: _string(json['id']),
    number: _int(json['number']),
    packId: _string(json['packId']),
    packName: _string(json['packName']),
    packBlurb: _string(json['blurb']),
    title: _string(json['title']),
    difficulty: _difficulty(json['difficulty']),
    milestone: json['milestone'] == true,
    tutorial: json['tutorial'] == true,
    puzzle: InkPuzzle(
      rows: _int(json['rows']),
      cols: cols,
      clues: [for (final clue in clues) Clue.fromList(clue)],
    ),
    solution: solution,
  );
}

List<int> _cells(Object? raw, int cols) {
  if (raw is! List) throw CatalogException('Expected a list of cells.');
  return [
    for (final entry in raw)
      if (entry is List && entry.length == 2)
        _int(entry[0]) * cols + _int(entry[1])
      else
        throw CatalogException('A cell needs a row and column.'),
  ];
}

ParcelLevel _parcelLevel(Map<String, Object?> json) {
  final clues = _matrix(json['clues'], 3, 'clue');
  final solution = _matrix(json['solution'], 4, 'rectangle');
  return ParcelLevel(
    id: _string(json['id']),
    number: _int(json['number']),
    packId: _string(json['packId']),
    packName: _string(json['packName']),
    packBlurb: _string(json['blurb']),
    title: _string(json['title']),
    difficulty: _difficulty(json['difficulty']),
    milestone: json['milestone'] == true,
    tutorial: json['tutorial'] == true,
    puzzle: ParcelPuzzle(
      rows: _int(json['rows']),
      cols: _int(json['cols']),
      clues: [for (final clue in clues) Clue.fromList(clue)],
    ),
    solution: [for (final rect in solution) GridRect.fromList(rect)],
  );
}

ThreadLevel _threadLevel(Map<String, Object?> json) {
  final pairsRaw = json['pairs'];
  if (pairsRaw is! List || pairsRaw.isEmpty) {
    throw CatalogException('A thread level needs pairs.');
  }
  final pairs = <ThreadPair>[];
  final cols = _int(json['cols']);
  for (final entry in pairsRaw) {
    if (entry is! Map) throw CatalogException('A pair is not an object.');
    final pair = Map<String, Object?>.from(entry);
    final a = pair['a'];
    final b = pair['b'];
    if (a is! List || b is! List || a.length != 2 || b.length != 2) {
      throw CatalogException('A pair needs two endpoints.');
    }
    pairs.add(
      ThreadPair(
        label: _string(pair['label']),
        a: _int(a[0]) * cols + _int(a[1]),
        b: _int(b[0]) * cols + _int(b[1]),
      ),
    );
  }
  final blockedRaw = json['blocked'];
  final blocked = <int>[];
  if (blockedRaw is List) {
    for (final entry in blockedRaw) {
      if (entry is! List || entry.length != 2) {
        throw CatalogException('A blocked cell needs a row and column.');
      }
      blocked.add(_int(entry[0]) * cols + _int(entry[1]));
    }
  }
  final solutionRaw = json['solution'];
  if (solutionRaw is! List) {
    throw CatalogException('A thread solution is missing.');
  }
  final solution = <List<int>>[];
  for (final path in solutionRaw) {
    if (path is! List) throw CatalogException('A thread path is not a list.');
    solution.add([
      for (final step in path)
        if (step is List && step.length == 2)
          _int(step[0]) * cols + _int(step[1])
        else
          throw CatalogException('A path step needs a row and column.'),
    ]);
  }
  return ThreadLevel(
    id: _string(json['id']),
    number: _int(json['number']),
    packId: _string(json['packId']),
    packName: _string(json['packName']),
    packBlurb: _string(json['blurb']),
    title: _string(json['title']),
    difficulty: _difficulty(json['difficulty']),
    milestone: json['milestone'] == true,
    tutorial: json['tutorial'] == true,
    puzzle: ThreadPuzzle(
      rows: _int(json['rows']),
      cols: cols,
      pairs: pairs,
      blocked: blocked,
    ),
    solution: solution,
  );
}

void _rejectDuplicateIds(List<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) throw CatalogException('Duplicate level id $id.');
  }
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map) throw CatalogException('$label catalog is not an object.');
  return Map<String, Object?>.from(value);
}

List<List<int>> _matrix(Object? raw, int width, String label) {
  if (raw is! List || raw.isEmpty) {
    throw CatalogException('Missing $label list.');
  }
  return [
    for (final entry in raw)
      if (entry is List &&
          entry.length == width &&
          entry.every((v) => v is int))
        [for (final value in entry) value as int]
      else
        throw CatalogException('Bad $label entry.'),
  ];
}

String _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw CatalogException('Missing text in level data.');
}

int _int(Object? value) {
  if (value is int) return value;
  throw CatalogException('Missing number in level data.');
}

Difficulty _difficulty(Object? value) {
  for (final difficulty in Difficulty.values) {
    if (difficulty.name == value) return difficulty;
  }
  throw CatalogException('Unknown difficulty: $value');
}

String encodeCatalog(Object root) =>
    const JsonEncoder.withIndent('  ').convert(root);
