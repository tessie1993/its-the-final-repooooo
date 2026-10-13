import 'page_spec.dart';

/// Visuals: choosing and shaping what the visualizer draws.
const visualsPage = PageSpec(
  id: 'visuals',
  title: 'Visuals',
  summary: 'Presets, styles, the Customize panel, MilkDrop textures and recorded takes.',
  surface: PageSurface.visualizer,
  features: [
    'The live visualizer runs behind the hub while you edit',
    'Auto visuals: a visual playlist, random mode and scene suggestions from the track analysis',
    'Key colour (detected musical key → hue) and palette from the artwork',
  ],
  poweredBy: [
    'C++ geode_viz: scenes, parameters, LFO/ADSR, transitions, safety clamp',
    'Dart: preset / template / texture stores, parameter catalog and randomizer',
  ],
  tabs: [_presetsTab, _stylesTab, _customizeTab, _texturesTab, _takesTab],
);

const _presetsTab = PageSpec(
  id: 'presets',
  title: 'Presets',
  features: [
    'Preset tree with folders; built-in looks plus your own',
    'Apply live with a timed glide; save the current look; share as a link or file',
    'Import MilkDrop .milk presets (single file or folder)',
    'Visual playlist: presets that change on a timer or with the music',
  ],
  poweredBy: ['Dart: preset store (JSON, same format as the old app)'],
  sheets: [templatesSheet, backgroundSheet],
);

const _stylesTab = PageSpec(
  id: 'styles',
  title: 'Styles',
  summary: 'Every visual style, by family.',
  tabs: [
    PageSpec(id: 'silk', title: 'Silk', features: ['9 advected strand-field styles (GPU compute)']),
    PageSpec(id: 'life', title: 'Life', features: ['9 Lenia / Gray-Scott cellular styles']),
    PageSpec(id: 'mycelium', title: 'Mycelium', features: ['9 physarum agent styles']),
    PageSpec(id: 'acid', title: 'Acid', features: ['10 video-feedback styles']),
    PageSpec(
      id: 'shaders',
      title: 'Shaders',
      features: ['39 fragment-shader styles (fractals, tunnels, raymarched bodies, nebulae…)'],
    ),
    PageSpec(
      id: 'fluid',
      title: 'Fluid',
      features: ['9 looks over one stable-fluids solver, plus Curl Flow and Water'],
    ),
    PageSpec(
      id: 'cymatics',
      title: 'Cymatics',
      features: ['10+ resonant-plate styles driven by the spectrum'],
    ),
    PageSpec(
      id: 'milkdrop',
      title: 'MilkDrop',
      features: ['projectM 4 presets, with texture linking'],
      poweredBy: ['C++ MilkdropScene (projectM 4.1.7, patched for FBO rendering)'],
    ),
  ],
);

const _customizeTab = PageSpec(
  id: 'customize',
  title: 'Customize',
  summary: 'Every parameter of the current style. Controls that do nothing for it are hidden.',
  features: [
    'Toolbar: search parameters, randomize (respects locks), undo/redo, reset tab or all',
    'Per-parameter locks; A/B snapshots with a blend slider',
    'Layers: a second scene mixed over the first with a blend mode',
    'Modulators: 3 LFOs and 2 ADSR envelopes, each with a source and a target',
    'Palette maker',
  ],
  poweredBy: [
    'C++ geode_viz_set_params / set_lfo / set_adsr',
    'Dart: parameter scope and keys catalogs, randomizer, A/B blend',
  ],
  tabs: [
    PageSpec(
      id: 'shape',
      title: 'Shape',
      features: ['Geometry: zoom, symmetry, kaleidoscope, tile, morph, twist…'],
    ),
    PageSpec(
      id: 'colour',
      title: 'Colour',
      features: ['Palette, saturation, brightness, contrast, colour cycle, key colour'],
    ),
    PageSpec(id: 'motion', title: 'Motion', features: ['Speed, sway, drift, rotation, endless zoom, dive']),
    PageSpec(id: 'fx', title: 'FX', features: ['Trails, bloom, vignette, pixelate, posterize, warp echo']),
    PageSpec(
      id: 'reactivity',
      title: 'Reactivity',
      features: ['Audio drive, form drive, transient response, band gains (bass/mid/treble)'],
    ),
    PageSpec(
      id: 'scene',
      title: 'Scene',
      features: ['Choices about the style itself; transitions between styles'],
    ),
    PageSpec(id: 'fluid', title: 'Fluid', features: ['Solver and emitter controls (fluid styles only)']),
    PageSpec(id: 'cymatics', title: 'Cymatics', features: ['Plate controls (cymatics styles only)']),
    PageSpec(
      id: 'glsl',
      title: 'GLSL',
      features: ['In-app GLSL editor for shader styles; compile errors shown inline'],
      poweredBy: ['C++ geode_viz_set_custom_shader'],
    ),
  ],
);

const _texturesTab = PageSpec(
  id: 'textures',
  title: 'Textures',
  features: [
    'Import PNG/JPG/TGA textures for MilkDrop presets',
    'Link a preset\'s missing texture to one you have; see which presets use which texture',
  ],
  poweredBy: ['Dart: texture store + texture links', 'C++ geode_viz_set_milk_texture_dir'],
);

const _takesTab = PageSpec(
  id: 'takes',
  title: 'Takes',
  features: [
    'Record a performance: every parameter change you make while the music plays',
    'Replay, rename, delete, or render a take to video in Studio',
  ],
  poweredBy: ['Dart: take recorder and timeline'],
);

const templatesSheet = PageSpec(
  id: 'templates',
  title: 'Video templates',
  kind: PageKind.sheet,
  features: [
    'Starter templates (Reel Neon, Lo-Fi Loop, Vinyl Spin, Album Teaser, Podcast Bars, Master 4K)',
    'Save the current look as a template; share as a link; import from text or file',
  ],
  poweredBy: ['Dart: template format (keeps fields from newer versions)'],
);

const backgroundSheet = PageSpec(
  id: 'background',
  title: 'Background image',
  kind: PageKind.sheet,
  features: ['Pick an image behind the scene; blend (screen / multiply / add), amount, blur, dim'],
  poweredBy: ['C++ geode_viz_set_underlay_rgba'],
);
