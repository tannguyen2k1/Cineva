import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  String _category = 'all';
  String _action = 'all';
  List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  final _categories = const [
    {'key': 'all', 'label': 'Tất cả', 'icon': Icons.apps_rounded},
    {'key': 'watch', 'label': 'Xem phim', 'icon': Icons.play_circle_fill_rounded},
    {'key': 'engagement', 'label': 'Tương tác', 'icon': Icons.star_rounded},
    {'key': 'auth', 'label': 'Đăng nhập', 'icon': Icons.lock_rounded},
    {'key': 'system', 'label': 'Hệ thống', 'icon': Icons.settings_rounded},
  ];

  static const _allActions = [
    {'value': 'all', 'label': 'Tất cả hành động', 'cat': 'all'},
    {'value': 'WATCH_FILM', 'label': 'Xem phim', 'cat': 'watch'},
    {'value': 'SEARCH_FILM', 'label': 'Tìm kiếm', 'cat': 'watch'},
    {'value': 'ADD_WATCHLIST', 'label': 'Lưu phim', 'cat': 'engagement'},
    {'value': 'REMOVE_WATCHLIST', 'label': 'Bỏ lưu phim', 'cat': 'engagement'},
    {'value': 'FOLLOW_FILM', 'label': 'Theo dõi', 'cat': 'engagement'},
    {'value': 'UNFOLLOW_FILM', 'label': 'Bỏ theo dõi', 'cat': 'engagement'},
    {'value': 'POST_COMMENT', 'label': 'Bình luận', 'cat': 'engagement'},
    {'value': 'LOGIN', 'label': 'Đăng nhập', 'cat': 'auth'},
    {'value': 'LOGOUT', 'label': 'Đăng xuất', 'cat': 'auth'},
    {'value': 'PASSWORD_CHANGE', 'label': 'Đổi mật khẩu', 'cat': 'auth'},
    {'value': 'CREATE_USER', 'label': 'Tạo user', 'cat': 'system'},
    {'value': 'UPDATE_USER', 'label': 'Sửa user', 'cat': 'system'},
    {'value': 'DELETE_USER', 'label': 'Xóa user', 'cat': 'system'},
  ];

  List<Map<String, String>> get _availableActions {
    if (_category == 'all') return _allActions;
    return [
      const {'value': 'all', 'label': 'Tất cả hành động', 'cat': 'all'},
      ..._allActions.where((a) => a['cat'] == _category),
    ];
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:logs')) {
        showCinevaToast(context, 'Không có quyền xem logs', error: true);
        context.go('/admin');
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
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _setCategory(String cat) {
    if (_category == cat) return;
    setState(() {
      _category = cat;
      _action = 'all';
    });
    _reload();
  }

  void _setAction(String act) {
    if (_action == act) return;
    setState(() => _action = act);
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _items = [];
    });
    try {
      final res = await context.read<ApiClient>().adminListLogs(
            page: 1,
            search: _searchCtrl.text,
            category: _category,
            action: _action,
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
    setState(() => _loadingMore = true);
    try {
      final res = await context.read<ApiClient>().adminListLogs(
            page: _page + 1,
            search: _searchCtrl.text,
            category: _category,
            action: _action,
          );
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

  String _formatAction(String action) {
    switch (action) {
      case 'WATCH_FILM':
        return 'Xem phim';
      case 'ADD_WATCHLIST':
        return 'Thêm tủ phim';
      case 'REMOVE_WATCHLIST':
        return 'Xóa tủ phim';
      case 'FOLLOW_FILM':
        return 'Theo dõi phim';
      case 'UNFOLLOW_FILM':
        return 'Bỏ theo dõi';
      case 'POST_COMMENT':
        return 'Bình luận';
      case 'SEARCH_FILM':
        return 'Tìm kiếm';
      case 'LOGIN':
        return 'Đăng nhập';
      case 'LOGOUT':
        return 'Đăng xuất';
      case 'PASSWORD_CHANGE':
        return 'Đổi mật khẩu';
      case 'CREATE_USER':
        return 'Tạo user';
      case 'UPDATE_USER':
        return 'Sửa user';
      case 'DELETE_USER':
        return 'Xóa user';
      default:
        return action;
    }
  }

  Color _actionColor(String action) {
    if (action.contains('DELETE') || action.contains('REMOVE')) {
      return Colors.redAccent;
    }
    if (action.contains('UPDATE') || action.contains('MODERATE')) {
      return Colors.amber;
    }
    if (action.contains('WATCH') || action.contains('ADD') || action.contains('CREATE')) {
      return Colors.greenAccent;
    }
    if (action.contains('LOGIN') || action.contains('FOLLOW')) {
      return Colors.lightBlueAccent;
    }
    return CinevaColors.muted;
  }

  String _formatDuration(int? sec) {
    if (sec == null || sec <= 0) return '';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }

  void _showLogDetail(Map<String, dynamic> log) {
    final details = log['details'];
    showModalBottomSheet(
      context: context,
      backgroundColor: CinevaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _actionColor(log['action']?.toString() ?? '').withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatAction(log['action']?.toString() ?? ''),
                      style: TextStyle(
                        color: _actionColor(log['action']?.toString() ?? ''),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    log['createdAt']?.toString() ?? '',
                    style: const TextStyle(color: CinevaColors.muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Thực hiện: ${log['actor'] ?? log['actorUsername'] ?? 'Hệ thống'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text('Chi tiết Payload:', style: TextStyle(color: CinevaColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CinevaColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    details is Map
                        ? const JsonEncoder.withIndent('  ').convert(details)
                        : details?.toString() ?? 'Không có dữ liệu',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: Text('Nhật ký ($_total)'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm user, phim, action…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: CinevaColors.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Dropdowns: Phân loại & Hành động
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: CinevaColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isExpanded: true,
                        dropdownColor: CinevaColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: CinevaColors.muted,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _categories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['key'] as String,
                            child: Row(
                              children: [
                                Icon(
                                  c['icon'] as IconData,
                                  size: 15,
                                  color: CinevaColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    c['label'] as String,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) _setCategory(v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: CinevaColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _availableActions.any((a) => a['value'] == _action)
                            ? _action
                            : 'all',
                        isExpanded: true,
                        dropdownColor: CinevaColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: CinevaColors.muted,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _availableActions.map((a) {
                          return DropdownMenuItem<String>(
                            value: a['value']!,
                            child: Text(
                              a['label']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) _setAction(v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              color: CinevaColors.accent,
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _items.isEmpty
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
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final log = _items[i];
                            final actor = log['actor'] ?? log['actorUsername'] ?? 'Hệ thống';
                            final action = log['action']?.toString() ?? '';
                            final details = log['details'] is Map ? log['details'] as Map : null;
                            final filmName = details?['filmName']?.toString();
                            final posterUrl = details?['posterUrl']?.toString();
                            final epName = details?['episodeName']?.toString();
                            final posSec = (details?['positionSec'] as num?)?.toInt();

                            return InkWell(
                              onTap: () => _showLogDetail(log),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
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
                                    // Row 1: Actor + Time
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.white12,
                                          backgroundImage: log['actorAvatar'] != null
                                              ? NetworkImage(log['actorAvatar'])
                                              : null,
                                          child: log['actorAvatar'] == null
                                              ? Text(
                                                  actor.isNotEmpty ? actor[0].toUpperCase() : 'S',
                                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            actor,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          log['createdAt']?.toString().split('T').first ?? '',
                                          style: const TextStyle(
                                            color: CinevaColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 2: Action badge + Film / Details
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _actionColor(action).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _formatAction(action),
                                            style: TextStyle(
                                              color: _actionColor(action),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (filmName != null) ...[
                                          if (posterUrl != null && posterUrl.isNotEmpty) ...[
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: SizedBox(
                                                width: 22,
                                                height: 30,
                                                child: CinevaNetworkImage(
                                                  url: posterUrl,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              '$filmName${epName != null ? ' - $epName' : ''}${posSec != null ? ' (${_formatDuration(posSec)})' : ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ] else if (details?['keyword'] != null) ...[
                                          Expanded(
                                            child: Text(
                                              '"${details!['keyword']}"',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          Expanded(
                                            child: Text(
                                              log['details']?.toString() ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: CinevaColors.muted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
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
