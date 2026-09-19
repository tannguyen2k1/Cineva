import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';

class AdminFeaturedScreen extends StatefulWidget {
  const AdminFeaturedScreen({super.key});

  @override
  State<AdminFeaturedScreen> createState() => _AdminFeaturedScreenState();
}

class _AdminFeaturedScreenState extends State<AdminFeaturedScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  bool get _canCreate =>
      context.read<AuthState>().hasPermission('create:featured');
  bool get _canDelete =>
      context.read<AuthState>().hasPermission('delete:featured');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:featured')) {
        showCinevaToast(context, 'Không có quyền xem nổi bật', error: true);
        context.go('/admin');
        return;
      }
      _reload();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ApiClient>().adminListFeatured();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openCreate() async {
    final result = await showModalBottomSheet<_FeaturedFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CinevaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => const _FeaturedEditorSheet(),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<ApiClient>().adminCreateFeatured(
            filmSlug: result.filmSlug,
            section: result.section,
            sortOrder: result.sortOrder,
          );
      if (!mounted) return;
      showCinevaToast(context, 'Đã thêm phim nổi bật');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || !_canDelete) return;
    final filmRaw = row['film'];
    final film = filmRaw is Map ? Map<String, dynamic>.from(filmRaw) : null;
    final name = film?['name']?.toString() ?? id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ khỏi nổi bật?'),
        content: Text(name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiClient>().adminDeleteFeatured(id);
      if (!mounted) return;
      showCinevaToast(context, 'Đã gỡ phim nổi bật');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: Text('Nổi bật (${_items.length})'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        actions: [
          if (_canCreate)
            IconButton(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Thêm nổi bật',
            ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        color: CinevaColors.accent,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(_error!)),
                      TextButton(onPressed: _reload, child: const Text('Thử lại')),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          const Center(
                            child: Text(
                              'Chưa có phim nổi bật',
                              style: TextStyle(color: CinevaColors.muted),
                            ),
                          ),
                          if (_canCreate)
                            Center(
                              child: TextButton(
                                onPressed: _openCreate,
                                child: const Text('Thêm phim'),
                              ),
                            ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final row = _items[i];
                          final filmRaw = row['film'];
                          final film = filmRaw is Map
                              ? Map<String, dynamic>.from(filmRaw)
                              : <String, dynamic>{};
                          final poster = film['posterUrl']?.toString() ??
                              film['thumbUrl']?.toString();
                          final name = film['name']?.toString() ?? '—';
                          final slug = film['slug']?.toString();
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CinevaColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 52,
                                    height: 72,
                                    child: poster != null && poster.isNotEmpty
                                        ? CinevaNetworkImage(
                                            url: poster,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(color: Colors.white12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: slug == null
                                        ? null
                                        : () => context.push('/phim/$slug'),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '#${row['sortOrder'] ?? i + 1}'
                                          ' · ${row['section'] ?? 'home_hot'}'
                                          '${slug != null ? ' · $slug' : ''}',
                                          style: const TextStyle(
                                            color: CinevaColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_canDelete)
                                  IconButton(
                                    onPressed: () => _delete(row),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
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

class _FeaturedFormData {
  const _FeaturedFormData({
    required this.filmSlug,
    required this.section,
    required this.sortOrder,
  });

  final String filmSlug;
  final String section;
  final int sortOrder;
}

class _FeaturedEditorSheet extends StatefulWidget {
  const _FeaturedEditorSheet();

  @override
  State<_FeaturedEditorSheet> createState() => _FeaturedEditorSheetState();
}

class _FeaturedEditorSheetState extends State<_FeaturedEditorSheet> {
  final _slug = TextEditingController();
  final _sort = TextEditingController(text: '0');

  @override
  void dispose() {
    _slug.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    final slug = _slug.text.trim();
    if (slug.isEmpty) {
      showCinevaToast(context, 'Cần film slug', error: true);
      return;
    }
    Navigator.pop(
      context,
      _FeaturedFormData(
        filmSlug: slug,
        section: 'home_hot',
        sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thêm phim nổi bật',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _slug,
            decoration: const InputDecoration(
              labelText: 'Film slug *',
              hintText: 'vd: spider-man',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sort,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Thứ tự'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Thêm')),
        ],
      ),
    );
  }
}
