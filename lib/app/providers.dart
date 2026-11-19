import 'dart:convert';

import 'package:flutter/material.dart'
    show WidgetsBinding, Brightness, ThemeData, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/config_channel.dart';
import 'config/secrets.dart';
import 'l10n/l10n.dart';
import 'state/discover_filters.dart';
import 'theme/app_theme.dart';
import '../data/api/tmdb_api.dart';
import '../data/local/local_store.dart';
import '../data/models/tmdb_models.dart';
import '../features/settings/settings_controller.dart';

/// Uygulamanın tüm durum sağlayıcıları tek yerde.
///
/// Ekranlar yalnızca bu provider'ları tüketir; API ve yerel depolama
/// detayları burada soyutlanır. Ayarlar değişince (`_localeKey`) API
/// üzerinden gelen tüm veriler otomatik yenilenir.

// ─────────────────────────── TEMEL ───────────────────────────

final apiProvider = Provider<TmdbApi>((ref) => TmdbApi.instance);

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final l10nProvider = Provider<L10n>((ref) => L10n(ref.watch(settingsProvider).languageCode));

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeModeFlutter;
});

final themeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  final dark = mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
  return dark ? AppTheme.dark() : AppTheme.light();
});

final brightnessProvider = Provider<Brightness>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == ThemeMode.light) return Brightness.light;
  if (mode == ThemeMode.dark) return Brightness.dark;
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
});

/// Dil/bölge/yetişkin filtresi değiştiğinde tüm veri yeniden çekilir.
final localeKeyProvider = Provider<String>((ref) {
  final s = ref.watch(settingsProvider);
  return '${s.contentLanguage}|${s.region}|${s.showAdult}';
});

/// Ayarları API istemcisine yansıtan sarmalayıcı.
final repoProvider = Provider<TmdbRepo>((ref) {
  final api = ref.watch(apiProvider);
  final s = ref.watch(settingsProvider);
  api.language = s.contentLanguage;
  api.region = s.region;
  return TmdbRepo(api, ref.watch(localStoreProvider), ref.watch(localeKeyProvider));
});

class TmdbRepo {
  final TmdbApi api;
  final LocalStore store;
  final String localeKey;
  TmdbRepo(this.api, this.store, this.localeKey);

  bool get showAdult => localeKey.endsWith('|true');

  /// Çevrimdışı çalışabilmesi için liste yanıtlarını diske yazar.
  Future<PagedResult<MediaSummary>> _mediaCached(
    String key,
    Future<PagedResult<MediaSummary>> Function() fetch,
  ) async {
    try {
      final raw = await fetch();
      await store.cacheJson(
          key, jsonEncode(raw.results.map((e) => e.toJson()).toList()));
      return raw;
    } on TmdbException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await store.readCache(key, maxAge: const Duration(days: 30));
      if (cached == null) rethrow;
      final list = (jsonDecode(cached) as List).whereType<Map<String, dynamic>>();
      return PagedResult(
        page: 1,
        totalPages: 1,
        totalResults: list.length,
        results: list.map((m) => MediaSummary.fromJson(m)).toList(),
      );
    }
  }

  Future<PagedResult<MediaSummary>> trending(MediaType type, String window, int page) =>
      _mediaCached(
          'trending|$localeKey|${type.apiPath}|$window|$page',
          () => api.trending(mediaType: type, window: window, page: page));

  Future<PagedResult<MediaSummary>> section(String path, MediaType type, {int page = 1}) =>
      _mediaCached('section|$localeKey|$path|${type.apiPath}|$page', () {
        return switch (path) {
          'now_playing' => api.nowPlaying(page: page),
          'upcoming' => api.upcoming(page: page),
          'popular' => api.popular(mediaType: type, page: page),
          'top_rated' => api.topRated(mediaType: type, page: page),
          'tv_airing' => api.popular(mediaType: MediaType.tv, page: page),
          _ => api.trending(mediaType: type, page: page),
        };
      });

  Future<PagedResult<MediaSummary>> discover(DiscoverFilters f, {int page = 1}) =>
      api.discover(
        mediaType: f.mediaType,
        page: page,
        withGenres: f.genres,
        withGenresLogic: f.genresMatchAll ? 'AND' : null,
        sortBy: f.sortBy,
        voteCountGte: f.minVoteCount,
        voteAverageGte: f.minVoteAverage,
        certLte: f.certification,
        certCountry:
            f.certification != null ? (f.certificationCountry ?? api.region) : null,
        year: f.mediaType == MediaType.movie ? f.year : null,
        withOriginalYear: f.mediaType == MediaType.tv ? f.year : null,
        originalLanguage: f.originalLanguage,
        withWatchProviders: f.watchProvider,
        withWatchMonetizationTypes: f.monetizationType,
        runtimeGte: f.minRuntime,
        runtimeLte: f.maxRuntime,
        withPeople: f.people,
        withCompanies: f.companies,
        withNetworks: f.networks,
        withKeywords: f.keywords,
        releaseDateGte: f.releaseFrom,
        releaseDateLte: f.releaseTo,
        includeAdult: showAdult,
      );

  Future<PagedResult<MediaSummary>> search(String q, String? type, int page) {
    return switch (type) {
      'movie' => api.searchMovies(q, page: page),
      'tv' => api.searchTv(q, page: page),
      'person' => api.searchPeople(q, page: page),
      'list' => api.searchLists(q, page: page),
      _ => api.searchMulti(q, page: page, includeAdult: showAdult),
    };
  }

  String image(String? path, {String size = 'w500'}) => api.image(path, size: size);
  String poster(String? p, {bool large = false}) => api.poster(p, large: large);
  String backdrop(String? p, {bool large = false}) => api.backdrop(p, large: large);
  String profile(String? p, {bool large = false}) => api.profile(p, large: large);
}

// ─────────────────────────── REFERANS VERİ ───────────────────────────

final movieGenresProvider = FutureProvider<GenreList>((ref) {
  ref.watch(localeKeyProvider);
  return ref.watch(repoProvider).api.genres(MediaType.movie);
});

final tvGenresProvider = FutureProvider<GenreList>((ref) {
  ref.watch(localeKeyProvider);
  return ref.watch(repoProvider).api.genres(MediaType.tv);
});

final genresProvider = FutureProvider.autoDispose
    .family<GenreList, MediaType>((ref, type) {
  ref.watch(localeKeyProvider);
  return ref.watch(repoProvider).api.genres(type);
});

final providerCatalogProvider = FutureProvider.family<WatchProviderCatalog, String>(
    (ref, country) => ref.watch(repoProvider).api.providers(watchRegion: country));

final countriesProvider =
    FutureProvider<List<CountryInfo>>((ref) => ref.watch(repoProvider).api.alternativeCountries());

// ─────────────────────────── ANA SAYFA ───────────────────────────

final trendingProvider = FutureProvider.autoDispose
    .family<List<MediaSummary>, (MediaType, String)>((ref, key) async {
  final res = await ref.watch(repoProvider).trending(key.$1, key.$2, 1);
  return res.results;
});

final homeSectionProvider = FutureProvider.autoDispose
    .family<PagedResult<MediaSummary>, (String, MediaType)>((ref, key) =>
        ref.watch(repoProvider).section(key.$1, key.$2));

final releaseCalendarProvider = FutureProvider.autoDispose
    .family<List<MediaSummary>, (String, String)>((ref, range) async {
  final res = await ref.watch(repoProvider).api.releases(
        startDate: range.$1,
        endDate: range.$2,
        region: ref.watch(settingsProvider).region,
      );
  return res.results;
});

// ─────────────────────────── SAYFALAMA ───────────────────────────

class MediaPageState {
  final List<MediaSummary> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? error;
  const MediaPageState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.error,
  });

  MediaPageState copyWith({
    List<MediaSummary>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? error,
  }) =>
      MediaPageState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );
}

/// Sayfalanan listeler için ortak taban (argümanlı aile sağlayıcıları).
abstract class PagedFamilyNotifier<T>
    extends AutoDisposeFamilyAsyncNotifier<MediaPageState, T> {
  Future<PagedResult<MediaSummary>> fetchPage(int page, T arg);

  @override
  Future<MediaPageState> build(T arg) async {
    final first = await fetchPage(1, arg);
    return MediaPageState(items: first.results, page: first.page, hasMore: first.hasMore);
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final next = await fetchPage(cur.page + 1, arg);
      final merged = [...cur.items, ...next.results];
      state = AsyncData(MediaPageState(
        items: merged,
        page: next.page,
        hasMore: next.hasMore && merged.length > cur.items.length,
      ));
    } catch (e) {
      state = AsyncData(cur.copyWith(loadingMore: false, hasMore: false, error: '$e'));
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await fetchPage(1, arg);
      return MediaPageState(items: r.results, page: r.page, hasMore: r.hasMore);
    });
  }
}

/// Sayfalanan listeler için ortak taban (argümansız sağlayıcılar).
abstract class PagedNotifier extends AutoDisposeAsyncNotifier<MediaPageState> {
  Future<PagedResult<MediaSummary>> fetchPage(int page);

  @override
  Future<MediaPageState> build() async {
    final first = await fetchPage(1);
    return MediaPageState(items: first.results, page: first.page, hasMore: first.hasMore);
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final next = await fetchPage(cur.page + 1);
      final merged = [...cur.items, ...next.results];
      state = AsyncData(MediaPageState(
        items: merged,
        page: next.page,
        hasMore: next.hasMore && merged.length > cur.items.length,
      ));
    } catch (e) {
      state = AsyncData(cur.copyWith(loadingMore: false, hasMore: false, error: '$e'));
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await fetchPage(1);
      return MediaPageState(items: r.results, page: r.page, hasMore: r.hasMore);
    });
  }
}

class SearchNotifier extends PagedFamilyNotifier<(String, String?)> {
  @override
  Future<PagedResult<MediaSummary>> fetchPage(int page, (String, String?) arg) =>
      ref.read(repoProvider).search(arg.$1, arg.$2, page);
}

final searchResultsProvider = AutoDisposeAsyncNotifierProviderFamily<SearchNotifier,
    MediaPageState, (String, String?)>(SearchNotifier.new);

/// Discover ekranı: filtreler değişince otomatik yeniden yüklenir.
class DiscoverNotifier extends PagedNotifier {
  @override
  Future<PagedResult<MediaSummary>> fetchPage(int page) {
    final filters = ref.watch(discoverFiltersProvider);
    return ref.read(repoProvider).discover(filters, page: page);
  }
}

final discoverResultsProvider =
    AutoDisposeAsyncNotifierProvider<DiscoverNotifier, MediaPageState>(DiscoverNotifier.new);

class RelatedMediaNotifier extends PagedFamilyNotifier<(MediaType, int, String)> {
  @override
  Future<PagedResult<MediaSummary>> fetchPage(int page, (MediaType, int, String) arg) {
    final api = ref.read(repoProvider).api;
    return switch (arg.$3) {
      'similar' => api.similar(arg.$1, arg.$2, page: page),
      'recommendations' => api.recommendations(arg.$1, arg.$2, page: page),
      'keyword' => api.keywordMovies(arg.$2, page: page),
      'company' => api.companyMovies(arg.$2, page: page),
      'network' => api.networkTv(arg.$2, page: page),
      'list' => api.lists(arg.$2, page: page).then((r) => PagedResult(
            page: r.page,
            totalPages: r.totalPages,
            totalResults: r.totalResults,
            results: r.results.map(_fromListItem).toList(),
          )),
      _ => api.trending(mediaType: arg.$1, page: page),
    };
  }

  static MediaSummary _fromListItem(MovieListItem l) => MediaSummary(
        id: l.id,
        mediaType: MediaType.movie,
        title: l.name,
        originalTitle: l.username,
        posterPath: l.posterPath,
        overview: l.description,
        voteCount: l.itemCount,
      );
}

final relatedMediaProvider = AutoDisposeAsyncNotifierProviderFamily<RelatedMediaNotifier,
    MediaPageState, (MediaType, int, String)>(RelatedMediaNotifier.new);

class PopularPeopleNotifier extends PagedNotifier {
  @override
  Future<PagedResult<MediaSummary>> fetchPage(int page) =>
      ref.read(repoProvider).api.popularPerson(page);
}

final popularPeopleProvider =
    AutoDisposeAsyncNotifierProvider<PopularPeopleNotifier, MediaPageState>(
        PopularPeopleNotifier.new);

class Top250Notifier extends PagedNotifier {
  @override
  Future<PagedResult<MediaSummary>> fetchPage(int page) =>
      ref.read(repoProvider).api.discover(
            mediaType: MediaType.movie,
            page: page,
            sortBy: 'vote_average.desc',
            voteCountGte: 300,
            includeAdult: ref.read(settingsProvider).showAdult,
          );
}

final top250Provider =
    AutoDisposeAsyncNotifierProvider<Top250Notifier, MediaPageState>(Top250Notifier.new);

// ─────────────────────────── DETAY ───────────────────────────

final mediaDetailProvider = FutureProvider.autoDispose
    .family<MediaDetail, (MediaType, int)>((ref, key) {
  ref.watch(localeKeyProvider);
  return ref.watch(repoProvider).api.mediaDetail(key.$2, key.$1);
});

final personDetailProvider = FutureProvider.autoDispose.family<PersonDetail, int>((ref, id) {
  ref.watch(localeKeyProvider);
  return ref.watch(repoProvider).api.personDetail(id);
});

final seasonProvider = FutureProvider.autoDispose
    .family<SeasonDetail, (int, int)>(
        (ref, key) => ref.watch(repoProvider).api.seasonDetail(key.$1, key.$2));

final episodeProvider = FutureProvider.autoDispose
    .family<EpisodeDetail, (int, int, int)>((ref, key) =>
        ref.watch(repoProvider).api.episodeDetail(key.$1, key.$2, key.$3));

final collectionProvider = FutureProvider.autoDispose
    .family<MediaDetail, int>((ref, id) async {
  final r = await ref.watch(repoProvider).api.collectionDetail(id);
  return r;
});

final companyProvider = FutureProvider.autoDispose
    .family<Company, int>((ref, id) => ref.watch(repoProvider).api.companyDetail(id));

final reviewsProvider = FutureProvider.autoDispose
    .family<List<ReviewItem>, (MediaType, int)>((ref, key) async {
  final r = await ref.watch(repoProvider).api.reviews(key.$1, key.$2);
  return r.results;
});

final imagesProvider = FutureProvider.autoDispose
    .family<ImageCollection, (MediaType, int)>((ref, key) =>
        ref.watch(repoProvider).api.images(key.$1, key.$2));

// ─────────────────────────── KULLANICI LİSTELERİ ───────────────────────────

class SavedListState {
  final Map<String, List<SavedItem>> byStatus;
  final bool ready;
  const SavedListState({this.byStatus = const {}, this.ready = false});

  List<SavedItem> of(String status) => byStatus[status] ?? const [];
  int countOf(String status) => of(status).length;
  int get total => byStatus.values.fold(0, (a, b) => a + b.length);
}

class SavedListNotifier extends AutoDisposeNotifier<SavedListState> {
  @override
  SavedListState build() {
    Future.microtask(_refresh);
    return const SavedListState();
  }

  Future<void> _refresh() async {
    final all = await ref.read(localStoreProvider).allSaved();
    final grouped = <String, List<SavedItem>>{};
    for (final item in all) {
      grouped.putIfAbsent(item.status, () => []).add(item);
    }
    state = SavedListState(byStatus: grouped, ready: true);
  }

  Future<bool> toggle(int id, MediaType type, String status, MediaSummary summary) async {
    final store = ref.read(localStoreProvider);
    final current = await store.statusOf(id, type.apiPath);
    if (current == status) {
      await store.removeStatus(id, type.apiPath, status);
    } else {
      await store.upsertSaved(summary, status: status);
    }
    await _refresh();
    return (await store.statusOf(id, type.apiPath)) == status;
  }

  Future<void> setStatus(int id, MediaType type, String status, MediaSummary summary) async {
    await ref.read(localStoreProvider).upsertSaved(summary, status: status);
    await _refresh();
  }

  Future<void> remove(int id, MediaType type) async {
    await ref.read(localStoreProvider).removeSaved(id, type.apiPath);
    await _refresh();
  }

  Future<void> rate(int id, MediaType type, MediaSummary summary, double rating) async {
    final store = ref.read(localStoreProvider);
    final current = await store.statusOf(id, type.apiPath);
    if (current == null || current.isEmpty) {
      await store.upsertSaved(summary, status: 'rated');
    }
    await store.setRating(id, type.apiPath, rating);
    await _refresh();
  }

  Future<void> setNote(int id, MediaType type, String body) async {
    await ref.read(localStoreProvider).setNote(id, type.apiPath, body);
    await _refresh();
  }

  Future<void> clearStatus(String status) async {
    for (final item in state.of(status)) {
      await ref.read(localStoreProvider).removeSaved(item.mediaId, item.mediaType.apiPath);
    }
    await _refresh();
  }

  Future<void> reload() => _refresh();
}

final savedListProvider =
    AutoDisposeNotifierProvider<SavedListNotifier, SavedListState>(SavedListNotifier.new);

final savedStatusProvider = FutureProvider.autoDispose
    .family<String?, (MediaType, int)>((ref, key) async {
  ref.watch(savedListProvider);
  return ref.read(localStoreProvider).statusOf(key.$2, key.$1.apiPath);
});

final savedRatingProvider = FutureProvider.autoDispose
    .family<double?, (MediaType, int)>((ref, key) async {
  ref.watch(savedListProvider);
  return ref.read(localStoreProvider).ratingOf(key.$2, key.$1.apiPath);
});

final noteProvider = FutureProvider.autoDispose
    .family<String?, (MediaType, int)>((ref, key) async {
  ref.watch(savedListProvider);
  return ref.read(localStoreProvider).noteFor(key.$2, key.$1.apiPath);
});

final searchHistoryTickProvider = StateProvider<int>((ref) => 0);

final searchHistoryProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  ref.watch(searchHistoryTickProvider);
  return ref.read(localStoreProvider).searchHistory();
});

final followTickProvider = StateProvider<int>((ref) => 0);

final followedPeopleProvider = FutureProvider.autoDispose<List<SavedPerson>>((ref) async {
  ref.watch(followTickProvider);
  return ref.read(localStoreProvider).followedPeople();
});

final isFollowedProvider = FutureProvider.autoDispose
    .family<bool, int>((ref, id) async {
  ref.watch(followTickProvider);
  return ref.read(localStoreProvider).isFollowed(id);
});

// ─────────────────────────── YAPILANDIRMA DURUMU ───────────────────────────

final appStatusProvider = Provider<AppStatus>((ref) {
  final ready = ref.watch(apiReadyProvider);
  return AppStatus(ready: ready, hasKey: Secrets.hasApiKey);
});

final apiReadyProvider = StateProvider<bool>((ref) => false);

class AppStatus {
  final bool ready;
  final bool hasKey;
  const AppStatus({required this.ready, required this.hasKey});

  bool get usable => ready && hasKey;
}

/// Uygulama açılışındaki hazırlık: veritabanı + API yapılandırması.
final bootstrapProvider = FutureProvider<bool>((ref) async {
  await LocalStore.instance.open();
  await ConfigChannel.loadAll();
  final key = ConfigChannel.tmdbApiKey(Secrets.devApiKey);
  Secrets.apply(
    apiKey: key,
    banner: ConfigChannel.value('ADMOB_BANNER_ID'),
    native: ConfigChannel.value('ADMOB_NATIVE_ID'),
    interstitial: ConfigChannel.value('ADMOB_INTERSTITIAL_ID'),
  );
  await TmdbApi.instance.configure(
    key,
    region: ref.read(settingsProvider).region,
  );
  final ready = TmdbApi.instance.isReady;
  ref.read(apiReadyProvider.notifier).state = ready;
  return ready;
});
