import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/cineva_theme.dart';
import 'cineva_network_image.dart';

/// Compact 3D deck: portrait posters upright, landscape → wide banner cards.
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
  PageController? _pageCtrl;
  bool _booted = false;
  bool _isHovering = false;

  static const _arcDrop = 42.0;
  static const _arcPeak = 14.0;
  static const _infoHPortrait = 152.0;
  static const _posterAspect = 1.32;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create once with the correct viewportFraction. Orientation changes remount
    // this State via ValueKey — never swap controllers mid-build.
    if (_booted) return;
    _booted = true;
    final m = _metrics(MediaQuery.sizeOf(context));
    _pageCtrl = PageController(
      initialPage: widget.index.clamp(0, math.max(0, widget.slides.length - 1)),
      viewportFraction: m.fraction,
    );
  }

  @override
  void didUpdateWidget(covariant HomeHeroDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = _pageCtrl;
    if (ctrl == null) return;
    if (oldWidget.index != widget.index &&
        ctrl.hasClients &&
        (ctrl.page?.round() ?? widget.index) != widget.index) {
      ctrl.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl?.dispose();
    super.dispose();
  }

  double get _page {
    final ctrl = _pageCtrl;
    if (ctrl != null && ctrl.hasClients && ctrl.position.haveDimensions) {
      return ctrl.page ?? widget.index.toDouble();
    }
    return widget.index.toDouble();
  }

  ({
    double cardW,
    double cardH,
    double heroH,
    double fraction,
    bool landscape,
  })
  _metrics(Size size) {
    final screenW = size.width;

    // We only have portrait posters from the API, so we always use the portrait card layout,
    // but we scale the viewport fraction so that desktop shows a nice multi-card cover flow.
    final cardW = (screenW * 0.45).clamp(160.0, 320.0);
    final posterH = cardW * _posterAspect;
    final cardH = posterH + _infoHPortrait;
    final heroH = cardH + _arcDrop + _arcPeak + 16;
    
    // Fraction of the viewport each page takes. On desktop this becomes smaller (~0.3)
    final fraction = (cardW / screenW * 1.15).clamp(0.25, 0.60);
    
    return (
      cardW: cardW,
      cardH: cardH,
      heroH: heroH,
      fraction: fraction,
      landscape: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    final ctrl = _pageCtrl;
    if (ctrl == null) return const SizedBox.shrink();

    final m = _metrics(MediaQuery.sizeOf(context));

    return SizedBox(
      height: m.heroH,
      width: double.infinity,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Rebuild transforms while dragging — safe outside build phase.
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            setState(() {});
          }
          return false;
        },
        child: Builder(
          builder: (context) {
            final page = _page;
            final activeIndex = page.round().clamp(0, slides.length - 1);
            final active = slides[activeIndex];
            final hasPrev = activeIndex > 0;
            final hasNext = activeIndex < slides.length - 1;

            return MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 480),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _AmbientBackdrop(
                      key: ValueKey(active.imageUrl ?? active.slug),
                      imageUrl: active.imageUrl,
                    ),
                  ),
                ),
                PageView.builder(
                  controller: ctrl,
                  itemCount: slides.length,
                  onPageChanged: widget.onChanged,
                  padEnds: true,
                  itemBuilder: (context, i) {
                    final film = slides[i];
                    final delta = page - i;
                    final abs = delta.abs().clamp(0.0, 2.0);

                    final arcY = (abs * abs) * _arcDrop - _arcPeak;
                    final rotateY = delta * (m.landscape ? 0.32 : 0.55);
                    final rotateZ = delta * (m.landscape ? 0.06 : 0.12);
                    final scale = (1 - abs * 0.12).clamp(0.86, 1.0);
                    final opacity = (1 - abs * 0.28).clamp(0.5, 1.0);
                    final arcX =
                        math.sin(delta * 0.55) * (m.landscape ? 10 : 6);

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
                            width: m.cardW,
                            height: m.cardH,
                            child: m.landscape
                                ? _LandscapeBannerCard(
                                    film: film,
                                    active: abs < 0.4,
                                    onOpen: () => widget.onOpen(film.slug),
                                    onSelect: () {
                                      if (abs < 0.4) {
                                        widget.onOpen(film.slug);
                                      } else {
                                        widget.onChanged(i);
                                      }
                                    },
                                  )
                                : _PortraitDeckCard(
                                    film: film,
                                    active: abs < 0.4,
                                    posterHeight: m.cardW * _posterAspect,
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
                ),
                if (_isHovering && hasPrev)
                  Positioned(
                    left: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () {
                          _pageCtrl?.previousPage(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                  ),
                if (_isHovering && hasNext)
                  Positioned(
                    right: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () {
                          _pageCtrl?.nextPage(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            );
          },
        ),
      ),
    );
  }
}

/// Soft blurred poster wash behind the deck — not flat black.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({super.key, this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: CinevaColors.bg),
        if (imageUrl != null && imageUrl!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Transform.scale(
              scale: 1.22,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.28),
                  BlendMode.darken,
                ),
                child: CinevaNetworkImage(
                  url: imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                CinevaColors.bg.withValues(alpha: 0.35),
                Colors.transparent,
                CinevaColors.bg.withValues(alpha: 0.55),
                CinevaColors.bg.withValues(alpha: 0.92),
              ],
              stops: const [0, 0.28, 0.72, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 1.05,
              colors: [
                CinevaColors.accent.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                CinevaColors.bg.withValues(alpha: 0.55),
                Colors.transparent,
                Colors.transparent,
                CinevaColors.bg.withValues(alpha: 0.55),
              ],
              stops: const [0, 0.22, 0.78, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// Wide landscape banner: image full-bleed + text/CTA overlay.
class _LandscapeBannerCard extends StatelessWidget {
  const _LandscapeBannerCard({
    required this.film,
    required this.active,
    required this.onOpen,
    required this.onSelect,
  });

  final FilmCard film;
  final bool active;
  final VoidCallback onOpen;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final borderColor = active
        ? CinevaColors.accent
        : CinevaColors.accent.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: borderColor, width: active ? 2.2 : 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: active ? 0.5 : 0.3),
              blurRadius: active ? 22 : 12,
              offset: Offset(0, active ? 12 : 6),
            ),
            if (active)
              BoxShadow(
                color: CinevaColors.accent.withValues(alpha: 0.16),
                blurRadius: 18,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinevaNetworkImage(
                url: film.imageUrl,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
              ),
              // Left + bottom wash for readable copy.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.35, 0.52, 0.78, 1],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
              if (film.avgRating > 0)
                Positioned(
                  top: 14,
                  right: 14,
                  child: _RatingBadge(
                    text: '★ ${film.avgRating.toStringAsFixed(1)}',
                    accent: true,
                  ),
                )
              else
                const Positioned(
                  top: 14,
                  right: 14,
                  child: _RatingBadge(text: 'Chưa có đánh giá'),
                ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            film.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              color: Color(0xFFF4F4F5),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (film.year != null) _Chip(film.year!),
                              if (film.quality != null) _Chip(film.quality!),
                              if (film.language != null) _Chip(film.language!),
                            ],
                          ),
                          if (film.releaseStatusLabel != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              film.releaseStatusLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: film.isOngoing
                                    ? CinevaColors.accent.withValues(alpha: 0.95)
                                    : const Color(0xFF4ADE80),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('Xem ngay'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(148, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitDeckCard extends StatelessWidget {
  const _PortraitDeckCard({
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
          border: Border.all(color: borderColor, width: active ? 2.2 : 1.5),
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
                      CinevaNetworkImage(
                        url: film.imageUrl,
                        alignment: Alignment.topCenter,
                      ),
                      if (film.avgRating > 0)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _RatingBadge(
                            text: '★ ${film.avgRating.toStringAsFixed(1)}',
                            accent: true,
                          ),
                        )
                      else
                        const Positioned(
                          top: 10,
                          left: 10,
                          child: _RatingBadge(text: 'Chưa có đánh giá'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  film.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    color: Color(0xFFF4F4F5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 4,
                                  children: [
                                    if (film.year != null) _Chip(film.year!),
                                    if (film.quality != null)
                                      _Chip(film.quality!),
                                    if (film.language != null)
                                      _Chip(film.language!),
                                  ],
                                ),
                                if (film.releaseStatusLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    film.releaseStatusLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: film.isOngoing
                                          ? CinevaColors.accent.withValues(
                                              alpha: 0.9,
                                            )
                                          : const Color(0xFF4ADE80),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 34,
                          child: FilledButton.icon(
                            onPressed: onOpen,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Xem ngay'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              maximumSize: const Size(double.infinity, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
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

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? CinevaColors.accent : const Color(0xFFD4D4D8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: accent
            ? CinevaColors.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? CinevaColors.accent : const Color(0xFFD4D4D8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 36, color: Colors.white),
        onPressed: onTap,
        padding: const EdgeInsets.all(12),
        hoverColor: CinevaColors.accent.withValues(alpha: 0.2),
      ),
    );
  }
}
