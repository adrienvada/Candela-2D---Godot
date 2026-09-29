#!/usr/bin/env python3
"""L'intro v2 — le titre CANDELA monté (2026-09-29, version choisie par Adrien : Flow).

Le clip Veo (Flow, image de début = le logo éteint, image de fin = le logo
incandescent) montre une étincelle qui part de la gauche et enflamme chaque
lettre. Ce script le cale sur quatre mesures de la musique pour que
l'embrasement tombe sur le troisième temps, et y ajoute deux images d'éclair,
une secousse de six images et un fondu au noir final. Le son (impact grave,
allumage du tube, musique d'intro) est posé par `tools/monter_intro.py`.

Lit `assets/sources/intro/clips/f_titre.mp4`, écrit
`assets/sources/intro/titre/titre.mp4`.

    python3 tools/intro_titre.py
"""
import os
import random
import subprocess

from PIL import Image, ImageChops, ImageEnhance

DEPOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = f"{DEPOT}/assets/sources/intro"
W, H, FPS = 1920, 1080, 30
TEMPS = 60 / 170
DUREE = 4 * 4 * TEMPS          # quatre mesures : 5,65 s
IMPACT = 2 * TEMPS             # l'embrasement sur le troisième temps de la première mesure
CLIP, DEBUT, FIN, ALLUMAGE = f"{SOURCES}/clips/f_titre.mp4", 0.6, 8.0, 1.55


def monter():
    dossier = f"{SOURCES}/_titre"
    subprocess.run(["rm", "-rf", dossier], check=True)
    os.makedirs(dossier)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(DEBUT), "-t", str(FIN - DEBUT), "-i", CLIP,
                    "-vf", f"fps=120,scale={W}:{H}:flags=lanczos", f"{dossier}/%05d.png"], check=True)
    src = sorted(os.listdir(dossier))
    n = round(DUREE * FPS)
    os.makedirs(f"{SOURCES}/titre", exist_ok=True)
    sortie = f"{SOURCES}/titre/titre.mp4"
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-crf", "17", "-pix_fmt", "yuv420p", sortie],
                          stdin=subprocess.PIPE)
    rnd = random.Random(5)
    i_impact = round(IMPACT * FPS)
    for i in range(n):
        t = i / FPS
        # [DEBUT, ALLUMAGE] joue sur [0, IMPACT], [ALLUMAGE, FIN] sur [IMPACT, DUREE]
        s = (DEBUT + (ALLUMAGE - DEBUT) * t / IMPACT) if t < IMPACT else \
            (ALLUMAGE + (FIN - ALLUMAGE) * (t - IMPACT) / (DUREE - IMPACT))
        im = Image.open(f"{dossier}/{src[min(len(src) - 1, max(0, round((s - DEBUT) * 120)))]}").convert("RGB")
        d = i - i_impact
        if d in (0, 1):                                        # l'éclair : deux images brûlées
            im = Image.blend(im, Image.new("RGB", (W, H), (255, 244, 220)), 0.75 if d == 0 else 0.35)
        if 0 <= d < 6:                                         # la secousse, qui s'amortit
            amp = (6 - d) * 5
            im = ImageChops.offset(im, rnd.randint(-amp, amp), rnd.randint(-amp, amp))
        if i >= n - 8:                                         # fondu au noir des huit dernières images
            im = ImageEnhance.Brightness(im).enhance((n - i) / 8)
        ff.stdin.write(im.tobytes())
    ff.stdin.close()
    ff.wait()
    subprocess.run(["rm", "-rf", dossier], check=True)
    print(f"titre : {n} images ({DUREE:.2f} s) → {sortie}")


if __name__ == "__main__":
    monter()
