import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../components/gel_route.dart';
import '../../media/music_controller.dart';
import '../../scene/gel_float.dart';
import '../../state/geode_app_state.dart';
import 'music_collection_screen.dart';
import 'music_widgets.dart';
import 'track_actions.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({super.key, required this.state});
  final GeodeAppState state;
  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  final _search = TextEditingController();
  int _tab = 0;
  String _sort = 'title';
  static const _tabs = ['Tracks', 'Albums', 'Artists', 'Playlists', 'Favorites', 'Recent'];
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state.music, builder: (context, _) {
      final music = widget.state.music;
      final query = _search.text.trim().toLowerCase();
      var tracks = music.tracks.where((track) =>
        ' ${track.title} ${track.artist} ${track.album}'.toLowerCase().contains(query) &&
        (_tab != 4 || music.favorites.contains(track.id)) &&
        (_tab != 5 || music.recentIds.contains(track.id))).toList();
      if (_tab == 5) {
        tracks.sort((a, b) => music.recentIds.indexOf(a.id).compareTo(music.recentIds.indexOf(b.id)));
      } else {
        tracks.sort((a, b) => switch (_sort) {
          'artist' => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
          'album' => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
          'added' => b.addedAt.compareTo(a.addedAt),
          _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        });
      }
      final groups = <String, List<MusicTrack>>{};
      if (_tab == 1 || _tab == 2) {
        for (final track in tracks) {
          final raw = _tab == 1 ? track.album : track.artist;
          final name = raw.isEmpty ? (_tab == 1 ? 'Unknown album' : 'Unknown artist') : raw;
          groups.putIfAbsent(name, () => []).add(track);
        }
      }
      final groupNames = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final playlists = music.playlists.where((list) => list.name.toLowerCase().contains(query)).toList();
      final count = _tab == 3 ? playlists.length : _tab == 1 || _tab == 2 ? groupNames.length : tracks.length;
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820),
        child: CustomScrollView(slivers: [
          SliverPadding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            sliver: SliverToBoxAdapter(child: _header(context, music))),
          if (!music.initialized && music.loading) const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
          else if (!music.initialized) SliverPadding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            sliver: SliverToBoxAdapter(child: MusicEmpty(title: 'Let’s reopen your library',
              message: 'Your saved collection has been kept. Try loading it again.',
              actionLabel: 'Retry', action: music.initialize, icon: Icons.refresh_rounded)))
          else if (count == 0) SliverPadding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            sliver: SliverToBoxAdapter(child: _empty(context, music, query)))
          else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList.builder(itemCount: count, itemBuilder: (context, index) {
              if (_tab == 1 || _tab == 2) {
                final name = groupNames[index];
                return _groupTile(name, '${groups[name]!.length} tracks',
                  _tab == 1 ? Icons.album_rounded : Icons.person_outline_rounded,
                  () => _openCollection(name, _tab == 1 ? 'album' : 'artist', name));
              }
              if (_tab == 3) {
                final playlist = playlists[index];
                return _groupTile(playlist.name, '${playlist.trackIds.length} tracks',
                  Icons.queue_music_rounded, () => _openCollection(playlist.name, 'playlist', playlist.id));
              }
              return MusicTrackTile(state: widget.state, track: tracks[index], from: tracks);
            })),
        ]),
      ));
    },
  );

  Widget _header(BuildContext context, MusicController music) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('YOUR LISTENING GROVE', style: text.labelSmall),
      const SizedBox(height: 10),
      Text('Music library', style: text.headlineLarge),
      const SizedBox(height: 10),
      Text('A quieter place for the music you love.', style: text.bodyLarge),
      const SizedBox(height: 24),
      GelFloat(controller: widget.state.scene, anchor: const Offset(.5, .25), weight: 2.5,
        child: GelPanel(padding: const EdgeInsets.all(18), child: Row(children: [
          const MusicArtwork(size: 66), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${music.tracks.length} ${music.tracks.length == 1 ? 'track' : 'tracks'}', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(music.busy ? music.importStatus ?? 'Adding your music…' : 'From your device. Always yours.', style: text.bodySmall),
          ])),
          GelIconButton(icon: music.busy ? Icons.hourglass_top_rounded : Icons.add_rounded,
            tooltip: 'Import audio files', onPressed: music.busy ? null : music.importAudio),
        ]))),
      if (music.busy) ...[
        const SizedBox(height: 10),
        LinearProgressIndicator(value: music.importProgress),
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: music.cancelImport, child: const Text('Cancel import'))),
      ] else Align(alignment: Alignment.centerRight, child: TextButton.icon(
        icon: const Icon(Icons.link_rounded), label: const Text('Import from link'),
        onPressed: () => _importLink(context, music))),
      const SizedBox(height: 18),
      MusicErrorBanner(music: music),
      GelPanel(radius: 22, padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
        child: TextField(controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(icon: const Icon(Icons.search_rounded),
            hintText: _tab == 3 ? 'Find a playlist' : 'Search your music', border: InputBorder.none,
            suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Clear search',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded))))),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (var index = 0; index < _tabs.length; index++) Padding(
          padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(_tabs[index]), selected: _tab == index, showCheckmark: false,
            visualDensity: VisualDensity.standard, materialTapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            onSelected: (_) => setState(() => _tab = index))),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(_tabs[_tab].toUpperCase(), style: text.labelSmall)),
        if (_tab == 3) TextButton.icon(onPressed: _newPlaylist,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.add_rounded), label: const Text('New playlist'))
        else if (_tab != 5) PopupMenuButton<String>(tooltip: 'Sort music', initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'title', child: Text('Title · A to Z')),
            PopupMenuItem(value: 'artist', child: Text('Artist · A to Z')),
            PopupMenuItem(value: 'album', child: Text('Album · A to Z')),
            PopupMenuItem(value: 'added', child: Text('Recently added')),
          ], icon: const Icon(Icons.sort_rounded)),
      ]),
      const SizedBox(height: 6),
    ]);
  }

  Widget _groupTile(String name, String subtitle, IconData icon, VoidCallback onTap) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: GelPanel(radius: 22,
      padding: const EdgeInsets.all(4), child: ListTile(minTileHeight: 82,
        leading: Stack(alignment: Alignment.center, children: [
          const MusicArtwork(size: 52, radius: 18), Icon(icon, shadows: const [Shadow(blurRadius: 6)]),
        ]), title: Text(name), subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16), onTap: onTap)));

  Widget _empty(BuildContext context, MusicController music, String query) {
    if (query.isNotEmpty) { return MusicEmpty(title: 'Nothing found',
      message: 'Try a different title, artist or album.', actionLabel: 'Clear search',
      action: () => setState(_search.clear), icon: Icons.search_rounded); }
    if (_tab == 3) { return MusicEmpty(title: 'Make a little collection',
      message: 'Gather your favorite tracks into a playlist for any mood.',
      actionLabel: 'Create playlist', action: _newPlaylist, icon: Icons.queue_music_rounded); }
    if (_tab == 4) { return const MusicEmpty(title: 'Keep what moves you',
      message: 'Add a heart to a track and find it here.', icon: Icons.favorite_border_rounded); }
    if (_tab == 5) { return const MusicEmpty(title: 'Your listening trail',
      message: 'Tracks you play will appear here.', icon: Icons.history_rounded); }
    return MusicEmpty(title: 'Bring your music into nature',
      message: 'Choose audio files from your device to start your personal collection.',
      actionLabel: 'Import music', action: music.busy ? null : music.importAudio);
  }

  Future<void> _newPlaylist() async {
    final name = await musicNameDialog(context, title: 'New playlist', action: 'Create');
    if (name == null || !mounted) return;
    final id = widget.state.music.createPlaylist(name);
    _openCollection(name, 'playlist', id);
  }

  Future<void> _importLink(BuildContext context, MusicController music) async {
    final url = await showDialog<String>(context: context, builder: (_) => const _AudioLinkDialog());
    if (url != null && mounted) await music.importAudioUrl(url);
  }

  void _openCollection(String name, String type, String id) => showGelRoute<void>(context,
    MusicCollectionScreen(state: widget.state, title: name, kind: type, collectionId: id),
    name: '/music/$type');
}

class _AudioLinkDialog extends StatefulWidget {
  const _AudioLinkDialog();
  @override
  State<_AudioLinkDialog> createState() => _AudioLinkDialogState();
}

class _AudioLinkDialogState extends State<_AudioLinkDialog> {
  final _input = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  void _submit() {
    if (_form.currentState!.validate()) Navigator.pop(context, _input.text.trim());
  }
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true,
    title: const Text('Import an audio link'),
    content: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Download a direct audio file into your library for offline listening. '
          'Use a file link, such as MP3, M4A, WAV or FLAC. Web pages and live radio links are not supported.'),
        const SizedBox(height: 18),
        TextFormField(controller: _input, autofocus: true, keyboardType: TextInputType.url,
          autocorrect: false, decoration: const InputDecoration(labelText: 'Audio file URL', hintText: 'https://'),
          onFieldSubmitted: (_) => _submit(), validator: (value) {
            final uri = Uri.tryParse(value?.trim() ?? '');
            return uri != null && const ['http', 'https'].contains(uri.scheme) &&
              uri.host.isNotEmpty && uri.userInfo.isEmpty ? null : 'Enter a direct HTTP or HTTPS audio link';
          }),
      ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Download'))]);
}
