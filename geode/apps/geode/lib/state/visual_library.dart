import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nature_look.dart';

class VisualLibrary extends ChangeNotifier {
  static const storageKey = 'geode.ui.looks.v1';
  static const _seed = [
    NatureLook(id: 'forest-glass', name: 'Forest glass',
      description: 'Clear water · quiet ripples', material: 0, energy: .42),
    NatureLook(id: 'moonstone', name: 'Moonstone',
      description: 'Opal quartz · slow drift', material: 1, energy: .25, hue: .72),
    NatureLook(id: 'silver-spring', name: 'Silver spring',
      description: 'Liquid silver · flowing light', material: 2, energy: .68, hue: .4),
  ];
  final List<NatureLook> _looks = [..._seed];
  final Set<String> _favorites = {'forest-glass'};
  String _selectedLookId = 'forest-glass';
  SharedPreferences? _preferences;
  Future<void> _pendingWrite = Future<void>.value();
  bool _disposed = false;
  String? persistenceError;

  List<NatureLook> get looks => List.unmodifiable(_looks);
  Set<String> get favorites => Set.unmodifiable(_favorites);
  String get selectedLookId => _selectedLookId;
  NatureLook get selectedLook => _looks.firstWhere(
    (look) => look.id == _selectedLookId, orElse: () => _looks.first);

  Future<void> initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences!.getString(storageKey);
      if (saved != null) {
        final data = _decode(saved);
        final userLooks = (data['looks'] as List).map((value) =>
          NatureLook.fromJson(Map<String, dynamic>.from(value as Map)))
          .where((look) => look.saved && !_seed.any((seed) => seed.id == look.id));
        _looks.addAll({for (final look in userLooks) look.id: look}.values);
        _favorites
          ..clear()
          ..addAll((data['favorites'] as List? ?? const []).whereType<String>()
            .where((id) => _looks.any((look) => look.id == id)));
        final selected = data['selectedLookId'];
        if (selected is String && _looks.any((look) => look.id == selected)) {
          _selectedLookId = selected;
        }
      }
    } catch (_) {
      persistenceError = 'Saved looks could not be loaded. Your nature studies are still available.';
    }
    if (!_disposed) notifyListeners();
  }

  void select(String id) {
    if (!_looks.any((look) => look.id == id)) return;
    _selectedLookId = id;
    _changed();
  }

  void toggleFavorite(String id) {
    if (!_looks.any((look) => look.id == id)) return;
    if (!_favorites.add(id)) _favorites.remove(id);
    _changed();
  }

  void save(NatureLook look) {
    // Built-in nature studies remain a stable starting point.
    if (_seed.any((seed) => seed.id == look.id)) return;
    final index = _looks.indexWhere((item) => item.id == look.id);
    final saved = look.copyWith(saved: true);
    if (index < 0) { _looks.add(saved); } else { _looks[index] = saved; }
    _selectedLookId = look.id;
    _favorites.add(look.id);
    _changed();
  }

  void rename(String id, String name) {
    final index = _looks.indexWhere((look) => look.id == id && look.saved);
    final clean = name.trim();
    if (index < 0 || clean.isEmpty || clean.length > 64) return;
    _looks[index] = _looks[index].copyWith(name: clean);
    _changed();
  }

  NatureLook? duplicate(String id) {
    final index = _looks.indexWhere((look) => look.id == id);
    if (index < 0) return null;
    final original = _looks[index];
    final copy = original.copyWith(id: _newId(),
      name: '${original.name.length > 55 ? original.name.substring(0, 55) : original.name} · copy',
      description: 'Your saved nature study', saved: true);
    save(copy);
    return copy;
  }

  void delete(String id) {
    _looks.removeWhere((look) => look.id == id && look.saved);
    if (!_looks.any((look) => look.id == id)) _favorites.remove(id);
    if (!_looks.any((look) => look.id == _selectedLookId)) {
      _selectedLookId = _looks.first.id;
    }
    _changed();
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
    final data = _decode(source);
    // Validate the entire file before changing the collection.
    final imported = (data['looks'] as List).map((value) {
      if (value is! Map) throw const FormatException('Invalid look in collection.');
      return NatureLook.fromJson(Map<String, dynamic>.from(value));
    }).toList();
    for (final look in imported) {
      _looks.add(look.copyWith(id: _newId(), saved: true));
    }
    if (imported.isNotEmpty) _changed();
    return imported.length;
  }

  Future<bool> exportLooks() async {
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export Geode looks', fileName: 'geode-looks.json', mimeType: 'application/json',
      type: FileType.custom, allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(exportJson())));
    return result != null;
  }

  /// Returns -1 for cancellation, otherwise the number of imported looks.
  Future<int> importLooks() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import Geode looks', type: FileType.custom,
      allowedExtensions: ['json']);
    if (file == null) return -1;
    final length = await file.length();
    if (length != null && length > 2 * 1024 * 1024) {
      throw const FormatException('Choose a look collection smaller than 2 MB.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (builder.length + chunk.length > 2 * 1024 * 1024) {
        throw const FormatException('Choose a look collection smaller than 2 MB.');
      }
      builder.add(chunk);
    }
    return importJson(utf8.decode(builder.takeBytes()));
  }

  void _changed() {
    if (!_disposed) notifyListeners();
    final serialized = exportJson();
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        _preferences ??= await SharedPreferences.getInstance();
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
