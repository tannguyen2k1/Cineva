/// HLS helpers for the normal catalog. 18+ embed pages are not m3u8.
const resumeAskSec = 30;

const hlsHeaders = {
  'Referer': 'https://player.phimapi.com/',
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
};

String? directHls(String playUrl, String? embedUrl) {
  final play = playUrl.trim();
  if (play.contains('.m3u8')) return play;
  final nested = Uri.tryParse(embedUrl?.trim() ?? '')?.queryParameters['url'];
  if (nested != null && nested.contains('.m3u8')) return nested;
  return null;
}

Uri? embedUri({required String playUrl, String? embedUrl}) {
  final embed = embedUrl?.trim() ?? '';
  if (embed.isNotEmpty) return Uri.tryParse(embed);
  final play = playUrl.trim();
  if (play.isEmpty) return null;
  if (play.contains('.m3u8')) {
    return Uri.parse(
      'https://player.phimapi.com/player/?url=${Uri.encodeComponent(play)}',
    );
  }
  return Uri.tryParse(play);
}

String clockLabel(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$m:$ss';
}
