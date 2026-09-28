#!/usr/bin/env bash
# Q39 (2) — refaire les images et les mesures aujourd'hui / essai A / essai B (session cloud corps-sombre-2, 2026-09-28).
# Depuis la racine du dépôt, dans le conteneur du cloud (Xvfb, llvmpipe) ; sur le Mac, retirer `xvfb-run …`.
# Mêmes scènes et mêmes classes que le premier tour (docs/iso/cloud/corps-sombre/lancer.sh) ; `--fondu` ajoute l'essai B.
# ⚠️ Une fusée par séance (sa fumée efface les corps) ; le Spectre n'en a pas. Un XDG_DATA_HOME neuf : l'outil congédie l'intro.
set -uo pipefail
GODOT="${GODOT:-godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/cs2_data}"
mkdir -p "$XDG_DATA_HOME"
SORTIE="user://corps_sombre_2"
seance() {
  timeout 5000 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --path . \
    res://tools/photo_corps_sombre.tscn -- --no-eos --led-murs-fige --fondu --sortie="$SORTIE" "$@"
}
seance --classes=pistolet,pompe,fumiste,spectre --scenes=noir,torche,vide,adverse,lisiere,scinde,scinde_noir
for c in pistolet pompe fumiste; do seance --classes=$c --scenes=fusee; done
python3 docs/iso/cloud/corps-sombre-2/mesurer.py "$XDG_DATA_HOME/godot/app_userdata/Candela 2D/corps_sombre_2"
