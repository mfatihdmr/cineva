import 'package:flutter/material.dart' hide ImageInfo;

import '../data/models/tmdb_models.dart';
import '../features/about/about_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/company/company_screen.dart';
import '../features/credits/credits_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/home/home_shell.dart';
import '../features/keyword/keyword_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/lists/lists_screen.dart';
import '../features/media/media_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/people/people_screen.dart';
import '../features/person/person_screen.dart';
import '../features/reviews/reviews_screen.dart';
import '../features/season/season_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/top250/top250_screen.dart';
import '../features/watch/providers_screen.dart';
import '../features/search/search_screen.dart';
import 'deep_link.dart';

/// Uygulama içi tüm geçişler buradan yapılır (type-safe, tek nokta).
class Nav {
  Nav._();

  static void _dismissKeyboard() =>
      FocusManager.instance.primaryFocus?.unfocus();

  static Future<T?> push<T>(BuildContext context, Widget screen) {
    _dismissKeyboard();
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> home(BuildContext context) =>
      _replace(context, const HomeShell());

  static Future<T?> media<T>(BuildContext context, MediaType type, int id) =>
      push<T>(context, MediaDetailScreen(type: type, id: id));

  static Future<T?> person<T>(BuildContext context, int id) =>
      push<T>(context, PersonScreen(id: id));

  static Future<T?> discover<T>(BuildContext context, MediaType type) =>
      push<T>(context, DiscoverScreen(initialType: type));

  static Future<T?> search<T>(BuildContext context, {String query = ''}) =>
      push<T>(context, SearchScreen(initialQuery: query));

  static Future<T?> season<T>(BuildContext context, int tvId, int season) =>
      push<T>(context, SeasonScreen(tvId: tvId, seasonNumber: season));

  static Future<T?> reviews<T>(BuildContext context, MediaType type, int id) =>
      push<T>(context, ReviewsScreen(type: type, id: id));

  static Future<T?> gallery<T>(BuildContext context, MediaType type, int id,
          {List<ImageInfo>? images}) =>
      push<T>(context, GalleryScreen(type: type, id: id, images: images));

  static Future<T?> collection<T>(BuildContext context, int id) =>
      push<T>(context, CollectionEntry(id: id));

  static Future<T?> company<T>(BuildContext context, int id) =>
      push<T>(context, CompanyScreen(id: id));

  static Future<T?> keyword<T>(BuildContext context, int id, String name) =>
      push<T>(context, KeywordScreen(id: id, name: name));

  static Future<T?> credits<T>(BuildContext context, MediaType type, int id,
          String title, List<CastMember> cast, List<CrewMember> crew) =>
      push<T>(context, CreditsScreen(
          type: type, mediaId: id, mediaTitle: title, cast: cast, crew: crew));

  static Future<T?> calendar<T>(BuildContext context) =>
      push<T>(context, const CalendarScreen());

  static Future<T?> top250<T>(BuildContext context) =>
      push<T>(context, const Top250Screen());

  static Future<T?> people<T>(BuildContext context) =>
      push<T>(context, const PeopleScreen());

  static Future<T?> lists<T>(BuildContext context) =>
      push<T>(context, const ListsScreen());

  static Future<T?> watchProviders<T>(BuildContext context) =>
      push<T>(context, const ProvidersScreen());

  static Future<T?> settings<T>(BuildContext context) =>
      push<T>(context, const SettingsScreen());

  static Future<T?> about<T>(BuildContext context) =>
      push<T>(context, const AboutScreen());

  static Future<T?> legal<T>(BuildContext context, LegalKind kind) =>
      push<T>(context, LegalScreen(kind: kind));

  static Future<void> onboarding(BuildContext context) =>
      _replace(context, const OnboardingScreen());

  static void pop<T>(BuildContext context, [T? result]) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(result);
  }

  static Future<T?> _replace<T>(BuildContext context, Widget screen) =>
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
}

/// `cineva://` derin bağlantılarını ekran eşlemesine çevirir.
class DeepLinkRouter {
  DeepLinkRouter._();

  static Widget? widgetFor(CinevaLink? link) {
    if (link == null) return null;
    return switch (link.kind) {
      'media' => MediaDetailScreen(type: link.mediaType, id: link.id),
      'person' => PersonScreen(id: link.id),
      'collection' => CollectionEntry(id: link.id),
      'list' => CollectionEntry(id: link.id, asList: true),
      'search' => SearchScreen(initialQuery: link.query),
      _ => null,
    };
  }

  static Route<dynamic>? routeFor(CinevaLink? link) {
    final screen = widgetFor(link);
    if (screen == null) return null;
    return MaterialPageRoute(builder: (_) => screen);
  }
}
