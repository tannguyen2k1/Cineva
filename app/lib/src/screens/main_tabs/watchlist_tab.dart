import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/cineva_theme.dart';
import '../../widgets/film_card_tile.dart';
import 'shared_components.dart';

int _watchlistCrossAxisCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return ((w - 32) / 148).floor().clamp(3, 8);
}

class WatchlistTab extends StatelessWidget {
  const WatchlistTab({
    super.key,
    required this.loggedIn,
    required this.future,
    required this.onLogin,
    required this.onRefresh,
    required this.onOpenFilm,
  });

  final bool loggedIn;
  final Future<List<FilmCard>>? future;
  final VoidCallback onLogin;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenFilm;

  @override
  Widget build(BuildContext context) {
    if (!loggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 48,
                color: CinevaColors.accent.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tủ phim',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đăng nhập để đồng bộ và xem phim đã lưu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CinevaColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onLogin, child: const Text('Đăng nhập')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            'Tủ phim',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<FilmCard>>(
            future: future,
            builder: (context, snap) {
              if (future == null ||
                  snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorPane(
                  message: snap.error.toString(),
                  onRetry: () => onRefresh(),
                );
              }
              final films = snap.data ?? const [];
              if (films.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Bạn chưa thêm phim nào vào tủ. Hãy thêm phim vào tủ ở chi tiết phim.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CinevaColors.muted, height: 1.45),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                color: CinevaColors.accent,
                onRefresh: onRefresh,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _watchlistCrossAxisCount(context),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.48,
                  ),
                  itemCount: films.length,
                  itemBuilder: (context, i) {
                    final film = films[i];
                    return FilmCardTile(
                      film: film,
                      onTap: () => onOpenFilm(film.slug),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
