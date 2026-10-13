import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../components/components.dart';
import 'studio_controller.dart';
import 'studio_dialogs.dart';

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.studio});
  final StudioController studio;
  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final _form = GlobalKey<FormState>();
  late String _quality, _ratio, _codec, _loudness;
  late int _fps;
  late final TextEditingController _start, _end;
  bool _busy = false;
  static const _qualities = ['720p', '1080p', '4K'];
  static const _ratios = ['16:9', '9:16', '1:1', '4:5', '4:3', '21:9'];
  static const _codecs = ['h264', 'hevc'];
  static const _targets = ['as-is', 'youtube', 'shorts'];
  static const _frames = [24, 25, 30, 50, 60];

  @override
  void initState() {
    super.initState();
    final project = widget.studio.selectedProject!;
    final settings = project.exportSettings;
    _quality = _qualities.contains(settings['quality']) ? settings['quality'] as String : '1080p';
    _ratio = _ratios.contains(settings['ratio']) ? settings['ratio'] as String : '16:9';
    _codec = _codecs.contains(settings['codec']) ? settings['codec'] as String : 'h264';
    _loudness = _targets.contains(settings['loudness']) ? settings['loudness'] as String : 'as-is';
    _fps = _frames.contains(settings['fps']) ? (settings['fps'] as num).toInt() : 30;
    final startValue = settings['rangeStartMs'];
    final endValue = settings['rangeEndMs'];
    final start = startValue is num && startValue.isFinite ? startValue.toInt().clamp(0, project.durationMs - 1000) : 0;
    final end = endValue is num && endValue.isFinite ? endValue.toInt().clamp(start + 1000, project.durationMs) : project.durationMs;
    _start = TextEditingController(text: (start / 1000).toStringAsFixed(3));
    _end = TextEditingController(text: (end / 1000).toStringAsFixed(3));
  }

  @override
  void dispose() { _start.dispose(); _end.dispose(); super.dispose(); }

  String? _validSeconds(String? value) {
    final number = double.tryParse(value ?? '');
    if (number == null || !number.isFinite || number < 0 ||
      number > widget.studio.selectedProject!.durationMs / 1000) return 'Enter a time within the project.';
    return null;
  }

  bool _saveSettings() {
    if (!_form.currentState!.validate()) return false;
    final start = (double.parse(_start.text) * 1000).round();
    final end = (double.parse(_end.text) * 1000).round();
    if (end - start < 1000) {
      studioMessage(context, 'Choose an export range of at least one second.'); return false;
    }
    final shortEdge = _quality == '720p' ? 720 : _quality == '4K' ? 2160 : 1080;
    final parts = _ratio.split(':').map(int.parse).toList();
    final landscape = parts[0] >= parts[1];
    final width = landscape ? (shortEdge * parts[0] / parts[1] / 2).round() * 2 : shortEdge;
    final height = landscape ? shortEdge : (shortEdge * parts[1] / parts[0] / 2).round() * 2;
    widget.studio.saveExport({'quality': _quality, 'ratio': _ratio, 'codec': _codec,
      'fps': _fps, 'loudness': _loudness, 'rangeStartMs': start, 'rangeEndMs': end,
      'width': width, 'height': height, 'format': 'mp4',
      'bitrateMbps': _quality == '720p' ? 6 : _quality == '4K' ? 40 : 12});
    return widget.studio.error == null;
  }

  Future<void> _save() async {
    if (!_saveSettings()) return;
    setState(() => _busy = true);
    await widget.studio.flush();
    if (!mounted) return;
    setState(() => _busy = false);
    studioMessage(context, widget.studio.error ?? 'Export settings saved on this device.');
  }

  Future<void> _export() async {
    if (!_saveSettings()) return;
    setState(() => _busy = true);
    try {
      final project = widget.studio.selectedProject!;
      final name = project.name.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim();
      final saved = await FilePicker.saveFile(
        fileName: '${name.isEmpty ? 'geode-project' : name}.geode-ui.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ')
          .convert(widget.studio.projectJson()))),
      );
      if (mounted && saved != null) studioMessage(context, 'Project JSON exported.');
    } catch (error) {
      if (mounted) studioMessage(context, 'Could not export project: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choice(String label, String value, List<String> values, ValueChanged<String> onChanged,
    {String Function(String)? display}) => DropdownButtonFormField<String>(
      initialValue: value, decoration: InputDecoration(labelText: label), isExpanded: true,
      items: values.map((option) => DropdownMenuItem(value: option,
        child: Text(display?.call(option) ?? option))).toList(),
      onChanged: _busy ? null : (value) => setState(() => onChanged(value!)));

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(height: MediaQuery.sizeOf(context).height * .9,
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
          child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text('Prepare your film', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(tooltip: 'Close export settings', onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded))]),
            const SizedBox(height: 8),
            const Text('Set the delivery format and keep a portable copy of your timeline.'),
            const SizedBox(height: 24),
            _choice('Quality', _quality, _qualities, (value) => _quality = value,
              display: (value) => '$value · ${value == '720p' ? 6 : value == '4K' ? 40 : 12} Mbps'),
            const SizedBox(height: 18),
            _choice('Canvas ratio', _ratio, _ratios, (value) => _ratio = value),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(initialValue: _fps, decoration: const InputDecoration(labelText: 'Frame rate'),
              items: _frames.map((value) => DropdownMenuItem(value: value, child: Text('$value fps'))).toList(),
              onChanged: _busy ? null : (value) => setState(() => _fps = value!)),
            const SizedBox(height: 18),
            _choice('Codec', _codec, _codecs, (value) => _codec = value,
              display: (value) => value == 'h264' ? 'H.264 · broad compatibility' : 'HEVC · smaller files'),
            const SizedBox(height: 18),
            _choice('Audio loudness', _loudness, _targets, (value) => _loudness = value,
              display: (value) => value == 'as-is' ? 'Keep original levels' : value == 'youtube' ? 'YouTube target' : 'Short-form target'),
            const SizedBox(height: 18),
            TextFormField(controller: _start, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Range start · seconds'), validator: _validSeconds),
            const SizedBox(height: 18),
            TextFormField(controller: _end, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Range end · seconds'), validator: _validSeconds),
            const SizedBox(height: 10),
            TextButton.icon(onPressed: _busy ? null : () => setState(() {
              _start.text = '0.000';
              _end.text = (widget.studio.selectedProject!.durationMs / 1000).toStringAsFixed(3);
            }), icon: const Icon(Icons.select_all_rounded), label: const Text('Use entire timeline')),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, children: [
              GelButton(label: 'Save settings', icon: Icons.check_rounded, onPressed: _busy ? null : _save),
              GelButton(label: 'Export project JSON', primary: false, icon: Icons.download_rounded,
                onPressed: _busy ? null : _export),
            ]),
            const SizedBox(height: 20),
            const GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Video rendering is not connected', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('This Flutter UI can save your timeline and export a Geode UI project JSON. The native video renderer and media compositor are not bound to this app yet.'),
              SizedBox(height: 12),
              FilledButton(onPressed: null, child: Text('Render video')),
            ])),
            const SizedBox(height: 14),
            Text('JSON files contain editing data and file references, not media. This format is separate from native .geode templates.',
              style: Theme.of(context).textTheme.bodySmall),
          ])),
        ))),
    ),
  );
}
