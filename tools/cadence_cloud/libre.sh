#!/usr/bin/env bash
# Rend 0 si aucun Godot ni Xvfb ne tourne (hors le PID donné en $1, le nôtre, et ses enfants directs), et liste les
# intrus sinon. Le nom de processus (comm) d'un Godot lancé par le lien `godot` est « godot » ; lancé par le binaire,
# « Godot_v4.7-stab » (15 caractères). On regarde comm, jamais la ligne de commande (l'outil se compterait lui-même).
moi="${1:-0}"
intrus=$(ps -eo pid=,ppid=,comm=,pcpu=,etimes= | awk -v moi="$moi" '($3=="godot" || $3 ~ /^Godot_v4/ || $3=="Xvfb") && $1!=moi && $2!=moi')
if [ -z "$intrus" ]; then exit 0; fi
echo "$intrus"
exit 1
