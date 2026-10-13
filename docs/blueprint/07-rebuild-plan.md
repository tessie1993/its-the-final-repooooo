# 7 · Rebuild plan: what we reuse, what we rebuild

The product is three things on one engine:

1. **Music player**: library, queue, playback with the native audio engine.
2. **High-end music visualizer (C++)**: the existing visual styles on a native render host.
3. **Export studio**: the visuals and cuts rendered to video.

The UI is new, written in Flutter. The C++ engine, shaders and visual styles are kept. Everything the
Kotlin did is either rebuilt in Dart (UI, state, logic, storage) or moved down into C++ (anything on
the audio, render or encode path).

The basic navigable UI in [`app/`](../../app) already contains every screen of the old app. Each
milestone below replaces some of its placeholder pages with real ones.

## 7.1 Reuse as-is (no rewrite)

| What | Where | Used by |
|---|---|---|
| Audio analysis: FFT, 64 bands, onsets, tempo, beat grid, bars, drums, chroma, key, structure, stereo | `geode/core/analysis` | Visualizer, Studio, Player spectrum |
| Native player: MediaCodec decode, Hermite resampler, gapless/crossfade mixer, Oboe output | `geode/core/audio/player` | Player |
| DSP chain: gain, 10-band EQ, bass boost, crossfeed, lookahead limiter | `geode/core/audio/dsp` | Player |
| Tags (TagLib): read/write, ReplayGain, embedded art | `geode/core/library` | Library |
| Renderer: frame graph, params, LFO/ADSR, transitions, safety clamp, thermal tiers, program cache | `geode/core/viz` | Visualizer, Studio |
| Scenes: shader styles, Fluid (9 looks), Curl Flow, Water, Silk, Life, Acid, Mycelium, Cymatics, MilkDrop | `geode/core/viz/{scenes,fluid,compute}` | Visualizer, Studio |
| 95 GLSL shaders, blue noise, cyclic palettes, 122 GL Transitions, 6 starter `.milk` | `geode/app/src/main/assets` | Visualizer, Studio |
| The C API (`geode_api.h`) | `geode/core/api` | Dart FFI binds to it directly |
| Third-party libs: projectM 4.1.7 (+ patch), kissfft, TagLib, Oboe | `geode/third_party` | — |
| Fonts, theme-pack art and UI sounds | `geode/app/src/main/res` | Optional: only if the new design keeps the stone themes |

## 7.2 Rebuild in C++ (replacing Kotlin hot paths)

These were Kotlin calling into C++ 60–120 times a second over JNI. They move fully native, so the
audio and render loops never wait on Flutter.

| New native module | Replaces (Kotlin) | Needed for |
|---|---|---|
| `PcmRing` + `AnalysisThread` + `FeatureRing` + `PresentationClock` | `PcmRingBuffer`, `SampleRing`, `AnalysisEngine`, `FeatureRing`, `AudioPresentationClock`, `PcmTap`, `NativeTapPump` | Visualizer reacting in sync with what you hear |
| `Engine` (player + DSP + tap, one handle for Dart) | `NativePlayer`, `NativePlayerDsp`, `PlaybackEngine` | Player |
| Time-stretch (speed/pitch) and skip-silence in the mixer | Media3's Sonic and silence-skipping processors | Player (ExoPlayer is dropped) |
| `RenderHost` (EGL context + render thread on a Flutter `SurfaceProducer`) + `FramePacer` (AChoreographer, thermal) | `VisualizerView`, `VisualizerRenderer`, `FramePacer`, `ThermalGovernor` | Visualizer |
| `CaptureSource` (Oboe input) | `MicCapture`, `AudioCapturePump` | Visualizer on microphone input |
| `OfflineAnalysis` + analysis cache + `FeatureTimeline` | `OfflineAnalyzer`, `AnalysisCache`, `FeatureTimeline`, `FrameAccumulator`, `AiffPcm` | Studio, waveform seek bar |
| Export: offscreen render → `AMediaCodec` (H.264/HEVC + AAC) → `AMediaMuxer`, LUFS meter | `VideoExporter`, `EncoderSurface`, `AudioTranscoder`, `LoudnessMeter`, `OffscreenSceneRenderer` | Studio |
| Loop render + loop-extend (remux) | `LoopRender`, `LoopExtend` | Studio |
| Timeline compositor (decode clips → GL effects, LUTs, transitions, captions → encode) | Media3 Transformer path (`StudioExporter`, `ProjectComposition`, `ClipEdit`…) | Studio timeline export |
| FFI surface (`geode_engine_*`, `geode_surface_*`, `geode_capture_*`, `geode_export_*`) | `GeodeNative` (JNI) | Everything |

## 7.3 Rebuild in Flutter/Dart

The architecture follows the official Flutter architecture skill: a UI layer of views + ChangeNotifier
view models, a data layer of repositories + services, and an optional domain layer.

| Area | Rebuilt from (Kotlin) | Notes |
|---|---|---|
| All screens | `ui/*`, `ui/studio/*`, `ui/theme/*` | New design; the basic skin is the placeholder |
| Library: MediaStore scan, folders, track store, search, sort, duplicates | `MusicLibraryController`, `TrackLibrary`, `LibraryBrowse`, `LibraryDuplicates` | MediaStore through a plugin |
| Playlists, smart playlists, M3U/PLS/XSPF | `MusicPlaylistStore`, `SmartPlaylistStore`, `PlaylistFormats` | Same JSON formats |
| Queue, history, sleep timer, ReplayGain, bookmarks, fades | `QueueController`, `HistoryStore`, `SleepTimer`, `ReplayGain`, `TrackBookmarks`, `PlaybackFades` | |
| Visual settings, presets, templates, textures, takes | `VisualSettingsController`, `PresetStore`, `TemplateFormat`/`Repository`, `TextureStore`, `TakeStore` | Same JSON so old presets load |
| Customize: parameter catalog, scopes, randomizer, A/B, locks | `SceneParams`, `ParamKeys`, `ParamScope`, `ParamRandomizer`, `ParamBlend`, `ModulationController` | Parameter order comes from `geode_viz_param_name` |
| Auto visuals, scene suggestion, key/art palette | `AutoVisualsController`, `SceneSuggester`, `KeyPalette`, `ArtPalette` | |
| Studio editor model: timeline, keyframes, markers, auto-cut, subtitles, chapters | `editor/*`, `ChapterMarkers` | Pure logic, a direct port |
| Share links (presets, templates) | `PresetLink` | Same bounded-inflate limits |

## 7.4 Data that only exists inside Kotlin: extract first

The theme packs, built-in presets, bundled templates, style catalog, parameter names and scopes,
scene capabilities, icon paths, EQ presets, help and tutorial copy live only in Kotlin source. They
are extracted to JSON by compiling those files once and dumping their values. That way nothing is
re-typed by hand.

Status: the extraction workspace compiles most of them. It was **paused at your request** before the
last two dependencies were added. Finishing it is the first task of milestone 1.

## 7.5 Drop or defer

| Item | Decision | Why |
|---|---|---|
| ExoPlayer / Media3 playback path, platform audiofx | **Drop** | The native engine already does gapless, crossfade, EQ and bit-perfect |
| Hilt, Compose theme machinery, Kotlin mirrors of native math (`CymaticsMath`, `VisualSafety`, `LiveSignal`) | **Drop** | Replaced by Flutter or already native |
| Android Auto browse tree, home-screen widget | **Defer** to milestone 4 | Needs Android shims (see D1 in doc 6) |
| Live wallpaper, screensaver, second screen, PiP | **Defer** to milestone 4 | Reuse `RenderHost` behind thin Java shims |
| Other apps' audio capture (MediaProjection) | **Defer** to milestone 4 | Java-only API; shim feeds the C++ ring |
| Stone theme packs (960 images, sounds, haptics) | **Your call** | Keep if the new design wants them, otherwise retire |

## 7.6 Milestones

Each milestone ends with something you can install and use. Placeholder pages in `app/` are replaced
as their milestone lands.

| # | Milestone | Native work | Flutter work | Pages made real |
|---|---|---|---|---|
| 0 | **Foundation** | CMake builds `libgeode.so` inside the Flutter app; FFI bindings via ffigen | Finish the Kotlin data extraction (§7.4) | — |
| 1 | **Music player** | `Engine` (player + DSP + tap), time-stretch, skip-silence | Library, queue, playlists, smart playlists, transport, EQ, background playback + media notification | Player, Library (all tabs), Queue, Settings › Audio |
| 2 | **Visualizer** | `RenderHost`, `FramePacer`, `PcmRing`/`AnalysisThread`/`FeatureRing`/`PresentationClock`, `CaptureSource` (mic) | Styles, Customize, presets, MilkDrop + textures, auto visuals, background image, touch | Visualizer (full screen), Visuals hub (all tabs) |
| 3 | **Export studio** | `OfflineAnalysis`, export pipeline, LUFS, loop render, then the timeline compositor | Clip library, clip editor, export screens, then the timeline editor | Studio (all pages), Settings › Export |
| 4 | **Everywhere else** | Shims: media session/Android Auto, wallpaper, screensaver, widget, capture service | Takes, templates, second screen, PiP | Remaining placeholders |

## 7.7 Decisions for you

- **D1:** Android shims for the deferred features. They can't be written in Flutter or C++ (doc 6).
- **Theme packs:** keep the stone themes in the new UI, or retire them (§7.5).
- **Order:** is Player → Visualizer → Studio right, or should the visualizer come first? It can run on the microphone before the player is rebuilt.
