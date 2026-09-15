class_name MenuTheme
extends RefCounted

## Les noms d'interface de la charte — et rien d'autre.
##
## **Ce fichier ne décide plus de rien.** Il portait sa propre palette, en
## doublon de celle d'`ui.gd`, avec un commentaire promettant de réunir les deux
## « le temps de la Phase 5 étape 3 » — close depuis. Les deux copies avaient
## bien divergé entre-temps, comme il l'annonçait lui-même.
##
## Chaque constante est désormais un **alias** vers [Charte]. Elles subsistent
## parce que deux cents sites d'appel les nomment, et parce que `MenuTheme.DIM`
## dit à l'endroit où on le lit quelque chose que `Charte.ACIER * 0.7` ne dit
## pas : *le rôle*. Mais la valeur n'est plus ici, donc elle ne peut plus dériver.
##
## Écrire une couleur en dur dans ce fichier reviendrait à rouvrir exactement le
## défaut qu'il vient de fermer.

const C := preload("res://charte.gd")

# --- Couleurs ---------------------------------------------------------------

## Joueur 1, et soi : la convention *blue force*. Ce n'est plus l'accent
## d'interface — voir [constant ACCENT], qui existe précisément pour ça.
const P1 := C.BLEU
## Joueur 2, l'adversaire, et les actions destructrices.
const P2 := C.ROUGE
## L'accent d'interface, qui n'appartient à aucun joueur.
##
## **Son absence avait déjà coûté une correction.** Le 2026-08-18, les entrées
## « lanceur » se confondaient avec le liseré de sélection parce que les deux
## portaient `P1`. On avait retiré la couleur des lanceurs ; la cause restait —
## l'interface empruntait la couleur de quelqu'un faute d'en avoir une.
##
## **Habillage iso (2026-09-15) : l'accent est le papier, plus l'acier.** Même
## rôle — la couleur qui n'est à aucun joueur —, dans la pâte des planches :
## ce qui s'éclaire au survol s'éclaire comme le béton sous la torche.
const ACCENT := C.PATE_SURVOL
## Les titres, et tout ce qui mérite d'être lu en premier. Même teinte que le feu
## du jeu : dans un tableau de bord, l'ambre est la couleur de ce qui appelle.
const GOLD := C.AMBRE
## Texte secondaire, sous-titres, entrées inactives.
const DIM := C.PATE_TEXTE_SECOND
## Avertissement qui n'est pas une erreur.
##
## Alias d'`AMBRE`, et c'est la moitié d'une correction : le code écrivait
## `GOLD if success else WARN` — deux orangés voisins pour des sens opposés.
## L'autre moitié est aux sites d'appel, qui disent maintenant [constant OK] et
## [constant FAUTE].
const WARN := C.ETAT_ATTENTION
## Ce qui est prêt, ce qui a réussi.
const OK := C.ETAT_OK
## Ce qui a échoué.
const FAUTE := C.ETAT_FAUTE
## Filets et bordures au repos.
##
## ⚠️ **Depuis l'habillage iso, ces alias ne pointent plus vers les couleurs
## d'appareil du même nom** (`C.LINE`, `C.SURFACE`…), et c'est le cœur de la
## bascule : ces dernières sont lues par le jeu (`player.gd`, les voxels), les
## changer aurait repeint l'arène. L'interface change de rôles ; le jeu garde ses
## couleurs. Voir « LA PÂTE » dans `charte.gd`.
const LINE := C.PATE_FILET
## Fond des panneaux, légèrement translucide.
const SURFACE := C.PATE_FOND
## Fond d'un écran de hub. Moins opaque que le noir du jeu : on doit sentir
## qu'il y a un monde derrière, même à l'arrêt.
const BACKDROP := C.PATE_RIDEAU
## Le texte courant, et ce qui s'éclaire : le papier des planches.
const LUMIERE := C.PATE_TEXTE
## Le texte posé sur une plaque éclairée (survol, bouton principal).
const TEXTE_SUR_PAPIER := C.PATE_TEXTE_SUR_PAPIER
## Le filament : le cadre de ce qui est choisi, et les valeurs qu'on règle.
const FILAMENT := C.PATE_FILAMENT
## L'ombre portée d'une plaque.
const OMBRE := C.PATE_OMBRE

# --- Typographie ------------------------------------------------------------

const T_MENTION := C.T_MENTION
const T_COURANT := C.T_COURANT
const T_APPUI := C.T_APPUI
const T_TITRE := C.T_TITRE
const T_VERDICT := C.T_VERDICT
const T_ENSEIGNE := C.T_ENSEIGNE

# --- Rythme -----------------------------------------------------------------

const GAP_XXS := C.GAP_XXS
const GAP_XS := C.GAP_XS
const GAP_S := C.GAP_S
const GAP_M := C.GAP_M
const GAP_L := C.GAP_L

# --- Transitions ------------------------------------------------------------

## Durée d'un fondu entre deux écrans. Court : une navigation qu'on attend est
## une navigation qu'on subit.
const FADE := C.D_MOYEN
## Glissement latéral accompagnant le fondu, en pixels. Quatre pas de grille.
const SLIDE := 32.0
