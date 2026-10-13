import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../components/gel_route.dart';
import '../../media/music_controller.dart';
import '../../scene/gel_float.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import 'audio_settings_screen.dart';
import 'lyrics_sheet.dart';
import 'music_widgets.dart';
import 'queue_sheet.dart';
import 'track_details.dart';

Future<void> showNowPlaying(BuildContext context, GeodeAppState state) =>
  showGelRoute<void>(context, NowPlayingScreen(state: state), name: '/music/playing');

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state.music, builder: (context, _) {
      final music = state.music;
      final track = music.currentTrack;
      final text = Theme.of(context).textTheme;
      final compact = MediaQuery.sizeOf(context).width < 340;
      return MusicPage(title: 'Now playing', actions: [
        IconButton(tooltip: 'Audio settings', icon: const Icon(Icons.tune_rounded),
          onPressed: () => showGelRoute<void>(context, AudioSettingsScreen(state: state), name: '/music/audio')),
        IconButton(tooltip: 'Track details', icon: const Icon(Icons.more_horiz_rounded),
          onPressed: track == null ? null : () => showTrackDetails(context, state, track)),
      ], child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(compact ? 12 : 24, 20, compact ? 12 : 24, 36),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540),
          child: Column(children: [
            MusicErrorBanner(music: music),
            if (track == null) MusicEmpty(title: 'Let your music flow',
              message: 'Choose audio files from your device, then press play.',
              actionLabel: 'Import music', action: music.busy ? null : music.importAudio)
            else ...[
              Text('YOUR MUSIC, NATURALLY', style: text.labelSmall),
              const SizedBox(height: 25),
              GelFloat(controller: state.scene, anchor: const Offset(.5, .4), weight: 2.4,
                child: _NatureRecord(playing: music.playing,
                  reducedMotion: state.scene.effectiveReducedMotion)),
              const SizedBox(height: 30),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.title, style: text.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(track.artist.isEmpty ? 'Unknown artist' : track.artist, style: text.bodyLarge),
                  if (track.album.isNotEmpty) Text(track.album, style: text.bodySmall),
                ])),
                const SizedBox(width: 12),
                GelIconButton(icon: music.favorites.contains(track.id) ? Icons.favorite : Icons.favorite_border,
                  tooltip: music.favorites.contains(track.id) ? 'Remove from favorites' : 'Add to favorites',
                  selected: music.favorites.contains(track.id), onPressed: () => music.toggleFavorite(track.id)),
              ]),
              const SizedBox(height: 20),
              _SeekBar(key: ValueKey(track.id), music: music),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GelIconButton(icon: Icons.shuffle_rounded, tooltip: 'Shuffle', selected: music.shuffle,
                  onPressed: () => music.setShuffle(!music.shuffle)),
                GelIconButton(icon: Icons.skip_previous_rounded, tooltip: 'Previous track',
                  onPressed: music.busy || music.loading ? null : music.previous),
                SizedBox(width: compact ? 64 : 78, height: compact ? 64 : 78, child: GelPanel(radius: 39,
                  padding: EdgeInsets.zero, child: music.busy || music.loading
                    ? const Center(child: SizedBox(width: 27, height: 27, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(iconSize: 38, tooltip: music.playing ? 'Pause' : 'Play',
                        onPressed: music.togglePlay,
                        icon: Icon(music.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)))),
                GelIconButton(icon: Icons.skip_next_rounded, tooltip: 'Next track',
                  onPressed: music.busy || music.loading ? null : music.next),
                GelIconButton(icon: music.repeatMode == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  tooltip: ['Repeat off', 'Repeat all', 'Repeat one'][music.repeatMode.clamp(0, 2)],
                  selected: music.repeatMode != 0,
                  onPressed: () => music.setRepeatMode((music.repeatMode + 1) % 3)),
              ]),
              const SizedBox(height: 26),
              Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                GelButton(label: 'Lyrics', icon: Icons.lyrics_outlined, primary: false,
                  onPressed: () => showLyrics(context, state)),
                GelButton(label: 'Queue', icon: Icons.queue_music_rounded, primary: false,
                  onPressed: () => showQueue(context, state)),
                GelButton(label: 'Loop & sleep', icon: Icons.bedtime_outlined, primary: false,
                  onPressed: () => _showTools(context)),
              ]),
              const SizedBox(height: 22),
              if (music.loopStart != null || music.sleepEndsAt != null) GelPanel(
                padding: const EdgeInsets.all(16), child: Column(children: [
                  if (music.loopStart != null) Text('Loop from ${formatMusicTime(music.loopStart!)}'
                    '${music.loopEnd == null ? ' · choose an end point' : ' to ${formatMusicTime(music.loopEnd!)}'}'),
                  if (music.sleepEndsAt != null) Text('Sleep timer ends at '
                    '${TimeOfDay.fromDateTime(music.sleepEndsAt!).format(context)}'),
                ])),
            ],
          ]),
        )),
      ));
    });

  Future<void> _showTools(BuildContext context) => showModalBottomSheet<void>(
    context: context, showDragHandle: true, isScrollControlled: true,
    backgroundColor: GeodeTokens.deep,
    builder: (context) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: ListenableBuilder(listenable: state.music, builder: (context, _) {
        final music = state.music;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Linger a little', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Text('A–B LOOP', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          const Text('Mark a start and an end while listening to repeat a passage.'),
          const SizedBox(height: 16),
          ValueListenableBuilder<Duration>(valueListenable: music.position,
            builder: (context, position, _) => Wrap(spacing: 10, runSpacing: 10, children: [
              GelButton(label: music.loopStart == null ? 'Set A' : 'A · ${formatMusicTime(music.loopStart!)}',
                primary: false, onPressed: () => music.setLoopStart(position)),
              GelButton(label: music.loopEnd == null ? 'Set B' : 'B · ${formatMusicTime(music.loopEnd!)}',
                primary: false, onPressed: music.loopStart != null && position > music.loopStart!
                  ? () => music.setLoopEnd(position) : null),
              TextButton(onPressed: music.loopStart == null ? null : () {
                music.setLoopStart(null); music.setLoopEnd(null);
              }, child: const Text('Clear loop')),
            ])),
          const SizedBox(height: 28),
          Text('SLEEP TIMER', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(music.sleepEndsAt == null ? 'Let the music pause when it is time to rest.' :
            'Music pauses at ${TimeOfDay.fromDateTime(music.sleepEndsAt!).format(context)}.'),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final minutes in [15, 30, 45, 60])
              ActionChip(label: Text('$minutes min'), onPressed: () =>
                music.setSleepTimer(Duration(minutes: minutes))),
            if (music.sleepEndsAt != null) ActionChip(label: const Text('Cancel timer'),
              onPressed: () => music.setSleepTimer(null)),
          ]),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerRight, child: TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done'))),
        ]);
      }),
    )),
  );
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({super.key, required this.music});
  final MusicController music;
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _NatureRecord extends StatefulWidget {
  const _NatureRecord({required this.playing, required this.reducedMotion});
  final bool playing, reducedMotion;
  @override
  State<_NatureRecord> createState() => _NatureRecordState();
}

class _NatureRecordState extends State<_NatureRecord> with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(vsync: this,
    duration: const Duration(seconds: 36));
  void _sync() {
    final animate = widget.playing && !widget.reducedMotion && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_rotation.isAnimating) { _rotation.repeat(); }
    if (!animate) { _rotation.stop(); }
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _sync(); }
  @override
  void didUpdateWidget(_NatureRecord oldWidget) { super.didUpdateWidget(oldWidget); _sync(); }
  @override
  void dispose() { _rotation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final size = constraints.maxWidth.clamp(0.0, 310.0).toDouble();
    return Semantics(image: true, label: 'A moss-covered jade record floating in water',
      child: SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
        Container(width: size * .83, height: size * .83,
          decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: Color(0x65001013), blurRadius: 36, spreadRadius: 10, offset: Offset(0, 28)),
            BoxShadow(color: Color(0x3866A791), blurRadius: 42, spreadRadius: 5),
          ])),
        Transform(alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, .0012)..rotateX(-.10)..rotateY(.08),
          child: RotationTransition(turns: _rotation,
            child: RepaintBoundary(child: Image.asset('assets/images/stone-dial.png',
              width: size, height: size, fit: BoxFit.contain, excludeFromSemantics: true)))),
      ])));
  });
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: widget.music.position, builder: (context, position, _) {
      final duration = widget.music.duration;
      final total = duration.inMilliseconds.toDouble();
      final value = (_drag ?? position.inMilliseconds.toDouble()).clamp(0.0, total > 0 ? total : 1.0).toDouble();
      return Column(children: [
        Semantics(label: 'Playback position', child: Slider(min: 0, max: total > 0 ? total : 1,
          value: value, label: formatMusicTime(Duration(milliseconds: value.round())),
          onChanged: total <= 0 ? null : (value) => setState(() => _drag = value),
          onChangeEnd: (value) {
            widget.music.seek(Duration(milliseconds: value.round()));
            setState(() => _drag = null);
          })),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatMusicTime(Duration(milliseconds: value.round())),
              style: Theme.of(context).textTheme.bodySmall),
            Text(total > 0 ? formatMusicTime(duration) : '—:—', style: Theme.of(context).textTheme.bodySmall),
          ])),
      ]);
    });
}
