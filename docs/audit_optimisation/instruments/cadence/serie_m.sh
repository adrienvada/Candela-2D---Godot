#!/usr/bin/env bash
# UNE SÉRIE de prises (audit M) : copie de tools/cadence_cloud/serie.sh appelant prise_m.sh. Plan : « étiquette|arbre|drapeaux ».
# Une prise refusée par la porte ou par analyse.py est refaite, deux fois au plus ; verdict.py ne compte que la dernière de chaque rang.
dir="$(cd "$(dirname "$0")" && pwd)"
plan="$1"; sortie="$2"; nom="$3"
mkdir -p "$sortie"
n=0
while IFS='|' read -r etiquette arbre drapeaux; do
  [ -z "$etiquette" ] && continue
  case "$etiquette" in \#*) continue ;; esac
  n=$((n+1))
  for essai in 1 2 3; do
    base="$sortie/${nom}_$(printf '%02d' $n)_${etiquette}"
    [ "$essai" -gt 1 ] && base="${base}_r$essai"
    # shellcheck disable=SC2086
    "$dir/prise_m.sh" "$arbre" "$base" $drapeaux < /dev/null
    verdict="$(python3 "$dir/analyse.py" "$base.log")"
    echo "$verdict"
    case "$verdict" in *"✓"*) break ;; esac
  done
done < "$plan"
echo "[série $nom] finie à $(date +%H:%M:%S)"
