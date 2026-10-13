import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'studio_models.dart';

part 'studio_actions.dart';

class StudioController extends ChangeNotifier with _StudioEditing {
  StudioController({SharedPreferencesAsync? preferences, this.enableDeviceServices = true})
      : _providedPreferences = preferences;
  final bool enableDeviceServices;
  final SharedPreferencesAsync? _providedPreferences;
  static const storageKey = 'geode.ui.projects.v1';
  late final SharedPreferencesAsync _preferences = _providedPreferences ?? SharedPreferencesAsync();
  final List<StudioProject> _projects = [];
  final Map<String, List<StudioProject>> _undo = {}, _redo = {};
  Map<String, dynamic> _storageExtras = {};
  String? _selectedProjectId, _selectedClipId, _error;
  int _playheadMs = 0, _sequence = 0;
  bool _initialized = false, _disposed = false, _loadedSuccessfully = false;
  Timer? _saveTimer;
  Future<void> _saveQueue = Future.value();
  Future<void>? _initialization;

  bool get initialized => _initialized;
  bool get storageReady => _loadedSuccessfully;
  String? get error => _error;
  List<StudioProject> get projects => List.unmodifiable(_projects);
  String? get selectedProjectId => _selectedProjectId;
  @override
  String? get selectedClipId => _selectedClipId;
  @override
  int get playheadMs => _playheadMs;
  @override
  StudioProject? get selectedProject =>
      _projects.where((project) => project.id == _selectedProjectId).firstOrNull;
  @override
  StudioClip? get selectedClip => selectedProject?.clips
      .where((clip) => clip.id == _selectedClipId).firstOrNull;
  bool get canUndo => (_undo[_selectedProjectId]?.isNotEmpty ?? false);
  bool get canRedo => (_redo[_selectedProjectId]?.isNotEmpty ?? false);

  Future<void> initialize() {
    if (_disposed) return Future.value();
    if (!enableDeviceServices) {
      _initialized = _loadedSuccessfully = true;
      notifyListeners();
      return Future.value();
    }
    if (_initialization != null) return _initialization!;
    if (_loadedSuccessfully) {
      _queueSave();
      return _saveQueue;
    }
    return _initialization = _load().whenComplete(() => _initialization = null);
  }

  Future<void> _load() async {
    try {
      final raw = await _preferences.getString(storageKey);
      if (_disposed) return;
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> || decoded['version'] != 1 ||
            decoded['projects'] is! List) {
          throw const FormatException('Saved studio data has an unsupported format.');
        }
        final loaded = (decoded['projects'] as List).map((item) =>
          StudioProject.fromJson(Map<String, dynamic>.from(item as Map))).toList();
        if (loaded.map((project) => project.id).toSet().length != loaded.length) {
          throw const FormatException('Saved projects contain duplicate IDs.');
        }
        _projects..clear()..addAll(loaded);
        _storageExtras = Map<String, dynamic>.from(decoded)
          ..removeWhere((key, _) => ['version', 'projects', 'selectedProjectId'].contains(key));
        final selected = decoded['selectedProjectId'];
        _selectedProjectId = selected == null ? null
            : loaded.any((project) => project.id == selected)
                ? selected as String : loaded.firstOrNull?.id;
      }
      _loadedSuccessfully = true;
      _error = null;
    } catch (failure) {
      _error = 'Could not restore studio projects: $failure';
    } finally {
      _initialized = true;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  bool _ready() {
    if (_disposed) return false;
    if (_loadedSuccessfully) return true;
    _fail(_error ?? 'Studio storage is not ready. Retry loading before editing.');
    return false;
  }

  StudioProject? createProject(String name) {
    if (!_ready()) return null;
    final project = StudioProject(id: _id(), name: _name(name, 'Untitled project'));
    _projects.add(project);
    _selectedProjectId = project.id;
    _selectedClipId = null;
    _playheadMs = 0;
    _changed();
    return project;
  }

  String _name(String value, String fallback) => value.trim().isEmpty
      ? fallback : value.trim().substring(0, math.min(value.trim().length, 120));

  void renameProject(String id, String name) {
    if (!_ready()) return;
    final project = _projects.where((item) => item.id == id).firstOrNull;
    if (project != null) _commit(project.copyWith(name: _name(name, project.name)));
  }

  void duplicateProject(String id) {
    if (!_ready()) return;
    final project = _projects.where((item) => item.id == id).firstOrNull;
    if (project == null) return;
    final copy = project.copyWith(id: _id(), name: '${project.name} copy');
    _projects.add(copy);
    selectProject(copy.id);
  }

  void deleteProject(String id) {
    if (!_ready()) return;
    _projects.removeWhere((project) => project.id == id);
    _undo.remove(id);
    _redo.remove(id);
    if (_selectedProjectId == id) {
      _selectedProjectId = _projects.firstOrNull?.id;
      _selectedClipId = null;
      _playheadMs = 0;
    }
    _changed();
  }

  void selectProject(String? id) {
    if (!_ready()) return;
    if (id != null && !_projects.any((project) => project.id == id)) return;
    _selectedProjectId = id;
    _selectedClipId = null;
    _playheadMs = 0;
    _changed();
  }

  @override
  void selectClip(String? id) {
    if (_disposed) return;
    if (id != null && !(selectedProject?.clips.any((clip) => clip.id == id) ?? false)) return;
    _selectedClipId = id;
    notifyListeners();
  }

  void setPlayhead(int milliseconds) {
    if (_disposed) return;
    final next = milliseconds.clamp(0, selectedProject?.durationMs ?? 0).toInt();
    if (_playheadMs == next) return;
    _playheadMs = next;
    notifyListeners();
  }

  @override
  void _commit(StudioProject project) {
    if (!_ready()) return;
    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index < 0 || jsonEncode(_projects[index].toJson()) == jsonEncode(project.toJson())) return;
    final history = _undo.putIfAbsent(project.id, () => []);
    history.add(_projects[index]);
    if (history.length > 40) history.removeAt(0);
    _redo[project.id] = [];
    _projects[index] = project;
    _repairSelection();
    _changed();
  }

  void undo() => _restore(_undo, _redo);
  void redo() => _restore(_redo, _undo);

  void _restore(Map<String, List<StudioProject>> from,
      Map<String, List<StudioProject>> to) {
    if (!_ready()) return;
    final project = selectedProject;
    final history = from[_selectedProjectId];
    if (project == null || history == null || history.isEmpty) return;
    to.putIfAbsent(project.id, () => []).add(project);
    _projects[_projects.indexOf(project)] = history.removeLast();
    _repairSelection();
    _changed();
  }

  void _repairSelection() {
    if (selectedClip == null) _selectedClipId = null;
    _playheadMs = _playheadMs.clamp(0, selectedProject?.durationMs ?? 0).toInt();
  }

  bool importProject(Map<String, dynamic> json) {
    if (!_ready()) return false;
    try {
      var project = StudioProject.fromJson(json);
      if (_projects.any((item) => item.id == project.id)) {
        project = project.copyWith(id: _id(), name: '${project.name} imported');
      }
      _projects.add(project);
      selectProject(project.id);
      return true;
    } catch (failure) {
      _fail('Could not import project: $failure');
      return false;
    }
  }

  Map<String, dynamic> projectJson() => selectedProject?.toJson() ?? {};

  @override
  void _fail(String message) {
    _error = message;
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    _error = null;
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    _error = null;
    if (!_disposed) notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _queueSave);
  }

  void _queueSave() {
    _saveTimer = null;
    if (!_loadedSuccessfully || !enableDeviceServices) return;
    final snapshot = jsonEncode({..._storageExtras, 'version': 1,
      'projects': _projects.map((project) => project.toJson()).toList(),
      'selectedProjectId': _selectedProjectId});
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _preferences.setString(storageKey, snapshot);
        if (_error?.startsWith('Project changes could not be saved:') ?? false) {
          _error = null;
          if (!_disposed) notifyListeners();
        }
      } catch (failure) {
        _fail('Project changes could not be saved: $failure');
      }
    });
  }

  Future<void> flush() {
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      _queueSave();
    }
    return _saveQueue;
  }

  @override
  void dispose() {
    _disposed = true;
    flush();
    super.dispose();
  }
}
