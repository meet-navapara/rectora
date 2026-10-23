import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/parcels/session.dart';
import 'package:rectora/domain/tutorial/coach.dart';
import 'package:rectora/domain/tutorial/progress.dart';

void main() {
  test('the parcel lesson demonstrates a real rectangle, then waits', () {
    const puzzle = ParcelPuzzle(
      rows: 2,
      cols: 3,
      clues: [Clue(0, 0, 4), Clue(0, 2, 2)],
    );
    const solution = [GridRect(0, 0, 1, 1), GridRect(0, 2, 1, 2)];
    final coach = PlayCoach(
      parcelGuide(number: 1, solution: solution, cols: 3),
      hintCopy: parcelHintCopy,
    );
    expect(coach.phase, CoachPhase.intro);
    expect(coach.locksInput, isTrue);
    coach.continuePressed();
    expect(coach.phase, CoachPhase.demonstrating);
    expect(coach.step.kind, GuideKind.demonstrate);

    final session = ParcelSession(puzzle: puzzle, strictness: Strictness.basic);
    final shown = rectFromCells(coach.step.cells, 3);
    expect(session.commit(shown, rules: Strictness.basic), PlacementIssue.ok);
    expect(session.placed, [shown]);
    coach.demonstrationFinished();
    expect(coach.phase, CoachPhase.waitingForPlayer);
    expect(coach.locksInput, isFalse);

    final wrong = session.commit(
      const GridRect(0, 0, 0, 0),
      rules: Strictness.basic,
    );
    expect(wrong, isNot(PlacementIssue.ok));
    expect(coach.judge(rectCells(const GridRect(0, 1, 0, 1), 3)), isFalse);
    expect(coach.phase, CoachPhase.correctiveHint);

    final second = rectFromCells(coach.step.cells, 3);
    expect(session.commit(second, rules: Strictness.basic), PlacementIssue.ok);
    expect(coach.judge(rectCells(second, 3)), isTrue);
    expect(coach.phase, CoachPhase.successFeedback);
    expect(session.isComplete, isTrue);
    coach.markSolved();
    expect(coach.phase, CoachPhase.completed);
  });

  test('skipping a lesson does not record it as finished', () {
    final coach = PlayCoach(
      traceGuide(number: 1, solution: const [0, 1, 2, 5, 4, 3]),
      hintCopy: traceHintCopy,
    );
    coach.skip();
    expect(coach.phase, CoachPhase.skipped);
    final save = SaveGame.fresh().skipTutorial('parcels');
    expect(tutorialSettled(save.tutorialsSeen, 'parcels'), isTrue);
    expect(tutorialCompleted(save.tutorialsSeen, 'parcels'), isFalse);
    expect(tutorialSettled(save.tutorialsSeen, 'trace'), isFalse);
  });

  test('a trace prefix is kept and a detour is rejected', () {
    final coach = PlayCoach(
      traceGuide(number: 2, solution: const [0, 1, 2, 5]),
      hintCopy: traceHintCopy,
    );
    coach.continuePressed();
    expect(coach.phase, CoachPhase.waitingForPlayer);
    expect(coach.judge(const [0]), isTrue);
    expect(coach.phase, CoachPhase.waitingForPlayer);
    expect(coach.judge(const [0, 1]), isTrue);
    expect(coach.phase, CoachPhase.successFeedback);
    coach.replay();
    expect(coach.phase, CoachPhase.intro);
  });

  test('a guided level does not request an interstitial', () {
    const cadence = AdCadence(sinceInterstitial: interstitialEvery - 1);
    final decision = cadence.afterCompletion(
      levelId: 'parcel-001',
      tutorial: true,
    );
    expect(decision.show, isFalse);
  });

  test('one finished mode lesson leaves the others open', () {
    final save = SaveGame.fresh().seeTutorial('parcels');
    expect(tutorialCompleted(save.tutorialsSeen, 'parcels'), isTrue);
    expect(tutorialSettled(save.tutorialsSeen, 'trace'), isFalse);
    expect(tutorialSettled(save.tutorialsSeen, 'inks'), isFalse);
    expect(tutorialSettled(save.tutorialsSeen, 'threads'), isFalse);
    expect(save.parcelRecords, isEmpty);
    final replayed = save.forgetTutorial('parcels');
    expect(tutorialSettled(replayed.tutorialsSeen, 'parcels'), isFalse);
    expect(replayed.parcelRecords, isEmpty);
  });
}
