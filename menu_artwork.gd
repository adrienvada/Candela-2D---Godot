class_name MenuArtwork
extends RefCounted

## Registre et contrôleur des illustrations de menu — Candela 2D.
##
## Gère :
## 1. Les Points d'Intérêt (POI) d'où partent les flammes de transition (torche, pistolet, fusée).
## 2. Les types d'effets vivants uniques attribués à chaque illustration.
## 3. Les couleurs d'embrasement associées (ambre incandescent vs rouge carmin de détresse).

const Charte := preload("res://charte.gd")

enum EffectMode {
	NONE = 0,
	FLICKER_DUST = 1,
	HEARTBEAT_FLARE = 2,
	BEAM_CLASH = 3,
	BREATHING_HALO = 4,
	NETWORK_LEDS = 5,
	CRT_SCAN = 6,
	LASER_TARGET = 7,
	ELECTRICAL_ARC = 8,
	VAULT_BEAMS = 9,
	DYING_EMBER = 10,
	FLARE_SMOKE = 11,
	DISTANT_BEACON = 12,
	ABYSS_VORTEX = 13,
}

## Points d'intérêt en coordonnées normalisées (U, V) dans l'image 1024x640.
const POIS: Dictionary = {
	"ill_accueil": Vector2(0.66, 0.72),
	"ill_competitif": Vector2(0.65, 0.73),
	"ill_ecran_scinde": Vector2(0.50, 0.50),
	"ill_amical": Vector2(0.65, 0.72),
	"ill_amical_ligne": Vector2(0.63, 0.72),
	"ill_amical_local": Vector2(0.25, 0.40),
	"ill_entrainement": Vector2(0.67, 0.54),
	"ill_personnalisation": Vector2(0.48, 0.44),
	"ill_mise_a_jour": Vector2(0.04, 0.88),
	"ill_quitter": Vector2(0.50, 0.72),
	"ill_creer_ligne": Vector2(0.58, 0.65),
	"ill_rejoindre_ligne": Vector2(0.58, 0.40),
	"ill_creer_local": Vector2(0.77, 0.83),
	"ill_rejoindre_local": Vector2(0.72, 0.38),
	"ill_creer": Vector2(0.58, 0.65),
	"ill_rejoindre": Vector2(0.58, 0.40),
	"ill_retour": Vector2(0.35, 0.70),
}

## Effets vivants spécifiques par clé d'illustration.
const EFFECTS: Dictionary = {
	"ill_accueil": EffectMode.FLICKER_DUST,
	"ill_competitif": EffectMode.HEARTBEAT_FLARE,
	"ill_ecran_scinde": EffectMode.BEAM_CLASH,
	"ill_amical": EffectMode.BREATHING_HALO,
	"ill_amical_ligne": EffectMode.NETWORK_LEDS,
	"ill_amical_local": EffectMode.CRT_SCAN,
	"ill_entrainement": EffectMode.LASER_TARGET,
	"ill_personnalisation": EffectMode.ELECTRICAL_ARC,
	"ill_mise_a_jour": EffectMode.VAULT_BEAMS,
	"ill_quitter": EffectMode.DYING_EMBER,
	"ill_creer_ligne": EffectMode.FLARE_SMOKE,
	"ill_rejoindre_ligne": EffectMode.DISTANT_BEACON,
	"ill_creer_local": EffectMode.FLARE_SMOKE,
	"ill_rejoindre_local": EffectMode.DISTANT_BEACON,
	"ill_creer": EffectMode.FLARE_SMOKE,
	"ill_rejoindre": EffectMode.DISTANT_BEACON,
	"ill_retour": EffectMode.ABYSS_VORTEX,
}

## Déduit la clé canonique à partir d'un chemin d'asset ou d'une clé brute.
static func cle_canonique(identifiant: String) -> String:
	if identifiant == "":
		return "ill_accueil"
	var nom := identifiant.get_file().get_basename()
	if nom.begins_with("ill_") or nom.begins_with("apercu_"):
		if nom == "apercu_personnalisation":
			return "ill_personnalisation"
		return nom
	if POIS.has(identifiant):
		return identifiant
	return "ill_accueil"

## Point d'intérêt (U, V) pour une clé d'illustration donnée.
static func poi_pour(identifiant: String) -> Vector2:
	var cle := cle_canonique(identifiant)
	return POIS.get(cle, Vector2(0.5, 0.5))

## Mode d'effet vivant pour une clé donnée.
static func effet_pour(identifiant: String) -> int:
	var cle := cle_canonique(identifiant)
	return EFFECTS.get(cle, EffectMode.NONE)

## Couleur de flamme/embrasement pour une clé donnée.
static func couleur_flamme_pour(identifiant: String) -> Color:
	var cle := cle_canonique(identifiant)
	if cle.begins_with("ill_creer") or cle.begins_with("ill_rejoindre"):
		# Fusée de détresse rouge carmin
		return Color(2.2, 0.45, 0.35)
	if cle == "ill_competitif":
		# Reflet froid bleu électrique / halo blanc
		return Color(0.8, 1.8, 2.5)
	# Flamme halogène / ambre incandescent standard
	return Charte.AMBRE_INCANDESCENT
