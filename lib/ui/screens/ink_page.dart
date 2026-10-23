import 'package:flutter/material.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/tutorial/coach.dart';
import 'package:rectora/domain/parcels/models.dart';
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
import 'package:rectora/ui/widgets/ink_board.dart';
import 'package:rectora/ui/widgets/play_clock.dart';

class InkPage extends StatefulWidget {
  const InkPage({super.key, required this.level});

  final InkLevel level;

  @override
  State<InkPage> createState() => _InkPageState();
}

class _InkPageState extends State<InkPage> with WidgetsBindingObserver {
  late InkSession session;
  final feedback = FeedbackPlayer();
  final draft = <int>[];
  var bankedMs = 0;
  DateTime? runningSince;
  var finishing = false;
  var erase = false;
  var busy = false;
  var clockLive = false;
  bool? draftValid;
  String? notice;
  var _holdErase = false;
  String? checkingLabel;
  PlayCoach? coach;
  var _shownDemo = -1;
  List<int> _hintCells = const [];

  @override
  void initState() {
    super.initState();
    final save = RectoraScope.read(context).save;
    final stored = save.drafts[widget.level.id];
    final guide = shouldGuideLevel(
      number: widget.level.number,
      campaignLevel: true,
      seen: save.tutorialsSeen,
      modeId: 'inks',
    );
    if (guide) {
      coach = PlayCoach(
        inkGuide(number: widget.level.number, solution: widget.level.solution),
        hintCopy: inkHintCopy,
      );
    }
    session = InkSession(
      puzzle: widget.level.puzzle,
      draft: guide ? null : stored?.moves,
      hintsUsed: guide ? 0 : stored?.hintsUsed ?? 0,
    );
    bankedMs = stored?.elapsedMs ?? 0;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = RectoraScope.read(context);
      controller.markStarted(id: widget.level.id, mode: PlayMode.ink);
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
    await RectoraScope.read(context).saveDraft(
      id: widget.level.id,
      draft: session.regions.isEmpty
          ? null
          : PuzzleDraft(
              elapsedMs: elapsedMs,
              hintsUsed: session.hintsUsed,
              moves: [for (final region in session.regions) region.cells],
            ),
    );
  }

  void _touch(int cell, {required bool moving}) {
    if (busy || coach?.locksInput == true) return;
    if (!moving) coach?.hidePointer();
    if (!moving) {
      _holdErase = false;
      if (session.regions.any((region) => region.cells.contains(cell))) {
        if (coach != null && coach!.phase != CoachPhase.practice) return;
        _holdErase = true;
        if (session.eraseAt(cell)) {
          feedback.tap(RectoraScope.read(context).save.settings);
          setState(() {
            draft.clear();
            draftValid = null;
            notice = null;
          });
          _persist();
        }
        return;
      }
    } else if (_holdErase) {
      return;
    }
    final starting = !clockLive;
    runningSince ??= DateTime.now();
    clockLive = true;
    if (erase) {
      if (session.eraseAt(cell)) {
        setState(() {});
        _persist();
      } else if (starting) {
        setState(() {});
      }
      return;
    }
    if (draft.isNotEmpty && draft.last == cell) {
      if (starting) setState(() {});
      return;
    }
    final next = List<int>.from(draft);
    if (next.isEmpty) {
      next.add(cell);
    } else if (next.length >= 2 && next[next.length - 2] == cell) {
      next.removeLast();
    } else if (session.geometry.neighbors(next.last).contains(cell) &&
        !next.contains(cell)) {
      next.add(cell);
    } else {
      if (starting) setState(() {});
      return;
    }
    final assessment = session.geometry.assess(next, session.occupied);
    setState(() {
      draft
        ..clear()
        ..addAll(next);
      draftValid = assessment.accepted;
    });
  }

  Future<void> _release() async {
    if (busy || draft.isEmpty || erase) return;
    final issue = session.commit(draft);
    setState(() {
      draft.clear();
      draftValid = null;
    });
    if (issue == InkIssue.ok) {
      final lesson = coach;
      if (lesson != null && lesson.expectsMove) {
        final placed = session.regions.last.cells;
        if (!lesson.judge(placed)) {
          session.undo();
          if (!mounted) return;
          setState(() => notice = lesson.correction);
          return;
        }
      }
      await feedback.place(RectoraScope.read(context).save.settings);
      if (!mounted) return;
      setState(() => notice = null);
      await _persist();
      if (session.isComplete) coach?.markSolved();
      await _checkComplete();
      return;
    }
    await feedback.error(RectoraScope.read(context).save.settings);
    if (!mounted) return;
    setState(() => notice = _reason(issue));
  }

  String _reason(InkIssue issue) {
    return switch (issue) {
      InkIssue.clue => 'A region needs exactly one number, and it must contain that many cells.',
      InkIssue.disconnected => 'Stay on cells that touch by an edge.',
      InkIssue.overlap => 'That overlaps a region already placed.',
      InkIssue.incomplete => 'Keep drawing until the number is satisfied.',
      InkIssue.malformed => 'This puzzle data cannot be played.',
      InkIssue.ok => 'Placed.',
    };
  }

  Future<void> _checkComplete() async {
    if (finishing || !session.claimCompletion()) return;
    finishing = true;
    clockLive = false;
    _bank();
    final controller = RectoraScope.read(context);
    final record = await controller.finishLevel(
      id: widget.level.id,
      mode: PlayMode.ink,
      skipped: false,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (widget.level.tutorial && widget.level.number >= 2) {
      await controller.seeTutorial('inks');
    }
    if (!mounted) return;
    await feedback.complete(controller.save.settings);
    if (!mounted) return;
    final choice = await showRectoraDialog<String>(
      context: context,
      title: 'Board covered',
      body: record.perfect
          ? 'Every region matches its number, and no hint was used.'
          : 'The regions cover every cell without overlap.',
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
      final next = RectoraScope.read(context).nextInk(widget.level.id);
      if (next == null) {
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => InkPage(level: next)),
      );
      return;
    }
    if (choice == 'replay') {
      setState(() {
        session = InkSession(puzzle: widget.level.puzzle);
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
    busy = true;
    final InkHint hint;
    try {
      hint = await showWhenSlow(
        future: inkHintAway(
          puzzle: widget.level.puzzle,
          placed: session.regions,
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
      title: hint.kind == InkHintKind.forced ? 'Forced region' : 'No hint',
      body: switch (hint.kind) {
        InkHintKind.forced =>
          'This is a region the remaining numbers still allow.',
        InkHintKind.ambiguous =>
          'More than one covering still fits, so a hint will not guess.',
        InkHintKind.deadEnd =>
          'These regions cannot cover the board. Undo. No hint was used.',
      },
      choices: [
        if (hint.kind == InkHintKind.forced)
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

  Future<void> _skip() async {
    final choice = await showRectoraDialog<bool>(
      context: context,
      title: 'Skip this board?',
      body: 'Skipping unlocks the next Inks puzzle. It does not count as a solve, and it does not play an ad.',
      choices: const [
        DialogChoice(label: 'Skip', value: true, primary: true),
        DialogChoice(label: 'Cancel', value: false),
      ],
    );
    if (choice != true || !mounted) return;
    await RectoraScope.read(context).finishLevel(
      id: widget.level.id,
      mode: PlayMode.ink,
      skipped: true,
      hintsUsed: session.hintsUsed,
      elapsedMs: elapsedMs,
    );
    if (!mounted) return;
    final next = RectoraScope.read(context).nextInk(widget.level.id);
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => InkPage(level: next)),
    );
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
    await RectoraScope.read(context).skipTutorial('inks');
  }

  Future<void> _guideReplay() async {
    final lesson = coach;
    if (lesson == null) return;
    setState(() {
      session.restart();
      draft.clear();
      draftValid = null;
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

  Future<void> _maybeDemo() async {
    final lesson = coach;
    if (lesson == null || lesson.phase != CoachPhase.demonstrating) return;
    if (_shownDemo == lesson.index) return;
    _shownDemo = lesson.index;
    final cells = lesson.step.cells;
    if (homeMotionEnabled(context)) {
      for (var i = 1; i <= cells.length; i++) {
        setState(() {
          draft
            ..clear()
            ..addAll(cells.sublist(0, i));
          draftValid = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 160));
        if (!mounted || coach?.phase != CoachPhase.demonstrating) return;
      }
    }
    final issue = session.commit(cells);
    if (!mounted || issue != InkIssue.ok) return;
    setState(() {
      draft.clear();
      draftValid = null;
      lesson.demonstrationFinished();
    });
    await _persist();
    if (session.isComplete) {
      coach?.markSolved();
      await _checkComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final settings = RectoraScope.of(context).save.settings;
    final solved =
        RectoraScope.of(context).save.inkRecords[widget.level.id]?.solved ==
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
      mode: 'inks',
      steps: inkTutorial,
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
                    tooltip: 'How Inks works',
                    onPressed: () => showModeHelp(
                      context: context,
                      objective: 'Give every number its own group of squares.',
                      gestures: 'Drag through squares that share a side. The group may bend. Tap a finished group to remove it.',
                      mistakes: 'Match the number, keep one number in each group, and do not overlap.',
                      lesson: inkTutorial,
                      onBonusHint: _hint,
                    ),
                    icon: const Icon(Icons.help_outline),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => pushSoft(
                      context,
                      SettingsPage(activeLevelId: widget.level.id),
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
                child: Listener(
                  onPointerUp: (_) => _release(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GuidePulse(
                      rows: widget.level.puzzle.rows,
                      cols: widget.level.puzzle.cols,
                      cells: glow,
                      showPointer:
                          lesson?.pointerVisible == true &&
                          lesson?.expectsMove == true,
                      child: InkBoard(
                        puzzle: widget.level.puzzle,
                        regions: session.regions,
                        draft: draft,
                        draftValid: draftValid,
                        onCell: _touch,
                      ),
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
                      tooltip: 'Erase one region',
                      icon: Icons.auto_fix_off_outlined,
                      selected: erase,
                      onPressed: () => setState(() => erase = !erase),
                    ),
                    PlayTool(
                      label: 'Undo',
                      tooltip: 'Undo the last region',
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
                      tooltip: 'Restore the undone region',
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
                      label: 'Hint',
                      tooltip: 'Place one forced region',
                      icon: Icons.lightbulb_outline,
                      onPressed: busy ? null : _hint,
                    ),
                    if (!solved)
                      PlayTool(
                        label: 'Skip',
                        tooltip: 'Skip this Inks level',
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
