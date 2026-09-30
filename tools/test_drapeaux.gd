## Test headless de la lecture des drapeaux de lancement (répétition du test d'Adrien, D3).
##
## Le défaut : la moitié des drapeaux n'était lue qu'après `--`, l'autre moitié des deux
## côtés, et rien ne le disait (`godot --path . --lacet=0 --sans-usure` donnait le lacet 0
## AVEC les murs abîmés). Deux gardes :
##
## 1. **Aucun script de la racine ne relit la ligne de commande lui-même** : tout passe par
##    `DrapeauxDeLancement` (`drapeaux_de_lancement.gd`). C'est ce qui empêche le défaut de
##    revenir par le prochain drapeau ajouté.
## 2. **La même liste de drapeaux donne le même état, avant et après `--`**, et chaque
##    drapeau y change quelque chose (sans quoi l'égalité ne prouverait rien). Le test se
##    relance lui-même en sous-processus, une fois par position ; la ligne de commande ne
##    se change pas en cours d'exécution.
##
## ⚠️ `--pate D` n'est pas essayé AVANT `--` : un mot nu (`D`) parmi les arguments du
## moteur peut être pris par Godot pour autre chose qu'une valeur de drapeau.
##
## Lancer : godot --headless --path . --script res://tools/test_drapeaux.gd
extends SceneTree

const SONDE := "--sonde-drapeaux"
const DRAPEAUX := ["--sans-usure", "--sans-beaute", "--encre-essai", "--pochoirs-essai",
	"--sans-fusee-rouge-long", "--mannequin", "--corps-detaille", "--corps=portraits",
	"--menus=ancien", "--sans-led-murs", "--faisceau", "--sans-fumee-masque", "--lacet=0",
	"--sans-corps-soi-sombre", "--sans-fusee-rouge-sang",
	# GV1bis — la fumée : le retour aux couches, la taille fine, le trait de GV1 (jamais le défaut), le relief du bruit.
	"--fumee-couches", "--fumee-voxels=fin", "--fumee-encre=cotes", "--fumee-relief=bruit"]

var _failures := 0

func _init() -> void:
	if DrapeauxDeLancement.present(SONDE):
		_sonder()
		return
	print("=== Test des drapeaux de lancement, avant et après -- (D3) ===")
	_test_une_seule_lecture()
	_test_meme_etat_des_deux_cotes()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


## Le sous-processus : imprime l'état que le jeu tire de SA ligne de commande.
func _sonder() -> void:
	var volumes := IsoVolumes.new()
	var etat := {
		"usure": IsoMateriaux.usure_essai_active(),
		"beaute": IsoMateriaux.beaute_active(),
		"encre": IsoMateriaux.encre_essai_active(),
		"pochoirs": ArenaDecor.pochoirs_actifs(),
		"plein_feu": FuseeModele.duree_plein_feu,
		"mannequin": VoxelCatalogue.mannequin_actif(),
		"detail": VoxelCatalogue.detail_actif(),
		"tenue": VoxelCatalogue.tenue(),
		"menus": MenuArtwork.reglage_art(),
		"led": MurLed.est_actif(),
		"faisceau": volumes.faisceaux_actifs,
		"fumee_masque": volumes.masque_fumee,
		"fumee_voxel": volumes.fumee_voxel,
		"fumee_taille": volumes.variante_voxel,
		"fumee_encre": volumes.encre_voxel,
		"fumee_relief": volumes.relief_voxel,
		"soi_sombre": VoxelCatalogue.soi_sombre_actif(),
		"rouge_sang": load("res://fusee_couleur.gd").rouge_sang,
		"lacet": load("res://settings_manager.gd").lacet_applique(DrapeauxDeLancement.arguments()),
	}
	volumes.free()
	print("ETAT ", JSON.stringify(etat))
	quit(0)


func _test_une_seule_lecture() -> void:
	var fautifs := PackedStringArray()
	var dossier := DirAccess.open("res://")
	for fichier in dossier.get_files():
		if not fichier.ends_with(".gd") or fichier == "drapeaux_de_lancement.gd":
			continue
		var n := 0
		for ligne in FileAccess.get_file_as_string("res://" + fichier).split("\n"):
			n += 1
			var code := ligne.strip_edges()
			if code.begins_with("#"):
				continue
			if code.contains("OS.get_cmdline_user_args") or code.contains("OS.get_cmdline_args"):
				fautifs.append("%s:%d" % [fichier, n])
	_check("aucun script de la racine ne relit la ligne de commande hors de DrapeauxDeLancement",
		fautifs.is_empty(), ", ".join(fautifs))


func _test_meme_etat_des_deux_cotes() -> void:
	var sans := _etat_lance([SONDE])
	var avant := _etat_lance(DRAPEAUX + ["--", SONDE])
	var apres := _etat_lance([SONDE] + DRAPEAUX)
	_check("les trois sondes répondent", not sans.is_empty() and not avant.is_empty()
		and not apres.is_empty(), "%s / %s / %s" % [sans, avant, apres])
	if sans.is_empty() or avant.is_empty() or apres.is_empty():
		return
	for cle in sans:
		_check("« %s » : chaque drapeau change l'état (après --)" % cle,
			str(apres[cle]) != str(sans[cle]), "%s = %s dans les deux cas" % [cle, sans[cle]])
		_check("« %s » : même état avant et après --" % cle,
			str(avant[cle]) == str(apres[cle]), "avant %s, après %s" % [avant[cle], apres[cle]])


## `args` : ce qui suit `--script` ; un `--` doit y figurer pour séparer les drapeaux du
## jeu, sinon il est ajouté en tête.
func _etat_lance(args: Array) -> Dictionary:
	var ligne := ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/test_drapeaux.gd"]
	if not args.has("--"):
		ligne.append("--")
	ligne.append_array(args)
	var sortie := []
	OS.execute(OS.get_executable_path(), PackedStringArray(ligne), sortie, true)
	for bloc in sortie:
		for l in String(bloc).split("\n"):
			if l.begins_with("ETAT "):
				var etat = JSON.parse_string(l.substr(5))
				return etat if etat is Dictionary else {}
	return {}


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")
