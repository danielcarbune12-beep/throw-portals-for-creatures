"""Raster export of the repository-authored SVG cursor, no generated image dependency."""
from pathlib import Path
from PIL import Image, ImageDraw
S=8
im=Image.new('RGBA',(40*S,40*S))
d=ImageDraw.Draw(im)
def poly(points,fill,outline=None,width=1):
    pts=[(x*S,y*S) for x,y in points]
    d.polygon(pts,fill=fill)
    if outline:
        d.line(pts+[pts[0]],fill=outline,width=round(width*S),joint='curve')
shape=[(4,3),(4,30),(11,24),(17,36),(23,32),(17,21),(29,20)]
poly(shape,'#f4ead3','#202c31',3)
poly(shape,'#f4ead3','#c59b50',1.35)
poly([(6,7),(25,19),(15,19),(20,31),(18,32),(12,21),(6,26)],'#fffaf0')
poly([(4,3),(29,20),(17,21),(14,18)],'#dfb86b')
poly([(8,11),(15,16),(12,18)],'#579385')
im.resize((80,80),Image.Resampling.LANCZOS).save(Path(__file__).with_name('forged-cursor.png'))
