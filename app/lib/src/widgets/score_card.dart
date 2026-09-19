import 'package:flutter/material.dart';

import '../theme/cineva_theme.dart';

class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.score, required this.count});

  final double score;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (score <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF27272A)),
          color: const Color(0xFF141416),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '★',
              style: TextStyle(
                color: CinevaColors.muted,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Chưa có đánh giá',
              style: TextStyle(
                color: Color(0xFFD4D4D8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CinevaColors.accent.withValues(alpha: 0.28),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CinevaColors.accent.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.04),
          ],
          stops: const [0, 0.55],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: CinevaColors.accent.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Text(
                    '★',
                    style: TextStyle(
                      color: CinevaColors.accent,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Color(0x59FFD66B),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: CinevaColors.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: '/10',
                          style: TextStyle(
                            color: CinevaColors.accent.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              color: CinevaColors.accent.withValues(alpha: 0.2),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 0 ? _formatCount(count) : '—',
                    style: const TextStyle(
                      color: Color(0xFFF4F4F5),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const Text(
                    'lượt đánh giá',
                    style: TextStyle(
                      color: CinevaColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
