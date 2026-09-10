# Fiche de Génération Google Flow (Veo 3.1 & Imagen 4) — Candela 2D

*Documentation technique pour la génération ou l'enrichissement vidéo IA de l'introduction narrative.*

Ce guide fournit la suite de prompts et réglages de caméra prête pour **Google Flow** (`flow.google`), s'appuyant sur les modèles **Veo 3.1** (mouvement vidéo cinématique) et **Imagen 4** (génération d'images haute cohérence).

---

## 1. Bloc Invariant de Style (Prompt Système / Style Consistency)

Dans Google Flow, utilisez ce bloc invariant comme référence de style ou en en-tête de chaque prompt pour garantir l'unité visuelle du roman graphique :

```text
Graphic novel noir illustration, heavy ink line art, tight crosshatching, brutalist raw concrete architectural edges. 16:9 cinematic aspect ratio, deep chiaroscuro lighting, 80-85% of frame immersed in pure ink black shadows (sub-10% luminance). High contrast, claustrophobic atmosphere. Single dramatic directional light source cutting through darkness. Limited restrained color palette: deep ink black, desaturated industrial concrete grey, warm incandescent amber (#F5B03D) for filaments and fire, warm off-white (#FAE8CC) for the beam core. Zero saturated primary colors, zero greens, zero neon hues. Gritty texture, dust motes floating in light beams, heavy shadows. Cinematic film grain.
```

### Paramètres recommandés dans Google Flow / Veo :
- **Aspect Ratio** : `16:9` (1024×640 ou 1920×1080)
- **Motion Strength** : `3` / `10` (Mouvement lent, mesuré, cinématique — évite les déformations IA)
- **Camera Controls** : Pans lents, zooms avant légers (Push-in), pas de mouvements brusques
- **Negative Prompt** :
```text
3d render, cgi, photorealistic human skin, colorful, neon, glowing green, saturated colors, smooth clean textures, cartoonish, low quality, blurry, modern armor, sci-fi helmet, futuristic lasers.
```

---

## 2. Storyboard Cinématique des 6 Séquences (Veo 3.1 Prompts)

### Séquence 1 — La Descente (`ill_intro_descente`)
- **Action & Cadrage** : Vue de trois quarts arrière. Un homme seul descend un escalier de béton droit et étroit, sac de sport en bandoulière à l'épaule, main gantée sur la rampe métallique rouillée. Vue de dos anonyme.
- **Éclairage** : Une seule ampoule nue au bout d'un fil vacille au-dessus de lui, dernière source allumée. Le bas des marches s'enfonce dans le noir absolu.
- **Mouvement Caméra Flow/Veo** : `Slow downward camera tilt and slow pedestal down, descending into the pitch-black basement along with the walking figure, dust particles drifting across the flickering bulb light. Ambient underground tension.`

### Séquence 2 — Le Seuil (`ill_intro_seuil`)
- **Action & Cadrage** : Plan rapproché sur une lourde porte blindée industrielle entrouverte de quelques centimètres. Une main gantée la pousse lentement. Au-dessus du linteau, un panneau rouillé avec l'inscription gravée **ARENA**.
- **Éclairage** : Une fente de lumière rasante ambrée s'échappe de la porte entrouverte. Derrière, l'obscurité totale d'un puits sans fond.
- **Mouvement Caméra Flow/Veo** : `Slow cinematic push-in toward the vertical slit of light and the rusty "ARENA" sign, ominous claustrophobic camera creep forward as the heavy steel door creeps open into pure darkness.`

### Séquence 3 — La Dotation (`ill_intro_dotation`)
- **Action & Cadrage** : Plan serré en légère plongée sur un établi de béton brut fissuré. Posés sur la dalle : une lampe torche tubulaire en acier patiné et un pistolet semi-automatique lourd. Une main entre dans le cadre et saisit fermement la torche.
- **Éclairage** : Lampe rasante d'atelier hors champ projetant des ombres longues et dures sur le grain du béton et les douilles éparpillées.
- **Mouvement Caméra Flow/Veo** : `Slow lateral macro tracking camera moving from the gun to the heavy steel flashlight, hand entering frame to grip the torch, cinematic depth of field, ink-hatched textures.`

### Séquence 4 — L'Allumage (`ill_intro_allumage`)
- **Action & Cadrage** : L'homme debout de profil allume violemment sa torche. Le faisceau s'ouvre d'un coup sec, découpant l'espace d'un cône éclatant qui percute un mur de béton ébréché, criblé d'impacts de balles et maculé de sang séché.
- **Éclairage** : Percée violente à 100% de puissance lumineuse. Poussières denses illuminées dans le cône, contraste maximal avec le noir d'encre environnant.
- **Mouvement Caméra Flow/Veo** : `Sudden violent burst of bright amber-white flashlight beam cutting through pitch darkness with micro camera shake on ignition, followed by slow steady pan across bullet holes and dried blood stains on the brutalist concrete wall.`

### Séquence 5 — Le Prix (`ill_intro_prix`)
- **Action & Cadrage** : Plan large cinématographique. L'homme de dos au premier plan à gauche tient la torche. Le faisceau traverse tout le couloir et révèle, au loin, une silhouette ennemie immobile dans le cône. Simultanément, la torche projette l'ombre démesurée du protagoniste sur le mur arrière.
- **Texte en carton** : *VOIR SANS ÊTRE VU.*
- **Mouvement Caméra Flow/Veo** : `Expansive slow cinematic pull-back and subtle drift, revealing the chilling tension of the two figures: the lit silhouette in the distance and the colossal menacing shadow cast behind the protagonist.`

### Séquence 6 — L'Extinction & Climax (`ill_intro_extinction`)
- **Action & Cadrage** : La torche est brusquement coupée. Le cadre est englouti à 95% dans le noir le plus profond. Seule subsiste la lueur rougeoyante d'un filament mourant et une braise fumante flottant dans l'ombre.
- **Texte en carton** : *TUER SANS ÊTRE TUÉ.*
- **Transition Finale** : Le mot stencil *CANDELA* émerge incandescent de l'obscurité.
- **Mouvement Caméra Flow/Veo** : `Sudden blackout snap, camera slowly drifting in toward a tiny dying orange ember in a sea of absolute ink black void, smoke wisp ascending, dissolving into glowing embossed industrial title letterforms.`
