#!/usr/bin/env bash
# UNE SÉRIE DE PRISES DANS LE CLOUD (voir `prise.sh`), dans l'ordre d'un plan : une prise par ligne,
# « étiquette|arbre|drapeaux de banc en plus » (lignes vides et `#` ignorées). Chaque prise refusée — par la porte ou par un
# contrôle d'`analyse.py` — est refaite, deux fois au plus ; `verdict.py` ne compte que la DERNIÈRE de chaque rang.
# Les journaux vont dans <dossier>/<série>_<rang>_<étiquette>[_r<essai>].log.
#
# Alterner (A B B A, ou A B C C B A) : le miroir compense une dérive régulière de la machine, pas un voisin bruyant — c'est
# le rôle de la porte.
#
# Une série de SOLO (OM6, chantier OMBRES) : la scène passe par `SCENE`, que chaque prise lit (voir `prise.sh`), et le plan ne porte
# que les drapeaux en plus. Exemple, le coût de chaque lumière de la salle 8.9 (« étiquette|arbre|drapeaux », A refait à la fin) :
#   SCENE="--solo=8.9" serie.sh plan.txt sortie solo1      avec, dans plan.txt :
#     A|/chemin/arbre|
#     B|/chemin/arbre|--sans-ombres-2d
#     C|/chemin/arbre|--sans-capteurs
#     D|/chemin/arbre|--sans-halos-pnj
#     D|/chemin/arbre|--sans-halos-pnj
#     C|/chemin/arbre|--sans-capteurs
#     B|/chemin/arbre|--sans-ombres-2d
#     A|/chemin/arbre|
# `verdict.py` compare chaque étiquette à la référence A, en cadence.
#
# `VERROU_MESURE=<fichier>` : posé (`touch`) juste avant la série, retiré juste après, quoi qu'il arrive — le signal aux
# autres sessions du conteneur qu'une série de temps tourne (protocole du 2026-09-30 : elles attendent qu'il n'existe plus
# ET qu'aucun Godot ne tourne avant de lancer les leurs).
#
# Usage : serie.sh <plan> <dossier de sortie> <nom de série>   (SECONDES, PHYSIQUE : voir `prise.sh`)
dir="$(cd "$(dirname "$0")" && pwd)"
plan="$1"; sortie="$2"; nom="$3"
mkdir -p "$sortie"
if [ -n "${VERROU_MESURE:-}" ]; then
  touch "$VERROU_MESURE"
  trap 'rm -f "$VERROU_MESURE"' EXIT
fi
n=0
while IFS='|' read -r etiquette arbre drapeaux; do
  [ -z "$etiquette" ] && continue
  case "$etiquette" in \#*) continue ;; esac
  n=$((n+1))
  for essai in 1 2 3; do
    base="$sortie/${nom}_$(printf '%02d' $n)_${etiquette}"
    [ "$essai" -gt 1 ] && base="${base}_r$essai"
    # shellcheck disable=SC2086
    "$dir/prise.sh" "$arbre" "$base" $drapeaux < /dev/null
    verdict="$(python3 "$dir/analyse.py" "$base.log")"
    echo "$verdict"
    case "$verdict" in *"✓"*) break ;; esac
  done
done < "$plan"
echo "[série $nom] finie à $(date +%H:%M:%S)"
