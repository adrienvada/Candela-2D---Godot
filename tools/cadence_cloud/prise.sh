#!/usr/bin/env bash
# UNE PRISE DU BANC DE CADENCE DANS LE CLOUD — Xvfb et rendu logiciel (Mesa llvmpipe). Chantier de l'allègement de la 0.8.0
# (2026-09-30), où ces outils ont été écrits : un verdict qui dépend d'un outil veut l'outil dans le dépôt (Pièges connus,
# 2026-09-26), pas dans un scratchpad.
#
# ⚠️ **Relative seulement.** llvmpipe n'est pas le pilote d'Apple : une prise dit si une version coûte plus qu'une autre SOUS
# MESA, jamais ce que voit le Mac. La scène est celle des séries du Mac (règle 278) : `--fusee --vue-unique --classe=pompe`.
#
# **La scène se change par `SCENE`** (OM6, chantier OMBRES, 2026-10-04) : `SCENE="--solo=8.9" prise.sh …` pose la salle 8.9 de
# l'aventure — une fusillade, J1 posté là où le plus de PNJ le voient — à la place du duel ; les drapeaux en plus (`--sans-ombres-2d`,
# `--sans-capteurs`, `--sans-halos-pnj`, `--solo-poste=<x>,<y>`…) se passent comme avant, après le préfixe de sortie. `SCENE` REMPLACE la
# scène par défaut au lieu de s'y ajouter — `--solo` refuse les drapeaux du duel (`--fusee`, `--vue-unique`, `--classe=`…). Le journal dit
# la scène qu'il a jouée (« [prise] … args= ») et `analyse.py` lit le mode dans le journal : une prise de solo se juge sur la salle
# tenue et la fusillade, pas sur la classe du pompe.
#
# ⚠️ **`--physique 8` par défaut, et c'est la condition pour que le chiffre veuille dire quelque chose.** Sous llvmpipe une
# image dure 300 à 600 ms ; à 60 pas de physique par seconde, Godot n'en joue que huit par image (`max_physics_steps_per_frame`)
# et RETIRE du temps d'image ceux qu'il saute : le banc lit alors 133,3 ms (8 × 1/60 s) quelle que soit la charge — la 0.7.1
# comme la 0.8.0, 338 images en 45 s chacune (Pièges connus, 2026-09-30). À 8 pas par seconde, le plafond passe à une seconde,
# et chaque image n'en joue que deux ou trois, comme le Mac en joue une. `PHYSIQUE=60` rend le défaut du jeu.
# Jamais `--fixed-fps` : il fausserait le temps d'image.
#
# La porte stricte (`porte.py`) refuse une prise pendant laquelle un processus ÉTRANGER a dépassé 20 % d'un cœur (le harnais
# de l'agent, `claude`, excepté et relevé à part) ; la série (`serie.sh`) la refait. Aucune prise ne part tant qu'un autre
# Godot ou Xvfb tourne (`attendre_libre.sh`) : le conteneur est partagé entre sessions.
#
# Usage : prise.sh <arbre> <préfixe de sortie> [drapeaux de banc en plus…]   (SECONDES=45, PHYSIQUE=8, SCENE par défaut : voir plus haut)
# Sorties : <préfixe>.log (le journal du banc, chaque image datée par `--seuil-lent 1`) et <préfixe>.porte.json.
dir="$(cd "$(dirname "$0")" && pwd)"
arbre="$1"; sortie="$2"; shift 2
SECONDES="${SECONDES:-45}"
PHYSIQUE="${PHYSIQUE:-8}"
# La scène : celle des séries du Mac si `SCENE` n'est pas posé (posé, même vide, il la remplace en entier).
SCENE="${SCENE---fusee --vue-unique --classe=pompe}"
# Le cache de shaders de Mesa survit d'une prise à l'autre ; il est indexé par le source des shaders (deux arbres ne s'y
# confondent pas) et n'agit que sur la chauffe. Lu AVANT que HOME ne change.
CACHE_MESA="${CACHE_MESA:-$HOME/.cache/candela_cadence_mesa}"
"$dir/attendre_libre.sh" 120 || exit 3
maison="$(mktemp -d)"
mkdir -p "$maison/.local/share/godot/app_userdata/Candela 2D" "$CACHE_MESA"
# Un foyer isolé est un joueur neuf : l'intro jouerait par-dessus le duel (Pièges connus, 2026-09-14).
printf '[video]\n\nvsync_enabled=false\nfps_cap=0\niso_lightmap="1080p"\n\n[display]\n\nintro_vue=true\n' \
  > "$maison/.local/share/godot/app_userdata/Candela 2D/settings.cfg"
debut=$(date +%s)
echo "[prise] $(date +%H:%M:%S) arbre=$arbre args=$SCENE --seconds $SECONDES --seuil-lent 1 --physique $PHYSIQUE $*" > "$sortie.log"
export MESA_SHADER_CACHE_DIR="$CACHE_MESA"
export MESA_SHADER_CACHE_MAX_SIZE=4G
# `$SCENE` sans guillemets : ce sont plusieurs drapeaux, séparés par des espaces.
# shellcheck disable=SC2086
HOME="$maison" timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path "$arbre" res://tools/bench_framerate.tscn -- \
  $SCENE --seconds "$SECONDES" --seuil-lent 1 --physique "$PHYSIQUE" "$@" >> "$sortie.log" 2>&1 &
pid=$!
python3 "$dir/porte.py" "$pid" "$sortie.porte.json" 20 2 &
porte=$!
wait "$pid"; code=$?
wait "$porte"
echo "[prise] code $code ; durée $(( $(date +%s) - debut )) s" >> "$sortie.log"
rm -rf "$maison"
exit "$code"
