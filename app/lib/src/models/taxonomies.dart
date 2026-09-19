class TaxonomyItem {
  const TaxonomyItem({required this.slug, required this.name});

  final String slug;
  final String name;

  factory TaxonomyItem.fromJson(Map<String, dynamic> json) {
    return TaxonomyItem(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class Taxonomies {
  const Taxonomies({
    this.genres = const [],
    this.countries = const [],
    this.types = const [],
    this.years = const [],
  });

  final List<TaxonomyItem> genres;
  final List<TaxonomyItem> countries;
  final List<TaxonomyItem> types;
  final List<String> years;

  factory Taxonomies.fromJson(Map<String, dynamic> json) {
    List<TaxonomyItem> items(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => TaxonomyItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.slug.isNotEmpty)
          .toList();
    }

    final yearsRaw = json['years'];
    return Taxonomies(
      genres: items(json['genres']),
      countries: items(json['countries']),
      types: items(json['types']),
      years: yearsRaw is List
          ? yearsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }
}

class CatalogFilters {
  const CatalogFilters({
    this.sort = 'newest',
    this.type,
    this.genre,
    this.year,
    this.country,
  });

  final String sort;
  final String? type;
  final String? genre;
  final String? year;
  final String? country;

  bool get hasActive =>
      (type != null && type!.isNotEmpty) ||
      (genre != null && genre!.isNotEmpty) ||
      (year != null && year!.isNotEmpty) ||
      (country != null && country!.isNotEmpty) ||
      sort != 'newest';

  CatalogFilters copyWith({
    String? sort,
    String? type,
    String? genre,
    String? year,
    String? country,
    bool clearType = false,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearCountry = false,
  }) {
    return CatalogFilters(
      sort: sort ?? this.sort,
      type: clearType ? null : (type ?? this.type),
      genre: clearGenre ? null : (genre ?? this.genre),
      year: clearYear ? null : (year ?? this.year),
      country: clearCountry ? null : (country ?? this.country),
    );
  }

  static const empty = CatalogFilters();
}
