#version 460 core
#include <flutter/runtime_effect.glsl>

// Float slots are shared by SceneSurface and the optional WebGL study.
uniform vec2 uResolution;     // 0, 1: logical canvas pixels
uniform float uTime;          // 2: seconds
uniform vec2 uTilt;           // 3, 4: spring position, -1..1
uniform float uEnergy;        // 5: 0..1
uniform float uMaterial;      // 6: 0 moss, 1 river stone, 2 bark (interpolated)
uniform float uPulse;         // 7: decaying touch impulse, 0..1
uniform vec2 uCenter;         // 8, 9: normalized orb center
uniform float uOrbScale;      // 10: base sphere radius = .285 * shortest side
uniform vec2 uImageSize;      // 11, 12: environment image dimensions
uniform float uReducedMotion;// 13: 0 or 1
uniform float uHighQuality;  // 14: full-quality normals and 48 ray steps
uniform vec4 uTouch0;        // 15..18: normalized x/y, age seconds, strength
uniform vec4 uTouch1;        // 19..22
uniform vec4 uTouch2;        // 23..26
uniform vec4 uTouch3;        // 27..30
uniform float uHue;         // 31: centered hue rotation, .5 is neutral
uniform float uAudioRms;    // 32: live measured PCM envelope
uniform float uAudioBass;   // 33: live measured bass envelope
uniform float uLuminescence; // 34: user-selected living light
uniform sampler2D uEnvironment; // sampler slot 0
uniform sampler2D uMoss;        // sampler slot 1
uniform sampler2D uStone;       // sampler slot 2
uniform sampler2D uBark;        // sampler slot 3
uniform sampler2D uVeins;       // sampler slot 4: transparent bioluminescence

out vec4 fragColor;

vec3 touchWave(vec2 uv, vec4 touch) {
  float shortest = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 delta = (uv - touch.xy) * uResolution / shortest;
  float distance = length(delta);
  float age = touch.z - distance / .65;
  if (age < 0.0 || age > 3.8 || touch.w < .01 || uReducedMotion > .5) return vec3(0.0);
  float envelope = smoothstep(0.0, .06, age) * exp(-age * 2.1 - distance * .75) * touch.w;
  vec2 radial = delta / max(distance, .002);
  float phase = age * 11.0;
  return vec3(radial * cos(phase) * envelope, sin(phase) * envelope);
}

vec3 gelWave(vec2 uv) {
  return touchWave(uv, uTouch0) + touchWave(uv, uTouch1) +
         touchWave(uv, uTouch2) + touchWave(uv, uTouch3);
}

vec2 coverUv(vec2 uv) {
  float screenAspect = uResolution.x / max(uResolution.y, 1.0);
  float imageAspect = uImageSize.x / max(uImageSize.y, 1.0);
  vec2 crop = vec2(min(screenAspect / imageAspect, 1.0),
                   min(imageAspect / screenAspect, 1.0));
  return (uv - .5) * crop + .5;
}

vec3 environment(vec2 uv) {
  vec2 coordinate = coverUv(uv);
  coordinate += uTilt * vec2(.007, .004);
  vec3 color = texture(uEnvironment, clamp(coordinate, vec2(.001), vec2(.999))).rgb;
  return color * vec3(.98, 1.0, .91);
}

float sphereField(vec3 point) {
  float t = uTime * (1.0 - uReducedMotion);
  vec3 p = point;
  p.xy -= vec2(uTilt.x, -uTilt.y) * .075;
  p.y -= sin(t * .75) * .019;
  float radius = .57 + uPulse * .035 + uAudioBass * .022;
  float wave = sin(p.x * 7.0 + t * 1.15) *
               sin(p.y * 6.0 - t * .83) *
               sin(p.z * 5.0 + t * .6);
  float shortest = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 uv = uCenter + vec2(point.x, -point.y) * uOrbScale * shortest * .5 / uResolution;
  float touchDeformation = gelWave(uv).z * .026;
  p *= vec3(.93, 1.10, 1.22);
  return length(p) - radius + wave * (.014 + uEnergy * .012) + touchDeformation * .55;
}

float sceneField(vec3 p) {
  float t = uTime * (1.0 - uReducedMotion);
  float d = sphereField(p);
  // Separate 3D satellites, with slow depth motion and distinct sphere normals.
  vec3 a = vec3(-.62, .60 + sin(t * .9) * .033, .09);
  vec3 b = vec3(.70, .26 + sin(t * .7 + 1.0) * .042, -.12);
  vec3 c = vec3(-.72, -.27 + sin(t * 1.1 + 2.0) * .024, .13);
  vec3 e = vec3(.39, .79 + cos(t * .6) * .023, -.04);
  a.xy += vec2(uTilt.x, -uTilt.y) * .10;
  b.xy += vec2(uTilt.x, -uTilt.y) * .035;
  return min(min(min(d, length(p - a) - .065),
                     length(p - b) - .034),
             min(length(p - c) - .024, length(p - e) - .016));
}

vec3 surfaceNormal(vec3 p) {
  if (uHighQuality < .5) {
    // Four tetrahedral samples conserve work without flattening the sculpture.
    const vec2 k = vec2(1.0, -1.0) * .0018;
    return normalize(k.xyy * sceneField(p + k.xyy) +
                     k.yyx * sceneField(p + k.yyx) +
                     k.yxy * sceneField(p + k.yxy) +
                     k.xxx * sceneField(p + k.xxx));
  }
  const float e = .0015;
  return normalize(vec3(
    sceneField(p + vec3(e, 0, 0)) - sceneField(p - vec3(e, 0, 0)),
    sceneField(p + vec3(0, e, 0)) - sceneField(p - vec3(0, e, 0)),
    sceneField(p + vec3(0, 0, e)) - sceneField(p - vec3(0, 0, e))
  ));
}

float mineralNoise(vec3 p) {
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 natureSurface(vec3 position, vec3 normal, vec2 screenUv) {
  vec3 light = normalize(vec3(-.55, .85, 1.20));
  float diffuse = max(dot(normal, light), 0.0);
  // Photograph-based material maps follow the curved world-space surface.
  vec2 textureUv = fract(position.xy * .78 + position.z * vec2(.16, .09) + .5);
  vec3 moss = texture(uMoss, textureUv).rgb;
  vec3 stone = texture(uStone, textureUv).rgb;
  vec3 bark = texture(uBark, textureUv).rgb;
  vec3 material = mix(moss, stone, clamp(uMaterial, 0.0, 1.0));
  material = mix(material, bark, clamp(uMaterial - 1.0, 0.0, 1.0));
  float edge = pow(1.0 - max(normal.z, 0.0), 2.0);
  // Organic transmission keeps the landscape visible through the softer core,
  // while the textured outer rim preserves the form of the moss and stone.
  vec3 behind = environment(screenUv + normal.xy * vec2(.012, -.012));
  float transmission = .46 + (1.0 - edge) * .18;
  vec3 lit = material * (.48 + diffuse * .95);
  vec3 color = mix(lit, behind * vec3(.90, 1.0, .94), transmission);
  vec4 veins = texture(uVeins, textureUv);
  float envelope = uLuminescence * (.32 + uAudioRms * .72 + uAudioBass * .36 + uPulse * .25);
  float breathing = .88 + .12 * sin(uTime * .8) * (1.0 - uReducedMotion);
  // Flutter image samplers already contain premultiplied alpha.
  vec3 emission = veins.rgb * envelope * breathing;
  // Living sap: lit internal filaments and soft rounded edge scattering.
  float filament = pow(.5 + .5 * sin(position.y * 24.0 + sin(position.x * 14.0)
      + position.z * 18.0 + uTime * .16 * (1.0 - uReducedMotion)), 18.0);
  color += emission + vec3(.08, .64, .40) * edge * envelope * .5;
  color += vec3(.04, .48, .29) * filament * envelope * .22;
  vec3 halfLight = normalize(light + vec3(0.0, 0.0, 1.0));
  color += vec3(.55, .77, .57) * pow(max(dot(normal, halfLight), 0.0), 20.0) * .09;
  vec3 tint = .92 + .08 * cos((uHue - .5) * 6.2831853 + vec3(0.0, 2.1, 4.2));
  return color * tint;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float shortest = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 p = (frag - uCenter * uResolution) * 2.0 / shortest;
  p.y = -p.y;
  p /= max(uOrbScale, .1);
  vec3 gel = gelWave(uv);
  // Touch waves travel across the lake behind the solid natural materials.
  // Slow gel advection remains subtle enough to keep the environment legible.
  float clock = uTime * (1.0 - uReducedMotion);
  float pool = smoothstep(.35, .65, uv.y);
  vec2 drift = vec2(sin(uv.y * 18.0 + clock * .32),
      cos(uv.x * 16.0 - clock * .24)) * .0015 * pool;
  vec2 gelUv = uv + drift + gel.xy * .012 * shortest / uResolution;
  vec3 color = environment(gelUv);
  color += vec3(.05, .7, .48) * abs(gel.z) * uLuminescence * .35;
  // Fine caustics live below the surface of the gel pool.
  float caustic = sin(uv.x * 43.0 + sin(uv.y * 28.0 + clock * .4))
      * sin(uv.y * 39.0 - sin(uv.x * 22.0 - clock * .3));
  color += vec3(.02, .22, .16) * pow(max(caustic, 0.0), 8.0)
      * pool * uLuminescence * (.25 + uAudioBass * .5);
  float vignette = smoothstep(.14, .85, distance(uv, vec2(.5, .43)));
  color *= 1.0 - vignette * .24;

  // Grounding: soft contact shadow and expanding ripples on the lake.
  vec2 floorP = vec2(p.x, (p.y + .73) * 4.4);
  float shadow = exp(-dot(floorP * vec2(1.20, 1.6), floorP * vec2(1.20, 1.6)) * 3.0);
  color *= 1.0 - shadow * .17;
  float radius = length(floorP);

  float rings = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float phase = fract(uTime * .095 + fi * .333);
    float ringRadius = .64 + phase * .85;
    float line = exp(-pow((radius - ringRadius) * 125.0, 2.0));
    rings += line * (1.0 - phase) * (.18 + uEnergy * .12);
  }
  color += vec3(.47, .70, .74) * rings * (1.0 - uReducedMotion);

  // Conservative bounds avoid ray marching background pixels.
  if (abs(p.x) < .91 && abs(p.y) < .96) {
    vec3 origin = vec3(p, 1.6);
    vec3 direction = vec3(0.0, 0.0, -1.0);
    float travel = 0.0;
    float hit = 0.0;
    vec3 position = origin;
    for (int i = 0; i < 48; i++) {
      if (uHighQuality < .5 && i >= 32) break;
      position = origin + direction * travel;
      float distanceToSurface = sceneField(position);
      if (distanceToSurface < .0012) { hit = 1.0; break; }
      travel += max(distanceToSurface * .87, .0008);
      if (travel > 2.45) break;
    }
    if (hit > .5) {
      vec3 normal = surfaceNormal(position);
      color = natureSurface(position, normal, uv);
    }
  }
  fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
