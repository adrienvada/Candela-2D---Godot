class_name CanauxLumiere
## Les canaux de lumière des deux vues — un seul endroit, et sans autoload.
##
## Un `CanvasItem` n'est éclairé que par les lumières dont
## `range_item_cull_mask` croise son `light_mask`. Candela en fait un protocole :
##
## - `DECOR` (1) : sol, murs, décor — commun aux deux vues ;
## - `ENNEMI` (2) : les sprites « ennemis », LES DEUX (le mien chez lui, le sien
##   chez moi) — torche, reflet, tirs, bandeau LED ;
## - `JOUEUR_LOCAL` (4) : le sprite du joueur tel qu'il se voit ;
## - `canal_de_vue(id)` (16 pour la vue de J1, 32 pour celle de J2) : ce qui
##   n'appartient qu'à UNE vue — les copies de sol et de murs de ce joueur, et
##   son halo de proximité.
##
## ⚠️ **Ce fichier ne référence aucun autoload, et c'est sa raison d'être.**
## `player.gd` en nomme plusieurs : il ne compile ni dans une suite lancée en
## `--script`, ni depuis un gadget qui voudrait le nommer. La règle du halo vivait
## d'abord dans `player.gd` ; le leurre (`gadget_leurre.gd`) doit l'appliquer
## trait pour trait, et la session « 10 classes » l'a demandée ailleurs pour ne
## pas la recopier (2026-09-11). Une règle recopiée est une règle qui dérive.

const DECOR := 1
const ENNEMI := 2
const JOUEUR_LOCAL := 4

## Canal propre à la vue du joueur `id` : 16 pour J1, 32 pour J2.
static func canal_de_vue(id: int) -> int:
	return 16 << id

## Masque de lumière du sprite « ennemi » du joueur `id` — celui que voit
## l'AUTRE.
##
## Décision d'Adrien (2026-09-11) : « je veux que le halo révèle un ennemi
## proche. Attention, ma propre lueur ne doit pas me rendre détectable auprès de
## mon ennemi à distance. » Le canal `ENNEMI` est commun aux deux sprites
## ennemis : le halo ne pouvait l'éclairer sans éclairer aussi MON sprite sur SON
## écran, et il n'éclairait donc aucun ennemi. Le sprite ennemi de `id` porte en
## plus le canal de la vue ADVERSE : le halo de l'autre l'éclaire, chez l'autre
## seulement ; le mien, jamais. Tout corps qui se fait passer pour un joueur aux
## yeux de l'adversaire (le leurre) doit porter ce même masque.
## `tools/test_halo_proximite.tscn` garde les deux moitiés de la phrase.
static func masque_vue_adverse(id: int) -> int:
	return ENNEMI | canal_de_vue(1 - id)
