## Test headless de la table arme ↔ rang (`rank_loadout.gd`) — Phase 7.
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • **la règle du miroir aligne sur le MOINS bien classé** — l'inverse est le
##     défaut plausible, et il donnerait au mieux classé des options que l'autre
##     ne peut pas avoir, dans un duel où l'équilibre est tout ;
##   • **la table n'est pas monotone** : les rangs au-dessus de Lanterne
##     redescendent au Pistolet faute d'armes. Un test qui supposerait « plus
##     haut = mieux armé » figerait une règle que personne n'a écrite ;
##   • **une sélection, jamais une arme** : chaque entrée est un tableau, y
##     compris quand elle n'en contient qu'une. C'est ce qui permettra d'emporter
##     plusieurs armes sans réécrire les appelants ;
##   • hors compétitif, le socle entier, et **asymétrique** — deux amis ont le
##     droit de ne pas prendre la même chose ;
##   • un rang inconnu ne rend jamais un arsenal vide : un joueur sans arme n'est
##     pas un cas dégradé, c'est une partie injouable.
##
## Lancer : godot --headless --path . --script res://tools/test_arsenal.gd
extends SceneTree

var _failures: int = 0
## Chargé dans `_run()` et non dans `_init()` : en mode --script, le cache des
## classes globales n'existe pas encore au moment de `_init()`.
var _L: GDScript

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== ARSENAL PAR RANG ===")
	_L = load("res://rank_loadout.gd")
	if _L == null:
		printerr("✗ rank_loadout.gd introuvable")
		quit(1)
		return

	_test_socle()
	_test_table()
	_test_miroir()
	_test_disponibilite()
	_test_raisons()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _test_socle() -> void:
	print("\n[Hors compétitif : le socle, asymétrique]")
	var libre: Array = _L.available(false)
	# ⚠️ **Dix, et pas quatre.** Le socle veut dire « tout ce qui existe » ; le
	# laisser à quatre pendant que le catalogue en compte dix aurait fait d'une
	# non-restriction une restriction, sans que personne ne l'ait décidé.
	_check("les dix classes sont proposées", libre.size() == 10, str(libre))
	_check("le pistolet en fait partie", _L.PISTOLET in libre)
	_check("l'arbalète aussi", _L.ARBALETE in libre)
	_check("le Spectre aussi", _L.SPECTRE in libre)
	# Le rang ne doit rien changer hors compétitif : c'est ce qui distingue
	# l'amical du classé, et le confondre verrouillerait des armes entre amis.
	_check("le rang n'y change rien",
		_L.available(false, 1, 10) == _L.available(false, 10, 1))
	_check("l'écran partagé et l'amical partagent le même arsenal",
		_L.available(false, 3) == libre)

func _test_table() -> void:
	print("\n[La table compétitive]")
	# ⚠️ **Ce que chaque rang AJOUTE**, et non ce qu'il donne : le déblocage est
	# cumulatif depuis le 2026-09-09 (décision d'Adrien). `COMPETITIF` porte
	# l'apport, `for_tier()` cumule.
	_check("Aveugle apporte le pistolet", _L.COMPETITIF[0] == [_L.PISTOLET])
	_check("Braise le Fumiste", _L.COMPETITIF[1] == [_L.FUMISTE])
	_check("Bougie l'Illusionniste (fusil)", _L.COMPETITIF[2] == [_L.FUSIL])
	_check("Lanterne le Braconnier (arbalète)", _L.COMPETITIF[3] == [_L.ARBALETE])
	_check("Torche le Terrassier (pompe)", _L.COMPETITIF[4] == [_L.POMPE])
	_check("Brasier l'Incendiaire", _L.COMPETITIF[5] == [_L.INCENDIAIRE])
	_check("Phare la Sentinelle", _L.COMPETITIF[6] == [_L.SENTINELLE])
	_check("Aurore l'Occulteur", _L.COMPETITIF[7] == [_L.OCCULTEUR])
	_check("Zénith l'Allumeur", _L.COMPETITIF[8] == [_L.ALLUMEUR])
	_check("Candela le Spectre", _L.COMPETITIF[9] == [_L.SPECTRE])

	# ── Et ce que chaque rang DONNE : tout ce qui précède ────────────────────
	_check("Aveugle n'a que le pistolet", _L.for_tier(1) == [_L.PISTOLET],
		str(_L.for_tier(1)))
	_check("Bougie a les trois premières",
		_L.for_tier(3) == [_L.PISTOLET, _L.FUMISTE, _L.FUSIL], str(_L.for_tier(3)))
	_check("Candela les a toutes les dix", _L.for_tier(10).size() == 10,
		str(_L.for_tier(10).size()))

	# ⚠️ **Ce contrôle a été RETOURNÉ le 2026-09-09.** Il exigeait que la table ne
	# soit PAS monotone, et il était écrit « pour qu'une relecture ne le corrige
	# pas ». Adrien a demandé le déblocage cumulatif : le garde-fou existait pour
	# empêcher une correction non demandée, jamais pour opposer un veto au
	# propriétaire du jeu. Il garde donc maintenant la propriété INVERSE — et la
	# garde de la même façon, en propriété plutôt qu'en valeurs.
	#
	# ⚠️ Ce qui croît avec le rang est le CHOIX, pas la puissance : le Braconnier
	# et ses 0,60 s de root est toujours au rang 4, l'Allumeur et ses 0,20 s au
	# rang 9. Un Zénith a neuf classes de plus qu'un Aveugle, pas une classe plus
	# forte — et c'est la seule lecture qui rende l'échelle de lumière compatible
	# avec un déblocage.
	var croissant := true
	var strict := true
	for tier in range(2, 11):
		var avant: Array = _L.for_tier(tier - 1)
		var apres: Array = _L.for_tier(tier)
		for idx in avant:
			if not idx in apres:
				croissant = false
		if apres.size() <= avant.size():
			strict = false
	_check("chaque rang garde tout ce que le précédent avait", croissant)
	_check("et en ajoute au moins une", strict)
	_check("les dix catégories apportent dix classes DISTINCTES",
		_classes_distinctes())
	_check("la table couvre les dix catégories", _L.COMPETITIF.size() == 10)

	# Une sélection, jamais une arme — même quand elle n'en contient qu'une.
	for tier in range(1, 11):
		var sel: Variant = _L.for_tier(tier)
		if not (sel is Array):
			_check("la catégorie %d rend une sélection" % tier, false, str(sel))
			return
	_check("chaque catégorie rend une sélection, pas une arme", true)

	# Un rang inconnu ne doit pas produire un joueur sans arme.
	_check("un rang inconnu retombe sur la première catégorie",
		_L.for_tier(0) == [_L.PISTOLET] and _L.for_tier(-3) == [_L.PISTOLET])
	_check("un rang hors échelle est ramené au dernier",
		_L.for_tier(99) == _L.for_tier(10))
	# La sélection rendue doit être une copie : un appelant qui la trierait ou y
	# ajouterait une arme corromprait la table pour tout le reste de la partie.
	var vol: Array = _L.for_tier(1)
	vol.append(_L.ARBALETE)
	_check("modifier la sélection rendue n'altère pas la table",
		_L.for_tier(1) == [_L.PISTOLET], str(_L.for_tier(1)))

func _test_miroir() -> void:
	print("\n[La règle du miroir]")
	# L'inverse — aligner sur le mieux classé — est le défaut plausible, et il
	# passerait tous les autres contrôles.
	_check("Lanterne contre Aveugle joue au pistolet",
		_L.mirrored(4, 1) == [_L.PISTOLET], str(_L.mirrored(4, 1)))
	_check("et l'ordre des arguments n'y change rien",
		_L.mirrored(1, 4) == _L.mirrored(4, 1))
	_check("deux Bougie gardent leur sélection",
		_L.mirrored(3, 3) == _L.for_tier(3), str(_L.mirrored(3, 3)))

	# ⚠️ **Depuis le déblocage cumulatif, le miroir ne PRÊTE plus rien.** Il
	# retirait autrefois au mieux classé sa propre classe pour lui en donner une
	# autre — un Candela contre un Lanterne se retrouvait à l'arbalète, qu'il
	# n'avait jamais jouée. Il ne fait plus que RÉDUIRE : la sélection du moins
	# bien classé est un sous-ensemble stricte de celle de l'autre.
	#
	# C'est la propriété qui rend la règle acceptable, et elle mérite d'être
	# gardée : sans elle, « aligner sur le moins bien classé » pourrait redevenir
	# « échanger deux arsenals disjoints » au premier remaniement de la table.
	var reduit := true
	for haut in range(2, 11):
		for bas in range(1, haut):
			var commun: Array = _L.mirrored(haut, bas)
			if commun != _L.for_tier(bas):
				reduit = false
			for idx in commun:
				if not idx in _L.for_tier(haut):
					reduit = false
	_check("le miroir ne fait que retirer, jamais prêter", reduit)
	_check("Candela contre Lanterne garde les quatre premières",
		_L.mirrored(10, 4) == _L.for_tier(4), str(_L.mirrored(10, 4)))
	_check("un rang inconnu compte comme la première catégorie",
		_L.mirrored(0, 5) == [_L.PISTOLET])

func _test_disponibilite() -> void:
	print("\n[Ce qui est jouable]")
	_check("en amical, l'arbalète est jouable par un débutant",
		_L.is_available(_L.ARBALETE, false, 1))
	_check("en compétitif, un Aveugle n'y a pas droit",
		not _L.is_available(_L.ARBALETE, true, 1))
	_check("un Lanterne y a droit", _L.is_available(_L.ARBALETE, true, 4))
	_check("mais pas contre un Aveugle",
		not _L.is_available(_L.ARBALETE, true, 4, 1))
	# Adversaire inconnu : on montre sa propre sélection. Elle ne peut que
	# rétrécir ensuite, donc rien d'annoncé ici ne sera repris à tort.
	_check("adversaire inconnu : sa propre sélection",
		_L.available(true, 4) == _L.for_tier(4), str(_L.available(true, 4)))
	# ⚠️ Et l'annonce ne peut que RÉTRÉCIR à l'arrivée de l'autre, jamais
	# s'élargir : c'est ce qui rend honnête de montrer sa sélection avant de
	# connaître l'adversaire. Le déblocage cumulatif le garantit désormais par
	# construction, là où c'était une propriété de la table.
	_check("et elle ne peut que rétrécir ensuite",
		_L.available(true, 4, 1).size() <= _L.available(true, 4).size())

func _test_raisons() -> void:
	print("\n[Pourquoi une arme est refusée]")
	_check("une arme disponible n'a pas de raison",
		_L.reason_for(_L.PISTOLET, true, 1) == "")
	var r_mode: String = _L.reason_for(_L.ARBALETE, true, 1)
	_check("un rang trop bas est expliqué", r_mode != "", r_mode)
	var r_miroir: String = _L.reason_for(_L.ARBALETE, true, 4, 1, "Kim")
	_check("le miroir nomme l'adversaire", r_miroir.contains("Kim"), r_miroir)
	_check("et dit que l'arsenal est aligné", r_miroir.contains("aligné"), r_miroir)
	var r_anonyme: String = _L.reason_for(_L.ARBALETE, true, 4, 1)
	_check("sans pseudo, la phrase reste lisible",
		r_anonyme.contains("adversaire"), r_anonyme)


## Les dix catégories donnent-elles dix classes différentes ?
##
## ⚠️ **Ce contrôle n'aurait rien dit avant le 2026-09-09**, où six rangs sur dix
## rendaient le pistolet faute de contenu. Il dit maintenant quelque chose de
## fort : chaque palier de l'échelle a sa propre classe. Le jour où une saison
## fera partager une classe à deux rangs, il rougira — et c'est bien : ce sera
## une décision, elle mérite d'être vue.
## Les dix rangs APPORTENT-ils dix classes distinctes ?
##
## ⚠️ Lit `COMPETITIF` et non `for_tier()` : depuis le déblocage cumulatif, ce
## dernier rend des sélections qui se contiennent, et la distinction porte sur ce
## que chaque rang ajoute — c'est elle qui garantit qu'aucune classe n'est
## inaccessible et qu'aucune n'est débloquée deux fois.
func _classes_distinctes() -> bool:
	var vues := {}
	for apport in _L.COMPETITIF:
		if apport.size() != 1:
			return false
		if vues.has(apport[0]):
			return false
		vues[apport[0]] = true
	return vues.size() == 10
