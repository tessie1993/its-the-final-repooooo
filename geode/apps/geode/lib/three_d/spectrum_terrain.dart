import 'dart:math' as math;

import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:geode_engine/geode_engine.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../components/gel_panel.dart';
import '../state/geode_app_state.dart';

/// A bounded 3D quartz terrain of actual post-DSP PCM bands. No demo signal.
class SpectrumTerrain extends StatefulWidget {
  const SpectrumTerrain({super.key, required this.state});
  final GeodeAppState state;

  @override
  State<SpectrumTerrain> createState() => _SpectrumTerrainState();
}

class _SpectrumTerrainState extends State<SpectrumTerrain> {
  final _camera = DiTreDiController(rotationX: -28, rotationY: 20,
    lightStrength: .8, ambientLightStrength: .4);
  final _bounds = vm.Aabb3.minMax(vm.Vector3(-4, 0, -1.6), vm.Vector3(4, 2.5, 1.6));

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context) || widget.state.scene.motionDisabled;
    return GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('LIVE SPECTRUM', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      SizedBox(height: 140, child: RepaintBoundary(child:
        ValueListenableBuilder<AudioFeatureFrame>(valueListenable: widget.state.music.analysis,
          builder: (context, frame, _) => Semantics(
            label: frame.rms > .005 ? 'Audio spectrum from the playing track' : 'Audio spectrum: silence',
            child: ExcludeSemantics(child: IgnorePointer(ignoring: still,
              child: DiTreDiDraggable(controller: _camera, scaleEnabled: false,
                rotationEnabled: !still,
                child: DiTreDi(controller: _camera, bounds: _bounds,
                  figures: _terrain(still ? AudioFeatureFrame.silence : frame)),
              ),
            )),
          ),
        ),
      )),
      Text(still ? 'Spectrum motion is paused.' : 'Bass to treble · drag to explore',
        style: Theme.of(context).textTheme.bodySmall),
    ]));
  }

  List<Model3D> _terrain(AudioFeatureFrame frame) {
    final bands = frame.bands;
    final figures = <Model3D>[];
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 16; column++) {
        final index = column * 4 + row;
        final level = bands[index].clamp(0.0, 1.0).toDouble();
        final height = .045 + math.sqrt(level) * 2.1;
        final color = Color.lerp(const Color(0xFF315B4A),
          const Color(0xFF9FF8C8), level)!;
        figures.add(TransformModifier3D(
          Cube3D(1, vm.Vector3.zero(), color: color),
          vm.Matrix4.identity()
            ..translateByDouble((column - 7.5) * .46, height / 2, (row - 1.5) * .65, 1)
            ..scaleByDouble(.23, height, .23, 1),
        ));
      }
    }
    for (var row = 0; row < 4; row++) {
      figures.add(Line3D(vm.Vector3(-3.7, 0, (row - 1.5) * .65),
        vm.Vector3(3.7, 0, (row - 1.5) * .65), color: const Color(0xFF477E68), width: .7));
    }
    return figures;
  }

  @override
  void dispose() { _camera.dispose(); super.dispose(); }
}
