import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cineva/app/deep_link.dart';
import 'package:cineva/app/providers.dart';
import 'package:cineva/app/state/discover_filters.dart';
import 'package:cineva/data/models/tmdb_models.dart';
import 'package:cineva/features/settings/settings_controller.dart';
import 'package:cineva/main.dart';

void main() {
  test('CinevaLink derin bağlantıları çözümler', () {
    final media = CinevaLink.parse('cineva://media/tv/1396');
    expect(media, isNotNull);
    expect(media!.kind, 'media');
    expect(media.mediaType, MediaType.tv);
    expect(media.id, 1396);

    expect(CinevaLink.parse('cineva://person/287')?.id, 287);
    expect(CinevaLink.parse('cineva://search/breaking%20bad')?.query, 'breaking bad');
    expect(CinevaLink.parse('https://example.com/x'), isNull);
    expect(CinevaLink.parse('cineva://media/movie'), isNull);
  });

  test('MediaSummary TMDB JSON alanlarını okur', () {
    final summary = MediaSummary.fromJson({
      'id': 603,
      'media_type': 'movie',
      'title': 'Against the Ropes',
      'poster_path': '/abc.jpg',
      'release_date': '1999-08-27',
      'vote_average': 6.4,
      'vote_count': 120,
      'genre_ids': [28, 18],
    });
    expect(summary.displayTitle, 'Against the Ropes');
    expect(summary.year, '1999');
    expect(summary.mediaType, MediaType.movie);
    expect(summary.genreIds, [28, 18]);
    expect(summary.voteAverage, 6.4);
  });

  test('DiscoverFilters varsayılanları ve aktif filtre sayısı', () {
    const f = DiscoverFilters();
    expect(f.isDefault, isTrue);
    expect(f.activeCount, 0);

    final changed = f.copyWith(genres: const [28, 878], minVoteCount: 500);
    expect(changed.isDefault, isFalse);
    expect(changed.activeCount, greaterThanOrEqualTo(2));

    final args = changed.toApiArgs(includeAdult: false);
    expect(args['withGenres'], [28, 878]);
    expect(args['voteCountGte'], 500);
    expect(args['includeAdult'], false);
    expect(changed.cleared().isDefault, isTrue);
  });

  testWidgets('Açılış ekranı uygulama adını gösterir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapProvider.overrideWith((ref) => Completer<bool>().future),
      ],
      child: const CinevaApp(),
    ));
    await tester.pump();
    expect(find.text('Cineva'), findsOneWidget);
  });
}
