import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/cineva_theme.dart';
import '../widgets/cineva_bottom_nav.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.body,
    required this.onShowMenu,
  });

  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;
  final Widget body;
  final VoidCallback onShowMenu;

  static const _navItems = [
    (Icons.home_rounded, 'Trang chủ'),
    (Icons.movie_filter_rounded, 'Phim'),
    (Icons.star_rounded, 'Tủ phim'),
    (Icons.history_rounded, 'Đã xem'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: CinevaColors.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
              SizedBox(
                height: 32,
                child: DragToMoveArea(
                  child: Container(
                    color: CinevaColors.bg,
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WindowCaption(
                          brightness: Brightness.dark,
                          backgroundColor: Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  _DesktopSidebar(
                    currentIndex: currentIndex,
                    onChanged: onNavigationChanged,
                    onShowMenu: onShowMenu,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: CinevaColors.bg,
      body: body,
      bottomNavigationBar: CinevaBottomNav(
        index: currentIndex,
        onChanged: (i) {
          if (i == 4) {
            onShowMenu();
          } else {
            onNavigationChanged(i);
          }
        },
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.currentIndex,
    required this.onChanged,
    required this.onShowMenu,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onShowMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: CinevaColors.navBg,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo area
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Text(
              'CINEVA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: CinevaColors.accent,
              ),
            ),
          ),
          // Nav items
          for (var i = 0; i < AdaptiveScaffold._navItems.length; i++)
            _SidebarItem(
              icon: AdaptiveScaffold._navItems[i].$1,
              label: AdaptiveScaffold._navItems[i].$2,
              active: currentIndex == i,
              onTap: () => onChanged(i),
            ),
          const Spacer(),
          // Settings / More
          _SidebarItem(
            icon: Icons.menu_rounded,
            label: 'Menu',
            active: false,
            onTap: onShowMenu,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? CinevaColors.accent : (
      _hovering ? Colors.white : CinevaColors.muted
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.active 
                ? CinevaColors.accent.withValues(alpha: 0.1) 
                : (_hovering ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: color, size: 24),
                const SizedBox(width: 16),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
