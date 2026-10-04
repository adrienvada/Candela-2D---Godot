class_name AventureHud
extends CanvasLayer

## Ce que l'aventure dit PENDANT le jeu — chantier SOLO, 2026-10-04 (Adrien : « il faut ensuite que chaque niveau soit hyper
## gratifiant, que le jeu nous indique sur quelle touche appuyer à chaque étape du didacticiel pour nous introduire les mécaniques »).
##
## Trois choses, et pas une de plus :
##
##   • **les consignes de l'initiation** (chapitre 0) : la touche, puis le geste — « CLIC DROIT  ·  Gâchette L2   Allumer la torche ».
##     Chaque ligne s'allume quand le corps a FAIT le geste (sa torche s'est allumée, il a bougé, il s'est accroupi), jamais au seul appui
##     d'une touche : une consigne validée par un appui dans le vide n'aurait rien enseigné. Les touches se lisent dans l'`InputMap`
##     (`UI.libelle_du_geste`), donc une réassignation se voit ici ;
##   • **le compteur des silhouettes** (toutes les salles) : il répond à chaque abattu. Le bandeau « FATAL — <arme> » est au JcJ et ne
##     se pose plus contre un PNJ (`Player.kill_entre_joueurs`) ; sans réponse, un kill en solo tomberait dans le vide ;
##   • **le tampon de la salle réussie** (toutes les salles) : « SALLE RÉUSSIE », le temps, l'essai, et le record s'il tombe.
##
## Le carton (`AventureCarton`) restait « le SEUL endroit où l'aventure parle » (S6, « aucun texte pendant le jeu »). La demande
## d'Adrien du 2026-10-04 le change pour l'initiation : un didacticiel qui tait ses touches oblige à les chercher dans les menus.
##
## Il ne décide de rien : `AventurePartie` le règle (`entrer_dans_la_salle`, `commencer`, `salle_reussie`, `cacher`) et lui passe
## le joueur à regarder. Nommé (`HudAventure`), comme tout nœud ajouté dynamiquement.

const Charte := preload("res://charte.gd")

## Juste SOUS l'interface (10) : le menu de pause et le HUD du match passent devant, le jeu derrière. Au-dessus, les consignes
## couvriraient le menu de pause ; le carton (90), lui, couvre tout.
const CALQUE := 9

## Les gestes qu'une consigne peut demander. Chacun nomme ses actions (pour la touche à afficher) ; la validation est dans
## `_geste_fait()`.
const ACTIONS_DU_GESTE := {
	"deplacer": ["p1_move_up", "p1_move_left", "p1_move_down", "p1_move_right"],
	"viser": ["p1_aim_left"],
	"tirer": ["p1_shoot"],
	"torche_allumer": ["p1_torch"],
	"torche_eteindre": ["p1_torch"],
	"recharger": ["p1_reload"],
	"accroupir": ["p1_accroupir"],
	"fusee": ["p1_lance_fusee"],
	"gadget": ["p1_gadget"],
}

## Les consignes de l'initiation, salle par salle (« <chapitre>-<numéro de salle> », de 1). Chaque salle enseigne UNE chose nouvelle
## (ROADMAP, « Le chapitre 0 — l'initiation ») : la consigne nomme le geste de cette chose, et rien de ce qui précède.
## 0.9 (« La salle pleine ») n'en a pas : tout y est déjà connu, c'est la salle où l'on se passe d'aide.
const CONSIGNES := {
	"0-1": [["deplacer", "Se déplacer"], ["viser", "Viser"], ["tirer", "Tirer"]],
	"0-2": [["torche_allumer", "Allumer la torche : elle révèle ce qu'elle touche"]],
	"0-3": [["recharger", "Recharger : six cartouches pour trois silhouettes"]],
	"0-4": [["accroupir", "S'accroupir derrière un muret : il cache le corps, pas la lumière"]],
	"0-5": [["fusee", "Lancer une fusée : elle éclaire loin"]],
	"0-6": [["torche_allumer", "La torche allumée…"], ["torche_eteindre", "… puis éteinte pour approcher : ce qui brille se fait voir"]],
	"0-7": [["tirer", "Tirer…"], ["deplacer", "… puis changer de place : un tir se voit de loin"]],
	"0-8": [["accroupir", "S'accroupir : on avance lentement, sans bruit"]],
	"0-10": [["gadget", "Le gadget du Parasite"]],
}

## Le geste « viser » est fait quand le corps a tourné d'au moins cet angle depuis le début de la salle.
const ANGLE_VISEE := 0.6
## Le geste « se déplacer » est fait au-delà de cette distance parcourue.
const DISTANCE_DEPLACEMENT := 48.0
## Une fois toutes les consignes faites, elles restent ce temps allumées, puis s'effacent.
const TENUE_APRES_TOUT := 1.6

var _compteur: Label
var _consignes: VBoxContainer
var _tampon: VBoxContainer
var _tampon_titre: Label
var _tampon_detail: Label
## Le nom de touche d'un geste : `Callable(actions: Array) -> String`. Sans lui (suites isolées), le geste se nomme seul.
var nommer_les_touches: Callable = Callable()

## [{"geste", "texte", "fait", "ligne"}] de la salle en cours.
var _lignes: Array[Dictionary] = []
var _joueur: Node2D = null
var _depart := Vector2.ZERO
var _cap_de_depart := 0.0
var _torche_vue_allumee := false
var _tout_fait_depuis := -1.0
var _total := 0
var _abattus := 0


func _init() -> void:
	name = "HudAventure"
	layer = CALQUE
	visible = false
	_compteur = _etiquette("Compteur", Charte.T_TITRE, Charte.AMBRE, Charte.POIDS_ENSEIGNE)
	# SOUS la plaque du titre de la salle (`match_hud`, en haut au centre) : posé à 28 px il était caché derrière elle — vu à la
	# première capture, aucune suite ne l'aurait dit.
	_compteur.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compteur.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_compteur.position.y = 92.0
	add_child(_compteur)

	_consignes = VBoxContainer.new()
	_consignes.name = "Consignes"
	_consignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_consignes.alignment = BoxContainer.ALIGNMENT_END
	_consignes.add_theme_constant_override("separation", 8)
	_consignes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_consignes.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_consignes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_consignes.offset_bottom = -64.0
	add_child(_consignes)

	var centre := CenterContainer.new()
	centre.name = "CentreTampon"
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_tampon = VBoxContainer.new()
	_tampon.name = "Tampon"
	_tampon.alignment = BoxContainer.ALIGNMENT_CENTER
	_tampon.add_theme_constant_override("separation", 10)
	_tampon.visible = false
	centre.add_child(_tampon)
	_tampon_titre = _etiquette("TamponTitre", Charte.T_ENSEIGNE, Charte.HALOGENE, Charte.POIDS_ENSEIGNE)
	_tampon_detail = _etiquette("TamponDetail", Charte.T_TITRE, Charte.AMBRE, Charte.POIDS_DISPLAY)
	_tampon.add_child(_tampon_titre)
	_tampon.add_child(_tampon_detail)


func _etiquette(nom: String, taille: int, couleur: Color, poids: int) -> Label:
	var l := Label.new()
	l.name = nom
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reglage := LabelSettings.new()
	reglage.font = Charte.police_display(poids)
	reglage.font_size = taille
	reglage.font_color = couleur
	Charte.contourer_settings(reglage, taille)
	l.label_settings = reglage
	return l


# ---------------------------------------------------------------------------
# CE QUE LA PARTIE LUI DIT
# ---------------------------------------------------------------------------

## Une salle se pose (sous le carton) : ses consignes sont prêtes, son compteur à zéro, rien ne se montre encore.
func entrer_dans_la_salle(chapitre: int, numero: int, nombre_de_pnj: int, joueur: Node2D) -> void:
	visible = false
	_tampon.visible = false
	_joueur = joueur
	_total = nombre_de_pnj
	_abattus = 0
	_tout_fait_depuis = -1.0
	_torche_vue_allumee = false
	for enfant in _consignes.get_children():
		_consignes.remove_child(enfant)
		enfant.queue_free()
	_lignes.clear()
	for c: Array in consignes_de(chapitre, numero):
		var ligne := _ligne_de_consigne(String(c[0]), String(c[1]))
		_consignes.add_child(ligne)
		_lignes.append({"geste": String(c[0]), "texte": String(c[1]), "fait": false, "ligne": ligne})
	_consignes.modulate.a = 1.0
	_consignes.visible = not _lignes.is_empty()
	_maj_compteur()


## Le carton se retire : le jeu commence, le HUD se montre et le geste se mesure depuis ICI (le joueur était figé avant).
func commencer() -> void:
	visible = true
	if is_instance_valid(_joueur):
		_depart = _joueur.global_position
		_cap_de_depart = _joueur.rotation


## La salle est gagnée : le tampon claque. `secondes` : le temps de jeu de la salle ; `essai` : le numéro de l'essai ; `record` : vrai
## si ce temps bat le meilleur connu (faux au premier passage, qui n'a rien battu).
func salle_reussie(secondes: float, essai: int, record: bool) -> void:
	visible = true
	_consignes.visible = false
	_tampon_titre.text = "SALLE RÉUSSIE"
	var morceaux: Array[String] = [_temps(secondes), "premier essai" if essai <= 1 else "essai %d" % essai]
	if record:
		morceaux.append("RECORD")
	_tampon_detail.text = "  ·  ".join(morceaux)
	_tampon.visible = true
	_tampon.pivot_offset = _tampon.size * 0.5
	var tw := _tampon.create_tween()
	Charte.animer(tw, _tampon, "scale", Vector2(1.6, 1.6), Vector2.ONE, Charte.D_MOYEN, Charte.Courbe.REBOND)
	_son("ui_tampon")


func cacher() -> void:
	visible = false
	_tampon.visible = false


## Ce qu'il montre, pour les suites.
func etat() -> Dictionary:
	var lignes: Array = []
	for l in _lignes:
		lignes.append({"geste": l["geste"], "texte": l["texte"], "fait": l["fait"], "touches": (l["ligne"] as Node).get_node("Touches").text})
	return {"visible": visible, "compteur": _compteur.text, "consignes": lignes, "tampon": _tampon.visible,
		"tampon_titre": _tampon_titre.text, "tampon_detail": _tampon_detail.text}


## Les consignes d'une salle, `numero` compté de 1 comme à l'écran. Vide hors de l'initiation et en 0.9.
static func consignes_de(chapitre: int, numero: int) -> Array:
	return CONSIGNES.get("%d-%d" % [chapitre, numero], [])


# ---------------------------------------------------------------------------
# PENDANT LE JEU
# ---------------------------------------------------------------------------

## Appelé par la partie à chaque pas de jeu (phase JEU) : compte les abattus, valide les gestes faits.
func suivre(pnj: Array, delta: float) -> void:
	var abattus := 0
	for p in pnj:
		if is_instance_valid(p) and bool(p.dead):
			abattus += 1
	if abattus != _abattus:
		_abattus = abattus
		_maj_compteur()
		_pulser(_compteur, 1.35)
	if not is_instance_valid(_joueur) or bool(_joueur.dead):
		return
	if bool(_joueur.get("flashlight_on")):
		_torche_vue_allumee = true
	var reste := false
	for l in _lignes:
		if bool(l["fait"]):
			continue
		if _geste_fait(String(l["geste"])):
			_valider(l)
		else:
			reste = true
	if not _lignes.is_empty() and not reste:
		if _tout_fait_depuis < 0.0:
			_tout_fait_depuis = 0.0
		else:
			_tout_fait_depuis += delta
		if _tout_fait_depuis >= TENUE_APRES_TOUT:
			_consignes.modulate.a = maxf(_consignes.modulate.a - delta * 2.0, 0.0)


## Le geste a-t-il été FAIT ? Lu sur le corps quand il le dit (torche, posture, déplacement, cap), sur l'action quand
## seul l'appui existe (tir, recharge, fusée, gadget — chacun a un effet immédiat que le joueur voit).
func _geste_fait(geste: String) -> bool:
	match geste:
		"deplacer":
			return _joueur.global_position.distance_to(_depart) >= DISTANCE_DEPLACEMENT
		"viser":
			return absf(angle_difference(_cap_de_depart, _joueur.rotation)) >= ANGLE_VISEE
		"torche_allumer":
			return bool(_joueur.get("flashlight_on"))
		"torche_eteindre":
			return _torche_vue_allumee and not bool(_joueur.get("flashlight_on"))
		"accroupir":
			return bool(_joueur.get("accroupi"))
		"tirer":
			return Input.is_action_just_pressed("p1_shoot")
		"recharger":
			return Input.is_action_just_pressed("p1_reload")
		"fusee":
			return Input.is_action_just_pressed("p1_lance_fusee")
		"gadget":
			return Input.is_action_just_pressed("p1_gadget")
	return false


func _valider(l: Dictionary) -> void:
	l["fait"] = true
	var ligne: HBoxContainer = l["ligne"]
	# VERT, et pas l'ambre des touches ni le blanc chaud du texte : à la première capture, une ligne faite en HALOGENE ne se
	# distinguait pas d'une ligne à faire. Le vert est la seule couleur de la charte qui dise « réussi » sans rien d'autre.
	(ligne.get_node("Touches") as Label).label_settings.font_color = Charte.VERT
	(ligne.get_node("Texte") as Label).label_settings.font_color = Charte.VERT
	_pulser(ligne, 1.18)
	_son("ui_ready_ping")


func _ligne_de_consigne(geste: String, texte: String) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.name = "Consigne_%s" % geste
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 18)
	var touches := _etiquette("Touches", Charte.T_TITRE, Charte.AMBRE, Charte.POIDS_ENSEIGNE)
	touches.text = _touches_du_geste(geste)
	var dit := _etiquette("Texte", Charte.T_TITRE, Charte.PAPIER, Charte.POIDS_APPUI)
	dit.text = texte
	ligne.add_child(touches)
	ligne.add_child(dit)
	return ligne


func _touches_du_geste(geste: String) -> String:
	var actions: Array = ACTIONS_DU_GESTE.get(geste, [])
	if nommer_les_touches.is_valid():
		return String(nommer_les_touches.call(actions))
	return " ".join(actions)


func _maj_compteur() -> void:
	_compteur.text = "SILHOUETTES  %d / %d" % [_abattus, _total] if _total > 0 else ""


func _pulser(c: Control, ampleur: float) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	Charte.animer(tw, c, "scale", Vector2(ampleur, ampleur), Vector2.ONE, Charte.D_MOYEN, Charte.Courbe.REBOND)


## Par le nœud et non par le nom de l'autoload : ce script est aussi chargé par des bancs `--script`, compilés AVANT que les autoloads
## n'existent — le nom `AudioManager` y est inconnu et le fichier entier refuserait de compiler.
func _son(cle: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_ui(cle)


static func _temps(secondes: float) -> String:
	var s := maxf(secondes, 0.0)
	if s < 60.0:
		return ("%.1f s" % s).replace(".", ",")
	return "%d min %02d s" % [int(s) / 60, int(s) % 60]
