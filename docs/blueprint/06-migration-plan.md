# 6 · Migration plan

The plan is ordered by dependency. Each phase ends with something that runs.

| Phase | Work | Exit criteria |
|---|---|---|
| **0 · Foundation** | Verify the submodule pins build. **Extract every 📦 DATA Kotlin file to JSON** (doc 3 §3.10) from the source repo. Convert `strings.xml` → ARB. Rename theme-pack art into `assets/theme_packs/` | `cmake` configures `geode_core` for arm64-v8a and x86_64; the JSON catalogs exist and validate |
| **1 · Native host skeleton** | Restructure into `app/` + `native/` (doc 5 §5.6). Remove the JNI glue. Add `ffi/` with `geode_engine_*` and `geode_surface_*`. Write `PcmRing`, `FeatureRing`, `AnalysisThread`, `RenderHost`, `FramePacer`. Port the `FeatureRingTest` contract to GoogleTest | `flutter run` shows one ShaderScene in a `Texture`, driven by a sine-wave PCM source |
| **2 · Playback** | `host/Engine` (Player + DSP + tap → ring + clock), time-stretch + skip-silence. Dart `PlaybackService`, queue, history, sleep timer, ReplayGain, bookmarks. Media session per D1 | Plays a library track gaplessly, the visuals react, lock-screen controls work |
| **3 · Library & data** | MediaStore/SAF scan, the TrackLibrary JSON, playlists (M3U/PLS/XSPF), smart playlists, duplicates, search, lyrics, TagLib read/write (+ consent shim) | Feature parity with the Library screen |
| **4 · Visuals UI** | Stone theme system, Player + Visualizer screens, Visuals hub, the Customize panel (params from `geode_viz_param_name`, scope/keys catalogs, randomizer, locks, A/B, LFO/ADSR), presets/templates/`.milk`/textures, background underlay, touch, auto visuals | Every scene and style reachable, presets round-trip with the old JSON |
| **5 · Capture** | Mic (Oboe input), playback-capture shim → `geode_capture_write`, notification-listener now-playing | Visualizes other apps' audio |
| **6 · Studio & export** | Port the editor domain (pure Dart). Timeline UI. `OfflineAnalysis` jobs. Native visualizer export, loop render/extend, loudness. Compositor (D2). Export foreground service | Frame-exact visualizer export matches the old app on the same track |
| **7 · Ambient** | Wallpaper + dream (shim → `RenderHost`), widget, Android Auto tree, second screen, PiP | All manifest components in doc 1 §1.10 accounted for |
| **8 · Hardening** | Provenance check in Dart, the device checklist (`DEVICE_CHECKS.md`), thermal tiers, the safety model review, the release workflow | Release build installs with no INTERNET permission |

## Decisions that need you

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | Android entry points that can't be written in Flutter or C++: media session/Android Auto, MediaProjection capture FGS, live wallpaper, Daydream, widget, notification listener, MediaStore write consent, bit-perfect USB, PiP, second screen | (a) Use maintained Flutter plugins (`audio_service`, `home_widget`, `permission_handler` …). They contain Kotlin/Java internally, but you write none. (b) Write about 10 thin **Java** shims that only forward into C++/Dart. (c) Drop the features | **(a) where a plugin exists, (b) for wallpaper/dream/capture.** "No Kotlin" holds for code you write. Android simply has no C++ or Dart entry point for these components |
| **D2** | The Studio cut export used Media3 Transformer (Kotlin/Java) | (a) Write a native compositor in C++ (`AMediaCodec` decode → GL effects → encode). It is the most work and needs no JVM. (b) Use `ffmpeg_kit_flutter` (GPL/LGPL licence implications, bigger APK). (c) Call Media3 Transformer through a Java shim | **(a)**. It reuses the native `Transition`, the grade and LUT shaders, and the encoder already built for the visualizer export |
| **D3** | State management | Riverpod, BLoC, or MVVM with ChangeNotifier | **Decided:** MVVM with ChangeNotifier view models + repositories, as the official Flutter architecture skill prescribes (used in `app/`) |
| **D4** | Platforms | Android only (as today) or iOS too | Android first. Keep `core/` portable (only `audio/player/Decoder`, `Output` and the EGL host are Android-specific) so iOS is possible later |
| **D5** | ExoPlayer is dropped, so the native engine is the only player | Accept, or keep a Media3 fallback through a shim | Accept. The native engine already does gapless, crossfade and bit-perfect |
| **D6** | Third-party pins for kissfft / TagLib / Oboe (not recorded in the source) | Keep 131.1.0 / v2.1.1 / 1.9.3, or bump | Keep for phase 0 and bump deliberately afterwards |
