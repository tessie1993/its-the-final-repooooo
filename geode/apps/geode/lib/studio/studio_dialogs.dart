import 'package:flutter/material.dart';

String studioTime(int ms) {
  final seconds = ms ~/ 1000;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}.'
      '${((ms % 1000) ~/ 10).toString().padLeft(2, '0')}';
}

Future<String?> studioName(BuildContext context, String title,
  {String initial = '', String label = 'Name'}) => showDialog<String>(
  context: context, builder: (_) => _NameDialog(title, initial, label));

Future<bool> studioConfirm(BuildContext context, String title, String body) async =>
  await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(title), content: Text(body), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
    ],
  )) ?? false;

void studioMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _NameDialog extends StatefulWidget {
  const _NameDialog(this.title, this.initial, this.label);
  final String title, initial, label;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: controller, autofocus: true, maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (_) => setState(() {}),
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
      }),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: controller.text.trim().isEmpty ? null
        : () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
    ],
  );
}
