import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/topxx_models.dart';

class TopxxClient {
  TopxxClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String baseUrl = 'https://topxx.vip/api/v1';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Cineva/1.0',
      };

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('TopXX API error: ${res.statusCode}');
  }

  Future<TopxxPageResult> getLatest({int page = 1, int perPage = 24}) async {
    final data = await _get('/movies/latest', {
      'page': '$page',
      'per_page': '$perPage',
      'sort_dir': 'desc',
    });
    return TopxxPageResult.fromJson(data);
  }

  Future<TopxxPageResult> getToday({int page = 1, int perPage = 24}) async {
    final data = await _get('/movies/today', {
      'page': '$page',
      'per_page': '$perPage',
    });
    return TopxxPageResult.fromJson(data);
  }

  Future<TopxxPageResult> search(String query, {int page = 1, int perPage = 24}) async {
    final data = await _get('/movies/search', {
      'q': query.trim(),
      'locale': 'vi',
      'page': '$page',
      'per_page': '$perPage',
    });
    return TopxxPageResult.fromJson(data);
  }

  Future<TopxxMovie?> getDetail(String code) async {
    final data = await _get('/movies/$code');
    final payload = data['data'];
    if (payload is Map<String, dynamic>) {
      // Also grab sources from top-level if present
      final topSources = data['sources'];
      if (topSources is List && topSources.isNotEmpty && payload['sources'] == null) {
        payload['sources'] = topSources;
      }
      return TopxxMovie.fromJson(payload);
    }
    return null;
  }

  Future<List<TopxxGenre>> getGenres() async {
    final data = await _get('/genres', {'per_page': '50'});
    final list = data['data'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => TopxxGenre.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<TopxxPageResult> getByGenre(String genreCode, {int page = 1, int perPage = 24}) async {
    final data = await _get('/genres/$genreCode/movies', {
      'page': '$page',
      'per_page': '$perPage',
      'locale': 'vi',
    });
    return TopxxPageResult.fromJson(data);
  }
}
