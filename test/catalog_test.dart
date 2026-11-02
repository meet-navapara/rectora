import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/common/date_key.dart';
import 'package:rectora/domain/difficulty/effort.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/ui/screens/settings_page.dart' show rectoraVersion;

void main() {
  final parcels = File('assets/levels/parcels.json').readAsStringSync();
  final threads = File('assets/levels/threads.json').readAsStringSync();
  final daily = File('assets/levels/daily.json').readAsStringSync();
  final traces = File('assets/levels/traces.json').readAsStringSync();
  final inks = File('assets/levels/inks.json').readAsStringSync();
  final catalog = decodeCatalogs(
    parcelsJson: parcels,
    threadsJson: threads,
    dailyJson: daily,
    tracesJson: traces,
    inksJson: inks,
  );

  test('shipped catalogs match the validation report', () {
    expect(catalog.parcels, hasLength(500));
    expect(catalog.threads, hasLength(500));
    expect(catalog.traces, hasLength(500));
    expect(catalog.inks, hasLength(500));
    expect(catalog.daily, hasLength(120));
    expect(catalog.parcels.first.id, 'parcel-001');
    expect(catalog.parcels.last.id, 'parcel-500');
    expect(catalog.threads.last.id, 'thread-500');
    for (final chapters in [
      catalog.parcelChapters,
      catalog.tracePacks,
      catalog.inkPacks,
      catalog.packsFor(true),
    ]) {
      expect(chapters, hasLength(10));
      for (final chapter in chapters) {
        expect(chapter.levelIds, hasLength(50), reason: chapter.name);
      }
    }
  });

  test('measured effort never falls from one level to the next', () {
    void rising(String mode, List<double> efforts) {
      // The first two levels are lessons, so the ramp starts after them.
      for (var i = 3; i < efforts.length; i++) {
        expect(
          efforts[i],
          greaterThanOrEqualTo(efforts[i - 1]),
          reason: '$mode level ${i + 1}',
        );
      }
    }

    rising('parcels', [
      for (final level in catalog.parcels)
        parcelEffort(level.puzzle, level.solution).effort,
    ]);
    rising('traces', [
      for (final level in catalog.traces) traceEffort(level.puzzle),
    ]);
    rising('inks', [for (final level in catalog.inks) inkEffort(level.puzzle)]);
    rising('threads', [
      for (final level in catalog.threads) threadEffort(level.puzzle),
    ]);
  }, timeout: const Timeout(Duration(minutes: 8)));

  test('difficulty never drops as a campaign goes on', () {
    final campaigns = <String, List<(String, Difficulty, int)>>{
      'parcels': [
        for (final level in catalog.parcels)
          (level.id, level.difficulty, level.puzzle.rows * level.puzzle.cols),
      ],
      'traces': [
        for (final level in catalog.traces)
          (level.id, level.difficulty, level.puzzle.rows * level.puzzle.cols),
      ],
      'inks': [
        for (final level in catalog.inks)
          (level.id, level.difficulty, level.puzzle.rows * level.puzzle.cols),
      ],
      'threads': [
        for (final level in catalog.threads)
          (level.id, level.difficulty, level.puzzle.rows * level.puzzle.cols),
      ],
    };
    campaigns.forEach((mode, levels) {
      for (var i = 1; i < levels.length; i++) {
        expect(
          levels[i].$2.index,
          greaterThanOrEqualTo(levels[i - 1].$2.index),
          reason: '$mode ${levels[i].$1}',
        );
      }
      expect(levels.last.$2, Difficulty.grandmaster, reason: mode);
    });
    expect(catalog.parcels.first.puzzle.cellCount, lessThan(10));
  });

  test('chapters on the map match the chapter a level belongs to', () {
    for (final chapter in catalog.parcelChapters) {
      for (final id in chapter.levelIds) {
        expect(catalog.parcelById(id)!.packName, chapter.name);
      }
    }
  });

  test('no board repeats another after a rotation or a mirror', () {
    String key(int rows, int cols, Map<(int, int), String> cells) {
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
          final found = '$shape|${parts.join(',')}';
          if (best == null || found.compareTo(best) < 0) best = found;
        }
      }
      return best!;
    }

    void unique(Iterable<(String, String)> keyed) {
      final seen = <String, String>{};
      for (final (id, value) in keyed) {
        expect(seen[value], isNull, reason: '$id repeats ${seen[value]}');
        seen[value] = id;
      }
    }

    unique([
      for (final level in [...catalog.parcels, ...catalog.daily])
        (
          level.id,
          key(level.puzzle.rows, level.puzzle.cols, {
            for (final clue in level.puzzle.clues)
              (clue.row, clue.col): '${clue.value}',
          }),
        ),
    ]);
    unique([
      for (final level in catalog.inks)
        (
          level.id,
          key(level.puzzle.rows, level.puzzle.cols, {
            for (final clue in level.puzzle.clues)
              (clue.row, clue.col): '${clue.value}',
          }),
        ),
    ]);
    unique([
      for (final level in catalog.traces)
        (
          level.id,
          key(level.puzzle.rows, level.puzzle.cols, {
            for (var i = 0; i < level.puzzle.checkpoints.length; i++)
              (
                level.puzzle.checkpoints[i] ~/ level.puzzle.cols,
                level.puzzle.checkpoints[i] % level.puzzle.cols,
              ): '$i',
          }),
        ),
    ]);
    unique([
      for (final level in catalog.threads)
        (
          level.id,
          key(level.puzzle.rows, level.puzzle.cols, {
            for (final pair in level.puzzle.pairs) ...{
              (pair.a ~/ level.puzzle.cols, pair.a % level.puzzle.cols): 'p',
              (pair.b ~/ level.puzzle.cols, pair.b % level.puzzle.cols): 'p',
            },
            for (final cell in level.puzzle.blocked)
              (cell ~/ level.puzzle.cols, cell % level.puzzle.cols): 'x',
          }),
        ),
    ]);
  });

  test('the version in Settings matches pubspec', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((text) => text.startsWith('version:'));
    expect(line, contains('$rectoraVersion+'));
  });

  test('the same local date selects the same daily puzzle', () {
    final morning = DateTime(2026, 10, 21, 1);
    final evening = DateTime(2026, 10, 21, 23, 30);
    expect(
      catalog.dailyLevelFor(morning).id,
      catalog.dailyLevelFor(evening).id,
    );
    expect(
      catalog.dailyLevelFor(DateTime(2026, 10, 22)).id,
      isNot(catalog.dailyLevelFor(morning).id),
    );
    expect(
      dailyPoolIndex(morning, catalog.daily.length),
      inInclusiveRange(0, 119),
    );
  });

  test(
    'every shipped puzzle has one solution',
    () => proveCatalogUnique(catalog),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
