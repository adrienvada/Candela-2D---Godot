extends Node

## PatchLoader — Autoload, **déclaré en premier**, et l'ordre est la moitié du
## fichier. Phase 9, étape 1.
##
## ## Ce qu'il fait
##
## Il monte le correctif `.pck` téléchargé par l'écran de mise à jour, s'il y en a
## un, s'il s'applique au socle installé, et s'il est intact. Un correctif contient
## des scripts et des scènes qui **recouvrent** ceux du jeu : c'est le chemin de
## mise à jour léger, quelques mégaoctets au lieu de cent.
##
## ## Pourquoi il est déclaré avant tous les autres
##
## Godot instancie les autoloads dans l'ordre de `project.godot`. Un correctif qui
## remplace `network_manager.gd` doit être monté **avant** que `NetworkManager` ne
## soit instancié, sinon Godot a déjà chargé l'ancienne version du script et le
## correctif ne recouvre plus rien — sans erreur, sans trace, avec un jeu qui
## annonce une version qu'il n'exécute pas. C'est la variante silencieuse habituelle
## de ce projet, et la seule parade est la place dans la liste.
##
## Corollaire à connaître avant de publier : **un correctif ne peut pas ajouter
## d'autoload**, la liste étant lue dans le `project.godot` du socle. Ni changer le
## moteur, ni l'addon EOS, ni les modèles d'exportation. Tout cela demande un
## remplacement complet — c'est le rôle de `socle_min` dans le manifeste.
##
## ## Le témoin d'essai, et ce qu'il attrape
##
## Un correctif défaillant peut empêcher le jeu de démarrer. Le jeu n'a alors plus
## d'écran pour proposer quoi que ce soit, et le joueur n'a plus qu'à réinstaller :
## c'est le pire résultat possible pour un système censé réparer.
##
## D'où le témoin. On écrit un fichier **avant** de monter le correctif ;
## `update_manager.gd` l'efface une fois que le jeu a vécu quelques secondes. Si
## on le retrouve au démarrage suivant, c'est que le démarrage précédent n'est
## jamais arrivé jusque-là : le correctif est mis en quarantaine et le jeu repart
## sur son socle. Le joueur perd le correctif, jamais le jeu.
##
## Ce que le témoin n'attrape pas, et il faut le dire : un correctif qui casse une
## fonction rarement utilisée, trois écrans plus loin. Il couvre le démarrage,
## c'est-à-dire le seul échec dont on ne peut pas se relever.

const REGISTRE := "user://maj/correctif.json"
const TEMOIN := "user://maj/en_essai"
const SUFFIXE_SUSPECT := ".suspect"

## La version que le correctif monté apporte, ou `""` si le jeu tourne sur son
## seul socle. `update_manager.gd` s'en sert pour dire au joueur ce qu'il exécute
## vraiment — la version affichée doit être celle du code qui tourne, pas celle du
## fichier qui l'a installé.
var version_appliquee: String = ""

## Rempli quand un correctif a été refusé, pour que l'écran puisse le dire.
## Un correctif qui disparaît sans explication est un correctif qu'on
## retéléchargera en boucle.
var incident: String = ""

func _init() -> void:
	var socle := str(ProjectSettings.get_setting("application/config/version", ""))

	if FileAccess.file_exists(TEMOIN):
		# Le démarrage précédent n'est jamais allé jusqu'au menu.
		_mettre_en_quarantaine()
		DirAccess.remove_absolute(TEMOIN)
		incident = ("Le correctif précédent a empêché le jeu de démarrer : "
			+ "il a été écarté et le jeu est reparti sur sa version installée.")
		return

	if not FileAccess.file_exists(REGISTRE):
		return

	var registre: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRE))
	if typeof(registre) != TYPE_DICTIONARY:
		_oublier("Le registre des correctifs est illisible.")
		return
	var d: Dictionary = registre
	var fichier := str(d.get("fichier", ""))
	var version := str(d.get("version", ""))
	var socle_attendu := str(d.get("socle", ""))

	# Le socle a changé sous le correctif : une mise à jour complète est passée
	# par là. Le correctif recouvrirait des fichiers d'une version qu'il n'a
	# jamais vue — c'est-à-dire un mélange que personne n'a testé.
	if socle_attendu != socle:
		_oublier("")
		return

	if not FileAccess.file_exists(fichier):
		_oublier("Le correctif a disparu du disque.")
		return

	# L'empreinte est revérifiée à **chaque** démarrage, pas seulement à
	# l'installation : entre les deux il y a un disque, un antivirus, une
	# synchronisation de dossier, et un fichier tronqué qui monterait à moitié.
	var sha := str(d.get("sha256", ""))
	if sha != "" and FileAccess.get_sha256(fichier).to_lower() != sha.to_lower():
		_oublier("Le correctif était abîmé : il a été écarté.")
		return

	var f := FileAccess.open(TEMOIN, FileAccess.WRITE)
	if f != null:
		f.store_string(version)
		f.close()

	if not ProjectSettings.load_resource_pack(fichier, true):
		DirAccess.remove_absolute(TEMOIN)
		_oublier("Le correctif n'a pas pu être monté.")
		return
	version_appliquee = version

## Efface le témoin : le jeu a démarré, le correctif monté a fait ses preuves sur
## ce qui compte. Appelé par `update_manager.gd`, jamais ici — c'est justement la
## survie du démarrage qu'on cherche à constater.
func confirmer_demarrage() -> void:
	if FileAccess.file_exists(TEMOIN):
		DirAccess.remove_absolute(TEMOIN)

func _oublier(raison: String) -> void:
	var registre: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRE))
	if typeof(registre) == TYPE_DICTIONARY:
		var fichier := str((registre as Dictionary).get("fichier", ""))
		if fichier != "" and FileAccess.file_exists(fichier):
			DirAccess.remove_absolute(fichier)
	DirAccess.remove_absolute(REGISTRE)
	incident = raison

## La quarantaine garde le fichier au lieu de l'effacer : quand un correctif
## empêche le jeu de démarrer, le fichier est la seule pièce à conviction, et il
## n'y a rien à en tirer s'il a disparu.
func _mettre_en_quarantaine() -> void:
	if not FileAccess.file_exists(REGISTRE):
		return
	var registre: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRE))
	if typeof(registre) == TYPE_DICTIONARY:
		var fichier := str((registre as Dictionary).get("fichier", ""))
		if fichier != "" and FileAccess.file_exists(fichier):
			DirAccess.rename_absolute(fichier, fichier + SUFFIXE_SUSPECT)
	DirAccess.rename_absolute(REGISTRE, REGISTRE + SUFFIXE_SUSPECT)
