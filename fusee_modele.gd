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
## Q35 = B (Adrien, 2026-09-26) — ESSAI du rouge long, À DURÉE TOTALE ÉGALE (ordre 412) : `--fusee-rouge-long` porte le plein
## feu à 4 s et retire ces 2 s à la braise ; l'agonie et le résidu ne changent pas, la fusée vit toujours 20 s. La fumée garde
## donc exactement sa taille et sa densité à chaque âge (`echelle_fumee_a` rapporte l'âge à la durée de combustion), et le rouge
## dans la fumée pleine existe de 3 à 4 s, l'instant de l'illustration « Créer en ligne ». La première lecture (la braise
## gardée, la fusée vivant 22 s) a ÉCHOUÉ au banc d'équité sur l'aire cachée × temps : voir la ROADMAP. Lu une fois au
## chargement. ⚠️ Les deux pairs doivent porter le même drapeau : l'horloge est publique, simulée à l'identique — un essai,
## pas un réglage de match.
##
## **Q35 = OUI (Adrien, 2026-09-28 : « Avant de publier 0.7 : Q35 : oui ») — le rouge long est LE DÉFAUT depuis la 0.7.0.**
## Il entre sous le protocole 18, que rien n'avait encore publié : tous les jeux 0.7 ont la même horloge de fusée.
## `--sans-fusee-rouge-long` rend le plein feu de 2 s, en build de débogage SEULEMENT (les bancs qui comparent) : en build
## publié, un joueur qui le passerait lirait une autre horloge que son adversaire. `--fusee-rouge-long` reste accepté, sans effet.
const DUREE_PLEIN_FEU_LONG := 4.0
const DRAPEAU_ROUGE_LONG := "--fusee-rouge-long"
const DRAPEAU_SANS_ROUGE_LONG := "--sans-fusee-rouge-long"
static var duree_plein_feu: float = DUREE_PLEIN_FEU \
	if OS.is_debug_build() and DrapeauxDeLancement.present(DRAPEAU_SANS_ROUGE_LONG) else DUREE_PLEIN_FEU_LONG
## La braise de l'essai : elle rend au plein feu ce qu'il gagne, pour que la durée totale ne bouge pas.
static var duree_braise: float = DUREE_BRAISE - (duree_plein_feu - DUREE_PLEIN_FEU)
const DUREE_BRAISE := 10.0        # s
const DUREE_AGONIE := 3.0         # s
const DUREE_RESIDU := 5.0         # s

const ENERGIE_PLEIN_FEU := 3.0
const ENERGIE_BRAISE := 1.2
const ENERGIE_RESIDU := 0.25
const ENERGIE_VOL := 0.8          # la comète : assez pour tracer l'arc, pas pour lire
const RACCORD_PLEIN_FEU_BRAISE := 1.5 # s de glissement plein feu → braise (dans l'acte braise)

# ── Q58 — l'allumage : la fusée illumine loin ───────────────────────────────
# Adrien, 2026-10-01 vers 09:10 : « Q58 : il faudrait qu'à l'allumage la fusée illumine loin effectivement » — la question
# de la page des lumières (L1) : « La torche seule, ou toutes les lumières ? […] faut-il que le halo d'une fusée remplisse
# l'écran ? ». À l'allumage (l'atterrissage, le début du plein feu), le halo porte aussi loin que les torches
# (`rayon_allumage` : la portée au bord le plus proche de l'écran de Q76, 468 px), le tient, puis revient en douceur à son
# empreinte habituelle AVANT la braise. En vol, rien ne change. L'énergie non plus : le halo s'élargit, il ne brille pas
# davantage — l'éblouissement (qui lit l'énergie) ne bouge pas. Tout se dérive de l'âge de combustion : la killcam suit la
# même courbe, et rien ne passe sur le fil.
## La part du plein feu pendant laquelle le halo TIENT sa portée d'allumage : 0,25, soit 1 s sur le plein feu de 4 s.
const ALLUMAGE_TENUE := 0.25
## La part du plein feu où il a RETROUVÉ son empreinte habituelle : 0,75, soit 3 s, une seconde avant la braise. Entre les
## deux, un `smoothstep` : le bord du halo rentre sans à-coup (au plus 186 px/s, à mi-course).
const ALLUMAGE_FIN := 0.75
## Le rayon du halo à l'allumage, en pixels de monde ; 0 : pas d'allumage (la fusée de la 0.8.0 : `--sans-fusee-allumage`,
## en build de débogage et hors ligne). Posé par `GameSettings.accorder_au_mode` depuis le cadrage de la vue unique — le
## même calcul que la portée des torches (`PorteeEcran.portee_au_bord`) —, statique comme elle (`WeaponData.portee_plafond`) :
## la même valeur sur les deux machines, sans rien sur le fil.
static var rayon_allumage := 0.0

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

# ── FU3 — le tir dans la fumée ───────────────────────────────────────────────
# Un tir parti DE l'intérieur du nuage se dilue : toute la fumée pulse au lieu
# du seul point du canon, et la position du tireur se noie dans l'ensemble.
# Une balle qui TRAVERSE le nuage, elle, y creuse un tunnel rectiligne bref —
# incandescent pour une arme qui émet de la lumière (elle accuse le tireur),
# SOMBRE pour l'arbalète (la seule trace au monde de l'arme sans lumière).
const DIFFUSION_DUREE := 0.45     # s — le pouls qui dilue le flash de bouche
const TUNNEL_DUREE := 0.4         # s — la trace du tir dans la fumée, visible
const TUNNEL_LARGEUR := 10.0      # px — un trait, pas un couloir
const TUNNEL_ENTREE_MIN := 4.0    # px — sous ce seuil, un tunnel ne se lit pas

# ── FU5 — éteindre la fusée ──────────────────────────────────────────────────
# Piétiner une fusée AU SOL l'éteint : 0,7 s immobile dessus, le pied dans sa
# propre lumière — le moment le plus vulnérable que le jeu puisse offrir. Il
# remplace la lumière par un panache de fumée NOIRE, bref, qui couvre la fuite
# de l'éteigneur. Une balle l'éteignait aussi, en un coup, jusqu'au 2026-09-11 :
# Adrien l'a retiré, un gadget gazeux ne se tue pas au tir.
const EXTINCTION_PIETINEMENT := 0.7   # s immobile pour éteindre au pied
const EXTINCTION_RAYON := 24.0        # px — « sur » la fusée, pas dans tout son nuage
const EXTINCTION_VITESSE_MAX := 30.0  # px/s — tolérance d'immobilité humaine
const PANACHE_MONTEE := 0.3           # s — apparition quasi instantanée du panache
const PANACHE_DUREE := 3.0            # s — avant dissipation complète


## La vitesse restante après `delta` secondes de frottement — jamais négative.
static func vitesse_apres(vitesse: float, delta: float) -> float:
	return maxf(vitesse - FROTTEMENT_VOL * delta, 0.0)


## Le rebond sur un mur : réflexion sur la normale, puis amortissement.
static func rebondir(velocite: Vector2, normale: Vector2) -> Vector2:
	return velocite.bounce(normale) * REBOND_AMORTI


## La portée d'un lancer sans obstacle — dérivée, jamais recopiée.
static func portee_libre() -> float:
	return VITESSE_LANCER * VITESSE_LANCER / (2.0 * FROTTEMENT_VOL)


## Q35 — l'essai du rouge long, posé ou retiré sur place (les bancs et les suites comparent les deux) : le plein feu et la braise
## bougent ENSEMBLE, la durée totale jamais.
static func poser_rouge_long(actif: bool) -> void:
	duree_plein_feu = DUREE_PLEIN_FEU_LONG if actif else DUREE_PLEIN_FEU
	duree_braise = DUREE_BRAISE - (duree_plein_feu - DUREE_PLEIN_FEU)


static func duree_combustion() -> float:
	return duree_plein_feu + duree_braise + DUREE_AGONIE + DUREE_RESIDU


## L'acte à un âge de COMBUSTION donné (0 = l'atterrissage ; le vol est géré
## par l'appelant, qui connaît sa durée de vol).
static func acte_a(age: float) -> Acte:
	if age < 0.0:
		return Acte.VOL
	if age < duree_plein_feu:
		return Acte.PLEIN_FEU
	if age < duree_plein_feu + duree_braise:
		return Acte.BRAISE
	if age < duree_plein_feu + duree_braise + DUREE_AGONIE:
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
	var t := age - duree_plein_feu - duree_braise
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
			var t := age - duree_plein_feu
			if t < RACCORD_PLEIN_FEU_BRAISE:
				return lerpf(ENERGIE_PLEIN_FEU, ENERGIE_BRAISE, t / RACCORD_PLEIN_FEU_BRAISE)
			return ENERGIE_BRAISE
		Acte.AGONIE:
			# Le fondu continu que verrait un joueur à intensité 0.
			var t := age - duree_plein_feu - duree_braise
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
			var t := age - duree_plein_feu - duree_braise - DUREE_AGONIE
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
			var t := age - duree_plein_feu
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
	var debut_residu := duree_plein_feu + duree_braise + DUREE_AGONIE
	if age >= debut_residu:
		return lerpf(montee, 0.0, (age - debut_residu) / DUREE_RESIDU)
	return montee


## L'échelle des nappes (elles gonflent lentement sur la vie de la fusée).
static func echelle_fumee_a(age: float) -> float:
	var t := clampf(age / duree_combustion(), 0.0, 1.0)
	return lerpf(1.0, FUMEE_GONFLE, t)


## Q58 — la part de l'allumage à un âge de combustion, dans [0, 1] : 0 en vol ; 1 de l'atterrissage à `ALLUMAGE_TENUE` du
## plein feu ; un `smoothstep` jusqu'à 0 à `ALLUMAGE_FIN` ; 0 ensuite. Continue partout sauf à l'atterrissage, qui EST
## l'allumage. Rapportée à la durée du plein feu : le retour finit avant la braise, rouge long ou non.
static func part_allumage_a(age: float) -> float:
	if age < 0.0:
		return 0.0
	return 1.0 - smoothstep(ALLUMAGE_TENUE * duree_plein_feu, ALLUMAGE_FIN * duree_plein_feu, age)


## Q58 — le rayon du halo d'une fusée POSÉE à cet âge, en pixels de monde : de `rayon_allumage` à `rayon_pose` (son empreinte
## habituelle sur deux, `Fusee.EMPREINTE_LUMIERE` / 2) selon `part_allumage_a`. Jamais sous `rayon_pose` : un allumage plus
## court que le halo ne le rapetisse pas, et l'allumage éteint (`rayon_allumage` à 0) rend `rayon_pose` à tout âge.
static func rayon_halo_a(age: float, rayon_pose: float) -> float:
	return lerpf(rayon_pose, maxf(rayon_allumage, rayon_pose), part_allumage_a(age))


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


## FU3 — la force du pouls de diffusion, dans [0, 1], `age_depuis_tir` secondes
## après le tir. Un simple fondu : la dilution n'a pas besoin de rallumage,
## contrairement à l'agonie — c'est un seul événement, pas une combustion.
static func diffusion_a(age_depuis_tir: float) -> float:
	if age_depuis_tir < 0.0 or age_depuis_tir >= DIFFUSION_DUREE:
		return 0.0
	return 1.0 - smoothstep(0.0, DIFFUSION_DUREE, age_depuis_tir)


## FU3 — la force d'un tunnel de balle, dans [0, 1], `age_depuis_tir` secondes
## après que la balle a fini de le creuser (donc après sa sortie du nuage, ou
## sa mort dedans). Fondu simple sur TUNNEL_DUREE : « visible ~0,4 s ».
static func tunnel_force_a(age_depuis_tir: float) -> float:
	if age_depuis_tir < 0.0 or age_depuis_tir >= TUNNEL_DUREE:
		return 0.0
	return 1.0 - smoothstep(0.0, TUNNEL_DUREE, age_depuis_tir)


## FU5 — l'opacité du panache noir post-extinction, dans [0, 1],
## `age_depuis_extinction` secondes après le geste qui a éteint la fusée.
## Apparition quasi instantanée (PANACHE_MONTEE), puis dissipation sur le
## reste de PANACHE_DUREE — le panache doit COUVRIR la fuite, pas s'installer.
static func alpha_panache_a(age_depuis_extinction: float) -> float:
	if age_depuis_extinction < 0.0 or age_depuis_extinction >= PANACHE_DUREE:
		return 0.0
	var montee := clampf(age_depuis_extinction / PANACHE_MONTEE, 0.0, 1.0)
	return montee * (1.0 - smoothstep(PANACHE_DUREE * 0.5, PANACHE_DUREE, age_depuis_extinction))
