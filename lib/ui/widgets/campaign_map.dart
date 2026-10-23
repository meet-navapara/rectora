import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/theme/palette.dart';

class CampaignStop {
  const CampaignStop({
    required this.pack,
    required this.solved,
    required this.total,
    required this.locked,
    required this.current,
  });

  final PackSummary pack;
  final int solved;
  final int total;
  final bool locked;
  final bool current;
}

class CampaignMap extends StatelessWidget {
  const CampaignMap({
    super.key,
    required this.stops,
    required this.reduceMotion,
    required this.onOpen,
  });

  final List<CampaignStop> stops;
  final bool reduceMotion;
  final ValueChanged<PackSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final height = 28.0 + stops.length * 112;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion ? Duration.zero : RectoraTokens.reveal,
      curve: RectoraTokens.ease,
      builder: (context, progress, child) {
        return CustomPaint(
          painter: _RoutePainter(
            palette: palette,
            count: stops.length,
            progress: progress,
            current: [for (final stop in stops) stop.current],
            done: [
              for (final stop in stops)
                stop.solved == stop.total && stop.total > 0,
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cardWidth = (width * 230 / 380).clamp(140.0, 230.0);
            final inset = (width * 24 / 380).clamp(12.0, 24.0);
            return Stack(
              children: [
                for (var i = 0; i < stops.length; i++)
                  Positioned(
                    top: 16 + i * 112,
                    left: i.isEven ? inset : null,
                    right: i.isOdd ? inset : null,
                    width: cardWidth,
                    child: _Landmark(stop: stops[i], onOpen: onOpen),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Landmark extends StatelessWidget {
  const _Landmark({required this.stop, required this.onOpen});

  final CampaignStop stop;
  final ValueChanged<PackSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final label = stop.locked
        ? '${stop.pack.name}, locked'
        : stop.current
        ? '${stop.pack.name}, continue here'
        : '${stop.pack.name}, ${stop.solved} of ${stop.total} solved';
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: stop.locked ? palette.backgroundAlt : palette.surface,
        elevation: stop.current ? 2 : 0,
        shadowColor: palette.copper.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RectoraTokens.nodeRadius),
          side: BorderSide(
            color: stop.current
                ? palette.copper
                : stop.solved == stop.total && stop.total > 0
                ? palette.pine
                : palette.line,
            width: stop.current ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RectoraTokens.nodeRadius),
          onTap: stop.locked ? null : () => onOpen(stop.pack),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.pack.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  stop.locked
                      ? 'Finish the previous chapter.'
                      : stop.pack.blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text('${stop.solved} of ${stop.total}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.palette,
    required this.count,
    required this.progress,
    required this.current,
    required this.done,
  });

  final RectoraPalette palette;
  final int count;
  final double progress;
  final List<bool> current;
  final List<bool> done;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;
    final path = Path();
    for (var i = 0; i < count; i++) {
      final point = _point(size, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < count; i++) {
      final point = _point(size, i);
      final paint = Paint()
        ..color = current[i]
            ? palette.copper
            : done[i]
            ? palette.pine
            : palette.muted;
      canvas.drawCircle(point, current[i] ? 7 : 5, paint);
    }
  }

  Offset _point(Size size, int index) {
    final left = index.isEven;
    final edge = size.width >= 380 ? 48.0 : size.width * 48 / 380;
    return Offset(left ? edge : size.width - edge, 48 + index * 112);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.count != count;
  }
}
