class_name MenuParticlesAmbiance
extends Control

## Système de particules physiques d'ambiance 2D pour les illustrations de menu — Candela 2D.
##
## Superpose de discrètes volutes, poussières lumineuses et étincelles physiques
## (CPUParticles2D) adaptées à chaque illustration Brutalist Graphic Novel.
## Calé sur les Points d'Intérêt (POI) de MenuArtwork.

const MenuArtwork := preload("res://menu_artwork.gd")
const Charte := preload("res://charte.gd")

enum Profile {
	NONE,
	ATMOSPHERIC_DUST,
	CYAN_ELECTRIC,
	CYAN_NETWORK,
	CRT_PHOSPHOR,
	SPLIT_CLASH,
	TARGET_BRASS_DUST,
	WORKBENCH_AMBER,
	VAULT_GOLD_BURST,
	DYING_EMBERS,
	FLARE_CRIMSON,
	CONSOLE_AMBER_GREEN,
	RADIO_BEACON,
	AIRLOCK_EMERALD,
	ABYSS_GOLD,
}

const PROFILE_MAP: Dictionary = {
	"ill_accueil": Profile.ATMOSPHERIC_DUST,
	"ill_competitif": Profile.CYAN_ELECTRIC,
	"ill_amical": Profile.ATMOSPHERIC_DUST,
	"ill_amical_ligne": Profile.CYAN_NETWORK,
	"ill_amical_local": Profile.CRT_PHOSPHOR,
	"ill_ecran_scinde": Profile.SPLIT_CLASH,
	"ill_scinde": Profile.SPLIT_CLASH,
	"ill_entrainement": Profile.TARGET_BRASS_DUST,
	"ill_personnalisation": Profile.WORKBENCH_AMBER,
	"apercu_personnalisation": Profile.WORKBENCH_AMBER,
	"ill_mise_a_jour": Profile.VAULT_GOLD_BURST,
	"ill_maj": Profile.VAULT_GOLD_BURST,
	"ill_quitter": Profile.DYING_EMBERS,
	"ill_creer_ligne": Profile.FLARE_CRIMSON,
	"ill_creer": Profile.FLARE_CRIMSON,
	"ill_creer_local": Profile.CONSOLE_AMBER_GREEN,
	"ill_rejoindre_ligne": Profile.RADIO_BEACON,
	"ill_rejoindre": Profile.RADIO_BEACON,
	"ill_rejoindre_local": Profile.AIRLOCK_EMERALD,
	# DA6.6 — mêmes profils que les menus, pour la même raison que les effets.
	"ill_intro_descente": Profile.ATMOSPHERIC_DUST,
	"ill_intro_seuil": Profile.ABYSS_GOLD,
	"ill_intro_dotation": Profile.WORKBENCH_AMBER,
	"ill_intro_allumage": Profile.ATMOSPHERIC_DUST,
	"ill_intro_prix": Profile.ATMOSPHERIC_DUST,
	"ill_intro_extinction": Profile.DYING_EMBERS,
	"ill_retour": Profile.ABYSS_GOLD,
}

var _particles: CPUParticles2D
var _secondary_particles: CPUParticles2D
var _dot_texture: Texture2D
var _current_profile: Profile = Profile.NONE
var _current_artwork: String = ""
var _active_poi_uv: Vector2 = Vector2(0.5, 0.5)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dot_texture = _creer_texture_lueur_ronde()
	_creer_emetteurs()

func _ready() -> void:
	resized.connect(_sur_redimensionnement)

func _creer_texture_lueur_ronde() -> Texture2D:
	var grad_tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 16
	grad_tex.height = 16
	return grad_tex

func _creer_gradient_vie(alpha_max: float = 0.6) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, alpha_max),
		Color(1, 1, 1, alpha_max * 0.8),
		Color(1, 1, 1, 0.0)
	])
	return g

func _creer_emetteurs() -> void:
	_particles = CPUParticles2D.new()
	_particles.name = "ParticulesAmbiancePrincipales"
	_particles.texture = _dot_texture
	_particles.emitting = false
	_particles.one_shot = false
	_particles.preprocess = 1.5
	_particles.speed_scale = 1.0
	_particles.color_ramp = _creer_gradient_vie(0.6)
	add_child(_particles)

	_secondary_particles = CPUParticles2D.new()
	_secondary_particles.name = "ParticulesAmbianceSecondaires"
	_secondary_particles.texture = _dot_texture
	_secondary_particles.emitting = false
	_secondary_particles.one_shot = false
	_secondary_particles.preprocess = 1.0
	_secondary_particles.speed_scale = 1.0
	_secondary_particles.color_ramp = _creer_gradient_vie(0.4)
	add_child(_secondary_particles)

func definir_illustration(identifiant: String) -> void:
	var cle := MenuArtwork.cle_canonique(identifiant)
	_current_artwork = cle
	_active_poi_uv = MenuArtwork.poi_pour(cle)
	var profil: Profile = PROFILE_MAP.get(cle, Profile.ATMOSPHERIC_DUST)
	_appliquer_profil(profil)

func _sur_redimensionnement() -> void:
	if _current_profile != Profile.NONE:
		_repositionner_emetteurs()

func _repositionner_emetteurs() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var poi_pos := Vector2(size.x * _active_poi_uv.x, size.y * _active_poi_uv.y)
	_particles.position = poi_pos
	_secondary_particles.position = poi_pos

func _appliquer_profil(profil: Profile) -> void:
	_current_profile = profil
	_repositionner_emetteurs()

	_particles.emitting = false
	_secondary_particles.emitting = false

	if profil == Profile.NONE:
		return

	match profil:
		Profile.ATMOSPHERIC_DUST:
			# Poussières lentes en suspension dans le faisceau
			_particles.position = size * 0.5
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_particles.emission_rect_extents = size * 0.45
			_particles.amount = 18
			_particles.lifetime = 4.5
			_particles.gravity = Vector2(0.0, -4.0)
			_particles.direction = Vector2(-0.2, -1.0)
			_particles.spread = 45.0
			_particles.initial_velocity_min = 3.0
			_particles.initial_velocity_max = 8.0
			_particles.scale_amount_min = 0.25
			_particles.scale_amount_max = 0.55
			_particles.color = Color(0.98, 0.88, 0.65, 0.45)
			_particles.emitting = true

		Profile.VAULT_GOLD_BURST:
			# Particules d'or et micro-étincelles émergeant de la brèche VAULT 07
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_particles.emission_sphere_radius = 28.0
			_particles.amount = 26
			_particles.lifetime = 3.2
			_particles.gravity = Vector2(0.0, -12.0)
			_particles.direction = Vector2(-0.6, -0.8)
			_particles.spread = 60.0
			_particles.initial_velocity_min = 18.0
			_particles.initial_velocity_max = 42.0
			_particles.scale_amount_min = 0.30
			_particles.scale_amount_max = 0.75
			_particles.color = Color(1.0, 0.90, 0.42, 0.85)
			_particles.emitting = true

			# Volutes dorées plus lentes
			_secondary_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_secondary_particles.emission_sphere_radius = 45.0
			_secondary_particles.amount = 12
			_secondary_particles.lifetime = 4.0
			_secondary_particles.gravity = Vector2(0.0, -6.0)
			_secondary_particles.direction = Vector2(-0.3, -1.0)
			_secondary_particles.spread = 40.0
			_secondary_particles.initial_velocity_min = 6.0
			_secondary_particles.initial_velocity_max = 16.0
			_secondary_particles.scale_amount_min = 0.50
			_secondary_particles.scale_amount_max = 1.10
			_secondary_particles.color = Color(1.0, 0.80, 0.30, 0.35)
			_secondary_particles.emitting = true

		Profile.FLARE_CRIMSON:
			# Étincelles carmin et rougeoyantes s'élevant de la fusée au sol
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_particles.emission_sphere_radius = 16.0
			_particles.amount = 22
			_particles.lifetime = 2.8
			_particles.gravity = Vector2(0.0, -18.0)
			_particles.direction = Vector2(0.2, -1.0)
			_particles.spread = 35.0
			_particles.initial_velocity_min = 20.0
			_particles.initial_velocity_max = 50.0
			_particles.scale_amount_min = 0.25
			_particles.scale_amount_max = 0.65
			_particles.color = Color(1.0, 0.32, 0.18, 0.80)
			_particles.emitting = true

			# Fumée rougeoyante
			_secondary_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_secondary_particles.emission_sphere_radius = 30.0
			_secondary_particles.amount = 10
			_secondary_particles.lifetime = 3.6
			_secondary_particles.gravity = Vector2(5.0, -8.0)
			_secondary_particles.direction = Vector2(0.4, -1.0)
			_secondary_particles.spread = 45.0
			_secondary_particles.initial_velocity_min = 8.0
			_secondary_particles.initial_velocity_max = 20.0
			_secondary_particles.scale_amount_min = 0.60
			_secondary_particles.scale_amount_max = 1.20
			_secondary_particles.color = Color(0.90, 0.20, 0.15, 0.30)
			_secondary_particles.emitting = true

		Profile.CYAN_ELECTRIC, Profile.CYAN_NETWORK:
			# Micro-impulsions et poussière électrique cyan
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_particles.emission_rect_extents = Vector2(40.0, 50.0)
			_particles.amount = 14
			_particles.lifetime = 2.5
			_particles.gravity = Vector2(0.0, -2.0)
			_particles.direction = Vector2(0.0, -1.0)
			_particles.spread = 90.0
			_particles.initial_velocity_min = 4.0
			_particles.initial_velocity_max = 14.0
			_particles.scale_amount_min = 0.20
			_particles.scale_amount_max = 0.45
			_particles.color = Color(0.25, 0.85, 1.0, 0.65)
			_particles.emitting = true

		Profile.CRT_PHOSPHOR, Profile.CONSOLE_AMBER_GREEN:
			# Balayage et micro-motes cathodiques vert phosphore
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_particles.emission_rect_extents = Vector2(55.0, 40.0)
			_particles.amount = 12
			_particles.lifetime = 2.8
			_particles.gravity = Vector2(0.0, -3.0)
			_particles.direction = Vector2(0.0, -1.0)
			_particles.spread = 60.0
			_particles.initial_velocity_min = 2.0
			_particles.initial_velocity_max = 10.0
			_particles.scale_amount_min = 0.20
			_particles.scale_amount_max = 0.45
			_particles.color = Color(0.35, 1.0, 0.45, 0.50) if profil == Profile.CRT_PHOSPHOR else Color(0.85, 0.95, 0.30, 0.50)
			_particles.emitting = true

		Profile.RADIO_BEACON:
			# Ondes de balise et poussière lumineuse bleue
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_particles.emission_sphere_radius = 25.0
			_particles.amount = 16
			_particles.lifetime = 3.0
			_particles.gravity = Vector2(0.0, -5.0)
			_particles.direction = Vector2(0.0, -1.0)
			_particles.spread = 120.0
			_particles.initial_velocity_min = 6.0
			_particles.initial_velocity_max = 20.0
			_particles.scale_amount_min = 0.25
			_particles.scale_amount_max = 0.55
			_particles.color = Color(0.20, 0.75, 1.0, 0.70)
			_particles.emitting = true

		Profile.AIRLOCK_EMERALD:
			# Voyant vert émeraude au-dessus du sas
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_particles.emission_sphere_radius = 20.0
			_particles.amount = 12
			_particles.lifetime = 3.2
			_particles.gravity = Vector2(0.0, 2.0)
			_particles.direction = Vector2(0.0, 1.0)
			_particles.spread = 45.0
			_particles.initial_velocity_min = 4.0
			_particles.initial_velocity_max = 12.0
			_particles.scale_amount_min = 0.25
			_particles.scale_amount_max = 0.50
			_particles.color = Color(0.25, 1.0, 0.50, 0.55)
			_particles.emitting = true

		Profile.DYING_EMBERS:
			# Braises mourantes et poussière rougeoyante de la torche tombée
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_particles.emission_sphere_radius = 22.0
			_particles.amount = 10
			_particles.lifetime = 2.4
			_particles.gravity = Vector2(0.0, -6.0)
			_particles.direction = Vector2(0.3, -1.0)
			_particles.spread = 45.0
			_particles.initial_velocity_min = 8.0
			_particles.initial_velocity_max = 24.0
			_particles.scale_amount_min = 0.20
			_particles.scale_amount_max = 0.50
			_particles.color = Color(0.95, 0.60, 0.22, 0.60)
			_particles.emitting = true

		Profile.TARGET_BRASS_DUST, Profile.WORKBENCH_AMBER, Profile.ABYSS_GOLD, Profile.SPLIT_CLASH:
			# Ambiance chaude dorée / ambrée localisée autour du POI
			_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_particles.emission_sphere_radius = 50.0
			_particles.amount = 16
			_particles.lifetime = 3.5
			_particles.gravity = Vector2(0.0, -5.0)
			_particles.direction = Vector2(0.0, -1.0)
			_particles.spread = 60.0
			_particles.initial_velocity_min = 4.0
			_particles.initial_velocity_max = 14.0
			_particles.scale_amount_min = 0.25
			_particles.scale_amount_max = 0.60
			_particles.color = Color(0.98, 0.82, 0.40, 0.55)
			_particles.emitting = true

func masquer_doux() -> void:
	_particles.emitting = false
	_secondary_particles.emitting = false
	_current_profile = Profile.NONE
	_current_artwork = ""
