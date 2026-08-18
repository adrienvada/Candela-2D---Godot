## La série de victoires consécutives d'une session, et ce qu'elle a à dire.
##
## Un fichier à elle, et pas trois fonctions de plus dans `game_state.gd` — pour
## une raison qui s'est manifestée à la première exécution. `game_state.gd`
## référence `NetworkManager` et `AudioManager` par leur nom d'autoload ; en mode
## `--script` ces noms ne résolvent pas, le fichier ne compile pas, et une suite
## qui le `preload` voit chacun de ses appels échouer. Pire : l'erreur **avorte
## la fonction de test sans incrémenter le compteur**, si bien que la suite
## annonce « tous les tests passent ». Seul le contrôle `SCRIPT ERROR` du
## lanceur l'attrape.
##
## La comptabilité d'une série ne dépend de rien : ni du réseau, ni de l'audio,
## ni de l'état d'un match. Ce qui ne dépend de rien se relit à froid, et doit
## pouvoir se tester à froid.
##
## Pourquoi une série, alors qu'un score de session existe déjà : « 3 - 2 » ne
## dit pas dans quel ORDRE. Trois victoires puis deux défaites, ou une
## alternance stricte, donnent le même affichage — et on ne se sent pas du tout
## dans la même partie. La série est exactement ce que le score ne peut pas dire.
extends RefCounted

## Personne ne porte la série : session neuve, ou série qui vient de tomber.
const PERSONNE := -1

## Fait avancer une série après un match. Rend (porteur, longueur).
##
## Une égalité tombe dans le même cas qu'une défaite : une série est faite de
## VICTOIRES consécutives, et laisser une nulle la prolonger reviendrait à dire
## qu'on n'a pas perdu — ce n'est pas la même fierté, et ce n'est pas ce que le
## mot promet.
static func apres(porteur: int, longueur: int, vainqueur: int) -> Vector2i:
	if vainqueur < 0:
		return Vector2i(PERSONNE, 0)
	if vainqueur == porteur:
		return Vector2i(porteur, longueur + 1)
	return Vector2i(vainqueur, 1)

## Ce que la série a à dire, après le score de session. Vide quand elle n'a rien
## à dire — **une « série de 1 » n'est pas une série, c'est un match gagné.**
## L'annoncer à chaque fin de match viderait le mot de son sens avant qu'il ait
## servi une seule fois.
##
## `local_idx` vaut -1 en écran partagé : il n'y a pas de « toi » à désigner
## quand les deux joueurs regardent le même écran, et la série se nomme alors
## par son joueur.
static func mot(porteur_avant: int, longueur_avant: int, vainqueur: int,
		local_idx: int) -> String:
	# Une série qui TOMBE se dit avant celle qui commence : perdre une série de
	# quatre est l'événement du match, pas le fait d'en ouvrir une de un.
	if longueur_avant >= 2 and vainqueur != porteur_avant:
		return "SÉRIE BRISÉE"
	var suite := apres(porteur_avant, longueur_avant, vainqueur)
	if suite.y < 2:
		return ""
	if local_idx < 0:
		return "SÉRIE J%d : %d" % [suite.x + 1, suite.y]
	return "SÉRIE : %d" % suite.y if suite.x == local_idx \
		else "SÉRIE ADVERSE : %d" % suite.y
