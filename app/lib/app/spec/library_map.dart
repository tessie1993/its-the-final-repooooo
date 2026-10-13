import 'page_spec.dart';

/// Library: the music on the device and the playlists built from it.
const libraryPage = PageSpec(
  id: 'library',
  title: 'Library',
  summary: 'Tracks, albums, artists, folders, playlists and duplicates.',
  features: [
    'Reads the device music library plus folders added by hand (SD card, Downloads)',
    'Search and sort on the track-shaped tabs',
    'Tapping a track queues everything in the list you are looking at',
  ],
  poweredBy: [
    'Android MediaStore + folder access (shim / plugin)',
    'C++ TagLib: read and write tags, ReplayGain, embedded artwork',
    'Dart: track library store, search, sort',
  ],
  tabs: [
    PageSpec(
      id: 'tracks',
      title: 'Tracks',
      features: ['Every track; search, sort (title, artist, album, added, length, plays)'],
      children: [trackInfoPage],
      sheets: [addToPlaylistDialog],
    ),
    PageSpec(id: 'albums', title: 'Albums', features: ['Tracks grouped by album'], children: [albumPage]),
    PageSpec(id: 'artists', title: 'Artists', features: ['Tracks grouped by artist'], children: [artistPage]),
    PageSpec(
      id: 'folders',
      title: 'Folders',
      features: ['Folder tree of the music roots'],
      children: [folderPage],
    ),
    PageSpec(
      id: 'playlists',
      title: 'Playlists',
      features: [
        'Hand-made playlists: create, rename, reorder by drag, delete',
        'Import M3U / M3U8 / PLS / XSPF',
        'Smart playlists: rules over title, artist, album, folder, length, age, play count, favourite',
      ],
      poweredBy: ['Dart: playlist store, playlist file parsers, smart-playlist matcher'],
      children: [playlistPage],
      sheets: [newPlaylistDialog, smartPlaylistSheet, importPlaylistSheet],
    ),
    PageSpec(
      id: 'duplicates',
      title: 'Duplicates',
      features: [
        'Same title and artist with lengths within two seconds, side by side',
        'Play each copy to compare, then delete the spare',
      ],
    ),
  ],
);

const albumPage = PageSpec(
  id: 'album',
  title: 'Album',
  features: ['The album\'s tracks in disc/track order; play or shuffle'],
);

const artistPage = PageSpec(id: 'artist', title: 'Artist', features: ['The artist\'s tracks and albums']);

const folderPage = PageSpec(
  id: 'folder',
  title: 'Folder',
  features: ['Tracks in this folder and its subfolders'],
);

const playlistPage = PageSpec(
  id: 'playlist',
  title: 'Playlist',
  features: ['Hand-ordered tracks; drag to reorder, remove, play'],
);

const trackInfoPage = PageSpec(
  id: 'track-info',
  title: 'Track info',
  summary: 'Edit a track\'s tags.',
  features: [
    'Title, artist, album, album artist, genre, comment, year, track number',
    'Writes back into the file; asks Android for consent when the file belongs to another app',
  ],
  poweredBy: ['C++ geode_tags (TagLib)', 'Android MediaStore write request (shim)'],
);

const addToPlaylistDialog = PageSpec(
  id: 'add-to-playlist',
  title: 'Add to playlist',
  kind: PageKind.dialog,
  features: ['Pick a playlist or create a new one'],
);

const newPlaylistDialog = PageSpec(
  id: 'new-playlist',
  title: 'New playlist',
  kind: PageKind.dialog,
  features: ['Name the playlist'],
);

const smartPlaylistSheet = PageSpec(
  id: 'smart-playlist',
  title: 'Smart playlist',
  kind: PageKind.sheet,
  features: ['Rules: field, operator, value; match all or any', 'Live count of matching tracks'],
);

const importPlaylistSheet = PageSpec(
  id: 'import-playlist',
  title: 'Import playlist file',
  kind: PageKind.sheet,
  features: ['Pick an M3U, PLS or XSPF file; unresolved entries are reported'],
);
