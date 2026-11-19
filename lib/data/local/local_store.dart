import 'dart:io' show Directory;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/tmdb_models.dart';

/// Kullanıcı listesi (izleme/izledim/favori), puan ve arama geçmişi için
/// tamamen yerel veritabanı. Hiçbir veri sunucuya gönderilmez.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  Database? _db;
  static const _dbVersion = 2;

  bool get available => _db != null;

  Future<String> _dbPath() async {
    if (kIsWeb) return p.join(Directory.systemTemp.path, 'cineva_memory.db');
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'cineva_data.db');
  }

  Future<void> open() async {
    if (_db != null) return;
    try {
      _db = await openDatabase(
        await _dbPath(),
        version: _dbVersion,
        onCreate: _create,
        onUpgrade: _upgrade,
      );
    } catch (e) {
      debugPrint('[LocalStore] açılamadı: $e');
      _db = null;
    }
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE saved_media(
        media_type TEXT NOT NULL,
        media_id INTEGER NOT NULL,
        title TEXT,
        poster_path TEXT,
        release_date TEXT,
        vote_average REAL,
        status TEXT DEFAULT 'watchlist',
        rating REAL,
        added_at INTEGER NOT NULL,
        note TEXT DEFAULT '',
        PRIMARY KEY(media_type, media_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_saved_status ON saved_media(status, added_at DESC)');
    await db.execute('''
      CREATE TABLE search_history(
        term TEXT PRIMARY KEY,
        searched_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE followed_people(
        person_id INTEGER PRIMARY KEY,
        name TEXT,
        profile_path TEXT,
        followed_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE notes(
        media_type TEXT NOT NULL,
        media_id INTEGER NOT NULL,
        body TEXT,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(media_type, media_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE cached_response(
        cache_key TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('ALTER TABLE saved_media ADD COLUMN note TEXT DEFAULT ""');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes(
          media_type TEXT NOT NULL, media_id INTEGER NOT NULL,
          body TEXT, updated_at INTEGER NOT NULL,
          PRIMARY KEY(media_type, media_id))
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_response(
          cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, saved_at INTEGER NOT NULL)
      ''');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ─────────────── KAYDEDİLEN İÇERİK ───────────────

  Future<void> upsertSaved(MediaSummary m, {String status = 'watchlist'}) async {
    final db = _db;
    if (db == null) return;
    await db.insert('saved_media', {
      'media_type': m.mediaType.apiPath,
      'media_id': m.id,
      'title': m.displayTitle,
      'poster_path': m.posterPath,
      'release_date': m.releaseDate,
      'vote_average': m.voteAverage,
      'status': status,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeSaved(int id, String type) async {
    await _db?.delete('saved_media',
        where: 'media_type = ? AND media_id = ?', whereArgs: [type, id]);
  }

  Future<void> setStatus(int id, String type, String status) async {
    final db = _db;
    if (db == null) return;
    final existing = await db.query('saved_media',
        where: 'media_type = ? AND media_id = ?', whereArgs: [type, id], limit: 1);
    if (existing.isEmpty) return;
    await db.update('saved_media', {'status': status},
        where: 'media_type = ? AND media_id = ?', whereArgs: [type, id]);
  }

  Future<void> removeStatus(int id, String type, String status) async {
    final db = _db;
    if (db == null) return;
    if (status == 'watchlist') {
      await db.delete('saved_media',
          where: 'media_type = ? AND media_id = ?', whereArgs: [type, id]);
      return;
    }
    await db.update('saved_media', {'status': ''},
        where: 'media_type = ? AND media_id = ? AND status = ?',
        whereArgs: [type, id, status]);
  }

  Future<void> setRating(int id, String type, double? rating) async {
    final db = _db;
    if (db == null) return;
    final existing = await db.query('saved_media',
        where: 'media_type = ? AND media_id = ?', whereArgs: [type, id], limit: 1);
    if (existing.isEmpty) {
      if (rating == null) return;
      await db.insert('saved_media', {
        'media_type': type,
        'media_id': id,
        'rating': rating,
        'status': 'rated',
        'added_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    await db.update(
      'saved_media',
      {'rating': rating, if (rating != null) 'status': 'rated'},
      where: 'media_type = ? AND media_id = ?',
      whereArgs: [type, id],
    );
  }

  Future<double?> ratingOf(int id, String type) async {
    final rows = await _db?.query('saved_media',
        columns: ['rating'],
        where: 'media_type = ? AND media_id = ?',
        whereArgs: [type, id],
        limit: 1);
    if (rows == null || rows.isEmpty) return null;
    final v = rows.first['rating'];
    return v is num ? v.toDouble() : null;
  }

  Future<String?> statusOf(int id, String type) async {
    final rows = await _db?.query('saved_media',
        columns: ['status'],
        where: 'media_type = ? AND media_id = ?',
        whereArgs: [type, id],
        limit: 1);
    if (rows == null || rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<List<SavedItem>> savedByStatus(List<String> statuses) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('saved_media',
        where: 'status IN (${statuses.map((_) => '?').join(',')})',
        whereArgs: statuses,
        orderBy: 'added_at DESC');
    return rows.map(SavedItem.fromRow).toList();
  }

  Future<List<SavedItem>> allSaved() async {
    final rows = await _db?.query('saved_media', orderBy: 'added_at DESC');
    return (rows ?? const []).map(SavedItem.fromRow).toList();
  }

  Future<Map<String, int>> statusCounts() async {
    final db = _db;
    if (db == null) return const {};
    final rows = await db.rawQuery(
        'SELECT status, COUNT(*) AS c FROM saved_media GROUP BY status');
    return {for (final r in rows) (r['status'] as String? ?? ''): r['c'] as int};
  }

  // ─────────────── NOT ───────────────

  Future<void> setNote(int id, String type, String body) async {
    final db = _db;
    if (db == null) return;
    if (body.trim().isEmpty) {
      await db.delete('notes', where: 'media_type=? AND media_id=?', whereArgs: [type, id]);
      await db.update('saved_media', {'note': ''},
          where: 'media_type=? AND media_id=?', whereArgs: [type, id]);
      return;
    }
    await db.insert('notes', {
      'media_type': type,
      'media_id': id,
      'body': body,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.update('saved_media', {'note': body},
        where: 'media_type=? AND media_id=?', whereArgs: [type, id]);
  }

  Future<String?> noteFor(int id, String type) async {
    final rows = await _db?.query('notes',
        columns: ['body'], where: 'media_type=? AND media_id=?', whereArgs: [type, id], limit: 1);
    if (rows == null || rows.isEmpty) return null;
    return rows.first['body'] as String?;
  }

  // ─────────────── ARAMA GEÇMİŞİ ───────────────

  Future<void> pushSearch(String term) async {
    final db = _db;
    final clean = term.trim();
    if (db == null || clean.length < 2) return;
    await db.insert('search_history', {'term': clean, 'searched_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace);
    final all = await db.query('search_history', columns: ['term'], orderBy: 'searched_at DESC');
    if (all.length > 20) {
      final extra = all.skip(20).map((r) => r['term'] as String).toList();
      await db.delete('search_history',
          where: 'term IN (${extra.map((_) => '?').join(',')})', whereArgs: extra);
    }
  }

  Future<List<String>> searchHistory() async {
    final rows = await _db?.query('search_history',
        columns: ['term'], orderBy: 'searched_at DESC', limit: 12);
    return (rows ?? const []).map((r) => r['term'] as String).toList();
  }

  Future<void> removeSearch(String term) async {
    await _db?.delete('search_history', where: 'term = ?', whereArgs: [term]);
  }

  Future<void> clearSearchHistory() async {
    await _db?.delete('search_history');
  }

  // ─────────────── TAKİP EDİLEN KİŞİLER ───────────────

  Future<bool> toggleFollow(int personId, String name, String? profilePath) async {
    final db = _db;
    if (db == null) return false;
    final exists = await db.query('followed_people', where: 'person_id = ?', whereArgs: [personId], limit: 1);
    if (exists.isEmpty) {
      await db.insert('followed_people', {
        'person_id': personId,
        'name': name,
        'profile_path': profilePath,
        'followed_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    }
    await db.delete('followed_people', where: 'person_id = ?', whereArgs: [personId]);
    return false;
  }

  Future<List<SavedPerson>> followedPeople() async {
    final rows = await _db?.query('followed_people', orderBy: 'followed_at DESC');
    return (rows ?? const []).map(SavedPerson.fromRow).toList();
  }

  Future<bool> isFollowed(int personId) async {
    final rows = await _db?.query('followed_people', where: 'person_id = ?', whereArgs: [personId], limit: 1);
    return rows != null && rows.isNotEmpty;
  }

  // ─────────────── API YANIT ÖNBELLEĞİ ───────────────

  Future<void> cacheJson(String key, String payload) async {
    await _db?.insert('cached_response', {
      'cache_key': key,
      'payload': payload,
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readCache(String key, {Duration maxAge = const Duration(days: 3)}) async {
    final rows = await _db?.query('cached_response',
        columns: ['payload', 'saved_at'], where: 'cache_key = ?', whereArgs: [key], limit: 1);
    if (rows == null || rows.isEmpty) return null;
    final savedAt = rows.first['saved_at'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - savedAt > maxAge.inMilliseconds) return null;
    return rows.first['payload'] as String?;
  }

  Future<void> clearCache() async {
    await _db?.delete('cached_response');
  }

  Future<int> cacheSizeBytes() async {
    final rows = await _db?.rawQuery('SELECT SUM(LENGTH(payload)) AS s FROM cached_response');
    if (rows == null || rows.isEmpty) return 0;
    return (rows.first['s'] as int?) ?? 0;
  }
}

class SavedItem {
  final MediaType mediaType;
  final int mediaId;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double? voteAverage;
  final String status;
  final double? rating;
  final String note;
  final DateTime addedAt;

  const SavedItem({
    required this.mediaType,
    required this.mediaId,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.voteAverage,
    required this.status,
    this.rating,
    this.note = '',
    required this.addedAt,
  });

  factory SavedItem.fromRow(Map<String, Object?> r) => SavedItem(
        mediaType: MediaTypeX.fromApi(r['media_type'] as String?),
        mediaId: (r['media_id'] as num?)?.toInt() ?? 0,
        title: (r['title'] as String?) ?? '',
        posterPath: r['poster_path'] as String?,
        releaseDate: r['release_date'] as String?,
        voteAverage: (r['vote_average'] as num?)?.toDouble(),
        status: (r['status'] as String?) ?? 'watchlist',
        rating: (r['rating'] as num?)?.toDouble(),
        note: (r['note'] as String?) ?? '',
        addedAt: DateTime.fromMillisecondsSinceEpoch((r['added_at'] as num?)?.toInt() ?? 0),
      );

  MediaSummary toSummary() => MediaSummary(
        id: mediaId,
        mediaType: mediaType,
        title: title,
        originalTitle: title,
        posterPath: posterPath,
        voteAverage: voteAverage,
        releaseDate: releaseDate,
      );
}

class SavedPerson {
  final int id;
  final String name;
  final String? profilePath;
  const SavedPerson({required this.id, required this.name, this.profilePath});

  factory SavedPerson.fromRow(Map<String, Object?> r) => SavedPerson(
        id: (r['person_id'] as num?)?.toInt() ?? 0,
        name: (r['name'] as String?) ?? '',
        profilePath: r['profile_path'] as String?,
      );
}
