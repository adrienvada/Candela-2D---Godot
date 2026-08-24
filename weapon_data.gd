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
## Nom du cookie cuit, sans chemin ni extension : `res://assets/torche/cookie_<x>.png`.
##
## Un champ explicite plutôt qu'un slug dérivé de `name` : « Arbalète » porte un
## accent, et un nom de fichier déduit d'un libellé d'interface se casse le jour
## où quelqu'un renomme l'arme à l'écran.
@export var torch_cookie: String = "pistolet"
## ⚠️ **DEMI-angle**, pas l'ouverture totale : la comparaison est
## `abs(dir.angle()) <= deg_to_rad(torch_angle_deg)`, donc 60° ouvre un cône de
## 120°. Cuit dans le cookie — le changer oblige à recuire.
@export var torch_angle_deg: float = 35.0
@export var torch_scale: float = 1.6
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

## Le cookie cuit, chargé une fois par arme. Voir `torch_cookie` plus haut.
var _torch_texture: Texture2D

## La texture du faisceau, chargée depuis `res://assets/torche/`.
##
## **Elle était fabriquée ici, pixel par pixel, au premier équipement** — 262 144
## itérations de GDScript pendant une manche, soit un hoquet posé exactement sur
## le moment où l'arme change. Même classe de défaut que le shader compilé au
## premier mort, déjà payée une fois. Elle est désormais cuite hors ligne par
## `tools/fabrique_cookies.gd` et versionnée.
##
## ⚠️ **Aucun bouche-trou en cas d'absence.** Un cookie manquant crie dans la
## console et rend `null` : la torche devient un carré lumineux, ce qui ne se
## confond avec rien. Fabriquer un dégradé de secours redonnerait un faisceau
## plausible, et un faisceau plausible se prend pour une intention — c'est la
## règle « câbler, taire, diagnostiquer » du dépôt, appliquée à un asset dont
## l'absence ne peut pas rester discrète.
func get_torch_texture() -> Texture2D:
	if _torch_texture != null:
		return _torch_texture
	var chemin := "res://assets/torche/cookie_%s.png" % torch_cookie
	if not ResourceLoader.exists(chemin):
		push_error("WeaponData : cookie de torche introuvable — %s" % chemin)
		return null
	_torch_texture = load(chemin)
	return _torch_texture


## Empreinte de référence d'un cookie, en texels. `torch_scale` s'exprime dans
## cette unité, jamais dans celle du fichier.
const TAILLE_COOKIE_REFERENCE := 512.0

## Le `texture_scale` à poser sur la `PointLight2D`.
##
## ⚠️ **La ligne la plus dangereuse du chantier DA2.1, et elle vit ICI pour
## qu'il n'y en ait qu'une.** `texture_scale` multiplie la taille PROPRE de la
## texture : le cookie historique faisait 512², les cookies cuits en font 1024.
## Posé tel quel, le même `torch_scale` couvre **deux fois plus d'unités de
## monde** — la torche porte deux fois plus loin, et aucune valeur de gameplay
## n'a bougé.
##
## Le défaut a été vu à l'œil par Adrien — « ça éclaire beaucoup trop loin » —
## pendant que les contrôles annonçaient une énergie conservée à 0,2 % près : ils
## mesuraient en coordonnées de texture, où tout allait bien. *Une mesure juste
## dans le mauvais repère rassure.* Voir « Pièges connus ».
##
## **Deux appelants, et le second est celui qui coûte cher** : `player.gd` pour
## la torche jouée, et `game_state.gd` pour les fantômes de killcam. Le second ne
## se voit qu'après une mort, qu'aucune suite n'exerce et que la planche de
## contact ne visite pas — laisser les deux calculer la même chose chacun de son
## côté, c'était garantir qu'un seul serait corrigé.
func echelle_torche() -> float:
	var tex := get_torch_texture()
	if tex == null or tex.get_width() <= 0:
		return torch_scale
	return torch_scale * TAILLE_COOKIE_REFERENCE / float(tex.get_width())
