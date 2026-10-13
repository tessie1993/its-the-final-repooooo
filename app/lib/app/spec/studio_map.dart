import 'page_spec.dart';

/// Studio: turning music and visuals into videos.
const studioPage = PageSpec(
  id: 'studio',
  title: 'Studio',
  summary: 'Your rendered clips, the clip editor, the timeline and the exporter.',
  features: [
    'Clip library: every video Geode rendered, with rename, delete and storage use',
    'Open a clip in the clip editor, or build a multi-lane project on the timeline',
    'Export a visualizer video or a seamless loop from the current track',
  ],
  poweredBy: [
    'C++ offline analysis → frame-exact visualizer render → MediaCodec H.264/HEVC + AAC → muxer',
    'C++ compositor for timeline cuts (decode → GL effects → encode)',
  ],
  children: [clipEditorPage, timelinePage, exportPage],
  sheets: [renameClipDialog, deleteClipDialog],
);

const clipEditorPage = PageSpec(
  id: 'clip',
  title: 'Clip editor',
  summary: 'Edit one clip and render it again.',
  surface: PageSurface.visualizer,
  tabs: [
    PageSpec(id: 'cut', title: 'Cut', features: ['Trim in/out, split, speed and speed ramps']),
    PageSpec(
      id: 'look',
      title: 'Look',
      features: ['Brightness, contrast, saturation, hue (keyframable), .cube LUTs, gamma'],
    ),
    PageSpec(
      id: 'frame',
      title: 'Frame',
      features: ['Aspect ratio (16:9, 9:16, 1:1, 4:5, 4:3, 21:9), crop, rotation'],
    ),
    PageSpec(
      id: 'sound',
      title: 'Sound & caption',
      features: ['Audio track, mute, captions from lyrics or SRT'],
    ),
    PageSpec(
      id: 'render',
      title: 'Render & send',
      features: ['Quality (720p / 1080p / 4K), codec (H.264 / HEVC), destination folder, share'],
    ),
  ],
);

const timelinePage = PageSpec(
  id: 'timeline',
  title: 'Timeline',
  kind: PageKind.fullscreen,
  summary: 'Multi-lane editor: visual, media, text, overlay and audio lanes.',
  surface: PageSurface.timeline,
  features: [
    'Trim, split, ripple, snapping; undo/redo of whole-project snapshots',
    'Markers: placed by hand, tapped in live, or detected from the track',
    'Keyframe curves (bezier) for scene and clip parameters',
    'GL Transitions between clips (122 transitions)',
    'Captions from lyrics or SRT; chapter export (YouTube, WebVTT, FFmetadata)',
  ],
  poweredBy: [
    'Dart: timeline, keyframes, markers, auto-cut (pure logic ported from the old app)',
    'C++ compositor + encoder for the export',
  ],
  sheets: [addTrackSheet, transitionSheet, autoCutSheet, textClipDialog, chapterExportDialog],
);

const exportPage = PageSpec(
  id: 'export',
  title: 'Export',
  summary: 'Render the current track\'s visuals to video.',
  tabs: [
    PageSpec(
      id: 'visualizer-video',
      title: 'Visualizer video',
      features: [
        'Frame-exact render from the track analysis at 24/30/48/60 fps',
        'Keyframed parameters, LFO/ADSR modulation, background image',
        'Loudness measured (LUFS) against YouTube / Shorts targets',
      ],
      poweredBy: ['C++ offscreen geode_viz + MediaCodec encoder + LUFS meter'],
    ),
    PageSpec(
      id: 'loop',
      title: 'Loop render',
      features: [
        'Render one seamless loop (seam dissolve, palette drift) and repeat it for hours',
        'Long-form soundtrack from one track or a mix, with chapters',
      ],
      poweredBy: ['C++ loop render + remux (no re-render of repeated frames)'],
    ),
  ],
);

const renameClipDialog = PageSpec(id: 'rename-clip', title: 'Rename clip', kind: PageKind.dialog);
const deleteClipDialog = PageSpec(id: 'delete-clip', title: 'Delete clip', kind: PageKind.dialog);

const addTrackSheet = PageSpec(
  id: 'add-track',
  title: 'Add keyframe track',
  kind: PageKind.sheet,
  features: ['Pick a scene or clip parameter to animate'],
);

const transitionSheet = PageSpec(
  id: 'transition',
  title: 'Transition',
  kind: PageKind.sheet,
  features: ['Pick the GL Transition a clip opens with and its duration'],
);

const autoCutSheet = PageSpec(
  id: 'auto-cut',
  title: 'Auto-cut',
  kind: PageKind.sheet,
  features: ['Propose cuts or markers from the transients in the track'],
);

const textClipDialog = PageSpec(id: 'text-clip', title: 'Text clip', kind: PageKind.dialog);

const chapterExportDialog = PageSpec(
  id: 'chapters',
  title: 'Export chapters',
  kind: PageKind.dialog,
  features: ['YouTube description, WebVTT or FFmetadata'],
);
