#!/usr/bin/env python3
"""Writes apps/geode/assets/models/geode_crystal.glb, the interactive geode shown by the
model viewer on the Visuals screen.

A split geode: a rough, faceted river-stone shell open at the front, lined with a cluster of
amethyst-to-jade quartz points. Flat-shaded (one normal per face) so the facets catch light.
Deterministic: the same seed always produces byte-identical output.

    python3 geode/tools/make_geode_crystal_glb.py
"""
import json
import math
import random
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "apps/geode/assets/models/geode_crystal.glb"
rng = random.Random(1337)


def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def norm(v):
    length = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return (v[0] / length, v[1] / length, v[2] / length)


class Mesh:
    def __init__(self):
        self.positions, self.normals, self.colors = [], [], []

    def tri(self, a, b, c, color):
        n = norm(cross(sub(b, a), sub(c, a)))
        for p in (a, b, c):
            self.positions.append(p)
            self.normals.append(n)
            self.colors.append(color)


def icosphere(subdivisions):
    t = (1 + math.sqrt(5)) / 2
    verts = [norm(v) for v in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
                               (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(subdivisions):
        cache, next_faces = {}, []

        def mid(i, j):
            key = (min(i, j), max(i, j))
            if key not in cache:
                a, b = verts[i], verts[j]
                verts.append(norm(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)))
                cache[key] = len(verts) - 1
            return cache[key]
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            next_faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = next_faces
    return verts, faces


def shell():
    """Outer rock: a lumpy sphere with the front cap (z > 0.35) cut away, plus an inner wall."""
    mesh = Mesh()
    verts, faces = icosphere(3)
    bump = [1 + rng.uniform(-0.07, 0.07) for _ in verts]
    outer = [(v[0] * 1.0 * s, v[1] * 0.86 * s, v[2] * 0.92 * s) for v, s in zip(verts, bump)]
    inner = [(p[0] * 0.82, p[1] * 0.82, p[2] * 0.82) for p in outer]
    for a, b, c in faces:
        if (verts[a][2] + verts[b][2] + verts[c][2]) / 3 > 0.35:
            continue
        shade = rng.uniform(0.82, 1.0)
        mesh.tri(outer[a], outer[b], outer[c], (0.30 * shade, 0.27 * shade, 0.22 * shade, 1))
        # Inner wall faces inward (reversed winding), a lighter chalcedony band.
        band = rng.uniform(0.85, 1.0)
        mesh.tri(inner[a], inner[c], inner[b], (0.62 * band, 0.70 * band, 0.66 * band, 1))
    # Rim joining outer and inner surfaces around the opening.
    for a, b, c in faces:
        inside = [verts[i][2] > 0.35 for i in (a, b, c)]
        if any(inside) and not all(inside):
            edge = [i for i, flag in zip((a, b, c), inside) if not flag]
            if len(edge) == 2:
                i, j = edge
                mesh.tri(outer[i], inner[i], outer[j], (0.50, 0.47, 0.40, 1))
                mesh.tri(outer[j], inner[i], inner[j], (0.50, 0.47, 0.40, 1))
    return mesh


def crystal(mesh, base, direction, length, radius, color):
    """A hexagonal quartz prism with a six-sided pyramidal termination."""
    d = norm(direction)
    helper = (0, 1, 0) if abs(d[1]) < 0.9 else (1, 0, 0)
    u = norm(cross(d, helper))
    v = cross(d, u)
    ring = lambda center, r: [
        (center[0] + (u[0] * math.cos(k * math.pi / 3) + v[0] * math.sin(k * math.pi / 3)) * r,
         center[1] + (u[1] * math.cos(k * math.pi / 3) + v[1] * math.sin(k * math.pi / 3)) * r,
         center[2] + (u[2] * math.cos(k * math.pi / 3) + v[2] * math.sin(k * math.pi / 3)) * r)
        for k in range(6)]
    shaft = length * 0.72
    top_center = (base[0] + d[0] * shaft, base[1] + d[1] * shaft, base[2] + d[2] * shaft)
    tip = (base[0] + d[0] * length, base[1] + d[1] * length, base[2] + d[2] * length)
    bottom, top = ring(base, radius), ring(top_center, radius * 0.92)
    for k in range(6):
        n = (k + 1) % 6
        mesh.tri(bottom[k], bottom[n], top[n], color)
        mesh.tri(bottom[k], top[n], top[k], color)
        lit = tuple(min(1.0, c * 1.18) for c in color[:3]) + (color[3],)
        mesh.tri(top[k], top[n], tip, lit)


def cluster():
    mesh = Mesh()
    palette = [(0.55, 0.36, 0.78, 0.82), (0.66, 0.48, 0.86, 0.82), (0.42, 0.74, 0.62, 0.82),
               (0.78, 0.70, 0.92, 0.82)]
    for _ in range(46):
        # Crystals grow from the inner wall toward the geode's centre.
        theta = rng.uniform(0, 2 * math.pi)
        phi = rng.uniform(0.15, 2.2)
        wall = (math.sin(phi) * math.cos(theta) * 0.8, math.sin(phi) * math.sin(theta) * 0.7,
                -math.cos(phi) * 0.75)
        inward = (-wall[0] + rng.uniform(-0.2, 0.2), -wall[1] + rng.uniform(-0.2, 0.2),
                  -wall[2] + 0.6)
        crystal(mesh, wall, inward, rng.uniform(0.22, 0.48), rng.uniform(0.035, 0.07),
                palette[rng.randrange(len(palette))])
    return mesh


def pack(meshes):
    binary, views, accessors, primitives = bytearray(), [], [], []

    def add(data, fmt, count, kind, target, minmax=None):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        for item in data:
            binary.extend(struct.pack(fmt, *item))
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset,
                      "target": target})
        accessor = {"bufferView": len(views) - 1, "componentType": 5126, "count": count,
                    "type": kind}
        if minmax:
            accessor.update(minmax)
        accessors.append(accessor)
        return len(accessors) - 1

    for material, mesh in enumerate(meshes):
        count = len(mesh.positions)
        bounds = {"min": [min(p[i] for p in mesh.positions) for i in range(3)],
                  "max": [max(p[i] for p in mesh.positions) for i in range(3)]}
        primitives.append({"attributes": {
            "POSITION": add(mesh.positions, "<3f", count, "VEC3", 34962, bounds),
            "NORMAL": add(mesh.normals, "<3f", count, "VEC3", 34962),
            "COLOR_0": add(mesh.colors, "<4f", count, "VEC4", 34962),
        }, "material": material, "mode": 4})
    while len(binary) % 4:
        binary.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "geode/tools/make_geode_crystal_glb.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "Geode crystal"}],
        "meshes": [{"name": "Geode", "primitives": primitives}],
        "materials": [
            {"name": "River stone shell", "doubleSided": True, "pbrMetallicRoughness": {
                "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.88}},
            {"name": "Amethyst quartz", "alphaMode": "BLEND", "doubleSided": True,
             "emissiveFactor": [0.10, 0.05, 0.16], "pbrMetallicRoughness": {
                 "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.12}},
        ],
        "accessors": accessors, "bufferViews": views,
        "buffers": [{"byteLength": len(binary)}],
    }
    payload = json.dumps(gltf, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    total = 12 + 8 + len(payload) + 8 + len(binary)
    return (struct.pack("<III", 0x46546C67, 2, total)
            + struct.pack("<II", len(payload), 0x4E4F534A) + payload
            + struct.pack("<II", len(binary), 0x004E4942) + bytes(binary))


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(pack([shell(), cluster()]))
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
