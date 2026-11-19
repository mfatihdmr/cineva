import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/utils/format.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

Future<void> _launch(BuildContext context, WidgetRef ref, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme.isEmpty) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(l10nProvider).t('Bağlantı açılamadı', 'Could not open link'),
        ),
      ),
    );
  }
}

class SeasonScreen extends ConsumerStatefulWidget {
  final int tvId;
  final int seasonNumber;
  const SeasonScreen({
    super.key,
    required this.tvId,
    required this.seasonNumber,
  });

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen> {
  void _markWatched() {
    final l = ref.read(l10nProvider);
    final show =
        ref.read(mediaDetailProvider((MediaType.tv, widget.tvId))).valueOrNull;
    if (show == null) return;
    final summary = MediaSummary(
      id: show.id,
      mediaType: MediaType.tv,
      title: show.title,
      originalTitle: show.originalTitle,
      posterPath: show.posterPath,
      voteAverage: show.voteAverage,
      releaseDate: show.releaseDate,
    );
    ref
        .read(savedListProvider.notifier)
        .setStatus(show.id, MediaType.tv, 'watched', summary);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${show.title} — ${l.watched}')));
  }

  Future<void> _refresh() async {
    ref.invalidate(seasonProvider((widget.tvId, widget.seasonNumber)));
    try {
      await ref.read(seasonProvider((widget.tvId, widget.seasonNumber)).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final showAsync = ref.watch(
      mediaDetailProvider((MediaType.tv, widget.tvId)),
    );
    final seasonAsync = ref.watch(
      seasonProvider((widget.tvId, widget.seasonNumber)),
    );
    final show = showAsync.valueOrNull;
    final ads = ref.watch(adsEnabledProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          show?.title ?? l.season,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _seasonChips(show, l)),
            SliverToBoxAdapter(
              child: _header(seasonAsync.valueOrNull, seasonAsync.isLoading, l),
            ),
            if (seasonAsync.hasError)
              SliverToBoxAdapter(
                child: ErrorView(
                  error: seasonAsync.error,
                  onRetry:
                      () => ref.invalidate(
                        seasonProvider((widget.tvId, widget.seasonNumber)),
                      ),
                ),
              )
            else if (seasonAsync.valueOrNull != null &&
                seasonAsync.valueOrNull!.episodes.isEmpty)
              SliverToBoxAdapter(
                child: EmptyView(
                  icon: Icons.video_library_outlined,
                  title: l.t(
                    'Bu sezonda bölüm yok',
                    'No episodes in this season',
                  ),
                ),
              )
            else if (seasonAsync.valueOrNull != null)
              SliverList(
                delegate: SliverChildListDelegate(
                  _episodeRows(seasonAsync.valueOrNull!, ads, l),
                ),
              )
            else
              const SliverToBoxAdapter(child: _SeasonShimmer()),
          ],
        ),
      ),
    );
  }

  Widget _seasonChips(MediaDetail? show, L10n l) {
    if (show == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 90, 4),
        child: ShimmerBox(
          height: 34,
          radius: BorderRadius.all(Radius.circular(20)),
        ),
      );
    }
    final seasons = <SeasonSummary>[...show.seasons];
    if (!seasons.any((s) => s.seasonNumber == widget.seasonNumber)) {
      seasons.add(
        SeasonSummary(
          seasonNumber: widget.seasonNumber,
          name: '${l.season} ${widget.seasonNumber}',
        ),
      );
    }
    seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = seasons[i];
          final selected = s.seasonNumber == widget.seasonNumber;
          return ChoiceChip(
            label: Text(
              s.name.isEmpty ? '${l.season} ${s.seasonNumber}' : s.name,
            ),
            selected: selected,
            onSelected:
                selected
                    ? null
                    : ((_) => Nav.season(context, widget.tvId, s.seasonNumber)),
          );
        },
      ),
    );
  }

  Widget _header(SeasonDetail? d, bool loading, L10n l) {
    final scheme = Theme.of(context).colorScheme;
    if (d == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 92, height: 138),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 140, height: 13),
                  SizedBox(height: 8),
                  ShimmerBox(height: 13),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final repo = ref.watch(repoProvider);
    final meta = <String>[
      if (d.airDate != null && d.airDate!.isNotEmpty) formatDate(d.airDate),
      '${d.episodes.length} ${l.episodes}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 138,
                  child: RemoteImage(url: repo.poster(d.posterPath)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final m in meta)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (d.overview.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              d.overview.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _episodeRows(SeasonDetail d, bool ads, L10n l) {
    final kids = <Widget>[];
    for (var i = 0; i < d.episodes.length; i++) {
      final e = d.episodes[i];
      kids.add(
        _EpisodeTile(
          tvId: widget.tvId,
          seasonNumber: widget.seasonNumber,
          episode: e,
          l: l,
          onMarkWatched: _markWatched,
        ),
      );
      if (ads && (i + 1) % 10 == 0 && i + 1 < d.episodes.length) {
        kids.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: InlineAdBanner(),
          ),
        );
      }
    }
    kids.add(const SizedBox(height: 24));
    return kids;
  }
}

class _EpisodeTile extends ConsumerWidget {
  final int tvId;
  final int seasonNumber;
  final EpisodeDetail episode;
  final L10n l;
  final VoidCallback onMarkWatched;
  const _EpisodeTile({
    required this.tvId,
    required this.seasonNumber,
    required this.episode,
    required this.l,
    required this.onMarkWatched,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    final e = episode;
    final title =
        e.name.isEmpty
            ? 'E${e.episodeNumber}'
            : 'E${e.episodeNumber}. ${e.name}';
    final meta = <String>[
      if (e.airDate != null && e.airDate!.isNotEmpty) formatDate(e.airDate),
      if (e.runtime > 0) formatRuntime(e.runtime),
      if (e.voteAverage != null && e.voteAverage! > 0)
        formatScore(e.voteAverage),
    ].join(' • ');
    return GestureDetector(
      onLongPress: onMarkWatched,
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
        child: ExpansionTile(
          key: PageStorageKey('s${seasonNumber}_e${e.episodeNumber}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading:
              e.stillPath == null
                  ? Container(
                    width: 64,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                  : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 40,
                      child: RemoteImage(
                        url: repo.image(e.stillPath, size: 'w300'),
                      ),
                    ),
                  ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.overview.isNotEmpty)
                Text(
                  e.overview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    meta,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          children: [
            _EpisodeExpanded(
              tvId: tvId,
              seasonNumber: seasonNumber,
              episodeNumber: e.episodeNumber,
              l: l,
              onMarkWatched: onMarkWatched,
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeExpanded extends ConsumerWidget {
  final int tvId;
  final int seasonNumber;
  final int episodeNumber;
  final L10n l;
  final VoidCallback onMarkWatched;
  const _EpisodeExpanded({
    required this.tvId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.l,
    required this.onMarkWatched,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (tvId, seasonNumber, episodeNumber);
    final async = ref.watch(episodeProvider(key));
    return async.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
      error:
          (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(episodeProvider(key)),
          ),
      data: (d) => _body(context, ref, d),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, EpisodeDetail d) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    final videos = d.videos.where((v) => v.isYouTube).toList();
    final stills = <String>[
      for (final ep
          in ref
                  .watch(seasonProvider((tvId, seasonNumber)))
                  .valueOrNull
                  ?.episodes ??
              const <EpisodeDetail>[])
        if (ep.stillPath != null) ep.stillPath!,
    ];
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.cast.isNotEmpty) ...[
          header(l.cast),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in d.cast.take(8))
                ActionChip(
                  avatar:
                      c.profilePath == null
                          ? null
                          : ClipOval(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: RemoteImage(
                                url: repo.profile(c.profilePath),
                              ),
                            ),
                          ),
                  label: Text(
                    c.character.isEmpty ? c.name : '${c.name} (${c.character})',
                  ),
                  onPressed: () => Nav.person(context, c.id),
                ),
            ],
          ),
        ],
        if (d.crew.isNotEmpty) ...[
          header(l.crew),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in d.crew.take(6))
                ActionChip(
                  label: Text(c.job.isEmpty ? c.name : '${c.name} • ${c.job}'),
                  onPressed: () => Nav.person(context, c.id),
                ),
            ],
          ),
        ],
        if (videos.isNotEmpty) ...[
          header(l.videos),
          for (final v in videos.take(6))
            InkWell(
              onTap: () => _launch(context, ref, v.youtubeUrl),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 96,
                        height: 54,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RemoteImage(url: v.thumbnailUrl),
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white70,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        v.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (stills.isNotEmpty) ...[
          header(l.photos),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stills.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder:
                  (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 112,
                      height: 66,
                      child: RemoteImage(
                        url: repo.image(stills[i], size: 'w300'),
                      ),
                    ),
                  ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: OutlinedButton.icon(
            onPressed: onMarkWatched,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(l.markWatched),
          ),
        ),
      ],
    );
  }
}

class _SeasonShimmer extends StatelessWidget {
  const _SeasonShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: const [
        ShimmerBox(height: 76, radius: BorderRadius.all(Radius.circular(16))),
        SizedBox(height: 8),
        ShimmerBox(height: 76, radius: BorderRadius.all(Radius.circular(16))),
        SizedBox(height: 8),
        ShimmerBox(height: 76, radius: BorderRadius.all(Radius.circular(16))),
        SizedBox(height: 8),
        ShimmerBox(height: 76, radius: BorderRadius.all(Radius.circular(16))),
      ],
    );
  }
}
