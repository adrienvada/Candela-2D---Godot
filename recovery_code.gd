## Code de récupération d'un profil classé — moitié client.
##
## Le Device ID Epic est lié à la MACHINE : un joueur qui change d'ordinateur
## arrive avec un PUID neuf et perdrait tout. Ce code, noté par lui, rattache la
## nouvelle machine au profil existant.
##
## Le code est tiré PAR LE SERVEUR et jamais ici : c'est ce qui empêche un joueur
## de se choisir le code d'un autre. Ce fichier ne sait que nettoyer la saisie,
## la valider et la mettre en forme — logique pure, sans réseau, donc testable en
## headless (voir tools/test_netcode.gd). Le tirage vit dans
## supabase/functions/_shared/recovery_code.ts, avec ses propres tests.
class_name RecoveryCode
extends RefCounted

## Le même alphabet que les codes de salon : ni I, ni O, ni 0, ni 1. Ce code-ci
## sera lu à voix haute et recopié à la main, exactement comme eux.
const ALPHABET := LobbyCode.ALPHABET

## 12 caractères sur 32, soit 60 bits.
##
## Un code de salon en fait 6 : suffisant pour désigner un salon qui vit dix
## minutes, dérisoire pour un secret au porteur qui ouvre un profil classé à vie.
const LENGTH := 12

## Groupes de lecture. N'intervient qu'à l'affichage — la forme stockée et
## envoyée reste sans séparateur.
const GROUP := 4

## Remonte ce que le joueur a tapé ou collé jusqu'à la forme canonique :
## majuscules, séparateurs et caractères hors alphabet retirés, longueur
## plafonnée.
##
## Aucune substitution : « I » ne devient pas « J ». Deviner à la place du joueur
## rattacherait le profil de quelqu'un d'autre, alors qu'un code refusé se retape
## en dix secondes.
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

## Forme lisible, par groupes de GROUP : « ABCD-EFGH-JKLM ».
##
## Accepte un code incomplet : le champ de saisie s'en sert pendant la frappe.
static func format(code: String) -> String:
	var groups := PackedStringArray()
	var index := 0
	while index < code.length():
		groups.append(code.substr(index, GROUP))
		index += GROUP
	return "-".join(groups)
