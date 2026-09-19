import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  bool get _canCreate =>
      context.read<AuthState>().hasPermission('create:banners');
  bool get _canUpdate =>
      context.read<AuthState>().hasPermission('update:banners');
  bool get _canDelete =>
      context.read<AuthState>().hasPermission('delete:banners');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:banners')) {
        showCinevaToast(context, 'Không có quyền xem banner', error: true);
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
      final items = await context.read<ApiClient>().adminListBanners();
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

  Future<void> _toggle(Map<String, dynamic> b) async {
    final id = b['id']?.toString();
    if (id == null || !_canUpdate) return;
    final next = !(b['isActive'] == true);
    setState(() => _busyId = id);
    try {
      await context.read<ApiClient>().adminSetBannerActive(id, isActive: next);
      if (!mounted) return;
      setState(() {
        b['isActive'] = next;
        _busyId = null;
      });
      showCinevaToast(context, next ? 'Đã bật banner' : 'Đã tắt banner');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showCinevaToast(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final id = b['id']?.toString();
    if (id == null || !_canDelete) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa banner?'),
        content: Text(b['title']?.toString() ?? id),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiClient>().adminDeleteBanner(id);
      if (!mounted) return;
      showCinevaToast(context, 'Đã xóa banner');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<_BannerFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CinevaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _BannerEditorSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    try {
      final api = context.read<ApiClient>();
      if (existing != null) {
        await api.adminUpdateBanner(
          existing['id'].toString(),
          title: result.title,
          imageUrl: result.imageUrl,
          filmSlug: result.filmSlug,
          linkUrl: result.linkUrl,
          sortOrder: result.sortOrder,
          isActive: result.isActive,
        );
        if (!mounted) return;
        showCinevaToast(context, 'Đã cập nhật banner');
      } else {
        await api.adminCreateBanner(
          title: result.title,
          imageUrl: result.imageUrl,
          filmSlug: result.filmSlug,
          linkUrl: result.linkUrl,
          sortOrder: result.sortOrder,
          isActive: result.isActive,
        );
        if (!mounted) return;
        showCinevaToast(context, 'Đã thêm banner');
      }
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
        title: Text('Banner (${_items.length})'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        actions: [
          if (_canCreate)
            IconButton(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Thêm banner',
            ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
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
                              'Chưa có banner',
                              style: TextStyle(color: CinevaColors.muted),
                            ),
                          ),
                          if (_canCreate)
                            Center(
                              child: TextButton(
                                onPressed: () => _openEditor(),
                                child: const Text('Thêm banner'),
                              ),
                            ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final b = _items[i];
                          final active = b['isActive'] == true;
                          final busy = _busyId == b['id']?.toString();
                          final image = b['imageUrl']?.toString();
                          return Container(
                            decoration: BoxDecoration(
                              color: CinevaColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 7,
                                  child: image != null && image.isNotEmpty
                                      ? CinevaNetworkImage(
                                          url: image,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.white12,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    8,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              b['title']?.toString() ??
                                                  'Banner',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (b['filmSlug'] != null &&
                                                    '${b['filmSlug']}'
                                                        .isNotEmpty)
                                                  '${b['filmSlug']}',
                                                '#${b['sortOrder'] ?? 0}',
                                              ].join(' · '),
                                              style: const TextStyle(
                                                color: CinevaColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (busy)
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else if (_canUpdate)
                                        Switch.adaptive(
                                          value: active,
                                          onChanged: (_) => _toggle(b),
                                        ),
                                      if (_canUpdate)
                                        IconButton(
                                          onPressed: () =>
                                              _openEditor(existing: b),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      if (_canDelete)
                                        IconButton(
                                          onPressed: () => _delete(b),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                    ],
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

class _BannerFormData {
  const _BannerFormData({
    required this.title,
    required this.imageUrl,
    required this.filmSlug,
    required this.linkUrl,
    required this.sortOrder,
    required this.isActive,
  });

  final String title;
  final String imageUrl;
  final String? filmSlug;
  final String? linkUrl;
  final int sortOrder;
  final bool isActive;
}

class _BannerEditorSheet extends StatefulWidget {
  const _BannerEditorSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_BannerEditorSheet> createState() => _BannerEditorSheetState();
}

class _BannerEditorSheetState extends State<_BannerEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _image;
  late final TextEditingController _slug;
  late final TextEditingController _link;
  late final TextEditingController _sort;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title']?.toString() ?? '');
    _image = TextEditingController(text: e?['imageUrl']?.toString() ?? '');
    _slug = TextEditingController(text: e?['filmSlug']?.toString() ?? '');
    _link = TextEditingController(text: e?['linkUrl']?.toString() ?? '');
    _sort = TextEditingController(
      text: '${e?['sortOrder'] ?? 0}',
    );
    _active = e?['isActive'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _image.dispose();
    _slug.dispose();
    _link.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final image = _image.text.trim();
    if (title.isEmpty || image.isEmpty) {
      showCinevaToast(context, 'Cần tiêu đề và URL ảnh', error: true);
      return;
    }
    Navigator.pop(
      context,
      _BannerFormData(
        title: title,
        imageUrl: image,
        filmSlug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
        linkUrl: _link.text.trim().isEmpty ? null : _link.text.trim(),
        sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Sửa banner' : 'Thêm banner',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Tiêu đề *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _image,
              decoration: const InputDecoration(
                labelText: 'URL ảnh *',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Film slug',
                hintText: 'vd: spider-man',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Link URL',
                hintText: '/phim/... hoặc https://...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sort,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Thứ tự'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang bật'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              child: Text(isEdit ? 'Lưu' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}
