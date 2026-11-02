import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/parcels/geometry.dart';

void main() {
  final catalog = decodeCatalogs(
    parcelsJson: File('assets/levels/parcels.json').readAsStringSync(),
    threadsJson: File('assets/levels/threads.json').readAsStringSync(),
    dailyJson: File('assets/levels/daily.json').readAsStringSync(),
    tracesJson: File('assets/levels/traces.json').readAsStringSync(),
    inksJson: File('assets/levels/inks.json').readAsStringSync(),
  );

  test('the first two levels of every mode are guided lessons', () {
    expect(catalog.parcels[0].tutorial, isTrue);
    expect(catalog.parcels[1].tutorial, isTrue);
    expect(catalog.parcels[0].solution.length, greaterThan(1));
    expect(catalog.traces[0].tutorial, isTrue);
    expect(catalog.traces[1].tutorial, isTrue);
    expect(catalog.traces[0].solution.length, greaterThan(3));
    expect(catalog.inks[0].tutorial, isTrue);
    expect(catalog.inks[1].tutorial, isTrue);
    expect(catalog.inks[0].solution.length, greaterThan(1));
    expect(catalog.threads[0].tutorial, isTrue);
    expect(catalog.threads[1].tutorial, isTrue);
    expect(catalog.threads[0].solution.length, greaterThan(1));
  });

  test('parcels 1-100 are unique and rise in tier', () {
    final seen = <String>{};
    final ranks = <int>[];
    for (final level in catalog.parcels.take(100)) {
      final clues = [
        for (final clue in level.puzzle.clues)
          '${clue.row}:${clue.col}:${clue.value}',
      ]..sort();
      final key =
          '${level.puzzle.rows}x${level.puzzle.cols}:${clues.join('|')}';
      expect(seen.add(key), isTrue, reason: level.id);
      final geometry = ParcelGeometry(level.puzzle);
      expect(geometry.wellFormed, isTrue, reason: level.id);
      expect(exactCover(geometry, level.solution), isTrue, reason: level.id);
      final solved = solveParcels(geometry, limit: 2, nodeBudget: 180000);
      expect(solved.budgetExhausted, isFalse, reason: level.id);
      expect(solved.solutions, 1, reason: level.id);
      ranks.add(level.difficulty.index);
    }
    double meanRank(int start, int end) {
      var total = 0.0;
      for (var i = start; i < end; i++) {
        total += ranks[i];
      }
      return total / (end - start);
    }

    expect(meanRank(75, 100), greaterThan(meanRank(2, 10)));
    expect(catalog.parcels.length, 500);
  });
}
