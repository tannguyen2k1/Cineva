import 'models.dart';

class HomeTopic {
  const HomeTopic({
    required this.slug,
    required this.name,
    required this.href,
    required this.tone,
  });

  final String slug;
  final String name;
  final String href;
  final String tone;

  factory HomeTopic.fromJson(Map<String, dynamic> json) {
    return HomeTopic(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      href: (json['href'] ?? '').toString(),
      tone: (json['tone'] ?? 'slate').toString(),
    );
  }
}

class HomeSection {
  const HomeSection({
    required this.key,
    required this.title,
    required this.href,
    required this.items,
  });

  final String key;
  final String title;
  final String href;
  final List<FilmCard> items;

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return HomeSection(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      href: (json['href'] ?? '').toString(),
      items: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => FilmCard.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}

class HomePayload {
  const HomePayload({
    this.slides = const [],
    this.newest = const [],
    this.sections = const [],
    this.topics = const [],
  });

  final List<FilmCard> slides;
  final List<FilmCard> newest;
  final List<HomeSection> sections;
  final List<HomeTopic> topics;

  factory HomePayload.fromJson(Map<String, dynamic> json) {
    List<FilmCard> cards(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => FilmCard.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final sectionsRaw = json['sections'];
    final topicsRaw = json['topics'];

    return HomePayload(
      slides: cards(json['slides']),
      newest: cards(json['newest']),
      sections: sectionsRaw is List
          ? sectionsRaw
                .whereType<Map>()
                .map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      topics: topicsRaw is List
          ? topicsRaw
                .whereType<Map>()
                .map((e) => HomeTopic.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}
