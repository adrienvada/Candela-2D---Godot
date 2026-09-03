class_name FuseeModele
## Le modèle pur de la fusée éclairante — chantier FUSÉE, étape FU1.
##
## Ce fichier est SANS DÉPENDANCE (ni autoload, ni nœud), comme `brouillage.gd`
## et `vision.gd`, et pour la même raison : être chargeable par une suite en
## `--script`. Trois données transitent dans le RPC de spawn — départ, angle,
## graine — et tout le reste se simule localement à l'identique chez les deux
## pairs (le vol rebondit sur des murs identiques, à pas de physique fixes) ;
## la combustion, elle, se dérive entièrement de l'âge, ce qui laisse la
## killcam reconstruire lumière et fumée à un instant arbitraire.
##
## Les nombres ci-dessous sont des VALEURS DE DÉPART, à doser au banc
## `tools/banc_fusee.tscn` — jamais en les éditant à l'aveugle.

# ── Le vol ──────────────────────────────────────────────────────────────────
# La fusée REBONDIT sur les murs (décision d'Adrien au premier essai, FU2.1 —
# elle les survolait, et ça se lisait comme une traversée). Elle part tendue,
# le frottement la freine, chaque rebond l'amortit, et elle s'allume au sol
# quand elle n'a plus d'élan. La simulation est locale et déterministe chez les
# deux pairs : mêmes murs, mêmes pas de physique, mêmes rebonds — le patron des
# ricochets de `bullet.gd`.
const VITESSE_LANCER := 900.0     # px/s au départ
const FROTTEMENT_VOL := 900.0     # px/s² — v²/2f donne ~450 px de portée libre
const REBOND_AMORTI := 0.55       # part de vitesse conservée à chaque rebond
const VITESSE_ARRET := 60.0       # px/s — en dessous, elle se pose et s'allume

# ── La vie en actes ─────────────────────────────────────────────────────────
# Rouge de détresse à plein feu (le scan honnête — une fusée de marine,
# Adrien FU2.1) → braise orange (l'ère de l'ambiguïté, la fumée règne) →
# agonie (rallumages sporadiques, chacun une photo de la pièce) → braise
# résiduelle (un repère, plus une information). L'horloge est publique : les
# deux joueurs lisent le même acte au même instant.
enum Acte { VOL, PLEIN_FEU, BRAISE, AGONIE, RESIDU, MORTE }

const DUREE_PLEIN_FEU := 2.0          # s
const DUREE_BRAISE := 10.0        # s
const DUREE_AGONIE := 3.0         # s
const DUREE_RESIDU := 5.0         # s

const ENERGIE_PLEIN_FEU := 3.0
const ENERGIE_BRAISE := 1.2
const ENERGIE_RESIDU := 0.25
const ENERGIE_VOL := 0.8          # la comète : assez pour tracer l'arc, pas pour lire
const RACCORD_PLEIN_FEU_BRAISE := 1.5 # s de glissement plein feu → braise (dans l'acte braise)

# ── L'agonie : des rallumages, pas un strobe ────────────────────────────────
# Les instants de sursaut sont tirés d'une graine transmise au spawn : la liste
# entière se régénère à l'identique n'importe où, n'importe quand — c'est ce
# qui permet à la killcam d'afficher le bon état à un âge arbitraire.
#
# Le premier jet était un créneau on/off — « trop informatique » (Adrien, au
# premier essai, FU2.1). Chaque sursaut est désormais une ENVELOPPE : montée
# vive, retombée lente — un rallumage spontané de la combustion, pas un
# clignotement de diode.
const AGONIE_FLASHS_MIN := 3
const AGONIE_FLASHS_MAX := 5
const FLASH_DUREE_MIN := 0.08     # s — sert à étaler les centres dans l'agonie
const FLASH_DUREE_MAX := 0.12     # s
const FLASH_MONTEE := 0.05        # s — l'attaque du rallumage
const FLASH_DESCENTE := 0.30      # s — la braise qui retombe
const ENERGIE_FLASH := 2.5
const ENERGIE_CREUX := 0.15       # le quasi-noir entre deux sursauts
const RAMPE_AGONIE := 0.25        # s — l'effondrement vers le quasi-noir se fond

# ── La fumée ────────────────────────────────────────────────────────────────
# Dense au centre, claire aux bords : la cachette a un gradient spatial. La
# fumée met du temps à s'épaissir (le plein feu reste un scan) et meurt avec
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


## La vitesse restante après `delta` secondes de frottement — jamais négative.
static func vitesse_apres(vitesse: float, delta: float) -> float:
	return maxf(vitesse - FROTTEMENT_VOL * delta, 0.0)


## Le rebond sur un mur : réflexion sur la normale, puis amortissement.
static func rebondir(velocite: Vector2, normale: Vector2) -> Vector2:
	return velocite.bounce(normale) * REBOND_AMORTI


## La portée d'un lancer sans obstacle — dérivée, jamais recopiée.
static func portee_libre() -> float:
	return VITESSE_LANCER * VITESSE_LANCER / (2.0 * FROTTEMENT_VOL)


static func duree_combustion() -> float:
	return DUREE_PLEIN_FEU + DUREE_BRAISE + DUREE_AGONIE + DUREE_RESIDU


## L'acte à un âge de COMBUSTION donné (0 = l'atterrissage ; le vol est géré
## par l'appelant, qui connaît sa durée de vol).
static func acte_a(age: float) -> Acte:
	if age < 0.0:
		return Acte.VOL
	if age < DUREE_PLEIN_FEU:
		return Acte.PLEIN_FEU
	if age < DUREE_PLEIN_FEU + DUREE_BRAISE:
		return Acte.BRAISE
	if age < DUREE_PLEIN_FEU + DUREE_BRAISE + DUREE_AGONIE:
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
	# Marges DÉRIVÉES des enveloppes : l'attaque doit être éteinte à la
	# frontière de la braise, la retombée à celle du résidu — sans quoi le bord
	# d'acte tranche un sursaut en plein vol et redevient exactement le créneau
	# que FU2.1 supprime (attrapé par le contrôle de continuité de la suite).
	var debut_min := FLASH_MONTEE * 5.0
	var fin_max := DUREE_AGONIE - FLASH_DESCENTE * 3.0
	var tranche := (fin_max - debut_min) / float(nb)
	for i in nb:
		var duree := rng.randf_range(FLASH_DUREE_MIN, FLASH_DUREE_MAX)
		var marge := maxf(tranche - duree, 0.0)
		var debut := debut_min + float(i) * tranche + rng.randf_range(0.0, marge)
		fenetres.append([debut, debut + duree])
	return fenetres


## La lueur des rallumages à cet âge, dans [0, 1] : enveloppe asymétrique
## autour du centre de chaque fenêtre — attaque en FLASH_MONTEE, retombée en
## FLASH_DESCENTE. Continue partout : rien ne « clignote », tout se rallume.
## Les fenêtres se précalculent UNE fois par fusée (`fenetres_agonie`).
static func lueur_agonie(age: float, fenetres: Array) -> float:
	if acte_a(age) != Acte.AGONIE:
		return 0.0
	var t := age - DUREE_PLEIN_FEU - DUREE_BRAISE
	var lueur := 0.0
	for f in fenetres:
		var centre: float = (f[0] + f[1]) * 0.5
		var ecart := t - centre
		var sigma := FLASH_MONTEE if ecart < 0.0 else FLASH_DESCENTE
		lueur = maxf(lueur, exp(-(ecart * ecart) / (2.0 * sigma * sigma)))
	return lueur


## Un sursaut est-il « allumé » à cet âge ? Seuil sur la lueur — sert aux tests
## et à tout code qui veut un booléen plutôt qu'une enveloppe.
static func flash_actif(age: float, fenetres: Array) -> bool:
	return lueur_agonie(age, fenetres) > 0.5


## L'énergie lumineuse à un âge de combustion donné. `intensite_agonie` vient
## d'EffectPolicy (famille MONDE, plancher en classé) : à 1, le strobe est
## entier ; vers 0, les flashs s'aplatissent sur un fondu continu — le rythme
## reste porté par le SON, identique pour tous (variante photosensibilité).
static func energie_a(age: float, fenetres: Array, intensite_agonie: float = 1.0) -> float:
	match acte_a(age):
		Acte.VOL:
			return ENERGIE_VOL
		Acte.PLEIN_FEU:
			return ENERGIE_PLEIN_FEU
		Acte.BRAISE:
			var t := age - DUREE_PLEIN_FEU
			if t < RACCORD_PLEIN_FEU_BRAISE:
				return lerpf(ENERGIE_PLEIN_FEU, ENERGIE_BRAISE, t / RACCORD_PLEIN_FEU_BRAISE)
			return ENERGIE_BRAISE
		Acte.AGONIE:
			# Le fondu continu que verrait un joueur à intensité 0.
			var t := age - DUREE_PLEIN_FEU - DUREE_BRAISE
			var fondu := lerpf(ENERGIE_BRAISE, ENERGIE_RESIDU, t / DUREE_AGONIE)
			# Le plancher s'effondre vers le quasi-noir en RAMPE_AGONIE et en
			# remonte autant avant le résidu : les FRONTIÈRES d'acte aussi sont
			# des fondus, jamais des créneaux (contrôle de continuité de la suite).
			var creux := lerpf(fondu, ENERGIE_CREUX,
				minf(smoothstep(0.0, RAMPE_AGONIE, t),
					smoothstep(0.0, RAMPE_AGONIE, DUREE_AGONIE - t)))
			var sursaut := maxf(creux, lerpf(ENERGIE_CREUX, ENERGIE_FLASH,
				lueur_agonie(age, fenetres)))
			return lerpf(fondu, sursaut, clampf(intensite_agonie, 0.0, 1.0))
		Acte.RESIDU:
			var t := age - DUREE_PLEIN_FEU - DUREE_BRAISE - DUREE_AGONIE
			return lerpf(ENERGIE_RESIDU, 0.0, t / DUREE_RESIDU)
		_:
			return 0.0


## La température de couleur à un âge donné : 0 = blanc magnésium, 1 = braise.
## L'appelant mappe sur ses couleurs (Charte) — le modèle ne connaît pas la
## charte, il doit rester sans dépendance.
static func temperature_a(age: float) -> float:
	match acte_a(age):
		Acte.VOL, Acte.PLEIN_FEU:
			return 0.0
		Acte.BRAISE:
			var t := age - DUREE_PLEIN_FEU
			return clampf(t / RACCORD_PLEIN_FEU_BRAISE, 0.0, 1.0)
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
	var debut_residu := DUREE_PLEIN_FEU + DUREE_BRAISE + DUREE_AGONIE
	if age >= debut_residu:
		return lerpf(montee, 0.0, (age - debut_residu) / DUREE_RESIDU)
	return montee


## L'échelle des nappes (elles gonflent lentement sur la vie de la fusée).
static func echelle_fumee_a(age: float) -> float:
	var t := clampf(age / duree_combustion(), 0.0, 1.0)
	return lerpf(1.0, FUMEE_GONFLE, t)


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
