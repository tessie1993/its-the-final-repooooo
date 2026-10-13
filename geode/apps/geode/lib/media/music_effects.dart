part of 'music_controller.dart';

extension _MusicEffects on MusicController {
  Future<void> _initializeEqualizer() async {
    if (_equalizer == null || _eqInitializing || _eqParameters != null || _disposed) return;
    _eqInitializing = true;
    try {
      final parameters = await _equalizer!.parameters.timeout(const Duration(seconds: 3));
      if (_disposed) return;
      _eqParameters = parameters;
      eqMinGain = parameters.minDecibels;
      eqMaxGain = parameters.maxDecibels;
      eqFrequencies = List.unmodifiable(parameters.bands.map((band) => band.centerFrequency));
      for (var i = 0; i < parameters.bands.length && i < _savedEqGains.length; i++) {
        await parameters.bands[i].setGain(_savedEqGains[i].clamp(eqMinGain, eqMaxGain).toDouble());
      }
      await _equalizer!.setEnabled(_savedEqEnabled);
      if (_disposed) return;
      equalizerAvailable = parameters.bands.isNotEmpty;
      equalizerEnabled = _equalizer!.enabled;
      eqGains = List.unmodifiable(parameters.bands.map((band) => band.gain));
      _notify();
    } catch (_) {
      // No pretend EQ: unavailable devices retain a disabled UI.
      equalizerAvailable = false;
      equalizerEnabled = false;
      _eqParameters = null;
      _notify();
    } finally { _eqInitializing = false; }
  }

  Future<void> _setEqualizerEnabled(bool value) => _serial(() async {
    if (!equalizerAvailable || _equalizer == null) return;
    await _equalizer!.setEnabled(value);
    equalizerEnabled = _equalizer!.enabled;
    _savedEqEnabled = equalizerEnabled;
    _changed();
  });

  Future<void> _setEqGain(int index, double value) => _serial(() async {
    final parameters = _eqParameters;
    if (!equalizerAvailable || parameters == null || index < 0 || index >= parameters.bands.length) return;
    await parameters.bands[index].setGain(value.clamp(eqMinGain, eqMaxGain).toDouble());
    eqGains = List.unmodifiable(parameters.bands.map((band) => band.gain));
    _savedEqGains = List.of(eqGains);
    _changed();
  });

  void _setSleepTimer(Duration? value) => _change(() {
    _sleepTimer?.cancel();
    sleepEndsAt = value == null ? null : DateTime.now().add(value);
    if (value == null) return;
    _sleepTimer = Timer(value.isNegative ? Duration.zero : value, () {
      unawaited(_serial(() async {
        await _player.pause();
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
