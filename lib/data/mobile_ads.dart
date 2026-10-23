import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rectora/domain/ads/ad_config.dart';
import 'package:rectora/domain/ads/ad_policy.dart';

/// Loads Google's test units unless a production unit was compiled in.
///
/// Sample units are allowed during development. A production unit waits until
/// the consent status says ads may be requested. Gameplay does not wait on
/// either check.
Future<void> startMobileAds() async {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  if (binding.contains('Test')) return;
  try {
    if (!usingSampleAdUnits) {
      await _requestConsent();
      final allowed = await ConsentInformation.instance.canRequestAds();
      if (!allowed) return;
    }
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 8));
    Ads.rewarded = MobileRewardedAds();
    Ads.interstitials = MobileInterstitialAds();
  } catch (_) {
    Ads.rewarded = const UnavailableRewarded();
    Ads.interstitials = const UnavailableInterstitial();
  }
}

Future<void> _requestConsent() async {
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () async {
      try {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      } catch (_) {
        // A missing privacy message in the AdMob console is not a game error.
      }
      if (!done.isCompleted) done.complete();
    },
    (_) {
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
}

class MobileRewardedAds extends RewardedAds {
  var _busy = false;

  @override
  Future<RewardResult> show() async {
    if (_busy) {
      return const RewardResult(loaded: false, earned: false, failed: true);
    }
    _busy = true;
    RewardedAd? loaded;
    try {
      loaded = await _load();
      if (loaded == null) {
        return const RewardResult(loaded: false, earned: false, failed: true);
      }
      final earned = Completer<bool>();
      var rewarded = false;
      loaded.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!earned.isCompleted) earned.complete(rewarded);
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          if (!earned.isCompleted) earned.complete(false);
        },
      );
      await loaded.show(
        onUserEarnedReward: (_, _) {
          rewarded = true;
        },
      );
      loaded = null;
      final didEarn = await earned.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => false,
      );
      return RewardResult(loaded: true, earned: didEarn, failed: !didEarn);
    } catch (_) {
      loaded?.dispose();
      return const RewardResult(loaded: false, earned: false, failed: true);
    } finally {
      _busy = false;
    }
  }

  Future<RewardedAd?> _load() {
    final done = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: done.complete,
        onAdFailedToLoad: (_) {
          if (!done.isCompleted) done.complete(null);
        },
      ),
    );
    return done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
  }
}

class MobileInterstitialAds extends InterstitialAds {
  var _busy = false;

  @override
  Future<bool> show() async {
    if (_busy) return false;
    _busy = true;
    InterstitialAd? loaded;
    try {
      loaded = await _load();
      if (loaded == null) return false;
      final closed = Completer<void>();
      loaded.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!closed.isCompleted) closed.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          if (!closed.isCompleted) closed.complete();
        },
      );
      await loaded.show();
      loaded = null;
      await closed.future.timeout(const Duration(minutes: 2));
      return true;
    } catch (_) {
      loaded?.dispose();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<InterstitialAd?> _load() {
    final done = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: done.complete,
        onAdFailedToLoad: (_) {
          if (!done.isCompleted) done.complete(null);
        },
      ),
    );
    return done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
  }
}
