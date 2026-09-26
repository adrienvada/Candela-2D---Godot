#!/usr/bin/env bash
# LA PREUVE À L'IMAGE DU MASQUE DE LA FUMÉE (ISO13, Q31) — deux lancements du plan `loupe-fusee-masque-preuve`, le bandeau LED
# figé à son SOMMET (l1) puis à son CREUX (l2), puis l'analyse (`tools/preuve_masque_fumee.py`) de chacun.
# Ce qui est prouvé par le JEU, jamais par la ligne de commande : chaque attestation est lue dans son journal (masque posé,
# vue iso, LED figées, caméra tenue, un seul repère 2D pour toutes les prises, aucune lumière 3D), chaque capture doit être
# plus récente que le début de son lancement, et une erreur de script ou de shader au journal arrête tout — une variante qui
# ne compile pas ne dessine rien et paraît gratuite (piège du 2026-09-25).
# ⚠️ Il ouvre des FENÊTRES : verrou du Mac pris par l'appelant (mkdir /tmp/candela-mac.lock), aucun Godot ouvert, et il
# s'arrête si quelqu'un est devant le Mac (navigateur, lecteur ou son au-dessus de 5 % d'un cœur — la règle du 2026-09-24).
# Réécrit dans le dépôt le 2026-09-26 : l'original vivait dans /tmp, qu'un redémarrage du Mac a vidé.
#     tools/preuve_masque_fumee.sh <dossier de sortie> [<carte des coutures : préfixe>]
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
OUT="${1:?dossier de sortie}"; COUTURES="${2:-}"
mkdir -p "$OUT"
L="$HOME/Library/Application Support/Godot/app_userdata/Candela 2D/photos/loupe"
present() {
  top -l 2 -s 2 -n 30 -o cpu -stats command,cpu 2>/dev/null | awk '
    /^COMMAND/ { n++; next }
    n==2 { cpu=$NF; sub(/%/,"",cpu); nom=$0; sub(/[ \t]+[0-9.]+%?[ \t]*$/,"",nom); l=tolower(nom)
      if (l ~ /firefox|safari|chrome|vlc|iina|quicktime|music|podcasts|^tv|usbaudiod|coreaudiod|spotify/ && cpu+0 >= 5.0) {
        printf "%s %.1f%%\n", nom, cpu; t=1 } }
    END { exit t ? 0 : 1 }'
}
[ -d /tmp/candela-mac.lock ] || { echo "✗ le verrou du Mac n'est pas pris (mkdir /tmp/candela-mac.lock)"; exit 1; }
if pgrep -x Godot > /dev/null; then echo "✗ un Godot est déjà ouvert"; exit 1; fi
echo "base : $(git log --oneline -1 | cut -c1-70) · diff : $(git diff --stat | tail -1)"
for spec in "l1:--led-murs-fige:1.00" "l2:--led-murs-fige=0:0.00"; do
  nom=${spec%%:*}; reste=${spec#*:}; led=${reste%%:*}; attendu=${reste#*:}
  if qui=$(present); then echo "✗ quelqu'un est devant le Mac ($(echo $qui | tr '\n' ' ')) : arrêt"; exit 1; fi
  touch "$OUT/$nom.debut"
  ./tools/run_photos.sh --plan=loupe-fusee-masque-preuve $led > "$OUT/$nom.txt" 2>&1
  j="$OUT/$nom.txt"
  if grep -qE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; then
    echo "✗ $nom : erreur au journal"; grep -m3 -E "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; exit 1
  fi
  grep -q "\[fumée masque\] allumé — variante FUMEE_MASQUE posée (#define FUMEE_MASQUE dans son code)" "$j" || { echo "✗ $nom : masque non attesté"; exit 1; }
  grep -q "\[iso\] vue isométrique allumée" "$j" || { echo "✗ $nom : vue iso non attestée"; exit 1; }
  grep -q "loupe-fusee-masque-preuve : bandeau LED figé à $attendu de son sommet" "$j" || { echo "✗ $nom : bandeau LED non figé à $attendu"; exit 1; }
  grep -q "loupe-fusee-masque-preuve : caméra 2D tenue" "$j" || { echo "✗ $nom : caméra 2D non tenue"; exit 1; }
  reperes=$(grep -oE "loupe-fusee-masque-preuve-(a|a1|b|a2|c|a3|a4) : .*repère 2D de J1 origine \([^)]*\)" "$j" | grep -oE "origine \([^)]*\)" | sort -u | wc -l | tr -d ' ')
  [ "$reperes" = "1" ] || { echo "✗ $nom : le repère 2D change entre les prises ($reperes valeurs)"; exit 1; }
  if grep -q "lumière 3D allumée" "$j"; then echo "✗ $nom : lumière 3D allumée"; exit 1; fi
  for e in a a1 b a2 c a3 a4 murs; do
    grep -qE "loupe-fusee-masque-preuve-$e : (fumée|faces en blanc)" "$j" || { echo "✗ $nom $e : étape non attestée"; exit 1; }
    f=$(ls -t "$L"/*"loupe-fusee-masque-preuve-$e.png" 2>/dev/null | head -1)
    if [ -z "$f" ] || [ ! "$f" -nt "$OUT/$nom.debut" ]; then echo "✗ $nom $e : aucune image de CE lancement"; exit 1; fi
    cp "$f" "$OUT/$nom-$e.png"
  done
  echo "$nom : attesté · $(grep -o 'repère 2D de J1 origine ([^)]*)' "$j" | head -1)"
done
echo "CAPTURES TERMINÉES $(TZ=Europe/Paris date +%H:%M:%S)"
verdict=0
for nom in l1 l2; do
  echo "== $nom"
  python3 tools/preuve_masque_fumee.py "$OUT" "$nom" ${COUTURES:+"$COUTURES/$nom"} || verdict=1
done
exit $verdict
