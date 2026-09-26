#!/usr/bin/env bash
# Lance le pilote de la répétition (voir pilote.gd). À appeler sous Xvfb dans le cloud :
#   GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
#     ./tools/cloud_repetition/run_pilote.sh --etapes=menus,local --sortie=/chemin/absolu
# HOME_PILOTE : le HOME du jeu (donc son user://). Neuf, le jeu part sur l'intro.
set -uo pipefail
GODOT="${GODOT:-/usr/local/bin/godot}"
GODOT_ARGS="${GODOT_ARGS:-}"
HOME_PILOTE="${HOME_PILOTE:-$HOME}"
cd "$(dirname "$0")/../.."
# shellcheck disable=SC2086
HOME="$HOME_PILOTE" "$GODOT" $GODOT_ARGS --resolution 1920x1080 --path . \
  res://tools/cloud_repetition/pilote.tscn -- "$@"
