import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_toast.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _lastSync;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthState>().isAdmin) {
        showCinevaToast(context, 'Bạn không có quyền admin', error: true);
        context.go('/');
        return;
      }
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().dashboardStats();
      final stats = data['stats'];
      final sync = data['lastSync'];
      if (!mounted) return;
      setState(() {
        _stats = stats is Map ? Map<String, dynamic>.from(stats) : null;
        _lastSync = sync is Map ? Map<String, dynamic>.from(sync) : null;
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

  int _n(String key) => (_stats?[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final name = auth.user?.fullName?.isNotEmpty == true
        ? auth.user!.fullName!
        : auth.user?.username ?? 'Admin';

    final modules = <_AdminModule>[
      if (auth.hasPermission('read:films'))
        const _AdminModule(
          icon: Icons.movie_filter_outlined,
          title: 'Phim',
          subtitle: 'Ẩn / hiện phim công khai',
          route: '/admin/films',
        ),
      if (auth.hasPermission('read:sync'))
        const _AdminModule(
          icon: Icons.sync_rounded,
          title: 'Đồng bộ',
          subtitle: 'Chạy sync & xem lịch sử',
          route: '/admin/sync',
        ),
      if (auth.hasPermission('read:banners'))
        const _AdminModule(
          icon: Icons.view_carousel_outlined,
          title: 'Banner',
          subtitle: 'Hero / banner trang chủ',
          route: '/admin/banners',
        ),
      if (auth.hasPermission('read:featured'))
        const _AdminModule(
          icon: Icons.local_fire_department_outlined,
          title: 'Nổi bật',
          subtitle: 'Phim hot trên trang chủ',
          route: '/admin/featured',
        ),
      if (auth.hasPermission('read:comments'))
        const _AdminModule(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Bình luận',
          subtitle: 'Ẩn bình luận vi phạm',
          route: '/admin/comments',
        ),
      if (auth.hasPermission('read:users'))
        const _AdminModule(
          icon: Icons.people_outline_rounded,
          title: 'Người dùng',
          subtitle: 'Danh sách thành viên',
          route: '/admin/users',
        ),
      if (auth.hasPermission('read:roles'))
        const _AdminModule(
          icon: Icons.shield_outlined,
          title: 'Vai trò',
          subtitle: 'Roles & quyền',
          route: '/admin/roles',
        ),
      if (auth.hasPermission('read:logs'))
        const _AdminModule(
          icon: Icons.receipt_long_outlined,
          title: 'Nhật ký',
          subtitle: 'System / audit log',
          route: '/admin/logs',
        ),
    ];

    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: const Text('Admin'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: CinevaColors.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Xin chào, $name',
              style: const TextStyle(color: CinevaColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_loading && _stats == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _stats == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              )
            else ...[
              const Text(
                'Tổng quan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    label: 'Phim',
                    value: '${_n('films')}',
                    hint: '${_n('filmsVisible')} đang hiện',
                    color: const Color(0xFFF5A524),
                  ),
                  _StatCard(
                    label: 'Bình luận',
                    value: '${_n('comments')}',
                    hint: '${_n('commentsHidden')} đã ẩn',
                    color: const Color(0xFF3DDC97),
                  ),
                  _StatCard(
                    label: 'Người dùng',
                    value: '${_n('users')}',
                    hint: 'Thành viên active',
                    color: const Color(0xFF5B8CFF),
                  ),
                  _StatCard(
                    label: 'CMS',
                    value: '${_n('bannersActive')}/${_n('featured')}',
                    hint: 'Banner / nổi bật',
                    color: const Color(0xFFFF6B6B),
                  ),
                ],
              ),
              if (_lastSync != null) ...[
                const SizedBox(height: 14),
                _SyncBanner(sync: _lastSync!),
              ],
            ],
            const SizedBox(height: 28),
            const Text(
              'Quản lý',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (modules.isEmpty)
              const Text(
                'Không có module nào trong quyền của bạn.',
                style: TextStyle(color: CinevaColors.muted),
              )
            else
              ...modules.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdminTile(
                    icon: m.icon,
                    title: m.title,
                    subtitle: m.subtitle,
                    onTap: () => context.push(m.route),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminModule {
  const _AdminModule({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: CinevaColors.muted, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(color: CinevaColors.muted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.sync});

  final Map<String, dynamic> sync;

  @override
  Widget build(BuildContext context) {
    final status = sync['status']?.toString() ?? '—';
    final job = sync['jobType']?.toString() ?? '—';
    final upserted = sync['itemsUpserted'];
    Color tone = CinevaColors.muted;
    if (status == 'success') tone = const Color(0xFF3DDC97);
    if (status == 'failed') tone = Colors.redAccent;
    if (status == 'running') tone = const Color(0xFFF5A524);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_sync_outlined, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sync gần nhất',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '$job · $status'
                  '${upserted != null ? ' · $upserted items' : ''}',
                  style: const TextStyle(
                    color: CinevaColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/admin/sync'),
            child: const Text('Chi tiết'),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CinevaColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: CinevaColors.accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: CinevaColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: CinevaColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CinevaColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
