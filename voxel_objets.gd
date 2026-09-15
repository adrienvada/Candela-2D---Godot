class_name VoxelObjet
extends Node3D

## Un objet debout voxel — chantier ISO, étape ISO3, vague 3 (iso-corps).
##
## ## Même interface que `VoxelCorps`, par construction
##
## `construire(slug)` bâtit les boîtes d'un objet depuis
## `VoxelCatalogueObjets.fiche(slug)` ; `poser(etat)` est une fonction PURE de
## `etat`, comme `VoxelCorps.poser()` — mêmes disciplines (aucune horloge,
## aucun hasard). Les deux matériaux (`corps_iso.gdshader`,
## `corps_iso_profondeur.gdshader`), leurs uniforms (capteur par vue, `centre`,
## `opacite_N`, `silhouette_N`, `style`, `echelle_lecture`), la passe de
## profondeur en enfant de chaque boîte : tout est repris à l'identique de
## `voxel_corps.gd`, pour qu'ISO2 puisse brancher un objet exactement comme
## elle a branché un corps (même appels, mêmes noms). Dupliqué plutôt que
## partagé par refactor : `voxel_corps.gd` est déjà intégré dans le jeu réel
## (`Presentation3D`, ISO3a) au moment d'écrire ceci — le retoucher pour en
## extraire un socle commun aurait risqué la seule chose déjà vérifiée en jeu,
## pour un gain qui n'aide qu'ici.
##
## ## Le leurre n'est PAS ici
##
## `gadget_leurre.gd` ne dessine aucun objet neuf : il recopie le corps de la
## classe qui l'a posé (silhouette, ombre, teinte adverse), pour être
## indiscernable d'un vrai joueur. Le voxel qui lui correspond est donc un
## `VoxelCorps` tout simple, construit sur `classe_du_poseur.slug()` et posé
## ainsi (immobile, arme baissée, pas de torche — le leurre « n'éclaire pas ») :
##
##   var corps := VoxelCorps.new()
##   corps.construire(classe_du_poseur.slug())
##   corps.poser({
##       "position": position_du_leurre, "visee": orientation_du_leurre,
##       "vitesse": Vector2.ZERO, "torche": false, "arme": classe_du_poseur.slug(),
##       "tir": false, "touche": false, "mort": false, "arme_baissee": true, "t": 0.0,
##   })
##
## `arme_baissee` (ISO3 vague 3, ajouté à `VoxelCorps.poser()`) est le seul
## champ neuf que ce besoin a demandé côté corps — un booléen additif, par
## défaut faux, qui ne change rien pour aucun appelant existant.
##
## ## Le plafond d'équité
##
## « Un objet voxel ne doit jamais cacher un corps que la vue de dessus laisse
## voir » (brief). Deux bornes, tenues geométriquement ici et mesurées par
## `tools/test_voxel_objets.gd` : hauteur totale ≤ `VoxelCatalogueObjets.HAUTEUR_MAX`
## (0,25 tuile) pour tout objet ; empreinte au sol ≤ rayon de collision réel de
## l'objet (`VoxelCatalogueObjets.OBJETS[slug]["rayon_px"]`) `× MARGE_EMPREINTE`.
## `hauteur_totale()`/`rayon_empreinte()` recalculent ces deux grandeurs depuis
## le maillage réel, jamais depuis une constante à part — même discipline que
## `VoxelCorps.sommet_tete()`.
##
## ## Les états par objet — un `etat` minimal, jamais deviné pour un objet qui
## n'a rien à montrer
##
## `orientation` (comme `visee` chez les corps) tourne l'objet entier : utile
## pour la torche fantôme (son faisceau), les piquets du voile (l'axe de la
## toile) et la plaque de l'ombre (sa face). `allumee` anime un petit repère
## géométrique — jamais un éclat émis par ce nœud lui-même (`corps_iso.gdshader`
## reste unshaded : toute lumière vient du capteur, jamais d'une émission
## inventée ici) — sur la mine (un flare qui se dresse) et la fusée posée (une
## braise qui se dresse). `poser()` ne lit ni ne dessine `actif` (l'état du
## grésillement, silencieusement ignoré comme tout autre champ que `etat` peut
## porter) : la bobine réelle n'a « aucun témoin lumineux visible »
## (`gadget_gresillement.gd`, lu avant de trancher) — un choix du jeu, pas un
## oubli d'ici.
##
## ## Le repère
##
## Identique aux corps : origine au pied (Y=0 au sol), `+Y` vers le haut,
## `-Z` l'avant de l'objet quand `orientation` pointe vers le bas de l'écran.

const VoxelCatalogueObjetsT := preload("res://voxel_catalogue_objets.gd")
const ShaderCorpsIso := preload("res://corps_iso.gdshader")
const ShaderCorpsIsoProfondeur := preload("res://corps_iso_profondeur.gdshader")
const IsoPateT := preload("res://iso_pate.gd")

## Même choix que `VoxelCorps.STYLE_PAR_DEFAUT`, même raison : LAVIS, pas
## GRAVURE — voir son en-tête pour le détail (une pâte hachurée sur une
## période plus grande qu'un petit objet devient une loterie noir/clair).
const STYLE_PAR_DEFAUT := IsoPateT.LAVIS

## Marge tolérée sur l'empreinte au sol, recopiée de `VoxelCatalogueObjets`
## pour que la suite compare à la MÊME valeur que ce nœud applique — jamais
## deux constantes qui pourraient diverger.
const MARGE_EMPREINTE := VoxelCatalogueObjetsT.MARGE_EMPREINTE

# --- Géométrie par objet, en tuiles (35 px = 1 tuile, comme voxel_corps.gd) ---
# Chaque constante est un choix de dessin, borné par la règle d'équité
# (hauteur ≤ 0,25 tuile, empreinte ≤ rayon de collision réel × 1,1) — jamais
# la forme réelle du sprite 2D recopiée telle quelle, qui n'a pas cette borne.

const MINE_BOITIER := Vector3(0.30, 0.05, 0.30)
const MINE_FLARE := Vector3(0.05, 0.14, 0.05)
const MINE_FLARE_Y0 := 0.05          # base du flare = sommet du boîtier
const MINE_FLARE_FACTEUR_ETEINT := 0.05

const TORCHE_PIED := Vector3(0.16, 0.14, 0.16)
const TORCHE_TETE := Vector3(0.10, 0.06, 0.14)
const TORCHE_TETE_Y := 0.17
const TORCHE_TETE_AVANT := 0.04      # décalage en -Z (vers l'avant de l'objet)

const VOILE_PIQUET := Vector3(0.12, 0.15, 0.12)
const VOILE_DEMI_ECART := 2.4        # GadgetVoile.DEMI_LONGUEUR (84 px) / 35

const OMBRE_PLAQUE := Vector3(1.00, 0.22, 0.12)

const GRESILLEMENT_BOBINE := Vector3(0.28, 0.10, 0.28)

const FUSEE_TIGE := Vector3(0.10, 0.18, 0.10)
const FUSEE_BRAISE := Vector3(0.08, 0.05, 0.08)
const FUSEE_BRAISE_Y0 := 0.18        # base de la braise = sommet de la tige
const FUSEE_BRAISE_FACTEUR_ETEINTE := 0.2

var _fiche: Dictionary = {}
var _materiau: ShaderMaterial
var _materiau_profondeur: ShaderMaterial
var _nombre_de_boites: int = 0
var _boites_visibles: Array = []

var _flare_mesh: MeshInstance3D
var _braise_mesh: MeshInstance3D


## Bâtit l'objet depuis `VoxelCatalogueObjets.fiche(slug)`. Rend `false` (et
## laisse le catalogue crier) si le slug est inconnu ou n'a pas de voxel (voir
## `VoxelCatalogueObjets.SLUGS_SANS_VOXEL`). Idempotent, comme `VoxelCorps`.
func construire(slug: String) -> bool:
	_vider()
	var f := VoxelCatalogueObjetsT.fiche(slug)
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
	_materiau.set_shader_parameter("pixels_par_unite", 1.0)
	_materiau.set_shader_parameter("opacite_1", 1.0)
	_materiau.set_shader_parameter("opacite_2", 1.0)
	_materiau.set_shader_parameter("silhouette_1", Color(0.0, 0.0, 0.0, 0.0))
	_materiau.set_shader_parameter("silhouette_2", Color(0.0, 0.0, 0.0, 0.0))

	_materiau_profondeur = ShaderMaterial.new()
	_materiau_profondeur.shader = ShaderCorpsIsoProfondeur
	_materiau_profondeur.render_priority = -1
	_materiau_profondeur.set_shader_parameter("opacite_1", 1.0)
	_materiau_profondeur.set_shader_parameter("opacite_2", 1.0)
	_materiau_profondeur.set_shader_parameter("silhouette_1", Color(0.0, 0.0, 0.0, 0.0))
	_materiau_profondeur.set_shader_parameter("silhouette_2", Color(0.0, 0.0, 0.0, 0.0))

	_construire_squelette()

	poser({"position": Vector2.ZERO, "orientation": Vector2.DOWN, "t": 0.0})
	return true


func slug() -> String:
	return String(_fiche.get("slug", ""))


func couleur() -> Color:
	return _fiche.get("couleur", Color.WHITE)


func nombre_de_boites() -> int:
	return _nombre_de_boites


func materiau() -> ShaderMaterial:
	return _materiau


func materiau_profondeur() -> ShaderMaterial:
	return _materiau_profondeur


func boites() -> Array:
	return _boites_visibles.duplicate()


func definir_lumiere(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("lumiere_recue", clampf(v, 0.0, 1.0))


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


func effacer_capteur() -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("capteur_actif", false)


func definir_pixels_par_unite(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("pixels_par_unite", v)


func definir_echelle_lecture(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("echelle_lecture", v)


func definir_opacite(o: float, vue: int = 0) -> void:
	var v := clampf(o, 0.0, 1.0)
	for mat in [_materiau, _materiau_profondeur]:
		if mat == null:
			continue
		if vue != 2:
			mat.set_shader_parameter("opacite_1", v)
		if vue != 1:
			mat.set_shader_parameter("opacite_2", v)


func definir_silhouette(couleur: Color, alpha: float, vue: int = 0) -> void:
	var c := Color(couleur.r, couleur.g, couleur.b, clampf(alpha, 0.0, 1.0))
	for mat in [_materiau, _materiau_profondeur]:
		if mat == null:
			continue
		if vue != 2:
			mat.set_shader_parameter("silhouette_1", c)
		if vue != 1:
			mat.set_shader_parameter("silhouette_2", c)


func definir_style(s: int) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("style", s)


## La hauteur totale de l'objet posé (sommet de sa boîte la plus haute),
## recalculée depuis le maillage réel — voir « Le plafond d'équité » en tête
## de fichier. Tient compte de l'état courant (un repère réduit à l'arrêt
## pèse moins que le même repère allumé).
func hauteur_totale() -> float:
	var h := 0.0
	for b in _boites_visibles:
		var inst: MeshInstance3D = b
		var box: BoxMesh = inst.mesh
		var sommet: float = inst.position.y + box.size.y * 0.5 * inst.scale.y
		h = maxf(h, sommet)
	return h


## La plus grande empreinte au sol qu'UNE SEULE boîte occupe (sa propre
## demi-diagonale XZ, PAS son décalage au centre de l'objet) — voir « Le
## plafond d'équité ». Volontairement PAS le décalage : les deux piquets du
## voile sont loin l'un de l'autre (`VOILE_DEMI_ECART`, la vraie toile est
## longue), et ce n'est pas ce que la règle d'équité borne — elle borne
## combien de sol UNE boîte, à elle seule, occupe et peut donc cacher, comparé
## au rayon de collision réel du morceau qu'elle représente.
func rayon_empreinte() -> float:
	var r := 0.0
	for b in _boites_visibles:
		var inst: MeshInstance3D = b
		var box: BoxMesh = inst.mesh
		var demi := Vector2(box.size.x * 0.5 * inst.scale.x, box.size.z * 0.5 * inst.scale.z).length()
		r = maxf(r, demi)
	return r


# -----------------------------------------------------------------------------
# LA POSE — fonction pure de `etat`
# -----------------------------------------------------------------------------

## Fonction PURE de `etat`, comme `VoxelCorps.poser()` : à état égal, pose
## égale. `position`/`orientation` en pixels 2D (`position`) et direction
## (`orientation`), comme `position`/`visee` chez les corps. `allumee` : voir
## l'en-tête de classe pour qui la lit.
func poser(etat: Dictionary) -> void:
	if _fiche.is_empty():
		return

	var pos: Vector2 = etat.get("position", Vector2.ZERO)
	var orientation: Vector2 = etat.get("orientation", Vector2.DOWN)
	var allumee: bool = etat.get("allumee", false)
	var eteinte: bool = etat.get("eteinte", false)

	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	position = Vector3(pos.x / tuile, 0.0, pos.y / tuile)

	if orientation.length_squared() > 0.0001:
		basis = Basis.looking_at(Vector3(orientation.x, 0.0, orientation.y).normalized(), Vector3.UP)

	if _flare_mesh != null:
		var facteur := 1.0 if allumee else MINE_FLARE_FACTEUR_ETEINT
		_flare_mesh.scale.y = facteur
		_flare_mesh.position.y = MINE_FLARE_Y0 + MINE_FLARE.y * 0.5 * facteur

	if _braise_mesh != null:
		var f := FUSEE_BRAISE_FACTEUR_ETEINTE if eteinte else 1.0
		_braise_mesh.scale.y = f
		_braise_mesh.position.y = FUSEE_BRAISE_Y0 + FUSEE_BRAISE.y * 0.5 * f


func _vider() -> void:
	for enfant in get_children():
		remove_child(enfant)
		enfant.free()
	_fiche = {}
	_nombre_de_boites = 0
	_boites_visibles.clear()
	_flare_mesh = null
	_braise_mesh = null
	position = Vector3.ZERO
	basis = Basis.IDENTITY


## Identique à `VoxelCorps._boite()` — voir son en-tête pour le détail du
## double en profondeur (enfant, jamais frère, pour hériter tout changement
## de transform futur).
func _boite(parent: Node3D, taille: Vector3, decalage: Vector3, nom: String = "Boite") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = taille
	var inst := MeshInstance3D.new()
	inst.name = nom
	inst.mesh = mesh
	inst.material_override = _materiau
	inst.position = decalage
	parent.add_child(inst)
	_nombre_de_boites += 1
	_boites_visibles.append(inst)

	var profondeur := MeshInstance3D.new()
	profondeur.name = nom + "Profondeur"
	profondeur.mesh = mesh
	profondeur.material_override = _materiau_profondeur
	inst.add_child(profondeur)

	return inst


func _construire_squelette() -> void:
	match _fiche["slug"]:
		"mine":
			_construire_mine()
		"torche_fantome":
			_construire_torche_fantome()
		"voile":
			_construire_voile()
		"ombre":
			_construire_ombre()
		"gresillement":
			_construire_gresillement()
		"fusee":
			_construire_fusee()


func _construire_mine() -> void:
	_boite(self, MINE_BOITIER, Vector3(0.0, MINE_BOITIER.y * 0.5, 0.0), "Boitier")
	_flare_mesh = _boite(self, MINE_FLARE, Vector3(0.0, MINE_FLARE_Y0 + MINE_FLARE.y * 0.5, 0.0), "Flare")


func _construire_torche_fantome() -> void:
	_boite(self, TORCHE_PIED, Vector3(0.0, TORCHE_PIED.y * 0.5, 0.0), "Pied")
	_boite(self, TORCHE_TETE, Vector3(0.0, TORCHE_TETE_Y, -TORCHE_TETE_AVANT), "Tete")


func _construire_voile() -> void:
	_boite(self, VOILE_PIQUET, Vector3(-VOILE_DEMI_ECART, VOILE_PIQUET.y * 0.5, 0.0), "PiquetGauche")
	_boite(self, VOILE_PIQUET, Vector3(VOILE_DEMI_ECART, VOILE_PIQUET.y * 0.5, 0.0), "PiquetDroit")


func _construire_ombre() -> void:
	_boite(self, OMBRE_PLAQUE, Vector3(0.0, OMBRE_PLAQUE.y * 0.5, 0.0), "Plaque")


func _construire_gresillement() -> void:
	_boite(self, GRESILLEMENT_BOBINE, Vector3(0.0, GRESILLEMENT_BOBINE.y * 0.5, 0.0), "Bobine")


func _construire_fusee() -> void:
	_boite(self, FUSEE_TIGE, Vector3(0.0, FUSEE_TIGE.y * 0.5, 0.0), "Tige")
	_braise_mesh = _boite(self, FUSEE_BRAISE, Vector3(0.0, FUSEE_BRAISE_Y0 + FUSEE_BRAISE.y * 0.5, 0.0), "Braise")
