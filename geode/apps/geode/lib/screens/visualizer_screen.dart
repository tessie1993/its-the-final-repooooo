import 'package:flutter/material.dart';
import '../components/components.dart';
import '../scene/scene_surface.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';

class VisualizerScreen extends StatelessWidget {
  const VisualizerScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final wide = bounds.maxWidth >= 900;
    final intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('A LITTLE CLOSER TO NATURE',
        style: TextStyle(fontSize: 10, letterSpacing: 2.2, color: GeodeTokens.accent)),
      const SizedBox(height: 12),
      Text('Find your\nflow.', style: TextStyle(fontFamily: 'Georgia',
        fontSize: wide ? 76 : 53, height: .98, letterSpacing: -2.6, color: GeodeTokens.ink)),
      const SizedBox(height: 14),
      const Text('A living landscape. Shaped by you.',
        style: TextStyle(color: Color(0xFFE2EAE3), fontSize: 13)),
    ]);
    final center = _sceneSpace(wide ? 255 : (bounds.maxHeight * .28).clamp(160.0, 260.0).toDouble());
    final controls = _controls(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 52 : 26, 18, wide ? 52 : 26, 10),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200),
        child: wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, center, _sceneCaption()])),
          const SizedBox(width: 60),
          SizedBox(width: 340, child: Column(children: [
            const SizedBox(height: 48), controls,
            if (state.natureDetails) ...[const SizedBox(height: 18), _natureNote()],
          ])),
        ]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          intro, center, _sceneCaption(), const SizedBox(height: 16), controls,
        ]),
      )),
    );
  });

  Widget _sceneSpace(double height) => SizedBox(height: height,
    child: Stack(clipBehavior: Clip.none, children: [
      if (state.natureDetails)
        Positioned(right: 0, top: 14, child: GelFloat(controller: state.scene,
          anchor: const Offset(.83, .34), weight: .65, phase: 1.2,
          child: Tooltip(message: 'Fern suspended in a water droplet',
            child: Image.asset('assets/images/fern-dew.png', width: 72, height: 72,
              semanticLabel: 'Fern in a clear water droplet')))),
      Positioned(left: 0, bottom: 22, child: GelFloat(controller: state.scene,
        anchor: const Offset(.18, .50), weight: .8, phase: 2.6,
        child: GelPanel(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          radius: 22, opacity: .35, blur: 8,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.touch_app_outlined, size: 15, color: GeodeTokens.accent),
            const SizedBox(width: 7),
            Text(state.scene.motionDisabled ? 'Still water' : 'Touch to make waves',
              style: const TextStyle(fontSize: 10)),
          ])))),
    ]),
  );

  Widget _sceneCaption() => Wrap(spacing: 20, runSpacing: 8,
    alignment: WrapAlignment.spaceBetween, children: [
      Text(state.scene.paused ? 'SCENE PAUSED' : 'LIVING LANDSCAPE',
        style: const TextStyle(fontSize: 9, letterSpacing: 1.9, color: GeodeTokens.accent)),
      const Text('Forest sanctuary', style: TextStyle(fontSize: 10, color: GeodeTokens.muted)),
    ]);

  Widget _controls(BuildContext context) => GelFloat(controller: state.scene,
    anchor: const Offset(.5, .76), weight: 1.8,
    child: GelPanel(padding: const EdgeInsets.all(20), opacity: .66,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${state.selectedLook.name}${state.isEdited ? ' · edited' : ''}', style: const TextStyle(fontSize: 20, letterSpacing: -.4)),
            const SizedBox(height: 4),
            const Text('Water, light & a little wonder',
              style: TextStyle(fontSize: 11, color: GeodeTokens.muted)),
          ])),
          GelIconButton(icon: state.isEdited ? Icons.bookmark_add_outlined : state.favorites.contains(state.selectedLookId)
              ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            tooltip: state.isEdited ? 'Save this look in Studio' : state.favorites.contains(state.selectedLookId) ? 'Remove from favorites' : 'Add to favorites',
            selected: !state.isEdited && state.favorites.contains(state.selectedLookId),
            onPressed: () => state.isEdited ? state.navigate(2) : state.toggleFavorite(state.selectedLookId)),
        ]),
        const SizedBox(height: 18),
        GelMaterialPicker(selectedIndex: state.scene.materialIndex, onChanged: state.setMaterial),
        const SizedBox(height: 14),
        GelSlider(label: 'Flow intensity', value: state.scene.energy, onChanged: state.setEnergy),
        Row(children: [
          Expanded(child: GelButton(label: state.scene.paused ? 'Let it flow' : 'Pause scene',
            icon: state.scene.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onPressed: state.togglePlayback)),
          const SizedBox(width: 10),
          GelIconButton(icon: Icons.tune_rounded, tooltip: 'Open visual studio',
            onPressed: () => state.navigate(2)),
        ]),
      ])),
  );

  Widget _natureNote() => GelFloat(controller: state.scene,
    anchor: const Offset(.78, .7), weight: .7, phase: 2,
    child: Column(children: [
      NaturePebble(label: 'Explore your collection', onPressed: () => state.navigate(1),
        width: 290, height: 105),
      const Text('One touch. A thousand little ripples.',
        style: TextStyle(fontSize: 11, color: GeodeTokens.muted)),
    ]),
  );
}
