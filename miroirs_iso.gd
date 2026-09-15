class_name MiroirsIso
extends Node3D

## ISO4 — les objets debout, le leurre, la balle, le viseur et la ligne de visée dans la vue iso.
##
## La vue iso projette la lightmap 2D au sol, et tout ce qui y est dessiné s'y aplatit. Les objets qui
## ont un corps dans le jeu — ils arrêtent une balle ou occultent la lumière — se lèvent en voxels
## (`VoxelObjet`, vague 3 d'ISO Corps). Le leurre reçoit le corps voxel de la classe de son poseur, arme
## baissée (`VoxelCorps`). La balle, le viseur et la ligne de visée deviennent des quads posés au sol, que
## les murs 3D cachent comme ils cachent le sol. Les nappes et les volumes (suie, poussière, poudre,
## braises) restent à plat dans la lightmap : le jeu ne leur donne aucun corps.
##
## ⚠️ **Chaque sprite remplacé sort des lightmaps** (couche 0, rendue à l'extinction). Sans cela, il se
## dessinerait deux fois : debout en voxel, et à plat sous lui. Ses lumières et ses occluders restent.
##
## ⚠️ **Chaque voxel lit sa lumière dans ses capteurs, un par vue** — la règle des corps (ISO2) : un
## disque sous l'objet, sur la couche des objets de la vue (`couche_objets`, hors des masques des
## lightmaps), avec le masque de lumière et la courbe du sprite qu'il remplace. Un gadget prend la
## lumière du moteur, comme le décor (`capteur_objet.gdshader`) ; le leurre prend celle de l'ennemi dans
## la vue adverse, celle du moteur dans la vue de son poseur — ses deux silhouettes 2D, mot pour mot.
##
## Le miroir suit le conteneur des balles image par image, rejeu compris : la killcam y recrée gadgets,
## fusées et balles (`is_replay`), qui reçoivent leur miroir comme en direct.

const COUCHE_OBJETS := 128
const SHADER_OBJET := preload("res://capteur_objet.gdshader")
const SHADER_QUAD := preload("res://quad_iso.gdshader")
const SHADER_QUAD_ADDITIF := preload("res://quad_iso_additif.gdshader")
## Au-dessus du sol projeté, jamais dedans : sans ce décalage, le quad et le sol se disputent la
## profondeur pixel par pixel.
const HAUTEUR_QUAD_PX := 0.6
## La période des tirets de la ligne de visée (`player.gd` : 8 px pleins, 8 px vides).
const PERIODE_TIRETS_PX := 16.0

## Les sprites qu'un voxel remplace, par slug. La toile du voile, la lentille de la torche, les lumières
## et les voiles de fumée restent dans la lightmap.
const SPRITES_REMPLACES := {
	"mine": ["Visuel"],
	"torche_fantome": ["Visuel", "Tete"],
	"voile": ["PiquetG", "PiquetD"],
	"ombre": ["Visuel"],
	"gresillement": ["Visuel"],
	"fusee": ["Coeur", "Corps"],
	"leurre": ["Visuel", "VisuelPoseur"],
}

## Gadgets et lumières (2026-09-15) — le slug que le JEU donne à un gadget posé
## (`GameState.IMPLEMENTATIONS`) quand il diffère de la clé du catalogue des voxels.
##
## ⚠️ **Sans cette table, la mine et l'ombre habitée n'avaient pas de voxel en match.** Le jeu les pose
## sous `mine_magnesium` et `ombre_habitee` ; le catalogue (vague 3 d'ISO Corps) les nomme `mine` et
## `ombre`. `slug_objet` rendait donc "" pour elles, et elles restaient couchées dans la lightmap. La
## suite et le banc d'ISO4 posaient leurs gadgets sous les clés du catalogue (`g.slug = slug`), jamais par
## le vrai chemin : verts, ils ne pouvaient pas le voir. `tools/test_iso_gadgets.gd` pose désormais par
## `GameState._do_spawn_gadget`.
const SLUG_DU_CATALOGUE := {"mine_magnesium": "mine", "ombre_habitee": "ombre"}

var _miroirs := {}           # instance_id du nœud 2D -> Dictionary
var _couches := {}           # instance_id d'un CanvasItem retiré -> sa couche d'origine
var _quads_joueurs: Array = [{}, {}]
var _quads_balles := {}      # instance_id de la balle -> {"core": MeshInstance3D, "aura": MeshInstance3D}
var _plan := PlaneMesh.new()
var _quads_masques := false
## Gadgets et lumières — les volumes, les lueurs, l'onde et la toile (`iso_volumes.gd`).
var volumes := IsoVolumes.new()


func _init() -> void:
	name = "Miroirs"
	_plan.size = Vector2.ONE
	volumes.miroirs = self
	add_child(volumes)


## La couche de visibilité des disques des objets dans les capteurs de la vue `vue_id` : 128 ou 256.
static func couche_objets(vue_id: int) -> int:
	return COUCHE_OBJETS << vue_id


## Le slug du miroir d'un nœud du conteneur des balles, ou "" s'il reste à plat.
##
## ⚠️ **Reconnu par ses propriétés, jamais par son nom de classe.** `Bullet` et `Fusee` nomment
## l'autoload `NetworkManager` : les nommer ici rendait `MiroirsIso` — donc `Presentation3D` — impossible
## à compiler dans une suite headless (`extends SceneTree` compile avant les autoloads), et chaque suite
## qui nommait la présentation tombait avec (premier jet d'ISO4).
static func slug_objet(noeud: Node) -> String:
	if noeud == null:
		return ""
	if "poseur_id" in noeud and "slug" in noeud:
		var s := String(noeud.get("slug"))
		if s == "leurre":
			return "leurre"
		s = String(SLUG_DU_CATALOGUE.get(s, s))
		return s if VoxelCatalogueObjets.OBJETS.has(s) else ""
	if "_atterrie" in noeud and "graine" in noeud:
		return "fusee" if bool(noeud.get("_atterrie")) else ""
	return ""


## Une balle du jeu : sa traçante et ses rebonds, sans nommer sa classe (voir `slug_objet`).
static func est_une_balle(noeud: Node) -> bool:
	return noeud != null and "bounces_left" in noeud and noeud.get_node_or_null(^"Core") is Line2D


func nombre_de_miroirs() -> int:
	return _miroirs.size()


func miroir_de(noeud: Node) -> Node3D:
	var m: Dictionary = _miroirs.get(noeud.get_instance_id(), {})
	return m.get("voxel") if not m.is_empty() else null


func capteurs_de(noeud: Node) -> Array:
	var m: Dictionary = _miroirs.get(noeud.get_instance_id(), {})
	return m.get("capteurs", [null, null]) if not m.is_empty() else [null, null]


func quads_du_joueur(j: int) -> Dictionary:
	return _quads_joueurs[j]


func quads_de_la_balle(balle: Node) -> Dictionary:
	return _quads_balles.get(balle.get_instance_id(), {})


## Garde cachés les quads non éclairés — viseur, ligne de visée, balle — tant que `masques` est vrai.
## Pour le contrôle (b) du noir absolu (`tools/banc_iso.gd`), qui retire tout ce que la 2D dessine : ces
## quads SONT des dessins 2D sans lumière passés en 3D, et ils y étaient retirés avec leur lightmap.
func masquer_les_quads(masques: bool) -> void:
	_quads_masques = masques
	volumes.masquer(masques)


## Ce dessin 2D est-il retiré des lightmaps par le miroir d'un objet posé ? `IsoVolumes` le demande avant
## de rendre un dessin qu'il avait sorti (le cœur d'une fusée qui vient d'atterrir passe de la comète au
## voxel posé : une seule main le rend).
func tient_le_dessin(item: Object) -> bool:
	for m: Dictionary in _miroirs.values():
		if (m["sprites"] as Array).has(item):
			return true
	return false


## Une image : miroirs créés, posés ou retirés ; quads des joueurs et des balles. `vues` : les ids des
## vues projetées ; `parent_capteurs` : le nœud qui porte les sous-vues des capteurs.
func suivre(main: Node, vues: Array, style: int, parent_capteurs: Node) -> void:
	var conteneur: Node = main.get("bullet_container")
	var vus := {}
	if conteneur != null:
		for noeud in conteneur.get_children():
			if est_une_balle(noeud):
				_suivre_balle(noeud as Node2D, vus)
				continue
			var slug := slug_objet(noeud)
			if slug == "":
				continue
			var id := noeud.get_instance_id()
			vus[id] = true
			var m: Dictionary = _miroirs.get(id, {})
			if m.is_empty() or m["slug"] != slug or m["vues"] != vues:
				_retirer(id)
				m = _creer(noeud as Node2D, slug, main, vues, parent_capteurs)
				_miroirs[id] = m
			_poser(m, noeud as Node2D, style)
	for id in _miroirs.keys():
		if not vus.has(id):
			_retirer(id)
	for id in _quads_balles.keys():
		if not vus.has(id):
			_retirer_balle(id)
	_suivre_joueurs(main)
	# Gadgets et lumières — après les miroirs : une fusée qui vient d'atterrir a déjà son voxel, qui tient
	# son cœur, quand la comète le lâche.
	volumes.suivre(main, vues, style, parent_capteurs)


## Tout rendre : sprites à leur couche, capteurs et voxels libérés, quads retirés.
func vider() -> void:
	volumes.vider()
	for id in _miroirs.keys():
		_retirer(id)
	for id in _quads_balles.keys():
		_retirer_balle(id)
	for q: Dictionary in _quads_joueurs:
		for mi in q.values():
			if is_instance_valid(mi):
				(mi as Node).queue_free()
		q.clear()
	for id in _couches.keys():
		var item := instance_from_id(id) as CanvasItem
		if item != null and item.visibility_layer == Presentation3D.COUCHE_HORS_VUE:
			item.visibility_layer = _couches[id]
	_couches.clear()


# ---------------------------------------------------------------------------
# LES OBJETS ET LE LEURRE
# ---------------------------------------------------------------------------

func _creer(noeud: Node2D, slug: String, main: Node, vues: Array, parent_capteurs: Node) -> Dictionary:
	var ancre := Node3D.new()
	ancre.name = "Miroir_%s" % noeud.name
	ancre.scale = Vector3.ONE * float(CandelaTileSet.TILE_SIZE.x)
	add_child(ancre)
	var voxel: Node3D
	var rayon_lu := CapteurCorps.RAYON_PX - 3.0
	var poseur := int(noeud.get("poseur_id")) if "poseur_id" in noeud else -1
	if slug == "leurre":
		var corps := VoxelCorps.new()
		ancre.add_child(corps)
		corps.construire(_classe_du_leurre(noeud))
		corps.definir_lecture_au_bord(1.0)
		rayon_lu = minf(Presentation3D.RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0)
		voxel = corps
	else:
		var objet := VoxelObjet.new()
		ancre.add_child(objet)
		objet.construire(slug)
		rayon_lu = minf(float(VoxelCatalogueObjets.OBJETS[slug]["rayon_px"]) + 1.0, CapteurCorps.RAYON_PX - 3.0)
		voxel = objet
	voxel.call("definir_pixels_par_unite", 1.0)
	# Raccords de la vague — l'encre des arêtes des corps (ISO7, ISO Corps vague 5) sur les objets debout et le
	# leurre : ils partagent `corps_iso.gdshader`, le même crochet leur pose la même encre.
	IsoMateriaux.accorder_corps(voxel.call("materiau") as ShaderMaterial)
	var capteurs := [null, null]
	for id in vues:
		var masque := MapGeometry.WALL_LAYER
		var shader: Shader = SHADER_OBJET
		if slug == "leurre":
			if id == poseur:
				masque = 4  # `GadgetLeurre._monter_visuel` : « VisuelPoseur », light_mask 4
			else:
				masque = CanauxLumiere.masque_vue_adverse(poseur)
				shader = CapteurCorps.SHADER_ADVERSE
		var c := CapteurCorps.creer(id, 0, main.vp1.world_2d, couche_objets(id), masque)
		c.name = "CapteurObjetVue%d_%s" % [id + 1, noeud.name]
		(c.matiere() as ShaderMaterial).shader = shader
		parent_capteurs.add_child(c)
		capteurs[id] = c
	var sprites := []
	for nom in SPRITES_REMPLACES.get(slug, []):
		var s := noeud.get_node_or_null(NodePath(nom)) as CanvasItem
		if s != null:
			sprites.append(s)
			_retirer_de_la_lightmap(s)
	return {"slug": slug, "vues": vues.duplicate(), "ancre": ancre, "voxel": voxel, "capteurs": capteurs,
		"sprites": sprites, "rayon_lu": rayon_lu, "poseur": poseur}


## Le corps du leurre : la classe de son poseur, ou la première du catalogue — un repli de RENDU.
static func _classe_du_leurre(noeud: Node) -> String:
	var classe = noeud.get("classe_du_poseur")
	var s := String(classe.slug()) if classe != null and classe.has_method("slug") else ""
	return s if VoxelCatalogue.slugs().has(s) else String(VoxelCatalogue.slugs()[0])


func _poser(m: Dictionary, noeud: Node2D, style: int) -> void:
	var pos := noeud.global_position
	var voxel: Node3D = m["voxel"]
	var visee := Vector2(cos(noeud.global_rotation), sin(noeud.global_rotation))
	if m["slug"] == "leurre":
		var corps := voxel as VoxelCorps
		corps.poser({"position": pos, "visee": visee, "vitesse": Vector2.ZERO, "torche": false,
			"arme": corps.slug(), "arme_baissee": true, "t": 0.0})
	else:
		var lumiere := noeud.get("_lumiere") as Light2D if "_lumiere" in noeud else null
		(voxel as VoxelObjet).poser({"position": pos, "orientation": visee,
			"allumee": bool(noeud.get("_allumee")) if "_allumee" in noeud else false,
			"eteinte": m["slug"] == "fusee" and lumiere != null and not lumiere.enabled})
	var textures := [null, null]
	for id in 2:
		var c = m["capteurs"][id]
		if c != null:
			(c as CapteurCorps).suivre(pos, noeud.is_visible_in_tree())
			textures[id] = (c as CapteurCorps).get_texture()
	var t1: Texture2D = textures[0] if textures[0] != null else textures[1]
	var t2: Texture2D = textures[1] if textures[1] != null else textures[0]
	voxel.call("definir_capteur", t1, pos, CapteurCorps.MONDE_PX, float(m["rayon_lu"]), t2)
	voxel.call("definir_style", style)
	(m["ancre"] as Node3D).visible = noeud.is_visible_in_tree()
	# L'opacité par vue : celle du sprite remplacé tel que la vue le dessine (suie, fondu du leurre).
	for id in 2:
		var o := 1.0
		if m["slug"] == "leurre":
			var s := noeud.get_node_or_null(NodePath("VisuelPoseur" if id == m["poseur"] else "Visuel"))
			o = Presentation3D.opacite_rendue(s) if s != null else 1.0
		elif not (m["sprites"] as Array).is_empty():
			o = Presentation3D.opacite_rendue(m["sprites"][0])
		voxel.call("definir_opacite", o, id)


func _retirer(id: int) -> void:
	var m: Dictionary = _miroirs.get(id, {})
	if m.is_empty():
		return
	for s in m["sprites"]:
		_rendre_a_la_lightmap(s)
	for c in m["capteurs"]:
		if c != null and is_instance_valid(c):
			(c as Node).queue_free()
	if is_instance_valid(m["ancre"]):
		(m["ancre"] as Node).queue_free()
	_miroirs.erase(id)


# ---------------------------------------------------------------------------
# LES QUADS : BALLE, VISEUR, LIGNE DE VISÉE
# ---------------------------------------------------------------------------

## Le viseur et la ligne de visée ne se voient que dans la vue de leur joueur, comme en 2D (couches 2
## et 4) : leurs quads vont au calque 3D de cette vue.
func _suivre_joueurs(main: Node) -> void:
	for j in 2:
		var joueur = main.p1 if j == 0 else main.p2
		if not is_instance_valid(joueur):
			continue
		var q: Dictionary = _quads_joueurs[j]
		if q.is_empty():
			q["ligne"] = _quad("LigneDeVisee%d" % (j + 1), Presentation3D._calque_de(j), false)
			q["viseur"] = _quad("Viseur%d" % (j + 1), Presentation3D._calque_de(j), false)
		var ligne := joueur.get("aim_line") as Line2D
		var mi_ligne: MeshInstance3D = q["ligne"]
		mi_ligne.visible = false
		if ligne != null:
			_retirer_de_la_lightmap(ligne)
			var pts := ligne.points
			if pts.size() >= 2 and ligne.is_visible_in_tree() and not _quads_masques:
				_poser_segment(mi_ligne, ligne.global_transform * pts[0], ligne.global_transform * pts[pts.size() - 1],
					ligne.width, ligne.texture, ligne.default_color * ligne.modulate, PERIODE_TIRETS_PX)
				mi_ligne.visible = true
		var viseur := (joueur as Node).get_node_or_null(^"Viseur") as Sprite2D
		var mi_viseur: MeshInstance3D = q["viseur"]
		mi_viseur.visible = false
		if viseur != null and viseur.texture != null:
			_retirer_de_la_lightmap(viseur)
			if viseur.is_visible_in_tree() and not _quads_masques:
				_poser_rect(mi_viseur, viseur.global_position, viseur.global_rotation,
					viseur.texture.get_size() * viseur.global_scale.abs(), viseur.texture, viseur.modulate)
				mi_viseur.visible = true


## La balle se voit dans les deux vues (couche 1 en 2D) : ses quads vont au calque commun. Elle n'éclaire
## plus rien depuis le 2026-09-15 (décision d'Adrien, « la balle n'est plus une source de lumière ») : sa
## traçante et son aura, non éclairées, sont tout ce qu'on voit d'elle.
func _suivre_balle(balle: Node2D, vus: Dictionary) -> void:
	var id := balle.get_instance_id()
	vus[id] = true
	var q: Dictionary = _quads_balles.get(id, {})
	if q.is_empty():
		q = {"core": _quad("BalleCoeur", Presentation3D.CALQUE_COMMUN, true),
			"aura": _quad("BalleAura", Presentation3D.CALQUE_COMMUN, true)}
		_quads_balles[id] = q
	var core := balle.get_node_or_null(^"Core") as Line2D
	var aura := balle.get_node_or_null(^"Aura") as Sprite2D
	var mi_core: MeshInstance3D = q["core"]
	var mi_aura: MeshInstance3D = q["aura"]
	mi_core.visible = false
	mi_aura.visible = false
	if core != null:
		_retirer_de_la_lightmap(core)
		var pts := core.points
		if pts.size() >= 2 and core.is_visible_in_tree() and not _quads_masques:
			_poser_segment(mi_core, core.global_transform * pts[0], core.global_transform * pts[pts.size() - 1],
				core.width, core.texture, core.default_color * core.modulate, 0.0)
			mi_core.visible = true
	if aura != null and aura.texture != null:
		_retirer_de_la_lightmap(aura)
		if aura.is_visible_in_tree() and not _quads_masques:
			_poser_rect(mi_aura, aura.global_position, aura.global_rotation,
				aura.texture.get_size() * aura.global_scale.abs(), aura.texture, aura.modulate)
			mi_aura.visible = true


func _retirer_balle(id: int) -> void:
	var q: Dictionary = _quads_balles.get(id, {})
	for mi in q.values():
		if is_instance_valid(mi):
			(mi as Node).queue_free()
	_quads_balles.erase(id)


func _quad(nom: String, calque: int, additif: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = _plan
	mi.layers = calque
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_QUAD_ADDITIF if additif else SHADER_QUAD
	mi.material_override = mat
	add_child(mi)
	return mi


## Un segment 2D `a` → `b`, de `largeur` px, posé au sol. `periode` > 0 : texture répétée tous les
## `periode` px (tirets) ; 0 : étirée d'un bout à l'autre (traçante).
static func _poser_segment(mi: MeshInstance3D, a: Vector2, b: Vector2, largeur: float, tex: Texture2D,
		couleur: Color, periode: float) -> void:
	var d := b - a
	var longueur := maxf(d.length(), 0.001)
	mi.position = Vector3((a.x + b.x) * 0.5, HAUTEUR_QUAD_PX, (a.y + b.y) * 0.5)
	mi.basis = Basis(Vector3.UP, -atan2(d.y, d.x)) * Basis.from_scale(Vector3(longueur, 1.0, maxf(largeur, 0.001)))
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter("texture_quad", tex)
	mat.set_shader_parameter("avec_texture", tex != null)
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("repetition", Vector2(longueur / periode if periode > 0.0 else 1.0, 1.0))


## Un sprite 2D centré en `centre`, tourné de `angle`, de `taille` px, posé au sol.
static func _poser_rect(mi: MeshInstance3D, centre: Vector2, angle: float, taille: Vector2, tex: Texture2D,
		couleur: Color) -> void:
	mi.position = Vector3(centre.x, HAUTEUR_QUAD_PX, centre.y)
	mi.basis = Basis(Vector3.UP, -angle) * Basis.from_scale(Vector3(maxf(taille.x, 0.001), 1.0, maxf(taille.y, 0.001)))
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter("texture_quad", tex)
	mat.set_shader_parameter("avec_texture", tex != null)
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("repetition", Vector2.ONE)


# ---------------------------------------------------------------------------
# LES COUCHES RETIRÉES
# ---------------------------------------------------------------------------

func _retirer_de_la_lightmap(item: CanvasItem) -> void:
	if item.visibility_layer == Presentation3D.COUCHE_HORS_VUE:
		return
	var id := item.get_instance_id()
	if not _couches.has(id):
		_couches[id] = item.visibility_layer
	item.visibility_layer = Presentation3D.COUCHE_HORS_VUE


func _rendre_a_la_lightmap(item) -> void:
	if not is_instance_valid(item):
		return
	var id := (item as Object).get_instance_id()
	if _couches.has(id) and (item as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE:
		(item as CanvasItem).visibility_layer = _couches[id]
	_couches.erase(id)
