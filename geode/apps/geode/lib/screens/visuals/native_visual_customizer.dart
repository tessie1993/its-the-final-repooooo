import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../state/visual_parameters.dart';
import '../../theme/geode_theme.dart';
import 'visual_widgets.dart';
import '../../three_d/controls_3d.dart';

class NativeVisualCustomizer extends StatelessWidget {
  const NativeVisualCustomizer({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: state,
    builder: (context, _) {
      final parameters = visualParameterCatalog.where((p) => p.appliesTo(state.nativeVisuals.sceneId)).toList();
      final groups = parameters.map((p) => p.group).toSet();
      return VisualPageShell(title: 'Shape your visual world',
        subtitle: state.nativeVisuals.sceneId.replaceAll('_', ' '),
        actions: [IconButton(tooltip: 'Save visual look', onPressed: () => saveCurrentLook(context, state),
          icon: const Icon(Icons.bookmark_add_outlined))],
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 100),
              GelPanel(child: Column(children: [
                GelSlider(label: 'Audio drive', value: state.scene.energy, onChanged: state.setEnergy),
                GelSlider(label: 'Color hue', value: state.scene.hue, onChanged: state.setHue),
              ])),
              const SizedBox(height: 16),
              for (final group in groups) Padding(padding: const EdgeInsets.only(bottom: 16),
                child: GelPanel(padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ExpansionTile(title: Text(group), childrenPadding: const EdgeInsets.all(12),
                    shape: const Border(), collapsedShape: const Border(),
                    initiallyExpanded: group == 'Motion', children: [
                      for (final parameter in parameters.where((p) => p.group == group))
                        _control(context, parameter),
                    ]))),
              if (state.nativeVisuals.error != null) Padding(padding: const EdgeInsets.only(bottom: 16),
                child: Text(state.nativeVisuals.error!, style: const TextStyle(color: GeodeTokens.accent))),
              Wrap(spacing: 12, runSpacing: 12, children: [
                GelButton(label: 'Save this world', icon: Icons.bookmark_add_outlined,
                  onPressed: () => saveCurrentLook(context, state)),
                TextButton.icon(onPressed: state.resetVisualParameters,
                  icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset visual settings')),
              ]),
            ]))),
        ]));
    });

  Widget _control(BuildContext context, VisualParameter parameter) {
    final value = state.visualParameter(parameter);
    if (parameter.toggle) {
      return SwitchTile3D(contentPadding: EdgeInsets.zero,
      title: Text(parameter.label), value: value >= .5,
      onChanged: (enabled) => state.setVisualParameter(parameter, enabled ? 1 : 0));
    }
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(children: [
      Row(children: [Expanded(child: Text(parameter.label)),
        Text(parameter.integer ? '${value.round()}' : value.toStringAsFixed(2),
          style: const TextStyle(color: GeodeTokens.accent))]),
      Semantics(label: parameter.label, child: Slider(value: value, min: parameter.min, max: parameter.max,
        divisions: parameter.integer ? (parameter.max - parameter.min).round() : null,
        semanticFormatterCallback: (v) => '${parameter.label}: ${v.toStringAsFixed(2)}',
        onChanged: (v) => state.setVisualParameter(parameter, v))),
    ]));
  }
}
