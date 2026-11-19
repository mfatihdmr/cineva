# Cineva — Ekran Yazarken Uyulacak Sözleşme (AGENT NOTU)

Bu dosya yalnızca kod üretimi sırasında referanstır. **Oku ve birebir uy.**

## Genel kurallar
- Dil: Dart 3.7, Flutter 3.29. Riverpod **2.6** (codegen YOK — `StateNotifier`/`AutoDisposeNotifier`/`FutureProvider` kullan, `@riverpod` anotasyonu KULLANMA).
- Tüm kullanıcıya görünen metinler **Türkçe**, `ref.watch(l10nProvider)` üzerinden (`l.myList` gibi). Metni bilmiyorsan `l.t('Türkçe', 'English')` kullan.
- Yorum satırı yazma (yalnızca gerçekten gerekliyse tek satır). Gereksiz doc-comment yasak.
- `const` kullanabildiğin her yerde kullan.
- Ekranlar `ConsumerWidget` / `ConsumerStatefulWidget` olmalı.
- Derleme hatası bırakma: yalnızca aşağıda listelenen API'lere eriş. Başka bir alan/sınıf uydurma.
- Dosya yolu ve sınıf adı tam olarak aşağıdaki gibi olmalı (navigation.dart bunları import ediyor).

## Renk/tokan
`AppTheme.primary` (0xFF00CDB0), `AppTheme.secondary`, `AppTheme.darkBg`, `AppTheme.darkSurface`,
`AppTheme.heroScrim`, `AppTheme.cardScrim` → `lib/app/theme/app_theme.dart`.
Material 3 tema `Theme.of(context)` ile gelir; koyu/açık iki tema var, `brightness` kontrolü:
`Theme.of(context).brightness == Brightness.dark`.

## Yardımcı widgetlar — `lib/app/widgets/common.dart`
```dart
PosterCard({required MediaSummary item, double width = 118, bool showTitle = true})
MediaCarousel({required String title, required List<MediaSummary> items, VoidCallback? onSeeAll, double cardWidth = 118, bool showTitles = true})
RemoteImage({required String url, BoxFit fit = BoxFit.cover, double? width, double? height, Widget? placeholder})
ShimmerBox({double? width, double? height, BorderRadius? radius})
ScoreBadge({required double value, double size = 34})
GenreChips({required List<Genre> genres, int max = 4})
ErrorView({Object? error, VoidCallback? onRetry})
EmptyView({IconData icon, required String title, String? subtitle, Widget? action})
SectionTitle(String text, {Widget? trailing})
ViewToggleButton({required bool grid, required VoidCallback onTap})
extension MediaNav on BuildContext { void openMedia(MediaSummary m) }  // detay/person'a gider
```

## Gezinme — `lib/app/navigation.dart` (sadece bunlar var)
```dart
Nav.media(context, MediaType type, int id)
Nav.person(context, int id)
Nav.discover(context, MediaType type)
Nav.search(context, {String query = ''})
Nav.season(context, int tvId, int season)
Nav.reviews(context, MediaType type, int id)
Nav.gallery(context, MediaType type, int id, {List<ImageInfo>? images})
Nav.collection(context, int id)
Nav.company(context, int id)
Nav.keyword(context, int id, String name)
Nav.credits(context, MediaType type, int id, String title, List<CastMember> cast, List<CrewMember> crew)
Nav.calendar(context)
Nav.top250(context)
Nav.people(context)
Nav.lists(context)
Nav.watchProviders(context)
Nav.settings(context)
Nav.about(context)
Nav.legal(context, LegalKind kind)          // LegalKind: terms, privacy, licenses, tmdb
Nav.home(context) / Nav.onboarding(context) / Nav.pop(context, [result])
Nav.push(context, Widget screen)            // özel ekranlar için
```

## Durum sağlayıcıları — `lib/app/providers.dart`
```dart
// çekirdek
apiProvider -> TmdbApi
repoProvider -> TmdbRepo   // .api, .poster(path,{large}), .backdrop(path,{large}), .profile(path,{large}), .image(path,{size})
localStoreProvider -> LocalStore
l10nProvider -> L10n
themeProvider -> ThemeData, themeModeProvider -> ThemeMode, brightnessProvider -> Brightness
settingsProvider -> SettingsState (StateNotifierProvider)   // .languageCode .region .contentLanguage .showAdult .themeMode .appOpenCount .personalizedAds
localeKeyProvider -> String
bootstrapProvider -> Future<bool>
apiReadyProvider -> StateProvider<bool>

// referans
movieGenresProvider / tvGenresProvider -> FutureProvider<GenreList>
genresProvider(MediaType) -> FutureProvider.family<GenreList, MediaType>
providerCatalogProvider(String country) -> FutureProvider.family<WatchProviderCatalog, String>
countriesProvider -> FutureProvider<List<CountryInfo>>

// liste
trendingProvider((MediaType, String window)) -> family<List<MediaSummary>>   // window: 'day'|'week'
homeSectionProvider((String path, MediaType)) -> family<PagedResult<MediaSummary>>  // path: now_playing|upcoming|popular|top_rated
releaseCalendarProvider((String from, String to)) -> family<List<MediaSummary>>

// sayfalamalı (MediaPageState: items, page, hasMore, loadingMore, error)
searchResultsProvider((String query, String? type)) -> family<AsyncValue<MediaPageState>>
  // notifier'a erişim: ref.read(searchResultsProvider((q,type)).notifier).loadMore()
discoverResultsProvider -> AutoDisposeAsyncNotifierProvider<DiscoverNotifier, MediaPageState>
  // ref.watch(discoverResultsProvider) / ref.read(discoverResultsProvider.notifier).loadMore() / .reload()
relatedMediaProvider((MediaType, int id, String kind)) -> family  // kind: similar|recommendations|keyword|company|network|list
popularPeopleProvider -> AutoDisposeAsyncNotifierProvider<*, MediaPageState>
top250Provider -> AutoDisposeAsyncNotifierProvider<*, MediaPageState>

// detay
mediaDetailProvider((MediaType, int)) -> family<MediaDetail>
personDetailProvider(int) -> family<PersonDetail>
seasonProvider((int tvId, int season)) -> family<SeasonDetail>
episodeProvider((int tvId, int season, int episode)) -> family<EpisodeDetail>
collectionProvider(int) -> family<MediaDetail>
companyProvider(int) -> family<Company>
reviewsProvider((MediaType,int)) -> family<List<ReviewItem>>
imagesProvider((MediaType,int)) -> family<ImageCollection>

// kullanıcı verisi (yerel sqlite)
savedListProvider -> AutoDisposeNotifierProvider<SavedListNotifier, SavedListState>
  // state.byStatus/of(status)/countOf(status)/total ; notifier: toggle(id,type,status,summary), setStatus(...), remove(id,type), rate(id,type,summary,double), setNote(id,type,String), clearStatus(status), reload()
savedStatusProvider((MediaType,int)) -> family<String?>   // 'watchlist'|'watching'|'watched'|'favorites'|'rated'|''
savedRatingProvider((MediaType,int)) -> family<double?>
noteProvider((MediaType,int)) -> family<String?>
searchHistoryProvider -> List<String> ; searchHistoryTickProvider (tick artınca yenilenir)
followedPeopleProvider -> List<SavedPerson> ; followTickProvider ; isFollowedProvider(int) -> bool
```
Status sabitleri (yerel liste türleri): `watchlist`, `watching`, `watched`, `favorites`, `rated`.

## TmdbRepo metodları (repoProvider.api üzerinden API'ye eriş)
`TmdbApi` önemli imzaları (`lib/data/api/tmdb_api.dart`):
```dart
api.trending({MediaType mediaType, String window, int page})
api.discover({required MediaType mediaType, int page, List<int> withGenres, String sortBy, double? voteAverageGte, int? voteCountGte, String? certCountry, String? certLte, int? year, String? originalLanguage, String? withWatchProviders, int? runtimeGte, int? runtimeLte, List<int> withPeople, List<int> withCompanies, List<int> withNetworks, List<int> withKeywords, String? releaseDateGte, String? releaseDateLte, bool? includeAdult, String? withGenresLogic})
api.searchMovies/searchTv/searchPeople/searchMulti(query, {page})
api.movieDetail(id) / tvDetail(id) / mediaDetail(id, type)  // append_to_response dolu gelir
api.personDetail(id) / seasonDetail(tvId, season) / episodeDetail(tvId, s, e)
api.similar(type,id,{page}) / recommendations(type,id,{page})
api.reviews(type,id,{page}) -> PagedResult<ReviewItem>
api.images(type,id) -> ImageCollection
api.genres(type) -> GenreList
api.companyDetail(id) -> Company ; api.companyMovies(id) ; api.networkTv(id) ; api.keywordMovies(id)
api.providers({String watchRegion}) -> WatchProviderCatalog
api.releases({region, startDate, endDate}) ; api.nowPlaying ; api.upcoming ; api.popular ; api.topRated
api.collections? YOK — collectionDetail(id) -> MediaDetail
api.image(path,{size}) / poster / backdrop / profile / logo / still
```

## Modeller — `lib/data/models/tmdb_models.dart`
`MediaType { movie, tv, person }` + `MediaTypeX` (`apiPath`, `label`, `fromApi`).
`MediaSummary`: id, mediaType, title, originalTitle, overview, posterPath, backdropPath, voteAverage(double?), voteCount(int), popularity(double), adult, originalLanguage, genreIds(List<int>), releaseDate(String?), characters(List<String>) — getter: `displayTitle`, `year`.
`MediaDetail`: id, mediaType, title, originalTitle, overview, tagline, posterPath, backdropPath, voteAverage, voteCount, runtime, releaseDate, status, originalLanguage, `List<Genre> genres`, `List<Company> productionCompanies`, productionCountries, `List<VideoInfo> videos`, `Credits credits`, `List<MediaSummary> similar`, `List<MediaSummary> recommendations`, `ImageCollection images`, `List<CertificationInfo> certifications`, `Map<String,ReleaseRegion> releases`, homepage, imdbId, popularity, adult, budget, revenue, `List<Keyword> keywords`, `List<SeasonSummary> seasons`, episodeRunTime, createdBy, originCountry, `List<ReviewItem> reviews`, `MediaSummary? belongsToCollection`, `ProviderResults providers`.
`PersonDetail`: id, name, alsoKnownAs(List<String>), biography, birthday, deathday, age, placeOfBirth, homepage, profilePath, popularity, adult, knownForDepartment, `List<MediaSummary> combinedCredits`, `ImageCollection images`, taggedProfiles, `ExternalIds externalIds`.
`SeasonDetail`: id, name, overview, posterPath, airDate, seasonNumber, `List<EpisodeDetail> episodes`.
`EpisodeDetail`: id, episodeNumber, seasonNumber, name, overview, stillPath, airDate, runtime, voteAverage, voteCount, cast, crew, videos.
`Credits`: cast(`List<CastMember>`), crew(`List<CrewMember>`), `departments`, `byDepartment(dep)`.
`CastMember`: id, name, character, originalName, profilePath, order, creditId, mediaType (`creditType`).
`CrewMember`: id, name, job, department, profilePath, creditId.
`ImageCollection`: backdrops, posters, logos, profiles, stills (hepsi `List<ImageInfo>`); `ImageInfo`: filePath, width, height, language, aspectRatio, type.
`VideoInfo`: id, key, name, site, type, official, publishedAt, `isYouTube`, `isTrailer`, `thumbnailUrl`, `youtubeUrl`.
`ReviewItem`: id, author, content, url, updatedAt, rating; `shortContent`.
`Genre`: id, name. `GenreList`: genres, `nameOf(id)`.
`Company`: id, name, logoPath, originCountry, description, headquarters, homepage, parentCompanyId.
`Keyword`: id, name. `ExternalIds`: imdbId, tvdbId, ... `socialLinks` → `List<(String label, String url)>`.
`WatchProviderEntry`: providerId, providerName, logoPath, displayPriority.
`RegionProviders`: flatrate, rent, buy (`List<WatchProviderEntry>`), `isEmpty`.
`ProviderResults`: `byCountry` Map<String,RegionProviders>, `region(String code)`.
`WatchProviderCatalog`: flatrate/rent/buy Map<String,List<WatchProviderEntry>>, `allFor(country)`.
`ReleaseRegion`: country, entries(List<ReleaseDateEntry>); `ReleaseDateEntry`: type, date, certification, `typeLabel`.
`CertificationInfo`: country, certification, meaning.
`SeasonSummary`: seasonNumber, name, overview, posterPath, airDate, episodeCount.
`SavedItem` (local_store.dart): mediaType, mediaId, title, posterPath, releaseDate, voteAverage, status, rating, note, addedAt; `toSummary()`.
`SavedPerson`: id, name, profilePath.
`MovieListItem`: id, name, description, itemCount, posterPath, username, language, type, favoriteCount.
`PagedResult<T>`: page, totalPages, totalResults, results, `hasMore`.
`TmdbException` (api dosyasında): message, statusCode, isNetwork.

## L10n — `lib/app/l10n/l10n.dart`
`l = ref.watch(l10nProvider)`; alanlar: appName, retry, loading, emptyTitle, emptySub, offline, cancel, close, save, share, seeAll, more, searchHint, results, noResults, noResultsSub, errorTitle, tabDiscover, tabSearch, tabList, tabSettings, movies, series, people, companies, collections, keywords, lists, trending, trendingToday, trendingWeek, nowPlaying, upcoming, popular, topRated, recommended, calendar, top250, similar, recommendations, becauseYouWatched, overview, readMore, readLess, cast, crew, trailer, videos, photos, gallery, reviews, whereToWatch, streaming, rent, buy, productionCompanies, facts, keywordsLabel, seasons, episodes, episode, season, belongsToCollection, credits, knownFor, personalInfo, birthday, deathday, birthplace, alsoKnownAs, externalLinks, runtime, status, originalTitle, originalLanguage, releaseDate, firstAir, lastAir, budget, revenue, imdb, tmdbPage, ageRating, audienceScore, votes, myList, watchlist, watching, watched, favorites, myRatings, history, addToList, markWatched, rateIt, yourRating, remove, addedTo, removedFrom, emptyListBody, searchHistory, clearHistory, filters, sort, genre, year, minRating, minVotes, maxDuration, minDuration, language, country, providerFilter, ageFilter, personFilter, companyFilter, keywordFilter, apply, reset, anyValue, releaseRange, from, to, `sortByLabel(String)`, settings, appearance, themeMode, themeSystem, themeLight, themeDark, content, languageRegion, showAdult, showAdultSub, data, clearCache, clearCacheSub, about, aboutApp, terms, privacy, openSource, versionInfo, feedback, rateApp, notifications, followPeople, myLists, tmdbAccount, signIn, signOut, signedInAs, ads, adsSub, personalizedAds, onboardingTitle, onboardingSub, start, pickLanguage, pickRegion, permissionNote.

## Reklam — `lib/app/ads.dart`
```dart
BannerSlot({AdSize size})   // widget, boşsa hiçbir şey çizmez
InlineAdBanner()            // liste arasına göm
AnchoredBanner()            // ekran altı sabit
adsEnabledProvider -> bool
InterstitialAdManager.instance.preload() / .maybeShow()
```
Listelerde her 10 öğede bir `InlineAdBanner()` göster.

## Biçimlendirme yardımcıları (kendi dosyanda tanımla, tekrar etme)
- Puan: `'${(v! * 10).round()}%'`
- Süre: `if (m > 0) '${m ~/ 60}s ${m % 60}dk' else '-'`
- Para: `'₺${NumberFormat('#,##0').format(value)}'` → intl `NumberFormat` kullan.
- Tarih: `DateFormat('d MMMM yyyy', 'tr')` — `intl` mevcut; `date_tr.dart` içinde bir `formatDate(String?)` helper varsa onu kullan, yoksa kendi dosyanda yaz.

## Dosya haritası (her ekran kendi klasöründe)
```
lib/features/home/home_shell.dart        class HomeShell extends ConsumerStatefulWidget
lib/features/home/home_page.dart         class HomePage extends ConsumerStatefulWidget
lib/features/search/search_screen.dart   class SearchScreen extends ConsumerStatefulWidget ({String initialQuery})
lib/features/discover/discover_screen.dart class DiscoverScreen ({MediaType initialType})
lib/features/discover/widgets.dart        (FilterSheet vb.)
lib/features/mylist/my_list_screen.dart  class MyListScreen extends ConsumerStatefulWidget
lib/features/media/media_detail_screen.dart class MediaDetailScreen({required MediaType type, required int id})
lib/features/media/widgets.dart           (HeroPoster, MetaRow, ...)
lib/features/person/person_screen.dart    class PersonScreen({required int id})
lib/features/season/season_screen.dart    class SeasonScreen({required int tvId, required int seasonNumber})
lib/features/gallery/gallery_screen.dart  class GalleryScreen({required MediaType type, required int id, List<ImageInfo>? images})
lib/features/reviews/reviews_screen.dart  class ReviewsScreen({required MediaType type, required int id})
lib/features/credits/credits_screen.dart  class CreditsScreen({required MediaType type, required int mediaId, required String mediaTitle, required List<CastMember> cast, required List<CrewMember> crew})
lib/features/company/company_screen.dart  class CompanyScreen({required int id}) + collection ekranı da burada: class CollectionEntry({required int id, bool asList = false})
lib/features/keyword/keyword_screen.dart  class KeywordScreen({required int id, required String name})
lib/features/calendar/calendar_screen.dart class CalendarScreen extends ConsumerWidget
lib/features/top250/top250_screen.dart    class Top250Screen extends ConsumerWidget
lib/features/people/people_screen.dart    class PeopleScreen extends ConsumerWidget
lib/features/lists/lists_screen.dart      class ListsScreen extends ConsumerWidget
lib/features/watch/providers_screen.dart  class ProvidersScreen extends ConsumerWidget
lib/features/settings/settings_screen.dart class SettingsScreen extends ConsumerWidget
lib/features/about/about_screen.dart      class AboutScreen extends ConsumerWidget
lib/features/legal/legal_screen.dart      class LegalScreen({required LegalKind kind}) + enum LegalKind { terms, privacy, licenses, tmdb }
lib/features/onboarding/onboarding_screen.dart class OnboardingScreen extends ConsumerStatefulWidget
```

## Kalıplar
### AsyncValue görünümü
```dart
ref.watch(mediaDetailProvider((widget.type, widget.id))).when(
  loading: () => const SkeletonDetail(),
  error: (e, st) => ErrorView(error: e, onRetry: () => ref.invalidate(mediaDetailProvider((widget.type, widget.id)))),
  data: (d) => RealBody(d),
)
```
### Sayfalamalı liste
```dart
NotificationListener<ScrollNotification>(
  onNotification: (n) {
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
      ref.read(top250Provider.notifier).loadMore();
    }
    return false;
  },
  child: GridView.builder(...)
)
```
### Paylaşım
`share_plus` BAĞIMLILIĞI YOK. `url_launcher` var: `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`.
Metin kopyalama için `Clipboard.setData` (services) + SnackBar.

### Kaydetme butonu (detay ekranında)
```dart
final status = ref.watch(savedStatusProvider((type, id))).valueOrNull;
ref.read(savedListProvider.notifier).toggle(id, type, 'watchlist', summary);
```

## Yapılacaklar listesi mantığı
Bottom bar 4 sekme: Keşfet(HomePage), Ara(SearchScreen), Listem(MyListScreen), Ayarlar(SettingsScreen).
IndexedStack ile durum korunur.
