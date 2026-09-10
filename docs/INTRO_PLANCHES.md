# L'intro en planches — storyboard et commande d'images

*Inscrit le 2026-09-09. Item **DA6.6**, voir `ROADMAP.md`.*

> ⚠️ **Le principe central de ce document — « l'intro ne se regarde pas, elle
> s'éclaire » — ne correspond plus au comportement livré.** Depuis le
> 2026-09-10 (décision d'Adrien, détail dans `ROADMAP.md`), les six planches
> sont des clips vidéo Veo 3.1 lus en `VideoStreamPlayer`, plus des images
> fixes révélées au curseur. Le storyboard, le texte gravé, la cadence et le
> raccord de sortie ci-dessous restent d'actualité ; la section « Le principe »
> qui suit décrit une mécanique abandonnée, gardée ici pour la raison du choix
> initial et parce que `intro_planches.gd` y retombe en repli si un fichier
> vidéo manque.

Six planches de bande dessinée, dans le style des illustrations de menu, qui
racontent l'arrivée d'un homme dans un lieu sombre. On ne sait pas pourquoi il
est là et **on ne le saura pas** : pas de camp, pas de commanditaire, pas de
récit expliqué. La seule chose que l'intro enseigne est la règle du jeu, et elle
l'enseigne en image.

## Le principe : l'intro ne se regarde pas, elle s'éclaire

Le jeu a déjà tout le vocabulaire, et il n'a jamais servi à raconter :

| brique existante | ce qu'elle apporte à l'intro |
|---|---|
| `menu_comic_panel.gd` | le cadre d'encre, les repères de massicot, l'ouverture au volet (*Comic Panel Reveal*) |
| `menu_artwork.gdshader` | le noir d'encre à 85 %, la percée des hautes lumières à 100 %, **et le halo de torche asservi au curseur** |
| `menu_particles_ambiance.gd` | les poussières de faisceau, les braises |

La conséquence est la seule idée de conception qui compte ici : **le curseur est
déjà la torche.** Chaque planche s'ouvre presque noire et ne se lit que là où le
joueur passe le faisceau. Elle s'enchaîne quand elle a été balayée, ou après son
délai si le joueur ne bouge pas.

Le joueur apprend donc le verbe du jeu — *éclairer pour voir* — avant le premier
match, sans une ligne de tutoriel. Et une intro qu'on **fait** n'a pas le même
statut qu'une intro qu'on subit : c'est ce qui la rend compatible avec
« immédiat, intuitif, addictif ».

## Les six planches

| # | Fichier | Planche | Percée lumineuse | POI (u,v) | `EffectMode` | Profil de particules |
|---|---|---|---|---|---|---|
| 1 | `ill_intro_descente` | **La descente** — un homme de dos, sac à l'épaule, descend un escalier de béton. Une ampoule nue au-dessus de lui, la dernière allumée. | ampoule vacillante, `AMBRE` faible | 0.38, 0.18 | `FLICKER_DUST` | `ATMOSPHERIC_DUST` |
| 2 | `ill_intro_seuil` | **Le seuil** — sa main pousse une porte lourde. Derrière : du noir absolu, plein cadre. Au-dessus, un panneau rouillé dont un seul mot se lit. | fente verticale de la porte | 0.55, 0.45 | `ABYSS_VORTEX` | `ABYSS_GOLD` |
| 3 | `ill_intro_dotation` | **La dotation** — une table de béton. Une torche, un pistolet. Rien d'autre. Sa main prend les deux. | lampe d'atelier rasante | 0.46, 0.62 | `BREATHING_HALO` | `WORKBENCH_AMBER` |
| 4 | `ill_intro_allumage` | **L'allumage** — le faisceau s'ouvre. Premier vrai percement de lumière de la séquence : il frappe le béton ébréché, les douilles, le sang séché. | le cône, net et tranché | 0.34, 0.50 | `VAULT_BEAMS` | `ATMOSPHERIC_DUST` |
| 5 | `ill_intro_prix` | **Le prix** — le cône révèle une silhouette au loin. Et le même cône projette **son ombre à lui**, immense, sur le mur derrière. | le cône, et rien d'autre | 0.74, 0.44 | `HEARTBEAT_FLARE` | `ATMOSPHERIC_DUST` |
| 6 | `ill_intro_extinction` | **L'extinction** — il éteint. Noir presque total. Ne survit qu'une braise. | la braise seule | 0.50, 0.52 | `DYING_EMBER` | `DYING_EMBERS` |

**Aucun mode d'effet neuf, aucun profil de particules neuf.** Les six planches se
câblent en douze lignes de dictionnaire dans `menu_artwork.gd` et six dans
`menu_particles_ambiance.gd`. C'est délibéré : un effet écrit pour six images
vues quinze secondes serait du code que personne ne rejuge jamais.

### La planche 5 est la seule qui compte

Les cinq autres installent ; celle-là **est** le jeu. Un seul cône y porte les
deux moitiés de la mécanique — il montre l'adversaire *et* il dessine l'ombre qui
désigne celui qui éclaire. C'est l'image à réussir en premier, et celle qu'on
garde si le reste tombe.

### Le raccord de sortie

La planche 6 se dissout dans `ill_accueil` : **même couloir, même panneau
*ARENA*.** L'illustration d'accueil cesse d'être un décor et devient la dernière
image de l'histoire — le menu commence exactement là où l'intro s'arrête. C'est
aussi pourquoi le POI de la planche 2 (0.55, 0.45) est voisin de celui
d'`ill_accueil` (0.62, 0.25) : c'est le même panneau, vu deux fois.

## Le texte

Quatre mots, gravés à l'encre dans la planche, **jamais en voix off, jamais en
bulle** :

> **VOIR SANS ÊTRE VU.** *(planche 5)*
> **TUER SANS ÊTRE TUÉ.** *(carton final, sur le noir de la planche 6)*

Le jeu n'a pas de dialogue et n'a pas de lore écrit ; une intro bavarde lui en
inventerait un. Quatre mots, c'est aussi quatre mots à traduire le jour où le
jeu sort ailleurs, pas quarante.

## Cadence et règles

- **6 planches × 2,5 s ≈ 15 s.** Le balayage à la torche peut raccourcir, jamais
  rallonger.
- **Passable à tout moment**, n'importe quelle touche. Une intro non passable
  contredit la thèse du jeu.
- **Jouée une fois** (drapeau dans `user://settings.cfg`), puis rejouable depuis
  le menu — elle ne doit pas s'imposer au deuxième lancement.
- **Chaque planche montre quelque chose que le moteur fait vraiment** : le cône,
  l'ombre portée, les douilles, le sang existent dans l'arène. Une intro qui
  promet un plan que le jeu ne rend pas, c'est le défaut « généré par défaut »
  transposé en récit — exactement ce que tout le chantier DA existe pour fermer.

## La commande d'images

Format **1024×640**, comme les quinze autres. Même procédé de génération que
DA1.5 et MV3, **et même langue de prompt** : deux images faites par deux procédés
différents jurent comme deux artistes différents (décision du 2026-08-24), et la
langue du prompt fait partie du procédé.

### Bloc invariant — à mettre en tête des six prompts, sans le modifier

> Illustration de roman graphique sombre, encrage noir franc au trait, hachures
> serrées, arêtes géométriques vives du béton brut. Cadre 1024×640, pleine page,
> sans bordure ni marge blanche. Clair-obscur radical : 80 à 85 % du cadre est
> plongé dans un noir d'encre profond, luminosité sous 10 %, pénombre
> claustrophobe absolue d'où émerge violemment **une seule** source de lumière
> nette et tranchée, à pleine luminosité. Palette limitée : noir d'encre, gris
> béton désaturés, ambre chaud (#F5B03D) pour toute flamme ou filament, blanc
> cassé chaud (#FAE8CC) pour le cœur du faisceau. Aucune couleur saturée, aucun
> vert, aucun néon froid, aucune teinte au-delà de 75 % de saturation. Décor :
> arène clandestine souterraine en béton ébréché, douilles au sol, sang séché
> des affrontements précédents. Personnage : homme seul, tenue noire sobre —
> sweat à capuche, pantalon sombre — sans armure, sans casque, sans électronique,
> équipé uniquement d'une lampe torche et d'un pistolet standard. Aucun texte
> ni logo hormis ce que la scène précise ci-dessous.

### Les six scènes

**1 — `ill_intro_descente`**
> Vue de trois quarts arrière. Un homme descend un escalier de béton droit et
> étroit, sac de sport à l'épaule, main libre sur la rampe métallique. Il est vu
> de dos : on ne verra pas son visage. Au-dessus de lui, une ampoule nue au bout
> d'un fil, la seule allumée de la cage d'escalier — les autres douilles de
> plafond sont vides ou brisées. Sa lumière est faible, jaune, vacillante ; elle
> découpe ses épaules et laisse le bas des marches dans le noir total. Poussière
> en suspension dans le cône de l'ampoule. Peinture écaillée sur les murs,
> traces d'humidité. On ne sait pas d'où il vient.

**2 — `ill_intro_seuil`**
> Plan rapproché sur une porte industrielle lourde en acier, vue de face,
> entrouverte de quelques centimètres. Une main gantée la pousse par la tranche.
> Par la fente s'échappe une lumière ambre rasante, unique percée du cadre :
> derrière la porte, le noir est absolu et occupe presque toute l'image. Au-dessus
> du linteau, un panneau indicateur rouillé et cabossé sur lequel un seul mot
> reste lisible, en capitales : **ARENA**. Les autres inscriptions du panneau sont
> effacées, criblées ou noyées dans l'ombre. Rivets, rouille, béton ébréché
> autour de l'encadrement.

**3 — `ill_intro_dotation`**
> Plan serré en légère plongée sur une table de béton brut. Posés dessus,
> exactement deux objets et rien d'autre : une lampe torche cylindrique en métal
> usé, éteinte, et un pistolet semi-automatique standard, sans accessoire. Une
> main entre dans le cadre par la droite et se referme sur la torche. Éclairage
> unique : une lampe d'atelier hors champ, rasante, qui allume la tranche des
> deux objets et la texture granuleuse du béton, et laisse le fond dans le noir
> complet. Quelques douilles vides roulées contre le bord de la table. Aucun
> autre équipement visible : c'est toute la dotation.

**4 — `ill_intro_allumage`**
> L'homme, debout de profil, vient d'allumer sa torche. Le faisceau s'ouvre vers
> la droite du cadre en un cône net, aux bords tranchés, à pleine luminosité —
> c'est le premier vrai percement de lumière de la séquence, et il est violent.
> Le cône frappe un mur de béton ébréché et le sol : il révèle des douilles
> éparses, une large tache de sang séché, brun, ancienne, et les impacts de
> balles dans le béton. Le reste du cadre, y compris la majeure partie du corps
> de l'homme, reste dans le noir d'encre. Poussière dense visible dans le
> faisceau. Contraste maximal entre le cône et l'obscurité.

**5 — `ill_intro_prix`**
> Plan large. L'homme, torche allumée, de dos au premier plan à gauche. Son
> faisceau traverse toute la largeur du cadre et révèle, au loin, une deuxième
> silhouette debout dans le cône — nette, immobile, tenue noire identique, encore
> anonyme. Et la même torche projette derrière lui, sur le mur de gauche, **son
> ombre à lui**, démesurée et parfaitement lisible. Les deux informations
> coexistent dans une seule image : ce que le faisceau montre, et ce qu'il
> trahit. Aucune autre source de lumière. Béton, poussière, douilles au sol.

**6 — `ill_intro_extinction`**
> Cadre presque entièrement noir, à 95 %. La torche vient d'être éteinte : il ne
> reste que la rémanence orange mourante du filament, un point de braise unique,
> légèrement décentré, qui éclaire à peine le contour d'une main et une arête de
> béton. Fumée ténue. Aucune autre forme identifiable. Le noir doit être un noir
> d'encre plein, pas un gris sombre : l'image se lit comme la fin d'une planche
> de bande dessinée, sur laquelle un titre pourra être posé.

## Ce que l'intro ferme, et ce qu'elle nourrit

- **Elle ferme DA6.5** (« la séquence power-on — logo, souffle, lumière ») : la
  planche 4 *est* l'allumage, et la planche 6 pose le wordmark.
- **Elle alimente quatre fiches de DA7 sans commande supplémentaire.** Les
  planches 4 et 5 sont la capsule de boutique (DA7.1), l'ouverture du trailer
  (DA7.2), l'en-tête du site d'une page (DA7.4) et les images d'ambiance du
  presskit (DA7.3). **Une commande, quatre usages** — c'est l'argument principal
  pour faire l'intro avant le reste de DA7, et non après.

## Ce qui reste à trancher par Adrien

1. **La formule.** « Voir, tuer, sans être vu, ni tuer » se lit dans deux sens.
   Le chiasme fermé proposé ici est *VOIR SANS ÊTRE VU. TUER SANS ÊTRE TUÉ.*
2. **Le visage.** Le storyboard ne le montre jamais (planches 1, 2, 3, 5 de dos
   ou hors champ) alors qu'`ill_accueil` le montre. À décider : anonymat tenu
   jusqu'au bout, ou raccord de personnage avec l'accueil.
3. **Le son.** L'intro est muette dans ce document. Le stem de menu à 170 BPM
   existe ; un rythme de planche calé dessus (une planche toutes les 4 mesures =
   1,41 s) serait une autre cadence que les 2,5 s proposées.
