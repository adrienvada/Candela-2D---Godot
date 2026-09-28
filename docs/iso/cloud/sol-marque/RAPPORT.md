# Le sol marqué, à l'essai — rapport (en cours)

Session cloud, branche `claude/cloud-sol-marque`, partie d'`origin/claude/cloud-ecart-illustrations` (f4039a0), le
28/09/2026. Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». Tâche : le manque n° 5 de
`docs/iso/cloud/ecart-illustrations/RAPPORT.md` — un sol jonché et marqué.

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

**L'équité** : 132 marques sur les six cartes, 18 à 25 par carte. La table est écrite à la main pour une moitié de
chaque carte (`table.py`, le détail et les raisons de chaque place) ; le script en déduit les jumeaux et imprime la table
GDScript. Le jumeau d'une marque a la même graine : le même motif, retourné pour un miroir, tourné d'un demi-tour pour la
Croisée — l'image exacte au pixel du monde près. Cadres, bandes et lettres sont symétriques par construction (leur usure
est tirée sur un quart et reportée) : posés sur l'axe, ils sont leur propre jumeau. L'Usine n'a pas de symétrie exacte
(son bloc central est décalé d'une case) : traitée en miroir, comme les pochoirs, et **rien n'est posé près du bloc
décalé**.

## État

- [x] relevé
- [x] drapeau et table
- [x] garde headless (`tools/test_sol_marque.gd`, 27 vérifications)
- [ ] prises et mesures
- [ ] preuve de cuisson (éteint = base, au bit)
- [ ] comptes de dessin (outil « Budget »)
- [ ] planche
- [ ] suite complète
