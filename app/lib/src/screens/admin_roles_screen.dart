import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_toast.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().hasPermission('read:roles')) {
        showCinevaToast(context, 'Không có quyền xem roles', error: true);
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
      final res = await context.read<ApiClient>().adminListRoles();
      if (!mounted) return;
      setState(() {
        _items = res.items;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: Text('Vai trò (${_items.length})'),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = _items[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CinevaColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: CinevaColors.accent.withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: CinevaColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name']?.toString() ?? '—',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (r['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r['description']}',
                                      style: const TextStyle(
                                        color: CinevaColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '${r['userCount'] ?? 0} users',
                              style: const TextStyle(
                                color: CinevaColors.muted,
                                fontSize: 12,
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
