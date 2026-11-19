import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config/app_config.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../legal/legal_screen.dart';

const _playUrl = 'https://play.google.com/store/apps/details?id=app.cineva.cineva';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutApp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 34),
        children: [
          const SizedBox(height: 10),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon/logo_512.png',
                width: 98,
                height: 98,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(AppConfig.appName,
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
          ),
          const SizedBox(height: 5),
          Center(
            child: Text(
              '${l.versionInfo} ${AppConfig.appVersion}',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.primary, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            child: Text(
              l.t(
                'Cineva; film ve dizileri keşfetmeni, puanlarını ve türlerini karşılaştırmanı, '
                'nerede izlenebileceklerini görmeni ve kendi izleme listeni oluşturmanı sağlayan '
                'sessiz, hızlı bir rehberdir. Reklamlarla ücretsiz kalır, abonelik istemez.',
                'Cineva is a quiet, fast guide to discover movies and shows, compare scores and '
                'genres, see where to watch them and build your own watchlist. Ads keep it free; '
                'no subscription is required.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
          _Card(
            child: Column(
              children: [
                _Feature(
                  icon: Icons.explore_outlined,
                  title: l.tabDiscover,
                  body: l.t('Trendler, vizyondakiler, yakındakiler ve gelişmiş keşif filtreleri.',
                      'Trending, in cinemas, upcoming and advanced discover filters.'),
                ),
                _Feature(
                  icon: Icons.play_circle_outline_rounded,
                  title: l.whereToWatch,
                  body: l.t('Dijital platform, kiralama ve satın alma bilgisi ülkene göre.',
                      'Streaming, rent and buy information for your country.'),
                ),
                _Feature(
                  icon: Icons.bookmarks_outlined,
                  title: l.myList,
                  body: l.t('İstediğim, izliyorum, izledim ve favoriler; kendi puanın ve notların.',
                      'Watchlist, watching, watched and favorites; your own rating and notes.'),
                ),
                _Feature(
                  icon: Icons.cloud_off_rounded,
                  title: l.offline,
                  body: l.t('Gördüğün içerikler cihazda saklanır; bağlantın yokken de okuyabilirsin.',
                      'Content you browsed is stored on the device and readable offline.',
                      ),
                  last: true,
                ),
              ],
            ),
          ),
          SectionTitle(l.t('Nasıl çalışır', 'How it works')),
          _Card(
            child: Text(
              l.t(
                'Cineva kendi sunucusu olmayan bir istemcidir. Gördüğün tüm künye, poster, puan ve '
                'inceleme verileri TMDB (themoviedb.org) API’sinden gelir. Listen, puanların, '
                'notların ve arama geçmişin yalnızca kendi cihazında, SQLite veritabanında saklanır '
                've hiçbir yere gönderilmez.',
                'Cineva is a client with no server of its own. Every credit, poster, score and '
                'review comes from the TMDB (themoviedb.org) API. Your list, ratings, notes and '
                'search history are stored only on your device in SQLite and never sent anywhere.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
          _Card(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('${AppConfig.contentRatingMinAge}+',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.secondary)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l.t(
                      'Hedef kitle ${AppConfig.contentRatingMinAge} yaş ve üzeridir. 18+ içerik '
                      'varsayılan olarak kapalıdır; Ayarlar’dan açabilirsin.',
                      'The audience is ages ${AppConfig.contentRatingMinAge} and up. 18+ content is '
                      'off by default and can be enabled in Settings.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(l.tmdbPage),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConfig.tmdbAttribution,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                const SizedBox(height: 10),
                Text(
                  l.t(
                    'Bu uygulama TMDB tarafından desteklenmektedir; TMDB logoları TMDB’nin '
                    'mülkiyetindedir. API anahtarı geliştirici tarafından sağlanır.',
                    'This product uses the TMDB API. TMDB logos are the property of TMDB. The API '
                    'key is provided by the developer.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
          SectionTitle(l.externalLinks),
          _Card(
            child: Column(
              children: [
                _LinkRow(
                  icon: Icons.movie_filter_outlined,
                  label: 'themoviedb.org',
                  onTap: () => launchUrl(Uri.parse(AppConfig.tmdbSiteUrl),
                      mode: LaunchMode.externalApplication),
                ),
                _LinkRow(
                  icon: Icons.api_outlined,
                  label: l.t('TMDB API dokümanları', 'TMDB API docs'),
                  onTap: () => launchUrl(Uri.parse(AppConfig.tmdbApiDocs),
                      mode: LaunchMode.externalApplication),
                ),
                _LinkRow(
                  icon: Icons.mail_outline_rounded,
                  label: l.t('Destek e-postası', 'Support e-mail'),
                  onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}')),
                ),
                _LinkRow(
                  icon: Icons.description_outlined,
                  label: l.terms,
                  onTap: () => Nav.legal(context, LegalKind.terms),
                ),
                _LinkRow(
                  icon: Icons.lock_outline_rounded,
                  label: l.privacy,
                  onTap: () => Nav.legal(context, LegalKind.privacy),
                ),
                _LinkRow(
                  icon: Icons.code_rounded,
                  label: l.openSource,
                  onTap: () => Nav.legal(context, LegalKind.licenses),
                  last: true,
                ),
              ],
            ),
          ),
          SectionTitle(l.t('Cineva’ya destek', 'Support Cineva')),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(_playUrl),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: Text(l.rateApp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: _playUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text(l.t(
                              'Play Store bağlantısı kopyalandı', 'Play Store link copied'))));
                  },
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(l.share),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '${AppConfig.appName} v${AppConfig.appVersion} • ${AppConfig.tmdbShortAttribution}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l.t('İstanbul’da sevilerek yapıldı.', 'Made with love in Istanbul.'),
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool last;
  const _Feature({
    required this.icon,
    required this.title,
    required this.body,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: last ? 12 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 2),
            leading: Icon(icon, size: 20),
            title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 19),
            onTap: onTap,
          ),
          if (!last) const Divider(height: 1),
        ],
      );
}
