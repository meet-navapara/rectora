/// One interstitial after this many newly completed levels.
const interstitialEvery = 3;

class AdCadence {
  const AdCadence({this.sinceInterstitial = 0, this.lastLevelId});

  final int sinceInterstitial;
  final String? lastLevelId;

  AdDecision afterCompletion({
    required String levelId,
    required bool tutorial,
  }) {
    if (tutorial || levelId.isEmpty || levelId == lastLevelId) {
      return AdDecision.skip(this);
    }
    final nextCount = sinceInterstitial + 1;
    if (nextCount >= interstitialEvery) {
      return AdDecision.show(
        AdCadence(sinceInterstitial: 0, lastLevelId: levelId),
      );
    }
    return AdDecision.wait(
      AdCadence(sinceInterstitial: nextCount, lastLevelId: levelId),
    );
  }
}

class AdDecision {
  const AdDecision._(this.show, this.next);

  const AdDecision.skip(AdCadence next) : this._(false, next);
  const AdDecision.wait(AdCadence next) : this._(false, next);
  const AdDecision.show(AdCadence next) : this._(true, next);

  final bool show;
  final AdCadence next;
}

class RewardResult {
  const RewardResult({
    required this.loaded,
    required this.earned,
    required this.failed,
  });

  final bool loaded;
  final bool earned;
  final bool failed;
}

abstract class RewardedAds {
  const RewardedAds();

  Future<RewardResult> show();
}

abstract class InterstitialAds {
  const InterstitialAds();

  Future<bool> show();
}

class UnavailableRewarded extends RewardedAds {
  const UnavailableRewarded();

  @override
  Future<RewardResult> show() async {
    return const RewardResult(loaded: false, earned: false, failed: true);
  }
}

class UnavailableInterstitial extends InterstitialAds {
  const UnavailableInterstitial();

  @override
  Future<bool> show() async => false;
}

/// Accepts one reward callback per request. Opening or closing an ad is not
/// enough, and the same request cannot be granted twice.
class RewardGate {
  final Set<int> _granted = {};

  bool accept({required int requestId, required bool earned}) {
    if (!earned || _granted.contains(requestId)) return false;
    _granted.add(requestId);
    return true;
  }
}

class Ads {
  static RewardedAds rewarded = const UnavailableRewarded();
  static InterstitialAds interstitials = const UnavailableInterstitial();
  static AdCadence cadence = const AdCadence();
  static final rewards = RewardGate();
  static var _rewardRequest = 0;

  static Future<bool> grantRewarded() async {
    final requestId = ++_rewardRequest;
    final RewardResult result;
    try {
      result = await rewarded.show();
    } catch (_) {
      return false;
    }
    return rewards.accept(requestId: requestId, earned: result.earned);
  }

  static Future<void> afterLevel({
    required String levelId,
    required bool tutorial,
  }) async {
    final decision = cadence.afterCompletion(
      levelId: levelId,
      tutorial: tutorial,
    );
    cadence = decision.next;
    if (!decision.show) return;
    try {
      await interstitials.show();
    } catch (_) {
      // A missing ad never blocks the next level.
    }
  }
}
