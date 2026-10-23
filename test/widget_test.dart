import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/app.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/settings/settings.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/widgets/campaign_map.dart';
import 'package:rectora/ui/widgets/mark.dart';

void _ignore(PackSummary pack) {}

Future<void> _dismissHomeTour(WidgetTester tester) async {
  final skip = find.text('Skip Tutorial');
  if (skip.evaluate().isEmpty) return;
  await tester.ensureVisible(skip);
  await tester.tap(skip);
  await tester.pumpAndSettle();
}

GameCatalog _sampleCatalog() {
  ParcelLevel parcel(int number) {
    return ParcelLevel(
      id: 'parcel-${number.toString().padLeft(3, '0')}',
      number: number,
      packId: 'first-light',
      packName: 'First Light',
      packBlurb: 'Small boards.',
      title: 'Parcel $number',
      difficulty: Difficulty.easy,
      milestone: false,
      puzzle: const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
      solution: const [GridRect(0, 0, 1, 1)],
    );
  }

  return GameCatalog(
    parcels: [parcel(1), parcel(2)],
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
    daily: [parcel(1)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the campaign map stays still when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRectoraTheme(RectoraPalette.dark),
        home: Scaffold(
          body: CampaignMap(
            reduceMotion: true,
            stops: const [
              CampaignStop(
                pack: PackSummary(
                  id: 'dawn',
                  name: 'Dawn',
                  blurb: 'Open ground.',
                  levelIds: ['parcel-001'],
                ),
                solved: 0,
                total: 1,
                locked: false,
                current: true,
              ),
            ],
            onOpen: _ignore,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Dawn'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'settings and profile stay on device and routes survive updates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MemoryStore();
      await tester.pumpWidget(
        RectoraApp(
          catalog: _sampleCatalog(),
          store: store,
          clock: () => DateTime(2026, 10, 21, 12),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play as Guest'));
      await tester.pumpAndSettle();
      await _dismissHomeTour(tester);

      expect(find.text('RECTORA'), findsOneWidget);
      expect(find.byType(RectoraMark), findsNothing);
      expect(find.byType(AvatarMark), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Guest account'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Show timer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Show timer'), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Show timer'));
      await tester.pumpAndSettle();
      expect(find.text('Show timer'), findsOneWidget);
      expect(store.values[saveKey], contains('"showTimer":false'));

      await tester.scrollUntilVisible(
        find.text('Dark'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(store.values[saveKey], contains('"theme":"dark"'));
      expect(find.text('Settings'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(store.values[saveKey], contains('"name":"Ada"'));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parcels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First Light'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);
      expect(find.text('Level locked'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2026-10-21'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2026-10-21'), findsOneWidget);
    },
  );

  testWidgets('light theme and larger text keep the home screen intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final store = MemoryStore();
    await store.write(
      saveKey,
      SaveGame.fresh()
          .copyWith(settings: const Settings(theme: ThemeChoice.light))
          .encode(),
    );
    await tester.pumpWidget(
      RectoraApp(
        catalog: _sampleCatalog(),
        store: store,
        clock: () => DateTime(2026, 10, 21, 12),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play as Guest'));
    await tester.pumpAndSettle();
    await _dismissHomeTour(tester);
    expect(find.text('RECTORA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
