extends SceneTree
## Ce que les corps HABILLÉS coûtent en géométrie, compté exactement plutôt que mesuré.
##
## Un corps est fait de boîtes, et `VoxelCorps._boite()` crée DEUX `MeshInstance3D` par boîte : la
## boîte visible et son jumeau de profondeur. Une tenue peinte (`--corps=portraits`, `sombre`,
## `sombre2`, `sombre3`) ajoute la bouteille dans le dos aux six classes qui la portent — une boîte,
## donc deux maillages. Ce script le vérifie classe par classe au lieu de le déduire.
##
##     godot --headless --path . --script res://tools/compte_boites_corps.gd -- --corps=sombre
##
## L'argument de tenue se passe APRÈS `--` : `VoxelCatalogue.tenue()` lit `get_cmdline_USER_args()`.
## Sans lui, le gris d'ISO3. Le script imprime d'abord ce que la ligne de commande a été comprise
## dire : c'est la preuve que le drapeau porte, réclamée avant tout chiffre.

func _initialize() -> void:
	var demandee := VoxelCatalogue.tenue()
	print("TENUE lue par le jeu : « %s »   (arguments utilisateur : %s)"
		% [demandee, " ".join(OS.get_cmdline_user_args())])
	print("")

	var lignes := []
	var total_gris := 0
	var total_tenue := 0
	for slug in VoxelCatalogue.slugs():
		var gris := _compter(slug, "")
		var habille := _compter(slug, demandee)
		total_gris += gris
		total_tenue += habille
		lignes.append([slug, gris, habille, habille - gris])

	print("COMPTE  classe          maillages_gris  maillages_tenue  delta")
	for l in lignes:
		print("COMPTE  %-14s %8d %15d %+7d" % [l[0], l[1], l[2], l[3]])
	print("COMPTE  TOTAL (10)     %8d %15d %+7d" % [total_gris, total_tenue, total_tenue - total_gris])
	print("")
	# ⚠️ Le delta est PAR CLASSE PORTEUSE, jamais une moyenne sur les dix : une moyenne dirait
	# « +1,2 » d'un coût que six classes paient en entier et quatre pas du tout.
	var porteuses := 0
	var par_porteuse := 0
	for l in lignes:
		if int(l[3]) > 0:
			porteuses += 1
			par_porteuse = int(l[3])
	_shaders_des_matieres(demandee)
	print("COMPTE  %d classes sur %d portent la bouteille, +%d maillages chacune."
		% [porteuses, lignes.size(), par_porteuse])
	print("COMPTE  Un duel où les DEUX joueurs la portent : +%d maillages. Où aucun (le pompe) : +0."
		% (2 * par_porteuse))
	quit(0)


## Les `MeshInstance3D` réellement posés sous un corps construit dans la tenue `nom`.
## On force la tenue AVANT `construire()` : c'est `construire()` qui pose la géométrie, et
## `porter_tenue()` ne touche ensuite que des uniformes.
func _compter(slug: String, nom: String) -> int:
	VoxelCatalogue.forcer_tenue = nom
	var corps := VoxelCorps.new()
	root.add_child(corps)
	var ok := corps.construire(slug)
	var n := 0
	if ok:
		n = _maillages(corps)
	else:
		push_error("construire() a refusé la classe %s" % slug)
	corps.queue_free()
	VoxelCatalogue.forcer_tenue = "-"
	return n


func _maillages(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for e in n.get_children():
		c += _maillages(e)
	return c


## Les SHADERS des matières d'un corps, gris contre tenue : la tenue change-t-elle le programme, ou
## seulement des uniformes ? On imprime le chemin de ressource ET une empreinte du code, parce que
## deux `Shader` distincts peuvent porter le même chemin d'`#include`.
##
## ⚠️ Un shader identique ne veut PAS dire un coût identique : `iso_corps_portrait.gdshaderinc` ouvre
## `portrait_fiche()` et `portrait_teindre()` par `if (portrait < 0.5) return ...;`. Le gris sort à la
## première ligne ; la tenue exécute tout le reste, par pixel. La bascule est un UNIFORME, invisible
## à toute comparaison de shaders — d'où cette mise en garde imprimée avec le résultat.
func _shaders_des_matieres(nom: String) -> void:
	print("")
	print("SHADER  (pistolet, une classe porteuse)")
	for etat in [["gris", ""], ["tenue", nom]]:
		VoxelCatalogue.forcer_tenue = etat[1]
		var corps := VoxelCorps.new()
		root.add_child(corps)
		corps.construire("pistolet")
		var vus := {}
		_recolter(corps, vus)
		var cles := vus.keys()
		cles.sort()
		for k in cles:
			print("SHADER  %-6s %-34s code %s  (%d maillages)" % [etat[0], k, vus[k][0], vus[k][1]])
		corps.queue_free()
		VoxelCatalogue.forcer_tenue = "-"
	print("SHADER  ⚠️ Même shader ≠ même coût : `portrait` est un UNIFORME, et le gris sort de")
	print("SHADER     `portrait_fiche()` à sa première ligne quand la tenue exécute tout le corps.")


func _recolter(n: Node, vus: Dictionary) -> void:
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).material_override
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var sh: Shader = (m as ShaderMaterial).shader
			var chemin := sh.resource_path if sh.resource_path != "" else "(sans chemin)"
			var empreinte := str(sh.code.hash())
			if not vus.has(chemin):
				vus[chemin] = [empreinte, 0]
			vus[chemin][1] += 1
	for e in n.get_children():
		_recolter(e, vus)
