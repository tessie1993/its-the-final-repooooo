# Geode: Flutter UI over the native Kotlin core

This document is the contract for replacing Geode's Compose UI with a Flutter 3D UI. Every
workstream codes against it. If a workstream needs it changed, the integrator changes it here
first.

## Decisions (from the owner)

- **Source of truth.** The app is the native Android Geode v1.8.0 in
  `tessie1993/visuals-its-the-final-repooooo`, under
  `geode-app-85491c2b76b26cf45c77f2f7fcda6b2f0d8855bd/`. It replaces the older Kotlin copy in
  this repo's `geode/app` and `geode/engine`. `geode/core` (C++) is already byte-identical.
- **Architecture.** Flutter replaces only the Compose UI. The engine, audio, scenes, renderers,
  visual styles, player, library, data stores, export, wallpaper, dream, widget and Android Auto
  stay in Kotlin + C++ exactly as they are. The audio engine modules
  (`engine/audio-core`, `engine/audio-android`) are not modified.
- **Look.** Photorealistic nature: a misty lake or forest pond at dawn or dusk, fog, light
  shafts, real water with reflections and ripples, ferns, mossy stones, and clear water-glass
  orbs and droplets as the controls. Glowing cyan-blue light threads and particle strands link
  them. The pastel reference videos are a guide to motion and animation only, never to colour
  or theme. Copy their motion: liquid morphing and metaball bridging between controls, swirls
  that trail the finger, droplets that stretch and merge, bubbles that drift and pop, glass
  tubes filled with swirling liquid, and a water-drop Now Playing hero with a liquid stem.
- **Builds.** Nothing is compiled, built or tested locally. GitHub Actions
  (`.github/workflows/flutter-android.yml`) does that. `dart analyze` (static analysis only) is
  allowed locally. Gradle, flutter build, flutter test and NDK builds are not.

## Reference videos (what each shows)

1. A droplet rises from a forest pond (light shafts, ferns), becomes a speech bubble, then a
   notification bell with radiating light.
2. Glass pebbles float on a dawn lake. A central glass orb with an avatar sends light threads
   to floating glass panels and glass-pebble stat cards. A large glass dome encloses the panels.
3. A stone with a glowing blue core rises from a lake. Glass orbs ring it, then form a radial
   menu of glass icon bubbles linked by light lines.
4. Glass player components float over a night lake in rain: play, skip, shuffle, sliders and
   an album card holding a CD. Liquid morphs between buttons, and there are counters and a glass
   progress bar.
5. A glowing water dome button is pressed. Rings ripple out and energy veins spread.
6. A dusk pond: ripples, then glowing particle strands radiating from a stone to glass bubbles
   with a bell icon.
7. Now Playing: a glass sphere over a misty lake holding the turning album art, with satellite
   orbs and speech bubbles on light lines and swirling water splashes. Title, heart, seek bar
   and transport sit below.
8. Pastel references (motion only): library rows over water, ink swirls under the finger, a
   droplet Now Playing with a liquid-stem slider, glass pills (Home / Profile / Messages), a
   glass tube filling with swirling liquid, and iridescent bubbles.

## Repository layout after the change

| Path | What | Owner |
|---|---|---|
| `geode/core/**` | C++ engine, unchanged | nobody |
| `geode/engine/{audio-core,audio-android,scenes}` | Kotlin engine modules from the source of truth, unchanged | W1 |
| `geode/app-core/` | Gradle **library** module `:geode-core`: every non-Compose Kotlin source and resource of the source app's `app/` module (package `dev.geode` unchanged) | W1 |
| `geode/apps/geode/android/**` | Flutter Android host: Gradle, manifest, `MainActivity`, `GeodeApplication` | W1 |
| `.github/workflows/flutter-android.yml` | CI | W1 |
| `geode/packages/geode_bridge/**` | Flutter plugin: the typed Dart ⇄ Kotlin bridge, including the visualizer texture | W2 |
| `geode/apps/geode/lib/design/**` | Liquid-glass component kit and motion system | W3 |
| `geode/apps/geode/lib/world/**` | Photoreal 3D nature world (lake, fog, shaders, particles, light threads) | W3 |
| `geode/apps/geode/assets/world/**`, `geode/apps/geode/shaders/**` | CC0 photographic and HDR assets with provenance, and fragment shaders | W3 |
| `geode/apps/geode/lib/screens/**`, `lib/app.dart`, `lib/main.dart` | Every screen, wired to `geode_bridge` | W4 |

Files outside your rows are read-only for you. `pubspec.yaml` files and `pubspec.lock`: each
workstream may add its own dependencies (run `flutter pub get` in `geode/` so the lockfile
stays in sync; CI uses `--enforce-lockfile`). The integrator resolves lockfile merges.

## Native contract (W1 provides, W2 consumes)

- Gradle project paths in the Flutter host: `:geode-core`, `:engine:audio-core`,
  `:engine:audio-android`, `:engine:scenes`. They are included from the host's
  `settings.gradle.kts` with `projectDir` pointing into `geode/`.
- `libgeode.so` and `libprojectM-4.so` are built exactly once, by the module that builds them
  in the source app. Any second CMake build of `geode/CMakeLists.txt` (for example the old
  `geode_native` plugin) is removed so the APK has one copy.
- Hilt: the host app module applies Hilt and KSP. `dev.geode.GeodeApplication` (in the host) is
  `@HiltAndroidApp` and keeps everything the source `GeodeApp` did, including the `container`
  property, the crash handler and the `RingLog` echo. The source app's `Application` is
  replaced, not duplicated. `dev.geode.MainActivity` (in the host) is
  `@AndroidEntryPoint class MainActivity : FlutterFragmentActivity()`. It keeps the source
  activity's non-UI duties: incoming VIEW and SEND intents, media-button and notification
  intents, and second-screen handling.
- ViewModels: the bridge obtains `PlayerViewModel`, `LibraryViewModel`, `VisualsViewModel`,
  `StudioViewModel` and `SettingsViewModel` with
  `ViewModelProvider(activity)[XViewModel::class.java]` from the attached
  `FlutterFragmentActivity` (Hilt supplies the factory). App-wide objects come from
  `(activity.application as GeodeApplication).container`.
- Manifest: every service, receiver, provider, permission and meta-data entry of the source
  manifest survives: the playback service, wallpaper, dream, widget, Android Auto, capture,
  export and file provider. Only the Compose activity becomes the Flutter `MainActivity`.

## Bridge contract (W2 provides, W4 consumes)

`package:geode_bridge/geode_bridge.dart` exports:

- `GeodeBridge`: the root. `GeodeBridge.instance` is a singleton backed by platform
  channels. Constructed with a `GeodeBridgeTransport`, it can run in tests with no platform.
- One Dart controller per Kotlin ViewModel: `PlayerBridge`, `LibraryBridge`, `VisualsBridge`,
  `StudioBridge` and `SettingsBridge`.
  - Every Kotlin `StateFlow<T>` becomes a `ValueListenable<T>` with the same name.
  - Every public function becomes a method with the same name, returning `Future<R>`.
- Models mirror the Kotlin data classes field for field, following `geode/PORTING.md` naming.
  They are immutable, with `==`, `hashCode`, `copyWith`, and `fromMap`/`toMap` using the Kotlin
  property names as keys. Examples: `PlayerUiState`, `QueueUiState`, `VizUiState`,
  `AudioFeatures` and `SceneParams`.
- `GeodeVisualizerView`: a widget showing the live native visualizer through a Flutter
  `Texture`. Its GL thread is independent of the UI thread and its size follows the widget. It
  pauses when hidden and supports the same scene, transition and parameter calls as the source
  `VisualizerView`.
- Pickers, permissions and system intents (SAF, MediaProjection consent, notification access,
  microphone) are bridge methods that return results. Dart never touches Android APIs directly.
- Channels: `geode/<viewModel>` method channels and `geode/<viewModel>/<flow>` event channels,
  using the standard codec. High-rate data (audio features at frame rate, the waveform) goes on
  its own event channel and is throttled on the Kotlin side to the display rate.

## Design-system contract (W3 provides, W4 consumes)

`package:geode/design/design.dart` and `package:geode/world/world.dart` export:

- `NatureWorld`: the full-screen 3D photoreal world behind every screen. It takes a
  `WorldStation` (one per destination plus `immersive`) and glides the camera between them. It
  reacts to `AudioFeatures`: bass ripples, beat light pulses and onset splashes.
- Glass kit:
  - `GlassOrbButton`: a water dome that ripples and grows energy veins on press.
  - `GlassPill`: a liquid pill button.
  - `GlassPanel` and `GlassCard`: panels that refract the world behind.
  - `GlassTubeProgress` and `GlassTubeSlider`: tubes filled with swirling liquid.
  - `GlassToggle`, `GlassCheck`, `GlassChip`, `GlassTabBar` and `GlassListRow`.
  - `GlassSearchField` and `GlassSheet` (a bottom sheet).
  - `GlassDialog`, shown with `showGlassDialog`.
  - `DropletHero`: the Now Playing water drop holding the artwork.
  - `LightThreads`: glowing curved links between widgets, located by `GlobalKey`s.
  - `BubbleField`, `InkSwirlTouch` (swirls trailing the finger) and `NotificationDroplet`.
- `MetaballGroup`: liquid bridging and morphing between adjacent glass controls.
- `GeodeNatureTheme`: tokens for type, spacing, glass and light colours, all taken from the
  photoreal palette.
- Every component has semantics, a 48 dp minimum touch target and a reduced-motion path. Each
  also has a flat fallback that works in widget tests and without Impeller (no shaders and no
  Flutter GPU).

## Rules for every workstream

- Follow `geode/GEMINI.md`: plan first, no placeholders, stubs or TODOs, keep files small and
  focused, and use RAII for native resources.
- Never build, compile or run tests locally. `dart analyze --fatal-infos` on what you touched
  is allowed and expected.
- Assets must be CC0 or created by us. Record each one in a `provenance.json` next to it.
- Commit in small, clear commits on your worktree branch. Every message ends with:

  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01T28863HT5AXtvu7DzfnVMv
  ```

  Do not put model identifiers anywhere else.
