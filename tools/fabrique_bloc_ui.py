#!/usr/bin/env python3
"""Fabrique les plaques de bloc de l'interface voxel (chantier ISO11, l'interface au thème iso voxel).

Une plaque d'interface est un BLOC : une face du dessus éclairée, des flancs dans
l'ombre, une arête d'encre, du plâtre ocre patiné de rouille. Trois images en
neuf tranches (`StyleBoxTexture`), une par état — au repos, sous la torche,
enfoncée.

## Les quatre règles, et pourquoi chacune n'est pas un goût

1. **La matière vient du JEU.** La source est `assets/iso/face_mur.png`, la face
   des murs du duel — déjà aplanie, tuilée et mise en facteur par
   `tools/fabrique_textures_iso.py`. Les plaques du menu sont donc faites du
   plâtre que le joueur voit en arène, pas d'une imitation qui lui ressemble.

2. **L'image ne porte que des FACTEURS, jamais une couleur d'état.** Règle
   reprise d'`iso_materiaux.gd` : « une matière est un facteur de la lumière,
   jamais une lumière ». Le blanc vaut la face du dessus ; tout le reste est une
   fraction. La couleur, c'est `modulate_color` qui la donne — donc un bloc
   bleu, ambre ou rouge est la MÊME image, et les plaques se dessinent ensemble.

3. **La patine ne peut qu'ASSOMBRIR.** La rouille est appliquée comme une teinte
   multiplicative (le canal rouge gardé, le vert et le bleu rabattus). Une patine
   qui éclaircirait rapprocherait la plaque du texte clair posé dessus ; celle-ci
   ne le peut pas, par construction et non par réglage.

4. **Le contraste est VÉRIFIÉ ici, pixel par pixel, pas promis.** Le script
   compose chaque état avec la couleur que la charte lui donnera, mesure la
   luminance de chaque pixel de la zone qui peut porter du texte, et refuse
   d'écrire un fichier qui sort des seuils. Il imprime les extrêmes mesurés.

⚠️ **Le centre se RÉPÈTE, les bords non.** Les neuf tranches tuilent le centre
(`axis_stretch` en TILE) : une tache marquée au centre reviendrait tous les
128 px et se lirait comme un motif, pas comme une patine. La patine est donc
faible au centre et franche sur les bords et les coins, qui ne se répètent pas —
ce qui est aussi là où l'eau coule sur un vrai mur.

Usage : tools/fabrique_bloc_ui.py [--sortie assets/ui/matiere] [--graine 7]
"""
import sys

from PIL import Image, ImageChops, ImageFilter

# --- Ce que la charte dit, recopié ici et VÉRIFIÉ par tools/test_habillage.gd --
#
# Recopié parce qu'un script Python ne lit pas `charte.gd` ; vérifié parce qu'un
# doublon qu'on accepte est un doublon qu'on surveille. La suite relit le PNG et
# le compare aux constantes de la charte : si l'une bouge sans l'autre, ça rougit.
ENCRE = (0.075, 0.063, 0.051)
PAPIER = (0.80, 0.72, 0.62)
ROUILLE = (0.494, 0.251, 0.137)
VOXEL_DESSUS = (0.37225, 0.33237, 0.28429)
VOXEL_FACTEUR_FLANC = 0.41
VOXEL_ARETE_RESTE = 0.25
VOXEL_DESSUS_PX = 10
VOXEL_FLANC_PX = 6
VOXEL_ARETE_PX = 2
# La période de la matière, en pixels d'interface. **C'est celle du JEU** :
# `IsoMateriaux.PERIODE_FACE_MUR_PX` fait revenir la face des murs tous les 70 px
# de monde. À 128 px, les pierres du menu étaient deux fois plus grosses que les
# mêmes pierres en duel — la plaque lisait « photo de mur » au lieu de « plâtre ».
VOXEL_TUILE_PX = 70
VOXEL_PATINE_LUM_MAX = 0.0713

# Le bas d'une plaque : l'arête d'encre plus le rebord qui rentre dans l'ombre.
VOXEL_BAS_PX = 8

# La force de la matière sur une plaque d'interface. Même valeur que
# `IsoMateriaux.FORCE_MATIERE_SOL` : une surface qui porte déjà autre chose (là
# des dalles, ici du texte) prend une matière de moitié.
FORCE_MATIERE = 0.5

# La patine, par zone. Le centre se répète : il reste sous la moitié du reste.
PATINE_CENTRE = 0.10
PATINE_BORD = 0.45
PATINE_COIN = 0.60

# Le profil de chaque état : (facteur du dessus, facteur du corps, nom).
#
# Au repos, le bloc est dans l'ombre et son modelé se voit (corps à 0,41 du
# dessus — le rapport 2,46 mesuré sur la vitrine). Sous la torche, la lumière
# ÉCRASE le modelé : les faces se rejoignent. C'est ce qu'on voit sur n'importe
# quel volume éclairé de face, et c'est aussi ce qui garde 4,5:1 au texte sombre
# qu'une plaque allumée porte.
# **Quatre plaques, et non trois : deux lumières croisées avec deux positions.**
# Un bloc est dans l'ombre ou sous la torche ; il est sorti ou rentré. Les trois
# premières suffisaient tant qu'on n'enfonçait que ce qu'on touche — mais
# l'entrée de menu CHOISIE reste rentrée sans être touchée, et sa plaque doit
# rester sombre : son libellé est un `Label` enfant, à couleur fixe, qui devient
# illisible sur une plaque allumée (le bouton, lui, change la couleur de son
# propre texte). D'où la quatrième.
#
# Enfoncée, **le dessus devient un flanc** : la règle est celle de `charte.gd` et
# le nombre n'est pas choisi — c'est le corps multiplié par `VOXEL_FACTEUR_FLANC`,
# le rapport mesuré sur la vitrine. Un bloc qui s'enfonce sort de la lumière d'en
# haut ; sa face du dessus prend exactement la valeur de ses propres côtés.
ETATS = {
	"bloc_plaque": (1.00, VOXEL_FACTEUR_FLANC),
	"bloc_plaque_allumee": (1.00, 0.90),
	"bloc_plaque_enfoncee": (0.90 * VOXEL_FACTEUR_FLANC, 0.90),
	"bloc_plaque_rentree": (VOXEL_FACTEUR_FLANC * VOXEL_FACTEUR_FLANC, VOXEL_FACTEUR_FLANC),
}


def luminance(r, g, b):
	"""La luminance relative des seuils de lecture (sRGB linéarisé), sur [0,1]."""
	c = []
	for v in (r, g, b):
		c.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
	return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def matiere(source, cote, force):
	"""La face des murs, ramenée au côté voulu et rendue TUILABLE à ce côté-là.

	⚠️ Découper 128 px dans une image tuilable à 512 ne donne pas une image
	tuilable à 128 : la couture revient. On réduit d'abord, puis on refait le
	croisement décalé — le même geste que `tuiler()` de la fabrique du jeu.
	"""
	im = Image.open(source).convert("L").resize((cote, cote), Image.LANCZOS)
	decale = ImageChops.offset(im, cote // 2, cote // 2)
	masque = Image.new("L", (cote, cote))
	valeurs = []
	for y in range(cote):
		dy = abs(y + 0.5 - cote / 2) / (cote / 2)
		for x in range(cote):
			dx = abs(x + 0.5 - cote / 2) / (cote / 2)
			t = min(1.0, max(0.0, (max(dx, dy) - 0.55) / 0.4))
			valeurs.append(int(t * t * (3 - 2 * t) * 255))
	masque.putdata(valeurs)
	im = Image.composite(decale, im, masque)

	# En facteur autour de 1, amplitude bridée : la matière module, elle ne peint pas.
	d = list(im.getdata())
	moy = sum(d) / len(d)
	return [1.0 + (v / moy - 1.0) * force for v in d]


def patine(largeur, hauteur, graine):
	"""Le masque de patine : 0 au centre propre, 1 là où l'oxyde s'est installé.

	Des taches molles, posées par un générateur à graine fixe (donc rejouable),
	pondérées par la distance au bord — l'eau coule sur les arêtes et stagne en bas.
	"""
	import random

	rng = random.Random(graine)
	brut = Image.new("L", (largeur, hauteur), 0)
	px = brut.load()
	for _ in range(220):
		cx = rng.randrange(largeur)
		cy = rng.randrange(hauteur)
		r = rng.randint(3, 11)
		force = rng.randint(90, 255)
		for y in range(max(0, cy - r), min(hauteur, cy + r + 1)):
			for x in range(max(0, cx - r), min(largeur, cx + r + 1)):
				d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
				if d <= r:
					v = int(force * (1.0 - d / r) ** 1.5)
					if v > px[x, y]:
						px[x, y] = v
	brut = brut.filter(ImageFilter.GaussianBlur(2.0))
	return [v / 255.0 for v in brut.getdata()]


def zone(x, y, largeur, hauteur):
	"""Où tombe ce pixel : coin, bord, ou centre (le centre est ce qui se répète)."""
	gauche = x < VOXEL_FLANC_PX
	droite = x >= largeur - VOXEL_FLANC_PX
	haut = y < VOXEL_DESSUS_PX
	bas = y >= hauteur - VOXEL_BAS_PX
	if (gauche or droite) and (haut or bas):
		return PATINE_COIN
	if gauche or droite or haut or bas:
		return PATINE_BORD
	return PATINE_CENTRE


def relief(x, y, largeur, hauteur, dessus, corps):
	"""Le facteur de relief d'un pixel : sa face, son arête, son dégradé.

	Le repère est celui d'un bloc vu d'un peu au-dessus : la bande du haut est la
	face du dessus, les bandes latérales sont les flancs qui fuient, la bande du
	bas est le rebord qui rentre dans l'ombre. L'arête d'encre cerne le tout et
	garde `VOXEL_ARETE_RESTE` de la face qu'elle borde — la règle du jeu.
	"""
	a = VOXEL_ARETE_PX
	bas_y = hauteur - VOXEL_BAS_PX

	# ⚠️ **Pas d'encre AU-DESSUS de la face du dessus.** Un trait noir posé sur le
	# bord haut d'un bloc disparaît sur le fond noir des menus : la plaque perdait
	# sa silhouette au lieu d'en gagner une. C'est la règle du jeu, déjà écrite
	# pour les murs (`IsoMateriaux.LISERE_SOMMET_PX`) : le bord du sommet prend la
	# lumière de la face qu'il couronne. Ici, c'est cette bande éclairée — et elle
	# seule — qui détache le bloc du noir.
	if x < a or x >= largeur - a or y >= hauteur - a:
		face = dessus if y < VOXEL_DESSUS_PX else corps
		return face * VOXEL_ARETE_RESTE

	# **Les arêtes INTERNES, celles qui font le volume.** Entre la face du dessus
	# et la face avant, et de part et d'autre entre l'avant et les flancs : ce sont
	# elles qu'on voit sur le cube de tête du mannequin, et sans elles une plaque
	# n'est qu'un rectangle plus clair en haut. Elles vivent dans les tranches de
	# bord, donc elles ne se répètent jamais au centre.
	if y == VOXEL_DESSUS_PX - 1:
		return dessus * VOXEL_ARETE_RESTE
	if y == bas_y:
		return corps * VOXEL_ARETE_RESTE
	if y > VOXEL_DESSUS_PX and (x == VOXEL_FLANC_PX - 1 or x == largeur - VOXEL_FLANC_PX):
		return corps * VOXEL_ARETE_RESTE

	if y < VOXEL_DESSUS_PX:
		# La face du dessus s'éteint en descendant vers son arête.
		t = y / max(1, VOXEL_DESSUS_PX - 1)
		return dessus * (1.0 - 0.14 * t)

	f = corps
	if y > bas_y:
		t = (y - bas_y) / max(1, VOXEL_BAS_PX - a)
		f *= 1.0 - 0.45 * min(1.0, t)
	if x < VOXEL_FLANC_PX:
		t = 1.0 - x / max(1, VOXEL_FLANC_PX - 1)
		f *= 1.0 - 0.28 * min(1.0, t)
	elif x >= largeur - VOXEL_FLANC_PX:
		t = (x - (largeur - VOXEL_FLANC_PX)) / max(1, VOXEL_FLANC_PX - 1)
		f *= 1.0 - 0.28 * min(1.0, t)
	return f


def teinte_de_rouille():
	"""La rouille en TEINTE multiplicative, normalisée sur son canal le plus fort.

	`ROUILLE / VOXEL_DESSUS` demanderait 1,33 au rouge — impossible dans une
	image. On garde le RAPPORT entre canaux et on le ramène sous 1 : la patine
	rabat le vert et le bleu, ne touche pas le rouge, et ne peut donc
	qu'assombrir. C'est la règle 3, et elle est ici, en trois lignes.
	"""
	rapport = [ROUILLE[i] / VOXEL_DESSUS[i] for i in range(3)]
	m = max(rapport)
	return [v / m for v in rapport]


def fabriquer(nom, dessus, corps, mat, pat, largeur, hauteur, rouille):
	im = Image.new("RGB", (largeur, hauteur))
	sortie = []
	for y in range(hauteur):
		for x in range(largeur):
			i = y * largeur + x
			f = relief(x, y, largeur, hauteur, dessus, corps)
			f *= mat[(y % VOXEL_TUILE_PX) * VOXEL_TUILE_PX + (x % VOXEL_TUILE_PX)]
			s = pat[i] * zone(x, y, largeur, hauteur)
			canaux = []
			for c in range(3):
				v = f * (1.0 - s + s * rouille[c])
				canaux.append(int(round(max(0.0, min(1.0, v)) * 255)))
			sortie.append(tuple(canaux))
	im.putdata(sortie)
	return im


def mesurer(im, couleur, nom):
	"""Compose la plaque avec la couleur que la charte lui donnera, et mesure.

	On ne mesure que la zone qui peut porter du texte — le corps, arêtes et
	bandes exclues : personne n'écrit sur le rebord d'un bloc.
	"""
	largeur, hauteur = im.size
	px = im.load()
	lo, hi = 1.0, 0.0
	# La zone de texte : le corps, sans les tranches de bord.
	for y in range(VOXEL_DESSUS_PX, hauteur - VOXEL_BAS_PX):
		for x in range(VOXEL_FLANC_PX, largeur - VOXEL_FLANC_PX):
			r, g, b = px[x, y]
			l = luminance(r / 255 * couleur[0], g / 255 * couleur[1], b / 255 * couleur[2])
			lo = min(lo, l)
			hi = max(hi, l)
	return lo, hi


def main(argv):
	sortie = "assets/ui/matiere"
	graine = 7
	for i, a in enumerate(argv):
		if a == "--sortie" and i + 1 < len(argv):
			sortie = argv[i + 1]
		elif a == "--graine" and i + 1 < len(argv):
			graine = int(argv[i + 1])

	largeur = VOXEL_FLANC_PX * 2 + VOXEL_TUILE_PX
	hauteur = VOXEL_DESSUS_PX + VOXEL_TUILE_PX + VOXEL_BAS_PX
	mat = matiere("assets/iso/face_mur.png", VOXEL_TUILE_PX, FORCE_MATIERE)
	pat = patine(largeur, hauteur, graine)
	rouille = teinte_de_rouille()
	print("plaque %d×%d, tranches haut %d bas %d flanc %d, arête %d"
		% (largeur, hauteur, VOXEL_DESSUS_PX, VOXEL_BAS_PX, VOXEL_FLANC_PX, VOXEL_ARETE_PX))
	print("rouille en teinte multiplicative : %.3f, %.3f, %.3f" % tuple(rouille))

	# Les deux seuils, calculés et non recopiés : le papier doit tenir 4,5:1 sur
	# une plaque au repos, l'encre doit tenir 4,5:1 sur une plaque allumée.
	plafond_repos = VOXEL_PATINE_LUM_MAX
	plancher_allume = 4.5 * (luminance(*ENCRE) + 0.05) - 0.05
	# ⚠️ On fabrique et on mesure TOUT avant d'écrire quoi que ce soit. Écrire au
	# fil de la boucle laisserait, sur un état fautif, un dossier moitié neuf et
	# moitié ancien — et le jeu afficherait une plaque au repos qui ne va plus
	# avec sa plaque allumée, sans que rien ne le dise.
	faute = 0
	prete = []
	for nom, (dessus, corps) in ETATS.items():
		im = fabriquer(nom, dessus, corps, mat, pat, largeur, hauteur, rouille)
		# Chaque plaque est mesurée SOUS LA COULEUR QU'ELLE PORTERA : les plaques
		# de l'ombre sous la face du dessus, les allumées sous le papier. Mesurer
		# les quatre sous la même couleur dirait juste sur une et faux sur l'autre.
		dans_l_ombre = nom in ("bloc_plaque", "bloc_plaque_rentree")
		couleur = VOXEL_DESSUS if dans_l_ombre else PAPIER
		lo, hi = mesurer(im, couleur, nom)
		if dans_l_ombre:
			depasse = hi > plafond_repos
			faute += 1 if depasse else 0
			print("  %-24s luminance du corps %.4f à %.4f — plafond %.4f : %s"
				% (nom, lo, hi, plafond_repos, "DÉPASSE" if depasse else "OK"))
		else:
			sombre = lo < plancher_allume
			faute += 1 if sombre else 0
			print("  %-24s luminance du corps %.4f à %.4f — plancher %.4f : %s"
				% (nom, lo, hi, plancher_allume, "TROP SOMBRE" if sombre else "OK"))
		prete.append((nom, im))
	if faute:
		print("✗ %d plaque(s) hors des seuils de lecture : rien n'est écrit" % faute)
		return 1
	for nom, im in prete:
		chemin = "%s/%s.png" % (sortie, nom)
		im.save(chemin)
		print("  écrit %s" % chemin)
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
