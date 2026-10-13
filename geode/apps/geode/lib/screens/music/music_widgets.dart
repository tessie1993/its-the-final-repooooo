import 'dart:io';
import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../media/music_controller.dart';
import '../../theme/geode_theme.dart';
import '../../three_d/asset_3d.dart';

String formatMusicTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 999999);
  final minutes = seconds ~/ 60;
  return '${minutes.toString().padLeft(1, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class MusicArtwork extends StatelessWidget {
  const MusicArtwork({super.key, this.size = 64, this.radius = 22, this.track});
  final double size;
  final double radius;
  final MusicTrack? track;

  Widget _fallback() => Asset3D(asset: Geode3DAsset.stoneDial, fallback: Image.asset('assets/images/fern-dew.png', fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (_, error, stack) => const Icon(Icons.music_note_rounded)));

  @override
  Widget build(BuildContext context) => Semantics(
    label: track?.artPath.isNotEmpty == true ? 'Artwork for ${track!.album}' : 'Geode fern artwork', image: true,
    child: ClipRRect(borderRadius: BorderRadius.circular(radius),
      child: Container(width: size, height: size, color: const Color(0xFF153831),
        child: track?.artPath.isNotEmpty == true ? Image.file(File(track!.artPath),
          fit: BoxFit.cover, excludeFromSemantics: true, cacheWidth: (size * 3).round(),
          errorBuilder: (_, error, stack) => _fallback()) : _fallback(),
      ),
    ),
  );
}

class MusicErrorBanner extends StatelessWidget {
  const MusicErrorBanner({super.key, required this.music});
  final MusicController music;
  @override
  Widget build(BuildContext context) => music.error == null
    ? const SizedBox.shrink()
    : Padding(padding: const EdgeInsets.only(bottom: 16),
        child: GelPanel(radius: 20, padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded), const SizedBox(width: 12),
            Expanded(child: Text(music.error!, style: Theme.of(context).textTheme.bodyMedium)),
            IconButton(tooltip: 'Dismiss message', constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: music.clearError, icon: const Icon(Icons.close_rounded)),
          ]),
        ));
}

class MusicEmpty extends StatelessWidget {
  const MusicEmpty({super.key, required this.title, required this.message,
    this.action, this.actionLabel, this.icon = Icons.library_music_rounded});
  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;
  final IconData icon;
  @override
  Widget build(BuildContext context) => GelPanel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Asset3D.boxed(asset: Geode3DAsset.crystalFern, width: 80, height: 80, fallback: Image.asset('assets/images/crystal-fern.png', width: 80, height: 80,
          fit: BoxFit.contain, excludeFromSemantics: true)),
        const SizedBox(width: 12), Icon(icon, color: GeodeTokens.accent, size: 28),
      ]),
      const SizedBox(height: 18),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Text(message, style: Theme.of(context).textTheme.bodyLarge),
      if (action != null) ...[
        const SizedBox(height: 20),
        GelButton(label: actionLabel ?? 'Continue', icon: Icons.add_rounded, onPressed: action),
      ],
    ],
  ));
}

class MusicPage extends StatelessWidget {
  const MusicPage({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis), backgroundColor: const Color(0x8614273A),
      surfaceTintColor: Colors.transparent, actions: actions),
    body: Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x4D061B22), Color(0xB5061B22)]))),
      SafeArea(child: child),
    ]),
  );
}

Future<String?> musicNameDialog(BuildContext context, {required String title,
  String initial = '', String label = 'Name', String action = 'Save'}) =>
  showDialog<String>(context: context, builder: (_) => _MusicNameDialog(
    title: title, initial: initial, label: label, action: action));

class _MusicNameDialog extends StatefulWidget {
  const _MusicNameDialog({required this.title, required this.initial,
    required this.label, required this.action});
  final String title, initial, label, action;
  @override
  State<_MusicNameDialog> createState() => _MusicNameDialogState();
}

class _MusicNameDialogState extends State<_MusicNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true,
    title: Text(widget.title), content: TextField(controller: _controller,
      autofocus: true, maxLength: 80, textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (_) => setState(() {}), onSubmitted: (_) => _save()),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _controller.text.trim().isEmpty ? null : _save,
        child: Text(widget.action))]);
}

Future<bool> confirmMusicAction(BuildContext context, {required String title,
  required String message, String action = 'Remove'}) async =>
  await showDialog<bool>(context: context, builder: (context) => AlertDialog(scrollable: true,
    title: Text(title), content: Text(message), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
    ])) ?? false;
