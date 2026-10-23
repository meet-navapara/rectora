import 'package:flutter/material.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/threads/engine.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/tutorial/coach.dart';
import 'package:rectora/domain/work/background.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/coach/guide_view.dart';
import 'package:rectora/ui/feedback_player.dart';
import 'package:rectora/ui/home/home_motion.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/screens/settings_page.dart';
import 'package:rectora/ui/tutorial.dart';
import 'package:rectora/ui/widgets/dialogs.dart';
import 'package:rectora/ui/widgets/play_clock.dart';
import 'package:rectora/ui/widgets/thread_board.dart';

class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.level});

  final ThreadLevel level;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> with WidgetsBindingObserver {
  final feedback = FeedbackPlayer();
  late ThreadSession session;
  List<int> draft = const [];
  DateTime? runningSince;
  int bankedMs = 0;
  var finishing = false;
  var busy = false;
  String? notice;
  String? checkingLabel;
  PlayCoach? coach;
  var _shownDemo = -1;
  List<int> _hintCells = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final save = RectoraScope.read(context).save;
    final stored = save.drafts[widget.level.id];
    final guide = shouldGuideLevel(
      number: widget.level.number,
      campaignLevel: true,
      seen: save.tutorialsSeen,
      modeId: 'threads',
    );
    if (guide) {
      coach = PlayCoach(
        threadGuide(
          number: widget.level.number,
          solution: widget.level.solution,
        ),
        hintCopy: threadHintCopy,
      );
    }
    session = ThreadSession(
      puzzle: widget.level.puzzle,
      draft: guide
          ? null
          : [
              for (final move in stored?.moves ?? const <List<int>>[])
                ThreadPath(pairIndex: 0, cells: move),
            ],
      hintsUsed: guide ? 0 : stored?.hintsUsed ?? 0,
    );
    bankedMs = stored?.elapsedMs ?? 0;
    runningSince = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = RectoraScope.read(context);
      controller.markStarted(id: widget.level.id, thread: true);
      if (session.discardedDraft && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved paths for this puzzle were damaged and cleared.',
            ),
          ),
        );
      }
      if (session.isComplete) _checkComplete();
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
    } else if (runningSince != null) {
      bankedMs += DateTime.now().difference(runningSince!).inMilliseconds;
      runningSince = null;
    }
    if (mounted) setState(() {});
  }

  int get elapsedMs =>
      bankedMs +
      (runningSince == null
          ? 0
          : DateTime.now().difference(runningSince!).inMilliseconds);

  String get clockLabel {
    final total = elapsedMs ~/ 1000;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _persist() async {
    await RectoraScope.read(context).saveDraft(
      id: widget.level.id,
      draft: session.paths.isEmpty
          ? null
          : PuzzleDraft(
              elapsedMs: elapsedMs,
              hintsUsed: session.hintsUsed,
              moves: [for (final path in session.paths) path.cells],
            ),
    );
  }

  void _down(int index) {
    if (busy || coach?.locksInput == true) return;
    coach?.hidePointer();
    for (final path in session.paths) {
      if (!path.cells.contains(index)) continue;
      if (coach != null && coach!.phase != CoachPhase.practice) return;
      if (session.erasePair(path.pairIndex)) {
        feedback.tap(RectoraScope.read(context).save.settings);
        setState(() {
          draft = const [];
          notice = null;
        });
        _persist();
      }
      return;
    }
    final owner = session.geometry.terminalOwner[index];
    if (owner < 0 || session.paths.any((path) => path.pairIndex == owner)) {
      return;
    }
    setState(() => draft = [index]);
  }

  void _move(int index) {
    if (busy || draft.isEmpty || draft.last == index) return;
    final next = session.geometry.extend(
      path: draft,
      target: index,
      occupied: session.occupied,
    );
    if (_sameCells(draft, next)) return;
    setState(() => draft = next);
  }

  Future<void> _up(int index) async {
    if (busy || draft.isEmpty) return;
    final cells = session.geometry.extend(
      path: draft,
      target: index,
      occupied: session.occupied,
    );
    setState(() => draft = const []);
    final issue = session.commit(cells);
    final settings = RectoraScope.read(context).save.settings;
    if (issue == ThreadIssue.ok) {
      final lesson = coach;
      if (lesson != null && lesson.expectsMove) {
        final placed = session.paths.last.cells;
        if (!lesson.judge(placed)) {
          session.undo();
          if (!mounted) return;
          setState(() => notice = lesson.correction);
          return;
        }
      }
      await feedback.place(settings);
      if (!mounted) return;
      setState(() => notice = null);
      await _persist();
      if (session.isComplete) coach?.markSolved();
      await _checkComplete();
      return;
    }
    await feedback.error(settings);
    if (!mounted) return;
    setState(() => notice = _threadIssue(issue));
  }

  String _threadIssue(ThreadIssue issue) {
    switch (issue) {
      case ThreadIssue.notOrthogonal:
        return 'Paths only step up, down, left, or right. Diagonal moves are not allowed.';
      case ThreadIssue.blocked:
        return 'That cell is closed.';
      case ThreadIssue.overlap:
      case ThreadIssue.revisit:
        return 'A path cannot cross itself or another path.';
      case ThreadIssue.foreignTerminal:
        return 'This path ran into a different letter.';
      case ThreadIssue.endsMismatch:
      case ThreadIssue.tooShort:
        return 'Release on the matching letter. The path has to join that pair.';
      case ThreadIssue.malformed:
        return 'This puzzle data cannot be played.';
      case ThreadIssue.ok:
        return 'Connected.';
    }
  }

  Future<void> _checkComplete() async {
    if (finishing || !session.claimCompletion()) return;
    finishing = true;
    if (runningSince != null) {
      bankedMs += DateTime.now().difference(runningSince!).inMilliseconds;
      runningSince = null;
    }
    final controller = RectoraScope.read(context);
    final record = await controller.finishLevel(
      id: widget.level.id,
      thread: true,
      skipped: false,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (widget.level.tutorial && widget.level.number >= 2) {
      await controller.seeTutorial('threads');
    }
    if (!mounted) return;
    await feedback.complete(controller.save.settings);
    if (!mounted) return;
    final next = controller.nextThread(widget.level.id);
    final choice = await showRectoraDialog<String>(
      context: context,
      barrierDismissible: false,
      title: 'Threads complete',
      body:
          'Time $clockLabel. ${session.hintsUsed == 0 ? 'Perfect clear.' : 'Hints used: ${session.hintsUsed}.'} Best ${_clock(record.bestMs)}.',
      choices: [
        if (next != null)
          const DialogChoice(
            label: 'Next thread',
            value: 'next',
            primary: true,
          ),
        const DialogChoice(label: 'Replay', value: 'replay'),
        DialogChoice(
          label: 'Back to campaign',
          value: 'back',
          primary: next == null,
        ),
      ],
    );
    if (!mounted) return;
    if (choice != null && choice != 'replay') {
      await Ads.afterLevel(
        levelId: widget.level.id,
        tutorial: widget.level.tutorial,
      );
    }
    if (!mounted) return;
    if (choice == 'replay') {
      setState(() {
        session = ThreadSession(puzzle: widget.level.puzzle);
        bankedMs = 0;
        runningSince = DateTime.now();
        finishing = false;
      });
      await _persist();
      return;
    }
    if (choice == 'next' && next != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ThreadPage(level: next)),
      );
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _hint() async {
    if (busy) return;
    busy = true;
    final ThreadHint hint;
    try {
      hint = await showWhenSlow(
        future: threadHintAway(
          puzzle: widget.level.puzzle,
          placed: session.paths,
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
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: switch (hint.kind) {
        ThreadHintKind.required => 'One valid continuation',
        ThreadHintKind.deadEnd => 'No way forward',
        ThreadHintKind.ambiguous => 'No proved step',
        ThreadHintKind.alreadyDone => 'Already joined',
      },
      body: switch (hint.kind) {
        ThreadHintKind.required => 'This path is a real way to join the next open pair. Placing it uses a hint.',
        ThreadHintKind.deadEnd => 'The paths on the board cannot be finished. Undo one. No hint was used.',
        ThreadHintKind.ambiguous =>
          'The search did not prove a single next path, so nothing was placed.',
        ThreadHintKind.alreadyDone => 'Every pair is already joined.',
      },
      choices: [
        if (hint.placesAPath)
          const DialogChoice(
            label: 'Place this path',
            value: true,
            primary: true,
          ),
        const DialogChoice(label: 'Close', value: false),
      ],
    );
    if (choice != true || !mounted) return;
    final before = session.hintsUsed;
    if (!session.applyHint(hint)) return;
    await RectoraScope.read(context).noteHints(session.hintsUsed - before);
    if (!mounted) return;
    setState(() {});
    await _persist();
    await _checkComplete();
  }

  Future<void> _skip() async {
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Skip this thread?',
      body: 'Skipping marks the puzzle finished and unlocks the next one. It does not count as a solve. No advertisement is shown.',
      choices: const [
        DialogChoice(label: 'Skip puzzle', value: true, primary: true),
        DialogChoice(label: 'Keep playing', value: false),
      ],
    );
    if (choice != true || !mounted || finishing) return;
    finishing = true;
    final controller = RectoraScope.read(context);
    await controller.finishLevel(
      id: widget.level.id,
      thread: true,
      skipped: true,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (!mounted) return;
    final next = controller.nextThread(widget.level.id);
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ThreadPage(level: next)),
    );
  }

  Future<void> _restart() async {
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Restart this thread?',
      body: 'Every path on this attempt will be cleared.',
      choices: const [
        DialogChoice(label: 'Restart', value: true, primary: true),
        DialogChoice(label: 'Cancel', value: false),
      ],
    );
    if (choice != true || !mounted) return;
    setState(() {
      session.restart();
      draft = const [];
    });
    await _persist();
  }

  void _guideContinue() {
    final lesson = coach;
    if (lesson == null) return;
    setState(() => lesson.continuePressed());
    _maybeDemo();
  }

  Future<void> _guideSkip() async {
    coach?.skip();
    setState(() {});
    await RectoraScope.read(context).skipTutorial('threads');
  }

  Future<void> _guideReplay() async {
    final lesson = coach;
    if (lesson == null) return;
    setState(() {
      session.restart();
      draft = const [];
      notice = null;
      _hintCells = const [];
      _shownDemo = -1;
      lesson.replay();
    });
    await _persist();
  }

  void _guideHint() {
    final lesson = coach;
    if (lesson == null) return;
    lesson.bumpHint();
    final hint = lesson.hintTier >= 2 ? session.proposeHint() : null;
    setState(() {
      _hintCells = hint?.cells ?? const [];
      if (lesson.hintText.isNotEmpty) notice = lesson.hintText;
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
      draft = const [];
      lesson.demonstrationFinished();
    });
  }

  Future<void> _leave() async {
    if (session.isComplete) {
      Navigator.pop(context);
      return;
    }
    final choice = await showRectoraDialog<String>(
      context: context,
      title: 'Pause',
      body: 'Your paths stay saved on this device.',
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
    final palette = RectoraTheme.of(context);
    final settings = RectoraScope.of(context).save.settings;
    final solved =
        RectoraScope.of(context).save.threadRecords[widget.level.id]?.solved ==
        true;
    final lesson = coach;
    final glow = lesson == null
        ? const <int>[]
        : lesson.expectsMove || lesson.phase == CoachPhase.demonstrating
        ? lesson.step.cells
        : lesson.hintTier >= 2
        ? _hintCells
        : const <int>[];
    return TutorialGate(
      active: widget.level.tutorial && lesson == null,
      mode: 'threads',
      steps: threadTutorial,
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
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _leave,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        widget.level.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Help',
                      onPressed: () => showModeHelp(
                        context: context,
                        objective: 'Join each letter to its matching letter.',
                        gestures: 'Press one letter and drag to the other copy. Tap a finished path to remove it.',
                        mistakes: 'Stay on squares that share a side. Paths cannot cross or reuse a square.',
                        lesson: threadTutorial,
                        onBonusHint: _hint,
                      ),
                      icon: const Icon(Icons.help_outline),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => pushSoft(
                        context,
                        SettingsPage(
                          activeLevelId: widget.level.id,
                          onResetLevel: _restart,
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                if (settings.showTimer)
                  PlayClock(bankedMs: bankedMs, runningSince: runningSince),
                if (checkingLabel != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(checkingLabel!, textAlign: TextAlign.center),
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
                      child: ThreadBoard(
                        puzzle: widget.level.puzzle,
                        paths: session.paths,
                        draft: draft,
                        onDown: _down,
                        onMove: _move,
                        onUp: _up,
                        onCancel: () => setState(() => draft = const []),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      PlayTool(
                        label: 'Redo',
                        tooltip: 'Restore the undone path',
                        icon: Icons.redo,
                        onPressed: session.canRedo
                            ? () {
                                setState(() {
                                  session.redo();
                                });
                                _persist();
                              }
                            : null,
                      ),
                      PlayTool(
                        label: 'Undo',
                        tooltip: 'Undo the last path',
                        icon: Icons.undo,
                        onPressed: session.canUndo
                            ? () {
                                setState(() => session.undo());
                                _persist();
                              }
                            : null,
                      ),
                      PlayTool(
                        label: 'Hint',
                        tooltip: 'Show a valid next path',
                        icon: Icons.lightbulb_outline,
                        onPressed: busy ? null : _hint,
                      ),
                      if (!solved)
                        PlayTool(
                          label: 'Skip',
                          tooltip: 'Skip this puzzle without an ad',
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

String _clock(int? ms) {
  if (ms == null) return 'not set';
  final total = ms ~/ 1000;
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

bool _sameCells(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
