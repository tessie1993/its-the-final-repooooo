# Geode: nature in motion

This step replaces the Flutter counter scaffold with a nature material interface.
The shared rule is **everything is suspended in one touch-reactive gel field**.
The photographic components are real app assets, not pictures of a proposed UI.

## Navigation

| Destination | Working UI in this step | Connection still required |
| --- | --- | --- |
| Visuals | Raymarched glass sculpture, presets, material/motion/palette editor, particle controls, immersive view | Native audio-reactive surface |
| Music | Local audio import/playback, six collection views, playlists, queue, lyrics, speed/pitch/EQ controls | Existing native audio engine host |
| Studio | Five-lane project editor, clip properties, markers/keyframes, undo/redo, project JSON export | Native media preview/composition and video export |
| Settings | Persisted appearance, comfort/haptic controls, audio settings, local collection status | Native wallpaper integration |

The music controller uses just_audio and copies imported tracks into private app
storage. Project, look and appearance data use versioned Flutter namespaces;
legacy native stores remain untouched. Native render output is clearly marked
unavailable. Dependencies need `flutter pub get` on a working SDK.

## File and component boundaries

| Files | Responsibility |
| --- | --- |
| `apps/geode/lib/main.dart`, `app.dart` | Bootstrap, four destinations, global pointer coordinates, safe areas, back/immersive behavior |
| `lib/state/geode_app_state.dart` | Persisted screen state, presets and preferences; never listens to every frame |
| `lib/scene/geode_scene_controller.dart` | Shared spring state, local touch waves, bounded displacement, preferences |
| `lib/scene/scene_surface.dart` | Single lifecycle-aware ticker, asset/shader resources, rendering and fallback |
| `lib/scene/gel_float.dart` | Translate and tilt reusable controls using an isolated child, up to six logical pixels |
| `shaders/liquid_glass.frag` | SDF sculpture, environment transmission/reflection, touch refraction and water rings |
| `lib/components/` | Photographic pebble buttons, dew controls, glass panels, materials, slider, dock, thumbnails |
| `lib/screens/` | Visuals, Music, Studio and Settings compositions |
| `lib/theme/geode_theme.dart` | Ice, forest and mint colors, typography, targets and Flutter theme |

Dependency order: assets and theme → scene controller/shader and components →
screen state → screens → shell. The native FFI barrel is intentionally not
imported by the UI: currently it eagerly opens `libgeode.so`, and the host has
not yet implemented `VisualizerSurface`.

## Material vocabulary

- **Moss glass pebble:** transparent blue quartz/gel, photographed moss and tiny
  fern edges; the primary button and free-floating navigation object.
- **Fern dew:** a small fern suspended inside a refractive water droplet; round
  actions, scene thumbnails and the brand mark.
- **Water:** transparent blue transmission, absorption and Fresnel edge light.
- **Opal:** softly iridescent quartz-like scattering over the water material.
- **Mercury:** reflective liquid-silver finish (a visual material only).
- **Panel shell:** independently blurred forest, cool translucent body, double
  specular rim, soft shadow. Text is not warped by the scene shader.

Assets are generated imagery. `assets/images/forest-sanctuary.png` was available
from the earlier visual study; the two transparent nature components were created
with the built-in image generator for this step. No external runtime image URLs.

## Touch, motion and FX

One pointer Listener surrounds the Navigator and the shared scene. Touching a control also excites
the gel. A maximum of four impulses is retained. Drag wakes are rate-limited.
Waves travel from the actual touch location and attenuate with distance and time.
Components apply delayed radial displacement weighted by apparent mass.

The spring uses unit mass, stiffness 38 and damping 10.5; frame dt is capped at
50 ms and subdivided to at most 1/120 s. Component travel is bounded to ±6 px.
The shader raymarches a 3D signed-distance surface, with 48 steps and six normal
samples at high quality or 32 steps and four normal samples at reduced quality.
A single decoded environment image feeds transmission and reflection. Particle
positions are deterministic, with no per-frame random allocation.

This is an artistic damped-wave field and refractive 3D sculpture, **not** a full
Navier–Stokes gel simulation, a mesh-based world, or a path-traced scene. The
photographic buttons are raster surfaces with live composited movement; their
fern geometry is not independently simulated.

Pause freezes time. App/system reduced motion disables waves, drifting and
button press scaling. The ticker stops for background lifecycle and hidden
TickerMode. Shader failure preserves a photographic Canvas fallback.

## Native handoff

When the host is ready, keep audio buffers and rendering off the widget rebuild
path. Retain the stable native scene IDs. The existing native APIs accept:

- `geode_viz_set_touch`: up to five y-up NDC points; zero points on release.
- `geode_viz_queue_touch_stroke`: 0..1 position, delta, dt and strength.
- Latched scene parameter setters; GL-thread-only render/surface operations.

The nature UI does not rename or change these APIs or the existing native code.

## Validation and run instructions

Use Flutter 3.47.7 / Dart 3.13.5 or a version satisfying the workspace manifests:

```sh
cd geode
flutter pub get
cd apps/geode
flutter analyze
flutter test
flutter run
```

The existing scaffold smoke test was updated to exercise real navigation, the
music destination and reduced-motion control. No passing run is claimed:
Flutter/Dart sources and the matching SDK were obtained in this environment,
but Dart VM startup aborts with `Failed to retrieve stack bounds` before running
analysis, tests or builds. Device frame rate, shader compatibility, text scaling
and final rendered layout therefore still require verification on a working SDK.

Static checks completed: all 60 Dart source/test files parse without syntax errors;
all image/shader references resolve; the 32 float uniform slots and one image
sampler match the Dart renderer; whitespace checks pass. These do not establish
type correctness, successful shader compilation, visual layout or device performance.

Shader API reference: https://docs.flutter.dev/ui/design/graphics/fragment-shaders
