#!/usr/bin/env bash
# Q40, la lampe claire : refaire les prises, les mesures et la planche (cloud, Xvfb). Depuis la racine du dépôt.
#   docs/iso/cloud/lampe-claire/lancer.sh
# Une seule séance : l'outil bascule l'essai lui-même, jeu en pause, au même instant (aucun drapeau à passer).
set -euo pipefail
GODOT="${GODOT:-godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/lampe-xdg}"
mkdir -p "$XDG_DATA_HOME"
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --path . res://tools/photo_lampe.tscn -- \
    --no-eos --led-murs-fige --sortie=user://lampe/v1
D="$XDG_DATA_HOME/godot/app_userdata/Candela 2D/lampe/v1"
python3 docs/iso/cloud/lampe-claire/mesurer.py "$D" > docs/iso/cloud/lampe-claire/mesures.json
python3 docs/iso/cloud/lampe-claire/planche.py "$D" docs/iso/cloud/lampe-claire/mesures.json
