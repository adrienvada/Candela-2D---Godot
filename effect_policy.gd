class_name EffectPolicy
extends RefCounted

## Ce qu'un joueur a le droit de baisser dans les effets visuels, et jusqu'où.
##
## Dans un jeu dont la seule information est la lumière, désactiver un effet est
## presque toujours un **avantage compétitif** : sans secousse on vise mieux,
## sans vignette on voit plus d'écran une fois blessé, sans éblouissement on
## encaisse le flash adverse sans rien perdre. Si tout se coupe, tous les
## joueurs sérieux finissent par jouer avec un jeu nu — et le jeu qu'on a écrit
## n'est plus celui qui se joue en classé. Mais imposer secousses et flashs à
## quelqu'un qui y est sensible n'est pas défendable non plus : c'est de
## l'accessibilité, pas une préférence.
##
## La règle tranchée coupe entre les deux :
##
## - **Confort** — n'obstrue que l'écran de celui qui règle et n'apprend rien
##   sur l'adversaire. Réglable de 0 à 100 %, zéro compris, y compris en classé.
## - **Monde** — perçu par les deux joueurs, ou porteur d'information sur
##   l'adversaire. Réglable jusqu'à un **plancher**, jamais annulable en classé.
##
## En écran partagé, les planchers ne s'appliquent pas : rien n'y est en jeu.
## Même logique que le déblocage d'armes (décision du 2026-08-16).
##
## ## Ce que ce plancher n'est pas
##
## Ce n'est pas une mesure anti-triche : un client modifié fait ce qu'il veut, et
## aucune valeur écrite ici ne l'en empêchera. Le plancher dit **dans quel jeu se
## joue un match classé** ; il ne l'impose pas au binaire. Le traiter comme une
## sécurité conduirait à l'alourdir pour rien.
##
## ## L'échelle des planchers
##
## Le plancher est proportionnel à la part d'information du match qui passe par
## l'effet : 80 % pour l'éblouissement, qui est une pénalité de jeu déguisée en
## effet, 20 % pour la poussière, qui ne fait que rendre un faisceau visible de
## côté. Un effet dont on ne saurait pas dire quelle information il porte n'a
## rien à faire dans la famille Monde.
##
## ## Ajouter un effet
##
## Une entrée dans `EFFECTS`, et rien d'autre : l'écran, la persistance et les
## tests parcourent tous la table. Une entrée sans famille, sans phrase, ou dont
## le plancher contredit la famille fait échouer `tools/test_effect_policy.gd`.

## Deux familles, et il n'en existe pas de troisième : un effet qu'on n'arrive
## pas à ranger est un effet qu'on n'a pas fini de comprendre.
enum Family { CONFORT, MONDE }

const MIN := 0.0
const MAX := 1.0
## Intensité d'un effet jamais réglé : le jeu tel qu'il a été écrit.
const DEFAULT := 1.0

## La table. Une ligne = un effet.
##
## `phrase` n'est pas un commentaire de code, c'est le texte lu par le joueur
## sous le curseur. Un curseur qui refuse de descendre sans dire pourquoi passe
## pour un défaut, et se signale comme tel.
const EFFECTS := {
	# --- Confort : votre écran, vos affaires -------------------------------
	# Vague M — la vitrine des menus. Plancher 0.0 sans discussion : ces effets
	# n'apprennent rien, ne se voient jamais en match, et n'existent que pour le
	# plaisir de qui les garde.
	"cadran_titre": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Cadran de titre",
		"phrase": "Le titre porte une ombre qui tourne avec le temps passé au menu. Purement décoratif.",
	},
	"remanence_curseur": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Rémanence du curseur",
		"phrase": "Le curseur laisse une après-image là où il était, comme une lumière vive sur la rétine.",
	},
	"torche_menu": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Torche du curseur",
		"phrase": "Le curseur porte une flaque de lumière qui le suit. Elle n'éclaire rien qu'on ne voyait pas.",
	},
	"regard_du_noir": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Le regard du noir",
		"phrase": "Après un long silence, deux reflets peuvent apparaître dans le noir du menu. Ils ne font rien.",
	},
	"passant_vitre": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Quelqu'un derrière la vitre",
		"phrase": "Une lueur passe parfois derrière les panneaux du menu, comme une torche de l'autre côté d'un verre.",
	},
	"encre_coulee": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "L'encre coulée",
		"phrase": "Un écran de menu s'écrit ligne à ligne au lieu d'apparaître d'un bloc. Purement décoratif.",
	},
	"gravure_code": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Le code gravé",
		"phrase": "Le code de salon se frappe caractère par caractère au lieu de s'afficher. Le code reste le même.",
	},
	"extinction_menu": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "L'extinction des feux",
		"phrase": "Ouvrir et fermer un menu passe par un battement de noir au lieu d'un basculement sec.",
	},
	"depart_au_tir": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Le départ au tir",
		"phrase": "Lancer une partie tire une traçante dans le menu. N'apparaît que sur le bouton qui engage.",
	},
	"secousse_camera": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Secousse de caméra",
		"phrase": "Secoue votre vue, jamais celle d'en face. Rien ne vous oblige à la garder.",
	},
	"recul_camera": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Recul de caméra au tir",
		"phrase": "Le cadrage repart en arrière au coup de feu. C'est du toucher, pas de l'information.",
	},
	"vignette_degats": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Vignette de dégâts",
		"phrase": "Le rouge aux bords de VOTRE écran quand vous encaissez. Vos points de vie sont déjà affichés ailleurs.",
	},
	"flash_mort": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Flash de mort",
		"phrase": "Le blanc et l'aberration au moment fatal. La manche est finie : plus rien ne se joue derrière.",
	},
	"tremblement_interface": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Tremblements de l'interface",
		"phrase": "Chiffres et jauges qui sursautent. Décoratif de bout en bout.",
	},
	"grain_killcam": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Grain de la killcam",
		"phrase": "Grain et balayage du rejeu. Chacun rejoue son propre enregistrement, après coup.",
	},
	"vibration_manette": {
		"famille": Family.CONFORT,
		"plancher": 0.0,
		"nom": "Vibrations de la manette",
		"phrase": "Ne sort pas de vos mains. Coupez-la sans y penser.",
	},

	# --- Monde : la langue commune du match --------------------------------
	"eblouissement": {
		"famille": Family.MONDE,
		"plancher": 0.8,
		"nom": "Éblouissement",
		"phrase": "L'éblouissement est une pénalité, pas une décoration : il vous handicape quand une lumière vous prend. L'annuler changerait le handicap en avantage.",
	},
	"silhouette_revelee": {
		"famille": Family.MONDE,
		"plancher": 0.7,
		"nom": "Silhouette révélée au tir",
		"phrase": "Tirer, c'est se montrer. Effacer cette silhouette rendrait l'adversaire invisible à l'instant précis où le jeu veut qu'il soit vu.",
	},
	"flash_de_tir": {
		"famille": Family.MONDE,
		"plancher": 0.6,
		"nom": "Flash de bouche",
		"phrase": "Être ébloui par le tir d'en face est le prix à payer pour savoir où il est. Baisser le flash échangerait ce prix contre un avantage.",
	},
	"trait_de_balle": {
		"famille": Family.MONDE,
		"plancher": 0.5,
		"nom": "Trait de balle",
		"phrase": "La balle éclaire sa trajectoire : c'est ce qui dit d'où l'on vous tire dessus. En classé, elle reste lisible pour les deux.",
	},
	"lumiere_impact": {
		"famille": Family.MONDE,
		"plancher": 0.4,
		"nom": "Lumière d'impact",
		"phrase": "Toucher éclaire la pièce une seconde : l'un est révélé, l'autre est ébloui. Supprimer cette lumière n'annulerait que la moitié gênante.",
	},
	"particules_sang": {
		"famille": Family.MONDE,
		"plancher": 0.35,
		"nom": "Particules de sang",
		"phrase": "Le sang confirme la touche et éclaire le blessé. C'est une information de match, pas un ornement.",
	},
	"eclats_impact": {
		"famille": Family.MONDE,
		"plancher": 0.3,
		"nom": "Éclats sur les murs",
		"phrase": "Les étincelles disent qu'un tir a manqué, et où il a frappé. Les couper effacerait la trace d'un tir raté.",
	},
	"traces_de_sang": {
		"famille": Family.MONDE,
		"plancher": 0.25,
		"nom": "Traces de sang au sol",
		"phrase": "Une trace dit qu'on s'est battu ici. Le noir garde peu de mémoire : celle-là reste.",
	},
	"poussiere_faisceau": {
		"famille": Family.MONDE,
		"plancher": 0.2,
		"nom": "Poussière dans le faisceau",
		"phrase": "La poussière rend un faisceau visible de côté : une torche se repère sans être pointée sur vous. L'effacer rendrait les torches plus discrètes.",
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

## Plancher applicable dans ce contexte. Zéro partout hors classé : l'écran
## partagé n'est pas classé, rien n'y est en jeu.
static func floor_of(id: String, ranked: bool) -> float:
	if not ranked or not EFFECTS.has(id):
		return MIN
	return clampf(float(EFFECTS[id]["plancher"]), MIN, MAX)

## Valeur réellement applicable : écrêtée entre le plancher du contexte et 1.
##
## Une valeur hors bornes est ramenée plutôt que refusée — un curseur mal
## calibré, un fichier trafiqué ou une préférence prise en écran partagé ne
## doivent pas pouvoir fabriquer une intensité que le classé n'accepte pas.
static func clamp_value(id: String, value: float, ranked: bool) -> float:
	if is_nan(value):
		return DEFAULT
	return clampf(value, floor_of(id, ranked), MAX)

## Le curseur refuse-t-il de descendre jusqu'à zéro ici ? C'est la question à
## laquelle l'écran doit répondre visiblement, jamais en masquant la course.
static func is_capped(id: String, ranked: bool) -> bool:
	return floor_of(id, ranked) > MIN

# ---------------------------------------------------------------------------
# CE QUE LE JOUEUR LIT
# ---------------------------------------------------------------------------
#
# Tout le texte destiné au joueur vit ici, à côté des valeurs qu'il explique.
# Le mettre dans l'écran garantirait qu'un plancher changé un jour laisse
# derrière lui une phrase qui dit autre chose.

static func family_label(family: int) -> String:
	match family:
		Family.CONFORT: return "Confort"
		Family.MONDE: return "Monde"
	return ""

## Règle de la famille, en une ligne, sous son titre.
static func family_rule(family: int) -> String:
	match family:
		Family.CONFORT:
			return "N'obstrue que votre écran. Réglable jusqu'à zéro, même en classé."
		Family.MONDE:
			return "Ce que les deux joueurs lisent. Se réduit en classé, ne s'annule pas."
	return ""

## Bandeau de contexte, en tête d'écran. Le joueur doit savoir *avant* de
## toucher un curseur si ce qu'il règle vaudra pour son prochain match.
static func context_line(ranked: bool) -> String:
	if ranked:
		return "Match classé — les effets du monde gardent un minimum ; le confort reste libre."
	return "Écran partagé — aucun minimum : rien n'est en jeu ici."

## Ligne affichée sous le curseur : la contrainte d'abord, sa raison ensuite.
static func constraint_line(id: String, ranked: bool) -> String:
	if not EFFECTS.has(id):
		return ""
	var reason := reason_of(id)
	if family_of(id) == Family.CONFORT:
		return "Jusqu'à zéro. " + reason
	if not ranked:
		return "Sans minimum en écran partagé. " + reason
	return "Minimum en classé : %d %%. %s" % [intensity_to_percent(floor_of(id, true)), reason]

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
