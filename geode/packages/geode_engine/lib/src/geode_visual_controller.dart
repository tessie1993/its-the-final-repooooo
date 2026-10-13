import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geode_native/geode_native.dart';

/// Owns the renderer selection and parameters, independent of widget lifetime.
/// The visible Texture widget owns the GPU surface itself.
class GeodeVisualController extends ChangeNotifier {
  GeodeVisualController({bool enableDeviceServices = true, GeodeNative? native})
      : available = enableDeviceServices && !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        _native = native ?? GeodeNative.instance;

  final GeodeNative _native;
  final bool available;
  bool enabled = false;
  bool loading = false;
  String sceneId = 'water';
  String? milkPreset;
  String? error;
  List<String> scenes = const [];
  List<String> presets = const [];
  bool _disposed = false;
  bool _initialized = false;
  bool _reducedMotion = false;
  bool _paused = false;
  bool _appActive = true;
  int surfaceRevision = 0;
  Object? _textureOwner;
  int? _textureId;
  Future<void>? _initialization;
  Future<void> _commands = Future<void>.value();
  final Map<String, double> _parameters = {};

  Future<void> initialize() {
    if (_disposed || !available || _initialized) return Future<void>.value();
    return _initialization ??= _initialize().whenComplete(() => _initialization = null);
  }

  Future<void> _initialize() async {
    loading = true;
    _notify();
    try {
      await _native.initialize();
      final catalog = await Future.wait([_native.listScenes(), _native.listMilkPresets()]);
      if (_disposed) return;
      scenes = List.unmodifiable(catalog[0]);
      presets = List.unmodifiable(catalog[1]);
      _initialized = true;
      error = null;
    } catch (_) {
      if (!_disposed) error = 'The native scene engine could not start. Tap a scene to retry.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> selectScene(String id) => _enqueue(() async {
    await initialize();
    if (!_initialized || _disposed) return;
    if (!scenes.contains(id)) {
      error = 'This scene is not available in the installed engine.';
      _notify();
      return;
    }
    if (_textureId != null) await _native.setScene(id);
    if (_disposed) return;
    sceneId = id;
    if (id != 'milkdrop') milkPreset = null;
    enabled = true;
    surfaceRevision++;
    error = null;
    _notify();
  });

  Future<void> selectMilkPreset(String preset) => _enqueue(() async {
    await initialize();
    if (!_initialized || _disposed) return;
    if (!presets.contains(preset)) {
      error = 'This MilkDrop preset is not in the installed collection.';
      _notify();
      return;
    }
    if (_textureId != null) {
      await _native.setScene('milkdrop');
      await _native.loadMilkPreset(preset);
    }
    if (_disposed) return;
    sceneId = 'milkdrop';
    milkPreset = preset;
    enabled = true;
    surfaceRevision++;
    error = null;
    _notify();
  });

  void showNature() {
    if (_disposed) return;
    enabled = false;
    error = null;
    _notify();
  }

  Future<void> setParam(String name, double value) => _enqueue(() async {
    if (!value.isFinite) return;
    _parameters[name] = value;
    if (_textureId != null) await _native.setParam(name, value);
  });

  Future<void> setReducedMotion(bool value) => _enqueue(() async {
    _reducedMotion = value;
    if (_textureId != null) await _native.setReducedMotion(value);
  });

  Future<void> setPaused(bool value) => _enqueue(() async {
    _paused = value;
    if (_textureId != null) await _native.setPaused(value || !_appActive);
  });

  Future<void> setAppActive(bool value) => _enqueue(() async {
    _appActive = value;
    if (_textureId != null) await _native.setPaused(_paused || !value);
  });

  Future<int?> acquireTexture({required int width, required int height, required Object owner}) async {
    int? result;
    await _enqueue(() async {
      await initialize();
      if (!_initialized || _disposed || !enabled) return;
      if (_textureId != null) {
        if (identical(owner, _textureOwner)) {
          result = _textureId;
          return;
        }
        _textureId = null;
        _textureOwner = null;
        await _native.disposeTexture();
      }
      final texture = await _native.createTexture(width: width, height: height);
      if (_disposed || !enabled) {
        await _native.disposeTexture();
        return;
      }
      try {
        await _native.setScene(sceneId);
        if (milkPreset != null) await _native.loadMilkPreset(milkPreset!);
        await _native.setReducedMotion(_reducedMotion);
        await _native.setPaused(_paused || !_appActive);
        for (final parameter in _parameters.entries) {
          await _native.setParam(parameter.key, parameter.value);
        }
        if (_disposed || !enabled) {
          await _native.disposeTexture();
          return;
        }
        _textureId = texture;
        _textureOwner = owner;
        result = texture;
        error = null;
        _notify();
      } catch (_) {
        await _native.disposeTexture();
        rethrow;
      }
    });
    return result;
  }

  Future<void> releaseTexture(int? texture, {required Object owner}) => _enqueue(() async {
    if (texture == null || _textureId != texture || !identical(owner, _textureOwner)) return;
    _textureId = null;
    _textureOwner = null;
    await _native.disposeTexture();
  });

  Future<void> _enqueue(Future<void> Function() action) {
    if (_disposed || !available) return Future<void>.value();
    return _commands = _commands.then((_) async {
      if (_disposed) return;
      try { await action(); }
      catch (_) {
        if (!_disposed) {
          error = 'The visualizer could not apply this change. Choose a scene to retry.';
          _notify();
        }
      }
    });
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  @override
  void dispose() {
    _disposed = true;
    if (_textureId != null) {
      _textureId = null;
      unawaited(_commands.then((_) => _native.disposeTexture()).catchError((Object _) {}));
    }
    super.dispose();
  }
}
