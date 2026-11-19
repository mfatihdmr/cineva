import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/utils/format.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final MediaType type;
  final int id;
  const ReviewsScreen({super.key, required this.type, required this.id});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final List<ReviewItem> _extra = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _moreError;

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final next = _page + 1;
      final res = await ref
          .read(repoProvider)
          .api
          .reviews(widget.type, widget.id, page: next);
      if (!mounted) return;
      setState(() {
        _page = next;
        _extra.addAll(res.results);
        _hasMore = res.hasMore && res.results.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
        _moreError = '';
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(reviewsProvider((widget.type, widget.id)));
    setState(() {
      _extra.clear();
      _page = 1;
      _hasMore = true;
      _moreError = null;
    });
    try {
      await ref.read(reviewsProvider((widget.type, widget.id)).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final ads = ref.watch(adsEnabledProvider);
    final key = (widget.type, widget.id);
    final async = ref.watch(reviewsProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(l.reviews)),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const _ReviewsShimmer(),
              error:
                  (e, st) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(reviewsProvider(key)),
                  ),
              data: (firstPage) => _list(firstPage, l),
            ),
          ),
          if (ads) const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }

  Widget _list(List<ReviewItem> firstPage, L10n l) {
    if (firstPage.isEmpty && _extra.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyView(
                icon: Icons.rate_review_outlined,
                title: l.t('Henüz inceleme yok', 'No reviews yet'),
                subtitle: l.emptySub,
              ),
            ),
          ],
        ),
      );
    }
    final all = <ReviewItem>[...firstPage, ..._extra];
    return RefreshIndicator(
      onRefresh: _refresh,
      color: Theme.of(context).colorScheme.primary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 500) _loadMore();
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          itemCount: all.length + (_loadingMore || _moreError != null ? 1 : 0),
          itemBuilder: (_, i) {
            if (i < all.length) return _ReviewCard(review: all[i], l: l);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child:
                    _loadingMore
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                        : TextButton(
                          onPressed: _loadMore,
                          child: Text(
                            l.t('Daha fazla dene', 'Try loading more'),
                          ),
                        ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  final ReviewItem review;
  final L10n l;
  const _ReviewCard({required this.review, required this.l});

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final l = widget.l;
    final scheme = Theme.of(context).colorScheme;
    final hasMore = r.content != r.shortContent;
    final body = _expanded ? r.content : r.shortContent;
    String ratingLabel = '';
    if (r.rating > 0) {
      final score = r.rating / 2.0;
      ratingLabel = '${score.toStringAsFixed(score % 1 == 0 ? 0 : 1)} / 10';
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primary.withValues(alpha: 0.18),
                  child: Text(
                    r.author.isEmpty ? '?' : r.author.characters.first,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        relativeTime(r.updatedAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ratingLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: scheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ratingLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              maxLines: _expanded ? null : 6,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (hasMore)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? l.readLess : l.readMore),
                ),
              ),
            if (r.url.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(r.url);
                    if (uri == null) return;
                    final ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l.t('Bağlantı açılamadı', 'Could not open link'),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(l.t('Kaynağı görüntüle', 'View source')),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ReviewsShimmer extends StatelessWidget {
  const _ReviewsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        ShimmerBox(height: 160, radius: BorderRadius.all(Radius.circular(16))),
        SizedBox(height: 12),
        ShimmerBox(height: 200, radius: BorderRadius.all(Radius.circular(16))),
        SizedBox(height: 12),
        ShimmerBox(height: 170, radius: BorderRadius.all(Radius.circular(16))),
      ],
    );
  }
}
