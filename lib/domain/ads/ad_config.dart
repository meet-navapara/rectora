/// Google's published Android sample ad units.
///
/// These are test ids from Google's AdMob test-ad documentation. They are not
/// a production monetization setup. Replace them at build time with
/// `--dart-define=RECTORA_REWARDED_AD_UNIT=...`,
/// `--dart-define=RECTORA_INTERSTITIAL_AD_UNIT=...`, and
/// `--dart-define=RECTORA_BANNER_AD_UNIT=...` after an AdMob app exists.
/// The Android app id is the manifest placeholder `RECTORA_ADMOB_APP_ID`.
const googleSampleRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
const googleSampleInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';
const googleSampleBannerUnitId = 'ca-app-pub-3940256099942544/9214589741';
const googleSampleAppId = 'ca-app-pub-3940256099942544~3347511713';

const rewardedAdUnitOverride = String.fromEnvironment(
  'RECTORA_REWARDED_AD_UNIT',
);
const interstitialAdUnitOverride = String.fromEnvironment(
  'RECTORA_INTERSTITIAL_AD_UNIT',
);
const bannerAdUnitOverride = String.fromEnvironment('RECTORA_BANNER_AD_UNIT');

/// Lets a release build on a test device request sample ads.
const allowTestAdsInRelease = bool.fromEnvironment('RECTORA_TEST_ADS');

String get rewardedAdUnitId => rewardedAdUnitOverride.isEmpty
    ? googleSampleRewardedUnitId
    : rewardedAdUnitOverride;

String get interstitialAdUnitId => interstitialAdUnitOverride.isEmpty
    ? googleSampleInterstitialUnitId
    : interstitialAdUnitOverride;

String get bannerAdUnitId => bannerAdUnitOverride.isEmpty
    ? googleSampleBannerUnitId
    : bannerAdUnitOverride;

bool get usingSampleAdUnits =>
    rewardedAdUnitId == googleSampleRewardedUnitId &&
    interstitialAdUnitId == googleSampleInterstitialUnitId &&
    bannerAdUnitId == googleSampleBannerUnitId;
