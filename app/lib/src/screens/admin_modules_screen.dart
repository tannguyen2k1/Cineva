import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';

class AdminModulesScreen extends StatelessWidget {
  const AdminModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

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
        title: const Text('Quản lý'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: modules.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không có module nào trong quyền của bạn.',
                  style: TextStyle(color: CinevaColors.muted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: modules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = modules[i];
                return _AdminModuleTile(
                  icon: m.icon,
                  title: m.title,
                  subtitle: m.subtitle,
                  onTap: () => context.push(m.route),
                );
              },
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

class _AdminModuleTile extends StatelessWidget {
  const _AdminModuleTile({
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
