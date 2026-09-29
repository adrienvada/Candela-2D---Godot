class_name SonVisible
extends RefCounted

## Le son rendu visible — le MODÈLE, sans scène ni autoload.
##
## Chantier SON VISIBLE, version 0.8.0. Décisions d'Adrien du 2026-09-29 :
##
## > « je veux que le bruit ne soit pas seulement sonore, je veux qu'il soit
## > indiqué par un liseré ou quelque chose d'approchant sur les bords de l'écran
## > (comme un indicateur de dégâts dans beaucoup de fps pour indiquer la
## > direction du tir), mais ce liseré doit être d'autant plus étendu que le son
## > est loin / faible. »
## > « quand ils sont accroupis, le son soit le minimum […] un liseré très très
## > très léger, comme s'il entendait un bruissement, et qui donne une direction
## > très approximative à 180° par exemple »
## > « le liseré le plus précis doit faire à peu près 10° je pense lorsque le
## > joueur ennemi marche rapidement près du joueur »
## > Q47 : « on garde le clavier au maximum de bruit en normal. Le joueur pourra
## > s'accroupir s'il veut faire moins de bruit. »
## > Q48 : « le liseré indique TOUS les bruits localisés […] un code couleur
## > légèrement différent pour tout […] s'il y a beaucoup de bruit en même temps,
## > les bords d'écran d'un joueur peuvent être un peu chaotiques : c'est l'idée
## > […] La reverb des sons d'impact peut rendre plus flous les liserés »
##
## ## Deux ancres, et tout le reste en descend
##
## Adrien a donné deux cas, pas une courbe : le pas de course tout près fait
## **10°**, le pas accroupi fait **180°**. Ce fichier n'invente donc pas d'échelle :
## il pose ces deux cas sur le NIVEAU du son (la table `NIVEAU_RELATIF` d'
## `AudioManager`, jugée au banc par Adrien) et en dérive le reste.
##
## - Un pas debout part à -13 dB ; accroupi, `PAS_ACCROUPI_DB` le baisse de 9 dB.
##   → `NIVEAU_NET_DB` = -13 (10°), `NIVEAU_FLOU_DB` = -22 (180°).
## - **La distance coûte exactement l'écart entre les deux ancres** sur toute la
##   portée du son : un pas de course perd toute précision au bout de sa portée.
## - **Le seuil est l'ancre floue diminuée de cette même perte** : un pas
##   accroupi s'efface exactement au bout de sa portée — qui est déjà moitié
##   moindre (`PAS_ACCROUPI_PORTEE`).
## - Un tir (0 dB) reste au plus net d'un bout à l'autre de la carte ; c'est la
##   salle qui l'élargit (la réverbération), jamais la seule distance.
##
## ⚠️ **Le niveau est celui que l'OREILLE reçoit, pas un second dosage.** Le
## modèle lit ce que le moteur audio a décidé pour ce son — famille, allure,
## posture, duck sous le tir, fumée — plus une perte de distance qui lui est
## propre : l'atténuation du son, réglée par Adrien à la courbe 0,40, est presque
## plate (« presque tout s'entend presque partout »), et elle ne pourrait donc pas
## dire la distance à l'œil. C'est la seule divergence, et elle est voulue :
## l'oreille dose la présence, le liseré dit la précision.
##
## Ce fichier ne référence **aucun autoload** : il se `preload` sans danger depuis
## une suite lancée en `--script` (`tools/test_son_visible.gd`).

const Charte := preload("res://charte.gd")

# =============================================================================
# LES SORTES DE SONS — ce que le liseré raconte, et sa couleur
# =============================================================================

enum Categorie { PAS, FROLEMENT, TIR, PERCUTEUR, RECHARGE, DOUILLE, IMPACT, RICOCHET, CORPS, FUSEE, GADGET, AUTRE }

## Chaque famille de dosage (`AudioManager.famille_de`) rend une sorte. **La
## table se lit par famille, jamais par fichier** : ajouter une variante de tir
## ne demande rien ici, et c'est ce que `famille_de` garantit déjà au mixage.
##
## ⚠️ `tools/test_son_visible_jeu.gd` exige que CHAQUE famille de
## `AudioManager.NIVEAU_RELATIF` soit rangée ici ou déclarée muette : une famille
## livrée demain sans sa sorte tomberait sinon dans `AUTRE` sans que rien le dise.
const CATEGORIE_DE_FAMILLE: Dictionary = {
	"footstep": Categorie.PAS,
	"footstep_a": Categorie.PAS,
	"footstep_b": Categorie.PAS,
	# Le frôlement ET l'enjambement (même famille, +6 dB) : le corps contre la pierre.
	"wall_brush": Categorie.FROLEMENT,
	"shoot": Categorie.TIR,
	# Joué au canon, à l'instant du tir d'arbalète : c'est un second départ, pas
	# une trajectoire (voir `AudioManager.play_bolt_flight`).
	"bolt_flight": Categorie.TIR,
	"weapon_dry": Categorie.PERCUTEUR,
	"weapon_reload": Categorie.RECHARGE,
	"shell": Categorie.DOUILLE,
	"wall_impact": Categorie.IMPACT,
	"ricochet": Categorie.RICOCHET,
	"flesh_impact": Categorie.CORPS,
	"hit_center": Categorie.CORPS,
	"hit_edge": Categorie.CORPS,
	"breath_hit": Categorie.CORPS,
	"fusee_lancer": Categorie.FUSEE,
	"fusee_atterrit": Categorie.FUSEE,
	"fusee_rebond": Categorie.FUSEE,
	"fusee_eteinte": Categorie.FUSEE,
	"fusee_combustion": Categorie.FUSEE,
}

## Localisés, mais sans rien à apprendre : ils ne dessinent rien. La salle
## (`_tic_ambiance`) joue des gouttes et des craquements à des places tirées au
## sort ; les montrer ferait voir un adversaire qui n'existe pas.
const FAMILLES_MUETTES: Array[String] = ["ambience", "torch_on", "torch_off"]

## Les sons de gadget n'existent pas encore (« plus tard chaque gadget aura son
## bruit », Adrien) : leur famille commencera par ce préfixe, et ils trouveront
## leur sorte sans qu'on revienne ici.
const PREFIXE_GADGET := "gadget"

## La sorte d'une famille, ou -1 si elle ne dessine rien.
static func categorie_de(famille: String) -> int:
	if famille == "" or FAMILLES_MUETTES.has(famille):
		return -1
	if CATEGORIE_DE_FAMILLE.has(famille):
		return int(CATEGORIE_DE_FAMILLE[famille])
	if famille.begins_with(PREFIXE_GADGET):
		return Categorie.GADGET
	return Categorie.AUTRE

## Le code couleur (Q48 : « légèrement différent pour tout »).
##
## **Des formules sur la charte, jamais des couleurs de plus** (règle 4 de
## `charte.gd`). Quatre familles de teintes, qui disent ce qui a fait le bruit :
##
## - **le blanc chaud du tir** — `HALOGENE`, la couleur du flash de bouche ;
## - **le sable du corps qui bouge** — `PAPIER`, le béton sous la lampe, et plus
##   sombre pour le frôlement ;
## - **l'ambre du projectile** — `AMBRE`, la couleur des balles : vif pour le
##   ricochet (la balle vit encore), rouillé pour l'impact (elle est morte),
##   laiton pour la douille ;
## - **le rouge de ce qui saigne ou brûle** — le corps touché, rosé ; la fusée,
##   du rouge de sa flamme ;
## - **l'acier de l'arme qu'on manipule** — percuteur, rechargement ; plus sombre
##   pour les gadgets, qui sont de l'équipement.
##
## ⚠️ **Jamais `BLEU` ni `VERT`** : le bleu est « soi » et le liseré montre
## toujours un autre que soi ; le vert n'existe pas dans l'arène (règle 3).
## Et le `ROUGE` pur reste au voile de dégâts : un liseré de la même couleur que
## « je suis touché » mentirait sur ce qui vient d'arriver.
static func couleur(categorie: int) -> Color:
	match categorie:
		Categorie.TIR:
			return Charte.HALOGENE
		Categorie.PAS:
			return Charte.PAPIER
		Categorie.FROLEMENT:
			return Charte.BETON_CLAIR
		Categorie.RICOCHET:
			return Charte.AMBRE
		Categorie.IMPACT:
			return Charte.AMBRE.lerp(Charte.ROUILLE, 0.35)
		Categorie.DOUILLE:
			return Charte.AMBRE.lerp(Charte.PAPIER, 0.5)
		Categorie.CORPS:
			return Charte.ROUGE.lerp(Charte.HALOGENE, 0.4)
		Categorie.FUSEE:
			return Charte.ROUGE.lerp(Charte.AMBRE, 0.3)
		Categorie.PERCUTEUR:
			return Charte.ACIER.lerp(Charte.HALOGENE, 0.35)
		Categorie.RECHARGE:
			return Charte.ACIER
		Categorie.GADGET:
			return Charte.DIM
	return Charte.PAPIER.lerp(Charte.ACIER, 0.5)

## Combien la salle brouille chaque sorte (0 à 1). Adrien : « la reverb des sons
## d'impact peut rendre plus flous les liserés ». Les transitoires violents — tir,
## impact, ricochet — excitent toute la salle ; un pas la touche à peine.
const RESONANCE: Dictionary = {
	Categorie.TIR: 1.0,
	Categorie.IMPACT: 1.0,
	Categorie.RICOCHET: 1.0,
	Categorie.FUSEE: 0.6,
	Categorie.CORPS: 0.5,
	Categorie.GADGET: 0.5,
	Categorie.AUTRE: 0.5,
	Categorie.DOUILLE: 0.4,
	Categorie.PERCUTEUR: 0.3,
	Categorie.RECHARGE: 0.3,
	Categorie.PAS: 0.2,
	Categorie.FROLEMENT: 0.1,
}

## Combien de temps un liseré reste à l'écran, en secondes, avant la traîne de
## la salle. Court pour ce qui se répète (un pas toutes les 170 ms en courant),
## long pour ce qui est rare et lourd.
const DUREE: Dictionary = {
	Categorie.TIR: 0.90,
	Categorie.FUSEE: 0.80,
	Categorie.IMPACT: 0.70,
	Categorie.RICOCHET: 0.70,
	Categorie.CORPS: 0.70,
	Categorie.RECHARGE: 0.60,
	Categorie.GADGET: 0.60,
	Categorie.PERCUTEUR: 0.50,
	Categorie.AUTRE: 0.50,
	Categorie.PAS: 0.45,
	Categorie.FROLEMENT: 0.40,
	Categorie.DOUILLE: 0.40,
}

# =============================================================================
# L'ALLURE — Q47 : plus on va lentement, moins on fait de bruit
# =============================================================================

## Le pas le plus lent qu'on puisse faire DEBOUT, en écart au pas de course.
## Point de départ, à doser au banc comme les autres niveaux.
##
## ⚠️ **Toujours au-dessus du pas accroupi** (`PAS_ACCROUPI_DB` = -9 dB, portée
## moitié) : Adrien veut que s'accroupir reste LE moyen d'être au minimum, celui
## du clavier (Q47). Marcher lentement au stick aide, sans jamais valoir la
## posture — `tools/test_son_visible.gd` le vérifie.
const PAS_LENT_DB := -6.0

## L'écart de niveau d'un pas debout, selon l'allure : 0 dB à pleine vitesse,
## `PAS_LENT_DB` à l'arrêt. `allure` est la vitesse moyenne du dernier pas,
## rapportée à la vitesse de marche du joueur (`Player.speed`).
##
## Le clavier rend toujours une allure de 1 — « on garde le clavier au maximum de
## bruit en normal » (Q47) ; la manette la règle par l'inclinaison du stick, que
## `Input.get_vector` rend déjà proportionnelle.
static func ecart_allure_db(allure: float) -> float:
	return PAS_LENT_DB * (1.0 - clampf(allure, 0.0, 1.0))

# =============================================================================
# LA PERCEPTION — ce qu'un auditeur tire d'un son
# =============================================================================

## Le pas de course (famille `footstep`, pleine allure), à sa source : 10°.
const NIVEAU_NET_DB := -13.0
## Le pas accroupi à sa source (-13 - 9 dB) : 180°.
const NIVEAU_FLOU_DB := -22.0
## La perte de précision sur toute la portée d'un son : l'écart entre les deux
## ancres. Un pas de course passe de 10° à 180° en traversant sa portée.
const PERTE_DISTANCE_DB := NIVEAU_FLOU_DB - NIVEAU_NET_DB
## En deçà, rien ne se dessine : un pas accroupi s'efface au bout de sa portée.
const NIVEAU_SEUIL_DB := NIVEAU_FLOU_DB + PERTE_DISTANCE_DB
## Le coup de feu à sa source : le liseré le plus présent du jeu.
const NIVEAU_FORT_DB := 0.0

## Un mur coûte ce qu'il coûte à l'oreille : même pente que
## `AudioManager.OCCLUSION_PENTE_DB` (vérifié par `test_son_visible_jeu.gd`), et
## il ÉLARGIT en plus — le son n'arrive plus en ligne droite, il contourne.
const PERTE_OCCLUSION_DB := -5.0
const FLOU_OCCLUSION := 0.6
## Ce que la salle ajoute de flou, loin de la source : réverbération × distance
## rapportée à la diagonale de la carte × résonance de la sorte.
const FLOU_REVERB := 2.0

const LARGEUR_MIN_DEG := 10.0
const LARGEUR_MAX_DEG := 180.0

## La présence d'un liseré (opacité et épaisseur), par paliers posés sur les mêmes
## ancres : le pas accroupi au contact est « très très très léger » (Adrien), le pas
## de course au contact se lit franchement, le tir est plein.
##
## ⚠️ **Une puissance du niveau (γ = 1,8) rendait le pas de course à 0,29 d'opacité à
## 260 px** : juste pour le modèle, illisible à l'écran — le banc d'images l'a montré
## le 2026-09-29, un liseré de sable à 30 % sur du noir ne se voit pas en jouant. Les
## paliers disent directement ce qu'on doit VOIR à chaque ancre.
const PRESENCE_FLOU := 0.2
const PRESENCE_NET := 0.7
const ALPHA_MAX := 0.95
## Épaisseur du liseré, en pixels d'une vue de 1080 de haut.
const EPAISSEUR_MIN_PX := 6.0
const EPAISSEUR_MAX_PX := 26.0
## La part de l'épaisseur qui reste pleine avant le fondu vers l'intérieur.
const EPAISSEUR_PLEINE := 0.45
## La salle allonge aussi la traîne : jusqu'à ce facteur, à pleine réverbération.
const TRAINE_REVERB := 1.0

## Un son qui naît sur soi n'a pas de direction.
const RAYON_SOI_PX := 24.0

## Ce qu'un auditeur perçoit d'un son, ou `{}` s'il n'en perçoit rien. Pure.
##
## - `niveau_db` : le niveau à la source, tel que le moteur audio l'a posé (famille,
##   allure, posture, duck sous le tir) ;
## - `distance`, `portee` : en pixels du monde ; au-delà de la portée, le moteur
##   rend le son muet — le liseré aussi ;
## - `part_occultee` : 0, 1/3, 2/3 ou 1 (les trois rayons de l'audio) ;
## - `fumee_db` : l'étouffement de la fumée au point source (≤ 0) ;
## - `wet`, `diagonale` : la réverbération de la salle et la diagonale de la carte.
##
## Rend `largeur` (degrés), `alpha`, `epaisseur` (px à 1080p), `duree` (s),
## `douceur` (0 = bord franc, 1 = tout en fondu) et `niveau_percu` (dB).
static func percevoir(categorie: int, niveau_db: float, distance: float, portee: float,
		part_occultee: float = 0.0, fumee_db: float = 0.0, wet: float = 0.0,
		diagonale: float = 0.0) -> Dictionary:
	if categorie < 0 or portee <= 0.0 or distance >= portee:
		return {}
	var part := clampf(part_occultee, 0.0, 1.0)
	var r := clampf(distance / portee, 0.0, 1.0)
	var percu := niveau_db + PERTE_DISTANCE_DB * r + PERTE_OCCLUSION_DB * part + minf(fumee_db, 0.0)
	if percu <= NIVEAU_SEUIL_DB:
		return {}
	# La netteté, de 0 (180°) à 1 (10°), et la largeur en interpolation
	# GÉOMÉTRIQUE : chaque décibel multiplie la largeur par le même facteur, ce
	# qui est la seule façon qu'un décibel pèse pareil à 10° et à 150°.
	var nettete := clampf((percu - NIVEAU_FLOU_DB) / (NIVEAU_NET_DB - NIVEAU_FLOU_DB), 0.0, 1.0)
	var largeur := LARGEUR_MAX_DEG * pow(LARGEUR_MIN_DEG / LARGEUR_MAX_DEG, nettete)
	var resonance := float(RESONANCE.get(categorie, 0.5))
	var r_salle := clampf(distance / diagonale, 0.0, 1.0) if diagonale > 0.0 else r
	var flou_salle := FLOU_REVERB * maxf(wet, 0.0) * r_salle * resonance
	largeur = minf(largeur * (1.0 + flou_salle) * (1.0 + FLOU_OCCLUSION * part), LARGEUR_MAX_DEG)
	var presence := presence_de(percu)
	var duree := float(DUREE.get(categorie, 0.5)) * (1.0 + TRAINE_REVERB * maxf(wet, 0.0) * resonance)
	return {
		"largeur": largeur,
		"alpha": ALPHA_MAX * presence,
		"epaisseur": lerpf(EPAISSEUR_MIN_PX, EPAISSEUR_MAX_PX, presence),
		"duree": duree,
		"douceur": clampf(flou_salle + FLOU_OCCLUSION * part, 0.0, 1.0),
		"niveau_percu": percu,
	}

## La présence (0 à 1) d'un son perçu à `niveau_percu` dB : par paliers linéaires,
## du seuil (0) à l'ancre floue (`PRESENCE_FLOU`), à l'ancre nette (`PRESENCE_NET`),
## puis au coup de feu (1).
static func presence_de(niveau_percu: float) -> float:
	if niveau_percu <= NIVEAU_SEUIL_DB:
		return 0.0
	if niveau_percu <= NIVEAU_FLOU_DB:
		return PRESENCE_FLOU * inverse_lerp(NIVEAU_SEUIL_DB, NIVEAU_FLOU_DB, niveau_percu)
	if niveau_percu <= NIVEAU_NET_DB:
		return lerpf(PRESENCE_FLOU, PRESENCE_NET, inverse_lerp(NIVEAU_FLOU_DB, NIVEAU_NET_DB, niveau_percu))
	return lerpf(PRESENCE_NET, 1.0, clampf(inverse_lerp(NIVEAU_NET_DB, NIVEAU_FORT_DB, niveau_percu), 0.0, 1.0))

## L'opacité d'un liseré au fil de sa vie : une attaque brève, puis la courbe
## d'extinction de la charte (vite au début, une traîne ensuite — comme une
## réverbération). `age` et `duree` en secondes.
const ATTAQUE_S := Charte.D_COURT

static func enveloppe(age: float, duree: float) -> float:
	if age < 0.0 or duree <= 0.0 or age >= duree:
		return 0.0
	if age < ATTAQUE_S:
		return age / ATTAQUE_S
	var t := (age - ATTAQUE_S) / maxf(duree - ATTAQUE_S, 0.001)
	return 1.0 - Charte.courbe(Charte.Courbe.EXTINCTION, t)

## Le profil d'un liseré en travers de sa largeur : 1 en son cœur, 0 à ses bords.
## `x` va de -1 à 1. **Un liseré net a un cœur PLEIN** — un plateau sur 55 % de sa
## largeur, puis un fondu court : on lit sa largeur d'un coup d'œil. La salle et
## les murs (`douceur`) mangent le plateau jusqu'à n'en laisser qu'un dégradé, et
## c'est ainsi qu'un son flou se reconnaît.
##
## ⚠️ Le premier jet était un cosinus carré : juste en théorie, mais le cœur visible
## ne couvrait qu'un tiers de la largeur annoncée — un liseré « de 14° » se lisait à
## 5° (banc d'images du 2026-09-29).
const PLATEAU := 0.55

static func profil(x: float, douceur: float) -> float:
	var ax := absf(x)
	if ax >= 1.0:
		return 0.0
	var plein := PLATEAU * (1.0 - clampf(douceur, 0.0, 1.0))
	if ax <= plein:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (ax - plein) / (1.0 - plein))

# =============================================================================
# LA GÉOMÉTRIE — du monde au bord de l'écran
# =============================================================================

## Le point du bord de `cadre` que le rayon parti d'`origine` dans la direction
## `angle` (radians, 0 = droite, sens horaire à l'écran) rencontre en premier.
## `origine` est ramenée dans le cadre : un joueur hors champ ne fait pas sortir
## son liseré de l'écran.
static func point_du_bord(origine: Vector2, angle: float, cadre: Rect2) -> Vector2:
	var o := origine.clamp(cadre.position + Vector2.ONE, cadre.end - Vector2.ONE)
	var d := Vector2.RIGHT.rotated(angle)
	var t := INF
	if d.x > 0.000001:
		t = minf(t, (cadre.end.x - o.x) / d.x)
	elif d.x < -0.000001:
		t = minf(t, (cadre.position.x - o.x) / d.x)
	if d.y > 0.000001:
		t = minf(t, (cadre.end.y - o.y) / d.y)
	elif d.y < -0.000001:
		t = minf(t, (cadre.position.y - o.y) / d.y)
	if t == INF:
		return o
	return o + d * t

## La bande d'un liseré : des triplets de points (bord, milieu, intérieur), du
## premier bord angulaire au second, avec le profil de chaque triplet. Les points
## reculent le long du rayon, vers `origine` — de `EPAISSEUR_PLEINE` × `epaisseur`
## pour le milieu (jusque-là, plein), de `epaisseur` pour l'intérieur (fondu) : la
## bande reste continue dans les coins, là où une normale au bord sauterait.
##
## ⚠️ **Les coins de l'écran sont des échantillons obligés.** Entre deux rayons
## réguliers qui tombent de part et d'autre d'un coin, le segment coupe le coin
## en biais : le liseré y aurait une encoche, d'autant plus grande que le rayon
## rase le bord (près de 100 px à 3° d'écart, mesuré par la suite). Chaque coin
## compris dans la largeur ajoute donc son propre rayon.
static func bande(origine: Vector2, angle_centre: float, largeur_deg: float, cadre: Rect2,
		epaisseur: float, douceur: float, pas_deg: float = 3.0) -> Dictionary:
	var demi := deg_to_rad(largeur_deg) * 0.5
	var n := maxi(2, int(ceil(largeur_deg / maxf(pas_deg, 0.5))))
	var bords := PackedVector2Array()
	var milieu := PackedVector2Array()
	var dedans := PackedVector2Array()
	var poids := PackedFloat32Array()
	var o := origine.clamp(cadre.position + Vector2.ONE, cadre.end - Vector2.ONE)
	var abscisses: Array[float] = []
	for i in n + 1:
		abscisses.append(-1.0 + 2.0 * float(i) / float(n))
	if demi > 0.0:
		for coin in [cadre.position, Vector2(cadre.end.x, cadre.position.y), cadre.end,
				Vector2(cadre.position.x, cadre.end.y)]:
			var ecart := wrapf((coin - o).angle() - angle_centre, -PI, PI)
			if absf(ecart) < demi:
				abscisses.append(ecart / demi)
		abscisses.sort()
	for x in abscisses:
		var a := angle_centre + x * demi
		var b := point_du_bord(o, a, cadre)
		var vers_o := o - b
		var l := vers_o.length()
		var dir := vers_o / l if l > 0.001 else Vector2.ZERO
		bords.append(b)
		milieu.append(b + dir * minf(epaisseur * EPAISSEUR_PLEINE, l))
		dedans.append(b + dir * minf(epaisseur, l))
		poids.append(profil(x, douceur))
	return {"bords": bords, "milieu": milieu, "dedans": dedans, "poids": poids}

## L'angle à l'écran d'un son, depuis l'auditeur : entre deux points PROJETÉS,
## parce qu'en vue inclinée l'angle du monde n'est plus celui de l'écran. NAN si
## les deux projections se confondent (le son naît sur l'auditeur).
static func angle_a_l_ecran(ecran_auditeur: Vector2, ecran_source: Vector2) -> float:
	var d := ecran_source - ecran_auditeur
	if d.length_squared() < 0.0001:
		return NAN
	return d.angle()
