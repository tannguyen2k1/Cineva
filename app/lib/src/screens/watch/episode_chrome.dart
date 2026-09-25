import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/cineva_theme.dart';

String episodeLabel(EpisodeItem ep) {
  final raw = ep.name.trim();
  if (raw.isEmpty) return 'tập tiếp';
  if (RegExp(r'^\d+$').hasMatch(raw)) return 'Tập $raw';
  return raw;
}

class NextEpisodeBar extends StatelessWidget {
  const NextEpisodeBar({
    super.key,
    required this.label,
    required this.prominent,
    required this.onTap,
    this.countdownSec = 0,
  });

  final String label;
  final bool prominent;
  final VoidCallback onTap;
  final int countdownSec;

  @override
  Widget build(BuildContext context) {
    final countdown = prominent && countdownSec > 0 ? ' (${countdownSec}s)' : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: prominent
                ? CinevaColors.accent
                : Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            border: prominent
                ? null
                : Border.all(
                    color: CinevaColors.accent.withValues(alpha: 0.55),
                  ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: prominent ? 18 : 14,
            vertical: prominent ? 14 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.skip_next_rounded,
                color: prominent ? CinevaColors.onAccent : CinevaColors.accent,
                size: prominent ? 26 : 22,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  prominent
                      ? 'Tập tiếp theo · $label$countdown'
                      : 'Tập tiếp · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: prominent ? CinevaColors.onAccent : CinevaColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: prominent ? 15 : 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EndedEpisodeOverlay extends StatelessWidget {
  const EndedEpisodeOverlay({
    super.key,
    required this.countdownSec,
    required this.label,
    required this.onPlayNext,
    required this.onCancel,
  });

  final int countdownSec;
  final String label;
  final VoidCallback onPlayNext;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hết tập',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                countdownSec > 0
                    ? 'Tự phát tập tiếp sau $countdownSec giây'
                    : 'Sẵn sàng xem tập tiếp theo',
                textAlign: TextAlign.center,
                style: const TextStyle(color: CinevaColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              NextEpisodeBar(
                label: label,
                prominent: true,
                countdownSec: countdownSec,
                onTap: onPlayNext,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: CinevaColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
