import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class KeywordScreen extends ConsumerStatefulWidget {
  const KeywordScreen({super.key, required this.id, required this.name});

  final int id;
  final String name;

  @override
  ConsumerState<KeywordScreen> createState() => _KeywordScreenState();
}

class _KeywordScreenState extends ConsumerState<KeywordScreen> {
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
      final res = await ref.read(repoProvider).api.keywordMovies(widget.id, page: page);
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
    final ads = ref.watch(adsEnabledProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(child: _body(l, ads)),
          if (ads) const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }

  Widget _body(L10n l, bool ads) {
    if (_loading && _items.isEmpty) return const _GridShimmer();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error, onRetry: () => _load(1));
    }
    if (_items.isEmpty) {
      return EmptyView(icon: Icons.search_off_rounded, title: l.emptyTitle, subtitle: l.noResultsSub);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ..._gridSlivers(_items, ads: ads, loadingMore: _loadingMore),
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
        child: Center(
            child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5))),
      ),
    ));
  }
  return out;
}
