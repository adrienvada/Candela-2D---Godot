extends RefCounted
class_name MatchHistoryView

## Le journal de matchs, rendu affichable.
##
## `MatchRecord` archive chaque match dans `user://match_history.json` et
## personne ne le relit. Cette classe comble le trou : elle rend des lignes
## prêtes à poser dans un écran, et un résumé de soirée. Sans état, sans nœud,
## sans interface — elle ne dessine rien. L'écran qui la consomme n'a donc
## jamais à connaître la forme du journal, ni à se protéger de ses accidents.
##
## Car ce fichier vit sur le disque d'un joueur : absent au premier lancement,
## tronqué par un arrêt brutal, édité à la main, ou écrit par une autre version
## du jeu. Aucun de ces cas ne rend une erreur — un journal illisible rend une
## liste vide, un enregistrement invalide est sauté, les autres survivent. Un
## écran d'historique n'est pas un endroit où planter, et une soirée de jeu ne
## se solde pas par une trace de pile.

## Dernière version de schéma que cette classe sait lire.
const READABLE_VERSION := MatchRecord.SCHEMA_VERSION

## Version prêtée à un enregistrement sans champ `version` : il date d'avant son
## introduction, donc du premier schéma.
const LEGACY_VERSION := 1

## Nombre de matchs rendus par défaut : un écran montre une page, pas 200 lignes.
const DEFAULT_LIMIT := 25

## Lire tout le journal. Toute limite ≤ 0 vaut celle-ci.
const NO_LIMIT := 0

## Au-delà de trois heures d'écart, deux matchs n'appartiennent plus à la même
## soirée. Le journal ne marque aucun début de session : la déduire du temps
## écoulé est la seule lecture possible sans changer son format.
const SESSION_GAP := 10800.0

## Issue d'un match, du point de vue de CE poste.
##
## `NO_SIDE` n'est pas un cas dégradé : en écran partagé les deux joueurs sont
## là, aucun n'est « moi », et la ligne se lit « VICTOIRE J1 ».
enum Outcome { WIN, LOSS, DRAW, NO_SIDE }

const OUTCOME_LABELS := {
	Outcome.WIN: "VICTOIRE",
	Outcome.LOSS: "DÉFAITE",
	Outcome.DRAW: "ÉGALITÉ",
}

## Libellés des modes écrits par `game_state.gd`.
const MODE_LABELS := {
	"local": "Écran partagé",
	"en_ligne_hote": "En ligne — hôte",
	"en_ligne_client": "En ligne — invité",
}

## Camp tenu par cette machine, selon le mode. Un mode absent de cette table n'a
## pas de camp local — c'est le cas de l'écran partagé, et c'est voulu.
const LOCAL_SIDE := {
	"en_ligne_hote": 0,
	"en_ligne_client": 1,
}

const PLAYER_LABELS := ["J1", "J2"]

# ---------------------------------------------------------------------------
# LECTURE DU JOURNAL
# ---------------------------------------------------------------------------

## Les matchs les plus récents, du plus récent au plus ancien.
##
## `limit` ≤ 0 rend tout le journal. Un fichier absent, illisible, ou dont le
## contenu n'est pas une liste rend un tableau vide : au premier lancement, il
## n'y a pas d'erreur à signaler, il n'y a simplement pas encore de matchs.
static func recent(limit: int = DEFAULT_LIMIT,
		path: String = MatchRecord.HISTORY_PATH) -> Array[Dictionary]:
	return lines_from(MatchRecord.load_history(path), limit)

## Même lecture, mais qui dit aussi ce qu'elle a écarté.
##
## Rend `{"lignes", "lus", "ignores", "trop_recents"}`. Les compteurs ne portent
## que sur la portion réellement parcourue : la lecture s'arrête dès que la
## limite est atteinte. Un écran honnête peut ainsi annoncer « 2 matchs écrits
## par une version plus récente » au lieu de les escamoter.
static func recent_report(limit: int = DEFAULT_LIMIT,
		path: String = MatchRecord.HISTORY_PATH) -> Dictionary:
	return report_from(MatchRecord.load_history(path), limit)

## `recent()` sans disque, pour un journal déjà en mémoire.
static func lines_from(history: Array, limit: int = DEFAULT_LIMIT) -> Array[Dictionary]:
	var lines: Array[Dictionary] = report_from(history, limit)["lignes"]
	return lines

## Le cœur de la lecture : parcourt le journal à rebours et met en forme.
##
## À rebours parce que l'ordre du journal EST la chronologie — il est écrit par
## ajouts successifs. On ne trie pas sur l'horodatage : un enregistrement dont
## la date est illisible n'aurait alors plus de place légitime, et un tri
## réordonnerait ce que l'écriture, elle, sait juste.
static func report_from(history: Array, limit: int = DEFAULT_LIMIT) -> Dictionary:
	var lines: Array[Dictionary] = []
	var scanned := 0
	var skipped := 0
	var too_new := 0
	# Le fuseau est demandé une fois pour toute la page, pas une fois par ligne.
	var offset := local_offset_minutes()

	var i := history.size() - 1
	while i >= 0:
		if limit > NO_LIMIT and lines.size() >= limit:
			break
		var entry: Variant = history[i]
		i -= 1
		scanned += 1

		if version_of(entry) > READABLE_VERSION:
			too_new += 1
			continue
		var line := row_from(entry, offset)
		if line.is_empty():
			skipped += 1
			continue
		lines.append(line)

	return {
		"lignes": lines,
		"lus": scanned,
		"ignores": skipped,
		"trop_recents": too_new,
	}

# ---------------------------------------------------------------------------
# UNE LIGNE
# ---------------------------------------------------------------------------

## Version de schéma d'un enregistrement : `LEGACY_VERSION` s'il n'en porte pas,
## `-1` si le champ existe mais n'est pas un nombre (fichier trafiqué).
static func version_of(record: Variant) -> int:
	if not (record is Dictionary):
		return -1
	var rec: Dictionary = record
	if not rec.has("version"):
		return LEGACY_VERSION
	if not _is_number(rec["version"]):
		return -1
	return _as_int(rec["version"], -1)

## Met un enregistrement en forme de ligne d'écran. Rend `{}` s'il est
## inexploitable — l'appelant saute la ligne et garde les autres.
##
## **Décision : un enregistrement dont la version dépasse `READABLE_VERSION` est
## écarté, jamais affiché « au mieux ».** Le cas arrive pour de vrai : deux
## builds partagent le même `user://`, et revenir à une version antérieure suffit
## à relire un journal écrit par la suivante. La convention du dépôt veut qu'une
## version n'AJOUTE que des clés (`2 — ajout de forfait`), mais c'est une
## convention, pas une garantie : le jour où `duree` passerait en millisecondes
## ou `vainqueur` en identifiant de joueur, une lecture optimiste afficherait des
## matchs faux avec l'aplomb des vrais. Une ligne absente se voit et se
## comprend ; une durée fausse, non. Ces enregistrements sont comptés à part par
## `report_from()` pour qu'un écran puisse le dire au lieu de les escamoter.
##
## Dans l'autre sens, une version INFÉRIEURE se lit au mieux : les clés qu'elle
## ignore prennent leur valeur neutre. Un enregistrement v1 n'a pas de `forfait`,
## et il n'y avait effectivement pas de forfait à son époque — la valeur neutre
## est ici la vérité, pas un pis-aller.
static func row_from(record: Variant,
		offset_minutes: int = local_offset_minutes()) -> Dictionary:
	var version := version_of(record)
	if version < 0 or version > READABLE_VERSION:
		return {}
	var rec: Dictionary = record

	# `vainqueur` est le seul champ dont l'absence vide la ligne de son sens :
	# une ligne d'historique dit d'abord qui a gagné. Tout le reste se dégrade en
	# valeur neutre, à l'image d'un match archivé sans arme (abandon immédiat).
	if not _is_number(rec.get("vainqueur")):
		return {}
	var winner := _as_int(rec.get("vainqueur"), -1)
	if winner < -1 or winner > 1:
		return {}

	var mode := _as_text(rec.get("mode"))
	var side := int(LOCAL_SIDE.get(mode, -1))
	var duration := maxf(_as_float(rec.get("duree"), 0.0), 0.0)
	var weapons := [_as_text(rec.get("arme_j1")), _as_text(rec.get("arme_j2"))]
	var stamp := _as_text(rec.get("horodatage"))
	var epoch := epoch_of(stamp)
	var outcome := outcome_of(winner, side)

	return {
		"issue": outcome,
		"issue_texte": outcome_label(outcome, winner),
		"forfait": rec.get("forfait") is bool and bool(rec["forfait"]),
		"vainqueur": winner,
		"moi": side,
		"duree": duration,
		"duree_texte": MatchRecord.format_clock(duration),
		"arme_j1": weapons[0],
		"arme_j2": weapons[1],
		"arme_moi": weapons[side] if side >= 0 else "",
		"arme_adverse": weapons[1 - side] if side >= 0 else "",
		"carte": _as_text(rec.get("carte")),
		"mode": mode,
		"mode_texte": mode_label(mode),
		"format": _as_text(rec.get("format")),
		"horodatage": stamp,
		"date_texte": format_epoch(epoch, offset_minutes),
		"epoch": epoch,
		"version": version,
	}

## Issue d'un match vue du camp `side` (-1 = aucun camp local).
static func outcome_of(winner: int, side: int) -> Outcome:
	if winner < 0:
		return Outcome.DRAW
	if side < 0:
		return Outcome.NO_SIDE
	return Outcome.WIN if winner == side else Outcome.LOSS

## Libellé d'issue. Sans camp local, on nomme le vainqueur plutôt que de
## prétendre à une victoire ou à une défaite qui n'appartiendrait à personne.
static func outcome_label(outcome: Outcome, winner: int) -> String:
	if outcome == Outcome.NO_SIDE:
		return "VICTOIRE %s" % PLAYER_LABELS[clampi(winner, 0, 1)]
	return String(OUTCOME_LABELS.get(outcome, ""))

## Libellé de mode. Un mode inconnu se montre tel quel : mieux vaut un intitulé
## brut qu'un tiret qui efface l'information.
static func mode_label(mode: String) -> String:
	if mode.is_empty():
		return "—"
	return String(MODE_LABELS.get(mode, mode))

# ---------------------------------------------------------------------------
# RÉSUMÉ DE SESSION
# ---------------------------------------------------------------------------

## Résumé de la soirée : le nombre de matchs, le bilan, l'arme la plus jouée et
## le temps passé. Prêt pour l'écran de fin de soirée.
static func session_summary(gap: float = SESSION_GAP,
		path: String = MatchRecord.HISTORY_PATH) -> Dictionary:
	return summarize(session_lines(recent(NO_LIMIT, path), gap))

## Les matchs de la soirée en cours : la série ininterrompue qui se termine par
## le match le plus récent, deux matchs restant de la même série tant que moins
## de `gap` secondes les séparent.
##
## Attend des lignes déjà triées du plus récent au plus ancien, comme les rend
## `recent()`.
static func session_lines(lines: Array, gap: float = SESSION_GAP) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var previous := -1
	for entry in lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		var stamp := _as_int(line.get("epoch"), -1)
		if stamp >= 0 and previous >= 0 and float(previous - stamp) > gap:
			break
		out.append(line)
		# Un horodatage illisible ne disqualifie pas la ligne — on la garde, elle
		# est bien parmi les plus récentes — mais il interdit de mesurer l'écart
		# suivant : la série s'arrête là plutôt que de gonfler la soirée de matchs
		# peut-être vieux d'un mois.
		if stamp < 0:
			break
		previous = stamp
	return out

## Agrège des lignes (celles de `recent()`, de `session_lines()`, ou n'importe
## quel sous-ensemble) en un bilan affichable.
##
## Deux comptages cohabitent, et c'est délibéré. Les matchs en ligne ont un camp
## local : ils alimentent victoires / défaites. Les matchs en écran partagé n'en
## ont pas — les deux joueurs sont sur ce poste — et alimentent un score
## `J1 - J2`. Les mélanger produirait un bilan personnel faux dès qu'une soirée
## mêle les deux, ce qu'une soirée fait tout le temps. Les égalités, elles, sont
## comptées ensemble : une égalité n'appartient à personne dans les deux cas.
static func summarize(lines: Array) -> Dictionary:
	var counts := {"matchs": 0, "victoires": 0, "defaites": 0, "egalites": 0,
		"victoires_j1": 0, "victoires_j2": 0, "forfaits": 0}
	var total_time := 0.0
	var weapon_counts := {}

	for entry in lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		counts["matchs"] += 1
		total_time += _as_float(line.get("duree"), 0.0)
		if line.get("forfait") is bool and bool(line["forfait"]):
			counts["forfaits"] += 1

		match _as_int(line.get("issue"), Outcome.DRAW):
			Outcome.WIN: counts["victoires"] += 1
			Outcome.LOSS: counts["defaites"] += 1
			Outcome.DRAW: counts["egalites"] += 1
			Outcome.NO_SIDE:
				if _as_int(line.get("vainqueur"), -1) == 0:
					counts["victoires_j1"] += 1
				else:
					counts["victoires_j2"] += 1

		# Arme la plus jouée SUR CE POSTE : en ligne, seule la sienne compte ;
		# en écran partagé, les deux joueurs ont joué ici, donc les deux comptent.
		var side := _as_int(line.get("moi"), -1)
		if side >= 0:
			_tally(weapon_counts, _as_text(line.get("arme_moi")))
		else:
			_tally(weapon_counts, _as_text(line.get("arme_j1")))
			_tally(weapon_counts, _as_text(line.get("arme_j2")))

	var favourite := _most_played(weapon_counts)
	var summary := counts.duplicate()
	summary["arme_favorite"] = favourite
	summary["arme_favorite_matchs"] = int(weapon_counts.get(favourite, 0))
	summary["duree_totale"] = snappedf(total_time, 0.01)
	summary["duree_totale_texte"] = format_span(total_time)
	summary["bilan_texte"] = ""
	summary["bilan_partage_texte"] = ""
	if counts["victoires"] + counts["defaites"] + counts["egalites"] > 0:
		summary["bilan_texte"] = "%dV %dD %dN" % [counts["victoires"],
			counts["defaites"], counts["egalites"]]
	if counts["victoires_j1"] + counts["victoires_j2"] > 0:
		summary["bilan_partage_texte"] = "J1 %d - %d J2" % [counts["victoires_j1"],
			counts["victoires_j2"]]
	return summary

# ---------------------------------------------------------------------------
# MISE EN FORME
# ---------------------------------------------------------------------------

## Durée cumulée, lisible d'un coup d'œil : « 1 h 23 », « 23 min », « 45 s ».
## L'horloge mm:ss de `MatchRecord` reste la bonne forme pour un match ; elle
## afficherait « 83:20 » pour une soirée, ce que personne ne lit comme 1 h 23.
static func format_span(seconds: float) -> String:
	var total := maxi(floori(seconds), 0)
	if total >= 3600:
		return "%d h %02d" % [total / 3600, (total % 3600) / 60]
	if total >= 60:
		return "%d min" % (total / 60)
	return "%d s" % total

## Date courte « 16/08 23:29 », ramenée à l'heure locale : le journal horodate en
## UTC, et un joueur qui a joué à 23 h ne doit pas lire 21 h. Rend "" si
## l'horodatage est illisible — la ligne reste affichable sans sa date.
static func format_date(horodatage: String, offset_minutes: int = local_offset_minutes()) -> String:
	return format_epoch(epoch_of(horodatage), offset_minutes)

## Même chose depuis un horodatage déjà décodé (la clé `epoch` d'une ligne).
static func format_epoch(epoch: int, offset_minutes: int = local_offset_minutes()) -> String:
	if epoch < 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(epoch + offset_minutes * 60)
	return "%02d/%02d %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]

## Horodatage du journal en secondes Unix, `-1` s'il est illisible.
##
## La forme est contrôlée à la main avant d'appeler `Time` : sur une chaîne
## abîmée, le moteur pousse une erreur dans la console. Un journal édité à la
## main ne doit pas faire de bruit, il doit juste ne pas être daté.
static func epoch_of(horodatage: String) -> int:
	if horodatage.length() < 19:
		return -1
	var s := horodatage.substr(0, 19)
	if s[4] != "-" or s[7] != "-" or s[13] != ":" or s[16] != ":":
		return -1
	# `MatchRecord` écrit « AAAA-MM-JJ HH:MM:SS » ; la variante « T » de l'ISO
	# 8601 est acceptée pour un journal recopié depuis une autre source.
	if s[10] != " " and s[10] != "T":
		return -1
	var parts := [s.substr(0, 4), s.substr(5, 2), s.substr(8, 2),
		s.substr(11, 2), s.substr(14, 2), s.substr(17, 2)]
	# Bornes de chaque champ : le moteur refuse un mois 13 en poussant une erreur
	# dans la console, et une date absurde n'est pas une raison de faire du bruit.
	var bounds := [[0, 9999], [1, 12], [1, 31], [0, 23], [0, 59], [0, 59]]
	for i in parts.size():
		var part: String = parts[i]
		if not part.is_valid_int():
			return -1
		var value := int(part)
		if value < int(bounds[i][0]) or value > int(bounds[i][1]):
			return -1
	return Time.get_unix_time_from_datetime_string(s.replace(" ", "T"))

## Décalage du fuseau local par rapport à UTC, en minutes.
static func local_offset_minutes() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))

# ---------------------------------------------------------------------------
# COERCITIONS
# ---------------------------------------------------------------------------
#
# Le journal revient du JSON, où TOUT nombre est relu en flottant : `vainqueur`
# vaut 0.0 et non 0 après un aller-retour disque. Un `typeof(x) == TYPE_INT`
# écarterait donc des enregistrements parfaitement valides — piège d'autant plus
# sournois qu'il ne se voit pas sur un enregistrement fraîchement construit.

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _as_int(value: Variant, fallback: int) -> int:
	return int(value) if _is_number(value) else fallback

static func _as_float(value: Variant, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback

## Un champ texte qui n'en est pas un rend "" plutôt que sa représentation :
## afficher « 3 » dans la colonne des armes serait une donnée inventée.
static func _as_text(value: Variant) -> String:
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return ""

static func _tally(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + 1

## Clé la plus comptée. À égalité, la première insérée l'emporte — les lignes
## étant parcourues de la plus récente à la plus ancienne, c'est l'arme jouée le
## plus récemment, ce qui est le départage le moins arbitraire disponible.
static func _most_played(counts: Dictionary) -> String:
	var best := ""
	var best_count := 0
	for key in counts:
		var n := int(counts[key])
		if n > best_count:
			best = String(key)
			best_count = n
	return best
