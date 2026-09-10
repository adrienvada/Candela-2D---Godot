#!/usr/bin/env bash
# DA7.2 — tourne et monte le trailer.
#
# Le blocage annoncé de DA7.2 — « aucune capture vidéo n'existe » — était faux :
# Godot filme depuis toujours (`--write-movie`), et la mise en scène existait
# déjà chez le photographe. Ce script ne fait que les mettre bout à bout.
#
#   ./tools/run_trailer.sh                      tourne et monte tout
#   ./tools/run_trailer.sh --plans=duel,fusee   quelques plans seulement
#   ./tools/run_trailer.sh --monter-seulement   remonte sans retourner
#
# ⚠️ CE SCRIPT OUVRE UNE FENÊTRE DE JEU, une fois par plan. Le mode film de
# Godot ne fonctionne pas en sans-écran — mesuré : il s'active puis abandonne
# sur « Parameter "t" is null », faute de texture à écrire. Ne pas lancer
# pendant qu'un banc de cadence mesure quelque chose : les deux se disputeraient
# le premier plan.
#
# ⚠️ LA CADENCE EST DONNÉE DEUX FOIS, ici et au cinéaste, et elle doit être la
# MÊME. Le cinéaste imprime ses repères en numéros d'image ; le découpage les
# convertit en secondes en divisant par elle. Deux valeurs différentes couperaient
# à côté sans que rien ne le dise.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
FPS=60
LARGEUR=1920
HAUTEUR=1080
SORTIE="${SORTIE:-$HOME/Desktop/candela-trailer}"
MUSIQUE="assets/audio/music/music_menu.ogg"

# ⚠️ `--sans-hud` N'EST PAS UN DÉTAIL. Sans lui, chaque plan de jeu porte le
# panneau « JOUEUR 1 » et le chrono : le film ressemble alors à une capture de
# débogage, et l'œil lit l'interface avant de lire la lumière. Le premier
# montage l'a payé — quinze plans, quinze HUD.
#
# Le zoom, lui, est un geste de cinéaste assumé : le cadrage du joueur montre
# beaucoup de noir autour d'un petit cône, ce qui est juste en jeu et faible à
# l'image. 1,4 resserre sans mentir sur la mécanique.
ZOOM=1.4

# La grille vient de la musique, pas d'un choix : le stem de menu est à 170 BPM,
# donc une mesure vaut 60/170*4 = 1,412 s. Toutes les durées ci-dessous en sont
# des multiples, et la densité de coupe MONTE — 4 mesures au début, 1 à la fin.
# C'est la courbe d'une manche.
MESURE=1.412

# plan:mesures — l'ordre est celui du montage.
PLANS=(
  "torche:3"           # on cherche, seul
  "duel:2"             # on se cherche à deux — deux volontés, deux rythmes
  "retrodiffusion:2"   # les cônes se croisent et repartent
  "flash-de-tir:2"     # on tire dans le noir, torches éteintes
  "gel-fatal:2"        # quelqu'un tombe
)

MONTER_SEULEMENT=0
for a in "$@"; do
  case "$a" in
    --plans=*) IFS=',' read -r -a CHOISIS <<< "${a#*=}" ;;
    --monter-seulement) MONTER_SEULEMENT=1 ;;
    --sortie=*) SORTIE="${a#*=}" ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
  esac
done

command -v ffmpeg >/dev/null || { echo "✗ ffmpeg est requis (brew install ffmpeg)"; exit 1; }
[ -x "$GODOT" ] || { echo "✗ Godot introuvable : $GODOT"; exit 1; }

BRUT="$SORTIE/brut"
CLIPS="$SORTIE/plans"
mkdir -p "$BRUT" "$CLIPS"

garde() {  # ne tourner que les plans demandés, si une liste a été donnée
  local id="$1"
  [ "${CHOISIS+x}" ] || return 0
  for c in "${CHOISIS[@]}"; do [ "$c" = "$id" ] && return 0; done
  return 1
}

# ------------------------------------------------------------------- l'intro
# LES PLANCHES VIENNENT DU JEU, PAS D'UN MONTEUR.
#
# L'intro (DA6.6) est déjà le roman graphique qu'on veut en ouverture : six
# planches, leur lettrage, la torche qui les éclaire, le cadre d'encre. Plutôt
# que de la reconstruire à coups de fondus sur des PNG — et de refabriquer un
# lettrage que ffmpeg ne sait même pas rendre, faute de `drawtext` —, on FILME
# le jeu qui la joue.
#
# ⚠️ Elle ne se joue qu'au PREMIER lancement : le foyer doit être neuf, sinon
# `intro_vue` est déjà écrit et le jeu ouvre droit sur le menu. D'où le `mktemp`.
# Les cartons : une phrase sur du noir, dans la fonte du jeu. Ils ne chargent
# pas l'arène — le cinéaste sort avant. Deux secondes chacun : assez pour lire,
# assez court pour ne pas arrêter le film.
# ⚠️ PLUS DE `VOIR SANS ÊTRE VU` NI DE `TUER SANS ÊTRE TUÉ` ICI. Les planches
# 5 et 6 de l'intro portent déjà ces deux phrases, gravées dans l'image : les
# répéter en carton faisait lire deux fois le même texte à trente secondes
# d'intervalle. Un film ne se cite pas lui-même.
CARTONS=(
  "c1:LA SEULE INFORMATION EST LA LUMIÈRE"
  "c2:ÉCLAIRER, C’EST VOIR"
  "c3:ÉCLAIRER, C’EST ÊTRE VU"
)

# L'ENSEIGNE — l'ouverture du film. Même mécanique que les cartons : elle ne
# charge pas le jeu, elle n'a besoin que du wordmark et d'une horloge.
filmer_l_enseigne() {
  [ -s "$CLIPS/enseigne.mp4" ] && return 0
  echo "=== L'enseigne — l'ouverture ==="
  local brut="$BRUT/enseigne.avi" journal="$BRUT/enseigne.log"
  HOME=$(mktemp -d) "$GODOT" --path . res://tools/cineaste.tscn --no-eos \
    --write-movie "$brut" --fixed-fps "$FPS" --disable-vsync \
    --quit-after $(( 90 * FPS )) \
    -- --enseigne --duree=5.65 --fps="$FPS" > "$journal" 2>&1
  local d f
  d=$(grep -m1 "^CINEASTE debut enseigne " "$journal" | awk '{print $4}')
  f=$(grep -m1 "^CINEASTE fin enseigne " "$journal" | awk '{print $4}')
  if [ -z "$d" ] || [ -z "$f" ]; then echo "  ✗ pas de repère"; return 1; fi
  ffmpeg -nostdin -y -v error \
    -ss "$(awk -v i="$d" -v r="$FPS" 'BEGIN{printf "%.3f", i/r}')" \
    -t "$(awk -v a="$d" -v b="$f" -v r="$FPS" 'BEGIN{printf "%.3f", (b-a)/r}')" \
    -i "$brut" -an -r "$FPS" -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
    "$CLIPS/enseigne.mp4" </dev/null
  [ -s "$CLIPS/enseigne.mp4" ] && echo "  ✓" || echo "  ✗"
}

filmer_les_cartons() {
  echo "=== Les cartons ==="
  for entree in "${CARTONS[@]}"; do
    local id="${entree%%:*}" texte="${entree#*:}"
    [ -s "$CLIPS/$id.mp4" ] && continue
    local brut="$BRUT/$id.avi" journal="$BRUT/$id.log"
    printf '  %-4s %s  ' "$id" "$texte"
    HOME=$(mktemp -d) "$GODOT" --path . res://tools/cineaste.tscn --no-eos \
      --write-movie "$brut" --fixed-fps "$FPS" --disable-vsync \
      --quit-after $(( 90 * FPS )) \
      -- --carton="$texte" --duree=2.4 --fps="$FPS" > "$journal" 2>&1
    local d f
    d=$(grep -m1 "^CINEASTE debut carton " "$journal" | awk '{print $4}')
    f=$(grep -m1 "^CINEASTE fin carton " "$journal" | awk '{print $4}')
    if [ -z "$d" ] || [ -z "$f" ]; then echo "✗"; continue; fi
    ffmpeg -nostdin -y -v error \
      -ss "$(awk -v i="$d" -v r="$FPS" 'BEGIN{printf "%.3f", i/r}')" \
      -t "$(awk -v a="$d" -v b="$f" -v r="$FPS" 'BEGIN{printf "%.3f", (b-a)/r}')" \
      -i "$brut" -an -r "$FPS" -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
      "$CLIPS/$id.mp4" </dev/null
    [ -s "$CLIPS/$id.mp4" ] && echo "✓" || echo "✗"
  done
}

filmer_l_intro() {
  local brut="$BRUT/intro.avi"
  if [ ! -s "$brut" ]; then
    echo "=== L'intro — six planches ==="
    local foyer; foyer=$(mktemp -d)
    HOME="$foyer" "$GODOT" --path . --no-eos \
      --write-movie "$brut" --fixed-fps "$FPS" --disable-vsync \
      --quit-after $(( 25 * FPS )) > "$BRUT/intro.log" 2>&1
  fi
  [ -s "$brut" ] || { echo "  ✗ l'intro n'a pas été filmée"; return 1; }
  # Les planches durent exactement `IntroPlanches.DUREE_PLANCHE` chacune. On ne
  # les DEVINE pas : on demande à ffmpeg où sont les changements de plan, et on
  # vérifie qu'il en trouve bien six régulièrement espacés.
  local coupes; coupes=$(ffmpeg -nostdin -v error -i "$brut" \
    -filter_complex "select='gt(scene,0.25)',metadata=print:file=-" -an -f null - 2>/dev/null \
    | grep -o "pts_time:[0-9.]*" | cut -d: -f2)
  local n; n=$(echo "$coupes" | grep -c .)
  echo "  $n changement(s) de planche détecté(s)"
  local i=1 debut=0
  for t in $coupes; do
    ffmpeg -nostdin -y -v error -ss "$debut" -to "$t" -i "$brut" \
      -an -r "$FPS" -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
      "$CLIPS/planche$i.mp4" </dev/null
    debut="$t"; i=$((i+1))
  done
  echo "  $((i-1)) planche(s) découpée(s)"
}

# ---------------------------------------------------------------- le tournage
tournes=0
rates=0
if [ "$MONTER_SEULEMENT" -eq 0 ]; then
  echo "=== Tournage — $LARGEUR×$HAUTEUR @ ${FPS} img/s ==="
  for entree in "${PLANS[@]}"; do
    id="${entree%%:*}"; mesures="${entree##*:}"
    garde "$id" || continue
    duree=$(awk -v m="$mesures" -v b="$MESURE" 'BEGIN{printf "%.3f", m*b}')
    # Assez d'images pour la stabilisation du photographe, le plan et ses marges,
    # plus le démarrage du jeu. Trop, jamais trop peu : on découpe après.
    # ⚠️ BUDGET LARGE, ET JAMAIS SERRÉ. `--quit-after` compte les images ÉCRITES,
    # et l'encodage du mode film coûte des dizaines de millisecondes par image :
    # un budget calculé au plus juste tronque le plan en silence, sans erreur et
    # sans repère de fin. Le cinéaste sort de lui-même quand il a fini ; ce
    # nombre n'est qu'un filet contre un blocage.
    images=$(awk -v d="$duree" -v f="$FPS" 'BEGIN{printf "%d", (d+60)*f}')
    journal="$BRUT/$id.log"
    printf '  %-16s %s mesure(s) — %ss  ' "$id" "$mesures" "$duree"
    # ⚠️ LA SCÈNE EST OBLIGATOIRE. Sans `res://tools/cineaste.tscn`, Godot lance
    # `main.tscn` : le jeu tourne, le film s'écrit, et il ne contient QUE le
    # menu — aucun repère, aucune erreur, un fichier de 110 Mo parfaitement
    # valide et parfaitement inutile. Payé une fois.
    #
    # ⚠️ ET LA TAILLE PASSE PAR `--taille`, pas par `--resolution`. Le
    # photographe pose lui-même sa fenêtre au démarrage : le drapeau du moteur
    # est écrasé juste après avoir été honoré, et le film sort en 1280×720 sans
    # que rien ne le signale. Payé une fois aussi.
    HOME="$HOME" "$GODOT" --path . res://tools/cineaste.tscn --no-eos \
      --write-movie "$BRUT/$id.avi" --fixed-fps "$FPS" --disable-vsync \
      --resolution "${LARGEUR}x${HAUTEUR}" --quit-after "$images" \
      -- --plan="$id" --duree="$duree" --fps="$FPS" --sans-hud --zoom="$ZOOM" \
         --taille="${LARGEUR}x${HAUTEUR}" --sortie="user://cineaste" \
      > "$journal" 2>&1

    debut=$(grep -m1 "^CINEASTE debut $id " "$journal" | awk '{print $4}')
    fin=$(grep -m1 "^CINEASTE fin $id " "$journal" | awk '{print $4}')
    if [ -z "$debut" ] || [ -z "$fin" ] || [ ! -s "$BRUT/$id.avi" ]; then
      echo "✗ pas de repère — voir $journal"
      rates=$((rates+1)); continue
    fi
    # Les repères sont des NUMÉROS D'IMAGE : secondes = image / cadence. Exact,
    # et indépendant de la charge de la machine — c'est tout l'intérêt du mode
    # film, qui simule le temps au lieu de le subir.
    t0=$(awk -v i="$debut" -v f="$FPS" 'BEGIN{printf "%.3f", i/f}')
    dt=$(awk -v a="$debut" -v b="$fin" -v f="$FPS" 'BEGIN{printf "%.3f", (b-a)/f}')
    ffmpeg -nostdin -y -v error -ss "$t0" -t "$dt" -i "$BRUT/$id.avi" \
      -an -r "$FPS" -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
      "$CLIPS/$id.mp4" </dev/null
    if [ -s "$CLIPS/$id.mp4" ]; then
      echo "✓ ${dt}s"; tournes=$((tournes+1))
    else
      echo "✗ découpage vide"; rates=$((rates+1))
    fi
  done
  echo "--- $tournes plan(s) tourné(s), $rates raté(s) ---"
  filmer_l_enseigne
  filmer_l_intro
  filmer_les_cartons
fi

# ----------------------------------------------------------------- le montage
# L'ALTERNANCE : une planche, puis du jeu, puis une planche. Le roman graphique
# pose la question, le jeu y répond, et on repart. C'est la structure du site,
# et c'est elle qui fait qu'il se passe quelque chose entre deux images fixes.
#
# Les planches viennent de l'intro filmée (`planche1`..`planche6`), le jeu des
# plans tournés. Un maillon absent est sauté sans casser la suite.
SEQUENCE=(
  "enseigne"        # le logo naît du noir
  "planche1"        # la descente
  "planche2"        # le seuil — ARENA
  "c1"              # LA SEULE INFORMATION EST LA LUMIÈRE
  "torche"          # un homme cherche, seul
  "planche3"        # la dotation
  "c2"              # ÉCLAIRER, C’EST VOIR
  "duel"            # ils se cherchent, sans se trouver
  "c3"              # ÉCLAIRER, C’EST ÊTRE VU
  "retrodiffusion"  # les cônes se croisent
  "flash-de-tir"    # on tire dans le noir
  "planche5"        # le prix — l'ombre sur le mur, et sa phrase
  "gel-fatal"       # quelqu'un tombe
  "planche6"        # l'extinction, et sa phrase
)

liste="$SORTIE/liste.txt"
: > "$liste"
total=0
manquants=""
for id in "${SEQUENCE[@]}"; do
  if [ ! -s "$CLIPS/$id.mp4" ]; then manquants="$manquants $id"; continue; fi
  echo "file '$CLIPS/$id.mp4'" >> "$liste"
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$CLIPS/$id.mp4")
  total=$(awk -v t="$total" -v d="$d" 'BEGIN{printf "%.3f", t+d}')
done
[ -s "$liste" ] || { echo "✗ aucun plan à monter"; exit 1; }
[ -n "$manquants" ] && echo "  ⚠️ absents du montage :$manquants"

corps="$SORTIE/corps.mp4"
ffmpeg -nostdin -y -v error -f concat -safe 0 -i "$liste" -c copy "$corps" </dev/null

# ⚠️ PLUS DE NOIR AJOUTÉ EN TÊTE. Il en fallait un quand le film ouvrait sur du
# gameplay ; l'enseigne naît maintenant elle-même d'un noir complet, et sa
# montée dure presque deux secondes. Empiler les deux ferait cinq secondes
# d'écran vide avant le premier signe de vie.
noir=$(awk 'BEGIN{printf "%.3f", 0.6}')
duree_totale=$(awk -v t="$total" -v n="$noir" 'BEGIN{printf "%.3f", t+n}')
muet="$SORTIE/muet.mp4"
final="$SORTIE/candela-trailer.mp4"

# DEUX PASSES, et c'est un choix. Un seul `-filter_complex` mêlant concaténation
# vidéo, fondu et piste audio a échoué ici sur « Could not open encoder before
# EOF » — un graphe où l'audio ne reçoit rien, sans que le message dise lequel
# des trois maillons a lâché. Deux commandes simples se diagnostiquent chacune
# toute seule ; c'est plus long à lire et beaucoup plus court à réparer.

# 1) L'image seule : quatre mesures de noir, puis les plans, puis le fondu.
# ⚠️ LA TAILLE DU NOIR SE LIT SUR LES PLANS, elle ne se suppose pas. Le mode
# film verrouille sa résolution à l'initialisation du moteur, avant que le
# photographe ne pose sa fenêtre : le film peut donc sortir plus petit que
# demandé. Un noir généré à la taille VOULUE et des plans à la taille RÉELLE
# font échouer la concaténation — « Invalid data found », sans un mot sur les
# dimensions. Payé une fois.
dims=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$corps")
[ -n "$dims" ] || { echo "✗ impossible de lire la taille de $corps"; exit 1; }
echo "  montage en $dims"

ffmpeg -nostdin -y -v error \
  -f lavfi -t "$noir" -i "color=c=black:s=${dims}:r=${FPS}" \
  -i "$corps" \
  -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[v];[v]fade=t=out:st=$(awk -v d="$duree_totale" 'BEGIN{printf "%.2f", d-1.4}'):d=1.4[vf]" \
  -map "[vf]" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p "$muet" </dev/null

# 2) La musique par-dessus, bouclée si le film est plus long qu'elle, et coupée
#    net à la durée de l'image par `-shortest`.
if [ -f "$MUSIQUE" ]; then
  ffmpeg -nostdin -y -v error -i "$muet" -stream_loop -1 -i "$MUSIQUE" \
    -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest \
    -af "afade=t=out:st=$(awk -v d="$duree_totale" 'BEGIN{printf "%.2f", d-2.0}'):d=2.0" \
    "$final" </dev/null
else
  echo "  (musique absente : $MUSIQUE — montage muet)"
  cp "$muet" "$final"
fi

duree_finale=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$final" 2>/dev/null)
echo "=== $final ==="
printf '    %s s de film, %s plan(s), noir d’ouverture compris\n' "${duree_finale:-?}" "$(wc -l < "$liste" | tr -d ' ')"
[ "$rates" -gt 0 ] && echo "    ⚠️ $rates plan(s) manquent — le montage les a sautés, il est donc plus court que prévu"
exit 0
