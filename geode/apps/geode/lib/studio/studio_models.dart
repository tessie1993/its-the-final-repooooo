const studioLanes = ['visual', 'media', 'text', 'overlay', 'audio'];
const studioTransitions = ['none', 'dissolve', 'fade', 'wipe'];
const studioExportDefaults = {'quality': '1080p', 'ratio': '16:9', 'fps': 30,
  'codec': 'h264', 'loudness': 'as-is', 'rangeStartMs': 0, 'rangeEndMs': 1000};

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected an object with string keys.');
  }
  return Map<String, dynamic>.from(value);
}

int _integer(Object? value, int fallback, {int minimum = 0}) {
  if (value == null) return fallback;
  if (value is! num || !value.isFinite || value != value.roundToDouble() ||
      value < minimum || value > 9007199254740991) {
    throw const FormatException('Invalid timeline number.');
  }
  return value.toInt();
}

String _string(Object? value, String fallback) {
  if (value == null) return fallback;
  if (value is! String) throw const FormatException('Expected text.');
  return value;
}

bool _boolean(Object? value, bool fallback) {
  if (value == null) return fallback;
  if (value is! bool) throw const FormatException('Expected true or false.');
  return value;
}

Map<String, dynamic> _extras(Map<String, dynamic> json, List<String> keys) =>
    Map<String, dynamic>.from(json)..removeWhere((key, _) => keys.contains(key));

List<T> _items<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  if (value == null) return [];
  if (value is! List) throw const FormatException('Expected a list.');
  return value.map((item) => decode(_map(item))).toList();
}

class StudioClip {
  const StudioClip({required this.id, required this.lane, required this.label,
    this.startMs = 0, this.durationMs = 4000, this.sourceInMs = 0,
    this.sourceDurationMs = 0, this.materialIndex = 0, this.enabled = true,
    this.source, this.transition = const {'type': 'none', 'durationMs': 0},
    this.extras = const {}});

  final String id, lane, label;
  final int startMs, durationMs, sourceInMs, sourceDurationMs, materialIndex;
  final bool enabled;
  final String? source;
  final Map<String, dynamic> transition, extras;
  int get endMs => startMs + durationMs;

  factory StudioClip.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id'], '');
    final lane = _string(json['lane'], 'visual');
    if (id.isEmpty || !studioLanes.contains(lane)) {
      throw const FormatException('Clip ID or lane is invalid.');
    }
    final duration = _integer(json['durationMs'], 4000, minimum: 33);
    final sourceIn = _integer(json['sourceInMs'], 0);
    final sourceDuration = _integer(json['sourceDurationMs'], 0);
    if (sourceDuration > 0 && sourceIn + duration > sourceDuration) {
      throw const FormatException('Clip extends beyond its source.');
    }
    final transition = json['transition'] == null
        ? <String, dynamic>{'type': 'none', 'durationMs': 0}
        : _map(json['transition']);
    final type = _string(transition['type'], 'none');
    final transitionMs = _integer(transition['durationMs'], 0);
    if (!studioTransitions.contains(type) || transitionMs > duration ||
        (type == 'none' && transitionMs != 0) ||
        (type != 'none' && (transitionMs < 100 || transitionMs > 5000))) {
      throw const FormatException('Clip transition is invalid.');
    }
    final material = _integer(json['materialIndex'], 0);
    if (material > 2) throw const FormatException('Unknown material.');
    return StudioClip(id: id, lane: lane, label: _string(json['label'], 'Untitled'),
      startMs: _integer(json['startMs'], 0), durationMs: duration,
      sourceInMs: sourceIn, sourceDurationMs: sourceDuration,
      materialIndex: material, enabled: _boolean(json['enabled'], true),
      source: json['source'] == null ? null : _string(json['source'], ''),
      transition: {...transition, 'type': type, 'durationMs': transitionMs},
      extras: _extras(json, ['id', 'lane', 'label', 'startMs', 'durationMs',
        'sourceInMs', 'sourceDurationMs', 'materialIndex', 'enabled', 'source',
        'transition']));
  }

  Map<String, dynamic> toJson() => {...extras, 'id': id, 'lane': lane,
    'label': label, 'startMs': startMs, 'durationMs': durationMs,
    'sourceInMs': sourceInMs, 'sourceDurationMs': sourceDurationMs,
    'materialIndex': materialIndex, 'enabled': enabled, 'source': source,
    'transition': {...transition}};

  StudioClip copyWith({String? id, String? label, int? startMs, int? durationMs,
    int? sourceInMs, int? materialIndex, bool? enabled,
    Map<String, dynamic>? transition}) => StudioClip.fromJson({...toJson(),
      if (id != null) 'id': id, if (label != null) 'label': label,
      if (startMs != null) 'startMs': startMs,
      if (durationMs != null) 'durationMs': durationMs,
      if (sourceInMs != null) 'sourceInMs': sourceInMs,
      if (materialIndex != null) 'materialIndex': materialIndex,
      if (enabled != null) 'enabled': enabled,
      if (transition != null) 'transition': transition});
}

class StudioMarker {
  const StudioMarker({required this.id, required this.name, required this.atMs,
    this.extras = const {}});
  final String id, name;
  final int atMs;
  final Map<String, dynamic> extras;
  factory StudioMarker.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id'], '');
    if (id.isEmpty) throw const FormatException('Marker ID is missing.');
    return StudioMarker(id: id, name: _string(json['name'], 'Marker'),
      atMs: _integer(json['atMs'], 0),
      extras: _extras(json, ['id', 'name', 'atMs']));
  }
  Map<String, dynamic> toJson() => {...extras, 'id': id, 'name': name, 'atMs': atMs};
}

class StudioKey {
  const StudioKey({required this.id, required this.parameter, required this.atMs,
    required this.value, this.extras = const {}});
  final String id, parameter;
  final int atMs;
  final double value;
  final Map<String, dynamic> extras;
  factory StudioKey.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id'], '');
    final parameter = _string(json['parameter'], '');
    final value = json['value'];
    if (id.isEmpty || !['opacity', 'energy'].contains(parameter) ||
        value is! num || !value.isFinite || value < 0 || value > 1) {
      throw const FormatException('Invalid opacity or energy keyframe.');
    }
    return StudioKey(id: id, parameter: parameter,
      atMs: _integer(json['atMs'], 0), value: value.toDouble(),
      extras: _extras(json, ['id', 'parameter', 'atMs', 'value']));
  }
  Map<String, dynamic> toJson() => {...extras, 'id': id, 'parameter': parameter,
    'atMs': atMs, 'value': value};
}

class StudioProject {
  const StudioProject({required this.id, required this.name, this.clips = const [],
    this.lanes = const {}, this.markers = const [], this.keys = const [],
    this.exportSettings = studioExportDefaults, this.extras = const {}});
  final String id, name;
  final List<StudioClip> clips;
  final Map<String, dynamic> lanes, exportSettings, extras;
  final List<StudioMarker> markers;
  final List<StudioKey> keys;
  int get durationMs => [1000, ...clips.map((clip) => clip.endMs),
    ...markers.map((marker) => marker.atMs), ...keys.map((key) => key.atMs)]
      .reduce((a, b) => a > b ? a : b);

  factory StudioProject.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'geode.ui.project' || json['version'] != 1) {
      throw const FormatException('Expected a Geode UI project, version 1.');
    }
    final id = _string(json['id'], '');
    final name = _string(json['name'], 'Untitled project');
    if (id.isEmpty || name.trim().isEmpty) {
      throw const FormatException('Project ID and name are required.');
    }
    final lanes = json['lanes'] == null ? <String, dynamic>{} : _map(json['lanes']);
    for (final lane in lanes.entries) {
      if (!studioLanes.contains(lane.key)) {
        throw const FormatException('Unknown timeline lane.');
      }
      final state = _map(lane.value);
      _boolean(state['muted'], false);
      _boolean(state['locked'], false);
    }
    final clips = _items(json['clips'], StudioClip.fromJson);
    final markers = _items(json['markers'], StudioMarker.fromJson);
    final keys = _items(json['keys'], StudioKey.fromJson);
    if (keys.map((key) => '${key.parameter}:${key.atMs}').toSet().length != keys.length) {
      throw const FormatException('Only one keyframe per parameter and time is allowed.');
    }
    for (final ids in [clips.map((item) => item.id), markers.map((item) => item.id),
      keys.map((item) => item.id)]) {
      if (ids.toSet().length != ids.length) {
        throw const FormatException('Duplicate timeline item IDs.');
      }
    }
    return StudioProject(id: id, name: name, clips: List.unmodifiable(clips),
      lanes: lanes, markers: List.unmodifiable(markers), keys: List.unmodifiable(keys),
      exportSettings: json['export'] == null ? studioExportDefaults : _map(json['export']),
      extras: _extras(json, ['format', 'version', 'id', 'name', 'clips', 'lanes',
        'markers', 'keys', 'export']));
  }

  Map<String, dynamic> toJson() => {...extras, 'format': 'geode.ui.project',
    'version': 1, 'id': id, 'name': name,
    'clips': clips.map((item) => item.toJson()).toList(), 'lanes': lanes,
    'markers': markers.map((item) => item.toJson()).toList(),
    'keys': keys.map((item) => item.toJson()).toList(), 'export': exportSettings};

  StudioProject copyWith({String? id, String? name, List<StudioClip>? clips,
    Map<String, dynamic>? lanes, List<StudioMarker>? markers,
    List<StudioKey>? keys, Map<String, dynamic>? exportSettings}) =>
      StudioProject.fromJson({...toJson(), if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (clips != null) 'clips': clips.map((item) => item.toJson()).toList(),
        if (lanes != null) 'lanes': lanes,
        if (markers != null) 'markers': markers.map((item) => item.toJson()).toList(),
        if (keys != null) 'keys': keys.map((item) => item.toJson()).toList(),
        if (exportSettings != null) 'export': exportSettings});

  double evaluate(String parameter, int atMs, {double fallback = 1}) {
    final points = keys.where((key) => key.parameter == parameter).toList()
      ..sort((a, b) => a.atMs.compareTo(b.atMs));
    if (points.isEmpty) return fallback;
    if (atMs <= points.first.atMs) return points.first.value;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (atMs <= b.atMs) {
        if (a.atMs == b.atMs) return b.value;
        return a.value + (b.value - a.value) * (atMs - a.atMs) / (b.atMs - a.atMs);
      }
    }
    return points.last.value;
  }
}
