part of 'music_controller.dart';

extension _MusicImport on MusicController {
  Future<void> _importAudio() async {
    await initialize();
    if (!initialized || _disposed || busy || !enableDeviceServices) return;
    busy = true;
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
        if (_disposed) break;
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
      _changed();
    }
  }
}
