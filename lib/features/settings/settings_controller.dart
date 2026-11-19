import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeX { system, light, dark }

class SettingsState {
  final bool loaded;
  final ThemeModeX themeMode;
  final String languageCode; // tr | en
  final String contentLanguage; // TMDB `language` parametresi
  final String region; // ISO-3166 alpha-2
  final bool showAdult;
  final bool onboardingDone;
  final bool personalizedAds;
  final int appOpenCount;
  final String? lastInterstitialAt;

  const SettingsState({
    this.loaded = false,
    this.themeMode = ThemeModeX.dark,
    this.languageCode = 'tr',
    this.contentLanguage = 'tr-TR',
    this.region = 'TR',
    this.showAdult = false,
    this.onboardingDone = false,
    this.personalizedAds = true,
    this.appOpenCount = 0,
    this.lastInterstitialAt,
  });

  ThemeMode get themeModeFlutter => switch (themeMode) {
        ThemeModeX.system => ThemeMode.system,
        ThemeModeX.light => ThemeMode.light,
        ThemeModeX.dark => ThemeMode.dark,
      };

  SettingsState copyWith({
    bool? loaded,
    ThemeModeX? themeMode,
    String? languageCode,
    String? contentLanguage,
    String? region,
    bool? showAdult,
    bool? onboardingDone,
    bool? personalizedAds,
    int? appOpenCount,
    String? lastInterstitialAt,
  }) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
        contentLanguage: contentLanguage ?? this.contentLanguage,
        region: region ?? this.region,
        showAdult: showAdult ?? this.showAdult,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        personalizedAds: personalizedAds ?? this.personalizedAds,
        appOpenCount: appOpenCount ?? this.appOpenCount,
        lastInterstitialAt: lastInterstitialAt ?? this.lastInterstitialAt,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._prefs) : super(SettingsState(
          loaded: _prefs == null,
          themeMode: ThemeModeX.values[_prefs?.getInt('theme_mode') ?? 2],
          languageCode: _prefs?.getString('lang') ?? 'tr',
          contentLanguage: _prefs?.getString('content_lang') ?? 'tr-TR',
          region: _prefs?.getString('region') ?? 'TR',
          showAdult: _prefs?.getBool('show_adult') ?? false,
          onboardingDone: _prefs?.getBool('onboarded') ?? false,
          personalizedAds: _prefs?.getBool('personalized_ads') ?? true,
          appOpenCount: _prefs?.getInt('open_count') ?? 0,
          lastInterstitialAt: _prefs?.getString('last_interstitial'),
        ));

  final SharedPreferences? _prefs;

  SharedPreferences? get _p => _prefs;

  Future<void> _set(String key, Object? value) async {
    final p = _p;
    if (p == null) return;
    switch (value) {
      case bool v:
        await p.setBool(key, v);
      case int v:
        await p.setInt(key, v);
      case String v:
        await p.setString(key, v);
    }
  }

  void setThemeMode(ThemeModeX mode) {
    state = state.copyWith(themeMode: mode);
    _set('theme_mode', mode.index);
  }

  void setLanguage(String code, String contentLang) {
    state = state.copyWith(languageCode: code, contentLanguage: contentLang);
    _set('lang', code);
    _set('content_lang', contentLang);
  }

  void setRegion(String region) {
    state = state.copyWith(region: region.toUpperCase());
    _set('region', region.toUpperCase());
  }

  void setShowAdult(bool value) {
    state = state.copyWith(showAdult: value);
    _set('show_adult', value);
  }

  void finishOnboarding() {
    state = state.copyWith(onboardingDone: true);
    _set('onboarded', true);
  }

  void setPersonalizedAds(bool value) {
    state = state.copyWith(personalizedAds: value);
    _set('personalized_ads', value);
  }

  Future<void> registerAppOpen() async {
    final count = state.appOpenCount + 1;
    state = state.copyWith(appOpenCount: count);
    await _set('open_count', count);
  }

  Future<void> markInterstitialShown() async {
    final now = DateTime.now().toIso8601String();
    state = state.copyWith(lastInterstitialAt: now);
    await _set('last_interstitial', now);
  }

  /// En az 12 saat geçmişse reklam gösterilebilir.
  bool get canShowInterstitial {
    final last = state.lastInterstitialAt;
    if (last == null) return state.appOpenCount >= 4;
    final dt = DateTime.tryParse(last);
    if (dt == null) return true;
    return DateTime.now().difference(dt).inHours >= 12;
  }
}

/// main() içinde provider override olarak verilir; prefs yoksa güvenli varsayılan.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});
