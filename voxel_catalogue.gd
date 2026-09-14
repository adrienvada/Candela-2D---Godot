class_name VoxelCatalogue
extends RefCounted

## Le catalogue des dix corps voxel — chantier ISO, étape ISO3, vague 0 (iso-corps).
##
## ## Un seul squelette, dix fiches
##
## Les dix classes du jeu (`game_state.gd:_batir_catalogue()`) partagent la même
## charpente — tête, torse, deux bras, deux jambes, torche — et ne divergent que
## par trois choses : un gris plafonné, une échelle de gabarit très légère, et la
## forme de leur arme et de leur gadget. `SQUELETTE` porte la charpente commune,
## en tuiles (`voxel_corps.gd` la lit et bâtit les nœuds) ; `CLASSES` porte ce qui
## varie. La torche n'est PAS dans les formes qui varient : c'est du matériel
## standard, pas une arme — toutes les classes tiennent la même.
##
## ## Le gris plafonné
##
## « Plafonné » : jamais plus clair que `Charte.DIM`, le gris déjà utilisé par le
## dépôt (texte discret des menus) — pas une teinte inventée pour l'occasion. Les
## dix classes se répartissent entre 55 % et 85 % de sa valeur, à la même teinte :
## de quoi distinguer une silhouette d'une autre dans la lumière sans qu'aucune
## ne sorte de l'enveloppe d'équité. La répartition est une formule sur l'indice
## de la classe dans `CLASSES`, jamais un nombre tiré au hasard — le catalogue ne
## contient et n'appelle aucun `randi`/`randf`.
##
## ## Slugs
##
## Les quatre premiers slugs sont ceux des armes historiques
## (`weapon_pistolet.slug()` etc., cf. `game_state.gd:389-435`) ; les six
## suivants sont ceux posés par `_classe()` dans `game_state.gd:4373-4464`. Ce
## fichier ne les invente pas : il les recopie, dans le même ordre que le
## catalogue du jeu, pour qu'une classe se retrouve au même rang des deux côtés.

const Charte := preload("res://charte.gd")

## Plafond de gris : aucune classe ne peut être rendue plus claire que ça.
const GRIS_PLAFOND := Charte.DIM

## La charpente, commune aux dix classes, en tuiles (1 tuile = 1 unité 3D,
## 35 px — voir `CandelaTileSet.TILE_SIZE`). Hauteur totale 1,0, rayon au sol
## 0,4 : les deux constantes du prototype iso (`tools/proto_iso.gd:60-61`), pas
## des nombres redécouverts ici.
const SQUELETTE := {
	"hauteur_corps": 1.0,
	"rayon_corps": 0.4,

	# Jambes : du sol jusqu'à l'entrejambe.
	"hauteur_jambe": 0.42,
	"largeur_jambe": 0.12,
	"profondeur_jambe": 0.12,
	"ecart_jambe": 0.08,          # demi-écart au centre

	# Torse : de l'entrejambe aux épaules.
	"y0_torse": 0.42,
	"hauteur_torse": 0.32,
	"largeur_torse": 0.28,
	"profondeur_torse": 0.16,

	# Tête : posée sur les épaules, sous le plafond de la tuile.
	"y0_tete": 0.74,
	"hauteur_tete": 0.20,
	"cote_tete": 0.19,

	# Bras : pivot à l'épaule, boîte suspendue vers le bas par défaut (une
	# rotation de pose les relève, voir `voxel_corps.gd`).
	"y_epaule": 0.72,
	"longueur_bras": 0.26,
	"largeur_bras": 0.09,

	# Arme et torche : hauteur de main, en avant du torse. La torche est à
	# gauche (elle n'engage jamais la visée), l'arme à droite.
	"y_main": 0.58,
	"avant_main": 0.30,
	"ecart_main": 0.13,

	# Torche : matériel standard, identique pour les dix classes.
	"torche": {"largeur": 0.05, "hauteur": 0.05, "longueur": 0.16},

	# Gadget : porté dans le dos, à hauteur de ceinture.
	"y_gadget": 0.46,
	"arriere_gadget": 0.14,
}

## Les dix classes, dans l'ordre de `game_state.gd:_batir_catalogue()`. Chaque
## forme (`arme`, `gadget`) est en tuiles : `largeur` = X, `hauteur` = Y,
## `longueur` = profondeur tenue en avant (Z). `gris_rang` fixe la place de la
## classe entre 0 (la plus sombre) et 9 (la plus proche du plafond) — c'est lui,
## pas l'indice dans le tableau, qui pilote le gris, pour pouvoir réordonner le
## tableau sans redistribuer les gris.
const CLASSES: Array[Dictionary] = [
	{
		"slug": "pistolet", "libelle": "Le Parasite", "gris_rang": 3, "echelle": 0.97,
		"arme": {"largeur": 0.05, "hauteur": 0.06, "longueur": 0.14},
		"gadget_slug": "gresillement", "gadget_libelle": "Le grésillement",
		"gadget": {"largeur": 0.10, "hauteur": 0.06, "longueur": 0.08},
	},
	{
		"slug": "fusil", "libelle": "L'Illusionniste", "gris_rang": 6, "echelle": 1.00,
		"arme": {"largeur": 0.045, "hauteur": 0.06, "longueur": 0.30},
		"gadget_slug": "leurre", "gadget_libelle": "Le leurre inerte",
		"gadget": {"largeur": 0.12, "hauteur": 0.05, "longueur": 0.10},
	},
	{
		"slug": "pompe", "libelle": "Le Terrassier", "gris_rang": 1, "echelle": 1.08,
		"arme": {"largeur": 0.06, "hauteur": 0.07, "longueur": 0.26},
		"gadget_slug": "poussiere", "gadget_libelle": "La poussière",
		"gadget": {"largeur": 0.08, "hauteur": 0.10, "longueur": 0.08},
	},
	{
		"slug": "arbalete", "libelle": "Le Braconnier", "gris_rang": 5, "echelle": 1.00,
		"arme": {"largeur": 0.09, "hauteur": 0.08, "longueur": 0.22},
		"gadget_slug": "torche_fantome", "gadget_libelle": "La torche fantôme",
		"gadget": {"largeur": 0.07, "hauteur": 0.14, "longueur": 0.07},
	},
	{
		"slug": "fumiste", "libelle": "Le Fumiste", "gris_rang": 2, "echelle": 1.05,
		"arme": {"largeur": 0.06, "hauteur": 0.07, "longueur": 0.17},
		"gadget_slug": "cartouche_suie", "gadget_libelle": "La cartouche de suie",
		"gadget": {"largeur": 0.06, "hauteur": 0.10, "longueur": 0.06},
	},
	{
		"slug": "incendiaire", "libelle": "L'Incendiaire", "gris_rang": 8, "echelle": 1.02,
		"arme": {"largeur": 0.07, "hauteur": 0.08, "longueur": 0.16},
		"gadget_slug": "nappe_braises", "gadget_libelle": "La nappe de braises",
		"gadget": {"largeur": 0.11, "hauteur": 0.07, "longueur": 0.09},
	},
	{
		"slug": "sentinelle", "libelle": "La Sentinelle", "gris_rang": 4, "echelle": 0.98,
		"arme": {"largeur": 0.04, "hauteur": 0.05, "longueur": 0.38},
		"gadget_slug": "poudre_contact", "gadget_libelle": "La poudre de contact",
		"gadget": {"largeur": 0.09, "hauteur": 0.09, "longueur": 0.07},
	},
	{
		"slug": "occulteur", "libelle": "L'Occulteur", "gris_rang": 0, "echelle": 0.95,
		"arme": {"largeur": 0.055, "hauteur": 0.07, "longueur": 0.18},
		"gadget_slug": "ombre_habitee", "gadget_libelle": "L'ombre habitée",
		"gadget": {"largeur": 0.12, "hauteur": 0.10, "longueur": 0.03},
	},
	{
		"slug": "allumeur", "libelle": "L'Allumeur", "gris_rang": 9, "echelle": 1.03,
		"arme": {"largeur": 0.075, "hauteur": 0.075, "longueur": 0.28},
		"gadget_slug": "mine_magnesium", "gadget_libelle": "La mine au magnésium",
		"gadget": {"largeur": 0.10, "hauteur": 0.05, "longueur": 0.10},
	},
	{
		"slug": "spectre", "libelle": "Le Spectre", "gris_rang": 7, "echelle": 0.96,
		"arme": {"largeur": 0.04, "hauteur": 0.05, "longueur": 0.24},
		"gadget_slug": "voile", "gadget_libelle": "Le voile",
		"gadget": {"largeur": 0.08, "hauteur": 0.16, "longueur": 0.08},
	},
]

## Facteur de gris pour un rang 0..9 : de 55 % à 85 % du plafond, linéaire.
static func _facteur_gris(rang: int) -> float:
	return lerpf(0.55, 0.85, float(rang) / 9.0)

## Les dix slugs, dans l'ordre du catalogue.
static func slugs() -> PackedStringArray:
	var out := PackedStringArray()
	for c in CLASSES:
		out.append(c["slug"])
	return out

## La fiche complète d'une classe : charpente commune + ce qui lui est propre,
## couleur calculée. Dictionnaire vide et `push_error` si le slug est inconnu —
## un repli plausible (la première classe, par exemple) cacherait une faute de
## frappe d'appelant derrière un corps qui a l'air correct.
static func fiche(slug: String) -> Dictionary:
	for c in CLASSES:
		if c["slug"] == slug:
			var f := SQUELETTE.duplicate(true)
			for cle in c:
				f[cle] = c[cle]
			f["couleur"] = GRIS_PLAFOND * _facteur_gris(c["gris_rang"])
			return f
	push_error("VoxelCatalogue : classe inconnue « %s » (connues : %s)"
		% [slug, ", ".join(slugs())])
	return {}
