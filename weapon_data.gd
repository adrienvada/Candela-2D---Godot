extends Resource
class_name WeaponData

const Charte := preload("res://charte.gd")
const Vision := preload("res://vision.gd")

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

## Le slug de l'arme — `pistolet`, `fusil`, `pompe`, `arbalete`.
##
## C'est `torch_cookie` et rien d'autre, exposé sous le nom de ce qu'il est
## vraiment. Le champ porte le nom de son PREMIER usage, pas de son sens ; il
## sert aussi à nommer les sons de tir (`assets/audio/weapons/`).
##
## Pourquoi pas un second champ `slug` : ce fichier a déjà payé la leçon plus
## bas — « une copie garantit que deux nombres divergent ». Deux slugs pour une
## arme, c'est le jour où le cookie dit `arbalete` et le son `arbalète`, sans
## que rien ne le signale : le son ne se charge pas, et un son absent ne lève
## aucune erreur.
func slug() -> String:
	return torch_cookie
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
##
## `Texture2D` et non `ImageTexture` : un PNG importé revient en
## `CompressedTexture2D`, jamais en `ImageTexture`. Le type plus étroit
## compilait tant que la texture était fabriquée en mémoire ; il aurait cassé au
## premier chargement.
var _torch_texture: Texture2D

## L'`Image` est gardée à part de la texture : `get_image()` rapatrie depuis le
## GPU à chaque appel, ce qui se paierait une fois par image et par joueur.
var _torch_image: Image

## Portée réelle du faisceau, en pixels — jusqu'où la torche pose encore de la
## lumière. Lue par l'éblouissement, qui doit s'arrêter là où le faisceau
## s'arrête.
##
## ⚠️ **Elle dérive de l'empreinte de RÉFÉRENCE, pas de la taille du fichier.**
## La branche « éblouissement » portait ici une constante `TAILLE_TEXTURE_TORCHE`
## à 512 décrite comme « le côté de la texture » : exacte quand la texture était
## fabriquée en 512², **fausse dès le premier cookie cuit en 1024²**. La valeur
## restait juste par accident — `echelle_torche()` compense justement pour que
## l'empreinte au sol reste `512 × torch_scale` — mais le nom et le commentaire
## mentaient, et c'est ainsi qu'on hérite d'un nombre que plus personne n'ose
## toucher. Une seule constante porte désormais cette unité.
func portee_torche() -> float:
	return TAILLE_COOKIE_REFERENCE * 0.5 * torch_scale

## Demi-angle du faisceau, en radians.
##
## `torch_angle_deg` est bien un **demi**-angle : le cookie allume les pixels
## dont l'écart à l'axe lui est inférieur. Le pompe (60) éclaire donc à 120° au
## total, l'arbalète (5) à 10°. La confusion coûte un facteur deux et ne se voit
## pas : elle a faussé l'éblouissement, puis le semis de poussière de V5.5, qui
## redivisait par deux. D'où ces deux fonctions — un seul endroit peut désormais
## se tromper sur ce que le nombre veut dire.
func demi_angle_torche() -> float:
	return deg_to_rad(torch_angle_deg)

## Le même, en cosinus, prêt pour un produit scalaire.
func cos_demi_cone() -> float:
	return cos(demi_angle_torche())

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


## L'image du faisceau, celle-là même que la lumière projette — pour que
## l'éblouissement la LISE au lieu d'en recopier la formule.
##
## **C'est la fin d'une famille entière de défauts.** `Vision` refaisait le
## calcul terme pour terme, avec ce commentaire : « recopié du rendu à dessein —
## deux formules pour un même faisceau finiraient par diverger ». Le risque était
## bien vu, le remède était le mauvais : une copie garantit que deux nombres
## restent égaux, jamais qu'ils veulent dire la même chose.
##
## L'image passe TOUJOURS par `get_torch_texture()`, jamais par une relecture du
## fichier : deux chemins vers la même vérité, c'est la faute que ce lot répare.
## `decompress()` n'est pas une précaution de style — une texture importée en
## VRAM revient compressée et `get_pixelv()` y échoue.
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


## Ce que ce faisceau verse sur un point du monde.
##
## ⚠️ **Elle existe parce que le même défaut s'est produit TROIS FOIS le
## 2026-08-24, dans trois fichiers différents.** `Vision.intensite_texture()`
## demande l'échelle à laquelle la texture est étalée ; chaque appelant devait
## donc la choisir, et chacun pouvait se tromper. Ils se sont trompés de la même
## façon — `torch_scale` au lieu de `echelle_torche()` — dans
## `game_state._lumiere_recue`, dans `tools/test_vision.gd` et dans
## `tools/planche_eblouissement.gd`.
##
## Les deux nombres ont été identiques pendant toute la vie du projet, tant que
## le cookie faisait 512². Depuis DA2.1 ils valent le simple et le double, et
## l'erreur fait **échantillonner le faisceau à mi-distance du point visé** :
## trop de pénalité au loin, de la pénalité là où le faisceau est éteint, et un
## jeu qui reste parfaitement jouable.
##
## **L'échelle est désormais choisie ici, une fois, à côté de la texture qu'elle
## décrit.** Un appelant ne peut plus se tromper parce qu'on ne lui demande plus
## rien. Proposée par la session « éblouissement », qui avait nommé la cause :
## la même question posée par deux chemins finit par recevoir deux réponses.
func lumiere_recue(avant: Vector2, depuis: Vector2, vers: Vector2) -> float:
	return Vision.intensite_texture(image_torche(), avant, depuis, vers, echelle_torche())


## Le même, dans l'axe du faisceau, à `distance` pixels de la source. C'est la
## mesure des bancs : « que verse cette arme droit devant, à 80 px ? »
func lumiere_axiale(distance: float) -> float:
	return lumiere_recue(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * distance)
