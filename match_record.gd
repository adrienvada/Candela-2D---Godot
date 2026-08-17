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
const SCHEMA_VERSION := 3

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
		outcome: String = "") -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"forfait": forfeit,
		"vainqueur": winner_id,
		"egalite": winner_id == -1,
		"duree": snappedf(maxf(duration, 0.0), 0.01),
		"arme_j1": weapon_1,
		"arme_j2": weapon_2,
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
	}

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
