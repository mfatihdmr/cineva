import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../settings/settings_controller.dart';

const _regions = <(String, String)>[
  ('TR', 'Türkiye'),
  ('US', 'ABD'),
  ('GB', 'B. Krallık'),
  ('DE', 'Almanya'),
  ('FR', 'Fransa'),
  ('ES', 'İspanya'),
  ('IT', 'İtalya'),
  ('CA', 'Kanada'),
  ('AU', 'Avustralya'),
  ('BR', 'Brezilya'),
  ('JP', 'Japonya'),
  ('KR', 'Güney Kore'),
];

const _uiLanguages = <(String, String, String)>[
  ('tr', 'Türkçe', 'tr-TR'),
  ('en', 'English', 'en-US'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _adult = false;

  static const _pages = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    final next = page.clamp(0, _pages - 1);
    if (next == _page) return;
    setState(() => _page = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.setShowAdult(_adult);
    notifier.finishOnboarding();
    if (mounted) Nav.home(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final s = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final last = _page == _pages - 1;

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _page == 0
                          ? const SizedBox(height: 44)
                          : IconButton(
                              onPressed: () => _go(_page - 1),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: l.t('Geri', 'Back'),
                            ),
                    ),
                    _Dots(page: _page, pages: _pages, color: theme.colorScheme.onSurface),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: last
                            ? const SizedBox(height: 44)
                            : TextButton(
                                onPressed: _finish,
                                child: Text(l.t('Atla', 'Skip')),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _introPage(l, theme),
                    _languagePage(l, s, theme),
                    _regionPage(l, s, theme),
                    _noticePage(l, theme),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _finish,
                    child: Text(last
                        ? l.t('Evet, başla', 'Yes, get started')
                        : l.start),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introPage(L10n l, ThemeData theme) {
    return _Page(
      header: _Header(
        child: Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withValues(alpha: 0.32),
                AppTheme.secondary.withValues(alpha: 0.22),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset('assets/icon/logo_512.png',
                width: 132, height: 132, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
      title: l.onboardingTitle,
      subtitle: l.onboardingSub,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final tag in [
            l.trendingToday,
            l.nowPlaying,
            l.upcoming,
            l.whereToWatch,
            l.myList,
            l.top250,
          ])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tag,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
        ],
      ),
    );
  }

  Widget _languagePage(L10n l, SettingsState s, ThemeData theme) {
    return _Page(
      header: _Header(icon: Icons.translate_rounded),
      title: l.pickLanguage,
      subtitle: l.t('Arayüz ve içerik dilini birlikte ayarlıyoruz.',
          'This sets both the interface and the content language.'),
      child: Column(
        children: [
          for (final option in _uiLanguages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChoiceTile(
                title: option.$2,
                subtitle: option.$1 == 'tr'
                    ? l.t('İçerik dili: tr-TR', 'Content language: tr-TR')
                    : l.t('İçerik dili: en-US', 'Content language: en-US'),
                selected: s.languageCode == option.$1,
                onTap: () =>
                    ref.read(settingsProvider.notifier).setLanguage(option.$1, option.$3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _regionPage(L10n l, SettingsState s, ThemeData theme) {
    return _Page(
      header: _Header(icon: Icons.public_rounded),
      title: l.pickRegion,
      subtitle: l.t(
        'Bölge; yayın takvimi, yaş sınırı ve “nerede izlenir” sonuçlarını etkiler.',
        'The region drives the release calendar, age ratings and where-to-watch results.',
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final r in _regions)
            ChoiceChip(
              selected: s.region == r.$1,
              onSelected: (_) => ref.read(settingsProvider.notifier).setRegion(r.$1),
              label: Text('${r.$2} • ${r.$1}'),
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: s.region == r.$1 ? AppTheme.primary : theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }

  Widget _noticePage(L10n l, ThemeData theme) {
    return _Page(
      header: _Header(icon: Icons.verified_user_outlined),
      title: l.permissionNote,
      subtitle: l.t(
        'Hesap gerekmez, veri satılmaz. Dilediğin an Ayarlar’dan her şeyi silebilirsin.',
        'No account needed, no data sold. You can erase everything from Settings any time.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.t('Aşağıdaki anahtar dışında hiçbir kişisel veri ayarı değiştirilmez.',
                        'No personal data setting is changed other than the switch below.'),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _adult
                      ? AppTheme.secondary.withValues(alpha: 0.6)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: SwitchListTile.adaptive(
              secondary: const Icon(Icons.no_adult_content_outlined),
              title: Text(l.showAdult),
              subtitle: Text(
                l.t(
                  'Kapalı kalması önerilir. Açarsan 18+ filmler ve diziler listelerde görünür; '
                  'uygulama 13 yaş ve üzeri için yayınlanmıştır.',
                  'Keep it off for best results. Turning it on reveals 18+ titles in lists; the '
                  'app is published for ages 13 and up.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              value: _adult,
              activeColor: AppTheme.secondary,
              onChanged: (v) => setState(() => _adult = v),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.t(
              'Bu seçimi istediğin an Ayarlar > İçerik bölümünden değiştirebilirsin.',
              'You can change this any time in Settings > Content.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final Widget header;
  final String title;
  final String subtitle;
  final Widget? child;
  const _Page({required this.header, required this.title, required this.subtitle, this.child});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        children: [
          Center(child: header),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
          ),
          if (child != null) ...[const SizedBox(height: 22), child!],
        ],
      );
}

class _Header extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  const _Header({this.icon, this.child});

  @override
  Widget build(BuildContext context) {
    if (child != null) return child!;
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.3),
            AppTheme.secondary.withValues(alpha: 0.22),
          ],
        ),
      ),
      child: Icon(icon, size: 46, color: AppTheme.primary),
    );
  }
}

class _Dots extends StatelessWidget {
  final int page;
  final int pages;
  final Color color;
  const _Dots({required this.page, required this.pages, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < pages; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == page ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == page ? AppTheme.primary : color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      );
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.7)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: selected ? AppTheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
