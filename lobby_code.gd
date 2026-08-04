## Code de salon à 6 caractères, lu à voix haute d'un joueur à l'autre.
##
## Logique pure et sans dépendance réseau : c'est ce qui la rend testable en
## headless (voir tools/test_netcode.gd).
class_name LobbyCode
extends RefCounted

## Ni I ni O ni 0 ni 1 : à l'oral comme à l'écrit ces quatre-là se confondent
## deux à deux, et un code mal recopié est indiscernable d'un salon fermé.
const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const LENGTH := 6

static func generate() -> String:
	var code := ""
	for i in LENGTH:
		code += ALPHABET[randi() % ALPHABET.length()]
	return code

## Remonte ce que le joueur a tapé jusqu'à la forme canonique : majuscules,
## séparateurs et caractères hors alphabet retirés, longueur plafonnée.
##
## Aucune substitution : « I » ne devient pas « J ». Deviner à la place du
## joueur ferait entrer dans un salon qui n'est pas le sien, alors qu'un code
## refusé se retape en trois secondes.
static func sanitize(raw: String) -> String:
	var out := ""
	for c in raw.to_upper():
		if ALPHABET.contains(c):
			out += c
			if out.length() == LENGTH:
				break
	return out

## Vrai seulement si le code fait LENGTH caractères, tous dans l'alphabet.
static func is_valid(code: String) -> bool:
	if code.length() != LENGTH:
		return false
	for c in code:
		if not ALPHABET.contains(c):
			return false
	return true
