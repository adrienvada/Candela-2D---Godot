# V1b — Les premières fois à froid : vérification contradictoire

Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12). Lecture seule ; Godot n'a pas été lancé ; aucun fichier du dépôt n'a été touché.
Constats vérifiés : ETA-05, BOT-10, HUD-09, GEO-04, GAD-05, GAD-06, AUD-02, ISO-09 (= SHA-01), ISO-12 (= SHA-12) ; SHA-02 (la chaîne de dix `Shader.new()`)
est vérifié par V9 et cité à sa place dans la liste consolidée (§ 4). Rapports d'origine : `06_ETA`, `12_BOT`, `09_HUD`, `02_GEO`, `07_GAD`, `11_AUD`, `01_ISO`, `03_SHA`.

Conventions. **PROUVÉ** : lu dans le code ou dans un fichier du dépôt (fichier:ligne). **ESTIMÉ** : raisonné, ordre de grandeur sans mesure.
**À MESURER** : rien ne le fonde ; la section « preuve dans le cloud » dit comment. Les numéros de ligne sont ceux du commit `52a29c1`.
Ce que je sais du moteur sans pouvoir le relire (aucun source Godot sur cette machine) est marqué « connaissance du moteur » et listé en § 6.

---

## 0. Verdicts d'un coup d'œil

| Constat(s) | Verdict | Sévérité corrigée | Coût corrigé |
|---|---|---|---|
| **ETA-05 + BOT-10** (même appel : `WeaponData.image_torche()`) | CONFIRMÉ AVEC RÉSERVE | MINEUR (bas) | `image_torche()` : une image, une fois par classe et par processus, hôte/local seulement, 0,5-5 ms ESTIMÉ ; script de gadget : 1-3 ms ESTIMÉ, **deux fois à chaque pose** sans instance vivante (cache faible : très probable, à confirmer par P1) ; masques de balle < 0,3 ms |
| **HUD-09** | CONFIRMÉ AVEC RÉSERVE | ANECDOTIQUE | icône 128² : ≤ 1 ms ESTIMÉ, hors duel (salon/démarrage) ; glyphes : 0,1-1 ms par glyphe, au décompte ou aux premières secondes |
| **GEO-04 + GAD-05 + GAD-06** | CONFIRMÉ AVEC RÉSERVE ; 2 sous-points RÉFUTÉS ; 1 constat NOUVEAU | MINEUR (grilles, scripts, sprites) ; **MAJEUR présumé** pour le constat nouveau (aplat/relief) et pour la part GL | grille de fusée : 14 400 + 9 136 itérations GDScript, 8-20 ms ESTIMÉ, une fois par (type, côté de caméra) ; **aplat + relief : ~0,1 s pour une masse de 336 px selon le commentaire du dépôt (`iso_nuage_voxel.gd:301-303`, estimation dont la méthode n'est pas écrite) ; mon estimation 0,05-0,4 s pour la poussière, 0,02-0,12 s pour la suie, À MESURER (test P1, CPU pur), à CHAQUE pose** |
| **AUD-02** | CONFIRMÉ AVEC RÉSERVE | ANECDOTIQUE (MINEUR pour les stings au premier kill) | WAV QOA ≤ 0,5 ms, Ogg 1-3 ms ESTIMÉ ; sondes ratées : 2 `exists` par tir de 6 classes, 10-60 µs en lancement dev, ~nul en export ; préchargement complet 20-50 ms ESTIMÉ |
| **ISO-09 (= SHA-01 ; SHA-02 → V9)** | CONFIRMÉ AVEC RÉSERVE (mécanisme prouvé, ampleur non mesurée ; un sous-point RÉFUTÉ) | **MAJEUR présumé** | compilation GL : 143-150 ms par sorte de lampe 3D mesurés sur Mac (ROADMAP l. 27613-27622), non mesuré sur les matériaux de jeu ; CPU : dix `Shader.new()` au premier allumage, 10-150 ms ESTIMÉ |
| **ISO-12 (= SHA-12)** | CONFIRMÉ (SHA-12 plus complet : 7 shaders, pas 5) | ANECDOTIQUE | 5-45 ms ESTIMÉ, une fois au lancement ; aucune compilation GL économisée |

Quatre faits que les rapports d'origine n'ont pas vus, et qui changent l'ordre des priorités :

1. **Le cache de ressources du moteur est faible.** Une ressource qui n'est plus tenue par rien est libérée, et son `load()` suivant la relit du disque (texture) ou la recompile (script). « Une fois par session » est donc faux pour tout ce qui n'a pas de détenteur permanent : les scripts de gadget (8 sur 10), les sprites de gadget. § 1.
2. **Le préchauffage de `aplat`/`relief` (suie, poussière) est inopérant** : les caches sont indexés par `get_instance_id()` d'une texture que `prechauffer()` laisse mourir ; le gadget charge sa propre instance. Le calcul GDScript (~0,1 s pour 336 px d'après le commentaire du dépôt) retombe à la pose, à chaque pose. § 3.3.
3. **Deux « premières fois » des rapports sont RÉFUTÉES** : `fusee_corps.png` est déjà chargé au démarrage et tenu par une icône permanente du HUD (`ui.gd:3021-3025`) ; la pré-passe de profondeur des objets partage le programme des corps (dessinés dès l'ouverture de la manche). § 3.3, § 3.5.
4. **Presque tout le reste est petit** (icône, glyphes, sons, masques : ≤ 3 ms, une fois). Le poids est dans trois endroits : le premier allumage de torche (dix `Shader.new()` + deux programmes de 1 584 lignes sources + `image_torche`), les nuages de gadgets (aplat/relief, grille, programmes), et la première fusée.

---

## 1. Réponse transversale : « un `load()` d'une ressource déjà en cache coûte-t-il encore quelque chose ? »

**Deux cas, qu'il ne faut pas confondre.**

**(a) La ressource est tenue par quelqu'un** (un `Ref` vit quelque part). `load()` passe par le cache du chargeur : normalisation du chemin, verrou, recherche dans le cache, jeton de chargement. Pas de disque, pas de décodage, pas d'upload GPU. Ordre de grandeur ESTIMÉ : **5-30 µs** (dont, en lancement de développement, un `stat` sur `chemin.remap`). Négligeable par événement ; pas gratuit en boucle par image (voir ISO-10 : un `load()` par image pour le texte F3). `ResourceLoader.exists(chemin)` d'un chemin en cache rend vrai tôt (même ordre).

**(b) Plus personne ne la tient.** Le cache du chargeur ne retient rien (connaissance du moteur : table de pointeurs nus, la ressource s'en retire à sa destruction ; le cache des scripts GDScript idem). Dès que le dernier `Ref` tombe, la ressource est détruite ; le `load()` suivant refait **tout** : lecture du fichier, décodage (PNG/WebP sans perte), upload, ou analyse + compilation pour un script. **C'est le cas des « premières fois » qui reviennent.**

Conséquence pour un préchauffage : un `load()` jeté ne chauffe rien. Il faut **garder la référence** (variable statique, dictionnaire) — c'est ce que font déjà `AudioManager._stream_cache`, `LightTextures._masques`, `Fusee._cache_textures`, `IsoNuageVoxel._grilles`, `IsoMateriaux._variantes`.

**Inventaire des détenteurs (PROUVÉ par lecture)** :

| Ressource | Chargée par | Tenue ensuite par | À froid à nouveau ? |
|---|---|---|---|
| cookie de torche (texture) | `WeaponData.get_torch_texture()` (`weapon_data.gd:231-239`), à `equip_weapon` | l'objet `WeaponData` (catalogue bâti une fois dans `GameState._ready`, `game_state.gd:592`) | non |
| image du cookie `_torch_image` | `image_torche()` (`weapon_data.gd:288-299`), au premier `lumiere_recue` | le `WeaponData` | non |
| masques de lumière, flash, traînée | `LightTextures.masque` (`light_textures.gd:65-76`) | `_masques` (statique) | non |
| volutes de fusée (1024², 2048², 2048²) | `Fusee.prechauffer` (`fusee.gd:343-348`), à `GameState._ready` | `Fusee._cache_textures` (statique) | non |
| `fusee_corps.png` (1456×720) | **`ui.gd:3021-3025`, à la construction du HUD** (`UI._ready` → `_build_hud`, `ui.gd:1335`) | une `TextureRect` du HUD, permanente | **non** (réfute GAD-06 sur ce point) |
| sprites de jeu des gadgets `gadget_<pièce>.png` | `GadgetBase._texture_de` (`gadget_base.gd:424-429`), à la pose | le seul `Sprite2D` du gadget | **oui**, à chaque pose sans instance vivante (petites images : 0,5-215 Ko) |
| scripts de gadget | `load(chemin)` (`game_state.gd:3508` et `:3796`) | l'instance seule (`GadgetGresillement` et `GadgetPoudre` sont nommés dans du code de `game_state.gd` : très probablement tenus par le code compilé de ce fichier, connaissance du moteur, § 6) | **oui pour 8 des 10** |
| aplats, reliefs, planches réduites | `IsoNuageVoxel.aplat/relief/planche` | dictionnaires statiques **indexés par `get_instance_id()` de la texture source** | fusée : non (volutes tenues) ; **suie/poussière : oui, clé morte** (§ 3.3) |
| grilles de cubes | `IsoNuageVoxel.grille` (`iso_nuage_voxel.gd:404`) | `_grilles` (clé chaîne) | non |
| variantes de shader | `IsoMateriaux.variante_definie` (`iso_materiaux.gd:118`) | `_variantes` (clé `id:nom`) | non |
| flux sonores | `AudioManager.get_audio_stream` (`audio_manager.gd:1479-1506`) | `_stream_cache` (`:1390`) | non (mais les absents ne sont jamais mémorisés) |
| icônes de gadget du HUD | `MenuIcones.recadree` | `_recadrages` (clé = chemin, valeur `AtlasTexture` qui tient la texture) | non |
| éclats de mur, taches de sang | `load` par tache (`wall_impact.gd:74`, `blood_stain.gd:410-411`) | les taches vivantes (≤ 90 / 120) | petit (96 px) |
| planches de marche (8 par classe) | `_precharger_la_planche` (`player.gd:1047-1067`), à `equip_weapon` | le `Player` | à chaque changement de classe (décompte) |

---

## 2. Quand arrive chaque « première fois » (chronologie réelle)

Les faits qui bornent tout : le décompte fige les joueurs et **éteint les torches** (`player.gd:1734-1743` : `countdown_left > 0` → `flashlight_on = false`, vitesse nulle, retour) ; le décompte dure 3 s (`COUNTDOWN_DURATION`, `game_state.gd:178`), 10 s en classé apparié (`:192`) ; il est décrémenté du `delta` réel de l'image (`:2122`), donc une image longue le raccourcit sans rien perdre au jeu.

| Moment | Ce qui se passe pour la première fois du processus | Dans le décompte ? |
|---|---|---|
| Lancement (`Main._ready`) | `GameState._ready` → `rebuild_arena()` (`game_state.gd:628`) → `Fusee.prechauffer(arena)` (`:1565`) : trois volutes, quad du voile ; `Presentation3D` créée en différé → `MiroirsIso.new()` → `IsoVolumes.new()` → `IsoNuageVoxel.prechauffer()` (`iso_volumes.gd:343`) ; `UI._ready` : HUD, icônes de classe, `fusee_corps.png` ; `AudioManager._ready` : musique | hors match |
| Première manche, premières images | `Presentation3D._allumer` : sol, murs, corps voxel, pré-passe, capteurs, `quad_iso` (viseur et ligne de visée), `damage_vignette`, voile calme, `player_*_light` ; `equip_weapon` (cookie 1024² décodé si pas encore fait, 8 PNG de marche) ; icône de gadget de l'adversaire (HUD-09) ; éventails du rayon calculés lampe éteinte (`iso_volumes.gd:688-693`) | **oui** |
| Après « FIGHT » : 1er allumage de torche | éblouissement : `image_torche()` ; 3D : dix `Shader.new()`, programmes couche + juge du rayon, `halo_iso` (lentille) ; son `torch_on` | **non — en plein duel** |
| 1er tir | masques de balle, 3 PNG de flash, `quad_iso_additif`, matériau canvas ADD + non éclairé, `halo_iso` (éclat), sons de tir | non |
| 1re touche | `blood_shader`, 2 PNG de tache, `damage_vignette` (déjà là), `peinture_iso` | non |
| 1re pose de gadget | script (×2), sprites, `capteur_objet`, `VoxelObjet`, nuage (aplat/relief, grille, programme, juge), halos | non |
| 1re fusée | lancer : `Fusee._ready` (sons de lancer et de combustion), vol (~0,5 s) : `halo_iso` (la comète, `_suivre_comete`, `iso_volumes.gd:580`) ; atterrissage : `halo_iso_melange` (lueur au sol et cœur, `:515, 548`), `nappe_fusee`, matériau canvas MIX + non éclairé, grille 9 136 cubes, programme `NUAGE_FUSEE`, juge de nuage | non |
| 1re mort | `death_flash`, bandeau FATAL (glyphes), `killcam_overlay`, `ghost_unshaded`, stings | non (ETA-02, hors V1b) |

**L'affirmation de `tools/banc_pics.gd` (« un pic de compilation se paie une fois par lancement et jamais en match ») est contredite par ce tableau** : tout ce qui suit « FIGHT » arrive en match. Les bancs ne le voient pas parce qu'ils chauffent 30 s avant de mesurer (`bench_framerate.gd`, `WARMUP_SEC`) et lisent le 1 % bas « hors transitoire ». Mais le dépôt a déjà mesuré le phénomène : sur deux prises de 60 s avec un échauffement de 2 s, **53 des 55 images lentes tombaient dans les cinq premières secondes** (`docs/iso/iso12/mesure_fusee.md:172-205` ; 1 % bas 76,6 contre 84,8 pour le témoin sans fusée, 62,1 contre 70,1 avec).

---

## 3. Les blocs

### 3.1 ETA-05 + BOT-10 — image du cookie, scripts de gadget, masques de balle

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : MINEUR (bas).** BOT-10 est le même appel qu'ETA-05 (a) ; ETA-05 en ajoute trois autres. Quatre corrections de fait.

**Le code relu.**

```gdscript
# weapon_data.gd:288-299
func image_torche() -> Image:
	if _torch_image != null: return _torch_image
	var tex := get_torch_texture()
	...
	var img := tex.get_image()                       # lecture GPU (export) — le dépôt le sait (`weapon_data.gd:106-108`)
	if img != null and img.is_compressed(): img.decompress()
	_torch_image = img
# weapon_data.gd:322-323 : lumiere_recue() = Vision.intensite_texture(image_torche(), ...)
# vision.gd:130-155 : le test de cône n'arrive qu'APRÈS img.get_size() — l'image est lue avant de savoir si la cible est dans le cône
```

Appelants remontés (PROUVÉ) :

- Éblouissement : `GameState._process` (par image rendue) → `_maj_eblouissement` (`game_state.gd:2360`) → `_plafond_de_source` (`:2551`) → `_lumiere_recue` (`:2620`) → `_lumiere_du_faisceau` (`:2699`) → `arme.lumiere_recue(...)` (`:2707`). **Le client sort dès la première ligne** (`:2361-2362`, `ONLINE_CLIENT`) : il ne lit jamais l'image par ce chemin. Conditions : `_en_jeu(source)`, `_en_jeu(cible)`, `source.flashlight_on` (`:2622-2625`). En entraînement, J2 est caché (`visible` faux) : aucune lecture.
- Bot : `PerceptionBotNoeud._physics_process` (`perception_bot_noeud.gd:147`) → `_voir` (`:159`) → `Percep.voir` → `eclaire` (`perception_bot.gd:407`) → `intensite_cone` (`:382`) → `arme.call("lumiere_recue", ...)`. Seulement si la torche du bot brûle (`perception_bot_noeud.gd:312-315`) et après un test de ligne de vue.
- Suie : `GadgetVolume._lumiere_entrante` (`gadget_volume.gd:201`), par pas de physique, chez les **deux** pairs.

**Quand (PROUVÉ).** Jamais pendant le décompte : `flashlight_on` est forcé à faux (`player.gd:1736`) et la torche « suit un bouton » (`:1814`). Le premier appel tombe donc à la première image où une torche est allumée après « FIGHT », pour chaque classe (une `WeaponData` par classe, bâtie une fois). Il ne dépend pas du cône : une torche allumée dos à l'adversaire suffit.

**Coût.** `get_image()` est une lecture GPU synchrone d'une texture 1 024² RGBA8 (4 Mo) : le dépôt le dit lui-même (`weapon_data.gd:106-107`, « rapatrie depuis le GPU à chaque appel »). Durée : **ESTIMÉ 0,5-5 ms sur Mac** (mémoire unifiée, peut n'être qu'une copie) ; **jusqu'à une image entière sur un GPU dédié Windows** (attente de la file). Une image longue, une fois par classe et par processus, sur l'hôte seulement : c'est l'ordre du MINEUR. Le 1 % bas n'en bouge pas (une image sur 18 000).

**`load()` en cache ?** Le cookie (texture) est tenu par le `WeaponData` ; `image_torche()` mémorise son résultat. Rien ne revient.

**Les trois autres sous-points d'ETA-05.**

- *Script de gadget (`game_state.gd:3796`)* : **CONFIRMÉ, et pire que dit.** (1) La liste du rapport des scripts « déjà chargés parce qu'un autre script les nomme » est fausse : un balayage des occurrences hors commentaires montre que seuls `GadgetGresillement` (`game_state.gd:3376, 3664, 3772`, `ui.gd:3222…`) et `GadgetPoudre` (`game_state.gd:4014`) sont nommés par du code de jeu ; `GadgetMine`, `GadgetSuie`, `GadgetVolume`, `GadgetLeurre`, `GadgetBraises`, `GadgetOmbre`, `GadgetVoile`, `GadgetTorcheFantome`, `GadgetPoussiere` ne le sont que dans des commentaires (ou dans `tools/`). **Huit scripts sur dix compilent à la première pose.** (2) Ils ne restent pas : le cache est faible (§ 1), donc chaque pose sans instance vivante recompile (scripts de 35 à 343 lignes : 0,5-3 ms ESTIMÉ). (3) `_gabarit_bloquant` (`:3504-3514`) fait `load` + `script.new()` + `free()` **une fois par pose pour tous les slugs** (appelé par `_reculer_hors_des_corps` ← `point_de_pose_libre` ← `spawn_gadget`, `:3348`), pas « à chaque tentative d'un gadget qui arrête les joueurs » : le test `tools/test_tir_et_reserves.gd:804-811` établit que le voile est le seul bloquant. La référence locale `script` meurt au retour, donc `_do_spawn_gadget` (`:3796`) recompile : **deux compilations par pose** pour un gadget sans instance vivante. Gadgets à vie longue (voile, ombre, mine, poudre, grésillement : la manche) : l'instance précédente tient le script au moment de la pose suivante, pas de recompilation.
- *Masques de balle (`bullet.gd:88, 104`)* : CONFIRMÉ mais **ANECDOTIQUE** : `trainee.png` 128², `tracante.png` 256×12 (1,3 Ko et 0,2 Ko), mémorisés dans `_masques`. Même ordre pour les trois PNG de flash (256², `player.gd:2648, 2789`). < 0,3 ms.
- *Sons* : voir AUD-02.

**Invariants.** `image_torche()` doit rester l'image *projetée* (`vision.gd`, ROADMAP l. 8024-8036 selon le rapport) ; ne pas la renommer : `tools/planche_eblouissement.gd:162-170` et `tools/test_banc.gd` gardent des symboles par leur nom. `tools/banc_claustro.gd:282, 301` remet `_torch_image` à `null` : l'idempotence doit tenir. Un préchauffage ne doit instancier **aucun** vrai gadget dans `bullet_container` (`ReplaySystem.record_frame`, l'éblouissement, `PerceptionBotNoeud._lumieres` y balayent les groupes `gadgets`/`fusees`). Aucun tirage `randi()` dans le préchauffage (les bancs reseedent par image). RAM : l'image d'un cookie pèse 4 Mo ; chauffer **les dix classes** ajouterait 24-32 Mo pour rien — ne chauffer que les classes en jeu.

**Statut.** NOUVEAU pour la lecture GPU et la recompilation. La doctrine est DÉJÀ-TRANCHÉE ailleurs (`weapon_data.gd:213-222` : le cookie fabriqué en GDScript au premier équipement était « la même classe de défaut que le shader compilé au premier mort »).

**Correctif minimal.** Dans `_do_start_round`, juste après `p1.equip_weapon / p2.equip_weapon` (`game_state.gd:1985-1986`) : `image_torche()` des armes de `_joueurs_en_lice()` (figurants de l'aventure compris, à la pose de la salle). Un `static var` ou une variable de `GameState` qui **tient** les scripts de gadget des classes en jeu (`load` au même endroit), et une mémoïsation de `_gabarit_bloquant` par slug (résultat `{}` ou `{forme, angle_pose}`, constant). Coût du préchauffage : ≤ 2 lectures GPU + 2-6 ms, pendant le décompte, idempotent.

**Preuve dans le cloud.**
- *Déterministe, headless* : une suite qui monte `main.tscn`, appelle `_do_start_round` et vérifie `_torch_image != null` pour les deux armes **avant** toute torche allumée (aujourd'hui : `null`) ; compteur des `load` de scripts de gadget (cold / tenu / relâché, § annexe).
- *Cache faible, headless, 10 lignes* : `load("res://gadget_mine.gd")` chronométré à froid, tenu, puis après `s = null` : si le troisième est aussi lent que le premier, la recompilation est établie.
- *Ce que le cloud ne peut PAS dire* : le coût de la lecture GPU. Sous `--headless` le moteur de rendu factice garde l'image côté CPU ; et **dans un binaire d'éditeur** (celui de la CI, `Godot_v4.7.1-stable_linux.x86_64`, `00_M_mesures.md`) le serveur de rendu garde en général une copie de l'image de chaque texture 2D chargée (`#ifdef TOOLS_ENABLED`, connaissance du moteur, **à vérifier dans le source 4.7**) : `get_image()` y est gratuit. Si c'est vrai, **aucun relevé local ne peut voir ce coût** — il n'existe que dans un export. D'où le choix : corriger sur principe (correctif de 4 lignes, sans risque), ne pas attendre de mesure.

---

### 3.2 HUD-09 — icône de gadget (lecture GPU) et glyphes

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : ANECDOTIQUE.**

**Le code relu (PROUVÉ).**

```gdscript
# ui.gd:3256-3260 (dans _maj_reserves, appelé par update_hud à chaque image, joueur ET adversaire)
if String(ico.get_meta("slug", "?")) != slug:
	ico.set_meta("slug", slug)
	ico.texture = MenuIcones.recadree(load(chemin)) if chemin != "" and ResourceLoader.exists(chemin) else null
# menu_icones.gd:254-274 : tex.get_image() puis get_used_rect(), mémorisé par resource_path dans _recadrages
```

**Fréquence et moment.** `update_hud` est appelé sans condition à chaque image (`game_state.gd:2342-2345`, menus compris) : la première fois que les deux panneaux voient une classe (au lancement, pour les classes par défaut ; ensuite à chaque changement de classe — au salon, ou à `_do_start_round` pour la classe de l'adversaire côté hôte, c'est-à-dire au plus tard à la première image du décompte). **Jamais en plein duel.** `_recadrages` est un cache fort (la valeur est une `AtlasTexture` qui tient la texture) : une fois par icône et par processus. La fiche de classe du salon réchauffe déjà celle de la classe survolée (`menu_fiche_classe.gd:499`).

**Correction de grandeur.** Les icônes de gadget sont **128×128** (15-22 Ko, `assets/ui/icones/gadget_*.png`), pas une image de 4 Mo : le « 1-5 ms » du rapport est un majorant ; **≤ 1 ms ESTIMÉ** (64 Ko de lecture ; `get_used_rect()` sur 16 384 pixels en C++).

**Glyphes.** CONFIRMÉ : `preload=[]`, pas de MSDF, `allow_system_fallback=true` (`assets/fonts/*.import`). Les atlas se remplissent au premier dessin de chaque (glyphe, taille, contour, graisse). Le décompte (136 px, contour 15, graisse 800) rastérise « 3 », « 2 », « 1 » **pendant le décompte** (joueurs figés : sans effet de jeu) ; les chiffres du chrono et des rechargements s'ajoutent un à un pendant les dix premières secondes (petites tailles, ~0,1-0,3 ms). Le bandeau FATAL (`player.gd:3028`) est ETA-02.

Deux ajouts :
- *Caches de glyphes par `FontVariation`* : `Charte._variation()` (`charte.gd:614-623`) crée un `FontVariation` neuf à chaque appel, y compris pour les nombres de dégâts (`bullet.gd:737`, taille 19-42 px) et le bandeau FATAL. Si les caches étaient par instance, chaque coup repayerait ses chiffres. **Connaissance du moteur : `FontVariation` retrouve la variation déjà créée dans la `FontFile` de base (`find_variation`) pour des réglages identiques, donc le cache est partagé** ; à vérifier en 4.7 (§ 6). Je n'en fais pas un constat.
- *Glyphe hors police* : un balayage des chaînes littérales de tous les `*.gd` de la racine contre la table `cmap` d'Oxanium et de Big Shoulders (script `v1b_work/cmap.py`) trouve **un seul caractère absent des deux polices sur le chemin du duel : « ● » (U+25CF) du libellé de latence** (`ui.gd:1736`, police `Charte.appareil`, affiché dès qu'une latence existe : salon et manche en ligne). Les autres (✓ ⚠ ▸ ▾ ☐ ✕ ✗, flèches) vivent dans les menus, l'éditeur de cartes et des diagnostics. Avec `allow_system_fallback=true`, le premier affichage déclenche la recherche d'une police système (sur macOS, via le système de polices : **À MESURER**, peut dépasser l'icône de plusieurs ordres de grandeur). Il tombe au premier calcul de latence, c'est-à-dire au salon, pas en duel.

**Invariants.** Aucun test ne lit ce code. Mémoire : quelques atlas.

**Statut.** NOUVEAU (aucune mention de glyphes ni de MSDF dans la ROADMAP) ; la proposition HUD-01 (ne plus nourrir le panneau adverse caché) supprimerait aussi l'icône de l'adversaire — elle n'est pas faite à `52a29c1`.

**Correctif minimal.** Aucun pour l'icône (déjà hors duel). Pour les glyphes : rien tant qu'une mesure ne le réclame ; si le décompte hoquette visiblement au premier match, un `Label` hors champ montrant « 3 2 1 FIGHT » à la même taille/graisse/contour au démarrage. Pour « ● » : le remplacer par un caractère présent dans les polices (« • » U+2022 si présent) ou le dessiner ; ou le mesurer.

**Preuve dans le cloud.** Le script `cmap` ci-dessus (statique). Pas de mesure utile : llvmpipe rastérise les glyphes comme le Mac mais sans ses polices système.

---

### 3.3 GEO-04 + GAD-05 + GAD-06 — première fumée, première fusée

**Verdict : CONFIRMÉ AVEC RÉSERVE pour les grilles, les programmes GL non chauffés, `nappe_fusee`, les matériaux canvas partagés, les scripts et sprites de gadget. RÉFUTÉ pour `fusee_corps.png` et pour la pré-passe de profondeur. NOUVEAU (V1b) : le préchauffage d'aplat/relief est inopérant pour la suie et la poussière.**
**Sévérité corrigée : MINEUR pour ce que les rapports décrivent ; MAJEUR présumé pour le constat nouveau et pour la part GL.**

**Les chiffres des grilles, recomptés (PROUVÉ).** `cellules(rayon, rangs, voxel, cote)` (`iso_nuage_voxel.gd:388-401`), voxel « gros » = 35/4 = 8,75 px, `RESSERRE` = 0,22 (`:127`), hauteurs `0,8 / 0,4 / 1,0` tuile : suie rayon 92 → 3 rangs, **1 728 itérations, 1 124 cubes** ; poussière rayon 168 → 2 rangs, **3 528 / 2 176** ; fusée rayon 250 → 4 rangs, **14 400 itérations, 9 136 cubes** (calcul indépendant en Python, `v1b_work`). Une grille par (type, côté de caméra), `MultiMesh` de 48 octets par cube (439 Ko pour la fusée), cache fort `_grilles` : **une fois par processus et par (type, côté)** ; deux côtés en écran scindé (J1 à 45°, J2 à 225° : signes opposés dans `cote_camera`). Les « 18 272 » de la ROADMAP sont bien 2 × 9 136. Réponse à la question « 9 136 cubes par vue ? » : **oui, par grille de fusée, donc par vue/côté.**

**Quand (PROUVÉ).** La grille est bâtie dans `_suivre_nuage_voxel` (`iso_volumes.gd:1589-1628`, sentinelle `Vector2i(9, 9)` ≠ tout côté réel : construction à la première image où le nuage est suivi). Pour la fusée : `_suivre_fusee_en_voxels` n'est appelé qu'à l'atterrissage, dès `alpha_fumee > 0` (`:501-502`) — soit ~0,5 s après le lancer. Jamais pendant le décompte, jamais chauffé : `IsoNuageVoxel.prechauffer()` (`:306-323`) charge le shader (deux objets `Shader` : base et `NUAGE_FUSEE`), les aplats, reliefs et planches ; **aucune grille, aucun dessin**.

**Coût grilles.** CPU pur GDScript : boucle 1 (14 400 itérations avec un `Vector3`, un `Vector2.length()`, un `append`), boucle 2 (9 136 itérations, six écritures). ESTIMÉ **8-20 ms** pour la fusée (5-15 selon le rapport, plausible), 1-3 ms pour la suie et la poussière. Mesurable en headless, sans GPU (§ preuve).

**Sous-point NOUVEAU (V1b) : `aplat`/`relief` recalculés à chaque pose.**

```gdscript
# iso_nuage_voxel.gd:158-161, 200-203 : le cache est indexé par l'identifiant d'instance de la texture
static func aplat(tex):  var cle := tex.get_instance_id() ; if _aplats.has(cle): return _aplats[cle] ...
static func relief(tex): var cle := tex.get_instance_id() ; if _reliefs.has(cle): return _reliefs[cle] ...
# iso_nuage_voxel.gd:312-318 : prechauffer() charge la source dans une variable LOCALE
for nom in ["cartouche_suie", "poussiere"]:
	var dessin := load("res://assets/sprites/gadget_%s.png" % nom) as Texture2D
	aplat(dessin) ; relief(dessin)          # la clé est l'id de `dessin`, qui meurt au retour de prechauffer()
# gadget_base.gd:424-429 : le gadget charge SA texture à la pose (aucun cache statique)
# iso_volumes.gd:1350-1360 : _suivre_gadget_en_voxels -> aplat(visuel.texture), relief(texture_origine) : clé = id de l'instance du gadget
```

Seuls `GadgetBase._texture_de` et `IsoNuageVoxel.prechauffer*` chargent ces deux sprites (balayage de `*.gd`). Personne ne tient l'instance de `prechauffer()` : au retour elle est libérée, le gadget charge une **nouvelle** instance (autre identifiant), `_aplats`/`_reliefs` ratent, et les boucles GDScript par pixel (`relief` : trois boucles sur `n` pixels, `aplat` : une) tournent à la première image du nuage. Le cache ne sert ensuite qu'**à l'intérieur de la vie d'un gadget** (le suivi relit `relief` à chaque image) et quand l'instance précédente est encore vivante (remplacement d'un gadget à vie longue : jamais la suie ni la poussière, qui meurent en 9 et 7,5 s pour une recharge de 60 s). Le dépôt évalue lui-même l'enjeu : « une masse de 336 px se repeint en ~0,1 s de GDScript : un à-coup pile au moment où l'on pose la fumée » (`iso_nuage_voxel.gd:301-303`, sans méthode écrite : estimation). Mon propre ordre de grandeur, par le nombre d'itérations : quatre boucles GDScript sur tous les pixels (une pour `aplat`, trois pour `relief`), soit 4 × 113 000 itérations pour la poussière (336², `gadget_poussiere.png`) et 4 × 34 000 pour la suie (184²) ; à 0,2-0,6 µs l'itération (lectures et écritures de `PackedByteArray`, `roundi`), 0,1-0,3 s et 0,03-0,1 s, plus quelques ms de réductions et de redimensionnement en C++ — **ESTIMÉ, À MESURER** (P1 ci-dessous : CPU pur, valable sous llvmpipe comme majorant). Le terme est sur le fil principal, à l'image où le nuage apparaît. Chaque pose, sur les deux pairs (chacun suit sa vue), s'y ajoute en plus au travail inutile du lancement. Les tests existants (`tools/test_fumee_voxel.gd:448-449`) vérifient « le même objet d'un appel à l'autre » **avec la même texture tenue** : ils ne peuvent pas le voir. Les entrées périmées restent dans les dictionnaires (≈ 0,3-0,9 Mo par pose) : une fuite lente, bornée par le nombre de poses.

Sévérité présumée **MAJEUR** (récurrent, GDScript, sur l'action « poser une fumée ») ; **non confirmé tant que le test de cinq lignes n'a pas tourné** (§ annexe). La fusée est épargnée : ses planches viennent des volutes, tenues par `Fusee._cache_textures` ; `IsoNuageVoxel.prechauffer` les relit dans la même instance (`Fusee.prechauffer` passe avant, `game_state.gd:628`).

**Correctif minimal (nouveau).** Une ligne dans `prechauffer()` : tenir les deux textures sources dans une variable statique (`_sources.append(dessin)`) ; `GadgetBase._texture_de` rend alors, par le cache du chargeur, la même instance et les clés tiennent. Variante plus robuste : indexer par `resource_path`.

**Programmes GL (GEO-04, GAD-05, GAD-06).** CONFIRMÉ : le seul dessin de chauffe du dépôt est le quad du voile (`fusee.gd:343-358`). Rien ne dessine `nuage_voxel_iso` (base ou `NUAGE_FUSEE`), le juge de nuage, `nappe_fusee` (`fusee.gd:20, 265-281`), `halo_iso_melange`, les `CanvasItemMaterial` partagés (voir § 4). Le même appel de compilation, au même instant, pour tous : voir ISO-09.
- *Pré-passe de profondeur (GEO-04)* : **RÉFUTÉ.** `VoxelObjet` et `VoxelCorps` chargent les mêmes ressources `corps_iso.gdshader` et `corps_iso_profondeur.gdshader` (`voxel_objets.gd:74-75, 136, 152` ; `voxel_corps.gd:81-84`) ; dans la configuration par défaut `accorder_corps` ne pose aucune variante (`iso_materiaux.gd:247-265`, drapeaux éteints) et la pré-passe reste le shader ordinaire (`:300-303`). Les corps des deux joueurs sont dessinés dès l'ouverture de la manche : le programme est déjà compilé à la première pose d'un objet.
- *`fusee_corps.png` (GAD-06)* : **RÉFUTÉ.** Chargé au lancement par le HUD (`ui.gd:3021-3025`) et tenu par une `TextureRect` permanente ; le `load` de `Fusee._ready` (`fusee.gd:250-254`) tombe sur le cache (§ 1 cas a). Fragile : si le HUD cesse de la tenir, le décodage (WebP sans perte, ~1 Mpx, 10-30 ms ESTIMÉ) retombe à chaque lancer.
- *Sprites et scripts de gadget (GAD-06)* : CONFIRMÉ, et ce n'est pas « à la première pose » mais « à chaque pose sans instance vivante » (§ 1, § 3.1). Petit : sprites de 12×12 à 336×336 (le plus gros, `gadget_poussiere.png`, 215 Ko : 2-5 ms de décodage ESTIMÉ).

**Invariants à respecter (gardes textuelles).**
- `tools/test_fumee_voxel.gd:143-149` : `iso_nuage_voxel.gd` ne contient aucun `preload(` et exactement un `load(CHEMIN_SHADER)` ; `IsoVolumes._init` contient exactement un `IsoNuageVoxel.prechauffer()` sous `\tif fumee_voxel:` ; `src.count("_suivre_nuage_voxel(") == 4` et `_suivre_fusee_en_voxels(` / `_suivre_gadget_en_voxels(` == 2 : **un préchauffage qui dessinerait en réutilisant ces fonctions casserait la suite** ; il doit appeler `IsoNuageVoxel.grille/materiau` directement. `:612-613` : sous `--fumee-couches` le shader ne doit jamais être chargé. `tools/test_nappes_voxel.gd:113` : même garde pour `prechauffer_nappes()`.
- Noir absolu : le dessin de chauffe n'écrit rien (alpha de sortie nul posé **dans un uniforme**, pas sur `modulate`, qu'un item quasi transparent fait sauter : c'est ce que `fusee.gd:355` fait).
- Une chauffe ne doit instancier ni `Fusee` ni `Gadget*` dans `bullet_container`.

**Statut.** GEO-04 : CONNU-OUVERT (ROADMAP l. 31299-31302, 27517-27521) ; GAD-05 grilles : NOUVEAU ; GAD-06 : CONNU-OUVERT (l. 22509-22513, 22431-22433) ; aplat/relief inopérants : NOUVEAU.

**Ce que le préchauffage demande.** Grilles : appeler `IsoNuageVoxel.grille(...)` pour (suie, poussière, fusée) × côté(s) de caméra des vues projetées, à la première image où `_vues` est connu (`IsoVolumes.suivre`) ou dans `Presentation3D._allumer` ; 8-20 ms + 3-8 ms, une fois (×2 en écran scindé). Textures sources tenues (0 ms). Programmes : voir ISO-09.

**Preuve dans le cloud.** (1) Headless : `Time.get_ticks_usec()` autour de `IsoNuageVoxel.grille("fusee", 35.0, 8.75, Vector2i(1, 1))` — CPU pur, indépendant du GPU (la machine cloud est plus lente que le Mac : un majorant). (2) Headless, 5 lignes : `IsoNuageVoxel.prechauffer()` ; `var t = load(".../gadget_poussiere.png")` ; afficher `IsoNuageVoxel._reliefs.has(t.get_instance_id())` (attendu `false` si le constat est vrai) et le temps de `relief(t)`. (3) Un compteur de `_reliefs.size()` avant/après deux poses espacées de plus de 10 s.

---

### 3.4 AUD-02 — aucun préchargement des sons

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : ANECDOTIQUE (MINEUR pour les stings Ogg au premier kill).**

**Le code relu (PROUVÉ).** `get_audio_stream` (`audio_manager.gd:1479-1506`) : cache `_stream_cache` (`:1390`, dictionnaire fort) ; fichier absent : `ResourceLoader.exists(path)` puis, pour `.wav`/`.ogg`, `exists(alt_path)`, puis `return null` **sans rien mémoriser** ; sinon `load(path)` synchrone au moment de jouer. Aucun appelant ne précharge (hors `fusee.gd:305` et `screen_audio.gd:489`). Chiffres vérifiés : 44 entrées WAV dans `SOUNDS`, 96 WAV en tout (64 `sfx/` + 24 `weapons/` + 8 `voice/`), 4 stings Ogg (`sting_kill`, `sting_kill_match`, `sting_defeat`, `sting_draw`) ; seules 4 classes sur 10 ont des échantillons d'arme (`weapon_{pistolet,fusil,pompe,arbalete}_0N.wav`, `weapon_dry_*`, `weapon_reload_*`).

**Quand.** À la première occurrence de chaque fichier (variante tirée au hasard, `randi_range(1, 4)` pour les tirs) : premiers tirs, premiers pas (8 variantes), première mort, première fin de manche — c'est-à-dire en match. Chaque chargement est un événement isolé de 0,1-0,5 ms (WAV en QOA, `compress/mode=2` : fichiers de 10-100 Ko, conservés compressés) ; les stings Ogg 1-3 ms (ESTIMÉ). Une trentaine d'événements dans les premières minutes ; aucun n'est cumulatif.

**`load()` en cache ?** Oui, fort (`_stream_cache`) : une fois par fichier.

**Les sondes ratées (« re-sondés à chaque tir »).** Vrai : pour les six classes sans échantillon (fumiste, incendiaire, sentinelle, occulteur, allumeur, spectre), chaque tir fait **2 `ResourceLoader.exists` ratés** (`play_weapon_shot`, `:1796-1801`), chaque clic à vide aussi, et chaque rechargement 1 `exists` sur une clé qui n'est pas un chemin (`play_weapon_reload`, `:1930-1934`). Coût : le chargeur normalise le chemin, regarde le cache, puis essaie `.remap`/`.import` sur le disque : **10-60 µs par tir ESTIMÉ en lancement de développement, ~1-4 µs en export (recherche dans le paquet)** ; à 2-11 tirs par seconde, c'est 0,02-0,7 ms/s. Négligeable ; le cache négatif est correct mais ne rapporte rien de mesurable.

**Ce que le préchargement demande.** Une méthode `precharger()` parcourant les chemins que les tables connaissent déjà (`SOUNDS` hors musique interactive, `VARIANTES_SFX`, `chemin_tir`/`chemin_percuteur` pour les slugs des classes) et remplissant `_stream_cache` : 96 `load` ≈ **20-50 ms ESTIMÉ**, soit au lancement (autoload, avant la première image), soit via `ResourceLoader.load_threaded_request` (aucun à-coup), soit étalé sur le décompte. +2,4 Mo de mémoire (ESTIMÉ). Le contrôle de présence reste (règle « câbler, taire »). Pas de cache négatif nécessaire ; s'il est ajouté, l'invalider pour que `test_musique` voie toujours « absent : câbler, taire ».

**Invariants.** `tools/test_musique.gd` lit quatre fois le texte de `audio_manager.gd` (`:426, 495, 501, 865`) pour des chaînes précises (`poser_limiteur()`, la garde d'occlusion, `ecoute_somme`, `jouer_acouphene_mort`) : un ajout ne les touche pas, une réécriture de `get_audio_stream` oui. Les trois gestes de l'oreille (CLAUDE.md) ne sont pas concernés. Le préchargement ne tire aucun `randf()`/`randi()` global.

**Statut.** NOUVEAU (aucun préchargement audio dans la ROADMAP).

**Correctif minimal.** `precharger()` au lancement, via fil. Pas de cache négatif.

**Preuve dans le cloud.** Headless (le pilote audio factice charge tout de même les ressources) : `get_audio_stream(chemin)` chronométré à froid puis à chaud pour chaque chemin des tables (et vérification que tous les chemins de `SOUNDS`/`VARIANTES_SFX` sont dans le jeu préchargé) ; un compteur du nombre d'appels qui rendent `null` pendant 100 tirs d'une classe sans échantillon.

---

### 3.5 ISO-09 = SHA-01 — aucun programme GL iso n'est chauffé (SHA-02 : V9)

**Verdict : CONFIRMÉ AVEC RÉSERVE (le mécanisme est établi par le code et par une mesure du dépôt ; l'ampleur sur les matériaux de jeu n'est mesurée nulle part). Un sous-point RÉFUTÉ. Sévérité : MAJEUR présumé.** SHA-01 (`03_SHA`, § 1.2 et § 3) donne la liste des moments un par un ; ISO-09 n'en cite que cinq.

**Ce qui est prouvé.**
- Le seul dessin de chauffe du dépôt est `Fusee.prechauffer` (`fusee.gd:343-358`) ; `IsoNuageVoxel.prechauffer` avoue ne pas compiler (`iso_nuage_voxel.gd:301-305`). Les commentaires « shader préchargé : compilé au démarrage » (`death_flash.gdshader:18-19`, `blood_stain.gd:30-31`, `capteur_corps.gd:66`) confondent charger et compiler ; la ROADMAP l'avait écrit (l. 22509-22513).
- Le rayon de la torche n'existe pas tant que la lampe est éteinte : `_suivre_faisceau_air` rend la main sans créer de nœud (`iso_volumes.gd:694-695`) ; les couches et le juge naissent à l'allumage (`:701-713`). La lentille (`halo_iso`) aussi (`:1186-1202`, `part <= 0 → continue` avant `_entree`). L'éclat de bouche crée ses halos à la première image mais les garde invisibles (`:1144-1160`, `mi.visible = intensite > 0,002`) jusqu'au premier tir.
- Ce qui est déjà fait pour ce moment : les éventails du rayon sont calculés lampe éteinte, au décompte (`:688-693`, commentaire explicite « jamais à l'image où la lampe s'allume, où ce serait un hoquet ») — la géométrie CPU, pas les programmes.
- Mesure du dépôt sur le même matériel et le même pilote : « les hoquets de 143 à 150 ms sont des COMPILATIONS au premier allumage d'une sorte de lampe » (ROADMAP l. 27613-27622), tombés à 16-40 ms par la chauffe par couverture ; et l. 27616-27618 : en écran scindé « chaque vue a SES matériaux, et la chauffe ne couvre que ceux de la vue de J1 ». Ces shaders sont ceux de la lumière 3D (éteinte en jeu) : **la preuve porte sur le mécanisme, pas sur les matériaux de jeu**. Indice indirect sur les matériaux de jeu : 53 des 55 images lentes dans les cinq premières secondes d'une mesure après 2 s de chauffe (`mesure_fusee.md:172-205`).

**Le premier allumage de torche, tel que le code le fait (PROUVÉ).**

1. `_couches(e, 3, FORME_POCHOIR, true)` → `_materiau_volume` → `_poser_forme_imposee` : `variante_forme(variante_masque(usure), 3)` puis `FAISCEAU_LUMINEUX` = **6 `Shader.new()`** : `FUMEE_MASQUE`, `USURE_ESSAI`, `MASQUE_COMPACT`, `MASQUE_RESSERRE`, `MASQUE_POCHOIR`, `FAISCEAU_LUMINEUX`.
2. `_poser_juge` → `_variante_juge_de` : `variante_juge(usure, 5)` = + `MASQUE_LUMIERE`, `MASQUE_AJUSTE`, `MASQUE_POCHOIR_JUGE`, puis `FAISCEAU_LUMINEUX_JUGE` = **4 `Shader.new()`**.
3. Total **10 objets `Shader`**, dont 2 seulement dessinés (les huit autres sont des étapes intermédiaires de la chaîne `variante_definie`, `iso_materiaux.gd:118-129`). Recompté ici, d'accord avec SHA-02 (vérifié par V9) ; ISO-09 disait « jusqu'à 8 ».
4. Chaque `code =` relance le préprocesseur d'`#include` et l'analyse du moteur sur ~1 584 lignes sources (`volume_iso` 249 + `iso_pate` 318 + `iso_lightmap` 90 + `volume_masque` 475 + `iso_usure` 163 + `volume_masque_compact` 289) : CPU synchrone, **ESTIMÉ 1-15 ms chacun (10-150 ms au total) — À MESURER** (SHA-02 : 10-30 ms ; mon estimation haute vient de la taille des sources).
5. À l'image suivante, le premier dessin compile le **programme couche** et le **programme juge** (deux programmes de 1 584 lignes sources) + `halo_iso` (lentille, 72 lignes) : GL, synchrone, **143-150 ms l'unité si le cas de la lumière 3D est représentatif**.
6. Dans le même instant : `image_torche()` (§ 3.1), le son `torch_on`, la lumière 2D de la torche.

**Sous-point RÉFUTÉ : « première mort (`quad_iso` de l'onde) ».** L'onde de mort utilise `SHADER_TRAIT` = `quad_iso.gdshader` (`iso_volumes.gd:42, 1271`), **la même ressource** que `MiroirsIso.SHADER_QUAD` (`miroirs_iso.gd:27`), employée par la ligne de visée et le viseur de chaque joueur dès l'ouverture de la manche (`_suivre_joueurs`, `miroirs_iso.gd:318-345`, `_quad(..., false)`). Le programme est déjà compilé. Les premiers dessins de `quad_iso_additif` (balles) et de `capteur_objet` (canvas, 11 lignes, `light_only`) restent réels mais petits.

**Appelants remontés.** `Presentation3D._process` → `_suivre` → `MiroirsIso.suivre` → `IsoVolumes.suivre` (`miroirs_iso.gd:150-190`, `iso_volumes.gd:409-456`), à chaque image rendue ; première exécution des branches ci-dessus au premier événement.

**`load()` en cache ?** Les `Shader` sont tenus par `IsoMateriaux._variantes` (fort) et par les constantes `preload` : une fois par processus, jamais à nouveau.

**Invariants.** (1) *Même clé de variante* : un dessin de chauffe qui activerait une autre variante que le dessin réel ne chauffe rien (le piège écarté par `fusee.gd:337-342` pour son voile). Les variantes de `volume_iso` se choisissent par `variante_masque(IsoMateriaux.usure_essai_active())` + `variante_forme` + les `#define` de lumineux : **réutiliser les mêmes fonctions**. (2) Pour le canvas, le moteur compile très probablement une variante par état d'éclairage (SHA-01, ESTIMÉ) : le quad de `Fusee.prechauffer` est posé en (0, 0) de l'arène ; s'il est hors du cadre de la caméra de la lightmap à l'image où il vit, **rien n'est dessiné** (un objet hors champ ne compile rien, `bench_framerate.gd:724-725`) — l'existant n'a jamais été prouvé par un relevé avec/sans. (3) *Noir absolu et équité* : sortie nulle (uniformes), pas de vraie `Light2D`, pas de pochoir écrit par le juge de chauffe ; chauffer **les deux vues** en écran scindé (matériaux par vue). (4) Gardes textuelles : voir § 3.3 (`test_fumee_voxel`), `tools/test_masque_formes.gd`, `tools/test_allegement_faisceau.gd`, `tools/test_iso_gadgets.gd`, `tools/test_banc.gd` lisent `iso_volumes.gd`/`presentation_3d.gd`. (5) Le MSAA ×4 de la fenêtre et de la sous-vue ne change pas le programme, mais l'idée d'ISO-09 de dessiner dans un `SubViewport` 1×1 diffère de la cible réelle : **dessiner dans le viewport réel**, un maillage d'un pixel dans le champ de la caméra locale.

**Statut.** CONNU-OUVERT pour la lumière 3D (ROADMAP l. 27519-27521 « noté pour le plan des lots, pas fait ici » ; l. 27613-27622 la preuve) ; la doctrine générale est DÉJÀ-TRANCHÉE (CLAUDE.md, ROADMAP l. 22509-22513, 22431-22433) ; son application à l'iso de jeu est inédite.

**Correctif minimal, en deux temps.**
1. *CPU, sans risque, mesurable dans le cloud* (SHA-02, vérifié par V9) : composer les `#define` en **une seule** passe (`variante_definies(shader, [noms])`, une `Shader` par variante finale : 4-5 au lieu de 10), ou créer les variantes finales au chargement à côté de `IsoNuageVoxel.prechauffer()`. Garder la clé `id:nom` et `_formes_posees` (filtre par identité de `_pousser_lightmaps`, ROADMAP l. 4086-4092).
2. *GL, pendant le décompte de la première manche* : dessiner une fois, sortie nulle, dans la vue regardée (les deux en écran scindé), les programmes de la liste § 4-B, **un ou deux par image** pour ne pas figer le décompte, derrière un drapeau statique ; plus une garde headless (§ 4-D).

**Preuve dans le cloud.**
- *Couverture, déterministe, headless* : voir § 4-D (ensemble des `Shader` effectivement présents sur des nœuds visibles, après le décompte puis après un duel scripté ; la différence doit être vide).
- *Coût CPU des variantes, sous xvfb + llvmpipe* (pas `--headless` : le moteur factice ignore `shader_set_code`) : `Time.get_ticks_usec()` autour de la première série de `variante_definie` ; c'est du CPU pur, valable pour l'ordre de grandeur.
- *Compilation GL, relative seulement* : `tools/cadence_cloud/prise.sh` avec `--seuil-lent 1`, torche allumée à t = 5 s après une chauffe de 2 s, `MESA_SHADER_CACHE_DISABLE=true` (le cache disque de Mesa, `prise.sh` le garde par défaut, masquerait la compilation), lire la pire image dans les 2 s qui suivent chaque événement, avec et sans chauffe. llvmpipe n'est pas le pilote d'Apple : l'ordre des événements, pas les millisecondes.

---

### 3.6 ISO-12 = SHA-12 — shaders et script d'un chemin éteint, préchargés au lancement

**Verdict : CONFIRMÉ. Sévérité : ANECDOTIQUE.** SHA-12 est plus complet : sept shaders, pas cinq.

**Le code relu (PROUVÉ).** `presentation_3d.gd:107-117` : `SHADER_SOL_ECLAIRE` (391 lignes), `SHADER_MUR_ECLAIRE` (418), `SHADER_CORPS_ECLAIRE` (418), `SHADER_PATE_ECRAN` (22), `SHADER_PATE_VUE` (16), `SHADER_CORPS` (`corps_grossier_iso`, 126), `SHADER_CORPS_PROFONDEUR` (`corps_profondeur_iso`, 37, identique à `corps_iso_profondeur` hors commentaires selon SHA) et `LumieresIsoT := preload("res://lumieres_iso.gd")` (410 lignes). Leurs seuls usages : `poser_lumiere_3d` (`lumiere_3d := false` par défaut, `:263` ; appelée uniquement par des outils), `_accorder_la_pate_ecran` (`variante_pate_3d := 0`, `:274`, et le matériau de vue est créé à vide à chaque image), `--corps-grossiers`. Aucun n'est jamais dessiné en jeu.

**Coût.** Au lancement seulement : le `preload` charge le texte et le moteur l'analyse (préprocesseur d'`#include` + analyse). SHA-12 : 1-3 ms par shader ; ISO-12 : quelques ms à quelques dizaines — **ESTIMÉ, non mesuré, 5-45 ms au total** ; pas de compilation GL économisée (jamais dessinés).

**Pourquoi c'est surtout une affaire de principe.** Les constantes disent exprès « préchargés comme les autres : aucun shader compilé à la volée au premier allumage » (`presentation_3d.gd:105-106`) : c'est la doctrine pour le jour où la lumière 3D sera allumée (GO réduit, ROADMAP l. 27650+, Q20 ouverte). Un `preload` ne protège de toute façon pas de la compilation GL (§ 3.5).

**Invariants.** (1) `tools/test_banc.gd:325-372` lit les **fichiers** `.gdshader` par chemin (`FileAccess.get_file_as_string("res://%s.gdshader")`) pour garder la parité sol/mur/corps 2D ↔ éclairés : **déplacer les fichiers vers `tools/` casserait cette garde ; passer les constantes en `load()` à la demande non**. (2) Le piège de la ROADMAP « un `preload` en tête de fichier compile avant les autoloads » (l. 8962-8975) joue en faveur de `load()` après la première image. (3) `poser_lumiere_3d(true)` est l'unique chemin qui assigne ces shaders : un `load()` y suffit ; les bancs (`banc_lumiere3d`, `bench_framerate`, photographe, `test_iso_torches3d`) passent par lui.

**Statut.** SHA-12 : NOUVEAU pour les forks, CONNU-OUVERT pour `distorsion_eblouissement` (ROADMAP l. 22506-22508). ISO-12 : NOUVEAU.

**Correctif minimal.** Ne rien faire tant que la lumière 3D n'est pas tranchée (Q20) : le gain est de 10-45 ms au lancement, et le risque d'une dérive miroir est dans les gardes. Si on le fait : `load()` dans `poser_lumiere_3d` et `_accorder_la_pate_ecran` seulement, fichiers en place.

**Preuve dans le cloud.** Sous xvfb : `Time.get_ticks_usec()` autour de `load("res://sol_iso_eclaire.gdshader")` etc. (le moteur de rendu réel est nécessaire pour l'analyse GLSL) ; headless : la présence des constantes n'est pas mesurable.

---

## 4. Liste consolidée : ce qu'un préchauffage devrait couvrir, et ce qui existe déjà

Pour chaque ligne : quand a lieu le premier usage, ce que le dépôt fait déjà, ce qu'il faut couvrir, coût de la couverture (ESTIMÉ), source. Les moments « décompte » sont ceux d'un premier match ; tout est idempotent par drapeau statique.

### A. Ressources et calculs CPU (sûr, petit, prouvable en headless)

| # | Élément | Premier usage | Existe déjà ? | À couvrir | Coût de la couverture |
|---|---|---|---|---|---|
| A1 | `WeaponData.image_torche()` des armes en jeu (+ figurants) | 1er allumage de torche après FIGHT (hôte/local) ; 1er pas de bot qui voit | non ; le cookie (texture) est chargé à `equip_weapon` | appel après `equip_weapon` (`game_state.gd:1985-1986`) et à la pose de la salle (aventure) | ≤ 2 lectures GPU, 0,5-5 ms chacune (ETA-05, BOT-10) |
| A2 | Scripts des 8 gadgets non nommés + `_gabarit_bloquant` | chaque pose sans instance vivante (×2) | non | tenir les scripts des classes en jeu (ou des dix : 10-30 ms) ; mémoïser `_gabarit_bloquant` par slug | 2-6 ms au décompte ; ensuite 0 |
| A3 | Sprites de gadget (`gadget_<pièce>.png`, 12² à 336²) | chaque pose sans instance vivante | non (cache faible) | tenir les textures des classes en jeu | < 5 ms |
| A4 | **Textures sources de la suie et de la poussière** (clé d'`aplat`/`relief`) | chaque pose de suie/poussière | **inopérant** (`prechauffer` les relâche) | tenir les deux textures dans une variable statique (1 ligne) ; ou clé par chemin | 0 ms ; retire ~0,03-0,1 s par pose (NOUVEAU V1b) |
| A5 | Grilles de cubes (suie, poussière, fusée) × côté(s) de caméra | atterrissage de la 1re fusée ; 1re suie ; 1re poussière | non | `IsoNuageVoxel.grille(...)` pour les types et côtés des vues projetées (sans passer par `_suivre_nuage_voxel`, garde textuelle) | 8-20 ms (fusée) + 2-6 ms (suie et poussière), ×2 en écran scindé |
| A6 | Masques de lumière : `TRAINEE`, `tracante.png`, `FLASH`×3, `AMBIANTE`, `RETRODIFFUSION`, `ECLAT` | 1er tir, 1re fusée | cache `_masques` rempli au 1er usage | `LightTextures.precharger()` | < 1 ms |
| A7 | Sons : 96 WAV + 4 stings | 1re occurrence de chaque fichier | non (musique interactive seulement, `_ready`) | `AudioManager.precharger()` (fil ou lancement) | 20-50 ms ; +2,4 Mo (AUD-02) |
| A8 | Volutes de la fusée (3 PNG sans perte dont deux 2048²) | 1re manche | **oui** : `Fusee.prechauffer` au lancement (l'en-tête dit « 8,5 ms » : mesure du repli procédural, périmée depuis les planches peintes ; coût réel de démarrage hors V1b) | — | — |
| A9 | `fusee_corps.png` | 1er lancer | **oui, par le HUD** (`ui.gd:3021-3025`) | — (fragile : dépend de ce détenteur) | — |
| A10 | Planches réduites de la fusée (`planche`) | atterrissage | **oui** : `IsoNuageVoxel.prechauffer` (clé tenue par les volutes) | — | — |
| A11 | Taches de sang, éclats de mur, flash (PNG 96-256 px) | 1re touche, 1er impact | non | optionnel (tenir 4-6 textures) | ANECDOTIQUE |
| A12 | Éventails du rayon (`_eventails_du_faisceau`) | 1er allumage | **oui** : calculés au décompte, lampe éteinte (`iso_volumes.gd:688-693`) | — | — |
| A13 | Planches de marche, sprites statiques, cookie (textures) | changement de classe | **oui** : `equip_weapon` (`player.gd:1047-1067`, `weapon_data.gd:231`) | — | — |
| A14 | Icône de gadget du HUD, glyphes du décompte et des chiffres de dégâts | salon, décompte ; 1er coup au but | partiel : cache d'icône ; glyphes : non | `Label` hors champ « 3 2 1 FIGHT » (optionnel) ; chiffres de dégâts : une taille de police par valeur de dégâts (`bullet.gd:737-742`, de `T_APPUI` à `T_VERDICT`), donc quelques tailles × 10 chiffres rastérisés au fil des premiers coups, 0,1-0,5 ms ESTIMÉ chacun | < 5 ms (HUD-09) |
| A15 | `Shader.new()` des variantes de `volume_iso` (10 au 1er allumage) | 1er allumage de torche ; 1re pose de nuage/nappe | non (**SHA-02 → V9**) | une passe par variante finale, ou création au chargement | économise ~6 analyses (10-150 ms ESTIMÉ) |
| A16 | Planches de marche (8 PNG de 56-62 px par classe, 1-3 Ko) | chaque `equip_weapon` | oui à chaque équipement, mais `_poses_peintes.clear()` relâche avant de recharger (`player.gd:1047-1067`) : re-décodage de 8 petits PNG par joueur et par manche, pendant `_do_start_round` | non-sujet pour V1b (répété, pas « première fois ») | ≈ 0,3-1 ms par équipement, ANECDOTIQUE |

### B. Programmes GL à compiler (il faut DESSINER, dans le viewport réel, sortie nulle)

Comptes issus de la lecture (ESTIMÉ ; SHA-01 donne ≈ 15 programmes spatiaux et ≈ 17 sources canvas au total). Variantes de `volume_iso` (chaîne `variante_definie` : `FUMEE_MASQUE` → `USURE_ESSAI` → `MASQUE_COMPACT` → `MASQUE_RESSERRE` → `MASQUE_POCHOIR` → `MASQUE_LUMIERE` → `MASQUE_AJUSTE`, puis `MASQUE_POCHOIR_JUGE`, `FAISCEAU_LUMINEUX`, `FAISCEAU_LUMINEUX_JUGE`) :

| # | Programme | Premier dessin | Existe déjà ? | Remarque |
|---|---|---|---|---|
| B1 | `volume_iso` + `FM+U+COMPACT+RESSERRE+POCHOIR+FAISCEAU_LUMINEUX` (couches du rayon) | 1er allumage de torche | non | 1 584 lignes sources ; le plus lourd de l'allumage |
| B2 | `volume_iso` + `…+LUMIERE+AJUSTE+POCHOIR_JUGE+FAISCEAU_LUMINEUX_JUGE` (juge du rayon) | idem | non | idem |
| B3 | `halo_iso` (lentille, éclat de bouche, comète, éclair de mine, braises) | 1er allumage ou 1er tir | non | 72 lignes, `unshaded` : petit |
| B4 | `halo_iso_melange` (lueur au sol et cœur de la fusée) | atterrissage de la 1re fusée (`iso_volumes.gd:515, 548` ; la comète en vol emploie `halo_iso`, B3) | non | petit |
| B5 | `quad_iso_additif` (traçante, aura des balles) | 1er tir | non | 17 lignes |
| B6 | `nuage_voxel_iso` base (suie, poussière), `MultiMesh` instancié | 1re suie/poussière | non (shader chargé, jamais dessiné) | 1 138 lignes sources |
| B7 | `nuage_voxel_iso` + `NUAGE_FUSEE` | atterrissage de la 1re fusée | non | idem |
| B8 | `volume_iso` forme 5 (couches braises/poudre) et son juge `FM+U+…+POCHOIR_JUGE` (nuages voxel comprises) | 1re braise/poudre/fumée voxel | non | 1 programme couche + 1 juge |
| B9 | `volume_iso` forme 2 (ruban du voile) | 1er voile | non | |
| B10 | `capteur_objet` (canvas, `light_only`) dans un `SubViewport` 256² | 1er objet posé/fusée | non | 11 lignes |
| B11 | `nappe_fusee` (canvas, `fwidth`) | atterrissage de la 1re fusée | non (GAD-06) | 39 lignes ; modulate 0 jusque-là |
| B12 | `CanvasItemMaterial` (ADD + non éclairé) : balles, éclat de bouche, poudre ; (MIX + non éclairé) : cœur de la fusée, nappe de braises, lentille, masse de suie | 1er tir ; 1re fusée/gadget | non | une clé = un programme ; le son visible utilise (ADD + éclairé) (AUD-02) |
| B13 | `fumee_fusee` (voile 2D) | 1re fusée | **oui** : `Fusee.prechauffer` (un quad à `alpha_globale = 0`) — position non prouvée (voir 3.5) | |
| B14 | `blood_shader` (canvas, éclairé) | 1re touche | non | SHA-01 |
| B15 | `voile_eblouissement` plein + copie plein cadre ; `brouillage_flou` | 1er éblouissement fort, 1er brouillage | non | SHA-01 |
| B16 | `death_flash`, `killcam_overlay`, `ghost_unshaded` | 1re mort | non | ETA-02 |
| B17 | `sol_iso`, `mur_iso` (+ USURE), `corps_iso`, pré-passe, `quad_iso`, `damage_vignette`, voile calme, `player_*_light`, `capteur_local/adverse` | ouverture de la manche | **oui par construction** : dessinés dès les premières images du décompte (`damage_vignette` : `ColorRect` créé visible, `player.gd:795-810` ; voile calme : « un `ColorRect` d'alpha nul se dessine quand même », `ui.gd:2436-2451`, et `_poser_voile` choisit le calme au repos, `:2543-2548`) | à ne pas chauffer à part ; la pré-passe et `quad_iso` sont partagés avec les objets et l'onde ; le voile **plein** (B15) est un autre programme |
| B18 | `*_eclaire`, `pate_*`, `corps_grossier_iso`, `corps_profondeur_iso`, `grain_iso`, `corps_iso_contour`, `murs_bas_*` (aucune carte livrée n'a de muret) | jamais en jeu par défaut | — | hors liste (ISO-12) |

Total à chauffer pour un duel complet : **≈ 17 programmes après FIGHT sans la mort (B1-B15), ≈ 20 avec elle (B16)**, dont un joueur donné ne touche que 8-12 selon sa classe ; **7 sont gros** (> 1 000 lignes sources : B1, B2, B6, B7, la couche et le juge de B8, B9), les autres petits.

**Variantes `#ifdef` réellement actives par défaut** (les autres — `CORPS_DETAIL`, `CORPS_SOI_*`, `ENCRE_ESSAI`, `*_eclaire` — sont des essais éteints) : `volume_iso` en **5 programmes distincts** (chaîne de `#define` de `variante_definie`) — (1) couche du rayon `FM+U+COMPACT+RESSERRE+POCHOIR+FAISCEAU_LUMINEUX`, (2) juge du rayon `FM+U+COMPACT+RESSERRE+POCHOIR+LUMIERE+AJUSTE+POCHOIR_JUGE+FAISCEAU_LUMINEUX_JUGE`, (3) couche de forme 5 `FM+U+COMPACT+RESSERRE+POCHOIR+LUMIERE+AJUSTE` (nappes de braises et de poudre, tant que `nappes_voxel` est faux), (4) juge de forme 5 `…+POCHOIR_JUGE` (partagé par les nuages en voxels et les nappes), (5) ruban du voile `FM+U+COMPACT+RESSERRE` (forme 2) — soit 10 objets `Shader` pour 5 programmes ; `nuage_voxel_iso` en **2** (`NUAGE_FUSEE` ou non) ; `sol_iso` et `mur_iso` + `USURE_ESSAI` (déjà dessinés au décompte). `FM` = `FUMEE_MASQUE`, `U` = `USURE_ESSAI` (allumée par défaut depuis Q30 : `iso_materiaux.gd:147, 165-173`) ; `masque_fumee := true` et `forme_masque := 5` sont les défauts de `iso_volumes.gd:153, 159`. Coût de la couverture : de l'ordre de 0,5-3 s de compilation au total sur Mac (ESTIMÉ à partir des 143-150 ms mesurés pour les gros), **à répartir sur plusieurs images du premier décompte** (un ou deux programmes par image) ; le décompte ranké de 10 s l'absorbe, celui de 3 s à peine pour le premier match seulement.

### C. Ce qui n'est PAS à chauffer

Les programmes de B17 (déjà dessinés au décompte) ; les menus (hub) ; la pré-passe et `quad_iso` pour les objets et l'onde (partagés) ; `fusee_corps.png` (tenu par le HUD tant que le HUD existe) ; l'icône de gadget (hors duel) ; les cookies des classes hors jeu (RAM) ; B18.

### D. Garde de couverture (sinon la liste se périme sans bruit)

Aucune suite ne rougit aujourd'hui si une chauffe manque (SHA-01). Deux gardes complémentaires :
- *Statique* (SHA-01) : lister les `.gdshader` référencés par le jeu ; échouer si l'un n'est ni dans la liste de chauffe ni dans une liste d'exclusions (menus, bancs).
- *Dynamique* (V1b) : monter `main.tscn`, exécuter le préchauffage, relever l'ensemble E0 des `Shader` portés par les matériaux des nœuds visibles (`ShaderMaterial.shader` ; pour les `CanvasItemMaterial`, le couple `blend_mode/light_mode`), puis jouer un duel scripté (allumer, tirer, toucher, poser chaque gadget, lancer une fusée jusqu'à l'atterrissage, tuer) et relever E1. **Exiger `E1 ⊆ E0 ∪ exclusions`, et `IsoMateriaux._variantes` de taille inchangée**. La différence imprimée est exactement la liste B ci-dessus. Faisable en headless : les nœuds et matériaux existent sans GPU.

---

### E. Où placer chaque couverture, et dans quel ordre

| Étage | Quand | Contenu | Budget (ESTIMÉ) |
|---|---|---|---|
| 1. Lancement (`GameState._ready`, derrière l'intro ou le hub : 100-300 ms tolérables, la 3D n'est pas allumée sous les menus) | une fois par processus | A4 (tenir les deux textures sources de la suie et de la poussière : 0 ms) ; A6 (masques) ; A7 (sons, par `load_threaded_request`) ; A15 (créer les variantes finales de `volume_iso` : 4-5 `Shader` au lieu de 10) | 30-80 ms hors fil |
| 2. Ouverture de la 1re manche, **pendant le décompte** (3 s ; 10 s en classé apparié), un ou deux éléments par image | la 1re manche d'un processus, puis jamais | A1 + A2 + A3 juste après `equip_weapon` (`game_state.gd:1985-1986`) pour les classes en jeu (figurants de l'aventure compris, à la pose de la salle) ; A5 (grilles, côté(s) de caméra des vues projetées) ; dessins de chauffe des gros programmes (B1, B2, B6, B7, B8 et son juge, B9), puis des petits (B3-B5, B10-B12, B14, B15) | CPU 15-40 ms ; GL 0,5-2 s ESTIMÉ, à étaler |
| 3. Changement de classe au salon, `pick_countdown_weapon` | par classe, puis idempotent | A1-A3 de la nouvelle classe | 3-8 ms |
| 4. Chaque manche suivante | — | rien : drapeaux statiques | 0 |

Contraintes de conception, relevées dans le code :
- **Le décompte est court devant 0,5-2 s de compilation** : il est décrémenté du `delta` réel de l'image (`game_state.gd:2122`), donc une image longue le raccourcit sans rien retirer au jeu, mais le premier match d'un processus verrait « 3 » durer moins que ses 3 s. D'où l'étalement, et la préférence pour les gros programmes en premier.
- **Écran scindé** : deux vues, deux jeux de matériaux (ROADMAP l. 27618) : chauffer dans chaque vue regardée ; ne pas chauffer la vue éteinte (`UPDATE_DISABLED`).
- **Rien d'observable** : aucun pixel écrit (alpha de sortie nul posé dans un **uniforme**, pas sur `modulate`), aucune vraie `Light2D`, aucun pochoir écrit par le juge de chauffe ; aucun nœud dans `bullet_container` ni dans les groupes `gadgets`/`fusees` (l'enregistrement du rejeu, l'éblouissement et la perception des bots les balaient) ; aucun RPC ; aucun tirage de hasard global ; **les deux pairs de la même façon** (l'équité ne dépend pas de qui a chauffé).
- **Idempotence** : un drapeau statique par bloc (comme `Fusee._voile_rechauffe`), car `rebuild_arena` rappelle chaque manche.
- **Garde** : § D, sinon la liste se périme sans bruit.

## 5. Corrections à apporter aux rapports d'audit

1. **ETA-05** : « un script déjà chargé parce qu'un autre le nomme (`GadgetMine`, `GadgetGresillement`, `GadgetPoudre`, `GadgetSuie`/`GadgetVolume`, `GadgetLeurre`) » : seuls `GadgetGresillement` et `GadgetPoudre` sont nommés par du code de jeu ; les autres mentions sont des commentaires (balayage hors commentaires de tous les `*.gd` de la racine). Huit scripts sur dix compilent à la pose, pas trois. « `_gabarit_bloquant` à chaque tentative d'un gadget qui arrête les joueurs » : une fois par pose, pour tous les slugs. « Une fois par session » : faux (cache faible).
2. **HUD-09** : l'icône fait 128², elle est tenue par un cache fort et chargée hors duel ; la lecture GPU n'est pas une relecture de 4 Mo.
3. **GEO-04** : « `prechauffer()` prépare aplats, reliefs, planches » : vrai pour la fusée, **inopérant pour la suie et la poussière** (clé = id d'une instance morte). « Pré-passe de profondeur compilée au premier dessin » : réfuté (ressources partagées avec les corps).
4. **GAD-06** : « `fusee_corps.png` n'est chargé qu'au premier lancer » : réfuté (HUD, `ui.gd:3021-3025`). « Sprites de gadget chargés à la première pose » : à chaque pose sans instance vivante.
5. **ISO-09** : « première mort (`quad_iso` de l'onde) » : réfuté (même shader que le viseur et la ligne de visée, dessinés dès l'ouverture). « Jusqu'à 8 `Shader` » : 10 (SHA-02). Le rapport laisse de côté `blood_shader`, le voile d'éblouissement plein, `brouillage_flou`, `nappe_fusee` et les `CanvasItemMaterial` : SHA-01 les liste.
6. **ISO-12** : cinq shaders ; sept avec `corps_grossier_iso` et `corps_profondeur_iso` (SHA-12).
7. **BOT-10** : doublon d'ETA-05 (a). « Importé sans compression » : exact (`compress/mode=0`, lossless, 1 024², sans mipmaps).
8. **AUD-02** : les coûts sont faibles ; le seul poste non négligeable est l'ensemble des chargements du premier kill (stings Ogg 1-3 ms chacun).
9. **`tools/banc_pics.gd` (en-tête)** : « un pic de compilation se paie une fois par lancement et jamais en match » est contredit par § 2.
10. **`fusee.gd:340-342`** : « 8,5 ms mesurées » décrit la génération procédurale ; `_texture_volute` charge maintenant trois PNG peints dont deux de 2048² au lancement (coût réel : hors V1b, à rapprocher du constat de démarrage).

---

## 6. Questions ouvertes

1. **Ampleur de la compilation GL des matériaux de jeu sur le pilote d'Apple** : jamais mesurée. Une seule prise froide (processus neuf, torche allumée à 5 s, `--seuil-lent 1`, sans chauffe) la donnerait ; Adrien ne mesure plus, donc c'est à décider : corriger sur principe (le coût d'un dessin de chauffe est borné) ou autoriser une prise. Les caches de shaders des pilotes (disque, certains fabricants) changent l'effet d'une plateforme à l'autre.
2. **`texture_2d_get` et le binaire d'éditeur** : garde-t-il une copie CPU de chaque texture (`TOOLS_ENABLED`) ? Si oui, `get_image()` est gratuit dans `godot --path .` et dans la CI et il ne coûte que dans un export. À lire dans le source 4.7.
3. **Cache faible des scripts et des textures** : le test de dix lignes (`load` à froid / tenu / relâché) le tranche en headless.
4. **Partage des caches de glyphes entre `FontVariation` identiques** : à confirmer en 4.7 (sinon chaque `Charte.police_*` repaie ses glyphes).
5. **Le quad de `Fusee.prechauffer` est-il dans le cadre de la caméra de la lightmap à l'image où il vit ?** Test géométrique en headless sur `canvas_transform`. Et dessine-t-il la variante éclairée ou non éclairée du voile ?
6. **Le coût de l'analyse GLSL du moteur sur ~1 584 lignes** (`Shader.code =`) : 1 ms ou 15 ms ? Mesurable sous xvfb en trois lignes. Il décide si la composition des `#define` en une passe (SHA-02) est un correctif de premier plan.
7. **Sur la 3D à deux vues (écran scindé)** : « chaque vue a SES matériaux » (ROADMAP l. 27618) alors que le programme est par shader : qu'est-ce qui compile une seconde fois ? Non expliqué.
8. **Décision d'Adrien** : où placer la chauffe GL — premier décompte (étalée), ou derrière l'intro/le hub (la scène 3D n'est pas allumée sous les menus). Je recommande le décompte.

---

## Annexe — squelettes de preuves (à écrire par qui corrige ; rien n'a été ajouté au dépôt)

**P1. Cache faible et clé morte (headless, `extends SceneTree`, `--script`).**

```gdscript
# `extends SceneTree`, lancé par `godot --headless --path . --script res://…`. Les scripts de jeu se chargent à l'exécution,
# APRÈS la première image (un `--script` qui nomme une classe de jeu casse tout le processus : ROADMAP l. 3578-3589 et
# 8962-8975) ; `IsoNuageVoxel` est écrit pour compiler sous `--script` (`iso_nuage_voxel.gd:29-30`).
func _initialize() -> void:
	await process_frame
	# 1) cache faible des scripts : froid / tenu / relâché
	var chemin := "res://gadget_mine.gd"          # aucun code de jeu ne le nomme
	var t := Time.get_ticks_usec(); var s = load(chemin); var froid := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec(); var s2 = load(chemin); var tenu := Time.get_ticks_usec() - t
	s = null; s2 = null
	t = Time.get_ticks_usec(); var s3 = load(chemin); var relache := Time.get_ticks_usec() - t
	print("froid %d µs, tenu %d µs, relâché %d µs" % [froid, tenu, relache])   # relâché ≈ froid => cache faible
	# 2) clé morte d'aplat/relief
	IsoNuageVoxel.prechauffer()
	var tex: Texture2D = load("res://assets/sprites/gadget_poussiere.png")
	print("en cache pour la texture de la pose : ", IsoNuageVoxel._reliefs.has(tex.get_instance_id()))   # attendu : false
	t = Time.get_ticks_usec(); IsoNuageVoxel.relief(tex); print("relief : %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	# 3) coût d'un load() tenu
	var tenue: Texture2D = load("res://assets/torche/cookie_pompe.png")
	t = Time.get_ticks_usec(); for i in 10000: load("res://assets/torche/cookie_pompe.png")
	print("load() en cache : %.1f µs" % ((Time.get_ticks_usec() - t) / 10000.0))
	quit()
```

**P2. Coût CPU des grilles (headless)** : `Time.get_ticks_usec()` autour de `IsoNuageVoxel.grille("fusee", 35.0, 8.75, Vector2i(1, 1))`, `("cartouche_suie", 28.0, …)`, `("poussiere", 14.0, …)`.

**P3. Coût CPU des variantes (xvfb + llvmpipe, pas `--headless`)** : `Time.get_ticks_usec()` autour de `IsoVolumes.variante_juge(true, 5)` puis `IsoVolumes.variante_forme(IsoVolumes.variante_masque(true), 3)` dans un processus neuf, `_variantes` vide.

**P4. Couverture** : § 4-D.

Fichiers de travail : `v1b_work/cmap.py` (balayage des glyphes absents des polices). Calculs des grilles reproduits dans le texte (Python, 12 lignes).
