import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geode_export/geode_export.dart';
import 'package:just_audio/just_audio.dart';

import '../components/components.dart';
import 'studio_models.dart';

/// The same native compositor supplies preview frames and exported video frames.
class StudioPreview extends StatefulWidget {
  const StudioPreview({super.key, required this.project, required this.atMs,
    required this.playing, required this.deviceServices});
  final StudioProject project;
  final int atMs;
  final bool playing, deviceServices;

  @override
  State<StudioPreview> createState() => _StudioPreviewState();
}

class _StudioPreviewState extends State<StudioPreview> {
  final _service = GeodeExport.instance;
  final _audio = _TimelineAudio();
  Uint8List? _image;
  String? _error;
  bool _rendering = false, _again = false;
  late String _projectKey;
  bool get _native => widget.deviceServices && _service.supported;

  @override
  void initState() {
    super.initState();
    _projectKey = jsonEncode(widget.project.toJson());
    _refresh();
  }

  @override
  void didUpdateWidget(StudioPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.project, widget.project)) {
      _projectKey = jsonEncode(widget.project.toJson());
      _error = null;
    }
    _refresh();
  }

  void _refresh() {
    if (!_native) return;
    _audio.sync(widget.project, widget.atMs, widget.playing, (message) {
      if (mounted) setState(() => _error = message);
    });
    if (_rendering) { _again = true; return; }
    unawaited(_render());
  }

  Future<void> _render() async {
    _rendering = true;
    try {
      do {
        _again = false;
        final image = await _service.preview(widget.project.toJson(), _projectKey, widget.atMs);
        if (!mounted) return;
        if (image != null) setState(() { _image = image; _error = null; });
      } while (_again && mounted);
    } catch (error) {
      if (mounted) setState(() => _error = 'Preview could not load: $error');
    } finally { _rendering = false; }
  }

  @override
  void dispose() {
    _audio.dispose();
    if (_native) unawaited(_service.closePreview().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = widget.project.clips.where((clip) => clip.lane == 'visual' && clip.enabled &&
      clip.startMs <= widget.atMs && widget.atMs < clip.endMs).toList();
    return ClipRRect(borderRadius: BorderRadius.circular(22), child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(fit: StackFit.expand, children: [
        if (_image != null) Image.memory(_image!, fit: BoxFit.contain, gaplessPlayback: true)
        else SceneThumbnail(materialIndex: visuals.lastOrNull?.materialIndex ?? 0, height: 270),
        if (_native && _image == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_error != null) ColoredBox(color: const Color(0xDB17251B), child: Center(
          child: Padding(padding: const EdgeInsets.all(18), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center, maxLines: 4),
              TextButton(onPressed: () { setState(() => _error = null); _refresh(); }, child: const Text('Retry preview')),
            ])))),
        Positioned(left: 12, top: 12, child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0xDB17251B), borderRadius: BorderRadius.circular(10)),
          child: Padding(padding: const EdgeInsets.all(8), child: Text(
            _native ? 'LIVE COMPOSITION' : 'MATERIAL PREVIEW', style: Theme.of(context).textTheme.labelSmall)))),
      ]),
    ));
  }
}

/// Serializes seeks and source loads so scrubbing cannot resurrect stale audio.
class _TimelineAudio {
  final Map<String, AudioPlayer> _players = {};
  StudioProject? _project;
  int _atMs = 0;
  bool _playing = false, _busy = false, _pending = false, _disposed = false;
  void Function(String)? _onError;

  void sync(StudioProject project, int atMs, bool playing, void Function(String) onError) {
    _project = project; _atMs = atMs; _playing = playing; _onError = onError;
    if (_busy) { _pending = true; return; }
    unawaited(_update());
  }

  Future<void> _update() async {
    _busy = true;
    try {
      do {
        _pending = false;
        final project = _project!;
        final active = project.clips.where((clip) => clip.lane == 'audio' && clip.enabled &&
          project.lanes['audio']?['muted'] != true && clip.source != null &&
          clip.startMs <= _atMs && _atMs < clip.endMs).toList();
        for (final id in _players.keys.toList()) {
          if (!active.any((clip) => clip.id == id)) await _players.remove(id)!.dispose();
        }
        if (_disposed) return;
        for (final clip in active) {
          var player = _players[clip.id];
          if (player == null) {
            player = AudioPlayer(handleAudioSessionActivation: false, handleInterruptions: false);
            _players[clip.id] = player;
            await player.setAudioSource(AudioSource.uri(Uri.parse(clip.source!)));
          }
          if (_disposed) return;
          final target = Duration(milliseconds: clip.sourceInMs + _atMs - clip.startMs);
          if (!_playing || (player.position - target).inMilliseconds.abs() > 200) await player.seek(target);
          final transition = (clip.transition['durationMs'] as num?)?.toDouble() ?? 0;
          final volume = transition <= 0 ? 1.0 : ((_atMs - clip.startMs) / transition).clamp(0.0, 1.0);
          await player.setVolume(volume);
          if (_playing && !player.playing) unawaited(player.play().catchError((Object error) {
            if (!_disposed) _onError?.call('Soundtrack preview failed: $error');
          }));
          if (!_playing && player.playing) await player.pause();
        }
      } while (_pending && !_disposed);
    } catch (error) {
      if (!_disposed) _onError?.call('Soundtrack preview failed: $error');
    } finally {
      _busy = false;
      if (_disposed) { for (final player in _players.values) { unawaited(player.dispose()); } _players.clear(); }
    }
  }

  void dispose() {
    _disposed = true;
    for (final player in _players.values) { unawaited(player.pause()); }
    if (!_busy) { for (final player in _players.values) { unawaited(player.dispose()); } _players.clear(); }
  }
}
