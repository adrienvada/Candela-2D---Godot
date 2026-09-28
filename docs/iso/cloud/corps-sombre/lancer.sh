#!/usr/bin/env bash
# Q39 — refaire toutes les images et la planche du corps de soi (session cloud corps-sombre, 2026-09-28).
# Depuis la racine du dépôt, dans le conteneur du cloud (Xvfb, llvmpipe) ou sur le Mac (sans xvfb-run).
# Un XDG_DATA_HOME neuf : l'outil congédie l'intro en planches d'un user:// neuf.
set -euo pipefail
GODOT="${GODOT:-godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/cs_data}"
mkdir -p "$XDG_DATA_HOME"
timeout 3500 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --path . \
  res://tools/photo_corps_sombre.tscn -- --no-eos --led-murs-fige --sortie=user://cs_full | tee /tmp/cs_full.log
python3 docs/iso/cloud/corps-sombre/mesurer.py "$XDG_DATA_HOME/godot/app_userdata/Candela 2D/cs_full"
python3 docs/iso/cloud/corps-sombre/planche.py
