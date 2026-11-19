import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/local/local_store.dart';
import '../../data/models/tmdb_models.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final ads = ref.watch(adsEnabledProvider);
    ref.watch(followTickProvider);
    final followed = ref.watch(followedPeopleProvider).valueOrNull ?? const [];
    final state = ref.watch(popularPeopleProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.people)),
      body: Column(
        children: [
          if (followed.isNotEmpty) ...[
            SectionTitle(l.followPeople),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: followed.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _FollowedTile(person: followed[i]),
              ),
            ),
          ],
          Expanded(
            child: state.when(
              loading: () => const _PeopleShimmer(),
              error: (e, st) => ErrorView(
                error: e,
                onRetry: () => ref.read(popularPeopleProvider.notifier).reload(),
              ),
              data: (ps) => NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 600 &&
                      ps.hasMore &&
                      !ps.loadingMore) {
                    ref.read(popularPeopleProvider.notifier).loadMore();
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: _peopleSlivers(ps.items,
                      ads: ads, loadingMore: ps.loadingMore),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _peopleSlivers(List<MediaSummary> items,
    {required bool ads, required bool loadingMore}) {
  final out = <Widget>[];
  final n = items.length;
  for (var start = 0; start < n; start += 10) {
    final end = start + 10 > n ? n : start + 10;
    out.add(SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final cols = (width / 124).floor().clamp(2, 6);
          final cellW = (width - (cols - 1) * 10.0) / cols;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              mainAxisExtent: cellW + 44,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _PersonTile(item: items[start + i], size: cellW),
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

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.item, required this.size});

  final MediaSummary item;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    return GestureDetector(
      onTap: () => Nav.person(context, item.id),
      child: Column(
        children: [
          _Avatar(url: item.posterPath == null ? '' : repo.profile(item.posterPath, large: true), size: size),
          const SizedBox(height: 7),
          Text(
            item.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _FollowedTile extends ConsumerWidget {
  const _FollowedTile({required this.person});

  final SavedPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    return GestureDetector(
      onTap: () => Nav.person(context, person.id),
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            _Avatar(url: repo.profile(person.profilePath, large: true), size: 78),
            const SizedBox(height: 6),
            Text(
              person.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: url.isEmpty
            ? Icon(Icons.person_rounded, size: size * 0.45, color: scheme.onSurfaceVariant)
            : RemoteImage(url: url, placeholder: const SizedBox.shrink()),
      ),
    );
  }
}

class _PeopleShimmer extends StatelessWidget {
  const _PeopleShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ShimmerBox(width: 90, height: 90, radius: BorderRadius.all(Radius.circular(45))),
          ShimmerBox(width: 90, height: 90, radius: BorderRadius.all(Radius.circular(45))),
          ShimmerBox(width: 90, height: 90, radius: BorderRadius.all(Radius.circular(45))),
          ShimmerBox(width: 90, height: 90, radius: BorderRadius.all(Radius.circular(45))),
        ],
      ),
    );
  }
}
