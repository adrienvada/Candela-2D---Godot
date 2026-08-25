class_name MenuEngraver
extends Control

## M7 — Le code gravé par impacts. Vague M, « la vitrine ».
##
## Le code de salon à 6 caractères ne s'imprime pas : il se **frappe**. Chaque
## caractère apparaît blanc incandescent puis refroidit vers l'or, décalé de
## 70 ms, avec une secousse d'un pixel vers le bas et deux ou trois étincelles
## qui chutent et meurent au point d'impact — six balles qui gravent le code
## dans le mur.
##
## Le code de salon est l'objet social du jeu : c'est celui qu'on lit à voix
## haute à un ami. Il apparaissait sans cérémonie. Le graver en fait un petit
## événement à chaque ouverture de salon, dans le langage exact du monde —
## l'impact qui marque la matière, le métal qui refroidit — et le
## refroidissement blanc → or atterrit précisément sur la sémantique « or = à
## lire » du thème.
##
## ## Deux mesures, selon ce qu'on grave
##
## **Gabarit fixe** (le code de salon, six cases) : chaque caractère a sa case,
## dimensionnée une fois pour toutes. Le bloc occupe exactement la même place
## avec un code, sans code et pendant la gravure — rien ne bouge autour, et le
## bouton COPIER ne se déplace jamais sous le doigt qui le vise.
##
## **Mesure libre** (l'adresse IP, longueur inconnue d'avance) : les cases
## naissent avec la chaîne et prennent la largeur de leur caractère. Un point
## d'IPv4 dans une case de chiffre laisserait un trou visible.
##
## Dans les deux cas `_get_minimum_size()` remonte la mesure au parent. Sans
## elle, un `Control` nu rend une taille minimale NULLE et, dans une rangée
## horizontale, le bouton COPIER vient se poser PAR-DESSUS le code — défaut vu à
## l'écran le 2026-08-18, sur les deux rangées à la fois.
##
## ## La gravure ne rejoue pas au repeint
##
## `set_code()` est appelé par tout ce qui rafraîchit le bloc salon, c'est-à-dire
## souvent et pour des raisons sans rapport. Seul un **changement** de chaîne
## déclenche l'animation ; sinon le code se regraverait à chaque signal réseau,
## et l'événement perdrait tout son poids.

## DA4.9 — **le code prend la fonte d'enseigne, et le gabarit décide du registre.**
##
## Le code de salon est l'objet social du jeu : celui qu'on lit à voix haute à un
## ami. La vague M lui avait déjà donné sa cérémonie — les six impacts, le métal
## qui refroidit — mais il restait écrit dans la fonte de tout le reste. Il est
## désormais en `BigShouldersDisplay`, la signalétique industrielle, ce qui le
## rend **iconique** au lieu de simplement gros.
##
## ⚠️ **Cette fonte n'est pas tabulaire, et ici ça n'a aucune importance —
## uniquement grâce au gabarit fixe.** Chaque caractère est centré dans sa propre
## case dimensionnée d'avance : un `W` et un `J` occupent le même espace, donc le
## bloc ne bouge jamais. C'est la seule disposition qui rende l'ultra-condensé
## inoffensif ; le même code écrit en ligne libre changerait de largeur à chaque
## tirage. Voir la note de section de [Charte] sur les deux registres.
##
## **D'où la règle appliquée ici : le registre suit le GABARIT, pas l'appelant.**
## Gabarit fixe = un code, un objet qu'on transmet, donc l'enseigne. Mesure libre
## = une adresse IP de longueur inconnue, donc l'appareil et ses chiffres
## tabulaires. Le lier au gabarit plutôt qu'à un paramètre de plus, c'est le
## rendre impossible à contredire : la seule disposition qui protège du
## non-tabulaire est exactement celle qui l'autorise.

## Nombre de cases. Le code de salon en fait six, le code de récupération aussi.
const CASES := 6
## Décalage d'un impact au suivant.
const DECALAGE := 0.07
## Durée du refroidissement blanc → or.
const REFROID := 0.5
## Amplitude de la secousse, en pixels.
const SECOUSSE := 1.0
## Durée de vie d'une étincelle.
const VIE_ETINCELLE := 0.3
const ETINCELLES_MIN := 2
const ETINCELLES_MAX := 3
## Placeholder d'une case vide.
const VIDE := "—"

var _intensite: float = 1.0
var _labels: Array[Label] = []
var _check: Label
var _boite: HBoxContainer
var _sparks: Control
var _code: String = ""
var _t: float = -1.0
var _etincelles: Array[Dictionary] = []
var _alea := RandomNumberGenerator.new()
## Nombre de cases imposé. Zéro = mesure libre, les cases suivent la chaîne.
var _gabarit: int = CASES
var _taille: int = MenuTheme.T_VERDICT
var _teinte: Color = MenuTheme.GOLD
## Largeur d'une case en gabarit fixe, et hauteur de la rangée : MESURÉES sur la
## fonte réellement posée, jamais déduites d'un coefficient — voir [method _mesurer].
var _case: float = 0.0
var _hauteur: float = 0.0

func _init(gabarit: int = CASES, taille: int = MenuTheme.T_VERDICT,
		teinte: Color = MenuTheme.GOLD) -> void:
	name = "GravureCode"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gabarit = maxi(gabarit, 0)
	_taille = taille
	_teinte = teinte
	_alea.randomize()

	_boite = HBoxContainer.new()
	_boite.name = "Cases"
	_boite.alignment = BoxContainer.ALIGNMENT_CENTER
	_boite.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
	_boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boite)

	_mesurer()

	# La coche de copie a sa propre case : la coller au code obligerait à
	# reconstruire les caractères pour l'afficher, donc à les regraver.
	#
	# Elle reste dans la fonte d'INTERFACE quel que soit le registre du code :
	# « ✓ » n'appartient à aucune des deux fontes du projet, il vient de la fonte
	# de repli du système. Lui poser une enseigne ultra-condensée ne changerait
	# donc rien à son dessin, et prétendrait le contraire.
	_check = Label.new()
	_check.name = "Coche"
	_check.custom_minimum_size = Vector2(_case * 0.8, _hauteur)
	_check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Charte.appareil(_check, int(_taille * 0.73))
	_check.add_theme_color_override("font_color", _teinte)
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boite.add_child(_check)

	_ajuster_cases(_gabarit)

	# Les étincelles se dessinent APRÈS les caractères : un enfant dessiné par le
	# parent passerait dessous, et une étincelle derrière le chiffre qu'elle vient
	# de frapper ne se voit pas.
	_sparks = Control.new()
	_sparks.name = "Etincelles"
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sparks.draw.connect(_dessiner_etincelles)
	add_child(_sparks)

## Ce que le parent doit nous réserver. Voir la note de tête : sans cette
## remontée, la rangée croit que le bloc ne prend aucune place.
func _get_minimum_size() -> Vector2:
	return _boite.get_combined_minimum_size() if _boite != null else Vector2.ZERO

## Le registre de ce bloc. Voir la note de tête : il suit le gabarit.
func registre() -> Charte.Registre:
	return Charte.Registre.ENSEIGNE if _gabarit > 0 else Charte.Registre.APPAREIL

## La fonte réellement posée sur les caractères, ou `null` si le fichier manque.
func police() -> Font:
	var g := Charte.graisse_pour(_taille, registre())
	return (Charte.police_display(g) if registre() == Charte.Registre.ENSEIGNE
		else Charte.police_ui(g))

## Mesure la case sur la fonte réellement posée, au lieu de la deviner.
##
## ⚠️ **Les deux coefficients d'avant — `× 0,87` en largeur, `× 1,27` en hauteur —
## n'étaient pas « justes pour Oxanium et faux ailleurs ». Ils étaient faux POUR
## OXANIUM.** À taille 30, la lettre la plus large de l'alphabet des codes fait
## **28,0 px** et la case en faisait **26,1**. Le `W` et le `M` étaient à
## l'étroit dans leur case depuis le premier jour.
##
## **Et c'est l'uniformité du défaut qui l'a caché.** Les six cases étaient trop
## étroites de la même quantité : rien ne dépassait par rapport à son voisin, rien
## n'était de travers. Le bloc paraissait serré, c'est-à-dire exactement ce
## qu'aurait donné quelqu'un ayant choisi de le serrer.
##
## Le soupçon de départ — « ces coefficients vont casser sous la fonte
## d'enseigne » — était d'ailleurs faux : mesurés, ils y tiennent à 4 % près.
## C'est en allant vérifier ce soupçon qu'on a trouvé l'autre défaut.
##
## La largeur est celle du **glyphe le plus large de l'alphabet des codes**, pas
## du caractère affiché : c'est ce qui tient la promesse « un I et un W occupent
## la même case ». Elle se mesure sur `LobbyCode.ALPHABET`, dont dérive aussi
## celui du code de récupération — un seul alphabet, donc une seule mesure.
##
## Sans fonte chargée (fichier absent, ou cache d'import pas encore construit),
## on retombe sur les anciens coefficients : le bloc reste dimensionné, la
## gravure reste jouable, et l'absence se lit au panneau F3.
func _mesurer() -> void:
	var f := police()
	if f == null:
		_case = _taille * 0.87
		_hauteur = _taille * 1.27
		return
	var large := 0.0
	for c in LobbyCode.ALPHABET:
		large = maxf(large, f.get_string_size(c,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _taille).x)
	# Un demi-pas de grille d'air de chaque côté : sans lui les caractères se
	# touchent, et six lettres collées cessent de se lire comme six signes.
	_case = large + MenuTheme.GAP_XXS
	_hauteur = f.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, _taille).y \
		+ MenuTheme.GAP_XXS

## Amène le nombre de cases à `n`, en créant ou en retirant ce qu'il faut. La
## coche reste la dernière : elle suit le code, elle ne s'y mêle pas.
func _ajuster_cases(n: int) -> void:
	while _labels.size() < n:
		var lbl := Label.new()
		lbl.name = "CodeChar%d" % _labels.size()
		lbl.text = VIDE
		# En gabarit fixe, un « I » et un « W » occupent la même case : le code ne
		# change pas de longueur selon les lettres tirées. Cette promesse tenait
		# par un coefficient réglé sur Oxanium ; elle tient désormais par la
		# mesure du glyphe le plus large — et `tools/test_habillage.gd` la vérifie
		# en gravant six `W` puis six `J` et en comparant les deux largeurs.
		lbl.custom_minimum_size = Vector2(_case if _gabarit > 0 else 0.0, _hauteur)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Charte.habiller_selon(lbl, _taille, registre())
		lbl.add_theme_color_override("font_color", _teinte)
		# Hors parcours du curseur : ce sont des caractères, pas des contrôles.
		lbl.focus_mode = Control.FOCUS_NONE
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boite.add_child(lbl)
		_labels.append(lbl)
	while _labels.size() > n:
		var mort := _labels.pop_back() as Label
		_boite.remove_child(mort)
		mort.queue_free()
	_boite.move_child(_check, -1)
	update_minimum_size()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_finir()

## Pose le code. Chaîne vide = salon pas encore ouvert : les six cases affichent
## leur tiret, et rien ne se grave.
func set_code(code: String) -> void:
	var propre := code.strip_edges().to_upper()
	if propre == _code:
		return
	_code = propre
	_check.text = ""
	# En mesure libre le bloc suit la chaîne ; en gabarit fixe il ne bouge jamais.
	_ajuster_cases(_gabarit if _gabarit > 0 else propre.length())
	for i in _labels.size():
		_labels[i].text = propre.substr(i, 1) if i < propre.length() else VIDE
		_labels[i].position.y = 0.0
	if propre.is_empty() or _intensite <= 0.0:
		_finir()
		return
	_etincelles.clear()
	_t = 0.0
	set_process(true)

## Le code actuellement gravé. Les bancs le lisent : six Labels séparés n'ont
## plus de `.text` unique, et le leur recomposer à chaque appel serait un second
## endroit où la vérité pourrait diverger.
func code() -> String:
	return _code

## Le joueur vient de copier : la coche s'allume sans toucher au code.
func marquer_copie() -> void:
	_check.text = "✓"

func _finir() -> void:
	_t = -1.0
	_etincelles.clear()
	for lbl in _labels:
		lbl.position.y = 0.0
		lbl.add_theme_color_override("font_color", MenuTheme.GOLD)
	set_process(false)
	_sparks.queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var vivant := false

	for i in _labels.size():
		var lbl := _labels[i]
		var t := _t - float(i) * DECALAGE
		if t < 0.0:
			# Pas encore frappé : la case reste vide, et le caractère qu'elle
			# porte déjà n'est simplement pas montré.
			lbl.modulate.a = 0.0
			vivant = true
			continue
		lbl.modulate.a = 1.0
		if t < REFROID:
			vivant = true
			var part := t / REFROID
			# Le métal refroidit vite au début puis lentement : la courbe fait le
			# travail que ferait un dégradé, sans en dessiner un.
			lbl.add_theme_color_override("font_color",
				MenuTheme.LUMIERE.lerp(MenuTheme.GOLD, sqrt(part)))
			lbl.position.y = SECOUSSE * _intensite * (1.0 - part) * cos(part * PI * 3.0)
		else:
			lbl.add_theme_color_override("font_color", MenuTheme.GOLD)
			lbl.position.y = 0.0
		# L'impact naît à l'instant exact où le caractère apparaît.
		if t >= 0.0 and t - delta < 0.0:
			_frapper(i)

	for e in _etincelles:
		e["t"] += delta
		e["v"] = (e["v"] as Vector2) + Vector2(0.0, 620.0 * delta)
		e["p"] = (e["p"] as Vector2) + (e["v"] as Vector2) * delta
	_etincelles = _etincelles.filter(func(e): return float(e["t"]) < VIE_ETINCELLE)
	if not _etincelles.is_empty():
		vivant = true

	_sparks.queue_redraw()
	if not vivant:
		_finir()

func _frapper(index: int) -> void:
	var lbl := _labels[index]
	var centre := lbl.position + lbl.size * 0.5
	for _i in _alea.randi_range(ETINCELLES_MIN, ETINCELLES_MAX):
		_etincelles.append({
			"p": centre,
			"v": Vector2(_alea.randf_range(-70.0, 70.0), _alea.randf_range(-150.0, -60.0)),
			"t": 0.0,
		})

func _dessiner_etincelles() -> void:
	if _intensite <= 0.0:
		return
	for e in _etincelles:
		var mort := 1.0 - float(e["t"]) / VIE_ETINCELLE
		var c := MenuTheme.LUMIERE.lerp(MenuTheme.GOLD, 1.0 - mort)
		c.a = mort * _intensite
		_sparks.draw_circle(e["p"] as Vector2, 1.0 + mort, c)
