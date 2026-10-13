import 'page_spec.dart';

/// The first-run flow, in order. Copy taken from the original app's strings.
const onboardingSteps = [
  OnboardingStepSpec(
    id: 'boot',
    title: 'Geode',
    body: 'Music player · visualizer · studio',
    primary: 'Continue',
  ),
  OnboardingStepSpec(
    id: 'safety',
    title: 'Before the visuals start',
    body:
        'Geode reacts to music with light, and the visuals are intense — bright, fast and '
        'full-screen.',
    note:
        'The flash rate is limited in the engine, by design. Nothing on screen can flash more '
        'than three times a second, no preset or imported file can raise that, and the video you '
        'export is held to the same limit as the screen you saw.',
    primary: 'I understand',
  ),
  OnboardingStepSpec(
    id: 'access',
    title: "Let's find your music",
    body:
        'Geode needs access to the audio on this device. Nothing leaves your phone — there is no '
        'account and no sign-in.',
    primary: 'Allow music access',
    secondary: 'Not now',
  ),
  OnboardingStepSpec(
    id: 'folder',
    title: 'Add a folder?',
    body:
        'Optional. Add a folder only if you keep music somewhere Android does not index — an SD '
        'card, or Downloads.',
    primary: 'Start listening',
    secondary: 'Choose a folder',
  ),
];

/// The guided tour. It moves through the real app rather than showing screenshots.
const tutorialStepsAll = [
  TutorialStepSpec(
    destination: DestinationId.player,
    title: 'This is the Player',
    body:
        'Your track, the transport, and a live spectrum. Tap the artwork to go full screen — that '
        'is where the visuals live.',
  ),
  TutorialStepSpec(
    destination: DestinationId.library,
    title: 'Your music lives here',
    body:
        'Tracks, albums, artists, folders and playlists. Tapping any track queues everything you '
        'are looking at.',
  ),
  TutorialStepSpec(
    destination: DestinationId.visuals,
    title: 'Sixty-odd visual styles',
    body: 'Pick a style, then open Customize to change how it moves. Presets save a whole look.',
  ),
  TutorialStepSpec(
    destination: DestinationId.visuals,
    title: 'Touch the visuals',
    body:
        'On the full-screen visualizer, one finger sets a point, two set an axis, three or more '
        'open a swirl. Pinch and twist zoom and rotate.',
  ),
  TutorialStepSpec(
    destination: DestinationId.studio,
    title: 'Studio makes videos',
    body: 'Record a performance as you play with the controls, then render it out at any quality.',
    videoMakersOnly: true,
  ),
  TutorialStepSpec(
    destination: DestinationId.settings,
    title: 'Everything else is in Settings',
    body: 'Themes, audio, playback, folders and safety. You can replay this walkthrough from Help.',
  ),
];
