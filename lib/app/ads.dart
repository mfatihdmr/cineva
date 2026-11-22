import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config/secrets.dart';
import '../features/settings/settings_controller.dart';

/// AdMob yaşam döngüsü + UMP (GDPR/AB) rıza akışı.
///
/// Yayın öncesi kontrol listesi:
///  1. `android/local.properties` içindeki ADMOB_* değerlerini gerçek
///     AdMob panel kimliklerinle değiştir (test kimlikleri kalırsa
///     reklam isteği yapılmaz, sadece boşluk görünür).
///  2. `AndroidManifest.xml` içindeki `com.google.android.gms.ads.APPLICATION_ID`
///     de gerçek App ID olmalı (build.gradle `ADMOB_APP_ID` üzerinden gelir).
///  3. Play Console > Uygulama içeriği > Reklamlar beyanını tamamla.
class Ads {
  Ads._();

  static bool _sdkReady = false;
  static bool _consentResolved = false;
  static bool _canRequest = false;

  static bool get sdkReady => _sdkReady;
  static bool get canRequestAds => _canRequest;

  /// Reklamlar gerçekten aktif mi (kimlikler gerçek + rıza uygun).
  static bool get enabled => _canRequest && !_isTestMode;

  static bool get _isTestMode => Secrets.isTestId(Secrets.admobBannerId);

  static Future<void> bootstrap() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await MobileAds.instance.initialize();
      _sdkReady = true;
    } catch (e) {
      debugPrint('[Ads] initialize başarısız: $e');
      _sdkReady = false;
      return;
    }
    await _requestConsent();
  }

  /// Rıza akışı tamamlanana kadar bekler; [Ads.enabled] bu noktadan sonra
  /// geçerli değeri taşır.
  static Future<void> _requestConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((err) async {
          _consentResolved = true;
          _canRequest = await ConsentInformation.instance.canRequestAds();
          if (_canRequest) InterstitialAdManager.instance.preload();
          done.complete();
        });
      },
      (error) async {
        // Rıza bilgisi alınamadıysa bile canRequestAds kontrol edilebilir;
        // EEA dışındaki kullanıcılar için true dönebilir.
        _consentResolved = true;
        try {
          _canRequest = await ConsentInformation.instance.canRequestAds();
        } catch (_) {
          _canRequest = false;
        }
        if (_canRequest) InterstitialAdManager.instance.preload();
        done.complete();
        debugPrint('[Ads] consent update hatası: ${error.errorCode}');
      },
    );
    return done.future;
  }

  /// Ayarlardan "Reklam tercihleri" için privacy options formu.
  static Future<void> showPrivacyOptions() async {
    if (kIsWeb || !_sdkReady) return;
    await ConsentForm.showPrivacyOptionsForm((_) async {
      _canRequest = await ConsentInformation.instance.canRequestAds();
    });
  }

  static bool get consentResolved => _consentResolved;
}

final adsEnabledProvider = Provider<bool>((ref) {
  final personalized = ref.watch(settingsProvider).personalizedAds;
  return personalized && Ads.enabled;
});

/// Uyarlanabilir banner reklamı; başarısızsa hiçbir şey çizmez.
class BannerSlot extends ConsumerStatefulWidget {
  final AdSize size;
  const BannerSlot({super.key, this.size = AdSize.banner});

  @override
  ConsumerState<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends ConsumerState<BannerSlot> {
  BannerAd? _ad;
  bool _failed = false;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    if (_loading || _ad != null || _failed) return;
    if (!ref.read(adsEnabledProvider)) return;
    _loading = true;
    BannerAd(
      adUnitId: Secrets.admobBannerId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {
          _ad = ad as BannerAd;
          _loading = false;
        }),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          setState(() {
            _failed = true;
            _loading = false;
          });
          debugPrint('[Ads] banner yüklenemedi: ${err.message}');
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsEnabledProvider)) return const SizedBox.shrink();
    if (_ad == null && !_failed && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// Liste içine gömülen tam genişlikte banner satırı.
class InlineAdBanner extends ConsumerWidget {
  const InlineAdBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adsEnabledProvider)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: BannerSlot(),
    );
  }
}

/// Ekran altında yapışık, güvenli alanı olan banner.
class AnchoredBanner extends ConsumerStatefulWidget {
  const AnchoredBanner({super.key});

  @override
  ConsumerState<AnchoredBanner> createState() => _AnchoredBannerState();
}

class _AnchoredBannerState extends ConsumerState<AnchoredBanner> {
  BannerAd? _ad;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loading || _ad != null) return;
    if (!ref.read(adsEnabledProvider)) return;
    _loading = true;
    final width = MediaQuery.of(context).size.width.toInt();
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width > 0 ? width : 360,
    );
    if (!mounted || size == null) {
      _loading = false;
      return;
    }
    final ad = BannerAd(
      adUnitId: Secrets.admobBannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) => setState(() {
          _ad = a as BannerAd;
          _loading = false;
        }),
        onAdFailedToLoad: (a, e) {
          a.dispose();
          _loading = false;
          debugPrint('[Ads] anchored banner: ${e.message}');
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsEnabledProvider)) return const SizedBox.shrink();
    if (_ad == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: Center(child: AdWidget(ad: ad)),
    );
  }
}

/// Geçişlerde gösterilebilir tam ekran reklam (sınırlı kullanım).
class InterstitialAdManager {
  InterstitialAdManager._();
  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _ad;
  DateTime? _lastShown;

  bool get _throttledOk {
    final last = _lastShown;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= 12;
  }

  void preload() {
    if (!Ads.enabled || _ad != null) return;
    InterstitialAd.load(
      adUnitId: Secrets.admobInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (e) {
          _ad = null;
          debugPrint('[Ads] interstitial: ${e.message}');
        },
      ),
    );
  }

  /// Sekme değişiminde çağrılır; 12 saatte birden fazla göstermez.
  void maybeShow() {
    final ad = _ad;
    if (ad == null) {
      preload();
      return;
    }
    if (!_throttledOk) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _ad = null;
        _lastShown = DateTime.now();
        preload();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _ad = null;
      },
    );
    ad.show();
  }
}
