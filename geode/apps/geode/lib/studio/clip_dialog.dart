import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../components/components.dart';
import 'studio_controller.dart';
import 'studio_timeline.dart';

class ClipDialog extends StatefulWidget {
  const ClipDialog({super.key, required this.studio});
  final StudioController studio;
  @override
  State<ClipDialog> createState() => _ClipDialogState();
}

class _ClipDialogState extends State<ClipDialog> {
  final _label = TextEditingController();
  String _lane = 'visual';
  String? _source, _error;
  int _material = 0;
  bool _picking = false;
  bool get _needsSource => ['media', 'overlay', 'audio'].contains(_lane);
  @override
  void dispose() { _label.dispose(); super.dispose(); }

  Future<void> _pick() async {
    setState(() { _picking = true; _error = null; });
    try {
      final file = await FilePicker.pickFile(type: FileType.custom,
        allowedExtensions: _lane == 'audio' ? ['mp3', 'm4a', 'wav', 'ogg', 'flac', 'aac']
          : ['mp4', 'mov', 'webm', 'png', 'jpg', 'jpeg', 'webp'],
        dialogTitle: 'Choose a $_lane reference');
      if (!mounted || file == null) return;
      setState(() { _source = file.uri.toString(); _label.text = file.name; });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open that file: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a moment'),
    content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: _lane, decoration: const InputDecoration(labelText: 'Lane'),
          items: List.generate(5, (i) => DropdownMenuItem(value: uiStudioLanes[i], child: Text(studioLaneNames[i]))),
          onChanged: _picking ? null : (value) => setState(() { _lane = value!; _source = null; _label.clear(); })),
        const SizedBox(height: 18),
        TextField(controller: _label, maxLength: _lane == 'text' ? 240 : 80,
          maxLines: _lane == 'text' ? 3 : 1,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: _lane == 'text' ? 'On-screen text' : 'Clip label')),
        if (_lane == 'visual') ...[
          const SizedBox(height: 8),
          GelMaterialPicker(selectedIndex: _material, onChanged: (value) => setState(() => _material = value)),
        ],
        if (_needsSource) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _picking ? null : _pick,
            icon: Icon(_source == null ? Icons.attach_file_rounded : Icons.check_rounded),
            label: Text(_picking ? 'Opening files…' : _source == null ? 'Choose file reference' : 'Change file')),
          const SizedBox(height: 8),
          const Text('The timeline stores this file reference. File contents are not embedded or played in this preview; you may need to select the file again on another device.'),
        ],
        if (widget.studio.laneLocked(_lane)) const Padding(padding: EdgeInsets.only(top: 12),
          child: Text('This lane is locked. Unlock it in the timeline to add clips.')),
        if (_error != null) Text(_error!),
      ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _label.text.trim().isEmpty || _picking ||
        widget.studio.laneLocked(_lane) || (_needsSource && _source == null) ? null : () {
          widget.studio.addClip(_lane, label: _label.text.trim(), materialIndex: _material, source: _source);
          Navigator.pop(context);
        }, child: const Text('Add to timeline')),
    ],
  );
}
