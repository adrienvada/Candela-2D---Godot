class_name Fusee
extends Node2D
## La fusée éclairante — chantier FUSÉE, étapes FU1-FU2, retouches FU2.1
## (premier essai d'Adrien : rebonds, rouge de détresse, sprites effacés dans
## la fumée, agonie organique, textures substituables).
##
## Même famille que `Bullet` : nœud NON répliqué, instancié localement chez les
## deux pairs par le RPC de spawn de `game_state.gd`. Le vol REBONDIT sur les
## murs — simulation locale déterministe (mêmes murs, mêmes pas de physique,
## patron des ricochets de `bullet.gd`), aucune synchro en vol. La killcam ne
## rejoue pas le vol : elle lit la position dans l'instantané et reconstruit
## lumière et fumée depuis l'âge de combustion (`appliquer_age`).
##
## Rouge de détresse d'abord — une fusée de marine — puis l'orange de la
## braise, puis des rallumages sporadiques avant le noir.

const VOILE_SHADER := preload("res://fumee_fusee.gdshader")
## Préchargé comme tous les shaders du jeu : un `Shader.new()` à la volée
## compile au premier usage, donc pile sur l'action (règle de `player.gd`).
const NAPPE_SHADER := preload("res://nappe_fusee.gdshader")

## Le rouge de détresse. Dérivé : CARMIN (0.551, 0.168, 0.191) porté à la
## valeur de l'AMBRE (× 0.96/0.551 ≈ 1.74) — même rouge, mais assez lumineux
## pour être une LUMIÈRE et non une matière.
const COULEUR_DETRESSE := Color(0.96, 0.293, 0.334)

## Empreinte de la lumière au sol, en pixels de diamètre utile. Légèrement plus
## large que la fumée : la lumière déborde du nuage, la cachette vit DANS la
## zone informée.
const EMPREINTE_LUMIERE := 440.0
const EMPREINTE_VOL := 160.0

## Hauteur factice du vol, en pixels au départ — elle suit l'élan restant.
const HAUTEUR_VOL_PX := 18.0

## Largeur de la PLANCHE du corps à l'écran, en pixels de monde — **l'empreinte
## commande, jamais le fichier** (même règle que `EMPREINTE_VISEUR` et que les
## masques de lumière) : recuire la planche à une autre résolution ne doit RIEN
## changer à sa taille en jeu.
##
## L'empreinte porte la planche ENTIÈRE, marges comprises, et la fusée n'en
## occupe que ~62 % — elle mesure donc ~19 px à l'écran, un peu plus de la
## moitié d'un joueur (36 px de large). C'est déjà généreux pour un objet de
## 25 cm : à l'échelle du jeu il vaudrait 5 px, et il serait illisible. La
## lisibilité l'emporte, mais pas au point d'en faire une poutre. Valeur de
## départ, à doser en FU6.
const EMPREINTE_CORPS := 30.0
## Le point de braise au cœur de la fusée, en unités de monde (lot 3).
const EMPREINTE_COEUR := 16.0

## Deux rebonds dans la même seconde s'entendent ; vingt dans un angle, non.
const REBOND_SON_ESPACEMENT := 0.09

# Paramètres du spawn — posés AVANT add_child, comme pour Bullet.
var depart := Vector2.ZERO
var direction := Vector2.RIGHT
var graine: int = 0
var shooter_id: int = 0
var is_replay: bool = false
## Les corps à silhouetter, à effacer dans la fumée et à faire creuser le
## sillage : [p1, p2] en jeu, [ghost_p1, ghost_p2] en killcam.
var joueurs: Array = []

## L'âge de COMBUSTION : négatif en vol, 0 à l'atterrissage. C'est LUI que
## l'instantané transporte — le vol, non dérivable de l'âge depuis les rebonds,
## voyage par sa position.
var _age_combustion: float = -1.0
var _velocite := Vector2.ZERO
var _fenetres: Array = []
var _atterrie: bool = false
var _dernier_son_rebond: float = -1.0
var _exclusions: Array[RID] = []

var _lumiere: PointLight2D
var _coeur: Sprite2D
var _corps: Sprite2D
var _nappes: Array = []
var _voile: Sprite2D
var _voile_mat: ShaderMaterial
var _combustion: AudioStreamPlayer2D

# Occultation : ce que la fumée cache aux sprites — lu par player.gd via le
# groupe « fusees », recalculé à chaque application d'âge.
var _alpha_fumee_courant: float = 0.0
var _rayon_courant: float = FuseeModele.RAYON_FUMEE

# Sillage : par joueur, la position du dernier échantillon et l'instant du
# prochain ; les points vivants sont partagés (un seul tampon d'uniforms).
var _sillage_points: Array = []
var _sillage_precedent: Dictionary = {}
var _sillage_prochain: float = 0.0
var _trous_pousses: bool = false

# FU3 — diffusion du flash de tir dans la fumée : un pouls, jamais répliqué
# (dérivé localement d'un tir déjà arbitré ailleurs). `_diffusion_debut` est
# hors de portée (duree_combustion() + PANACHE_DUREE la dépasse toujours) tant
# qu'aucun tir n'a eu lieu, pour que la fusée naisse sans pouls résiduel.
var _diffusion_debut: float = -1000.0

# FU3 — tunnels de balle : { entree: Vector2, sortie: Vector2, sombre: bool,
# age_debut: float }, en âge de COMBUSTION. Purement local, jamais répliqué ni
# rejoué en killcam — un effet cosmétique dérivé d'un tir déjà arbitré ailleurs.
var _tunnels: Array = []
const TUNNELS_MAX := 6 # une volée de pompe peut en ouvrir jusqu'à cinq
var _tunnels_pousses: bool = false

# FU5 — l'extinction. Une fois `_eteinte`, la fusée ne suit plus l'horloge de
# combustion : elle suit celle, indépendante, de son propre panache.
var _eteinte: bool = false
var _age_extinction: float = 0.0

static var _cache_textures: Dictionary = {}


## L'échelle qui donne à une texture l'empreinte voulue, quelle que soit sa
## résolution. **Personne ici n'écrit un `scale` autrement qu'en passant par
## elle** : le dépôt a déjà payé deux fois qu'une planche recuite à une autre
## résolution change de taille en jeu sans que rien ne le relie à la recuisson
## (les masques de lumière, puis le viseur à 48 px — voir « Pièges connus »).
## C'est ce qui rend la substitution d'une texture VRAIMENT sans effet de bord :
## la planche 1024 d'Adrien et le repli procédural 128 rendent la même taille.
static func _echelle_pour(tex: Texture2D, empreinte: float) -> float:
	if tex == null or tex.get_width() <= 0:
		return 1.0
	return empreinte / float(tex.get_width())


## Un blanc uni : le voile n'échantillonne pas sa texture, tout vient du shader.
static func _texture_blanche() -> ImageTexture:
	if _cache_textures.has("blanc"):
		return _cache_textures["blanc"]
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_cache_textures["blanc"] = tex
	return tex


## Une nappe de volutes. Une planche PEINTE (`assets/sprites/fusee_volute_N.png`,
## la filière Gemini d'Adrien) prime dès qu'elle existe ; sinon, repli
## procédural — bruit FBM sous un masque radial, blanc + alpha, la teinte
## venant des lumières (même règle que les masques de `light_textures.gd`).
## L'absence du fichier n'est pas un défaut : c'est l'état ATTENDU tant que la
## planche n'est pas livrée — d'où l'absence de cri, contrairement à `masque()`.
static func _texture_volute(graine_tex: int) -> Texture2D:
	var cle := "volute_%d" % graine_tex
	if _cache_textures.has(cle):
		return _cache_textures[cle]
	# La planche numérotée d'abord, puis la première, puis la planche SANS
	# numéro — une seule volute livrée est le cas courant, et l'exiger numérotée
	# ferait échouer la substitution en silence (payé le 2026-09-07 : la planche
	# détourée est arrivée sous `fusee_volute.png` et le code a continué de
	# charger l'ancienne, au damier, sans que rien ne le dise).
	# Repli procédural en dernier seulement : mêler une volute peinte à des
	# nappes de bruit donnerait un nuage qui se contredit d'une couche à
	# l'autre, alors que la même planche à trois rotations différentes EST
	# l'effet recherché — c'est déjà ce que font les trois vitesses de rotation.
	var candidats := [
		"res://assets/sprites/fusee_volute_%d.png" % graine_tex,
		"res://assets/sprites/fusee_volute_1.png",
		"res://assets/sprites/fusee_volute.png",
	]
	for chemin in candidats:
		if ResourceLoader.exists(chemin, "Texture2D"):
			var peinte: Texture2D = load(chemin)
			_cache_textures[cle] = peinte
			return peinte
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
	_fenetres = FuseeModele.fenetres_agonie(graine)
	add_to_group("fusees")

	_lumiere = PointLight2D.new()
	_lumiere.name = "Halo"
	LightTextures.poser(_lumiere, LightTextures.RETRODIFFUSION, EMPREINTE_VOL)
	_lumiere.color = COULEUR_DETRESSE
	_lumiere.energy = FuseeModele.ENERGIE_VOL
	# 1 = décor, 2 = sprites ennemis, 4 = sprites du joueur local : la fusée est
	# une lumière NEUTRE, elle éclaire tout le monde dans les deux vues.
	_lumiere.range_item_cull_mask = 1 | 2 | 4
	# Les ombres dès le départ : la fusée rebondit sur les murs, elle ne les
	# survole plus — une lumière qui les traverserait mentirait sur sa physique.
	_lumiere.shadow_enabled = true
	_lumiere.shadow_item_cull_mask = 1 # murs seuls : un corps ne bouche pas sa propre lumière
	_lumiere.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	add_child(_lumiere)

	# Le cœur incandescent — refonte roman graphique, lot 3 (2026-09-11). C'était
	# le dernier dégradé radial procédural en production (`LightTextures.radial`),
	# en mélange additif : une lueur floue. C'est désormais le masque ambiant
	# ENCRÉ (trois paliers, lot 1) ramené à 16 px, en mélange normal et non
	# éclairé : un point de braise à bord franc, qui se voit dans le noir complet
	# parce qu'il EST la source — sans s'additionner à son propre halo.
	_coeur = Sprite2D.new()
	_coeur.name = "Coeur"
	var tex_coeur := LightTextures.masque(LightTextures.AMBIANTE)
	if tex_coeur == null:
		tex_coeur = LightTextures.radial(16)
	_coeur.texture = tex_coeur
	_coeur.scale = Vector2.ONE * _echelle_pour(tex_coeur, EMPREINTE_COEUR)
	_coeur.material = _materiau_incandescent()
	_coeur.modulate = COULEUR_DETRESSE
	_coeur.z_index = 12
	add_child(_coeur)

	# Le corps physique de la fusée — seulement si la planche peinte existe
	# (filière Gemini). Sans elle, le cœur incandescent suffit.
	var chemin_corps := "res://assets/sprites/fusee_corps.png"
	if ResourceLoader.exists(chemin_corps, "Texture2D"):
		_corps = Sprite2D.new()
		_corps.name = "Corps"
		var tex_corps: Texture2D = load(chemin_corps)
		_corps.texture = tex_corps
		_corps.scale = Vector2.ONE * _echelle_pour(tex_corps, EMPREINTE_CORPS)
		_corps.light_mask = 2
		_corps.z_index = 11
		add_child(_corps)

	# En écran scindé, tout se dessine deux fois : une nappe de moins.
	var nb_nappes := FuseeModele.NAPPES_PAR_DEFAUT
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		nb_nappes -= 1
	var mat_nappe := ShaderMaterial.new()
	mat_nappe.shader = NAPPE_SHADER
	for i in nb_nappes:
		var nappe := Sprite2D.new()
		nappe.name = "Nappe%d" % (i + 1)
		nappe.texture = _texture_volute(i + 1)
		# Un seul matériau pour les trois : elles ne diffèrent que par leur
		# transform et leur modulate, rien qui vive dans le shader.
		nappe.material = mat_nappe
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
		_velocite = direction.normalized() * FuseeModele.VITESSE_LANCER
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
		# La killcam pilote l'âge et la position elle-même, image par image.
		_atterrie = true
		_age_combustion = 0.0
		set_physics_process(false)

	_appliquer_age(_age_combustion)


static var _materiau_incandescent_partage: CanvasItemMaterial

## Non éclairé, en mélange NORMAL (plus additif depuis le lot 3, 2026-09-11) :
## le cœur EST une source, il doit se voir dans le noir complet — éclairé, il
## serait avalé hors de son halo. L'addition, elle, n'apportait qu'un flou.
static func _materiau_incandescent() -> CanvasItemMaterial:
	if _materiau_incandescent_partage == null:
		_materiau_incandescent_partage = CanvasItemMaterial.new()
		_materiau_incandescent_partage.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _materiau_incandescent_partage


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
	if _eteinte:
		_age_extinction += delta
		_appliquer_extinction()
		if _age_extinction >= FuseeModele.PANACHE_DUREE:
			queue_free()
		return
	if not _atterrie:
		_voler(delta)
	else:
		_age_combustion += delta
	_appliquer_age(_age_combustion)
	if FuseeModele.acte_a(_age_combustion) == FuseeModele.Acte.MORTE:
		queue_free()


## Un pas de vol : avance, rebondit sur les murs, se freine, se pose à bout
## d'élan. Rayon contre la couche 1 (murs) en excluant les corps des joueurs —
## eux aussi couche 1 (map_geometry), et une fusée ne rebondit pas sur un torse.
func _voler(delta: float) -> void:
	var espace := get_world_2d().direct_space_state
	if espace == null:
		return
	if _exclusions.is_empty():
		for j in joueurs:
			if is_instance_valid(j) and j is CollisionObject2D:
				_exclusions.append(j.get_rid())
	var restant := delta
	# Deux rebonds peuvent tomber dans le même tick (un angle serré) : on
	# consomme le pas en morceaux, quatre réflexions au plus.
	for _i in 4:
		if restant <= 0.0:
			break
		var pas := _velocite * restant
		var q := PhysicsRayQueryParameters2D.create(global_position,
			global_position + pas, 1)
		q.exclude = _exclusions
		var hit := espace.intersect_ray(q)
		if hit.is_empty():
			global_position += pas
			break
		var avant := global_position.distance_to(hit["position"])
		restant -= restant * (avant / maxf(pas.length(), 0.001))
		global_position = (hit["position"] as Vector2) + (hit["normal"] as Vector2) * 2.0
		_velocite = FuseeModele.rebondir(_velocite, hit["normal"])
		_jouer_rebond()
	var vitesse := FuseeModele.vitesse_apres(_velocite.length(), delta)
	_velocite = _velocite.normalized() * vitesse if vitesse > 0.0 else Vector2.ZERO
	# L'élan restant porte la hauteur factice et l'orientation du corps.
	var elan := vitesse / FuseeModele.VITESSE_LANCER
	_coeur.position = Vector2(0.0, -HAUTEUR_VOL_PX * elan)
	if _corps:
		_corps.position = _coeur.position
		_corps.rotation = _velocite.angle() if vitesse > 0.0 else _corps.rotation
	if vitesse < FuseeModele.VITESSE_ARRET:
		_atterrir()


func _jouer_rebond() -> void:
	if is_replay:
		return
	var maintenant := Time.get_ticks_msec() / 1000.0
	if maintenant - _dernier_son_rebond < REBOND_SON_ESPACEMENT:
		return
	_dernier_son_rebond = maintenant
	AudioManager.play_sfx_2d_random_pitch("fusee_rebond", global_position)


## L'âge de combustion (négatif en vol) — lu par ReplaySystem pour l'instantané.
func age_combustion() -> float:
	return _age_combustion


## La killcam applique l'âge lu dans l'instantané (la position, elle, vient
## aussi de l'instantané : les rebonds ne se dérivent pas de l'âge).
func appliquer_age(age: float) -> void:
	_age_combustion = age
	_appliquer_age(age)


## Le banc saute d'acte en acte : la fusée se pose là où elle est et prend
## l'âge demandé. Sans effet en killcam (l'instantané fait foi).
func forcer_age(age: float) -> void:
	_atterrie = true
	_velocite = Vector2.ZERO
	_coeur.position = Vector2.ZERO
	appliquer_age(age)


## Ce que la fumée cache d'un corps posé à `pos`, dans [0, 1] : profond au cœur
## du nuage, rien au bord — le même gradient que le voile peint. player.gd
## l'applique à ses sprites : dans la fumée, on est vu (masse sombre) sans être
## LU (le sprite s'efface) — retour d'Adrien au premier essai, FU2.1.
func occultation_pour(pos: Vector2) -> float:
	if _alpha_fumee_courant <= 0.0:
		return 0.0
	var d := pos.distance_to(global_position) / maxf(_rayon_courant, 1.0)
	if d >= 1.0:
		return 0.0
	return _alpha_fumee_courant * (1.0 - smoothstep(0.55, 1.0, d))


## FU5 — cette fusée est-elle posée, allumée, et pas déjà en train de s'éteindre ?
## C'est la condition d'existence des DEUX moyens de l'éteindre : le piétinement
## (game_state.gd, host-only) et la balle (bullet.gd, tous pairs).
func est_allumee_au_sol() -> bool:
	return _atterrie and not _eteinte


## Ce que la fusée BRÛLE en ce moment, entre 0 et 1 — la part de son plein feu.
##
## ⚠️ **L'éblouissement doit la lire.** Adrien, le 2026-09-11 : « je suis
## ébloui par une fusée éclairante même quand elle est éteinte, quand elle
## clignote sur la fin notamment ». La source d'éblouissement de la fusée
## (`game_state._sources_eblouissantes`) ne regardait que « posée et pas
## éteinte » et lui donnait son rayon plein : une braise à 0,25 et un creux
## d'agonie à 0,15 aveuglaient comme le plein feu à 3,0. La lumière que voit
## le joueur est `_lumiere.energy` ; c'est elle qui fait l'éblouissement, à
## l'échelle du plein feu. Une lumière désactivée rend 0.
func energie_relative() -> float:
	if _lumiere == null or not _lumiere.enabled:
		return 0.0
	return clampf(_lumiere.energy / FuseeModele.ENERGIE_PLEIN_FEU, 0.0, 1.0)


## FU3 — un tir est parti DE L'INTÉRIEUR du nuage : toute la fumée pulse au
## lieu du seul canon, pour diluer la position du tireur. Appelé depuis
## `game_state._do_spawn_bullet`, une fois par volée, sur toute fusée dont
## `occultation_pour(muzzle_pos)` est positive — jamais en killcam (le site
## d'appel n'existe pas sur le chemin de rejeu).
func diffuser_flash() -> void:
	if not _atterrie or _eteinte:
		return
	_diffusion_debut = _age_combustion


## FU3 — une balle a creusé ce segment dans la fumée. `sombre` = l'arme
## n'émettait pas de lumière (l'arbalète) : la seule trace au monde qu'elle
## laisse. Appelé depuis `bullet.gd`, sur SON propre nœud de fusée local —
## jamais répliqué, jamais rejoué en killcam.
func ajouter_tunnel(entree: Vector2, sortie: Vector2, sombre: bool) -> void:
	if not _atterrie or _eteinte:
		return
	if entree.distance_to(sortie) < FuseeModele.TUNNEL_ENTREE_MIN:
		return # un tunnel trop court ne se lit pas, et un segment nul ferait planter distance_segment
	_tunnels.append({
		"entree": entree, "sortie": sortie, "sombre": sombre,
		"age_debut": _age_combustion,
	})
	if _tunnels.size() > TUNNELS_MAX:
		_tunnels.pop_front()


## FU5 — éteint la fusée : c'est un geste, pas une manche d'existence.
## Idempotent : appelé indépendamment par chaque machine sur son propre nœud
## local (piétinement via game_state, hôte seul ; balle via bullet.gd, tous
## pairs) — un second appel ne fait rien.
func eteindre() -> void:
	if _eteinte or not _atterrie:
		return
	_eteinte = true
	_age_extinction = 0.0
	_tunnels.clear()
	_sillage_points.clear()
	if not is_replay:
		AudioManager.play_sfx_2d_random_pitch("fusee_eteinte", global_position)


## FU5 — une fois éteinte, la fusée suit l'horloge de son propre panache, plus
## celle de la combustion : la lumière coupe net, seule reste une fumée NOIRE
## qui couvre la fuite de l'éteigneur puis se dissipe.
func _appliquer_extinction() -> void:
	_lumiere.enabled = false
	_coeur.modulate.a = 0.0
	if _corps:
		_corps.visible = false

	var alpha_panache := FuseeModele.alpha_panache_a(_age_extinction)
	var diametre := FuseeModele.RAYON_FUMEE * 2.0 \
		* FuseeModele.echelle_fumee_a(FuseeModele.duree_combustion())
	_alpha_fumee_courant = alpha_panache
	_rayon_courant = diametre * 0.5

	var actif := alpha_panache > 0.0
	_voile.visible = actif
	for i in _nappes.size():
		var nappe: Sprite2D = _nappes[i]
		nappe.visible = actif
	if not actif:
		return
	# Les nappes tournent encore — elles donnent sa forme au panache — mais
	# leur teinte plonge au noir : même mécanique que la fumée normale, une
	# seule variable change. L'âge continue de dériver depuis où il s'est
	# arrêté, pour que la rotation ne saute pas au moment de l'extinction.
	for i in _nappes.size():
		var nappe: Sprite2D = _nappes[i]
		var age_visuel := FuseeModele.duree_combustion() + _age_extinction
		nappe.rotation = float(FuseeModele.NAPPE_VITESSES[i]) * age_visuel * TAU
		nappe.scale = Vector2.ONE * _echelle_pour(nappe.texture, diametre) * (1.0 - 0.12 * i)
		nappe.modulate = Color(0.02, 0.02, 0.02,
			clampf(FuseeModele.NAPPE_ALPHA * alpha_panache * 1.3, 0.0, 1.0))
	_voile.scale = Vector2.ONE * _echelle_pour(_voile.texture, diametre)
	_voile_mat.set_shader_parameter("teinte", Color(0.02, 0.02, 0.02, 1.0))
	_voile_mat.set_shader_parameter("alpha_globale", alpha_panache)
	_voile_mat.set_shader_parameter("age", FuseeModele.duree_combustion() + _age_extinction)
	# Pas de sillage ni de tunnels dans le panache : il ne dure que quelques
	# secondes, et sa seule fonction est de couvrir — pas d'y lire un passage.
	if _tunnels_pousses:
		_voile_mat.set_shader_parameter("nb_tunnels", 0)
		_tunnels_pousses = false


func _appliquer_age(age_combustion: float) -> void:
	if _eteinte:
		# Défensif : `appliquer_age()`/`forcer_age()` sont publiques (killcam,
		# banc). Une fusée éteinte suit sa propre horloge, jamais celle-ci.
		_appliquer_extinction()
		return
	# --- La lumière : énergie et température dérivées de l'âge. ---
	var intensite: float = GameSettings.current_effect("fusee_agonie")
	var energie := FuseeModele.energie_a(age_combustion, _fenetres, intensite)
	var temperature := FuseeModele.temperature_a(age_combustion)
	# Rouge de détresse au départ, orange de braise ensuite — jamais de blanc :
	# c'est une fusée de marine, pas un projecteur (Adrien, FU2.1).
	var couleur := COULEUR_DETRESSE.lerp(Charte.AMBRE, temperature)
	_lumiere.energy = energie
	_lumiere.color = couleur
	_lumiere.enabled = energie > 0.005
	_coeur.modulate = Color(couleur.r, couleur.g, couleur.b,
		clampf(energie / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0))
	if not _atterrie:
		return # en vol : pas de fumée, la suite ne concerne que le sol

	if _coeur.position != Vector2.ZERO and _velocite == Vector2.ZERO:
		_coeur.position = Vector2.ZERO

	# --- La fumée : nappes tournantes + voile à trous. ---
	var alpha_fumee := FuseeModele.alpha_fumee_a(age_combustion)
	var echelle := FuseeModele.echelle_fumee_a(maxf(age_combustion, 0.0))
	var diametre := FuseeModele.RAYON_FUMEE * 2.0 * echelle
	_alpha_fumee_courant = alpha_fumee
	_rayon_courant = diametre * 0.5
	# Sans fumée (fusée éteinte), rien à peindre ni à pousser au shader.
	var fumee_active := alpha_fumee > 0.0

	# FU3 — le pouls de diffusion : un tir depuis l'intérieur du nuage fait
	# pulser TOUTE la fumée au lieu du seul canon, pour diluer la position du
	# tireur. `diffuser_flash()` pose `_diffusion_debut` ; ce n'est qu'un
	# BOOST d'opacité — jamais une teinte, la couleur reste celle des lumières.
	var intensite_diffusion: float = GameSettings.current_effect("fusee_diffusion")
	var diffusion := FuseeModele.diffusion_a(age_combustion - _diffusion_debut) \
		* intensite_diffusion
	var boost := 1.0 + diffusion * 1.6

	_voile.visible = fumee_active
	for i in _nappes.size():
		var nappe: Sprite2D = _nappes[i]
		nappe.visible = fumee_active
		if not fumee_active:
			continue
		# Rotation dérivée de l'âge (jamais d'un timer) : identique chez les
		# deux pairs et dans la killcam, avance rapide comprise.
		nappe.rotation = float(FuseeModele.NAPPE_VITESSES[i]) * maxf(age_combustion, 0.0) * TAU
		nappe.scale = Vector2.ONE * _echelle_pour(nappe.texture, diametre) * (1.0 - 0.12 * i)
		nappe.modulate.a = clampf(FuseeModele.NAPPE_ALPHA * alpha_fumee * boost, 0.0, 1.0)
	if fumee_active:
		_voile.scale = Vector2.ONE * _echelle_pour(_voile.texture, diametre)
		_voile_mat.set_shader_parameter("alpha_globale", clampf(alpha_fumee * 0.8 * boost, 0.0, 1.0))
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
		_maj_tunnels(age_combustion, diametre)


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


## FU3 — purge les tunnels expirés (leur enveloppe est retombée à zéro) et
## pousse les survivants au shader. Séparé de `_maj_sillage_et_masses` : ce
## sont deux familles différentes — le sillage EFFACE tant qu'un corps y est,
## un tunnel s'ÉTEINT tout seul en 0,4 s quoi qu'il arrive ; les mêler dans le
## même tampon aurait fait d'un tunnel un trou permanent.
func _maj_tunnels(age_combustion: float, diametre: float) -> void:
	var vivants: Array = []
	for tun in _tunnels:
		if FuseeModele.tunnel_force_a(age_combustion - float(tun["age_debut"])) > 0.0:
			vivants.append(tun)
	_tunnels = vivants

	if _tunnels.is_empty() and not _tunnels_pousses:
		return # cas courant : rien à pousser, et rien n'a jamais été poussé
	var entrees := PackedVector2Array()
	var sorties := PackedVector2Array()
	var forces := PackedFloat32Array()
	var sombres := PackedFloat32Array()
	for tun in _tunnels:
		var e: Vector2 = (tun["entree"] - global_position) / diametre + Vector2(0.5, 0.5)
		var s: Vector2 = (tun["sortie"] - global_position) / diametre + Vector2(0.5, 0.5)
		entrees.append(e)
		sorties.append(s)
		forces.append(FuseeModele.tunnel_force_a(age_combustion - float(tun["age_debut"])))
		sombres.append(1.0 if tun["sombre"] else 0.0)
	var nb := mini(entrees.size(), 6)
	while entrees.size() < 6:
		entrees.append(Vector2.ZERO)
		sorties.append(Vector2.ZERO)
		forces.append(0.0)
		sombres.append(0.0)
	_voile_mat.set_shader_parameter("nb_tunnels", nb)
	_voile_mat.set_shader_parameter("tunnels_entree", entrees)
	_voile_mat.set_shader_parameter("tunnels_sortie", sorties)
	_voile_mat.set_shader_parameter("tunnel_force", forces)
	_voile_mat.set_shader_parameter("tunnel_sombre", sombres)
	_voile_mat.set_shader_parameter("tunnel_largeur_uv", FuseeModele.TUNNEL_LARGEUR / diametre)
	_tunnels_pousses = nb > 0


func _atterrir() -> void:
	_atterrie = true
	_age_combustion = 0.0
	_velocite = Vector2.ZERO
	_coeur.position = Vector2.ZERO
	LightTextures.poser(_lumiere, LightTextures.RETRODIFFUSION, EMPREINTE_LUMIERE)
	if is_replay:
		return
	AudioManager.play_sfx_2d_random_pitch("fusee_atterrit", global_position)
	if _combustion and _combustion.stream:
		# Le bus (occlusion par les murs) se choisit une fois, à l'atterrissage —
		# c'est le contrat des one-shots du pool, assumé ici pour une boucle en
		# attendant l'étape audio (FU4) : la position de la fusée ne bouge plus,
		# seule l'oreille bouge encore.
		var part: float = AudioManager.part_occultee(global_position)
		_combustion.bus = AudioManager.bus_pour("SFX", part > 0.0)
		if part > 0.0:
			_combustion.volume_db += AudioManager.OCCLUSION_PENTE_DB * part
		_combustion.play()


func _exit_tree() -> void:
	if _combustion and _combustion.playing:
		_combustion.stop()
