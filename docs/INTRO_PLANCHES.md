# L'intro — récit A, « Qui allume se montre »

*Refaite de A à Z le 2026-09-28, à la demande d'Adrien : « elle est nulle et plus
du tout dans le thème ». Remplace l'intro en planches de DA6.6 (voir la fin de ce
document). Page de travail, avec le storyboard des quatre récits proposés, les
images et le prémontage : https://claude.ai/artifact/QCqBo76ASmSLR8GCZH7xkP*

## Le récit

Un mannequin allume sa torche pour chercher l'autre, et c'est précisément ce qui
le perd. L'autre attendait dans le noir, derrière le pilier ZONE 4.

C'est la règle du jeu en dix plans, sans une ligne d'explication : **qui allume
voit, et se montre.** Le spectateur comprend avant d'avoir joué pourquoi on hésite
à allumer — et il a envie d'être celui qui attend.

Quatre récits ont été proposés (A « Qui allume se montre », B « La fusée », C « Dix
façons de disparaître », D « Deux moitiés ») ; Adrien a choisi A.

## Le découpage

Coupé sur les mesures de la musique du jeu : 170 BPM, quatre temps, **une mesure =
1,4118 s**. 18 mesures, **25,41 s**.

| # | Mesures | Temps (s) | Image | Son |
|---|---|---|---|---|
| 1 | 2 | 0,00 – 2,82 | Noir. | Ambiance, quatre pas lents. |
| 2 | 2 | 2,82 – 5,65 | Le faisceau ambre s'ouvre ; le mannequin, de dos, avance dans le couloir. **Clip Flow.** | `torch_on`, les pas se rapprochent. |
| 3 | 2 | 5,65 – 8,47 | Le faisceau glisse vers le pilier ZONE 4 ; le caché, torche éteinte, ne bouge pas. **Clip Flow.** | Les pas arrivent tout près. |
| 4 | 2 | 8,47 – 11,29 | **Le jeu** : capture 0.7.0 (photographe, zoom 4) — un mannequin dans son cône, l'autre dans le noir contre le mur. | La pulsation du match, trois mesures en crescendo. |
| 5 | 1 | 11,29 – 12,71 | Le caché lève son arme, à contre-jour. **Clip Flow.** | Le clic de l'arme. |
| 6 | 1 | 12,71 – 14,12 | Un coup de feu éclaire les deux le temps de trois images, puis noir. | Le tir, le sifflement d'oreille. |
| 7 | 1 | 14,12 – 15,53 | Noir. | Une douille tombe. |
| 8 | 2 | 15,53 – 18,35 | La torche tombée roule, son faisceau rase les douilles et le sang. **Clip Flow.** | Frottements, une douille heurtée. |
| 9 | 2 | 18,35 – 21,18 | **VOIR SANS ÊTRE VU.** | Frappe d'imprimerie ; la musique d'intro du jeu démarre. |
| 10 | 3 | 21,18 – 25,41 | CANDELA s'allume en deux ratés, puis fondu sur le panneau ARENA de l'accueil. | `ui_power_on`, puis la musique du menu. |

Tous les sons sont ceux du jeu (`assets/audio/`). Le jeu n'a pas de fichier de
respiration : les pas en tiennent lieu. `weapon_reload_pistolet.wav` est presque
muet (−63 dB en moyenne) : c'est le clic à vide qui fait le cran de l'arme.

## Ce que le jeu joue

- **Un seul film**, `assets/video/intro/intro_a.ogv` : Theora 1920×1080 + Vorbis
  stéréo, 5,3 Mo. Image ET son, tel que validé. Pourquoi un seul fichier : les
  coupes tombent sur les temps et la musique traverse les plans ; deux lecteurs
  qui se relaient perdent une image à chaque raccord.
- **La musique du jeu se tait pendant le film** (`AudioManager.suspendre_musique`),
  puis reprend où elle était : au lancement, sur son clip d'intro, qui enchaîne
  seul sur le menu.
- **Le repli** : si le film manque, les six images de `assets/ui/intro/`
  (1280×720) défilent en coupes franches à la même cadence ; le texte et le logo
  sont posés par le jeu. Muet.
- Inchangé : n'importe quelle touche (clavier, bouton de souris ou de manette) la
  passe, un mouvement de souris non ; jouée une fois (`intro_vue`, posé au
  démarrage), rejouable depuis l'accueil ; nœud `IntroPlanches`, signal `terminee`.
- Les joueurs qui ont vu l'ancienne intro ne verront pas la nouvelle d'eux-mêmes
  (Adrien, 2026-09-28 : pas de rejeu forcé) ; elle reste accessible depuis
  l'accueil.

## La fabrication

Tout se refait avec **`python3 tools/monter_intro.py`** (`--repere` incruste le plan
et le temps, pour relire). Le script dessine chaque image en PIL, mixe les sons du
jeu avec ffmpeg (−16 LUFS, limité), encode avec `ffmpeg2theora` et écrit les
images de repli. Ses sources vivent dans `assets/sources/intro/`, **hors dépôt**
(voir son `.gitignore`), comme les rushes de l'ancienne intro.

Le découpage est écrit deux fois — `plans` dans le monteur, `PLANS` dans
`intro_planches.gd` — et `tools/test_intro_planches.gd` vérifie qu'ils sont
d'accord, plan par plan.

### Les images (Gemini)

Treize images générées dans l'appli Gemini, toujours avec des références jointes,
toujours relues avant d'être gardées. Le bloc de prompt commun exige le mannequin
à tête cubique sans visage en armure gris-bleu sombre, 85 % de noir d'encre et une
seule source de lumière nommée. Les images retenues passent ensuite par **une même
courbe (gamma 1,35)** : 83 à 95 % de pixels sous 30/255, pour une cible de 85 %.
Une courbe commune a été plus fiable que des relances, comme en DA6.6.

⚠️ L'envoi à Gemini d'illustrations du dépôt a été refusé une fois par le garde-fou
de Claude Code (« exfiltration ») : Adrien a tranché que seules des images déjà
produites par Gemini servent de référence.

### Les clips (Google Flow, Veo 3.1 Fast)

Image-vers-vidéo depuis les images-clés, 16:9, 720p (le 1080p n'est pas offert
pour ce modèle ; Adrien : « 720p ça va »). **200 crédits sur 1 050** (cinq envois à
40 crédits, deux sorties chacun ; deux envois ratés n'ont rien coûté). Runway :
rien.

Ce que Veo a fait, et qu'on ne voit qu'image par image :

- **Il peut ignorer l'image de départ.** Les deux essais « propres » du plan 2 ont
  changé de décor, de style et d'armure dès la première image. Le retenu est un
  essai lancé par erreur avec le seul bloc commun : il est fidèle. **Contrôle
  obligatoire : comparer la première image du clip à l'image-clé.**
- **Il dédouble un objet en mouvement.** Plan 5 : deux pistolets superposés
  pendant la montée du bras. 0,45 → 0,85 s sont retirés ; l'arme monte à mi-course
  puis se retrouve pointée d'un coup sec.
- **Il dérive après 3 s** : torche qui flotte (plan 3), torche qui se redresse
  (plan 8). Chaque plan n'utilise que les 1,4 à 2,8 premières secondes.

## L'ancienne intro (DA6.6, 2026-09-09 → 2026-09-28)

Six planches (« la descente », « le seuil », « la dotation », « l'allumage », « le
prix », « l'extinction ») : un homme arrive dans un lieu souterrain, s'équipe,
allume sa torche. Les illustrations `ill_intro_*.png` montraient des mannequins,
mais les six clips Veo en avaient fait **un homme réaliste en sweat à capuche** —
la première raison du « plus du tout dans le thème ». Et le récit ne montrait ni
adversaire, ni tir, ni vue de jeu. Ses six `.ogv` et `tools/convert_intro_videos.sh`
sont retirés.

⚠️ **Restent au dépôt, et ne servent plus à l'intro** : les six `ill_intro_*.png`
(20 Mo en tout). `ill_intro_allumage.png` illustre encore l'entrée « rejouer l'intro » de
l'accueil (`ui.gd`) ; les cinq autres ne sont plus lus que par les tables de
`menu_artwork.gd` et `menu_particles_ambiance.gd`. Les retirer allégerait chaque
téléchargement d’environ 17 Mo — décision laissée à Adrien.
