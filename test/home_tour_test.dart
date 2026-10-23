import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/app.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/account/progress_merge.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/records.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/ink/engine.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/trace/engine.dart';
import 'package:rectora/domain/tutorial/home_tour.dart';
import 'package:rectora/domain/tutorial/progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home onboarding and mode lessons stay separate', () {
    final fresh = SaveGame.fresh();
    expect(shouldAutoStartHomeTour(fresh), isTrue);
    expect(shouldOfferHomeTour(fresh), isFalse);

    final skipped = fresh
        .skipTutorial(homeIntroId)
        .copyWith(onboardingVersion: currentOnboardingVersion);
    expect(tutorialSettled(skipped.tutorialsSeen, homeIntroId), isTrue);
    for (final id in modeLessonIds) {
      expect(tutorialSettled(skipped.tutorialsSeen, id), isFalse);
    }
    expect(shouldAutoStartHomeTour(skipped), isFalse);

    final parcelsOnly = fresh.seeTutorial('parcels');
    expect(tutorialCompleted(parcelsOnly.tutorialsSeen, 'parcels'), isTrue);
    expect(tutorialSettled(parcelsOnly.tutorialsSeen, 'trace'), isFalse);
    expect(tutorialSettled(parcelsOnly.tutorialsSeen, 'inks'), isFalse);
    expect(tutorialSettled(parcelsOnly.tutorialsSeen, 'threads'), isFalse);
    expect(shouldAutoStartHomeTour(parcelsOnly), isFalse);
    expect(shouldOfferHomeTour(parcelsOnly), isTrue);

    final replayed = parcelsOnly.forgetTutorial('parcels');
    expect(tutorialSettled(replayed.tutorialsSeen, 'parcels'), isFalse);
    expect(replayed.parcelRecords, parcelsOnly.parcelRecords);

    final restored = _load(skipped.encode());
    expect(restored.onboardingVersion, currentOnboardingVersion);
    expect(tutorialSettled(restored.tutorialsSeen, homeIntroId), isTrue);

    final legacy = SaveGame.fromJson({'v': 1, 'xp': 4});
    expect(legacy.onboardingVersion, 0);
    expect(legacy.xp, 4);

    final merged = mergeProgress(
      device: skipped,
      account: fresh,
      difficulty: const {},
    ).save;
    expect(merged.onboardingVersion, currentOnboardingVersion);
    expect(tutorialSettled(merged.tutorialsSeen, homeIntroId), isTrue);
  });

  test('a tutorial level does not request an interstitial', () {
    const cadence = AdCadence(sinceInterstitial: interstitialEvery - 1);
    final decision = cadence.afterCompletion(
      levelId: 'parcel-001',
      tutorial: true,
    );
    expect(decision.show, isFalse);
    expect(decision.next.sinceInterstitial, cadence.sinceInterstitial);
  });

  testWidgets('a new guest sees the home tour once', (tester) async {
    final store = MemoryStore();
    await _open(tester, store, _catalog());
    expect(find.text('Welcome to RECTORA'), findsOneWidget);
    expect(find.text('Let\'s Begin'), findsOneWidget);
    expect(find.text('Skip Tutorial'), findsOneWidget);

    await tester.tap(find.text('Skip Tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to RECTORA'), findsNothing);
    final saved = _load(store.values[saveKey]!);
    expect(tutorialSettled(saved.tutorialsSeen, homeIntroId), isTrue);
    for (final id in modeLessonIds) {
      expect(tutorialSettled(saved.tutorialsSeen, id), isFalse);
    }
    expect(saved.parcelRecords, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _open(tester, store, _catalog());
    expect(find.text('Welcome to RECTORA'), findsNothing);
    expect(find.text('RECTORA'), findsOneWidget);
  });

  testWidgets('closing during the tour starts it again', (tester) async {
    final store = MemoryStore();
    await _open(tester, store, _catalog());
    expect(find.text('Welcome to RECTORA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _open(tester, store, _catalog());
    expect(find.text('Welcome to RECTORA'), findsOneWidget);
    final saved = _load(store.values[saveKey]!);
    expect(saved.parcelRecords, isEmpty);
    for (final id in modeLessonIds) {
      expect(tutorialSettled(saved.tutorialsSeen, id), isFalse);
    }
  });

  testWidgets('an existing player keeps progress and is not blocked', (
    tester,
  ) async {
    final played = SaveGame.fresh().copyWith(
      entered: true,
      parcelRecords: {
        'parcel-001': const LevelRecord(
          solved: true,
          skipped: false,
          hintsOnBestSolve: 0,
        ),
      },
    );
    final store = MemoryStore();
    await store.write(saveKey, played.encode());
    await _open(tester, store, _catalog(), guest: false);
    expect(find.text('Welcome to RECTORA'), findsNothing);
    expect(find.text('Take a short tour of the home screen.'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    final saved = _load(store.values[saveKey]!);
    expect(saved.parcelRecords['parcel-001']?.solved, isTrue);
    expect(tutorialSettled(saved.tutorialsSeen, homeIntroId), isTrue);
    expect(tutorialSettled(saved.tutorialsSeen, 'parcels'), isFalse);
  });

  testWidgets('choosing a mode keeps the home tour and opens that lesson', (
    tester,
  ) async {
    final ads = _CountingAds();
    final previous = Ads.interstitials;
    Ads.interstitials = ads;
    addTearDown(() => Ads.interstitials = previous);

    final store = MemoryStore();
    await _open(tester, store, _catalog());
    await tester.tap(find.text('Let\'s Begin'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Find Your Puzzle Style'), findsOneWidget);

    await tester.tap(find.text('Parcels'));
    await _pumpRoute(tester);
    expect(find.text('Cover the grid'), findsOneWidget);
    var saved = _load(store.values[saveKey]!);
    expect(tutorialCompleted(saved.tutorialsSeen, homeIntroId), isTrue);
    expect(tutorialSettled(saved.tutorialsSeen, 'parcels'), isFalse);
    expect(ads.shown, 0);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Skip Tutorial'));
    await tester.pump();
    saved = _load(store.values[saveKey]!);
    expect(tutorialCompleted(saved.tutorialsSeen, 'parcels'), isFalse);
    expect(tutorialSettled(saved.tutorialsSeen, 'parcels'), isTrue);
    expect(tutorialSettled(saved.tutorialsSeen, 'trace'), isFalse);
    expect(tutorialSettled(saved.tutorialsSeen, 'inks'), isFalse);
    expect(tutorialSettled(saved.tutorialsSeen, 'threads'), isFalse);
    expect(ads.shown, 0);

    await _leavePage(tester);
    expect(find.text('Learn another mode?'), findsNothing);
  });

  testWidgets('each mode guide opens its own lesson', (tester) async {
    final store = MemoryStore();
    final played = SaveGame.fresh().copyWith(
      entered: true,
      tutorialsSeen: {homeIntroId},
      onboardingVersion: currentOnboardingVersion,
    );
    await store.write(saveKey, played.encode());
    await _open(tester, store, _catalog(), guest: false);

    final lessons = {
      'Parcels guide': 'Cover the grid',
      'Trace guide': 'Start at 1',
      'Inks guide': 'Each number owns a group',
      'Threads guide': 'Find the matching letters',
    };
    for (final entry in lessons.entries) {
      await tester.tap(find.byTooltip('Help'));
      await tester.pumpAndSettle();
      expect(find.text('Home-screen guide'), findsOneWidget);
      expect(find.text(entry.key), findsOneWidget);
      final tile = find.ancestor(
        of: find.text(entry.key),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(
        find.descendant(of: tile, matching: find.text('Replay')),
      );
      await tester.tap(
        find.descendant(of: tile, matching: find.text('Replay')),
      );
      await _pumpRoute(tester);
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(find.text('Skip Tutorial'));
      await tester.pump();
      await _leavePage(tester);
      expect(find.text('How to play'), findsOneWidget);
      navigator(tester).pop();
      await tester.pumpAndSettle();
    }

    final saved = _load(store.values[saveKey]!);
    expect(saved.parcelRecords, isEmpty);
    expect(tutorialCompleted(saved.tutorialsSeen, homeIntroId), isTrue);
  });

  testWidgets('help can reopen the home guide', (tester) async {
    final store = MemoryStore();
    await _open(tester, store, _catalog());
    await tester.tap(find.text('Skip Tutorial'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Not started'), findsWidgets);
    final tile = find.ancestor(
      of: find.text('Home-screen guide'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: tile, matching: find.text('Replay')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to RECTORA'), findsOneWidget);
    final saved = _load(store.values[saveKey]!);
    expect(tutorialSettled(saved.tutorialsSeen, 'parcels'), isFalse);
  });
}

GameCatalog _catalog() {
  return GameCatalog(
    parcels: [
      ParcelLevel(
        id: 'parcel-001',
        number: 1,
        packId: 'first-light',
        packName: 'First Light',
        packBlurb: 'Small boards.',
        title: 'Parcel 1',
        difficulty: Difficulty.easy,
        milestone: false,
        tutorial: true,
        puzzle: const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
        solution: const [GridRect(0, 0, 1, 1)],
      ),
    ],
    traces: [
      const TraceLevel(
        id: 'trace-001',
        number: 1,
        packId: 'path',
        packName: 'Path',
        packBlurb: 'One path.',
        title: 'Trace 1',
        difficulty: Difficulty.easy,
        milestone: false,
        tutorial: true,
        puzzle: TracePuzzle(rows: 2, cols: 2, checkpoints: [0, 3]),
        solution: [0, 1, 3],
      ),
    ],
    inks: [
      InkLevel(
        id: 'ink-001',
        number: 1,
        packId: 'wash',
        packName: 'Wash',
        packBlurb: 'One group.',
        title: 'Ink 1',
        difficulty: Difficulty.easy,
        milestone: false,
        tutorial: true,
        puzzle: const InkPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
        solution: const [
          [0, 1, 2, 3],
        ],
      ),
    ],
    threads: [
      const ThreadLevel(
        id: 'thread-001',
        number: 1,
        packId: 'strand',
        packName: 'Single Strand',
        packBlurb: 'One path.',
        title: 'Thread 1',
        difficulty: Difficulty.easy,
        milestone: false,
        tutorial: true,
        puzzle: ThreadPuzzle(
          rows: 2,
          cols: 2,
          pairs: [ThreadPair(label: 'A', a: 0, b: 1)],
          blocked: [2, 3],
        ),
        solution: [
          [0, 1],
        ],
      ),
    ],
    daily: const [],
  );
}

Future<void> _open(
  WidgetTester tester,
  MemoryStore store,
  GameCatalog catalog, {
  bool guest = true,
}) async {
  await tester.pumpWidget(
    RectoraApp(
      catalog: catalog,
      store: store,
      clock: () => DateTime(2026, 10, 21, 12),
    ),
  );
  await tester.pumpAndSettle();
  if (!guest || find.text('Play as Guest').evaluate().isEmpty) return;
  await tester.tap(find.text('Play as Guest'));
  await tester.pumpAndSettle();
}

Future<void> _leavePage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (find.text('Leave').evaluate().isNotEmpty) {
    await tester.tap(find.text('Leave'));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

NavigatorState navigator(WidgetTester tester) {
  return tester.state<NavigatorState>(find.byType(Navigator));
}

SaveGame _load(String raw) {
  return SaveGame.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
}

class _CountingAds extends InterstitialAds {
  int shown = 0;

  @override
  Future<bool> show() async {
    shown++;
    return true;
  }
}
