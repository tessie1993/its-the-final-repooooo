import 'package:flutter/material.dart';
import '../../media/music_controller.dart';
import '../../state/geode_app_state.dart';
import '../../scene/gel_float.dart';
import '../../components/gel_panel.dart';
import 'music_widgets.dart';
import 'now_playing_screen.dart';
import 'track_details.dart';

class MusicTrackTile extends StatelessWidget {
  const MusicTrackTile({super.key, required this.state, required this.track,
    this.from, this.playlistId, this.trailing});
  final GeodeAppState state;
  final MusicTrack track;
  final List<MusicTrack>? from;
  final String? playlistId;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final current = state.music.currentTrack?.id == track.id;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: GelFloat(controller: state.scene, anchor: const Offset(.5, .6),
        weight: 3.2, phase: (track.id.hashCode % 10).toDouble(),
        child: GelPanel(radius: 32, opacity: current ? .78 : .48, blur: 6,
          pearl: true, highlighted: current,
          padding: const EdgeInsets.symmetric(horizontal: 6), child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      leading: Stack(alignment: Alignment.center, children: [
        const MusicArtwork(size: 48, radius: 15),
        if (current) const Icon(Icons.graphic_eq_rounded, color: Colors.white),
      ]),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text('${track.artist.isEmpty ? 'Unknown artist' : track.artist}'
        '${track.durationMs > 0 ? ' · ${formatMusicTime(Duration(milliseconds: track.durationMs))}' : ''}',
        maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: current,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onTap: () { state.music.playTrack(track, from: from); showNowPlaying(context, state); },
      trailing: trailing ?? PopupMenuButton<String>(
        tooltip: 'Options for ${track.title}',
        constraints: const BoxConstraints(minWidth: 200),
        onSelected: (value) => trackAction(context, state, track, value, playlistId: playlistId),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'favorite', child: Text(state.music.favorites.contains(track.id) ? 'Unfavorite' : 'Add to favorites')),
          const PopupMenuItem(value: 'queue', child: Text('Add to queue')),
          const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
          const PopupMenuItem(value: 'details', child: Text('Track details & lyrics')),
          if (playlistId != null) const PopupMenuItem(value: 'removePlaylist', child: Text('Remove from playlist')),
          const PopupMenuItem(value: 'remove', child: Text('Remove from library')),
        ],
      ),
    ))));
  }
}

Future<void> trackAction(BuildContext context, GeodeAppState state,
  MusicTrack track, String action, {String? playlistId}) async {
  switch (action) {
    case 'favorite': state.music.toggleFavorite(track.id); break;
    case 'queue':
      state.music.enqueue(track.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to queue')));
      break;
    case 'playlist': await addTrackToPlaylist(context, state, track); break;
    case 'details': await showTrackDetails(context, state, track); break;
    case 'removePlaylist':
      if (playlistId != null) state.music.removeFromPlaylist(playlistId, track.id);
      break;
    case 'remove':
      if (await confirmMusicAction(context, title: 'Remove this track?',
        message: '“${track.title}” will leave your library, playlists and queue. The original audio file stays on your device.') && context.mounted) {
        state.music.removeTrack(track.id);
      }
      break;
  }
}

Future<void> addTrackToPlaylist(BuildContext context, GeodeAppState state, MusicTrack track) async {
  final selected = await showModalBottomSheet<String>(context: context,
    isScrollControlled: true, showDragHandle: true,
    builder: (context) => SafeArea(child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Padding(padding: const EdgeInsets.all(12), child: Text('Add to playlist', style: Theme.of(context).textTheme.titleLarge)),
        ListTile(minTileHeight: 56, leading: const Icon(Icons.add_rounded), title: const Text('Create a playlist'),
          onTap: () => Navigator.pop(context, '__new')),
        for (final playlist in state.music.playlists)
          ListTile(minTileHeight: 56, leading: const Icon(Icons.queue_music_rounded),
            title: Text(playlist.name), subtitle: Text('${playlist.trackIds.length} tracks'),
            trailing: playlist.trackIds.contains(track.id) ? const Icon(Icons.check_rounded) : null,
            onTap: () => Navigator.pop(context, playlist.id)),
      ]),
    )));
  if (selected == null || !context.mounted) return;
  String playlistId = selected;
  if (selected == '__new') {
    final name = await musicNameDialog(context, title: 'New playlist', action: 'Create');
    if (name == null || !context.mounted) return;
    playlistId = state.music.createPlaylist(name);
  }
  state.music.addToPlaylist(playlistId, track.id);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Added to playlist')));
}
