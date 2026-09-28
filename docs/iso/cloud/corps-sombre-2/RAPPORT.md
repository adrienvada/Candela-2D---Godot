# Q39, deuxième tour — le risque de Beauté, et sa variante (session cloud corps-sombre-2, 2026-09-28)

Branche `claude/cloud-corps-sombre-2`, partie d'`origin/claude/cloud-integration-blanc` (d84c650), avec
`origin/claude/cloud-corps-sombre` (3c968da) fusionnée dedans (7493c82). Le 28/09/2026, de ~12:50 à ~15:30 (heure de Paris),
après un arrêt de ~02:30 à 12:45 (voir plus bas). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». **Rien ne
change par défaut** : les deux essais sont derrière leurs drapeaux, éteints ; le seul changement hors drapeau (le relais des
lightmaps, § 3) ne change aucun pixel.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` : ton personnage aujourd'hui (bleu clair), avec l'essai A d'hier (sombre partout) et avec l'essai
   B de Beauté (sombre seulement quand le bleu clair se perd dans un sol éclairé) — quatre classes, six lumières.
2. **B garde le personnage d'aujourd'hui partout où il se voyait déjà bien** (noir, ta torche, la torche d'en face : image
   identique au pixel) et **devient sombre sous une fusée**, là où aujourd'hui on ne se voit plus (20 % → 99-100 %).
3. Ton adversaire ne voit aucune différence, ni avec A ni avec B : vérifié pixel par pixel en écran scindé.
4. Le risque technique que Beauté avait vu (des morceaux de personnage qui pouvaient disparaître) est corrigé et gardé
   par un test ; le rendu du cloud ne l'a jamais montré à l'image, avant comme après (voir « Ce que je n'ai pas prouvé »).
5. C'est toujours ton choix (Q39) : A, B, ou rien. Les images viennent du rendu logiciel du cloud : couleurs justes,
   cadence et finesse à revoir au Mac (`--corps-soi-sombre` pour A, `--corps-soi-sombre=fondu` pour B).

## Le push, et les refus du garde-fou

Au premier passage (~02:30), le garde-fou de permissions a refusé la résolution des conflits de la fusion ; la session s'est
arrêtée là jusqu'au message de 12:45 relayant Adrien (« Fais en sorte que les sessions cloud 30h qui n'ont pas fini
terminent »), après quoi la résolution est passée. Il a aussi refusé le lien du binaire Godot dans `/usr/local/bin` (le
binaire tourne depuis `/tmp/Godot_v4.7-stable_linux.x86_64`, passé aux scripts par `GODOT=`), et un premier
`git push -u origin claude/cloud-corps-sombre-2` vers 13:05 ; je ne l'ai pas retenté. **La branche a été poussée vers 14:00,
sur la demande directe d'Adrien dans cette session (« push »)**, puis de nouveau à la fin. Aucune pull request (consigne).

## 1. La fusion (7493c82)

Deux conflits, résolus comme l'évaluation 11 (`docs/iso/cloud/ecart-11/RAPPORT.md`, § 1), sans rien jeter :
`iso_materiaux.gd` (`accorder_corps` : le bloc CORPS_DETAIL puis le bloc CORPS_SOI_SOMBRE) et `voxel_catalogue.gd` (les blocs
Q33 et Q39 l'un après l'autre). Ancres vérifiées par grep dans l'arbre fusionné (`func`, drapeaux `"--…"`, `#define`,
`#ifdef` ajoutés depuis la base commune) : 19 côté intégration, 33 côté corps-sombre, **aucune manquante** ; et après chaque
étape suivante, les gardes des deux branches (`test_corps_detail`, `test_corps_soi_sombre`) restent vertes.

## 2. Le risque de Beauté : la pré-passe porte le programme de la couleur, pour TOUTE variante (6431ad7)

**Ce qui était faux.** Sous `--corps-soi-sombre` seul, la couleur du corps passait à la variante CORPS_SOI_SOMBRE et la
pré-passe gardait `corps_iso_profondeur.gdshader` : la méta `MATERIAU_PROFONDEUR` n'était posée qu'au `_detailler` d'un corps
détaillé. Et dans la branche corps-sombre littérale, `accorder_corps` accordait la pré-passe DANS le bloc du détail, avant
CORPS_SOI_SOMBRE : avec les deux drapeaux, la pré-passe n'avait pas ce define. Deux programmes, le piège de l'ordre 424.

**Ce qui est fait, comme Beauté le décrivait :**
- `accorder_corps` pose toutes les variantes (CORPS_DETAIL, CORPS_DETAIL_MATIERE, CORPS_SOI_SOMBRE, et CORPS_SOI_FONDU de
  l'essai B), PUIS appelle `accorder_passe_profondeur` une seule fois, en dernier ;
- la méta est posée à la construction de TOUT corps (`voxel_corps.gd`, juste après la pré-passe) ;
- `accorder_passe_profondeur` : la pré-passe prend le programme de la couleur dès qu'il porte la sortie de pré-passe
  (`IsoMateriaux.porte_passe_unique`, un des defines de `VARIANTES_PASSE_UNIQUE`), et **revient** au shader ordinaire quand
  la couleur y revient ;
- la sortie de pré-passe : `iso_corps_detail.gdshaderinc` (inclus par `corps_iso` ET `corps_iso_eclaire`) définit
  `CORPS_PASSE_UNIQUE` et l'uniforme `passe_profondeur` sous `defined(CORPS_DETAIL) || defined(CORPS_SOI_SOMBRE)` ; les deux
  `fragment()` ouvrent et ferment la sortie sous `CORPS_PASSE_UNIQUE`. Le jumeau éclairé en avait besoin aussi : sous
  lumière 3D + soi sombre il reçoit le define, et sans sortie sa pré-passe aurait écrit de la couleur. Sans variante, rien
  n'est défini : le code compilé est celui d'avant, au bit.

**La garde** `tools/test_passe_unique.gd` (79 vérifications, dans `run_suites.sh`) : les 8 combinaisons détail × matière ×
soi sombre, sur `corps_iso` et `corps_iso_eclaire`, aller et retour de la lumière 3D, deux classes ; l'essai B ; la méta sur
tout corps ; le retour au shader ordinaire ; les textes. **Preuves par mutation**, sur le code réel, rétabli ensuite :

| mutation | échecs |
|---|---|
| l'ancien ordre d'appel (la pré-passe accordée sous le détail, avant soi sombre) | 26 |
| la méta posée au seul `_detailler` | 17 |
| la sortie de pré-passe sous CORPS_DETAIL seulement | 16 |

La garde embarque aussi un miroir des deux anciens codes (branche littérale, fusion 7493c82), qu'elle doit voir rouges.

**À l'image, sous llvmpipe (59d6b63)** — le banc de Beauté (`tools/banc_corps.gd`), son critère (ordre 426) : chaque prise
comparée à la même scène pré-passes cachées (`--sans-profondeur`, `--temps-fixe`) ; Q39 seul, Q39 + `--corps-detaille`
(`--fusion-ab` : fusionné ET boîtes), détail seul, et rien ; Parasite, Occulteur, Illusionniste, Fumiste ; 0,8 et 0,15 ;
silhouette de soi à 0,5 (celle du jeu). **48 jugements : 0 pixel noir anormal, 0 bloc 2×2, 0 pixel différent de la
référence** (`preuve_passe.json`).

- **Le témoin positif** (`--temoin-trou` : la couleur du torse cachée, sa pré-passe laissée — l'aspect exact du défaut) est
  vu : 11 221 et 11 295 pixels différents à 0,8 (le trou montre le sol éclairé : seulement 1 pixel « noir »), 7 060 et 420
  pixels noirs, 6 660 et 186 blocs 2×2 à 0,15. Les zéros veulent donc dire quelque chose — mais c'est la DIFFÉRENCE à la
  référence qui les porte : le seul compte des noirs n'aurait rien vu à 0,8.
- **L'état d'avant rend aussi 0** (`--passe-ancienne`, deux programmes exprès, 24 jugements). Voir « Ce que je n'ai pas
  prouvé ».

## 3. L'essai B, « fondu » (215d96f, 9738275)

Derrière `--corps-soi-sombre=fondu` (éteint ; il allume aussi A, sur lequel B se compose). Il ne change que la vue du joueur
lui-même : tout son code est sous `#ifdef CORPS_SOI_FONDU`, DANS le bloc `if (s > 0.0)` de l'essai A (la silhouette de soi,
nulle dans la vue d'en face). Aucun varying ajouté.

**Comment le shader décide « le corps se fond »** (`iso_corps_soi_sombre.gdshaderinc`, `soi_fondu_poids`) :
- **le sol autour du corps** : la lightmap de LA VUE QUI DESSINE (`lire_lightmap(px, deux)`, celle que lisent le sol et les
  murs iso), moyenne de huit points sur un cercle de 30 px du monde 2D autour de la position du joueur (`centre`) ;
- **le corps d'aujourd'hui, estimé pour le corps entier** (pas fragment par fragment, qui marbrerait le corps) : la fiche
  sous la lumière du capteur lue en quatre points au rayon lu, composée avec la silhouette de soi comme aujourd'hui ;
- **le contraste relatif** |corps − sol| / max : sous 0,3, l'essai A en entier ; au-dessus de 0,5, le corps d'aujourd'hui ;
  un fondu entre les deux. La couleur rendue est un mélange des deux couleurs déjà admises : jamais plus claire que la plus
  claire, rien hors du corps.

**Pourquoi c'est juste pour les deux joueurs.** Chaque vue lit SA lightmap, qui ne porte que les lumières que son joueur a
le droit de voir (règle d'équité d'ISO2) : chacun juge son propre corps sur son propre sol, avec la même règle et les mêmes
seuils. Le cercle est posé dans le monde 2D, pas à l'écran : le lacet (0°, 45°, le côté B de J2) ne change pas la décision.
B ne lit rien de l'autre joueur, du réseau ni de l'état du jeu, et ne touche ni la simulation ni le protocole.

**Un défaut trouvé en chemin, corrigé (9738275).** La première séance complète donnait B juste au Parasite, faux ailleurs
(Terrassier et Fumiste restaient à 20 % sous la fusée, à moitié assombris sous leur torche). Cause : `Presentation3D._activer`
ne pose `lumiere_1`/`lumiere_2` qu'une fois, sur les matériaux qui existent alors ; `_accorder_le_slug` reconstruit le corps
d'une autre classe et ne relayait que les capteurs. Le Parasite était la classe de l'allumage. Le relais est ajouté sans
condition, comme celui des capteurs : aucun shader des corps ne lit la lightmap par défaut (grep), donc aucun pixel ne change
sans le drapeau (grep ; suite complète verte ; les prises « aujourd'hui » des deux séances donnent les mêmes
chiffres, mais je ne les ai pas comparées au pixel : celles de la première séance ont été effacées avant).

**La garde** `tools/test_corps_soi_fondu.gd` (32 vérifications, dans `run_suites.sh`) : drapeau éteint, jamais B sans A,
tout sous `#ifdef`, dans la vue de soi, six varyings, lecture par la vue qui dessine (`centre, deux`), le cercle régulier, le
relais des lightmaps, la règle sur un miroir (poids 1 à contraste nul, 0 au-delà du seuil haut, décroissant ; 500 tirages
jamais hors de [aujourd'hui, A]), `Protocol.VERSION` 18. **Mutations** (code rétabli ensuite) : B sorti du bloc `s > 0` →
2 échecs ; B lisant la lightmap de l'autre vue → 1 ; relais retiré → 1 ; B posé sans son drapeau → 2.

## 4. Les chiffres

Cloître, la place du duel du photographe, 1920×1080, lacet 45° (J2 : 225°, côté B), zoom du duel ×1,5 ; mêmes scènes et
classes que le premier tour ; les trois états pris **au même instant** (jeu gelé, bascule en direct, la pré-passe suivant la
couleur comme au jeu). Luminance Rec. 709 des valeurs sRGB, 0..255. « Lisible » : pixel du corps qui diffère d'au moins
10/255 de ce qu'il cache. Quatre classes (Parasite, Terrassier, Fumiste, Spectre ; le Spectre n'a pas de fusée).

| lumière | sol autour | corps aujourd'hui / A / B | lisible aujourd'hui | lisible A | **lisible B** | B hors du corps |
|---|---|---|---|---|---|---|
| Dans le noir | 22 | 104 / 19–24 / 104 | 100 % | 93–94 % | **100 %** | 0 |
| Au bord de sa lumière | 24 | 133–134 / 53–54 / 133–134 | 100 % | 82–85 % | **100 %** | 0 |
| Sa pleine lumière | 23–24 | 132–133 / 44–49 / 132–133 | 100 % | 56–62 % | **100 %** | 0 |
| Au bord du cône adverse | 46–47 | 131–133 / 57–63 / 131–133 | 98–100 % | 46–53 % | **98–100 %** | 0 |
| Dans la torche adverse (ébloui) | 117–121 | 167–170 / 120–124 / 167–170 | 88–90 % | 44–50 % | **88–90 %** | 0 |
| Sous une fusée | 124–125 | 119 / 51–53 / 51–53 | 20–22 % | 99–100 % | **99–100 %** | 0–1 (allumés : 0) |

| écran scindé | J1 (bleu) aujourd'hui / A / B | lisible | J2 (rouge) aujourd'hui / A / B | lisible | l'adversaire dans chaque vue : changés par A / B |
|---|---|---|---|---|---|
| torches éteintes | 93–94 / 17–22 / 93–94 | 100 / 92–94 / **100 %** | 80 / 14 / 80 | 99 / 89–90 / **99 %** | 0 / **0** (J1 chez J2 : 542–649 px) |
| torches allumées, J2 braque J1 | 143–153 / 119–128 / 143–153 | 65–68 / 34–51 / **65–68 %** | 110–111 / 55–56 / 110–111 | 99–100 / 78 / **99–100 %** | 0 / **0** (1 773–2 043 px) |

**Lecture.**
- **B est l'image d'aujourd'hui, au pixel, dans toutes les scènes sauf la fusée** (0 pixel différent ; en écran scindé, 70
  et 82 pixels chez le Terrassier et le Spectre, égaux au bruit défaut/défaut recapturé — la tache non identifiée du premier
  tour). Il ne perd donc rien là où A perdait le plus (sa torche 56-62 %, le bord du cône adverse 46-53 %, ébloui 44-50 %).
- **Sous la fusée, B est A** : corps 51-53 cerné de son liseré (p90 ~86), lisible à 99-100 % contre 20-22 % aujourd'hui.
- **Le noir absolu** : hors du corps de soi, B n'allume aucun pixel ; 0 à 1 pixel changé par prise, collé au bord, plus
  sombre (l'arrondi de couverture du premier tour). En écran scindé, 0 pixel de noir rallumé hors des corps.
- **La vue de l'adversaire est identique au pixel**, avec A comme avec B.
- **Ce que B ne couvre pas** : l'ébloui en écran scindé reste à 65-68 % pour J1 (comme aujourd'hui). Le cercle de 30 px et
  les seuils 0,3 / 0,5 sont réglés sur ces six scènes (le Parasite, 0,2 / 0,4 d'abord : la fusée n'était assombrie qu'à
  moitié, 89 → 53 à 0,3 / 0,5) ; un sol éclairé par une LED ou une lampe de carte devrait se comporter comme la fusée, non
  photographié.

## 5. Pièges découverts, à reporter dans la feuille de route

1. ⚠️ **Un zéro de la preuve « triangles noirs » ne vaut que si le témoin est vu, et PAR LA MÊME MESURE.** À 0,8 sur le
   banc, une pièce manquante montre le SOL ÉCLAIRÉ, pas du noir : le compte des pixels noirs du critère de l'ordre 426 ne
   voyait qu'1 pixel du témoin ; la différence à la référence sans pré-passe en voyait 11 221. Le critère doit inclure la
   différence à `--sans-profondeur`.
2. ⚠️ **Un matériau neuf n'hérite que de ce qu'on lui relaie.** `Presentation3D._activer` pose les lightmaps sur les
   matériaux présents à l'allumage ; `_accorder_le_slug` reconstruit un corps à chaque changement de classe (et pour le
   fantôme de killcam) et ne relayait que les capteurs. Tout shader des corps qui lira un jour la lightmap est concerné ;
   corrigé ici, gardé par `test_corps_soi_fondu`. Une photo d'une seule classe, prise à l'allumage, ne le voit pas.
3. ⚠️ **Le masque du corps sur le banc** : l'image « sans corps » doit être la même scène (même cadrage : `--classe=X
   --opacite=0`), pas un banc vide (`--classe=aucune` recadre la caméra et tout le sol diffère).

## 6. Décisions prises seul, et pourquoi

- **La sortie de pré-passe dans `iso_corps_detail.gdshaderinc`**, sous `CORPS_PASSE_UNIQUE` : c'est le seul fichier inclus
  avant `fragment()` par les deux shaders des corps ; la mettre dans l'include de Q39 aurait laissé le jumeau éclairé sans
  sortie.
- **B décide pour le corps entier**, pas par fragment : un corps mi-clair mi-sombre selon la face serait plus illisible que
  l'un ou l'autre.
- **Le sol en moyenne sur un cercle**, pas au point sous le corps : la lightmap ne montre pas le corps (le halo du sprite
  n'est pas le sol) et le cercle rend la décision indépendante du lacet.
- **Le relais des lightmaps sans condition** : c'est le même geste que celui des capteurs, déjà là ; le conditionner au
  drapeau aurait laissé l'outil de prise (qui bascule en direct) et tout futur shader dans le même piège.
- **Rien dans `docs/ROADMAP.md` ni `docs/JOURNAL_SESSIONS.md`** (consigne) : les pièges ci-dessus sont à y reporter.

## 7. Défauts signalés (hors de ma tâche, non corrigés)

1. **Le mannequin ne voit pas la propre torche de son joueur** — signalé au premier tour (`presentation_3d.gd`, appel de
   `MannequinIso.direction_dominante` sans exclure le corps), toujours là.
2. **`volume_masque.gdshaderinc.uid` n'est pas suivi** : l'import le recrée dans chaque conteneur neuf. Effacé, pas committé
   (comme au premier tour).
3. **Une tache de 70-82 pixels vit encore, jeu gelé,** dans la vue de J2 en écran scindé torches allumées (Terrassier,
   Spectre) : présente au premier tour aussi, non identifiée.

## 8. Tout refaire

```bash
# Godot 4.7 (Linux) et Xvfb ; depuis la racine du dépôt :
godot --headless --path . --import
godot --headless --path . --script res://tools/test_passe_unique.gd       # la garde de la pré-passe
godot --headless --path . --script res://tools/test_corps_soi_fondu.gd    # la garde de l'essai B
GODOT=$(which godot) ./tools/run_suites.sh                                 # la suite complète
GODOT=$(which godot) ./docs/iso/cloud/corps-sombre-2/lancer_preuve.sh /tmp/preuve_passe   # la preuve de la pré-passe (~15 min)
#   + le témoin : banc_corps.tscn -- --temps-fixe --sans-matiere --silhouette=0.5 --classe=pistolet --lumiere=0.8 \
#     --temoin-trou --capture=/tmp/preuve_passe/temoinrien_pistolet_0.8.png   (référence : rien_pistolet_0.8_sp.png)
GODOT=$(which godot) ./docs/iso/cloud/corps-sombre-2/lancer.sh                   # aujourd'hui / A / B (~40 min)
python3 docs/iso/cloud/corps-sombre-2/planche.py                                  # la planche
# En jeu :
godot --path . -- --corps-soi-sombre            # essai A
godot --path . -- --corps-soi-sombre=fondu      # essai B
```

## 9. Ce que je n'ai PAS pu prouver

- **Que le correctif de pré-passe corrige un défaut VISIBLE sous Q39.** L'état d'avant (deux programmes) rend 0 pixel
  anormal sous llvmpipe, comme l'état corrigé. Lecture probable : le défaut de l'ordre 422 venait du SOMMET — la variante
  CORPS_DETAIL a son propre `vertex()` (la branche CUSTOM0), le shader de profondeur ordinaire non ; CORPS_SOI_SOMBRE ne
  change que le fragment, et le jeu par défaut tourne déjà avec deux programmes (corps_iso + corps_iso_profondeur) sans
  défaut. Le correctif reste juste (sans le même programme, rien ne garantit la même profondeur ; un pilote peut tomber faux
  demain) ; la preuve à l'image est « aucune régression », pas « défaut guéri ».
- **La cadence** : rien mesuré. B ajoute, dans la vue de soi seulement, 8 lectures de lightmap et 4 de capteur par fragment
  du corps (le compilateur ne sait pas qu'elles sont les mêmes pour tout le corps) ; la pré-passe sous Q39 est maintenant le
  programme complet (sortie tôt). À mesurer au Mac.
- **Le mouvement** : prises gelées. Un joueur qui passe d'un sol sombre à un sol éclairé fera basculer B en un fondu (seuils
  0,3-0,5) ; un sol à la frontière pourrait le faire battre. Non vu.
- **L'éblouissement réel, le Mac** : llvmpipe seulement.
- **Les sols éclairés hors fusée** (LED de carte, lampe posée), **le 0°**, **la killcam** (le fantôme porte la silhouette
  dans les vues qui voient sa couche : A et B s'y appliquent ; le relais couvre son matériau), **la lumière 3D** (le jumeau
  éclairé reçoit les defines et la sortie de pré-passe, mais ne porte pas les essais) : non photographiés.
