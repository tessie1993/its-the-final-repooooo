import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../ui/ui_kit.dart';
import 'app_state.dart';
import 'router.dart';

/// The app: app state, the router built from the app map, and the UI kit that draws it.
class GeodeApp extends StatefulWidget {
  const GeodeApp({super.key, required this.ui, this.state});

  /// The skin. Swap this to change how every screen looks.
  final GeodeUiKit ui;

  /// Injected by tests; created here otherwise.
  final AppState? state;

  @override
  State<GeodeApp> createState() => _GeodeAppState();
}

class _GeodeAppState extends State<GeodeApp> {
  late final AppState _state = widget.state ?? AppState();
  late final GoRouter _router = buildRouter(state: _state, ui: widget.ui);

  @override
  void dispose() {
    _router.dispose();
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp.router(
        title: 'Geode',
        debugShowCheckedModeBanner: false,
        theme: widget.ui.theme(),
        routerConfig: _router,
      ),
    );
  }
}
