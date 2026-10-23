import 'dart:isolate';

import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/parcels/session.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/trace/engine.dart';

/// Runs a parcel placement, including the hard-tier search, off the draw thread.
/// The returned issue is applied on the live session only when it is accepted.
Future<PlacementIssue> parcelPlacementAway({
  required ParcelPuzzle puzzle,
  required Strictness strictness,
  required List<GridRect> placed,
  required GridRect rect,
}) {
  final draft = List<GridRect>.from(placed);
  return Isolate.run(() {
    return ParcelSession(
      puzzle: puzzle,
      strictness: strictness,
      draft: draft,
    ).commit(rect);
  });
}

Future<ParcelHint> parcelHintAway({
  required ParcelPuzzle puzzle,
  required Strictness strictness,
  required List<GridRect> placed,
  required int hintsUsed,
}) {
  final draft = List<GridRect>.from(placed);
  return Isolate.run(() {
    return ParcelSession(
      puzzle: puzzle,
      strictness: strictness,
      draft: draft,
      hintsUsed: hintsUsed,
    ).proposeHint();
  });
}

Future<TraceHint> traceHintAway({
  required TracePuzzle puzzle,
  required List<int> path,
  required int hintsUsed,
}) {
  final draft = List<int>.from(path);
  return Isolate.run(() {
    return TraceSession(
      puzzle: puzzle,
      draft: draft,
      hintsUsed: hintsUsed,
    ).proposeHint();
  });
}

Future<InkHint> inkHintAway({
  required InkPuzzle puzzle,
  required List<InkRegion> placed,
  required int hintsUsed,
}) {
  final draft = [for (final region in placed) List<int>.from(region.cells)];
  return Isolate.run(() {
    return InkSession(
      puzzle: puzzle,
      draft: draft,
      hintsUsed: hintsUsed,
    ).proposeHint();
  });
}

Future<ThreadHint> threadHintAway({
  required ThreadPuzzle puzzle,
  required List<ThreadPath> placed,
  required int hintsUsed,
}) {
  final draft = [
    for (final path in placed)
      ThreadPath(pairIndex: path.pairIndex, cells: List<int>.from(path.cells)),
  ];
  return Isolate.run(() {
    return ThreadSession(
      puzzle: puzzle,
      draft: draft,
      hintsUsed: hintsUsed,
    ).proposeHint();
  });
}
