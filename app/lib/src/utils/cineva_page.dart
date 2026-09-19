import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

/// Cupertino page → left-edge swipe-to-back (iOS-style) on push routes.
Page<void> cinevaPage({
  required GoRouterState state,
  required Widget child,
  bool fullscreenDialog = false,
}) {
  return CupertinoPage<void>(
    key: state.pageKey,
    name: state.name ?? state.matchedLocation,
    child: child,
    fullscreenDialog: fullscreenDialog,
  );
}
