class_name MatchBanner
extends PanelContainer

## Bandeau de recherche d'adversaire — Phase 8, étape 8.6.
##
## La recherche ne se fait pas dans un écran : **elle se fait pendant qu'on
## regarde ailleurs.** Appuyer sur « chercher un match » lance la file et rend la
## main ; le joueur continue de parcourir les menus, change d'arme, lit son
## classement, et le bandeau lui dit en permanence où en est la recherche.
##
## C'est la seule disposition qui ne mente pas sur la nature de l'attente. Un
## écran dédié immobilise le joueur devant un compte à rebours qu'il ne peut pas
## accélérer — il transforme une opération de fond en salle d'attente. Le bandeau
## dit la même chose sans rien confisquer.
##
## Il est collé au bord haut, centré, **au-dessus du titre du jeu** : une
## recherche en cours est l'information la plus périssable de l'écran, et c'est le
## seul endroit qu'aucun autre contenu ne dispute.
##
## Le cœur (`matchmaking.gd`) n'est pas connu de ce fichier autrement que par son
## chemin d'autoload et une poignée de méthodes vérifiées à l'exécution : le
## bandeau se tait s'il n'y a rien à interroger, plutôt que de tomber en panne.

## Le joueur a demandé à sortir de la file, ou à confirmer. L'appelant tranche.
signal action_requested(action: String)

const Charte := preload("res://charte.gd")
const MenuWidgets := preload("res://menu_widgets.gd")
const MenuTheme := preload("res://menu_theme.gd")

const MATCHMAKER_PATH := ^"/root/Matchmaker"

## Prises réelles de `matchmaking.gd`. Prises toutes ou pas du tout : un bandeau
## qui saurait lire l'état sans pouvoir annuler donnerait un bouton mort, et un
## bouton mort ne se distingue pas d'un jeu cassé.
const REQUIRED: Array[String] = ["search_snapshot", "cancel", "accept", "refuse"]

## Valeurs de `Matchmaking.State`, en clair. Recopier l'énumération obligerait ce
## fichier à charger la classe ; lire un entier qu'on n'a pas nommé finirait par
## confondre « au repos » et « en échec », tous deux inoffensifs à l'œil.
const ST_IDLE := 0
const ST_SEARCHING := 1
const ST_FOUND := 2
const ST_AWAITING := 3
const ST_FAILED := 4

var _titre: Label
var _detail: Label
var _boutons: HBoxContainer
var _btn_engage: Button
var _btn_retrait: Button
var _dernier_etat: int = -1

## Doublure de cœur pour les essais headless. Même prise que
## `ScreenMatchmaking.matchmaker_override` : l'autoload existe déjà dans une suite
## (inerte), donc une doublure ne peut pas se substituer à lui par le nom.
var matchmaker_override: Node = null

func _init() -> void:
	name = "MatchBanner"
	# Les menus tournent arbre en pause : un bandeau gelé afficherait un chrono
	# arrêté pendant que la file, elle, continue de courir.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ancré en haut, centré, largeur libre : il grandit avec son texte et reste au
	# milieu. `SHRINK_CENTER` sur un nœud ancré n'aurait aucun effet — c'est le
	# calcul d'offsets ci-dessous qui centre.
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	hide()
	_build()

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MenuTheme.SURFACE
	style.set_border_width_all(MenuWidgets.BORDER_WIDTH_CONTROL)
	style.border_width_top = 0
	style.border_color = MenuTheme.P1
	# Coins arrondis en bas seulement : le bandeau pend du bord de l'écran, il n'y
	# est pas posé.
	style.corner_radius_bottom_left = MenuWidgets.CORNER_PANEL
	style.corner_radius_bottom_right = MenuWidgets.CORNER_PANEL
	style.content_margin_left = MenuTheme.GAP_M
	style.content_margin_right = MenuTheme.GAP_M
	style.content_margin_top = MenuTheme.GAP_S
	style.content_margin_bottom = MenuTheme.GAP_S
	add_theme_stylebox_override("panel", style)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
	add_child(colonne)

	_titre = Label.new()
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(_titre, MenuTheme.T_COURANT, Charte.POIDS_APPUI)
	colonne.add_child(_titre)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(_detail, MenuTheme.T_MENTION)
	_detail.add_theme_color_override("font_color", MenuTheme.DIM)
	colonne.add_child(_detail)

	_boutons = HBoxContainer.new()
	_boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	_boutons.add_theme_constant_override("separation", MenuTheme.GAP_S)
	colonne.add_child(_boutons)

	# Deux emplacements fixes, rangés par intention : ce qui engage à gauche, ce
	# qui retire à droite, et jamais l'inverse. Un bouton unique qui passerait
	# d'ANNULER à CONFIRMER quand l'adversaire arrive confirmerait un match à
	# quelqu'un dont le doigt partait pour **sortir** de la file.
	_btn_engage = _make_button(MenuTheme.P1)
	_btn_engage.pressed.connect(_on_engage)
	_boutons.add_child(_btn_engage)

	_btn_retrait = _make_button(MenuTheme.DIM)
	_btn_retrait.pressed.connect(_on_retrait)
	_boutons.add_child(_btn_retrait)

func _make_button(accent: Color) -> Button:
	var btn := MenuWidgets.make_button("", accent, false, MenuTheme.T_COURANT, Vector2(160, 38))
	btn.hide()
	return btn

# ---------------------------------------------------------------------------
# LE CŒUR
# ---------------------------------------------------------------------------

## Le cœur, ou `null` s'il n'y a rien d'utilisable. Relu à chaque appel plutôt
## que retenu : sans Epic configuré l'autoload existe mais reste inerte, et un
## cache poserait l'absence pour toute la session.
func _usable() -> Node:
	var mm := matchmaker_override
	if mm == null:
		mm = get_node_or_null(MATCHMAKER_PATH) if is_inside_tree() else null
	if mm == null:
		return null
	for m in REQUIRED:
		if not mm.has_method(m):
			return null
	return mm

func _snapshot() -> Dictionary:
	var mm := _usable()
	if mm == null:
		return {}
	var v: Variant = mm.call("search_snapshot")
	return (v as Dictionary) if v is Dictionary else {}

# ---------------------------------------------------------------------------
# AFFICHAGE
# ---------------------------------------------------------------------------

## Le bandeau se tient à jour tout seul. Il lit un instantané par image plutôt
## que de s'abonner aux six signaux du cœur : le chrono avance de toute façon à
## chaque image, donc l'abonnement ne ferait économiser aucun réveil.
func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var snap := _snapshot()
	if snap.is_empty():
		_dernier_etat = -1
		hide()
		return

	var etat := int(snap.get("state", ST_IDLE))
	if etat == ST_IDLE:
		_dernier_etat = etat
		hide()
		return

	show()
	# **La file est nommée, pas seulement teintée.** Les deux recherches n'ont ni
	# les mêmes adversaires ni les mêmes règles — l'une apparie sur le classement,
	# l'autre prend n'importe qui — et la couleur seule ne le dit qu'à celui qui
	# connaît déjà le code. Un joueur qui attend doit pouvoir lire dans quelle file
	# il attend.
	var classe := bool(snap.get("ranked", false))
	_titre.text = "%s  —  %s" % [String(snap.get("state_label", "")).to_upper(),
		"CLASSÉ" if classe else "AMICAL"]
	_titre.add_theme_color_override("font_color",
		MenuTheme.GOLD if classe else MenuTheme.LUMIERE)
	_detail.text = _detail_text(etat, snap)
	_apply_buttons(etat)
	if etat != _dernier_etat:
		# Une seule fois par appariement, sur la BASCULE : `refresh()` est appelée
		# à chaque instantané, et jouer sur l'état plutôt que sur son changement
		# ferait un bourdonnement continu.
		if etat == ST_FOUND and _dernier_etat != ST_FOUND:
			# Par le CHEMIN d'autoload, jamais par le nom : `AudioManager` n'existe
			# pas à la compilation en mode `--script`, et le nommer empêchait ce
			# fichier de compiler. La suite ne pouvait alors plus l'instancier, sa
			# coroutine mourait avant `quit()`, et le processus **pendait** au lieu
			# d'échouer — trois se sont accumulés sur la machine avant qu'on
			# comprenne. C'est le même piège que `NetworkManager` dans
			# `ranked_identity.gd`, sous une troisième forme.
			#
			# Ce fichier atteint déjà `/root/Matchmaker` de cette façon : l'idiome
			# est le sien, pas une entorse.
			var audio := get_node_or_null(^"/root/AudioManager")
			if audio != null and audio.has_method("play_sfx"):
				audio.play_sfx("ui_ready_ping")
		_dernier_etat = etat
	_recenter()

## Ce qu'il y a à savoir sous le titre, et rien de plus.
##
## En recherche : depuis combien de temps, et **quelle fourchette est cherchée en
## ce moment** — c'est ce qui rend l'attente lisible plutôt que subie, le joueur
## voyant l'exigence baisser à mesure.
func _detail_text(etat: int, snap: Dictionary) -> String:
	match etat:
		ST_SEARCHING:
			var t := _clock(float(snap.get("elapsed", 0.0)))
			var f := String(snap.get("range_label", ""))
			return "%s  ·  %s" % [t, f] if f != "" else t
		ST_FOUND, ST_AWAITING:
			# Plus de décompte « pour répondre » : il n'y a plus rien à répondre.
			# Reste ce qui s'apprend — qui héberge, puisqu'en P2P l'hôte joue sans
			# latence et que taire l'asymétrie la transforme en rumeur.
			var qui := _who_hosts()
			return "Lancement du match…  ·  %s" % qui if qui != "" \
				else "Lancement du match…"
		ST_FAILED:
			var err := String(snap.get("last_error", ""))
			return err if err != "" else "Réessayez dans un instant."
	return ""

## Qui héberge, dit sans détour. En P2P l'hôte joue sans latence et son
## adversaire non : une asymétrie qu'on n'affiche pas devient une rumeur.
func _who_hosts() -> String:
	var mm := _usable()
	if mm == null or not mm.has_method("pairing_snapshot"):
		return ""
	var v: Variant = mm.call("pairing_snapshot")
	if not v is Dictionary:
		return ""
	var p: Dictionary = v
	if not p.has("local_hosts"):
		return ""
	return "vous hébergez" if bool(p["local_hosts"]) else "il héberge"

func _apply_buttons(etat: int) -> void:
	match etat:
		ST_SEARCHING:
			_set_button(_btn_engage, "")
			_set_button(_btn_retrait, "ANNULER")
		# Le match part tout seul : plus rien à confirmer ni à refuser. Laisser un
		# bouton de refus ici rendrait l'abandon possible pendant l'annonce, à
		# l'instant précis où le lien s'établit — et la file de l'autre camp
		# tomberait sans qu'il ait rien fait.
		ST_FOUND, ST_AWAITING:
			_set_button(_btn_engage, "")
			_set_button(_btn_retrait, "")
		ST_FAILED:
			_set_button(_btn_engage, "")
			_set_button(_btn_retrait, "FERMER")
		_:
			_set_button(_btn_engage, "")
			_set_button(_btn_retrait, "")
	_boutons.visible = _btn_engage.visible or _btn_retrait.visible

func _set_button(btn: Button, label: String) -> void:
	btn.text = label
	btn.visible = label != ""

## Recentre sur la largeur réelle du contenu. Un nœud ancré ne suit pas les
## règles de conteneur : sans cela le bandeau grandirait vers la droite à chaque
## fois que le texte s'allonge, et cesserait d'être centré.
func _recenter() -> void:
	var l := get_combined_minimum_size().x
	offset_left = -l * 0.5
	offset_right = l * 0.5
	offset_top = 0.0
	offset_bottom = get_combined_minimum_size().y

## Un compteur qui dit « 1:05 » plutôt que « 65 s » : au-delà d'une minute, le
## joueur compte en minutes.
func _clock(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]

# ---------------------------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------------------------

func _on_engage() -> void:
	var mm := _usable()
	if mm == null:
		return
	if _dernier_etat == ST_FOUND:
		mm.call("accept")
		action_requested.emit("accepter")
	refresh()

func _on_retrait() -> void:
	var mm := _usable()
	if mm == null:
		return
	if _dernier_etat == ST_FOUND or _dernier_etat == ST_AWAITING:
		mm.call("refuse")
		action_requested.emit("refuser")
	else:
		mm.call("cancel")
		action_requested.emit("annuler")
	refresh()

## Les contrôles atteignables en ce moment — pour le champ de navigation du menu,
## qui ne connaît pas la structure interne du bandeau.
func focusables() -> Array[Control]:
	var out: Array[Control] = []
	if not visible:
		return out
	for btn in [_btn_engage, _btn_retrait]:
		if btn.visible and not btn.disabled:
			out.append(btn)
	return out
