class_name CarteDeSoiree
extends Control

## DA6.3 (= V6.10) — la carte de fin de soirée, et l'image qu'on en garde.
##
## « Ce soir : 7 matchs, 4-3, arme favorite : pompe. » La fiche V6.10 la voulait
## au retour menu après trois matchs ; DA6.3 la veut **illustrée**, DA6.4 la veut
## **exportable en image**. Les trois demandent la même chose : que la soirée
## laisse une trace qu'on puisse regarder après avoir éteint.
##
## ## Un `Control`, et pas un `CanvasLayer` — c'est ce qui rend DA6.4 possible
##
## La même composition sert deux fois : posée sur l'écran à la taille de la
## fenêtre, et posée dans un `SubViewport` à 1080×1350 pour en tirer un PNG. Un
## `CanvasLayer` ne peut pas entrer dans un `SubViewport` en gardant sa mise en
## page ; un `Control` qui se compose À PARTIR DE SA TAILLE le peut.
##
## **C'est la contrainte qui a fait la mise en page, et elle l'a améliorée.** Un
## premier jet écrivait ses tailles de police en dur : à 1080×1350 le bloc tenait
## le tiers de la carte. Tout est désormais dérivé de la hauteur, ce qui était de
## toute façon la bonne façon de composer.
##
## ## Portrait, et non 16:9
##
## L'image exportée est en 4:5 — le format que les téléphones et les fils
## d'actualité ne recadrent pas. Une carte de soirée se montre sur un téléphone,
## pas sur un moniteur : l'exporter au format du jeu garantissait qu'elle soit
## recoupée par quelqu'un d'autre, et mal.
##
## ## Ce qu'elle ne dit pas
##
## Ni ELO, ni progression, ni comparaison à hier. Une carte de fin de soirée se
## regarde entre gens qui viennent de jouer ; un chiffre de classement en ferait
## un relevé de performance, et c'est l'écran PROFIL qui en a la charge.

const Charte := preload("res://charte.gd")

## Le format de l'image exportée. 4:5, celui qui ne se fait pas recadrer.
const TAILLE_EXPORT := Vector2i(1080, 1350)

## DA6.3 dit « illustrées », et la fiche est marquée *(S + C)* : la composition
## est du ressort des sessions, l'illustration d'une commande. **L'emplacement
## est donc câblé et vide.** Le jour où le fichier existe, la carte le prend ;
## tant qu'il n'existe pas, elle reste sur son noir et ne dit rien.
##
## C'est l'idiome déjà employé pour l'audio de ce dépôt — un crochet muet plutôt
## qu'une fonctionnalité absente — et il vaut mieux que l'inverse : une carte qui
## réclamerait son illustration pour s'afficher rendrait DA6.3 indissociable
## d'une commande, et DA6.4 avec elle.
const FOND_ILLUSTRE := "res://assets/ui/carte_soiree_fond.png"

## Ce que l'illustration garde de sa force. 0,22 : une carte de fin de soirée est
## un tableau de chiffres avant d'être une image, et un fond à pleine puissance
## rendrait le score illisible — la faute exacte que le chantier DA reproche aux
## interfaces qui « décorent » au lieu de composer.
const FOND_FORCE := 0.22

## La hauteur de référence des tailles de police. Toute la composition s'échelle
## depuis elle — changer ce nombre change la carte entière, et rien d'autre.
const HAUTEUR_ETALON := 1350.0

var _bilan: Dictionary = {}


## Compose une carte pour un bilan et une taille données.
##
## `pour_export` retire l'invite de touches : elle n'a aucun sens dans un PNG, et
## une image qui dit « ENTRÉE — GARDER L'IMAGE » raconte l'outil au lieu de la
## soirée.
static func composer(bilan: Dictionary, taille: Vector2,
		pour_export: bool = false) -> CarteDeSoiree:
	var carte := CarteDeSoiree.new()
	carte.name = "CarteDeSoiree"
	carte.custom_minimum_size = taille
	carte.size = taille
	carte._bilan = bilan
	carte._batir(taille, pour_export)
	return carte


func _batir(taille: Vector2, pour_export: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var echelle: float = taille.y / HAUTEUR_ETALON
	var marge := CadrePhoto.marge_pour(taille)

	var fond := ColorRect.new()
	fond.color = Color(Charte.NOIR, 1.0)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)

	# L'emplacement de l'illustration (DA6.3, moitié *(C)*). Absent, il ne
	# laisse rien — pas un cadre vide, pas un carré gris.
	if ResourceLoader.exists(FOND_ILLUSTRE):
		var illustration := TextureRect.new()
		illustration.texture = load(FOND_ILLUSTRE)
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# `KEEP_ASPECT_COVERED` : la carte est en 4:5, une illustration arrivera
		# dans le format qu'elle aura. On remplit et on rogne, plutôt que de
		# laisser des bandes noires qui feraient mentir le cadre.
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illustration.modulate = Color(1.0, 1.0, 1.0, FOND_FORCE)
		add_child(illustration)

	var cadre := CadrePhoto.new()
	cadre.teinte = Color(Charte.ACIER, 0.26)
	add_child(cadre)

	var colonne := VBoxContainer.new()
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	colonne.offset_left = marge
	colonne.offset_right = -marge
	colonne.offset_top = marge
	colonne.offset_bottom = -marge
	colonne.add_theme_constant_override("separation", int(Charte.GAP_S * echelle))
	add_child(colonne)

	# --- la tête ---------------------------------------------------------
	var tete := HBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(tete)
	tete.add_child(_mention("CANDELA", Color(Charte.HALOGENE, 0.70), echelle))
	tete.add_child(_ressort())
	tete.add_child(_mention(_date(), Color(Charte.ACIER, 0.45), echelle))

	colonne.add_child(_filet(echelle, 0.26))
	# Deux ressorts, un de chaque côté du corps : la masse se centre au lieu de
	# se tasser en haut. Sans le premier, la carte gardait un tiers de vide sous
	# le tableau — un vide qui se lit comme un oubli, pas comme de l'air.
	colonne.add_child(_ressort_vertical())

	# --- le nombre de la soirée -------------------------------------------
	# Un seul chiffre en grand, et le mot dessous. C'est le geste d'affiche de
	# DA6.1 réemployé : ce qui compte se lit de loin, le reste se lit de près.
	var n := int(_bilan.get("matchs", 0))
	colonne.add_child(_enorme(str(n), Charte.HALOGENE, echelle, 0.155))
	colonne.add_child(_mention("MATCH%s CE SOIR" % ("S" if n > 1 else ""),
		Color(Charte.ACIER, 0.62), echelle))
	colonne.add_child(_air(Charte.GAP_L, echelle))

	# --- le score ---------------------------------------------------------
	var local := int(_bilan.get("local_idx", -1))
	var v := int(_bilan.get("victoires", 0))
	var d := int(_bilan.get("defaites", 0))
	var nul := int(_bilan.get("nulles", 0))
	colonne.add_child(_enorme("%d – %d" % [v, d],
		Charte.VERT if v > d else (Charte.ROUGE if d > v else Charte.ACIER),
		echelle, 0.095))
	var sous_score := "VICTOIRES – DÉFAITES" if local >= 0 else "JOUEUR 1 – JOUEUR 2"
	if nul > 0:
		sous_score += "   ·   %d ÉGALITÉ%s" % [nul, "S" if nul > 1 else ""]
	colonne.add_child(_mention(sous_score, Color(Charte.ACIER, 0.62), echelle))
	colonne.add_child(_air(Charte.GAP_L, echelle))
	colonne.add_child(_filet(echelle, 0.18))
	colonne.add_child(_air(Charte.GAP_M, echelle))

	# --- les faits de la soirée -------------------------------------------
	for ligne in _lignes_de_faits():
		colonne.add_child(_paire(String(ligne[0]), String(ligne[1]), echelle))

	colonne.add_child(_ressort_vertical())
	colonne.add_child(_filet(echelle, 0.18))
	colonne.add_child(_air(Charte.GAP_XS, echelle))

	# --- le pied -----------------------------------------------------------
	var pied := HBoxContainer.new()
	pied.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(pied)
	pied.add_child(_mention(BilanDeSoiree.phrase(_bilan),
		Color(Charte.ACIER, 0.40), echelle, Charte.T_MENTION))
	if not pour_export:
		pied.add_child(_ressort())
		pied.add_child(_mention("ENTRÉE — GARDER L'IMAGE   ·   ÉCHAP — FERMER",
			Color(Charte.ACIER, 0.38), echelle, Charte.T_MENTION))


## Les lignes « intitulé / valeur » de la soirée, dans l'ordre où on les lit.
##
## Chacune disparaît quand elle n'a rien à dire. Une soirée d'entraînement n'a
## pas d'arme favorite, une soirée sur une seule carte n'a pas d'arène favorite
## qui apprenne quoi que ce soit — et une ligne « — » se lit comme une donnée
## perdue plutôt que comme une absence.
func _lignes_de_faits() -> Array:
	var out: Array = []
	var arme := String(_bilan.get("arme", ""))
	if arme != "":
		out.append(["ARME FAVORITE", "%s   (%d)" % [arme.to_upper(),
			int(_bilan.get("arme_n", 0))]])
	var carte := String(_bilan.get("carte", ""))
	var n_carte := int(_bilan.get("carte_n", 0))
	# Une « arène favorite » jouée une seule fois n'est pas une favorite : c'est
	# la seule carte de la soirée, et le mot ment.
	if carte != "" and n_carte >= 2:
		out.append(["ARÈNE FAVORITE", "%s   (%d)" % [carte.to_upper(), n_carte]])
	var serie := int(_bilan.get("serie", 0))
	if serie >= 2:
		out.append(["MEILLEURE SÉRIE", "%d D'AFFILÉE" % serie])
	var total := float(_bilan.get("duree_totale", 0.0))
	if total > 0.0:
		out.append(["TEMPS DE JEU", BilanDeSoiree.duree_longue(total)])
	var court := float(_bilan.get("plus_court", -1.0))
	if court >= 0.0:
		out.append(["MATCH LE PLUS COURT", MatchRecord.format_clock(court)])
	return out


# ---------------------------------------------------------------------------
# LA MENUISERIE TYPOGRAPHIQUE
# ---------------------------------------------------------------------------

func _enorme(texte: String, teinte: Color, echelle: float, part: float) -> Label:
	var lbl := Label.new()
	lbl.text = texte
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reglages := LabelSettings.new()
	reglages.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	reglages.font_size = maxi(18, int(HAUTEUR_ETALON * part * echelle))
	reglages.font_color = teinte
	lbl.label_settings = reglages
	return lbl


func _paire(intitule: String, valeur: String, echelle: float) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(_mention(intitule, Color(Charte.ACIER, 0.48), echelle,
		Charte.T_MENTION))
	ligne.add_child(_ressort())
	ligne.add_child(_mention(valeur, Color(Charte.HALOGENE, 0.88), echelle))
	return ligne


func _mention(texte: String, teinte: Color, echelle: float,
		taille: int = Charte.T_COURANT) -> Label:
	var lbl := Label.new()
	lbl.text = texte
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Charte.appareil(lbl, maxi(9, int(taille * echelle * 1.35)))
	lbl.add_theme_color_override("font_color", teinte)
	return lbl


func _filet(echelle: float, alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(Charte.ACIER, alpha)
	r.custom_minimum_size = Vector2(0, maxf(1.0, roundf(echelle)))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _air(px: int, echelle: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0, px * echelle)
	return c


func _ressort() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _ressort_vertical() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _date() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%02d.%02d.%04d" % [int(d["day"]), int(d["month"]), int(d["year"])]
