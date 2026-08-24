## Test headless du système de mise à jour — Phase 9, étape 1.
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • **rien ne s'installe sans signature valide** — c'est la propriété dont
##     tout le reste dépend. Un fichier écrit par `HTTPRequest` ne porte pas
##     l'attribut de quarantaine de macOS : aucun système d'exploitation ne
##     vérifiera à notre place ce que ce code fait exécuter au joueur ;
##   • **le refus est poli** — une version de retard n'empêche rien : ni de
##     démarrer, ni de jouer en écran scindé, ni d'ouvrir l'éditeur. La seule
##     chose qui cesse est de trouver un adversaire en ligne, et elle a déjà
##     cessé toute seule (`Protocol.accepts` refuse symétriquement). L'écran le
##     nomme, il ne verrouille pas ;
##   • **un type de paquet inconnu s'ignore, un paquet incomplet crie** — les deux
##     se ressemblent et n'ont pas du tout la même conséquence : le premier est
##     l'extension future qu'on veut pouvoir publier sans casser les jeux
##     installés, le second est un défaut de publication qu'il faut voir avant
##     qu'un joueur ne télécharge cent mégaoctets invérifiables ;
##   • **le correctif s'applique au socle, jamais à un empilement** — deux
##     correctifs superposés donneraient un état que personne n'a testé ;
##   • **le script d'échange attend la fermeture du jeu et garde l'ancienne
##     installation** — c'est le seul geste irréversible du système, et la seule
##     façon de l'éprouver sur une machine d'intégration est de lire le script
##     qu'il produit ;
##   • **un correctif qui empêche le démarrage est écarté au démarrage suivant** —
##     sinon le système censé réparer le jeu est celui qui le casse
##     définitivement.
##
## `patch_loader.gd` lit `user://maj/` — celui du jeu installé. La suite en fait
## une copie de sauvegarde avant de le manipuler, le restaure ensuite, et le
## dernier contrôle est que rien n'a bougé.
##
## Lancer : godot --headless --path . --script res://tools/test_mise_a_jour.gd
extends SceneTree

const REGISTRE := "user://maj/correctif.json"
const TEMOIN := "user://maj/en_essai"

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, le registre
## des classes globales n'est pas encore en portée. `load()` par chemin ne
## dépend pas de ce cache.
var _Manifeste: GDScript
var _Installeur: GDScript
var _Patch: GDScript
var _Ecran: GDScript

## Sauvegarde de l'état réel de `user://maj/`, restauré à la fin.
var _sauvegarde: Dictionary = {}

func _init() -> void:
	print("=== Test du système de mise à jour ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_Manifeste = load("res://update_manifest.gd")
	_Installeur = load("res://update_installer.gd")
	_Patch = load("res://patch_loader.gd")
	_Ecran = load("res://screen_update.gd")

	_test_lecture()
	_test_versions()
	_test_choix_paquet()
	_test_refus_poli()
	_test_signature()
	_test_racines()
	_test_script_echange()
	_sauver_etat()
	_test_correctif()
	_restaurer_etat()
	_test_ecran()

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
# LECTURE DU MANIFESTE
# ---------------------------------------------------------------------------

## Le manifeste de référence, construit comme un dictionnaire et non comme du
## texte à trous : une variante se fabrique en changeant une clé, jamais par une
## substitution de chaîne. Une substitution qui ne trouve pas sa cible ne dit
## rien et laisse un test vert qui n'a rien exercé — le mode de défaillance que
## ce dépôt traque partout ailleurs.
func _base(extra: Array = []) -> Dictionary:
	var paquets: Array = [{
		"type": "bundle", "plateforme": "windows", "arch": "x86_64",
		"url": "https://exemple.test/candela-0.2.0-windows.zip",
		"octets": 90000000, "sha256": "a".repeat(64), "racine": "Candela",
	}]
	paquets.append_array(extra)
	return {
		"format": 1, "version": "0.2.0", "protocole": 2,
		"publie_le": "2026-08-19", "notes": "Deuxième version.",
		"paquets": paquets,
	}

func _lire(d: Dictionary) -> Object:
	return _Manifeste.depuis_json(JSON.stringify(d))

func _test_lecture() -> void:
	print("\n[Lecture du manifeste]")
	var m: Object = _lire(_base())
	_check("un manifeste bien formé est valide", m.valide(), m.erreur)
	_check("la version est lue", m.version == "0.2.0", m.version)
	_check("le protocole est lu", m.protocole == 2, str(m.protocole))
	_check("le paquet est retenu", m.paquets.size() == 1, str(m.paquets.size()))

	# Le cas qu'on ne peut pas rattraper après coup : un manifeste écrit par un
	# outil plus récent que le jeu installé. Ce n'est pas « illisible », c'est
	# « vous êtes trop vieux » — et la phrase doit dire quoi faire.
	var futur_d := _base()
	futur_d["format"] = 99
	var futur: Object = _lire(futur_d)
	_check("un format plus récent est refusé", not futur.valide())
	_check("… et le dit au joueur, pas à l'auteur",
		futur.erreur.to_lower().contains("à la main"), futur.erreur)

	_check("un texte qui n'est pas du JSON est refusé",
		not _Manifeste.depuis_json("ceci n'est pas du json").valide())
	_check("un JSON qui n'est pas un objet est refusé",
		not _Manifeste.depuis_json("[1, 2, 3]").valide())

	for cas: Dictionary in [
		{"nom": "sans version", "cle": "version", "valeur": ""},
		{"nom": "avec une version illisible", "cle": "version", "valeur": "hier"},
		{"nom": "sans protocole", "cle": "protocole", "valeur": 0},
		{"nom": "sans liste de paquets", "cle": "paquets", "valeur": "aucune"},
	]:
		var d := _base()
		d[cas["cle"]] = cas["valeur"]
		var r: Object = _lire(d)
		_check("un manifeste %s est refusé" % cas["nom"], not r.valide(), "accepté à tort")
		_check("… avec une raison", r.erreur != "")

	# Tout nombre relu d'un JSON revient en flottant. Le piège a déjà coûté une
	# soirée sur le journal des matchs ; ici il rendrait tous les manifestes
	# invalides — ce qui se voit, mais seulement une fois publié.
	var flottant_d := _base()
	flottant_d["protocole"] = 2.0
	var flottant: Object = _lire(flottant_d)
	_check("un protocole relu en flottant reste lisible",
		flottant.valide() and flottant.protocole == 2, flottant.erreur)

	# LA distinction du fichier : inconnu n'est pas incomplet.
	var inconnu: Object = _lire(_base([{
		"type": "delta_futur", "url": "https://exemple.test/x", "sha256": "z",
	}]))
	_check("un type de paquet inconnu est ignoré, pas refusé",
		inconnu.valide() and inconnu.paquets.size() == 1,
		inconnu.erreur + " / " + str(inconnu.paquets.size()))

	for defaut: Dictionary in [
		{"nom": "sans empreinte", "cle": "sha256", "valeur": ""},
		{"nom": "avec une empreinte trop courte", "cle": "sha256", "valeur": "abc"},
		{"nom": "sans url", "cle": "url", "valeur": ""},
		{"nom": "en http au lieu de https", "cle": "url", "valeur": "http://exemple.test/x.zip"},
		{"nom": "sans taille", "cle": "octets", "valeur": 0},
	]:
		var d := _base()
		d["paquets"][0][defaut["cle"]] = defaut["valeur"]
		_check("un paquet connu %s rend le manifeste invalide" % defaut["nom"],
			not _lire(d).valide(), "accepté à tort")

	# Un correctif doit dire sur quel socle il s'applique : sans `socle_min`, il
	# s'appliquerait sur n'importe quoi, y compris sur un socle qui ne contient
	# plus les fichiers qu'il recouvre.
	var sans_socle: Object = _lire(_base([{
		"type": "pck", "url": "https://exemple.test/p.pck",
		"octets": 4000000, "sha256": "b".repeat(64),
	}]))
	_check("un correctif sans socle_min est refusé", not sans_socle.valide())

# ---------------------------------------------------------------------------
# VERSIONS
# ---------------------------------------------------------------------------

func _test_versions() -> void:
	print("\n[Comparaison des versions]")
	_check("0.1.0 < 0.2.0", _Manifeste.comparer("0.1.0", "0.2.0") < 0)
	# Le cas que la comparaison de chaînes rate toujours, et qui arrive une fois
	# par projet — au dixième correctif.
	_check("0.9.0 < 0.10.0", _Manifeste.comparer("0.9.0", "0.10.0") < 0)
	_check("1.0 == 1.0.0", _Manifeste.comparer("1.0", "1.0.0") == 0)
	_check("0.2.0 > 0.1.9", _Manifeste.comparer("0.2.0", "0.1.9") > 0)
	_check("une pré-version précède sa version",
		_Manifeste.comparer("0.2.0-rc1", "0.2.0") < 0)
	_check("« hier » n'est pas une version", not _Manifeste.est_version("hier"))
	_check("« » n'est pas une version", not _Manifeste.est_version(""))
	_check("0.2.0-rc1 en est une", _Manifeste.est_version("0.2.0-rc1"))

	var m: Object = _lire(_base())
	_check("plus ancien → disponible", m.etat_pour("0.1.0") == _Manifeste.Etat.DISPONIBLE)
	_check("identique → à jour", m.etat_pour("0.2.0") == _Manifeste.Etat.A_JOUR)
	# Un build de développement est en avance sur ce qui est publié. Ce n'est pas
	# une erreur, et surtout pas une invitation à « revenir » à la version
	# publiée : rétrograder effacerait le travail en cours.
	_check("plus récent → en avance, et ce n'est pas une erreur",
		m.etat_pour("0.3.0") == _Manifeste.Etat.EN_AVANCE)

# ---------------------------------------------------------------------------
# CHOIX DU PAQUET
# ---------------------------------------------------------------------------

func _avec_correctif(socle_min: String, socle_max: String) -> Object:
	return _lire(_base([{
		"type": "pck", "plateforme": "*",
		"url": "https://exemple.test/candela-0.2.0.pck",
		"octets": 4200000, "sha256": "b".repeat(64),
		"socle_min": socle_min, "socle_max": socle_max,
	}]))

func _test_choix_paquet() -> void:
	print("\n[Choix du paquet]")
	var m: Object = _lire(_base())
	var p: Dictionary = m.paquet_pour("windows", "x86_64", "0.1.0")
	_check("le bundle Windows est retenu", p.get("type", "") == "bundle")
	_check("… et rien pour macOS", m.paquet_pour("macos", "arm64", "0.1.0").is_empty())
	_check("… ni pour une autre architecture",
		m.paquet_pour("windows", "arm64", "0.1.0").is_empty())

	# Le paquet macOS de Godot est un binaire universel : l'annoncer « x86_64 »
	# le ferait refuser par tous les Mac Apple Silicon, avec pour seul symptôme
	# « aucun paquet ne correspond à cette machine ». Une architecture vide veut
	# dire « convient partout », et c'est ce que `fabrique_manifeste.sh` écrit
	# pour macOS.
	var universel := _base()
	universel["paquets"][0]["plateforme"] = "macos"
	universel["paquets"][0]["arch"] = ""
	var u: Object = _lire(universel)
	_check("un paquet sans architecture convient à l'arm64",
		not u.paquet_pour("macos", "arm64", "0.1.0").is_empty())
	_check("… comme au x86_64",
		not u.paquet_pour("macos", "x86_64", "0.1.0").is_empty())

	# Le moins cher qui s'applique gagne : quelques mégaoctets referment la
	# fracture entre versions bien plus vite que cent.
	var avec: Object = _avec_correctif("0.1.0", "0.1.0")
	_check("un correctif applicable est préféré au bundle",
		avec.paquet_pour("windows", "x86_64", "0.1.0").get("type", "") == "pck")
	_check("un correctif hors intervalle laisse la place au bundle",
		avec.paquet_pour("windows", "x86_64", "0.0.9").get("type", "") == "bundle")
	var borne: Object = _avec_correctif("0.1.0", "")
	_check("sans socle_max, tout socle plus récent que le minimum convient",
		borne.paquet_pour("windows", "x86_64", "0.1.5").get("type", "") == "pck")
	_check("un socle plus ancien que socle_min ne convient pas",
		borne.paquet_pour("windows", "x86_64", "0.0.1").get("type", "") == "bundle")
	# Le correctif s'applique au SOCLE, pas à ce qu'un correctif précédent a déjà
	# posé : deux correctifs empilés donneraient un état que personne n'a testé.
	_check("un correctif d'un autre socle est écarté même si la version colle",
		_avec_correctif("0.2.0", "0.2.0").paquet_pour(
			"windows", "x86_64", "0.1.0").get("type", "") == "bundle")

# ---------------------------------------------------------------------------
# LE REFUS POLI
# ---------------------------------------------------------------------------

func _test_refus_poli() -> void:
	print("\n[Refus poli — décision d'Adrien, 2026-08-24]")
	var m: Object = _lire(_base())
	_check("même protocole : rien à dire", m.message_en_ligne(2) == "")
	var msg: String = m.message_en_ligne(3)
	_check("protocole différent : on le dit", msg != "")
	_check("… en nommant ce qui ne marchera plus",
		msg.to_lower().contains("adversaire"), msg)
	_check("… et en disant que le reste marche encore",
		msg.to_lower().contains("continue de fonctionner"), msg)
	for mot: String in ["obligatoire", "impossible de jouer", "vous devez", "quitter"]:
		_check("… sans « %s »" % mot, not msg.to_lower().contains(mot), msg)

	# La propriété structurelle derrière la phrase : un protocole différent ne
	# fabrique pas d'état spécial. Rien dans le manifeste ne peut forcer quoi que
	# ce soit, parce qu'il n'y a aucun champ pour le dire.
	var autre_protocole := _base()
	autre_protocole["protocole"] = 7
	var meme_version: Object = _lire(autre_protocole)
	_check("un protocole différent ne rend pas une version « à installer »",
		meme_version.etat_pour("0.2.0") == _Manifeste.Etat.A_JOUR)

# ---------------------------------------------------------------------------
# SIGNATURE — LA PROPRIÉTÉ DONT TOUT LE RESTE DÉPEND
# ---------------------------------------------------------------------------

func _test_signature() -> void:
	print("\n[Signature de l'annonce]")
	var crypto := Crypto.new()
	var cle := crypto.generate_rsa(2048)
	var publique := cle.save_to_string(true)
	var autre := crypto.generate_rsa(2048)

	var charge := JSON.stringify(_base()).to_utf8_buffer()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(charge)
	var signature := crypto.sign(HashingContext.HASH_SHA256, ctx.finish(), cle)

	_check("une signature valide est acceptée",
		_Manifeste.verifier_signature(charge, signature, publique))

	# Un octet, un seul. C'est exactement ce qu'une substitution en chemin
	# changerait : l'url d'un paquet, pas le reste du fichier.
	var altere := JSON.stringify(_base()).replace(
		"exemple.test", "exemp1e.test").to_utf8_buffer()
	_check("un manifeste modifié est refusé",
		not _Manifeste.verifier_signature(altere, signature, publique))

	var ctx2 := HashingContext.new()
	ctx2.start(HashingContext.HASH_SHA256)
	ctx2.update(charge)
	var fausse := crypto.sign(HashingContext.HASH_SHA256, ctx2.finish(), autre)
	_check("une signature d'une autre clé est refusée",
		not _Manifeste.verifier_signature(charge, fausse, publique))

	# Sans clé publique, le système est inerte — et surtout : il ne « laisse pas
	# passer ». C'est le mode dégradé du jeu tant que la paire n'est pas faite,
	# et le laisser accepter reviendrait à n'avoir aucune signature du tout.
	_check("sans clé publique, rien n'est accepté",
		not _Manifeste.verifier_signature(charge, signature, ""))
	_check("une clé illisible n'accepte rien",
		not _Manifeste.verifier_signature(charge, signature, "pas une clé"))
	_check("une signature vide n'est pas acceptée",
		not _Manifeste.verifier_signature(charge, PackedByteArray(), publique))

# ---------------------------------------------------------------------------
# OÙ LE JEU EST INSTALLÉ
# ---------------------------------------------------------------------------

func _test_racines() -> void:
	print("\n[Racine de l'installation]")
	_check("macOS : on remonte jusqu'au .app",
		_Installeur.racine_pour("/Applications/Candela.app/Contents/MacOS/Candela 2D",
			"macos") == "/Applications/Candela.app")
	_check("… même sous un chemin profond",
		_Installeur.racine_pour("/Users/a/Jeux/Candela.app/Contents/MacOS/x", "macos")
			== "/Users/a/Jeux/Candela.app")
	_check("… et rien si aucun .app dans le chemin",
		_Installeur.racine_pour("/usr/local/bin/candela", "macos") == "")
	_check("Windows : le dossier de l'exécutable",
		_Installeur.racine_pour("C:/Jeux/Candela/Candela.exe", "windows")
			== "C:/Jeux/Candela")
	_check("Linux : le dossier de l'exécutable",
		_Installeur.racine_pour("/opt/candela/Candela.x86_64", "linux") == "/opt/candela")

	# Sous macOS on relance le bundle, pas le binaire : `open` passe par
	# LaunchServices, seul chemin qui rende au jeu un vrai contexte
	# d'application (premier plan, icône, événements).
	_check("macOS : on relance le bundle",
		_Installeur.executable_relance_pour("/Applications/Candela.app",
			"/Applications/Candela.app/Contents/MacOS/Candela", "macos")
			== "/Applications/Candela.app")
	_check("Windows : on relance l'exécutable",
		_Installeur.executable_relance_pour("C:/Jeux/Candela",
			"C:/Jeux/Candela/Candela.exe", "windows") == "C:/Jeux/Candela/Candela.exe")

# ---------------------------------------------------------------------------
# LE SCRIPT D'ÉCHANGE — LE SEUL GESTE IRRÉVERSIBLE
# ---------------------------------------------------------------------------

func _test_script_echange() -> void:
	print("\n[Script d'échange]")
	var sh: String = _Installeur.script_echange(4242, "/Applications/Candela.app",
		"/Applications/.candela-maj/Candela.app", "/Applications/Candela.app.ancien",
		"/Applications/Candela.app", "macos", "/tmp/echange.log")
	_check("le script porte le pid du jeu", sh.contains("4242"), sh)
	_check("il attend que le processus ait disparu", sh.contains("kill -0"))
	_check("il ne s'attend pas indéfiniment", sh.contains("-gt 120"))

	# LA propriété : rien n'est touché tant que le jeu tourne. On le vérifie par
	# l'ordre du texte, parce qu'aucune machine d'intégration ne peut exécuter ce
	# script pour de vrai.
	var attente := sh.find("kill -0")
	var deplacement := sh.find('mv "$CIBLE"')
	_check("… et le déplacement vient APRÈS l'attente",
		attente >= 0 and deplacement > attente, "%d / %d" % [attente, deplacement])

	_check("l'ancienne installation est gardée, pas effacée",
		sh.contains('mv "$CIBLE" "$ANCIEN"'))
	_check("… et remise en place si la nouvelle ne s'installe pas",
		sh.contains('mv "$ANCIEN" "$CIBLE"'))
	_check("le jeu est relancé dans les deux cas",
		sh.count("$RELANCE") >= 2, str(sh.count("$RELANCE")))
	_check("rien n'efface la cible", not sh.contains('rm -rf "$CIBLE"'))

	var bat: String = _Installeur.script_echange(77, "C:/Jeux/Candela",
		"C:/Jeux/.candela-maj/Candela", "C:/Jeux/Candela.ancien",
		"C:/Jeux/Candela/Candela.exe", "windows", "C:/Jeux/log.txt")
	_check("Windows : il attend la fin du processus", bat.contains("tasklist"))
	_check("Windows : le pid est celui du jeu", bat.contains("set \"PID=77\""), bat)
	_check("Windows : les variables sont bien citées", bat.contains("%CIBLE%"), bat)
	var attente_w := bat.find("tasklist")
	var deplacement_w := bat.find('move "%CIBLE%"')
	_check("Windows : le déplacement vient APRÈS l'attente",
		attente_w >= 0 and deplacement_w > attente_w)
	_check("Windows : retour en arrière prévu", bat.contains('move "%ANCIEN%" "%CIBLE%"'))
	_check("Windows : le jeu est relancé", bat.contains('start "" "%RELANCE%"'))

	# Un chemin qu'on ne sait pas citer ne produit PAS un script approximatif :
	# un script mal cité effacerait autre chose que ce qu'il croit effacer.
	_check("un chemin avec une apostrophe est refusé, pas mal cité",
		_Installeur.script_echange(1, "/Users/l'ami/Candela.app", "/b", "/c", "/d",
			"macos", "/e") == "")
	_check("Windows : un chemin avec un guillemet est refusé",
		_Installeur.script_echange(1, 'C:/a"b', "C:/b", "C:/c", "C:/d",
			"windows", "C:/e") == "")
	_check("Windows : un chemin avec un pourcent est refusé",
		_Installeur.script_echange(1, "C:/%TEMP%", "C:/b", "C:/c", "C:/d",
			"windows", "C:/e") == "")

# ---------------------------------------------------------------------------
# LE CORRECTIF ET SON TÉMOIN
# ---------------------------------------------------------------------------

func _sauver_etat() -> void:
	for chemin: String in [REGISTRE, TEMOIN]:
		if FileAccess.file_exists(chemin):
			_sauvegarde[chemin] = FileAccess.get_file_as_bytes(chemin)

func _restaurer_etat() -> void:
	print("\n[L'état réel du joueur est rendu intact]")
	for chemin: String in [REGISTRE, TEMOIN]:
		if FileAccess.file_exists(chemin):
			DirAccess.remove_absolute(chemin)
	for chemin: String in _sauvegarde:
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_buffer(_sauvegarde[chemin])
		f.close()
	var intact := true
	for chemin: String in _sauvegarde:
		intact = intact and FileAccess.get_file_as_bytes(chemin) == _sauvegarde[chemin]
	_check("les fichiers de mise à jour du joueur sont restaurés", intact)

func _ecrire(chemin: String, texte: String) -> void:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()

func _monter(registre: Dictionary, fichier_present: bool) -> Object:
	var pck := "user://maj/correctifs/essai.pck"
	if fichier_present:
		_ecrire(pck, "ceci n'est pas un vrai pck")
	elif FileAccess.file_exists(pck):
		DirAccess.remove_absolute(pck)
	registre["fichier"] = pck
	_ecrire(REGISTRE, JSON.stringify(registre))
	var chargeur: Object = _Patch.new()
	return chargeur

func _test_correctif() -> void:
	print("\n[Correctif : ce qui est monté, et ce qui est écarté]")
	var socle := str(ProjectSettings.get_setting("application/config/version", ""))
	_check("le socle a une version", socle != "", socle)

	# Un correctif inscrit pour un AUTRE socle : une mise à jour complète est
	# passée entre-temps, et le correctif recouvrirait des fichiers d'une version
	# qu'il n'a jamais vue.
	var autre: Object = _monter({"format": 1, "version": "9.9.9",
		"socle": "0.0.1-autre", "sha256": ""}, true)
	_check("un correctif d'un autre socle n'est pas monté", autre.version_appliquee == "")
	_check("… et son registre est oublié", not FileAccess.file_exists(REGISTRE))
	autre.free()

	# Empreinte revérifiée à chaque démarrage : entre l'installation et le
	# démarrage suivant il y a un disque, un antivirus, une synchronisation.
	var abime: Object = _monter({"format": 1, "version": "9.9.9", "socle": socle,
		"sha256": "c".repeat(64)}, true)
	_check("un correctif abîmé n'est pas monté", abime.version_appliquee == "")
	_check("… et le joueur en est informé", abime.incident != "", abime.incident)
	_check("… et le fichier est effacé",
		not FileAccess.file_exists("user://maj/correctifs/essai.pck"))
	abime.free()

	var disparu: Object = _monter({"format": 1, "version": "9.9.9", "socle": socle,
		"sha256": ""}, false)
	_check("un correctif disparu du disque n'est pas monté",
		disparu.version_appliquee == "")
	_check("… et le registre ne le réclame pas éternellement",
		not FileAccess.file_exists(REGISTRE))
	disparu.free()

	# Le témoin : le démarrage précédent n'est jamais arrivé jusqu'au menu.
	# Sans ce chemin, un correctif défaillant laisse un jeu qui ne démarre plus
	# et un joueur qui n'a plus que la réinstallation.
	_ecrire(REGISTRE, JSON.stringify({"format": 1, "version": "9.9.9",
		"socle": socle, "fichier": "user://maj/correctifs/essai.pck", "sha256": ""}))
	_ecrire("user://maj/correctifs/essai.pck", "peu importe")
	_ecrire(TEMOIN, "9.9.9")
	var apres_plantage: Object = _Patch.new()
	_check("un correctif qui a empêché le démarrage est écarté",
		apres_plantage.version_appliquee == "")
	_check("… le témoin est levé", not FileAccess.file_exists(TEMOIN))
	_check("… le joueur apprend pourquoi le jeu est revenu en arrière",
		apres_plantage.incident.to_lower().contains("démarrer"),
		apres_plantage.incident)
	# La quarantaine garde la pièce à conviction : un correctif qui casse le
	# démarrage est le seul cas où on aura besoin du fichier pour comprendre.
	_check("… et le correctif est gardé en quarantaine, pas effacé",
		FileAccess.file_exists(REGISTRE + ".suspect")
			or FileAccess.file_exists("user://maj/correctifs/essai.pck.suspect"))
	apres_plantage.free()
	for reste: String in ["user://maj/correctif.json.suspect",
			"user://maj/correctifs/essai.pck.suspect",
			"user://maj/correctifs/essai.pck"]:
		if FileAccess.file_exists(reste):
			DirAccess.remove_absolute(reste)

	# Rien en attente : le cas de tous les jours, et il ne doit rien coûter.
	var vide: Object = _Patch.new()
	_check("sans correctif en attente, rien n'est monté ni signalé",
		vide.version_appliquee == "" and vide.incident == "")
	vide.free()

# ---------------------------------------------------------------------------
# L'ÉCRAN
# ---------------------------------------------------------------------------

## Doublure du gestionnaire. Elle COMPTE les déclenchements : c'est le seul moyen
## de prouver qu'afficher l'écran ne lance rien — un écran qui vérifierait au
## simple affichage sortirait sur le réseau à chaque passage dans le menu.
class FauxGestionnaire extends Node:
	signal etat_change(etat: int)
	signal progression(recu: int, total: int)

	var resume_rendu: Dictionary = {}
	var action: String = "verifier"
	var libelle: String = "VÉRIFIER MAINTENANT"
	var diagnostic: Dictionary = {"ok": true, "raison": ""}
	var version: String = "0.1.0"
	var socle: String = "0.1.0"
	var declenchements: int = 0

	func resume() -> Dictionary:
		return resume_rendu
	func action_suivante() -> String:
		return action
	func libelle_action() -> String:
		return libelle
	func peut_installer() -> Dictionary:
		return diagnostic
	func version_installee() -> String:
		return version
	func version_socle() -> String:
		return socle
	func declencher() -> void:
		declenchements += 1

func _monter_ecran(faux: FauxGestionnaire) -> Array:
	var corps := VBoxContainer.new()
	var ecran: Object = _Ecran.new()
	ecran.source = faux
	corps.add_child(ecran)
	ecran.build(corps)
	return [ecran, corps]

func _texte_des_labels(corps: Node) -> String:
	var tout := ""
	for enfant: Node in corps.get_children():
		if enfant is Label and (enfant as Label).visible:
			tout += (enfant as Label).text + "\n"
	return tout

func _test_ecran() -> void:
	print("\n[Écran de mise à jour]")
	var faux := FauxGestionnaire.new()
	faux.resume_rendu = {"titre": "Version 0.2.0 disponible", "detail": "90 Mo",
		"notes": "Deuxième version.", "en_ligne": "", "incident": "", "telecharge": false}
	var monte := _monter_ecran(faux)
	var ecran: Object = monte[0]
	var corps: Node = monte[1]

	var texte := _texte_des_labels(corps)
	_check("l'écran montre ce que le gestionnaire dit",
		texte.contains("Version 0.2.0 disponible"), texte)
	_check("… et la version qui tourne", texte.contains("0.1.0"), texte)
	# LA propriété à ne jamais laisser régresser : afficher ne déclenche rien.
	_check("afficher l'écran ne déclenche aucune action", faux.declenchements == 0)

	ecran.refresh()
	ecran.refresh()
	_check("refresh() est idempotent",
		_texte_des_labels(corps) == texte, _texte_des_labels(corps))

	# Une action qui ne pourra pas aboutir n'est pas proposée : on dit pourquoi.
	faux.action = "telecharger"
	faux.libelle = "TÉLÉCHARGER"
	faux.diagnostic = {"ok": false, "raison": "Glissez Candela dans Applications."}
	ecran.refresh()
	var bouton := corps.find_child("Action", true, false) as Button
	_check("un téléchargement impossible ne montre pas de bouton",
		bouton != null and not bouton.visible)
	_check("… et la raison est affichée",
		_texte_des_labels(corps).contains("Applications"), _texte_des_labels(corps))

	faux.diagnostic = {"ok": true, "raison": ""}
	ecran.refresh()
	_check("le bouton revient quand l'installation est possible",
		bouton.visible and bouton.text == "TÉLÉCHARGER", bouton.text)

	# Rien à proposer : le bouton disparaît au lieu d'être grisé. Un bouton grisé
	# oblige le joueur à deviner ce qu'il ferait s'il était actif.
	faux.action = ""
	faux.libelle = ""
	ecran.refresh()
	_check("sans action, aucun bouton grisé ne subsiste", not bouton.visible)

	# La version qui tourne, pas celle qui est installée : un rapport de bug qui
	# nomme la mauvaise version envoie chercher au mauvais endroit.
	faux.version = "0.1.1"
	faux.socle = "0.1.0"
	ecran.refresh()
	var v := _texte_des_labels(corps)
	_check("un correctif monté se voit dans la version affichée",
		v.contains("0.1.1") and v.contains("0.1.0") and v.contains("correctif"), v)

	# Le refus poli : la phrase est affichée telle quelle, rien n'est verrouillé.
	faux.resume_rendu["en_ligne"] = ("Les parties en ligne demandent la même "
		+ "version des deux côtés.")
	ecran.refresh()
	_check("l'avis sur le jeu en ligne est affiché",
		_texte_des_labels(corps).contains("des deux côtés"))
	_check("… et il n'a fermé ni bloqué quoi que ce soit",
		corps.get_parent() == null and faux.declenchements == 0)

	# Un écran jamais construit doit survivre à un rafraîchissement : le hub en
	# rafraîchit avant de les montrer.
	var vierge: Object = _Ecran.new()
	vierge.refresh()
	_check("refresh() sur un écran jamais construit ne plante pas", true)
	vierge.free()

	corps.free()
	faux.free()
