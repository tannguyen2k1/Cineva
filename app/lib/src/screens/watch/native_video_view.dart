import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../theme/cineva_theme.dart';

Widget hidePlayerSpinner(BuildContext _) => const SizedBox.shrink();

class NativeVideoView extends StatelessWidget {
  const NativeVideoView({
    super.key,
    required this.controller,
    required this.bottomPadding,
    required this.hideBuffering,
  });

  final VideoController controller;
  final double bottomPadding;
  final bool hideBuffering;

  @override
  Widget build(BuildContext context) {
    final theme = MaterialVideoControlsThemeData(
      seekBarPositionColor: CinevaColors.accent,
      seekBarThumbColor: CinevaColors.accent,
      bufferingIndicatorBuilder: hideBuffering ? hidePlayerSpinner : null,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: MaterialVideoControlsTheme(
        normal: theme,
        fullscreen: theme,
        child: Video(
          controller: controller,
          fill: Colors.black,
          fit: BoxFit.contain,
          controls: MaterialVideoControls,
        ),
      ),
    );
  }
}
