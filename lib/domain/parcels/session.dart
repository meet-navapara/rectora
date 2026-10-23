import 'bits.dart';
import 'geometry.dart';
import 'models.dart';

sealed class GridEdit {
  const GridEdit();
}

class AddRect extends GridEdit {
  const AddRect(this.rect);
  final GridRect rect;
}

class RemoveRect extends GridEdit {
  const RemoveRect(this.rect);
  final GridRect rect;
}

class ReplaceAll extends GridEdit {
  const ReplaceAll(this.previous);
  final List<GridRect> previous;
}

enum ParcelHintKind { forced, required, ambiguous, deadEnd }

class ParcelHint {
  const ParcelHint({
    required this.kind,
    this.rect,
    this.clueIndex,
    this.candidateCount = 0,
  });

  final ParcelHintKind kind;
  final GridRect? rect;
  final int? clueIndex;
  final int candidateCount;

  bool get placesARectangle =>
      rect != null &&
      (kind == ParcelHintKind.forced || kind == ParcelHintKind.required);
}

/// Play session for one parcel puzzle. The geometry engine accepts or
/// rejects every change; the undo stack stores those accepted rectangles.
class ParcelSession {
  ParcelSession({
    required this.puzzle,
    required this.strictness,
    List<GridRect>? draft,
    this.hintsUsed = 0,
  }) : geometry = ParcelGeometry(puzzle) {
    if (!geometry.wellFormed || draft == null) return;
    final restored = <GridRect>[];
    var occupied = Bits.zero;
    for (final rect in draft) {
      final assessment = geometry.assess(
        rect,
        occupied,
        strictness: Strictness.basic,
      );
      if (!assessment.accepted ||
          assessment.rect == null ||
          assessment.mask == null) {
        discardedDraft = true;
        return;
      }
      restored.add(assessment.rect!);
      occupied = occupied.union(assessment.mask!);
    }
    _placed.addAll(restored);
  }

  final ParcelPuzzle puzzle;
  final Strictness strictness;
  final ParcelGeometry geometry;
  int hintsUsed;
  bool discardedDraft = false;

  final List<GridRect> _placed = [];
  final List<GridEdit> _undo = [];
  final List<GridEdit> _redo = [];
  bool _rewardClaimed = false;

  List<GridRect> get placed => List.unmodifiable(_placed);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isComplete => exactCover(geometry, _placed);

  PlacementAssessment preview(GridRect rect, {Strictness? strictness}) {
    return geometry.assess(
      rect,
      occupancyOf(geometry, _placed),
      strictness: strictness ?? this.strictness,
    );
  }

  PlacementIssue commit(
    GridRect rect, {
    bool? solveDeadEnds,
    Strictness? rules,
  }) {
    final applied = rules ?? strictness;
    final assessment = geometry.assess(
      rect,
      occupancyOf(geometry, _placed),
      strictness: applied,
      solveDeadEnds: solveDeadEnds ?? applied == Strictness.solvable,
    );
    if (!assessment.accepted || assessment.rect == null) {
      return assessment.issue;
    }
    _placed.add(assessment.rect!);
    _remember(AddRect(assessment.rect!));
    return PlacementIssue.ok;
  }

  bool eraseAt(int row, int col) {
    final index = _placed.indexWhere((rect) => rect.containsCell(row, col));
    if (index < 0) return false;
    final rect = _placed.removeAt(index);
    _remember(RemoveRect(rect));
    return true;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final edit = _undo.removeLast();
    _invert(edit);
    _redo.add(edit);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final edit = _redo.removeLast();
    _apply(edit);
    _undo.add(edit);
    return true;
  }

  void restart() {
    if (_placed.isEmpty) return;
    _remember(ReplaceAll(List<GridRect>.from(_placed)));
    _placed.clear();
  }

  void _remember(GridEdit edit) {
    _undo.add(edit);
    _redo.clear();
  }

  void _apply(GridEdit edit) {
    switch (edit) {
      case AddRect(:final rect):
        _placed.add(rect);
      case RemoveRect(:final rect):
        _placed.remove(rect);
      case ReplaceAll():
        _placed.clear();
    }
  }

  void _invert(GridEdit edit) {
    switch (edit) {
      case AddRect(:final rect):
        _placed.remove(rect);
      case RemoveRect(:final rect):
        _placed.add(rect);
      case ReplaceAll(:final previous):
        _placed
          ..clear()
          ..addAll(previous);
    }
  }

  /// True only the first time the finished board is claimed.
  bool claimCompletion() {
    if (_rewardClaimed || !isComplete) return false;
    _rewardClaimed = true;
    return true;
  }

  ParcelHint proposeHint() {
    if (!geometry.wellFormed) {
      return const ParcelHint(kind: ParcelHintKind.deadEnd);
    }
    final occupied = occupancyOf(geometry, _placed);
    final covered = <int>{};
    for (final rect in _placed) {
      final match = geometry.choiceMatching(rect);
      if (match != null) covered.add(match.clueIndex);
    }

    var fewest = 1 << 30;
    var fewestIndex = -1;
    RegionChoice? forced;
    for (var i = 0; i < puzzle.clues.length; i++) {
      if (covered.contains(i)) continue;
      final feasible = <RegionChoice>[];
      for (final choice in geometry.choices[i]) {
        if (!occupied.intersects(choice.mask)) feasible.add(choice);
      }
      if (feasible.length == 1 && forced == null) {
        forced = feasible.single;
      }
      if (feasible.length < fewest) {
        fewest = feasible.length;
        fewestIndex = i;
      }
    }

    final solved = solveParcels(
      geometry,
      occupied: occupied,
      placedClues: covered,
      limit: 2,
      nodeBudget: 250000,
    );
    if (!solved.budgetExhausted && solved.solutions == 0) {
      return ParcelHint(kind: ParcelHintKind.deadEnd, clueIndex: fewestIndex);
    }
    if (forced != null && !solved.budgetExhausted && solved.solutions >= 1) {
      return ParcelHint(
        kind: ParcelHintKind.forced,
        rect: forced.rect,
        clueIndex: forced.clueIndex,
        candidateCount: 1,
      );
    }
    if (!solved.budgetExhausted &&
        solved.solutions == 1 &&
        solved.solution != null &&
        solved.solution!.isNotEmpty) {
      GridRect? bestRect;
      var bestCount = 1 << 30;
      var bestClue = -1;
      for (final rect in solved.solution!) {
        final match = geometry.choiceMatching(rect);
        if (match == null || covered.contains(match.clueIndex)) continue;
        var count = 0;
        for (final choice in geometry.choices[match.clueIndex]) {
          if (!occupied.intersects(choice.mask)) count++;
        }
        if (count < bestCount) {
          bestCount = count;
          bestRect = rect;
          bestClue = match.clueIndex;
        }
      }
      if (bestRect != null) {
        return ParcelHint(
          kind: ParcelHintKind.required,
          rect: bestRect,
          clueIndex: bestClue,
          candidateCount: bestCount,
        );
      }
    }
    return ParcelHint(
      kind: ParcelHintKind.ambiguous,
      clueIndex: fewestIndex < 0 ? null : fewestIndex,
      candidateCount: fewest == 1 << 30 ? 0 : fewest,
    );
  }

  /// Applies a hint only when the engine accepts the rectangle.
  bool applyHint(ParcelHint hint) {
    if (!hint.placesARectangle || hint.rect == null) return false;
    final issue = commit(hint.rect!);
    if (issue != PlacementIssue.ok) return false;
    hintsUsed++;
    return true;
  }
}
