import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/domain/tutorial/progress.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/home/home_motion.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/widgets/dialogs.dart';

enum TutorialWait { none, placed, solved }

enum TutorialResult { finished, skipped }

class TutorialStep {
  const TutorialStep(
    this.title,
    this.body, {
    this.example,
    this.wait = TutorialWait.none,
  });

  final String title;
  final String body;
  final String? example;
  final TutorialWait wait;
}

const parcelTutorial = [
  TutorialStep(
    'Cover the grid',
    'The goal is to cover every square with rectangles.',
    example: 'parcel-cover',
  ),
  TutorialStep(
    'Numbers tell you the size',
    'A number is how many squares belong in its rectangle.',
    example: 'parcel-area',
  ),
  TutorialStep(
    'Make a rectangle',
    'Press an empty square and drag to the opposite corner. Then let go.',
    example: 'parcel-drag',
    wait: TutorialWait.placed,
  ),
  TutorialStep(
    'One number in each rectangle',
    'Each rectangle holds one number, and that number matches its size.',
  ),
  TutorialStep(
    'No overlaps or empty squares',
    'Rectangles cannot cover the same square. Every square must be covered.',
    wait: TutorialWait.solved,
  ),
  TutorialStep(
    'You solved it',
    'The board is covered. You can replay this lesson any time from Help.',
  ),
];

const traceTutorial = [
  TutorialStep(
    'Start at 1',
    'Trace is one path. It begins on the square marked 1.',
    example: 'trace-order',
  ),
  TutorialStep(
    'Move to a touching square',
    'Drag up, down, left, or right. A diagonal jump is ignored.',
    example: 'trace-edge',
    wait: TutorialWait.placed,
  ),
  TutorialStep(
    'Keep the numbers in order',
    'Reach 2 before 3, and do not visit a square twice.',
  ),
  TutorialStep(
    'Cover every open square',
    'The path is finished when every open square is on it. '
        'A crossed-out square is closed: leave it empty.',
    example: 'trace-cover',
    wait: TutorialWait.solved,
  ),
  TutorialStep(
    'You solved it',
    'The path is complete. Replay this lesson from Help.',
  ),
];

const inkTutorial = [
  TutorialStep(
    'Each number owns a group',
    'A group is a set of touching squares. It may bend. It does not have to be a rectangle.',
    example: 'ink-bend',
  ),
  TutorialStep(
    'Match the number',
    'The group contains that many squares and no other number.',
    wait: TutorialWait.placed,
  ),
  TutorialStep(
    'Drag through touching squares',
    'Press a square and drag into squares that share a side. Then let go.',
    example: 'ink-drag',
  ),
  TutorialStep(
    'Cover every square once',
    'Groups cannot overlap. The board is done when no square is left open.',
    example: 'ink-cover',
    wait: TutorialWait.solved,
  ),
  TutorialStep(
    'You solved it',
    'Every group matches its number. Replay this lesson from Help.',
  ),
];

const threadTutorial = [
  TutorialStep(
    'Find the matching letters',
    'Each letter appears twice. Those two squares belong together.',
  ),
  TutorialStep(
    'Join one pair',
    'Press one letter and drag to its match. Move up, down, left, or right.',
    wait: TutorialWait.placed,
  ),
  TutorialStep(
    'Do not cross',
    'Paths cannot cross, reuse a square, or enter a blocked square.',
  ),
  TutorialStep(
    'Cover the open board',
    'Join every pair. Every open square belongs to one path.',
    wait: TutorialWait.solved,
  ),
  TutorialStep(
    'You solved it',
    'Every pair is joined. Replay this lesson from Help.',
  ),
];

Future<TutorialResult> showTutorial(
  BuildContext context,
  List<TutorialStep> steps, {
  bool requiredSteps = false,
}) async {
  final result = await showGeneralDialog<TutorialResult>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Lesson',
    pageBuilder: (context, _, _) =>
        _TutorialDialog(steps: steps, requiredSteps: requiredSteps),
  );
  return result ?? TutorialResult.skipped;
}

/// Shows every lesson step in a popup. The level behind it stays locked
/// until the last step is finished.
class TutorialGate extends StatefulWidget {
  const TutorialGate({
    super.key,
    required this.active,
    required this.mode,
    required this.steps,
    required this.child,
  });

  final bool active;
  final String mode;
  final List<TutorialStep> steps;
  final Widget child;

  @override
  State<TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<TutorialGate> {
  var ready = false;
  var opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (opening) return;
    opening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    final controller = RectoraScope.read(context);
    final show =
        widget.active &&
        !tutorialSettled(controller.save.tutorialsSeen, widget.mode);
    if (!show) {
      setState(() => ready = true);
      return;
    }
    final result = await showTutorial(
      context,
      widget.steps,
      requiredSteps: true,
    );
    if (!mounted) return;
    if (result == TutorialResult.finished) {
      await controller.seeTutorial(widget.mode);
    }
    if (!mounted) return;
    setState(() => ready = result == TutorialResult.finished);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(ignoring: !ready, child: widget.child);
  }
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({required this.steps, required this.requiredSteps});

  final List<TutorialStep> steps;
  final bool requiredSteps;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog>
    with SingleTickerProviderStateMixin {
  var index = 0;
  late final AnimationController motion;

  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!homeMotionEnabled(context)) {
      motion.value = 1;
    } else if (!motion.isAnimating && motion.value == 0) {
      motion.forward();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  void _go(int next) {
    setState(() => index = next);
    if (!homeMotionEnabled(context)) return;
    motion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[index];
    final last = index == widget.steps.length - 1;
    return PopScope(
      canPop: !widget.requiredSteps,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: motion,
            child: _LessonCard(
              step: step,
              index: index,
              count: widget.steps.length,
              canContinue: true,
              continueLabel: last
                  ? (widget.requiredSteps ? 'Play level' : 'Done')
                  : 'Continue',
              onBack: index == 0 ? null : () => _go(index - 1),
              onContinue: () {
                if (last) {
                  Navigator.pop(context, TutorialResult.finished);
                } else {
                  _go(index + 1);
                }
              },
              onSkip: widget.requiredSteps
                  ? null
                  : () => Navigator.pop(context, TutorialResult.skipped),
            ),
          ),
        ),
      ),
    );
  }
}

class TutorialDock extends StatelessWidget {
  const TutorialDock({
    super.key,
    required this.visible,
    required this.steps,
    required this.acted,
    required this.solved,
    required this.onDone,
  });

  final bool visible;
  final List<TutorialStep> steps;
  final bool acted;
  final bool solved;
  final Future<void> Function(bool skipped) onDone;

  @override
  Widget build(BuildContext context) {
    if (!visible || steps.isEmpty) return const SizedBox.shrink();
    return _Dock(steps: steps, acted: acted, solved: solved, onDone: onDone);
  }
}

class _Dock extends StatefulWidget {
  const _Dock({
    required this.steps,
    required this.acted,
    required this.solved,
    required this.onDone,
  });

  final List<TutorialStep> steps;
  final bool acted;
  final bool solved;
  final Future<void> Function(bool skipped) onDone;

  @override
  State<_Dock> createState() => _DockState();
}

class _DockState extends State<_Dock> {
  var index = 0;
  var closing = false;

  Future<void> _finish(bool skipped) async {
    if (closing) return;
    closing = true;
    await widget.onDone(skipped);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[index];
    final last = index == widget.steps.length - 1;
    final waiting = switch (step.wait) {
      TutorialWait.placed => !widget.acted,
      TutorialWait.solved => !widget.solved,
      TutorialWait.none => false,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: _LessonCard(
        step: step,
        index: index,
        count: widget.steps.length,
        canContinue: true,
        note: waiting
            ? 'Try it on the board, or continue to the next step.'
            : null,
        continueLabel: last ? 'Done' : 'Continue',
        onBack: index == 0 ? null : () => setState(() => index -= 1),
        onContinue: () {
          if (last) {
            _finish(false);
          } else {
            setState(() => index += 1);
          }
        },
        onSkip: () => _finish(true),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.step,
    required this.index,
    required this.count,
    required this.canContinue,
    this.note,
    required this.continueLabel,
    required this.onBack,
    required this.onContinue,
    this.onSkip,
  });

  final TutorialStep step;
  final int index;
  final int count;
  final bool canContinue;
  final String? note;
  final String continueLabel;
  final VoidCallback? onBack;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Material(
      color: palette.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step ${index + 1} of $count',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: palette.copper),
            ),
            const SizedBox(height: 4),
            Text(step.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(step.body, style: Theme.of(context).textTheme.bodyLarge),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(note!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (step.example != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: CustomPaint(
                  painter: _ExamplePainter(step.example!, palette),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (onBack != null)
                  TextButton(onPressed: onBack, child: const Text('Back')),
                const Spacer(),
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    child: const Text('Skip lesson'),
                  ),
                if (onSkip != null) const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.copper,
                    foregroundColor: palette.copperInk,
                  ),
                  onPressed: canContinue ? onContinue : null,
                  child: Text(continueLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showModeHelp({
  required BuildContext context,
  required String objective,
  required String gestures,
  required String mistakes,
  required List<TutorialStep> lesson,
}) async {
  final action = await showRectoraDialog<String>(
    context: context,
    title: 'How to play',
    body: '$objective\n\n$gestures\n\n$mistakes',
    choices: [
      const DialogChoice(
        label: 'Replay lesson',
        value: 'replay',
        primary: true,
      ),
      const DialogChoice(label: 'Close', value: 'close'),
    ],
  );
  if (!context.mounted || action != 'replay') return;
  await showTutorial(context, lesson);
}

/// True when the player may take a hint: the free one, or one paid for by a
/// finished rewarded ad.
Future<bool> claimHint(BuildContext context, int used) async {
  if (used < freeHintsPerPuzzle) return true;
  if (!Ads.canOfferReward) {
    await showRectoraDialog<bool>(
      context: context,
      title: 'No hints left',
      body: 'Each puzzle has one free hint, and this one is used.',
      choices: const [DialogChoice(label: 'OK', value: true, primary: true)],
    );
    return false;
  }
  final watch = await showRectoraDialog<bool>(
    context: context,
    title: 'No free hints left',
    body: 'Each puzzle has one free hint. A short ad can give you another.',
    choices: const [
      DialogChoice(label: 'Watch ad', value: true, primary: true),
      DialogChoice(label: 'Not now', value: false),
    ],
  );
  if (!context.mounted || watch != true) return false;
  final granted = await Ads.grantRewarded();
  if (!granted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The ad did not finish, so no hint was added.'),
      ),
    );
  }
  return granted;
}

/// Skipping has a limit, so a hard level cannot be stepped over forever.
Future<bool> allowSkip(BuildContext context, PlayMode mode) async {
  final left = RectoraScope.read(context).save.skipsLeft(mode);
  if (left > 0) return true;
  await showRectoraDialog<bool>(
    context: context,
    title: 'No skips left',
    body:
        'Each mode can have $skipAllowance skipped levels at a time. Go back and solve one to skip again.',
    choices: const [DialogChoice(label: 'OK', value: true, primary: true)],
  );
  return false;
}

class _ExamplePainter extends CustomPainter {
  _ExamplePainter(this.kind, this.palette);

  final String kind;
  final RectoraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 3;
    final side = math.min(size.width, size.height);
    final origin = Offset((size.width - side) / 2, 0);
    final cell = side / count;
    final fills = <int, Color>{};
    final numbers = <int, String>{};
    final path = <int>[];
    final copper = palette.copper.withValues(alpha: 0.45);
    final pine = palette.pine.withValues(alpha: 0.45);
    switch (kind) {
      case 'parcel-area':
      case 'parcel-drag':
        fills.addAll({0: copper, 1: copper, 3: copper, 4: copper});
        numbers[0] = '4';
        break;
      case 'parcel-cover':
        fills.addAll({
          0: copper,
          1: copper,
          3: copper,
          4: copper,
          2: pine,
          5: pine,
          6: pine,
          7: pine,
          8: pine,
        });
        numbers[0] = '4';
        numbers[2] = '5';
        break;
      case 'trace-order':
        numbers.addAll({0: '1', 4: '2', 8: '3'});
        break;
      case 'trace-edge':
        path.addAll([0, 1, 4, 5, 8]);
        numbers.addAll({0: '1', 4: '2', 8: '3'});
        break;
      case 'trace-cover':
        path.addAll([0, 1, 2, 5, 4, 3, 6, 7, 8]);
        numbers.addAll({0: '1', 4: '2', 8: '3'});
        break;
      case 'ink-bend':
      case 'ink-drag':
        fills.addAll({0: copper, 1: copper, 4: copper});
        numbers[0] = '3';
        break;
      case 'ink-cover':
        fills.addAll({
          0: copper,
          1: copper,
          4: copper,
          3: pine,
          2: palette.rose.withValues(alpha: 0.4),
          5: palette.rose.withValues(alpha: 0.4),
          6: palette.rose.withValues(alpha: 0.4),
          7: palette.rose.withValues(alpha: 0.4),
          8: palette.rose.withValues(alpha: 0.4),
        });
        numbers.addAll({0: '3', 3: '1', 8: '5'});
        break;
      default:
        break;
    }
    final fill = Paint();
    for (final entry in fills.entries) {
      fill.color = entry.value;
      canvas.drawRect(_rect(origin, cell, entry.key), fill);
    }
    if (path.length > 1) {
      final line = Path();
      for (var i = 0; i < path.length; i++) {
        final point = _center(origin, cell, path[i]);
        if (i == 0) {
          line.moveTo(point.dx, point.dy);
        } else {
          line.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = palette.copper
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.16
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final grid = Paint()
      ..color = palette.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var index = 0; index < count * count; index++) {
      canvas.drawRect(_rect(origin, cell, index), grid);
    }
    for (final entry in numbers.entries) {
      final painter = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: TextStyle(
            color: palette.ink,
            fontSize: cell * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final center = _center(origin, cell, entry.key);
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  Rect _rect(Offset origin, double cell, int index) {
    final row = index ~/ 3;
    final col = index % 3;
    return Rect.fromLTWH(
      origin.dx + col * cell,
      origin.dy + row * cell,
      cell,
      cell,
    );
  }

  Offset _center(Offset origin, double cell, int index) {
    return _rect(origin, cell, index).center;
  }

  @override
  bool shouldRepaint(covariant _ExamplePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.palette != palette;
  }
}
