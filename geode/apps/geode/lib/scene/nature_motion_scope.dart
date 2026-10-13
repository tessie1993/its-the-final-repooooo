import 'package:flutter/widgets.dart';
import 'geode_scene_controller.dart';

/// Supplies a shared paint clock without rebuilding the controls each frame.
class NatureMotionScope extends InheritedWidget {
  const NatureMotionScope({super.key, required this.controller, required super.child});
  final GeodeSceneController controller;
  static GeodeSceneController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NatureMotionScope>()?.controller;
  @override
  bool updateShouldNotify(NatureMotionScope oldWidget) => oldWidget.controller != controller;
}
