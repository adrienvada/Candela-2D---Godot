#!/usr/bin/env python3
"""Fabrique une « ferme » : un projet Godot fait de liens symboliques vers le worktree, dont le project.godot enveloppe chaque
autoload d'un script `extends` qui date son `_init` et son `_ready` (étape 3 de la mission M : le coût de chaque autoload).

Usage : faire_ferme.py <dossier de la ferme> [<scène principale>]
La scène principale par défaut est `res://tools/sonde_demarrage.tscn` (elle date le chargement de main.tscn).
"""
import os
import pathlib
import re
import shutil
import sys

WT = pathlib.Path("/home/user/Candela-2D---Godot/.claude/worktrees/agent-a26bf5b2f4d2b80a3")
ferme = pathlib.Path(sys.argv[1])
scene = sys.argv[2] if len(sys.argv) > 2 else "res://tools/sonde_demarrage.tscn"

if ferme.exists():
    shutil.rmtree(ferme)
ferme.mkdir(parents=True)
for e in sorted(os.listdir(WT)):
    if e in ("project.godot", ".git", ".claude", ".github"):
        continue
    os.symlink(WT / e, ferme / e)

# uid -> chemin res:// pour les autoloads déclarés par uid (le greffon EOS).
uids = {}
for racine in ("addons",):
    for p in (WT / racine).rglob("*.uid"):
        try:
            u = p.read_text().strip()
        except OSError:
            continue
        if u.startswith("uid://"):
            uids[u] = "res://" + str(p.relative_to(WT))[:-4]

src = (WT / "project.godot").read_text(encoding="utf-8").split("\n")
sortie = []
dans_autoload = False
(ferme / "_wrap").mkdir()
n = 0
ordre = []
for ligne in src:
    if ligne.startswith("["):
        dans_autoload = ligne.strip() == "[autoload]"
        sortie.append(ligne)
        continue
    if dans_autoload and "=" in ligne and not ligne.startswith(";"):
        nom, valeur = ligne.split("=", 1)
        v = valeur.strip().strip('"')
        etoile = v.startswith("*")
        chemin = v[1:] if etoile else v
        if chemin.startswith("uid://"):
            chemin = uids.get(chemin, "")
        if not chemin:
            sortie.append(ligne)
            ordre.append((nom, "?"))
            continue
        n += 1
        w = ferme / "_wrap" / ("%02d_%s.gd" % (n, re.sub(r"[^A-Za-z0-9_]", "_", nom)))
        w.write_text(
            'extends "%s"\n\n'
            "func _init() -> void:\n"
            '\tprint("[AL] init %s %%d" %% Time.get_ticks_usec())\n\n'
            "func _notification(what: int) -> void:\n"
            "\tif what == NOTIFICATION_READY:\n"
            '\t\tprint("[AL] ready %s %%d" %% Time.get_ticks_usec())\n' % (chemin, nom, nom),
            encoding="utf-8")
        sortie.append('%s="%sres://_wrap/%s"' % (nom, "*" if etoile else "", w.name))
        ordre.append((nom, chemin))
        continue
    if ligne.startswith("run/main_scene="):
        sortie.append('run/main_scene="%s"' % scene)
        continue
    sortie.append(ligne)
(ferme / "project.godot").write_text("\n".join(sortie), encoding="utf-8")
print("ferme prête :", ferme)
for nom, chemin in ordre:
    print("  autoload %-20s %s" % (nom, chemin))
