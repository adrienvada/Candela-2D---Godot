# Mesurer la cadence par version

> Règle décidée par Adrien le 2026-09-28 vers 06:35 : « Mesurons par version, plus par nouveauté. Trions avec le cloud
> avant le Mac. Faisons des séries plus courtes. » Écrite par la session cloud « cadence-version » le même jour, **avant**
> les outils qui la servent (`tools/cadence/tri_cloud.sh`, `tools/cadence/serie_version.sh`). C'est le texte qu'Iso 1
> porte dans la feuille de route.

## Pourquoi changer

Jusqu'ici, chaque nouveauté avait sa série sur le Mac : 1 h 20 à 1 h 45, jusqu'à cinq bras. Le Mac ne fait tourner qu'un
jeu à la fois ; il est devenu le goulot du chantier. Or la question qu'Adrien se pose en jouant n'est pas « combien coûte
chaque idée ? », c'est « **le jeu que je lance tient-il ?** ». Une série ne répond qu'à cette question-là, sur ce qui est
réellement joué. Le reste — qui coûte quoi — se trie avant, dans le cloud, où l'on peut **compter** sans chronomètre.

## 1. Ce qu'est une version

**Une version, c'est une tête intégrée, lancée sans aucun drapeau, avec ses réglages par défaut.** Ce que le joueur a
devant lui en ouvrant le jeu.

- Une nouveauté **éteinte derrière son drapeau n'en fait pas partie** : elle ne coûte rien tant qu'elle est éteinte (les
  gardes « drapeau éteint : rien ne change » de chaque essai le vérifient dans la suite). Elle entre dans une version le
  jour où son défaut change.
- Deux têtes qui ne diffèrent que par du code éteint, des outils ou des documents sont **la même version** pour la cadence.
- Pourquoi aucun drapeau : un drapeau perdu ne se voit pas, il se déguise en l'autre bras de la comparaison
  (`docs/iso/iso12/mesurer_une_cadence.md`, § 13). Une série par version passe **les mêmes arguments** aux deux bras ; ce qui
  les distingue, c'est l'arbre de travail, prouvé par son hash.

## 2. Quand on la mesure

**Quand ses défauts changent**, et seulement alors : une nouveauté allumée par défaut, un réglage par défaut qui bouge, un
shader ou une scène qui change pour tout le monde.

- **Pas pour un essai éteint.** Adrien juge un essai à l'image ; son prix se lit au tri du cloud (§ 4). Il se mesure au Mac
  le jour où il devient le défaut — dans la version qui l'allume.
- Plusieurs défauts qui changent ensemble se mesurent **ensemble**, en une série : c'est la version qui compte.
- Une version qui n'a rien changé de ses défauts depuis la dernière mesurée ne se remesure pas.

## 3. La référence

**La référence est la dernière version mesurée qui a tenu.** Pas `main`, pas l'état d'hier : la dernière tête dont une
série courte a rendu « tient ».

- Le jour où la règle entre en vigueur, la référence est `a30a407` (`integration-iso14`), l'état intégré du jour (masque de
  la fumée éteint, usure et 45° B au défaut). Elle n'a pas de série à son nom : ce n'est pas grave, car **chaque série
  courte remesure A à côté de B** — la référence est une tête, pas un chiffre recopié d'une autre séance.
- Une version qui tient **devient** la référence de la suivante. Une version qui échoue ne le devient pas.
- Pourquoi pas une référence fixe : les écarts se composent. Mesurer chaque version contre la précédente garde les écarts
  petits, donc lisibles, et dit laquelle a coûté.

## 4. Le tri du cloud, avant le Mac

Avant toute série, le cloud compare les deux têtes (`tools/cadence/tri_cloud.sh`) sur ce qu'il sait compter sans
chronomètre : appels de dessin, primitives, vues rendues, copies d'écran, lumières à ombre (l'outil de la session
« Budget », six cartes à 45° B et le pompe sous une fusée, vue unique et écran scindé) ; les programmes de shader que la
version ajoute (le GLSL que Godot donne au pilote : instructions, lectures de texture, boucles) ; la part de l'écran qui
change. Il classe chaque nouveauté **neutre**, **à surveiller** ou **lourde**, avec des seuils écrits dans l'outil et
justifiés par les mesures du Mac déjà faites.

Ce que le tri décide :

- **Tout est neutre** → la série courte en vue unique suffit ; si la version ne change que des nouveautés neutres **et**
  qu'aucune n'est un shader, elle peut attendre la version suivante pour être mesurée avec elle.
- **Une nouveauté à surveiller ou lourde** → la série courte, en vue unique ; **et en écran scindé aussi** si la lourde est
  une nouveauté de **géométrie** (appels ou primitives qui doublent avec les vues).
- Le classement est une présomption, pas un verdict. Le cloud ne voit pas le temps : **zéro appel n'est pas gratuit** (le
  masque de la fumée ne change aucun compte et coûtait 0,838). C'est pourquoi un shader qui ajoute une boucle ou des
  lectures de texture est « lourd » même à zéro appel.
- **Un coût derrière un uniforme ne se voit pas dans les programmes** (`--mannequin` n'en fait naître aucun). Quand une
  nouveauté allume un uniforme, on le **nomme** au tri (`PLIER=<nom>:<uniforme>`) : l'outil compile le programme uniforme
  à 0 puis à 1 et compte la branche. Seul le code dit quel uniforme un drapeau allume : c'est à l'auteur de la nouveauté de
  l'écrire dans son rapport.

Le tri sert aussi à Adrien **avant** de dire oui à un essai : s'il est neutre, l'allumer ne demande qu'une série de version ;
s'il est lourd, il sait d'avance qu'il faudra peut-être choisir.

## 5. La série courte

`tools/cadence/serie_version.sh <tête A> <tête B> <sortie>`, sur le Mac, en une fois, **30 minutes au plus** :

- **Deux bras seulement** : A (la référence) et B (la candidate), chacun dans son propre arbre de travail, **importé avant
  la série** (un import pendant la série pèserait sur les prises).
- **La scène de la règle 278** : le pompe sous une fusée, vue unique, au lacet par défaut. L'écran scindé seulement si le
  tri l'a demandé (§ 4).
- **Un ordre en miroir court** : une chauffe A non comptée, puis `A B B A A B` — trois prises par bras, soixante secondes de
  mesure chacune, 90 secondes sans aucun Godot avant chaque prise.
- **La porte de l'ordre 432**, gardée telle quelle dans le lanceur : Claude Helper admis sous 30 % et relevé à chaque prise ;
  tout processus étranger au-dessus de 20 % d'un cœur refuse la prise ; la porte ne juge que la fenêtre mesurée ; une
  prise refusée se refait à sa place ; les deux bras équilibrés à 2 points de charge de Claude Helper.
- **Un repos initial de 5 minutes**, et non 20 : ce qui protège la première prise, c'est la chauffe non comptée et le repos de
  90 s avant chaque prise (§ 6 du document de mesure : trois prises reposées tiennent, enchaînées elles s'effondrent) ; et
  l'état thermique du Mac est lu avant chaque prise (il doit être « normal »).
- **Chaque prise prouve la tête qu'elle mesure** : le hash de l'arbre, l'arbre propre (aucun fichier suivi modifié), et
  les lignes d'état que le jeu imprime (`[usure] …`, `[fumée masque] …`, `Rendu : …`), qui doivent être les mêmes à chaque
  prise d'un même bras.

**Pourquoi trois prises suffisent.** Dans les séries déjà faites à la règle 278, les médianes d'un même bras varient de 0 à
2 images par seconde d'une prise à l'autre (T 88 · 88 · 88 ; U0 89 · 89 · 89 ; U1 84 · 84 · 84 ; M0 88 · 86 · 87 ;
M1 82 · 82 · 82 ; 0° 88 · 88 · 87 ; 45° 84 · 86 · 84). La médiane de trois ne bouge donc que d'une image au plus, soit
1,2 % à 85 : sous les 3 % que la règle veut voir.

**Le verdict** (règle 278, inchangée) : la version **tient** si la médiane de ses trois médianes vaut **au moins 0,970**
de celle de A **et** si la médiane de ses trois 1 % bas (hors 10 s) est **au-dessus de 60**. La série n'a de verdict que si
les trois A tiennent entre eux dans 5 % et si les bras sont équilibrés.

**La prolongation, écrite d'avance** : si le rapport tombe **à une image près de la barre** — entre 0,958 et 0,982, soit
± 1 image à 85 —, le lanceur ajoute **UN** bloc `B A` (qui rééquilibre le miroir : positions moyennes 4,5 et 4,5), et rend
le verdict sur les quatre prises par bras. **Jamais davantage** : un second bloc, c'est chercher le résultat qu'on veut.

## 6. Si une version échoue : trouver la coupable

On ne revient **pas** à une série par nouveauté.

1. Le tri du cloud a déjà classé les nouveautés de la version. On retire **la plus lourde** (on éteint son défaut, dans une
   tête de travail qui ne diffère de B que par cela) : c'est B′.
2. **Une série courte A contre B′.** Si B′ tient, la coupable est trouvée : elle revient à Adrien avec son prix (B contre
   B′ se lit dans les deux séries).
3. Si B′ échoue encore, on retire la suivante dans l'ordre du tri, **sur B′** (B″), et une série courte de plus.
4. À la troisième série sans coupable, on s'arrête et on écrit ce qu'on sait : c'est l'empilement, pas une nouveauté, et
   la question revient à Adrien.

Pourquoi « la plus lourde d'abord » : c'est la plus probable, et une série courte (30 minutes) qui la confirme coûte moins
que cinq séries par nouveauté. Pourquoi retirer au lieu d'ajouter : B′ reste une version jouable, qui peut devenir la
référence si elle tient.

## 7. Ce qui ne change pas

- La barre de la **règle 278** : au moins **0,970** de la référence, **1 % bas médian au-dessus de 60**.
- Les leçons de l'instrument (`docs/iso/iso12/mesurer_une_cadence.md`) : chauffe de 30 s, porte sur la seule fenêtre
  mesurée et au maximum, repos de 90 s, prise refusée refaite à sa place, le verdict lit le dernier essai.
- **Le cloud ne mesure pas le temps.** Aucun chiffre d'images par seconde tiré du cloud ne s'écrit comme une mesure ; le
  tri compte, le Mac mesure.
