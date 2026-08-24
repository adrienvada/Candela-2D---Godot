extends Resource
class_name WeaponData

const Charte := preload("res://charte.gd")

@export var name: String = "Pistolet"
@export var cooldown: float = 1.0
@export var bullet_speed: float = 12000.0
@export var bullet_max_distance: float = 10000.0
@export var damage_center: float = 50.0
@export var damage_edge: float = 25.0
@export var max_bounces: int = 0
@export var damages_shooter: bool = false
@export var projectile_count: int = 1
@export var spread_angles_deg: Array[float] = [0.0]
@export var emits_light: bool = true

@export_group("Flashlight")
@export var torch_angle_deg: float = 30.0
@export var torch_scale: float = 2.3
@export var torch_brightness: float = 1.0

@export_group("Visibility & Mobility")
@export var muzzle_flash_intensity: float = 1.0
@export var muzzle_flash_duration: float = 0.1
@export var backlight_multiplier: float = 1.0
@export var movement_speed_while_reloading: float = 1.0
@export var can_run_while_reloading: bool = true

@export_group("Projectile Visuals")
@export var bullet_color: Color = Charte.AMBRE_INCANDESCENT
@export var bullet_light_energy: float = 50.0
@export var bullet_width: float = 5.0

## Côté de la texture de torche, en pixels. La lumière l'étale ensuite par
## `torch_scale` (`player.gd`), d'où la portée réelle ci-dessous.
const TAILLE_TEXTURE_TORCHE := 512

## Portée réelle du faisceau, en pixels — jusqu'où la torche pose encore de la
## lumière. Dérivée de la texture plutôt que recopiée : le jour où sa taille
## change, un seul endroit peut mentir. Lue par l'éblouissement, qui doit
## s'arrêter là où le faisceau s'arrête.
func portee_torche() -> float:
	return TAILLE_TEXTURE_TORCHE * 0.5 * torch_scale

## Demi-angle du faisceau, en radians.
##
## `torch_angle_deg` est bien un **demi**-angle : `get_torch_texture` allume les
## pixels dont l'écart à l'axe lui est inférieur. Le pompe (60) éclaire donc à
## 120° au total, l'arbalète (5) à 10°. La confusion coûte un facteur deux et ne
## se voit pas : elle a faussé l'éblouissement, puis le semis de poussière de
## V5.5, qui redivisait par deux. D'où ces deux fonctions — un seul endroit peut
## désormais se tromper sur ce que le nombre veut dire.
func demi_angle_torche() -> float:
	return deg_to_rad(torch_angle_deg)

## Le même, en cosinus, prêt pour un produit scalaire.
func cos_demi_cone() -> float:
	return cos(demi_angle_torche())

var _torch_texture: ImageTexture

## L'image du faisceau, celle-là même que la lumière projette — pour que
## l'éblouissement la LISE au lieu d'en recopier la formule.
##
## **C'est la fin d'une famille entière de défauts.** `Vision` refaisait le
## calcul de `get_torch_texture()` terme pour terme, avec ce commentaire :
## « recopié du rendu à dessein — deux formules pour un même faisceau finiraient
## par diverger ». Le risque était bien vu, le remède était le mauvais : une
## copie garantit que deux nombres restent égaux, jamais qu'ils veulent dire la
## même chose. Trois divergences en sont sorties, mesurées le 2026-08-24 —
## `torch_brightness` que le modèle ignorait (l'arbalète éblouissait comme le
## pistolet avec un faisceau trois fois plus sombre), le cône écrit en dur, et
## le profil peint des cookies qui tombe à la moitié dans les flancs.
##
## Un pixel ne peut pas diverger de lui-même. Et il porte **tout** : l'angle de
## son arme, sa portée, sa luminosité, et demain la matière peinte du cookie.
##
## L'`Image` est gardée à part de la texture : `ImageTexture.get_image()`
## rapatrie depuis le GPU à chaque appel, ce qui se paierait une fois par image
## et par joueur.
var _torch_image: Image

## L'image passe TOUJOURS par `get_torch_texture()`, jamais par une relecture du
## fichier : deux chemins vers la même vérité, c'est la faute que ce lot répare.
##
## **Et elle sait se passer de la fabrique procédurale.** La session « assets
## visuels » remplace celle-ci par le chargement d'un cookie peint ; le jour où
## `_torch_image` cessera d'être posé en chemin, se contenter de le rendre
## donnerait `null` — et l'éblouissement retomberait **en silence** sur la
## formule analytique, c'est-à-dire sur le défaut qu'on vient de retirer. Le
## repli par la texture rend la lecture indifférente à la provenance de l'image.
##
## `decompress()` n'est pas une précaution de style : une texture importée en
## VRAM revient compressée, et `get_pixelv()` y échoue. Le contrôle d'usage
## `is_compressed()` évite d'y toucher quand elle ne l'est pas.
func image_torche() -> Image:
	if _torch_image != null:
		return _torch_image
	var tex := get_torch_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img != null and img.is_compressed():
		if img.decompress() != OK:
			return null
	_torch_image = img
	return _torch_image

func get_torch_texture() -> ImageTexture:
	if _torch_texture != null:
		return _torch_texture
		
	var tex_size = 512
	var img = Image.create_empty(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center = Vector2(tex_size / 2.0, tex_size / 2.0)
	var max_dist = tex_size / 2.0
	var cone_angle = deg_to_rad(torch_angle_deg)
	
	for y in range(tex_size):
		for x in range(tex_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist >= max_dist:
				continue
				
			var dir = center.direction_to(pos)
			var angle = abs(dir.angle())
			var intensity = 0.0
			
			if angle <= cone_angle:
				var beam_intensity = 1.0 - (dist / max_dist)
				var angle_fade = clamp((cone_angle - angle) * 8.0, 0.0, 1.0)
				intensity = max(intensity, beam_intensity * angle_fade)
				
			var halo_angle = deg_to_rad(80.0)
			if angle <= halo_angle:
				var halo_dist = max_dist * 0.2
				if dist < halo_dist:
					var halo_intensity = pow(1.0 - (dist / halo_dist), 2.5) * 0.15
					var angle_fade = clamp((halo_angle - angle) * 4.0, 0.0, 1.0)
					intensity = max(intensity, halo_intensity * angle_fade)
				
			if intensity > 0:
				img.set_pixel(x, y, Color(Charte.HALOGENE, intensity * torch_brightness))
	
	_torch_image = img
	_torch_texture = ImageTexture.create_from_image(img)
	return _torch_texture

var _torch_texture_flat: ImageTexture

func get_torch_texture_flat() -> ImageTexture:
	if _torch_texture_flat != null:
		return _torch_texture_flat
		
	var tex_size = 512
	var img = Image.create_empty(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center = Vector2(tex_size / 2.0, tex_size / 2.0)
	var max_dist = tex_size / 2.0
	var cone_angle = deg_to_rad(torch_angle_deg)
	
	for y in range(tex_size):
		for x in range(tex_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist >= max_dist:
				continue
				
			var dir = center.direction_to(pos)
			var angle = abs(dir.angle())
			var intensity = 0.0
			
			if angle <= cone_angle:
				# Solid light, but with a slight diffuse edge to prevent harsh pixelated steps
				var angle_fade = clamp((cone_angle - angle) * 16.0, 0.0, 1.0)
				var dist_fade = clamp((max_dist - dist) / 25.0, 0.0, 1.0)
				intensity = angle_fade * dist_fade
				
			var halo_angle = deg_to_rad(80.0)
			if angle <= halo_angle:
				var halo_dist = max_dist * 0.2
				if dist < halo_dist:
					var halo_angle_fade = clamp((halo_angle - angle) * 8.0, 0.0, 1.0)
					var halo_dist_fade = clamp((halo_dist - dist) / 15.0, 0.0, 1.0)
					intensity = max(intensity, halo_angle_fade * halo_dist_fade)
				
			if intensity > 0:
				img.set_pixel(x, y, Color(Charte.HALOGENE, intensity * torch_brightness))
	
	_torch_texture_flat = ImageTexture.create_from_image(img)
	return _torch_texture_flat
