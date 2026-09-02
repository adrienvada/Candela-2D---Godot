## Ce que l'`InputMap` dit des liaisons, lu et jamais recopié — DA4.11.
##
## **Ce fichier est ce qui reste de deux dessins abandonnés**, et c'est la partie
## qui valait la peine. DA4.11 a d'abord livré un clavier dessiné par le code,
## puis deux claviers recadrés par joueur ; Adrien a rejeté les deux à l'écran —
## *« beaucoup trop le bordel »*, puis *« ni beau ni clair »* — et la rubrique
## est devenue une liste.
##
## ⚠️ **L'argument du dessin était juste, et il l'est resté jusqu'au bout.** Voir
## où tombe le doigt vaut mieux que lire un nom. Ce qui l'a tué n'est pas
## l'argument mais **l'encombrement** : dessiner un appareil demande de la place,
## et cette place ne vient pas gratuitement dans une rubrique qui doit aussi
## porter neuf lignes réglables par joueur. *Un raisonnement correct sur une
## contrainte oubliée donne une réponse fausse*, et seul l'écran le dit.
##
## Ce qui survit n'est donc pas du dessin : ce sont les **mesures** qu'il avait
## fallu écrire pour dessiner juste, et qui restent vraies sans lui.
##
## ## Les touches se lisent, jamais ne se recopient
##
## Une table de touches écrite dans un fichier serait juste le jour de son
## écriture et mentirait à la première réassignation — **sans erreur, et sur
## l'écran même qui sert à réassigner.**
##
## ## Positionnel au fond, localisé à l'affichage
##
## `project.godot` lie par `physical_keycode` : la touche « haut » de J1 est le
## `W` d'un QWERTY, qui est **physiquement le Z** d'un AZERTY. Tout ce qui
## compare travaille donc sur la position ; seul l'affichage traduit, par
## `dans_la_disposition()`. Afficher « W » à Adrien serait exact du point de vue
## du code et faux du point de vue de sa main.

class_name Liaisons
extends RefCounted

# ---------------------------------------------------------------------------
# CE QUE L'INPUT MAP DIT — jamais une table recopiée
# ---------------------------------------------------------------------------

## Le code physique lié à une action, ou `0` si elle n'est pas au clavier.
##
## ⚠️ **`physical_keycode` d'abord.** Une liaison posée par le joueur au
## réassignement peut n'avoir qu'un `keycode` ; on retombe dessus, mais l'ordre
## compte : lire `keycode` en premier ferait dessiner la lettre plutôt que la
## position, et le clavier mentirait sur un AZERTY.
static func code_physique_de(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var t: InputEventKey = ev
			return t.physical_keycode if t.physical_keycode != 0 else t.keycode
	return 0


## Quel joueur occupe quelle touche : `{code_physique: index_joueur}`.
##
## ⚠️ **Rend aussi les COLLISIONS.** Si deux joueurs se retrouvent sur la même
## touche, la seconde écrase la première dans le dictionnaire — et
## `collisions()` la nomme séparément, parce qu'une touche partagée n'est pas un
## détail d'affichage : c'est deux joueurs qui ne peuvent pas jouer ensemble.
static func occupation(par_joueur: Dictionary) -> Dictionary:
	var out := {}
	for j: int in par_joueur.keys():
		for action: String in par_joueur[j]:
			var code := code_physique_de(action)
			if code != 0:
				out[code] = j
	return out


## Les touches revendiquées par les DEUX joueurs. Vide = personne ne se gêne.
static func collisions(par_joueur: Dictionary) -> Array[int]:
	var vu := {}
	var fautives: Array[int] = []
	for j: int in par_joueur.keys():
		for action: String in par_joueur[j]:
			var code := code_physique_de(action)
			if code == 0:
				continue
			if vu.has(code) and vu[code] != j and not fautives.has(code):
				fautives.append(code)
			vu[code] = j
	return fautives


## Le libellé d'un capuchon, dans la disposition du joueur.
##
## ⚠️ **Traduit, jamais supposé.** `KEY_W` est une POSITION ; sur le clavier
## d'Adrien cette position porte un **Z**. Afficher « W » serait exact du point
## de vue du code et faux du point de vue de sa main.
static func libelle_de(code_physique: int) -> String:
	match code_physique:
		KEY_UP: return "▲"
		KEY_DOWN: return "▼"
		KEY_LEFT: return "◀"
		KEY_RIGHT: return "▶"
		KEY_SPACE: return "ESPACE"
	return OS.get_keycode_string(dans_la_disposition(code_physique))


## Le code tel que la disposition du joueur l'imprime sur son capuchon.
##
## ⚠️ **Sans serveur d'affichage, il n'y a pas de disposition à traduire.**
## `keyboard_get_keycode_from_physical()` n'existe pas en headless : appelée
## quand même, elle rend zéro **et journalise une erreur à chaque touche**. Six
## lignes rouges par lancement de banc pour une situation parfaitement normale —
## et un banc qui imprime des erreurs apprend à les ignorer, ce qui coûte le
## jour où l'une d'elles compte. On demande donc d'abord s'il y a un clavier à
## interroger.
static func dans_la_disposition(code_physique: int) -> int:
	if DisplayServer.get_name() == "headless":
		return code_physique
	var local := DisplayServer.keyboard_get_keycode_from_physical(code_physique)
	return local if local != 0 else code_physique


