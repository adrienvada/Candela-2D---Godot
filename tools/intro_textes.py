#!/usr/bin/env python3
"""L'intro v2 — les quatre textes animés (2026-09-29).

Chaque texte est une petite scène de lumière, dans la logique du jeu : on ne lit
que ce qui est éclairé.

- « VOIR » : un pochoir bombé sur un mur, qui n'existe que là où passe la torche ;
- « SANS ÊTRE VU. » : les lettres s'allument en deux ratés, puis meurent une à une ;
- « TUER » : une image blanche où le mot est brûlé en noir, l'éclair, la rémanence rouge ;
- « SANS ÊTRE TUÉ. » : gravé dans le sol, lu à la lumière rasante d'une torche qui se pose.

Fabriqués image par image (Pillow seul : ce poste n'a pas numpy), zéro crédit.
Écrit dans `assets/sources/intro/textes/`, que `tools/monter_intro.py` lit.
Les plaques (mur, sol, image du tir) sont des images Gemini recadrées, dans
`assets/sources/intro/plaques/` (hors dépôt, voir son `.gitignore`).

    python3 tools/intro_textes.py [voir|sans_etre_vu|tuer|sans_etre_tue|tout]
"""
import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

DEPOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = f"{DEPOT}/assets/sources/intro"
POLICE = f"{DEPOT}/assets/fonts/BigShouldersDisplay.ttf"
W, H, FPS = 1920, 1080, 30
MESURE = 4 * 60 / 170
PAPIER = (233, 226, 211)
AMBRE = (245, 176, 61)
NOIR = Image.new("RGB", (W, H), (0, 0, 0))


# ── Outils ───────────────────────────────────────────────────────────────────
def police(taille, graisse=800):
    f = ImageFont.truetype(POLICE, taille)
    try:
        f.set_variation_by_axes([graisse])
    except Exception:
        pass
    return f


def lettres(texte, taille, approche=0.06, graisse=800):
    """Un masque L par lettre du texte centré, et la hauteur des capitales — pour les animer une à une."""
    f = police(taille, graisse)
    avances = [f.getlength(c) + taille * approche for c in texte]
    largeur = sum(avances) - taille * approche
    bb = f.getbbox("ÉÈÊTVAG")
    x = (W - largeur) / 2
    y = (H - (bb[3] - bb[1])) / 2 - bb[1]
    masques = []
    for c, a in zip(texte, avances):
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).text((x, y), c, font=f, fill=255)
        masques.append(m)
        x += a
    return masques, (y + bb[1], y + bb[3])


def union(masques):
    out = Image.new("L", (W, H), 0)
    for m in masques:
        out = ImageChops.lighter(out, m)
    return out


def spot(cx, cy, rx, ry, dur=2.2):
    """Tache de torche : cœur chaud, bord doux (0-255)."""
    g = Image.radial_gradient("L").resize((max(2, int(2 * rx)), max(2, int(2 * ry))), Image.BILINEAR)
    g = ImageOps.invert(g).point(lambda v: int(255 * min(1.0, (v / 255) ** dur * 1.6)))
    out = Image.new("L", (W, H), 0)
    out.paste(g, (int(cx - rx), int(cy - ry)))
    return out


def eclairer(image, lumiere, teinte=0.55):
    """image × lumière, teintée ambre (la couleur de la torche de J1)."""
    lum = Image.merge("RGB", [lumiere.point(lambda v, k=k: int(v * (1 - teinte + teinte * k / 255))) for k in AMBRE])
    return ImageChops.multiply(image, lum)


def grain(im, force=10):
    n = Image.effect_noise((W, H), 40).convert("RGB")
    return ImageChops.add(im, n.point(lambda v: max(0, v - 128) * force // 40), scale=1.0)


def halo(im, rayon=22, force=0.7):
    return ImageChops.add(im, im.filter(ImageFilter.GaussianBlur(rayon)).point(lambda v: int(v * force)))


def poussiere(lumiere, t, n=160, graine=3):
    """Grains de poussière visibles seulement dans la lumière."""
    rnd = random.Random(graine)
    calque = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(calque)
    for _ in range(n):
        x = (rnd.uniform(0, W) + t * rnd.uniform(-40, 40)) % W
        y = (rnd.uniform(0, H) + t * rnd.uniform(-25, 10)) % H
        r = rnd.choice([1, 1, 2, 2, 3])
        d.ellipse((x - r, y - r, x + r, y + r), fill=rnd.randint(90, 220))
    return ImageChops.multiply(calque, lumiere)


def lisse(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def plaque(nom):
    return ImageOps.fit(Image.open(f"{SOURCES}/plaques/{nom}.png").convert("RGB"), (W, H), Image.LANCZOS)


def ecrire(nom, images):
    os.makedirs(f"{SOURCES}/textes", exist_ok=True)
    sortie = f"{SOURCES}/textes/{nom}.mp4"
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-crf", "17", "-pix_fmt", "yuv420p", sortie],
                          stdin=subprocess.PIPE)
    for im in images:
        ff.stdin.write(im.tobytes())
    ff.stdin.close()
    ff.wait()
    print(f"{nom} : {len(images)} images ({len(images) / FPS:.2f} s) → {sortie}")


# ── « VOIR » : un pochoir sur le mur, que le faisceau balaie ──────────────────
def voir(mesures=1):
    n = round(mesures * MESURE * FPS)
    # la plaque, sans sa propre lumière, un peu assombrie pour que la peinture ressorte
    mur = ImageOps.autocontrast(plaque("mur").convert("L"), cutoff=1).point(lambda v: int(v * 0.62)).convert("RGB")
    masques, haut = lettres("VOIR", 470, approche=0.10)
    mot = union(masques)
    h = haut[1] - haut[0]
    ImageDraw.Draw(mot).rectangle((0, haut[0] + h * 0.47, W, haut[0] + h * 0.52), fill=0)   # le pont du pochoir
    texture = Image.effect_noise((W, H), 70).point(lambda v: 170 + v * 85 // 255)
    peinture = ImageChops.multiply(mot.filter(ImageFilter.GaussianBlur(1.6)), texture)
    nuage = mot.filter(ImageFilter.GaussianBlur(14)).point(lambda v: v * 38 // 255)          # le nuage de la bombe
    peinture = ImageChops.lighter(peinture, nuage)
    coulures = Image.new("L", (W, H), 0)
    rnd = random.Random(4)
    bb = mot.getbbox()
    for _ in range(12):
        x = rnd.uniform(bb[0], bb[2])
        if mot.getpixel((int(x), int(haut[1] - 8))) > 128:
            ImageDraw.Draw(coulures).line((x, haut[1] - 6, x, haut[1] + rnd.uniform(25, 110)),
                                          fill=210, width=rnd.choice([3, 4, 5]))
    peinture = ImageChops.lighter(peinture, coulures.filter(ImageFilter.GaussianBlur(1)))
    mur_peint = Image.composite(Image.new("RGB", (W, H), (242, 236, 222)), mur, peinture)
    images = []
    for i in range(n):
        t = i / (n - 1)
        # le faisceau entre par la gauche, ralentit sur le mot, repart à droite
        u = t + 0.18 * math.sin(t * math.pi) * (0.5 - t) * 2
        lum = spot(-0.25 * W + u * 1.5 * W, H * 0.52 + 30 * math.sin(t * 5), W * 0.30, H * 0.46)
        im = eclairer(mur_peint, lum)
        im = ImageChops.add(im, Image.merge("RGB", [poussiere(lum, t * 3).point(lambda v, k=k: v * k // 255)
                                                    for k in AMBRE]))
        images.append(grain(halo(im, 14, 0.35)))
    ecrire("voir", images)


# ── « SANS ÊTRE VU. » : les lettres s'allument, puis meurent une à une ───────
def sans_etre_vu(mesures=1):
    n = round(mesures * MESURE * FPS)
    texte = "SANS ÊTRE VU."
    masques, _ = lettres(texte, 250, approche=0.13, graisse=750)
    rnd = random.Random(7)
    ordre = [k for k, c in enumerate(texte) if c != " "]
    morts = {k: 0.55 + 0.38 * j / len(ordre) + rnd.uniform(-0.03, 0.03) for j, k in enumerate(ordre)}
    images = []
    for i in range(n):
        t = i / (n - 1)
        calque = Image.new("L", (W, H), 0)
        for k, m in enumerate(masques):
            if texte[k] == " ":
                continue
            allume = 1.0 if i > 4 else (0.0 if i in (0, 2) else 0.7)                 # l'allumage : deux ratés
            if t > morts[k]:
                dt = (t - morts[k]) * n
                allume = 0.0 if dt > 3 else (0.9 if int(dt) % 2 == 0 else 0.15)     # la mort : un sursaut
            if allume > 0:
                calque = ImageChops.lighter(calque, m.point(lambda v, a=allume: int(v * a)))
        im = halo(Image.merge("RGB", [calque.point(lambda v, k=k: v * k // 255) for k in PAPIER]), 28, 0.9)
        z = 1.0 + 0.035 * t
        im = im.resize((int(W * z), int(H * z)), Image.BICUBIC).crop(
            (int((W * z - W) / 2), int((H * z - H) / 2), int((W * z - W) / 2) + W, int((H * z - H) / 2) + H))
        images.append(grain(im))
    ecrire("sans_etre_vu", images)


# ── « TUER » : gravé dans l'éclair du tir ────────────────────────────────────
def tuer(mesures=1):
    n = round(mesures * MESURE * FPS)
    flash = plaque("flash")
    masques, _ = lettres("TUER", 560, approche=0.08, graisse=900)
    mot = union(masques)
    images = []
    rnd = random.Random(2)
    for i in range(n):
        dx, dy = (rnd.randint(-26, 26), rnd.randint(-16, 16)) if i < 6 else (0, 0)
        if i == 0:                                                           # le blanc brûlé, le mot en noir
            im = Image.new("RGB", (W, H), (255, 250, 236))
            im.paste((10, 8, 6), (0, 0), mot)
        elif i in (1, 2):
            im = ImageChops.add(flash, Image.merge("RGB", [mot.point(lambda v, k=k: v * k // 300) for k in PAPIER]))
        elif i == 3:
            im = Image.blend(NOIR, flash, 0.3)
        else:                                                                # la rémanence, sur la rétine
            a = max(0.0, 1 - (i - 4) / (n * 0.7))
            rem = mot.filter(ImageFilter.GaussianBlur(3 + (i - 4) * 0.6))
            im = Image.merge("RGB", [rem.point(lambda v, k=k, a=a: int(v * a * k / 255)) for k in (150, 22, 12)])
        images.append(grain(ImageChops.offset(im, dx, dy)))
    ecrire("tuer", images)


# ── « SANS ÊTRE TUÉ. » : creusé dans le sol, lu à la lumière rasante ─────────
def sans_etre_tue(mesures=2):
    n = round(mesures * MESURE * FPS)
    sol = ImageOps.autocontrast(plaque("sol").convert("L"), cutoff=1).convert("RGB")
    masques, _ = lettres("SANS ÊTRE TUÉ.", 200, approche=0.12, graisse=800)
    mot = union(masques).filter(ImageFilter.GaussianBlur(1.2))
    grave = Image.composite(ImageChops.multiply(sol, Image.new("RGB", (W, H), (45, 40, 36))), sol, mot)  # le creux
    ombre = ImageChops.subtract(mot, ImageChops.offset(mot, 10, 6))      # l'arête côté lumière reste dans l'ombre
    arete = ImageChops.subtract(mot, ImageChops.offset(mot, -7, -4))     # l'arête opposée prend la lumière
    grave = ImageChops.subtract(grave, Image.merge("RGB", [ombre] * 3))
    grave = ImageChops.add(grave, Image.merge("RGB", [arete.point(lambda v: int(v * 0.8))] * 3))
    images = []
    for i in range(n):
        t = i / (n - 1)
        # la torche au sol finit de rouler : sa lumière oscille, s'amortit, se pose
        ang = 0.5 * math.exp(-4 * t) * math.cos(t * 18)
        lum = spot(-W * 0.15 + W * 0.2 * ang, H * 0.5 + 160 * ang, W * 1.15, H * 0.5, dur=1.2)
        a = lisse(t / 0.12)
        im = eclairer(grave, lum.point(lambda v, a=a: int(v * a)), teinte=0.7)
        images.append(grain(halo(im, 10, 0.25)))
    ecrire("sans_etre_tue", images)


if __name__ == "__main__":
    quoi = sys.argv[1] if len(sys.argv) > 1 else "tout"
    for nom, f in (("voir", voir), ("sans_etre_vu", sans_etre_vu), ("tuer", tuer), ("sans_etre_tue", sans_etre_tue)):
        if quoi in (nom, "tout"):
            f()
