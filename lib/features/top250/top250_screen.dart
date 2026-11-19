import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class Top250Screen extends ConsumerWidget {
  const Top250Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final ads = ref.watch(adsEnabledProvider);
    final state = ref.watch(top250Provider);
    return Scaffold(
      appBar: AppBar(title: Text(l.top250)),
      body: state.when(
        loading: () => const _TopShimmer(),
        error: (e, st) => ErrorView(
          error: e,
          onRetry: () => ref.read(top250Provider.notifier).reload(),
        ),
        data: (ps) => NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 600 &&
                ps.hasMore &&
                !ps.loadingMore) {
              ref.read(top250Provider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    l.t('300+ oy ile en yüksek puanlı filmler',
                        'The highest-rated films with 300+ votes'),
                    style: TextStyle(
                        fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              ..._rankSlivers(ps.items, ads: ads, loadingMore: ps.loadingMore),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _rankSlivers(List<MediaSummary> items,
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
          final cols = (width / 136).floor().clamp(2, 5);
          final cellW = (width - (cols - 1) * 12.0) / cols;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 18,
              crossAxisSpacing: 12,
              mainAxisExtent: cellW * 1.5 + 62,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _RankCell(item: items[start + i], rank: start + i + 1),
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

class _RankCell extends ConsumerWidget {
  const _RankCell({required this.item, required this.rank});

  final MediaSummary item;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final l = ref.watch(l10nProvider);
    return GestureDetector(
      onTap: () => context.openMedia(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(url: repo.poster(item.posterPath, large: true)),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.66),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  if (item.voteAverage != null && item.voteAverage! > 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: ScoreBadge(value: item.voteAverage!, size: 30),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25),
          ),
          Text(
            '${item.year} • ${item.voteCount} ${l.votes}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TopShimmer extends StatelessWidget {
  const _TopShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const Row(
        children: [
          Expanded(child: ShimmerBox(height: 230)),
          SizedBox(width: 12),
          Expanded(child: ShimmerBox(height: 230)),
          SizedBox(width: 12),
          Expanded(child: ShimmerBox(height: 230)),
        ],
      ),
    );
  }
}
