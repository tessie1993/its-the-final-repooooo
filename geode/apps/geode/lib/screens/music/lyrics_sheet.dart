import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../media/music_controller.dart';
import '../../media/music_lyrics.dart';
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
    final result = await showDialog<String>(context: context,
      builder: (_) => _LyricsEditorDialog(initial: track.lyrics));
    if (result != null && context.mounted) {
      final latest = state.music.tracks.firstWhere((item) => item.id == track.id, orElse: () => track);
      state.music.updateTrack(latest.copyWith(lyrics: result));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: ListenableBuilder(listenable: state.music, builder: (context, _) {
      final music = state.music;
      final track = music.currentTrack;
      final lines = parseLyrics(track?.lyrics ?? '');
      final timed = lines.any((line) => line.time != null);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 16, 16), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lyrics', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
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
          Expanded(child: _FollowingLyrics(key: ValueKey('${track?.id}:${track?.lyrics.hashCode}'),
            music: music, lines: lines, timed: timed)),
        ],
      ]);
    }),
  ));
}

class _FollowingLyrics extends StatefulWidget {
  const _FollowingLyrics({super.key, required this.music, required this.lines, required this.timed});
  final MusicController music;
  final List<LyricLine> lines;
  final bool timed;
  @override
  State<_FollowingLyrics> createState() => _FollowingLyricsState();
}

class _FollowingLyricsState extends State<_FollowingLyrics> {
  final _scroll = ScrollController();
  bool _following = true;
  int _lastActive = -2;
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _follow(int active, double height) {
    if (!_following || active < 0 || !_scroll.hasClients) return;
    final target = (12 + active * height - _scroll.position.viewportDimension / 2 + height / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
    if (MediaQuery.disableAnimationsOf(context)) { _scroll.jumpTo(target); }
    else { _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut); }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: widget.music.position, builder: (context, position, _) {
      final active = activeLyricIndex(widget.lines, position);
      final rowHeight = 138 * MediaQuery.textScalerOf(context).scale(1);
      if (active != _lastActive) {
        _lastActive = active;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _follow(active, rowHeight);
        });
      }
      return Stack(children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle && _following) {
              setState(() => _following = false);
            }
            return false;
          },
          child: ListView.builder(controller: _scroll,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 70),
            itemExtent: rowHeight, itemCount: widget.lines.length,
            itemBuilder: (context, index) {
              final line = widget.lines[index];
              final selected = index == active;
              return Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Material(color: Colors.transparent, child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: line.time == null ? null : () => widget.music.seek(line.time!),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                      color: selected ? GeodeTokens.ice.withValues(alpha: .13) : Colors.transparent),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (line.time != null) Text(formatMusicTime(line.time!),
                          style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Flexible(child: Tooltip(message: line.text,
                          child: Text(line.text.isEmpty ? '♪' : line.text, maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: selected || !widget.timed ? GeodeTokens.ink : GeodeTokens.muted, height: 1.4)))),
                      ])))));
            })),
        if (widget.timed && !_following) Positioned(bottom: 12, right: 24,
          child: FilledButton.icon(onPressed: () {
            setState(() => _following = true);
            _follow(active, rowHeight);
          }, icon: const Icon(Icons.my_location_rounded), label: const Text('Follow lyrics'))),
      ]);
    });
}

class _LyricsEditorDialog extends StatefulWidget {
  const _LyricsEditorDialog({required this.initial});
  final String initial;
  @override
  State<_LyricsEditorDialog> createState() => _LyricsEditorDialogState();
}

class _LyricsEditorDialogState extends State<_LyricsEditorDialog> {
  late final _input = TextEditingController(text: widget.initial);
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true,
    title: const Text('Your lyrics'),
    content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Paste plain lyrics or timed LRC text, such as [00:12.50] First line.'),
        const SizedBox(height: 16),
        TextField(controller: _input, minLines: 5, maxLines: 12,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: 'Lyrics', alignLabelWithHint: true,
            border: OutlineInputBorder())),
      ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: const Text('Save lyrics'))]);
}
