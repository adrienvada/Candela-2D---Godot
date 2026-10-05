#!/usr/bin/env bash
# Attend (au plus $1 minutes, sonde toutes les 20 s) qu'aucun Godot ni Xvfb ne tourne. 0 : libre ; 1 : délai dépassé.
max_min="${1:-60}"
dir="$(cd "$(dirname "$0")" && pwd)"
debut=$SECONDS
annonce=0
while true; do
  if "$dir/libre.sh" >/dev/null; then
    [ "$annonce" -eq 1 ] && echo "[attente] libre après $((SECONDS-debut)) s"
    exit 0
  fi
  if [ "$annonce" -eq 0 ]; then echo "[attente] occupé :"; "$dir/libre.sh" | sed 's/^/    /'; annonce=1; fi
  if [ $((SECONDS-debut)) -ge $((max_min*60)) ]; then echo "[attente] délai de ${max_min} min dépassé"; exit 1; fi
  sleep 20
done
