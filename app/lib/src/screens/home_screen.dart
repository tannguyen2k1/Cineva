import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/continue_item.dart';
import '../models/home_payload.dart';
import '../models/models.dart';
import '../models/taxonomies.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/catalog_filter_sheet.dart';
import '../widgets/cineva_bottom_nav.dart';
import '../widgets/cineva_header.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';
import '../widgets/film_card_tile.dart';
import '../widgets/home_hero_deck.dart';
import '../widgets/public_more_menu.dart';

/// Keep catalog tiles ~140–160px wide so landscape doesn't blow them up.
int _catalogCrossAxisCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return ((w - 32) / 148).floor().clamp(3, 8);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomePayload> _homeFuture;
  List<FilmCard> _catalogItems = [];
  int _catalogPage = 0;
  int _catalogTotal = 0;
  bool _catalogLoading = true;
  bool _catalogLoadingMore = false;
  String? _catalogError;
  Future<Taxonomies>? _taxonomiesFuture;
  Taxonomies _taxonomies = const Taxonomies();
  CatalogFilters _filters = CatalogFilters.empty;
  final _searchCtrl = TextEditingController();
  int _tab = 0;
  int _slide = 0;
  bool _searchOpen = false;
  String? _query;
  String _catalogTitle = 'Phim';
  Future<List<FilmCard>>? _watchlistFuture;
  Future<List<ContinueItem>>? _continueFuture;
  AuthState? _auth;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _auth = context.read<AuthState>();
    _wasLoggedIn = _auth!.isLoggedIn;
    _auth!.addListener(_onAuthChanged);
    _homeFuture = api.home();
    _taxonomiesFuture = api.taxonomies().then((t) {
      _taxonomies = t;
      return t;
    }).catchError((Object e) {
      // Filters stay empty; don't surface as unhandled async error.
      return const Taxonomies();
    });
    _loadCatalog(reset: true);
  } 

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null || !mounted) return;
    final now = auth.isLoggedIn;
    final becameLoggedIn = now && !_wasLoggedIn;
    final becameLoggedOut = !now && _wasLoggedIn;
    _wasLoggedIn = now;
    if (!becameLoggedIn && !becameLoggedOut) return;

    // Defer off the notifyListeners stack so GoRouter redirect can run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (becameLoggedIn) {
        if (_tab == 2) {
          unawaited(_reloadWatchlist());
        } else if (_tab == 3) {
          unawaited(_reloadContinue());
        }
      } else if (becameLoggedOut) {
        setState(() {
          _watchlistFuture = null;
          _continueFuture = null;
        });
      }
    });
  }

  Future<void> _reloadHome() async {
    try {
      final future = context.read<ApiClient>().home();
      final data = await future;
      if (mounted) {
        setState(() {
          _homeFuture = Future.value(data);
        });
      }
    } catch (e) {
      if (mounted) showCinevaToast(context, e.toString(), error: true);
    }
  }

  Future<void> _reloadWatchlist() async {
    final future = context.read<ApiClient>().listWatchlist();
    if (mounted) {
      setState(() {
        _watchlistFuture = future;
      });
    }
    try {
      await future;
    } catch (e) {
      if (mounted) showCinevaToast(context, e.toString(), error: true);
    }
  }

  Future<void> _reloadContinue() async {
    final future = context.read<ApiClient>().listContinue();
    if (mounted) {
      setState(() {
        _continueFuture = future;
      });
    }
    try {
      await future;
    } catch (e) {
      if (mounted) showCinevaToast(context, e.toString(), error: true);
    }
  }

  Future<void> _openContinue(ContinueItem item) async {
    final api = context.read<ApiClient>();
    try {
      final detail = await api.filmDetail(item.slug);
      EpisodeServer? server;
      EpisodeItem? ep;
      for (final s in detail.episodes) {
        if (item.serverName != null &&
            item.serverName!.isNotEmpty &&
            s.serverName != item.serverName) {
          continue;
        }
        for (final e in s.items) {
          if (item.episodeSlug != null && e.slug == item.episodeSlug) {
            server = s;
            ep = e;
            break;
          }
        }
        if (ep != null) break;
      }
      if (ep == null) {
        for (final s in detail.episodes) {
          if (s.items.isEmpty) continue;
          if (item.serverName != null &&
              item.serverName!.isNotEmpty &&
              s.serverName != item.serverName) {
            continue;
          }
          server = s;
          ep = s.items.first;
          break;
        }
      }
      if (ep == null && detail.episodes.isNotEmpty) {
        server = detail.episodes.first;
        if (server.items.isNotEmpty) ep = server.items.first;
      }
      if (!mounted) return;
      if (ep == null || (ep.embed.isEmpty && ep.playUrl.isEmpty)) {
        context.push('/phim/${item.slug}');
        return;
      }
      context.push(
        '/xem/${item.slug}',
        extra: {
          'title': detail.name,
          'playUrl': ep.playUrl,
          'embedUrl': ep.embed,
          'episodeSlug': ep.slug,
          'episodeName': ep.name,
          'serverName': server?.serverName,
          'positionSec': item.positionSec,
        },
      );
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, 'Không mở được tập: $e', error: true);
    }
  }

  void _reloadCatalog({String? q, bool clearQuery = false}) {
    if (clearQuery) {
      _query = null;
    } else if (q != null) {
      _query = q.trim().isEmpty ? null : q.trim();
    }
    _loadCatalog(reset: true);
  }

  Future<void> _loadCatalog({required bool reset}) async {
    if (reset) {
      if (_catalogLoadingMore) return;
      setState(() {
        _catalogLoading = true;
        _catalogLoadingMore = false;
        _catalogError = null;
        _catalogPage = 0;
      });
    } else {
      if (_catalogLoading ||
          _catalogLoadingMore ||
          _catalogItems.length >= _catalogTotal) {
        return;
      }
      setState(() => _catalogLoadingMore = true);
    }

    final nextPage = reset ? 1 : _catalogPage + 1;
    try {
      final result = await context.read<ApiClient>().listFilms(
            page: nextPage,
            q: _query,
            type: _filters.type,
            genre: _filters.genre,
            country: _filters.country,
            year: _filters.year,
            sort: _filters.sort,
          );
      if (!mounted) return;
      setState(() {
        _catalogPage = result.page;
        _catalogTotal = result.total;
        _catalogItems = reset
            ? result.items
            : [..._catalogItems, ...result.items];
        _catalogLoading = false;
        _catalogLoadingMore = false;
        _catalogError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogLoadingMore = false;
        if (reset) {
          _catalogError = e.toString();
          _catalogItems = [];
          _catalogTotal = 0;
        }
      });
    }
  }

  void _applyFilters(CatalogFilters filters, {String? title}) {
    setState(() {
      _filters = filters;
      _catalogTitle = title ?? _titleForFilters(filters);
      _tab = 1;
    });
    _reloadCatalog();
  }

  String _titleForFilters(CatalogFilters f) {
    if (f.genre != null) {
      final hit = _taxonomies.genres.where((e) => e.slug == f.genre);
      if (hit.isNotEmpty) return hit.first.name;
    }
    if (f.country != null) {
      final hit = _taxonomies.countries.where((e) => e.slug == f.country);
      if (hit.isNotEmpty) return hit.first.name;
    }
    if (f.type != null) {
      final hit = _taxonomies.types.where((e) => e.slug == f.type);
      if (hit.isNotEmpty) return hit.first.name;
    }
    if (f.year != null) return 'Năm ${f.year}';
    return 'Phim';
  }

  void _openCatalog({String? title, String? type, String? genre}) {
    _searchCtrl.clear();
    _query = null;
    _applyFilters(
      CatalogFilters(type: type, genre: genre),
      title: title,
    );
  }

  Future<void> _showFilters() async {
    _taxonomiesFuture ??= context.read<ApiClient>().taxonomies().then((t) {
      _taxonomies = t;
      return t;
    });
    try {
      final tax = await _taxonomiesFuture!;
      if (!mounted) return;
      final next = await showCatalogFilterSheet(
        context,
        current: _filters,
        taxonomies: tax,
      );
      if (next == null || !mounted) return;
      _applyFilters(next);
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, 'Không tải được bộ lọc: $e', error: true);
    }
  }

  Future<void> _showMenu() async {
    final action = await showPublicMoreMenu(context);
    if (!mounted || action == null) return;

    switch (action) {
      case MoreMenuAction.profile:
        if (!context.read<AuthState>().isLoggedIn) {
          context.push('/login');
          return;
        }
        context.push('/profile');
      case MoreMenuAction.phimLe:
        _openCatalog(title: 'Phim Lẻ', type: 'phim-le');
      case MoreMenuAction.phimBo:
        _openCatalog(title: 'Phim Bộ', type: 'phim-bo');
      case MoreMenuAction.chieuRap:
        _openCatalog(title: 'Đang chiếu', type: 'phim-chieu-rap');
      case MoreMenuAction.catalog:
        _openCatalog(title: 'Phim');
      case MoreMenuAction.admin:
        context.push('/admin');
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
    final loggedIn = context.watch<AuthState>().isLoggedIn;
    if (loggedIn && _tab == 3 && _continueFuture == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            context.read<AuthState>().isLoggedIn &&
            _continueFuture == null) {
          unawaited(_reloadContinue());
        }
      });
    }
    if (loggedIn && _tab == 2 && _watchlistFuture == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            context.read<AuthState>().isLoggedIn &&
            _watchlistFuture == null) {
          unawaited(_reloadWatchlist());
        }
      });
    }

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
                items: _catalogItems,
                loading: _catalogLoading,
                loadingMore: _catalogLoadingMore,
                error: _catalogError,
                hasMore: _catalogItems.length < _catalogTotal,
                searchOpen: _searchOpen,
                searchCtrl: _searchCtrl,
                filtersActive: _filters.hasActive,
                onOpenFilters: _showFilters,
                onCloseSearch: () {
                  final hadQuery = _searchCtrl.text.trim().isNotEmpty;
                  _searchCtrl.clear();
                  setState(() => _searchOpen = false);
                  if (hadQuery) _reloadCatalog(clearQuery: true);
                },
                onSearch: (q) => _reloadCatalog(q: q),
                onRefresh: () async => _reloadCatalog(q: _searchCtrl.text),
                onLoadMore: () => _loadCatalog(reset: false),
                onOpenFilm: (slug) => context.push('/phim/$slug'),
              ),
              2 => _WatchlistFeed(
                loggedIn: context.watch<AuthState>().isLoggedIn,
                future: _watchlistFuture,
                onLogin: () => context.push('/login'),
                onRefresh: () async => _reloadWatchlist(),
                onOpenFilm: (slug) => context.push('/phim/$slug'),
              ),
              _ => _ContinueFeed(
                loggedIn: context.watch<AuthState>().isLoggedIn,
                future: _continueFuture,
                onLogin: () => context.push('/login'),
                onRefresh: () async => _reloadContinue(),
                onOpenDetail: (item) => context.push('/phim/${item.slug}'),
                onPlay: _openContinue,
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
          setState(() {
            _tab = i;
            if (!context.read<AuthState>().isLoggedIn) return;
            if (i == 2) {
              unawaited(_reloadWatchlist());
            } else if (i == 3) {
              unawaited(_reloadContinue());
            }
          });
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

class _CatalogFeed extends StatefulWidget {
  const _CatalogFeed({
    required this.title,
    required this.items,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.hasMore,
    required this.searchOpen,
    required this.searchCtrl,
    required this.filtersActive,
    required this.onOpenFilters,
    required this.onCloseSearch,
    required this.onSearch,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpenFilm,
  });

  final String title;
  final List<FilmCard> items;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final bool filtersActive;
  final VoidCallback onOpenFilters;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onOpenFilm;

  @override
  State<_CatalogFeed> createState() => _CatalogFeedState();
}

class _CatalogFeedState extends State<_CatalogFeed> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: widget.searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                hintText: 'Tìm phim…',
                prefixIcon: const Icon(Icons.search, color: CinevaColors.muted),
                suffixIcon: IconButton(
                  tooltip: 'Đóng tìm kiếm',
                  icon: const Icon(Icons.close, color: CinevaColors.muted),
                  onPressed: widget.onCloseSearch,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Bộ lọc',
                  onPressed: widget.onOpenFilters,
                  icon: Badge(
                    isLabelVisible: widget.filtersActive,
                    smallSize: 8,
                    backgroundColor: CinevaColors.accent,
                    child: Icon(
                      Icons.tune_rounded,
                      color: widget.filtersActive
                          ? CinevaColors.accent
                          : CinevaColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.loading && widget.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : widget.error != null && widget.items.isEmpty
              ? _ErrorPane(
                  message: widget.error!,
                  onRetry: () => widget.onRefresh(),
                )
              : widget.items.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có phim',
                    style: TextStyle(color: CinevaColors.muted),
                  ),
                )
              : Column(
                  children: [
                    if (widget.loadingMore)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: RefreshIndicator(
                        color: CinevaColors.accent,
                        onRefresh: widget.onRefresh,
                        child: GridView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _catalogCrossAxisCount(context),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.48,
                          ),
                          itemCount: widget.items.length,
                          itemBuilder: (context, i) {
                            final film = widget.items[i];
                            return FilmCardTile(
                              film: film,
                              onTap: () => widget.onOpenFilm(film.slug),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
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

class _ContinueFeed extends StatelessWidget {
  const _ContinueFeed({
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
                return _ErrorPane(
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

class _WatchlistFeed extends StatelessWidget {
  const _WatchlistFeed({
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
                return _ErrorPane(
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
                    crossAxisCount: _catalogCrossAxisCount(context),
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
