class_name EstampeDeKill
extends CanvasLayer

## DA6.2 — la photo du gel fatal, signée.
##
## Le gel existe depuis V2.1 : 150 ms de rendu figé sur l'impact, puis la
## killcam, puis deux secondes d'arrêt sur image. V2.7 y a posé le tampon
## « KILL — 04:12 ». **La fiche DA6.2 demande le reste : le cadrer, le titrer,
## le dater — pour que chaque kill produise une image montrable.**
##
## Ce que ce fichier ajoute au tampon, et pourquoi si peu :
##
## - **Un cadre** (`CadrePhoto`) : un écran montre un monde qui continue hors
##   champ, une image affirme un bord.
## - **Une ligne de tête** : le nom du jeu et la date. C'est ce qui rend une
##   capture identifiable une fois sortie du jeu — sans elle, l'image est une
##   image de quelque chose.
## - **Une légende de pied** : la carte, l'arme, le mode. Trois faits, et
##   seulement ceux que l'écran ne dit pas déjà.
##
## ⚠️ **La marge du coup fatal n'est PAS dans la légende, et c'est délibéré.**
## V2.9 l'écrit déjà au-dessus du corps, à cette seconde précise. La répéter en
## bas de cadre ferait dire deux fois la même chose au même moment — le défaut
## exact que DA4.7 a corrigé sur le bandeau de fin. La légende porte ce qui
## manque, jamais ce qui redonde.
##
## ## Le tampon garde son claquement, et il ne se déplace pas
##
## Le premier jet l'avait poussé en haut à gauche « pour dégager l'image ». À
## l'écran, la composition se vidait : le tampon EST le sujet, et un sujet en
## coin fait une image qui attend autre chose. Il reste au centre, avec son
## inclinaison et son rebond d'encreur — c'est du travail déjà jugé, on n'y
## touche pas.
##
## ## Durée
##
## Toute la vie de cette image tient dans l'arrêt sur image de deux secondes que
## `game_state` ménage avant l'écran de fin. Dépasser, c'est se faire recouvrir
## en pleine apparition ; rester en deçà, c'est laisser deux secondes de gel nu.
## `DUREE_UTILE` est donc lue par les deux côtés — et le test la compare au
## `create_timer(2.0)` de la séquence de fin, pour qu'un changement de l'un se
## voie sur l'autre.

const Charte := preload("res://charte.gd")

## Ce que l'image occupe, du premier pixel au dernier. Doit rester ≤ à l'arrêt
## sur image de `game_state._do_end_round` (2 s).
const DUREE_UTILE := 2.0

## Le temps que met le tirage à venir — cadre, légende, et l'effacement du HUD.
const D_LEVEE := 0.22
const D_APPARITION := 0.03
const D_CLAQUEMENT := 0.12
## Ce qui reste des deux secondes une fois la levée et la sortie payées, moins
## le claquement du tampon. Écrit en clair pour que la somme se vérifie à l'œil :
## 0,22 + 0,03 + 0,12 + 1,48 + 0,15 = 2,00.
const D_TENUE := 1.48
const D_SORTIE := 0.15

## L'échelle de départ du tampon : l'inertie d'un encreur qu'on abat.
const ECHELLE_ABATTUE := 2.6

## L'inclinaison, en radians. Trois degrés et demi : assez pour qu'on voie que
## le tampon a été POSÉ, pas assez pour qu'il ait l'air tombé.
const INCLINAISON := -0.06


## Pose l'image sur l'arrêt sur image et la laisse vivre sa vie.
##
## `faits` : `temps` (secondes écoulées de la manche), `carte`, `arme`, `mode`.
## Tout est facultatif — une clé absente retire sa mention plutôt que d'écrire un
## tiret. Une case vide se lit comme une donnée perdue ; une mention absente ne
## pose aucune question.
## `estomper` : ce qu'on efface le temps de la photo — le HUD de match, en
## pratique. Une jauge de vie figée sur un mort n'informe plus personne, et elle
## occupe précisément la bande où se posent les légendes.
static func poser(parent: Node, faits: Dictionary,
		estomper: Array = []) -> EstampeDeKill:
	var couche := EstampeDeKill.new()
	couche.name = "EstampeDeKill"
	couche.layer = 95
	parent.add_child(couche)
	couche._estompes = estomper
	couche._composer(faits)
	return couche


var _racine: Control
var _estompes: Array = []


func _composer(faits: Dictionary) -> void:
	_racine = Control.new()
	_racine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

	var cadre := CadrePhoto.new()
	# Un filet plus présent qu'au menu : il tombe sur une image de jeu presque
	# noire, où `LINE` disparaîtrait. C'est la même couleur, montée en alpha —
	# jamais une seconde couleur, qui ferait une seconde décision à tenir.
	cadre.teinte = Color(Charte.ACIER, 0.34)
	_racine.add_child(cadre)

	var taille := _ecran()
	var marge := CadrePhoto.marge_pour(taille)

	# --- la légende, TOUTE en bas ----------------------------------------
	#
	# ⚠️ **Le premier jet mettait la signature en haut**, et la première photo l'a
	# montrée : le HUD de match occupe toute la bande supérieure — panneau de
	# vie à gauche, chronomètre au centre —, si bien que « CANDELA » se posait
	# derrière le panneau de J1 et la date derrière rien du tout. La bande basse,
	# elle, est vide dans ce jeu. Une légende de photo s'y met de toute façon.
	var pied := _ligne(marge)
	_racine.add_child(pied)
	var gauche := _legende(faits)
	if gauche != "":
		pied.add_child(_mention(gauche, Color(Charte.ACIER, 0.62)))
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pied.add_child(vide)
	pied.add_child(_mention("CANDELA · " + _date(),
		Color(Charte.HALOGENE, 0.55)))

	# --- le tampon, inchangé --------------------------------------------
	var tampon := Label.new()
	tampon.text = "KILL — %s" % MatchRecord.format_clock(
		float(faits.get("temps", 0.0)))
	var reglages := LabelSettings.new()
	reglages.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	reglages.font_size = Charte.T_ENSEIGNE
	reglages.font_color = Charte.ROUGE
	Charte.contourer_settings(reglages, reglages.font_size)
	tampon.label_settings = reglages
	tampon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tampon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tampon.set_anchors_preset(Control.PRESET_FULL_RECT)
	tampon.pivot_offset = taille / 2.0
	tampon.rotation = INCLINAISON
	tampon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(tampon)

	# Le cadre et les mentions arrivent AVANT le tampon, et plus doucement : ils
	# sont le tirage, il est ce qu'on y a imprimé. Les faire claquer ensemble
	# donnait une image qui saute d'un bloc, sans hiérarchie.
	cadre.modulate.a = 0.0
	pied.modulate.a = 0.0
	tampon.modulate.a = 0.0
	tampon.scale = Vector2(ECHELLE_ABATTUE, ECHELLE_ABATTUE)

	# ⚠️ **DEUX tweens, et le premier jet n'en avait qu'un.** Il mélangeait
	# `set_parallel(true)`, `chain()` et `parallel()` — et la sonde a montré ce
	# que ça produisait : le HUD s'éteignait bien, puis **remontait à 1 en trois
	# dixièmes**, au lieu de rester éteint le temps de la photo. Mesuré à
	# l'image : 0,565 → 0,000 → 0,132 → 0,934 → 1,000, et plus rien ne bougeait
	# ensuite. Un seul tween qui mêle les trois modes est un ordre d'exécution
	# qu'on croit lire ; deux tweens séquentiels sont un ordre qu'on lit.
	#
	# Le premier porte l'IMAGE, le second ce qu'on efface pour elle. Ils n'ont
	# rien à se dire : l'un compose, l'autre range.
	var tw := create_tween()
	Charte.animer(tw, cadre, "modulate:a", 0.0, 1.0, D_LEVEE, Charte.Courbe.SORTIE)
	tw.parallel()
	Charte.animer(tw, pied, "modulate:a", 0.0, 1.0, D_LEVEE, Charte.Courbe.SORTIE)
	tw.tween_property(tampon, "modulate:a", 1.0, D_APPARITION)
	tw.parallel()
	Charte.animer(tw, tampon, "scale", Vector2(ECHELLE_ABATTUE, ECHELLE_ABATTUE),
		Vector2.ONE, D_CLAQUEMENT, Charte.Courbe.REBOND)
	tw.tween_interval(D_TENUE)
	Charte.animer(tw, cadre, "modulate:a", 1.0, 0.0, D_SORTIE,
		Charte.Courbe.ENTREE)
	tw.parallel()
	Charte.animer(tw, pied, "modulate:a", 1.0, 0.0, D_SORTIE, Charte.Courbe.ENTREE)
	tw.parallel()
	Charte.animer(tw, tampon, "modulate:a", 1.0, 0.0, D_SORTIE,
		Charte.Courbe.ENTREE)
	tw.tween_callback(queue_free)

	# Le HUD : un tween par nœud, purement séquentiel — s'éteindre, attendre la
	# photo, revenir. La tenue est calculée depuis `DUREE_UTILE` pour que le HUD
	# revienne EXACTEMENT quand l'image s'en va, quoi qu'on change au-dessus.
	var tenue: float = maxf(0.0, DUREE_UTILE - D_LEVEE - D_SORTIE)
	for n in _estompes:
		var ci := n as CanvasItem
		if not is_instance_valid(ci):
			continue
		var th := create_tween()
		Charte.animer(th, ci, "modulate:a", ci.modulate.a, 0.0, D_LEVEE,
			Charte.Courbe.ENTREE)
		th.tween_interval(tenue)
		Charte.animer(th, ci, "modulate:a", 0.0, 1.0, D_SORTIE,
			Charte.Courbe.SORTIE)


## ⚠️ **La ceinture.** `_clear_kill_stamp()` libère cette couche sur tous les
## chemins d'abandon de la killcam — une manche relancée, un pair qui part. Le
## tween meurt avec elle, et le HUD resterait invisible pour le reste de la
## partie sans que rien ne le dise : le nœud existe, il est simplement
## transparent. C'est exactement la forme de panne que ce dépôt appelle « muette
## et vraisemblable ».
func _exit_tree() -> void:
	for n in _estompes:
		var ci := n as CanvasItem
		if is_instance_valid(ci):
			ci.modulate.a = 1.0


## La taille réelle de l'écran, disponible IMMÉDIATEMENT.
##
## ⚠️ **`Control.size` vaut zéro tant que la mise en page n'a pas eu lieu**, et
## une composition bâtie dans la foulée d'un `add_child()` la lit donc à zéro.
## Le repli « 1920×1080 » qui traînait ici marchait par coïncidence sur la
## fenêtre de développement et donnait des marges d'un tiers trop larges en
## 1280×720. Le viewport, lui, connaît sa taille avant tout le monde.
func _ecran() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)


## La ligne de légende, collée en pied de cadre.
##
## Une seule, et sans variante « en tête » : la version précédente en proposait
## deux, la bande haute a été abandonnée au profit du HUD qui l'occupe, et une
## branche qu'on n'emprunte plus finit par mentir sur ce qu'elle fait.
func _ligne(marge: float) -> HBoxContainer:
	var boite := HBoxContainer.new()
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	boite.offset_left = marge
	boite.offset_right = -marge
	boite.offset_bottom = -marge
	boite.offset_top = -Charte.T_MENTION * 2.0
	return boite


func _mention(texte: String, teinte: Color) -> Label:
	var lbl := Label.new()
	lbl.text = texte
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Charte.appareil(lbl, Charte.T_MENTION)
	lbl.add_theme_color_override("font_color", teinte)
	# Le contour : ces mentions tombent sur une image de jeu dont on ne connaît
	# ni la luminosité ni le contenu. Sans lui, une mention posée sur une flaque
	# de torche disparaît — et c'est justement là qu'on regarde.
	Charte.contourer_control(lbl, Charte.T_MENTION)
	return lbl


## La carte et l'arme, séparées d'un point médian. Ce que l'écran ne dit pas.
func _legende(faits: Dictionary) -> String:
	var bouts: Array[String] = []
	var carte := String(faits.get("carte", "")).strip_edges()
	if carte != "":
		bouts.append(carte.to_upper())
	var arme := String(faits.get("arme", "")).strip_edges()
	if arme != "":
		bouts.append(arme.to_upper())
	return " · ".join(bouts)


## La date seule, sans l'heure. Une photo se date au jour ; l'heure du kill est
## déjà dans le tampon, et c'est une autre horloge — celle de la manche.
func _date() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%02d.%02d.%04d" % [int(d["day"]), int(d["month"]), int(d["year"])]
