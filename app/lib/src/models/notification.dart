class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.linkUrl,
    this.isRead = false,
    this.createdAt,
    this.actorName,
    this.filmSlug,
    this.filmName,
    this.filmImageUrl,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? linkUrl;
  final bool isRead;
  final DateTime? createdAt;
  final String? actorName;
  final String? filmSlug;
  final String? filmName;
  final String? filmImageUrl;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      linkUrl: linkUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actorName: actorName,
      filmSlug: filmSlug,
      filmName: filmName,
      filmImageUrl: filmImageUrl,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    final film = json['film'];
    DateTime? created;
    final rawCreated = json['createdAt'];
    if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    String? filmImage;
    String? filmSlug;
    String? filmName;
    if (film is Map) {
      final map = Map<String, dynamic>.from(film);
      filmSlug = map['slug']?.toString();
      filmName = map['name']?.toString();
      filmImage = (map['posterUrl'] ?? map['thumbUrl'])?.toString();
    }

    String? actorName;
    if (actor is Map) {
      final map = Map<String, dynamic>.from(actor);
      actorName = (map['fullName'] as String?)?.trim().isNotEmpty == true
          ? map['fullName'] as String
          : map['username']?.toString();
    }

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: json['body'] as String?,
      linkUrl: json['linkUrl'] as String?,
      isRead: json['isRead'] == true,
      createdAt: created,
      actorName: actorName,
      filmSlug: filmSlug,
      filmName: filmName,
      filmImageUrl: filmImage,
    );
  }
}

class NotificationListResult {
  const NotificationListResult({
    this.items = const [],
    this.unreadCount = 0,
  });

  final List<AppNotification> items;
  final int unreadCount;
}
