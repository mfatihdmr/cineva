import 'package:flutter/material.dart' hide ImageInfo;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/ads.dart';
import '../../app/deep_link.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/format.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';
import '../settings/settings_controller.dart';
import 'widgets.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  final MediaType type;
  final int id;

  const MediaDetailScreen({super.key, required this.type, required this.id});

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  static const List<String> _statuses = [
    'watchlist',
    'watching',
    'watched',
    'favorites',
    'rated',
  ];
  static const Map<String, IconData> _statusIcons = {
    'watchlist': Icons.bookmarks_outlined,
    'watching': Icons.play_circle_outline_rounded,
    'watched': Icons.done_all_rounded,
    'favorites': Icons.favorite_outline_rounded,
    'rated': Icons.star_outline_rounded,
  };

  final ScrollController _scroll = ScrollController();
  bool _pinned = false;
  double _heroHeight = 320;

  (MediaType, int) get _key => (widget.type, widget.id);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) InterstitialAdManager.instance.maybeShow();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pinned = _scroll.offset > _heroHeight - kToolbarHeight - 24;
    if (pinned != _pinned) setState(() => _pinned = pinned);
  }

  Future<void> _refresh() async {
    ref.invalidate(mediaDetailProvider(_key));
    try {
      await ref.read(mediaDetailProvider(_key).future);
    } catch (_) {}
  }

  String _titleOf(MediaDetail d) =>
      d.title.isNotEmpty ? d.title : d.originalTitle;

  MediaSummary _summary(MediaDetail d) => MediaSummary(
        id: d.id,
        mediaType: d.mediaType,
        title: d.title,
        originalTitle: d.originalTitle,
        overview: d.overview,
        posterPath: d.posterPath,
        backdropPath: d.backdropPath,
        voteAverage: d.voteAverage,
        voteCount: d.voteCount,
        adult: d.adult,
        originalLanguage: d.originalLanguage,
        genreIds: [for (final g in d.genres) g.id],
        releaseDate: d.releaseDate,
      );

  VideoInfo? _trailerFor(MediaDetail d) {
    for (final v in d.videos) {
      if (v.isYouTube && v.isTrailer) return v;
    }
    for (final v in d.videos) {
      if (v.isYouTube) return v;
    }
    return null;
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleWatchlist(MediaSummary summary) async {
    final l = ref.read(l10nProvider);
    final added = await ref
        .read(savedListProvider.notifier)
        .toggle(widget.id, widget.type, 'watchlist', summary);
    if (!mounted) return;
    _snack(added
        ? l.t('İzleme listene eklendi', 'Added to your watchlist')
        : l.t('İzleme listenden çıkarıldı', 'Removed from your watchlist'));
  }

  void _openStatusSheet(MediaSummary summary, String? current) {
    final l = ref.read(l10nProvider);
    String labelOf(String s) => switch (s) {
          'watchlist' => l.watchlist,
          'watching' => l.watching,
          'watched' => l.watched,
          'favorites' => l.favorites,
          _ => l.t('Puanlanmış', 'Rated'),
        };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l.addToList,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            for (final s in _statuses)
              ListTile(
                leading: Icon(_statusIcons[s]),
                title: Text(labelOf(s)),
                trailing: current == s
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(sheetCtx).colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  if (current == s) {
                    _snack(l.t('Zaten bu durumda', 'Already set'));
                    return;
                  }
                  ref
                      .read(savedListProvider.notifier)
                      .setStatus(widget.id, widget.type, s, summary);
                  _snack('${labelOf(s)} ${l.addedTo}');
                },
              ),
            if (current != null && current.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l.remove,
                    style: TextStyle(
                        color: Theme.of(sheetCtx).colorScheme.error)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ref
                      .read(savedListProvider.notifier)
                      .remove(widget.id, widget.type);
                  _snack(l.t('Listeden çıkarıldı', 'Removed from list'));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openRatingDialog(MediaSummary summary) {
    final l = ref.read(l10nProvider);
    double value = ref.read(savedRatingProvider(_key)).valueOrNull ?? 7.0;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.rateIt),
        content: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.toStringAsFixed(1)} / 10',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Slider(
                min: 0.5,
                max: 10,
                divisions: 19,
                value: value,
                label: value.toStringAsFixed(1),
                onChanged: (v) => setSheet(() => value = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref
                  .read(savedListProvider.notifier)
                  .rate(widget.id, widget.type, summary, value);
              _snack(l.t('Puanın kaydedildi', 'Rating saved'));
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  void _openNoteDialog() {
    final l = ref.read(l10nProvider);
    final controller =
        TextEditingController(text: ref.read(noteProvider(_key)).valueOrNull ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.t('Not', 'Note')),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l.t('Düşüncelerin…', 'Your thoughts…'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final body = controller.text.trim();
              Navigator.of(dialogCtx).pop();
              ref
                  .read(savedListProvider.notifier)
                  .setNote(widget.id, widget.type, body);
              _snack(body.isEmpty
                  ? l.t('Not kaldırıldı', 'Note removed')
                  : l.t('Not kaydedildi', 'Note saved'));
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    final l = ref.read(l10nProvider);
    final url = CinevaLink(kind: 'media', mediaType: widget.type, id: widget.id)
        .shareUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _snack(l.t('Bağlantı kopyalandı', 'Link copied'));
  }

  Future<void> _openTrailer(VideoInfo video) async {
    await launchUrl(Uri.parse(video.youtubeUrl),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final detail = ref.watch(mediaDetailProvider(_key));
    final d = detail.valueOrNull;
    final heroHeight =
        (MediaQuery.sizeOf(context).width * 0.88).clamp(280.0, 430.0);
    _heroHeight = heroHeight;
    final overImage = d != null && !_pinned;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: d == null ? kToolbarHeight : heroHeight,
              backgroundColor: overImage ? Colors.transparent : null,
              foregroundColor: overImage ? Colors.white : null,
              title: d == null
                  ? null
                  : Opacity(
                      opacity: _pinned ? 1 : 0,
                      child: Text(
                        _titleOf(d),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
              actions: [
                if (d != null)
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    tooltip: ref.watch(l10nProvider).retry,
                  ),
                if (d != null)
                  IconButton(
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share_rounded, size: 21),
                    tooltip: ref.watch(l10nProvider).share,
                  ),
              ],
              flexibleSpace: d == null
                  ? null
                  : FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: HeroPoster(
                        backdropUrl: repo.backdrop(d.backdropPath, large: true),
                        posterUrl: repo.poster(d.posterPath, large: true),
                        title: _titleOf(d),
                        tagline: d.tagline,
                        year: formatYear(d.releaseDate),
                        voteAverage: d.voteAverage,
                        adult: d.adult,
                        genres: d.genres,
                      ),
                    ),
            ),
            ...detail.when(
              loading: () => const [
                SliverToBoxAdapter(child: DetailSkeleton()),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(mediaDetailProvider(_key)),
                  ),
                ),
              ],
              data: (m) => _sections(m, repo),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(MediaDetail d, TmdbRepo repo) {
    final l = ref.watch(l10nProvider);
    final summary = _summary(d);
    final rawStatus = ref.watch(savedStatusProvider(_key)).valueOrNull;
    final status = (rawStatus == null || rawStatus.isEmpty) ? null : rawStatus;
    final myRating = ref.watch(savedRatingProvider(_key)).valueOrNull;
    final note = ref.watch(noteProvider(_key)).valueOrNull;
    final trailer = _trailerFor(d);
    final adsOn = ref.watch(adsEnabledProvider);
    final region = ref.watch(settingsProvider).region;
    final similar = ref
            .watch(relatedMediaProvider((widget.type, widget.id, 'similar')))
            .valueOrNull
            ?.items ??
        const <MediaSummary>[];
    final recs = ref
            .watch(
                relatedMediaProvider((widget.type, widget.id, 'recommendations')))
            .valueOrNull
            ?.items ??
        const <MediaSummary>[];

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _actionRow(summary, status, myRating, trailer),
      ),
    ];

    if (d.overview.trim().isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: _Overview(text: d.overview)));
    }

    if (note != null && note.trim().isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: SectionTitle(
          l.t('Notum', 'My note'),
          trailing: IconButton(
            onPressed: _openNoteDialog,
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: l.save,
          ),
        ),
      ));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(note,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.45)),
            ),
          ),
        ),
      ));
    }

    final facts = <Widget>[];
    if (d.runtime > 0) {
      facts.add(MetaRow(label: l.runtime, value: formatRuntime(d.runtime)));
    }
    if (d.status.isNotEmpty) {
      facts.add(MetaRow(label: l.status, value: d.status));
    }
    if (d.originalLanguage.isNotEmpty) {
      facts.add(MetaRow(
          label: l.originalLanguage,
          value: d.originalLanguage.toUpperCase()));
    }
    if (d.releaseDate != null && d.releaseDate!.isNotEmpty) {
      facts.add(MetaRow(
        label: widget.type == MediaType.movie ? l.releaseDate : l.firstAir,
        value: formatDate(d.releaseDate),
      ));
    }
    if (d.budget > 0) {
      facts.add(MetaRow(label: l.budget, value: formatMoney(d.budget)));
    }
    if (d.revenue > 0) {
      facts.add(MetaRow(label: l.revenue, value: formatMoney(d.revenue)));
    }
    if (d.productionCountries.isNotEmpty) {
      facts.add(MetaRow(
        label: l.country,
        value: d.productionCountries.map((c) => c.localName).join(', '),
      ));
    }
    if (widget.type == MediaType.tv &&
        d.episodeRunTime != null &&
        d.episodeRunTime! > 0) {
      facts.add(MetaRow(
          label: l.t('Bölüm süresi', 'Episode runtime'),
          value: formatRuntime(d.episodeRunTime)));
    }
    if (d.createdBy != null && d.createdBy!.isNotEmpty) {
      facts.add(MetaRow(
          label: l.t('Yaratıcı', 'Created by'), value: d.createdBy!));
    }
    if (facts.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: SectionTitle(l.facts),
      ));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(
              children: [
                for (var i = 0; i < facts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                  facts[i],
                ],
              ],
            ),
          ),
        ),
      ));
    }

    if (d.credits.cast.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: SectionTitle(
          l.cast,
          trailing: TextButton(
            onPressed: () => Nav.credits(context, widget.type, widget.id,
                _titleOf(d), d.credits.cast, d.credits.crew),
            child: Text(l.seeAll, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
      ));
      slivers.add(SliverToBoxAdapter(child: _castRow(d, repo)));
    }

    if (adsOn) {
      slivers.add(const SliverToBoxAdapter(child: InlineAdBanner()));
    }

    if (similar.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
          child: MediaCarousel(title: l.similar, items: similar)));
    }
    if (recs.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
          child: MediaCarousel(title: l.recommendations, items: recs)));
    }

    final rp = d.providers.region(region) ?? d.providers.region('TR');
    if (rp != null && !rp.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: SectionTitle(l.whereToWatch)));
      final rows = <Widget>[];
      if (rp.flatrate.isNotEmpty) {
        rows.add(_providerRow(l.streaming, rp.flatrate, repo));
      }
      if (rp.rent.isNotEmpty) {
        if (rows.isNotEmpty) {
          rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
        }
        rows.add(_providerRow(l.rent, rp.rent, repo));
      }
      if (rp.buy.isNotEmpty) {
        if (rows.isNotEmpty) {
          rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
        }
        rows.add(_providerRow(l.buy, rp.buy, repo));
      }
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(child: Column(children: rows)),
        ),
      ));
    }

    if (adsOn) {
      slivers.add(const SliverToBoxAdapter(child: InlineAdBanner()));
    }

    final certs = d.certifications
        .where((c) => c.country == region || c.country == 'TR')
        .toList();
    final releaseRegion = d.releases[region] ?? d.releases['TR'];
    final releaseEntries = releaseRegion?.entries ?? const <ReleaseDateEntry>[];
    if (certs.isNotEmpty || releaseEntries.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: SectionTitle(l.ageRating)));
      if (certs.isNotEmpty) {
        slivers.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final c in certs)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color:
                          Theme.of(context).colorScheme.errorContainer,
                    ),
                    child: Text(
                      '${c.certification}${c.country == 'TR' ? '' : ' · ${c.country}'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ));
      }
      for (final e in releaseEntries.take(4)) {
        if (e.date.isEmpty) continue;
        slivers.add(SliverToBoxAdapter(
            child: MetaRow(label: e.typeLabel, value: formatDate(e.date))));
      }
    }

    if (widget.type == MediaType.tv && d.seasons.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: SectionTitle(l.seasons)));
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _seasonTile(d.seasons[i], repo),
          childCount: d.seasons.length,
        ),
      ));
    }

    final collection = d.belongsToCollection;
    if (collection != null) {
      slivers.add(SliverToBoxAdapter(
          child: SectionTitle(l.belongsToCollection)));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Nav.collection(context, collection.id),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 46,
                        height: 69,
                        child: RemoteImage(
                            url: repo.poster(collection.posterPath)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        collection.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    if (d.productionCompanies.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
          child: SectionTitle(l.productionCompanies)));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final c in d.productionCompanies)
                ActionChip(
                  label: Text(c.name,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => Nav.company(context, c.id),
                ),
            ],
          ),
        ),
      ));
    }

    if (d.keywords.isNotEmpty) {
      slivers.add(
          SliverToBoxAdapter(child: SectionTitle(l.keywordsLabel)));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final k in d.keywords.take(12))
                ActionChip(
                  label: Text(k.name, style: const TextStyle(fontSize: 12)),
                  onPressed: () => Nav.keyword(context, k.id, k.name),
                ),
            ],
          ),
        ),
      ));
    }

    if (d.reviews.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: SectionTitle(
          l.reviews,
          trailing: TextButton(
            onPressed: () => Nav.reviews(context, widget.type, widget.id),
            child: Text(l.seeAll, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
      ));
      for (final r in d.reviews.take(2)) {
        slivers.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                        if (r.rating > 0)
                          Text('${r.rating}/10',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      r.shortContent,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
      }
    }

    if (adsOn) {
      slivers.add(const SliverToBoxAdapter(child: InlineAdBanner()));
    }

    final allImages = <ImageInfo>[
      ...d.images.backdrops,
      ...d.images.posters,
      ...d.images.stills,
    ];
    if (allImages.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: SectionTitle(
          l.gallery,
          trailing: TextButton(
            onPressed: () =>
                Nav.gallery(context, widget.type, widget.id, images: allImages),
            child: Text(l.seeAll, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
      ));
      slivers.add(SliverToBoxAdapter(
        child: SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allImages.length.clamp(0, 8),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () =>
                  Nav.gallery(context, widget.type, widget.id, images: allImages),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 150,
                  child: RemoteImage(
                      url: repo.image(allImages[i].filePath, size: 'w500')),
                ),
              ),
            ),
          ),
        ),
      ));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 28)));
    return slivers;
  }

  Widget _actionRow(MediaSummary summary, String? status,
      double? myRating, VideoInfo? trailer) {
    final l = ref.watch(l10nProvider);
    final saved = status == 'watchlist';
    String statusLabel(String s) => switch (s) {
          'watchlist' => l.watchlist,
          'watching' => l.watching,
          'watched' => l.watched,
          'favorites' => l.favorites,
          _ => l.t('Puanlanmış', 'Rated'),
        };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _toggleWatchlist(summary),
            icon: Icon(saved
                ? Icons.bookmark_added_rounded
                : Icons.bookmark_add_outlined, size: 19),
            label: Text(saved
                ? l.t('Listemde', 'In my list')
                : l.t('İzleme listem', 'Watchlist')),
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _openStatusSheet(summary, status),
            icon: Icon(status == null
                ? Icons.flag_outlined
                : (_statusIcons[status] ?? Icons.flag_outlined), size: 18),
            label: Text(status == null
                ? l.addToList
                : statusLabel(status)),
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _openRatingDialog(summary),
            icon: Icon(
                myRating != null ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: myRating != null ? AppTheme.accentGold : null),
            label: Text(myRating != null
                ? myRating.toStringAsFixed(1)
                : l.rateIt),
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openNoteDialog,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(l.t('Not', 'Note')),
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(l.share),
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
          if (trailer != null) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _openTrailer(trailer),
              icon: const Icon(Icons.play_arrow_rounded, size: 19),
              label: Text(l.trailer),
              style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ],
      ),
    );
  }

  Widget _castRow(MediaDetail d, TmdbRepo repo) {
    final cast = d.credits.cast.take(12).toList();
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cast[i];
          return GestureDetector(
            onTap: () => Nav.person(context, c.id),
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: RemoteImage(
                          url: repo.profile(c.profilePath, large: false)),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.character,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _providerRow(
      String label, List<WatchProviderEntry> entries, TmdbRepo repo) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Nav.watchProviders(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in entries.take(10))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: ColoredBox(
                          color: cs.surfaceContainerHighest,
                          child: RemoteImage(
                              url: repo.image(p.logoPath, size: 'w92')),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seasonTile(SeasonSummary s, TmdbRepo repo) {
    final l = ref.watch(l10nProvider);
    final year = formatYear(s.airDate);
    final parts = <String>[
      if (year.isNotEmpty) year,
      '${s.episodeCount} ${l.episodes.toLowerCase()}',
    ];
    return InkWell(
      onTap: () => Nav.season(context, widget.id, s.seasonNumber),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 66,
                child: RemoteImage(url: repo.poster(s.posterPath)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Overview extends ConsumerStatefulWidget {
  final String text;

  const _Overview({required this.text});

  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final long = widget.text.length > 260;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l.overview),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, height: 1.5),
          ),
        ),
        if (long)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? l.readLess : l.readMore,
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }
}
