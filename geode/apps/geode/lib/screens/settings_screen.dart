import 'package:flutter/material.dart';

import '../components/components.dart';
import '../scene/gel_float.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PREFERENCES', style: text.labelSmall),
          const SizedBox(height: 12),
          Text('Make it yours', style: text.headlineLarge),
          const SizedBox(height: 12),
          Text('Find your own kind of quiet.', style: text.bodyLarge),
          const SizedBox(height: 28),
          GelFloat(controller: state.scene, anchor: const Offset(.6, .27), weight: 1.8,
            child: GelPanel(padding: const EdgeInsets.all(20), child: Row(children: [
              const Icon(Icons.spa_outlined, color: GeodeTokens.accent, size: 30),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('A softer space', style: text.titleMedium),
                const SizedBox(height: 5),
                Text('Adjust the movement and detail until Geode feels right for you.',
                  style: text.bodyMedium),
              ])),
            ])),
          ),
          const SizedBox(height: 26),
          Text('COMFORT & DETAIL', style: text.labelSmall),
          const SizedBox(height: 12),
          GelFloat(controller: state.scene, anchor: const Offset(.5, .52), phase: 1.7, weight: 2,
            child: GelPanel(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(children: [
                _setting(context, Icons.motion_photos_off_outlined, 'Reduce motion',
                  'Still surfaces, without drifting or touch waves.',
                  state.scene.reducedMotion, state.setReducedMotion),
                if (state.scene.effectiveReducedMotion && !state.scene.reducedMotion)
                  Padding(padding: const EdgeInsets.only(left: 42, bottom: 18),
                    child: Text('Reduced motion is enabled by your device.', style: text.bodySmall)),
                const Divider(height: 1),
                _setting(context, Icons.auto_awesome_outlined, 'Rich material detail',
                  'More detailed light and reflections. Uses more graphics power.',
                  state.scene.highQuality, state.setQuality),
                const Divider(height: 1),
                _setting(context, Icons.grain_rounded, 'Floating particles',
                  'Tiny suspended glints throughout the scene.',
                  state.scene.particlesEnabled, state.setParticles),
                const Divider(height: 1),
                _setting(context, Icons.eco_outlined, 'Nature details',
                  'Show decorative fern accents around the scene.',
                  state.natureDetails, state.setNatureDetails),
              ]),
            ),
          ),
          const SizedBox(height: 26),
          GelFloat(controller: state.scene, anchor: const Offset(.4, .8), phase: 3, weight: 1.6,
            child: GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Back to the beginning', style: text.titleMedium),
              const SizedBox(height: 8),
              Text('Return to forest glass, gentle movement and full nature detail. '
                'Your saved looks stay in your collection.', style: text.bodyMedium),
              const SizedBox(height: 18),
              GelButton(label: 'Reset appearance', icon: Icons.restart_alt_rounded, primary: false,
                onPressed: () {
                  state.resetAppearance();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forest glass restored.')));
                }),
            ])),
          ),
          const SizedBox(height: 30),
          Text('GEODE', style: text.labelSmall?.copyWith(letterSpacing: 4)),
          const SizedBox(height: 8),
          Text('A nature-inspired visual study.\nPreferences and saved looks apply to this session.',
            style: text.bodySmall),
        ]),
      )),
    );
  }

  Widget _setting(BuildContext context, IconData icon, String title, String subtitle,
    bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, size: 23, color: GeodeTokens.ice),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ])),
      const SizedBox(width: 10),
      Semantics(label: title, child: Switch(value: value, onChanged: onChanged)),
    ]),
  );
}
