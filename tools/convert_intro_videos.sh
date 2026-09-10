#!/usr/bin/env bash
# DA6.6 — convertit les rushes Veo de l'intro (assets/video/intro/*.mp4) en
# .ogv (Theora/muet), le seul format vidéo lu nativement par Godot 4.
#
# Chaque plan est rogné à la fenêtre temporelle qui reste cohérente : les
# rushes Veo dérivent souvent dans la première ou la dernière seconde
# (un objet qui se substitue à un autre, une silhouette qui apparaît puis
# disparaît). Les fenêtres ci-dessous ont été choisies à l'œil, planche par
# planche, voir docs/ROADMAP.md (DA6.6, entrée du 2026-09-10) pour le détail
# de ce qui a été écarté et pourquoi.
#
# Nécessite ffmpeg et ffmpeg2theora (`brew install ffmpeg2theora`) — ffmpeg
# seul ne sait pas encoder Theora sur ce poste (décodage seulement).

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/video/intro"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v ffmpeg2theora >/dev/null; then
	echo "ffmpeg2theora manquant : brew install ffmpeg2theora" >&2
	exit 1
fi

# fichier source | début (s) | durée (s) | inverser (1/0)
PLANS=(
	"01_descente.mp4|0.0|2.5|0"
	"02_seuil.mp4|0.0|2.0|0"
	"03_dotation.mp4|2.0|2.5|0"
	"04_allumage.mp4|0.0|2.0|0"
	"05_prix.mp4|4.0|2.5|0"
	"06_extinction.mp4|0.5|2.5|1"
)

for plan in "${PLANS[@]}"; do
	IFS='|' read -r fichier debut duree inverser <<< "$plan"
	base="${fichier%.mp4}"
	src="$SRC_DIR/$fichier"
	trim="$TMP_DIR/${base}_trim.mp4"
	sortie="$SRC_DIR/${base}.ogv"

	if [ ! -f "$src" ]; then
		echo "Absent, ignoré : $fichier" >&2
		continue
	fi

	filtre=""
	if [ "$inverser" = "1" ]; then
		filtre="-vf reverse"
	fi

	echo "== $fichier -> ${base}.ogv (début ${debut}s, durée ${duree}s, inversé=${inverser}) =="
	# shellcheck disable=SC2086
	ffmpeg -y -v error -ss "$debut" -t "$duree" -i "$src" -an $filtre "$trim"
	ffmpeg2theora --videoquality 7 --nosound -o "$sortie" "$trim" >/dev/null

	echo "   -> $(du -h "$sortie" | cut -f1)"
done

echo "Terminé. Les .mp4 sources restent dans assets/video/intro/ (hors dépôt, non versionnés)."
