#!/usr/bin/env python3
"""L'intro v2, récit A « Qui allume se montre » — le monteur (2026-09-29).

Refait, depuis `assets/sources/intro/` (hors dépôt, voir son `.gitignore`) :

- le film `assets/video/intro/intro_a.ogv` (Theora + Vorbis, le seul format
  vidéo que Godot lit), image ET son, tel qu'Adrien l'a validé ;
- une image de repli par plan, `assets/ui/intro/intro_a_pNN.jpg`, que
  `intro_planches.gd` montre si le film manque.

Dix-sept plans sur vingt-cinq mesures de la musique du jeu (170 BPM, quatre
temps : une mesure = 1,4118 s), 35,29 s. **Le découpage est écrit deux fois**,
ici (`PLANS`) et dans `intro_planches.gd` ; `tools/test_intro_planches.gd`
vérifie qu'ils sont d'accord en relisant ce fichier.

Chaque plan prend une fenêtre de sa source (avec une coupe éventuelle) et la
cale sur sa durée. Les sources : onze clips vidéo générés (Veo 3.1 Fast par
Google Flow, un par Kling 3 Pro via Runway), deux clips de la veille, les
textes animés (`tools/intro_textes.py`) et le titre (`tools/intro_titre.py`),
à refaire AVANT ce script s'ils changent. Le son est un mixage ffmpeg des
fichiers du jeu, normalisé à −16 LUFS puis limité.

    python3 tools/monter_intro.py            # film + repli
    python3 tools/monter_intro.py --repere   # + plan et temps incrustés (pour relire)

Nécessite ffmpeg, ffmpeg2theora (`brew install ffmpeg2theora` ; l'ffmpeg de ce
poste ne sait pas encoder le Theora) et Pillow. ⚠️ Installer ffmpeg2theora a déjà
cassé l'ffmpeg du poste une fois (`libx265` introuvable) : `brew reinstall ffmpeg`.
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

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
NOIR = Image.new("RGB", (W, H), (0, 0, 0))

# Qualité Theora (0-10) et Vorbis (-1-10). Theora 4 : 9,2 Mo au lieu de 18,5 à 6, sans perte visible en
# recadrage 1:1 (comparé le 2026-09-29) ; à 3 (7,4 Mo), la texture du mur de « VOIR » s'adoucit.
QUALITE_VIDEO = 4
QUALITE_AUDIO = 4

# (mesures, nom, source dans assets/sources/intro/, début, fin, coupe) — le même ordre que `PLANS` dans
# intro_planches.gd. La fenêtre [début, fin] de la source est calée sur la durée du plan.
PLANS = [
    (1, "noir", None, 0, 0, None),
    (1, "le pouce", "clips/f02_pouce.mp4", 1.2, 3.9, (2.65, 3.10)),      # l'étoile d'éclair plate de Veo (2,67 → 3,04 s, mesurée), coupée
    (2, "le couloir", "clips/p2_faisceau.mp4", 0.0, 2.82, None),
    (1, "VOIR", "textes/voir.mp4", 0.0, 1.40, None),
    (2, "le pilier", "clips/p3_cache.mp4", 0.0, 2.82, None),
    (1, "la tête", "clips/f06_tete.mp4", 3.0, 5.5, None),
    (1, "le chasseur", "clips/f07_chasseur.mp4", 1.0, 3.0, None),
    (1, "SANS ÊTRE VU.", "textes/sans_etre_vu.mp4", 0.0, 1.40, None),
    (1, "la main", "clips/f09_main.mp4", 1.0, 4.0, None),
    (1, "le pilier, vu par J1", "clips/f10_pilier_j1.mp4", 0.5, 2.5, None),   # après 3 s, la poussière gonfle
    (2, "la sortie", "clips/k11_sortie.mp4", 1.9, 4.10, None),          # finit sur l'éclair de bouche (4,06 s)
    (1, "TUER", "textes/tuer.mp4", 0.0, 1.40, None),
    (1, "la main s'ouvre", "clips/f13_main_ouvre.mp4", 0.8, 3.6, None),
    (2, "la torche roule", "clips/p8_torche.mp4", 0.0, 2.82, None),
    (1, "le pied", "clips/f15_pied.mp4", 1.6, 4.4, None),
    (2, "SANS ÊTRE TUÉ.", "textes/sans_etre_tue.mp4", 0.0, 2.82, None),
    (4, "CANDELA", "titre/titre.mp4", 0.0, 5.64, None),
]


def m(mes, tps=0.0):
    return mes * MESURE + tps * TEMPS


# (instant, fichier du jeu, gain dB, vitesse)
SONS = [
    (m(0, 0.2), "sfx/ambience_03.wav", -10, 1), (m(0, 1), "sfx/footstep_a_01.wav", -7, 1), (m(0, 3), "sfx/footstep_a_02.wav", -7, 1),
    (m(1, 2.6), "sfx/torch_on.wav", 0, 1),                                  # la lampe s'allume (plan 2, après la coupe)
    (m(2), "music/music_match_base.ogg", -9, 1),
    (m(2, 1), "sfx/footstep_a_03.wav", -6, 1), (m(2, 3), "sfx/footstep_a_04.wav", -6, 1),
    (m(3, 1), "sfx/footstep_a_01.wav", -6, 1), (m(3, 3), "sfx/footstep_a_02.wav", -6, 1),
    (m(4), "sfx/wall_brush_01.wav", -12, 1),
    (m(5, 1), "sfx/footstep_a_03.wav", -5, 1), (m(5, 3), "sfx/footstep_a_04.wav", -4, 1),
    (m(6, 1), "sfx/footstep_a_01.wav", -3, 1), (m(6, 3), "sfx/footstep_a_02.wav", -2, 1),
    (m(8, 1), "sfx/footstep_a_03.wav", -3, 1), (m(8, 3), "sfx/footstep_a_04.wav", -3, 1),
    (m(10), "music/music_match_drums.ogg", -8, 1),                          # le caché serre son arme
    (m(10, 3), "weapons/weapon_dry_pistolet.wav", -12, 1),
    (m(12, 1), "sfx/footstep_b_01.wav", -2, 1), (m(12, 3), "sfx/footstep_b_02.wav", -2, 1),
    (m(14), "weapons/weapon_pistolet_01.wav", 1, 1), (m(14, 0.1), "sfx/tinnitus_death.wav", -3, 1),
    (m(16, 0.5), "sfx/shell_02.wav", -2, 1), (m(16, 1), "sfx/shell_03.wav", -6, 1),
    (m(16, 1.5), "sfx/wall_brush_01.wav", -8, 1), (m(17), "sfx/wall_brush_02.wav", -10, 1), (m(17, 2), "sfx/shell_04.wav", -6, 1),
    (m(18, 2), "sfx/footstep_b_03.wav", 1, 1), (m(18, 3.7), "sfx/torch_off.wav", 0, 1),
    (m(19, 0.2), "sfx/ui_massicot.wav", -4, 1),
    (m(21, 2), "weapons/weapon_pompe_01.wav", 2, 0.5),                     # l'impact du titre : un pompe ralenti
    (m(21, 2), "sfx/ui_power_on.wav", -2, 1), (m(21, 2), "music/music_intro.ogg", -4, 1),
]
# la musique du match se coupe net sur le coup de feu (mesure 14)
COUPE_MUSIQUE = m(14)
MUSIQUES_COUPEES = ("music/music_match_base.ogg", "music/music_match_drums.ogg")


def extraire(dossier, source, a, b, coupe):
    os.makedirs(dossier, exist_ok=True)
    filtre = f"fps=60,scale={W}:{H}:flags=lanczos"
    if coupe:
        filtre = f"select='not(between(t,{coupe[0] - a},{coupe[1] - a}))',setpts=N/FRAME_RATE/TB," + filtre
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(a), "-t", str(b - a), "-i", f"{SOURCES}/{source}",
                    "-vf", filtre, "-q:v", "2", f"{dossier}/%05d.jpg"], check=True)
    return [f"{dossier}/{n}" for n in sorted(os.listdir(dossier))]


def monter():
    tmp = f"{SOURCES}/_images"
    subprocess.run(["rm", "-rf", tmp], check=True)
    duree = sum(p[0] for p in PLANS) * MESURE
    video = f"{tmp}/_video.mp4"
    os.makedirs(tmp)
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "16",
                           "-pix_fmt", "yuv420p", video], stdin=subprocess.PIPE)
    police = ImageFont.truetype(f"{DEPOT}/assets/fonts/Oxanium.ttf", 22)
    os.makedirs(REPLI, exist_ok=True)
    t0 = 0.0
    for k, (mes, nom, source, a, b, coupe) in enumerate(PLANS, 1):
        debut, fin = round(t0 * FPS), round((t0 + mes * MESURE) * FPS)
        n = fin - debut
        src = extraire(f"{tmp}/{k:02d}", source, a, b, coupe) if source else []
        for i in range(n):
            im = Image.open(src[min(len(src) - 1, i * len(src) // n)]).convert("RGB") if src else NOIR
            if nom == "le pied" and i >= n - 4:                 # la torche s'éteint : noir
                im = NOIR
            # l'image de repli : le milieu du plan ; pour le titre, le logo net après l'embrasement
            if source and i == (int(n * 0.85) if nom == "CANDELA" else n // 2):
                im.resize((1280, 720), Image.LANCZOS).save(f"{REPLI}/intro_a_p{k:02d}.jpg", quality=86)
            if REPERE:
                im = im.copy()
                ImageDraw.Draw(im).text((28, H - 46), f"plan {k} · {nom} · {(debut + i) / FPS:05.2f} s",
                                        font=police, fill=(120, 116, 108))
            ff.stdin.write(im.tobytes())
        print(f"plan {k:2d}  {t0:6.2f} → {t0 + mes * MESURE:6.2f} s  {nom}")
        t0 += mes * MESURE
    ff.stdin.close()
    if ff.wait() != 0:
        sys.exit("ffmpeg (vidéo) a échoué")

    entrees, filtres = [], []
    for j, (t, fichier, db, vitesse) in enumerate(SONS):
        entrees += ["-i", AUDIO + fichier]
        ms = round(t * 1000)
        ralenti = f"asetrate=48000*{vitesse},aresample=48000," if vitesse != 1 else ""
        coupe = ""
        if fichier in MUSIQUES_COUPEES:
            reste = COUPE_MUSIQUE - t
            coupe = f"atrim=0:{reste:.3f},afade=t=out:st={reste - 0.03:.3f}:d=0.03,"
        filtres.append(f"[{j + 1}:a]aformat=sample_rates=48000:channel_layouts=stereo,{ralenti}{coupe}volume={db}dB,"
                       f"adelay={ms}|{ms}[s{j}]")
    filtres.append("".join(f"[s{j}]" for j in range(len(SONS))) + f"amix=inputs={len(SONS)}:normalize=0,"
                   f"atrim=0:{duree:.3f},afade=t=out:st={duree - 0.5:.3f}:d=0.5,"
                   "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,alimiter=limit=0.8:level=false[a]")
    maitre = MAITRE.replace(".mp4", "_repere.mp4") if REPERE else MAITRE
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, *entrees, "-filter_complex", ";".join(filtres),
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", maitre], check=True)
    subprocess.run(["rm", "-rf", tmp], check=True)
    if REPERE:
        print(f"durée {duree:.2f} s → {maitre} (version de relecture, le film du jeu n'est pas touché)")
        return
    subprocess.run(["ffmpeg2theora", "-v", str(QUALITE_VIDEO), "-a", str(QUALITE_AUDIO), "-o", FILM, maitre],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"durée {duree:.2f} s → {FILM} ({os.path.getsize(FILM) / 1e6:.1f} Mo)")


if __name__ == "__main__":
    monter()
