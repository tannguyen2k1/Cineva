import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';

class AdminFilmsScreen extends StatefulWidget {
  const AdminFilmsScreen({super.key});

  @override
  State<AdminFilmsScreen> createState() => _AdminFilmsScreenState();
}

class _AdminFilmsScreenState extends State<AdminFilmsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<FilmCard> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _savingSlug;

  bool get _canUpdate =>
      context.read<AuthState>().hasPermission('update:films');

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().isAdmin) {
        showCinevaToast(context, 'Bạn không có quyền admin', error: true);
        context.go('/');
        return;
      }
      _reload();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_items.length >= _total) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _items = [];
    });
    try {
      final res = await context.read<ApiClient>().adminListFilms(
        page: 1,
        q: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        _page = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final res = await context.read<ApiClient>().adminListFilms(
        page: next,
        q: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...res.items];
        _total = res.total;
        _page = next;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showCinevaToast(context, 'Không tải thêm được: $e', error: true);
    }
  }

  Future<void> _toggleVisible(FilmCard film, bool visible) async {
    if (!_canUpdate) {
      showCinevaToast(context, 'Không có quyền cập nhật phim', error: true);
      return;
    }
    setState(() => _savingSlug = film.slug);
    try {
      await context.read<ApiClient>().adminSetFilmHidden(
        film.slug,
        isHidden: !visible,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final f in _items)
            if (f.slug == film.slug) f.copyWith(isHidden: !visible) else f,
        ];
      });
      showCinevaToast(
        context,
        visible ? 'Đã hiện phim' : 'Đã ẩn phim',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingSlug = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: const Text('Quản lý phim'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên / slug…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _loading ? 'Đang tải…' : '$_total phim',
                style: const TextStyle(
                  color: CinevaColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: CinevaColors.muted),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'Không có phim',
                      style: TextStyle(color: CinevaColors.muted),
                    ),
                  )
                : RefreshIndicator(
                    color: CinevaColors.accent,
                    onRefresh: _reload,
                    child: ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      itemCount: _items.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final film = _items[i];
                        final saving = _savingSlug == film.slug;
                        return _AdminFilmRow(
                          film: film,
                          canUpdate: _canUpdate,
                          saving: saving,
                          onToggle: (v) => _toggleVisible(film, v),
                          onOpen: () => context.push('/phim/${film.slug}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminFilmRow extends StatelessWidget {
  const _AdminFilmRow({
    required this.film,
    required this.canUpdate,
    required this.saving,
    required this.onToggle,
    required this.onOpen,
  });

  final FilmCard film;
  final bool canUpdate;
  final bool saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = !film.isHidden;
    return Material(
      color: CinevaColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: CinevaNetworkImage(url: film.imageUrl),
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
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (film.year != null) film.year!,
                        if (film.currentEpisode != null) film.currentEpisode!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CinevaColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      film.slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CinevaColors.mutedSoft,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    visible ? 'Hiện' : 'Ẩn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: visible
                          ? const Color(0xFF4ADE80)
                          : CinevaColors.muted,
                    ),
                  ),
                  if (saving)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Switch.adaptive(
                      value: visible,
                      onChanged: canUpdate ? onToggle : null,
                      activeThumbColor: CinevaColors.onAccent,
                      activeTrackColor: CinevaColors.accent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
