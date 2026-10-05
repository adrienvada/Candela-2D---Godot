#!/usr/bin/env python3
"""V5 / AUD-04 — les WAV positionnels importés en stéréo sont-ils de vrais stéréo ou du « double mono » ?

Lecture seule. Usage : python3 stereo_sfx.py [racine_du_depot]
Pour chaque WAV de assets/audio/sfx et assets/audio/weapons : canaux, durée, drapeau `force/mono` de son
`.import`, et — si stéréo 16 bits — l'écart maximal entre canaux et le rapport d'énergie côté / milieu
(0 = L et R identiques ; 1 = autant d'énergie dans la différence que dans la somme).
"""
import array
import glob
import os
import sys
import wave

racine = sys.argv[1] if len(sys.argv) > 1 else "/home/user/Candela-2D---Godot"
os.chdir(os.path.join(racine, "assets/audio"))
lignes = []
for d in ("sfx", "weapons"):
    for f in sorted(glob.glob("%s/*.wav" % d)):
        imp = open(f + ".import", encoding="utf-8", errors="replace").read()
        mono = "force/mono=true" in imp
        w = wave.open(f, "rb")
        n, sr, fr, sw = w.getnchannels(), w.getframerate(), w.getnframes(), w.getsampwidth()
        if n == 2 and sw == 2:
            a = array.array("h")
            a.frombytes(w.readframes(fr))
            L, R = a[0::2], a[1::2]
            ecart = max((abs(x - y) for x, y in zip(L, R)), default=0)
            side = sum((x - y) ** 2 for x, y in zip(L, R))
            mid = sum((x + y) ** 2 for x, y in zip(L, R))
            ratio = side / mid if mid else 0.0
        else:
            ecart, ratio = None, None
        lignes.append((f, n, fr / sr, mono, ecart, ratio))
        w.close()

print("%-40s %s %6s %-10s %8s %s" % ("fichier", "ch", "durée", "mono_imp.", "écart_LR", "côté/milieu"))
for f, n, dur, mono, ecart, ratio in lignes:
    print("%-40s %d %5.2fs %-10s %8s %s" % (f, n, dur, mono, ecart, "%.5f" % ratio if ratio is not None else "-"))
