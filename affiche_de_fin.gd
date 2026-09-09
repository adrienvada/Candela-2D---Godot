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
## Une touche la retire. Et elle se retire seule au bout de `DUREE_MAX` : sous
## elle peut apparaître un message que le joueur DOIT voir — « l'adversaire a
## quitté », un échec de connexion. Une affiche qui attend indéfiniment un geste
## est une affiche qui peut masquer une mauvaise nouvelle.

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

var _racine: Control
var _invite: Label
var _congedie := false


## Pose l'affiche. `faits` : `carte`, `duree`, `arme_j1`, `arme_j2`, `mode`,
## `session_j1`, `session_j2`, `serie`, `marge_px`, `local_idx`.
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
	fond.color = Charte.NOIR
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# L'affiche AVALE les clics : sans ça, un joueur qui la congédie d'un clic
	# appuierait du même geste sur l'entrée du salon qui se trouve dessous.
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)

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
	cadre.teinte = Color(Charte.ACIER, 0.30)
	_racine.add_child(cadre)

	# --- ligne de tête ---------------------------------------------------
	var tete := _bande(marge, true)
	_racine.add_child(tete)
	var mode := String(faits.get("mode", "")).strip_edges().to_upper()
	tete.add_child(_mention("CANDELA" + (" · " + mode if mode != "" else ""),
		Color(Charte.HALOGENE, 0.66), echelle))
	tete.add_child(_ressort())
	tete.add_child(_mention(_date(), Color(Charte.ACIER, 0.45), echelle))

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
	mot.text = _verdict_texte(titre, faits)
	var reglages := LabelSettings.new()
	reglages.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	reglages.font_size = maxi(24, int(taille.y * PART_VERDICT))
	reglages.font_color = _verdict_teinte(titre)
	Charte.contourer_settings(reglages, reglages.font_size)
	mot.label_settings = reglages
	bloc.add_child(mot)

	var filet := ColorRect.new()
	filet.color = Color(Charte.ACIER, 0.44)
	filet.custom_minimum_size = Vector2(0, maxf(1.0, roundf(echelle)))
	filet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloc.add_child(filet)

	var legende := _legende(faits)
	if legende != "":
		bloc.add_child(_mention(legende, Color(Charte.ACIER, 0.72), echelle,
			Charte.T_TITRE))

	# --- la ligne de session ---------------------------------------------
	var pied := _bande(marge, false)
	_racine.add_child(pied)
	for texte in _colonnes_de_session(faits):
		pied.add_child(_mention(texte, Color(Charte.ACIER, 0.62), echelle))
		pied.add_child(_ressort())

	_invite = _mention("UNE TOUCHE POUR CONTINUER", Color(Charte.ACIER, 0.38),
		echelle)
	_invite.modulate.a = 0.0
	pied.add_child(_invite)

	# --- l'entrée ---------------------------------------------------------
	# Le mot arrive par le bas de quelques pixels : une affiche qui se pose, pas
	# un panneau qui apparaît. L'écart est petit — au-delà, on retombe sur le
	# vocabulaire des menus, où tout glisse.
	fond.modulate.a = 0.0
	_racine.modulate.a = 0.0
	var depart: float = bloc.position.y + 18.0 * echelle
	bloc.position.y = depart
	# ⚠️ **Pas de `set_parallel(true)` global ici, et c'est une leçon payée.**
	# `estampe_de_kill.gd` en portait un, mêlé à des `chain()` et à des
	# `parallel()` : un `parallel()` posé juste après un `chain()` **annule ce
	# `chain()`**, et le groupe de sortie s'était retrouvé à tourner en même
	# temps que la tenue. Mesuré à la sonde, invisible à la lecture. On écrit
	# donc en séquentiel par défaut, et on nomme les parallèles une par une.
	var tw := create_tween()
	Charte.animer(tw, fond, "modulate:a", 0.0, 1.0, D_ENTREE, Charte.Courbe.SORTIE)
	tw.parallel()
	Charte.animer(tw, _racine, "modulate:a", 0.0, 1.0, D_ENTREE, Charte.Courbe.SORTIE)
	tw.parallel()
	Charte.animer(tw, bloc, "position:y", depart, depart - 18.0 * echelle,
		D_ENTREE * 1.4, Charte.Courbe.SORTIE)
	tw.tween_interval(DELAI_INVITE)
	Charte.animer(tw, _invite, "modulate:a", 0.0, 1.0, 0.4, Charte.Courbe.SORTIE)
	tw.tween_interval(maxf(0.0, DUREE_MAX - DELAI_INVITE - D_ENTREE))
	tw.tween_callback(congedier)

	set_process_unhandled_input(true)


## Toujours vraie tant que l'affiche est visible — `game_state` s'en sert pour
## refuser un « PRÊT » cliqué à travers elle. Fausse dès `congedier()` : rien
## n'attend `queue_free()`, sous peine de laisser passer un clic pendant le
## fondu de sortie.
func est_active() -> bool:
	return not _congedie


## Congédier : une seule porte, quel que soit le geste. Deux chemins de sortie
## laisseraient un jour l'un des deux oublier de rendre la main aux entrées.
func congedier() -> void:
	if _congedie:
		return
	_congedie = true
	set_process_unhandled_input(false)
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


func _unhandled_input(evenement: InputEvent) -> void:
	if _congedie:
		return
	# Ni les mouvements de souris ni les relâchements : l'affiche disparaîtrait
	# avant d'être lue, sur le simple fait de reposer la main sur le clavier.
	var geste: bool = evenement is InputEventKey and evenement.pressed \
		and not evenement.echo
	geste = geste or (evenement is InputEventMouseButton and evenement.pressed)
	geste = geste or (evenement is InputEventJoypadButton and evenement.pressed)
	if not geste:
		return
	get_viewport().set_input_as_handled()
	congedier()


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


func _verdict_teinte(titre: Label) -> Color:
	if titre != null and is_instance_valid(titre):
		var c := titre.get_theme_color(&"font_color")
		if c.a > 0.0:
			return c
	return Charte.HALOGENE


## La carte, la durée, les deux armes. L'ordre va du lieu au geste.
func _legende(faits: Dictionary) -> String:
	var bouts: Array[String] = []
	var carte := String(faits.get("carte", "")).strip_edges()
	if carte != "":
		bouts.append(carte.to_upper())
	var duree := float(faits.get("duree", -1.0))
	if duree >= 0.0:
		bouts.append(MatchRecord.format_clock(duree))
	var a1 := String(faits.get("arme_j1", "")).strip_edges()
	var a2 := String(faits.get("arme_j2", "")).strip_edges()
	if a1 != "" and a2 != "":
		bouts.append("%s / %s" % [a1.to_upper(), a2.to_upper()])
	elif a1 != "":
		bouts.append(a1.to_upper())
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
