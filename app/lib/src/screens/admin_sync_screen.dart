import 'dart:async';

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
  Map<String, dynamic>? _latestFull;
  Timer? _pollTimer;
  final _scrollCtrl = ScrollController();

  bool get _canCreate =>
      context.read<AuthState>().hasPermission('create:sync');

  bool get _fullRunning =>
      _latestFull?['status']?.toString() == 'running';

  bool get _canResumeFull {
    final s = _latestFull?['status']?.toString();
    return s == 'failed' || s == 'running';
  }

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
    _pollTimer?.cancel();
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

  void _armPoll() {
    _pollTimer?.cancel();
    if (!_fullRunning) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      try {
        final full = await context.read<ApiClient>().adminFullSyncStatus();
        if (!mounted) return;
        setState(() => _latestFull = full);
        if (full?['status']?.toString() != 'running') {
          _pollTimer?.cancel();
          await _reload();
        }
      } catch (_) {}
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _runs = [];
    });
    try {
      final api = context.read<ApiClient>();
      final res = await api.adminListSyncRuns(page: 1);
      final full = await api.adminFullSyncStatus();
      if (!mounted) return;
      setState(() {
        _runs = res.items;
        _total = res.total;
        _page = 1;
        _latestFull = full;
        _loading = false;
      });
      _armPoll();
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

  Future<void> _confirmAndRun({
    required String title,
    required String body,
    required Future<Map<String, dynamic>> Function() action,
    required String toastOk,
  }) async {
    if (_running) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CinevaColors.surface,
        title: Text(title),
        content: Text(body, style: const TextStyle(color: CinevaColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _running = true);
    try {
      await action();
      if (!mounted) return;
      showCinevaToast(context, toastOk);
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

  String _jobLabel(String? job) {
    switch (job) {
      case 'full':
        return 'Toàn bộ';
      case 'catalog':
        return 'Catalog';
      case 'incremental':
        return 'Incremental';
      case 'images':
        return 'Ảnh';
      default:
        return job ?? 'sync';
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _running || _fullRunning;

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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _confirmAndRun(
                                    title: 'Incremental',
                                    body:
                                        'Cào vài trang phim mới nhất. Chạy nhanh.',
                                    action: () => context
                                        .read<ApiClient>()
                                        .adminRunIncrementalSync(),
                                    toastOk: 'Đã chạy incremental',
                                  ),
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Incremental'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _confirmAndRun(
                                    title: 'Catalog',
                                    body:
                                        'Đồng bộ ~5 trang mỗi nguồn (đủ trang chủ). Có thể mất vài phút.',
                                    action: () => context
                                        .read<ApiClient>()
                                        .adminRunCatalogSync(),
                                    toastOk: 'Đã chạy catalog',
                                  ),
                          icon: const Icon(
                            Icons.library_books_outlined,
                            size: 18,
                          ),
                          label: const Text('Catalog'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: CinevaColors.accentDeep,
                            foregroundColor: CinevaColors.onAccent,
                          ),
                          onPressed: busy
                              ? null
                              : () => _confirmAndRun(
                                    title: 'Cào toàn bộ',
                                    body:
                                        'Cào toàn bộ danh mục nguồn và tải poster. Chạy lâu, có checkpoint để tiếp tục nếu gián đoạn.',
                                    action: () => context
                                        .read<ApiClient>()
                                        .adminRunFullSync(),
                                    toastOk: 'Đã bắt đầu cào toàn bộ',
                                  ),
                          icon: const Icon(Icons.cloud_download_rounded, size: 18),
                          label: const Text('Cào toàn bộ'),
                        ),
                      ),
                      if (_canResumeFull) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _running
                                ? null
                                : () => _confirmAndRun(
                                      title: 'Tiếp tục Full',
                                      body:
                                          'Tiếp tục job full từ checkpoint gần nhất.',
                                      action: () => context
                                          .read<ApiClient>()
                                          .adminRunFullSync(resume: true),
                                      toastOk: 'Đã resume full sync',
                                    ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Resume'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          if (_latestFull != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _FullProgressCard(
                run: _latestFull!,
                tone: _statusColor(_latestFull!['status']?.toString()),
              ),
            ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
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
                            TextButton(
                              onPressed: _reload,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _runs.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i >= _runs.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
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
                                          _jobLabel(r['jobType']?.toString()),
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                  if ((r['imagesDownloaded'] ?? 0) != 0 ||
                                      (r['imagesFailed'] ?? 0) != 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ảnh: ${r['imagesDownloaded'] ?? 0}'
                                      ' · lỗi: ${r['imagesFailed'] ?? 0}',
                                      style: const TextStyle(
                                        color: CinevaColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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

class _FullProgressCard extends StatelessWidget {
  const _FullProgressCard({required this.run, required this.tone});

  final Map<String, dynamic> run;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final status = run['status']?.toString() ?? '—';
    final upserted = (run['itemsUpserted'] is num)
        ? (run['itemsUpserted'] as num).toInt()
        : int.tryParse('${run['itemsUpserted']}') ?? 0;
    final imgs = (run['imagesDownloaded'] is num)
        ? (run['imagesDownloaded'] as num).toInt()
        : int.tryParse('${run['imagesDownloaded']}') ?? 0;
    final imgFail = (run['imagesFailed'] is num)
        ? (run['imagesFailed'] as num).toInt()
        : int.tryParse('${run['imagesFailed']}') ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: tone, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Full sync · $status',
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Phim: $upserted · Ảnh: $imgs · Ảnh lỗi: $imgFail',
            style: const TextStyle(color: CinevaColors.muted, fontSize: 12),
          ),
          if (status == 'running') ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              color: tone,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ],
      ),
    );
  }
}
