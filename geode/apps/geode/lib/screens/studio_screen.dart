import 'package:flutter/material.dart';

import '../components/components.dart';
import '../scene/gel_float.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key, required this.state});
  final GeodeAppState state;

  Future<void> _save(BuildContext context) async {
    final result = await showDialog<String>(context: context,
      builder: (_) => const _SaveLookDialog());
    if (result == null || !context.mounted) return;
    state.saveLook(result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('“$result” saved for this session.'),
      action: SnackBarAction(label: 'View', onPressed: () => state.navigate(1)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final materialNames = ['Forest glass', 'Moonstone', 'Liquid silver'];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STUDIO', style: text.labelSmall),
          const SizedBox(height: 12),
          Text('Shape the\natmosphere', style: text.headlineLarge),
          const SizedBox(height: 12),
          Text('A material. A movement. A world of your own.', style: text.bodyLarge),
          const SizedBox(height: 28),
          GelFloat(controller: state.scene, anchor: const Offset(.5, .35), phase: .8,
            child: SceneThumbnail(materialIndex: state.scene.materialIndex, height: 220,
              child: Stack(children: [
                if (state.natureDetails)
                  Positioned(right: -20, bottom: -12,
                    child: NaturePebble(label: 'Living detail', width: 180, height: 135)),
                Positioned(left: 20, bottom: 22, right: 120, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MATERIAL STUDY', style: text.labelSmall?.copyWith(color: GeodeTokens.ink)),
                    const SizedBox(height: 6),
                    Text(materialNames[state.scene.materialIndex], style: text.titleLarge),
                  ])),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          _floating(const Offset(.5, .54), 1, GelPanel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('01   Choose a material', style: text.titleMedium),
              const SizedBox(height: 18),
              GelMaterialPicker(selectedIndex: state.scene.materialIndex, onChanged: state.setMaterial),
              const SizedBox(height: 16),
              Text('Light bends through glass, gathers in stone, and flows over silver.',
                style: text.bodyMedium),
            ],
          ))),
          const SizedBox(height: 20),
          _floating(const Offset(.45, .68), 2, GelPanel(child: GelSlider(
            label: '02   Motion energy', value: state.scene.energy,
            onChanged: state.setEnergy,
            description: state.scene.effectiveReducedMotion
              ? 'Motion is currently reduced. Your energy setting is kept for later.'
              : 'From a quiet drift to a lively current. Touch the scene to feel the gel.',
          ))),
          const SizedBox(height: 20),
          _floating(const Offset(.55, .8), 3, GelPanel(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(children: [
              _toggle(context, 'Living details', 'Decorative fern accents around your world.',
                state.natureDetails, state.setNatureDetails),
              const Divider(height: 1),
              _toggle(context, 'Floating particles', 'Small glints suspended in the gel.',
                state.scene.particlesEnabled, state.setParticles),
            ]),
          )),
          const SizedBox(height: 24),
          _floating(const Offset(.5, .9), 4, Wrap(spacing: 12, runSpacing: 12, children: [
            GelButton(label: 'Save this look', icon: Icons.bookmark_add_outlined,
              primary: true, onPressed: () => _save(context)),
            GelButton(label: 'Step inside', icon: Icons.arrow_outward_rounded,
              primary: false, onPressed: () => state.navigate(0)),
          ])),
        ]),
      )),
    );
  }

  Widget _floating(Offset anchor, double phase, Widget child) => GelFloat(
    controller: state.scene, anchor: anchor, phase: phase, weight: 1.6, child: child);

  Widget _toggle(BuildContext context, String title, String description,
    bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ])),
      const SizedBox(width: 12),
      Semantics(label: title, child: Switch(value: value, onChanged: onChanged)),
    ]),
  );
}

class _SaveLookDialog extends StatefulWidget {
  const _SaveLookDialog();
  @override
  State<_SaveLookDialog> createState() => _SaveLookDialogState();
}

class _SaveLookDialogState extends State<_SaveLookDialog> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF183540),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    title: const Text('Name your little world'),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _name, autofocus: true, maxLength: 36,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'A quiet morning'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          }),
        const SizedBox(height: 8),
        const Text('Saved looks stay in your collection for this session.'),
      ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ValueListenableBuilder<TextEditingValue>(valueListenable: _name,
        builder: (context, value, _) => FilledButton(
          onPressed: value.text.trim().isEmpty ? null
            : () => Navigator.pop(context, value.text.trim()),
          child: const Text('Save look'),
        )),
    ],
  );
}
