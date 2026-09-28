# Le sol marqué, à l'essai — rapport

Session cloud, branche `claude/cloud-sol-marque`, partie d'`origin/claude/cloud-ecart-illustrations` (f4039a0), le
28/09/2026. Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». Tâche : le manque n° 5 de
`docs/iso/cloud/ecart-illustrations/RAPPORT.md` — un sol jonché et marqué.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` : pour chaque sorte de marque, le dessin, le jeu sans, le jeu avec, et une loupe.
2. L'essai pose au sol des gravats, des débris, des chaînes, des bandes peintes et quelques lettres, tous sombres, sur les
   six cartes. Il est éteint : sans le drapeau `--sol-marque-essai`, le jeu est identique au bit près.
3. Rien ne s'allume dans le noir, rien n'est plus clair que le sol, et ça ne coûte rien à l'image (tout est peint une fois
   par carte, avec les pochoirs).
4. Une leçon d'équité en chemin : à 45°, ton adversaire voit la carte à l'envers, donc chaque marque doit avoir son double
   « retourné », pas seulement son double « en miroir ». Les pochoirs actuels ne l'ont pas tous.
5. À toi de juger à l'œil, sur ton écran : est-ce que ça habille le sol sans gêner la lecture d'un adversaire ? Mesuré ici,
   un corps au bord de la lumière perd 2 à 3 % de contraste sur sol marqué.

## 1. Le relevé, illustration par illustration (écrit avant le code)

Relevé à l'œil sur les vingt illustrations (`docs/iso/cloud/ecart-illustrations/img/ill_*.jpg`, 1024×640), en regardant
le SOL seulement. Tailles rapportées à une dalle du dessin (≈ une case du jeu, 35 px du monde).

| illustration | gravats (tas, pied des murs) | éclats épars | chaînes | bandes / cadres | lettres | écarté |
|---|---|---|---|---|---|---|
| accueil | fins, au pied du poteau et du mur droit | quelques-uns | — | — | — (ARENA est une enseigne) | ~20 douilles, sang |
| amical | **tas dense en arc au pied du pilier** (≈ 1 dalle de long, éclats de 1/10 à 1/5 de dalle) | nombreux dans la salle | — | — | « ZONE 4 » BLANC sur le pilier (mur) | douilles, sang, marquage clair |
| créer local (= rejoindre local, même fichier) | petit tas au pied du pilier | quelques-uns | **deux** : un anneau lâche (gauche), une longue (droite), maillons ≈ 1/6 de dalle | **cadres de bandes** autour des mots, bande ≈ 1/10 de dalle | « ZONE 4 », « DEATHMATCH », « ⊗ X ⊗ », dans les cadres | douilles ; bandes et lettres BLANCHES |
| compétitif | — | papiers, quelques débris | — | — | — | douilles en nappe, taches |
| intro allumage | au pied du mur éclairé | épars dans le rond de lumière | — | — | — | douilles, sang |
| intro prix | blocs plus gros au pied du mur (dalles cassées) | **partout dans le couloir** | — | — | — | douilles, sang |
| intro seuil | au seuil | quelques-uns | — | — | — | douilles, sang |
| écran scindé | petit tas au pied du mur droit | rares | — | — | — | douilles, sang |
| quitter | rares, pied du mur droit | — | — | — | — | douilles, sang, la lampe |
| mise à jour | au pied de la porte | quelques-uns | **deux**, symétriques de part et d'autre de la porte | — | « VAULT 07 » (sur la porte) | douilles |
| retour | — (dalles fissurées) | — | — | — | — | reflet d'eau |
| entraînement, créer ligne, rejoindre ligne | — | — | — | — | — | tapis ou sol de douilles |
| amical ligne | — | — | — | — | — | traînée de sang |
| amical local, intro descente, intro dotation | pas de sol lisible (menus, escalier, gros plan) | | | | | |

**Ce qui revient** : les gravats au pied des verticales (7 illustrations), les éclats épars (8), les chaînes (2
illustrations, 4 chaînes), les cadres de bandes et les lettres (1 illustration — mais c'est celle du jeu local, deux
écrans). Les fissures des dalles sont déjà au défaut (usure, Q30 = A). **La densité** : un tas par pied de pilier ou de
mur éclairé, une poignée d'éclats par salle, une ou deux chaînes par scène, un cadre par mot peint.

**Écarté d'emblée, et pourquoi :**
- **Les douilles de décor** (12 illustrations sur 13). Dans le jeu une douille est une information : « on a tiré ici,
  il y a peu ». En semer d'avance mentirait au joueur ; et la peinture de la carte peint déjà les vraies douilles une
  fois immobiles (`peinture_iso.gd`).
- **Le sang** : même raison (une touche), et le rouge est réservé.
- **Tout marquage CLAIR** (le « ZONE 4 » blanc, les bandes blanches de « créer local ») : un blanc serait plus clair que
  le sol qui le porte, donc visible dans une pénombre où le sol ne l'est pas — la règle des pochoirs le peint sombre.
- **Les symboles « ⊗ X ⊗ » et les flèches** : un symbole au sol se lit comme une consigne (une cible, un chemin).
- **La forme claire des gravats** : dans les dessins, un gravat est un éclat CLAIR avec son ombre. On n'en garde que
  l'ombre (noir translucide) : plus clair que le sol, il serait un point lumineux dans le noir.

## 2. L'essai `--sol-marque-essai` (éteint par défaut)

Dans `arena_decor.gd`, à côté des pochoirs, cuit dans la même texture du décor (rien de plus par image). Six familles :

| famille | forme | peinture | posée |
|---|---|---|---|
| gravats | 6 éclats par case de long (polygones de 3 à 5 sommets, 0,9 à 3,2 px de rayon, plus gros au cœur) + autant de grains d'1 px, dans une bande de ±5 px | noir 38 à 60 % | le long d'un mur ou d'un pilier, à une demi-case de lui |
| éclats | 6 à 9 éclats sur un disque d'une case | noir 32 à 50 % | dans les salles |
| chaîne | un maillon à plat (anneau 6,4 × 3,6 px), un de chant (trait de 5 px), tous les 4,2 px, en arc lâche | noir 60 % | au sol libre, une ou deux par moitié de carte |
| cadre | quatre bandes de 3,5 px, usées | noir 30 % | autour des deux « DEATHMATCH » des pochoirs |
| bande | une bande de 3,5 px, usée | noir 30 % | sur l'axe de la carte |
| lettres | « 07 », « B-07 », « C3 », fonte des pochoirs à 14 px | noir 40 % | près d'un mur |

**Pourquoi à une demi-case des murs et pas contre eux** : la face d'un mur iso lit sa lumière dans la lightmap 12 px
devant elle, en la divisant par la peinture de la carte (`mur_iso.gdshader`, `lire_lumiere`, et `peinture_iso.gd`). Une
marque dans ces 12 px entrerait dans ce calcul ; au-delà, la face ne la voit pas. D'où des tas « au pied » à ~13 px.

**Pourquoi ces lettres** : ni « ZONE », ni « ARENA », ni « DEATHMATCH » (ce sont les pochoirs), ni « 1 » ou « 2 »
(les départs), ni flèche. Des codes de secteur sans sens de jeu, qui font écho au « VAULT 07 » des menus.

**L'équité** : 232 marques sur les six cartes, 22 à 48 par carte. La table est écrite à la main pour une moitié (un
quart, en pratique) de chaque carte (`table.py`, la place de chaque marque) ; le script en déduit les jumeaux et imprime la
table GDScript. Le jumeau d'une marque a la même graine : le même motif, retourné pour un miroir, tourné pour un
demi-tour — l'image exacte au pixel du monde près.

⚠️ **Le jumeau par la symétrie de la carte ne suffit pas à 45° B** — découvert à la première séance, corrigé dans
`640ea0b`. J2 regarde depuis le côté opposé (lacet + 180°) : ce que J1 voit au point p, J2 le voit au **demi-tour** de p,
pas à son miroir. La première table (132 marques, fermée par le miroir gauche-droite seul) posait un tas au pied SUD du
pilier nord-ouest et son jumeau au pied SUD du pilier nord-est : visible pour J1, caché derrière son pilier pour J2. Mesuré
à l'écran scindé, J1 et J2 chacun devant « son » tas : **713 pixels assombris dans le cône de J1, 27 dans celui de J2**. Les
cinq cartes en miroir ont AUSSI la symétrie haut-bas (l'Usine à une case près) : la table est désormais fermée par les deux
miroirs et le demi-tour, et la garde headless l'exige (et rougit sur la première table). **À reporter dans la feuille de
route, au-delà de cet essai** : tout décor posé « avec son jumeau par la symétrie de la carte » doit aussi avoir son jumeau
par le demi-tour pour être équitable à 45° B. Les pochoirs ne l'ont pas (« ZONE 1 » et « ZONE 2 » sont tous deux au sud sur les cinq cartes en miroir — la Croisée,
en demi-tour, est juste ; les « DEATHMATCH » de l'Arène Standard et de l'Arène Circulaire ne sont pas à des places échangées par le miroir
haut-bas) : signalé, pas corrigé. Les cadres de cet essai, qui encadrent ces « DEATHMATCH », en héritent.

Cadres, bandes et lettres sont symétriques par construction (leur usure
est tirée sur un quart et reportée) : posés sur l'axe, ils sont leur propre jumeau. L'Usine n'a pas de symétrie exacte
(son bloc central est décalé d'une case) : traitée en miroir, comme les pochoirs, et **rien n'est posé près du bloc
décalé**.

## 3. Les preuves

Mesures : `mesurer.py` → `mesures.json`, sur les prises de `tools/photo_sol_marque.gd`. Le Cloître, 1920×1080, lacet 45° B,
zoom du duel. **Chaque prise est triple, au même instant, jeu en pause** : A (les marques), B (retirées, décor recuit), A'
(remises). A − B est l'essai et lui seul ; A − A' le bruit — **nul, 0 pixel, dans toutes les scènes**. Deux séances : l'essai
seul, et tous les essais de la nuit allumés (`--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai
--corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang`) ; les chiffres ci-dessous sont ceux de l'essai
seul, ceux de « tous » sont à quelques pixels près (`mesures.json`).

| preuve | résultat |
|---|---|
| **éteint : rien ne change au bit** | les textures cuites du décor, les six cartes : md5 **identiques** à la base f4039a0 drapeau éteint, **toutes différentes** drapeau allumé (`cuisson_md5.txt`, `cuisson.gd`). C'est la seule texture que l'essai touche (le reste du diff : une table, des fonctions appelées seulement quand la table est posée, un test) |
| **le noir absolu** | torches éteintes (scène `noir`) : sur 1 046 120 pixels noirs sans marques, **0** s'allume avec (A), **0** en A'. Et dans les huit scènes, 0 pixel noir allumé |
| **jamais plus clair que le sol** | aucun pixel plus clair de **2/255 ou plus**, dans aucune scène. Des pixels plus clairs d'**1/255 sur un canal** : 6 à 29 par scène (sur 7 000 à 14 000 changés), au bord des marques, en pleine lumière — la division lightmap ÷ peinture du sol éclairé (`sol_iso_eclaire.gdshader`), à l'arrondi près. 0 dans le noir. Dans la texture cuite elle-même : **0 texel éclairci** (`emprises.py`) |
| **les emprises** | chaque texel touché par l'essai tombe dans l'emprise que promet la garde headless (0 hors, sur les six cartes : `emprises.py`) |
| **la symétrie J1/J2 à 45° B** | écran scindé, J1 devant un tas de gravats, J2 au demi-tour de J1 : **4 746 pixels assombris dans la vue de J1, 4 677 dans celle de J2** (somme de l'assombrissement 30 805 / 29 743, −3,4 %) ; dans le cône de chacun, 299 / 292. Avant la correction du demi-tour : 713 / 27 |
| **les comptes de dessin** | outil de la session « Budget » (`tools/cloud_budget/`, repris tel quel), six cartes, lacet 45°, vue unique et écran scindé, deux lancements par configuration : contre le témoin, **+0 appel, +0 primitive** (médiane des six cartes), pire carte ±2 appels, ±8 primitives — l'écart entre deux lancements identiques. Mêmes vues rendues, copies d'écran, lumières à ombre (`budget.md`) |
| **la lisibilité d'un corps adverse** | J2, torche éteinte, debout sur des marques dans le cône de J1. À 4 cases : corps 15,1 contre sol 37,0 (Δ −21,9) sur sol nu ; 14,7 contre 36,2 (Δ −21,5) sur sol marqué. À 7 cases : Δ −18,0 nu, −17,4 marqué. **Le contraste baisse de 2 % (4 cases) et 3 % (7 cases)** : le sol s'assombrit un peu, le corps aussi (son ombre porte sur les marques) |

**Un piège de l'instrument, au passage** : le TOUT PREMIER lancement de la série (`defaut`) comptait +6 appels et +100
primitives de plus que tous les suivants, et 30 Mo de mémoire vidéo de plus — un effet de premier lancement (caches à
froid dans un `user://` neuf). Pris seul, il faisait paraître le sol marqué **moins** cher que le défaut. La référence est
donc le témoin `defaut2`, lancé après. À retenir pour toute matrice : jeter le premier lancement, ou le refaire à la fin.

**Assombrissement moyen** des pixels touchés, en luminance 0..255 : gravats 6,0 ; éclats 11,2 ; chaîne 7,9 ; cadre 9,8 ;
bande 5,6 ; lettres 9,3. **À la taille du jeu, ça se voit peu** (comme les pochoirs) : la chaîne et les cadres se lisent
à 1:1, les gravats et les éclats il faut la loupe. C'est le prix de la règle « jamais plus clair que le sol ».

**Le contraste, lu avec prudence.** Le « corps » est ce que J2 change à l'image (J2 présent − J2 absent, marques retirées) :
son corps ET l'ombre qu'il porte dans le cône de J1 — le masque fait 12 800 pixels à 4 cases, surtout de l'ombre. Le chiffre
dit donc « la silhouette de J2, ombre comprise, se détache 2 à 3 % moins d'un sol marqué » ; il ne dit rien de l'œil
(llvmpipe, et un seul placement). C'est la question à trancher sur le Mac.

## 4. Pièges et défauts découverts, à reporter dans la feuille de route

1. **À 45° B, l'équité d'un décor demande le jumeau par le DEMI-TOUR, pas seulement par la symétrie de la carte.** J2
   regarde depuis le côté opposé : ce que J1 voit en p, J2 le voit au demi-tour de p. Sur une carte en miroir, le jumeau
   par le miroir d'un objet posé contre une face « visible » de J1 est contre une face cachée pour J2 (mesuré : 713 pixels
   contre 27). Vaut pour tout décor à venir (gravats, meubles, enseignes au sol).
2. **Les pochoirs de l'essai ISO13 ne sont pas fermés par le demi-tour** : sur les cinq cartes en miroir, « ZONE 1 » et
   « ZONE 2 » sont tous deux dans la moitié sud ; les « DEATHMATCH » de l'Arène Standard (y = 6 et 26, H = 32) et de
   l'Arène Circulaire (4,5 et 19,5, H = 24) ne s'échangent pas par le miroir haut-bas. La Croisée est juste. Reproduire :
   `ArenaDecor.POCHOIRS_ESSAI` contre la règle de `tools/test_sol_marque.gd` (`_orphelins(…, "demi_tour")`). Signalé, pas
   corrigé.
3. **La peinture iso n'est pas ravivée pendant une pause** : `PeintureIso._process` reprend la texture recuite du décor,
   mais il est arrêté par la pause. Un banc qui recuit le décor jeu en pause (`poser_pochoirs`, `poser_marques`) doit
   l'appeler lui-même (`tools/photo_sol_marque.gd`, `_marques`).
4. **Au bord d'une marque sombre, le sol éclairé iso peut sortir plus clair d'1/255 sur un canal** (6 à 29 pixels par
   scène) : la division lightmap ÷ peinture de `sol_iso_eclaire.gdshader`, à l'arrondi. Pas au-delà d'1/255 ; jamais dans
   le noir. Vaut sans doute aussi pour les pochoirs, le sang, les douilles (non mesuré).
5. **Le premier lancement d'une matrice de l'outil « Budget » compte plus que les suivants** (+6 appels, +100 primitives,
   +30 Mo, ici) : un `user://` neuf. Le jeter, ou le refaire à la fin (`budget.md`, lignes `defaut` et `defaut2`).
6. **`tools/photo_ecart.gd.uid` manquait** à la base (engendré par l'import) : ajouté ici.

## 5. Pour tout refaire

```bash
git fetch origin claude/cloud-sol-marque && git checkout claude/cloud-sol-marque
godot --headless --path . --import                                  # la première fois
pip install pillow numpy
# La garde headless, et la suite complète :
godot --headless --path . --script res://tools/test_sol_marque.gd
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
# Les deux séances de prise (~15 min chacune sous llvmpipe), les mesures, la planche :
XDG_DATA_HOME=$PWD/.xdg GODOT=/usr/local/bin/godot ./docs/iso/cloud/sol-marque/lancer.sh
#   (mesures seules : SOL_SOURCE="<user://sol-marque>" python3 docs/iso/cloud/sol-marque/mesurer.py ; puis planche.py)
# La preuve au bit : la texture cuite, drapeau éteint, ici et sur la base (un worktree de f4039a0 où l'on copie cuisson.gd) :
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --script res://docs/iso/cloud/sol-marque/cuisson.gd -- --sortie=/tmp/c/branche
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --script res://docs/iso/cloud/sol-marque/cuisson.gd -- --sol-marque-essai --sortie=/tmp/c/essai
python3 docs/iso/cloud/sol-marque/emprises.py /tmp/c/branche /tmp/c/essai
# Les comptes de dessin (outil de la session Budget) :
LACETS=45 SCENES=cartes GODOT=/usr/local/bin/godot ./tools/cloud_budget/run_budget.sh /tmp/budget \
    'defaut=' 'solmarque=--sol-marque-essai' 'defaut2=' 'solmarque2=--sol-marque-essai'
python3 tools/cloud_budget/synthese.py /tmp/budget --reference=defaut2
# Réécrire la table après avoir changé une place à la main (la demi-table est dans table.py) :
python3 docs/iso/cloud/sol-marque/table.py <vidange ASCII des cartes>   # imprime SOL_MARQUE_ESSAI
```

Sur le Mac : `ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/sol-marque/lancer.sh`, la
fenêtre au premier plan.

## 6. Ce que je n'ai PAS pu prouver

- **L'œil.** Que le sol marqué « habille sans gêner » est un jugement sur un vrai écran ; le cloud rend en llvmpipe (couleurs
  à ~1/255 du Mac), sans éblouissement ni geste des corps.
- **La lisibilité en général** : un seul placement de J2 (deux distances, sur éclats et gravats, torche éteinte), et un
  masque « corps » qui comprend son ombre. Ni en mouvement, ni sous la torche de J2, ni sur une chaîne ou un cadre.
- **Aucune cadence.** Rien ici n'en est une ; l'essai n'ajoute aucun appel par image, mais la texture cuite est la même
  taille : le coût, s'il existe, est nul par construction — à confirmer au banc sur le Mac si besoin.
- **Le 0° n'est pas photographié** : l'équité à 0° découle de la table (fermée par les symétries de la carte, vérifiée par la
  garde) et de la texture cuite ; les prises sont toutes à 45° B.
- **Les cinq autres cartes ne sont pas photographiées en jeu** : seulement leur texture cuite (vues de dessus `img/carte_*`)
  et la garde headless. Les scènes sont toutes sur le Cloître.
- **L'Usine** n'a pas de symétrie exacte : sa table suit le miroir, loin du bloc décalé ; l'équité y est celle de la carte.

## État

- [x] relevé
- [x] drapeau et table
- [x] garde headless (`tools/test_sol_marque.gd`, 27 vérifications)
- [x] prises et mesures
- [x] preuve de cuisson (éteint = base, au bit : `cuisson_md5.txt`) et emprises tenues (`emprises.py` : 0 texel hors)
- [x] comptes de dessin (outil « Budget ») : +0 appel, +0 primitive
- [x] planche (`planche.html`)
- [x] suite complète : « tout passe, sans erreur de script (641 s) », EXIT 0
