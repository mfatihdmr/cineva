import 'package:flutter/foundation.dart';

/// Gizli yapılandırmanın tek giriş noktası.
///
/// Android: `android/local.properties` içindeki değerler derleme sırasında
/// BuildConfig'e yazılır, çalışma zamanında [ConfigChannel] ile okunur.
/// Web/test: `--dart-define=TMDB_API_KEY=...` ya da aşağıdaki geliştirme
/// varsayılanı kullanılır.
class Secrets {
  Secrets._();

  /// Yerel geliştirme varsayılanı (yalnızca debug/web için).
  /// Android derlemesinde anahtar `android/local.properties` üzerinden gelir.
  static const String devApiKey = String.fromEnvironment('TMDB_API_KEY');

  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696142';
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';

  static String _tmdbApiKey = kIsWeb ? devApiKey : '';
  static String _bannerId = '';
  static String _nativeId = '';
  static String _interstitialId = '';

  /// [ConfigChannel] okunduktan sonra çağrılır.
  static void apply({
    required String apiKey,
    String? banner,
    String? native,
    String? interstitial,
  }) {
    _tmdbApiKey = apiKey;
    _bannerId = banner ?? '';
    _nativeId = native ?? '';
    _interstitialId = interstitial ?? '';
  }

  static String get tmdbApiKey =>
      _tmdbApiKey.trim().isNotEmpty ? _tmdbApiKey.trim() : devApiKey;

  static String get admobBannerId => _pick(_bannerId, _testBanner);
  static String get admobNativeId => _pick(_nativeId, _testNative);
  static String get admobInterstitialId => _pick(_interstitialId, _testInterstitial);

  static String _pick(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  /// Google'un resmi test kimlikleri => gerçek reklam isteği yapılmaz.
  static bool isTestId(String id) => id.startsWith('ca-app-pub-3940256099942544');

  static bool get hasApiKey => tmdbApiKey.isNotEmpty;

  /// Yayına alma kontrol listesi için: gerçek reklam kimliği girilmiş mi?
  static bool get adsAreProduction =>
      !isTestId(admobBannerId) && !isTestId(admobNativeId);
}
