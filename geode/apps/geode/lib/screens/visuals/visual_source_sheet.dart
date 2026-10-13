import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import '../library_screen.dart';
import 'visual_widgets.dart';

Future<void> showVisualSourceSheet(BuildContext context, GeodeAppState state) =>
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
        child: ListenableBuilder(listenable: Listenable.merge([state.music, state.nativeVisuals]),
          builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, children: [
          const VisualEyebrow('The rhythm of your world'), const SizedBox(height: 10),
          Text('Sound & motion', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(state.music.nativeAudioAvailable
            ? 'Your music moves through every world. Touch the water to add a ripple.'
            : 'Drifting seeds and little waves, with your music alongside.'),
          const SizedBox(height: 24),
          VisualFloat(state: state, child: GelPanel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Icon(Icons.water_rounded, color: GeodeTokens.accent),
              const SizedBox(width: 16), Expanded(child: Text('Forest sanctuary',
                style: Theme.of(context).textTheme.titleMedium)),
              if (!state.nativeVisuals.enabled) const Icon(Icons.check_circle_rounded, color: GeodeTokens.accent)]),
            const SizedBox(height: 10),
            const Text('Moss, river stone and a landscape shaped by your touch.'),
            if (state.nativeVisuals.enabled) ...[const SizedBox(height: 14),
              GelButton(label: 'Return to the forest', primary: false, onPressed: () {
                state.nativeVisuals.showNature(); Navigator.pop(context);
              })],
          ]))),
          const SizedBox(height: 12),
          VisualFloat(state: state, phase: 1, child: GelPanel(highlighted: state.music.playing,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [const Icon(Icons.graphic_eq_rounded, color: GeodeTokens.ice),
                const SizedBox(width: 16), Expanded(child: Text('Music playback',
                  style: Theme.of(context).textTheme.titleMedium))]),
              const SizedBox(height: 10),
              Text(state.music.nativeAudioAvailable
                ? 'Bass, melody and brightness follow the sound you are hearing.'
                : 'Choose your music and play it beside the living landscape.'),
              if (state.music.currentTrack != null) ...[
                const SizedBox(height: 14), Text(state.music.currentTrack!.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                GelButton(label: 'Open music', icon: Icons.library_music_outlined, primary: false,
                  onPressed: () { Navigator.pop(context); state.navigate(1); }),
                if (state.nativeVisuals.available) GelButton(label: 'Explore visuals',
                  icon: Icons.auto_awesome_rounded, primary: false, onPressed: () {
                    Navigator.pop(context);
                    openVisualPage(context, PresetLibraryScreen(state: state));
                  }),
              ]),
            ]))),
          const SizedBox(height: 22),
          _unavailable(context, Icons.mic_none_rounded, 'Microphone', 'Microphone capture is not available yet.'),
          const Divider(height: 28),
          _unavailable(context, Icons.apps_rounded, 'Other apps', 'Use imported music for audio-reactive visuals.'),
          const SizedBox(height: 20),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Return to the flow')),
        ])),
      ),
    )));

Widget _unavailable(BuildContext context, IconData icon, String title, String detail) =>
  Semantics(enabled: false, child: Row(children: [
    Icon(icon, color: GeodeTokens.muted), const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 3),
      Text(detail, style: Theme.of(context).textTheme.bodySmall),
    ])),
  ]));
