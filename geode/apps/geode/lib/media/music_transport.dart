part of 'music_controller.dart';

extension _MusicTransport on MusicController {
  Future<void> _playTrack(MusicTrack track, {List<MusicTrack>? from}) => _serial(() async {
    if (_findTrack(track.id) == null) return;
    final source = (from ?? _tracks).where((item) => _findTrack(item.id) != null).map((item) => item.id).toList();
    if (!source.contains(track.id)) source.add(track.id);
    _queue..clear()..addAll(source);
    queueIndex = _queue.indexOf(track.id);
    _resumePositionMs = 0;
    await _loadCurrent(autoplay: true);
  });

  Future<void> _togglePlay() => _serial(() async {
    if (currentTrack == null && _tracks.isNotEmpty) {
      _queue..clear()..addAll(_tracks.map((track) => track.id));
      queueIndex = 0;
    }
    if (currentTrack == null) return;
    error = null;
    if (_loadedTrackId != currentTrack!.id) {
      await _loadCurrent(autoplay: true);
    } else if (_player.playing && _player.processingState != ProcessingState.completed) {
      await _player.pause();
      _changed();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _startPlayback();
    }
  });

  Future<void> _loadCurrent({required bool autoplay}) async {
    _sourceGeneration++;
    _loadedTrackId = null;
    loopStart = null;
    loopEnd = null;
    final track = currentTrack;
    if (track == null) {
      await _player.stop();
      _loadedTrackId = null;
      duration = Duration.zero;
      if (!_disposed) position.value = Duration.zero;
      _changed();
      return;
    }
    loading = true;
    error = null;
    _loadingSource = true;
    duration = Duration(milliseconds: track.durationMs);
    position.value = Duration(milliseconds: math.max(0, _resumePositionMs));
    _notify();
    try {
      // Pause before replacing the source so a previous play request cannot
      // accidentally start a newly selected source before it is ready.
      await _player.pause();
      if (_disposed) return;
      if (!await File(track.path).exists()) {
        throw const FileSystemException('Imported audio file is unavailable');
      }
      if (_disposed) return;
      final resume = math.max(0, _resumePositionMs);
      _resumePositionMs = 0;
      final knownDuration = track.durationMs;
      final initialMs = knownDuration > 0 ? math.min(resume, knownDuration) : resume;
      final loadedDuration = await _player.setFilePath(
        track.path, initialPosition: Duration(milliseconds: initialMs),
      );
      if (_disposed) return;
      _loadedTrackId = track.id;
      _loadingSource = false;
      position.value = _player.position;
      if (loadedDuration != null) _acceptDuration(loadedDuration);
      else duration = Duration(milliseconds: track.durationMs);
      _recentIds..remove(track.id)..insert(0, track.id);
      if (_recentIds.length > 50) _recentIds.removeRange(50, _recentIds.length);
      unawaited(_initializeEqualizer());
      if (autoplay) _startPlayback();
    } catch (_) {
      _loadedTrackId = null;
      if (!_disposed) error = 'This track could not be opened. Retry, or import the original audio file again.';
    } finally {
      _loadingSource = false;
      loading = false;
      _changed();
    }
  }

  void _startPlayback() {
    // AudioPlayer.play completes at pause/completion, so never await it inside
    // the command queue. Its errors still need an explicit handler.
    final source = _sourceGeneration;
    unawaited(_player.play().catchError((Object failure) {
      if (_disposed || source != _sourceGeneration) return;
      _loadedTrackId = null;
      error = 'Playback could not start. Tap play to retry.';
      _notify();
    }));
    _changed();
  }

  Future<void> _seek(Duration value) => _serial(() async {
    if (currentTrack == null) return;
    if (_loadedTrackId != currentTrack!.id) await _loadCurrent(autoplay: false);
    if (_loadedTrackId == null) return;
    final end = duration.inMilliseconds;
    final milliseconds = end > 0
        ? value.inMilliseconds.clamp(0, end).toInt()
        : math.max(0, value.inMilliseconds);
    await _player.seek(Duration(milliseconds: milliseconds));
    _changed();
  });

  Future<void> _advance(int direction, {bool completed = false}) async {
    if (_queue.isEmpty) return;
    var target = queueIndex + direction;
    if (shuffle && _queue.length > 1 && direction > 0) {
      // Choose another queue entry; random playback never silently edits order.
      target = (queueIndex + 1 + math.Random().nextInt(_queue.length - 1)) % _queue.length;
    }
    if (target >= _queue.length) {
      if (repeatMode == 1) target = 0;
      else {
        if (completed) { await _player.pause(); _changed(); }
        return;
      }
    }
    if (target < 0) {
      if (repeatMode == 1) target = _queue.length - 1;
      else { await _player.seek(Duration.zero); return; }
    }
    queueIndex = target;
    _resumePositionMs = 0;
    await _loadCurrent(autoplay: true);
  }

  void _enqueue(String id) => _change(() {
    if (_findTrack(id) == null) return;
    _queue.add(id);
    if (queueIndex < 0) queueIndex = 0;
  });

  Future<void> _removeQueue(int index) => _serial(() async {
    if (index < 0 || index >= _queue.length) return;
    final wasPlaying = playing;
    final removedCurrent = index == queueIndex;
    _queue.removeAt(index);
    if (index < queueIndex) queueIndex--;
    if (_queue.isEmpty) queueIndex = -1;
    else if (queueIndex >= _queue.length) queueIndex = _queue.length - 1;
    if (removedCurrent) {
      _resumePositionMs = 0;
      await _loadCurrent(autoplay: wasPlaying);
    }
    _changed();
  });

  void _moveQueue(int oldIndex, int newIndex) => _change(() {
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex > _queue.length) return;
    if (newIndex > oldIndex) newIndex--;
    final id = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, id);
    if (queueIndex == oldIndex) queueIndex = newIndex;
    else if (oldIndex < queueIndex && newIndex >= queueIndex) queueIndex--;
    else if (oldIndex > queueIndex && newIndex <= queueIndex) queueIndex++;
  });
}
