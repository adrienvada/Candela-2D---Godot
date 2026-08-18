class_name UpdateManifest
extends RefCounted

## Le manifeste de mise à jour : ce que le jeu lit avant de décider quoi que ce
## soit — Phase 9, étape 1.
##
## ## Pourquoi un objet séparé du téléchargement
##
## Tout ce qui se décide ici se décide **sans réseau, sans disque et sans
## fenêtre** : quelle version est publiée, est-elle plus récente que la nôtre,
## quel paquet convient à cette machine, et le jeu en ligne survit-il à l'écart.
## Ces quatre questions sont exactement celles qu'un test headless peut poser
## cent fois par seconde ; les mêler à un `HTTPRequest` les rendrait
## invérifiables. `update_manager.gd` fait le réseau, ce fichier fait le
## jugement.
##
## ## Le format, et pourquoi il porte un numéro
##
## ```json
## {
##   "format": 1,
##   "version": "0.2.0",
##   "protocole": 3,
##   "publie_le": "2026-08-19",
##   "notes": "Ce que cette version change, en une phrase.",
##   "paquets": [
##     {"type": "bundle", "plateforme": "windows", "arch": "x86_64",
##      "url": "https://…/Candela-0.2.0-windows.zip",
##      "octets": 91234567, "sha256": "…", "racine": "Candela"},
##     {"type": "pck", "plateforme": "*",
##      "url": "https://…/candela-0.2.0.pck",
##      "octets": 4210000, "sha256": "…",
##      "socle_min": "0.2.0", "socle_max": "0.2.0"}
##   ]
## }
## ```
##
## `format` protège le seul cas qu'on ne peut pas rattraper après coup : un
## manifeste écrit par un futur outil et lu par un jeu déjà installé. Un numéro
## **plus grand** que `FORMAT` n'est pas une erreur de publication, c'est un jeu
## trop vieux — et il doit le dire ainsi, pas afficher « manifeste illisible ».
##
## ## Deux types de paquets, et un seul chemin de décision
##
## `bundle` remplace l'installation entière ; `pck` ne remplace que le contenu
## chargé par-dessus le socle. Le jeu ne choisit pas la **stratégie**, il
## applique celle que le manifeste rend applicable : un `pck` dont l'intervalle
## de socle contient la version installée est préféré, parce qu'il coûte quelques
## mégaoctets au lieu de cent — sinon on retombe sur le `bundle`.
##
## C'est délibérément une décision **de publication**, pas d'exécution : au
## moment de publier, on sait si le changement touche au moteur, à l'addon EOS ou
## aux modèles d'exportation (alors `bundle` seul), ou uniquement à du GDScript et
## des scènes (alors `pck` possible). Le jeu installé, lui, ne peut pas le savoir.
##
## ## Un type inconnu s'ignore, un champ manquant crie
##
## Les deux se ressemblent et ne sont pas du tout la même chose. Un paquet d'un
## type que ce build ne connaît pas est une **extension future** : on l'ignore et
## on prend le suivant, sinon publier un nouveau type casserait tous les jeux
## déjà installés. Un paquet d'un type connu à qui il manque son `sha256` est un
## **défaut de publication** : il rend le manifeste invalide, bruyamment, parce
## que c'est la seule occasion de s'en apercevoir avant qu'un joueur ne
## télécharge cent mégaoctets qu'on ne saura pas vérifier.

## Le format que ce build sait lire. À incrémenter uniquement si la forme du
## manifeste change d'une façon qu'un ancien jeu ne peut pas ignorer.
const FORMAT := 1

## Les valeurs admises de `type`. Tout le reste est ignoré à la lecture — voir
## l'en-tête : c'est ce qui permettra d'ajouter un type sans casser l'existant.
const TYPE_BUNDLE := "bundle"
const TYPE_PCK := "pck"
const TYPES_CONNUS: Array[String] = [TYPE_BUNDLE, TYPE_PCK]

## `plateforme` : les trois noms que `update_installer.gd` sait produire, plus
## `*` pour un paquet qui convient partout (le cas normal d'un `pck` : du
## GDScript et des scènes n'ont pas de plateforme).
const PARTOUT := "*"

## Où en est l'installation par rapport à ce qui est publié.
enum Etat {
	A_JOUR,           ## Rien à faire.
	DISPONIBLE,       ## Le manifeste publie plus récent que ce qui tourne.
	EN_AVANCE,        ## On tourne plus récent que ce qui est publié — build de
	                  ## développement, ou publication retirée. Jamais une erreur.
}

## Rempli si le manifeste est inutilisable. Vide sinon. Un manifeste en erreur
## n'est jamais « à jour » : il ne dit rien, et ne rien dire n'est pas rassurer.
var erreur: String = ""

var format: int = 0
var version: String = ""
var protocole: int = 0
var publie_le: String = ""
var notes: String = ""
var paquets: Array[Dictionary] = []

func valide() -> bool:
	return erreur == ""

# ---------------------------------------------------------------------------
# LECTURE
# ---------------------------------------------------------------------------

## Lit un manifeste. Rend toujours un objet — jamais `null` : un appelant qui
## doit tester la nullité *et* l'erreur finit toujours par n'en tester qu'une.
static func depuis_json(texte: String) -> UpdateManifest:
	var m := UpdateManifest.new()
	var brut: Variant = JSON.parse_string(texte)
	if typeof(brut) != TYPE_DICTIONARY:
		m.erreur = "Le manifeste n'est pas un objet JSON."
		return m
	var d: Dictionary = brut

	# `format` d'abord, et avant tout contrôle de contenu : si le manifeste est
	# plus récent que nous, aucun autre message ne serait juste.
	m.format = _entier(d.get("format", 0))
	if m.format <= 0:
		m.erreur = "Le manifeste ne dit pas son format."
		return m
	if m.format > FORMAT:
		m.erreur = ("Ce jeu est trop ancien pour lire l'annonce de mise à jour. "
			+ "Téléchargez la dernière version à la main.")
		return m

	m.version = str(d.get("version", ""))
	if not est_version(m.version):
		m.erreur = "Version publiée illisible : « %s »." % m.version
		return m

	m.protocole = _entier(d.get("protocole", 0))
	if m.protocole <= 0:
		m.erreur = "Le manifeste ne dit pas son numéro de protocole."
		return m

	m.publie_le = str(d.get("publie_le", ""))
	m.notes = str(d.get("notes", ""))

	var liste: Variant = d.get("paquets", null)
	if typeof(liste) != TYPE_ARRAY:
		m.erreur = "Le manifeste ne porte aucune liste de paquets."
		return m
	for entree: Variant in liste:
		if typeof(entree) != TYPE_DICTIONARY:
			m.erreur = "Un paquet du manifeste n'est pas un objet."
			return m
		var p: Dictionary = entree
		var type := str(p.get("type", ""))
		# Type inconnu : extension future, on passe. Voir l'en-tête.
		if not TYPES_CONNUS.has(type):
			continue
		var manque := _champ_manquant(p)
		if manque != "":
			m.erreur = "Paquet « %s » incomplet : %s." % [type, manque]
			return m
		m.paquets.append(_normalise(p))
	return m

## Ce qu'un paquet doit porter pour être utilisable. Le `sha256` en fait partie :
## un paquet qu'on ne saura pas vérifier ne doit pas exister, et surtout pas être
## téléchargé « pour voir ».
static func _champ_manquant(p: Dictionary) -> String:
	if str(p.get("url", "")) == "":
		return "pas d'url"
	if not str(p.get("url", "")).begins_with("https://"):
		return "url non https"
	var sha := str(p.get("sha256", ""))
	if sha.length() != 64:
		return "empreinte sha256 absente ou de mauvaise longueur"
	if _entier(p.get("octets", 0)) <= 0:
		return "taille absente"
	if str(p.get("type", "")) == TYPE_PCK and not est_version(str(p.get("socle_min", ""))):
		return "un correctif doit dire sur quel socle il s'applique (socle_min)"
	return ""

static func _normalise(p: Dictionary) -> Dictionary:
	return {
		"type": str(p.get("type", "")),
		"plateforme": str(p.get("plateforme", PARTOUT)),
		"arch": str(p.get("arch", "")),
		"url": str(p.get("url", "")),
		"octets": _entier(p.get("octets", 0)),
		"sha256": str(p.get("sha256", "")).to_lower(),
		"racine": str(p.get("racine", "")),
		"socle_min": str(p.get("socle_min", "")),
		"socle_max": str(p.get("socle_max", "")),
	}

## Tout nombre relu d'un JSON revient en flottant — piège déjà payé sur le
## journal des matchs. `int()` sur un `String` rendrait 0 en silence, d'où le
## contrôle de type explicite.
static func _entier(v: Variant) -> int:
	match typeof(v):
		TYPE_INT: return v
		TYPE_FLOAT: return int(v)
		_: return 0

# ---------------------------------------------------------------------------
# VERSIONS
# ---------------------------------------------------------------------------

## « 0.2.0 », « 1.0 », « 0.2.0-rc1 ». Trois segments au plus, des chiffres, et
## un suffixe facultatif introduit par un tiret.
static func est_version(v: String) -> bool:
	if v == "":
		return false
	var corps := v.split("-")[0]
	var segments := corps.split(".")
	if segments.is_empty() or segments.size() > 4:
		return false
	for s: String in segments:
		if s == "" or not s.is_valid_int():
			return false
	return true

## -1, 0 ou 1. Un suffixe rend la version **antérieure** à la même sans suffixe
## (`0.2.0-rc1` vient avant `0.2.0`), convention semver : une pré-version précède
## toujours la version qu'elle prépare.
static func comparer(a: String, b: String) -> int:
	var ca := a.split("-")
	var cb := b.split("-")
	var sa := ca[0].split(".")
	var sb := cb[0].split(".")
	var n := maxi(sa.size(), sb.size())
	for i in n:
		var va := int(sa[i]) if i < sa.size() else 0
		var vb := int(sb[i]) if i < sb.size() else 0
		if va != vb:
			return -1 if va < vb else 1
	var suffixe_a := ca.size() > 1
	var suffixe_b := cb.size() > 1
	if suffixe_a == suffixe_b:
		return 0
	return -1 if suffixe_a else 1

func etat_pour(version_installee: String) -> Etat:
	var c := comparer(version_installee, version)
	if c < 0:
		return Etat.DISPONIBLE
	if c > 0:
		return Etat.EN_AVANCE
	return Etat.A_JOUR

# ---------------------------------------------------------------------------
# CHOIX DU PAQUET
# ---------------------------------------------------------------------------

## Le paquet à prendre pour cette machine, ou `{}` s'il n'y en a aucun.
##
## `socle` est la version de l'installation **sur le disque**, pas la version
## effective : un correctif s'applique sur ce qui a été installé, pas sur ce
## qu'un correctif précédent a déjà changé. Deux correctifs empilés au hasard
## donneraient un état que personne n'a jamais testé.
func paquet_pour(plateforme: String, arch: String, socle: String) -> Dictionary:
	var replis: Array[Dictionary] = []
	for p: Dictionary in paquets:
		if not _convient(p, plateforme, arch):
			continue
		if p["type"] == TYPE_PCK:
			if _socle_compatible(p, socle):
				return p  # Le moins cher qui s'applique gagne, tout de suite.
			continue
		replis.append(p)
	return replis[0] if not replis.is_empty() else {}

static func _convient(p: Dictionary, plateforme: String, arch: String) -> bool:
	var pl := str(p.get("plateforme", PARTOUT))
	if pl != PARTOUT and pl != plateforme:
		return false
	var ar := str(p.get("arch", ""))
	return ar == "" or ar == arch

static func _socle_compatible(p: Dictionary, socle: String) -> bool:
	if not est_version(socle):
		return false
	if comparer(socle, str(p.get("socle_min", ""))) < 0:
		return false
	var maxi_ := str(p.get("socle_max", ""))
	if maxi_ != "" and comparer(socle, maxi_) > 0:
		return false
	return true

# ---------------------------------------------------------------------------
# LE JEU EN LIGNE — REFUS POLI
# ---------------------------------------------------------------------------

## Ce qu'il faut dire au joueur quand la version publiée n'a pas le même
## protocole que la sienne. Vide si tout va bien.
##
## **Rien n'est bloqué, et c'est une décision d'Adrien (2026-08-18).** Le jeu ne
## se ferme pas, ne verrouille aucun menu, ne force aucun téléchargement : l'écran
## scindé, l'entraînement et l'éditeur de cartes n'ont jamais eu besoin d'un
## adversaire distant. Ce qui cesse de fonctionner — trouver quelqu'un en ligne —
## a déjà cessé de fonctionner tout seul, puisque `Protocol.accepts()` refuse
## symétriquement. Le rôle de cette phrase est de **nommer** ce que le joueur
## constate, pas de le contraindre : un jeu qui refuse de démarrer tant qu'on n'a
## pas mis à jour transforme une gêne en panne.
func message_en_ligne(protocole_local: int) -> String:
	if protocole_local == protocole:
		return ""
	return ("Les parties en ligne demandent la même version des deux côtés. "
		+ "Tant que vous n'aurez pas mis à jour, vous ne trouverez pas "
		+ "d'adversaire. Tout le reste du jeu continue de fonctionner.")

# ---------------------------------------------------------------------------
# SIGNATURE
# ---------------------------------------------------------------------------

## Vérifie que le manifeste vient bien de chez nous.
##
## ## Pourquoi c'est obligatoire, et pas un raffinement
##
## Un fichier écrit par `HTTPRequest` ne porte pas l'attribut de quarantaine de
## macOS : un bundle remplacé par ce système ne repasse jamais devant Gatekeeper.
## C'est confortable — et cela veut dire que **plus personne d'autre que nous ne
## vérifie ce qui s'exécute**. Le jeu porte un classement ELO : un manifeste
## substitué en chemin ferait exécuter n'importe quel binaire sur la machine du
## joueur, avec son avatar et son rang.
##
## ## Signature détachée, et RSA plutôt qu'ed25519
##
## Détachée (`manifeste.json.sig` à côté du fichier) parce que signer un champ
## *dans* le JSON obligerait les deux bouts à s'accorder sur une écriture
## canonique — un espace de plus côté CI et la signature ne vaut plus rien, sans
## que rien ne le dise. On signe les octets exacts, tels que téléchargés.
##
## RSA parce que `Crypto.verify()` de Godot ne connaît que `CryptoKey`, qui est
## RSA : ed25519 aurait demandé une GDExtension pour un gain nul ici.
##
## La clé **publique** est faite pour être publiée : elle est en clair dans le
## dépôt. La privée ne quitte jamais les secrets GitHub — même règle que
## `eos_credentials.gd`, et même conséquence si elle fuite : on republie une clé
## et les anciens builds ne se mettent plus à jour.
static func verifier_signature(octets: PackedByteArray, signature: PackedByteArray,
		pem_publique: String) -> bool:
	if pem_publique.strip_edges() == "" or signature.is_empty() or octets.is_empty():
		return false
	var cle := CryptoKey.new()
	if cle.load_from_string(pem_publique, true) != OK:
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(octets)
	var empreinte := ctx.finish()
	var crypto := Crypto.new()
	return crypto.verify(HashingContext.HASH_SHA256, empreinte, signature, cle)

## L'empreinte d'un fichier déjà sur le disque, en minuscules — la forme que
## `sha256sum` et `shasum -a 256` écrivent, donc celle qui se compare sans
## conversion à ce que la CI a publié.
static func empreinte_fichier(chemin: String) -> String:
	return FileAccess.get_sha256(chemin).to_lower()
