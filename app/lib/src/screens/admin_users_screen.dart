import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_toast.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:users')) {
        showCinevaToast(context, 'Không có quyền xem users', error: true);
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

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _items = [];
    });
    try {
      final res = await context.read<ApiClient>().adminListUsers(
            page: 1,
            search: _searchCtrl.text,
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
      final res = await context.read<ApiClient>().adminListUsers(
            page: _page + 1,
            search: _searchCtrl.text,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: Text('Người dùng ($_total)'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm username / email…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: CinevaColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final u = _items[i];
                            final active = u['isActive'] == true;
                            final roles = (u['roles'] is List)
                                ? (u['roles'] as List).join(', ')
                                : '';
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: CinevaColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: CinevaColors.accent
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      () {
                                        final n =
                                            u['username']?.toString() ?? '?';
                                        return n.isNotEmpty
                                            ? n[0].toUpperCase()
                                            : '?';
                                      }(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u['fullName']?.toString().isNotEmpty ==
                                                  true
                                              ? u['fullName'].toString()
                                              : u['username']?.toString() ??
                                                  '—',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@${u['username'] ?? ''}'
                                          '${u['email'] != null ? ' · ${u['email']}' : ''}',
                                          style: const TextStyle(
                                            color: CinevaColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (roles.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            roles,
                                            style: const TextStyle(
                                              color: CinevaColors.accent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (active
                                              ? const Color(0xFF3DDC97)
                                              : Colors.redAccent)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      active ? 'Active' : 'Off',
                                      style: TextStyle(
                                        color: active
                                            ? const Color(0xFF3DDC97)
                                            : Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
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
