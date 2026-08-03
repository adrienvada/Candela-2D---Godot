extends RefCounted
class_name MatchRecord

## Résultat d'un match, structuré et archivé localement.
##
## C'est la fondation de l'envoi ELO à venir : aucune couche réseau ici, on se
## contente de produire un enregistrement complet et stable, et de l'empiler
## dans user://. Le futur envoi n'aura qu'à relire ce fichier.

const HISTORY_PATH := "user://match_history.json"

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
static func build(winner_id: int, duration: float, weapon_1: String, weapon_2: String,
		map_id: String, mode: String, format: int = Format.BO1) -> Dictionary:
	return {
		"vainqueur": winner_id,
		"egalite": winner_id == -1,
		"duree": snappedf(maxf(duration, 0.0), 0.01),
		"arme_j1": weapon_1,
		"arme_j2": weapon_2,
		"carte": map_id,
		"horodatage": Time.get_datetime_string_from_system(true, true),
		"mode": mode,
		"format": FORMAT_NAMES.get(format, "BO1"),
	}

## Ajoute un enregistrement au journal local. Retourne l'historique tel qu'il a
## été écrit, ou un tableau vide si l'écriture a échoué.
static func append_to_history(record: Dictionary, path: String = HISTORY_PATH) -> Array:
	var history := load_history(path)
	history.append(record)
	history = cap(history, HISTORY_MAX)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("MatchRecord: écriture de l'historique impossible (%s)" % path)
		return []
	file.store_string(JSON.stringify(history, "\t"))
	file.close()
	return history

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
