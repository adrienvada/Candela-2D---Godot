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
## ISO3 vague 5 — répartition verticale mesurée sur le gabarit du DA
## (`gabarit_proportions_01.jpg`, ISO Assets), pas devinée : tête 28,4 %,
## torse 45,9 %, jambes 25,7 % de la hauteur totale (six lignes de guidage de
## l'image, détectées au pixel par PIL — voir ROADMAP, section « Vague 5 »),
## contre 21,3 %/34,0 %/44,7 % avant cette vague. Le total reste 0,94 (jamais
## touché, voir `hauteur_debout`) : `hauteur_jambe` + `hauteur_torse` +
## `hauteur_tete` = 0,39 + 0,335 + 0,215 = 0,94, une tête plus grande et un
## torse plus profond au prix de jambes plus courtes — le style « figurine
## trapue » du gabarit, jamais un simple agrandissement uniforme (qui aurait
## cassé `hauteur_debout`). **Choix retenu à mi-chemin du gabarit, pas
## deviné mais BUTÉ par deux tests qui ont fait reculer un premier essai plus
## proche du gabarit** (jambe à 0,30, torse à 0,38, tête à 0,26) : la
## fourchette accroupie (0,49-0,61) est passée à 0,611 et l'empreinte du
## corps seul à 19,5 px (contre 17,5 permis) — la vraie cause n'était pas la
## tête plus large mais le TORSE ET LA TÊTE plus hauts, qui, une fois penchés
## en accroupi (35°, +20° pour la tête), poussent plus loin en profondeur
## qu'avant ; l'ancien pire cas (le bras tendu, debout) n'était plus le pire
## une fois la tête et le torse assez hauts pour que leur inclinaison
## l'emporte. Reculé par petits pas, mesuré à chaque pas
## (`test_voxel_corps.gd`, jamais à l'œil), jusqu'à cette valeur : les deux
## contraintes tiennent avec une marge réelle (0,581 et 17,4 px au pire cas,
## voir ROADMAP). Le brief interdit de toucher aux postures déjà réglées
## (accroupi, enjambement) : ces deux constantes n'ont pas bougé, c'est la
## hauteur des boîtes qui a cédé du terrain à leur place.
const SQUELETTE := {
	"hauteur_corps": 1.0,
	"rayon_corps": 0.4,

	# Jambes : du sol jusqu'à l'entrejambe.
	"hauteur_jambe": 0.39,
	"largeur_jambe": 0.12,
	"profondeur_jambe": 0.12,
	"ecart_jambe": 0.08,          # demi-écart au centre

	# Torse : de l'entrejambe aux épaules.
	"y0_torse": 0.39,
	"hauteur_torse": 0.335,
	"largeur_torse": 0.28,
	"profondeur_torse": 0.16,

	# Tête : posée sur les épaules, sous le plafond de la tuile. `cote_tete`
	# monte de 0,19 à 0,20 (vague 5) — le gabarit du DA a une tête relativement
	# plus large que le corps (46 % de la largeur d'épaules mesurée, contre
	# 41 % avant cette vague) ; le bras tenu en avant reste le point le plus
	# éloigné du corps debout (voir `_construire_squelette`), cette tête plus
	# large ne menace donc pas le couloir d'une tuile à elle seule — vérifié,
	# pas supposé (voir le commentaire de `SQUELETTE` : c'est la hauteur de la
	# tête ET du torse, penchée en accroupi, qui a dû reculer, pas sa largeur).
	"y0_tete": 0.725,
	"hauteur_tete": 0.215,
	"cote_tete": 0.20,

	# Bras : pivot à l'épaule, boîte suspendue vers le bas par défaut (une
	# rotation de pose les relève, voir `voxel_corps.gd`).
	"y_epaule": 0.705,
	"longueur_bras": 0.26,
	"largeur_bras": 0.09,

	# Arme et torche : hauteur de main, en avant du torse. La torche est à
	# gauche (elle n'engage jamais la visée), l'arme à droite.
	"y_main": 0.5575,
	"avant_main": 0.30,
	"ecart_main": 0.13,

	# Torche : matériel standard, identique pour les dix classes.
	"torche": {"largeur": 0.05, "hauteur": 0.05, "longueur": 0.16},

	# Gadget : porté dans le dos, à hauteur de ceinture.
	"y_gadget": 0.43,
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


## ISO3 vague 4 — décision d'Adrien (2026-09-15, mot pour mot : « il faut que
## le volume de chaque joueur soit plus important... tant pis si ça touche
## leur hitbox ») : les corps grossissent en largeur et en profondeur pour
## retrouver la masse des planches du DA (`planche_palette_corps.jpg`,
## mesurée dans la ROADMAP, section « Vague 4 », avant d'écrire cette
## constante), JAMAIS en hauteur (la hauteur debout, la fourchette accroupie
## à 0,57 et le plafond de mur haut à 1,25 tuile n'en dépendent pas et ne
## doivent pas bouger). Multiplie `echelle` — qui ne joue déjà QUE sur les
## dimensions X/Z du squelette (voir `_construire_squelette()`), jamais Y —
## donc torse, tête, bras et jambes épaississent ensemble, dans les mêmes
## proportions relatives qu'avant entre les dix classes (la variation
## d'`echelle` PAR classe, elle, ne change pas : Le Terrassier, `echelle`
## le plus large du catalogue, reste visiblement plus large que L'Occulteur,
## le plus étroit, juste les deux plus épais qu'avant — vérifié par
## `tools/test_voxel_corps.gd`, pas supposé). `"leger"` (×1,0) est l'ancien
## gabarit (vague 0-3), gardé pour la planche avant/après et pour qui a
## besoin d'y revenir — jamais retiré.
const EPAISSEUR_REGLAGES := {
	"leger": 1.0,
	"x1_3": 1.3,
	"x1_6": 1.6,
	"x2_0": 2.0,
}

## Le réglage par défaut de tout `VoxelCorps.construire(slug)` qui n'en
## précise pas — donc de tout appelant déjà écrit (ISO2/ISO5, les bancs, la
## suite) sans qu'aucun n'ait à changer une ligne. Choisi par comparaison
## visuelle au banc contre `planche_palette_corps.jpg` (ROADMAP, section
## « Vague 4 ») — PAS deviné, et pas nécessairement définitif : Adrien
## tranche à H-ISO5 sur la planche `docs/iso/planche_corps_epais.png`.
const EPAISSEUR_PAR_DEFAUT := "x1_6"


# -----------------------------------------------------------------------------
# ISO12 — L'ASPECT DES CORPS D'APRÈS LES DIX PORTRAITS DE CLASSE
# -----------------------------------------------------------------------------

## Le drapeau de comparaison, éteint par défaut : sans lui, les corps restent les aplats gris d'ISO3.
const DRAPEAU_PORTRAITS := "--corps=portraits"

## Pour les suites (`--script`, sans ligne de commande de jeu) : -1 lit le drapeau, 0 l'éteint, 1 l'allume.
static var forcer_portraits := -1


static func portraits_actifs() -> bool:
	if forcer_portraits >= 0:
		return forcer_portraits == 1
	return OS.get_cmdline_user_args().has(DRAPEAU_PORTRAITS)


## Les teintes lues AU PIXEL sur les dix portraits (ISO Assets, `docs/iso/planches_gemini/habillage/portrait_<classe>.png`,
## fond vert écarté, pixels du corps rangés par clarté, moyennes des quantiles 30-60 % et 60-85 % ; mesure du 2026-09-22).
## Seule leur TEINTE sert : leur clarté est ramenée à celle de la classe par `palette_portrait()`.
## - le plâtre des portraits clairs (sept classes) : (237, 150, 55) ; sa rouille : (136, 53, 17) ; le brun des sangles : (66, 24, 6) ;
## - le plâtre des portraits usés (pistolet, occulteur, spectre) : (202, 115, 55) ; leur rouille : (69, 39, 24).
const TEINTE_OCRE := Color8(237, 150, 55)
const TEINTE_ROUILLE := Color8(136, 53, 17)
const TEINTE_OCRE_USE := Color8(202, 115, 55)
const TEINTE_ROUILLE_USE := Color8(69, 39, 24)
const TEINTE_BRUN := Color8(66, 24, 6)
## La bouteille pâle et les armes brunes des portraits (relevés à la main sur `portrait_allumeur` et `portrait_fusil`).
const TEINTE_BOUTEILLE := Color8(214, 204, 184)
const TEINTE_ARME := Color8(110, 62, 30)
const TEINTE_CARTOUCHE_GRISE := Color8(150, 150, 146)
const TEINTE_CARTOUCHE_ROUGE := Color8(178, 52, 38)

## Ce que chaque classe porte, lu sur son portrait : la bouteille dans le dos, les cartouches, l'usure.
const PORTRAITS := {
	"pistolet": {"bouteille": true, "cartouches": "", "usure": 1.0},
	"fusil": {"bouteille": false, "cartouches": "", "usure": 0.0},
	"pompe": {"bouteille": false, "cartouches": "", "usure": 0.0},
	"arbalete": {"bouteille": false, "cartouches": "", "usure": 0.0},
	"fumiste": {"bouteille": false, "cartouches": "grise", "usure": 0.0},
	"incendiaire": {"bouteille": true, "cartouches": "rouge", "usure": 0.0},
	"sentinelle": {"bouteille": true, "cartouches": "", "usure": 0.0},
	"occulteur": {"bouteille": true, "cartouches": "", "usure": 1.0},
	"allumeur": {"bouteille": true, "cartouches": "", "usure": 0.0},
	"spectre": {"bouteille": true, "cartouches": "", "usure": 1.0},
}

## La clarté de chaque pièce, en fraction de la luminance de la classe (le plâtre, 1, garde la visibilité du gris d'ISO3).
## Tout est plus sombre que le plâtre, sauf la bouteille — bornée, elle, par `Charte.DIM` (voir `palette_portrait`).
## ⚠️ La rouille des portraits est bien plus sombre (0,19 du plâtre, mesuré) ; à 0,19, les pieds de la classe la plus
## sombre (l'occulteur) tombaient sous la clarté du sol peint (`CandelaTileSet.SOL_DESSIN_B`) — le corps se serait fondu
## dans les dalles par le bas. 0,55 garde les pieds de l'occulteur à 1,2 fois la clarté sRGB du sol peint (vérifié par
## `tools/test_corps_portraits.gd` ; 0,5 suffisait tant que la palette se normalisait en linéaire).
const CLARTE_ROUILLE := 0.55
const CLARTE_BRUN := 0.22
const CLARTE_ARME := 0.45
const CLARTE_CARTOUCHE := 0.7
const CLARTE_BOUTEILLE := 1.25
## ⚠️ **La visibilité d'une classe, c'est la clarté MOYENNE de son corps, pas celle de son plâtre.** Posé à la clarté
## exacte du gris d'ISO3, le plâtre rendait des corps plus sombres de 20 à 26 % au banc des corps à 0,8 (moyennes des
## pixels du corps, 2026-09-22 23:59) — la rouille et les sangles ne font qu'assombrir. Le plâtre monte donc de ce que la
## patine retire en moyenne, sans jamais passer `Charte.DIM`. Depuis que le portrait teint après la pâte
## (`portrait_teindre`), le rapport portrait / gris est exactement celui des clartés affichées, à toute lumière : un seul
## facteur suffit (1/0,78 et 1/0,74 mesurés : 0,98 à 1,05 du gris à 0,8 au banc des corps, 2026-09-23 01:36).
const COMPENSATION_PATINE := 1.0 / 0.78
const COMPENSATION_PATINE_USEE := 1.0 / 0.74

## La bouteille dans le dos, en tuiles (× `echelle` en largeur et en profondeur, comme le reste du corps) : couchée en
## travers du haut du dos comme sur les portraits.
const BOUTEILLE := {"largeur": 0.2, "hauteur": 0.085, "profondeur": 0.07, "haut": 0.26}


## La clarté À L'ÉCRAN d'une couleur de fiche (poids de `IsoPate`, sur ses valeurs sRGB) : c'est l'espace où
## `portrait_teindre` fait son rapport, celui des octets de l'image. ⚠️ Normalisée d'abord en luminance linéaire, puis dans
## l'espace de `pate_vers_affiche`, une teinte saturée sortait plus sombre à l'écran qu'un gris de même « luminance » (au banc
## des corps, 2026-09-22 23:59 puis 2026-09-23 00:42).
static func luminance_affichee(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## `teinte` ramenée à la clarté `cible`, sa teinte gardée (échelle de ses valeurs sRGB).
static func a_luminance(teinte: Color, cible: float) -> Color:
	var k := cible / maxf(luminance_affichee(teinte), 0.000001)
	return Color(teinte.r * k, teinte.g * k, teinte.b * k)


## Les couleurs d'une classe (valeurs sRGB, posées dans des uniformes `source_color`) : le plâtre à la luminance de son
## gris d'ISO3 relevée de ce que la patine retire (`COMPENSATION_PATINE`), le reste en fraction de lui ; rien jamais
## au-dessus de `Charte.DIM`.
static func palette_portrait(slug: String) -> Dictionary:
	var f := fiche(slug)
	if f.is_empty() or not PORTRAITS.has(slug):
		return {}
	var p: Dictionary = PORTRAITS[slug]
	var use := float(p["usure"]) > 0.5
	var plafond := luminance_affichee(GRIS_PLAFOND)
	var gris := luminance_affichee(f["couleur"])
	var compensation: float = COMPENSATION_PATINE_USEE if use else COMPENSATION_PATINE
	var l: float = minf(gris * compensation, plafond)
	# ⚠️ Quand le plâtre bute sur `Charte.DIM` (les classes les plus claires : Allumeur, Incendiaire, Spectre), il ne compense
	# plus toute la patine, et le corps sortait plus sombre qu'aujourd'hui (le Spectre à 0,93 au banc, 2026-09-23 00:52) — ce
	# que l'équité interdit, surtout aux furtifs. La patine s'allège alors d'autant : la clarté moyenne passe avant l'usure.
	var patine := clampf((1.0 - gris / l) / (1.0 - 1.0 / compensation), 0.0, 1.0)
	var cartouche := Color(0, 0, 0, 0)
	if p["cartouches"] == "grise":
		cartouche = a_luminance(TEINTE_CARTOUCHE_GRISE, l * CLARTE_CARTOUCHE)
	elif p["cartouches"] == "rouge":
		cartouche = a_luminance(TEINTE_CARTOUCHE_ROUGE, l * CLARTE_CARTOUCHE)
	return {
		"ocre": a_luminance(TEINTE_OCRE_USE if use else TEINTE_OCRE, l),
		"rouille": a_luminance(TEINTE_ROUILLE_USE if use else TEINTE_ROUILLE, l * CLARTE_ROUILLE),
		"brun": a_luminance(TEINTE_BRUN, l * CLARTE_BRUN),
		"arme": a_luminance(TEINTE_ARME, l * CLARTE_ARME),
		"bouteille": a_luminance(TEINTE_BOUTEILLE, minf(l * CLARTE_BOUTEILLE, plafond)),
		"cartouche": cartouche,
		"usure": float(p["usure"]),
		"patine": patine,
		"bouteille_portee": bool(p["bouteille"]),
	}


## La fiche complète d'une classe : charpente commune + ce qui lui est propre,
## couleur calculée, `echelle` élargie par le réglage d'épaisseur (vague 4,
## voir `EPAISSEUR_REGLAGES`). Dictionnaire vide et `push_error` si le slug
## OU le réglage d'épaisseur est inconnu — un repli plausible (la première
## classe, l'échelle 1.0) cacherait une faute de frappe d'appelant derrière
## un corps qui a l'air correct.
static func fiche(slug: String, epaisseur: String = EPAISSEUR_PAR_DEFAUT) -> Dictionary:
	if not EPAISSEUR_REGLAGES.has(epaisseur):
		push_error("VoxelCatalogue : réglage d'épaisseur inconnu « %s » (connus : %s)"
			% [epaisseur, ", ".join(EPAISSEUR_REGLAGES.keys())])
		return {}
	for c in CLASSES:
		if c["slug"] == slug:
			var f := SQUELETTE.duplicate(true)
			for cle in c:
				f[cle] = c[cle]
			f["couleur"] = GRIS_PLAFOND * _facteur_gris(c["gris_rang"])
			f["echelle"] = float(f["echelle"]) * float(EPAISSEUR_REGLAGES[epaisseur])
			return f
	push_error("VoxelCatalogue : classe inconnue « %s » (connues : %s)"
		% [slug, ", ".join(slugs())])
	return {}
