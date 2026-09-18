class UserSession {
  const UserSession({
    required this.id,
    required this.username,
    this.fullName,
    this.permissions = const [],
  });

  final String id;
  final String username;
  final String? fullName;
  final List<String> permissions;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    return UserSession(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      fullName: json['fullName'] as String? ?? json['full_name'] as String?,
      permissions: perms is List
          ? perms.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class FilmCard {
  const FilmCard({
    required this.slug,
    required this.name,
    this.originalName,
    this.thumbUrl,
    this.posterUrl,
    this.year,
    this.quality,
    this.language,
    this.currentEpisode,
    this.avgRating = 0,
    this.ratingCount = 0,
    this.description,
  });

  final String slug;
  final String name;
  final String? originalName;
  final String? thumbUrl;
  final String? posterUrl;
  final String? year;
  final String? quality;
  final String? language;
  final String? currentEpisode;
  final double avgRating;
  final int ratingCount;
  final String? description;

  String? get imageUrl => posterUrl ?? thumbUrl;

  factory FilmCard.fromJson(Map<String, dynamic> json) {
    return FilmCard(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      originalName: json['originalName'] as String?,
      thumbUrl: json['thumbUrl'] as String?,
      posterUrl: json['posterUrl'] as String?,
      year: json['year']?.toString(),
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      currentEpisode: json['currentEpisode']?.toString(),
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
    );
  }
}

class EpisodeItem {
  const EpisodeItem({
    required this.name,
    required this.slug,
    required this.embed,
  });

  final String name;
  final String slug;
  final String embed;

  /// Prefer direct HLS when embed wraps `player.phimapi.com/?url=`.
  String get playUrl {
    final uri = Uri.tryParse(embed);
    if (uri == null) return embed;
    final nested = uri.queryParameters['url'];
    if (nested != null && nested.isNotEmpty) return nested;
    return embed;
  }

  factory EpisodeItem.fromJson(Map<String, dynamic> json) {
    return EpisodeItem(
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      embed: (json['embed'] ?? '').toString(),
    );
  }
}

class EpisodeServer {
  const EpisodeServer({required this.serverName, required this.items});

  final String serverName;
  final List<EpisodeItem> items;

  factory EpisodeServer.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return EpisodeServer(
      serverName: (json['serverName'] ?? 'Server').toString(),
      items: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => EpisodeItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}

class FilmDetail extends FilmCard {
  const FilmDetail({
    required super.slug,
    required super.name,
    super.originalName,
    super.thumbUrl,
    super.posterUrl,
    super.year,
    super.quality,
    super.language,
    super.currentEpisode,
    super.avgRating,
    super.ratingCount,
    super.description,
    this.director,
    this.casts,
    this.episodes = const [],
  });

  final String? director;
  final String? casts;
  final List<EpisodeServer> episodes;

  factory FilmDetail.fromJson(Map<String, dynamic> json) {
    final rawEps = json['episodes'];
    return FilmDetail(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      originalName: json['originalName'] as String?,
      thumbUrl: json['thumbUrl'] as String?,
      posterUrl: json['posterUrl'] as String?,
      year: json['year']?.toString(),
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      currentEpisode: json['currentEpisode']?.toString(),
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      director: json['director'] as String?,
      casts: json['casts'] as String?,
      episodes: rawEps is List
          ? rawEps
                .whereType<Map>()
                .map(
                  (e) => EpisodeServer.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
    );
  }
}
