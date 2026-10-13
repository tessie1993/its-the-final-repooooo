import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../media/music_controller.dart';
import '../../state/geode_app_state.dart';
import 'music_widgets.dart';

Future<void> showTrackDetails(BuildContext context, GeodeAppState state,
  MusicTrack track) => Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => TrackDetailsScreen(state: state, track: track)));

class TrackDetailsScreen extends StatefulWidget {
  const TrackDetailsScreen({super.key, required this.state, required this.track});
  final GeodeAppState state;
  final MusicTrack track;
  @override
  State<TrackDetailsScreen> createState() => _TrackDetailsScreenState();
}

class _TrackDetailsScreenState extends State<TrackDetailsScreen> {
  late final _title = TextEditingController(text: widget.track.title);
  late final _artist = TextEditingController(text: widget.track.artist);
  late final _album = TextEditingController(text: widget.track.album);
  late final _lyrics = TextEditingController(text: widget.track.lyrics);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _title.dispose(); _artist.dispose(); _album.dispose(); _lyrics.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => MusicPage(title: 'Track details',
    child: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
        child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: MusicArtwork(size: 140, radius: 40)),
          const SizedBox(height: 24),
          GelPanel(child: Column(children: [
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Enter a title' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _artist, decoration: const InputDecoration(labelText: 'Artist')),
            const SizedBox(height: 16),
            TextFormField(controller: _album, decoration: const InputDecoration(labelText: 'Album')),
          ])),
          const SizedBox(height: 20),
          GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lyrics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Paste plain lyrics or timed LRC lyrics, such as [00:12.50] followed by a line.'),
            const SizedBox(height: 12),
            TextFormField(controller: _lyrics, minLines: 6, maxLines: 14,
              decoration: const InputDecoration(hintText: 'Your lyrics', border: OutlineInputBorder())),
          ])),
          const SizedBox(height: 20),
          GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('File information', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(widget.track.path, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Duration: ${widget.track.durationMs > 0 ? formatMusicTime(Duration(milliseconds: widget.track.durationMs)) : 'Available after loading'}'),
            Text('Size: ${widget.track.sizeBytes > 0 ? '${(widget.track.sizeBytes / 1048576).toStringAsFixed(1)} MB' : 'Unknown'}'),
            const SizedBox(height: 12),
            const Text('Edits are saved in your Geode library. Original audio tags and files are unchanged.'),
          ])),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: GelButton(label: 'Save details', icon: Icons.check_rounded,
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              final latest = widget.state.music.tracks.firstWhere((track) => track.id == widget.track.id,
                orElse: () => widget.track);
              widget.state.music.updateTrack(latest.copyWith(title: _title.text.trim(),
                artist: _artist.text.trim(), album: _album.text.trim(), lyrics: _lyrics.text));
              Navigator.pop(context);
            })),
          const SizedBox(height: 24),
        ])),
      )),
    ),
  );
}
