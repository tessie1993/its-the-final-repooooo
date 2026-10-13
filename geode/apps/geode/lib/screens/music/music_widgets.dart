import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../media/music_controller.dart';
import '../../theme/geode_theme.dart';

String formatMusicTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 999999);
  final minutes = seconds ~/ 60;
  return '${minutes.toString().padLeft(1, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class MusicArtwork extends StatelessWidget {
  const MusicArtwork({super.key, this.size = 64, this.radius = 22});
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Geode fern artwork', image: true,
    child: ClipRRect(borderRadius: BorderRadius.circular(radius),
      child: Container(width: size, height: size, color: const Color(0xFF153831),
        child: Image.asset('assets/images/fern-dew.png', fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, error, stack) => const Icon(Icons.music_note_rounded)),
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
        Image.asset('assets/images/crystal-fern.png', width: 80, height: 80,
          fit: BoxFit.contain, excludeFromSemantics: true),
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
    backgroundColor: Colors.transparent, extendBodyBehindAppBar: true,
    appBar: AppBar(title: Text(title), backgroundColor: const Color(0x99061B22),
      surfaceTintColor: Colors.transparent, actions: actions),
    body: Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xA3061B22), Color(0xE6061B22)]))),
      SafeArea(child: child),
    ]),
  );
}

Future<String?> musicNameDialog(BuildContext context, {required String title,
  String initial = '', String label = 'Name', String action = 'Save'}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(context: context, builder: (context) =>
    AlertDialog(title: Text(title), content: TextField(controller: controller,
      autofocus: true, maxLength: 80, textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
      onSubmitted: (value) { if (value.trim().isNotEmpty) Navigator.pop(context, value.trim()); }),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(context, controller.text.trim()); },
          child: Text(action))]));
  controller.dispose();
  return result;
}

Future<bool> confirmMusicAction(BuildContext context, {required String title,
  required String message, String action = 'Remove'}) async =>
  await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(title), content: Text(message), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
    ])) ?? false;
