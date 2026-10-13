import 'package:flutter/foundation.dart';

/// User controls for active C++ parameters, matching core/viz/Params.hpp.
/// Retired pulse/shake/flash/strobe fields are intentionally not offered.
@immutable
class VisualParameter {
  const VisualParameter(this.id, this.label, this.group, this.min, this.max,
    this.initial, {this.toggle = false, this.integer = false, this.family});
  final String id, label, group;
  final double min, max, initial;
  final bool toggle, integer;
  final String? family;
  double clamp(double value) {
    final result = value.clamp(min, max).toDouble();
    return integer || toggle ? result.roundToDouble() : result;
  }
  bool appliesTo(String scene) => family == null || switch (family) {
    'fluid' => scene == 'fluid' || scene.startsWith('fluid_'),
    'water' => scene == 'water',
    'milkdrop' => scene == 'milkdrop',
    _ => scene == family,
  };
}

const visualParameterCatalog = [
  VisualParameter('speed', 'Movement speed', 'Motion', 0, 3, 1),
  VisualParameter('zoom', 'Zoom', 'Motion', .25, 3, 1),
  VisualParameter('rotation', 'Rotation', 'Motion', -1, 1, 0),
  VisualParameter('sway', 'Sway', 'Motion', 0, 1, 0),
  VisualParameter('driftX', 'Horizontal drift', 'Motion', -1, 1, 0),
  VisualParameter('driftY', 'Vertical drift', 'Motion', -1, 1, 0),
  VisualParameter('trails', 'Motion trails', 'Motion', 0, 1, 0, toggle: true),
  VisualParameter('trailLength', 'Trail length', 'Motion', 0, .98, .5),
  VisualParameter('saturation', 'Saturation', 'Color & light', 0, 2, 1),
  VisualParameter('brightness', 'Brightness', 'Color & light', .2, 2, 1),
  VisualParameter('contrast', 'Contrast', 'Color & light', .25, 2, 1),
  VisualParameter('gamma', 'Gamma', 'Color & light', .4, 2, 1),
  VisualParameter('temperature', 'Warmth', 'Color & light', -1, 1, 0),
  VisualParameter('bloom', 'Bloom', 'Color & light', 0, 1.5, 0),
  VisualParameter('colorCycle', 'Evolving colors', 'Color & light', 0, 1, 0, toggle: true),
  VisualParameter('cycleSpeed', 'Color speed', 'Color & light', 0, 1, .1),
  VisualParameter('mirror', 'Mirror', 'Shape & texture', 0, 1, 0, toggle: true),
  VisualParameter('kaleidoscope', 'Kaleidoscope', 'Shape & texture', 0, 1, 0, toggle: true),
  VisualParameter('symmetry', 'Symmetry folds', 'Shape & texture', 2, 16, 6, integer: true),
  VisualParameter('warp', 'Warp', 'Shape & texture', 0, 1, 0),
  VisualParameter('morph', 'Morph', 'Shape & texture', 0, 1, 0),
  VisualParameter('twist', 'Twist', 'Shape & texture', -1, 1, 0),
  VisualParameter('grain', 'Film grain', 'Shape & texture', 0, 1, 0),
  VisualParameter('vignette', 'Vignette', 'Shape & texture', 0, 1, 0),
  VisualParameter('chromaAb', 'Color fringes', 'Shape & texture', 0, 1, 0),
  VisualParameter('bassGain', 'Bass response', 'Audio response', 0, 3, 1),
  VisualParameter('midGain', 'Mid response', 'Audio response', 0, 3, 1),
  VisualParameter('trebGain', 'Treble response', 'Audio response', 0, 3, 1),
  VisualParameter('milkdropPaletteTint', 'Palette tint', 'MilkDrop', 0, 1, 0, family: 'milkdrop'),
  VisualParameter('milkdropBlendPresets', 'Blend preset changes', 'MilkDrop', 0, 1, 0, toggle: true, family: 'milkdrop'),
  VisualParameter('waterWaveSpeed', 'Wave speed', 'Water', .1, 3, 1, family: 'water'),
  VisualParameter('waterRippleStrength', 'Water ripples', 'Water', 0, 2, 1, family: 'water'),
  VisualParameter('waterDepth', 'Water depth', 'Water', 0, 2, .6, family: 'water'),
  VisualParameter('waterFlow', 'Water flow', 'Water', 0, 2, .3, family: 'water'),
  VisualParameter('fluidCurl', 'Fluid curl', 'Fluid', 0, 60, 30, family: 'fluid'),
  VisualParameter('fluidDensityDissipation', 'Ink fade', 'Fluid', 0, 3, 1, family: 'fluid'),
  VisualParameter('fluidSplatForce', 'Fluid force', 'Fluid', 0, 3, 1, family: 'fluid'),
  VisualParameter('fluidParticlesEnabled', 'Fluid particles', 'Fluid', 0, 1, 1, toggle: true, family: 'fluid'),
];
