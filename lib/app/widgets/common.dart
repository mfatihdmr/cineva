import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../navigation.dart';
import '../providers.dart';
import '../../data/api/tmdb_api.dart';
import '../../data/models/tmdb_models.dart';

/// Poster kartı: görsel + başlık + puan. Basınca detaya gider.
class PosterCard extends ConsumerWidget {
  final MediaSummary item;
  final double width;
  final bool showTitle;
  const PosterCard({
    super.key,
    required this.item,
    this.width = 118,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final url = repo.poster(item.posterPath, large: true);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.openMedia(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(url: url, fit: BoxFit.cover),
                    if (item.voteAverage != null && item.voteAverage! > 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: ScoreBadge(value: item.voteAverage!),
                      ),
                    if (item.adult)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A5F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('18+',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showTitle) ...[
            const SizedBox(height: 7),
            Text(
              item.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25),
            ),
            if (item.year.isNotEmpty)
              Text(item.year,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.55))),
          ],
        ],
      ),
    );
  }
}

/// Yatay kaydırmalı içerik satırı.
class MediaCarousel extends ConsumerWidget {
  final String title;
  final List<MediaSummary> items;
  final VoidCallback? onSeeAll;
  final double cardWidth;
  final bool showTitles;
  const MediaCarousel({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.cardWidth = 118,
    this.showTitles = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l = ref.watch(l10nProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              ),
              if (onSeeAll != null)
                TextButton(
                    onPressed: onSeeAll,
                    child: Text(l.seeAll, style: const TextStyle(fontSize: 12.5))),
            ],
          ),
        ),
        SizedBox(
          height: showTitles ? 236 : 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (_, i) => PosterCard(item: items[i], width: cardWidth, showTitle: showTitles),
          ),
        ),
      ],
    );
  }
}

/// Sinematik arka plan (backdrop) görseli.
class RemoteImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: (width == null ? 500 : width!).round(),
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => placeholder ?? ShimmerBox(width: width, height: height),
      errorWidget: (_, __, ___) => placeholder ?? _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie_outlined, size: 26, color: Colors.white30),
      );
}

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? radius;
  const ShimmerBox({super.key, this.width, this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1C242E) : const Color(0xFFE6E8EC),
      highlightColor: dark ? const Color(0xFF2A333F) : const Color(0xFFF3F5F8),
      child: Container(
        width: width,
        height: height ?? 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius ?? BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final double value;
  final double size;
  const ScoreBadge({super.key, required this.value, this.size = 34});

  Color get _color => value >= 7 ? const Color(0xFF2BB673) : value >= 5 ? const Color(0xFFE5A50A) : const Color(0xFFE0475B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '${(value * 10).round()}%',
        style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: _color),
      ),
    );
  }
}

/// Tür etiketleri satırı.
class GenreChips extends StatelessWidget {
  final List<Genre> genres;
  final int max;
  const GenreChips({super.key, required this.genres, this.max = 4});

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final g in genres.take(max))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Text(g.name,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
          ),
      ],
    );
  }
}

class ErrorView extends ConsumerWidget {
  final Object? error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.white24),
            const SizedBox(height: 14),
            Text(l.errorTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(error is TmdbException ? '$error' : l.emptySub,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({super.key, this.icon = Icons.movie_filter_outlined, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white24),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 7),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.55))),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Bölüm başlığı + sağda aksiyon.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Liste/grid geçiş düğmesi.
class ViewToggleButton extends StatelessWidget {
  final bool grid;
  final VoidCallback onTap;
  const ViewToggleButton({super.key, required this.grid, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 21),
        tooltip: grid ? 'Liste' : 'Izgara',
      );
}

/// Sayfa geçiş kısayolu.
extension MediaNav on BuildContext {
  void openMedia(MediaSummary m) {
    if (m.mediaType == MediaType.person) {
      Nav.person(this, m.id);
    } else {
      Nav.media(this, m.mediaType, m.id);
    }
  }
}
