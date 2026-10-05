#!/usr/bin/env python3
"""V5 / CAR-07 — taille d'un code de partage « bombe » et statistiques des cartes légitimes.

Lecture seule : ne touche à aucun fichier du dépôt. Usage :
    python3 bombe_codec.py [racine_du_depot]

1. Fabrique, en mémoire, le JSON le plus gros que `MapCodec.from_share_code` accepte (8 Mo décompressés,
   `MAX_DECOMPRESSED_BYTES = 8 << 20`) fait de runs « 0,0,128; » et dit sa taille en gzip / base64 et le
   nombre de cases que `decode_runs` en tirerait.
2. Relève, sur les cartes livrées (assets/maps) et les salles d'aventure (assets/solo/chapitre_*), la longueur
   et le nombre de runs les plus grands par famille (floor / walls / low_walls) : la marge des bornes proposées.
"""
import base64
import glob
import json
import os
import sys
import zlib

MAX = 8 << 20
UNITE = "0,0,128;"

avant = '{"version":4,"id":"a","name":"b","grid_size":{"x":32,"y":32},"floor":"'
apres = '","walls":"","low_walls":"","spawn_p1":{"x":1,"y":1},"spawn_p2":{"x":20,"y":20}}'
budget = MAX - len(avant) - len(apres) - 16
n = budget // len(UNITE)
js = avant + UNITE * n + apres
c = zlib.compressobj(9, zlib.DEFLATED, 31)  # 31 = en-tête gzip, comme FileAccess.COMPRESSION_GZIP
z = c.compress(js.encode()) + c.flush()
print("JSON décompressé : %d octets (borne %d)" % (len(js), MAX))
print("runs : %d  -> cases décodées : %d" % (n, n * 128))
print("gzip : %d octets  | base64 : %d caractères  | ratio %.0f:1" % (len(z), len(base64.b64encode(z)), len(js) / len(z)))
print("Array[Vector2i] (Variant de 24 o) : %.2f Go ; à 8 o/case : %.2f Go" % (n * 128 * 24 / 1e9, n * 128 * 8 / 1e9))

racine = sys.argv[1] if len(sys.argv) > 1 else "/home/user/Candela-2D---Godot"
fichiers = glob.glob(os.path.join(racine, "assets/maps/*.json")) + \
    glob.glob(os.path.join(racine, "assets/solo/chapitre_*/*.json"))
maxi = {}
nb = 0
for f in fichiers:
    d = json.load(open(f, encoding="utf-8"))
    carte = d["carte"] if isinstance(d.get("carte"), dict) else d
    if "floor" not in carte:
        continue
    nb += 1
    for cle in ("floor", "walls", "low_walls"):
        s = carte.get(cle, "")
        if not isinstance(s, str):
            continue
        runs = s.count(";") + 1 if s else 0
        for nom, val in (("%s_caractères" % cle, len(s)), ("%s_runs" % cle, runs)):
            if val > maxi.get(nom, (0, ""))[0]:
                maxi[nom] = (val, os.path.relpath(f, racine))
print("\n%d cartes lues (livrées + salles d'aventure)" % nb)
for k, (v, f) in sorted(maxi.items()):
    print("  max %-22s %6d   %s" % (k, v, f))
