import 'package:flutter/material.dart';
import 'package:rectora/domain/tutorial/coach.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_motion.dart';
import 'package:rectora/ui/widgets/parcel_board.dart';

class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.coach,
    required this.onContinue,
    required this.onSkip,
    required this.onReplay,
    required this.onHint,
  });

  final PlayCoach coach;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onReplay;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final theme = Theme.of(context);
    final phase = coach.phase;
    final title = phase == CoachPhase.correctiveHint
        ? 'Try the glow'
        : phase == CoachPhase.successFeedback
        ? 'Correct'
        : coach.step.title;
    final body = phase == CoachPhase.correctiveHint
        ? coach.correction
        : phase == CoachPhase.successFeedback
        ? 'That move fits. Continue when you are ready.'
        : coach.step.body;
    final showContinue =
        phase == CoachPhase.intro ||
        phase == CoachPhase.successFeedback ||
        phase == CoachPhase.correctiveHint;
    final showHint =
        phase == CoachPhase.waitingForPlayer ||
        phase == CoachPhase.correctiveHint ||
        phase == CoachPhase.practice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: palette.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.34,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyLarge),
                if (coach.hintText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    coach.hintText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.copper,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showContinue)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.copper,
                          foregroundColor: palette.copperInk,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: onContinue,
                        child: const Text('Continue'),
                      ),
                    if (showHint)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: onHint,
                        child: const Text('Show me a hint'),
                      ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onReplay,
                      child: const Text('Replay demonstration'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onSkip,
                      child: const Text('Skip Tutorial'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glow and a pointer over the board. Neither widget takes touches.
class GuidePulse extends StatefulWidget {
  const GuidePulse({
    super.key,
    required this.rows,
    required this.cols,
    required this.cells,
    required this.showPointer,
    required this.child,
  });

  final int rows;
  final int cols;
  final List<int> cells;
  final bool showPointer;
  final Widget child;

  @override
  State<GuidePulse> createState() => _GuidePulseState();
}

class _GuidePulseState extends State<GuidePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GuidePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final allow = homeMotionEnabled(context) && widget.showPointer;
    if (allow) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = homeMotionEnabled(context) && widget.showPointer;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.cells.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: animate
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _GlowPainter(
                            rows: widget.rows,
                            cols: widget.cols,
                            cells: widget.cells,
                            showPointer: true,
                            t: _pulse.value,
                          ),
                        );
                      },
                    )
                  : CustomPaint(
                      painter: _GlowPainter(
                        rows: widget.rows,
                        cols: widget.cols,
                        cells: widget.cells,
                        showPointer: false,
                        t: 1,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.rows,
    required this.cols,
    required this.cells,
    required this.showPointer,
    required this.t,
  });

  final int rows;
  final int cols;
  final List<int> cells;
  final bool showPointer;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = BoardMetrics(rows: rows, cols: cols, size: size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFE2A15A).withValues(alpha: 0.45 + 0.4 * t);
    for (final cell in cells) {
      final row = cell ~/ cols;
      final col = cell % cols;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          metrics.cellRect(row, col).inflate(1),
          const Radius.circular(6),
        ),
        paint,
      );
    }
    if (!showPointer || cells.isEmpty) return;
    final row = cells.first ~/ cols;
    final col = cells.first % cols;
    final center = metrics.cellRect(row, col).center;
    canvas.drawCircle(
      center.translate(0, -metrics.cell * 0.55),
      7 + 2 * t,
      Paint()..color = const Color(0xFF1C140C).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.showPointer != showPointer ||
        oldDelegate.cells != cells;
  }
}
