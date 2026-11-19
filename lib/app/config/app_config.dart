/// Cineva uygulama sabitleri.
class AppConfig {
  AppConfig._();

  static const String appName = 'Cineva';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'muhammetfatihdemr@gmail.com';

  /// TMDB atıf zorunluluğu (API şartları).
  static const String tmdbAttribution =
      'Bu uygulama TMDB API kullanmaktadır; TMDB tarafından onaylanmış veya '
      'desteklenmemektedir.';
  static const String tmdbShortAttribution = 'TMDB tarafından desteklenmektedir';

  static const String tmdbSiteUrl = 'https://www.themoviedb.org';
  static const String tmdbApiDocs = 'https://developers.themoviedb.org';
  static const String tmdbTermsUrl = 'https://www.themoviedb.org/terms-of-use';

  /// İçerik yaş sınırlaması (Play Store hedef kitle beyanı için referans).
  static const int contentRatingMinAge = 13;
}
