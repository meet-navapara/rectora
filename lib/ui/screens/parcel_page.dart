import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/common/date_key.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/domain/parcels/session.dart';
import 'package:rectora/domain/tutorial/coach.dart';
import 'package:rectora/domain/work/background.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/coach/guide_view.dart';
import 'package:rectora/ui/feedback_player.dart';
import 'package:rectora/ui/home/home_motion.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/settings_page.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/ui/tutorial.dart';
import 'package:rectora/ui/widgets/dialogs.dart';
import 'package:rectora/ui/widgets/parcel_board.dart';
import 'package:rectora/ui/widgets/play_clock.dart';

class ParcelPage extends StatefulWidget {
  const ParcelPage({
    super.key,
    required this.level,
    this.dailyDate,
    this.weekly = false,
  });

  final ParcelLevel level;
  final DateTime? dailyDate;
  final bool weekly;

  @override
  State<ParcelPage> createState() => _ParcelPageState();
}

class _ParcelPageState extends State<ParcelPage> with WidgetsBindingObserver {
  final feedback = FeedbackPlayer();
  late ParcelSession session;
  DateTime? runningSince;
  int bankedMs = 0;
  GridRect? anchor;
  GridRect? preview;
  GridRect? highlight;
  var erase = false;
  var finishing = false;
  var busy = false;
  String? notice;
  String? checkingLabel;
  PlayCoach? coach;
  var _shownDemo = -1;

  String get storageId {
    if (widget.dailyDate != null) return 'daily@${dateKey(widget.dailyDate!)}';
    if (widget.weekly) return 'weekly@${widget.level.id}';
    return widget.level.id;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final save = RectoraScope.read(context).save;
    final draft = save.drafts[storageId];
    final guide = shouldGuideLevel(
      number: widget.level.number,
      campaignLevel: widget.dailyDate == null && !widget.weekly,
      seen: save.tutorialsSeen,
      modeId: 'parcels',
    );
    if (guide) {
      coach = PlayCoach(
        parcelGuide(
          number: widget.level.number,
          solution: widget.level.solution,
          cols: widget.level.puzzle.cols,
        ),
        hintCopy: parcelHintCopy,
      );
    }
    session = ParcelSession(
      puzzle: widget.level.puzzle,
      strictness: strictnessFor(widget.level.difficulty),
      draft: guide
          ? null
          : [
              for (final move in draft?.moves ?? const <List<int>>[])
                if (move.length == 4)
                  GridRect(move[0], move[1], move[2], move[3]),
            ],
      hintsUsed: guide ? 0 : draft?.hintsUsed ?? 0,
    );
    bankedMs = draft?.elapsedMs ?? 0;
    runningSince = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = RectoraScope.read(context);
      controller.markStarted(id: storageId, thread: false);
      if (session.discardedDraft && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved moves for this puzzle were damaged and cleared.',
            ),
          ),
        );
      }
      if (session.isComplete) {
        _checkComplete();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feedback.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      runningSince ??= DateTime.now();
    } else {
      _bank();
    }
    if (mounted) setState(() {});
  }

  void _bank() {
    if (runningSince == null) return;
    bankedMs += DateTime.now().difference(runningSince!).inMilliseconds;
    runningSince = null;
  }

  int get elapsedMs {
    final running = runningSince == null
        ? 0
        : DateTime.now().difference(runningSince!).inMilliseconds;
    return bankedMs + running;
  }

  String get clockLabel {
    final total = elapsedMs ~/ 1000;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _persist() async {
    final controller = RectoraScope.read(context);
    await controller.saveDraft(
      id: storageId,
      draft: session.placed.isEmpty
          ? null
          : PuzzleDraft(
              elapsedMs: elapsedMs,
              hintsUsed: session.hintsUsed,
              moves: [for (final rect in session.placed) rect.toList()],
            ),
    );
  }

  void _down(int row, int col) {
    if (busy || coach?.locksInput == true) return;
    coach?.hidePointer();
    final settings = RectoraScope.read(context).save.settings;
    if (session.placed.any((rect) => rect.containsCell(row, col))) {
      if (session.eraseAt(row, col)) {
        feedback.tap(settings);
        setState(() => notice = null);
        _persist();
      }
      return;
    }
    if (erase) return;
    if (settings.cornerPlacement) {
      if (anchor == null) {
        setState(() {
          notice = null;
          anchor = GridRect(row, col, row, col);
        });
        return;
      }
      final rect = GridRect.fromCorners(anchor!.r1, anchor!.c1, row, col);
      setState(() => anchor = null);
      _commit(rect);
      return;
    }
    setState(() {
      notice = null;
      anchor = GridRect(row, col, row, col);
      preview = anchor;
    });
  }

  void _move(int row, int col) {
    if (busy ||
        anchor == null ||
        RectoraScope.read(context).save.settings.cornerPlacement) {
      return;
    }
    final rect = GridRect.fromCorners(anchor!.r1, anchor!.c1, row, col);
    if (preview == rect) return;
    setState(() {
      preview = rect;
    });
  }

  void _up(int row, int col) {
    if (busy ||
        anchor == null ||
        RectoraScope.read(context).save.settings.cornerPlacement) {
      return;
    }
    final rect = GridRect.fromCorners(anchor!.r1, anchor!.c1, row, col);
    setState(() {
      anchor = null;
      preview = null;
    });
    _commit(rect);
  }

  Future<void> _commit(GridRect rect) async {
    if (busy) return;
    busy = true;
    final PlacementIssue decided;
    try {
      final guided = coach?.expectsMove == true;
      decided = session.commit(
        rect,
        rules: guided ? Strictness.basic : null,
        solveDeadEnds: guided ? false : null,
      );
    } finally {
      busy = false;
    }
    if (!mounted) return;
    final settings = RectoraScope.read(context).save.settings;
    if (decided == PlacementIssue.ok) {
      final lesson = coach;
      if (lesson != null && lesson.expectsMove) {
        final kept = lesson.judge(rectCells(rect, widget.level.puzzle.cols));
        if (!kept) {
          session.undo();
          if (!mounted) return;
          setState(() => notice = lesson.correction);
          return;
        }
      }
      highlight = null;
      await feedback.place(settings);
      if (!mounted) return;
      setState(() => notice = null);
      await _persist();
      if (session.isComplete) coach?.markSolved();
      await _checkComplete();
      return;
    }
    if (decided == PlacementIssue.deadEnd) {
      if (!mounted) return;
      setState(() => notice = null);
      return;
    }
    await feedback.error(settings);
    if (!mounted) return;
    setState(() => notice = _issueText(decided, rect));
  }

  String _issueText(PlacementIssue issue, GridRect rect) {
    final area = rect.area;
    switch (issue) {
      case PlacementIssue.outOfBounds:
        return 'That rectangle leaves the board.';
      case PlacementIssue.degenerate:
        return 'Drag across at least one cell.';
      case PlacementIssue.clueCount:
        return 'A rectangle must contain exactly one number.';
      case PlacementIssue.valueMismatch:
        return 'This rectangle covers $area cells. The number inside it asks for a different area.';
      case PlacementIssue.overlap:
        return 'That overlaps a rectangle already on the board.';
      case PlacementIssue.deadEnd:
        return 'The area matches the number, but the remaining numbers would have no legal rectangle. On this difficulty that move is refused.';
      case PlacementIssue.malformed:
        return 'This puzzle data cannot be played.';
      case PlacementIssue.ok:
        return 'Placed.';
    }
  }

  Future<void> _checkComplete() async {
    if (finishing || !session.claimCompletion()) return;
    finishing = true;
    _bank();
    final controller = RectoraScope.read(context);
    final xpBefore = controller.save.xp;
    final record = await controller.finishLevel(
      id: storageId,
      thread: false,
      skipped: false,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    var firstDaily = false;
    if (widget.dailyDate != null) {
      firstDaily = await controller.completeDaily(widget.dailyDate!);
    }
    if (widget.weekly) await controller.noteWeekly(widget.level.id);
    if (widget.level.tutorial && widget.level.number >= 2) {
      await controller.seeTutorial('parcels');
    }
    if (!mounted) return;
    await feedback.complete(controller.save.settings);
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    if (!mounted) return;
    await _completeDialog(record, firstDaily, controller.save.xp - xpBefore);
  }

  Future<void> _completeDialog(
    LevelRecord record,
    bool firstDaily,
    int xpGained,
  ) async {
    final controller = RectoraScope.read(context);
    final next = widget.dailyDate == null && !widget.weekly
        ? controller.nextParcel(widget.level.id)
        : null;
    final choice = await showRectoraDialog<String>(
      context: context,
      barrierDismissible: false,
      title: widget.dailyDate == null ? 'Parcel complete' : 'Daily complete',
      body: [
        completionBody(
          time: clockLabel,
          hints: session.hintsUsed,
          difficulty: widget.level.difficulty,
          xpGained: xpGained,
          bestMs: record.bestMs,
        ),
        if (widget.dailyDate != null && firstDaily)
          'Today counts toward your streak.',
        if (widget.dailyDate != null && !firstDaily) 'This date was already completed, so the streak was not increased again.',
      ].join(' '),
      choices: [
        if (next != null)
          const DialogChoice(label: 'Next level', value: 'next', primary: true),
        const DialogChoice(label: 'Replay', value: 'replay', primary: false),
        DialogChoice(
          label: widget.dailyDate == null
              ? 'Back to campaign'
              : 'Back to calendar',
          value: 'back',
          primary: next == null,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice != 'replay') {
      await Ads.afterLevel(levelId: storageId, tutorial: widget.level.tutorial);
    }
    if (!mounted) return;
    if (choice == 'back') {
      Navigator.pop(context);
      return;
    }
    if (choice == 'replay') {
      setState(() {
        session = ParcelSession(
          puzzle: widget.level.puzzle,
          strictness: strictnessFor(widget.level.difficulty),
        );
        bankedMs = 0;
        runningSince = DateTime.now();
        finishing = false;
        highlight = null;
      });
      await _persist();
      return;
    }
    if (next != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ParcelPage(level: next)),
      );
    }
  }

  Future<void> _hint() async {
    if (busy) return;
    busy = true;
    final ParcelHint hint;
    try {
      hint = await showWhenSlow(
        future: parcelHintAway(
          puzzle: widget.level.puzzle,
          strictness: session.strictness,
          placed: session.placed,
          hintsUsed: session.hintsUsed,
        ),
        mounted: () => mounted,
        onSlow: () =>
            setState(() => checkingLabel = 'Looking for a forced step.'),
        onDone: () => setState(() => checkingLabel = null),
      );
    } finally {
      busy = false;
    }
    if (!mounted) return;
    final clue = hint.clueIndex == null
        ? null
        : widget.level.puzzle.clues[hint.clueIndex!];
    final where = clue == null
        ? ''
        : ' The number ${clue.value} is in row ${clue.row + 1}, column ${clue.col + 1}.';
    final String title;
    final String body;
    final List<DialogChoice> choices;
    switch (hint.kind) {
      case ParcelHintKind.forced:
        title = 'Only one shape';
        body =
            'Only one rectangle can hold this number from the current board.$where Placing it uses a hint, and this solve will not be perfect even if you undo.';
        choices = const [
          DialogChoice(label: 'Place this step', value: true, primary: true),
          DialogChoice(label: 'Not now', value: false),
        ];
      case ParcelHintKind.required:
        title = 'Needed to finish';
        body =
            'This rectangle is part of the only way to finish from here.$where Placing it uses a hint.';
        choices = const [
          DialogChoice(label: 'Place this step', value: true, primary: true),
          DialogChoice(label: 'Not now', value: false),
        ];
      case ParcelHintKind.deadEnd:
        title = 'No way forward';
        body = 'These rectangles cannot cover the board. Undo a placement. No hint was used.';
        choices = [
          if (session.canUndo)
            const DialogChoice(
              label: 'Undo last',
              value: 'undo',
              primary: true,
            ),
          const DialogChoice(label: 'Close', value: false),
        ];
      case ParcelHintKind.ambiguous:
        title = 'Nothing is forced';
        body = 'More than one finish still fits, so a hint will not guess. No hint was used.';
        choices = const [
          DialogChoice(label: 'Close', value: false, primary: true),
        ];
    }
    setState(() => highlight = hint.rect);
    final choice = await showRectoraDialog<Object>(
      context: context,
      title: title,
      body: body,
      choices: choices,
    );
    if (!mounted) return;
    if (choice == 'undo') {
      setState(() {
        session.undo();
        highlight = null;
      });
      await _persist();
      return;
    }
    if (choice == true) {
      final hintsBefore = session.hintsUsed;
      final placed = session.applyHint(hint);
      if (!placed) {
        setState(() => highlight = null);
        return;
      }
      await RectoraScope.read(context)
          .noteHints(session.hintsUsed - hintsBefore);
      if (!mounted) return;
      setState(() => highlight = null);
      await _persist();
      await _checkComplete();
      return;
    }
    setState(() => highlight = null);
  }

  Future<void> _skip() async {
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Skip this parcel?',
      body: 'Skipping marks the level finished and unlocks the next one. It does not count as a solved puzzle or a perfect clear. Nothing is charged, and no advertisement is shown.',
      choices: const [
        DialogChoice(label: 'Skip level', value: true, primary: true),
        DialogChoice(label: 'Keep playing', value: false),
      ],
    );
    if (choice != true || !mounted || finishing) return;
    finishing = true;
    _bank();
    final controller = RectoraScope.read(context);
    await controller.finishLevel(
      id: storageId,
      thread: false,
      skipped: true,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (!mounted) return;
    final next = controller.nextParcel(widget.level.id);
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ParcelPage(level: next)),
    );
  }

  void _guideContinue() {
    final lesson = coach;
    if (lesson == null) return;
    setState(() => lesson.continuePressed());
    _maybeDemo();
  }

  Future<void> _guideSkip() async {
    final lesson = coach;
    if (lesson == null) return;
    setState(() => lesson.skip());
    await RectoraScope.read(context).skipTutorial('parcels');
  }

  Future<void> _guideReplay() async {
    final lesson = coach;
    if (lesson == null) return;
    setState(() {
      session.restart();
      highlight = null;
      preview = null;
      anchor = null;
      notice = null;
      _shownDemo = -1;
      lesson.replay();
    });
    await _persist();
  }

  void _guideHint() {
    final lesson = coach;
    if (lesson == null) return;
    lesson.bumpHint();
    GridRect? ghost;
    if (lesson.hintTier >= 2) {
      final hint = session.proposeHint();
      ghost = hint.rect;
    }
    setState(() {
      highlight = ghost;
      if (lesson.hintTier >= 3) preview = ghost;
    });
  }

  void _maybeDemo() {
    final lesson = coach;
    if (lesson == null || lesson.phase != CoachPhase.demonstrating) return;
    if (_shownDemo == lesson.index) return;
    _shownDemo = lesson.index;
    if (!homeMotionEnabled(context)) _demoFinished();
  }

  void _demoFinished() {
    final lesson = coach;
    if (!mounted ||
        lesson == null ||
        lesson.phase != CoachPhase.demonstrating) {
      return;
    }
    setState(() {
      preview = null;
      lesson.demonstrationFinished();
    });
  }

  Future<void> _restart() async {
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Restart this parcel?',
      body: 'Every rectangle on this attempt will be cleared. Your best time stays.',
      choices: const [
        DialogChoice(label: 'Restart', value: true, primary: true),
        DialogChoice(label: 'Cancel', value: false),
      ],
    );
    if (choice != true || !mounted) return;
    setState(() {
      session.restart();
      highlight = null;
      preview = null;
      anchor = null;
    });
    await _persist();
  }

  Future<void> _leave() async {
    if (session.isComplete) {
      Navigator.pop(context);
      return;
    }
    final choice = await showRectoraDialog<String>(
      context: context,
      title: 'Pause',
      body: 'Your rectangles stay saved on this device.',
      choices: const [
        DialogChoice(label: 'Resume', value: 'resume', primary: true),
        DialogChoice(label: 'Restart', value: 'restart'),
        DialogChoice(label: 'Leave', value: 'leave'),
      ],
    );
    if (!mounted || choice == null || choice == 'resume') return;
    if (choice == 'restart') {
      await _restart();
      return;
    }
    await _persist();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final settings = controller.save.settings;
    final solved = controller.save.parcelRecords[storageId]?.solved == true;
    final lesson = coach;
    final glow =
        lesson != null &&
            (lesson.expectsMove || lesson.phase == CoachPhase.demonstrating)
        ? lesson.step.cells
        : const <int>[];
    return TutorialGate(
      active:
          widget.level.tutorial &&
          lesson == null &&
          widget.dailyDate == null &&
          !widget.weekly,
      mode: 'parcels',
      steps: parcelTutorial,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: _leave,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.dailyDate == null
                                  ? widget.level.title
                                  : 'Daily ${dateKey(widget.dailyDate!)}',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (settings.showSize)
                              Text(
                                '${widget.level.puzzle.rows}×${widget.level.puzzle.cols}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Help',
                        onPressed: () => showModeHelp(
                          context: context,
                          objective: 'Cover every square with rectangles.',
                          gestures: 'Drag from one corner of a rectangle to the other. Tap a finished rectangle to remove it.',
                          mistakes: 'A rectangle needs one number, and the number must match its size. Rectangles cannot overlap.',
                          lesson: parcelTutorial,
                          onBonusHint: _hint,
                        ),
                        icon: const Icon(Icons.help_outline),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => pushSoft(
                          context,
                          SettingsPage(
                            activeLevelId: storageId,
                            onResetLevel: _restart,
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
                if (settings.showTimer)
                  PlayClock(bankedMs: bankedMs, runningSince: runningSince),
                if (checkingLabel != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      checkingLabel!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (settings.cornerPlacement)
                  Text(
                    anchor == null
                        ? 'Tap the first corner'
                        : 'Tap the opposite corner',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      notice!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: palette.rose),
                    ),
                  ),
                if (settings.showSize && preview != null)
                  Text(
                    '${preview!.width}×${preview!.height} = ${preview!.area}',
                  ),
                if (lesson != null &&
                    lesson.phase != CoachPhase.completed &&
                    lesson.phase != CoachPhase.skipped)
                  GuideCard(
                    coach: lesson,
                    onContinue: _guideContinue,
                    onSkip: _guideSkip,
                    onReplay: _guideReplay,
                    onHint: _guideHint,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GuidePulse(
                      rows: widget.level.puzzle.rows,
                      cols: widget.level.puzzle.cols,
                      cells: glow,
                      travel: lesson?.phase == CoachPhase.demonstrating,
                      onTravelEnd: _demoFinished,
                      showPointer:
                          lesson?.pointerVisible == true &&
                          lesson?.expectsMove == true,
                      child: ParcelBoard(
                        puzzle: widget.level.puzzle,
                        placed: session.placed,
                        preview: preview,
                        highlight: highlight,
                        onDown: _down,
                        onMove: _move,
                        onUp: _up,
                        onCancel: () => setState(() {
                          anchor = null;
                          preview = null;
                        }),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      PlayTool(
                        label: erase ? 'Drawing' : 'Eraser',
                        tooltip: erase
                            ? 'Return to drawing rectangles'
                            : 'Erase one rectangle',
                        icon: erase
                            ? Icons.edit_outlined
                            : Icons.auto_fix_off_outlined,
                        selected: erase,
                        onPressed: () => setState(() => erase = !erase),
                      ),
                      PlayTool(
                        label: 'Undo',
                        tooltip: 'Undo the last change',
                        icon: Icons.undo,
                        onPressed: session.canUndo
                            ? () {
                                setState(() => session.undo());
                                _persist();
                              }
                            : null,
                      ),
                      PlayTool(
                        label: 'Redo',
                        tooltip: 'Restore the undone change',
                        icon: Icons.redo,
                        onPressed: session.canRedo
                            ? () {
                                setState(() => session.redo());
                                _persist();
                              }
                            : null,
                      ),
                      PlayTool(
                        label: 'Corners',
                        tooltip: 'Place a rectangle with two taps',
                        icon: Icons.crop_free,
                        selected: settings.cornerPlacement,
                        onPressed: () {
                          controller.updateSettings(
                            settings.copyWith(
                              cornerPlacement: !settings.cornerPlacement,
                            ),
                          );
                        },
                      ),
                      PlayTool(
                        label: 'Hint',
                        tooltip: 'Show a required next step',
                        icon: Icons.lightbulb_outline,
                        onPressed: busy ? null : _hint,
                      ),
                      if (widget.dailyDate == null && !solved)
                        PlayTool(
                          label: 'Skip',
                          tooltip: 'Skip this level without an ad',
                          icon: Icons.fast_forward,
                          onPressed: _skip,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayTool extends StatelessWidget {
  const PlayTool({
    super.key,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: selected ? palette.copper : palette.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Semantics(
              button: true,
              label: tooltip,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: selected ? palette.copperInk : palette.ink,
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? palette.copperInk : palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
