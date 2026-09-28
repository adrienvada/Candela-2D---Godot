#!/usr/bin/env bash
# Le jumeau par le demi-tour — les deux séances de prise (avant, après), puis les mesures et la planche.
#
# Dans le conteneur du cloud (Linux, Xvfb, rendu logiciel) :
#   GODOT=/usr/local/bin/godot ./docs/iso/cloud/decor-demi-tour/lancer.sh
# Sur le Mac : ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/decor-demi-tour/lancer.sh
#   (la fenêtre au premier plan pendant toute la séance ; DT_SOURCE vers le user:// du Mac pour mesurer.py).
#
# « avant » : un arbre de travail détaché à 8ad6495 (la base : ecart-illustrations + sol-marque + murs-meubles fusionnés),
# où l'on copie l'outil de prise ; « après » : cette branche. Chaque séance AVEC les trois drapeaux (l'outil bascule le décor
# lui-même, au même instant : A, B, A').
set -uo pipefail
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
ENVELOPPE="${ENVELOPPE-xvfb-run -a -s \"-screen 0 1920x1080x24\"}"
AVANT="${AVANT:-/tmp/demi-tour-avant}"
DRAPEAUX="--no-eos --led-murs-fige --pochoirs-essai --sol-marque-essai --tuyaux-essai"

un() {
  local dossier=$1 nom=$2
  echo "--- $nom ($dossier)"
  (cd "$dossier" && eval "$ENVELOPPE" "$GODOT" --fixed-fps 60 --path . res://tools/photo_demi_tour.tscn -- \
    $DRAPEAUX --sortie=user://demi-tour/"$nom") | grep -E '^(PRISE|SCENE|  lacets|  pochoirs|  tuyaux)|✗'
}

if [ ! -d "$AVANT" ]; then
  git worktree add --detach "$AVANT" 8ad6495
  cp tools/photo_demi_tour.gd tools/photo_demi_tour.gd.uid tools/photo_demi_tour.tscn "$AVANT/tools/"
  (cd "$AVANT" && "$GODOT" --headless --path . --import >/dev/null 2>&1)
fi
un "$AVANT" avant
un . apres
python3 docs/iso/cloud/decor-demi-tour/mesurer.py
