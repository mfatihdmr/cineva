import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Yerel (Android BuildConfig) yapılandırma değerlerini okur.
///
/// `android/local.properties` içinde tutulan anahtarlar derleme sırasında
/// BuildConfig'e yazılır, uygulama çalışırken bu kanal üzerinden alınır.
/// Böylece anahtar Dart kaynak koduna gömülü olmaz.
class ConfigChannel {
  ConfigChannel._();

  static const MethodChannel _channel =
      MethodChannel('app.cineva.cineva/config');

  static final Map<String, String> _values = <String, String>{};
  static bool _loaded = false;

  static Future<void> loadAll() async {
    if (_loaded || kIsWeb) return;
    for (final key in const [
      'TMDB_API_KEY',
      'ADMOB_BANNER_ID',
      'ADMOB_NATIVE_ID',
      'ADMOB_INTERSTITIAL_ID',
    ]) {
      try {
        final v =
            await _channel.invokeMethod<String>('getConfig', {'key': key});
        _values[key] = v ?? '';
      } on MissingPluginException {
        _loaded = true;
        return;
      } catch (_) {
        _values[key] = '';
      }
    }
    _loaded = true;
  }

  /// Okunamayan anahtarda [fallback] döner.
  static String value(String key, {String fallback = ''}) =>
      _values[key]?.isNotEmpty == true ? _values[key]! : fallback;

  static String tmdbApiKey(String fallback) =>
      value('TMDB_API_KEY', fallback: fallback);
}
