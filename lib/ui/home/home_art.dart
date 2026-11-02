import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';

/// Painted geometric worlds for the home screen. Each painter is original
/// line art, themed from the live palette so light and dark both stay readable.
class HomeAtmospherePainter extends CustomPainter {
  HomeAtmospherePainter({required this.palette, required this.shift});

  final RectoraPalette palette;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = palette.background;
    canvas.drawRect(Offset.zero & size, base);
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.backgroundAlt, palette.background],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final grid = Paint()
      ..color = palette.line.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 46.0;
    final drift = shift * step;
    for (var x = -step + drift; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = -step; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final node = Paint()..color = palette.copper.withValues(alpha: 0.55);
    final halo = Paint()..color = palette.copper.withValues(alpha: 0.12);
    final points = <Offset>[
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.82, size.height * 0.12 + shift * 8),
      Offset(size.width * 0.7, size.height * 0.46),
      Offset(size.width * 0.2, size.height * 0.72),
      Offset(size.width * 0.88, size.height * 0.84),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 16, halo);
      canvas.drawCircle(point, 2.4, node);
    }
  }

  @override
  bool shouldRepaint(covariant HomeAtmospherePainter oldDelegate) {
    return oldDelegate.shift != shift || oldDelegate.palette != palette;
  }
}

class HeroWorldPainter extends CustomPainter {
  HeroWorldPainter({required this.palette, required this.glow});

  final RectoraPalette palette;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final night = palette.brightness == Brightness.dark;
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: night
            ? const [Color(0xFF1A2740), Color(0xFF101820), Color(0xFF3A2A22)]
            : const [Color(0xFFE7D3B8), Color(0xFFF7F1E6), Color(0xFFD7C4A4)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final ink = night ? const Color(0xFFF4EFE6) : const Color(0xFF1C212B);
    final line = Paint()
      ..color = ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = palette.copper.withValues(alpha: 0.28);
    // Stays in the right half so it never runs under the text on the left.
    final cell = math.min(size.width * 0.42 / 5, size.height / 7);
    final origin = Offset(size.width * 0.56, size.height * 0.16);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        final rect = Rect.fromLTWH(
          origin.dx + col * cell,
          origin.dy + row * cell,
          cell - 4,
          cell - 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          line,
        );
      }
    }
    _block(canvas, origin, cell, 0, 0, 2, 2, fill, line);
    _block(canvas, origin, cell, 0, 2, 1, 3, fill, line);
    _block(canvas, origin, cell, 2, 2, 2, 2, fill, line);

    final lamp = Offset(origin.dx + cell * 4.4, size.height * 0.86);
    final path = Path()
      ..moveTo(origin.dx + cell * 0.5, origin.dy + cell * 4.2)
      ..quadraticBezierTo(
        origin.dx + cell * 1.5,
        size.height * 0.9,
        lamp.dx,
        lamp.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.copper
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final pulse = 5 + glow * 3;
    canvas.drawCircle(
      lamp,
      pulse * 3,
      Paint()..color = palette.copper.withValues(alpha: 0.16 + glow * 0.08),
    );
    canvas.drawCircle(lamp, pulse, Paint()..color = palette.copper);
    _num(canvas, origin + Offset(cell * 0.7, cell * 0.85), '4', ink);
    _num(canvas, origin + Offset(cell * 2.55, cell * 0.85), '6', ink);
    _num(canvas, origin + Offset(cell * 3.2, cell * 2.7), '4', ink);
  }

  void _block(
    Canvas canvas,
    Offset origin,
    double cell,
    int row,
    int col,
    int rows,
    int cols,
    Paint fill,
    Paint line,
  ) {
    final rect = Rect.fromLTWH(
      origin.dx + col * cell,
      origin.dy + row * cell,
      cols * cell - 4,
      rows * cell - 4,
    );
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(shape, fill);
    canvas.drawRRect(shape, line);
  }

  void _num(Canvas canvas, Offset at, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant HeroWorldPainter oldDelegate) {
    return oldDelegate.glow != glow || oldDelegate.palette != palette;
  }
}

class ParcelArtPainter extends CustomPainter {
  ParcelArtPainter(this.palette);

  final RectoraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _wash(canvas, size, palette.copper);
    final cell = math.min(size.width / 6, size.height / 4.2);
    final origin = Offset(
      (size.width - cell * 5) / 2,
      (size.height - cell * 3.2) / 2,
    );
    final line = _line(palette.ink);
    final fill = Paint()..color = palette.copper.withValues(alpha: 0.45);
    _cells(canvas, origin, cell, 4, 3, line);
    _span(canvas, origin, cell, 0, 0, 2, 2, fill, line);
    _span(canvas, origin, cell, 0, 2, 1, 2, fill, line);
    _label(canvas, origin + Offset(cell, cell), '4', palette.ink);
    _label(canvas, origin + Offset(cell * 2.5, cell * 0.5), '2', palette.ink);
  }

  @override
  bool shouldRepaint(covariant ParcelArtPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class TraceArtPainter extends CustomPainter {
  TraceArtPainter(this.palette);

  final RectoraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _wash(canvas, size, palette.pine);
    final cell = math.min(size.width / 6, size.height / 4.2);
    final origin = Offset(
      (size.width - cell * 4) / 2,
      (size.height - cell * 3) / 2,
    );
    _cells(canvas, origin, cell, 4, 3, _line(palette.ink));
    final route = Path();
    final stops = [0, 1, 5, 6, 7, 11];
    for (var i = 0; i < stops.length; i++) {
      final point = _center(origin, cell, stops[i], 4);
      if (i == 0) {
        route.moveTo(point.dx, point.dy);
      } else {
        route.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      route,
      Paint()
        ..color = palette.copper
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _label(canvas, _center(origin, cell, 0, 4), '1', palette.ink);
    _label(canvas, _center(origin, cell, 5, 4), '2', palette.ink);
    _label(canvas, _center(origin, cell, 11, 4), '3', palette.ink);
  }

  @override
  bool shouldRepaint(covariant TraceArtPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class InkArtPainter extends CustomPainter {
  InkArtPainter(this.palette);

  final RectoraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _wash(canvas, size, regionFills[2]);
    final cell = math.min(size.width / 6, size.height / 4.2);
    final origin = Offset(
      (size.width - cell * 4) / 2,
      (size.height - cell * 3) / 2,
    );
    final line = _line(palette.ink);
    _cells(canvas, origin, cell, 4, 3, line);
    _fillCells(canvas, origin, cell, 4, const [0, 1, 4, 8], regionFills[0]);
    _fillCells(canvas, origin, cell, 4, const [2, 3, 7], regionFills[1]);
    _fillCells(canvas, origin, cell, 4, const [
      5,
      6,
      9,
      10,
      11,
    ], regionFills[3]);
    _label(canvas, _center(origin, cell, 4, 4), '4', numberInk);
    _label(canvas, _center(origin, cell, 3, 4), '3', numberInk);
    _label(canvas, _center(origin, cell, 10, 4), '5', numberInk);
  }

  @override
  bool shouldRepaint(covariant InkArtPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class ThreadArtPainter extends CustomPainter {
  ThreadArtPainter(this.palette);

  final RectoraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _wash(canvas, size, regionFills[4]);
    final cell = math.min(size.width / 6, size.height / 4.2);
    final origin = Offset(
      (size.width - cell * 4) / 2,
      (size.height - cell * 3) / 2,
    );
    _cells(canvas, origin, cell, 4, 3, _line(palette.ink));
    _thread(canvas, origin, cell, 4, const [0, 4, 5, 9], palette.copper, 'A');
    _thread(canvas, origin, cell, 4, const [3, 7, 6, 10], palette.pine, 'B');
  }

  void _thread(
    Canvas canvas,
    Offset origin,
    double cell,
    int cols,
    List<int> indexes,
    Color color,
    String mark,
  ) {
    final route = Path();
    for (var i = 0; i < indexes.length; i++) {
      final point = _center(origin, cell, indexes[i], cols);
      if (i == 0) {
        route.moveTo(point.dx, point.dy);
      } else {
        route.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      route,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _label(
      canvas,
      _center(origin, cell, indexes.first, cols),
      mark,
      palette.ink,
    );
    _label(
      canvas,
      _center(origin, cell, indexes.last, cols),
      mark,
      palette.ink,
    );
  }

  @override
  bool shouldRepaint(covariant ThreadArtPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

class DailyArtPainter extends CustomPainter {
  DailyArtPainter(this.palette, {required this.done});

  final RectoraPalette palette;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final color = done ? palette.pine : palette.copper;
    final center = Offset(size.width * 0.72, size.height * 0.5);
    canvas.drawCircle(
      center,
      size.height * 0.34,
      Paint()..color = color.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      center,
      size.height * 0.28,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final cell = size.height * 0.11;
    final origin = center - Offset(cell * 1.5, cell * 1.5);
    _cells(canvas, origin, cell, 3, 3, _line(palette.ink));
    if (done) {
      final mark = Path()
        ..moveTo(center.dx - cell * 0.7, center.dy)
        ..lineTo(center.dx - cell * 0.15, center.dy + cell * 0.55)
        ..lineTo(center.dx + cell * 0.8, center.dy - cell * 0.55);
      canvas.drawPath(
        mark,
        Paint()
          ..color = palette.pine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DailyArtPainter oldDelegate) {
    return oldDelegate.done != done || oldDelegate.palette != palette;
  }
}

class WeeklyArtPainter extends CustomPainter {
  WeeklyArtPainter(this.palette, {required this.filled, required this.total});

  final RectoraPalette palette;
  final int filled;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final count = total <= 0 ? 3 : total;
    final gap = size.width / (count + 1);
    final y = size.height * 0.55;
    final line = Paint()
      ..color = palette.copper.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    if (count > 1) {
      canvas.drawLine(Offset(gap, y), Offset(gap * count, y), line);
    }
    for (var i = 0; i < count; i++) {
      final center = Offset(gap * (i + 1), y);
      final active = i < filled;
      canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = active
              ? palette.copper
              : palette.ink.withValues(alpha: 0.08),
      );
      canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = palette.copper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final diamond = Path()
        ..moveTo(center.dx, center.dy - 6)
        ..lineTo(center.dx + 5, center.dy)
        ..lineTo(center.dx, center.dy + 6)
        ..lineTo(center.dx - 5, center.dy)
        ..close();
      canvas.drawPath(
        diamond,
        Paint()..color = active ? palette.copperInk : palette.copper,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyArtPainter oldDelegate) {
    return oldDelegate.filled != filled ||
        oldDelegate.total != total ||
        oldDelegate.palette != palette;
  }
}

void _wash(Canvas canvas, Size size, Color tint) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint.withValues(alpha: 0.28), tint.withValues(alpha: 0.05)],
      ).createShader(Offset.zero & size),
  );
}

Paint _line(Color color) {
  return Paint()
    ..color = color.withValues(alpha: 0.45)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
}

void _cells(
  Canvas canvas,
  Offset origin,
  double cell,
  int cols,
  int rows,
  Paint line,
) {
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx + col * cell,
            origin.dy + row * cell,
            cell - 3,
            cell - 3,
          ),
          const Radius.circular(3),
        ),
        line,
      );
    }
  }
}

void _span(
  Canvas canvas,
  Offset origin,
  double cell,
  int row,
  int col,
  int rows,
  int cols,
  Paint fill,
  Paint line,
) {
  final rect = Rect.fromLTWH(
    origin.dx + col * cell,
    origin.dy + row * cell,
    cols * cell - 3,
    rows * cell - 3,
  );
  final shape = RRect.fromRectAndRadius(rect, const Radius.circular(5));
  canvas.drawRRect(shape, fill);
  canvas.drawRRect(shape, line);
}

void _fillCells(
  Canvas canvas,
  Offset origin,
  double cell,
  int cols,
  List<int> indexes,
  Color color,
) {
  final paint = Paint()..color = color.withValues(alpha: 0.78);
  for (final index in indexes) {
    final row = index ~/ cols;
    final col = index % cols;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          origin.dx + col * cell,
          origin.dy + row * cell,
          cell - 3,
          cell - 3,
        ),
        const Radius.circular(3),
      ),
      paint,
    );
  }
}

Offset _center(Offset origin, double cell, int index, int cols) {
  final row = index ~/ cols;
  final col = index % cols;
  return origin +
      Offset(col * cell + (cell - 3) / 2, row * cell + (cell - 3) / 2);
}

void _label(Canvas canvas, Offset at, String text, Color color) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
}
