## CapteurCorps — la lumière qu'un corps REÇOIT, lue dans la vue de celui qui le regarde
## (chantier ISO, étape ISO2).
##
## ## Pourquoi un capteur, et pas le sol sous les pieds
##
## Le halo de proximité révèle un ennemi collé à soi en n'éclairant QUE son sprite ; le
## sol sous ses pieds reste noir (constaté au banc ISO0.b). Un corps 3D qui lit la
## lightmap au sol disparaît donc là où la vue de dessus le montre. Le capteur rend au
## corps ce que son sprite recevait : une sous-vue de 256×256 partage le `World2D` du duel,
## ne dessine qu'un disque blanc posé sous le corps (sur une couche de visibilité À LUI,
## `Presentation3D.couche_capteur()`, qu'aucune lightmap ne lit), et ce disque porte le
## **masque de lumière du sprite qu'il remplace** — `CanauxLumiere.JOUEUR_LOCAL` (4) pour son
## propre corps, `CanauxLumiere.masque_vue_adverse(id)` pour le corps d'en face. Les lumières
## et les ombres du jeu font le reste, canal par canal. Il les reçoit par la **courbe du sprite
## qu'il remplace** — `capteur_adverse.gdshader` et `capteur_local.gdshader`, miroirs des shaders
## des sprites : le corps 3D suit la lampe comme la vue de dessus.
##
## ⚠️ **Sa couche est à lui seul.** Deux capteurs sont posés sous chaque corps, un par vue, dans
## le même monde 2D. Sur une couche commune, chacun dessinait aussi le disque de l'autre et
## recevait les canaux des deux vues : en écran scindé, J2 s'allumait chez J1 sous les lumières
## que seul J2 voit (jalon H-ISO2, 2026-09-14 ; six cas faux sur huit à `banc_iso.gd --canaux`).
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
## Les shaders des disques, préchargés : rien à compiler au premier affichage.
const SHADER_ADVERSE := preload("res://capteur_adverse.gdshader")
const SHADER_LOCAL := preload("res://capteur_local.gdshader")

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
	# ⚠️ **Lumière seule, par la courbe du sprite remplacé.** Lumière seule (`render_mode
	# light_only` des deux shaders) : en mode normal le disque valait 13 à 17/255 TOUTES
	# LUMIÈRES ÉTEINTES (banc ISO2, contrôle du noir), le `CanvasModulate` noir de l'arène ne
	# l'éteignant pas dans cette sous-vue. La courbe : le sprite ennemi ne prend pas la lumière
	# par défaut du moteur (× énergie, ×4 puis plafond) ; un disque qui la prenait donnait au
	# corps une autre lumière que celle de la vue de dessus.
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER_LOCAL if vue == corps else SHADER_ADVERSE
	c._disque.material = materiau
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


func matiere() -> Material:
	return _disque.material
