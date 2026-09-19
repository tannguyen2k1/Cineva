import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/continue_item.dart';
import '../models/home_payload.dart';
import '../models/models.dart';
import '../models/notification.dart';
import '../models/taxonomies.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class FilmListResult {
  const FilmListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<FilmCard> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => items.length < total || page * pageSize < total;
}

class AdminPageResult {
  const AdminPageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => items.length < total;

  factory AdminPageResult.fromJson(Map<String, dynamic> data) {
    final raw = data['data'];
    final list = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];
    return AdminPageResult(
      items: list,
      total: (data['total'] as num?)?.toInt() ?? list.length,
      page: (data['page'] as num?)?.toInt() ?? 1,
      pageSize: (data['pageSize'] as num?)?.toInt() ?? list.length,
    );
  }
}

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const _accessKey = 'cineva_access_token';
  static const _refreshKey = 'cineva_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  Future<void> loadTokens() async {
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<void> _persistTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBase.replaceAll(RegExp(r'/+$'), '');
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool auth = true, bool form = false}) {
    return {
      if (form)
        'Content-Type': 'application/x-www-form-urlencoded'
      else
        'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (auth && _accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  Future<T> _withNetworkHandling<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.');
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    return _withNetworkHandling(() async {
      final res = await _client.post(
        _uri('/api/auth/token'),
        headers: _headers(auth: false, form: true),
        body: {
          'grant_type': 'password',
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 15));
      final body = _decode(res);
      final access = body['access_token']?.toString();
      final refresh = body['refresh_token']?.toString();
      if (access == null || refresh == null) {
        throw ApiException('Đăng nhập thất bại: thiếu token');
      }
      await _persistTokens(access: access, refresh: refresh);
      return body;
    });
  }

  /// Creates a member account. Cookie session from the API is ignored;
  /// call [login] afterward for Bearer tokens.
  Future<void> register({
    required String username,
    required String password,
    String? fullName,
    String? email,
    String turnstileToken = 'XXXX.DUMMY.TOKEN.XXXX',
  }) async {
    await postJson(
      '/api/auth/register',
      auth: false,
      body: {
        'username': username.trim(),
        'password': password,
        'turnstileToken': turnstileToken,
        if (fullName != null && fullName.trim().isNotEmpty)
          'fullName': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
  }

  Future<bool> refreshSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final res = await _client.post(
        _uri('/api/auth/token'),
        headers: _headers(auth: false, form: true),
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) {
        await clearTokens();
        return false;
      }
      final body = _decode(res);
      final access = body['access_token']?.toString();
      final refresh = body['refresh_token']?.toString();
      if (access == null || refresh == null) {
        await clearTokens();
        return false;
      }
      await _persistTokens(access: access, refresh: refresh);
      return true;
    } catch (_) {
      return false; // If network fails during refresh, just return false for now
    }
  }

  Future<UserSession> me() async {
    final data = await getJson('/api/auth/me');
    final block = data['data'];
    if (block is! Map) {
      throw ApiException('Không đọc được thông tin user');
    }
    final user = block['user'];
    if (user is! Map) {
      throw ApiException('Không đọc được thông tin user');
    }
    final map = Map<String, dynamic>.from(user);
    final perms = block['permissions'];
    if (perms is List) {
      map['permissions'] = perms;
    }
    return UserSession.fromJson(map);
  }

  Future<FilmListResult> listFilms({
    int page = 1,
    String? q,
    String? type,
    String? genre,
    String? country,
    String? year,
    String sort = 'newest',
  }) async {
    final data = await getJson(
      '/api/public/films',
      query: {
        'page': '$page',
        'pageSize': '24',
        'sort': sort,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (genre != null && genre.trim().isNotEmpty) 'genre': genre.trim(),
        if (country != null && country.trim().isNotEmpty)
          'country': country.trim(),
        if (year != null && year.trim().isNotEmpty) 'year': year.trim(),
      },
    );
    final items = data['data'];
    final list = items is List
        ? items
              .whereType<Map>()
              .map((e) => FilmCard.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const <FilmCard>[];
    return FilmListResult(
      items: list,
      total: (data['total'] as num?)?.toInt() ?? list.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['pageSize'] as num?)?.toInt() ?? 24,
    );
  }

  Future<Taxonomies> taxonomies() async {
    final data = await getJson('/api/public/taxonomies');
    final block = data['data'];
    if (block is! Map) return const Taxonomies();
    return Taxonomies.fromJson(Map<String, dynamic>.from(block));
  }

  Future<HomePayload> home() async {
    final data = await getJson('/api/public/home');
    final block = data['data'];
    if (block is! Map) return const HomePayload();
    return HomePayload.fromJson(Map<String, dynamic>.from(block));
  }

  Future<List<FilmCard>> homeNewest() async {
    final payload = await home();
    return payload.newest;
  }

  Future<FilmDetail> filmDetail(String slug) async {
    final data = await getJson('/api/public/films/$slug');
    final film = data['data'];
    if (film is! Map) {
      throw ApiException('Không tìm thấy phim');
    }
    return FilmDetail.fromJson(Map<String, dynamic>.from(film));
  }

  Future<AdminPageResult> listFilmComments(String slug, {int page = 1}) async {
    final data = await getJson(
      '/api/public/films/$slug/comments',
      query: {'page': '$page', 'pageSize': '20'},
      auth: false,
    );
    return AdminPageResult.fromJson(data);
  }

  Future<Map<String, dynamic>> addFilmComment(
    String slug, {
    required String body,
    String? parentId,
  }) async {
    final data = await postJson(
      '/api/public/films/$slug/comments',
      body: {
        'body': body,
        if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
      },
    );
    final payload = data['data'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return const {};
  }

  Future<int> notificationsUnreadCount() async {
    final data = await getJson('/api/me/notifications/unread-count');
    final block = data['data'];
    if (block is Map) {
      return (block['unreadCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<NotificationListResult> listNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await getJson(
      '/api/me/notifications',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
    final items = data['data'];
    final list = items is List
        ? items
              .whereType<Map>()
              .map(
                (e) => AppNotification.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : const <AppNotification>[];
    final unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
    return NotificationListResult(items: list, unreadCount: unread);
  }

  Future<void> markNotificationRead(String id) async {
    await putJson('/api/me/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await postJson('/api/me/notifications/read-all');
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    try {
      var res = await _client.get(
        uri,
        headers: _headers(auth: auth),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401 && auth) {
        final ok = await refreshSession();
        if (ok) {
          res = await _client.get(
            uri,
            headers: _headers(auth: true),
          ).timeout(const Duration(seconds: 15));
        }
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_GET_$uri', res.body);
      }
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_GET_$uri');
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      throw ApiException('Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.');
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    return _withNetworkHandling(() async {
      var res = await _client.post(
        _uri(path, query),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401 && auth) {
        final ok = await refreshSession();
        if (ok) {
          res = await _client.post(
            _uri(path, query),
            headers: _headers(auth: true),
            body: body == null ? null : jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
        }
      }
      return _decode(res);
    });
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _withNetworkHandling(() async {
      var res = await _client.put(
        _uri(path),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401 && auth) {
        final ok = await refreshSession();
        if (ok) {
          res = await _client.put(
            _uri(path),
            headers: _headers(auth: true),
            body: body == null ? null : jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
        }
      }
      return _decode(res);
    });
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    return _withNetworkHandling(() async {
      var res = await _client.patch(
        _uri(path, query),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401 && auth) {
        final ok = await refreshSession();
        if (ok) {
          res = await _client.patch(
            _uri(path, query),
            headers: _headers(auth: true),
            body: body == null ? null : jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
        }
      }
      return _decode(res);
    });
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool auth = true,
  }) async {
    return _withNetworkHandling(() async {
      var res = await _client.delete(
        _uri(path),
        headers: _headers(auth: auth),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401 && auth) {
        final ok = await refreshSession();
        if (ok) {
          res = await _client.delete(
            _uri(path),
            headers: _headers(auth: true),
          ).timeout(const Duration(seconds: 15));
        }
      }
      return _decode(res);
    });
  }

  Future<List<FilmCard>> listWatchlist({int page = 1}) async {
    final data = await getJson(
      '/api/me/watchlist',
      query: {'page': '$page', 'pageSize': '48'},
    );
    final items = data['data'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => FilmCard.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addWatchlist(String slug) async {
    await postJson('/api/me/watchlist/$slug');
  }

  Future<void> removeWatchlist(String slug) async {
    await deleteJson('/api/me/watchlist/$slug');
  }

  Future<List<ContinueItem>> listContinue() async {
    final data = await getJson('/api/me/continue');
    final items = data['data'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => ContinueItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveProgress({
    required String slug,
    required String episodeSlug,
    String? episodeName,
    String? serverName,
    int? positionSec,
  }) async {
    await putJson(
      '/api/me/progress',
      body: {
        'slug': slug,
        'episodeSlug': episodeSlug,
        if (episodeName != null) 'episodeName': episodeName,
        if (serverName != null) 'serverName': serverName,
        if (positionSec != null) 'positionSec': positionSec,
      },
    );
  }

  Future<FilmListResult> adminListFilms({int page = 1, String? q}) async {
    final data = await getJson(
      '/api/admin/films',
      query: {
        'page': '$page',
        'pageSize': '24',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final items = data['data'];
    final list = items is List
        ? items
              .whereType<Map>()
              .map((e) => FilmCard.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const <FilmCard>[];
    return FilmListResult(
      items: list,
      total: (data['total'] as num?)?.toInt() ?? list.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['pageSize'] as num?)?.toInt() ?? 24,
    );
  }

  Future<void> adminSetFilmHidden(String slug, {required bool isHidden}) async {
    await patchJson(
      '/api/admin/films/$slug',
      body: {'isHidden': isHidden},
    );
  }

  Future<Map<String, dynamic>> dashboardStats() async {
    final data = await getJson('/api/dashboard/stats');
    final payload = data['data'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return const {};
  }

  Future<AdminPageResult> adminListSyncRuns({int page = 1}) async {
    final data = await getJson(
      '/api/admin/sync/runs',
      query: {'page': '$page', 'pageSize': '20'},
    );
    return AdminPageResult.fromJson(data);
  }

  Future<Map<String, dynamic>> adminRunIncrementalSync() async {
    return postJson('/api/admin/sync/run');
  }

  Future<Map<String, dynamic>> adminRunCatalogSync({int pagesPerSource = 5}) async {
    return postJson(
      '/api/admin/sync/catalog',
      query: {'pagesPerSource': '$pagesPerSource'},
    );
  }

  Future<Map<String, dynamic>> adminRunFullSync({bool resume = false}) async {
    return postJson(
      '/api/admin/sync/full',
      query: {'resume': '$resume'},
    );
  }

  Future<Map<String, dynamic>?> adminFullSyncStatus() async {
    final data = await getJson('/api/admin/sync/full/status');
    final payload = data['data'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  Future<AdminPageResult> adminListComments({int page = 1}) async {
    final data = await getJson(
      '/api/admin/comments',
      query: {'page': '$page', 'pageSize': '20'},
    );
    return AdminPageResult.fromJson(data);
  }

  Future<void> adminSetCommentHidden(String id, {required bool isHidden}) async {
    await patchJson(
      '/api/admin/comments/$id',
      query: {'isHidden': '$isHidden'},
    );
  }

  Future<List<Map<String, dynamic>>> adminListBanners() async {
    final data = await getJson('/api/admin/banners');
    return _mapList(data['data']);
  }

  Future<void> adminSetBannerActive(String id, {required bool isActive}) async {
    await patchJson(
      '/api/admin/banners/$id',
      body: {'isActive': isActive},
    );
  }

  Future<void> adminCreateBanner({
    required String title,
    required String imageUrl,
    String? filmSlug,
    String? linkUrl,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    await postJson(
      '/api/admin/banners',
      body: {
        'title': title,
        'imageUrl': imageUrl,
        if (filmSlug != null && filmSlug.isNotEmpty) 'filmSlug': filmSlug,
        if (linkUrl != null && linkUrl.isNotEmpty) 'linkUrl': linkUrl,
        'sortOrder': sortOrder,
        'isActive': isActive,
      },
    );
  }

  Future<void> adminUpdateBanner(
    String id, {
    String? title,
    String? imageUrl,
    String? filmSlug,
    String? linkUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    await patchJson(
      '/api/admin/banners/$id',
      body: {
        if (title != null) 'title': title,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'filmSlug': filmSlug,
        'linkUrl': linkUrl,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (isActive != null) 'isActive': isActive,
      },
    );
  }

  Future<void> adminDeleteBanner(String id) async {
    await deleteJson('/api/admin/banners/$id');
  }

  Future<List<Map<String, dynamic>>> adminListFeatured({
    String section = 'home_hot',
  }) async {
    final data = await getJson(
      '/api/admin/featured',
      query: {'section': section},
    );
    return _mapList(data['data']);
  }

  Future<void> adminCreateFeatured({
    required String filmSlug,
    String section = 'home_hot',
    int sortOrder = 0,
  }) async {
    await postJson(
      '/api/admin/featured',
      body: {
        'filmSlug': filmSlug,
        'section': section,
        'sortOrder': sortOrder,
      },
    );
  }

  Future<void> adminDeleteFeatured(String id) async {
    await deleteJson('/api/admin/featured/$id');
  }

  Future<AdminPageResult> adminListUsers({int page = 1, String? search}) async {
    final data = await getJson(
      '/api/users',
      query: {
        'page': '$page',
        'pageSize': '20',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return AdminPageResult.fromJson(data);
  }

  Future<AdminPageResult> adminListRoles({int page = 1}) async {
    final data = await getJson(
      '/api/roles',
      query: {'page': '$page', 'pageSize': '50'},
    );
    return AdminPageResult.fromJson(data);
  }

  Future<AdminPageResult> adminListLogs({int page = 1, String? search}) async {
    final data = await getJson(
      '/api/logs',
      query: {
        'page': '$page',
        'pageSize': '20',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return AdminPageResult.fromJson(data);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? email,
    String? password,
  }) async {
    final data = await putJson(
      '/api/users/profile',
      body: {
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    final payload = data['data'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return const {};
  }

  Future<String> uploadAvatar(String filePath, {String? filename}) async {
    return _withNetworkHandling(() async {
      final safeName = _avatarUploadName(filename ?? filePath);
      final mediaType = _avatarMediaType(safeName);

      Future<http.StreamedResponse> send() async {
        final req = http.MultipartRequest('POST', _uri('/api/users/avatar'));
        if (_accessToken != null) {
          req.headers['Authorization'] = 'Bearer $_accessToken';
        }
        req.headers['Accept'] = 'application/json';
        req.files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: safeName,
            contentType: mediaType,
          ),
        );
        return _client.send(req).timeout(const Duration(seconds: 30));
      }

      var streamed = await send();
      var res = await http.Response.fromStream(streamed);
      if (res.statusCode == 401) {
        final ok = await refreshSession();
        if (ok) {
          streamed = await send();
          res = await http.Response.fromStream(streamed);
        }
      }
      final body = _decode(res);
      final data = body['data'];
      if (data is Map && data['avatar'] != null) {
        return data['avatar'].toString();
      }
      throw ApiException('Upload avatar thất bại');
    });
  }

  /// Backend only accepts jpeg/png/gif/webp — normalize HEIC / missing ext.
  static String _avatarUploadName(String raw) {
    final name = raw.split('/').last.split('\\').last;
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return name;
    }
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : (name.isEmpty ? 'avatar' : name);
    return '$base.jpg';
  }

  static MediaType _avatarMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = {};
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      }
    }
    if (res.statusCode >= 400) {
      final detail =
          body['detail']?.toString() ??
          body['statusMessage']?.toString() ??
          body['msg']?.toString() ??
          'Lỗi ${res.statusCode}';
      throw ApiException(detail, statusCode: res.statusCode);
    }
    return body;
  }
}
