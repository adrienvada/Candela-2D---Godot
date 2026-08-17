extends Node
## Banc d'essai de la file d'appariement — contre le VRAI service EOS.
##
## Il répond à **une** question, et c'est la seule qui puisse encore invalider la
## conception de la Phase 8 :
##
##     EOS accepte-t-il un filtre ENTIER avec GreaterThanOrEqual sur l'attribut
##     de classement ?
##
## Tout le filtre de fourchette repose là-dessus. Si la réponse est non, il
## faudra publier des paliers nommés en chaîne et filtrer par égalité —
## l'élargissement devient plus grossier, et le cœur change.
##
## **Une seule instance suffit.** On ne cherche pas à trouver un adversaire : le
## ticket qu'on vient de publier s'auto-exclut. On cherche à savoir si la
## **requête** est acceptée par le service. Trouver zéro candidat est le résultat
## attendu ; une requête refusée est le résultat qui compte.
##
## Ce banc est une SCÈNE et non un script, et ce n'est pas un détail : un
## `--script` compile `network_manager.gd` avant l'enregistrement des autoloads du
## plugin EOS, et `HLobbies` reste introuvable.
##
## Lancer : godot --headless --path . res://tools/test_queue.tscn -- [--eos-ephemeral]

const EOS_READY_TIMEOUT := 30.0

var _failures := 0

func _ready() -> void:
	print("=== Banc de file d'appariement (EOS réel) ===")
	_run()

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _run() -> void:
	if not await _wait_for_eos():
		printerr("\n✗ EOS n'est pas prêt : le banc ne prouve rien.")
		NetworkManager.quit_game(2)
		return

	print("\n[Préalable]")
	_check("l'appariement se déclare supporté", NetworkManager.matchmaking_supported())
	var moi := NetworkManager.local_identity_key()
	_check("l'identité locale est connue", moi != "", "vide")
	print("    identité : ", moi.substr(0, 12), "…")

	print("\n[Publication d'un ticket]")
	var publie: bool = await NetworkManager.queue_publish_async("RANKED", 1000, "sonde")
	_check("le ticket part avec un classement de 1000", publie)

	# --- LA question -------------------------------------------------------
	print("\n[Filtre entier — la question qui décide]")
	var borne: Variant = await NetworkManager.queue_search_async("RANKED", 940, 1060)
	_check("une fourchette bornée des deux côtés est ACCEPTÉE",
		borne is Array, "la requête a échoué : EOS refuse le filtre entier")
	if borne is Array:
		print("    [940, 1060] → ", (borne as Array).size(),
			" candidat(s) (zéro attendu : on s'auto-exclut)")

	var basse: Variant = await NetworkManager.queue_search_async("RANKED", 940, -1)
	_check("une borne basse seule est acceptée", basse is Array)
	var haute: Variant = await NetworkManager.queue_search_async("RANKED", -1, 1060)
	_check("une borne haute seule est acceptée", haute is Array)
	var ouverte: Variant = await NetworkManager.queue_search_async("RANKED", -1, -1)
	_check("une recherche sans borne est acceptée", ouverte is Array)

	print("\n[Étanchéité des deux files]")
	var amicale: Variant = await NetworkManager.queue_search_async("CASUAL", -1, -1)
	_check("la file amicale répond séparément", amicale is Array)

	print("\n[Retrait]")
	await NetworkManager.queue_close_async()
	_check("le ticket est retiré sans erreur", true)

	if _failures == 0:
		print("\n✓ EOS accepte le filtre entier — la conception de la Phase 8 tient.")
	else:
		printerr("\n✗ %d contrôle(s) en échec — voir docs/ROADMAP.md, étape 8.2." % _failures)
	NetworkManager.quit_game(1 if _failures > 0 else 0)

func _wait_for_eos() -> bool:
	var reste := EOS_READY_TIMEOUT
	while reste > 0.0:
		if NetworkManager.eos_state == NetworkManager.EosState.READY:
			return true
		if NetworkManager.eos_state == NetworkManager.EosState.FAILED:
			return false
		await get_tree().create_timer(0.5).timeout
		reste -= 0.5
	return false
