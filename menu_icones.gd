class_name MenuIcones
extends RefCounted

## Les icônes dessinées de l'interface — et la mort des derniers emojis.
##
## ⚠️ **Ce fichier a annoncé « le dernier emoji » une fois de trop.** Les cinq
## des boutons d'arme sont morts le 2026-08-26 ; l'éditeur de cartes en gardait
## un sixième, `💾` sur SAUVEGARDER, plus dix-huit glyphes Unicode rares
## (`▭ ⌗ ⇔ ⇕ ⟳ ⤡ ⤢ ↶ ↷ ◎ ⧉ ⤓ ✦ ⌫ ▶ ✕`) que personne n'avait comptés. **Un
## nettoyage annoncé complet empêche le suivant** : on ne recompte pas ce qu'on
## croit fini. Le compte se tient maintenant dans un banc, pas dans une phrase.
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


## Les outils de l'éditeur de cartes, indexés sur le **slug d'action** — la
## constante `ACTION_*` de `map_editor_hud.gd`, ou le mode de pinceau.
##
## Même règle que `PAR_ARME`, et pour la même raison : le slug, jamais le
## libellé. « TOUT VIDER » peut devenir « EFFACER » demain sans qu'une icône
## disparaisse en silence.
const PAR_OUTIL := {
	# Les trois pinceaux, un par valeur de `map_editor.gd:Brush`.
	"pinceau_libre": "outil_pinceau.png",
	"pinceau_rect": "outil_rectangle.png",
	"pinceau_pot": "outil_pot.png",
	# Les actions : la clé EST la constante `MapEditorHUD.ACTION_*`.
	"auto_walls": "outil_murs_auto.png",
	"mirror_h": "outil_miroir_h.png",
	"mirror_v": "outil_miroir_v.png",
	"mirror_ad": "outil_miroir_ad.png",
	"rotate_180": "outil_rotation.png",
	"undo": "outil_annuler.png",
	"redo": "outil_refaire.png",
	"light": "outil_lumiere.png",
	"frame": "outil_cadre.png",
	"share": "outil_partager.png",
	"clear": "outil_effacer.png",
}


## Les icônes qui n'ont pas de fichier : elles sont le **reflet** d'une autre.
##
## ⚠️ **La symétrie diagonale et l'anti-diagonale ne peuvent pas être deux
## dessins.** Ce sont deux boutons voisins qui désignent le même geste sur deux
## axes opposés : si leurs icônes ne sont pas rigoureusement l'image l'une de
## l'autre, le joueur les lit comme deux outils différents. Deux tirages
## indépendants n'auraient jamais donné cette exactitude — c'est la leçon que la
## doctrine de `assets/sources/ui_outils/` consigne pour la planche des
## symétries, appliquée un cran plus loin : ici, le second n'est même pas un
## tirage.
##
## Un seul fichier, deux boutons, et la paire tient par construction — comme la
## torche de DA4.14 sert les deux joueurs par `modulate`.
const REFLET_DE := {
	"mirror_d": "mirror_ad",
}


## Les actions dont l'icône ne se déduit **pas** de l'action, mais d'un état.
##
## ⚠️ **`brush` ne veut pas dire « le pinceau », il veut dire « changer de
## pinceau ».** Son bouton montre le mode COURANT — rectangle, libre ou pot —,
## donc son icône arrive par `set_brush()` et non par le catalogue. Sans cette
## liste, l'action apparaîtrait orpheline au banc, et la corriger en l'ajoutant
## à `SANS_ICONE` aurait été un mensonge exact : elle en a une, mais pas la
## sienne.
const ICONE_D_ETAT := ["brush"]


## Les actions de l'éditeur qui n'ont **pas** d'icône, et pour lesquelles il n'y
## en a pas non plus de commandée. Elles retombent sur leur libellé texte.
##
## ⚠️ **Deux absences se ressemblent et ne se soignent pas pareil.** Une icône
## *cataloguée mais pas cuite* attend un fichier, et `manquantes()` la nomme ;
## une action *hors catalogue* attend une décision — faut-il seulement lui en
## dessiner une ? Les confondre envoie chercher un fichier que personne n'a
## jamais commandé. Cette liste existe pour que la seconde question ait un
## endroit où se poser.
const SANS_ICONE := ["grid_wider", "grid_narrower", "grid_taller",
	"grid_shorter", "new", "import", "save", "test", "back"]


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


## L'icône d'un outil de l'éditeur, par son slug d'action.
##
## Les reflets sont calculés au premier appel puis gardés : retourner une image
## de 128 px coûte peu, mais le faire à chaque survol de bouton serait absurde.
static func outil(slug: String) -> Texture2D:
	if REFLET_DE.has(slug):
		return _reflet(String(REFLET_DE[slug]))
	return icone(String(PAR_OUTIL.get(slug, "")))


static var _reflets: Dictionary = {}

## L'image retournée d'une icône existante. `null` si la source manque.
static func _reflet(source: String) -> Texture2D:
	if _reflets.has(source):
		return _reflets[source]
	var tex := outil(source)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate() as Image
	# ⚠️ **`get_image()` peut rendre une image compressée**, et `flip_x()` refuse
	# d'y toucher. Les icônes sont importées sans perte (`compress/mode=0`), donc
	# le cas ne se présente pas aujourd'hui — mais il se présenterait sans bruit
	# le jour où quelqu'un change ce réglage dans l'inspecteur.
	if img.is_compressed():
		img.decompress()
	img.flip_x()
	var miroir := ImageTexture.create_from_image(img)
	_reflets[source] = miroir
	return miroir


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
	return poser_texture(bouton, arme(slug), teinte, cote)


## Pose l'icône d'un outil de l'éditeur sur un bouton.
##
## La teinte par défaut est celle du texte d'interface : dans l'éditeur, une
## icône n'appartient à personne — contrairement aux armes, où elle dit *quel
## joueur*. Le site d'appel reste libre de la changer, c'est tout l'intérêt de
## ne pas enfermer la couleur ici.
static func poser_outil(bouton: Button, slug: String,
		teinte: Color = Charte.HALOGENE, cote: float = 22.0) -> bool:
	return poser_texture(bouton, outil(slug), teinte, cote)


## Pose une texture déjà résolue. Rend `false` si le bouton ou l'icône manque.
static func poser_texture(bouton: Button, tex: Texture2D, teinte: Color,
		cote: float) -> bool:
	if bouton == null or tex == null:
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
	for f: String in PAR_OUTIL.values():
		if not ResourceLoader.exists(DOSSIER + f):
			out.append(f)
	return out
