extends Node

## UpdateManager — Autoload. La mise à jour du jeu installé, de bout en bout.
## Phase 9, étape 1.
##
## ## Le partage des rôles
##
## - `update_manifest.gd` **juge** : quelle version est publiée, laquelle prendre,
##   ce que ça change pour le jeu en ligne. Sans réseau, donc vérifiable.
## - `update_installer.gd` **pose** : décompresser, échanger, relancer. Le seul
##   fichier qui sache ce qu'est un `.app` ou un dossier Windows.
## - ce fichier **enchaîne** : télécharger, vérifier, appeler l'un puis l'autre,
##   et raconter où on en est.
## - `screen_update.gd` **montre**, et ne décide rien.
##
## ## Quatre refus, énoncés une fois pour toutes
##
## 1. **Rien n'est jamais installé sans signature valide.** Un fichier écrit par
##    `HTTPRequest` ne porte pas l'attribut de quarantaine de macOS : le système
##    d'exploitation ne vérifiera rien à notre place. Si la clé publique n'est pas
##    renseignée, le jeu dit « mises à jour non configurées » et s'arrête là —
##    comme il dit « EOS non configuré » sans identifiants.
## 2. **Rien n'est jamais installé automatiquement.** La vérification est
##    silencieuse, l'installation est un geste du joueur. Un jeu compétitif qui se
##    met à jour tout seul peut changer le comportement d'une arme entre deux
##    manches d'une même soirée.
## 3. **Rien n'est jamais bloqué** — décision d'Adrien, 2026-08-24 : refus poli.
##    Une version de retard rend le jeu en ligne inopérant, ce que
##    `Protocol.accepts()` fait déjà tout seul ; l'écran le **nomme**, il ne
##    verrouille rien. Écran scindé, entraînement et éditeur de cartes continuent.
## 4. **Rien n'est vérifié pendant un match.** La vérification automatique
##    n'existe qu'au démarrage, hors éditeur et hors headless.
##
## ## Deux chemins, une seule décision — et elle est prise à la publication
##
## `bundle` remplace l'installation entière ; `pck` ne pose qu'un correctif de
## quelques mégaoctets par-dessus le socle. Le jeu ne choisit pas la stratégie : il
## prend le paquet le moins cher que le manifeste rend applicable. Ce qui est
## publiable en correctif se décide au moment de publier — voir `docs/MISE_A_JOUR.md`.

## L'adresse ne bouge jamais, et c'est ce qui la rend utilisable : GitHub redirige
## `latest/download/<fichier>` vers la dernière publication non préliminaire. Un
## jeu installé aujourd'hui trouvera encore l'annonce dans deux ans, sans avoir eu
## besoin de connaître le numéro de la version qui la porte.
const URL_MANIFESTE := "https://github.com/adrienvada/Candela-2D---Godot/releases/latest/download/manifeste.json"
const URL_SIGNATURE := URL_MANIFESTE + ".sig"

## La clé **publique** de signature, en PEM. Elle est faite pour être lue par tout
## le monde : la publier ici est sans risque, c'est la privée qui compte, et elle
## ne quitte jamais les secrets GitHub.
##
## Tant que cette constante est vide, le jeu se déclare « mises à jour non
## configurées » et ne télécharge rien — dégradation franche, même patron que
## `eos_credentials.gd` absent. La fabrication de la paire est un jalon humain
## (H8) : `docs/MISE_A_JOUR.md` donne les deux commandes.
const CLE_PUBLIQUE := """-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAu8ICiegdFuMq0rAytB8f
0gO3C3+gBIp2dFxKK5XX/nQjKwisaneHPp7pBrteGogJgoCXV083guwDPHZ4eI6m
MecFSBa+JSVseVMoCTSaXGkB+fll2EFELcALLJRu+qZUlJe8W4XqMVmHrvxMaU+2
zshq0w//veykfUds5k2pzGLLc21GjEJx2Iy3PvhrocEKRd/8R5SLWxduCnOojbPy
8H5fwghCttkkXr+zAVPcg1neWcrlBjFUxY0JYh0XmhIRomXy0RJKkdNmVWLrg0rq
gWd5rMKLrYVV5OezGN7Jpg1bbykpLkuP7TsISOyKlYXfQHhgH93faMB2eh1Y1nZi
wBJFGWzNSApF4Vbh11YSkMpnDhdPzEsvwb4FhgYnpHO31ZlBsF7I1a+CWx/P97A3
vwEalNe4L6vGeQlPAnJyDOdDmLqc+99iJglq7AcLd55d6S5xWchlNF25b8gXLfPf
IaKvXrOjNpGE5YGoQnkBKq++Uh39jaQ0B2bkCyN29CHcuPu++N8R5RY37t2818hI
cr/8/5jefet/COZk5K5F/P3L2KuJQVRH3S1+HxZP5NczCEzN9MQvK9a3NbgmKQEC
+iAr9wCfw/e/dalpwzGljtJdpR3ZT62qricyTmsSVCMUArvPHdy4QJueMrNSEkOe
QdR7IOdYLWc6Fu6FelSoZiECAwEAAQ==
-----END PUBLIC KEY-----
"""

const DOSSIER := "user://maj"

## Le manifeste et sa signature sont minuscules ; un paquet ne l'est pas. Ces
## plafonds existent parce qu'un serveur qui répond n'importe quoi ne doit pas
## pouvoir faire gonfler la mémoire du jeu — même famille que le garde-fou
## anti-bombe de décompression du codec de cartes.
const TAILLE_MAX_MANIFESTE := 64 * 1024
const TAILLE_MAX_PAQUET := 600 * 1024 * 1024

## Le délai avant de considérer qu'un correctif monté n'empêche pas le démarrage.
## Assez long pour couvrir la construction du menu sur une machine lente, assez
## court pour que le joueur qui ferme aussitôt ne perde pas son correctif.
const DELAI_CONFIRMATION := 8.0

enum Etat {
	INACTIF,        ## Rien n'a encore été demandé.
	NON_CONFIGURE,  ## Pas de clé publique : le système est inerte, et le dit.
	VERIFICATION,   ## L'annonce est en cours de lecture.
	A_JOUR,         ## Vérifié, rien à faire.
	DISPONIBLE,     ## Une version plus récente existe, et un paquet convient.
	TELECHARGEMENT, ## En cours.
	PRET,           ## Téléchargé, vérifié, préparé. Il ne reste qu'à redémarrer.
	ERREUR,         ## `erreur` dit quoi, en français, au joueur.
}

signal etat_change(etat: int)
signal progression(recu: int, total: int)

var etat: Etat = Etat.INACTIF
var erreur: String = ""
var manifeste: UpdateManifest = null
var paquet: Dictionary = {}

var _http: HTTPRequest = null
var _installeur := UpdateInstaller.new()
var _archive: String = ""
var _neuf: String = ""
var _occupe: bool = false

# ---------------------------------------------------------------------------
# CE QUE LE JEU EST
# ---------------------------------------------------------------------------

## La version du **socle** : ce qui est installé sur le disque.
func version_socle() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## La version **qui tourne**. Différente du socle dès qu'un correctif est monté —
## et c'est celle-là qu'il faut montrer au joueur : afficher la version du fichier
## installé pendant qu'un correctif exécute autre chose, c'est se rendre incapable
## de diagnostiquer quoi que ce soit à distance.
func version_installee() -> String:
	var patch := get_node_or_null("/root/PatchLoader")
	if patch != null and str(patch.version_appliquee) != "":
		return str(patch.version_appliquee)
	return version_socle()

func configure() -> bool:
	return CLE_PUBLIQUE.strip_edges() != ""

## Le diagnostic d'installabilité, tel que l'écran doit le montrer : `{ok, raison}`.
func peut_installer() -> Dictionary:
	return _installeur.diagnostic()

# ---------------------------------------------------------------------------
# DÉMARRAGE
# ---------------------------------------------------------------------------

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	_http = HTTPRequest.new()
	_http.name = "UpdateHTTP"
	_http.use_threads = true
	_http.timeout = 30.0
	add_child(_http)
	# `_process` n'existe que pour la barre de progression : il reste éteint tant
	# qu'aucun téléchargement ne tourne.
	set_process(false)

	if not configure():
		_poser(Etat.NON_CONFIGURE, "")

	# Le ménage d'après-installation : si l'ancienne installation est encore là,
	# c'est que la nouvelle vient de démarrer — donc que l'échange a réussi. Tant
	# que ce démarrage n'avait pas eu lieu, l'ancienne était la seule chose qui
	# marchait à coup sûr, et le script d'échange a eu raison de la garder.
	if _est_installe():
		var racine := UpdateInstaller.racine_pour(OS.get_executable_path(),
			UpdateInstaller.plateforme())
		_installeur.nettoyer_apres_installation(racine)

	_confirmer_correctif_plus_tard()

	if _peut_verifier_seul():
		await get_tree().create_timer(3.0).timeout
		await verifier()

## Le correctif monté au démarrage n'est déclaré sain qu'une fois le jeu vivant :
## c'est ce constat, et lui seul, qui efface le témoin de `patch_loader.gd`.
func _confirmer_correctif_plus_tard() -> void:
	var patch := get_node_or_null("/root/PatchLoader")
	if patch == null:
		return
	await get_tree().create_timer(DELAI_CONFIRMATION).timeout
	patch.confirmer_demarrage()

## La vérification automatique n'a lieu que dans un jeu installé, avec une fenêtre.
## En headless elle ferait sortir du réseau les suites de tests, et dans l'éditeur
## elle annoncerait des mises à jour qu'on ne peut de toute façon pas installer.
func _peut_verifier_seul() -> bool:
	if not configure() or not _est_installe():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not OS.get_cmdline_args().has("--sans-maj")

func _est_installe() -> bool:
	return OS.has_feature("template")

# ---------------------------------------------------------------------------
# VÉRIFIER
# ---------------------------------------------------------------------------

## Lit l'annonce publiée et range le résultat dans `etat`. Ne télécharge aucun
## paquet, n'installe rien : c'est l'étape qu'on peut faire cent fois sans
## conséquence.
func verifier() -> void:
	if _occupe or not configure():
		return
	_occupe = true
	_poser(Etat.VERIFICATION, "")

	var texte := await _obtenir(URL_MANIFESTE, TAILLE_MAX_MANIFESTE)
	if texte.is_empty():
		_occupe = false
		_poser(Etat.ERREUR, "Impossible de joindre le serveur des mises à jour.")
		return
	var signature := await _obtenir(URL_SIGNATURE, TAILLE_MAX_MANIFESTE)
	if signature.is_empty():
		_occupe = false
		_poser(Etat.ERREUR, "L'annonce de mise à jour n'est pas signée : "
			+ "rien ne sera installé.")
		return

	# Sur les octets **exacts** tels que reçus : la signature est détachée
	# précisément pour n'avoir jamais à réécrire le JSON avant de le vérifier.
	if not UpdateManifest.verifier_signature(texte, _debase64(signature), CLE_PUBLIQUE):
		_occupe = false
		_poser(Etat.ERREUR, "La signature de l'annonce de mise à jour est "
			+ "invalide. Par précaution, rien ne sera téléchargé.")
		return

	var m := UpdateManifest.depuis_json(texte.get_string_from_utf8())
	if not m.valide():
		_occupe = false
		_poser(Etat.ERREUR, m.erreur)
		return
	manifeste = m
	_occupe = false

	match m.etat_pour(version_installee()):
		UpdateManifest.Etat.DISPONIBLE:
			paquet = m.paquet_pour(UpdateInstaller.plateforme(),
				UpdateInstaller.architecture(), version_socle())
			if paquet.is_empty():
				_poser(Etat.ERREUR, ("La version %s est publiée, mais aucun paquet "
					+ "ne correspond à cette machine.") % m.version)
			else:
				_poser(Etat.DISPONIBLE, "")
		_:
			paquet = {}
			_poser(Etat.A_JOUR, "")

## Ce qu'il faut dire du jeu en ligne, ou `""`. Le refus poli tient dans cette
## phrase : elle nomme ce qui ne marchera plus, sans rien empêcher.
func message_en_ligne() -> String:
	if manifeste == null or not manifeste.valide():
		return ""
	return manifeste.message_en_ligne(Protocol.VERSION)

# ---------------------------------------------------------------------------
# TÉLÉCHARGER ET PRÉPARER
# ---------------------------------------------------------------------------

## Télécharge le paquet retenu, vérifie son empreinte, et le prépare jusqu'au
## dernier geste réversible. À la sortie, `Etat.PRET` veut dire : il ne reste
## qu'à redémarrer, et tout ce qui pouvait échouer a déjà échoué.
func telecharger() -> void:
	if _occupe or paquet.is_empty():
		return
	var diag := peut_installer()
	if not diag["ok"]:
		_poser(Etat.ERREUR, str(diag["raison"]))
		return
	if int(paquet["octets"]) > TAILLE_MAX_PAQUET:
		_poser(Etat.ERREUR, "Le paquet annoncé est anormalement gros : "
			+ "rien ne sera téléchargé.")
		return

	_occupe = true
	_poser(Etat.TELECHARGEMENT, "")
	var nom := "candela-%s.%s" % [manifeste.version,
		"pck" if paquet["type"] == UpdateManifest.TYPE_PCK else "zip"]
	_archive = DOSSIER.path_join(nom)
	if FileAccess.file_exists(_archive):
		DirAccess.remove_absolute(_archive)

	_http.download_file = _archive
	set_process(true)
	var code := _http.request(str(paquet["url"]))
	if code != OK:
		_fin_telechargement("La mise à jour n'a pas pu être demandée.")
		return
	var reponse: Array = await _http.request_completed
	set_process(false)
	_http.download_file = ""
	if int(reponse[0]) != HTTPRequest.RESULT_SUCCESS or int(reponse[1]) != 200:
		_fin_telechargement("Le téléchargement s'est interrompu.")
		return

	# L'empreinte d'abord, la préparation ensuite : décompresser un fichier dont
	# on n'a pas vérifié l'origine reviendrait à lui faire écrire des chemins de
	# son choix à côté du jeu.
	if UpdateManifest.empreinte_fichier(_archive) != str(paquet["sha256"]):
		DirAccess.remove_absolute(_archive)
		_fin_telechargement("Le fichier téléchargé ne correspond pas à ce qui "
			+ "était annoncé. Il a été supprimé.")
		return

	if paquet["type"] == UpdateManifest.TYPE_PCK:
		_occupe = false
		_poser(Etat.PRET, "")
		return

	var racine := UpdateInstaller.racine_pour(OS.get_executable_path(),
		UpdateInstaller.plateforme())
	var prep := _installeur.preparer_bundle(_archive, racine, str(paquet["racine"]))
	if not prep["ok"]:
		_fin_telechargement(str(prep["raison"]))
		return
	_neuf = str(prep["neuf"])
	_occupe = false
	_poser(Etat.PRET, "")

func _fin_telechargement(raison: String) -> void:
	set_process(false)
	_http.download_file = ""
	_occupe = false
	_poser(Etat.ERREUR, raison)

func _process(_delta: float) -> void:
	if _http != null and etat == Etat.TELECHARGEMENT:
		progression.emit(_http.get_downloaded_bytes(), _http.get_body_size())

# ---------------------------------------------------------------------------
# INSTALLER
# ---------------------------------------------------------------------------

## Le seul geste irréversible du système, et il ne s'exécute qu'après un
## `Etat.PRET`. Le jeu se ferme par `NetworkManager.quit_game()` — l'unique porte
## de sortie du dépôt : quitter directement pendant qu'EOS tique fait entrer dans
## `EOS_Platform_Tick()` depuis sa propre pile, et le processus meurt en segfault
## au lieu de se mettre à jour.
func installer() -> void:
	if etat != Etat.PRET:
		return
	if paquet["type"] == UpdateManifest.TYPE_PCK:
		var pose := _installeur.installer_correctif(_archive, manifeste.version,
			version_socle(), str(paquet["sha256"]))
		if not pose["ok"]:
			_poser(Etat.ERREUR, str(pose["raison"]))
			return
		_installeur.relancer()
		NetworkManager.quit_game()
		return

	var racine := UpdateInstaller.racine_pour(OS.get_executable_path(),
		UpdateInstaller.plateforme())
	var applique := _installeur.appliquer_bundle(racine, _neuf)
	if not applique["ok"]:
		_poser(Etat.ERREUR, str(applique["raison"]))
		return
	NetworkManager.quit_game()

# ---------------------------------------------------------------------------
# CE QUE L'ÉCRAN AFFICHE
# ---------------------------------------------------------------------------

## Toute la mise en mots vit ici, pas dans l'écran, et ce n'est pas un détail
## d'organisation : l'écran ne doit pas avoir à connaître l'énumération d'états
## pour choisir une phrase. Une comparaison d'état recopiée dans l'interface est
## une comparaison qui cessera un jour d'être exhaustive — un état ajouté ici et
## l'écran affiche le libellé du précédent, sans que rien ne le signale.
##
## L'écran demande donc trois choses : un état en clair, un libellé de bouton, et
## le nom de l'action à déclencher. Il n'en interprète aucune.
func resume() -> Dictionary:
	var titre := ""
	var detail := ""
	match etat:
		Etat.NON_CONFIGURE:
			titre = "Mises à jour non configurées"
			detail = ("Ce build n'a pas de clé de vérification : il ne peut rien "
				+ "installer. Téléchargez les nouvelles versions à la main.")
		Etat.VERIFICATION:
			titre = "Vérification…"
		Etat.A_JOUR:
			titre = "Vous avez la dernière version"
			detail = "Vérifié à l'instant."
		Etat.DISPONIBLE:
			titre = "Version %s disponible" % manifeste.version
			detail = _poids(int(paquet.get("octets", 0)))
			if paquet.get("type", "") == UpdateManifest.TYPE_PCK:
				detail += " — correctif léger, le jeu redémarre seul."
		Etat.TELECHARGEMENT:
			titre = "Téléchargement…"
		Etat.PRET:
			titre = "Prêt à installer"
			detail = ("Tout a été téléchargé et vérifié. Le jeu va se fermer, "
				+ "s'installer et se rouvrir.")
		Etat.ERREUR:
			titre = "La mise à jour n'a pas abouti"
			detail = erreur
		_:
			titre = "Mise à jour"
	return {
		"titre": titre,
		"detail": detail,
		"notes": manifeste.notes if manifeste != null and manifeste.valide() else "",
		"en_ligne": message_en_ligne(),
		"incident": _incident_correctif(),
		"telecharge": etat == Etat.TELECHARGEMENT,
	}

## Le nom de ce qui se passera si le joueur appuie. `""` : rien à proposer, et
## l'écran n'affiche alors aucun bouton — plutôt qu'un bouton grisé dont personne
## ne sait ce qu'il ferait.
func action_suivante() -> String:
	match etat:
		Etat.INACTIF, Etat.A_JOUR, Etat.ERREUR: return "verifier"
		Etat.DISPONIBLE: return "telecharger"
		Etat.PRET: return "installer"
		_: return ""

func libelle_action() -> String:
	match action_suivante():
		"verifier": return "VÉRIFIER MAINTENANT"
		"telecharger": return "TÉLÉCHARGER"
		"installer": return "REDÉMARRER ET INSTALLER"
		_: return ""

## Le seul point d'entrée de l'écran. Il ne choisit pas : il appuie.
func declencher() -> void:
	match action_suivante():
		"verifier": await verifier()
		"telecharger": await telecharger()
		"installer": installer()

func _incident_correctif() -> String:
	var patch := get_node_or_null("/root/PatchLoader")
	return str(patch.incident) if patch != null else ""

static func _poids(octets: int) -> String:
	if octets <= 0:
		return ""
	var mo := float(octets) / (1024.0 * 1024.0)
	if mo < 1.0:
		return "%d Ko" % int(octets / 1024.0)
	return "%.0f Mo" % mo

# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _poser(nouvel_etat: Etat, message: String) -> void:
	etat = nouvel_etat
	erreur = message
	etat_change.emit(etat)

## Un GET en mémoire, plafonné. Rend les octets, ou un tableau vide.
func _obtenir(url: String, plafond: int) -> PackedByteArray:
	_http.download_file = ""
	if _http.request(url) != OK:
		return PackedByteArray()
	var reponse: Array = await _http.request_completed
	if int(reponse[0]) != HTTPRequest.RESULT_SUCCESS or int(reponse[1]) != 200:
		return PackedByteArray()
	var corps: PackedByteArray = reponse[3]
	if corps.size() > plafond:
		return PackedByteArray()
	return corps

## La signature voyage en base64 : `openssl dgst -sign` rend du binaire, et un
## fichier binaire de 512 octets passe mal partout — un éditeur, un copier-coller,
## une conversion de fin de ligne suffisent à le corrompre en silence.
static func _debase64(octets: PackedByteArray) -> PackedByteArray:
	var texte := octets.get_string_from_utf8().strip_edges()
	if texte == "":
		return PackedByteArray()
	return Marshalls.base64_to_raw(texte)
