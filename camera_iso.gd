## CameraIso — la caméra orthographique de la vue isométrique (ISO1).
##
## **Décisions d'Adrien (H15, 2026-09-14)** : tangage 52°, lacet 0°, et la caméra
## **garde la profondeur** de la vue de dessus — `size = 1080 × sin θ`. Au sol, elle
## montre donc 1080 px de monde en profondeur, comme la vue de dessus, mais seulement
## `1920 × sin θ` en largeur (1513 px à 52°) : l'iso voit MOINS large, jamais plus.
##
## Elle suit la caméra 2D du joueur regardé en lisant la transformation de canevas de
## sa vue — celle qui a rendu la lightmap —, secousse et zoom compris : un zoom de
## killcam réduit d'autant ce qu'elle montre. **Elle ne montre jamais plus de carte que
## la caméra 2D** (vérifié par `tools/test_iso_camera.gd`, lacet nul) ; et ce qu'un mur
## ferait dépasser au bord de l'image lit la lightmap hors de son rectangle, donc du noir.
##
## ⚠️ Un lacet non nul fait tourner l'empreinte au sol hors du rectangle de la vue 2D :
## la garantie ci-dessus ne vaut qu'à 0°, la valeur actée.
class_name CameraIso
extends Camera3D

const TANGAGE_DEG := 52.0
const LACET_DEG := 0.0
## La hauteur logique d'une vue 2D : l'aire est 1920×1080 (`stretch = keep`).
const HAUTEUR_VUE := 1080.0
## Recul le long de l'axe de visée. En orthographique il ne change pas l'image ; il
## laisse seulement la scène entre `near` et `far`.
const RECUL := 5000.0

var tangage_deg := TANGAGE_DEG
var lacet_deg := LACET_DEG


func _init() -> void:
	name = "CameraIso"
	projection = Camera3D.PROJECTION_ORTHOGONAL
	# `size` est une HAUTEUR de vue : c'est la profondeur qu'on garde.
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = 1.0
	far = RECUL * 3.0


## Pose la caméra sur la vue 2D : `canevas` est la `canvas_transform` de la sous-vue
## qui rend la lightmap, `taille_2d` son aire 2D.
func suivre(canevas: Transform2D, taille_2d: Vector2) -> void:
	transform = transform_pour(canevas, taille_2d, tangage_deg, lacet_deg)
	size = taille_orthographique(tangage_deg, hauteur_monde(canevas, taille_2d))


# ---------------------------------------------------------------------------
# LES FORMULES — statiques, vérifiées sans fenêtre
# ---------------------------------------------------------------------------

## `Camera3D.size` qui garde, au sol, la profondeur d'une vue de dessus de
## `hauteur_vue` pixels : le sol se voit raccourci de sin θ.
static func taille_orthographique(tangage: float, hauteur_vue: float = HAUTEUR_VUE) -> float:
	return hauteur_vue * sin(deg_to_rad(tangage))


## Le monde visible au sol, lacet nul : la profondeur est gardée, la largeur non.
static func empreinte_au_sol(tangage: float, vue: Vector2) -> Vector2:
	var taille := taille_orthographique(tangage, vue.y)
	return Vector2(taille * vue.x / vue.y, taille / sin(deg_to_rad(tangage)))


## Combien de pixels de MONDE la vue 2D montre en hauteur : zoom compris.
static func hauteur_monde(canevas: Transform2D, taille_2d: Vector2) -> float:
	var echelle := canevas.y.length()
	return taille_2d.y / echelle if echelle > 0.0 else taille_2d.y


## Le point du monde au centre de la vue 2D.
static func centre_de_vue(canevas: Transform2D, taille_2d: Vector2) -> Vector2:
	return canevas.affine_inverse() * (taille_2d * 0.5)


## Ordre d'Euler YXZ : on incline (X), puis on tourne autour de la verticale (Y).
## Pas de `look_at`, qui perd son « haut » à 90°.
static func transform_pour(canevas: Transform2D, taille_2d: Vector2, tangage: float,
		lacet: float) -> Transform3D:
	var base := Basis.from_euler(Vector3(deg_to_rad(-tangage), deg_to_rad(lacet), 0.0),
		EULER_ORDER_YXZ)
	var centre := centre_de_vue(canevas, taille_2d)
	return Transform3D(base, Vector3(centre.x, 0.0, centre.y) + base.z * RECUL)


## Les quatre coins de l'image ramenés au sol (`y = 0`), en pixels du monde 2D :
## haut-gauche, haut-droit, bas-gauche, bas-droit.
static func coins_au_sol(t: Transform3D, taille: float, aspect: float) -> Array[Vector2]:
	var coins: Array[Vector2] = []
	var demi_h := taille * 0.5
	var demi_l := demi_h * aspect
	var direction := -t.basis.z
	for s: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var o := t.origin + t.basis.x * demi_l * s.x + t.basis.y * demi_h * s.y
		var k := -o.y / direction.y
		coins.append(Vector2(o.x + direction.x * k, o.z + direction.z * k))
	return coins


## Le rectangle de monde (boîte englobante) que couvre une vue 2D.
static func rect_couvert(canevas: Transform2D, taille_2d: Vector2) -> Rect2:
	var inverse := canevas.affine_inverse()
	var r := Rect2(inverse * Vector2.ZERO, Vector2.ZERO)
	for coin in [Vector2(taille_2d.x, 0.0), Vector2(0.0, taille_2d.y), taille_2d]:
		r = r.expand(inverse * coin)
	return r


## Point du monde → uv de la lightmap. **La même formule que `lire_lightmap()` dans
## `iso_lightmap.gdshaderinc`** : colonnes x, y et origine de la transformation,
## divisées par la taille 2D.
static func uv_de(canevas: Transform2D, taille_2d: Vector2, point: Vector2) -> Vector2:
	return (canevas.x * point.x + canevas.y * point.y + canevas.origin) / taille_2d
