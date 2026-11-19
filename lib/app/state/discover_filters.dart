import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tmdb_models.dart';

/// Discover ekranının durum modeli.
class DiscoverFilters {
  final MediaType mediaType;
  final List<int> genres;
  final bool genresMatchAll;
  final String sortBy;
  final int? minVoteCount;
  final double? minVoteAverage;
  final String? certification;
  final String? certificationCountry;
  final int? year;
  final String? originalLanguage;
  final String? watchProvider;
  final String? monetizationType;
  final int? minRuntime;
  final int? maxRuntime;
  final List<int> people;
  final List<int> companies;
  final List<int> networks;
  final List<int> keywords;
  final String? releaseFrom;
  final String? releaseTo;

  const DiscoverFilters({
    this.mediaType = MediaType.movie,
    this.genres = const [],
    this.genresMatchAll = false,
    this.sortBy = 'popularity.desc',
    this.minVoteCount,
    this.minVoteAverage,
    this.certification,
    this.certificationCountry,
    this.year,
    this.originalLanguage,
    this.watchProvider,
    this.monetizationType,
    this.minRuntime,
    this.maxRuntime,
    this.people = const [],
    this.companies = const [],
    this.networks = const [],
    this.keywords = const [],
    this.releaseFrom,
    this.releaseTo,
  });

  bool get isDefault =>
      genres.isEmpty &&
      sortBy == 'popularity.desc' &&
      minVoteCount == null &&
      minVoteAverage == null &&
      certification == null &&
      year == null &&
      originalLanguage == null &&
      watchProvider == null &&
      minRuntime == null &&
      maxRuntime == null &&
      people.isEmpty &&
      companies.isEmpty &&
      networks.isEmpty &&
      keywords.isEmpty &&
      releaseFrom == null &&
      releaseTo == null;

  int get activeCount => [
        genres.isNotEmpty,
        minVoteCount != null,
        minVoteAverage != null,
        certification != null,
        year != null,
        originalLanguage != null,
        watchProvider != null,
        minRuntime != null,
        maxRuntime != null,
        people.isNotEmpty,
        companies.isNotEmpty,
        networks.isNotEmpty,
        keywords.isNotEmpty,
        releaseFrom != null,
      ].where((e) => e).length;

  DiscoverFilters copyWith({
    MediaType? mediaType,
    List<int>? genres,
    bool? genresMatchAll,
    String? sortBy,
    int? minVoteCount,
    double? minVoteAverage,
    String? certification,
    String? certificationCountry,
    int? year,
    String? originalLanguage,
    String? watchProvider,
    String? monetizationType,
    int? minRuntime,
    int? maxRuntime,
    List<int>? people,
    List<int>? companies,
    List<int>? networks,
    List<int>? keywords,
    String? releaseFrom,
    String? releaseTo,
  }) =>
      DiscoverFilters(
        mediaType: mediaType ?? this.mediaType,
        genres: genres ?? this.genres,
        genresMatchAll: genresMatchAll ?? this.genresMatchAll,
        sortBy: sortBy ?? this.sortBy,
        minVoteCount: minVoteCount ?? this.minVoteCount,
        minVoteAverage: minVoteAverage ?? this.minVoteAverage,
        certification: certification ?? this.certification,
        certificationCountry: certificationCountry ?? this.certificationCountry,
        year: year ?? this.year,
        originalLanguage: originalLanguage ?? this.originalLanguage,
        watchProvider: watchProvider ?? this.watchProvider,
        monetizationType: monetizationType ?? this.monetizationType,
        minRuntime: minRuntime ?? this.minRuntime,
        maxRuntime: maxRuntime ?? this.maxRuntime,
        people: people ?? this.people,
        companies: companies ?? this.companies,
        networks: networks ?? this.networks,
        keywords: keywords ?? this.keywords,
        releaseFrom: releaseFrom ?? this.releaseFrom,
        releaseTo: releaseTo ?? this.releaseTo,
      );

  /// `null` alanı temizlemek için: sentinel -1 kullanılır.
  DiscoverFilters cleared() => DiscoverFilters(mediaType: mediaType);

  Map<String, dynamic> toApiArgs({required bool includeAdult}) => {
        'mediaType': mediaType,
        'withGenres': genres,
        'withGenresLogic': genresMatchAll ? 'AND' : null,
        'sortBy': sortBy,
        'voteCountGte': minVoteCount,
        'voteAverageGte': minVoteAverage,
        'certCountry': certification != null ? (certificationCountry ?? 'TR') : null,
        'certLte': certification,
        'year': mediaType == MediaType.movie ? year : null,
        'withOriginalYear': mediaType == MediaType.tv ? year : null,
        'originalLanguage': originalLanguage,
        'withWatchProviders': watchProvider,
        'withWatchMonetizationTypes': monetizationType,
        'runtimeGte': minRuntime,
        'runtimeLte': maxRuntime,
        'withPeople': people,
        'withCompanies': companies,
        'withNetworks': networks,
        'withKeywords': keywords,
        'releaseDateGte': releaseFrom,
        'releaseDateLte': releaseTo,
        'includeAdult': includeAdult,
      };
}

/// Ekrandan bağımsız, tek örnekli filtre durumu.
final discoverFiltersProvider =
    NotifierProvider<DiscoverFiltersNotifier, DiscoverFilters>(
        DiscoverFiltersNotifier.new);

class DiscoverFiltersNotifier extends Notifier<DiscoverFilters> {
  @override
  DiscoverFilters build() => const DiscoverFilters();

  void set(DiscoverFilters value) => state = value;
  void clear() => state = state.cleared();
  void toggleType(MediaType t) => state = state.copyWith(mediaType: t);
  void toggleGenre(int id) {
    final list = [...state.genres];
    list.contains(id) ? list.remove(id) : list.add(id);
    state = state.copyWith(genres: list);
  }

  void setSort(String s) => state = state.copyWith(sortBy: s);
}
