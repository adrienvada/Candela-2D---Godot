## Presentation3D — la vue isométrique du duel (chantier ISO, étapes ISO1 et ISO2).
##
## ## Ce qu'elle est
##
## **B-projection** (`docs/ETUDE_ISO.md`, § 3.2). Les sous-vues 2D du jeu continuent de
## rendre TOUT le duel — sol, murs, encre, LED, décals, lumières, ombres, masques
## d'équité — et deviennent des « lightmaps », **une par joueur** ; ce nœud les projette
## sur un sol 3D, extrude les murs (`IsoGeometrie`), pose deux corps grossiers et une
## `CameraIso` par vue regardée. **Aucune `Light3D`** : la seule vérité d'ombre reste
## celle qui décide du jeu. Ce que l'écran montre est, au pixel près, ce que l'hôte fait
## payer.
##
## ## Les vues et les canaux (ISO2)
##
## - **Vue unique** (entraînement, en ligne) : la racine dessine la 3D avec la caméra
##   `CameraIso` de ce nœud, qui ne voit que le sol du joueur regardé.
## - **Écran scindé** : deux `SubViewport` 3D (`VueIso1`, `VueIso2`) partagent le
##   `World3D` de la racine — murs et corps n'existent qu'une fois, sur le calque commun ;
##   chaque vue a son sol (`Sol1` sur le calque 2, `Sol2` sur le 4) et sa caméra, dont le
##   `cull_mask` choisit le sol ET, dans les shaders, la lightmap à lire
##   (`CAMERA_VISIBLE_LAYERS`, voir `iso_lightmap.gdshaderinc`). Chaque vue s'affiche par
##   un `TextureRect` posé sur le cadre de son conteneur 2D, à la résolution de la fenêtre.
## - **Les lightmaps gardent leurs masques réels** (`~4` / `~2`, posés par
##   `game_state.gd`), moins les couches des capteurs. Ce que chaque lightmap contient est
##   exactement ce que son joueur a le droit de voir : ses lumières, pas celles de l'autre.
##   C'est la règle d'équité du jeu, et le jalon H-ISO2 : « je ne vois pas sa torche, il
##   ne voit pas mon halo ».
## - **Les capteurs de corps** (`CapteurCorps`) : par vue regardée et par corps, une
##   sous-vue de 256² lit la lumière que ce corps REÇOIT dans cette vue, avec le masque de
##   lumière du sprite qu'il remplace. Sans eux, un ennemi révélé par le seul halo de
##   proximité restait noir (le sol sous ses pieds l'est) — constat du banc ISO0.b.
## - **Les effets d'écran suivent la vue** : `GameState` demande à ce nœud où loger les
##   calques (vignette, flash de mort) et l'appareil de brouillage d'un joueur
##   (`parent_ecran`) ; le brouillage projette alors le monde par la caméra 3D
##   (`projecteur_ecran`) ; `ui.gd` prend l'angle du voile par `angle_ecran`, et ne pose le
##   voile de J2 que si les deux vues sont affichées.
## - **Pas sous les menus** : le retour au menu remontre les deux vues ; la vue iso ne
##   s'allume que hors du menu principal.
##
## ## Aller-retour
##
## Vue unique ↔ scindé ↔ 2D, en cours de partie (la killcam cache une vue) comme entre
## deux manches : à chaque changement de l'ensemble des vues regardées, tout est ÉTEINT
## puis rallumé dans la même image. L'extinction rend à l'identique conteneurs, tailles
## de sous-vues, masques, fond, rendu racine, couches des sprites, calques et brouillage.
## Prouvé par `tools/test_iso_vues.gd`.
##
## ## Où elle vit, et pourquoi
##
## Enfant de la RACINE de l'arbre (`/root/Presentation3D`), sœur de `Main` — **jamais
## sous `Player*` ni sous `GameState`**. Un nœud ajouté sous un porteur de RPC peut
## dérouter les RPC sans la moindre erreur console (« Pièges connus »). Ici, aucun
## chemin du duel ne change.
##
## ## Quand elle s'allume
##
## `GameSettings.mode_iso` — vrai par défaut depuis ISO6, faux sous le drapeau de débogage
## `--2d` ou le réglage « Vue de dessus (débogage) » — et au moins une vue regardée. Le jeu ne l'appelle qu'à UN endroit : la fin de
## `GameState.rebuild_arena()`. Tout le reste — allumer, tenir, éteindre, reconstruire les
## murs — elle le fait elle-même, à chaque image : le jeu redéfait ses gestes (accords de
## rendu, couches de sprites) et elle les repose en les comptant, comme le banc ISO0.b.
##
## ## Ce qu'elle écrit, et rien d'autre
##
## De la présentation seulement : l'alpha, le filtre souris, `top_level` et `stretch` des
## conteneurs regardés, la taille et l'aire 2D de leurs sous-vues (la lightmap `plein` ou
## `1080p`), la couche des
## capteurs retirée des masques de cull, le `Background`, `GameState.rendu_racine_autorise`
## (le chemin `SubViewport` forcé, sans quoi la texture de la vue n'existe pas), et la
## couche de visibilité des dix sprites de corps — **jamais `visible`**, que le rejeu lit.
## ISO5 y ajoute la couche du sprite des fantômes de killcam (`VisualColored`) et celle du voile de
## killcam (`UI.killcam_overlay`), relu sur la vue iso par un calque à soi.
## Positions, rotations et `visual.visible` sont LUS. Tout est rendu à l'extinction.
##
## ⚠️ **Pour ISO3 — les hauteurs de simulation ne sont pas des hauteurs de rendu.** Le
## chantier des murs bas pose dans `map_geometry.gd` `HAUTEUR_MUR_HAUT` (1,25),
## `HAUTEUR_MUR_BAS` (0,40), `HAUTEUR_ACCROUPI` (0,10) et `HAUTEUR_DEBOUT` (1,00), en
## tuiles : elles disent ce qu'une balle et une lumière franchissent. Le rendu iso a les
## siennes — `IsoGeometrie.H_HAUT` pour les murs hauts (0,65 tuile recommandée : un mur
## d'1,25 tuile cacherait 34 px de sol derrière lui à 52°, deux fois le rayon d'un
## corps) ; et un corps accroupi de 0,10 tuile extrudé tel quel ferait 3,5 px. La hauteur
## de voxel d'un corps n'est pas sa hauteur de jeu : ISO3 dessine un corps lisible, qui se
## lit accroupi à sa silhouette. Aucune de ces constantes n'est posée ici.
class_name Presentation3D
extends Node3D

const IsoPate := preload("res://iso_pate.gd")
## ISO7 — le sol habillé : `sol_projete.gdshader` (ISO1) plus la matière du sol, force 0 sans beauté.
const SHADER_SOL := preload("res://sol_iso.gdshader")
const SHADER_MUR := preload("res://mur_iso.gdshader")
const SHADER_CORPS := preload("res://corps_grossier_iso.gdshader")
## ISO2b — la passe de profondeur des corps, avant leur couleur (voir le shader).
const SHADER_CORPS_PROFONDEUR := preload("res://corps_profondeur_iso.gdshader")

const NOM := "Presentation3D"

## La couche de visibilité où partent les sprites de corps : AUCUNE.
##
## ⚠️ **`main.tscn` déclare 3 et 5, et c'est faux dès la première image** : le jeu
## réécrit les masques en `~4` (vue de J1) et `~2` (vue de J2) dans `_setup_players()`.
## Aucun bit non nul n'échappe aux deux vues ; zéro ne partage rien avec aucun masque,
## racine comprise. Vérifié sur les masques vivants par `tools/test_iso_geometrie.gd`.
const COUCHE_HORS_VUE := 0
## La première couche de visibilité 2D des disques de capteur (bit 4 des vingt couches) : les
## quatre capteurs en prennent chacun une, de 8 à 64 (`couche_capteur`), qu'aucun `CanvasItem`
## du jeu ne porte — le jeu n'utilise que 1, 2 et 4. **Retirées des masques des lightmaps
## pendant que la vue est allumée** : sans quoi `~4` et `~2`, qui lisent tout sauf une couche,
## dessineraient un disque blanc sous chaque corps dans le sol.
##
## ⚠️ **Une couche PAR capteur, jamais une commune** (retour d'Adrien au jalon H-ISO2,
## 2026-09-14). Les quatre disques vivent dans le même monde 2D, et deux sont posés sous chaque
## corps — celui de la vue de J1 et celui de la vue de J2. Sur une couche commune, chaque
## capteur dessinait les deux et recevait ses canaux ET ceux de l'autre vue : en écran scindé,
## J2 s'allumait chez J1 sous les lumières que seul J2 a le droit de voir (étincelles, impact),
## et le corps de J1 restait noir sous son propre halo. Mesuré par `tools/banc_iso.gd --canaux` :
## six cas faux sur huit en écran scindé, aucun en vue unique, où seuls deux capteurs existent.
## Aucune suite sans rendu ne pouvait le voir ; la suite, elle, vérifiait « la » couche commune.
const COUCHE_CAPTEUR := 8
## ISO4 : plus les couches des disques des objets et du leurre, une par vue (`MiroirsIso.couche_objets`,
## 128 et 256) — elles sortent des masques des lightmaps comme celles des corps.
const COUCHES_CAPTEURS := 8 | 16 | 32 | 64 | 128 | 256
## Les calques 3D : murs et corps sur le calque commun, le sol de chaque joueur sur le sien.
const CALQUE_COMMUN := 1
const CALQUE_VUE_1 := 2
const CALQUE_VUE_2 := 4
## Les dix nœuds qui dessinent un corps, dans les deux vues (liste du banc ISO0.b).
const APPUIS_JOUEUR := ["visual", "visual_ptr", "visual_reveal", "visual_reveal_ptr",
	"visual_dim", "visual_dim_ptr", "visual_enemy", "visual_enemy_ptr",
	"visual_reveal_enemy", "visual_reveal_enemy_ptr"]

## Où la face d'un mur lit sa lumière : à ce nombre de pixels devant elle.
const PIED_PX := 8.0
## Le corps grossier du banc : 0,4 tuile de rayon, une tuile de haut.
const RAYON_CORPS_PX := 14.0
const HAUTEUR_CORPS_PX := 35.0

## Les tailles de lightmap, la question qu'H15 a laissée ouverte : `1080p` est l'aire
## logique du conteneur (ce que la vue rendait avant le chantier R), `plein` les pixels
## de la fenêtre. Le choix vit dans `GameSettings.iso_lightmap` et `--lightmap` ; Adrien
## tranche au relevé de fin de chantier, sur les appels de dessin et les cibles imprimés
## par le banc.
const LIGHTMAPS := ["1080p", "plein"]

## Les touches de la pâte, pendant qu'elle est allumée : **1, 2, 3, 4** choisissent A, B, C,
## D et **0** la brute ; F2 les fait défiler.
##
## ⚠️ **F2 seule n'a jamais atteint le jeu chez Adrien** (2026-09-14, trois parties, aucune
## ligne `[iso] pâte` au journal) : sur un Mac, F2 sans `fn` règle la luminosité et n'est pas
## transmise à l'application. La rangée des chiffres se lit par `physical_keycode` : en
## AZERTY, `keycode` y donne `&`, `é`, `"` (piège de `tools/banc_audio.gd`). Aucune action
## de l'Input Map ni aucun script du jeu ne la prend.
const TOUCHE_PATE := KEY_F2
const TOUCHES_DIRECTES := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_0: -1}
## **D, lavis et pochoir — décision d'Adrien, 2026-09-14** (jalon H-ISO1), sur la planche
## et la mesure de fidélité : la seule pâte qui garde la lueur faible au niveau de la vue
## de dessus.
const PATE_PAR_DEFAUT := IsoPate.LAVIS
const DRAPEAU_PATE := "--pate"

static var _instance: Presentation3D

## La pâte en cours (uniform `style`) — `--pate A|B|C|D|brute`, puis 1-4, 0 ou F2.
var style_pate := PATE_PAR_DEFAUT
## Ce que la ligne « VUE ISO » du panneau F3 affiche.
var etat := "en attente du prochain duel"

## Ce que le jeu a défait et qu'elle a dû reposer. Un compteur qui monte dit qu'un
## chemin du jeu repose des couches, des masques ou des tailles de sous-vue.
var corps_recaches := 0
var lightmaps_reposees := 0
var masques_reposes := 0
## Combien de fois la vue s'est rallumée sur un autre ensemble de vues (killcam, manche
## suivante, réglage) — le compte des aller-retours, pour F3 et les suites.
var bascules := 0

var _main: Node
var _actif := false
var _reconstruire := true
## Les vues regardées, dans l'ordre `vp1` puis `vp2` ; une ou deux.
var _vues: Array[SubViewport] = []
var _scinde := false
var _sauvegarde := {}
## CanvasItem → couche d'origine, pour rendre les sprites à l'extinction.
var _couches := {}

var _scene: Node3D
var _camera: CameraIso
var _sols: Array[MeshInstance3D] = []
var _murs: Node3D
var _corps: Array[Node3D] = []
var _mat_sols: Array[ShaderMaterial] = []
var _mat_mur: ShaderMaterial
var _mat_corps: Array[ShaderMaterial] = []
var _mat_profondeur: Array[ShaderMaterial] = []
## ISO3a — les corps de la vue iso sont les corps voxel des dix classes (`VoxelCorps`, chantier ISO
## Corps). Les cylindres d'ISO1 et d'ISO2 restent derrière `--corps-grossiers`, pour le banc et les
## comparaisons, jamais pour le jeu.
const DRAPEAU_CORPS_GROSSIERS := "--corps-grossiers"
var corps_voxel := true
## Par joueur : son `VoxelCorps` (vide en corps grossiers), et ce qu'il faut retenir d'une image à
## l'autre pour déduire ses états (points de vie, recharge, instants du tir, du coup reçu, de la mort).
var _voxels: Array = []
var _etats_corps: Array = []
var _miroirs: MiroirsIso
## ISO3a — combien de temps un tir et un coup reçu durent pour le corps, en secondes.
const DUREE_TIR_CORPS := 0.25
const DUREE_TOUCHE_CORPS := 0.6
var _vues3d: Array[SubViewport] = []
var _cameras3d: Array[CameraIso] = []
var _affichages: Array[TextureRect] = []
## `[vue_id][corps_id]` → `CapteurCorps`, ou `null` quand la vue n'est pas regardée.
var _capteurs := [[null, null], [null, null]]
## ISO5 — par joueur, ce que son fantôme de killcam a laissé d'une image à l'autre (points de vie, éclair
## du tir, posture, position à l'horloge du rejeu) ; vidé dès que le fantôme n'est plus montré.
var _etats_fantomes := [{}, {}]
## ISO5 — le voile de killcam de la vue iso, un `CanvasLayer` par vue regardée (voir
## `_accorder_le_voile_de_killcam`) ; `null` tant qu'aucune killcam ne l'a demandé.
var _voiles: Array = [null, null]
## Sous tous les calques du jeu (brouillage 1, interface 10, estampe 95) : en vue de dessus, le voile vit
## DANS l'arène (`z_index` 2), donc sous chacun d'eux.
const CALQUE_VOILE_KILLCAM := -1


## Le crochet du jeu — appelé par `GameState.rebuild_arena()`, sous garde `mode_iso`.
## Crée le nœud au premier appel, puis demande seulement de reconstruire les murs :
## la carte vient peut-être de changer.
static func accrocher(main: Node) -> Presentation3D:
	if not is_instance_valid(_instance):
		_instance = Presentation3D.new()
		_instance.name = NOM
		# Différé : `rebuild_arena()` tourne aussi pendant le `_ready()` de `Main`, quand
		# la racine refuse encore qu'on lui ajoute un enfant.
		main.get_tree().root.add_child.call_deferred(_instance)
	_instance._main = main
	_instance._reconstruire = true
	return _instance


static func instance() -> Presentation3D:
	return _instance if is_instance_valid(_instance) else null


## Le texte de la ligne « RENDU » du panneau F3. ISO6 : il commence par `mode_rendu`, et l'état
## de la vue porte la taille de chaque lightmap (`_decrire`).
static func texte_f3(mode_iso: bool) -> String:
	if not mode_iso:
		return "mode_rendu=dessus (drapeau de débogage --2d ou réglage)"
	var p := instance()
	return "mode_rendu=iso · " + (p.etat if p != null else "en attente du prochain duel")


# ---------------------------------------------------------------------------
# CE QUE LE JEU LUI DEMANDE — les vues où chaque joueur est rendu
# ---------------------------------------------------------------------------

## Le viewport qui rend l'ÉCRAN du joueur `pid` pendant que la vue iso tient : la fenêtre
## en vue unique, sa sous-vue 3D en écran scindé ; `null` sinon (vue éteinte, ou joueur
## dont la vue n'est pas regardée).
func viewport_ecran(pid: int) -> Viewport:
	if not _actif or _vue_de(pid) == null:
		return null
	if _scinde:
		return _vues3d[pid]
	return get_window()


## Le nœud sous lequel `GameState` loge les calques d'écran et l'appareil de brouillage du
## joueur `pid` (`_viewport_du_joueur`, `_accorder_brouillage_aux_vues`) : sa sous-vue 3D
## en écran scindé ; en vue unique, `GameState` lui-même — un `CanvasLayer` sous un nœud
## de la racine s'attache à la fenêtre, et part avec `Main` (le patron du rendu racine).
## `null` quand la vue iso ne rend pas ce joueur : le jeu garde alors ses propres règles.
func parent_ecran(pid: int) -> Node:
	if not _actif or _vue_de(pid) == null:
		return null
	return _vues3d[pid] if _scinde else _main


## Monde 2D → écran (en unités logiques du viewport rendu par `viewport_ecran`), par la
## caméra 3D de cette vue. Invalide quand la vue ne rend pas ce joueur.
func projecteur_ecran(pid: int) -> Callable:
	var cam := _camera_de(pid)
	var ecran := viewport_ecran(pid)
	if cam == null or ecran == null:
		return Callable()
	return func(point: Vector2) -> Vector2:
		return cam.vers_ecran(point, ecran.get_visible_rect().size)


## L'angle À L'ÉCRAN, chez le joueur `pid`, du segment `de` → `vers` du monde. Les
## caméras 2D du duel ne tournent jamais, donc en vue de dessus l'angle du monde vaut
## celui de l'écran ; incliné de 52°, le sol se voit raccourci en profondeur et l'angle
## change. `NAN` quand la vue ne rend pas ce joueur : l'appelant garde l'angle du monde.
func angle_ecran(pid: int, de: Vector2, vers: Vector2) -> float:
	var cam := _camera_de(pid)
	if cam == null:
		return NAN
	# L'angle ne dépend ni du centre ni de l'échelle : une aire unité suffit.
	return (cam.vers_ecran(vers, Vector2.ONE) - cam.vers_ecran(de, Vector2.ONE)).angle()


func _vue_de(pid: int) -> SubViewport:
	if not is_instance_valid(_main):
		return null
	var vue: SubViewport = _main.vp1 if pid == 0 else _main.vp2
	return vue if _vues.has(vue) else null


func _camera_de(pid: int) -> CameraIso:
	if not _actif or _vue_de(pid) == null:
		return null
	return _cameras3d[pid] if _scinde else _camera


## 0 pour la vue de J1 (`vp1`), 1 pour celle de J2.
func _id_de(vue: SubViewport) -> int:
	return 0 if vue == _main.vp1 else 1


# ---------------------------------------------------------------------------
# CYCLE
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Après la caméra 2D et l'interpolation des joueurs : sinon le sol et la lightmap
	# auraient une image d'écart, et le sol tremblerait à chaque pas.
	process_priority = 10000
	var args := OS.get_cmdline_user_args()
	var i := args.find(DRAPEAU_PATE)
	if i >= 0 and i + 1 < args.size():
		var st := IsoPate.style_depuis_nom(args[i + 1])
		if st >= IsoPate.BRUTE:
			style_pate = st
		else:
			push_error("Presentation3D : --pate attend A, B, C, D ou brute (reçu « %s »)" % args[i + 1])
	corps_voxel = not args.has(DRAPEAU_CORPS_GROSSIERS)
	_construire_la_scene()


func _enter_tree() -> void:
	# ISO3b — la zone morte des murs bas sur les disques des capteurs, poussée juste avant le rendu,
	# comme `GameState._pousser_zone_morte` : les caméras des capteurs ont alors suivi leur corps.
	if not RenderingServer.frame_pre_draw.is_connected(_pousser_zone_morte_capteurs):
		RenderingServer.frame_pre_draw.connect(_pousser_zone_morte_capteurs)


## ⚠️ **Pendant la fermeture du jeu, on ne rappelle pas le jeu.** L'extinction rend ses
## réglages à `GameState` puis relance l'accord des vues ; à la fermeture, l'accord échange le
## `World2D` de la racine pendant que l'arbre se démonte, et Godot plante (signal 11,
## « Parameter "viewport" is null » dans `Control`) — toutes les fenêtres du banc en vue unique
## sortaient en code 134 après leur mesure, le 2026-09-14.
func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_pousser_zone_morte_capteurs):
		RenderingServer.frame_pre_draw.disconnect(_pousser_zone_morte_capteurs)
	if _actif:
		_eteindre(true)


func _process(_delta: float) -> void:
	var voulues := _vues_a_projeter()
	if _actif and voulues != _vues:
		# Pourquoi la vue change, dans le journal : une extinction muette au milieu d'un banc a déjà fait
		# mesurer la vue de dessus sous le nom de l'iso (ISO3b, section « coût » du banc des murs bas).
		print("[iso] les vues à projeter changent : %s" % raison_des_vues())
		_eteindre()
		if not voulues.is_empty():
			bascules += 1
	if not voulues.is_empty():
		if not _actif:
			_allumer(voulues)
		# Une manche neuve rappelle le crochet (`rebuild_arena`) pendant que la vue tient :
		# la carte a peut-être changé — un salon en ligne adopte celle de l'hôte.
		if _reconstruire:
			_construire_les_murs()
		_tenir()
		_suivre()
	etat = _decrire(voulues)


func _mode_iso_voulu() -> bool:
	var reglages := get_node_or_null(^"/root/GameSettings")
	return reglages != null and bool(reglages.get("mode_iso"))


## Ce que `_vues_a_projeter` lit, en clair — imprimé à chaque changement de vues.
func raison_des_vues() -> String:
	var interface = _main.get("ui") if is_instance_valid(_main) else null
	var conteneurs := []
	if is_instance_valid(_main):
		for vue: SubViewport in [_main.vp1, _main.vp2]:
			var conteneur := vue.get_parent() as Control
			conteneurs.append("%s=%s" % [vue.name, conteneur.visible if conteneur != null else "sans conteneur"])
	return "mode_iso=%s, jeu=%s, joueurs=%s, caméras=%s, menu=%s, %s" % [
		_mode_iso_voulu(), is_instance_valid(_main) and _main.is_inside_tree(),
		is_instance_valid(_main) and is_instance_valid(_main.p1) and is_instance_valid(_main.p2),
		is_instance_valid(_main) and _main.cam1 != null and _main.cam2 != null,
		interface != null and bool(interface.get("_is_main_menu")), ", ".join(conteneurs)]


## Les vues à projeter, dans l'ordre `vp1`, `vp2` — vide si rien à faire. Le `visible`
## d'un conteneur est la source de vérité du jeu pour « quelle vue est regardée »
## (`_accorder_rendu_aux_vues`) : on la lit là, sans en tenir une seconde.
func _vues_a_projeter() -> Array[SubViewport]:
	var regardees: Array[SubViewport] = []
	if not _mode_iso_voulu() or not is_instance_valid(_main) or not _main.is_inside_tree():
		return regardees
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2) \
			or _main.cam1 == null or _main.cam2 == null:
		return regardees
	# ⚠️ **Pas sous les menus.** Le retour au menu remontre les DEUX conteneurs
	# (`_on_main_menu_requested`), et le démarrage du jeu construit l'arène derrière le
	# hub : sans cette garde, la vue iso s'allumait en écran scindé sous les menus — deux
	# rendus 3D et quatre capteurs pour une image que personne ne regarde. ISO1 n'avait
	# pas le cas : deux vues regardées l'éteignaient.
	var interface = _main.get("ui")
	if interface != null and bool(interface.get("_is_main_menu")):
		return regardees
	for vue: SubViewport in [_main.vp1, _main.vp2]:
		var conteneur := vue.get_parent() as Control
		if conteneur != null and conteneur.visible:
			regardees.append(vue)
	return regardees


# ---------------------------------------------------------------------------
# ALLUMER, TENIR, ÉTEINDRE
# ---------------------------------------------------------------------------

func _allumer(vues: Array[SubViewport]) -> void:
	_vues = vues.duplicate()
	_scinde = _vues.size() == 2
	var fond := _main.get_node_or_null("Background") as CanvasItem
	_sauvegarde = {
		"autorise": _main.rendu_racine_autorise,
		"fond": fond,
		"fond_visible": fond.visible if fond != null else false,
		"masques": {},
		"vues": [],
	}
	# Les couches des capteurs sortent des DEUX masques, regardés ou non : une vue peut se
	# rallumer entre deux images (retour de killcam) et lirait un disque blanc au sol.
	for vue: SubViewport in [_main.vp1, _main.vp2]:
		_sauvegarde["masques"][vue] = vue.canvas_cull_mask
		vue.canvas_cull_mask = _sans_capteurs(vue.canvas_cull_mask)
	for vue in _vues:
		var conteneur := vue.get_parent() as SubViewportContainer
		_sauvegarde["vues"].append({
			"vue": vue,
			"conteneur": conteneur,
			"alpha": conteneur.modulate.a,
			"souris": conteneur.mouse_filter,
			"taille": vue.size,
			"aire": vue.size_2d_override,
			"aire_etiree": vue.size_2d_override_stretch,
			"stretch": conteneur.stretch,
			"top_level": conteneur.top_level,
		})
	# Le chemin `SubViewport` : sans lui, la vue unique est rendue par la racine et la
	# texture de la vue reste gelée — il n'y aurait rien à projeter. `_actif` AVANT
	# l'accord : c'est lui qui envoie les calques d'écran et le brouillage dans nos
	# viewports (`GameState._viewport_du_joueur` interroge `parent_ecran`).
	_main.rendu_racine_autorise = false
	_actif = true
	_main._accorder_rendu_aux_vues()
	# ⚠️ **Transparent, pas caché** (écart voulu du banc ISO0.b) : caché, le jeu
	# arrêterait la vue à chaque accord, retirerait son brouillage, et le conteneur ne
	# transmettrait plus la souris. Transparent, il reste regardé ; la 3D prend l'écran.
	# APRÈS l'accord : `_accorder_la_peinture_de_la_racine` repose l'alpha à 1.
	for vue in _vues:
		_poser_lightmap(vue)
	# Le fond noir plein cadre de `main.tscn` se dessine APRÈS la 3D de la racine.
	# `visible` et non `modulate` : c'est `modulate` que le jeu réécrit à chaque accord.
	if fond != null:
		fond.visible = false
	if _reconstruire or _murs == null:
		_construire_les_murs()
	for m in _materiaux():
		m.set_shader_parameter("lumiere_1", _main.vp1.get_texture())
		m.set_shader_parameter("lumiere_2", _main.vp2.get_texture())
	_poser_capteurs()
	for j in [_main.p1, _main.p2]:
		_cacher_corps(j)
	_poser_cameras()
	_scene.visible = true
	print("[iso] vue isométrique allumée : %s — tangage %s°, murs %s tuile (%s), pâte %s, lightmap %s"
		% ["écran scindé (vues %s et %s)" % [_vues[0].name, _vues[1].name] if _scinde
		else "vue unique (%s)" % _vues[0].name,
		str(_camera.tangage_deg), str(IsoGeometrie.hauteur_mur_haut()),
		IsoGeometrie.source_des_hauteurs(), IsoPate.NOMS[style_pate], variante_lightmap()])


func _eteindre(sortie_de_l_arbre := false) -> void:
	# ISO4 — les sprites remplacés reprennent leur couche, les capteurs des objets partent.
	if _miroirs != null:
		_miroirs.vider()
	# ISO5 — le voile de killcam iso part avec la vue ; le voile 2D reprend sa couche (`_rendre_corps`).
	for i in _voiles.size():
		if _voiles[i] != null and is_instance_valid(_voiles[i]):
			(_voiles[i] as CanvasLayer).visible = false
			(_voiles[i] as Node).queue_free()
		_voiles[i] = null
	_actif = false
	if _scene != null:
		_scene.visible = false
	if _camera != null:
		_camera.current = false
	for i in _vues3d.size():
		_cameras3d[i].current = false
		_vues3d[i].render_target_update_mode = SubViewport.UPDATE_DISABLED
		_affichages[i].visible = false
	_retirer_capteurs()
	_rendre_corps()
	# `Main` libéré pendant que la vue tenait : les calques d'écran et le brouillage qu'il
	# avait logés dans nos vues 3D n'ont plus personne pour les reprendre.
	if not is_instance_valid(_main):
		for vue3d in _vues3d:
			for enfant in vue3d.get_children():
				if not enfant is Camera3D:
					enfant.queue_free()
	if not _sauvegarde.is_empty():
		for s in _sauvegarde["vues"]:
			# ⚠️ Non typée : `Main` libéré pendant que la vue tenait (une suite qui fait `queue_free()`
			# sur le jeu) laisse ici une instance libérée, et l'affecter à une variable typée
			# `SubViewport` est une erreur de script avant même le `is_instance_valid` qui suit.
			# Trouvé par ISO6, quand l'iso est devenue le défaut de toutes les suites (`test_classes`).
			var vue = s["vue"]
			var conteneur = s["conteneur"]
			if is_instance_valid(conteneur):
				conteneur.modulate.a = s["alpha"]
				conteneur.mouse_filter = s["souris"]
				# De retour dans la mise en page : `stretch` rendu, qui réimpose à la vue la taille
				# du conteneur ; puis la boîte le replace — elle ne trie pas d'elle-même quand un
				# enfant quitte `top_level`.
				conteneur.top_level = s["top_level"]
				conteneur.stretch = s["stretch"]
				var boite := conteneur.get_parent() as Container
				if boite != null:
					boite.queue_sort()
			if is_instance_valid(vue):
				vue.size_2d_override = s["aire"]
				vue.size_2d_override_stretch = s["aire_etiree"]
				if is_instance_valid(conteneur) and not conteneur.stretch:
					vue.size = s["taille"]
		for vue in _sauvegarde["masques"]:
			if is_instance_valid(vue):
				(vue as SubViewport).canvas_cull_mask = _sauvegarde["masques"][vue]
		var fond = _sauvegarde["fond"]
		if is_instance_valid(fond):
			fond.visible = _sauvegarde["fond_visible"]
		if is_instance_valid(_main):
			_main.rendu_racine_autorise = _sauvegarde["autorise"]
			# `_actif` est faux : l'accord ramène calques et brouillage dans les vues du jeu.
			if _main.is_inside_tree() and not sortie_de_l_arbre:
				_main._accorder_rendu_aux_vues()
	_sauvegarde.clear()
	_vues.clear()
	_scinde = false
	print("[iso] vue isométrique éteinte (%d corps recachés, %d lightmap(s) reposée(s), %d masque(s) reposé(s), %d bascule(s))"
		% [corps_recaches, lightmaps_reposees, masques_reposes, bascules])


## Ce que le jeu peut défaire pendant la partie, reposé et compté.
##
## ⚠️ **Le mode de rendu des lightmaps n'est PAS reposé ici.** ISO1 relançait toute vue
## arrêtée ; or le gel du kill (`_do_end_round`) arrête les deux sous-vues exprès, pour
## figer l'image de l'impact. La vue iso gèle avec elles (`_suivre`), et c'est
## `_accorder_rendu_aux_vues` — chemin `SubViewport` forcé — qui les rallume ensuite.
func _tenir() -> void:
	for s in _sauvegarde["vues"]:
		var vue: SubViewport = s["vue"]
		var conteneur = s["conteneur"]
		if is_instance_valid(conteneur):
			if conteneur.modulate.a != 0.0:
				conteneur.modulate.a = 0.0
			if conteneur.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				conteneur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Le cadre suit la fenêtre (il se relit dans la boîte), et le réglage de lightmap peut
		# changer en jeu : tout écart se repose, et se compte.
		if not _lightmap_en_place(vue):
			_poser_lightmap(vue)
			lightmaps_reposees += 1
	var fond = _sauvegarde["fond"]
	if is_instance_valid(fond) and fond.visible:
		fond.visible = false
	if _main.rendu_racine_autorise:
		_main.rendu_racine_autorise = false
		_main._accorder_rendu_aux_vues()
	for vue: SubViewport in [_main.vp1, _main.vp2]:
		if (vue.canvas_cull_mask & COUCHES_CAPTEURS) != 0:
			vue.canvas_cull_mask = _sans_capteurs(vue.canvas_cull_mask)
			masques_reposes += 1
	for j in [_main.p1, _main.p2]:
		corps_recaches += _cacher_corps(j)


## ISO3b — la zone morte des murs bas sur les disques des capteurs. Le capteur rend au corps iso la
## lumière du sprite qu'il remplace ; ce sprite, accroupi dans la zone morte d'un muret, ne reçoit plus
## la lumière venue de l'autre côté (MB3c, `player_enemy_light.gdshader` et `player_rim_light`) : le
## disque la refuse de même, par les mêmes uniformes (`MursBasRendu.poser_corps`, jugé en son centre à
## la hauteur de sa posture), convertis dans l'écran du CAPTEUR — celui où son `light()` lit
## LIGHT_POSITION. Les murs sont ceux que `GameState` pousse à ses propres vues (`murs_bas`), jamais une
## copie : le banc les retire pour mesurer « sans la règle », et les capteurs doivent suivre.
func _pousser_zone_morte_capteurs() -> void:
	if not _actif or _main == null or not is_instance_valid(_main):
		return
	var arene := _main.get("arena") as Node2D
	if arene == null:
		return
	var murs: Array = _main.get("murs_bas") if "murs_bas" in _main else []
	var joueurs := [_main.p1, _main.p2]
	for id in _capteurs.size():
		for j in (_capteurs[id] as Array).size():
			var c = _capteurs[id][j]
			if c == null or not is_instance_valid(c) or not is_instance_valid(joueurs[j]):
				continue
			var capteur := c as CapteurCorps
			var ecran := capteur.get_final_transform() * capteur.get_canvas_transform()
			var u := MursBasRendu.uniformes_de_vue(ecran * arene.global_transform, murs,
				Rect2(Vector2.ZERO, Vector2(capteur.size)))
			MursBasRendu.poser_corps(capteur.matiere() as ShaderMaterial, u,
				ecran * (joueurs[j] as Node2D).global_position, bool(joueurs[j].get("accroupi")))


func _suivre() -> void:
	var joueurs := [_main.p1, _main.p2]
	for m in _materiaux():
		m.set_shader_parameter("style", style_pate)
	for vue in _vues:
		var id := _id_de(vue)
		# Le gel du kill : la lightmap ne bouge plus, la 3D non plus — caméra, sol et corps
		# restent où ils sont, et la sous-vue 3D s'arrête avec sa lightmap.
		var gelee := vue.render_target_update_mode == SubViewport.UPDATE_DISABLED
		for j in 2:
			var capteur: CapteurCorps = _capteurs[id][j]
			if capteur != null:
				capteur.render_target_update_mode = SubViewport.UPDATE_DISABLED if gelee \
					else SubViewport.UPDATE_ALWAYS
		if _scinde:
			_vues3d[id].render_target_update_mode = SubViewport.UPDATE_DISABLED if gelee \
				else SubViewport.UPDATE_ALWAYS
		if gelee:
			continue
		var canevas: Transform2D = vue.canvas_transform
		var taille := Vector2(vue.size_2d_override) if vue.size_2d_override != Vector2i.ZERO \
			else Vector2(vue.size)
		var n := id + 1
		for m in _materiaux():
			m.set_shader_parameter("canevas_%d_x" % n, canevas.x)
			m.set_shader_parameter("canevas_%d_y" % n, canevas.y)
			m.set_shader_parameter("canevas_%d_o" % n, canevas.origin)
			m.set_shader_parameter("taille_%d" % n, taille)
		var rect := CameraIso.rect_couvert(canevas, taille)
		_sols[id].position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		_sols[id].scale = Vector3(rect.size.x, 1.0, rect.size.y)
		if _scinde:
			_accorder_vue3d(id)
			_cameras3d[id].suivre(canevas, taille)
		else:
			_camera.suivre(canevas, taille)
		for j in 2:
			var capteur: CapteurCorps = _capteurs[id][j]
			var joueur = joueurs[j]
			if capteur != null and is_instance_valid(joueur):
				capteur.suivre(joueur.global_position, joueur.visible and joueur.visual.visible)
	_accorder_le_voile_de_killcam()
	for j in 2:
		var joueur = joueurs[j]
		# ISO5 — **pendant la killcam, c'est le FANTÔME qui porte le corps**, pas le joueur. Le rejeu cache
		# les sprites des vrais joueurs (`hide_all_visuals`) et montre les fantômes `GhostP1`/`GhostP2` à
		# leur place : lire le joueur ferait disparaître le corps pendant toute la lecture (constat d'ISO4).
		var fantome := fantome_montre(j)
		if fantome != null:
			_suivre_le_fantome(j, fantome)
			continue
		if not (_etats_fantomes[j] as Dictionary).is_empty():
			_etats_fantomes[j] = {}
		# `visual.visible` est LU, jamais écrit : c'est l'état de mort que le rejeu
		# enregistre. `visible` du joueur : l'entraînement cache J2 ainsi.
		_corps[j].visible = is_instance_valid(joueur) and joueur.visible and joueur.visual.visible
		if not _corps[j].visible:
			continue
		var p: Vector2 = joueur.global_position
		if corps_voxel:
			# ISO3a — le corps de sa classe, posé et animé depuis le joueur (`VoxelCorps.poser`, fonction
			# pure) ; son ancre reste à l'origine, à l'échelle d'une tuile.
			_accorder_la_classe(j, joueur)
			(_voxels[j] as VoxelCorps).poser(etat_du_corps(j, joueur))
		else:
			_corps[j].position = Vector3(p.x, 0.0, p.y)
		# Le centre que suit son capteur, à la même image : le corps y lit sa lumière.
		_mat_corps[j].set_shader_parameter("centre", p)
		# ISO2b — l'effacement et la silhouette de la vue de dessus, PAR VUE, lus sur les sprites
		# que ce corps remplace tels que `player.gd` les a posés cette image. Aucun recalcul.
		for vue_id in 2:
			var o := opacite_du_corps(joueur, vue_id == j)
			var sil := silhouette_du_corps(joueur, vue_id == j)
			for m in [_mat_corps[j], _mat_profondeur[j]]:
				(m as ShaderMaterial).set_shader_parameter("opacite_%d" % (vue_id + 1), o)
				(m as ShaderMaterial).set_shader_parameter("silhouette_%d" % (vue_id + 1), sil)
		if not corps_voxel:
			_corps[j].basis = Basis.looking_at(Vector3(cos(joueur.rotation), 0.0, sin(joueur.rotation)), Vector3.UP)


# ---------------------------------------------------------------------------
# LES LIGHTMAPS — la taille, une question laissée ouverte par H15
# ---------------------------------------------------------------------------

## `1080p` ou `plein` : `--lightmap` pour l'exécution, sinon le réglage du joueur.	# ISO4 — les miroirs, après les corps : ils lisent les mêmes vues et la même pâte.
	var ids := []
	for vue in _vues:
		ids.append(_id_de(vue))
	_miroirs.suivre(_main, ids, style_pate, self)


func variante_lightmap() -> String:
	var reglages := get_node_or_null(^"/root/GameSettings")
	var v := String(reglages.get("iso_lightmap")) if reglages != null else "1080p"
	return v if LIGHTMAPS.has(v) else "1080p"


## La taille de la cible 2D pour une aire logique donnée (formule du banc ISO0.b).
static func taille_lightmap(variante: String, logique: Vector2i, etirement: float) -> Vector2i:
	if variante == "plein":
		return Vector2i((Vector2(logique) * etirement).round())
	return logique


func _taille_lightmap(logique: Vector2i) -> Vector2i:
	return taille_lightmap(variante_lightmap(), logique, _etirement())


## Pixels de fenêtre par unité logique : le rapport que `stretch = keep` applique.
##
## ⚠️ **Sans fenêtre (headless), `window_get_size()` rend 0** : l'étirement tombait à 0,
## et avec lui les vues 3D (2×2) et la lightmap `plein` (0×0) — mesuré par
## `tools/test_iso_vues.gd` à sa première exécution. Sans fenêtre, un pixel vaut une unité.
func _etirement() -> float:
	var aire := get_viewport().get_visible_rect().size
	var fenetre := DisplayServer.window_get_size()
	if aire.y <= 0.0 or fenetre.y <= 0:
		return 1.0
	return float(fenetre.y) / aire.y


## Le cadre logique de la vue `id` : celui que le `HBoxContainer` des vues lui donne — relu
## VIVANT à chaque image, dans la BOÎTE et non dans le conteneur, que la vue iso sort de la
## mise en page (`_poser_lightmap`). Même partage que `BoxContainer` : deux vues étendues
## séparées de `separation` pixels, la moitié entière à gauche (957 et 958 sur 1920).
func _cadre(id: int) -> Rect2:
	var vue: SubViewport = _main.vp1 if id == 0 else _main.vp2
	var conteneur := vue.get_parent() as Control
	var boite := conteneur.get_parent() as Control
	if boite == null:
		return conteneur.get_global_rect()
	var r := boite.get_global_rect()
	if not _scinde:
		return r
	var sep := float(boite.get_theme_constant("separation"))
	var gauche := floorf((r.size.x - sep) * 0.5)
	if id == 0:
		return Rect2(r.position, Vector2(gauche, r.size.y))
	return Rect2(r.position + Vector2(gauche + sep, 0.0), Vector2(r.size.x - gauche - sep, r.size.y))


## La vue 2D devient une lightmap : elle rend toujours, mais ne s'affiche plus.
##
## ⚠️ **Hors de la mise en page, et c'est ce qui rend `plein` possible.** Godot refuse de
## changer la taille d'une sous-vue dont le conteneur est en `stretch`, par un simple
## avertissement (« Can't change the size of a `SubViewport`… ») : vingt et une fois dans le
## journal de la première exécution de `tools/test_iso_vues.gd`, et la lightmap `plein`
## restait en `1080p` sans qu'aucun contrôle ne rougisse. Sans `stretch`, un conteneur prend
## la taille de sa vue comme taille MINIMALE et pousse son voisin dans la boîte (piège du
## 2026-09-14). D'où `top_level` : le conteneur sort du tri de la boîte, se pose sur le cadre
## qu'elle lui aurait donné, et peut alors lâcher `stretch` en `plein`. En `1080p` il le
## garde, et la vue prend la taille du conteneur : l'aire logique.
##
## Transparent, pas caché (écart voulu du banc ISO0.b) : caché, le jeu arrêterait la vue à
## chaque accord. L'aire 2D vient de `size_2d_override` : le monde 2D reste celui d'une vue
## à l'aire de son cadre (caméras, zoom et champ inchangés) pendant que la texture prend la
## résolution de la variante.
func _poser_lightmap(vue: SubViewport) -> void:
	var conteneur := vue.get_parent() as SubViewportContainer
	var cadre := _cadre(_id_de(vue))
	var logique := Vector2i(cadre.size.round())
	var plein := variante_lightmap() == "plein"
	conteneur.modulate.a = 0.0
	# La visée souris est reprojetée par `_viser_a_la_souris()`.
	conteneur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteneur.top_level = true
	conteneur.global_position = cadre.position
	conteneur.size = cadre.size
	conteneur.stretch = not plein
	vue.size_2d_override = logique
	vue.size_2d_override_stretch = true
	if plein:
		vue.size = _taille_lightmap(logique)


## La lightmap est-elle posée comme la variante le veut ? En `plein`, le conteneur sans
## `stretch` grandit jusqu'à sa vue (taille minimale) : seule sa position se compare.
func _lightmap_en_place(vue: SubViewport) -> bool:
	var conteneur := vue.get_parent() as SubViewportContainer
	var cadre := _cadre(_id_de(vue))
	var logique := Vector2i(cadre.size.round())
	var plein := variante_lightmap() == "plein"
	if not conteneur.top_level or conteneur.stretch == plein \
			or not conteneur.global_position.is_equal_approx(cadre.position):
		return false
	if not plein and not conteneur.size.is_equal_approx(cadre.size):
		return false
	return vue.size_2d_override == logique and vue.size == _taille_lightmap(logique)


static func _sans_capteurs(masque: int) -> int:
	return (masque & 0xFFFFFFFF) & ~COUCHES_CAPTEURS


# ---------------------------------------------------------------------------
# LES CAPTEURS DE CORPS
# ---------------------------------------------------------------------------

## Le masque de lumière du disque qui remplace, chez le joueur `vue_id`, le sprite du
## corps `corps_id` : le sien (`JOUEUR_LOCAL`), ou celui d'en face
## (`masque_vue_adverse`) — la règle des sprites, mot pour mot (`canaux_lumiere.gd`).
static func masque_capteur(vue_id: int, corps_id: int) -> int:
	if vue_id == corps_id:
		return CanauxLumiere.JOUEUR_LOCAL
	return CanauxLumiere.masque_vue_adverse(corps_id)


## La couche de visibilité du capteur de la vue `vue_id` sous le corps `corps_id` : 8, 16, 32
## ou 64 — une par capteur (voir `COUCHE_CAPTEUR`).
static func couche_capteur(vue_id: int, corps_id: int) -> int:
	return COUCHE_CAPTEUR << (vue_id * 2 + corps_id)


func _poser_capteurs() -> void:
	_retirer_capteurs()
	for vue in _vues:
		var id := _id_de(vue)
		for j in 2:
			var c := CapteurCorps.creer(id, j, _main.vp1.world_2d, couche_capteur(id, j), masque_capteur(id, j))
			add_child(c)
			_capteurs[id][j] = c
			_mat_corps[j].set_shader_parameter("capteur_%d" % (id + 1), c.get_texture())


func _retirer_capteurs() -> void:
	for id in 2:
		for j in 2:
			var c = _capteurs[id][j]
			if c != null:
				if is_instance_valid(c):
					remove_child(c)
					c.queue_free()
				_capteurs[id][j] = null
			if _mat_corps.size() > j:
				_mat_corps[j].set_shader_parameter("capteur_%d" % (id + 1), null)


# ---------------------------------------------------------------------------
# ISO2b — L'EFFACEMENT DES CORPS ET LA SILHOUETTE DE SOI
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ISO3a — LES CORPS VOXEL
# ---------------------------------------------------------------------------

## Un `VoxelCorps` par joueur, sous une ancre `CorpsN` posée à l'origine et mise à l'échelle d'une
## tuile. ⚠️ **L'échelle est portée par l'ancre, jamais devinée dans le shader.** `VoxelCorps` pense
## en tuiles (`poser()` divise la position par la taille d'une tuile, ses boîtes mesurent des
## fractions de tuile) ; la scène iso pense en pixels de monde, comme les lightmaps et les capteurs.
## Sous l'ancre, le corps retombe en pixels, et son shader lit `monde.xz` directement en pixels :
## `pixels_par_unite` reste à l'identité (convenu avec la session ISO Corps le 2026-09-15).
##
## Un seul corps par joueur pour les deux caméras, comme le corps grossier : chaque caméra le relit
## avec ses propres uniformes (`capteur_N`, `opacite_N`, `silhouette_N`, choisis par
## `lightmap_de_j2(CAMERA_VISIBLE_LAYERS)`) — c'est « un corps par joueur et par vue » au sens des
## canaux, sans poser deux fois chaque corps par image.
func _construire_les_corps_voxel() -> void:
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	for i in 2:
		var ancre := Node3D.new()
		ancre.name = "Corps%d" % (i + 1)
		ancre.scale = Vector3.ONE * tuile
		var voxel := VoxelCorps.new()
		voxel.name = "Voxel"
		ancre.add_child(voxel)
		_scene.add_child(ancre)
		_corps.append(ancre)
		_voxels.append(voxel)
		_mat_corps.append(null)
		_mat_profondeur.append(null)
		_etats_corps.append({"hp": -1.0, "recharge": 0.0, "t_tir": -100.0, "t_touche": -100.0,
			"t_mort": -100.0, "mort": false})
		_accorder_la_classe(i, null)


## Le corps de la classe du joueur, reconstruit si la classe a changé, et ses nouveaux matériaux reliés
## à ce que la présentation pilote : capteurs des deux vues, capteur actif, échelle en pixels, style.
## ⚠️ `construire()` crée de NOUVEAUX matériaux : sans ce relais, un joueur qui change de classe
## entre deux manches aurait un corps lisant des capteurs vides — noir partout.
func _accorder_la_classe(j: int, joueur: Node) -> void:
	_accorder_le_slug(j, slug_du_corps(joueur))


## Le corps d'un slug donné : celui de la classe du joueur, ou celle qu'avait son fantôme de killcam (ISO5).
func _accorder_le_slug(j: int, slug: String) -> void:
	var voxel := _voxels[j] as VoxelCorps
	if voxel.slug() == slug and _mat_corps[j] != null:
		return
	if not voxel.construire(slug):
		return
	voxel.definir_pixels_par_unite(1.0)
	var mat := voxel.materiau()
	mat.set_shader_parameter("capteur_actif", true)
	mat.set_shader_parameter("monde_capteur_px", CapteurCorps.MONDE_PX)
	mat.set_shader_parameter("rayon_lu_px", minf(RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0))
	mat.set_shader_parameter("style", style_pate)
	# ⚠️ **Lu au bord du disque, dans la direction du fragment.** Un corps voxel est bien plus mince que son
	# sprite : lu à sa propre distance du centre, son torse et sa tête restaient à l'ombre du torse du
	# porteur, et un porteur de torche trahi par sa rétrodiffusion en vue de dessus restait noir en iso
	# (banc ISO3a, 2026-09-15). Chaque point de sa surface lit maintenant la lumière du sprite dans sa
	# direction, au rayon lu — là où le sprite montre son croissant éclairé (voir `corps_iso.gdshader`).
	mat.set_shader_parameter("lecture_au_bord", 1.0)
	# ISO7 — l'encre des arêtes des voxels (sans effet tant que le shader des corps ne la déclare pas).
	IsoMateriaux.accorder_corps(mat)
	_mat_corps[j] = mat
	_mat_profondeur[j] = voxel.materiau_profondeur()
	for id in 2:
		var c = _capteurs[id][j]
		if c != null:
			mat.set_shader_parameter("capteur_%d" % (id + 1), (c as CapteurCorps).get_texture())


## Le corps voxel d'un joueur : celui de sa classe (`ClassData.slug()`, la lecture de
## `GameState._slug_de_classe`). Sans classe connue du catalogue, le corps de la première classe :
## c'est un repli de RENDU — il faut bien dessiner quelqu'un —, pas une statistique. `VoxelCatalogue`
## et `GameState` refusent ce repli pour les données, à raison ; l'image n'en porte aucune.
static func slug_du_corps(joueur: Node) -> String:
	var classe: Variant = joueur.get("current_weapon") if joueur != null and is_instance_valid(joueur) else null
	return slug_de_la_classe(classe)


## Le slug du corps voxel d'une classe (`ClassData`), avec le même repli de rendu que `slug_du_corps`.
static func slug_de_la_classe(classe: Variant) -> String:
	if classe is ClassData:
		var s := String((classe as ClassData).slug())
		if VoxelCatalogue.slugs().has(s):
			return s
	return VoxelCatalogue.slugs()[0]


## L'état que `VoxelCorps.poser()` attend, déduit du joueur sans rien lui ajouter : position, visée,
## vitesse, torche, et trois événements lus d'une image à l'autre — un temps de recharge qui repart
## (un tir), des points de vie qui baissent (un coup reçu), `dead` qui passe à vrai (la mort). `t` est le
## temps depuis le dernier de ces événements tant qu'il dure, sinon le temps qui passe (la cadence de
## la marche et de la respiration). Accroupi et enjambement viennent de la posture de `main` (ISO3b) :
## `accroupi` lu sur le joueur, sa bascule remettant `t` à zéro comme un tir ; l'enjambement déduit de
## la position (`progres_enjambement`). ⚠️ Le corps d'un mort est caché comme son sprite (`visual.visible`) : la pose
## de mort ne se voit donc que le temps de l'image où les deux ne sont pas encore d'accord.
func etat_du_corps(j: int, joueur: Node) -> Dictionary:
	var e: Dictionary = _etats_corps[j]
	var maintenant := Time.get_ticks_msec() / 1000.0
	var hp := float(joueur.get("hp"))
	var recharge := float(joueur.get("shoot_cooldown"))
	var mort := bool(joueur.get("dead"))
	if float(e["hp"]) >= 0.0 and hp < float(e["hp"]) - 0.001:
		e["t_touche"] = maintenant
	if recharge > float(e["recharge"]) + 0.001:
		e["t_tir"] = maintenant
	if mort and not bool(e["mort"]):
		e["t_mort"] = maintenant
	e["hp"] = hp
	e["recharge"] = recharge
	e["mort"] = mort
	# ISO3b — la posture de `main` (MB2), lue et jamais écrite. C'est aussi ce que le rejeu repose sur les
	# joueurs pendant la killcam (`poser_posture`, depuis `Snapshot.pN_accroupi`) : un fantôme iso (ISO5)
	# prendra la posture enregistrée sans rien de plus.
	var accroupi := bool(joueur.get("accroupi"))
	if accroupi != bool(e.get("accroupi", false)):
		e["t_posture"] = maintenant
	e["accroupi"] = accroupi
	var tir := maintenant - float(e["t_tir"]) < DUREE_TIR_CORPS
	var touche := maintenant - float(e["t_touche"]) < DUREE_TOUCHE_CORPS
	var posture := maintenant - float(e.get("t_posture", -100.0)) < VoxelCorps.DUREE_TRANSITION_ACCROUPI
	var t := maintenant
	if mort:
		t = maintenant - float(e["t_mort"])
	elif tir or touche or posture:
		t = maintenant - maxf(maxf(float(e["t_tir"]) if tir else -100.0,
			float(e["t_touche"]) if touche else -100.0), float(e["t_posture"]) if posture else -100.0)
	var rotation := float(joueur.get("rotation"))
	var vitesse = joueur.get("velocity")
	# ISO3b — l'enjambement, un progrès 0..1 le long de la traversée du muret : `VoxelCorps` le veut
	# « déjà avancé ». Déduit de la POSITION et des murs de la manche, par la règle même qui décide
	# `enjambe` dans `player.gd` (`MursBas.chevauche_cercle`). ⚠️ Chez le client, `Player.enjambe`
	# n'est jamais recalculé pour l'adversaire interpolé (`_regler_enjambement` n'est appelé que pour
	# un joueur qui bouge) — signalé, hors périmètre ; sa position, elle, est à jour.
	var v2: Vector2 = vitesse if vitesse is Vector2 else Vector2.ZERO
	if v2.length() > 1.0:
		e["direction"] = v2.normalized()
	var direction: Vector2 = e.get("direction", Vector2(cos(rotation), sin(rotation)))
	var enjambe := progres_enjambement((joueur as Node2D).global_position, direction,
		MursBas.murs_de_la_manche, bool(joueur.get("enjambe")))
	return {
		"position": (joueur as Node2D).global_position,
		"visee": Vector2(cos(rotation), sin(rotation)),
		"vitesse": vitesse if vitesse is Vector2 else Vector2.ZERO,
		"torche": bool(joueur.get("flashlight_on")),
		"arme": (_voxels[j] as VoxelCorps).slug(),
		"tir": tir, "touche": touche, "mort": mort,
		"accroupi": accroupi, "enjambe": enjambe,
		"t": t,
	}


## ISO5 — le fantôme de killcam du joueur `j` quand le jeu le MONTRE, sinon `null`. `visible` est lu,
## jamais écrit : c'est le rejeu qui le pose (`ghost_pN.visible = snap.pN_visible`), et un fantôme caché
## — la victime morte dans le rejeu — rend la main au joueur, caché lui aussi : le corps disparaît avec
## le sprite, comme en vue de dessus.
func fantome_montre(j: int) -> Node2D:
	if not is_instance_valid(_main):
		return null
	var fantome = _main.get("ghost_p1" if j == 0 else "ghost_p2")
	if not is_instance_valid(fantome) or not (fantome is Node2D):
		return null
	return fantome if (fantome as Node2D).is_visible_in_tree() else null


## ISO5 — le corps du joueur `j` porté par son fantôme de killcam : position et visée du fantôme ; classe,
## torche, tir, coup reçu et posture de l'instantané rejoué (`GameState.current_snap`).
##
## ⚠️ **Composé comme le fantôme se dessine en vue de dessus, pas comme un joueur.** Le fantôme 2D est
## `VisualColored` en aplat (`ghost_unshaded.gdshader`), à la moitié de sa couleur, sans aucun sprite
## éclairé, et sur la couche commune (« visible par toutes les caméras », `_setup_ghosts`). Le corps iso
## n'a donc aucune part éclairée (opacité 0) et porte la silhouette du fantôme dans CHAQUE vue dont le
## masque voit sa couche — la règle de la silhouette de soi (chez soi seulement) est celle du duel, pas
## celle du rejeu, qui montre les deux fantômes aux deux joueurs. Une seule source : le sprite du fantôme.
func _suivre_le_fantome(j: int, fantome: Node2D) -> void:
	var trace := fantome.get_node_or_null(^"VisualColored") as CanvasItem
	_cacher_le_fantome(fantome)
	var snap = _main.get("current_snap")
	var p := fantome.global_position
	_corps[j].visible = true
	if corps_voxel:
		_accorder_le_slug(j, slug_de_la_classe(_classe_du_fantome(j, snap)))
		(_voxels[j] as VoxelCorps).poser(etat_du_fantome(j, fantome, snap))
	else:
		_corps[j].position = Vector3(p.x, 0.0, p.y)
		_corps[j].basis = Basis.looking_at(Vector3(cos(fantome.global_rotation), 0.0,
			sin(fantome.global_rotation)), Vector3.UP)
	_mat_corps[j].set_shader_parameter("centre", p)
	for vue_id in 2:
		var vue: SubViewport = _main.vp1 if vue_id == 0 else _main.vp2
		var sil := silhouette_du_fantome(trace, couche_d_origine(trace), vue.canvas_cull_mask)
		for m in [_mat_corps[j], _mat_profondeur[j]]:
			(m as ShaderMaterial).set_shader_parameter("opacite_%d" % (vue_id + 1), 0.0)
			(m as ShaderMaterial).set_shader_parameter("silhouette_%d" % (vue_id + 1), sil)


## La silhouette qu'un fantôme de killcam dessine dans une vue : la couleur de son `VisualColored` (alpha
## 0,5 compris, posé par `_setup_ghosts`) fois son opacité rendue ; transparente si le masque de la vue ne
## voit pas sa couche. `couche` : sa couche d'origine, la vue iso l'ayant retirée des lightmaps.
##
## ISO6 — **la couleur est atténuée de `ATTENUATION_FANTOME` pour s'aligner sur le fantôme 2D.** ISO5 a
## mesuré, dans les mêmes conditions et la même exécution (`banc_iso.gd --jeu --scinde --killcam`, lumières
## éteintes, teinte noire, médianes des pixels allumés), le fantôme iso à 87/111/126 et 125/87/89 contre
## 22/30/30 et 31/23/22 en vue de dessus : un rapport de 0,24 à 0,27 sur les six canaux. Relu par ISO6 au
## pixel sur la capture 2D d'une vraie killcam (`captures_iso5/gros_plan_j1_vue_de_dessus.png`) : médianes
## 19/25/25 et 23/16/15 — le fantôme 2D est bien quatre fois plus sombre que sa couleur à demi-opacité.
## ⚠️ La piste d'ISO5 (« la luminance moyenne de la texture de `VisualColored` ») ne tient pas : cette
## texture est un blanc de 1×1 (`player.gd`, posée pour que les UV existent). L'atténuation est donc un
## étalon mesuré, pas une formule dérivée ; l'alpha (la couverture) ne change pas.
const ATTENUATION_FANTOME := 0.25

static func silhouette_du_fantome(trace: Variant, couche: int, masque_de_la_vue: int) -> Color:
	if not is_instance_valid(trace) or not (trace is Polygon2D) or (couche & masque_de_la_vue) == 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var c: Color = (trace as Polygon2D).color
	return Color(c.r * ATTENUATION_FANTOME, c.g * ATTENUATION_FANTOME, c.b * ATTENUATION_FANTOME,
		c.a * opacite_rendue(trace))


## La classe du fantôme : celle de l'instantané (`pN_weapon`), retenue quand l'instantané manque — l'arrêt
## sur image qui suit la lecture garde les fantômes montrés sans instantané.
func _classe_du_fantome(j: int, snap: Variant) -> Variant:
	var e: Dictionary = _etats_fantomes[j]
	if snap != null:
		var c = snap.get("p%d_weapon" % (j + 1))
		if c is ClassData:
			e["classe"] = c
	if e.has("classe"):
		return e["classe"]
	var joueur = _main.p1 if j == 0 else _main.p2
	return joueur.get("current_weapon") if is_instance_valid(joueur) else null


## ISO5 — le temps du rejeu, en secondes d'enregistrement (`ReplaySystem.RECORD_HZ`, 60) : il ralentit avec
## le ralenti, s'arrête pendant le pré-tracé et l'arrêt sur image. La marche et la respiration du fantôme
## battent à ce temps-là, comme ses gestes. Sans rejeu, le temps réel.
func horloge_du_rejeu() -> float:
	var rejeu := get_node_or_null(^"/root/ReplaySystem")
	return float(rejeu.get("playback_index")) / 60.0 if rejeu != null else Time.get_ticks_msec() / 1000.0


## L'état que `VoxelCorps.poser()` attend, pour le fantôme du joueur `j` — mêmes clés que `etat_du_corps`.
## Les événements se lisent d'un instantané à l'autre, à l'horloge du rejeu : un éclair de tir qui
## s'allume (`pN_flash`), des points de vie qui baissent (`pN_hp`), une posture qui bascule
## (`pN_accroupi`). La vitesse se déduit des positions rejouées. Jamais mort : un fantôme mort est caché.
func etat_du_fantome(j: int, fantome: Node2D, snap: Variant) -> Dictionary:
	var e: Dictionary = _etats_fantomes[j]
	var horloge := horloge_du_rejeu()
	var pos := fantome.global_position
	if snap != null:
		var n := "p%d_" % (j + 1)
		var hp := float(snap.get(n + "hp"))
		var flash := float(snap.get(n + "flash"))
		var accroupi := bool(snap.get(n + "accroupi"))
		if e.has("hp") and hp < float(e["hp"]) - 0.001:
			e["t_touche"] = horloge
		if flash > 0.0 and float(e.get("flash", 0.0)) <= 0.0:
			e["t_tir"] = horloge
		if e.has("accroupi") and accroupi != bool(e["accroupi"]):
			e["t_posture"] = horloge
		e["hp"] = hp
		e["flash"] = flash
		e["accroupi"] = accroupi
		e["torche"] = bool(snap.get(n + "light"))
	if not e.has("pos"):
		e["pos"] = pos
		e["horloge"] = horloge
		e["vitesse"] = Vector2.ZERO
	elif horloge > float(e["horloge"]) + 1e-6:
		e["vitesse"] = (pos - (e["pos"] as Vector2)) / (horloge - float(e["horloge"]))
		e["pos"] = pos
		e["horloge"] = horloge
	var tir := horloge - float(e.get("t_tir", -100.0)) < DUREE_TIR_CORPS
	var touche := horloge - float(e.get("t_touche", -100.0)) < DUREE_TOUCHE_CORPS
	var posture := horloge - float(e.get("t_posture", -100.0)) < VoxelCorps.DUREE_TRANSITION_ACCROUPI
	var t := horloge
	if tir or touche or posture:
		t = horloge - maxf(maxf(float(e["t_tir"]) if tir else -100.0,
			float(e["t_touche"]) if touche else -100.0), float(e["t_posture"]) if posture else -100.0)
	var visee := Vector2(cos(fantome.global_rotation), sin(fantome.global_rotation))
	var vitesse: Vector2 = e["vitesse"]
	var direction := vitesse.normalized() if vitesse.length() > 1.0 else visee
	return {
		"position": pos,
		"visee": visee,
		"vitesse": vitesse,
		"torche": bool(e.get("torche", false)),
		"arme": (_voxels[j] as VoxelCorps).slug(),
		"tir": tir, "touche": touche, "mort": false,
		"accroupi": bool(e.get("accroupi", false)),
		"enjambe": progres_enjambement(pos, direction, MursBas.murs_de_la_manche, false),
		"t": t,
	}


## Le progrès d'un enjambement, 0..1 — 0 hors de tout muret. Sur un muret (le cercle d'encombrement le
## chevauche : la règle de `player.gd`), la part parcourue du rectangle du muret élargi de ce rayon, le
## long de `direction` : l'entrée à 0, la sortie à 1. Poussé contre un muret sans y être monté
## (`pousse`), le geste commence. Fonction pure des positions : elle vaut pour le direct comme pour un
## rejeu.
const PROGRES_ENJAMBEMENT_MIN := 0.02


static func progres_enjambement(position: Vector2, direction: Vector2, murs: Array, pousse: bool) -> float:
	var d := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.DOWN
	for r: Rect2 in murs:
		if not MursBas.chevauche_cercle(position, MursBas.RAYON_ENCOMBREMENT, [r]):
			continue
		var g := r.grow(MursBas.RAYON_ENCOMBREMENT)
		var entree := -INF
		var sortie := INF
		for axe in 2:
			if absf(d[axe]) < 1e-6:
				continue
			var t1 := (g.position[axe] - position[axe]) / d[axe]
			var t2 := (g.end[axe] - position[axe]) / d[axe]
			entree = maxf(entree, minf(t1, t2))
			sortie = minf(sortie, maxf(t1, t2))
		if is_inf(entree) or is_inf(sortie) or sortie <= entree:
			return PROGRES_ENJAMBEMENT_MIN
		return clampf(-entree / (sortie - entree), PROGRES_ENJAMBEMENT_MIN, 1.0)
	return PROGRES_ENJAMBEMENT_MIN if pousse else 0.0


## L'opacité à laquelle la vue de dessus dessine, chez ce regardeur, le sprite que remplace ce corps :
## `visual` pour son propre corps, `visual_enemy` pour celui d'en face (brief d'Adrien, ISO2b).
##
## ⚠️ **Une seule source : le sprite.** La suie (`a_soi`, `a_autre`) et le brouillage du regardeur
## (`Brouillage.opacite`) sont écrits par `player.gd` sur ces sprites, à deux endroits et à deux
## moments de l'image ; les recalculer ici ferait une seconde règle qui dériverait de la première.
## On lit ce que la vue de dessus affiche : l'opacité RENDUE (`opacite_rendue`).
static func opacite_du_corps(joueur: Node, le_sien: bool) -> float:
	if joueur == null or not is_instance_valid(joueur):
		return 0.0
	return opacite_rendue(joueur.get("visual") if le_sien else joueur.get("visual_enemy"))


## L'opacité avec laquelle un `CanvasItem` se dessine : la sienne (`self_modulate`), fois celle de
## chacun de ses parents de canevas (`modulate` s'hérite) ; zéro s'il ou l'un d'eux est caché.
## ⚠️ Le sprite retiré de la lightmap par la vue iso l'est par sa COUCHE (`COUCHE_HORS_VUE`), pas par
## `visible` : son opacité reste celle que le jeu lui donne.
static func opacite_rendue(item: Variant) -> float:
	if not (item is CanvasItem) or not is_instance_valid(item):
		return 0.0
	var a := (item as CanvasItem).self_modulate.a
	var n: Node = item
	while n is CanvasItem:
		if not (n as CanvasItem).visible:
			return 0.0
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return clampf(a, 0.0, 1.0)


## La silhouette qui recouvre son propre corps, chez son propre joueur seulement (brief d'Adrien,
## ISO2b) : celle de la vue de dessus, `visual_dim` — sa couleur telle quelle, son opacité (0,5 dans
## `player.gd`) fois son opacité rendue. **Même valeur qu'en 2D, aucune constante neuve.** Pour la
## vue d'en face : transparente — la silhouette de J1 ne s'écrit jamais dans la vue de J2.
static func silhouette_du_corps(joueur: Node, le_sien: bool) -> Color:
	if not le_sien or joueur == null or not is_instance_valid(joueur):
		return Color(0.0, 0.0, 0.0, 0.0)
	var dim = joueur.get("visual_dim")
	if not (dim is Polygon2D):
		return Color(0.0, 0.0, 0.0, 0.0)
	var couleur: Color = (dim as Polygon2D).color
	return Color(couleur.r, couleur.g, couleur.b, couleur.a * opacite_rendue(dim))


## MIROIR processeur de la fin de `fragment()` dans `corps_grossier_iso.gdshader`, formule pour
## formule, en valeurs affichées comme la vue de dessus compose (sous `gl_compatibility`, le shader y
## travaille déjà — voir sa fin) : le corps éclairé à l'opacité `o` de son sprite,
## puis la silhouette (`silhouette.a`) par-dessus. Rend la couleur posée et, en alpha, l'opacité du
## fondu vers ce que la vue montre derrière le corps. Sert aux suites ; le shader ne l'appelle pas.
static func composer_corps(corps_srgb: Color, o: float, silhouette: Color) -> Color:
	var s := clampf(silhouette.a, 0.0, 1.0)
	var op := clampf(o, 0.0, 1.0)
	var a := 1.0 - (1.0 - op) * (1.0 - s)
	if a <= 0.0001:
		return Color(0.0, 0.0, 0.0, 0.0)
	var k := op * (1.0 - s)
	return Color((corps_srgb.r * k + silhouette.r * s) / a, (corps_srgb.g * k + silhouette.g * s) / a,
		(corps_srgb.b * k + silhouette.b * s) / a, a)


## Les capteurs vivants : `[vue_id][corps_id]` → nœud, pour les suites et F3.
func capteurs() -> Array:
	return _capteurs


# ---------------------------------------------------------------------------
# LES CAMÉRAS ET LES VUES 3D
# ---------------------------------------------------------------------------

func _poser_cameras() -> void:
	if _scinde:
		_camera.current = false
		for id in 2:
			_accorder_vue3d(id)
			_vues3d[id].render_target_update_mode = SubViewport.UPDATE_ALWAYS
			_affichages[id].visible = true
			_cameras3d[id].cull_mask = CALQUE_COMMUN | _calque_de(id)
			_cameras3d[id].current = true
		return
	var id := _id_de(_vues[0])
	for i in 2:
		_cameras3d[i].current = false
		_vues3d[i].render_target_update_mode = SubViewport.UPDATE_DISABLED
		_affichages[i].visible = false
	_camera.cull_mask = CALQUE_COMMUN | _calque_de(id)
	_camera.current = true


static func _calque_de(id: int) -> int:
	return CALQUE_VUE_1 if id == 0 else CALQUE_VUE_2


## La sous-vue 3D de `id` rend aux pixels de la fenêtre sur le cadre de son conteneur ;
## son aire 2D reste logique (les calques d'écran et le brouillage y vivent en unités
## logiques, comme dans la racine). Repose seulement ce qui a changé.
func _accorder_vue3d(id: int) -> void:
	var cadre := _cadre(id)
	var pixels := Vector2i((cadre.size * _etirement()).round())
	var vue := _vues3d[id]
	if vue.size != pixels:
		vue.size = pixels
	var logique := Vector2i(cadre.size.round())
	if vue.size_2d_override != logique:
		vue.size_2d_override = logique
		vue.size_2d_override_stretch = true
	var affichage := _affichages[id]
	if affichage.position != cadre.position or affichage.size != cadre.size:
		affichage.position = cadre.position
		affichage.size = cadre.size


# ---------------------------------------------------------------------------
# LES SPRITES
# ---------------------------------------------------------------------------

func _cacher_corps(joueur: Node) -> int:
	if not is_instance_valid(joueur):
		return 0
	var n := 0
	for nom in APPUIS_JOUEUR:
		var noeud := joueur.get(nom) as CanvasItem
		if noeud == null or noeud.visibility_layer == COUCHE_HORS_VUE:
			continue
		if not _couches.has(noeud):
			_couches[noeud] = noeud.visibility_layer
		noeud.visibility_layer = COUCHE_HORS_VUE
		n += 1
	return n


## Rend aux sprites leur couche d'origine — sauf si le jeu en a posé une autre entre
## temps, qui fait alors foi.
func _rendre_corps() -> void:
	for noeud in _couches:
		if is_instance_valid(noeud) and (noeud as CanvasItem).visibility_layer == COUCHE_HORS_VUE:
			(noeud as CanvasItem).visibility_layer = _couches[noeud]
	_couches.clear()


## Sort un sprite des lightmaps (couche 0), en retenant sa couche d'origine ; 1 s'il y était encore.
func _retirer_de_la_lightmap(item: CanvasItem) -> int:
	if item == null or item.visibility_layer == COUCHE_HORS_VUE:
		return 0
	if not _couches.has(item):
		_couches[item] = item.visibility_layer
	item.visibility_layer = COUCHE_HORS_VUE
	return 1


## La couche qu'avait un sprite avant que la vue iso ne le retire des lightmaps.
func couche_d_origine(item: Variant) -> int:
	if not is_instance_valid(item) or not (item is CanvasItem):
		return 0
	return int(_couches.get(item, (item as CanvasItem).visibility_layer))


## ISO5 — le sprite d'un fantôme (`VisualColored` et son pointeur) sort des lightmaps comme ceux des
## joueurs : sans cela il se dessinerait deux fois, debout en voxel et à plat sous lui.
func _cacher_le_fantome(fantome: Node2D) -> int:
	var trace := fantome.get_node_or_null(^"VisualColored") as CanvasItem
	if trace == null:
		return 0
	var n := _retirer_de_la_lightmap(trace)
	for enfant in trace.find_children("*", "CanvasItem", true, false):
		n += _retirer_de_la_lightmap(enfant as CanvasItem)
	return n


## ISO5 — **le voile de killcam lit l'image de la vue iso.** `killcam_overlay.gdshader` relit l'écran
## (`hint_screen_texture`) pour le réduire à trois tons, tirer ses contours et poser sa vignette. En vue
## de dessus il vit dans l'arène (`z_index` 2), sous les fantômes : il lit la sous-vue du duel. En iso,
## cette sous-vue est la lightmap projetée au sol — le voile n'y verrait ni les murs ni les corps, et
## sa vignette serait posée sur le sol, pas sur l'écran. Il sort donc des lightmaps, et un rectangle plein
## écran PARTAGEANT SON MATÉRIAU (les uniformes que `ui.gd` pousse — tension, négatif, curseur de grain —
## valent pour les deux) se pose dans la vue iso, sous tous les calques du jeu : l'habillage de la killcam
## (planche, estampe, bandeau, affiche) reste au-dessus, inchangé. Montré quand le voile 2D l'est.
func _accorder_le_voile_de_killcam() -> void:
	var interface = _main.get("ui")
	var voile_2d = interface.get("killcam_overlay") if interface != null else null
	if not is_instance_valid(voile_2d) or not (voile_2d is CanvasItem):
		return
	_retirer_de_la_lightmap(voile_2d)
	var montre := (voile_2d as CanvasItem).is_visible_in_tree()
	for id in 2:
		var regardee := _vue_de(id) != null
		var calque = _voiles[id]
		if calque == null and regardee and montre:
			calque = _creer_le_voile(id)
		if calque != null and is_instance_valid(calque):
			(calque as CanvasLayer).visible = regardee and montre
			((calque as Node).get_child(0) as CanvasItem).material = (voile_2d as CanvasItem).material


func _creer_le_voile(id: int) -> CanvasLayer:
	var calque := CanvasLayer.new()
	calque.name = "VoileKillcamIso%d" % (id + 1)
	calque.layer = CALQUE_VOILE_KILLCAM
	var rect := ColorRect.new()
	rect.name = "Voile"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(rect)
	# Vue unique : sous ce nœud de la racine, le calque s'attache à la fenêtre ; écran scindé : à la vue 3D.
	var parent: Node = _vues3d[id] if _scinde else self
	parent.add_child(calque)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voiles[id] = calque
	return calque


## Le voile de killcam iso de la vue `id`, pour les suites et le banc (`null` sans killcam).
func voile_de_killcam(id: int) -> CanvasLayer:
	var calque = _voiles[id]
	return calque if is_instance_valid(calque) else null


# ---------------------------------------------------------------------------
# F3
# ---------------------------------------------------------------------------

func _decrire(voulues: Array[SubViewport]) -> String:
	if not _mode_iso_voulu():
		return "désactivée"
	if _actif and not voulues.is_empty():
		var lignes: PackedStringArray = []
		lignes.append("%s · %s° · murs %s t · pâte %s · lightmap %s · %d bascule(s)"
			% ["scindé" if _scinde else "unique", str(_camera.tangage_deg),
			str(IsoGeometrie.hauteur_mur_haut()), IsoPate.NOMS[style_pate].get_slice(" ", 0),
			variante_lightmap(), bascules])
		for vue in _vues:
			var id := _id_de(vue)
			var rendu: Vector2i = _vues3d[id].size if _scinde else DisplayServer.window_get_size()
			# Le masque tel que le jeu l'a posé (`~4`, `~2`), les couches des capteurs dites à part :
			# `~12` ne se lirait pas.
			lignes.append("J%d : masque ~%d sans capteurs · lightmap %d×%d · rendu %d×%d · capteurs %s / %s"
				% [id + 1, (~vue.canvas_cull_mask & 0xFFFFFFFF) & ~COUCHES_CAPTEURS, vue.size.x, vue.size.y,
				rendu.x, rendu.y, _masque_texte(_capteurs[id][0]), _masque_texte(_capteurs[id][1])])
		return "\n".join(lignes)
	return "en attente du prochain duel"


static func _masque_texte(c) -> String:
	return str((c as CapteurCorps).masque_lumiere()) if c != null else "—"


# ---------------------------------------------------------------------------
# LA SCÈNE
# ---------------------------------------------------------------------------

func _construire_la_scene() -> void:
	_scene = Node3D.new()
	_scene.name = "SceneIso"
	_scene.visible = false
	add_child(_scene)
	# ISO4 — les objets debout, le leurre, la balle, le viseur et la ligne de visée.
	_miroirs = MiroirsIso.new()
	_scene.add_child(_miroirs)

	_camera = CameraIso.new()
	add_child(_camera)

	_mat_mur = _materiau(SHADER_MUR)
	_mat_mur.set_shader_parameter("pied", PIED_PX)
	# ISO7 — la matière et l'encre des murs viennent du catalogue (`iso_materiaux.gd`).
	IsoMateriaux.accorder_mur(_mat_mur)

	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE
	for id in 2:
		var mat := _materiau(SHADER_SOL)
		IsoMateriaux.accorder_sol(mat)
		_mat_sols.append(mat)
		var sol := MeshInstance3D.new()
		sol.name = "Sol%d" % (id + 1)
		sol.mesh = plan
		sol.material_override = mat
		sol.layers = _calque_de(id)
		sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scene.add_child(sol)
		_sols.append(sol)

	if corps_voxel:
		_construire_les_corps_voxel()
	else:
		var cylindre := CylinderMesh.new()
		cylindre.top_radius = RAYON_CORPS_PX
		cylindre.bottom_radius = RAYON_CORPS_PX
		cylindre.height = HAUTEUR_CORPS_PX
		var nez := BoxMesh.new()
		nez.size = Vector3(6.0, 6.0, 12.0)
		for i in 2:
			var mat := _materiau(SHADER_CORPS)
			mat.set_shader_parameter("gris", Charte.ADVERSAIRE)
			# Où le corps lit son capteur : chaque fragment à sa place dans le disque, jamais au-delà
			# de son bord adouci (voir `corps_grossier_iso.gdshader`).
			mat.set_shader_parameter("monde_capteur_px", CapteurCorps.MONDE_PX)
			mat.set_shader_parameter("rayon_lu_px", minf(RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0))
			_mat_corps.append(mat)
			# ISO2b — la profondeur d'abord (priorité -1), la couleur ensuite (0) : un seul fondu par pixel.
			var profondeur := ShaderMaterial.new()
			profondeur.shader = SHADER_CORPS_PROFONDEUR
			profondeur.render_priority = -1
			_mat_profondeur.append(profondeur)
			var corps := Node3D.new()
			corps.name = "Corps%d" % (i + 1)
			var pieces := [[cylindre, Vector3(0.0, HAUTEUR_CORPS_PX * 0.5, 0.0), "Tronc"],
				[nez, Vector3(0.0, HAUTEUR_CORPS_PX * 0.6, -(RAYON_CORPS_PX + 4.0)), "Nez"]]
			for piece in pieces:
				for passe in [[mat, ""], [profondeur, "Profondeur"]]:
					var mi := MeshInstance3D.new()
					mi.name = piece[2] + passe[1]
					mi.mesh = piece[0]
					mi.position = piece[1]
					mi.material_override = passe[0]
					mi.layers = CALQUE_COMMUN
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					corps.add_child(mi)
			_scene.add_child(corps)
			_corps.append(corps)

	# Les deux vues 3D de l'écran scindé. `own_world_3d` faux : elles rendent le
	# `World3D` de la racine, celui de `SceneIso` — murs et corps n'existent qu'une fois.
	# Chacune a son propre `World2D` (défaut d'une sous-vue), donc n'est jamais dans le
	# monde du duel : ni auditrice, ni lectrice de ses lumières.
	for id in 2:
		var vue := SubViewport.new()
		vue.name = "VueIso%d" % (id + 1)
		vue.own_world_3d = false
		vue.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vue.audio_listener_enable_2d = false
		vue.audio_listener_enable_3d = false
		vue.handle_input_locally = false
		vue.gui_disable_input = true
		add_child(vue)
		var cam := CameraIso.new()
		cam.name = "CameraIso%d" % (id + 1)
		cam.current = false
		vue.add_child(cam)
		var affichage := TextureRect.new()
		affichage.name = "AffichageIso%d" % (id + 1)
		affichage.texture = vue.get_texture()
		affichage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		affichage.stretch_mode = TextureRect.STRETCH_SCALE
		affichage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		affichage.visible = false
		add_child(affichage)
		_vues3d.append(vue)
		_cameras3d.append(cam)
		_affichages.append(affichage)


func _construire_les_murs() -> void:
	if _murs != null:
		_scene.remove_child(_murs)
		_murs.queue_free()
	var cartes := get_node_or_null(^"/root/MapData")
	var data: Dictionary = cartes.get_selected() if cartes != null else {}
	_murs = IsoGeometrie.build_meshes(data, _mat_mur)
	# ISO7 — la grille des murs de CETTE carte : l'encre et le liseré ne tombent que sur les vrais bords.
	IsoMateriaux.accorder_grille(_mat_mur, data)
	for boite in _murs.get_children():
		(boite as MeshInstance3D).layers = CALQUE_COMMUN
	_scene.add_child(_murs)
	_reconstruire = false


## Un matériau par shader PRÉCHARGÉ : aucun `Shader.new()` à la volée, qui compilerait
## au premier affichage (piège consigné — le hoquet tombe sur l'action).
func _materiau(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("style", style_pate)
	return m


func _materiaux() -> Array[ShaderMaterial]:
	var tous: Array[ShaderMaterial] = [_mat_mur]
	tous.append_array(_mat_sols)
	tous.append_array(_mat_corps)
	return tous


# ---------------------------------------------------------------------------
# ENTRÉES — la pâte à chaud, la visée souris
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _actif:
		return
	var touche := event as InputEventKey
	if touche != null and touche.pressed and not touche.echo:
		var choisie := -2
		if TOUCHES_DIRECTES.has(touche.physical_keycode):
			choisie = TOUCHES_DIRECTES[touche.physical_keycode]
		elif touche.physical_keycode == TOUCHE_PATE or touche.keycode == TOUCHE_PATE:
			# A → B → C → D → brute → A
			choisie = IsoPate.BRUTE if style_pate == IsoPate.LAVIS else \
				(IsoPate.GRAVURE if style_pate == IsoPate.BRUTE else style_pate + 1)
		if choisie >= IsoPate.BRUTE:
			style_pate = choisie
			print("[iso] pâte %s" % IsoPate.NOMS[style_pate])
			get_viewport().set_input_as_handled()
			return


## ISO5 — 0 pour J1, 1 pour J2, -1 pour tout autre nœud.
func indice_du_joueur(joueur: Node) -> int:
	if not is_instance_valid(_main) or joueur == null:
		return -1
	return 0 if joueur == _main.p1 else (1 if joueur == _main.p2 else -1)


## ISO5 — **le point du SOL sous le curseur, dans la vue de ce joueur** : le rayon de sa caméra iso coupé
## par le plan du sol, rendu en pixels du monde 2D (`CameraIso.vers_sol`, l'inverse exact de
## `vers_ecran`). `souris_racine` : la position de la souris en unités logiques de la fenêtre. En écran
## scindé, chaque joueur vise par sa propre caméra, dans son propre cadre. `null` quand la vue iso ne rend
## pas ce joueur : `LocalInputProvider` garde alors la visée de la vue de dessus.
##
## Remplace le brouillon d'ISO1 (`_viser_a_la_souris`), qui poussait un événement souris reprojeté dans
## la sous-vue de J1 seul : en écran scindé, la souris ne visait jamais par la vue de J2.
func point_au_sol(joueur: Node, souris_racine: Vector2) -> Variant:
	var pid := indice_du_joueur(joueur)
	if pid < 0:
		return null
	var cam := _camera_de(pid)
	var ecran := viewport_ecran(pid)
	if cam == null or ecran == null:
		return null
	var pos := souris_racine - (_cadre(pid).position if _scinde else Vector2.ZERO)
	return cam.vers_sol(pos, ecran.get_visible_rect().size)


## ISO5 — le stick de visée tourné du lacet de la caméra de ce joueur : pousser vers le haut vise vers le
## haut de SON écran. Lacet acté à 0° (H15) : sans effet, prouvé par `tools/test_iso_killcam.gd`.
func stick_au_sol(joueur: Node, stick: Vector2) -> Vector2:
	var pid := indice_du_joueur(joueur)
	var cam := _camera_de(pid) if pid >= 0 else null
	return CameraIso.stick_au_sol(stick, cam.lacet_deg) if cam != null else stick
