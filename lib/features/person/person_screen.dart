import 'package:flutter/material.dart' hide ImageInfo;
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

class PersonScreen extends ConsumerStatefulWidget {
  final int id;
  const PersonScreen({super.key, required this.id});

  @override
  ConsumerState<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends ConsumerState<PersonScreen> {
  bool _bioExpanded = false;
  bool _showMovies = true;

  Future<void> _toggleFollow(PersonDetail p) async {
    await ref
        .read(localStoreProvider)
        .toggleFollow(p.id, p.name, p.profilePath);
    ref.read(followTickProvider.notifier).state++;
  }

  String _ageLabel(PersonDetail p) {
    final raw = p.age;
    if (raw != null && raw > 0 && raw < 120) return '$raw';
    if (raw != null) return '-';
    final b = p.birthday;
    if (b == null || p.deathday != null) return '';
    final d = DateTime.tryParse(b);
    if (d == null) return '';
    final now = DateTime.now();
    var years = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      years--;
    }
    return (years > 0 && years < 120) ? '$years' : '';
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final ads = ref.watch(adsEnabledProvider);
    final async = ref.watch(personDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.name ?? l.people,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const _PersonShimmer(),
              error:
                  (e, st) => ErrorView(
                    error: e,
                    onRetry:
                        () => ref.invalidate(personDetailProvider(widget.id)),
                  ),
              data:
                  (p) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(personDetailProvider(widget.id));
                      try {
                        await ref.read(personDetailProvider(widget.id).future);
                      } catch (_) {}
                    },
                    child: _body(p, l),
                  ),
            ),
          ),
          if (ads) const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }

  Widget _body(PersonDetail p, L10n l) {
    final repo = ref.watch(repoProvider);
    final profiles = p.images.profiles;
    final followed = ref.watch(isFollowedProvider(p.id)).valueOrNull ?? false;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _hero(p, repo, l)),
        SliverToBoxAdapter(child: _followButton(p, followed, l)),
        if (p.biography.trim().isNotEmpty)
          SliverToBoxAdapter(child: _bio(p, l)),
        SliverToBoxAdapter(child: _personalInfo(p, l)),
        if (profiles.isNotEmpty)
          SliverToBoxAdapter(child: _photoStrip(profiles, repo, l)),
        if (p.combinedCredits.isNotEmpty)
          SliverToBoxAdapter(child: _credits(p, l)),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _hero(PersonDetail p, TmdbRepo repo, L10n l) {
    final scheme = Theme.of(context).colorScheme;
    final age = _ageLabel(p);
    final facts = <String>[
      if (p.knownForDepartment.isNotEmpty) p.knownForDepartment,
      if (p.placeOfBirth.isNotEmpty) p.placeOfBirth,
      if (age.isNotEmpty) '${l.t('Yaş', 'Age')}: $age',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 118,
              height: 170,
              child: RemoteImage(url: repo.profile(p.profilePath, large: true)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                for (final f in facts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _followButton(PersonDetail p, bool followed, L10n l) {
    final label = Text(
      followed ? l.t('Takiptesin', 'Following') : l.t('Takip et', 'Follow'),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child:
          followed
              ? OutlinedButton.icon(
                onPressed: () => _toggleFollow(p),
                icon: const Icon(Icons.person_remove_rounded, size: 19),
                label: label,
              )
              : FilledButton.icon(
                onPressed: () => _toggleFollow(p),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: label,
              ),
    );
  }

  Widget _bio(PersonDetail p, L10n l) {
    final scheme = Theme.of(context).colorScheme;
    final full = p.biography.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(l.overview),
          Text(
            full,
            maxLines: _bioExpanded ? null : 6,
            overflow: _bioExpanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (full.length > 380)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _bioExpanded = !_bioExpanded),
                child: Text(_bioExpanded ? l.readLess : l.readMore),
              ),
            ),
        ],
      ),
    );
  }

  static String _shortAka(String a) {
    final open = a.lastIndexOf('(');
    final close = a.lastIndexOf(')');
    if (open > 0 && close > open) return a.substring(open + 1, close).trim();
    return a;
  }

  Widget _personalInfo(PersonDetail p, L10n l) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      if (p.birthday != null && p.birthday!.isNotEmpty)
        (l.birthday, formatDate(p.birthday, pattern: 'd MMMM yyyy')),
      if (p.deathday != null && p.deathday!.isNotEmpty)
        (l.deathday, formatDate(p.deathday, pattern: 'd MMMM yyyy')),
      if (p.placeOfBirth.isNotEmpty) (l.birthplace, p.placeOfBirth),
    ];
    final links = <(String, String)>[
      for (final s in p.externalIds.socialLinks) s,
      if (p.homepage.isNotEmpty && p.externalIds.homepage.isEmpty)
        (l.t('Web sitesi', 'Website'), p.homepage),
    ];
    if (rows.isEmpty && links.isEmpty && p.alsoKnownAs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.personalInfo,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      children: [
                        TextSpan(
                          text: '${r.$1}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: r.$2,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              if (p.alsoKnownAs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l.alsoKnownAs,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in p.alsoKnownAs)
                      Chip(label: Text(_shortAka(a))),
                  ],
                ),
              ],
              if (links.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l.externalLinks,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final link in links)
                      ActionChip(
                        avatar: Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: scheme.primary,
                        ),
                        label: Text(link.$1),
                        onPressed: () => _launch(context, ref, link.$2),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoStrip(List<ImageInfo> profiles, TmdbRepo repo, L10n l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l.photos),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final img = profiles[i];
              return GestureDetector(
                onTap:
                    () => Nav.push(
                      context,
                      _PersonViewer(images: profiles, initial: i),
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    height: 132,
                    child: RemoteImage(
                      url: repo.image(img.filePath, size: 'w185'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _credits(PersonDetail p, L10n l) {
    final movies =
        p.combinedCredits.where((c) => c.mediaType == MediaType.movie).toList();
    final series =
        p.combinedCredits.where((c) => c.mediaType == MediaType.tv).toList();
    final selected = _showMovies ? movies : series;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(l.credits),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('${l.movies} (${movies.length})'),
                  selected: _showMovies,
                  onSelected:
                      movies.isEmpty
                          ? null
                          : ((_) => setState(() => _showMovies = true)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('${l.series} (${series.length})'),
                  selected: !_showMovies,
                  onSelected:
                      series.isEmpty
                          ? null
                          : ((_) => setState(() => _showMovies = false)),
                ),
              ],
            ),
          ),
          if (selected.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                l.emptyTitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final row in _groupedByYear(selected, l)) row,
        ],
      ),
    );
  }

  List<Widget> _groupedByYear(List<MediaSummary> items, L10n l) {
    final byYear = <String, List<MediaSummary>>{};
    for (final c in items) {
      byYear.putIfAbsent(c.year.isEmpty ? '?' : c.year, () => []).add(c);
    }
    final years =
        byYear.keys.toList()..sort((a, b) {
          if (a == b) return 0;
          if (a == '?') return 1;
          if (b == '?') return -1;
          return b.compareTo(a);
        });
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final y in years) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            y == '?' ? l.t('Diğer', 'Other') : y,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ),
        for (final c in byYear[y]!) _CreditRow(item: c),
      ],
    ];
  }
}

class _CreditRow extends ConsumerWidget {
  final MediaSummary item;
  const _CreditRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      if (item.year.isNotEmpty) item.year,
      if (item.characters.isNotEmpty) item.characters.join(', '),
    ];
    return InkWell(
      onTap: () => context.openMedia(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 60,
                child: RemoteImage(url: repo.poster(item.posterPath)),
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      parts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.voteAverage != null && item.voteAverage! > 0) ...[
              const SizedBox(width: 8),
              ScoreBadge(value: item.voteAverage!, size: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonViewer extends ConsumerStatefulWidget {
  final List<ImageInfo> images;
  final int initial;
  const _PersonViewer({required this.images, required this.initial});

  @override
  ConsumerState<_PersonViewer> createState() => _PersonViewerState();
}

class _PersonViewerState extends ConsumerState<_PersonViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initial,
  );
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final l = ref.watch(l10nProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final img = widget.images[i];
              return Center(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: RemoteImage(
                    url: repo.image(img.filePath, size: 'original'),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Nav.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: l.close,
                  ),
                  const Spacer(),
                  Text(
                    '${_page + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonShimmer extends StatelessWidget {
  const _PersonShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: const [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 118, height: 170),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 18),
                  SizedBox(height: 10),
                  ShimmerBox(width: 120, height: 13),
                  SizedBox(height: 8),
                  ShimmerBox(width: 160, height: 13),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        ShimmerBox(height: 44, radius: BorderRadius.all(Radius.circular(14))),
        SizedBox(height: 20),
        ShimmerBox(height: 14),
        SizedBox(height: 8),
        ShimmerBox(height: 14),
        SizedBox(height: 8),
        ShimmerBox(height: 14),
        SizedBox(height: 20),
        ShimmerBox(height: 130, radius: BorderRadius.all(Radius.circular(16))),
      ],
    );
  }
}
