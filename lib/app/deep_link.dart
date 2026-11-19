import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models/tmdb_models.dart';

/// `android/local.properties` yerine intent üzerinden gelen bağlantıyı okur.
class CinevaLink {
  final String kind; // media | person | collection | list | search
  final MediaType mediaType;
  final int id;
  final String query;

  const CinevaLink({
    required this.kind,
    this.mediaType = MediaType.movie,
    this.id = 0,
    this.query = '',
  });

  /// Örnekler:
  ///   cineva://media/movie/603
  ///   cineva://media/tv/1396
  ///   cineva://person/287
  ///   cineva://collection/10
  ///   cineva://search/breaking
  static CinevaLink? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != 'cineva' && uri.scheme != 'tmdb') return null;
    final parts = uri.host.isNotEmpty
        ? [uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    if (parts.isEmpty) return null;
    final kind = parts.first;
    int asInt(String s) => int.tryParse(s) ?? 0;
    switch (kind) {
      case 'media':
        if (parts.length < 3) return null;
        return CinevaLink(
          kind: 'media',
          mediaType: MediaTypeX.fromApi(parts[1]),
          id: asInt(parts[2]),
        );
      case 'person':
        return parts.length < 2 ? null : CinevaLink(kind: 'person', id: asInt(parts[1]));
      case 'collection':
        return parts.length < 2 ? null : CinevaLink(kind: 'collection', id: asInt(parts[1]));
      case 'list':
        return parts.length < 2 ? null : CinevaLink(kind: 'list', id: asInt(parts[1]));
      case 'search':
        return CinevaLink(kind: 'search', query: Uri.decodeComponent(parts.length > 1 ? parts[1] : ''));
    }
    return null;
  }

  String get shareUrl => switch (kind) {
        'media' => 'https://www.themoviedb.org/${mediaType.apiPath}/$id',
        'person' => 'https://www.themoviedb.org/person/$id',
        'collection' => 'https://www.themoviedb.org/collection/$id',
        _ => 'https://www.themoviedb.org',
      };
}

/// Android tarafından gelen niyet verisini okur (web'de her zaman null).
Future<CinevaLink?> readIncomingLink() async {
  if (kIsWeb) return null;
  const channel = MethodChannel('app.cineva.cineva/deeplink');
  try {
    final value = await channel.invokeMethod<String>('getInitialLink');
    return CinevaLink.parse(value);
  } catch (_) {
    return null;
  }
}
