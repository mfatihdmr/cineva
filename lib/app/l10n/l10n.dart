/// Hafif çok dilli destek (Türkçe varsayılan, İngilizce yedek).
class L10n {
  final String languageCode;
  const L10n(this.languageCode);

  bool get isTr => languageCode.startsWith('tr');

  String t(String tr, String en) => isTr ? tr : en;

  // ── Genel ──
  String get appName => 'Cineva';
  String get retry => t('Tekrar dene', 'Retry');
  String get loading => t('Yükleniyor…', 'Loading…');
  String get emptyTitle => t('Burulacak bir şey yok', 'Nothing here yet');
  String get emptySub => t('Bağlantını kontrol edip tekrar deneyebilirsin.',
      'Check your connection and try again.');
  String get offline => t('Çevrimdışı', 'Offline');
  String get cancel => t('Vazgeç', 'Cancel');
  String get close => t('Kapat', 'Close');
  String get save => t('Kaydet', 'Save');
  String get share => t('Paylaş', 'Share');
  String get seeAll => t('Tümünü gör', 'See all');
  String get more => t('Devamı', 'More');
  String get searchHint => t('Film, dizi veya kişi ara', 'Search movies, shows or people');
  String get results => t('Sonuçlar', 'Results');
  String get noResults => t('Sonuç bulunamadı', 'No results found');
  String get noResultsSub => t('Farklı bir kelime veya yazım deneyin.',
      'Try a different word or spelling.');
  String get errorTitle => t('Bir şeyler ters gitti', 'Something went wrong');

  // ── Sekmeler ──
  String get tabDiscover => t('Keşfet', 'Discover');
  String get tabSearch => t('Ara', 'Search');
  String get tabList => t('Listem', 'My list');
  String get tabSettings => t('Ayarlar', 'Settings');

  // ── Medya ──
  String get movies => t('Filmler', 'Movies');
  String get series => t('Diziler', 'TV Shows');
  String get people => t('Kişiler', 'People');
  String get companies => t('Şirketler', 'Companies');
  String get collections => t('Koleksiyonlar', 'Collections');
  String get keywords => t('Anahtar Kelimeler', 'Keywords');
  String get lists => t('Listeler', 'Lists');

  String get trending => t('Trendler', 'Trending');
  String get trendingToday => t('Bugün', 'Today');
  String get trendingWeek => t('Bu hafta', 'This week');
  String get nowPlaying => t('Sinemalarda', 'In cinemas');
  String get upcoming => t('Yakında', 'Coming soon');
  String get popular => t('Popüler', 'Popular');
  String get topRated => t('En yüksek puanlı', 'Top rated');
  String get recommended => t('Sana özel', 'For you');
  String get calendar => t('Yayın takvimi', 'Release calendar');
  String get top250 => t('En iyi 250', 'Top 250');
  String get similar => t('Benzer içerikler', 'More like this');
  String get recommendations => t('Tavsiyeler', 'Recommendations');
  String get becauseYouWatched => t('İzlediklerine benzer', 'Because you watched');

  String get overview => t('Konusu', 'Overview');
  String get readMore => t('Devamı', 'Read more');
  String get readLess => t('Daha az', 'Read less');
  String get cast => t('Oyuncular', 'Cast');
  String get crew => t('Kamera ekibi', 'Crew');
  String get trailer => t('Fragman', 'Trailer');
  String get videos => t('Videolar', 'Videos');
  String get photos => t('Görseller', 'Photos');
  String get gallery => t('Galeri', 'Gallery');
  String get reviews => t('İncelemeler', 'Reviews');
  String get whereToWatch => t('Nerede izlenir?', 'Where to watch');
  String get streaming => t('Dijital platform', 'Stream');
  String get rent => t('Kiralama', 'Rent');
  String get buy => t('Satın alma', 'Buy');
  String get productionCompanies => t('Yapım şirketleri', 'Production companies');
  String get facts => t('Künye', 'Facts');
  String get keywordsLabel => t('İpuçları', 'Keywords');
  String get seasons => t('Sezonlar', 'Seasons');
  String get episodes => t('Bölümler', 'Episodes');
  String get episode => t('Bölüm', 'Episode');
  String get season => t('Sezon', 'Season');
  String get belongsToCollection => t('Serinin parçası', 'Part of collection');
  String get credits => t('Krediler', 'Credits');
  String get knownFor => t('Bilinen yapımlar', 'Known for');
  String get personalInfo => t('Kişisel bilgi', 'Personal info');
  String get birthday => t('Doğum', 'Born');
  String get deathday => t('Ölüm', 'Died');
  String get birthplace => t('Doğum yeri', 'Birthplace');
  String get alsoKnownAs => t('Diğer adları', 'Also known as');
  String get externalLinks => t('Bağlantılar', 'Links');

  String get runtime => t('Süre', 'Runtime');
  String get status => t('Durum', 'Status');
  String get originalTitle => t('Orijinal ad', 'Original title');
  String get originalLanguage => t('Orijinal dil', 'Original language');
  String get releaseDate => t('Gösterim tarihi', 'Release date');
  String get firstAir => t('İlk yayın', 'First aired');
  String get lastAir => t('Son yayın', 'Last aired');
  String get budget => t('Bütçe', 'Budget');
  String get revenue => t('Hasılat', 'Revenue');
  String get imdb => t('IMDb sayfası', 'IMDb page');
  String get tmdbPage => t('TMDB sayfası', 'TMDB page');
  String get ageRating => t('Yaş sınırı', 'Age rating');
  String get audienceScore => t('Seyirci puanı', 'Audience score');
  String get votes => t('oy', 'votes');

  // ── Listeler / kullanıcı ──
  String get myList => t('Listem', 'My list');
  String get watchlist => t('İstediğim', 'Watchlist');
  String get watching => t('İzliyorum', 'Watching');
  String get watched => t('İzledim', 'Watched');
  String get favorites => t('Favoriler', 'Favorites');
  String get myRatings => t('Puanlarım', 'My ratings');
  String get history => t('Geçmiş', 'History');
  String get addToList => t('Listeye ekle', 'Add to list');
  String get markWatched => t('İzledim olarak işaretle', 'Mark as watched');
  String get rateIt => t('Puan ver', 'Rate it');
  String get yourRating => t('Puanın', 'Your rating');
  String get remove => t('Listeden çıkar', 'Remove');
  String get addedTo => t('listesine eklendi', 'list added');
  String get removedFrom => t('listesinden çıkarıldı', 'list removed');
  String get emptyListBody => t('Henüz bir şey eklemedin.', 'You have not added anything yet.');
  String get searchHistory => t('Son aramalar', 'Recent searches');
  String get clearHistory => t('Aramaları temizle', 'Clear searches');

  // ── Keşif filtreleri ──
  String get filters => t('Filtreler', 'Filters');
  String get sort => t('Sıralama', 'Sort');
  String get genre => t('Tür', 'Genre');
  String get year => t('Yıl', 'Year');
  String get minRating => t('En az puan', 'Min rating');
  String get minVotes => t('En az oy sayısı', 'Min votes');
  String get maxDuration => t('En fazla süre', 'Max runtime');
  String get minDuration => t('En az süre', 'Min runtime');
  String get language => t('Dil', 'Language');
  String get country => t('Ülke', 'Country');
  String get providerFilter => t('Platform', 'Provider');
  String get ageFilter => t('Yaş sınırı', 'Certification');
  String get personFilter => t('Kişi', 'People');
  String get companyFilter => t('Şirket', 'Company');
  String get keywordFilter => t('Anahtar kelime', 'Keyword');
  String get apply => t('Uygula', 'Apply');
  String get reset => t('Temizle', 'Reset');
  String get anyValue => t('Fark etmez', 'Any');
  String get releaseRange => t('Tarih aralığı', 'Date range');
  String get from => t('Başlangıç', 'From');
  String get to => t('Bitiş', 'To');

  String sortByLabel(String key) {
    const tr = {
      'popularity.desc': 'Popülerlik',
      'popularity.asc': 'Popülerlik (artan)',
      'vote_average.desc': 'Puan',
      'vote_count.desc': 'Oy sayısı',
      'primary_release_date.desc': 'Gösterim tarihi',
      'first_air_date.desc': 'İlk yayın tarihi',
      'revenue.desc': 'Hasılat',
      'budget.desc': 'Bütçe',
      'original_title.asc': 'Ad (A→Z)',
      'title.asc': 'Ad (A→Z)',
      'adult.desc': 'Yetişkin içeriğe göre',
      'cast_normalizing_popularity.desc': 'Kadro popülerliği',
      'certified.popularity.desc': 'Sertifika popularitesi',
      'watchability.popularity.desc': 'İzlenebilirlik',
      'theta_surreal_popularity.desc': 'Sürreal popülerlik',
    };
    const en = {
      'popularity.desc': 'Popularity',
      'popularity.asc': 'Popularity (asc)',
      'vote_average.desc': 'Rating',
      'vote_count.desc': 'Vote count',
      'primary_release_date.desc': 'Release date',
      'first_air_date.desc': 'First air date',
      'revenue.desc': 'Revenue',
      'budget.desc': 'Budget',
      'original_title.asc': 'Title (A→Z)',
      'title.asc': 'Title (A→Z)',
      'adult.desc': 'Adult content',
      'cast_normalizing_popularity.desc': 'Cast popularity',
      'certified.popularity.desc': 'Certification popularity',
      'watchability.popularity.desc': 'Watchability',
      'theta_surreal_popularity.desc': 'Surreal popularity',
    };
    final map = isTr ? tr : en;
    return map[key] ?? key.replaceAll('.desc', isTr ? ' (↓)' : ' (desc)');
  }

  // ── Ayarlar ──
  String get settings => t('Ayarlar', 'Settings');
  String get appearance => t('Görünüm', 'Appearance');
  String get themeMode => t('Tema', 'Theme');
  String get themeSystem => t('Sistem', 'System');
  String get themeLight => t('Açık', 'Light');
  String get themeDark => t('Koyu', 'Dark');
  String get content => t('İçerik', 'Content');
  String get languageRegion => t('Dil ve bölge', 'Language & region');
  String get showAdult => t('Yetişkin içeriği göster', 'Show adult content');
  String get showAdultSub => t('18+ filmler ve diziler listelerde görünür.',
      '18+ titles appear in lists.');
  String get data => t('Veri', 'Data');
  String get clearCache => t('Görsel önbelleğini temizle', 'Clear image cache');
  String get clearCacheSub => t('Diskten yer açar.', 'Frees up disk space.');
  String get about => t('Hakkında', 'About');
  String get aboutApp => t('Cineva hakkında', 'About Cineva');
  String get terms => t('Kullanım koşulları', 'Terms of use');
  String get privacy => t('Gizlilik politikası', 'Privacy policy');
  String get openSource => t('Açık kaynak lisansları', 'Open source licenses');
  String get versionInfo => t('Sürüm', 'Version');
  String get feedback => t('Geri bildirim gönder', 'Send feedback');
  String get rateApp => t('Uygulamayı puanla', 'Rate the app');
  String get notifications => t('Bildirimler', 'Notifications');
  String get followPeople => t('Takip edilen kişiler', 'Followed people');
  String get myLists => t('TMDB listelerim', 'My TMDB lists');
  String get tmdbAccount => t('TMDB hesabı', 'TMDB account');
  String get signIn => t('TMDB ile giriş yap', 'Sign in with TMDB');
  String get signOut => t('Çıkış yap', 'Sign out');
  String get signedInAs => t('Giriş yapılan hesap', 'Signed in as');
  String get ads => t('Reklamlar', 'Ads');
  String get adsSub => t('Reklamlar uygulamayı ücretsiz tutar.',
      'Ads keep the app free.');
  String get personalizedAds => t('Kişiselleştirilmiş reklamlar', 'Personalized ads');

  // ── Başlangıç ──
  String get onboardingTitle => t('Sinema dünyası avucunda', 'The movie world in your hand');
  String get onboardingSub => t('700.000+ film ve dizi; trendler, puanlar, '
      'izleme rehberi ve kendi listen.', '700,000+ movies and shows; trends, '
      'scores, where to watch and your own list.');
  String get start => t('Başla', 'Get started');
  String get pickLanguage => t('Dilini seç', 'Choose your language');
  String get pickRegion => t('Ülkeni seç', 'Choose your country');
  String get permissionNote => t('Cineva yalnızca TMDB verilerini okur; '
      'hiçbir kişisel verin sunucularımıza gönderilmez.',
      'Cineva only reads TMDB data; no personal data is sent to our servers.');
}
