class_name ScreenUpdate
extends HubScreen

## Écran « Mise à jour » du hub — Phase 9, étape 1.
##
## ## Ce que l'écran ne décide pas
##
## Rien. Il ne sait pas comparer deux versions, ne connaît pas la différence entre
## un correctif et un remplacement complet, et n'a aucune énumération d'états
## recopiée. Il demande à `UpdateManager` un titre, un détail et le nom de
## l'action à proposer ; il affiche les trois et transmet l'appui.
##
## Ce partage n'est pas de l'esthétique d'architecture : un `match` sur les états
## recopié dans l'interface cesse d'être exhaustif à la première évolution, et il
## le fait en silence — l'écran affiche alors le libellé de l'état précédent, ce
## qui est exactement le genre de défaut que ce dépôt paie trois manches à
## trouver.
##
## ## Pourquoi aucun bouton grisé
##
## Quand il n'y a rien à proposer — vérification en cours, téléchargement en
## cours — le bouton **disparaît** au lieu d'être grisé. Un bouton grisé oblige le
## joueur à deviner ce qu'il ferait s'il était actif ; une phrase à sa place le
## lui dit.
##
## ## Le refus poli tient dans une ligne de texte
##
## Quand la version publiée n'a pas le même protocole, l'écran écrit ce qui ne
## marchera plus — trouver un adversaire — et rien de plus. Aucun menu n'est
## verrouillé, aucune fenêtre modale n'attend un clic, le jeu ne se ferme pas.
## C'est une décision d'Adrien (2026-08-24) : ce qui a cessé de fonctionner a
## cessé tout seul, et une gêne annoncée vaut mieux qu'une panne organisée.

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")
const MenuWidgets := preload("res://menu_widgets.gd")

const TITRE := "Mise à jour"

## Injectable pour les tests : sans doublure, l'écran prend l'autoload.
var source: Node = null

var _version: Label = null
var _titre: Label = null
var _detail: Label = null
var _notes: Label = null
var _avis: Label = null
var _barre: ProgressBar = null
var _bouton: Button = null
var _empeche: Label = null

func screen_title() -> String:
	return TITRE

func build(body: VBoxContainer) -> void:
	if body == null or _titre != null:
		return
	if source == null:
		source = get_node_or_null("/root/UpdateManager")

	_version = _ligne(body, MenuTheme.T_COURANT, MenuTheme.DIM)
	_titre = _ligne(body, MenuTheme.T_APPUI, MenuTheme.P1)
	_detail = _ligne(body, MenuTheme.T_COURANT, MenuTheme.DIM)
	_notes = _ligne(body, MenuTheme.T_COURANT, MenuTheme.LUMIERE)

	_barre = ProgressBar.new()
	_barre.name = "Progression"
	_barre.custom_minimum_size = Vector2(0, 10)
	_barre.show_percentage = false
	_barre.max_value = 1.0
	_barre.visible = false
	body.add_child(_barre)

	# L'avis sur le jeu en ligne et l'incident de correctif partagent une ligne
	# d'alerte : ce sont les deux seules choses que le joueur doit lire même s'il
	# n'a rien demandé.
	_avis = _ligne(body, MenuTheme.T_COURANT, MenuTheme.WARN)
	_empeche = _ligne(body, MenuTheme.T_MENTION, MenuTheme.WARN)

	_bouton = _build_bouton()
	body.add_child(_bouton)

	if source != null:
		if source.has_signal("etat_change"):
			source.etat_change.connect(func(_e: int) -> void: refresh())
		if source.has_signal("progression"):
			source.progression.connect(_on_progression)
	refresh()

func _ligne(body: VBoxContainer, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(l, taille)
	l.add_theme_color_override("font_color", couleur)
	l.visible = false
	body.add_child(l)
	return l

func _build_bouton() -> Button:
	var btn := MenuWidgets.make_button("Action", MenuTheme.P1, false, MenuTheme.T_COURANT, Vector2(260, 44))
	btn.name = "Action"
	btn.pressed.connect(_on_appui)
	return btn

func focus_seed() -> Control:
	return _bouton if _bouton != null and _bouton.visible else null

# ---------------------------------------------------------------------------

## Idempotent, y compris avant toute construction et sans gestionnaire : l'écran
## peut être rafraîchi par le hub avant d'avoir jamais été montré.
func refresh() -> void:
	if _titre == null:
		return
	if source == null:
		_poser(_titre, "Mise à jour indisponible dans ce build.")
		_bouton.visible = false
		return

	var r: Dictionary = source.resume()
	_poser(_version, _texte_version())
	_poser(_titre, str(r.get("titre", "")))
	_poser(_detail, str(r.get("detail", "")))
	_poser(_notes, str(r.get("notes", "")))

	var avis := str(r.get("en_ligne", ""))
	var incident := str(r.get("incident", ""))
	_poser(_avis, avis)
	_poser(_empeche, incident)

	_barre.visible = bool(r.get("telecharge", false))

	var action := str(source.action_suivante())
	# Une action qui ne pourra pas aboutir n'est pas proposée : on dit pourquoi à
	# la place. Le cas qui compte est macOS lançant le jeu depuis un emplacement
	# temporaire en lecture seule — tout marcherait jusqu'au dernier geste.
	if action == "telecharger" or action == "installer":
		var diag: Dictionary = source.peut_installer()
		if not bool(diag.get("ok", false)):
			_poser(_empeche, str(diag.get("raison", "")))
			_bouton.visible = false
			return
	_bouton.text = str(source.libelle_action())
	_bouton.visible = _bouton.text != ""

func _texte_version() -> String:
	var qui_tourne := str(source.version_installee())
	var socle := str(source.version_socle())
	if qui_tourne == socle:
		return "Vous jouez en %s." % qui_tourne
	# La version affichée est celle du code qui s'exécute, jamais celle du
	# fichier installé : sans ça, un rapport de bug désigne la mauvaise version.
	return "Vous jouez en %s (installé : %s, plus un correctif)." % [qui_tourne, socle]

static func _poser(l: Label, texte: String) -> void:
	if l == null:
		return
	l.text = texte
	l.visible = texte != ""

func _on_appui() -> void:
	if source == null:
		return
	# Le bouton disparaît le temps de l'action : une deuxième pression pendant un
	# téléchargement relancerait la même requête sur le même fichier.
	_bouton.visible = false
	source.declencher()

func _on_progression(recu: int, total: int) -> void:
	if _barre == null:
		return
	_barre.visible = true
	if total > 0:
		_barre.value = clampf(float(recu) / float(total), 0.0, 1.0)
		_poser(_detail, "%d %%" % int(_barre.value * 100.0))
	else:
		# Un serveur qui n'annonce pas la taille existe. Montrer 0 % pendant une
		# minute ferait croire à un blocage : on montre les octets reçus.
		_poser(_detail, "%.1f Mo reçus" % (float(recu) / 1048576.0))
