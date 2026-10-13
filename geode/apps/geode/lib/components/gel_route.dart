import 'package:flutter/material.dart';
import '../three_d/bevel_border.dart';

Future<T?> showGelRoute<T>(BuildContext context, Widget page, {String? name}) {
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    settings: RouteSettings(name: name), opaque: false,
    transitionDuration: reducedMotion ? Duration.zero : const Duration(milliseconds: 420),
    reverseTransitionDuration: reducedMotion ? Duration.zero : const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      Swing3DTransition(animation: animation, secondary: secondaryAnimation, child: child),
  ));
}
