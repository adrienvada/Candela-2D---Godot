#!/usr/bin/env bash
# LE TRI DU CLOUD, avant le Mac (session cloud « cadence-version », 2026-09-28). La règle qu'il sert :
# `docs/iso/cadence_par_version.md`, § 4. Il ne mesure AUCUN temps : il compte ce que le cloud sait compter sans chronomètre,
# et classe chaque nouveauté neutre / à surveiller / lourde (seuils et leur pourquoi : `tools/cadence/tri.py`).
#
#   Une version contre la précédente (les deux sans drapeau) :
#     tools/cadence/tri_cloud.sh <tête A> <tête B> <sortie>
#   Chaque essai contre la même tête sans lui :
#     tools/cadence/tri_cloud.sh --essais <tête> <sortie> <nom>=<drapeaux> [<nom>=<drapeaux> …]
#
# Pour chaque configuration, un lancement de l'outil Budget (`tools/cloud_budget/budget.tscn`, recopié dans l'arbre) :
# six cartes et le pompe sous une fusée, vue unique puis écran scindé, au lacet par défaut (45° B), sous Xvfb ; avec
# les captures des scènes et le GLSL que Godot donne à Mesa (MESA_SHADER_CAPTURE_PATH). Puis `tri.py` compare chaque
# configuration à la référence (A, ou la tête sans drapeau) et écrit <sortie>/TRI.md. Un TÉMOIN (la référence relancée)
# mesure le bruit : TEMOIN=0 pour s'en passer.
#
# Chaque tête vit dans son arbre de travail ($ARBRES/<hash>), préparé une fois : l'outil Budget y est copié (non suivi),
# les deux corrections du photographe pour Xvfb (76fe78f → 0c67705) appliquées si elles manquent, l'import fait. Aucun
# commit n'y est écrit. Environ 4 min par lancement sous llvmpipe ; lancer en parallèle n'accélère rien (rapport Budget).
#
# Variables : GODOT (défaut `godot`), ARBRES (défaut /tmp/candela-arbres), PLAFOND (secondes par lancement, 1800),
# TEMOIN (1), SCENES (cartes,pompe).
set -u
DEPOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DEPOT" || exit 1
GODOT="${GODOT:-godot}"
ARBRES="${ARBRES:-/tmp/candela-arbres}"
PLAFOND="${PLAFOND:-1800}"
SCENES="${SCENES:-cartes,pompe}"

resoudre() { git rev-parse --verify --quiet "$1^{commit}" || { echo "✗ tête inconnue : $1" >&2; exit 1; }; }

# Un arbre prêt pour la tête "$1" ; imprime son chemin.
preparer() {
  local h a
  h="$(resoudre "$1")"; a="$ARBRES/$(echo "$h" | cut -c1-12)"
  if [ ! -e "$a/.tri_pret" ]; then
    mkdir -p "$ARBRES"
    [ -d "$a" ] || git worktree add --detach "$a" "$h" > /dev/null 2>&1 || { echo "✗ worktree $a" >&2; exit 1; }
    mkdir -p "$a/tools/cloud_budget"
    cp "$DEPOT"/tools/cloud_budget/budget.gd "$DEPOT"/tools/cloud_budget/budget.tscn "$a/tools/cloud_budget/"
    # Les corrections du photographe sous Xvfb (fenêtre retaillée, repos en images de jeu) : sans elles, les images
    # sortent en 1280×720 et l'outil Budget hérite du photographe.
    if git cat-file -e 0c67705 2>/dev/null && git cat-file -e 76fe78f 2>/dev/null; then
      git diff 76fe78f 0c67705 -- tools/photographe.gd tools/loupe.gd tools/run_photos.sh > "$a/.photographe.patch"
      if (cd "$a" && git apply --check .photographe.patch 2>/dev/null); then
        (cd "$a" && git apply .photographe.patch) && echo "  $a : corrections du photographe appliquées" >&2
      fi
    else
      echo "⚠ 76fe78f / 0c67705 introuvables (git fetch origin claude/cloud-photographe main) : photographe tel quel" >&2
    fi
    echo "  import de $a…" >&2
    timeout "$PLAFOND" "$GODOT" --headless --path "$a" --import > "$a/.import_tri.log" 2>&1
    touch "$a/.tri_pret"
  fi
  echo "$a"
}

# Un lancement : <nom> <arbre> <drapeaux…>
lancer() {
  local nom="$1" a="$2"; shift 2
  local j="$SORTIE/journaux/$nom.log"
  if [ -s "$j" ] && grep -q "^=== fin du budget" "$j"; then echo "→ $nom : déjà fait ($j)"; return; fi
  rm -rf "$SORTIE/glsl/$nom" "$SORTIE/captures/$nom" "$XDG/godot/app_userdata/Candela 2D/shader_cache"
  mkdir -p "$SORTIE/glsl/$nom" "$SORTIE/captures/$nom" "$SORTIE/journaux"
  echo "→ $nom : $(git -C "$a" rev-parse --short=12 HEAD) $*  ($(TZ=Europe/Paris date +%H:%M))"
  { echo "tête $(git -C "$a" rev-parse HEAD) · arbre $a · drapeaux : $*"; } > "$j"
  # shellcheck disable=SC2086
  XDG_DATA_HOME="$XDG" MESA_SHADER_CAPTURE_PATH="$SORTIE/glsl/$nom" timeout "$PLAFOND" \
    xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --path "$a" res://tools/cloud_budget/budget.tscn -- \
    --no-eos --config="$nom" --scenes="$SCENES" --captures="$SORTIE/captures/$nom" "$@" >> "$j" 2>&1
  local code=$?
  echo "   code $code, $(grep -c '^BUDGET' "$j") relevés, $(ls "$SORTIE/glsl/$nom" | wc -l) programmes GLSL"
  grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error" "$j" | head -3
}

if [ "${1:-}" = "--essais" ]; then
  TETE="${2:?tête}"; SORTIE="${3:?sortie}"; shift 3
  mkdir -p "$SORTIE"; SORTIE="$(cd "$SORTIE" && pwd)"; XDG="$SORTIE/.xdg"
  ARBRE="$(preparer "$TETE")"
  lancer ref "$ARBRE"
  [ "${TEMOIN:-1}" = "1" ] && lancer temoin "$ARBRE"
  NOMS=()
  for paire in "$@"; do
    nom="${paire%%=*}"; drapeaux="${paire#*=}"
    # shellcheck disable=SC2086
    lancer "$nom" "$ARBRE" $drapeaux
    NOMS+=("$nom")
  done
  python3 "$DEPOT/tools/cadence/tri.py" "$SORTIE" ref $([ "${TEMOIN:-1}" = "1" ] && echo --temoin=temoin) "${NOMS[@]}"
else
  A="${1:?tête A}"; B="${2:?tête B}"; SORTIE="${3:?sortie}"
  mkdir -p "$SORTIE"; SORTIE="$(cd "$SORTIE" && pwd)"; XDG="$SORTIE/.xdg"
  ARBRE_A="$(preparer "$A")"; ARBRE_B="$(preparer "$B")"
  lancer A "$ARBRE_A"
  [ "${TEMOIN:-1}" = "1" ] && lancer temoin "$ARBRE_A"
  lancer B "$ARBRE_B"
  # Ce que les shaders du dépôt changent entre A et B, dit par git : lignes, lectures de texture, boucles.
  {
    echo "## Les shaders qui changent entre $(git rev-parse --short=12 "$A") et $(git rev-parse --short=12 "$B")"
    echo
    echo "| fichier | lignes + / − | texture( ajoutées | boucles (for/while) ajoutées | #define ajoutés |"
    echo "|---|---|---|---|---|"
    git diff --numstat "$A" "$B" -- '*.gdshader' '*.gdshaderinc' | while read -r plus moins f; do
      ajout="$(git diff "$A" "$B" -- "$f" | grep '^+' | grep -v '^+++')"
      printf '| `%s` | +%s / −%s | %s | %s | %s |\n' "$f" "$plus" "$moins" \
        "$(echo "$ajout" | grep -c 'texture\(Lod\)\?(\|texelFetch(')" "$(echo "$ajout" | grep -cE '\b(for|while) *\(')" \
        "$(echo "$ajout" | grep -c '#define')"
    done
    echo
    echo "Et les scripts qui les allument (défauts) : $(git diff --stat "$A" "$B" -- '*.gd' ':!tools/*' | tail -1)"
  } > "$SORTIE/shaders_git.md"
  python3 "$DEPOT/tools/cadence/tri.py" "$SORTIE" A $([ "${TEMOIN:-1}" = "1" ] && echo --temoin=temoin) B
  cat "$SORTIE/shaders_git.md"
fi
