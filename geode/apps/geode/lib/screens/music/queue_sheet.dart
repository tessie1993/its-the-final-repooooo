import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import 'music_widgets.dart';

Future<void> showQueue(BuildContext context, GeodeAppState state) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: GeodeTokens.deep,
      builder: (_) => QueueSheet(state: state),
    );

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: ListenableBuilder(listenable: state.music, builder: (context, _) {
        final music = state.music;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Queue', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('${music.queue.length} tracks · drag to reorder',
                  style: Theme.of(context).textTheme.bodyMedium),
              ])),
              if (music.queue.isNotEmpty) IconButton(tooltip: 'Clear queue',
                icon: const Icon(Icons.playlist_remove_rounded), onPressed: () async {
                  if (await confirmMusicAction(context, title: 'Clear queue?',
                    message: 'Playback will stop. Your library and playlists are kept.', action: 'Clear')) {
                    await music.clearQueue();
                  }
                }),
              IconButton(tooltip: 'Close queue', icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
            ])),
          if (music.queue.isEmpty)
            const Expanded(child: Center(child: Padding(padding: EdgeInsets.all(30),
              child: Text('Your queue is quiet. Play a track or add music from your library.',
                textAlign: TextAlign.center))))
          else Expanded(child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            buildDefaultDragHandles: false,
            itemCount: music.queue.length,
            onReorderItem: music.moveQueue,
            itemBuilder: (context, index) {
              final id = music.queue[index];
              final matches = music.tracks.where((track) => track.id == id);
              final track = matches.isEmpty ? null : matches.first;
              final current = index == music.queueIndex;
              return Padding(key: ValueKey('$index-$id'),
                padding: const EdgeInsets.only(bottom: 10),
                child: GelPanel(radius: 22, padding: const EdgeInsets.all(8),
                  opacity: current ? .85 : .45,
                  child: Row(children: [
                    ReorderableDragStartListener(index: index,
                      child: const SizedBox(width: 48, height: 56,
                        child: Icon(Icons.drag_indicator, color: GeodeTokens.muted))),
                    Expanded(child: InkWell(borderRadius: BorderRadius.circular(14),
                      onTap: track == null ? null : () => music.playQueueIndex(index),
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Icon(current ? Icons.graphic_eq : Icons.music_note_outlined,
                            size: 20, color: current ? GeodeTokens.accent : GeodeTokens.muted),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track?.title ?? 'Unavailable track', maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              Text(track == null ? 'Remove this item to continue' :
                                '${track.artist}${track.durationMs > 0 ? ' · ${formatMusicTime(Duration(milliseconds: track.durationMs))}' : ''}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall),
                            ])),
                        ])))),
                    IconButton(tooltip: 'Remove from queue',
                      onPressed: () => music.removeQueue(index),
                      icon: const Icon(Icons.remove_circle_outline, size: 21)),
                  ])));
            },
          )),
        ]);
      }),
    ),
  );
}
