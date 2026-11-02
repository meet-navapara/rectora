import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/app.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/settings/settings.dart';
import 'package:rectora/domain/threads/models.dart';
import 'package:rectora/domain/trace/engine.dart';
import 'package:rectora/domain/tutorial/coach.dart';
import 'package:rectora/domain/tutorial/home_tour.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/screens/trace_page.dart';
import 'package:rectora/ui/widgets/parcel_board.dart';
import 'package:rectora/ui/widgets/trace_board.dart';

/// Skipping a lesson must leave a normal, playable board behind.
void main() {
  final parcel = ParcelLevel(
    id: 'parcel-001',
    number: 1,
    packId: 'dawn',
    packName: 'Dawn',
    packBlurb: 'Small boards.',
    title: 'Parcel 1',
    difficulty: Difficulty.beginner,
    milestone: false,
    tutorial: true,
    puzzle: const ParcelPuzzle(
      rows: 2,
      cols: 2,
      clues: [Clue(0, 0, 2), Clue(1, 0, 2)],
    ),
    solution: const [GridRect(0, 0, 0, 1), GridRect(1, 0, 1, 1)],
  );
  const trace = TraceLevel(
    id: 'trace-001',
    number: 1,
    packId: 'first-step',
    packName: 'First Step',
    packBlurb: 'A short path.',
    title: 'Trace 1',
    difficulty: Difficulty.beginner,
    milestone: false,
    tutorial: true,
    puzzle: TracePuzzle(rows: 2, cols: 3, checkpoints: [0, 1, 2, 5, 4, 3]),
    solution: [0, 1, 2, 5, 4, 3],
  );
  final catalog = GameCatalog(
    parcels: [parcel],
    traces: const [trace],
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
    daily: [parcel],
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    final save = SaveGame.fresh().copyWith(
      entered: true,
      // The sound plugin has no test double, so keep it off here.
      settings: const Settings(sound: false, haptics: false),
      tutorialsSeen: {homeIntroId},
      onboardingVersion: currentOnboardingVersion,
    );
    await store.write(saveKey, save.encode());
    await tester.pumpWidget(RectoraApp(catalog: catalog, store: store));
    await settle(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await settle(tester);
    expect(find.text('Skip Tutorial'), findsOneWidget);
    await tester.tap(find.text('Skip Tutorial'));
    await settle(tester);
    expect(find.text('Skip Tutorial'), findsNothing);
  }

  Offset cellCenter(Rect board, int rows, int cols, int row, int col) {
    final cell = (board.width / cols) < (board.height / rows)
        ? board.width / cols
        : board.height / rows;
    final origin = board.center - Offset(cell * cols / 2, cell * rows / 2);
    return origin + Offset(cell * (col + 0.5), cell * (row + 0.5));
  }

  testWidgets('a skipped Parcels lesson can still be played to the end', (
    tester,
  ) async {
    await open(tester, ParcelPage(level: parcel));
    final board = tester.getRect(find.byType(ParcelBoard));
    for (final row in [0, 1]) {
      await tester.dragFrom(
        cellCenter(board, 2, 2, row, 0),
        cellCenter(board, 2, 2, row, 1) - cellCenter(board, 2, 2, row, 0),
      );
      await settle(tester);
    }
    expect(find.text('Parcel complete'), findsOneWidget);
  });

  testWidgets('a skipped Trace lesson can still be played to the end', (
    tester,
  ) async {
    await open(tester, const TracePage(level: trace));
    final board = tester.getRect(find.byType(TraceBoard));
    final finger = await tester.startGesture(cellCenter(board, 2, 3, 0, 0));
    for (final cell in trace.solution.skip(1)) {
      await finger.moveTo(cellCenter(board, 2, 3, cell ~/ 3, cell % 3));
      await tester.pump();
    }
    await finger.up();
    await settle(tester);
    expect(find.text('Path complete'), findsOneWidget);
  });

  test('a finished or skipped lesson frees the board in every mode', () {
    for (final ended in [CoachPhase.skipped, CoachPhase.completed]) {
      final coach = PlayCoach(
        const [GuideStep(kind: GuideKind.intro, title: 'a', body: 'b')],
        hintCopy: const ['1', '2', '3'],
      )..phase = ended;
      expect(coach.locksInput, isFalse, reason: '$ended');
      expect(coach.restrictsEditing, isFalse, reason: '$ended');
      expect(coach.expectsMove, isFalse, reason: '$ended');
    }
  });
}
