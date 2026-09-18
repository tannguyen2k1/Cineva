import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/score_card.dart';

class FilmDetailScreen extends StatefulWidget {
  const FilmDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  State<FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<FilmDetailScreen> {
  late Future<FilmDetail> _future;
  String? _serverName;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().filmDetail(widget.slug);
  }

  void _play(FilmDetail film, EpisodeServer? server, EpisodeItem ep) {
    context.push(
      '/xem/${film.slug}',
      extra: {
        'title': film.name,
        'playUrl': ep.playUrl,
        'episodeName': ep.name,
        'serverName': server?.serverName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      body: FutureBuilder<FilmDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(snap.error?.toString() ?? 'Lỗi'),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Quay lại'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final film = snap.data!;
          final servers = film.episodes;
          final server =
              servers.cast<EpisodeServer?>().firstWhere(
                (s) => s?.serverName == _serverName,
                orElse: () => servers.isNotEmpty ? servers.first : null,
              ) ??
              (servers.isNotEmpty ? servers.first : null);
          final firstEp = server?.items.isNotEmpty == true
              ? server!.items.first
              : null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: CinevaColors.bg.withValues(alpha: 0.9),
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                title: Text(
                  film.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 140,
                              child: AspectRatio(
                                aspectRatio: 2 / 3,
                                child: film.imageUrl == null
                                    ? const ColoredBox(
                                        color: CinevaColors.surfaceElevated,
                                      )
                                    : CinevaNetworkImage(url: film.imageUrl!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  film.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                                if (film.originalName != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    film.originalName!,
                                    style: const TextStyle(
                                      color: CinevaColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (film.year != null)
                                      _MetaChip(film.year!),
                                    if (film.quality != null)
                                      _MetaChip(film.quality!),
                                    if (film.language != null)
                                      _MetaChip(film.language!),
                                    if (film.currentEpisode != null)
                                      _MetaChip(film.currentEpisode!),
                                  ],
                                ),
                                if (film.avgRating > 0) ...[
                                  const SizedBox(height: 12),
                                  ScoreCard(
                                    score: film.avgRating,
                                    count: film.ratingCount,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (firstEp != null) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _play(film, server, firstEp),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text('Xem ${firstEp.name}'),
                        ),
                      ],
                      if (film.description != null &&
                          film.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Nội dung',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          film.description!,
                          style: const TextStyle(
                            color: Color(0xFFD4D4D8),
                            height: 1.55,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (film.director != null || film.casts != null) ...[
                        const SizedBox(height: 18),
                        if (film.director != null)
                          _InfoLine(label: 'Đạo diễn', value: film.director!),
                        if (film.casts != null)
                          _InfoLine(label: 'Diễn viên', value: film.casts!),
                      ],
                      if (servers.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Server',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in servers)
                              ChoiceChip(
                                label: Text(s.serverName),
                                selected: server?.serverName == s.serverName,
                                selectedColor: CinevaColors.accent.withValues(
                                  alpha: 0.2,
                                ),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          server?.serverName == s.serverName
                                          ? CinevaColors.accent
                                          : const Color(0xFFE4E4E7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                side: BorderSide(
                                  color: server?.serverName == s.serverName
                                      ? CinevaColors.accent.withValues(
                                          alpha: 0.45,
                                        )
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                                onSelected: (_) =>
                                    setState(() => _serverName = s.serverName),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Danh sách tập',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final ep
                                in server?.items ?? const <EpisodeItem>[])
                              ActionChip(
                                label: Text(ep.name),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFFF4F4F5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                onPressed: () => _play(film, server, ep),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 12),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, height: 1.45),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: CinevaColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFFE4E4E7)),
            ),
          ],
        ),
      ),
    );
  }
}
