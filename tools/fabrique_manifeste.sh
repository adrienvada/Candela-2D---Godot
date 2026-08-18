#!/usr/bin/env bash
# Fabrique le manifeste de mise à jour à partir des paquets exportés.
#
# Il n'invente aucune valeur : la version vient de `project.godot`, le numéro de
# protocole de `protocol.gd`, les empreintes des fichiers eux-mêmes. C'est la
# raison d'être du script — un manifeste écrit à la main finit toujours par
# annoncer une version que le jeu n'a pas, et le jeu qui la reçoit se met à jour
# en boucle sans jamais arriver au bout.
#
#   tools/fabrique_manifeste.sh \
#       --base-url https://github.com/<compte>/<dépôt>/releases/download/v0.2.0 \
#       --notes "Ce que cette version change." \
#       --bundle macos:build/macos/Candela.zip:Candela.app \
#       --bundle windows:build/windows/Candela.zip:Candela \
#       --pck build/candela-0.2.0.pck:0.1.0:0.1.0 \
#       > manifeste.json
#
# `--bundle plateforme:fichier:racine` — `racine` est le nom de l'entrée à la
# racine de l'archive ; le jeu vérifie qu'elle s'y trouve avant de remplacer quoi
# que ce soit, faute de quoi un `.zip` mal fabriqué serait découvert au pire
# moment, après la fermeture du jeu.
#
# `--pck fichier:socle_min:socle_max` — l'intervalle de socles sur lesquels le
# correctif s'applique. Le laisser large est la seule façon de fabriquer un
# mélange que personne n'a testé : `socle_min == socle_max == la version sur
# laquelle le correctif a été construit` est le cas normal.
set -euo pipefail

racine_depot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_url=""
notes=""
declare -a bundles=()
declare -a pcks=()
verifier_tag=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base-url) base_url="$2"; shift 2 ;;
    --notes) notes="$2"; shift 2 ;;
    --bundle) bundles+=("$2"); shift 2 ;;
    --pck) pcks+=("$2"); shift 2 ;;
    --verifier-tag) verifier_tag="$2"; shift 2 ;;
    *) echo "argument inconnu : $1" >&2; exit 2 ;;
  esac
done

[ -n "$base_url" ] || { echo "--base-url est obligatoire" >&2; exit 2; }

# La version du socle, lue là où le jeu la lit lui-même.
version="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$racine_depot/project.godot")"
[ -n "$version" ] || { echo "config/version absent de project.godot" >&2; exit 1; }

# Le numéro de protocole, lu là où la poignée de main le lit. Le recopier à la
# main serait une occasion de le laisser diverger — et un manifeste qui annonce
# le mauvais protocole ferait dire au jeu « vos versions diffèrent » à des jeux
# qui s'entendent très bien, ou l'inverse.
protocole="$(sed -n 's/^const VERSION := \([0-9]*\)$/\1/p' "$racine_depot/protocol.gd")"
[ -n "$protocole" ] || { echo "Protocol.VERSION introuvable" >&2; exit 1; }

# Le rappel, même esprit que `Protocol.WIRE_WITNESS` : la mécanique n'a pas
# d'avis sur le numéro, elle refuse seulement qu'on publie sous un tag qui ne
# corresponde pas à ce que le jeu affichera. Deux versions qui portent le même
# nom sans être le même code sont indiagnosticables à distance.
if [ -n "$verifier_tag" ]; then
  attendu="v$version"
  if [ "$verifier_tag" != "$attendu" ]; then
    echo "Le tag ($verifier_tag) et config/version ($version) divergent." >&2
    echo "Montez config/version dans project.godot, ou posez le tag $attendu." >&2
    exit 1
  fi
fi

empreinte() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

octets() { wc -c < "$1" | tr -d ' '; }

paquets="[]"
for entree in "${bundles[@]:-}"; do
  [ -n "$entree" ] || continue
  IFS=':' read -r plateforme fichier racine arch <<< "$entree"
  [ -f "$fichier" ] || { echo "paquet absent : $fichier" >&2; exit 1; }
  # L'architecture par défaut se déduit de la plateforme, et le cas macOS est
  # celui qui se trompe tout seul : Godot y produit un binaire universel
  # (x86_64 + arm64). L'annoncer « x86_64 » ferait refuser le paquet par toutes
  # les machines Apple Silicon — c'est-à-dire par les Mac vendus depuis 2020 —
  # avec pour seul symptôme « aucun paquet ne correspond à cette machine ».
  # Une architecture vide veut dire « convient partout ».
  if [ -z "${arch:-}" ]; then
    case "$plateforme" in
      macos) arch="" ;;
      *) arch="x86_64" ;;
    esac
  fi
  paquets="$(jq --arg t bundle --arg p "$plateforme" --arg a "$arch" \
    --arg u "$base_url/$(basename "$fichier")" --arg s "$(empreinte "$fichier")" \
    --argjson o "$(octets "$fichier")" --arg r "$racine" \
    '. + [{type:$t, plateforme:$p, arch:$a, url:$u, sha256:$s, octets:$o, racine:$r}]' \
    <<< "$paquets")"
done

for entree in "${pcks[@]:-}"; do
  [ -n "$entree" ] || continue
  IFS=':' read -r fichier socle_min socle_max <<< "$entree"
  [ -f "$fichier" ] || { echo "correctif absent : $fichier" >&2; exit 1; }
  paquets="$(jq --arg t pck --arg p '*' \
    --arg u "$base_url/$(basename "$fichier")" --arg s "$(empreinte "$fichier")" \
    --argjson o "$(octets "$fichier")" --arg mi "$socle_min" --arg ma "$socle_max" \
    '. + [{type:$t, plateforme:$p, url:$u, sha256:$s, octets:$o, socle_min:$mi, socle_max:$ma}]' \
    <<< "$paquets")"
done

if [ "$(jq 'length' <<< "$paquets")" -eq 0 ]; then
  echo "aucun paquet : un manifeste sans paquet n'annonce rien d'installable" >&2
  exit 1
fi

jq -n --argjson f 1 --arg v "$version" --argjson pr "$protocole" \
  --arg d "$(date -u +%Y-%m-%d)" --arg n "$notes" --argjson pq "$paquets" \
  '{format:$f, version:$v, protocole:$pr, publie_le:$d, notes:$n, paquets:$pq}'
