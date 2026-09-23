## ISO13, lot A — LA LUMIÈRE QUI MODÈLE UN CORPS (chantier d'ISO7 Beauté, 2026-09-24).
##
## Le mannequin (`iso_corps_mannequin.gdshaderinc`) monte la face d'un corps tournée vers la lumière et descend celle qui
## lui tourne le dos. Cette lumière doit être celle qui éclaire VRAIMENT le corps (ordre de la session cloud) : ce module la
## calcule, pour chaque corps et à chaque image, depuis les `Light2D` du jeu — la même liste que le miroir d'ISO12
## (`lumieres_iso.gd` : torches, rétrodiffusion, flash de tir, fusées, braises, mine, faisceaux fantômes).
##
## Chaque lampe pèse son intensité (énergie × luminance de sa couleur), décroît linéairement jusqu'à son rayon, ne compte
## pas hors de son cône (une torche), ni derrière un mur (un rayon de physique sur la couche des murs, comme les occluders
## de la 2D). La direction est la moyenne PONDÉRÉE des directions du corps vers chaque lampe ; sa longueur (0..1) dit à
## quel point la lumière vient d'un seul côté — deux lampes opposées et égales s'annulent, le modelé s'efface.
##
## ⚠️ **Pourquoi elle ne peut pas s'inverser** : c'est une géométrie (du corps VERS la lampe), pas un gradient d'image. Le
## Lambert d'ISO7b lisait le gradient de la lightmap, c'est-à-dire le BORD d'une tache de lumière, et changeait de sens
## en traversant un cône. Ici une lampe seule donne toujours une direction qui pointe sur elle
## (`tools/test_corps_mannequin.gd` le vérifie sur un tour complet, murs et cônes compris).
##
## La propre torche d'un joueur l'éclaire de face par sa rétrodiffusion (`BodyLight`, posée 18 px devant lui) : c'est ce
## qui donne au mannequin des illustrations son côté éclairé par sa propre lampe.
class_name MannequinIso
extends RefCounted

## Sous ce poids total, pas de direction : un corps dans le noir n'a pas de côté.
const POIDS_MINIMUM := 0.02
## La marge du bord d'un cône de torche, en radians : le poids y tombe à 0 en douceur plutôt que d'un coup.
const BORD_DU_CONE := 0.12


## Le poids d'une lampe sur un corps en `corps` (pixels du monde). Une lampe :
## {"position": Vector2, "intensite": float, "rayon": float, "cone": Vector2 (ZERO pour une omni), "demi_angle": float}.
static func poids(lampe: Dictionary, corps: Vector2) -> float:
	var vers: Vector2 = corps - Vector2(lampe["position"])
	var dist := vers.length()
	var rayon := float(lampe.get("rayon", 0.0))
	if rayon <= 0.0 or dist >= rayon:
		return 0.0
	var w := float(lampe.get("intensite", 0.0)) * (1.0 - dist / rayon)
	var cone: Vector2 = lampe.get("cone", Vector2.ZERO)
	if cone != Vector2.ZERO:
		if dist < 0.5:
			return 0.0
		var ecart := absf(cone.angle_to(vers))
		var demi := float(lampe.get("demi_angle", PI))
		w *= clampf((demi - ecart) / BORD_DU_CONE + 0.5, 0.0, 1.0)
	return maxf(w, 0.0)


## La direction horizontale vers la lumière dominante sur un corps en `corps`, longueur 0..1. `occulte` (facultatif) :
## `func(de: Vector2, vers: Vector2) -> bool`, vrai si un mur coupe la ligne.
static func direction_dominante(corps: Vector2, lampes: Array, occulte: Callable = Callable()) -> Vector2:
	var somme := Vector2.ZERO
	var total := 0.0
	for l in lampes:
		var lampe := l as Dictionary
		var w := poids(lampe, corps)
		if w <= 0.0:
			continue
		var vers_lampe: Vector2 = Vector2(lampe["position"]) - corps
		if vers_lampe.length() < 0.5:
			continue
		if occulte.is_valid() and bool(occulte.call(corps, Vector2(lampe["position"]))):
			continue
		somme += vers_lampe.normalized() * w
		total += w
	if total < POIDS_MINIMUM:
		return Vector2.ZERO
	return somme / total


## Les lampes du jeu à cette image, décrites pour `direction_dominante` — la même liste que `LumieresIso.suivre`.
static func lampes_du_jeu(main: Node) -> Array:
	var out: Array = []
	for j in 2:
		var joueur = main.get("p1") if j == 0 else main.get("p2")
		if not is_instance_valid(joueur):
			continue
		var arme: WeaponData = joueur.get("current_weapon")
		_torche(out, joueur.get_node_or_null(^"Flashlight") as Light2D, arme)
		_omni(out, joueur.get_node_or_null(^"MuzzleFlash") as Light2D)
		_omni(out, joueur.get_node_or_null(^"BodyLight") as Light2D)
	for j in 2:
		var fantome := main.get("ghost_p%d" % (j + 1)) as Node2D
		if fantome == null or not fantome.visible:
			continue
		var snap = main.get("current_snap")
		var arme_rejouee: WeaponData = snap.get("p%d_weapon" % (j + 1)) if snap != null else null
		_torche(out, fantome.get_node_or_null(^"Light") as Light2D, arme_rejouee)
		_omni(out, fantome.get_node_or_null(^"Flash") as Light2D)
	var conteneur: Node = main.get("bullet_container")
	if conteneur != null:
		for noeud in conteneur.get_children():
			if not (noeud is Node2D) or (noeud as Node).is_queued_for_deletion():
				continue
			for nom in [^"Halo", ^"Lueur", ^"Embrasement"]:
				_omni(out, noeud.get_node_or_null(nom) as Light2D)
			var faisceau := noeud.get_node_or_null(^"Faisceau") as Light2D
			if faisceau != null and "classe_du_poseur" in noeud:
				_torche(out, faisceau, noeud.get("classe_du_poseur") as WeaponData)
	return out


## Vrai si un mur coupe la ligne de `de` à `vers` — pour `direction_dominante`, dans l'espace de physique de `noeud`.
static func occultation(noeud: Node2D, exclus: Array = []) -> Callable:
	var espace := noeud.get_world_2d().direct_space_state
	return func(de: Vector2, vers: Vector2) -> bool:
		var q := PhysicsRayQueryParameters2D.create(de, vers, MapGeometry.WALL_LAYER)
		q.exclude = exclus
		return not espace.intersect_ray(q).is_empty()


static func _allumee(source: Light2D) -> bool:
	return source != null and source.enabled and source.is_visible_in_tree() and source.energy > 0.001


static func _intensite(source: Light2D) -> float:
	var c := source.color
	return source.energy * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)


static func _omni(out: Array, source: Light2D) -> void:
	if not _allumee(source):
		return
	var rayon := 64.0
	if source.texture != null:
		rayon = float(source.texture.get_width()) * source.texture_scale * 0.5
	out.append({"position": source.global_position, "intensite": _intensite(source), "rayon": rayon,
		"cone": Vector2.ZERO, "demi_angle": PI})


static func _torche(out: Array, source: Light2D, arme: WeaponData) -> void:
	if not _allumee(source) or arme == null:
		return
	out.append({"position": source.global_position, "intensite": _intensite(source), "rayon": arme.portee_torche(),
		"cone": Vector2.RIGHT.rotated(source.global_rotation), "demi_angle": deg_to_rad(arme.torch_angle_deg)})
