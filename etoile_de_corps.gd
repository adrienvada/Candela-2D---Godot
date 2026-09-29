class_name EtoileDeCorps
extends CanvasLayer
## L'ombre en étoile d'un corps, posée dans SA canvas — et jamais dans celle des capteurs de ce corps.
## Q42, « le corps ignore sa propre ombre » (Adrien, 2026-09-29).
##
## ## Le défaut
##
## La torche d'un joueur porte dans ses ombres l'occluder de l'ADVERSAIRE (`1 | 2 | couche du corps d'en face`,
## `player.gd`), et cet occluder épouse la silhouette de la classe : une étoile de 32 rayons, arme comprise (décision
## d'Adrien, 2026-08-26 : « l'occlusion ne se fait pas selon le sprite »). Le capteur d'un corps (`CapteurCorps`) est un
## disque de 18 px sous lui, dans le MÊME monde 2D : il recevait donc l'ombre de SON PROPRE corps. Le corps voxel lit sa
## lumière sur un anneau de 15 px, que l'étoile recouvre ou ombre — du côté de l'arme surtout, où elle déborde de l'anneau.
## Torche de ce côté, le Fumiste, l'Incendiaire et l'Occulteur restaient noirs même à mi-portée, et le capteur variait de
## 11 % d'une classe à l'autre au même endroit (rapports `cloud-ombre-classes` et `cloud-ombre-orientation`).
##
## ## Pourquoi pas une lumière jumelle
##
## Le moteur ne trie PAS les occluders par récepteur : un disque qui reçoit l'ombre d'une lumière (son `light_mask` croise
## le `shadow_item_cull_mask` de la lumière) reçoit TOUS les occluders de ce masque, murs et étoile ensemble ; sinon il n'en
## reçoit aucun, murs compris. Et `visibility_layer` / `canvas_cull_mask` ne trient pas les occluders non plus (mesuré sous
## Godot 4.7, rapport `cloud-ombre-classes`). La seule parade qui laisse les murs ombrer le corps, c'est une lumière
## jumelle par torche et par halo, qui n'éclaire que les capteurs avec les murs seuls dans ses ombres : une lumière ombrée
## de plus par source et par vue, et un miroir de l'état de chaque lumière (énergie, cône, couleur, allumage) à tenir.
##
## ## La voie retenue : chaque vue ne compte que les occluders des canvas qu'on lui rattache
##
## Mesuré au banc du moteur (Godot 4.7, gl_compatibility) :
## - un occluder posé dans un `CanvasLayer` n'ombre QUE les viewports auxquels la canvas de ce calque est rattachée ;
## - `follow_viewport_enabled` fait de cette canvas l'enfant de la canvas du monde : où qu'elle soit rattachée, elle suit
##   la caméra DE CETTE VUE — aucune transformation à poser, ni par vue ni par image ;
## - `RenderingServer.viewport_attach_canvas()` la rattache à un viewport que le nœud ne connaît pas (une autre sous-vue,
##   un capteur) ; un calque masqué, ou libéré pendant qu'il est rattaché, cesse d'ombrer sans rien casser.
##
## L'étoile de chaque corps vit donc dans SA canvas, rattachée à toutes les vues qui rendent le duel (`GROUPE_VUES`) et à
## tous les capteurs SAUF ceux de son propre corps (`CapteurCorps.proprietaire`). Le reste est inchangé, par construction :
## - **l'ombre au sol, sur les murs, sur les sprites** : les lightmaps voient l'étoile comme avant (même canvas parente, même
##   caméra) — vérifié pixel pour pixel par `tools/planche_q42.gd` ;
## - **les murs** ombrent toujours le capteur : ils vivent dans la canvas du monde, que tous les capteurs partagent ;
## - **l'autre joueur** l'ombre toujours : son étoile est rattachée à ce capteur (et un leurre, corps à part entière, a la
##   sienne — il ne s'ombre pas plus qu'un joueur, et il ombre le joueur qu'il imite comme tout autre corps) ;
## - **le disque de torse** (rétrodiffusion, couches 16 et 32) est un autre occluder, resté dans le monde : « le dos du
##   porteur reste dans le noir » (décision d'Adrien, 2026-08-26) n'est pas touché ;
## - **toutes les lumières** qui portent une couche de corps dans leur masque d'ombre (torche, halo de proximité, faisceau
##   d'une torche fantôme…) reçoivent la règle sans qu'aucune ne soit modifiée.
##
## ## L'équité
##
## La règle est « le capteur d'un corps ne voit pas l'étoile de CE corps » : elle est la même pour J1 et pour J2, pour les dix
## classes (une étoile par silhouette, aucune n'est distinguée), dans les deux vues d'un écran scindé, en vue unique et en
## ligne — hôte comme client bâtissent la présentation par le même chemin. Elle ne dépend d'aucune donnée de la partie.
##
## ⚠️ **La vue de dessus (`--2d`) n'est pas concernée** : elle n'a pas de capteurs, son sprite adverse reçoit l'ombre de la
## torche comme avant (décision d'Adrien du 2026-09-14 : le liseré du côté de la lampe).

## Les étoiles vivantes, pour les capteurs qui naissent après elles.
const GROUPE := &"etoiles_de_corps"
## Les viewports qui rendent le monde du duel et doivent voir toutes les étoiles : `vp1`, `vp2`, et la racine quand elle
## adopte ce monde (`GameState._rendre_dans_la_racine`). L'appelant inscrit et désinscrit, puis `rapprocher_tout()`.
const GROUPE_VUES := &"vues_du_duel"
## Les capteurs de corps (`CapteurCorps`) : chacun ne voit pas l'étoile de son propre corps.
const GROUPE_CAPTEURS := &"capteurs_de_corps"

## Le corps dont c'est l'ombre : un joueur, un leurre.
var proprietaire: Node2D
## L'occluder de l'étoile — celui-là même que le corps a monté, et que ses gardes lisent (`visible`, `occluder`, masque).
var occluder: LightOccluder2D
var _suivi: RemoteTransform2D
## Les viewports où la canvas est rattachée À LA MAIN : identifiant d'instance → RID du viewport. Le viewport où le nœud
## vit est rattaché par le moteur, et ne figure jamais ici.
var _rattachee := {}


## Monte l'étoile d'un corps : `occ` quitte le monde partagé pour la canvas d'un calque enfant du corps, qui le suit.
##
## À appeler depuis le `_ready()` du corps (il est alors dans l'arbre). Rend le calque, ou `null` si `occ` est nul.
static func monter(corps: Node2D, occ: LightOccluder2D) -> EtoileDeCorps:
	if corps == null or occ == null:
		return null
	var e := EtoileDeCorps.new()
	# Un nom EXPLICITE, comme tout nœud ajouté sous un joueur (nom auto-généré = chemin qui diverge entre pairs).
	e.name = "OmbreDuCorps"
	e.follow_viewport_enabled = true
	e.proprietaire = corps
	e.occluder = occ
	if occ.get_parent() != null:
		occ.get_parent().remove_child(occ)
	e.add_child(occ)
	corps.add_child(e)
	# Le calque ne suit pas le corps : c'est le rôle de ce nœud, posé dans le corps, qui recopie sa transformation dans le
	# repère du monde (`follow_viewport`) à chaque changement — avant le rendu, comme un enfant.
	var suivi := RemoteTransform2D.new()
	suivi.name = "SuiviDeLOmbre"
	suivi.use_global_coordinates = true
	suivi.update_position = true
	suivi.update_rotation = true
	suivi.update_scale = false
	corps.add_child(suivi)
	suivi.remote_path = suivi.get_path_to(occ)
	e._suivi = suivi
	occ.global_transform = Transform2D(corps.global_rotation, corps.global_position)
	return e


func _enter_tree() -> void:
	add_to_group(GROUPE)
	if proprietaire != null and not proprietaire.visibility_changed.is_connected(_accorder_la_visibilite):
		proprietaire.visibility_changed.connect(_accorder_la_visibilite)
	_accorder_la_visibilite()
	rapprocher()


func _exit_tree() -> void:
	# Ce qui a été rattaché à la main se détache à la main : un calque qui quitte l'arbre garde sa canvas, et une vue qui
	# la garderait ombrerait encore avec un corps qui n'est plus là.
	for id in _rattachee.keys():
		_detacher(id)


## Une étoile ne vit pas dans un corps caché : sous un parent `CanvasItem`, l'occluder suivait sa visibilité seul ; sous un
## calque, il la perd — on la lui rend ici.
func _accorder_la_visibilite() -> void:
	if proprietaire != null:
		visible = proprietaire.is_visible_in_tree()


## Rattache la canvas de cette étoile à chaque vue qui doit la voir, et la détache des autres.
func rapprocher() -> void:
	if not is_inside_tree():
		return
	var arbre := get_tree()
	var voulues := {}
	for v in arbre.get_nodes_in_group(GROUPE_VUES):
		if v is Viewport:
			voulues[v.get_instance_id()] = (v as Viewport).get_viewport_rid()
	for c in arbre.get_nodes_in_group(GROUPE_CAPTEURS):
		if c is Viewport and c.get("proprietaire") != proprietaire:
			voulues[c.get_instance_id()] = (c as Viewport).get_viewport_rid()
	# Le viewport du nœud est rattaché par le moteur : une seconde fois, il refuserait.
	voulues.erase(get_viewport().get_instance_id())
	for id in _rattachee.keys():
		if not voulues.has(id) or not is_instance_id_valid(id):
			_detacher(id)
	for id in voulues:
		if not _rattachee.has(id):
			RenderingServer.viewport_attach_canvas(voulues[id], get_canvas())
			_rattachee[id] = voulues[id]


func _detacher(id: int) -> void:
	# Un viewport libéré a déjà rendu sa canvas ; on ne détache que celui qui vit encore.
	if is_instance_id_valid(id):
		RenderingServer.viewport_remove_canvas(_rattachee[id], get_canvas())
	_rattachee.erase(id)


## Toutes les étoiles se rapprochent des vues : à appeler quand un capteur ou une vue naît, ou change de monde.
static func rapprocher_tout(arbre: SceneTree) -> void:
	if arbre == null:
		return
	for e in arbre.get_nodes_in_group(GROUPE):
		(e as EtoileDeCorps).rapprocher()


## Les viewports auxquels la canvas est rattachée à la main, pour les gardes : `{id d'instance → RID}`.
func vues_rattachees() -> Dictionary:
	return _rattachee.duplicate()
