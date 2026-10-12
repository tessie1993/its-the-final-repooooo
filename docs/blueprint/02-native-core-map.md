# 2 · Native core map (C++, imported as-is)

`geode/core` is a static library, `geode_core`. It is C++20, built by `geode/core/CMakeLists.txt`
and linked against kissfft, projectM, TagLib, Oboe, `mediandk`, `GLESv3`, `EGL`, `log` and
`android`. Almost all of it is reused unchanged. Most `.hpp`/`.cpp` pairs share one row.

**Verdict key:**
- **Keep**: reuse unchanged.
- **Modify**: small, named change needed for Flutter.
- **Replace**: superseded by new code (doc 5).

## 2.1 `core/api` (the C ABI and the FFI boundary)

| File | What it does | Verdict |
|---|---|---|
| `api/geode_api.h` | The whole public C surface: opaque handles `geode_analysis`, `geode_drums`, `geode_viz`, `geode_dsp`, `geode_player`, `geode_tags`; `GeodeFeatureFrame` (237 floats); analysis, pulse-replay, drums, viz, dsp, tags and player functions; constants (`GEODE_BAND_COUNT 64`, `GEODE_LFO_SLOTS 3`, `GEODE_ADSR_SLOTS 2`, `GEODE_DSP_BANDS 10`, crossfade curves, player states, tag fields/errors) | **Modify**: add the new `geode_engine_*`, `geode_capture_*`, `geode_surface_*` and `geode_export_*` entry points (doc 5). Change `geode_viz_create` to accept an asset-root prefix, because Flutter assets live under `flutter_assets/` |
| `api/geode_api.cpp` | `geode_version`, analysis + drums + pulse-replay wrappers over `AnalysisSession`/`DrumChannels`/`PulseReplay` | Keep |
| `api/geode_viz_api.cpp` | `geode_viz_*` → `viz::Renderer` (param table, latched setters, GL-thread calls) | Keep |
| `api/geode_dsp_api.cpp` | `geode_dsp_*` → `audio::dsp::DspChain` | Keep |
| `api/geode_player_api.cpp` | `geode_player_*` → `audio::player::Player` | Keep |
| `api/geode_tags_api.cpp` | `geode_tags_*` → `library/Tags` (fd-owning; thread-local last error) | Keep |

## 2.2 `core/analysis` (audio feature extraction)

| Module | What it does | Verdict |
|---|---|---|
| `AnalysisSession` | Owns one analysis pipeline. `analyze()` handles a single window. `push()`/`pull()` is the hop-locked streaming path with a bounded buffer. It fills `GeodeFeatureFrame` | Keep |
| `ReactiveAnalyzer` | Composes every stage below into the per-hop frame: levels, bands, flux, onset, beat, tempo, bar, drums, chroma, key, structure, stereo | Keep |
| `WindowTable` | Precomputed analysis windows (`WindowShape`) | Keep |
| `Spectrum` | kissfft real FFT → magnitudes | Keep |
| `LogBands` | Linear bins → 64 log-spaced bands | Keep |
| `AdaptiveRange` | Per-band dB floor/ceiling followers → 0..1 normalisation with warm-up | Keep |
| `AdaptiveWhitening` | Per-band peak-decay whitening before onset detection | Keep |
| `SuperFlux` | SuperFlux onset detection function (max-filtered spectral flux) | Keep |
| `OnsetPeakPicker` | Adaptive-threshold peak picking with refractory period → onset/transient | Keep |
| `TempoTracker` | Onset autocorrelation → BPM + beat period + confidence | Keep |
| `TempoStability` | How steady the BPM estimate is (mean/deviation in octaves) | Keep |
| `BeatGrid` | Phase-locked beat grid; `step(period, confidence, onset)` → beat + phase | Keep |
| `BarTracker` | 4/4 bar phase, downbeat and downbeat confidence from beat accents | Keep |
| `DrumChannels` | Kick/snare/hat from band ranges with per-channel flux + pickers (sample-rate change keeps history) | Keep |
| `Chromagram` | 12-bin pitch-class profile | Keep |
| `KeyDetector` | Key estimate from accumulated chroma (string such as `"A minor"`) | Keep |
| `HarmonicBalance` | Harmonic-vs-percussive balance (`harmonicity`) | Keep |
| `StructureTracker` | Novelty, section boundary, build-up, drop, arrival, macro energy | Keep |
| `StereoField` | Width, correlation and pan from mid/side | Keep |
| `FrameLevels` | RMS / bass / mid / treble / centroid helpers | Keep |
| `PulseReplay` | Re-decides beat/transient from cached flux + RMS under new tuning (offline) | Keep |

## 2.3 `core/audio/dsp` (playback DSP chain, RT-safe process)

| File | What it does | Verdict |
|---|---|---|
| `Biquad.hpp` | Transposed-DF-II biquad, RBJ cookbook coefficients, denormal flush | Keep |
| `Gain.hpp` | Smoothed dB gain (ReplayGain + preamp) | Keep |
| `Equalizer` | 10 peaking bands on ISO octave centres + bass-boost shelf, millibel levels | Keep |
| `Crossfeed` | Headphone crossfeed (low-passed, attenuated opposite channel, level-preserving) | Keep |
| `Limiter` | Lookahead peak limiter with sliding-window max | Keep |
| `DspChain.hpp` | gain → EQ → crossfeed → limiter, float interleaved, in place | Keep |

## 2.4 `core/audio/player` (native playback engine)

| File | What it does | Verdict |
|---|---|---|
| `Decoder` | `AMediaExtractor` + `AMediaCodec` on an fd → interleaved stereo float | Keep |
| `Resampler` | Stereo 4-point Hermite rate converter | Keep |
| `SpscRing.hpp` | Wait-free single-producer single-consumer ring | Keep (also reuse it for the new PCM rings) |
| `Deck.hpp` | One track's decoded audio at the output rate (ring + owner) | Keep |
| `Mixer` | Drains the current deck, gapless join or crossfade into the next, RT-safe DSP swap with deferred reclaim, tap write | Keep |
| `Output` | Oboe stereo float stream, exclusive when granted, disconnect handling | Keep |
| `Player` | Engine thread: owns decoders/decks/stream, command queue, atomics for state/position/duration/token | **Modify**: in the new design it becomes **the only** playback engine (ExoPlayer is dropped). Add speed/pitch (time-stretch) and skip-silence, which Media3 used to provide (doc 5 §5.4) |

## 2.5 `core/library` and `core/util`

| File | What it does | Verdict |
|---|---|---|
| `library/Tags` | TagLib read/write over an fd: text fields, year, track, duration, ReplayGain, art size, write errors | Keep |
| `util/Json` | Small JSON parser (used by the transition catalog and style data) | Keep |
| `util/Log.hpp` | `__android_log_print` macros | Keep |

## 2.6 `core/viz` (renderer, frame graph, infrastructure)

| Module | What it does | Verdict |
|---|---|---|
| `Renderer` + `RendererFrame.cpp` | Frame graph: LFO/ADSR → safety → motion → scene target (trail) → secondary scene (transition/layer) → overlays → composite → target FBO. Latched any-thread setters, GL-thread surface/scene/render calls, band gains | Keep |
| `Scene.hpp` | `Scene` interface + `SceneFamily`, `SceneHost` hooks (trail retention, flow, PCM, touch) | Keep |
| `SceneRegistry` | id → scene class factory; shader-scene id → `shaders/<id>_frag.glsl` | Keep |
| `Params` + `ParamsFields.cpp` | `SceneParams` (every Customize field, defaults, order) + the name ↔ index table behind `geode_viz_param_name` | Keep. This order is a wire contract with Dart |
| `Lfo` | 3 LFO slots: wave, rate, depth, polarity, curve, source (free LFO or live follower), chained targets | Keep |
| `Adsr` | 2 ADSR slots gated by a band, sustain tracking, retrigger | Keep |
| `LiveSignal.hpp` | Edge detection + traverse helpers on the feature frame | Keep |
| `MotionField` | Continuous motion layer: running-average ratios, phase-locked oscillators, slow retargets | Keep |
| `VisualSafety` | Unconditional flash/luminance clamp, `FlashBudget` (3 rising edges per second), strobe limit | Keep. This is a product guarantee |
| `ThermalGovernor` | Render tier ladder from platform thermal status/headroom + frame deficit | Keep (Dart or a JNI-free NDK `AThermal` push feeds it, doc 5) |
| `TouchField` | Latest-wins touch hand-over, stepped per frame | Keep |
| `Overlays` | Shared flow field + ripple overlay + touch smears | Keep |
| `TrailPass` | Feedback fade quad / trail-warp resample | Keep |
| `CompositePass` | Final opaque pass over `composite_frag.glsl`: grade, underlay/overlay RGBA8 upload (ARGB→RGBA swizzle), spliced transition | **Modify**: the pixel layout stays ARGB_8888 ints. Dart's `Image.toByteData(rawRgba)` gives RGBA bytes, so add an RGBA entry point or swizzle in Dart |
| `CompositeGrade` | Grade gate flags (geo, mirror invert, grade, pulse) | Keep |
| `Transition` | Built-in transitions + GL Transitions library parsing + LRU of 4 spliced composite programs | Keep |
| `ShaderSource` | Reads `shaders/<name>` through `AAssetManager`, resolves `//#include lib_*` recursively with a cycle guard | **Modify**: prefix `flutter_assets/` (or the configured asset root) |
| `Program` | Compile/link with a uniform cache, restoring from the binary cache | Keep |
| `ProgramBinaryCache` + `Sha256` | Persistent `glProgramBinary` cache keyed by source hash | Keep |
| `GlCaps` / `GlProber` / `GlProfile` | Probe the GLES version, renderable/filterable formats, compute and timer queries. Facts cached in `gl-probe-facts.txt`. `GlProfile` makes a throwaway pbuffer context | Keep |
| `Compute` | Compute-shader support, limits, image formats, dispatch | Keep |
| `Framebuffer`, `Texture`, `Quad`, `Half.hpp`, `BlueNoise` | RAII GL objects, fullscreen triangle, fp16 conversion, 64×64 blue-noise mask | Keep |

## 2.7 `core/viz/compute`, `core/viz/fluid`, `core/viz/scenes`

| Module | What it does | Verdict |
|---|---|---|
| `compute/SimField` | Ping-pong state pair, allocated on demand | Keep |
| `compute/SimGlsl` | Shared preamble + compute / fragment program shapes around a step body | Keep |
| `compute/SimPass` | One simulation step per frame on compute (where proven) or fragment ping-pong | Keep |
| `fluid/FluidSim` | Stable-fluids solver on half-float grids (advect, curl, vorticity, divergence, pressure Jacobi, gradient) | Keep |
| `fluid/FluidBuffers` | Proven half-float formats + FBO / double-FBO RAII | Keep |
| `fluid/FluidEmitters` | Beat, stirrer, suction, sparkle and pump splats | Keep |
| `fluid/FluidChoreography` | Spawn/catch anchors walking a path on heard energy | Keep |
| `fluid/FluidParticles` | Particle state texture advected by velocity | Keep |
| `fluid/FluidLook` | Display-look selection (`fluid_display_frag` branches), bloom, sunrays | Keep |
| `fluid/FluidMath` | Audio drive scaling, water and curl-flow math | Keep |
| `fluid/FluidQuality.hpp` | Quality tiers (resolution, iterations) | Keep |
| `fluid/FlowField` | Velocity-only fluid warping the fragment styles and the composite | Keep |
| `fluid/RippleSim` + `RippleMath` | Height-field wave grid + ink layer, overlay drops (rings on transients, sparkles on treble) | Keep |
| `scenes/ShaderScene` | One fragment style on the fullscreen triangle, shared uniform block, smoothed motion layer | Keep |
| `scenes/FluidSceneBase` + `FluidScene` | Shared clock/idle/quality/GL state guard + one instance per fluid style (look + biases) | Keep |
| `scenes/CurlFlowScene` | Particles in curl-noise flow | Keep |
| `scenes/WaterScene` | Ripple pool with ink, fed by emitters + fingers | Keep |
| `scenes/SilkScene` | Advected strand field (compute) | Keep |
| `scenes/LifeScene` | Lenia / Gray-Scott with census reseed | Keep |
| `scenes/AcidScene` | Video-feedback loop on RGBA8 ping-pong | Keep |
| `scenes/MycoScene` | Physarum agents + blurred trail field | Keep |
| `scenes/CymaticsScene` + `CymaticsMath` | Resonant plate driven by the spectrum (modes, Bessel approximation, drops) | Keep |
| `scenes/MilkdropScene` | projectM into a scene-owned FBO via the back-ported `projectm_opengl_render_frame_fbo`, graded by `pm_post_frag`, preset/texture dir, error de-dupe | Keep |
| `scenes/StyleCatalog` | Per-family style tables (Cymatics, Silk, Life, Acid, Myco, Fluid profiles as multipliers) | Keep |
| `scenes/ProgramLoader.hpp`, `scenes/SceneCommon.hpp` | Asset → program helper; shared scene helpers (`PcmPulse`, motion include) | Keep |

## 2.8 JNI glue (`geode/app/src/main/cpp`)

| File | What it does | Verdict |
|---|---|---|
| `geode_jni.cpp` | `Java_dev_geode_engine_bridge_GeodeNative_*` for analysis, drums, pulse replay, dsp | **Replace**: Dart FFI calls the C ABI directly. Delete in phase 1 |
| `geode_viz_jni.cpp` | JNI for `geode_viz_*` (AssetManager from Java, float arrays, strings) | **Replace**: needs a tiny `AAssetManager` acquisition path (doc 5 §5.3) |
| `geode_player_jni.cpp` | JNI for `geode_player_*` | Replace |
| `geode_tags_jni.cpp` | JNI for `geode_tags_*` (`byte[][]` → nullable UTF-8) | Replace |
| `jni_util.hpp` | RAII `Utf8Chars` / `FloatElements` | Replace |

The root `geode/CMakeLists.txt` builds `libgeode.so` from these four JNI files. In the new tree
it builds from the new `ffi/` and `host/` sources instead (doc 5 §5.6).

## 2.9 Tools (`geode/tools`)

| File | Purpose | Status |
|---|---|---|
| `projectm-v4.1.7-render-fbo-backport.patch` | Adds `projectm_opengl_render_frame_fbo` to projectM 4.1.7. CMake applies it idempotently | Required |
| `build-projectm.md` | How projectM is built in-tree | Reference |
| `smoke.c` | Headless projectM test (EGL surfaceless + Mesa) | Useful for native CI |
| `glslcheck/` (`check.mjs`, `page.html`) | Compile-checks every shader in a browser/WebGL2 | Useful |
| `shaderpreview/` | Live preview harness for the fragment styles | Useful |
| `oracle/generate_corpus.py` | Generates the analysis reference corpus | Useful for analysis regression tests |
| `vendor_gl_transitions.py` | Re-vendors `gl_transitions.json` | Keep |
| `import-theme-pack.sh` | Imports theme-pack art into `res/drawable-nodpi` | **Modify**: target `assets/theme_packs/` |
| `check_style_collection.py` | Validates the style collection | Keep |
| `setup-android-sdk.sh` | Installs SDK/NDK/CMake | Keep (NDK `28.0.13004108`, CMake `3.22.1`) |
| `hostlink/hostlink.sh` | Device helper | Keep |
