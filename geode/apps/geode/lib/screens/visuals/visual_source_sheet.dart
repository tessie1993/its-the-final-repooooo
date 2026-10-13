import 'package:flutter/material.dart';
import 'package:geode_engine/geode_engine.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import 'visual_widgets.dart';

Future<void> showVisualSourceSheet(BuildContext context, GeodeAppState state) =>
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    showDragHandle: true, builder: (context) => _VisualSourceSheet(state: state));

class _VisualSourceSheet extends StatefulWidget {
  const _VisualSourceSheet({required this.state});
  final GeodeAppState state;
  @override
  State<_VisualSourceSheet> createState() => _VisualSourceSheetState();
}

class _VisualSourceSheetState extends State<_VisualSourceSheet> {
  bool _busy = false;
  GeodeAppState get state => widget.state;

  Future<void> _select(String source) async {
    setState(() => _busy = true);
    await state.nativeVisuals.setAudioSource(source);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
      child: ListenableBuilder(listenable: Listenable.merge([state.music, state.nativeVisuals]),
        builder: (context, _) {
          final native = state.nativeVisuals;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const VisualEyebrow('The rhythm of your world'), const SizedBox(height: 10),
            Text('Sound & motion', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            const Text('Choose the sound that moves your landscape. Every meter follows the sound being analyzed.'),
            const SizedBox(height: 22),
            _source(Icons.library_music_outlined, 'Your music',
              state.music.currentTrack?.title ?? 'Play imported music from your collection.',
              selected: native.audioSource == 'player',
              onTap: _busy || !native.available ? null : () => _select('player')),
            const SizedBox(height: 12),
            _source(Icons.mic_none_rounded, 'Microphone',
              native.available ? 'React to the room or live music while Geode is open. Microphone permission is requested when selected.'
                : 'Microphone input is available in the Android app.',
              selected: native.audioSource == 'microphone',
              onTap: _busy || !native.available ? null : () => _select('microphone')),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (native.error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(native.error!, style: const TextStyle(color: GeodeTokens.accent))),
            if (native.available) ...[
              const SizedBox(height: 14),
              GelPanel(child: ValueListenableBuilder<AudioFeatureFrame>(valueListenable: state.music.analysis,
                builder: (context, frame, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [const Expanded(child: Text('Live sound', style: TextStyle(fontWeight: FontWeight.w600))),
                    Text(frame.rms > .005 ? 'Listening' : 'Quiet', style: const TextStyle(color: GeodeTokens.accent))]),
                  const SizedBox(height: 18),
                  _meter('Bass', frame.bass), _meter('Mid', frame.mid), _meter('Treble', frame.treble),
                ]))),
            ],
            const SizedBox(height: 22),
            GelButton(label: 'Open music', icon: Icons.library_music_outlined,
              onPressed: () { Navigator.pop(context); state.navigate(1); }),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Return to the flow')),
          ];
        }),
    )),
  ));

  Widget _source(IconData icon, String title, String description, {
    required bool selected, required VoidCallback? onTap}) => GelPanel(
      padding: const EdgeInsets.all(6), highlighted: selected,
      child: ListTile(enabled: onTap != null, onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        leading: Icon(icon, color: GeodeTokens.accent),
        title: Text(title), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(description)),
        trailing: selected ? const Icon(Icons.check_circle_rounded, color: GeodeTokens.accent) : null));

  Widget _meter(String label, double value) => Padding(padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [SizedBox(width: 56, child: Text(label)),
      Expanded(child: Semantics(label: '$label level', value: '${(value * 100).round()} percent',
        child: LinearProgressIndicator(value: value, minHeight: 8,
          borderRadius: BorderRadius.circular(6), backgroundColor: GeodeTokens.deep,
          color: GeodeTokens.ice))),
    ]));
}
