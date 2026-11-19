import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ads.dart';
import '../../app/config/app_config.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';
import '../legal/legal_screen.dart';
import 'settings_controller.dart';

const _quickCountries = <(String, String)>{
  ('TR', 'Türkiye'),
  ('US', 'ABD'),
  ('GB', 'Birleşik Krallık'),
  ('DE', 'Almanya'),
  ('FR', 'Fransa'),
  ('ES', 'İspanya'),
  ('IT', 'İtalya'),
  ('CA', 'Kanada'),
  ('AU', 'Avustralya'),
  ('BR', 'Brezilya'),
  ('JP', 'Japonya'),
  ('KR', 'Güney Kore'),
  ('RU', 'Rusya'),
  ('NL', 'Hollanda'),
  ('SE', 'İsveç'),
  ('NO', 'Norveç'),
  ('DK', 'Danimarka'),
  ('PL', 'Polonya'),
  ('CZ', 'Çekya'),
  ('GR', 'Yunanistan'),
  ('IN', 'Hindistan'),
  ('MX', 'Meksika'),
};

const _contentLanguages = <(String, String)>[
  ('tr-TR', 'Türkçe (tr-TR)'),
  ('en-US', 'English (en-US)'),
  ('de-DE', 'Deutsch (de-DE)'),
  ('fr-FR', 'Français (fr-FR)'),
  ('es-ES', 'Español (es-ES)'),
  ('it-IT', 'Italiano (it-IT)'),
  ('pt-BR', 'Português (pt-BR)'),
  ('ru-RU', 'Русский (ru-RU)'),
  ('ja-JP', '日本語 (ja-JP)'),
  ('ko-KR', '한국어 (ko-KR)'),
];

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _themeLabel(ThemeModeX mode, L10n l) => switch (mode) {
      ThemeModeX.system => l.themeSystem,
      ThemeModeX.light => l.themeLight,
      ThemeModeX.dark => l.themeDark,
    };

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final cacheBytes = ref.watch(cacheSizeProvider).valueOrNull ?? 0;
    final savedTotal = ref.watch(savedListProvider).total;
    final follows = ref.watch(followedPeopleProvider).valueOrNull?.length ?? 0;
    final historyCount = ref.watch(searchHistoryProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 26),
              children: [
                SectionTitle(l.appearance),
                _Group(children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(l.themeMode),
                    subtitle: Text(_themeLabel(s.themeMode, l)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => _pickTheme(context, ref, l),
                  ),
                ]),
                SectionTitle(l.content),
                _Group(children: [
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(l.language),
                    subtitle: Text(s.languageCode == 'tr' ? 'Türkçe' : 'English'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () async {
                      final code = await _pickString(
                        context,
                        l.language,
                        const [('tr', 'Türkçe'), ('en', 'English')],
                        s.languageCode,
                      );
                      if (code == null) return;
                      ref.read(settingsProvider.notifier).setLanguage(
                          code, code == 'tr' ? 'tr-TR' : 'en-US');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.subtitles_outlined),
                    title: Text(l.t('İçerik dili', 'Content language')),
                    subtitle: Text(l.t('TMDB başlık ve özet dili',
                        'Language of TMDB titles and overviews')),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () async {
                      final code = await _pickString(
                          context, l.t('İçerik dili', 'Content language'), _contentLanguages, s.contentLanguage);
                      if (code == null) return;
                      ref.read(settingsProvider.notifier).setLanguage(s.languageCode, code);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.public_rounded),
                    title: Text(l.country),
                    subtitle: Text('${_countryName(s.region)} (${s.region})'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () async {
                      final iso = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _RegionSheet(),
                      );
                      if (iso == null) return;
                      ref.read(settingsProvider.notifier).setRegion(iso);
                    },
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.no_adult_content_outlined),
                    title: Text(l.showAdult),
                    subtitle: Text(l.showAdultSub),
                    value: s.showAdult,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => _setAdult(context, ref, l, v),
                  ),
                ]),
                SectionTitle(l.data),
                _Group(children: [
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: Text(l.clearCache),
                    subtitle: Text(l.clearCacheSub),
                    trailing: cacheBytes > 0
                        ? Text(_humanSize(cacheBytes),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary))
                        : null,
                    onTap: () => _clearCache(context, ref, l),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(l.clearHistory),
                    subtitle: Text('$historyCount ${l.searchHistory.toLowerCase()}'),
                    onTap: () async {
                      await ref.read(localStoreProvider).clearSearchHistory();
                      ref.read(searchHistoryTickProvider.notifier).state++;
                      ref.invalidate(searchHistoryProvider);
                      if (!context.mounted) return;
                      _toast(context, l.t('Arama geçmişi temizlendi', 'Search history cleared'));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: Text(l.myList),
                    subtitle: Text(l.t('Cihazında saklanan kayıtlar', 'Saved on this device')),
                    trailing: Text('$savedTotal',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    onTap: () => ref.read(savedListProvider.notifier).reload(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: Text(l.followPeople),
                    trailing: Text('$follows',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    onTap: () => Nav.people(context),
                  ),
                ]),
                if (Ads.enabled) ...[
                  SectionTitle(l.ads),
                  _Group(children: [
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.tune_rounded),
                      title: Text(l.personalizedAds),
                      subtitle: Text(l.adsSub),
                      value: s.personalizedAds,
                      activeColor: AppTheme.primary,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setPersonalizedAds(v),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(l.t('Reklam gizlilik seçenekleri', 'Ad privacy options')),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 19),
                      onTap: Ads.showPrivacyOptions,
                    ),
                  ]),
                ],
                SectionTitle(l.t('Hakkında ve destek', 'About and support')),
                _Group(children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(l.aboutApp),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Nav.about(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l.terms),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Nav.legal(context, LegalKind.terms),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: Text(l.privacy),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Nav.legal(context, LegalKind.privacy),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: Text(l.openSource),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Nav.legal(context, LegalKind.licenses),
                  ),
                  ListTile(
                    leading: const Icon(Icons.movie_creation_outlined),
                    title: Text(l.tmdbPage),
                    subtitle: Text(AppConfig.tmdbShortAttribution),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Nav.legal(context, LegalKind.tmdb),
                  ),
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(l.feedback),
                    subtitle: Text(AppConfig.supportEmail),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 19),
                    onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.star_outline_rounded),
                    title: Text(l.rateApp),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 19),
                    onTap: () => launchUrl(
                      Uri.parse('https://play.google.com/store/apps/details?id=app.cineva.cineva'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 26, 16, 8),
                  child: Column(
                    children: [
                      Text('${AppConfig.appName} v${AppConfig.appVersion}',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.6))),
                      const SizedBox(height: 4),
                      Text(AppConfig.tmdbShortAttribution,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (ref.watch(adsEnabledProvider))
            const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref, L10n l) async {
    final current = ref.read(settingsProvider).themeMode;
    final picked = await showDialog<ThemeModeX>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.themeMode),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in ThemeModeX.values)
                ListTile(
                  title: Text(_themeLabel(m, l)),
                  trailing: m == current
                      ? Icon(Icons.check_rounded, color: AppTheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel))],
      ),
    );
    if (picked == null) return;
    ref.read(settingsProvider.notifier).setThemeMode(picked);
  }

  Future<String?> _pickString(
    BuildContext context,
    String title,
    List<(String, String)> options,
    String current,
  ) =>
      showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in options)
                    ListTile(
                      title: Text(o.$2),
                      trailing: o.$1 == current
                          ? Icon(Icons.check_rounded, color: AppTheme.primary)
                          : null,
                      onTap: () => Navigator.pop(ctx, o.$1),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _setAdult(
      BuildContext context, WidgetRef ref, L10n l, bool value) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (!value) {
      notifier.setShowAdult(false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.showAdult),
        content: Text(l.t(
          'Bu seçenek açıldığında 18+ içerikler listelerde ve aramalarda görünebilir. '
          'Cineva 13 yaş ve üzeri için yayınlanmaktadır.',
          'Turning this on lets 18+ titles appear in lists and search. '
          'Cineva is published for ages 13 and up.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.apply)),
        ],
      ),
    );
    if (ok == true) notifier.setShowAdult(true);
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref, L10n l) async {
    final store = ref.read(localStoreProvider);
    await store.clearCache();
    ref.invalidate(trendingProvider);
    ref.invalidate(homeSectionProvider);
    ref.invalidate(releaseCalendarProvider);
    ref.invalidate(searchResultsProvider);
    ref.invalidate(discoverResultsProvider);
    ref.invalidate(relatedMediaProvider);
    ref.invalidate(popularPeopleProvider);
    ref.invalidate(top250Provider);
    ref.invalidate(mediaDetailProvider);
    ref.invalidate(personDetailProvider);
    ref.invalidate(seasonProvider);
    ref.invalidate(episodeProvider);
    ref.invalidate(collectionProvider);
    ref.invalidate(companyProvider);
    ref.invalidate(reviewsProvider);
    ref.invalidate(imagesProvider);
    ref.invalidate(genresProvider);
    ref.invalidate(movieGenresProvider);
    ref.invalidate(tvGenresProvider);
    ref.invalidate(providerCatalogProvider);
    ref.invalidate(countriesProvider);
    ref.invalidate(cacheSizeProvider);
    if (!context.mounted) return;
    _toast(context, l.t('Önbellek temizlendi', 'Cache cleared'));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(children: children),
    );
  }
}

class _RegionSheet extends ConsumerStatefulWidget {
  const _RegionSheet();

  @override
  ConsumerState<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends ConsumerState<_RegionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final loaded = ref.watch(countriesProvider).valueOrNull;
    final all = loaded ??
        [for (final c in _quickCountries) CountryInfo(c.$1, c.$2, c.$2)];
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? all.take(40).toList()
        : all
            .where((c) =>
                c.iso.toLowerCase().contains(q) ||
                c.localName.toLowerCase().contains(q) ||
                c.englishName.toLowerCase().contains(q))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l.pickRegion,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: loaded != null,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: list.isEmpty
                    ? EmptyView(icon: Icons.search_off_rounded, title: l.noResults)
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 34,
                              child: Text(c.iso,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                            title: Text(c.localName.isEmpty ? c.englishName : c.localName),
                            onTap: () => Navigator.pop(context, c.iso),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _countryName(String iso) {
  for (final c in _quickCountries) {
    if (c.$1 == iso) return c.$2;
  }
  return iso;
}
