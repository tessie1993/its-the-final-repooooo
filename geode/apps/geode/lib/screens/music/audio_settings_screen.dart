import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../scene/gel_float.dart';
import '../../theme/geode_theme.dart';
import 'music_widgets.dart';

class AudioSettingsScreen extends StatelessWidget {
  const AudioSettingsScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => MusicPage(title: 'Shape your sound',
    child: ListenableBuilder(listenable: state.music, builder: (context, _) {
      final music = state.music;
      final text = Theme.of(context).textTheme;
      return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MusicErrorBanner(music: music),
            Text('A SOUND OF YOUR OWN', style: text.labelSmall),
            const SizedBox(height: 12),
            Text('Find your balance', style: text.headlineLarge),
            const SizedBox(height: 12),
            Text('Small adjustments. A different feeling.', style: text.bodyLarge),
            const SizedBox(height: 28),
            GelFloat(controller: state.scene, anchor: const Offset(.5, .35), weight: 2.4,
              child: GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _slider(context, title: 'Volume', valueLabel: '${(music.volume * 100).round()}%',
                icon: Icons.volume_up_outlined, value: music.volume, min: 0, max: 1,
                divisions: 100, onChanged: music.setVolume),
              if (music.speedAvailable) ...[
                const Divider(height: 32),
                _slider(context, title: 'Playback speed', valueLabel: '${music.speed.toStringAsFixed(2)}×',
                  icon: Icons.speed_rounded, value: music.speed, min: .5, max: 2,
                  divisions: 30, onChanged: music.setSpeed),
              ],
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: () { music.setVolume(1);
                  if (music.speedAvailable) music.setSpeed(1); },
                icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset playback'))),
            ]))),
            const SizedBox(height: 22),
            GelFloat(controller: state.scene, anchor: const Offset(.5, .7), weight: 2.8, phase: 1.2,
              child: GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.graphic_eq_rounded, color: GeodeTokens.ice),
                const SizedBox(width: 12),
                Expanded(child: Text('Equalizer', style: text.titleLarge)),
                Switch(value: music.equalizerAvailable && music.equalizerEnabled,
                  onChanged: music.equalizerAvailable ? music.setEqualizerEnabled : null),
              ]),
              const SizedBox(height: 8),
              if (!music.equalizerAvailable)
                Text('The equalizer is available with supported Android audio output. '
                  'Your playback controls remain available here.', style: text.bodyMedium)
              else if (music.eqFrequencies.isEmpty || music.eqGains.isEmpty)
                Text('Play a track to load the available frequency bands.', style: text.bodyMedium)
              else ...[
                Text('Tune the low, mid and high frequencies.', style: text.bodyMedium),
                const SizedBox(height: 20),
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var index = 0; index < music.eqFrequencies.length && index < music.eqGains.length; index++)
                      SizedBox(width: 70, child: Column(children: [
                        Text('${music.eqGains[index] > 0 ? '+' : ''}${music.eqGains[index].toStringAsFixed(1)}',
                          style: text.labelMedium),
                        SizedBox(height: 176, child: RotatedBox(quarterTurns: 3,
                          child: Semantics(label: '${_frequency(music.eqFrequencies[index].toDouble())} equalizer gain',
                            child: Slider(min: music.eqMinGain, max: music.eqMaxGain,
                              value: music.eqGains[index].clamp(music.eqMinGain, music.eqMaxGain).toDouble(),
                              label: '${music.eqGains[index].toStringAsFixed(1)} dB',
                              onChanged: music.equalizerEnabled && music.eqMaxGain > music.eqMinGain
                                ? (value) => music.setEqGain(index, value) : null)))),
                        Text(_frequency(music.eqFrequencies[index].toDouble()), style: text.labelMedium),
                      ])),
                  ])),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  for (final preset in ['Flat', 'Warm', 'Vocal', 'Bright'])
                    ActionChip(label: Text(preset), onPressed: !music.equalizerEnabled ? null : () {
                      for (var i = 0; i < music.eqGains.length && i < music.eqFrequencies.length; i++) {
                        final hz = music.eqFrequencies[i];
                        final gain = switch (preset) {
                          'Warm' => hz < 200 ? 4.0 : hz > 4000 ? -2.0 : 0.0,
                          'Vocal' => hz >= 250 && hz <= 4000 ? 2.0 : -1.0,
                          'Bright' => hz > 2500 ? 3.0 : hz < 150 ? -1.0 : 0.0,
                          _ => 0.0,
                        };
                        music.setEqGain(i, gain.clamp(music.eqMinGain, music.eqMaxGain).toDouble());
                      }
                    }),
                  Text('Gain in dB · frequency in Hz', style: text.bodySmall),
                ]),
              ],
            ]))),
            if (music.equalizerAvailable) ...[
              const SizedBox(height: 22),
              GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Listening texture', style: text.titleLarge),
                const SizedBox(height: 18),
                _slider(context, title: 'Bass boost', valueLabel: '${(music.bassBoost * 100).round()}%',
                  icon: Icons.speaker_rounded, value: music.bassBoost, min: 0, max: 1,
                  divisions: 20, onChanged: (value) => music.setSoundEffects(bass: value)),
                const SizedBox(height: 18),
                _slider(context, title: 'Loudness', valueLabel: '+${music.loudnessDb.toStringAsFixed(1)} dB',
                  icon: Icons.volume_up_rounded, value: music.loudnessDb, min: 0, max: 10,
                  divisions: 20, onChanged: (value) => music.setSoundEffects(loudness: value)),
                const SizedBox(height: 18),
                _slider(context, title: 'Preamp', valueLabel: '${music.preampDb > 0 ? '+' : ''}${music.preampDb.toStringAsFixed(1)} dB',
                  icon: Icons.tune_rounded, value: music.preampDb, min: -15, max: 15,
                  divisions: 60, onChanged: (value) => music.setSoundEffects(preamp: value)),
                SwitchListTile(contentPadding: EdgeInsets.zero,
                  title: const Text('Headphone crossfeed'),
                  subtitle: const Text('Blend a little of each stereo channel for a relaxed headphone sound.'),
                  value: music.crossfeed, onChanged: (value) => music.setSoundEffects(headphoneCrossfeed: value)),
                SwitchListTile(contentPadding: EdgeInsets.zero,
                  title: const Text('Peak limiter'), subtitle: const Text('Keep boosted peaks from clipping.'),
                  value: music.limiter, onChanged: (value) => music.setSoundEffects(peakLimiter: value)),
                const Divider(height: 28),
                Text('ReplayGain', style: text.titleMedium),
                const SizedBox(height: 8),
                const Text('Use embedded loudness tags to balance songs or preserve an album’s dynamics. '
                  'Tracks without tags keep their original level.'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final mode in const {'off': 'Off', 'track': 'Track', 'album': 'Album'}.entries)
                    ChoiceChip(label: Text(mode.value), selected: music.replayGainMode == mode.key,
                      onSelected: (_) => music.setSoundEffects(replayGain: mode.key)),
                ]),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(
                  onPressed: () => music.setSoundEffects(bass: 0, loudness: 0, preamp: 0,
                    headphoneCrossfeed: false, peakLimiter: true, replayGain: 'off'),
                  icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset effects'))),
              ])),
            ],
            const SizedBox(height: 24),
            Text('Audio settings are saved and applied to the music you play.', style: text.bodySmall),
          ]),
        )),
      );
    }),
  );

  Widget _slider(BuildContext context, {required String title, required String valueLabel,
    required IconData icon, required double value, required double min, required double max,
    required int divisions, required ValueChanged<double>? onChanged}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: GeodeTokens.ice), const SizedBox(width: 12),
          Expanded(child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 6,
            children: [Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(valueLabel, style: Theme.of(context).textTheme.labelLarge)]))]),
        const SizedBox(height: 12),
        Semantics(label: title, child: Slider(value: value.clamp(min, max).toDouble(),
          min: min, max: max, divisions: divisions, label: valueLabel, onChanged: onChanged)),
      ]);

  String _frequency(double value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k' : value.round().toString();
}
