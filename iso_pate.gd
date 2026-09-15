## Miroir processeur de `iso_pate.gdshaderinc` — la même formule, pâte pour pâte.
##
## Il sert à UNE chose : que la suite headless vérifie l'invariant du noir absolu —
## monotone en la lumière, strictement 0 à lumière 0, sur les quatre pâtes — sans rien
## rendre. Le GPU, lui, se vérifie au pixel au banc (`--jeu --noir`).
##
## ⚠️ Toute retouche de la pâte se fait DANS LES DEUX fichiers. Le bruit n'est pas
## identique au bit près (flottants 64 bits ici, 32 là-bas) ; l'invariant, lui, ne
## dépend d'aucune valeur de motif, et la suite le balaie sur des centaines de lieux.
extends RefCounted

const BRUTE := -1
const GRAVURE := 0
const LIGNE_CLAIRE := 1
const TRAME := 2
const LAVIS := 3

## Les pâtes dans l'ordre de l'uniform `style`, sous le nom qu'Adrien lit sur planche.
const LETTRES := ["A", "B", "C", "D"]
const NOMS := {
	BRUTE: "brute (sans pâte)",
	GRAVURE: "A — gravure à l'encre",
	LIGNE_CLAIRE: "B — ligne claire",
	TRAME: "C — trame et encre décalée",
	LAVIS: "D — lavis et pochoir",
}

const POIDS := Vector3(0.2126, 0.7152, 0.0722)
const PLANCHER := 0.25


## `A`, `B`, `C`, `D` ou `brute` → valeur de l'uniform ; `-2` si inconnu.
static func style_depuis_nom(nom: String) -> int:
	var n := nom.strip_edges().to_upper()
	if n == "BRUTE" or n == "BRUT":
		return BRUTE
	var i := LETTRES.find(n)
	return i if i >= 0 else -2


static func luminance(c: Vector3) -> float:
	return c.dot(POIDS)


static func _fract(x: float) -> float:
	return x - floor(x)


static func _hash(p: Vector2) -> float:
	return _fract(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453)


static func _bruit(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1.0, 0.0))
	var c := _hash(i + Vector2(0.0, 1.0))
	var d := _hash(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _trait(coord: float, periode: float, demi_largeur: float, aa: float) -> float:
	var s := absf(_fract(coord / periode) - 0.5) * 2.0
	return 1.0 - smoothstep(demi_largeur - aa, demi_largeur + aa, s + aa)


## ISO7 — miroirs de `pate_vers_affiche`, `pate_depuis_affiche` et `pate_facteur` : un facteur
## d'habillage s'applique à la valeur AFFICHÉE (décodage sRGB, multiplication, encodage).
static func _vers_affiche_canal(c: float) -> float:
	var s := maxf(c, 0.0)
	return s / 12.92 if s < 0.04045 else pow((s + 0.055) / 1.055, 2.4)


static func _depuis_affiche_canal(a: float) -> float:
	var s := maxf(a, 0.0)
	return s * 12.92 if s < 0.0031308 else 1.055 * pow(s, 1.0 / 2.4) - 0.055


static func vers_affiche(c: Vector3) -> Vector3:
	return Vector3(_vers_affiche_canal(c.x), _vers_affiche_canal(c.y), _vers_affiche_canal(c.z))


static func depuis_affiche(a: Vector3) -> Vector3:
	return Vector3(_depuis_affiche_canal(a.x), _depuis_affiche_canal(a.y), _depuis_affiche_canal(a.z))


static func facteur(c: Vector3, f: float) -> Vector3:
	return depuis_affiche(vers_affiche(c) * maxf(f, 0.0))


## Miroir de `pate_matiere_et_encre` : matière et encre en valeur affichée, l'encre bornée par `plancher`.
static func matiere_et_encre(c: Vector3, matiere: float, reste: float, t: float, plancher: float) -> Vector3:
	var a := vers_affiche(c)
	var s := luminance(a)
	if s <= 0.0:
		return Vector3.ZERO
	var m := maxf(matiere, 0.0)
	var avec_encre := maxf(s * minf(m, reste), minf(s * m, plancher))
	var cible := lerpf(s * m, minf(s * m, avec_encre), clampf(t, 0.0, 1.0))
	return depuis_affiche(a * (cible / s))


## ISO7 — miroir de `PATE_TEINTE_CHAUDE` et `pate_temperature` : la teinte d'une lumière neutre, sa
## luminance gardée.
const TEINTE_CHAUDE := Vector3(1.10, 0.97, 0.80)


static func temperature(c: Vector3, force: float) -> Vector3:
	var l := luminance(c)
	if l <= 0.0 or force <= 0.0:
		return c
	var mx := maxf(c.x, maxf(c.y, c.z))
	var mn := minf(c.x, minf(c.y, c.z))
	var neutre := 1.0 - clampf((mx - mn) / maxf(mx, 0.0001), 0.0, 1.0)
	var teinte := TEINTE_CHAUDE / luminance(TEINTE_CHAUDE)
	var chaude := c * Vector3.ONE.lerp(teinte, clampf(force, 0.0, 1.0) * neutre)
	return chaude * (l / maxf(luminance(chaude), 0.000001))


## ISO7 — miroir de `pate_trait_de_bord` : 1 sur le trait, 0 au-delà.
static func trait_de_bord(distance: float, largeur: float, aa: float) -> float:
	return 1.0 - smoothstep(largeur - aa, largeur + aa, distance)


## ISO7 — miroir de `pate_encre_boite` : le facteur d'encre des arêtes d'une boîte, dans [reste, 1].
static func encre_boite(local: Vector3, demi: Vector3, echelle: Vector3, normale: Vector3, largeur: float,
		reste: float, px_monde: float) -> float:
	if largeur <= 0.0:
		return 1.0
	var d := (demi - local.abs()).max(Vector3.ZERO) * echelle
	var an := normale.abs()
	var bord := minf(d.y, d.z) if an.x > 0.5 else (minf(d.x, d.z) if an.y > 0.5 else minf(d.x, d.y))
	var w := maxf(largeur, px_monde)
	return lerpf(1.0, clampf(reste, 0.0, 1.0), trait_de_bord(bord, w, px_monde))


static func pate(couleur: Vector3, lumiere: float, st: int, motif: Vector2, pente: Vector2,
		lumiere_decalee: float, aa: float) -> Vector3:
	if st == BRUTE:
		return couleur
	if lumiere <= 0.0:
		return Vector3.ZERO
	var l := clampf(lumiere, 0.0, 1.0)
	if st == GRAVURE:
		var t := clampf(l * 2.2, 0.0, 1.0)
		var angle := 0.785398
		if pente.length() > 0.0001:
			angle = atan2(pente.y, pente.x)
		angle = floor(angle / 0.392699 + 0.5) * 0.392699
		var n := Vector2(cos(angle), sin(angle))
		var trait_1 := _trait(motif.dot(n), 6.0, 1.0 - t, aa)
		var trait_2 := _trait(motif.dot(Vector2(-n.y, n.x)), 6.0, clampf(1.0 - 2.0 * t, 0.0, 1.0), aa)
		return couleur * (1.0 - trait_1) * (1.0 - trait_2)
	var teinte := couleur / maxf(l, PLANCHER)
	if st == LIGNE_CLAIRE:
		var a := 0.012
		var q := 0.22 * smoothstep(0.02 - a, 0.02 + a, l) \
			+ 0.33 * smoothstep(0.2 - a, 0.2 + a, l) \
			+ 0.45 * smoothstep(0.5 - a, 0.5 + a, l)
		var bord := smoothstep(0.02, 0.06, pente.length())
		return teinte * q * (1.0 - 0.9 * bord)
	if st == TRAME:
		var p := Vector2(motif.x + motif.y, motif.y - motif.x) * 0.70710678 / 5.0
		var f := p - p.floor() - Vector2(0.5, 0.5)
		var d := f.length() * 1.41421356
		var rayon := sqrt(l) * 1.15
		var point := 1.0 - smoothstep(rayon - aa, rayon + aa, d + aa)
		var encre := 1.0 - 0.55 * (1.0 - smoothstep(0.0, 0.06, lumiere_decalee))
		return teinte * point * encre
	# LAVIS
	var b := _bruit(motif / 23.0)
	var grain := _bruit(motif / 3.0)
	var a := 0.01
	var e_1 := 0.02 + 0.03 * b
	var e_2 := 0.16 + 0.08 * b
	var e_3 := 0.42 + 0.1 * b
	var q := 0.3 * smoothstep(e_1 - a, e_1 + a, l) \
		+ 0.3 * smoothstep(e_2 - a, e_2 + a, l) \
		+ 0.4 * smoothstep(e_3 - a, e_3 + a, l)
	var gris := luminance(couleur)
	var lave := couleur.lerp(Vector3(gris, gris, gris), 0.35) / maxf(l, PLANCHER)
	return lave * q * (0.82 + 0.18 * grain)
