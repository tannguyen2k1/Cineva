import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';
import '../widgets/film_comments_section.dart';
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
  bool _watchBusy = false;
  bool? _inWatchlist;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().filmDetail(widget.slug);
  }

  Future<void> _toggleWatchlist(FilmDetail film) async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }
    final api = context.read<ApiClient>();
    final next = !(_inWatchlist ?? film.inWatchlist);
    setState(() => _watchBusy = true);
    try {
      if (next) {
        await api.addWatchlist(film.slug);
      } else {
        await api.removeWatchlist(film.slug);
      }
      if (!mounted) return;
      setState(() => _inWatchlist = next);
      showCinevaToast(
        context,
        next ? 'Đã thêm vào tủ phim' : 'Đã xóa khỏi tủ phim',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _watchBusy = false);
    }
  }

  Future<void> _play(
    FilmDetail film,
    EpisodeServer? server,
    EpisodeItem ep, {
    int? positionSec,
  }) async {
    await context.push(
      '/xem/${film.slug}',
      extra: {
        'title': film.name,
        'playUrl': ep.playUrl,
        'embedUrl': ep.embed,
        'episodeSlug': ep.slug,
        'episodeName': ep.name,
        'serverName': server?.serverName,
        if (positionSec != null && positionSec > 0) 'positionSec': positionSec,
      },
    );
    if (!mounted) return;
    setState(() {
      _future = context.read<ApiClient>().filmDetail(widget.slug);
    });
  }

  /// Resolve episode to resume from [film.watchProgress], else first episode.
  ({EpisodeServer? server, EpisodeItem ep, bool isContinue})? _primaryPlay(
    FilmDetail film,
    List<EpisodeServer> servers,
    EpisodeServer? selectedServer,
  ) {
    final progress = film.watchProgress;
    if (progress != null && progress.episodeSlug.isNotEmpty) {
      // Prefer matching server, then any server that has the episode.
      final preferred = <EpisodeServer>[
        if (progress.serverName != null && progress.serverName!.isNotEmpty)
          ...servers.where((s) => s.serverName == progress.serverName),
        ...servers,
      ];
      for (final s in preferred) {
        for (final ep in s.items) {
          if (ep.slug == progress.episodeSlug) {
            return (server: s, ep: ep, isContinue: true);
          }
        }
      }
      // Episode slug gone from catalog — still label continue with stored name.
      if (selectedServer?.items.isNotEmpty == true) {
        return (
          server: selectedServer,
          ep: selectedServer!.items.first,
          isContinue: true,
        );
      }
    }

    if (selectedServer?.items.isNotEmpty == true) {
      return (
        server: selectedServer,
        ep: selectedServer!.items.first,
        isContinue: false,
      );
    }
    return null;
  }

  String _episodeButtonLabel(EpisodeItem ep, {required bool isContinue}) {
    final raw = ep.name.trim();
    final epLabel = RegExp(r'^\d+$').hasMatch(raw) ? 'Tập $raw' : raw;
    if (!isContinue) return 'Xem $epLabel';
    return epLabel.isEmpty ? 'Xem tiếp' : 'Xem tiếp · $epLabel';
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
          final primary = _primaryPlay(film, servers, server);

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
                                child: CinevaNetworkImage(url: film.imageUrl),
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
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                if (film.originalName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    film.originalName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: CinevaColors.muted,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
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
                                const SizedBox(height: 8),
                                ScoreCard(
                                  score: film.avgRating,
                                  count: film.ratingCount,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (primary != null) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _play(
                            film,
                            primary.server,
                            primary.ep,
                            positionSec: primary.isContinue
                                ? film.watchProgress?.positionSec
                                : null,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            _episodeButtonLabel(
                              primary.ep,
                              isContinue: primary.isContinue,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _watchBusy
                            ? null
                            : () => _toggleWatchlist(film),
                        icon: Icon(
                          (_inWatchlist ?? film.inWatchlist)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                        label: Text(
                          (_inWatchlist ?? film.inWatchlist)
                              ? 'Đã lưu tủ phim'
                              : 'Thêm vào tủ phim',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CinevaColors.accent,
                          side: BorderSide(
                            color: CinevaColors.accent.withValues(alpha: 0.45),
                          ),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
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
                        _EpisodeSection(
                          servers: servers,
                          selected: server,
                          onSelectServer: (s) =>
                              setState(() => _serverName = s.serverName),
                          onPlay: (ep) => _play(film, server, ep),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilmCommentsSection(slug: film.slug),
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

class _EpisodeSection extends StatelessWidget {
  const _EpisodeSection({
    required this.servers,
    required this.selected,
    required this.onSelectServer,
    required this.onPlay,
  });

  final List<EpisodeServer> servers;
  final EpisodeServer? selected;
  final ValueChanged<EpisodeServer> onSelectServer;
  final ValueChanged<EpisodeItem> onPlay;

  @override
  Widget build(BuildContext context) {
    final items = selected?.items ?? const <EpisodeItem>[];
    final width = MediaQuery.sizeOf(context).width;
    final cols = ((width - 32) / 56).floor().clamp(5, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danh sách tập',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${items.length} tập',
              style: const TextStyle(
                color: CinevaColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (servers.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: servers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = servers[i];
                final active = selected?.serverName == s.serverName;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelectServer(s),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: active
                            ? CinevaColors.accent.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: active
                              ? CinevaColors.accent.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        s.serverName,
                        style: TextStyle(
                          color: active
                              ? CinevaColors.accent
                              : const Color(0xFFE4E4E7),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Text(
            'Chưa có tập nào',
            style: TextStyle(color: CinevaColors.muted),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              final ep = items[i];
              return _EpisodeTile(
                label: _episodeLabel(ep, i),
                onTap: () => onPlay(ep),
              );
            },
          ),
      ],
    );
  }
}

String _episodeLabel(EpisodeItem ep, int index) {
  final name = ep.name.trim();
  final tap = RegExp(
    r'(?:tập|tap|ep(?:isode)?)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(name);
  if (tap != null) return tap.group(1)!;
  final onlyNum = RegExp(r'^\d+$').firstMatch(name);
  if (onlyNum != null) return name;
  if (name.length <= 4) return name;
  return '${index + 1}';
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: CinevaColors.accent.withValues(alpha: 0.18),
        highlightColor: CinevaColors.accent.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF1A1A22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF4F4F5),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE4E4E7),
          fontSize: 11,
          height: 1.2,
        ),
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
