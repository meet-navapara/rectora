import 'bits.dart';

enum Difficulty { beginner, easy, medium, hard, expert, master, grandmaster }

enum Strictness { basic, forward, solvable }

/// Every tier uses the plain rules. Refusing a legal move because it leads
/// nowhere would tell the player which moves are right.
Strictness strictnessFor(Difficulty difficulty) => Strictness.basic;

extension DifficultyLabel on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.beginner:
        return 'Beginner';
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
      case Difficulty.expert:
        return 'Expert';
      case Difficulty.master:
        return 'Master';
      case Difficulty.grandmaster:
        return 'Grandmaster';
    }
  }
}

/// Inclusive rectangle. [GridRect.fromCorners] normalizes any drag direction.
class GridRect {
  const GridRect(this.r1, this.c1, this.r2, this.c2);

  factory GridRect.fromCorners(int r1, int c1, int r2, int c2) {
    final top = r1 < r2 ? r1 : r2;
    final bottom = r1 < r2 ? r2 : r1;
    final left = c1 < c2 ? c1 : c2;
    final right = c1 < c2 ? c2 : c1;
    return GridRect(top, left, bottom, right);
  }

  factory GridRect.fromList(List<dynamic> values) {
    if (values.length != 4) {
      throw FormatException('A rectangle needs four coordinates.');
    }
    return GridRect(
      _asInt(values[0]),
      _asInt(values[1]),
      _asInt(values[2]),
      _asInt(values[3]),
    );
  }

  final int r1;
  final int c1;
  final int r2;
  final int c2;

  int get width => c2 - c1 + 1;
  int get height => r2 - r1 + 1;
  int get area => width * height;

  bool containsCell(int row, int col) =>
      row >= r1 && row <= r2 && col >= c1 && col <= c2;

  bool overlaps(GridRect other) =>
      r1 <= other.r2 && other.r1 <= r2 && c1 <= other.c2 && other.c1 <= c2;

  bool inside(int rows, int cols) =>
      r1 >= 0 && c1 >= 0 && r2 < rows && c2 < cols && r1 <= r2 && c1 <= c2;

  List<int> toList() => [r1, c1, r2, c2];

  @override
  bool operator ==(Object other) =>
      other is GridRect &&
      other.r1 == r1 &&
      other.c1 == c1 &&
      other.r2 == r2 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(r1, c1, r2, c2);

  @override
  String toString() => 'GridRect($r1,$c1-$r2,$c2)';
}

class Clue {
  const Clue(this.row, this.col, this.value);

  factory Clue.fromList(List<dynamic> values) {
    if (values.length != 3) {
      throw FormatException('A clue needs row, column, and value.');
    }
    return Clue(_asInt(values[0]), _asInt(values[1]), _asInt(values[2]));
  }

  final int row;
  final int col;
  final int value;

  List<int> toList() => [row, col, value];

  @override
  bool operator ==(Object other) =>
      other is Clue &&
      other.row == row &&
      other.col == col &&
      other.value == value;

  @override
  int get hashCode => Object.hash(row, col, value);
}

class ParcelPuzzle {
  const ParcelPuzzle({
    required this.rows,
    required this.cols,
    required this.clues,
  });

  final int rows;
  final int cols;
  final List<Clue> clues;

  int get cellCount => rows * cols;

  int get clueSum => clues.fold(0, (sum, clue) => sum + clue.value);
}

enum PlacementIssue {
  ok,
  outOfBounds,
  degenerate,
  clueCount,
  valueMismatch,
  overlap,
  deadEnd,
  malformed,
}

class PlacementAssessment {
  const PlacementAssessment({
    required this.issue,
    this.rect,
    this.clueIndex,
    this.mask,
    this.area = 0,
    this.cluesInside = 0,
  });

  final PlacementIssue issue;
  final GridRect? rect;
  final int? clueIndex;
  final Bits? mask;
  final int area;
  final int cluesInside;

  bool get accepted => issue == PlacementIssue.ok;
}

class RegionChoice {
  const RegionChoice({
    required this.clueIndex,
    required this.rect,
    required this.mask,
  });

  final int clueIndex;
  final GridRect rect;
  final Bits mask;
}

int _asInt(Object? value) {
  if (value is int) return value;
  throw FormatException('Expected an integer, got $value');
}
