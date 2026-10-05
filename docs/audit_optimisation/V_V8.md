# V8 — Les lumières, l'éblouissement et le brouillage : vérification contradictoire (2026-10-05)

Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12). Rôle : contradicteur. **Lecture seule ; Godot n'a pas été lancé ; aucun fichier du
dépôt n'a été touché.** Rapport source : `audit/04_LUM_lumieres.md` (blocs complets lus, plus `lum/*.py`). Doublons lus en entier : `03_SHA` (SHA-03, SHA-06, SHA-07),
`09_HUD` (HUD-04, HUD-08), `06_ETA`/`12_BOT` (ETA-05, BOT-10), et les verdicts déjà rendus `V_V1a` (HUD-08), `V_V1b` (ETA-05 + BOT-10, ISO-09 = SHA-01), `V_V2` (HUD-04),
`V_V5` (GAD-12). Contexte lu : `CONTEXTE_CHANTIERS_EN_COURS.md` et, dans `ROADMAP_branche_OMBRES.md`, la section OM (l. 33869-34163).

**Ce que j'ai fait de plus que relire le dépôt : lire le moteur.** Les constats LUM reposent presque tous sur « ce que fait Godot 4.7 » ; les auditeurs l'écrivaient « de mémoire ». J'ai
lu les sources du moteur à l'étiquette **`4.7-stable`** (`raw.githubusercontent.com/godotengine/godot/4.7-stable/…`, copies dans `audit/v8_work/godot47/`) : culling des lumières 2D, passe
d'ombre GLES3, copie d'écran, `PointLight2D.offset`, atlas des textures de lumière, lecture GPU des textures. Chaque fait de moteur ci-dessous cite son fichier et ses lignes ; les
numéros de ligne du jeu sont ceux de `52a29c1`. Étiquettes : **PROUVÉ** = lu dans le code (jeu ou moteur) ou calculé hors jeu ; **ESTIMÉ** = raisonné ; **à mesurer** = personne ne sait.

---

## 0. Verdicts d'un coup d'œil

| Constat(s) | Verdict | Sévérité corrigée | Coût corrigé | Statut |
|---|---|---|---|---|
| **LUM-01** (flou + copie + halo permanents) | **CONFIRMÉ** (mécanisme PROUVÉ) ; coût NON ÉTABLI | **MINEUR** (MAJEUR si la coupure de passe pèse ≥ 0,3 ms) | 0,1-0,4 ms ESTIMÉ (une coupure de passe plein cadre) ; les deux quads et la copie RECT pèsent < 0,05 ms | NOUVEAU comme coût ; **tombe de lui-même avec Q81(a) si le plancher est posé dans `Brouillage._dose`** |
| **LUM-02 + HUD-04 + SHA-03** (voile « calme » complet au repos) | **CONFIRMÉ** pour l'existence ; coût NON ÉTABLI | **MINEUR, à mesurer** (V2 l'avait déjà rabaissé) | 0,05-0,7 ms GPU à 2560×1440, ÷ 4 à 1280×720 ; **nul si le duel est lié au CPU** | CONNU-OUVERT (l. 16993, périmé en partie) ; **ne tombe PAS avec Q81(a)** |
| **LUM-03** (passe d'ombre × capteurs, solo non mesuré, `p2` caché) | **CONFIRMÉ AVEC RÉSERVE** ; leviers DÉJÀ PRIS EN CHARGE (OM6) | MAJEUR présumé, **à mesurer** | modèle surestimé : **× 0,79 (duel), × 0,65 (solo)** en dessins ; 0,3-1,9 ms duel, 0,6-2,0 ms solo médian ESTIMÉ | CONNU-OUVERT, titulaire OMBRES ; le modèle chiffré est NOUVEAU mais partage l'unique ancre d'OMBRES |
| **LUM-04** (rect carré 936² des torches, cookies rognés + `offset`) | **CONFIRMÉ AVEC RÉSERVE** (géométrie et moteur PROUVÉS) | MAJEUR potentiel (effort L, risque élevé) | −30 % (duel) / −50 % (solo) de dessins d'ombre, ±6 points avec le test d'AABB du moteur ; **plus** : atlas des lumières 32 → 4 Mio (D1) | **NOUVEAU** par rapport à OM6 |
| **LUM-05** (shaders flou/voile + copie jamais préchauffés) | **CONFIRMÉ AVEC RÉSERVE** | MINEUR | une fois par processus : compilation ESTIMÉE 10-50 ms + allocation du back-buffer 1-5 ms ; **à livrer avec LUM-01** | CONNU-OUVERT (l. 22510 ; V1a HUD-08 ; V1b SHA-01) |
| **LUM-06 + SHA-07** (`filter_linear_mipmap` sur l'écran) | **CONFIRMÉ par le moteur** (chaîne gaussienne de 5-6 passes à chaque copie) ; coût à mesurer ; image *quasi* identique | MINEUR | 0,1-0,4 ms ESTIMÉ pendant les éblouissements ≥ 0,12 et la killcam | NOUVEAU |
| **LUM-07** (`image_torche()`) | **= ETA-05 (a) = BOT-10**, vérifié par V1b | MINEUR (bas) | 0,5-5 ms, une fois par classe, hôte/local seulement | cité, non refait |
| **LUM-08** (murs par contours) | **DÉJÀ PRIS EN CHARGE** (OM6, 4ᵉ puce) | MINEUR | −40 % d'occulteurs de mur (duel), −36 % (solo) : recompte reproduit | CONNU-OUVERT, titulaire OMBRES |
| **LUM-09** (halos sans récepteur) | **DÉJÀ PRIS EN CHARGE** (OM6, 2ᵉ puce) — **solo compris** | MINEUR | ≤ 0,14 ms (duel, ROADMAP) ; ≈ 0,9 ms sur 3 en solo (OMBRES) | l'auditeur disait « NOUVEAU pour le solo » : **faux** |
| **LUM-10** (`hit_light` par plomb) | **CONFIRMÉ** (mécanisme) ; recoupe OM6 et OM4 | ANECDOTIQUE (pompe au contact seulement) | ≤ 0,1-0,7 ms pendant 1 s ; le coût dominant est la DURÉE de l'ombre (OM6) | NOUVEAU pour l'empilement ; ROADMAP 2506 prémisse fausse pour la pompe |
| **LUM-12 + SHA-06** (vignette de dégâts à alpha 0) | **CONFIRMÉ** | ANECDOTIQUE | 0,02-0,1 ms GPU + 1 appel de dessin ; **viole une règle écrite** (l. 6871) | NOUVEAU |

Quatre faits **non demandés** sortis de cette lecture, qui changent la lecture de plusieurs constats (détail § 3) :
**D1** l'atlas des textures de lumière du moteur est reconstruit en entier à chaque ajout d'une texture inédite — le flash de bouche en provoque jusqu'à deux **par tir** ;
**D2** `source_eblouissante` n'existe que chez l'hôte : **chez le client, le halo et le flou de repos se posent sur l'ADVERSAIRE** (équité, non vu à l'image) ;
**D3** le moteur ne dessine pas un item dont `modulate.a < 0,007` : on peut éteindre un `ColorRect` d'`HBoxContainer` sans toucher la mise en page ;
**D4** deux défauts de modèle dans les chiffres d'ombre : l'AABB du rect tourné, et les masques d'ombre (le moteur ne dessine pas tous les occulteurs pour chaque lampe).

---

## 1. Qui pilote quoi — la question Q81, établie variable par variable

*(Demandé : « Si Adrien dit oui à Q81(a), le flou permanent de LUM-01 tombe-t-il de lui-même ? Et le voile de LUM-02 ? Quelles variables pilotent chacun ? »)*

### 1.1 La valeur de repos

Le niveau d'un joueur dont la torche brûle et que rien n'éblouit vaut **exactement** `Eblouissement.RETRODIFFUSION × gain_taille(rayon) × facteur_de_lampe_a(pos)` :
`eblouissement.gd:174` (0,06), `eblouissement.gd:199` (`EXPOSANT_TAILLE := 0.0` ⇒ `gain_taille` = 1,0), `game_state.gd:2565-2574` (le « cas de soi » : `src["porteur"] == cible`,
retour avant tout échantillonnage du cookie). Le facteur de lampe vaut 1 sauf suie/grésillement (il ne peut que baisser la valeur). `Eblouissement.integrer` (l. 127-131) y monte à
1,25/s (**48 ms**) et en redescend à 2,67/s (**22 ms**). Donc : **0,06 pile, dès l'allumage, tant que la torche brûle** ; 0,06 est un *maximum* de repos, jamais un minimum.
Deux nuances de robustesse : si `EXPOSANT_TAILLE` passait un jour à 0,5 (« un commit à part », l. 187-199), le repos monterait jusqu'à 0,12 (gain ≤ 2) et un plancher câblé à 0,06 laisserait un
résidu ; et le client reçoit `net_dazzle` (flottant répliqué, `player.gd:617`), à comparer avec une marge (`≤ 0,06 + 1e-3`), pas à l'égalité stricte.

### 1.2 Les consommateurs de `dazzle_amount` (liste exhaustive des scripts de la racine)

| Effet | Ce qu'il lit | Où | Se déclenche quand | Valeur à 0,06 |
|---|---|---|---|---|
| **Flou** + `BackBufferCopy` (LUM-01) | `Brouillage.flou(d)` = `{rayon: 190·D, force: D}`, `D = clamp(clamp(d,0,1)·GAIN, 0, 1)`, **GAIN = 2,0 en dur** (`brouillage.gd:605`, non réglable) | `brouillage_vue.gd:193, 227-231` | visible ⇔ `190·D > 2` **et** `D > 0,001` ⇔ **d > 0,00526** | D = 0,12 → rayon 22,8 px, force 0,12 |
| **Halo** (LUM-01) | `Brouillage.halo(d)` = `{rayon: 150·D, intensité: 0,7·D}` | `brouillage_vue.gd:266-268` | visible ⇔ `150·D > 1` ⇔ **d > 0,00333** | rayon 18 px, alpha **0,084** (≈ 21/255 au centre) |
| **Opacité du corps adverse** (O2/Q81) | `Brouillage.opacite(d)` = `(1 − D)^3,4` | `player.gd:1915-1923` | toujours évaluée | **0,648** |
| Fantômes, dérive, rémanence | `Brouillage.fantomes/derive/retard(d)` | `brouillage.gd:411-453` | toujours évaluées | non branchées en jeu (banc) |
| **Voile « calme »** (LUM-02) | `niveau = clamp(d,0,1) × EffectPolicy.curseur("eblouissement")` — le curseur est de la famille MONDE : **1,0, non réglable** (`effect_policy.gd:62, 199`) | `ui.gd:2536, 2553` ; shader `voile_eblouissement.gdshaderinc:308` | corps complet ⇔ **niveau > 0,001** | 0,06 |
| Voile **plein** + copie `_voile_bb` | `niveau × curseur ≥ aberration_debut` (0,12) | `ui.gd:2543, 8881-8885` | **d ≥ 0,12** | **éteints** (déjà : ISO10 1a) |
| Pénalité de vitesse / de visée | `d` brut : `lerp(1, 0,4, d)`, `18·(1 − 0,6·d)` | `player.gd:1787-1788, 1807` | toujours | −3,6 % / −3,6 % |
| Acouphène ; bot | `d` brut | `player.gd:1376` ; `perception_bot_noeud.gd:170` | — | — |

**Ce que le tableau dit.** (i) Flou, halo et opacité passent **tous par `Brouillage._dose`** (`brouillage.gd:655`) : c'est « une seule formule, deux appelants » (`BrouillageVue.maj` et `player.gd:1915`).
(ii) Le voile **ne passe jamais par `Brouillage`** : il relit `dazzle_amount` à `ui.gd:2536`, sans GAIN. (iii) La pénalité de jeu lit la valeur brute : « très très léger quand on utilise sa lampe »
(Adrien, 2026-09-09, ROADMAP 2538 et 18886) — **c'est de l'équité, pas du rendu**.

### 1.3 Réponses

**Q81(a) fait-il tomber le flou permanent (LUM-01) ?** **Oui — à une condition : le plancher doit être posé dans `Brouillage._dose`** (ou, à défaut, dans la lecture `dazzle` de `BrouillageVue.maj` *et*
dans `player.gd:1915`). Alors, au repos, `D = 0` ⇒ `rayon = 0`, `force = 0` ⇒ `_flou.visible = _copie.visible = _halo.visible = false` : les trois nœuds, dont la copie d'écran, disparaissent, et
l'opacité adverse revient à 1,0 (O2) ; c'est un seul geste pour trois symptômes. **Non** s'il n'est posé que dans `Brouillage.opacite()` (le symptôme O2 pris isolément) : `flou()` et `halo()`
recalculent leur propre dose. Le texte de Q81 (« l'éblouissement ne brouille qu'au-delà de ce que sa propre torche verse ») se lit comme le premier cas, mais **le code est à deux appelants
et rien ne les force à rester d'accord** ; `test_brouillage` ne les lit pas ensemble.
La *forme* du plancher décide de ce qui change au-dessus de 0,06 : (α) **soustractif** `D = 2·max(0, d − 0,06)` : continu, mais décale toute la courbe (saturation à d = 0,56 au lieu de 0,5 ;
opacité de l'ennemi à d = 0,3 : 0,108 au lieu de 0,044) — c'est ce que Q81 dit en demandant de rejouer la matrice du bot ; (β) **zone morte** `d ≤ 0,063 ⇒ 0`, inchangé au-dessus : ne touche
rien au-dessus, mais fait *apparaître* d'un coup à 0,0631 un flou de rayon 24 px (noyau ≤ 4,3 px chez le client, voir D2). Le seuil d'extinction réel du flou est `d > 0,00526 + P`.

**Le voile de LUM-02 tombe-t-il lui aussi ?** **Non, pas de lui-même.** Autre variable (`niveau`, pas `D`), autre fichier (`ui.gd`), autre seuil (0,001). Un même plancher *numérique*
(0,06 sur `dazzle_amount`) l'éteindrait au repos — le shader sort sur `COLOR = vec4(0)` (branche uniforme `niveau ≤ 0,001`) — mais :
(1) c'est une **seconde écriture** à `ui.gd:2536` ; (2) c'est un **changement d'image**, que Q81 ne tranche pas : le voile soulève tout l'écran de 2 à 4/255 au repos (le noir « sous le voile » :
ROADMAP 30744, relevé à 79 000-205 000 pixels par vue) et ajoute une lueur et cinq traînées (jusqu'à ~14/255 au centre, ESTIMÉ par l'auditeur) ; sans lui le noir tombe à 0/255. Aucune décision écrite ne
dit que ce voile de repos est voulu (ROADMAP 26541 : « légitime, alimenté par un niveau que personne ne regardait » — à propos de la *frange*) ni qu'il ne l'est pas : **c'est une question à Adrien, distincte de Q81** ;
(3) ne pas *soustraire* : `aberration_debut` (0,12) compare le niveau brut ; une zone morte de test (`niveau ≤ 0,063 ⇒ 0`) laisse le plein/calme inchangé ; (4) le quad reste dessiné (voir D3 pour le moyen de ne plus le dessiner).

**Un même plancher les éteindrait-il au repos ?** Numériquement oui (0,06 + marge), **mais à deux endroits, avec deux conséquences différentes** : brouillage = aucun changement d'image visible à 1080p (≤ 1 px au-delà), O2 corrigé, effet de repos du client supprimé (D2) ;
voile = changement d'image mesurable (le noir). **C'est l'argument de performance pour Q81 que l'audit peut donner à Adrien** : *poser (a) dans `_dose` supprime, au repos, une copie d'écran + deux quads par vue et par image
(0,1-0,4 ms ESTIMÉ à 1080p-1440p), sans toucher la pénalité d'équité ni l'image du voile* — et il rend les deux joueurs symétriques (D2).

### 1.4 Pour l'agent de mesure (variante « niveau ≤ 0,06 traité comme 0 pour le brouillage et le voile »)

* **Où patcher** : `brouillage_vue.gd:193` (`var dazzle := …` ⇒ 0 si `≤ 0,06 + 1e-3`) pour flou + copie + halo ; `ui.gd:2536` (`niveau`) pour le voile. **Ne pas** écrire dans `Player.dazzle_amount` : vitesse, visée,
  acouphène, bot et `net_dazzle` en dépendent. `player.gd:1915` (opacité) seulement si l'on veut le Q81 *complet* — c'est de la lecture d'équité, pas du coût.
* **Ce que la variante retire réellement** : *brouillage* — trois nœuds **retirés du dessin** (`visible = false`) : un `BackBufferCopy` RECT (≈ 40 k texels au repos : le coût est la **coupure de passe**, pas la bande passante de la copie),
  un `ColorRect` de 17 prises sur ≈ 10 k px (1440p), un `TextureRect` de ≈ 3 k px. *Voile* — le `ColorRect` **reste dessiné** (le code ne le cache jamais au repos : piège de l'`HBoxContainer` en écran scindé, `ui.gd:2436-2451`) : on mesure « corps calme − quad vide », pas « corps calme − rien » ; pour mesurer ce dernier, poser `modulate.a = 0` (D3).
* **Limites de llvmpipe** : la coupure de passe d'un GPU à tuiles **n'existe pas** en rendu logiciel (la copie est un `memcpy`) ; un delta nul sur la partie brouillage **n'infirme pas LUM-01**. Seul le delta du voile (ALU
  par fragment, ici CPU) est lisible, et **en rapport** (voile calme / quad témoin de même surface, dans la même fenêtre), pas en ms absolues. Le comptage de nœuds visibles (test headless, § 2) est la preuve indépendante du matériel.
* **Effets de bord à surveiller** : (i) le hoquet de première compilation du flou (LUM-05) **se déplace** du premier allumage de torche vers le premier éblouissement réel — pile sur l'action ; (ii) chez le client, l'ancrage de repos du
  flou/halo sur l'adversaire disparaît (D2) ; (iii) `test_classes._test_ancrage_des_effets` lit le **texte** de `brouillage_vue.gd` et de `game_state.gd` (`func _a_un_axe(`, `var dirige := _a_un_axe(emetteur)`, `if dirige else 1.0`,
  `emetteur.get("eblouissement_dirige")`, pas de `is Player`, `app.maj(regardeur, source_eblouissante_ou(regardeur,`) : ne pas y toucher ; (iv) le seuil se compare à la valeur *répliquée* chez le client.

---

## 2. Un bloc par constat

### LUM-01 — Flou, copie d'écran et halo allumés en permanence dès que la torche brûle

**1. Le code.** Exact. `brouillage_vue.gd:227-231` :
```gdscript
var f := Brouillage.flou(dazzle); var rayon_flou := float(f["rayon"]); var force := float(f["force"])
_flou.visible = rayon_flou > 2.0 and force > 0.001
_copie.visible = _flou.visible          # un BackBufferCopy visible recopie à chaque image
```
et l'intention, `brouillage_vue.gd:145-148` (doc d'`eteindre()`) : « le laisser allumé hors éblouissement ferait payer l'effet en permanence, alors qu'il ne sert que quelques secondes par manche ».
Arithmétique reproduite : `D = 0,06 × 2 = 0,12` ; rayon `190 × 0,12 = 22,8 > 2` ; force `0,12 > 0,001` ; halo `150 × 0,12 = 18 > 1`, alpha `0,7 × 0,12 = 0,084`. Le gagnant du MAX est le porteur lui-même
(`gagnante[cible] = src["noeud"]` dès que `v = 0,06 > 0`, `game_state.gd:2396-2406`) : `emetteur == regardeur`. `lum/flou_repos.py` relancé : noyau maximal **0,256 px / couverture 4,5 %** à 1080p, 0,915 px / 44 % à ×1,33, 2,494 px / 100 % à ×2 — **identique au rapport**.

**2. La fréquence.** Remontée : `GameState._process` (l. 2081) → `_maj_brouillage()` (l. 2094 ; corps l. 5856-5884) → `BrouillageVue.maj(regardeur, source_eblouissante_ou(…))` **à chaque image rendue**, par vue regardée, dès que
`round_active` et p1/p2 valides. Niveau 0,06 dès que la torche du regardeur est allumée (V1b : jamais pendant le décompte, `player.gd:1736`). Vue unique : un appareil sous `_main` (donc la fenêtre, `presentation_3d.gd:409-413`) ;
écran scindé : deux, chacun dans sa sous-vue 3D ; en ligne : hôte **et** client ; entraînement et solo : l'appareil de J1. C'est « l'essentiel d'un match ».

**3. Le coût.** Ce qui est dessiné au repos est **PROUVÉ** ; ce que ça coûte ne l'est pas. Emprise de repos : ellipse de 2×59,3 × 2×22,8 ≈ 118×46 px canevas (≈ 5 k px, ≈ 10 k px à 1440p) → 17 prélèvements × 10 k ≈ 170 k lectures : **négligeable** ;
halo ≈ 3 k px : négligeable ; copie `COPY_MODE_RECT` ≈ (118+68)×(46+68) ≈ 21 k px canevas ≈ 40 k texels : **négligeable en bande passante**. Ce qui peut peser est la **coupure de passe** : le moteur vide les items en attente puis copie
(`rasterizer_canvas_gles3.cpp:519-534` ; `texture_storage.cpp:3657-3692`), c.-à-d. sur un GPU à tuiles un *store* puis un *load* de toute la couleur de la fenêtre (≈ 2 × 3,7 Mpx × 4 o ≈ 30 Mo à 1440p, 17 Mo à 1080p, indépendant du rect copié) :
**0,1-0,4 ms ESTIMÉ**, ∝ fenêtre. La seule mesure (ISO10 1a, 0,53 ms à 2560×1440 : « copie + voile plein » contre « calme », ROADMAP 4316, 26533) **regroupe** copie plein cadre + chaîne de mips (LUM-06) + 3 lectures d'écran par pixel : c'est une borne haute, pas le prix de la
copie RECT. Le chiffre de l'auditeur (0,1-0,5 ms) est donc plausible, **sans preuve**.

**4. Les invariants.** *Image* : retirer le flou au repos ne change rien de visible à 1080p ; à ×1,33 il retire un adoucissement ≤ 0,9 px dans un lopin devant le joueur (hors trou d'exclusion) ; le halo retiré est un voile chaud de 21/255 au pic sur soi (hôte) — changement
d'image **très faible mais réel**, à faire valider. *Équité* : la valeur est répliquée ; mais l'effet de repos n'est **pas le même des deux côtés** (D2) — le retirer rétablit la symétrie. *Tests* : § 1.4 (iii) ; `test_brouillage` (arithmétique à 0/0,5/1/1,6 : un plancher dans `_dose` n'en rougit aucun, `opacite(0,5) < 0,45` reste vrai) ;
`banc_voile.gd:757-760` pose le mode de copie après `maj` : sans effet sur la visibilité. *Interaction avec LUM-05* : sans préchauffage, retirer le flou au repos **déplace le hoquet de compilation sur le premier éblouissement réel**.

**5. Le statut.** Le niveau de repos est connu (ROADMAP 3616, 26516-26517, 26541) ; **son coût sur le brouillage ne l'est pas** (ISO10 1a n'a traité que `_voile_bb`). OMBRES le rencontre côté opacité (O2, Q81) mais pas côté flou/copie/halo. → NOUVEAU comme coût ; **DÉJÀ COUVERT dans ses effets si Q81(a) est accepté et posé dans `_dose`**.

**6. Verdict : CONFIRMÉ (mécanisme PROUVÉ), coût NON ÉTABLI. Sévérité : MINEUR (MAJEUR si ≥ 0,3 ms mesuré).**
*Correctif minimal* : dans `Brouillage._dose`, ou à défaut `BrouillageVue.maj`, traiter `d ≤ RETRODIFFUSION × 1,05` (0,063) comme 0 — **à fondre dans Q81(a)** si Adrien dit oui (soustractif), sinon zone morte (S) ; **dans le même commit, préchauffer** flou + copie + voile (LUM-05).
*Preuve dans le cloud, indépendante du matériel* : un test headless `maj()` sur un faux regardeur (`dazzle_amount` posé à 0,06) dont on lit `_flou.visible`, `_copie.visible`, `_halo.visible` — **vrai aujourd'hui** (c'est la preuve de la permanence), faux après ; à 0,2 : vrai ; `emetteur != regardeur` : inchangé ; et un second cas
`regardeur = p2`, `emetteur = p1` (le client, D2) qui prouve l'ancrage. *Prix* : seulement sur le Mac (coupure de passe) — **ne pas conclure d'un delta nul sous llvmpipe**.

---

### LUM-02 + HUD-04 + SHA-03 — Le voile « calme » exécute son corps complet sur toute la fenêtre torche allumée

*(trois auditeurs, un défaut ; V2 a déjà rendu « CONFIRMÉ (existence) / coût NON ÉTABLI, MINEUR à mesurer » pour HUD-04 : je confirme et j'ajoute ce qui suit.)*

**1. Le code.** Exact. `ui.gd:2543-2545` choisit le matériau calme sous `aberration_debut` ; `voile_eblouissement.gdshaderinc:307-310` ne sort tôt que sous `niveau ≤ 0,001` ; `ui.gd` ne surcharge ni `lueurs_n` (2), `flares_n` (5), `fantomes_n` (5)
ni `plancher` (0,18) / `cime` (0,48) (défauts du shader). Les trois textures font 256², 512×64, 256² (**163 840 px**, ≈ 0,65 Mo : elles tiennent en cache — chaque lecture est un TMU, pas un défaut de cache). **SHA-03 : « ≈ 63 % des 12 lectures tombent hors de [0,1]² » — reproduit** par
Monte-Carlo sur la géométrie du shader (`v8_work/voile_lectures_hors_texture.py`) : lueurs 11,7 %, traînées 49,1 %, fantômes 95,9 % ⇒ **62,4 %**. Elles rendent 0 (bord noir par contrat, `repeat_disable`) mais le GPU les exécute.

**2. La fréquence.** `GameState._process` → `ui.update_hud` (l. 2343) → `_poser_voile(p1_dazzle, …)` (`ui.gd:8804`) à chaque image ; le fragment s'exécute sur tout le `ColorRect` : la fenêtre en vue unique (`p2_dazzle.visible = _voile_scinde and _deux_vues_affichees()`, `ui.gd:8870-8871`),
deux demi-fenêtres en scindé (même nombre total de pixels). Torche allumée : essentiel d'un match. Torche éteinte : niveau 0 → sortie précoce, quad transparent (l. 16993 point 3).

**3. Le coût.** Surface PROUVÉE (0,9 / 2,1 / 3,7 Mpx à 720p / 1080p / 1440p). Poids : 12 TMU + lavis (`pow`) + grain (`hash21`) + ≈ 100-150 ALU par pixel si les ≈ 55 `sin/cos` d'uniformes sont hissés (préambule du pilote d'Apple : **non vérifié**), ≈ 300 ALU sinon.
À 3,7 Mpx : 44 M lectures + 0,4-1,1 G ALU ⇒ **0,05-0,7 ms GPU ESTIMÉ** à 1440p (V2 : 0,05-0,8 ; l'auditeur : 0,1-0,5 ; SHA-03 : 0,2-0,5) ; ÷ 4 à 720p. **Et seulement si le duel est lié au GPU** : sur un jeu lié au CPU le gain d'image est nul. ISO10 1a a mesuré « plein + copie » contre « calme », **jamais « calme » contre « rien »**
(`loupe.gd:1511-1545` n'a que deux bras) : le coût du voile calme seul n'a jamais été isolé.

**4. Les invariants.** (a) **Pas de `visible = false` en écran scindé** (`ui.gd:2436-2451` : un enfant d'`HBoxContainer` caché donne toute la largeur à l'autre ; attrapé par `planche_eblouissement`) ; en vue unique, `p2_dazzle` est déjà caché et `p1_dazzle` serait seul — mais cela ne change rien tant que le niveau de repos (0,06) garde le fragment complet. **Mais le moteur offre un autre moyen** (D3) : `modulate.a < 0,007` fait sauter l'item au culling
(`renderer_canvas_cull.cpp:327-331`) sans toucher `visible`, donc sans bouger la mise en page — c'est la leçon que le dépôt a déjà payée à `game_state.gd:6058-6071` (« `modulate` et non `visible` »). Personne ne l'a proposé pour le voile ni pour la ligne 16993. (b) *Image* : sauter les lectures hors texture (SHA-03 option 1) et hisser les
trigonométries d'uniformes (option A de HUD-04/V2) rendent la **même image** ; le plancher et la variante allégée sous `aberration_debut` la **changent** (décision d'Adrien, famille MONDE : jamais un réglage joueur). (c) `VoileEncre` (10 % de noir, `ui.gd:2582-2587`) : identité, ≤ 0,05 ms, **à ne pas toucher** (V2 d'accord). (d) `tools/test_iso_vues.gd:149, 158` lit `p2_dazzle.visible` — pas `modulate`.

**5. Le statut.** CONNU-OUVERT : l. 16993 (point 3) est **périmé en partie** : son remède `visible = niveau > 0,001` ne couvre plus l'état courant (torche allumée : le fragment complet tourne alors), et il n'est sûr qu'**en vue unique** : en écran scindé, cacher un des deux enfants de l'`HBoxContainer` donne toute la largeur à l'autre — la moitié de J1 blanchissait quand J2 était ébloui, rattrapé par `planche_eblouissement` et consigné à `ui.gd:2436-2451` ; la l. 16993 le dit elle-même (« à condition de ne pas rejouer la régression du point 1 »). (La l. 16534 — « les rectangles sont cachés au repos » — décrit le branchement DA5.5 ; le code n'a caché que `p2_dazzle`, hors scindé : c'est ce que la l. 16993 relève.) **Déjà fait** : le shader calme sans copie d'écran (ISO10 1a, l. 26518-26537 : `voile_eblouissement_calme.gdshader`, copie `_voile_bb`
suspendue sous 0,12, `p2_dazzle` caché hors scindé). **Reste** : (i) le corps complet au repos ; (ii) le quad d'alpha nul torche éteinte ; (iii) `VoileEncre` (identité).

**6. Verdict : CONFIRMÉ pour l'existence ; coût NON ÉTABLI. Sévérité : MINEUR, à mesurer** (MAJEUR si ≥ 0,3 ms **et** GPU-bound). *Correctif minimal* : mesurer d'abord (bras C « voile masqué par `modulate.a = 0` », bras D « sans `VoileEncre` » à `loupe.gd:_cout_du_voile`, comme V2) ; si ≥ 0,15 ms,
**sauter les lectures hors texture** (image identique à 0 px, 0,4-0,5 G ALU-éq selon SHA-03) — *sans décision* ; l'extinction au repos est une décision d'image (§ 1.3). *Preuve dans le cloud* : A/B `loupe-cout-voile` sous llvmpipe (rapport voile/quad témoin) ; `tools/banc_voile.tscn` pour l'identité au pixel (SHA-03 option 1 ⇒ 0 pixel).

---

### LUM-03 — La passe d'ombre vaut `4 × N × L` par viewport, se répète dans chaque capteur, solo jamais mesuré

**1. Le code et le moteur.** La structure du constat est **exacte, et je le confirme par le moteur** (ce que l'auditeur écrivait « de mémoire ») : `renderer_viewport.cpp:466-512` rassemble, **par viewport**, toutes les lumières qui croisent son `clip_rect` (`:493`) et fusionne
leurs rects en un `shadow_rect` unique (`:503-505`) ; `:552-572` trie les occulteurs contre ce rect englobant ; `:575-580` appelle `light_update_shadow` pour chaque lampe ; `rasterizer_canvas_gles3.cpp:1705-1746` rejoue, **4 fois**, **tous** les occulteurs de la liste
(strip de 2 lignes : `glViewport(…, p_shadow_index*2, tex/4, 2)`, l. 1706). Ces dessins ne sont pas dans le compteur d'appels (`glDrawElements` direct, l. 1742). `capteur_corps.gd:84-105` : sous-vue 256² en `UPDATE_ALWAYS`, monde partagé ; `presentation_3d.gd:803-810` : un capteur ne gèle que si la **vue** gèle ;
`presentation_3d.gd:846` : `p2` caché (`game_state.gd:1289`) garde son capteur, qui continue de se centrer sur lui (`suivre()` ne change que la visibilité du disque). Parqué où ? `_do_start_round` (l. 1926) le pose à `_get_spawn_position(1)` (l. 1996), et `aventure_poser_la_salle` l'appelle (l. 1275) : le `spawn_p2` de la carte de la salle — **dans la salle**, donc souvent au voisinage d'au moins une lampe : le coût de ce viewport n'est pas nul.
La fenêtre de 128 px d'un capteur croise le rect d'une torche si le corps est à ± 532 px (468 + 64) **dans l'axe de la torche — jusqu'à ± 690 px selon la visée** (D4 : le moteur teste l'AABB du rect tourné, pas le carré).

**2. La fréquence.** Par image rendue, par viewport qui rend le monde : lightmap (1 en vue unique, 2 en scindé), capteurs de corps (2 en duel vue unique, 4 en scindé, + 1 par PNJ à ≤ 1 300 px, `presentation_3d.gd:161, 1197-1200`), capteurs d'objets posés (`miroirs_iso.gd`). Tout cela est le duel standard, pas un cas rare.

**3. Le coût — l'apport de l'auditeur, et ses deux corrections.**
*(a) Le modèle surcompte les dessins.* Chaque lampe ne dessine que les occulteurs dont la couche croise son `shadow_item_cull_mask` : `rasterizer_canvas_gles3.cpp:1719` (`!(p_light_mask & instance->light_mask) → continue`). Or `solo_ombres.py` compte **les quatre occulteurs de corps** (étoile 50 px + torse 24 px, × 2 corps) pour **toutes** les lampes.
En vrai : la torche de J1 dessine les étoiles adverses seules (`player.gd:832`, `1 | 2 | COUCHE_OCCLUDER_ADVERSE`), celle d'un PNJ l'étoile de J1 seule (Q86 : « leurs lumières ne lisent que la couche 4 »), la rétrodiffusion les torses (`player.gd:877`), le halo l'étoile d'en face, un plafonnier aucun corps.
J'ai refait le calcul (`v8_work/modele_corrige.py`, mêmes salles et mêmes hypothèses, caméra sur le joueur, 12-24 visées) : **solo, 100 salles : médiane 1 044 → 704 dessins, p90 3 461 → 1 931, max 7 744 → 4 035 (× 0,65) ; duel, six cartes : 728/448/728/840/840/840 → 576/296/576/688/688/688 (× 0,79).**
(Les 1 212 / 3 496 / 7 296 du rapport prennent la *pire* des positions de caméra pour la lightmap ; mes chiffres sont « caméra sur le joueur » — comparer chaque colonne à son semblable.)
*(b) L'étalonnage à 2,8 µs/dessin n'est qu'une borne haute.* Il vient d'**un seul point** : la lampe de la fusée, à 8 occulteurs, 0,09 ms « dans le bruit de ses propres passes (0,35) » (ROADMAP 28270 ; `compte_occulteurs.gd:22-25`). 0,09 ms / 32 dessins vaut 2,8 µs **seulement si cette lampe n'est dessinée que dans un viewport** (lightmap) ;
dans V viewports c'est 2,8/V (1 à 3 : lightmap + 0 à 2 capteurs), et le total contient un coût **fixe par lampe et par viewport** (`glBindFramebuffer`, `glViewport`, `glScissor`, `glClear` couleur + profondeur, `version_bind_shader`, ≈ 15 appels GL, l. 1646-1673) que le modèle `4 × N × L` ignore. La seconde « ancre » du dépôt (64 dessins ≈ 0,14 ms ⇒ 2,2 µs, ROADMAP 27698)
est une **dérivation**, pas une mesure indépendante. **Plage retenue : 0,9-2,8 µs/dessin** (un `glDrawElements` + deux `glUniform4f` + un `glBindVertexArray` sur le pilote GL d'Apple : ordre de grandeur plausible, **à mesurer**). D'où : duel 296-688 dessins ⇒ **0,3-1,9 ms** (rapport : 1,1-2,4) ; solo médian 704 ⇒ **0,6-2,0 ms** (rapport : 3,4) ;
la salle `chapitre_00/niveau_09` (6 PNJ, toutes torches allumées) : 4 028 dessins ⇒ 3,6-11 ms — **cohérent avec OMBRES** (« environ 3 ms torches de PNJ éteintes, jusqu'à 9,5 ms si toutes brûlent »), ce qui n'a rien de surprenant : **même ancre, mêmes unités**.

**4. Les invariants.** Les leviers de l'auditeur n'ont pas de risque de déterminisme (rendu local) ; l'apparition d'un corps 3D au bord d'écran est le risque de (2) — qu'`UPDATE_WHEN_VISIBLE` (OM6) a **par construction** : `used_in_frame` est posé quand un matériau portant la texture du capteur est *lié pour un dessin*
(`material_storage.cpp:2789`, appelé par `SceneMaterialData::bind_uniforms`, l. 3269-3274) — un corps frustum-culled ou caché (`presentation_3d.gd:868`) ne le pose pas ; **une image de retard** à la rentrée (contenu périmé du dernier tour).

**5. Le statut — ce qu'il apporte de plus qu'OM6.** OM6 contient déjà : les capteurs en `UPDATE_WHEN_VISIBLE` (joueurs, figurants, objets : **le gating « champ + marge » et `p2` caché de l'auditeur en sont des cas**), les halos sans récepteur, la lumière de coup, les contours, les étoiles aux seuls capteurs proches, le banc solo — et le **même** modèle moteur
(« Ce que coûte la lumière », l. 33952-33963) avec la **même ancre unique**. **Nouveau** : (i) le dénombrement par salle (les trois salles à benchmarker : `chapitre_00/niveau_09` 6 PNJ, `chapitre_09/niveau_07` 76 rectangles, `chapitre_08/niveau_09` 100×80, 7 PNJ, 8 plafonniers) ; (ii) le constat structurel « (ii)-(iii) » : la lampe recouvre un carré, le coût est surlinéaire en nombre de corps ;
(iii) **le levier cookies (LUM-04), absent d'OM6** ; (iv) deux défauts de modèle (D4), qui dégonflent ses ms. **Rien de neuf** sur les leviers 1, 2, 3, 5 (OM6) ni sur le fait que le solo n'a jamais été mesuré (ROADMAP 2449 ; OM6 : « mesurer chaque geste avant et après »).

**6. Verdict : CONFIRMÉ AVEC RÉSERVE ; DÉJÀ PRIS EN CHARGE pour les leviers (OM6) ; sévérité MAJEUR présumé → à mesurer** (en duel : 0,3-1,9 ms ESTIMÉ — le seuil de 0,3 ms que le projet s'est fixé, ROADMAP 28303, est au bas de la fourchette ; l'étalonnage est une borne haute). *Correctif minimal* : aucun nouveau geste ; **un seul ajout au banc d'OM6** : compter les dessins *par masque* (`4 × N_masque × L`), pas `4 × N × L`.
*Preuve dans le cloud* : le recensement existant (`bench_framerate.gd:767-841`, imprimé à l'ouverture) est un compteur indépendant du matériel — **mais il ignore la rotation et `offset`** (il pose un carré centré `Rect2(l.global_position - taille*0.5, taille)`, l. 788-790) et ne filtre pas par masque : l'étendre *avant* de s'en servir ;
temps CPU par viewport (`RenderingServer.viewport_set_measure_render_time` / `viewport_get_measured_render_time_cpu`) sous Xvfb + llvmpipe, A/B `shadow_enabled = false` — lu en **rapport**, pas en µs.

---

### LUM-04 — Le rect carré 936² de chaque torche est vide à plus de 75 % ; rogner les cookies + `offset`

**1. Le code et la géométrie.** `lum/cookies.py` relancé : sur les **dix cookies de classe**, tout l'alpha non nul est dans la moitié avant (x ≥ 512 sur 1 024) ; boîte englobante à alpha ≥ 1/255 de **7,1 % (arbalète) à 24,0 % (pompe)**, moyenne 13,9 % ; texels non nuls 2,8-13,5 %. (Les cookies `projecteur_large` et
`spot_focalise` ne sont pas des cookies de classe.) Les cookies font 1 024², `compress/mode=0`, `mipmaps/generate=false` (4 Mio). Empreinte : `echelle_torche()` = `portee_torche() / 256 × 512 / largeur` = 468/256 × 0,5 = 0,914 → **936 px** (`weapon_data.gd:265-272` ; Q76 : 468 px, les dix classes, ROADMAP 2460).

**2. Le moteur — les trois questions posées, toutes tranchées par la source 4.7-stable.**
*Le culling d'une `PointLight2D` utilise-t-il le rect de sa texture ?* **Oui, et rien d'autre** : `renderer_viewport.cpp:477-491` : `tsize = taille de la texture × scale` ; `local_rect = Rect2(-tsize/2 + texture_offset, tsize)` ; `rect_cache = xform_cache.xform(local_rect)` — **l'AABB du rectangle tourné** (`Transform2D::xform(Rect2)`), pas son contour ; `:493` croise ce rect avec le viewport ;
`:503-505` le fusionne dans le `shadow_rect` ; `rasterizer_canvas_gles3.cpp:850` s'en sert encore pour la liste de lumières **par item** (`global_rect_cache.intersects(light->rect_cache)`, plafond `max_lights_per_item`). L'alpha n'est lu nulle part. *Un `offset` le déplace-t-il ?* **Oui** : `texture_offset` entre dans `local_rect` (l. 481) **et** dans la matrice de lecture de la texture
(`light_shader_xform`, l. 496-499 ; `rasterizer_canvas_gles3.cpp:242`) ; **mais l'origine de l'ombre reste le nœud** : `light_update_shadow(…, light->xform_cache.affine_inverse(), …)` (`renderer_viewport.cpp:579`) et `shadow_matrix = xform_cache.affine_inverse()` (`rasterizer_canvas_gles3.cpp:243`). **L'hypothèse de l'auditeur (« à confirmer avant tout travail ») est confirmée.**
Un détail de plus : `radius_cache = local_rect.size.length()` (l. 508) est la diagonale du rect de **texture** ; il fixe le plan lointain de la carte d'ombre (`p_far = radius × 1,1`, l. 579) : ≈ 1 456 px aujourd'hui, ≈ 615 px pour un cookie rogné au pistolet. Les occulteurs au-delà sont écrêtés — sans effet visible, puisque la boîte rognée ne contient que les texels d'alpha non nul (son coin le plus loin de la lampe est à ≈ 491 px) ; à vérifier au banc.
(Au passage : `PointLight2D.set_texture` avertit — en build de débogage — si on lui donne un `AtlasTexture` (`light_2d.cpp:398-413`) : la planche « plusieurs images dans un fichier » n'est pas une voie pour les lumières.)

**3. Le coût — le chiffre de l'auditeur tient à ± 6 points, mais le test du modèle était optimiste.** `solo_ombres.py` croise les rects par SAT (rectangle orienté) ; le moteur croise **l'AABB** (D4). Refait avec l'AABB (`modele_corrige.py`), rect rogné = boîte du pistolet (511×336 texels, 16,4 % : le milieu des dix) × 0,914, décalé de w/2 devant la lampe, orientations tirées :
**duel** (comptage par masque) : −33/−57/−34/−30/−33/−31 % selon la carte (rapport : −33 à −49 %), soit **≈ −30 %** ; **solo** : **−54 %** (rapport : −50 %) ; les trois salles lourdes : −60 % (`chapitre_00/niveau_09`), −66 % (`chapitre_09/niveau_07`), −77 % (`chapitre_08/niveau_09`). Le gain en **ms** hérite de l'incertitude de LUM-03 (0,9-2,8 µs/dessin, masques) : **0,1-0,6 ms en duel ESTIMÉ**.
*Ancre mesurée que l'auditeur n'a pas citée* : **Q76** (ROADMAP 30890-30920) a retiré ×0,41 de **surface de lampe** au Terrassier et gagné **5,8 à 6,6 % du temps d'image sous llvmpipe** (24 prises en miroir). Rogner le rect à ≈ 17 % de l'AABB actuelle est un levier de la même famille, **plus fort** — mais sous llvmpipe le coût est un coût de **fragments** (boucles de lumières par item), alors que
sur le Mac la passe d'ombre est un coût **CPU de pilote** : les deux gains ne s'additionnent pas de la même façon. **Et un gain qu'ils ne voient pas : l'atlas (D1)** : deux cookies 1 024² ⇒ un atlas de lumières de **2048×4096 = 32 Mio** ; rognés, **1024×1024 = 4 Mio** (`v8_work/atlas_lumieres.py`).

**4. Les invariants — l'auditeur a raison et la liste est incomplète.** (a) **La règle de la portée** (ROADMAP 8047-8075, « une propriété d'implémentation ne doit jamais décider d'une grandeur de jeu ») : avec un cookie « moitié avant » rogné, `texture_scale = portée / largeur` (468/512) et non plus `2·portée / largeur` — **un facteur 2 silencieux** pour tout lecteur qui suppose le cookie centré :
`iso_volumes.gd:718` (`0,5 × largeur × texture_scale` ⇒ **le rayon dans l'air passerait de 468 à 234 sans erreur**, et `_tailler_faisceau_air(e, lampe.texture, …)` lit l'enveloppe du cookie), `vision.gd:152` (`taille × 0,5 + local / échelle` : le décalage), `weapon_data.gd:265-272`, `light_textures.gd:96-103`, `gadget_torche_fantome.gd:131-132`, `game_state.gd:2246, 2259` (fantômes de killcam),
`lumieres_iso.gd:296-297` (lumière 3D dormante). Le bot lit le cône de la torche par `arme.lumiere_recue` (`perception_bot.gd:385` → `Vision`) : **même adaptation que l'éblouissement** ; ses lumières rondes (`perception_bot_noeud.gd:284`, halos) ne sont pas la torche ; le mannequin iso lit la portée par `arme.portee_torche()` (`mannequin_iso.gd:_torche`) : à l'abri. (b) L'éblouissement lit l'alpha du cookie au pixel (`Vision.intensite_texture`) : équité, doit coller. (c) Gardes qui rougiraient : `test_vision`, `test_torches`, `test_lumieres` (n'autorise `texture_scale` que via `poser()`), `test_iso_torches3d`, `test_portee_ecran`, `test_allegement_faisceau`, `test_faisceaux_concentres` — toutes présentes dans `tools/`.
(d) `tools/concentrer_cookies.gd` existe mais resserre **en angle** (déformation polaire) ; il ne recadre pas.

**5. Le statut.** **NOUVEAU** : ni OM6 ni OMBRES ni le « Lot 6 » de l'audit des lumières ne parlent de rogner les cookies. Voisins : `rendering_quadrant_size` (ROADMAP 5338-5340, 5378 : « à chiffrer », non fait).

**6. Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : MAJEUR potentiel, effort L, risque élevé en surface.** *Correctif minimal* : **ne pas le faire avant la mesure d'OM6** ; si la passe d'ombre pèse encore ≥ 0,3 ms en duel après OM6 : prototyper **au banc, à l'exécution, sans toucher un consommateur** (`--cookies-rognes` : `ImageTexture` recadrée + `offset` + `texture_scale`) et mesurer ; seulement ensuite réécrire les consommateurs **d'un seul tenant** avec leurs gardes. *Preuve dans le cloud* :
comptage hors matériel avec le recensement étendu (AABB, `offset`, masques) ; protocole **Q76** (A C Q Q C A, llvmpipe, `--fusee --vue-unique --classe=pompe`) pour le temps d'image ; image : lightmap identique au pixel dans le cône (`banc_lumieres`, `planche_eblouissement`).

---

### LUM-05 — Shaders du flou et du voile, et copie d'écran, jamais préchauffés

**1. Le code.** Exact : `brouillage_vue.gd:71, 77` (`_copie.visible = false`, `_flou.visible = false` à la construction), `game_state.gd:5859` (`maj` seulement en manche) ; seul préchauffage du dépôt : `Fusee.prechauffer` (`game_state.gd:1565`, `fusee.gd:343-358`, shader de la **fumée**). Le programme GL se compile au premier **dessin** (ROADMAP 22510, PE3.5 ; V1a § 3.1 : quatre sources concordantes).
**2. La fréquence.** Une fois par processus et par shader. Le flou : au premier allumage de torche d'une manche (LUM-01 l'allume dès ce moment). Le voile **plein** : au premier éblouissement ≥ 0,12 (**V1a : HUD-08 CONFIRMÉ AVEC RÉSERVE**, « le seul item du lot pendant la partie ») ; le **calme** est dessiné dès la première image (V1a). **3. Le coût.** Non mesuré pour ces shaders (V1a : « je ne retiens pas “quelques ms à quelques dizaines de ms” comme un chiffre ») ; les 143-150 ms de la ROADMAP 27616 sont des variantes de lampe 3D. Programme du flou : 33 lignes de code, 17 prises ; voile plein : 128 lignes. S'y ajoute la **première allocation du back-buffer de la fenêtre** (`texture_storage.cpp:2766-2819` : une texture RGBA8 en chaîne de mips, ≈ 3,7 Mpx × 4 o × 1,33 ≈ 20 Mo à 1440p, **initialisée niveau par niveau**) :
ESTIMÉ 1-5 ms. **ESTIMÉ 10-50 ms au total, une fois.**
**4. Les invariants** (V1a § 3.5) : le dessin de chauffe doit être **réellement dessiné** (`modulate.a = 0` ou `visible = false` *sautent* le dessin, donc la compilation — D3 le confirme dans le moteur) ; alpha de **shader** nul : le flou avec `force = 0` (⇒ `couverture = 0`), le voile avec `niveau = 0`, dans **la même racine** que le dessin réel (la fenêtre en vue unique, la sous-vue 3D en scindé) ; `killcam_overlay` sort toujours `alpha = 1` (V1a). **5. Le statut** : CONNU-OUVERT (22510 ; V1a ; V1b ISO-09 = SHA-01 pour les shaders 3D). **Ce que l'auditeur n'a pas écrit** : ce correctif **devient plus important si LUM-01 est corrigé** (le hoquet quitte le premier allumage — un moment banal — pour le premier éblouissement réel).
**6. Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : MINEUR** (une fois par processus). *Correctif minimal* : étendre `Fusee.prechauffer` (`rebuild_arena`) à `SHADER_FLOU` (`force = 0`) + une `BackBufferCopy` visible de 1 px, `SHADER_VOILE` et `SHADER_VOILE_CALME` (`niveau = 0`) ; **à livrer avec LUM-01**. *Preuve* : `bench_framerate --seuil-lent 25` daté autour du premier allumage (règle de ROADMAP 22513) — un hoquet groupé disparaît.

### LUM-07 — `image_torche()` : lecture GPU de 4 Mio au premier allumage

**= ETA-05 (a) = BOT-10 — vérifié par V1b (§ 3.1) : CONFIRMÉ AVEC RÉSERVE, MINEUR (bas), 0,5-5 ms ESTIMÉ, une fois par classe et par processus, hôte/local seulement (le client sort dès la première ligne de `_maj_eblouissement`).** Je ne refais pas. Un seul ajout, de moteur : `texture_2d_get` ne rend son `image_cache_2d` qu'**en build d'éditeur** (`texture_storage.cpp:1519-1523`, `#ifdef TOOLS_ENABLED`) ; en export il fait un `glGetTexImage` synchrone par niveau (l. 1528-1551) ; le cookie n'a pas de mipmaps (`mipmaps/generate=false`) : **4 Mio exactement** (pas 5,6). Le hoquet n'existe donc pas quand on joue **dans** l'éditeur — à savoir pour le cloud.

---

### LUM-06 + SHA-07 — `filter_linear_mipmap` sur la texture d'écran

**1. Le code.** `voile_eblouissement.gdshaderinc:245` (sous `#ifdef VOILE_LIT_L_ECRAN`, donc le **plein** seulement), `killcam_overlay.gdshader:20` (l. 52-61 : 5 lectures), `distorsion_eblouissement.gdshader:6` (orphelin). Les autres lecteurs d'écran sont en `filter_linear` (`menu_glass`, `menu_veil`, `brouillage_flou`, `pate_ecran_iso`).
**2. Le moteur — la question « à mesurer » est tranchée.** `servers/rendering/shader_compiler.cpp:946-951` : `if (u.filter >= FILTER_NEAREST_MIPMAP) uses_screen_texture_mipmaps = true` ; l'énumération (`shader_language.h:334-342`) place `FILTER_LINEAR_MIPMAP` (3) au-dessus de `FILTER_NEAREST_MIPMAP` (2) et `FILTER_LINEAR` (1) au-dessous.
`rasterizer_canvas_gles3.cpp:429-437` : un item dont le matériau lit l'écran et déclare des mips fait passer `backbuffer_gen_mipmaps` à vrai ; `:529` → `render_target_copy_to_back_buffer(…, gen_mipmaps)` puis `copy_effects.cpp:253-313` **`gaussian_blur`** : un `glGenFramebuffers` neuf, puis, **pour chaque niveau de 1 à `mipmap_count − 1`** (`MAX(1, nb_mips − 4)` : 7 niveaux, niveau 0 compris, à 2560×1440 ; 6 à 1920×1080 ; `texture_storage.cpp:2773`), un changement d'attache de FBO,
deux `glTexParameteri`, un shader de flou et un quad plein écran. **Soit 6 passes de rendu en plus à 2560×1440 (5 à 1080p) à chaque image où ce shader est dessiné** — pas seulement « au premier dessin ». Quand le `BackBufferCopy` (`_voile_bb`) précède, le moteur fait la copie plein cadre **puis** la chaîne (`:537-541`, `render_target_gen_back_buffer_mipmaps`). Le corps du filtre : `texture(screen_texture, SCREEN_UV ± décalage)` à ≈ 1 texel par pixel ⇒ **LOD ≈ 0** : la chaîne ne sert à rien.
**3. Le coût.** Mécanisme PROUVÉ ; prix **à mesurer**. ESTIMÉ 0,1-0,4 ms (6 ruptures de passe + ≈ 1,2 Mpx de flou à 1440p), **pendant les éblouissements ≥ 0,12** (de l'ordre de 5-15 % du temps d'un duel : chaque balayage de faisceau, chaque flash) et pendant la killcam — « exactement les instants qui font le 1 % bas ». Le 0,53 ms d'ISO10 1a **contient** déjà cette chaîne.
**4. Les invariants.** L'auditeur et SHA-07 écrivent « image identique (LOD 0) ». **Pas strictement** : avec mips générés, `GL_TEXTURE_MAX_LEVEL = count − 1` (`rasterizer_canvas_gles3.cpp:2218`) et le filtre de la texture est `LINEAR_MIPMAP_LINEAR` (`texture_storage.cpp:2816`) : un LOD de 0,03-0,05 (gradient du `décalage`) mélange **3-5 %** du niveau 1, flou ; sans mips, `MAX_LEVEL = 0`. Écart attendu : quelques /255 sur les arêtes franches, 0 ailleurs — **à mesurer au pixel** (`banc_voile`). Pour la killcam : le shader encadre un contour par gradient de luminance (`step(0,045, …)`, l. 58-62) : la netteté du niveau 0 est *voulue*.
**5. Le statut.** NOUVEAU (V1a l'écrivait « de mémoire du moteur » ; **c'est maintenant lu**). **6. Verdict : CONFIRMÉ (moteur), coût à mesurer. Sévérité : MINEUR.** *Correctif minimal* : `filter_linear` dans les deux fichiers (S). *Preuve* : `loupe-cout-voile` forcé à 1,0, A/B des deux filtres ; écart au pixel au `banc_voile` ; sous llvmpipe la chaîne est du CPU lisible **en rapport**.

---

### LUM-08 — Murs par contours (`trace_contours`)

**DÉJÀ PRIS EN CHARGE : OM6, 4ᵉ puce** (« les murs : leurs occulteurs tracés par contours, rentrés de 3 px, validés à l'image — le geste le plus risqué du lot »). **Recompte reproduit** (`lum/occluders.py`) : duel 4/9/9/11/11/11 rects → 2/3/7/9/7/5 boucles (55 → 33, −40 %) ; solo 1 106 → 711 (−36 %), max 76 → 51. `trace_contours` existe (`map_geometry.gd:418`) et **sert déjà** à `mur_encre.gd:106` (le trait d'encre) : seul le branchement des occulteurs manque (commentaire `map_geometry.gd:262-268`).
**Ce que l'auditeur ajoute et qu'OM6 ne dit pas** : la **couture**. Deux rects voisins laissent entre leurs occulteurs un joint de 6 px (2 × `OCCLUDER_INSET` = 3) sur 29 px de long (35 − 6) : **un rayon ne le traverse que s'il arrive à moins de ± atan(6/29) ≈ ± 11,7° de l'axe de la couture** (calcul, non constaté) — un liseré d'au plus 6 px de large derrière un mur, donc de l'**information à travers un mur** (équité) mais minuscule ; la ROADMAP ne l'a jamais constaté à l'image (le commentaire est le seul témoin).
**Coût** : en instances PROUVÉ ; en temps, hérite de LUM-03 (par masque, les murs sont le gros de N : le gain reste ≈ −13 à −46 % de N retenu en duel ; en ms **0,1-1,2 ms ESTIMÉ selon la carte** au calibrage 0,9-2,8 µs — −2 occulteurs au Cloître ≈ 0,1-0,4 ms, −6 au Bunker ≈ 0,4-1,2 ms —, soit l'ordre du rapport (0,15-0,9), avec la même incertitude). **Risque** : celui qu'écrit OM6 (tout s'aligne sur les rects rentrés : `test_map_geometry`, zone morte des murets, `mur_iso`, `IsoGeometrie`, modèle de vue du bot « du côté du noir au moindre doute »). **Verdict : DÉJÀ PRIS EN CHARGE ; MINEUR.** *Preuve* : `tools/compte_occulteurs.gd`, `test_map_geometry`, A/B image.

### LUM-09 — Halos de proximité sans récepteur

**DÉJÀ PRIS EN CHARGE : OM6, 2ᵉ puce** (« les halos sans récepteur (PNJ, et adversaire en vue unique) : `shadow_enabled = false` — jamais `enabled` »). **L'auditeur écrit « NOUVEAU pour le solo » : c'est faux** — « Ce que coûte la lumière » (OMBRES l. 33959) chiffre déjà « le halo de chaque PNJ (portée 32, aucun récepteur dans la vue de J1 — environ 0,9 ms sur 3) ». Vérifié : le halo d'un PNJ (`player_id = 1`) porte le canal 32 (`canaux_lumiere.gd`, `canal_de_vue`) ; en vue de J1, les copies de sol `_P2` sont sur la couche 4 (hors masque de `vp1`) : aucun récepteur. Son point (b) — un halo périphérique **agrandit le rect englobant**
donc N pour toutes les lampes du viewport — est **juste et prouvé par le moteur** (`renderer_viewport.cpp:503-505`).
**Garde-fou que ni l'auditeur ni OM6 ne disent** : `shadow_enabled = false` est **global** à la lampe. Il n'est sûr que là où la **vue réceptrice n'est pas rendue** (le halo adverse en vue unique ; le halo d'un PNJ en vue de J1) ; en écran scindé, le halo de J2 a des récepteurs dans `vp2` et perdrait ses ombres de mur — l'information « un ennemi collé révélé à travers un mur » que `test_halo_proximite` garde. La règle doit se **recalculer au changement de vue** (le client regarde `vp2`, `game_state.gd:6329-6332` : les rôles s'inversent). **Verdict : DÉJÀ PRIS EN CHARGE ; MINEUR ; coût ≤ 0,14 ms en duel (ROADMAP 27698, 28303 : « rangé sans code »).**

### LUM-10 — Une `hit_light` à ombre par plomb touché

**1. Le code.** Exact. `player.gd:2875-2932` : `rpc_update_hp` (`@rpc("authority", "call_local", "reliable")`) crée à **chaque** appel une `PointLight2D` (`ECLAT`, 400 px, `shadow_enabled = true`, `shadow_item_cull_mask = 1`, énergie 2,0, tween d'1 s puis `queue_free`) ; `take_damage` l'appelle pour chaque plomb (`bullet.gd:_hit_player` → `target.take_damage`) ; la pompe lance 5 plombs à `[0, 20, −20, 60, −60]°` (`game_state.gd:552-553`). Les plombs ± 20° touchent un corps de rayon 18 si `d·sin 20° ≲ 22` (≈ 64 px) : **jusqu'à 3 lumières identiques dans la même image**, uniquement au contact.
**2. La fréquence.** Par coup reçu ; événement. La prémisse de ROADMAP 2506 (« ne s'allume qu'une fois par coup reçu, … pas allumée en nombre ») **est fausse pour une volée de pompe** ; elle était vraie au relevé (rafale de pistolet).
**3. Le coût.** Le moteur ne dessine, pour cette lampe, que les occulteurs de **couche 1** (les murs) : `4 × N_murs × V` avec N_murs ≈ 4-11 et V = 3 viewports (lightmap + capteur de la victime + capteur du tireur à ≤ 264 px) = **48-132 dessins par lampe** (le rapport comptait N = 7-15, corps compris : D4). Les deux lampes en trop : 96-264 dessins ⇒ **0,1-0,7 ms pendant 1 s** au contact. Mais le coût qui compte est **la durée** : à ≈ 3 coups/s, 3 `hit_light` ombrées vivent à la fois (144-396 dessins) — c'est exactement le levier d'**OM6** (« couper son ombre après 0,3 à 0,5 s »), pas l'empilement par plomb.
**4. Les invariants.** Regrouper par image et par victime donne la même image (les énergies s'additionnent) ; ne pas regrouper des coups d'images différentes ; le plafond de 15 lumières par item joue en faveur. Le client exécute lui aussi chaque RPC. **Piège (D1)** : `ECLAT` est tenue **en permanence** par les 240 `Light` du pool de particules (`particle_pool.gd:214, 234, 258`) ; **si le pool retirait ces nœuds (LUM-11), chaque `hit_light` et chaque `ground_flash` deviendrait un ajout d'une texture inédite dans l'atlas des lumières**.
**5. Le statut.** OM6 (ombre de la `hit_light` coupée) et OM4 (« masques neutres pour `hit_light` et `ground_flash` ») la couvrent ; **nouveau** : l'empilement par plomb (une prémisse de la ROADMAP 2506 est fausse). **6. Verdict : CONFIRMÉ (mécanisme) ; ANECDOTIQUE.** *Correctif minimal* : celui d'OM6 ; le regroupement par image est 6 lignes si l'on veut, **sans effet sur la durée**. *Preuve* : recensement par viewport (étendu par masque) après un tir de pompe au contact (`banc_balle_sans_lumiere.gd` pose déjà une rafale).

### LUM-12 + SHA-06 — Vignette de dégâts à alpha 0

**1. Le code.** `player.gd:795-810` : `ColorRect` `PRESET_FULL_RECT`, jamais `visible = false` ; `vignette_rect` est locale (jamais reprise) ; `intensity` n'est écrite qu'en trois endroits (`player.gd:1296, 1300`, `2864, 2868`) ; `damage_vignette.gdshader` : `COLOR.a = … × step(0.03, intensity)` (une `distance`, des `step`, un `fract` : ≈ 15 ALU, **pas 28**). Aucun test ne la lit (`grep` dans `tools/` : aucun `vignette_rect`/`CalqueVignette`). **2. La fréquence.** Par image, un seul quad par vue (le `visibility_layer` du joueur, 2 ou 4,
est écarté par `canvas_cull_mask` — `renderer_canvas_cull.cpp:311-313` — pour l'adversaire et les PNJ). **3. Le coût.** 3,7 Mpx × ≈ 15 ALU + un mélange plein cadre : **0,02-0,1 ms GPU ESTIMÉ** + un appel de dessin (rupture de lot, matériau distinct). **4. Les invariants.** Nul : sous 0,03 le shader sort déjà alpha 0 ; le `CanvasLayer` n'est pas dans un conteneur (`visible = false` est sûr ici,
contrairement au voile). **5. Le statut.** NOUVEAU comme constat, mais **la règle est écrite** : ROADMAP 6871-6878 (« Un effet éteint qui rastérise encore n'est pas éteint, il est invisible… couper l'intensité ne coupe pas le coût, seul le retrait du nœud le fait » — à propos des traits de vitesse, V5.9). La vignette est la même faute. **6. Verdict : CONFIRMÉ ; sévérité ANECDOTIQUE** (SHA-06 : MINEUR ; l'écart est un facteur 2 sur un coût < 0,1 ms).
*Correctif minimal* : `visible = false` à la création ; `visible = intensity ≥ 0,03` posé par **une seule fonction** qui écrit `intensity` (les trois sites) ; `vignette_rect` en variable membre. *Preuve* : compteur d'appels de dessin (`RenderingServer.get_rendering_info`, **indépendant du matériel**) : −1 par vue au repos.

---

## 3. Ce que la lecture du moteur a révélé — faits non demandés

### D1 — L'atlas des textures de lumière est reconstruit en entier à chaque ajout d'une texture inédite (PROUVÉ dans le moteur ; coût et fréquence à mesurer)

*Le moteur* (GLES3, 4.7-stable) : toute `PointLight2D` assigne sa texture via `canvas_light_set_texture` (`renderer_canvas_cull.cpp:2182-2192`, qui ignore une texture inchangée) puis `light_set_texture` (`rasterizer_canvas_gles3.cpp:1612-1631`) : `texture_remove_from_texture_atlas(ancienne)` puis `texture_add_to_texture_atlas(nouvelle)` (`texture_storage.cpp:2286-2306`).
**Un ajout dont la texture n'est tenue par aucune autre lumière pose `texture_atlas.dirty = true`** ; un retrait ne le pose pas. `RendererCanvasCull::update()` (`:2566`) appelle chaque image `update_dirty_resources` → `update_texture_atlas` (`utilities.cpp:395-401`) : si `dirty`, **libère l'atlas, en alloue un neuf** (`glTexImage2D` de `base_size×2` par `nearest_pow2(h×2)`), le **vide** (`glClear`), puis **recopie chaque texture membre**
(`texture_storage.cpp:2325-2480`). Le contenu = toutes les textures tenues par au moins une lumière, **allumée ou non**.
*Le jeu* : (i) chaque tir pose le flash de bouche sur `FLASH[0]`, puis `FLASH[1]` à 1/3 de la durée, puis `FLASH[2]` à 2/3 (`player.gd:2635-2658`, « deux images de rendu chacune ») ; (ii) `FLASH[0]` est tenue en permanence (les deux lumières de bouche + leurs doubles de killcam, `game_state.gd:1689-1730`) ; **`FLASH[1]` et `FLASH[2]` ne sont tenues par personne** (`eclat.texture` est un `Sprite2D`, pas une lumière) ⇒ **chaque tir ajoute deux textures
inédites, donc jusqu'à deux reconstructions d'atlas par tir, chez les deux pairs, pour les tirs de l'un comme de l'autre** (`game_state.gd:4227-4228`). (iii) `ECLAT` est tenue en permanence par les 240 `Light` du pool de particules, dès la première poussière (`particle_pool.gd:214, 234, 258`) : `ground_flash` et `hit_light` n'ajoutent rien — **tant que ce couplage tient** (LUM-11 propose de retirer ces nœuds : ce serait ajouter une reconstruction par tir et par coup).
*La taille de l'atlas* (`v8_work/atlas_lumieres.py`, **port fidèle de l'algorithme** ; entrées = tailles des PNG du dépôt) : un duel à **une** classe : 2048×2048 = **16 Mio** ; à **deux** classes (deux cookies 1 024² distincts) : **2048×4096 = 32 Mio** ; solo, 4 à 7 classes : **4096×4096 = 64 Mio** ; 10 classes : 4096×8192 = **128 Mio**. Cookies rognés : 4 Mio (duel), 8-16 Mio (solo).
*Ce qui n'est PAS établi* : le **prix** d'une reconstruction sur le M3 (un `glClear` de 32 Mio, ≈ 2,4 M texels recopiés, une allocation neuve : ESTIMÉ 0,3-1,5 ms, GPU + pilote) et donc ce que ça pèse sur le 1 % bas ; le banc de cadence **tire** (`bench_framerate.gd:667`, `p.shoot()` à la cadence de l'arme) — **ce coût est déjà dans ses relevés, jamais isolé**. Le jeu, lui, n'a jamais vu l'atlas : « atlas » n'apparaît dans la ROADMAP que pour l'atlas **d'ombres** (Q85) et les glyphes.
*Preuve dans le cloud* (matériel-indépendante pour l'existence, en rapport pour le prix) : un banc de 600 images où une `PointLight2D` change de texture à chaque image entre deux textures non tenues (reconstruction) contre deux textures tenues par une lumière factice (rien) — le surcoût sous llvmpipe dit l'existence et l'échelle (∝ taille de l'atlas : × 8 entre 32 et 4 Mio). *Correctif minimal, sans rien changer d'autre* : faire tenir `FLASH[1]` et `FLASH[2]` par deux `PointLight2D` désactivées permanentes (S).
**Ne pas confondre** avec l'atlas d'**ombres** de Q85 (`rendering/2d/shadow_atlas/size`, `rasterizer_canvas_gles3.cpp:1864-1905`, alloué **une fois**, `size × (max_lights_per_render × 2)` texels : 2048×512 par défaut).

### D2 — `source_eblouissante` n'existe que chez l'hôte : chez le client, le halo et le flou de repos se posent sur l'adversaire (PROUVÉ par lecture ; **non vu à l'image**)

`game_state.gd:2360-2362` : `_maj_eblouissement` sort d'emblée en `ONLINE_CLIENT` ; `game_state.gd:2406` est **la seule écriture** de `cible.source_eblouissante` ; la propriété n'est pas dans la liste répliquée (`player.gd:613-623` : `net_position`, `net_rotation`, `net_flashlight_on`, `net_dazzle`, `net_ack_seq`, `net_accroupi`, `hp`).
Chez le client elle vaut donc **toujours `null`** ; `source_eblouissante_ou(victime, defaut)` (`game_state.gd:5898-5902`) rend alors `defaut`, **l'adversaire** ; le client regarde `vp2` (`game_state.gd:6329-6332`) : `app.maj(p2, p1)`. Au repos (`net_dazzle = 0,06`, torche allumée), `BrouillageVue.maj` place donc l'ellipse du flou à **23,7 px devant l'adversaire** et le halo à **13 px devant lui**, partout où il est dans le champ — et le trou d'exclusion (autour de **soi**) ne protège plus rien.
Chiffres (formules du shader et de `Brouillage`, aucune mesure) : noyau **4,1 px** au centre de l'ellipse (3,4 à d = 0,25 ; 2,0 à 0,5 ; 0,6 à 0,75), couverture 100 %, sur 118×46 px canevas ; halo de 86×36 px, **21/255 au pic**, ≥ 3/255 sur 42×18 px. Le halo est un `TextureRect` **non éclairé** : il se dessine même si l'adversaire est dans le noir ou derrière un mur. Chez l'hôte, au même instant, l'effet est centré sur lui-même (invisible).
*Pourquoi c'est dit ici* : (a) c'est la **correction du « jumeau » du 2026-09-09** (ROADMAP 5800-5820) qui ne tient qu'**hors client** ; (b) **Q81(b)** (« seul le corps qui éblouit s'efface », OMBRES) s'appuie sur `source_eblouissante`, « déjà connue » — **elle ne l'est pas chez le client** ; (c) c'est un argument d'équité **pour** le plancher de Q81(a) (il supprime l'effet de repos des deux côtés) en plus de la performance.
*À vérifier* : un test headless `BrouillageVue.maj(regardeur = p2, emetteur = p1)` avec `p2.dazzle_amount = 0,06` prouve la position et la visibilité (sans réseau) ; l'image, deux machines ou une scène forcée en `ONLINE_CLIENT`.

### D3 — `modulate.a < 0,007` fait sauter l'item au culling

`renderer_canvas_cull.cpp:304-331` : `if (!ci->visible) return;` puis `if (!(ci->visibility_layer & p_canvas_cull_mask)) return;` puis `Color modulate = ci->modulate * p_modulate; if (modulate.a < 0.007) return;`. **Un `Control` d'`modulate.a = 0` n'est pas dessiné et reste dans la mise en page** : la parade au piège de l'`HBoxContainer` (`ui.gd:2436-2451`) que ni la ROADMAP (16993) ni les auditeurs
n'ont envisagée, et que le dépôt pratique déjà ailleurs (`game_state.gd:6058-6071`, « `modulate` et non `visible` »). Même fonction : un item dont le `visibility_layer` est écarté par `canvas_cull_mask` ne coûte rien (la vignette de l'adversaire, LUM-12). Contrepartie, pour LUM-05 : une chauffe en `modulate.a = 0` ne chauffe rien.

### D4 — Deux défauts dans les chiffres d'ombre (rect tourné, masques)

(i) `Transform2D::xform(Rect2)` rend l'**AABB** : un carré de 936 px tourné de 45° couvre **1 324 px de côté** (moyenne sur la visée : 1 192) ; le recensement du banc (`bench_framerate.gd:788-790`) et `solo_ombres.py` (SAT) l'ignorent. (ii) `rasterizer_canvas_gles3.cpp:1719` : une lampe ne dessine que les occulteurs dont la couche croise son `shadow_item_cull_mask`. Effets mesurés par `modele_corrige.py` : § LUM-03 (× 0,65 / × 0,79) et § LUM-04 (−30 % / −54 % au lieu de −33 à −49 / −50 %).
(iii) `light_update_shadow` ne dessine qu'une **bande de 2 lignes** par lampe et par quart de tour (`glViewport(…, p_shadow_index*2, tex/4, 2)`) : le coût est en **appels**, non en texels — l'atlas d'ombres 4096 de Q85 coûte de la **mémoire** (16+16 Mio contre 8+8) bien plus que du temps de passe.

---

## 4. Ce que l'audit doit rendre

### 4.1 NOUVEAU par rapport au chantier OMBRES et à l'audit des lumières

1. **Le coût du brouillage au repos** (LUM-01) : une copie d'écran, un flou 17 prises et un halo, par vue et par image, dès que la torche brûle. OMBRES connaît la cause (0,06) pour l'opacité (O2) mais jamais ce coût ; **il tombe avec Q81(a) si le plancher est posé dans `Brouillage._dose`** (§ 1) — un argument de performance pour Q81 qu'Adrien n'a probablement pas.
2. **Le voile n'est pas couvert par Q81(a)** : autre variable, autre fichier ; l'éteindre au repos est une décision d'image distincte (le noir à 2-4/255). Et un moyen de ne plus le dessiner **sans toucher la mise en page** (D3).
3. **LUM-04 (cookies rognés)** : ni OM6 ni OMBRES ni le « Lot 6 » ne l'écrivent. Géométrie et comportement du moteur **prouvés** ; gain recalculé à l'AABB : −30 % (duel), −54 % (solo) ; **piège ×2 de portée** (`iso_volumes.gd:718`) ; ancre cloud **Q76** (−6 % de temps d'image par ×0,41 de surface de lampe sous llvmpipe).
4. **D1 — l'atlas des textures de lumière** : reconstruit en entier à chaque ajout inédit ; **le flash de bouche en ajoute deux par tir** ; 32 Mio pour deux cookies 1 024², 64-128 Mio en solo. Inconnu du dépôt. À mesurer en premier : si une reconstruction pèse ≥ 0,3 ms, c'est du même ordre que les gestes d'OM6 — et elle touche **chaque tir**, pas seulement les salles lourdes.
5. **D2 — le client** : l'ancrage de repos du flou/halo sur l'adversaire ; `source_eblouissante` non répliquée (Q81(b)).
6. **LUM-06 (moteur lu)** : la chaîne gaussienne de mips est regénérée **à chaque image** d'éblouissement ≥ 0,12 et en killcam ; l'image n'est « identique » qu'à quelques /255 près.
7. **LUM-10** : l'empilement par plomb de la pompe (prémisse fausse de ROADMAP 2506) ; **LUM-12** : la vignette, faute déjà condamnée par ROADMAP 6871.
8. **D4** : deux défauts de modèle (AABB, masques) qui dégonflent les ms d'ombre ; l'étalonnage 2,8 µs est une borne haute (un point, bruit ≥ effet, V ignoré, coût fixe par lampe ignoré).
**Ce qui n'est PAS nouveau** : les leviers de LUM-03, LUM-08, LUM-09 (OM6, solo compris pour LUM-09) ; LUM-05/07 (ROADMAP 22510 ; V1a HUD-08 ; V1b ETA-05 + BOT-10 + SHA-01).

### 4.2 À transmettre à la session OMBRES (des faits, pas des ordres)

* **Variables** : flou, halo et opacité adverse passent tous par `Brouillage._dose` (`brouillage.gd:655`) ; le voile lit `dazzle_amount` à `ui.gd:2536` ; la pénalité de vitesse/visée le lit brut (`player.gd:1787-1807`). La valeur de repos est **0,06 exactement** (× `gain_taille` = 1 tant que `EXPOSANT_TAILLE = 0`, × facteur de lampe ≤ 1), atteinte en 48 ms. Seuils d'allumage : flou d > 0,00526, halo d > 0,00333.
* **`source_eblouissante` est `null` chez le client** (écrite à `game_state.gd:2406`, hôte seulement ; absente de `rep_config`). Aujourd'hui, au repos, le client voit halo + flou sur l'adversaire, l'hôte sur lui-même. Q81(b) « seul le corps qui éblouit s'efface » ne peut pas lire cette propriété chez le client.
* **Moteur 4.7-stable, passe d'ombre** : toute lampe à ombre dont l'AABB de rect croise le viewport est rejouée ; leurs rects fusionnent en un `shadow_rect` ; **chaque lampe redessine tous les occulteurs de la liste dont la couche croise son `shadow_item_cull_mask`** (aucun tri par distance) ; `canvas_cull_mask` ne filtre ni lumières ni occulteurs. Le décompte d'OM6 gagne à se faire **par masque** (les quatre occulteurs de corps ne sont pas tous dessinés par chaque lampe) ; mes chiffres : × 0,79 (duel), × 0,65 (solo, caméra sur le joueur).
* **`PointLight2D.offset`** décale le rect de culling et la texture, **pas l'origine de l'ombre** ; `rect_cache` est l'AABB du rect tourné (jusqu'à × 1,41 de côté pour un carré) ; `radius_cache` = diagonale du rect de **texture**.
* **`UPDATE_WHEN_VISIBLE` sur les capteurs** : le drapeau `used_in_frame` est posé par la **liaison d'un matériau** portant la texture du capteur à un dessin (`material_storage.cpp:2789`, `SceneMaterialData::bind_uniforms`) : un corps hors champ ou caché ne le pose pas ; une image de retard à la rentrée (contenu périmé).
* **Atlas des textures de lumière** : reconstruit à chaque ajout d'une texture inédite (`texture_storage.cpp:2286-2306, 2325-2480`) ; **le flash de bouche (`FLASH[1]`, `FLASH[2]`) en ajoute deux par tir** ; `ECLAT` n'est tenue que par les 240 `Light` du pool de particules (`particle_pool.gd`) — tout geste d'OM4 qui change **quelle lumière tient quelle texture** (flash, `hit_light`, `ground_flash`, masques neutres) ou qui retire ces nœuds change le nombre de reconstructions. Taille : 32 Mio à deux cookies de classe.
* **Q85** : la carte d'ombre est une bande de **2 lignes** par lampe et par quart de tour ; l'atlas 4096 coûte de la mémoire (16+16 Mio) plus que du temps de passe ; allocation unique.
* **Hits** : le coût d'une `hit_light` est dominé par la **durée** de son ombre ; l'empilement par plomb n'arrive qu'au contact avec la pompe ; **trois** lumières ombrées peuvent vivre en même temps sous 3 coups/s.
* **Murs** : recompte reproduit (rects → boucles : 55 → 33 en duel, 1 106 → 711 en solo) ; le joint de 6 px entre rects voisins laisse passer un rayon à ± 11,7° de son axe (calcul, jamais constaté).
* **Bancs** : le recensement de `bench_framerate.gd:767-841` et `compte_occulteurs.gd` ignorent rotation, `offset` et masques ; `loupe.gd:_cout_du_voile` n'a pas de bras « voile masqué » ; `bench_framerate` **tire** (`p.shoot()`), donc ses relevés contiennent déjà le coût d'atlas de D1 ; **Q76** est un précédent de mesure cloud d'une surface de lampe (A C Q Q C A, llvmpipe, −5,8 à −6,6 %).
* **Gardes qui lisent du texte** : `test_classes._test_ancrage_des_effets` lit `brouillage_vue.gd` et `game_state.gd` ; `tools/test_lumieres.gd` n'autorise `texture_scale` que via `LightTextures.poser()` (et `echelle_torche()`).

---

## 5. Reproduire

Scripts (Python, aucun Godot) : `audit/lum/flou_repos.py` (relancé, identique), `audit/lum/occluders.py` (relancé : recompte LUM-08 identique), `audit/lum/cookies.py` (relancé : boîtes identiques), `audit/v8_work/modele_corrige.py` (AABB + masques, § LUM-03/04), `audit/v8_work/atlas_lumieres.py` (atlas de lumières, D1),
`audit/v8_work/voile_lectures_hors_texture.py` (SHA-03 : 62,4 %). Sources du moteur : `audit/v8_work/godot47/` (étiquette `4.7-stable` : `servers/rendering/renderer_viewport.cpp`, `renderer_canvas_cull.cpp`, `shader_compiler.cpp`, `shader_language.h` ; `drivers/gles3/rasterizer_canvas_gles3.cpp`, `rasterizer_gles3.cpp`,
`storage/texture_storage.cpp`, `storage/material_storage.cpp`, `storage/utilities.cpp`, `effects/copy_effects.cpp` ; `scene/2d/light_2d.cpp`). **Limite** : je n'ai exécuté aucun Godot ; tout coût en ms est ESTIMÉ ou emprunté à la ROADMAP avec son numéro de ligne ; les ordres de grandeur sur « coupure de passe » et « reconstruction d'atlas » sont des raisonnements sur un GPU à tuiles, **non mesurés** — c'est écrit chaque fois.
