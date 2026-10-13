import 'package:flutter/material.dart';
import 'components/components.dart';
import 'scene/scene_surface.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/visualizer_screen.dart';
import 'state/geode_app_state.dart';
import 'theme/geode_theme.dart';

class GeodeApp extends StatelessWidget {
  const GeodeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Geode — Nature in motion', debugShowCheckedModeBanner: false,
    theme: GeodeTokens.theme, home: const GeodeShell(),
  );
}

class GeodeShell extends StatefulWidget {
  const GeodeShell({super.key});
  @override
  State<GeodeShell> createState() => _GeodeShellState();
}

class _GeodeShellState extends State<GeodeShell> {
  final _state = GeodeAppState();
  final _pointers = <int>{};

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _state,
    builder: (context, _) => PopScope(
      canPop: _state.destination == 0 && !_state.immersive,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _state.navigate(0); },
      child: Scaffold(body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        Offset normalize(Offset point) => Offset(
          (point.dx / constraints.maxWidth).clamp(0.0, 1.0).toDouble(),
          (point.dy / constraints.maxHeight).clamp(0.0, 1.0).toDouble(),
        );
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _pointers.add(event.pointer);
            _state.scene.touch(normalize(event.localPosition));
          },
          onPointerMove: (event) => _state.scene.interact(normalize(event.localPosition)),
          onPointerUp: (event) {
            _pointers.remove(event.pointer);
            if (_pointers.isEmpty) _state.scene.release();
          },
          onPointerCancel: (event) {
            _pointers.remove(event.pointer);
            if (_pointers.isEmpty) _state.scene.release();
          },
          child: Stack(fit: StackFit.expand, children: [
            SceneSurface(controller: _state.scene, interactive: false,
              orbAlignment: _state.immersive ? Alignment.center
                : (wide ? const Alignment(-.40, -.08) : const Alignment(0, -.15)),
              orbScale: wide ? .8 : .96),
            IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: .34), Colors.transparent,
                  const Color(0xFF031F25).withValues(alpha: .80)],
                stops: const [0, .4, 1]),
            ))),
            if (_state.destination != 0)
              const IgnorePointer(child: ColoredBox(color: Color(0x80102428))),
            MediaQuery(data: MediaQuery.of(context).copyWith(
              disableAnimations: MediaQuery.disableAnimationsOf(context) || _state.scene.reducedMotion),
              child: SafeArea(child: _state.immersive
              ? Align(alignment: Alignment.topRight, child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GelIconButton(icon: Icons.close_rounded, tooltip: 'Exit immersive view',
                    onPressed: () => _state.setImmersive(false))))
              : Column(children: [
                  _header(wide),
                  Expanded(child: switch (_state.destination) {
                    1 => LibraryScreen(state: _state),
                    2 => StudioScreen(state: _state),
                    3 => SettingsScreen(state: _state),
                    _ => VisualizerScreen(state: _state),
                  }),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 510),
                      child: GelFloat(controller: _state.scene,
                        anchor: const Offset(.5, .92), weight: 2.4,
                        child: GelNavDock(selectedIndex: _state.destination,
                          onChanged: _state.navigate)))),
                ]))),
          ]),
        );
      })),
    ),
  );

  Widget _header(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 40 : 24, 14, wide ? 40 : 24, 8),
    child: Row(children: [
      Image.asset('assets/images/fern-dew.png', width: 42, height: 42, excludeFromSemantics: true),
      const SizedBox(width: 9),
      const Text('geode', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: -1.4)),
      const Spacer(),
      if (wide) const Padding(padding: EdgeInsets.only(right: 20),
        child: Text('N A T U R E   I N   M O T I O N', style: TextStyle(fontSize: 10, color: GeodeTokens.muted))),
      GelIconButton(icon: Icons.fullscreen_rounded, tooltip: 'Immersive view',
        onPressed: () { _state.navigate(0); _state.setImmersive(true); }),
    ]),
  );

  @override
  void dispose() { _state.dispose(); super.dispose(); }
}
