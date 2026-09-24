import 'package:flutter/material.dart';

import '../../models/continue_item.dart';
import '../../theme/cineva_theme.dart';
import '../../widgets/cineva_network_image.dart';
import 'shared_components.dart';

class ContinueTab extends StatelessWidget {
  const ContinueTab({
    super.key,
    required this.loggedIn,
    required this.future,
    required this.onLogin,
    required this.onRefresh,
    required this.onOpenDetail,
    required this.onPlay,
  });

  final bool loggedIn;
  final Future<List<ContinueItem>>? future;
  final VoidCallback onLogin;
  final Future<void> Function() onRefresh;
  final ValueChanged<ContinueItem> onOpenDetail;
  final ValueChanged<ContinueItem> onPlay;

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
                Icons.history_rounded,
                size: 48,
                color: CinevaColors.accent.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 14),
              const Text(
                'Đã xem',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đăng nhập để tiếp tục đúng đoạn bạn dừng lại.',
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
          padding: EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Text(
            'Đã xem',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ContinueItem>>(
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
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có lịch sử xem.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CinevaColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                color: CinevaColors.accent,
                onRefresh: onRefresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final film = item.film;
                    return Material(
                      color: const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => onOpenDetail(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 72,
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: CinevaNetworkImage(
                                      url: film.imageUrl,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      film.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      [
                                        'Tiếp tục',
                                        if (item.episodeLabel.isNotEmpty)
                                          item.episodeLabel,
                                        if (item.positionLabel.isNotEmpty)
                                          item.positionLabel,
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: CinevaColors.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (film.year != null ||
                                        film.quality != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (film.year != null) film.year!,
                                          if (film.quality != null)
                                            film.quality!,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: CinevaColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Xem tiếp',
                                onPressed: () => onPlay(item),
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: CinevaColors.accent,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
