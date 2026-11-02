import 'dart:math' as math;

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
    final handed =
        phase == CoachPhase.waitingForPlayer &&
        coach.step.kind == GuideKind.demonstrate;
    final title = phase == CoachPhase.correctiveHint
        ? 'Try the glow'
        : phase == CoachPhase.successFeedback
        ? 'Correct'
        : handed
        ? 'Your turn'
        : coach.step.title;
    final body = phase == CoachPhase.correctiveHint
        ? coach.correction
        : phase == CoachPhase.successFeedback
        ? 'That move fits. Continue when you are ready.'
        : handed
        ? 'The squares are still empty. Drag the glow yourself.'
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Skip sits in the title row, so it can never scroll out of view.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
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
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    this.travel = false,
    this.onTravelEnd,
  });

  final int rows;
  final int cols;
  final List<int> cells;
  final bool showPointer;
  final Widget child;

  /// Moves a guide light along [cells] without changing the puzzle.
  final bool travel;
  final VoidCallback? onTravelEnd;

  @override
  State<GuidePulse> createState() => _GuidePulseState();
}

class _GuidePulseState extends State<GuidePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  var _travelStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GuidePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.travel && !oldWidget.travel) _travelStarted = false;
    _sync();
  }

  void _sync() {
    final motion = homeMotionEnabled(context);
    if (widget.travel && motion) {
      if (_travelStarted) return;
      _travelStarted = true;
      _pulse
        ..duration = const Duration(milliseconds: 1680)
        ..stop()
        ..value = 0;
      _pulse.forward().whenComplete(() {
        if (!mounted || !widget.travel) return;
        widget.onTravelEnd?.call();
      });
      return;
    }
    _travelStarted = false;
    if (widget.showPointer && motion) {
      _pulse.duration = const Duration(milliseconds: 900);
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      return;
    }
    _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = homeMotionEnabled(context);
    final travel = widget.travel && motion;
    final animate = motion && widget.showPointer && !travel;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.cells.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: travel || animate
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _GlowPainter(
                            rows: widget.rows,
                            cols: widget.cols,
                            cells: widget.cells,
                            showPointer: animate,
                            travel: travel,
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
                        travel: false,
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
    required this.travel,
    required this.t,
  });

  final int rows;
  final int cols;
  final List<int> cells;
  final bool showPointer;
  final bool travel;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = BoardMetrics(rows: rows, cols: cols, size: size);
    final glow = travel ? 0.72 : t;
    final wash = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE0975C).withValues(alpha: 0.08 + 0.06 * glow);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFE0975C).withValues(alpha: 0.42 + 0.38 * glow);
    for (final cell in cells) {
      final row = cell ~/ cols;
      final col = cell % cols;
      final rect = RRect.fromRectAndRadius(
        metrics.cellRect(row, col),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, wash);
      canvas.drawRRect(rect, stroke);
    }
    if (travel && cells.isNotEmpty) {
      final glide = _glide(t);
      _trail(canvas, metrics, glide);
      _mark(
        canvas,
        _along(metrics, glide),
        metrics.cell,
        press: _press(t),
        lift: _lift(t),
        breath: 0.35,
      );
      return;
    }
    if (!showPointer || cells.isEmpty) return;
    final row = cells.first ~/ cols;
    final col = cells.first % cols;
    _mark(
      canvas,
      metrics.cellRect(row, col).center,
      metrics.cell,
      press: 0,
      lift: 0,
      breath: t,
    );
  }

  /// Press, then a slow glide, then a lift. [t] is the full demonstration.
  double _glide(double t) {
    const pressEnd = 0.18;
    const glideEnd = 0.82;
    if (t <= pressEnd) return 0;
    if (t >= glideEnd) return 1;
    return Curves.easeInOutCubic.transform(
      (t - pressEnd) / (glideEnd - pressEnd),
    );
  }

  double _press(double t) {
    const pressEnd = 0.18;
    if (t <= 0 || t >= pressEnd) return 0;
    return Curves.easeOut.transform(t / pressEnd);
  }

  double _lift(double t) {
    const glideEnd = 0.82;
    if (t <= glideEnd) return 0;
    return Curves.easeIn.transform((t - glideEnd) / (1 - glideEnd));
  }

  Offset _at(BoardMetrics metrics, int cell) {
    final row = cell ~/ cols;
    final col = cell % cols;
    return metrics.cellRect(row, col).center;
  }

  Offset _along(BoardMetrics metrics, double t) {
    if (cells.length == 1) return _at(metrics, cells.first);
    final span = t.clamp(0.0, 1.0) * (cells.length - 1);
    final index = span.floor().clamp(0, cells.length - 2);
    return Offset.lerp(
      _at(metrics, cells[index]),
      _at(metrics, cells[index + 1]),
      span - index,
    )!;
  }

  void _trail(Canvas canvas, BoardMetrics metrics, double glide) {
    if (cells.length < 2 || glide <= 0) return;
    final path = Path();
    final span = glide * (cells.length - 1);
    final last = span.floor().clamp(0, cells.length - 2);
    for (var i = 0; i <= last; i++) {
      final point = _at(metrics, cells[i]);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final tip = _along(metrics, glide);
    path.lineTo(tip.dx, tip.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(2, metrics.cell * 0.045)
        ..color = const Color(0xFFE0975C).withValues(alpha: 0.38),
    );
  }

  /// A ring and a soft core. [press] ripples, [lift] fades the mark away.
  void _mark(
    Canvas canvas,
    Offset center,
    double cell, {
    required double press,
    required double lift,
    required double breath,
  }) {
    final scale = 1 + breath * 0.08 - press * 0.1 + lift * 0.22;
    final fade = (1 - lift).clamp(0.0, 1.0);
    final radius = cell * 0.2 * scale;
    final copper = const Color(0xFFE0975C);
    canvas.drawCircle(
      center,
      radius * 2.15,
      Paint()
        ..color = copper.withValues(alpha: 0.16 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.07),
    );
    canvas.drawCircle(
      center,
      radius * 1.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, cell * 0.03)
        ..color = copper.withValues(alpha: 0.9 * fade),
    );
    canvas.drawCircle(
      center,
      radius * 0.38,
      Paint()..color = const Color(0xFFFFF6EA).withValues(alpha: 0.95 * fade),
    );
    if (press > 0.04) {
      canvas.drawCircle(
        center,
        radius * (1.5 + press * 2.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.1, cell * 0.018)
          ..color = copper.withValues(alpha: (1 - press) * 0.5 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.showPointer != showPointer ||
        oldDelegate.travel != travel ||
        oldDelegate.cells != cells;
  }
}
