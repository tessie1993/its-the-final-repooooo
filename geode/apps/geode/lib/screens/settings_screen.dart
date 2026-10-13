import 'package:flutter/material.dart';

import '../components/components.dart';
import '../components/gel_route.dart';
import '../scene/gel_float.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';
import 'library_screen.dart';
import 'music/audio_settings_screen.dart';
import 'visuals/visual_customizer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});
  final GeodeAppState state;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _retrying = false;
  GeodeAppState get state => widget.state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: state,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(context),
          if (state.error != null) ...[
            const SizedBox(height: 20), _errorPanel(context),
          ],
          const SizedBox(height: 26),
          LayoutBuilder(builder: (context, constraints) {
            final preferences = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _eyebrow(context, 'Comfort & detail'), const SizedBox(height: 12),
              _preferences(context), const SizedBox(height: 22), _resetPanel(context),
            ]);
            final collection = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _eyebrow(context, 'Your Geode'), const SizedBox(height: 12),
              _destinations(context), const SizedBox(height: 22),
              _collectionStatus(context), const SizedBox(height: 22),
              _aboutPanel(context),
            ]);
            if (constraints.maxWidth >= 820) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: preferences), const SizedBox(width: 24),
                Expanded(flex: 5, child: collection),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              preferences, const SizedBox(height: 28), collection,
            ]);
          }),
          const SizedBox(height: 26),
          Text('GEODE  /  A LITTLE CLOSER TO NATURE', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2)),
        ]))),
    ));

  Widget _header(BuildContext context) => _float(0, const Offset(.4, .24),
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow(context, 'Preferences'), const SizedBox(height: 12),
        Text('Make it yours.', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text('Find your own kind of quiet.', style: Theme.of(context).textTheme.bodyLarge),
      ])),
      if (state.natureDetails) Padding(padding: const EdgeInsets.only(left: 8),
        child: Image.asset('assets/images/crystal-fern.png', width: 88, height: 108, excludeFromSemantics: true)),
    ]));

  Widget _preferences(BuildContext context) => _float(1, const Offset(.35, .5),
    GelPanel(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(children: [
        _setting(context, Icons.motion_photos_off_outlined, 'Reduce motion',
          'Still surfaces, without drifting or touch waves.', state.scene.reducedMotion, state.setReducedMotion),
        if (state.scene.effectiveReducedMotion && !state.scene.reducedMotion)
          Padding(padding: const EdgeInsets.only(left: 40, bottom: 16),
            child: Text('Your device’s reduced-motion preference is active.', style: Theme.of(context).textTheme.bodySmall)),
        const Divider(height: 1),
        _setting(context, Icons.vibration_rounded, 'Gentle haptics',
          'A light response to touch on supported devices.', state.haptics, state.setHaptics),
        const Divider(height: 1),
        _setting(context, Icons.auto_awesome_outlined, 'Rich material detail',
          'More detailed light and reflections. Uses more graphics power.', state.scene.highQuality, state.setQuality),
        const Divider(height: 1),
        _setting(context, Icons.grain_rounded, 'Floating particles',
          'Tiny suspended glints throughout the scene.', state.scene.particlesEnabled, state.setParticles),
        const Divider(height: 1),
        _setting(context, Icons.eco_outlined, 'Nature details',
          'Fern droplets and crystal accents around your world.', state.natureDetails, state.setNatureDetails),
      ])));

  Widget _destinations(BuildContext context) => _float(1.8, const Offset(.75, .45),
    GelPanel(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Column(children: [
      _navigation(context, Icons.headphones_rounded, 'Sound & playback', 'Volume, speed, repeat and sleep timer',
        () => showGelRoute(context, AudioSettingsScreen(state: state), name: '/settings/audio')),
      const Divider(height: 1, indent: 16, endIndent: 16),
      _navigation(context, Icons.tune_rounded, 'Shape the atmosphere', 'Materials, movement and your palette',
        () => showGelRoute(context, VisualCustomizerScreen(state: state), name: '/settings/appearance')),
      const Divider(height: 1, indent: 16, endIndent: 16),
      _navigation(context, Icons.bookmarks_outlined, 'Saved little worlds', 'Presets, favorites and import / export',
        () => showGelRoute(context, PresetLibraryScreen(state: state), name: '/settings/looks')),
    ])));

  Widget _collectionStatus(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([state.music, state.studio, state.visualLibrary]),
    builder: (context, _) {
      final looks = state.looks.where((look) => look.saved).length;
      final error = state.visualLibrary.persistenceError;
      return _float(2.5, const Offset(.7, .65), GelPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [const Icon(Icons.inventory_2_outlined, color: GeodeTokens.ice, size: 21),
            const SizedBox(width: 11), Expanded(child: Text('On this device', style: Theme.of(context).textTheme.titleMedium))]),
          const SizedBox(height: 20),
          Wrap(spacing: 22, runSpacing: 18, children: [
            _count(context, state.music.tracks.length, 'Tracks'),
            _count(context, state.music.playlists.length, 'Playlists'),
            _count(context, looks, 'Saved looks'),
            _count(context, state.studio.projects.length, 'Projects'),
          ]),
          const SizedBox(height: 18),
          Text('Your collections and preferences are stored on this device. Export looks and project files to keep a separate copy.',
            style: Theme.of(context).textTheme.bodySmall),
          if (error != null) ...[
            const SizedBox(height: 12), Text(error, style: const TextStyle(color: Color(0xFFF4CBA9), fontSize: 12)),
            if (!state.visualLibrary.storageReady) Align(alignment: Alignment.centerLeft,
              child: TextButton(onPressed: state.visualLibrary.loading ? null : state.visualLibrary.initialize,
                child: const Text('Retry looks'))),
          ],
          if (!state.music.initialized) ...[
            const SizedBox(height: 12), const Text('Music storage is not ready yet.', style: TextStyle(fontSize: 12)),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: state.music.loading ? null : state.music.initialize,
              child: Text(state.music.loading ? 'Loading music…' : 'Retry music'))),
          ],
          if (state.studio.error != null) ...[
            const SizedBox(height: 12), Text(state.studio.error!, style: const TextStyle(color: Color(0xFFF4CBA9), fontSize: 12)),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => state.navigate(2), child: const Text('Open Studio'))),
          ],
        ])));
    });

  Widget _aboutPanel(BuildContext context) => _float(3.2, const Offset(.65, .82),
    GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Growing into its world', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 9),
      Text('The gel scene and local music player are available. Native audio-reactive scenes, video rendering and live wallpaper still need their engine connections.',
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 6, children: [
        TextButton.icon(icon: const Icon(Icons.info_outline_rounded, size: 19), label: const Text('About Geode'),
          onPressed: () => showAboutDialog(context: context, applicationName: 'Geode',
            applicationVersion: '1.8.0 · build 32',
            applicationIcon: Image.asset('assets/images/fern-dew.png', width: 56, height: 56, excludeFromSemantics: true),
            children: [const Text('Music, living landscapes and creative little worlds.\n\nThis Flutter interface includes a touch-reactive gel scene, local audio playback, saved looks and project editing. Native rendering integrations remain in development.')])),
        TextButton.icon(icon: const Icon(Icons.description_outlined, size: 19), label: const Text('Licenses'),
          onPressed: () => showLicensePage(context: context, applicationName: 'Geode', applicationVersion: '1.8.0')),
      ]),
    ])));

  Widget _resetPanel(BuildContext context) => _float(3.7, const Offset(.35, .82),
    GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Image.asset('assets/images/fern-dew.png', width: 42, height: 42, excludeFromSemantics: true),
        const SizedBox(width: 12), Expanded(child: Text('Back to the beginning', style: Theme.of(context).textTheme.titleMedium))]),
      const SizedBox(height: 12),
      Text('Return to forest glass, gentle movement and full nature detail. Your saved worlds stay in your collection.',
        style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 18),
      GelButton(label: 'Reset appearance', icon: Icons.restart_alt_rounded, primary: false,
        onPressed: () {
          state.resetAppearance();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forest glass restored.')));
        }),
    ])));

  Widget _errorPanel(BuildContext context) => GelPanel(child: Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, color: Color(0xFFF4CBA9)), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(state.error!, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: _retrying ? null : _retry,
          icon: _retrying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded), label: Text(_retrying ? 'Retrying…' : 'Retry preferences')),
      ])),
    ]));

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try { await state.initialize(); }
    catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences could not be restored. Please try again.')));
    } finally { if (mounted) setState(() => _retrying = false); }
  }

  Widget _count(BuildContext context, int count, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$count', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 29)),
      const SizedBox(height: 3), Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);

  Widget _navigation(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) =>
    ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      leading: Icon(icon, color: GeodeTokens.ice), title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20), onTap: onTap);

  Widget _setting(BuildContext context, IconData icon, String title, String subtitle,
    bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18), child: Row(children: [
      Icon(icon, size: 23, color: GeodeTokens.ice), const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ])), const SizedBox(width: 10), Semantics(label: title, child: Switch(value: value, onChanged: onChanged)),
    ]));

  Widget _eyebrow(BuildContext context, String text) => Text(text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GeodeTokens.accent, letterSpacing: 1.8));

  Widget _float(double phase, Offset anchor, Widget child) => GelFloat(
    controller: state.scene, anchor: anchor, phase: phase, weight: 1.8, child: child);
}
