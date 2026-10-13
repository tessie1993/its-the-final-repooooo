import 'package:flutter/material.dart';

Future<T?> showGelRoute<T>(BuildContext context, Widget page, {String? name}) {
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    settings: RouteSettings(name: name), opaque: false,
    transitionDuration: reducedMotion ? Duration.zero : const Duration(milliseconds: 420),
    reverseTransitionDuration: reducedMotion ? Duration.zero : const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(opacity: eased, child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(eased),
        child: ScaleTransition(scale: Tween<double>(begin: .975, end: 1).animate(eased), child: child)));
    },
  ));
}
