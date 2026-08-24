class_name ScreenHistory
extends HubScreen

## Historique des matchs — Phase 5, étape 5.
##
## Tout le travail de fond était déjà fait : `match_history_view.gd` lit le
## journal, met en forme, agrège, et sait dire ce qu'il a écarté. Cet écran ne
## fait que montrer, et c'est délibérément tout ce qu'il fait — aucune règle de
## lecture n'est réimplémentée ici, sous peine d'en avoir deux qui divergent.
##
## Deux partis pris qui ne se devinent pas :
##
## **Les lignes sont un pool fixe, remplies par `refresh()`.** Reconstruire
## l'arbre à chaque affichage ferait perdre le focus du curseur au moment précis
## où l'on revient sur l'écran, et le hub rappelle `refresh()` à chaque entrée.
##
## **Ce qui a été écarté est dit, pas escamoté.** Un journal peut contenir des
## enregistrements illisibles, ou écrits par une version plus récente du jeu —
## typiquement après un retour en arrière. Les taire donnerait un historique
## silencieusement incomplet, ce qui est la seule chose qu'un historique ne doit
## jamais être.

## Nombre de matchs affichés. Au-delà, la page devient un mur qu'on ne lit plus ;
## le journal, lui, garde tout.
const SHOWN := 12

var _summary: Label
var _detail: Label
var _empty: Label
var _warning: Label
var _rows: Array[Dictionary] = []

func screen_title() -> String:
	return "Historique"

func build(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation", MenuTheme.GAP_S)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", MenuTheme.T_APPUI)
	_summary.add_theme_color_override("font_color", MenuTheme.GOLD)
	body.add_child(_summary)

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	_detail.add_theme_color_override("font_color", MenuTheme.DIM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail)

	var filet := ColorRect.new()
	filet.color = MenuTheme.LINE
	filet.custom_minimum_size = Vector2(0, 1)
	body.add_child(filet)

	_empty = Label.new()
	_empty.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	_empty.add_theme_color_override("font_color", MenuTheme.DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_empty)

	for i in SHOWN:
		_rows.append(_build_row(body, i))

	_warning = Label.new()
	_warning.add_theme_font_size_override("font_size", MenuTheme.T_MENTION)
	_warning.add_theme_color_override("font_color", MenuTheme.WARN)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_warning)

	refresh()

## Une ligne de match. L'issue porte la couleur : c'est ce qu'on cherche en
## parcourant la liste, le reste se lit une fois qu'on s'est arrêté dessus.
func _build_row(body: VBoxContainer, index: int) -> Dictionary:
	var ligne := HBoxContainer.new()
	ligne.name = "Ligne%d" % index
	ligne.add_theme_constant_override("separation", MenuTheme.GAP_S)
	body.add_child(ligne)

	var date := Label.new()
	date.custom_minimum_size = Vector2(150, 0)
	date.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	date.add_theme_color_override("font_color", MenuTheme.DIM)
	ligne.add_child(date)

	var issue := Label.new()
	issue.custom_minimum_size = Vector2(110, 0)
	issue.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	ligne.add_child(issue)

	var duree := Label.new()
	duree.custom_minimum_size = Vector2(70, 0)
	duree.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	duree.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ligne.add_child(duree)

	var reste := Label.new()
	reste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reste.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	reste.add_theme_color_override("font_color", MenuTheme.DIM)
	ligne.add_child(reste)

	return {"ligne": ligne, "date": date, "issue": issue, "duree": duree, "reste": reste}

func refresh() -> void:
	if _summary == null:
		return
	var rapport := MatchHistoryView.recent_report(SHOWN)
	var lignes: Array = rapport.get("lignes", [])
	var bilan := MatchHistoryView.session_summary()

	_summary.text = _summary_text(bilan)
	_detail.text = _detail_text(bilan)

	# Un journal vide au premier lancement n'est pas une anomalie : on le dit
	# comme tel, sans message d'erreur ni tableau vide sans explication.
	_empty.visible = lignes.is_empty()
	_empty.text = "Aucun match archivé pour l'instant. Jouez une partie : elle " \
		+ "s'inscrira ici, en ligne comme en écran partagé."

	for i in _rows.size():
		var r: Dictionary = _rows[i]
		# Pas de local nommé `visible` : ce serait masquer le membre de `Control`,
		# que GDScript refuse.
		var montree := i < lignes.size()
		r["ligne"].visible = montree
		if not montree:
			continue
		_fill_row(r, lignes[i])

	_warning.text = _warning_text(rapport)
	_warning.visible = not _warning.text.is_empty()

func _fill_row(r: Dictionary, entry: Variant) -> void:
	var l: Dictionary = entry if entry is Dictionary else {}
	r["date"].text = String(l.get("date_texte", "—"))
	r["issue"].text = String(l.get("issue_texte", "—"))
	r["issue"].add_theme_color_override("font_color", _outcome_color(l))
	r["duree"].text = String(l.get("duree_texte", "—"))

	var morceaux: Array[String] = []
	var mode := String(l.get("mode_texte", ""))
	if not mode.is_empty():
		morceaux.append(mode)
	var carte := String(l.get("carte", ""))
	if not carte.is_empty():
		morceaux.append(carte)
	# L'arme n'est nommée que si l'on sait de qui elle est : en écran partagé les
	# deux joueurs sont là, et « pompe » ne dirait pas lequel l'a prise.
	var arme := String(l.get("arme_moi", ""))
	if not arme.is_empty():
		morceaux.append(arme)
	if l.get("forfait") is bool and bool(l["forfait"]):
		morceaux.append("forfait")
	r["reste"].text = " · ".join(morceaux)

func _outcome_color(l: Dictionary) -> Color:
	match int(l.get("issue", MatchHistoryView.Outcome.DRAW)):
		MatchHistoryView.Outcome.WIN: return MenuTheme.P1
		MatchHistoryView.Outcome.LOSS: return MenuTheme.P2
		MatchHistoryView.Outcome.NO_SIDE: return MenuTheme.GOLD
		_: return MenuTheme.DIM

## Le bilan de la soirée en cours, pas celui de toute la vie du journal : c'est
## la question qu'on se pose en sortant d'un match.
func _summary_text(bilan: Dictionary) -> String:
	var matchs := int(bilan.get("matchs", 0))
	if matchs == 0:
		return "Aucun match ce soir"
	var texte := "Ce soir : %d match%s" % [matchs, "s" if matchs > 1 else ""]
	var perso := String(bilan.get("bilan_texte", ""))
	if not perso.is_empty():
		texte += " · " + perso
	var partage := String(bilan.get("bilan_partage_texte", ""))
	if not partage.is_empty():
		texte += " · " + partage
	return texte

func _detail_text(bilan: Dictionary) -> String:
	if int(bilan.get("matchs", 0)) == 0:
		return ""
	var morceaux: Array[String] = []
	var duree := String(bilan.get("duree_totale_texte", ""))
	if not duree.is_empty():
		morceaux.append("temps de jeu " + duree)
	var arme := String(bilan.get("arme_favorite", ""))
	if not arme.is_empty():
		morceaux.append("arme favorite %s (%d)" % [arme,
			int(bilan.get("arme_favorite_matchs", 0))])
	var forfaits := int(bilan.get("forfaits", 0))
	if forfaits > 0:
		morceaux.append("%d forfait%s" % [forfaits, "s" if forfaits > 1 else ""])
	return " · ".join(morceaux)

## Ce que la lecture a écarté, dit franchement. Un historique qui saute des
## lignes sans le dire vaut moins qu'un historique absent : on croit le lire en
## entier.
func _warning_text(rapport: Dictionary) -> String:
	var morceaux: Array[String] = []
	var trop_recents := int(rapport.get("trop_recents", 0))
	if trop_recents > 0:
		morceaux.append("%d match%s écrit%s par une version plus récente du jeu"
			% [trop_recents, "s" if trop_recents > 1 else "",
				"s" if trop_recents > 1 else ""])
	var ignores := int(rapport.get("ignores", 0))
	if ignores > 0:
		morceaux.append("%d enregistrement%s illisible%s"
			% [ignores, "s" if ignores > 1 else "", "s" if ignores > 1 else ""])
	if morceaux.is_empty():
		return ""
	return "Non affiché%s : %s." % ["s" if morceaux.size() > 1 else "",
		", ".join(morceaux)]
