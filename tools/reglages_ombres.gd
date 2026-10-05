## OMBRES, OM3c (Q85, 2026-10-05) — LES DEUX RÉGLAGES D'OMBRE QUE Q85 PROPOSE, posés à l'exécution par les bancs, jamais par le jeu.
##
## Q85 : « le filtre d'ombre PCF5 avec un léger lissage sur la torche, le halo et les plafonniers, et l'atlas d'ombres à 4096 ? »
## L'atlas (`rendering/2d/shadow_atlas/size`, 2048 dans le projet) se règle pour tout le rendu 2D
## (`RenderingServer.canvas_set_shadow_texture_size`) ; le filtre, lumière par lumière (`Light2D.shadow_filter`). Ce fichier est le
## SEUL endroit qui dit quelles lumières Q85 filtre : le banc de cadence (`bench_framerate.gd --atlas-ombres=… --pcf5…`) et le banc
## des ombres (`planche_ombres.gd`, la famille `q85`) le lisent tous deux, pour que l'image jugée et le coût mesuré soient ceux du
## même réglage. `tools/test_banc.gd` le joue sans fenêtre.
##
## ⚠️ **Il ne touche ni `enabled` ni `shadow_enabled`** : la perception des bots lit `enabled` (`perception_bot_noeud.gd`), et un
## réglage de filtre qui éteindrait une ombre mesurerait autre chose. Seuls `shadow_filter` et `shadow_filter_smooth` s'écrivent ici.
extends RefCounted

## Le lissage « léger » de Q85 : `shadow_filter_smooth` = 1. Il élargit le noyau du PCF5 (cinq prises de l'atlas, de part et
## d'autre de l'arête) ; la pénombre qu'il donne au sol se MESURE sur la planche de Q85, elle ne se déduit pas d'ici.
const LISSAGE_LEGER := 1.0
## L'atlas que Q85 propose.
const ATLAS_PROPOSE := 4096


## L'atlas du projet (2048) : celui que le jeu rend, et que les bancs remettent après un plan.
static func atlas_du_projet() -> int:
	return int(ProjectSettings.get_setting("rendering/2d/shadow_atlas/size", 2048))


static func poser_l_atlas(taille: int) -> void:
	RenderingServer.canvas_set_shadow_texture_size(taille)


## Les lumières que Q85 filtrerait : la torche (`flashlight`) et le halo de proximité (`ambient_light`) de chaque corps donné (J1,
## J2, chaque PNJ), et le halo de chaque plafonnier allumé ou non (le groupe « plafonniers », leur `halo`). Ni le flash de bouche, ni
## l'écho au sol, ni la lumière de coup, ni la rétrodiffusion, ni les lumières posées : Q85 ne les nomme pas.
static func lumieres_de_q85(arbre: SceneTree, corps: Array) -> Array[Light2D]:
	var sortie: Array[Light2D] = []
	for c in corps:
		if c == null or not is_instance_valid(c):
			continue
		for prop in ["flashlight", "ambient_light"]:
			var l: Variant = (c as Object).get(prop)
			if l is Light2D and not sortie.has(l):
				sortie.append(l)
	if arbre != null:
		for p in arbre.get_nodes_in_group("plafonniers"):
			var h: Variant = p.get("halo")
			if h is Light2D and not sortie.has(h):
				sortie.append(h)
	return sortie


## Pose le PCF5 (et son lissage) sur ces lumières, ou les rend au filtre du jeu (aucun, lissage nul) : `player.gd` et
## `plafonnier.gd` posent `SHADOW_FILTER_NONE` et ne touchent pas au lissage. Rend le nombre de lumières réglées.
static func poser_le_filtre(lumieres: Array, pcf5: bool, lissage: float = LISSAGE_LEGER) -> int:
	var n := 0
	for l in lumieres:
		if l == null or not is_instance_valid(l):
			continue
		(l as Light2D).shadow_filter = Light2D.SHADOW_FILTER_PCF5 if pcf5 else Light2D.SHADOW_FILTER_NONE
		(l as Light2D).shadow_filter_smooth = lissage if pcf5 else 0.0
		n += 1
	return n


## Combien de ces lumières portent le PCF5 à cet instant (la vérification de la fin d'une prise).
static func combien_en_pcf5(lumieres: Array) -> int:
	var n := 0
	for l in lumieres:
		if l != null and is_instance_valid(l) and (l as Light2D).shadow_filter == Light2D.SHADOW_FILTER_PCF5:
			n += 1
	return n
