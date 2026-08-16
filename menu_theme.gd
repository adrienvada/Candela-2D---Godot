class_name MenuTheme
extends RefCounted

## Palette et rythme de l'interface, en un seul endroit.
##
## Ces valeurs vivaient jusqu'ici en constantes privées de `ui.gd`. Le hub de la
## Phase 5 en a besoin aussi, et deux copies d'une palette divergent toujours :
## on corrige une teinte d'un côté, l'autre reste. Elles sont donc extraites ici
## avant que le second consommateur n'existe, pas après.
##
## `ui.gd` conserve ses constantes le temps de la Phase 5 étape 3, qui déplace
## l'existant sous le hub — les changer maintenant toucherait des centaines de
## lignes hors du périmètre de l'étape en cours.

# --- Couleurs ---------------------------------------------------------------

## Cyan du joueur 1. Sert aussi d'accent d'interface : c'est la couleur du
## curseur qui parcourt les menus.
const P1 := Color(0.0, 0.94, 1.0)
## Rouge du joueur 2, et des actions destructrices.
const P2 := Color(1.0, 0.0, 0.33)
## Or : les titres, et tout ce qui mérite d'être lu en premier.
const GOLD := Color(1.0, 0.8, 0.0)
## Texte secondaire, sous-titres, entrées inactives.
const DIM := Color(0.52, 0.55, 0.63)
## Avertissements qui ne sont pas des erreurs.
const WARN := Color(1.0, 0.45, 0.2)
## Filets et bordures au repos.
const LINE := Color(0.19, 0.2, 0.25)
## Fond des panneaux, légèrement translucide.
const SURFACE := Color(0.05, 0.055, 0.075, 0.92)

## Fond d'un écran de hub. Moins opaque que le noir du jeu : on doit sentir
## qu'il y a un monde derrière, même à l'arrêt.
const BACKDROP := Color(0.01, 0.012, 0.02, 0.96)

# --- Rythme -----------------------------------------------------------------

const GAP_XS := 8
const GAP_S := 16
const GAP_M := 24
const GAP_L := 40

# --- Transitions ------------------------------------------------------------

## Durée d'un fondu entre deux écrans. Court : une navigation qu'on attend est
## une navigation qu'on subit.
const FADE := 0.14
## Glissement latéral accompagnant le fondu, en pixels.
const SLIDE := 32.0
