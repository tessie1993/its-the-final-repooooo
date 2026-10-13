#version 460 core
#include <flutter/runtime_effect.glsl>

// Float slots are shared by SceneSurface and the optional WebGL study.
uniform vec2 uResolution;     // 0, 1: logical canvas pixels
uniform float uTime;          // 2: seconds
uniform vec2 uTilt;           // 3, 4: spring position, -1..1
uniform float uEnergy;        // 5: 0..1
uniform float uMaterial;      // 6: 0 water, 1 opal, 2 mercury (interpolated)
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
uniform sampler2D uEnvironment; // sampler slot 0

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
  return color * vec3(.88, .98, 1.02);
}

float sphereField(vec3 point) {
  float t = uTime * (1.0 - uReducedMotion);
  vec3 p = point;
  p.xy -= vec2(uTilt.x, -uTilt.y) * .075;
  p.y -= sin(t * .75) * .019;
  float radius = .57 + uPulse * .018;
  float wave = sin(p.x * 7.0 + t * 1.15) *
               sin(p.y * 6.0 - t * .83) *
               sin(p.z * 5.0 + t * .6);
  float shortest = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 uv = uCenter + vec2(point.x, -point.y) * uOrbScale * shortest * .5 / uResolution;
  float touchDeformation = gelWave(uv).z * .026;
  return length(p) - radius + wave * (.005 + uEnergy * .012) + touchDeformation;
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

vec3 glassSurface(vec3 position, vec3 normal, vec2 uv) {
  vec3 eye = vec3(0.0, 0.0, 1.0);
  float facing = clamp(dot(normal, eye), 0.0, 1.0);
  float fresnel = .025 + .975 * pow(1.0 - facing, 4.2);
  vec3 reflection = reflect(-eye, normal);
  vec2 bend = vec2(normal.x, -normal.y);
  float lens = .11 + facing * .13;
  vec2 refractedUv = uv - bend * lens * uOrbScale;
  // RGB dispersion at a glass edge, subtle enough to remain photographic.
  vec3 transmitted;
  transmitted.r = environment(refractedUv + bend * .0030).r;
  transmitted.g = environment(refractedUv).g;
  transmitted.b = environment(refractedUv - bend * .0030).b;
  float thickness = max(.06, position.z * 1.7);
  transmitted *= exp(-vec3(1.55, .32, .16) * thickness);
  transmitted += vec3(.015, .14, .19) * (1.0 - facing) * .40;

  vec3 reflected = environment(vec2(.5) + vec2(reflection.x, -reflection.y) * .43);
  reflected *= vec3(.82, 1.07, 1.15);
  vec3 water = mix(transmitted, reflected, fresnel * .75 + .09);
  // A broad upper-left softbox and a fine secondary rim give the object volume.
  vec3 light = normalize(vec3(-.55, .85, 1.20));
  float key = pow(max(dot(reflection, light), 0.0), 55.0);
  float sheen = pow(max(dot(normal, normalize(vec3(-.5, .72, .26))), 0.0), 24.0);
  float rim = pow(1.0 - facing, 2.4);
  float rimLight = smoothstep(-.3, .8, dot(normal, normalize(vec3(-.6, .65, .0))));
  water += vec3(.70, .94, 1.0) * (key * .76 + sheen * .38 + rim * rimLight * .42);
  water += vec3(.02, .21, .29) * pow(1.0 - facing, 8.0);

  float iridescence = sin((normal.x + normal.y) * 7.0 + uTime * .15);
  vec3 pearlTint = mix(vec3(.34, .67, .83), vec3(.94, .61, .76), iridescence * .5 + .5);
  vec3 opal = mix(water, pearlTint * (.66 + facing * .30), .60);
  opal += vec3(key * .60 + sheen * .35);
  vec3 silver = reflected * (.62 + facing * .42) + vec3(key * 1.15 + sheen * .54);
  silver = mix(silver, vec3(.86, .96, 1.0), rim * rimLight * .60);
  vec3 material = mix(water, opal, clamp(uMaterial, 0.0, 1.0));
  material = mix(material, silver, clamp(uMaterial - 1.0, 0.0, 1.0));
  return material;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float shortest = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 p = (frag - uCenter * uResolution) * 2.0 / shortest;
  p.y = -p.y;
  p /= max(uOrbScale, .1);
  vec3 gel = gelWave(uv);
  // Every touch refracts the photographic gel field at its actual location.
  vec2 gelUv = uv + gel.xy * .009 * shortest / uResolution;
  vec3 color = environment(gelUv);
  color += vec3(.18, .34, .35) * gel.z * .10;
  float vignette = smoothstep(.14, .85, distance(uv, vec2(.5, .43)));
  color *= 1.0 - vignette * .24;

  // Grounding: soft contact shadow, cool caustic and expanding water rings.
  vec2 floorP = vec2(p.x, (p.y + .73) * 4.4);
  float shadow = exp(-dot(floorP * vec2(1.20, 1.6), floorP * vec2(1.20, 1.6)) * 3.0);
  color *= 1.0 - shadow * .17;
  float radius = length(floorP);
  float caustic = exp(-pow((radius - .59) * 17.0, 2.0));
  color += vec3(.11, .29, .33) * caustic * .15;
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
      color = glassSurface(position, normal, uv);
    }
  }
  fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
