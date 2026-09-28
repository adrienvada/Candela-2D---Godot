#!/usr/bin/env bash
# Le sol marqué — les lancements, puis les mesures et la planche.
#
# Dans le conteneur du cloud (Linux, Xvfb, rendu logiciel) :
#   GODOT=/usr/local/bin/godot ./docs/iso/cloud/sol-marque/lancer.sh
# Sur le Mac : ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/sol-marque/lancer.sh
#   (la fenêtre au premier plan pendant toute la séance).
#
# Deux lancements de `tools/photo_sol_marque.tscn` (~10 min chacun sous llvmpipe), chacun AVEC `--sol-marque-essai` (la
# séance bascule les marques elle-même, au même instant : A, B, A') : `seul` (l'essai seul) et `tous` (tous les essais de la
# nuit allumés — la vue d'ensemble). Puis la preuve « éteint : rien ne change au bit » (la texture cuite du décor, carte
# par carte, contre la base f4039a0 : voir `cuisson.gd`), les mesures et la planche.
set -uo pipefail
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
ENVELOPPE="${ENVELOPPE-xvfb-run -a -s \"-screen 0 1920x1080x24\"}"
TOUS="--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang"

un() {
  local nom=$1; shift
  echo "--- $nom $*"
  eval "$ENVELOPPE" "$GODOT" --fixed-fps 60 --path . res://tools/photo_sol_marque.tscn -- \
    --no-eos --led-murs-fige --sol-marque-essai --sortie=user://sol-marque/"$nom" "$@" | grep -E '^(PRISE|SCENE|  lacet|  marques)|✗'
}

# SEANCES="seul" : une seule séance ; MESURES=0 : les prises seulement.
for s in ${SEANCES:-seul tous}; do
  if [ "$s" = tous ]; then un tous $TOUS; else un "$s"; fi
done
[ "${MESURES:-1}" = 0 ] && exit 0

python3 docs/iso/cloud/sol-marque/mesurer.py
python3 docs/iso/cloud/sol-marque/planche.py
