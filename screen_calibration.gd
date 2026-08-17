class_name ScreenCalibration
extends HubScreen

## Écran « Calibration » : amener chaque joueur au même point de perception.
##
## ## Pourquoi cet écran existe
##
## Dans un duel dont l'unique canal d'information est la lumière, un écran mal
## réglé — ou trop bien réglé — est un avantage compétitif. Celui qui pousse la
## luminosité de son moniteur distingue une silhouette que l'autre ne voit pas.
## Celui dont l'écran écrase les noirs joue à un jeu où la moitié de
## l'information n'existe pas, et croira que c'est le jeu qui est aveugle. Ce
## n'est donc pas une question de confort, c'est la même question d'honnêteté
## que les planchers d'`effect_policy.gd`, posée à l'autre bout de la chaîne :
## là-bas on décide de ce que le jeu affiche, ici de ce que l'écran en restitue.
##
## ## Pourquoi un curseur nu ne convient pas
##
## Un curseur nu demande au joueur un chiffre qu'il n'a aucun moyen de juger, et
## l'issue est toujours la même : chacun le pousse. Il faut une **cible
## perceptive** — quelque chose à distinguer tout juste. Mais une cible unique
## ne suffirait pas ici : « montez jusqu'à voir ceci » ne pose qu'un plancher, et
## rien n'empêche d'aller au-delà. Or c'est précisément au-delà que se trouve
## l'avantage qu'on veut refuser.
##
## ## La cible retenue : une échelle de silhouettes, et DEUX marques
##
## L'aperçu répète la même forme — un joueur vu de dessus, comme en match — à des
## luminances décroissantes, chacune un cran d'échelle. Deux crans sont marqués :
##
##   • le **repère** doit tout juste apparaître. C'est la trace la plus faible que
##     le jeu veuille montrer : un adversaire effleuré par la rétrodiffusion d'un
##     mur, à la frange d'un faisceau.
##   • la **limite**, le cran juste en dessous, doit rester invisible. C'est ce
##     que le jeu cache délibérément : quelqu'un tapi hors du faisceau.
##
## Le réglage juste est ainsi encadré des deux côtés, et l'écart entre les deux
## marques est d'un seul cran d'échelle — la fenêtre est étroite parce que la
## décision qu'elle protège l'est aussi. Trop bas, le joueur perd une information
## que le jeu lui destine ; trop haut, il en gagne une que le jeu refuse aux deux.
## Les deux dérives se lisent à l'œil, sur la même image, sans qu'aucun chiffre
## n'ait à être compris.
##
## Pourquoi une silhouette plutôt qu'une pastille grise : ce qu'un joueur doit
## reconnaître en match est une **forme**, pas une tache. Reconnaître une forme
## demande plus de contraste que détecter une plage uniforme ; calibrer sur la
## tache réglerait donc le jeu trop bas, et le joueur découvrirait en match qu'il
## ne reconnaît rien de ce qu'il avait « vu » ici.
##
## Pourquoi un gris neutre plutôt qu'une teinte de torche : la mesure ne doit
## dépendre que de la réponse de l'écran dans les noirs — la seule chose qui
## diffère réellement d'un moniteur à l'autre — et non de sa balance des
## couleurs, qui ferait varier le résultat pour une raison sans rapport.
##
## ## Ce que cet écran n'est pas
##
## Ce n'est pas une mesure anti-triche, et pour la même raison qu'`EffectPolicy` :
## personne n'empêchera un joueur de monter la luminosité de son moniteur, et le
## jeu ne voit rien de ce qui se passe hors de sa fenêtre. La fenêtre honnête est
## donc **montrée et nommée, jamais imposée** — c'est aussi pourquoi la valeur
## n'est pas écrêtée à cette fenêtre. Refuser un réglage que l'œil réclame ne le
## ferait pas disparaître : il migrerait vers le bouton du moniteur, là où le jeu
## n'en saura jamais rien. Un réglage hors fenêtre reste dans le jeu, visible,
## annoncé au joueur et signalé dans la charge utile (`dans_la_fenetre`).

# ---------------------------------------------------------------------------
# CE QUI SORT DE L'ÉCRAN
# ---------------------------------------------------------------------------
#
# L'écran ne persiste rien lui-même : le contrat de `HubScreen` lui interdit de
# connaître autre chose que son propre corps, et `settings_manager.gd` n'a pas
# encore de section pour ce réglage. La valeur retenue sort donc par
# `action_requested`, et quelqu'un branchera la persistance derrière.

## Nom d'action émis. Charge utile : un `Dictionary` de trois clés —
##
##   • `valeur` (float, 0 → 1) : le réglage lui-même, déjà borné et aligné sur un
##     cran. C'est la seule valeur à retenir ; tout le reste s'en déduit.
##   • `pourcent` (int, 0 → 100) : la même chose telle qu'elle est affichée. Elle
##     est jointe pour qu'un journal ou un rapport de match n'ait pas à refaire la
##     conversion — et donc à la refaire autrement.
##   • `dans_la_fenetre` (bool) : le réglage tombe-t-il dans la fenêtre honnête.
##     Ce n'est pas un refus, c'est un constat : le jeu ne peut pas vérifier un
##     moniteur, il peut au moins savoir que le joueur a été prévenu.
##
## Émise à **chaque** changement, jamais sur une validation séparée : un joueur
## qui règle puis ressort par le retour ne doit pas perdre son réglage, et un
## écran navigué à la manette n'a pas le droit de le lui demander dans une
## fenêtre modale. Celui qui branchera la persistance écrira dans une section
## `calibration` de `user://settings.cfg`, clé `luminosite`, en relisant
## `valeur` — et repassera cette valeur à `adopt_level()` avant l'affichage.
const ACTION := "calibration_luminosite"

# ---------------------------------------------------------------------------
# LA CIBLE
# ---------------------------------------------------------------------------

## Luminances de l'échelle, du plus clair au plus sombre, en fraction du blanc et
## mesurées **au-dessus** du noir du champ. Progression géométrique de raison
## ~2,3 : à l'œil un cran d'échelle est un doublement, jamais un pas constant.
const LADDER: Array[float] = [0.386, 0.170, 0.075, 0.033, 0.0145]

## Le cran qui doit tout juste apparaître.
const INDEX_REVEAL := 2
## Le cran qui doit rester invisible, immédiatement sous le repère.
const INDEX_HIDE := 3

## Contraste au-dessus du noir en deçà duquel une forme cesse d'être
## reconnaissable, dans une pièce sombre et à distance de jeu.
##
## Ce n'est pas une constante physique : c'est LE point de perception commun que
## cet écran cherche à faire partager. Les deux crans marqués l'encadrent — l'un
## juste au-dessus, l'autre juste en dessous — et c'est de cet encadrement, et
## non du chiffre lui-même, que la cible tire sa justesse.
const THRESHOLD := 0.05

# ---------------------------------------------------------------------------
# LA COURSE
# ---------------------------------------------------------------------------

const LEVEL_MIN := 0.0
const LEVEL_MAX := 1.0
## Mi-course : l'écran de référence, celui qui n'appelle aucune correction. Un
## joueur dont le moniteur est déjà juste ne touche à rien et a raison.
const LEVEL_DEFAULT := 0.5

## Un cran de réglage : vingt-et-un crans sur la course. Assez fin pour se poser
## dans la fenêtre — cinq crans y tiennent — assez gros pour qu'un bout à l'autre
## reste une poignée d'appuis à la manette. Même arbitrage que le pas de 5 % des
## curseurs d'effets.
const NOTCH := 0.05

## Amplitude de correction, exprimée en exposant : la course va de γ = 1,8 (écran
## qui écrase les noirs, donc à relever) à γ = 1/1,8 (écran qui les relève déjà,
## donc à rabaisser), l'interpolation étant **géométrique** — deux corrections
## successives multiplient leurs exposants, c'est donc en logarithme que la
## course est droite, et mi-course vaut exactement γ = 1.
##
## C'est aussi la borne, et elle est choisie pour cela : au-delà, le réglage ne
## corrigerait plus un écran, il fabriquerait de la vision. La course entière est
## le garde-fou — il n'y a pas de plancher à l'intérieur, comme pour les effets,
## parce que l'excès est ici des DEUX côtés.
const GAMMA_SPAN := 1.8

enum Verdict { TROP_SOMBRE, JUSTE, TROP_CLAIR }

# ---------------------------------------------------------------------------
# CE QUE LE JOUEUR LIT
# ---------------------------------------------------------------------------
#
# Le texte vit à côté des valeurs qu'il explique : ailleurs, un seuil déplacé un
# jour laisserait derrière lui une phrase qui dit autre chose.

const PROTOCOLE := "Réglez dans la pièce et à la distance où vous jouerez, "\
	+ "lumières éteintes. Montez jusqu'à ce que la silhouette REPÈRE apparaisse "\
	+ "tout juste ; redescendez si la silhouette LIMITE se laisse deviner. "\
	+ "Ensuite, ne touchez plus au bouton de luminosité du moniteur : ce "\
	+ "réglage-ci n'en saurait rien."

const MARK_REVEAL := "REPÈRE\ndoit tout juste apparaître"
const MARK_HIDE := "LIMITE\ndoit rester invisible"

const BOUND_NOTICE := "Bout de course. Si votre écran en réclame encore, c'est "\
	+ "le moniteur qu'il faut reprendre : au-delà, ce réglage ne corrigerait "\
	+ "plus un écran, il fabriquerait de la vision."

const FOOTER := "Ce réglage ne change que votre écran, et le jeu n'a aucun "\
	+ "moyen de vérifier votre moniteur. Il dit dans quel jeu se joue un match "\
	+ "classé ; il ne l'impose à personne."

const LABEL_DARKER := "−  PLUS SOMBRE"
const LABEL_BRIGHTER := "PLUS CLAIR  +"
const LABEL_RESET := "REVENIR AU REPÈRE NEUTRE"

# ---------------------------------------------------------------------------
# LE MODÈLE — fonctions pures, exerçables sans écran
# ---------------------------------------------------------------------------

## Réglage ramené dans ses bornes. NAN se propage silencieusement dans un
## flottant et rendrait l'aperçu noir sans la moindre erreur : il retombe sur le
## repère neutre plutôt que de contaminer la course.
static func clamp_level(level: float) -> float:
	if is_nan(level):
		return LEVEL_DEFAULT
	return clampf(level, LEVEL_MIN, LEVEL_MAX)

## Réglage borné ET aligné sur un cran. Toute valeur qui entre dans l'écran passe
## par là : un réglage entre deux crans ne serait pas reproductible d'une session
## à l'autre, et deux joueurs comparant leurs chiffres compareraient du bruit.
static func snap_level(level: float) -> float:
	return clampf(snappedf(clamp_level(level), NOTCH), LEVEL_MIN, LEVEL_MAX)

## Exposant appliqué par le réglage. Décroissant : plus le réglage monte, plus
## les noirs se relèvent.
static func gamma_for(level: float) -> float:
	return pow(GAMMA_SPAN, 1.0 - 2.0 * clamp_level(level))

## Réglage auquel la course rend cet exposant. Réciproque exacte de
## `gamma_for()` : c'est elle qui donne les bornes de la fenêtre sans avoir à
## balayer la course.
static func level_for_gamma(gamma: float) -> float:
	if gamma <= 0.0:
		return LEVEL_MAX
	return clamp_level((1.0 - log(gamma) / log(GAMMA_SPAN)) / 2.0)

## Contraste réellement perçu, au-dessus du noir du champ, pour une luminance
## d'échelle et un réglage donnés.
static func perceived(luminance: float, level: float) -> float:
	return pow(clampf(luminance, 0.0, 1.0), gamma_for(level))

## Ce cran se distingue-t-il du noir ?
static func is_patch_visible(luminance: float, level: float) -> bool:
	return perceived(luminance, level) >= THRESHOLD

## Nombre de crans visibles. Croît avec le réglage — c'est la propriété qui rend
## l'aperçu lisible : monter le réglage ne peut qu'ajouter des silhouettes.
static func visible_count(level: float) -> int:
	var count := 0
	for luminance in LADDER:
		if is_patch_visible(luminance, level):
			count += 1
	return count

## Le verdict, dans l'ordre où les deux marques se contredisent : si la limite se
## voit, le repère se voit forcément aussi (il est plus clair), et c'est l'excès
## qu'il faut annoncer, pas la réussite.
static func verdict_for(level: float) -> int:
	if is_patch_visible(LADDER[INDEX_HIDE], level):
		return Verdict.TROP_CLAIR
	if not is_patch_visible(LADDER[INDEX_REVEAL], level):
		return Verdict.TROP_SOMBRE
	return Verdict.JUSTE

## Fenêtre honnête, en réglage : `x` incluse, `y` exclue. L'asymétrie n'est pas
## un oubli — c'est celle des deux marques, l'une devant apparaître (donc
## atteindre le seuil), l'autre devant rester en deçà.
static func window() -> Vector2:
	var low := level_for_gamma(log(THRESHOLD) / log(LADDER[INDEX_REVEAL]))
	var high := level_for_gamma(log(THRESHOLD) / log(LADDER[INDEX_HIDE]))
	return Vector2(low, high)

static func level_to_percent(level: float) -> int:
	return int(round(clamp_level(level) * 100.0))

static func percent_to_level(percent: int) -> float:
	return clamp_level(float(percent) / 100.0)

## Noir du champ : le noir du jeu, opaque.
##
## Ce n'est pas une couleur d'interface inventée à côté de la palette, c'est la
## RÉFÉRENCE de la mesure — et `MenuTheme.BACKDROP` ne peut pas jouer ce rôle :
## sa propre définition dit qu'il est volontairement moins noir que le jeu, pour
## qu'on sente un monde derrière. Mesurer sur ce fond-là décalerait chaque joueur
## du même côté, invisiblement : un noir relevé écrase le contraste des crans les
## plus bas, chacun compenserait en montant, et l'écran produirait exactement
## l'excès qu'il existe pour éviter. Le champ est donc le noir du match.
##
## Opaque, pour la même raison : un champ translucide laisserait ce qu'il y a
## derrière décider du résultat de la mesure.
static func field_black() -> Color:
	return Color(0.0, 0.0, 0.0, 1.0)

## Couleur d'un cran : le noir du champ, RELEVÉ du contraste perçu.
##
## Relevé, et non remplacé : un cran invisible doit valoir exactement le fond. En
## posant la couleur perçue telle quelle, le cran le plus bas se retrouverait plus
## sombre que le champ, donc parfaitement visible — en négatif. La lumière
## s'ajoute, la mesure aussi.
static func patch_color(luminance: float, level: float) -> Color:
	var lift := perceived(luminance, level)
	var back := field_black()
	return Color(minf(back.r + lift, 1.0), minf(back.g + lift, 1.0),
		minf(back.b + lift, 1.0), 1.0)

## Les cinq crans du réglage courant, dans l'ordre de l'échelle.
static func patch_colors(level: float) -> PackedColorArray:
	var out := PackedColorArray()
	for luminance in LADDER:
		out.append(patch_color(luminance, level))
	return out

static func verdict_line(verdict: int) -> String:
	match verdict:
		Verdict.TROP_SOMBRE:
			return "Trop sombre — le repère ne se détache pas. En match, un "\
				+ "adversaire que le jeu vous montre vous échappera."
		Verdict.JUSTE:
			return "Réglage juste — vous voyez ce que le jeu montre, et rien de "\
				+ "ce qu'il cache."
		Verdict.TROP_CLAIR:
			return "Trop clair — la limite se laisse deviner. Vous verriez un "\
				+ "adversaire que le jeu n'a pas décidé de montrer."
	return ""

static func verdict_color(verdict: int) -> Color:
	return MenuTheme.GOLD if verdict == Verdict.JUSTE else MenuTheme.WARN

# ---------------------------------------------------------------------------
# ÉTAT
# ---------------------------------------------------------------------------

var _level: float = LEVEL_DEFAULT

var _field: Field
var _marks: HBoxContainer
var _gauge: HSlider
var _value_label: Label
var _verdict_label: Label
var _bound_notice: Label
var _btn_darker: Button
var _btn_brighter: Button
var _btn_reset: Button

## Vrai pendant `refresh()` : la jauge qu'on repositionne émet `value_changed`
## comme si la souris l'avait tirée. Sans ce garde-fou, un simple affichage
## annoncerait un réglage que personne n'a choisi. Même piège, même parade que
## dans `screen_effects.gd`.
var _applying: bool = false

func screen_title() -> String:
	return "Calibration"

## Le curseur se pose sur « plus sombre ».
##
## Il faut bien choisir, et les deux biais ne se valent pas : dans ce jeu, c'est
## le trop clair qui donne un avantage. Le premier geste offert est donc celui
## qui n'en donne aucun.
func focus_seed() -> Control:
	return _btn_darker

func current_level() -> float:
	return _level

func current_percent() -> int:
	return level_to_percent(_level)

func current_verdict() -> int:
	return verdict_for(_level)

## Charge utile de `action_requested`, et rien d'autre : ce que l'écran annonce
## est ce que l'écran affiche, il n'y a pas deux chemins pour le calculer.
func payload() -> Dictionary:
	return {
		"valeur": _level,
		"pourcent": current_percent(),
		"dans_la_fenetre": current_verdict() == Verdict.JUSTE,
	}

## Reprend un réglage déjà retenu, avant l'affichage.
##
## N'annonce rien : renvoyer aussitôt la valeur qu'on vient de nous donner ferait
## réécrire au disque un réglage que personne n'a touché — et, le jour où
## l'écriture aura un coût, à chaque ouverture de l'écran.
func adopt_level(level: float) -> void:
	_level = snap_level(level)
	refresh()

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	if body == null or _field != null:
		return

	var protocole := Label.new()
	protocole.name = "Protocole"
	protocole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	protocole.add_theme_font_size_override("font_size", 14)
	protocole.add_theme_color_override("font_color", MenuTheme.DIM)
	protocole.text = PROTOCOLE
	body.add_child(protocole)

	body.add_child(_build_field())
	body.add_child(_build_verdict())
	body.add_child(_build_course())
	body.add_child(_build_footer())

	refresh()

## L'aperçu vit dans son propre panneau, et rien de clair ne le borde.
##
## Ce n'est pas une préciosité : l'œil s'adapte à ce qui l'entoure, et une plage
## lumineuse posée contre le champ remonterait le seuil de perception du joueur
## pendant qu'il règle. Il calibrerait alors pour un écran qu'il ne retrouvera
## jamais en match, où tout est noir. Le seul emprunt à la palette est le filet
## qui borde le champ : deux pixels de `LINE`, assez pour que le champ se lise
## comme un cadre plutôt que comme un trou, trop peu pour peser sur l'adaptation.
func _build_field() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Champ"
	var style := StyleBoxFlat.new()
	style.bg_color = field_black()
	style.set_border_width_all(2)
	style.border_color = MenuTheme.LINE
	style.set_corner_radius_all(10)
	style.content_margin_top = MenuTheme.GAP_S
	style.content_margin_bottom = MenuTheme.GAP_XS
	style.content_margin_left = MenuTheme.GAP_S
	style.content_margin_right = MenuTheme.GAP_S
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	panel.add_child(column)

	_field = Field.new()
	_field.name = "Silhouettes"
	_field.custom_minimum_size = Vector2(0, 170)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_field)

	# Les marques sont écrites SOUS les silhouettes, y compris sous celle qui doit
	# rester invisible : savoir où regarder fait partie de la mesure. Un joueur
	# qui cherche la limite au hasard conclurait « je ne la vois pas » aussi bien
	# quand elle est là que quand elle n'y est pas.
	_marks = HBoxContainer.new()
	_marks.name = "Marques"
	_marks.add_theme_constant_override("separation", 0)
	for i in LADDER.size():
		var mark := Label.new()
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 11)
		match i:
			INDEX_REVEAL:
				mark.text = MARK_REVEAL
				mark.add_theme_color_override("font_color", MenuTheme.GOLD)
			INDEX_HIDE:
				mark.text = MARK_HIDE
				mark.add_theme_color_override("font_color", MenuTheme.WARN)
			_:
				mark.text = ""
				mark.add_theme_color_override("font_color", MenuTheme.DIM)
		_marks.add_child(mark)
	column.add_child(_marks)

	return panel

func _build_verdict() -> Control:
	_verdict_label = Label.new()
	_verdict_label.name = "Verdict"
	_verdict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_label.add_theme_font_size_override("font_size", 16)
	return _verdict_label

## La course, et la réponse à la question « que fait gauche/droite ? ».
##
## Dans ce jeu, gauche et droite DÉPLACENT LE CURSEUR : `ui.gd` intercepte
## `p*_menu_left/right` et les résout géométriquement, parce que deux joueurs
## naviguent en même temps et que le focus natif de Godot est unique. Un contrôle
## focalisé ne reçoit donc jamais ces directions, et une jauge tirée par la
## gauche et la droite serait morte à la manette.
##
## D'où cette disposition : les deux boutons de pas sont posés de part et d'autre
## de la jauge, dans le sens qu'ils appliquent. Pousser à gauche amène le curseur
## sur « plus sombre », pousser à droite sur « plus clair » — le geste et l'effet
## vont dans le même sens, et il ne reste qu'à valider. La jauge, elle, ne prend
## pas le focus : un contrôle que la manette ne peut pas régler n'a rien à faire
## sous le curseur. Elle reste tirable à la souris, où elle est le geste naturel.
func _build_course() -> Control:
	var row := HBoxContainer.new()
	row.name = "Course"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", MenuTheme.GAP_M)

	_btn_darker = _make_button("BoutonSombre", LABEL_DARKER)
	_btn_darker.pressed.connect(_on_darker)
	row.add_child(_btn_darker)

	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 2)
	row.add_child(middle)

	_gauge = HSlider.new()
	_gauge.name = "Jauge"
	_gauge.min_value = 0.0
	_gauge.max_value = 100.0
	# Le pas de la jauge est celui des boutons : si quelqu'un lui rendait un jour
	# le focus, gauche/droite tomberait exactement sur les mêmes crans.
	_gauge.step = NOTCH * 100.0
	_gauge.custom_minimum_size = Vector2(300, 24)
	_gauge.focus_mode = Control.FOCUS_NONE
	_gauge.add_theme_stylebox_override("slider", _track_style(MenuTheme.LINE))
	_gauge.add_theme_stylebox_override("grabber_area", _track_style(MenuTheme.P1))
	_gauge.add_theme_stylebox_override("grabber_area_highlight", _track_style(MenuTheme.P1))
	_gauge.value_changed.connect(_on_gauge_changed)
	middle.add_child(_gauge)

	_value_label = Label.new()
	_value_label.name = "Valeur"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 17)
	middle.add_child(_value_label)

	_btn_brighter = _make_button("BoutonClair", LABEL_BRIGHTER)
	_btn_brighter.pressed.connect(_on_brighter)
	row.add_child(_btn_brighter)

	return row

func _build_footer() -> Control:
	var column := VBoxContainer.new()
	column.name = "Pied"
	column.add_theme_constant_override("separation", MenuTheme.GAP_XS)

	_bound_notice = Label.new()
	_bound_notice.name = "BoutDeCourse"
	_bound_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bound_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bound_notice.add_theme_font_size_override("font_size", 12)
	_bound_notice.add_theme_color_override("font_color", MenuTheme.WARN)
	_bound_notice.text = BOUND_NOTICE
	column.add_child(_bound_notice)

	# Le retour au repère neutre n'est JAMAIS désactivé, pas même quand on y est
	# déjà : un bouton désactivé sort des candidats du curseur (`ui.gd`), et le
	# joueur qui a poussé son réglage n'importe où doit toujours voir de quoi
	# revenir — c'est la seule chose qu'il cherche à ce moment-là.
	var center := CenterContainer.new()
	_btn_reset = _make_button("BoutonRepere", LABEL_RESET)
	_btn_reset.pressed.connect(_on_reset)
	center.add_child(_btn_reset)
	column.add_child(center)

	var footer := Label.new()
	footer.name = "Note"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", MenuTheme.DIM)
	footer.text = FOOTER
	column.add_child(footer)

	return column

func _make_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(180, 40)
	return button

func _track_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

# ---------------------------------------------------------------------------
# AFFICHAGE
# ---------------------------------------------------------------------------

## Idempotent, et sans effet sur un écran jamais construit : le hub appelle
## `refresh()` avant le premier affichage comme après.
func refresh() -> void:
	if _field == null:
		return
	_applying = true

	_field.background = field_black()
	_field.patches = patch_colors(_level)
	_field.queue_redraw()

	_gauge.value = float(current_percent())
	_value_label.text = "%d %%" % current_percent()

	var verdict := current_verdict()
	_verdict_label.text = verdict_line(verdict)
	_verdict_label.add_theme_color_override("font_color", verdict_color(verdict))

	# Au bout de la course, les boutons restent actifs et sans effet plutôt que
	# de disparaître de sous le curseur. Ce qui change, c'est qu'on dit pourquoi.
	_bound_notice.visible = _level <= LEVEL_MIN or _level >= LEVEL_MAX

	_applying = false

# ---------------------------------------------------------------------------
# LE RÉGLAGE
# ---------------------------------------------------------------------------

## Seul chemin par lequel un choix du joueur devient une valeur retenue.
##
## Un réglage qui ne bouge pas n'annonce rien : au bout de la course, appuyer
## encore ne doit pas remplir le journal — ni le disque, le jour où quelqu'un
## branchera la persistance derrière — d'un réglage identique répété.
func _choose(level: float) -> void:
	var next := snap_level(level)
	if is_equal_approx(next, _level):
		return
	_level = next
	refresh()
	action_requested.emit(ACTION, payload())

func _on_darker() -> void:
	_choose(_level - NOTCH)

func _on_brighter() -> void:
	_choose(_level + NOTCH)

func _on_reset() -> void:
	_choose(LEVEL_DEFAULT)

func _on_gauge_changed(percent: float) -> void:
	if _applying:
		return
	_choose(percent_to_level(int(percent)))

# ---------------------------------------------------------------------------
# L'APERÇU
# ---------------------------------------------------------------------------
#
# L'aperçu est peint ici, dans l'écran, et nulle part ailleurs. Pas de
# `CanvasModulate` global, pas d'arène chargée : le réglage se juge sur une image
# fabriquée pour ça, et le monde du jeu n'a pas à être touché pour qu'un menu
# s'affiche. La simulation est exacte — la couleur d'un cran est très exactement
# celle que le rendu lui donnerait — parce qu'elle applique le même exposant.

## Le champ de mesure : une silhouette par cran, à la couleur qu'on lui donne.
##
## Il ne calcule rien de lui-même. Les couleurs lui sont posées par l'écran, ce
## qui laisse toute la logique dans des fonctions pures et exerçables sans
## fenêtre — un test headless ne dessine jamais.
class Field extends Control:
	var background: Color = Color.BLACK
	var patches: PackedColorArray = PackedColorArray()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), background)
		if patches.is_empty():
			return
		var cell := size.x / float(patches.size())
		var radius := minf(size.y * 0.30, cell * 0.28)
		for i in patches.size():
			_draw_silhouette(Vector2((float(i) + 0.5) * cell, size.y * 0.5),
				radius, patches[i])

	## Un joueur vu de dessus : le corps, et l'amorce de l'arme qui donne son
	## orientation à la forme. C'est cette forme-là qu'on reconnaît en match, pas
	## une pastille — et c'est donc elle qu'on doit apprendre à reconnaître ici.
	func _draw_silhouette(center: Vector2, radius: float, color: Color) -> void:
		draw_circle(center, radius, color)
		draw_rect(Rect2(center.x - radius * 0.16, center.y - radius * 1.5,
			radius * 0.32, radius * 0.6), color)
