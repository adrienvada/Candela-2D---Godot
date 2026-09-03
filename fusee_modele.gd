class_name FuseeModele
## Le modèle pur de la fusée éclairante — chantier FUSÉE, étape FU1.
##
## Ce fichier est SANS DÉPENDANCE (ni autoload, ni nœud), comme `brouillage.gd`
## et `vision.gd`, et pour la même raison : être chargeable par une suite en
## `--script`. Tout l'état d'une fusée se dérive de trois données qui transitent
## dans le RPC de spawn — départ, cible, graine — plus l'âge local. C'est ce qui
## rend la simulation identique chez les deux pairs sans aucune synchro en vol,
## et la killcam capable de reconstruire une fusée à un âge arbitraire.
##
## Les nombres ci-dessous sont des VALEURS DE DÉPART, à doser au banc
## `tools/banc_fusee.tscn` — jamais en les éditant à l'aveugle.

# ── Le vol ──────────────────────────────────────────────────────────────────
# La fusée se lance en cloche : elle survole les murs (aucun test de collision
# pendant le vol) et atterrit en un point calculé AVANT le RPC de spawn, donc
# identique partout. La vitesse borne la durée du vol, pas l'inverse.
const VITESSE_VOL := 700.0        # px/s
const PORTEE_MAX := 450.0         # px — portée fixe v1, pas de charge à l'appui
const PORTEE_MIN := 80.0          # px — en dessous, on se la jette dans les pieds
const DUREE_VOL_MIN := 0.25       # s — même un lancer court doit se LIRE en vol
const DUREE_VOL_MAX := 0.90       # s

# ── La vie en actes ─────────────────────────────────────────────────────────
# Blanc magnésium (scan honnête) → braise (l'ère de l'ambiguïté, la fumée
# règne) → agonie (strobe : chaque flash est une photo de la pièce) → braise
# résiduelle (un repère, plus une information). L'horloge est publique : les
# deux joueurs lisent le même acte au même instant.
enum Acte { VOL, BLANC, BRAISE, AGONIE, RESIDU, MORTE }

const DUREE_BLANC := 2.0          # s
const DUREE_BRAISE := 10.0        # s
const DUREE_AGONIE := 3.0         # s
const DUREE_RESIDU := 5.0         # s

const ENERGIE_BLANC := 3.0
const ENERGIE_BRAISE := 1.2
const ENERGIE_RESIDU := 0.25
const ENERGIE_VOL := 0.8          # la comète : assez pour tracer l'arc, pas pour lire
const RACCORD_BLANC_BRAISE := 1.5 # s de glissement blanc → braise (dans l'acte braise)

# ── L'agonie stroboscopique ─────────────────────────────────────────────────
# Les instants de flash sont tirés d'une graine transmise au spawn : la liste
# entière se régénère à l'identique n'importe où, n'importe quand — c'est ce
# qui permet à la killcam d'afficher le bon flash à un âge arbitraire.
const AGONIE_FLASHS_MIN := 3
const AGONIE_FLASHS_MAX := 5
const FLASH_DUREE_MIN := 0.08     # s
const FLASH_DUREE_MAX := 0.12     # s
const ENERGIE_FLASH := 2.5
const ENERGIE_CREUX := 0.15       # le quasi-noir entre deux flashs

# ── La fumée ────────────────────────────────────────────────────────────────
# Dense au centre, claire aux bords : la cachette a un gradient spatial. La
# fumée met du temps à s'épaissir (l'acte blanc reste un scan) et meurt avec
# le résidu — la « fumée orpheline » de sa lumière est une décision d'identité
# non actée, elle n'existe pas en v1.
const RAYON_FUMEE := 200.0        # px
const FUMEE_MONTEE := 3.0         # s pour atteindre la pleine densité
const NAPPES_PAR_DEFAUT := 3      # une de moins en écran scindé
const NAPPE_ALPHA := 0.35
const NAPPE_VITESSES := [0.05, -0.08, 0.03]  # TOURS/s (fusee.gd multiplie par TAU)
const FUMEE_GONFLE := 1.25        # la nappe s'étale de ×1 à ×1,25 sur la vie

# ── La silhouette sans identité ─────────────────────────────────────────────
# Dans la fumée, un joueur n'est jamais invisible : une masse sombre de la
# taille d'un corps le remplace. On voit QU'IL Y A quelqu'un — pas qui, pas
# dans quel sens il vise. Jamais d'invisibilité dans la lumière (garde-fou
# anti-camping du brainstorm, décision de conception).
const MASSE_RAYON := 26.0         # px — la taille d'un corps
const MASSE_OPACITE := 0.55

# ── Le sillage ──────────────────────────────────────────────────────────────
# Traverser la fumée y creuse un couloir qui se referme : l'endroit qui cache
# le mieux est celui qui enregistre le mieux. L'immobilité ne creuse rien.
const SILLAGE_DUREE := 2.0        # s avant refermeture complète
const SILLAGE_RAYON := 18.0       # px
const SILLAGE_PERIODE := 0.25     # s entre deux points de trace
const SILLAGE_POINTS_MAX := 8     # par joueur
const SILLAGE_VITESSE_MIN := 40.0 # px/s — en dessous, on ne creuse pas

# ── L'économie ──────────────────────────────────────────────────────────────
const STOCK_PAR_MANCHE := 1
const DESARMEMENT := 0.6          # s sans tir après le lancer — pas de lance-et-tire


static func duree_vol(distance: float) -> float:
	return clampf(distance / VITESSE_VOL, DUREE_VOL_MIN, DUREE_VOL_MAX)


## Borne la cible demandée entre PORTEE_MIN et PORTEE_MAX du départ.
static func borner_cible(depart: Vector2, cible: Vector2) -> Vector2:
	var delta := cible - depart
	var distance := delta.length()
	if distance < 0.001:
		return depart + Vector2.RIGHT * PORTEE_MIN
	return depart + delta / distance * clampf(distance, PORTEE_MIN, PORTEE_MAX)


static func duree_combustion() -> float:
	return DUREE_BLANC + DUREE_BRAISE + DUREE_AGONIE + DUREE_RESIDU


## L'acte à un âge de COMBUSTION donné (0 = l'atterrissage ; le vol est géré
## par l'appelant, qui connaît sa durée de vol).
static func acte_a(age: float) -> Acte:
	if age < 0.0:
		return Acte.VOL
	if age < DUREE_BLANC:
		return Acte.BLANC
	if age < DUREE_BLANC + DUREE_BRAISE:
		return Acte.BRAISE
	if age < DUREE_BLANC + DUREE_BRAISE + DUREE_AGONIE:
		return Acte.AGONIE
	if age < duree_combustion():
		return Acte.RESIDU
	return Acte.MORTE


## Les fenêtres de flash de l'agonie, en secondes depuis le DÉBUT de l'agonie :
## un tableau de paires [debut, fin]. Même graine, même liste, partout.
static func fenetres_agonie(graine: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var nb := rng.randi_range(AGONIE_FLASHS_MIN, AGONIE_FLASHS_MAX)
	var fenetres: Array = []
	# Répartition : l'agonie est découpée en nb tranches égales, chaque flash
	# tombe à un instant tiré dans sa tranche — irrégulier à l'oreille et à
	# l'œil, mais jamais deux flashs collés ni un trou de deux secondes.
	var tranche := DUREE_AGONIE / float(nb)
	for i in nb:
		var duree := rng.randf_range(FLASH_DUREE_MIN, FLASH_DUREE_MAX)
		var marge := maxf(tranche - duree, 0.0)
		var debut := float(i) * tranche + rng.randf_range(0.0, marge)
		fenetres.append([debut, debut + duree])
	return fenetres


## Un flash est-il allumé à cet âge de combustion ? Les fenêtres se précalculent
## UNE fois par fusée (`fenetres_agonie`) : les recalculer chaque image
## allouerait un générateur aléatoire par appel.
static func flash_actif(age: float, fenetres: Array) -> bool:
	if acte_a(age) != Acte.AGONIE:
		return false
	var t := age - DUREE_BLANC - DUREE_BRAISE
	for f in fenetres:
		if t >= f[0] and t < f[1]:
			return true
	return false


## L'énergie lumineuse à un âge de combustion donné. `intensite_agonie` vient
## d'EffectPolicy (famille MONDE, plancher en classé) : à 1, le strobe est
## entier ; vers 0, les flashs s'aplatissent sur un fondu continu — le rythme
## reste porté par le SON, identique pour tous (variante photosensibilité).
static func energie_a(age: float, fenetres: Array, intensite_agonie: float = 1.0) -> float:
	match acte_a(age):
		Acte.VOL:
			return ENERGIE_VOL
		Acte.BLANC:
			return ENERGIE_BLANC
		Acte.BRAISE:
			var t := age - DUREE_BLANC
			if t < RACCORD_BLANC_BRAISE:
				return lerpf(ENERGIE_BLANC, ENERGIE_BRAISE, t / RACCORD_BLANC_BRAISE)
			return ENERGIE_BRAISE
		Acte.AGONIE:
			# Le fondu continu que verrait un joueur à intensité 0.
			var t := age - DUREE_BLANC - DUREE_BRAISE
			var fondu := lerpf(ENERGIE_BRAISE, ENERGIE_RESIDU, t / DUREE_AGONIE)
			var strobe := ENERGIE_FLASH if flash_actif(age, fenetres) else ENERGIE_CREUX
			return lerpf(fondu, strobe, clampf(intensite_agonie, 0.0, 1.0))
		Acte.RESIDU:
			var t := age - DUREE_BLANC - DUREE_BRAISE - DUREE_AGONIE
			return lerpf(ENERGIE_RESIDU, 0.0, t / DUREE_RESIDU)
		_:
			return 0.0


## La température de couleur à un âge donné : 0 = blanc magnésium, 1 = braise.
## L'appelant mappe sur ses couleurs (Charte) — le modèle ne connaît pas la
## charte, il doit rester sans dépendance.
static func temperature_a(age: float) -> float:
	match acte_a(age):
		Acte.VOL, Acte.BLANC:
			return 0.0
		Acte.BRAISE:
			var t := age - DUREE_BLANC
			return clampf(t / RACCORD_BLANC_BRAISE, 0.0, 1.0)
		_:
			return 1.0


## L'opacité globale de la fumée à un âge de combustion donné, dans [0, 1]
## (facteur appliqué aux alphas des nappes et du voile).
static func alpha_fumee_a(age: float) -> float:
	if age < 0.0:
		return 0.0
	var fin := duree_combustion()
	if age >= fin:
		return 0.0
	var montee := clampf(age / FUMEE_MONTEE, 0.0, 1.0)
	# La fumée meurt avec le résidu, en fondu sur la durée du résidu.
	var debut_residu := DUREE_BLANC + DUREE_BRAISE + DUREE_AGONIE
	if age >= debut_residu:
		return lerpf(montee, 0.0, (age - debut_residu) / DUREE_RESIDU)
	return montee


## L'échelle des nappes (elles gonflent lentement sur la vie de la fusée).
static func echelle_fumee_a(age: float) -> float:
	var t := clampf(age / duree_combustion(), 0.0, 1.0)
	return lerpf(1.0, FUMEE_GONFLE, t)


## Position en vol : interpolation directe départ → cible (la cloche est un
## habillage visuel — hauteur factice — pas une trajectoire physique).
static func position_vol(depart: Vector2, cible: Vector2, t01: float) -> Vector2:
	return depart.lerp(cible, clampf(t01, 0.0, 1.0))


## Hauteur factice de la cloche dans [0, 1] (0 au départ et à l'arrivée).
static func hauteur_vol(t01: float) -> float:
	return sin(clampf(t01, 0.0, 1.0) * PI)


## Filtre un sillage : ne garde que les points plus récents que SILLAGE_DUREE,
## bornés à SILLAGE_POINTS_MAX (les plus récents gagnent). Un point est un
## Dictionary { "pos": Vector2, "t": float }.
static func filtrer_sillage(points: Array, maintenant: float) -> Array:
	var vivants: Array = []
	for p in points:
		if maintenant - p["t"] < SILLAGE_DUREE:
			vivants.append(p)
	while vivants.size() > SILLAGE_POINTS_MAX:
		vivants.pop_front()
	return vivants


## Le rayon résiduel d'un point de sillage selon son âge (se referme en 2 s).
static func rayon_sillage(age_point: float) -> float:
	return SILLAGE_RAYON * clampf(1.0 - age_point / SILLAGE_DUREE, 0.0, 1.0)
