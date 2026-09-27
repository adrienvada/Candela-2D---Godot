#!/usr/bin/env bash
# Les essais éteints, sur image — tous les lancements, puis les mesures et la planche.
#
# Dans le conteneur du cloud (Linux, Xvfb, rendu logiciel) :
#   GODOT=/usr/local/bin/godot ./docs/iso/cloud/essais/lancer.sh
# Sur le Mac : ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/essais/lancer.sh
#   (la fenêtre au premier plan pendant toute la séance, comme pour le photographe).
#
# Un lancement par état des drapeaux (~4 min chacun sous llvmpipe), puis les passes « scindé » (écran scindé, vue de J2).
# Les prises vont dans user://essais/<nom>/ ; `mesurer.py` les lit là et écrit img/, mesures.json ; `planche.py` la page.
set -uo pipefail
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
ENVELOPPE="${ENVELOPPE-xvfb-run -a -s \"-screen 0 1920x1080x24\"}"

un() {
  local nom=$1; shift
  echo "--- $nom $*"
  eval "$ENVELOPPE" "$GODOT" --fixed-fps 60 --path . res://tools/photo_essais.tscn -- \
    --no-eos --led-murs-fige --sortie=user://essais/"$nom" "$@" | grep -E '^(PRISE|SCENE|  lacet)|✗'
}

# Les témoins : trois lancements sans aucun essai. 1 et 2 disent où deux lancements diffèrent (le souffle des corps) ;
# 3 dit le niveau de ce bruit, compté comme un essai.
for t in temoin1 temoin2 temoin3; do un $t; done
un faisceau --faisceau
un mannequin --mannequin
un pochoirs --pochoirs-essai
un encre --encre-essai
un tuyaux --tuyaux-essai
un corps --corps-detaille
# Les tuyaux de près : un vrai rendu, caméra ×4,5 (trois fois le zoom du duel), comparé au même instant sans eux.
un tuyaux_pres --tuyaux-essai --zoom-photo=4.5
# L'écran scindé : la vue de J2, depuis le côté opposé (lacet B).
for t in temoin1 temoin2 temoin3; do un $t --scenes=scinde; done
un faisceau --faisceau --scenes=scinde
un mannequin --mannequin --scenes=scinde
un pochoirs --pochoirs-essai --scenes=scinde
un encre --encre-essai --scenes=scinde
un tuyaux --tuyaux-essai --scenes=scinde
un corps --corps-detaille --scenes=scinde

python3 docs/iso/cloud/essais/mesurer.py
python3 docs/iso/cloud/essais/planche.py
