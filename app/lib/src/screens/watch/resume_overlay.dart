import 'package:flutter/material.dart';

import '../../theme/cineva_theme.dart';
import '../../widgets/cineva_network_image.dart';
import 'hls_source.dart';

class ResumeBackdrop extends StatelessWidget {
  const ResumeBackdrop({super.key, required this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CinevaNetworkImage(
          url: posterUrl,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x66000000),
                Color(0xFF000000),
              ],
              stops: [0, 0.38, 0.68],
            ),
          ),
        ),
      ],
    );
  }
}

class ResumeOverlay extends StatelessWidget {
  const ResumeOverlay({
    super.key,
    required this.title,
    required this.episodeName,
    required this.positionSec,
    required this.secondsLeft,
    required this.onContinue,
    required this.onRestart,
  });

  final String title;
  final String? episodeName;
  final int positionSec;
  final int secondsLeft;
  final VoidCallback onContinue;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final left = secondsLeft.clamp(0, 8);
    final episode = episodeName?.trim();
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black,
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 32,
                compact ? 64 : 88,
                compact ? 20 : 32,
                (compact ? 16 : 24) + bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResumeHeader(
                      compact: compact,
                      title: title,
                      episode: episode,
                      clock: clockLabel(positionSec),
                    ),
                    const SizedBox(height: 22),
                    _ResumeActions(
                      compact: compact,
                      onContinue: onContinue,
                      onRestart: onRestart,
                    ),
                    const SizedBox(height: 14),
                    _ResumeCountdown(
                      left: left,
                      compact: compact,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResumeHeader extends StatelessWidget {
  const _ResumeHeader({
    required this.compact,
    required this.title,
    required this.episode,
    required this.clock,
  });

  final bool compact;
  final String title;
  final String? episode;
  final String clock;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 22 : 26,
      height: compact ? 1.2 : 1.15,
      fontWeight: FontWeight.w800,
    );
    final titleText = Text(
      title,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    final episodeText = episode != null && episode!.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              episode!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CinevaColors.muted, fontSize: 14),
            ),
          )
        : null;
    final clockText = Text(
      clock,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 28 : 32,
        height: 1,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    const kicker = Text(
      'TIẾP TỤC XEM',
      style: TextStyle(
        color: CinevaColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
    const watched = Text(
      'đã xem tới',
      style: TextStyle(color: CinevaColors.muted, fontSize: 13),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kicker,
          const SizedBox(height: 8),
          titleText,
          ?episodeText,
          const SizedBox(height: 14),
          Row(
            children: [
              clockText,
              const SizedBox(width: 10),
              watched,
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              kicker,
              const SizedBox(height: 8),
              titleText,
              ?episodeText,
            ],
          ),
        ),
        const SizedBox(width: 28),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            clockText,
            const SizedBox(height: 6),
            const Text(
              'đã xem tới',
              style: TextStyle(color: CinevaColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResumeActions extends StatelessWidget {
  const _ResumeActions({
    required this.compact,
    required this.onContinue,
    required this.onRestart,
  });

  final bool compact;
  final VoidCallback onContinue;
  final VoidCallback onRestart;

  ButtonStyle _style({required Color background, required Color foreground}) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      minimumSize: const Size.fromHeight(48),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconSize: 20,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _continueButton() {
    return FilledButton.icon(
      style: _style(
        background: CinevaColors.accent,
        foreground: CinevaColors.onAccent,
      ),
      onPressed: onContinue,
      icon: const Icon(Icons.play_arrow_rounded, size: 20),
      label: const Text('Xem tiếp'),
    );
  }

  Widget _restartButton() {
    return FilledButton.icon(
      style: _style(
        background: const Color(0xFF2A2A32),
        foreground: Colors.white,
      ),
      onPressed: onRestart,
      icon: const Icon(Icons.replay_rounded, size: 20),
      label: const Text('Xem từ đầu'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          SizedBox(height: 48, width: double.infinity, child: _continueButton()),
          const SizedBox(height: 10),
          SizedBox(height: 48, width: double.infinity, child: _restartButton()),
        ],
      );
    }
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _continueButton()),
          const SizedBox(width: 12),
          Expanded(child: _restartButton()),
        ],
      ),
    );
  }
}

class _ResumeCountdown extends StatefulWidget {
  const _ResumeCountdown({
    required this.left,
    required this.compact,
  });

  final int left;
  final bool compact;

  @override
  State<_ResumeCountdown> createState() => _ResumeCountdownState();
}

class _ResumeCountdownState extends State<_ResumeCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..forward();
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.left;
    final label = Text(
      left > 0 ? 'Tự xem tiếp sau $left giây' : 'Đang mở lại…',
      style: const TextStyle(color: CinevaColors.mutedSoft, fontSize: 12),
    );
    final bar = AnimatedBuilder(
      animation: _fill,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _fill.value,
            minHeight: 2,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            color: CinevaColors.accent,
            trackGap: 0,
            stopIndicatorRadius: 0,
          ),
        );
      },
    );
    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar,
          const SizedBox(height: 8),
          label,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: 12),
        label,
      ],
    );
  }
}
