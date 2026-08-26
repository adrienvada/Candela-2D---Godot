extends SceneTree

## La démarche tombe-t-elle avec le pas, et ment-elle sur la visée ? (DA2.4)
##
## **Ce banc surveille deux invariants qui ne se voient pas à l'écran** — l'un
## parce qu'il ne se manifeste qu'en changeant d'allure, l'autre parce qu'il se
## manifeste *tout le temps* et se lit donc comme du style.
##
## ## 1. Le roulis ne pivote jamais le sprite
##
## ⚠️ `rotation` dit où le joueur vise. C'est **l'information la plus chère du
## jeu** : toute la proposition de Candela est qu'on ne sait de l'adversaire que
## ce que la lumière en dit, et l'angle de son arme en fait partie. Une démarche
## qui inclinerait le sprite — ou une frame peinte avec l'arme pivotée —
## contredirait cet angle douze fois par seconde, et personne ne saurait dire
## pourquoi ses tirs partent à côté.
##
## Le piège est réel et il a failli passer : **ma première consigne au
## générateur demandait exactement ça** (« les bras et le fusil suivent les
## épaules »). Le générateur a obéi. C'est en regardant le résultat qu'on a vu
## que la consigne, pas le rendu, était fausse.
##
## ## 2. Le roulis se dérive du compteur de PAS, pas d'une horloge
##
## ⚠️ Le détecteur de pas compte une **distance** — 45 px — et non
## un temps. Le son du pas, l'empreinte au sol et la bosse de rétrodiffusion
## tombent déjà ensemble sur ce compteur. Une démarche cadencée par le temps
## dériverait de tout ça dès qu'on change d'allure. C'est aussi la raison pour
## laquelle quatre images fixes ne pouvaient pas convenir : rien à quoi les
## accrocher.
##
## *(Le sprint a été supprimé le 2026-08-26 ; il n'y a donc plus qu'une allure.
## Le contrôle qui exigeait que le roulis en tienne compte est retiré, mais
## l'ancrage sur la DISTANCE reste ce qui rend la démarche juste.)*
##
## ## Pourquoi lire le TEXTE
##
## Monter un `Player` en `--script` demanderait ses autoloads, son arène et une
## `MultiplayerAPI` ; le contrôle n'existerait alors pas du tout. Et c'est **par
## le texte** que ces deux défauts reviendraient : quelqu'un « améliorant » le
## roulis en y ajoutant une inclinaison, ou le recadençant sur `delta` parce que
## c'est le réflexe. Même motif que `test_torches.gd` et `test_charte.gd`.

var _echecs := 0
var _total := 0


func _init() -> void:
	var joueur := _lire("res://player.gd")
	if joueur == "":
		_vrai("player.gd lisible", false)
		_verdict()
		return

	_vrai("player.gd déclare une amplitude de roulis",
		joueur.contains("ROULIS_MARCHE"))
	_vrai("player.gd lisse le retour au repos",
		joueur.contains("ROULIS_RETOUR"))

	# ⚠️ **Le bloc doit être borné des DEUX côtés.** Premier jet : borné au
	# prochain `func`, il avalait la suite de `_physics_process` — laquelle
	# manipule `rotation` tout à fait légitimement, pour la visée. Le contrôle
	# « le roulis ne pivote rien » était donc rouge à l'état sain, et sur du code
	# qui n'était pas le sien. Un contrôle qui désigne le mauvais coupable ne
	# vaut pas mieux qu'un contrôle muet : on le débranche, et on perd les deux.
	#
	# La borne de fin est un repère qui existe déjà dans le fichier. S'il
	# disparaît, le bloc s'élargit et le banc **rougit** — jamais l'inverse.
	# C'est le bon sens de la panne : un faux rouge se voit, un faux vert non.
	var corps := _bloc(joueur, "DA2.4 — le corps roule sur le pied porteur",
		"# Visuals update for all clients")
	_vrai("le bloc de roulis existe", corps != "")
	if corps == "":
		_verdict()
		return

	# ⚠️ **L'invariant central.** Le roulis déplace, il n'incline pas.
	#
	# ⚠️ **Sur le CODE seul, commentaires retirés.** Premier jet de ce contrôle :
	# rouge d'emblée, parce que le commentaire qui explique *pourquoi* ne pas
	# pivoter contient le mot `rotation`. C'est le miroir exact du faux-vert
	# consigné le même jour : un contrôle textuel qui lit la prose mesure ce que
	# le code DIT de lui-même, pas ce qu'il fait.
	var code := _sans_commentaires(corps)
	_vrai("le roulis ne pivote rien", not code.contains("rotation"))
	_vrai("le roulis déplace bien quelque chose", code.contains("position.y"))

	# ⚠️ **L'ancrage.** Sans le compteur de pas, la démarche dérive du son.
	_vrai("le roulis se dérive du compteur de pas",
		corps.contains("step_distance_accumulated"))
	_vrai("le roulis alterne les pieds", corps.contains("_foot_side"))

	# ⚠️ **L'appel, pas la déclaration** — piège consigné le 2026-08-25 : un
	# `contains("ma_fonction()")` est vert grâce à la ligne `func`. Ici le
	# roulis est en ligne dans `_physics_process`, donc on vérifie qu'il est
	# bien DANS cette fonction et pas dans un coin mort du fichier.
	var phys := _bloc(joueur, "func _physics_process")
	_vrai("le roulis tourne dans _physics_process",
		phys.contains("ROULIS_RETOUR"))

	# Les cinq vues, sinon une seule roule et le joueur se dédouble.
	for vue in ["visual", "visual_dim", "visual_reveal", "visual_enemy",
			"visual_reveal_enemy"]:
		_vrai("la vue %s roule aussi" % vue, corps.contains(vue))

	_verdict()


## Le même bloc, privé de ses commentaires — voir `_init()` pour la raison.
func _sans_commentaires(bloc: String) -> String:
	var sortie := ""
	for l in bloc.split("\n"):
		var nette := l
		var d := nette.find("#")
		if d >= 0:
			nette = nette.substr(0, d)
		if nette.strip_edges() != "":
			sortie += nette + "\n"
	return sortie


## Le texte entre `reperage` et `borne` — ou jusqu'au prochain `func` si
## `borne` est vide.
func _bloc(texte: String, reperage: String, borne := "") -> String:
	var i := texte.find(reperage)
	if i < 0:
		return ""
	var suite := texte.substr(i)
	var fin := suite.find(borne, 1) if borne != "" else suite.find("\nfunc ", 1)
	return suite if fin < 0 else suite.substr(0, fin)


func _lire(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _vrai(quoi: String, ok: bool) -> void:
	_total += 1
	if not ok:
		_echecs += 1
		printerr("  ÉCHEC %s" % quoi)


func _verdict() -> void:
	print("test_marche : %d/%d" % [_total - _echecs, _total])
	quit(1 if _echecs > 0 else 0)
