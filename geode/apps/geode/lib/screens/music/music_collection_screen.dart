import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../media/music_controller.dart';
import '../../state/geode_app_state.dart';
import 'music_widgets.dart';
import 'now_playing_screen.dart';
import 'playlist_tracks_sheet.dart';
import 'track_actions.dart';

class MusicCollectionScreen extends StatefulWidget {
  const MusicCollectionScreen({super.key, required this.state, required this.title,
    required this.kind, required this.collectionId});
  final GeodeAppState state;
  final String title;
  final String kind;
  final String collectionId;
  @override
  State<MusicCollectionScreen> createState() => _MusicCollectionScreenState();
}

class _MusicCollectionScreenState extends State<MusicCollectionScreen> {
  bool _reordering = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.state.music,
    builder: (context, _) {
      final music = widget.state.music;
      MusicPlaylist? playlist;
      for (final item in music.playlists) {
        if (item.id == widget.collectionId) playlist = item;
      }
      final isPlaylist = widget.kind == 'playlist';
      final tracks = _tracks(music, playlist);
      final name = isPlaylist ? playlist?.name ?? widget.title : widget.title;
      final duration = tracks.fold<int>(0, (total, track) => total + track.durationMs);
      return MusicPage(title: isPlaylist ? 'Playlist' : widget.kind == 'album' ? 'Album' : 'Artist',
        actions: [if (isPlaylist && playlist != null)
          PopupMenuButton<String>(tooltip: 'Playlist options', onSelected: (action) => _action(action, name),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename playlist')),
              PopupMenuItem(value: 'reorder', child: Text(_reordering ? 'Finish reordering' : 'Reorder tracks')),
              const PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
            ])],
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: MusicArtwork(size: 176, radius: 52, track: tracks.firstOrNull)),
                const SizedBox(height: 24),
                Text(name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('${tracks.length} tracks${duration > 0 ? ' · ${formatMusicTime(Duration(milliseconds: duration))} known audio' : ''}'),
                const SizedBox(height: 24),
                MusicErrorBanner(music: music),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  GelButton(label: 'Play all', icon: Icons.play_arrow_rounded,
                    onPressed: tracks.isEmpty || music.busy || music.loading ? null : () async {
                      music.setShuffle(false);
                      await music.playTrack(tracks.first, from: tracks);
                      if (context.mounted) showNowPlaying(context, widget.state);
                    }),
                  GelButton(label: 'Shuffle', primary: false, icon: Icons.shuffle_rounded,
                    onPressed: tracks.isEmpty || music.busy || music.loading ? null : () async {
                      music.setShuffle(true);
                      await music.playTrack(tracks[math.Random().nextInt(tracks.length)], from: tracks);
                      if (context.mounted) showNowPlaying(context, widget.state);
                    }),
                  if (isPlaylist) GelButton(label: 'Add tracks', primary: false,
                    icon: Icons.add_rounded, onPressed: () => showPlaylistTracks(context,
                      widget.state, widget.collectionId)),
                ]),
                if (_reordering && isPlaylist) Padding(padding: const EdgeInsets.only(top: 18),
                  child: Row(children: [const Expanded(child: Text('Drag the handles to change the order.')),
                    TextButton(onPressed: () => setState(() => _reordering = false), child: const Text('Done'))])),
              ]))),
            if (tracks.isEmpty) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(child: MusicEmpty(title: 'A little room for music',
                message: isPlaylist ? 'Add tracks from your library to shape this playlist.' : 'There are no tracks in this collection.',
                actionLabel: isPlaylist ? 'Choose tracks' : null,
                action: isPlaylist ? () => showPlaylistTracks(context, widget.state, widget.collectionId) : null)))
            else if (_reordering && isPlaylist) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(itemCount: tracks.length,
                onReorderItem: (oldIndex, newIndex) => music.movePlaylistTrack(widget.collectionId, oldIndex, newIndex),
                itemBuilder: (context, index) => MusicTrackTile(key: ValueKey(tracks[index].id),
                  state: widget.state, track: tracks[index], from: tracks,
                  trailing: ReorderableDragStartListener(index: index,
                    child: const SizedBox(width: 48, height: 48,
                      child: Tooltip(message: 'Drag to reorder', child: Icon(Icons.drag_handle_rounded)))))))
            else SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(itemCount: tracks.length, itemBuilder: (context, index) =>
                MusicTrackTile(state: widget.state, track: tracks[index], from: tracks,
                  playlistId: isPlaylist ? widget.collectionId : null))),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ]),
        )));
    });

  List<MusicTrack> _tracks(MusicController music, MusicPlaylist? playlist) {
    if (widget.kind == 'playlist') {
      final byId = {for (final track in music.tracks) track.id: track};
      return [for (final id in playlist?.trackIds ?? <String>[])
        if (byId.containsKey(id)) byId[id]!];
    }
    return music.tracks.where((track) {
      final raw = widget.kind == 'album' ? track.album : track.artist;
      final name = raw.isEmpty ? (widget.kind == 'album' ? 'Unknown album' : 'Unknown artist') : raw;
      return name == widget.collectionId;
    }).toList();
  }

  Future<void> _action(String action, String name) async {
    switch (action) {
      case 'rename':
        final renamed = await musicNameDialog(context, title: 'Rename playlist', initial: name);
        if (renamed != null && mounted) widget.state.music.renamePlaylist(widget.collectionId, renamed);
        break;
      case 'reorder': setState(() => _reordering = !_reordering); break;
      case 'delete':
        if (await confirmMusicAction(context, title: 'Delete playlist?',
          message: '“$name” will be removed. Your tracks stay in the music library.', action: 'Delete') && mounted) {
          widget.state.music.deletePlaylist(widget.collectionId);
          if (mounted) Navigator.pop(context);
        }
        break;
    }
  }
}
