/// TMDB v3 API veri modelleri.
library;

enum MediaType { movie, tv, person }

extension MediaTypeX on MediaType {
  String get apiPath => switch (this) {
        MediaType.movie => 'movie',
        MediaType.tv => 'tv',
        MediaType.person => 'person',
      };

  String get label => switch (this) {
        MediaType.movie => 'Film',
        MediaType.tv => 'Dizi',
        MediaType.person => 'Kişi',
      };

  static MediaType fromApi(String? value) => switch (value) {
        'tv' => MediaType.tv,
        'person' => MediaType.person,
        _ => MediaType.movie,
      };
}

int? _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : null);
double? _asDouble(dynamic v) => v is num ? v.toDouble() : null;
String? _asString(dynamic v) => v?.toString();
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
List<int> _ids(dynamic v) => v is List ? v.whereType<num>().map((e) => e.toInt()).toList() : const [];
dynamic _firstOf(dynamic v) => v is List && v.isNotEmpty ? v.first : v;

class Genre {
  final int id;
  final String name;
  const Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> j) =>
      Genre(id: _asInt(j['id']) ?? 0, name: _asString(j['name']) ?? '');
}

class GenreList {
  final List<Genre> genres;
  const GenreList(this.genres);

  factory GenreList.fromJson(Map<String, dynamic> j) =>
      GenreList(_maps(j['genres']).map(Genre.fromJson).toList());

  String nameOf(int id) => genres.firstWhere((g) => g.id == id, orElse: () => Genre(id: id, name: '')).name;
}

/// Film / dizi kartları ve listeleri için ortak özet model.
class MediaSummary {
  final int id;
  final MediaType mediaType;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double? voteAverage;
  final int voteCount;
  final double popularity;
  final bool adult;
  final String originalLanguage;
  final List<int> genreIds;
  final String? releaseDate;
  final List<String> characters;

  const MediaSummary({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.voteCount = 0,
    this.popularity = 0,
    this.adult = false,
    this.originalLanguage = '',
    this.genreIds = const [],
    this.releaseDate,
    this.characters = const [],
  });

  String get displayTitle => title.isNotEmpty ? title : originalTitle;
  String get year {
    final d = releaseDate;
    if (d == null || d.length < 4) return '';
    return d.substring(0, 4);
  }

  factory MediaSummary.fromJson(Map<String, dynamic> j, {String? fallbackType}) {
    final rawType = _asString(j['media_type']) ?? fallbackType ?? 'movie';
    final type = MediaTypeX.fromApi(rawType);
    final isPerson = type == MediaType.person;
    final title = isPerson
        ? (_asString(j['name']) ?? '')
        : (_asString(j['title']) ?? _asString(j['name']) ?? '');
    final original = isPerson
        ? (_asString(j['original_name']) ?? _asString(j['name']) ?? title)
        : (_asString(j['original_title']) ?? _asString(j['original_name']) ?? title);
    final chars = _maps(j['characters'])
        .map((c) => _asString(c['role']) ?? _asString(c['character']) ?? '')
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    return MediaSummary(
      id: _asInt(j['id']) ?? 0,
      mediaType: type,
      title: title,
      originalTitle: original,
      overview: _asString(j['overview']) ?? '',
      posterPath: _asString(j['poster_path'] ?? j['profile_path']),
      backdropPath: _asString(j['backdrop_path']),
      voteAverage: _asDouble(j['vote_average']),
      voteCount: _asInt(j['vote_count']) ?? 0,
      popularity: _asDouble(j['popularity']) ?? 0,
      adult: j['adult'] == true,
      originalLanguage: _asString(j['original_language']) ?? '',
      genreIds: _ids(j['genre_ids']),
      releaseDate: _asString(j['release_date'] ?? j['first_air_date']),
      characters: chars,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'media_type': mediaType.apiPath,
        'title': title,
        'original_title': originalTitle,
        'overview': overview,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'vote_average': voteAverage,
        'vote_count': voteCount,
        'popularity': popularity,
        'adult': adult,
        'original_language': originalLanguage,
        'genre_ids': genreIds,
        'release_date': releaseDate,
      };
}

class PagedResult<T> {
  final int page;
  final int totalPages;
  final int totalResults;
  final List<T> results;
  const PagedResult({
    required this.page,
    required this.totalPages,
    required this.totalResults,
    required this.results,
  });

  bool get hasMore => page < totalPages;

  static PagedResult<MediaSummary> media(Map<String, dynamic> j, {String? mediaType}) {
    final list = _maps(j['results'])
        .map((m) => MediaSummary.fromJson(m, fallbackType: mediaType))
        .toList();
    return PagedResult(
      page: _asInt(j['page']) ?? 1,
      totalPages: _asInt(j['total_pages']) ?? 1,
      totalResults: _asInt(j['total_results']) ?? list.length,
      results: list,
    );
  }

  static PagedResult<T> generic<T>(
          Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) =>
      PagedResult(
        page: _asInt(j['page']) ?? 1,
        totalPages: _asInt(j['total_pages']) ?? 1,
        totalResults: _asInt(j['total_results']) ?? 0,
        results: _maps(j['results']).map(parse).toList(),
      );

  static const PagedResult<MediaSummary> empty =
      PagedResult(page: 1, totalPages: 1, totalResults: 0, results: []);
}

class Company {
  final int id;
  final String name;
  final String? logoPath;
  final String originCountry;
  final String description;
  final String headquarters;
  final String homepage;
  final int? parentCompanyId;

  const Company({
    required this.id,
    required this.name,
    this.logoPath,
    this.originCountry = '',
    this.description = '',
    this.headquarters = '',
    this.homepage = '',
    this.parentCompanyId,
  });

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: _asInt(j['id']) ?? 0,
        name: _asString(j['name']) ?? '',
        logoPath: _asString(j['logo_path']),
        originCountry: _asString(j['origin_country']) ?? '',
        description: _asString(j['description']) ?? '',
        headquarters: _asString(j['headquarters']) ?? '',
        homepage: _asString(j['homepage']) ?? '',
        parentCompanyId: _asInt(j['parent_id']),
      );
}

class CastMember {
  final int id;
  final String name;
  final String character;
  final String originalName;
  final String? profilePath;
  final int order;
  final String creditId;
  final MediaType creditType;

  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.originalName = '',
    this.profilePath,
    this.order = 0,
    this.creditId = '',
    this.creditType = MediaType.movie,
  });

  factory CastMember.fromJson(Map<String, dynamic> j, {String type = 'movie'}) =>
      CastMember(
        id: _asInt(j['id']) ?? 0,
        name: _asString(j['name']) ?? '',
        character: _asString(j['character']) ?? _asString(j['job']) ?? '',
        originalName: _asString(j['original_name']) ?? '',
        profilePath: _asString(j['profile_path']),
        order: _asInt(j['order']) ?? 0,
        creditId: _asString(j['credit_id']) ?? '',
        creditType: MediaTypeX.fromApi(type),
      );
}

class CrewMember {
  final int id;
  final String name;
  final String job;
  final String department;
  final String? profilePath;
  final String creditId;

  const CrewMember({
    required this.id,
    required this.name,
    required this.job,
    required this.department,
    this.profilePath,
    this.creditId = '',
  });

  factory CrewMember.fromJson(Map<String, dynamic> j) => CrewMember(
        id: _asInt(j['id']) ?? 0,
        name: _asString(j['name']) ?? '',
        job: _asString(j['job']) ?? '',
        department: _asString(j['department']) ?? '',
        profilePath: _asString(j['profile_path']),
        creditId: _asString(j['credit_id']) ?? '',
      );
}

class Credits {
  final List<CastMember> cast;
  final List<CrewMember> crew;
  const Credits({this.cast = const [], this.crew = const []});

  factory Credits.fromJson(Map<String, dynamic>? j, {String type = 'movie'}) {
    if (j == null) return const Credits();
    return Credits(
      cast: _maps(j['cast']).map((c) => CastMember.fromJson(c, type: type)).toList(),
      crew: _maps(j['crew']).map(CrewMember.fromJson).toList(),
    );
  }

  List<String> get departments => (crew.map((c) => c.department).toSet().toList())..sort();

  List<CrewMember> byDepartment(String dep) => crew.where((c) => c.department == dep).toList();
}

class ImageInfo {
  final String filePath;
  final int width;
  final int height;
  final String language;
  final double aspectRatio;
  final String type;
  const ImageInfo({
    required this.filePath,
    this.width = 0,
    this.height = 0,
    this.language = '',
    this.aspectRatio = 0,
    this.type = '',
  });

  factory ImageInfo.fromJson(Map<String, dynamic> j) => ImageInfo(
        filePath: _asString(j['file_path']) ?? '',
        width: _asInt(j['width']) ?? 0,
        height: _asInt(j['height']) ?? 0,
        language: _asString(j['iso_639_1']) ?? '',
        aspectRatio: _asDouble(j['aspect_ratio']) ?? 0,
        type: _asString(j['type']) ?? '',
      );
}

class ImageCollection {
  final List<ImageInfo> backdrops;
  final List<ImageInfo> posters;
  final List<ImageInfo> logos;
  final List<ImageInfo> profiles;
  final List<ImageInfo> stills;
  const ImageCollection({
    this.backdrops = const [],
    this.posters = const [],
    this.logos = const [],
    this.profiles = const [],
    this.stills = const [],
  });

  factory ImageCollection.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ImageCollection();
    return ImageCollection(
      backdrops: _maps(j['backdrops']).map(ImageInfo.fromJson).toList(),
      posters: _maps(j['posters']).map(ImageInfo.fromJson).toList(),
      logos: _maps(j['logos']).map(ImageInfo.fromJson).toList(),
      profiles: _maps(j['profiles']).map(ImageInfo.fromJson).toList(),
      stills: _maps(j['stills']).map(ImageInfo.fromJson).toList(),
    );
  }
}

class VideoInfo {
  final String id;
  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;
  final DateTime? publishedAt;

  const VideoInfo({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    this.official = true,
    this.publishedAt,
  });

  bool get isYouTube => site == 'YouTube';
  bool get isTrailer => type == 'Trailer';
  bool get isTeaser => type == 'Teaser';
  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/hqdefault.jpg';
  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';

  factory VideoInfo.fromJson(Map<String, dynamic> j) => VideoInfo(
        id: _asString(j['id']) ?? '',
        key: _asString(j['key']) ?? '',
        name: _asString(j['name']) ?? '',
        site: _asString(j['site']) ?? '',
        type: _asString(j['type']) ?? '',
        official: _asString(j['official']) != 'false',
        publishedAt: DateTime.tryParse(_asString(j['published_at']) ?? ''),
      );
}

class Keyword {
  final int id;
  final String name;
  const Keyword(this.id, this.name);
  factory Keyword.fromJson(Map<String, dynamic> j) =>
      Keyword(_asInt(j['id']) ?? 0, _asString(j['name']) ?? '');
}

/// Tek bir certification kaydı (ülke -> yaş sınırı).
class CertificationInfo {
  final String country;
  final String certification;
  final String meaning;
  const CertificationInfo(this.country, this.certification, [this.meaning = '']);
}

/// Bir ülkeye ait yayın/erişim bilgisi.
class ReleaseRegion {
  final String country;
  final List<ReleaseDateEntry> entries;
  const ReleaseRegion({required this.country, this.entries = const []});
}

class ReleaseDateEntry {
  final String type;
  final String date;
  final String certification;
  final int note;
  const ReleaseDateEntry({
    required this.type,
    required this.date,
    this.certification = '',
    this.note = 0,
  });

  String get typeLabel => switch (type) {
        '1' => 'Premier',
        '2' => 'Sinema',
        '3' => 'Dijital',
        '4' => 'Fiziksel',
        '5' => 'TV',
        _ => type,
      };
}

class RegionProviders {
  final String displayPriority;
  final List<WatchProviderEntry> flatrate;
  final List<WatchProviderEntry> rent;
  final List<WatchProviderEntry> buy;
  const RegionProviders({
    this.displayPriority = 'flat,rent,buy',
    this.flatrate = const [],
    this.rent = const [],
    this.buy = const [],
  });

  factory RegionProviders.fromJson(Map<String, dynamic> j) => RegionProviders(
        displayPriority: _asString(j['display_priority']) ?? 'flat,rent,buy',
        flatrate: _maps(j['flatrate']).map(WatchProviderEntry.fromJson).toList(),
        rent: _maps(j['rent']).map(WatchProviderEntry.fromJson).toList(),
        buy: _maps(j['buy']).map(WatchProviderEntry.fromJson).toList(),
      );

  bool get isEmpty => flatrate.isEmpty && rent.isEmpty && buy.isEmpty;
}

class WatchProviderEntry {
  final int providerId;
  final String providerName;
  final String logoPath;
  final int displayPriority;
  const WatchProviderEntry({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    this.displayPriority = 0,
  });

  factory WatchProviderEntry.fromJson(Map<String, dynamic> j) => WatchProviderEntry(
        providerId: _asInt(j['provider_id']) ?? 0,
        providerName: _asString(j['provider_name']) ?? '',
        logoPath: _asString(j['logo_path']) ?? '',
        displayPriority: _asInt(j['display_priority']) ?? 0,
      );
}

class ProviderResults {
  final Map<String, RegionProviders> byCountry;
  const ProviderResults(this.byCountry);

  factory ProviderResults.fromJson(Map<String, dynamic> j) {
    final out = <String, RegionProviders>{};
    for (final r in _maps(j['results'])) {
      final country = _asString(r['iso_3166_1']) ?? '';
      if (r['providers'] is Map<String, dynamic>) {
        out[country] = RegionProviders.fromJson(r['providers'] as Map<String, dynamic>);
      }
    }
    return ProviderResults(out);
  }

  RegionProviders? region(String code) => byCountry[code];
}

class WatchProviderCatalog {
  final Map<String, List<WatchProviderEntry>> flatrate;
  final Map<String, List<WatchProviderEntry>> rent;
  final Map<String, List<WatchProviderEntry>> buy;
  const WatchProviderCatalog({this.flatrate = const {}, this.rent = const {}, this.buy = const {}});

  static Map<String, List<WatchProviderEntry>> _parse(dynamic j) {
    final out = <String, List<WatchProviderEntry>>{};
    if (j is Map<String, dynamic>) {
      j.forEach((k, v) {
        out[k] = _maps(v).map(WatchProviderEntry.fromJson).toList();
      });
    }
    return out;
  }

  factory WatchProviderCatalog.fromJson(Map<String, dynamic> j) => WatchProviderCatalog(
        flatrate: _parse(j['flatrate']),
        rent: _parse(j['rent']),
        buy: _parse(j['buy']),
      );

  List<WatchProviderEntry> allFor(String country) {
    final seen = <int>{};
    final out = <WatchProviderEntry>[];
    for (final m in [flatrate, rent, buy]) {
      for (final p in (m[country] ?? const <WatchProviderEntry>[])) {
        if (seen.add(p.providerId)) out.add(p);
      }
    }
    out.sort((a, b) => b.displayPriority.compareTo(a.displayPriority));
    return out;
  }
}

/// Film ve dizi detayının birleşik modeli.
class MediaDetail {
  final int id;
  final MediaType mediaType;
  final String title;
  final String originalTitle;
  final String overview;
  final String tagline;
  final String? posterPath;
  final String? backdropPath;
  final double? voteAverage;
  final int voteCount;
  final int runtime;
  final String? releaseDate;
  final String status;
  final String originalLanguage;
  final List<Genre> genres;
  final List<Company> productionCompanies;
  final List<CountryInfo> productionCountries;
  final List<VideoInfo> videos;
  final Credits credits;
  final List<MediaSummary> similar;
  final List<MediaSummary> recommendations;
  final ImageCollection images;
  final List<CertificationInfo> certifications;
  final Map<String, ReleaseRegion> releases;
  final String homepage;
  final String? imdbId;
  final double popularity;
  final bool adult;
  final int budget;
  final int revenue;
  final List<Keyword> keywords;
  final List<SeasonSummary> seasons;
  final int? episodeRunTime;
  final String? createdBy;
  final List<String> originCountry;
  final List<MediaSummary> externalLinks;
  final List<ReviewItem> reviews;
  final MediaSummary? belongsToCollection;
  final ProviderResults providers;

  const MediaDetail({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    this.overview = '',
    this.tagline = '',
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.voteCount = 0,
    this.runtime = 0,
    this.releaseDate,
    this.status = '',
    this.originalLanguage = '',
    this.genres = const [],
    this.productionCompanies = const [],
    this.productionCountries = const [],
    this.videos = const [],
    this.credits = const Credits(),
    this.similar = const [],
    this.recommendations = const [],
    this.images = const ImageCollection(),
    this.certifications = const [],
    this.releases = const {},
    this.homepage = '',
    this.imdbId,
    this.popularity = 0,
    this.adult = false,
    this.budget = 0,
    this.revenue = 0,
    this.keywords = const [],
    this.seasons = const [],
    this.episodeRunTime,
    this.createdBy,
    this.originCountry = const [],
    this.externalLinks = const [],
    this.reviews = const [],
    this.belongsToCollection,
    this.providers = const ProviderResults({}),
  });

  static MediaDetail fromJson(
    Map<String, dynamic> j, {
    required MediaType mediaType,
    Map<String, dynamic> extra = const {},
  }) {
    Map<String, dynamic>? sub(String key) {
      final direct = j[key];
      if (direct is Map<String, dynamic>) return direct;
      final e = extra[key];
      return e is Map<String, dynamic> ? e : null;
    }

    final title = _asString(j['title'] ?? j['name']) ?? '';
    final original = _asString(j['original_title'] ?? j['original_name']) ?? title;
    final creditsJson = sub('credits');
    final contentRatings = <CertificationInfo>[];
    final releases = <String, ReleaseRegion>{};
    final releaseJson = sub('release_dates') ?? sub('content_ratings');
    if (releaseJson != null) {
      for (final r in _maps(releaseJson['results'])) {
        final country = _asString(r['iso_3166_1']) ?? _asString(r['iso_3166_2']) ?? '';
        final entries = <ReleaseDateEntry>[];
        final raw = _maps(r['release_dates']).isEmpty ? _maps(r['runtime']) : _maps(r['release_dates']);
        for (final t in raw) {
          final cert = _asString(t['certification']) ?? '';
          if (cert.isNotEmpty) {
            contentRatings.add(CertificationInfo(country, cert));
          }
          entries.add(ReleaseDateEntry(
            type: _asString(t['type']) ?? '',
            date: _asString(t['release_date']) ?? '',
            certification: cert,
          ));
        }
        releases[country] = ReleaseRegion(country: country, entries: entries);
      }
    }

    final providerJson = sub('watch/providers');
    final keywordsJson = sub('keywords');
    final externalJson = sub('external_ids');
    final reviewJson = sub('reviews');
    final collectionJson = j['belongs_to_collection'];
    final companies = _maps(j['production_companies']).map(Company.fromJson).toList();
    final created = _maps(j['created_by']).map((c) => _asString(c['name']) ?? '').where((s) => s.isNotEmpty).join(', ');

    List<MediaSummary> list(String key) {
      final m = sub(key);
      return _maps(m?['results'])
          .map((e) => MediaSummary.fromJson(e, fallbackType: mediaType.apiPath))
          .toList();
    }

    return MediaDetail(
      id: _asInt(j['id']) ?? 0,
      mediaType: mediaType,
      title: title,
      originalTitle: original,
      overview: _asString(j['overview']) ?? '',
      tagline: _asString(j['tagline']) ?? '',
      posterPath: _asString(j['poster_path']),
      backdropPath: _asString(j['backdrop_path']),
      voteAverage: _asDouble(j['vote_average']),
      voteCount: _asInt(j['vote_count']) ?? 0,
      runtime: mediaType == MediaType.movie
          ? _asInt(j['runtime']) ?? 0
          : _asInt(_firstOf(j['episode_run_time'])) ?? 0,
      releaseDate: _asString(j['release_date'] ?? j['first_air_date']),
      status: _asString(j['status']) ?? '',
      originalLanguage: _asString(j['original_language']) ?? '',
      genres: _maps(j['genres']).map(Genre.fromJson).toList(),
      productionCompanies: companies,
      productionCountries: _maps(j['production_countries'])
          .map((c) => CountryInfo(
                _asString(c['iso_3166_1']) ?? '',
                _asString(c['name']) ?? '',
                _asString(c['name']) ?? '',
              ))
          .toList(),
      videos: _maps(sub('videos')?['results']).map(VideoInfo.fromJson).toList(),
      credits: Credits.fromJson(creditsJson, type: mediaType.apiPath),
      similar: list('similar'),
      recommendations: list('recommendations'),
      images: ImageCollection.fromJson(sub('images')),
      certifications: contentRatings,
      releases: releases,
      homepage: _asString(j['homepage']) ?? '',
      imdbId: _asString(j['imdb_id'] ?? externalJson?['imdb_id']),
      popularity: _asDouble(j['popularity']) ?? 0,
      adult: j['adult'] == true,
      budget: _asInt(j['budget']) ?? 0,
      revenue: _asInt(j['revenue']) ?? 0,
      keywords: _maps(keywordsJson?['keywords']).map(Keyword.fromJson).toList(),
      seasons: _maps(j['seasons']).map(SeasonSummary.fromJson).toList(),
      episodeRunTime: _asInt(_firstOf(j['episode_run_time'])),
      createdBy: created.isEmpty ? null : created,
      originCountry: (j['origin_country'] as List?)?.cast<String>() ?? const [],
      externalLinks: const [],
      reviews: _maps(reviewJson?['results']).map(ReviewItem.fromJson).toList(),
      belongsToCollection: collectionJson is Map<String, dynamic>
          ? MediaSummary.fromJson(collectionJson, fallbackType: 'movie')
          : null,
      providers: providerJson is Map<String, dynamic>
          ? ProviderResults.fromJson(providerJson)
          : const ProviderResults({}),
    );
  }
}

class SeasonSummary {
  final int seasonNumber;
  final String name;
  final String overview;
  final String? posterPath;
  final String? airDate;
  final int episodeCount;

  const SeasonSummary({
    required this.seasonNumber,
    required this.name,
    this.overview = '',
    this.posterPath,
    this.airDate,
    this.episodeCount = 0,
  });

  factory SeasonSummary.fromJson(Map<String, dynamic> j) => SeasonSummary(
        seasonNumber: _asInt(j['season_number']) ?? 0,
        name: _asString(j['name']) ?? '',
        overview: _asString(j['overview']) ?? '',
        posterPath: _asString(j['poster_path']),
        airDate: _asString(j['air_date']),
        episodeCount: _asInt(j['episode_count']) ?? 0,
      );
}

class EpisodeDetail {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final String? airDate;
  final int runtime;
  final double? voteAverage;
  final int voteCount;
  final List<CastMember> cast;
  final List<CrewMember> crew;
  final List<VideoInfo> videos;
  final int productionCode;

  const EpisodeDetail({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.overview = '',
    this.stillPath,
    this.airDate,
    this.runtime = 0,
    this.voteAverage,
    this.voteCount = 0,
    this.cast = const [],
    this.crew = const [],
    this.videos = const [],
    this.productionCode = 0,
  });

  factory EpisodeDetail.fromJson(Map<String, dynamic> j, {int season = 0}) {
    final creditsJson = j['credits'] is Map<String, dynamic> ? j['credits'] as Map<String, dynamic> : null;
    return EpisodeDetail(
      id: _asInt(j['id']) ?? 0,
      episodeNumber: _asInt(j['episode_number']) ?? 0,
      seasonNumber: _asInt(j['season_number']) ?? season,
      name: _asString(j['name']) ?? '',
      overview: _asString(j['overview']) ?? '',
      stillPath: _asString(j['still_path']),
      airDate: _asString(j['air_date']),
      runtime: _asInt(j['runtime']) ?? 0,
      voteAverage: _asDouble(j['vote_average']),
      voteCount: _asInt(j['vote_count']) ?? 0,
      cast: _maps(creditsJson?['cast']).map((c) => CastMember.fromJson(c, type: 'tv')).toList(),
      crew: _maps(creditsJson?['crew']).map(CrewMember.fromJson).toList(),
      videos: _maps((j['videos'] as Map?)?['results']).map(VideoInfo.fromJson).toList(),
    );
  }
}

class SeasonDetail {
  final int id;
  final String name;
  final String overview;
  final String? posterPath;
  final String? airDate;
  final int seasonNumber;
  final List<EpisodeDetail> episodes;

  const SeasonDetail({
    required this.id,
    required this.name,
    this.overview = '',
    this.posterPath,
    this.airDate,
    required this.seasonNumber,
    this.episodes = const [],
  });

  factory SeasonDetail.fromJson(Map<String, dynamic> j) {
    final seasonNo = _asInt(j['season_number']) ?? 0;
    return SeasonDetail(
      id: _asInt(j['id']) ?? 0,
      name: _asString(j['name']) ?? '',
      overview: _asString(j['overview']) ?? '',
      posterPath: _asString(j['poster_path']),
      airDate: _asString(j['air_date']),
      seasonNumber: seasonNo,
      episodes: _maps(j['episodes']).map((e) => EpisodeDetail.fromJson(e, season: seasonNo)).toList(),
    );
  }
}

class ReviewItem {
  final String id;
  final String author;
  final String content;
  final String url;
  final DateTime updatedAt;
  final int rating;

  const ReviewItem({
    required this.id,
    required this.author,
    required this.content,
    this.url = '',
    required this.updatedAt,
    this.rating = 0,
  });

  String get shortContent => content.length > 320 ? '${content.substring(0, 320)}…' : content;

  factory ReviewItem.fromJson(Map<String, dynamic> j) {
    final authorJson = j['author_details'] is Map<String, dynamic>
        ? j['author_details'] as Map<String, dynamic>
        : null;
    return ReviewItem(
      id: _asString(j['id']) ?? '',
      author: authorJson != null
          ? (_asString(authorJson['username']) ?? _asString(j['author']) ?? '')
          : _asString(j['author']) ?? '',
      content: _asString(j['content']) ?? '',
      url: _asString(j['url']) ?? '',
      updatedAt: DateTime.tryParse(_asString(j['created_at'] ?? j['updated_at']) ?? '') ?? DateTime.now(),
      rating: (_asDouble(authorJson?['rating']) ?? 0) * 2 as int,
    );
  }
}

class MovieListItem {
  final int id;
  final String name;
  final String description;
  final int itemCount;
  final String? posterPath;
  final String username;
  final String language;
  final String type;
  final int favoriteCount;

  const MovieListItem({
    required this.id,
    required this.name,
    this.description = '',
    this.itemCount = 0,
    this.posterPath,
    this.username = '',
    this.language = '',
    this.type = 'movie',
    this.favoriteCount = 0,
  });

  factory MovieListItem.fromJson(Map<String, dynamic> j) => MovieListItem(
        id: _asInt(j['id']) ?? 0,
        name: _asString(j['name']) ?? '',
        description: _asString(j['description']) ?? '',
        itemCount: _asInt(j['item_count']) ?? 0,
        posterPath: _asString((j['image'] is Map ? (j['image'] as Map)['url'] : null) ?? j['poster_path']),
        username: _asString(j['username'] ?? (j['created_by'] is Map ? (j['created_by'] as Map)['username'] : null)) ?? '',
        language: _asString(j['iso_639_1']) ?? '',
        type: _asString(j['type']) ?? 'movie',
        favoriteCount: _asInt(j['favorite_count']) ?? 0,
      );
}

class PersonDetail {
  final int id;
  final String name;
  final List<String> alsoKnownAs;
  final String biography;
  final String? birthday;
  final String? deathday;
  final int? age;
  final String placeOfBirth;
  final String homepage;
  final String? profilePath;
  final double popularity;
  final bool adult;
  final String knownForDepartment;
  final List<MediaSummary> combinedCredits;
  final ImageCollection images;
  final List<MediaSummary> taggedProfiles;
  final ExternalIds externalIds;

  const PersonDetail({
    required this.id,
    required this.name,
    this.alsoKnownAs = const [],
    this.biography = '',
    this.birthday,
    this.deathday,
    this.age,
    this.placeOfBirth = '',
    this.homepage = '',
    this.profilePath,
    this.popularity = 0,
    this.adult = false,
    this.knownForDepartment = '',
    this.combinedCredits = const [],
    this.images = const ImageCollection(),
    this.taggedProfiles = const [],
    this.externalIds = const ExternalIds(),
  });

  factory PersonDetail.fromJson(Map<String, dynamic> j, {Map<String, dynamic> extra = const {}}) {
    final credits = <MediaSummary>[];
    final seen = <String>{};
    for (final key in ['movie_credits', 'tv_credits']) {
      final src = extra[key] ?? j[key];
      if (src is! Map<String, dynamic>) continue;
      final type = key == 'tv_credits' ? 'tv' : 'movie';
      for (final c in _maps(src['cast'])) {
        final m = MediaSummary.fromJson(c, fallbackType: type);
        if (seen.add('${m.mediaType.name}-${m.id}')) credits.add(m);
      }
      for (final c in _maps(src['crew'])) {
        final m = MediaSummary.fromJson(c, fallbackType: type);
        if (seen.add('${m.mediaType.name}-${m.id}')) credits.add(m);
      }
    }
    credits.sort((a, b) => b.popularity.compareTo(a.popularity));

    final imagesJson = (extra['images'] ?? j['images']);
    final tagged = (extra['tagged_images'] ?? j['tagged_images']);

    return PersonDetail(
      id: _asInt(j['id']) ?? 0,
      name: _asString(j['name']) ?? '',
      alsoKnownAs: (j['also_known_as'] as List?)?.cast<String>() ?? const [],
      biography: _asString(j['biography']) ?? '',
      birthday: _asString(j['birthday']),
      deathday: _asString(j['deathday']),
      age: _asInt(j['age']),
      placeOfBirth: _asString(j['place_of_birth']) ?? '',
      homepage: _asString(j['homepage']) ?? '',
      profilePath: _asString(j['profile_path']),
      popularity: _asDouble(j['popularity']) ?? 0,
      adult: j['adult'] == true,
      knownForDepartment: _asString(j['known_for_department']) ?? '',
      combinedCredits: credits,
      images: ImageCollection.fromJson(
          imagesJson is Map<String, dynamic> ? imagesJson : null),
      taggedProfiles: _maps((tagged as Map?)?['results'])
          .map((e) => MediaSummary.fromJson(e, fallbackType: e['media_type']?.toString()))
          .toList(),
      externalIds: ExternalIds.fromJson(
          (extra['external_ids'] ?? j['external_ids']) as Map<String, dynamic>?),
    );
  }
}

class ExternalIds {
  final String imdbId;
  final String tvdbId;
  final String wikidataId;
  final String facebook;
  final String instagram;
  final String twitter;
  final String youtube;
  final String homepage;
  const ExternalIds({
    this.imdbId = '',
    this.tvdbId = '',
    this.wikidataId = '',
    this.facebook = '',
    this.instagram = '',
    this.twitter = '',
    this.youtube = '',
    this.homepage = '',
  });

  factory ExternalIds.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ExternalIds();
    String s(String k) => _asString(j[k]) ?? '';
    return ExternalIds(
      imdbId: s('imdb_id'),
      tvdbId: s('tvdb_id'),
      wikidataId: s('wikidata_id'),
      facebook: s('facebook_id'),
      instagram: s('instagram_id'),
      twitter: s('twitter_id'),
      youtube: s('youtube_id'),
      homepage: s('homepage'),
    );
  }

  List<(String, String)> get socialLinks => [
        if (facebook.isNotEmpty) ('Facebook', 'https://facebook.com/$facebook'),
        if (instagram.isNotEmpty) ('Instagram', 'https://instagram.com/$instagram'),
        if (twitter.isNotEmpty) ('X / Twitter', 'https://x.com/$twitter'),
        if (youtube.isNotEmpty) ('YouTube', 'https://youtube.com/@$youtube'),
        if (imdbId.isNotEmpty) ('IMDb', 'https://www.imdb.com/title/$imdbId/'),
        if (tvdbId.isNotEmpty) ('TVDb', 'https://thetvdb.com/series/$tvdbId'),
        if (wikidataId.isNotEmpty) ('Wikidata', 'https://www.wikidata.org/wiki/$wikidataId'),
        if (homepage.isNotEmpty) ('Web sitesi', homepage),
      ];
}

class TmdbConfiguration {
  final String imageUrl;
  final List<String> posterSizes;
  final List<String> backdropSizes;
  final List<String> logoSizes;
  final List<String> profileSizes;
  final List<String> stillSizes;
  const TmdbConfiguration({
    required this.imageUrl,
    this.posterSizes = const ['w185', 'w500', 'original'],
    this.backdropSizes = const ['w300', 'w780', 'w1280', 'original'],
    this.logoSizes = const ['w96', 'w154', 'w500', 'original'],
    this.profileSizes = const ['w45', 'w185', 'original'],
    this.stillSizes = const ['w92', 'w185', 'w300', 'original'],
  });

  factory TmdbConfiguration.fromJson(Map<String, dynamic> j) {
    final images = j['images'] as Map<String, dynamic>? ?? const {};
    List<String> sizes(String key, List<String> dflt) =>
        (images[key] as List?)?.cast<String>() ?? dflt;
    return TmdbConfiguration(
      imageUrl: _asString(images['secure_base_url'] ?? images['base_url']) ??
          'https://image.tmdb.org/t/p/',
      posterSizes: sizes('poster_sizes', const ['w185', 'w500', 'original']),
      backdropSizes: sizes('backdrop_sizes', const ['w300', 'w780', 'w1280', 'original']),
      logoSizes: sizes('logo_sizes', const ['w96', 'w154', 'w500', 'original']),
      profileSizes: sizes('profile_sizes', const ['w45', 'w185', 'original']),
      stillSizes: sizes('still_sizes', const ['w92', 'w185', 'w300', 'original']),
    );
  }
}

class CountryInfo {
  final String iso;
  final String englishName;
  final String localName;
  const CountryInfo(this.iso, this.englishName, this.localName);

  factory CountryInfo.fromJson(Map<String, dynamic> j) => CountryInfo(
        _asString(j['iso_3166_1']) ?? '',
        _asString(j['english_name']) ?? '',
        _asString(j['native_name'] ?? j['english_name']) ?? '',
      );
}

class LanguageInfo {
  final String iso;
  final String english;
  final String local;
  const LanguageInfo(this.iso, this.english, this.local);
  factory LanguageInfo.fromJson(Map<String, dynamic> j) => LanguageInfo(
        _asString(j['iso_639_1']) ?? '',
        _asString(j['english_name']) ?? '',
        _asString(j['local_name'] ?? j['english_name']) ?? '',
      );
}

class CollectionDetail {
  final int id;
  final String name;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final List<MediaSummary> parts;

  const CollectionDetail({
    required this.id,
    required this.name,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    this.parts = const [],
  });

  factory CollectionDetail.fromJson(Map<String, dynamic> j) => CollectionDetail(
        id: _asInt(j['id']) ?? 0,
        name: _asString(j['name']) ?? '',
        overview: _asString(j['overview']) ?? '',
        posterPath: _asString(j['poster_path']),
        backdropPath: _asString(j['backdrop_path']),
        parts: _maps(j['parts']).map((e) => MediaSummary.fromJson(e, fallbackType: 'movie')).toList(),
      );
}

class TrendingFrame {
  final DateTime fetchedAt;
  final List<MediaSummary> items;
  const TrendingFrame(this.fetchedAt, this.items);
}
