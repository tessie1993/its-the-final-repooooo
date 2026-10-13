import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';
import 'music_widgets.dart';

Future<void> showLyrics(BuildContext context, GeodeAppState state) =>
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    showDragHandle: true, backgroundColor: GeodeTokens.deep,
    builder: (_) => LyricsSheet(state: state));

class LyricsSheet extends StatelessWidget {
  const LyricsSheet({super.key, required this.state});
  final GeodeAppState state;

  Future<void> _edit(BuildContext context) async {
    final track = state.music.currentTrack;
    if (track == null) return;
    final input = TextEditingController(text: track.lyrics);
    final result = await showDialog<String>(context: context, builder: (context) =>
      AlertDialog(scrollable: true, title: const Text('Your lyrics'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paste plain lyrics or timed LRC text, such as [00:12.50] First line.'),
            const SizedBox(height: 16),
            TextField(controller: input, minLines: 5, maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(labelText: 'Lyrics', alignLabelWithHint: true,
                border: OutlineInputBorder())),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Save lyrics'))]));
    if (result != null) {
      final latest = state.music.tracks.firstWhere((item) => item.id == track.id, orElse: () => track);
      state.music.updateTrack(latest.copyWith(lyrics: result));
    }
    // Let the closing route finish using the field before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: ListenableBuilder(listenable: state.music, builder: (context, _) {
      final music = state.music;
      final track = music.currentTrack;
      final lines = _parseLyrics(track?.lyrics ?? '');
      final timed = lines.any((line) => line.time != null);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 16, 16), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Words in the water', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(track?.title ?? 'Nothing playing', maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          IconButton(tooltip: 'Edit lyrics', onPressed: track == null ? null : () => _edit(context),
            icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: 'Close lyrics', onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
        ])),
        if (lines.isEmpty) Expanded(child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(28), child: GelPanel(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lyrics_outlined, size: 42, color: GeodeTokens.ice),
              const SizedBox(height: 16),
              Text('Give this song its words', style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('Add lyrics from your own collection. Timed LRC lyrics follow playback.',
                textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GelButton(label: 'Add lyrics', icon: Icons.add,
                onPressed: track == null ? null : () => _edit(context)),
            ])))))
        else ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(timed ? 'Timed lyrics · tap a line to seek' : 'Your saved lyrics',
              style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 8),
          Expanded(child: ValueListenableBuilder<Duration>(valueListenable: music.position,
            builder: (context, position, _) {
              var active = -1;
              for (var i = 0; i < lines.length; i++) {
                if (lines[i].time != null && lines[i].time! <= position) active = i;
              }
              return ListView.builder(padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                itemCount: lines.length, itemBuilder: (context, index) {
                  final line = lines[index];
                  final selected = index == active;
                  return Padding(padding: const EdgeInsets.only(bottom: 12),
                    child: Material(color: Colors.transparent, child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: line.time == null ? null : () => music.seek(line.time!),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero :
                          const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                          color: selected ? GeodeTokens.ice.withValues(alpha: .13) : Colors.transparent),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (line.time != null) Text(formatMusicTime(line.time!),
                            style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Text(line.text, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: selected || !timed ? GeodeTokens.ink : GeodeTokens.muted,
                            height: 1.45)),
                        ])))));
                });
            })),
        ],
      ]);
    }),
  ));
}

class _LyricLine {
  const _LyricLine(this.text, this.time);
  final String text;
  final Duration? time;
}

List<_LyricLine> _parseLyrics(String lyrics) {
  final result = <_LyricLine>[];
  final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  for (final raw in lyrics.split('\n')) {
    final text = raw.replaceAll(timestamp, '').trim();
    if (text.isEmpty || RegExp(r'^\[(ar|al|ti|by|offset):', caseSensitive: false).hasMatch(text)) continue;
    final matches = timestamp.allMatches(raw);
    if (matches.isEmpty) {
      result.add(_LyricLine(text, null));
    } else {
      for (final match in matches) {
        final millis = (match.group(3) ?? '').padRight(3, '0');
        result.add(_LyricLine(text, Duration(minutes: int.parse(match.group(1)!),
          seconds: int.parse(match.group(2)!), milliseconds: int.parse(millis))));
      }
    }
  }
  if (result.every((line) => line.time != null)) {
    result.sort((a, b) => a.time!.compareTo(b.time!));
  }
  return result;
}
