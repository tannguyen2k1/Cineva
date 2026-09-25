import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/continue_item.dart';
import '../models/home_payload.dart';
import '../models/models.dart';
import '../models/taxonomies.dart';
import '../services/api_client.dart';
import '../state/app_mode_state.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import 'adaptive_scaffold.dart';
import '../widgets/catalog_filter_sheet.dart';
import '../widgets/cineva_header.dart';
import '../widgets/cineva_toast.dart';
import '../widgets/public_more_menu.dart';
import '../screens/adult_home_screen.dart';
import '../screens/main_tabs/catalog_tab.dart';
import '../screens/main_tabs/continue_tab.dart';
import '../screens/main_tabs/home_tab.dart';
import '../screens/main_tabs/watchlist_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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
          'posterUrl': detail.imageUrl,
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
    final appMode = context.watch<AppModeState>();
    if (appMode.is18Plus) {
      return const AdultHomeScreen();
    }

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

    return AdaptiveScaffold(
      currentIndex: _tab,
      onShowMenu: _showMenu,
      onNavigationChanged: (i) {
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
              0 => HomeTab(
                future: _homeFuture,
                slide: _slide,
                onSlide: (i) => setState(() => _slide = i),
                onRefresh: () async => _reloadHome(),
                onOpenFilm: (slug) => context.push('/phim/$slug'),
                onOpenTopic: _openTopic,
              ),
              1 => CatalogTab(
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
              2 => WatchlistTab(
                loggedIn: context.watch<AuthState>().isLoggedIn,
                future: _watchlistFuture,
                onLogin: () => context.push('/login'),
                onRefresh: () async => _reloadWatchlist(),
                onOpenFilm: (slug) => context.push('/phim/$slug'),
              ),
              _ => ContinueTab(
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
    );
  }
}

