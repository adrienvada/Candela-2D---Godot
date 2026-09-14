## CapteurCorps — la lumière qu'un corps REÇOIT, lue dans la vue de celui qui le regarde
## (chantier ISO, étape ISO2).
##
## ## Pourquoi un capteur, et pas le sol sous les pieds
##
## Le halo de proximité révèle un ennemi collé à soi en n'éclairant QUE son sprite ; le
## sol sous ses pieds reste noir (constaté au banc ISO0.b). Un corps 3D qui lit la
## lightmap au sol disparaît donc là où la vue de dessus le montre. Le capteur rend au
## corps ce que son sprite recevait : une sous-vue de 256×256 partage le `World2D` du duel,
## ne dessine qu'un disque blanc posé sous le corps (couche de visibilité
## `Presentation3D.COUCHE_CAPTEUR`, qu'aucune lightmap ne lit), et ce disque porte le
## **masque de lumière du sprite qu'il remplace** — `CanauxLumiere.JOUEUR_LOCAL` (4) pour son
## propre corps, `CanauxLumiere.masque_vue_adverse(id)` pour le corps d'en face. Les lumières
## et les ombres du jeu font le reste, canal par canal, sans réécrire un shader `light()`.
##
## ## Équité
##
## Un capteur appartient à UNE vue (`vue_id`) et à UN corps (`corps_id`). Chez J1, le
## corps de J2 porte `2 | canal de la vue de J1` : le halo de J1 l'éclaire, celui de J2
## jamais — la règle du 2026-09-11, mot pour mot celle des sprites. Les masques sont donc
## **miroir** entre les deux vues (vérifié par `tools/test_iso_vues.gd`). Et le noir
## absolu tient par construction : le disque est en « lumière seule » — zéro sans lumière,
## sans dépendre du `CanvasModulate` de l'arène, qui ne l'éteignait pas (13 à 17/255 mesurés).
##
## ## Ce qu'il ne touche pas
##
## Rien du jeu : ni `visible`, ni les sprites, ni `player.gd`. Le disque est un nœud À
## LUI, positionné par `Presentation3D` à chaque image après l'interpolation des joueurs.
## Le capteur n'est jamais auditeur (`audio_listener_enable_2d` reste faux).
class_name CapteurCorps
extends SubViewport

## La taille du capteur, en texels — et le monde qu'il couvre, en pixels 2D : le disque
## d'un corps (rayon 18 px) tient au centre avec de la marge pour le filtrage.
const TAILLE := 256
const MONDE_PX := 128.0
## Le rayon du disque : celui d'un corps.
const RAYON_PX := 18.0

var vue_id := 0
var corps_id := 0
var _camera: Camera2D
var _disque: Polygon2D


static func creer(vue: int, corps: int, monde: World2D, couche: int, masque_lumiere: int) -> CapteurCorps:
	var c := CapteurCorps.new()
	c.name = "CapteurVue%dCorps%d" % [vue + 1, corps + 1]
	c.vue_id = vue
	c.corps_id = corps
	c.world_2d = monde
	c.size = Vector2i(TAILLE, TAILLE)
	c.canvas_cull_mask = couche
	c.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	c.transparent_bg = false
	c.audio_listener_enable_2d = false
	# Aucune 3D ici : le monde 3D du parent ne doit pas se rendre une troisième fois.
	c.disable_3d = true
	c.handle_input_locally = false
	c.gui_disable_input = true

	c._camera = Camera2D.new()
	c._camera.name = "Camera"
	c._camera.zoom = Vector2.ONE * (float(TAILLE) / MONDE_PX)
	c.add_child(c._camera)

	c._disque = Polygon2D.new()
	c._disque.name = "Disque"
	var pts := PackedVector2Array()
	for i in 32:
		var a := float(i) / 32.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * RAYON_PX)
	c._disque.polygon = pts
	c._disque.color = Color.WHITE
	c._disque.visibility_layer = couche
	c._disque.light_mask = masque_lumiere
	# ⚠️ **Lumière seule : le disque ne vaut que ce que les lumières lui apportent.** En mode
	# normal il valait 13 à 17/255 TOUTES LUMIÈRES ÉTEINTES (banc ISO2, contrôle du noir) :
	# le `CanvasModulate` noir de l'arène ne l'éteignait pas dans cette sous-vue, et chaque
	# corps sortait du noir. Un disque « lumière seule » est noir sans lumière par
	# construction, quel que soit l'état du modulateur. Un matériau de canevas, pas un
	# shader : rien à compiler au premier affichage.
	var matiere := CanvasItemMaterial.new()
	matiere.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
	c._disque.material = matiere
	c.add_child(c._disque)
	return c


func _ready() -> void:
	_camera.make_current()


## Pose le disque sous le corps, et la caméra dessus.
func suivre(position_corps: Vector2, visible_corps: bool) -> void:
	_disque.global_position = position_corps
	_disque.visible = visible_corps
	_camera.global_position = position_corps


func masque_lumiere() -> int:
	return _disque.light_mask


func couche() -> int:
	return _disque.visibility_layer
