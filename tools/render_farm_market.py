"""Render exported production stall geometry; this is not a Roblox screenshot."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import numpy as np


def render(source, output):
    stalls = json.loads(Path(source).read_text(encoding="utf-8"))
    fig = plt.figure(figsize=(12, 7), facecolor="white")
    light = np.array([0.3, -0.5, 0.8])
    light /= np.linalg.norm(light)
    for index, stall in enumerate(stalls):
        ax = fig.add_subplot(1, 2, index + 1, projection="3d")
        faces, colors = [], []
        for shape in stall["shapes"]:
            cf = shape["cf"]
            rotation = np.array(cf[3:]).reshape(3, 3)
            position, half = np.array(cf[:3]), np.array(shape["size"]) / 2
            for axis in range(3):
                other = [i for i in range(3) if i != axis]
                for sign in (-1, 1):
                    points = []
                    for a, b in ((-1, -1), (-1, 1), (1, 1), (1, -1)):
                        p = np.zeros(3)
                        p[axis], p[other[0]], p[other[1]] = sign, a, b
                        points.append(rotation @ (p * half) + position)
                    normal = rotation[:, axis] * sign
                    shade = 0.65 + 0.35 * max(0, normal @ light)
                    # Roblox uses Y-up. Swapping Y/Z also needs an X sign change
                    # to preserve handedness rather than mirror physical lettering.
                    p00, p01, p11, p10 = np.array(points)
                    step = 0.1 if shape.get("name") == "TradeSign" else 3
                    nu = max(1, int(np.ceil(np.linalg.norm(p10 - p00) / step)))
                    nv = max(1, int(np.ceil(np.linalg.norm(p01 - p00) / step)))
                    for u in range(nu):
                        for v in range(nv):
                            patch = [p00 + (p10 - p00) * x / nu + (p01 - p00) * y / nv
                                     for x, y in ((u, v), (u, v + 1), (u + 1, v + 1), (u + 1, v))]
                            plotted = np.array(patch)[:, [0, 2, 1]]
                            plotted[:, 0] *= -1
                            faces.append(plotted)
                            colors.append(np.clip(np.array(shape["color"]) * shade, 0, 1))
        ax.add_collection3d(Poly3DCollection(faces, facecolors=colors, edgecolors="none", zsort="average"))
        ax.set(xlim=(-6, 6), ylim=(-6, 4), zlim=(0, 9))
        ax.set_box_aspect((12, 10, 9))
        ax.set_proj_type("ortho")
        ax.view_init(elev=20, azim=-67)
        ax.set_axis_off()
        ax.set_title("BUY · Seeds & supplies" if stall["kind"] == "Buy" else "SELL · Harvest counter",
                     fontsize=17, fontfamily="serif", color="#2A211B", pad=0)
    fig.text(0.5, 0.93, "THE GREAT HALL MARKET", ha="center", fontsize=22, fontfamily="serif", color="#2A211B")
    fig.text(0.5, 0.08, "Production geometry preview · Roblox lighting and material textures are not shown",
             ha="center", fontsize=10, color="#665B4E")
    fig.subplots_adjust(left=0, right=1, top=0.86, bottom=0.1, wspace=0)
    fig.savefig(output, dpi=180, facecolor="white")
    plt.close(fig)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("output")
    args = parser.parse_args()
    render(args.source, args.output)
