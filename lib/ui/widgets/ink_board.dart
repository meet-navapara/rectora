import 'package:flutter/material.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/theme/palette.dart';

class InkBoard extends StatelessWidget {
  const InkBoard({
    super.key,
    required this.puzzle,
    required this.regions,
    required this.draft,
    required this.draftValid,
    required this.onCell,
  });

  final InkPuzzle puzzle;
  final List<InkRegion> regions;
  final List<int> draft;
  final bool? draftValid;
  final void Function(int cell, {required bool moving}) onCell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final unit =
            side / (puzzle.cols > puzzle.rows ? puzzle.cols : puzzle.rows);
        return Center(
          child: SizedBox(
            width: unit * puzzle.cols,
            height: unit * puzzle.rows,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) =>
                  onCell(_cell(event.localPosition, unit), moving: false),
              onPointerMove: (event) =>
                  onCell(_cell(event.localPosition, unit), moving: true),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _InkPainter(
                    puzzle: puzzle,
                    regions: regions,
                    draft: draft,
                    draftValid: draftValid,
                    palette: RectoraTheme.of(context),
                    cell: unit,
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

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.puzzle,
    required List<InkRegion> regions,
    required List<int> draft,
    required this.draftValid,
    required this.palette,
    required this.cell,
  }) : regions = [
         for (final region in regions) InkRegion(List<int>.from(region.cells)),
       ],
       draft = List<int>.from(draft);

  final InkPuzzle puzzle;
  final List<InkRegion> regions;
  final List<int> draft;
  final bool? draftValid;
  final RectoraPalette palette;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = palette.surfaceHigh;
    for (var row = 0; row < puzzle.rows; row++) {
      for (var col = 0; col < puzzle.cols; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(col * cell + 2, row * cell + 2, cell - 4, cell - 4),
            Radius.circular(cell * 0.12),
          ),
          base,
        );
      }
    }
    for (var i = 0; i < regions.length; i++) {
      final paint = Paint()..color = regionFills[i % regionFills.length];
      for (final index in regions[i].cells) {
        _cellRect(canvas, index, paint);
      }
    }
    if (draft.isNotEmpty) {
      final paint = Paint()
        ..color = (draftValid ?? false ? palette.pine : palette.rose)
            .withValues(alpha: 0.55);
      for (final index in draft) {
        _cellRect(canvas, index, paint);
      }
    }
    for (final clue in puzzle.clues) {
      final text = TextPainter(
        text: TextSpan(
          text: '${clue.value}',
          style: TextStyle(
            color: palette.ink,
            fontSize: cell * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final origin = Offset(
        (clue.col + 0.5) * cell - text.width / 2,
        (clue.row + 0.5) * cell - text.height / 2,
      );
      text.paint(canvas, origin);
    }
  }

  void _cellRect(Canvas canvas, int index, Paint paint) {
    final row = index ~/ puzzle.cols;
    final col = index % puzzle.cols;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(col * cell + 2, row * cell + 2, cell - 4, cell - 4),
        Radius.circular(cell * 0.12),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.cell != cell ||
        oldDelegate.draftValid != draftValid ||
        !_sameRegions(oldDelegate.regions, regions) ||
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

bool _sameRegions(List<InkRegion> left, List<InkRegion> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (!_sameInts(left[i].cells, right[i].cells)) return false;
  }
  return true;
}
