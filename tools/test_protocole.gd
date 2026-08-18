## Le rappel — Phase 8, étape 8.9.
##
## `Protocol.VERSION` est tenu à la main : lui seul peut porter le jugement
## « ce changement casse la compatibilité ». Sa faiblesse est l'oubli, et cette
## suite est là pour la couvrir.
##
## Elle recalcule une empreinte de **tout ce qui voyage sur le fil** et la compare
## au témoin figé dans `protocol.gd`. Si le fil a bougé sans que le numéro bouge,
## elle passe au rouge et affiche l'empreinte à recopier — après avoir tranché la
## question du numéro, jamais avant.
##
## Ce qu'elle protège ne se voit pas autrement : **deux jeux qui ne parlent pas
## la même langue ne plantent pas, ils jouent chacun dans leur réalité.**
##
## Lancer : godot --headless --path . --script res://tools/test_protocole.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test du protocole ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_regles()
	_test_aucun_rpc_hors_liste()
	_test_temoin()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------

## La symétrie du refus. Un build ancien ne peut pas savoir ce que le nouveau a
## changé : sa tolérance serait une supposition.
func _test_regles() -> void:
	print("\n[La règle du bonjour]")
	_check("un pair de même version est accepté", Protocol.accepts(Protocol.VERSION))
	_check("un pair plus ancien est refusé", not Protocol.accepts(Protocol.VERSION - 1))
	_check("un pair plus récent est refusé AUSSI", not Protocol.accepts(Protocol.VERSION + 1))
	_check("un pair muet est refusé", not Protocol.accepts(0))

	# Le joueur n'a pas à connaître le numéro : il a à savoir quoi faire.
	var m := Protocol.mismatch_message(Protocol.VERSION + 1)
	_check("le message dit quoi faire", m.to_lower().contains("mettez à jour"), m)
	_check("et qui est en retard", m.contains("adversaire"), m)
	_check("un pair muet a son propre message",
		Protocol.mismatch_message(0) != m, Protocol.mismatch_message(0))

## Un `@rpc` dans un fichier absent de `RPC_SOURCES` échapperait au témoin : le
## fil aurait bougé et l'empreinte serait pourtant inchangée. C'est le seul mode
## de défaillance qui rende ce dispositif inutile, donc le seul qu'il faut rendre
## impossible par inadvertance.
func _test_aucun_rpc_hors_liste() -> void:
	print("\n[Aucun RPC hors des fichiers déclarés]")
	var oublies: Array[String] = []
	for chemin in _tous_les_scripts():
		if Protocol.RPC_SOURCES.has(chemin):
			continue
		if _porte_un_rpc(chemin):
			oublies.append(chemin)
	_check("tout @rpc vit dans un fichier surveillé", oublies.is_empty(),
		"non surveillés : %s — ajoutez-les à Protocol.RPC_SOURCES" % str(oublies))

func _test_temoin() -> void:
	print("\n[Le témoin]")
	var empreinte := _empreinte()
	_check("le fil n'a pas bougé depuis que le numéro a été fixé",
		empreinte == Protocol.WIRE_WITNESS,
		("le fil a changé.\n"
		+ "      Décidez D'ABORD si Protocol.VERSION doit monter (il est à %d),\n"
		+ "      PUIS recopiez ce témoin dans protocol.gd :\n"
		+ "      const WIRE_WITNESS := \"%s\"") % [Protocol.VERSION, empreinte])

# ---------------------------------------------------------------------------
# L'EMPREINTE
# ---------------------------------------------------------------------------

## Tout ce qui voyage, en une chaîne stable.
##
## Trois sources, et pas une de plus que nécessaire :
## - les **signatures de RPC**, qui portent le nom ET l'arité ET les types —
##   c'est l'arité qui fait qu'un paquet est jeté sans erreur ;
## - la **version du codec de carte**, la géométrie voyageant par valeur ;
## - les **noms d'attributs de salon**, par lesquels deux jeux se trouvent.
##
## Trié, pour qu'un déplacement de fonction dans un fichier ne fasse pas croire à
## un changement de protocole.
func _empreinte() -> String:
	var morceaux := PackedStringArray()
	for chemin in Protocol.RPC_SOURCES:
		for sig in _signatures_rpc(chemin):
			morceaux.append(sig)
	morceaux.sort()
	morceaux.append("mapcodec=%d" % MapCodec.VERSION)
	for cle in ["EOS_BUCKET_ID", "EOS_CODE_ATTRIBUTE", "EOS_QUEUE_ATTRIBUTE",
			"EOS_QUEUE_RATING_ATTRIBUTE", "EOS_QUEUE_COMMIT_ATTRIBUTE",
			"EOS_MEMBER_NONCE_ATTRIBUTE", "EOS_MEMBER_RATING_ATTRIBUTE",
			"EOS_MEMBER_ACCEPT_ATTRIBUTE", "EOS_SOCKET_ID"]:
		morceaux.append("%s=%s" % [cle, _constante("res://network_manager.gd", cle)])
	return "\n".join(morceaux).sha256_text().substr(0, 16)

## L'annotation ET la signature qui la suit : `@rpc("any_peer", "reliable")` et
## `func rpc_x(a: int)` disent chacune une moitié du contrat. Changer le mode
## d'appel sans changer la signature casse tout autant.
func _signatures_rpc(chemin: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lignes := _lire(chemin).split("\n")
	for i in lignes.size():
		var ligne := String(lignes[i]).strip_edges()
		if not ligne.begins_with("@rpc"):
			continue
		# La signature peut être séparée de l'annotation par des commentaires.
		for j in range(i + 1, mini(i + 12, lignes.size())):
			var suite := String(lignes[j]).strip_edges()
			if suite.begins_with("func "):
				out.append("%s %s" % [ligne, suite])
				break
	return out

## En **début de ligne** seulement, et la nuance a mordu tout de suite : chercher
## « @rpc » n'importe où dans le fichier faisait dénoncer `protocol.gd` lui-même,
## dont la documentation cite l'annotation en exemple. Un détecteur qui accuse le
## fichier expliquant la règle est un détecteur qu'on finit par ignorer.
func _porte_un_rpc(chemin: String) -> bool:
	for ligne in _lire(chemin).split("\n"):
		if String(ligne).strip_edges().begins_with("@rpc"):
			return true
	return false

func _constante(chemin: String, nom: String) -> String:
	for ligne in _lire(chemin).split("\n"):
		var l := String(ligne).strip_edges()
		if l.begins_with("const %s " % nom) or l.begins_with("const %s:" % nom):
			return l
	return "ABSENTE"

func _lire(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	return f.get_as_text() if f != null else ""

## Les scripts du jeu, à plat à la racine. `tools/` est exclu : un banc peut
## définir ses propres RPC de doublure sans que ce soit le protocole du jeu.
func _tous_les_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://")
	if d == null:
		return out
	d.list_dir_begin()
	var nom := d.get_next()
	while nom != "":
		if not d.current_is_dir() and nom.ends_with(".gd"):
			out.append("res://" + nom)
		nom = d.get_next()
	d.list_dir_end()
	return out
