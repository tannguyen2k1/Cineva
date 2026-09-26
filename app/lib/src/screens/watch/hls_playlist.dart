import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'hls_source.dart';

/// Downloads the episode playlist and drops spliced ad segments that sit
/// outside the episode's own HLS folder (`3500kb/hls/…`).
///
/// iOS receives an `http://127.0.0.1` URL. AVPlayer rejects a `file://`
/// playlist whose segments stay on the CDN. Other platforms get a temp file.
/// Throws if the source cannot be read, so the player can fall back to the
/// original URL.
Future<String> prepareHlsPlayback(String url) async {
  final media = await _loadMediaPlaylist(Uri.parse(url));
  final filtered = _stripOutsideSegments(media.playlistUrl, media.body);
  if (Platform.isIOS) return _iosPlaylistHost.publish(filtered);
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}cineva-playback.m3u8',
  );
  await file.writeAsString(filtered);
  return file.path;
}

final _iosPlaylistHost = _LocalPlaylistHost();

/// Serves the latest rewritten playlist so AVPlayer can load it over HTTP.
class _LocalPlaylistHost {
  HttpServer? _server;
  String _body = '';

  Future<String> publish(String playlist) async {
    _body = playlist;
    if (!await _answers()) {
      final stale = _server;
      _server = null;
      unawaited(stale?.close(force: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen((request) async {
        try {
          final response = request.response;
          final bytes = utf8.encode(_body);
          response.statusCode = HttpStatus.ok;
          response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/vnd.apple.mpegurl',
          );
          response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
          response.contentLength = bytes.length;
          response.add(bytes);
          await response.close();
        } catch (_) {
          try {
            await request.response.close();
          } catch (_) {}
        }
      }, onDone: () {
        if (identical(_server, server)) _server = null;
      });
    }
    final server = _server;
    if (server == null) {
      throw StateError('Không mở được playlist cục bộ');
    }
    return 'http://127.0.0.1:${server.port}/cineva-playback.m3u8';
  }

  Future<bool> _answers() async {
    final server = _server;
    if (server == null) return false;
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/cineva-playback.m3u8'))
          .timeout(const Duration(milliseconds: 500));
      final response = await request.close().timeout(const Duration(milliseconds: 500));
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

class _LoadedPlaylist {
  const _LoadedPlaylist(this.playlistUrl, this.body);
  final Uri playlistUrl;
  final String body;
}

Future<_LoadedPlaylist> _loadMediaPlaylist(Uri url) async {
  final first = await _fetch(url);
  final variant = _variantUri(url, first);
  if (variant == null) return _LoadedPlaylist(url, first);
  final body = await _fetch(variant);
  return _LoadedPlaylist(variant, body);
}

Future<String> _fetch(Uri url) async {
  final response = await http
      .get(url, headers: hlsHeaders)
      .timeout(const Duration(seconds: 12));
  if (response.statusCode != 200 || !response.body.contains('#EXTM3U')) {
    throw StateError('Playlist không đọc được');
  }
  return response.body;
}

/// First media playlist linked from a master playlist, if this body is one.
Uri? _variantUri(Uri playlistUrl, String body) {
  final lines = body.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
    for (var j = i + 1; j < lines.length; j++) {
      final line = lines[j].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) break;
      return playlistUrl.resolve(line);
    }
  }
  return null;
}

const _segmentTags = {
  '#EXTINF',
  '#EXT-X-BYTERANGE',
  '#EXT-X-DISCONTINUITY',
  '#EXT-X-PROGRAM-DATE-TIME',
  '#EXT-X-GAP',
};

String _stripOutsideSegments(Uri playlistUrl, String body) {
  final folder = playlistUrl.resolve('.').path;
  final lines = body.split(RegExp(r'\r?\n'));
  final out = <String>[];
  final pending = <String>[];
  var kept = 0;
  var dropped = 0;

  void flushPending(bool keep) {
    if (keep) out.addAll(pending);
    pending.clear();
  }

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      final tag = line.split(':').first;
      if (_segmentTags.contains(tag)) {
        pending.add(line);
      } else {
        flushPending(true);
        out.add(line);
      }
      continue;
    }

    final resolved = playlistUrl.resolve(line);
    final keep = resolved.path.startsWith(folder);
    flushPending(keep);
    if (keep) {
      out.add(resolved.toString());
      kept++;
    } else {
      dropped++;
    }
  }
  flushPending(true);

  if (kept == 0 || dropped == 0) {
    throw StateError('Không có đoạn quảng cáo để bỏ');
  }
  if (!out.last.startsWith('#EXT-X-ENDLIST')) {
    out.add('#EXT-X-ENDLIST');
  }
  return '${out.join('\n')}\n';
}
