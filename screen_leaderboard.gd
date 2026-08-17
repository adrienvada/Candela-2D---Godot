class_name ScreenLeaderboard
extends HubScreen

## Écran « Classement » du hub : les dix premiers, et la ligne du joueur.
##
## Le serveur fait tout le travail. L'Edge Function `standing` rend le haut du
## tableau et la ligne du demandeur, rang compris ; cet écran ne calcule rien,
## il met en page. C'est la même règle que côté serveur, et pour la même raison :
## le rang est une fonction pure du classement, dérivée à un seul endroit. Un
## second calcul ici finirait par diverger du premier, et un classement faux
## reste plausible — personne ne le verrait.
##
## ## Ce qui fait la difficulté : les états, pas le tableau
##
## Le cas heureux — dix lignes et la mienne — est le plus rare des six. Les
## autres sont la vie normale du jeu :
##
## - **non configuré** : `supabase_config.gd` n'est pas versionné. Un nouveau
##   contributeur y tombe, et toute exécution headless aussi. Le jeu s'y joue
##   normalement : l'écran doit le dire sans prendre l'air d'une panne ;
## - **identification en cours**, **échec** (Epic, réseau ou serveur) ;
## - **profil connu, aucun match classé** : la seule chose à ne surtout pas
##   écrire est « 1000 points ». Le classement de départ existe côté serveur,
##   mais il n'est attribué qu'au premier match concordant. L'afficher avant
##   serait un chiffre inventé, et le dépôt a déjà tranché contre ;
## - **tableau vide** : personne n'a encore joué de match classé ;
## - **joueur hors des dix** : sa ligne se montre à part, sous le tableau.
##
## ## Manette
##
## Dix lignes tiennent dans le corps d'un écran de hub : aucun défilement, donc
## aucune liste à parcourir à la molette, et un seul contrôle à atteindre au
## curseur — le bouton qui relance la lecture.

# ===========================================================================
# HYPOTHÈSE ISOLÉE — ce que `ranked_identity.gd` n'expose pas encore
# ===========================================================================
#
# `RankedIdentity` lit déjà l'Edge Function `standing`, mais ne garde de sa
# réponse que la ligne du joueur : `_on_standing_completed()` ignore le champ
# `top`, et un échec de lecture y est silencieux. L'écran ne peut donc, à ce
# jour, obtenir ni le tableau ni la raison d'un tableau manquant.
#
# Rien n'est modifié dans l'autoload depuis ici, et aucun appel réseau n'est
# fait en direct. Le manque est isolé en un seul point : `_snapshot()`. Tant que
# la méthode attendue n'existe pas, l'écran affiche ma ligne — que l'autoload
# expose déjà — et dit franchement que le tableau n'est pas disponible, plutôt
# que de laisser un cadre vide qui passerait pour un défaut.
#
# La signature attendue, à ajouter à `ranked_identity.gd` :
#
#     ## Ce que la dernière lecture du classement a rendu, au-delà de ma ligne.
#     func standing_snapshot() -> Dictionary:
#         return {
#             "loaded": bool,   # une lecture a abouti — même si elle rend zéro ligne
#             "error": String,  # dernier échec de lecture, vide si la dernière a abouti
#             "top": Array,     # les lignes du tableau, au plus dix, déjà triées par rang
#         }
#
# Une seule méthode plutôt que trois propriétés : l'écran n'a qu'un point de
# contact à sonder, et les tests un seul point à simuler.

## Méthode attendue de l'autoload. Absente, l'écran se rabat sur ma seule ligne.
const SNAPSHOT_METHOD := "standing_snapshot"

## Clé, dans une ligne du tableau, du libellé de rang (« Bougie II »).
##
## Le serveur ne l'envoie pas encore : `standing/index.ts` sélectionne les
## colonnes de la vue `leaderboard`, et le libellé n'en est pas une — il se
## dérive par `rankOf()` dans `elo.ts`. La colonne reste donc vide tant que la
## fonction n'enrichit pas ses lignes. Elle n'est surtout pas recalculée ici :
## l'échelle a un seul propriétaire, et c'est le serveur.
const TIER_KEY := "rank_label"

## Hauteur du tableau. Miroir de la constante `TOP` de `standing/index.ts` : la
## fonction ne rend jamais plus de dix lignes.
const TOP_ROWS := 10

## Miroir de `RankedIdentity.State`. L'écran doit se construire sans l'autoload
## — c'est le contrat de `HubScreen`, et c'est ce qui le rend exerçable en test.
## La suite vérifie que ce miroir n'a pas dérivé de l'original.
enum Identity { UNCONFIGURED = 0, INITIALIZING = 1, READY = 2, FAILED = 3 }

## Les six états que l'écran sait raconter. Chacun produit un affichage
## distinct : c'est ce que la suite headless vérifie, faute de pouvoir joindre
## le serveur.
enum Display {
	## Pas de `supabase_config.gd` : le classement n'existe pas sur cette
	## installation. Ce n'est pas une panne, et ça ne doit pas y ressembler.
	UNCONFIGURED,
	## Identification Epic puis Supabase en cours.
	IDENTIFYING,
	## Epic injoignable, serveur muet, ou lecture refusée.
	FAILED,
	## Identifié, le tableau n'est pas encore arrivé.
	LOADING,
	## Profil connu, aucun match classé à son nom. Aucun chiffre à afficher.
	UNRANKED,
	## Profil classé : ma ligne existe, avec des chiffres qui viennent du serveur.
	RANKED,
}

## Largeur des colonnes à valeur fixe. La colonne du pseudo prend le reste.
const COL_RANK := 56
const COL_TIER := 132
const COL_RATING := 84
const COL_MATCHES := 78
const COL_RECORD := 118

const ROW_HEIGHT := 26
const FONT_ROW := 15
const FONT_HEAD := 12

## Écrit par les tests, qui construisent l'écran sans autoload. En jeu il reste
## nul et l'écran s'adresse à `/root/RankedIdentity`.
var identity_override: Node = null

var _status: Label
var _detail: Label
var _head: HBoxContainer
## Les dix lignes, créées une fois pour toutes et masquées quand elles ne
## servent pas : reconstruire des nœuds à chaque `refresh()` ferait perdre le
## focus du curseur et clignoter l'écran.
var _rows: Array[Dictionary] = []
## Message qui remplace le tableau quand il n'y a rien à y mettre.
var _table_notice: Label
var _mine_separator: Control
var _mine_row: Dictionary = {}
var _refresh_button: Button

var _display: Display = Display.UNCONFIGURED
## Vrai une fois branché aux signaux de l'identité classée. Un seul branchement
## par écran : le hub construit ses écrans une fois pour toute la partie.
var _wired: bool = false
var _table_reachable: bool = false
var _top: Array = []
var _outside_top: bool = false

func screen_title() -> String:
	return "Classement"

func focus_seed() -> Control:
	return _refresh_button

# ===========================================================================
# LECTURE DE L'ÉTAT — sans jamais rien inventer
# ===========================================================================

## État raconté par l'écran. Rend un `Display` même avant construction : les
## tests s'en servent pour vérifier que les six cas sont bien distingués.
func display_state() -> Display:
	return _display

## Le tableau est-il seulement joignable ? Faux tant que l'autoload n'expose pas
## `standing_snapshot()`.
func table_reachable() -> bool:
	return _table_reachable

## Le tableau a-t-il été lu et ne contient-il personne ? Seuls les deux états
## qui suivent une lecture aboutie peuvent répondre oui : ailleurs, un tableau
## vide veut seulement dire qu'on ne l'a pas encore.
func table_is_empty() -> bool:
	return _table_reachable and _top.is_empty() \
		and (_display == Display.UNRANKED or _display == Display.RANKED)

## Le joueur est-il classé mais hors des dix premiers ? C'est le seul cas où sa
## ligne se montre à part.
func is_outside_top() -> bool:
	return _outside_top

# ===========================================================================
# CONSTRUCTION
# ===========================================================================

func build(body: VBoxContainer) -> void:
	if body == null or not _rows.is_empty():
		return

	var head_box := VBoxContainer.new()
	head_box.add_theme_constant_override("separation", 2)
	body.add_child(head_box)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 19)
	head_box.add_child(_status)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", MenuTheme.DIM)
	head_box.add_child(_detail)

	var table := VBoxContainer.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 2)
	body.add_child(table)

	_head = _build_header()
	table.add_child(_head)

	for i in TOP_ROWS:
		var row := _build_row("Ligne_%d" % (i + 1))
		table.add_child(row["panel"])
		_rows.append(row)

	_table_notice = Label.new()
	_table_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_table_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_table_notice.add_theme_font_size_override("font_size", 14)
	_table_notice.add_theme_color_override("font_color", MenuTheme.DIM)
	table.add_child(_table_notice)

	# Un filet, et non un espace : sans marque visible, la ligne du joueur posée
	# sous un dixième se lirait comme un onzième du tableau.
	_mine_separator = _build_separator()
	table.add_child(_mine_separator)

	_mine_row = _build_row("LigneJoueur")
	table.add_child(_mine_row["panel"])

	_refresh_button = _build_refresh_button()
	body.add_child(_refresh_button)

	refresh()

func _build_header() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", MenuTheme.GAP_S)
	for spec in [
		["RANG", COL_RANK, HORIZONTAL_ALIGNMENT_RIGHT],
		["JOUEUR", 0, HORIZONTAL_ALIGNMENT_LEFT],
		["CATÉGORIE", COL_TIER, HORIZONTAL_ALIGNMENT_LEFT],
		["POINTS", COL_RATING, HORIZONTAL_ALIGNMENT_RIGHT],
		["MATCHS", COL_MATCHES, HORIZONTAL_ALIGNMENT_RIGHT],
		["V · D · N", COL_RECORD, HORIZONTAL_ALIGNMENT_RIGHT],
	]:
		var cell := _make_cell(int(spec[1]), int(spec[2]), FONT_HEAD)
		cell.text = String(spec[0])
		cell.add_theme_color_override("font_color", MenuTheme.DIM)
		line.add_child(cell)
	return line

func _build_row(node_name: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _row_style(false))
	panel.hide()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MenuTheme.GAP_XS)
	margin.add_theme_constant_override("margin_right", MenuTheme.GAP_XS)
	panel.add_child(margin)

	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	line.add_theme_constant_override("separation", MenuTheme.GAP_S)
	margin.add_child(line)

	var cells := {
		"rank": _make_cell(COL_RANK, HORIZONTAL_ALIGNMENT_RIGHT, FONT_ROW),
		"nickname": _make_cell(0, HORIZONTAL_ALIGNMENT_LEFT, FONT_ROW),
		"tier": _make_cell(COL_TIER, HORIZONTAL_ALIGNMENT_LEFT, FONT_ROW),
		"rating": _make_cell(COL_RATING, HORIZONTAL_ALIGNMENT_RIGHT, FONT_ROW),
		"matches": _make_cell(COL_MATCHES, HORIZONTAL_ALIGNMENT_RIGHT, FONT_ROW),
		"record": _make_cell(COL_RECORD, HORIZONTAL_ALIGNMENT_RIGHT, FONT_ROW),
	}
	for key in ["rank", "nickname", "tier", "rating", "matches", "record"]:
		line.add_child(cells[key])

	var row := cells.duplicate()
	row["panel"] = panel
	return row

func _make_cell(width: int, align: int, font_size: int) -> Label:
	var cell := Label.new()
	cell.horizontal_alignment = align
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.clip_text = true
	cell.add_theme_font_size_override("font_size", font_size)
	if width > 0:
		cell.custom_minimum_size = Vector2(width, 0)
	else:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cell

func _build_separator() -> Control:
	var rule := ColorRect.new()
	rule.color = MenuTheme.LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.hide()
	return rule

func _build_refresh_button() -> Button:
	var btn := Button.new()
	btn.name = "Rafraichir"
	btn.text = "RAFRAÎCHIR"
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(240, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = MenuTheme.SURFACE
	normal.set_border_width_all(2)
	normal.border_color = MenuTheme.LINE
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = MenuTheme.P1
	hover.bg_color = Color(MenuTheme.P1.r, MenuTheme.P1.g, MenuTheme.P1.b, 0.08)
	for state in ["hover", "focus", "pressed"]:
		btn.add_theme_stylebox_override(state, hover)

	btn.pressed.connect(refresh)
	return btn

func _row_style(mine: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	# Ma ligne s'allume ; les autres restent au fond du panneau. C'est la seule
	# façon de se retrouver dans dix lignes sans les lire une à une.
	box.bg_color = Color(MenuTheme.P1.r, MenuTheme.P1.g, MenuTheme.P1.b, 0.10) \
		if mine else MenuTheme.SURFACE
	box.set_border_width_all(1)
	box.border_color = MenuTheme.P1 if mine else MenuTheme.LINE
	box.set_corner_radius_all(6)
	return box

# ===========================================================================
# AFFICHAGE
# ===========================================================================

## Remet l'écran en accord avec `RankedIdentity`, et **relance la lecture**.
##
## Idempotent au sens du contrat : deux appels de suite donnent le même
## affichage, et un appel sur un écran jamais construit ne fait rien. La lecture
## relancée n'y contrevient pas — `refresh_standing()` se refuse lui-même tant
## qu'une requête est en vol ou que le profil n'est pas prêt, si bien que dix
## appels d'affilée ne produisent qu'une requête.
func refresh() -> void:
	var identity := _identity()
	_wire(identity)
	_request_standing(identity)
	_redisplay()

## Rejoue l'affichage **sans rien redemander**.
##
## C'est la moitié de `refresh()` qui répond aux signaux de l'autoload. Les
## brancher sur `refresh()` relancerait une requête à chaque réponse, donc en
## boucle, et le classement est un ornement du menu — pas une raison de marteler
## une Edge Function.
func _redisplay() -> void:
	var identity := _identity()
	_compute_state(identity)
	if _rows.is_empty():
		return
	_apply_status(identity)
	_apply_table(identity)

## Branche l'écran sur l'identité classée, une fois.
##
## Sans ces liaisons, la réponse du serveur — qui arrive bien après l'appel —
## n'atteindrait jamais l'écran : le joueur devrait appuyer deux fois sur
## RAFRAÎCHIR, une pour demander et une pour voir.
func _wire(identity: Node) -> void:
	if _wired or identity == null:
		return
	if identity.has_signal("standing_changed"):
		identity.connect("standing_changed", _redisplay)
	if identity.has_signal("state_changed"):
		identity.connect("state_changed", _on_identity_state_changed)
	_wired = true

func _on_identity_state_changed(_state: int) -> void:
	_redisplay()

func _request_standing(identity: Node) -> void:
	if identity == null or not identity.has_method("refresh_standing"):
		return
	if int(identity.state) != Identity.READY:
		return
	identity.refresh_standing()

## Établit l'état à partir de ce que l'autoload donne — et de rien d'autre.
func _compute_state(identity: Node) -> void:
	_top = []
	_outside_top = false
	_table_reachable = false

	if identity == null or int(identity.state) == Identity.UNCONFIGURED:
		_display = Display.UNCONFIGURED
		return
	if int(identity.state) == Identity.INITIALIZING:
		_display = Display.IDENTIFYING
		return
	if int(identity.state) == Identity.FAILED:
		_display = Display.FAILED
		return

	var snapshot := _snapshot(identity)
	_table_reachable = not snapshot.is_empty()
	if _table_reachable:
		if not String(snapshot.get("error", "")).is_empty():
			_display = Display.FAILED
			return
		if not bool(snapshot.get("loaded", false)):
			_display = Display.LOADING
			return
		var rows: Variant = snapshot.get("top", [])
		_top = (rows as Array) if rows is Array else []

	if not bool(identity.is_ranked):
		# Identifié ne veut pas dire classé : sans match concordant, il n'y a
		# aucun chiffre à son nom, et en inventer un serait faux.
		_display = Display.UNRANKED
		return

	_display = Display.RANKED
	_outside_top = _table_reachable and not _top.is_empty() \
		and _index_of_mine(identity) < 0

## Position de ma ligne dans le tableau, ou -1 si je n'y suis pas — ni si
## personne ne demande. `_apply_table()` s'exécute aussi sans identité
## joignable : sans ce garde-fou, l'écran « non configuré » lève une erreur de
## script à la construction, et une erreur de script n'échoue aucun test.
func _index_of_mine(identity: Node) -> int:
	if identity == null:
		return -1
	var mine := String(identity.profile_id)
	if mine.is_empty():
		return -1
	for i in _top.size():
		var row: Variant = _top[i]
		if row is Dictionary and String((row as Dictionary).get("player_id", "")) == mine:
			return i
	return -1

func _apply_status(identity: Node) -> void:
	match _display:
		Display.UNCONFIGURED:
			_status.text = "Classement non configuré sur cette installation."
			# Ton neutre et volontairement pas d'orange : ce n'est pas une panne,
			# et un nouveau contributeur ne doit pas croire qu'il a cassé quelque
			# chose. Le fichier de configuration n'est simplement pas versionné.
			_set_status_color(MenuTheme.DIM)
			_detail.text = "Le jeu se joue normalement : seul le tableau en ligne manque."
		Display.IDENTIFYING:
			_status.text = "Identification en cours…"
			_set_status_color(MenuTheme.DIM)
			_detail.text = "Le tableau s'affiche dès que le profil est reconnu."
		Display.FAILED:
			_status.text = "Classement indisponible."
			_set_status_color(MenuTheme.WARN)
			_detail.text = _failure_detail(identity)
		Display.LOADING:
			_status.text = "Lecture du classement…"
			_set_status_color(MenuTheme.DIM)
			_detail.text = _nickname_line(identity)
		Display.UNRANKED:
			# Aucun chiffre dans cette phrase, et c'est le point : le classement
			# de départ n'est attribué qu'au premier match concordant.
			_status.text = "Pas encore classé — jouez un match en ligne pour entrer au tableau."
			_set_status_color(MenuTheme.GOLD)
			_detail.text = _nickname_line(identity)
		Display.RANKED:
			_status.text = _ranked_line(identity)
			_set_status_color(MenuTheme.GOLD)
			_detail.text = _ranked_detail(identity)

func _set_status_color(color: Color) -> void:
	_status.add_theme_color_override("font_color", color)

func _nickname_line(identity: Node) -> String:
	var nickname := String(identity.nickname)
	return "Profil %s" % nickname if not nickname.is_empty() else ""

## Détail d'un échec : la phrase du serveur, si on en a une. Elle est déjà
## rédigée pour le joueur — la reformuler perdrait la cause exacte du refus.
func _failure_detail(identity: Node) -> String:
	var snapshot := _snapshot(identity)
	var reading := String(snapshot.get("error", ""))
	if not reading.is_empty():
		return reading
	var last := String(identity.last_error)
	return last if not last.is_empty() else "Serveur du classement injoignable."

func _ranked_line(identity: Node) -> String:
	# Tout ce qui suit vient du serveur : rien n'est recomposé, et le libellé de
	# rang n'est pas déduit du nombre de points.
	var nickname := String(identity.nickname)
	var who := nickname if not nickname.is_empty() else "Votre profil"
	return "%s — %de, %d points" % [who, int(identity.rank), int(identity.rating)]

## Deuxième ligne d'un joueur classé. Elle ne prétend jamais savoir où il se
## situe dans le tableau tant que le tableau n'a pas été lu.
func _ranked_detail(identity: Node) -> String:
	if _outside_top:
		return "Votre ligne est rappelée sous le tableau."
	if _table_reachable and not _top.is_empty():
		return "Vous êtes dans les dix premiers."
	return _nickname_line(identity)

func _apply_table(identity: Node) -> void:
	var mine_at := _index_of_mine(identity)
	var shown := 0
	for i in _rows.size():
		var visible := i < _top.size() and _top[i] is Dictionary
		if visible:
			_fill_row(_rows[i], _top[i] as Dictionary, mine_at == i)
			shown += 1
		(_rows[i]["panel"] as Control).visible = visible

	_head.visible = shown > 0
	_table_notice.text = _table_message()
	_table_notice.visible = not _table_notice.text.is_empty()

	# La ligne à part n'existe que pour un joueur classé absent des dix : dans
	# tous les autres cas elle ferait doublon, ou pire, afficherait des chiffres
	# là où il n'y en a pas.
	_mine_separator.visible = _outside_top
	(_mine_row["panel"] as Control).visible = _outside_top
	if _outside_top:
		_fill_row(_mine_row, _mine_as_row(identity), true)

## Ce qui remplace le tableau quand il n'y a rien à montrer. Chaîne vide quand
## le tableau, lui, a quelque chose à dire.
func _table_message() -> String:
	if _display == Display.UNCONFIGURED or _display == Display.IDENTIFYING \
			or _display == Display.FAILED or _display == Display.LOADING:
		return ""
	if not _table_reachable:
		return "Tableau de tête indisponible : cette version ne sait lire que votre ligne."
	if _top.is_empty():
		return "Personne n'a encore joué de match classé."
	return ""

## Ma ligne, recomposée depuis ce que l'autoload expose déjà, pour être rendue
## avec exactement la même mise en page que celles du tableau.
func _mine_as_row(identity: Node) -> Dictionary:
	return {
		"player_id": String(identity.profile_id),
		"nickname": String(identity.nickname),
		"rating": int(identity.rating),
		"rank": int(identity.rank),
		"matches": int(identity.matches_played),
		"wins": int(identity.wins),
		"losses": int(identity.losses),
		"draws": int(identity.draws),
	}

func _fill_row(row: Dictionary, data: Dictionary, mine: bool) -> void:
	(row["rank"] as Label).text = _number(data, "rank")
	(row["nickname"] as Label).text = String(data.get("nickname", "—"))
	# Vide tant que le serveur n'enrichit pas ses lignes : une colonne vide se
	# lit comme une colonne vide, un libellé recalculé ici se lirait comme une
	# vérité.
	(row["tier"] as Label).text = String(data.get(TIER_KEY, ""))
	(row["rating"] as Label).text = _number(data, "rating")
	(row["matches"] as Label).text = _number(data, "matches")
	(row["record"] as Label).text = _record(data)

	(row["panel"] as PanelContainer).add_theme_stylebox_override("panel", _row_style(mine))
	var accent := MenuTheme.P1 if mine else MenuTheme.GOLD
	(row["nickname"] as Label).add_theme_color_override("font_color",
		accent if mine else Color.WHITE)
	(row["rank"] as Label).add_theme_color_override("font_color", accent)

## Un nombre du serveur, ou un tiret. Jamais zéro par défaut : une absence et un
## zéro ne se ressemblent que dans le code.
##
## Tout nombre relu d'un JSON revient en flottant — un rang `1` vaut `1.0`, et
## l'écrire tel quel afficherait « 1.0e ».
func _number(data: Dictionary, key: String) -> String:
	if not data.has(key):
		return "—"
	return str(int(data[key]))

func _record(data: Dictionary) -> String:
	for key in ["wins", "losses", "draws"]:
		if not data.has(key):
			return "—"
	return "%d · %d · %d" % [int(data["wins"]), int(data["losses"]), int(data["draws"])]

# ===========================================================================
# ACCÈS À L'IDENTITÉ CLASSÉE
# ===========================================================================
#
# L'écran se construit seul, sans hub et sans autoload — contrat de `HubScreen`,
# et seule façon de l'exercer en test. Sans identité joignable, il affiche
# « non configuré », ce qui se trouve être exactement la vérité.

func _identity() -> Node:
	if identity_override != null:
		return identity_override
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/RankedIdentity")

## Le tableau et l'issue de sa lecture. Vide tant que l'autoload n'expose pas
## `standing_snapshot()` — voir l'hypothèse isolée en tête de fichier.
func _snapshot(identity: Node) -> Dictionary:
	if identity == null or not identity.has_method(SNAPSHOT_METHOD):
		return {}
	var value: Variant = identity.call(SNAPSHOT_METHOD)
	return (value as Dictionary) if value is Dictionary else {}
