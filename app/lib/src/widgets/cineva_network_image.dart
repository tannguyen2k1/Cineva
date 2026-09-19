import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/cineva_theme.dart';

/// Resolves `/uploads/...` against [AppConfig.apiBase] and loads network images.
///
/// Missing / failed images show the branded Cineva poster. While loading, a
/// calm solid surface is used so grids don't flash the mascot on every tile.
///
/// On Flutter web, CDN hosts like phimimg.com often lack CORS headers, so byte
/// fetch fails. Prefer HTML `<img>` (same as Nuxt) which can display them.
class CinevaNetworkImage extends StatelessWidget {
  const CinevaNetworkImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  static const posterPlaceholderAsset =
      'assets/brand/film-poster-placeholder.png';

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;

  static String resolve(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = AppConfig.apiBase.replaceAll(RegExp(r'/+$'), '');
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  /// No poster / broken URL — branded art.
  Widget get _missingPoster =>
      error ??
      Image.asset(
        posterPlaceholderAsset,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
      );

  /// In-flight load — quiet so infinite scroll does not strobe mascots.
  Widget get _loading =>
      placeholder ??
      ColoredBox(
        color: CinevaColors.surfaceElevated,
        child: SizedBox(width: width, height: height),
      );

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(url ?? '');
    if (resolved.isEmpty) return _missingPoster;

    if (kIsWeb) {
      return Image.network(
        resolved,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        gaplessPlayback: true,
        // Prefer HTML for CORS CDNs; deck cards still clip via parent Clip.
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => _missingPoster,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loading;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => _loading,
      errorWidget: (_, _, _) => _missingPoster,
    );
  }
}
