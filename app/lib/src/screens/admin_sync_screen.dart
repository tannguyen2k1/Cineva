import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_toast.dart';

class AdminSyncScreen extends StatefulWidget {
  const AdminSyncScreen({super.key});

  @override
  State<AdminSyncScreen> createState() => _AdminSyncScreenState();
}

class _AdminSyncScreenState extends State<AdminSyncScreen> {
  List<Map<String, dynamic>> _runs = [];
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _running = false;
  String? _error;
  final _scrollCtrl = ScrollController();

  bool get _canCreate =>
      context.read<AuthState>().hasPermission('create:sync');

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:sync')) {
        showCinevaToast(context, 'Không có quyền xem sync', error: true);
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
    if (_runs.length >= _total) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _runs = [];
    });
    try {
      final res = await context.read<ApiClient>().adminListSyncRuns(page: 1);
      if (!mounted) return;
      setState(() {
        _runs = res.items;
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
          await context.read<ApiClient>().adminListSyncRuns(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _runs = [..._runs, ...res.items];
        _total = res.total;
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action, String label) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await action();
      if (!mounted) return;
      showCinevaToast(context, 'Đã chạy $label');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'success':
        return const Color(0xFF3DDC97);
      case 'failed':
        return Colors.redAccent;
      case 'running':
        return const Color(0xFFF5A524);
      default:
        return CinevaColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: const Text('Đồng bộ'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: Column(
        children: [
          if (_canCreate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _running
                          ? null
                          : () => _run(
                                () => context
                                    .read<ApiClient>()
                                    .adminRunIncrementalSync(),
                                'incremental',
                              ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Incremental'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _running
                          ? null
                          : () => _run(
                                () => context
                                    .read<ApiClient>()
                                    .adminRunCatalogSync(),
                                'catalog',
                              ),
                      icon: const Icon(Icons.library_books_outlined, size: 18),
                      label: const Text('Catalog'),
                    ),
                  ),
                ],
              ),
            ),
          if (_running)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              color: CinevaColors.accent,
              child: _loading && _runs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _runs.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(child: Text(_error!)),
                            TextButton(onPressed: _reload, child: const Text('Thử lại')),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _runs.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i >= _runs.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final r = _runs[i];
                            final status = r['status']?.toString() ?? '—';
                            final tone = _statusColor(status);
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
                                          r['jobType']?.toString() ?? 'sync',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tone.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: tone,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upserted: ${r['itemsUpserted'] ?? 0}'
                                    ' · Inserted: ${r['itemsInserted'] ?? 0}'
                                    ' · Failed: ${r['itemsFailed'] ?? 0}',
                                    style: const TextStyle(
                                      color: CinevaColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (r['startedAt'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r['startedAt']}',
                                      style: const TextStyle(
                                        color: CinevaColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (r['error'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${r['error']}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
