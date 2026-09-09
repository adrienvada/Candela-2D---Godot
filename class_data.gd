class_name ClassData
extends WeaponData

## Une classe jouable — chantier CLASSES, étape 1.
##
## ## Pourquoi ClassData HÉRITE de WeaponData au lieu d'en porter une
##
## Le premier jet composait : une classe *contenait* une arme. Deux raisons de
## ne pas le faire, et la seconde décide.
##
## 1. `player.equip_weapon(weapon)`, `game_state.weapon_for_index()`,
##    `rpc_spawn_bullet(..., weapon_idx)` et `bullet.gd` prennent tous une
##    `WeaponData`. Composer aurait obligé à écrire `classe.arme` sur chaque site
##    — de la plomberie pure, pour rien.
## 2. Surtout : **les quatre armes existantes n'ont pas été recopiées.** Leurs
##    quatre blocs impératifs de `game_state._ready()` sont restés mot pour mot ;
##    seul `WeaponData.new()` est devenu `ClassData.new()`. Une copie garantit
##    que deux nombres restent égaux, jamais qu'ils veulent dire la même chose —
##    le dépôt l'a écrit noir sur blanc, et l'hériter était le seul moyen de ne
##    pas recopier.
##
## ## Le slug, et le fait qu'il n'y en ait qu'UN
##
## `slug()` est hérité de `WeaponData` et rend `torch_cookie`. Une classe nomme
## donc d'un seul mot son cookie (`assets/torche/cookie_<slug>.png`), son sprite
## (`assets/sprites/<slug>.png`), ses sons (`assets/audio/weapons/`) et son icône
## (`MenuIcones.PAR_ARME`). C'est volontairement rigide : le fichier parent
## explique pourquoi deux slugs finissent toujours par diverger en silence.
##
## ⚠️ **Conséquence assumée pour les six classes neuves** : tant que leurs
## planches n'existent pas, `_poser_sprite()` crie et rend `false`, et
## `get_torch_texture()` crie et rend `null`. C'est le comportement voulu — un
## repli plausible redonnerait un disque ou un carré lumineux, c'est-à-dire
## exactement ce qu'on remplace, et le seul diagnostic possible depuis l'écran
## serait « ça n'a pas changé ».

## Le nom affiché. Il se traduit et se renomme ; le slug non.
@export var libelle: String = ""

## La catégorie de rang qui attribue cette classe en compétitif, de 1 (Aveugle)
## à 10 (Candela).
##
## ⚠️ **C'est une donnée d'AFFICHAGE et de contrôle, pas la table.** La table
## vit dans `rank_loadout.gd`, elle est saisonnière et se remplace sans toucher
## à quoi que ce soit d'autre. Ce champ existe pour qu'une suite puisse vérifier
## que les deux disent la même chose — deux vérités qui divergeraient en silence
## seraient pires qu'une seule.
@export var rang: int = 0

## ⚠️ **Les trois types passent par `preload`, pas par leur identifiant global.**
## En mode `--script` le cache des classes globales n'existe pas encore : un
## `@export var root: RootProfile` rend « Could not resolve external class member »
## et le fichier entier cesse de compiler — donc `tools/test_classes.gd` aussi.
## Le piège est celui que `tools/test_arsenal.gd` contourne déjà de son côté, et
## il mord ici parce que ce fichier est destiné à être chargé par des suites.
const RootProfileT := preload("res://root_profile.gd")
const FlareProfileT := preload("res://flare_profile.gd")
const GadgetProfileT := preload("res://gadget_profile.gd")

## L'immobilisation qui suit le tir.
@export var root: RootProfileT

## La réserve de fusées éclairantes.
@export var fusees: FlareProfileT

## Le gadget unique de la classe.
@export var gadget: GadgetProfileT


## Les trois profils sont-ils là ?
##
## Une classe sans profil n'est pas un cas dégradé, c'est un crash différé : le
## premier `classe.root.duree` sur un `null` arrête la manche. Les appelants
## vérifient une fois, au montage du catalogue, plutôt que partout.
func est_complete() -> bool:
	return root != null and fusees != null and gadget != null


## Le chemin du cookie de torche de cette classe, dérivé du slug.
##
## Redit ici ce que `WeaponData.get_torch_texture()` construit, et c'est le seul
## endroit où cette duplication est tolérée : elle sert aux CONTRÔLES, qui
## doivent pouvoir dire « ce fichier manque » sans monter une texture. Toute
## autre lecture passe par le parent.
func chemin_cookie() -> String:
	return "res://assets/torche/cookie_%s.png" % slug()


## Le chemin du sprite peint du joueur, dérivé du même slug.
func chemin_sprite() -> String:
	return "res://assets/sprites/%s.png" % slug()


## Cette classe est-elle jouable en l'état — tous ses assets présents ?
##
## Sert au catalogue et aux suites, jamais à choisir un repli : une classe
## incomplète doit être visible comme telle, pas remplacée en douce.
func assets_presents() -> bool:
	return ResourceLoader.exists(chemin_cookie()) and ResourceLoader.exists(chemin_sprite())
