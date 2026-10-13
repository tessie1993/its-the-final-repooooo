part of 'music_controller.dart';

extension _MusicEffects on MusicController {
  Future<void> _initializeEqualizer() async {
    if (!_player.usesNative || _eqInitializing || equalizerAvailable || _disposed) return;
    _eqInitializing = true;
    try {
      const frequencies = <double>[31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      final gains = List<double>.generate(frequencies.length, (i) =>
        i < _savedEqGains.length ? _savedEqGains[i].clamp(-15.0, 15.0).toDouble() : 0);
      if (_disposed) return;
      eqMinGain = -15;
      eqMaxGain = 15;
      eqFrequencies = frequencies;
      eqGains = List.unmodifiable(gains);
      equalizerAvailable = true;
      equalizerEnabled = _savedEqEnabled;
      await _applyDsp();
      _notify();
    } catch (_) {
      equalizerAvailable = false;
      equalizerEnabled = false;
      _notify();
    } finally { _eqInitializing = false; }
  }

  Future<void> _setEqualizerEnabled(bool value) => _serial(() async {
    if (!equalizerAvailable) return;
    await _applyDsp(eqEnabled: value);
    equalizerEnabled = value;
    _savedEqEnabled = value;
    _changed();
  });

  Future<void> _setEqGain(int index, double value) => _serial(() async {
    if (!equalizerAvailable || index < 0 || index >= eqGains.length) return;
    final gains = List<double>.of(eqGains);
    gains[index] = value.clamp(eqMinGain, eqMaxGain).toDouble();
    await _applyDsp(bands: gains);
    eqGains = List.unmodifiable(gains);
    _savedEqGains = gains;
    _changed();
  });

  double get _replayGain {
    final track = currentTrack;
    if (track == null || replayGainMode == 'off') return 0;
    final album = replayGainMode == 'album';
    final gain = (album ? track.albumGainDb ?? track.trackGainDb : track.trackGainDb) ?? 0;
    final peak = album ? track.albumPeak ?? track.trackPeak : track.trackPeak;
    // Prevent tag-directed gain from clipping even when the user disables the
    // limiter. The final native limiter handles additional EQ boosts.
    if (peak != null && peak > 0 && peak.isFinite) {
      return math.min(gain, -20 * math.log(peak) / math.ln10 - preampDb);
    }
    return gain.isFinite ? gain : 0;
  }

  Future<void> _applyDsp({bool? eqEnabled, List<double>? bands}) =>
    _player.setEqualizer(
      enabled: true,
      bands: (eqEnabled ?? equalizerEnabled) ? bands ?? eqGains : List.filled(10, 0),
      bassBoost: bassBoost, loudnessDb: loudnessDb,
      gainDb: (preampDb + _replayGain).clamp(-30.0, 15.0).toDouble(),
      crossfeed: crossfeed, limiter: limiter,
    );

  Future<void> _setSoundEffects({double? bass, double? loudness, double? preamp,
    bool? headphoneCrossfeed, bool? peakLimiter, String? replayGain}) => _serial(() async {
      if (!equalizerAvailable) return;
      final previous = (bassBoost, loudnessDb, preampDb, crossfeed, limiter, replayGainMode);
      bassBoost = bass?.clamp(0.0, 1.0).toDouble() ?? bassBoost;
      loudnessDb = loudness?.clamp(0.0, 10.0).toDouble() ?? loudnessDb;
      preampDb = preamp?.clamp(-15.0, 15.0).toDouble() ?? preampDb;
      crossfeed = headphoneCrossfeed ?? crossfeed;
      limiter = peakLimiter ?? limiter;
      if (const ['off', 'track', 'album'].contains(replayGain)) replayGainMode = replayGain!;
      try { await _applyDsp(); }
      catch (_) {
        (bassBoost, loudnessDb, preampDb, crossfeed, limiter, replayGainMode) = previous;
        rethrow;
      }
      _changed();
    });

  void _setSleepTimer(Duration? value) => _change(() {
    _sleepTimer?.cancel();
    sleepAtTrackEnd = false;
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
