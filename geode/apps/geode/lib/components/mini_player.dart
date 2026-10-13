import 'package:flutter/material.dart';
import '../screens/music/music_widgets.dart';
import '../state/geode_app_state.dart';
import '../three_d/medallion_3d.dart';
import 'gel_panel.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.state, required this.onOpen});
  final GeodeAppState state;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: state.music,
    builder: (context, _) {
      final music = state.music;
      final track = music.currentTrack;
      if (track == null) return const SizedBox.shrink();
      return GelPanel(radius: 23, padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
        opacity: .9, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            SizedBox.square(dimension: 42, child: Medallion3D(compact: true,
              music: music, nature: state.scene,
              fallback: MusicArtwork(size: 42, radius: 14, track: track))),
            const SizedBox(width: 10),
            Expanded(child: Semantics(button: true, label: 'Open now playing',
              child: InkWell(onTap: onOpen, borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 56),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                    Text(track.artist.isEmpty ? 'Unknown artist' : track.artist,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  ]))))),
            IconButton(onPressed: music.busy || music.loading ? null : music.togglePlay,
              tooltip: music.playing ? 'Pause music' : 'Play music',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(music.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
            IconButton(onPressed: music.queue.isEmpty || music.busy || music.loading ? null : music.next,
              tooltip: 'Next track', constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.skip_next_rounded)),
          ]),
          ValueListenableBuilder<Duration>(valueListenable: music.position,
            builder: (_, position, child) => ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(minHeight: 2,
                value: music.duration.inMilliseconds > 0
                  ? (position.inMilliseconds / music.duration.inMilliseconds).clamp(0.0, 1.0)
                  : 0, backgroundColor: Colors.white10))),
        ]));
    });
}
