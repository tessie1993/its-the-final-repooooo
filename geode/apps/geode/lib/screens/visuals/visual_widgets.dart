import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../scene/gel_float.dart';
import '../../state/geode_app_state.dart';
import '../../theme/geode_theme.dart';

Future<T?> openVisualPage<T>(BuildContext context, Widget child) =>
  Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    pageBuilder: (_, animation, secondaryAnimation) => child,
    transitionsBuilder: (_, animation, secondaryAnimation, page) =>
      FadeTransition(opacity: animation, child: page),
    transitionDuration: const Duration(milliseconds: 220),
  ));

class VisualPageShell extends StatelessWidget {
  const VisualPageShell({super.key, required this.title, required this.subtitle,
    required this.child, this.actions = const []});
  final String title, subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xB8061B22),
    body: SafeArea(child: Column(children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
          child: Row(children: [
            GelIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back to visuals',
              onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ])),
            ...actions,
          ])))),
      Expanded(child: child),
    ])),
  );
}

class VisualFloat extends StatelessWidget {
  const VisualFloat({super.key, required this.state, required this.child,
    this.phase = 0, this.anchor = const Offset(.5, .5)});
  final GeodeAppState state;
  final Widget child;
  final double phase;
  final Offset anchor;
  @override
  Widget build(BuildContext context) => GelFloat(controller: state.scene,
    anchor: anchor, weight: 1.8, phase: phase, child: child);
}

class VisualEyebrow extends StatelessWidget {
  const VisualEyebrow(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GeodeTokens.accent));
}

Future<String?> askLookName(BuildContext context, {String? initialName,
  String title = 'Name your little world', String action = 'Save look'}) =>
  showDialog<String>(context: context, builder: (_) =>
    _LookNameDialog(initialName: initialName, title: title, action: action));

Future<void> saveCurrentLook(BuildContext context, GeodeAppState state) async {
  final name = await askLookName(context);
  if (name == null || !context.mounted) return;
  state.saveLook(name);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('“$name” added to your saved looks.')));
}

class _LookNameDialog extends StatefulWidget {
  const _LookNameDialog({required this.initialName, required this.title, required this.action});
  final String? initialName;
  final String title, action;
  @override
  State<_LookNameDialog> createState() => _LookNameDialogState();
}

class _LookNameDialogState extends State<_LookNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: GeodeTokens.deep,
    title: Text(widget.title),
    content: SizedBox(width: 360, child: TextField(
      controller: _controller, autofocus: true, maxLength: 64,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Look name', hintText: 'A quiet morning'),
      onSubmitted: (name) { if (name.trim().isNotEmpty) Navigator.pop(context, name.trim()); },
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ValueListenableBuilder<TextEditingValue>(valueListenable: _controller,
        builder: (context, value, _) => FilledButton(
          onPressed: value.text.trim().isEmpty ? null
            : () => Navigator.pop(context, value.text.trim()),
          child: Text(widget.action))),
    ],
  );
}
