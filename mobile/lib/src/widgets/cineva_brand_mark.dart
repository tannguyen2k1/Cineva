import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/cineva_theme.dart';

/// Gold rounded mark from web (`cineva-mark.svg`) — no white square.
class CinevaBrandMark extends StatelessWidget {
  const CinevaBrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
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
