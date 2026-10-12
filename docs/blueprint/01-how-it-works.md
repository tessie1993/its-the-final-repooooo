# 1 · How Geode works today

This describes the Kotlin + C++ app as it stands at source commit `bd70915`. The paths are
from the original tree. Kotlin files are named for reference only, because they were not
imported. [doc 3](03-kotlin-replacement-map.md) says where each one goes.

## 1.1 Product surface

| Area | What the user gets |
|---|---|
| **Player** | MediaStore library, SAF folder roots and imports, queue, favourites, playlists (M3U/PLS/XSPF import), smart playlists (rule engine), duplicate finder, fuzzy multi-term search, timed lyrics (`.lrc`/embedded), A-B repeat, fades, sleep timer, 10-band EQ + bass boost + loudness, ReplayGain, speed/pitch, skip silence, resume bookmarks for tracks over 20 min, tag editing that writes back into the file (TagLib) |
| **Native engine (opt-in)** | Gapless joins, crossfades (linear / equal-power / smooth), bit-perfect USB output on Android 14+ |
| **Visualizer** | About 40 fragment-shader styles, particle and simulation families (Fluid ×9 looks, Curl Flow, Water, Silk, Life, Acid, Myco, Cymatics), MilkDrop via projectM 4, GL Transitions between scenes, layer mixing, a background underlay image, an in-app GLSL editor, a Customize panel (Shape/Color/Motion/FX/Reactivity/Scene tabs, per-param locks, randomizer, 3 LFOs + 2 ADSRs, palette maker, A/B snapshot blend, presets as JSON + `.milk`), an unconditional photosensitivity clamp, touch interaction |
| **Auto visuals** | Visual playlists, random mode, "intelligence" scene suggestion from track analysis, key→colour, artwork palette |
| **Studio** | Multi-lane timeline (visual/media/text/overlay/audio), trim/split/ripple/snap, markers (manual / tapped / detected), auto-cut from transients, keyframe curves (bezier), GL Transitions between clips, speed ramps, `.cube` LUTs, captions from lyrics/SRT, chapter export. Visualizer export is frame-exact from the analysis timeline. Cut export runs on Media3 Transformer. H.264/HEVC, loudness metering (BS.1770/LUFS), long-form loop render + loop-extend |
| **Ambient** | Live wallpaper, Daydream screensaver, second-screen (Presentation), picture-in-picture, home-screen widget, Android Auto browse tree |
| **Other apps' audio** | Android 10+ `AudioPlaybackCapture` (MediaProjection) and microphone feed the same PCM ring as the player |
| **Theming** | 10 "stone" theme packs (Amethyst, Azurite, Clear Quartz, Firestone, Kyanite, Lapis Lazuli, Malachite, Mookaite, Onyx, Sugilite): 960 state-art `.webp`s, 3 UI sounds per pack, haptic cues, fonts |

The app has no network permission. Everything stays on the device.

## 1.2 Layering (old)

```
┌──────────────────────────── Jetpack Compose UI (ui/, ui/studio/, ui/theme/) ─────────────────────────────┐
│ MainActivity → AppShell → {Player, Library, Visuals hub, Studio, Settings}  ·  5 ViewModels (Hilt)       │
├──────────────────────────────────────── PlayerSession (god-object) ──────────────────────────────────────┤
│ ~20 controllers: Queue, Capture, TrackAnalysis, AutoVisuals, Modulation, PresetLibrary, Template, Take,   │
│ Texture, MilkImport, Background, TrackColor, PlayerSettings, VisualSettings, Export, Editor, Listening…   │
├──────────────── data/ (JSON-file stores, SharedPrefs)  ·  editor/ (pure timeline model)  ·  export/ ─────┤
├──────────── playback/ (Media3 ExoPlayer or NativePlayer, MediaLibraryService, Android Auto) ─────────────┤
├──────── engine/scenes (Kotlin): analysis/, render/ (VisualizerView, FramePacer, NativeViz bridge) ───────┤
├──────── engine/audio-core (Kotlin): GeodeNative JNI decls, FeatureRing, SampleRing, clocks ──────────────┤
├──────── engine/audio-android (Kotlin): PcmTap (Media3 TeeAudioProcessor), SinkClockDriver ───────────────┤
╞══════════════════════════════════ JNI (app/src/main/cpp/*_jni.cpp) ══════════════════════════════════════╡
│ libgeode.so  ←  geode_core (C++20): api/ · analysis/ · audio/dsp · audio/player · library/ · viz/ · util/ │
│ third_party: projectM 4.1.7 (patched) · kissfft · TagLib · Oboe  ·  NDK: mediandk, GLESv3, EGL, android │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## 1.3 Pipeline A: playback

Two interchangeable engines sit behind the same Media3 `Player` interface, so the session,
notification and UI never know which one is running.

**Default, ExoPlayer:**
```
file/URI → ExoPlayer → DefaultAudioSink ── MvzAudioProcessorChain
                                              1. TeeAudioProcessor(PcmTap)   ← analysis tap (always first)
                                              2. SilenceSkippingAudioProcessor
                                              3. SonicAudioProcessor (speed/pitch)
                                              4. NativeDspProcessor → geode_dsp (gain→EQ→crossfeed→limiter)
                       → AudioTrack → platform audiofx (Equalizer/BassBoost/LoudnessEnhancer on the session id)
```

**Native, `playback/NativePlayer.kt` → `geode_player_*`:**
```
fd → Decoder (AMediaExtractor+AMediaCodec, float stereo) → Resampler (Hermite) → Deck (SPSC ring)
   → Mixer (gapless / crossfade, owns DSP chain, RT-safe swap) → Output (Oboe, exclusive when granted) → device
                                         └→ tap ring → geode_player_read_tap → NativeTapPump → PcmTap
```

Rules from `geode/docs/AUDIO_CHAIN.md` that the new design must keep:

1. **The analysis tap is first.** User DSP is downstream, so live features match offline/exported features for the same file. EQ and ReplayGain never change the picture.
2. **Never enable float sink output.** That applies to Media3. The native engine is float end to end.

Supporting pieces:
- `PlaybackService` is a `MediaLibraryService` with the session, notification and the Android Auto tree (`LibraryTree`).
- `PlaybackEngine` handles refcounted acquire/release by the UI and the service.
- `QueueOps`, `SleepTimer`, `ReplayGain` (reads the tags and drives the gain stage), `TrackBookmarks`, `PlaybackErrors` (skip, stop or explain), `BitPerfectOutput` and `SessionBitmapLoader` (embedded art).

## 1.4 Pipeline B: live analysis (the heart of the visuals)

```
PCM sources ─┬─ PcmTap (player)              ┐
             ├─ NativeTapPump (native player) ├→ PcmRingBuffer / SampleRing (lock-free, epoch-tagged, mid+side)
             ├─ MicCapture (AudioRecord)      │        │
             └─ PlaybackCapture (MediaProj.)  ┘        ▼
                                          AnalysisEngine thread (hop-locked)
                                          ReactiveAnalyzer → geode_analysis_push / pull
                                                 │ (C++ AnalysisSession: window → kissfft Spectrum →
                                                 │  LogBands(64) · SuperFlux · OnsetPeakPicker · AdaptiveWhitening ·
                                                 │  TempoTracker · TempoStability · BeatGrid · BarTracker ·
                                                 │  DrumChannels(kick/snare/hat) · Chromagram · KeyDetector ·
                                                 │  HarmonicBalance · StructureTracker · StereoField · FrameLevels)
                                                 ▼
                                    GeodeFeatureFrame (33 scalars + 64 bands + 128 waveform + 12 chroma = 237 floats)
                                                 │
                         PulseHold (stretch 1-hop pulses across a display frame)
                                                 ▼
                    FeatureRing (timestamped) + AudioPresentationClock (sink latency → presentation time)
                                                 ▼
                         renderer asks "features at presentation time t" → interpolated frame
```

- **Offline path:** `OfflineAnalyzer` decodes the whole file with MediaCodec and runs the same analyzer to build a `FeatureTimeline`. `AnalysisCache` stores it on disk (versioned columns). Users: the seek-bar waveform, export (frame-exact), auto-cut, scene suggestion, section staging and BPM-aware glides.
- **Tuning:** `BeatTuning` (sensitivity, refractory) and `LiveInputProfile` (mic vs. tap presets). `PulseReplay` re-decides beats from cached flux under new tuning without re-decoding.
- **Colour from audio:** `KeyPalette` (detected key → hue) and `ArtPalette` (artwork → palette).

## 1.5 Pipeline C: render

```
VisualizerView (GLSurfaceView) ← FramePacer (Choreographer vsync, divisor/cap, thermal tier)
   └ GL thread: VisualizerRenderer.onDrawFrame
        hands over @Volatile state → NativeViz → geode_viz_* (latched setters) → geode_viz_render(t, fbo)
             C++ Renderer::render:
               LFO/ADSR tick (viz/Lfo, viz/Adsr) → VisualSafety clamp → MotionField
               drawSceneTarget: [TrailPass] → scene.setParams → deliverPcm → scene.update(features, dt) → scene.draw
               [secondary scene for transition/layer] → Overlays (flow field, ripples, touch smears)
               CompositePass (grade, bloom, underlay/overlay RGBA, GL-Transition splice) → target FBO
```

- **Scenes** (`core/viz/scenes`): `ShaderScene` (one fragment style on a fullscreen triangle, about 40 styles), `FluidScene`/`FluidSceneBase` (stable-fluids solver, emitters, choreography, particles, 9 looks), `CurlFlowScene`, `WaterScene` (ripple height field + ink), `SilkScene`, `LifeScene` (Lenia/Gray-Scott), `AcidScene` (feedback), `MycoScene` (physarum), `CymaticsScene` (plate modes) and `MilkdropScene` (projectM into its own FBO, graded by `pm_post_frag`).
- **GPU capability layer:** `GlCaps`/`GlProber`/`GlProfile` probe formats, compute and timer queries once, cached in `<cacheDir>/gl-probe-facts.txt`. `Compute`+`SimPass` run each simulation step on compute where it is proven, otherwise on fragment ping-pong. `ProgramBinaryCache` persists linked programs by SHA-256.
- **Performance:** the `ThermalGovernor` tier ladder works from platform thermal status and headroom (pushed from Kotlin) plus a frame-deficit monitor. `FluidQuality` tiers. `MarchBudget` sets raymarch steps.
- **Params:** `SceneParams` has a fixed field order (`geode_viz_param_name(i)`). Kotlin packs it as a float array (`SceneParamsCodec.verify` checks the order against the library once).

## 1.6 Pipeline D: capture of other apps / mic

`CaptureController` arbitrates the sources. `PlaybackCaptureService` is a foreground service of
type `mediaProjection`. `MicCapture` uses `AudioRecord` and picks its source by device.
`AudioCapturePump` uses a run-generation counter so a late blocked read never writes into a sink
it no longer owns. `NowPlayingBridge` and `GeodeNotificationListener` read the title/artist of
the external app's media session.

## 1.7 Pipeline E: export

| Export | How |
|---|---|
| **Visualizer video** (`VideoExporter`) | Offline `FeatureTimeline` + `OffscreenSceneRenderer` (`geode_viz_set_offscreen(1)`) → `EncoderSurface` (EGL window on the `MediaCodec` input surface, `setPresentationTimeNs`) → H.264/HEVC + AAC (`AudioTranscoder`, AIFF via `AiffPcm`/`AiffExtractor`) → `MediaMuxer`. Frame-exact from the timeline, not real time. Keyframed params, LFO/ADSR, background underlay |
| **Loop render / loop-extend** (`LoopRender`, `LoopExtend`) | Render one seamless loop with a cross-dissolved seam and time-of-day palette drift, then repeat the encoded segment to the soundtrack length (hours) without re-rendering |
| **Studio cut** (`StudioExporter`, `ProjectComposition`) | Media3 Transformer `Composition`: media lanes in sequence, `ClipEdit` (trim, speed ramp via `SpeedRamp`, `KeyframedGrade` colour matrix, rotation, `.cube` LUT via `CubeLut`, `TimedTextOverlay` captions), `GlTransitionEffect` between clips (frame captured by `TransitionCaptureEffect`), mixed audio lanes |
| **Loudness** (`LoudnessMeter`, `LoudnessTarget`) | ITU BS.1770 integrated loudness with gating, advice versus targets (YouTube −14, Shorts/TikTok, leave as is) |
| **Chapters** (`ChapterMarkers`) | YouTube description, WebVTT and FFmetadata sidecars from mix-clip drops |

These run in `ExportService` (a foreground service with timeout handling). `ExportRun` tracks
state and cancellation. `RenderEta` estimates the time left. `StudioClips` lists rendered clips
in MediaStore with pending-row handling. `GeodeContainer` sweeps stale scratch and orphaned
pending rows at startup.

## 1.8 Persistence

Everything is local. There are two kinds:

- **JSON files under `files/`**, written atomically (`AtomicWrite`: temp file + rename, and a corrupt file is quarantined instead of crashing). Presets (`PresetStore`, with folders, `.milk` materialised beside), templates (`TemplateFormat` and `TemplateRepository`, which must round-trip *foreign fields from future versions*), editor projects (`EditorProjectJson`/`EditorProjectStore`), performance takes (`TakeStore`), playlists, smart playlists, palettes, LFO/ADSR configs, the track library (`TrackLibrary`), history (`HistoryStore`), the session (`SessionStore`, schema-versioned), analysis cache (binary columns), MilkDrop textures (`TextureStore` + `MilkTextureLinks`).
- **SharedPreferences** (`GeodePrefsFiles`): player prefs, GUI/theme prefs, export defaults, background prefs, boot animation, auto-visuals prefs, viz state, bookmarks, favourites, widget state.

**Share links:** `PresetLink` and the template link (`geode://…`) carry a deflated, base64 JSON document with bounded inflate (anti zip-bomb). The only test in the app covers this.

## 1.9 Threads (what must stay isolated)

| Thread | Work | Rate |
|---|---|---|
| Audio callback (Oboe / AudioTrack) | mix, DSP, tap write | device period |
| Engine thread (native player) | decode, resample, commands | continuous |
| Analysis thread | ring read → `geode_analysis_push/pull` → feature ring | 62.5 Hz hop (live), 60 Hz (offline) |
| Capture pump | AudioRecord read → ring | continuous |
| GL thread | pacer → render | 30–120 Hz |
| Main/UI | Compose, `StateFlow` collection, 250 ms-ish session poll | |
| IO | stores, MediaStore, tag reads | |

In the Kotlin design every analysis hop and every rendered frame crossed JNI with float arrays.
The new design keeps all of the rows above except Main/UI inside C++ (see doc 5).

## 1.10 Android platform entry points (from `AndroidManifest.xml`)

| Component | Class (old) | Purpose |
|---|---|---|
| Activity | `ui.MainActivity` | single activity, PiP, share/import intents, `geode://` links, search intents |
| Service | `playback.PlaybackService` | `MediaLibraryService`: media session, notification, Android Auto |
| Service | `audio.PlaybackCaptureService` | foreground `mediaProjection` capture |
| Service | `export.ExportService` | foreground `mediaProcessing`/`dataSync` export |
| Service | `wallpaper.VisualizerWallpaperService` | live wallpaper |
| Service | `wallpaper.VisualizerDreamService` | Daydream |
| Service | `audio.GeodeNotificationListener` | read other apps' now-playing |
| Receiver | `widget.NowPlayingWidgetReceiver` (Glance) | home-screen widget |
| Receiver | `MediaButtonReceiver` (Media3) | headset buttons |
| Provider | `FileProvider` | sharing exports and presets |

Permissions: `READ_MEDIA_AUDIO` (or `READ_EXTERNAL_STORAGE` ≤ 32), `RECORD_AUDIO`,
`FOREGROUND_SERVICE` + `_MEDIA_PROJECTION`/`_MEDIA_PLAYBACK`/`_MEDIA_PROCESSING`/`_DATA_SYNC`,
`POST_NOTIFICATIONS`, `VIBRATE`, `MODIFY_AUDIO_SETTINGS`. **No `INTERNET`.**
