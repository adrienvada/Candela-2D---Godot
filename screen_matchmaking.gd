class_name ScreenMatchmaking
extends HubScreen

## Écran « Recherche de match » du hub : ce que la file cherche en ce moment, et
## où en est la poignée de main.
##
## ## Ce qui fait la difficulté : dire ce qu'on cherche
##
## Une barre qui tourne sans rien annoncer passe pour cassée au bout de vingt
## secondes — c'est écrit noir sur blanc à l'étape 8.5 de la feuille de route, et
## c'est la seule raison d'être de cet écran. La fourchette de classement
## cherchée **à cet instant** est donc au même rang d'importance que le temps
## écoulé : sans elle, l'attente n'a pas d'explication, et le joueur conclut au
## défaut plutôt qu'à la file peu peuplée.
##
## Deuxième chose qui ne se devine pas : **qui héberge**. En P2P l'hôte simule
## tout et joue à 0 ms (décision actée, prix assumé de l'absence de serveur
## dédié). Tant que ce n'est pas écrit à l'écran, l'asymétrie devient une rumeur
## — quelqu'un finit par affirmer que « l'hôte gagne toujours » sans que personne
## puisse le confirmer ni l'infirmer. Elle est donc affichée, dans les mêmes
## termes que ce soit à son avantage ou non.
##
## ## Ce que l'écran ne fait pas
##
## Il ne navigue pas (il émet `navigate_requested`), il ne connaît pas le
## transport, et il ne calcule ni fourchette ni délai : tout vient de
## l'appariement. Un second calcul ici finirait par diverger du premier, et une
## fourchette fausse reste plausible — personne ne la verrait.
##
## Il ne lance rien tout seul non plus. `refresh()` lit et met en page ; c'est
## tout. Un `refresh()` qui démarrerait la recherche mettrait le joueur en file
## au simple passage sur l'écran, et en classé cela l'engagerait dans un match
## qu'il n'a pas demandé.
##
## ## Manette
##
## Aucune popup, aucune liste à parcourir, et **aucun bouton désactivé** : un
## contrôle grisé sort du parcours du curseur, et le voir sortir en pleine action
## ressemble exactement à un défaut. Les deux boutons sont donc rangés par
## intention plutôt que par importance — voir `_apply_buttons()`.

# ===========================================================================
# LE POINT DE CONTACT — et c'est le seul
# ===========================================================================
#
# `matchmaking.gd` n'existe pas encore : il s'écrit en parallèle de cet écran.
# Tout ce que l'écran suppose de lui est rassemblé ici, en constantes nommées,
# de sorte que le raccordement final tienne dans ce bloc et nulle part ailleurs.
#
# ## Pourquoi aucun `preload`, et aucun miroir d'énumération
#
# `screen_profile.gd` emprunte l'énumération de `ranked_identity.gd` par
# `preload()` plutôt que de la recopier, et c'est la bonne règle : deux
# énumérations jumelles finissent toujours par diverger. Elle est inapplicable
# ici pour deux raisons cumulées :
#
#   • un `preload()` sur un chemin absent **échoue à l'analyse** du script, donc
#     emporte tout l'écran, pas seulement la ligne fautive ;
#   • un miroir d'énumération recopié à l'aveugle est pire que pas de miroir :
#     si l'autre agent ordonne ses valeurs autrement, l'écran lit « match
#     trouvé » là où l'appariement dit « en recherche », **sans la moindre
#     erreur** pour le signaler.
#
# La phase circule donc en **chaîne de caractères**, d'un vocabulaire arrêté
# ci-dessous. Une chaîne ne dérive pas quand on réordonne une énumération, et une
# chaîne inconnue se détecte au lieu de se confondre avec la valeur zéro.
#
# ## L'API attendue de `matchmaking.gd`
#
#     ## Autoload nommé `Matchmaking`.
#     signal matchmaking_changed
#
#     ## Tout ce que l'écran affiche, en une lecture. Aucune clé n'est
#     ## obligatoire hors `configured` et `phase` : une clé absente veut dire
#     ## « je ne sais pas », et l'écran n'affiche alors rien plutôt qu'un zéro.
#     func matchmaking_snapshot() -> Dictionary:
#         return {
#             "configured": bool,    # l'appariement est praticable ici
#             "phase": String,       # vocabulaire PHASE_* ci-dessous
#             "reason": String,      # pourquoi indisponible, déjà rédigé
#             "elapsed": float,      # secondes en file — absent si inconnu
#             "bracket": Array,      # [bas, haut] du classement cherché — absent si inconnu
#             "remaining": float,    # secondes restantes pour confirmer — absent si inconnu
#             "me": Dictionary,      # {"nickname": String, "rating": int, "rank_label": String}
#             "opponent": Dictionary,# idem — vide tant qu'il n'y a pas d'adversaire
#             "host_is_me": bool,    # ABSENT tant que l'hôte n'est pas désigné
#             "notice": String,      # dernier événement à annoncer, déjà rédigé
#         }
#
#     func start_search(ranked: bool) -> void
#     func cancel_search() -> void
#     func accept_match() -> void
#     func decline_match() -> void
#
# Les deux identités viennent du même instantané, y compris la mienne, alors que
# `RankedIdentity` saurait me la donner : l'appariement a apparié deux joueurs
# à un instant donné, et deux sources pour une même paire finiraient par
# s'afficher en désaccord.

## Le seul nom d'autoload que cet écran connaisse.
# L'autoload ne peut pas s'appeler `Matchmaking` : ce nom est déjà celui de la
# classe (`class_name Matchmaking`), et Godot refuse qu'un singleton masque une
# classe globale. D'où `Matchmaker` pour l'instance, `Matchmaking` pour le type.
const MATCHMAKER_PATH := ^"/root/Matchmaker"

# Noms réels de `matchmaking.gd`. Cet écran a été écrit AVANT ce fichier, contre
# une API supposée ; les noms ont divergé, et c'est précisément ce que ce bloc
# isolé prévoyait. La réconciliation tient ici et dans `_snapshot()`.
const SNAPSHOT_METHOD := "search_snapshot"
const START_METHOD := "start_search"
const CANCEL_METHOD := "cancel"
const ACCEPT_METHOD := "accept"
const DECLINE_METHOD := "refuse"
## Le cœur émet un signal par transition ; l'écran n'a besoin que de savoir que
## quelque chose a bougé. Il les écoute tous et se réaffiche.
const CHANGED_SIGNAL := "state_changed"

## Le point de contact est pris tel quel ou pas du tout.
##
## Un instantané lisible mais sans `accept_match()` donnerait un écran « match
## trouvé » dont le bouton ACCEPTER ne fait rien. Un bouton qui n'agit pas est un
## défaut ; un écran qui explique qu'il ne sait pas apparier est une information.
const REQUIRED_METHODS: Array[String] = [
	SNAPSHOT_METHOD, START_METHOD, CANCEL_METHOD, ACCEPT_METHOD, DECLINE_METHOD,
]

## Vocabulaire des phases. Arrêté ici, en clair, parce que c'est le contrat.
const PHASE_IDLE := "idle"
const PHASE_SEARCHING := "searching"
const PHASE_FOUND := "found"
const PHASE_AWAITING := "awaiting_peer"
const PHASE_DECLINED := "declined"
const PHASE_UNAVAILABLE := "unavailable"

## Écran du hub qui héberge le match amical par code. Miroir de
## `ui.gd:SCREEN_FRIENDLY` — c'est la porte de sortie de l'état « indisponible »,
## et la suite headless verrouille les deux valeurs l'une contre l'autre : un hub
## qui refuse silencieusement la navigation donne un bouton mort, et un bouton
## mort ne se distingue pas d'un jeu cassé.
const FRIENDLY_SCREEN := "en_ligne_amical"

# ===========================================================================
# CE QUE L'ÉCRAN RACONTE
# ===========================================================================

## Les six états, et ils font tout le travail. Le cas heureux — un adversaire
## trouvé à sa mesure — est le plus rare des six.
enum Display {
	## Pas d'appariement possible : ni `eos_credentials.gd` sur cette
	## installation, ni service joignable, ni point de contact dans cette
	## version. Le jeu se joue normalement et un match amical par code reste
	## jouable : ça ne doit surtout pas ressembler à une panne.
	UNAVAILABLE,
	## Rien n'est lancé. Une entrée invite à chercher.
	IDLE,
	## En file : le temps écoulé, et la fourchette cherchée en ce moment.
	SEARCHING,
	## Apparié : les deux identités, et qui héberge.
	FOUND,
	## J'ai confirmé ; l'autre doit confirmer, avec le délai restant.
	AWAITING_PEER,
	## L'autre a refusé ou n'a pas répondu. Retour en file, sans perdre son tour.
	PEER_DECLINED,
}

## Cadence de l'horloge. La seconde est la précision que le joueur lit ; plus
## souvent ne changerait qu'une chose, le nombre de fois par seconde où l'écran
## se réétiquette.
const CLOCK_PERIOD := 1.0

# Dix tailles nommées, prises sur l'échelle de la charte plutôt que choisies
# ici. Elles portaient dix valeurs distinctes entre 12 et 20 — une échelle
# privée de plus, dans un fichier que personne n'atteint depuis le hub, donc la
# plus facile à laisser dériver.
const FONT_STATUS := MenuTheme.T_APPUI
const FONT_DETAIL := MenuTheme.T_MENTION
const FONT_CLOCK := MenuTheme.T_APPUI
const FONT_BRACKET := MenuTheme.T_COURANT
const FONT_HOST := MenuTheme.T_COURANT
const FONT_HOST_WHY := MenuTheme.T_MENTION
const FONT_QUEUE := MenuTheme.T_MENTION
const FONT_ROLE := MenuTheme.T_MENTION
const FONT_NICKNAME := MenuTheme.T_APPUI
const FONT_STATS := MenuTheme.T_COURANT

const BUTTON_SIZE := Vector2(300, 40)

## Écrit par les tests, qui construisent l'écran sans autoload. En jeu il reste
## nul et l'écran s'adresse à `/root/Matchmaking`.
var matchmaker_override: Node = null

var _queue: Label
var _status: Label
var _detail: Label
## Les deux étiquettes vivantes, et les seules : voir `_apply_live()`.
var _bracket: Label
var _clock: Label
var _cards: HBoxContainer
var _card_me: Dictionary = {}
var _card_them: Dictionary = {}
var _host: Label
var _host_why: Label
var _engage: Button
var _withdraw: Button

var _display: Display = Display.UNAVAILABLE
var _reachable: bool = false
var _configured: bool = false
var _alarming: bool = false
var _bracket_known: bool = false
var _host_known: bool = false

## File classée ou amicale. **L'amical est le défaut** : l'étape 8.1 tranche que
## le classé doit être le cas explicite, faute de quoi un oubli de branchement
## ajouterait des matchs au classement — la faute qui ne se rattrape pas par un
## rejeu.
var _ranked: bool = false

## Action portée par chaque bouton dans l'état courant. Les signaux `pressed`
## sont branchés une seule fois, à la construction : rebrancher à chaque
## rafraîchissement empile les connexions, et un ACCEPTER branché trois fois
## confirme trois fois.
var _engage_action: String = ""
var _withdraw_action: String = ""

## Vrai une fois branché aux signaux de l'appariement. Un écran du hub est
## construit une fois pour toute la partie : un seul branchement.
var _wired: bool = false

var _clock_accum: float = 0.0
## Empreinte de tout ce qui, hors horloge et fourchette, décidait le dernier
## affichage. Sert à distinguer « une seconde de plus » de « la situation a
## changé » sans repeindre l'écran une fois par seconde.
var _live_signature: String = ""

func screen_title() -> String:
	return "Recherche de match"

## Le curseur se pose sur ce que le joueur est venu faire — et jamais sur rien :
## un écran sans amorce de curseur laisse le pouce sans prise.
func focus_seed() -> Control:
	if _engage != null and _engage.visible:
		return _engage
	return _withdraw

# ===========================================================================
# LECTURE DE L'ÉTAT — sans jamais rien inventer
# ===========================================================================

## État raconté par l'écran. Renseigné même avant construction : les tests s'en
## servent pour vérifier que les six cas sont bien distingués.
func display_state() -> Display:
	return _display

## Le point de contact est-il là, et complet ? Faux tant que `matchmaking.gd`
## n'existe pas, ou n'expose pas les cinq méthodes attendues.
func matchmaking_reachable() -> bool:
	return _reachable

## L'appariement est-il praticable sur cette installation ? Faux sans
## `eos_credentials.gd`, ce qui est le cas par défaut d'un dépôt frais.
func matchmaking_configured() -> bool:
	return _configured

## L'état courant est-il un ennui à signaler, ou seulement une absence ?
##
## Toute la différence entre « pas configuré ici » et « service injoignable » :
## le premier est un fait sans conséquence pour qui veut jouer, le second mérite
## la couleur d'avertissement. Les peindre pareil ferait passer une installation
## sans identifiants EOS pour un jeu cassé.
func is_alarming() -> bool:
	return _alarming

## La fourchette cherchée est-elle affichée ? Faux si l'appariement ne la
## communique pas — l'écran le dit alors, plutôt que d'en inventer une.
func bracket_shown() -> bool:
	return _bracket_known

## L'hôte est-il désigné ? Faux avant la désignation, et l'écran l'écrit : une
## moitié de match affichée sans son hôte laisserait croire qu'il n'y en a pas.
func host_known() -> bool:
	return _host_known

## Y a-t-il, à cet instant, un contrôle d'abandon **visible et atteignable au
## curseur** ? C'est l'invariant de la manette : pendant une recherche, une
## attente ou un retour en file, il doit toujours y avoir de quoi sortir.
func cancel_reachable() -> bool:
	return _withdraw != null and _withdraw.visible and not _withdraw.disabled \
		and _withdraw.focus_mode != Control.FOCUS_NONE

## File classée ou amicale.
func queue_is_ranked() -> bool:
	return _ranked

## Dit à l'écran de quelle file il parle. Le hub le sait, l'écran non : c'est le
## même partage que `ScreenEffects.set_ranked_context()`. Idempotent — le
## rappeler avec la même valeur ne coûte qu'un rafraîchissement.
func set_ranked_queue(ranked: bool) -> void:
	_ranked = ranked
	refresh()

# ===========================================================================
# CONSTRUCTION
# ===========================================================================

func build(body: VBoxContainer) -> void:
	if body == null or _status != null:
		return

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
	body.add_child(head)

	_queue = _make_line(FONT_QUEUE, MenuTheme.DIM)
	head.add_child(_queue)

	_status = _make_line(FONT_STATUS, MenuTheme.LUMIERE)
	head.add_child(_status)

	_detail = _make_line(FONT_DETAIL, MenuTheme.DIM)
	head.add_child(_detail)

	_bracket = _make_line(FONT_BRACKET, MenuTheme.P1)
	body.add_child(_bracket)

	_build_cards(body)

	var host_box := VBoxContainer.new()
	host_box.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
	body.add_child(host_box)

	_host = _make_line(FONT_HOST, MenuTheme.GOLD)
	host_box.add_child(_host)

	_host_why = _make_line(FONT_HOST_WHY, MenuTheme.DIM)
	host_box.add_child(_host_why)

	_clock = _make_line(FONT_CLOCK, MenuTheme.LUMIERE)
	body.add_child(_clock)

	# Verticale et non horizontale : les voisins de focus se déduisent de la
	# géométrie, et deux boutons empilés donnent un haut/bas franc au stick.
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	body.add_child(buttons)

	_engage = _make_button("Engager", MenuTheme.P1)
	_engage.pressed.connect(_on_engage)
	buttons.add_child(_engage)

	_withdraw = _make_button("Abandonner", MenuTheme.P2)
	_withdraw.pressed.connect(_on_withdraw)
	buttons.add_child(_withdraw)

	refresh()

func _make_line(font_size: int, color: Color) -> Label:
	var line := Label.new()
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", color)
	return line

func _build_cards(body: VBoxContainer) -> void:
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", MenuTheme.GAP_M)
	body.add_child(_cards)

	_card_me = _build_card("VOUS", MenuTheme.P1)
	_cards.add_child(_card_me["panel"])

	_card_them = _build_card("ADVERSAIRE", MenuTheme.P2)
	_cards.add_child(_card_them["panel"])

## Une carte d'identité. Les deux ont la même mise en page : un appariement se
## lit en comparant deux lignes, et deux mises en page différentes obligeraient à
## les lire une à une.
func _build_card(role: String, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Carte" + role.capitalize()
	panel.custom_minimum_size = Vector2(240, 0)

	var box := StyleBoxFlat.new()
	box.bg_color = MenuTheme.SURFACE
	box.set_border_width_all(2)
	box.border_color = accent
	box.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", MenuTheme.GAP_XS)
	margin.add_theme_constant_override("margin_bottom", MenuTheme.GAP_XS)
	margin.add_theme_constant_override("margin_left", MenuTheme.GAP_S)
	margin.add_theme_constant_override("margin_right", MenuTheme.GAP_S)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
	margin.add_child(column)

	var role_label := _make_line(FONT_ROLE, accent)
	role_label.text = role
	column.add_child(role_label)

	var nickname := _make_line(FONT_NICKNAME, MenuTheme.LUMIERE)
	nickname.clip_text = true
	column.add_child(nickname)

	var stats := _make_line(FONT_STATS, MenuTheme.DIM)
	column.add_child(stats)

	return {"panel": panel, "nickname": nickname, "stats": stats}

func _make_button(node_name: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = BUTTON_SIZE

	var normal := StyleBoxFlat.new()
	normal.bg_color = MenuTheme.SURFACE
	normal.set_border_width_all(2)
	normal.border_color = MenuTheme.LINE
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = accent
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.08)
	for state in ["hover", "focus", "pressed"]:
		btn.add_theme_stylebox_override(state, hover)

	return btn

# ===========================================================================
# AFFICHAGE
# ===========================================================================

## Remet l'écran en accord avec l'appariement, **sans rien lancer**.
##
## Idempotent au sens du contrat : deux appels de suite donnent le même
## affichage, et un appel sur un écran jamais construit ne fait rien. Il ne
## déclenche aucune commande — un `refresh()` qui démarrerait la recherche
## mettrait le joueur en file au simple passage sur l'écran.
func refresh() -> void:
	_wire()
	_redisplay()

## Branche l'écran sur l'appariement, une fois.
##
## Sans cette liaison, un appariement trouvé pendant que l'écran est affiché
## n'arriverait jamais jusqu'à lui : le joueur verrait « en recherche » alors que
## son adversaire l'attend, jusqu'à expiration du délai.
func _wire() -> void:
	if _wired:
		return
	var mm := _matchmaker()
	if mm == null:
		return
	if mm.has_signal(CHANGED_SIGNAL):
		# Le cœur émet `state_changed(state)` avec un argument ; `_redisplay` n'en
		# prend aucun, et Godot refuse la connexion telle quelle. `unbind(1)` jette
		# l'argument — l'écran ne s'en sert pas, il relit l'instantané complet.
		mm.connect(CHANGED_SIGNAL, Callable(self, "_redisplay").unbind(1))
	_wired = true

func _redisplay() -> void:
	var snap := _snapshot()
	_compute_state(snap)
	_live_signature = _signature(snap)
	_clock_accum = 0.0
	# L'horloge ne tourne que quand il y a une horloge à montrer : un écran au
	# repos n'a aucune raison de relire l'appariement une fois par seconde
	# pendant toute la partie.
	set_process(_needs_clock())
	if _status == null:
		return
	_apply_queue()
	_apply_status(snap)
	_apply_cards(snap)
	_apply_host(snap)
	_apply_live(snap)
	_apply_buttons()

## Établit l'état à partir de ce que l'appariement donne — et de rien d'autre.
func _compute_state(snap: Dictionary) -> void:
	_reachable = not snap.is_empty()
	_configured = _reachable and bool(snap.get("configured", false))
	_bracket_known = false
	_host_known = false

	if not _reachable or not _configured:
		# Pas de point de contact, ou pas d'identifiants sur cette machine. Ni
		# l'un ni l'autre n'est une panne, et la couleur d'alerte ne s'y applique
		# pas : le jeu se joue, et le match par code reste jouable.
		_display = Display.UNAVAILABLE
		_alarming = false
		return

	var phase := String(snap.get("phase", ""))
	match phase:
		PHASE_IDLE:
			_display = Display.IDLE
			_alarming = false
		PHASE_SEARCHING:
			_display = Display.SEARCHING
			_alarming = false
		PHASE_FOUND:
			_display = Display.FOUND
			_alarming = false
		PHASE_AWAITING:
			_display = Display.AWAITING_PEER
			_alarming = false
		PHASE_DECLINED:
			_display = Display.PEER_DECLINED
			# Un refus adverse est un contretemps, pas une erreur : la file
			# reprend. La couleur d'avertissement du thème est faite pour ça.
			_alarming = false
		_:
			# `unavailable`, et tout mot que cette version ne connaît pas. Une
			# phase inconnue n'est pas neutralisable : la traiter comme « au
			# repos » offrirait un bouton CHERCHER alors qu'une recherche tourne
			# peut-être déjà.
			_display = Display.UNAVAILABLE
			_alarming = true

	_bracket_known = _has_bracket(snap) and _shows_queue_progress()
	_host_known = _shows_pairing() and snap.has("host_is_me")

## Les états où une horloge court. Ailleurs, rien ne bouge tout seul.
func _needs_clock() -> bool:
	return _display == Display.SEARCHING or _display == Display.FOUND \
		or _display == Display.AWAITING_PEER or _display == Display.PEER_DECLINED

## Les états où l'on est en file : la fourchette et le temps écoulé s'y lisent.
## Le refus adverse en fait partie — c'est précisément le sens de « retour en
## file sans perdre son tour ».
func _shows_queue_progress() -> bool:
	return _display == Display.SEARCHING or _display == Display.PEER_DECLINED

## Les états où un adversaire est désigné et où les deux cartes se montrent.
func _shows_pairing() -> bool:
	return _display == Display.FOUND or _display == Display.AWAITING_PEER

func _apply_queue() -> void:
	if _ranked:
		_queue.text = "File classée — ce match comptera pour votre classement."
		_queue.add_theme_color_override("font_color", MenuTheme.GOLD)
	else:
		_queue.text = "File amicale — ce match ne comptera pas pour le classement."
		_queue.add_theme_color_override("font_color", MenuTheme.DIM)

func _apply_status(snap: Dictionary) -> void:
	match _display:
		Display.UNAVAILABLE:
			_status.text = "Appariement automatique indisponible."
			_status.add_theme_color_override("font_color",
				MenuTheme.WARN if _alarming else MenuTheme.DIM)
			_detail.text = _unavailable_detail(snap)
		Display.IDLE:
			_status.text = "Prêt à chercher un adversaire."
			_status.add_theme_color_override("font_color", MenuTheme.GOLD)
			_detail.text = "L'appariement cherche un classement proche du vôtre, " \
				+ "et élargit sa fourchette à mesure que l'attente dure."
		Display.SEARCHING:
			_status.text = "Recherche d'un adversaire…"
			_status.add_theme_color_override("font_color", MenuTheme.P1)
			# Le hub ne verrouille rien pendant une opération réseau : la
			# recherche survit à la navigation. Le dire évite qu'on reste planté
			# devant l'écran à la regarder tourner.
			_detail.text = "Vous pouvez parcourir les menus, la recherche continue. " \
				+ "Revenez ici pour confirmer."
		Display.FOUND:
			_status.text = "Adversaire trouvé."
			_status.add_theme_color_override("font_color", MenuTheme.GOLD)
			_detail.text = "Confirmez pour lancer le match. Sans réponse de votre " \
				+ "part, l'appariement repart en file."
		Display.AWAITING_PEER:
			_status.text = "En attente de votre adversaire."
			_status.add_theme_color_override("font_color", MenuTheme.P1)
			_detail.text = "Vous avez confirmé. C'est à lui de confirmer maintenant."
		Display.PEER_DECLINED:
			_status.text = "L'appariement n'a pas abouti."
			_status.add_theme_color_override("font_color", MenuTheme.WARN)
			_detail.text = _declined_detail(snap)

## Pourquoi l'appariement est indisponible. Trois causes distinctes, et les
## confondre serait envoyer un contributeur chercher une panne de serveur qui
## n'existe pas.
func _unavailable_detail(snap: Dictionary) -> String:
	var tail := " Un match amical par code reste jouable : le bouton ci-dessous y mène."
	if not _reachable:
		return "Cette version du jeu ne sait pas encore apparier." + tail
	if not _configured:
		# Cas de tout dépôt frais : `eos_credentials.gd` n'est pas versionné, le
		# jeu démarre normalement et seul le réseau local reste disponible.
		return "Cette installation n'a pas les identifiants nécessaires à " \
			+ "l'appariement en ligne." + tail
	var reason := String(snap.get("reason", ""))
	# La phrase de l'appariement est déjà rédigée pour le joueur : la reformuler
	# perdrait la cause exacte.
	if not reason.is_empty():
		return reason + tail
	return "Le service d'appariement est injoignable." + tail

## Le retour en file, annoncé sans accuser personne — et surtout pas le joueur.
func _declined_detail(snap: Dictionary) -> String:
	var notice := String(snap.get("notice", ""))
	if notice.is_empty():
		notice = "La confirmation de votre adversaire n'est pas venue."
	# La garantie tient à l'étape 8.4 : celui qui reste ne perd pas son tour.
	# L'écrire est ce qui distingue un contretemps d'un échec de son propre fait.
	return notice + " Vous restez en file, sans perdre votre tour."

func _apply_cards(snap: Dictionary) -> void:
	var shown := _shows_pairing()
	_cards.visible = shown
	if not shown:
		return
	_fill_card(_card_me, _sub(snap, "me"))
	_fill_card(_card_them, _sub(snap, "opponent"))

func _fill_card(card: Dictionary, who: Dictionary) -> void:
	var nickname := String(who.get("nickname", ""))
	(card["nickname"] as Label).text = nickname if not nickname.is_empty() else "—"
	(card["stats"] as Label).text = _stats_line(who)

## Classement et catégorie, s'ils existent. Une absence rend un tiret, jamais un
## zéro : « 0 point » est une affirmation, et elle serait fausse. En file amicale
## il n'y a légitimement aucun chiffre à montrer.
func _stats_line(who: Dictionary) -> String:
	var parts := PackedStringArray()
	if who.has("rating"):
		parts.append("%d points" % int(who["rating"]))
	var tier := String(who.get("rank_label", ""))
	if not tier.is_empty():
		parts.append(tier)
	return " · ".join(parts) if parts.size() > 0 else "—"

## Qui héberge — la ligne la plus importante de l'écran de match trouvé.
##
## La même phrase d'explication dans les deux cas : l'asymétrie est une propriété
## du P2P, pas un reproche à celui qui en profite. Et rien du tout tant que l'hôte
## n'est pas désigné — le deviner à partir de qui cherchait donnerait une réponse
## juste une fois sur deux, ce qui est pire que pas de réponse.
func _apply_host(snap: Dictionary) -> void:
	var shown := _shows_pairing()
	_host.visible = shown
	_host_why.visible = shown
	if not shown:
		return

	if not _host_known:
		_host.text = "Hôte pas encore désigné."
		_host.add_theme_color_override("font_color", MenuTheme.DIM)
		_host_why.text = "Il le sera avant le lancement, et il sera écrit ici."
		return

	if bool(snap["host_is_me"]):
		_host.text = "Vous hébergez ce match."
	else:
		var nickname := String(_sub(snap, "opponent").get("nickname", ""))
		if nickname.is_empty():
			_host.text = "Votre adversaire héberge ce match."
		else:
			_host.text = "%s héberge ce match." % nickname
	_host.add_theme_color_override("font_color", MenuTheme.GOLD)
	_host_why.text = "Sans serveur dédié, c'est l'hôte qui simule le match : " \
		+ "il joue sans latence, son adversaire non."

# ---------------------------------------------------------------------------
# LES DEUX ÉTIQUETTES VIVANTES
# ---------------------------------------------------------------------------
#
# Le temps écoulé change chaque seconde, la fourchette s'élargit par paliers.
# Tout le reste ne change que sur événement. Repeindre l'écran entier une fois
# par seconde le ferait scintiller et déplacerait le focus du curseur — sur un
# écran qu'on regarde parfois une minute d'affilée, c'est intenable.
#
# Ces deux étiquettes sont donc les seules que la cadence touche, et l'horloge
# est celle de l'appariement, pas la nôtre : l'écran ne compte pas le temps, il
# lit celui de la file. Deux compteurs indépendants finiraient par se contredire
# à l'affichage.

func _process(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if not _needs_clock() or _status == null:
		return
	_clock_accum += delta
	if _clock_accum < CLOCK_PERIOD:
		return
	_clock_accum = 0.0
	var snap := _snapshot()
	# Filet de sécurité pour un appariement qui n'émettrait aucun signal : si
	# autre chose que l'horloge a bougé, on repeint tout. Sinon on ne touche que
	# les deux étiquettes.
	if _signature(snap) != _live_signature:
		_redisplay()
		return
	_apply_live(snap)

func _apply_live(snap: Dictionary) -> void:
	_clock.text = _clock_text(snap)
	_clock.visible = not _clock.text.is_empty()
	_bracket.text = _bracket_text(snap)
	_bracket.visible = not _bracket.text.is_empty()
	_bracket.add_theme_color_override("font_color",
		MenuTheme.P1 if _bracket_known else MenuTheme.DIM)

func _clock_text(snap: Dictionary) -> String:
	if _shows_queue_progress():
		if not snap.has("elapsed"):
			return ""
		return "En file depuis %s." % _elapsed_text(float(snap["elapsed"]))
	if not snap.has("remaining"):
		return ""
	var left := _remaining_text(float(snap["remaining"]))
	if _display == Display.FOUND:
		return "Il vous reste %s pour confirmer." % left
	if _display == Display.AWAITING_PEER:
		return "Sa réponse est attendue sous %s." % left
	return ""

## La fourchette cherchée en ce moment — le point le plus important de l'écran.
##
## Si l'appariement ne la communique pas, l'écran le dit au lieu de laisser un
## blanc : une ligne vide se lit comme un défaut de mise en page, et une
## fourchette recomposée ici serait un chiffre inventé.
func _bracket_text(snap: Dictionary) -> String:
	if not _shows_queue_progress():
		return ""
	if not _bracket_known:
		return "L'appariement ne communique pas la fourchette cherchée."
	var bracket: Array = snap["bracket"]
	return "Fourchette cherchée : %d – %d points." % [int(bracket[0]), int(bracket[1])]

## Temps déjà passé : arrondi vers le bas. Annoncer une seconde qui n'est pas
## écoulée ferait avancer le compteur avant l'heure.
func _elapsed_text(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	if total < 60:
		return "%d s" % total
	return "%d min %02d s" % [total / 60, total % 60]

## Temps restant : arrondi vers le haut. Afficher zéro pendant qu'il reste une
## fraction de seconde pour confirmer serait un mensonge — celui qui coûte le
## match.
func _remaining_text(seconds: float) -> String:
	return "%d s" % maxi(0, ceili(seconds))

# ---------------------------------------------------------------------------
# LES DEUX BOUTONS
# ---------------------------------------------------------------------------

## Deux emplacements fixes, rangés par **intention** et non par importance :
## l'engagement en haut, le retrait en bas.
##
## C'est ce qui rend l'écran sûr à la manette. Un unique bouton dont le libellé
## passerait de ANNULER à CONFIRMER au moment où l'adversaire est trouvé
## confirmerait un match à qui appuyait pour sortir de la file. En gardant le
## retrait à sa place, le curseur qui s'y trouvait y reste, et l'appui garde son
## sens. Aucun des deux n'est jamais désactivé : un bouton grisé sort du parcours
## du curseur, et le voir sortir en pleine action ressemble à un défaut.
func _apply_buttons() -> void:
	match _display:
		Display.UNAVAILABLE:
			# Rien à abandonner, et rien à réessayer sur commande : `refresh()`
			# relit l'appariement à chaque fois que l'écran s'affiche. Reste la
			# porte de sortie, qui elle est utile tout de suite.
			_set_engage("MATCH AMICAL PAR CODE", "friendly")
			_set_withdraw("", "")
		Display.IDLE:
			_set_engage("CHERCHER UN MATCH", "start")
			_set_withdraw("", "")
		Display.SEARCHING:
			_set_engage("", "")
			_set_withdraw("ANNULER LA RECHERCHE", "cancel")
		Display.FOUND:
			_set_engage("CONFIRMER", "accept")
			_set_withdraw("REFUSER", "decline")
		Display.AWAITING_PEER:
			# On peut encore renoncer pendant l'attente : l'étape 8.4 l'exige, et
			# sans cela un adversaire qui ne répond jamais retient le joueur
			# jusqu'à expiration.
			_set_engage("", "")
			_set_withdraw("RENONCER À CE MATCH", "cancel")
		Display.PEER_DECLINED:
			_set_engage("", "")
			_set_withdraw("ANNULER LA RECHERCHE", "cancel")

func _set_engage(label: String, action: String) -> void:
	_engage_action = action
	_engage.text = label
	_engage.visible = not label.is_empty()

func _set_withdraw(label: String, action: String) -> void:
	_withdraw_action = action
	_withdraw.text = label
	_withdraw.visible = not label.is_empty()

func _on_engage() -> void:
	match _engage_action:
		"friendly":
			# L'écran ne navigue pas de lui-même : il demande, le hub tranche.
			navigate_requested.emit(FRIENDLY_SCREEN)
			return
		"start":
			# Le cœur attend un mode et un classement, pas un booléen : il filtre
			# la fourchette d'après le classement réel, et un joueur non classé
			# n'est pas placé du tout plutôt qu'estimé.
			var mode := 1 if _ranked else 0
			var note := -1
			if is_instance_valid(RankedIdentity) and RankedIdentity.is_ranked:
				note = RankedIdentity.rating
			_command(START_METHOD, [mode, note])
		"accept":
			_command(ACCEPT_METHOD, [])
	_redisplay()

func _on_withdraw() -> void:
	match _withdraw_action:
		"cancel":
			_command(CANCEL_METHOD, [])
		"decline":
			_command(DECLINE_METHOD, [])
	_redisplay()

# ===========================================================================
# ACCÈS À L'APPARIEMENT
# ===========================================================================
#
# L'écran se construit seul, sans hub et sans autoload — contrat de `HubScreen`,
# et seule façon de l'exercer en test. Sans appariement joignable il affiche
# « indisponible », ce qui se trouve être exactement la vérité.

func _matchmaker() -> Node:
	if matchmaker_override != null:
		return matchmaker_override
	if not is_inside_tree():
		return null
	return get_node_or_null(MATCHMAKER_PATH)

## L'appariement, s'il est là **et complet**. Nul sinon.
##
## `has_method()` est interrogé sur l'instance et non sur le script : posé sur un
## `GDScript`, il ne rendrait que les méthodes statiques et déclarerait absentes
## les quatre commandes.
func _usable() -> Node:
	var mm := _matchmaker()
	if mm == null:
		return null
	for method in REQUIRED_METHODS:
		if not mm.has_method(method):
			return null
	return mm

## Tout ce que l'écran affiche, en une lecture. Dictionnaire vide tant que
## `matchmaking.gd` n'existe pas — l'écran dit alors qu'il ne sait pas apparier,
## plutôt que de laisser un cadre vide qui passerait pour un défaut.
func _snapshot() -> Dictionary:
	var mm := _usable()
	if mm == null:
		return {}
	var value: Variant = mm.call(SNAPSHOT_METHOD)
	if not value is Dictionary:
		return {}
	return _adapt(mm, value as Dictionary)

## Traduit l'instantané du cœur dans le vocabulaire de cet écran.
##
## Deux vocabulaires plutôt qu'un seul partagé, et c'est délibéré : le cœur pense
## en machine à états (`State.AWAITING_ACCEPT`), l'écran pense en ce que le joueur
## regarde (« il doit confirmer »). Les faire coïncider de force aurait obligé
## l'un des deux à porter le vocabulaire de l'autre. La traduction est ici, en un
## seul endroit, et **toute clé qu'on ne sait pas remplir est omise** — l'écran
## n'affiche alors rien plutôt que d'inventer.
func _adapt(mm: Node, raw: Dictionary) -> Dictionary:
	# Un instantané déjà rédigé dans le vocabulaire de cet écran n'a rien à
	# traduire. Le cas ne se produit qu'avec une doublure de test : le cœur réel
	# rend `supported`/`state`, jamais `phase`. La traduction est donc idempotente
	# sans masquer de dérive — si le cœur se mettait un jour à parler cette langue,
	# c'est qu'il aurait été réécrit pour cela.
	if raw.has("phase"):
		return raw

	var out := {}
	out["configured"] = bool(raw.get("supported", false))

	var etat := int(raw.get("state", 0))
	var perdus := int(raw.get("handshakes_lost", 0))
	# Un refus adverse ramène le cœur en recherche, le tour préservé. C'est bien
	# « en file » du point de vue de la mécanique, mais le joueur doit d'abord
	# apprendre qu'on l'a refusé — sans quoi le compteur repart sans explication.
	if etat == 1 and perdus > 0:
		out["phase"] = PHASE_DECLINED
	else:
		match etat:
			0: out["phase"] = PHASE_IDLE
			1: out["phase"] = PHASE_SEARCHING
			2: out["phase"] = PHASE_FOUND
			3: out["phase"] = PHASE_AWAITING
			_: out["phase"] = PHASE_UNAVAILABLE

	var erreur := String(raw.get("last_error", ""))
	if erreur != "":
		out["reason"] = erreur
	if raw.has("elapsed"):
		out["elapsed"] = float(raw["elapsed"])
	if raw.has("handshake_remaining"):
		out["remaining"] = float(raw["handshake_remaining"])

	# La fourchette n'est une fourchette qu'avec ses deux bornes. Ouverte, elle
	# n'en est pas une : l'écran dira « toutes catégories » par son propre libellé.
	if not bool(raw.get("range_open", true)) and raw.has("range_low") and raw.has("range_high"):
		out["bracket"] = [int(raw["range_low"]), int(raw["range_high"])]

	if is_instance_valid(RankedIdentity) and RankedIdentity.is_ready():
		var moi := {"nickname": RankedIdentity.nickname}
		if RankedIdentity.is_ranked:
			moi["rating"] = RankedIdentity.rating
		out["me"] = moi

	var paire: Variant = mm.call("pairing_snapshot") if mm.has_method("pairing_snapshot") else {}
	if paire is Dictionary and not (paire as Dictionary).is_empty():
		var p: Dictionary = paire
		var adv := {}
		# Le cœur ne connaît que des clés d'identité, pas des pseudos : les
		# afficher serait montrer un PUID à un joueur. Faute de pseudo, on n'en
		# invente pas — l'écran écrira « adversaire ».
		if p.has("opponent_rating") and int(p["opponent_rating"]) >= 0:
			adv["rating"] = int(p["opponent_rating"])
		out["opponent"] = adv
		if p.has("local_hosts"):
			out["host_is_me"] = bool(p["local_hosts"])
	return out

func _command(method: String, args: Array) -> void:
	var mm := _usable()
	if mm == null:
		return
	mm.callv(method, args)

## Un sous-dictionnaire de l'instantané, ou vide. Une clé absente et une clé
## d'un autre type mènent au même endroit : on n'affiche rien.
func _sub(snap: Dictionary, key: String) -> Dictionary:
	var value: Variant = snap.get(key, {})
	return (value as Dictionary) if value is Dictionary else {}

## La fourchette est-elle utilisable telle quelle ? Deux bornes, et pas une.
func _has_bracket(snap: Dictionary) -> bool:
	var value: Variant = snap.get("bracket", null)
	return value is Array and (value as Array).size() == 2

## Tout ce qui décide l'affichage **hors horloge et hors fourchette**.
##
## La fourchette en est exclue à dessein : elle s'élargit pendant la recherche,
## et l'y mettre déclencherait un repeint complet de l'écran à chaque palier —
## exactement ce que la cadence cherche à éviter.
func _signature(snap: Dictionary) -> String:
	if snap.is_empty():
		return ""
	return "%s|%s|%s|%s|%s|%s|%s" % [
		str(snap.get("configured", false)),
		String(snap.get("phase", "")),
		String(snap.get("reason", "")),
		str(snap.get("me", {})),
		str(snap.get("opponent", {})),
		str(snap.get("host_is_me", null)),
		String(snap.get("notice", "")),
	]
