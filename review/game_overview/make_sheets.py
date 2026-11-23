"""Arrange actual Studio screenshots for visual review; originals stay untouched."""
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
SHOTS = json.loads((ROOT / "captures.json").read_text(encoding="utf-8"))
BY_ID = {s["id"]: s for s in SHOTS}
GROUPS = [
    ("A_Hub_And_Base", "Hub and player base", ["01", "02", "03", "04", "05", "06", "07", "21"]),
    ("B_All_Eight_Biomes", "All eight biomes", ["08", "09", "10", "11", "12", "13", "14", "15"]),
    ("C_UI_And_Portals", "Interface and portal launch", ["16", "17", "18", "19", "20", "22", "23", "24"]),
]

def font(size, bold=False):
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size)

for name, title, ids in GROUPS:
    width, pad, gap, header, label, image_h = 1920, 28, 24, 120, 62, 530
    cell_w = (width - pad * 2 - gap) // 2
    row_h = image_h + label
    sheet = Image.new("RGB", (width, header + 4 * row_h + 3 * gap + pad), "#F1F3F5")
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 20), title, font=font(38, True), fill="#1B232C")
    draw.text((pad, 72), "Actual game screenshots | Tell me the image numbers you want changed", font=font(24), fill="#525D69")
    for index, shot_id in enumerate(ids):
        shot = BY_ID[shot_id]
        x = pad + (index % 2) * (cell_w + gap)
        y = header + (index // 2) * (row_h + gap)
        draw.rectangle((x, y, x + cell_w, y + row_h), fill="white")
        with Image.open(ROOT / "originals" / shot["file"]) as original:
            original.verify()
        with Image.open(ROOT / "originals" / shot["file"]) as original:
            thumb = ImageOps.contain(original.convert("RGB"), (cell_w, image_h), Image.Resampling.LANCZOS)
            sheet.paste(thumb, (x + (cell_w - thumb.width) // 2, y + (image_h - thumb.height) // 2))
        draw.text((x + 14, y + image_h + 10), shot_id + "  " + shot["title"], font=font(28, True), fill="#1B232C")
    sheet.save(ROOT / (name + ".jpg"), quality=94, subsampling=0)

parts = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Game screenshot review</title>',
    '<style>body{font-family:Segoe UI,Arial,sans-serif;background:#f1f3f5;color:#1b232c;margin:24px}h1{font-size:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,480px),1fr));gap:20px}figure{margin:0;background:white;padding:12px}img{width:100%;height:auto}figcaption{font-size:18px;font-weight:600;padding:10px 0}a{color:inherit}</style>',
    '<h1>Game screenshot review</h1><p>Click an image for its full-size original. Tell me its number and what you want changed.</p><p>UI shots show a fresh temporary profile. The gameplay and map were not redesigned for these screenshots.</p><main>']
for shot in SHOTS:
    path = "originals/" + shot["file"]
    caption = html.escape(shot["id"] + " - " + shot["title"])
    parts.append(f'<figure><a href="{path}"><img loading="lazy" src="{path}" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>')
parts.append("</main></html>")
(ROOT / "index.html").write_text("\n".join(parts), encoding="utf-8")
print("Created three numbered sheets and a full-size screenshot gallery.")
