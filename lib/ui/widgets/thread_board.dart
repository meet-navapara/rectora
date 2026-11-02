import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/widgets/parcel_board.dart';

class ThreadBoard extends StatelessWidget {
  const ThreadBoard({
    super.key,
    required this.puzzle,
    required this.paths,
    required this.draft,
    required this.onDown,
    required this.onMove,
    required this.onUp,
    required this.onCancel,
  });

  final ThreadPuzzle puzzle;
  final List<ThreadPath> paths;
  final List<int> draft;
  final void Function(int index) onDown;
  final void Function(int index) onMove;
  final void Function(int index) onUp;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final save = RectoraScope.of(context).save;
    final palette = RectoraTheme.of(context)
        .forBoard(save.settings.boardStyle, save.xp);
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      label:
          'Thread grid, ${puzzle.rows} by ${puzzle.cols}, ${puzzle.pairs.length} pairs.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) =>
                    _hit(event.localPosition, side, false, onDown),
                onPointerMove: (event) =>
                    _hit(event.localPosition, side, true, onMove),
                onPointerUp: (event) =>
                    _hit(event.localPosition, side, true, onUp),
                onPointerCancel: (_) => onCancel(),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ThreadPainter(
                      puzzle: puzzle,
                      paths: paths,
                      draft: draft,
                      palette: palette,
                      textScaler: scaler,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _hit(
    Offset local,
    double side,
    bool clampOutside,
    void Function(int index) emit,
  ) {
    final metrics = BoardMetrics(
      rows: puzzle.rows,
      cols: puzzle.cols,
      size: Size.square(side),
    );
    final cell = metrics.cellAt(local, clampOutside: clampOutside);
    if (cell != null) emit(cell.$1 * puzzle.cols + cell.$2);
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter({
    required this.puzzle,
    required List<ThreadPath> paths,
    required List<int> draft,
    required this.palette,
    required this.textScaler,
  }) : paths = [
         for (final path in paths)
           ThreadPath(
             pairIndex: path.pairIndex,
             cells: List<int>.from(path.cells),
           ),
       ],
       draft = List<int>.from(draft);

  final ThreadPuzzle puzzle;
  final List<ThreadPath> paths;
  final List<int> draft;
  final RectoraPalette palette;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = BoardMetrics(
      rows: puzzle.rows,
      cols: puzzle.cols,
      size: size,
    );
    final blocked = puzzle.blocked.toSet();
    final radius = Radius.circular(math.max(4, metrics.cell * 0.16));
    for (var index = 0; index < puzzle.cellCount; index++) {
      final row = index ~/ puzzle.cols;
      final col = index % puzzle.cols;
      final rect = metrics.cellRect(row, col);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = blocked.contains(index)
              ? palette.line.withValues(alpha: 0.55)
              : palette.emptyCell,
      );
      if (blocked.contains(index)) {
        canvas.drawLine(
          rect.topLeft,
          rect.bottomRight,
          Paint()..color = palette.muted,
        );
      }
    }
    for (var i = 0; i < paths.length; i++) {
      _path(
        canvas,
        metrics,
        paths[i].cells,
        regionFills[i % regionFills.length],
        0.55,
      );
    }
    if (draft.length >= 2) {
      _path(canvas, metrics, draft, palette.copper, 0.9);
    }
    final scale = textScaler.scale(1).clamp(0.85, 1.4);
    for (final pair in puzzle.pairs) {
      _label(canvas, metrics, pair.a, pair.label, scale);
      _label(canvas, metrics, pair.b, pair.label, scale);
    }
  }

  void _path(
    Canvas canvas,
    BoardMetrics metrics,
    List<int> cells,
    Color color,
    double widthFactor,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(6, metrics.cell * 0.28 * widthFactor)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < cells.length; i++) {
      final center = metrics
          .cellRect(cells[i] ~/ puzzle.cols, cells[i] % puzzle.cols)
          .center;
      if (i == 0) {
        path.moveTo(center.dx, center.dy);
      } else {
        path.lineTo(center.dx, center.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _label(
    Canvas canvas,
    BoardMetrics metrics,
    int index,
    String label,
    double scale,
  ) {
    final cell = metrics.cellRect(index ~/ puzzle.cols, index % puzzle.cols);
    canvas.drawCircle(
      cell.center,
      metrics.cell * 0.28,
      Paint()..color = palette.surface,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: palette.ink,
          fontWeight: FontWeight.w800,
          fontSize: math.min(metrics.cell * 0.34 * scale, metrics.cell * 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      cell.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ThreadPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.textScaler != textScaler ||
        !_samePaths(oldDelegate.paths, paths) ||
        !_sameInts(oldDelegate.draft, draft);
  }
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _samePaths(List<ThreadPath> left, List<ThreadPath> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i].pairIndex != right[i].pairIndex) return false;
    if (!_sameInts(left[i].cells, right[i].cells)) return false;
  }
  return true;
}
