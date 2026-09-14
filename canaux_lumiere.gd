class_name CanauxLumiere
## Les canaux de lumière des deux vues — un seul endroit, et sans autoload.
##
## Un `CanvasItem` n'est éclairé que par les lumières dont
## `range_item_cull_mask` croise son `light_mask`. Candela en fait un protocole :
##
## - `DECOR` (1) : sol, murs, décor — commun aux deux vues ;
## - `ENNEMI` (2) : les sprites « ennemis », LES DEUX (le mien chez lui, le sien
##   chez moi) — torche, reflet, tirs ;
## - `JOUEUR_LOCAL` (4) : le sprite du joueur tel qu'il se voit ;
## - `canal_de_vue(id)` (16 pour la vue de J1, 32 pour celle de J2) : ce qui
##   n'appartient qu'à UNE vue — les copies de sol et de murs de ce joueur, et
##   son halo de proximité.
##
## Et, plus bas, une SECONDE famille — les couches d'OMBRE, qui disent qui bouche
## la lumière plutôt que qui la reçoit. Le bloc qui les introduit dit où les deux
## se rencontrent, et pourquoi il faut le savoir.
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


# ── Les couches d'OMBRE ──────────────────────────────────────────────────────
#
# Un second espace de noms. Les canaux ci-dessus se lisent dans `light_mask` et
# `range_item_cull_mask` : ils disent QUI est éclairé. Ceux qui suivent se lisent
# dans `occluder_light_mask` : ils disent QUI fait de l'ombre. Les deux règles
# restent écrites séparément : les faire dériver l'une de l'autre les marierait
# pour de bon, et un jour l'une devrait bouger seule.
#
# ⚠️ **Mais elles se CROISENT dans `shadow_item_cull_mask` — et ce bloc a affirmé
# le contraire jusqu'au 2026-09-14.** Le moteur y compare DEUX choses : le
# `occluder_light_mask` des occluders (qui fait de l'ombre) ET le `light_mask` des
# sprites (qui la REÇOIT). Un sprite dont le `light_mask` ne croise pas ce masque
# est éclairé en entier, occluder ou pas. C'est toute la différence entre la
# torche (`1 | 2 | corps adverse`, où 2 = `ENNEMI`) et le halo d'avant (`1`) :
# mesuré au banc, 7 % du corps adverse éclairé sous l'une, 100 % sous l'autre.
# Conséquence pratique : dans un masque d'ombre, 16 veut dire À LA FOIS « torse de
# J1 » pour un occluder et « vue de J1 » pour un sprite. Y mettre
# `canal_de_vue(id)` fait donc aussi ombrer le torse de `id` — voir
# `masque_ombre_halo()`, qui l'évite.

## La couche d'ombre du CORPS du joueur `id` : 4 pour J1, 8 pour J2.
##
## Deux couches distinctes parce qu'une torche doit ombrer le corps d'en face
## **sans ombrer le sien** — voir `player.gd`, qui pose ses propres occluders avec
## cette règle. Une couche commune rendait les deux indissociables : on ne pouvait
## qu'ombrer les deux ou aucun, et le jeu avait choisi aucun.
##
## ⚠️ **Tout corps qui se fait passer pour le corps de `id` la porte** — le leurre
## depuis le 2026-09-12 (décision d'Adrien : « oui, qu'il ait l'ombre d'un
## corps »). Sur la couche du décor, il faisait de l'ombre sous les lumières dont
## le masque d'ombre ne contient que le décor — fusée au sol, mine qui brûle,
## nappe de braises, halo de la torche fantôme, lumière d'impact —, là où AUCUN
## corps n'en fait : il suffisait d'éclairer la zone pour le démasquer.
static func couche_ombre_corps(id: int) -> int:
	return 4 << id

## La couche d'ombre du TORSE du joueur `id` : 16 pour J1, 32 pour J2.
##
## Réservée à la rétrodiffusion, seule lumière qu'un disque de torse arrête : le
## grand occluder du corps ne doit jamais la voir, sans quoi chaque joueur se
## tiendrait dans sa propre ombre. Le leurre la porte aussi — sans elle, la
## rétrodiffusion de l'adversaire le traverserait, ce qu'elle ne fait pour aucun
## corps, et c'était un indice de plus.
static func couche_ombre_torse(id: int) -> int:
	return 16 << id

## Le masque d'ombre du halo de proximité du joueur `id`.
##
## Demande d'Adrien (2026-09-14) : que toutes les sources lumineuses se
## comportent comme la lampe torche — la silhouette de l'ennemi éclairée, et qui
## « crée de l'ombre ». Sous la torche, le corps d'en face reste sombre, liseré
## du côté de la lampe, et projette son ombre ; sous le halo il était éclairé à
## plat, en entier, et s'additionnait au bandeau LED jusqu'au blanc.
##
## Trois bits, chacun pour une raison :
## - `DECOR` : les murs font ombre, comme avant ;
## - `ENNEMI` : pour que le sprite adverse REÇOIVE l'ombre (bloc ci-dessus).
##   ⚠️ Pas `canal_de_vue(id)`, qui y parvenait aussi : il vaut la couche du
##   torse de `id`, et ce torse, posé au centre même du halo, aurait ombré sa
##   propre lueur ;
## - le corps d'EN FACE, jamais le sien — sinon on se tiendrait dans sa propre
##   ombre.
##
## `ENNEMI` fait recevoir l'ombre aux DEUX sprites ennemis, mais le halo n'en
## éclaire qu'un (`range_item_cull_mask`) : « ma lueur ne me trahit pas à
## distance » tient toujours. `tools/test_halo_proximite.tscn` garde les deux.
static func masque_ombre_halo(id: int) -> int:
	return DECOR | ENNEMI | couche_ombre_corps(1 - id)
