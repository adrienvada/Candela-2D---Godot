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
## Sinon : la charpente suit `marche` ou `repos` selon `vitesse` ; `tir`
## ajoute un recul sur l'arme SEULE, par-dessus quoi que fasse le reste du
## corps ; `touche` ajoute une secousse au torse. Un joueur qui encaisse en
## marchant continue donc de marcher, secoué — ce que la description en liste
## séparée de la commande ("repos, marche, visée, tir, touché, mort") laissait
## ambigu, et que la superposition rend possible sans état caché.
##
## ## Le geste de gadget
##
## Un seul, partagé par les dix classes : le gadget suit le bob du torse
## pendant la marche. Un geste PAR CLASSE (le brief l'autorise « si c'est
## simple ») aurait exigé dix animations distinctes pour un chantier dont le
## budget est de deux sessions-journées — **signalé pour ISO4**, pas fait ici.
##
## ## Ce que ce nœud NE fait PAS
##
## Aucune lumière : `lumiere_recue` est un simple curseur (`definir_lumiere`),
## que le banc pilote et qu'ISO2 alimentera depuis la lightmap 2D. Aucun
## `Light3D`. Aucune dépendance à `tools/proto_iso.gd` — même convention de
## repère, code indépendant.

const VoxelCatalogueT := preload("res://voxel_catalogue.gd")
const ShaderCorpsIso := preload("res://corps_iso.gdshader")

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

var _fiche: Dictionary = {}
var _materiau: ShaderMaterial
var _nombre_de_boites: int = 0

var _jambe_g: Node3D
var _jambe_d: Node3D
var _torse: Node3D
var _bras_g: Node3D
var _bras_d: Node3D
var _arme_pivot: Node3D
var _arme_mesh: MeshInstance3D
var _torche_mesh: MeshInstance3D
var _gadget_pivot: Node3D

var _torse_y_base: float = 0.0
var _arme_pos_base: Vector3 = Vector3.ZERO
var _gadget_pos_base: Vector3 = Vector3.ZERO


## Bâtit le corps depuis `VoxelCatalogue.fiche(slug)`. Rend `false` (et laisse
## le catalogue crier) si le slug est inconnu. Idempotent : un second appel
## reconstruit proprement, comme `proto_iso.gd:construire()`.
func construire(slug: String) -> bool:
	_vider()
	var f := VoxelCatalogueT.fiche(slug)
	if f.is_empty():
		return false
	_fiche = f

	_materiau = ShaderMaterial.new()
	_materiau.shader = ShaderCorpsIso
	_materiau.set_shader_parameter("couleur_fiche", f["couleur"])
	_materiau.set_shader_parameter("lumiere_recue", 0.0)
	_materiau.set_shader_parameter("style", 0.0)

	_construire_squelette()

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


func nombre_de_boites() -> int:
	return _nombre_de_boites


## Exposé pour le banc et la suite : lire `lumiere_recue` sans rendre une
## image, et le régler depuis le curseur du banc.
func materiau() -> ShaderMaterial:
	return _materiau


func definir_lumiere(v: float) -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("lumiere_recue", clampf(v, 0.0, 1.0))


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
	var vmag := vitesse.length()
	if vmag > 1.0:
		_poser_marche(t, vmag)
	else:
		_poser_repos(t)

	var recul := _enveloppe_recul(t) if tir else 0.0
	_arme_pivot.position = _arme_pos_base + Vector3(0.0, 0.0, recul)

	_torse.rotation.z = (AMPL_SECOUSSE * sin(t * OMEGA_SECOUSSE) * exp(-t * DECAY_SECOUSSE)) if touche else 0.0


func _poser_repos(t: float) -> void:
	var bob := sin(t * TAU * FREQ_RESPIRATION) * AMPL_RESPIRATION
	_torse.position.y = _torse_y_base + bob
	_jambe_g.rotation.x = 0.0
	_jambe_d.rotation.x = 0.0
	_bras_g.rotation.x = -GARDE_BRAS
	_bras_d.rotation.x = -GARDE_BRAS
	_gadget_pivot.position = _gadget_pos_base + Vector3(0.0, bob * 0.5, 0.0)


func _poser_marche(t: float, vmag: float) -> void:
	var vitesse_tuiles := vmag / float(CandelaTileSet.TILE_SIZE.x)
	var phase := t * vitesse_tuiles / LONGUEUR_PAS
	var ang := sin(phase * TAU)
	_jambe_d.rotation.x = ang * AMPLITUDE_JAMBE
	_jambe_g.rotation.x = -ang * AMPLITUDE_JAMBE
	_bras_g.rotation.x = ang * AMPLITUDE_BRAS - GARDE_BRAS
	_bras_d.rotation.x = -ang * AMPLITUDE_BRAS - GARDE_BRAS
	var bob := absf(sin(phase * TAU)) * AMPL_RESPIRATION * 1.5
	_torse.position.y = _torse_y_base + bob
	_gadget_pivot.position = _gadget_pos_base + Vector3(0.0, bob * 0.5, 0.0)


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
	position.y = 0.04 if t >= TEMPS_CHUTE[-1] else 0.0

	var pli := clampf(t / TEMPS_CHUTE[-1], 0.0, 1.0)
	_jambe_g.rotation.x = lerpf(0.0, deg_to_rad(45.0), pli)
	_jambe_d.rotation.x = lerpf(0.0, deg_to_rad(-30.0), pli)
	_bras_g.rotation.x = lerpf(-GARDE_BRAS, deg_to_rad(20.0), pli)
	_bras_d.rotation.x = lerpf(-GARDE_BRAS, deg_to_rad(-20.0), pli)
	_arme_pivot.position = _arme_pos_base
	_gadget_pivot.position = _gadget_pos_base


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
	position = Vector3.ZERO
	rotation = Vector3.ZERO


func _boite(taille: Vector3, decalage: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = taille
	var inst := MeshInstance3D.new()
	inst.name = "Boite"
	inst.mesh = mesh
	inst.material_override = _materiau
	inst.position = decalage
	_nombre_de_boites += 1
	return inst


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

	_jambe_g = _pivot(self, "JambeGauche", Vector3(-ecart_jambe, y_hanche, 0.0))
	_jambe_g.add_child(_boite(Vector3(l_jambe, h_jambe, p_jambe), Vector3(0.0, -h_jambe * 0.5, 0.0)))
	_jambe_d = _pivot(self, "JambeDroite", Vector3(ecart_jambe, y_hanche, 0.0))
	_jambe_d.add_child(_boite(Vector3(l_jambe, h_jambe, p_jambe), Vector3(0.0, -h_jambe * 0.5, 0.0)))

	_torse = _pivot(self, "Torse", Vector3(0.0, y_hanche, 0.0))
	_torse_y_base = y_hanche
	var h_torse: float = s["hauteur_torse"]
	var l_torse: float = s["largeur_torse"] * e
	var p_torse: float = s["profondeur_torse"] * e
	_torse.add_child(_boite(Vector3(l_torse, h_torse, p_torse), Vector3(0.0, h_torse * 0.5, 0.0)))

	# Tête — pivot propre pour qu'ISO4/ISO7 puissent l'orienter plus tard sans
	# toucher au reste, mais AUCUNE pose de cette étape ne la fait bouger.
	var tete_pivot := _pivot(_torse, "Tete", Vector3(0.0, s["y0_tete"] - y_hanche, 0.0))
	var h_tete: float = s["hauteur_tete"]
	var c_tete: float = s["cote_tete"] * e
	tete_pivot.add_child(_boite(Vector3(c_tete, h_tete, c_tete), Vector3(0.0, h_tete * 0.5, 0.0)))

	var y_epaule: float = s["y_epaule"] - y_hanche
	var l_bras: float = s["largeur_bras"] * e
	var longueur_bras: float = s["longueur_bras"]
	var x_epaule: float = l_torse * 0.5 + l_bras * 0.5

	_bras_g = _pivot(_torse, "BrasGauche", Vector3(-x_epaule, y_epaule, 0.0))
	_bras_g.add_child(_boite(Vector3(l_bras, longueur_bras, l_bras), Vector3(0.0, -longueur_bras * 0.5, 0.0)))
	_bras_d = _pivot(_torse, "BrasDroit", Vector3(x_epaule, y_epaule, 0.0))
	_bras_d.add_child(_boite(Vector3(l_bras, longueur_bras, l_bras), Vector3(0.0, -longueur_bras * 0.5, 0.0)))

	# Arme et torche : tenues à hauteur de main, en avant du torse — jamais
	# portées par le bras qui se balance (voir « couches d'animation » plus
	# haut) : l'arme ne ment jamais sur la visée, quel que soit le pas en cours.
	var y_main: float = s["y_main"] - y_hanche
	var avant_main: float = s["avant_main"]
	var ecart_main: float = s["ecart_main"]

	_arme_pos_base = Vector3(ecart_main, y_main, -avant_main)
	_arme_pivot = _pivot(_torse, "Arme", _arme_pos_base)
	var fa: Dictionary = s["arme"]
	_arme_mesh = _boite(Vector3(fa["largeur"], fa["hauteur"], fa["longueur"]),
		Vector3(0.0, 0.0, -fa["longueur"] * 0.5))
	_arme_pivot.add_child(_arme_mesh)

	var torche_pos := Vector3(-ecart_main, y_main, -avant_main)
	var torche_pivot := _pivot(_torse, "Torche", torche_pos)
	var ft: Dictionary = s["torche"]
	_torche_mesh = _boite(Vector3(ft["largeur"], ft["hauteur"], ft["longueur"]),
		Vector3(0.0, 0.0, -ft["longueur"] * 0.5))
	torche_pivot.add_child(_torche_mesh)

	_gadget_pos_base = Vector3(0.0, s["y_gadget"] - y_hanche, s["arriere_gadget"])
	_gadget_pivot = _pivot(_torse, "Gadget", _gadget_pos_base)
	var fg: Dictionary = s["gadget"]
	_gadget_pivot.add_child(_boite(Vector3(fg["largeur"], fg["hauteur"], fg["longueur"]),
		Vector3(0.0, 0.0, fg["longueur"] * 0.5)))
