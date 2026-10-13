import 'package:flutter/material.dart';
import 'studio_controller.dart';
import 'studio_dialogs.dart';

class KeyframeEditor extends StatelessWidget {
  const KeyframeEditor({super.key, required this.studio, required this.pausePreview});
  final StudioController studio;
  final VoidCallback pausePreview;
  @override
  Widget build(BuildContext context) {
    final project = studio.selectedProject!;
    final keys = [...project.keys]..sort((a, b) => a.atMs.compareTo(b.atMs));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Animate the atmosphere', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Project keyframes · linear interpolation', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: ['energy', 'opacity'].map((parameter) => OutlinedButton.icon(
        icon: const Icon(Icons.diamond_outlined, size: 16),
        label: Text(parameter == 'energy' ? 'Motion energy' : 'Material opacity'),
        onPressed: () {
          pausePreview();
          showDialog<void>(context: context, builder: (_) => _KeyDialog(studio: studio, parameter: parameter));
        },
      )).toList()),
      const SizedBox(height: 10),
      if (keys.isEmpty) Text('Move the playhead, then add a value. Two keys create a gradual change.',
        style: Theme.of(context).textTheme.bodySmall),
      Wrap(spacing: 8, runSpacing: 8, children: keys.map((key) => InputChip(
        label: Text('${key.parameter} ${(key.value * 100).round()}% · ${studioTime(key.atMs)}'),
        onPressed: () { pausePreview(); studio.setPlayhead(key.atMs);
          showDialog<void>(context: context, builder: (_) => _KeyDialog(studio: studio, parameter: key.parameter)); },
        onDeleted: () => studio.deleteKey(key.id), deleteButtonTooltipMessage: 'Delete keyframe',
      )).toList()),
    ]);
  }
}

class _KeyDialog extends StatefulWidget {
  const _KeyDialog({required this.studio, required this.parameter});
  final StudioController studio;
  final String parameter;
  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  late double value = widget.studio.selectedProject!.evaluate(widget.parameter,
    widget.studio.playheadMs, fallback: widget.parameter == 'energy' ? .4 : 1);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.parameter == 'energy' ? 'Motion energy' : 'Material opacity'} keyframe'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('At ${studioTime(widget.studio.playheadMs)} · ${(value * 100).round()}%'),
      Slider(value: value.clamp(0.0, 1.0).toDouble(), divisions: 100,
        label: '${(value * 100).round()}%', onChanged: (next) => setState(() => value = next)),
      const Text('Before the first key and after the last, the value holds steady.'),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () { widget.studio.addKey(widget.parameter, value);
        Navigator.pop(context); }, child: const Text('Save keyframe')),
    ],
  );
}
