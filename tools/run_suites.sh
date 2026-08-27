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
#
# ⚠️ **Et il était sourd à la moitié qui compte.** Ce contrôle ne cherchait que
# `SCRIPT ERROR`. Or les `push_error()` — le CRI DU REPLI MUET, sur lequel tout
# le dépôt s'appuie pour qu'une absence se VOIE : masque de lumière manquant,
# sprite manquant, viseur manquant — ne portent pas cette mention. Le lanceur
# était donc muet exactement là où le code a choisi de crier, et « tout passe,
# sans erreur de script » ne disait rien d'un jeu qui aurait perdu toutes ses
# textures. Trouvé le 2026-08-25 en cherchant à vérifier qu'un viseur se montait
# vraiment en match : la suite était verte et ne pouvait pas répondre.
#
# ⚠️ **La chaîne n'est PAS `USER ERROR`** — c'est ce que le premier rapport
# annonçait, moi compris, et c'était faux. Mesuré : Godot imprime
# `ERROR: <message>`, mot pour mot ce qu'il imprime pour son propre bruit de fin
# de course (« 16 resources still in use at exit »). Grepper `ERROR:` ferait
# donc rougir tous les lots. La signature qui distingue un cri DÉLIBÉRÉ est la
# ligne d'origine qui le suit : `at: push_error (`.
#
# ⚠️ **Ce que la garde n'entend PAS : `printerr()`.** Il n'imprime aucun préfixe
# — pas même `ERROR:` — juste le texte nu, donc rien ne le distingue d'un
# `print()`. Un cri passé par là restera muet. Mesuré le 2026-08-25 : **une
# seule occurrence** dans tout le code de production à la racine
# (`network_manager.gd`), le motif « repli muet » passant partout ailleurs par
# `push_error`. La garde couvre donc ce qu'elle doit couvrir — mais si un second
# `printerr` apparaît, personne ne l'entendra.
#
# ## Les cris VOULUS : une égalité déclarée, pas une interdiction
#
# ⚠️ **Une garde qui exigerait zéro cri rendrait le repli bruyant intestable.**
# `test_vision` construit exprès une arme dont le cookie n'existe pas, pour
# vérifier que le jeu CRIE au lieu de retomber en silence ; ses quatre
# `push_error` sont la preuve que le test réussit. Interdire tout cri, ce serait
# interdire d'éprouver le motif que le dépôt s'impose partout.
#
# Une suite déclare donc ses cris attendus en imprimant `CRIS ATTENDUS: <n>` ;
# sans déclaration, la tolérance est **zéro**. Le lanceur échoue si le compte
# **diffère** — et cette égalité vaut mieux qu'un plafond : elle attrape aussi
# le cas inverse, un test de repli qui CESSERAIT de crier parce qu'un
# `push_error` a été remplacé par un `return` silencieux. Même forme que
# l'égalité exigée de `test_torches.gd`.
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
#   • `--rapide` pendant qu'on itère — les 46 suites headless, ~1 min ;
#   • le lot complet **avant de commiter**, comme l'exige `CLAUDE.md`.
RAPIDE=0
if [ "${1:-}" = "--rapide" ]; then RAPIDE=1; fi
DEBUT=$SECONDS

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SUITES=(test_carte_appareil test_map_codec test_map_geometry test_arena_build test_editor_tools
	test_icones_editeur
        test_match_format test_pause_menu test_menu_hub test_audio_settings
        test_match_history_view test_effect_policy test_screen_leaderboard
        test_screen_profile test_screen_historique test_arsenal test_matchmaking test_screen_matchmaking test_screen_audio
        test_screen_calibration test_match_banner test_carte_partagee test_rejeu_journal test_pseudo test_protocole
        test_vitrine_menus test_audit_menus test_pool_sfx test_musique test_oreille test_ecran_de_fin test_serie_de_session test_vision test_eblouissement test_brouillage test_rejeu test_releve_balistique test_curseur_systeme test_banc test_rendu_racine test_prediction_tir
        test_mise_a_jour test_charte test_habillage test_bandeau_fatal test_autoloads test_torches test_lumieres test_viseur test_marche test_sprites
        test_dosage_audio)

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
# Scénarios qui n'ont pas pu tourner (port occupé). Comptés à part : une mesure
# qui n'a pas eu lieu n'est pas une mesure ratée.
reportes=0
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
    printf '%s\n' "$sortie" | grep -E 'SCRIPT ERROR|Parse Error|at: push_error \(' | head -4
    fail=1
    return
  fi
  local erreurs
  erreurs="$(printf '%s\n' "$sortie" | grep -c 'SCRIPT ERROR' || true)"
  # Le cri du repli muet — voir l'en-tête pour la signature, et pourquoi ce
  # n'est surtout pas `ERROR:`.
  local cris attendus
  cris="$(printf '%s\n' "$sortie" | grep -c 'at: push_error (' || true)"
  # Les cris que la suite déclare attendre — voir l'en-tête. `tail -1` : si une
  # suite déclarait deux fois, la dernière fait foi plutôt qu'un cumul muet.
  attendus="$(printf '%s\n' "$sortie" \
    | sed -n 's/^CRIS ATTENDUS: *\([0-9][0-9]*\).*/\1/p' | tail -1)"
  attendus="${attendus:-0}"
  if [ "$code" -ne 0 ]; then
    printf '%-28s ÉCHEC (code %d)\n' "$nom" "$code"; fail=1
  elif [ "$erreurs" -ne 0 ]; then
    printf '%-28s ÉCHEC — %s erreur(s) de script malgré un code 0\n' "$nom" "$erreurs"
    printf '%s\n' "$sortie" | grep -A2 'SCRIPT ERROR' | head -12
    fail=1
  elif [ "$cris" -ne "$attendus" ]; then
    printf '%-28s ÉCHEC — %s push_error(s), %s déclaré(s)\n' "$nom" "$cris" "$attendus"
    # `-B1` parce que le message est sur la ligne AVANT `at: push_error` :
    # sans lui on afficherait l'origine sans jamais dire ce qui manque.
    printf '%s\n' "$sortie" | grep -B1 -A1 'at: push_error (' | head -12
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

# L'éblouissement dans un vrai match — le CÂBLAGE, pas le modèle.
#
# `test_eblouissement` prouve le modèle et `test_vision` la géométrie. Le défaut
# du 2026-08-18 vivait entre les deux : montée dans un fichier, descente dans un
# autre, jamais additionnées. Les deux suites étaient vertes, la mécanique
# centrale du jeu était morte. Ce mode-ci est le seul qui l'aurait vu.
run test_eblouissement_en_jeu res://tools/test_online_match.tscn -- --eblouissement

# Le match complet à DEUX PROCESSUS, en ENet sur 127.0.0.1.
#
# Dernier trou de l'étude de robustesse du 2026-08-16 : « les transitions d'état
# en ligne ne sont couvertes que manuellement — c'est la zone la plus régressive
# d'un jeu réseau ». Elles l'étaient parce qu'un match demande deux instances.
# ENet lève l'obstacle : aucun identifiant Epic, adresse connue d'avance.
#
## Un scénario à deux instances : OK, REPORTÉ, ou ÉCHEC.
##
## **Trois issues et non deux, parce que deux mentaient.** `run_duo.sh` rend
## désormais **3** quand il refuse de démarrer — le port UDP 7777 est tenu par
## un autre lot, souvent celui d'une session voisine sur le même arbre. Ce n'est
## pas un échec : c'est une mesure qui n'a pas eu lieu.
##
## Les compter ensemble a coûté quatre diagnostics à trois sessions le
## 2026-08-25. Le lanceur annonçait « au moins une suite a échoué », quelqu'un
## lisait la queue de sortie, et l'on partait chercher une régression de netcode
## — puis une panne de caméra — pendant que la vraie cause était un Godot
## orphelin qui tenait le port. **Un résumé qui gonfle un compte d'échecs est
## aussi trompeur qu'une erreur qui ment sur sa cause.**
##
## REPORTÉ ne met PAS `fail` à 1 : le lot reste vert, et sa dernière ligne dit
## combien de scénarios n'ont pas pu tourner.
duo() {
  local nom="$1"; shift
  if [ "$RAPIDE" -eq 1 ]; then return 0; fi
  ./tools/run_duo.sh "$@"
  local code=$?
  if [ "$code" -eq 0 ]; then
    printf '%-28s OK\n' "$nom"
  elif [ "$code" -eq 3 ]; then
    printf '%-28s REPORTÉ (port occupé, pas une panne)\n' "$nom"
    reportes=$((reportes + 1))
  else
    printf '%-28s ÉCHEC\n' "$nom"; fail=1
  fi
}

# Il coûte une minute environ, plus que toutes les autres réunies. C'est le prix
# d'une couverture sur la zone la plus régressive, et il se paie une fois par
# commit plutôt qu'une manche entière à la main.
duo duo_enet

# Famille 3 de la checklist : l'adversaire disparaît pendant le 3-2-1.
#
# La transition la plus régressive du jeu, vérifiée jusqu'ici en fermant une
# fenêtre à la main au bon moment. Le piège qu'elle protège est nommé dans
# `game_state.gd` : un décompte laissé figé cloue l'hôte sur place, sans message
# et sans pouvoir bouger. C'est le pire état atteignable, et le seul qu'aucune
# erreur ne signale.
duo duo_coupure --coupure

# Famille 1 : la pause en ligne ne gèle rien.
#
# Deux propriétés OPPOSÉES, et c'est leur combinaison qui fait la règle : le
# monde continue **et** celui qui navigue cesse d'agir. Vérifier l'une sans
# l'autre laisserait passer les deux défauts qui comptent — une pause qui gèle
# le match pour les deux, ou un joueur qui court encore pendant qu'il lit son
# menu. La pause ne doit pas être une invincibilité gratuite.
duo duo_pause --pause

# Famille 2 : ce que l'adversaire fait pendant votre killcam.
#
# Deux exigences opposées à nouveau : pendant le ralenti son intention est
# RETENUE et non appliquée — rien ne bouge chez vous, aucune manche ne démarre
# seule — mais à la sortie elle n'est pas PERDUE. Un changement d'arme appliqué
# au milieu d'un ralenti couperait la killcam de celui qui regarde encore.
duo duo_killcam --killcam

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
duo duo_ralenti --ralenti

# Famille 6 : les deux martèlent « prêt » — une seule manche doit démarrer.
#
# Cette famille paraissait intestable : elle décrit un martèlement pendant des
# transitions, donc des fenêtres de quelques dixièmes. Mais sa propriété n'est
# pas une fenêtre, c'est un COMPTE — et un compte est stable quel que soit le
# tempo. C'est le principe de placement appliqué : chercher l'observable stable
# plutôt que le moment.
duo duo_spam --spam

# Familles 4.1 et 4.2 : l'adversaire meurt, quitte pendant la killcam, revient.
#
# ⚠️ **Ces deux-là ont manqué au lot pendant une semaine, et l'absence s'est
# refermée sur elle-même** : le banc avait été sorti du lanceur parce qu'il était
# rouge, et il est resté rouge dans la feuille de route parce que personne ne le
# relançait. Il était vert depuis le matin du 2026-08-19. **Un banc qu'on retire
# du lot parce qu'il rougit cesse d'être un banc : il devient une phrase.**
#
# Deux scénarios et non un, parce que l'INSTANT du retour est tout le sujet : la
# 4.1 le veut pendant la killcam de l'hôte, la 4.2 sur son écran de fin. Un seul
# banc les confondait — et passait sur la seconde en croyant juger la première.
#
# Chacun peut rendre REPORTÉ (code 3) : le placement du retour dépend du tempo de
# la machine, et un banc qui rougit sous la charge est un faux rouge, donc un
# banc qu'on finit par débrancher.
duo duo_reconnexion --reconnexion
duo duo_reconnexion_tardive --reconnexion-tardive

# --- Aucun asset livré ne vit hors du dépôt ---------------------------------
#
# ⚠️ **Ce contrôle est en bash et pas en GDScript, et c'est la raison d'être du
# placement.** La question n'est pas « le fichier est-il sur le disque ? » — les
# bancs Godot répondent déjà à celle-là, et elle a répondu OUI le 2026-08-26
# pendant que quatorze icônes livrées n'existaient QUE sur le poste d'Adrien, le
# jour même où un incident effaçait sa session. La question est « git le
# connaît-il ? », et seul git peut y répondre.
#
# Ce que ça attrape : un asset déposé dans `assets/` et jamais ajouté. Il se voit
# à l'écran, tous les bancs sont verts, et il disparaît avec la machine.
#
# ⚠️ **`assets/` en entier, et surtout PAS une liste de sous-dossiers.** Le
# premier jet en nommait trois — `ui`, `audio`, `maps` — sur les quatorze que le
# dépôt porte. Les onze autres, dont `sprites/`, n'étaient pas surveillés : les
# trente-deux images de la démarche, cuites le 2026-08-25, seraient restées
# invisibles à la garde écrite pour les trouver. **Une énumération partielle se
# lit comme une liste complète** — c'est exactement la faute que ce contrôle
# existe pour attraper, commise dans le contrôle lui-même. Relevé par la session
# DA2 le 2026-08-27.
#
# Les planches sources non retenues restent muettes : `--exclude-standard` honore
# les `.gitignore` de `assets/sources/`, et c'est voulu — leur doctrine les exclut
# nommément. Un fichier ignoré est un fichier dont l'absence a été DÉCIDÉE.
hors_depot=$(git ls-files --others --exclude-standard -- assets 2>/dev/null | wc -l | tr -d ' ')
if [ "${hors_depot:-0}" -ne 0 ]; then
  echo "--- ${hors_depot} asset(s) présent(s) mais HORS DU DÉPÔT ---"
  git ls-files --others --exclude-standard -- assets | sed 's/^/    /'
  echo "    Ils s'affichent, les bancs sont verts, et ils meurent avec la machine."
  echo "    git add les fichiers ci-dessus, ou explique leur exclusion dans un .gitignore."
  fail=1
fi

DUREE=$((SECONDS - DEBUT))
if [ "$fail" -ne 0 ]; then
  echo "--- au moins une suite a échoué (${DUREE}s) ---"; exit 1
fi
if [ "$RAPIDE" -eq 1 ]; then
  echo "--- suites headless vertes en ${DUREE}s — SCÉNARIOS À DEUX INSTANCES NON JOUÉS ---"
  echo "    (relancer sans --rapide avant de commiter)"
elif [ "$reportes" -ne 0 ]; then
  # **Vert, mais incomplet — et il faut que la DERNIÈRE ligne le dise.** C'est
  # elle qu'on lit ; un « tout passe » sur un lot amputé de ses scénarios réseau
  # ferait commiter du netcode que personne n'a exercé.
  echo "--- tout passe, MAIS ${reportes} scénario(s) à deux instances REPORTÉ(S) (${DUREE}s) ---"
  echo "    Port 7777 occupé : ce n'est pas une panne, c'est une mesure qui n'a pas eu lieu."
  echo "    Relancer quand le champ est libre :  lsof -nP -iUDP:7777"
else
  echo "--- tout passe, sans erreur de script (${DUREE}s) ---"
fi
