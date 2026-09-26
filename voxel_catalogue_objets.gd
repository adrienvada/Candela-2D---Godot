class_name VoxelCatalogueObjets
extends RefCounted

## Le catalogue des objets debout voxel — chantier ISO, étape ISO3, vague 3 (iso-corps).
##
## ## Qui devient un voxel, qui reste à plat
##
## Lu gadget par gadget (`gadget_mine.gd`, `gadget_torche_fantome.gd`,
## `gadget_voile.gd`, `gadget_ombre.gd`, `gadget_gresillement.gd`, `fusee.gd` —
## et `gadget_leurre.gd`, hors catalogue, voir plus bas) avant de trancher, comme
## le brief le demande :
##
## - **Devient un voxel** : la mine (un boîtier posé), la torche fantôme (pied +
##   tête, un vrai luminaire posé), les DEUX PIQUETS du voile (des poteaux, pas la
##   toile elle-même — fine et déjà à plat dans le jeu), la plaque de l'ombre
##   habitée (une plaque d'acier montée sur un mât), la bobine du grésillement (un
##   petit boîtier), la fusée POSÉE (`fusee.gd`, seulement au sol : le vol reste
##   hors de ce catalogue, le brief le dit explicitement).
## - **Reste à plat, dans la lightmap** : suie, poussière, poudre de contact,
##   nappe de braises. Les quatre partagent le même verdict côté code
##   (`gadget_volume.gd`, `gadget_poudre.gd`, `gadget_braises.gd`) :
##   `arrete_les_balles = false`, `touche_par_les_balles = false`,
##   `occulte_la_lumiere = false`, et pour trois des quatre, `_monter_occluder()`
##   est vide — ce ne sont pas des objets physiques dans le jeu lui-même, juste
##   une lueur ou une nappe qui teinte la lightmap 2D. Leur donner un volume 3D
##   inventerait une présence que le jeu n'a jamais eue.
##
## ## Le leurre, à part
##
## Le leurre (`gadget_leurre.gd`) ne dessine PAS un objet : il recopie le corps
## de la classe qui l'a posé (silhouette, ombre, teinte adverse) pour être
## indiscernable d'un vrai joueur. Un `VoxelCorps` construit sur `classe_du_poseur`
## et posé immobile, arme baissée, EST son propre voxel — inutile de le refaire
## ici. Voir `voxel_objets.gd`, en-tête, pour l'état exact à lui donner.
##
## ## Le plafond d'équité
##
## « Un objet voxel ne doit jamais cacher un corps que la vue de dessus laisse
## voir » (brief). Deux bornes, mesurées par `tools/test_voxel_objets.gd` :
## - hauteur totale ≤ `HAUTEUR_MAX` (0,25 tuile, 8,75 px) pour tout objet — le
##   leurre est un corps entier, explicitement hors de cette borne ;
## - empreinte au sol (demi-diagonale de la boîte la plus large) ≤
##   `rayon_collision_tuiles() * MARGE_EMPREINTE` (rayon de collision RÉEL de
##   l'objet, `+ 10 %` au plus, jamais deviné : `OBJETS[slug]["rayon_px"]` est
##   recopié du gadget lui-même, jamais réinventé).
##
## ## Une fiche par objet, comme les corps
##
## `rayon_px` est le rayon (ou demi-diagonale, pour une forme rectangulaire) de
## la VRAIE forme de collision 2D du gadget, en pixels — recopié de son fichier,
## jamais recalculé. `couleur` suit la même discipline que `VoxelCatalogue` : un
## gris plafonné à `Charte.DIM`, jamais plus clair.

const Charte := preload("res://charte.gd")

## Même plafond que les corps (`VoxelCatalogue.GRIS_PLAFOND`) — pas une seconde
## teinte inventée pour les objets.
const GRIS_PLAFOND := Charte.DIM

## Hauteur maximale d'un objet voxel, en tuiles (1 tuile = 35 px) — la règle
## d'équité du brief, chiffrée. Le leurre (un `VoxelCorps` entier) n'y est pas
## soumis, par nature : c'est un corps, pas un objet.
const HAUTEUR_MAX := 0.25

## Marge tolérée sur l'empreinte au sol par rapport au rayon de collision réel.
const MARGE_EMPREINTE := 1.10

## Les objets qui restent à plat dans la lightmap 2D — jamais construits ici,
## présents seulement pour que `slugs()`/les tests sachent qu'ils sont un choix
## et non un oubli. Raison par slug, voir l'en-tête de classe.
const SLUGS_SANS_VOXEL := ["suie", "poussiere", "poudre_contact", "nappe_braises"]

## `rayon_px` : rayon de collision réel (ou demi-diagonale du rectangle réel),
## en pixels — voir le fichier cité pour la valeur d'origine.
const OBJETS: Dictionary = {
	"mine": {
		"libelle": "La mine au magnésium",
		"source": "gadget_mine.gd",
		"rayon_px": 8.0,             # GadgetMine._init() : rayon = 8.0
		"gris_rang": 2,
	},
	"torche_fantome": {
		"libelle": "La torche fantôme",
		"source": "gadget_torche_fantome.gd",
		"rayon_px": 9.0,             # GadgetTorcheFantome._init() : rayon = 9.0
		"gris_rang": 6,
	},
	"voile": {
		"libelle": "Les piquets du voile",
		"source": "gadget_voile.gd",
		# Pas un disque : GadgetVoile pose un RectangleShape2D, DEMI_LONGUEUR (84 px)
		# × DEMI_EPAISSEUR (6,5 px). `rayon_px` sert ici à borner CHAQUE piquet
		# (un petit poteau), jamais la toile entière : demi-épaisseur, la seule
		# grandeur qui décrit un piquet plutôt que la bande complète.
		"rayon_px": 6.5,
		"demi_longueur_px": 84.0,    # GadgetVoile.DEMI_LONGUEUR — écart entre les deux piquets
		"gris_rang": 4,
	},
	"ombre": {
		"libelle": "La plaque de l'ombre habitée",
		"source": "gadget_ombre.gd",
		# RectangleShape2D, DEMI_TORSE (18 px) × DEMI_EPAISSEUR (3 px) — demi-
		# diagonale réelle : sqrt(18² + 3²) ≈ 18,25 px.
		"rayon_px": 18.2477,
		"gris_rang": 0,
		# ISO13, Q32 : la plaque IMITE un corps — celui de l'Occulteur, son poseur. Elle suit donc le gris de ce corps
		# (`VoxelCatalogue.facteur_gris_de`), jamais son propre rang : sa clarté ne doit pas la trahir.
		"imite": "occulteur",
	},
	"gresillement": {
		"libelle": "La bobine du grésillement",
		"source": "gadget_gresillement.gd",
		"rayon_px": 9.0,             # GadgetGresillement._init() : rayon = 9.0 (collision — RAYON=240 n'est que la portée)
		"gris_rang": 8,
	},
	"fusee": {
		"libelle": "La fusée posée",
		"source": "fusee.gd / fusee_modele.gd",
		# `Fusee` est un `Node2D` SANS forme de collision (elle interagit par
		# rayons, jamais par corps physique) : aucun `rayon_px` d'origine à
		# recopier. Tranché ici, noté comme demandé par le brief (« si tu
		# hésites... tranche, note-le ») : `EMPREINTE_CORPS` (30 px, le diamètre
		# du sprite du corps de la fusée) donne un rayon visuel de 15 px, la
		# meilleure mesure disponible de ce qu'elle occupe réellement au sol.
		"rayon_px": 15.0,
		"gris_rang": 9,
	},
}

## Facteur de gris pour un rang 0..9 : même formule que `VoxelCatalogue`
## (`_facteur_gris`), 55 % à 85 % du plafond, linéaire — pas réinventée.
static func _facteur_gris(rang: int) -> float:
	return lerpf(0.55, 0.85, float(rang) / 9.0)


## Les slugs des objets voxelisés, dans l'ordre de déclaration.
static func slugs() -> PackedStringArray:
	var out := PackedStringArray()
	for s in OBJETS:
		out.append(s)
	return out


## La fiche d'un objet : ses données propres + une couleur calculée, comme
## `VoxelCatalogue.fiche()`. Dictionnaire vide et `push_error` si le slug est
## inconnu.
static func fiche(slug: String) -> Dictionary:
	if OBJETS.has(slug):
		var f: Dictionary = OBJETS[slug].duplicate(true)
		f["slug"] = slug
		# ISO13, Q32 — un objet qui imite un corps prend le gris de ce corps (les gris égaux), jamais son rang.
		var facteur := VoxelCatalogue.facteur_gris_de(String(f["imite"]), int(f["gris_rang"])) if f.has("imite") \
			else _facteur_gris(f["gris_rang"])
		f["couleur"] = GRIS_PLAFOND * facteur
		return f
	push_error("VoxelCatalogueObjets : objet inconnu « %s » (connus : %s)"
		% [slug, ", ".join(slugs())])
	return {}


## Le rayon de collision réel d'un objet, en TUILES (35 px = 1 tuile) — pour
## comparer l'empreinte au sol de son voxel à la règle d'équité du brief.
static func rayon_collision_tuiles(slug: String) -> float:
	var f := fiche(slug)
	if f.is_empty():
		return 0.0
	return float(f["rayon_px"]) / float(CandelaTileSet.TILE_SIZE.x)
