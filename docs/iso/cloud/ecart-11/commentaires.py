"""L'écart aux illustrations, évaluation 11 — ce que cette évaluation dit de chaque illustration (lu par `planche.py`).

Les chiffres cités viennent de `mesures.json` (lancements du 28/09/2026, cloud). « 1 % clair » : le seuil de luminance du
1 % le plus clair de l'image, 0..255 ; « couleur » : la distance RGB entre la couleur moyenne de ce 1 % dans le jeu et dans
l'illustration.
"""

CINQ_LIGNES = [
    "La lampe est devenue crème : la lumière du jeu a enfin la couleur de celle des dessins (sur « Amical », l'écart de "
    "couleur tombe de 99 à 13).",
    "Ton propre personnage est devenu sombre, comme dans les dessins (luminance 136 → 38, les dessins sont à 40-60), avec "
    "un liseré clair du côté de la lumière.",
    "Les murs meublés et le sol marqué se voient à peine à la taille du jeu : il faut la loupe.",
    "Le noir reste noir, sauf une petite fuite trouvée : sur la Croisée et le Bunker, le sol marqué fait briller quelques "
    "pixels de l'arête d'un mur (au plus 51/255), à corriger avant de l'allumer.",
    "Ce qui reste loin ne se comblera pas par un essai : les dessins montrent une pénombre partout et un plan à hauteur "
    "d'homme ; le jeu, vu de haut, ne montre que ce que la lumière touche — c'est la règle du jeu.",
]

EN_TETE = [
    {"titre": "La lampe crème et le corps sombre — « Amical »",
     "gauche": "img/loupe_defaut_zone.jpg", "legende_gauche": "le jeu par défaut (loupe ×2)",
     "droite": "img/loupe_tout_zone.jpg", "legende_droite": "« tout » (même cadre, même instant)",
     "texte": "À comparer à <a href=\"img/ill_amical.jpg\">l'illustration</a> : la lumière passe d'un ocre (172, 144, 99) à "
              "un crème (231, 207, 168) — celle du dessin est (224, 197, 164). Le 1 % le plus clair monte de 126 à 188 "
              "(dessin : 185). Le personnage n'est plus bleu glacier : il est ardoise, cerné."},
    {"titre": "Le contre-jour — « Le prix »",
     "gauche": "img/loupe_defaut_duel.jpg", "legende_gauche": "le jeu par défaut",
     "droite": "img/loupe_tout_duel.jpg", "legende_droite": "« tout »",
     "texte": "<a href=\"img/ill_intro_prix.jpg\">L'illustration</a> montre un joueur sombre devant sa lumière. Ton corps "
              "passe de (114, 140, 157) à (32, 39, 45) : le même rapport de valeurs que le dessin. L'adversaire, dans "
              "ton cône, est inchangé (l'essai ne touche que ce que tu vois de toi)."},
    {"titre": "L'écran scindé",
     "gauche": "img/jeu_defaut_scinde.jpg", "legende_gauche": "le jeu par défaut",
     "droite": "img/jeu_tout_scinde.jpg", "legende_droite": "« tout »",
     "texte": "<a href=\"img/ill_ecran_scinde.jpg\">Le diptyque</a> : l'écart de couleur de la lumière tombe de 116 à 35, "
              "son 1 % clair de 122 à 190 (dessin : 201). Le reste de l'image — la pénombre lisible, les poutres — ne "
              "bouge pas, et ne doit pas bouger."},
    {"titre": "Ce qui ne se rapproche pas — « L'accueil »",
     "gauche": "img/ill_accueil.jpg", "legende_gauche": "l'illustration",
     "droite": "img/jeu_tout_arena.jpg", "legende_droite": "« tout », plein cadre",
     "texte": "La lumière est juste (écart de couleur 76 → 50), mais la médiane de l'image reste à 0 contre 16 au dessin : "
              "hors du cône, le jeu est noir, le dessin est gris. C'est pourquoi la distance globale entre les deux "
              "images ne bouge pas (25,5 → 25,5) : tout ce que les essais changent tient dans le cône."},
]

AUTRES_CARTES = ("La Croisée et le Bunker, même mise en scène que le duel du Cloître (J1 à 3,5 cases au sud d'un mur haut "
                 "intérieur, J2 dans son cône), puis torches éteintes. La lampe crème et le corps sombre s'y lisent de "
                 "la même façon (corps : 38 de luminance sur les trois cartes). Le sol marqué a des marques sur ces deux "
                 "cartes ; c'est là, torches éteintes, qu'il allume quelques pixels d'arête (voir « Le noir »). Les "
                 "enseignes et les tuyaux d'hier, eux, n'existent qu'au Cloître.")

COMMENTAIRES = {
    "ill_accueil": "Plus proche : la couleur de la lumière (écart 76 → 50) et son éclat (1 % clair 123 → 182, dessin 170). "
                   "Le personnage est sombre comme celui du dessin. Reste loin : la pénombre partout, le panneau sur "
                   "poteau, les douilles (contredites).",
    "ill_amical": "La meilleure paire de l'évaluation : la couleur de la lumière est presque celle du dessin (écart 13) et "
                  "son éclat aussi (188 contre 185). Reste loin : le « ZONE 4 » blanc (le jeu le peint sombre, à raison), "
                  "les deux cônes dans l'air, la pénombre.",
    "ill_amical_ligne": "La lumière blanchit (écart de couleur 147 → 38) mais reste moins éclatante que le dessin (171 "
                        "contre 223). Les murs meublés (boîtiers, grilles, portes, câbles sombres) ne se "
                        "lisent, quand ils sont dans le cadre, qu'à la loupe ; les baies de serveurs à LED cyan restent absentes (ce seraient des lumières).",
    "ill_amical_local": "Aucune scène : un décor de menu (écrans verts, table d'armes).",
    "ill_competitif": "Peu de changement : la lumière de ce dessin est froide (168, 180, 167) ; la lampe crème s'en "
                      "rapproche un peu (77 → 53). Le rouge et le cyan d'ambiance restent absents (lumières fixes : "
                      "décision d'Adrien).",
    "ill_creer_ligne": "Seule illustration qui s'ÉLOIGNE (couleur 38 → 62) : la lampe crème blanchit le cône qui traverse "
                       "la lumière rouge de la fusée, là où le dessin est tout rouge. Le masque de fumée (--fumee-masque-"
                       "pochoir) garde le noir sous la fusée ; la fumée sombre en rouleaux du dessin n'est pas là.",
    "ill_creer_local": "La lumière monte (1 % clair 125 → 184, dessin 191) ; la couleur se rapproche moins (97 → 66) car ce "
                       "dessin est d'un ocre saturé (249, 196, 108), plus jaune que la lampe crème. Le sol marqué ajoute "
                       "gravats, bandes et cadres sombres : à la loupe seulement.",
    "ill_ecran_scinde": "La lumière des deux moitiés se rapproche fortement (couleur 116 → 35). La torche bleue de J2 du "
                        "dessin reste absente (une couleur par joueur : décision d'Adrien, à luminance égale).",
    "ill_entrainement": "La lampe est crème, mais le 1 % le plus clair BAISSE (98 → 82) : dans cette scène peu éclairée, ton "
                        "propre corps clair faisait partie de ce 1 % ; devenu sombre, il en sort. La lampe fixe au plafond "
                        "du dessin reste absente.",
    "ill_intro_allumage": "La couleur se rapproche (176 → 97) mais l'éclat non (1 % clair 119 → 126, dessin 235) : le dessin "
                          "est un cône blanc sur béton pâle, plein cadre ; la scène d'impacts n'en montre qu'une part.",
    "ill_intro_descente": "Aucune scène : un escalier.",
    "ill_intro_dotation": "Aucune scène : un gros plan d'objets.",
    "ill_intro_extinction": "Torches éteintes, la plus proche des illustrations (distance 7). « Tout » rend l'image un peu "
                            "plus sombre encore (1 % clair 59 → 43) : le dessin est plus noir que le jeu, qui garde les "
                            "LED des murs.",
    "ill_intro_prix": "Le corps sombre est exactement ce que le dessin montre (ardoise devant la lumière). La lumière "
                      "change de couleur (154 → 49). L'ombre portée géante reste contredite.",
    "ill_intro_seuil": "La lumière crème approche l'orange plat du dessin (couleur 111 → 40, 1 % clair 123 → 182 contre 201). "
                       "La porte d'acier et la lumière d'une autre pièce restent absentes.",
    "ill_mise_a_jour": "Aucune scène : la porte du coffre, une image de menu.",
    "ill_quitter": "Aucune scène : une lampe restée allumée au sol, sans joueur.",
    "ill_rejoindre_ligne": "Inchangé pour l'essentiel (couleur 157 → 153) : la lumière de ce dessin est BLEUE (87, 200, 221), "
                           "celle d'un boîtier fixe. La lampe crème n'y peut rien. Les murs meublés approchent un peu les "
                           "faisceaux de câbles, à la loupe.",
    "ill_rejoindre_local": "Le même fichier que « Créer en local » : même lecture.",
    "ill_retour": "Aucune scène : la porte du coffre.",
}
