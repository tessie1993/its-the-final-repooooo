import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import 'visual_widgets.dart';

Future<void> showVisualSourceSheet(BuildContext context, GeodeAppState state) =>
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    backgroundColor: GeodeTokens.deep, showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (context) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const VisualEyebrow('The rhythm of your world'), const SizedBox(height: 10),
          Text('Choose a source', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text('Ambient motion shapes the scene. Audio-reactive visuals need the native engine connection.'),
          const SizedBox(height: 24),
          VisualFloat(state: state, child: GelPanel(child: Row(children: [
            const Icon(Icons.water_rounded, color: GeodeTokens.accent), const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ambient motion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 4), Text('Living gel, gentle drift and your touch.'),
            ])), const Icon(Icons.check_circle_rounded, color: GeodeTokens.accent),
          ]))),
          const SizedBox(height: 12),
          VisualFloat(state: state, phase: 1, child: GelPanel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [const Icon(Icons.music_note_rounded), const SizedBox(width: 16),
                Expanded(child: Text('Music playback', style: Theme.of(context).textTheme.titleMedium))]),
              const SizedBox(height: 8),
              const Text('Listen to your local music alongside the scene. The scene does not react to audio in this build.'),
              const SizedBox(height: 14),
              GelButton(label: 'Open music', icon: Icons.arrow_forward_rounded, primary: false,
                onPressed: () { Navigator.pop(context); state.navigate(1); }),
            ]))),
          const SizedBox(height: 22),
          _unavailable(context, Icons.mic_none_rounded, 'Microphone', 'Requires native audio capture.'),
          const Divider(height: 28),
          _unavailable(context, Icons.apps_rounded, 'Other apps', 'System audio capture is not connected.'),
          const SizedBox(height: 20),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Return to the flow')),
        ])),
    )));

Widget _unavailable(BuildContext context, IconData icon, String title, String detail) =>
  Semantics(enabled: false, child: Row(children: [
    Icon(icon, color: GeodeTokens.muted), const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 3),
      Text(detail, style: Theme.of(context).textTheme.bodySmall),
    ])), const SizedBox(width: 8), const Text('Unavailable', style: TextStyle(fontSize: 11, color: GeodeTokens.muted)),
  ]));
