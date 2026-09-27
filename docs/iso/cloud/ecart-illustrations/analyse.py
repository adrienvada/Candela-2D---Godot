"""L'écart du jeu à ses illustrations — le contenu : ce que montre chaque illustration, la scène du jeu qui l'approche, et le
tableau de ce qui est là, de ce que les essais apportent, de ce qui manque, et de ce que ce manque vaut devant les invariants
du jeu (noir absolu, équité, rien de plus clair que la surface qui le porte). Lu par `planche.py`.

Verdicts : `compatible` (le manque peut se combler sans toucher aux invariants), `moitie` (compatible à une condition, dite
dans la cellule), `contredit` (l'illustration montre ce que le jeu ne DOIT pas montrer).
"""

VERDICTS = {
    "compatible": "compatible",
    "moitie": "compatible, à condition",
    "contredit": "contredit les invariants",
}

SCENES_LIBELLES = {
    "duel": "le duel — J1 face au mur haut, J2 dans son cône",
    "noir": "le duel, torches éteintes",
    "scinde": "l'écran scindé, de part et d'autre du mur haut",
    "sol": "J1 devant le pochoir au sol « ZONE 1 »",
    "mur": "J1 devant la face la plus meublée de tuyaux",
    "arena": "J1 devant l'enseigne « ARENA »",
    "zone": "J1 devant la peinture murale « ZONE 1 »",
    "impacts": "trois tirs dans un mur, étincelles en l'air",
    "fusee1": "une fusée, 1,5 s après le lancer",
    "fusee2": "une fusée, 4 s après le lancer",
    "entrainement": "l'entraînement, la cible",
}



def r(theme, la, essais, manque, verdict):
    return {"theme": theme, "la": la, "essais": essais, "manque": manque, "verdict": verdict}


# Les lignes qui reviennent d'une illustration à l'autre : écrites une fois, pour que le même constat se dise pareil.
CADRAGE = r("Cadrage",
            "Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur.",
            "Rien : aucun essai ne touche la caméra.",
            "Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir.",
            "contredit")
PERSO = r("Personnages",
          "Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche.",
          "Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : "
          "accessoires modelés (à 60 px, à peine lisibles).",
          "Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; "
          "la lampe et l'arme lisibles dans la main.",
          "moitie")
PERSO_V = ("un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais "
           "dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien).")
TORCHE = r("La lumière et sa couleur",
           "Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99).",
           "Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle.",
           "Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; "
           "le faisceau visible dans l'air, avec sa poussière.",
           "moitie")
TORCHE_V = ("plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré "
            "le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée.")
AMBIANCE = r("Le noir hors de la lumière",
             "Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane "
             "de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte.",
             "Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures).",
             "Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, "
             "9e décile 85-230, contre 0 et 28 au jeu).",
             "contredit")
MURS = r("Les murs",
         "Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés "
         "au pied ; dessus noirs.",
         "Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; "
         "enseignes : « ARENA » et « ZONE n », plus sombres que le béton.",
         "", "compatible")
SOL = r("Le sol",
        "Dalles carrées brun-ocre, douilles et sang laissés par le jeu, gravats au pied des murs (usure).",
        "Pochoirs : « ZONE 1 », « DEATHMATCH » et bandes, peints sombres au sol ; encre : hachures.",
        "", "compatible")


def murs(manque, verdict="compatible"):
    return dict(MURS, manque=manque, verdict=verdict)


def sol(manque, verdict="compatible"):
    return dict(SOL, manque=manque, verdict=verdict)


def perso(detail=""):
    return dict(PERSO, manque=PERSO["manque"] + (" " + detail if detail else "") + " Condition : " + PERSO_V)


def torche(detail=""):
    return dict(TORCHE, manque=TORCHE["manque"] + (" " + detail if detail else "") + " — " + TORCHE_V)


ILLUSTRATIONS = [
    {"nom": "ill_accueil", "titre": "L'accueil", "scene": "arena",
     "decrit": "Un mannequin anthracite, pistolet au poing, braque une lampe au cône ambre, dur et plein, sur un poteau de "
               "panneaux rouillés dont seul « ARENA » se lit. Béton gris-brun à hachures, portes à grilles, sol jonché de "
               "douilles en laiton et de sang. Plan moyen de trois quarts, à hauteur d'homme ; les murs se lisent en "
               "demi-teinte bien au-delà du cône.",
     "tableau": [torche(), AMBIANCE,
                 murs("Le panneau sur POTEAU (le jeu pose une plaque à plat sur la face) ; les grilles, les portes ; la "
                      "rouille claire du panneau.", "moitie"),
                 sol("Les douilles de décor, par dizaines, qui brillent.", "contredit"),
                 perso(), CADRAGE]},
    {"nom": "ill_amical", "titre": "Amical", "scene": "zone",
     "decrit": "Deux mannequins de part et d'autre d'un pilier de béton qui porte « ZONE 4 » peint au pochoir blanc, "
               "chacun avec sa lampe ambre ; poussière et étincelles dans les cônes. Tuyaux et boîtiers électriques aux "
               "murs, machine à droite, gravats, douilles, sang. Les deux joueurs se voient de profil.",
     "tableau": [torche("Deux cônes qui se croisent dans l'air."), AMBIANCE,
                 murs("Le « ZONE 4 » BLANC du dessin (le jeu le peint sombre : un blanc serait plus clair que le "
                      "béton qui le porte) ; les boîtiers électriques ; le pilier isolé.", "moitie"),
                 sol("Les gravats épars (hors du pied des murs), la machine."),
                 perso(), CADRAGE]},
    {"nom": "ill_amical_ligne", "titre": "Amical en ligne", "scene": "mur",
     "decrit": "Une salle de serveurs : baies noires semées de LED cyan, câbles en guirlandes au plafond, long couloir en "
               "perspective. Un mannequin rouillé braque une lampe jaune pâle ; une tache de lumière au sol ; traînée de "
               "sang. Ambiance froide bleu-gris.",
     "tableau": [torche(),
                 r("Les petites lumières", "Les filets LED dorés au pied des murs, allumés partout.", "Rien.",
                   "Des LED cyan par centaines sur des baies : autant de sources, qui éclaireraient les joueurs proches.",
                   "moitie"),
                 AMBIANCE,
                 murs("Les baies de serveurs (un décor entier, pas une texture) ; les câbles en guirlande au PLAFOND — "
                      "le jeu n'a pas de plafond."),
                 perso(), CADRAGE],
     "note_scene": "Condition des LED cyan : ce sont des lumières ; si elles éclairent, elles changent le jeu (un joueur "
                   "devant une baie se voit) — décision d'Adrien ; si elles n'éclairent rien, un point cyan sur un mur "
                   "sombre est plus clair que sa surface : contredit."},
    {"nom": "ill_amical_local", "titre": "Amical local", "scene": None,
     "pourquoi_rien": "Une salle de moniteurs à tubes verts (images de couloirs, « 22:15:38 SEC C »), une table en bois "
                      "avec pistolets et chargeurs : c'est l'armurerie d'avant-match, un décor de menu. Aucune carte n'a "
                      "de moniteurs ni de table, aucune scène ne s'en approche.",
     "decrit": "Un mur d'écrans cathodiques verts qui éclairent une table d'armes ; un mannequin bleu rouillé de face à "
               "droite. Toute la lumière est verte et vient des écrans.",
     "tableau": [r("Ce qu'il faudrait", "—", "—",
                   "Un décor d'intérieur (écrans, table, armes posées) et une lumière verte fixe.", "moitie")]},
    {"nom": "ill_competitif", "titre": "Compétitif", "scene": "impacts",
     "decrit": "Un tableau électrique ouvert (« MAIN FEED ») éclairé de cyan, un couloir qui s'enfonce dans le rouge, "
               "des impacts de balles plein les murs, un mannequin qui avance lampe blanche au poing, un rond de lumière "
               "au sol, des douilles partout. Rouge et sarcelle.",
     "tableau": [torche("Le rond de lumière au bout du cône, net."),
                 r("Couleurs d'ambiance", "Une seule famille de couleur : ocre, dorée par les LED.", "Rien.",
                   "Le rouge du fond de couloir et le cyan du tableau : deux lumières colorées fixes.", "moitie"),
                 AMBIANCE,
                 murs("Le tableau électrique ; les impacts par dizaines (le jeu montre les 48 derniers, au défaut, là où "
                      "l'on a tiré — c'est de l'information, pas du décor)."),
                 sol("Les douilles en nappe, préalables à tout tir.", "contredit"),
                 perso(), CADRAGE]},
    {"nom": "ill_creer_ligne", "titre": "Créer en ligne", "scene": "fusee1",
     "decrit": "Un mannequin accroupi tient une fusée au cœur blanc et à la flamme rouge ; un halo rouge sang, une "
               "énorme fumée rouge et noire qui roule sous un plafond de câbles et de tuyaux ; sol de douilles.",
     "tableau": [r("La lumière de la fusée",
                   "Un grand disque de lumière rouge-orangé (1,5 s), puis orange-jaune (4 s) ; le point de braise presque "
                   "blanc (Q34 = C, au défaut).",
                   "Rouge long : le rouge tient jusqu'à 4 s ; rouge « sang » : la teinte passe de l'orange au rouge "
                   "(350-5°) — mais à luminance égale il vire au ROSE (voir la loupe à 4 s).",
                   "Le rouge SOMBRE et saturé (le 1 % le plus clair de l'illustration : 242, 175, 174 ; sa moyenne "
                   "éclairée : 86, 41, 44).",
                   "contredit"),
                 r("La fumée", "Une fumée claire et translucide, couleur de la lumière.", "Rien de plus.",
                   "La fumée épaisse, SOMBRE, en rouleaux, qui cache le plafond.", "moitie"),
                 murs("Les câbles et tuyaux au plafond : le jeu n'a pas de plafond (les tuyaux de l'essai sont sur les "
                      "faces)."),
                 perso("La pose accroupie, la fusée tenue à la main."), CADRAGE],
     "note_scene": "La fusée, contredite : la session « fusée rouge » l'a établi — le rouge sang du dessin est surtout "
                   "SOMBRE, et un sol plus sombre sous la fusée, c'est un jeu qui montre moins (la fusée est une "
                   "information partagée). La fumée sombre : compatible si elle ne s'allume que dans la lumière de la "
                   "fusée, jamais dans le noir (le masque de fumée, `--fumee-masque`, éteint, porte cette garantie ; il "
                   "n'est pas dans les essais demandés ici)."},
    {"nom": "ill_creer_local", "titre": "Créer en local", "scene": "sol",
     "decrit": "Un pilier fissuré, ocre, entre deux mannequins ; au sol, un marquage peint « ZONE 4 » et "
               "« DEATHMATCH » dans des bandes blanches, des chaînes, des douilles ; mezzanine à garde-corps, graffitis, "
               "machine. Toute l'image baigne dans un jaune d'ocre chaud.",
     "tableau": [torche(), AMBIANCE,
                 sol("Les bandes et les lettres BLANCHES (le jeu les peint en noir à 45 % : un blanc serait plus clair "
                     "que le sol) ; les chaînes.", "moitie"),
                 murs("La mezzanine, le garde-corps, les graffitis clairs sur béton sombre.", "moitie"),
                 perso(), CADRAGE]},
    {"nom": "ill_ecran_scinde", "titre": "Écran scindé", "scene": "scinde",
     "decrit": "Un diptyque : à gauche, lumière AMBRE (J1), à droite lumière BLEUE (J2), de part et d'autre d'un mur ; "
               "poutres, plafond de planches, poussière dans les cônes, ronds de lumière au sol ; mannequins rouillés.",
     "tableau": [torche("Une couleur de torche par joueur (ambre / bleu)."),
                 r("Équité des couleurs", "Même torche pour les deux ; J2 vu depuis le côté opposé (lacet B).",
                   "Rien.",
                   "Deux torches de couleurs différentes.", "moitie"),
                 AMBIANCE,
                 murs("Poutres et plafond : le jeu vu de haut n'en a pas."),
                 perso(), CADRAGE],
     "note_scene": "Une torche bleue et une torche ambre ne se valent pas : l'œil ne lit pas la même luminance dans les "
                   "deux (le bleu paraît plus sombre à énergie égale). Compatible seulement à luminance égale, mesurée "
                   "— décision d'Adrien."},
    {"nom": "ill_entrainement", "titre": "Entraînement", "scene": "entrainement",
     "decrit": "Un stand de tir : une suspension au plafond jette un cône de lumière sur une cible en carton criblée ; "
               "un mannequin tire ; un tapis de douilles couvre tout le sol ; piliers de béton, silhouettes de cibles au "
               "fond du couloir.",
     "tableau": [r("La lumière", "Seule la torche du joueur ; la cible dans le noir.",
                   "Cœur chaud à la lampe.",
                   "Une lampe FIXE au plafond au-dessus de la cible.", "compatible"),
                 AMBIANCE,
                 sol("Le tapis de douilles (ici légitime : c'est l'entraînement, personne n'en tire d'information)."),
                 murs("Les cibles-silhouettes en carton, les piliers."),
                 perso("La pose de tir, bras tendus."), CADRAGE],
     "note_scene": "L'entraînement est le seul mode sans adversaire : une lampe fixe et un sol jonché n'y trompent "
                   "personne. C'est le lieu le moins cher pour se rapprocher d'une illustration."},
    {"nom": "ill_intro_allumage", "titre": "Intro — l'allumage", "scene": "impacts",
     "decrit": "Le plus proche du jeu : un noir total, un mannequin rouillé, un cône ambre plein de poussière et "
               "d'étincelles qui frappe un mur de béton pâle criblé d'impacts, du sang qui coule, des douilles. Hors du "
               "cône, rien.",
     "tableau": [torche("Le cône plein de poussière, jusqu'au mur."),
                 r("Le noir hors de la lumière", "Noir, sauf les filets LED.", "Rien.",
                   "Rien : l'illustration EST le noir absolu.", "compatible"),
                 murs("Le béton PÂLE sous la lampe (le jeu : beige moyen) ; les impacts groupés à hauteur d'homme ; "
                      "le sang qui coule sur la face."),
                 perso(), CADRAGE]},
    {"nom": "ill_intro_descente", "titre": "Intro — la descente", "scene": None,
     "pourquoi_rien": "Un escalier : le jeu est plan, sans niveaux ni marches.",
     "decrit": "Un mannequin de dos, sac à l'épaule, descend un escalier sous une ampoule nue qui pend à son fil ; "
               "murs lépreux ocre.",
     "tableau": [r("Ce qu'il faudrait", "—", "—", "Des niveaux, une ampoule fixe.", "moitie")]},
    {"nom": "ill_intro_dotation", "titre": "Intro — la dotation", "scene": None,
     "pourquoi_rien": "Un gros plan d'objets sur une table (pistolet dans un rond de lumière, main qui prend la lampe) : "
                      "un plan de cinéma, que la caméra du jeu ne fait pas.",
     "decrit": "Une table, un pistolet dans un rond de lumière tombée du plafond, la main cubique d'un mannequin qui "
               "saisit la lampe.",
     "tableau": []},
    {"nom": "ill_intro_extinction", "titre": "Intro — l'extinction", "scene": "noir",
     "decrit": "Le noir presque total (93 % de l'image sous 7,5/255) : une main de mannequin au bord d'une table, une "
               "braise rouge qui meurt, un filet de fumée.",
     "tableau": [r("Le noir", "Torches éteintes : 45 % de l'image reste éclairée par les filets LED des murs.",
                   "Rien : aucun essai n'allume le noir (1 pixel, au bruit près).",
                   "L'illustration est PLUS noire que le jeu : sans les LED, il ne resterait que la braise.",
                   "compatible"),
                 perso("La main et son liseré, seuls visibles près de la braise."), CADRAGE],
     "note_scene": "Les LED des murs sont une décision du jeu (lumières fixes, les mêmes pour les deux joueurs) ; "
                   "l'illustration ne les a pas. Ce n'est pas une faute envers le noir absolu : elles SONT des lumières."},
    {"nom": "ill_intro_prix", "titre": "Intro — le prix", "scene": "duel",
     "decrit": "Un couloir voûté ; un mannequin de dos braque sa lampe ambre, qui découpe au fond un autre mannequin en "
               "SILHOUETTE NOIRE sur un mur pâle ; l'ombre géante du premier sur le mur de gauche ; gravats, sang.",
     "tableau": [torche(),
                 r("Le contre-jour", "J2 dans le cône est ÉCLAIRÉ, gris, de face.", "Mannequin : côté de la lumière.",
                   "La silhouette noire sur fond clair : l'adversaire DEVANT un mur éclairé.", "compatible"),
                 r("Les ombres portées des corps", "Les corps ne portent pas d'ombre sur les murs.", "Rien.",
                   "La grande ombre du joueur sur le mur, portée par une lumière derrière lui.", "contredit"),
                 AMBIANCE, perso(), CADRAGE],
     "note_scene": "L'ombre portée du premier mannequin suppose une lumière DERRIÈRE lui, qui n'existe pas dans la "
                   "scène (sa propre lampe est devant) : c'est un effet de dessin. La silhouette au fond, elle, est la "
                   "promesse même du jeu, et le jeu la tient déjà quand J2 passe devant un mur que la torche éclaire."},
    {"nom": "ill_intro_seuil", "titre": "Intro — le seuil", "scene": "arena",
     "decrit": "Une porte d'acier rivetée, rouillée, entrouverte sur une lumière orange plate ; au-dessus, la plaque "
               "« ARENA » ; un mannequin la pousse, lampe à la main ; pierre ocre à hachures ; ombre longue au sol.",
     "tableau": [r("La lumière", "Seule la torche.", "Rien.",
                   "La lumière qui vient d'une autre pièce, par une porte.", "moitie"),
                 murs("La porte d'acier ; la plaque ARENA claire et grande (le jeu : petite, sombre, sur la face).",
                      "moitie"),
                 perso("Le geste (pousser une porte)."), CADRAGE]},
    {"nom": "ill_mise_a_jour", "titre": "Mise à jour", "scene": None,
     "pourquoi_rien": "Une porte de coffre-fort ronde « VAULT 07 » qui s'ouvre sur des rayons dorés : une métaphore de "
                      "menu (le jeu se met à jour), sans rien du duel.",
     "decrit": "Un mannequin de dos, en contre-jour, devant une porte de coffre ronde entrouverte d'où jaillissent des "
               "rayons dorés ; chaînes, douilles.",
     "tableau": []},
    {"nom": "ill_quitter", "titre": "Quitter", "scene": None,
     "pourquoi_rien": "Personne : une lampe abandonnée au sol, allumée, près d'une flaque de sang. Le jeu n'a pas de "
                      "torche qui reste allumée sans joueur — la plus proche serait la fin de manche, et le photographe "
                      "ne sait pas la poser au même instant pour les deux lancements.",
     "decrit": "Un couloir vide, une lampe torche couchée au sol, allumée, une flaque de sang, des douilles ; une porte "
               "rivetée au fond ; ambre et reflets bleus.",
     "tableau": [r("Ce qu'il faudrait", "—", "—",
                   "Une lampe qui reste allumée à terre, sans joueur : une lumière posée (comme la fusée).",
                   "moitie")]},
    {"nom": "ill_rejoindre_ligne", "titre": "Rejoindre en ligne", "scene": "mur",
     "decrit": "Un couloir étroit tapissé de faisceaux de câbles noirs et de tuyaux ; au fond, un boîtier bleu irradie ; "
               "un mannequin, sac au dos, pistolet au poing, marche vers lui ; douilles au sol.",
     "tableau": [r("La lumière", "La torche, les filets LED dorés.", "Rien.",
                   "Une source bleue fixe au fond du couloir, qui rayonne.", "moitie"),
                 murs("Les faisceaux de câbles serrés, d'un bout à l'autre du couloir (l'essai en pose quelques-uns)."),
                 perso("Le sac à dos (les corps détaillés en portent sur certaines classes)."), CADRAGE]},
    {"nom": "ill_rejoindre_local", "titre": "Rejoindre en local", "scene": "sol",
     "decrit": "Le même fichier, octet pour octet, que « Créer en local » (même empreinte md5) : voir plus haut.",
     "tableau": []},
    {"nom": "ill_retour", "titre": "Retour", "scene": None,
     "pourquoi_rien": "La porte du coffre « VAULT 07 / RESTRICTED » en gros plan, un rayon doré : une image de menu.",
     "decrit": "Une porte de coffre-fort ronde, gonds et volant, entrouverte ; un faisceau doré horizontal ; roche, sol "
               "de dalles.",
     "tableau": []},
]
