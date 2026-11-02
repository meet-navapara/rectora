import 'package:flutter/material.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/widgets/ad_banner.dart';
import 'package:rectora/ui/widgets/dialogs.dart';

class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final week = weekKey(controller.now);
    final ids = controller.weeklyIds();
    final solved = ids
        .where((id) => controller.save.weeklySolved.contains('$week|$id'))
        .length;
    final claimed = controller.save.weeklyClaimed.contains(week);
    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: const Text('This week'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('Week of $week', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Finish these three parcel puzzles. A new set arrives every Monday. Completing it awards $weeklyClearBonus mastery points once. Playing them again does not award them again.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            claimed
                ? 'Weekly reward collected.'
                : '$solved of ${ids.length} finished',
          ),
          const SizedBox(height: 16),
          for (final id in ids)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WeeklyTile(
                id: id,
                done: controller.save.weeklySolved.contains('$week|$id'),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeeklyTile extends StatelessWidget {
  const _WeeklyTile({required this.id, required this.done});

  final String id;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final level = controller.catalog.parcelById(id);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        title: Text(level?.title ?? id),
        subtitle: Text(level == null ? id : level.difficulty.label),
        trailing: Icon(
          done ? Icons.check_circle : Icons.play_arrow_rounded,
          color: done ? palette.pine : palette.copper,
        ),
        onTap: level == null
            ? null
            : () => pushSoft(context, ParcelPage(level: level, weekly: true)),
      ),
    );
  }
}
