extends RefCounted
class_name ConditionsDeMatch

## Les CONDITIONS d'un match : ce que la machine a coûté pendant qu'on jouait,
## et quelle machine c'était.
##
## Chantier « prêt à l'essai », étape PE2.1. Jusqu'ici l'archive de match
## (`MatchRecord`) disait le RÉSULTAT — vainqueur, armes, carte — et rien des
## conditions : un testeur qui écrit « ça rame » n'avait rien à joindre, et
## toutes les mesures de cadence du projet venaient d'une seule machine, un
## Apple M3. Ce fichier fait de chaque match joué un relevé de cadence, pris
## sur la machine de qui joue.
##
## ## Ce qu'il mesure, et comment
##
## Une durée par image RENDUE, lue à l'horloge (`Time.get_ticks_usec`) et
## jamais à `get_process_delta_time()` : le delta de traitement suit
## `Engine.time_scale`, et l'encaissement d'un tir le ralentit en pleine manche
## — un relevé pris au delta y lirait des images de 0,2 ms, soit 5 000 fps.
## ⚠️ Et jamais à `Engine.get_frames_per_second()`, qui ne bouge qu'une fois par
## seconde : quinze valeurs recopiées cent fois ne font pas un percentile
## (piège connu du 2026-08-18, « `get_frames_per_second()` ne bouge qu'une fois
## par seconde »).
##
## Les statistiques sont CELLES DU BANC (`tools/bench_framerate.gd::_report`),
## définition pour définition : moyenne = images / temps total, médiane, 1 % bas
## = cadence moyenne du centième d'images le plus lent, pire image. Un chiffre
## relevé ici doit se comparer à un chiffre du banc sans conversion — sinon deux
## relevés de la même partie se contrediraient, et le plus flatteur gagnerait.
##
## ## Ce qu'il ne mesure pas, délibérément
##
## - La killcam et l'écran de fin : `arreter()` est appelé à la mort, avant le
##   ralenti. Le relevé décrit la manche jouée, pas son cinéma.
## - Une pause en écran partagé (`get_tree().paused`), ou une fenêtre gelée par
##   le système : l'image qui suit dure une minute et n'est pas une saccade.
##   Tout écart au-dessus de `TROU_S` est compté comme un TROU, pas comme une
##   image, et le compte figure dans le résumé — un relevé plein de trous doit
##   se lire comme tel, pas comme un relevé propre.
##
## Aucune référence à un autoload ici : le fichier se charge en `--script`
## (`tools/test_conditions_de_match.gd`). Les valeurs réseau lui sont PASSÉES
## par `game_state.gd` ; il ne va pas les chercher.

## Au-dessus de cette durée, une image n'est pas une saccade : c'est une pause
## ou un gel, compté à part.
const TROU_S := 0.5

## Version du RÉSUMÉ, indépendante du schéma de `MatchRecord` : le jour où une
## clé s'ajoute ici, un lecteur sait à quelle forme il a affaire sans que tout
## le journal change de version.
const VERSION := 1

var _durees := PackedFloat32Array()
var _rtt := PackedFloat32Array()
var _trous := 0
var _en_cours := false
var _dernier_tic_usec := 0

func commencer() -> void:
	_durees = PackedFloat32Array()
	_rtt = PackedFloat32Array()
	_trous = 0
	_dernier_tic_usec = 0
	_en_cours = true

func arreter() -> void:
	_en_cours = false

func en_cours() -> bool:
	return _en_cours

## Une image rendue. `rtt_ms` négatif quand il n'y a pas de lien à mesurer.
## `tic_usec` n'existe que pour les tests : par défaut, l'horloge.
func echantillonner(rtt_ms: float = -1.0, tic_usec: int = -1) -> void:
	if not _en_cours:
		return
	var t := tic_usec if tic_usec >= 0 else Time.get_ticks_usec()
	if _dernier_tic_usec > 0:
		var dt := float(t - _dernier_tic_usec) / 1e6
		if dt > TROU_S:
			_trous += 1
		elif dt > 0.0:
			_durees.append(dt)
	_dernier_tic_usec = t
	if rtt_ms >= 0.0:
		_rtt.append(rtt_ms)

## Le résumé archivable : cadence, lien, machine et mémoire vidéo.
func resume() -> Dictionary:
	var r := statistiques(_durees)
	r["version"] = VERSION
	r["trous"] = _trous
	if _rtt.is_empty():
		r["rtt_moyen_ms"] = -1.0
		r["rtt_max_ms"] = -1.0
	else:
		var somme := 0.0
		var pic := 0.0
		for v in _rtt:
			somme += v
			pic = maxf(pic, v)
		r["rtt_moyen_ms"] = snappedf(somme / _rtt.size(), 0.1)
		r["rtt_max_ms"] = snappedf(pic, 0.1)
	r["machine"] = machine()
	return r

## Les mêmes définitions que `tools/bench_framerate.gd` — voir l'en-tête.
static func statistiques(durees: PackedFloat32Array) -> Dictionary:
	var n := durees.size()
	if n == 0:
		return {"images": 0, "duree_s": 0.0, "fps_moyen": 0.0, "fps_median": 0.0,
			"fps_1pc_bas": 0.0, "pire_image_ms": 0.0}
	# Trié du plus RAPIDE au plus lent : ce sont des durées, pas des cadences.
	var triees := durees.duplicate()
	triees.sort()
	var total := 0.0
	for v in triees:
		total += v
	# Une moyenne sur la tranche lente, et non sa borne : un pic isolé ne doit
	# pas décider seul, mais vingt saccades doivent.
	var lents := maxi(1, int(round(n * 0.01)))
	var somme_lentes := 0.0
	for i in range(n - lents, n):
		somme_lentes += triees[i]
	return {
		"images": n,
		"duree_s": snappedf(total, 0.01),
		"fps_moyen": snappedf(float(n) / total, 0.1),
		"fps_median": snappedf(1.0 / triees[n / 2], 0.1),
		"fps_1pc_bas": snappedf(float(lents) / somme_lentes, 0.1),
		"pire_image_ms": snappedf(triees[n - 1] * 1000.0, 0.1),
	}

## La machine, telle que le moteur la voit. Tout ce qu'un testeur ne saura pas
## décrire et qu'on lui demanderait en premier.
static func machine() -> Dictionary:
	var fenetre := DisplayServer.window_get_size()
	var mem := OS.get_memory_info()
	return {
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"build": "debug" if OS.is_debug_build() else "release",
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu": OS.get_processor_name(),
		"coeurs": OS.get_processor_count(),
		"memoire_mo": int(float(mem.get("physical", 0)) / 1048576.0),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_fournisseur": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		# Sur `OS`, pas sur `RenderingServer` : nom et version du PILOTE, ce qui
		# distingue deux machines à carte identique dont une seule saccade.
		"gpu_pilote": " ".join(OS.get_video_adapter_driver_info()),
		"rendu": RenderingServer.get_current_rendering_method(),
		"pilote": RenderingServer.get_current_rendering_driver_name(),
		"fenetre": "%dx%d" % [fenetre.x, fenetre.y],
		"plein_ecran": DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN,
		"ecran_hz": snappedf(DisplayServer.screen_get_refresh_rate(), 0.1),
		# 0 quand le moteur de rendu ne le compte pas : lire « non mesuré »,
		# jamais « aucune texture chargée ».
		"vram_mo": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"textures_mo": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
	}

## Le diagnostic lisible, à coller dans un message. `blocs` : une liste de
## paires `[titre, dictionnaire]` ; un dictionnaire imbriqué s'aplatit en
## `parent.cle`. Pure mise en forme, sans lecture d'aucun état du jeu.
static func texte_diagnostic(blocs: Array) -> String:
	var lignes := PackedStringArray()
	lignes.append("CANDELA 2D — DIAGNOSTIC  %s" % Time.get_datetime_string_from_system(true, true))
	for bloc in blocs:
		if not (bloc is Array) or (bloc as Array).size() != 2:
			continue
		lignes.append("")
		lignes.append("== %s ==" % String(bloc[0]))
		_ecrire(lignes, bloc[1], "")
	lignes.append("")
	return "\n".join(lignes)

static func _ecrire(lignes: PackedStringArray, valeur: Variant, prefixe: String) -> void:
	if valeur is Dictionary:
		var d: Dictionary = valeur
		for cle in d.keys():
			var v: Variant = d[cle]
			if v is Dictionary:
				_ecrire(lignes, v, prefixe + String(cle) + ".")
			else:
				lignes.append("%-24s %s" % [prefixe + String(cle), str(v)])
	else:
		lignes.append("%-24s %s" % [prefixe.trim_suffix("."), str(valeur)])
