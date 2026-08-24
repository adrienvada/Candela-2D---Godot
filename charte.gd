class_name Charte
extends RefCounted

## La charte visuelle du jeu — couleurs, typographie, rythme, courbes.
##
## **Un seul endroit, et tout en descend.** Avant ce fichier, le dépôt portait
## 220 `Color(...)` écrits à la main, six ors distincts, sept rouges, et deux
## copies de la palette (`ui.gd` et `menu_theme.gd`) que le commentaire de la
## seconde promettait de réunir « à l'étape 3 », close depuis longtemps. Une
## palette recopiée est une palette qui dérive : on corrige une teinte d'un
## côté, l'autre reste, et personne ne voit l'écart parce que chaque moitié
## paraît juste.
##
## ## Le principe : deux familles de lumière, qui ne se mélangent pas
##
## **Le MONDE est chaud.** Halogène, feu, sang — tout ce que la torche révèle.
## **L'APPAREIL est LED.** Froid, étroit, émis — tout ce que le matériel affiche.
##
## Le joueur apprend à lire cette différence sans qu'on la lui dise : si c'est
## chaud, c'est le monde ; si c'est LED, c'est son équipement. C'est la même
## discipline que le reste du jeu — la lumière porte l'information, elle ne
## décore pas.
##
## ## Les règles dures
##
## 1. **Aucune couleur au-dessus de 75 % de saturation.** Le 100 % est la
##    signature du « personne n'a choisi » : c'est ce que rend un sélecteur de
##    couleur qu'on n'a pas touché.
## 2. **Aucune primaire, aucune valeur pure — sauf `NOIR`.** Son exception est
##    mécanique et non esthétique : l'écran de calibration mesure le point de
##    noir du joueur **sur ce noir-là**. Un noir relevé décalerait tous les
##    joueurs du même côté, invisiblement.
## 3. **Le vert n'existe jamais dans l'arène.** Aucune lumière, aucune
##    particule, aucun décor. C'est la seule règle de la charte qui se contrôle
##    mécaniquement plutôt qu'à l'œil : un pixel vert dans une capture est donc
##    toujours de l'interface.
## 4. **Les dérivées sont des formules, jamais des choix.** Elles sont écrites
##    en littéral parce que GDScript ne sait pas appeler `lerp()` dans une
##    constante — et `tools/test_charte.gd` recalcule chacune depuis les sept à
##    chaque exécution. Le littéral ne peut donc pas s'éloigner de sa formule
##    sans que le lot passe au rouge.
##
## Ce fichier ne référence **aucun autoload** : il se `preload` sans danger
## depuis n'importe où, y compris depuis une suite lancée en `--script`.

# =============================================================================
# LES SEPT — famille MONDE (chaud, ce que la torche révèle)
# =============================================================================

## Le noir du monde. Seule valeur pure de toute la charte, et c'est la
## calibration qui l'exige — voir la règle 2.
const NOIR := Color(0.0, 0.0, 0.0)

## Le faisceau, et tout blanc cassé. Remplace chaque `Color(1, 1, 1)` du dépôt,
## à commencer par le liseré des murs — le blanc pur y disait « rien n'a été
## décidé » sur l'élément le plus vu du jeu. Chaud parce que toute source de
## lumière de Candela est une flamme ou un filament : à 18 % de saturation, une
## arête éclairée a la température d'une lampe torche, pas celle d'un néon.
const HALOGENE := Color(0.98, 0.91, 0.80)

## Le feu, et la mise en garde. Double emploi assumé, et c'est le brief qui le
## justifie : l'ambre est la couleur de ce qui brûle **et** la couleur d'alerte
## de tous les tableaux de bord du monde. Torche, flash de bouche, balle,
## braise ; puis titres, code de salon, chrono de dernière minute.
const AMBRE := Color(0.96, 0.69, 0.24)

# =============================================================================
# LES SEPT — famille APPAREIL (LED, ce que l'équipement émet)
# =============================================================================

## La diode « prêt ». La seule couleur ajoutée par la révision tactique, et elle
## paie une confusion qui existait : le code écrivait `GOLD if success else
## WARN`, deux orangés voisins portant des sens **opposés**, lus à 12 px dans le
## noir. La triade d'instrument — vert, ambre, rouge — les sépare pour de bon.
const VERT := Color(0.38, 0.90, 0.50)

## Soi. Convention *blue force* : sur un affichage tactique, le bleu est
## toujours celui qui regarde l'écran. Ce n'est pas une teinte choisie ici — la
## décision actée du 2026-08-19 disait déjà « la couleur suit le RÔLE, pas le
## numéro », ce qui **est** le suivi de force bleue. Seule la saturation change,
## de 100 % à 70 % : le cyan d'arcade devient une diode.
const BLEU := Color(0.29, 0.72, 0.97)

## L'autre, et la faute. Convention *red force*, et par extension tout ce qui
## détruit — quitter, abandonner, refuser.
##
## ⚠️ **Ne porte jamais de texte courant.** Son contraste sur `SURFACE` vaut
## 4,9:1 : suffisant pour un libellé de bouton ou un verdict en gros, insuffisant
## pour une phrase à 12 px.
const ROUGE := Color(0.95, 0.29, 0.33)

## Le boîtier de l'appareil — filets, cadres, accent d'interface.
##
## **C'est la couleur qui manquait, et son absence avait déjà coûté.** Le
## 2026-08-18, les entrées « lanceur » se confondaient avec le liseré de
## sélection : les deux portaient la couleur d'un joueur. On avait traité le
## symptôme (les lanceurs ne teintent plus leur fond) sans traiter la cause —
## **l'interface n'avait pas de couleur à elle et empruntait celle de quelqu'un.**
## `ACIER` la lui donne, et n'introduit pas une quatrième teinte : c'est le noir
## des panneaux, monté en luminance.
const ACIER := Color(0.70, 0.76, 0.82)

# =============================================================================
# LES DÉRIVÉES — des formules, pas des couleurs de plus
# =============================================================================
#
# Chaque littéral ci-dessous est le résultat de l'opération écrite en commentaire.
# `tools/test_charte.gd` les recalcule et compare : une valeur retouchée à la
# main sans sa formule fait rougir le lot.
#
# ⚠️ **Les facteurs portent sur les trois canaux, jamais sur l'opacité.** En
# GDScript, `ROUGE * 0.58` assombrit **et** rend à moitié transparent : une teinte
# baissée n'est pas une teinte effacée, et les dérivées ci-dessous sont opaques.
# Relevé par le banc à son premier lancement, ce qui vaut mieux que de le
# découvrir sur une tache de sang qu'on voit à travers.

## `ROUGE * 0.58` — le sang. Le rouge hostile, sous la lumière qu'il a coûtée :
## c'est la même couleur que l'adversaire, vue à l'intensité d'une chose qui ne
## s'éclaire plus elle-même. Remplace les `Color(0.9, 0, 0)` et `Color(0.5, 0, 0)`
## qui traînaient dans `bullet.gd` et `blood_stain.gd`.
const CARMIN := Color(0.551, 0.1682, 0.1914)

## `AMBRE × 2,6`, opacité rendue — le cœur d'une balle, et lui seul.
##
## **Une couleur qui sort du cube [0, 1], délibérément.** Godot laisse passer les
## valeurs supérieures à 1 sur un matériau additif : c'est ce qui donne au trait
## de la balle sa surexposition, l'impression d'un métal en fusion plutôt que
## d'un trait jaune. La teinte reste exactement celle de l'ambre — seule
## l'intensité déborde —, sans quoi la balle serait la seule chose du jeu à
## brûler d'une autre couleur que le feu.
const AMBRE_INCANDESCENT := Color(2.496, 1.794, 0.624)

## `ACIER * 0.70` — texte secondaire, entrées inactives, unités.
const DIM := Color(0.49, 0.532, 0.574)

## `NOIR` monté vers `ACIER` à 27 % — filets et bordures au repos.
const LINE := Color(0.189, 0.2052, 0.2214)

## `NOIR` monté vers `ACIER` à 8 %, alpha 0,92 — fond des panneaux.
const SURFACE := Color(0.056, 0.0608, 0.0656, 0.92)

## `NOIR` monté vers `ACIER` à 2 %, alpha 0,96 — fond d'un écran de hub. Moins
## opaque que le noir du jeu : on doit sentir qu'il y a un monde derrière.
const BACKDROP := Color(0.014, 0.0152, 0.0164, 0.96)

## `NOIR` monté vers `ACIER` à 14,5 % et 30 % — les deux sols du damier, et
## leurs arêtes. Froids, parce qu'un sol n'émet rien : il attend la torche.
const SOL_A := Color(0.1015, 0.1102, 0.1189)
const SOL_A_ARETE := Color(0.126, 0.1368, 0.1476)
const SOL_B := Color(0.21, 0.228, 0.246)
const SOL_B_ARETE := Color(0.266, 0.2888, 0.3116)

## `HALOGENE * K_ADVERSAIRE` — l'adversaire, vu depuis l'autre écran.
##
## ⚠️ **La seule dérivée qui touche à l'ÉQUITÉ, donc la seule qui ne se retouche
## pas à l'œil.** C'est la valeur à laquelle on voit quelqu'un dans le noir : la
## baisser rend l'adversaire plus dur à repérer, la monter le trahit.
##
## Le coefficient n'est donc pas choisi, il est **résolu** : c'est celui pour
## lequel la luminance perceptuelle de cette couleur égale exactement celle du
## gris neutre qu'elle remplace (`Color(0.7, 0.7, 0.7)`). Seule la température
## change — l'adversaire prend la teinte de la lampe qui le révèle au lieu de
## rester gris sous une lumière chaude — et **la quantité de lumière ne bouge
## pas d'un centième**. `tools/test_charte.gd` compare les deux luminances.
##
## Un premier jet posait `HALOGENE * 0.70` en affirmant cette égalité dans son
## propre commentaire. Elle était fausse de 8 % : le gris part d'une luminance de
## 1,0, l'halogène de 0,917. C'est le calcul qui l'a dit, pas la relecture.
const K_ADVERSAIRE := 0.76341
const ADVERSAIRE := Color(0.748142, 0.694703, 0.610728)

# =============================================================================
# ALIAS DE RÔLE — pour que les sites d'appel disent l'intention, pas la teinte
# =============================================================================

## Ce qui va, ce qui est prêt, ce qui a réussi.
const ETAT_OK := VERT
## Ce qui demande attention sans être une faute.
const ETAT_ATTENTION := AMBRE
## Ce qui a échoué, ce qui détruit.
const ETAT_FAUTE := ROUGE

# =============================================================================
# TYPOGRAPHIE — une échelle de six, et plus une taille arbitraire
# =============================================================================
#
# Le dépôt portait **25 tailles distinctes**, de 10 à 140, aucune issue d'une
# règle. Six suffisent, et le fait qu'elles suffisent est la démonstration :
# une taille qu'on ne peut pas ranger dans l'échelle est presque toujours une
# taille qu'on n'avait pas décidée.
#
# Rapport ≈ 1,27 entre les quatre premières, puis deux sauts d'affiche.

## Mentions, badges, unités, méta d'une vignette.
const T_MENTION := 12
## Texte courant : entrées de liste, libellés de bouton, phrases d'explication.
const T_COURANT := 15
## Valeurs qu'on lit du coin de l'œil : chiffres du HUD, sous-titres.
const T_APPUI := 19
## Titre d'écran.
const T_TITRE := 25
## Verdicts, FATAL, chiffres de dégâts au plafond.
const T_VERDICT := 42
## L'enseigne : le titre du jeu, les verdicts pleins, le mot FATAL.
const T_ENSEIGNE := 68

## Le décompte 3-2-1, et rien d'autre.
##
## **Ce n'est pas une septième taille, c'est une dérivée** — et la distinction
## vaut d'être faite, parce qu'une échelle qui s'allonge d'un cran « juste pour
## ce cas-là » a cessé d'être une échelle. Un chiffre seul qui occupe l'écran
## n'est pas du texte : c'est un élément graphique dont la taille est *deux fois
## l'enseigne*, par construction. `tools/test_charte.gd` vérifie le rapport.
const T_DECOMPTE := T_ENSEIGNE * 2

## L'enseigne et les verdicts : *Big Shoulders Display*, signalétique
## industrielle ultra-condensée, variable de Thin à Black. C'est le lieu.
const CHEMIN_DISPLAY := "res://assets/fonts/BigShouldersDisplay.ttf"
## Tout le reste : *Oxanium*, linéale anguleuse à chanfreins, variable elle
## aussi. C'est l'appareil.
##
## **Elle a été choisie par une mesure, pas par goût.** Le premier candidat
## (Chakra Petch) portait le récit aussi bien, et ses chiffres ne sont **pas
## tabulaires** : `0` fait 12 px, `1` en fait 6,9 — un chrono qui saute à chaque
## seconde. Poser `opentype_features = {"tnum": 1}` dessus **ne change rien et ne
## dit rien**, la fonte n'ayant pas la fonctionnalité. Oxanium, elle, est
## tabulaire **par construction** : les dix chiffres font 11 px pile, sans
## drapeau à poser. Une propriété qui n'a pas d'interrupteur ne peut pas être
## éteinte par mégarde.
##
## **Elle est aussi posée en `gui/theme/custom_font` dans `project.godot`**, et
## c'est là que se trouve le vrai levier de la passe typographique : Godot donne
## cette fonte par défaut à **tout `Control` de l'arbre**. C'est le seul réglage
## qui atteigne les écrans construits ailleurs qu'à la main — boîtes de dialogue,
## éditeur de cartes, panneau F3 — c'est-à-dire précisément ceux que personne ne
## pense à visiter, et donc ceux où la fonte par défaut se serait vue.
##
## ⚠️ **L'explication vit ici et pas dans `project.godot` : Godot réécrit ce
## fichier à chaque enregistrement et en efface les commentaires.** Le premier
## jet en portait douze lignes ; elles ont disparu au premier lancement de
## l'éditeur, sans que rien ne le signale. Un commentaire dans un fichier
## regénéré est un commentaire qu'on écrit pour soi.
const CHEMIN_UI := "res://assets/fonts/Oxanium.ttf"

## Le tag OpenType `wght`, en entier.
##
## ⚠️ **`variation_opentype` ignore les clés en chaîne, sans le dire.**
## `{"wght": 900}` se relit correctement dans la propriété — le dictionnaire
## contient bien ce qu'on y a mis — et **ne change pas un pixel du rendu**.
## Seul le tag entier agit : mesuré sur « CANDELA » en 40 px, 75 px de large avec
## la chaîne quelle que soit la graisse, 75 → 131 px avec l'entier.
##
## C'est la même famille de piège que `tnum` ci-dessus, et que les noms de nœuds
## auto-générés de la Phase 3 : **on écrit quelque chose de correct, rien ne
## proteste, et l'effet n'a pas lieu.** `tools/test_charte.gd` vérifie que cette
## constante vaut bien `name_to_tag("wght")`, et surtout **qu'une graisse haute
## rend une chasse différente d'une graisse basse** — le seul contrôle qui
## distingue « l'axe est appliqué » de « l'axe est écrit ».
const TAG_WGHT := 2003265652

## Graisses employées, sur l'axe variable des deux fontes.
##
## C'est ce qui retire du dépôt son dernier faux gras : `menu_hub.gd` posait
## `variation_embolden = 1.2` sur la fonte par défaut, avec ce commentaire —
## « le projet n'a pas de police à poids multiples ». Il en a deux.
const POIDS_COURANT := 400
const POIDS_APPUI := 600
const POIDS_DISPLAY := 700
const POIDS_ENSEIGNE := 800


static func _variation(chemin: String, poids: int) -> Font:
	if not ResourceLoader.exists(chemin):
		return null
	var base := load(chemin) as Font
	if base == null:
		return null
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TAG_WGHT: poids}
	return v


## La fonte d'interface, à la graisse demandée. `null` si le fichier manque.
##
## Règle du dépôt, « câbler, taire, diagnostiquer » : un appelant qui reçoit
## `null` ne pose pas d'override et Godot rend la fonte par défaut. Le jeu reste
## lisible, et l'absence se lit au panneau F3 plutôt qu'en erreur.
static func police_ui(poids: int = POIDS_COURANT) -> Font:
	return _variation(CHEMIN_UI, poids)


## La fonte d'affichage, à la graisse demandée.
static func police_display(poids: int = POIDS_DISPLAY) -> Font:
	return _variation(CHEMIN_DISPLAY, poids)


## Les fichiers de fonte attendus et absents. Vide = tout est là.
static func polices_manquantes() -> Array[String]:
	var out: Array[String] = []
	for c in [CHEMIN_DISPLAY, CHEMIN_UI]:
		if not ResourceLoader.exists(c):
			out.append(c)
	return out


# =============================================================================
# HABILLER UN CONTRÔLE — la fonte, la taille et la graisse posées ENSEMBLE
# =============================================================================
#
# **Le dépôt avait deux fontes et n'en portait qu'une.** DA1.2 a livré les deux
# fichiers, leurs licences, l'axe variable et sa vérification ; six jours plus
# tard `police_display()` n'était appelée que depuis **trois** sites, tous en
# espace-monde — `player.gd`, `bullet.gd`, `game_state.gd`. Les 5 000 lignes qui
# construisent les menus, le HUD, la killcam et l'écran de fin ne l'appelaient
# **jamais**. La fonte d'enseigne n'atteignait pas un seul écran.
#
# La cause n'est pas l'oubli, c'est l'ergonomie : poser une fonte demandait
# `add_theme_font_override` **plus** `add_theme_font_size_override` **plus** une
# `FontVariation` pour la graisse — trois gestes pour une intention. Personne ne
# fait trois gestes cinquante fois. Les deux fonctions ci-dessous en font un.
#
# C'est le même remède que la palette : ce n'est pas la discipline qui a tenu les
# 51 littérales, c'est d'avoir un nom plus court à écrire que la valeur.
#
# ## Les deux registres, et la mesure qui les sépare
#
# **`enseigne()` — ce qui s'écrit une fois.** CANDELA, FATAL, VICTOIRE, KILLCAM,
# le code de salon, le décompte. Du texte qui apparaît, se lit, et s'en va.
#
# **`appareil()` — tout le reste**, et en particulier **tout ce qui se remplace
# sur place**.
#
# ⚠️ **La frontière n'est pas une préférence, elle est mesurée, et l'écart est
# énorme.** `Big Shoulders Display` n'est pas tabulaire : à `T_VERDICT`, la
# chaîne `00:00` fait 83 px et `11:11` en fait **49** — 41 % de largeur en moins
# pour le même nombre de signes. Un chrono écrit dans cette fonte ne « saute »
# pas, il **tremble** : sa boîte change de largeur à chaque seconde.
#
# Pour mémoire, le défaut qui avait fait écarter *Chakra Petch* de la place de
# fonte d'interface en DA1.2 valait 12 px contre 6,9 sur un seul glyphe. Celui-ci
# est d'un autre ordre. **Ce n'est pas un défaut de la fonte** — une signalétique
# industrielle n'a aucune raison d'être tabulaire, et l'ultra-condensé qui fait
# sa personnalité est exactement ce qui l'en empêche. C'est un défaut d'emploi,
# et il ne peut se produire que d'un côté de la frontière.
#
# La règle mécanique qui en découle, vérifiée par `tools/test_habillage.gd` :
# **aucun compteur ne porte la fonte d'enseigne.** Le banc mesure les dix
# chiffres du `Control` réel plutôt que de lire quelle fonte on croit y avoir
# posée — c'est la seule formulation qui survive à un remplacement de fonte.
#
# Un chiffre qui varie n'est pas pour autant interdit d'enseigne : les nombres de
# dégâts de `bullet.gd` sont en display, et ils y sont bien. Ils naissent, ils
# montent, ils meurent — **aucun ne se substitue à un autre dans la même boîte**.
# Le critère n'est pas « est-ce un nombre », c'est « est-ce que ça se remplace
# sur place ».

## Les deux registres. Voir la note ci-dessus pour ce qui les sépare.
enum Registre {
	## LED, ce que l'appareil affiche : Oxanium, tabulaire, jusqu'à `POIDS_APPUI`.
	APPAREIL,
	## L'enseigne : Big Shoulders Display, condensée, à partir de `POIDS_DISPLAY`.
	ENSEIGNE,
}


## La graisse qui va avec une taille, dans un registre donné.
##
## **Une formule, pas un choix** — même discipline que les couleurs dérivées.
## Une graisse choisie au site d'appel est une graisse qui diverge : c'est
## exactement ainsi que le dépôt s'est retrouvé avec vingt-cinq tailles.
##
## Chacun des quatre poids a **un seul domicile**, et c'est ce qui rend la table
## lisible d'un coup d'œil : `POIDS_COURANT` et `POIDS_APPUI` sont à l'appareil,
## `POIDS_DISPLAY` et `POIDS_ENSEIGNE` à l'enseigne. Un poids employé des deux
## côtés ne dirait plus rien de l'endroit où on le lit.
##
## L'appareil **plafonne à `POIDS_APPUI`** : un tableau de bord ne crie pas. Le
## gras d'affiche appartient à l'enseigne, qui est là pour ça.
static func graisse_pour(taille: int, registre: Registre = Registre.APPAREIL) -> int:
	if registre == Registre.ENSEIGNE:
		return POIDS_DISPLAY if taille <= T_TITRE else POIDS_ENSEIGNE
	return POIDS_COURANT if taille <= T_COURANT else POIDS_APPUI


## Habille un `Control` : fonte d'enseigne, taille, et la graisse qui va avec.
##
## Pour les mots qui s'écrivent une fois. **Jamais pour un compteur** — voir la
## note de section, et `tools/test_habillage.gd` qui le refuse par la mesure.
static func enseigne(control: Control, taille: int, poids: int = -1) -> void:
	habiller_selon(control, taille, Registre.ENSEIGNE, poids)


## Habille un `Control` : fonte d'interface, taille, et la graisse qui va avec.
##
## Le registre par défaut de tout ce qui s'affiche. Ses chiffres sont tabulaires
## par construction, donc rien de ce qu'on lui confie ne peut trembler.
static func appareil(control: Control, taille: int, poids: int = -1) -> void:
	habiller_selon(control, taille, Registre.APPAREIL, poids)


## Habille un `Control` dans un registre calculé à l'exécution.
##
## Préférer [method enseigne] ou [method appareil] : elles **nomment** le choix à
## l'endroit où on le lit. Cette forme n'existe que pour le cas où le registre ne
## se connaît pas à l'écriture — `menu_engraver.gd` le tire de son gabarit, un
## code et une adresse IP passant par le même constructeur.
##
## ⚠️ **La taille se pose même quand la fonte manque, et l'ordre compte.**
##
## Règle du dépôt — « câbler, taire, diagnostiquer » : un fichier de fonte absent
## rend `null`, on ne pose alors aucun override de fonte et Godot sert la sienne.
## L'écran reste lisible et l'absence se lit au panneau F3, pas en erreur.
##
## Poser la taille malgré tout est ce qui fait la différence entre « la fonte
## manque » et « la mise en page a disparu » : sans elle, un dépôt sans polices
## rendrait tous ses écrans à la taille par défaut, c'est-à-dire illisibles, et
## l'on chercherait le défaut ailleurs que dans les deux fichiers manquants.
static func habiller_selon(control: Control, taille: int, registre: Registre,
		poids: int = -1) -> void:
	if control == null:
		return
	control.add_theme_font_size_override("font_size", taille)
	var g := poids if poids > 0 else graisse_pour(taille, registre)
	var f := (police_display(g) if registre == Registre.ENSEIGNE
		else police_ui(g))
	if f == null:
		return
	control.add_theme_font_override("font", f)


# =============================================================================
# RYTHME — la grille de 8
# =============================================================================
#
# Un seul pas, et un demi-pas toléré. Les espacements du dépôt allaient de 2 à
# 40 sans règle ; l'à-peu-près d'alignement ne se nomme pas quand on le voit,
# il se ressent comme « pas fini ».

## Le demi-pas. Le seul écart à la grille qui soit permis, et il ne sert qu'à
## coller deux lignes qui appartiennent à la même chose (un libellé et sa valeur).
const GAP_XXS := 4
const GAP_XS := 8
const GAP_S := 16
const GAP_M := 24
const GAP_L := 40
const GAP_XL := 64

# =============================================================================
# MOUVEMENT — trois courbes, trois durées, et rien d'autre
# =============================================================================
#
# **Ce sont des courbes maison, pas des `TRANS_*` de Godot.** Le dépôt utilisait
# cinq transitions différentes et douze durées ; le résultat est un jeu
# « tweené », où chaque animation a été réglée seule. Trois courbes utilisées
# partout donnent une signature — c'est-à-dire la sensation que la même main a
# animé tout l'écran.
#
# Chacune est une Bézier cubique, évaluée par `courbe()`. Pures et sans nœud,
# donc vérifiables en headless : `tools/test_charte.gd` contrôle leurs bornes,
# leur monotonie là où elle est due, et le dépassement du rebond.

enum Courbe {
	## L'allumage — part vite, s'installe longuement. Ce qui arrive à l'écran.
	ENTREE,
	## L'extinction — traîne puis file. Ce qui s'en va.
	SORTIE,
	## Le déclic — un seul dépassement, net, sans oscillation. Ce qu'on presse.
	REBOND,
}

## 90 ms — le retour d'un appui. En dessous, le geste paraît ignoré ; au-dessus,
## il paraît mou.
const D_COURT := 0.09
## 180 ms — une traversée d'écran, un panneau qui change.
const D_MOYEN := 0.18
## 300 ms — ce qu'on a le droit de regarder : une révélation, un verdict.
const D_LONG := 0.30

const _POINTS := {
	Courbe.ENTREE: [0.16, 0.84, 0.24, 1.0],
	Courbe.SORTIE: [0.55, 0.0, 0.85, 0.30],
	Courbe.REBOND: [0.34, 1.56, 0.44, 1.0],
}


## Évalue une courbe de la charte en `t ∈ [0, 1]`.
##
## Rend une valeur qui peut **dépasser 1** pour `REBOND` : c'est le dépassement,
## et c'est voulu. Un appelant qui borne le résultat retire ce qui fait la courbe.
static func courbe(quelle: Courbe, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var p: Array = _POINTS[quelle]
	return _bezier_y(t, p[0], p[1], p[2], p[3])


## Interpole entre deux valeurs le long d'une courbe de la charte.
##
## `Variant` plutôt qu'un type : les mêmes trois courbes servent aux couleurs,
## aux positions et aux échelles, et écrire trois fonctions ferait diverger les
## trois — exactement ce que ce fichier existe pour empêcher.
static func interpoler(depart: Variant, arrivee: Variant, quelle: Courbe, t: float) -> Variant:
	return lerp(depart, arrivee, courbe(quelle, t))


## Anime une propriété le long d'une courbe de la charte.
##
## Godot n'expose pas d'interpolateur personnalisé sur `Tween` : passer par
## `tween_method` est le seul chemin qui applique une vraie courbe maison plutôt
## que la `TRANS_*` la plus proche. Rend le `Tweener` pour qu'un appelant puisse
## l'enchaîner comme d'habitude.
##
## ⚠️ **`set_indexed` et surtout pas `set`.** `tween_property` accepte les chemins
## de sous-propriété — `"modulate:a"`, `"position:x"` — et c'est ainsi que la
## moitié des animations du dépôt sont écrites. **`Object.set("modulate:a", …)`
## ne lève rien et ne fait rien** : il cherche une propriété portant ce nom
## littéral, ne la trouve pas, et se tait.
##
## Le premier jet employait `set`. Résultat : la colonne de gauche du hub restait
## à `modulate.a = 0` après chaque navigation — **tout un écran de menu
## invisible**, avec seulement le liseré de sélection encore à l'écran puisqu'il
## vit dans un nœud séparé. Aucune suite ne l'a vu ; c'est la **planche de
## contact** qui l'a montré, et c'est très exactement ce pour quoi elle existe.
static func animer(tween: Tween, objet: Object, propriete: String,
		depart: Variant, arrivee: Variant, duree: float,
		quelle: Courbe = Courbe.ENTREE) -> MethodTweener:
	var chemin := NodePath(propriete)
	var appliquer := func(t: float) -> void:
		if is_instance_valid(objet):
			objet.set_indexed(chemin, interpoler(depart, arrivee, quelle, t))
	return tween.tween_method(appliquer, 0.0, 1.0, duree)


# --- Bézier cubique ----------------------------------------------------------
#
# Les points de contrôle sont exprimés comme en CSS : `x1, y1, x2, y2`, les
# extrémités étant fixées en (0,0) et (1,1). Il faut donc retrouver le paramètre
# de la courbe depuis l'abscisse avant de lire l'ordonnée — Newton d'abord,
# bissection en filet parce que Newton décroche là où la tangente s'aplatit,
# c'est-à-dire précisément aux deux bouts d'une courbe d'animation.

const _NEWTON_PASSES := 6
const _EPSILON := 1e-6

static func _bezier_axe(t: float, a1: float, a2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * t * a1 + 3.0 * u * t * t * a2 + t * t * t


static func _bezier_pente(t: float, a1: float, a2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * a1 + 6.0 * u * t * (a2 - a1) + 3.0 * t * t * (1.0 - a2)


static func _bezier_y(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var t := x
	for _i in _NEWTON_PASSES:
		var ecart := _bezier_axe(t, x1, x2) - x
		if absf(ecart) < _EPSILON:
			return _bezier_axe(t, y1, y2)
		var pente := _bezier_pente(t, x1, x2)
		if absf(pente) < _EPSILON:
			break
		t -= ecart / pente
	var bas := 0.0
	var haut := 1.0
	t = x
	while haut - bas > _EPSILON:
		if _bezier_axe(t, x1, x2) < x:
			bas = t
		else:
			haut = t
		t = (bas + haut) * 0.5
	return _bezier_axe(t, y1, y2)
