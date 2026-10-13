part of 'music_controller.dart';

extension _MusicImport on MusicController {
  Future<void> _importAudio() async {
    await initialize();
    if (!initialized || _disposed || busy || !enableDeviceServices) return;
    busy = true;
    _cancelImport = false;
    importStatus = 'Choose audio files';
    error = null;
    _notify();
    var failed = 0;
    try {
      final selected = await FilePicker.pickFiles(type: FileType.audio);
      if (_disposed || selected.isEmpty) return;
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/geode_music');
      await directory.create(recursive: true);
      for (final picked in selected) {
        if (_disposed || _cancelImport) break;
        importStatus = 'Importing ${picked.name}';
        _notify();
        final id = _newId();
        final extension = (picked.extension ?? 'audio').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final destination = File('${directory.path}/$id.$extension');
        final partial = File('${destination.path}.part');
        try {
          final sink = partial.openWrite();
          try {
            await sink.addStream(picked.readAsByteStream());
            await sink.flush();
          } finally {
            await sink.close();
          }
          final size = await partial.length();
          if (size == 0) throw const FormatException('The selected file is empty');
          await partial.rename(destination.path);
          if (_disposed) { await destination.delete(); break; }
          final filename = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
          Map<String, dynamic> tags = const {};
          try { tags = await _player.readTags(destination.path); }
          catch (_) { /* A missing tag never makes playable audio unimportable. */ }
          if (_disposed) { await destination.delete(); break; }
          String label(String key, String fallback) {
            final value = tags[key];
            return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
          }
          _tracks.add(MusicTrack(
            id: id, path: destination.path,
            title: label('title', filename.isEmpty ? 'Untitled track' : filename),
            artist: label('artist', 'Unknown artist'),
            album: label('album', 'Unknown album'),
            durationMs: (tags['durationMs'] as num?)?.toInt() ?? 0,
            addedAt: DateTime.now().millisecondsSinceEpoch,
            sizeBytes: size,
            artPath: tags['artPath'] as String? ?? '',
            trackGainDb: (tags['trackGainDb'] as num?)?.toDouble(),
            trackPeak: (tags['trackPeak'] as num?)?.toDouble(),
            albumGainDb: (tags['albumGainDb'] as num?)?.toDouble(),
            albumPeak: (tags['albumPeak'] as num?)?.toDouble(),
          ));
          // Save each successful copy so one unreadable selection cannot lose
          // the rest of a batch. Never modify or delete the original file.
          _changed();
        } catch (_) {
          failed++;
          if (await partial.exists()) await partial.delete();
        }
      }
      if (failed > 0) error = '$failed audio ${failed == 1 ? 'file could' : 'files could'} not be imported. Please select them again.';
    } catch (_) {
      error = 'Audio import was interrupted. Open the file picker to retry.';
    } finally {
      busy = false;
      importStatus = null;
      importProgress = null;
      _changed();
    }
  }

  Future<void> _importAudioUrl(String url, {required String title}) async {
    await initialize();
    if (!initialized || _disposed || busy || !enableDeviceServices) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !const ['https', 'http'].contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      error = 'Enter a direct HTTP or HTTPS audio file link.';
      _notify();
      return;
    }
    busy = true;
    _cancelImport = false;
    error = null;
    importStatus = 'Connecting to ${uri.host}';
    importProgress = null;
    _notify();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    _downloadClient = client;
    File? partial;
    File? completedFile;
    var imported = false;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Server returned ${response.statusCode}');
      }
      final mime = response.headers.contentType?.mimeType ?? '';
      if (mime.startsWith('text/') || mime.contains('json') || mime.contains('mpegurl') || mime.contains('html')) {
        throw const FormatException('Use a direct audio file link, not a web page or streaming playlist.');
      }
      const maximumBytes = 1024 * 1024 * 1024;
      if (response.contentLength > maximumBytes) throw const FormatException('Choose an audio file smaller than 1 GB.');
      final support = await getApplicationSupportDirectory();
      final directory = await Directory('${support.path}/geode_music').create(recursive: true);
      final id = _newId();
      final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final extension = RegExp(r'\.([a-zA-Z0-9]{1,8})$').firstMatch(name)?.group(1) ?? 'audio';
      final destination = File('${directory.path}/$id.$extension');
      partial = File('${destination.path}.part');
      var received = 0;
      var lastProgress = DateTime.now();
      final started = DateTime.now();
      final sink = partial.openWrite();
      try {
        await for (final bytes in response.timeout(const Duration(seconds: 30))) {
          if (_disposed || _cancelImport) throw const HttpException('Import cancelled');
          received += bytes.length;
          if (received > maximumBytes || DateTime.now().difference(started) > const Duration(minutes: 15)) {
            throw const FormatException('This link appears to be a live stream. Import a downloadable audio file.');
          }
          sink.add(bytes);
          if (DateTime.now().difference(lastProgress) >= const Duration(milliseconds: 250)) {
            lastProgress = DateTime.now();
            importStatus = 'Downloading ${(received / 1048576).toStringAsFixed(1)} MB';
            importProgress = response.contentLength > 0 ? received / response.contentLength : null;
            _notify();
          }
        }
        await sink.flush();
      } finally { await sink.close(); }
      if (received == 0) throw const FormatException('The audio file is empty.');
      if (response.contentLength >= 0 && received != response.contentLength) {
        throw const FormatException('The download was incomplete. Please try again.');
      }
      if (_disposed || _cancelImport) return;
      completedFile = await partial.rename(destination.path);
      Map<String, dynamic> tags = const {};
      try { tags = await _player.readTags(destination.path); } catch (_) { /* Optional metadata. */ }
      if (_disposed || _cancelImport) return;
      String label(String key, String fallback) {
        final value = tags[key];
        return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
      }
      final filename = name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
      _tracks.add(MusicTrack(
        id: id, path: destination.path,
        title: title.trim().isNotEmpty ? title.trim() : label('title', filename.isEmpty ? uri.host : filename),
        artist: label('artist', 'Unknown artist'), album: label('album', 'Unknown album'),
        durationMs: (tags['durationMs'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.now().millisecondsSinceEpoch, sizeBytes: received,
        artPath: tags['artPath'] as String? ?? '',
        trackGainDb: (tags['trackGainDb'] as num?)?.toDouble(), trackPeak: (tags['trackPeak'] as num?)?.toDouble(),
        albumGainDb: (tags['albumGainDb'] as num?)?.toDouble(), albumPeak: (tags['albumPeak'] as num?)?.toDouble(),
      ));
      imported = true;
    } catch (failure) {
      if (!_disposed && !_cancelImport) {
        error = failure is FormatException ? failure.message :
          'Could not download this audio file. Check the link and connection, then retry.';
      }
    } finally {
      client.close(force: true);
      _downloadClient = null;
      if (partial != null && await partial.exists()) await partial.delete();
      if (!imported && completedFile != null && await completedFile.exists()) await completedFile.delete();
      busy = false;
      importStatus = null;
      importProgress = null;
      _changed();
    }
  }
}
