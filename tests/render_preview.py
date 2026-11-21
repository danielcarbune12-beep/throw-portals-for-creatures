"""Offline preview renderer for creature geometry exported by tests/lune/export.luau.
Draws every visible piece (box / wedge / cylinder / sphere-as-octahedron-box) with flat shading in a
three-quarter view. A design-review aid only: it is NOT Roblox rendering (no materials, lighting or bloom).
Usage:  python -I tests/render_preview.py out.png [columns]
"""
import json, sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

data = json.load(open("tests/lune/tmp/export.json", encoding="utf-8"))
out = sys.argv[1] if len(sys.argv) > 1 else "preview.png"
cols = int(sys.argv[2]) if len(sys.argv) > 2 else min(4, len(data))
rows = math.ceil(len(data) / cols)
LIGHT = np.array([-0.4, 0.8, -0.45]); LIGHT /= np.linalg.norm(LIGHT)

def faces_for(p):
    sx, sy, sz = [v / 2 for v in p["size"]]
    m = p["mesh"]
    if m == "Wedge":  # tall face at +Z, slope down to -Z
        v = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz), (-sx, sy, sz), (sx, sy, sz)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]
    elif m == "Cylinder":  # axis X, octagonal prism
        v = []
        for x in (-sx, sx):
            for k in range(8):
                a = k / 8 * 2 * math.pi
                v.append((x, math.cos(a) * sy, math.sin(a) * sz))
        f = [tuple(range(8)), tuple(range(8, 16))] + [(k, (k + 1) % 8, 8 + (k + 1) % 8, 8 + k) for k in range(8)]
    elif m == "Sphere":  # rounded-ish: octahedral-cut box
        v = [(sx, 0, 0), (-sx, 0, 0), (0, sy, 0), (0, -sy, 0), (0, 0, sz), (0, 0, -sz)]
        f = [(0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2), (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5)]
    else:  # Brick
        v = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    c = p["cf"]
    pos = np.array(c[:3]); R = np.array(c[3:]).reshape(3, 3)
    V = np.array(v) @ R.T + pos
    return [V[list(face)] for face in f]

fig = plt.figure(figsize=(cols * 4, rows * 4.4), facecolor="white")
for i, cre in enumerate(data):
    ax = fig.add_subplot(rows, cols, i + 1, projection="3d")
    polys, colors = [], []
    allpts = []
    for p in cre["parts"]:
        for face in faces_for(p):
            if len(face) < 3: continue
            n = np.cross(face[1] - face[0], face[2] - face[0])
            nn = np.linalg.norm(n)
            shade = 0.55 + 0.45 * abs(np.dot(n / nn, LIGHT)) if nn > 1e-9 else 0.8
            col = np.array(p["color"])
            if p["neon"]: shade = 1.05
            rgb = np.clip(col * shade, 0, 1)
            polys.append(face[:, [0, 2, 1]] * np.array([1, -1, 1]))  # Roblox Y-up -> plot Z-up, front (-Z) toward viewer
            colors.append((*rgb, max(0.15, 1 - p["tr"])))
            allpts.append(face)
    pc = Poly3DCollection(polys, facecolors=colors, edgecolors=(0, 0, 0, 0.08), linewidths=0.3)
    ax.add_collection3d(pc)
    P = np.vstack(allpts)[:, [0, 2, 1]] * np.array([1, -1, 1])
    mn, mx = P.min(axis=0), P.max(axis=0)
    ctr = (mn + mx) / 2; r = (mx - mn).max() / 2 * 1.05
    ax.set_xlim(ctr[0] - r, ctr[0] + r); ax.set_ylim(ctr[1] - r, ctr[1] + r); ax.set_zlim(ctr[2] - r, ctr[2] + r)
    ax.view_init(elev=14, azim=118)
    ax.set_box_aspect((1, 1, 1)); ax.axis("off")
    ax.set_title(f"{cre['name']}\n{cre['rarity']}  ({len(cre['parts'])} parts)", fontsize=10)
plt.tight_layout()
plt.savefig(out, dpi=90)
print("saved", out)
