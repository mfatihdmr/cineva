import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _committed = '';
  String? _type;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    final seed = widget.initialQuery.trim();
    if (seed.length >= 2) _committed = seed;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    _debounce = Timer(const Duration(milliseconds: 400), () => _commit(q));
  }

  Future<void> _commit(String q) async {
    if (q.length < 2) {
      if (mounted) setState(() => _committed = '');
      return;
    }
    await ref.read(localStoreProvider).pushSearch(q);
    ref.read(searchHistoryTickProvider.notifier).state++;
    if (mounted) setState(() => _committed = q);
  }

  void _setType(String? type) {
    setState(() => _type = type);
    final q = _controller.text.trim();
    if (q.length >= 2) _commit(q);
  }

  void _runFromHistory(String term) {
    _controller.text = term;
    _focusNode.unfocus();
    _commit(term.trim());
  }

  Future<void> _clearHistory() async {
    await ref.read(localStoreProvider).clearSearchHistory();
    ref.read(searchHistoryTickProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final hasQuery = _committed.length >= 2;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _debounce?.cancel();
            _commit(v.trim());
          },
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: hasQuery ? _activeView(l) : _startView(l),
    );
  }

  Widget _activeView(L10n l) {
    final key = (_committed, _type);
    final provider = searchResultsProvider(key);
    final async = ref.watch(provider);
    return Column(
      children: [
        _TypeBar(type: _type, onChanged: _setType),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              final page = ref.read(provider).valueOrNull;
              if (page != null &&
                  page.hasMore &&
                  !page.loadingMore &&
                  n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
                ref.read(provider.notifier).loadMore();
              }
              return false;
            },
            child: async.when(
              loading: () => const _ResultsShimmer(),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.read(provider.notifier).reload(),
              ),
              data: (page) => _resultsList(l, page),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultsList(L10n l, MediaPageState page) {
    final items = page.items;
    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: l.noResults,
        subtitle: l.noResultsSub,
      );
    }
    final ads = ref.watch(adsEnabledProvider);
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(_ResultRow(item: items[i]));
      if (ads && (i + 1) % 10 == 0 && i + 1 < items.length) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: InlineAdBanner(),
        ));
      }
    }
    if (page.loadingMore) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      ));
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: children,
    );
  }

  Widget _startView(L10n l) {
    final history = ref.watch(searchHistoryProvider).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: SectionTitle(l.searchHistory)),
              TextButton(
                onPressed: _clearHistory,
                child: Text(l.clearHistory, style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in history)
                ActionChip(
                  label: Text(term),
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  onPressed: () => _runFromHistory(term),
                ),
            ],
          ),
        ],
        SectionTitle(l.t('Kategoriler', 'Categories')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CategoryChip(
              label: l.movies,
              icon: Icons.movie_rounded,
              type: 'movie',
              onPick: _setType,
            ),
            _CategoryChip(
              label: l.series,
              icon: Icons.tv_rounded,
              type: 'tv',
              onPick: _setType,
            ),
            _CategoryChip(
              label: l.people,
              icon: Icons.person_rounded,
              type: 'person',
              onPick: _setType,
            ),
            _CategoryChip(
              label: l.lists,
              icon: Icons.list_rounded,
              type: 'list',
              onPick: _setType,
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeBar extends ConsumerWidget {
  final String? type;
  final ValueChanged<String?> onChanged;
  const _TypeBar({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final options = <(String?, String)>[
      (null, l.t('Tümü', 'All')),
      ('movie', l.movies),
      ('tv', l.series),
      ('person', l.people),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.$2),
                selected: type == o.$1,
                onSelected: (_) => onChanged(o.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String type;
  final ValueChanged<String?> onPick;
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.type,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => onPick(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: scheme.primary.withValues(alpha: 0.12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  final MediaSummary item;
  const _ResultRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final l = ref.watch(l10nProvider);
    final isPerson = item.mediaType == MediaType.person;
    final url = isPerson
        ? repo.profile(item.posterPath)
        : repo.poster(item.posterPath);
    final subtitle = item.year.isNotEmpty
        ? item.year
        : (item.characters.isNotEmpty ? item.characters.join(', ') : '');

    return InkWell(
      onTap: () => isPerson
          ? Nav.person(context, item.id)
          : context.openMedia(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: isPerson ? 56 : 84,
                child: RemoteImage(url: url, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (isPerson)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.people,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isPerson && item.voteAverage != null && item.voteAverage! > 0) ...[
              const SizedBox(width: 8),
              ScoreBadge(value: item.voteAverage!, size: 30),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsShimmer extends StatelessWidget {
  const _ResultsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        for (var i = 0; i < 8; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const ShimmerBox(width: 56, height: 84),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 14),
                      SizedBox(height: 8),
                      ShimmerBox(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
