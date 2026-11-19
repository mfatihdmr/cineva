import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../company/company_screen.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.lists)),
      body: const _ListsBody(),
    );
  }
}

class _Card {
  const _Card({
    required this.id,
    required this.name,
    required this.description,
    this.itemCount = 0,
    this.countLabel,
    required this.username,
    this.imagePath,
  });

  final int id;
  final String name;
  final String description;
  final int itemCount;
  final String? countLabel;
  final String username;
  final String? imagePath;
}

class _ListsBody extends ConsumerStatefulWidget {
  const _ListsBody();

  @override
  ConsumerState<_ListsBody> createState() => _ListsBodyState();
}

class _ListsBodyState extends ConsumerState<_ListsBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  final List<_Card> _cards = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  bool get _searching => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadPopular(1));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPopular(int page) async {
    if (page == 1) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await ref.read(repoProvider).api.popularLists(page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _cards.clear();
        _cards.addAll(res.map((l) => _Card(
              id: l.id,
              name: l.name,
              description: l.description,
              itemCount: l.itemCount,
              username: l.username,
              imagePath: l.posterPath,
            )));
        _page = page;
        _hasMore = res.isNotEmpty;
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

  Future<void> _search(String query, int page) async {
    if (page == 1) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await ref.read(repoProvider).api.searchLists(query, page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _cards.clear();
        _cards.addAll(res.results.map((s) => _Card(
              id: s.id,
              name: s.displayTitle,
              description: s.originalTitle,
              countLabel: s.overview,
              username: '',
              imagePath: s.posterPath,
            )));
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

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = value.trim();
      if (q.isEmpty) {
        _loadPopular(1);
      } else {
        _search(q, 1);
      }
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 400 &&
        _hasMore &&
        !_loading &&
        !_loadingMore &&
        _error == null) {
      if (_searching) {
        _search(_controller.text.trim(), _page + 1);
      } else {
        _loadPopular(_page + 1);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final ads = ref.watch(adsEnabledProvider);
    if (_loading && _cards.isEmpty) {
      return const Column(
        children: [
          _SearchBoxStatic(),
          Expanded(child: _ListsShimmer()),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: l.searchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _loadPopular(1);
                      },
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _error != null && _cards.isEmpty
              ? ErrorView(error: _error, onRetry: () => _searching ? _search(_controller.text.trim(), 1) : _loadPopular(1))
              : _cards.isEmpty
                  ? EmptyView(
                      icon: Icons.list_alt_rounded,
                      title: _searching ? l.noResults : l.emptyTitle,
                      subtitle: _searching ? l.noResultsSub : l.emptySub,
                    )
                  : _list(l, ads),
        ),
      ],
    );
  }

  Widget _list(L10n l, bool ads) {
    final n = _cards.length;
    final slotCount = ads ? n + n ~/ 10 : n;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        itemCount: slotCount + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (_loadingMore && i == slotCount) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                  child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5))),
            );
          }
          if (ads && i % 11 == 10) return const InlineAdBanner();
          final card = _cards[ads ? i - i ~/ 11 : i];
          return _ListCardTile(card: card, l: l);
        },
      ),
    );
  }
}

class _ListCardTile extends ConsumerWidget {
  const _ListCardTile({required this.card, required this.l});

  final _Card card;
  final L10n l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Nav.push(context, CollectionEntry(id: card.id, asList: true)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 84,
                  child: RemoteImage(url: repo.image(card.imagePath, size: 'w185')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (card.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(card.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.video_collection_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(
                          card.countLabel ?? '${card.itemCount} ${l.t('içerik', 'items')}',
                          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                        ),
                        if (card.username.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.person_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(card.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5, color: scheme.onSurfaceVariant)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBoxStatic extends StatelessWidget {
  const _SearchBoxStatic();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: ShimmerBox(height: 46, radius: BorderRadius.all(Radius.circular(14))),
      );
}

class _ListsShimmer extends StatelessWidget {
  const _ListsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const Row(
        children: [
          ShimmerBox(width: 56, height: 84, radius: BorderRadius.all(Radius.circular(10))),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14),
                SizedBox(height: 8),
                ShimmerBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
