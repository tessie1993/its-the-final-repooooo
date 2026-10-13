part of 'studio_controller.dart';

mixin _StudioEditing on ChangeNotifier {
  StudioProject? get selectedProject;
  StudioClip? get selectedClip;
  String? get selectedClipId;
  int get playheadMs;
  String _id();
  void _commit(StudioProject project);
  void _fail(String message);
  void selectClip(String? id);

  bool laneMuted(String lane) => selectedProject?.lanes[lane]?['muted'] == true;
  bool laneLocked(String lane) => selectedProject?.lanes[lane]?['locked'] == true;
  bool _canEdit(String lane) {
    if (!studioLanes.contains(lane)) return false;
    if (laneLocked(lane)) {
      _fail('Unlock the $lane lane to edit its clips.');
      return false;
    }
    return true;
  }

  void addClip(String lane, {required String label, int materialIndex = 0,
      String? source, int sourceDurationMs = 0}) {
    final project = selectedProject;
    if (project == null || !_canEdit(lane)) return;
    if (sourceDurationMs > 0 && sourceDurationMs < 33) {
      _fail('Media must be at least 33 milliseconds long.');
      return;
    }
    final clip = StudioClip(id: _id(), lane: lane,
      label: label.trim().isEmpty ? 'Untitled clip' : label.trim(), startMs: playheadMs,
      materialIndex: materialIndex.clamp(0, 2).toInt(), source: source,
      sourceDurationMs: math.max(0, sourceDurationMs),
      durationMs: sourceDurationMs > 0 ? math.min(4000, sourceDurationMs) : 4000);
    _commit(project.copyWith(clips: [...project.clips, clip]));
    selectClip(clip.id);
  }

  void updateClip({String? label, int? startMs, int? durationMs,
      int? sourceInMs, int? materialIndex, bool? enabled}) {
    final clip = selectedClip;
    if (clip == null || !_canEdit(clip.lane)) return;
    var sourceIn = math.max(0, sourceInMs ?? clip.sourceInMs);
    if (clip.sourceDurationMs > 0) {
      sourceIn = math.min(sourceIn, clip.sourceDurationMs - 33);
    }
    var duration = math.max(33, durationMs ?? clip.durationMs);
    if (clip.sourceDurationMs > 0) duration = math.min(duration, clip.sourceDurationMs - sourceIn);
    final transition = {...clip.transition,
      'type': duration < 100 ? 'none' : clip.transition['type'],
      'durationMs': duration < 100 ? 0 : math.min((clip.transition['durationMs'] as int?) ?? 0, duration)};
    _replaceClip(clip.copyWith(label: label?.trim().isNotEmpty == true ? label!.trim() : null,
      startMs: math.max(0, startMs ?? clip.startMs), durationMs: duration,
      sourceInMs: sourceIn, materialIndex: materialIndex?.clamp(0, 2).toInt(),
      enabled: enabled, transition: transition));
  }

  void _replaceClip(StudioClip replacement) {
    final project = selectedProject;
    if (project == null) return;
    _commit(project.copyWith(clips: project.clips.map((clip) =>
      clip.id == replacement.id ? replacement : clip).toList()));
  }

  void trimStart() {
    final clip = selectedClip;
    if (clip == null || !_canEdit(clip.lane)) return;
    final amount = playheadMs - clip.startMs;
    if (amount <= 0 || amount > clip.durationMs - 33) {
      _fail('Place the playhead inside the clip, leaving at least 33 ms.');
      return;
    }
    updateClip(startMs: playheadMs, durationMs: clip.durationMs - amount,
      sourceInMs: clip.sourceInMs + amount);
  }

  void trimEnd() {
    final clip = selectedClip;
    if (clip == null || !_canEdit(clip.lane)) return;
    final duration = playheadMs - clip.startMs;
    if (duration < 33 || duration >= clip.durationMs) {
      _fail('Place the playhead inside the clip, leaving at least 33 ms.');
      return;
    }
    updateClip(durationMs: duration);
  }

  void splitClip() {
    final clip = selectedClip, project = selectedProject;
    if (clip == null || project == null || !_canEdit(clip.lane)) return;
    final firstDuration = playheadMs - clip.startMs;
    if (firstDuration < 33 || clip.durationMs - firstDuration < 33) {
      _fail('Each side of a split must be at least 33 milliseconds.');
      return;
    }
    final first = clip.copyWith(durationMs: firstDuration, transition: {...clip.transition,
      'type': firstDuration < 100 ? 'none' : clip.transition['type'],
      'durationMs': firstDuration < 100 ? 0 : math.min((clip.transition['durationMs'] as int?) ?? 0, firstDuration)});
    final second = clip.copyWith(id: _id(), label: '${clip.label} · 2',
      startMs: playheadMs, durationMs: clip.durationMs - firstDuration,
      sourceInMs: clip.sourceInMs + firstDuration,
      transition: {...clip.transition, 'type': 'none', 'durationMs': 0});
    _commit(project.copyWith(clips: [for (final item in project.clips)
      if (item.id == clip.id) ...[first, second] else item]));
    selectClip(second.id);
  }

  void duplicateClip() {
    final clip = selectedClip, project = selectedProject;
    if (clip == null || project == null || !_canEdit(clip.lane)) return;
    final copy = clip.copyWith(id: _id(), label: '${clip.label} copy', startMs: clip.endMs);
    _commit(project.copyWith(clips: [...project.clips, copy]));
    selectClip(copy.id);
  }

  void deleteClip() {
    final clip = selectedClip, project = selectedProject;
    if (clip == null || project == null || !_canEdit(clip.lane)) return;
    _commit(project.copyWith(clips: project.clips.where((item) => item.id != clip.id).toList()));
  }

  void toggleLaneMute(String lane) => _toggleLane(lane, 'muted');
  void toggleLaneLock(String lane) => _toggleLane(lane, 'locked');
  void _toggleLane(String lane, String property) {
    final project = selectedProject;
    if (project == null || !studioLanes.contains(lane)) return;
    final state = Map<String, dynamic>.from(project.lanes[lane] as Map? ?? {});
    state[property] = state[property] != true;
    _commit(project.copyWith(lanes: {...project.lanes, lane: state}));
  }

  void addMarker(String name) {
    final project = selectedProject;
    if (project == null) return;
    _commit(project.copyWith(markers: [...project.markers, StudioMarker(id: _id(),
      name: name.trim().isEmpty ? 'Marker' : name.trim(), atMs: playheadMs)]));
  }

  void deleteMarker(String id) {
    final project = selectedProject;
    if (project != null) _commit(project.copyWith(markers:
      project.markers.where((marker) => marker.id != id).toList()));
  }

  void setTransition(String type, int durationMs) {
    final clip = selectedClip;
    if (clip == null || !_canEdit(clip.lane)) return;
    if (!studioTransitions.contains(type)) {
      _fail('Choose a supported transition.');
      return;
    }
    if (type != 'none' && clip.durationMs < 100) {
      _fail('A transition requires a clip at least 100 milliseconds long.');
      return;
    }
    _replaceClip(clip.copyWith(transition: {...clip.transition, 'type': type,
      'durationMs': type == 'none' ? 0 : durationMs.clamp(100, math.min(5000, clip.durationMs)).toInt()}));
  }

  void addKey(String parameter, double value) {
    final project = selectedProject;
    if (project == null || !['opacity', 'energy'].contains(parameter) || !value.isFinite) return;
    final old = project.keys.where((key) => key.parameter == parameter && key.atMs == playheadMs).firstOrNull;
    final key = StudioKey(id: old?.id ?? _id(), parameter: parameter,
      atMs: playheadMs, value: value.clamp(0, 1).toDouble(), extras: old?.extras ?? {});
    _commit(project.copyWith(keys: [...project.keys.where((item) => item.id != old?.id), key]));
  }

  void deleteKey(String id) {
    final project = selectedProject;
    if (project != null) _commit(project.copyWith(keys:
      project.keys.where((key) => key.id != id).toList()));
  }

  void saveExport(Map<String, dynamic> settings) {
    final project = selectedProject;
    if (project != null) _commit(project.copyWith(exportSettings:
      {...project.exportSettings, ...settings}));
  }
}
