import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../media/music_controller.dart';
import '../scene/geode_scene_controller.dart';
import '../studio/studio_controller.dart';
import 'nature_look.dart';
import 'visual_library.dart';

export 'nature_look.dart';

/// Screen-level state stays independent of audio positions and animation frames.
class GeodeAppState extends ChangeNotifier {
  GeodeAppState({this.enableDeviceServices = true})
      : music = MusicController(enableDeviceServices: enableDeviceServices),
        studio = StudioController(enableDeviceServices: enableDeviceServices),
        visualLibrary = VisualLibrary(enableDeviceServices: enableDeviceServices) {
    visualLibrary.addListener(_libraryChanged);
  }
  final bool enableDeviceServices;
  final scene = GeodeSceneController();
  final MusicController music;
  final StudioController studio;
  final VisualLibrary visualLibrary;
  late final _preferences = SharedPreferencesAsync();
  Timer? _saveTimer;
  Future<void>? _initialization;
  bool _storageReady = false;
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;
  bool initialized = false;
  String? error;
  int destination = 0;
  bool immersive = false;
  bool natureDetails = true;
  bool haptics = true;
  final Set<String> parameterLocks = {};
  static const _key = 'geode.ui.appearance.v1';

  List<NatureLook> get looks => visualLibrary.looks;
  Set<String> get favorites => visualLibrary.favorites;
  String get selectedLookId => visualLibrary.selectedLookId;
  NatureLook get selectedLook => visualLibrary.selectedLook;
  bool get isEdited => selectedLook.material != scene.materialIndex ||
    (selectedLook.energy - scene.energy).abs() > .001 ||
    selectedLook.particles != scene.particlesEnabled ||
    selectedLook.natureDetails != natureDetails ||
    (selectedLook.hue - scene.hue).abs() > .001 ||
    (selectedLook.particleDensity - scene.particleDensity).abs() > .001 ||
    (selectedLook.rippleStrength - scene.rippleStrength).abs() > .001;

  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    return _initialization ??= _restore().whenComplete(() => _initialization = null);
  }

  Future<void> _restore() async {
    if (!enableDeviceServices) {
      await Future.wait([music.initialize(), studio.initialize(), visualLibrary.initialize()]);
      if (_disposed) return;
      initialized = true;
      _changed(persist: false);
      return;
    }
    // Each module owns its errors, data and updates. UI remains usable if a
    // platform service is absent, without silently claiming a successful save.
    try {
      await Future.wait([visualLibrary.initialize(), music.initialize(), studio.initialize()]);
      if (_disposed) return;
      if (_storageReady) { _queueSave(); await flush(); return; }
      final stored = await _preferences.getString(_key);
      if (_disposed) return;
      if (stored != null) {
        final p = jsonDecode(stored) as Map<String, dynamic>;
        scene.setMaterial(_number(p, 'material', selectedLook.material.toDouble()).round());
        scene.setEnergy(_number(p, 'energy', selectedLook.energy));
        scene.setHue(_number(p, 'hue', .5));
        scene.setParticleDensity(_number(p, 'density', .6));
        scene.setRippleStrength(_number(p, 'ripples', .65));
        scene.particlesEnabled = p['particles'] != false;
        scene.highQuality = p['highQuality'] != false;
        scene.reducedMotion = p['reducedMotion'] == true;
        natureDetails = p['natureDetails'] != false;
        haptics = p['haptics'] != false;
        final locks = p['locks'];
        parameterLocks.clear();
        if (locks is List) parameterLocks.addAll(locks.whereType<String>().where(
          const {'material', 'energy', 'hue', 'particleDensity', 'rippleStrength'}.contains));
      } else {
        _applyLook(selectedLook);
      }
      _storageReady = true;
      error = null;
    } catch (_) { error = 'Appearance could not be restored. Your saved data was not changed.'; }
    if (_disposed) return;
    initialized = true;
    _changed(persist: false);
  }

  double _number(Map<String,dynamic> p, String key, double fallback) {
    final value = p[key];
    return value is num && value.isFinite ? value.toDouble() : fallback;
  }

  void _libraryChanged() { _changed(persist: false); }
  void _changed({bool persist = true}) {
    if (_disposed) return;
    notifyListeners();
    if (persist && initialized && enableDeviceServices && _storageReady) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 250), _queueSave);
    }
  }

  void _queueSave() {
    _saveTimer = null;
    if (!_storageReady || !enableDeviceServices) return;
    final snapshot = jsonEncode({
      'material': scene.materialIndex, 'energy': scene.energy, 'hue': scene.hue,
      'density': scene.particleDensity, 'ripples': scene.rippleStrength,
      'particles': scene.particlesEnabled, 'highQuality': scene.highQuality,
      'reducedMotion': scene.reducedMotion, 'natureDetails': natureDetails,
      'haptics': haptics, 'locks': parameterLocks.toList(),
    });
    _writes = _writes.then((_) async {
      try {
        await _preferences.setString(_key, snapshot);
        if (!_disposed && error == 'Appearance changes could not be saved.') {
          error = null;
          notifyListeners();
        }
      } catch (_) {
        if (!_disposed) { error = 'Appearance changes could not be saved.'; notifyListeners(); }
      }
    });
  }

  Future<void> flush() async {
    if (_saveTimer != null) { _saveTimer!.cancel(); _queueSave(); }
    await Future.wait([_writes, studio.flush(), music.flush(), visualLibrary.flush()]);
  }

  void navigate(int index) {
    destination = index.clamp(0, 3).toInt();
    immersive = false;
    _changed(persist: false);
  }
  void clearError() { error = null; _changed(persist: false); }
  void setImmersive(bool value) { immersive = value; _changed(persist: false); }
  void togglePlayback() { scene.paused = !scene.paused; _changed(persist: false); }
  void setMaterial(int value) { scene.setMaterial(value); _changed(); }
  void setEnergy(double value) { scene.setEnergy(value); _changed(); }
  void setHue(double value) { scene.setHue(value); _changed(); }
  void setParticleDensity(double value) { scene.setParticleDensity(value); _changed(); }
  void setRippleStrength(double value) { scene.setRippleStrength(value); _changed(); }
  void setParticles(bool value) { scene.particlesEnabled = value; _changed(); }
  void setQuality(bool value) { scene.highQuality = value; _changed(); }
  void setReducedMotion(bool value) { scene.reducedMotion = value; _changed(); }
  void setNatureDetails(bool value) { natureDetails = value; _changed(); }
  void setHaptics(bool value) { haptics = value; _changed(); }
  void toggleParameterLock(String key) {
    if (!parameterLocks.add(key)) parameterLocks.remove(key);
    _changed();
  }
  void randomizeVisuals() {
    final random = Random();
    if (!parameterLocks.contains('material')) scene.setMaterial(random.nextInt(3));
    if (!parameterLocks.contains('energy')) scene.setEnergy(.15 + random.nextDouble() * .7);
    if (!parameterLocks.contains('hue')) scene.setHue(random.nextDouble());
    if (!parameterLocks.contains('particleDensity')) scene.setParticleDensity(.2 + random.nextDouble() * .7);
    if (!parameterLocks.contains('rippleStrength')) scene.setRippleStrength(.3 + random.nextDouble() * .7);
    _changed();
  }
  void _applyLook(NatureLook look) {
    scene.setMaterial(look.material);
    scene.setEnergy(look.energy);
    scene.setHue(look.hue);
    scene.setParticleDensity(look.particleDensity);
    scene.setRippleStrength(look.rippleStrength);
    scene.particlesEnabled = look.particles;
    natureDetails = look.natureDetails;
  }
  void selectLook(NatureLook look) {
    _applyLook(look);
    visualLibrary.select(look.id);
    destination = 0;
    _changed();
  }
  void toggleFavorite(String id) => visualLibrary.toggleFavorite(id);
  void saveLook(String name) {
    if (name.trim().isEmpty) return;
    final look = NatureLook(id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(), description: 'Your nature study',
      material: scene.materialIndex, energy: scene.energy, saved: true,
      particles: scene.particlesEnabled, natureDetails: natureDetails,
      hue: scene.hue, particleDensity: scene.particleDensity, rippleStrength: scene.rippleStrength);
    visualLibrary.save(look);
    visualLibrary.select(look.id);
    _changed();
  }
  void resetAppearance() {
    _applyLook(looks.first);
    visualLibrary.select(looks.first.id);
    scene.reducedMotion = false;
    scene.highQuality = true;
    scene.paused = false;
    parameterLocks.clear();
    _changed();
  }

  @override
  void dispose() {
    unawaited(flush());
    _disposed = true;
    visualLibrary.removeListener(_libraryChanged);
    visualLibrary.dispose(); music.dispose(); studio.dispose(); scene.dispose();
    super.dispose();
  }
}
