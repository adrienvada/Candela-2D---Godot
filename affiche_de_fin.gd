class_name AfficheDeFin
extends CanvasLayer

## DA6.1 — l'écran de victoire, composé comme une affiche.
##
## ## Ce que la fiche reproche à l'existant, et elle a raison
##
## L'écran de fin actuel est un SALON avec un titre au-dessus : la liste des
## modes, les deux panneaux d'armes, la vignette de carte, le bouton REJOUER. Il
## est juste — c'est là que « encore une » se décide — et il ne se montre pas.
## Une capture de cet écran raconte « un menu de jeu », pas « j'ai gagné ».
##
## ## Ce que ce fichier ajoute, et ce qu'il ne touche pas
##
## Une affiche, posée par-dessus, qui tient jusqu'à ce qu'on la congédie. Le
## salon reste dessous, intact : **aucune ligne de `ui.gd` ne change.** C'est le
## précédent du tampon de kill, qui vit dans son propre `CanvasLayer` parce que
## `ui.gd` appartient à une autre session — et c'est aussi le bon découpage,
## indépendamment de qui tient quel fichier : une affiche et un salon n'ont ni
## la même durée de vie, ni le même travail.
##
## ## Trois décisions de composition, et leurs raisons
##
## **Le fond est opaque.** Premier jet : un voile à 82 % laissant transparaître
## l'arrêt sur image du kill. À l'écran, ce n'était pas l'arène qui remontait —
## c'était le SALON, avec ses rectangles, ses libellés et sa vignette, réduits à
## un bruit géométrique derrière le mot. Deux images valent mieux qu'une image
## double : la photo du gel (DA6.2) montre le monde deux secondes plus tôt,
## l'affiche montre le mot.
##
## ⚠️ **Opaque DÈS LA PREMIÈRE IMAGE, et il ne l'a pas été depuis sa création (DA6,
## 2026-09-09).** Le fond entrait en fondu, de 0 à 1 en 0,34 s sur une courbe qui
## traîne avant de filer (`SORTIE`) — et `ui.show_game_over()` allume le salon DANS
## LA MÊME IMAGE que l'affiche se pose. Mesuré image par image le 2026-09-29 (Xvfb, 60 Hz de jeu) :
## opacité de l'affiche 0,09 huit images après la pose, 0,28 après treize, alors que
## le rideau du salon était tombé (0,96) dès la huitième et ses cartes de classe se
## lisaient à la dixième. Pendant une quinzaine d'images, le joueur voyait le menu
## de rejeu se construire, puis l'affiche le recouvrir : « il arrive que je vois
## subrepticement le menu de rejeu avant l'affichage du carton » (Adrien). Ce qui
## entre en fondu, ce sont donc l'illustration et le mot — jamais le noir qui cache
## le salon. Voir `couverture()`, que la garde suit à chaque image.
##
## **Le mot est à gauche, pas au centre.** Un mot centré sur fond noir est un
## écran de chargement. Aligné sur une marge, avec un filet dessous et une
## légende sous le filet, il devient un bloc typographique — c'est-à-dire une
## décision, qui est tout ce que le chantier DA demande.
##
## **Le verdict n'est pas recalculé ici.** Il est LU sur le titre que
## `ui.show_game_over()` vient de poser, couleur comprise. Le mot dépend du mode
## (« VICTOIRE » en ligne, « JOUEUR 1 GAGNE » en écran partagé) et d'une décision
## d'Adrien sur l'égalité grise ; en refaire le calcul ici garantissait qu'un
## jour les deux divergent, et que l'affiche annonce un vainqueur que le menu
## dessous contredit.
##
## ## Elle se congédie de deux façons, et la seconde est une sécurité
##
## N'importe quel appui la retire. Et elle se retire seule au bout de `DUREE_MAX` :
## sous elle peut apparaître un message que le joueur DOIT voir — « l'adversaire a
## quitté », un échec de connexion. Une affiche qui attend indéfiniment un geste
## est une affiche qui peut masquer une mauvaise nouvelle.
##
## ## « N'importe quel appui », c'est cinq choses, et l'ancien code n'en tenait que deux
##
## (Adrien, 2026-09-29 : « fais en sorte que ce carton soit skippable avec n'importe
## quelle touche ».) Mesuré sous Xvfb sur le jeu réel, avant cette version :
## la touche du clavier congédiait ; le CLIC DE SOURIS jamais ; L1 et R1 de la manette
## jamais ; les GÂCHETTES jamais.
##
## 1. **Elle écoute avant l'interface (`_input`), pas après (`_unhandled_input`).**
##    Son propre fond, `MOUSE_FILTER_STOP`, avale le clic dans la phase de l'interface :
##    ce qui n'écoute qu'`_unhandled_input` n'en voit jamais la couleur — le commentaire
##    de ce fond disait « elle avale les clics » sans voir que cela la rendait sourde aux
##    siens. Et `ui._input`, qui passe avant `_unhandled_input`, mangeait L1 et R1
##    (« onglet précédent / suivant » du salon) : ils ne congédiaient rien et faisaient
##    remonter le salon d'un cran DESSOUS.
## 2. **Le geste qui la congédie est consommé.** Toute autre touche la congédiait ET
##    déplaçait un curseur du salon caché. Tout appui est donc avalé tant que l'affiche
##    vit, congédiante ou non — sauf les touches de fonction, qui restent au jeu
##    (F4 est la trace d'écoute, F2 la pâte : des outils, pas des gestes).
## 3. **Les gâchettes comptent.** Ce sont des AXES (`InputEventJoypadMotion`), que
##    `InputEventJoypadButton` ne voit jamais — et R2 est le tir de la manette. Voir
##    `_gachette_pressee`.
## 4. **Le geste tenu ne compte pas.** Le bouton de tir enfoncé au moment du coup fatal ne
##    doit pas passer l'affiche à la première image. Pour une touche, un bouton de
##    souris, un bouton de manette, c'est acquis : seul un NOUVEL appui produit un
##    événement (`echo` exclu). Pour une gâchette, dont la valeur tremble tant qu'on la
##    tient, on retient d'où elle part : tenue à la pose, elle doit d'abord être relâchée.
## 5. **Une courte garde : l'entrée.** Tant que l'affiche n'a pas fini d'entrer, un appui
##    est avalé sans la congédier — on ne renvoie pas ce qui n'est pas encore lisible, et
##    un joueur qui martèle le tir au moment de la mort l'aurait passée avant de la
##    voir. La garde EST la durée de l'entrée (`est_armee()`), pas un nombre de plus :
##    la lever à la fin de l'animation la garde honnête si l'animation change.
##
## **Ce que « passer » fait, dans chaque mode : rien qu'en local.** Elle retire l'affiche
## et rend REJOUER — verrouillé tant qu'elle vit (`UI.set_launch_locked`). Rien ne part
## sur le fil : ni RPC, ni `protocol.gd`. L'écran scindé revoit le salon et REJOUER relance
## une manche ; en ligne, REJOUER lance la poignée de main de la revanche (les deux camps
## doivent se déclarer prêts), que passer l'affiche ne précède ni ne remplace, et l'affiche
## de l'AUTRE machine vit sa vie — six secondes ou son propre geste. À l'entraînement, il
## n'y a pas d'affiche : aucune manche n'y est armée, aucune mort n'y clôt un match.

const Charte := preload("res://charte.gd")

## Au-dessus du tampon de kill (95) et de l'interface (1).
const COUCHE := 96

## La sécurité : au-delà, l'affiche s'efface d'elle-même. Six secondes, c'est
## le temps de lire quatre lignes deux fois.
const DUREE_MAX := 6.0

## Le temps avant que l'invite n'apparaisse. Assez pour qu'on ait regardé
## l'affiche avant qu'on nous dise comment en sortir.
const DELAI_INVITE := 1.3

const D_ENTREE := 0.34
const D_SORTIE := 0.26

## La hauteur du mot, en fraction de la hauteur de l'écran. 13 % : à 1080 px cela
## fait 140, soit deux fois l'enseigne de la charte — la taille à laquelle un mot
## cesse d'être un titre pour devenir un sujet.
const PART_VERDICT := 0.13

## Une gâchette est « pressée » au-delà de ce seuil — celui de la zone morte du tir dans
## `project.godot` (0,5, voir « Pièges connus »), pour qu'un appui compte pour l'affiche
## exactement quand il compte pour le jeu. Elle n'est « relâchée » qu'en dessous du
## second : entre les deux, une gâchette qui tremble ne change pas d'état.
const SEUIL_GACHETTE := 0.5
const SEUIL_RELACHE := 0.3
## Les manettes dont on relève l'état des gâchettes à la pose. Le jeu en branche deux ; huit
## couvrent un pupitre de bancs sans qu'un indice hors bornes soit jamais lu.
const MANETTES_SURVEILLEES := 8

var _fond: ColorRect
var _racine: Control
var _invite: Label
var _congedie := false
## Vrai quand l'entrée est finie : c'est la garde. Voir « Une courte garde » en tête.
var _armee := false
## Par manette et par gâchette : tenue au dernier événement vu (ou à la pose).
var _gachettes_tenues := {}


## Pose l'affiche. `faits` : `carte`, `duree`, `classe_j1`, `classe_j2` (les LIBELLÉS des
## classes — « Le Parasite » —, jamais le nom de leur arme), `mode`, `session_j1`,
## `session_j2`, `serie`, `marge_px`, `local_idx`.
## `titre` est le nœud dont on lit le verdict — le titre du menu de fin.
static func poser(parent: Node, faits: Dictionary,
		titre: Label = null) -> AfficheDeFin:
	var couche := AfficheDeFin.new()
	couche.name = "AfficheDeFin"
	couche.layer = COUCHE
	parent.add_child(couche)
	couche._composer(faits, titre)
	return couche


func _composer(faits: Dictionary, titre: Label) -> void:
	# ⚠️ **Opaque, et le premier jet ne l'était pas.** À 94 % d'alpha, six pour
	# cent d'un salon restaient lisibles — et six pour cent d'une barre ambre
	# saturée, ce n'est pas six pour cent d'une image : le bouton REJOUER
	# traversait l'affiche en travers du mot. Un voile ne compose pas, il
	# superpose.
	var fond := ColorRect.new()
	fond.name = "Fond"
	_fond = fond
	fond.color = Charte.NOIR
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# L'affiche AVALE les clics : sans ça, un joueur qui la congédie d'un clic
	# appuierait du même geste sur l'entrée du salon qui se trouve dessous. ⚠️ **Et c'est
	# précisément ce qui la rendait sourde aux siens** tant qu'elle n'écoutait qu'après
	# l'interface : voir « N'importe quel appui » en tête — elle écoute maintenant avant.
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)
	# Habillage iso (2026-09-15) : l'illustration de fin, ENFANT du fond — elle hérite de
	# sa sortie sans une ligne de plus. Opaque comme lui : la décision « le fond est opaque »
	# tient, c'est le noir qui cède la place à une image entière, jamais à une transparence
	# qui laisserait remonter le salon. Son ENTRÉE, elle, est la sienne : le fond ne se fond
	# pas (voir « Opaque DÈS LA PREMIÈRE IMAGE »), c'est l'image qui monte sur le noir.
	var illustration := _illustration_pour(_verdict_texte(titre, faits))
	if illustration != null:
		fond.add_child(illustration)

	_racine = Control.new()
	_racine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

	var taille := _ecran()
	var marge := CadrePhoto.marge_pour(taille)
	var echelle: float = taille.y / 1080.0

	var cadre := CadrePhoto.new()
	# 0,30 et non 0,22 : sur un fond devenu opaque, un filet à 0,22 d'acier tombe
	# à RGB 39 — il existe dans le fichier et pas à l'œil. Le premier réglage
	# avait été choisi contre un fond translucide, où il portait davantage.
	cadre.teinte = Color(Charte.PATE_TEXTE_SECOND, 0.30)
	_racine.add_child(cadre)

	# --- ligne de tête ---------------------------------------------------
	var tete := _bande(marge, true)
	_racine.add_child(tete)
	var mode := String(faits.get("mode", "")).strip_edges().to_upper()
	tete.add_child(_mention("CANDELA" + (" · " + mode if mode != "" else ""),
		Color(Charte.PATE_TEXTE, 0.66), echelle))
	tete.add_child(_ressort())
	tete.add_child(_mention(_date(), Color(Charte.PATE_TEXTE_SECOND, 0.45), echelle))

	# --- le bloc du verdict ----------------------------------------------
	var bloc := VBoxContainer.new()
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	bloc.grow_horizontal = Control.GROW_DIRECTION_END
	bloc.grow_vertical = Control.GROW_DIRECTION_BOTH
	bloc.offset_left = marge
	# Les ancres sont à gauche : `offset_right` se mesure donc depuis le BORD
	# GAUCHE, pas depuis la droite. `taille.x - marge` place la fin du bloc à une
	# marge du bord opposé — c'est-à-dire là où le filet doit s'arrêter.
	bloc.offset_right = taille.x - marge
	bloc.add_theme_constant_override("separation", int(Charte.GAP_S * echelle))
	_racine.add_child(bloc)

	var mot := Label.new()
	mot.name = "Verdict"
	mot.text = _verdict_texte(titre, faits)
	var reglages := LabelSettings.new()
	reglages.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	reglages.font_size = maxi(24, int(taille.y * PART_VERDICT))
	reglages.font_color = _verdict_teinte(titre)
	Charte.contourer_settings(reglages, reglages.font_size)
	mot.label_settings = reglages
	bloc.add_child(mot)

	var filet := ColorRect.new()
	filet.color = Color(Charte.PATE_TEXTE_SECOND, 0.44)
	filet.custom_minimum_size = Vector2(0, maxf(1.0, roundf(echelle)))
	filet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloc.add_child(filet)

	var legende := _legende(faits)
	if legende != "":
		var ligne := _mention(legende, Color(Charte.PATE_TEXTE_SECOND, 0.72), echelle,
			Charte.T_TITRE)
		ligne.name = "Legende"
		bloc.add_child(ligne)

	# --- la ligne de session ---------------------------------------------
	var pied := _bande(marge, false)
	_racine.add_child(pied)
	for texte in _colonnes_de_session(faits):
		pied.add_child(_mention(texte, Color(Charte.PATE_TEXTE_SECOND, 0.62), echelle))
		pied.add_child(_ressort())

	_invite = _mention("UNE TOUCHE POUR CONTINUER", Color(Charte.PATE_TEXTE_SECOND, 0.38),
		echelle)
	_invite.name = "Invite"
	_invite.modulate.a = 0.0
	pied.add_child(_invite)

	# --- l'entrée ---------------------------------------------------------
	# Le mot arrive par le bas de quelques pixels : une affiche qui se pose, pas
	# un panneau qui apparaît. L'écart est petit — au-delà, on retombe sur le
	# vocabulaire des menus, où tout glisse.
	#
	# ⚠️ **Le fond, lui, ne bouge pas : il est opaque à la première image.** Ce qui entre en
	# fondu, c'est l'image et le mot, sur ce noir. Voir « Opaque DÈS LA PREMIÈRE IMAGE ».
	_racine.modulate.a = 0.0
	if illustration != null:
		illustration.modulate.a = 0.0
	var depart: float = bloc.position.y + 18.0 * echelle
	bloc.position.y = depart
	# ⚠️ **Pas de `set_parallel(true)` global ici, et c'est une leçon payée.**
	# `estampe_de_kill.gd` en portait un, mêlé à des `chain()` et à des
	# `parallel()` : un `parallel()` posé juste après un `chain()` **annule ce
	# `chain()`**, et le groupe de sortie s'était retrouvé à tourner en même
	# temps que la tenue. Mesuré à la sonde, invisible à la lecture. On écrit
	# donc en séquentiel par défaut, et on nomme les parallèles une par une.
	var tw := create_tween()
	Charte.animer(tw, _racine, "modulate:a", 0.0, 1.0, D_ENTREE, Charte.Courbe.SORTIE)
	if illustration != null:
		tw.parallel()
		Charte.animer(tw, illustration, "modulate:a", 0.0, 1.0, D_ENTREE, Charte.Courbe.SORTIE)
	tw.parallel()
	Charte.animer(tw, bloc, "position:y", depart, depart - 18.0 * echelle,
		D_ENTREE * 1.4, Charte.Courbe.SORTIE)
	# L'entrée est finie : un appui compte à partir d'ici (voir « Une courte garde »).
	tw.tween_callback(func() -> void: _armee = true)
	tw.tween_interval(DELAI_INVITE)
	Charte.animer(tw, _invite, "modulate:a", 0.0, 1.0, 0.4, Charte.Courbe.SORTIE)
	tw.tween_interval(maxf(0.0, DUREE_MAX - DELAI_INVITE - D_ENTREE))
	tw.tween_callback(congedier)

	# Avant l'interface, pas après : voir « N'importe quel appui » en tête. Et l'état des
	# gâchettes À LA POSE : c'est là que se décide si l'une d'elles est déjà tenue.
	_relever_les_gachettes()
	set_process_input(true)


## Toujours vraie tant que l'affiche est visible — `game_state` s'en sert pour
## refuser un « PRÊT » cliqué à travers elle. Fausse dès `congedier()` : rien
## n'attend `queue_free()`, sous peine de laisser passer un clic pendant le
## fondu de sortie.
func est_active() -> bool:
	return not _congedie


## L'entrée est-elle finie ? Avant, un appui ne compte pas : voir « Une courte garde » en
## tête. Vraie ensuite, jusqu'à la sortie.
func est_armee() -> bool:
	return _armee


## Combien le noir cache ce qui se trouve dessous, de 0 à 1 : l'opacité du fond.
##
## **Elle vaut 1 dès la première image, et c'est le contrat de l'entrée** : le salon s'allume
## dans la MÊME image que l'affiche se pose, et rien de lui ne doit se voir avant que ce
## noir ne l'ait recouvert. `tools/test_carton_transition.gd` la suit à chaque image de la
## fin de manche. Elle ne baisse qu'à la sortie — et c'est voulu : le salon se révèle alors.
func couverture() -> float:
	return _fond.modulate.a if is_instance_valid(_fond) else 0.0


## Congédier : une seule porte, quel que soit le geste. Deux chemins de sortie
## laisseraient un jour l'un des deux oublier de rendre la main aux entrées.
func congedier() -> void:
	if _congedie:
		return
	_congedie = true
	set_process_input(false)
	var tw := create_tween()
	var premier := true
	for enfant in get_children():
		var c := enfant as CanvasItem
		if c == null:
			continue
		if not premier:
			tw.parallel()
		premier = false
		Charte.animer(tw, c, "modulate:a", c.modulate.a, 0.0, D_SORTIE,
			Charte.Courbe.ENTREE)
	tw.tween_callback(queue_free)


## Tout appui, avant l'interface. Voir « N'importe quel appui » en tête : ce qui suit en est
## la mécanique, et chaque ligne y répond à un défaut mesuré.
func _input(evenement: InputEvent) -> void:
	if _congedie or not is_inside_tree():
		return
	if not _est_un_appui(evenement):
		return
	# Avalé tant que l'affiche vit, congédiant ou non : ce qui la congédie n'agit pas sur le salon
	# caché dessous, et un appui pendant l'entrée ne fait pas remonter un menu qu'on ne voit pas.
	# Les touches de fonction restent au jeu — F4 est la trace d'écoute, F2 la pâte.
	if not _est_touche_de_fonction(evenement):
		get_viewport().set_input_as_handled()
	# La garde : l'entrée n'est pas finie, l'appui est avalé et compte pour rien.
	if not _armee:
		return
	congedier()


## Cet événement est-il un APPUI — le début d'un geste, jamais sa suite ?
##
## Ni les mouvements de souris ni les relâchements : l'affiche disparaîtrait avant d'être
## lue, sur le simple fait de reposer la main sur le clavier. Ni la répétition d'une touche
## tenue (`echo`) : c'est le geste du coup fatal, et il n'est pas nouveau. Ni la molette, que
## Godot rend comme un bouton pressé puis relâché dans le même souffle : faire défiler
## n'est pas congédier. Ni un stick : ce n'est pas une touche.
func _est_un_appui(evenement: InputEvent) -> bool:
	var touche := evenement as InputEventKey
	if touche != null:
		return touche.pressed and not touche.echo
	var souris := evenement as InputEventMouseButton
	if souris != null:
		return souris.pressed and souris.button_index != MOUSE_BUTTON_WHEEL_UP \
			and souris.button_index != MOUSE_BUTTON_WHEEL_DOWN \
			and souris.button_index != MOUSE_BUTTON_WHEEL_LEFT \
			and souris.button_index != MOUSE_BUTTON_WHEEL_RIGHT
	var bouton := evenement as InputEventJoypadButton
	if bouton != null:
		return bouton.pressed
	var axe := evenement as InputEventJoypadMotion
	if axe != null:
		return _gachette_pressee(axe)
	return false


## Une gâchette vient-elle d'être PRESSÉE — passée de relâchée à tenue ?
##
## L2 et R2 sont des axes, et la valeur d'un axe tremble tant qu'on le tient : chaque tremblement
## est un événement, qui ne doit pas passer pour un appui. On retient donc, par manette et par
## gâchette, si elle est tenue — à la pose (`_relever_les_gachettes`), puis à chaque événement.
## Une gâchette tenue ne compte pas ; relâchée (sous `SEUIL_RELACHE`), puis pressée
## (au-delà de `SEUIL_GACHETTE`), elle compte. C'est le tir du coup fatal qui est visé : il
## se tient encore quand l'affiche apparaît.
func _gachette_pressee(evenement: InputEventJoypadMotion) -> bool:
	if evenement.axis != JOY_AXIS_TRIGGER_LEFT and evenement.axis != JOY_AXIS_TRIGGER_RIGHT:
		return false
	var cle := _cle_gachette(evenement.device, evenement.axis)
	if bool(_gachettes_tenues.get(cle, false)):
		if evenement.axis_value < SEUIL_RELACHE:
			_gachettes_tenues[cle] = false
		return false
	if evenement.axis_value > SEUIL_GACHETTE:
		_gachettes_tenues[cle] = true
		return true
	return false


func _cle_gachette(manette: int, axe: int) -> int:
	return manette * 16 + axe


## Ce que le processus sait des gâchettes à l'instant où l'affiche se pose.
func _relever_les_gachettes() -> void:
	for manette in MANETTES_SURVEILLEES:
		for axe in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			_gachettes_tenues[_cle_gachette(manette, axe)] = \
				Input.get_joy_axis(manette, axe) > SEUIL_GACHETTE


## F1 à F12 : des outils (trace d'écoute, pâte, diagnostic), pas des gestes du joueur. Elles congédient
## l'affiche comme toute touche, mais ne lui sont pas confisquées.
func _est_touche_de_fonction(evenement: InputEvent) -> bool:
	var touche := evenement as InputEventKey
	if touche == null:
		return false
	var code: int = touche.physical_keycode if touche.physical_keycode != KEY_NONE \
		else touche.keycode
	return code >= KEY_F1 and code <= KEY_F12


# ---------------------------------------------------------------------------
# LA MATIÈRE
# ---------------------------------------------------------------------------

## Le mot du verdict, LU sur le titre du menu de fin. Voir l'en-tête : le
## recalculer garantissait la divergence. Le repli n'existe que pour le banc, qui
## peut composer une affiche sans menu derrière.
func _verdict_texte(titre: Label, faits: Dictionary) -> String:
	if titre != null and is_instance_valid(titre) and titre.text.strip_edges() != "":
		return titre.text
	var vainqueur := int(faits.get("vainqueur", -1))
	var local := int(faits.get("local_idx", -1))
	if vainqueur < 0:
		return "ÉGALITÉ"
	if local < 0:
		return "JOUEUR %d GAGNE" % (vainqueur + 1)
	return "VICTOIRE" if vainqueur == local else "DÉFAITE"


## Les illustrations de fin, en pâte D (sources ISO Assets `fin_victoire` et
## `fin_defaite`, recadrées dans leur encre par `tools/preparer_habillage.py`).
const FIN_VICTOIRE := "res://assets/ui/fin_victoire.jpg"
const FIN_DEFAITE := "res://assets/ui/fin_defaite.jpg"
## Ce que l'illustration garde de sa lumière sous le mot. 0,55 : le verdict est en
## couleur de joueur ou en gris d'égalité, et l'image doit rester SOUS lui.
const FORCE_ILLUSTRATION := 0.55


## L'illustration qui va avec le mot — lu, jamais recalculé (voir l'en-tête).
##
## - **Égalité** : aucune. Personne n'a éteint personne ; l'affiche garde son noir.
## - **Défaite** : la lampe tombée. **Tout le reste** (« VICTOIRE », « JOUEUR n
##   GAGNE ») : la torche tenue — en écran partagé, quelqu'un a gagné.
##
## ⚠️ **Retournée** (`flip_h`) : les deux planches posent leur sujet éclairé à
## GAUCHE, là où l'affiche pose le mot. En miroir, la gauche devient l'ombre et
## reçoit le verdict ; la lumière passe à droite, dans le vide que le bloc laisse.
##
## Absente, l'affiche reste sur son noir et le dit (`push_error`) : pas d'image de
## remplacement.
func _illustration_pour(mot: String) -> TextureRect:
	var m := mot.strip_edges().to_upper()
	if m == "" or m.begins_with("ÉGALITÉ"):
		return null
	var chemin := FIN_DEFAITE if m.begins_with("DÉFAITE") else FIN_VICTOIRE
	if not ResourceLoader.exists(chemin):
		push_error("affiche de fin : illustration absente — %s" % chemin)
		return null
	var ill := TextureRect.new()
	ill.name = "Illustration"
	ill.texture = load(chemin)
	ill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ill.flip_h = true
	ill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ill.self_modulate = Color(FORCE_ILLUSTRATION, FORCE_ILLUSTRATION, FORCE_ILLUSTRATION)
	return ill


func _verdict_teinte(titre: Label) -> Color:
	if titre != null and is_instance_valid(titre):
		var c := titre.get_theme_color(&"font_color")
		if c.a > 0.0:
			return c
	return Charte.PATE_TEXTE


## La carte, la durée, les deux CLASSES. L'ordre va du lieu au geste.
##
## ⚠️ **La classe, pas l'arme** (Adrien, 2026-09-29 : « le carton de fin affiche la classe »). Le
## carton écrivait `WeaponData.name` — « Pistolet », « Pompe », « Pistolet silencieux » —, le nom de
## l'ARME, qui n'est pas ce que le joueur a choisi : à l'écran de sélection on choisit « Le Parasite »,
## pas un pistolet. Deux Parasites se lisaient « PISTOLET / PISTOLET » ; l'Illusionniste, « FUSIL ».
## Le libellé (`ClassData.libelle` : « Le Parasite », « L'Illusionniste ») est ce que le salon, la
## fenêtre de choix et la fiche de classe écrivent déjà. J1 d'abord, J2 ensuite, sur chaque
## machine : l'hôte et le client lisent la même ligne.
##
## ⚠️ **Le repli ne redit PAS une arme.** Une classe inconnue se tait ; elle n'emprunte pas le
## nom de l'arme d'un joueur sans classe — un mauvais nom plausible se prend pour une intention.
func _legende(faits: Dictionary) -> String:
	var bouts: Array[String] = []
	var carte := String(faits.get("carte", "")).strip_edges()
	if carte != "":
		bouts.append(carte.to_upper())
	var duree := float(faits.get("duree", -1.0))
	if duree >= 0.0:
		bouts.append(MatchRecord.format_clock(duree))
	var c1 := String(faits.get("classe_j1", "")).strip_edges()
	var c2 := String(faits.get("classe_j2", "")).strip_edges()
	if c1 != "" and c2 != "":
		bouts.append("%s / %s" % [c1.to_upper(), c2.to_upper()])
	elif c1 != "":
		bouts.append(c1.to_upper())
	elif c2 != "":
		bouts.append(c2.to_upper())
	return "  ·  ".join(bouts)


## Les colonnes du pied : le score de session, la série, la marge du dernier
## coup. Chacune disparaît quand elle n'a rien à dire — une colonne vide se lit
## comme une donnée perdue.
func _colonnes_de_session(faits: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var j1 := int(faits.get("session_j1", 0))
	var j2 := int(faits.get("session_j2", 0))
	if j1 + j2 > 0:
		out.append("SESSION  %d – %d" % [j1, j2])
	var serie := String(faits.get("serie", "")).strip_edges()
	if serie != "":
		out.append(serie.to_upper())
	var marge := float(faits.get("marge_px", -1.0))
	if marge >= 0.0:
		out.append("DERNIER COUP  " + Echelle.ecrire(marge))
	return out


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


func _bande(marge: float, en_tete: bool) -> HBoxContainer:
	var boite := HBoxContainer.new()
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.set_anchors_preset(Control.PRESET_TOP_WIDE if en_tete
		else Control.PRESET_BOTTOM_WIDE)
	boite.offset_left = marge
	boite.offset_right = -marge
	if en_tete:
		boite.offset_top = marge
	else:
		boite.offset_bottom = -marge
		boite.offset_top = -Charte.T_COURANT * 2.2
	return boite


func _ressort() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _mention(texte: String, teinte: Color, echelle: float,
		taille: int = Charte.T_COURANT) -> Label:
	var lbl := Label.new()
	lbl.text = texte
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Charte.appareil(lbl, maxi(9, int(taille * echelle)))
	lbl.add_theme_color_override("font_color", teinte)
	return lbl


func _date() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%02d.%02d.%04d" % [int(d["day"]), int(d["month"]), int(d["year"])]
