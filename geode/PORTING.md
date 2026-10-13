# Kotlin → Flutter port

Geode is moving from a Kotlin Android app to Flutter. Logic is written in Dart, and the C++
engine is called directly through `dart:ffi`. The only Kotlin left is the Android entry points
that cannot be Dart: Android has to instantiate them as Android classes.

The source being ported is the Kotlin under `app/src/main/java/dev/geode/` and `engine/*/src/main/kotlin/`.
`KOTLIN_INVENTORY.md` lists every file. When the port is done, the old `app/`, `engine/`,
`build-logic/` and Gradle files are deleted.

## Layout

| Path | What | Owner |
|---|---|---|
| `pubspec.yaml` | Pub workspace root | integrator |
| `apps/geode/lib/` | The Flutter app: bootstrap and the background Dart entrypoints | integrator |
| `apps/geode/android/` | Android host: manifest, `MainActivity`, Gradle | native |
| `packages/geode_native/` | ffigen bindings to `core/api/geode_api.h` (`geodeApi`), the Kotlin plugin with the irreducible Android classes, the C++ surface/render host | native |
| `packages/geode_engine/` | Port of `engine/audio-core`, `engine/scenes` (minus GL surface plumbing), `app/.../viz` | engine |
| `packages/geode_data/` | Port of `app/.../data` | data |
| `packages/geode_editor/` | Port of `app/.../editor` | editor |
| `packages/geode_playback/` | Port of `app/.../playback`, `app/.../audio` (minus capture), `app/.../widget`, `engine/audio-android` | playback |
| `packages/geode_export/` | Port of `app/.../export` and `engine/scenes/.../offscreen`, plus native encoders in `core/export/` | export |

Only edit files you own. If you need something from a package you don't own, code against the
name the mirroring rule below predicts. The integrator reconciles the packages afterwards.

## Naming: mirror the Kotlin

- One Kotlin file becomes one Dart file. `dev/geode/<pkg path>/FooBar.kt` becomes
  `lib/<pkg path>/foo_bar.dart` inside the owning package. Example:
  `engine/scenes/.../dev/geode/render/scene/SceneParams.kt` becomes
  `packages/geode_engine/lib/render/scene/scene_params.dart`, imported as
  `package:geode_engine/render/scene/scene_params.dart`.
- Keep the Kotlin type, member and constant names: classes stay `UpperCamel`, members become
  `lowerCamel`, and `const val FOO_BAR` becomes `static const fooBar`. Kotlin `object Foo`
  becomes a Dart class with static members, or a top-level `final foo` instance when it holds
  state. A `data class` becomes an immutable class with `==`, `hashCode` and `copyWith`. A
  `sealed interface` becomes a Dart `sealed class`.
- `StateFlow` and `Flow` become `Stream`/`ValueListenable` (`ValueNotifier` for state).
  Coroutines become `async`/`await`, isolates for CPU-heavy work, and `Timer` for polling loops.
- `org.json` becomes `dart:convert`. Keep the exact JSON keys and file formats, so files written
  by the Kotlin app still load.
- `SharedPreferences` keys and file names under the app's files dir stay byte-identical. Users'
  data must survive the upgrade.

## Native boundary

- Call libgeode through `package:geode_native/geode_native.dart` (`geodeApi`, generated from
  `core/api/geode_api.h` by `packages/geode_native/tool/ffigen.dart`). Never hand-write
  `DynamicLibrary.lookup` bindings. New native APIs get a header under `core/api/` and an ffigen
  script.
- New C++ goes in `core/host/` (native owner) or `core/export/` (export owner). Each directory has
  its own `CMakeLists.txt` defining an OBJECT library `geode_host_core` / `geode_export_core`.
  The root `CMakeLists.txt` already picks them up.
- Android APIs that Dart can't reach (MediaStore, ContentResolver file descriptors, AssetManager,
  Surfaces, services, MediaProjection, the thermal API) are reached through the `geode_native`
  plugin's method channels, or through a maintained pub.dev plugin when a good one exists:
  `audio_service` for the media session, Android Auto and the notification;
  `home_widget` for the widget; `path_provider`; `shared_preferences`.
- Kotlin is allowed only in `packages/geode_native/android/` and `apps/geode/android/`, and only
  for Android classes that cannot be anything else. Keep it thin: no logic that could live in
  Dart or C++.

## Quality bar (from GEMINI.md)

- Complete, production code. No `TODO`, stubs, placeholders, `UnimplementedError` or "rest omitted".
- Port behaviour faithfully, including edge cases and the numeric details (clamps, rounding,
  overflow guards). Keep comments that explain *why*; drop comments that narrate *what*.
- No dead code: if nothing in the port calls it and it isn't public API of the package, leave it out.
- Every package ships a barrel file `lib/<package>.dart` that exports its public files, plus unit
  tests under `test/` for its pure logic.
- `flutter analyze` (run from the package dir) must report zero issues, and `flutter test` must pass.

## Shared contracts

These are fixed up front so the packages can be ported in parallel. If a contract turns out
wrong, implement the closest correct thing and note the change in your package README under
"Contract changes".

### `geode_native` Dart API (native owner implements, everyone else consumes)

`package:geode_native/geode_native.dart` exports:

- `geodeApi`: the ffigen bindings (`GeodeApi`) to `libgeode.so`.
- `class GeodeAndroid` (static methods over the plugin's method channel `dev.geode/native`):
  - `Future<int> openFd(String uri, {String mode = 'r'})` returns a detached file descriptor for a
    `content://` or `file://` uri; ownership passes to the caller. `Future<void> closeFd(int fd)`.
  - `Future<List<DeviceAudioRow>> queryAudio()` returns MediaStore audio rows, with fields `uri`, `title`,
    `artist`, `album`, `folder`, `durationMs`, `addedSec` (the columns `DeviceTrackQuery.kt` reads).
  - `Future<int> assetManager()` returns the native `AAssetManager*` (as an int address) for
    `geode_viz_create`. Shaders and `.milk` packs stay Android assets (`app/src/main/assets`).
  - `Future<ThermalReading> thermal()` (`status`, `headroom`) and `Stream<int> thermalStatus`.
  - `Future<void> startForegroundWork({required String kind, required String title, required String text})`
    and `Future<void> stopForegroundWork(String kind)`. `kind` is `export` (mediaProcessing/dataSync
    service) or `capture` (mediaProjection service). This is the foreground-service shell the
    Kotlin `ExportService` and `PlaybackCaptureService` used to be.
  - `Future<bool> requestPlaybackCapture()` (consent dialog plus capture start),
    `Future<void> stopPlaybackCapture()`, `Stream<Float32List> playbackCapturePcm`
    (interleaved stereo float at `captureSampleRate`), and the same trio for the microphone:
    `startMic()`, `stopMic()`, `Stream<Float32List> micPcm`.
  - `Future<NowPlayingInfo?> otherAppNowPlaying()` and `Future<bool> notificationAccessGranted()`,
    `Future<void> openNotificationAccessSettings()` (what `NowPlayingBridge.kt` did).
- `class VisualizerSurface`: a Flutter `Texture` backed by a native surface that the C++ host in
  `core/host/` renders a `geode_viz*` into on its own render thread, with frame pacing and the
  thermal governor. It exposes `textureId`, `Future<void> resize(int w, int h)`, a pointer to the `geode_viz`
  so Dart can drive it through `geodeApi.geode_viz_*`, `pause()`/`resume()`, and `dispose()`.

### Widget (playback owner publishes, native owner renders)

`home_widget` keys: `title` (String), `artist` (String), `playing` (bool), `art_path`
(String, a PNG file path or empty). Widget taps are `geode://widget/<command>`, where command is
`play_pause`, `next`, `previous` or `open`. The provider is `dev.geode.geode_native.NowPlayingWidgetProvider`.

### Background Dart entrypoints (integrator writes, native owner launches)

The live wallpaper and the screensaver run a headless `FlutterEngine` on the app's Dart bundle,
with entrypoints `wallpaperMain` and `dreamMain` in `apps/geode/lib/background_entrypoints.dart`.
The engine receives the surface through `VisualizerSurface` APIs the native owner documents in
`packages/geode_native/README.md`.
