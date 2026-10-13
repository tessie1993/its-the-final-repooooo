# 7 · Rebuild plan: Player · Visualizer · Export Studio

**This doc supersedes doc 6 for scope.** The product is three things:

1. **Music player**: local library, queue, transport, EQ.
2. **High-end music visualizer in C++**: every visual style the engine has, driven by the existing analysis.
3. **Export studio**: render the visualizer to video, frame-exact, plus timeline editing.

Everything here reuses the existing C++ audio engine and visual styles. The Kotlin app is not
ported file by file. We keep what the three pillars need and rebuild the rest smaller and
cleaner.

---

## 7.1 What we take as-is (no rewrite)

| Asset | Path | Used by |
|---|---|---|
| Audio analysis: FFT, 64 bands, onsets, tempo/beat/bar, drums, chroma/key, structure, stereo | `geode/core/analysis/*` | Visualizer, Studio |
| Playback DSP: gain, 10-band EQ + bass boost, crossfeed, limiter | `geode/core/audio/dsp/*` | Player |
| Native player: decode → resample → gapless/crossfade mixer → Oboe | `geode/core/audio/player/*` | Player |
| Tag read/write (TagLib) | `geode/core/library/*` | Player |
| Renderer frame graph, composite, trails, overlays, safety clamp, LFO/ADSR, motion, thermal tiers, touch | `geode/core/viz/*` | Visualizer, Studio |
| Every scene family: ~40 shader styles, Fluid ×9, Curl Flow, Water, Silk, Life, Acid, Myco, Cymatics, MilkDrop | `geode/core/viz/scenes`, `fluid`, `compute` | Visualizer, Studio |
| 95 shaders, LUTs, 122 GL Transitions, starter `.milk` presets | `geode/app/src/main/assets/*` | Visualizer, Studio |
| C ABI (`geode_analysis_*`, `geode_dsp_*`, `geode_player_*`, `geode_tags_*`, `geode_viz_*`) | `geode/core/api/*` | Dart FFI |
| Third-party: projectM, kissfft, TagLib, Oboe | `geode/third_party/*` | |

That is about 20k lines of C++ and 16k lines of GLSL. It is the hard, high-value part, and it
already works.

## 7.2 What we rebuild

### C++ (new native code: the parts Kotlin used to do on hot paths)

| # | Module | Purpose | Based on (old Kotlin design) |
|---|---|---|---|
| N1 | `PcmRing` | Lock-free, sample-indexed PCM ring with epochs and explicit gap reporting | `PcmRingBuffer`, `SampleRing`, `AUDIO_FEATURE_ABI.md` |
| N2 | `AnalysisThread` + `FeatureRing` | Hop-locked live analysis → timestamped feature frames | `AnalysisEngine`, `FeatureRing` |
| N3 | `PresentationClock` | Maps audio played ↔ on-screen time (latency, seeks) | `AudioPresentationClock` |
| N4 | `Engine` | Wraps `Player` + DSP chain + tap → `PcmRing`; one C API for Dart | `NativePlayer`, `NativeTapPump`, `NativePlayerDsp` |
| N5 | `RenderHost` | Own EGL context + render thread drawing into a Flutter `Texture`; feeds features at presentation time | `VisualizerView`, `VisualizerRenderer` |
| N6 | `FramePacer` | `AChoreographer` vsync pacing, fps cap, thermal feed | `FramePacer`, `ThermalGovernor` |
| N7 | `OfflineAnalysis` + cache | Decode a whole track → feature timeline on disk (for the seek bar, Studio and export) | `OfflineAnalyzer`, `AnalysisCache`, `FeatureTimeline` |
| N8 | `VideoExport` | Offscreen `geode_viz` frame by frame from the timeline → `AMediaCodec` H.264/HEVC + AAC → `AMediaMuxer` | `VideoExporter`, `EncoderSurface`, `AudioTranscoder` |
| N9 | `Loudness` | BS.1770 LUFS metering of exports | `LoudnessMeter` |
| N10 | `Compositor` (Studio v2) | Clip decode → grade/LUT/transition GL chain → encode | Media3 Transformer path |
| N11 | Time-stretch (optional) | Speed/pitch control; ExoPlayer did this before | — (vendor a library) |

### Dart / Flutter (new app code)

| # | Area | Contents | Reference |
|---|---|---|---|
| D1 | Native bridge | `ffigen` bindings, handle wrappers with finalizers | `GeodeNative`, `NativeViz` |
| D2 | Player | Library scan (MediaStore/folders), track list, search, queue, playlists, transport, mini player, EQ, ReplayGain, sleep timer, lyrics | `ui/Library*`, `QueueController`, `playback/*` |
| D3 | Visualizer | Fullscreen view (`Texture`), style browser, Customize panel (params/locks/randomize, LFO/ADSR, palettes), presets (save/share), transitions, background image, touch | `VisualizerScreen`, `VisualsHub`, `CustomizeTabs`, `render/scene/*` |
| D4 | Studio | Track + range picker, export settings (codec/quality/aspect/fps), progress + ETA, loudness readout, clip library. v2: timeline (lanes, keyframes, markers, auto-cut, captions, transitions) | `ExportController`, `editor/*`, `ui/studio/*` |
| D5 | Data | JSON stores (presets, playlists, projects, prefs) with atomic writes; preset JSON stays compatible with the old app | `data/*` |
| D6 | Design system | One clean theme first, with dark and glass styling to match the visuals | `Crystal*`, `StoneTheme` |

### Data to recover from the old Kotlin (step 0)

The Visualizer and Studio need these, and they exist only in Kotlin source:

| Data | From | Needed for |
|---|---|---|
| Scene/style catalog (ids, labels, families, capabilities) | `SceneIds`, `SceneCapabilities`, `VisualStyleCatalog` | Style browser |
| Parameter names, defaults, which params apply to which style | `ParamKeys`, `SceneParams`, `ParamScope` | Customize panel |
| Built-in presets (13 looks) | `BuiltInPresets` | Visualizer |
| Bundled video templates (6) | `TemplateRepository` | Studio |
| EQ presets | `AudioFxPresets` | Player |

Method: compile those files once with stubs and dump them to JSON, so the values are exact.
This had started and is paused. Hand-porting is the fallback.

## 7.3 What we drop or defer

| Feature | Decision |
|---|---|
| Android Auto, lock-screen browse tree | **Defer.** Keep basic media notification + lock-screen controls (needed for background playback) |
| Live wallpaper, Daydream, home-screen widget, second screen | **Defer** (the `RenderHost` makes them cheap to add later) |
| Visualizing other apps' audio (MediaProjection), notification listener | **Defer** |
| Microphone input | **Optional, cheap** (Oboe input → `PcmRing`) |
| 10 "stone" theme packs (960 images, sounds, haptics) | **Defer.** Ship one theme; the art stays in `geode/` for later |
| ExoPlayer / Media3 | **Drop.** The native engine is the only player |
| Performance takes, smart playlists, duplicate finder, tag editing UI | **Later** |
| Loop render / loop-extend (hours-long) | **Studio v2** |
| Bit-perfect USB | **Drop for now** |

## 7.4 Milestones

| M | Deliverable | Exit test |
|---|---|---|
| **M0 Foundation** | Flutter app created (`app/`), native moved to `native/` with CMake wired into the Flutter Android build, JNI files removed, catalog data recovered to JSON | `flutter build apk` builds `libgeode.so` for arm64 + x86_64 |
| **M1 First frame** | N5 RenderHost + N6 pacer + D1 bridge: one shader style on screen in a `Texture`, driven by a test tone through N1/N2 | Style animates to the tone at 60 fps; no Dart work per frame |
| **M2 Player** | N4 Engine + N3 clock + D2: scan library, play, queue, seek, EQ, notification controls | A real track plays gaplessly, the visuals react in sync |
| **M3 Visualizer** | D3: every style selectable, Customize panel, presets, transitions, background, touch, MilkDrop presets | Every scene in the catalog renders; presets round-trip |
| **M4 Studio v1** | N7 + N8 + N9 + D4: pick track + range + style/preset → frame-exact video with audio, saved to the gallery | Exported MP4 matches the live look; LUFS shown |
| **M5 Studio v2** | Timeline editor: keyframes, markers, auto-cut, captions, clip lanes + N10 compositor, GL Transitions | Multi-clip project exports |
| **M6 Polish** | Performance/thermal, safety review, theme work, deferred features as wanted | Device checklist passes |

## 7.5 How we build it (fleet, approved: small)

After M0 lands (I do it solo, because everything depends on it), work splits into parallel tracks
with fixed contracts:

| Worker | Owns | Input contract |
|---|---|---|
| Native-audio | N1–N4, N7 | `geode_api.h` + new `geode_engine_*` header written first |
| Native-render | N5, N6, then N8–N10 | `geode_surface_*`, `geode_export_*` headers |
| Dart-player | D1, D2, D5 | Engine header + ffigen |
| Dart-visualizer | D3, D6 | Viz header + catalog JSON |
| Dart-studio | D4 | Export header + editor domain spec |

I write every header contract before any worker starts. Each worker delivers one module per
commit.

## 7.6 Open decisions

| # | Question | Default if you don't choose |
|---|---|---|
| Q1 | Studio v1 scope: visualizer-to-video only, or include the timeline editor straight away? | Visualizer-to-video first (M4), timeline in M5 |
| Q2 | Mic input in the first release? | Yes, it is cheap |
| Q3 | Speed/pitch control in the player? | Later (needs a vendored time-stretch library, licence check) |
| Q4 | Keep old preset/template JSON compatibility? | Yes |
| Q5 | Theme direction: one new theme, or port one stone pack first? | One new dark glass theme |
