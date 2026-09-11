extends RefCounted
class_name MatchRecord

## Résultat d'un match, structuré et archivé localement.
##
## C'est la fondation de l'envoi ELO à venir : aucune couche réseau ici, on se
## contente de produire un enregistrement complet et stable, et de l'empiler
## dans user://. Le futur envoi n'aura qu'à relire ce fichier.

const HISTORY_PATH := "user://match_history.json"

## Version du schéma d'un enregistrement. À incrémenter à chaque changement de
## clé : le futur envoi ELO relira des journaux écrits par des versions
## différentes du jeu et devra savoir quelle forme il a sous les yeux.
##
## 2 — ajout de `forfait`.
## 3 — ajout de `match_id`, `classe`, `issue` et `remonte`, qui rendent le journal
##     **rejouable**. Les entrées v2 n'ont pas d'identifiant de match : elles sont
##     définitivement irrejouables, et `pending_reports()` les écarte plutôt que
##     de fabriquer un rapport que le serveur ne saurait pas apparier.
## 4 — ajout de `classe_j1` et `classe_j2` (chantier CLASSES, 2026-09-09). Le
##     journal ne disait pas QUELLE CLASSE avait été jouée : `arme_j1` porte le
##     nom de l'ARME (« Pistolet silencieux »), et depuis que dix classes se
##     partagent dix armes, ce nom ne désigne plus le joueur qu'on veut retrouver.
##     Les deux nouvelles clés portent le **slug de classe**, celui qui nomme déjà
##     le cookie, le sprite, les sons et l'icône.
##
##     ⚠️ **`classe_j1` n'a RIEN à voir avec `classe`.** La clé `classe`, arrivée
##     en v3, est un booléen qui veut dire « ce match comptait au classement ».
##     Le rapprochement est un piège de lecture, pas de code : les deux vivent
##     dans le même dictionnaire, et confondre les deux ferait remonter au
##     classement des matchs amicaux — ou l'inverse. Le nom `classe` était mal
##     choisi ; il est publié, donc il reste.
##
##     Les entrées v3 et antérieures n'ont pas ces clés : elles rendent une chaîne
##     vide, jamais un repli plausible. Un journal qui inventerait « pistolet »
##     pour un match d'avant les classes fausserait la seule statistique que ces
##     clés existent pour porter.
## 5 — ajout de `conditions` (chantier PRÊT À L'ESSAI, PE2.1, 2026-09-10) : ce
##     que la machine a coûté pendant la manche — cadence par image (médiane,
##     1 % bas, pire image, aux définitions du banc), lien, et la machine
##     elle-même. Voir `conditions_de_match.gd`. Jusqu'ici le journal disait le
##     résultat et rien des conditions : un testeur qui écrivait « ça rame »
##     n'avait rien à joindre, et tous les relevés de cadence du projet venaient
##     d'un seul poste. Un dictionnaire VIDE quand rien n'a été relevé — jamais
##     une clé absente, pour qu'un lecteur n'ait qu'une forme à connaître.
##     ⚠️ Ces conditions restent LOCALES : l'envoi au classement (`_report_to_ranking`)
##     construit son propre corps et ne les transmet pas. Les faire remonter est
##     l'étape PE2.3, qui attend un arbitrage d'Adrien sur ce qui remonte.
## 6 — ajout de `gadgets` (chantier DIX CLASSES, étape 28, lot E — PE5, 2026-09-11) :
##     ce que les gadgets ont FAIT pendant le match, par joueur — poses, morts de
##     gadget par balle ou en fin de vie, allumages, bascules du grésillement, PV
##     infligés par les braises, et morts survenues dans la fenêtre qui suit un effet
##     de gadget. Voir `telemetrie_gadgets.gd`. Pourquoi : H11 est ouvert, les dix
##     gadgets n'avaient jamais servi en match, et rien dans le journal ne disait si
##     l'un d'eux sert, ou tue, ou jamais.
##
##     Compté chez les DEUX pairs depuis les mêmes ordres : les deux archives d'un
##     match en ligne disent la même chose — sauf, à la gigue du lien près, les deux
##     compteurs de fenêtre (`morts_*_apres_effet`), que chaque pair date à
##     l'arrivée. La fenêtre et la version du bloc voyagent dedans (`fenetre_s`,
##     `version`). Pour la mine, `allumages` compte aussi les mines abattues : les
##     mines déclenchées par un passage valent **au plus** `allumages − morts_balle`
##     — un majorant, parce qu'une mine abattue meurt 1,6 s plus tard et que le match
##     archivé (ou la manche purgée) avant sa fin ne compte aucune mort pour elle
##     (revue du 2026-09-11 ; voir `telemetrie_gadgets.gd`).
##
##     ⚠️ **`gadgets` n'a RIEN à voir avec `classe` ni avec `classe_j1`** : chaque
##     côté porte le slug de son GADGET (`nappe_braises`, `gresillement`…), et aucune
##     clé du bloc ne contient « classe » — le piège de lecture de la v4.
##
##     Un dictionnaire VIDE quand rien n'a été compté, comme `conditions`. Une entrée
##     d'avant cette version n'a pas la clé : `gadgets_de()` rend alors `{}`, JAMAIS
##     des zéros — « zéro pose » est un fait, « pas compté » n'en est pas un.
##
##     En ligne, le bloc voyage DANS `conditions` (`conditions_a_envoyer()`, seule
##     fusion, appelée par l'envoi et par le rejeu du journal) : il arrive dans le
##     jsonb de PE2.3, sans migration. ⚠️ **La note de la v5 — « Ces conditions
##     restent LOCALES » — est périmée depuis PE2.3 (2026-09-10)** : les conditions
##     partent avec le rapport (`_report_to_ranking`, `RankedIdentity`). L'entrée v5
##     est de l'histoire, elle n'est pas réécrite.
const SCHEMA_VERSION := 6

## L'historique est plafonné : c'est un journal local, pas une base. Au-delà,
## les entrées les plus anciennes sont oubliées.
const HISTORY_MAX := 200

## Formats de match. Seul le BO1 est implémenté — la constante existe pour que
## des BO3/BO5 puissent s'ajouter sans toucher au reste de la chaîne.
enum Format { BO1, BO3, BO5 }

## Durée d'une manche. Décision produit : 5 minutes, un match tactique dense
## plutôt qu'une série de manches jetables.
const ROUND_DURATION := 300.0

const FORMAT_NAMES := {
	Format.BO1: "BO1",
	Format.BO3: "BO3",
	Format.BO5: "BO5",
}

## Nombre de manches gagnantes d'un format.
static func wins_needed(format: int) -> int:
	match format:
		Format.BO3: return 2
		Format.BO5: return 3
		_: return 1

## Le match est-il terminé après ces scores de manches ? En BO1, toujours.
static func is_match_over(format: int, p1_rounds: int, p2_rounds: int) -> bool:
	var needed := wins_needed(format)
	return p1_rounds >= needed or p2_rounds >= needed

## Construit l'enregistrement d'un match terminé.
##
## `winner_id` suit la convention du jeu : 0 = J1, 1 = J2, -1 = égalité (temps
## écoulé). `duration` est la durée effective, décompte de départ exclu.
##
## `forfeit` distingue une victoire gagnée d'une victoire encaissée parce que
## l'adversaire est parti. Sans ce drapeau, le classement ne pourrait pas faire
## la différence — or elle est capitale : un abandon compte, mais il ne dit rien
## du niveau des deux joueurs, et le jour où il faudra le pondérer autrement,
## c'est ce champ qui permettra de recalculer sans rejouer l'histoire.
## Les trois derniers paramètres sont ce qui rend le journal **rejouable**.
##
## `game_state.gd` promettait depuis longtemps qu'« une étape ultérieure pourra
## rejouer ce qui manque ». Elle ne le pouvait pas : l'enregistrement ne portait
## ni l'identifiant du match, ni sa nature classée, ni l'issue vue par cette
## machine — c'est-à-dire exactement les trois champs que le serveur exige. Le
## journal était un souvenir lisible par un humain, pas une source de rejeu.
##
## `outcome` est l'issue **du point de vue de cette machine** et non le vainqueur
## absolu : c'est ce que le serveur attend, chaque pair ne déclarant que son
## propre sort.
static func build(winner_id: int, duration: float, weapon_1: String, weapon_2: String,
		map_id: String, mode: String, format: int = Format.BO1,
		forfeit: bool = false, match_id: String = "", ranked: bool = false,
		outcome: String = "", class_1: String = "", class_2: String = "",
		conditions: Dictionary = {}, gadgets: Dictionary = {}) -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"forfait": forfeit,
		"vainqueur": winner_id,
		"egalite": winner_id == -1,
		"duree": snappedf(maxf(duration, 0.0), 0.01),
		"arme_j1": weapon_1,
		"arme_j2": weapon_2,
		# ⚠️ Le SLUG de classe, pas son libellé : « Le Braconnier » se traduit et
		# se renomme, `arbalete` nomme des fichiers. C'est la même règle que
		# partout ailleurs dans le dépôt, et elle a déjà coûté une leçon.
		"classe_j1": class_1,
		"classe_j2": class_2,
		"carte": map_id,
		"horodatage": Time.get_datetime_string_from_system(true, true),
		"mode": mode,
		"format": FORMAT_NAMES.get(format, "BO1"),
		"match_id": match_id,
		"classe": ranked,
		"issue": outcome,
		# Faux jusqu'à preuve du contraire, et c'est le sens sûr : un rapport
		# rejoué en trop est refusé par le serveur, un rapport jamais envoyé est
		# perdu pour toujours.
		"remonte": false,
		# Schéma 5 : les CONDITIONS de la manche (voir en tête). Copie, pour que
		# l'enregistrement ne partage pas son dictionnaire avec le releveur.
		"conditions": conditions.duplicate(true),
		# Schéma 6 : ce que les GADGETS ont fait (voir en tête). Copie profonde, pour
		# la même raison que les conditions.
		"gadgets": gadgets.duplicate(true),
	}

## Le bloc de gadgets d'une entrée, ou `{}` — JAMAIS des zéros : une entrée d'avant
## le schéma 6 n'a pas été comptée, et « zéro pose » est un fait, pas un défaut.
static func gadgets_de(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var g = (entry as Dictionary).get("gadgets", {})
	return g if g is Dictionary else {}

## Le bloc `conditions` tel qu'il part au serveur : les conditions, et la télémétrie
## des gadgets rangée DEDANS — le jsonb de la migration 20260910120000, sans nouvelle
## migration. La SEULE fusion : l'envoi (`GameState._report_to_ranking`) et le rejeu
## du journal (`RankedIdentity`) l'appellent tous deux. Sans télémétrie, le bloc
## d'avant, exactement. Une copie : ni `conditions` ni `gadgets` ne sont touchés.
static func conditions_a_envoyer(conditions: Variant, gadgets: Dictionary) -> Dictionary:
	var sortie: Dictionary = (conditions as Dictionary).duplicate(true) \
		if conditions is Dictionary else {}
	if not gadgets.is_empty():
		sortie["gadgets"] = gadgets.duplicate(true)
	return sortie

## Les matchs classés que le serveur n'a jamais accusé réception.
##
## Trois chemins les produisent aujourd'hui, tous silencieux : identité pas encore
## prête au moment du rapport, jeton Epic indisponible (la file est alors vidée),
## et trois tentatives réseau infructueuses. Dans les trois cas le match est bien
## archivé ici — il ne manque que le renvoi.
##
## Les enregistrements d'avant le schéma v3 n'ont pas d'identifiant de match : ils
## sont **définitivement** irrejouables, et le filtre les écarte sans bruit plutôt
## que de fabriquer un rapport que le serveur ne saurait pas apparier.
static func pending_reports(history: Array) -> Array:
	var out: Array = []
	for entry in history:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry
		if not bool(e.get("classe", false)):
			continue
		if String(e.get("match_id", "")).is_empty():
			continue
		if String(e.get("issue", "")).is_empty():
			continue
		if bool(e.get("remonte", false)):
			continue
		out.append(e)
	return out

## Marque un match comme remonté et réécrit le journal.
##
## Appelé aussi bien sur un accusé de réception que sur un refus définitif du
## serveur (4xx) : dans les deux cas il n'y a plus rien à tenter, et laisser
## l'enregistrement ouvert ferait rejouer indéfiniment un rapport que le serveur
## a déjà tranché.
static func mark_reported(match_id: String, path: String = HISTORY_PATH) -> bool:
	if match_id.is_empty():
		return false
	var history := load_history(path)
	var touched := false
	for entry in history:
		if entry is Dictionary and String((entry as Dictionary).get("match_id", "")) == match_id:
			(entry as Dictionary)["remonte"] = true
			touched = true
	if not touched:
		return false
	return _write_history(history, path)

## Ajoute un enregistrement au journal local. Retourne l'historique tel qu'il a
## été écrit, ou un tableau vide si l'écriture a échoué.
static func append_to_history(record: Dictionary, path: String = HISTORY_PATH) -> Array:
	var history := load_history(path)
	history.append(record)
	history = cap(history, HISTORY_MAX)
	return history if _write_history(history, path) else []

## Écriture atomique : fichier temporaire puis renommage. Un arrêt brutal en
## pleine écriture ne peut corrompre que le temporaire, jamais le journal déjà
## archivé — le jour où il sert de source de rejeu, c'est ce qui fait qu'une
## coupure de courant coûte un match et non deux cents.
static func _write_history(history: Array, path: String) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("MatchRecord: écriture de l'historique impossible (%s)" % tmp_path)
		return false
	file.store_string(JSON.stringify(history, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("MatchRecord: renommage de l'historique impossible (%s → %s)" % [tmp_path, path])
		return false
	return true

## Relit le journal. Un fichier absent ou corrompu repart d'un journal vide
## plutôt que de faire échouer une fin de match.
static func load_history(path: String = HISTORY_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		return parsed
	return []

## Horloge mm:ss, seule mise en forme du temps de match.
static func format_clock(seconds: float) -> String:
	var total := maxi(floori(seconds), 0)
	return "%02d:%02d" % [total / 60, total % 60]

## Ne garde que les `limit` entrées les plus récentes.
static func cap(history: Array, limit: int) -> Array:
	if history.size() <= limit:
		return history
	return history.slice(history.size() - limit)
