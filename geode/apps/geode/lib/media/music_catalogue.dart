part of 'music_controller.dart';

extension _MusicCatalogue on MusicController {
  void _toggleFavorite(String id) => _change(() {
    if (_findTrack(id) == null) return;
    if (!_favorites.remove(id)) _favorites.add(id);
  });

  String _createPlaylist(String name) {
    final id = _newId();
    _change(() => _playlists.add(MusicPlaylist(
      id: id, name: name.trim().isEmpty ? 'New playlist' : name.trim(),
    )));
    return id;
  }

  void _renamePlaylist(String id, String name) => _change(() {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0 || name.trim().isEmpty) return;
    _playlists[index] = _playlists[index].copyWith(name: name.trim());
  });

  void _editPlaylist(String playlistId, String trackId, {required bool add}) => _change(() {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0 || _findTrack(trackId) == null) return;
    final ids = List<String>.of(_playlists[index].trackIds);
    if (add && !ids.contains(trackId)) ids.add(trackId);
    if (!add) ids.remove(trackId);
    _playlists[index] = _playlists[index].copyWith(trackIds: ids);
  });

  void _movePlaylistTrack(String id, int oldIndex, int newIndex) => _change(() {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    final ids = List<String>.of(_playlists[index].trackIds);
    if (oldIndex < 0 || oldIndex >= ids.length || newIndex < 0 || newIndex > ids.length) return;
    if (newIndex > oldIndex) newIndex--;
    final track = ids.removeAt(oldIndex);
    ids.insert(newIndex, track);
    _playlists[index] = _playlists[index].copyWith(trackIds: ids);
  });

  void _updateTrack(MusicTrack track) => _change(() {
    final index = _tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) return;
    final original = _tracks[index];
    _tracks[index] = original.copyWith(
      title: track.title.trim().isEmpty ? original.title : track.title.trim(),
      artist: track.artist.trim().isEmpty ? 'Unknown artist' : track.artist.trim(),
      album: track.album.trim().isEmpty ? 'Unknown album' : track.album.trim(),
      lyrics: track.lyrics,
    );
  });

  Future<void> _removeTrack(String id) => _serial(() async {
    final removedCurrent = currentTrack?.id == id;
    final wasPlaying = playing;
    final oldIndex = queueIndex;
    final removedBefore = _queue.take(math.max(0, oldIndex)).where((item) => item == id).length;
    _tracks.removeWhere((track) => track.id == id);
    _queue.removeWhere((item) => item == id);
    _favorites.remove(id);
    _recentIds.remove(id);
    for (var index = 0; index < _playlists.length; index++) {
      final playlist = _playlists[index];
      _playlists[index] = playlist.copyWith(trackIds: playlist.trackIds.where((item) => item != id).toList());
    }
    queueIndex = _queue.isEmpty ? -1 : (oldIndex - removedBefore).clamp(0, _queue.length - 1).toInt();
    if (removedCurrent) {
      _resumePositionMs = 0;
      await _loadCurrent(autoplay: wasPlaying);
    }
    // Removing a catalogue entry never touches the user's original file.
    _changed();
  });
}
