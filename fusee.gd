class_name Fusee
extends Node2D
## La fusée éclairante — chantier FUSÉE, étapes FU1 (objet, lancer, trois actes)
## et FU2 (fumée : nappes, silhouette, sillage).
##
## Même famille que `Bullet` : nœud NON répliqué, instancié localement chez les
## deux pairs par le RPC de spawn de `game_state.gd`. Tout l'état se dérive de
## quatre paramètres transmis une fois — départ, cible, graine, tireur — plus
## l'âge : aucune synchro en vol, et la killcam reconstruit une fusée à un âge
## arbitraire en appelant `appliquer_age()` (voir `ReplaySystem.Snapshot`).
##
## Le vol est une cloche : il SURVOLE les murs (aucun test de collision — la
## cible a été validée au spawn par l'hôte), la hauteur est un habillage. La
## lumière ne prend ses ombres qu'au sol : en vol, elle traverserait mal les
## occluders qu'elle est censée survoler.

const VOILE_SHADER := preload("res://fumee_fusee.gdshader")

## Blanc « magnésium » : la seule lumière chimique du jeu. Dérivée :
## HALOGENE (0.98, 0.91, 0.80) refroidi — les canaux rouge/bleu échangés autour
## du gris, pour jurer volontairement avec tout ce que la charte éclaire.
const COULEUR_MAGNESIUM := Color(0.90, 0.93, 0.99)

## Empreinte de la lumière au sol, en pixels de diamètre utile. Légèrement plus
## large que la fumée : la lumière déborde du nuage, la cachette vit DANS la
## zone informée.
const EMPREINTE_LUMIERE := 440.0
const EMPREINTE_VOL := 160.0

## Hauteur factice de la cloche, en pixels d'écran au sommet.
const HAUTEUR_CLOCHE_PX := 26.0

# Paramètres du spawn — posés AVANT add_child, comme pour Bullet.
var depart := Vector2.ZERO
var cible := Vector2.ZERO
var graine: int = 0
var shooter_id: int = 0
var is_replay: bool = false
## Les corps à silhouetter et à faire creuser le sillage : [p1, p2] en jeu,
## [ghost_p1, ghost_p2] en killcam. Posé par game_state au spawn.
var joueurs: Array = []

var _age: float = 0.0
var _duree_vol: float = 0.0
var _fenetres: Array = []
var _atterrie: bool = false

var _lumiere: PointLight2D
var _coeur: Sprite2D
var _nappes: Array = []
var _voile: Sprite2D
var _voile_mat: ShaderMaterial
var _combustion: AudioStreamPlayer2D

# Sillage : par joueur, la position du dernier échantillon et l'instant du
# prochain ; les points vivants sont partagés (un seul tampon d'uniforms).
var _sillage_points: Array = []
var _sillage_precedent: Dictionary = {}
var _sillage_prochain: float = 0.0
var _trous_pousses: bool = false

static var _cache_textures: Dictionary = {}


## Un blanc uni : le voile n'échantillonne pas sa texture, tout vient du shader.
static func _texture_blanche() -> ImageTexture:
	if _cache_textures.has("blanc"):
		return _cache_textures["blanc"]
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_cache_textures["blanc"] = tex
	return tex


## Une nappe de volutes : bruit FBM sous un masque radial, blanche + alpha —
## la teinte vient des lumières qui l'éclairent (même règle que les masques de
## `light_textures.gd`). Générée une fois, partagée entre toutes les fusées.
## Le jour où une planche peinte arrive, elle se substitue ici sans autre geste.
static func _texture_volute(graine_tex: int) -> ImageTexture:
	var cle := "volute_%d" % graine_tex
	if _cache_textures.has(cle):
		return _cache_textures[cle]
	var taille := 128
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_VALUE
	bruit.fractal_octaves = 3
	bruit.frequency = 0.05
	bruit.seed = graine_tex
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var centre := Vector2(taille, taille) * 0.5
	for y in taille:
		for x in taille:
			var d := Vector2(x, y).distance_to(centre) / (taille * 0.5)
			var masque := clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
			var n := (bruit.get_noise_2d(x, y) + 1.0) * 0.5
			var alpha := masque * lerpf(0.35, 1.0, n)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var tex := ImageTexture.create_from_image(img)
	_cache_textures[cle] = tex
	return tex


func _ready() -> void:
	# Comme Bullet : le conteneur parent ne doit imposer ni transform ni ordre.
	set_as_top_level(true)
	global_position = depart
	_duree_vol = FuseeModele.duree_vol(depart.distance_to(cible))
	_fenetres = FuseeModele.fenetres_agonie(graine)

	_lumiere = PointLight2D.new()
	_lumiere.name = "Halo"
	LightTextures.poser(_lumiere, LightTextures.RETRODIFFUSION, EMPREINTE_VOL)
	_lumiere.color = COULEUR_MAGNESIUM
	_lumiere.energy = FuseeModele.ENERGIE_VOL
	# 1 = décor, 2 = sprites ennemis, 4 = sprites du joueur local : la fusée est
	# une lumière NEUTRE, elle éclaire tout le monde dans les deux vues.
	_lumiere.range_item_cull_mask = 1 | 2 | 4
	_lumiere.shadow_enabled = false # en vol, elle survole les murs
	_lumiere.shadow_item_cull_mask = 1 # murs seuls : un corps ne bouche pas sa propre lumière
	_lumiere.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	add_child(_lumiere)

	_coeur = Sprite2D.new()
	_coeur.name = "Coeur"
	_coeur.texture = LightTextures.radial(16)
	_coeur.material = _materiau_additif()
	_coeur.modulate = COULEUR_MAGNESIUM
	_coeur.z_index = 12
	add_child(_coeur)

	# En écran scindé, tout se dessine deux fois : une nappe de moins.
	var nb_nappes := FuseeModele.NAPPES_PAR_DEFAUT
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		nb_nappes -= 1
	for i in nb_nappes:
		var nappe := Sprite2D.new()
		nappe.name = "Nappe%d" % (i + 1)
		nappe.texture = _texture_volute(i + 1)
		nappe.modulate = Color(0.72, 0.70, 0.68, 0.0)
		nappe.z_index = 10
		add_child(nappe)
		_nappes.append(nappe)

	_voile = Sprite2D.new()
	_voile.name = "Voile"
	_voile.texture = _texture_blanche()
	_voile.z_index = 11
	_voile_mat = ShaderMaterial.new()
	_voile_mat.shader = VOILE_SHADER
	# Les uniforms qui ne bougent jamais se posent UNE fois ; la boucle d'âge ne
	# pousse que ce qui change (revue du lot : huit poussées par tick, dont
	# cinq constantes).
	_voile_mat.set_shader_parameter("graine", float(graine % 1000))
	_voile_mat.set_shader_parameter("masse_opacite", FuseeModele.MASSE_OPACITE)
	_voile.material = _voile_mat
	add_child(_voile)

	if not is_replay:
		_combustion = AudioStreamPlayer2D.new()
		_combustion.name = "Combustion"
		# Câblée, muette tant que le fichier manque (règle « câbler, taire »).
		# Voix DÉDIÉE, hors du pool de seize : une boucle de quinze secondes s'y
		# ferait voler sa voix par n'importe quel son de priorité égale, et la
		# référence rendue désignerait alors un autre son. Patron `_dazzle_player`.
		_combustion.stream = AudioManager.get_audio_stream("fusee_combustion")
		_combustion.max_distance = AudioManager.portee_courante("fusee_combustion")
		_combustion.attenuation = AudioManager.courbe_distance
		_combustion.volume_db = AudioManager.niveau_relatif_de("fusee_combustion")
		add_child(_combustion)
		AudioManager.play_sfx_2d_random_pitch("fusee_lancer", depart)
	else:
		# La killcam pilote l'âge elle-même, image par image.
		set_physics_process(false)

	_appliquer_age(_age)


static var _materiau_additif_partage: CanvasItemMaterial

static func _materiau_additif() -> CanvasItemMaterial:
	if _materiau_additif_partage == null:
		_materiau_additif_partage = CanvasItemMaterial.new()
		_materiau_additif_partage.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		# UNSHADED comme le patron Bullet : le cœur EST une source, il doit se
		# voir dans le noir complet — éclairé, il serait avalé hors de son halo.
		_materiau_additif_partage.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _materiau_additif_partage


static var _voile_rechauffe := false

## Paie hors action ce que le premier lancer paierait pile sur l'action :
## la génération des textures de volutes (3 × 16 384 set_pixel — 8,5 ms
## mesurées à la revue) et la compilation du shader du voile (un quad invisible
## dessiné une image). Même doctrine que les shaders préchargés de player.gd.
## Appelée par `rebuild_arena()` ; idempotente.
static func prechauffer(parent: Node) -> void:
	for i in FuseeModele.NAPPES_PAR_DEFAUT:
		_texture_volute(i + 1)
	_texture_blanche()
	if _voile_rechauffe or parent == null or not parent.is_inside_tree():
		return
	_voile_rechauffe = true
	var chauffe := Sprite2D.new()
	chauffe.name = "ChauffeVoileFusee"
	chauffe.texture = _texture_blanche()
	var mat := ShaderMaterial.new()
	mat.shader = VOILE_SHADER
	mat.set_shader_parameter("alpha_globale", 0.0)
	chauffe.material = mat
	parent.add_child(chauffe)
	parent.get_tree().process_frame.connect(chauffe.queue_free, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_age += delta
	_appliquer_age(_age)
	if FuseeModele.acte_a(_age - _duree_vol) == FuseeModele.Acte.MORTE:
		queue_free()


## L'âge depuis le LANCER (vol compris) — lu par ReplaySystem pour l'instantané.
func age_depuis_lancer() -> float:
	return _age


## Applique l'état dérivé d'un âge : la killcam appelle ceci directement avec
## l'âge lu dans l'instantané, le vivant l'appelle depuis `_physics_process`.
func appliquer_age(age: float) -> void:
	_age = age
	_appliquer_age(age)


func _appliquer_age(age: float) -> void:
	var age_combustion := age - _duree_vol

	# --- Le vol : cloche au-dessus des murs, hauteur factice sur le cœur. ---
	if age_combustion < 0.0:
		var t01 := age / _duree_vol if _duree_vol > 0.0 else 1.0
		global_position = FuseeModele.position_vol(depart, cible, t01)
		var hauteur := FuseeModele.hauteur_vol(t01)
		_coeur.position = Vector2(0.0, -hauteur * HAUTEUR_CLOCHE_PX)
		_coeur.scale = Vector2.ONE * (1.0 + hauteur * 0.6)
	else:
		global_position = cible
		_coeur.position = Vector2.ZERO
		_coeur.scale = Vector2.ONE
		if not _atterrie:
			_atterrir()

	# --- La lumière : énergie et température dérivées de l'âge. ---
	var intensite: float = GameSettings.current_effect("fusee_agonie")
	var energie := FuseeModele.energie_a(age_combustion, _fenetres, intensite)
	var temperature := FuseeModele.temperature_a(age_combustion)
	var couleur := COULEUR_MAGNESIUM.lerp(Charte.AMBRE, temperature)
	_lumiere.energy = energie
	_lumiere.color = couleur
	_lumiere.enabled = energie > 0.005
	_coeur.modulate = Color(couleur.r, couleur.g, couleur.b,
		clampf(energie / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0))

	# --- La fumée : nappes tournantes + voile à trous. ---
	var alpha_fumee := FuseeModele.alpha_fumee_a(age_combustion)
	var echelle := FuseeModele.echelle_fumee_a(maxf(age_combustion, 0.0))
	var diametre := FuseeModele.RAYON_FUMEE * 2.0 * echelle
	# Sans fumée (vol, fusée éteinte), rien à peindre ni à pousser au shader.
	var fumee_active := alpha_fumee > 0.0
	_voile.visible = fumee_active
	for i in _nappes.size():
		var nappe: Sprite2D = _nappes[i]
		nappe.visible = fumee_active
		if not fumee_active:
			continue
		# Rotation dérivée de l'âge (jamais d'un timer) : identique chez les
		# deux pairs et dans la killcam, avance rapide comprise.
		nappe.rotation = float(FuseeModele.NAPPE_VITESSES[i]) * maxf(age_combustion, 0.0) * TAU
		nappe.scale = Vector2.ONE * (diametre / 128.0) * (1.0 - 0.12 * i)
		nappe.modulate.a = FuseeModele.NAPPE_ALPHA * alpha_fumee
	if fumee_active:
		_voile.scale = Vector2.ONE * (diametre / 4.0)
		_voile_mat.set_shader_parameter("alpha_globale", alpha_fumee * 0.8)
		# L'âge nourrit la dérive des volutes DANS le shader — jamais TIME, que
		# la killcam ne saurait pas rembobiner.
		_voile_mat.set_shader_parameter("age", maxf(age_combustion, 0.0))

	# Le grésillement meurt au POP de fin d'agonie, pas en fondu sous le résidu :
	# le silence soudain est un événement de jeu (le premier pas dedans s'entend).
	if _combustion and _combustion.playing \
			and FuseeModele.acte_a(age_combustion) >= FuseeModele.Acte.RESIDU:
		_combustion.stop()

	if fumee_active:
		_maj_sillage_et_masses(age_combustion, diametre)


## Échantillonne le sillage et pousse masses + trous au shader. Tout se calcule
## depuis des positions déjà répliquées (ou des fantômes de killcam) : aucune
## donnée locale non partagée n'entre jamais dans le rendu de la fumée.
func _maj_sillage_et_masses(age_combustion: float, diametre: float) -> void:
	var rayon := diametre * 0.5

	# L'horloge peut RECULER (banc qui saute d'acte, bench qui boucle l'âge,
	# killcam) : sans ce reset, `_sillage_prochain` resterait au-dessus de tout
	# âge atteignable — plus un point, et les anciens trous figés grands
	# ouverts (revue du lot). On repart d'un nuage vierge, comme au vrai début.
	if age_combustion + FuseeModele.SILLAGE_PERIODE < _sillage_prochain:
		_sillage_prochain = age_combustion
		_sillage_points.clear()
		_sillage_precedent.clear()

	if age_combustion >= 0.0 and age_combustion >= _sillage_prochain:
		_sillage_prochain = age_combustion + FuseeModele.SILLAGE_PERIODE
		for j in joueurs:
			if not is_instance_valid(j):
				continue
			var pos: Vector2 = j.global_position
			var precedent: Vector2 = _sillage_precedent.get(j.get_instance_id(), pos)
			_sillage_precedent[j.get_instance_id()] = pos
			if pos.distance_to(global_position) > rayon:
				continue
			# L'immobilité ne creuse rien : la discrétion se paie en vitesse.
			var vitesse := pos.distance_to(precedent) / FuseeModele.SILLAGE_PERIODE
			if vitesse < FuseeModele.SILLAGE_VITESSE_MIN:
				continue
			_sillage_points.append({"pos": pos, "t": age_combustion})
	_sillage_points = FuseeModele.filtrer_sillage(_sillage_points, age_combustion)

	# Les trous se referment continûment : tant qu'il y a des points, on pousse
	# chaque image ; le cas courant (aucun point) ne pousse qu'une fois.
	if not _sillage_points.is_empty() or _trous_pousses:
		var trous := PackedVector3Array()
		for p in _sillage_points:
			var uv: Vector2 = (p["pos"] - global_position) / diametre + Vector2(0.5, 0.5)
			var r := FuseeModele.rayon_sillage(age_combustion - p["t"]) / diametre
			trous.append(Vector3(uv.x, uv.y, r))
		var nb_trous := mini(trous.size(), 16)
		while trous.size() < 16:
			trous.append(Vector3.ZERO)
		_voile_mat.set_shader_parameter("nb_trous", nb_trous)
		_voile_mat.set_shader_parameter("trous", trous)
		_trous_pousses = nb_trous > 0

	var masses := PackedVector2Array()
	for j in joueurs:
		if not is_instance_valid(j):
			continue
		var pos: Vector2 = j.global_position
		if pos.distance_to(global_position) > rayon:
			continue
		var uv: Vector2 = (pos - global_position) / diametre + Vector2(0.5, 0.5)
		masses.append(uv)
	var nb_masses := mini(masses.size(), 2)
	while masses.size() < 2:
		masses.append(Vector2.ZERO)
	_voile_mat.set_shader_parameter("nb_masses", nb_masses)
	_voile_mat.set_shader_parameter("masses", masses)
	_voile_mat.set_shader_parameter("masse_rayon_uv", FuseeModele.MASSE_RAYON * 2.0 / diametre)


func _atterrir() -> void:
	_atterrie = true
	# Au sol, la lumière reprend ses ombres : sans occlusion, la torche — et la
	# fusée — traverseraient les murs, et la mécanique centrale disparaît.
	_lumiere.shadow_enabled = true
	LightTextures.poser(_lumiere, LightTextures.RETRODIFFUSION, EMPREINTE_LUMIERE)
	if is_replay:
		return
	AudioManager.play_sfx_2d_random_pitch("fusee_atterrit", cible)
	if _combustion and _combustion.stream:
		# Le bus (occlusion par les murs) se choisit une fois, à l'atterrissage —
		# c'est le contrat des one-shots du pool, assumé ici pour une boucle en
		# attendant l'étape audio (FU4) : la position de la fusée ne bouge plus,
		# seule l'oreille bouge encore.
		var part: float = AudioManager.part_occultee(cible)
		_combustion.bus = AudioManager.bus_pour("SFX", part > 0.0)
		if part > 0.0:
			_combustion.volume_db += AudioManager.OCCLUSION_PENTE_DB * part
		_combustion.play()


func _exit_tree() -> void:
	if _combustion and _combustion.playing:
		_combustion.stop()
