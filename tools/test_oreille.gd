## L'oreille se pose vraiment, dans un vrai arbre de jeu.
##
## **Pourquoi cette suite existe alors que `test_musique` couvre déjà la règle.**
## La règle (`oreille_suit`) dit QUI doit entendre ; elle ne dit pas si le geste
## fonctionne. Or le geste a **trois pièces, et deux d'entre elles ne s'entendent
## pas seules** :
##
## 1. le pool d'`AudioStreamPlayer2D` doit habiter le `World2D` du jeu — il est
##    enfant de l'autoload, donc dans celui de la RACINE ;
## 2. le `SubViewport` doit être déclaré oreille — `audio_listener_enable_2d`
##    vaut `false` par défaut, seule la fenêtre racine l'a à `true` ;
## 3. un `AudioListener2D` doit être courant sur le joueur local.
##
## Poser la 3 sans la 1 ne change **rien du tout**, et on chercherait l'erreur
## dans le listener pendant des heures. C'est exactement ce qui a permis au jeu de
## vivre des mois avec des sons positionnels sans aucune oreille : rien n'était en
## erreur, tout était audible, et le panoramique était référencé à un point mort
## au centre de l'écran.
##
## Ce que cette suite NE prouve PAS, et il faut le dire : que le panoramique
## s'entend. En headless le pilote audio est muet. Elle prouve le CÂBLAGE, qui est
## précisément la partie qu'on ne peut pas juger à l'oreille sans se mentir.
##
## Lancer : godot --headless --path . --script res://tools/test_oreille.gd
extends SceneTree

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== L'OREILLE ===")
	var am = get_root().get_node_or_null("/root/AudioManager")
	_check("l'autoload AudioManager est là", am != null)
	if am == null:
		quit(1)
		return

	var scene = load("res://main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var vp1 = scene.get_node_or_null("SplitScreen/ViewportContainer1/SubViewport1")
	_check("la vue de jeu est là", vp1 != null)
	var porteur = scene.p1
	_check("le joueur 1 est là", porteur != null)
	if vp1 == null or porteur == null:
		_conclure()
		return
	var lecteur = am.sfx_players_2d[0]

	print("\n[Avant — l'état d'origine, celui qui a duré des mois]")
	# Ces deux contrôles décrivent le DÉFAUT. S'ils passent au vert un jour, c'est
	# que quelqu'un a déplacé le pool ailleurs — et la suite entière ne mesure
	# plus ce qu'elle croit mesurer.
	_check("le pool n'est PAS dans le monde du jeu",
		lecteur.get_world_2d() != vp1.world_2d)
	_check("la vue n'est PAS une oreille", not vp1.audio_listener_enable_2d)

	print("\n[Après — les trois pièces posées ensemble]")
	am.poser_oreille(porteur)
	await process_frame
	_check("le pool a rejoint le monde du jeu",
		lecteur.get_world_2d() == vp1.world_2d)
	_check("la vue est devenue une oreille", vp1.audio_listener_enable_2d)
	var oreille = porteur.get_node_or_null("OreilleLocale")
	_check("l'oreille est posée sur le joueur", oreille != null)
	if oreille != null:
		_check("et elle est courante", oreille.is_current())
		porteur.global_position = Vector2(321, 654)
		await process_frame
		_check("elle suit le joueur quand il bouge",
			oreille.global_position.is_equal_approx(porteur.global_position),
			str(oreille.global_position))

	print("\n[Rendu — rien ne reste accroché au monde du jeu]")
	# Le pool DOIT revenir. L'arène est reconstruite à chaque manche : les voix
	# parties avec elle seraient libérées, et le jeu perdrait tout son positionnel
	# pour le reste de la session, sans une seule erreur.
	am.rendre_oreille()
	await process_frame
	_check("le pool est revenu chez l'autoload", lecteur.get_parent() == am)
	_check("l'oreille a été retirée",
		porteur.get_node_or_null("OreilleLocale") == null)
	_check("rendre_oreille est idempotente", _rendre_deux_fois(am, lecteur))

	_conclure()

func _rendre_deux_fois(am, lecteur) -> bool:
	am.rendre_oreille()
	am.rendre_oreille()
	return lecteur.get_parent() == am

func _conclure() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
