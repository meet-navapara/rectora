import 'package:flutter/material.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final stats = controller.stats;
    final achievements = controller.achievements;
    String time(int? ms) {
      if (ms == null) return '—';
      final total = ms ~/ 1000;
      return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (stats.parcelsSolved == 0 &&
              stats.threadsSolved == 0 &&
              stats.tracesSolved == 0 &&
              stats.inksSolved == 0 &&
              controller.save.parcelsStarted.isEmpty &&
              controller.save.threadsStarted.isEmpty &&
              controller.save.tracesStarted.isEmpty &&
              controller.save.inksStarted.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Play a puzzle to start a record. These totals are counted from the save on this device.',
              ),
            ),
          _Stat('Parcels solved', '${stats.parcelsSolved}'),
          _Stat('Trace solved', '${stats.tracesSolved}'),
          _Stat('Inks solved', '${stats.inksSolved}'),
          _Stat('Threads solved', '${stats.threadsSolved}'),
          _Stat(
            'Parcel completion rate',
            stats.parcelStarts == 0
                ? '—'
                : '${(stats.parcelCompletionRate * 100).round()}% of ${stats.parcelStarts} started',
          ),
          _Stat('Skipped parcels', '${stats.parcelsSkipped}'),
          _Stat('Perfect clears', '${stats.perfectClears}'),
          _Stat('Best parcel time', time(stats.bestParcelMs)),
          _Stat('Best perfect parcel', time(stats.bestPerfectParcelMs)),
          _Stat('Best thread time', time(stats.bestThreadMs)),
          _Stat('Hints used', '${stats.hintsUsed}'),
          _Stat('Mastery', '${controller.save.xp}'),
          _Stat('Daily streak', '${stats.currentStreak}'),
          _Stat('Longest streak', '${stats.longestStreak}'),
          const SizedBox(height: 16),
          Text('Difficulty', style: Theme.of(context).textTheme.titleMedium),
          for (final difficulty in Difficulty.values)
            _Stat(
              difficulty.label,
              '${stats.solvedByDifficulty[difficulty] ?? 0} solved',
            ),
          const SizedBox(height: 16),
          Text('Achievements', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${achievement.earned ? 'Earned' : 'In progress'} · ${achievement.title}',
                  ),
                  Text(achievement.detail),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: achievement.fraction,
                      backgroundColor: palette.surfaceHigh,
                      color: achievement.earned ? palette.pine : palette.copper,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
