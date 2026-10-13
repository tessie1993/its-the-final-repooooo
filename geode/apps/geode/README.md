# Geode Flutter UI

Nature-inspired interface with a shared touch-reactive gel field, photographic
moss/glass components and a raymarched 3D water sculpture. A transparent Flutter Scene GPU pass adds
faceted quartz, jade and dew with physically based materials.

Four destinations: Visuals, Music, Studio and Settings. Includes local audio
import/playback, queue and playlist management, saved visual presets, a five-lane
project editor, JSON import/export, and persisted appearance preferences.

The shader scene, nature assets and spring-driven components share one scene
behind every route. Audio position and editor playhead updates stay outside the
root app rebuild path.

Native music-reactive rendering, MilkDrop, video export and live wallpaper still
require Flutter host integration. Their C++ source is retained intact and the Flutter Android plugin now
packages the original CMake engine and native assets. Video render
is explicitly unavailable; project JSON export is implemented.

This is an integration checkpoint, not a verified release. Flutter/Dart startup
in the editing environment aborts with `Failed to retrieve stack bounds` before
analysis or builds. Dependencies and lockfile must be resolved on a working SDK.

From the `geode` workspace root, run `flutter pub get`, then from this directory
run `flutter analyze`, `flutter test`, and `flutter run` with Flutter 3.47.7 /
Dart 3.13.5. Initialize native dependencies with `git submodule update --init
--recursive` from the repository root before native build work.

See [the blueprint](../../docs/design/NATURE_UI_BLUEPRINT.md) for scene boundaries.
