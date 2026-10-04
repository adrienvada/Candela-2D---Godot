class_name AventureProgression
extends RefCounted

## La PROGRESSION du joueur dans l'aventure — chantier SOLO, étape S6. Un fichier, `user://solo.cfg`.
##
## ```
## [progression]
## classes_debloquees = ["pistolet", "fumiste"]
## classe_choisie = "fumiste"
##
## [chapitre_00]
## niveaux_reussis = [0, 1, 2, …, 9]
## termine = true
## ```
##
## ## Ce qu'elle dit, et ce qu'elle ne touche pas
##
## - **Un chapitre s'ouvre quand le précédent est fini** (le chapitre 0 est toujours ouvert) ; **dans un chapitre, un niveau
##   s'ouvre quand le précédent est réussi** (le premier est toujours ouvert). Réussir un niveau déjà joué n'ouvre rien de plus.
## - **Finir un chapitre débloque SA classe** (`AventureFormat.classe_du_chapitre`) — et celle-là seulement : on ne peut pas finir un
##   chapitre fermé, donc les classes ne se débloquent jamais dans le désordre. `classes_debloquees()` les rend dans l'ORDRE DU RANG.
## - **Le déblocage est propre au solo.** Il ne touche ni `RankLoadout` ni le rang : en ligne, seul le rang débloque (Phase 7, règle
##   du miroir en classé). Rien de ce fichier ne sort de la machine, rien ne transite.
## - **Elle ne sait rien du jeu monté** : ni autoload ni nœud — une suite en `--script` la charge seule, sur un chemin à elle.
##
## ## Un fichier illisible ne se perd pas en silence
##
## Un `solo.cfg` absent est un joueur qui commence. Un `solo.cfg` PRÉSENT mais illisible est autre chose : écrire par-dessus
## l'effacerait avec tout ce qu'il portait. On le crie (`push_error`) et on le met de côté (`<chemin>.illisible`) AVANT de repartir
## d'une progression vide.

const FormatT := preload("res://aventure_format.gd")

const CHEMIN_PAR_DEFAUT := "user://solo.cfg"

var chemin := CHEMIN_PAR_DEFAUT
var _cfg := ConfigFile.new()
## Vrai si le fichier existait mais n'a pas pu être lu : la progression repart vide, l'original est à côté (`.illisible`).
var fichier_illisible := false


func _init(un_chemin: String = CHEMIN_PAR_DEFAUT) -> void:
	chemin = un_chemin
	charger()


## Relit le fichier. Absent : une progression vide. Illisible : crié, mis de côté, puis vide.
func charger() -> void:
	_cfg = ConfigFile.new()
	fichier_illisible = false
	if not FileAccess.file_exists(chemin):
		return
	var code := _cfg.load(chemin)
	if code != OK:
		fichier_illisible = true
		push_error("AventureProgression : %s illisible (code %d) — mis de côté en .illisible, la progression repart vide" % [chemin, code])
		DirAccess.copy_absolute(chemin, chemin + ".illisible")
		_cfg = ConfigFile.new()


## Écrit le fichier. Rend faux (et crie) si le disque refuse : une progression qui ne se sauve pas doit se voir.
func sauver() -> bool:
	var code := _cfg.save(chemin)
	if code != OK:
		push_error("AventureProgression : %s non écrit (code %d)" % [chemin, code])
		return false
	return true


# --- Les chapitres ----------------------------------------------------------

static func _section(chapitre: int) -> String:
	return "chapitre_%02d" % chapitre


func chapitre_termine(chapitre: int) -> bool:
	return bool(_cfg.get_value(_section(chapitre), "termine", false))


## Le chapitre 0 est toujours ouvert ; un autre quand celui d'avant est fini.
func chapitre_ouvert(chapitre: int) -> bool:
	if chapitre < 0 or chapitre > FormatT.CHAPITRE_MAX:
		return false
	return chapitre == 0 or chapitre_termine(chapitre - 1)


## Combien de chapitres sont finis.
func chapitres_termines() -> int:
	var n := 0
	for c in FormatT.CHAPITRE_MAX + 1:
		if chapitre_termine(c):
			n += 1
	return n


# --- Les niveaux ------------------------------------------------------------

func niveaux_reussis(chapitre: int) -> Array[int]:
	var sortie: Array[int] = []
	for v in _cfg.get_value(_section(chapitre), "niveaux_reussis", []):
		sortie.append(int(v))
	sortie.sort()
	return sortie


func niveau_reussi(chapitre: int, index: int) -> bool:
	return niveaux_reussis(chapitre).has(index)


## Le premier niveau d'un chapitre ouvert est ouvert ; un autre quand le précédent est réussi.
func niveau_ouvert(chapitre: int, index: int) -> bool:
	if index < 0 or not chapitre_ouvert(chapitre):
		return false
	return index == 0 or niveau_reussi(chapitre, index - 1)


## Le premier niveau non réussi d'un chapitre : celui qu'on propose de jouer. `nombre` : combien de salles compte le chapitre ; si
## toutes sont réussies, on propose la première (on rejoue).
func prochain_niveau(chapitre: int, nombre: int) -> int:
	for i in nombre:
		if not niveau_reussi(chapitre, i):
			return i
	return 0


## Note qu'un niveau est réussi. Refuse (et crie) un niveau fermé : on ne réussit pas une salle qu'on n'a pas pu atteindre.
func reussir_niveau(chapitre: int, index: int) -> bool:
	if not niveau_ouvert(chapitre, index):
		push_error("AventureProgression : le niveau %d.%d est fermé — il ne peut pas être réussi" % [chapitre, index + 1])
		return false
	var deja := niveaux_reussis(chapitre)
	if not deja.has(index):
		deja.append(index)
		deja.sort()
		_cfg.set_value(_section(chapitre), "niveaux_reussis", deja)
	return sauver()


## Le meilleur temps d'une salle, en secondes de jeu (carton exclu) ; 0 si elle n'a jamais été réussie. Il nourrit le « RECORD » du
## tampon de la salle réussie (`AventureHud`, 2026-10-04) : rejouer une salle a un but, la battre.
func meilleur_temps(chapitre: int, index: int) -> float:
	return float(_cfg.get_value(_section(chapitre), "temps_%d" % index, 0.0))


## Note un temps de salle réussie ; vrai si c'est un RECORD — il bat un meilleur temps déjà connu. Le premier passage n'en est pas un :
## il n'a rien battu. Écrit seulement quand le temps s'améliore.
func noter_temps(chapitre: int, index: int, secondes: float) -> bool:
	if secondes <= 0.0:
		return false
	var ancien := meilleur_temps(chapitre, index)
	if ancien > 0.0 and secondes >= ancien:
		return false
	_cfg.set_value(_section(chapitre), "temps_%d" % index, snappedf(secondes, 0.01))
	sauver()
	return ancien > 0.0


## Finit un chapitre — son BOSS est tombé — et débloque sa classe. Refuse (et crie) un chapitre fermé.
func terminer_chapitre(chapitre: int) -> bool:
	if not chapitre_ouvert(chapitre):
		push_error("AventureProgression : le chapitre %d est fermé — il ne peut pas être fini" % chapitre)
		return false
	_cfg.set_value(_section(chapitre), "termine", true)
	var classe := FormatT.classe_du_chapitre(chapitre)
	if classe != "":
		var deja := _classes_brutes()
		if not deja.has(classe):
			deja.append(classe)
		_cfg.set_value("progression", "classes_debloquees", deja)
	return sauver()


# --- Les classes ------------------------------------------------------------

func _classes_brutes() -> Array[String]:
	var sortie: Array[String] = []
	for v in _cfg.get_value("progression", "classes_debloquees", []):
		if FormatT.ORDRE_DES_CLASSES.has(String(v)) and not sortie.has(String(v)):
			sortie.append(String(v))
	return sortie


## Les classes débloquées, dans l'ORDRE DU RANG (Parasite d'abord) — quel que soit l'ordre où le fichier les a notées.
func classes_debloquees() -> Array[String]:
	var brutes := _classes_brutes()
	var sortie: Array[String] = []
	for slug in FormatT.ORDRE_DES_CLASSES:
		if brutes.has(slug):
			sortie.append(slug)
	return sortie


func classe_debloquee(slug: String) -> bool:
	return classes_debloquees().has(slug)


## La classe choisie pour jouer, ou `""` si personne n'a rien choisi — ou si la classe notée n'est plus (ou pas) débloquée.
func classe_choisie() -> String:
	var s := String(_cfg.get_value("progression", "classe_choisie", ""))
	return s if classe_debloquee(s) else ""


## Choisit sa classe parmi les débloquées. Refuse (et crie) une classe qui ne l'est pas : le choix est libre, mais pas sur ce qu'on
## n'a pas gagné.
func choisir_classe(slug: String) -> bool:
	if not classe_debloquee(slug):
		push_error("AventureProgression : la classe « %s » n'est pas débloquée" % slug)
		return false
	_cfg.set_value("progression", "classe_choisie", slug)
	return sauver()


## La classe avec laquelle on joue le chapitre `chapitre`, dont le manifeste dit `imposee` (vide : libre) : l'imposée si le chapitre
## en impose une, sinon la choisie, sinon la première débloquée, sinon la classe par défaut (le Parasite : « prêté » au chapitre 0).
func classe_pour_jouer(imposee: String) -> String:
	if imposee != "":
		return imposee
	var choisie := classe_choisie()
	if choisie != "":
		return choisie
	var debloquees := classes_debloquees()
	return debloquees[0] if not debloquees.is_empty() else FormatT.CLASSE_PAR_DEFAUT
