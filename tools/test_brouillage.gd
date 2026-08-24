## Le brouillage — les deux invariants, et les bornes de chaque mode.
##
## Ce fichier ne juge AUCUN réglage : lequel des cinq modes est le bon, et à
## quelle amplitude, se tranche au banc (`tools/banc_brouillage.tscn`) et par
## Adrien. Ici on ne vérifie que ce qui doit rester vrai quel que soit
## l'arbitrage — faute de quoi le banc jugerait un modèle cassé sans le savoir,
## ce qui est très exactement ce qui s'est produit le 2026-08-18 : trente suites
## vertes sur une mécanique qui ne faisait rien.
##
## Les deux invariants, et pourquoi ils comptent plus que les nombres :
##
## 1. **À éblouissement nul, tout mode est l'identité.** Un brouillage résiduel
##    au repos rendrait le jeu illisible sans jamais apparaître dans un relevé.
## 2. **La vérité reste recouvrable.** Barycentre des fantômes nul, moyenne
##    temporelle de la dérive nulle. Sans cette propriété, le brouillage n'aurait
##    pas de plafond de compétence : ce serait de la chance, pas une mécanique,
##    et le jeu se veut « honnête en compétition ».
##
## Lancer : godot --headless --path . --script res://tools/test_brouillage.gd
extends SceneTree

const Brouillage := preload("res://brouillage.gd")

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
	print("=== LE BROUILLAGE ===")
	_test_identite_a_zero()
	_test_verite_recouvrable()
	_test_bornes()
	_test_monotonie()
	_test_determinisme()
	_test_continuite()
	_test_noms()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# INVARIANT 1 — à éblouissement nul, rien ne bouge
# ---------------------------------------------------------------------------

func _test_identite_a_zero() -> void:
	print("\n[À éblouissement nul, tout mode est l'identité]")
	# Balayé sur plusieurs instants : un mode qui ne dépendrait de `dazzle` que
	# par son amplitude passerait quand même, mais un mode qui l'aurait oublié
	# dans un terme de phase se trahirait ici.
	var propre := true
	for i in 40:
		var t := float(i) * 0.137
		if not Brouillage.fantomes(0.0, 1.0, t).is_empty():
			propre = false
		if Brouillage.derive(0.0, 1.0, t) != Vector2.ZERO:
			propre = false
	_check("aucun fantôme, aucune dérive, à aucun instant", propre)
	_check("aucun retard", is_zero_approx(Brouillage.retard(0.0)))
	var h := Brouillage.halo(0.0)
	_check("aucun halo", is_zero_approx(h["rayon"]) and is_zero_approx(h["intensite"]))
	_check("aucune perte de contraste", is_equal_approx(Brouillage.opacite(0.0), 1.0))

	# Une force nulle est l'autre porte de sortie : c'est ainsi qu'un mode se
	# désactive depuis les options sans que personne ait à écrire un `if`.
	_check("force nulle vaut éblouissement nul",
		Brouillage.fantomes(1.0, 0.0, 3.0).is_empty()
		and Brouillage.derive(1.0, 0.0, 3.0) == Vector2.ZERO
		and is_zero_approx(Brouillage.retard(1.0, 0.0))
		and is_zero_approx(Brouillage.halo(1.0, 0.0)["rayon"])
		and is_equal_approx(Brouillage.opacite(1.0, 0.0), 1.0))


# ---------------------------------------------------------------------------
# INVARIANT 2 — la vérité reste recouvrable
# ---------------------------------------------------------------------------

func _test_verite_recouvrable() -> void:
	print("\n[La vérité reste recouvrable]")
	# Le barycentre de N points également répartis sur un cercle est son centre.
	# C'est la propriété qui autorise « vise entre les deux » ; sans elle, la
	# diplopie serait un décalage constant, c'est-à-dire un mensonge.
	for copies in [2, 3, 4]:
		var pire := 0.0
		for i in 30:
			var t := float(i) * 0.211
			var somme := Vector2.ZERO
			for o in Brouillage.fantomes(1.0, 1.0, t, copies):
				somme += o
			pire = maxf(pire, somme.length())
		_check("le barycentre de %d fantômes est la position vraie" % copies,
			pire < 0.001, "écart %.5f px" % pire)

	# La dérive doit être de moyenne nulle sur un temps long : celui qui garde
	# son calme et moyenne retrouve sa cible. On échantillonne sur 40 s, bien
	# au-delà de la période des deux composantes.
	var moyenne := Vector2.ZERO
	var n := 4000
	for i in n:
		moyenne += Brouillage.derive(1.0, 1.0, float(i) * 0.01)
	moyenne /= float(n)
	_check("la dérive est de moyenne nulle sur la durée",
		moyenne.length() < Brouillage.AMPLITUDE_DERIVE * 0.05,
		"%.2f px de biais" % moyenne.length())

	# La rémanence ne ment pas non plus, mais autrement : elle montre un état
	# qui a VRAIMENT existé. Ce qu'on éprouve ici, c'est qu'elle reste bornée —
	# un retard qui grandirait sans fin ferait diverger la lecture.
	_check("le retard est borné par son réglage",
		Brouillage.retard(1.0, 1.0) <= Brouillage.RETARD_REMANENCE + 1e-6)


# ---------------------------------------------------------------------------
# LES BORNES — l'amplitude annoncée est la vraie
# ---------------------------------------------------------------------------

func _test_bornes() -> void:
	print("\n[Les bornes annoncées sont les bornes réelles]")
	# La dérive est bornée en LONGUEUR, pas par axe. Sans `limit_length`, la
	# diagonale vaudrait √2 fois le réglage — l'écart qu'on découvre en mesurant
	# six mois plus tard, et qu'on prend alors pour un réglage voulu.
	var pire := 0.0
	for i in 5000:
		pire = maxf(pire, Brouillage.derive(1.0, 1.0, float(i) * 0.0073).length())
	_check("la dérive ne dépasse jamais son amplitude",
		pire <= Brouillage.AMPLITUDE_DERIVE + 1e-4,
		"%.3f px pour %.1f annoncés" % [pire, Brouillage.AMPLITUDE_DERIVE])
	_check("et elle l'atteint (le réglage n'est pas un majorant décoratif)",
		pire > Brouillage.AMPLITUDE_DERIVE * 0.9, "%.3f px" % pire)

	for o in Brouillage.fantomes(1.0, 1.0, 1.234, 2):
		_check("un fantôme se tient à la distance annoncée",
			absf(o.length() - Brouillage.RAYON_DIPLOPIE) < 1e-4,
			"%.4f px" % o.length())

	# Le pic de flash peut porter `dazzle` au-dessus de 1 (`apply_dazzle` le
	# permet, et c'est le modèle). Rien ici ne doit sortir des amplitudes jugées.
	_check("un éblouissement au-delà de 1 ne dépasse pas la saturation",
		Brouillage.derive(1.6, 1.0, 2.0).length() <= Brouillage.AMPLITUDE_DERIVE + 1e-4
		and is_equal_approx(Brouillage.retard(1.6), Brouillage.RETARD_REMANENCE))
	_check("une force au-delà de 1 sature aussi",
		is_equal_approx(Brouillage.retard(1.0, 5.0), Brouillage.RETARD_REMANENCE))


# ---------------------------------------------------------------------------
# LA MONOTONIE — plus d'éblouissement ne peut pas brouiller moins
# ---------------------------------------------------------------------------

func _test_monotonie() -> void:
	print("\n[Plus d'éblouissement ne brouille jamais moins]")
	var croissant := true
	var precedent := -1.0
	for i in 21:
		var d := float(i) / 20.0
		var r := Brouillage.retard(d)
		var h := float(Brouillage.halo(d)["rayon"])
		var a := Brouillage.opacite(d)
		var f := Brouillage.fantomes(d, 1.0, 0.0, 2)
		var rayon := 0.0 if f.is_empty() else Vector2(f[0]).length()
		if r < precedent - 1e-9:
			croissant = false
		precedent = r
		if h < 0.0 or a > 1.0 or a < Brouillage.ALPHA_CONTRASTE - 1e-6 or rayon < 0.0:
			croissant = false
	_check("retard, halo, rayon croissent ; l'opacité décroît sans passer sous son plancher",
		croissant)


# ---------------------------------------------------------------------------
# LE DÉTERMINISME — hôte et client doivent voir la même figure
# ---------------------------------------------------------------------------

func _test_determinisme() -> void:
	print("\n[Deux machines, un même instant, une même figure]")
	# Sans état ni générateur aléatoire : c'est ce qui permettrait un jour de
	# calculer le brouillage des deux côtés du fil sans rien transmettre.
	var pareil := true
	for i in 50:
		var t := float(i) * 0.317
		if Brouillage.derive(0.8, 1.0, t, 3.0) != Brouillage.derive(0.8, 1.0, t, 3.0):
			pareil = false
		if Brouillage.fantomes(0.8, 1.0, t) != Brouillage.fantomes(0.8, 1.0, t):
			pareil = false
	_check("le même appel rend le même résultat", pareil)
	# Deux joueurs éblouis en même temps ne doivent pas trembler à l'unisson :
	# à l'unisson, ça se lit comme un défaut d'affichage, pas comme deux paires
	# d'yeux.
	var ecart := 0.0
	for i in 200:
		var t := float(i) * 0.05
		ecart = maxf(ecart, (Brouillage.derive(1.0, 1.0, t, 0.0)
			- Brouillage.derive(1.0, 1.0, t, 2.7)).length())
	_check("deux graines donnent deux figures distinctes",
		ecart > Brouillage.AMPLITUDE_DERIVE * 0.5, "%.2f px d'écart maximal" % ecart)


# ---------------------------------------------------------------------------
# LA CONTINUITÉ — rien ne doit sauter
# ---------------------------------------------------------------------------

func _test_continuite() -> void:
	print("\n[Rien ne saute]")
	# Un saut de silhouette se lirait comme une désynchronisation réseau, ce qui
	# est le pire malentendu possible dans un jeu en ligne : le joueur
	# incriminerait sa connexion, pas la torche qu'on lui braque dessus.
	var pas := 1.0 / 60.0
	var saut := 0.0
	for i in 3000:
		var t := float(i) * pas
		saut = maxf(saut, (Brouillage.derive(1.0, 1.0, t + pas)
			- Brouillage.derive(1.0, 1.0, t)).length())
	# **Le plafond est la vitesse de MARCHE d'un joueur** (`player.speed`, 260
	# px/s), pas une fraction de l'amplitude. Un seuil relatif ne veut rien dire
	# ici ; celui-ci dit quelque chose : ce qui se déplace comme un joueur se lit
	# comme un joueur. Au-dessus, on ne lit plus une dérive mais une vibration —
	# donc un défaut d'affichage, et surtout un brouillage qui s'annule tout
	# seul, l'œil intégrant ce qui tremble vite jusqu'à retrouver la moyenne,
	# c'est-à-dire la vérité.
	#
	# Ce contrôle a servi dès sa première exécution : la dérive filait à
	# 322 px/s, et les deux fréquences ont été divisées par deux et demi.
	var vitesse := saut / pas
	_check("la dérive ne va jamais plus vite qu'un joueur qui marche (260 px/s)",
		vitesse < 260.0, "%.0f px/s" % vitesse)

	var saut_f := 0.0
	for i in 3000:
		var t := float(i) * pas
		var a := Brouillage.fantomes(1.0, 1.0, t)
		var b := Brouillage.fantomes(1.0, 1.0, t + pas)
		saut_f = maxf(saut_f, (Vector2(b[0]) - Vector2(a[0])).length())
	_check("les fantômes tournent sans sauter",
		saut_f < Brouillage.RAYON_DIPLOPIE * 0.05, "%.3f px" % saut_f)


func _test_noms() -> void:
	print("\n[Chaque mode a un nom]")
	# Un mode ajouté sans son libellé s'affiche « (null) » au banc et dans les
	# options. Trois défauts purement visuels trouvés à l'œil par Adrien le
	# 2026-08-24 avaient la même cause : ce qui n'a pas de nom dans le code n'a
	# pas de contrôle possible.
	var complet := true
	for m in Brouillage.Mode.values():
		if not Brouillage.NOMS.has(m) or String(Brouillage.NOMS[m]).is_empty():
			complet = false
	_check("les %d modes sont tous nommés" % Brouillage.Mode.size(), complet)
