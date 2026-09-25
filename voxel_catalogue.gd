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

## Le drapeau des corps d'après les dix portraits, éteint par défaut (sans lui, la tenue du jeu : `TENUE_PAR_DEFAUT`).
const DRAPEAU_PORTRAITS := "--corps=portraits"
## ISO12 — les TENUES SOMBRES (ordre de la session cloud, 2026-09-23 20:43, après la réponse d'Adrien à Q21 : « il faudrait
## que les personnages soient en tenue sombre. Dans tous les visuels. »), en trois variantes (`TENUES_SOMBRES`) :
## `--corps=sombre` (V1), `--corps=sombre2` (V2), `--corps=sombre3` (V3). V3 est la tenue du jeu depuis le 2026-09-24
## (`TENUE_PAR_DEFAUT`).
const DRAPEAU_SOMBRE := "--corps=sombre"

## Pour les suites (`--script`, sans ligne de commande de jeu) : -1 lit la ligne de commande, 0 impose le gris, 1 les portraits.
static var forcer_portraits := -1
## Pour les suites et les bancs : `"-"` lit la ligne de commande ; sinon la tenue imposée (`""` le gris, `"portraits"`,
## `"sombre1"`, `"sombre2"`, `"sombre3"`). Prime sur `forcer_portraits`.
static var forcer_tenue := "-"

## LA TENUE DU JEU (décision d'Adrien, 2026-09-24, Q21 et Q23 : « J'aime bien V3 froide », « Et en jeu la V3 sombre », puis
## pour la teinte en jeu, à 12:42 : « V3 froide ») : V3 — tissu sombre, arêtes claires — en teinte froide, pour les deux
## joueurs, en écran scindé comme en ligne, comme dans les illustrations. Le gris d'ISO3 reste joignable pour comparer :
## `--corps=gris` (et `--teinte=olive` pour l'ancienne teinte des tenues sombres).
const TENUE_PAR_DEFAUT := "sombre3"
const DRAPEAU_GRIS := "--corps=gris"


## La tenue des corps : `TENUE_PAR_DEFAUT` sans drapeau ; `""` (le gris d'ISO3, `--corps=gris`), `"portraits"` ou l'une des
## `TENUES_SOMBRES`.
static func tenue() -> String:
	if forcer_tenue != "-":
		return forcer_tenue
	if forcer_portraits >= 0:
		return "portraits" if forcer_portraits == 1 else ""
	return tenue_de(OS.get_cmdline_user_args())


## La tenue que nomme une ligne de commande (la première qui en nomme une) : `TENUE_PAR_DEFAUT` si aucune.
static func tenue_de(args: PackedStringArray) -> String:
	for a in args:
		if a == DRAPEAU_GRIS:
			return ""
		if a == DRAPEAU_PORTRAITS:
			return "portraits"
		if a == DRAPEAU_SOMBRE:
			return "sombre1"
		if a.begins_with(DRAPEAU_SOMBRE) and TENUES_SOMBRES.has("sombre" + a.trim_prefix(DRAPEAU_SOMBRE)):
			return "sombre" + a.trim_prefix(DRAPEAU_SOMBRE)
	return TENUE_PAR_DEFAUT


## Une tenue PEINTE est-elle portée (portraits ou sombre) : c'est ce que lisent `VoxelCorps` et les bancs (temps figé, prise
## grise sur les mêmes matériaux). Le nom date des portraits.
static func portraits_actifs() -> bool:
	return tenue() != ""


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

## ⚠️ **LA PEINTURE CHANGE LA COULEUR, JAMAIS LA VISIBILITÉ** (exigence d'équité de la session cloud, 2026-09-23 01:49 :
## « jamais plus sombre », et aussi « jamais plus clair »). Toutes les couleurs d'une classe ont la clarté À L'ÉCRAN exacte
## du gris de sa classe : plâtre, rouille, sangles, arme, cartouches, bouteille ne diffèrent que par la TEINTE et la
## SATURATION. Pourquoi pas une patine plus sombre compensée par un plâtre plus clair, de moyenne 1 : la moyenne d'un corps
## est pondérée par ses pixels les plus éclairés, qui ne sont pas les mêmes à toute lumière (à 0,8 les dessus butent sur le
## plafond de la fiche, à 0,2 non) — mesuré au banc des corps (2026-09-23 01:36) : 0,98-1,05 du gris à 0,8, mais 1,00-1,18
## à 0,2 et 1,04-1,33 à 0,15, un écart qui variait d'une classe à l'autre. L'encre et le modelé, identiques au gris, restent
## les seules variations de clarté.
## Les sangles, la poche et l'arme sont des bruns DÉSATURÉS (leur teinte mêlée de gris) : à clarté égale, c'est ce qui les
## détache du plâtre saturé et de la rouille plus rouge.
const DESATURATION_SANGLE := 0.55
const DESATURATION_ARME := 0.3

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
	# Un canal ne dépasse jamais 1 : une teinte très saturée y perd un peu de clarté, jamais n'en gagne.
	return Color(minf(teinte.r * k, 1.0), minf(teinte.g * k, 1.0), minf(teinte.b * k, 1.0))


## Les couleurs d'une classe (valeurs sRGB, posées dans des uniformes `source_color`), TOUTES à la clarté à l'écran du gris
## d'ISO3 de la classe (voir `DESATURATION_SANGLE`) : la visibilité d'un corps peint est celle du gris, à toute lumière.
static func palette_portrait(slug: String) -> Dictionary:
	var f := fiche(slug)
	if f.is_empty() or not PORTRAITS.has(slug):
		return {}
	var p: Dictionary = PORTRAITS[slug]
	var use := float(p["usure"]) > 0.5
	var gris: Color = f["couleur"]
	var l := luminance_affichee(gris)
	var cartouche := Color(0, 0, 0, 0)
	if p["cartouches"] == "grise":
		cartouche = a_luminance(TEINTE_CARTOUCHE_GRISE, l)
	elif p["cartouches"] == "rouge":
		cartouche = a_luminance(TEINTE_CARTOUCHE_ROUGE, l)
	return {
		"ocre": a_luminance(TEINTE_OCRE_USE if use else TEINTE_OCRE, l),
		# La rouille des usés (69, 39, 24) a presque la chromaticité de leur plâtre (écart 0,04) : à clarté égale elle ne se
		# verrait plus. La rouille rouge des portraits clairs, pour tous.
		"rouille": a_luminance(TEINTE_ROUILLE, l),
		"brun": a_luminance(TEINTE_BRUN.lerp(gris, DESATURATION_SANGLE), l),
		"arme": a_luminance(TEINTE_ARME.lerp(gris, DESATURATION_ARME), l),
		"bouteille": a_luminance(TEINTE_BOUTEILLE, l),
		"cartouche": cartouche,
		"usure": float(p["usure"]),
		"bouteille_portee": bool(p["bouteille"]),
	}


## ISO12 — LES TENUES SOMBRES. Même mécanisme que les portraits (la teinte posée APRÈS la pâte, en valeurs affichées : la
## lumière décide seule où un corps se voit), mais chaque rôle porte ici un RAPPORT de clarté au gris de sa classe, au lieu
## de 1 : c'est ce rapport qui rend une tenue sombre, et c'est lui que le banc des corps chiffre (clarté peinte / grise).
## Les rôles : `tissu` (le plâtre des portraits), `usure` (sa patine : un tissu passé, par taches, vers le bas et aux arêtes),
## `cuir` (sangles, ceinture, poche, cerclage et vanne de la bouteille), `arme`, `bouteille`, `cartouche`, et deux rôles
## neufs : `tete` (la tête entière) et `arete` (un liseré le long des arêtes des boîtes, large de `arete_px` pixels du monde ;
## rapport 0 = pas de liseré).
## - **V1 — sombre à l'œil, aussi visible qu'aujourd'hui** : tissus sombres, tête et liseré clairs, réglés pour qu'un corps
##   garde en moyenne la clarté de son gris (critère 2 : à 3 % près), mesuré au banc des corps.
## - **V2 — vraiment sombre** : tout plus sombre que le gris, aucun accent clair ; l'adversaire se voit moins.
## - **V3 — sombre, silhouette gardée** : les tissus de V2 et le liseré clair de V1, sans la tête claire — entre les deux.
## ⚠️ Un rapport > 1 n'éclaire jamais un pixel noir : `portrait_teindre` ne teint pas sous 10/255 (il n'y fait qu'assombrir,
## quand le rapport est < 1 et que `sous_seuil` le permet). Le noir absolu tient par construction ; le banc le vérifie.
## ⚠️ Et rien ne dépasse `Charte.DIM` (`GRIS_PLAFOND`, « aucune classe ne peut être rendue plus claire que ça ») : la tête et
## le liseré clairs de V1 y sont bornés, ce qui laisse aux classes claires (l'Allumeur est à 0,85 du plafond) bien moins de
## marge qu'aux sombres (l'Occulteur à 0,55).
## `sous_seuil` : sous le seuil du noir, le gris assombri du rapport du pixel (V2, V3) ou laissé tel quel (V1 : sa promesse
## est la visibilité d'aujourd'hui, et c'est là, au pied de l'échelle, qu'on commence à voir un adversaire). `seuils` : où la
## teinte commence et où elle est entière, en valeurs affichées (10/255 et 24/255 pour les portraits, V2 et V3).
## ⚠️ **Pourquoi V1 teint plus haut (16/255 → 32/255), mesuré au banc des corps (2026-09-23, 20:52)** : l'image affichée
## ÉCRASE les valeurs très sombres. Un pixel gris à 1-4 niveaux, assombri de 38 %, sort à 0 ; à 4-8 niveaux il garde 22 % de
## sa valeur au lieu de 62 %. Dans la bande de fondu, un tissu sombre y perd donc bien plus que son rapport, quand la tête et
## le liseré clairs gagnent le leur : V1 réglé à 1,00 à 0,8 sortait à 0,89-0,97 à 0,2 (Allumeur, Incendiaire, Spectre, Illusionniste).
## Teinte plus haut, V1 laisse la lumière faible au gris d'aujourd'hui, et n'est sombre qu'en bonne lumière.
## Le réglage de V1 (même banc, même soirée) : la part de la clarté d'un corps portée par la tête et le liseré vaut 0,63 à
## 0,67 selon la classe (le dessus de la tête est la face la plus éclairée de la vue iso) ; avec le reste au rapport de V2,
## une tête et un liseré à 1,2 fois le gris rendent la clarté du gris à 0,8. L'Allumeur est borné par `Charte.DIM` à 1,18.
const TENUES_SOMBRES := {
	"sombre1": {"tissu": 0.62, "usure": 0.74, "cuir": 0.46, "arme": 0.52, "bouteille": 0.9, "cartouche": 0.95,
		"tete": 1.2, "arete": 1.2, "arete_px": 1.6, "sous_seuil": false, "seuils": Vector2(16.0, 32.0) / 255.0},
	"sombre2": {"tissu": 0.62, "usure": 0.74, "cuir": 0.46, "arme": 0.52, "bouteille": 0.8, "cartouche": 0.85,
		"tete": 0.7, "arete": 0.0, "arete_px": 0.0, "sous_seuil": true, "seuils": Vector2(10.0, 24.0) / 255.0},
	"sombre3": {"tissu": 0.62, "usure": 0.74, "cuir": 0.46, "arme": 0.52, "bouteille": 0.8, "cartouche": 0.85,
		"tete": 0.7, "arete": 1.2, "arete_px": 1.6, "sous_seuil": true, "seuils": Vector2(10.0, 24.0) / 255.0},
}
## Les teintes des tenues sombres (seule leur chromaticité sert : la clarté vient du rapport) : un drap olive éteint, passé
## vers le brun à l'usure, un cuir brun noir, un métal bleuté pour l'arme et la bouteille, une tête et un liseré couleur d'os
## (la bouteille pâle des portraits).
const TEINTE_TISSU_SOMBRE := Color8(58, 62, 50)
const TEINTE_USURE_SOMBRE := Color8(96, 86, 66)
const TEINTE_CUIR_SOMBRE := Color8(44, 30, 22)
const TEINTE_METAL_SOMBRE := Color8(70, 76, 84)
const TEINTE_OS := Color8(214, 204, 184)

## ISO12 — LA TEINTE DES TENUES SOMBRES (ordre de la session cloud, 2026-09-23 21:40), derrière son propre drapeau, éteint :
## `--teinte=froide`. Seule la chromaticité change ; chaque rôle garde son rapport de clarté (`TENUES_SOMBRES`).
## Pourquoi : à clarté égale, l'olive et l'os de V1 se détachaient MOINS du sol ocre que le gris bleuté d'aujourd'hui (ΔE76 au
## centre du cône, −4 à −35 % selon la classe, l'Occulteur de 8,9 à 5,8 ; banc de beauté, 21:13). L'ocre est orangé : ce qui
## s'en écarte le plus à clarté égale est le bleu. La froide met donc le drap, l'usure, le métal, la tête et le liseré dans les
## bleus-gris (un ardoise sombre, une tête et un liseré gris perle), et garde les cartouches (grises, rouges) et le cuir brun :
## ce sont des repères de classe, pas la tenue.
const DRAPEAU_TEINTE := "--teinte="
const TEINTES := {
	"olive": {"tissu": TEINTE_TISSU_SOMBRE, "usure": TEINTE_USURE_SOMBRE, "cuir": TEINTE_CUIR_SOMBRE,
		"metal": TEINTE_METAL_SOMBRE, "clair": TEINTE_OS},
	"froide": {"tissu": Color8(48, 58, 76), "usure": Color8(78, 88, 104), "cuir": TEINTE_CUIR_SOMBRE,
		"metal": Color8(62, 76, 98), "clair": Color8(190, 204, 224)},
}
## Pour les suites et les bancs : `""` lit la ligne de commande ; sinon la teinte imposée.
static var forcer_teinte := ""
## La teinte du jeu (décision d'Adrien, 2026-09-24, 12:42 : « V3 froide »).
const TEINTE_PAR_DEFAUT := "froide"


## ISO13, lot A — LE MANNEQUIN (`iso_corps_mannequin.gdshaderinc`) : segments, côté de la lumière, contour. Éteint par défaut,
## indépendant de la tenue. `forcer_mannequin` : -1 lit la ligne de commande, 0 l'éteint, 1 l'allume.
const DRAPEAU_MANNEQUIN := "--mannequin"
static var forcer_mannequin := -1
## La ligne de commande, lue une fois (-1 : pas encore).
static var _mannequin_ligne := -1
## Le contraste du côté de la lumière et le report sur les dessus (voir l'include) ; le plafond est `GRIS_PLAFOND`.
const MANNEQUIN_CONTRASTE := 0.4
const MANNEQUIN_REPORT := 1.6


## ISO13 — LE PERSONNAGE DÉTAILLÉ À L'ESSAI (ordre de la session cloud, 2026-09-24 16:46, après la question d'Adrien : les
## personnages peuvent-ils ressembler à leur portrait ?). Derrière `--corps-detaille`, éteint par défaut, une classe d'abord :
## le pistolet (Le Parasite), d'après son portrait V3 froide. Trois essais : les accessoires MODELÉS (`VoxelCorps._detailler`),
## une matière peinte douce à la taille du duel (`iso_corps_detail.gdshaderinc`), et le contour du lot B s'il sert.
## `forcer_detail` : -1 lit la ligne de commande (une fois), 0 l'éteint, 1 l'allume.
const DRAPEAU_DETAIL := "--corps-detaille"
static var forcer_detail := -1
static var _detail_ligne := -1
## Les classes détaillées à l'essai.
const CLASSES_DETAILLEES := ["pistolet"]
## Le laiton des cartouches, des manomètres et du robinet, lu au pixel sur le portrait V3 froide du pistolet (ISO Assets,
## `portrait_pistolet_v3froide.png`, les cartouches de la bandoulière). Seule sa chromaticité sert : sa clarté est le rapport
## « cartouche » de la tenue, comme les cartouches des autres classes — jamais plus claire que le gris de la classe.
const TEINTE_LAITON := Color8(152, 102, 59)


static func detail_actif() -> bool:
	if forcer_detail >= 0:
		return forcer_detail == 1
	if _detail_ligne < 0:
		_detail_ligne = 1 if OS.get_cmdline_user_args().has(DRAPEAU_DETAIL) else 0
	return _detail_ligne == 1


## Les couleurs des accessoires modelés pour une tenue : le cuir (sangle, étui), le laiton (cartouches, manomètres,
## robinet), le métal (la crosse du pistolet). `{}` pour le gris ou une classe sans portrait.
static func palette_details(slug: String, nom: String, nom_teinte := "") -> Dictionary:
	var p := palette_tenue(slug, nom, nom_teinte)
	if p.is_empty() or not p.has("rapports"):
		return {}
	var l := luminance_affichee(fiche(slug)["couleur"])
	return {"cuir": p["brun"], "laiton": a_luminance(TEINTE_LAITON, l * float((p["rapports"] as Dictionary)["cartouche"])),
		"metal": p["arme"]}


static func mannequin_actif() -> bool:
	if forcer_mannequin >= 0:
		return forcer_mannequin == 1
	# Lu une fois : la présentation le demande à chaque image, et `get_cmdline_user_args()` rend un tableau neuf à chaque appel
	# (question de coût de la session cloud, 01:13 — drapeau éteint, rien ne doit tourner sans servir).
	if _mannequin_ligne < 0:
		_mannequin_ligne = 1 if OS.get_cmdline_user_args().has(DRAPEAU_MANNEQUIN) else 0
		# La preuve, dans le journal, que le drapeau a porté dans CE lancement (demande d'ISO7 Gadgets pour ses séries de
		# cadence : un drapeau perdu se déguise en l'autre branche d'une comparaison). Même forme que « [faisceau] allumé ».
		if _mannequin_ligne == 1:
			print("[mannequin] allumé — les corps en mannequins (ISO13 lot A)")
	return _mannequin_ligne == 1


## La teinte des tenues sombres : `"froide"` (le défaut depuis la décision d'Adrien, 2026-09-24 — `TEINTE_PAR_DEFAUT`) ou
## `"olive"` (`--teinte=olive`, pour comparer).
static func teinte() -> String:
	if forcer_teinte != "":
		return forcer_teinte
	return teinte_de(OS.get_cmdline_user_args())


static func teinte_de(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with(DRAPEAU_TEINTE) and TEINTES.has(a.trim_prefix(DRAPEAU_TEINTE)):
			return a.trim_prefix(DRAPEAU_TEINTE)
	return TEINTE_PAR_DEFAUT


## ISO13 — L'ÉQUITÉ DE V3 ENTRE LES CLASSES (ordre de la session cloud, 2026-09-24 16:52). Les rôles de V3 sont un RAPPORT au
## gris de la classe, le même pour toutes (tissu 0,62…). Mais les gris des classes vont de 0,55 à 0,85 du plafond
## (`gris_rang`) : au bord de la lumière, 0,62 fois un gris sombre tombe sous ce que l'écran montre, 0,62 fois un gris clair
## non. À 0,15, V3 gardait 13 % des pixels visibles du gris pour l'Occulteur, 92 % pour l'Allumeur — un avantage de classe
## que la tenue avait créé. Un facteur par classe `g` multiplie les rapports sombres de V3 (tissu, usure, cuir, métal,
## bouteille, cartouches, tête), plafonnés à 1 : jamais plus clair que le gris de la classe, donc jamais visible plus tôt
## qu'aujourd'hui. Le liseré clair (rapport > 1) n'y est pas soumis. Les valeurs viennent du banc des corps (`--equite=`),
## rapportées dans la ROADMAP ; une classe absente vaut 1.
## Calibration du 2026-09-24, 18:45 (banc des corps, `--equite=` de 0,4 à 1,6, gris et V3 dans la même partie, à 0,15) : la
## réponse vient par marches (des faces entières franchissent le seuil de l'écran d'un coup) ; le g retenu est un point mesuré
## dans la bande quand il y en a un, interpolé sinon, puis vérifié au balayage complet.
const V3_EQUITE := {
	"pistolet": 1.05, "fusil": 0.87, "pompe": 1.26, "arbalete": 1.0, "fumiste": 1.2,
	"incendiaire": 0.8, "sentinelle": 1.05, "occulteur": 1.35, "allumeur": 0.8, "spectre": 0.83,
}
## Pour les bancs : < 0 lit `V3_EQUITE` ; sinon le même facteur pour toutes les classes (la calibration).
static var forcer_equite := -1.0


static func facteur_equite(slug: String, nom: String) -> float:
	if nom != "sombre3":
		return 1.0
	if forcer_equite >= 0.0:
		return forcer_equite
	return float(V3_EQUITE.get(slug, 1.0))


static func _rapport_equitable(r: float, g: float) -> float:
	return minf(r * g, maxf(r, 1.0))


## La palette de la tenue `nom` pour la classe `slug`, aux mêmes clés que `palette_portrait()` (plus `tete`, `arete`,
## `arete_px`, `rapports`) : `{}` pour le gris ou un nom inconnu. `nom_teinte` : `""` pour la teinte en cours (`teinte()`).
static func palette_tenue(slug: String, nom: String, nom_teinte := "") -> Dictionary:
	if nom == "portraits":
		return palette_portrait(slug)
	if not TENUES_SOMBRES.has(nom):
		return {}
	var f := fiche(slug)
	if f.is_empty() or not PORTRAITS.has(slug):
		return {}
	var p: Dictionary = PORTRAITS[slug]
	var r: Dictionary = TENUES_SOMBRES[nom]
	var te: Dictionary = TEINTES.get(nom_teinte if nom_teinte != "" else teinte(), TEINTES["olive"])
	var l := luminance_affichee(f["couleur"])
	# ISO13 — l'équité de V3 : un facteur par classe sur les rôles sombres, jamais au-dessus du gris (voir `V3_EQUITE`).
	var g := facteur_equite(slug, nom)
	var plafond := luminance_affichee(GRIS_PLAFOND)
	var cartouche := Color(0, 0, 0, 0)
	if p["cartouches"] == "grise":
		cartouche = a_luminance(TEINTE_CARTOUCHE_GRISE, l * _rapport_equitable(float(r["cartouche"]), g))
	elif p["cartouches"] == "rouge":
		cartouche = a_luminance(TEINTE_CARTOUCHE_ROUGE, l * _rapport_equitable(float(r["cartouche"]), g))
	var arete := Color(0, 0, 0, 0)
	if float(r["arete"]) > 0.0:
		arete = a_luminance(te["clair"], minf(l * float(r["arete"]), plafond))
	return {
		"ocre": a_luminance(te["tissu"], l * _rapport_equitable(float(r["tissu"]), g)),
		"rouille": a_luminance(te["usure"], l * _rapport_equitable(float(r["usure"]), g)),
		"brun": a_luminance(te["cuir"], l * _rapport_equitable(float(r["cuir"]), g)),
		"arme": a_luminance(te["metal"], l * _rapport_equitable(float(r["arme"]), g)),
		"bouteille": a_luminance(te["metal"], l * _rapport_equitable(float(r["bouteille"]), g)),
		"cartouche": cartouche,
		"tete": a_luminance(te["clair"] if float(r["tete"]) > 1.0 else te["tissu"],
			minf(l * (float(r["tete"]) if float(r["tete"]) > 1.0 else _rapport_equitable(float(r["tete"]), g)), plafond)),
		"arete": arete,
		"arete_px": float(r["arete_px"]),
		"sous_seuil": bool(r["sous_seuil"]),
		"seuils": r["seuils"],
		"usure": float(p["usure"]),
		"bouteille_portee": bool(p["bouteille"]),
		"rapports": r,
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
