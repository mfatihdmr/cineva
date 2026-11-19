import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';
import '../settings/settings_controller.dart';

final _watchCountryOverrideProvider = StateProvider<String?>((ref) => null);

class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final region = ref.watch(settingsProvider).region;
    final country = ref.watch(_watchCountryOverrideProvider) ?? region;
    final countries = ref.watch(countriesProvider).valueOrNull ?? const <CountryInfo>[];
    final catalog = ref.watch(providerCatalogProvider(country));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.whereToWatch)),
      body: Column(
        children: [
          if (countries.isNotEmpty) ...[
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: countries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = countries[i];
                  return ChoiceChip(
                    label: Text(c.localName.isEmpty ? c.iso : c.localName),
                    selected: c.iso == country,
                    onSelected: (_) =>
                        ref.read(_watchCountryOverrideProvider.notifier).state = c.iso,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.public_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(l.country,
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: countries.any((c) => c.iso == country) ? country : null,
                      hint: Text(country),
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final c in countries)
                          DropdownMenuItem(
                            value: c.iso,
                            child: Text('${c.localName.isEmpty ? c.englishName : c.localName} (${c.iso})'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(_watchCountryOverrideProvider.notifier).state = v;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: catalog.when(
              loading: () => const _CatalogShimmer(),
              error: (e, st) => ErrorView(
                error: e,
                onRetry: () {
                  ref.invalidate(providerCatalogProvider(country));
                  ref.invalidate(countriesProvider);
                },
              ),
              data: (cat) => _catalogList(l, cat, country),
            ),
          ),
          if (ref.watch(adsEnabledProvider))
            const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }

  Widget _catalogList(L10n l, WatchProviderCatalog cat, String country) {
    final sections = <(String, List<WatchProviderEntry>)>[
      (l.streaming, cat.flatrate[country] ?? const []),
      (l.rent, cat.rent[country] ?? const []),
      (l.buy, cat.buy[country] ?? const []),
    ];
    if (sections.every((s) => s.$2.isEmpty)) {
      return EmptyView(
        icon: Icons.live_tv_rounded,
        title: l.emptyTitle,
        subtitle: l.t('Bu ülke için platform verisi bulunamadı.',
            'No provider data for this country.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        for (final s in sections)
          if (s.$2.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(s.$1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [for (final p in s.$2) _ProviderTile(entry: p)],
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

class _ProviderTile extends ConsumerWidget {
  const _ProviderTile({required this.entry});

  final WatchProviderEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: RemoteImage(url: repo.image(entry.logoPath, size: 'w92')),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.providerName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _CatalogShimmer extends StatelessWidget {
  const _CatalogShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerBox(width: 150, height: 20),
        SizedBox(height: 14),
        Row(
          children: [
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
          ],
        ),
        SizedBox(height: 26),
        ShimmerBox(width: 150, height: 20),
        SizedBox(height: 14),
        Row(
          children: [
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            ShimmerBox(width: 64, height: 64, radius: BorderRadius.all(Radius.circular(12))),
          ],
        ),
      ],
    );
  }
}
