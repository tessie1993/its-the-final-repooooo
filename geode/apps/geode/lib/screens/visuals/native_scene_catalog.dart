import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../theme/geode_theme.dart';
import '../../state/geode_app_state.dart';

/// Display names for the original C++ scene IDs. The engine supplies the
/// available IDs at runtime; controls remain disabled if it cannot initialize.
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
  // GPU fluid dynamics (core/viz/fluid): Navier-Stokes dye and velocity fields.
  (id: 'fluid_ink', name: 'Ink in water'), (id: 'fluid_oilslick', name: 'Oil slick'),
  (id: 'fluid_neon', name: 'Neon fluid'), (id: 'fluid_chrome', name: 'Liquid chrome'),
  (id: 'fluid_smoke', name: 'Smoke'), (id: 'fluid_lava', name: 'Molten flow'),
  (id: 'fluid_marble', name: 'Marbling'), (id: 'fluid_aurora', name: 'Aurora fluid'),
  // Particle agents (physarum): thousands of sensing, depositing particles.
  (id: 'myco_polycephalum', name: 'Slime mould'), (id: 'myco_rivals', name: 'Rival colonies'),
  (id: 'myco_symbiosis', name: 'Symbiosis'), (id: 'myco_predator', name: 'Predator and prey'),
  (id: 'myco_ghosts', name: 'Ghost trails'), (id: 'myco_circuit', name: 'Circuit growth'),
  (id: 'myco_silkroad', name: 'Silk road'), (id: 'myco_sporestorm', name: 'Spore storm'),
  (id: 'myco_capillary', name: 'Capillaries'), (id: 'myco_frostvein', name: 'Frost veins'),
];

class NativeSceneCatalog extends StatelessWidget {
  const NativeSceneCatalog({super.key, required this.query, required this.state});
  final String query;
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state.nativeVisuals, builder: (context, _) {
      final native = state.nativeVisuals;
      final names = {for (final scene in nativeSceneCatalog) scene.id: scene.name};
      final ids = native.scenes.isEmpty ? names.keys.toList() : native.scenes;
      final scenes = ids.where((id) => '${names[id] ?? id} $id'
        .toLowerCase().contains(query.toLowerCase())).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GelPanel(highlighted: native.enabled, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.auto_awesome_rounded, color: GeodeTokens.ice),
            const SizedBox(width: 14), Expanded(child: Text('Living visuals',
              style: Theme.of(context).textTheme.titleLarge))]),
          const SizedBox(height: 10),
          Text(native.available
            ? 'Choose a world. Your music shapes its light and movement.'
            : native.loading ? 'Preparing your visual collection…'
            : 'The visual engine is unavailable on this device. Your nature looks are ready to use.'),
          if (native.error != null) ...[const SizedBox(height: 10), Text(native.error!,
            style: const TextStyle(color: Color(0xFFF4CBA9)))],
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            GelButton(label: 'Forest sanctuary', icon: Icons.water_drop_outlined, primary: false,
              onPressed: () { native.showNature(); Navigator.pop(context); }),
            if (native.presets.isNotEmpty) GelButton(label: 'MilkDrop presets',
              icon: Icons.auto_awesome_rounded, primary: false,
              onPressed: native.loading ? null : () => _showMilkdropPresets(context, state)),
          ]),
        ])),
        const SizedBox(height: 18),
        if (scenes.isEmpty) const Padding(padding: EdgeInsets.all(28),
          child: Text('No visual scenes match that search.')),
        for (final id in scenes) Padding(padding: const EdgeInsets.only(bottom: 10),
          child: GelPanel(radius: 28, opacity: native.enabled && native.sceneId == id ? .78 : .42,
            highlighted: native.enabled && native.sceneId == id,
            blur: 5, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: ListTile(enabled: native.available && !native.loading,
              selected: native.enabled && native.sceneId == id,
              leading: MaterialOrb(materialIndex: id == 'milkdrop' ? 1 : 0, size: 44),
              title: Text(names[id] ?? id.replaceAll('_', ' ')),
              subtitle: id == 'milkdrop' && native.milkPreset != null
                ? Text(_presetName(native.milkPreset!), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
              trailing: Icon(native.enabled && native.sceneId == id
                ? Icons.check_circle_rounded : Icons.arrow_outward_rounded,
                color: GeodeTokens.accent, size: 21),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              onTap: () async {
                await native.selectScene(id);
                if (context.mounted && native.enabled && native.error == null) Navigator.pop(context);
              },
            ),
          )),
      ]);
    });
}

String _presetName(String path) => path.split('/').last.replaceFirst(RegExp(r'\.milk$'), '');

Future<void> _showMilkdropPresets(BuildContext context, GeodeAppState state) =>
  showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
    builder: (context) => _MilkdropPresetSheet(state: state));

class _MilkdropPresetSheet extends StatefulWidget {
  const _MilkdropPresetSheet({required this.state});
  final GeodeAppState state;
  @override
  State<_MilkdropPresetSheet> createState() => _MilkdropPresetSheetState();
}

class _MilkdropPresetSheetState extends State<_MilkdropPresetSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) => SafeArea(child: SizedBox(
    height: MediaQuery.sizeOf(context).height * .75,
    child: ListenableBuilder(listenable: widget.state.nativeVisuals, builder: (context, _) {
      final native = widget.state.nativeVisuals;
      final presets = native.presets.where((path) => _presetName(path)
        .toLowerCase().contains(_query.toLowerCase())).toList();
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MilkDrop worlds', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(hintText: 'Find a preset',
              prefixIcon: Icon(Icons.search_rounded)), onChanged: (value) => setState(() => _query = value)),
            if (native.error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(native.error!, style: const TextStyle(color: Color(0xFFF4CBA9)))),
          ])),
        Expanded(child: presets.isEmpty ? const Center(child: Text('No presets found'))
          : ListView.builder(itemCount: presets.length, itemBuilder: (context, index) {
            final preset = presets[index];
            return ListTile(title: Text(_presetName(preset)), enabled: !native.loading,
              selected: native.milkPreset == preset,
              leading: const Icon(Icons.auto_awesome_rounded),
              trailing: native.milkPreset == preset ? const Icon(Icons.check_rounded) : null,
              onTap: () async {
                await native.selectMilkPreset(preset);
                if (context.mounted && native.error == null) Navigator.pop(context);
              });
          })),
      ]);
    }),
  ));
}
