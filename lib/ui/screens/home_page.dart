import 'package:flutter/material.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/common/date_key.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/domain/tutorial/home_tour.dart';
import 'package:rectora/domain/tutorial/progress.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/controller.dart';
import 'package:rectora/ui/home/home_art.dart';
import 'package:rectora/ui/home/home_cards.dart';
import 'package:rectora/ui/home/home_stage.dart';
import 'package:rectora/ui/home/home_tour_view.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/campaign_page.dart';
import 'package:rectora/ui/screens/daily_page.dart';
import 'package:rectora/ui/screens/help_page.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/screens/profile_page.dart';
import 'package:rectora/ui/screens/settings_page.dart';
import 'package:rectora/ui/screens/stats_page.dart';
import 'package:rectora/ui/screens/weekly_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _continueKey = GlobalKey();
  final _modesKey = GlobalKey();
  final _dailyKey = GlobalKey();
  final _weeklyKey = GlobalKey();
  final _progressKey = GlobalKey();
  final _guideKey = GlobalKey();
  var _step = HomeTourStep.off;
  var _tourToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootTour());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = RectoraScope.of(context).homeTourToken;
    if (token != _tourToken && token > 0) {
      _tourToken = token;
      _step = HomeTourStep.welcome;
    }
  }

  void _bootTour() {
    if (!mounted || _step != HomeTourStep.off) return;
    final save = RectoraScope.read(context).save;
    if (shouldAutoStartHomeTour(save)) {
      setState(() => _step = HomeTourStep.welcome);
    }
  }

  GlobalKey? get _holeKey {
    return switch (_step) {
      HomeTourStep.continueJourney => _continueKey,
      HomeTourStep.modes || HomeTourStep.choose => _modesKey,
      HomeTourStep.daily => _dailyKey,
      HomeTourStep.weekly => _weeklyKey,
      HomeTourStep.progress => _progressKey,
      HomeTourStep.help => _guideKey,
      _ => null,
    };
  }

  Future<void> _reveal() async {
    final key = _holeKey;
    final target = key?.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: _step == HomeTourStep.choose ? 0.05 : 0.2,
      duration: const Duration(milliseconds: 220),
    );
    if (mounted) setState(() {});
  }

  Future<void> _advance() async {
    final index = homeTourSteps.indexOf(_step);
    if (index < 0 || index + 1 >= homeTourSteps.length) return;
    setState(() => _step = homeTourSteps[index + 1]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  Future<void> _skipTour() async {
    await RectoraScope.read(context).skipHomeTour();
    if (mounted) setState(() => _step = HomeTourStep.off);
  }

  Future<void> _pickMode(PlayMode mode) async {
    final controller = RectoraScope.read(context);
    if (_step != HomeTourStep.off) {
      await controller.finishHomeTour();
      if (mounted) setState(() => _step = HomeTourStep.off);
    }
    if (!mounted) return;
    await openModeLesson(context, mode);
  }

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final stats = controller.stats;
    final catalog = controller.catalog;
    final save = controller.save;
    final nextId = controller.continueParcelId();
    final next = catalog.parcelById(nextId);
    final today = dateKey(controller.now);
    final dailyDone = save.dailyCompleted.contains(today);
    final dailyLevel = catalog.daily.isEmpty
        ? null
        : catalog.dailyLevelFor(controller.now);
    final week = weekKey(controller.now);
    final weekly = controller.weeklyIds();
    final weeklyDone = weekly
        .where((id) => save.weeklySolved.contains('$week|$id'))
        .length;
    final started =
        save.lastPlayed != null ||
        stats.parcelsSolved > 0 ||
        stats.tracesSolved > 0 ||
        stats.inksSolved > 0 ||
        stats.threadsSolved > 0;
    final solved =
        stats.parcelsSolved +
        stats.tracesSolved +
        stats.inksSolved +
        stats.threadsSolved;
    final parcelTotal = catalog.parcels.length;
    final puzzleTotal =
        parcelTotal +
        catalog.traces.length +
        catalog.inks.length +
        catalog.threads.length;
    final choosing = _step == HomeTourStep.choose;
    final modes = [
      ModeArtworkCard(
        title: 'Parcels',
        body: 'Rectangles. One number, matching area.',
        done: stats.parcelsSolved,
        total: parcelTotal,
        tier: _tier(controller, PlayMode.parcel, catalog.parcelIds, [
          for (final level in catalog.parcels) level.difficulty,
        ]),
        art: ParcelArtPainter(palette),
        onTap: () => choosing
            ? _pickMode(PlayMode.parcel)
            : pushSoft(context, const CampaignPage(kind: CampaignKind.parcel)),
      ),
      ModeArtworkCard(
        title: 'Trace',
        body: 'One path through every cell, numbers in order.',
        done: stats.tracesSolved,
        total: catalog.traces.length,
        tier: _tier(controller, PlayMode.trace, catalog.traceIds, [
          for (final level in catalog.traces) level.difficulty,
        ]),
        art: TraceArtPainter(palette),
        onTap: () => choosing
            ? _pickMode(PlayMode.trace)
            : pushSoft(context, const CampaignPage(kind: CampaignKind.trace)),
      ),
      ModeArtworkCard(
        title: 'Inks',
        body: 'Connected regions. Shapes can bend.',
        done: stats.inksSolved,
        total: catalog.inks.length,
        tier: _tier(controller, PlayMode.ink, catalog.inkIds, [
          for (final level in catalog.inks) level.difficulty,
        ]),
        art: InkArtPainter(palette),
        onTap: () => choosing
            ? _pickMode(PlayMode.ink)
            : pushSoft(context, const CampaignPage(kind: CampaignKind.ink)),
      ),
      ModeArtworkCard(
        title: 'Threads',
        body: 'Join each letter pair without crossing.',
        done: stats.threadsSolved,
        total: catalog.threads.length,
        tier: _tier(controller, PlayMode.thread, catalog.threadIds, [
          for (final level in catalog.threads) level.difficulty,
        ]),
        art: ThreadArtPainter(palette),
        onTap: () => choosing
            ? _pickMode(PlayMode.thread)
            : pushSoft(context, const CampaignPage(kind: CampaignKind.thread)),
      ),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          const HomeAtmosphere(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    HomeHeader(
                      name: save.profile.name,
                      avatar: save.profile.avatar,
                      status: _focus(controller),
                      guideKey: _guideKey,
                      onProfile: () => pushSoft(context, const ProfilePage()),
                      onSettings: () => pushSoft(context, const SettingsPage()),
                      onHelp: () => pushSoft(context, const HelpPage()),
                    ),
                    if (_step == HomeTourStep.off &&
                        shouldOfferHomeTour(save)) ...[
                      const SizedBox(height: 12),
                      _TourInvite(
                        onStart: () =>
                            setState(() => _step = HomeTourStep.welcome),
                        onLater: _skipTour,
                      ),
                    ],
                    const SizedBox(height: 14),
                    ContinueHero(
                      key: _continueKey,
                      chapter: next?.packName ?? 'Parcels',
                      levelLabel: next == null
                          ? 'No puzzle is ready'
                          : '${next.number}. ${next.title}',
                      summary: next == null
                          ? 'The parcel campaign is empty.'
                          : '$solved of $puzzleTotal puzzles solved',
                      progress: puzzleTotal == 0 ? 0 : solved / puzzleTotal,
                      started: started && next != null,
                      onTap: next == null
                          ? null
                          : () => pushSoft(context, ParcelPage(level: next)),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Modes',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    KeyedSubtree(
                      key: _modesKey,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: modes[0]),
                              const SizedBox(width: 12),
                              Expanded(child: modes[1]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: modes[2]),
                              const SizedBox(width: 12),
                              Expanded(child: modes[3]),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    WeeklyFeatureCard(
                      key: _weeklyKey,
                      done: weeklyDone,
                      total: weekly.length,
                      reward: weeklyClearBonus,
                      claimed: save.weeklyClaimed.contains(week),
                      accountLabel: save.isGuest
                          ? 'Guest'
                          : save.isGoogle
                          ? 'Google'
                          : 'Play Games',
                      onTap: () => pushSoft(context, const WeeklyPage()),
                    ),
                    const SizedBox(height: 12),
                    DailyFeatureCard(
                      key: _dailyKey,
                      dateLabel: today,
                      difficulty: dailyLevel == null
                          ? 'No daily puzzle'
                          : dailyLevel.difficulty.label,
                      done: dailyDone,
                      streak: stats.currentStreak,
                      bestStreak: stats.longestStreak,
                      onTap: () => pushSoft(context, const DailyPage()),
                    ),
                    const SizedBox(height: 12),
                    MasteryPanel(
                      key: _progressKey,
                      mastery: save.xp,
                      solved: solved,
                      streak: stats.currentStreak,
                      bestDifficulty: _bestTier(stats.solvedByDifficulty),
                      openedLine: stats.parcelStarts == 0
                          ? null
                          : '${stats.parcelsSolved} of ${stats.parcelStarts} opened parcels solved',
                      onTap: () => pushSoft(context, const StatsPage()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_step == HomeTourStep.off && controller.suggestNextMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _NextModeOffer(
                seen: save.tutorialsSeen,
                onPick: _pickMode,
                onLater: controller.dismissModeOffer,
              ),
            ),
          if (_step != HomeTourStep.off)
            Positioned.fill(
              child: HomeTourOverlay(
                step: _step,
                holeKey: _holeKey,
                onNext: _advance,
                onSkip: _skipTour,
              ),
            ),
        ],
      ),
    );
  }
}

String _tier(
  RectoraController controller,
  PlayMode mode,
  List<String> ids,
  List<Difficulty> difficulties,
) {
  var best = Difficulty.beginner;
  for (var i = 0; i < ids.length; i++) {
    if (!controller.save.unlocked(mode, ids, ids[i])) continue;
    if (difficulties[i].index > best.index) best = difficulties[i];
  }
  return best.label;
}

String? _bestTier(Map<Difficulty, int> solved) {
  for (final difficulty in Difficulty.values.reversed) {
    if ((solved[difficulty] ?? 0) > 0) return difficulty.label;
  }
  return null;
}

class _TourInvite extends StatelessWidget {
  const _TourInvite({required this.onStart, required this.onLater});

  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New here?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Take a short tour of the home screen.'),
            Row(
              children: [
                TextButton(onPressed: onLater, child: const Text('Not now')),
                const Spacer(),
                TextButton(onPressed: onStart, child: const Text('Start tour')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextModeOffer extends StatelessWidget {
  const _NextModeOffer({
    required this.seen,
    required this.onPick,
    required this.onLater,
  });

  final Set<String> seen;
  final Future<void> Function(PlayMode mode) onPick;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    final open = [
      for (final id in modeLessonIds)
        if (!tutorialSettled(seen, id)) id,
    ];
    if (open.isEmpty) return const SizedBox.shrink();
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learn another mode?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Your progress stays. Pick another guided puzzle.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in open)
                  ActionChip(
                    label: Text(_modeLabel(id)),
                    onPressed: () => onPick(_modeFor(id)),
                  ),
                ActionChip(label: const Text('Not now'), onPressed: onLater),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _modeLabel(String id) {
  return switch (id) {
    'parcels' => 'Parcels',
    'trace' => 'Trace',
    'inks' => 'Inks',
    'threads' => 'Threads',
    _ => id,
  };
}

PlayMode _modeFor(String id) {
  return switch (id) {
    'trace' => PlayMode.trace,
    'inks' => PlayMode.ink,
    'threads' => PlayMode.thread,
    _ => PlayMode.parcel,
  };
}

String _focus(RectoraController controller) {
  final today = dateKey(controller.now);
  if (!controller.save.dailyCompleted.contains(today)) {
    return 'Today’s puzzle is open.';
  }
  final week = weekKey(controller.now);
  final ids = controller.weeklyIds();
  final done = ids
      .where((id) => controller.save.weeklySolved.contains('$week|$id'))
      .length;
  if (ids.isNotEmpty && done < ids.length) {
    return 'Weekly set: $done of ${ids.length}.';
  }
  return 'The next parcel is ready.';
}
