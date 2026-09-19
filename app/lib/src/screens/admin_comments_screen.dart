import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_toast.dart';

class AdminCommentsScreen extends StatefulWidget {
  const AdminCommentsScreen({super.key});

  @override
  State<AdminCommentsScreen> createState() => _AdminCommentsScreenState();
}

class _AdminCommentsScreenState extends State<AdminCommentsScreen> {
  List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _busyId;
  final _scrollCtrl = ScrollController();

  bool get _canUpdate =>
      context.read<AuthState>().hasPermission('update:comments');

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:comments')) {
        showCinevaToast(context, 'Không có quyền xem bình luận', error: true);
        context.go('/admin');
        return;
      }
      _reload();
    });
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_items.length >= _total) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _items = [];
    });
    try {
      final res = await context.read<ApiClient>().adminListComments(page: 1);
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
    setState(() => _loadingMore = true);
    try {
      final res =
          await context.read<ApiClient>().adminListComments(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...res.items];
        _total = res.total;
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || !_canUpdate) return;
    final next = !(item['isHidden'] == true);
    setState(() => _busyId = id);
    try {
      await context.read<ApiClient>().adminSetCommentHidden(id, isHidden: next);
      if (!mounted) return;
      setState(() {
        item['isHidden'] = next;
        _busyId = null;
      });
      showCinevaToast(context, next ? 'Đã ẩn bình luận' : 'Đã hiện bình luận');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showCinevaToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: Text('Bình luận ($_total)'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
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
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final c = _items[i];
                      final hidden = c['isHidden'] == true;
                      final busy = _busyId == c['id']?.toString();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CinevaColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c['username']?.toString() ?? 'user',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (busy)
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else if (_canUpdate)
                                  Switch.adaptive(
                                    value: !hidden,
                                    onChanged: (_) => _toggle(c),
                                  )
                                else if (hidden)
                                  const Text(
                                    'Ẩn',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            if (c['filmName'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${c['filmName']}',
                                style: const TextStyle(
                                  color: CinevaColors.accent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              c['body']?.toString() ?? '',
                              style: TextStyle(
                                color: hidden
                                    ? CinevaColors.muted
                                    : Colors.white.withValues(alpha: 0.9),
                                height: 1.4,
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
