class_name MenuIcones
extends RefCounted

## Les icônes dessinées de l'interface — et la mort du dernier emoji.
##
## **Le dépôt en portait cinq**, dans les boutons d'arme et l'indicateur de
## torche : 🔫 🏹 ☄️ 💥 🔦. Ils paraissent inoffensifs et ils sont le marqueur
## amateur le plus visible qui restait, pour trois raisons cumulées :
##
## 1. **Ils sont rendus par la fonte emoji du SYSTÈME**, pas par les nôtres. Tout
##    le travail de DA1.2 — deux fontes choisies, licences, axe variable — les
##    contourne. Ce sont les seuls glyphes du jeu que la charte n'atteint pas.
## 2. **Ils arrivent en couleur pleine et saturée.** La règle 1 de la charte
##    plafonne la saturation à 75 % parce que le 100 % est « la signature du
##    personne n'a choisi » ; un emoji est à 100 % par construction, et il porte
##    en plus des teintes — orange vif, rouge — que la charte réserve à des sens
##    précis.
## 3. **Ils diffèrent d'une machine à l'autre.** Le même code montre un pistolet
##    gris sur macOS, un autre sur Windows, une case vide sur un Linux sans fonte
##    emoji. Un jeu ne peut pas avoir une identité visuelle qui dépend du système
##    d'exploitation de son joueur.
##
## ## Ce que ce fichier fait, et surtout ce qu'il ne fait pas
##
## Il **rend une texture pour un nom**, et rien d'autre. Aucune mise en page,
## aucune couleur, aucune taille : ce sont des décisions de site d'appel, et les
## enfermer ici obligerait ce fichier à savoir ce qu'est un bouton d'arme.
##
## La teinte est appliquée par l'appelant sur un masque gris — **un seul fichier
## sert les deux joueurs**, bleu d'un côté, rouge de l'autre. C'est la discipline
## DA1.5 : l'image ne fournit que la matière, le code garde la couleur.
##
## ## Le repli est la moitié du travail
##
## Une icône absente ne casse rien et ne se tait pas : l'appelant retombe sur le
## **libellé texte**, qui reste lisible. Règle du dépôt — câbler, taire,
## diagnostiquer. C'est ce qui permet de poser tout le câblage avant que les
## fichiers n'existent, et de les voir apparaître un par un sans rien changer.

const DOSSIER := "res://assets/ui/icones/"

## Le nom de fichier par arme, indexé sur le **slug** de `weapon_data.gd` et non
## sur son nom affiché.
##
## ⚠️ **Le slug, jamais le nom.** « Arbalète » porte un accent et une majuscule ;
## dériver un chemin de fichier d'un libellé traduisible est la garantie qu'un
## jour le renommage d'un bouton fera disparaître une icône, sans erreur et sans
## que le lien soit visible. `weapon_data.gd` a déjà payé cette leçon — sa note
## de tête l'écrit noir sur blanc.
const PAR_ARME := {
	"pistolet": "arme_pistolet.png",
	"fusil": "arme_fusil.png",
	"pompe": "arme_pompe.png",
	"arbalete": "arme_arbalete.png",
}

## La lampe torche, dans l'indicateur du HUD.
const TORCHE := "torche.png"


## La texture d'un nom de fichier, ou `null` s'il n'est pas encore cuit.
static func icone(fichier: String) -> Texture2D:
	if fichier == "":
		return null
	var chemin := DOSSIER + fichier
	if not ResourceLoader.exists(chemin):
		return null
	return load(chemin) as Texture2D


## L'icône d'une arme, par son slug. `null` tant qu'elle n'est pas cuite.
static func arme(slug: String) -> Texture2D:
	return icone(String(PAR_ARME.get(slug, "")))


## Pose l'icône d'une arme sur un bouton, teintée, et adapte son libellé.
##
## **Le libellé perd son emoji dans tous les cas**, que l'icône existe ou non :
## un emoji est un défaut à lui seul, et le garder « en attendant » aurait laissé
## le dépôt dans l'état qu'on corrige précisément.
##
## Rend `true` si une icône a été posée — les bancs le lisent pour distinguer
## « pas encore cuite » de « cuite et non affichée », deux états qui se
## ressemblent trop à l'œil.
static func poser_sur(bouton: Button, slug: String, teinte: Color,
		cote: float = 20.0) -> bool:
	if bouton == null:
		return false
	var tex := arme(slug)
	if tex == null:
		return false
	bouton.icon = tex
	# ⚠️ **`icon_max_width` et non une taille de contrôle.** Un `Button` ne
	# redimensionne pas son icône : sans ce réglage il l'affiche à sa taille
	# native — 128 px pour un bouton qui en fait 40 de haut. C'est le cousin exact
	# du piège `EXPAND_KEEP_SIZE` des `TextureRect`, payé par DA1 le 2026-08-24 :
	# on pose une taille, elle est ignorée, et l'écran affiche autre chose.
	bouton.add_theme_constant_override("icon_max_width", int(cote))
	# La teinte du joueur sur un masque gris. `icon_normal_color` et non
	# `modulate` : `modulate` teindrait aussi le libellé.
	bouton.add_theme_color_override("icon_normal_color", teinte)
	bouton.add_theme_color_override("icon_pressed_color", teinte)
	bouton.add_theme_color_override("icon_hover_color", teinte)
	bouton.add_theme_color_override("icon_disabled_color", Charte.DIM)
	return true


## Les icônes attendues et absentes. Vide = tout est cuit.
##
## Le panneau F3 le lit : une absence se diagnostique, elle ne se devine pas.
## Même motif que `Charte.polices_manquantes()`.
static func manquantes() -> Array[String]:
	var out: Array[String] = []
	for f: String in PAR_ARME.values():
		if not ResourceLoader.exists(DOSSIER + f):
			out.append(f)
	if not ResourceLoader.exists(DOSSIER + TORCHE):
		out.append(TORCHE)
	return out
