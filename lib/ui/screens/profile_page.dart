import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/profile/profile.dart';
import 'package:rectora/domain/progression/relics.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/gallery_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';
import 'package:rectora/ui/widgets/mark.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController name;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: RectoraScope.read(context).save.profile.name,
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final stats = controller.stats;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'This name and avatar stay on this device. You can play as a guest. Sign in from Settings when you want a Google account.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarMark(index: controller.save.profile.avatar, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: name,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) async {
                    final message = await controller.updateName(value);
                    if (mounted) setState(() => error = message);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                final message = await controller.updateName(name.text);
                if (mounted) setState(() => error = message);
              },
              child: const Text('Save name'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Avatars', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < Profile.avatarCount; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => controller.updateAvatar(i),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: controller.save.profile.avatar == i
                            ? palette.copper
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AvatarMark(index: i, size: 64),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Level ${controller.save.xp ~/ 40 + 1}'),
          Text('${controller.save.xp} mastery points'),
          Text('${stats.parcelsSolved} parcels solved'),
          Text('${stats.tracesSolved} traces · ${stats.inksSolved} inks'),
          Text('${stats.threadsSolved} threads solved'),
          Text('Highest ${_highest(stats.solvedByDifficulty)}'),
          Text('Favorite ${_favorite(stats)}'),
          Text(
            'Best parcel ${stats.bestParcelMs == null ? '—' : '${stats.bestParcelMs! ~/ 1000}s'}',
          ),
          Text('Streak ${stats.currentStreak}'),
          Text('Style ${controller.save.settings.boardStyle}'),
          Text(
            '${controller.achievements.where((item) => item.earned).length} of ${controller.achievements.length} achievements',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => pushSoft(context, const GalleryPage()),
            child: Text(
              '${relicsFor(stats: stats, save: controller.save, chapters: controller.catalog.parcelChapters, mode: 'parcel').where((relic) => relic.earned).length} fragments restored',
            ),
          ),
        ],
      ),
    );
  }
}

String _highest(Map<Difficulty, int> counts) {
  Difficulty? best;
  for (final entry in counts.entries) {
    if (entry.value <= 0) continue;
    if (best == null || entry.key.index > best.index) best = entry.key;
  }
  return best?.label ?? 'None yet';
}

String _favorite(DerivedStats stats) {
  final scores = {
    'Parcels': stats.parcelsSolved,
    'Trace': stats.tracesSolved,
    'Inks': stats.inksSolved,
    'Threads': stats.threadsSolved,
  };
  var name = 'Parcels';
  var best = -1;
  for (final entry in scores.entries) {
    if (entry.value > best) {
      best = entry.value;
      name = entry.key;
    }
  }
  return best <= 0 ? 'Not chosen yet' : name;
}
