import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/tutorial/home_tour.dart';
import 'package:rectora/domain/tutorial/progress.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_tour_view.dart';
import 'package:rectora/ui/scope.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final controller = RectoraScope.of(context);
    final seen = controller.save.tutorialsSeen;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('How to play'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Guides', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _GuideTile(
            title: 'Home-screen guide',
            seen: seen,
            id: homeIntroId,
            onReplay: () async {
              await controller.requestHomeTour();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          _GuideTile(
            title: 'Parcels guide',
            seen: seen,
            id: 'parcels',
            onReplay: () => _replayMode(context, PlayMode.parcel),
          ),
          _GuideTile(
            title: 'Trace guide',
            seen: seen,
            id: 'trace',
            onReplay: () => _replayMode(context, PlayMode.trace),
          ),
          _GuideTile(
            title: 'Inks guide',
            seen: seen,
            id: 'inks',
            onReplay: () => _replayMode(context, PlayMode.ink),
          ),
          _GuideTile(
            title: 'Threads guide',
            seen: seen,
            id: 'threads',
            onReplay: () => _replayMode(context, PlayMode.thread),
          ),
          const SizedBox(height: 16),
          const _Rule(
            'Parcels',
            'Cover the grid with rectangles. Each number is the area of its rectangle, and rectangles do not overlap.',
          ),
          const _Rule(
            'Trace',
            'Draw one path through every open cell. Visit the numbers in order, and stay on orthogonal steps.',
          ),
          const _Rule(
            'Inks',
            'Fill the grid with connected regions. A region may bend, and each region keeps its own color.',
          ),
          const _Rule(
            'Threads',
            'Join each matching letter. Paths stay orthogonal and do not cross.',
          ),
          const SizedBox(height: 12),
          const Text(
            'The hint button shows a step the puzzle requires. It is free. Help can offer one more hint after a test ad, and that ad can be cancelled. The first two levels of each mode show one move, then ask you to make the next one. Replay them here. Skip does not finish the lesson, does not clear solved puzzles, and does not show an ad.',
          ),
        ],
      ),
    );
  }

  Future<void> _replayMode(BuildContext context, PlayMode mode) async {
    final controller = RectoraScope.read(context);
    final id = switch (mode) {
      PlayMode.parcel => 'parcels',
      PlayMode.trace => 'trace',
      PlayMode.ink => 'inks',
      PlayMode.thread => 'threads',
    };
    await controller.forgetTutorial(id);
    if (!context.mounted) return;
    await openModeLesson(context, mode);
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({
    required this.title,
    required this.seen,
    required this.id,
    required this.onReplay,
  });

  final String title;
  final Set<String> seen;
  final String id;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final status = tutorialCompleted(seen, id)
        ? 'Finished'
        : tutorialSettled(seen, id)
        ? 'Skipped'
        : 'Not started';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(status),
      trailing: TextButton(onPressed: onReplay, child: const Text('Replay')),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
