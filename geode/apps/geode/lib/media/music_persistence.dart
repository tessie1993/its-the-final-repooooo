part of 'music_controller.dart';

const _musicStorageKey = 'geode.ui.music.v1';

extension _MusicPersistence on MusicController {
  Future<void> _initialize() async {
    loading = true;
    error = null;
    _notify();
    var stage = 'storage';
    try {
      final source = await _preferences.getString(_musicStorageKey);
      if (_disposed) return;
      stage = 'catalogue';
      // Decode completely before changing live state. A malformed snapshot is
      // kept intact; retrying never overwrites it with an empty catalogue.
      final data = source == null ? <String, dynamic>{}
          : jsonDecode(source) as Map<String, dynamic>;
      final tracks = (data['tracks'] as List<dynamic>? ?? [])
          .map((value) => MusicTrack.fromJson(Map<String, dynamic>.from(value as Map))).toList();
      final validIds = tracks.map((track) => track.id).toSet();
      final playlists = (data['playlists'] as List<dynamic>? ?? []).map((value) {
        final playlist = MusicPlaylist.fromJson(Map<String, dynamic>.from(value as Map));
        return playlist.copyWith(trackIds: playlist.trackIds.where(validIds.contains).toList());
      }).toList();
      final queue = (data['queue'] as List<dynamic>? ?? []).cast<String>().where(validIds.contains).toList();
      final favorites = (data['favorites'] as List<dynamic>? ?? []).cast<String>().where(validIds.contains).toSet();
      final recent = (data['recentIds'] as List<dynamic>? ?? []).cast<String>().where(validIds.contains).take(50).toList();
      final storedVolume = ((data['volume'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0).toDouble();
      final storedSpeed = ((data['speed'] as num?)?.toDouble() ?? 1).clamp(0.5, 2.0).toDouble();
      final storedRepeat = ((data['repeatMode'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt();
      final storedShuffle = data['shuffle'] as bool? ?? false;
      final storedIndex = (data['queueIndex'] as num?)?.toInt() ?? -1;
      final storedPosition = (data['positionMs'] as num?)?.toInt() ?? 0;
      final storedEqEnabled = data['equalizerEnabled'] as bool? ?? false;
      final storedEqGains = (data['eqGains'] as List<dynamic>? ?? []).map((value) => (value as num).toDouble()).toList();
      final storedSleep = (data['sleepEndsAt'] as num?)?.toInt();
      stage = 'audio';
      _ensurePlayer();
      await _player.initialize();
      if (_disposed) return;
      await _player.setVolume(storedVolume);
      if (_disposed) return;
      if (_player.speedAvailable) await _player.setSpeed(storedSpeed);
      if (_disposed) return;
      _tracks..clear()..addAll(tracks);
      _playlists..clear()..addAll(playlists);
      _queue..clear()..addAll(queue);
      _favorites..clear()..addAll(favorites);
      _recentIds..clear()..addAll(recent);
      queueIndex = queue.isEmpty ? -1 : storedIndex.clamp(0, queue.length - 1).toInt();
      volume = storedVolume;
      speed = _player.speedAvailable ? storedSpeed : 1;
      pitch = 0;
      repeatMode = storedRepeat;
      shuffle = storedShuffle;
      _shuffleOrder.reset(_queue.length, queueIndex);
      _resumePositionMs = math.max(0, storedPosition);
      position.value = Duration(milliseconds: _resumePositionMs);
      duration = Duration(milliseconds: currentTrack?.durationMs ?? 0);
      _savedEqEnabled = storedEqEnabled;
      _savedEqGains = storedEqGains;
      bassBoost = ((data['bassBoost'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble();
      loudnessDb = ((data['loudnessDb'] as num?)?.toDouble() ?? 0).clamp(0.0, 10.0).toDouble();
      preampDb = ((data['preampDb'] as num?)?.toDouble() ?? 0).clamp(-15.0, 15.0).toDouble();
      crossfeed = data['crossfeed'] == true;
      limiter = data['limiter'] != false;
      final savedGainMode = data['replayGainMode'];
      replayGainMode = const ['off', 'track', 'album'].contains(savedGainMode) ? savedGainMode as String : 'off';
      sleepAtTrackEnd = data['sleepAtTrackEnd'] == true;
      initialized = true;
      unawaited(_initializeEqualizer());
      if (storedSleep != null) {
        final remaining = DateTime.fromMillisecondsSinceEpoch(storedSleep).difference(DateTime.now());
        if (remaining > Duration.zero) _setSleepTimer(remaining);
      }
    } catch (_) {
      if (!_disposed) {
        error = switch (stage) {
          'storage' => 'Music storage is unavailable. Retry after restarting the app. Saved data has been kept.',
          'audio' => 'Audio services could not start. Retry after restarting the app. Your saved library has been kept.',
          _ => 'Your saved music library could not be loaded. Retry to recover it; saved data has been kept.',
        };
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  void _scheduleSave() {
    if (!initialized || _disposed || !enableDeviceServices) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _writeSnapshot);
  }

  void _writeSnapshot() {
    if (!initialized || !enableDeviceServices) return;
    final snapshot = jsonEncode({
      'version': 1,
      'tracks': _tracks.map((track) => track.toJson()).toList(),
      'playlists': _playlists.map((playlist) => playlist.toJson()).toList(),
      'queue': List.of(_queue), 'queueIndex': queueIndex,
      'favorites': _favorites.toList(), 'recentIds': List.of(_recentIds),
      'shuffle': shuffle, 'repeatMode': repeatMode,
      'volume': volume, 'speed': speed, 'pitch': pitch,
      'positionMs': position.value.inMilliseconds,
      'equalizerEnabled': _savedEqEnabled, 'eqGains': List.of(_savedEqGains),
      'sleepEndsAt': sleepEndsAt?.millisecondsSinceEpoch,
      'sleepAtTrackEnd': sleepAtTrackEnd,
      'bassBoost': bassBoost, 'loudnessDb': loudnessDb, 'preampDb': preampDb,
      'crossfeed': crossfeed, 'limiter': limiter, 'replayGainMode': replayGainMode,
    });
    // Keep writes ordered. A slower earlier write cannot replace newer edits.
    _saveSerial = _saveSerial.then((_) => _preferences.setString(_musicStorageKey, snapshot))
        .catchError((Object failure) {
      if (_disposed) return;
      error = 'These changes could not be saved. Make another change to retry.';
      _notify();
    });
  }
}
