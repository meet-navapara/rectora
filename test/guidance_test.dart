import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/domain/account/firebase_start.dart';
import 'package:rectora/domain/ads/ad_policy.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/tutorial/progress.dart';

void main() {
  test('a skipped lesson is not marked complete and replay keeps solves', () {
    final solved = SaveGame.fresh().finishLevel(
      mode: PlayMode.parcel,
      id: 'parcel-009',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 1000,
    );
    final skipped = solved.skipTutorial('parcels');
    expect(tutorialSettled(skipped.tutorialsSeen, 'parcels'), isTrue);
    expect(tutorialCompleted(skipped.tutorialsSeen, 'parcels'), isFalse);
    expect(skipped.parcelRecords['parcel-009']!.solved, isTrue);

    final replayed = skipped.replayTutorials();
    expect(tutorialSettled(replayed.tutorialsSeen, 'parcels'), isFalse);
    expect(replayed.parcelRecords['parcel-009']!.solved, isTrue);
  });

  test('opening a lesson does not by itself settle it', () {
    expect(tutorialSettled(SaveGame.fresh().tutorialsSeen, 'trace'), isFalse);
  });

  test(
    'the first shipped level of each mode is marked as its lesson',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final name in ['parcels', 'traces', 'inks', 'threads']) {
        final raw = jsonDecode(
          await rootBundle.loadString('assets/levels/$name.json'),
        );
        final levels = raw['levels'] as List;
        expect((levels.first as Map)['tutorial'], isTrue, reason: name);
        expect((levels[1] as Map)['tutorial'], isTrue, reason: name);
        expect((levels[2] as Map)['tutorial'], isNot(true), reason: name);
      }
    },
  );

  test('lessons and repeated completions do not request an interstitial', () {
    const start = AdCadence();
    final lesson = start.afterCompletion(levelId: 'parcel-001', tutorial: true);
    expect(lesson.show, isFalse);
    expect(lesson.next.sinceInterstitial, 0);

    final first = start.afterCompletion(levelId: 'parcel-002', tutorial: false);
    final repeat = first.next.afterCompletion(
      levelId: 'parcel-002',
      tutorial: false,
    );
    expect(first.show, isFalse);
    expect(repeat.show, isFalse);
    expect(repeat.next.sinceInterstitial, 1);
  });

  test('the third distinct completion is the first interstitial', () {
    var state = const AdCadence();
    AdDecision? decision;
    for (final id in ['a', 'b', 'c']) {
      decision = state.afterCompletion(levelId: id, tutorial: false);
      state = decision.next;
    }
    expect(decision!.show, isTrue);
    expect(state.sinceInterstitial, 0);
  });

  test('a failed or repeated reward does not grant a hint', () async {
    final gate = RewardGate();
    expect(gate.accept(requestId: 1, earned: false), isFalse);
    expect(gate.accept(requestId: 1, earned: true), isTrue);
    expect(gate.accept(requestId: 1, earned: true), isFalse);

    final previous = Ads.rewarded;
    Ads.rewarded = const _DeniedReward();
    addTearDown(() => Ads.rewarded = previous);
    expect(await Ads.grantRewarded(), isFalse);
  });

  test('Firebase stays unconfigured until a build asks for it', () async {
    var called = false;
    final idle = await startFirebase(
      enabled: false,
      initialize: () async => called = true,
    );
    expect(idle, FirebaseStart.notConfigured);
    expect(called, isFalse);

    final failed = await startFirebase(
      enabled: true,
      initialize: () async => throw StateError('missing project'),
    );
    expect(failed, FirebaseStart.failed);
  });

  test('Firestore rules isolate each signed-in user', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    expect(rules, contains('request.auth.uid == uid'));
    expect(rules, isNot(contains('allow read, write: if true')));
  });
}

class _DeniedReward extends RewardedAds {
  const _DeniedReward();

  @override
  Future<RewardResult> show() async {
    return const RewardResult(loaded: false, earned: false, failed: true);
  }
}
