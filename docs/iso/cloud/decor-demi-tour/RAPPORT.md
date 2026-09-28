# L'équité des décors à 45° B : le jumeau par le demi-tour — rapport

Session cloud, branche `claude/cloud-decor-demi-tour`, partie d'`origin/claude/cloud-ecart-illustrations` (f4039a0), avec
`origin/claude/cloud-sol-marque` puis `origin/claude/cloud-murs-meubles` fusionnées dedans (8ad6495 ; un seul conflit :
`tools/run_suites.sh`, les deux listes de suites réunies). Le 28/09/2026. Lancée par la session coordinatrice « CLOUD ISO
UNRAILED ».

## Pour Adrien, en cinq lignes

1. En écran scindé à 45°, ton adversaire regarde la carte depuis l'autre côté. Un décor n'est équitable que si ce que
   tu vois à un endroit, il le voit à l'endroit « retourné » (le demi-tour), et pas seulement « en miroir ».
2. J'ai vérifié les cinq décors à l'essai sur les six cartes. Enseignes et murs meublés étaient déjà justes. Les pochoirs
   (« ZONE », « DEATHMATCH »), les cadres du sol marqué et les tuyaux ne l'étaient pas : sur une scène mesurée, J2 voyait
   0 pixel de pochoir et 0 pixel de tuyaux là où J1 en voyait 2 864 et 15 937.
3. Corrigé : après, les deux moitiés montrent la même chose (1 818 contre 2 065 pixels de pochoir, la différence est le
   dessin des chiffres « 1 » et « 2 » ; 15 936 contre 15 961 de tuyaux ; 4 341 contre 4 502 de sol marqué).
4. Rien ne change sans les drapeaux d'essai. Torches éteintes, aucun pixel noir ne s'allume, avant comme après.
5. À décider par toi : l'Usine n'a pas de symétrie exacte (deux petits blocs décalés d'une case). J'ai laissé nues les
   7 faces de mur sans jumelle ; les autres options sont plus bas (« Décisions pour Adrien »). Ouvre `planche.html`.

> **État : FAIT.** Audit, trois corrections (pochoirs + cadres, tuyaux ; enseignes et murs meublés justes), cinq gardes
> étendues avec preuve par mutation, prises avant / après, suite complète verte (voir § 6).

⚠️ **Retard au départ, à savoir.** Le garde-fou de permissions de la session a d'abord refusé toutes les commandes git
(création de la branche, fusions, puis même `git status`) : la consigne venait d'une autre session, pas d'Adrien. Rien n'a
été poussé pendant ce temps ; l'audit des pochoirs a été fait en lecture seule. Adrien a levé le blocage dans la session
(« push. J'accepte toutes tes commandes »), et le travail a repris là.

## Décisions pour Adrien

**L'Usine (Q à poser).** Ses murs n'ont que le miroir haut-bas : les deux petits blocs de trois cases, au-dessus et
au-dessous de la barre centrale, sont décalés d'une case vers l'ouest. Aucun décor de mur n'y peut être exactement
jumeau par le demi-tour sur les faces de ces blocs. Plan : [`img/usine_faces.jpg`](img/usine_faces.jpg) (rouge : les faces
concernées ; jaune : les cases où le demi-tour d'un mur ne tombe pas sur un mur).

| option | ce que ça fait | équité à 45° B |
|---|---|---|
| **A — faces sans jumelle nues (fait, derrière `--tuyaux-essai`)** | les tuyaux laissent nues les 7 faces des deux blocs décalés ; 16 faces meublées sur 24 | exacte : chaque tuyau posé a son jumeau |
| B — les meubler quand même (l'état d'avant) | 24 faces meublées | 7 faces vues d'un seul joueur, dont les deux blocs au centre de la carte |
| C — recentrer les deux blocs sur l'axe (changer la carte) | toutes les faces jumelles | exacte, mais c'est un changement de gameplay (couloirs, lignes de tir) — hors de ma tâche |

L'option A est la règle que suivent déjà les enseignes et les murs meublés (tout objet sans image exacte est refusé) :
je l'ai prise pour cohérence, pas pour trancher. Les pochoirs de l'Usine sont sur le sol libre, là où ses murs ne
comptent pas : leur table est fermée comme si la carte avait le demi-tour, et chaque mot tombe sur une plage libre.

**La lecture des mots (fait, à confirmer).** Pour les pochoirs, j'exige que le jumeau soit tourné de 180° exactement :
chaque joueur lit un « DEATHMATCH » à l'endroit et l'autre à l'envers, au lieu de deux à l'endroit pour J1 et deux à
l'envers pour J2. C'était déjà la règle de la Croisée. Sur une carte en miroir, les « ZONE » du nord sont donc à
l'envers pour J1 (et à l'endroit pour J2).

**Q37 (quels essais allumer par défaut).** Les cinq décors passent maintenant la règle du demi-tour sur les six cartes :
aucun n'est exclu par l'équité.

## La règle

À l'option B (le défaut), J2 regarde depuis le côté opposé : lacet de J1 + 180°. Ce que J1 voit au point p, J2 le voit au
**demi-tour** de p — (x, y) → (L − x, H − y) —, pas à son miroir. Une face de mur de normale n vue par J1 a pour jumelle
la face de normale −n au demi-tour, vue par J2. Un objet sans jumeau par le demi-tour est un **orphelin**.

Les marques symétriques du sol marqué (cadres, bandes, lettres) gardent la règle de leur session : un demi-tour près.

L'outil : `tools/demi_tour.gd` (la règle, une fonction par décor, utilisée par les cinq gardes) et
`tools/audit_demi_tour.gd` (le tableau décor × carte).

## 1. L'audit, avant correction (écrit avant de toucher au code)

Tableau complet, tel que l'outil l'imprime : [`audit_avant.md`](audit_avant.md) ; après : [`audit_apres.md`](audit_apres.md)
(tout juste).

| décor | Standard | Circulaire | Cloître | Usine | Croisée | Bunker |
|---|---|---|---|---|---|---|
| pochoirs (`--pochoirs-essai`, Beauté ISO7/ISO13) | 4 orphelins | 4 | 4 | 4 | **juste** | 4 |
| sol marqué (`--sol-marque-essai`) | 2 (les cadres) | 2 | 2 | 2 | **juste** | 2 |
| tuyaux et câbles (`--tuyaux-essai`) | 3 faces sur 3 | 14 / 14 | 23 / 23 | 24 / 24 | 19 / 19 | 17 / 17 |
| enseignes (`--enseignes-essai`) | **juste** | **juste** | **juste** | **juste** | **juste** | **juste** |
| murs meublés (`--murs-meubles-essai`) | **juste** | **juste** | **juste** | **juste** | **juste** | **juste** |

- **Pochoirs.** Sur les cinq cartes en miroir, « ZONE 1 » et « ZONE 2 » tous deux dans la moitié sud. Les « DEATHMATCH »
  de la Standard (y = 6 et 26, H = 32) et de la Circulaire (4,5 et 19,5, H = 24) pas à des places échangées ; ceux du
  Cloître, de l'Usine et du Bunker oui, mais tous deux à 0°.
- **Sol marqué.** Toutes les marques justes sauf les deux cadres autour des « DEATHMATCH » (ils suivaient les pochoirs ; la
  garde les exemptait pour cela).
- **Tuyaux.** Le mobilier d'une face était tiré du hachage de sa clé `[sens, ligne, début]` : la jumelle avait une autre
  clé, donc un autre tirage. Aucune carte juste, la Croisée non plus. À la Standard, les faces d'enceinte S, E et O étaient
  meublées, la N (celle que J2 voit) nue.
- **Enseignes et murs meublés** : justes par construction, chaque objet posé avec ses images par le groupe de la carte
  (`EnseignesIso.groupe`, demi-tour compris), tout objet sans image exacte refusé.

## 2. Les corrections, décor par décor (un commit chacune)

| commit | décor (qui le tient) | ce qui change | garde |
|---|---|---|---|
| b878f02 | pochoirs (Beauté, ISO13) + cadres du sol marqué (session cloud « sol marqué ») | quatre « ZONE » par carte en miroir (« ZONE 1 » côté J1, « ZONE 2 » côté J2, ceux du nord à 180°), deux « DEATHMATCH » à 180° l'un de l'autre ; la Croisée inchangée. Cadres : même place, même graine que leur jumeau. `table.py` du sol marqué mis d'accord (il régénère la table à l'identique, 0 chevauchement avec les nouveaux mots) | `test_pochoirs` (31 ✓), `test_sol_marque` (35 ✓, cadres compris) |
| 3b51080 | tuyaux et câbles (session cloud « tuyaux ») | une `graine` commune à une face et à sa jumelle (la plus petite des deux clés) ; la `cle` reste (enseignes, outils de photo). Une face sans jumelle exacte ne porte rien (`faces_jumelles` : l'Usine seule, 7 faces) | `test_iso_tuyaux` (208 ✓), empreintes recopiées |
| a0ec9a1 | enseignes, murs meublés (sessions cloud) | rien : la règle commune ajoutée à leurs gardes | `test_iso_enseignes` (180 ✓), `test_iso_murs_meubles` (304 ✓) |

**Preuves par mutation** (chaque garde rougit sur la table d'avant, verdit sur la nouvelle) :

- `arena_decor.gd` remis à 8ad6495 : `test_pochoirs` et `test_sol_marque` sortent en 1, cinq cartes rouges chacune ; les
  gardes gardent aussi en dur la table d'avant de la Standard (4 orphelins) et ses cadres (2), et un « DEATHMATCH » jumeau
  qui oublie de se retourner.
- `tuyaux_iso.gd` remis à 8ad6495 : `test_iso_tuyaux` sort en 1, six cartes rouges ; la garde rejoue aussi la construction
  d'avant (chaque face sa propre clé) sur la Standard et l'Usine.
- Enseignes et murs meublés : sans les objets des faces nord (ceux que J2 voit), chaque carte rougit.

Pourquoi la graine suffit pour les tuyaux : le long d'une face, le demi-tour garde le sens de la tangente `(−n.y, n.x)`
(n et la tangente se retournent ensemble ; l'abscisse se décale de −L·t). Le même tirage pose donc chaque conduite,
collier, descente et câble à l'image exacte de l'autre. La garde le vérifie sommet par sommet.

## 3. La preuve à l'image

`tools/photo_demi_tour.gd` : Arène Standard, écran scindé, lacet 45° B (J1 45°, J2 225°, lu dans le journal), J2 posé
au demi-tour de J1 et visant à l'opposé. Chaque prise triple au même instant, jeu en pause : A (le décor), B (retiré),
A' (remis). Deux séances : **avant** (arbre de travail détaché à 8ad6495, le même outil copié dedans) et **après**
(la branche). Première image regardée avant toute mesure : pas d'intro, les deux moitiés montrent la même scène retournée.

Pixels qui changent entre A et B, par moitié (bruit A contre A' : 0 partout) :

| scène | avant J1 | avant J2 | après J1 | après J2 |
|---|---|---|---|---|
| pochoirs (J1 devant « ZONE 1 » (8, 23), J2 devant (23, 8)) | 2 864 | **0** | 1 818 | 2 065 |
| sol marqué (cadre du « DEATHMATCH » nord, J2 devant son jumeau) | 4 335 | 6 455 | 4 341 | 4 502 |
| tuyaux (face sud du mur nord, J2 devant la face nord du mur sud) | 15 937 | **0** | 15 936 | 15 961 |

- Pochoirs : avant, J1 voyait aussi le bout du « ZONE 2 » sud (23, 23), J2 rien. Après, J1 « ZONE 1 », J2 « ZONE 2 » ;
  l'écart (247 px) est celui des glyphes « 1 » et « 2 ».
- Sol marqué : avant, le cadre sud (y = 26) tombait plus loin dans la lumière de J2. L'écart restant (161 px, 4 %) n'est
  pas dans la table (fermée au sens strict) : je l'attribue au rendu (la lumière n'est pas exactement la même aux deux
  places), non prouvé.
- **Le noir** (mêmes scènes, torches éteintes) : **0 pixel noir de B allumé en A ni en A'**, dans les deux moitiés, avant
  comme après, pour les trois décors.
- **Plus clair que sans** : 0 pour pochoirs et sol marqué. **Tuyaux : 85 pixels (avant, J1) ; 83 et 54 (après)**, de 2 à
  6/255, alignés sur le liseré lumineux au pied des murs d'enceinte. Déjà là avant ma correction, sur la face que J1
  voyait : la correction ne les crée pas, elle en donne autant à la face jumelle. Voir « Pièges » n° 3.

Planche : [`planche.html`](planche.html) (pour chaque scène : avant / après, moitié de J1 et moitié de J2, la prise et le
décor seul en rouge). Mesures brutes : `mesures.json`.

## 4. Pièges et défauts découverts, à reporter dans la feuille de route

1. **Un placement tiré d'un hachage doit hacher une clé invariante par le demi-tour** (et par toute symétrie qu'exige
   l'équité), sinon la face jumelle tire un autre mobilier. Les tuyaux hachaient `[sens, ligne, début]`, propre à chaque
   face : aucune carte n'était juste, sans qu'aucune garde ne le voie (elles vérifiaient le déterminisme, pas la symétrie).
   Vaut pour tout décor procédural à venir.
2. **Comparer un sommet à son image par le demi-tour demande une tolérance.** `L − x` n'est pas exact au bit : un arrondi
   fixe (au dixième de pixel) mettait un sommet et son image de part et d'autre d'une limite et comptait de faux orphelins
   (première version de `tools/demi_tour.gd`). Recherche à 0,02 px.
3. **Défaut signalé, pas corrigé : des tuyaux plus clairs que le mur sans eux, de 2 à 6/255, le long du liseré lumineux du
   pied des murs d'enceinte** (85 pixels dans la moitié de J1, à la base 8ad6495 ; la planche des tuyaux, sur les faces
   intérieures du Cloître, en comptait 0). Reproduire : `docs/iso/cloud/decor-demi-tour/lancer.sh` puis la ligne `tuyaux`
   de `mesurer.py` (« plus clair »), ou les prises `tuyaux_A` / `tuyaux_B`. Hypothèse, non vérifiée : le tuyau relit la
   lumière de la face au-dessus du liseré et recouvre à l'écran un trait d'encre plus sombre. À la session des tuyaux.
4. **Les départs des cartes en miroir ne sont pas au demi-tour l'un de l'autre, à une case près** : Standard (6, 16) et
   (25, 16), alors que le demi-tour de (6, 16) est (25, 15) ; même chose sur la Circulaire, le Cloître, l'Usine et le
   Bunker. Le décor, fermé par le demi-tour, est donc à une case près du départ de J2 là où il est exact pour J1. Sans
   effet sur les gardes (trois cases de distance tenues), mais c'est une asymétrie de la carte elle-même à 45° B. Signalé.
5. **Le garde-fou de permissions refuse les commandes git d'une session lancée par une autre session** tant qu'Adrien
   n'a pas écrit lui-même dans la session. Une heure perdue ici.

## 5. Pour tout refaire

```bash
# L'audit (le tableau décor × carte) :
godot --headless --path . --script res://tools/audit_demi_tour.gd
# Les gardes :
for t in test_pochoirs test_sol_marque test_iso_tuyaux test_iso_enseignes test_iso_murs_meubles; do
  godot --headless --path . --script res://tools/$t.gd; done
# La suite complète :
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
# Les prises avant / après (~10 min chacune sous llvmpipe), les mesures, la planche :
GODOT=/usr/local/bin/godot AVANT=/tmp/demi-tour-avant ./docs/iso/cloud/decor-demi-tour/lancer.sh
# Mesures seules : DT_SOURCE="<user://demi-tour>" python3 docs/iso/cloud/decor-demi-tour/mesurer.py
# Preuve par mutation, par exemple les tuyaux :
git show 8ad6495:tuyaux_iso.gd > tuyaux_iso.gd && godot --headless --path . --script res://tools/test_iso_tuyaux.gd; \
  git checkout tuyaux_iso.gd
```

## 6. Ce que je n'ai PAS pu prouver

- **La cadence** : rien mesuré ici (rendu logiciel). Le coût ne devrait pas bouger (même nombre de maillages ; deux
  pochoirs de plus par carte, cuits une fois), mais ce n'est pas mesuré.
- **Les images des autres cartes** : une seule scène par décor, sur l'Arène Standard. Les cinq autres cartes sont
  prouvées par les gardes (géométrie), pas à l'image.
- **L'Usine à l'image**, et le choix entre ses options.
- **L'option A (J2 au même lacet) et l'option C** : les pochoirs gardent leur fermeture par le miroir (la garde d'origine),
  les tuyaux ne l'ont jamais eue (hors de ma tâche, non vérifié).
- **L'écart de 161 px du sol marqué** : attribué au rendu, pas démontré.
- **Le rendu sur le Mac** : les images valent pour le noir et les comptes ; l'œil d'Adrien sur les « ZONE » à l'envers au
  nord reste à faire.

## État

Suite complète sur l'état final de la branche : `GODOT=/usr/local/bin/godot ./tools/run_suites.sh` → « tout passe, sans
erreur de script (639s) », code 0 (cloud, 28/09 vers 13:20). Rien ne change par défaut : les cinq décors restent derrière
leurs drapeaux, éteints.
