import 'page_spec.dart';
import 'studio_map.dart';

/// Settings: everything else.
const settingsPage = PageSpec(
  id: 'settings',
  title: 'Settings',
  summary: 'Look, audio, export, folders, behavior, help and about.',
  tabs: [
    PageSpec(
      id: 'look',
      title: 'Look',
      features: [
        'Theme pack (10 stone themes: art, sounds, haptics), font colour, contrast',
        'Layout: player position, corner style, bar opacity',
        'Boot animation on/off',
      ],
    ),
    PageSpec(
      id: 'audio',
      title: 'Audio',
      features: [
        'Playback: crossfade, gapless, speed/pitch, skip silence, ReplayGain, bit-perfect USB',
        'Equalizer: 10 bands, bass boost, loudness, presets',
        'Analysis: beat sensitivity, intelligence mode, analysis cache',
        'Live input (microphone) and capture of other apps\' audio',
      ],
      poweredBy: ['C++ geode_dsp / geode_player', 'C++ analysis tuning'],
    ),
    PageSpec(
      id: 'export',
      title: 'Export',
      features: ['Export defaults: frame rate, codec, quality, loudness target, destination'],
      children: [exportPage],
    ),
    PageSpec(
      id: 'folders',
      title: 'Folders',
      features: ['Preset folders, music folders, analysis cache size and clear'],
    ),
    PageSpec(
      id: 'behavior',
      title: 'Behavior',
      features: [
        'What you use Geode for (decides whether Studio is in the navigation)',
        'Touch on the visualizer, connected display, reduced motion, picture-in-picture',
        'Live wallpaper and screensaver',
      ],
      actions: [
        ActionSpec(AppAction.intentListening, 'I only listen (hide Studio)'),
        ActionSpec(AppAction.intentVideos, 'I make videos'),
        ActionSpec(AppAction.intentBoth, 'Both'),
      ],
    ),
    PageSpec(
      id: 'help',
      title: 'Help',
      features: [
        'Library: where your music comes from',
        'Visuals: styles, presets and Customize',
        'Touch: what your fingers do on the visualizer',
        'Safety: the flash limit',
        'Performance: quality tiers and battery',
      ],
      actions: [
        ActionSpec(AppAction.replayTutorial, 'Replay the walkthrough'),
        ActionSpec(AppAction.restartOnboarding, 'Show the first-run screens again'),
      ],
    ),
    PageSpec(
      id: 'about',
      title: 'About',
      features: ['Version, privacy (nothing leaves the phone, no network permission), licences'],
    ),
  ],
);
