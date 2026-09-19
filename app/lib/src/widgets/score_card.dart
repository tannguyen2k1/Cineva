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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF27272A)),
          color: const Color(0xFF141416),
        ),
        child: const Row(
          children: [
            Text(
              '★',
              style: TextStyle(color: CinevaColors.muted, fontSize: 13),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Chưa có đánh giá',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFD4D4D8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final countLabel = count > 0 ? _formatCount(count) : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CinevaColors.accent.withValues(alpha: 0.28),
        ),
        color: CinevaColors.accent.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          const Text(
            '★',
            style: TextStyle(color: CinevaColors.accent, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              color: CinevaColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            '/10',
            style: TextStyle(
              color: CinevaColors.accent.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$countLabel lượt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: CinevaColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
