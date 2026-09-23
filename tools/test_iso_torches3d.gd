## ISO12 L1 — les torches en lumière 3D : le miroir d'une torche 2D, classe par classe, orientation par orientation.
##
## Ce que cette suite prouve, sans fenêtre, sur le VRAI miroir (`lumieres_iso.gd::_torche`) et les dix classes de la table
## d'outillage (`tools/torches.gd`, dont `test_torches.gd` garde l'égalité avec le jeu) :
## - la lampe 3D est à la position de la torche 2D, à la hauteur du canon de la posture (debout, accroupi) ;
## - elle vise, à l'horizontale, la direction du cône 2D, sous seize orientations (piège ISO11 L1 : une lecture qui décide
##   d'un état se vérifie sous toutes les orientations du corps), et elle penche vers le sol ;
## - **elle COUVRE l'empreinte 2D** — sol et faces jusqu'au mur haut, de la lampe au bout de la portée : au plus
##   `HORS_MAX` de l'aire hors du spot, et seulement à moins de `BANDE_MAX` px de la lampe. Hors du spot, la garde du relief
##   rend R = 1 et une face y saute de relief : c'est la couture que le plancher de 75° a retirée (45° laissait jusqu'à 2 %
##   de l'empreinte dehors, jusqu'à 105 px de la lampe) ;
## - elle s'éteint avec sa source (éteinte, cachée, énergie nulle) et se rallume avec elle ;
## - en mode A (`ombres` faux, le GO réduit), la torche ne porte pas d'ombre.
##
## Ce qu'elle ne prouve pas : la couleur rendue. Le jugement sur image est au banc (`tools/banc_lumiere3d.gd`,
## `--cone-plancher=45` pour l'avant).
extends SceneTree

const Torches := preload("res://tools/torches.gd")
const WD := preload("res://weapon_data.gd")
const LumieresIsoT := preload("res://lumieres_iso.gd")
const IsoGeometrieT := preload("res://iso_geometrie.gd")

## La part de l'aire de l'empreinte 2D qui peut sortir du spot, et jusqu'où de la lampe (le corps du porteur : la lampe est
## à 28 px devant son centre).
const HORS_MAX := 0.005
const BANDE_MAX := 30.0
const ORIENTATIONS := 16
## Les facteurs de portée : celui du jeu (`FACTEUR_PORTEE_DEFAUT` de `settings_manager.gd`) et la portée pleine
## (`--torche=1`). Une portée courte est le cas le plus dur : la lampe y est haute devant la distance.
const FACTEURS := [0.75, 1.0]

var _failures := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if not ok:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ISO12 L1 — LES TORCHES EN LUMIÈRE 3D ===")
	var monde := Node2D.new()
	root.add_child(monde)
	var joueur := Node2D.new()
	joueur.name = "Joueur"
	joueur.position = Vector2(700.0, 500.0)
	monde.add_child(joueur)
	var source := PointLight2D.new()
	source.name = "Flashlight"
	source.position = Vector2(28.0, 0.0)
	source.energy = 1.0
	joueur.add_child(source)
	var miroir: Node3D = LumieresIsoT.new()
	root.add_child(miroir)
	miroir.set("ombres", false)
	var mur_haut := IsoGeometrieT.hauteur_mur_haut() * MursBas.TUILE
	var facteur_avant := WD.facteur_portee

	var pire := {"hors": 0.0, "bande": 0.0, "nom": ""}
	for facteur in FACTEURS:
		WD.facteur_portee = facteur
		for t in Torches.ARMES:
			var arme := WD.new()
			arme.torch_angle_deg = float(t["angle"])
			arme.torch_scale = float(t["echelle"])
			for accroupi in [false, true]:
				var h := MursBas.hauteur_de_posture(accroupi)
				var nom := "%s ×%.2f %s" % [t["fichier"], facteur, "accroupi" if accroupi else "debout"]
				var echecs_avant := _failures
				for k in ORIENTATIONS:
					joueur.rotation = TAU * k / ORIENTATIONS
					var vus := {}
					miroir.call("_torche", source, arme, h, "torche", vus)
					var l := (miroir.get("_pool") as Dictionary).get(source.get_instance_id()) as SpotLight3D
					_check("%s : une SpotLight3D par torche" % nom, l != null)
					if l == null:
						continue
					_verifier_lampe(nom, k, l, source, arme, h)
					var c := _couverture(l, source, arme, mur_haut)
					_check("%s, orientation %d : au plus %.1f %% de l'empreinte hors du spot" % [nom, k, HORS_MAX * 100.0],
						c[0] <= HORS_MAX, "%.2f %%" % (c[0] * 100.0))
					_check("%s, orientation %d : le manque reste à moins de %.0f px de la lampe" % [nom, k, BANDE_MAX],
						c[1] <= BANDE_MAX, "%.0f px" % c[1])
					if c[0] > pire["hors"]:
						pire = {"hors": c[0], "bande": c[1], "nom": nom}
				if _failures == echecs_avant:
					print("  ✓ %s : position, visée, couverture sous %d orientations" % [nom, ORIENTATIONS])
	print("  · la pire couverture : %s, %.2f %% hors du spot, jusqu'à %.0f px de la lampe"
		% [pire["nom"], pire["hors"] * 100.0, pire["bande"]])
	WD.facteur_portee = facteur_avant

	_extinction(miroir, source)
	_sortir()


func _verifier_lampe(nom: String, k: int, l: SpotLight3D, source: PointLight2D, arme: WeaponData, h: float) -> void:
	var p := source.global_position
	_check("%s, orientation %d : allumée avec sa source" % [nom, k], l.visible)
	_check("%s, orientation %d : à la position 2D, à hauteur de canon" % [nom, k],
		l.global_position.distance_to(Vector3(p.x, h, p.y)) < 0.01, str(l.global_position))
	var axe := -l.global_transform.basis.z
	var dir_2d := Vector2.RIGHT.rotated(source.global_rotation)
	var horizontal := Vector2(axe.x, axe.z).normalized()
	_check("%s, orientation %d : vise la direction du cône 2D" % [nom, k],
		horizontal.dot(dir_2d) >= cos(deg_to_rad(0.5)), "%s contre %s" % [str(horizontal), str(dir_2d)])
	_check("%s, orientation %d : penche vers le sol" % [nom, k], axe.y < 0.0)
	_check("%s, orientation %d : cône au moins celui de la classe + %.0f°" % [nom, k, LumieresIsoT.CONE_EN_PLUS_DEG],
		l.spot_angle >= minf(arme.torch_angle_deg + LumieresIsoT.CONE_EN_PLUS_DEG, 89.0) - 0.01)
	_check("%s, orientation %d : portée au-delà de la portée 2D" % [nom, k],
		l.spot_range >= arme.portee_torche() * LumieresIsoT.PORTEE_EN_PLUS - 0.01)
	_check("%s, orientation %d : sans ombre en mode A" % [nom, k], not l.shadow_enabled)


## [part de l'aire hors du spot, distance à la lampe du point le plus loin hors du spot]. L'empreinte 2D : le cône de demi-angle
## `torch_angle_deg`, de la lampe à `portee_torche()`, au sol et sur une face dressée jusqu'au mur haut (mi-hauteur et sommet).
## L'aire au sol d'un anneau croît comme la distance : chaque échantillon pèse sa distance.
func _couverture(l: SpotLight3D, source: PointLight2D, arme: WeaponData, mur_haut: float) -> Array:
	var lampe := l.global_position
	var axe := -l.global_transform.basis.z
	var cos_spot := cos(deg_to_rad(l.spot_angle))
	var p := source.global_position
	var dir_2d := Vector2.RIGHT.rotated(source.global_rotation)
	var portee := arme.portee_torche()
	var demi := deg_to_rad(arme.torch_angle_deg)
	var total := 0.0
	var hors := 0.0
	var bande := 0.0
	for i in range(1, 121):
		var d := portee * i / 120.0
		for j in range(-20, 21):
			var sol := p + dir_2d.rotated(demi * j / 20.0) * d
			for z in [0.0, mur_haut * 0.5, mur_haut]:
				var v := Vector3(sol.x, z, sol.y) - lampe
				total += d
				if v.normalized().dot(axe) < cos_spot or v.length() > l.spot_range:
					hors += d
					bande = maxf(bande, d)
	return [hors / total, bande]


func _extinction(miroir: Node3D, source: PointLight2D) -> void:
	var arme := WD.new()
	var h := MursBas.hauteur_de_posture(false)
	var cas := [
		["éteinte", func(): source.enabled = false, func(): source.enabled = true],
		["cachée", func(): source.visible = false, func(): source.visible = true],
		["énergie nulle", func(): source.energy = 0.0, func(): source.energy = 1.0],
	]
	for c in cas:
		(c[1] as Callable).call()
		miroir.call("_torche", source, arme, h, "torche", {})
		var l := (miroir.get("_pool") as Dictionary).get(source.get_instance_id()) as SpotLight3D
		_check("source %s : la lampe 3D s'éteint" % c[0], l != null and not l.visible)
		(c[2] as Callable).call()
		miroir.call("_torche", source, arme, h, "torche", {})
		_check("source %s puis rallumée : la lampe 3D se rallume" % c[0], l != null and l.visible)
	if _failures == 0:
		print("  ✓ éteinte, cachée, énergie nulle : la lampe 3D suit sa source, et se rallume")


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
