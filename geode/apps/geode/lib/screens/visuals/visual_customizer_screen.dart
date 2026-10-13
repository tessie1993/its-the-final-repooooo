import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import 'visual_widgets.dart';
import '../../three_d/asset_3d.dart';
import '../../three_d/crystal_viewer.dart';

class VisualCustomizerScreen extends StatefulWidget {
  const VisualCustomizerScreen({super.key, required this.state});
  final GeodeAppState state;
  @override
  State<VisualCustomizerScreen> createState() => _VisualCustomizerScreenState();
}

class _VisualCustomizerScreenState extends State<VisualCustomizerScreen> {
  int _tab = 0;
  GeodeAppState get state => widget.state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: state,
    builder: (context, _) => VisualPageShell(
      title: 'Shape the atmosphere', subtitle: 'Your personal nature studio',
      actions: [IconButton(tooltip: 'Save current look', icon: const Icon(Icons.bookmark_add_outlined),
        onPressed: () => saveCurrentLook(context, state))],
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _preview(context),
            const SizedBox(height: 16),
            VisualFloat(state: state, phase: 1.6, child: GelPanel(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              opacity: .5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const VisualEyebrow('Turn the stone'),
                GeodeCrystalViewer(fallback: SizedBox(height: 180, child: Center(child: Asset3D.boxed(
                  asset: Geode3DAsset.crystalFern, width: 160, height: 160,
                  fallback: Image.asset('assets/images/crystal-fern.png', width: 160, height: 160,
                    excludeFromSemantics: true))))),
              ]))),
            const SizedBox(height: 22),
            VisualFloat(state: state, child: GelPanel(padding: const EdgeInsets.all(6), radius: 22,
              child: Row(children: [
                for (var i = 0; i < 3; i++) Expanded(child: _tabButton(i)),
              ]))),
            const SizedBox(height: 20),
            AnimatedSwitcher(duration: state.scene.effectiveReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(_tab), child: switch (_tab) {
                0 => _materials(context), 1 => _motion(context), _ => _palette(context),
              })),
            const SizedBox(height: 22),
            VisualFloat(state: state, phase: 2.3, child: GelPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('A little serendipity', style: Theme.of(context).textTheme.titleMedium)),
                  Asset3D.boxed(asset: Geode3DAsset.fernDew, width: 42, height: 42, fallback: Image.asset('assets/images/fern-dew.png', width: 42, height: 42, excludeFromSemantics: true)),
                ]),
                const SizedBox(height: 4),
                const Text('Lock what you love. Shuffle the rest into something new.'),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 10, children: [
                  GelButton(label: 'Surprise me', icon: Icons.casino_outlined,
                    onPressed: state.randomizeVisuals, primary: false),
                  TextButton.icon(onPressed: state.resetAppearance,
                    icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset scene')),
                ]),
              ]))),
            const SizedBox(height: 20),
            VisualFloat(state: state, phase: 3, child: GelButton(label: 'Keep this little world',
              icon: Icons.bookmark_add_outlined, onPressed: () => saveCurrentLook(context, state))),
            const SizedBox(height: 12),
            Text(state.visualLibrary.persistenceError ?? 'Your saved looks stay on this device.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ]))),
      )));

  Widget _preview(BuildContext context) => VisualFloat(state: state, phase: .8,
    child: GelPanel(padding: EdgeInsets.zero, opacity: .45,
      child: SizedBox(height: 225, child: Stack(children: [
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(28),
          child: Asset3D(asset: Geode3DAsset.forestSanctuary, fallback: Image.asset('assets/images/forest-sanctuary.png', fit: BoxFit.cover,
            color: const Color(0xB8092631), colorBlendMode: BlendMode.srcATop,
            excludeFromSemantics: true)))),
        Positioned(right: -20, top: -20, child: VisualFloat(state: state,
          phase: 2, anchor: const Offset(.72, .32), child: Asset3D.boxed(asset: Geode3DAsset.crystalFern, spin: true, width: 245, height: 245, fallback: Image.asset(
            'assets/images/crystal-fern.png', width: 245, height: 245, excludeFromSemantics: true)))),
        Positioned(right: 40, bottom: 32, child: VisualFloat(state: state, phase: 3.5,
          child: MaterialOrb(materialIndex: state.scene.materialIndex, size: 95))),
        Positioned(left: 24, right: 130, bottom: 26, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            VisualEyebrow(state.isEdited ? 'Your evolving look' : 'Current look'),
            const SizedBox(height: 9),
            Text(state.selectedLook.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 9),
            Text('${['Moss', 'Stone', 'Bark'][state.scene.materialIndex]} · ${(state.scene.energy * 100).round()}% flow',
              style: const TextStyle(color: GeodeTokens.ink, fontSize: 12)),
          ])),
      ]))));

  Widget _tabButton(int index) => TextButton(
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      foregroundColor: _tab == index ? GeodeTokens.ink : GeodeTokens.muted,
      backgroundColor: _tab == index ? GeodeTokens.ice.withValues(alpha: .16) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
    onPressed: () => setState(() => _tab = index), child: Text(['Material', 'Motion', 'Palette'][index]));

  Widget _materials(BuildContext context) => VisualFloat(state: state, phase: 1.3,
    child: GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Light you can almost touch', style: Theme.of(context).textTheme.titleLarge)),
        _lock('material', 'Material'),
      ]),
      const SizedBox(height: 7),
      const Text('Choose moss, weathered stone or warm bark. Light and grain follow your selection.'),
      const SizedBox(height: 22),
      GelMaterialPicker(selectedIndex: state.scene.materialIndex, onChanged: state.setMaterial),
      const SizedBox(height: 20),
      Text(switch (state.scene.materialIndex) {
        1 => 'STONE  /  Weathered river rock with soft mineral veins.',
        2 => 'BARK  /  Warm wood grain carved by flowing water.',
        _ => 'MOSS  /  A soft green surface with fine woodland texture.',
      }, style: Theme.of(context).textTheme.bodySmall),
      const Divider(height: 34),
      _toggle(context, 'Living nature', 'Fern droplets and crystal details around your scene.',
        state.natureDetails, state.setNatureDetails),
    ])));

  Widget _motion(BuildContext context) => Column(children: [
    VisualFloat(state: state, phase: 1, child: GelPanel(child: Column(children: [
      _parameter('energy', 'Flow energy', state.scene.energy, state.setEnergy,
        state.scene.effectiveReducedMotion ? 'Motion is reduced. Your flow setting is kept for later.' : 'From a quiet drift to a lively current.'),
      const Divider(height: 32),
      _parameter('rippleStrength', 'Touch ripples', state.scene.rippleStrength, state.setRippleStrength,
        'The strength of waves that travel across the water.'),
    ]))),
    const SizedBox(height: 18),
    VisualFloat(state: state, phase: 2, child: GelPanel(child: Column(children: [
      _toggle(context, 'Suspended particles', 'Seeds and fireflies moving through the scene.',
        state.scene.particlesEnabled, state.setParticles),
      const SizedBox(height: 16),
      _parameter('particleDensity', 'Particle density', state.scene.particleDensity,
        state.scene.particlesEnabled ? state.setParticleDensity : null,
        state.scene.particlesEnabled ? 'Set the number of seeds above the water.' : 'Turn on suspended particles to change their density.'),
      const Divider(height: 28),
      _toggle(context, 'Reduced motion', 'Keep the atmosphere still and remove reactive movement.',
        state.scene.reducedMotion, state.setReducedMotion),
    ]))),
  ]);

  Widget _palette(BuildContext context) {
    const palettes = <({String name, double hue, Color color})>[
      (name: 'Forest', hue: .32, color: Color(0xFF83BF9A)),
      (name: 'Glacier', hue: .5, color: Color(0xFF89D6E3)),
      (name: 'Dusk', hue: .67, color: Color(0xFFB1A1DC)),
      (name: 'Rose', hue: .86, color: Color(0xFFD99DAC)),
      (name: 'Amber', hue: .12, color: Color(0xFFE1C38C)),
    ];
    return VisualFloat(state: state, phase: 1.3, child: GelPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Find your light', style: Theme.of(context).textTheme.titleLarge)), _lock('hue', 'Palette')]),
        const SizedBox(height: 8),
        const Text('A wash of color across the landscape. Pick a mood or find a shade between.'),
        const SizedBox(height: 22),
        Wrap(spacing: 14, runSpacing: 16, children: [
          for (final palette in palettes) Semantics(button: true, label: '${palette.name} palette',
            selected: (state.scene.hue - palette.hue).abs() < .01,
            child: InkWell(borderRadius: BorderRadius.circular(24), onTap: () => state.setHue(palette.hue),
              child: SizedBox(width: 74, child: Column(children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(center: const Alignment(-.4, -.5), colors: [Colors.white,
                    palette.color, palette.color.withValues(alpha: .38)], stops: const [0, .24, 1]),
                  border: Border.all(color: (state.scene.hue - palette.hue).abs() < .01
                    ? GeodeTokens.ink : Colors.white.withValues(alpha: .2), width: 2),
                  boxShadow: [BoxShadow(color: palette.color.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 7))]),
                  child: (state.scene.hue - palette.hue).abs() < .01 ? const Icon(Icons.check_rounded, color: GeodeTokens.deep) : null),
                const SizedBox(height: 10), Text(palette.name, style: Theme.of(context).textTheme.bodySmall),
              ])))),
        ]),
        const SizedBox(height: 28),
        Container(height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: List.generate(7, (i) => HSVColor.fromAHSV(1, i * 60.0, .45, .9).toColor())))),
        const SizedBox(height: 18),
        GelSlider(label: 'Color hue', value: state.scene.hue, onChanged: state.setHue,
          description: 'Changes the tint of the landscape and its floating seeds.'),
      ])));
  }

  Widget _parameter(String key, String label, double value, ValueChanged<double>? onChanged, String description) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: GelSlider(label: label, value: value, onChanged: onChanged, description: description)),
      const SizedBox(width: 8), _lock(key, label),
    ]);

  Widget _lock(String key, String label) => GelIconButton(
    icon: state.parameterLocks.contains(key) ? Icons.lock_rounded : Icons.lock_open_rounded,
    selected: state.parameterLocks.contains(key),
    tooltip: state.parameterLocks.contains(key) ? 'Unlock $label for randomizing' : 'Lock $label while randomizing',
    onPressed: () => state.toggleParameterLock(key));

  Widget _toggle(BuildContext context, String title, String detail, bool value, ValueChanged<bool> onChanged) => Row(
    children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 5),
      Text(detail, style: Theme.of(context).textTheme.bodySmall),
    ])), const SizedBox(width: 14), Semantics(label: title, child: Switch(value: value, onChanged: onChanged))]);
}
