class_name MenuGlass
extends Node

## M14 — Le verre fumé. Vague M, « la vitrine ».
##
## Pose le matériau de verre sur les surfaces qui doivent en être, et tient à
## jour ce que le shader ne peut pas savoir : leur taille, et laquelle porte le
## focus.
##
## ## Quelles surfaces, et pourquoi pas toutes
##
## Le cadre de droite, et les rangées de réglage. Rien d'autre. Une rangée de
## classement porte des **données** : y ajouter une luisance rendrait un chiffre
## un peu moins net pour un gain purement décoratif, et les squelettes de M13
## passent déjà dessus. Un effet de matière se pose sur ce qu'on manipule, pas
## sur ce qu'on lit.
##
## ## Un matériau par surface, et c'est nécessaire
##
## Chaque panneau a sa taille et son focus : un matériau partagé donnerait à tous
## la géométrie du dernier inscrit. Ils sont légers — quelques uniformes, aucun
## état — et il y en a une vingtaine.
##
## ## Le focus se branche tout seul
##
## Une rangée de réglage n'est pas focalisable : c'est le curseur qu'elle
## contient qui l'est. Plutôt que de demander à chaque écran de le déclarer — ce
## qui aurait fini par manquer sur le prochain — on cherche le premier descendant
## focalisable et on écoute le sien. Un écran qui n'en a pas garde simplement un
## panneau sans lueur, ce qui est correct.

const SHADER := preload("res://menu_glass.gdshader")

## Préfixe des rangées de réglage. Voir la note de tête : ce qui se manipule est
## vitré, ce qui se lit ne l'est pas.
const PREFIXE_RANGEE := "Row_"

var _vitres: Array[Dictionary] = []
var _intensite: float = 1.0

func _init() -> void:
	name = "VerreFume"

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	for v in _vitres:
		var mat: ShaderMaterial = v["materiau"]
		if mat != null:
			mat.set_shader_parameter("intensite", _intensite)

## Vitre une surface, et garde sa taille à jour.
##
## `flou` réserve le **second étage** — la brume relue et défocalisée derrière la
## vitre — à une seule surface. C'est une copie d'écran par image : la donner à
## vingt rangées coûterait vingt fois pour un effet qu'on ne verrait que sur la
## plus grande.
func vitrer(panneau: Control, teinte: Color = MenuTheme.P1,
		flou: bool = false) -> void:
	if panneau == null or not is_instance_valid(panneau):
		return
	for v in _vitres:
		if v["panneau"] == panneau:
			return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("intensite", _intensite)
	mat.set_shader_parameter("teinte_focus", teinte)
	mat.set_shader_parameter("taille", panneau.size)
	# Posé explicitement plutôt que laissé au défaut du shader : un uniforme
	# jamais assigné se relit `null`, et une surface au repos doit pouvoir dire
	# qu'elle est au repos.
	mat.set_shader_parameter("focus", 0.0)
	mat.set_shader_parameter("flou", 1.0 if flou else 0.0)
	panneau.material = mat
	var vitre := {"panneau": panneau, "materiau": mat}
	_vitres.append(vitre)
	panneau.resized.connect(func() -> void:
		if is_instance_valid(panneau):
			mat.set_shader_parameter("taille", panneau.size))
	_ecouter_focus(panneau, mat)

## Vitre toutes les rangées de réglage d'un sous-arbre. Le cadre de droite, lui,
## se déclare à la main : c'est une surface et non une famille.
func vitrer_rangees(racine: Node) -> void:
	if racine == null:
		return
	if racine is PanelContainer and String(racine.name).begins_with(PREFIXE_RANGEE):
		vitrer(racine as Control)
		return
	for enfant in racine.get_children():
		vitrer_rangees(enfant)

## Branche la lueur de focus sur le premier descendant focalisable.
func _ecouter_focus(panneau: Control, mat: ShaderMaterial) -> void:
	var cible := _premier_focalisable(panneau)
	if cible == null:
		return
	cible.focus_entered.connect(func() -> void:
		mat.set_shader_parameter("focus", 1.0))
	cible.focus_exited.connect(func() -> void:
		mat.set_shader_parameter("focus", 0.0))

func _premier_focalisable(racine: Node) -> Control:
	for enfant in racine.get_children():
		var ctrl := enfant as Control
		if ctrl != null and ctrl.focus_mode != Control.FOCUS_NONE:
			return ctrl
		var trouve := _premier_focalisable(enfant)
		if trouve != null:
			return trouve
	return null
