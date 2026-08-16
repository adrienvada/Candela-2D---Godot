class_name HubScreen
extends Control

## Contrat d'un écran du hub — et la raison pour laquelle il existe.
##
## Avant la Phase 5, toute l'interface vivait dans `ui.gd` : 3 000 lignes, un
## seul fichier. Conséquence pratique qu'on ne mesure qu'en essayant de
## paralléliser : **une seule personne à la fois peut construire un écran**. Deux
## contributeurs sur deux écrans différents produisent un conflit à chaque
## poussée, parce que le découpage réel du travail suit les fichiers et non les
## sujets.
##
## Un écran par fichier lève ce blocage. C'est aussi, accessoirement, une
## meilleure architecture — mais ce n'est pas pour ça qu'on le fait.
##
## ## Le contrat
##
## Un écran est un `Control` autonome qui :
##
## - se construit **sans argument** et sans rien connaître de `ui.gd` ni du hub ;
## - remplit `body`, le conteneur que le hub lui donne, et rien d'autre de la
##   scène ;
## - demande ce dont il a besoin par **signal**, jamais en appelant un autre
##   écran : c'est ce qui permet de le tester seul, et de le déplacer dans
##   l'arborescence sans le réécrire ;
## - survit à `refresh()` appelé plusieurs fois d'affilée, y compris avant
##   d'avoir jamais été affiché.
##
## ## Ce qu'un écran ne fait jamais
##
## Il ne décide pas de la navigation. Un écran qui appellerait `MenuHub.push()`
## lui-même se lierait à sa position dans l'arborescence, et la déplacer
## coûterait une réécriture. Il émet `navigate_requested` ; le hub tranche.
##
## Il ne touche pas au réseau. `NetworkManager` et le transport restent hors de
## portée : la règle d'architecture du dépôt veut qu'aucun `if transport == …`
## n'existe hors de `network_manager.gd` et du bloc lobby.

## L'écran veut aller ailleurs. Le hub décide si c'est possible.
signal navigate_requested(screen_id: String)

## L'écran veut déclencher une action qui ne le regarde pas : lancer un match,
## quitter, ouvrir la galerie. L'hôte branche ce qu'il faut derrière.
signal action_requested(action: String, payload: Variant)

## Titre affiché dans l'en-tête du hub. Redéfini par chaque écran.
func screen_title() -> String:
	return "Écran"

## Construit le contenu dans `body`. Appelé une fois, à la déclaration.
##
## `body` appartient au hub : l'écran y ajoute ses enfants et ne touche ni à ses
## ancres, ni à sa visibilité — c'est le hub qui montre et cache.
func build(_body: VBoxContainer) -> void:
	pass

## Remet l'affichage en accord avec l'état du jeu. Appelé à chaque fois que
## l'écran redevient visible, et parfois avant qu'il ne l'ait jamais été.
##
## Doit être **idempotent** : deux appels de suite donnent le même résultat, et
## un appel sur un écran jamais construit ne plante pas. Sans cette garantie,
## l'ordre d'ouverture des écrans devient une dépendance cachée — celles qui ne
## se voient que sur la machine de quelqu'un d'autre.
func refresh() -> void:
	pass

## Le curseur doit-il se poser ici en priorité ? Rend le contrôle à viser, ou
## `null` pour laisser le hub choisir le premier venu.
func focus_seed() -> Control:
	return null
