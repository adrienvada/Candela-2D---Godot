## Test headless de la logique netcode testable sans réseau : géométrie du tir
## compensé, remontée dans l'historique de positions, file de tirs prédits et
## plafonnement du recul de compensation.
##
## Lancer : godot --headless --path . res://tools/test_netcode.tscn
##
## Contrairement aux autres suites, celle-ci passe par une scène et non par
## `--script` : le code testé référence les autoloads (NetworkManager), que le
## mode script ne déclare pas à la compilation.
extends Node

## La durée de vie d'une prédiction a quitté `game_state.gd` pour un fichier sans
## dépendance ; le banc lit la constante là où elle vit désormais.
const PredictionTir := preload("res://prediction_tir.gd")

var _failures: int = 0

func _ready() -> void:
	print("=== Test Netcode ===")

	_test_circle_entry_distance()
	_test_rewound_position()
	_test_predicted_shots()
	_test_lag_comp_delay()
	_test_lobby_code()
	_test_recovery_code()
	_test_rendu_des_vues()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _check_near(label: String, value: float, expected: float, tolerance: float = 0.001) -> void:
	_check(label, absf(value - expected) <= tolerance, "%f attendu %f" % [value, expected])

# ---------------------------------------------------------------------------
# GÉOMÉTRIE DU TIR COMPENSÉ (bullet.gd)
# ---------------------------------------------------------------------------

## Distance d'entrée du pas de la balle dans le disque de la cible compensée.
## -1 signifie « pas d'impact sur ce pas ».
func _test_circle_entry_distance() -> void:
	print("\n[Entrée dans le cercle compensé]")

	var right := Vector2.RIGHT

	_check_near("cible droit devant → distance jusqu'au bord",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(50, 0), 10.0), 40.0)

	_check_near("origine déjà dans le cercle → impact immédiat",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(5, 0), 10.0), 0.0)

	_check_near("origine au centre exact → impact immédiat",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2.ZERO, 10.0), 0.0)

	_check_near("cible entièrement derrière → aucun impact",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(-50, 0), 10.0), -1.0)

	# Le cercle est devant, mais hors du pas parcouru cette frame : ce n'est pas
	# un raté, c'est un impact qui appartient à une frame ultérieure.
	_check_near("cible au-delà du pas → aucun impact",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(200, 0), 10.0), -1.0)

	_check_near("bord atteint pile en fin de pas → impact retenu",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(110, 0), 10.0), 100.0)

	_check_near("tangente exacte → impact rasant",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(50, 10), 10.0), 50.0)

	_check_near("passe à côté → aucun impact",
		Bullet._circle_entry_distance(Vector2.ZERO, right, 100.0, Vector2(50, 10.5), 10.0), -1.0)

	# Le calcul suppose une direction unitaire : c'est le contrat de l'appelant.
	var diag := Vector2(1, 1).normalized()
	_check_near("direction diagonale → projection correcte",
		Bullet._circle_entry_distance(Vector2.ZERO, diag, 100.0, Vector2(30, 30), 5.0),
		Vector2(30, 30).length() - 5.0, 0.01)

	# Le tireur recule pendant que la balle avance : l'origine du pas n'est pas
	# forcément l'origine du monde.
	_check_near("origine décalée → distance relative au pas",
		Bullet._circle_entry_distance(Vector2(100, 50), right, 200.0, Vector2(250, 50), 20.0), 130.0)

# ---------------------------------------------------------------------------
# HISTORIQUE DE POSITIONS (game_state.gd)
# ---------------------------------------------------------------------------

## Historique linéaire : 100 px/s sur X pour P1, statique pour P2, échantillonné
## toutes les 0,1 s. La lenteur est volontaire — l'horloge avance entre la
## construction du jeu d'essai et l'appel testé. Le plus récent des échantillons
## date de 0,1 s : sans cette marge, la comparaison de borne haute jouerait à
## pile ou face avec le bruit de calcul.
func _seed_history(state: GameState, now: float) -> void:
	state._pos_history.clear()
	var ages: Array[float] = [0.4, 0.3, 0.2, 0.1]
	for i in ages.size():
		state._pos_history.append({
			"t": now - ages[i],
			"p1": Vector2(10.0 * float(i), 0.0),
			"p2": Vector2(0.0, 500.0),
		})

func _test_rewound_position() -> void:
	print("\n[Remontée dans l'historique]")

	var state := GameState.new()
	var p1 := Player.new()
	var p2 := Player.new()
	state.p1 = p1
	state.p2 = p2
	p1.global_position = Vector2(999, 0)
	p2.global_position = Vector2(999, 500)

	_check("historique vide → position courante",
		state._rewound_position(p1, 0.1) == Vector2(999, 0))

	var now := Time.get_ticks_msec() / 1000.0
	_seed_history(state, now)

	# Tolérance : quelques millisecondes s'écoulent entre _seed_history et
	# l'appel, soit une fraction de pixel à 100 px/s.
	_check_near("milieu de segment → interpolation",
		state._rewound_position(p1, 0.25).x, 15.0, 2.0)
	_check_near("sur un échantillon → sa valeur",
		state._rewound_position(p1, 0.2).x, 20.0, 2.0)
	_check_near("recul nul → position courante (borne haute)",
		state._rewound_position(p1, 0.0).x, 999.0, 0.001)
	_check_near("recul au-delà de la fenêtre → plus ancien échantillon (borne basse)",
		state._rewound_position(p1, 5.0).x, 0.0, 0.001)
	_check("chaque joueur a sa piste",
		state._rewound_position(p2, 0.25) == Vector2(0, 500),
		str(state._rewound_position(p2, 0.25)))

	# Un seul échantillon : rien à interpoler. Il fait autorité pour tout ce qui
	# est plus ancien que lui, et rien au-delà.
	state._pos_history.clear()
	state._pos_history.append({"t": now - 0.2, "p1": Vector2(42, 0), "p2": Vector2.ZERO})
	_check_near("échantillon unique, recul plus ancien → sa valeur",
		state._rewound_position(p1, 0.5).x, 42.0, 0.001)
	_check_near("échantillon unique, recul plus récent → position courante",
		state._rewound_position(p1, 0.05).x, 999.0, 0.001)

	p1.free()
	p2.free()
	state.free()

# ---------------------------------------------------------------------------
# FILE DE TIRS PRÉDITS (game_state.gd)
# ---------------------------------------------------------------------------

func _test_predicted_shots() -> void:
	print("\n[File de tirs prédits]")

	var previous_mode := NetworkManager.current_mode
	NetworkManager.current_mode = NetworkManager.GameMode.ONLINE_CLIENT

	var state := GameState.new()
	var now := Time.get_ticks_msec()

	_check("file vide → tir officiel à rendre", not state._consume_predicted_shot(0.0))

	state._predicted_shots.append({"t": now, "angle": 0.0})
	_check("tir récent → déjà rendu localement", state._consume_predicted_shot(0.0))
	_check("consommé une seule fois", state._predicted_shots.is_empty())

	# Une entrée porte désormais son instant ET son angle : l'ordre seul confondait
	# deux tirs rapprochés, et la durée de vie fixe rendait la balle en double dès
	# que le lien dépassait la seconde. La comptabilité vit dans
	# `prediction_tir.gd` ; ce qui se vérifie ICI est son branchement réel.
	var vieux := now - PredictionTir.TTL_DEFAUT_MS - 1

	# Prédiction jamais confirmée (paquet perdu, tir refusé) : elle doit sortir
	# de la file, sinon elle décalerait tous les tirs suivants d'un cran.
	state._predicted_shots.clear()
	state._predicted_shots.append({"t": vieux, "angle": 0.0})
	_check("tir périmé → tir officiel à rendre", not state._consume_predicted_shot(0.0))
	_check("tir périmé purgé de la file", state._predicted_shots.is_empty())

	state._predicted_shots.clear()
	state._predicted_shots.append({"t": vieux, "angle": 0.0})
	state._predicted_shots.append({"t": now, "angle": 1.0})
	_check("périmé puis récent → le récent est reconnu",
		state._consume_predicted_shot(1.0))
	_check("les deux entrées ont quitté la file", state._predicted_shots.is_empty())

	state._predicted_shots.clear()
	state._predicted_shots.append({"t": now, "angle": 0.0})
	state._predicted_shots.append({"t": now, "angle": 0.0})
	_check("volée de deux → premier reconnu", state._consume_predicted_shot(0.0))
	_check("volée de deux → second reconnu", state._consume_predicted_shot(0.0))
	_check("volée épuisée → tir officiel à rendre",
		not state._consume_predicted_shot(0.0))

	# Deux tirs séparés dans l'espace : c'est le cas que l'ordre seul confondait.
	# La balle qui revient doit retrouver SON tir, pas le plus ancien.
	state._predicted_shots.clear()
	state._predicted_shots.append({"t": now, "angle": 0.0})
	state._predicted_shots.append({"t": now, "angle": PI / 2.0})
	_check("la balle officielle retrouve son propre tir",
		state._consume_predicted_shot(PI / 2.0))
	_check("et laisse l'autre en file",
		state._predicted_shots.size() == 1
		and is_zero_approx(float(state._predicted_shots[0]["angle"])))

	# Hors du rôle client, la prédiction n'existe pas : la file ne doit ni
	# répondre ni être consommée.
	NetworkManager.current_mode = NetworkManager.GameMode.ONLINE_HOST
	state._predicted_shots.clear()
	state._predicted_shots.append({"t": now, "angle": 0.0})
	_check("hôte → jamais de tir prédit", not state._consume_predicted_shot(0.0))
	_check("hôte → file intacte", state._predicted_shots.size() == 1)

	state.free()
	NetworkManager.current_mode = previous_mode

# ---------------------------------------------------------------------------
# RECUL DE COMPENSATION (game_state.gd)
# ---------------------------------------------------------------------------

func _test_lag_comp_delay() -> void:
	print("\n[Plafonnement du recul de compensation]")

	var state := GameState.new()
	var previous_rtt := NetworkManager.rtt_ms

	NetworkManager.rtt_ms = 0.0
	_check_near("RTT nul → retard d'interpolation seul",
		state._lag_comp_delay(), Player.INTERP_DELAY)

	NetworkManager.rtt_ms = 100.0
	_check_near("RTT 100 ms → demi aller-retour ajouté",
		state._lag_comp_delay(), 0.05 + Player.INTERP_DELAY)

	NetworkManager.rtt_ms = 200.0
	_check_near("RTT 200 ms → pile au plafond",
		state._lag_comp_delay(), GameState.LAG_COMP_MAX)

	# Au-delà, on refuse de rembobiner davantage : un client très en retard
	# tuerait son adversaire loin derrière ce que celui-ci voit.
	NetworkManager.rtt_ms = 1000.0
	_check_near("RTT 1 s → écrêté au plafond",
		state._lag_comp_delay(), GameState.LAG_COMP_MAX)

	NetworkManager.rtt_ms = 60000.0
	_check_near("RTT absurde → écrêté au plafond",
		state._lag_comp_delay(), GameState.LAG_COMP_MAX)

	# Le RTT est un écho applicatif : une horloge qui recule ne doit pas
	# produire un recul négatif, qui viserait le futur.
	NetworkManager.rtt_ms = -5000.0
	var negative := state._lag_comp_delay()
	_check("RTT négatif → recul jamais négatif", negative >= 0.0, str(negative))
	_check("recul jamais au-dessus du plafond", negative <= GameState.LAG_COMP_MAX, str(negative))

	NetworkManager.rtt_ms = previous_rtt
	state.free()

# ---------------------------------------------------------------------------
# CODE DE SALON (lobby_code.gd)
# ---------------------------------------------------------------------------
func _test_lobby_code() -> void:
	print("\n-- Code de salon --")

	# Un code tiré au sort doit toujours être acceptable par le champ de saisie
	# d'en face : c'est le contrat entre generate() et is_valid().
	var all_valid := true
	var seen := {}
	for i in 500:
		var code := LobbyCode.generate()
		if not LobbyCode.is_valid(code):
			all_valid = false
			break
		seen[code] = true
	_check("500 tirages, tous valides", all_valid)
	_check("500 tirages, quasiment aucun doublon", seen.size() >= 495, "%d distincts" % seen.size())
	_check("longueur fixe", LobbyCode.generate().length() == LobbyCode.LENGTH)

	# Les quatre caractères ambigus n'entrent jamais dans un code produit.
	var forbidden_seen := false
	for i in 500:
		for c in LobbyCode.generate():
			if c in ["I", "O", "0", "1"]:
				forbidden_seen = true
	_check("jamais de I, O, 0 ni 1", not forbidden_seen)

	_check("is_valid refuse trop court", not LobbyCode.is_valid("ABC"))
	_check("is_valid refuse trop long", not LobbyCode.is_valid("ABCDEFG"))
	_check("is_valid refuse le vide", not LobbyCode.is_valid(""))
	_check("is_valid refuse les minuscules", not LobbyCode.is_valid("abcdef"))
	_check("is_valid refuse un caractère hors alphabet", not LobbyCode.is_valid("ABCDE1"))
	_check("is_valid accepte un code canonique", LobbyCode.is_valid("HNELWR"))

	# sanitize() rattrape ce que le joueur tape ou colle réellement.
	_check("sanitize met en majuscules", LobbyCode.sanitize("hnelwr") == "HNELWR")
	_check("sanitize retire les espaces", LobbyCode.sanitize(" HNE LWR ") == "HNELWR")
	_check("sanitize retire les tirets", LobbyCode.sanitize("HNE-LWR") == "HNELWR")
	_check("sanitize plafonne la longueur", LobbyCode.sanitize("HNELWRXYZ") == "HNELWR")
	_check("sanitize écarte les caractères interdits",
		LobbyCode.sanitize("H0N1ELWR") == "HNELWR", LobbyCode.sanitize("H0N1ELWR"))
	_check("sanitize d'un code propre est l'identité", LobbyCode.sanitize("HNELWR") == "HNELWR")

	# Ce que sanitize accepte, is_valid doit l'accepter : sans quoi l'UI
	# afficherait un code impossible à envoyer.
	_check("sanitize produit toujours un préfixe valide d'alphabet",
		LobbyCode.is_valid(LobbyCode.sanitize("h n e l w r")))

# ---------------------------------------------------------------------------
# CODE DE RÉCUPÉRATION (recovery_code.gd)
# ---------------------------------------------------------------------------
#
# Le TIRAGE vit côté serveur (supabase/functions/_shared/recovery_code.ts) et y
# est testé : c'est ce qui empêche un joueur de se choisir le code d'un autre.
# Ici on couvre la moitié cliente — nettoyer, valider, mettre en forme — et
# surtout le contrat qui lie les deux : ce que le serveur tire, le client doit
# l'accepter, et l'accepter sous la forme où le joueur le recopie.
func _test_recovery_code() -> void:
	print("\n-- Code de récupération --")

	_check("même alphabet que les codes de salon",
		RecoveryCode.ALPHABET == LobbyCode.ALPHABET)
	_check("aucun caractère ambigu dans l'alphabet",
		not ("I" in RecoveryCode.ALPHABET or "O" in RecoveryCode.ALPHABET
			or "0" in RecoveryCode.ALPHABET or "1" in RecoveryCode.ALPHABET))

	# 12 caractères sur 32, soit 60 bits. Un code de salon en fait 6 : assez pour
	# désigner un salon qui vit dix minutes, dérisoire pour un secret au porteur
	# qui ouvre un profil classé à vie.
	_check("deux fois plus long qu'un code de salon",
		RecoveryCode.LENGTH == 2 * LobbyCode.LENGTH, str(RecoveryCode.LENGTH))

	var canonical := "ABCDEFGHJKLM"
	_check("is_valid accepte un code canonique", RecoveryCode.is_valid(canonical))
	_check("is_valid refuse trop court", not RecoveryCode.is_valid("ABCDEFGH"))
	_check("is_valid refuse trop long", not RecoveryCode.is_valid("ABCDEFGHJKLMN"))
	_check("is_valid refuse le vide", not RecoveryCode.is_valid(""))
	_check("is_valid refuse les minuscules", not RecoveryCode.is_valid("abcdefghjklm"))
	_check("is_valid refuse un caractère ambigu", not RecoveryCode.is_valid("ABCDEFGHJKL1"))
	# La forme affichée n'est pas la forme canonique : elle porte ses tirets.
	_check("is_valid refuse la forme affichée",
		not RecoveryCode.is_valid("ABCD-EFGH-JKLM"))
	# Un code de salon ne doit jamais passer pour un code de récupération : ils
	# partagent l'alphabet, pas la longueur.
	_check("is_valid refuse un code de salon", not RecoveryCode.is_valid("HNELWR"))

	_check("sanitize met en majuscules",
		RecoveryCode.sanitize("abcdefghjklm") == canonical)
	_check("sanitize retire les tirets de lecture",
		RecoveryCode.sanitize("ABCD-EFGH-JKLM") == canonical,
		RecoveryCode.sanitize("ABCD-EFGH-JKLM"))
	_check("sanitize retire les espaces",
		RecoveryCode.sanitize(" ABCD EFGH JKLM ") == canonical)
	_check("sanitize plafonne la longueur",
		RecoveryCode.sanitize("ABCDEFGHJKLMNPQR") == canonical)
	_check("sanitize d'un code propre est l'identité",
		RecoveryCode.sanitize(canonical) == canonical)
	# Aucune substitution : un « I » disparaît, il ne devient pas « J ».
	# Deviner à la place du joueur rattacherait le profil de quelqu'un d'autre.
	_check("sanitize écarte les caractères ambigus sans les remplacer",
		RecoveryCode.sanitize("IABCDEFGHJKLM") == canonical,
		RecoveryCode.sanitize("IABCDEFGHJKLM"))
	_check("sanitize d'un code entièrement ambigu ne rend rien",
		RecoveryCode.sanitize("0O1I") == "")

	_check("format groupe par quatre",
		RecoveryCode.format(canonical) == "ABCD-EFGH-JKLM",
		RecoveryCode.format(canonical))
	_check("format d'un code vide reste vide", RecoveryCode.format("") == "")
	_check("format d'une saisie partielle ne perd rien",
		RecoveryCode.format("ABCDEF") == "ABCD-EF")

	# Le contrat qui compte : le champ de saisie affiche la forme groupée, et ce
	# qu'on y colle doit revenir à la forme que la fonction distante attend.
	_check("format puis sanitize est l'identité",
		RecoveryCode.sanitize(RecoveryCode.format(canonical)) == canonical)

	# Contrat avec le tirage serveur : tout code de LENGTH caractères pris dans
	# l'alphabet doit passer. On rejoue ici la forme de ce que le serveur produit.
	var all_valid := true
	for i in 200:
		var drawn := ""
		for j in RecoveryCode.LENGTH:
			drawn += RecoveryCode.ALPHABET[randi() % RecoveryCode.ALPHABET.length()]
		if not RecoveryCode.is_valid(drawn) or RecoveryCode.sanitize(drawn) != drawn:
			all_valid = false
			break
	_check("200 codes de la forme serveur, tous acceptés", all_valid)

## Une vue cachée ne doit pas rendre — la moitié du coût du duel.
##
## Cacher un `SubViewportContainer` ne suspend pas son `SubViewport` : il continue
## de dessiner dans une texture que personne n'affiche. En ligne et à
## l'entraînement, la moitié invisible de l'écran était rendue à chaque image, ce
## que la décomposition du 2026-08-18 chiffre à 1,5 ms — la totalité de l'écart
## entre le duel et un socle sans second rendu.
##
## Vérifié sur la règle et non sur la scène : c'est un accord entre deux
## propriétés, il se relit à froid.
func _test_rendu_des_vues() -> void:
	print("\n[Une vue cachée ne rend pas]")
	var vus := [true, false]
	var attendus := [SubViewport.UPDATE_ALWAYS, SubViewport.UPDATE_DISABLED]
	for i in 2:
		var mode: int = SubViewport.UPDATE_ALWAYS if vus[i] \
			else SubViewport.UPDATE_DISABLED
		_check("vue %s → %s" % ["affichée" if vus[i] else "cachée",
			"rend" if vus[i] else "ne rend pas"], mode == attendus[i])

	# Le point qui compte, et qui était faux : le gel du kill rétablissait les
	# DEUX vues d'office. En ligne, il rallumait donc celle que personne ne
	# regarde — et le coût revenait à la première mort, sans rien pour le dire.
	var state := GameState.new()
	_check("le rétablissement passe par l'état réel des vues",
		state.has_method("_accorder_rendu_aux_vues"))
	state.free()
