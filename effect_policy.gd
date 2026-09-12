class_name EffectPolicy
extends RefCounted

## Ce qu'un joueur a le droit de régler dans les effets visuels, et ce qui ne
## se règle pas du tout.
##
## Dans un jeu dont la seule information est la lumière, baisser un effet est
## souvent un **avantage compétitif** : sans poussière une torche se repère
## moins bien, sans flash de bouche on encaisse le tir d'en face sans rien
## perdre, sans sang la touche ne se confirme plus. Mais imposer secousses et
## flashs à quelqu'un qui y est sensible n'est pas défendable non plus : c'est
## de l'accessibilité, pas une préférence.
##
## Trois familles, et le menu les montre dans cet ordre :
##
## - **Menus** — l'habillage des écrans. Ne se voit jamais pendant une manche,
##   n'apprend rien de personne. Un seul interrupteur pour les quinze.
## - **Confort** — obstrue l'écran de celui qui règle, pendant le match, sans
##   rien dire de l'adversaire. Quatre niveaux, plus un réglage par effet dans
##   les paramètres avancés.
## - **Monde** — ce que les DEUX joueurs lisent du duel. **Ne se règle pas.**
##
## ## Pourquoi le Monde ne se règle plus (décision d'Adrien, 2026-09-12)
##
## Il se réglait, jusqu'à un plancher proportionnel à la part d'information qui
## passait par l'effet — 80 % pour l'éblouissement, 20 % pour la poussière — et
## les planchers ne valaient qu'en classé. Le dispositif tenait, mais il
## répondait mal à la question qu'il posait : **il laissait douze curseurs
## négociables sur ce qui fait justement l'égalité entre les deux joueurs**, et
## la marge restante (de 100 % à 20 %) était assez large pour faire deux jeux
## différents. Un réglage qui influe sur le compétitif n'a pas de bon plancher ;
## il a une valeur commune, et c'est tout.
##
## Ce que ça simplifie, et qui vaut d'être dit : plus de plancher, donc plus de
## contexte classé à deviner, donc plus de « la même préférence rend deux
## valeurs selon le mode ». `curseur(id)` répond la même chose partout.
##
## ⚠️ Ce n'est toujours **pas** une mesure anti-triche : un client modifié fait
## ce qu'il veut, et aucune valeur écrite ici ne l'en empêchera. La table dit
## **dans quel jeu se joue un match** ; elle ne l'impose pas au binaire.
##
## ## Ajouter un effet
##
## Une entrée dans `EFFECTS`, et rien d'autre : l'écran, la persistance et les
## tests parcourent tous la table. Une entrée sans famille ou sans phrase fait
## échouer `tools/test_effect_policy.gd`.

## Trois familles, et il n'en existe pas de quatrième : un effet qu'on n'arrive
## pas à ranger est un effet qu'on n'a pas fini de comprendre.
##
## ⚠️ **Menus et Confort ont longtemps été une seule famille**, séparées par un
## simple commentaire au milieu de la table. Ça a tenu tant que l'écran affichait
## trente-quatre curseurs à la file ; dès qu'il a fallu un interrupteur pour les
## uns et quatre niveaux pour les autres, le commentaire ne suffisait plus — un
## découpage que le code ne porte pas est un découpage qui se perd au premier
## effet ajouté au mauvais endroit.
enum Family { MENUS, CONFORT, MONDE }

const MIN := 0.0
const MAX := 1.0
## Intensité d'un effet jamais réglé : le jeu tel qu'il a été écrit.
const DEFAULT := 1.0

## Les quatre niveaux du confort, et leur nom tel que le joueur le lit.
##
## Ce ne sont pas des crans de curseur : ce sont les seules valeurs que l'écran
## simple sait poser. Un réglage pris dans les paramètres avancés peut tomber
## entre deux — l'écran l'affiche alors comme « personnalisé » plutôt que de
## l'arrondir, parce qu'arrondir effacerait silencieusement un choix.
const NIVEAUX: Array[float] = [0.0, 0.35, 0.70, 1.0]
const NOMS_NIVEAUX: Array[String] = ["NUL", "FAIBLE", "MOYEN", "ÉLEVÉ"]

## Écart en deçà duquel une intensité EST un niveau. Les valeurs viennent de
## `percent_to_intensity()`, donc d'une division par 100 : la comparaison doit
## tolérer l'arrondi du flottant, et rien de plus.
const TOLERANCE_NIVEAU := 0.001

const EFFECTS := {
	# --- Confort : votre écran, vos affaires -------------------------------
	# Vague M — la vitrine des menus. Plancher 0.0 sans discussion : ces effets
	# n'apprennent rien, ne se voient jamais en match, et n'existent que pour le
	# plaisir de qui les garde.
	"cadran_titre": {
		"famille": Family.MENUS,
		"nom": "Cadran de titre",
		"phrase": "Le titre porte une ombre qui tourne avec le temps passé au menu. Purement décoratif.",
	},
	"remanence_curseur": {
		"famille": Family.MENUS,
		"nom": "Rémanence du curseur",
		"phrase": "Le curseur laisse une après-image là où il était, comme une lumière vive sur la rétine.",
	},
	"torche_menu": {
		"famille": Family.MENUS,
		"nom": "Torche du curseur",
		"phrase": "Le curseur porte une flaque de lumière qui le suit. Elle n'éclaire rien qu'on ne voyait pas.",
	},
	"regard_du_noir": {
		"famille": Family.MENUS,
		"nom": "Le regard du noir",
		"phrase": "Après un long silence, deux reflets peuvent apparaître dans le noir du menu. Ils ne font rien.",
	},
	"passant_vitre": {
		"famille": Family.MENUS,
		"nom": "Quelqu'un derrière la vitre",
		"phrase": "Une lueur passe parfois derrière les panneaux du menu, comme une torche de l'autre côté d'un verre.",
	},
	"encre_coulee": {
		"famille": Family.MENUS,
		"nom": "L'encre coulée",
		"phrase": "Un écran de menu s'écrit ligne à ligne au lieu d'apparaître d'un bloc. Purement décoratif.",
	},
	"gravure_code": {
		"famille": Family.MENUS,
		"nom": "Le code gravé",
		"phrase": "Le code de salon se frappe caractère par caractère au lieu de s'afficher. Le code reste le même.",
	},
	# `arene_au_repos` a été RETIRÉ le 2026-09-11 : il réglait `menu_arene.gd`,
	# que le hub n'instancie plus depuis le 2026-08-27 (les écrans de mode
	# passent par des illustrations). Un curseur qui règle un composant absent
	# est un curseur qui ment ; Adrien a demandé que chaque curseur agisse.
	"extinction_menu": {
		"famille": Family.MENUS,
		"nom": "L'extinction des feux",
		"phrase": "Ouvrir et fermer un menu passe par un battement de noir au lieu d'un basculement sec.",
	},
	"depart_au_tir": {
		"famille": Family.MENUS,
		"nom": "Le départ au tir",
		"phrase": "Lancer une partie tire une traçante dans le menu. N'apparaît que sur le bouton qui engage.",
	},
	"brume_menu": {
		"famille": Family.MENUS,
		"nom": "La brume d'abysse",
		"phrase": "Le fond des menus devient une pénombre qui bouge, et glisse un peu à l'opposé du curseur.",
	},
	"bruit_de_l_oeil": {
		"famille": Family.MENUS,
		"nom": "Le bruit de l'œil",
		"phrase": "Une granulation fourmille à la lisière de la lumière du curseur, comme un œil qui force dans le noir.",
	},
	"titre_vivant": {
		"famille": Family.MENUS,
		"nom": "Le titre incandescent",
		"phrase": "Le titre respire comme une braise et prend feu à l'ouverture du menu. Le texte ne change pas.",
	},
	"voile_menu": {
		"famille": Family.MENUS,
		"nom": "Le voile d'objectif",
		"phrase": "Les menus semblent filmés : un grain fin, une vignette douce, une frange colorée dans les coins.",
	},
	"balayage_attente": {
		"famille": Family.MENUS,
		"nom": "Les squelettes de lumière",
		"phrase": "Un tableau qui attend le réseau montre des barres balayées par une lueur, au lieu d'un texte figé.",
	},
	"verre_panneaux": {
		"famille": Family.MENUS,
		"nom": "Le verre fumé",
		"phrase": "Le cadre de droite et les rangées de réglage prennent une matière de vitre. Le texte reste net.",
	},
	"secousse_camera": {
		"famille": Family.CONFORT,
		"nom": "Secousse de caméra",
		"phrase": "Secoue votre vue, jamais celle d'en face. Rien ne vous oblige à la garder.",
	},
	"recul_camera": {
		"famille": Family.CONFORT,
		"nom": "Recul de caméra au tir",
		"phrase": "Le cadrage repart en arrière au coup de feu. C'est du toucher, pas de l'information.",
	},
	"vignette_degats": {
		"famille": Family.CONFORT,
		"nom": "Vignette de dégâts",
		"phrase": "Le rouge aux bords de VOTRE écran quand vous encaissez. Vos points de vie sont déjà affichés ailleurs.",
	},
	"flash_mort": {
		"famille": Family.CONFORT,
		"nom": "Flash de mort",
		"phrase": "Le blanc et l'aberration au moment fatal. La manche est finie : plus rien ne se joue derrière.",
	},
	"tremblement_interface": {
		"famille": Family.CONFORT,
		"nom": "Tremblements de l'interface",
		"phrase": "Chiffres et jauges qui sursautent. Décoratif de bout en bout.",
	},
	"grain_killcam": {
		"famille": Family.CONFORT,
		"nom": "Grain de la killcam",
		"phrase": "Grain et balayage du rejeu. Chacun rejoue son propre enregistrement, après coup.",
	},
	"vibration_manette": {
		"famille": Family.CONFORT,
		"nom": "Vibrations de la manette",
		"phrase": "Ne sort pas de vos mains. Coupez-la sans y penser.",
	},

	# --- Monde : la langue commune du match --------------------------------
	"eblouissement": {
		"famille": Family.MONDE,
		"nom": "Éblouissement",
		"phrase": "L'éblouissement est une pénalité, pas une décoration : il vous handicape quand une lumière vous prend. L'annuler changerait le handicap en avantage.",
	},
	# DA5.5 — posée ici pour rester à côté de ce qu'elle habille. Deux lectures
	# étaient possibles (docs/ROADMAP.md, DA5.5) : CONFORT, sur le modèle de
	# `flash_mort`, parce que l'aberration ne porte aucune direction (déjà
	# donnée par `lueurs_derive`/`flares_penche`, non réglables) ; ou MONDE,
	# parce qu'elle fait partie de ce que montre l'éblouissement et pas d'un
	# habillage à part. **Adrien a tranché pour MONDE le 2026-09-09**, et cette
	# décision-là a survécu à la suppression des planchers : la famille dit
	# maintenant « non réglable », ce qui est la lecture MONDE poussée au bout.
	"aberration_eblouissement": {
		"famille": Family.MONDE,
		"nom": "Frange de l'éblouissement",
		"phrase": "Fait partie de ce que montre l'éblouissement, pas un habillage à part. La couper changerait l'expérience de la pénalité d'un joueur à l'autre : elle reste donc identique pour les deux.",
	},
	"silhouette_revelee": {
		"famille": Family.MONDE,
		"nom": "Silhouette révélée au tir",
		"phrase": "Tirer, c'est se montrer. Effacer cette silhouette rendrait l'adversaire invisible à l'instant précis où le jeu veut qu'il soit vu.",
	},
	"flash_de_tir": {
		"famille": Family.MONDE,
		"nom": "Flash de bouche",
		"phrase": "Être ébloui par le tir d'en face est le prix à payer pour savoir où il est. Baisser le flash échangerait ce prix contre un avantage.",
	},
	"trait_de_balle": {
		"famille": Family.MONDE,
		"nom": "Trait de balle",
		"phrase": "La balle éclaire sa trajectoire : c'est ce qui dit d'où l'on vous tire dessus. Elle reste lisible pour les deux.",
	},
	"lumiere_impact": {
		"famille": Family.MONDE,
		"nom": "Lumière d'impact",
		"phrase": "Toucher éclaire la pièce une seconde : l'un est révélé, l'autre est ébloui. Supprimer cette lumière n'annulerait que la moitié gênante.",
	},
	"particules_sang": {
		"famille": Family.MONDE,
		"nom": "Particules de sang",
		"phrase": "Le sang confirme la touche et éclaire le blessé. C'est une information de match, pas un ornement.",
	},
	"eclats_impact": {
		"famille": Family.MONDE,
		"nom": "Éclats sur les murs",
		"phrase": "Les étincelles disent qu'un tir a manqué, et où il a frappé. Les couper effacerait la trace d'un tir raté.",
	},
	"traces_de_sang": {
		"famille": Family.MONDE,
		"nom": "Traces de sang au sol",
		"phrase": "Une trace dit qu'on s'est battu ici. Le noir garde peu de mémoire : celle-là reste.",
	},
	"poussiere_faisceau": {
		"famille": Family.MONDE,
		"nom": "Poussière dans le faisceau",
		"phrase": "La poussière rend un faisceau visible de côté : une torche se repère sans être pointée sur vous. L'effacer rendrait les torches plus discrètes.",
	},
	# Chantier FUSÉE (FU1). Le strobe d'agonie est une information de match (qui
	# a bougé entre deux flashs se lit par différence) : MONDE, donc non réglable.
	# À intensité réduite, les flashs s'aplatissent sur un fondu continu — le
	# TEMPO reste porté par le son, identique pour tous, pour que la variante
	# photosensibilité ne retire aucune information de timing (fusee_modele.gd).
	"fusee_agonie": {
		"famille": Family.MONDE,
		"nom": "Agonie de la fusée",
		"phrase": "Les derniers flashs d'une fusée photographient la pièce pour les deux joueurs. Les aplatir n'éteint que l'image : le rythme reste dans le son.",
	},
	# Chantier FUSÉE (FU3). Un tir depuis l'intérieur du nuage dilue le flash de
	# bouche dans toute la fumée : la position du tireur devient plus dure à
	# lire. Un joueur qui l'annulerait retrouverait un flash ponctuel — la
	# lecture la plus favorable — donc MONDE, donc non réglable.
	"fusee_diffusion": {
		"famille": Family.MONDE,
		"nom": "Diffusion du flash dans la fumée",
		"phrase": "Tirer depuis le nuage fait pulser toute la fumée au lieu du seul canon : ça dilue la position du tireur pour les deux joueurs. L'aplatir rendrait le flash ponctuel, donc plus facile à lire.",
	},
}

# ---------------------------------------------------------------------------
# LECTURE DE LA TABLE
# ---------------------------------------------------------------------------

## Identifiants dans l'ordre de la table — un dictionnaire GDScript conserve
## l'ordre d'insertion. C'est cet ordre que l'écran affiche : le classer
## autrement ferait bouger la liste au gré des renommages.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in EFFECTS:
		out.append(String(id))
	return out

static func ids_of_family(family: int) -> PackedStringArray:
	var out := PackedStringArray()
	for id in EFFECTS:
		if int(EFFECTS[id]["famille"]) == family:
			out.append(String(id))
	return out

## Les identifiants que le joueur peut effectivement régler — Menus et Confort,
## dans l'ordre de la table. C'est exactement ce que listent les paramètres
## avancés, et rien d'autre ne doit jamais apparaître sous un curseur.
static func ids_reglables() -> PackedStringArray:
	var out := PackedStringArray()
	for id in EFFECTS:
		if reglable(String(id)):
			out.append(String(id))
	return out

static func exists(id: String) -> bool:
	return EFFECTS.has(id)

## Famille de l'effet, ou -1 s'il est inconnu. Le -1 n'est pas un défaut de
## conception : un identifiant venu d'un fichier trafiqué ou d'une version plus
## récente n'a pas de famille, et le prétendre serait pire que l'admettre.
static func family_of(id: String) -> int:
	if not EFFECTS.has(id):
		return -1
	return int(EFFECTS[id]["famille"])

static func is_world(id: String) -> bool:
	return family_of(id) == Family.MONDE

## LA question de ce fichier : ce réglage appartient-il au joueur ?
##
## Non pour le Monde — il est commun aux deux joueurs — et non pour un
## identifiant inconnu, qui n'a plus de famille et donc plus personne pour
## trancher. Tout le reste se règle jusqu'à zéro.
static func reglable(id: String) -> bool:
	var famille := family_of(id)
	return famille == Family.MENUS or famille == Family.CONFORT

## Ce que le rendu doit APPLIQUER, depuis n'importe quel fichier du jeu.
##
## Le seul chemin vers l'intensité d'un effet en production : `GameSettings`.
## Sans réglages — suite en `--script`, outil, banc — la réponse est `DEFAULT`,
## le jeu tel qu'il a été écrit, jamais une erreur : un effet ne doit pas cesser
## de se dessiner parce qu'un autoload manque. **C'est ce chemin que
## `tools/test_curseurs_branches.gd` cherche dans le texte de chaque fichier** :
## quinze curseurs sur trente-quatre n'avaient aucun lecteur le 2026-09-09
## (audit DA5.1), et rien ne le disait.
##
## ⚠️ Les douze effets du Monde passent toujours par ici, et doivent continuer
## de le faire : ils rendent `DEFAULT` au lieu d'un réglage, mais le jour où
## l'un d'eux cesserait d'appeler ce chemin, plus rien ne vérifierait qu'il se
## dessine encore.
static func curseur(id: String) -> float:
	var boucle := Engine.get_main_loop() as SceneTree
	if boucle == null or boucle.root == null:
		return DEFAULT
	var gs := boucle.root.get_node_or_null(^"GameSettings")
	if gs == null or not gs.has_method("current_effect"):
		return DEFAULT
	return float(gs.current_effect(id))

static func label_of(id: String) -> String:
	if not EFFECTS.has(id):
		return id
	return String(EFFECTS[id]["nom"])

## La phrase lue par le joueur. Toujours présente, y compris pour un effet de
## confort : « pourquoi ce curseur va-t-il jusqu'à zéro » mérite une réponse
## autant que l'inverse.
static func reason_of(id: String) -> String:
	if not EFFECTS.has(id):
		return ""
	return String(EFFECTS[id]["phrase"])

# ---------------------------------------------------------------------------
# LA CONTRAINTE
# ---------------------------------------------------------------------------

## Valeur réellement applicable pour cet effet.
##
## Un effet du Monde rend `DEFAULT` **quoi qu'on lui passe** : c'est la seule
## porte par laquelle une intensité arrive au rendu, donc c'est ici que la règle
## « commun à tout le monde » se tient — et non dans l'écran, qui peut être
## contourné, ni dans la persistance, qui peut être réécrite à la main.
##
## Une valeur hors bornes est ramenée plutôt que refusée : un curseur mal
## calibré ou un fichier trafiqué ne doivent pas pouvoir fabriquer une intensité
## que le jeu ne sait pas rendre.
static func clamp_value(id: String, value: float) -> float:
	if not reglable(id):
		return DEFAULT
	if is_nan(value):
		return DEFAULT
	return clampf(value, MIN, MAX)

# ---------------------------------------------------------------------------
# LES QUATRE NIVEAUX DU CONFORT
# ---------------------------------------------------------------------------

## L'index du niveau qui correspond EXACTEMENT à cette intensité, ou -1.
##
## Le -1 se lit « personnalisé », et c'est une réponse et non un échec : un
## joueur venu des paramètres avancés a le droit d'être entre deux niveaux, et
## l'écran doit le dire au lieu de le déplacer.
static func niveau_de(value: float) -> int:
	if is_nan(value):
		return -1
	for i in NIVEAUX.size():
		if absf(value - NIVEAUX[i]) < TOLERANCE_NIVEAU:
			return i
	return -1

## Le niveau commun à toute une famille, ou -1 si ses effets divergent.
##
## C'est ce que l'écran simple affiche : quatre boutons dont un seul s'allume,
## aucun quand les réglages fins ne tombent pas tous sur le même niveau.
static func niveau_commun(valeurs: Array) -> int:
	if valeurs.is_empty():
		return -1
	var premier := niveau_de(float(valeurs[0]))
	if premier < 0:
		return -1
	for v in valeurs:
		if niveau_de(float(v)) != premier:
			return -1
	return premier

# ---------------------------------------------------------------------------
# CE QUE LE JOUEUR LIT
# ---------------------------------------------------------------------------
#
# Tout le texte destiné au joueur vit ici, à côté des valeurs qu'il explique.
# Le mettre dans l'écran garantirait qu'une règle changée un jour laisse
# derrière elle une phrase qui dit autre chose.

static func family_label(family: int) -> String:
	match family:
		Family.MENUS: return "Effets des menus"
		Family.CONFORT: return "Effets de confort"
		Family.MONDE: return "Effets du monde"
	return ""

## Règle de la famille, en une ligne, sous son titre.
static func family_rule(family: int) -> String:
	match family:
		Family.MENUS:
			return "L'habillage des écrans. Rien de tout cela n'apparaît pendant une manche."
		Family.CONFORT:
			return "N'obstrue que votre écran pendant le match. Réglable jusqu'à zéro."
		Family.MONDE:
			return "Ce que les deux joueurs lisent du duel. Identique pour tout le monde, et ne se règle pas."
	return ""

## Bandeau de contexte, en tête d'écran. Le joueur doit savoir ce qui n'est
## PAS dans cet écran avant d'y chercher un réglage qui n'y est plus.
static func context_line() -> String:
	return "Flash de bouche, trait de balle, sang, poussière, éblouissement : " \
		+ "ce que les deux joueurs lisent du duel est le même pour tout le monde " \
		+ "et ne se règle pas."

## Ligne affichée sous un curseur : la contrainte d'abord, sa raison ensuite.
static func constraint_line(id: String) -> String:
	if not EFFECTS.has(id):
		return ""
	var reason := reason_of(id)
	if reglable(id):
		return "Jusqu'à zéro. " + reason
	return "Commun aux deux joueurs. " + reason

# ---------------------------------------------------------------------------
# CURSEURS GRADUÉS DE 0 À 100
# ---------------------------------------------------------------------------
#
# Même choix que les volumes : l'échelle affichée est celle que le joueur
# manipule, la conversion reste à l'application.

static func intensity_to_percent(intensity: float) -> int:
	return int(round(clampf(intensity, MIN, MAX) * 100.0))

static func percent_to_intensity(percent: int) -> float:
	return clampf(float(percent) / 100.0, MIN, MAX)
