#!/usr/bin/env bash
# Lance toutes les suites headless et échoue si l'une d'elles rate — OU si Godot
# a émis une erreur de script.
#
# Pourquoi ce second contrôle. Une `SCRIPT ERROR` n'échoue PAS un test GDScript :
# seul un `_check` incrémente le compteur. Une suite qui appelle une fonction
# supprimée continue donc d'annoncer « tous les tests passent » avec le code 0.
# Le cas s'est produit pour de vrai le 2026-08-17, sur la suite de la pause,
# après la disparition de la barre d'onglets. Grepper la sortie est le seul
# garde-fou qui ne dépende pas de la vigilance de l'auteur du test.
set -uo pipefail

# `--rapide` saute les six scénarios à DEUX INSTANCES.
#
# ⚠️ **Ce commentaire affirmait qu'ils coûtaient « l'essentiel » du temps. Mesuré :
# c'est faux.** Une suite headless prend **2,6 s** lancée seule, les 36 en font
# donc ~90 s ; les six scénarios à deux instances ~5 min. Le `--rapide` fait
# gagner ces cinq minutes, pas davantage.
#
# **Et la vraie cause des lots interminables n'est aucune des deux : c'est la
# CONTENTION.** Un lot complet a pris **61 minutes** le 2026-08-19 avec une charge
# moyenne à 10 — plusieurs sessions lançant Godot en même temps. Le même lot
# prenait 2 min 17 la veille au calme. **Un lanceur lent ne dit rien du code, il
# dit qui d'autre travaille.** Avant de découper ou d'optimiser quoi que ce soit
# ici, regarder `uptime`.
#
# **Le défaut reste le lot COMPLET, et c'est délibéré.** Baisser la barre par
# défaut l'aurait affaiblie en silence : le jour où quelqu'un ajoute un défaut de
# transition, personne ne s'apercevrait que la couverture avait été retirée. Il
# faut demander à en faire moins, jamais l'obtenir sans le savoir.
#
# Quand utiliser lequel :
#   • `--rapide` pendant qu'on itère — les 42 suites headless, ~1 min ;
#   • le lot complet **avant de commiter**, comme l'exige `CLAUDE.md`.
RAPIDE=0
if [ "${1:-}" = "--rapide" ]; then RAPIDE=1; fi
DEBUT=$SECONDS

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SUITES=(test_map_codec test_map_geometry test_arena_build test_editor_tools
        test_match_format test_pause_menu test_menu_hub test_audio_settings
        test_match_history_view test_effect_policy test_screen_leaderboard
        test_screen_profile test_screen_historique test_arsenal test_matchmaking test_screen_matchmaking test_screen_audio
        test_screen_calibration test_match_banner test_carte_partagee test_rejeu_journal test_pseudo test_protocole
        test_vitrine_menus test_audit_menus test_pool_sfx test_ecran_de_fin test_serie_de_session test_vision test_rejeu test_banc test_prediction_tir
        test_mise_a_jour test_charte test_autoloads)

# Plafond de vie d'une suite. Aucune ne dépasse quelques secondes ; ce plafond
# n'est pas là pour les lentes mais pour celles qui NE SORTENT PAS.
#
# Le cas s'est produit le 2026-08-18 : un appelant cassé a empêché
# `test_netcode.gd` de compiler, la scène a tourné sans script, et le lanceur a
# attendu **dix minutes** avant qu'on aille voir. Une suite qui pend est pire
# qu'une suite rouge — elle ne dit rien et elle bloque tout ce qui suit.
#
# macOS n'a pas `timeout`, d'où le chien de garde à la main.
PLAFOND_SUITE=${PLAFOND_SUITE:-120}

fail=0
run() {
  local nom="$1"; shift
  local sortie tmp chien code
  tmp="$(mktemp)"
  "$GODOT" --headless --path . "$@" >"$tmp" 2>&1 &
  local gpid=$!
  # `disown` puis redirection : sans eux, le shell annonce « Terminated: 15 »
  # pour CHAQUE chien de garde abattu, soit une ligne de bruit par suite — et
  # c'est exactement le genre de bavardage qui fait qu'on cesse de lire la sortie.
  ( sleep "$PLAFOND_SUITE"; kill -9 "$gpid" 2>/dev/null ) 2>/dev/null &
  chien=$!
  disown "$chien" 2>/dev/null || true
  wait "$gpid"; code=$?
  kill "$chien" 2>/dev/null
  sortie="$(cat "$tmp")"; rm -f "$tmp"
  # 137 = tué par le chien de garde (128 + SIGKILL).
  if [ "$code" -eq 137 ]; then
    printf '%-28s ÉCHEC — n'"'"'est pas sorti en %ss (bloqué)\n' "$nom" "$PLAFOND_SUITE"
    printf '%s\n' "$sortie" | grep -E 'SCRIPT ERROR|Parse Error' | head -4
    fail=1
    return
  fi
  local erreurs
  erreurs="$(printf '%s\n' "$sortie" | grep -c 'SCRIPT ERROR' || true)"
  if [ "$code" -ne 0 ]; then
    printf '%-28s ÉCHEC (code %d)\n' "$nom" "$code"; fail=1
  elif [ "$erreurs" -ne 0 ]; then
    printf '%-28s ÉCHEC — %s erreur(s) de script malgré un code 0\n' "$nom" "$erreurs"
    printf '%s\n' "$sortie" | grep -A2 'SCRIPT ERROR' | head -12
    fail=1
  else
    printf '%-28s OK\n' "$nom"
  fi
}

for t in "${SUITES[@]}"; do run "$t" --script "res://tools/$t.gd"; done
run test_netcode res://tools/test_netcode.tscn

# Le cycle de fin de match, en une seule instance et sans réseau.
#
# Ce chemin n'était couvert par AUCUNE suite, et c'est ce qui a laissé passer
# deux défauts en deux jours — dont `await RenderingServer.frame_post_draw`, qui
# n'est jamais émis en headless et suspendait la séquence de fin pour toujours.
# Invisible en jeu, puisqu'une fenêtre dessine ; visible seulement ici.
#
# Les modes `--host` / `--join` du même banc restent hors du lanceur : ils
# demandent deux processus coordonnés et une session Epic. À lancer à la main,
# protocole dans docs/PROTOCOLE_TEST_EOS.md.
run test_fin_de_match res://tools/test_online_match.tscn -- --local

# L'entraînement solitaire : une seule instance, aucun réseau. Ce qu'il protège
# avant tout, c'est que RIEN n'y soit archivé — le journal local est la source du
# rejeu vers le classement, et une ligne écrite ici polluerait un classement que
# personne ne saurait plus corriger.
run test_entrainement res://tools/test_online_match.tscn -- --training

# La fenêtre de choix d'un match apparié — dix secondes, arsenal aligné par la
# règle du miroir. Exercée en écran partagé : la mécanique est locale à
# `game_state`, et la faire dépendre de deux processus et d'Epic l'aurait rendue
# intestable en pratique, donc jamais testée.
run test_fenetre_de_choix res://tools/test_online_match.tscn -- --fenetre

# Le match complet à DEUX PROCESSUS, en ENet sur 127.0.0.1.
#
# Dernier trou de l'étude de robustesse du 2026-08-16 : « les transitions d'état
# en ligne ne sont couvertes que manuellement — c'est la zone la plus régressive
# d'un jeu réseau ». Elles l'étaient parce qu'un match demande deux instances.
# ENet lève l'obstacle : aucun identifiant Epic, adresse connue d'avance.
#
# Il coûte une minute environ, plus que toutes les autres réunies. C'est le prix
# d'une couverture sur la zone la plus régressive, et il se paie une fois par
# commit plutôt qu'une manche entière à la main.
if [ "$RAPIDE" -eq 1 ]; then :; elif ./tools/run_duo.sh; then
  printf '%-28s OK\n' "duo_enet"
else
  printf '%-28s ÉCHEC\n' "duo_enet"; fail=1
fi

# Famille 3 de la checklist : l'adversaire disparaît pendant le 3-2-1.
#
# La transition la plus régressive du jeu, vérifiée jusqu'ici en fermant une
# fenêtre à la main au bon moment. Le piège qu'elle protège est nommé dans
# `game_state.gd` : un décompte laissé figé cloue l'hôte sur place, sans message
# et sans pouvoir bouger. C'est le pire état atteignable, et le seul qu'aucune
# erreur ne signale.
if [ "$RAPIDE" -eq 1 ]; then :; elif ./tools/run_duo.sh --coupure; then
  printf '%-28s OK\n' "duo_coupure"
else
  printf '%-28s ÉCHEC\n' "duo_coupure"; fail=1
fi

# Famille 1 : la pause en ligne ne gèle rien.
#
# Deux propriétés OPPOSÉES, et c'est leur combinaison qui fait la règle : le
# monde continue **et** celui qui navigue cesse d'agir. Vérifier l'une sans
# l'autre laisserait passer les deux défauts qui comptent — une pause qui gèle
# le match pour les deux, ou un joueur qui court encore pendant qu'il lit son
# menu. La pause ne doit pas être une invincibilité gratuite.
if [ "$RAPIDE" -eq 1 ]; then :; elif ./tools/run_duo.sh --pause; then
  printf '%-28s OK\n' "duo_pause"
else
  printf '%-28s ÉCHEC\n' "duo_pause"; fail=1
fi

# Famille 2 : ce que l'adversaire fait pendant votre killcam.
#
# Deux exigences opposées à nouveau : pendant le ralenti son intention est
# RETENUE et non appliquée — rien ne bouge chez vous, aucune manche ne démarre
# seule — mais à la sortie elle n'est pas PERDUE. Un changement d'arme appliqué
# au milieu d'un ralenti couperait la killcam de celui qui regarde encore.
if [ "$RAPIDE" -eq 1 ]; then :; elif ./tools/run_duo.sh --killcam; then
  printf '%-28s OK\n' "duo_killcam"
else
  printf '%-28s ÉCHEC\n' "duo_killcam"; fail=1
fi

# Famille 5.3 : l'adversaire disparaît PENDANT le ralenti.
#
# Le croisement de deux chemins que rien n'exerçait ensemble — la perte de pair
# et la sortie de ralenti. Un `time_scale` oublié ne ralentit pas la killcam,
# il ralentit TOUT LE JEU, menus compris, et le joueur n'a aucune raison de
# relier son curseur qui rampe à une déconnexion d'il y a dix secondes.
#
# ⚠️ Ce banc couvre la remise à zéro, PAS le fait qu'un ralenti ait eu lieu
# avant : `Engine.time_scale` reste à 1,0 en headless, limite écrite dans le
# banc lui-même.
if [ "$RAPIDE" -eq 1 ]; then :; elif ./tools/run_duo.sh --ralenti; then
  printf '%-28s OK\n' "duo_ralenti"
else
  printf '%-28s ÉCHEC\n' "duo_ralenti"; fail=1
fi

# Famille 6 : les deux martèlent « prêt » — une seule manche doit démarrer.
#
# Cette famille paraissait intestable : elle décrit un martèlement pendant des
# transitions, donc des fenêtres de quelques dixièmes. Mais sa propriété n'est
# pas une fenêtre, c'est un COMPTE — et un compte est stable quel que soit le
# tempo. C'est le principe de placement appliqué : chercher l'observable stable
# plutôt que le moment.
if [ "$RAPIDE" -eq 1 ]; then :; elif ./tools/run_duo.sh --spam; then
  printf '%-28s OK\n' "duo_spam"
else
  printf '%-28s ÉCHEC\n' "duo_spam"; fail=1
fi

DUREE=$((SECONDS - DEBUT))
if [ "$fail" -ne 0 ]; then
  echo "--- au moins une suite a échoué (${DUREE}s) ---"; exit 1
fi
if [ "$RAPIDE" -eq 1 ]; then
  echo "--- suites headless vertes en ${DUREE}s — SCÉNARIOS À DEUX INSTANCES NON JOUÉS ---"
  echo "    (relancer sans --rapide avant de commiter)"
else
  echo "--- tout passe, sans erreur de script (${DUREE}s) ---"
fi
