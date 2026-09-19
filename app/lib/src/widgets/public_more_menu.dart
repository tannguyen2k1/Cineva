import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import 'notification_bell.dart';

enum MoreMenuAction {
  profile,
  phimLe,
  phimBo,
  chieuRap,
  catalog,
  admin,
  logout,
}

Future<MoreMenuAction?> showPublicMoreMenu(BuildContext context) {
  return showModalBottomSheet<MoreMenuAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A0A0A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0x4DFFFFFF)),
    ),
    builder: (ctx) => const _PublicMoreMenuSheet(),
  );
}

class _PublicMoreMenuSheet extends StatelessWidget {
  const _PublicMoreMenuSheet();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final isAdmin = auth.isAdmin;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 4, bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khám phá thêm',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Truy cập nhanh các khu vực khác của hệ thống.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (user != null) const NotificationBell(compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              name: user?.fullName?.isNotEmpty == true
                  ? user!.fullName!
                  : (user?.username ?? 'Khách'),
              subtitle: user != null
                  ? 'Xem hồ sơ và cài đặt tài khoản'
                  : 'Đăng nhập để đồng bộ tủ phim và lịch sử',
              onTap: () => Navigator.pop(context, MoreMenuAction.profile),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.35,
              children: [
                _GridCard(
                  icon: Icons.movie_outlined,
                  tone: _Tone.yellow,
                  title: 'Phim Lẻ',
                  subtitle: 'Duyệt nhanh',
                  onTap: () => Navigator.pop(context, MoreMenuAction.phimLe),
                ),
                _GridCard(
                  icon: Icons.collections_bookmark_outlined,
                  tone: _Tone.purple,
                  title: 'Phim Bộ',
                  subtitle: 'Duyệt nhanh',
                  onTap: () => Navigator.pop(context, MoreMenuAction.phimBo),
                ),
                _GridCard(
                  icon: Icons.play_circle_outline,
                  tone: _Tone.pink,
                  title: 'Đang chiếu',
                  subtitle: 'Phim đang công chiếu',
                  onTap: () => Navigator.pop(context, MoreMenuAction.chieuRap),
                ),
                _GridCard(
                  icon: Icons.grid_view_rounded,
                  tone: _Tone.blue,
                  title: 'Phim',
                  subtitle: 'Toàn bộ kho phim',
                  onTap: () => Navigator.pop(context, MoreMenuAction.catalog),
                ),
              ],
            ),
            if (user != null || isAdmin) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Column(
                  children: [
                    if (isAdmin)
                      _ListRow(
                        icon: Icons.settings_outlined,
                        label: 'Admin',
                        onTap: () =>
                            Navigator.pop(context, MoreMenuAction.admin),
                      ),
                    if (user != null)
                      _ListRow(
                        icon: Icons.logout_rounded,
                        label: 'Đăng xuất',
                        danger: true,
                        showDivider: isAdmin,
                        onTap: () =>
                            Navigator.pop(context, MoreMenuAction.logout),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Tone { blue, yellow, purple, pink }

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CinevaColors.accent.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(
                    color: CinevaColors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final _Tone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  Color get _fg => switch (tone) {
    _Tone.blue => const Color(0xFF3B82F6),
    _Tone.yellow => const Color(0xFFEAB308),
    _Tone.purple => const Color(0xFFA855F7),
    _Tone.pink => const Color(0xFFEC4899),
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _fg.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: _fg, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.showDivider = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFF97316) : const Color(0xFFE5E7EB);
    final iconColor = danger ? const Color(0xFFF97316) : const Color(0xFF9CA3AF);

    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFF262626)),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
