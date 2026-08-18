## [Client] Apparier un tir prédit localement avec la balle officielle de l'hôte.
##
## Le client rend son propre tir sans attendre l'accord de l'hôte — sinon chaque
## coup coûterait un aller-retour avant d'être vu. Quand la balle arbitrée
## arrive, il faut reconnaître qu'elle est *la même* pour ne pas en dessiner deux.
##
## **La version d'origine ne retenait que des horodatages, et défilait en FIFO
## aveugle avec un TTL fixe d'une seconde.** Relevé par l'étude de robustesse du
## 2026-08-16 : au-delà d'une seconde de latence, la prédiction expire avant que
## la balle officielle n'arrive, et **le joueur voit sa balle en double**. Ce
## n'est pas un cas d'école — c'est le cas d'un joueur sur un réseau mobile
## saturé, c'est-à-dire exactement celui pour qui la prédiction existe.
##
## Deux remèdes, ceux que l'étude proposait :
##
## 1. **Le TTL suit le RTT mesuré** au lieu d'être une constante. Une durée de vie
##    fixe est fausse des deux côtés : trop courte sur un mauvais lien (doublons),
##    trop longue sur un bon (des fantômes traînent).
## 2. **L'appariement regarde l'angle**, pas seulement l'ordre d'arrivée. À
##    cadence rapide, deux tirs peuvent se croiser ; l'ordre seul les confond.
##
## Fichier sans dépendance : la comptabilité d'une file se relit à froid, et
## `game_state.gd` nomme des autoloads — donc ne compile pas en `--script`.
extends RefCounted

## Durée de vie d'une prédiction quand le RTT n'est pas encore mesuré. C'est
## l'ancienne constante : à défaut de mieux, on ne fait pas pire qu'avant.
const TTL_DEFAUT_MS := 1000
## La balle officielle revient après un aller-retour ; le facteur couvre la gigue
## et le délai de cadence côté hôte, sans garder de fantômes indéfiniment.
const TTL_FACTEUR := 2.5
const TTL_PLANCHER_MS := 500
const TTL_PLAFOND_MS := 3000
## Tolérance d'appariement, en radians — environ trois degrés. L'angle traverse
## le réseau tel que le client l'a envoyé : il devrait être identique. La marge
## couvre l'arrondi de sérialisation, pas un désaccord.
const TOLERANCE_ANGLE := 0.05

## Combien de temps une prédiction reste valable, d'après le lien mesuré.
static func ttl_ms(rtt_ms: float, rtt_connu: bool) -> int:
	if not rtt_connu or rtt_ms <= 0.0:
		return TTL_DEFAUT_MS
	return clampi(int(rtt_ms * TTL_FACTEUR), TTL_PLANCHER_MS, TTL_PLAFOND_MS)

## Retire les prédictions périmées. Modifie le tableau reçu.
##
## Une prédiction expire quand l'hôte a refusé le tir (désaccord de cadence) ou
## quand le paquet d'entrée s'est perdu : sans purge, elle décalerait la file
## pour toujours et chaque balle officielle suivante serait attribuée à la
## mauvaise.
static func purger(predictions: Array, maintenant: int, ttl: int) -> void:
	while not predictions.is_empty() \
			and maintenant - int(predictions[0]["t"]) > ttl:
		predictions.remove_at(0)

## L'indice de la prédiction que cette balle officielle confirme, ou -1.
##
## **L'angle départage, l'ancienneté tranche.** On prend la plus ancienne
## prédiction dont l'angle correspond ; à défaut d'aucune correspondance, on
## retombe sur la plus ancienne tout court — c'est le comportement d'origine, et
## le garder en dernier recours garantit qu'on ne dessine **jamais** un doublon
## là où l'ancienne version n'en dessinait pas. L'appariement par angle améliore
## le choix ; il ne change pas le nombre de balles confirmées.
static func choisir(predictions: Array, angle: float) -> int:
	if predictions.is_empty():
		return -1
	for i in predictions.size():
		var a := float(predictions[i].get("angle", 0.0))
		if absf(angle_difference(a, angle)) <= TOLERANCE_ANGLE:
			return i
	return 0
