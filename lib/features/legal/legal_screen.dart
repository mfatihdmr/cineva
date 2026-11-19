import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ads.dart';
import '../../app/config/app_config.dart';
import '../../app/l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';
import '../settings/settings_controller.dart';

enum LegalKind { terms, privacy, licenses, tmdb }

final cacheSizeProvider =
    FutureProvider.autoDispose<int>((ref) => ref.watch(localStoreProvider).cacheSizeBytes());

const _packages = <(String, String)>[
  ('flutter_riverpod', 'Durum yönetimi'),
  ('dio', 'HTTP istemcisi'),
  ('sqflite', 'Yerel veritabanı'),
  ('path_provider', 'Dosya yolları'),
  ('cached_network_image', 'Görsel önbelleği'),
  ('google_mobile_ads', 'AdMob reklamları'),
  ('shared_preferences', 'Tercih depolama'),
  ('intl', 'Metin biçimlendirme'),
  ('url_launcher', 'Bağlantı açma'),
  ('shimmer', 'Yükleme animasyonu'),
  ('path', 'Yol yardımcıları'),
  ('cupertino_icons', 'iOS ikonları'),
];

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.kind});

  final LegalKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final title = switch (kind) {
      LegalKind.terms => l.terms,
      LegalKind.privacy => l.privacy,
      LegalKind.licenses => l.openSource,
      LegalKind.tmdb => l.tmdbPage,
    };
    final body = switch (kind) {
      LegalKind.terms => _terms(context, l),
      LegalKind.privacy => _privacy(context, ref, l),
      LegalKind.licenses => _licenses(context, l),
      LegalKind.tmdb => _tmdb(context, l),
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 34),
        children: [
          Text(title,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          ...body,
          const SizedBox(height: 16),
          Center(
            child: Text(
              l.t('Son güncelleme: 28.10.2026', 'Last updated: 28.10.2026'),
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _terms(BuildContext context, L10n l) => [
        _P(l.t(
          'Cineva, TMDB verilerini okuyan bağımsız bir film/dizi keşif uygulamasıdır. Resmî bir '
          'TMDB ürünü değildir ve TMDB tarafından onaylanmamıştır.',
          'Cineva is an independent movie/TV discovery app reading TMDB data. It is not an '
          'official TMDB product and is not endorsed by TMDB.',
        )),
        _LinkTile(
          label: l.t('TMDB kullanım koşulları', 'TMDB terms of use'),
          url: AppConfig.tmdbSiteUrl,
        ),
        _Block(title: l.t('Google Play politikaları', 'Google Play policies'), bodies: [
          _P(l.t(
            'Uygulama Google Play İçerik Politikalarına göre tasarlandı: hedef kitle '
            '${AppConfig.contentRatingMinAge}+ yaştır ve 18+ içerik varsayılan olarak gizlidir; '
            'Ayarlar’dan açılana kadar listelerde görünmez.',
            'The app follows Google Play Content Policies: the audience is '
            '${AppConfig.contentRatingMinAge}+, 18+ content is hidden by default and stays '
            'hidden until enabled in Settings.',
          )),
          _P(l.t(
            'Uygulama reklam gösterir. Reklam talepleri yaş uygunluğu filtreleriyle birlikte '
            'AdMob üzerinden yapılır.',
            'The app shows ads, requested from AdMob with age-appropriateness filters.',
          )),
        ]),
        _Block(title: l.t('İçerik ve telif', 'Content and copyright'), bodies: [
          _P(l.t(
            'Cineva yayın yapmaz, indirme sunmaz ve korsan bağlantı içermez. Yalnızca künye, '
            'poster, fragman bağlantısı ve inceleme gibi bilgilendirici veriler gösterilir.',
            'Cineva does not stream or offer downloads and holds no piracy links. Only '
            'informational data such as credits, posters, trailer links and reviews is shown.',
          )),
          _P(l.t(
            'Fragmanlar YouTube üzerinden resmî kaynaklardan açılır.',
            'Trailers open from official YouTube sources.',
          )),
        ]),
        _Block(title: l.t('Sorumluluk reddi', 'Disclaimer'), bodies: [
          _P(l.t(
            'TMDB’den gelen verilerin doğruluğu garanti edilmez. Eksik ya da yanlış bilgi '
            'bildirmek için destek e-postasını kullanabilirsin.',
            'Accuracy of TMDB data is not guaranteed. Use the support e-mail to report missing '
            'or wrong information.',
          )),
          _P(l.t('Uygulama “olduğu gibi” sunulmaktadır.', 'The app is provided “as is”.')),
        ]),
        _Block(title: l.feedback, bodies: [
          _P(l.t(
            'Şikâyet, içerik kaldırma ve politika ihlali bildirimleri e-posta ile alınır ve '
            'en kısa sürede yanıtlanır.',
            'Complaints, takedown and policy reports are handled over e-mail and answered as '
            'soon as possible.',
          )),
          const _MailTile(),
        ]),
      ];

  List<Widget> _privacy(BuildContext context, WidgetRef ref, L10n l) {
    final s = ref.watch(settingsProvider);
    return [
      _P(l.t(
        'Cineva’nın kendi sunucusu yoktur. Kişisel veri toplamaz, hesap açmanı istemez ve '
        'hiçbir bilgini bir Cineva sunucusuna göndermez.',
        'Cineva has no server of its own. It collects no personal data, needs no account and '
        'never sends your information to a Cineva server.',
      )),
      _Block(title: l.t('Yalnızca cihazında saklananlar', 'Stored only on your device'), bodies: [
        _P(l.t(
          'Listen (istediğim, izliyorum, izledim, favoriler), verdiğin puanlar ve yazdığın notlar.',
          'Your list (watchlist, watching, watched, favorites), your ratings and your notes.',
        )),
        _P(l.t(
          'Son aramaların (en fazla 20 kayıt) ve takip ettiğin kişiler.',
          'Your recent searches (max 20 entries) and the people you follow.',
        )),
        _P(l.t(
          'Tercihlerin: tema, arayüz dili, içerik dili, bölge ve yetişkin içerik anahtarı.',
          'Your preferences: theme, UI language, content language, region and adult switch.',
        )),
        _P(l.t(
          'Çevrimdışı okuyabilmen için tutulan TMDB yanıt önbelleği. Ayarlar > Veri bölümünden '
          'istediğin an silebilirsin.',
          'A TMDB response cache so you can browse offline. Clear it any time in '
          'Settings > Data.',
        )),
      ]),
      _Block(title: l.t('TMDB’ye gönderilen bilgiler', 'What is sent to TMDB'), bodies: [
        _P(l.t(
          'İçerikleri gösterebilmek için themoviedb.org’a anonim API istekleri gönderilir. '
          'Anahtar, uygulamayı geliştirenin sağladığı anahtardır; senin kimliğinle bağlantılı '
          'değildir.',
          'Anonymous API requests go to themoviedb.org to render content. The key belongs to '
          'the app developer and is not linked to your identity.',
        )),
        _P(l.t(
          'İsteklerde yalnızca seçtiğin içerik dili (${s.contentLanguage}) ve bölge (${s.region}) '
          'parametreleri bulunur. Ad, e-posta, telefon numarası veya kişi rehberi gönderilmez.',
          'Requests only carry your content language (${s.contentLanguage}) and region '
          '(${s.region}). No name, e-mail, phone number or contacts are sent.',
        )),
        _P(l.t(
          'TMDB, sunucu loglarını kendi gizlilik politikasına göre tutar.',
          'TMDB keeps server logs under its own privacy policy.',
        )),
      ]),
      _Block(title: l.ads, bodies: [
        _P(l.t(
          'Reklamlar Google AdMob (Google Mobile Ads SDK) ile gösterilir. SDK; çerez benzeri '
          'reklam tanımlayıcısı, yaklaşık konum (ülke kodu) ve cihaz/model bilgisi kullanabilir. '
          'Bu veriler Google’ın gizlilik politikasına tabidir.',
          'Ads are served by Google AdMob (Google Mobile Ads SDK). The SDK may use a cookie-like '
          'ad identifier, approximate location (country code) and device/model data, governed by '
          'Google’s privacy policy.',
        )),
        _P(l.t(
          'Kişiselleştirilmiş reklamları Ayarlar > Reklamlar bölümünden kapatabilirsin.',
          'You can disable personalized ads in Settings > Ads.',
        )),
        if (Ads.sdkReady)
          _OutlineButton(
            label: l.t('Reklam gizlilik seçenekleri', 'Ad privacy options'),
            icon: Icons.tune_rounded,
            onTap: Ads.showPrivacyOptions,
          )
        else
          _P(l.t(
            'Reklam gizlilik seçenekleri, reklam modülü açıldığında Ayarlar içinde de bulunur.',
            'Ad privacy options are also available in Settings once the ad module is open.',
          )),
        _P(l.t(
          'Reklam kimliğini sıfırlamak için Android > Ayarlar > Google > Reklamlar menüsünü '
          'kullanabilirsin.',
          'To reset your ad identity use Android Settings > Google > Ads.',
        )),
      ]),
      _Block(title: l.t('İzinler', 'Permissions'), bodies: [
        _P(l.t(
          'Uygulama yalnızca internet erişimine ihtiyaç duyar. Konum, kamera, mikrofon, rehber, '
          'dosya veya depolama izni istemez.',
          'The app only needs internet access. It never asks for location, camera, microphone, '
          'contacts or storage permissions.',
        )),
      ]),
      _Block(title: l.t('Saklama ve silme', 'Retention and deletion'), bodies: [
        _P(l.t(
          'Veriler cihazda kaldığı için uygulamayı kaldırdığında hepsi silinir. Aşağıdaki düğme '
          'tüm kullanıcı verilerini hemen ve kalıcı olarak temizler.',
          'Because data stays on the device, uninstalling removes it all. The button below wipes '
          'every user record immediately and permanently.',
        )),
        const _DeleteDataButton(),
      ]),
      _Block(title: l.t('Çocukların gizliliği', 'Children’s privacy'), bodies: [
        _P(l.t(
          'Uygulama ${AppConfig.contentRatingMinAge} yaş ve üzeri için tasarlanmıştır; 13 yaş '
          'altı hedeflenmez ve çocuklara yönelik davranışsal reklam yapılmaz.',
          'The app targets ages ${AppConfig.contentRatingMinAge} and up; children under 13 are '
          'not targeted and no behavioural ads are served to them.',
        )),
      ]),
      _Block(title: l.t('Değişiklikler ve iletişim', 'Changes and contact'), bodies: [
        _P(l.t(
          'Bu politika değiştiğinde yeni sürüm notlarında duyurulur. Veri talepleri ve sorular '
          'için: ',
          'Changes are announced in release notes. For data requests and questions: ',
        )),
        const _MailTile(),
      ]),
    ];
  }

  List<Widget> _licenses(BuildContext context, L10n l) => [
        _P(l.t(
          'Cineva açık kaynak kütüphaneler üzerine kuruludur. Aşağıdaki doğrudan bağımlılıkların '
          'tamamı MIT veya BSD-3-Clause türü, ticari kullanıma izin veren lisanslarla dağıtılır. '
          'Tam lisans metinleri Flutter’ın yerleşik lisans sayfasındadır.',
          'Cineva is built on open source libraries. All direct dependencies below ship under MIT '
          'or BSD-3-Clause style licenses allowing commercial use. Full texts are in Flutter’s '
          'license page.',
        )),
        const SizedBox(height: 6),
        for (final p in _packages) _PackageRow(name: p.$1, note: p.$2),
        const SizedBox(height: 14),
        _OutlineButton(
          label: l.t('Tüm lisans metinlerini aç', 'Open all license texts'),
          icon: Icons.article_outlined,
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
          ),
        ),
        const SizedBox(height: 8),
        _P(l.t(
          'Arayüz ikonları Material Icons ve Cupertino Icons kitaplıklarından gelir (Apache-2.0). '
          'TMDB logoları TMDB’nin mülkiyetindedir.',
          'UI icons come from Material Icons and Cupertino Icons (Apache-2.0). TMDB logos remain '
          'the property of TMDB.',
        )),
      ];

  List<Widget> _tmdb(BuildContext context, L10n l) => [
        const _P(AppConfig.tmdbAttribution),
        _P(l.t(
          'Film, dizi ve kişi verileri TMDB’den gelir; veri tabanı topluluk tarafından '
          'beslenir ve ticari olmayan kullanıma açıktır.',
          'Movie, TV and person data comes from TMDB, a community-driven database free for '
          'non-commercial use.',
        )),
        _Block(title: l.t('Nasıl çalışır', 'How it works'), bodies: [
          _P(l.t(
            'API anahtarı uygulama geliştiricisi tarafından sağlanır ve uygulama içinde '
            'gömülüdür; tüm istekler themoviedb.org adresine gider.',
            'The API key is provided by the app developer and bundled in the app; every request '
            'goes to themoviedb.org.',
          )),
          _P(l.t(
            'Poster ve backdrop görselleri TMDB CDN’inden yüklenir ve cihazda önbelleğe alınır.',
            'Posters and backdrops load from the TMDB CDN and are cached on the device.',
          )),
        ]),
        _LinkTile(label: 'themoviedb.org', url: AppConfig.tmdbSiteUrl),
        _LinkTile(label: l.t('TMDB API dokümanları', 'TMDB API docs'), url: AppConfig.tmdbApiDocs),
        _LinkTile(label: l.t('TMDB şartları', 'TMDB conditions'), url: AppConfig.tmdbTermsUrl),
        _P(l.t(
          'Bu ürün TMDb API kullanır ancak TMDb tarafından onaylanmamış veya desteklenmemiştir. '
          'Telif sahipleri içerik kaldırma taleplerini TMDB üzerinden yürütür.',
          'This product uses the TMDb API but is not endorsed or certified by TMDb. Rights '
          'holders handle removal requests through TMDB.',
        )),
      ];
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(height: 1.55, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      );
}

class _Block extends StatelessWidget {
  final String title;
  final List<Widget> bodies;
  const _Block({required this.title, required this.bodies});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionTitle(title), ...bodies],
      );
}

class _PackageRow extends StatelessWidget {
  final String name;
  final String note;
  const _PackageRow({required this.name, required this.note});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 6, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' — $note'),
                  ],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
}

class _LinkTile extends StatelessWidget {
  final String label;
  final String url;
  const _LinkTile({required this.label, required this.url});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: const Icon(Icons.link_rounded, size: 20),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(url, style: const TextStyle(fontSize: 11.5)),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      );
}

class _MailTile extends StatelessWidget {
  const _MailTile();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: const Icon(Icons.mail_outline_rounded, size: 20),
          title: const Text(AppConfig.supportEmail,
              style: TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}')),
        ),
      );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
        ),
      );
}

class _DeleteDataButton extends ConsumerWidget {
  const _DeleteDataButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        onPressed: () => _wipe(context, ref, l),
        icon: const Icon(Icons.delete_forever_outlined, size: 18),
        label: Text(l.t('Verilerini sil', 'Delete my data')),
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref, L10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('Tüm veriler silinsin mi?', 'Delete all data?')),
        content: Text(l.t(
          'Listen, puanların, notların, takip ettiğin kişiler, arama geçmişin ve TMDB önbelleği '
          'cihazından kalıcı olarak silinir. Bu işlem geri alınamaz.',
          'Your list, ratings, notes, followed people, search history and TMDB cache are removed '
          'permanently. This cannot be undone.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.remove)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final store = ref.read(localStoreProvider);
    for (final item in await store.allSaved()) {
      await store.setNote(item.mediaId, item.mediaType.apiPath, '');
      await store.removeSaved(item.mediaId, item.mediaType.apiPath);
    }
    for (final person in await store.followedPeople()) {
      await store.toggleFollow(person.id, person.name, person.profilePath);
    }
    await store.clearSearchHistory();
    await store.clearCache();

    ref.read(searchHistoryTickProvider.notifier).state++;
    ref.read(followTickProvider.notifier).state++;
    ref.invalidate(savedListProvider);
    ref.invalidate(searchHistoryProvider);
    ref.invalidate(followedPeopleProvider);
    ref.invalidate(cacheSizeProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(l.t('Tüm veriler silindi', 'All data deleted'))));
  }
}
