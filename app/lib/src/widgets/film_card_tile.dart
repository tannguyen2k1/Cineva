import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/cineva_theme.dart';
import 'cineva_network_image.dart';

class FilmCardTile extends StatefulWidget {
  const FilmCardTile({
    super.key,
    required this.film,
    required this.onTap,
    this.width,
  });

  final FilmCard film;
  final VoidCallback onTap;
  final double? width;

  @override
  State<FilmCardTile> createState() => _FilmCardTileState();
}

class _FilmCardTileState extends State<FilmCardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final film = widget.film;
    final badge = film.avgRating > 0
        ? '★ ${film.avgRating.toStringAsFixed(1)}'
        : (film.quality ?? film.year);
    final ep = film.currentEpisode;
    final hasSub = (film.year != null && film.year!.isNotEmpty) ||
        (film.language != null && film.language!.isNotEmpty);

    final poster = DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _pressed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (film.imageUrl != null)
              CinevaNetworkImage(url: film.imageUrl!)
            else
              const ColoredBox(
                color: CinevaColors.surfaceElevated,
                child: Icon(
                  Icons.movie_outlined,
                  color: CinevaColors.muted,
                ),
              ),
            if (badge != null && badge.isNotEmpty)
              Positioned(
                top: 7,
                left: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: CinevaColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (ep != null && ep.isNotEmpty)
              Positioned(
                left: 7,
                bottom: 7,
                right: 7,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      ep,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: widget.width,
        transform: Matrix4.translationValues(0, _pressed ? -3 : 0, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounded = constraints.maxHeight.isFinite;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bounded)
                  Expanded(child: poster)
                else
                  AspectRatio(aspectRatio: 2 / 3, child: poster),
                const SizedBox(height: 6),
                Text(
                  film.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _pressed
                        ? CinevaColors.accent
                        : const Color(0xFFF4F4F5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (hasSub) ...[
                  const SizedBox(height: 2),
                  Text(
                    [film.year, film.language]
                        .whereType<String>()
                        .where((e) => e.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CinevaColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
