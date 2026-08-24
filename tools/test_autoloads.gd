## L'ordre des autoloads est une contrainte, pas une préférence de rangement.
##
## ## Pourquoi ce banc existe
##
## Deux autoloads doivent être déclarés à une place précise dans
## `project.godot`, et **rien dans le fichier ne peut le dire** : Godot réécrit
## `project.godot` quand une extension d'éditeur appelle `ProjectSettings.save()`
## — c'est le cas de `godot_ai` — et cette réécriture **jette toutes les lignes
## de commentaire**. Une explication posée là est condamnée ; elle a été
## restaurée une fois, reperdue, et c'est ce qui a mené à ce fichier.
##
## Un commentaire n'aurait de toute façon protégé personne : il n'empêche pas de
## « ranger » les autoloads par ordre alphabétique six mois plus tard. Ce banc,
## lui, refuse le rangement au lieu de le déplorer.
##
## ## Les deux règles, et ce qu'on paie à les enfreindre
##
## - **`PatchLoader` en premier.** Il monte le correctif `.pck` téléchargé par
##   l'écran de mise à jour. Godot instancie les autoloads dans l'ordre déclaré :
##   un correctif qui remplace `network_manager.gd` et qui arrive **après**
##   l'instanciation de `NetworkManager` ne recouvre plus rien. Aucune erreur,
##   aucune trace — un jeu qui annonce une version qu'il n'exécute pas.
## - **`GameSettings` après `InputSetup`.** Les liaisons de touches sauvegardées
##   dans `user://settings.cfg` doivent **recouvrir** les liaisons par défaut. Si
##   `GameSettings` passe en premier, les défauts s'appliquent par-dessus le
##   choix du joueur : ses touches remappées sont perdues à chaque lancement, et
##   rien ne le signale. Règle antérieure à ce banc, jamais protégée jusqu'ici.
##
## ## Ce que le banc protège de lui-même
##
## Un banc qui lit un fichier peut se tromper de fichier, de section, ou de forme
## de ligne — et rendre alors une liste vide, donc **vert sans rien avoir
## vérifié**. C'est le mode de défaillance qui rendrait ce fichier inutile, et
## c'est pourquoi il commence par prouver que sa lecture a ramené quelque chose
## de reconnaissable avant de juger quoi que ce soit.
##
## Lancer : godot --headless --path . --script res://tools/test_autoloads.gd
extends SceneTree

const PROJET := "res://project.godot"

## Ceux dont ce banc connaît la place. Les autres n'ont pas de contrainte connue
## et ne sont donc pas jugés : un banc qui figerait l'ordre entier interdirait
## d'ajouter un autoload sans le modifier, ce qui le ferait retirer.
const PREMIER := "PatchLoader"
const APRES: Array[Array] = [
	["GameSettings", "InputSetup"],
]
## Ceux dont l'absence est une régression silencieuse : le jeu démarre, et une
## fonction entière a disparu sans que rien ne le dise.
const REQUIS: Array[String] = ["PatchLoader", "UpdateManager", "NetworkManager",
	"InputSetup", "GameSettings"]

var _failures: int = 0

func _init() -> void:
	print("=== Test de l'ordre des autoloads ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var noms := _lire_autoloads()
	_test_lecture(noms)
	_test_ordre(noms)

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------

## Les noms d'autoloads, dans l'ordre de déclaration.
##
## Lecture du **texte** et non de `ProjectSettings` : ce qui est en jeu est
## l'ordre des lignes, et l'API ne le rend pas. Les lignes de commentaire et les
## lignes vides sont ignorées — elles ne survivent pas à une réécriture de Godot,
## et une section qui en contient encore doit se lire comme une qui n'en a plus.
func _lire_autoloads() -> PackedStringArray:
	var noms := PackedStringArray()
	var texte := FileAccess.get_file_as_string(PROJET)
	var dans_section := false
	for ligne_brute: String in texte.split("\n"):
		var ligne := ligne_brute.strip_edges()
		if ligne.begins_with("["):
			# Une autre section commence : la nôtre est finie.
			dans_section = ligne == "[autoload]"
			continue
		if not dans_section or ligne == "" or ligne.begins_with(";"):
			continue
		var egal := ligne.find("=")
		if egal <= 0:
			continue
		noms.append(ligne.substr(0, egal).strip_edges())
	return noms

## Le banc prouve d'abord qu'il a lu quelque chose. Sans ce contrôle, une section
## renommée ou une forme de ligne changée rendrait une liste vide — et tous les
## contrôles suivants passeraient, faute de trouver quoi que ce soit à contredire.
func _test_lecture(noms: PackedStringArray) -> void:
	print("\n[La lecture a ramené quelque chose]")
	_check("la section [autoload] est trouvée et non vide", noms.size() > 0,
		"project.godot lu : %d octets" % FileAccess.get_file_as_string(PROJET).length())
	_check("elle contient plusieurs déclarations", noms.size() >= 6, str(noms.size()))
	for nom: String in REQUIS:
		_check("« %s » est déclaré" % nom, noms.has(nom),
			"absent de [autoload] — une fonction entière disparaît en silence")

func _test_ordre(noms: PackedStringArray) -> void:
	print("\n[L'ordre]")
	if noms.is_empty():
		return

	# Le message d'échec porte la marche à suivre : le commentaire qui la donnait
	# a été retiré de project.godot, où Godot ne l'aurait pas laissé vivre.
	_check("« %s » est déclaré EN PREMIER" % PREMIER, noms[0] == PREMIER,
		("le premier est « %s ». " % noms[0])
		+ "Un correctif .pck monté après un autoload ne le recouvre plus, "
		+ "sans erreur : remettre %s en tête de la section [autoload]." % PREMIER)

	for regle: Array in APRES:
		var apres := str(regle[0])
		var avant := str(regle[1])
		var i := noms.find(apres)
		var j := noms.find(avant)
		if i < 0 or j < 0:
			continue  # L'absence est déjà signalée par _test_lecture.
		_check("« %s » est déclaré après « %s »" % [apres, avant], i > j,
			"les liaisons de touches sauvegardées doivent recouvrir les "
			+ "liaisons par défaut, pas l'inverse — sinon le remappage du "
			+ "joueur est perdu à chaque lancement, en silence.")
