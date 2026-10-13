import 'package:flutter/material.dart';
import '../../state/geode_app_state.dart';
import 'music_widgets.dart';
import '../../three_d/controls_3d.dart';

Future<void> showPlaylistTracks(BuildContext context, GeodeAppState state, String playlistId) =>
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    showDragHandle: true, useSafeArea: true,
    builder: (_) => _PlaylistTracks(state: state, playlistId: playlistId));

class _PlaylistTracks extends StatefulWidget {
  const _PlaylistTracks({required this.state, required this.playlistId});
  final GeodeAppState state;
  final String playlistId;
  @override
  State<_PlaylistTracks> createState() => _PlaylistTracksState();
}

class _PlaylistTracksState extends State<_PlaylistTracks> {
  String _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.state.music,
    builder: (context, _) {
      final music = widget.state.music;
      final selected = <String>{};
      for (final playlist in music.playlists) {
        if (playlist.id == widget.playlistId) selected.addAll(playlist.trackIds);
      }
      final tracks = music.tracks.where((track) => '${track.title} ${track.artist}'.toLowerCase().contains(_query)).toList();
      return Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(height: MediaQuery.sizeOf(context).height * .76,
          child: CustomScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(child: Column(children: [
                Row(children: [Expanded(child: Text('Choose tracks', style: Theme.of(context).textTheme.titleLarge)),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]),
                const SizedBox(height: 8),
                TextField(onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search your library')),
                const SizedBox(height: 12),
                MusicErrorBanner(music: music),
              ]))),
              if (tracks.isEmpty) SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(child: MusicEmpty(
                  title: music.tracks.isEmpty ? 'Import music first' : 'No matching tracks',
                  message: music.tracks.isEmpty ? 'Choose audio files from your device, then add them here.' : 'Try another title or artist.',
                  action: music.tracks.isEmpty && !music.busy ? music.importAudio : null, actionLabel: 'Import music')))
              else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(itemCount: tracks.length, itemBuilder: (context, index) {
                  final track = tracks[index];
                  final checked = selected.contains(track.id);
                  void toggle(bool value) {
                    if (value) { music.addToPlaylist(widget.playlistId, track.id); }
                    else { music.removeFromPlaylist(widget.playlistId, track.id); }
                  }
                  return MergeSemantics(child: ListTile(
                    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    leading: MusicArtwork(size: 44, radius: 15, track: track),
                    trailing: Check3D(value: checked, onChanged: toggle),
                    onTap: () => toggle(!checked)));
                })),
            ])));
    });
}
