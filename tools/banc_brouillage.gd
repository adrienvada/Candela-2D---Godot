extends Node2D

## Le banc du BROUILLAGE — cinq façons de rendre l'adversaire difficile à viser,
## comparées manette (ou souris) en main, et CHIFFRÉES.
##
## ## Pourquoi celui-ci n'est pas une planche de plus
##
## `planche_eblouissement` pose des images et imprime des mesures : elle répond à
## « la mécanique fait-elle ce qu'elle dit ». La question d'ici est autre, et
## aucun banc du dépôt ne sait la poser : **est-ce qu'on arrive encore à viser ?**
## Elle ne se répond ni en headless ni sur une capture — il faut quelqu'un qui
## essaie de toucher.
##
## Alors le banc mesure l'essai. Chaque tir relève l'écart angulaire entre le
## canon et la position VRAIE de l'adversaire, et le convertit en écart latéral
## à la distance du duel. On repart donc avec un tableau : par mode, combien de
## tirs, combien au but, et de combien on rate en moyenne. **Le ressenti reste à
## Adrien ; le banc lui donne de quoi ne pas se fier qu'à lui.**
##
## C'est la leçon du 2026-08-24 appliquée d'avance : une seconde et demie de
## récupération « se tenait » sur le papier et s'est révélée punitive à l'essai.
## Cinq modes de brouillage se tiennent tous sur le papier.
##
## ## Ce que le banc reproduit fidèlement, et ce qu'il ne reproduit pas
##
## **Fidèle** : le faisceau (le vrai cookie de l'arme, la vraie échelle), la
## lumière reçue (`WeaponData.lumiere_recue`, donc l'alpha du pixel), la
## conversion en pénalité (`Eblouissement.plafond_pour`), la montée et la
## descente (`Eblouissement.integrer`), la vivacité de visée
## (`18,0 × (1 − 0,6 × éblouissement)`, recopiée de `player.gd`), la silhouette
## ennemie (même polygone, même gris de charte, même shader), le voile blanc
## (même teinte, même facteur 0,8).
##
## **Pas fidèle, et sciemment :**
##
## - **La victime ne se déplace pas.** La pénalité de vitesse est déjà livrée et
##   déjà jugée ; la question du jour est la LECTURE. Un canon fixe rend en
##   outre les écarts angulaires comparables d'un essai à l'autre, ce qu'un
##   tireur qui se déplace interdirait.
## - **Le canon de la victime est toujours visible** (non ombré, cyan de
##   charte) : c'est le repère du banc, il ne doit pas disparaître avec le reste.
## - **Une seule vue**, pas deux `SubViewport`. Le cloisonnement par
##   `visibility_layer` est une propriété d'ÉQUITÉ que `planche_eblouissement`
##   éprouve déjà ; la refaire ici n'apprendrait rien et coûterait la moitié de
##   l'écran.
##
## ## Lancer
##
##     godot --path . res://tools/banc_brouillage.tscn
##
## Hors du lanceur de suites, comme les deux autres outils qui regardent
## l'écran : `--headless` ne rastérise rien, et celui-ci attend en plus quelqu'un
## pour appuyer sur les touches.

const Brouillage := preload("res://brouillage.gd")
const Eblouissement := preload("res://eblouissement.gd")
const Charte := preload("res://charte.gd")
const SHADER_ENNEMI := preload("res://player_enemy_light.gdshader")

## Le polygone du joueur, recopié de `player.tscn` — seize côtés, rayon 18.
## Recopié et non chargé : instancier `player.tscn` amènerait
## `MultiplayerSynchronizer`, `LocalInputProvider` et `MapGeometry`, donc les
## autoloads, pour dessiner un disque.
## `static var` et non `const` : GDScript refuse un `PackedVector2Array` en
## constante — l'appel de constructeur n'est pas repliable. Le refus est une
## erreur d'ANALYSE, donc la scène tournerait sans script en sortant en 0.
static var CORPS: PackedVector2Array = PackedVector2Array([
	Vector2(18, 0), Vector2(16.63, 6.89), Vector2(12.73, 12.73), Vector2(6.89, 16.63),
	Vector2(0, 18), Vector2(-6.89, 16.63), Vector2(-12.73, 12.73), Vector2(-16.63, 6.89),
	Vector2(-18, 0), Vector2(-16.63, -6.89), Vector2(-12.73, -12.73), Vector2(-6.89, -16.63),
	Vector2(0, -18), Vector2(6.89, -16.63), Vector2(12.73, -12.73), Vector2(16.63, -6.89),
])
static var NEZ: PackedVector2Array = PackedVector2Array([
	Vector2(18, -2), Vector2(18, 2), Vector2(28, 0),
])

## Rayon du joueur, en pixels. C'est la demi-largeur de la cible : un tir dont
## l'écart latéral lui est inférieur touche.
const RAYON_JOUEUR := 18.0

## Recopiés de `player.gd` — la vivacité de visée et ce que l'éblouissement lui
## retire. Si ces deux nombres bougent là-bas, ils mentent ici.
const VISEE_PAR_S := 18.0
const VISEE_PENALITE := 0.6

## Le facteur d'opacité du voile blanc, recopié d'`ui.gd`.
const VOILE_FACTEUR := 0.8

## Combien de fantômes en diplopie. Deux : le milieu de deux points se tient à
## l'œil, le barycentre de trois beaucoup moins.
const COPIES_DIPLOPIE := 2

## Délai minimal entre deux tirs, en secondes. Pas la cadence d'une arme — celle
## du pistolet vaut une seconde, et on ne relèverait rien en une minute. Juste
## de quoi empêcher un clic maintenu de produire cent échantillons identiques.
const REPOS_TIR := 0.25

## Le tampon de rémanence, en secondes d'historique. Large devant
## `Brouillage.RETARD_REMANENCE` pour qu'un réglage de force à 2,0 ait encore de
## quoi lire. Dimensionné en SECONDES et jamais en nombre d'images : les fps ne
## sont pas plafonnés, et un tampon compté en images a déjà tronqué la killcam.
const HISTORIQUE_S := 0.8

enum Mouvement { IMMOBILE, VA_ET_VIENT, CERCLE, ERRATIQUE }
const NOMS_MOUVEMENT := ["immobile", "va-et-vient", "cercle", "erratique"]

# --- état réglable ----------------------------------------------------------
var _mode: int = Brouillage.Mode.AUCUN
var _force: float = 1.0
var _auto: bool = true          ## L'éblouissement est-il MESURÉ, ou forcé à la main ?
var _niveau_manuel: float = 0.7
var _arme_idx: int = 0
var _mouvement: int = Mouvement.VA_ET_VIENT
var _distance: float = 300.0
var _faisceau_suit: bool = false ## Le faisceau reste-t-il sur la position vraie ?
var _penalites: bool = true      ## La visée molle de `player.gd`.
var _voile: bool = true
var _verite: bool = false        ## Montrer où l'adversaire est VRAIMENT.

# --- état vivant ------------------------------------------------------------
var _dazzle: float = 0.0
var _temps: float = 0.0
var _pos_vraie := Vector2(0, -300)
var _rot_vraie: float = 0.0
var _repos: float = 0.0
var _cible_laterale: float = 0.0  ## Pour le mouvement erratique.
var _prochain_cap: float = 0.0
## L'historique de la rémanence : des `{t, pos, rot}`, le plus ancien en tête.
var _historique: Array[Dictionary] = []
## Les relevés, un par mode : `{tirs, touches, somme_ecart, somme_lateral, force}`.
var _releves := {}

# --- nœuds ------------------------------------------------------------------
var _armes: Array[WeaponData] = []
var _camera: Camera2D
var _porteur: Node2D          ## Ce qui porte le FAISCEAU.
var _torche: PointLight2D
var _silhouettes: Array[Node2D] = []
var _tourelle: Node2D
var _voile_rect: ColorRect
var _halo: TextureRect
var _croix: Node2D
var _tracer: Line2D
var _tracer_reste: float = 0.0
var _verdict: Label
var _verdict_reste: float = 0.0
var _panneau: Label
var _aide: Label


func _ready() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error("banc_brouillage : %s" % refus)
		print("banc_brouillage : refus — %s" % refus)
		get_tree().quit(1)
		return
	RenderingServer.set_default_clear_color(Charte.NOIR)
	_forger_armes()
	_batir_monde()
	_batir_ecran()
	for m in Brouillage.Mode.values():
		_releves[m] = {"tirs": 0, "touches": 0, "somme_ecart": 0.0, "somme_lateral": 0.0, "force": _force}
	_poser_arme()
	print("--- banc du brouillage — clic pour tirer, Échap pour sortir et lire le tableau ---")


## Les quatre armes du jeu, telles que `game_state` les construit.
##
## ⚠️ **Recopié de `game_state.gd`, et c'est une dette assumée.** Les armes y
## sont bâties dans `_ready()`, mêlées aux autoloads : les charger d'ici
## amènerait `NetworkManager` et le reste. Le jour où un réglage de torche bouge
## là-bas et pas ici, le banc mentira sans rien dire — c'est exactement la
## famille de défauts que `Vision.intensite_texture` a fermée en lisant le pixel
## plutôt qu'en recopiant la formule. **Les valeurs sont donc relues au premier
## doute, et le banc les IMPRIME au démarrage** pour qu'un écart se voie.
func _forger_armes() -> void:
	var pistolet := WeaponData.new()
	pistolet.name = "Pistolet"
	pistolet.torch_cookie = "pistolet"
	pistolet.torch_angle_deg = 35.0
	pistolet.torch_scale = 1.6
	pistolet.torch_brightness = 1.0
	var fusil := WeaponData.new()
	fusil.name = "Fusil"
	fusil.torch_cookie = "fusil"
	fusil.torch_angle_deg = 15.0
	fusil.torch_scale = 1.8
	fusil.torch_brightness = 1.0
	var pompe := WeaponData.new()
	pompe.name = "Pompe"
	pompe.torch_cookie = "pompe"
	pompe.torch_angle_deg = 60.0
	pompe.torch_scale = 1.2
	pompe.torch_brightness = 1.0
	var arbalete := WeaponData.new()
	arbalete.name = "Arbalète"
	arbalete.torch_cookie = "arbalete"
	arbalete.torch_angle_deg = 5.0
	arbalete.torch_scale = 3.0
	arbalete.torch_brightness = 0.3
	_armes = [pistolet, fusil, pompe, arbalete]
	for a in _armes:
		print("  arme %-9s cône ±%2.0f°  portée %.0f px  éclat %.2f"
			% [a.name, a.torch_angle_deg, a.portee_torche(), a.torch_brightness])


func _batir_monde() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)

	# Le sol : un damier répété, comme celui du jeu. Il ne sert qu'à une chose,
	# et elle est essentielle — sans texture au sol, un faisceau qui balaie ne se
	# voit pas balayer, et l'éblouissement n'aurait aucune cause visible.
	var sol := Sprite2D.new()
	sol.name = "Sol"
	sol.texture = _damier()
	sol.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sol.region_enabled = true
	sol.region_rect = Rect2(0, 0, 4096, 2560)
	sol.light_mask = 1
	sol.z_index = -20
	add_child(sol)

	# Quatre blocs aux angles : ils accrochent le faisceau et projettent des
	# ombres. Posés au-delà du rayon de déplacement de l'adversaire (460 px), ils
	# ne coupent jamais la ligne de vue — le banc ne mesure pas l'occlusion.
	for coin in [Vector2(-800, -430), Vector2(800, -430), Vector2(-800, 430), Vector2(800, 430)]:
		_bloc(coin, Vector2(170, 170))

	# Le porteur du faisceau. Séparé des silhouettes à dessein : c'est tout
	# l'enjeu de la touche « L » — le brouillage doit-il emporter la lumière avec
	# lui, ou seulement l'image du corps ?
	_porteur = Node2D.new()
	_porteur.name = "Porteur"
	add_child(_porteur)
	_torche = PointLight2D.new()
	_torche.name = "Torche"
	_torche.shadow_enabled = true
	_torche.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	_torche.shadow_item_cull_mask = 1
	_torche.range_item_cull_mask = 1 | 2
	_torche.energy = 2.5
	_torche.color = Charte.HALOGENE
	_torche.position = Vector2(30, 0)
	_porteur.add_child(_torche)

	# Trois silhouettes : une suffit à quatre modes, la diplopie en veut deux, et
	# la troisième laisse essayer `COPIES_DIPLOPIE = 3` sans rien rebâtir.
	for i in 3:
		_silhouettes.append(_forger_silhouette(i))

	_tourelle = Node2D.new()
	_tourelle.name = "Tourelle"
	_tourelle.z_index = 10
	add_child(_tourelle)
	# Non ombrée, contrairement au joueur du jeu : c'est le repère du banc. Si
	# elle s'éteignait avec le reste, on ne saurait plus d'où part le tir.
	var non_ombre := CanvasItemMaterial.new()
	non_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var corps := Polygon2D.new()
	corps.polygon = CORPS
	corps.color = Charte.BLEU
	corps.material = non_ombre
	_tourelle.add_child(corps)
	var canon := Line2D.new()
	canon.points = PackedVector2Array([Vector2(18, 0), Vector2(46, 0)])
	canon.width = 4.0
	canon.default_color = Charte.BLEU
	canon.material = non_ombre
	_tourelle.add_child(canon)

	_croix = Node2D.new()
	_croix.name = "Verite"
	_croix.z_index = 20
	_croix.visible = false
	add_child(_croix)
	# `branche` et non `trait` : `trait` est un mot réservé de GDScript, et le
	# refus est une *erreur d'analyse* — donc la scène tourne SANS script, sort
	# proprement en 0 et ne mesure rien. C'est la panne que `run_visuel.sh`
	# grepe explicitement ; elle s'est produite ici, au premier lancement.
	for axe in [Vector2(1, 0), Vector2(0, 1)]:
		var branche := Line2D.new()
		branche.points = PackedVector2Array([-axe * 30.0, axe * 30.0])
		branche.width = 2.0
		branche.default_color = Charte.VERT
		branche.material = non_ombre
		_croix.add_child(branche)

	_tracer = Line2D.new()
	_tracer.name = "Tracer"
	_tracer.width = 2.0
	_tracer.default_color = Charte.AMBRE
	_tracer.material = non_ombre
	_tracer.z_index = 20
	_tracer.visible = false
	add_child(_tracer)


## Une silhouette ennemie : le corps, le nez, et son propre halo.
##
## **Le halo appartient à la silhouette et non au porteur, et c'est la ligne qui
## fait marcher trois modes sur cinq.** Dans le jeu, `body_light` est enfant du
## joueur : elle le suit. Ici, si elle restait accrochée à la position vraie
## pendant que le tremblement ou la rémanence déplacent le corps, le corps
## sortirait de sa propre lumière et le shader ennemi le rendrait NOIR — c'est-à-
## dire invisible. On croirait juger un brouillage, on jugerait une disparition,
## qui est le mode CONTRASTE et pas celui-là.
func _forger_silhouette(indice: int) -> Node2D:
	var rig := Node2D.new()
	rig.name = "Silhouette%d" % indice
	rig.z_index = 10
	rig.visible = false
	add_child(rig)

	var halo := PointLight2D.new()
	halo.name = "Halo"
	halo.shadow_enabled = false
	halo.range_item_cull_mask = 2
	halo.energy = 0.6
	halo.color = Charte.HALOGENE
	halo.position = Vector2(18, 0)
	var grad := Gradient.new()
	grad.set_color(0, Color(Charte.HALOGENE, 1.0))
	grad.set_color(1, Color(Charte.HALOGENE, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	halo.texture = tex
	rig.add_child(halo)

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ENNEMI
	for forme in [CORPS, NEZ]:
		var poly := Polygon2D.new()
		poly.polygon = forme
		poly.color = Charte.ADVERSAIRE
		poly.light_mask = 2
		poly.material = mat
		rig.add_child(poly)
	return rig


func _bloc(centre: Vector2, taille: Vector2) -> void:
	var demi := taille * 0.5
	var pts := PackedVector2Array([
		-demi, Vector2(demi.x, -demi.y), demi, Vector2(-demi.x, demi.y),
	])
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Charte.SOL_B
	poly.light_mask = 1
	poly.position = centre
	poly.z_index = -10
	add_child(poly)
	var occ := LightOccluder2D.new()
	var forme := OccluderPolygon2D.new()
	forme.polygon = pts
	forme.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = forme
	occ.occluder_light_mask = 1
	occ.position = centre
	add_child(occ)


## Un damier de 128 px, deux tons de la charte — le sol du jeu, en plus simple.
func _damier() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var pair := ((x < 64) == (y < 64))
			img.set_pixel(x, y, Charte.SOL_A if pair else Charte.SOL_A_ARETE)
	return ImageTexture.create_from_image(img)


func _batir_ecran() -> void:
	var couche := CanvasLayer.new()
	couche.name = "Ecran"
	add_child(couche)

	# Le voile, puis le halo PAR-DESSUS : le halo est additif, il doit mordre sur
	# le voile et non passer dessous. Même raison d'ordre que le voile qui passe
	# sous le HUD dans `ui.gd` — un ordre de déclaration décide d'un rendu, donc
	# il se commente.
	_voile_rect = ColorRect.new()
	_voile_rect.name = "Voile"
	_voile_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile_rect.color = Color(Charte.HALOGENE, 0.0)
	couche.add_child(_voile_rect)

	_halo = TextureRect.new()
	_halo.name = "Halo"
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.texture = _texture_halo()
	_halo.visible = false
	var additif := CanvasItemMaterial.new()
	additif.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = additif
	couche.add_child(_halo)

	_panneau = _etiquette(couche, Vector2(24, 20), Charte.T_COURANT)
	_aide = _etiquette(couche, Vector2(24, 900), Charte.T_MENTION)
	_aide.modulate = Charte.DIM
	_aide.text = _texte_aide()

	# Le verdict se cache par son CADRE et non par son texte : un `Label` vide
	# dans un `PanelContainer` laisse un petit rectangle noir à l'écran, ce qui
	# se lit comme un défaut de rendu. Vu sur la première capture.
	_verdict = _etiquette(couche, Vector2(1500, 20), Charte.T_APPUI)
	_verdict.text = ""
	_verdict.get_parent().visible = false


## Une étiquette sur fond OPAQUE.
##
## ⚠️ **Le premier jet posait des `Label` nus avec un liseré noir, et le panneau
## était illisible sur toutes les captures.** Deux causes, et la seconde est la
## vraie : le voile blanchit l'écran jusqu'à 0,74 d'opacité — c'est-à-dire que le
## banc devient inutilisable exactement quand on a besoin de le lire ; et un
## liseré de 6 px sur une police de 12 mange le glyphe, si bien que le texte
## clair de la charte rendait NOIR.
##
## Un fond opaque plutôt qu'un liseré plus fin : le voile peut monter à
## n'importe quelle valeur, un contraste qui dépend de lui finira toujours par
## céder quelque part.
func _etiquette(parent: CanvasLayer, ou: Vector2, taille: int) -> Label:
	var cadre := PanelContainer.new()
	cadre.position = ou
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.BACKDROP
	fond.set_content_margin_all(Charte.GAP_XS)
	fond.set_corner_radius_all(4)
	cadre.add_theme_stylebox_override("panel", fond)
	parent.add_child(cadre)

	var lab := Label.new()
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var police := Charte.police_ui(Charte.POIDS_COURANT)
	if police != null:
		lab.add_theme_font_override("font", police)
	lab.add_theme_font_size_override("font_size", taille)
	lab.add_theme_color_override("font_color", Charte.ACIER)
	cadre.add_child(lab)
	return lab


## Le halo : un dégradé radial, blanc au centre, transparent au bord. Fabriqué
## une fois — une texture recalculée à chaque changement de rayon coûterait un
## hoquet pile au moment où l'effet se déclenche, la faute déjà payée par les
## shaders compilés au premier mort.
func _texture_halo() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(Charte.HALOGENE, 1.0), Color(Charte.HALOGENE, 0.45), Color(Charte.HALOGENE, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 512
	tex.height = 512
	return tex


func _process(delta: float) -> void:
	_temps += delta
	_repos = maxf(0.0, _repos - delta)
	_bouger_adversaire(delta)
	_integrer_eblouissement(delta)
	_viser(delta)
	_rendre()
	_maj_panneau()
	if _tracer_reste > 0.0:
		_tracer_reste -= delta
		_tracer.visible = _tracer_reste > 0.0
	if _verdict_reste > 0.0:
		_verdict_reste -= delta
		if _verdict_reste <= 0.0:
			_verdict.text = ""
			_verdict.get_parent().visible = false


func _bouger_adversaire(delta: float) -> void:
	match _mouvement:
		Mouvement.IMMOBILE:
			_pos_vraie = Vector2(0, -_distance)
		Mouvement.VA_ET_VIENT:
			_pos_vraie = Vector2(sin(_temps * TAU * 0.35) * 260.0, -_distance)
		Mouvement.CERCLE:
			_pos_vraie = Vector2.UP.rotated(_temps * TAU * 0.12) * _distance
		Mouvement.ERRATIQUE:
			_prochain_cap -= delta
			if _prochain_cap <= 0.0:
				_prochain_cap = randf_range(0.35, 0.9)
				_cible_laterale = randf_range(-300.0, 300.0)
			var x := lerpf(_pos_vraie.x, _cible_laterale, minf(1.0, delta * 3.0))
			_pos_vraie = Vector2(x, -_distance)
	# L'adversaire braque toujours sa torche sur la victime : c'est la situation
	# à juger, pas une situation moyenne.
	_rot_vraie = (_tourelle.global_position - _pos_vraie).angle()
	_historique.append({"t": _temps, "pos": _pos_vraie, "rot": _rot_vraie})
	while _historique.size() > 2 and _historique[0]["t"] < _temps - HISTORIQUE_S:
		_historique.pop_front()


## L'éblouissement, par le vrai chemin : le pixel du faisceau, la courbe, le
## modèle temporel. Aucune de ces trois étapes n'est réécrite ici.
func _integrer_eblouissement(delta: float) -> void:
	if not _auto:
		_dazzle = _niveau_manuel
		return
	var arme := _armes[_arme_idx]
	var avant := Vector2.RIGHT.rotated(_rot_vraie)
	var brut := arme.lumiere_recue(avant, _pos_vraie, _tourelle.global_position)
	_dazzle = Eblouissement.integrer(_dazzle, Eblouissement.plafond_pour(brut), delta)


## La visée : `lerp_angle` vers la souris, exactement comme `player.gd`.
func _viser(delta: float) -> void:
	var vers := get_global_mouse_position() - _tourelle.global_position
	if vers.length() < 1.0:
		return
	var vitesse := VISEE_PAR_S
	if _penalites:
		vitesse *= (1.0 - _dazzle * VISEE_PENALITE)
	_tourelle.rotation = lerp_angle(_tourelle.rotation, vers.angle(),
		minf(1.0, delta * vitesse))


## Où le brouillage fait APPARAÎTRE l'adversaire — un poste par silhouette à
## dessiner. Un seul endroit décide, pour que `_rendre` n'ait plus qu'à poser.
func _postes() -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	var opacite := 1.0
	match _mode:
		Brouillage.Mode.DIPLOPIE:
			var offs := Brouillage.fantomes(_dazzle, _force, _temps, COPIES_DIPLOPIE)
			if offs.is_empty():
				sortie.append({"pos": _pos_vraie, "rot": _rot_vraie})
			else:
				for o in offs:
					sortie.append({"pos": _pos_vraie + o, "rot": _rot_vraie})
		Brouillage.Mode.TREMBLEMENT:
			var d := Brouillage.derive(_dazzle, _force, _temps)
			sortie.append({"pos": _pos_vraie + d, "rot": _rot_vraie})
		Brouillage.Mode.REMANENCE:
			var passe := _relire(_temps - Brouillage.retard(_dazzle, _force))
			sortie.append(passe)
		Brouillage.Mode.CONTRASTE:
			opacite = Brouillage.opacite(_dazzle, _force)
			sortie.append({"pos": _pos_vraie, "rot": _rot_vraie})
		_:
			sortie.append({"pos": _pos_vraie, "rot": _rot_vraie})
	for poste in sortie:
		poste["alpha"] = opacite
	return sortie


## L'historique, interpolé — jamais l'échantillon le plus proche. Un tampon lu
## au plus proche saute d'un pas à l'autre, et sur un jeu dont les fps ne sont
## pas plafonnés, ce pas vaut deux millisecondes ou vingt selon la machine :
## le brouillage se mettrait à saccader chez les uns et pas chez les autres.
func _relire(quand: float) -> Dictionary:
	if _historique.size() < 2:
		return {"pos": _pos_vraie, "rot": _rot_vraie}
	if quand >= _historique[-1]["t"]:
		return {"pos": _pos_vraie, "rot": _rot_vraie}
	if quand <= _historique[0]["t"]:
		return {"pos": _historique[0]["pos"], "rot": _historique[0]["rot"]}
	for i in range(_historique.size() - 1, 0, -1):
		var apres: Dictionary = _historique[i]
		var avant: Dictionary = _historique[i - 1]
		if quand >= float(avant["t"]):
			var duree := float(apres["t"]) - float(avant["t"])
			var t := 0.0 if duree <= 0.0 else (quand - float(avant["t"])) / duree
			return {
				"pos": Vector2(avant["pos"]).lerp(Vector2(apres["pos"]), t),
				"rot": lerp_angle(float(avant["rot"]), float(apres["rot"]), t),
			}
	return {"pos": _historique[0]["pos"], "rot": _historique[0]["rot"]}


func _rendre() -> void:
	var postes := _postes()
	for i in _silhouettes.size():
		var rig := _silhouettes[i]
		var actif := i < postes.size()
		rig.visible = actif
		if not actif:
			continue
		var poste: Dictionary = postes[i]
		rig.global_position = poste["pos"]
		rig.rotation = poste["rot"]
		# `modulate.a` et rien d'autre. Toucher la COULEUR ferait briller la
		# silhouette au lieu de la fondre : le shader ennemi plafonne `LIGHT` à
		# `COLOR.rgb`, donc l'éclaircir relève son plafond. C'est ce qui a coûté
		# un réglage entier au premier rendu — voir `ALPHA_CONTRASTE`.
		rig.modulate = Color(1, 1, 1, float(poste["alpha"]))

	if _faisceau_suit and not postes.is_empty():
		_porteur.global_position = postes[0]["pos"]
		_porteur.rotation = postes[0]["rot"]
	else:
		_porteur.global_position = _pos_vraie
		_porteur.rotation = _rot_vraie

	_croix.visible = _verite
	_croix.global_position = _pos_vraie

	_voile_rect.color = Color(Charte.HALOGENE,
		(_dazzle * VOILE_FACTEUR) if _voile else 0.0)

	var h := Brouillage.halo(_dazzle, _force) if _mode == Brouillage.Mode.HALO else {"rayon": 0.0, "intensite": 0.0}
	var rayon := float(h["rayon"])
	_halo.visible = rayon > 1.0
	if _halo.visible:
		# Du monde vers la couche d'écran. `get_canvas_transform()` porte la
		# caméra ; la mise à l'échelle de la fenêtre s'applique ensuite aux DEUX
		# couches, donc elles restent d'accord quelle que soit la taille.
		var centre := get_viewport().get_canvas_transform() * _pos_vraie
		_halo.size = Vector2(rayon, rayon) * 2.0
		_halo.position = centre - Vector2(rayon, rayon)
		_halo.modulate = Color(1, 1, 1, float(h["intensite"]))


# --------------------------------------------------------------------------
# Le tir — le seul endroit où le banc AFFIRME quelque chose.
# --------------------------------------------------------------------------

func _tirer() -> void:
	if _repos > 0.0:
		return
	_repos = REPOS_TIR
	var depuis := _tourelle.global_position
	var vers_vrai := _pos_vraie - depuis
	var distance := vers_vrai.length()
	# L'écart entre où le canon regarde et où la cible EST. Signé pour le
	# calcul, pris en valeur absolue pour la moyenne : sans cela, rater à gauche
	# compenserait rater à droite et le banc annoncerait une visée parfaite.
	var ecart := angle_difference(vers_vrai.angle(), _tourelle.rotation)
	var lateral := distance * sin(ecart)
	var touche := absf(lateral) <= RAYON_JOUEUR

	var releve: Dictionary = _releves[_mode]
	releve["tirs"] += 1
	releve["force"] = _force
	if touche:
		releve["touches"] += 1
	releve["somme_ecart"] += absf(rad_to_deg(ecart))
	releve["somme_lateral"] += absf(lateral)

	_tracer.points = PackedVector2Array([depuis, depuis + Vector2.RIGHT.rotated(_tourelle.rotation) * 1400.0])
	_tracer.default_color = Charte.VERT if touche else Charte.AMBRE
	_tracer.visible = true
	_tracer_reste = 0.16
	_verdict.text = "TOUCHÉ" if touche else "RATÉ  %+.0f px" % lateral
	_verdict.add_theme_color_override("font_color", Charte.VERT if touche else Charte.ROUGE)
	_verdict.get_parent().visible = true
	_verdict_reste = 0.9


func _tableau() -> void:
	print("")
	print("--- brouillage : ce que chaque mode a coûté à la visée ---")
	print("  %-13s %6s %8s %10s %12s %7s" % ["mode", "tirs", "au but", "écart moy.", "latéral moy.", "force"])
	for m in Brouillage.Mode.values():
		var r: Dictionary = _releves[m]
		var n: int = r["tirs"]
		if n == 0:
			continue
		print("  %-13s %6d %7.0f%% %9.2f° %11.0f px %7.1f" % [
			Brouillage.NOMS[m], n, 100.0 * float(r["touches"]) / float(n),
			float(r["somme_ecart"]) / float(n), float(r["somme_lateral"]) / float(n),
			float(r["force"]),
		])
	print("")
	print("  Rappel : « au but » vaut pour un écart latéral sous %.0f px (le rayon" % RAYON_JOUEUR)
	print("  du joueur). La victime ne se déplace pas — la pénalité de VITESSE")
	print("  n'entre pas dans ces chiffres, seule celle de LECTURE y entre.")


# --------------------------------------------------------------------------
# Les touches
# --------------------------------------------------------------------------

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.pressed \
			and evenement.button_index == MOUSE_BUTTON_LEFT:
		_tirer()


func _unhandled_key_input(evenement: InputEvent) -> void:
	if not (evenement is InputEventKey) or not evenement.pressed or evenement.echo:
		return
	match evenement.keycode:
		KEY_0, KEY_KP_0: _mode = Brouillage.Mode.AUCUN
		KEY_1, KEY_KP_1: _mode = Brouillage.Mode.HALO
		KEY_2, KEY_KP_2: _mode = Brouillage.Mode.DIPLOPIE
		KEY_3, KEY_KP_3: _mode = Brouillage.Mode.TREMBLEMENT
		KEY_4, KEY_KP_4: _mode = Brouillage.Mode.REMANENCE
		KEY_5, KEY_KP_5: _mode = Brouillage.Mode.CONTRASTE
		KEY_LEFT: _force = maxf(0.0, _force - 0.1)
		KEY_RIGHT: _force = minf(2.0, _force + 0.1)
		KEY_UP:
			_auto = false
			_niveau_manuel = minf(1.0, _niveau_manuel + 0.05)
		KEY_DOWN:
			_auto = false
			_niveau_manuel = maxf(0.0, _niveau_manuel - 0.05)
		KEY_A: _auto = not _auto
		KEY_W:
			_arme_idx = (_arme_idx + 1) % _armes.size()
			_poser_arme()
		KEY_M: _mouvement = (_mouvement + 1) % NOMS_MOUVEMENT.size()
		KEY_Z: _distance = maxf(140.0, _distance - 20.0)
		KEY_X: _distance = minf(460.0, _distance + 20.0)
		KEY_L: _faisceau_suit = not _faisceau_suit
		KEY_P: _penalites = not _penalites
		KEY_V: _voile = not _voile
		KEY_T: _verite = not _verite
		KEY_R:
			for m in Brouillage.Mode.values():
				_releves[m] = {"tirs": 0, "touches": 0, "somme_ecart": 0.0,
					"somme_lateral": 0.0, "force": _force}
		KEY_ESCAPE:
			_tableau()
			get_tree().quit()


func _poser_arme() -> void:
	var arme := _armes[_arme_idx]
	_torche.texture = arme.get_torch_texture()
	_torche.texture_scale = arme.echelle_torche()


func _maj_panneau() -> void:
	var arme := _armes[_arme_idx]
	var r: Dictionary = _releves[_mode]
	var n: int = r["tirs"]
	var au_but := "—"
	var lateral := "—"
	if n > 0:
		au_but = "%.0f %%" % (100.0 * float(r["touches"]) / float(n))
		lateral = "%.0f px" % (float(r["somme_lateral"]) / float(n))
	_panneau.text = "\n".join([
		"MODE   %d · %s      force %.1f" % [_mode, Brouillage.NOMS[_mode], _force],
		"",
		"éblouissement   %.2f   (%s)" % [_dazzle, "mesuré" if _auto else "forcé"],
		"arme            %s" % arme.name,
		"distance        %.0f px      mouvement  %s" % [_distance, NOMS_MOUVEMENT[_mouvement]],
		"faisceau        %s" % ("suit le brouillage" if _faisceau_suit else "reste sur la vérité"),
		"pénalité visée  %s        voile  %s" % [
			"oui" if _penalites else "non", "oui" if _voile else "non"],
		"",
		"tirs %d      au but %s      raté moyen %s" % [n, au_but, lateral],
	])


func _texte_aide() -> String:
	return "clic tirer   0-5 mode   ←/→ force   A auto/forcé   ↑/↓ niveau   " \
		+ "W arme   M mouvement   Z/X distance\n" \
		+ "L le faisceau suit   P pénalité de visée   V voile   T montrer la vérité   " \
		+ "R remettre à zéro   Échap tableau et sortie"
