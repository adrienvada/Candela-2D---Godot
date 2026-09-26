#!/usr/bin/env bash
# Le budget de rendu (session cloud, 2026-09-27) : un lancement par configuration et par lacet, sous Xvfb.
#
#   ./tools/cloud_budget/run_budget.sh <dossier_de_sortie> <nom>=<drapeaux> [<nom>=<drapeaux> …]
#
# Exemple :
#   ./tools/cloud_budget/run_budget.sh /tmp/budget "defaut=" "corps=--corps-detaille" "tous=--corps-detaille --tuyaux-essai"
#
# Variables : GODOT (binaire, défaut `godot`), PROJET (dossier du projet, défaut : celui de ce script), LACETS (défaut
# « 0 45 »), SCENES (défaut « cartes,pompe »). Chaque lancement écrit <sortie>/<nom>_l<lacet>.log ; les lignes `BUDGET`
# s'y lisent par `synthese.py`. Aucun chiffre de cadence : sous llvmpipe le temps ne vaut rien, seuls les comptes valent.
set -u
SORTIE="${1:?dossier de sortie}"
shift
GODOT="${GODOT:-godot}"
PROJET="${PROJET:-$(cd "$(dirname "$0")/../.." && pwd)}"
LACETS="${LACETS:-0 45}"
SCENES="${SCENES:-cartes,pompe}"
mkdir -p "$SORTIE"
for paire in "$@"; do
	nom="${paire%%=*}"
	drapeaux="${paire#*=}"
	for lacet in $LACETS; do
		journal="$SORTIE/${nom}_l${lacet}.log"
		echo "→ $nom, lacet $lacet : $drapeaux"
		# shellcheck disable=SC2086
		xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --path "$PROJET" \
			res://tools/cloud_budget/budget.tscn -- --no-eos --lacet="$lacet" --config="$nom" --scenes="$SCENES" \
			$drapeaux > "$journal" 2>&1
		code=$?
		n=$(grep -c '^BUDGET' "$journal")
		echo "   code $code, $n relevés → $journal"
	done
done
