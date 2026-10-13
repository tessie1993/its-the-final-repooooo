import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/components.dart';
import 'components/mini_player.dart';
import 'scene/scene_host.dart';
import 'scene/gel_float.dart';
import 'screens/music/music_library_screen.dart';
import 'screens/music/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/visualizer_screen.dart';
import 'state/geode_app_state.dart';
import 'theme/geode_theme.dart';
import 'three_d/asset_3d.dart';

class GeodeApp extends StatefulWidget {
  const GeodeApp({super.key, this.enableDeviceServices = true});
  final bool enableDeviceServices;
  @override
  State<GeodeApp> createState() => _GeodeAppState();
}

class _GeodeAppState extends State<GeodeApp> with WidgetsBindingObserver {
  late final GeodeAppState state;
  bool? _immersiveMode;
  Future<void> _systemUiUpdate = Future<void>.value();
  @override
  void initState() {
    super.initState();
    state = GeodeAppState(enableDeviceServices: widget.enableDeviceServices);
    state.addListener(_syncSystemUi);
    WidgetsBinding.instance.addObserver(this);
    _syncSystemUi();
    unawaited(state.initialize());
  }

  void _syncSystemUi({bool force = false}) {
    if (!widget.enableDeviceServices || !mounted) return;
    if (!force && _immersiveMode == state.immersive) return;
    _immersiveMode = state.immersive;
    final mode = state.immersive
        ? SystemUiMode.immersiveSticky
        : SystemUiMode.edgeToEdge;
    _systemUiUpdate = _systemUiUpdate.then((_) async {
      try {
        await SystemChrome.setEnabledSystemUIMode(mode);
      } on PlatformException {
        // Some hosts own their system bars. The in-app exit remains usable.
      }
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      _syncSystemUi(force: true);
    } else {
      unawaited(state.flush());
    }
  }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Geode — Nature in motion', debugShowCheckedModeBanner: false,
    theme: GeodeTokens.theme,
    builder: (context, navigator) => SceneHost(state: state,
      child: navigator ?? const SizedBox.shrink()),
    home: GeodeShell(state: state),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.removeListener(_syncSystemUi);
    state.dispose();
    super.dispose();
  }
}

class GeodeShell extends StatelessWidget {
  const GeodeShell({super.key, required this.state});
  final GeodeAppState state;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => PopScope(
      canPop: state.destination == 0 && !state.immersive,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) state.navigate(0); },
      child: Scaffold(backgroundColor: Colors.transparent,
        body: SafeArea(child: state.immersive
          ? Align(alignment: Alignment.topRight, child: Padding(
              padding: const EdgeInsets.all(24),
              child: GelIconButton(icon: Icons.close_rounded,
                tooltip: 'Exit immersive view', onPressed: () => state.setImmersive(false))))
          : Column(children: [
              _header(context),
              Expanded(child: !state.initialized
                ? const Center(child: CircularProgressIndicator())
                : AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero : const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(key: ValueKey(state.destination),
                      child: switch (state.destination) {
                        1 => MusicLibraryScreen(state: state),
                        2 => StudioScreen(state: state),
                        3 => SettingsScreen(state: state),
                        _ => VisualizerScreen(state: state),
                      }))),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
                child: GelFloat(controller: state.scene, anchor: const Offset(.5, .82), weight: 2.8,
                  child: MiniPlayer(state: state, onOpen: () => showNowPlaying(context, state)))),
              Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 510),
                  child: GelFloat(controller: state.scene,
                    anchor: const Offset(.5, .92), weight: 2.4,
                    child: GelNavDock(selectedIndex: state.destination, onChanged: state.navigate)))),
            ]))),
    ),
  );
  Widget _header(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Padding(padding: EdgeInsets.fromLTRB(wide ? 40 : 24, 14, wide ? 40 : 24, 8),
      child: Row(children: [
        Asset3D.boxed(asset: Geode3DAsset.fernDew, spin: true, width: 42, height: 42, fallback: Image.asset('assets/images/fern-dew.png', width: 42, height: 42, excludeFromSemantics: true)),
        const SizedBox(width: 9),
        const Text('geode', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: -1.4)),
        const Spacer(),
        if (wide) const Padding(padding: EdgeInsets.only(right: 20),
          child: Text('N A T U R E   I N   M O T I O N', style: TextStyle(fontSize: 10, color: GeodeTokens.muted))),
        GelIconButton(icon: Icons.fullscreen_rounded, tooltip: 'Immersive view',
          onPressed: () { state.navigate(0); state.setImmersive(true); }),
      ]));
  }
}
