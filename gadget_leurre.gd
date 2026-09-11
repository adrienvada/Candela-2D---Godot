class_name GadgetLeurre
extends GadgetBase

## Le leurre inerte — gadget de l'Illusionniste, chantier CLASSES, étape 15.
##
## ## Ce qu'il est, et pourquoi il n'a rien à inventer
##
## *« Il fait croire à un corps qui n'est pas là. Le leurre ne se distingue d'un
## joueur que trop tard. »*
##
## Dans ce jeu, on ne voit jamais l'homme : **on voit le trou qu'il fait dans la
## lumière.** Un leurre convaincant n'a donc pas à ressembler à un joueur — il
## doit faire *le même trou* et porter *la même silhouette*. C'est ce qu'il fait,
## littéralement : l'ombre en étoile que le joueur tire de sa silhouette
## (`Charte.ombre_de_silhouette`), et la texture de cette silhouette.
##
## ⚠️ **Il projetait un DISQUE jusqu'au 2026-09-11**, et c'est ce qu'Adrien voyait :
## « un cercle comme actuellement ». L'étape 15 avait lu `18.0 is exactly the
## player radius` à côté de l'occluder du joueur — un cercle provisoire, écrasé
## par l'étoile au premier `equip_weapon()`. Le vrai joueur ne projette plus de
## disque depuis le 2026-08-26.
##
## ⚠️ **Rien n'est peint pour lui, et c'est le point.** Un sprite de leurre
## dessiné à part serait un sprite de plus à tenir d'accord avec celui du
## joueur ; le jour où l'un des deux changerait, le leurre cesserait de tromper
## sans qu'une seule erreur ne se lève. Il emprunte l'asset du joueur, comme la
## torche fantôme emprunte le cookie de sa classe.
##
## ## Ce qu'il ne fait PAS
##
## Il ne bouge pas, n'éclaire pas, ne tire pas et ne fait aucun bruit. C'est un
## leurre **inerte** — le nom que le catalogue lui donne depuis le premier jour.
## Un leurre qui bougerait serait un second joueur à simuler et à répliquer ;
## celui-ci ne coûte rien au fil, parce qu'il ne fait rien.
##
## ## Une balle suffit
##
## Et c'est ce qui l'équilibre : le démasquer coûte un tir, donc un flash, donc
## sa propre position. L'Illusionniste ne gagne pas parce que le leurre survit —
## il gagne parce que l'autre a tiré.

## Le rayon de la COLLISION : la zone de touche d'un vrai corps (`bullet.gd`,
## `PLAYER_BODY_RADIUS`). Son ombre, elle, est l'étoile de la silhouette — voir
## `_monter_occluder()`. Chaque forme suit la forme CORRESPONDANTE du joueur, qui a
## lui-même une ombre en étoile et une zone de touche ronde.
const RAYON_CORPS := 18.0

## Le shader d'un corps ADVERSE, par son CHEMIN — jamais `Player.SHADER_ENEMY_LIGHT`
## (voir `_monter_visuel`). La même ressource que celle de `player.gd`, rendue par le
## cache : rien à recompiler, aucun hoquet à la première pose.
const SHADER_CORPS_ADVERSE := preload("res://player_enemy_light.gdshader")

## L'étoile de son ombre, dans son repère — celle que porte l'occluder, et que la
## ligne de vue d'éblouissement lit (`coupe_le_regard`).
var _etoile := PackedVector2Array()
var _occluder: LightOccluder2D
## Le corps tel que l'ADVERSAIRE le voit — le patron de `visual_enemy`.
var _visuel: Polygon2D
## Le corps tel que le POSEUR le voit, sur sa seule vue (étape 28).
var _visuel_poseur: Polygon2D


func _init() -> void:
	rayon = RAYON_CORPS
	# Un corps arrête une balle. C'est aussi la seule façon de le démasquer.
	arrete_les_balles = true
	# Une balle, et il tombe. Voir la note de tête : ce n'est pas une fragilité,
	# c'est le prix que l'adversaire paie pour savoir.
	pv = 1.0
	eblouit = false
	# L'éblouissement lit son OMBRE, pas sa collision : voir `coupe_le_regard()`.
	regard_par_la_forme = true
	# Il regarde là où le poseur visait : on plante un leurre en le tournant vers
	# ce qu'on veut faire croire qu'il surveille.
	angle_pose = 0.0


## La silhouette de la classe du poseur, ou `null` — et alors un CRI. Partagée par
## l'ombre et le visuel : `_monter_occluder()` passe AVANT `_monter_visuel()`.
func _silhouette() -> Texture2D:
	if classe_du_poseur == null:
		push_error("GadgetLeurre : aucune classe posée, pas de silhouette")
		return null
	var chemin := "res://assets/sprites/%s_silhouette.png" % classe_du_poseur.slug()
	if not ResourceLoader.exists(chemin):
		# Aucun repli : un disque de secours redonnerait une forme plausible, et
		# une forme plausible se prend pour une intention.
		push_error("GadgetLeurre : silhouette absente — %s" % chemin)
		return null
	return load(chemin)


## L'ombre : l'étoile que le JOUEUR tire de la même silhouette, au pixel près.
##
## ⚠️ Recalculée depuis la silhouette, jamais copiée sur l'occluder du poseur : une
## seule vérité, `Charte.ombre_de_silhouette`, que le joueur lit aussi. L'occluder
## du joueur a d'ailleurs été, jusqu'au 2026-09-11, une ressource PARTAGÉE entre
## les deux corps — voir `player._accorder_occluder_a_la_silhouette()`.
func _monter_occluder() -> void:
	var tex := _silhouette()
	if tex == null:
		# Sans silhouette, le socle garde le disque : un gadget qui se déclare
		# opaque doit porter un occluder (`occulte_la_lumiere`), faute de quoi il
		# arrêterait l'éblouissement sans arrêter la lumière. Le cri est déjà parti.
		# Et le rayon relit alors la collision, qui est ce disque.
		regard_par_la_forme = false
		super()
		return
	_etoile = Charte.ombre_de_silhouette(tex)
	var occ := LightOccluder2D.new()
	occ.name = "Occluder"
	var poly := OccluderPolygon2D.new()
	poly.polygon = _etoile
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = MapGeometry.WALL_LAYER
	add_child(occ)
	_occluder = occ


## Le visuel : la SILHOUETTE de la classe du poseur, montée comme `player.gd`
## monte la sienne — un `Polygon2D` texturé, dimensionné par `empreinte_sprite()`.
##
## ⚠️ **La silhouette, jamais l'image peinte.** C'est ce que l'adversaire voit
## d'un vrai joueur (`visual_enemy` porte `t_sil`) ; lui montrer l'image peinte
## ferait du leurre la seule chose de l'arène qui se distingue d'un corps — soit
## exactement l'inverse du but.
##
## ⚠️ Et `empreinte_sprite()` plutôt que la largeur brute de la texture : c'est le
## piège que le chantier R a levé le 2026-08-25, recuire un asset
## redimensionnerait le corps.
##
## ⚠️ **Un corps par vue, comme un joueur** (étape 28, 2026-09-11). Jusque-là, un
## seul polygone, sur les trois masques de lumière et sans shader, dans les deux
## vues : il recevait l'écho au sol d'un tir, la lumière d'impact et les étincelles —
## qu'aucun corps ADVERSE ne reçoit (les deux derniers atteignent le corps PROPRE,
## masque 4 — et donc aussi `VisuelPoseur`) — et suivait le dégradé du cookie là où un corps adverse
## est un aplat plafonné. Il se trahissait par ce qu'il avait EN PLUS. Les deux
## polygones naissent de `poseur_id` et de `classe_du_poseur`, que les deux pairs
## connaissent : rien de neuf sur le fil. Chaque vue coupe celui qui ne la regarde
## pas — le patron exact de `player.gd` (`visual` / `visual_enemy`).
func _monter_visuel() -> void:
	var tex := _silhouette()
	if tex == null:
		return

	# ⚠️ `Charte` et non `Player` : nommer `Player` depuis un gadget ferait
	# cesser `tools/test_classes.gd` de compiler — `player.gd` nomme un
	# autoload, et une suite en `--script` n'en a aucun. La fonction a déménagé
	# dans la charte pour cette raison ; voir sa note là-bas.
	var demi := Vector2(Charte.empreinte_sprite(tex.get_width()),
		Charte.empreinte_sprite(tex.get_height())) * 0.5
	# Le corps que voit l'ADVERSAIRE : `visual_enemy` trait pour trait — masque de
	# lumière 2, shader du corps adverse, couche de la vue de l'AUTRE joueur. Le nom
	# « Visuel » lui reste : c'est lui qui trompe.
	_visuel = _corps_de_silhouette("Visuel", tex, demi)
	_visuel.light_mask = 2
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_CORPS_ADVERSE
	_visuel.material = mat
	_visuel.visibility_layer = GadgetBase.couche_de_vue(1 - poseur_id)
	# Le corps que voit le POSEUR : sur sa vue seule, sous les lumières de son propre
	# corps (masque 4) mais SANS le shader adverse — ni celui de son corps à lui,
	# ni son image peinte : c'est le leurre qu'il a planté, pas lui. Il le voit pour
	# le placer, pas pour se tromper.
	#
	# ⚠️ **Conséquence à l'entraînement** : seule la vue de J1 y est rendue, donc
	# Adrien n'y verra plus son leurre tel que l'adversaire le voit — seule une
	# capture (plan `leurre` du photographe) le montre.
	_visuel_poseur = _corps_de_silhouette("VisuelPoseur", tex, demi)
	_visuel_poseur.light_mask = 4
	_visuel_poseur.visibility_layer = GadgetBase.couche_de_vue(poseur_id)


## Un corps : la silhouette, à l'empreinte du joueur, à la teinte d'un adversaire.
## Ce que les deux vues partagent vit ICI, pour qu'elles ne divergent jamais.
func _corps_de_silhouette(nom: String, tex: Texture2D, demi: Vector2) -> Polygon2D:
	var corps := Polygon2D.new()
	corps.name = nom
	corps.polygon = PackedVector2Array([
		Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y),
		Vector2(demi.x, demi.y), Vector2(-demi.x, demi.y)])
	corps.texture = tex
	# ⚠️ **La teinte de l'adversaire, et elle n'est pas décorative.** La
	# silhouette est BLANCHE ; `Polygon2D.color` la multiplie, et `player.gd`
	# écrit pourquoi : *« `Charte.ADVERSAIRE` est calibrée en luminance pour
	# l'équité »*. Sans cette ligne le leurre sortait blanc sous la torche — plus
	# lumineux qu'un vrai corps, donc reconnaissable du premier coup d'œil, ce
	# qui est l'inverse exact de son métier. Constaté en capture.
	corps.color = Charte.ADVERSAIRE
	corps.uv = PackedVector2Array([
		Vector2.ZERO, Vector2(tex.get_width(), 0.0),
		Vector2(tex.get_width(), tex.get_height()), Vector2(0.0, tex.get_height())])
	corps.z_index = 6
	add_child(corps)
	return corps


## Dans la suie, il disparaît comme un corps — silhouette ET ombre —, et pâlit
## comme lui dans la fumée : la règle de `player.gd`, lue au même endroit
## (`GadgetBase.effacements_a`). Un leurre qui restait net là où un vrai corps
## s'efface se trahissait par ce qu'il avait EN PLUS. Trouvé en revue (2026-09-11).
func _physics_process(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion() or not is_inside_tree():
		return
	var e := GadgetBase.effacements_a(get_tree(), global_position)
	# Les DEUX corps (étape 28) : celui que voit l'adversaire, et celui que voit le
	# poseur — qui doit voir son leurre s'effacer là où l'autre le perd.
	var a := 1.0 - maxf(e.x, e.y)
	for v in [_visuel, _visuel_poseur]:
		if v != null:
			v.modulate.a = a
	if _occluder != null:
		_occluder.visible = e.y < SEUIL_OMBRE_MASQUEE


## Le segment `de` → `vers` traverse-t-il son OMBRE ? L'étoile de la silhouette,
## dans le repère du monde — ce que la lumière montre, donc ce qui doit arrêter
## l'éblouissement (`GameState._ligne_de_vue_depuis`). Sa collision, le disque de
## 18 d'une zone de touche, laissait passer l'éblouissement dans l'ombre du canon
## et l'arrêtait là où la lumière passe à côté du corps. Trouvé en revue
## (2026-09-11).
##
## Ombre coupée dans la suie : plus rien n'arrête le regard, comme la lumière. Une
## source DANS l'étoile n'est pas coupée — le rayon physique ne l'était pas non
## plus depuis l'intérieur d'un disque.
func coupe_le_regard(de: Vector2, vers: Vector2) -> bool:
	if _etoile.is_empty() or (_occluder != null and not _occluder.visible):
		return false
	var ombre: PackedVector2Array = global_transform * _etoile
	if Geometry2D.is_point_in_polygon(de, ombre):
		return false
	return not Geometry2D.intersect_polyline_with_polygon(
		PackedVector2Array([de, vers]), ombre).is_empty()


## Étape 28, lot F — son effacement dans la suie, tel qu'il était : silhouette pâlie,
## ombre coupée. Un seul alpha : les deux corps du lot D portent toujours le même.
func etat_de_rejeu() -> Dictionary:
	var d := super()
	d["alpha"] = _visuel.modulate.a if _visuel != null else 1.0
	d["ombre"] = _occluder.visible if _occluder != null else true
	return d


## ⚠️ **Les DEUX corps**, comme `_physics_process()` : celui que voit l'adversaire et
## celui que voit le poseur. N'en rejouer qu'un ferait du leurre de killcam la seule
## chose de l'arène qui s'efface d'un seul côté.
func rejouer(d: Dictionary) -> void:
	super(d)
	var a := float(d["alpha"])
	for v in [_visuel, _visuel_poseur]:
		if v != null:
			v.modulate.a = a
	if _occluder != null:
		_occluder.visible = bool(d["ombre"])
