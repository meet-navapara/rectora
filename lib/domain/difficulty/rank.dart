import '../parcels/geometry.dart';
import '../parcels/models.dart';

/// Opening choices on an empty board. A clue with one rectangle is forced.
class OpeningProfile {
  const OpeningProfile({
    required this.forcedClues,
    required this.widestChoice,
    required this.choiceTotal,
    required this.clues,
    required this.cells,
  });

  final int forcedClues;
  final int widestChoice;
  final int choiceTotal;
  final int clues;
  final int cells;

  double get forcedRatio => clues == 0 ? 1 : forcedClues / clues;
}

OpeningProfile openingProfile(ParcelGeometry geometry) {
  var forced = 0;
  var widest = 0;
  var total = 0;
  for (final choices in geometry.choices) {
    total += choices.length;
    if (choices.length > widest) widest = choices.length;
    if (choices.length == 1) forced++;
  }
  return OpeningProfile(
    forcedClues: forced,
    widestChoice: widest,
    choiceTotal: total,
    clues: geometry.puzzle.clues.length,
    cells: geometry.puzzle.cellCount,
  );
}

/// Classifies a unique parcel from opening choices and the search that
/// proved uniqueness. A larger board is not enough for Grandmaster.
///
/// The solver must have found exactly one solution. Anything else is rejected
/// by the caller and is not given a tier.
Difficulty rankParcel({
  required OpeningProfile opening,
  required int nodes,
  required bool backtracked,
}) {
  if (opening.cells <= 16 && opening.forcedRatio >= 0.75 && nodes < 40) {
    return Difficulty.beginner;
  }
  if (opening.cells <= 25 && opening.widestChoice <= 4 && nodes < 90) {
    return Difficulty.easy;
  }
  if (!backtracked && nodes < 250 && opening.widestChoice < 8) {
    return Difficulty.medium;
  }
  if (nodes < 900 && opening.widestChoice < 12) return Difficulty.hard;
  if (nodes < 4000) return Difficulty.expert;
  if (nodes < 20000 && opening.widestChoice < 10) return Difficulty.master;
  return Difficulty.grandmaster;
}

/// Search that tried more than one rectangle for the first open clue
/// had to backtrack, even if a later clue was forced.
bool parcelSearchBacktracked(ParcelGeometry geometry, int nodes) {
  if (geometry.choices.isEmpty) return false;
  var smallest = geometry.choices.first.length;
  for (final choices in geometry.choices) {
    if (choices.length < smallest) smallest = choices.length;
  }
  return smallest > 1 && nodes > geometry.puzzle.clues.length + 1;
}
