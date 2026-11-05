import 'package:flutter/material.dart';
import 'package:rectora/domain/trace/engine.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';

class TraceBoard extends StatelessWidget {
  const TraceBoard({
    super.key,
    required this.puzzle,
    required this.path,
    required this.onCell,
    this.onPress,
    this.onRelease,
  });

  final TracePuzzle puzzle;
  final List<int> path;
  final ValueChanged<int> onCell;
  final ValueChanged<int>? onPress;
  final VoidCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final cell =
            side / (puzzle.cols > puzzle.rows ? puzzle.cols : puzzle.rows);
        final width = cell * puzzle.cols;
        final height = cell * puzzle.rows;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                final index = _cell(event.localPosition, cell);
                if (onPress != null) {
                  onPress!(index);
                } else {
                  onCell(index);
                }
              },
              onPointerMove: (event) =>
                  onCell(_cell(event.localPosition, cell)),
              onPointerUp: (_) => onRelease?.call(),
              onPointerCancel: (_) => onRelease?.call(),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _TracePainter(
                    puzzle: puzzle,
                    path: path,
                    palette: RectoraTheme.of(context).forBoard(
                      RectoraScope.of(context).save.settings.boardStyle,
                      RectoraScope.of(context).save.xp,
                    ),
                    cell: cell,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _cell(Offset position, double cell) {
    final col = (position.dx / cell).floor().clamp(0, puzzle.cols - 1);
    final row = (position.dy / cell).floor().clamp(0, puzzle.rows - 1);
    return puzzle.index(row, col);
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.puzzle,
    required List<int> path,
    required this.palette,
    required this.cell,
  }) : path = List<int>.from(path);

  final TracePuzzle puzzle;
  final List<int> path;
  final RectoraPalette palette;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = palette.surfaceHigh;
    final line = Paint()
      ..color = palette.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final closed = puzzle.blocked.toSet();
    final closedFill = Paint()..color = palette.surface;
    final cross = Paint()
      ..color = palette.muted
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * 0.06;
    for (var row = 0; row < puzzle.rows; row++) {
      for (var col = 0; col < puzzle.cols; col++) {
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
        if (closed.contains(puzzle.index(row, col))) {
          // A closed square is not part of the route: draw it sunk and
          // crossed out so nobody mistakes it for a square left to fill.
          canvas.drawRect(rect.deflate(1), closedFill);
          canvas.drawRect(rect.deflate(1), line);
          final mark = rect.deflate(cell * 0.3);
          canvas.drawLine(mark.topLeft, mark.bottomRight, cross);
          canvas.drawLine(mark.topRight, mark.bottomLeft, cross);
          continue;
        }
        canvas.drawRect(rect.deflate(1), fill);
        canvas.drawRect(rect.deflate(1), line);
      }
    }
    if (path.length > 1) {
      final paint = Paint()
        ..color = palette.copper
        ..strokeWidth = cell * 0.18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final route = Path();
      for (var i = 0; i < path.length; i++) {
        final point = _center(path[i]);
        if (i == 0) {
          route.moveTo(point.dx, point.dy);
        } else {
          route.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(route, paint);
    }
    for (var i = 0; i < puzzle.checkpoints.length; i++) {
      final point = _center(puzzle.checkpoints[i]);
      canvas.drawCircle(point, cell * 0.28, Paint()..color = palette.surface);
      canvas.drawCircle(
        point,
        cell * 0.28,
        Paint()
          ..color = palette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: palette.ink,
            fontSize: cell * 0.32,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
    }
  }

  Offset _center(int index) {
    final (row, col) = puzzle.cellOf(index);
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.cell != cell ||
        !_sameInts(oldDelegate.path, path);
  }
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
