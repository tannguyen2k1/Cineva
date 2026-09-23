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
  List<Map<String, dynamic>>? _traffic;
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
      final rawTraffic = data['traffic'];
      if (!mounted) return;
      setState(() {
        _stats = stats is Map ? Map<String, dynamic>.from(stats) : null;
        _lastSync = sync is Map ? Map<String, dynamic>.from(sync) : null;
        _traffic = rawTraffic is List
            ? rawTraffic
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : null;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng quan',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  InkWell(
                    onTap: () => context.push('/admin/modules'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CinevaColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.dashboard_customize_outlined,
                            size: 15,
                            color: CinevaColors.accent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Quản lý',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: CinevaColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
              if (_traffic != null && _traffic!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _TrafficCard(traffic: _traffic!),
              ],
              if (_lastSync != null) ...[
                const SizedBox(height: 14),
                _SyncBanner(sync: _lastSync!),
              ],
            ],
          ],
        ),
      ),
    );
  }
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

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.traffic});

  final List<Map<String, dynamic>> traffic;

  @override
  Widget build(BuildContext context) {
    int totalViews = 0;
    int totalVisitors = 0;
    int totalLogins = 0;
    int maxVal = 1;

    for (final day in traffic) {
      final views = (day['pageViews'] as num?)?.toInt() ?? 0;
      final visitors = (day['uniqueVisitors'] as num?)?.toInt() ?? 0;
      final logins = (day['logins'] as num?)?.toInt() ?? 0;
      totalViews += views;
      totalVisitors += visitors;
      totalLogins += logins;
      if (views > maxVal) maxVal = views;
      if (visitors > maxVal) maxVal = visitors;
      if (logins > maxVal) maxVal = logins;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: Color(0xFF5B8CFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Lưu lượng truy cập',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Spacer(),
              Text(
                '7 ngày qua',
                style: TextStyle(color: CinevaColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TrafficStatItem(
                  label: 'Lượt xem',
                  value: '$totalViews',
                  color: const Color(0xFF5B8CFF),
                ),
              ),
              Expanded(
                child: _TrafficStatItem(
                  label: 'Khách duy nhất',
                  value: '$totalVisitors',
                  color: const Color(0xFF3DDC97),
                ),
              ),
              Expanded(
                child: _TrafficStatItem(
                  label: 'Đăng nhập',
                  value: '$totalLogins',
                  color: const Color(0xFFF5A524),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 115,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: traffic.map((d) {
                final dateStr = d['date']?.toString() ?? '';
                final parts = dateStr.split('-');
                final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : dateStr;
                final views = (d['pageViews'] as num?)?.toDouble() ?? 0;
                final visitors = (d['uniqueVisitors'] as num?)?.toDouble() ?? 0;
                final logins = (d['logins'] as num?)?.toDouble() ?? 0;

                final vH = maxVal > 0 ? (views / maxVal * 74).clamp(4.0, 74.0) : 4.0;
                final uH = maxVal > 0 ? (visitors / maxVal * 74).clamp(4.0, 74.0) : 4.0;
                final lH = maxVal > 0 ? (logins / maxVal * 74).clamp(4.0, 74.0) : 4.0;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 6,
                            height: vH,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5B8CFF),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 2.5),
                          Container(
                            width: 6,
                            height: uH,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3DDC97),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 2.5),
                          Container(
                            width: 6,
                            height: lH,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5A524),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: CinevaColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Color(0xFF5B8CFF), label: 'Xem'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFF3DDC97), label: 'Khách'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFFF5A524), label: 'Đăng nhập'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrafficStatItem extends StatelessWidget {
  const _TrafficStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: CinevaColors.muted, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: CinevaColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

