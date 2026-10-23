import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/tutorial/home_tour.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_motion.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/ink_page.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/screens/thread_page.dart';
import 'package:rectora/ui/screens/trace_page.dart';
import 'package:rectora/ui/widgets/mark.dart';

enum HomeTourStep {
  off,
  welcome,
  continueJourney,
  modes,
  daily,
  weekly,
  progress,
  help,
  choose,
}

const homeTourSteps = [
  HomeTourStep.welcome,
  HomeTourStep.continueJourney,
  HomeTourStep.modes,
  HomeTourStep.daily,
  HomeTourStep.weekly,
  HomeTourStep.progress,
  HomeTourStep.help,
  HomeTourStep.choose,
];

class HomeTourCopy {
  const HomeTourCopy(this.title, this.body);

  final String title;
  final String body;
}

HomeTourCopy homeTourCopy(HomeTourStep step) {
  return switch (step) {
    HomeTourStep.welcome => const HomeTourCopy(
      'Welcome to RECTORA',
      'Ready to train your mind? Solve clever puzzles, unlock new challenges, and discover your favorite way to play.',
    ),
    HomeTourStep.continueJourney => const HomeTourCopy(
      'Continue Your Journey',
      'Jump back into your last puzzle whenever you are ready.',
    ),
    HomeTourStep.modes => const HomeTourCopy(
      'Choose Your Challenge',
      'Each mode has different rules. Start with a guided puzzle to learn the basics.',
    ),
    HomeTourStep.daily => const HomeTourCopy(
      'Daily Challenge',
      'Try a new challenge and track your progress.',
    ),
    HomeTourStep.weekly => const HomeTourCopy(
      'Weekly Challenge',
      'Finish this week’s set for a mastery bonus.',
    ),
    HomeTourStep.progress => const HomeTourCopy(
      'Your Progress',
      'See the puzzles you have solved and the achievements you have earned.',
    ),
    HomeTourStep.help => const HomeTourCopy(
      'Need help?',
      'Open the question mark anytime to replay a guide. Settings holds sound, theme, and your account.',
    ),
    HomeTourStep.choose => const HomeTourCopy(
      'Find Your Puzzle Style',
      'Tap Parcels, Trace, Inks, or Threads. Each one plays differently.',
    ),
    HomeTourStep.off => const HomeTourCopy('', ''),
  };
}

/// Opens the first lesson level for [mode]. Campaign solves are left as they are.
Future<void> openModeLesson(BuildContext context, PlayMode mode) {
  final catalog = RectoraScope.read(context).catalog;
  final page = switch (mode) {
    PlayMode.parcel => _parcel(catalog),
    PlayMode.trace => _trace(catalog),
    PlayMode.ink => _ink(catalog),
    PlayMode.thread => _thread(catalog),
  };
  if (page == null) return Future<void>.value();
  return Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (_) => page));
}

Widget? _parcel(GameCatalog catalog) {
  final level = parcelLesson(catalog);
  if (level == null) return null;
  return ParcelPage(level: level);
}

Widget? _trace(GameCatalog catalog) {
  final level = traceLesson(catalog);
  if (level == null) return null;
  return TracePage(level: level);
}

Widget? _ink(GameCatalog catalog) {
  final level = inkLesson(catalog);
  if (level == null) return null;
  return InkPage(level: level);
}

Widget? _thread(GameCatalog catalog) {
  final level = threadLesson(catalog);
  if (level == null) return null;
  return ThreadPage(level: level);
}

class HomeTourOverlay extends StatefulWidget {
  const HomeTourOverlay({
    super.key,
    required this.step,
    required this.holeKey,
    required this.onNext,
    required this.onSkip,
  });

  final HomeTourStep step;
  final GlobalKey? holeKey;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<HomeTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HomeTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final allow =
        homeMotionEnabled(context) && widget.step == HomeTourStep.welcome;
    if (allow) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Rect? _hole(BuildContext context) {
    final target = widget.holeKey?.currentContext?.findRenderObject();
    final host = context.findRenderObject();
    if (target is! RenderBox || host is! RenderBox || !target.hasSize) {
      return null;
    }
    final origin = host.globalToLocal(target.localToGlobal(Offset.zero));
    return origin & target.size;
  }

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final copy = homeTourCopy(widget.step);
    final index = homeTourSteps.indexOf(widget.step);
    final hole = _hole(context);
    final choose = widget.step == HomeTourStep.choose;
    final welcome = widget.step == HomeTourStep.welcome;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DimPainter(
                hole: welcome ? null : hole,
                color: const Color(0xD9070B16),
              ),
            ),
          ),
        ),
        if (!choose)
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.transparent),
          ),
        if (welcome)
          Center(
            child: _TourCard(
              palette: palette,
              copy: copy,
              stepLabel: 'Step ${index + 1} of ${homeTourSteps.length}',
              primary: 'Let\'s Begin',
              onPrimary: widget.onNext,
              onSkip: widget.onSkip,
              mark: homeMotionEnabled(context)
                  ? AnimatedBuilder(
                      animation: _spin,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _spin.value * math.pi * 2,
                          child: child,
                        );
                      },
                      child: const RectoraMark(size: 64),
                    )
                  : const RectoraMark(size: 64),
            ),
          )
        else
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _TourCard(
              palette: palette,
              copy: copy,
              stepLabel: 'Step ${index + 1} of ${homeTourSteps.length}',
              primary: choose ? null : 'Continue',
              onPrimary: choose ? null : widget.onNext,
              onSkip: widget.onSkip,
            ),
          ),
      ],
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.palette,
    required this.copy,
    required this.stepLabel,
    required this.onSkip,
    this.primary,
    this.onPrimary,
    this.mark,
  });

  final RectoraPalette palette;
  final HomeTourCopy copy;
  final String stepLabel;
  final String? primary;
  final VoidCallback? onPrimary;
  final VoidCallback onSkip;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: palette.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (mark != null) ...[
                        Center(child: mark),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        stepLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: palette.copper,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(copy.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(copy.body, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (primary != null)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.copper,
                          foregroundColor: palette.copperInk,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: onPrimary,
                        child: Text(primary!),
                      ),
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Skip Tutorial'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  const _DimPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    final spot = hole;
    if (spot != null) {
      path.addRRect(
        RRect.fromRectAndRadius(spot.inflate(8), const Radius.circular(18)),
      );
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DimPainter oldDelegate) {
    return oldDelegate.hole != hole || oldDelegate.color != color;
  }
}
