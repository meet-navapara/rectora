import '../parcels/models.dart';
import 'records.dart';
import 'save_game.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.detail,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;
  final String detail;
  final int progress;
  final int target;

  bool get earned => progress >= target;
  double get fraction => target == 0 ? 1 : (progress / target).clamp(0, 1);
}

List<Achievement> achievementsFor({
  required DerivedStats stats,
  required SaveGame save,
  required int parcelPacksCleared,
  required int masterSolved,
}) {
  final quiet = save.parcelRecords.entries
      .where((entry) => !entry.key.startsWith('daily@'))
      .where((entry) => entry.value.solved && entry.value.perfect)
      .length;
  return [
    Achievement(
      id: 'first-parcel',
      title: 'First parcel',
      detail: 'Finish one parcel puzzle.',
      progress: stats.parcelsSolved,
      target: 1,
    ),
    Achievement(
      id: 'ten-windows',
      title: 'Ten windows',
      detail: 'Finish ten parcel puzzles.',
      progress: stats.parcelsSolved,
      target: 10,
    ),
    Achievement(
      id: 'fifty-windows',
      title: 'Fifty windows',
      detail: 'Finish fifty parcel puzzles.',
      progress: stats.parcelsSolved,
      target: 50,
    ),
    Achievement(
      id: 'hundred-windows',
      title: 'Hundred windows',
      detail: 'Finish one hundred parcel puzzles.',
      progress: stats.parcelsSolved,
      target: 100,
    ),
    Achievement(
      id: 'perfect-five',
      title: 'Clean edge',
      detail: 'Finish five puzzles with no hints.',
      progress: stats.perfectClears,
      target: 5,
    ),
    Achievement(
      id: 'quiet-hand',
      title: 'Quiet hand',
      detail: 'Finish ten parcel puzzles with no hints.',
      progress: quiet,
      target: 10,
    ),
    Achievement(
      id: 'week-of-days',
      title: 'Week of days',
      detail: 'Reach a seven-day daily streak.',
      progress: stats.longestStreak,
      target: 7,
    ),
    Achievement(
      id: 'threaded',
      title: 'Threaded',
      detail: 'Finish one Threads puzzle.',
      progress: stats.threadsSolved,
      target: 1,
    ),
    Achievement(
      id: 'loom',
      title: 'Loom',
      detail: 'Finish twenty-five Threads puzzles.',
      progress: stats.threadsSolved,
      target: 25,
    ),
    Achievement(
      id: 'keystone',
      title: 'Keystone',
      detail: 'Finish a master parcel.',
      progress: masterSolved,
      target: 1,
    ),
    Achievement(
      id: 'pack',
      title: 'Pack complete',
      detail: 'Finish every puzzle in a parcel pack.',
      progress: parcelPacksCleared,
      target: 1,
    ),
    Achievement(
      id: 'return',
      title: 'Return',
      detail: 'Complete daily puzzles on three different dates.',
      progress: stats.dailyCompletions,
      target: 3,
    ),
    Achievement(
      id: 'measured',
      title: 'Measured',
      detail: 'Record a parcel time under 45 seconds.',
      progress: stats.bestParcelMs != null && stats.bestParcelMs! <= 45000
          ? 1
          : 0,
      target: 1,
    ),
    Achievement(
      id: 'easy-run',
      title: 'Warm start',
      detail: 'Finish ten easy parcels.',
      progress: stats.solvedByDifficulty[Difficulty.easy] ?? 0,
      target: 10,
    ),
    Achievement(
      id: 'hard-finisher',
      title: 'Hard mode finisher',
      detail: 'Finish a hard puzzle.',
      progress: stats.solvedByDifficulty[Difficulty.hard] ?? 0,
      target: 1,
    ),
    Achievement(
      id: 'expert-deduction',
      title: 'Expert deduction',
      detail: 'Finish an expert puzzle.',
      progress: stats.solvedByDifficulty[Difficulty.expert] ?? 0,
      target: 1,
    ),
    Achievement(
      id: 'grandmaster',
      title: 'Grandmaster',
      detail: 'Finish a grandmaster puzzle.',
      progress: stats.solvedByDifficulty[Difficulty.grandmaster] ?? 0,
      target: 1,
    ),
  ];
}
