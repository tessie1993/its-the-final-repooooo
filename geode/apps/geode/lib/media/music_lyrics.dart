class LyricLine {
  const LyricLine(this.text, this.time);
  final String text;
  final Duration? time;
}

/// Reads plain lyrics and LRC, including repeated timestamps and global offset.
/// Metadata is omitted; a positive LRC offset advances lyrics relative to audio.
List<LyricLine> parseLyrics(String lyrics) {
  final result = <LyricLine>[];
  final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final metadata = RegExp(r'^\[(ar|al|ti|by|offset|re|ve|length):', caseSensitive: false);
  final offsets = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false).allMatches(lyrics);
  final offset = offsets.isEmpty ? 0 : int.tryParse(offsets.last.group(1)!) ?? 0;
  for (final raw in lyrics.split('\n')) {
    final matches = timestamp.allMatches(raw).toList();
    final text = raw.replaceAll(timestamp, '').trim();
    if (metadata.hasMatch(text)) continue;
    if (matches.isEmpty) {
      if (text.isNotEmpty) result.add(LyricLine(text, null));
      continue;
    }
    // Empty timestamped lines intentionally clear the previous sung line.
    for (final match in matches) {
      final seconds = int.parse(match.group(2)!);
      if (seconds >= 60) continue;
      final fraction = int.parse((match.group(3) ?? '').padRight(3, '0'));
      final milliseconds = int.parse(match.group(1)!) * 60000 + seconds * 1000 + fraction - offset;
      result.add(LyricLine(text, Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds)));
    }
  }
  if (result.any((line) => line.time != null)) {
    // Timed LRC often contains unsorted chorus timestamps. Keep untimed notes
    // first, then sort stably so highlighting never selects a future line.
    final indexed = result.indexed.toList();
    indexed.sort((a, b) {
      if (a.$2.time == null) return b.$2.time == null ? a.$1.compareTo(b.$1) : -1;
      if (b.$2.time == null) return 1;
      final timeOrder = a.$2.time!.compareTo(b.$2.time!);
      return timeOrder == 0 ? a.$1.compareTo(b.$1) : timeOrder;
    });
    return List.unmodifiable(indexed.map((entry) => entry.$2));
  }
  return List.unmodifiable(result);
}

int activeLyricIndex(List<LyricLine> lines, Duration position) {
  var active = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].time != null && lines[i].time! <= position) active = i;
  }
  return active;
}
