#!/usr/bin/env bash
# Q39 — refaire toutes les images et la planche du corps de soi (session cloud corps-sombre, 2026-09-28).
# Depuis la racine du dépôt, dans le conteneur du cloud (Xvfb, llvmpipe) ; sur le Mac, retirer `xvfb-run …`.
#
# ⚠️ Une fusée brûle plus de 10 s de jeu et sa fumée efface les corps : chaque fusée a sa propre séance, APRÈS les autres
# scènes de sa classe. Le Spectre n'a pas de fusée (par dessein). Un XDG_DATA_HOME neuf : l'outil congédie l'intro.
set -uo pipefail
GODOT="${GODOT:-godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/cs_data}"
mkdir -p "$XDG_DATA_HOME"
SORTIE="user://corps_sombre"
seance() {
  timeout 3500 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --path . \
    res://tools/photo_corps_sombre.tscn -- --no-eos --led-murs-fige --sortie="$SORTIE" "$@"
}
seance --classes=pistolet,pompe,fumiste,spectre --scenes=noir,torche,vide,adverse,lisiere,scinde,scinde_noir
for c in pistolet pompe fumiste; do seance --classes=$c --scenes=fusee; done
python3 docs/iso/cloud/corps-sombre/mesurer.py "$XDG_DATA_HOME/godot/app_userdata/Candela 2D/corps_sombre"
python3 docs/iso/cloud/corps-sombre/planche.py
