import '../campaign/catalog.dart';
import '../campaign/records.dart';
import '../campaign/save_game.dart';
import 'rewards.dart';

class Relic {
  const Relic({
    required this.id,
    required this.title,
    required this.detail,
    required this.earned,
  });

  final String id;
  final String title;
  final String detail;
  final bool earned;
}

/// Fragments earned from verified play. They are derived, so they cannot be
/// claimed twice by reopening a screen.
List<Relic> relicsFor({
  required DerivedStats stats,
  required SaveGame save,
  required List<PackSummary> chapters,
  required String mode,
}) {
  return [
    Relic(
      id: 'first-order',
      title: 'First order',
      detail: 'Finish one parcel puzzle.',
      earned: stats.parcelsSolved >= 1,
    ),
    Relic(
      id: 'quiet-five',
      title: 'Quiet five',
      detail: 'Finish five puzzles without a hint.',
      earned: stats.perfectClears >= 5,
    ),
    Relic(
      id: 'week-path',
      title: 'Week path',
      detail: 'Reach a seven-day daily streak.',
      earned: stats.longestStreak >= 7,
    ),
    Relic(
      id: 'week-seal',
      title: 'Week seal',
      detail: 'Finish a weekly set.',
      earned: save.weeklyClaimed.isNotEmpty,
    ),
    Relic(
      id: 'trace-mark',
      title: 'Trace mark',
      detail: 'Finish one Trace puzzle.',
      earned: stats.tracesSolved >= 1,
    ),
    Relic(
      id: 'ink-mark',
      title: 'Ink mark',
      detail: 'Finish one Inks puzzle.',
      earned: stats.inksSolved >= 1,
    ),
    for (final chapter in chapters)
      Relic(
        id: chapterKey(mode, chapter.id),
        title: chapter.name,
        detail: 'Solve every puzzle in ${chapter.name}.',
        earned: save.claimedChapters.contains(chapterKey(mode, chapter.id)),
      ),
  ];
}

bool chapterSolved(PackSummary pack, Map<String, LevelRecord> records) {
  return pack.levelIds.isNotEmpty &&
      pack.levelIds.every((id) => records[id]?.solved == true);
}
