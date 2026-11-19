import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/local/local_store.dart';
import '../../data/models/tmdb_models.dart';

const _statuses = ['watchlist', 'watching', 'watched', 'favorites', 'rated'];

String _statusLabel(String status, L10n l) => switch (status) {
      'watchlist' => l.watchlist,
      'watching' => l.watching,
      'watched' => l.watched,
      'favorites' => l.favorites,
      'rated' => l.myRatings,
      _ => l.addToList,
    };

class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});

  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> {
  String? _filter;
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final state = ref.watch(savedListProvider);
    final ads = ref.watch(adsEnabledProvider);
    final items = _visibleItems(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.myList),
        actions: [
          ViewToggleButton(
            grid: _grid,
            onTap: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      body: !state.ready
          ? const _ListShimmer()
          : Column(
              children: [
                _StatsRow(state: state, l: l),
                _FilterBar(
                  selected: _filter,
                  state: state,
                  l: l,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                Expanded(
                  child: items.isEmpty
                      ? EmptyView(
                          icon: Icons.bookmark_add_outlined,
                          title: l.emptyTitle,
                          subtitle: l.emptyListBody,
                          action: FilledButton.icon(
                            onPressed: () => Nav.discover(context, MediaType.movie),
                            icon: const Icon(Icons.explore_rounded, size: 18),
                            label: Text(l.tabDiscover),
                          ),
                        )
                      : _content(items, state),
                ),
                if (ads)
                  const SafeArea(top: false, child: AnchoredBanner()),
              ],
            ),
    );
  }

  List<SavedItem> _visibleItems(SavedListState state) {
    if (_filter != null) return state.of(_filter!);
    final all = <SavedItem>[];
    for (final s in _statuses) {
      all.addAll(state.of(s));
    }
    all.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return all;
  }

  Widget _content(List<SavedItem> items, SavedListState state) {
    if (_grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _GridTile(
          item: items[i],
          l: ref.read(l10nProvider),
          onLongPress: () => _showActions(items[i]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: items.length,
      itemBuilder: (_, i) => _ListItem(
        item: items[i],
        l: ref.read(l10nProvider),
        onLongPress: () => _showActions(items[i]),
      ),
    );
  }

  Future<void> _showActions(SavedItem item) async {
    final l = ref.read(l10nProvider);
    final summary = item.toSummary();
    final notifier = ref.read(savedListProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(l.status,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(sheetCtx).colorScheme.primary)),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _statuses)
                      ChoiceChip(
                        label: Text(_statusLabel(s, l)),
                        selected: item.status == s,
                        onSelected: (_) async {
                          await notifier.setStatus(item.mediaId, item.mediaType, s, summary);
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        },
                      ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded),
                  title: Text(l.rateIt),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _rateDialog(item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(l.t('Not ekle/düzenle', 'Add/edit note')),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _noteDialog(item);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: Theme.of(sheetCtx).colorScheme.error),
                  title: Text(l.remove,
                      style: TextStyle(color: Theme.of(sheetCtx).colorScheme.error)),
                  onTap: () async {
                    await notifier.remove(item.mediaId, item.mediaType);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rateDialog(SavedItem item) async {
    final l = ref.read(l10nProvider);
    final summary = item.toSummary();
    var value = item.rating ?? 7.0;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return AlertDialog(
            title: Text(l.yourRating),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded,
                        color: Theme.of(ctx).colorScheme.primary, size: 30),
                    const SizedBox(width: 8),
                    Text(value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
                Slider(
                  value: value,
                  min: 0.5,
                  max: 10,
                  divisions: 19,
                  label: value.toStringAsFixed(1),
                  onChanged: (v) => setSheet(() => value = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  await ref.read(savedListProvider.notifier)
                      .rate(item.mediaId, item.mediaType, summary, value);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                },
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _noteDialog(SavedItem item) async {
    final l = ref.read(l10nProvider);
    final existing =
        ref.read(noteProvider((item.mediaType, item.mediaId))).valueOrNull ?? item.note;
    final controller = TextEditingController(text: existing);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.t('Not', 'Note')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.t('Bu yapım hakkında notun…', 'Your note about this title…'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(savedListProvider.notifier)
                  .setNote(item.mediaId, item.mediaType, controller.text);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _StatsRow extends StatelessWidget {
  final SavedListState state;
  final L10n l;
  const _StatsRow({required this.state, required this.l});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratings = <double>[];
    for (final s in _statuses) {
      for (final item in state.of(s)) {
        final r = item.rating;
        if (r != null) ratings.add(r);
      }
    }
    final avg = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: scheme.primary)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75))),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          stat(l.myList, '${state.total}'),
          stat(l.watched, '${state.countOf('watched')}'),
          stat(l.myRatings, avg == null ? '-' : avg.toStringAsFixed(1)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? selected;
  final SavedListState state;
  final L10n l;
  final ValueChanged<String?> onChanged;
  const _FilterBar({
    required this.selected,
    required this.state,
    required this.l,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <(String?, String, int)>[
      (null, l.t('Tümü', 'All'), state.total),
      for (final s in _statuses) (s, _statusLabel(s, l), state.countOf(s)),
    ];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          return ChoiceChip(
            selected: selected == c.$1,
            onSelected: (_) => onChanged(c.$1),
            label: Text('${c.$2} (${c.$3})'),
          );
        },
      ),
    );
  }
}

class _GridTile extends ConsumerWidget {
  final SavedItem item;
  final L10n l;
  final VoidCallback onLongPress;
  const _GridTile({
    required this.item,
    required this.l,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    final url = item.mediaType == MediaType.person
        ? repo.profile(item.posterPath)
        : repo.poster(item.posterPath);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () => context.openMedia(item.toSummary()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(url: url, fit: BoxFit.cover),
                  if (item.status.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _OverlayChip(
                        text: _statusLabel(item.status, l),
                        color: scheme.primary,
                      ),
                    ),
                  if (item.rating != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: _OverlayChip(
                        text: item.rating!.toStringAsFixed(1),
                        color: scheme.tertiary,
                        icon: Icons.star_rounded,
                      ),
                    ),
                  if (item.voteAverage != null && item.voteAverage! > 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: ScoreBadge(value: item.voteAverage!, size: 28),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _OverlayChip({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ListItem extends ConsumerWidget {
  final SavedItem item;
  final L10n l;
  final VoidCallback onLongPress;
  const _ListItem({
    required this.item,
    required this.l,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final url = item.mediaType == MediaType.person
        ? repo.profile(item.posterPath)
        : repo.poster(item.posterPath);
    final parts = <String>[
      if (item.status.isNotEmpty) _statusLabel(item.status, l),
      if (item.rating != null)
        '${l.yourRating}: ${item.rating!.toStringAsFixed(1)}',
    ];

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () => context.openMedia(item.toSummary()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: item.mediaType == MediaType.person ? 52 : 78,
                child: RemoteImage(url: url, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    parts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (item.voteAverage != null && item.voteAverage! > 0) ...[
              const SizedBox(width: 8),
              ScoreBadge(value: item.voteAverage!, size: 30),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListShimmer extends StatelessWidget {
  const _ListShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.6,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ShimmerBox()),
          SizedBox(height: 6),
          ShimmerBox(height: 12),
        ],
      ),
    );
  }
}
