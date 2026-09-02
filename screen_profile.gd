class_name ScreenProfile
extends HubScreen

## Écran « Profil » du hub : qui est ce joueur pour le classement, et le seul
## secret qu'il ait à conserver.
##
## ## Pourquoi le code de récupération est affiché en grand
##
## L'identité classée s'appuie sur le Device ID d'Epic, qui est lié à la
## MACHINE. Un joueur qui change d'ordinateur arrive avec un PUID neuf : sans le
## code, son classement est perdu, et personne — pas même le serveur — ne peut
## le lui rendre, puisque c'est précisément ce code qui prouve que le profil est
## le sien. Il est donc affiché en grand, copiable en un appui, et jamais replié
## derrière un sous-menu : c'est **la seule chose** que le joueur ait à garder.
##
## ## Ce que l'écran ne fait pas
##
## Il ne touche pas au réseau (contrat de `HubScreen`) : il lit `RankedIdentity`
## et lui demande un rattachement, rien d'autre. Il ne navigue pas non plus, et
## n'ouvre aucune fenêtre modale — le jeu se joue à la manette, et une popup
## qu'on ne sait pas fermer au pouce est pire que pas de confirmation du tout.
## Toutes les réponses de l'écran sont donc des lignes de texte à leur place.
##
## ## Les six situations à tenir
##
## non configuré · identification en cours · prête · échec réseau ·
## rattachement refusé · rattachement réussi.
##
## La première est la plus facile à rater. `supabase_config.gd` n'est pas
## versionné : il est donc absent chez tout nouveau contributeur et dans les
## tests headless. Le jeu se joue alors normalement, il n'y a simplement pas de
## classement. L'écran doit énoncer ce fait **sans ressembler à une panne** —
## d'où deux registres séparés, la couleur d'alerte étant réservée aux échecs
## (voir `is_alarming()`).

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")
const MenuWidgets := preload("res://menu_widgets.gd")
const RANKED := preload("res://ranked_identity.gd")

const COPY_LABEL := "COPIER"
const COPY_DONE := "Code copié dans le presse-papiers."
const LINK_LABEL := "RATTACHER"
const LINK_PENDING := "Rattachement en cours…"

## Écrit par les tests, qui construisent l'écran sans autoload. En jeu il reste
## nul et l'écran s'adresse à `/root/RankedIdentity`.
var identity_override: Node = null

var _status: Label
var _explain: Label
var _nickname: Label
var _btn_rename: Button
var _rename_row: HBoxContainer
var _rename_input: LineEdit
var _btn_rename_ok: Button
var _btn_rename_cancel: Button
var _rename_feedback: Label
var _standing: Label
var _code: Label
var _btn_copy: Button
var _copy_feedback: Label
var _hint: Label
var _link_input: LineEdit
var _btn_link: Button
var _link_progress: Label
var _link_feedback: Label

## Identité à laquelle les signaux sont branchés. Gardée pour ne brancher qu'une
## fois et pour savoir quoi débrancher si elle change.
var _bound: Node = null

## Code effectivement copié par le joueur. Sert à décider si la confirmation
## affichée parle encore du code qui est à l'écran : après un rattachement, le
## profil n'est plus le même et un « code copié » resté là serait un mensonge.
var _copied: String = ""

func screen_title() -> String:
	return "Profil"

## Le curseur se pose sur ce qui compte : mettre le code à l'abri. À défaut, sur
## le rattachement — l'autre raison d'être ici. Jamais sur le champ de saisie :
## un `LineEdit` reste atteignable à la navigation, mais l'y déposer d'office à
## la manette donne un curseur qui a l'air perdu dans une case vide.
func focus_seed() -> Control:
	if _btn_copy != null and not _btn_copy.disabled:
		return _btn_copy
	if _btn_link != null and not _btn_link.disabled:
		return _btn_link
	return null

## Le renommage a attendu un point d'entrée serveur jusqu'au 2026-08-18 ; la
## fonction `rename` est déployée depuis, et c'est ici que la porte s'ouvre —
## la place était réservée dans la mise en page depuis l'origine.
##
## Deux conditions, et la seconde n'est pas décorative : un profil non identifié
## n'a pas de pseudo à changer, et une installation sans classement n'a pas de
## `rename()` à appeler. Montrer le bouton dans l'un ou l'autre cas donnerait une
## action qui échoue — indiscernable d'un jeu cassé.
func can_rename() -> bool:
	var identity := _identity()
	return identity != null and _state() == RANKED.State.READY \
		and identity.has_method("rename")

## Y a-t-il un code à montrer ? Un profil non identifié n'en a pas, et afficher
## un gabarit de tirets à sa place vaut mieux qu'un code inventé que le joueur
## noterait.
func has_recovery_code() -> bool:
	return not _recovery_code().is_empty()

## L'état courant est-il un ennui à signaler, ou seulement une absence ?
##
## C'est toute la différence entre « non configuré » et « échec » : le premier
## est un fait sans conséquence pour qui veut jouer, le second mérite la couleur
## d'avertissement. Peindre les deux pareil ferait passer une installation sans
## classement pour un jeu cassé.
func is_alarming() -> bool:
	return _state() == RANKED.State.FAILED

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	if body == null or _status != null:
		return

	_build_identity_block(body)
	_build_code_block(body)
	_build_link_block(body)

	_bind_identity()
	refresh()

## Ce que le serveur sait de ce joueur, et dans quel état est la liaison.
func _build_identity_block(body: VBoxContainer) -> void:
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(_status, MenuTheme.T_COURANT)
	body.add_child(_status)

	# La ligne qui empêche « non configuré » de passer pour une panne : elle dit
	# ce que ça change pour le joueur, c'est-à-dire rien tant qu'il joue.
	_explain = Label.new()
	_explain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(_explain, MenuTheme.T_MENTION)
	_explain.add_theme_color_override("font_color", MenuTheme.DIM)
	body.add_child(_explain)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", MenuTheme.GAP_S)
	body.add_child(name_row)

	_nickname = Label.new()
	Charte.enseigne(_nickname, MenuTheme.T_TITRE)
	_nickname.add_theme_color_override("font_color", MenuTheme.P1)
	name_row.add_child(_nickname)

	# Construit mais caché : un contrôle invisible est hors d'atteinte du curseur
	# (`_collect_focusables` s'arrête aux contrôles cachés), donc le joueur ne
	# peut pas demander une action qui n'aboutirait pas. Voir `can_rename()`.
	_btn_rename = _make_button("MODIFIER", MenuTheme.P1)
	_btn_rename.custom_minimum_size = Vector2(120, 34)
	_btn_rename.hide()
	_btn_rename.pressed.connect(_open_rename)
	name_row.add_child(_btn_rename)

	# La saisie prend la place du pseudo plutôt que de s'ajouter en dessous : on
	# modifie ce qu'on regarde, et la ligne ne se déplace pas au moment où l'on
	# bascule de l'un à l'autre.
	_rename_row = HBoxContainer.new()
	_rename_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rename_row.add_theme_constant_override("separation", MenuTheme.GAP_S)
	_rename_row.hide()
	body.add_child(_rename_row)

	_rename_input = LineEdit.new()
	_rename_input.custom_minimum_size = Vector2(300, 40)
	_rename_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_input.max_length = RecoveryCode.NICKNAME_MAX
	_rename_input.add_theme_stylebox_override("normal", MenuWidgets.make_line_edit_style(false))
	_rename_input.add_theme_stylebox_override("focus", MenuWidgets.make_line_edit_style(true))
	Charte.appareil(_rename_input, MenuTheme.T_COURANT)
	_rename_input.text_submitted.connect(func(_t: String) -> void: _request_rename())
	_rename_row.add_child(_rename_input)

	_btn_rename_ok = _make_button("VALIDER", MenuTheme.P1)
	_btn_rename_ok.pressed.connect(_request_rename)
	_rename_row.add_child(_btn_rename_ok)

	_btn_rename_cancel = _make_button("ANNULER", MenuTheme.DIM)
	_btn_rename_cancel.pressed.connect(_close_rename)
	_rename_row.add_child(_btn_rename_cancel)

	_rename_feedback = Label.new()
	_rename_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(_rename_feedback, MenuTheme.T_MENTION)
	_rename_feedback.add_theme_color_override("font_color", MenuTheme.DIM)
	body.add_child(_rename_feedback)

	# Le classement lui-même reste vide tant qu'aucun match en ligne n'a été
	# joué : afficher « 1000 points » à quelqu'un qui n'a jamais joué serait un
	# chiffre inventé.
	_standing = Label.new()
	_standing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(_standing, MenuTheme.T_APPUI)
	body.add_child(_standing)

func _build_code_block(body: VBoxContainer) -> void:
	body.add_child(_make_section("CODE DE RÉCUPÉRATION — À NOTER", MenuTheme.GOLD))

	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", MenuTheme.GAP_S)
	body.add_child(code_row)

	_code = Label.new()
	Charte.enseigne(_code, MenuTheme.T_TITRE)
	_code.add_theme_color_override("font_color", MenuTheme.GOLD)
	code_row.add_child(_code)

	_btn_copy = _make_button(COPY_LABEL, MenuTheme.GOLD)
	_btn_copy.pressed.connect(_copy_recovery_code)
	code_row.add_child(_btn_copy)

	# La confirmation vit sur sa propre ligne plutôt que dans le libellé du
	# bouton ou dans le code : ni l'un ni l'autre ne doit changer sous les yeux
	# du joueur au moment précis où il recopie douze caractères à la main.
	_copy_feedback = Label.new()
	_copy_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(_copy_feedback, MenuTheme.T_MENTION)
	_copy_feedback.add_theme_color_override("font_color", MenuTheme.GOLD)
	body.add_child(_copy_feedback)

	_hint = Label.new()
	_hint.text = "Sans ce code, un changement d'ordinateur repart d'un profil vierge."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(_hint, MenuTheme.T_MENTION)
	_hint.add_theme_color_override("font_color", MenuTheme.DIM)
	body.add_child(_hint)

func _build_link_block(body: VBoxContainer) -> void:
	body.add_child(_make_section("REPRENDRE UN PROFIL SUR CETTE MACHINE", MenuTheme.P1))

	var link_row := HBoxContainer.new()
	link_row.alignment = BoxContainer.ALIGNMENT_CENTER
	link_row.add_theme_constant_override("separation", MenuTheme.GAP_S)
	body.add_child(link_row)

	_link_input = LineEdit.new()
	_link_input.custom_minimum_size = Vector2(300, 40)
	_link_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_link_input.placeholder_text = "CODE À %d CARACTÈRES" % RecoveryCode.LENGTH
	_link_input.add_theme_stylebox_override("normal", MenuWidgets.make_line_edit_style(false))
	_link_input.add_theme_stylebox_override("focus", MenuWidgets.make_line_edit_style(true))
	Charte.appareil(_link_input, MenuTheme.T_COURANT)
	_link_input.text_changed.connect(_on_link_text_changed)
	link_row.add_child(_link_input)

	_btn_link = _make_button(LINK_LABEL, MenuTheme.P1)
	_btn_link.pressed.connect(_request_link)
	link_row.add_child(_btn_link)

	_link_progress = Label.new()
	_link_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(_link_progress, MenuTheme.T_MENTION)
	_link_progress.add_theme_color_override("font_color", MenuTheme.DIM)
	body.add_child(_link_progress)

	_link_feedback = Label.new()
	_link_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_link_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(_link_feedback, MenuTheme.T_MENTION)
	_link_feedback.add_theme_color_override("font_color", MenuTheme.DIM)
	body.add_child(_link_feedback)

func _make_section(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(label, MenuTheme.T_COURANT, Charte.POIDS_APPUI)
	label.add_theme_color_override("font_color", color)
	return label

func _make_button(text: String, accent: Color) -> Button:
	return MenuWidgets.make_button(text, accent, false, MenuTheme.T_COURANT, Vector2(150, 40))

# ---------------------------------------------------------------------------
# AFFICHAGE
# ---------------------------------------------------------------------------

## Idempotent, et sans effet sur un écran jamais construit : le hub appelle
## `refresh()` avant le premier affichage comme après.
func refresh() -> void:
	if _status == null:
		return

	var state := _state()
	var configured := state != RANKED.State.UNCONFIGURED

	_status.text = _status_text()
	_status.add_theme_color_override("font_color",
		MenuTheme.WARN if is_alarming() else MenuTheme.DIM)

	var explanation := _explanation_text()
	_explain.text = explanation
	_explain.visible = not explanation.is_empty()

	var nick := _nickname_text()
	_nickname.text = nick
	# Pendant la saisie, ni le pseudo ni le bouton : la rangée les remplace, et
	# les laisser afficherait deux fois la même chose dont une périmée.
	var en_saisie := _rename_row != null and _rename_row.visible
	_nickname.visible = not nick.is_empty() and not en_saisie
	_btn_rename.visible = can_rename() and not en_saisie

	var standing := _standing_text()
	_standing.text = standing
	_standing.visible = not standing.is_empty()
	_standing.add_theme_color_override("font_color",
		MenuTheme.P1 if _is_ranked() else MenuTheme.DIM)

	_refresh_code()

	# Le rattachement reste offert même après un échec : c'est exactement la
	# situation du joueur qui débarque sur une machine neuve et dont
	# l'identification n'a rien trouvé. Il n'est fermé que faute de classement du
	# tout, où `RankedIdentity.link()` refuserait de toute façon.
	_link_input.editable = configured
	_btn_link.disabled = not configured
	_hint.visible = configured
	_refresh_link_progress()

func _refresh_code() -> void:
	var code := _recovery_code()
	# Le code est montré dès qu'il est connu, y compris en état d'échec : c'est
	# la seule chose que le joueur doive conserver, et un hoquet de réseau n'est
	# pas une raison de la lui retirer de sous les yeux. À l'inverse, aucun état
	# n'affiche un code qui n'existe pas — le gabarit de tirets tient la place et
	# le bouton reste fermé.
	_code.text = RecoveryCode.format(code) if not code.is_empty() else _placeholder()
	_btn_copy.disabled = code.is_empty()

	# La confirmation ne survit qu'au code dont elle parle. Après un
	# rattachement, le profil a changé : elle disparaît d'elle-même.
	_copy_feedback.text = COPY_DONE if not code.is_empty() and _copied == code else ""

func _refresh_link_progress() -> void:
	if _btn_link.disabled:
		_link_progress.text = "Indisponible : cette installation n'a pas de classement."
		return
	# Le décompte se lit pendant la frappe : c'est ce qui rend le refus d'un code
	# trop court prévisible plutôt que subi. Le bouton, lui, reste atteignable —
	# le désactiver le ferait disparaître du parcours du curseur au beau milieu
	# d'une saisie, et un bouton qui s'évapore passe pour un défaut.
	var typed := RecoveryCode.sanitize(_link_input.text).length()
	if typed == RecoveryCode.LENGTH:
		_link_progress.text = "Code complet — %s" % LINK_LABEL.to_lower()
		return
	_link_progress.text = "%d caractère%s sur %d" % [
		typed, "s" if typed > 1 else "", RecoveryCode.LENGTH]

func _status_text() -> String:
	var identity := _identity()
	if identity == null:
		# Pas d'autoload : même situation qu'une installation sans configuration,
		# et il n'y a aucune raison de l'annoncer autrement.
		return "Classement : non configuré"
	var detail := String(identity.last_error)
	# `last_error` n'est montré que sur un échec d'identification : un
	# rattachement refusé le renseigne aussi, et l'afficher là ferait passer un
	# profil parfaitement valide pour un profil en panne.
	if is_alarming() and not detail.is_empty():
		return detail
	return String(identity.state_label())

func _explanation_text() -> String:
	match _state():
		RANKED.State.UNCONFIGURED:
			return "Cette installation n'a pas de classement en ligne. " \
				+ "Le jeu se joue normalement : il n'y a simplement aucun profil à suivre."
		RANKED.State.INITIALIZING:
			return "Identification en cours auprès du serveur. Rien n'attend : le menu et les matchs restent disponibles."
		RANKED.State.FAILED:
			return "Le classement est hors d'atteinte pour le moment. Les matchs restent jouables ; ils ne seront simplement pas comptés."
		_:
			return ""

func _nickname_text() -> String:
	var identity := _identity()
	if identity == null or _state() != RANKED.State.READY:
		return ""
	return String(identity.nickname)

func _standing_text() -> String:
	var identity := _identity()
	return String(identity.standing_label()) if identity != null else ""

func _is_ranked() -> bool:
	var identity := _identity()
	return identity != null and bool(identity.is_ranked)

## Gabarit occupant exactement la place d'un vrai code, séparateurs compris : la
## ligne ne se déplace pas au moment où le code arrive. Dérivé de `RecoveryCode`
## pour qu'un changement de longueur ne laisse pas un gabarit qui ment.
func _placeholder() -> String:
	return RecoveryCode.format("—".repeat(RecoveryCode.LENGTH))

# ---------------------------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------------------------

func _copy_recovery_code() -> void:
	var code := _recovery_code()
	if code.is_empty():
		return
	# La forme groupée : c'est celle qu'on recopie ou qu'on colle dans un
	# message, et le champ d'en face la ramène tout seul à sa forme canonique.
	DisplayServer.clipboard_set(RecoveryCode.format(code))
	_copied = code
	_copy_feedback.text = COPY_DONE

## Le champ refuse à la frappe ce qu'un code ne peut pas contenir, et regroupe
## ce qu'il garde par quatre.
##
## Nettoyer après coup — accepter la saisie puis la refuser — obligerait à
## expliquer un rejet ; ici le joueur ne PEUT PAS taper une saisie invalide, et
## il n'y a rien à lui refuser. Un collage de « ABCD-EFGH-JKLM » reçu par
## message passe donc tel quel, espaces et minuscules compris.
func _on_link_text_changed(typed: String) -> void:
	var pretty := RecoveryCode.format(RecoveryCode.sanitize(typed))
	if pretty != typed:
		# Seuls les caractères significatifs à gauche du curseur survivent au
		# reformatage : c'est la seule mesure qui résiste à l'insertion des
		# tirets, un décompte en caractères bruts sauterait d'un groupe.
		var kept := RecoveryCode.sanitize(typed.substr(0, _link_input.caret_column))
		_link_input.text = pretty
		_link_input.caret_column = mini(caret_for(kept.length()), pretty.length())
	_refresh_link_progress()

## Où poser le curseur de saisie dans la forme groupée, sachant combien de
## caractères significatifs le précèdent. Séparé pour être vérifiable seul : la
## règle est arithmétique, l'erreur d'un cran ne se voit qu'à la frappe.
static func caret_for(kept: int) -> int:
	if kept <= 0:
		return 0
	return kept + (kept - 1) / RecoveryCode.GROUP

## Ouvre la saisie, préremplie du pseudo courant.
##
## Préremplir plutôt que vider : on **modifie** un pseudo, on n'en saisit pas un
## nouveau. Un champ vide obligerait à retaper ce qu'on voulait garder, et la
## plupart des renommages sont des retouches.
func _open_rename() -> void:
	_rename_input.text = _nickname_text()
	_rename_feedback.text = ""
	_rename_row.show()
	_nickname.hide()
	_btn_rename.hide()
	_rename_input.grab_focus()
	_rename_input.select_all()

func _close_rename() -> void:
	_rename_row.hide()
	_rename_feedback.text = ""
	refresh()

func _request_rename() -> void:
	var identity := _identity()
	if identity == null or not identity.has_method("rename"):
		return
	# Posé AVANT l'appel : `rename()` refuse localement un pseudo vide ou inchangé
	# et émet son verdict de façon synchrone. L'ordre inverse écraserait le refus
	# par un « en cours » qui ne finirait jamais — même piège que le rattachement.
	_rename_feedback.text = "Enregistrement…"
	_rename_feedback.add_theme_color_override("font_color", MenuTheme.DIM)
	identity.rename(_rename_input.text)

func _on_rename_completed(success: bool, message: String) -> void:
	_rename_feedback.text = message
	_rename_feedback.add_theme_color_override("font_color",
		MenuTheme.GOLD if success else MenuTheme.WARN)
	if success:
		_rename_row.hide()
	refresh()

func _request_link() -> void:
	var identity := _identity()
	if identity == null:
		return
	# Posé AVANT l'appel : `link()` refuse localement un code trop court et émet
	# son verdict dans la foulée, de façon synchrone. L'ordre inverse écraserait
	# le refus par un « en cours » qui ne finirait jamais.
	_link_feedback.text = LINK_PENDING
	_link_feedback.add_theme_color_override("font_color", MenuTheme.DIM)
	identity.link(_link_input.text)

func _on_link_completed(success: bool, message: String) -> void:
	_link_feedback.text = message
	_link_feedback.add_theme_color_override("font_color",
		MenuTheme.GOLD if success else MenuTheme.WARN)
	if success:
		_link_input.text = ""
		# Le profil adopté n'est plus celui qu'on avait copié.
		_copied = ""
	refresh()

# ---------------------------------------------------------------------------
# ACCÈS À L'IDENTITÉ
# ---------------------------------------------------------------------------
#
# L'écran doit se construire seul, sans hub et sans autoload — contrat de
# `HubScreen`, et c'est ce qui le rend exerçable en test. Sans identité
# accessible il affiche « non configuré », ce qui reste juste.

func _identity() -> Node:
	if identity_override != null and is_instance_valid(identity_override):
		return identity_override
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/RankedIdentity")

func _state() -> int:
	var identity := _identity()
	return int(identity.state) if identity != null else RANKED.State.UNCONFIGURED

func _recovery_code() -> String:
	var identity := _identity()
	return String(identity.recovery_code) if identity != null else ""

## Le hub construit parfois l'écran avant de l'accrocher à l'arbre ; l'autoload
## n'est joignable qu'une fois dedans. Sans ce second essai, un écran bâti trop
## tôt resterait muet — et le seul symptôme serait un profil qui ne s'affiche
## jamais, ce qui ressemble à s'y méprendre à un serveur qui ne répond pas.
func _ready() -> void:
	_bind_identity()
	refresh()

func _bind_identity() -> void:
	var identity := _identity()
	if identity == _bound:
		return
	_unbind()
	if identity == null:
		return
	identity.state_changed.connect(_on_state_changed)
	identity.standing_changed.connect(refresh)
	# `link_completed` est écouté à part, et pas seulement pour son message :
	# un rattachement réussi appelle `_set_state(READY)` sur un état DÉJÀ prêt,
	# qui n'émet donc aucun `state_changed`. S'en remettre à ce seul signal
	# laisserait l'ancien pseudo et l'ancien code à l'écran, alors même que le
	# profil a changé.
	identity.link_completed.connect(_on_link_completed)
	# Même raison que ci-dessus : un renommage réussi ne change pas l'état, donc
	# n'émet aucun `state_changed` — l'écran garderait l'ancien pseudo.
	if identity.has_signal("rename_completed"):
		identity.rename_completed.connect(_on_rename_completed)
	_bound = identity

func _unbind() -> void:
	if _bound == null or not is_instance_valid(_bound):
		_bound = null
		return
	_bound.state_changed.disconnect(_on_state_changed)
	_bound.standing_changed.disconnect(refresh)
	_bound.link_completed.disconnect(_on_link_completed)
	if _bound.has_signal("rename_completed") \
			and _bound.rename_completed.is_connected(_on_rename_completed):
		_bound.rename_completed.disconnect(_on_rename_completed)
	_bound = null

func _on_state_changed(_state: int) -> void:
	refresh()
