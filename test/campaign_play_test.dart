import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/parcels/session.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/trace/engine.dart';

/// Plays the shipped levels through the same sessions the screens use, so a
/// board that a player could never finish, or that a hint cannot help with,
/// fails here rather than in the store.
void main() {
  String read(String name) =>
      File('assets/levels/$name.json').readAsStringSync();
  final catalog = decodeCatalogs(
    parcelsJson: read('parcels'),
    threadsJson: read('threads'),
    dailyJson: read('daily'),
    tracesJson: read('traces'),
    inksJson: read('inks'),
  );

  /// The first and last level of each chapter, where sizes change most.
  Iterable<T> sample<T>(List<T> levels) sync* {
    for (var i = 0; i < levels.length; i++) {
      if (i % 50 == 0 || i % 50 == 49) yield levels[i];
    }
  }

  test('every parcel and daily level can be finished by playing it', () {
    for (final level in [...catalog.parcels, ...catalog.daily]) {
      final session = ParcelSession(
        puzzle: level.puzzle,
        strictness: strictnessFor(level.difficulty),
      );
      for (final rect in level.solution) {
        expect(session.commit(rect), PlacementIssue.ok, reason: level.id);
      }
      expect(session.isComplete, isTrue, reason: level.id);
    }
  });

  test('every trace level can be finished by playing it', () {
    for (final level in catalog.traces) {
      final session = TraceSession(puzzle: level.puzzle);
      for (final cell in level.solution) {
        expect(session.dragTo(cell), TraceIssue.ok, reason: level.id);
      }
      expect(session.isComplete, isTrue, reason: level.id);
    }
  });

  test('every inks level can be finished by playing it', () {
    for (final level in catalog.inks) {
      final session = InkSession(puzzle: level.puzzle);
      for (final cells in level.solution) {
        expect(session.commit(cells), InkIssue.ok, reason: level.id);
      }
      expect(session.isComplete, isTrue, reason: level.id);
    }
  });

  test('every thread level can be finished by playing it', () {
    for (final level in catalog.threads) {
      final session = ThreadSession(puzzle: level.puzzle);
      for (final cells in level.solution) {
        expect(session.commit(cells), ThreadIssue.ok, reason: level.id);
      }
      expect(session.isComplete, isTrue, reason: level.id);
    }
  });

  test('a wrong but legal move is accepted, then a hint reports it', () {
    final hard = catalog.parcels.last;
    final session = ParcelSession(
      puzzle: hard.puzzle,
      strictness: strictnessFor(hard.difficulty),
    );
    GridRect? wrong;
    for (final clue in hard.puzzle.clues) {
      for (var height = 1; height <= clue.value && wrong == null; height++) {
        if (clue.value % height != 0) continue;
        final rect = GridRect(
          clue.row,
          clue.col,
          clue.row + height - 1,
          clue.col + clue.value ~/ height - 1,
        );
        if (hard.solution.contains(rect)) continue;
        if (session.commit(rect) == PlacementIssue.ok) wrong = rect;
      }
      if (wrong != null) break;
    }
    expect(wrong, isNotNull, reason: 'no legal wrong rectangle was found');
    expect(session.placed, contains(wrong));
    expect(session.proposeHint().kind, ParcelHintKind.deadEnd);
  });

  test('a hint gives a real step on the hardest boards of every chapter', () {
    for (final level in sample(catalog.parcels)) {
      final hint = ParcelSession(
        puzzle: level.puzzle,
        strictness: strictnessFor(level.difficulty),
      ).proposeHint();
      expect(hint.placesARectangle, isTrue, reason: level.id);
    }
    for (final level in sample(catalog.traces)) {
      final session = TraceSession(puzzle: level.puzzle);
      session.dragTo(level.solution.first);
      expect(
        session.proposeHint().kind,
        isNot(TraceHintKind.deadEnd),
        reason: level.id,
      );
    }
    for (final level in sample(catalog.inks)) {
      expect(
        InkSession(puzzle: level.puzzle).proposeHint().kind,
        InkHintKind.forced,
        reason: level.id,
      );
    }
    for (final level in sample(catalog.threads)) {
      expect(
        ThreadSession(puzzle: level.puzzle).proposeHint().kind,
        ThreadHintKind.required,
        reason: level.id,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
