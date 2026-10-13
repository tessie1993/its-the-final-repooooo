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
  return color * vec3(.98, 1.0, .91);
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
  p *= vec3(.93, 1.10, 1.22);
  return length(p) - radius + wave * .007 + touchDeformation * .28;
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

vec3 natureSurface(vec3 position, vec3 normal) {
  vec3 light = normalize(vec3(-.55, .85, 1.20));
  float diffuse = max(dot(normal, light), 0.0);
  float grain = mineralNoise(floor(position * 190.0));
  float mossPatch = sin(position.x * 9.0 + sin(position.y * 7.0)) *
                    sin(position.z * 8.0 - position.y * 4.0);
  vec3 jade = mix(vec3(.075, .16, .105), vec3(.27, .36, .16),
                  smoothstep(-.1, .58, mossPatch));
  float vein = pow(abs(sin(position.x * 6.0 + position.y * 8.0 + sin(position.z * 11.0))), 24.0);
  jade += vec3(.19, .18, .11) * vein * .34;
  vec3 stone = mix(vec3(.22, .25, .22), vec3(.48, .49, .40), grain * .2 + vein * .22);
  float rings = sin(length(position.xy + vec2(.12, -.14)) * 88.0 + sin(position.y * 12.0) * 3.0);
  vec3 bark = mix(vec3(.18, .105, .055), vec3(.38, .255, .13), rings * .5 + .5);
  vec3 material = mix(jade, stone, clamp(uMaterial, 0.0, 1.0));
  material = mix(material, bark, clamp(uMaterial - 1.0, 0.0, 1.0));
  material *= .76 + grain * .24;
  // Soft diffuse daylight and a restrained satin highlight: every material is
  // opaque. No environment refraction, transparent shell or emissive glass rim.
  vec3 color = material * (.43 + diffuse * .85);
  vec3 halfLight = normalize(light + vec3(0.0, 0.0, 1.0));
  color += vec3(.80, .79, .58) * pow(max(dot(normal, halfLight), 0.0), 18.0) * .07;
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
  vec2 gelUv = uv + gel.xy * .009 * shortest / uResolution;
  vec3 color = environment(gelUv);
  color += vec3(.18, .34, .35) * gel.z * .10;
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
      color = natureSurface(position, normal);
    }
  }
  fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
