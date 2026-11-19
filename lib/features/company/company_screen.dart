import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/utils/format.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final company = ref.watch(companyProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(company.valueOrNull?.name ?? l.companies)),
      body: Column(
        children: [
          Expanded(
            child: company.when(
              loading: () => const _GridShimmer(),
              error: (e, st) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(companyProvider(widget.id)),
              ),
              data: (c) => _CompanyFilms(company: c),
            ),
          ),
          if (ref.watch(adsEnabledProvider))
            const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }
}

class _CompanyFilms extends ConsumerStatefulWidget {
  const _CompanyFilms({required this.company});

  final Company company;

  @override
  ConsumerState<_CompanyFilms> createState() => _CompanyFilmsState();
}

class _CompanyFilmsState extends ConsumerState<_CompanyFilms> {
  final List<MediaSummary> _items = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(1));
  }

  Future<void> _load(int page) async {
    if (page == 1) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await ref.read(repoProvider).api.companyMovies(widget.company.id, page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _items.clear();
        _items.addAll(res.results);
        _page = page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 600 &&
        _hasMore &&
        !_loading &&
        !_loadingMore &&
        _error == null) {
      _load(_page + 1);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    if (_loading && _items.isEmpty) return const _GridShimmer();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error, onRetry: () => _load(1));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(l)),
          SliverToBoxAdapter(child: SectionTitle(l.movies)),
          ..._gridSlivers(_items, ads: false, loadingMore: _loadingMore),
        ],
      ),
    );
  }

  Widget _header(L10n l) {
    final c = widget.company;
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: c.logoPath == null || c.logoPath!.isEmpty
                ? const Icon(Icons.business_rounded, size: 56, color: Colors.black38)
                : RemoteImage(
                    url: repo.image(c.logoPath, size: 'w300'),
                    fit: BoxFit.contain,
                    height: 64,
                    placeholder: const SizedBox(height: 64),
                  ),
          ),
          const SizedBox(height: 14),
          Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c.description,
                style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant)),
          ],
          if (c.headquarters.isNotEmpty || c.originCountry.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [c.headquarters, c.originCountry].where((s) => s.isNotEmpty).join(', '),
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (c.homepage.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () =>
                      launchUrl(Uri.parse(c.homepage), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(l.externalLinks),
                ),
              if (c.parentCompanyId != null)
                OutlinedButton.icon(
                  onPressed: () => Nav.company(context, c.parentCompanyId!),
                  icon: const Icon(Icons.account_tree_outlined, size: 16),
                  label: Text(l.t('Üst şirket', 'Parent company')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridShimmer extends StatelessWidget {
  const _GridShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const Row(
        children: [
          Expanded(child: ShimmerBox(height: 210)),
          SizedBox(width: 12),
          Expanded(child: ShimmerBox(height: 210)),
          SizedBox(width: 12),
          Expanded(child: ShimmerBox(height: 210)),
        ],
      ),
    );
  }
}

class CollectionEntry extends ConsumerStatefulWidget {
  const CollectionEntry({super.key, required this.id, this.asList = false});

  final int id;
  final bool asList;

  @override
  ConsumerState<CollectionEntry> createState() => _CollectionEntryState();
}

class _CollectionEntryState extends ConsumerState<CollectionEntry> {
  (MediaType, int, String) get _key => (MediaType.movie, widget.id, 'list');

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return widget.asList ? _listBody(l) : _collectionBody(l);
  }

  Widget _collectionBody(L10n l) {
    final collection = ref.watch(collectionProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(collection.valueOrNull?.title ?? l.collections)),
      body: collection.when(
        loading: () => const _GridShimmer(),
        error: (e, st) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(collectionProvider(widget.id)),
        ),
        data: (d) => _CollectionBody(detail: d, l: l),
      ),
    );
  }

  Widget _listBody(L10n l) {
    final state = ref.watch(relatedMediaProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.lists),
        actions: [
          IconButton(
            tooltip: l.lists,
            icon: const Icon(Icons.format_list_bulleted_rounded),
            onPressed: () => Nav.lists(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.when(
              loading: () => const _GridShimmer(),
              error: (e, st) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(relatedMediaProvider(_key)),
              ),
              data: (ps) => ps.items.isEmpty
                  ? EmptyView(
                      icon: Icons.playlist_remove_rounded,
                      title: l.emptyTitle,
                      subtitle: l.t(
                        'Bu listenin içeriği şu an görüntülenemiyor; listeyi TMDB üzerinde '
                        'yönetebilirsin.',
                        "This list's content can't be viewed right now; you can manage it "
                        'on TMDB.',
                      ),
                      action: FilledButton(
                        onPressed: () => Nav.lists(context),
                        child: Text(l.lists),
                      ),
                    )
                  : _listItems(ps, l),
            ),
          ),
          if (ref.watch(adsEnabledProvider))
            const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }

  Widget _listItems(MediaPageState ps, L10n l) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 600 && ps.hasMore && !ps.loadingMore) {
          ref.read(relatedMediaProvider(_key).notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text(
                l.t('TMDB kullanıcı listesi', 'TMDB user list'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ..._gridSlivers(ps.items, ads: ref.watch(adsEnabledProvider), loadingMore: ps.loadingMore),
        ],
      ),
    );
  }
}

class _CollectionBody extends ConsumerWidget {
  const _CollectionBody({required this.detail, required this.l});

  final MediaDetail detail;
  final L10n l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    final parts = detail.similar;
    final headerUrl = repo.backdrop(detail.backdropPath ?? detail.posterPath, large: true);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Stack(
          children: [
            SizedBox(
              height: 210,
              width: double.infinity,
              child: RemoteImage(url: headerUrl, fit: BoxFit.cover, height: 210),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Text(
                detail.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                l.t('${parts.length} film', '${parts.length} films'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.primary),
              ),
              if (detail.budget > 0)
                Text(
                  '${l.budget}: ${formatMoney(detail.budget)}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              if (detail.revenue > 0)
                Text(
                  '${l.revenue}: ${formatMoney(detail.revenue)}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (detail.overview.isNotEmpty) ...[
          SectionTitle(l.overview),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(detail.overview,
                style: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant)),
          ),
        ],
        SectionTitle(l.t('Serinin filmleri', 'Collection films')),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cols = (width / 136).floor().clamp(2, 5);
              final cellW = (width - (cols - 1) * 12.0) / cols;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: cellW / (cellW * 1.5 + 58),
                ),
                itemCount: parts.length,
                itemBuilder: (_, i) => PosterCard(item: parts[i], width: cellW),
              );
            },
          ),
        ),
      ],
    );
  }
}

List<Widget> _gridSlivers(List<MediaSummary> items, {required bool ads, required bool loadingMore}) {
  final out = <Widget>[];
  final n = items.length;
  for (var start = 0; start < n; start += 10) {
    final end = start + 10 > n ? n : start + 10;
    out.add(SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final cols = (width / 136).floor().clamp(2, 5);
          final cellW = (width - (cols - 1) * 12.0) / cols;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: cellW / (cellW * 1.5 + 58),
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => PosterCard(item: items[start + i], width: cellW),
              childCount: end - start,
            ),
          );
        },
      ),
    ));
    if (ads && end < n) out.add(const SliverToBoxAdapter(child: InlineAdBanner()));
  }
  if (loadingMore) {
    out.add(const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))),
      ),
    ));
  }
  return out;
}
