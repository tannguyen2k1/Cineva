import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/home_payload.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_bottom_nav.dart';
import '../widgets/cineva_header.dart';
import '../widgets/film_card_tile.dart';
import '../widgets/home_hero_deck.dart';
import '../widgets/public_more_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomePayload> _homeFuture;
  late Future<List<FilmCard>> _catalogFuture;
  final _searchCtrl = TextEditingController();
  int _tab = 0;
  int _slide = 0;
  bool _searchOpen = false;
  String? _query;
  String? _filmType;
  String? _genre;
  String _catalogTitle = 'Phim';

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _homeFuture = api.home();
    _catalogFuture = api.listFilms();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reloadHome() {
    setState(() => _homeFuture = context.read<ApiClient>().home());
  }

  void _reloadCatalog({
    String? q,
    String? type,
    String? genre,
    bool clearFilters = false,
  }) {
    setState(() {
      _query = q?.trim().isEmpty == true ? null : q?.trim();
      if (clearFilters) {
        _filmType = null;
        _genre = null;
      } else {
        if (type != null) {
          _filmType = type.trim().isEmpty ? null : type.trim();
          if (_filmType != null) _genre = null;
        }
        if (genre != null) {
          _genre = genre.trim().isEmpty ? null : genre.trim();
          if (_genre != null) _filmType = null;
        }
      }
      _catalogFuture = context.read<ApiClient>().listFilms(
        q: _query,
        type: _filmType,
        genre: _genre,
      );
    });
  }

  void _openCatalog({
    required String title,
    String? type,
    String? genre,
  }) {
    setState(() {
      _tab = 1;
      _catalogTitle = title;
      _searchOpen = false;
      _searchCtrl.clear();
    });
    if (type == null && genre == null) {
      _reloadCatalog(clearFilters: true, q: '');
    } else {
      _reloadCatalog(type: type ?? '', genre: genre ?? '', q: '');
    }
  }

  Future<void> _showMenu() async {
    final action = await showPublicMoreMenu(context);
    if (!mounted || action == null) return;

    switch (action) {
      case MoreMenuAction.profile:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hồ sơ sẽ sớm có trên app.')),
        );
      case MoreMenuAction.phimLe:
        _openCatalog(title: 'Phim Lẻ', type: 'phim-le');
      case MoreMenuAction.phimBo:
        _openCatalog(title: 'Phim Bộ', type: 'phim-bo');
      case MoreMenuAction.chieuRap:
        _openCatalog(title: 'Đang chiếu', type: 'phim-chieu-rap');
      case MoreMenuAction.catalog:
        _openCatalog(title: 'Phim');
      case MoreMenuAction.admin:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin chỉ dùng trên web quản trị.')),
        );
      case MoreMenuAction.logout:
        await context.read<AuthState>().logout();
    }
  }

  void _openTopic(HomeTopic topic) {
    final uri = Uri.tryParse(topic.href);
    final type = uri?.queryParameters['type'];
    final genre = uri?.queryParameters['genre'];
    _openCatalog(
      title: topic.name,
      type: type,
      genre: genre,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      body: Column(
        children: [
          CinevaHeader(
            onSearch: () {
              setState(() {
                _tab = 1;
                _searchOpen = true;
              });
            },
          ),
          Expanded(
            child: switch (_tab.clamp(0, 3)) {
              0 => _HomeFeed(
                future: _homeFuture,
                slide: _slide,
                onSlide: (i) => setState(() => _slide = i),
                onRefresh: () async => _reloadHome(),
                onOpenFilm: (slug) => context.push('/phim/$slug'),
                onOpenTopic: _openTopic,
              ),
              1 => _CatalogFeed(
                title: _catalogTitle,
                future: _catalogFuture,
                searchOpen: _searchOpen,
                searchCtrl: _searchCtrl,
                onCloseSearch: () => setState(() => _searchOpen = false),
                onSearch: (q) => _reloadCatalog(q: q),
                onClear: () {
                  _searchCtrl.clear();
                  _reloadCatalog(q: '');
                },
                onRefresh: () async =>
                    _reloadCatalog(q: _searchCtrl.text),
                onOpenFilm: (slug) => context.push('/phim/$slug'),
              ),
              2 => const _PlaceholderPane(
                icon: Icons.star_rounded,
                title: 'Tủ phim',
                subtitle: 'Danh sách yêu thích sẽ sớm có trên app.',
              ),
              _ => const _PlaceholderPane(
                icon: Icons.history_rounded,
                title: 'Đã xem',
                subtitle: 'Lịch sử xem sẽ sớm có trên app.',
              ),
            },
          ),
        ],
      ),
      bottomNavigationBar: CinevaBottomNav(
        index: _tab,
        onChanged: (i) {
          if (i == 4) {
            _showMenu();
            return;
          }
          setState(() => _tab = i);
        },
      ),
    );
  }
}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed({
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
          return _ErrorPane(
            message: snap.error.toString(),
            onRetry: () => onRefresh(),
          );
        }
        final data = snap.data ?? const HomePayload();
        final slides =
            data.slides.isNotEmpty ? data.slides : data.newest.take(8).toList();

        return RefreshIndicator(
          color: CinevaColors.accent,
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (slides.isNotEmpty)
                HomeHeroDeck(
                  slides: slides,
                  index: slide.clamp(0, slides.length - 1),
                  onChanged: onSlide,
                  onOpen: onOpenFilm,
                ),
              if (data.topics.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _SectionTitle(title: 'Chủ đề'),
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
                      return _TopicCard(
                        topic: t,
                        onTap: () => onOpenTopic(t),
                      );
                    },
                  ),
                ),
              ],
              if (data.newest.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _SectionTitle(title: 'Mới cập nhật'),
                const SizedBox(height: 10),
                _FilmRail(films: data.newest, onOpen: onOpenFilm),
              ],
              for (final section in data.sections) ...[
                const SizedBox(height: 22),
                _SectionTitle(title: section.title),
                const SizedBox(height: 10),
                _FilmRail(films: section.items, onOpen: onOpenFilm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CatalogFeed extends StatelessWidget {
  const _CatalogFeed({
    required this.title,
    required this.future,
    required this.searchOpen,
    required this.searchCtrl,
    required this.onCloseSearch,
    required this.onSearch,
    required this.onClear,
    required this.onRefresh,
    required this.onOpenFilm,
  });

  final String title;
  final Future<List<FilmCard>> future;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenFilm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
              decoration: InputDecoration(
                hintText: 'Tìm phim…',
                prefixIcon: const Icon(Icons.search, color: CinevaColors.muted),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear, color: CinevaColors.muted),
                      onPressed: onClear,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CinevaColors.muted),
                      onPressed: onCloseSearch,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Expanded(
          child: FutureBuilder<List<FilmCard>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorPane(
                  message: snap.error.toString(),
                  onRetry: () => onRefresh(),
                );
              }
              final films = snap.data ?? const [];
              if (films.isEmpty) {
                return const Center(
                  child: Text(
                    'Chưa có phim',
                    style: TextStyle(color: CinevaColors.muted),
                  ),
                );
              }
              return RefreshIndicator(
                color: CinevaColors.accent,
                onRefresh: onRefresh,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.46,
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

class _FilmRail extends StatelessWidget {
  const _FilmRail({required this.films, required this.onOpen});

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

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

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.onTap});

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

class _PlaceholderPane extends StatelessWidget {
  const _PlaceholderPane({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: CinevaColors.accent.withValues(alpha: 0.7)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CinevaColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
