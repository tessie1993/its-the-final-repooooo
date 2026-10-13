import 'package:flutter/widgets.dart';

import '../state/geode_app_state.dart';

/// Which 3D path a UI surface should take right now.
enum ThreeDMode {
  /// No GPU 3D: widget tests, hosts without device services, or 3D failed to start.
  flat,

  /// 3D geometry is drawn but holds still (reduced motion or paused scene).
  still,

  /// 3D geometry is drawn and animates.
  live,
}

/// The single rule every 3D surface follows, so the dock, library, player and visuals agree
/// on when GPU work is allowed. Surfaces still fall back to [ThreeDMode.flat] on their own
/// when their renderer fails to initialise.
ThreeDMode threeDModeOf(BuildContext context, GeodeAppState state) {
  if (!state.enableDeviceServices || !state.natureDetails) return ThreeDMode.flat;
  if (MediaQuery.disableAnimationsOf(context) || state.scene.motionDisabled) {
    return ThreeDMode.still;
  }
  return ThreeDMode.live;
}

/// Device pixel ratio for offscreen 3D targets: full on high quality, capped otherwise so
/// small UI views never render more pixels than the screen can show.
double threeDPixelRatio(BuildContext context, GeodeAppState state) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return state.scene.highQuality ? ratio : ratio.clamp(1.0, 2.0).toDouble();
}
