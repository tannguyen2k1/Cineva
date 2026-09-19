import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import 'cineva_network_image.dart';
import 'cineva_toast.dart';

/// Facebook-style comment thread for a film.
class FilmCommentsSection extends StatefulWidget {
  const FilmCommentsSection({super.key, required this.slug});

  final String slug;

  @override
  State<FilmCommentsSection> createState() => _FilmCommentsSectionState();
}

class _FilmCommentsSectionState extends State<FilmCommentsSection> {
  final _rootCtrl = TextEditingController();
  final _replyCtrl = TextEditingController();
  final _replyFocus = FocusNode();

  List<Map<String, dynamic>> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _posting = false;
  String? _error;

  /// Actual parentId sent to API.
  String? _replyToId;

  /// Root comment id — where the inline composer is placed.
  String? _replyRootId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _rootCtrl.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await context.read<ApiClient>().listFilmComments(widget.slug);
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total;
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

  void _startReply(Map<String, dynamic> c, {required String rootId}) {
    setState(() {
      _replyToId = c['id']?.toString();
      _replyRootId = rootId;
      _replyToName = _displayName(c);
      _replyCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _replyFocus.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyRootId = null;
      _replyToName = null;
      _replyCtrl.clear();
    });
  }

  Future<void> _submitRoot() => _submit(
        body: _rootCtrl.text,
        parentId: null,
        clear: () => _rootCtrl.clear(),
      );

  Future<void> _submitReply() => _submit(
        body: _replyCtrl.text,
        parentId: _replyToId,
        clear: _cancelReply,
      );

  Future<void> _submit({
    required String body,
    required String? parentId,
    required VoidCallback clear,
  }) async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }
    final text = body.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await context.read<ApiClient>().addFilmComment(
            widget.slug,
            body: text,
            parentId: parentId,
          );
      if (!mounted) return;
      clear();
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final loggedIn = auth.isLoggedIn;
    final me = auth.user;
    final meName = me?.fullName?.isNotEmpty == true
        ? me!.fullName!
        : me?.username ?? '';
    final replying = _replyRootId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Bình luận',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (!_loading && _total > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$_total',
                style: const TextStyle(
                  color: CinevaColors.mutedSoft,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // Top composer only for new root comments (not while replying)
        if (!loggedIn)
          _GuestComposer(onLogin: () => context.push('/login'))
        else if (!replying)
          _ComposerRow(
            avatarUrl: me?.avatar,
            displayName: meName,
            controller: _rootCtrl,
            posting: _posting,
            hint: 'Viết bình luận…',
            onSubmit: _submitRoot,
          ),

        const SizedBox(height: 18),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          Column(
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
              TextButton(onPressed: _reload, child: const Text('Thử lại')),
            ],
          )
        else if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Chưa có bình luận. Hãy là người đầu tiên.',
              style: TextStyle(color: CinevaColors.mutedSoft, fontSize: 13),
            ),
          )
        else
          ..._items.map((c) {
            final rootId = c['id']?.toString() ?? '';
            final replies = _repliesOf(c);
            final showInlineReply =
                loggedIn && replying && _replyRootId == rootId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FbComment(
                    comment: c,
                    onReply: loggedIn
                        ? () => _startReply(c, rootId: rootId)
                        : null,
                  ),
                  if (replies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 44, top: 10),
                      child: Column(
                        children: [
                          for (var i = 0; i < replies.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == replies.length - 1 ? 0 : 10,
                              ),
                              child: _FbComment(
                                comment: replies[i],
                                compact: true,
                                onReply: loggedIn
                                    ? () => _startReply(
                                          replies[i],
                                          rootId: rootId,
                                        )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Inline reply composer — under this thread (FB style)
                  if (showInlineReply)
                    Padding(
                      padding: const EdgeInsets.only(left: 44, top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 36, bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        color: CinevaColors.mutedSoft,
                                        fontSize: 12,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Đang trả lời '),
                                        TextSpan(
                                          text: _replyToName ?? '',
                                          style: const TextStyle(
                                            color: CinevaColors.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _cancelReply,
                                  child: const Text(
                                    'Hủy',
                                    style: TextStyle(
                                      color: CinevaColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ComposerRow(
                            avatarUrl: me?.avatar,
                            displayName: meName,
                            controller: _replyCtrl,
                            focusNode: _replyFocus,
                            posting: _posting,
                            hint: 'Viết trả lời…',
                            avatarSize: 28,
                            onSubmit: _submitReply,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

List<Map<String, dynamic>> _repliesOf(Map<String, dynamic> c) {
  final raw = c['replies'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

String _displayName(Map<String, dynamic> c) {
  final full = c['fullName']?.toString();
  if (full != null && full.isNotEmpty) return full;
  return c['username']?.toString() ?? 'user';
}

class _GuestComposer extends StatelessWidget {
  const _GuestComposer({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLogin,
      child: Row(
        children: [
          const _Avatar(name: '?', size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3B3C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Đăng nhập để viết bình luận…',
                style: TextStyle(
                  color: CinevaColors.mutedSoft,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerRow extends StatelessWidget {
  const _ComposerRow({
    required this.avatarUrl,
    required this.displayName,
    required this.controller,
    required this.posting,
    required this.hint,
    required this.onSubmit,
    this.focusNode,
    this.avatarSize = 36,
  });

  final String? avatarUrl;
  final String displayName;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool posting;
  final String hint;
  final VoidCallback onSubmit;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Avatar(name: displayName, url: avatarUrl, size: avatarSize),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3B3C),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        color: CinevaColors.mutedSoft,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                      counterText: '',
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 2, bottom: 0),
                  child: IconButton(
                    onPressed: posting ? null : onSubmit,
                    visualDensity: VisualDensity.compact,
                    icon: posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: CinevaColors.accent.withValues(alpha: 0.95),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FbComment extends StatelessWidget {
  const _FbComment({
    required this.comment,
    this.onReply,
    this.compact = false,
  });

  final Map<String, dynamic> comment;
  final VoidCallback? onReply;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(comment);
    final body = comment['body']?.toString() ?? '';
    final created = comment['createdAt']?.toString();
    final avatar = comment['avatar']?.toString();
    final avatarSize = compact ? 28.0 : 36.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(name: name, url: avatar, size: avatarSize),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 10 : 12,
                  compact ? 6 : 8,
                  compact ? 10 : 12,
                  compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3B3C),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12.5 : 13.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: compact ? 13.5 : 14.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    if (created != null)
                      Text(
                        _shortDate(created),
                        style: const TextStyle(
                          color: CinevaColors.mutedSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (onReply != null)
                      GestureDetector(
                        onTap: onReply,
                        child: const Text(
                          'Trả lời',
                          style: TextStyle(
                            color: CinevaColors.mutedSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url, this.size = 36});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasUrl
            ? CinevaNetworkImage(url: url, fit: BoxFit.cover)
            : ColoredBox(
                color: _avatarColor(name),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.38,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

Color _avatarColor(String seed) {
  const palette = [
    Color(0xFF1877F2),
    Color(0xFFE4405F),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];
  if (seed.isEmpty) return palette[0];
  return palette[seed.codeUnitAt(0) % palette.length];
}

String _shortDate(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
  if (diff.inHours < 24) return '${diff.inHours} giờ';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} tuần';
  return '${local.day}/${local.month}';
}
