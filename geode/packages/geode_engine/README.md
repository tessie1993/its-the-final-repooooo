# Geode engine

Flutter state and texture integration for the existing C++ audio visualizer.

`AudioFeatureFrame` decodes the 237-float `GeodeFeatureFrame` ABI into immutable
PCM analysis snapshots. The original analyzer supplies the 64 spectrum bands,
128 waveform samples, chroma, beat/onset and energy values.

`GeodeVisualController` loads the native scene and MilkDrop catalogs, serializes
renderer commands and retains selection/parameters across texture recreation.
`NativeVisualizerTexture` displays the native EGL output through Flutter's
texture registry, adapts to viewport changes, and suspends rendering when the
application is backgrounded. User pause and lifecycle pause remain independent.

Android owns the native surface. Other platforms and tests with device services
disabled keep the Flutter nature renderer without opening native libraries.
