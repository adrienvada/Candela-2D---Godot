# L'intro — récit A, « Qui allume se montre »

*Refaite de A à Z le 2026-09-28 à la demande d'Adrien (« elle est nulle et plus du
tout dans le thème »), puis refaite une seconde fois le 2026-09-29 : le premier
film (dix plans, une capture du jeu, des images fixes zoomées) a été rejeté —
« les animations ne sont pas réalistes, pas cohérentes ». Remplace l'intro en
planches de DA6.6 (voir la fin de ce document). Pages de travail, avec le
storyboard, les essais et le film :
https://claude.ai/artifact/BW1JypN6UdyKX5ahhWqkG7 (la version en jeu) et
https://claude.ai/artifact/QCqBo76ASmSLR8GCZH7xkP (les quatre récits proposés et
la première version).*

## Le récit

Un mannequin allume sa torche pour chercher l'autre, et c'est précisément ce qui
le perd. L'autre attendait dans le noir, derrière le pilier ZONE 4.

C'est la règle du jeu en images, sans une ligne d'explication : **qui allume
voit, et se montre.** On comprend avant d'avoir joué pourquoi on hésite à allumer
— et on a envie d'être celui qui attend.

## Les règles qui gardent le film cohérent

Adrien a rejeté le premier film pour ses animations. Les règles qui en sont nées :

- **Chaque plan vidéo a une image de début ET une image de fin** (Flow et Runway
  savent tenir les deux) : l'outil interpole un geste écrit, il n'en invente pas.
  Les images de fin sont des retouches Gemini de l'image de début (« change
  seulement ceci »), donc même décor, même lumière.
- **Une seule logique de lumière** : la torche de J1, puis l'éclair du tir, puis la
  torche tombée. J2 n'éclaire jamais.
- **Un seul sens** : J1 va de gauche à droite, J2 est à droite et regarde à gauche.
- **On ne garde que les premières secondes** de chaque clip, relues image par image
  (voir « Pièges connus » de la ROADMAP, 2026-09-28 : Veo peut ignorer l'image de
  départ, dédoubler un objet en mouvement, dériver après 3 s).
- **Plus de capture du jeu** (Adrien, 2026-09-29) : elle cassait le style encré.

## Le découpage

Coupé sur les mesures de la musique du jeu : 170 BPM, quatre temps, **une mesure =
1,4118 s**. 25 mesures, **35,29 s**. Écrit deux fois — `PLANS` dans
`tools/monter_intro.py` et dans `intro_planches.gd` — et vérifié par
`tools/test_intro_planches.gd`.

| # | Mes. | Plan | Ce qu'on voit | Source |
|---|---|---|---|---|
| 1 | 1 | noir | On entend avant de voir : ambiance, pas. | — |
| 2 | 1 | le pouce | Le pouce presse l'interrupteur, la lampe s'allume. | Flow, début → fin |
| 3 | 2 | le couloir | J1, de dos, avance dans le couloir, faisceau ambre. | Flow (clip du 28/09) |
| 4 | 1 | **VOIR** | Un pochoir bombé sur un mur, lu seulement là où passe la torche. | texte animé |
| 5 | 2 | le pilier | Derrière ZONE 4, J2 attend ; le faisceau glisse au sol. | Flow (clip du 28/09) |
| 6 | 1 | la tête | Un reflet ambre glisse sur une arête de la tête cubique de J2. | Flow |
| 7 | 1 | le chasseur | J1 de profil marche vers la droite, le faisceau fouille. | Flow |
| 8 | 1 | **SANS ÊTRE VU.** | Les lettres s'allument en deux ratés, puis meurent une à une. | texte animé |
| 9 | 1 | la main | L'index de J2 glisse sur la détente. | Flow |
| 10 | 1 | le pilier, vu par J1 | Par-dessus l'épaule, le faisceau se pose sur ZONE 4. | Flow |
| 11 | 2 | la sortie | J2 sort de l'ombre, vise, **tire** : le plan finit sur l'éclair de bouche. | Kling 3 Pro, début → fin |
| 12 | 1 | **TUER** | Une image blanche où le mot est brûlé en noir, l'éclair, la rémanence rouge. | texte animé |
| 13 | 1 | la main s'ouvre | Touché, J1 lâche sa torche allumée. | Flow, début → fin |
| 14 | 2 | la torche roule | Elle roule, son faisceau balaie les douilles et le sang. | Flow (clip du 28/09) |
| 15 | 1 | le pied | Le pied de J2 se pose dans la lumière ; la torche s'éteint. | Flow, début → fin |
| 16 | 2 | **SANS ÊTRE TUÉ.** | Gravé dans le sol, lu à la lumière rasante. | texte animé |
| 17 | 4 | CANDELA | Une étincelle enflamme chaque lettre ; éclair, secousse, impact. | Flow, monté |

Le son est entièrement fait des fichiers du jeu : la basse du match entre après le
clic de la torche, la batterie quand J2 serre son arme, tout se coupe net sur le
coup de feu (sifflement d'oreille), puis l'impact du titre (un tir de pompe ralenti
deux fois), l'allumage du tube et la musique d'intro du jeu.

## Ce que le jeu joue

- **Un seul film**, `assets/video/intro/intro_a.ogv` : Theora 1920×1080 + Vorbis
  stéréo, image ET son. Pourquoi un seul fichier : les coupes tombent sur les temps
  et la musique traverse les plans.
- **La musique du jeu se tait pendant le film** (`AudioManager.suspendre_musique`),
  puis reprend où elle était.
- **Le repli** : si le film manque, seize images de `assets/ui/intro/` (1280×720,
  une par plan, textes et titre compris) défilent en coupes franches à la même
  cadence. Muet.
- Inchangé : n'importe quelle touche (clavier, bouton de souris ou de manette) la
  passe, un mouvement de souris non ; jouée une fois (`intro_vue`, posé au
  démarrage), rejouable depuis l'accueil ; nœud `IntroPlanches`, signal `terminee`.
  Pas de rejeu forcé pour qui a vu l'ancienne intro (Adrien, 2026-09-28).

## La fabrication

Trois outils, dans cet ordre, depuis `assets/sources/intro/` (**hors dépôt**, voir
son `.gitignore`) :

1. `python3 tools/intro_textes.py` — les quatre textes animés, fabriqués image par
   image en Pillow (zéro crédit), sur des plaques Gemini recadrées.
2. `python3 tools/intro_titre.py` — le titre : le clip Flow calé sur quatre mesures,
   l'embrasement sur le troisième temps, deux images d'éclair, une secousse.
3. `python3 tools/monter_intro.py` — le film : chaque plan prend une fenêtre de sa
   source et la cale sur sa durée ; mixage des sons du jeu (−16 LUFS, limité) ;
   encodage `ffmpeg2theora` ; les images de repli. `--repere` incruste plan et temps.

### Les outils de génération, comparés (2026-09-29)

- **Gemini** (images) : le storyboard, les images de début et de fin, les plaques.
  Toujours avec des références déjà produites par Gemini (Adrien, 2026-09-28 : les
  illustrations du dépôt ne partent pas).
- **Google Flow, Veo 3.1 Fast** : 40 crédits l'envoi de deux clips de 8 s en 720p.
  Aussi bon que Kling sur les mêmes plans : c'est l'outil principal.
- **Runway** : Kling 3 Pro, 60 crédits le clip de 5 s ; Seedance 2 en 1080p, 200
  crédits le clip (à ne pas refaire). Un envoi Kling est resté bloqué à 98 % :
  débité, jamais livré.
- Dépensé pour la seconde version : 290 crédits Flow (solde 560), 380 Runway
  (solde 235). Pour la première : 200 Flow.

## L'ancienne intro (DA6.6, 2026-09-09 → 2026-09-28)

Six planches (« la descente », « le seuil », « la dotation », « l'allumage », « le
prix », « l'extinction ») : un homme arrive dans un lieu souterrain, s'équipe,
allume sa torche. Les illustrations `ill_intro_*.png` montraient des mannequins,
mais les six clips Veo en avaient fait **un homme réaliste en sweat à capuche** —
la première raison du « plus du tout dans le thème ». Ses six `.ogv` et
`tools/convert_intro_videos.sh` sont retirés.

⚠️ **Restent au dépôt, et ne servent plus à l'intro** : les six `ill_intro_*.png`
(20 Mo en tout). `ill_intro_allumage.png` illustre encore l'entrée « rejouer l'intro » de
l'accueil (`ui.gd`) ; les cinq autres ne sont plus lus que par les tables de
`menu_artwork.gd` et `menu_particles_ambiance.gd`. Les retirer allégerait chaque
téléchargement d’environ 17 Mo — décision laissée à Adrien.
