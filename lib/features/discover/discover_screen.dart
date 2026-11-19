import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart' show L10n;
import '../../app/providers.dart';
import '../../app/state/discover_filters.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';
import 'widgets.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  final MediaType? initialType;
  const DiscoverScreen({super.key, this.initialType});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    final t = widget.initialType;
    if (t == null || t == MediaType.person) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(discoverFiltersProvider).mediaType != t) {
        ref.read(discoverFiltersProvider.notifier).toggleType(t);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final filters = ref.watch(discoverFiltersProvider);
    final results = ref.watch(discoverResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabDiscover),
        actions: [
          _filterButton(l, filters.activeCount),
        ],
      ),
      body: results.when(
        loading: () => const _ShimmerGrid(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.read(discoverResultsProvider.notifier).reload(),
        ),
        data: (s) => _body(context, l, filters, s),
      ),
    );
  }

  Widget _filterButton(L10n l, int count) {
    final btn = IconButton(
      onPressed: () => FilterSheet.show(context),
      icon: const Icon(Icons.tune_rounded),
      tooltip: l.filters,
    );
    return count > 0
        ? Badge(label: Text('$count'), child: btn)
        : btn;
  }

  Widget _body(BuildContext context, L10n l, DiscoverFilters filters,
      MediaPageState s) {
    final items = s.items;
    final adsOn = ref.watch(adsEnabledProvider);
    final width = MediaQuery.of(context).size.width;
    const gap = 10.0;
    const hpad = 12.0;
    final usable = width - hpad * 2;
    final columns = (usable / 120).round().clamp(2, 4).toInt();
    final colW = (usable - gap * (columns - 1)) / columns;

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${items.length} ${l.results.toLowerCase()}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<MediaType>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(
                      value: MediaType.movie,
                      label: Text(MediaType.movie.label),
                      icon: const Icon(Icons.local_movies_outlined, size: 18)),
                  ButtonSegment(
                      value: MediaType.tv,
                      label: Text(MediaType.tv.label),
                      icon: const Icon(Icons.tv_outlined, size: 18)),
                ],
                selected: {filters.mediaType},
                showSelectedIcon: false,
                onSelectionChanged: (sel) =>
                    ref.read(discoverFiltersProvider.notifier).toggleType(sel.first),
              ),
            ),
          ],
        ),
      ),
    );

    if (items.isEmpty) {
      return CustomScrollView(
        slivers: [
          header,
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(
              icon: Icons.movie_filter_outlined,
              title: l.noResults,
              subtitle: l.noResultsSub,
            ),
          ),
        ],
      );
    }

    final rows = <Widget>[];
    final current = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      current.add(PosterCard(item: items[i], width: colW));
      if (current.length == columns) {
        rows.add(_row(current, columns, colW, gap));
        current.clear();
      }
      if (adsOn && (i + 1) % 10 == 0) {
        if (current.isNotEmpty) {
          rows.add(_row(current, columns, colW, gap));
          current.clear();
        }
        rows.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: InlineAdBanner(),
        ));
      }
    }
    if (current.isNotEmpty) rows.add(_row(current, columns, colW, gap));
    if (s.loadingMore) {
      rows.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (s.hasMore &&
            n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
          ref.read(discoverResultsProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          header,
          for (final r in rows) SliverToBoxAdapter(child: r),
        ],
      ),
    );
  }

  Widget _row(List<Widget> cards, int columns, double colW, double gap) {
    final children = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      children.add(cards[i]);
      if (i < cards.length - 1) children.add(SizedBox(width: gap));
    }
    for (var i = cards.length; i < columns; i++) {
      children.add(SizedBox(width: gap));
      children.add(SizedBox(width: colW));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const gap = 10.0;
    const hpad = 12.0;
    final usable = width - hpad * 2;
    final columns = (usable / 120).round().clamp(2, 4).toInt();
    final colW = (usable - gap * (columns - 1)) / columns;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gap,
        mainAxisSpacing: 16,
        childAspectRatio: colW / (colW * 1.72),
      ),
      itemCount: columns * 4,
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: const ShimmerBox()),
          const SizedBox(height: 8),
          SizedBox(width: colW * 0.7, child: const ShimmerBox(height: 12)),
        ],
      ),
    );
  }
}
