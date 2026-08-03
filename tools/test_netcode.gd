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

var _failures: int = 0

func _ready() -> void:
	print("=== Test Netcode ===")

	_test_circle_entry_distance()
	_test_rewound_position()
	_test_predicted_shots()
	_test_lag_comp_delay()

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

	_check("file vide → tir officiel à rendre", not state._consume_predicted_shot())

	state._predicted_shots.append(now)
	_check("tir récent → déjà rendu localement", state._consume_predicted_shot())
	_check("consommé une seule fois", state._predicted_shots.is_empty())

	# Prédiction jamais confirmée (paquet perdu, tir refusé) : elle doit sortir
	# de la file, sinon elle décalerait tous les tirs suivants d'un cran.
	state._predicted_shots.clear()
	state._predicted_shots.append(now - GameState.PREDICTED_SHOT_TTL_MS - 1)
	_check("tir périmé → tir officiel à rendre", not state._consume_predicted_shot())
	_check("tir périmé purgé de la file", state._predicted_shots.is_empty())

	state._predicted_shots.clear()
	state._predicted_shots.append(now - GameState.PREDICTED_SHOT_TTL_MS - 1)
	state._predicted_shots.append(now)
	_check("périmé puis récent → le récent est reconnu", state._consume_predicted_shot())
	_check("les deux entrées ont quitté la file", state._predicted_shots.is_empty())

	state._predicted_shots.clear()
	state._predicted_shots.append(now)
	state._predicted_shots.append(now)
	_check("volée de deux → premier reconnu", state._consume_predicted_shot())
	_check("volée de deux → second reconnu", state._consume_predicted_shot())
	_check("volée épuisée → tir officiel à rendre", not state._consume_predicted_shot())

	# Hors du rôle client, la prédiction n'existe pas : la file ne doit ni
	# répondre ni être consommée.
	NetworkManager.current_mode = NetworkManager.GameMode.ONLINE_HOST
	state._predicted_shots.clear()
	state._predicted_shots.append(now)
	_check("hôte → jamais de tir prédit", not state._consume_predicted_shot())
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
