import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  MediaType _mediaType = MediaType.movie;
  String _window = 'day';

  (String, String) get _releaseRange {
    final now = DateTime.now();
    final to = now.add(const Duration(days: 14));
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    return (d(now), d(to));
  }

  List<String> get _sectionPaths => _mediaType == MediaType.movie
      ? const ['now_playing', 'upcoming', 'popular', 'top_rated']
      : const ['popular', 'top_rated'];

  Future<void> _refresh() async {
    ref
      ..invalidate(trendingProvider((_mediaType, _window)))
      ..invalidate(releaseCalendarProvider(_releaseRange));
    for (final path in _sectionPaths) {
      ref.invalidate(homeSectionProvider((path, _mediaType)));
    }
  }

  String _titleFor(String path, L10n l) => switch (path) {
        'now_playing' => l.nowPlaying,
        'upcoming' => l.upcoming,
        'popular' => l.popular,
        'top_rated' => l.topRated,
        _ => l.trending,
      };

  void _onSeeAll(String path) => switch (path) {
        'upcoming' => Nav.calendar(context),
        'top_rated' => _mediaType == MediaType.movie
            ? Nav.top250(context)
            : Nav.discover(context, _mediaType),
        _ => Nav.discover(context, _mediaType),
      };

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final adsOn = ref.watch(adsEnabledProvider);

    final sections = <Widget>[];
    for (var i = 0; i < _sectionPaths.length; i++) {
      final path = _sectionPaths[i];
      sections.add(_carousel(path, _titleFor(path, l)));
      if (adsOn && i == 1) sections.add(const InlineAdBanner());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appName,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SegmentedButton<MediaType>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: MediaType.movie, label: Text(l.movies)),
                      ButtonSegment(value: MediaType.tv, label: Text(l.series)),
                    ],
                    selected: {_mediaType},
                    onSelectionChanged: (s) => setState(() => _mediaType = s.first),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text(l.trendingToday),
                    selected: _window == 'day',
                    onSelected: (_) => setState(() => _window = 'day'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l.trendingWeek),
                    selected: _window == 'week',
                    onSelected: (_) => setState(() => _window == 'week'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _hero(),
            if (adsOn) const InlineAdBanner(),
            ...sections,
            _releaseCarousel(),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final async = ref.watch(trendingProvider((_mediaType, _window)));
    return async.when(
      loading: () => const _LoadingRow(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => items.isEmpty ? const SizedBox.shrink() : _HeroSection(items: items),
    );
  }

  Widget _carousel(String path, String title) {
    final async = ref.watch(homeSectionProvider((path, _mediaType)));
    return async.when(
      loading: () => const _LoadingRow(),
      error: (_, __) => const SizedBox.shrink(),
      data: (res) {
        if (res.results.isEmpty) return const SizedBox.shrink();
        return MediaCarousel(
          title: title,
          items: res.results,
          onSeeAll: () => _onSeeAll(path),
        );
      },
    );
  }

  Widget _releaseCarousel() {
    final l = ref.watch(l10nProvider);
    final async = ref.watch(releaseCalendarProvider(_releaseRange));
    return async.when(
      loading: () => const _LoadingRow(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : MediaCarousel(
              title: l.t('Yaklaşan vizyon tarihi', 'Upcoming release dates'),
              items: items,
              onSeeAll: () => Nav.calendar(context),
            ),
    );
  }
}

class _HeroSection extends ConsumerWidget {
  final List<MediaSummary> items;
  const _HeroSection({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = items.first;
    final repo = ref.watch(repoProvider);
    final l = ref.watch(l10nProvider);
    final backdrop = repo.backdrop(top.backdropPath, large: true);
    final status = ref.watch(savedStatusProvider((top.mediaType, top.id))).valueOrNull;
    final saved = status != null && status.isNotEmpty;
    final rest = items.length > 1 ? items.sublist(1, items.length.clamp(1, 12)) : const <MediaSummary>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: () => context.openMedia(top),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(url: backdrop),
                    DecoratedBox(
                        decoration: BoxDecoration(gradient: AppTheme.heroScrim)),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            top.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (top.voteAverage != null && top.voteAverage! > 0)
                                ScoreBadge(value: top.voteAverage!),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => context.openMedia(top),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: Text(l.t('Detay', 'Details')),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => ref
                                    .read(savedListProvider.notifier)
                                    .toggle(top.id, top.mediaType, 'watchlist', top),
                                icon: Icon(
                                  saved ? Icons.bookmark : Icons.bookmark_border,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (rest.isNotEmpty)
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 11),
              itemBuilder: (_, i) => PosterCard(item: rest[i]),
            ),
          ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 236,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              ShimmerBox(width: 118, height: 200),
              SizedBox(width: 11),
              ShimmerBox(width: 118, height: 200),
              SizedBox(width: 11),
              ShimmerBox(width: 118, height: 200),
            ],
          ),
        ),
      );
}
