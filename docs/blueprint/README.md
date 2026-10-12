# Geode → Flutter + C++ — Blueprint

This is the blueprint for rebuilding **Geode** (Android music player, real-time GPU music
visualizer and small video studio) as a fresh project: **Flutter for all UI**, **C++ for
audio, analysis, rendering and encoding**. No Kotlin.

The source is `tessie1993/visuals-its-the-final-repooooo` at commit `bd70915`
(folder `geode-app-85491c2b76b26cf45c77f2f7fcda6b2f0d8855bd`, Geode v1.8.0 / versionCode 32).
Look-alike repos (`geode-2`, `geode-3`, `geode-app`) are ignored on purpose. This blueprint
describes only that one snapshot.

## What was imported

Everything in the source except Kotlin now lives in [`geode/`](../../geode):

| Imported as-is | Path | Size |
|---|---|---|
| C++20 native core (analysis, DSP, player, tags, GLES renderer, scenes, fluid, compute) | `geode/core/` | 186 files, ~20.0k LOC |
| JNI glue (C++, to be replaced by the Dart FFI surface) | `geode/app/src/main/cpp/` | 5 files |
| Top-level CMake build | `geode/CMakeLists.txt`, `geode/core/CMakeLists.txt` | |
| GLSL ES 3.00 shaders + binary LUTs | `geode/app/src/main/assets/shaders/` | 95 `.glsl` (~16.2k LOC), 2 `.bin` |
| GL Transitions library (122 entries) | `geode/app/src/main/assets/gl_transitions.json` | |
| Starter MilkDrop presets | `geode/app/src/main/assets/milk/` | 6 `.milk` |
| Android resources (theme-pack art, UI sounds, fonts, launcher/widget icons, xml configs, strings) | `geode/app/src/main/res/` | 960 `.webp`, 30 `.wav`, 5 `.ttf`, 21 `.xml` |
| Android manifest (reference for permissions/services) | `geode/app/src/main/AndroidManifest.xml` | |
| Docs, privacy policy, wireframe, provenance registry | `geode/docs/` | |
| Dev tools (shader preview/check, projectM patch, oracle corpus, SDK setup) | `geode/tools/` | |
| CI workflows (Gradle-based, kept for reference, inactive in a subfolder) | `geode/.github/workflows/` | |
| Third-party native libs as **pinned git submodules** | `geode/third_party/{projectm,kissfft,taglib,oboe}` | |

Left out on purpose:

- every `.kt` file (290 files, 54,844 LOC) and every `.kts` Gradle script;
- `build-logic/` (Kotlin Gradle convention plugins), `config/detekt/`, the `*/detekt-baseline.xml` files, `gradle/`, `gradlew*`, `gradle.properties`, `.idea/`;
- the empty `engine/` module folders that only held Kotlin.

Submodule pins: projectM **v4.1.7** (the version the source's patch is written for, and
`tools/projectm-v4.1.7-render-fbo-backport.patch` applies cleanly to it), kissfft
**131.1.0**, TagLib **v2.1.1**, Oboe **1.9.3**. The source zip had no gitlinks, so only the
projectM pin comes from the source. The other three are recent stable tags I picked to keep the
build reproducible. Check them in phase 0.

## The documents

| # | Document | What it answers |
|---|---|---|
| 1 | [01-how-it-works.md](01-how-it-works.md) | Runtime architecture: the five pipelines (playback, live analysis, render, capture, export), threads, persistence, platform surfaces |
| 2 | [02-native-core-map.md](02-native-core-map.md) | Every C++ file in `geode/core` and the JNI glue: what it does, keep/modify/new |
| 3 | [03-kotlin-replacement-map.md](03-kotlin-replacement-map.md) | Every one of the 290 Kotlin files: what it did, and whether it becomes **Dart/Flutter**, **C++**, a **platform shim** or is **dropped** |
| 4 | [04-shaders-and-assets.md](04-shaders-and-assets.md) | Every shader and asset group, and how Flutter packages them |
| 5 | [05-target-architecture.md](05-target-architecture.md) | The new layered design: C ABI → Dart FFI → state → Flutter UI; the new C++ modules to write; folder layout; build |
| 6 | [06-migration-plan.md](06-migration-plan.md) | Phased, dependency-ordered plan with exit criteria, plus decisions that need you |

## How Graphify was used

The source repo is indexed in Graphify (`tessie1993/visuals-its-the-final-repooooo`,
10,308 nodes / 19,865 edges, built at `bd70915`). It supplied:

- the **hub analysis**: `ui/PlayerSession.kt` is the god-object. It has 185 symbols and 67 neighbour files, and it delegates to about 20 `*Controller` classes. That is why the target design splits it into separate Dart services (doc 5);
- the **native boundary**: `engine/bridge/GeodeNative.kt` has 92 `external` functions, and only 9 Kotlin files ever call them (`NativeViz`, `NativePlayer`, `NativeDspProcessor`, `ReactiveAnalyzer`, `NativePlayerDsp`, `NativeTags`, `NativeTapPump`, `DrumChannels`, `PulseReplay`). That small set is the whole FFI surface Dart has to replace;
- the **frame path**: `Renderer::render → drawSceneTarget → (trail) → setParams → deliverPcm → scene.update(features) → scene.draw → composite`, fed by `ReactiveAnalyzer.push → AnalysisSession::push/pull`.

## The short version

1. **Keep the C++ core almost untouched.** It already exposes a clean C ABI (`core/api/geode_api.h`) with opaque handles. Dart FFI binds to it directly, so no JNI is needed.
2. **Move the hot loops from Kotlin into C++.** These are the PCM rings, the hop-locked analysis thread, the feature ring, the presentation clock, mic and playback capture, the frame pacer, the offscreen exporter and the MediaCodec encoder. Under the Kotlin design they crossed JNI at 60–120 Hz. In the new design they never touch Dart. Dart only reads snapshots.
3. **The renderer owns its own EGL context in C++** and draws into a Flutter `SurfaceProducer`'s `ANativeWindow`. Flutter shows it with a `Texture` widget. This keeps the GL loop isolated from widget rebuilds.
4. **Port all the pure logic to Dart.** That covers the editor timeline, keyframes, templates, presets, playlists, smart playlists, library, lyrics, palettes, param catalog and randomizer. It is about 60% of the Kotlin and mostly pure functions.
5. **Some Android entry points can't be written in Flutter or C++.** These are the `MediaBrowserService`/Android Auto, the live wallpaper, the Daydream, the home-screen widget, the notification listener and the MediaProjection consent. Doc 6, decision D1, lists the options.
