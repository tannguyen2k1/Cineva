import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/cineva_theme.dart';

/// Cineva brand mark widget (hỗ trợ cả bản vàng nguyên bản và bản 18+ neon).
class CinevaBrandMark extends StatelessWidget {
  const CinevaBrandMark({
    super.key,
    this.size = 30,
    this.is18Plus = false,
  });

  final double size;
  final bool is18Plus;

  @override
  Widget build(BuildContext context) {
    if (is18Plus) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF1475).withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SvgPicture.asset(
          'assets/brand/cineva-18-mark.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }

    return SvgPicture.asset(
      'assets/brand/cineva-mark.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE08A), CinevaColors.accentDeep],
          ),
        ),
      ),
    );
  }
}
