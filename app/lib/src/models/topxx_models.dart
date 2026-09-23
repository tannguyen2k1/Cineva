import 'models.dart';

class TopxxMovie {
  const TopxxMovie({
    required this.code,
    required this.title,
    required this.slug,
    this.duration,
    this.quality,
    this.thumbnail,
    this.poster,
    this.backdrop,
    this.publishAt,
    this.description,
    this.genres = const [],
    this.embedLink,
  });

  final String code;
  final String title;
  final String slug;
  final String? duration;
  final String? quality;
  final String? thumbnail;
  final String? poster;
  final String? backdrop;
  final String? publishAt;
  final String? description;
  final List<String> genres;
  final String? embedLink;

  String get effectivePoster => poster ?? thumbnail ?? backdrop ?? '';
  String get effectiveBackdrop => backdrop ?? poster ?? thumbnail ?? '';

  /// Returns inferred tags/genres based on the movie title, genres, and metadata
  List<String> get inferredTags {
    final tags = <String>{};
    for (final g in genres) {
      if (g.trim().isNotEmpty) tags.add(g.trim());
    }
    final tLower = title.toLowerCase();
    if (tLower.contains('vietsub') || tLower.contains('phụ đề') || tLower.contains('sub')) {
      tags.add('Vietsub');
    }
    if (tLower.contains('không che') || tLower.contains('uncensored')) {
      tags.add('Không Che');
    }
    if (tLower.contains('nhật') ||
        tLower.contains('jav') ||
        RegExp(r'^[a-z]{2,5}-\d+', caseSensitive: false).hasMatch(code)) {
      tags.add('Nhật Bản');
    }
    if (tLower.contains('hàn') || tLower.contains('korea') || tLower.contains('kr')) {
      tags.add('Hàn Quốc');
    }
    if (tLower.contains('tây') || tLower.contains('âu mỹ') || tLower.contains('us')) {
      tags.add('Âu Mỹ');
    }
    if (tLower.contains('gái xinh') ||
        tLower.contains('idol') ||
        tLower.contains('hotgirl') ||
        tLower.contains('gái trẻ') ||
        tLower.contains('check hàng')) {
      tags.add('Gái Xinh');
    }
    if (tLower.contains('vụng trộm') ||
        tLower.contains('ngoại tình') ||
        tLower.contains('sếp') ||
        tLower.contains('công sở')) {
      tags.add('Tình Cảm');
    }
    if (tLower.contains('hentai') || tLower.contains('anime') || tLower.contains('3d')) {
      tags.add('Anime 18+');
    }
    if (tags.isEmpty) {
      tags.add('Full HD');
      tags.add('Đặc Sắc');
    }
    return tags.toList();
  }

  /// Returns a rich synopsis, falling back to a synthesized description if API does not provide one
  String get effectiveDescription {
    if (description != null &&
        description!.trim().isNotEmpty &&
        description!.trim() != 'null') {
      return description!.trim();
    }
    final buffer = StringBuffer();
    buffer.write('Thước phim đặc sắc "$title". ');
    final tags = inferredTags;
    if (tags.isNotEmpty) {
      buffer.write('Tác phẩm thuộc các chủ đề ${tags.take(3).join(", ")}, ');
    }
    buffer.write('được ghi hình với chất lượng cao ${quality ?? "FHD 1080P"}');
    if (duration != null && duration!.isNotEmpty) {
      buffer.write(' cùng thời lượng trọn vẹn $duration');
    }
    buffer.write(
      '. Nội dung mang đến trải nghiệm thị giác chân thực, âm thanh sống động và đường truyền ổn định. '
      'Hệ thống Cineva đảm bảo phát trực tuyến bảo mật, mượt mà và hoàn toàn riêng tư cho người dùng.',
    );
    return buffer.toString();
  }

  factory TopxxMovie.fromJson(Map<String, dynamic> json) {
    String title = json['code']?.toString() ?? '';
    String slug = json['code']?.toString() ?? '';
    String? description;

    final trans = json['trans'];
    if (trans is List && trans.isNotEmpty) {
      final viTrans = trans.firstWhere(
        (t) => t is Map && t['locale'] == 'vi',
        orElse: () => trans.first,
      );
      if (viTrans is Map) {
        if (viTrans['title'] != null && viTrans['title'].toString().isNotEmpty) {
          title = viTrans['title'].toString();
        }
        if (viTrans['slug'] != null && viTrans['slug'].toString().isNotEmpty) {
          slug = viTrans['slug'].toString();
        }
        final rawDesc = viTrans['description'] ??
            viTrans['content'] ??
            viTrans['seo_description'] ??
            json['description'] ??
            json['content'];
        if (rawDesc != null &&
            rawDesc.toString().trim().isNotEmpty &&
            rawDesc.toString() != 'null') {
          description = rawDesc.toString().trim();
        }
      }
    }
    if (description == null) {
      final rawDesc = json['description'] ?? json['content'] ?? json['seo_description'];
      if (rawDesc != null &&
          rawDesc.toString().trim().isNotEmpty &&
          rawDesc.toString() != 'null') {
        description = rawDesc.toString().trim();
      }
    }

    final rawGenres = json['genres'];
    final genresList = <String>[];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is Map) {
          final gTrans = g['trans'];
          if (gTrans is List && gTrans.isNotEmpty && gTrans.first is Map) {
            final name = gTrans.first['name']?.toString();
            if (name != null) genresList.add(name);
          } else if (g['name'] != null) {
            genresList.add(g['name'].toString());
          }
        }
      }
    }

    String? embedLink;
    final sources = json['sources'];
    if (sources is List && sources.isNotEmpty) {
      for (final s in sources) {
        if (s is Map && s['link'] != null) {
          embedLink = s['link'].toString();
          break;
        }
      }
    }

    return TopxxMovie(
      code: json['code']?.toString() ?? '',
      title: title,
      slug: slug,
      duration: json['duration']?.toString(),
      quality: json['quality']?.toString() ?? 'FHD',
      thumbnail: json['thumbnail']?.toString(),
      poster: json['poster']?.toString(),
      backdrop: json['backdrop']?.toString(),
      publishAt: json['publish_at']?.toString(),
      description: description,
      genres: genresList,
      embedLink: embedLink,
    );
  }

  /// Convert to FilmCard so it can be reused in existing Cineva widgets
  FilmCard toFilmCard() {
    return FilmCard(
      slug: code,
      name: title,
      originalName: duration != null ? '$quality · $duration' : quality,
      thumbUrl: effectivePoster,
      posterUrl: effectiveBackdrop,
      year: null,
      currentEpisode: duration ?? quality ?? 'FHD',
      quality: quality ?? 'FHD',
      language: 'Vietsub',
    );
  }
}

class TopxxGenre {
  const TopxxGenre({
    required this.code,
    required this.name,
    required this.slug,
  });

  final String code;
  final String name;
  final String slug;

  factory TopxxGenre.fromJson(Map<String, dynamic> json) {
    String name = json['code']?.toString() ?? '';
    final trans = json['translations'];
    if (trans is List && trans.isNotEmpty && trans.first is Map) {
      name = trans.first['name']?.toString() ?? name;
    }
    return TopxxGenre(
      code: json['code']?.toString() ?? '',
      name: name,
      slug: json['slug']?.toString() ?? json['code']?.toString() ?? '',
    );
  }
}

class TopxxPageResult {
  const TopxxPageResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<TopxxMovie> items;
  final int currentPage;
  final int lastPage;
  final int total;

  factory TopxxPageResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final items = <TopxxMovie>[];
    if (data is List) {
      for (final raw in data) {
        if (raw is Map<String, dynamic>) {
          items.add(TopxxMovie.fromJson(raw));
        } else if (raw is Map) {
          items.add(TopxxMovie.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final meta = json['meta'];
    int current = 1;
    int last = 1;
    int total = items.length;
    if (meta is Map) {
      current = (meta['current_page'] as num?)?.toInt() ?? 1;
      last = (meta['last_page'] as num?)?.toInt() ?? 1;
      total = (meta['total'] as num?)?.toInt() ?? items.length;
    }

    return TopxxPageResult(
      items: items,
      currentPage: current,
      lastPage: last,
      total: total,
    );
  }
}
