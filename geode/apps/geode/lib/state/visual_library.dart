import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nature_look.dart';

class VisualLibrary extends ChangeNotifier {
  VisualLibrary({this.enableDeviceServices = true})
    : _storageReady = !enableDeviceServices,
      _initialized = !enableDeviceServices;

  final bool enableDeviceServices;
  static const storageKey = 'geode.ui.looks.v1';
  static const _seed = [
    NatureLook(id: 'forest-glass', name: 'Forest sanctuary',
      description: 'Moss & fern · quiet ripples', material: 0, energy: .42),
    NatureLook(id: 'luminous-tide', name: 'Luminous tide',
      description: 'Glowing fungi · living gel · midnight pool', material: 0,
      energy: .55, hue: .5, luminescence: .9, particleDensity: .75),
    NatureLook(id: 'moonstone', name: 'Moonstone',
      description: 'River stone · slow drift', material: 1, energy: .25, hue: .72),
    NatureLook(id: 'silver-spring', name: 'Woodland current',
      description: 'Warm bark · flowing light', material: 2, energy: .68, hue: .4),
  ];
  final List<NatureLook> _looks = [..._seed];
  final Set<String> _favorites = {'forest-glass'};
  String _selectedLookId = 'forest-glass';
  SharedPreferences? _preferences;
  Future<void> _pendingWrite = Future<void>.value();
  bool _disposed = false;
  bool _initialized;
  bool _storageReady;
  Future<void>? _initialization;
  bool get initialized => _initialized;
  bool get storageReady => _storageReady;
  bool get loading => _initialization != null;
  String? persistenceError;

  List<NatureLook> get looks => List.unmodifiable(_looks);
  Set<String> get favorites => Set.unmodifiable(_favorites);
  String get selectedLookId => _selectedLookId;
  NatureLook get selectedLook => _looks.firstWhere(
    (look) => look.id == _selectedLookId, orElse: () => _looks.first);

  Future<void> initialize() {
    if (_disposed || _storageReady) return Future<void>.value();
    return _initialization ??= _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed) return;
      await preferences.reload();
      if (_disposed) return;
      final saved = preferences.getString(storageKey);
      final restored = <NatureLook>[..._seed];
      final restoredFavorites = <String>{'forest-glass'};
      var selected = 'forest-glass';
      if (saved != null) {
        final data = _decode(saved);
        final entries = (data['looks'] as List).map((value) {
          if (value is! Map) throw const FormatException('Invalid saved look.');
          return NatureLook.fromJson(Map<String, dynamic>.from(value));
        }).toList();
        if (entries.map((look) => look.id).toSet().length != entries.length) {
          throw const FormatException('Saved looks contain duplicate IDs.');
        }
        restored.addAll(entries.where((look) => look.saved &&
          !_seed.any((seed) => seed.id == look.id)));
        final favoriteIds = data['favorites'] ?? const <String>[];
        if (favoriteIds is! List || favoriteIds.any((id) => id is! String)) {
          throw const FormatException('Invalid saved favorites.');
        }
        restoredFavorites
          ..clear()
          ..addAll(favoriteIds.cast<String>().where((id) => restored.any((look) => look.id == id)));
        final storedSelection = data['selectedLookId'];
        if (storedSelection is String && restored.any((look) => look.id == storedSelection)) {
          selected = storedSelection;
        }
      }
      // Publish a fully validated snapshot once. A failed load never replaces
      // either the existing collection or the raw saved data.
      if (_disposed) return;
      _looks..clear()..addAll(restored);
      _favorites..clear()..addAll(restoredFavorites);
      _selectedLookId = selected;
      _preferences = preferences;
      _storageReady = true;
      persistenceError = null;
    } catch (_) {
      if (!_disposed) {
        _preferences = null;
        _storageReady = false;
        persistenceError = 'Saved looks could not be loaded. Retry loading before changing the collection. Existing saved data has not been changed.';
      }
    } finally {
      _initialization = null;
      if (!_disposed) { _initialized = true; notifyListeners(); }
    }
  }

  bool _canEdit() {
    if (_disposed) return false;
    if (_storageReady) return true;
    persistenceError ??= 'Look storage is not ready. Retry loading before saving changes.';
    notifyListeners();
    return false;
  }

  Future<void> flush() => _pendingWrite;

  void select(String id) {
    if (!_canEdit()) return;
    if (!_looks.any((look) => look.id == id)) return;
    _selectedLookId = id;
    _changed();
  }

  void toggleFavorite(String id) {
    if (!_canEdit()) return;
    if (!_looks.any((look) => look.id == id)) return;
    if (!_favorites.add(id)) _favorites.remove(id);
    _changed();
  }

  void save(NatureLook look) {
    if (!_canEdit()) return;
    // Built-in nature studies remain a stable starting point.
    if (_seed.any((seed) => seed.id == look.id)) return;
    final index = _looks.indexWhere((item) => item.id == look.id);
    if (index < 0 && !_canAdd(1)) return;
    final saved = look.copyWith(saved: true);
    if (index < 0) { _looks.add(saved); } else { _looks[index] = saved; }
    _selectedLookId = look.id;
    _favorites.add(look.id);
    _changed();
  }

  void rename(String id, String name) {
    if (!_canEdit()) return;
    final index = _looks.indexWhere((look) => look.id == id && look.saved);
    final clean = name.trim();
    if (index < 0 || clean.isEmpty || clean.length > 64) return;
    _looks[index] = _looks[index].copyWith(name: clean);
    _changed();
  }

  NatureLook? duplicate(String id) {
    if (!_canEdit()) return null;
    final index = _looks.indexWhere((look) => look.id == id);
    if (index < 0) return null;
    if (!_canAdd(1)) return null;
    final original = _looks[index];
    final copy = original.copyWith(id: _newId(),
      name: '${original.name.length > 55 ? original.name.substring(0, 55) : original.name} · copy',
      description: 'Your saved nature study', saved: true);
    save(copy);
    return copy;
  }

  void delete(String id) {
    if (!_canEdit()) return;
    _looks.removeWhere((look) => look.id == id && look.saved);
    if (!_looks.any((look) => look.id == id)) _favorites.remove(id);
    if (!_looks.any((look) => look.id == _selectedLookId)) {
      _selectedLookId = _looks.first.id;
    }
    _changed();
  }

  bool _canAdd(int count) {
    if (_looks.length + count <= 500) return true;
    persistenceError = 'Your collection can hold 500 looks. Export or delete some looks before adding more.';
    if (!_disposed) notifyListeners();
    return false;
  }

  String _newId() => 'saved-${DateTime.now().microsecondsSinceEpoch}-${_looks.length}';

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'format': 'geode-flutter-looks', 'version': 1,
    'looks': _looks.map((look) => look.toJson()).toList(),
    'favorites': _favorites.toList(), 'selectedLookId': _selectedLookId,
  });

  Map<String, dynamic> _decode(String source) {
    if (source.length > 2 * 1024 * 1024) throw const FormatException('Look collection is too large.');
    final data = jsonDecode(source);
    if (data is! Map<String, dynamic> || data['format'] != 'geode-flutter-looks' ||
        data['version'] != 1 || data['looks'] is! List ||
        (data['looks'] as List).length > 500) {
      throw const FormatException('Choose a Geode Flutter look collection (.json). Native renderer presets use a different format.');
    }
    return data;
  }

  int importJson(String source) {
    if (!_canEdit()) throw StateError('Look storage is not ready. Retry loading first.');
    final data = _decode(source);
    // Validate the entire file before changing the collection.
    final imported = (data['looks'] as List).map((value) {
      if (value is! Map) throw const FormatException('Invalid look in collection.');
      return NatureLook.fromJson(Map<String, dynamic>.from(value));
    }).toList();
    if (!_canAdd(imported.length)) throw FormatException(persistenceError!);
    for (final look in imported) {
      _looks.add(look.copyWith(id: _newId(), saved: true));
    }
    if (imported.isNotEmpty) _changed();
    return imported.length;
  }

  Future<bool> exportLooks() async {
    if (_disposed || !enableDeviceServices || !_storageReady) return false;
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export Geode looks', fileName: 'geode-looks.json', mimeType: 'application/json',
      type: FileType.custom, allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(exportJson())));
    return !_disposed && result != null;
  }

  /// Returns -1 for cancellation, otherwise the number of imported looks.
  Future<int> importLooks() async {
    if (_disposed || !enableDeviceServices) return -1;
    if (!_canEdit()) throw StateError('Look storage is not ready. Retry loading first.');
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import Geode looks', type: FileType.custom,
      allowedExtensions: ['json']);
    if (_disposed || file == null) return -1;
    final length = await file.length();
    if (_disposed) return -1;
    if (length != null && length > 2 * 1024 * 1024) {
      throw const FormatException('Choose a look collection smaller than 2 MB.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (_disposed) return -1;
      if (builder.length + chunk.length > 2 * 1024 * 1024) {
        throw const FormatException('Choose a look collection smaller than 2 MB.');
      }
      builder.add(chunk);
    }
    if (_disposed) return -1;
    return importJson(utf8.decode(builder.takeBytes()));
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    if (!enableDeviceServices || !_storageReady) return;
    final serialized = exportJson();
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        // Already-authorized writes finish after disposal, while notification
        // callbacks are guarded. flush() exposes their completion to callers.
        final written = await _preferences!.setString(storageKey, serialized);
        if (!written) throw StateError('Save failed');
        if (persistenceError != null) {
          persistenceError = null;
          if (!_disposed) notifyListeners();
        }
      } catch (_) {
        persistenceError = 'Changes are available now, but could not be saved on this device.';
        if (!_disposed) notifyListeners();
      }
    });
  }

  @override
  void dispose() { _disposed = true; super.dispose(); }
}
