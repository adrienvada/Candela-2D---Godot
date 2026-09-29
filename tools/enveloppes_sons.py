#!/usr/bin/env python3
"""Précalcule l'enveloppe d'amplitude de chaque son positionnel du jeu.

Chantier SON VISIBLE (0.8.0). Adrien, 2026-09-29 : « Il faudrait que les liserés
s'animent en fonction du son (de la forme d'onde plus ou moins) des sons : un long
son très réverbéré doit durer autant que le son, et un son très court et étouffé
doit durer très peu. »

    python3 tools/enveloppes_sons.py              # écrit enveloppes_sons.gd
    python3 tools/enveloppes_sons.py --verifier   # échoue si le fichier est périmé
    python3 tools/enveloppes_sons.py --autotest   # éprouve le lecteur de WAV

## Pourquoi ce script existe, et pourquoi il écrit du GDScript

Le liseré doit suivre la forme d'onde du son joué. Or le jeu ne peut pas la lire :
les 96 WAV sont importés en `compress/mode=2` (QOA), donc `AudioStreamWAV.data`
n'est pas du PCM lisible, et un export ne contient même pas les `.wav` sources.
L'enveloppe se **précalcule donc hors ligne**, depuis les sources, et se livre sous
la forme d'un **script** : un `.gd` est toujours exporté, un JSON ne l'aurait pas
été sans filtre d'export (et ce serait alors un repli muet de plus).

## Ce qu'il calcule

Pour chaque WAV : l'énergie RMS par fenêtres de 20 ms, une toutes les 10 ms,
exprimée en dB **sous le pic du fichier** (0 = la fenêtre la plus forte). Les deux
canaux d'un fichier stéréo se comptent ensemble (moyenne des puissances).

- **La fenêtre `i` couvre `[i·10 ms, i·10 ms + 20 ms]`** : elle ANTICIPE le son de
  20 ms au plus, pour que l'attaque du liseré tombe sur celle du son, jamais après.
- Le plancher est à -90 dB (le silence numérique ne vaut pas -infini).
- Une décimale suffit : le liseré ne distingue pas 0,1 dB.

Le niveau ABSOLU du fichier n'est pas gardé — c'est voulu : `AudioManager` dose le
niveau de chaque famille (`NIVEAU_RELATIF`), le liseré lit ce dosage au pic, et
l'enveloppe ne dit que la FORME autour de ce pic.

## L'empreinte

Chaque entrée porte la taille et le SHA-256 du fichier source. Une suite headless
(`tools/test_enveloppes_sons.gd`) échoue si un WAV positionnel n'a pas d'enveloppe
ou si son empreinte a changé : **remplacer un son sans relancer ce script ferait
animer le liseré sur la forme de l'ancien**, sans une erreur.

## Ce qu'il couvre

`assets/audio/sfx/` et `assets/audio/weapons/`, sauf ce qui n'est jamais joué en
positionnel : interface, décompte, acouphènes, ambiance et bascule de torche
(`EXCLUS`). Un son de gadget déposé demain dans `sfx/` est couvert sans qu'on
touche à rien ici — et la suite l'exige.

Sans dépendance : bibliothèque standard seulement (`wave`, plus une lecture RIFF de
secours pour les WAV « extensible » et flottants que `wave` refuse — la sortie de
plusieurs éditeurs audio en 24 bits).
"""
import argparse
import hashlib
import math
import struct
import sys
import tempfile
import wave
from array import array
from itertools import accumulate
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SORTIE = RACINE / "enveloppes_sons.gd"
DOSSIERS = ["assets/audio/sfx", "assets/audio/weapons"]
# Jamais joués par `play_sfx_2d` : ni annoncés au liseré, ni animés.
EXCLUS = ("ui_", "count_", "button_click", "tinnitus_", "ambience_", "torch_")

PAS_S = 0.010
FENETRE_S = 0.020
PLANCHER_DB = -90.0


# --- Lecture des WAV ------------------------------------------------------------

def _lire_riff(chemin):
    """(format, canaux, cadence, bits, octets) d'un WAV par ses blocs RIFF.

    Secours pour ce que `wave` refuse : `WAVE_FORMAT_EXTENSIBLE` (0xFFFE, la forme
    de presque tout ce qui dépasse 16 bits) et les flottants (format 3).
    """
    brut = Path(chemin).read_bytes()
    if brut[:4] != b"RIFF" or brut[8:12] != b"WAVE":
        raise ValueError("pas un fichier WAV (RIFF/WAVE absent)")
    fmt = None
    donnees = None
    i = 12
    while i + 8 <= len(brut):
        ident = brut[i:i + 4]
        taille = struct.unpack_from("<I", brut, i + 4)[0]
        corps = brut[i + 8:i + 8 + taille]
        if ident == b"fmt ":
            fmt = struct.unpack_from("<HHIIHH", corps, 0)
            tag = fmt[0]
            if tag == 0xFFFE and taille >= 26:
                # Le vrai format est le début du GUID de sous-format.
                tag = struct.unpack_from("<H", corps, 24)[0]
            fmt = (tag,) + fmt[1:]
        elif ident == b"data":
            donnees = corps
        i += 8 + taille + (taille & 1)
    if fmt is None or donnees is None:
        raise ValueError("bloc fmt ou data absent")
    tag, canaux, cadence, _debit, _align, bits = fmt
    return tag, canaux, cadence, bits, donnees


def _decoder(tag, bits, octets):
    """Les échantillons, en flottants entre -1 et 1 (entrelacés si plusieurs canaux)."""
    if tag == 3:
        if bits == 32:
            a = array("f")
        elif bits == 64:
            a = array("d")
        else:
            raise ValueError("WAV flottant en %d bits non géré" % bits)
        a.frombytes(octets[:len(octets) - len(octets) % (bits // 8)])
        if sys.byteorder == "big":
            a.byteswap()
        return list(a)
    if tag != 1:
        raise ValueError("format WAV %#x non géré (PCM entier ou flottant seulement)" % tag)
    if bits == 8:
        return [(b - 128) / 128.0 for b in octets]
    if bits == 16:
        a = array("h")
        a.frombytes(octets[:len(octets) - len(octets) % 2])
        if sys.byteorder == "big":
            a.byteswap()
        return [x / 32768.0 for x in a]
    if bits == 24:
        n = len(octets) // 3
        return [int.from_bytes(octets[3 * k:3 * k + 3], "little", signed=True) / 8388608.0
                for k in range(n)]
    if bits == 32:
        a = array("i")
        a.frombytes(octets[:len(octets) - len(octets) % 4])
        if sys.byteorder == "big":
            a.byteswap()
        return [x / 2147483648.0 for x in a]
    raise ValueError("WAV PCM en %d bits non géré" % bits)


def lire_wav(chemin):
    """(échantillons entrelacés en flottants, canaux, cadence) — `wave`, puis RIFF."""
    try:
        with wave.open(str(chemin), "rb") as w:
            canaux, largeur, cadence = w.getnchannels(), w.getsampwidth(), w.getframerate()
            octets = w.readframes(w.getnframes())
        return _decoder(1, 8 * largeur, octets), canaux, cadence
    except (wave.Error, EOFError):
        tag, canaux, cadence, bits, octets = _lire_riff(chemin)
        return _decoder(tag, bits, octets), canaux, cadence


# --- L'enveloppe ------------------------------------------------------------------

def enveloppe_db(echantillons, canaux, cadence):
    """(durée en s, liste des dB sous le pic, une valeur par pas de 10 ms)."""
    trames = len(echantillons) // canaux
    if trames == 0:
        return 0.0, [PLANCHER_DB]
    # Puissance par trame : moyenne des carrés sur les canaux.
    if canaux == 1:
        puissance = [x * x for x in echantillons]
    else:
        puissance = [sum(x * x for x in echantillons[k * canaux:(k + 1) * canaux]) / canaux
                     for k in range(trames)]
    cumul = list(accumulate(puissance, initial=0.0))
    pas = max(1, round(cadence * PAS_S))
    fenetre = max(1, round(cadence * FENETRE_S))
    rms = []
    for debut in range(0, trames, pas):
        fin = min(debut + fenetre, trames)
        rms.append(math.sqrt(max(cumul[fin] - cumul[debut], 0.0) / fenetre))
    pic = max(rms)
    if pic <= 0.0:
        return trames / cadence, [PLANCHER_DB] * len(rms)
    db = [max(20.0 * math.log10(max(r, 1e-12) / pic), PLANCHER_DB) for r in rms]
    return trames / cadence, [round(d, 1) + 0.0 for d in db]


def empreinte(chemin):
    brut = Path(chemin).read_bytes()
    return len(brut), hashlib.sha256(brut).hexdigest()


def wav_couverts():
    """Les WAV du dépôt qui reçoivent une enveloppe, en chemins `res://` triés."""
    trouves = []
    for dossier in DOSSIERS:
        for f in sorted((RACINE / dossier).glob("*.wav")):
            if f.name.startswith(EXCLUS):
                continue
            trouves.append("res://" + f.relative_to(RACINE).as_posix())
    return sorted(trouves)


# --- Le fichier GDScript ---------------------------------------------------------------

ENTETE = '''extends RefCounted

## ⚠️ GÉNÉRÉ par `tools/enveloppes_sons.py` — NE PAS ÉDITER À LA MAIN.
##
## L'enveloppe d'amplitude de chaque son positionnel du jeu, pour que le liseré du
## son rendu visible (`son_visible.gd`) suive la forme d'onde du fichier joué
## (Adrien, 2026-09-29). Précalculée hors ligne parce que les WAV sont importés en
## QOA (`AudioStreamWAV.data` n'est pas du PCM lisible) et qu'un export ne contient
## pas les sources — un script, lui, est toujours exporté.
##
## Régénérer :  python3 tools/enveloppes_sons.py
##
## `tools/test_enveloppes_sons.gd` échoue si un WAV positionnel n'a pas d'entrée ici
## ou si son empreinte (taille + SHA-256) a changé.
##
## Chaque entrée : `duree` (s, du fichier), `taille` et `sha256` (l'empreinte du
## source), `db` (énergie RMS par fenêtres de `FENETRE_S`, une toutes les `PAS_S`, en dB
## sous le pic du fichier ; la fenêtre `i` couvre `[i·PAS_S, i·PAS_S + FENETRE_S]`).

const PAS_S := %(pas)s
const FENETRE_S := %(fenetre)s
const PLANCHER_DB := %(plancher)s

const ENVELOPPES: Dictionary = {
'''


def texte_gd(entrees):
    """Le contenu exact de `enveloppes_sons.gd` — le même octet pour octet à chaque run."""
    sortie = [ENTETE % {"pas": repr(PAS_S), "fenetre": repr(FENETRE_S), "plancher": "%.1f" % PLANCHER_DB}]
    for chemin in sorted(entrees):
        e = entrees[chemin]
        sortie.append('\t"%s": {\n' % chemin)
        sortie.append('\t\t"duree": %s,\n' % repr(round(e["duree"], 6)))
        sortie.append('\t\t"taille": %d,\n' % e["taille"])
        sortie.append('\t\t"sha256": "%s",\n' % e["sha256"])
        sortie.append('\t\t"db": [\n')
        db = e["db"]
        for i in range(0, len(db), 20):
            sortie.append("\t\t\t" + ", ".join("%.1f" % x for x in db[i:i + 20]) + ",\n")
        sortie.append("\t\t],\n\t},\n")
    sortie.append("}\n")
    return "".join(sortie)


def calculer():
    entrees = {}
    for chemin in wav_couverts():
        source = RACINE / chemin[len("res://"):]
        echantillons, canaux, cadence = lire_wav(source)
        duree, db = enveloppe_db(echantillons, canaux, cadence)
        taille, sha = empreinte(source)
        entrees[chemin] = {"duree": duree, "db": db, "taille": taille, "sha256": sha}
    return entrees


def verifier(texte):
    """Vrai si `enveloppes_sons.gd` est à jour ; sinon dit quelles entrées ont bougé."""
    if not SORTIE.exists():
        print("enveloppes_sons.gd n'existe pas : python3 tools/enveloppes_sons.py")
        return False
    actuel = SORTIE.read_text(encoding="utf-8")
    if actuel == texte:
        return True

    def blocs(t):
        out = {}
        for morceau in t.split('\n\t"res://')[1:]:
            out["res://" + morceau.split('"', 1)[0]] = morceau
        return out

    a, b = blocs(actuel), blocs(texte)
    perimes = sorted(k for k in b if a.get(k) != b[k])
    manquants = sorted(k for k in b if k not in a)
    en_trop = sorted(k for k in a if k not in b)
    print("enveloppes_sons.gd est périmé — régénérer avec tools/enveloppes_sons.py")
    for k in perimes:
        print("  changé  : " + k)
    for k in manquants:
        print("  absent  : " + k)
    for k in en_trop:
        print("  en trop : " + k)
    return False


# --- L'auto-épreuve du lecteur ----------------------------------------------------------

def _ecrire_riff(chemin, tag, canaux, cadence, bits, octets, extensible=False):
    """Un WAV écrit à la main, pour éprouver le secours RIFF."""
    octets_par_echantillon = bits // 8
    if extensible:
        fmt = struct.pack("<HHIIHHHHIH14s", 0xFFFE, canaux, cadence,
                          cadence * canaux * octets_par_echantillon, canaux * octets_par_echantillon, bits,
                          22, bits, 3, tag, b"\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71")
    else:
        fmt = struct.pack("<HHIIHH", tag, canaux, cadence,
                          cadence * canaux * octets_par_echantillon, canaux * octets_par_echantillon, bits)
    corps = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt \
        + b"data" + struct.pack("<I", len(octets)) + octets
    Path(chemin).write_bytes(b"RIFF" + struct.pack("<I", len(corps)) + corps)


def autotest():
    """Un claquement (plein pendant 20 ms) puis un silence, sous tous les formats gérés :
    le pic doit être à 0 dB et le silence au plancher, quel que soit le codage."""
    cadence = 48000
    n = cadence // 2
    plein = cadence // 50
    signal = [0.5 if k < plein else 0.0 for k in range(n)]
    ok = True

    def controle(nom, dossier, ecrire, canaux):
        nonlocal ok
        chemin = Path(dossier) / (nom + ".wav")
        ecrire(chemin)
        e, c, sr = lire_wav(chemin)
        duree, db = enveloppe_db(e, c, sr)
        bon = c == canaux and sr == cadence and abs(duree - 0.5) < 1e-6 \
            and abs(db[0]) < 0.06 and db[-1] <= PLANCHER_DB + 0.01 and len(db) == 50
        print("  %-22s %s (%d canal(aux), %d valeurs, pic %.1f dB, fin %.1f dB)"
              % (nom, "ok " if bon else "ÉCHEC", c, len(db), db[0], db[-1]))
        ok = ok and bon

    def pcm(canaux, largeur):
        def ecrire(chemin):
            with wave.open(str(chemin), "wb") as w:
                w.setnchannels(canaux)
                w.setsampwidth(largeur)
                w.setframerate(cadence)
                crete = 2 ** (8 * largeur - 1) - 1
                trames = bytearray()
                for x in signal:
                    v = int(x * crete)
                    for _ in range(canaux):
                        if largeur == 1:
                            trames += bytes([v + 128])
                        else:
                            trames += v.to_bytes(largeur, "little", signed=True)
                w.writeframes(bytes(trames))
        return ecrire

    def riff(tag, bits, canaux, extensible):
        def ecrire(chemin):
            octets = bytearray()
            for x in signal:
                for _ in range(canaux):
                    if tag == 3:
                        octets += struct.pack("<f" if bits == 32 else "<d", x)
                    else:
                        octets += int(x * (2 ** (bits - 1) - 1)).to_bytes(bits // 8, "little", signed=True)
            _ecrire_riff(chemin, tag, canaux, cadence, bits, bytes(octets), extensible)
        return ecrire

    with tempfile.TemporaryDirectory() as tmp:
        print("lecteur de WAV :")
        controle("pcm8_mono", tmp, pcm(1, 1), 1)
        controle("pcm16_mono", tmp, pcm(1, 2), 1)
        controle("pcm16_stereo", tmp, pcm(2, 2), 2)
        controle("pcm24_mono", tmp, pcm(1, 3), 1)
        controle("pcm24_stereo", tmp, pcm(2, 3), 2)
        controle("pcm32_stereo", tmp, pcm(2, 4), 2)
        controle("extensible24_stereo", tmp, riff(1, 24, 2, True), 2)
        controle("extensible16_mono", tmp, riff(1, 16, 1, True), 1)
        controle("flottant32_stereo", tmp, riff(3, 32, 2, False), 2)
        controle("flottant32_extens", tmp, riff(3, 32, 1, True), 1)
        controle("flottant64_mono", tmp, riff(3, 64, 1, False), 1)
    # Le pic d'un fichier stéréo dont un seul canal joue vaut la moitié en puissance :
    # la normalisation au pic doit l'absorber, pas le compter.
    e = [0.5 if k % 2 == 0 else 0.0 for k in range(2 * cadence // 10)]
    _duree, db = enveloppe_db(e, 2, cadence)
    bon = abs(max(db)) < 0.01 and len(db) == 10
    print("  %-22s %s" % ("un seul canal joue", "ok " if bon else "ÉCHEC"))
    ok = ok and bon
    return ok


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--verifier", action="store_true",
                   help="ne rien écrire ; sortir en erreur si enveloppes_sons.gd est périmé")
    p.add_argument("--autotest", action="store_true", help="éprouver le lecteur de WAV, sans toucher au dépôt")
    args = p.parse_args()
    if args.autotest:
        return 0 if autotest() else 1
    entrees = calculer()
    texte = texte_gd(entrees)
    if args.verifier:
        ok = verifier(texte)
        if ok:
            print("enveloppes_sons.gd est à jour (%d sons)" % len(entrees))
        return 0 if ok else 1
    SORTIE.write_text(texte, encoding="utf-8")
    total = sum(len(e["db"]) for e in entrees.values())
    silencieux = [c for c, e in entrees.items() if max(e["db"]) <= PLANCHER_DB]
    print("%s : %d sons, %d valeurs" % (SORTIE.relative_to(RACINE), len(entrees), total))
    for c in silencieux:
        print("  ⚠️ fichier silencieux (enveloppe au plancher) : " + c)
    return 0


if __name__ == "__main__":
    sys.exit(main())
