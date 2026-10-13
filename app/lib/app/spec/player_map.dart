import 'page_spec.dart';

/// Player: what is playing now, and the way into the full-screen visualizer.
const playerPage = PageSpec(
  id: 'player',
  title: 'Player',
  summary: 'Now playing: artwork, transport, a live spectrum, the queue and quick actions.',
  surface: PageSurface.spectrum,
  features: [
    'Title, artist and artwork; tapping the artwork opens the full-screen visualizer',
    'Transport: play/pause, previous/next, seek on a waveform drawn from the track analysis',
    'Shuffle, repeat, A-B loop, favourite',
    'Scene chip showing the current visual style',
    'Live spectrum driven by the analysis feature frames',
    'Queue preview',
    'Quick actions: Shuffle all, Room (microphone input), Capture other apps\' audio, Sleep timer',
    'Fades on play/pause/skip, ReplayGain, resume position for tracks longer than 20 minutes',
  ],
  poweredBy: [
    'C++ geode_player: decode → resample → mixer (gapless / crossfade) → Oboe',
    'C++ DSP chain: gain → 10-band EQ → crossfeed → limiter',
    'C++ analysis: 237-float feature frame per hop',
    'Dart: queue, history, sleep timer, ReplayGain, bookmarks',
  ],
  children: [visualizerPage, queuePage],
  sheets: [sleepTimerSheet, abLoopSheet],
);

const visualizerPage = PageSpec(
  id: 'visualizer',
  title: 'Visualizer',
  kind: PageKind.fullscreen,
  summary: 'The music visualizer full screen, with the player chrome on top.',
  surface: PageSurface.visualizer,
  features: [
    'Tap to show/hide the controls; swipe down (predictive back) to collapse',
    'Touch is part of the picture: one finger sets a point, two an axis, three or more a swirl',
    'Pinch and twist to zoom and rotate',
    'Picture-in-picture, second-screen output, favourite',
    'Photosensitivity clamp is always on (max three flashes per second)',
  ],
  poweredBy: [
    'C++ render host: own EGL context + thread, AChoreographer pacing',
    'C++ geode_viz renderer: scene → trail → composite, 60+ styles, MilkDrop',
  ],
  tabs: [
    PageSpec(id: 'now', title: 'Now', features: ['Transport bar over the visuals']),
    PageSpec(
      id: 'lyrics',
      title: 'Lyrics',
      features: ['Timed lyrics from .lrc sidecars or embedded tags', 'Tap a line to seek'],
      poweredBy: ['Dart: lyrics parser'],
    ),
    PageSpec(
      id: 'queue',
      title: 'Queue',
      features: ['Play any entry, move up/down, remove, save the queue as a playlist'],
    ),
  ],
);

const queuePage = PageSpec(
  id: 'queue',
  title: 'Queue',
  summary: 'The play queue.',
  features: [
    'Reorder, remove, play next, save as playlist',
    'Tapping a track in a list queues everything in that list',
  ],
  poweredBy: ['Dart: queue service', 'C++ geode_player: next-track preload for gapless'],
  sheets: [saveQueueDialog],
);

const sleepTimerSheet = PageSpec(
  id: 'sleep-timer',
  title: 'Sleep timer',
  kind: PageKind.sheet,
  features: ['Stop after N minutes with a fade, or at the end of the current track'],
  poweredBy: ['Dart: sleep timer'],
);

const abLoopSheet = PageSpec(
  id: 'ab-loop',
  title: 'A-B loop',
  kind: PageKind.sheet,
  features: ['Set A and B points and repeat the section between them'],
);

const saveQueueDialog = PageSpec(
  id: 'save-queue',
  title: 'Save queue as playlist',
  kind: PageKind.dialog,
  features: ['Name the new playlist'],
);

/// Search: opened from any destination; the results play from search.
const searchPage = PageSpec(
  id: 'search',
  title: 'Search',
  kind: PageKind.fullscreen,
  summary: 'Search the whole library.',
  features: [
    'Multi-term, typo-tolerant search over title, artist, album and folder',
    'Tapping a result plays it with its context queued',
  ],
  poweredBy: ['Dart: library search (edit-distance matcher)'],
);
