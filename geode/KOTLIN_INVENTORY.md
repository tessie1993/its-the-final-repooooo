# Kotlin inventory (non-UI)

Every Kotlin file left after the UI and navigation layer was removed. This is the list to replace when the app moves to Flutter.

**131 files, 22,272 lines.**

How to read it:
- **Unreachable without a UI**: the code works, but only the removed UI ever started it. It covers video export, the timeline editor, templates, "visualize other apps" capture, mic input and offline track analysis. The Flutter UI will need to call these features (or their ports).
- **Running today**: these run with no UI at all. That is the playback service (Android Auto, media buttons, the lock screen), the live wallpaper, the screensaver, the home-screen widget, the notification listener, and the engine those use.
- The native C++ core (`core/`, `app/src/main/cpp/`) and the GLSL shaders are not Kotlin and are not listed. A Flutter app can keep them through FFI or a platform channel.

## `app` · androidTest · `(root)`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/androidTest/java/dev/geode/BuildVariantTest.kt` | 31 | — | Proves the instrumentation runner is wired and that the debug variant really |

## `app` · main · `(root)`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/GeodeApp.kt` | 32 | running |  |
| `app/src/main/java/dev/geode/GeodeContainer.kt` | 118 | running | Deletes render scratch files left behind by a render that never got to clean up after |
| `app/src/main/java/dev/geode/RingLog.kt` | 28 | running |  |

## `app` · main · `audio`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/audio/AiffExtractor.kt` | 268 | running |  |
| `app/src/main/java/dev/geode/audio/AudioBus.kt` | 47 | running |  |
| `app/src/main/java/dev/geode/audio/AudioCapturePump.kt` | 132 | unreachable without UI |  |
| `app/src/main/java/dev/geode/audio/AudioFxController.kt` | 203 | running | A named set of band levels in millibels, low band first. |
| `app/src/main/java/dev/geode/audio/AudioFxPresets.kt` | 17 | running | The built-in equalizer curves, ten bands from 31 Hz to 16 kHz in millibels. |
| `app/src/main/java/dev/geode/audio/MicCapture.kt` | 118 | unreachable without UI |  |
| `app/src/main/java/dev/geode/audio/NowPlayingBridge.kt` | 75 | running |  |
| `app/src/main/java/dev/geode/audio/PcmRingBuffer.kt` | 96 | running |  |
| `app/src/main/java/dev/geode/audio/PlaybackCapture.kt` | 122 | unreachable without UI |  |
| `app/src/main/java/dev/geode/audio/PlaybackCaptureService.kt` | 175 | unreachable without UI |  |
| `app/src/main/java/dev/geode/audio/TapRenderersFactory.kt` | 35 | running |  |

## `app` · main · `audio.dsp`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/audio/dsp/MvzAudioProcessorChain.kt` | 46 | running |  |
| `app/src/main/java/dev/geode/audio/dsp/NativeDspProcessor.kt` | 160 | running | Everything the native chain is told; re-applied whenever a format change builds a new chain. |

## `app` · main · `data`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/data/AtomicWrite.kt` | 54 | running |  |
| `app/src/main/java/dev/geode/data/DeviceTrackQuery.kt` | 76 | running | The music MediaStore already indexes, read the same way for the library screen and the Android Auto tree. |
| `app/src/main/java/dev/geode/data/FavouritesStore.kt` | 44 | running |  |
| `app/src/main/java/dev/geode/data/GeodePrefsFiles.kt` | 32 | running |  |
| `app/src/main/java/dev/geode/data/HistoryStore.kt` | 179 | running |  |
| `app/src/main/java/dev/geode/data/MusicPlaylistStore.kt` | 123 | running |  |
| `app/src/main/java/dev/geode/data/NativeTags.kt` | 168 | running | Result of [NativeTags.write], distinguishing a deniable consent gap from a hard failure. |
| `app/src/main/java/dev/geode/data/PerformanceTake.kt` | 149 | unreachable without UI |  |
| `app/src/main/java/dev/geode/data/PlayerPrefs.kt` | 159 | running | Where a long track was left, per track, in the same prefs file as the player options. Only |
| `app/src/main/java/dev/geode/data/PresetLink.kt` | 76 | unreachable without UI |  |
| `app/src/main/java/dev/geode/data/PresetStore.kt` | 496 | running |  |
| `app/src/main/java/dev/geode/data/SessionStore.kt` | 107 | running |  |
| `app/src/main/java/dev/geode/data/TakeStore.kt` | 109 | unreachable without UI |  |
| `app/src/main/java/dev/geode/data/TemplateFormat.kt` | 602 | unreachable without UI | Outcome of reading a template file, link or pasted blob. |
| `app/src/main/java/dev/geode/data/TextureStore.kt` | 232 | unreachable without UI | The picked file, or null if it cannot be read or runs past [MAX_TEXTURE_BYTES]. |
| `app/src/main/java/dev/geode/data/TrackLibrary.kt` | 215 | running |  |
| `app/src/main/java/dev/geode/data/VideoTemplate.kt` | 653 | unreachable without UI | A value drawn from a closed set that a *future* build may extend. |

## `app` · main · `di`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/di/DataModule.kt` | 32 | running |  |

## `app` · main · `editor`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/editor/AutoCut.kt` | 326 | unreachable without UI | Far enough apart that consecutive cuts read as cuts rather than as a flicker. |
| `app/src/main/java/dev/geode/editor/ClipTransition.kt` | 22 | unreachable without UI | The transition a clip opens with, from whatever ended on the same lane before it. [id] names an |
| `app/src/main/java/dev/geode/editor/Keyframes.kt` | 509 | unreachable without UI | The shapes a parameter value can take. The kind is fixed per track — see [KeyframeTrack.kind]. |
| `app/src/main/java/dev/geode/editor/Markers.kt` | 249 | unreachable without UI | How late a tap lands by default: human reaction to a hit sits around 100 ms and Android's audio |
| `app/src/main/java/dev/geode/editor/Timeline.kt` | 730 | unreachable without UI | Snap radius used when the UI has not derived one from the current zoom level. |

## `app` · main · `export`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/export/AudioTranscoder.kt` | 488 | unreachable without UI |  |
| `app/src/main/java/dev/geode/export/ChapterMarkers.kt` | 224 | unreachable without UI | One audio clip the user dropped into a long-form soundtrack, in the order they dropped it. |
| `app/src/main/java/dev/geode/export/ClipEdit.kt` | 204 | unreachable without UI | [lut] is the loaded table behind [lutUri]; callers resolve it because loading needs a content resolver. |
| `app/src/main/java/dev/geode/export/CubeLut.kt` | 120 | unreachable without UI | A colour lookup table in the shape Media3's `SingleColorLut.createFromCube` wants: `cube[r][g][b]` is |
| `app/src/main/java/dev/geode/export/EncoderSurface.kt` | 90 | unreachable without UI | Idempotent, and safe on a partially built surface — see the constructor. |
| `app/src/main/java/dev/geode/export/ExportRange.kt` | 31 | unreachable without UI |  |
| `app/src/main/java/dev/geode/export/ExportRun.kt` | 54 | unreachable without UI |  |
| `app/src/main/java/dev/geode/export/ExportService.kt` | 126 | unreachable without UI |  |
| `app/src/main/java/dev/geode/export/GlTransitionEffect.kt` | 237 | unreachable without UI | Passes frames through untouched and leaves the last one in [store] when the clip ends. |
| `app/src/main/java/dev/geode/export/KeyframedClipEffects.kt` | 159 | unreachable without UI | Brightness, contrast, saturation and hue as one colour matrix re-read every frame, so a clip's |
| `app/src/main/java/dev/geode/export/LoopExtend.kt` | 698 | unreachable without UI | The soundtrack a long-form video is built around. Its length is the video's length. |
| `app/src/main/java/dev/geode/export/LoopRender.kt` | 889 | unreachable without UI | The shape of one visual loop: how long it runs, how long its seam takes to dissolve, and at |
| `app/src/main/java/dev/geode/export/LoudnessMeter.kt` | 657 | unreachable without UI | Integrated loudness of a whole programme. |
| `app/src/main/java/dev/geode/export/LoudnessTarget.kt` | 330 | unreachable without UI | Under this much, "quieter than YouTube" is noise rather than information. |
| `app/src/main/java/dev/geode/export/RenderEta.kt` | 63 | unreachable without UI |  |
| `app/src/main/java/dev/geode/export/StudioExporter.kt` | 292 | unreachable without UI | Re-resolves [messageRes] against a live [context], for a UI layer that wants localisation. |
| `app/src/main/java/dev/geode/export/TransitionFrameStore.kt` | 15 | unreachable without UI | The last frame one clip rendered, handed from its capture effect to the transition opening the next clip. |
| `app/src/main/java/dev/geode/export/VideoExporter.kt` | 633 | unreachable without UI | This codec when the device has an encoder for it, otherwise H.264, which every device has. |

## `app` · main · `playback`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/playback/LibraryTree.kt` | 199 | running | The browse tree Android Auto and other browsers walk. Folder ids are fixed words or `<kind>/<name>`; |
| `app/src/main/java/dev/geode/playback/MediaArtwork.kt` | 59 | running | Media-item extras key carrying the track's own content URI, so [SessionBitmapLoader] can |
| `app/src/main/java/dev/geode/playback/NativePlayer.kt` | 423 | running | The native engine behind the Media3 [Player] API, so the session, service and UI stay unchanged. |
| `app/src/main/java/dev/geode/playback/NativePlayerDsp.kt` | 57 | running | Mirrors the equalizer settings the Media3 processor holds onto a chain built at the native player's |
| `app/src/main/java/dev/geode/playback/NativeTapPump.kt` | 67 | running | Drains the native mixer's tap into the same [PcmTap] the Media3 chain feeds, so analysis and the |
| `app/src/main/java/dev/geode/playback/PlaybackEngine.kt` | 202 | running | Read once here: the engine choice is fixed for the life of the session. |
| `app/src/main/java/dev/geode/playback/PlaybackService.kt` | 241 | running | Browsing answers on the resumption thread: the tree reads files and the MediaStore. |
| `app/src/main/java/dev/geode/playback/ReplayGain.kt` | 88 | running | Reads the ReplayGain tags of every track the player moves to and drives the gain stage with them. |
| `app/src/main/java/dev/geode/playback/SessionBitmapLoader.kt` | 74 | running | Memoises the most recent embedded-artwork load. |
| `app/src/main/java/dev/geode/playback/SleepTimer.kt` | 120 | running |  |

## `app` · main · `viz`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/viz/BackgroundImage.kt` | 171 | unreachable without UI | The user's background image choice, not yet decoded - an export decodes it at its own render size. |

## `app` · main · `wallpaper`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/wallpaper/IdleFeatures.kt` | 35 | running |  |
| `app/src/main/java/dev/geode/wallpaper/VisualizerDreamService.kt` | 135 | running | The visualizer as a screensaver (Daydream): the same renderer [VisualizerWallpaperService] |
| `app/src/main/java/dev/geode/wallpaper/VisualizerWallpaperService.kt` | 284 | running | Each engine instance — preview and home screen can both be live at once — owns its |

## `app` · main · `widget`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `app/src/main/java/dev/geode/widget/NowPlayingWidget.kt` | 149 | running | Artwork, title, artist and transport, redrawn whenever the playback service publishes a change. |
| `app/src/main/java/dev/geode/widget/WidgetPublisher.kt` | 88 | running | Mirrors the session's player into [WidgetState] and redraws the widget; artwork is decoded off the main thread… |
| `app/src/main/java/dev/geode/widget/WidgetState.kt` | 62 | running | What the home-screen widget shows, written by the playback service and read when the widget redraws. |

## build-logic (Gradle convention plugins)

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `build-logic/src/main/kotlin/ProvenanceRegistryReader.kt` | 19 | — |  |
| `build-logic/src/main/kotlin/ProvenanceRules.kt` | 108 | — |  |

## `engine/audio-android` · main · `engine.audioandroid`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/audio-android/src/main/kotlin/dev/geode/engine/audioandroid/PcmTap.kt` | 108 | running |  |
| `engine/audio-android/src/main/kotlin/dev/geode/engine/audioandroid/PcmTapFormat.kt` | 24 | running |  |
| `engine/audio-android/src/main/kotlin/dev/geode/engine/audioandroid/SinkClockContracts.kt` | 43 | running |  |
| `engine/audio-android/src/main/kotlin/dev/geode/engine/audioandroid/SinkClockDriver.kt` | 130 | running |  |

## `engine/audio-core` · main · `engine.audio`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/AudioPresentationClock.kt` | 82 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/ClockSegment.kt` | 47 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/DrumChannels.kt` | 40 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/MidSideWindow.kt` | 34 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/PcmSink.kt` | 9 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/PresentationMapping.kt` | 28 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/PulseReplay.kt` | 36 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/ReactiveAnalyzer.kt` | 159 | running |  |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/audio/SampleRing.kt` | 105 | running |  |

## `engine/audio-core` · main · `engine.bridge`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/audio-core/src/main/kotlin/dev/geode/engine/bridge/FeatureFrameLayout.kt` | 45 | running | Float offsets of `GeodeFeatureFrame` (core/api/geode_api.h); the order there is the order here. |
| `engine/audio-core/src/main/kotlin/dev/geode/engine/bridge/GeodeNative.kt` | 438 | running | [buffer] must be a direct float buffer holding [frames] interleaved frames; processed in place. |

## `engine/scenes` · main · `analysis`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/analysis/AnalysisCache.kt` | 290 | unreachable without UI |  |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/AnalysisEngine.kt` | 251 | running | A one-hop pulse held for the hops a display frame can span. |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/AnalysisIdentity.kt` | 12 | unreachable without UI |  |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/AudioFeatures.kt` | 73 | running | What the native HarmonicBalance reports before it has decided (its kUndecided). |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/BarTrim.kt` | 29 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/BeatTuning.kt` | 44 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/FeatureTimeline.kt` | 192 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/FrameAccumulator.kt` | 82 | unreachable without UI |  |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/OfflineAnalyzer.kt` | 282 | unreachable without UI | [stillWanted] is polled once per decoded buffer; returning false aborts the run with a |
| `engine/scenes/src/main/kotlin/dev/geode/analysis/PlaybackMath.kt` | 28 | running |  |

## `engine/scenes` · main · `audio`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/audio/AiffPcm.kt` | 138 | running |  |

## `engine/scenes` · main · `render`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/render/Adsr.kt` | 39 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/render/BlendMode.kt` | 24 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/render/CyclicPalettes.kt` | 6 | running | The cyclic palette rows of `shaders/cyclic_palettes.bin`, in texture order; the LUT itself is native. |
| `engine/scenes/src/main/kotlin/dev/geode/render/FramePacer.kt` | 395 | running | Receives one call per paced frame, on the thread that owns the Choreographer. |
| `engine/scenes/src/main/kotlin/dev/geode/render/Lfo.kt` | 173 | running | What a modulation slot listens to. |
| `engine/scenes/src/main/kotlin/dev/geode/render/SceneFactory.kt` | 14 | running | What an offscreen render needs to know about the scene it draws. |
| `engine/scenes/src/main/kotlin/dev/geode/render/ThermalGovernor.kt` | 66 | running | The platform's thermal readings, handed to the native governor that settles the render tier. |
| `engine/scenes/src/main/kotlin/dev/geode/render/TouchField.kt` | 378 | running | Where the fingers are, in one place every scene family can read. |
| `engine/scenes/src/main/kotlin/dev/geode/render/TransitionCatalog.kt` | 104 | running | Catalog of scene-to-scene transitions, both built-in and loaded from the GL Transitions asset. |
| `engine/scenes/src/main/kotlin/dev/geode/render/TransitionStyle.kt` | 9 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/render/UnderlayBlend.kt` | 22 | running | Blend function for a full-frame background image drawn UNDER/INTO the scene through |
| `engine/scenes/src/main/kotlin/dev/geode/render/VisualizerRenderer.kt` | 245 | running | The GL-thread adapter over the native renderer: every frame is one `geode_viz_render`. |
| `engine/scenes/src/main/kotlin/dev/geode/render/VisualizerView.kt` | 118 | running | Vsync, not `eglSwapBuffers` back-pressure, is what asks for a frame here. `requestRender` |

## `engine/scenes` · main · `render.bridge`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/render/bridge/FeatureFrameCodec.kt` | 53 | running | Lays an [AudioFeatures] out as a `GeodeFeatureFrame`; every scalar the native frame has is carried. |
| `engine/scenes/src/main/kotlin/dev/geode/render/bridge/ModConfigCodec.kt` | 40 | running | The float layouts `geode_viz_set_lfo` and `geode_viz_set_adsr` read; enums travel as ordinals. |
| `engine/scenes/src/main/kotlin/dev/geode/render/bridge/NativeViz.kt` | 252 | running | Owns one `geode_viz` handle: the native renderer behind a GL surface or an offscreen target. |
| `engine/scenes/src/main/kotlin/dev/geode/render/bridge/SceneParamsCodec.kt` | 306 | running | Packs [SceneParams] in `geode_viz_param_name` order; [verify] proves that order against the library once. |

## `engine/scenes` · main · `render.offscreen`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/render/offscreen/OffscreenSceneRenderer.kt` | 117 | running | Everything needed to render one offscreen sequence: the frame grid and the parameter |

## `engine/scenes` · main · `render.scene`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/CymaticsMath.kt` | 228 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/GlUtil.kt` | 112 | running | The GL helpers the app's own export passes still use; the scenes themselves are native. |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/ParamKeys.kt` | 155 | running | The user-facing name of every Customize parameter. |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/ParamScope.kt` | 328 | running | Which styles a Customize parameter can actually move. |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/PcmSink.kt` | 13 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/SceneCapabilities.kt` | 140 | running | Which scene class a style id builds. One entry per renderer, not per style. |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/SceneIds.kt` | 49 | running |  |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/SceneParams.kt` | 266 | running | March-step budget for the raymarched fragment styles, 0.25..1.5. |
| `engine/scenes/src/main/kotlin/dev/geode/render/scene/VisualStyleCatalog.kt` | 917 | running | Catalog of the per-scene visual styles the engine can render. |

## `engine/scenes` · main · `util`

| File | Lines | Status | First doc comment |
|---|---:|---|---|
| `engine/scenes/src/main/kotlin/dev/geode/util/BestEffort.kt` | 18 | running | Runs [block] for its side effect where a failure is genuinely acceptable — teardown, cache |
