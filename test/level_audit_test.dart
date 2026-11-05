import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/trace/engine.dart';

void main() {
  final catalog = decodeCatalogs(
    parcelsJson: File('assets/levels/parcels.json').readAsStringSync(),
    threadsJson: File('assets/levels/threads.json').readAsStringSync(),
    dailyJson: File('assets/levels/daily.json').readAsStringSync(),
    tracesJson: File('assets/levels/traces.json').readAsStringSync(),
    inksJson: File('assets/levels/inks.json').readAsStringSync(),
  );

  test('every trace level is won only when every open square is used', () {
    for (final level in catalog.traces) {
      final puzzle = level.puzzle;
      final geometry = TraceGeometry(puzzle);
      expect(geometry.wellFormed, isTrue, reason: level.id);
      final solved = solveTrace(geometry, limit: 1, nodeBudget: 5000000);
      final route = solved.solution;
      expect(route, isNotNull, reason: level.id);
      final closed = puzzle.blocked.toSet();
      expect(route!.toSet().intersection(closed), isEmpty, reason: level.id);
      expect(
        route.length + closed.length,
        puzzle.cellCount,
        reason: '${level.id} leaves an open square unused',
      );

      final session = TraceSession(puzzle: puzzle);
      for (final cell in route) {
        expect(session.dragTo(cell), TraceIssue.ok, reason: level.id);
        if (session.path.length < route.length) {
          expect(session.isComplete, isFalse, reason: level.id);
        }
      }
      expect(session.isComplete, isTrue, reason: level.id);
      for (final cell in closed) {
        expect(TraceSession(puzzle: puzzle).extend(cell), isNot(TraceIssue.ok));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  test('trace boards with closed squares include trace-052', () {
    final withClosed = catalog.traces
        .where((level) => level.puzzle.blocked.isNotEmpty)
        .toList();
    expect(withClosed, isNotEmpty);
    expect(withClosed.map((level) => level.id), contains('trace-052'));
  });

}
