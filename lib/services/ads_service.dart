import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Publicités AdMob, jamais pendant une manche : une interstitielle au plus
/// toutes les deux parties, au moment de relancer.
///
/// Les identifiants ci-dessous sont les identifiants de TEST publics de
/// Google. Ils sont à remplacer par ceux du compte AdMob avant publication
/// (et `APPLICATION_ID` dans tools/patch_android.py).
class AdsService {
  AdsService._();

  static const interstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static bool _ready = false;
  static InterstitialAd? _interstitial;
  static int _gamesSinceAd = 0;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      await MobileAds.instance.initialize();
      // jeu familial : contenus publicitaires tout public uniquement
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
      _ready = true;
      _load();
    } catch (e) {
      debugPrint('AdMob indisponible : $e');
    }
  }

  static void _load() {
    if (!_ready) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Appelé quand une partie se termine.
  static void gameFinished() => _gamesSinceAd++;

  /// Avant de relancer une partie : montre une interstitielle si c'est le
  /// moment, puis appelle [then] (immédiatement sinon).
  static void beforeNextGame(VoidCallback then) {
    final ad = _interstitial;
    if (!_ready || ad == null || _gamesSinceAd < 2) {
      then();
      return;
    }
    _gamesSinceAd = 0;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _load();
        then();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _load();
        then();
      },
    );
    ad.show();
  }
}
