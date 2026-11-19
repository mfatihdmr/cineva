import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/state/discover_filters.dart';
import '../../data/models/tmdb_models.dart';
import '../settings/settings_controller.dart';

typedef _Hit = (int, String);

const _unset = Object();

DiscoverFilters _cp(
  DiscoverFilters s, {
  MediaType? mediaType,
  List<int>? genres,
  bool? genresMatchAll,
  String? sortBy,
  Object? minVoteCount = _unset,
  Object? minVoteAverage = _unset,
  Object? certification = _unset,
  Object? certificationCountry = _unset,
  Object? year = _unset,
  Object? originalLanguage = _unset,
  Object? watchProvider = _unset,
  Object? monetizationType = _unset,
  Object? minRuntime = _unset,
  Object? maxRuntime = _unset,
  List<int>? people,
  List<int>? companies,
  List<int>? networks,
  List<int>? keywords,
  Object? releaseFrom = _unset,
  Object? releaseTo = _unset,
}) =>
    DiscoverFilters(
      mediaType: mediaType ?? s.mediaType,
      genres: genres ?? s.genres,
      genresMatchAll: genresMatchAll ?? s.genresMatchAll,
      sortBy: sortBy ?? s.sortBy,
      minVoteCount: minVoteCount == _unset ? s.minVoteCount : minVoteCount as int?,
      minVoteAverage:
          minVoteAverage == _unset ? s.minVoteAverage : minVoteAverage as double?,
      certification:
          certification == _unset ? s.certification : certification as String?,
      certificationCountry: certificationCountry == _unset
          ? s.certificationCountry
          : certificationCountry as String?,
      year: year == _unset ? s.year : year as int?,
      originalLanguage: originalLanguage == _unset
          ? s.originalLanguage
          : originalLanguage as String?,
      watchProvider:
          watchProvider == _unset ? s.watchProvider : watchProvider as String?,
      monetizationType: monetizationType == _unset
          ? s.monetizationType
          : monetizationType as String?,
      minRuntime: minRuntime == _unset ? s.minRuntime : minRuntime as int?,
      maxRuntime: maxRuntime == _unset ? s.maxRuntime : maxRuntime as int?,
      people: people ?? s.people,
      companies: companies ?? s.companies,
      networks: networks ?? s.networks,
      keywords: keywords ?? s.keywords,
      releaseFrom:
          releaseFrom == _unset ? s.releaseFrom : releaseFrom as String?,
      releaseTo: releaseTo == _unset ? s.releaseTo : releaseTo as String?,
    );

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: const FilterSheet(),
          ),
        ),
      );

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  final Map<int, String> _peopleNames = {};
  final Map<int, String> _companyNames = {};
  final Map<int, String> _keywordNames = {};

  void _set(DiscoverFilters next) =>
      ref.read(discoverFiltersProvider.notifier).set(next);

  void _addId(String kind, int id, String name) {
    final f = ref.read(discoverFiltersProvider);
    if (kind == 'people') {
      if (f.people.contains(id)) return;
      _peopleNames[id] = name;
      _set(_cp(f, people: [...f.people, id]));
    } else if (kind == 'companies') {
      if (f.companies.contains(id)) return;
      _companyNames[id] = name;
      _set(_cp(f, companies: [...f.companies, id]));
    } else {
      if (f.keywords.contains(id)) return;
      _keywordNames[id] = name;
      _set(_cp(f, keywords: [...f.keywords, id]));
    }
    setState(() {});
  }

  void _removeId(String kind, int id) {
    final f = ref.read(discoverFiltersProvider);
    if (kind == 'people') {
      _set(_cp(f, people: [...f.people]..remove(id)));
    } else if (kind == 'companies') {
      _set(_cp(f, companies: [...f.companies]..remove(id)));
    } else {
      _set(_cp(f, keywords: [...f.keywords]..remove(id)));
    }
    setState(() {});
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final f = ref.watch(discoverFiltersProvider);
    final region = ref.watch(settingsProvider).region;
    final scheme = Theme.of(context).colorScheme;
    final api = ref.read(repoProvider).api;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        );

    Widget chip(
      String label, {
      required bool selected,
      required VoidCallback onTap,
      Widget? leading,
    }) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          avatar: leading,
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
              fontSize: 12.5,
              color: selected ? scheme.onSecondaryContainer : scheme.onSurface),
        );

    Widget chips(List<Widget> items) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 7, runSpacing: 7, children: items),
        );

    final genreList =
        ref.watch(genresProvider(f.mediaType)).valueOrNull?.genres ?? const <Genre>[];
    final catalog = ref.watch(providerCatalogProvider(region)).valueOrNull;

    final sortKeys = <String>[
      'popularity.desc',
      'vote_average.desc',
      'vote_count.desc',
      if (f.mediaType == MediaType.movie) 'revenue.desc',
      if (f.mediaType == MediaType.movie) 'primary_release_date.desc',
      if (f.mediaType == MediaType.movie) 'release_date.desc',
      if (f.mediaType == MediaType.tv) 'first_air_date.desc',
      'original_title.asc',
    ];

    const langs = ['tr', 'en', 'es', 'fr', 'de', 'it', 'ja', 'ko', 'ru', 'hi'];
    const certs = ['P', 'PG', '13', '16', '18'];
    final currentYear = DateTime.now().year;
    final years = [for (var y = currentYear; y >= 1900; y--) y];

    final runtimeLower = (f.minRuntime ?? 0).toDouble();
    final runtimeUpper = (f.maxRuntime ?? 300).toDouble();

    final search = <String, Future<List<_Hit>> Function(String)>{
      'people': (q) async =>
          (await api.searchPeople(q)).results.map((m) => (m.id, m.displayTitle)).toList(),
      'companies': (q) async =>
          (await api.searchCompanies(q)).results.map((c) => (c.id, c.name)).toList(),
      'keywords': (q) async =>
          (await api.searchKeywords(q)).results.map((k) => (k.id, k.name)).toList(),
    };

    Widget selChips(String kind, List<int> ids, Map<int, String> names) {
      if (ids.isEmpty) return const SizedBox.shrink();
      return chips([
        for (final id in ids)
          Chip(
            label: Text(names[id] ?? '#$id',
                style: const TextStyle(fontSize: 12.5)),
            visualDensity: VisualDensity.compact,
            onDeleted: () => _removeId(kind, id),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
          ),
      ]);
    }

    Widget dateButton(String label, String? value, bool isFrom) => Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final init = value != null
                  ? (DateTime.tryParse(value) ?? DateTime.now())
                  : DateTime.now();
              final d = await _pickDate(init);
              if (d == null) return;
              final iso =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              if (isFrom) {
                _set(_cp(f, releaseFrom: iso));
              } else {
                _set(_cp(f, releaseTo: iso));
              }
            },
            icon: const Icon(Icons.event_rounded, size: 17),
            label: Text(value ?? label,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l.filters,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            children: [
              header(l.t('Tür', 'Type')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<MediaType>(
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                        value: MediaType.movie, label: Text(MediaType.movie.label)),
                    ButtonSegment(value: MediaType.tv, label: Text(MediaType.tv.label)),
                  ],
                  selected: {f.mediaType},
                  showSelectedIcon: false,
                  onSelectionChanged: (sel) => ref
                      .read(discoverFiltersProvider.notifier)
                      .toggleType(sel.first),
                ),
              ),
              header(l.sort),
              chips([
                for (final key in sortKeys)
                  chip(l.sortByLabel(key),
                      selected: f.sortBy == key,
                      onTap: () =>
                          ref.read(discoverFiltersProvider.notifier).setSort(key)),
              ]),
              header(l.genre),
              chips([
                chip(l.t('Hepsi', 'All'),
                    selected: f.genresMatchAll,
                    onTap: () => _set(_cp(f, genresMatchAll: true))),
                chip(l.t('Biri', 'Any'),
                    selected: !f.genresMatchAll,
                    onTap: () => _set(_cp(f, genresMatchAll: false))),
              ]),
              if (genreList.isNotEmpty)
                const SizedBox(height: 7)
              else
                const SizedBox(height: 4),
              if (genreList.isNotEmpty)
                chips([
                  for (final g in genreList)
                    chip(g.name,
                        selected: f.genres.contains(g.id),
                        onTap: () => ref
                            .read(discoverFiltersProvider.notifier)
                            .toggleGenre(g.id)),
                ]),
              header(l.minRating),
              _sliderRow(
                context,
                l.minRating,
                value: f.minVoteAverage ?? 0,
                max: 10,
                divisions: 20,
                labelOf: (v) => v <= 0
                    ? l.anyValue
                    : '${v.toStringAsFixed(1)} ${l.t('ve üzeri', 'and up')}',
                onChanged: (v) =>
                    _set(_cp(f, minVoteAverage: v <= 0 ? null : (v * 2).roundToDouble() / 2)),
              ),
              header(l.minVotes),
              _sliderRow(
                context,
                l.minVotes,
                value: (f.minVoteCount ?? 0).toDouble(),
                max: 2000,
                divisions: 20,
                labelOf: (v) => v <= 0
                    ? l.anyValue
                    : '${v.round()} ${l.t('oy ve üzeri', 'votes+')}',
                onChanged: (v) =>
                    _set(_cp(f, minVoteCount: v <= 0 ? null : v.round())),
              ),
              header(l.ageFilter),
              chips([
                chip(l.anyValue,
                    selected: f.certification == null,
                    onTap: () => _set(_cp(f, certification: null))),
                for (final c in certs)
                  chip(c,
                      selected: f.certification == c,
                      onTap: () => _set(_cp(
                          f, certification: f.certification == c ? null : c))),
              ]),
              header(l.year),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<int?>(
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  value: f.year,
                  hint: Text(l.anyValue),
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l.anyValue,
                            style: const TextStyle(fontSize: 14))),
                    for (final y in years)
                      DropdownMenuItem<int?>(
                          value: y,
                          child: Text('$y',
                              style: const TextStyle(fontSize: 14))),
                  ],
                  onChanged: (v) => _set(_cp(f, year: v)),
                ),
              ),
              header(l.language),
              chips([
                chip(l.anyValue,
                    selected: f.originalLanguage == null,
                    onTap: () => _set(_cp(f, originalLanguage: null))),
                for (final code in langs)
                  chip(code.toUpperCase(),
                      selected: f.originalLanguage == code,
                      onTap: () => _set(_cp(
                          f,
                          originalLanguage:
                              f.originalLanguage == code ? null : code))),
              ]),
              if (catalog != null) ...[
                header(l.providerFilter),
                chips([
                  chip(l.anyValue,
                      selected: f.monetizationType == null,
                      onTap: () => _set(_cp(f, monetizationType: null))),
                  chip(l.streaming,
                      selected: f.monetizationType == 'flat',
                      onTap: () => _set(_cp(
                          f,
                          monetizationType:
                              f.monetizationType == 'flat' ? null : 'flat'))),
                  chip(l.rent,
                      selected: f.monetizationType == 'rent',
                      onTap: () => _set(_cp(
                          f,
                          monetizationType:
                              f.monetizationType == 'rent' ? null : 'rent'))),
                  chip(l.buy,
                      selected: f.monetizationType == 'buy',
                      onTap: () => _set(_cp(
                          f,
                          monetizationType:
                              f.monetizationType == 'buy' ? null : 'buy'))),
                ]),
                const SizedBox(height: 7),
                chips([
                  for (final p in catalog.allFor(region).take(24))
                    chip(
                      p.providerName,
                      selected: f.watchProvider == p.providerId.toString(),
                      leading: CircleAvatar(
                        radius: 11,
                        backgroundImage: NetworkImage(
                            api.image(p.logoPath, size: 'w92')),
                      ),
                      onTap: () => _set(_cp(
                          f,
                          watchProvider: f.watchProvider == p.providerId.toString()
                              ? null
                              : p.providerId.toString())),
                    ),
                ]),
              ],
              header('${l.minDuration} / ${l.maxDuration}'),
              _rangeRow(context, runtimeLower, runtimeUpper, (lo, up) {
                _set(_cp(
                  f,
                  minRuntime: lo > 0 ? lo.round() : null,
                  maxRuntime: up < 300 ? up.round() : null,
                ));
              }),
              header(l.personFilter),
              _IdSearchField(
                hint: l.t('Kişi ara…', 'Search people…'),
                search: search['people']!,
                onPick: (id, name) => _addId('people', id, name),
              ),
              selChips('people', f.people, _peopleNames),
              header(l.companyFilter),
              _IdSearchField(
                hint: l.t('Yapım şirketi ara…', 'Search company…'),
                search: search['companies']!,
                onPick: (id, name) => _addId('companies', id, name),
              ),
              selChips('companies', f.companies, _companyNames),
              header(l.keywordFilter),
              _IdSearchField(
                hint: l.t('Anahtar kelime ara…', 'Search keywords…'),
                search: search['keywords']!,
                onPick: (id, name) => _addId('keywords', id, name),
              ),
              selChips('keywords', f.keywords, _keywordNames),
              header(l.releaseRange),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    dateButton(l.from, f.releaseFrom, true),
                    const SizedBox(width: 8),
                    dateButton(l.to, f.releaseTo, false),
                  ],
                ),
              ),
              if (f.releaseFrom != null || f.releaseTo != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: TextButton(
                      onPressed: () =>
                          _set(_cp(f, releaseFrom: null, releaseTo: null)),
                      child: Text(l.anyValue),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(discoverFiltersProvider.notifier).clear(),
                    child: Text(l.reset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.apply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
    BuildContext context,
    String title, {
    required double value,
    required double max,
    required int divisions,
    required String Function(double) labelOf,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(labelOf(value),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
          ),
          Slider(
            value: value.clamp(0.0, max).toDouble(),
            max: max,
            divisions: divisions,
            label: labelOf(value),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _rangeRow(BuildContext context, double lo, double up,
      void Function(double, double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text('${lo.round()} - ${up.round()} dk',
              style: const TextStyle(fontSize: 12.5)),
          RangeSlider(
            min: 0,
            max: 300,
            divisions: 60,
            values: RangeValues(lo.clamp(0.0, 300.0).toDouble(),
                up.clamp(0.0, 300.0).toDouble()),
            onChanged: (v) => onChanged(v.start, v.end),
          ),
        ],
      ),
    );
  }
}

class _IdSearchField extends ConsumerStatefulWidget {
  const _IdSearchField({
    required this.hint,
    required this.search,
    required this.onPick,
  });

  final String hint;
  final Future<List<_Hit>> Function(String) search;
  final void Function(int id, String name) onPick;

  @override
  ConsumerState<_IdSearchField> createState() => _IdSearchFieldState();
}

class _IdSearchFieldState extends ConsumerState<_IdSearchField> {
  final TextEditingController _ctl = TextEditingController();
  Timer? _timer;
  List<_Hit> _res = const [];
  bool _busy = false;

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _timer?.cancel();
    final t = q.trim();
    if (t.length < 2) {
      setState(() {
        _res = const [];
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    _timer = Timer(const Duration(milliseconds: 450), () => _run(t));
  }

  Future<void> _run(String q) async {
    try {
      final r = await widget.search(q);
      if (mounted) {
        setState(() {
          _res = r;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _ctl,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (v) {
              final t = v.trim();
              if (t.length >= 2) {
                _timer?.cancel();
                _run(t);
              }
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
        ),
        if (_res.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final h in _res)
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: Text(h.$2, style: const TextStyle(fontSize: 12.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      widget.onPick(h.$1, h.$2);
                      _ctl.clear();
                      setState(() => _res = const []);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
