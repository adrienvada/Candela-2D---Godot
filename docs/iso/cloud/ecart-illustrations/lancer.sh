#!/usr/bin/env bash
# L'écart du jeu à ses illustrations — les lancements, puis les mesures et la planche.
#
# Dans le conteneur du cloud (Linux, Xvfb, rendu logiciel) :
#   GODOT=/usr/local/bin/godot ./docs/iso/cloud/ecart-illustrations/lancer.sh
# Sur le Mac : ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/ecart-illustrations/lancer.sh
#   (la fenêtre au premier plan pendant toute la séance).
#
# Trois lancements de `tools/photo_ecart.tscn` (~8 min chacun sous llvmpipe) : le jeu par défaut, un témoin (le même, pour
# le bruit entre deux lancements), et tous les essais allumés. Les prises vont dans user://ecart/<nom>/ ;
# `mesurer.py` les lit là (ou dans $ECART_SOURCE) et écrit img/ et mesures.json ; `planche.py` écrit planche.html.
set -uo pipefail
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
ENVELOPPE="${ENVELOPPE-xvfb-run -a -s \"-screen 0 1920x1080x24\"}"
TOUS="--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang"

un() {
  local nom=$1; shift
  echo "--- $nom $*"
  eval "$ENVELOPPE" "$GODOT" --fixed-fps 60 --path . res://tools/photo_ecart.tscn -- \
    --no-eos --led-murs-fige --sortie=user://ecart/"$nom" "$@" | grep -E '^(PRISE|SCENE|  lacet)|✗'
}

un defaut
un temoin
un tous $TOUS

python3 docs/iso/cloud/ecart-illustrations/mesurer.py
python3 docs/iso/cloud/ecart-illustrations/planche.py
