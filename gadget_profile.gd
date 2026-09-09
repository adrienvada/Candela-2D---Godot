class_name GadgetProfile
extends Resource

## Le gadget d'une classe — chantier CLASSES, étape 1.
##
## Sans dépendance, comme ses deux voisins : il décrit un gadget, il n'en
## instancie aucun. La scène est nommée par son CHEMIN et chargée par l'appelant,
## faute de quoi ce fichier tirerait tout l'arbre des gadgets dans chaque suite
## qui le charge en `--script`.
##
## ## Le drapeau d'éblouissement vit ici, et il vit PAR INSTANCE
##
## Adrien, 2026-09-09 : « on doit pouvoir désactiver l'éblouissement d'un gadget
## à l'avenir si on sent que ça équilibre ». `eblouit` est donc la valeur par
## défaut de la CLASSE ; le nœud posé la recopie à sa construction et peut en
## dévier. Trois raisons de ne pas s'arrêter au type :
##
## 1. ça ne coûte rien de plus — une variable posée au spawn, comme `is_replay`
##    et `graine` le sont déjà pour la fusée ;
## 2. ça couvre le cas « par type » sans effort, l'inverse étant faux ;
## 3. ça n'oblige pas à savoir aujourd'hui quels gadgets existeront.
##
## ⚠️ **Et surtout pas sur `WeaponData`** : la fusée, l'écho au sol d'un tir et
## les gadgets n'ont pas d'arme. Le drapeau appartient à la SOURCE de lumière,
## pas à ce qui la déclenche.

## Le slug du gadget — clé unique du sprite (`assets/sprites/gadget_<slug>.png`)
## et de l'icône (`assets/ui/icones/gadget_<slug>.png`). Sans accent ni majuscule,
## même règle que le slug de classe : « Arbalète » a déjà coûté cette leçon.
@export var slug: String = ""

## Libellé affiché. Séparé du slug, et c'est délibéré : celui-ci se traduit et se
## renomme, l'autre nomme des fichiers.
@export var libelle: String = ""

## Chemin du **script** du nœud posé. Vide tant que le gadget n'est pas écrit —
## ce qui est l'état normal des premières étapes, et qui doit se voir plutôt que
## se deviner. `est_livre()` répond à la question.
##
## ⚠️ **Un script, pas une `PackedScene`, et ce champ s'appelait `scene`.** Les
## gadgets se montent en code comme la fusée (`Fusee.new()`, puis les champs, puis
## `add_child`) — il n'y a pas de `.tscn` à charger, et il n'y en aura pas : une
## scène pour un `StaticBody2D` dont tous les enfants sont créés par `_ready()`
## n'aurait rien à décrire. Le nom `scene` promettait un fichier qui n'existe pas.
@export var implementation: String = ""

## Le désarmement qui suit la pose, en secondes.
##
## Même geste que `FuseeModele.DESARMEMENT` et pour la même raison : poser un
## objet occupe les mains. Il passe par le **cooldown de tir existant**, donc il
## n'est pas répliqué — il est simulé à l'identique chez l'hôte et dans la
## prédiction du client, comme le tir lui-même.
##
## ⚠️ **Constant, et non réglable par gadget.** Dix désarmements différents ne se
## distingueraient pas à la main tout en rendant chaque gadget incomparable —
## c'est l'argument qui a déjà fixé `RootProfile.RECUPERATION`.
const DESARMEMENT := 0.30

## Combien on peut en poser par manche.
@export var stock: int = 1

## Ce gadget peut-il éblouir ? Valeur par défaut de la classe, recopiée sur le
## nœud à sa construction. Faux pour tout ce qui n'émet pas de lumière.
@export var eblouit: bool = false

## Durée de vie en secondes, ou 0 pour « jusqu'à la fin de la manche ».
@export var duree_vie: float = 0.0

## Points de vie du gadget posé. Tous sont destructibles à la balle — c'est le
## contrat commun de `GadgetBase` — mais pas au même prix.
@export var pv: float = 1.0


## Le gadget a-t-il une scène ? Faux tant qu'il n'est pas écrit.
##
## ⚠️ **Aucun repli n'est prévu ailleurs pour un gadget absent.** Un gadget muet
## qui ne poserait rien se confondrait avec un gadget dont la touche ne marche
## pas ; c'est la règle « câbler, taire, diagnostiquer » du dépôt, et c'est
## l'appelant qui doit crier, pas ce fichier qui doit inventer.
func est_livre() -> bool:
	return not implementation.is_empty()


## Le chemin du sprite du gadget posé, dérivé du slug — une seule vérité.
func chemin_sprite() -> String:
	return "res://assets/sprites/gadget_%s.png" % slug


## Le chemin de l'icône d'interface, dérivé du même slug.
func chemin_icone() -> String:
	return "res://assets/ui/icones/gadget_%s.png" % slug
