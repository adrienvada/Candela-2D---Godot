## Banc de cadence ÉTENDU de l'audit M (2026-10-04) — INSTRUMENT TEMPORAIRE, jamais commité.
##
## SOUS-CLASSE du banc du projet (`tools/bench_framerate.gd`), qu'il n'altère pas : sans aucun drapeau `--v-…` ni `--sonde`, il
## rend exactement le banc du projet (même charge, même journal — `tools/cadence_cloud/analyse.py` le lit sans changement).
##
##   --v-sans-ombres-2d / --v-sans-capteurs / --v-sans-halos / --v-sans-retro / --v-sans-voile / --v-sans-plafonniers /
##   --v-sans-torches-pnj : voir `variantes_reflexion.gd` (une nouveauté retirée par réflexion, posée avant chaque dessin) ;
##   --sonde              : à chaque image mesurée, les compteurs de rendu (`sonde_rendu.gd`) et la sonde à paliers (`sonde_mesures.gd`),
##                          imprimés en fin de mesure ; --sonde-palier N (300), --sonde-pas S (1/60), --sonde-depuis S (30).
extends "res://tools/bench_framerate.gd"

const Sonde := preload("res://tools/sonde_mesures.gd")
const SondeRendu := preload("res://tools/sonde_rendu.gd")
const VariantesReflexion := preload("res://tools/variantes_reflexion.gd")

var _m_sonde_on := false
var _m_sonde = null
var _m_rendu = null
var _m_var = null
var _m_branche := false


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_m_sonde_on = a.has("--sonde")
	_m_var = VariantesReflexion.new(a)


func _m_args_valeur(drapeau: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find(drapeau)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else defaut


func _process(_delta: float) -> void:
	# Le jeu n'est monté qu'après le premier `await` du banc : on branche les variantes dès que `_main` existe.
	if not _m_branche and is_instance_valid(_main) and _main.get("p1") != null:
		_m_branche = true
		_m_var.brancher(get_tree(), _main)


## Une fois par image MESURÉE (le banc appelle `_relever_rendu` seulement quand il échantillonne).
func _relever_rendu() -> void:
	super()
	if not _m_sonde_on:
		return
	if _m_sonde == null:
		# Les relevés de rendu (9 valeurs par viewport et par image, en tableaux de Variant) n'ont de sens que fenêtré — et ils
		# pèsent ~20 Mo sur 15 000 images : sous `headless` ils fausseraient la mesure de MÉMOIRE (constaté le 2026-10-05).
		if DisplayServer.get_name() != "headless":
			_m_rendu = SondeRendu.new()
			_m_rendu.armer(get_tree())
		_m_sonde = Sonde.new()
		_m_sonde.configurer("banc", int(_m_args_valeur("--sonde-palier", "300")), float(_m_args_valeur("--sonde-pas", str(1.0 / 60.0))),
			func() -> Dictionary: return Sonde.extras_du_jeu(get_tree(), _main))
		# Un pas de physique par image seulement sous `--fixed-fps` : la séparation physique / reste n'a de sens que là.
		# (`OS.get_cmdline_args()` ne rend pas les drapeaux du moteur : on s'appuie sur « headless », où les bancs sont toujours à pas fixe.)
		if DisplayServer.get_name() == "headless":
			_m_sonde.armer_physique(get_tree())
	if _m_rendu != null:
		_m_rendu.image()
	_m_sonde.image()


func _report() -> void:
	super()
	if _m_sonde_on and _menus:
		# Au hub : pas de relevé par image (le banc des menus n'appelle pas `_relever_rendu`), mais le recensement des viewports au
		# moment de la mesure et les compteurs de la dernière image.
		var r = SondeRendu.new()
		r.armer(get_tree())
		print("")
		print("[M] hub : appels de dessin %d · objets %d · primitives %d (dernière image) ; mémoire vidéo %.1f Mo"
			% [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		for l in r._recensement(_main):
			print(l)
		for l in r._tableau_des_vues():
			print(l)
		return
	if not _m_sonde_on or _m_sonde == null:
		return
	print("")
	if _m_rendu != null:
		print(_m_rendu.rapport(_main))
	print(_m_sonde.rapport(float(_m_args_valeur("--sonde-depuis", "30"))))
	var chemin_json := _m_args_valeur("--sonde-json", "")
	if chemin_json != "":
		_m_sonde.ecrire_json(chemin_json)
