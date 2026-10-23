import '../parcels/models.dart';

class LevelRecord {
  const LevelRecord({
    required this.solved,
    required this.skipped,
    required this.hintsOnBestSolve,
    this.bestMs,
    this.perfectBestMs,
  });

  final bool solved;
  final bool skipped;
  final int hintsOnBestSolve;
  final int? bestMs;
  final int? perfectBestMs;

  bool get perfect => solved && perfectBestMs != null;
  bool get finished => solved || skipped;

  LevelRecord copyWith({
    bool? solved,
    bool? skipped,
    int? hintsOnBestSolve,
    int? bestMs,
    int? perfectBestMs,
    bool clearBest = false,
    bool clearPerfect = false,
  }) {
    return LevelRecord(
      solved: solved ?? this.solved,
      skipped: skipped ?? this.skipped,
      hintsOnBestSolve: hintsOnBestSolve ?? this.hintsOnBestSolve,
      bestMs: clearBest ? null : bestMs ?? this.bestMs,
      perfectBestMs: clearPerfect ? null : perfectBestMs ?? this.perfectBestMs,
    );
  }

  Map<String, Object?> toJson() => {
    'solved': solved,
    'skipped': skipped,
    'hints': hintsOnBestSolve,
    'bestMs': bestMs,
    'perfectBestMs': perfectBestMs,
  };

  factory LevelRecord.fromJson(Map<String, Object?> json) {
    int? millis(Object? value) => value is int && value >= 0 ? value : null;
    return LevelRecord(
      solved: json['solved'] == true,
      skipped: json['skipped'] == true,
      hintsOnBestSolve: json['hints'] is int ? json['hints'] as int : 0,
      bestMs: millis(json['bestMs']),
      perfectBestMs: millis(json['perfectBestMs']),
    );
  }
}

class PuzzleDraft {
  const PuzzleDraft({
    required this.elapsedMs,
    required this.hintsUsed,
    required this.moves,
  });

  final int elapsedMs;
  final int hintsUsed;
  final List<List<int>> moves;

  Map<String, Object?> toJson() => {
    'elapsedMs': elapsedMs,
    'hintsUsed': hintsUsed,
    'moves': moves,
  };

  factory PuzzleDraft.fromJson(Map<String, Object?> json) {
    final moves = <List<int>>[];
    final raw = json['moves'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is List && entry.every((value) => value is int)) {
          moves.add([for (final value in entry) value as int]);
        }
      }
    }
    return PuzzleDraft(
      elapsedMs: json['elapsedMs'] is int ? json['elapsedMs'] as int : 0,
      hintsUsed: json['hintsUsed'] is int ? json['hintsUsed'] as int : 0,
      moves: moves,
    );
  }
}

class DerivedStats {
  const DerivedStats({
    required this.parcelsSolved,
    required this.threadsSolved,
    required this.tracesSolved,
    required this.inksSolved,
    required this.parcelsSkipped,
    required this.perfectClears,
    required this.bestParcelMs,
    required this.bestPerfectParcelMs,
    required this.bestThreadMs,
    required this.parcelStarts,
    required this.threadStarts,
    required this.hintsUsed,
    required this.solvedByDifficulty,
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyCompletions,
  });

  final int parcelsSolved;
  final int threadsSolved;
  final int tracesSolved;
  final int inksSolved;
  final int parcelsSkipped;
  final int perfectClears;
  final int? bestParcelMs;
  final int? bestPerfectParcelMs;
  final int? bestThreadMs;
  final int parcelStarts;
  final int threadStarts;
  final int hintsUsed;
  final Map<Difficulty, int> solvedByDifficulty;
  final int currentStreak;
  final int longestStreak;
  final int dailyCompletions;

  double get parcelCompletionRate {
    if (parcelStarts == 0) return 0;
    return parcelsSolved / parcelStarts;
  }
}
