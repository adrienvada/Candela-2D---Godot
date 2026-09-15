extends SubViewport

## La PEINTURE de la carte, sans lumière — chantier ISO10, famille 1f (le mur ne rougit pas du sang).
##
## ## Pourquoi
##
## Une face de mur iso lit sa lumière dans la lightmap, 12 px devant elle. Or la lightmap est le rendu 2D de la vue de
## dessus : le SOL PEINT × la lumière. Une tache de sang au pied d'un mur y est rouge, et la face la lisait rouge (r/g
## 1,32 sous la tache contre 1,21 à côté, `--plan=loupe-peinture`). Aucun tampon ne porte la lumière seule. Voie (E),
## feu vert de la session cloud (2026-09-15, 18:24) : la lumière = lightmap ÷ peinture (`mur_iso.gdshader`,
## `lire_lumiere`).
##
## ## Ce qu'elle est
##
## Une sous-vue qui PARTAGE le monde 2D du duel, cadrée une fois pour toutes sur la carte — le cadre du décor cuit
## (`ArenaDecor._cadre` : la grille et une case de bordure) — à 1 texel par pixel de monde, plafonnée à `COTE_MAX`
## texels de côté sur les cartes géantes. En espace MONDE, jamais au cadrage de la caméra du duel : celle-ci bouge à
## chaque image, et une peinture à son cadrage devrait se refaire à chaque image (condition de la session cloud). Une
## texture pour le jeu, la même pour les deux vues en écran scindé.
##
## Elle dessine des COPIES sans lumière (`light_mask` 0) sur une couche de visibilité à elle
## (`Presentation3D.COUCHE_PEINTURE`), que la présentation retire des masques des lightmaps comme celles des capteurs :
## - une fois par carte : le sol, le décor peint, l'encre des murs (copiés depuis les calques de la vue de J1) ;
## - à la pose : le sang, les éclats de mur, les douilles une fois immobiles ;
## - jamais : les empreintes de pas. Une par pas, fondu de 2 s : elles changeraient la peinture à chaque image. Elles
##   sont grises, pas rouges ; sous une empreinte, la face lit un peu plus sombre, comme avant.
## Elle ne se rend qu'à la demande (`UPDATE_ONCE`), quand une copie arrive, part ou change.
##
## ⚠️ **Les copies sont les ENFANTS DE CETTE SOUS-VUE, jamais de l'arène.** Une vue ne rend un `CanvasItem` que si lui ET
## TOUS SES PARENTS partagent une couche avec son masque (documentation de `visibility_layer`). Posées sous l'arène
## (couche 1), les copies de la couche 512 étaient toutes écartées : la texture valait 0/255 au pied du pilier aux deux
## premiers passages en jeu (`--plan=loupe-face-sang`), la division tombait partout sur le plancher et les faces
## s'éclaircissaient de 1,6 fois. Enfant d'une sous-vue, la chaîne des parents s'arrête à elle — le patron du disque de
## `capteur_corps.gd` — et la copie dessine toujours dans le monde partagé, à la transformation globale de sa source.
## Matériau NON ÉCLAIRÉ (`LIGHT_MODE_UNSHADED`, le geste de `bullet.gd` et `gadget_base.gd`) : l'albédo pur, hors de toute
## lumière et du `CanvasModulate` noir de l'arène.
##
## ⚠️ **Une copie de trace entre dans le groupe de SA copie J2** (`blood_p2`, `wall_impact_p2`, `casing_p2`) AVANT
## d'entrer dans l'arbre : son `_ready` s'arrête alors aussitôt — elle ne compte pas dans le plafond et n'engendre pas de
## copie. Ses variables de script sont recopiées TOUTES, par la liste des propriétés : `duplicate()` ne les recopie pas,
## et une variable neuve oubliée a déjà fait dessiner le vide à J2 (piège du 2026-08-25).

## ⚠️ **La référence et le plancher de la division sont PEINTS ICI**, deux carrés d'étalonnage au coin du cadre (dans la
## case de bordure, hors du sol jouable) : la couleur moyenne du sol dessiné, et le gris de 0,05 affiché. `mur_iso` les
## lit par la même texture et la même lecture que la peinture, donc dans le même espace de couleur, quel qu'il soit. Au
## troisième passage en jeu, une référence calculée en linéaire côté processeur (0,023) contre une peinture que le shader
## lisait autrement (≈ 0,15 au sol, sonde « référence 1, plancher 0 ») assombrissait les faces de six fois — alors que
## le rouge du sang, lui, disparaissait bien.
const ETALON_COTE := 6.0

## Le plafond de la texture, en texels de côté. Les cartes livrées font de 910 à 1 190 px de cadre (3,2 à 5,4 Mo en
## RGBA8) ; une carte de 128 × 128 cases en ferait 4 550 (79 Mo) — ramenée à 4 096, 0,9 texel par pixel.
const COTE_MAX := 4096
## Les traces peintes à la pose : groupe de l'original → groupe qui rend sa copie inerte (celui de sa copie J2).
const TRACES := {"blood_stain": "blood_p2", "wall_impact": "wall_impact_p2", "bullet_casing": "casing_p2"}
## Les calques peints une fois par carte, copiés depuis ceux de la vue de J1.
const CALQUES := ["CustomFloor_P1", "ArenaDecor_P1", "MurEncre_P1"]

## Le rectangle de monde couvert, en pixels, et les texels par pixel de monde.
var cadre := Rect2()
var echelle := 1.0
## Combien de rendus ont été demandés depuis la création — la mesure du coût les compte.
var rendus := 0

var _arene: Node2D
var _statiques: Array[CanvasItem] = []
## original → copie
var _copies := {}
## Les douilles qui glissent encore : peintes une fois immobiles.
var _attente: Array[Node2D] = []
var _decor_source: CanvasItem
var _decor_copie: CanvasItem
var _sale := true
var _debut_ms := 0
## Le matériau de toutes les copies : non éclairé, pour échapper au `CanvasModulate` (voir l'en-tête).
var _sans_lumiere := CanvasItemMaterial.new()


static func creer(arene: Node2D, data: Dictionary) -> SubViewport:
	var p: SubViewport = (preload("res://peinture_iso.gd") as GDScript).new()
	p.name = "PeintureIso"
	p._arene = arene
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var grille := Vector2(MapCodec.get_grid_size(data))
	p.cadre = Rect2(-tuile, (grille + Vector2(2, 2)) * tuile)
	p.echelle = minf(1.0, float(COTE_MAX) / maxf(p.cadre.size.x, p.cadre.size.y))
	p.world_2d = arene.get_world_2d()
	# Le même espace de couleur que la lightmap qu'elle divise : `mur_iso` lit les deux textures par le même indice
	# (`source_color`), et un rendu 2D HDR d'un côté seulement (texture flottante) contre 8 bits de l'autre fausserait le
	# rapport. Aujourd'hui aucune vue ne rend en HDR 2D : la recopie ne change rien, elle garde l'accord si ça change.
	var vue_arene := arene.get_viewport()
	if vue_arene != null:
		p.use_hdr_2d = vue_arene.use_hdr_2d
	p.size = Vector2i((p.cadre.size * p.echelle).ceil())
	p.canvas_cull_mask = Presentation3D.COUCHE_PEINTURE
	p.transparent_bg = false
	p.disable_3d = true
	p.audio_listener_enable_2d = false
	p.handle_input_locally = false
	p.gui_disable_input = true
	p.render_target_update_mode = SubViewport.UPDATE_ONCE
	return p


## Le centre de l'étalon de référence (couleur moyenne du sol dessiné) et celui du plancher, en pixels de monde.
func point_reference() -> Vector2:
	return cadre.position + Vector2(ETALON_COTE, ETALON_COTE) * 0.5


func point_plancher() -> Vector2:
	return cadre.position + Vector2(ETALON_COTE * 2.5, ETALON_COTE * 0.5)


## ISO12, lot 0 — les deux aplats du damier (`CandelaTileSet.SOL_DESSIN_A`, puis `_B`), peints comme les deux étalons de 1f : le
## sol éclairé divise la peinture par l'aplat de SA case, lu dans le même espace de couleur qu'elle.
func point_aplat_a() -> Vector2:
	return cadre.position + Vector2(ETALON_COTE * 4.5, ETALON_COTE * 0.5)


func point_aplat_b() -> Vector2:
	return cadre.position + Vector2(ETALON_COTE * 6.5, ETALON_COTE * 0.5)


## La couleur de l'étalon de référence : la moyenne des deux tons du sol dessiné, telle que le sol la peint.
static func couleur_reference() -> Color:
	return CandelaTileSet.SOL_DESSIN_A.lerp(CandelaTileSet.SOL_DESSIN_B, 0.5)


## La couleur de l'étalon du plancher : le gris de `IsoMateriaux.PEINTURE_PLANCHER_AFFICHE`, en valeur affichée.
static func couleur_plancher() -> Color:
	var v := IsoMateriaux.PEINTURE_PLANCHER_AFFICHE
	return Color(v, v, v)


## La mémoire de la texture, en mégaoctets : RGBA8, ou RGBA16F en rendu 2D HDR.
func memoire_mo() -> float:
	return float(size.x * size.y * (8 if use_hdr_2d else 4)) / 1048576.0


func _ready() -> void:
	# Caméra FIXE : le coin du cadre à l'origine de la texture, `echelle` texels par pixel de monde. DANS l'arbre : posée
	# avant, la sous-vue n'est pas encore attachée au canevas du monde (« !viewport->canvas_map.has(p_canvas) »).
	canvas_transform = Transform2D(0.0, Vector2(echelle, echelle), 0.0, -cadre.position * echelle)
	for nom in CALQUES:
		var source := _arene.get_node_or_null(nom) as CanvasItem
		if source == null:
			continue
		var copie := _copier(source, "")
		_statiques.append(copie)
		if nom.begins_with("ArenaDecor"):
			_decor_source = source
			_decor_copie = copie
	for paire in [[point_reference(), couleur_reference()], [point_plancher(), couleur_plancher()],
			[point_aplat_a(), CandelaTileSet.SOL_DESSIN_A], [point_aplat_b(), CandelaTileSet.SOL_DESSIN_B]]:
		_statiques.append(_etalon(paire[0], paire[1]))
	for groupe in TRACES:
		for n in get_tree().get_nodes_in_group(groupe):
			_examiner(n)
	_arene.child_entered_tree.connect(_arrivee)
	_debut_ms = Time.get_ticks_msec()
	print("[iso] peinture : %d×%d texels (%.2f texel par pixel de monde), %.1f Mo, %d calques, %d traces"
		% [size.x, size.y, echelle, memoire_mo(), _statiques.size(), _copies.size()])


func _exit_tree() -> void:
	# La fréquence des rendus à la demande sur la vie de cette peinture : le coût réel de (E) en partie.
	var duree := float(Time.get_ticks_msec() - _debut_ms) / 1000.0
	print("[iso] peinture retirée : %d rendus en %.1f s (%.2f par seconde), %d traces peintes"
		% [rendus, duree, float(rendus) / maxf(duree, 0.001), _copies.size()])
	if is_instance_valid(_arene) and _arene.child_entered_tree.is_connected(_arrivee):
		_arene.child_entered_tree.disconnect(_arrivee)
	for c in _statiques:
		if is_instance_valid(c):
			c.queue_free()
	for c in _copies.values():
		if is_instance_valid(c):
			c.queue_free()
	_statiques.clear()
	_copies.clear()
	_attente.clear()


func _process(_delta: float) -> void:
	for i in range(_attente.size() - 1, -1, -1):
		var d := _attente[i]
		if not is_instance_valid(d) or not d.is_inside_tree():
			_attente.remove_at(i)
		elif bool(d.get("at_rest")):
			_attente.remove_at(i)
			_ajouter_trace(d, TRACES["bullet_casing"])
	# Le décor se cuit une image après sa construction (`ArenaDecor._cuire`) : la copie reprend la texture cuite.
	if is_instance_valid(_decor_copie) and is_instance_valid(_decor_source) \
			and _decor_copie.get("_cuit") != _decor_source.get("_cuit"):
		_decor_copie.set("_cuit", _decor_source.get("_cuit"))
		_decor_copie.queue_redraw()
		_sale = true
	if _sale:
		_sale = false
		rendus += 1
		render_target_update_mode = SubViewport.UPDATE_ONCE


## Redemande un rendu (la mesure du coût s'en sert pour forcer un rendu par image).
func salir() -> void:
	_sale = true


func _arrivee(n: Node) -> void:
	# Différé : la tache de sang reçoit son `setup()` après son `add_child()` (`bullet.gd`), et ses groupes à son `_ready`.
	_examiner.call_deferred(n)


func _examiner(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree() or not (n is CanvasItem) or _copies.has(n):
		return
	for groupe in TRACES:
		var garde: String = TRACES[groupe]
		if n.is_in_group(garde) or not n.is_in_group(groupe):
			continue
		if groupe == "bullet_casing" and not bool(n.get("at_rest")):
			if not _attente.has(n):
				_attente.append(n)
			return
		_ajouter_trace(n, garde)
		return


func _ajouter_trace(n: CanvasItem, garde: String) -> void:
	if _copies.has(n):
		return
	_copies[n] = _copier(n, garde)
	n.tree_exiting.connect(_depart.bind(n), CONNECT_ONE_SHOT)


func _depart(n: Node) -> void:
	var copie = _copies.get(n)
	_copies.erase(n)
	if is_instance_valid(copie):
		copie.queue_free()
	_sale = true


## Un carré d'étalonnage de `ETALON_COTE` pixels centré sur `centre`, non éclairé, au-dessus de tout.
func _etalon(centre: Vector2, couleur: Color) -> CanvasItem:
	var carre := Polygon2D.new()
	var d := ETALON_COTE * 0.5
	carre.polygon = PackedVector2Array([Vector2(-d, -d), Vector2(d, -d), Vector2(d, d), Vector2(-d, d)])
	carre.color = couleur
	carre.position = centre
	carre.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	carre.visibility_layer = Presentation3D.COUCHE_PEINTURE
	carre.light_mask = 0
	_sans_lumiere.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	carre.material = _sans_lumiere
	carre.name = "Etalon"
	add_child(carre)
	return carre


func _copier(source: CanvasItem, garde: String) -> CanvasItem:
	var copie := source.duplicate() as CanvasItem
	for g in copie.get_groups():
		copie.remove_from_group(g)
	if garde != "":
		copie.add_to_group(garde)
	for p in source.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			copie.set(p["name"], source.get(p["name"]))
	copie.name = "%s_Peinture" % source.name
	copie.visible = true
	copie.visibility_layer = Presentation3D.COUCHE_PEINTURE
	copie.light_mask = 0
	_sans_lumiere.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	copie.material = _sans_lumiere
	add_child(copie)
	if copie is Node2D and source is Node2D:
		(copie as Node2D).global_transform = (source as Node2D).global_transform
	copie.queue_redraw()
	_sale = true
	return copie
