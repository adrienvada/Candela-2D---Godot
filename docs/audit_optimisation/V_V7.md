# V7 — Le build, les assets et le démarrage : vérification contradictoire de DEM-01 à DEM-13

Dépôt `/home/user/Candela-2D---Godot` @ `52a29c1`. Rapport source : `audit/13_DEM_demarrage_build.md`. Lecture seule, Godot non lancé.
Preuves et scripts de cette vérification : `audit/v7_work/` (relançables ; voir §Reproduire).

## Tableau de synthèse

| Constat | Verdict | Sévérité (auditeur → corrigée) | Coût corrigé |
|---|---|---|---|
| DEM-01 | CONFIRMÉ | MAJEUR → **MINEUR** (poids seulement) | −31,75 Mo de PCK, ≈ −30,9 Mo par zip, 0 ms |
| DEM-02 | CONFIRMÉ (prouvé sur le paquet publié) | MINEUR → MINEUR | −20,5 Mo de zip macOS (−11 %), −48,6 Mo installés |
| DEM-11 | CONFIRMÉ AVEC RÉSERVE | MINEUR → MINEUR | −6,88 Mo (repli exclu) et ≈ −2,9 Mo (3 images en lossy) ; ≈ −8,5 Mo en tout |
| DEM-12 | CONFIRMÉ (la ROADMAP se trompe) | ANECDOTIQUE → ANECDOTIQUE | −1,04 Mo, 280 entrées |
| DEM-03 + MEN-08 + HUD-10 | CONFIRMÉ AVEC RÉSERVE | MINEUR → MINEUR | 44-58 Mo résidents ; décodage mesuré en proxy 0,41 s sur un cœur Xeon (≈ 0,1-0,2 s attendu sur M3, non mesuré) |
| DEM-04 | CONFIRMÉ AVEC RÉSERVE (déjà tranché pour le coût) | MINEUR → **ANECDOTIQUE** | 0,2-0,4 s une fois par processus (mesure ROADMAP), 37,8 Mo résidents |
| DEM-07 | CONFIRMÉ AVEC RÉSERVE (glyphes prouvés, effet non prouvé) | MINEUR → **ANECDOTIQUE** | à-coup unique non mesuré ; 2 libellés concernés en jeu, pas 4 familles |
| DEM-10 (archive jamais supprimée) | CONFIRMÉ | MINEUR → MINEUR | 131 Mo (Windows) / 185 Mo (macOS) laissés par mise à jour installée |
| DEM-13 | CONFIRMÉ | ANECDOTIQUE → ANECDOTIQUE | ≈ 0, non mesuré |
| DEM-05 | CONFIRMÉ | MINEUR → MINEUR | aucun coût d'exécution : un angle mort |

## 0. Ce que j'ai refait moi-même (et non relu)

1. **Le paquet publié `v0.8.3`**, relu par requêtes HTTP `Range` sur les deux zips : annuaires complets ; entrée `Candela.pck` Windows (84 018 641 o → 86 386 392 o, **CRC32 vérifié**) et entrée `Candela 2D.pck` macOS (85 772 921 o → 88 154 536 o, **CRC32 vérifié**) inflatées, annuaires de PCK comparés ; entrée `libeosg` macOS inflatée et ses commandes de chargement Mach-O lues (`zipdir.py`, `pckx.py`).
2. **Les `.ctex` réels** : listés avec `ls -l` dans `.godot/imported/` du worktree de l'agent de mesure (aucune écriture). Les 33 images : 31 753 030 o, **identiques à l'octet** à celles du PCK publié (`ctex_check.py`).
3. **Toutes les formes de référence** des 33 (nom court, nom de fichier, chemin, famille, dossier) dans la racine (profondeur 1 : `.gd`, `.tscn`, `.tres`, `.cfg`, `.json`, `.gdshader*`, `project.godot`), `tools/` (récursif), `.github/`, `export_presets.cfg` (`refs33.py`), plus recherche des chemins **construits** (`%`, `+`, chaîne finissant par `/`, `path_join`, `"res://" +`) et des balayages `DirAccess` du jeu.
4. **Proxies de poids et de décodage** avec libwebp (Pillow installé dans un `venv` du dossier de travail, pas dans le dépôt), sur les charges utiles exactes des `.ctex` (`ctex_decode_bench.py`, `webp_probe.py`, `webp_decode_cmp.py`).
5. **Table des glyphes** : `cmapcheck.py` de l'auditeur relancé, puis recoupé avec fontTools.

---

## DEM-01 — 33 images que le jeu ne lit jamais (31,75 Mo sur 86,39 du PCK)

**Verdict : CONFIRMÉ. Sévérité corrigée : MINEUR** (l'auditeur : MAJEUR). Raison : c'est un poids de distribution — zéro milliseconde, zéro octet de RAM, aucun effet sur la cadence, la mémoire ni le démarrage (seul l'annuaire du PCK est lu). La ROADMAP a déjà classé la même famille « Mineur, un filtre suffit » (PE3 point 4, l. 22428-22430 ; PE3.4, l. 22497). Mais c'est **le premier gain de l'audit en octets par effort** : S, risque ≈ 0.
**Coût corrigé : −31 753 030 o de PCK (−36,8 %) ; ≈ −30,9 Mo par zip** (le PCK se déflate à 97,3 %) : Windows 131,18 → ≈ 100,3 Mo ; macOS 185,34 → ≈ 154,5 Mo (avant DEM-02/12). Les releases 0.8.x ne publient que des bundles complets (`manifeste.json`), donc chaque mise à jour retélécharge ce poids.

### 1. Le code

```
export_presets.cfg:12-14   export_filter="all_resources"  include_filter=""  exclude_filter="tools/*"     (macOS)
export_presets.cfg:269-271 idem (Windows Desktop)       export_presets.cfg:340-342 idem (Web)
```
(L'auditeur cite `:11`, `:270`, `:341` : décalage de 1 à 3 lignes, sans conséquence.)

### 2. Fréquence / quantités et méthode de l'estimation du PCK

- **Méthode de l'auditeur : saine.** « 86,39 Mo » est la taille décompressée de l'entrée `Candela.pck` dans l'annuaire du zip publié ; je l'ai re-calculée en téléchargeant et inflatant l'entrée (CRC32 OK). La somme des entrées de l'annuaire PCK est 86 216 034 o (le reste : en-tête 112 o, annuaire, alignement). Les 33 `.ctex` : 31 753 030 o = 36,8 % (de la somme des entrées comme du fichier). **Le chiffre tient avec les `.ctex` réels** : mêmes tailles, octet pour octet, que dans `.godot/imported/` de l'agent de mesure (HEAD `52a29c1`) ; les 33 sont donc inchangées entre le tag 0.8.3 et HEAD.
- Par groupe (octets dans le PCK) : `ui/titres` 13,408 Mo (17) · `ui/fond_*` 5,406 (3) · `ui/icone_*` 0,477 (2) · `keyart` 4,517 (3) · `logos` 4,792 (3) · `sources/encre` 3,153 (5). La composition du PCK (361 `.ctex` = 66,25 Mo ; film 9,14 ; 12 Ogg 3,29 ; 96 `.sample` 2,49 ; 333 `.gdc` 2,64 dont 160 d'addons 1,18) est exacte.

### 3. Classement des 33 (preuve par fichier : `refs33.py`)

| Fichiers | Classe | Preuve |
|---|---|---|
| 17 × `assets/ui/titres/*.png` (13,41 Mo) | **vraiment mortes à l'exécution** ; lues seulement par un **outil/test** | seuls hits : commentaires (`menu_hub.gd:130`, `menu_recitatif.gd:8`, `ui.gd:6086`) et `tools/test_menus_finitions.gd:91-112` (balayage `DirAccess` du dossier filtré sur `titre_`/`verdict_`, et lecture de `titre_accueil.png.import`). `tampon_fatal.png` : aucun lecteur, même dans l'outil. ROADMAP l. 22326 : « leur suppression est sa décision — `test_menus_finitions` continue de mesurer leur détourage, ce qui ne teste plus rien d'affiché » |
| `ui/fond_armes.png`, `fond_rangs.png`, `fond_telecharger.png` (5,41 Mo) | mortes à l'exécution ; **outil (indirect, non prouvé)** | aucun lecteur sous ce nom, aucune mention dans la ROADMAP. ⚠️ **L'auditeur écrit « aucune mention nulle part » : inexact** — `tools/site/assembler.py:31-33` attend `fond_armes.jpg`, `fond_rangs.jpg`, `fond_telecharger.jpg` « à côté de lui » (dérivés JPEG non versionnés, « trois fonds commandés pour le site »). Ces PNG en sont très probablement les sources (non documenté) |
| `ui/icone_macos.png`, `icone_windows.png` (0,48 Mo) | mortes à l'exécution ; **outil** | `tools/site/assembler.py:48-49` et `tools/site/LISEZMOI.md:27` (« telles quelles » depuis `assets/ui/`) ; ROADMAP l. 15372. À garder au dépôt |
| `keyart/*` (3, 4,52 Mo) | mortes | commentaires `ui.gd:3972,3983` ; `tools/fabrique_keyart.gd:38` y **écrit** (`SORTIE`), il ne les lit pas ; `keyart_convergents` : « jamais choisi » (l. 15270) |
| `logos/Wordmark_candela.jpg`, `icone_bootsplash.jpg`, `icone.png` (4,79 Mo) | mortes | l. 15265-15281 : « référencés par AUCUN fichier du dépôt… signalé, pas tranché » (les deux JPG) ; `icone.png` « remplacée par `icone_roman.png` » (l. 15260). `charte.gd:552,560` lit `wordmark.png` et `icone_roman.png` ; `project.godot:27,33` lit `boot.png` et `icone_faisceaux.png` — aucun des trois exclus |
| `sources/encre/*` (5, 3,15 Mo) | **outil seulement** (sources de cuisson) | `tools/encrer_masques.gd:35` (exemple `--planche res://assets/sources/encre/flash_amorce.png` → `assets/flash/flash_1.png` ; les deux autres planches `flash_*` suivent la même voie — **déduit** de `tools/apercu_torche.gd:103-105`, qui nomme `flash_1/2/3` : amorce, épanouissement, dissipation), `tools/apercu_traces.gd:105` (`load()` de `gadget_nappe_braises_source.png`), commentaires `wall_impact.gd:33`, `gadget_braises.gd:253`. C'est pourquoi `encre/` est le seul dossier de `sources/` sans `.gdignore` |

**Chargées dynamiquement : aucune.** Les 14 constructeurs de chemin du jeu visent tous un autre dossier : `wall_impact.gd:30` (decals), `menu_fiche_classe.gd:516` (portraits), `player.gd:441` / `gadget_leurre.gd:87` / `fusee.gd:168` / `gadget_profile.gd:114` / `class_data.gd:99` / `iso_nuage_voxel.gd:313,623` (sprites), `weapon_data.gd:234` / `class_data.gd:94` (torche), `gadget_profile.gd:119` / `menu_icones.gd:53` (ui/icones), `ui.gd:8094` (ui/prompts), audio. Aucune construction à partir de `res://` nu ou de `path_join`. Les seuls balayages `DirAccess` de `res://assets/` par le jeu : `map_data.gd:92` (`assets/maps/`) et `aventure_format.gd:496` (`assets/solo/`). **`asset_manifest.gd` : 90 entrées (et non 76), toutes audio** (musique 12, SFX 50, voix 8, armes 20) — aucune image. Les `.tscn/.tres` de la racine ne portent que des `ext_resource` de scripts ; le seul `.tres` d'`assets/` est un flux audio ; aucun `uid://` dans les `.gd` ; les 116 JSON de `assets/maps` et `assets/solo` ne contiennent aucun chemin d'image. Outils de photo/planche : `photographe.gd:2457` ne retient que `ill_*` et `apercu_personnalisation` ; `capturer_artworks.gd` liste des `ill_*`. Aucun code de jeu ne teste `ResourceLoader.exists()` / `FileAccess.file_exists()` sur ces chemins : l'exclusion ne change donc aucun comportement silencieusement.

### 4. Invariants

- Aucun test ne lit `export_presets.cfg` ni `release.yml` (grep de `tools/`). `test_menus_finitions` tourne dans le projet, pas dans l'export : inchangé.
- **Ne pas** poser de `.gdignore` sur `ui/titres/` (le test lit son `.import`) ni sur `sources/encre/` (`apercu_traces.gd:105` charge un fichier par `load()`) : l'`exclude_filter` est le bon outil. **Ne pas supprimer** du dépôt : c'est la décision d'Adrien (l. 22326, 15265-15281), et `tools/site` veut les icônes.
- Règle de la ROADMAP l. 4691-4701 (« toute image de documentation vit sous un `.gdignore` ») : l'extension naturelle est « toute image que rien ne lit est exclue de l'export ».

### 5. Statut

CONNU-OUVERT pour les orphelins un à un (l. 15265-15281, 22326) ; PE3.4 n'a filtré que `tools/*`. Le poids total dans le paquet et le lien avec la taille des mises à jour sont NOUVEAUX.

### 6. Correctif minimal et preuve

- **Geste** : ajouter aux `exclude_filter` des préréglages (sans espaces après les virgules) : `assets/ui/titres/*,assets/keyart/*,assets/ui/fond_armes.png,assets/ui/fond_rangs.png,assets/ui/fond_telecharger.png,assets/ui/icone_macos.png,assets/ui/icone_windows.png,assets/logos/Wordmark_candela.jpg,assets/logos/icone_bootsplash.jpg,assets/logos/icone.png,assets/sources/*` (+ `docs/*,supabase/*,build/*` en ceinture : rien n'y pèse aujourd'hui, vérifié — `docs/` et `supabase/` ne portent aucun JSON/image exportable hors `docs/iso/` qui a son `.gdignore`). Le point 3 de l'auditeur (`importer="keep"` pour `boot.png` et `icone_faisceaux.png`, −0,95 Mo : 271 950 + 674 114 o de `.ctex` doublonnés, vérifié) est **optionnel et non vérifié** côté exporteur d'icône ; à ne pas faire sans essai d'export.
- **Preuve cloud** (indépendante du matériel) : `godot --headless --path . --export-pack "Windows Desktop" /tmp/c.pck` (n'exige pas de modèle d'export, à ma connaissance ; la CI en a de toute façon), puis `python3 liste_pck.py /tmp/c.pck --mort '*titre_*,*keyart*,*sources/*,*godot_ai*'` (code retour 1 s'il reste une entrée) et un plafond de taille ; dans `release.yml` après l'export. Hors Godot : `ctex_check.py` recalcule les 31 753 030 o.

---

## DEM-02 — macOS : `libEOSSDK-Mac-Shipping.dylib` en double, `icon.icns` cuit dans le PCK

**Verdict : CONFIRMÉ — et prouvé sur l'artefact, pas sur une lecture.** Sévérité : **MINEUR**.
**Coût corrigé : −20,52 Mo de zip macOS (−11,1 %)** = dylib racine 18 755 814 o + `icon.icns` du PCK ≈ 1 754 280 o zippés (85 772 921 − 84 018 641) ; **−48,6 Mo installés** (48 623 616 o) ; 0 ms.

### 1. Le code et les preuves

```
release.yml:210-225   mkdir -p build/macos ; rm -rf "build/macos/Candela 2D.app" …
                      godot --headless --path . --export-release "macOS" "build/macos/Candela 2D.app"   # sortie DANS l'arbre du projet
:217                  codesign --force --deep --sign - "build/macos/Candela 2D.app"
eosg.gdextension      [dependencies] macos.release = {"bin/macos/libeosg.macos.template_release.framework/libEOSSDK-Mac-Shipping.dylib": ""}
addons/epic-online-services-godot/export_plugin.gd (case "macos")  add_shared_object("…/bin/macos/libEOSSDK-Mac-Shipping.dylib", [], "/")   # chemin inexistant : la dylib est dans le framework
```
- **Annuaire du zip macOS publié** : `Frameworks/libeosg.macos.template_release.framework/libEOSSDK-Mac-Shipping.dylib` (u = 48 623 616, z = 18 731 767, CRC 2477940459) **et** `Frameworks/libEOSSDK-Mac-Shipping.dylib` (u = 48 623 616, z = 18 755 814, CRC 957783738 — même taille, CRC différent : très probablement la signature ad-hoc de `codesign --deep` posée par copie, **déduit**, sans conséquence).
- **Mach-O de `libeosg` publié, inflaté et lu** (les deux tranches, x86_64 `0x1000007` et arm64 `0x100000c`) : `LC_LOAD_DYLIB @loader_path/libEOSSDK-Mac-Shipping.dylib`. `@loader_path` = le dossier du framework, où la dylib existe : **la copie racine n'est référencée par personne**. Rien d'autre ne la réclame (grep de `.github/`, `tools/`, `docs/` : seulement un commentaire de `tools/apercu_torche.gd:518`).
- **`icon.icns` dans le PCK** : l'annuaire du PCK macOS a **une entrée de plus** que celui du Windows, `build/macos/Candela 2D.app/Contents/Resources/icon.icns`, de 1 768 036 o, **de CRC32 2758154592 = celui de `Contents/Resources/icon.icns` du `.app`**. Arithmétique : 88 154 536 − 86 386 392 = 1 768 144 = 1 768 036 + 108 (entrée d'annuaire + alignement). Windows : une seule `EOSSDK-Win64-Shipping.dll`, aucune fuite (l'`.exe` embarque son icône).
- Nuance (mineure) : l'auditeur écrit « tout le reste est identique à l'octet » ; en réalité 5 petites entrées de même taille diffèrent entre les deux PCK (3 `.scn` d'export, `uid_cache.bin`, `global_script_class_cache.cfg` : identifiants de deux exports distincts). Sans conséquence.

### 2. Fréquence : à chaque installation et chaque mise à jour macOS. Aucun coût d'exécution.

### 3. Coût : poids seulement (calculé ci-dessus).

### 4. Invariants

`codesign --verify --deep --strict` (déjà dans le job) valide le bundle **après** la suppression. Le risque réel est celui que dit l'auditeur : si la suppression était fausse, EOS passerait en « Epic : indisponible » sans plantage. La preuve Mach-O le rend improbable ; la garde ci-dessous le rend **bruyant**. Le mécanisme exact par lequel l'`icon.icns` entre dans le PCK n'est pas établi (hypothèse : l'icône est écrite dans l'arbre du projet pendant l'export, avant la constitution de la liste du PCK ; le fait, lui, est prouvé par le CRC) : le correctif doit donc **ne pas dépendre du moment du balayage**.

### 5. Statut : NOUVEAU.

### 6. Correctif minimal et preuve

1. Préréglage macOS : `exclude_filter="tools/*,build/*"` (filtre appliqué à la liste finale, quel que soit le moment où l'icône y entre — plus robuste que `touch build/.gdignore`, que l'auditeur propose en premier ; les deux ne s'excluent pas).
2. `release.yml`, entre l'export (ligne 213) et `codesign` (ligne 217) :
```bash
fw="build/macos/Candela 2D.app/Contents/Frameworks/libeosg.macos.template_release.framework"
test -f "$fw/libEOSSDK-Mac-Shipping.dylib" || { echo "::error::dylib EOS absente du framework"; exit 1; }
otool -L "$fw/libeosg.macos.template_release" | grep -q '@loader_path/libEOSSDK-Mac-Shipping.dylib' \
  || { echo "::error::libeosg ne charge plus la dylib voisine"; exit 1; }
rm -f "build/macos/Candela 2D.app/Contents/Frameworks/libEOSSDK-Mac-Shipping.dylib"
```
3. **Preuve** : `unzip -l` du zip (ou `zipdir.py` sur une plage de la fin du fichier : annuaire seul) → plus qu'une dylib, plus d'`icon.icns` dans le PCK ; `codesign --verify` de la CI ; **et une vérification fonctionnelle d'une minute avant la première release** (lancer l'app construite, lire « Epic : connecté », `docs/PROTOCOLE_TEST_EOS.md`) — la seule partie qui ne se prouve pas dans le cloud.

---

## DEM-11 — Les sources JPEG sont ré-encodées sans perte (×4) et le repli d'intro pèse 6,9 Mo

**Verdict : CONFIRMÉ AVEC RÉSERVE** (chiffres exacts ; gain réel sous-estimé ; une décision de produit et une mesure de fidélité à faire). Sévérité : **MINEUR** (poids).
**Coût corrigé** : 19 sources JPEG = 2 528 731 o → 10 303 274 o de `.ctex` (×4,07 ; l'auditeur : 2,51 → 10,31 ✓). Détail : `fin_victoire` 468 534 → 1 730 420 · `fin_defaite` 243 008 → 903 762 · `fond_hub_iso` 138 626 → 791 518 · les 16 `intro_a_pNN.jpg` 1 678 563 → **6 877 574**.

### 1. Le code
`assets/ui/fin_victoire.jpg.import:18` `compress/mode=0` (et `lossy_quality=0.7` inerte), idem les 18 autres ; `intro_planches.gd:105-107` : `disponible()` = `ResourceLoader.exists(FILM) or repli_complet()` ; `jouer()` (l. 206) prend le film s'il existe et charge, sinon `_plan_suivant()`. Le repli ne sert que si le film manque ou ne se décode pas ; ses images sont des JPEG 1280×720 (`tools/monter_intro.py:139`, qualité 86).

### 2. Fréquence : poids du paquet ; le repli n'est lu que dans le cas « film absent ». Aucun appelant de `repli_complet()` hors `disponible()` et `tools/test_intro_planches.gd:113-114` (qui tourne dans le projet).

### 3. Coût — **mon estimation du gain est plus haute que celle de l'auditeur**
Sonde libwebp sur les vraies sources (chaîne de mipmaps incluse pour les trois images à mipmaps) : sans perte 9,46 Mo (Godot : 10,30 — proxy à 9 % près) ; **lossy q 0,9 → 1,77 Mo** ; q 0,85 → 1,26 ; q 0,7 → 0,72 (les 19 fichiers). Le WebP lossy est plus petit que le JPEG d'origine (2,53 Mo), non « ≈ la taille du JPG ». Gain plausible : **≈ −8,5 Mo** (q 0,9) ; ou −6,88 Mo en excluant le repli, +≈ −2,9 Mo pour les trois images vivantes (3,43 → ≈ 0,47 Mo). **ESTIMÉ** (encodeur de Godot ≠ Pillow) : à confirmer à l'export. Décodage (proxy, un cœur Xeon 2,8 GHz) : `fin_victoire` 62 ms sans perte contre 50 ms en lossy, `fin_defaite` 56 → 34 ms, `fond_hub_iso` 50 → 37 ms : le lossy aide un peu MEN-07, sans le résoudre.

### 4. Invariants
- **DA5.6** (l. 2557 : filtrage linéaire + mipmaps, résolution choisie sur la densité de texels) : `compress/mode=1` ne change ni le filtre, ni les mipmaps, ni la résolution — **non contredite**. Mais PE3 point 3 (l. 22424-22427) a posé « une décision d'import, pas une retouche par fichier » : à formuler comme une règle par type de source (« une source JPEG s'importe en lossy »), pas comme 19 retouches.
- **Q18** (l. 29660-29715) : les illustrations du hub ont des cibles de fidélité mesurées au photographe (luminance ≥ 0,95, énergie d'arêtes ≥ 0,90 au centre de la torche). `fond_hub_iso.jpg` est la racine du hub : toute recompression doit **rejouer le plan `artworks`** avant d'être acceptée (risque : arêtes, banding des noirs).
- Repli d'intro : décision d'Adrien (Q7 de l'auditeur). Le film Theora est lu par le décodeur du moteur (le modèle d'export est l'officiel, `release.yml:70-90` ; non vérifié dans le moteur) ; sans repli et film illisible, le joueur voit du noir jusqu'à une touche (l'intro se passe à n'importe quelle touche).
- Ne pas étendre aux PNG d'illustration (le WebP sans perte y est déjà plus petit que le PNG : 0,65-0,81 contre 0,9-1,1 Mo — vérifié).

### 5. Statut : NOUVEAU (PE3 point 3 parle de VRAM, pas du poids du paquet). Recoupe MEN-07/MEN-14 : correctifs composables.

### 6. Correctif minimal et preuve
(a) Si Adrien accepte l'intro sans repli : `assets/ui/intro/*` dans `exclude_filter` (**−6,88 Mo**, une ligne, aucun risque visuel). (b) Optionnel, après mesure de fidélité : `compress/mode=1` (qualité 0,9) sur `fin_*` et `fond_hub_iso` (−2,9 Mo). **Preuve** : `liste_pck.py` avant/après ; fidélité par `./tools/run_photos.sh --plan=artworks` sous fenêtre virtuelle si la chaîne cloud le permet (sinon par Adrien, une fois).

---

## DEM-12 — `addons/godot_ai` voyage dans chaque build ; la ROADMAP se trompe sur son autoload

**Verdict : CONFIRMÉ. Sévérité : ANECDOTIQUE. Coût corrigé : −1,04 Mo de PCK (280 entrées : 140 `.gdc` + 140 `.remap`), 0 ms.**

### 1. Tranchage
- **Le `project.binary` publié (10 424 o) a été lu** : exactement **20 autoloads** (`PatchLoader` … `Matchmaker`), **aucun `_mcp_game_helper`** (`pckx.py`). L'autoload est donc **bien retiré de l'export** : `addons/godot_ai/export/mcp_export_plugin.gd:42-53` (`_export_begin` efface `autoload/_mcp_game_helper` des réglages vivants avant le moulage du pack ; `_export_end` le restaure), enregistré par `plugin.gd:262-263` **avant** la garde « headless » exprès pour que `godot --headless --export-*` le retire (commentaire `plugin.gd:258-261`). La CI le fait fonctionner (artefact publié par `ubuntu-latest`).
- **ROADMAP l. 7659-7662 est fausse sur ce point précis** : « son autoload `_mcp_game_helper` tourne dans le processus du jeu [exporté], mais il reste inerte sans débogueur ». La moitié « le plugin part bien dans les builds (le filtre d'export n'exclut que `tools/`) » est exacte (1,04 Mo, 280 entrées vérifiées) ; ce que dit l'auditeur de l'autoload est exact et vérifié. (L'autoload tourne bien dans les lancements éditeur/CLI — bancs et suites — où il reste inerte sans débogueur.)
- Rien dans le code du jeu ne référence `godot_ai` (grep racine + `tools/` : seulement `project.godot:56,80` et un commentaire de `tools/test_autoloads.gd:8`).

### 2-3. Fréquence/coût : poids seul. 5. Statut : NOUVEAU (corrige la ROADMAP).

### 4. Invariants
Exclure `addons/godot_ai/*` n'est sûr **que tant que le plugin d'export tourne en CI** (le commentaire du plugin, lignes 6-10, décrit les trois « Failed to instantiate an autoload » si l'on exclut sans lui). Il tourne : preuve = le `project.binary` ci-dessus. Le risque apparaît si le plugin était désactivé ou si une mise à jour de `godot-ai` changeait ce mécanisme (la ROADMAP l. 7640-7656 décrit une mise à jour non sollicitée du plugin de 3.0.7 à 4.0.4).

### 6. Correctif minimal et preuve
`addons/godot_ai/*` dans `exclude_filter` + **garde de CI** : après `--export-pack`, échouer si `project.binary` contient `_mcp_game_helper` ou si une entrée `addons/godot_ai/*` reste (`liste_pck.py --mort '*godot_ai*'` + lecture de `project.binary`, `pckx.py`). Corriger la phrase de la ROADMAP (document seul, hors périmètre de l'audit).

---

## DEM-03 + MEN-08 + HUD-10 — 16 illustrations du hub décodées au démarrage et retenues pendant les duels

**Verdict : CONFIRMÉ AVEC RÉSERVE** (mécanisme et mémoire exacts ; durée de MEN-08 surestimée ; la proposition (c) de DEM-03 contredit une décision d'Adrien). Sévérité : **MINEUR**. **Coût corrigé** : 43,6 (RGB8) à 58,2 Mo (RGBA8) de VRAM **calculés depuis les en-têtes** (arithmétique refaite : 14 × 1024×640, `ill_intro_allumage` 2048×1280, `fond_hub_iso` 1920×1071 + mips) — `RENDER_TEXTURE_MEM_USED` n'a **jamais** été lu ; décodage au lancement : **0,41 s mesuré en proxy** (14,5 Mpx décodés de 13,6 Mo de `.ctex`, libwebp via Pillow, un cœur Xeon 2,8 GHz, meilleur de 3) — soit ≈ 19 ms par illustration 1024×640 ; sur M3 plutôt 0,1-0,2 s (**non mesuré**). DEM-03 (0,1-0,4 s) et HUD-10 (≈ 16 × 5-15 ms) sont plausibles ; **MEN-08 (0,3-0,8 s) est trop haut**. Effet par image : nul (nœuds cachés).

### 1. Le code
```gdscript
# ui.gd:4599-4600
for cle: String in ILLUSTRATIONS.keys():
	hub.register_panel(cle, MenuApercu.new(String(ILLUSTRATIONS[cle])))
# menu_apercu.gd (_init → poser) :  if chemin != "": poser(chemin) …  _image.texture = load(chemin)
```
18 clés, 16 fichiers (`ill_creer`/`ill_rejoindre` doublonnent). Appelants remontés : `UI._ready` (`ui.gd:1332`, via `_build_menu` `:1337`/`:4154` → `_build_hub_screens` `:4201`) — donc **avant la première image**. Les nœuds `MenuApercu` restent dans l'arbre (le hub est caché, pas libéré) : textures tenues toute la session, duel compris. `MenuHub._update_background` (`menu_hub.gd:804-809`) lit `MenuApercu.texture()` et l'affiche dans `_bg_image` (`menu_hub.gd:231-235` : `PRESET_FULL_RECT`, `STRETCH_KEEP_ASPECT_COVERED`) : l'illustration est un **fond plein cadre**. (Détail non compté par l'auditeur : `ui.gd:4639` pose aussi `ill_accueil.png` en repli, chargé à la demande.)

### 2. Fréquence : une fois par processus au lancement ; résidence permanente.

### 4. Invariants
- `ui.gd:239-256` : « une image qui donne envie doit arriver **avant** le clic » — un chargement paresseux **au survol** serait un hoquet de menu (principe cité par l'auditeur ; exact).
- Les bancs/photographe lisent `MenuApercu.texture()` (`menu_apercu.gd:96`, `menu_hub.gd:806`) : une texture absente doit rester un cas géré (le hub retombe sur `_screen_backgrounds`, `menu_hub.gd:815-824`, qui fait un `load()` synchrone).
- **(c) « ramener `ill_intro_allumage.png` à 1024×640 » contredit Q19 = B** (ROADMAP l. 2502 : les planches d'intro passent à 2048×1280, « +19 Mo au dépôt, accepté », même panneau de menu) et va à contre-sens de l'esprit de DA5.6 : le fond du hub est affiché **plein cadre**, où 1024 px valent ≈ 0,5 texel par pixel à 1080p et 2048 px ≈ 1. Les 14 sœurs en 1024×640 sont déjà le côté faible. À ne **pas** faire sans Adrien ; gain faible (−7,9 à −10,5 Mo de VRAM, −1,7 Mo de PCK).
- Compression VRAM (MEN-08 b, HUD-10) : Q18 (cibles d'arêtes/luminance, banding des noirs) la rend risquée ; décision d'Adrien.

### 5. Statut — ce que décidaient les lignes citées, et ce qui reste à faire
- **l. 22424-22427 (PE3 point 3, 2026-09-10)** : inventaire (« 295 images importées sans perte et sans mipmaps, des fonds d'interface de 3 Mo chacun : VRAM et temps de chargement, à peser avec R6 qui doublera la densité des assets ») et **une seule décision, de méthode** : « une décision d'import, pas une retouche par fichier ». Aucun fichier tranché, aucune mesure. Le titre de section dit : « PE3.2 et PE3.3 attendent une machine ». (« 295 » est périmé : 355 `CompressedTexture2D` aujourd'hui.)
- **l. 22527 (PE3.3)** : « lire `vram_mo` et `textures_mo` dans le diagnostic F6 avant toute décision d'import » (0 = « non mesuré par ce pilote »). La décision est donc **suspendue à une lecture sur machine réelle** (et à H13, la machine minimale).
- **Ce qui reste** : (1) la lecture n'a jamais eu lieu, et depuis la décision du 2026-09-30 (l. 2467, « plus aucune mesure sur le Mac d'Adrien ») elle n'aura pas lieu de son fait : il faut un **relevé cloud** — `Performance.RENDER_TEXTURE_MEM_USED` sous Xvfb + llvmpipe (octets comptés par Godot lui-même, indépendants du matériel ; `0` seulement en `--headless`) ; (2) H13 dit si 44-58 Mo comptent ; (3) R6 tire dans le sens inverse (plus de texels, pas moins) ; (4) le choix entre : chargement en fil dédié (sans risque visuel), déchargement à l'entrée en match (risque de hoquet au retour au menu), VRAM compressée (risque Q18), réduction de `ill_intro_allumage` (contredit Q19). Non lié à OM6.

### 6. Correctif minimal et preuve
**Mesurer d'abord** ; si l'on agit, le plus petit geste sans risque visuel est `ResourceLoader.load_threaded_request(chemin)` dans `MenuApercu._init` (non bloquant) avec `texture()` qui fait `load_threaded_get` à la demande (bloque au plus le reste du décodage) ; l'illustration d'accueil (`fond_hub_iso`) reste chargée tout de suite. **Preuve cloud** : script lancé sous Xvfb (comme `tools/cadence_cloud/prise.sh`) qui imprime `RENDER_TEXTURE_MEM_USED` et `Time.get_ticks_usec()` avant/après `_build_hub_screens` ; relatif seulement pour le temps (llvmpipe), exact pour les octets.

---

## DEM-04 — Le préchauffage de la fusée relit le GPU, boucle en GDScript et retient 37,8 Mo

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité corrigée : ANECDOTIQUE** (l'auditeur : MINEUR). Le coût de lancement est **déjà décidé** (« payé au lancement à dessein » : ROADMAP l. 31324-31326 « en 0,2 à 0,4 s » une fois par processus ; `iso_nuage_voxel.gd:300-304` donne la raison) ; ce que DEM-04 ajoute est une cuisson hors ligne (effort M) pour ≤ 0,3 s, et une mémoire qui ne pèse que pour H13. **Coût corrigé** : 0,2-0,4 s une fois par processus (mesure de la ROADMAP, machine non précisée ; le jeu imprime sa propre durée) ; 37,75 Mo résidents (4,19 + 16,78 + 16,78).

### 1. Le code (vérifié)
`fusee.gd:343-345` `prechauffer` → `_texture_volute(i+1)` pour `NAPPES_PAR_DEFAUT = 3` (`fusee_modele.gd:110`). **`fusee_volute_1.png` n'existe pas** : les candidats (`fusee.gd:167-171`) retombent sur `fusee_volute.png` (1024², 4,19 Mo) ; `_2` et `_3` sont 2048² (16,78 Mo chacune, RGBA8, sans mipmaps), tenues par `_cache_textures` (statique, jamais relâché). Puis `IsoNuageVoxel.prechauffer()` (`iso_nuage_voxel.gd:306-326`, appelé par `iso_volumes.gd:343`) → `planche()` (`:268-295`) : `tex.get_image()` (relecture GPU), `premultiply_alpha`, `shrink_x2` jusqu'à `PLANCHE_PX = 256`, puis **boucle GDScript** `for k in range(0, d.size(), 4)` sur 65 536 pixels par planche (× 3). Appelants : `game_state.gd:1565` (dans `rebuild_arena`, `Fusee.prechauffer`, idempotent) et `Presentation3D` → `iso_volumes.gd:343` ; gardes statiques `_prechauffe`/`_voile_rechauffe` : **une fois par processus**.

### 2-3. Fréquence/coût : par lancement, avant le premier écran (`GameState._ready`). Ordre de grandeur plausible (readback ×3 ≈ quelques dizaines de ms ; boucle GDScript ≈ 20-80 ms par planche ; C++ du reste), cohérent avec les 0,2-0,4 s de la ROADMAP — **non remesuré ici** ; la ligne `[fumée voxel] préchauffé en N ms` (`iso_nuage_voxel.gd:322`) est déjà dans le `godot.log` de chaque lancement (donc dans celui du Mac d'Adrien, sans nouvelle mesure de sa part).

### 4. Invariants
`tools/test_fumee_voxel.gd:498-501` exige que `planche(t)` rende une texture carrée ≤ 256 px **et mémoïsée** (`red == IsoNuageVoxel.planche(t)`) : une planche cuite doit être préférée *dans* `planche()` (clé = `tex.resource_path`), avec repli sur le calcul. Les 2048² servent aux nappes 2D (voile à trous) : DA5.6 (« filtrage linéaire et mipmaps à l'import », « résolution sur la densité de texels ») les juge **sur-denses** (×3-4 de minification selon GAD-11, et les quatre planches de la fusée n'ont pas de mipmaps) ; GAD-11 propose de les passer à 1024², DEM-04 de n'y pas toucher : **les deux rapports divergent**, c'est une décision d'art d'Adrien, pas un correctif de code.
Corrections à l'auditeur : `fusee_corps.png` (4,2 Mo) n'est pas « libéré à la dernière fusée » — `ui.gd:3025` le charge aussi pour l'icône de la rangée de fusées du HUD (`_create_reserves_indicator`, construit par `_build_hud`), donc résident toute la session. Le renvoi « ROADMAP l. 22331 densité de texels » pointe sur l'en-tête du chantier « prêt à l'essai » : la décision est DA5.6 (l. 2556-2557 ; reprise l. 13939 et 14472).

### 5. Statut : DÉJÀ-TRANCHÉ pour le coût ; cuisson hors ligne NOUVELLE. Recoupe GAD-11 (mêmes planches ; ≈ 42 Mo = 37,8 + 4,2).

### 6. Correctif minimal et preuve
Rien à faire tant que DEM-05 n'a pas dit ce que pèsent 0,2-0,4 s dans le démarrage total. Si l'on agit : cuire `fusee_volute_N_256.png` par un outil de `tools/` (même algorithme) et le préférer dans `planche()`. **Preuve** : lire la ligne `[fumée voxel] préchauffé en N ms` d'une prise `tools/cadence_cloud/prise.sh` (llvmpipe : CPU représentatif, GL non) avant/après.

---

## DEM-07 — Glyphes absents d'Oxanium (`●`, `✓`, `▲▼◀▶`…) : repli sur une police système

**Verdict : CONFIRMÉ AVEC RÉSERVE** (l'absence des glyphes est **prouvée** ; l'effet ne l'est pas ; la liste des cas d'usage est à réduire). Sévérité corrigée : **ANECDOTIQUE** (l'auditeur : MINEUR). **Coût corrigé** : un à-coup unique, **non mesuré** (le mécanisme du repli est celui du moteur : non vérifiable ici) ; deux libellés concernés en jeu.

### 1. Ce que j'ai vérifié
- **Table des glyphes lue deux fois** (script de l'auditeur + fontTools) : `Oxanium.ttf` 357 glyphes mappés, `BigShouldersDisplay.ttf` 718 ; **`●` U+25CF et `✓` U+2713 absents des deux** ; `•` U+2022, `·`, `√` U+221A présents dans les deux ; ni l'une ni l'autre `.import` ne pose de `fallbacks` (`allow_system_fallback=true`, `fallbacks=[]`).
- **Ce que le jeu affiche réellement** (les 15 caractères absents d'Oxanium, par usage) :
  - **En manche (en ligne seulement)** : `●` — `ui.gd:1736` `ping_label.text = "● %d ms"` (`_update_ping_label`, par `UI._process` dès que `NetworkManager.has_rtt`, c'est-à-dire dès le salon). C'est le **seul** glyphe absent visible pendant une manche.
  - **Écran de fin / revanche** : `✓ PRÊT` — `game_state.gd:5673` (`btn_replay.text`).
  - **Éditeur de cartes** (`map_editor_hud.gd`, `map_editor.gd:917-918`) : `✓ ✗ ⚠ ✕ ☐ ▸ ▾ ↗ ↘ ●` — hors duel.
  - **Console seulement** (`print`/`push_warning`) : `⚠` (`iso_materiaux.gd:190`, `iso_volumes.gd:1776`), `→` (`iso_volumes.gd:1803`, `match_record.gd:269`).
  - ⚠️ **`▲▼◀▶` (`liaisons.gd:94-97`) : code mort à l'exécution** — `Liaisons.libelle_de()` n'a **aucun appelant** hors `tools/test_liaisons.gd:82-83` ; `ui.gd:8148,8405` n'utilisent que `dans_la_disposition`. L'auditeur l'a rangé parmi les affichages réels : inexact.

### 2-3. Fréquence/coût
Premier façonnage du `●` à la première mesure de RTT (dès que le lien est établi, au salon, **avant** la manche, donc pas « pile sur l'action ») ; `✓ PRÊT` à la première revanche. Si le moteur met en cache la police de repli trouvée (je le crois, non vérifié), le reste est négligeable ; s'il ne le fait pas, le `●` serait refaçonné à chaque image à cause de DEM-14/HUD-02 (l'override de thème invalide le `Label` chaque image) — **hypothèse à mesurer, pas un fait**. Aucune durée n'est avancée ici.

### 4. Invariants
Remplacer `●` par `•` (présent dans les deux polices) change la forme de la pastille de latence : décision visuelle d'Adrien. Aucun test ne lit ce texte (`grep` de `tools/` : aucun).

### 6. Correctif minimal et preuve
`•` à la place de `●` (`ui.gd:1736`) et `√`/mot à la place de `✓` (`game_state.gd:5673`) ; **test headless déterministe** (indépendant du matériel) : pour chaque littéral non ASCII des `.gd` de jeu hors commentaires et hors `print`, `FontFile.has_char()` sur la police du thème — c'est le `cmapcheck.py` de l'auditeur converti en suite. Le coût du repli ne se mesure que sur Windows/macOS (`Time.get_ticks_usec()` autour du premier `ping_label.text = …`) ; le cloud Linux (fontconfig) ne le représente pas.

---

## DEM-10 — Mise à jour : l'archive téléchargée n'est jamais supprimée (partie « archive » seulement)

**Verdict : CONFIRMÉ. Sévérité : MINEUR. Coût corrigé : 131 Mo (Windows) / 185 Mo (macOS) laissés dans `user://maj/` par mise à jour installée, pour toujours ; aucun coût CPU/GPU.** (SHA-256 + extraction bloquants : hors de ma mission, traité par RES-10.)

### 1. Le code (relu)
```gdscript
# update_manager.gd:273-277
var nom := "candela-%s.%s" % [manifeste.version, "pck" if paquet["type"] == UpdateManifest.TYPE_PCK else "zip"]
_archive = DOSSIER.path_join(nom)            # DOSSIER = "user://maj" (:72)
if FileAccess.file_exists(_archive): DirAccess.remove_absolute(_archive)     # seulement le MÊME nom, avant de retélécharger
# :296  sur empreinte invalide : DirAccess.remove_absolute(_archive)
# :308-312  preparer_bundle(_archive, …) OK → _neuf = prep["neuf"] ; Etat.PRET   ← l'archive reste
# :336-352  installer() → appliquer_bundle(racine, _neuf) → NetworkManager.quit_game()
```
`update_installer.gd:411-415` `nettoyer_apres_installation` n'efface que `racine + SUFFIXE_ANCIEN` et `.candela-maj` (l'étape décompressée) ; le script d'échange (`:210-215`) ne touche pas non plus au zip. Les seuls `remove_absolute(_archive)` sont les deux ci-dessus. Pour un `.pck`, `installer_correctif` **déplace** le fichier (`:365-382`, rename vers `user://maj/correctifs/`) : pas de reste. `docs/MISE_A_JOUR.md` ne dit rien du sort de l'archive (grep). 

### 2. Fréquence : une fois par bundle installé. Chaque version laisse son zip (le nom change avec la version).
### 4. Invariants
`tools/test_mise_a_jour.gd` (suite de l'installateur sur données synthétiques) ne couvre pas `telecharger()` (réseau) et n'affirme jamais la présence du zip : aucun test texte sur `update_manager.gd`. L'archive n'est **jamais réutilisée** (le code la supprime avant tout nouveau téléchargement du même nom ; `installer()` d'un bundle n'utilise que `_neuf`). Ne pas toucher à `user://maj/correctifs/` ni à `correctif.json`/`en_essai` (PatchLoader).
### 5. Statut : NOUVEAU. 
### 6. Correctif minimal et preuve
Une ligne `DirAccess.remove_absolute(_archive)` après `preparer_bundle` réussi (branche bundle), plus un balayage de `user://maj/candela-*.zip` à côté de `nettoyer_apres_installation` dans `UpdateManager._ready` (rattrape les restes déjà posés chez les testeurs et les échecs de préparation). **Preuve cloud** : test headless — créer `user://maj/candela-0.0.1.zip`, appeler le balayage, vérifier qu'il disparaît et que `correctifs/` survit ; + `test_mise_a_jour` inchangé.

---

## DEM-13 — Réglages moteur laissés au défaut (Jolt 3D inutilisé, « Forward Plus » périmé, pilote GL jamais comparé)

**Verdict : CONFIRMÉ. Sévérité : ANECDOTIQUE. Coût corrigé : ≈ 0, non mesuré.**

### Faits vérifiés
- `project.godot:171` `3d/physics_engine="Jolt Physics"` ; **aucun fichier** de la racine ne contient `Body3D|Area3D|RayCast3D|ShapeCast3D|PhysicsServer3D|CollisionShape3D|CollisionObject3D|PhysicsDirectSpaceState3D|…` (grep) : le monde 3D de la vue iso est du rendu pur. `project.godot:16` `config/features=("4.7", "Forward Plus")` pour `rendering_method="gl_compatibility"` (:176) ; `:175` `rendering_device/driver.windows="d3d12"` sans objet sous GL ; `:177` `import_etc2_astc=true` sans objet (aucune texture VRAM-compressée). Effet à l'exécution du libellé : aucun connu (balise de l'éditeur ; non vérifié dans le moteur) ; coût du serveur 3D à vide : **à mesurer**.
- **Pilote GL** : aucun ANGLE dans les deux zips (annuaires lus : ni `libEGL`/`libGLESv2`/`d3dcompiler` côté Windows, aucun framework ANGLE côté macOS) ; `application/export_angle=0` (Auto, `export_presets.cfg:48,313`). Aucune comparaison natif/ANGLE n'est consignée (ROADMAP, README, CLAUDE.md : le mot ANGLE au sens graphique n'y figure pas). **Correction à la question Q3 de l'auditeur** : sur macOS il n'y a **pas d'ANGLE à essayer** — l'étude du dépôt (`docs/ETUDE_ISO.md:193`) consigne « macOS : OpenGL 3.3 natif (ANGLE-over-Metal abandonné) ; Forward+/Mobile = Metal » (affirmation de l'étude, non vérifiée dans le moteur) ; la seule alternative Mac est un autre moteur de rendu sous Metal, que la décision du 2026-09-28 écarte (« pas d'essai Metal pour l'instant », ROADMAP l. 2487) et que celle du 2026-09-30 (plus de mesure sur le Mac, l. 2467) ferme de toute façon. Reste le cas **Windows** à GPU intégré (H12) : ANGLE (D3D11) y existe comme pilote mais n'est pas embarqué, donc un GL natif absent ou défaillant n'a aujourd'hui **aucun repli** — un point de robustesse plus que de cadence, **non vérifié ici** (le coût en octets d'embarquer ANGLE n'est pas chiffré).

### Statut / correctif / preuve
NOUVEAU. Rien à faire sans mesure. **Preuve cloud** : moniteur `Performance.TIME_PHYSICS_PROCESS` sur un banc de 30 s `--fixed-fps 60`, Jolt contre GodotPhysics3D (CPU, disponible en headless) ; régénérer `config/features` en rouvrant le projet dans l'éditeur.

---

## DEM-05 — Le temps de démarrage n'est ni mesuré ni consigné

**Verdict : CONFIRMÉ. Sévérité : MINEUR** (un angle mort, pas un coût ; il bloque pourtant la priorisation de DEM-03/04 et la question Q1). **Coût : aucun à l'exécution.**

### 1. Le code (vérifié)
Aucun `Time.get_ticks_*` autour de `GameState._ready` (`game_state.gd:492`), `rebuild_arena` (`:628`/`:1412`), `UI._ready` (`ui.gd:1332`) ni `NetworkManager._init_eos_async` (`network_manager.gd:793`) : aucun des appels `Time.get_ticks_*` de la racine ne chronomètre le démarrage : ils servent au RTT, aux relevés de cadence, à l'horloge de jeu, au premier allumage des lampes (`lumieres_iso.gd:316`) et aux deux lignes `préchauffé en N ms` (`iso_nuage_voxel.gd:310-323,620-631`). `ConditionsDeMatch.machine()` (`conditions_de_match.gd:150-176`) porte `vram_mo`, `textures_mo`, le pilote, la fréquence d'écran — pas de démarrage. ROADMAP : aucune occurrence d'un temps de démarrage mesuré (grep « temps de démarrage », « démarre en », « menu prêt à » : rien). Le démarrage entier est synchrone sur le fil principal (aucun `Thread`/`WorkerThreadPool`/`load_threaded_request` dans le jeu).

### 4. Invariants
`tools/test_conditions_de_match.gd:132-138` contrôle la **présence** de 18 clés de `machine()`, pas l'ensemble : ajouter `demarrage_ms` ne la casse pas. Le tamis serveur `parseConditions` (liste blanche) ignore une clé inconnue sans dommage.

### 6. Correctif minimal et preuve
`print("[démarrage] …", Time.get_ticks_msec())` à quatre points (entrée de `GameState._ready`, après `rebuild_arena()`, fin de `UI._ready`, première image après `show_main_menu()`) + une clé `demarrage_ms` dans `machine()` : le `godot.log` (vidé à chaque `print`, PE2.4) et le F6/l'historique le portent déjà vers les testeurs. **Preuve cloud** : une prise sous Xvfb (comme `prise.sh`) donne la décomposition **relative** (CPU : compilation des scripts, décodage, boucles GDScript) ; l'absolu du M3 et des GPU intégrés Windows ne vient que des journaux des testeurs.

---

## Écarts relevés dans le rapport source (résumé pour la consolidation)

1. DEM-01 : « aucune mention nulle part » pour `fond_*` → `tools/site/assembler.py:31-33` attend leurs dérivés JPEG ; `icone_macos/windows` ont un lecteur outil documenté (`tools/site/LISEZMOI.md:27`). `asset_manifest.gd` : 90 entrées audio, pas 76 ressources ; aucune image. Numéros de ligne d'`export_presets.cfg` décalés de 1 à 3.
2. DEM-02 : « tout le reste identique à l'octet » → 5 petites entrées de même taille diffèrent (caches et scènes d'export) ; sans conséquence.
3. DEM-03 : (c) contredit Q19 = B (l. 2502) ; MEN-08 surestime le décodage.
4. DEM-04 : `fusee_corps` n'est pas libéré à la dernière fusée (icône du HUD) ; renvoi « l. 22331 » sans objet ; divergence avec GAD-11 sur les 2048².
5. DEM-07 : `▲▼◀▶` est du code mort.
6. DEM-11 : le gain du lossy est plus grand que « ≈ la taille du JPG ».
7. DEM-12 : exact ; c'est la ROADMAP (l. 7659-7662) qui est fausse.
8. DEM-13 / Q3 : l'essai « GL natif contre ANGLE » n'existe pas sur macOS (`docs/ETUDE_ISO.md:193`, « ANGLE-over-Metal abandonné ») ; il ne vaut que pour Windows (H12).

## Reproduire (aucun Godot)

Les binaires de travail (PCK inflatés, ≈ 350 Mo) ont été supprimés après analyse ; `./reproduire.sh` les reconstitue en quelques secondes depuis le paquet publié (lecture seule).

```
cd audit/v7_work && ./reproduire.sh
python3 zipdir.py tail_mac.bin 185337010 20        # annuaire du zip macOS (plage finale téléchargée avec curl -r)
python3 pckx.py candela_win.pck                    # project.binary : 20 autoloads, sans _mcp_game_helper
python3 ctex_check.py                              # 33 images : 31 753 030 o dans le PCK et dans .godot/imported/
python3 refs33.py                                  # références de chacune des 33
venv/bin/python ctex_decode_bench.py               # 16 illustrations : 0,41 s (un cœur Xeon 2,8 GHz)
venv/bin/python webp_probe.py ; venv/bin/python webp_decode_cmp.py
```
URL des paquets : `https://github.com/adrienvada/Candela-2D---Godot/releases/download/v0.8.3/Candela-{windows,macos}.zip` (entrées `Candela.pck` : offset 38 539 333 ; `Candela 2D.pck` : offset 61 344 331 ; `libeosg…` : offset 165 851 541).
