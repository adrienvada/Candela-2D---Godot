"""Retire un fond vert d'incrustation (#00B140) et rend une icône carrée de
128 px, recadrée sur l'objet.

Alpha tiré de la « verdeur » (g - max(r, b)) : un pixel franchement vert est
transparent, un pixel sans excès de vert est opaque, entre les deux un fondu.
Puis déversement : on retire au vert l'excès qui reste sur les bords, sans quoi
un liseré vert survit — le cousin exact du liseré blanc des titres.

Usage : python3 incruster.py source.png sortie.png"""
import sys
from PIL import Image

BAS, HAUT = 25, 90   # verdeur : en dessous opaque, au-dessus transparent
COTE = 128
MARGE = 6

src = Image.open(sys.argv[1]).convert("RGB")
W, H = src.size
sp = src.load()
out = Image.new("RGBA", (W, H))
op = out.load()
for y in range(H):
    for x in range(W):
        r, g, b = sp[x, y]
        v = g - max(r, b)
        if v <= BAS:
            a = 255
        elif v >= HAUT:
            a = 0
        else:
            a = int(255 * (HAUT - v) / (HAUT - BAS))
        if a > 0:
            g = min(g, max(r, b))  # déversement
            op[x, y] = (r, g, b, a)
        else:
            op[x, y] = (0, 0, 0, 0)

bb = out.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
if bb is None:
    sys.exit("image vide après incrustation : " + sys.argv[1])
obj = out.crop(bb)
w, h = obj.size
c = max(w, h)
toile = Image.new("RGBA", (c, c), (0, 0, 0, 0))
toile.paste(obj, ((c - w) // 2, (c - h) // 2))
final = Image.new("RGBA", (COTE, COTE), (0, 0, 0, 0))
t = COTE - 2 * MARGE
final.alpha_composite(toile.resize((t, t), Image.LANCZOS), (MARGE, MARGE))
final.save(sys.argv[2], optimize=True)
print("écrit", sys.argv[2], "objet", (w, h))
