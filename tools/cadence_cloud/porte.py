#!/usr/bin/env python3
"""La porte stricte d'une prise, version conteneur : échantillonne /proc toutes les `pas` secondes tant que le
processus surveillé vit, et note tout processus ÉTRANGER au-dessus de `seuil` % d'un cœur.

Étranger : ni le processus surveillé ni l'un de ses descendants (Godot, son Xvfb, xvfb-run), ni cette porte. Un AUTRE
Godot (ou Xvfb) se note à part, `godots_etrangers`, même au repos : `analyse.py` écarte la prise qui l'a chevauché.
Usage : porte.py <pid_racine> <sortie.json> [seuil=20] [pas=2]
"""
import json
import os
import sys
import time

racine = int(sys.argv[1])
sortie = sys.argv[2]
seuil = float(sys.argv[3]) if len(sys.argv) > 3 else 20.0
pas = float(sys.argv[4]) if len(sys.argv) > 4 else 2.0
HZ = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
moi = os.getpid()


def lire():
    etat = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            with open(f"/proc/{d}/stat", "rb") as f:
                s = f.read().decode("utf-8", "replace")
            fin = s.rindex(")")
            comm = s[s.index("(") + 1:fin]
            champs = s[fin + 2:].split()
            ppid = int(champs[1])
            t = int(champs[11]) + int(champs[12])
            etat[int(d)] = (comm, ppid, t)
        except (OSError, ValueError, IndexError):
            continue
    return etat


def descendants(etat, r):
    enfants = {}
    for pid, (_, ppid, _) in etat.items():
        enfants.setdefault(ppid, []).append(pid)
    vus = {r}
    pile = [r]
    while pile:
        p = pile.pop()
        for e in enfants.get(p, []):
            if e not in vus:
                vus.add(e)
                pile.append(e)
    return vus


# Exceptés, comme WindowServer et kernel_task sur le Mac : le harnais de l'agent qui lance la série (`claude`). Relevé à part.
EXCEPTES = {"claude"}
intrus = []
godots = []
connus = set()
exceptes_max = {}
prec = lire()
t_prec = time.monotonic()
charge_max = 0.0
while True:
    time.sleep(pas)
    cour = lire()
    t = time.monotonic()
    dt = t - t_prec
    # Une fois des nôtres, toujours des nôtres : à la fermeture, `xvfb-run` sort avant que son Xvfb ne meure, et le Xvfb,
    # rattaché à init, n'est plus un descendant — il se notait « autre Godot » à la dernière image (2026-09-30, 15:28).
    siens = descendants(cour, racine) | {moi} | connus
    connus |= siens
    for pid, (comm, ppid, tk) in cour.items():
        if pid in siens or pid not in prec:
            continue
        pct = 100.0 * (tk - prec[pid][2]) / HZ / dt
        if comm in EXCEPTES:
            exceptes_max[comm] = round(max(exceptes_max.get(comm, 0.0), pct), 1)
            continue
        # Un AUTRE Godot (ou son Xvfb), même au repos : la prise l'a chevauché, `analyse.py` l'écarte. Le conteneur se partage
        # entre sessions, et un Godot qui attend peut se réveiller au milieu d'une prise.
        if comm == "godot" or comm.startswith("Godot_v4") or comm == "Xvfb":
            if not any(g["pid"] == pid for g in godots):
                godots.append({"t": round(time.time(), 1), "pid": pid, "comm": comm, "cpu": round(pct, 1)})
        if pct > seuil:
            intrus.append({"t": round(time.time(), 1), "pid": pid, "comm": comm, "cpu": round(pct, 1)})
    try:
        charge_max = max(charge_max, os.getloadavg()[0])
    except OSError:
        pass
    prec, t_prec = cour, t
    if racine not in cour:
        break

with open(sortie, "w") as f:
    json.dump({"intrus": intrus, "godots_etrangers": godots, "fin": round(time.time(), 1), "seuil": seuil, "charge_max_1min": round(charge_max, 2), "exceptes_max": exceptes_max},
              f, ensure_ascii=False)
