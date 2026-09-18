import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/cineva_theme.dart';
import 'cineva_network_image.dart';

/// Compact 3D deck along a rainbow-like arc.
class HomeHeroDeck extends StatefulWidget {
  const HomeHeroDeck({
    super.key,
    required this.slides,
    required this.index,
    required this.onChanged,
    required this.onOpen,
  });

  final List<FilmCard> slides;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onOpen;

  @override
  State<HomeHeroDeck> createState() => _HomeHeroDeckState();
}

class _HomeHeroDeckState extends State<HomeHeroDeck> {
  late final PageController _pageCtrl;

  /// How strongly side cards drop along the arc (px at |delta|=1).
  static const _arcDrop = 42.0;

  /// How much the center card lifts (px).
  static const _arcPeak = 14.0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(
      initialPage: widget.index,
      viewportFraction: 0.58,
    );
  }

  @override
  void didUpdateWidget(covariant HomeHeroDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index &&
        _pageCtrl.hasClients &&
        (_pageCtrl.page?.round() ?? widget.index) != widget.index) {
      _pageCtrl.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  double get _page {
    if (_pageCtrl.hasClients && _pageCtrl.position.haveDimensions) {
      return _pageCtrl.page ?? widget.index.toDouble();
    }
    return widget.index.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = screenW * 0.54;
    final posterH = cardW * 1.42;
    const infoH = 118.0;
    // Extra vertical room so the arc can rise/drop without clipping.
    final heroH = posterH + infoH + _arcDrop + _arcPeak + 36;

    return SizedBox(
      height: heroH,
      width: double.infinity,
      child: ColoredBox(
        color: CinevaColors.bg,
        child: AnimatedBuilder(
          animation: _pageCtrl,
          builder: (context, _) {
            final page = _page;
            return PageView.builder(
              controller: _pageCtrl,
              itemCount: slides.length,
              onPageChanged: widget.onChanged,
              padEnds: true,
              itemBuilder: (context, i) {
                final film = slides[i];
                final delta = page - i;
                final abs = delta.abs().clamp(0.0, 2.0);

                // Rainbow arc: center high, sides low (y grows downward).
                final arcY = (abs * abs) * _arcDrop - _arcPeak;

                // Cylinder-ish facing: fan out left/right.
                final rotateY = delta * 0.55;
                final rotateZ = delta * 0.12;
                final scale = (1 - abs * 0.14).clamp(0.82, 1.0);
                final opacity = (1 - abs * 0.28).clamp(0.5, 1.0);

                // Pull sides slightly toward the arc center.
                final arcX = math.sin(delta * 0.55) * 6;

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.00115)
                        ..translateByDouble(arcX, arcY, 0.0, 1.0)
                        ..rotateY(rotateY)
                        ..rotateZ(rotateZ)
                        ..scaleByDouble(scale, scale, scale, 1.0),
                      child: SizedBox(
                        width: cardW,
                        height: posterH + infoH,
                        child: _DeckCard(
                          film: film,
                          active: abs < 0.4,
                          posterHeight: posterH,
                          onOpen: () => widget.onOpen(film.slug),
                          onSelect: () {
                            if (abs < 0.4) {
                              widget.onOpen(film.slug);
                            } else {
                              widget.onChanged(i);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.film,
    required this.active,
    required this.posterHeight,
    required this.onOpen,
    required this.onSelect,
  });

  final FilmCard film;
  final bool active;
  final double posterHeight;
  final VoidCallback onOpen;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final borderColor = active
        ? CinevaColors.accent
        : CinevaColors.accent.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: borderColor,
            width: active ? 2.2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: active ? 0.5 : 0.3),
              blurRadius: active ? 20 : 10,
              offset: Offset(0, active ? 10 : 5),
            ),
            if (active)
              BoxShadow(
                color: CinevaColors.accent.withValues(alpha: 0.16),
                blurRadius: 16,
              ),
          ],
        ),
        // Border lives outside clip — otherwise the stroke gets shaved off.
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: const Color(0xFF141416),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: posterHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (film.imageUrl != null)
                        CinevaNetworkImage(
                          url: film.imageUrl!,
                          alignment: Alignment.topCenter,
                        )
                      else
                        const ColoredBox(color: CinevaColors.surfaceElevated),
                      if (film.avgRating > 0)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${film.avgRating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: CinevaColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          film.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: Color(0xFFF4F4F5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            if (film.year != null) _Chip(film.year!),
                            if (film.quality != null) _Chip(film.quality!),
                            if (film.currentEpisode != null)
                              _Chip(film.currentEpisode!),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onOpen,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Xem ngay'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD4D4D8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
