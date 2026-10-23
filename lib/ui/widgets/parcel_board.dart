import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';

class BoardMetrics {
  BoardMetrics({required this.rows, required this.cols, required this.size});

  final int rows;
  final int cols;
  final Size size;

  double get cell => math.min(size.width / cols, size.height / rows);
  double get gap => math.max(2.0, cell * 0.07);

  Offset get origin =>
      Offset((size.width - cell * cols) / 2, (size.height - cell * rows) / 2);

  Rect cellRect(int row, int col) {
    return Rect.fromLTWH(
      origin.dx + col * cell + gap / 2,
      origin.dy + row * cell + gap / 2,
      cell - gap,
      cell - gap,
    );
  }

  Rect span(int r1, int c1, int r2, int c2) {
    final first = cellRect(r1, c1);
    final last = cellRect(r2, c2);
    return Rect.fromLTRB(first.left, first.top, last.right, last.bottom);
  }

  (int, int)? cellAt(Offset position, {required bool clampOutside}) {
    final local = position - origin;
    final past =
        local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= cell * cols ||
        local.dy >= cell * rows;
    if (past && !clampOutside) return null;
    final col = (local.dx / cell).floor().clamp(0, cols - 1);
    final row = (local.dy / cell).floor().clamp(0, rows - 1);
    return (row, col);
  }
}

class ParcelBoard extends StatelessWidget {
  const ParcelBoard({
    super.key,
    required this.puzzle,
    required this.placed,
    required this.preview,
    required this.highlight,
    required this.onDown,
    required this.onMove,
    required this.onUp,
    required this.onCancel,
  });

  final ParcelPuzzle puzzle;
  final List<GridRect> placed;
  final GridRect? preview;
  final GridRect? highlight;
  final void Function(int row, int col) onDown;
  final void Function(int row, int col) onMove;
  final void Function(int row, int col) onUp;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final save = RectoraScope.of(context).save;
    final accent = _boardAccent(palette, save.settings.boardStyle, save.xp);
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      label:
          'Parcel grid, ${puzzle.rows} by ${puzzle.cols}, ${puzzle.clues.length} clues.',
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
                    painter: _ParcelPainter(
                      puzzle: puzzle,
                      placed: placed,
                      preview: preview,
                      highlight: highlight,
                      palette: palette,
                      accent: accent,
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
    void Function(int row, int col) emit,
  ) {
    final metrics = BoardMetrics(
      rows: puzzle.rows,
      cols: puzzle.cols,
      size: Size.square(side),
    );
    final cell = metrics.cellAt(local, clampOutside: clampOutside);
    if (cell != null) emit(cell.$1, cell.$2);
  }
}

class _ParcelPainter extends CustomPainter {
  _ParcelPainter({
    required this.puzzle,
    required this.placed,
    required this.preview,
    required this.highlight,
    required this.palette,
    required this.accent,
    required this.textScaler,
  });

  final ParcelPuzzle puzzle;
  final List<GridRect> placed;
  final GridRect? preview;
  final GridRect? highlight;
  final RectoraPalette palette;
  final Color accent;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = BoardMetrics(
      rows: puzzle.rows,
      cols: puzzle.cols,
      size: size,
    );
    final radius = Radius.circular(math.max(4, metrics.cell * 0.16));
    for (var row = 0; row < puzzle.rows; row++) {
      for (var col = 0; col < puzzle.cols; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(metrics.cellRect(row, col), radius),
          Paint()..color = palette.emptyCell,
        );
      }
    }
    if (preview != null) {
      final fill = regionFills[placed.length % regionFills.length];
      _region(canvas, metrics, preview!, fill, fill);
    }
    for (var i = 0; i < placed.length; i++) {
      _region(
        canvas,
        metrics,
        placed[i],
        regionFills[i % regionFills.length],
        regionFills[i % regionFills.length],
      );
    }
    if (highlight != null) {
      _region(
        canvas,
        metrics,
        highlight!,
        accent.withValues(alpha: 0.28),
        accent,
      );
    }
    final scale = textScaler.scale(1).clamp(0.85, 1.45);
    for (final clue in puzzle.clues) {
      final covered =
          placed.any((rect) => rect.containsCell(clue.row, clue.col)) ||
          (preview?.containsCell(clue.row, clue.col) ?? false);
      final painter = TextPainter(
        text: TextSpan(
          text: '${clue.value}',
          style: TextStyle(
            color: covered ? numberInk : palette.ink,
            fontSize: math.min(
              metrics.cell * 0.42 * scale,
              metrics.cell * 0.62,
            ),
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: metrics.cell);
      final cell = metrics.cellRect(clue.row, clue.col);
      painter.paint(
        canvas,
        cell.center - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  void _region(
    Canvas canvas,
    BoardMetrics metrics,
    GridRect rect,
    Color fill,
    Color stroke,
  ) {
    final bounds = metrics.span(rect.r1, rect.c1, rect.r2, rect.c2);
    final rrect = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(math.max(6, metrics.cell * 0.18)),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, metrics.cell * 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant _ParcelPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        !_sameRects(oldDelegate.placed, placed) ||
        oldDelegate.preview != preview ||
        oldDelegate.highlight != highlight ||
        oldDelegate.palette != palette ||
        oldDelegate.textScaler != textScaler;
  }
}

bool _sameRects(List<GridRect> left, List<GridRect> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

Color _boardAccent(RectoraPalette palette, String style, int xp) {
  if (!styleUnlocked(xp, style)) return palette.copper;
  return switch (style) {
    'ivory' => const Color(0xFFF3E6C8),
    'pine' => palette.pine,
    'archive' => const Color(0xFFD6B15E),
    _ => palette.copper,
  };
}
