import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/domain/trace/engine.dart';
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
import 'package:rectora/ui/widgets/trace_board.dart';

class TracePage extends StatefulWidget {
  const TracePage({super.key, required this.level});

  final TraceLevel level;

  @override
  State<TracePage> createState() => _TracePageState();
}

class _TracePageState extends State<TracePage> with WidgetsBindingObserver {
  late TraceSession session;
  final feedback = FeedbackPlayer();
  var bankedMs = 0;
  DateTime? runningSince;
  var finishing = false;
  var busy = false;
  var clockLive = false;
  String? notice;
  String? checkingLabel;
  var _tapErase = false;
  int? _pressCell;
  int? _strokeCell;
  int? _soundedCell;
  Timer? _draftTimer;
  PlayCoach? coach;
  var _shownDemo = -1;
  int? _hintCell;

  @override
  void initState() {
    super.initState();
    final save = RectoraScope.read(context).save;
    final draft = save.drafts[widget.level.id];
    final guide = shouldGuideLevel(
      number: widget.level.number,
      campaignLevel: true,
      seen: save.tutorialsSeen,
      modeId: 'trace',
    );
    if (guide) {
      coach = PlayCoach(
        traceGuide(
          number: widget.level.number,
          solution: widget.level.solution,
        ),
        hintCopy: traceHintCopy,
      );
    }
    session = TraceSession(
      puzzle: widget.level.puzzle,
      draft: guide
          ? null
          : draft == null || draft.moves.isEmpty
          ? null
          : draft.moves.first,
      hintsUsed: guide ? 0 : draft?.hintsUsed ?? 0,
    );
    bankedMs = draft?.elapsedMs ?? 0;
    WidgetsBinding.instance.addObserver(this);
    if (session.discardedDraft && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A damaged saved path was cleared.')),
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = RectoraScope.read(context);
      controller.markStarted(id: widget.level.id, mode: PlayMode.trace);
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    feedback.dispose();
    super.dispose();
  }

  void _rememberStroke() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      _draftTimer = null;
      if (!mounted) return;
      _persist();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (clockLive && !finishing && !session.isComplete) {
        runningSince ??= DateTime.now();
      }
    } else {
      _bank();
      _persist();
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

  Future<void> _persist() async {
    final controller = RectoraScope.read(context);
    await controller.saveDraft(
      id: widget.level.id,
      draft: session.path.isEmpty
          ? null
          : PuzzleDraft(
              elapsedMs: elapsedMs,
              hintsUsed: session.hintsUsed,
              moves: [session.path],
            ),
    );
  }

  void _press(int cell) {
    if (coach?.locksInput == true) return;
    coach?.hidePointer();
    _pressCell = cell;
    _tapErase = session.path.contains(cell);
    if (_tapErase && coach?.restrictsEditing == true) {
      _tapErase = false;
      return;
    }
    if (_tapErase) return;
    _touch(cell);
  }

  void _slide(int cell) {
    if (_tapErase && cell == _pressCell) return;
    _tapErase = false;
    _touch(cell);
  }

  void _touch(int cell) {
    if (busy || coach?.locksInput == true || _strokeCell == cell) return;
    _strokeCell = cell;
    final starting = !clockLive;
    runningSince ??= DateTime.now();
    clockLive = true;
    final before = session.path.length;
    final issue = session.dragTo(cell);
    if (issue == TraceIssue.ok &&
        session.path.length == before &&
        notice == null) {
      if (starting) setState(() {});
      return;
    }
    setState(() {
      notice = issue == TraceIssue.ok ? null : _traceNotice(issue);
    });
    if (issue == TraceIssue.ok) {
      final lesson = coach;
      if (lesson != null &&
          lesson.expectsMove &&
          session.path.length != before) {
        if (!lesson.judge(List<int>.from(session.path))) {
          session.undo();
          setState(() => notice = lesson.correction);
          return;
        }
      }
      _soundedCell = null;
      if (session.path.length != before) {
        _rememberStroke();
        if (session.isComplete) coach?.markSolved();
        _checkComplete();
      }
      return;
    }
    if (_soundedCell == cell) return;
    _soundedCell = cell;
    feedback.error(RectoraScope.read(context).save.settings);
  }

  void _release() {
    if (_tapErase && session.path.isNotEmpty) {
      session.restart();
      feedback.tap(RectoraScope.read(context).save.settings);
      setState(() => notice = null);
      _persist();
    }
    _tapErase = false;
    _pressCell = null;
    _strokeCell = null;
    _soundedCell = null;
    _draftTimer?.cancel();
    _draftTimer = null;
    _persist();
  }

  String _traceNotice(TraceIssue issue) {
    return switch (issue) {
      TraceIssue.broken => 'Move to a cell that shares an edge.',
      TraceIssue.revisit => 'The path cannot visit a cell twice.',
      TraceIssue.blocked => 'That cell is closed.',
      TraceIssue.order => 'Visit the numbers in order, starting at 1.',
      TraceIssue.incomplete => 'The path still has open cells to cover.',
      TraceIssue.malformed => 'This puzzle data cannot be played.',
      TraceIssue.ok => '',
    };
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
    await RectoraScope.read(context).skipTutorial('trace');
  }

  Future<void> _guideReplay() async {
    final lesson = coach;
    if (lesson == null) return;
    setState(() {
      session.restart();
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
    final hint = lesson.hintTier >= 2 ? session.proposeHint() : null;
    setState(() {
      _hintCell = hint?.cell;
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
    setState(() => lesson.demonstrationFinished());
  }

  Future<void> _checkComplete() async {
    if (finishing || !session.claimCompletion()) return;
    finishing = true;
    clockLive = false;
    _bank();
    final controller = RectoraScope.read(context);
    final xpBefore = controller.save.xp;
    final replay =
        controller.save.traceRecords[widget.level.id]?.solved == true;
    final record = await controller.finishLevel(
      id: widget.level.id,
      mode: PlayMode.trace,
      skipped: false,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (widget.level.tutorial && widget.level.number >= 2) {
      await controller.seeTutorial('trace');
    }
    if (!mounted) return;
    await feedback.complete(controller.save.settings);
    if (!mounted) return;
    await _done(record, controller.save.xp - xpBefore, replay);
  }

  Future<void> _done(LevelRecord record, int xpGained, bool replay) async {
    final choice = await showRectoraDialog<String>(
      context: context,
      title: 'Path complete',
      body: completionBody(
        time: clockText(elapsedMs),
        hints: session.hintsUsed,
        difficulty: widget.level.difficulty,
        xpGained: xpGained,
        bestMs: record.bestMs,
        replay: replay,
      ),
      choices: const [
        DialogChoice(label: 'Next', value: 'next', primary: true),
        DialogChoice(label: 'Replay', value: 'replay'),
        DialogChoice(label: 'Back', value: 'back'),
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
    if (choice == 'next') {
      final next = RectoraScope.read(context).nextTrace(widget.level.id);
      if (next == null) {
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => TracePage(level: next)),
      );
      return;
    }
    if (choice == 'replay') {
      setState(() {
        session = TraceSession(puzzle: widget.level.puzzle);
        bankedMs = 0;
        runningSince = null;
        clockLive = false;
        finishing = false;
      });
      await _persist();
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _hint() async {
    if (busy) return;
    if (!await claimHint(context, session.hintsUsed) || !mounted) return;
    busy = true;
    final TraceHint hint;
    try {
      hint = await showWhenSlow(
        future: traceHintAway(
          puzzle: widget.level.puzzle,
          path: session.path,
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
    final body = switch (hint.kind) {
      TraceHintKind.forced =>
        'Only one next cell keeps a path that can still cover the board.',
      TraceHintKind.ambiguous =>
        'More than one continuation still works, so a hint will not guess.',
      TraceHintKind.deadEnd =>
        'This path cannot cover the board. Undo. No hint was used.',
    };
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: hint.kind == TraceHintKind.forced ? 'Next cell' : 'No hint',
      body: body,
      choices: [
        if (hint.kind == TraceHintKind.forced)
          const DialogChoice(label: 'Place it', value: true, primary: true),
        const DialogChoice(label: 'Close', value: false),
      ],
    );
    if (!mounted || choice != true || !session.applyHint(hint)) return;
    setState(() {});
    await RectoraScope.read(context).noteHints(1);
    await _persist();
    await _checkComplete();
  }

  Future<void> _restartFromSettings() async {
    setState(() {
      session.restart();
      notice = null;
    });
    await _persist();
  }

  Future<void> _skip() async {
    if (!await allowSkip(context, PlayMode.trace) || !mounted) return;
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Skip this path?',
      body: 'Skipping unlocks the next level but does not count as a solve. Each mode can have three skipped levels at a time.',
      choices: const [
        DialogChoice(label: 'Skip', value: true, primary: true),
        DialogChoice(label: 'Cancel', value: false),
      ],
    );
    if (choice != true || !mounted) return;
    await RectoraScope.read(context).finishLevel(
      id: widget.level.id,
      mode: PlayMode.trace,
      skipped: true,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (!mounted) return;
    final next = RectoraScope.read(context).nextTrace(widget.level.id);
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => TracePage(level: next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final settings = RectoraScope.of(context).save.settings;
    final solved =
        RectoraScope.of(context).save.traceRecords[widget.level.id]?.solved ==
        true;
    final lesson = coach;
    final glow = lesson == null
        ? const <int>[]
        : lesson.expectsMove || lesson.phase == CoachPhase.demonstrating
        ? lesson.step.cells
        : lesson.hintTier >= 2 && _hintCell != null
        ? <int>[_hintCell!]
        : const <int>[];
    return TutorialGate(
      active: widget.level.tutorial && lesson == null,
      mode: 'trace',
      steps: traceTutorial,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () async {
                      await _persist();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.level.title} · ${widget.level.difficulty.label}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'How Trace works',
                    onPressed: () => showModeHelp(
                      context: context,
                      objective: 'Draw one path through every open square.',
                      gestures: 'Start on 1 and drag through squares that share a side. Tap the path to remove it.',
                      mistakes: 'Visit the numbers in order. Do not visit a square twice or move diagonally.',
                      lesson: traceTutorial,
                    ),
                    icon: const Icon(Icons.help_outline),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => pushSoft(
                      context,
                      SettingsPage(
                        activeLevelId: widget.level.id,
                        onResetLevel: _restartFromSettings,
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
                  padding: const EdgeInsets.all(16),
                  child: GuidePulse(
                    rows: widget.level.puzzle.rows,
                    cols: widget.level.puzzle.cols,
                    cells: glow,
                    travel: lesson?.phase == CoachPhase.demonstrating,
                    onTravelEnd: _demoFinished,
                    showPointer:
                        lesson?.pointerVisible == true &&
                        lesson?.expectsMove == true,
                    child: TraceBoard(
                      puzzle: widget.level.puzzle,
                      path: session.path,
                      onPress: _press,
                      onCell: _slide,
                      onRelease: _release,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    PlayTool(
                      label: 'Undo',
                      tooltip: 'Undo the last path change',
                      icon: Icons.undo,
                      onPressed: session.canUndo
                          ? () {
                              setState(() {
                                session.undo();
                              });
                              _persist();
                            }
                          : null,
                    ),
                    PlayTool(
                      label: 'Redo',
                      tooltip: 'Restore the undone path change',
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
                      label: 'Restart',
                      tooltip: 'Clear this path',
                      icon: Icons.refresh,
                      onPressed: () {
                        setState(session.restart);
                        _persist();
                      },
                    ),
                    PlayTool(
                      label: 'Hint',
                      tooltip: 'Show the only legal next cell',
                      icon: Icons.lightbulb_outline,
                      onPressed: busy ? null : _hint,
                    ),
                    if (!solved && !widget.level.tutorial)
                      PlayTool(
                        label: 'Skip',
                        tooltip: 'Skip this Trace level',
                        icon: Icons.skip_next,
                        onPressed: _skip,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
