import 'models.dart';

class ContinueItem {
  const ContinueItem({
    required this.slug,
    required this.film,
    this.episodeSlug,
    this.episodeName,
    this.serverName,
    this.positionSec,
    this.updatedAt,
  });

  final String slug;
  final FilmCard film;
  final String? episodeSlug;
  final String? episodeName;
  final String? serverName;
  final int? positionSec;
  final String? updatedAt;

  String get episodeLabel {
    final raw = (episodeName ?? '').trim();
    if (raw.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(raw)) return 'Tập $raw';
    return raw;
  }

  String get positionLabel {
    final sec = positionSec;
    if (sec == null || sec <= 0) return '';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  factory ContinueItem.fromJson(Map<String, dynamic> json) {
    final filmRaw = json['film'];
    return ContinueItem(
      slug: (json['slug'] ?? '').toString(),
      episodeSlug: json['episodeSlug']?.toString(),
      episodeName: json['episodeName'] as String?,
      serverName: json['serverName'] as String?,
      positionSec: (json['positionSec'] as num?)?.toInt(),
      updatedAt: json['updatedAt']?.toString(),
      film: filmRaw is Map
          ? FilmCard.fromJson(Map<String, dynamic>.from(filmRaw))
          : FilmCard(
              slug: (json['slug'] ?? '').toString(),
              name: (json['slug'] ?? '').toString(),
            ),
    );
  }
}
