part of 'music_controller.dart';

extension _MusicEffects on MusicController {
  Future<void> _initializeEqualizer() async {
    if (!_player.usesNative || _eqInitializing || equalizerAvailable || _disposed) return;
    _eqInitializing = true;
    try {
      const frequencies = <double>[31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      final gains = List<double>.generate(frequencies.length, (i) =>
        i < _savedEqGains.length ? _savedEqGains[i].clamp(-15.0, 15.0).toDouble() : 0);
      await _player.setEqualizer(enabled: _savedEqEnabled, bands: gains);
      if (_disposed) return;
      eqMinGain = -15;
      eqMaxGain = 15;
      eqFrequencies = frequencies;
      eqGains = List.unmodifiable(gains);
      equalizerAvailable = true;
      equalizerEnabled = _savedEqEnabled;
      _notify();
    } catch (_) {
      equalizerAvailable = false;
      equalizerEnabled = false;
      _notify();
    } finally { _eqInitializing = false; }
  }

  Future<void> _setEqualizerEnabled(bool value) => _serial(() async {
    if (!equalizerAvailable) return;
    await _player.setEqualizer(enabled: value, bands: eqGains);
    equalizerEnabled = value;
    _savedEqEnabled = value;
    _changed();
  });

  Future<void> _setEqGain(int index, double value) => _serial(() async {
    if (!equalizerAvailable || index < 0 || index >= eqGains.length) return;
    final gains = List<double>.of(eqGains);
    gains[index] = value.clamp(eqMinGain, eqMaxGain).toDouble();
    await _player.setEqualizer(enabled: equalizerEnabled, bands: gains);
    eqGains = List.unmodifiable(gains);
    _savedEqGains = gains;
    _changed();
  });

  void _setSleepTimer(Duration? value) => _change(() {
    _sleepTimer?.cancel();
    sleepEndsAt = value == null ? null : DateTime.now().add(value);
    if (value == null || !enableDeviceServices) return;
    final deadline = sleepEndsAt;
    _sleepTimer = Timer(value.isNegative ? Duration.zero : value, () {
      unawaited(_serial(() async {
        if (sleepEndsAt != deadline) return;
        await _player.pause();
        if (_disposed || sleepEndsAt != deadline) return;
        sleepEndsAt = null;
        _changed();
      }));
    });
  });

  void _setLoopStart(Duration? value) => _change(() {
    if (currentTrack == null) return;
    loopStart = value == null ? null : _boundLoopPoint(value);
    if (loopStart == null || (loopEnd != null && loopEnd! <= loopStart!)) loopEnd = null;
  });

  void _setLoopEnd(Duration? value) => _change(() {
    if (value == null) { loopEnd = null; return; }
    if (loopStart == null) {
      error = 'Set the loop start before setting the end.';
      return;
    }
    final end = _boundLoopPoint(value);
    if (end <= loopStart! + const Duration(milliseconds: 250)) {
      error = 'The loop end must be at least a quarter second after its start.';
      return;
    }
    loopEnd = end;
  });

  Duration _boundLoopPoint(Duration value) => Duration(milliseconds: duration.inMilliseconds > 0
      ? value.inMilliseconds.clamp(0, duration.inMilliseconds).toInt()
      : math.max(0, value.inMilliseconds));
}
