import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class HeroPoster extends StatelessWidget {
  final String backdropUrl;
  final String posterUrl;
  final String title;
  final String tagline;
  final String year;
  final double? voteAverage;
  final bool adult;
  final List<Genre> genres;

  const HeroPoster({
    super.key,
    required this.backdropUrl,
    required this.posterUrl,
    required this.title,
    this.tagline = '',
    this.year = '',
    this.voteAverage,
    this.adult = false,
    this.genres = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RemoteImage(url: backdropUrl, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(gradient: AppTheme.heroScrim),
          child: const SizedBox.expand(),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (posterUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 92,
                        height: 138,
                        child: RemoteImage(url: posterUrl),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            if (adult) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5A5F),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('18+',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (year.isNotEmpty)
                              Text(
                                year,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (voteAverage != null && voteAverage! > 0) ...[
                              const SizedBox(width: 9),
                              ScoreBadge(value: voteAverage!, size: 30),
                            ],
                          ],
                        ),
                        const SizedBox(height: 9),
                        GenreChips(genres: genres, max: 3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const MetaRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 13, color: muted?.withValues(alpha: 0.75)),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(height: width * 0.72, radius: BorderRadius.zero),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ShimmerBox(
                width: 92,
                height: 138,
                radius: BorderRadius.all(Radius.circular(14)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 20, width: width * 0.42),
                    const SizedBox(height: 9),
                    ShimmerBox(height: 12, width: width * 0.24),
                    const SizedBox(height: 9),
                    ShimmerBox(height: 26, width: width * 0.55),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final w in [1.0, 0.92, 0.8, 0.95])
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
            child: ShimmerBox(height: 13, width: width * 0.9 * w),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (_, __) =>
                const ShimmerBox(width: 118, height: 200),
          ),
        ),
        const SizedBox(height: 16),
        for (final w in [0.9, 0.75, 0.85])
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
            child: ShimmerBox(height: 46, width: width * 0.9 * w),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
