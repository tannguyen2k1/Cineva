import 'package:flutter/material.dart';

import '../theme/cineva_theme.dart';
import 'cineva_brand_mark.dart';
import 'notification_bell.dart';

class CinevaHeader extends StatelessWidget {
  const CinevaHeader({
    super.key,
    this.onSearch,
    this.trailing,
    this.showTagline = false,
    this.showNotifications = true,
  });

  final VoidCallback? onSearch;
  final Widget? trailing;
  final bool showTagline;
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CinevaColors.bg.withValues(alpha: 0.82),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                const CinevaBrandMark(size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cineva',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      if (showTagline)
                        const Text(
                          'Xem phim chất lượng cao',
                          style: TextStyle(
                            color: CinevaColors.muted,
                            fontSize: 11,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showNotifications) ...[
                  const NotificationBell(),
                  const SizedBox(width: 4),
                ],
                if (onSearch != null)
                  IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: onSearch,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.search_rounded, size: 20),
                  ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
