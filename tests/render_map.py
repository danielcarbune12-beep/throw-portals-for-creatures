"""Offline perspective renderer for the map exported by tests/lune/export_map.luau.
Flat-shaded, painter-sorted polygons — a layout/composition review aid, NOT Roblox rendering
(no materials, textures, shadows, fog, bloom or terrain smoothing; terrain = recorded fill shapes).
Usage: python tests/render_map.py            -> renders all named views to map_views/*.png
"""
import json, math, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

D = json.load(open("tests/lune/tmp/map.json", encoding="utf-8"))
TCOL = {k: tuple(v) for k, v in D["colors"].items()}
DEFAULT_T = {"Pavement": (0.72, 0.70, 0.66), "Cobblestone": (0.55, 0.53, 0.5), "LeafyGrass": (0.4, 0.62, 0.3), "Grass": (0.41, 0.75, 0.31), "Rock": (0.47, 0.49, 0.45), "Water": (0.25, 0.68, 0.85), "Slate": (0.3, 0.27, 0.42),
             "Basalt": (0.24, 0.18, 0.18), "Snow": (0.92, 0.96, 1.0), "Sand": (1.0, 0.7, 0.84), "Limestone": (0.3, 0.32, 0.45),
             "Ground": (0.16, 0.1, 0.22), "Salt": (1.0, 0.98, 0.92), "Glacier": (0.59, 0.86, 1.0), "CrackedLava": (1.0, 0.43, 0.12)}
LIGHT = np.array([-0.35, 0.85, 0.4]); LIGHT /= np.linalg.norm(LIGHT)

def box(size):
    sx, sy, sz = [v / 2 for v in size]
    v = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    return v, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]

def shape_geom(shape, size):
    sx, sy, sz = [v / 2 for v in size]
    if shape == "Wedge":
        return [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz), (-sx, sy, sz), (sx, sy, sz)], \
               [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]
    if shape == "Corner":
        return [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz), (sx, sy, -sz)], \
               [(0, 1, 2, 3), (1, 4, 2), (0, 4, 1), (2, 4, 3), (3, 4, 0)]
    if shape in ("Ball", "Cylinder"):
        n = 10
        if shape == "Cylinder":
            v = []
            for x in (-sx, sx):
                for k in range(n):
                    a = k / n * 2 * math.pi
                    v.append((x, math.cos(a) * sy, math.sin(a) * sz))
            f = [tuple(range(n)), tuple(range(n, 2 * n))] + [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
            return v, f
        rings = 6
        v = [(0, sy, 0)]
        for i in range(1, rings):
            ph = i / rings * math.pi
            for k in range(n):
                th = k / n * 2 * math.pi
                v.append((math.sin(ph) * math.cos(th) * sx, math.cos(ph) * sy, math.sin(ph) * math.sin(th) * sz))
        v.append((0, -sy, 0))
        f = []
        for k in range(n): f.append((0, 1 + k, 1 + (k + 1) % n))
        for i in range(rings - 2):
            a, b = 1 + i * n, 1 + (i + 1) * n
            for k in range(n): f.append((a + k, a + (k + 1) % n, b + (k + 1) % n, b + k))
        last = len(v) - 1; base = 1 + (rings - 2) * n
        for k in range(n): f.append((last, base + (k + 1) % n, base + k))
        return v, f
    return box(size)

def world_faces():
    out = []  # (verts Nx3, rgb, alpha, neon)
    for p in D["parts"]:
        v, f = shape_geom(p["shape"], p["size"])
        c = p["cf"]; pos = np.array(c[:3]); R = np.array(c[3:]).reshape(3, 3)
        V = np.array(v) @ R.T + pos
        for face in f:
            out.append((V[list(face)], np.array(p["color"]), max(0.25, 1 - p["tr"]), p["neon"]))
    for t in D["fills"]:
        if t["mat"] == "Air": continue
        col = np.array(TCOL.get(t["mat"], DEFAULT_T.get(t["mat"], (0.5, 0.5, 0.5))))
        if t["kind"] == "block":
            c = t["cf"]; pos = np.array(c[:3]); R = np.array(c[3:]).reshape(3, 3)
            sx, sy, sz = [q / 2 for q in t["size"]]
            nx, nz = max(1, int(sx * 2 // 24)), max(1, int(sz * 2 // 24))
            for i in range(nx):
                for j in range(nz):
                    x0, x1 = -sx + 2 * sx * i / nx, -sx + 2 * sx * (i + 1) / nx
                    z0, z1 = -sz + 2 * sz * j / nz, -sz + 2 * sz * (j + 1) / nz
                    top = np.array([(x0, sy, z0), (x1, sy, z0), (x1, sy, z1), (x0, sy, z1)]) @ R.T + pos
                    out.append((top, col, 1.0, False))
            continue
        elif t["kind"] == "cyl":
            r, h = t["r"], t["h"]; n = 24
            top = np.array([(math.cos(k / n * 2 * math.pi) * r, h / 2, math.sin(k / n * 2 * math.pi) * r) for k in range(n)]) + np.array(t["c"])
            out.append((top, col, 1.0, False)); continue
        else:
            r = t["r"]; v, f = shape_geom("Ball", (2 * r, 2 * r, 2 * r)); V = np.array(v) + np.array(t["c"])
        for face in f:
            out.append((V[list(face)], col, 1.0, False))
    return out

FACES = world_faces()
ALLV = [f[0] for f in FACES]
CENT = np.array([fv.mean(axis=0) for fv in ALLV])

def render(name, eye, target, fov=70, maxdist=min(1100, 1e9), title=""):
    eye, target = np.array(eye, float), np.array(target, float)
    fwd = target - eye; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = 1 / math.tan(math.radians(fov / 2))
    rel = CENT - eye
    depth = rel @ fwd
    sel = np.where((depth > 1) & (depth < maxdist))[0]
    polys, cols, depths = [], [], []
    for i in sel:
        V, col, alpha, neon = FACES[i]
        rv = V - eye
        cam = np.stack([rv @ right, rv @ up, rv @ fwd], axis=1)
        if (cam[:, 2] < 0.5).any():  # Sutherland-Hodgman clip against the near plane
            out = []
            for k in range(len(cam)):
                a, b2 = cam[k], cam[(k + 1) % len(cam)]
                ina, inb = a[2] >= 0.5, b2[2] >= 0.5
                if ina: out.append(a)
                if ina != inb:
                    tt = (0.5 - a[2]) / (b2[2] - a[2]); out.append(a + (b2 - a) * tt)
            if len(out) < 3: continue
            cam = np.array(out)
        z = cam[:, 2]
        x = cam[:, 0] / z * f; y = cam[:, 1] / z * f
        if (abs(x) > 2.5).all() or (abs(y) > 2.5).all(): continue
        n = np.cross(V[1] - V[0], V[2] - V[0]); nn = np.linalg.norm(n)
        if nn < 1e-9: continue
        n /= nn
        if np.dot(n, -rv.mean(axis=0)) < 0: n = -n  # face toward camera for shading
        shade = 1.0 if neon else 0.5 + 0.5 * max(0, np.dot(n, LIGHT))
        fog = min(1, depth[i] / maxdist) ** 1.6 * 0.55
        rgb = np.clip(col * shade, 0, 1) * (1 - fog) + np.array([0.78, 0.86, 0.95]) * fog
        polys.append(np.stack([x, y], axis=1)); cols.append((*rgb, alpha)); depths.append(depth[i])
    order = np.argsort(depths)[::-1]
    fig = plt.figure(figsize=(12, 6.75), dpi=110)
    ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(-1.78, 1.78); ax.set_ylim(-1, 1); ax.axis("off")
    ax.set_facecolor((0.75, 0.85, 0.96)); fig.patch.set_facecolor((0.75, 0.85, 0.96))
    ax.add_collection(PolyCollection([polys[i] for i in order], facecolors=[cols[i] for i in order], edgecolors=(0, 0, 0, 0.06), linewidths=0.2))
    ax.text(-1.74, 0.92, title, fontsize=15, color="white", weight="bold", bbox=dict(facecolor=(0.2, 0.12, 0.35, 0.75), edgecolor="none", pad=6))
    os.makedirs("map_views", exist_ok=True)
    fig.savefig(f"map_views/{name}.png"); plt.close(fig)
    print("saved", name, len(polys))

ZB = {"Forest": (0, 150), "Volcano": (150, 350), "Frozen": (350, 600), "Crystal": (600, 900), "Candy": (900, 1300),
      "Space": (1300, 1800), "Shadow": (1800, 2400), "Heaven": (2400, 3200)}
VIEWS = {
    "00_hub": ((0, 110, -560), (0, 0, -170), "Hub — 8 bases, street, fountain, Launch Hall"),
    "00b_launch_hall": ((0, 14, -70), (0, 10, 60), "Launch Hall — looking down the lane"),
    "00c_spawn_player": ((-4, 5.5, -72), (2, 6, 0), "Spawn — player eye height, facing the Launch Hall"),
    "00d_plaza": ((-30, 9, -300), (0, 4, -335), "Fountain plaza — player height"),
    "00e_street": ((18, 7, -100), (-6, 4, -260), "Main street — base approaches and lamps"),
}
for i, (zid, (a, b)) in enumerate(ZB.items(), 1):
    VIEWS[f"{i:02d}_{zid.lower()}"] = ((22, 24, a + 16), (-10, 12, a + (b - a) * 0.7), f"{zid} [{a}, {b}) — flight / reveal view")
which = [] if sys.argv[1:] == ["lm"] else (sys.argv[1:] or list(VIEWS))
for k in which:
    e, t, title = VIEWS[k]
    zid = k.split("_", 1)[1].capitalize() if k[:2] not in ("00",) else None
    md = (ZB[zid][1] - ZB[zid][0]) * 1.1 + 120 if zid in ZB else 900
    render(k, e, t, title=title, maxdist=md)

# landmark close-ups from the reveal corridor (python tests/render_map.py lm)
LM = {
    "lm1_forest_oak": ((14, 20, 22), (-72, 30, 95)), "lm2_volcano": ((18, 26, 165), (-100, 50, 250)),
    "lm3_frozen_citadel": ((-12, 20, 405), (80, 28, 475)), "lm4_crystal_geode": ((12, 18, 680), (-84, 22, 750)),
    "lm5_candy_palace": ((-12, 20, 1030), (84, 24, 1100)), "lm6_space_observatory": ((12, 20, 1500), (-80, 26, 1580)),
    "lm7_shadow_cathedral": ((12, 22, 2015), (-80, 30, 2090)), "lm8_heaven_sanctuary": ((12, 22, 2775), (-82, 26, 2860)),
}
if sys.argv[1:] == ["lm"]:
    for k, (e, t) in LM.items():
        render(k, e, t, title=k.split("_", 1)[1].replace("_", " ").title() + " — landmark from the reveal corridor", maxdist=420)
