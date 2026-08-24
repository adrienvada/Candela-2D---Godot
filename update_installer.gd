class_name UpdateInstaller
extends RefCounted

## Poser la nouvelle version sur le disque — Phase 9, étape 1.
##
## ## Le partage avec `update_manager.gd`
##
## Le gestionnaire décide *quoi* (quel paquet, quand, faut-il le proposer) ; ce
## fichier sait *comment*, et c'est le seul endroit du dépôt qui connaisse la
## différence entre un `.app`, un dossier Windows et un `.pck`. La règle est la
## même que pour le transport réseau : aucun `if plateforme == …` ailleurs.
##
## ## Le remplacement se fait après la fermeture, jamais pendant
##
## Un jeu ne peut pas se remplacer lui-même : sous Windows son propre `.exe` est
## verrouillé tant qu'il tourne, et sous macOS remplacer un bundle en cours
## d'exécution laisse un processus dont les ressources ont disparu sous les pieds.
## D'où le script d'échange : le jeu l'écrit, le lance **détaché**, puis se ferme.
## Le script attend la disparition du processus, échange les dossiers, relance.
##
## ## Ce qui est réversible, et ce qui ne l'est pas
##
## Tout le coûteux — télécharger, vérifier l'empreinte, décompresser, vérifier que
## l'archive contient bien ce qu'elle annonce — se fait **pendant que le jeu
## tourne**, et n'importe lequel de ces échecs se raconte dans l'écran de mise à
## jour sans que rien n'ait bougé. Le geste irréversible se réduit à deux `mv`
## après la fermeture, et même ceux-là gardent l'ancienne installation sous un
## nom voisin : si le second échoue, le script remet le premier en place et
## relance l'ancienne version. Un joueur ne doit pas pouvoir se retrouver sans
## jeu parce qu'un téléchargement a été coupé.
##
## ## Ce qu'un correctif `.pck` ne peut pas faire
##
## Il remplace des scripts, des scènes, des ressources. Il ne remplace **ni le
## moteur, ni les modèles d'exportation, ni l'addon EOS** (une GDExtension charge
## une bibliothèque native déclarée au démarrage depuis `res://`), **ni la liste
## des autoloads**, qui est lue dans `project.godot` du socle. Publier un
## correctif qui a besoin de l'un de ces quatre est un défaut de publication, pas
## un défaut du jeu : `socle_min` est là pour l'empêcher.

const PLATEFORME_MACOS := "macos"
const PLATEFORME_WINDOWS := "windows"
const PLATEFORME_LINUX := "linux"

## Le dossier de travail, à côté de l'installation. Volontairement sur le même
## volume que la cible : un `mv` y est un renommage instantané, alors qu'un
## déplacement depuis `user://` recopierait cent mégaoctets — et un « déplacement »
## qui dure trente secondes est un déplacement qui peut être interrompu au milieu.
const DOSSIER_ETAPE := ".candela-maj"

## Ce que le script d'échange laisse derrière lui, et que `update_manager.gd`
## efface au premier démarrage réussi de la nouvelle version.
const SUFFIXE_ANCIEN := ".ancien"

## Là où vivent les correctifs installés. Sous `user://`, donc conservés quand le
## socle est remplacé — et c'est précisément pourquoi `patch_loader.gd` vérifie
## le socle avant d'en charger un.
const DOSSIER_CORRECTIFS := "user://maj/correctifs"
const REGISTRE_CORRECTIF := "user://maj/correctif.json"
const TEMOIN_ESSAI := "user://maj/en_essai"

# ---------------------------------------------------------------------------
# CE QUE CETTE MACHINE EST
# ---------------------------------------------------------------------------

static func plateforme() -> String:
	match OS.get_name():
		"macOS": return PLATEFORME_MACOS
		"Windows", "UWP": return PLATEFORME_WINDOWS
		_: return PLATEFORME_LINUX

static func architecture() -> String:
	# `Engine.get_architecture_name()` rend « x86_64 », « arm64 »… c'est déjà le
	# vocabulaire du manifeste ; le recopier serait une occasion de diverger.
	return Engine.get_architecture_name()

## La racine de l'installation, déduite du chemin de l'exécutable.
##
## Fonction pure, et c'est ce qui la rend vérifiable : la suite lui donne les
## trois formes de chemin que les trois plateformes produisent, sans avoir à
## exporter quoi que ce soit.
static func racine_pour(chemin_executable: String, plate: String) -> String:
	if chemin_executable == "":
		return ""
	if plate == PLATEFORME_MACOS:
		# /Applications/Candela.app/Contents/MacOS/Candela → /Applications/Candela.app
		var reste := chemin_executable
		while reste != "" and reste != "/":
			if reste.get_extension() == "app":
				return reste
			reste = reste.get_base_dir()
		return ""
	return chemin_executable.get_base_dir()

# ---------------------------------------------------------------------------
# PEUT-ON INSTALLER ICI ?
# ---------------------------------------------------------------------------

## Rend `{"ok": bool, "raison": String}`. La raison est écrite pour le joueur :
## elle dit quoi faire, jamais ce qui a échoué techniquement.
##
## Les trois refus valent chacun une soirée de dépannage évitée :
##
## - **build de développement** — dans l'éditeur il n'y a pas d'installation à
##   remplacer ; installer y écraserait un arbre de travail ;
## - **translocation macOS** — un `.app` lancé depuis Téléchargements avec l'
##   attribut de quarantaine tourne depuis un chemin aléatoire en **lecture
##   seule**. Tout marche jusqu'au dernier `mv`, qui échoue. Le seul moment où on
##   peut le dire utilement, c'est avant de télécharger ;
## - **dossier non inscriptible** — `C:\Program Files\` sans élévation, ou un
##   `.app` posé sur un volume monté en lecture seule.
func diagnostic(racine: String = "") -> Dictionary:
	if OS.has_feature("editor"):
		return {"ok": false, "raison": "Ce jeu tourne depuis l'éditeur : "
			+ "il n'y a rien à remplacer. La mise à jour ne concerne que les "
			+ "versions installées."}
	var cible := racine if racine != "" else racine_pour(OS.get_executable_path(), plateforme())
	if cible == "":
		return {"ok": false, "raison": "Impossible de trouver où le jeu est installé."}
	if plateforme() == PLATEFORME_MACOS and cible.contains("/AppTranslocation/"):
		return {"ok": false, "raison": "macOS exécute le jeu depuis un emplacement "
			+ "temporaire en lecture seule. Glissez Candela dans le dossier "
			+ "Applications, ouvrez-le depuis là, et la mise à jour sera possible."}
	var parent := cible.get_base_dir()
	if not _peut_ecrire(parent):
		return {"ok": false, "raison": ("Le jeu est installé dans un dossier où il "
			+ "n'a pas le droit d'écrire (%s). Déplacez-le dans un dossier "
			+ "personnel pour pouvoir le mettre à jour.") % parent}
	return {"ok": true, "raison": ""}

static func _peut_ecrire(dossier: String) -> bool:
	var essai := dossier.path_join(".candela-essai-ecriture")
	var f := FileAccess.open(essai, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(essai)
	return true

# ---------------------------------------------------------------------------
# BUNDLE — PRÉPARATION (RÉVERSIBLE)
# ---------------------------------------------------------------------------

## Décompresse l'archive à côté de l'installation et vérifie qu'elle contient
## bien ce que le manifeste annonce. Rend `{"ok", "raison", "neuf"}` où `neuf`
## est le chemin de la nouvelle installation, prête à prendre la place.
##
## Rien n'est encore remplacé à la sortie de cette fonction, et c'est tout
## l'intérêt : un échec ici se raconte à l'écran, le jeu continue.
func preparer_bundle(archive: String, racine: String, nom_racine: String) -> Dictionary:
	var parent := racine.get_base_dir()
	var etape := parent.path_join(DOSSIER_ETAPE)
	_effacer_recursif(etape)
	if DirAccess.make_dir_recursive_absolute(etape) != OK:
		return {"ok": false, "raison": "Impossible de préparer l'installation dans %s." % parent}

	var code := _decompresser(archive, etape)
	if code != OK:
		_effacer_recursif(etape)
		return {"ok": false, "raison": "L'archive téléchargée n'a pas pu être ouverte."}

	var attendu := nom_racine if nom_racine != "" else racine.get_file()
	var neuf := etape.path_join(attendu)
	if not (DirAccess.dir_exists_absolute(neuf) or FileAccess.file_exists(neuf)):
		# Une archive qui ne contient pas ce qu'elle dit est un défaut de
		# publication : le nommer précisément évite de chercher côté joueur.
		var trouve := ", ".join(_lister(etape))
		_effacer_recursif(etape)
		return {"ok": false, "raison": "L'archive ne contient pas « %s » (trouvé : %s)."
			% [attendu, trouve if trouve != "" else "rien"]}
	return {"ok": true, "raison": "", "neuf": neuf}

## Décompression déléguée aux outils du système, jamais à `ZIPReader`.
##
## `ZIPReader` sait lire une archive, mais pas restituer le **bit d'exécution**
## ni les liens symboliques : un `.app` ainsi reconstruit ne se lance pas, et
## l'erreur ne ressemble en rien à sa cause. `ditto` sous macOS et `tar` sous
## Windows (livré depuis Windows 10 1803) font le travail correctement.
func _decompresser(archive: String, vers: String) -> Error:
	var sortie: Array = []
	var code := -1
	match plateforme():
		PLATEFORME_MACOS:
			code = OS.execute("/usr/bin/ditto", ["-x", "-k", archive, vers], sortie, true)
		PLATEFORME_WINDOWS:
			code = OS.execute("tar.exe", ["-xf", archive, "-C", vers], sortie, true)
			if code != 0:
				code = OS.execute("powershell.exe", ["-NoProfile", "-Command",
					"Expand-Archive -LiteralPath '%s' -DestinationPath '%s' -Force"
						% [archive, vers]], sortie, true)
		_:
			code = OS.execute("unzip", ["-q", "-o", archive, "-d", vers], sortie, true)
	if code != 0:
		push_warning("UpdateInstaller: décompression en échec (%d) : %s" % [code, str(sortie)])
		return FAILED
	return OK

# ---------------------------------------------------------------------------
# BUNDLE — L'ÉCHANGE (LE SEUL GESTE IRRÉVERSIBLE)
# ---------------------------------------------------------------------------

## Écrit le script d'échange, le lance détaché, et rend `OK` — l'appelant doit
## quitter **immédiatement** après : le script attend la disparition du processus
## et n'ira pas plus loin tant que le jeu tourne.
func appliquer_bundle(racine: String, neuf: String) -> Dictionary:
	var texte := script_echange(OS.get_process_id(), racine, neuf,
		racine + SUFFIXE_ANCIEN, _executable_relance(racine), plateforme(),
		ProjectSettings.globalize_path("user://maj/echange.log"))
	if texte == "":
		return {"ok": false, "raison": "Un chemin d'installation contient un "
			+ "caractère que le script d'échange ne sait pas citer."}

	var chemin := ProjectSettings.globalize_path("user://maj/echange."
		+ ("bat" if plateforme() == PLATEFORME_WINDOWS else "sh"))
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "raison": "Impossible d'écrire le script d'installation."}
	f.store_string(texte)
	f.close()

	var pid := -1
	if plateforme() == PLATEFORME_WINDOWS:
		pid = OS.create_process("cmd.exe", ["/c", chemin])
	else:
		OS.execute("chmod", ["+x", chemin])
		pid = OS.create_process("/bin/sh", [chemin])
	if pid <= 0:
		return {"ok": false, "raison": "Le programme d'installation n'a pas pu démarrer."}
	return {"ok": true, "raison": ""}

## Le script d'échange, en texte. **Fonction pure** : la suite headless le lit et
## vérifie qu'il attend bien le processus, qu'il garde l'ancienne installation et
## qu'il sait revenir en arrière — trois propriétés qu'on ne peut pas éprouver en
## exécutant vraiment le script sur la machine d'intégration continue.
##
## Rend `""` si un chemin contient un caractère qui casserait la citation. Refuser
## vaut mieux que produire un script qui, sur un dossier nommé avec une
## apostrophe, effacerait la mauvaise chose.
static func script_echange(pid: int, cible: String, neuf: String, ancien: String,
		relance: String, plate: String, journal: String) -> String:
	var chemins := [cible, neuf, ancien, relance, journal]
	if plate == PLATEFORME_WINDOWS:
		for c: String in chemins:
			if c.contains('"') or c.contains("%"):
				return ""
		return _script_windows(pid, cible, neuf, ancien, relance, journal)
	for c: String in chemins:
		if c.contains("'"):
			return ""
	return _script_posix(pid, cible, neuf, ancien, relance, journal)

static func _script_posix(pid: int, cible: String, neuf: String, ancien: String,
		relance: String, journal: String) -> String:
	return """#!/bin/sh
# Écrit par Candela au moment d'installer une mise à jour. Se supprime de fait à
# la prochaine mise à jour, qui le réécrit.
#
# Il attend que le jeu ait vraiment disparu : remplacer un bundle sous un
# processus vivant laisse un jeu dont les ressources n'existent plus.
PID='%d'
CIBLE='%s'
NEUF='%s'
ANCIEN='%s'
RELANCE='%s'

exec >>'%s' 2>&1
echo "--- échange de bundle, pid $PID"

n=0
while kill -0 "$PID" 2>/dev/null; do
	n=$((n + 1))
	if [ "$n" -gt 120 ]; then
		echo "le jeu ne s'est pas fermé en 60 s, rien n'a été touché"
		exit 3
	fi
	sleep 0.5
done

rm -rf "$ANCIEN"
if ! mv "$CIBLE" "$ANCIEN"; then
	echo "impossible de mettre l'installation de côté, rien n'a été touché"
	exit 4
fi
if ! mv "$NEUF" "$CIBLE"; then
	echo "installation impossible, retour à la version précédente"
	mv "$ANCIEN" "$CIBLE"
	open "$RELANCE" || "$RELANCE" &
	exit 5
fi
echo "installée"
open "$RELANCE" || "$RELANCE" &
exit 0
""" % [pid, cible, neuf, ancien, relance, journal]

static func _script_windows(pid: int, cible: String, neuf: String, ancien: String,
		relance: String, journal: String) -> String:
	return """@echo off
rem Écrit par Candela au moment d'installer une mise à jour.
rem Il attend la disparition du processus : sous Windows, l'exécutable d'un jeu
rem qui tourne est verrouillé, et le remplacer échouerait sans rien dire.
setlocal
set "PID=%d"
set "CIBLE=%s"
set "NEUF=%s"
set "ANCIEN=%s"
set "RELANCE=%s"
set "JOURNAL=%s"

set /a N=0
:attente
tasklist /FI "PID eq %%PID%%" 2>nul | find "%%PID%%" >nul
if errorlevel 1 goto libre
set /a N+=1
if %%N%% GTR 120 (
	echo le jeu ne s'est pas ferme en 60 s, rien n'a ete touche >>"%%JOURNAL%%"
	exit /b 3
)
ping -n 2 127.0.0.1 >nul
goto attente

:libre
if exist "%%ANCIEN%%" rmdir /s /q "%%ANCIEN%%"
move "%%CIBLE%%" "%%ANCIEN%%" >nul
if errorlevel 1 (
	echo impossible de mettre l'installation de cote >>"%%JOURNAL%%"
	exit /b 4
)
move "%%NEUF%%" "%%CIBLE%%" >nul
if errorlevel 1 (
	echo installation impossible, retour a la version precedente >>"%%JOURNAL%%"
	move "%%ANCIEN%%" "%%CIBLE%%" >nul
	start "" "%%RELANCE%%"
	exit /b 5
)
echo installee >>"%%JOURNAL%%"
start "" "%%RELANCE%%"
exit /b 0
""" % [pid, cible, neuf, ancien, relance, journal]

## Ce qu'il faut relancer une fois l'échange fait. Sous macOS c'est le bundle
## lui-même (`open` passe par LaunchServices, qui remet le jeu au premier plan et
## lui donne un vrai contexte d'application) ; ailleurs c'est l'exécutable.
static func executable_relance_pour(racine: String, chemin_executable: String,
		plate: String) -> String:
	if plate == PLATEFORME_MACOS:
		return racine
	return racine.path_join(chemin_executable.get_file())

func _executable_relance(racine: String) -> String:
	return executable_relance_pour(racine, OS.get_executable_path(), plateforme())

# ---------------------------------------------------------------------------
# CORRECTIF .PCK
# ---------------------------------------------------------------------------

## Installe un correctif : le fichier est déplacé dans `user://`, et un registre
## dit au démarrage suivant quoi charger. Le socle installé y est inscrit tel
## qu'il est **maintenant** : c'est ce qui permet à `patch_loader.gd` de jeter le
## correctif si le socle a été remplacé entre-temps par une mise à jour complète.
func installer_correctif(fichier_telecharge: String, version: String, socle: String,
		sha256: String) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(DOSSIER_CORRECTIFS) != OK:
		return {"ok": false, "raison": "Impossible de préparer le dossier des correctifs."}
	var destination := "%s/candela-%s.pck" % [DOSSIER_CORRECTIFS, version]
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(destination)
	if DirAccess.rename_absolute(fichier_telecharge, destination) != OK:
		return {"ok": false, "raison": "Impossible de ranger le correctif téléchargé."}

	var registre := {
		"format": 1,
		"version": version,
		"socle": socle,
		"fichier": destination,
		"sha256": sha256.to_lower(),
	}
	var f := FileAccess.open(REGISTRE_CORRECTIF, FileAccess.WRITE)
	if f == null:
		DirAccess.remove_absolute(destination)
		return {"ok": false, "raison": "Impossible d'inscrire le correctif."}
	f.store_string(JSON.stringify(registre, "\t"))
	f.close()
	return {"ok": true, "raison": ""}

## Relance le jeu, pour un correctif : rien à échanger, donc pas de script.
func relancer() -> bool:
	var exe := OS.get_executable_path()
	var pid := -1
	if plateforme() == PLATEFORME_MACOS:
		var racine := racine_pour(exe, PLATEFORME_MACOS)
		pid = OS.create_process("/usr/bin/open", [racine]) if racine != "" \
			else OS.create_process(exe, [])
	else:
		pid = OS.create_process(exe, [])
	return pid > 0

# ---------------------------------------------------------------------------
# MÉNAGE
# ---------------------------------------------------------------------------

## Efface ce qu'une mise à jour précédente a laissé : l'ancienne installation
## gardée pour le retour en arrière, et le dossier d'étape.
##
## Appelé **au démarrage suivant**, jamais par le script d'échange lui-même : tant
## que le jeu neuf n'a pas démarré une fois, l'ancien est la seule chose qui
## marche à coup sûr, et l'effacer serait supprimer le filet en même temps que le
## risque.
func nettoyer_apres_installation(racine: String) -> void:
	if racine == "":
		return
	_effacer_recursif(racine + SUFFIXE_ANCIEN)
	_effacer_recursif(racine.get_base_dir().path_join(DOSSIER_ETAPE))

static func _lister(dossier: String) -> PackedStringArray:
	var d := DirAccess.open(dossier)
	if d == null:
		return PackedStringArray()
	var noms := PackedStringArray()
	noms.append_array(d.get_directories())
	noms.append_array(d.get_files())
	return noms

static func _effacer_recursif(chemin: String) -> void:
	if chemin == "" or chemin == "/" or not (DirAccess.dir_exists_absolute(chemin)
			or FileAccess.file_exists(chemin)):
		return
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
		return
	var d := DirAccess.open(chemin)
	if d == null:
		return
	for nom: String in d.get_files():
		DirAccess.remove_absolute(chemin.path_join(nom))
	for nom: String in d.get_directories():
		_effacer_recursif(chemin.path_join(nom))
	DirAccess.remove_absolute(chemin)
