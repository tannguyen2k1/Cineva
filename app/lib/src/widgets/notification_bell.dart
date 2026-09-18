import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/notification.dart';
import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import 'cineva_network_image.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.compact = false});

  /// Slightly larger hit target for menu header.
  final bool compact;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUnread());
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _refreshUnread());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      if (mounted) setState(() => _unread = 0);
      return;
    }
    try {
      final count = await context.read<ApiClient>().notificationsUnreadCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {
      // ignore transient errors
    }
  }

  Future<void> _openPanel() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0x1AFFFFFF)),
      ),
      builder: (ctx) => _NotificationsSheet(initialUnread: _unread),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _unread = result);
    } else {
      await _refreshUnread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.isLoggedIn) return const SizedBox.shrink();

    final size = widget.compact ? 36.0 : 38.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Thông báo',
          onPressed: _openPanel,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            foregroundColor: const Color(0xFFE4E4E7),
            minimumSize: Size(size, size),
            maximumSize: Size(size, size),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.notifications_none_rounded, size: 20),
        ),
        if (_unread > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.initialUnread});

  final int initialUnread;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  late Future<NotificationListResult> _future;
  late int _unread;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _unread = widget.initialUnread;
    _future = context.read<ApiClient>().listNotifications();
  }

  Future<void> _markAll() async {
    setState(() => _marking = true);
    try {
      await context.read<ApiClient>().markAllNotificationsRead();
      final current = await _future;
      setState(() {
        _unread = 0;
        _future = Future.value(
          NotificationListResult(
            items: current.items.map((e) => e.copyWith(isRead: true)).toList(),
            unreadCount: 0,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _openItem(AppNotification n) async {
    final api = context.read<ApiClient>();
    var unread = _unread;
    if (!n.isRead) {
      try {
        await api.markNotificationRead(n.id);
        unread = (_unread - 1).clamp(0, 9999);
        final current = await _future;
        setState(() {
          _unread = unread;
          _future = Future.value(
            NotificationListResult(
              items: [
                for (final item in current.items)
                  if (item.id == n.id) item.copyWith(isRead: true) else item,
              ],
              unreadCount: unread,
            ),
          );
        });
      } catch (_) {}
    }

    if (!mounted) return;
    final router = GoRouter.of(context);
    Navigator.pop(context, unread);

    final link = n.linkUrl?.trim();
    if (link == null || link.isEmpty) {
      if (n.filmSlug != null && n.filmSlug!.isNotEmpty) {
        router.push('/phim/${n.filmSlug}');
      }
      return;
    }

    if (link.startsWith('/phim/') || link.startsWith('/xem/')) {
      final parts = link.split('/').where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) {
        router.push('/phim/${parts[1]}');
      }
      return;
    }
    if (n.filmSlug != null && n.filmSlug!.isNotEmpty) {
      router.push('/phim/${n.filmSlug}');
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: SizedBox(
        height: maxH.clamp(320.0, 520.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thông báo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF4F4F5),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _unread == 0 || _marking ? null : _markAll,
                    child: _marking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Đọc hết',
                            style: TextStyle(
                              color: CinevaColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x0FFFFFFF)),
            Expanded(
              child: FutureBuilder<NotificationListResult>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snap.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CinevaColors.muted),
                        ),
                      ),
                    );
                  }
                  final items = snap.data?.items ?? const [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có thông báo',
                        style: TextStyle(color: CinevaColors.muted),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0x0DFFFFFF)),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      return InkWell(
                        onTap: () => _openItem(n),
                        child: Container(
                          color: n.isRead
                              ? null
                              : CinevaColors.accent.withValues(alpha: 0.05),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (n.filmImageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 40,
                                    height: 56,
                                    child: CinevaNetworkImage(
                                      url: n.filmImageUrl!,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: CinevaColors.accent.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    () {
                                      final name = n.actorName?.trim();
                                      if (name == null || name.isEmpty) {
                                        return '?';
                                      }
                                      return name.substring(0, 1).toUpperCase();
                                    }(),
                                    style: const TextStyle(
                                      color: CinevaColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: const TextStyle(
                                        color: Color(0xFFF4F4F5),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (n.body != null &&
                                        n.body!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        n.body!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: CinevaColors.muted,
                                          fontSize: 12.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                    if (n.createdAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(n.createdAt),
                                        style: const TextStyle(
                                          color: CinevaColors.mutedSoft,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
