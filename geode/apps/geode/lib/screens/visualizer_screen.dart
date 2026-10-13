import 'package:flutter/material.dart';
import '../components/components.dart';
import '../scene/gel_float.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';
import 'library_screen.dart';
import 'visuals/visual_customizer_screen.dart';
import 'visuals/native_visual_customizer.dart';
import 'visuals/native_scene_catalog.dart';
import 'visuals/visual_source_sheet.dart';
import 'visuals/visual_widgets.dart';

class VisualizerScreen extends StatelessWidget {
  const VisualizerScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final wide = bounds.maxWidth >= 900;
    final intro = VisualFloat(state: state, anchor: const Offset(.25, .2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const VisualEyebrow('A little closer to nature'),
        const SizedBox(height: 14),
        Text('Find your\nflow.', style: TextStyle(fontFamily: 'Georgia',
          fontSize: wide ? 82 : 58, height: .97, letterSpacing: -2.7, color: GeodeTokens.ink)),
        const SizedBox(height: 17),
        const Text('A living landscape. Shaped by you.',
          style: TextStyle(color: Color(0xFFE2EAE3), fontSize: 13)),
      ]));
    final center = _sceneSpace(wide ? 285 : (bounds.maxHeight * .24).clamp(150.0, 260.0).toDouble());
    final controls = _controls(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 52 : 24, 20, wide ? 52 : 24, 20),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200),
        child: wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, center, _sceneCaption(), const SizedBox(height: 26), _quickActions(context)])),
          const SizedBox(width: 58),
          SizedBox(width: 350, child: Column(children: [
            const SizedBox(height: 36), controls,
            const SizedBox(height: 24), _natureNote(context),
          ])),
        ]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          intro, center, _sceneCaption(), const SizedBox(height: 20), _quickActions(context),
          const SizedBox(height: 18), controls,
        ]),
      )),
    );
  });

  Widget _sceneSpace(double height) => SizedBox(height: height,
    child: Stack(clipBehavior: Clip.none, children: [
      if (state.natureDetails && !state.nativeVisuals.enabled) ...[
        Positioned(right: -15, top: 0, child: GelFloat(controller: state.scene,
          anchor: const Offset(.83, .34), weight: .65, phase: 1.2,
          child: Image.asset('assets/images/crystal-fern.png', width: 130, height: 130,
            semanticLabel: 'Fern suspended in translucent crystal'))),
        Positioned(left: 2, top: 23, child: GelFloat(controller: state.scene,
          anchor: const Offset(.21, .36), weight: .6, phase: 3.6,
          child: Image.asset('assets/images/fern-dew.png', width: 42, height: 42, excludeFromSemantics: true))),
      ],
      Positioned(left: 0, bottom: 17, child: GelFloat(controller: state.scene,
        anchor: const Offset(.18, .50), weight: .8, phase: 2.6,
        child: GelPanel(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          radius: 22, opacity: .35, blur: 8,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.touch_app_outlined, size: 15, color: GeodeTokens.accent),
            const SizedBox(width: 7),
            Text(state.scene.motionDisabled ? 'Still water' : 'Touch to make waves', style: const TextStyle(fontSize: 10)),
          ])))),
    ]));

  Widget _sceneCaption() => Wrap(spacing: 20, runSpacing: 8,
    alignment: WrapAlignment.spaceBetween, children: [
      Text(state.scene.paused ? 'SCENE PAUSED' : 'LIVING LANDSCAPE',
        style: const TextStyle(fontSize: 9, letterSpacing: 1.9, color: GeodeTokens.accent)),
      Text(state.nativeVisuals.enabled ? _visualName : '${state.selectedLook.name} · Nature in motion',
        style: const TextStyle(fontSize: 10, color: GeodeTokens.muted)),
    ]);

  Widget _quickActions(BuildContext context) => VisualFloat(state: state,
    anchor: const Offset(.5, .65), phase: 1.4,
    child: GelPanel(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), radius: 25,
      opacity: .64, child: Row(children: [
        Expanded(child: _action(context, Icons.grid_view_rounded, 'Presets',
          () => openVisualPage(context, PresetLibraryScreen(state: state)))),
        Container(width: 1, height: 30, color: GeodeTokens.ice.withValues(alpha: .14)),
        Expanded(child: _action(context, Icons.tune_rounded, 'Customize',
          () => openVisualPage(context, state.nativeVisuals.enabled
            ? NativeVisualCustomizer(state: state) : VisualCustomizerScreen(state: state)))),
        Container(width: 1, height: 30, color: GeodeTokens.ice.withValues(alpha: .14)),
        Expanded(child: _action(context, Icons.graphic_eq_rounded, 'Source',
          () => showVisualSourceSheet(context, state))),
      ])));

  Widget _action(BuildContext context, IconData icon, String title, VoidCallback onPressed) =>
    TextButton(onPressed: onPressed, style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 21),
        const SizedBox(height: 7), Text(title, style: Theme.of(context).textTheme.labelMedium)]));

  Widget _controls(BuildContext context) => GelFloat(controller: state.scene,
    anchor: const Offset(.5, .76), weight: 1.8,
    child: GelPanel(padding: const EdgeInsets.all(20), opacity: .68,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.isEdited ? 'YOUR EVOLVING LOOK' : 'CURRENT LOOK',
              style: const TextStyle(fontSize: 9, letterSpacing: 1.8, color: GeodeTokens.accent)),
            const SizedBox(height: 7),
            Text(_visualName, style: const TextStyle(fontSize: 22, letterSpacing: -.4)),
            const SizedBox(height: 5),
            Text(state.nativeVisuals.enabled ? 'A world shaped by your sound' : 'Moss, stone & a little wonder',
              style: const TextStyle(fontSize: 11, color: GeodeTokens.muted)),
          ])),
          GelIconButton(icon: state.isEdited ? Icons.bookmark_add_outlined : state.favorites.contains(state.selectedLookId)
              ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            tooltip: state.isEdited ? 'Save this look' : state.favorites.contains(state.selectedLookId) ? 'Remove from favorites' : 'Add to favorites',
            selected: !state.isEdited && state.favorites.contains(state.selectedLookId),
            onPressed: () { if (state.isEdited) { saveCurrentLook(context, state); }
              else { state.toggleFavorite(state.selectedLookId); } }),
        ]),
        const SizedBox(height: 22),
        if (state.nativeVisuals.enabled) Row(children: [
          Expanded(child: GelButton(label: 'Previous', primary: false, icon: Icons.skip_previous_rounded,
            onPressed: () => _stepVisual(-1))),
          const SizedBox(width: 8),
          Expanded(child: GelButton(label: 'Next', primary: false, icon: Icons.skip_next_rounded,
            onPressed: () => _stepVisual(1))),
        ]) else GelMaterialPicker(selectedIndex: state.scene.materialIndex, onChanged: state.setMaterial),
        const SizedBox(height: 18),
        GelSlider(label: 'Flow intensity', value: state.scene.energy, onChanged: state.setEnergy),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: GelButton(label: state.scene.paused ? 'Let it flow' : 'Pause scene',
            icon: state.scene.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onPressed: state.togglePlayback)),
          const SizedBox(width: 10),
          GelIconButton(icon: Icons.fullscreen_rounded, tooltip: 'Enter immersive mode',
            onPressed: () => state.setImmersive(true)),
        ]),
      ])));

  String get _visualName {
    if (!state.nativeVisuals.enabled) return state.selectedLook.name;
    final preset = state.nativeVisuals.milkPreset;
    if (state.nativeVisuals.sceneId == 'milkdrop' && preset != null) {
      return preset.split('/').last.replaceFirst(RegExp(r'\.milk$'), '');
    }
    for (final entry in nativeSceneCatalog) {
      if (entry.id == state.nativeVisuals.sceneId) return entry.name;
    }
    return state.nativeVisuals.sceneId.replaceAll('_', ' ');
  }

  void _stepVisual(int direction) {
    final native = state.nativeVisuals;
    if (native.loading) return;
    if (native.sceneId == 'milkdrop' && native.presets.isNotEmpty) {
      final current = native.presets.indexOf(native.milkPreset ?? '');
      native.selectMilkPreset(native.presets[(current + direction) % native.presets.length]);
    } else if (native.scenes.isNotEmpty) {
      final current = native.scenes.indexOf(native.sceneId);
      native.selectScene(native.scenes[(current + direction) % native.scenes.length]);
    }
  }

  Widget _natureNote(BuildContext context) => GelFloat(controller: state.scene,
    anchor: const Offset(.78, .7), weight: .7, phase: 2,
    child: Column(children: [
      NaturePebble(label: 'Explore your little worlds',
        onPressed: () => openVisualPage(context, PresetLibraryScreen(state: state)), width: 310, height: 110),
      const Text('One touch. A thousand little ripples.', style: TextStyle(fontSize: 11, color: GeodeTokens.muted)),
    ]));
}
