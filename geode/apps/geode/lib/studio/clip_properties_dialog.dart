import 'package:flutter/material.dart';
import 'studio_controller.dart';
import 'studio_models.dart';

class ClipPropertiesDialog extends StatefulWidget {
  const ClipPropertiesDialog({super.key, required this.studio, required this.clip});
  final StudioController studio;
  final StudioClip clip;
  @override
  State<ClipPropertiesDialog> createState() => _ClipPropertiesDialogState();
}

class _ClipPropertiesDialogState extends State<ClipPropertiesDialog> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.clip.label);
  late final _start = TextEditingController(text: (widget.clip.startMs / 1000).toStringAsFixed(3));
  late final _duration = TextEditingController(text: (widget.clip.durationMs / 1000).toStringAsFixed(3));
  late final _source = TextEditingController(text: (widget.clip.sourceInMs / 1000).toStringAsFixed(3));
  @override
  void dispose() {
    for (final controller in [_label, _start, _duration, _source]) { controller.dispose(); }
    super.dispose();
  }
  String? _number(String? value, {double minimum = 0}) {
    final n = double.tryParse(value ?? '');
    return n == null || !n.isFinite || n < minimum || n > 86400
      ? 'Enter seconds from $minimum to 86400.' : null;
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Clip details'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _label, maxLength: widget.clip.lane == 'text' ? 240 : 80,
          maxLines: widget.clip.lane == 'text' ? 3 : 1,
          decoration: InputDecoration(labelText: widget.clip.lane == 'text' ? 'On-screen text' : 'Label'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Enter a label.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _start, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Start · seconds'), validator: _number),
        const SizedBox(height: 12),
        TextFormField(controller: _duration, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Duration · seconds'),
          validator: (value) => _number(value, minimum: .033)),
        const SizedBox(height: 12),
        TextFormField(controller: _source, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Source in-point · seconds'), validator: _number),
        const SizedBox(height: 12),
        const Text('Trims keep source timing. Start moves the entire clip; duration changes its end.'),
      ])))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        widget.studio.updateClip(label: _label.text,
          startMs: (double.parse(_start.text) * 1000).round(),
          durationMs: (double.parse(_duration.text) * 1000).round(),
          sourceInMs: (double.parse(_source.text) * 1000).round());
        Navigator.pop(context);
      }, child: const Text('Apply')),
    ],
  );
}
