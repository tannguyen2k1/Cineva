import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/home_payload.dart';
import '../models/models.dart';
import '../models/notification.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
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

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/api/auth/token'),
      headers: _headers(auth: false, form: true),
      body: {
        'grant_type': 'password',
        'username': username,
        'password': password,
      },
    );
    final body = _decode(res);
    final access = body['access_token']?.toString();
    final refresh = body['refresh_token']?.toString();
    if (access == null || refresh == null) {
      throw ApiException('Đăng nhập thất bại: thiếu token');
    }
    await _persistTokens(access: access, refresh: refresh);
    return body;
  }

  Future<bool> refreshSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    final res = await _client.post(
      _uri('/api/auth/token'),
      headers: _headers(auth: false, form: true),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
      },
    );
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

  Future<List<FilmCard>> listFilms({
    int page = 1,
    String? q,
    String? type,
    String? genre,
  }) async {
    final data = await getJson(
      '/api/public/films',
      query: {
        'page': '$page',
        'pageSize': '24',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (genre != null && genre.trim().isNotEmpty) 'genre': genre.trim(),
      },
    );
    final items = data['data'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => FilmCard.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
    var res = await _client.get(
      _uri(path, query),
      headers: _headers(auth: auth),
    );
    if (res.statusCode == 401 && auth) {
      final ok = await refreshSession();
      if (ok) {
        res = await _client.get(
          _uri(path, query),
          headers: _headers(auth: true),
        );
      }
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    var res = await _client.post(
      _uri(path),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    if (res.statusCode == 401 && auth) {
      final ok = await refreshSession();
      if (ok) {
        res = await _client.post(
          _uri(path),
          headers: _headers(auth: true),
          body: body == null ? null : jsonEncode(body),
        );
      }
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    var res = await _client.put(
      _uri(path),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    if (res.statusCode == 401 && auth) {
      final ok = await refreshSession();
      if (ok) {
        res = await _client.put(
          _uri(path),
          headers: _headers(auth: true),
          body: body == null ? null : jsonEncode(body),
        );
      }
    }
    return _decode(res);
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
