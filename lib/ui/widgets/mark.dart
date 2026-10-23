import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';

class RectoraMark extends StatelessWidget {
  const RectoraMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(palette.copper, palette.ink),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.copper, this.ink);

  final Color copper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = copper
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;
    final radius = Radius.circular(size.width * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = copper.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      frame,
    );
    final inner = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    final a = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.22,
      size.width * 0.34,
      size.height * 0.56,
    );
    final b = Rect.fromLTWH(
      size.width * 0.48,
      size.height * 0.22,
      size.width * 0.3,
      size.height * 0.28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(a, Radius.circular(size.width * 0.06)),
      inner,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(b, Radius.circular(size.width * 0.06)),
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.copper != copper || oldDelegate.ink != ink;
}

class AvatarMark extends StatelessWidget {
  const AvatarMark({super.key, required this.index, this.size = 56});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Semantics(
      label: 'Avatar ${index + 1}',
      child: CustomPaint(
        size: Size.square(size),
        painter: _AvatarPainter(
          index: index,
          copper: palette.copper,
          ink: palette.ink,
          pine: palette.pine,
          surface: palette.surfaceHigh,
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({
    required this.index,
    required this.copper,
    required this.ink,
    required this.pine,
    required this.surface,
  });

  final int index;
  final Color copper;
  final Color ink;
  final Color pine;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.28)),
      Paint()..color = surface,
    );
    final stroke = Paint()
      ..color = index.isEven ? copper : pine
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = ink.withValues(alpha: 0.9);
    final center = size.center(Offset.zero);
    switch (index % 8) {
      case 0:
        canvas.drawCircle(center, size.width * 0.22, stroke);
        canvas.drawCircle(center, size.width * 0.08, fill);
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: size.width * 0.46,
              height: size.height * 0.46,
            ),
            Radius.circular(size.width * 0.08),
          ),
          stroke,
        );
      case 2:
        final path = Path()
          ..moveTo(center.dx, size.height * 0.22)
          ..lineTo(size.width * 0.74, size.height * 0.72)
          ..lineTo(size.width * 0.26, size.height * 0.72)
          ..close();
        canvas.drawPath(path, stroke);
      case 3:
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: size.width * 0.24),
          0.6,
          4.2,
          false,
          stroke,
        );
      case 4:
        canvas.drawLine(
          Offset(size.width * 0.28, size.height * 0.68),
          Offset(size.width * 0.72, size.height * 0.32),
          stroke,
        );
        canvas.drawCircle(
          Offset(size.width * 0.7, size.height * 0.32),
          size.width * 0.07,
          fill,
        );
      case 5:
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: size.width * 0.28,
            height: size.height * 0.48,
          ),
          stroke,
        );
      case 6:
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(size.width * (0.3 + i * 0.16), size.height * 0.28),
            Offset(size.width * (0.3 + i * 0.16), size.height * 0.72),
            stroke,
          );
        }
      default:
        canvas.drawCircle(
          Offset(size.width * 0.4, size.height * 0.42),
          size.width * 0.12,
          stroke,
        );
        canvas.drawCircle(
          Offset(size.width * 0.58, size.height * 0.58),
          size.width * 0.1,
          fill,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.index != index;
}
