#!/usr/bin/env bash
# Le rappel de la publication : ce numéro de version est-il le bon ?
#
# ## Ce qu'il protège, et pourquoi un commentaire n'y suffisait pas
#
# `Protocol.accepts()` refuse **symétriquement** : dès que le fil change, la
# population se coupe en deux moitiés qui ne se voient pas. Un joueur qui a la
# version d'avant ne trouve plus personne en ligne — le jeu ne plante pas, ne
# dit rien de faux, il refuse poliment. **C'est le seul défaut de ce système qui
# ne se voit chez personne** : ni chez toi, qui tournes toujours sur le dernier
# code, ni dans les suites, qui n'ont pas de population.
#
# D'où la règle, actée avec Adrien : le **chiffre du milieu** de la version dit
# la compatibilité en ligne. Même mineure = vous pouvez jouer ensemble. Elle doit
# donc changer chaque fois que `Protocol.VERSION` change.
#
#   0.2.0 → 0.3.0   le fil a bougé : « vous ne pouvez plus jouer avec l'ancienne »
#   0.2.0 → 0.2.1   tout le reste  : « c'est mieux, mais vous pouvez rester »
#
# ## Ce qu'il ne fait pas, délibérément
#
# Il n'interdit pas de monter la mineure sans changer le fil — une refonte peut
# mériter un numéro neuf sans toucher au réseau. Un contrôle qui interdit le
# mouvement devient un carcan ; celui-ci n'interdit que le cas dangereux, la
# mineure **inchangée** alors que le fil a bougé.
#
# ## Où il tourne
#
# Ici, à la main, **avant de poser le tag** — c'est le seul moment où l'erreur
# est encore gratuite. Et dans `.github/workflows/release.yml`, en second rideau,
# où il rattrape la publication faite sans passer par ici.
#
# Il n'est PAS dans `run_suites.sh` : il a besoin de l'historique et des tags,
# que la CI de tests ne récupère pas (clone superficiel). Une suite qui échoue
# faute de données n'apprend rien à personne.
#
#   tools/verifier_publication.sh          # « puis-je publier la version actuelle ? »
#   tools/verifier_publication.sh v0.2.0   # « … sous ce tag précis ? »
set -uo pipefail

racine="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag_vise="${1:-}"

lire_version() {  # <contenu de project.godot sur stdin>
  sed -n 's/^config\/version="\(.*\)"$/\1/p'
}
lire_protocole() { # <contenu de protocol.gd sur stdin>
  sed -n 's/^const VERSION := \([0-9]*\)$/\1/p'
}

version="$(lire_version < "$racine/project.godot")"
protocole="$(lire_protocole < "$racine/protocol.gd")"
[ -n "$version" ] || { echo "config/version absent de project.godot" >&2; exit 1; }
[ -n "$protocole" ] || { echo "Protocol.VERSION introuvable" >&2; exit 1; }

echo "Version du socle : $version    Protocole : $protocole"

# Le tag, s'il est donné, doit nommer exactement la version. Deux versions qui
# portent le même nom sans être le même code ne se diagnostiquent plus à distance.
if [ -n "$tag_vise" ] && [ "$tag_vise" != "v$version" ]; then
  echo "✗ Le tag $tag_vise ne correspond pas à config/version ($version)." >&2
  echo "  Monter config/version dans project.godot, ou poser le tag v$version." >&2
  exit 1
fi

# La publication précédente, lue dans les tags — c'est le seul registre qui ne
# puisse pas se périmer, puisque c'est lui qui a produit ce qui est installé chez
# les joueurs. Un témoin recopié à la main, lui, se serait tu le jour où on aurait
# oublié de le mettre à jour, c'est-à-dire précisément le jour où il servait.
precedent=""
for t in $(git -C "$racine" tag --list 'v*' --sort=-v:refname); do
  # Seul le tag qu'on est en train de publier est écarté : s'il existe déjà un
  # tag pour la version courante et qu'on ne le publie pas maintenant, c'est
  # justement l'erreur à dire — cette version est déjà partie.
  if [ "$t" != "${tag_vise:-}" ]; then
    precedent="$t"
    break
  fi
done

if [ -z "$precedent" ]; then
  echo "✓ Aucune publication antérieure : rien à comparer, tu peux publier v$version."
  exit 0
fi

ancien_projet="$(git -C "$racine" show "$precedent:project.godot" 2>/dev/null)" || {
  echo "✗ Le tag $precedent est introuvable en local." >&2
  echo "  git fetch --tags, puis relancer." >&2
  exit 1
}
ancienne_version="$(printf '%s' "$ancien_projet" | lire_version)"
ancien_protocole="$(git -C "$racine" show "$precedent:protocol.gd" 2>/dev/null | lire_protocole)"
echo "Dernière publiée  : $ancienne_version ($precedent)   Protocole : ${ancien_protocole:-inconnu}"

# Comparaison numérique segment par segment : « 0.10.0 » est plus récent que
# « 0.9.0 », ce qu'une comparaison de chaînes rend faux — et l'erreur n'arrive
# qu'au dixième correctif, quand plus personne ne la cherche.
plus_recent() { # $1 > $2 ?
  local a b i va vb
  IFS='.' read -ra a <<< "${1%%-*}"
  IFS='.' read -ra b <<< "${2%%-*}"
  for i in 0 1 2; do
    va="${a[i]:-0}"; vb="${b[i]:-0}"
    [ "$va" -gt "$vb" ] && return 0
    [ "$va" -lt "$vb" ] && return 1
  done
  return 1
}
mineure() { local s; IFS='.' read -ra s <<< "${1%%-*}"; echo "${s[1]:-0}"; }

echec=0

if ! plus_recent "$version" "$ancienne_version"; then
  echo "✗ La version $version n'est pas plus récente que la dernière publiée ($ancienne_version)." >&2
  echo "  Les versions parties dans la nature ne se rattrapent pas : un numéro" >&2
  echo "  déjà publié ne se réutilise jamais. Monter config/version." >&2
  echec=1
fi

if [ -n "$ancien_protocole" ] && [ "$protocole" != "$ancien_protocole" ]; then
  if [ "$(mineure "$version")" = "$(mineure "$ancienne_version")" ]; then
    echo "✗ Le fil a bougé (protocole $ancien_protocole → $protocole) mais la mineure" >&2
    echo "  n'a pas changé ($ancienne_version → $version)." >&2
    echo "  Publier ainsi couperait les joueurs de l'ancienne version du jeu en" >&2
    echo "  ligne SANS que le numéro le dise, et sans que rien ne se plaigne :" >&2
    echo "  ils chercheront un adversaire qu'ils ne trouveront jamais." >&2
    echo "  Version attendue : 0.$(( $(mineure "$ancienne_version") + 1 )).0" >&2
    echec=1
  else
    echo "✓ Le fil a bougé, et la mineure aussi — les joueurs sauront qu'il faut suivre."
  fi
elif [ -n "$ancien_protocole" ]; then
  echo "✓ Le fil n'a pas bougé : l'ancienne version peut continuer à jouer en ligne."
fi

if [ "$echec" -ne 0 ]; then
  echo "--- publication refusée ---" >&2
  exit 1
fi
echo "--- tu peux publier v$version ---"
