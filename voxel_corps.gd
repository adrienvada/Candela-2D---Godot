class_name VoxelCorps
extends Node3D

## Un corps voxel — chantier ISO, étape ISO3, vague 0 (iso-corps).
##
## ## Ce que ce nœud fait, et rien de plus
##
## `construire(slug)` bâtit neuf `BoxMesh` (tête, torse, deux bras, deux
## jambes, arme, torche, gadget) depuis `VoxelCatalogue.fiche(slug)`, avec un
## `Node3D` pivot par membre (jambes, torse, tête, bras). `poser(etat)` est
## l'unique entrée de mouvement, et c'est une **fonction pure** de `etat` : à
## état égal, pose égale, sur les deux machines et dans la killcam. Le temps
## n'entre que par `etat.t` — jamais `Time.get_ticks_msec()`, jamais `randf()`.
## Ce nœud ne lit ni la carte, ni le réseau, ni aucun autre corps.
##
## ## Le repère
##
## Origine au pied, `+Y` vers le haut, `-Z` l'avant du corps (même convention
## que `tools/proto_iso.gd` : `Basis.looking_at(direction, Vector3.UP)`).
## `etat.position` et `etat.vitesse` sont en PIXELS, comme partout ailleurs
## dans le jeu (`player.gd`) — la conversion en tuiles se fait ici, une seule
## fois, par `CandelaTileSet.TILE_SIZE.x`.
##
## ## Les couches d'animation, superposées et non exclusives
##
## `mort` domine tout le reste (un corps qui tombe ne marche ni ne respire).
## `enjambe > 0` domine tout sauf `mort` : on n'enjambe pas accroupi, la
## description du geste (ISO3 vague 1) est sans ambiguïté « debout ». Sinon :
## la charpente suit `marche` ou `repos` selon `vitesse`, `accroupi` abaisse et
## penche la même charpente par-dessus (voir plus bas) ; `tir` ajoute un recul
## sur l'arme SEULE, par-dessus quoi que fasse le reste du corps ; `touche`
## ajoute une secousse au torse. Un joueur qui encaisse en marchant continue
## donc de marcher, secoué — ce que la description en liste séparée de la
## commande laissait ambigu, et que la superposition rend possible sans état
## caché.
##
## ## Accroupi — une charpente abaissée, pas une seconde charpente
##
## Une seule jambe rigide par côté (vague 0) ne peut pas plier un genou : il
## n'y a pas de second joint. L'accroupi est donc un TRUCAGE assumé, à trois
## gestes combinés plutôt qu'une articulation : la hanche (pivots des jambes
## ET du torse) descend, les jambes basculent vers l'avant en se raccourcissant
## (`scale.y`, pour que le pied reste proche du sol plutôt que de le traverser),
## le torse penche et la tête se rentre par-dessus. Les quatre gestes sont
## pilotés par un seul facteur 0..1 (`_facteur_accroupi`), lui-même une
## fonction pure de `etat.accroupi` (bool) et de `etat.t` — le temps depuis le
## dernier changement de posture, MÊME convention que `tir`/`touche` : à la
## bascule, l'appelant remet `t` à zéro. Passé `DUREE_TRANSITION_ACCROUPI`
## (150 ms, la limite qu'Adrien a posée), le facteur reste figé à 0 ou 1 quel
## que soit `t` — comme `_poser_mort` se fige après son dernier palier.
##
## ## Enjambement — un flottant qui vient du jeu, pas une horloge
##
## `etat.enjambe` (0..1, 0 = pas d'enjambement) est fourni DÉJÀ AVANCÉ par
## l'appelant — contrairement à `tir`/`touche`/`accroupi`, ce nœud ne le
## dérive pas de `t`. La jambe qui enjambe (toujours la même, la droite)
## balaie d'un angle négatif (arrière) à positif (avant) sur tout l'intervalle
## et se soulève au milieu du geste ; le déplacement d'une tuile pendant que le
## paramètre va de 0 à 1 est à la charge de l'appelant (`etat.position`),
## jamais recalculé ici.
##
## ## Le geste de gadget (ISO4, finition)
##
## Un geste PAR CLASSE, pas un seul partagé (vague 0 partageait le bob du
## torse, signalé pour ISO4 — voir `GESTES_GADGET`) : une rotation continue,
## pure de `t`, superposée à ce bob, tirée du comportement réel de chaque
## gadget (son propre fichier `gadget_*.gd`, lu avant de choisir la forme du
## geste) — un tressautement électrique pour le grésillement, un lacet ample
## pour la torche fantôme, un flottement à deux axes pour le voile, une quasi-
## immobilité pour le leurre, l'ombre habitée et la mine (qui ne trahissent
## rien avant d'être posés), etc. Détail par classe : voir `GESTES_GADGET`.
##
## ## Ce que ce nœud NE fait PAS
##
## Aucune lumière : `lumiere_recue` est un simple curseur (`definir_lumiere`),
## que le banc pilote et qu'ISO2 alimentera depuis la lightmap 2D. Aucun
## `Light3D`. Aucune dépendance à `tools/proto_iso.gd` — même convention de
## repère, code indépendant.

const VoxelCatalogueT := preload("res://voxel_catalogue.gd")
const ShaderCorpsIso := preload("res://corps_iso.gdshader")
const ShaderCorpsIsoProfondeur := preload("res://corps_iso_profondeur.gdshader")
const IsoPateT := preload("res://iso_pate.gd")

## Le style par défaut d'un corps neuf — LAVIS, pas GRAVURE (0). Choix trouvé
## au banc (`--capteur`), pas deviné : GRAVURE hachure sur une période de 6
## unités-monde, la même que pour un mur ou un sol continus sur plusieurs
## tuiles ; un corps tient sur une fraction de tuile, plus petit que la
## période elle-même, si bien qu'il tombe presque entièrement DANS ou HORS
## d'un trait selon sa seule position sur la grille — un corps clair et son
## voisin identique à une tuile de distance peuvent apparaître l'un plein,
## l'autre quasi noir, sans rapport avec la lumière reçue. LAVIS est le style
## qu'Adrien a jugé « parfait » sur le corps grossier d'ISO2 au jalon H-ISO2
## (`PATE_PAR_DEFAUT` dans `presentation_3d.gd`) — repris ici pour la même
## raison, pas réinventé. `definir_style()` reste le point d'entrée pour qui
## veut trancher autrement (jalon H-ISO1, planche).
const STYLE_PAR_DEFAUT := IsoPateT.LAVIS

# --- Geste de gadget (ISO4, finition) ---------------------------------------
#
# Vague 0 partageait un seul geste entre les dix classes (le gadget suivait
# le bob du torse, rien de plus — « signalé pour ISO4 »). Chaque classe a
# maintenant SON geste, une rotation continue et pure de `t` superposée à ce
# bob — jamais une position ou une vitesse devinées, jamais `randf`. Chaque
# entrée est tirée du comportement RÉEL du gadget porté (son fichier `gadget_*.gd`
# lu avant de choisir la forme du geste, pas un style générique posé au hasard) :
#
#   - `gresillement` (pistolet) : un tressautement rapide et irrégulier — le
#     gadget lui-même « fait sauter les lampes torches autour d'elle » par un
#     bruit de coupure déterministe (`niveau_noir`, `CRENEAU`) ; deux
#     harmoniques proches en fréquence pour un tic électrique, jamais un
#     balancement propre.
#   - `leurre` (fusil) : presque immobile — le gadget déployé « ne bouge pas,
#     n'éclaire pas » (`gadget_leurre.gd`), porté il ne devrait pas trahir
#     plus de vie que posé.
#   - `poussiere` (pompe) : un roulis lent et large — une nappe fine qui
#     « on voit à travers, on ne voit pas loin », portée comme un nuage.
#   - `torche_fantome` (arbalète) : un lacet lent, plus ample que les autres —
#     un rappel du balayage du faisceau qu'elle joue une fois posée
#     (`AMPLITUDE` du fichier réel, réduite ici à l'échelle d'un geste porté).
#   - `cartouche_suie` (fumiste) : un roulis lent et resserré — dense et
#     petite, elle bouge moins que la poussière qu'elle masque plus qu'elle
#     ne dissipe.
#   - `nappe_braises` (incendiaire) : un tressaillement rapide sur deux
#     harmoniques proches, la chaleur d'un foyer porté contre le dos.
#   - `poudre_contact` (sentinelle) : un tangage très lent — un sablier
#     porté, jamais secoué (elle ne doit rien laisser paraître avant d'être
#     posée).
#   - `ombre_habitee` (occulteur) : quasiment immobile — une plaque d'acier
#     lourde, dont tout l'effet tient à rester parfaitement immobile une fois
#     montée.
#   - `mine_magnesium` (allumeur) : quasiment immobile — « aucune veilleuse,
#     aucun témoin lumineux visible » tant qu'elle n'est pas déclenchée
#     (`gadget_mine.gd`), portée comme posée.
#   - `voile` (spectre) : un flottement à deux axes — la toile qui ondule une
#     fois tendue (`ONDULATION`, `PERIODE_ONDULATION` du fichier réel).
#
# Chaque terme : `axe` (Vector3 normalisé, l'axe de rotation local du
# gadget), `amplitude` (rad), `freq` (Hz, cycles de `t` par seconde),
# `phase` (rad, optionnel, défaut 0 — sépare les harmoniques d'un même
# geste). Sommés terme à terme, jamais moyennés.
const GESTES_GADGET := {
	"gresillement": [
		{"axe": Vector3.UP, "amplitude": 0.05, "freq": 9.0},
		{"axe": Vector3.UP, "amplitude": 0.025, "freq": 20.7, "phase": 1.3},
	],
	"leurre": [
		{"axe": Vector3.RIGHT, "amplitude": 0.01, "freq": 0.2},
	],
	"poussiere": [
		{"axe": Vector3.RIGHT, "amplitude": 0.05, "freq": 0.35},
	],
	"torche_fantome": [
		{"axe": Vector3.UP, "amplitude": 0.15, "freq": 0.25},
	],
	"cartouche_suie": [
		{"axe": Vector3.RIGHT, "amplitude": 0.04, "freq": 0.22},
	],
	"nappe_braises": [
		{"axe": Vector3.RIGHT, "amplitude": 0.05, "freq": 5.0},
		{"axe": Vector3.RIGHT, "amplitude": 0.02, "freq": 12.1, "phase": 0.6},
	],
	"poudre_contact": [
		{"axe": Vector3.RIGHT, "amplitude": 0.03, "freq": 0.15},
	],
	"ombre_habitee": [
		{"axe": Vector3.RIGHT, "amplitude": 0.02, "freq": 0.12},
	],
	"mine_magnesium": [
		{"axe": Vector3.RIGHT, "amplitude": 0.01, "freq": 0.2},
	],
	"voile": [
		{"axe": Vector3.UP, "amplitude": 0.08, "freq": 0.4},
		{"axe": Vector3.RIGHT, "amplitude": 0.05, "freq": 0.55, "phase": 1.1},
	],
}

# --- Respiration (repos) ----------------------------------------------------
const FREQ_RESPIRATION := 0.55       # cycles/s
const AMPL_RESPIRATION := 0.012      # tuiles

# --- Marche ------------------------------------------------------------------
# Esthétique, volontairement PAS lue dans `player.gd` : ce corps n'a aucune
# dépendance au fichier du jeu, contrairement à `tools/banc_marche.gd` qui,
# lui, doit rester fidèle à la cadence réelle des pas sonores.
#
# ⚠️ **Une première version cadençait à ~5,5 foulées par seconde** (`LONGUEUR_PAS`
# trop court face à la vitesse du banc) — une course de dessin animé, pas des
# gens qui cherchent à ne pas faire de bruit. Adrien l'a vu au banc et l'a dit
# en ces termes le 2026-09-14. `LONGUEUR_PAS` est monté et les amplitudes
# resserrées : à la vitesse du banc, la foulée tombe autour de 1 Hz (deux pas
# par seconde), un pas posé et non une foulée sprintée.
const LONGUEUR_PAS := 6.0            # tuiles par foulée complète
const AMPLITUDE_JAMBE := 0.26        # rad (~15°)
const AMPLITUDE_BRAS := 0.14         # rad (~8°)
const GARDE_BRAS := 0.14             # rad — légèrement relevés au repos comme en marche

# --- Tir : recul de l'arme seule ---------------------------------------------
const T_MONTEE_RECUL := 0.02
const DUREE_RECUL := 0.12
const RECUL_MAX := 0.05              # tuiles

# --- Touché : secousse du torse ----------------------------------------------
const OMEGA_SECOUSSE := 40.0
const DECAY_SECOUSSE := 14.0
const AMPL_SECOUSSE := 0.17          # rad (~10°)

# --- Mort : trois poses puis couché ------------------------------------------
const TEMPS_CHUTE := [0.0, 0.15, 0.35, 0.55]
const ANGLES_CHUTE_DEG := [0.0, -22.0, -50.0, -90.0]

# --- Accroupi (ISO3 vague 1) --------------------------------------------------
# Cible choisie et VÉRIFIÉE par calcul (voir le commentaire de classe) : au
# sommet de la tête, ≈ 0,57 de la hauteur debout (0,94 tuile) — au milieu de
# la fourchette 0,5-0,6 posée par le brief, avec de la marge des deux côtés
# pour que les dix classes (gabarits légèrement différents via `echelle`, qui
# ne joue que sur la largeur — voir `_construire_squelette`) y tiennent toutes.
const DUREE_TRANSITION_ACCROUPI := 0.15   # 150 ms — la limite posée par Adrien
const FACTEUR_LONGUEUR_JAMBE_ACCROUPI := 0.5
const ANGLE_JAMBE_ACCROUPI := 0.6981      # rad (40°) — bascule avant, pivot hanche
const ANGLE_TORSE_ACCROUPI := 0.6109      # rad (35°) — buste penché
const ANGLE_TETE_ACCROUPI_SUPPL := 0.3491 # rad (20°) — tête rentrée, EN PLUS du buste

# --- Enjambement (ISO3 vague 1) -----------------------------------------------
const ANGLE_ENJAMBE_MAX := 1.2217         # rad (70°) — amplitude totale de la jambe
const LEVEE_ENJAMBE := 0.15               # tuiles — décollement du pied au milieu du geste
const ANGLE_ARME_BAISSEE := 0.9           # rad (~52°) — canon vers le bas, on ne tire pas
const SEUIL_ARME_BAISSEE := 0.1           # l'arme est baissée dès ce niveau d'enjambement

var _fiche: Dictionary = {}
var _materiau: ShaderMaterial
var _materiau_profondeur: ShaderMaterial
var _nombre_de_boites: int = 0
var _boites_visibles: Array = []

var _jambe_g: Node3D
var _jambe_d: Node3D
var _jambe_g_mesh: MeshInstance3D
var _jambe_d_mesh: MeshInstance3D
var _torse: Node3D
var _tete_pivot: Node3D
var _tete_mesh: MeshInstance3D
var _bras_g: Node3D
var _bras_d: Node3D
var _arme_pivot: Node3D
var _arme_mesh: MeshInstance3D
var _torche_pivot: Node3D
var _torche_mesh: MeshInstance3D
var _torche_pos_base: Vector3 = Vector3.ZERO
var _gadget_pivot: Node3D

var _torse_y_base: float = 0.0
var _arme_pos_base: Vector3 = Vector3.ZERO
var _gadget_pos_base: Vector3 = Vector3.ZERO
var _h_jambe_base: float = 0.0
var _hanche_accroupi_y: float = 0.0


## Bâtit le corps depuis `VoxelCatalogue.fiche(slug, epaisseur)`. Rend `false`
## (et laisse le catalogue crier) si le slug OU `epaisseur` est inconnu.
## Idempotent : un second appel reconstruit proprement, comme
## `proto_iso.gd:construire()`. `epaisseur` (ISO3 vague 4, voir
## `VoxelCatalogue.EPAISSEUR_REGLAGES`) : par défaut le nouveau gabarit épais
## — tout appelant déjà écrit (ISO2/ISO5, les bancs, la suite) le reçoit sans
## changer une ligne. `"leger"` retrouve l'ancien gabarit (vague 0-3).
func construire(slug: String, epaisseur: String = VoxelCatalogueT.EPAISSEUR_PAR_DEFAUT) -> bool:
	_vider()
	var f := VoxelCatalogueT.fiche(slug, epaisseur)
	if f.is_empty():
		return false
	_fiche = f

	_materiau = ShaderMaterial.new()
	_materiau.shader = ShaderCorpsIso
	_materiau.set_shader_parameter("couleur_fiche", f["couleur"])
	_materiau.set_shader_parameter("lumiere_recue", 0.0)
	_materiau.set_shader_parameter("style", STYLE_PAR_DEFAUT)
	_materiau.set_shader_parameter("capteur_actif", false)
	_materiau.set_shader_parameter("centre", Vector2.ZERO)
	_materiau.set_shader_parameter("monde_capteur_px", 128.0)
	_materiau.set_shader_parameter("rayon_lu_px", 15.0)
	_materiau.set_shader_parameter("echelle_lecture", 1.0)
	_materiau.set_shader_parameter("lecture_au_bord", 0.0)
	_materiau.set_shader_parameter("pixels_par_unite", 1.0)
	_materiau.set_shader_parameter("opacite_1", 1.0)
	_materiau.set_shader_parameter("opacite_2", 1.0)
	_materiau.set_shader_parameter("silhouette_1", Color(0.0, 0.0, 0.0, 0.0))
	_materiau.set_shader_parameter("silhouette_2", Color(0.0, 0.0, 0.0, 0.0))

	# Le double en profondeur seule — voir « La passe de profondeur » dans
	# l'en-tête de `corps_iso.gdshader`. Mêmes opacite_N/silhouette_N, tenus
	# synchronisés par tous les setters ci-dessous : jamais réglé une fois et
	# oublié, sans quoi les deux passes divergeraient en silence.
	_materiau_profondeur = ShaderMaterial.new()
	_materiau_profondeur.shader = ShaderCorpsIsoProfondeur
	# `render_priority` est une propriété de `Material`, pas du `MeshInstance3D` qui le
	# porte (erreur trouvée à cette étape : la poser sur le nœud lève une erreur de script,
	# silencieuse pour le reste de la suite). Une fois ici suffit : `material_override`
	# partage la même ressource sur les neuf boîtes de ce corps (voir `_boite`).
	_materiau_profondeur.render_priority = -1
	_materiau_profondeur.set_shader_parameter("opacite_1", 1.0)
	_materiau_profondeur.set_shader_parameter("opacite_2", 1.0)
	_materiau_profondeur.set_shader_parameter("silhouette_1", Color(0.0, 0.0, 0.0, 0.0))
	_materiau_profondeur.set_shader_parameter("silhouette_2", Color(0.0, 0.0, 0.0, 0.0))

	_construire_squelette()
	if VoxelCatalogueT.portraits_actifs():
		_habiller_en_portrait(slug)

	# Pose de référence : de face, immobile — un corps fraîchement construit
	# n'est jamais dans un état indéfini avant le premier `poser()` de l'appelant.
	poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": true, "arme": slug, "tir": false, "touche": false,
		"mort": false, "t": 0.0,
	})
	return true


func slug() -> String:
	return String(_fiche.get("slug", ""))


## Le gris plafonné de cette classe (`VoxelCatalogue.fiche()`) — exposé pour
## qui veut composer une silhouette de soi à sa propre couleur, comme le banc.
func couleur() -> Color:
	return _fiche.get("couleur", Color.WHITE)


func nombre_de_boites() -> int:
	return _nombre_de_boites


## Exposé pour le banc et la suite : lire `lumiere_recue` sans rendre une
## image, et le régler depuis le curseur du banc.
func materiau() -> ShaderMaterial:
	return _materiau


## Le double en profondeur seule — voir « La passe de profondeur » dans
## l'en-tête de `corps_iso.gdshader`. Exposé pour la suite, qui vérifie que ses
## `opacite_N`/`silhouette_N` restent synchronisés avec `materiau()`.
func materiau_profondeur() -> ShaderMaterial:
	return _materiau_profondeur


## Les neuf `MeshInstance3D` visibles (jamais leurs doubles en profondeur) —
## exposé pour ISO3a si sa présentation a besoin d'en faire autre chose
## (calques, masques de caméra) que ce que ce nœud gère déjà lui-même.
func boites() -> Array:
	return _boites_visibles.duplicate()


func definir_lumiere(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("lumiere_recue", clampf(v, 0.0, 1.0))


## Branche un capteur (ISO2, `CapteurCorps`) : mêmes noms et mêmes unités que
## `corps_grossier_iso.gdshader` (commit `02f6c28`) — `centre` en PIXELS 2D,
## posé à chaque image, `monde_capteur_px`/`rayon_lu_px` = `CapteurCorps.MONDE_PX`/
## un rayon de lecture proche de `RAYON_PX`. `texture_2` peut rester nulle : ce
## nœud, seul, n'a pas de second joueur à distinguer, et le shader retombe sur
## `texture_1` des deux côtés (voir `pixels_par_unite` pour le pont
## tuiles/pixels). `lumiere_recue` reste réglable pendant ce temps, mais le
## shader l'ignore tant que le capteur est actif.
func definir_capteur(texture_1: Texture2D, centre: Vector2, monde_capteur_px: float = 128.0,
		rayon_lu_px: float = 15.0, texture_2: Texture2D = null) -> void:
	if _materiau == null:
		return
	_materiau.set_shader_parameter("capteur_1", texture_1)
	_materiau.set_shader_parameter("capteur_2", texture_2 if texture_2 != null else texture_1)
	_materiau.set_shader_parameter("centre", centre)
	_materiau.set_shader_parameter("monde_capteur_px", monde_capteur_px)
	_materiau.set_shader_parameter("rayon_lu_px", rayon_lu_px)
	_materiau.set_shader_parameter("capteur_actif", texture_1 != null)


## Retombe sur `lumiere_recue` (le repli scalaire de vague 0/1).
func effacer_capteur() -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("capteur_actif", false)


## Le pont entre le repère de CE nœud (tuiles) et celui du capteur (pixels 2D) —
## voir `pixels_par_unite` dans `corps_iso.gdshader`. ISO3a, qui accrochera ce
## corps sous un `Node3D` déjà à l'échelle des pixels, laissera la valeur par
## défaut (1.0, l'identité) ; ce banc pose 35.0 (`CandelaTileSet.TILE_SIZE.x`).
func definir_pixels_par_unite(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("pixels_par_unite", v)


## Dilate le DÉCALAGE lu sur le disque du capteur (voir l'en-tête de
## `corps_iso.gdshader`) — identité à 1.0, jamais devinée ici. Trouvée par ISO2
## au banc du jeu réel (ISO3a) : la rétrodiffusion qui trahit le porteur sous
## sa propre torche vit dans un anneau étroit du disque (le torse l'arrête),
## et un corps voxel, plus étroit que le corps grossier d'ISO2, reste entier
## dans l'ombre de son propre torse sans cette dilatation — un écart
## d'équité, pas un défaut du shader. L'appelant la règle d'après le rapport
## entre le rayon réellement éclairé et le demi-encombrement au sol de SON
## corps ; ce nœud ne le devine jamais lui-même.
func definir_echelle_lecture(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("echelle_lecture", v)


## 0..1 — voir `lecture_au_bord` dans l'en-tête du shader : `echelle_lecture`
## seule ne suffisait pas (trouvé par ISO2 au banc du jeu réel, ISO3a) — à 0
## (le défaut), rien ne change ici ; c'est la présentation du jeu qui règle
## 1.0, jamais ce banc.
func definir_lecture_au_bord(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("lecture_au_bord", clampf(v, 0.0, 1.0))


## 0..1 — voir « Effacement » dans l'en-tête du shader : une vraie
## transparence, jamais un assombrissement. `vue` : 0 règle les deux vues (le
## cas courant, un seul joueur regardé au banc), 1 ou 2 une seule — utile pour
## la suite et pour qui veut driver les deux vues séparément avant qu'ISO3a
## n'existe.
func definir_opacite(o: float, vue: int = 0) -> void:
	var v := clampf(o, 0.0, 1.0)
	for mat in [_materiau, _materiau_profondeur]:
		if mat == null:
			continue
		if vue != 2:
			mat.set_shader_parameter("opacite_1", v)
		if vue != 1:
			mat.set_shader_parameter("opacite_2", v)


## `couleur`/`alpha` — voir « Effacement et silhouette » dans l'en-tête du
## shader : la même chose que `visual_dim` empilé sur le sprite en vue de
## dessus, chez son propre joueur (alpha à 0 ailleurs). Même `vue` que
## `definir_opacite`.
func definir_silhouette(couleur: Color, alpha: float, vue: int = 0) -> void:
	var c := Color(couleur.r, couleur.g, couleur.b, clampf(alpha, 0.0, 1.0))
	for mat in [_materiau, _materiau_profondeur]:
		if mat == null:
			continue
		if vue != 2:
			mat.set_shader_parameter("silhouette_1", c)
		if vue != 1:
			mat.set_shader_parameter("silhouette_2", c)


## Réservé jusqu'ici (ISO1 choisit la pâte sur planche) ; câblé pour de bon en
## vague 2 — voir `iso_pate.gdshaderinc` pour les quatre valeurs et `-1` (brute).
func definir_style(s: int) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("style", s)


## ISO3 vague 5 — l'encre des arêtes (contrat d'« ISO7 Beauté Opus »,
## `pate_encre_boite()` dans `iso_pate.gdshaderinc`). `largeur` en unités de ce
## nœud (tuiles ici, pixels sous l'ancre de Presentation3D) — 0.0 (le défaut du
## shader) n'a aucun effet. `reste` : la valeur du facteur SUR le trait, dans
## [0, 1]. Ne pose rien sur `materiau_profondeur()` : la passe de profondeur
## n'écrit aucune couleur, `corps_iso_profondeur.gdshader` n'a pas cet uniform.
func definir_encre(largeur: float, reste: float = 0.35) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("encre_arete", largeur)
		_materiau.set_shader_parameter("encre_reste", clampf(reste, 0.0, 1.0))


## Le Y global du sommet de la tête — la mesure que le brief ISO3 vague 1
## demande pour juger la pose accroupie (« mesure-le sur la planche »).
## Recalculée depuis le maillage réel, jamais depuis une constante : c'est la
## même discipline que `test_proto_iso.gd` (« les comptes sont refaits ici »).
func sommet_tete() -> float:
	var aabb := _tete_mesh.get_aabb()
	return _tete_mesh.to_global(Vector3(0.0, aabb.position.y + aabb.size.y, 0.0)).y


## ISO3 vague 5 — la bouche de l'arme, pour « ISO7 Gadgets et lumière Opus »
## (le flash de bouche en iso a besoin d'un point et d'une direction, il ne
## les invente pas). Recalculée depuis le maillage réel de l'arme, jamais
## depuis une constante — même discipline que `sommet_tete()`/`rayon_empreinte()` :
## la bouche suit la pose courante (recul du tir, bras baissé à l'enjambement,
## contre-rotation de l'accroupi), qu'on l'appelle avant ou après `poser()`
## n'a d'importance que pour savoir QUELLE pose elle décrit.
##
## Repère GLOBAL de ce nœud (tuiles, même convention que `sommet_tete()`),
## PAS le repère local de l'arme : un appelant qui place un effet dans la
## même scène 3D n'a rien à recomposer. `direction` est le vecteur unitaire
## vers l'avant du canon (`Basis.FORWARD` de l'arme, donc de la visée du
## corps une fois `visee` posée par `poser()`).
##
## Dictionnaire vide si aucune arme n'est construite ou si `_arme_mesh` est
## invisible (`arme_slug == ""`, voir `poser()`) — jamais une position
## inventée à l'origine du corps, qui laisserait un appelant croire à une
## arme absente qu'elle tire depuis les pieds.
func pointe_arme() -> Dictionary:
	if _arme_mesh == null or not _arme_mesh.visible or _fiche.is_empty():
		return {}
	var fa: Dictionary = _fiche.get("arme", {})
	var longueur: float = float(fa.get("longueur", 0.0))
	var pointe_locale := Vector3(0.0, 0.0, -longueur)
	return {
		"position": _arme_pivot.to_global(pointe_locale),
		"direction": (_arme_pivot.global_transform.basis * Vector3.FORWARD).normalized(),
	}


## ISO3 vague 4 — l'empreinte au sol RÉELLE de la pose courante : la plus
## grande distance, en tuiles, entre l'origine du corps et un coin de l'une
## de ses boîtes, projetée sur le plan XZ. Recalculée depuis le maillage réel
## via `global_transform` (donc juste même quand une jambe ou le torse est
## en rotation — marche, accroupi, enjambement), jamais depuis `rayon_corps`
## seul : la décision d'Adrien (« tant pis si ça touche leur hitbox »)
## remplace le contrat fixe de la vague 0 par cette mesure, posture par
## posture — voir `tools/test_voxel_corps.gd` et la ROADMAP, section
## « Vague 4 », pour le tableau complet.
##
## `corps_seul` (par défaut faux, les neuf boîtes) : vrai exclut l'arme, la
## torche et le gadget — ce que la règle du couloir d'une tuile borne, c'est
## le VOLUME DU CORPS qui grossit avec l'épaisseur (torse, tête, bras,
## jambes), jamais la portée d'une arme tenue en avant, qui ne dépend pas de
## l'épaisseur et existait déjà, telle quelle, en vague 0. Les deux mesures
## servent des questions différentes : `corps_seul = true` pour « un corps
## passe-t-il un couloir d'une tuile ? », `corps_seul = false` (l'ensemble,
## ce que la vue de dessus montre et ce qu'une balle peut toucher) pour le
## rayon à publier à ISO5 pour `bullet.gd:PLAYER_BODY_RADIUS`.
func rayon_empreinte(corps_seul: bool = false) -> float:
	var origine: Vector3 = global_transform.origin
	var r := 0.0
	for b in _boites_visibles:
		var inst: MeshInstance3D = b
		if corps_seul:
			var parent: Node = inst.get_parent()
			var nom_parent: String = String(parent.name) if parent != null else ""
			if nom_parent == "Arme" or nom_parent == "Torche" or nom_parent == "Gadget":
				continue
		var box: BoxMesh = inst.mesh
		var demi: Vector3 = box.size * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var coin_local := Vector3(demi.x * sx, demi.y * sy, demi.z * sz)
					var coin_monde: Vector3 = inst.global_transform * coin_local
					var d := Vector2(coin_monde.x - origine.x, coin_monde.z - origine.z).length()
					r = maxf(r, d)
	return r


# -----------------------------------------------------------------------------
# LA POSE — fonction pure de `etat`
# -----------------------------------------------------------------------------

func poser(etat: Dictionary) -> void:
	if _fiche.is_empty():
		return

	var pos: Vector2 = etat.get("position", Vector2.ZERO)
	var visee: Vector2 = etat.get("visee", Vector2.DOWN)
	var vitesse: Vector2 = etat.get("vitesse", Vector2.ZERO)
	var torche_allumee: bool = etat.get("torche", false)
	var arme_slug: String = String(etat.get("arme", ""))
	var tir: bool = etat.get("tir", false)
	var touche: bool = etat.get("touche", false)
	var mort: bool = etat.get("mort", false)
	var accroupi: bool = etat.get("accroupi", false)
	var enjambe: float = clampf(etat.get("enjambe", 0.0), 0.0, 1.0)
	# ISO3 vague 3 — le leurre (`gadget_leurre.gd`) porte un `VoxelCorps` immobile,
	# « arme baissée » : ni marche ni tir ni enjambement ne produisent cette pose,
	# elle a donc besoin de son propre champ, additif (défaut faux, aucun appelant
	# existant n'en pâtit). Ignoré en mort/enjambement, qui ont déjà leur propre
	# position d'arme.
	var arme_baissee: bool = etat.get("arme_baissee", false)
	var t: float = etat.get("t", 0.0)

	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	position = Vector3(pos.x / tuile, 0.0, pos.y / tuile)

	if visee.length_squared() > 0.0001:
		basis = Basis.looking_at(Vector3(visee.x, 0.0, visee.y).normalized(), Vector3.UP)

	_torche_mesh.visible = torche_allumee
	_arme_mesh.visible = arme_slug != ""

	if mort:
		_poser_mort(t)
		return

	rotation.x = 0.0

	if enjambe > 0.0:
		_poser_enjambe(enjambe)
		return

	var facteur_accroupi := _facteur_accroupi(accroupi, t)

	var vmag := vitesse.length()
	if vmag > 1.0:
		_poser_marche(t, vmag, facteur_accroupi)
	else:
		_poser_repos(t, facteur_accroupi)

	_appliquer_accroupi(facteur_accroupi)

	# L'arme et la torche sont enfants du torse pour rester à hauteur de main
	# SANS suivre le balancement des bras (vague 0, « l'arme ne ment pas ») —
	# mais le buste penché de l'accroupi (vague 1) est une rotation de ce MÊME
	# parent, et la suivre aveuglément commet exactement le même mensonge :
	# sans cette contre-rotation, l'arme plongeait vers le sol loin devant le
	# corps au lieu de rester tenue (trouvé au banc, pas à la suite — rien ne
	# vérifiait la position de l'arme pendant l'accroupi). La translation (la
	# hanche qui descend) continue de s'appliquer normalement via le parent ;
	# seule la ROTATION du torse est annulée pour ces deux enfants.
	var contre_rotation := Basis(Vector3.RIGHT, -_torse.rotation.x)
	var recul := _enveloppe_recul(t) if tir else 0.0
	var baisse := ANGLE_ARME_BAISSEE if arme_baissee else 0.0
	_arme_pivot.rotation.x = -_torse.rotation.x - baisse
	_arme_pivot.position = contre_rotation * (_arme_pos_base + Vector3(0.0, 0.0, recul))
	_torche_pivot.rotation.x = -_torse.rotation.x
	_torche_pivot.position = contre_rotation * _torche_pos_base

	_torse.rotation.z = (AMPL_SECOUSSE * sin(t * OMEGA_SECOUSSE) * exp(-t * DECAY_SECOUSSE)) if touche else 0.0


func _poser_repos(t: float, facteur_accroupi: float) -> void:
	var bob := sin(t * TAU * FREQ_RESPIRATION) * AMPL_RESPIRATION * lerpf(1.0, 0.3, facteur_accroupi)
	_torse.position.y = _torse_y_base + bob
	_jambe_g.rotation.x = 0.0
	_jambe_d.rotation.x = 0.0
	_bras_g.rotation.x = -GARDE_BRAS
	_bras_d.rotation.x = -GARDE_BRAS
	_gadget_pivot.position = _gadget_pos_base + Vector3(0.0, bob * 0.5, 0.0)
	_gadget_pivot.rotation = _geste_gadget(t)


## `facteur_accroupi` resserre l'amplitude des jambes et des bras et retire
## l'essentiel du rebond du torse : « à petits pas et sans rebond » (brief),
## des gens qui ne veulent pas faire de bruit ne martèlent pas le sol accroupis
## non plus que debout — la même leçon que le correctif de cadence du 2026-09-14.
func _poser_marche(t: float, vmag: float, facteur_accroupi: float) -> void:
	var vitesse_tuiles := vmag / float(CandelaTileSet.TILE_SIZE.x)
	var phase := t * vitesse_tuiles / LONGUEUR_PAS
	var ang := sin(phase * TAU)
	var amplitude_jambe := lerpf(AMPLITUDE_JAMBE, AMPLITUDE_JAMBE * 0.45, facteur_accroupi)
	var amplitude_bras := lerpf(AMPLITUDE_BRAS, AMPLITUDE_BRAS * 0.45, facteur_accroupi)
	_jambe_d.rotation.x = ang * amplitude_jambe
	_jambe_g.rotation.x = -ang * amplitude_jambe
	_bras_g.rotation.x = ang * amplitude_bras - GARDE_BRAS
	_bras_d.rotation.x = -ang * amplitude_bras - GARDE_BRAS
	var bob := absf(sin(phase * TAU)) * AMPL_RESPIRATION * lerpf(1.5, 0.3, facteur_accroupi)
	_torse.position.y = _torse_y_base + bob
	_gadget_pivot.position = _gadget_pos_base + Vector3(0.0, bob * 0.5, 0.0)
	_gadget_pivot.rotation = _geste_gadget(t)


## Le geste de gadget de CETTE classe (voir `GESTES_GADGET`) — une rotation
## pure de `t`, en radians par axe. Slug inconnu (catalogue sans geste écrit,
## ne devrait pas arriver) : `Vector3.ZERO`, jamais une valeur devinée.
func _geste_gadget(t: float) -> Vector3:
	var slug: String = _fiche.get("gadget_slug", "")
	if not GESTES_GADGET.has(slug):
		return Vector3.ZERO
	var total := Vector3.ZERO
	for terme in GESTES_GADGET[slug]:
		var axe: Vector3 = terme["axe"]
		var phase: float = terme.get("phase", 0.0)
		var angle := sin(t * TAU * float(terme["freq"]) + phase) * float(terme["amplitude"])
		total += axe * angle
	return total


## Le temps depuis le passage à `accroupi = true`, même convention que
## `tir`/`touche` (voir l'en-tête de classe) — mais SEULEMENT dans un sens.
## Une fonction pure de `(accroupi, t)` ne peut pas deviner si `t` proche de 0
## veut dire « vient tout juste de passer debout » ou « n'a jamais été
## accroupi » : les deux sont le même appel. Se relever va donc plus vite que
## s'accroupir — un aplomb instantané, plus court encore que les 150 ms que le
## brief autorise, et sans l'ambiguïté qu'un aller-retour aurait exigée de
## résoudre à l'aveugle.
func _facteur_accroupi(accroupi: bool, t: float) -> float:
	return clampf(t / DUREE_TRANSITION_ACCROUPI, 0.0, 1.0) if accroupi else 0.0


## Abaisse la hanche (jambes ET torse, pour qu'elles restent à la même ligne),
## penche le torse et rentre la tête — voir « Accroupi » dans l'en-tête de
## classe pour le pourquoi de chaque geste. Appliqué PAR-DESSUS la pose de
## `_poser_repos`/`_poser_marche`, jamais à leur place : la bascule debout↔
## accroupi ne doit pas réinitialiser la phase de marche en cours.
func _appliquer_accroupi(facteur: float) -> void:
	var hanche_y := lerpf(_torse_y_base, _hanche_accroupi_y, facteur)
	var bob_actuel := _torse.position.y - _torse_y_base
	var compression := lerpf(1.0, FACTEUR_LONGUEUR_JAMBE_ACCROUPI, facteur)
	var flexion := facteur * ANGLE_JAMBE_ACCROUPI

	_jambe_g.position.y = hanche_y
	_jambe_d.position.y = hanche_y
	_jambe_g.rotation.x += flexion
	_jambe_d.rotation.x += flexion
	_jambe_g_mesh.scale.y = compression
	_jambe_d_mesh.scale.y = compression
	_jambe_g_mesh.position.y = -_h_jambe_base * compression * 0.5
	_jambe_d_mesh.position.y = -_h_jambe_base * compression * 0.5

	_torse.position.y = hanche_y + bob_actuel
	_torse.rotation.x = -facteur * ANGLE_TORSE_ACCROUPI
	_tete_pivot.rotation.x = -facteur * ANGLE_TETE_ACCROUPI_SUPPL


## Debout, jamais accroupi (voir l'en-tête de classe) : la jambe droite —
## toujours la même, le geste n'alterne pas comme la marche — balaie de
## l'arrière vers l'avant en se soulevant au milieu du geste ; l'arme se
## baisse dès les premiers instants et le reste tant qu'on enjambe.
func _poser_enjambe(enjambe: float) -> void:
	_torse.position.y = _torse_y_base
	_torse.rotation.x = 0.0
	_tete_pivot.rotation.x = 0.0

	_jambe_g.position.y = _torse_y_base
	_jambe_g.rotation.x = 0.0
	_jambe_g_mesh.scale.y = 1.0
	_jambe_g_mesh.position.y = -_h_jambe_base * 0.5

	var angle := lerpf(-ANGLE_ENJAMBE_MAX, ANGLE_ENJAMBE_MAX, enjambe)
	var levee := LEVEE_ENJAMBE * sin(enjambe * PI)
	_jambe_d.position.y = _torse_y_base + levee
	_jambe_d.rotation.x = angle
	_jambe_d_mesh.scale.y = 1.0
	_jambe_d_mesh.position.y = -_h_jambe_base * 0.5

	_bras_g.rotation.x = -GARDE_BRAS
	_bras_d.rotation.x = -GARDE_BRAS

	var baisse := ANGLE_ARME_BAISSEE * clampf(enjambe / SEUIL_ARME_BAISSEE, 0.0, 1.0)
	_arme_pivot.rotation.x = -baisse
	_arme_pivot.position = _arme_pos_base
	_torche_pivot.rotation.x = 0.0
	_torche_pivot.position = _torche_pos_base

	_gadget_pivot.position = _gadget_pos_base
	_gadget_pivot.rotation = Vector3.ZERO


func _enveloppe_recul(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < T_MONTEE_RECUL:
		return RECUL_MAX * (t / T_MONTEE_RECUL)
	if t < DUREE_RECUL:
		return RECUL_MAX * (1.0 - (t - T_MONTEE_RECUL) / (DUREE_RECUL - T_MONTEE_RECUL))
	return 0.0


## Trois poses de bascule (0,15 / 0,35 / 0,55 s) puis couché, figé au-delà.
## **Exempte de la règle « aucune partie sous le sol »** (le catalogue de
## tests le dit explicitement) : un corps qui tombe traverse le plan du sol
## avant de s'y stabiliser, et le corriger pixel par pixel n'apporterait rien
## à ce qu'un test headless peut réellement garantir.
func _poser_mort(t: float) -> void:
	rotation.x = deg_to_rad(_interp_paliers(t, TEMPS_CHUTE, ANGLES_CHUTE_DEG))
	_torse.rotation.z = 0.0
	_torse.rotation.x = 0.0
	_tete_pivot.rotation.x = 0.0
	position.y = 0.04 if t >= TEMPS_CHUTE[-1] else 0.0

	var pli := clampf(t / TEMPS_CHUTE[-1], 0.0, 1.0)
	_jambe_g.position.y = _torse_y_base
	_jambe_d.position.y = _torse_y_base
	_jambe_g.rotation.x = lerpf(0.0, deg_to_rad(45.0), pli)
	_jambe_d.rotation.x = lerpf(0.0, deg_to_rad(-30.0), pli)
	# Compression et hauteur de hanche remises à l'état debout : un cadavre
	# hérité d'un `etat` accroupi ne doit pas garder des jambes raccourcies —
	# `poser()` est pure, rien d'un appel précédent ne doit survivre ici.
	_jambe_g_mesh.scale.y = 1.0
	_jambe_d_mesh.scale.y = 1.0
	_jambe_g_mesh.position.y = -_h_jambe_base * 0.5
	_jambe_d_mesh.position.y = -_h_jambe_base * 0.5
	_torse.position.y = _torse_y_base
	_bras_g.rotation.x = lerpf(-GARDE_BRAS, deg_to_rad(20.0), pli)
	_bras_d.rotation.x = lerpf(-GARDE_BRAS, deg_to_rad(-20.0), pli)
	_arme_pivot.rotation.x = 0.0
	_arme_pivot.position = _arme_pos_base
	_torche_pivot.rotation.x = 0.0
	_torche_pivot.position = _torche_pos_base
	_gadget_pivot.position = _gadget_pos_base
	_gadget_pivot.rotation = Vector3.ZERO


static func _interp_paliers(t: float, temps: Array, valeurs: Array) -> float:
	if t <= temps[0]:
		return valeurs[0]
	for i in range(temps.size() - 1):
		if t <= temps[i + 1]:
			var f: float = (t - temps[i]) / maxf(temps[i + 1] - temps[i], 0.0001)
			return lerpf(valeurs[i], valeurs[i + 1], f)
	return valeurs[valeurs.size() - 1]


# -----------------------------------------------------------------------------
# CONSTRUCTION
# -----------------------------------------------------------------------------

func _vider() -> void:
	for enfant in get_children():
		remove_child(enfant)
		enfant.free()
	_fiche = {}
	_nombre_de_boites = 0
	_boites_visibles.clear()
	position = Vector3.ZERO
	rotation = Vector3.ZERO


## Une boîte visible, et son double en profondeur seule — voir « La passe de
## profondeur » dans l'en-tête de `corps_iso.gdshader` (ISO3 vague 2). Neuf
## boîtes par corps se recouvrent ; sans ce double par boîte, deux surfaces
## semi-transparentes superposées à l'écran s'assombriraient deux fois au lieu
## d'une. Le double partage le MÊME maillage (rien à dupliquer que le
## matériau) ; `render_priority = -1` le fait passer avant la couleur.
##
## ⚠️ **Le double est un ENFANT de la boîte visible, jamais un frère à
## transform copiée.** L'accroupi (vague 1) change `scale`/`position` de
## certaines boîtes à chaque pose (`_jambe_*_mesh`) — un double posé une fois
## à côté aurait figé sa profondeur à la silhouette DEBOUT pendant que le
## rendu montrait une jambe comprimée, désynchronisant la seule chose que
## cette passe doit garantir. En transform locale identité sous son parent,
## il hérite CHAQUE changement automatiquement, sans rien à resynchroniser.
func _boite(parent: Node3D, taille: Vector3, decalage: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = taille
	var inst := MeshInstance3D.new()
	inst.name = "Boite"
	inst.mesh = mesh
	inst.material_override = _materiau
	inst.position = decalage
	parent.add_child(inst)
	_nombre_de_boites += 1
	_boites_visibles.append(inst)

	var profondeur := MeshInstance3D.new()
	profondeur.name = "BoiteProfondeur"
	profondeur.mesh = mesh
	profondeur.material_override = _materiau_profondeur
	inst.add_child(profondeur)

	return inst


## ISO12 — l'aspect des portraits de classe (`--corps=portraits`, voir `iso_corps_portrait.gdshaderinc`) : la palette
## de la classe dans la matière commune, les demi-tailles qui disent au shader quelle boîte est le torse, l'arme ou la
## bouteille, et — pour les six classes qui la portent sur leur portrait — la bouteille, une boîte de plus, sous le
## torse : elle compte donc dans l'empreinte du corps seul (`rayon_empreinte(true)`), comme la règle d'ISO Corps le veut.
func _habiller_en_portrait(slug: String) -> void:
	var p := VoxelCatalogueT.palette_portrait(slug)
	if p.is_empty():
		return
	var s := _fiche
	var e: float = s["echelle"]
	var torse := Vector3(float(s["largeur_torse"]) * e, s["hauteur_torse"], float(s["profondeur_torse"]) * e)
	var fa: Dictionary = s["arme"]
	# `couleur_fiche` reste le gris de la classe : c'est sur lui que la pâte décide où la lumière se voit.
	_materiau.set_shader_parameter("portrait", 1.0)
	for cle in ["ocre", "rouille", "brun", "bouteille", "arme", "cartouche"]:
		_materiau.set_shader_parameter("portrait_%s" % cle, p[cle])
	_materiau.set_shader_parameter("portrait_usure", p["usure"])
	_materiau.set_shader_parameter("portrait_patine", p["patine"])
	_materiau.set_shader_parameter("portrait_hauteur_px", float(s["hauteur_corps"]) * float(CandelaTileSet.TILE_SIZE.x))
	_materiau.set_shader_parameter("portrait_demi_torse", torse * 0.5)
	_materiau.set_shader_parameter("portrait_demi_arme", Vector3(fa["largeur"], fa["hauteur"], fa["longueur"]) * 0.5)
	if bool(p["bouteille_portee"]):
		var b: Dictionary = VoxelCatalogueT.BOUTEILLE
		var taille := Vector3(float(b["largeur"]) * e, b["hauteur"], float(b["profondeur"]) * e)
		_materiau.set_shader_parameter("portrait_demi_bouteille", taille * 0.5)
		# Couchée en travers du haut du dos, collée au torse (l'avant du corps est −Z, le dos +Z).
		var bouteille := _boite(_torse, taille, Vector3(0.0, float(s["hauteur_torse"]) - float(b["haut"]) * 0.5,
			torse.z * 0.5 + taille.z * 0.5))
		bouteille.name = "Bouteille"


func _pivot(parent: Node3D, nom: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nom
	n.position = pos
	parent.add_child(n)
	return n


## Neuf boîtes, un pivot par membre. Seules `largeur`/`profondeur` (le gabarit)
## suivent `echelle` : la disposition verticale (hauteurs, y0) reste identique
## aux dix classes, sans quoi une classe plus « ronde » deviendrait aussi plus
## haute qu'une tuile — ce que `RAYON_CORPS`/`HAUTEUR_CORPS` interdisent.
func _construire_squelette() -> void:
	var s := _fiche
	var e: float = s["echelle"]

	var y_hanche: float = s["y0_torse"]
	var h_jambe: float = s["hauteur_jambe"]
	var l_jambe: float = s["largeur_jambe"] * e
	var p_jambe: float = s["profondeur_jambe"] * e
	var ecart_jambe: float = s["ecart_jambe"] * e
	_h_jambe_base = h_jambe
	# Voir la constante : la hanche accroupie est celle qui pose le pied
	# exactement au sol quand la jambe est comprimée et basculée à son
	# maximum — calculée ici pour ne JAMAIS diverger de la géométrie réelle
	# des jambes, qui varie avec `hauteur_jambe` si le squelette évolue un jour.
	_hanche_accroupi_y = h_jambe * FACTEUR_LONGUEUR_JAMBE_ACCROUPI * cos(ANGLE_JAMBE_ACCROUPI)

	_jambe_g = _pivot(self, "JambeGauche", Vector3(-ecart_jambe, y_hanche, 0.0))
	_jambe_g_mesh = _boite(_jambe_g, Vector3(l_jambe, h_jambe, p_jambe), Vector3(0.0, -h_jambe * 0.5, 0.0))
	_jambe_d = _pivot(self, "JambeDroite", Vector3(ecart_jambe, y_hanche, 0.0))
	_jambe_d_mesh = _boite(_jambe_d, Vector3(l_jambe, h_jambe, p_jambe), Vector3(0.0, -h_jambe * 0.5, 0.0))

	_torse = _pivot(self, "Torse", Vector3(0.0, y_hanche, 0.0))
	_torse_y_base = y_hanche
	var h_torse: float = s["hauteur_torse"]
	var l_torse: float = s["largeur_torse"] * e
	var p_torse: float = s["profondeur_torse"] * e
	_boite(_torse, Vector3(l_torse, h_torse, p_torse), Vector3(0.0, h_torse * 0.5, 0.0))

	# Tête — pivot propre pour qu'ISO4/ISO7 puissent l'orienter plus tard sans
	# toucher au reste ; depuis ISO3 vague 1, la posture accroupie s'en sert
	# aussi (« tête rentrée »).
	_tete_pivot = _pivot(_torse, "Tete", Vector3(0.0, s["y0_tete"] - y_hanche, 0.0))
	var h_tete: float = s["hauteur_tete"]
	var c_tete: float = s["cote_tete"] * e
	_tete_mesh = _boite(_tete_pivot, Vector3(c_tete, h_tete, c_tete), Vector3(0.0, h_tete * 0.5, 0.0))

	var y_epaule: float = s["y_epaule"] - y_hanche
	var l_bras: float = s["largeur_bras"] * e
	var longueur_bras: float = s["longueur_bras"]
	var x_epaule: float = l_torse * 0.5 + l_bras * 0.5

	_bras_g = _pivot(_torse, "BrasGauche", Vector3(-x_epaule, y_epaule, 0.0))
	_boite(_bras_g, Vector3(l_bras, longueur_bras, l_bras), Vector3(0.0, -longueur_bras * 0.5, 0.0))
	_bras_d = _pivot(_torse, "BrasDroit", Vector3(x_epaule, y_epaule, 0.0))
	_boite(_bras_d, Vector3(l_bras, longueur_bras, l_bras), Vector3(0.0, -longueur_bras * 0.5, 0.0))

	# Arme et torche : tenues à hauteur de main, en avant du torse — jamais
	# portées par le bras qui se balance (voir « couches d'animation » plus
	# haut) : l'arme ne ment jamais sur la visée, quel que soit le pas en cours.
	var y_main: float = s["y_main"] - y_hanche
	var avant_main: float = s["avant_main"]
	var ecart_main: float = s["ecart_main"]

	_arme_pos_base = Vector3(ecart_main, y_main, -avant_main)
	_arme_pivot = _pivot(_torse, "Arme", _arme_pos_base)
	var fa: Dictionary = s["arme"]
	_arme_mesh = _boite(_arme_pivot, Vector3(fa["largeur"], fa["hauteur"], fa["longueur"]),
		Vector3(0.0, 0.0, -fa["longueur"] * 0.5))

	_torche_pos_base = Vector3(-ecart_main, y_main, -avant_main)
	_torche_pivot = _pivot(_torse, "Torche", _torche_pos_base)
	var ft: Dictionary = s["torche"]
	_torche_mesh = _boite(_torche_pivot, Vector3(ft["largeur"], ft["hauteur"], ft["longueur"]),
		Vector3(0.0, 0.0, -ft["longueur"] * 0.5))

	_gadget_pos_base = Vector3(0.0, s["y_gadget"] - y_hanche, s["arriere_gadget"])
	_gadget_pivot = _pivot(_torse, "Gadget", _gadget_pos_base)
	var fg: Dictionary = s["gadget"]
	_boite(_gadget_pivot, Vector3(fg["largeur"], fg["hauteur"], fg["longueur"]),
		Vector3(0.0, 0.0, fg["longueur"] * 0.5))
