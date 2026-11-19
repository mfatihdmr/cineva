import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/tmdb_models.dart';

class TmdbException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetwork;
  const TmdbException(this.message, {this.statusCode, this.isNetwork = false});

  factory TmdbException.network(Object e) => TmdbException(
        'İnternet bağlantısı yok. Wi-Fi veya mobil veriyi kontrol edin.',
        isNetwork: true,
      );

  @override
  String toString() => message;
}

/// TMDB v3 API istemcisi.
///
/// Tüm endpoint'ler tek yerde toplanır; ekranlar yalnızca bu servisi kullanır.
class TmdbApi {
  TmdbApi._();
  static final TmdbApi instance = TmdbApi._();

  static const String _base = 'https://api.themoviedb.org/3/';
  static const String _imageBase = 'https://image.tmdb.org/t/p/';

  Dio? _dio;
  String _apiKey = '';
  TmdbConfiguration _config = const TmdbConfiguration(imageUrl: _imageBase);

  /// TMDB `language` parametresi; ayarlardan yönetilir.
  String language = 'tr-TR';

  /// `tr-TR` bölge kodu varsayılanı; ayarlardan değiştirilebilir.
  String region = 'TR';

  Future<void> configure(String apiKey, {String? region}) async {
    _apiKey = apiKey;
    if (region != null && region.length == 2) this.region = region.toUpperCase();
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      queryParameters: {'api_key': _apiKey},
      headers: const {'Accept': 'application/json'},
    ));
    _dio!.interceptors.add(LogInterceptor(
      request: false,
      responseBody: false,
      logPrint: (o) => kDebugMode ? debugPrint('[tmdb] $o') : null,
    ));
    try {
      final r = await _get('configuration');
      _config = TmdbConfiguration.fromJson(r);
    } catch (_) {
      // İnternet yoksa varsayılan CDN adresiyle devam edilir.
    }
  }

  TmdbConfiguration get config => _config;
  bool get isReady => _dio != null && _apiKey.isNotEmpty;

  /// Görsel yolu tam URL'e çevirir.
  String image(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '${_config.imageUrl}$size/$clean';
  }

  /// Poster için en uygun boyutu seçer.
  String poster(String? path, {bool large = false}) =>
      image(path, size: large ? 'w500' : 'w342');
  String backdrop(String? path, {bool large = false}) =>
      image(path, size: large ? 'w1280' : 'w780');
  String profile(String? path, {bool large = false}) =>
      image(path, size: large ? 'w185' : 'w45');
  String logo(String? path, {bool large = false}) =>
      image(path, size: large ? 'w500' : 'w154');
  String still(String? path) => image(path, size: 'w300');

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? qp]) async {
    if (_dio == null) {
      throw const TmdbException('TMDB anahtarı yapılandırılmamış.');
    }
    try {
      final res = await _dio!.get<Map<String, dynamic>>(path,
          queryParameters: qp == null ? null : _clean(qp));
      final data = res.data;
      if (data == null) throw const TmdbException('Boş yanıt alındı.');
      if (data['success'] == false) {
        throw TmdbException(
          _asStringOrNull(data['status_message']) ?? 'TMDB hatası',
          statusCode: res.statusCode,
        );
      }
      return data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw TmdbException.network(e);
      }
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final msg = body is Map
          ? (_asStringOrNull(body['status_message']) ?? _statusMessage(status))
          : _statusMessage(status);
      throw TmdbException(msg, statusCode: status);
    } on TmdbException {
      rethrow;
    } catch (e) {
      throw TmdbException('Beklenmeyen bir hata oluştu: $e');
    }
  }

  static String _statusMessage(int? status) => switch (status) {
        401 => 'API anahtarı geçersiz (401). local.properties dosyasını kontrol edin.',
        404 => 'İçerik bulunamadı (404).',
        429 => 'Çok fazla istek gönderildi. Birkaç saniye sonra tekrar deneyin.',
        null || 0 => 'Sunucuya ulaşılamadı.',
        _ => 'Sunucu hatası ($status).',
      };

  static String? _asStringOrNull(dynamic v) => v?.toString();

  Map<String, dynamic> _clean(Map<String, dynamic> qp) {
    final out = <String, dynamic>{};
    qp.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is List) {
        if (v.isEmpty) return;
        out[k] = v.join(',');
        return;
      }
      if (v is bool) {
        out[k] = v;
        return;
      }
      out[k] = v;
    });
    return out;
  }

  Map<String, dynamic> _baseQuery({
    int page = 1,
    String? language,
    String? region,
    bool? includeAdult,
  }) =>
      {
        'page': page,
        'language': language ?? this.language,
        if (region != null) 'region': region,
        if (includeAdult != null) 'include_adult': includeAdult,
      };

  // ──────────────────────────── KEŞİF ────────────────────────────

  Future<PagedResult<MediaSummary>> trending({
    MediaType mediaType = MediaType.movie,
    String window = 'week',
    int page = 1,
  }) async {
    final path = mediaType == MediaType.person
        ? 'trending/person/$window'
        : 'trending/${mediaType.apiPath}/$window';
    final r = await _get(path, _baseQuery(page: page));
    return PagedResult.media(r,
        mediaType: mediaType == MediaType.person ? 'person' : mediaType.apiPath);
  }

  Future<PagedResult<MediaSummary>> discover({
    required MediaType mediaType,
    int page = 1,
    List<int> withGenres = const [],
    List<int> rejectGenres = const [],
    String sortBy = 'popularity.desc',
    String? certCountry,
    String? certLte,
    String? certGte,
    int? year,
    int? firstYear,
    String? primaryReleaseYear,
    int? withOriginalYear,
    String? releaseDateGte,
    String? releaseDateLte,
    double? voteAverageGte,
    int? voteCountGte,
    double? popularityGte,
    List<int> withPeople = const [],
    List<int> withCompanies = const [],
    List<int> withNetworks = const [],
    List<int> withKeywords = const [],
    String? withWatchProviders,
    String? withWatchMonetizationTypes,
    String? withCast,
    int? runtimeGte,
    int? runtimeLte,
    String? originalLanguage,
    bool? includeAdult,
    String? withGenresLogic,
  }) async {
    final r = await _get('discover/${mediaType.apiPath}', {
      ..._baseQuery(page: page, includeAdult: includeAdult),
      'with_genres': withGenres,
      'without_genres': rejectGenres,
      'sort_by': sortBy,
      if (certCountry != null) 'certification_country': certCountry,
      if (certLte != null) 'certification.lte': certLte,
      if (certGte != null) 'certification.gte': certGte,
      if (mediaType == MediaType.movie && year != null) 'year': year,
      if (mediaType == MediaType.movie && firstYear != null) 'first_release_date_year': firstYear,
      if (mediaType == MediaType.movie && primaryReleaseYear != null)
        'primary_release_year': primaryReleaseYear,
      if (mediaType == MediaType.tv && withOriginalYear != null) 'first_air_date_year': withOriginalYear,
      if (mediaType == MediaType.movie && releaseDateGte != null) 'release_date.gte': releaseDateGte,
      if (mediaType == MediaType.movie && releaseDateLte != null) 'release_date.lte': releaseDateLte,
      if (mediaType == MediaType.tv && releaseDateGte != null) 'first_air_date.gte': releaseDateGte,
      if (mediaType == MediaType.tv && releaseDateLte != null) 'first_air_date.lte': releaseDateLte,
      'vote_average.gte': voteAverageGte,
      'vote_count.gte': voteCountGte,
      'popularity.gte': popularityGte,
      'with_people': withPeople,
      'with_companies': withCompanies,
      if (mediaType == MediaType.tv) 'with_networks': withNetworks,
      'with_keywords': withKeywords,
      if (mediaType == MediaType.tv) 'with_cast': withCast,
      'runtime.gte': runtimeGte,
      'runtime.lte': runtimeLte,
      if (originalLanguage != null) 'with_original_language': originalLanguage,
      'with_watch_providers': withWatchProviders,
      'with_watch_monetization_types': withWatchMonetizationTypes,
      if (withGenresLogic != null) 'with_genres_logic': withGenresLogic,
      if (mediaType == MediaType.movie) 'include_to_next': true,
    });
    return PagedResult.media(r, mediaType: mediaType.apiPath);
  }

  Future<PagedResult<MediaSummary>> upcoming({int page = 1, String? region}) async {
    final r = await _get('movie/upcoming', _baseQuery(page: page, region: region ?? this.region));
    return PagedResult.media(r, mediaType: 'movie');
  }

  Future<PagedResult<MediaSummary>> nowPlaying({int page = 1, String? region}) async {
    final r = await _get('movie/now_playing', _baseQuery(page: page, region: region ?? this.region));
    return PagedResult.media(r, mediaType: 'movie');
  }

  Future<PagedResult<MediaSummary>> popular({
    MediaType mediaType = MediaType.movie,
    int page = 1,
  }) async {
    final r = await _get('${mediaType.apiPath}/popular', _baseQuery(page: page));
    return PagedResult.media(r, mediaType: mediaType.apiPath);
  }

  Future<PagedResult<MediaSummary>> topRated({
    MediaType mediaType = MediaType.movie,
    int page = 1,
  }) async {
    final r = await _get('${mediaType.apiPath}/top_rated', _baseQuery(page: page));
    return PagedResult.media(r, mediaType: mediaType.apiPath);
  }

  Future<PagedResult<MediaSummary>> latestMovie() async {
    final r = await _get('movie/latest', {'language': language});
    return PagedResult.media({'page': 1, 'total_pages': 1, 'total_results': 1, 'results': [r]},
        mediaType: 'movie');
  }

  /// Yayın takvimi: önümüzdeki [days] gün.
  Future<PagedResult<MediaSummary>> releases({
    String region = 'TR',
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    final r = await _get('discover/movie', {
      ..._baseQuery(page: page),
      'sort_by': 'popularity.desc',
      if (startDate != null) 'release_date.gte': startDate,
      if (endDate != null) 'release_date.lte': endDate,
      'with_release_type': [2, 3, 4],
    });
    return PagedResult.media(r, mediaType: 'movie');
  }

  // ──────────────────────────── ARAMA ────────────────────────────

  Future<PagedResult<MediaSummary>> searchMulti(String query,
      {int page = 1, bool? includeAdult}) async {
    final r = await _get('search/multi', {
      ..._baseQuery(page: page, includeAdult: includeAdult),
      'query': query,
    });
    return PagedResult.media(r);
  }

  Future<PagedResult<MediaSummary>> searchMovies(String query, {int page = 1}) async {
    final r = await _get('search/movie', {..._baseQuery(page: page), 'query': query});
    return PagedResult.media(r, mediaType: 'movie');
  }

  Future<PagedResult<MediaSummary>> searchTv(String query, {int page = 1}) async {
    final r = await _get('search/tv', {..._baseQuery(page: page), 'query': query});
    return PagedResult.media(r, mediaType: 'tv');
  }

  Future<PagedResult<MediaSummary>> searchPeople(String query, {int page = 1}) async {
    final r = await _get('search/person', {..._baseQuery(page: page), 'query': query});
    return PagedResult.media(r, mediaType: 'person');
  }

  Future<PagedResult<Company>> searchCompanies(String query, {int page = 1}) async {
    final r = await _get('search/company', _baseQuery(page: page)..['query'] = query);
    return PagedResult.generic(r, Company.fromJson);
  }

  Future<PagedResult<MediaSummary>> searchCollections(String query, {int page = 1}) async {
    final r = await _get('search/collection', {
      'api_key': _apiKey,
      'page': page,
      'language': language,
      'query': query,
    });
    return PagedResult.media(r, mediaType: 'movie');
  }

  Future<PagedResult<Keyword>> searchKeywords(String query, {int page = 1}) async {
    final r = await _get('search/keyword', {'page': page, 'query': query});
    return PagedResult.generic(r, Keyword.fromJson);
  }

  // ──────────────────────────── DETAY ────────────────────────────

  static const String _detailAppend =
      'images,credits,videos,similar,recommendations,release_dates,watch/providers,'
      'content_ratings,keywords,external_ids,reviews,provider';

  Future<MediaDetail> movieDetail(int id, {String? append}) async {
    final r = await _get('movie/$id', {
      'language': language,
      'append_to_response': append ?? _detailAppend,
    });
    return MediaDetail.fromJson(r, mediaType: MediaType.movie);
  }

  Future<MediaDetail> tvDetail(int id, {String? append}) async {
    final r = await _get('tv/$id', {
      'language': language,
      'append_to_response': append ?? _detailAppend,
    });
    return MediaDetail.fromJson(r, mediaType: MediaType.tv);
  }

  Future<MediaDetail> mediaDetail(int id, MediaType type) =>
      type == MediaType.tv ? tvDetail(id) : movieDetail(id);

  Future<MediaDetail> collectionDetail(int id) async {
    final r = await _get('collection/$id', {'language': language});
    final c = CollectionDetail.fromJson(r);
    return MediaDetail(
      id: c.id,
      mediaType: MediaType.movie,
      title: c.name,
      originalTitle: c.name,
      overview: c.overview,
      posterPath: c.posterPath,
      backdropPath: c.backdropPath,
      similar: c.parts,
      status: 'Koleksiyon',
    );
  }

  Future<PersonDetail> personDetail(int id) async {
    final r = await _get('person/$id', {
      'language': language,
      'append_to_response': 'movie_credits,tv_credits,external_ids,images,tagged_images,combined_credits',
    });
    return PersonDetail.fromJson(r);
  }

  Future<SeasonDetail> seasonDetail(int tvId, int seasonNumber) async {
    final r = await _get('tv/$tvId/season/$seasonNumber',
        {'language': language, 'append_to_response': 'videos,credits,images,external_ids'});
    return SeasonDetail.fromJson(r);
  }

  Future<EpisodeDetail> episodeDetail(int tvId, int season, int episode) async {
    final r = await _get('tv/$tvId/season/$season/episode/$episode', {
      'language': language,
      'append_to_response': 'credits,external_ids,images,videos'
    });
    return EpisodeDetail.fromJson(r, season: season);
  }

  Future<Credits> movieCredits(int id) async {
    final r = await _get('movie/$id/credits', {'language': language});
    return Credits.fromJson(r, type: 'movie');
  }

  Future<Credits> tvCredits(int id) async {
    final r = await _get('tv/$id/credits', {'language': language});
    return Credits.fromJson(r, type: 'tv');
  }

  Future<List<MediaSummary>> movieExternalIds(int id) async {
    final r = await _get('movie/$id/external_ids', {'language': language});
    return [ExternalIds.fromJson(r)]
        .where((e) => e.socialLinks.isNotEmpty)
        .expand((e) => e.socialLinks)
        .map((l) => MediaSummary(
              id: 0,
              mediaType: MediaType.movie,
              title: l.$1,
              originalTitle: l.$2,
            ))
        .toList();
  }

  // ──────────────────────────── LİSTELER ────────────────────────────

  Future<PagedResult<MediaSummary>> similar(MediaType type, int id, {int page = 1}) async {
    final r = await _get('${type.apiPath}/$id/similar', _baseQuery(page: page));
    return PagedResult.media(r, mediaType: type.apiPath);
  }

  Future<PagedResult<MediaSummary>> recommendations(MediaType type, int id, {int page = 1}) async {
    final r = await _get('${type.apiPath}/$id/recommendations', _baseQuery(page: page));
    return PagedResult.media(r, mediaType: type.apiPath);
  }

  Future<PagedResult<MediaSummary>> keywordMovies(int keywordId, {int page = 1}) async {
    final r = await _get('discover/movie', {
      ..._baseQuery(page: page),
      'with_keywords': keywordId,
      'sort_by': 'popularity.desc',
    });
    return PagedResult.media(r, mediaType: 'movie');
  }

  Future<PagedResult<MediaSummary>> companyMovies(int companyId, {int page = 1}) async {
    final r = await _get('discover/movie', {
      ..._baseQuery(page: page),
      'with_companies': companyId,
      'sort_by': 'popularity.desc',
    });
    return PagedResult.media(r, mediaType: 'movie');
  }

  Future<PagedResult<MediaSummary>> networkTv(int networkId, {int page = 1}) async {
    final r = await _get('discover/tv', {
      ..._baseQuery(page: page),
      'with_networks': networkId,
      'sort_by': 'popularity.desc',
    });
    return PagedResult.media(r, mediaType: 'tv');
  }

  // ──────────────────────────── İNCELEME / GÖRSEL ────────────────────────────

  Future<PagedResult<ReviewItem>> reviews(MediaType type, int id, {int page = 1}) async {
    final r = await _get('${type.apiPath}/$id/reviews',
        {'page': page, 'language': 'en-US'}); // TMDB incelemeleri çoğunlukla İngilizce
    return PagedResult.generic(r, ReviewItem.fromJson);
  }

  Future<ImageCollection> images(MediaType type, int id) async {
    final r = await _get('${type.apiPath}/$id/images', {'include_image_language': 'en,tr,null'});
    return ImageCollection.fromJson(r);
  }

  // ──────────────────────────── REFERANS ────────────────────────────

  Future<GenreList> genres(MediaType type) async {
    final r = await _get('genre/${type.apiPath}/list', {'language': language});
    return GenreList.fromJson(r);
  }

  Future<Company> companyDetail(int id) async {
    final r = await _get('company/$id', {'language': language});
    return Company.fromJson(r);
  }

  Future<WatchProviderCatalog> providers({String watchRegion = 'US', String only = 'all'}) async {
    final r = await _get('watch/providers/movie',
        {'language': 'tr', 'watch_region': watchRegion});
    return WatchProviderCatalog.fromJson(r);
  }

  Future<List<CountryInfo>> alternativeCountries() async {
    final r = await _get('configuration/countries', {'language': 'tr'});
    final list = (r['results'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    return list.map(CountryInfo.fromJson).toList();
  }

  Future<List<LanguageInfo>> alternativeLanguages() async {
    final r = await _get('configuration/languages', {'language': 'tr'});
    final list = (r as List).whereType<Map<String, dynamic>>();
    return list.map(LanguageInfo.fromJson).toList();
  }

  Future<List<Journey>> journeys() async {
    final r = await _get('configuration/journeys');
    final list = (r['results'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    return list
        .map((j) => Journey(
              _first(j, 'identifier')?.toString() ?? '',
              _first(j, 'name')?.toString() ?? '',
            ))
        .toList();
  }

  static dynamic _first(Map<String, dynamic> m, String k) => m[k] is List && (m[k] as List).isNotEmpty
      ? (m[k] as List).first
      : m[k];

  Future<PagedResult<MediaSummary>> popularPerson(int page) async {
    final r = await _get('person/popular', _baseQuery(page: page));
    return PagedResult.media(r, mediaType: 'person');
  }

  Future<PagedResult<MovieListItem>> lists(int id, {int page = 1}) async {
    final r = await _get('list/$id', {'language': language, 'page': page});
    return PagedResult.generic(r, MovieListItem.fromJson);
  }

  Future<List<MovieListItem>> popularLists({int page = 1}) async {
    final r = await _get('list/popular', _baseQuery(page: page));
    return (r['results'] as List?)?.whereType<Map<String, dynamic>>().map(MovieListItem.fromJson).toList() ??
        const [];
  }

  Future<PagedResult<MediaSummary>> searchLists(String query, {int page = 1}) async {
    final r = await _get('search/list', _baseQuery(page: page)..['query'] = query);
    final results = PagedResult.generic(r, MovieListItem.fromJson);
    return PagedResult(
      page: results.page,
      totalPages: results.totalPages,
      totalResults: results.totalResults,
      results: results.results
          .map((l) => MediaSummary(
                id: l.id,
                mediaType: MediaType.movie,
                title: l.name,
                originalTitle: l.description,
                posterPath: l.posterPath,
                overview: '${l.itemCount} içerik',
              ))
          .toList(),
    );
  }

  // ──────────────────────────── YARDIMCI ────────────────────────────

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
}

class Journey {
  final String identifier;
  final String name;
  const Journey(this.identifier, this.name);
}
