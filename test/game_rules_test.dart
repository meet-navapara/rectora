import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/app.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/ads/ad_config.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/tutorial.dart';
import 'package:rectora/ui/widgets/ad_banner.dart';

GameCatalog _catalog() {
  ParcelLevel parcel(int number) => ParcelLevel(
    id: 'parcel-${number.toString().padLeft(3, '0')}',
    number: number,
    packId: 'dawn',
    packName: 'Dawn',
    packBlurb: 'Small boards.',
    title: 'Parcel $number',
    difficulty: Difficulty.hard,
    milestone: false,
    puzzle: const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
    solution: const [GridRect(0, 0, 1, 1)],
  );
  return GameCatalog(
    parcels: [for (var i = 3; i <= 6; i++) parcel(i)],
    threads: const [
      ThreadLevel(
        id: 'thread-001',
        number: 1,
        packId: 'strand',
        packName: 'Single Strand',
        packBlurb: 'One path.',
        title: 'Thread 1',
        difficulty: Difficulty.easy,
        milestone: false,
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
    daily: [parcel(3)],
  );
}

Future<void> _openHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RectoraApp(
      catalog: _catalog(),
      store: MemoryStore(),
      clock: () => DateTime(2026, 10, 21, 12),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Play as Guest'));
  await tester.pumpAndSettle();
  final skip = find.text('Skip Tutorial');
  if (skip.evaluate().isNotEmpty) {
    await tester.tap(skip);
    await tester.pumpAndSettle();
  }
}

class _Reward extends RewardedAds {
  _Reward(this.earn);

  final bool earn;
  int shown = 0;

  @override
  Future<RewardResult> show() async {
    shown++;
    return RewardResult(loaded: true, earned: earn, failed: !earn);
  }
}

class _Interstitial extends InterstitialAds {
  int shown = 0;

  @override
  Future<bool> show() async {
    shown++;
    return true;
  }
}

Future<bool?> _claim(WidgetTester tester, int used) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRectoraTheme(RectoraPalette.dark),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await claimHint(context, used);
            },
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  tearDown(() {
    Ads.rewarded = const UnavailableRewarded();
    Ads.interstitials = const UnavailableInterstitial();
    Ads.cadence = const AdCadence();
    Ads.bannersOn = false;
  });

  testWidgets('both sign-in buttons fit on a small phone without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RectoraApp(
        catalog: _catalog(),
        store: MemoryStore(),
        clock: () => DateTime(2026, 10, 21, 12),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Play as Guest', 'Continue with Google']) {
      expect(
        tester.getBottomLeft(find.text(label)).dy,
        lessThan(568),
        reason: label,
      );
    }
  });

  testWidgets('a locked level stays closed until the one before is finished', (
    tester,
  ) async {
    await _openHome(tester);
    await tester.tap(find.text('Parcels').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dawn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(find.text('Finish level 3 first.'), findsOneWidget);
    expect(find.byType(ParcelPage), findsNothing);
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.byType(ParcelPage), findsOneWidget);
  });

  testWidgets('the first hint in a puzzle is free', (tester) async {
    final reward = _Reward(true);
    Ads.rewarded = reward;
    expect(await _claim(tester, 0), isTrue);
    expect(reward.shown, 0);
  });

  testWidgets('a used hint can only be followed by a finished ad', (
    tester,
  ) async {
    final reward = _Reward(true);
    Ads.rewarded = reward;
    await _claim(tester, 1);
    expect(find.text('No free hints left'), findsOneWidget);
    await tester.tap(find.text('Watch ad'));
    await tester.pumpAndSettle();
    expect(reward.shown, 1);
  });

  testWidgets('an unfinished ad gives no hint and says so', (tester) async {
    Ads.rewarded = _Reward(false);
    await _claim(tester, 1);
    await tester.tap(find.text('Watch ad'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('did not finish'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('without ads a used hint offers no ad', (tester) async {
    expect(Ads.canOfferReward, isFalse);
    await _claim(tester, 1);
    expect(find.text('No hints left'), findsOneWidget);
    expect(find.text('Watch ad'), findsNothing);
  });

  test('a full-screen ad follows every third level across all modes', () async {
    final ads = _Interstitial();
    Ads.interstitials = ads;
    for (final id in [
      'parcel-010',
      'trace-010',
      'ink-010',
      'thread-010',
      'daily@2026-10-21',
      'weekly@parcel-020',
    ]) {
      await Ads.afterLevel(levelId: id, tutorial: false);
    }
    expect(ads.shown, 2);
  });

  test('lessons and an immediate replay do not count toward an ad', () async {
    final ads = _Interstitial();
    Ads.interstitials = ads;
    await Ads.afterLevel(levelId: 'parcel-001', tutorial: true);
    await Ads.afterLevel(levelId: 'parcel-002', tutorial: true);
    await Ads.afterLevel(levelId: 'parcel-003', tutorial: false);
    await Ads.afterLevel(levelId: 'parcel-003', tutorial: false);
    expect(ads.shown, 0);
    expect(Ads.cadence.sinceInterstitial, 1);
  });

  test('sample ad units stay separate from real ones', () {
    expect(usingSampleAdUnits, isTrue);
    expect(bannerAdUnitId, googleSampleBannerUnitId);
  });

  testWidgets('every browsing screen carries the banner, and takes no space '
      'without an ad', (tester) async {
    await _openHome(tester);
    for (final mode in ['Parcels', 'Trace', 'Inks', 'Threads']) {
      await tester.tap(find.text(mode).first);
      await tester.pumpAndSettle();
      expect(find.byType(AdBanner), findsOneWidget, reason: mode);
      expect(tester.getSize(find.byType(AdBanner)).height, 0, reason: mode);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  test('skips are counted per mode, not across daily or weekly', () {
    var save = SaveGame.fresh();
    save = save.finishLevel(
      id: 'weekly@parcel-009',
      skipped: true,
      hintsUsed: 0,
      elapsedMs: 1,
    );
    expect(save.skipsLeft(PlayMode.parcel), 3);
  });
}
