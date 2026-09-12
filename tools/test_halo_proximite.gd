## Garde de la règle du halo de proximité — décision d'Adrien, 2026-09-11 :
## « je veux que le halo révèle un ennemi proche. Attention, ma propre lueur ne
## doit pas me rendre détectable auprès de mon ennemi à distance. »
##
## Les deux moitiés de la phrase sont vérifiées, d'abord sur la règle
## (`canaux_lumiere.gd` : `canal_de_vue()` et `masque_vue_adverse()`), puis sur
## deux vrais joueurs instanciés : c'est sur les nœuds que la règle doit tenir,
## pas seulement dans les fonctions qui la calculent.
##
## ⚠️ **Une SCÈNE, pas un `--script`.** `player.gd` s'appuie sur des autoloads
## (`AudioManager`…) que le mode `--script` ne déclare pas à la compilation : la
## première version, en `extends SceneTree`, ne compilait pas `player.gd`, ne
## vérifiait donc rien — et annonçait « tous les tests passent ». D'où aussi le
## plancher de vérifications en fin de course : un test qui n'a rien vérifié
## doit échouer, pas se taire.
## Lancer : godot --headless --path . res://tools/test_halo_proximite.tscn
extends Node

## Nombre de vérifications en dessous duquel le test ne peut pas être vert.
const PLANCHER := 20

var _failures: int = 0
var _verifications: int = 0

func _ready() -> void:
	print("=== Test halo de proximité ===")
	_test_regle()
	await _test_joueurs_reels()
	_check("au moins %d vérifications ont réellement tourné" % PLANCHER,
		_verifications >= PLANCHER, "%d" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	_verifications += 1
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _test_regle() -> void:
	print("\n— La règle")
	_check("un canal de vue par joueur", CanauxLumiere.canal_de_vue(0) != CanauxLumiere.canal_de_vue(1))
	for a in [0, 1]:
		var b: int = 1 - a
		var halo := CanauxLumiere.canal_de_vue(a)
		_check("le halo de J%d éclaire l'ennemi sur SON écran" % (a + 1),
			(halo & CanauxLumiere.masque_vue_adverse(b)) != 0)
		_check("le halo de J%d n'éclaire JAMAIS son propre sprite chez l'adversaire" % (a + 1),
			(halo & CanauxLumiere.masque_vue_adverse(a)) == 0)
		_check("le sprite ennemi de J%d garde le canal commun (torche, reflet, tirs)" % (a + 1),
			(CanauxLumiere.masque_vue_adverse(a) & 2) != 0)
		_check("le halo de J%d ne touche ni le décor commun, ni le canal ennemi, ni le joueur local" % (a + 1),
			(halo & (1 | 2 | 4)) == 0)

func _test_joueurs_reels() -> void:
	print("\n— Sur deux vrais joueurs")
	var scene: PackedScene = load("res://player.tscn")
	_check("player.tscn se charge", scene != null)
	if scene == null:
		return
	var joueurs := []
	for id in [0, 1]:
		var p = scene.instantiate()
		p.name = "Joueur%d" % (id + 1)
		p.player_id = id
		add_child(p)
		joueurs.append(p)
	await get_tree().process_frame
	for id in [0, 1]:
		var p = joueurs[id]
		var nom := "J%d" % (id + 1)
		_check("%s : halo sur son canal de vue" % nom, p.ambient_light != null
			and p.ambient_light.range_item_cull_mask == CanauxLumiere.canal_de_vue(id),
			str(p.ambient_light.range_item_cull_mask) if p.ambient_light else "pas de halo")
		for vue in ["visual_enemy", "visual_enemy_ptr"]:
			var n = p.get(vue)
			_check("%s : %s porte le masque de la vue adverse" % [nom, vue], n != null
				and n.light_mask == CanauxLumiere.masque_vue_adverse(id),
				str(n.light_mask) if n else "absent")
		# Le sprite ennemi d'un joueur est dessiné sur la vue de l'AUTRE : c'est
		# ce qui rend la règle juste — le halo de l'autre l'éclaire chez l'autre.
		_check("%s : son sprite ennemi est dessiné sur la vue de l'autre" % nom,
			p.visual_enemy != null and p.visual_enemy.visibility_layer == (4 if id == 0 else 2),
			str(p.visual_enemy.visibility_layer) if p.visual_enemy else "absent")
	# La phrase d'Adrien, sur les nœuds : mon halo n'atteint pas mon sprite
	# chez l'adversaire, et atteint le sien chez moi.
	for a in [0, 1]:
		var b: int = 1 - a
		var halo: int = joueurs[a].ambient_light.range_item_cull_mask
		_check("nœuds : le halo de J%d ne me rend pas détectable chez J%d" % [a + 1, b + 1],
			(halo & joueurs[a].visual_enemy.light_mask) == 0)
		_check("nœuds : le halo de J%d révèle J%d de près, chez J%d" % [a + 1, b + 1, a + 1],
			(halo & joueurs[b].visual_enemy.light_mask) != 0)
	for p in joueurs:
		p.queue_free()
	await get_tree().process_frame
