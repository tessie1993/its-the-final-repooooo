# 4 · Shaders and assets (imported as-is)

All paths below are relative to `geode/app/src/main/`.

## 4.1 How shaders are loaded

`core/viz/ShaderSource.cpp` reads `shaders/<name>` through `AAssetManager` and splices
`//#include lib_xxx` lines in recursively, with a cycle guard. Programs are linked once and
cached by `ProgramBinaryCache` (SHA-256 of the source). Every shader is **GLSL ES 3.00**
(`#version 300 es`). Compute variants are generated at run time by `compute/SimGlsl` around
the `*_step` bodies.

**Flutter packaging.** List `assets/shaders/`, `assets/milk/` and `assets/gl_transitions.json`
under `flutter: assets:` in `pubspec.yaml`. Inside the APK they land under
`assets/flutter_assets/<path>`, and the same `AAssetManager` reads them with that prefix. That
prefix is the only change `ShaderSource` needs (doc 2 §2.6). Do **not** use Flutter's
`FragmentProgram`: these shaders run on the native GL context, not on Impeller.

## 4.2 Shared libraries (`assets/shaders/lib_*.glsl`)

| File | LOC | Role |
|---|---|---|
| `lib_scene_uniforms.glsl` | 195 | The shared uniform contract every fragment style reads (time, resolution, levels, bands, beat/bar phases, palette, grade params) |
| `lib_scene_motion.glsl` | 276 | Smoothed relative-energy signals (`uEnergyRel`, `uBassRel`…) for continuous, non-trigger motion |
| `lib_scene_grade.glsl` | 29 | `grade()`: the shared final colour grade |
| `lib_palette.glsl` | 61 | Procedural palette vs. the `cyclic_palettes.bin` LUT row |
| `lib_touch.glsl` | 166 | Touch field sampling (fingers, fade) |
| `lib_sdf3.glsl` | 401 | 3D SDF primitives + smooth min/max for the raymarched styles |
| `lib_dmt.glsl` | 551 | Lighting/material model for the raymarched bodies |
| `lib_psrdnoise2.glsl` | 149 | Gustavson/McEwan periodic rotating simplex noise (MIT) |
| `lib_particle_common.glsl` | 146 | Particle shape SDFs |
| `lib_particle_shade.glsl` | 94 | Particle sprite shading (premultiplied) |

## 4.3 Fragment styles (`ShaderScene`; `SceneRegistry` maps id → `<id>_frag.glsl`)

| Shader | LOC | Look |
|---|---|---|
| `aurora_frag` | 183 | Aurora curtains |
| `bars_frag` | 173 | Spectrum bars |
| `bead_vortex_frag` | 112 | Tunnel of bead rings |
| `blacklight_bloom_frag` | 180 | Mirrored blacklight tapestry |
| `chroma_orb_frag` | 155 | Glass sphere with four-fold skin |
| `curl_bloom_frag` | 227 | Orbiting curl-noise blooms (raymarched) |
| `fractal_temple_frag` | 167 | Triangulated dome |
| `grid_frag` | 178 | Audio grid |
| `hexgrid_frag` | 176 | Hex grid |
| `julia_frag` | 185 | Julia set |
| `kaleido_frag` | 174 | Kaleidoscope (origin of the shared grade) |
| `kifs_frag` | 791 | Kaleidoscopic IFS fractal (raymarched) |
| `lava_frag` | 256 | Lava lamp |
| `liss_frag` | 177 | Lissajous |
| `mandala_dome_frag` | 165 | Eight-point star mandala |
| `mandel_frag` | 178 | Mandelbrot |
| `merkaba_grid_frag` | 187 | Sacred-geometry cathedral |
| `metaballs_frag` | 181 | Metaballs |
| `morphogen_frag` | 1104 | Morphing body (raymarched, the largest style) |
| `nebula_frag` | 833 | Volumetric nebula march |
| `nectar_flow_frag` | 179 | SDF nectar flow |
| `neon_tiles_frag` | 142 | SDF neon tiles |
| `noneuclid_frag` | 802 | Non-Euclidean space (raymarched) |
| `orb_lattice_frag` | 109 | Spherical kaleidoscope of neon dots |
| `plasma_frag` | 171 | Plasma |
| `ring_frag` | 174 | Rings |
| `ripples_frag` | 173 | 2D ripples |
| `rod_tunnel_frag` | 203 | Rod tunnel (raymarched, `uSteps` budget) |
| `scope_frag` | 171 | Oscilloscope |
| `solar_frag` | 165 | Solar |
| `spiral_eye_frag` | 131 | Logarithmic-spiral cloud |
| `spiral_frag` | 166 | Spiral |
| `starfield_frag` | 178 | Starfield |
| `tunnel_frag` | 174 | Tunnel |
| `vanishing_frag` | 766 | Vanishing-point march |
| `voronoi_frag` | 185 | Voronoi |
| `warp_frag` | 177 | Warp |
| `waves_frag` | 175 | Waves |
| `winter_frag` | 274 | Winter |

## 4.4 Simulation families

| Family | Shaders | Native owner |
|---|---|---|
| **Fluid** (9 looks) | `fluid_base_vert`, `fluid_advect`, `fluid_curl`, `fluid_vorticity`, `fluid_divergence`, `fluid_pressure`, `fluid_gradient`, `fluid_splat`, `fluid_clear`, `fluid_copy`, `fluid_display`, `fluid_bloom_prefilter/blur/final`, `fluid_blur`, `fluid_sunrays_mask`, `fluid_sunrays`, particles: `fluid_particle_seed/update/vert/frag` | `fluid/*`, `scenes/FluidScene*` |
| **Curl Flow** | `curl_field_frag` + the fluid particle shaders | `scenes/CurlFlowScene` |
| **Water** | `ripple_splat`, `ripple_update`, `water_ink_splat`, `water_ink_advect`, `water_display` | `fluid/RippleSim`, `scenes/WaterScene` |
| **Silk** | `silk_step.glsl` (SimPass body), `silk_show.glsl` | `scenes/SilkScene` |
| **Life** | `life_step_frag`, `life_show_frag` (6 looks) | `scenes/LifeScene` |
| **Acid** | `acid_step_frag`, `acid_show_frag` | `scenes/AcidScene` |
| **Mycelium** | `myco_agent_frag`, `myco_deposit_vert/frag`, `myco_blur_frag`, `myco_show_frag` (6 looks) | `scenes/MycoScene` |
| **Cymatics** | `cymatics_field_frag` (11 substyles) | `scenes/CymaticsScene` |
| **MilkDrop** | projectM's own shaders + `pm_post_frag` | `scenes/MilkdropScene` |

## 4.5 Frame-graph and utility shaders

| Shader | Role |
|---|---|
| `quad_vert` | Fullscreen triangle |
| `composite_frag` (494) | Final composite: grade, bloom, underlay/overlay, layer mix, spliced GL Transition (`ratio`, `progress`) |
| `trail_warp_frag` | MilkDrop-style feedback warp echo |
| `fade_vert` / `fade_frag` | Neutral trail fade |
| `overlay_frag` | Flow-field / ripple overlay + RGBA overlay layer |

## 4.6 Binary data

| File | Content | Reader |
|---|---|---|
| `shaders/blue_noise_64.bin` | 64×64 R8 blue-noise mask (dithering) | `viz/BlueNoise` |
| `shaders/cyclic_palettes.bin` | Cyclic palette LUT rows | `viz` palette LUT; names in the 📦 `CyclicPalettes` data |
| `gl_transitions.json` | 122 GL Transitions (name, GLSL body, uniforms + defaults) | `viz/Transition` (C++) + the Dart picker |

## 4.7 Other assets and Android resources

| Path | Content | Flutter destination |
|---|---|---|
| `assets/milk/*.milk` | 6 starter MilkDrop presets (`aurora_veil`, `fracture`, `geode_bloom`, `prism_well`, `slow_orbit`, `tidal_drift`) | `assets/milk/`, copied to app storage on first run (`MilkStarterPack`) |
| `assets/third_party_notices.txt` | Licence notices | `LicenseRegistry.addLicense` |
| `res/drawable-nodpi/tp_<pack>_<component>_<state>.webp` | **960 images**: 10 theme packs × components (button ×4 variants, slider track/thumb, knob, toggle, text field, sheet, progress ring, player, navigation bar, list, dialog, chip, card, album tile, material tile) × states (default/pressed/focused/selected/disabled), plus glow/refraction overlays and ambient portrait/landscape art | `assets/theme_packs/<pack>/<component>_<state>.webp` (rename by script; `tools/import-theme-pack.sh` → retarget) |
| `res/raw/tp_<pack>_{click_soft,confirm,swoop}.wav` | 30 UI sounds (3 per pack) | `assets/theme_packs/<pack>/sounds/`; play with `audioplayers`/`just_audio`, or better, a tiny native one-shot player in the engine (low latency, no extra plugin) |
| `res/font/*.ttf` | Mali (regular/medium/semibold/bold), Mystery Quest | `assets/fonts/` + `pubspec` `fonts:` |
| `res/drawable/ic_launcher_*`, `mipmap-anydpi-v26/ic_launcher.xml` | Adaptive launcher icon (vector) | `flutter_launcher_icons` or keep in `android/app/src/main/res` |
| `res/drawable/ic_widget_*`, `ic_stat_capture.xml` | Widget transport + capture notification icons | keep in `android/app/src/main/res` (used by the SHIMs) |
| `res/values/strings.xml` | 719 strings (UI copy, help, errors, notifications) | **Convert to ARB** (`lib/l10n/app_en.arb`) with a script. Notification/widget strings stay in Android `res` for the SHIMs |
| `res/values/themes.xml` | Launch/splash theme | `android/app/src/main/res/values/styles.xml` (`LaunchTheme`) |
| `res/xml/wallpaper.xml`, `dream_info.xml` | Wallpaper + Daydream metadata | keep (SHIM) |
| `res/xml/now_playing_widget_info.xml` | Widget provider info | keep (SHIM) |
| `res/xml/automotive_app_desc.xml` | Android Auto declaration | keep (SHIM) |
| `res/xml/preset_paths.xml` | FileProvider paths | keep |
| `res/xml/backup_rules.xml`, `data_extraction_rules.xml` | Backup exclusions | keep |
| `res/xml/locales_config.xml` | Per-app languages | keep |
| `AndroidManifest.xml` | Reference manifest | Merge into Flutter's `android/app/src/main/AndroidManifest.xml` (doc 5 §5.7) |

## 4.8 Docs carried over (`geode/docs`)

| Doc | Why it matters for the rebuild |
|---|---|
| `AUDIO_CHAIN.md` | The tap-first rule and why DSP never changes the picture |
| `visualizer-v2/AUDIO_FEATURE_ABI.md` | Sample-indexed time, epochs, explicit `Gap` ring reads. This is the contract for the new C++ `PcmRing`/`FeatureRing` |
| `visualizer-v2/SAFETY_MODEL.md` | Photosensitivity clamp model (non-negotiable) |
| `visualizer-v2/provenance.json`, `SOURCE_ARCHIVE.md`, `reference-coverage.json` | Origin/licence of vendored code; feeds the provenance check |
| `PARAM_MATRIX.md` | Which parameter moves which style (cross-check `ParamScope` data) |
| `VISUAL_STYLE_RESEARCH.md` | Design references for the styles |
| `DEVICE_CHECKS.md` | Manual device test checklist |
| `AUDIT_2026-09.md` | Last audit findings: open issues to carry forward |
| `wireframe.html` | UI wireframe: the starting point for the Flutter screen design |
| `privacy-policy.html` | Store listing |
