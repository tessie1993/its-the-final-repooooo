import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../theme/geode_theme.dart';

/// IDs mirror engine/scenes/.../SceneIds.kt. Listing an ID does not connect the
/// native renderer: these scenes intentionally have no launch action.
const nativeSceneCatalog = <({String id, String name})>[
  (id: 'silk_web', name: 'Silk web'), (id: 'julia', name: 'Julia'),
  (id: 'tunnel', name: 'Tunnel'), (id: 'bars', name: 'Bars'),
  (id: 'ring', name: 'Ring'), (id: 'scope', name: 'Scope'),
  (id: 'plasma', name: 'Plasma'), (id: 'kaleido', name: 'Kaleidoscope'),
  (id: 'warp', name: 'Warp'), (id: 'grid', name: 'Grid'),
  (id: 'voronoi', name: 'Voronoi'), (id: 'mandel', name: 'Mandelbrot'),
  (id: 'liss', name: 'Lissajous'), (id: 'metaballs', name: 'Metaballs'),
  (id: 'ripples', name: 'Ripples'), (id: 'starfield', name: 'Starfield'),
  (id: 'waves', name: 'Waves'), (id: 'hexgrid', name: 'Hex grid'),
  (id: 'spiral', name: 'Spiral'), (id: 'aurora', name: 'Aurora'),
  (id: 'solar', name: 'Solar'), (id: 'winter', name: 'Winter'),
  (id: 'lava', name: 'Lava'), (id: 'milkdrop', name: 'Milkdrop'),
  (id: 'fluid', name: 'Fluid'), (id: 'curlflow', name: 'Curl flow'),
  (id: 'water', name: 'Water'), (id: 'cymatics', name: 'Cymatics'),
  (id: 'vanishing', name: 'Vanishing'), (id: 'morphogen', name: 'Morphogen'),
  (id: 'nebula', name: 'Nebula'), (id: 'noneuclid', name: 'Non-Euclidean'),
  (id: 'kifs', name: 'KIFS'), (id: 'orb_lattice', name: 'Orb lattice'),
  (id: 'rod_tunnel', name: 'Rod tunnel'), (id: 'neon_tiles', name: 'Neon tiles'),
  (id: 'chroma_orb', name: 'Chroma orb'), (id: 'mandala_dome', name: 'Mandala dome'),
  (id: 'bead_vortex', name: 'Bead vortex'), (id: 'merkaba_grid', name: 'Merkaba grid'),
  (id: 'spiral_eye', name: 'Spiral eye'), (id: 'blacklight_bloom', name: 'Blacklight bloom'),
  (id: 'fractal_temple', name: 'Fractal temple'), (id: 'curl_bloom', name: 'Curl bloom'),
  (id: 'nectar_flow', name: 'Nectar flow'),
];

class NativeSceneCatalog extends StatelessWidget {
  const NativeSceneCatalog({super.key, required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    final scenes = nativeSceneCatalog.where((scene) =>
      '${scene.name} ${scene.id}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GelPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, color: GeodeTokens.ice),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Native scene collection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          const Text('These scenes are in the Geode engine catalog. They require the native renderer, which is not connected to this Flutter app yet. Water, Opal and Mercury are available in Looks.'),
        ])),
      ])),
      const SizedBox(height: 18),
      if (scenes.isEmpty) const Padding(padding: EdgeInsets.all(28),
        child: Text('No native scenes match that search.')),
      for (final scene in scenes) Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(enabled: false, child: GelPanel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), radius: 20,
          opacity: .4, blur: 5, child: Row(children: [
            const Icon(Icons.blur_circular_rounded, color: GeodeTokens.muted),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(scene.name, style: Theme.of(context).textTheme.titleSmall),
              Text(scene.id, style: Theme.of(context).textTheme.bodySmall),
            ])),
            const SizedBox(width: 8),
            const Flexible(child: Text('Requires native renderer', textAlign: TextAlign.end,
              style: TextStyle(color: GeodeTokens.muted, fontSize: 11))),
          ])))),
    ]);
  }
}
