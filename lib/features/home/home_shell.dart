import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/api/tmdb_api.dart';
import '../mylist/my_list_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import 'home_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _registered = false;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(adsEnabledProvider)) {
        InterstitialAdManager.instance.maybeShow();
      }
      if (!_registered) {
        _registered = true;
        ref.read(settingsProvider.notifier).registerAppOpen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final bootstrap = ref.watch(bootstrapProvider);

    if (bootstrap.hasError) {
      return Scaffold(
        body: Center(
          child: ErrorView(
            error: bootstrap.error,
            onRetry: () => ref.invalidate(bootstrapProvider),
          ),
        ),
      );
    }

    final apiReady = ref.watch(apiReadyProvider);
    if (!bootstrap.isLoading && (!apiReady || !TmdbApi.instance.isReady)) {
      return _missingKeyView(l);
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < 4; i++)
            _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _visited.add(i);
          _index = i;
        }),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l.tabDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: l.tabSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmarks_outlined),
            selectedIcon: const Icon(Icons.bookmarks),
            label: l.tabList,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.tabSettings,
          ),
        ],
      ),
    );
  }

  Widget _tab(int i) => switch (i) {
        0 => const HomePage(),
        1 => const SearchScreen(),
        2 => const MyListScreen(),
        _ => const SettingsScreen(),
      };

  Widget _missingKeyView(L10n l) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vpn_key_off_rounded, size: 44, color: theme.colorScheme.error),
              const SizedBox(height: 14),
              Text(l.t('API anahtarı yapılandırılmamış', 'API key not configured'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                l.t(
                  'Film ve dizileri görebilmek için Ayarlar\'dan geçerli bir TMDB API anahtarı girmen gerekiyor.',
                  'Enter a valid TMDB API key in Settings to browse movies and shows.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Nav.settings(context),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(l.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
