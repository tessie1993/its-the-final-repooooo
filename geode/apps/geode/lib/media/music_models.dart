/// Local catalogue metadata. [path] points to an app-owned audio copy.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.path,
    required this.title,
    this.artist = 'Unknown artist',
    this.album = 'Unknown album',
    this.durationMs = 0,
    required this.addedAt,
    this.sizeBytes = 0,
    this.lyrics = '',
    this.artPath = '',
    this.trackGainDb,
    this.trackPeak,
    this.albumGainDb,
    this.albumPeak,
  });

  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int addedAt;
  final int sizeBytes;
  final String lyrics;
  final String artPath;
  final double? trackGainDb, trackPeak, albumGainDb, albumPeak;

  MusicTrack copyWith({
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? lyrics,
  }) => MusicTrack(
    id: id,
    path: path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    durationMs: durationMs ?? this.durationMs,
    addedAt: addedAt,
    sizeBytes: sizeBytes,
    lyrics: lyrics ?? this.lyrics,
    artPath: artPath,
    trackGainDb: trackGainDb, trackPeak: trackPeak,
    albumGainDb: albumGainDb, albumPeak: albumPeak,
  );

  Map<String, Object?> toJson() => {
    'id': id, 'path': path, 'title': title, 'artist': artist,
    'album': album, 'durationMs': durationMs, 'addedAt': addedAt,
    'sizeBytes': sizeBytes, 'lyrics': lyrics,
    'artPath': artPath, 'trackGainDb': trackGainDb, 'trackPeak': trackPeak,
    'albumGainDb': albumGainDb, 'albumPeak': albumPeak,
  };

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    id: json['id'] as String,
    path: json['path'] as String,
    title: _nonempty(json['title'], 'Untitled track'),
    artist: _nonempty(json['artist'], 'Unknown artist'),
    album: _nonempty(json['album'], 'Unknown album'),
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    lyrics: json['lyrics'] as String? ?? '',
    artPath: json['artPath'] as String? ?? '',
    trackGainDb: (json['trackGainDb'] as num?)?.toDouble(),
    trackPeak: (json['trackPeak'] as num?)?.toDouble(),
    albumGainDb: (json['albumGainDb'] as num?)?.toDouble(),
    albumPeak: (json['albumPeak'] as num?)?.toDouble(),
  );
}

class MusicPlaylist {
  MusicPlaylist({required this.id, required this.name, List<String> trackIds = const []})
      : trackIds = List.unmodifiable(trackIds);

  final String id;
  final String name;
  final List<String> trackIds;

  MusicPlaylist copyWith({String? name, List<String>? trackIds}) =>
      MusicPlaylist(id: id, name: name ?? this.name, trackIds: trackIds ?? this.trackIds);

  Map<String, Object> toJson() => {'id': id, 'name': name, 'trackIds': trackIds};

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    name: _nonempty(json['name'], 'Untitled playlist'),
    trackIds: (json['trackIds'] as List<dynamic>? ?? []).cast<String>(),
  );
}

String _nonempty(dynamic value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
