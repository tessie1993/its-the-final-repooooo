# Engine source audit

Compared on 2026-10-13 before native host integration:

- Current repository: `tessie1993/its-the-final-repooooo`, native source at `f6b96e75e95c4d8793cb9ac9debe2dca2b4bb559` (unchanged by the Flutter UI checkpoint).
- [PR #1](https://github.com/tessie1993/its-the-final-repooooo/pull/1): head `13c47b663960b664a6c3c361b614355745e9cfb6`.
- [Visuals repository](https://github.com/tessie1993/visuals-its-the-final-repooooo): commit `bd709150fe5426a51f946110b9233424a4c2ab17`, source directory `geode-app-85491c2b76b26cf45c77f2f7fcda6b2f0d8855bd/`.

## Source already present

Git tree/blob identifiers were compared after mapping the visuals repository's source directory to `geode/`. These complete native subtrees are byte-identical in all three sources:

| Current path | Git tree | Contents |
| --- | --- | --- |
| `geode/core/` | `efc6537822abd7bd02b7ace4275ef68e6c86f2f3` | AMediaCodec player, Oboe output, DSP, analysis, visual renderer, fluid/particle scenes, MilkDrop integration |
| `geode/app/src/main/cpp/` | `101ba0350c2513d2949828053a5632c241e433c2` | Analysis, visualizer, tags, and player JNI adapters |
| `geode/app/src/main/assets/` | `23041054d5ae089bb084c45fde4bea7d7dff0506` | GLSL shaders, GL transitions, six starter `.milk` presets, notices |

The native engine is not missing its C++ implementation. Recopying these directories would add no functionality. `core/api/geode_api.h` and the generated Dart bindings already describe the player, DSP, analyzer, visualizer, touch, transition, and MilkDrop calls.

Across the full mapped snapshot, 496 files matched and 20 differed. Most of the 1,178 upstream-only paths are the old Compose interface (113), Android theme resources (996), and IDE metadata (16). The remainder includes old Android data/playback helpers and 18 Kotlin engine utilities/tests. These were not imported wholesale: the Flutter port does not use the old Compose application, and native equivalents already provide much of that engine behavior.

## Dependencies recovered from PR #1

The visuals repository is an extracted source snapshot: it contains `.gitmodules` but no `third_party` gitlinks. PR #1 retains the exact dependency revisions. The root `.gitmodules` and following gitlinks have been restored with paths relative to the actual repository root:

| Dependency path | Revision |
| --- | --- |
| `geode/third_party/kissfft` | `8f47a67f595a6641c566087bf5277034be64f24d` |
| `geode/third_party/oboe` | `b15f5e39c01a7ada306d959e5129620b145fb8b4` |
| `geode/third_party/projectm` | `e0b0a967f0ffd7d332106c366668ed271718472b` |
| `geode/third_party/taglib` | `7d86716194777e0294453bfdc9dd170bd033e1f4` |

Use `git submodule update --init --recursive` from the repository root. Recursive initialization succeeded during this audit. The existing projectM framebuffer backport patch passed `git apply --check` against its pinned checkout. CMake applies that patch when configuring the native engine.

## Integration gaps identified

At the start of this audit, the Flutter Android plugin did not declare `externalNativeBuild` or package the native engine's assets. Its method channel only returned an Android version string. The generated FFI bindings alone do not build, package, or host the engine.

The Flutter UI currently uses `just_audio` for local file playback and its own Flutter fragment shader for the nature scene. These are working implementations in source, but they are not the existing Oboe player or native MilkDrop renderer. Native support requires separate, real integration contracts:

1. Build and package `libgeode.so`, projectM, and their runtime dependencies with the existing root CMake target; include native shader/preset assets in the Android APK.
2. Own a native player handle, open file descriptors with explicit ownership transfer, propagate player state/errors, handle audio focus and lifecycle, and release all native resources. Only then switch UI playback from `just_audio`.
3. Own an Android GL surface or Flutter texture, pass its `AAssetManager` and cache path, render on a GL thread, and forward surface resize/context loss and touch events.
4. Feed the native player's actual PCM tap into analysis and MilkDrop, preserving the single-reader and audio-thread isolation contracts in `geode_api.h`.
5. Extract `.milk` assets to readable files before loading them, expose real scene IDs, and apply native transitions/parameters without inventing unavailable success states.

The existing native Android adapters are useful references for these contracts. They are not automatically part of the Flutter Android application.

## Packaging included in this checkpoint

The Flutter Android plugin now builds the existing root CMake target through
`externalNativeBuild` and packages the original native shader and MilkDrop asset
directory. The Flutter app and plugin use the existing native engine requirements:
Android API 26+, NDK 28.0.13004108, CMake 3.22.1, arm64-v8a and x86_64.
No C++ audio, DSP, PCM analyzer, visualizer or MilkDrop implementation was rewritten.

The native player control/descriptor bridge and PCM-to-visuals Flutter host are
not implemented in this checkpoint. Playback still uses just_audio. Packaging
these engines does not by itself make their runtime paths active.

## Attribution and verification limits

`geode/THIRD_PARTY_NOTICES` is byte-identical to the supplied visuals repository (blob `2e68abbbc32438963a3e729830034222d6130aeb`). Existing shader and source notices remain intact. In particular, projectM is dynamically linked under LGPL-2.1; its source, notices, framebuffer patch, and replaceable shared-library packaging must be retained. Dependency license files are provided by their pinned submodules. The current repository's root MIT license does not replace those third-party terms.

Verified here: source identity, dependency revisions, recursive dependency availability, and projectM patch applicability. These checks do not establish a successful Android native build, audible playback, GL rendering, or device performance. Flutter execution in this environment is blocked by a Dart VM stack-bounds failure; device/runtime integration must be validated separately before describing the native engine as active.
