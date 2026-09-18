import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/cineva_theme.dart';

/// Resolves `/uploads/...` against [AppConfig.apiBase] and loads network images.
///
/// On Flutter web, CDN hosts like phimimg.com often lack CORS headers, so byte
/// fetch fails. Prefer HTML `<img>` (same as Nuxt) which can display them.
class CinevaNetworkImage extends StatelessWidget {
  const CinevaNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String url;
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

  Widget get _placeholder =>
      placeholder ??
      const ColoredBox(color: CinevaColors.surfaceElevated);

  Widget get _error =>
      error ??
      const ColoredBox(
        color: CinevaColors.surfaceElevated,
        child: Icon(Icons.broken_image_outlined, color: CinevaColors.muted),
      );

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(url);
    if (resolved.isEmpty) return _error;

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
        errorBuilder: (_, _, _) => _error,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      placeholder: (_, _) => _placeholder,
      errorWidget: (_, _, _) => _error,
    );
  }
}
