#!/usr/bin/env python3
"""Les variantes de la décomposition de l'allègement de la 0.8.0 (2026-09-30) : chacune est l'arbre du candidat 0.8.0
(34666f25) avec UNE nouveauté retirée, par une retouche de texte figée ici (Pièges connus, 2026-09-25 : « figer en patch
chaque variante au moment où on la mesure »). Les autres nouveautés se retirent par leurs drapeaux de débogage
(`--sans-faisceau-air`, `--sans-portee-ecran`, `--zoom=1.5`, `--sans-point-lumineux`, `--sans-son-visible`).

Usage : variantes.py <arbre de la variante> <l2|q42|masques|l1bis>
L'arbre doit être une copie de 34666f25. Pour l1bis, les cookies de la 0.7.1 (`assets/torche/cookie_*.png` de 2501cb9a) se
copient à côté, puis l'arbre se réimporte (`godot --headless --path <arbre> --import`) : un cookie change d'import.
"""
import pathlib
import sys

arbre = pathlib.Path(sys.argv[1])
nom = sys.argv[2]


def remplacer(fichier, avant, apres, compte=1):
    p = arbre / fichier
    s = p.read_text(encoding="utf-8")
    n = s.count(avant)
    if n != compte:
        sys.exit("✗ %s : « %s » trouvé %d fois (attendu %d)" % (fichier, avant[:60], n, compte))
    p.write_text(s.replace(avant, apres), encoding="utf-8")
    print("  ✓ %s : %s…" % (fichier, avant.strip().splitlines()[0][:70]))


if nom == "l2":
    # L2 retiré : la lampe à (30, 0) devant le corps, un seul rayon vers l'avant (la règle d'avant L2).
    remplacer("player.gd", "\tflashlight.position = LENTILLE_LAMPE\n", "\tflashlight.position = Vector2(30.0, 0.0)\n")
    avant = """func _rapprocher_la_lampe() -> void:
	var lampe := LENTILLE_LAMPE
	var retro := RETRO_AVANCEE
	if flashlight_on and is_inside_tree():
		var espace := get_world_2d().direct_space_state
		var vers_lampe: Vector2 = global_transform.basis_xform(LENTILLE_LAMPE).normalized()
		var d := _mur_devant(espace, vers_lampe, LENTILLE_LAMPE.length() + RETRAIT_LAMPE)
		if d >= 0.0:
			lampe = LENTILLE_LAMPE.normalized() * clampf(d - RETRAIT_LAMPE, 4.0, LENTILLE_LAMPE.length())
		var r := _mur_devant(espace, global_transform.x.normalized(), RETRO_AVANCEE + RETRAIT_LAMPE)
		if r >= 0.0:
			retro = clampf(r - RETRAIT_LAMPE, 4.0, RETRO_AVANCEE)
	if not flashlight.position.is_equal_approx(lampe):
		flashlight.position = lampe
	if not is_equal_approx(body_light.position.x, retro):
		body_light.position.x = retro
"""
    apres = """func _rapprocher_la_lampe() -> void:
	var x := 30.0
	if flashlight_on and is_inside_tree():
		var espace := get_world_2d().direct_space_state
		var avant: Vector2 = global_transform.x.normalized()
		var q := PhysicsRayQueryParameters2D.create(global_position,
			global_position + avant * (30.0 + RETRAIT_LAMPE), MapGeometry.WALL_LAYER)
		q.exclude = [get_rid()]
		var coup: Dictionary = espace.intersect_ray(q)
		if not coup.is_empty():
			x = clampf(global_position.distance_to(coup["position"]) - RETRAIT_LAMPE, 4.0, 30.0)
	if not is_equal_approx(flashlight.position.x, x):
		flashlight.position.x = x
		body_light.position.x = minf(18.0, x)
"""
    remplacer("player.gd", avant, apres)
elif nom == "q42":
    # Q42 retiré : l'étoile de chaque corps reste dans le monde partagé (enfant du corps), sans canvas à elle.
    remplacer("player.gd", "\t\t_etoile_de_corps = EtoileDeCorps.monter(self, main_occ)\n",
              "\t\tpass  # variante de mesure : Q42 retiré\n")
elif nom == "masques":
    # Q55 et Q65 retirés : le capteur de soi ne porte que JOUEUR_LOCAL ; la rétrodiffusion sans bit récepteur.
    remplacer("canaux_lumiere.gd", "\treturn JOUEUR_LOCAL | couche_ombre_corps(id) | recepteur_retro(id)\n",
              "\treturn JOUEUR_LOCAL\n")
    remplacer("player.gd", "\tbody_light.shadow_item_cull_mask = 1 | 2 | COUCHE_TORSE | COUCHE_TORSE_ADVERSE \\\n"
              "\t\t| CanauxLumiere.recepteur_retro(1 - player_id)\n",
              "\tbody_light.shadow_item_cull_mask = 1 | 2 | COUCHE_TORSE | COUCHE_TORSE_ADVERSE\n")
elif nom == "l1bis":
    # L1bis retiré : les demi-angles d'avant (les cookies de la 0.7.1 sont écrits à côté, par `git show`).
    for avant, apres in [
        ("weapon_fusil.torch_angle_deg = 8.24", "weapon_fusil.torch_angle_deg = 10.0"),
        ("weapon_pompe.torch_angle_deg = 30.0", "weapon_pompe.torch_angle_deg = 60.0"),
        ("\"Le Fumiste\", 2, 18.2, 1.5)", "\"Le Fumiste\", 2, 30.0, 1.5)"),
        ("\"L'Incendiaire\", 6, 22.39, 1.4)", "\"L'Incendiaire\", 6, 40.0, 1.4)"),
        ("\"La Sentinelle\", 7, 7.02, 2.6)", "\"La Sentinelle\", 7, 8.0, 2.6)"),
        ("\"L'Occulteur\", 8, 15.96, 1.3)", "\"L'Occulteur\", 8, 25.0, 1.3)"),
        ("\"L'Allumeur\", 9, 24.38, 1.2)", "\"L'Allumeur\", 9, 45.0, 1.2)"),
        ("\"Le Spectre\", 10, 13.59, 1.4)", "\"Le Spectre\", 10, 20.0, 1.4)"),
    ]:
        remplacer("game_state.gd", avant, apres)
    remplacer("weapon_data.gd", "@export var torch_angle_deg: float = 20.34", "@export var torch_angle_deg: float = 35.0")
else:
    sys.exit("✗ variante inconnue : %s" % nom)
print("variante %s posée dans %s" % (nom, arbre))
