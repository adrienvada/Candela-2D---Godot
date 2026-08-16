class_name AssetManifest
extends RefCounted

## Inventaire des ressources que le jeu attend, et de celles qu'il n'a pas.
##
## Pourquoi ce fichier existe. Une trentaine d'items de game feel dépendent de
## sons qui ne sont pas dans le dépôt. Le code qui les joue est écrit ; sans
## inventaire, un son absent est indiscernable d'un son qu'on a choisi de ne pas
## jouer — et le défaut se découvre six mois plus tard, à l'oreille, sans savoir
## depuis quand.
##
## Deux états à ne pas confondre, et c'est toute la raison d'être de ce fichier :
##
## - **ABSENT** : le fichier n'existe pas. `AudioManager` ne joue rien, sans
##   erreur — c'est le silence honnête décidé le 2026-08-17.
## - **BOUCHE-TROU** : le fichier existe mais c'est un flux généré vide.
##   `music_menu.ogg`, `music_match.ogg` et `music_victory.ogg` pèsent
##   **exactement 160 032 octets** chacun : trois copies du même silence produit
##   par `tools/generate_music_streams.gd`. Un contrôle de présence les
##   déclarerait bons. C'est le cas le plus traître des deux.
##
## La détection du bouche-trou se fait à la taille exacte du fichier. C'est
## rustique et c'est délibéré : le jour où Adrien dépose le vrai fichier, la
## taille change et le drapeau tombe tout seul. Aucune liste à tenir à jour à la
## main, donc aucune liste qui puisse mentir.
##
## Le panneau F3 en rend compte en jeu. L'onglet ASSETS du suivi de projet donne
## à Adrien la même liste, avec durées et intentions.

## Taille, en octets, du flux vide produit par `generate_music_streams.gd`.
## Trois fichiers la portent aujourd'hui à l'identique.
const PLACEHOLDER_OGG_SIZE := 160032

const DIR_MUSIC := "res://assets/audio/music/"
const DIR_SFX := "res://assets/audio/sfx/"
const DIR_SPEAKER := "res://assets/audio/speaker/"

## Chaque entrée : `f` fichier, `d` dossier, `s` durée visée (s), `w` la vague de
## game feel qui l'attend, `p` true si un bouche-trou occupe déjà la place.
const EXPECTED: Array = [
	# --- Musique, tout à 170 BPM -------------------------------------------
	{"f": "music_menu.ogg", "d": DIR_MUSIC, "s": 22.588, "w": "V1.1", "p": true},
	# Piste de match non interactive, encore référencée par `AudioManager.SOUNDS`
	# en repli du flux à quatre couches.
	{"f": "music_match.ogg", "d": DIR_MUSIC, "s": 22.588, "w": "V1.1", "p": true},
	{"f": "music_match_base.ogg", "d": DIR_MUSIC, "s": 22.588, "w": "V1.1", "p": false},
	{"f": "music_match_drums.ogg", "d": DIR_MUSIC, "s": 22.588, "w": "V1.1", "p": false},
	{"f": "music_match_arp.ogg", "d": DIR_MUSIC, "s": 22.588, "w": "V1.1", "p": false},
	{"f": "music_victory.ogg", "d": DIR_MUSIC, "s": 5.647, "w": "V1.1", "p": true},
	{"f": "music_intro.ogg", "d": DIR_MUSIC, "s": 5.647, "w": "V1.1", "p": false},

	# --- Stingers, dans la tonalité du thème --------------------------------
	{"f": "sting_kill.ogg", "d": DIR_MUSIC, "s": 0.706, "w": "V2.3", "p": false},
	{"f": "sting_kill_match.ogg", "d": DIR_MUSIC, "s": 1.412, "w": "V2.3", "p": false},
	{"f": "sting_defeat.ogg", "d": DIR_MUSIC, "s": 2.118, "w": "V3.7", "p": false},
	{"f": "sting_draw.ogg", "d": DIR_MUSIC, "s": 1.412, "w": "V3.8", "p": false},

	# --- Annonceur — le dossier lui-même n'existe pas encore ----------------
	{"f": "spk_fight.wav", "d": DIR_SPEAKER, "s": 0.8, "w": "V1.3", "p": false},
	{"f": "spk_p1_wins.wav", "d": DIR_SPEAKER, "s": 1.2, "w": "V1.3", "p": false},
	{"f": "spk_p2_wins.wav", "d": DIR_SPEAKER, "s": 1.2, "w": "V1.3", "p": false},
	{"f": "spk_draw.wav", "d": DIR_SPEAKER, "s": 1.0, "w": "V1.3", "p": false},
	{"f": "spk_perfect.wav", "d": DIR_SPEAKER, "s": 1.0, "w": "V1.3", "p": false},
	{"f": "spk_close_call.wav", "d": DIR_SPEAKER, "s": 1.2, "w": "V1.3", "p": false},

	# --- Armes : corps + queue par arme -------------------------------------
	{"f": "weapon_pistolet_body.wav", "d": DIR_SFX, "s": 0.12, "w": "V4.1", "p": false},
	{"f": "weapon_pistolet_tail.wav", "d": DIR_SFX, "s": 0.6, "w": "V4.1", "p": false},
	{"f": "weapon_fusil_body.wav", "d": DIR_SFX, "s": 0.15, "w": "V4.1", "p": false},
	{"f": "weapon_fusil_tail.wav", "d": DIR_SFX, "s": 0.9, "w": "V4.1", "p": false},
	{"f": "weapon_pompe_body.wav", "d": DIR_SFX, "s": 0.2, "w": "V4.1", "p": false},
	{"f": "weapon_pompe_tail.wav", "d": DIR_SFX, "s": 1.2, "w": "V4.1", "p": false},
	{"f": "weapon_arbalete_body.wav", "d": DIR_SFX, "s": 0.1, "w": "V4.1", "p": false},
	{"f": "weapon_arbalete_tail.wav", "d": DIR_SFX, "s": 0.3, "w": "V4.1", "p": false},

	# --- Impacts et ratés ----------------------------------------------------
	{"f": "hit_center.wav", "d": DIR_SFX, "s": 0.15, "w": "V4.2", "p": false},
	{"f": "hit_edge.wav", "d": DIR_SFX, "s": 0.08, "w": "V4.2", "p": false},
	{"f": "ricochet_01.wav", "d": DIR_SFX, "s": 0.4, "w": "V4.3", "p": false},
	{"f": "ricochet_02.wav", "d": DIR_SFX, "s": 0.4, "w": "V4.3", "p": false},
	{"f": "ricochet_03.wav", "d": DIR_SFX, "s": 0.4, "w": "V4.3", "p": false},
	{"f": "weapon_dry.wav", "d": DIR_SFX, "s": 0.1, "w": "V4.4", "p": false},

	# --- Douilles -------------------------------------------------------------
	{"f": "shell_01.wav", "d": DIR_SFX, "s": 0.3, "w": "V4.8", "p": false},
	{"f": "shell_02.wav", "d": DIR_SFX, "s": 0.3, "w": "V4.8", "p": false},
	{"f": "shell_03.wav", "d": DIR_SFX, "s": 0.3, "w": "V4.8", "p": false},
	{"f": "shell_04.wav", "d": DIR_SFX, "s": 0.3, "w": "V4.8", "p": false},

	# --- Le corps qui encaisse ------------------------------------------------
	{"f": "breath_hit_01.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.9", "p": false},
	{"f": "breath_hit_02.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.9", "p": false},
	{"f": "breath_hit_03.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.9", "p": false},
	{"f": "breath_hit_04.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.9", "p": false},
	{"f": "breath_hit_05.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.9", "p": false},
	{"f": "breath_hit_06.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.9", "p": false},
	{"f": "tinnitus_death.wav", "d": DIR_SFX, "s": 1.5, "w": "V2.8", "p": false},
	{"f": "tinnitus_dazzle.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.3", "p": false},

	# --- Vol du carreau -------------------------------------------------------
	{"f": "bolt_flight.wav", "d": DIR_SFX, "s": 0.5, "w": "V4.10", "p": false},

	# --- Torche : le son le plus entendu du jeu -------------------------------
	{"f": "torch_on.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.1", "p": false},
	{"f": "torch_off.wav", "d": DIR_SFX, "s": 0.2, "w": "V5.1", "p": false},

	# --- Pas : deux matériaux, le damier du sol -------------------------------
	{"f": "footstep_a_01.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_a_02.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_a_03.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_a_04.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_b_01.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_b_02.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_b_03.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},
	{"f": "footstep_b_04.wav", "d": DIR_SFX, "s": 0.25, "w": "V5.7", "p": false},

	# --- La salle existe ------------------------------------------------------
	{"f": "ambience_01.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_02.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_03.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_04.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_05.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_06.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_07.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "ambience_08.wav", "d": DIR_SFX, "s": 2.0, "w": "V5.10", "p": false},
	{"f": "wall_brush_01.wav", "d": DIR_SFX, "s": 0.4, "w": "V5.11", "p": false},
	{"f": "wall_brush_02.wav", "d": DIR_SFX, "s": 0.4, "w": "V5.11", "p": false},
	{"f": "wall_brush_03.wav", "d": DIR_SFX, "s": 0.4, "w": "V5.11", "p": false},

	# --- Interface et récit ---------------------------------------------------
	{"f": "ui_ready_ping.wav", "d": DIR_SFX, "s": 0.3, "w": "V3.2", "p": false},
	{"f": "count_3.wav", "d": DIR_SFX, "s": 0.35, "w": "V3.3", "p": false},
	{"f": "count_2.wav", "d": DIR_SFX, "s": 0.35, "w": "V3.3", "p": false},
	{"f": "count_1.wav", "d": DIR_SFX, "s": 0.35, "w": "V3.3", "p": false},
	{"f": "ui_tick.wav", "d": DIR_SFX, "s": 0.08, "w": "V3.4", "p": false},
	{"f": "ui_type_impact.wav", "d": DIR_SFX, "s": 0.2, "w": "V3.5", "p": false},
	{"f": "ui_score_pawn.wav", "d": DIR_SFX, "s": 0.2, "w": "V3.6", "p": false},
	{"f": "ui_glass_break.wav", "d": DIR_SFX, "s": 0.8, "w": "V3.9", "p": false},
	{"f": "ui_vhs_rewind.wav", "d": DIR_SFX, "s": 0.3, "w": "V6.4", "p": false},
	{"f": "ui_keystroke.wav", "d": DIR_SFX, "s": 0.08, "w": "V6.7", "p": false},
	{"f": "ui_power_on.wav", "d": DIR_SFX, "s": 0.6, "w": "V6.8", "p": false},
]

static func path_of(entry: Dictionary) -> String:
	return String(entry["d"]) + String(entry["f"])

## Existe-t-il, sous une forme ou une autre ? `ResourceLoader` couvre le cas de
## l'export, où le `.wav` source est remplacé par sa version importée.
static func exists(entry: Dictionary) -> bool:
	var path := path_of(entry)
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

## Présent, mais vide. Voir `PLACEHOLDER_OGG_SIZE` : on compare la taille exacte
## plutôt que de tenir une liste à la main, qui finirait par mentir.
static func is_placeholder(entry: Dictionary) -> bool:
	var path := path_of(entry)
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var size := f.get_length()
	f.close()
	return size == PLACEHOLDER_OGG_SIZE

## Les fichiers qu'on n'a pas du tout.
static func missing() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in EXPECTED:
		if not exists(entry):
			out.append(String(entry["f"]))
	return out

## Les fichiers présents qui ne contiennent rien.
static func placeholders() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in EXPECTED:
		if exists(entry) and is_placeholder(entry):
			out.append(String(entry["f"]))
	return out

## Ligne unique pour le panneau F3.
static func summary() -> String:
	var total := EXPECTED.size()
	var absent := missing().size()
	var empty := placeholders().size()
	var ready := total - absent - empty
	if absent == 0 and empty == 0:
		return "Assets : %d/%d" % [ready, total]
	return "Assets : %d/%d  (%d absents, %d vides)" % [ready, total, absent, empty]
