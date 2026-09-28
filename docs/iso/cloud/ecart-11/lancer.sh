#!/usr/bin/env bash
# L'écart aux illustrations, évaluation 11 — les quatre lancements, puis les mesures et la planche.
#
# Dans le conteneur du cloud (Linux, Xvfb, rendu logiciel) :
#   XDG_DATA_HOME=$PWD/.xdg GODOT=/usr/local/bin/godot ./docs/iso/cloud/ecart-11/lancer.sh
# Sur le Mac : ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/ecart-11/lancer.sh
#   (la fenêtre au premier plan pendant toute la séance).
#
# Quatre lancements de `tools/photo_ecart.tscn` (~15 min chacun sous llvmpipe) : `defaut`, `temoin` (le même, pour le
# bruit), `hier` (exactement les neuf drapeaux de l'évaluation 10) et `tout` (les neuf, plus les cinq de la nuit du 28/09).
# `SEULS="hier tout"` n'en relance qu'une partie. Les prises vont dans user://ecart11/<nom>/ ; `mesurer.py` les lit là
# (ou dans $ECART_SOURCE) ; `planche.py` écrit planche.html.
set -uo pipefail
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
ENVELOPPE="${ENVELOPPE-xvfb-run -a -s \"-screen 0 1920x1080x24\"}"
HIER="--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang"
NUIT="--lampe-claire --corps-soi-sombre --murs-meubles-essai --sol-marque-essai --fumee-masque-pochoir"
SEULS="${SEULS:-defaut temoin hier tout}"

un() {
  local nom=$1; shift
  case " $SEULS " in *" $nom "*) ;; *) return ;; esac
  echo "--- $nom $*"
  eval "$ENVELOPPE" "$GODOT" --fixed-fps 60 --path . res://tools/photo_ecart.tscn -- \
    --no-eos --led-murs-fige --sortie=user://ecart11/"$nom" "$@" | grep -E '^(PRISE|SCENE|  lacet|  ·)|✗|!'
}

un defaut
un temoin
un hier $HIER
un tout $HIER $NUIT

python3 docs/iso/cloud/ecart-11/mesurer.py
python3 docs/iso/cloud/ecart-11/planche.py
