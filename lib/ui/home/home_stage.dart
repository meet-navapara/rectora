import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_art.dart';
import 'package:rectora/ui/home/home_cards.dart';
import 'package:rectora/ui/home/home_motion.dart';
import 'package:rectora/ui/widgets/mark.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.avatar,
    required this.status,
    required this.onProfile,
    required this.onSettings,
    required this.onHelp,
    this.guideKey,
  });

  final String name;
  final int avatar;
  final String status;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final Key? guideKey;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        _HeaderButton(
          tooltip: 'Profile',
          onPressed: onProfile,
          child: AvatarMark(index: avatar, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECTORA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$name · $status',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        KeyedSubtree(
          key: guideKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderButton(
                tooltip: 'Help',
                onPressed: onHelp,
                child: Icon(Icons.help_outline, color: palette.ink, size: 20),
              ),
              const SizedBox(width: 8),
              _HeaderButton(
                tooltip: 'Settings',
                onPressed: onSettings,
                child: Icon(
                  Icons.settings_outlined,
                  color: palette.ink,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: palette.surface,
        fixedSize: const Size(42, 42),
        shape: CircleBorder(side: BorderSide(color: palette.line)),
        padding: EdgeInsets.zero,
      ),
      icon: child,
    );
  }
}

class ContinueHero extends StatelessWidget {
  const ContinueHero({
    super.key,
    required this.chapter,
    required this.levelLabel,
    required this.summary,
    required this.progress,
    required this.started,
    required this.onTap,
  });

  final String chapter;
  final String levelLabel;
  final String summary;
  final double progress;
  final bool started;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    final reduce = !homeMotionEnabled(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : RectoraTokens.reveal,
      curve: RectoraTokens.ease,
      builder: (context, shown, child) {
        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, (1 - shown) * 12),
            child: child,
          ),
        );
      },
      child: HomePressable(
        onTap: onTap,
        label: started ? 'Continue $levelLabel' : 'Start playing',
        child: Stack(
          children: [
            const Positioned.fill(child: _HeroArt()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      palette.background.withValues(alpha: 0.9),
                      palette.background.withValues(alpha: 0.5),
                      palette.background.withValues(alpha: 0.02),
                    ],
                    stops: const [0, 0.46, 0.82],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: palette.copper,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    levelLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(summary, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bar = constraints.maxWidth.clamp(0.0, 180.0);
                      return SizedBox(
                        width: bar,
                        child: HomeProgress(value: progress),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionPill(label: started ? 'Continue' : 'Start playing'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroArt extends StatefulWidget {
  const _HeroArt();

  @override
  State<_HeroArt> createState() => _HeroArtState();
}

class _HeroArtState extends State<_HeroArt>
    with SingleTickerProviderStateMixin {
  AnimationController? glow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!homeMotionEnabled(context)) {
      glow?.stop();
      return;
    }
    final controller = glow ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!controller.isAnimating) controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    glow?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final controller = glow;
    if (controller == null) {
      return CustomPaint(painter: HeroWorldPainter(palette: palette, glow: 0));
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: HeroWorldPainter(palette: palette, glow: controller.value),
        );
      },
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.copper,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.copperInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: palette.copperInk,
            ),
          ],
        ),
      ),
    );
  }
}

class ModeArtworkCard extends StatelessWidget {
  const ModeArtworkCard({
    super.key,
    required this.title,
    required this.body,
    required this.done,
    required this.total,
    required this.tier,
    required this.art,
    required this.onTap,
  });

  final String title;
  final String body;
  final int done;
  final int total;
  final String tier;
  final CustomPainter art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    final percent = total == 0 ? 0 : ((done / total) * 100).round();
    return HomePressable(
      onTap: onTap,
      label: '$title, $percent percent, $tier',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Pixel 8a cards are about 180 wide with 112 of artwork.
          final artHeight = (constraints.maxWidth * 112 / 180).clamp(
            84.0,
            112.0,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: artHeight,
                child: CustomPaint(
                  painter: art,
                  child: const SizedBox.expand(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    HomeProgress(value: total == 0 ? 0 : done / total),
                    const SizedBox(height: 8),
                    Text(
                      '$percent% · $tier',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: palette.copper,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DailyFeatureCard extends StatelessWidget {
  const DailyFeatureCard({
    super.key,
    required this.dateLabel,
    required this.difficulty,
    required this.done,
    required this.streak,
    required this.bestStreak,
    required this.onTap,
  });

  final String dateLabel;
  final String difficulty;
  final bool done;
  final int streak;
  final int bestStreak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    return HomePressable(
      onTap: onTap,
      label: done ? 'Daily challenge finished' : 'Play daily challenge',
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: DailyArtPainter(palette, done: done)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 88, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Daily complete' : 'Daily challenge',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: done ? palette.pine : palette.copper,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dateLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  difficulty,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Streak $streak · best $bestStreak',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  done ? 'See the calendar' : 'Play daily challenge',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.ink,
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

class WeeklyFeatureCard extends StatelessWidget {
  const WeeklyFeatureCard({
    super.key,
    required this.done,
    required this.total,
    required this.reward,
    required this.claimed,
    required this.accountLabel,
    required this.onTap,
  });

  final int done;
  final int total;
  final int reward;
  final bool claimed;
  final String accountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    final available = total > 0;
    final title = !available
        ? 'No weekly set'
        : claimed
        ? 'Week sealed'
        : 'This week';
    final action = !available
        ? 'Open the week'
        : done >= total
        ? 'Review the set'
        : 'Continue challenge';
    return HomePressable(
      onTap: onTap,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 78,
            child: CustomPaint(
              painter: WeeklyArtPainter(palette, filled: done, total: total),
              child: const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  available
                      ? '$done of $total puzzles · $reward mastery for the set · $accountLabel'
                      : 'This catalog has no weekly puzzles yet.',
                ),
                if (available) ...[
                  const SizedBox(height: 10),
                  HomeProgress(value: done / total),
                ],
                const SizedBox(height: 10),
                Text(
                  action,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.copper,
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

class MasteryPanel extends StatelessWidget {
  const MasteryPanel({
    super.key,
    required this.mastery,
    required this.solved,
    required this.streak,
    required this.bestDifficulty,
    required this.openedLine,
    required this.onTap,
  });

  final int mastery;
  final int solved;
  final int streak;
  final String? bestDifficulty;
  final String? openedLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    return HomePressable(
      onTap: onTap,
      label: 'Player progress',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mastery',
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.copper,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(value: '$mastery', caption: 'Points'),
                _Metric(value: '$solved', caption: 'Solved'),
                _Metric(value: '$streak', caption: 'Streak'),
              ],
            ),
            if (bestDifficulty != null) ...[
              const SizedBox(height: 10),
              Text('Highest solved tier: $bestDifficulty'),
            ],
            if (openedLine != null) ...[
              const SizedBox(height: 4),
              Text(
                openedLine!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(caption),
        ],
      ),
    );
  }
}
