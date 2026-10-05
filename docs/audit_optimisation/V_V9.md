# V9 — Le coût GPU des shaders du duel, et une compilation à la volée : vérification contradictoire

Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12). Lecture seule ; Godot n'a pas été lancé ; aucun fichier du dépôt
n'a été touché. Rapport source : `03_SHA_shaders.md` (blocs complets lus). Constats vérifiés : **SHA-04, SHA-02, SHA-05, SHA-08, SHA-10,
SHA-11, SHA-13**, et SHA-12 (liste des fichiers morts seulement). Laissés aux autres vérificateurs : SHA-01 (V1b), SHA-03/06/07 (V8),
SHA-09 (V2), ISO-12 (même objet que SHA-12).

Écrit en dehors de ce rapport : deux petits scripts de comptage qui relisent le dépôt sans le modifier (`v9_work/muretsl.py`,
`v9_work/muretsl_vue.py`, qui réutilisent le portage Python de `MapGeometry` déjà présent dans `audit/port_geom.py`).

Conventions. **PROUVÉ** : lu dans le code ou dans un fichier du dépôt (`fichier:ligne`, numéros relus sur `52a29c1`). **ESTIMÉ** : raisonné,
ordre de grandeur sans mesure. **À MESURER** : rien ne le fonde. Ce que je sais de Godot 4.7, de Mesa ou des GPU Apple sans pouvoir le relire ici
(aucun source du moteur sur cette machine) est marqué « connaissance du moteur » et reste à confirmer.

---

## 0. Verdicts d'un coup d'œil

| ID | Verdict | Sévérité corrigée | Coût corrigé |
|---|---|---|---|
| **SHA-04** | CONFIRMÉ AVEC RÉSERVE | **MAJEUR présumé** (ESTIMÉ ; non démontrable dans le cloud) | sol : 460-505 ALU-éq économisés par pixel noir (rapport : 560) sur ≈ 1,8-3 Mpx dont 75-95 % de noir ⇒ **0,6-1,4 G, soit ≈ 0,3-1,4 ms sur le M3 (ESTIMÉ, non mesuré)** ; faces : 0,03-0,18 G (≈ 0,03-0,2 ms) |
| **SHA-02** | CONFIRMÉ AVEC RÉSERVE | MINEUR (moitié CPU du hoquet de SHA-01, qui est MAJEUR présumé) | **à mesurer** : ni 10-30 ms (SHA-02) ni 10-150 ms (V1b) ne reposent sur une mesure ; compte exact : 10 `Shader.new()`, dont 2 dessinés |
| **SHA-05** | CONFIRMÉ AVEC RÉSERVE | MINEUR (probablement ANECDOTIQUE) | 243 ALU-éq par pixel de sol éclairé (rapport : 215) ⇒ 0,02-0,2 G ⇒ **≤ 0,2 ms, plus vraisemblablement ≈ 0,05 ms** |
| **SHA-08** | (a) CONFIRMÉ AVEC RÉSERVE ; (b) CONNU-OUVERT confirmé | (a) ANECDOTIQUE à MINEUR ; (b) MAJEUR localisé à 2 niveaux sur 100 | (a) **≈ 0,05-0,1 ms en duel**, jusqu'à ≈ 0,3 ms dans une salle de solo à ≈ 15 lumières (ESTIMÉ) ; (b) +4 ms MESURÉ à 40 murets en écran scindé 1440p, ≈ +2 ms en vue unique (ESTIMÉ, jamais mesuré en iso) |
| **SHA-10** | CONFIRMÉ AVEC RÉSERVE | ANECDOTIQUE | ≈ 5 M de lectures par image ⇒ **≤ 0,05 ms** ; (b) change l'image |
| **SHA-11** | CONFIRMÉ (chiffres recomptés exacts) ; reste CONNU-OUVERT | ANECDOTIQUE sur le M3 (MINEUR à surveiller sur iGPU) | ≈ 0,055 G par vue et par fusée (500 ALU-éq × 109 632 sommets) ⇒ **≈ 0,05 ms** ; resserrer le juge : ≤ 11 % des fragments du nuage |
| **SHA-13** | CONFIRMÉ AVEC RÉSERVE comme risque de portabilité ; **RÉFUTÉ comme gain de performance** | MINEUR (portabilité) / ANECDOTIQUE (temps) | le hash de Hoskins coûte ≈ 18 opérations contre ≈ 5 (≈ 8 ALU-éq) pour le hash à `sin` : **aucun gain démontré, plutôt une perte (ESTIMÉ)** ; l'image change : **décision d'Adrien** |
| **SHA-12** | CONFIRMÉ | ANECDOTIQUE | liste exacte ci-dessous : 2 145 lignes + 1 orphelin de 33 ; démarrage ≈ −10 à −20 ms ESTIMÉ, rien de plus |

Cinq choses que le rapport source ne dit pas, et qui changent la lecture :

1. **SHA-04 : deux de ses trois options ne se valent pas.** L'option 1 (sortie sur couleur nulle) est exacte au bit. L'option 2 (ne calculer
   l'usure que sous le seuil de luminance) **ne l'est pas** : le code actuel passe par `pate_facteur(c, 1.0)`, un aller-retour sRGB qui n'est pas
   l'identité en virgule flottante (le dépôt le sait déjà : ROADMAP l. 28241-28246). Elle se range avec l'option 3.
2. **SHA-04 : la garde à rouvrir n'est pas une, mais trois** (`test_banc.gd`, `test_iso_usure.gd`, `test_iso_beaute.gd`), dont deux lisent le texte
   source **à la tabulation près** (§ 1.6).
3. **SHA-04 : le principe existe déjà dans le dépôt, appliqué à la copie du masque de fumée** (`volume_masque.gdshaderinc:244-251`, `:341-358`), et la
   ROADMAP rapporte que ce « calcul réduit, même réponse au pixel » **« n'a rien rendu »** à la mesure sur le Mac (l. 4199-4204). Ce n'est pas la même passe,
   mais c'est un précédent défavorable qu'il faut citer.
4. **SHA-04 sous llvmpipe** : à ma connaissance de gallivm, un `if` de fragment shader s'y exécute par masque SIMD, sans saut. **La prise de cadence du cloud ne
   verra donc probablement aucun gain**, et son absence ne réfute rien ; ce qui se prouve dans le cloud, c'est l'identité à l'octet et le nombre de pixels qui
   sautent la chaîne (§ 1.4).
5. **SHA-13 ne fait gagner aucun temps** : le remplaçant (hash de Hoskins, ≈ 18 instructions) coûte plus que `sin` + 3 opérations (≈ 5 instructions) ; retirer 10 à 17 `sin` revient à en ajouter ≈ 170.

---

## 1. Faits transversaux (établis une fois, cités dans les blocs)

### 1.1 Le sol dessine TOUTE la fenêtre

`Presentation3D._suivre` pose chaque sol sur le rectangle que la lightmap couvre :

```gdscript
# presentation_3d.gd:824-827
var rect := CameraIso.rect_couvert(canevas, taille)
_sols[id].position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
_sols[id].scale = Vector3(rect.size.x, 1.0, rect.size.y)
```

Ce n'est pas le rectangle de la carte : c'est celui de la vue 2D (1920×1080 logiques, ×1,5 de zoom par défaut : 1 280×720 px de monde, `tools/loupe.gd` en-tête). Tout
pixel d'écran que ni un mur ni un corps ne couvre est donc un fragment du shader `sol_iso`. La fourchette « 2,2 à 3,7 Mpx » du rapport tient à 2560×1440
(3,69 Mpx) ; elle suit la surface de la fenêtre, pas le contenu.

### 1.2 Quelle part de ce sol est noire (point (b) de la mission)

Le rapport s'appuie sur « sol 27,3 % éclairé » (ROADMAP l. 26096). **C'est la part d'une zone d'étude de ≈ 100 000 px centrée sur l'action** (« 97 042 pixels »,
l. 26186), pas celle de l'écran. Trois sources du dépôt donnent mieux, toutes dans le même sens :

- **Mesuré sur l'écran entier par le dépôt** (ROADMAP l. 10187-10190, piège du bandeau de LED) : dans le cadrage de banc `une_lumiere` (une lampe), la référence 2D éclaire **de 2 % à 27 % de l'écran** selon la phase de
  respiration de la LED des murs (8,5 s de période, `mur_led.gd:102`) ; `fusee_seule`, de 4,7 % à 30 %. Soit **73 à 98 % de noir selon la phase** (pixels éclairés en 2D, seuil non précisé par la ROADMAP).
- **Par construction (PROUVÉ, constantes du code)** : une torche éclaire un secteur de demi-angle `torch_angle_deg` (10° à 60° selon la classe, 20,34° au pistolet,
  `weapon_data.gd:82`) jusqu'à 468 px (Q76). Aire = demi-angle (rad) × r² : 38 000 px² (10°), 78 000 (20°), 229 000 (60°), soit **4 %, 8 % et 25 %** d'une vue de
  921 600 px² de monde. Le halo de proximité et le bandeau de LED s'y ajoutent ; les murs retirent.
- **Le lavis noircit aussi de la lumière non nulle** : la première bande de `pate()` ne s'allume qu'au-dessus de `e_1 = 0,02 + 0,03·b` (`iso_pate.gdshaderinc:304-309`) ;
  `volume_iso.gdshader:200-202` le dit en toutes lettres (« le sol est noir sur une lumière qui ne l'est pas »). La condition de saut (`c` nul **après** la pâte) couvre donc
  plus de pixels que « lightmap nulle ».

**Conclusion** : 73 % (rapport) est la borne BASSE d'une phase de LED défavorable ; la moyenne est plus probablement de 80-92 %. **À mesurer exactement** (§ 1.4, compteur).

### 1.3 Le modèle de coût utilisé, et ce qu'il vaut

Je reprends les poids du rapport (ALU = 1, transcendante = 4, lecture de texture = 8) pour pouvoir comparer, et je les recompte ligne à ligne. `pate_facteur(c, f)`
(`iso_pate.gdshaderinc:94-106`) : `pate_vers_affiche` = max 3 + div 3 + (+0,055)/1,055 6 + `pow(vec3, 2,4)` 27 + step 3 + mix 6 = **48** ; `pate_depuis_affiche` = **48** ;
×f 4 ⇒ **≈ 100** (rapport : 106). La conversion « ALU-éq → ms » n'a que deux ancres qui divergent d'un facteur 2 à 3 (rapport § 0 : MURS_BAS ≈ 1 G/ms ; usure ≈ 1,6-2,7 G/ms) ;
**je ne la raffine pas** : toute valeur en ms ci-dessous est ESTIMÉE et vaut « ordre de grandeur », à confirmer sur un GPU réel.

### 1.4 Ce que le cloud peut et ne peut pas prouver

- **Identité à l'octet** : valable partout (même rendu des deux côtés, même processus). C'est la preuve qui compte pour tout correctif « à image identique ».
- **Aucune erreur de shader** : `tools/cadence_cloud/analyse.py:60` refuse toute prise dont le journal porte `SCRIPT ERROR`, `SHADER ERROR` ou `Parse Error`. La garde headless **ne compile pas** les
  shaders sur le GPU (ROADMAP l. 4096-4100 : « une variante dont le shader ne compile pas paraît gratuite »). Une comparaison à l'octet doit donc contenir des pixels éclairés : un
  sol qui ne compile pas serait noir partout et « identique » sur les seuls pixels noirs.
- **Temps** : `tools/cadence_cloud/prise.sh` (Xvfb + Mesa llvmpipe, « relative seulement »). **Pour un branchement dynamique (SHA-04, SHA-05), ne pas en attendre de gain** : *connaissance du
  moteur, non vérifiée* — gallivm traduit un `if` de fragment shader en prédication par masque (`lp_exec_mask_cond_push`), sans saut même quand tout le masque est faux. Une prise « sans gain »
  ne prouve donc rien contre le Mac ; une prise « avec gain » (si Mesa 25.2 saute) est un bonus. **Un correctif qui RETIRE du code (SHA-08 a) se voit, lui, sous llvmpipe.**
- **Compteur indépendant du matériel** (ce qui manque, et qui est faisable) : le banc sait déjà compter des fragments par un shader de comptage étalonné sur place
  (ROADMAP l. 3720-3732 ; `banc_gadgets_volume.gd --mode=cout`). Pour SHA-04, une variante de BANC (jamais commitée) du fragment qui écrit `ALBEDO = vec3(1.0)` quand la chaîne est exécutée et
  `vec3(0.0)` sinon donne, sur une capture 1:1, le nombre exact de pixels qui paient la chaîne : 255 contre 0, aucun étalonnage. Multiplié par le nombre d'instructions de la chaîne (comptable dans le
  GLSL que Godot génère ; l'outil `tools/masque_fumee/compter_glsl.py` cité par `test_masque_formes.gd:8` **n'est pas dans le dépôt**), c'est le travail économisé, sans chronomètre.

### 1.5 Le protocole de preuve à l'octet qui existe déjà (à réutiliser tel quel)

C'est celui du **levier 1 de l'usure** (ROADMAP l. 28429-28445) : « la même image, prouvée dans UN seul processus, au même instant figé » — l'ancien chemin compilable sous un `#define`
que le jeu ne pose jamais (`USURE_HUIT_LECTURES`), les deux chemins posés tour à tour **sur le même matériau**, le jeu figé (`Engine.time_scale = 0.0`), les corps cachés (ils respirent sur
l'horloge réelle), l'image ENTIÈRE comparée, plus un **témoin positif** (là, l'usure allumée contre éteinte : 8 459 pixels différents). Les pièces sont versionnées :
`docs/iso/iso13/levier1/preuve_ab_arbre_de_planche_contre_86723ca.patch` (la fonction `_serie_usure` pour `tools/banc_lumiere3d.gd`, l'hôte qui a `_images(IMAGES_DE_REPOS)` et
`_capturer`) et `docs/iso/iso13/levier1/compare_ab.py` (le comparateur, qui sort « N pixels différents, plus grand écart M/255 »). **C'est l'instrument qui convient** ; les autres sont plus
faibles : `tools/banc_iso_beaute.gd` compare un habillage allumé à un habillage éteint (valeurs d'uniformes), pas deux chemins de code ; `tools/loupe.gd` (plans « basculés sur place », A B A') est
l'alternative (`loupe-fusee-masque-preuve`, `loupe-faisceau-taille`) ; `--temps-fixe` n'existe que dans `tools/banc_corps.gd`. `tools/banc_iso.gd --jeu --capture x.png --noir` reste le contrôle du
noir absolu (toutes les lumières éteintes, imprime le maximum de l'image : doit rester 0).

### 1.6 Gardes textuelles sensibles à l'indentation (piège pour tout correctif de `sol_iso` / `mur_iso`)

| Garde | Ce qu'elle lit | Casse si on enveloppe la chaîne dans un `if` |
|---|---|---|
| `tools/test_iso_usure.gd:168` (sols, **et** forks, boucle `SOLS`) | `"#ifdef USURE_ESSAI\n\tc = pate_facteur(c, usure_poids(c, usure_sol(…)));\n#endif\n\tc = pate_facteur(c, contact_des_corps(px));"` | **oui** (une tabulation de plus) |
| `tools/test_iso_usure.gd:163` (murs, **et** forks, boucle `MURS`) | `"encre_plancher_affiche);\n#ifdef USURE_ESSAI\n\t\tc = pate_facteur(c, usure_poids(c, usure_face("` | **oui** si on insère un `if` entre `#ifdef` et la ligne |
| `tools/test_iso_beaute.gd:318-319` | `"c = pate_facteur(c, matiere * dalle);\n\t// ISO7b"` | **oui** (le commentaire suivant passe à deux tabulations) |
| `tools/test_banc.gd:357-392` (`_lignes_du_fragment`, indentation ôtée) | chaque ligne de code du fragment de `sol_iso` / `mur_iso`, renommée (`c`→`c2d`, `brute`→`brute2d`), doit exister dans le fragment du fork éclairé | **oui** : toute ligne NOUVELLE (`if (c.r > 0.0 …) {`) doit être recopiée dans le fork |
| `tools/test_banc.gd:329-350` (`_fonction_de_shader`) | le CORPS de `ton_du_sol`, `lightmap_pateuse_sol`, `contact_des_corps` doit être identique dans `sol_iso_eclaire` | **oui pour SHA-05** : même retouche dans le fork |
| `tools/test_iso_gadgets.gd:903-953, 961-962` | lignes du sol / du mur par `contains(ligne)` (sans tabulation) | non (sous-chaînes) |
| `tools/test_iso_beaute.gd:796-838` (équité du mur) | affectations `c = …` : sources admises | non (`if` ne commence pas par `c = `) |

Les gardes **rougissent tout de suite** (c'est leur rôle) : ce n'est pas un danger, c'est un coût de retouche à compter dans l'effort (S-M, non S).

---

## 2. SHA-04 — le sol et les faces de mur exécutent leur chaîne d'habillage sur des pixels noirs

### 2.1 Le code (PROUVÉ)

```glsl
// sol_iso.gdshader:81-89 — le noir sort ici, MAIS seulement de la fonction, pas du fragment
vec3 lightmap_pateuse_sol(vec2 p, vec2 motif, float aa, bool deux) {
	vec3 c = lire_lightmap(p, deux) * ton_du_sol(p);
	if (style == PATE_BRUTE) { return c; }
	float l = pate_luminance(c);
	if (l <= 0.0) { return vec3(0.0); }
	...
// sol_iso.gdshader:147-168 — la suite s'exécute sur ce 0
	vec3 c = lightmap_pateuse_sol(px_lu, px, aa, deux);
	c = pate_facteur(c, matiere * dalle);                               // 100 ALU-éq
	if (temperature_seuil_haut <= 0.0) { … } else if (neutre_avant_pate > 0.5) {
		vec3 brute = lire_lightmap(px_lu, deux);                        // 2e lecture, MÊME adresse que celle de la fonction (l. 157)
		c = pate_temperature_graduee_neutre(c, …, pate_poids_neutre(brute));
	} …
#ifdef USURE_ESSAI                                                      // défaut depuis Q30 (`iso_materiaux.gd:147-149, 165-173`)
	c = pate_facteur(c, usure_poids(c, usure_sol(px, usure_mur_pres(px), px_monde)));
#endif
	c = pate_facteur(c, contact_des_corps(px));
	ALBEDO = c;
```

```glsl
// mur_iso.gdshader:228-229 puis 265-269 (face verticale) — `usure_face` est évaluée comme ARGUMENT, avant `usure_poids`
c = lightmap_pateuse_lue(brute, motif, aa);
…
c = pate_matiere_et_encre(c, matiere * lambert * contact, encre_arete_reste, max(encre_h, encre_v), encre_plancher_affiche);
#ifdef USURE_ESSAI
		c = pate_facteur(c, usure_poids(c, usure_face(monde.xz, n, tangente, hauteur_face, taille.y, px_monde)));
#endif
```

Configuration de production relue (`iso_materiaux.gd:406-432`) : `force_matiere` 0,5 ; `temperature` 0,8 ; `temperature_seuil_haut` 0,45 ; `neutre_avant_pate` 1 ; `dalles` 1 ; `ton_exposant` 0 ;
`usure` 1 (variante `USURE_ESSAI`, car `usure_active()` vaut vrai sauf `--sans-usure`) ; pâte = lavis (`presentation_3d.gd:203`, les touches de débogage ne jouent qu'en build de débogage, l. 2259-2266) ;
`seuil_noir_2d_3d` 0 (`presentation_3d.gd:322`). **La chaîne décrite par le rapport est bien celle du jeu.**

### 2.2 Point (a) — sauter la chaîne quand `c` est nul donne-t-il EXACTEMENT la même valeur ?

**Oui pour l'option 1, par étape (PROUVÉ par lecture, aucun GPU nécessaire) :**

| Étape appliquée à `c = vec3(0)` | Résultat | Pourquoi |
|---|---|---|
| `pate_facteur(c, f)` (`iso_pate.gdshaderinc:104`) | `vec3(0)` (ou `-0`, écrit 0) | `vers_affiche(0)` = `mix(0, P, step(0,04045, 0) = 0)` = 0 ; ×`max(f,0)` = 0 ; `depuis_affiche(0)` = `mix(0, 1,055·pow(0, 1/2,4) − 0,055, 0)` ; `pow(0, y>0)` est défini (= 0) ; le `mix` à poids 0 rend le premier terme |
| `pate_temperature_graduee_neutre` (`:192-203`) | `c` | `if (l <= 0.0 \|\| force <= 0.0) { return c; }` |
| `pate_poids_neutre(brute)` (`:181-188`), `brute` = 0 | 0 | `mx <= 0 → return 0` |
| `usure_poids(c, f)` (`iso_usure.gdshaderinc:112-115`) | 1 | `smoothstep(0,047, 0,125, 0) = 0` ⇒ `mix(1, f, 0) = 1` pour `f` fini |
| `pate_matiere_et_encre` (`iso_pate.gdshaderinc:115-125`) | `vec3(0)` | `s <= 0.0 → return vec3(0.0)` : **l'encre de 16/255 ne se pose que si `s > 0`** ; rien n'est ajouté au noir |
| `contact_des_corps` | facteur fini ∈ [reste, 1] | multiplicatif ; `pate_facteur(0, f) = 0` |

**Aucun terme additif ne survit au noir** : `ALBEDO = c`, `unshaded`, ni `EMISSION` ni brouillard ni ambiance dans `sol_iso` ni `mur_iso` ; la garde `test_iso_beaute.gd:796-838` le vérifie déjà pour le mur.
Seuls cas où le résultat actuel n'est pas 0 : `f` NaN (`atan(0,0)` dans `usure_face` si un impact tombe exactement au centre d'un fragment) — le code actuel écrit alors une valeur indéfinie
que le framebuffer réduit à 0 ; la sortie anticipée écrit 0 : même octet.

**Non pour l'option 2** (« n'évaluer que si `pate_luminance(c) > USURE_SEUILS.x` ») **si on retire la ligne** : sous 12/255, `usure_poids` vaut bien exactement 1, mais le code actuel applique encore
`pate_facteur(c, 1.0)`, qui n'est pas l'identité en virgule flottante (le dépôt a payé cette leçon : `if (mannequin >= 0.5)`, ROADMAP l. 28241-28246 — « exact à 1e-7 et non au bit »). La retirer change
l'image de ±1/255 sur ≲ 0,05 % des pixels de la bande de pénombre (ESTIMÉ, comme l'option 3 du rapport). **Et elle ne rapporte presque rien de plus** : entre « lightmap nulle » et 12/255 d'albédo il
ne reste qu'un anneau de quelques pixels, le lavis rendant 0 sous son premier seuil. **À écarter** ; l'option 1 prend l'essentiel.

**Dérivées** (« un `if` est-il sûr autour de ce code ? ») : tout ce qui demande des dérivées est pris AVANT la branche — `fwidth` ×4 (`:130-131`) et la matière mipmappée `texture(texture_sol…)` (`:133`).
Dans la branche restent `lire_lightmap` (`texture()` sur une `ViewportTexture` en `filter_linear` **sans mipmap** : une dérivée indéfinie n'y change que le choix min/mag, qui est le même filtre), et
`usure_mur_pres` (`textureLod`, explicite). Pour le mur : `lire_lumiere` lit `peinture` (`filter_linear`, sans mipmap), `occupe` (`textureLod`). **Rien ne dépend d'une dérivée dans la branche.**

### 2.3 Points (b) et (c)

**(b) Part noire** : § 1.2 — 73 à 98 % de l'écran selon la phase de la LED (mesuré par le dépôt), 75-95 % par la géométrie des torches ; les faces : « 58,4 % éclairées » dans la zone d'étude
⇒ ≥ 42 % noires, davantage sur l'écran.

**(c) Rentabilité du branchement.** *Sur un GPU réel : oui, par construction* — le noir vient en très grandes plages (tout ce qui n'est pas cône, halo ou anneau de LED), et un groupe de threads
(32 sur Apple) qui est entièrement noir saute le bloc ; les groupes mixtes (le contour de la lumière : ≈ 2 600 px de périmètre à l'écran (ESTIMÉ) × une dizaine de pixels de bruit de seuil) paient le chemin complet **comme
aujourd'hui**, plus un test de deux opérations. Ils représentent de l'ordre de 1 % du sol (ESTIMÉ). Le test dépend d'une lecture de texture dont le résultat est de toute façon attendu par la suite
(`lightmap_pateuse_sol` branche déjà dessus, l. 87) : pas de nouvelle latence. *Sous llvmpipe : probablement aucun gain* (§ 1.4) — à ne pas lire comme un échec. *Ce qui peut jouer contre* (à mesurer, non
démontrable ici) : rien de structurel ; le précédent « la bande des faces n'a rien rendu » (ROADMAP l. 4199-4204) concernait la copie du masque de fumée, où l'usure n'était payée que sous les pixels de fumée.

### 2.4 Point (d) — la forme exacte du correctif

**Sol** (`sol_iso.gdshader`, une enveloppe, pas de `return;` — la convention du dépôt, et je n'ai pas pu relire si, en `gl_compatibility`, un `return;` saute l'épilogue que le compilateur de Godot
ajoute au fragment) :

```glsl
	vec3 c = lightmap_pateuse_sol(px_lu, px, aa, deux);
	// Noir à l'écran : `c` vaut alors EXACTEMENT 0 (la fonction rend vec3(0) à lumière nulle, le lavis rend 0 sous son premier seuil).
	// Chaque étape qui suit multiplie `c` ou le rend tel quel à luminance nulle : 0 reste 0, au bit près. On ne la paie pas.
	// Les dérivées (`aa`, `px_monde`, la matière mipmappée) sont prises plus haut, hors de ce branchement.
	if (c.r > 0.0 || c.g > 0.0 || c.b > 0.0) {
		c = pate_facteur(c, matiere * dalle);
		…                                   // lignes 151-166 inchangées, une tabulation de plus
		c = pate_facteur(c, contact_des_corps(px));
	}
	ALBEDO = c;
```

**Mur** (`mur_iso.gdshader:267-269`, la seule pièce chère : `usure_face`, ≥ 17 `sin` + une boucle jusqu'à 48 impacts avec `length`, `atan`, `pow`) :

```glsl
#ifdef USURE_ESSAI
		if (c.r > 0.0 || c.g > 0.0 || c.b > 0.0) {
			c = pate_facteur(c, usure_poids(c, usure_face(monde.xz, n, tangente, hauteur_face, taille.y, px_monde)));
		}
#endif
```

**À faire dans le MÊME commit** : (i) recopier l'enveloppe dans `sol_iso_eclaire.gdshader` (branche d'identité, `c2d`) et `mur_iso_eclaire.gdshader:353` ; (ii) mettre à jour les chaînes de
`test_iso_usure.gd:163, 168`, `test_iso_beaute.gd:319` (§ 1.6) ; (iii) ROADMAP + une phrase dans l'en-tête de `sol_iso.gdshader`. **Variante d'épreuve** (jamais commitée, comme `USURE_HUIT_LECTURES`) :
`#ifdef SANS_SORTIE_NOIRE` remplace la condition par `true`.

Gain annexe, même branche : la seconde lecture de la lightmap à la même adresse (`sol_iso.gdshader:157`) et `usure_mur_pres` (une lecture) ne sont plus payées sur le noir ; le pilote CSE peut-être la
seconde (non vérifiable). Optionnel, exact : descendre `dalle` (l. 142-145, ≈ 30 ALU-éq) dans la branche.

### 2.5 La fréquence, les appelants, le coût

- **Fréquence (PROUVÉ)** : à chaque image rendue, pour chaque fragment du sol et des faces, en vue isométrique (le défaut depuis ISO6 ; `--2d` ne passe pas ici). Vue unique (en ligne, entraînement, solo) : un sol ;
  écran scindé local : deux sols, chacun sur sa moitié (même surface totale). Chaîne d'appel : `Presentation3D._suivre` (matériaux, `presentation_3d.gd:795-835`) → GPU, une passe 3D par vue.
- **Coût recompté** (modèle § 1.3, pixel noir du sol) : chaîne sautée = température 38 (relecture 30 + 8) + usure 216 (`usure_mur_pres` 22, `usure_sol` 82, `usure_poids` 11, `pate_facteur` 101)
  + matière 101 + contact 105-150 = **460-505 ALU-éq**, contre ≈ 130 qui restent (prélude : matière mipmappée, glisse, dalle, première lecture). Rapport : 560 sur 690. Même ordre.
  Surface : 1,8-3 Mpx de sol × 75-95 % de noir ⇒ **0,6-1,4 G**. Faces : ≈ 0,12-0,18 Mpx noirs × 240-1 000 (la boucle d'impacts croît avec `usure_impacts_n` ≤ 48, donc avec la manche) ⇒ 0,03-0,18 G.
  Recoupement indépendant : l'usure SEULE coûtait +0,67 ms avant le levier 1 (ROADMAP l. 28419-28421, mesuré) ; la chaîne sautée en contient l'usure plus deux `pate_facteur` plus la température.
  **⇒ de l'ordre de la milliseconde (0,3-1,4 ms), ESTIMÉ.** À l'échelle : une fenêtre 1080p divise par 1,8.

### 2.6 Invariants

Noir absolu et équité : **intacts** (même octet, prouvé par construction ci-dessus ; à prouver à l'image, § 2.7). Lisibilité de la lumière : inchangée. Déterminisme des bancs : inchangé. Copie du masque de fumée
(`sol_ecrit`, `volume_masque.gdshaderinc:196-225`) : sa parité est TEXTUELLE (`test_iso_gadgets.gd:886-953`) et sa valeur ne change pas : aucune retouche. « Pièges connus » respectés : `textureGrad`
absent ; pas d'uniforme qui gouverne un chemin (ici la condition est une VALEUR, pas un uniforme) ; un shader qui ne compile pas paraît gratuit : § 1.4.

### 2.7 Statut et preuve

- **Statut** : NOUVEAU pour `sol_iso` et `mur_iso` (aucun refus, aucune décision). Le principe est déjà dans le dépôt : `volume_masque.gdshaderinc:244-251` (`if (l <= 0.0) return true;` puis le « noir sûr » à la ligne 248),
  `:341-358` (la bande des faces, ordre 417), `volume_masque_compact.gdshaderinc:116, 132` ; `lire_pied_lampe` (sortie en tête à gain nul, ROADMAP l. 27793) ; le mannequin (`if (mannequin >= 0.5)`, l. 28241-28246). La boucle d'impacts reste
  CONNU-OUVERT (l. 28413-28414, 28444-28445). **Chantier OMBRES** : OM6 (capteurs, halos, lumière de coup, murs par contours) ne recoupe pas ; **OM7** (« l'ombre des corps calculée dans le shader du sol »,
  `ROADMAP_branche_OMBRES.md` l. 33902, 34060) réécrira les mêmes lignes de `sol_iso.gdshader` : l'enveloppe est compatible (une ombre ne fait qu'assombrir) mais **la session OMBRES doit en être avertie** (par message
  inter-session, pas fait ici : lecture seule).
- **Verdict** : CONFIRMÉ AVEC RÉSERVE, **MAJEUR présumé**. **Correctif minimal** : l'enveloppe du sol + la ligne `usure_face` du mur (§ 2.4), pas les options 2 et 3. Effort **S-M** (trois gardes, deux forks).
- **Preuve dans le cloud** : (1) **identité à l'octet** par le protocole du levier 1 (§ 1.5) : un plan de `tools/banc_lumiere3d.gd` sur le modèle de `_serie_usure`, deux variantes du sol posées tour à tour sur le même matériau
  (`SANS_SORTIE_NOIRE` puis la sortie), temps figé, corps cachés, `--sans-led-murs` ou `--led-murs-fige`, impacts posés sur la face (`_la_planche_usure` du même patch) pour que la boucle tourne, lacet 0 et 45°, vue unique et
  écran scindé, **avec des pixels éclairés dans le champ** ; comparateur `compare_ab.py` ; **témoin positif** : usure allumée contre éteinte (des milliers de pixels) et une condition volontairement fausse
  (`c.r > 0.5`) qui doit être vue ; contrôle du noir absolu par `banc_iso.gd --jeu --capture --noir` ; (2) **compteur de pixels sautés** (§ 1.4) pour chiffrer le travail économisé ; (3) `tools/run_suites.sh` (les trois gardes) et
  une série `tools/cadence_cloud/serie.sh` en A B B A **seulement pour l'absence de régression et de `SHADER ERROR`** ; (4) le gain en ms **n'est démontrable que sur un GPU réel** — à écrire comme ESTIMÉ dans la ROADMAP.

---

## 3. SHA-05 — cinq lectures de lightmap inutiles sous le lavis

**1. Le code (PROUVÉ).** `sol_iso.gdshader:90-98` : `lx_0, lx_1, ly_0, ly_1` (quatre `lire_lightmap` × `ton_du_sol`) et `decalee` (une cinquième), calculées pour `pente` et `lumiere_decalee`. `pate()` (`iso_pate.gdshaderinc:255-318`) ne lit `pente`
que pour GRAVURE (l. 269) et LIGNE_CLAIRE (l. 288), `lumiere_decalee` que pour TRAME (l. 297) ; le lavis (l. 300-317) n'utilise ni l'un ni l'autre. La copie du masque de fumée le sait : elle appelle `pate(lu, l, style, px, vec2(0.0), l, aa)`
(`volume_masque_compact.gdshaderinc:131`). Elles sont déjà derrière `if (l <= 0.0) { return vec3(0.0); }` (l. 87) : seul le sol ÉCLAIRÉ les paie.

**2. La fréquence.** Par image, par pixel de sol non nul après le lavis (5 à 27 % du sol, § 1.2) ; en production `style` vaut 3 (lavis) (`presentation_3d.gd:203`). Même motif dans `lightmap_pateuse` (`iso_lightmap.gdshaderinc:74-90`), appelée par le dessus des murets
(`mur_iso.gdshader:208`, aucun muret en duel) et par le ruban de toile (`volume_iso.gdshader:234`, rare).

**3. Le coût.** « Vraiment inutilisées ou seulement inutiles visuellement ? » — **les deux, selon le niveau** : à l'exécution elles ne servent à rien en lavis ; pour le compilateur elles sont VIVANTES, car `style` est un
`uniform int` (`iso_pate.gdshaderinc:31`) : elles alimentent des branches que seul son contenu éteint. Le compilateur de Godot ne les retire pas (il ne connaît pas la valeur). Celui du pilote ne peut les supprimer comme code mort ; il pourrait au mieux
les descendre dans les branches consommatrices (opération sur des lectures de texture, dont le comportement dépend du pilote : *non vérifiable ici*). Recompté : 5 × (`lire_lightmap` ≈ 30 + `ton_du_sol` ≈ 14 + luminance 3) + pente ≈ 8 = **≈ 243 ALU-éq** par pixel éclairé (rapport : 215)
⇒ 0,02-0,2 G ⇒ **≤ 0,2 ms, ESTIMÉ, plus vraisemblablement ≈ 0,05 ms**. Observation voisine (nouvelle, même classe) : `TON_EXPOSANT := 0.0` (`iso_materiaux.gd:401`) rend `ton_du_sol` **identiquement 1,0** (`pow(x, 0) = 1`, `mix(1, 1, {0,1}) = 1`, exact) ;
il est pourtant évalué 6 fois par pixel éclairé (≈ 80 ALU-éq) parce que l'exposant est un uniforme.

**4. Invariants.** Nul pour l'image (pour le lavis, `pente` et `decalee` sont ignorées ; pour les pâtes A, B, C, le chemin est inchangé). `tools/test_banc.gd:329-350` exige la **même fonction au caractère près** dans `sol_iso_eclaire` (retouche miroir).
**Règle du dépôt** « un uniforme qui gouverne un chemin coûte même à 0 » (ROADMAP l. 4258-4269) : `if (style != PATE_LAVIS)` laisse les lectures dans le programme (registres, instructions) et paie un test par pixel ; la forme stricte serait `#ifdef` avec une variante pour
les pâtes de débogage (M, plus invasif : A, B, C n'existent qu'en build de débogage, `presentation_3d.gd:2259`). Pour un gain ≤ 0,2 ms, **le test d'uniforme suffit**.

**5. Statut.** NOUVEAU. Question ouverte du rapport n° 6 (retirer les pâtes A, B, C de la production) : décision d'Adrien, non nécessaire ici.

**6. Verdict.** CONFIRMÉ AVEC RÉSERVE (le diagnostic « mortes » est vrai à l'exécution, faux pour le compilateur), **MINEUR**. Correctif minimal : `pente = vec2(0.0); decalee = l;` puis `if (style != PATE_LAVIS) { …les cinq lectures… }` dans `lightmap_pateuse_sol`
(et son miroir dans `sol_iso_eclaire.gdshader:228` et `lightmap_pateuse`). Effort S. **Preuve** : même protocole que SHA-04 (§ 1.5), en bouclant `style` sur −1, 0, 1, 2, 3 (les quatre pâtes changent : chaque chemin doit rester identique). Aucune mesure de temps attendue du cloud.

---

## 4. SHA-02 — dix `Shader.new()` au premier allumage

**1. Le code (PROUVÉ).**

```gdscript
# iso_materiaux.gd:118-129
static func variante_definie(shader: Shader, nom: String) -> Shader:
	if shader == null or shader.code.contains("#define %s\n" % nom): return shader
	var cle := "%d:%s" % [shader.get_instance_id(), nom]
	if _variantes.has(cle): return _variantes[cle]        # cache STATIQUE : une fois par processus
	var v := Shader.new()
	v.code = code.substr(0, fin) + "\n#define %s\n" % nom + code.substr(fin)
```

Recomptage de la chaîne au premier `_couches(e, 4, FORME_POCHOIR, true)` (`iso_volumes.gd:702`) : `_materiau_volume(3, true)` → `_poser_forme_imposee` (`:1791-1793`) = `variante_masque(usure)` {FUMEE_MASQUE, USURE_ESSAI} + `variante_forme(·, 3)` {MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR}
+ FAISCEAU_LUMINEUX = **6 objets** ; puis le juge (`_poser_juge` → `_variante_juge_de`, `:1949, 1962, 2016-2024`) avec `forme_masque = 5` : `variante_forme(·, 5)` ajoute MASQUE_LUMIERE et MASQUE_AJUSTE (les trois premiers sont mémorisés), puis MASQUE_POCHOIR_JUGE et FAISCEAU_LUMINEUX_JUGE = **4 objets**.
**Total 10, dont 2 dessinés (la couche, le juge)** ; les 8 autres sont des étapes. Chacun relance le préprocesseur d'`#include` et l'analyse sur ≈ 1 584 lignes sources (V1b § 3.5).

**2. Quand ? (la question de la mission)** — **ni au démarrage, ni au décompte : à l'image où une torche s'allume pour la première fois du processus.** Chemin :
`Presentation3D._process` → `_suivre()` → `MiroirsIso.suivre` (`presentation_3d.gd:915`, `miroirs_iso.gd:175`) → `IsoVolumes.suivre` (`iso_volumes.gd:409` ; l'instance naît avec les miroirs, `miroirs_iso.gd:65`) → `_suivre_faisceau_air(j, vus)` (`:443`, `:686`), qui **retourne avant `_couches`** tant que `lampe == null or not lampe.enabled or lampe.energy <= 0.0 or lampe.texture == null` (`:694-695`).
Le code sait déjà ne pas payer à cette image : « l'enveloppe du cookie et les éventails se calculent dès que le joueur est là (au décompte, lampe éteinte) … jamais à l'image où la lampe s'allume » (`:688-691`) — mais **il ne fait pas la même chose pour les variantes de shader**. Les deux joueurs sont suivis
(`for j in [p1, p2]`) : la première torche allumée, **celle de l'adversaire comprise**, déclenche la chaîne sur la machine de celui qui la voit. Aucun autre appelant ne la précède dans une manche de base : `_suivre_toile`/`_suivre_gadget` n'existent qu'avec un gadget posé ; `variante_juge` n'est appelée nulle part ailleurs
que par `_variante_juge_de` (grep). **Mis en cache ?** Oui : `_variantes` est un `static var` ; les allumages suivants (et les manches suivantes) ne paient rien. Donc : un coût **par processus**, pas par manche.

**3. Le coût.** **À MESURER.** SHA-02 écrit « 10-30 ms ESTIMÉ » et V1b « 1-15 ms chacun, 10-150 ms au total » : aucun des deux ne repose sur une mesure. *Connaissance du moteur* : `Shader.code =` lance le préprocesseur (CPU, y compris en headless) puis, avec un vrai rendu, l'analyse du langage
et la génération du GLSL ; la compilation du **programme GL** n'a pas lieu là mais au premier dessin des deux shaders finaux (SHA-01 ; mesure du dépôt : 143-150 ms par sorte de lampe 3D sur le Mac, ROADMAP l. 27613-27622 — des shaders différents, le juge de fumée étant bien plus gros :
≈ 14 600 instructions GLSL selon `volume_masque_compact.gdshaderinc` en-tête). **Nuance sur le « piège connu »** : la règle du dépôt (« préchargé ») n'évite que l'analyse CPU ; le programme GL se compile au premier dessin, préchargé ou non (ROADMAP l. 22509-22513). SHA-02 est la moitié CPU du hoquet, pas le hoquet.

**4. Invariants.** Image : nul (mêmes sources). Garder le piège « une variante n'est pas le même shader pour qui filtre par identité » (ROADMAP l. 4086-4092 ; `_formes_posees[mat.shader]` et `_shader_masque` posés sur les shaders FINAUX, `iso_volumes.gd:1769-1770, 1794, 1951, 1962`) : composer les `#define` en une passe doit rendre **les mêmes objets finaux** à
chaque appel (clé `id:noms`) et ne rien changer au filtre de `_pousser_lightmaps`. Les gardes lisent `#define X\n` par `contains` (indépendant de l'ordre). V1b propose `variante_definies(shader, [noms])` : 2 shaders au premier allumage au lieu de 10 (4 sur le processus avec la fumée).

**5. Statut.** NOUVEAU. Le défaut est l'application à `volume_iso` du « piège connu » de CLAUDE.md (`Shader.new()` à la volée), au sens CPU ; la marque d'attention du dépôt (`presentation_3d.gd:2233-2234`) ne couvre que les shaders préchargés, pas les variantes.

**6. Verdict.** CONFIRMÉ AVEC RÉSERVE (structure et moment établis, ampleur non mesurée), **MINEUR** — mais **sur le même frame que le hoquet GL de SHA-01 (MAJEUR présumé)**, donc à traiter dans le même geste : toute chauffe GL de SHA-01 devra de toute façon instancier ces variantes pendant le décompte ; elle rend
SHA-02 gratuit si elle est faite. **Correctif minimal** : `variante_definies` (une passe) + pré-création des variantes finales à côté de `IsoNuageVoxel.prechauffer()` (`iso_volumes.gd:343`, dans `_init()` de `IsoVolumes`). Effort S. **Preuve dans le cloud** : (1) **compteur indépendant du matériel**, test headless : `IsoMateriaux._variantes.size()`
(ou le nombre de `Shader.new()`) après le premier `_couches` et après `_poser_juge` : 10 aujourd'hui, 2 après ; (2) **chronomètre** `Time.get_ticks_usec()` autour de la chaîne sous Xvfb (trois lignes, V1b § 6) pour lever le « 1 ms ou 15 ms » ; (3) la durée de l'image d'allumage sous llvmpipe
(`prise.sh` date chaque image, `--seuil-lent 1`) avant/après : indicative seulement.

---

## 5. SHA-08 — la zone morte des murets dans `light()` du sol

**1. Le code (PROUVÉ).** `murs_bas_sol.gdshader:12-19` : `light()` appelle `mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)` pour chaque couple (fragment, lumière) puis écrit l'éclairage par défaut. Pour une torche (`source.z = 0`) : `source.z >= mb_z_sans_origine` (faux), `par_hauteur` faux, `mb_zone_morte <= 0` **faux — `poser_sol` pose `l_sol`
> 0 même sans mur** (`murs_bas_rendu.gd:132, 155, 164-166, 176-185`), donc le prologue `length(cible − src)`, `borne`, `borne2` s'exécute (≈ 20 ALU-éq), puis la boucle `for (i < mb_nb_murs)` de 0 tour. `game_state.gd:5982-5985` sait que `murs_bas.is_empty()` (une seule poussée). Le bandeau de LED (`z >= mb_z_sans_origine`) sort au premier test.

**2. La fréquence.** Par image et par couple (fragment, lumière) de chaque item de sol de la lightmap de la vue (`CustomFloor_P1/P2`, `game_state.gd:1512` ; un seul actif en vue unique). Le nombre de lumières par fragment est celui des lumières dont le rectangle touche l'item (plafond moteur
15 par item, CONTEXTE), pas celui qui éclaire le pixel : *connaissance du moteur, non relue ici*.

**3. Le coût — (a) sans muret.** Duel : LED (≈ 3) + 1,5 lumière non-LED en moyenne dans les quadrants proches des joueurs (≈ 20 chacune) ⇒ 2,07 Mpx × 33 ≈ **0,07 G ⇒ ≈ 0,05-0,1 ms** (ESTIMÉ ; rapport : 0,15-0,3 G, qui suppose 3 à 5 lumières non-LED partout). **La mesure de MB3c ne dit rien de plus** : `docs/MURS_BAS.md:535-547` (« ordre de grandeur, pas un relevé au protocole », trois tours entrelacés) donne « aucun mur 5,19 ms
(bruit : 4,07 au meilleur tour) », « 5 murs 4,47 ms » ; la carte à 5 murs fait strictement PLUS de travail que « aucun mur » et mesure MOINS : la première valeur est du bruit, et l'effet de (a) est ≤ 4,47 − 4,30 = 0,17 ms. En solo (≈ 15 lumières : PNJ, plafonniers ; 82 niveaux sur 100 sans muret) :
2,07 Mpx × (3 + ≈ 8 × 20) ≈ 0,3 G ⇒ **jusqu'à ≈ 0,3 ms** (ESTIMÉ ; dépend de OM3/OM4/OM6, qui réduisent le nombre de lumières). **(b) avec murets** : **recompté**, 18 niveaux d'aventure sur 100 ont des murets (`v9_work/muretsl.py`) : 44 rectangles (`chapitre_07/niveau_08`),
37 (`chapitre_09/niveau_07`), 10, 6, 4… ; **les six cartes de duel : 0** (confirmé). **Dans le champ de la vue + L, à toute position de caméra** (`v9_work/muretsl_vue.py`, zoom ×1,5 : 1 280×720) : 40-44 rectangles pour le premier niveau, 28-36 pour le second, 10 pour le troisième ; à ×1,0, tous. Le coût mesuré est
**+4,2 ms (8,69 contre 4,47) à 40 murets « serrés à l'écran », 2560×1440, écran scindé, torche allumée** — deux lightmaps ; la vue unique iso n'en rend qu'une ⇒ **≈ +2 ms, ESTIMÉ, jamais mesuré**.

**4. Invariants.** (a) : `murs_bas_sol.gdshader` annonce « 0/255 d'écart avec l'ancien matériau hors zone », vérifié au banc (`MURS_BAS.md` § 11) ; l'image est identique. Test à revoir : `test_iso_gadgets.gd:251` et `test_iso_murs_bas.gd:178` lisent `main._materiaux_zone_morte[pid]` (le garde `sol.material is ShaderMaterial`, `game_state.gd:1547`, a déjà prévu un sol sans
`ShaderMaterial`) ; sur une carte sans muret la liste ne contiendrait plus que le décor, et `not mats.is_empty()` suppose qu'il existe. `banc_murs_bas.gd:111, 252` (carte d'essai avec murets) : inchangé ; `test_murs_bas_rendu.gd` appelle `materiau_sol()` directement : inchangé. `peinture_iso.gd:254-274` repose son propre matériau : indépendant. (b) : la règle des murets est de
l'équité (« un même angle », Adrien, 2026-09-14) : toute structure qui évite de tester 64 murs par couple se prouve à 0/255 par `banc_murs_bas.tscn`.

**5. Statut.** (a) NOUVEAU ; (b) CONNU-OUVERT (ROADMAP l. 30046-30048, `MURS_BAS.md:535-547` : « loin de la cible »). **OMBRES** : OM5 (plafonniers : « une ombre finie calculée dans le matériau, comme la zone morte des murets ») peut étendre `mb_dans_la_zone_morte` ; OM6/OM3/OM4 changent le nombre de lumières donc l'échelle de (a) : **coordonner**, ne pas dupliquer.

**6. Verdict.** (a) **CONFIRMÉ AVEC RÉSERVE, ANECDOTIQUE à MINEUR** ; (b) **CONNU-OUVERT confirmé, MAJEUR localisé** (2 niveaux sur 100, jamais un duel). **Correctif minimal (a)** : `floor_layer.material = MursBasRendu.materiau_sol() if not murs_bas.is_empty() else <CanvasItemMaterial additif>` (`game_state.gd:1512`, idem le décor `:1551`) ; `murs_bas` est posé en `:1497`, avant. Effort S. **Pour (b)** : rien de petit ;
conception d'une structure exacte (L), à ouvrir seulement si Adrien veut ces deux salles. **Preuve dans le cloud** : (a) A/B à l'octet par le protocole § 1.5 sur une carte SANS muret (matériau-shader contre `CanvasItemMaterial`), et **ici une prise llvmpipe est valide** (on retire du code, pas un branchement) ; (b) `tools/banc_murs_bas.tscn` (40 murets) + `cadence_cloud`, relatif seulement.

---

## 6. SHA-10 — douze lectures par face, dont huit pour une moyenne

**1. Le code (PROUVÉ).** `mur_iso.gdshader:140-143` : `lire_lumiere_moyenne` = 4 × (`lire_lightmap` + `texture(peinture)`) = 8 lectures ; `:194-195` : `lire_etalon(peinture_etalon_px)` et `lire_etalon(peinture_plancher_px)` = 2 lectures **pour chaque fragment du shader, y compris les dessus noirs**, « hors de tout branchement ». `lambert_plancher` vaut 1,0
(`iso_materiaux.gd:376`) : les 4 lectures du Lambert ne tournent pas. La raison d'être des quatre prises (« les hachures d'encre du pied », l. 95-101) a bien disparu : `mur_encre.gd:51-61` — « le pied du mur est un LAVIS, plus une bande de hachures », qui finit à 10,5 px, avant les 12 px de lecture.

**2. La fréquence.** Par image, par fragment de face verticale (8) et de tout fragment du mur (2). **3. Le coût.** ≈ 0,3 Mpx × 8 + 1,4 Mpx × 2 ≈ 5 M de lectures de texture par image : **≤ 0,05 ms** (ESTIMÉ ; à ces débits de texture, de l'ordre de 0,03 ms). **ANECDOTIQUE.**

**4. Invariants — deux corrections.** (a) Les étalons ne se déplacent pas en uniformes à la légère : ils sont lus **dans la texture de la peinture elle-même pour rester dans son espace de couleur** (`mur_iso.gdshader:111-115` : « une référence calculée côté processeur en linéaire assombrissait les faces de six fois, troisième passage en jeu »). Les descendre dans la branche qui les utilise est exact ;
les relire côté CPU ne l'est pas. (b) Réduire les prises **change l'image** (l'argument du rapport) ; et la division par la peinture (`lire_lumiere`, `:125-136`) retire déjà le dessin du sol, y compris l'encre du pied (`peinture_iso.gd:57` peint `MurEncre_P1`) : ce que les quatre prises lissent encore (ombres, bords de lumière) est à juger sur `banc_iso_beaute`.
**5. Statut** NOUVEAU. **6. Verdict** CONFIRMÉ AVEC RÉSERVE, **ANECDOTIQUE**. Correctif minimal : aucun (ou (a) descendu dans les branches, exact, pour ≈ 0,03 ms). (b) : décision d'Adrien sur planche. Preuve : protocole § 1.5 pour (a) ; (b) à l'œil.

---

## 7. SHA-11 — sommets des nuages voxel, et le juge

**1. Le code (PROUVÉ).** `nuage_voxel_iso.gdshader:564-647` : `vertex()` calcule `cube_de(c)` pour **chacun** des sommets d'un cube (l. 568, mêmes `c` pour les 12), puis, pour un cube plein non caché, `cube_de(voisin)` (l. 584-590) ; la branche `encre_style == 1` (arêtes, l. 640) n'est pas prise par défaut (`encre_style` = 2) : **2 `cube_de` par sommet** au plus, 1 pour un cube vide ou petit.
`bouffees` : 12 `sin` en fbm pour la fusée (`clarte_du_voile`) ou 2 `pate_bruit` (8 `sin`) sinon ; `lumiere_lissee` : 9 lectures ; `pate()`. **Comptes recalculés** par le code de `IsoNuageVoxel.cellules` (`iso_nuage_voxel.gd:387-400`, rayon 250, 4 rangées de 8,75 px) : **9 136 cellules, 109 632 sommets** à 12 par cube (lacet 45°, 3 faces) ;
**73 088** à 8 par cube (lacet 0°). Exact. Le juge : `iso_volumes.gd:1677` `r := rayon × 1,05 + voxel + 0,13 × haut + 3`, puis `:1680` `scale = 2 × (r + haut)`, disque à 16 côtés (`FORME_AJUSTEE`).

**2. La fréquence.** Par image, par fusée posée (et par nuage de gadget : suie, poussière) et par vue ; une fusée dure quelques secondes, **en événement**. **3. Le coût.** 500 ALU-éq × 109 632 ≈ **0,055 G par vue** (ESTIMÉ) ⇒ ≈ 0,05 ms, ×2 en écran scindé : **négligeable sur le M3**, confirmé par le rapport. Le temps llvmpipe du dépôt (« voxels gros × 0,92 de temps d'image
contre les couches », ROADMAP l. 31262-31280) ne dit rien des sommets (« ce qu'aucun banc du cloud ne peut dire », l. 31299-31302).

**4. Invariants.** Resserrer le juge touche le **noir absolu** : un disque qui laisse un fragment de cube hors du pochoir laisse de la fumée sur du noir. Preuve : `loupe-fusee-masque-preuve` (A sans fumée, B fumée, C masquée, A'). **5. Statut — ce qui reste à faire** (ROADMAP l. 31282-31283, 31299-31302), vérifié contre le code : (i) « un disque plus serré (le rayon du nuage plus un demi-cube, au lieu de 5 % de marge) » **n'est pas fait**
(`:1677` est inchangé) ; gain plafonné : r de 1,05·250 + 8,75 + 0,13·35 + 3 ≈ 279 → ≈ 254 px (demi-cube), aire du disque −15 %, et la part du juge est 71 % des fragments (842 803 / 1 193 452) ⇒ **≤ 11 % des fragments du nuage** ; (ii) mesurer les sommets sur le pilote d'Apple : **jamais fait, impossible dans le cloud** ; (iii) le hoquet de la première compilation du shader
du nuage : SHA-01 ; (iv) précalculer l'état des cellules dans une texture (option L du rapport) : **non justifié** à 0,05 ms.
**6. Verdict.** CONFIRMÉ (chiffres), reste CONNU-OUVERT, **ANECDOTIQUE sur la machine de référence** (MINEUR à surveiller sur iGPU ou avec plusieurs fusées, à vérifier : le nombre de fusées simultanées). Correctif minimal : aucun. Si on resserre le juge : `tools/banc_gadgets_volume.gd --mode=cout` donne les fragments (hors matériel) et la preuve du noir se fait à l'octet.

---

## 8. SHA-13 — le hash `fract(sin())`

**1. Le code (PROUVÉ).** Trois copies GLSL du même hash (`iso_pate.gdshaderinc:46-48`, `fumee_fusee.gdshader:49-51`, `nuage_voxel_iso.gdshader:246-248` (`voile_valeur`, sous `#ifdef NUAGE_FUSEE`)) et un miroir processeur (`iso_pate.gd:49-50`, double précision). Le lavis appelle `pate_bruit` deux fois (`iso_pate.gdshaderinc:301-302`) = 8 `sin` ; l'usure du sol cinq ; l'usure d'une face 17 et plus. **Alternative déjà dans le dépôt** : `menu_hatch.gdshader:67-71`.

**2. La fréquence.** Par image, par pixel éclairé (lavis, usure) et par fragment de face ; les nuages, par sommet. **3. Le coût — le point que le rapport n'a pas compté.** Le hash de Hoskins (`menu_hatch`) compte `fract(vec3 × c)` 6 + `dot(p3, p3.yzx + 33,33)` 3+3 + `p3 +=` 3 + `fract((p3.x+p3.y)·p3.z)` 3 = **≈ 18 opérations** ;
le hash à `sin` = `dot` 2 + `sin` + ×43758 + `fract` = **5 instructions (≈ 8 ALU-éq avec `sin` à 4)**. Remplacer les 13 hachages d'un pixel éclairé (lavis 8 + usure 5) : 13 × 5 = 65 instructions (13 × 8 = 104 ALU-éq avec `sin` à 4) deviennent 13 × 18 = 234, soit **≈ +130 ALU-éq par pixel éclairé** : **aucun gain de temps démontré, plutôt une perte**, sauf à ce qu'un `sin` coûte plus de ≈ 18 instructions sur un GPU donné — ce que je ne sais pas (ESTIMÉ, à mesurer). La seule justification est la portabilité.

**4. Invariants — c'est une décision d'Adrien, pas une optimisation.** *Estimation de la non-portabilité* : l'argument `dot(i, (127,1 ; 311,7))` atteint ≈ 3·10⁴ (lavis grande échelle) à ≈ 2·10⁵ (grain à `motif/3`), où l'ulp fp32 vaut 0,002 à 0,016 rad ; une différence de contraction `fma` ou une `sin` à réduction d'argument imparfaite, multipliée par 43 758, change toute la fraction. Plausible, **non vérifié** (aucun deuxième GPU ici).
Conséquences : l'usure, le grain du lavis, la forme des cubes diffèrent d'un GPU à l'autre ; aucune règle de jeu (la visibilité vient du modèle processeur) ; les bornes du juge de fumée (`lavis_q(l, 0/1)`, grain dans [0,82 ; 1[) valent pour tout hash dans [0,1[ : **elles ne dépendent pas de lui**. **Remplacer le hash CHANGE l'image** (les seuils de bande `e_i = s_i + k_i·b` et le grain se déplacent : le liseré entre noir et première bande, et l'usure) : à voir sur planche par Adrien.
Il faudrait aussi refaire le miroir `iso_pate.gd`, les trois copies, et tout test qui lit leur texte (`test_fumee_voxel.gd:308-345`, `test_nappes_voxel.gd:576`, `test_allegement_faisceau.gd:144`, `test_iso_gadgets.gd:959`). Si Adrien veut la portabilité, **un hash entier** (`uint`, PCG) est exact sur tous les GPU et reproductible côté GDScript, mais change l'image comme tout autre.
**5. Statut** NOUVEAU. **6. Verdict.** CONFIRMÉ AVEC RÉSERVE comme risque de portabilité (ESTIMÉ) ; **RÉFUTÉ comme gain de performance** ; **MINEUR**. Correctif : aucun sans décision d'Adrien. Preuve : sur planche (`banc_iso_beaute`, cadrage e1) ; deux machines pour la portabilité (inaccessible au cloud).

---

## 9. SHA-12 — le code mort préchargé : la liste

Confirmée par lecture : `presentation_3d.gd:107-117` précharge `SHADER_SOL_ECLAIRE`, `SHADER_MUR_ECLAIRE`, `SHADER_CORPS_ECLAIRE`, `LumieresIsoT` (le script, l. 111), `SHADER_PATE_ECRAN`, `SHADER_PATE_VUE`, `SHADER_CORPS`, `SHADER_CORPS_PROFONDEUR`. Atteignables **seulement** par `poser_lumiere_3d(true)` (`presentation_3d.gd:1979` ; rappelée en `:636-637` derrière `_lumiere_3d_voulue`,
que seule cette fonction pose) — appelée par `tools/banc_lumiere3d.gd`, `banc_lumieres.gd`, `bench_framerate.gd`, `photographe.gd`, `test_lampe_modele.gd` (grep) —, ou par des drapeaux de débogage (`--corps-grossiers`, `presentation_3d.gd:250, 472`). **Aucun drapeau de lancement ne les allume en production.**

| Fichier | Lignes | Rôle |
|---|---|---|
| `sol_iso_eclaire.gdshader` | 391 | fork 3D du sol (lumière 3D) |
| `mur_iso_eclaire.gdshader` | 418 | idem, murs |
| `corps_iso_eclaire.gdshader` | 418 | idem, corps |
| `iso_relief.gdshaderinc` | 307 | inclus par les trois forks seulement |
| `lumieres_iso.gd` | 410 | le miroir des sources (instancié `presentation_3d.gd:2012`, dans `poser_lumiere_3d`) |
| `corps_grossier_iso.gdshader` | 126 | cylindres d'ISO1 (`--corps-grossiers`) |
| `corps_profondeur_iso.gdshader` | 37 | **identique hors commentaires** à `corps_iso_profondeur.gdshader` (40) — vérifié par `diff` |
| `pate_ecran_iso.gdshader` / `pate_vue_iso.gdshader` | 22 / 16 | pâte (b), lumière 3D + `variante_pate_3d == 2` |
| **total** | **2 145** | |
| `distorsion_eblouissement.gdshader` | 33 | **orphelin** : seule mention = un commentaire (`voile_eblouissement.gdshaderinc:235`) |

**Verdict** CONFIRMÉ, **ANECDOTIQUE** (démarrage ≈ −10 à −20 ms ESTIMÉ, une fois ; aucune compilation GL économisée). Remarque qui compte pour SHA-04/05 : les forks ne sont pas inertes pour les suites — `test_banc.gd:325-392` et `test_iso_usure.gd:20-21` (listes `MURS`, `SOLS`) les gardent ligne à ligne ; **tout correctif de `sol_iso`/`mur_iso` doit les recopier ou les retirer d'abord**.

---

## 10. Corrections apportées aux rapports d'origine

1. **SHA-04** — « image strictement identique pour 1 et 2 » : faux pour 2 (§ 2.2). « Risque : nul ; garde `test_banc.gd` » : incomplet (trois gardes, deux indentation-sensibles, § 1.6). « 73 % noir » : borne basse ; mesure du dépôt sur l'écran entier : 73-98 % (§ 1.2). Statut « NOUVEAU » : vrai pour `sol_iso`/`mur_iso`, mais le principe est dans le masque de fumée et y a été mesuré sans effet.
   Gain : 560 ALU-éq par pixel noir recomptés à 460-505 ; la fourchette de ms est conservée en ordre de grandeur, **non démontrable dans le cloud**.
2. **SHA-02** — « 10-30 ms » : sans base. « Au démarrage, au décompte ou à l'allumage ? » : **à l'allumage de la première torche du processus** (adverse comprise). Le « piège connu » n'est que la moitié CPU du hoquet.
3. **SHA-05** — « le compilateur GLSL peut les éliminer ? » : non, `style` est un uniforme ; elles sont mortes à l'exécution, vivantes pour le compilateur. 243 ALU-éq par pixel (rapport : 215). Voisin non vu : `ton_du_sol` est identiquement 1 avec `TON_EXPOSANT = 0`, évalué 6 fois.
4. **SHA-08** — « (a) 0,15-0,3 G » : ≈ 0,07 G en duel (la plupart des fragments ne voient que la LED) ; la mesure de MB3c « aucun mur 5,19 » est du bruit (la carte à 5 murs mesure moins). « 37-44 murets » recomptés exacts, **et presque tous dans le champ à toute position de caméra**.
5. **SHA-10** — les étalons ne se remplacent pas par des uniformes CPU (piège payé de la peinture).
6. **SHA-13** — « retire 10 à 17 transcendantes » : vrai, mais le remplaçant coûte plus cher : **pas d'optimisation**.
7. **SHA-11** — les comptes (9 136 / 109 632) sont exacts ; ajout : 73 088 sommets à 0°.

## 11. Ce que je n'ai pas pu établir (à mesurer, ou à décider)

1. **Le temps gagné par SHA-04/05 sur un GPU réel** : ni le cloud (llvmpipe, § 1.4) ni le Mac (plus mesuré) ne le donnent. À écrire comme ESTIMÉ ; le compteur de pixels (§ 1.4) chiffre le travail, pas le temps.
2. **La part de noir exacte à l'écran** (§ 1.2) : le compteur de banc, 5 minutes.
3. **Si Mesa 25.2 saute un `if` entièrement masqué** (§ 1.4) : la prise A B B A le dira, sans engager le Mac.
4. **Le coût CPU de `Shader.code =` sur 1 584 lignes** (SHA-02) : trois lignes sous Xvfb.
5. **Le nombre de lumières par item dans les salles de solo** (SHA-08 a) : à compter avec le banc solo de OM6.
6. **Décisions d'Adrien** : SHA-13 (changer le bruit du lavis ? un hash entier reproductible ?), SHA-10 b (réduire les quatre prises ?), SHA-05 question 6 (retirer les pâtes A-C de la production).
7. **Annoncer à la session OMBRES** (OM5, OM7) qu'un correctif SHA-04/SHA-08 touche `sol_iso.gdshader` et `murs_bas_*` : par `SendMessage`, pas fait ici.
