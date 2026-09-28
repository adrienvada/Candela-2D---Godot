#!/usr/bin/env python3
"""L'intro v2, récit A « Qui allume se montre » — le monteur (2026-09-28).

Refait, depuis `assets/sources/intro/` (hors dépôt, voir son `.gitignore`) :

- le film `assets/video/intro/intro_a.ogv` (Theora + Vorbis, le seul format
  vidéo que Godot lit), image ET son, tel qu'Adrien l'a validé ;
- les images de repli `assets/ui/intro/intro_a_pN.jpg`, que `intro_planches.gd`
  montre si le film manque.

Le découpage est celui de `intro_planches.gd` (`PLANS`) : dix plans coupés sur
les mesures de la musique du jeu (170 BPM, quatre temps : une mesure = 1,4118 s),
18 mesures, 25,41 s. **Les deux listes doivent rester d'accord**, et
`tools/test_intro_planches.gd` le vérifie en relisant ce fichier.

Chaque image est dessinée en PIL et poussée brute dans ffmpeg ; le son est un
mixage ffmpeg (adelay + amix) des fichiers du jeu, normalisé à −16 LUFS puis
limité.

Usage :
    python3 tools/monter_intro.py            # film + repli
    python3 tools/monter_intro.py --repere   # + plan et temps incrustés (pour relire)

Nécessite ffmpeg, ffmpeg2theora (`brew install ffmpeg2theora` ; l'ffmpeg de ce
poste ne sait pas encoder le Theora) et Pillow. ⚠️ Installer ffmpeg2theora a déjà
cassé l'ffmpeg du poste une fois (`libx265` introuvable) : `brew reinstall ffmpeg`.
"""
import os
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

DEPOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = f"{DEPOT}/assets/sources/intro"
AUDIO = f"{DEPOT}/assets/audio/"
FILM = f"{DEPOT}/assets/video/intro/intro_a.ogv"
REPLI = f"{DEPOT}/assets/ui/intro"
MAITRE = f"{SOURCES}/intro_a_maitre.mp4"
W, H, FPS = 1920, 1080, 30
TEMPS = 60 / 170
MESURE = 4 * TEMPS
REPERE = "--repere" in sys.argv

# Qualité Theora (0-10) et Vorbis (-1-10) : 6 et 4 tiennent le film sous 15 Mo.
QUALITE_VIDEO = 6
QUALITE_AUDIO = 4

NOIR = Image.new("RGB", (W, H), (0, 0, 0))
POLICE = f"{DEPOT}/assets/fonts/BigShouldersDisplay.ttf"
POLICE_REPERE = f"{DEPOT}/assets/fonts/Oxanium.ttf"


def lisse(t):
    return t * t * (3 - 2 * t)


def charger(chemin, boite=None):
    """Une image au format du film, avec 25 % de marge pour les mouvements de caméra."""
    im = Image.open(chemin).convert("RGB")
    if boite:
        im = im.crop(boite)
    im = ImageOps.fit(im, (W, H), Image.LANCZOS)
    return im.resize((int(W * 1.25), int(H * 1.25)), Image.LANCZOS)


def cadre(im, t, z0, z1, c0, c1):
    """Ken Burns : zoom z (1 = plein cadre) et centre c (fractions), interpolés sur t."""
    z = z0 + (z1 - z0) * t
    cx = c0[0] + (c1[0] - c0[0]) * t
    cy = c0[1] + (c1[1] - c0[1]) * t
    bw, bh = im.width / 1.25 / z, im.height / 1.25 / z
    x0 = min(max(cx * im.width - bw / 2, 0), im.width - bw)
    y0 = min(max(cy * im.height - bh / 2, 0), im.height - bh)
    return im.resize((W, H), Image.BICUBIC, box=(x0, y0, x0 + bw, y0 + bh))


def carton(texte, taille=150):
    """Le texte gravé : Big Shoulders Display, papier sur noir, halo ambre."""
    im = Image.new("RGB", (W, H), (0, 0, 0))
    f = ImageFont.truetype(POLICE, taille)
    try:
        f.set_variation_by_axes([800])
    except Exception:
        pass
    bb = ImageDraw.Draw(im).textbbox((0, 0), texte, font=f)
    x, y = (W - (bb[2] - bb[0])) / 2 - bb[0], (H - (bb[3] - bb[1])) / 2 - bb[1]
    halo = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(halo).text((x, y), texte, font=f, fill=(245, 176, 61))
    halo = halo.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.55))
    ImageDraw.Draw(im).text((x, y), texte, font=f, fill=(233, 226, 211))
    return ImageChops.add(im, halo)


# ── Les clips Flow : (fichier, début de la fenêtre utile, coupe éventuelle) ──
# p5 : 0,45 → 0,85 s retirés, Veo y dessine deux pistolets superposés.
CLIPS = {
    "p2": ("p2_faisceau.mp4", 0.0, None),
    "p3": ("p3_cache.mp4", 0.0, None),
    "p5": ("p5_arme.mp4", 0.0, (0.45, 0.85)),
    "p8": ("p8_torche.mp4", 0.0, None),
}


def clip(cle, duree, dossier):
    fichier, debut, coupe = CLIPS[cle]
    sortie = f"{dossier}/{cle}"
    os.makedirs(sortie, exist_ok=True)
    retire = coupe[1] - coupe[0] if coupe else 0.0
    filtre = f"fps={FPS},scale={W}:{H}:flags=lanczos"
    if coupe:
        filtre = f"select='not(between(t,{coupe[0]},{coupe[1]}))',setpts=N/FRAME_RATE/TB," + filtre
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(debut), "-t", f"{duree + retire + 0.2:.3f}",
                    "-i", f"{SOURCES}/clips/{fichier}", "-vf", filtre, f"{sortie}/%04d.png"], check=True)
    return [f"{sortie}/{n}" for n in sorted(os.listdir(sortie))]


def monter():
    tmp = f"{SOURCES}/_images"
    subprocess.run(["rm", "-rf", tmp], check=True)
    os.makedirs(tmp)

    jeu = charger(f"{SOURCES}/jeu/p4_retrodiffusion.png", boite=(470, 260, 1750, 980))
    flash = charger(f"{SOURCES}/cles/p6_flash.png")
    accueil = charger(f"{DEPOT}/assets/ui/ill_accueil.png")
    voir = carton("VOIR SANS ÊTRE VU.").resize((int(W * 1.25), int(H * 1.25)))
    logo = Image.open(f"{DEPOT}/assets/logos/wordmark.png").convert("RGBA")
    logo.thumbnail((int(W * 0.46), H))
    c2, c3 = clip("p2", 2 * MESURE, tmp), clip("p3", 2 * MESURE, tmp)
    c5, c8 = clip("p5", MESURE, tmp), clip("p8", 2 * MESURE, tmp)

    def image_de(images, i):
        return Image.open(images[min(i, len(images) - 1)]).convert("RGB")

    def p_noir(t, i, n):
        return NOIR

    def p_faisceau(t, i, n):  # le faisceau « s'ouvre » en 8 images
        return Image.blend(NOIR, image_de(c2, i), min(1.0, i / 8))

    def p_cache(t, i, n):
        return image_de(c3, i)

    def p_jeu(t, i, n):
        return cadre(jeu, lisse(t), 1.0, 1.08, (0.45, 0.5), (0.58, 0.52))

    def p_arme(t, i, n):
        return image_de(c5, i)

    def p_flash(t, i, n):  # trois images d'éclair (la première brûlée au blanc), une de rémanence, noir
        base = cadre(flash, 0, 1.02, 1.02, (0.5, 0.5), (0.5, 0.5))
        if i == 0:
            return Image.blend(base, Image.new("RGB", (W, H), (255, 250, 235)), 0.65)
        if i in (1, 2):
            return base
        return Image.blend(NOIR, base, 0.35) if i == 3 else NOIR

    def p_torche(t, i, n):
        return image_de(c8, i)

    def p_voir(t, i, n):
        im = cadre(voir, t, 1.0 + 0.04 * (1 - t), 1.0, (0.5, 0.5), (0.5, 0.5))
        return Image.blend(NOIR, im, min(1.0, i / 6))

    def p_logo(t, i, n):  # le tube s'allume en deux ratés ; dernière mesure : fondu sur l'accueil
        rates = {2: 0.5, 3: 0.0, 5: 0.8, 6: 0.2}
        k = 1.0 if i >= 8 else rates.get(i, 0.0 if i < 2 else 1.0)
        im = NOIR.copy()
        calque = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        calque.paste(logo, ((W - logo.width) // 2, (H - logo.height) // 2), logo)
        im.paste(calque.convert("RGB"), (0, 0), calque.getchannel("A").point(lambda v: int(v * k)))
        fin = n - int(MESURE * FPS)
        if i >= fin:
            im = Image.blend(im, cadre(accueil, 0, 1.0, 1.0, (0.5, 0.5), (0.5, 0.5)), lisse((i - fin) / max(1, n - fin)))
        return im

    # (mesures, nom, rendu, image de repli) — le même ordre que `PLANS` dans intro_planches.gd
    plans = [
        (2, "noir", p_noir, None),
        (2, "le faisceau", p_faisceau, "p2"),
        (2, "le caché", p_cache, "p3"),
        (2, "en jeu", p_jeu, "p4"),
        (1, "l'arme se lève", p_arme, "p5"),
        (1, "le flash", p_flash, "p6"),
        (1, "noir, une douille", p_noir, None),
        (2, "la torche roule", p_torche, "p8"),
        (2, "VOIR SANS ÊTRE VU.", p_voir, None),
        (3, "CANDELA", p_logo, None),
    ]

    def m(mes, tps=0.0):
        return mes * MESURE + tps * TEMPS

    # (instant, fichier du jeu, gain dB)
    sons = [
        (m(0, 0.2), "sfx/ambience_03.wav", -10), (m(1, 2.0), "sfx/ambience_07.wav", -12),
        (m(0, 1), "sfx/footstep_a_01.wav", -6), (m(0, 3), "sfx/footstep_a_02.wav", -6),
        (m(1, 1), "sfx/footstep_a_03.wav", -5), (m(1, 3), "sfx/footstep_a_04.wav", -5),
        (m(2), "sfx/torch_on.wav", 0),
        (m(2, 2), "sfx/footstep_a_01.wav", -4), (m(3, 0), "sfx/footstep_a_02.wav", -3),
        (m(3, 2), "sfx/footstep_a_03.wav", -2), (m(4, 0), "sfx/footstep_a_04.wav", -1),
        (m(4, 2), "sfx/footstep_a_01.wav", 0), (m(5, 0), "sfx/footstep_a_02.wav", 0),
        (m(6), "music/music_match_heartbeat.ogg", -6), (m(7), "music/music_match_heartbeat.ogg", -5),
        (m(8), "music/music_match_heartbeat.ogg", -4),
        (m(8, 2), "weapons/weapon_dry_pistolet.wav", -6),
        (m(9), "weapons/weapon_pistolet_01.wav", 0), (m(9, 0.1), "sfx/tinnitus_death.wav", -4),
        (m(10, 1), "sfx/shell_02.wav", -2), (m(10, 2), "sfx/shell_03.wav", -8),
        (m(11), "sfx/wall_brush_01.wav", -8), (m(11, 2), "sfx/wall_brush_02.wav", -10),
        (m(12, 1), "sfx/shell_04.wav", -6),
        (m(13), "sfx/ui_type_impact.wav", 0), (m(13), "music/music_intro.ogg", -3),
        (m(15), "sfx/ui_power_on.wav", 0),
        (m(17), "music/music_menu.ogg", -4),
    ]

    duree = sum(p[0] for p in plans) * MESURE
    video = f"{tmp}/_video.mp4"
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "16",
                           "-pix_fmt", "yuv420p", video], stdin=subprocess.PIPE)
    police = ImageFont.truetype(POLICE_REPERE, 22)
    os.makedirs(REPLI, exist_ok=True)
    t0 = 0.0
    for k, (mes, nom, rendu, repli) in enumerate(plans, 1):
        debut, fin = round(t0 * FPS), round((t0 + mes * MESURE) * FPS)
        n = fin - debut
        for i in range(n):
            im = rendu(i / max(1, n - 1), i, n)
            if repli and i == n // 2:
                im.resize((1280, 720), Image.LANCZOS).save(f"{REPLI}/intro_a_{repli}.jpg", quality=86)
            if REPERE:
                im = im.copy()
                ImageDraw.Draw(im).text((28, H - 46), f"A · plan {k} · {nom} · {(debut + i) / FPS:05.2f} s",
                                        font=police, fill=(120, 116, 108))
            ff.stdin.write(im.tobytes())
        print(f"plan {k:2d}  {t0:6.2f} → {t0 + mes * MESURE:6.2f} s  {nom}")
        t0 += mes * MESURE
    ff.stdin.close()
    if ff.wait() != 0:
        sys.exit("ffmpeg (vidéo) a échoué")

    entrees, filtres = [], []
    for j, (t, fichier, db) in enumerate(sons):
        entrees += ["-i", AUDIO + fichier]
        ms = round(t * 1000)
        filtres.append(f"[{j + 1}:a]aformat=sample_rates=48000:channel_layouts=stereo,volume={db}dB,adelay={ms}|{ms}[s{j}]")
    filtres.append("".join(f"[s{j}]" for j in range(len(sons)))
                   + f"amix=inputs={len(sons)}:normalize=0,atrim=0:{duree:.3f},afade=t=out:st={duree - 0.6:.3f}:d=0.6,"
                   "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,alimiter=limit=0.8:level=false[a]")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, *entrees, "-filter_complex", ";".join(filtres),
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", MAITRE],
                   check=True)
    subprocess.run(["ffmpeg2theora", "-v", str(QUALITE_VIDEO), "-a", str(QUALITE_AUDIO), "-o", FILM, MAITRE],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["rm", "-rf", tmp], check=True)
    print(f"durée {duree:.2f} s → {FILM} ({os.path.getsize(FILM) / 1e6:.1f} Mo)")


if __name__ == "__main__":
    monter()
