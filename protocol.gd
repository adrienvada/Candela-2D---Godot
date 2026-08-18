class_name Protocol
## Le numéro que deux jeux comparent avant de se parler — Phase 8, étape 8.9.
##
## Deux versions du jeu qui ne parlent pas exactement la même langue ne plantent
## pas : elles jouent, chacune dans sa réalité. Le pire défaut du netcode est
## celui qui ne lève rien.
##
## ## Le carnet, et le rappel
##
## `VERSION` est tenu **à la main**, et c'est délibéré (décision d'Adrien,
## 2026-08-18). Lui seul porte une intention : savoir si un changement casse la
## compatibilité est un jugement, pas un calcul. Une empreinte automatique
## changerait sur un simple renommage sans conséquence, et interdirait à jamais
## de dire « ce changement-ci passe, laissez-les jouer ».
##
## Sa faiblesse est l'oubli, et elle est réelle : le jour où on modifie un RPC
## sans toucher au numéro, deux jeux incompatibles se croient d'accord — et le
## garde-fou est muet exactement quand il fallait qu'il parle.
##
## D'où `WIRE_WITNESS` : le témoin de ce à quoi ressemblait le fil la dernière
## fois qu'on a regardé. `tools/test_protocole.gd` le recalcule et compare. Si le
## fil a bougé sans que `VERSION` bouge, la suite passe au rouge et dit quoi
## faire. **Le numéro reste une décision humaine ; l'oubli, lui, est mécanisé.**
##
## ## Ce que le numéro couvre
##
## Tout ce qui est visible sur le fil, en **un seul** numéro : formes des RPC,
## version du codec de carte, noms des attributs de salon EOS. Pas un numéro par
## sous-système — un joueur n'a pas à savoir lequel diffère, et deux numéros
## finiraient par se contredire.
##
## ## Comment on l'incrémente
##
## D'un, à chaque fois que le fil change. Jamais de saut, jamais de retour : les
## versions publiées dans la nature ne se rattrapent pas.

## Le carnet. À incrémenter dès que quoi que ce soit change sur le fil.
##
## 1 — état du 2026-08-18 au matin : douze RPC, codec de carte v3, attributs de
##     salon d'origine. Jamais publié.
## 2 — la poignée de main elle-même : `rpc_hello` et l'attribut de salon `PROTO`.
##     Un build v1 n'a pas `rpc_hello` ; il ne répond donc jamais, et c'est
##     `_check_hello_arrived` qui le refuse — le silence est un refus.
const VERSION := 3

## Le témoin. Empreinte du fil au moment où `VERSION` a été fixé.
##
## Il ne se modifie **jamais seul** : quand la suite le déclare périmé, on décide
## d'abord si `VERSION` doit monter, puis on recopie ici l'empreinte que la suite
## affiche. Le recopier sans avoir tranché la question du numéro ne fait que
## rendre le rappel silencieux.
const WIRE_WITNESS := "2a3497cc8e3ef35a"

## Fichiers portant des RPC. Une liste explicite plutôt qu'un balayage du dépôt :
## un fichier oublié rendrait le témoin vert alors que le fil a bougé, et c'est
## le seul mode de défaillance qui compte ici. Ajouter un RPC dans un fichier
## absent de cette liste doit être impossible à faire par inadvertance — d'où la
## vérification croisée de la suite, qui refuse tout `@rpc` hors de ces fichiers.
const RPC_SOURCES: Array[String] = [
	"res://game_state.gd",
	"res://network_manager.gd",
	"res://player.gd",
]

## Refuser dans les deux sens, sans « le plus récent tolère le plus ancien ».
##
## Le build ancien ne peut pas savoir ce que le nouveau a changé : sa tolérance
## serait une supposition. La symétrie est la seule règle que les deux côtés
## peuvent appliquer avec la même information — et deux jeux qui refusent pour la
## même raison peuvent l'expliquer pareil.
static func accepts(peer_version: int) -> bool:
	return peer_version == VERSION

## Ce qu'on montre au joueur quand ça ne colle pas. Il n'a pas à connaître le
## numéro : il a à savoir quoi faire.
static func mismatch_message(peer_version: int) -> String:
	if peer_version <= 0:
		return "Votre adversaire utilise une version du jeu trop ancienne pour se présenter."
	var qui := "la vôtre" if peer_version < VERSION else "celle de votre adversaire"
	return ("Vos deux jeux ne sont pas dans la même version : %s est plus ancienne. "
		+ "Mettez à jour des deux côtés avant de rejouer.") % qui
