import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/topxx_models.dart';
import '../services/topxx_client.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';

class AdultFilmDetailScreen extends StatefulWidget {
  const AdultFilmDetailScreen({
    super.key,
    required this.code,
    this.initialMovie,
  });

  final String code;
  final TopxxMovie? initialMovie;

  @override
  State<AdultFilmDetailScreen> createState() => _AdultFilmDetailScreenState();
}

class _AdultFilmDetailScreenState extends State<AdultFilmDetailScreen> {
  late Future<TopxxMovie?> _future;
  TopxxMovie? _movie;

  @override
  void initState() {
    super.initState();
    _movie = widget.initialMovie;
    _future = context.read<TopxxClient>().getDetail(widget.code);
  }

  void _watchMovie(TopxxMovie movie) {
    final embed = movie.embedLink;
    if (embed != null && embed.isNotEmpty) {
      context.push(
        '/xem/${movie.code}',
        extra: {
          'title': movie.title,
          'playUrl': embed,
          'embedUrl': embed,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lấy được nguồn phát video'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      body: FutureBuilder<TopxxMovie?>(
        future: _future,
        builder: (context, snapshot) {
          final detail = snapshot.data ?? _movie;

          if (snapshot.connectionState == ConnectionState.waiting && detail == null) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFE11D48),
              ),
            );
          }

          if (detail == null) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tìm thấy thông tin phim',
                        style: TextStyle(color: CinevaColors.muted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                        ),
                        child: const Text('Quay lại'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final imageUrl = detail.effectiveBackdrop.isNotEmpty
              ? detail.effectiveBackdrop
              : detail.effectivePoster;

          return CustomScrollView(
            slivers: [
              // Top Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: CinevaColors.bg.withValues(alpha: 0.95),
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  detail.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),

              // Content Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hero Widescreen Backdrop with Play Button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () => _watchMovie(detail),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CinevaNetworkImage(
                                  url: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Dark gradient overlay
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.7),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Center Play Icon Button
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE11D48),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE11D48)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              // Top Quality Badge
                              if (detail.quality != null)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      detail.quality!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF529D),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              // Bottom Duration Chip
                              if (detail.duration != null)
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.schedule_rounded,
                                          size: 11,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          detail.duration!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Movie Title
                      Text(
                        detail.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Details Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CinevaColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thông tin chi tiết',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Thời lượng', detail.duration ?? 'Đang cập nhật'),
                            const SizedBox(height: 8),
                            _buildInfoRow('Chất lượng', detail.quality ?? 'FHD 1080P'),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Thể loại',
                              detail.inferredTags.join(' · '),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Nguồn phát', 'Server XHub HD Streaming'),
                            if (detail.publishAt != null) ...[
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'Ngày đăng',
                                detail.publishAt!.split('T').first,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Description / Nội dung tóm tắt
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CinevaColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.subject_rounded,
                                  size: 16,
                                  color: Color(0xFFE11D48),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Mô tả nội dung',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              detail.effectiveDescription,
                              style: const TextStyle(
                                fontSize: 13,
                                color: CinevaColors.muted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 6. Security & Disclaimer Notice
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: CinevaColors.muted,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nội dung chỉ dành cho người từ 18 tuổi trở lên. Xem trực tiếp không lưu lịch sử trên hệ thống Cineva.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: CinevaColors.mutedSoft,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: CinevaColors.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF4F4F5),
            ),
          ),
        ),
      ],
    );
  }
}
