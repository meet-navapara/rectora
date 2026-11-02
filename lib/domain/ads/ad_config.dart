/// Rectora's AdMob units, requested only by release builds.
const productionRewardedUnitId = 'ca-app-pub-1959480289882936/4277154257';
const productionInterstitialUnitId = 'ca-app-pub-1959480289882936/1211560107';
const productionBannerUnitId = 'ca-app-pub-1959480289882936/7521817582';

/// Google's published Android sample ad units.
///
/// Debug and profile builds use these, so testing never touches the real
/// units. Tapping your own live ads can get an AdMob account suspended.
/// The Android app id follows the same rule in `android/app/build.gradle.kts`.
const googleSampleRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
const googleSampleInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';
const googleSampleBannerUnitId = 'ca-app-pub-3940256099942544/9214589741';
const googleSampleAppId = 'ca-app-pub-3940256099942544~3347511713';

/// Lets a release build on a test device request sample ads instead.
const allowTestAdsInRelease = bool.fromEnvironment('RECTORA_TEST_ADS');

const _isRelease = bool.fromEnvironment('dart.vm.product');

/// Whether this build requests the real units.
const _useProductionUnits = _isRelease && !allowTestAdsInRelease;

String get rewardedAdUnitId =>
    _useProductionUnits ? productionRewardedUnitId : googleSampleRewardedUnitId;

String get interstitialAdUnitId => _useProductionUnits
    ? productionInterstitialUnitId
    : googleSampleInterstitialUnitId;

String get bannerAdUnitId =>
    _useProductionUnits ? productionBannerUnitId : googleSampleBannerUnitId;

bool get usingSampleAdUnits => !_useProductionUnits;
