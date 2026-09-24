import 'package:flutter/material.dart';

import '../../models/home_payload.dart';
import '../../models/models.dart';
import '../../theme/cineva_theme.dart';
import '../../widgets/film_card_tile.dart';
import '../../widgets/home_hero_deck.dart';
import 'shared_components.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.future,
    required this.slide,
    required this.onSlide,
    required this.onRefresh,
    required this.onOpenFilm,
    required this.onOpenTopic,
  });

  final Future<HomePayload> future;
  final int slide;
  final ValueChanged<int> onSlide;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenFilm;
  final ValueChanged<HomeTopic> onOpenTopic;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomePayload>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorPane(
            message: snap.error.toString(),
            onRetry: () => onRefresh(),
          );
        }
        final data = snap.data ?? const HomePayload();
        final slides =
            data.slides.isNotEmpty ? data.slides : data.newest.take(16).toList();

        return RefreshIndicator(
          color: CinevaColors.accent,
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (slides.isNotEmpty)
                HomeHeroDeck(
                  key: ValueKey(MediaQuery.orientationOf(context)),
                  slides: slides,
                  index: slide.clamp(0, slides.length - 1),
                  onChanged: onSlide,
                  onOpen: onOpenFilm,
                ),
              if (data.topics.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionTitle(title: 'Chủ đề'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: data.topics.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final t = data.topics[i];
                      return TopicCard(
                        topic: t,
                        onTap: () => onOpenTopic(t),
                      );
                    },
                  ),
                ),
              ],
              if (data.newest.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionTitle(title: 'Mới cập nhật'),
                const SizedBox(height: 10),
                FilmRail(films: data.newest, onOpen: onOpenFilm),
              ],
              for (final section in data.sections) ...[
                const SizedBox(height: 22),
                SectionTitle(title: section.title),
                const SizedBox(height: 10),
                FilmRail(films: section.items, onOpen: onOpenFilm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class FilmRail extends StatelessWidget {
  const FilmRail({super.key, required this.films, required this.onOpen});

  final List<FilmCard> films;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 278,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: films.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final film = films[i];
          return FilmCardTile(
            width: 140,
            film: film,
            onTap: () => onOpen(film.slug),
          );
        },
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class TopicCard extends StatelessWidget {
  const TopicCard({super.key, required this.topic, required this.onTap});

  final HomeTopic topic;
  final VoidCallback onTap;

  static const _tones = <String, List<Color>>{
    'violet': [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFFA78BFA)],
    'rose': [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFFB7185)],
    'amber': [Color(0xFF9A3412), Color(0xFFEA580C), Color(0xFFFBBF24)],
    'crimson': [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF87171)],
    'gold': [Color(0xFF854D0E), Color(0xFFCA8A04), Color(0xFFFACC15)],
    'slate': [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF64748B)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _tones[topic.tone] ?? _tones['slate']!;
    final width = (MediaQuery.sizeOf(context).width * 0.42).clamp(140.0, 168.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
              stops: const [0, 0.5, 1],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                topic.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Xem chủ đề',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
