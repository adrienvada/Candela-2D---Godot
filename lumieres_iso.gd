## Les lumières 3D de la vue iso — chantier ISO12, lot 0 (plan-delta accepté par la session cloud, 2026-09-15 22:15).
##
## **Un MIROIR, pas une seconde logique.** Chaque lumière 3D recopie, à chaque image, une source Light2D du jeu :
## allumée ou non, énergie, couleur, position, hauteur. La liste des sources est FERMÉE :
## - la torche (`Flashlight`) et le flash de tir (`MuzzleFlash`) de chaque joueur ;
## - leurs doubles de killcam (`GhostPN/Light`, `GhostPN/Flash`), pilotés par l'instantané ;
## - le halo des fusées (`Halo`), la lueur des braises (`Lueur`), l'embrasement de la mine (`Embrasement`) et le
##   faisceau de la torche fantôme (`Faisceau`).
## - la RÉTRODIFFUSION : `BodyLight` de chaque joueur et le `Halo` de la torche fantôme (drapeau `retrodiffusion`).
##   ⚠️ Écartée au plan, rendue après la première passe du banc (2026-09-15 22:45) : sans elle, la vue 3D montrait MOINS que
##   la 2D — le halo qui trahit le porteur et le corps de J2 disparaissaient. La bride empêche d'en montrer plus, rien
##   n'empêchait d'en montrer moins ; le rendu Compatibility ne simule pas la lumière qui revient d'une surface.
## JAMAIS : `ambient_light` (la silhouette de soi, lumière privée d'une vue), les échos privés. Aucune lumière qui ne soit une source
## du jeu : le noir absolu tient par construction, et la bride (`sol_iso_eclaire`, `mur_iso_eclaire`) le garantit pixel
## par pixel — là où la lightmap de la vue dit 0, la couleur vaut 0.
##
## **Équité** : les constantes d'énergie par type de source sont les mêmes pour les deux joueurs et les deux vues, sans
## curseur. Le cône 3D est un peu plus large et un peu plus long que le cône 2D : le bord visible appartient à la bride,
## la 3D ne doit pas dessiner un second bord dans le cône.
##
## Pas de `class_name` : chargé par son chemin, lisible par les suites en `--script` sans import préalable.
extends Node3D

const TUILE := 35.0
## Le cône 3D dépasse le cône 2D de cinq degrés, adouci (décision de la session cloud, 22:15).
const CONE_EN_PLUS_DEG := 5.0
## L'angle plancher d'un spot de torche. ⚠️ Preuve rejouée du 2026-09-15 (23:48) : le faisceau de 5° du Braconnier, en spot de 10°,
## ne touchait le sol qu'à ~130 px devant la lampe et la bande proche restait noire en 3D alors que la 2D la montre. Le bord
## visible du cône est celui de la bride : le spot 3D doit seulement COUVRIR toute la zone du cône 2D, de la lampe au bout.
const CONE_PLANCHER_DEG := 45.0
const ATTENUATION_ANGULAIRE := 2.0
## La portée 3D dépasse un peu la portée 2D, pour la même raison.
const PORTEE_EN_PLUS := 1.15
## La torche vise le point du sol à cette fraction de sa portée. ⚠️ Penchée de 8° seulement (première passe du banc), elle
## ne touchait le sol qu'à ~250 px devant la lampe : le sol entre le porteur et le mur restait noir.
const VISEE_AU_SOL_PORTEE := 0.5
## Les types de source. Les énergies sont calibrées au banc (`tools/banc_lumiere3d.gd`) : une par type, pour tous.
const TYPES := ["torche", "flash", "fusee", "braise", "mine", "torche_fantome", "retrodiffusion"]
## Calibrées au banc le 2026-09-15. Cinquième passe rapide (bandeau de LED figé), luminance moyenne là où la 2D est éclairée,
## 3D sur 2D : cône de torche 1,06 à 1,29 avec 6, halo de fusée 0,77 à 0,84 avec 20, rétrodiffusion 1,10 avec 1. Puis ramenées
## vers 1,0 ± 0,1 (demande de la session cloud, 23:42) : torche 3,6 et fusée 52, à revérifier au banc.
## Les mêmes pour les deux joueurs et les deux vues : c'est de l'équité, pas un réglage.
var energie_par_type := {"torche": 3.6, "flash": 3.6, "fusee": 52.0, "braise": 52.0, "mine": 52.0, "torche_fantome": 3.6,
	"retrodiffusion": 0.8}
var retrodiffusion := true
## ISO12 — l'atténuation par type (`omni_attenuation` / `spot_attenuation`, 1 = inverse du carré, 0 = plat).
##
## ⚠️ **L'ATTÉNUATION PLATE A ÉTÉ ESSAYÉE PUIS RÉFUTÉE PAR LA MESURE (lot 0 quater).** Elle venait du principe « la 2D donne
## l'intensité, la 3D ne donne que le relief », et le principe est juste — c'est le mécanisme qui ne l'était pas. Aplatir
## supprime ce qui empêche plusieurs lampes de s'additionner au-delà du blanc : la fusée est passée à **42 932 pixels blancs
## contre 14 en 2D**, dès l'énergie ×1,0 (donc pas à cause d'un niveau trop haut). Et le rapport 3D/2D ne pouvait pas devenir
## constant : `lumière3D(x)` dépend du nombre de lampes qui atteignent le point, si bien que +70 % d'énergie a ÉLARGI l'écart
## entre cadrages (0,36-0,77 → 0,40-0,99) au lieu de le refermer.
##
## La décroissance de Godot revient donc, et elle est NÉCESSAIRE à la forme retenue : le relief divise la lumière par ce
## qu'elle donnerait au même point sur un sol plat, et la décroissance se simplifie dans ce rapport — elle doit être des deux
## côtés. Les valeurs sont celles du lot 0 ter ; elles seront rejugées une fois le relief en place.
var attenuation_par_type := {"fusee": 0.35, "braise": 0.6, "mine": 0.6}
var ombres := true
## Économies du brief, dans l'ordre : `ombres_omni` faux — pas d'ombre sur les omni (fusées, flashs, braises, mine,
## rétrodiffusion : six faces par omni et par image) ; `ombres_torches_joueurs_seules` vrai — une seule lumière ombrée par
## joueur, sa torche (la torche fantôme perd la sienne).
var ombres_omni := true
var ombres_torches_joueurs_seules := false
## `OmniLight3D.SHADOW_CUBE` : le seul mode d'ombre omni du rendu Compatibility (le double paraboloïde y est refusé à
## chaque image — premier passage du banc, 2026-09-15 22:45).
var mode_ombre_omni := OmniLight3D.SHADOW_CUBE

const IsoVolumesT := preload("res://iso_volumes.gd")

## instance_id de la Light2D → Light3D.
var _pool := {}


## Une image. `main` : le jeu ; `voxels` : les corps voxel de la présentation (pour le bout de l'arme).
func suivre(main: Node, voxels: Array) -> void:
	var vus := {}
	for j in 2:
		var joueur = main.p1 if j == 0 else main.p2
		if not is_instance_valid(joueur):
			continue
		var corps: Variant = voxels[j] if j < voxels.size() else null
		var arme: WeaponData = joueur.get("current_weapon")
		# En PIXELS : `MursBas.hauteur_de_posture` rend la hauteur du canon, celle que la balle et la lumière du jeu lisent
		# (debout, une tuile ; accroupi, sous le muret — « la torche d'un accroupi bute sur le mur »).
		var hauteur_px := MursBas.hauteur_de_posture(bool(joueur.get("accroupi")))
		_torche(joueur.get_node_or_null(^"Flashlight") as Light2D, arme, hauteur_px, "torche", vus)
		_omni(joueur.get_node_or_null(^"MuzzleFlash") as Light2D, "flash", _bout(corps, joueur, hauteur_px), vus)
		if retrodiffusion:
			var retro := joueur.get_node_or_null(^"BodyLight") as Light2D
			if retro != null:
				var pr := retro.global_position
				_omni(retro, "retrodiffusion", Vector3(pr.x, hauteur_px, pr.y), vus)
	for j in 2:
		var fantome := main.get("ghost_p%d" % (j + 1)) as Node2D
		if fantome == null or not fantome.visible:
			continue
		var snap = main.get("current_snap")
		var arme_rejouee: WeaponData = snap.get("p%d_weapon" % (j + 1)) if snap != null else null
		var accroupi_rejoue: bool = bool(snap.get("p%d_accroupi" % (j + 1))) if snap != null else false
		var h_px := MursBas.hauteur_de_posture(accroupi_rejoue)
		_torche(fantome.get_node_or_null(^"Light") as Light2D, arme_rejouee, h_px, "torche", vus)
		var flash_rejoue := fantome.get_node_or_null(^"Flash") as Light2D
		if flash_rejoue != null:
			var pf := flash_rejoue.global_position
			_omni(flash_rejoue, "flash", Vector3(pf.x, h_px, pf.y), vus)
	var conteneur: Node = main.get("bullet_container")
	if conteneur != null:
		for noeud in conteneur.get_children():
			if not (noeud is Node2D) or (noeud as Node).is_queued_for_deletion():
				continue
			if "_atterrie" in noeud and "graine" in noeud:
				_omni(noeud.get_node_or_null(^"Halo") as Light2D, "fusee", null, vus)
			elif "poseur_id" in noeud and "slug" in noeud:
				_omni(noeud.get_node_or_null(^"Lueur") as Light2D, "braise", null, vus)
				_omni(noeud.get_node_or_null(^"Embrasement") as Light2D, "mine", null, vus)
				var faisceau := noeud.get_node_or_null(^"Faisceau") as Light2D
				if faisceau != null:
					_torche(faisceau, noeud.get("classe_du_poseur") as WeaponData,
						MursBas.HAUTEUR_DEBOUT * 0.6 * TUILE, "torche_fantome", vus)
				var halo := noeud.get_node_or_null(^"Halo") as Light2D
				if retrodiffusion and halo != null and faisceau != null:
					var ph := halo.global_position
					_omni(halo, "retrodiffusion", Vector3(ph.x, MursBas.HAUTEUR_DEBOUT * 0.6 * TUILE, ph.y), vus)
	for id in _pool.keys():
		if not vus.has(id):
			(_pool[id] as Node).queue_free()
			_pool.erase(id)


## Combien de lumières 3D allumées cette image — le banc le compare au plafond par maillage.
func allumees() -> int:
	var n := 0
	for l: Light3D in _pool.values():
		if l.visible:
			n += 1
	return n


func _torche(source: Light2D, arme: WeaponData, hauteur_px: float, type: String, vus: Dictionary) -> void:
	if source == null or arme == null:
		return
	var l := _lumiere(source, true, vus) as SpotLight3D
	if not _recopier(source, l, type):
		return
	l.shadow_enabled = ombres and not (ombres_torches_joueurs_seules and type != "torche")
	var p := source.global_position
	var devant := Vector2.RIGHT.rotated(source.global_rotation)
	l.global_position = Vector3(p.x, hauteur_px, p.y)
	var au_sol := devant * arme.portee_torche() * VISEE_AU_SOL_PORTEE
	var cible := Vector3(p.x + au_sol.x, 0.0, p.y + au_sol.y)
	l.look_at(cible, Vector3.UP)
	l.spot_angle = clampf(maxf(arme.torch_angle_deg + CONE_EN_PLUS_DEG, CONE_PLANCHER_DEG), 1.0, 89.0)
	l.spot_angle_attenuation = ATTENUATION_ANGULAIRE
	l.spot_range = arme.portee_torche() * PORTEE_EN_PLUS


func _omni(source: Light2D, type: String, position_3d: Variant, vus: Dictionary) -> void:
	if source == null:
		return
	var l := _lumiere(source, false, vus) as OmniLight3D
	if not _recopier(source, l, type):
		return
	# La rétrodiffusion ne s'ombre pas : c'est la lumière qui revient sur le porteur, que son propre corps ne bouche pas. ⚠️ Preuve
	# rejouée (23:48) : ombrée, l'omni posée contre le corps voxel de J2 plongeait son propre halo dans l'ombre de ce corps.
	l.shadow_enabled = ombres and ombres_omni and not ombres_torches_joueurs_seules and type != "retrodiffusion"
	if position_3d is Vector3:
		l.global_position = position_3d
	else:
		var h := MursBasRendu.hauteur_source(source)
		var p := source.global_position
		l.global_position = Vector3(p.x, maxf(h, MursBasRendu.HAUTEUR_AU_RAS_DU_SOL) * TUILE, p.y)
	var rayon := 64.0
	if source.texture != null:
		rayon = float(source.texture.get_width()) * source.texture_scale * 0.5
	l.omni_range = rayon * PORTEE_EN_PLUS
	l.omni_attenuation = float(attenuation_par_type.get(type, 1.0))
	l.omni_shadow_mode = mode_ombre_omni


## Recopie l'état commun ; faux si la lumière est éteinte cette image.
func _recopier(source: Light2D, l: Light3D, type: String) -> bool:
	var allumee := source.enabled and source.is_visible_in_tree() and source.energy > 0.001
	l.visible = allumee
	if not allumee:
		return false
	l.light_color = source.color
	l.light_energy = source.energy * float(energie_par_type.get(type, 1.0))
	l.shadow_enabled = ombres
	l.light_specular = 0.0
	return true


func _lumiere(source: Light2D, spot: bool, vus: Dictionary) -> Light3D:
	var id := source.get_instance_id()
	vus[id] = true
	var l: Light3D = _pool.get(id, null)
	if l == null or not is_instance_valid(l) or (l is SpotLight3D) != spot:
		if l != null and is_instance_valid(l):
			l.queue_free()
		l = SpotLight3D.new() if spot else OmniLight3D.new()
		l.name = "%s_%d" % [source.name, id]
		add_child(l)
		_pool[id] = l
	return l


## Le bout de l'arme du corps voxel ; à défaut, le canon à hauteur de posture.
func _bout(corps: Variant, joueur: Node2D, hauteur_px: float) -> Vector3:
	var bout: Variant = IsoVolumesT._bout_de_l_arme(corps)
	if bout is Vector3:
		return bout
	var bouche := joueur.get_node_or_null(^"Muzzle") as Node2D
	var p := bouche.global_position if bouche != null else joueur.global_position
	return Vector3(p.x, hauteur_px, p.y)
