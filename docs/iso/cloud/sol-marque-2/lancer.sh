#!/usr/bin/env bash
# Sol marqué 2 — les séances de preuve (six cartes, 45° B, vue unique et écran scindé, torches éteintes et allumées, A/B/A'),
# puis la démonstration de la cause (la Croisée passée par le Cloître, avec et sans essai, et posée directement).
# Sous Xvfb dans le cloud ; sur le Mac : ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./lancer.sh
set -u
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
ENVELOPPE="${ENVELOPPE-xvfb-run -a -s \"-screen 0 1920x1080x24\"}"
H="--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang"
lancer() {
	eval "$ENVELOPPE" "$GODOT" --fixed-fps 60 --path . res://tools/photo_sol_marque_noir.tscn -- --no-eos --led-murs-fige "$@" \
		2>&1 | grep -E "^(SCENE|CARTE|PAR|PEINTURE|PRISE)|✗|SCRIPT ERROR"
}
case "${1:-preuve}" in
preuve)
	lancer --sol-marque-essai --sortie=user://sm2/seul
	lancer $H --sol-marque-essai --sortie=user://sm2/tout
	;;
cause)
	lancer $H --sol-marque-essai --sortie=user://sm2/essai2 --cartes=map_003_la_croisee --scenes=noir
	lancer $H --temoin --sortie=user://sm2/direct_temoin --cartes=map_003_la_croisee --scenes=noir
	lancer $H --sol-marque-essai --sortie=user://sm2/par_avec --cartes=map_003_la_croisee --par=map_001_le_cloitre --scenes=noir
	lancer $H --temoin --sortie=user://sm2/par_temoin --cartes=map_003_la_croisee --par=map_001_le_cloitre --scenes=noir
	;;
esac
