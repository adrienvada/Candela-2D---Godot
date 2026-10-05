# AUD — Audio et son rendu visible

Audit d'optimisation du 2026-10-04, commit `52a29c1` (0.8.3 + SOLO S12). **Lecture seule** : Godot n'a pas été lancé, rien n'a
été écrit hors de ce dossier. Convention : **[PROUVÉ]** = établi par lecture du code ou des fichiers d'import ;
**[ESTIMÉ]** = raisonnement chiffré, ou comportement du moteur 4.x tel que je le connais (non vérifié sur 4.7) ; **non mesuré** =
aucune mesure n'existe, ni dans le dépôt ni dans la ROADMAP.

## 0. Résumé

- **L'audio est léger sur le fil principal.** `AudioManager` ne boucle sur aucune voix, ne lance aucun rayon et ne déplace
  aucune source à l'image : son `_process` n'est qu'une garde de quelques comparaisons (audio_manager.gd:2880-2929). L'occlusion se
  décide **une fois**, au démarrage de chaque son, par trois rayons — jamais suivie ensuite.
- **Le seul code audio-adjacent qui tourne à chaque image est le dessin des liserés du son rendu visible**
  (`son_visible_vue.gd:212-288`) : toute la géométrie de chaque trace vivante est reconstruite par image, en GDScript, avec
  une dizaine d'allocations par trace et un polygone moteur par trace. **Son coût n'a jamais été mesuré** : les relevés de
  cadence de la 0.8.0 notent expressément « aucun liseré dessiné » (ROADMAP l. 30506, 2466, 30467). Mon estimation : de
  0,1 à 1 ms par image dans un échange dense. C'est le constat AUD-01, le seul que je classe MAJEUR (ESTIMÉ).
- **Aucun fichier son n'est préchargé** : les 96 WAV et les 4 stings Ogg se chargent au premier usage, sur le fil principal,
  y compris au premier tir de chaque prise, à la première mort, au premier kill. Les fichiers absents (six classes sur dix n'ont
  aucun échantillon d'arme) sont re-sondés à chaque tir (AUD-02).
- Le reste est du second ordre : redondances dans l'entonnoir `play_sfx_2d` (huit classifications par son, AUD-03), 40 sons
  positionnels importés en stéréo contre le principe écrit en ROADMAP (AUD-04), une chaîne de 7 effets de bus jamais
  mesurée sur le fil audio (AUD-05), des micro-coûts froids ou de diagnostic (AUD-06). Hors périmètre perf, à signaler : six classes sur dix
  n'ont aucun échantillon d'arme, de recharge ni de clic à vide (AUD-07).
- La musique est **précalculée** (Ogg, 7 flux référencés par une ressource de 3 Ko) ; `tools/generate_music_streams.gd` n'existe
  plus. Les WAV sont en **QOA** (96/96), la mémoire audio totale reste sous 6 Mo [ESTIMÉ].

## 1. Ce qui a été lu

`audio_manager.gd` en entier (2 976 l.), `son_visible.gd`, `son_visible_vue.gd`, `screen_audio.gd` en entier ;
`enveloppes_sons.gd` (la table : 60 sons, 3 283 valeurs, aucune logique) ; `default_bus_layout.tres` ; la section `[audio]` de
`project.godot` (deux clés seulement : le layout ; **aucun** `driver/mix_rate`, `driver/output_latency` ni `general/*` : tous les
défauts du moteur) ; les 108 fichiers `.import` de `assets/audio/` (comptage ciblé, aucun binaire lu, à une exception près :
**l'en-tête de 44 octets** de `tinnitus_dazzle.wav`, pour confirmer 48 kHz / 16 bits / stéréo, cohérent avec la taille/durée de
tous les autres). Hors liste mais nécessaires pour remonter les appelants : `game_state.gd` (`_sur_son_localise`,
`_accorder_sons_aux_vues`, `rebuild_arena`, `_accorder_oreille`, fin de manche), `player.gd` (pas, dazzle, bruits de corps),
`fusee.gd` (voix de combustion), `bullet.gd`, `perception_bot*.gd`, `class_data.gd`. ROADMAP : « spatialisation du son » (l. 15451),
« Foley » (l. 18574), « Acoustique » (l. 18597), « son rendu visible » (l. 30115), « allègement de la 0.8.0 » (l. 30456) et
les « Pièges connus » audio (l. 3840, 4593, 6568, 7228, 7265, 7850, 9802, 9883, 9958, 9990).

`tools/generate_music_streams.gd` **n'existe plus** (supprimé : `docs/JOURNAL_SESSIONS.md` l. 2723 ; stems réels livrés le
2026-08-24, ROADMAP l. 10811-10818).

## 2. Carte des chemins chauds

### 2.1 Qui tourne quand

| Fréquence | Quoi | Où | Quantités au pire cas d'un duel |
|---|---|---|---|
| **Par image rendue** | `AudioManager._process` : garde « l'oreille écoute-t-elle le bon viewport ? », test du ralenti, et — seulement quand un relais d'oreille existe (vue de dessus `--2d` rendue par la racine ; J2 en écran scindé) — copie de position | audio_manager.gd:2880-2929 | 1 appel, ~10 opérations, **0 boucle, 0 rayon, 0 allocation** en régime établi |
| Par image, par joueur piloté localement | `set_dazzle_level(pid, dazzle_amount)` : écriture d'un Dictionary + `.values()` (Array alloué) | player.gd:1376 → audio_manager.gd:2847-2871 | 1 appel/image (en ligne, entraînement), 2 en écran scindé |
| Par image | `set_music_intensity(level)` : rend la main à la 2ᵉ ligne si le niveau n'a pas changé | game_state.gd:2165 → audio_manager.gd:2204-2209 | 1 |
| **Par image tant qu'une trace vit** | `SonVisibleVue._process` (vieillit les traces, `queue_redraw`) puis `_dessiner` (reconstruit **toute** la géométrie) | son_visible_vue.gd:212-222, 236-288 | de 0 à 48 traces (`TRACES_MAX`, l. 71) ; typique d'un échange : 3 à 10 ; **par vue rendue** (1 en ligne/entraînement, 2 en écran scindé) |
| Par tick physique, **dans le moteur** | mise à jour du panoramique de chaque `AudioStreamPlayer2D` qui joue (calcul d'atténuation/pan par auditeur) | moteur [ESTIMÉ] | ≤ 16 voix du pool + 1 voix « combustion » par fusée allumée (≤ ~6) |
| **Par son positionnel** (événement : 10 à 40 /s, voir 2.3) | `play_sfx_2d` : classification, volume/portée, annonce, arbitrage de voix, **3 rayons d'occlusion**, démarrage de la voix, témoin diagnostique | audio_manager.gd:1590-1713 | ~150-300 µs [ESTIMÉ] |
| Par son positionnel annoncé | `GameState._sur_son_localise` → pour chaque vue rendue : **3 rayons** + `SonVisibleVue.recevoir` (`percevoir`, `angle_a_l_ecran`, `SonVisible.animer`) | game_state.gd:6194-6213, son_visible_vue.gd:150-209 | ROADMAP : 0,02-0,08 ms pour `vie_de` (l. 30287) |
| Par son (solo contre un bot) | `PerceptionBotNoeud._sur_un_son` → `Percep.ecouter` (3 `segment_degage` GDScript purs) | perception_bot_noeud.gd:112-113, 129-140 | hors périmètre (domaine bot) |
| Par manche (début) | `rebuild_arena` → `accorder_a_la_carte` ; `demarrer_ambiance` ; `_accorder_oreille` → `poser_oreille` (16 `reparent`, `AudioListener2D.new`, relais, **écriture de `user://diagnostic_ecoute.txt`**) ; `set_in_match(true)` ; `play_music("music_match")` (instancie 4 lecteurs Vorbis) | game_state.gd:1424, 1948, 1966-1971 | une fois |
| Par manche (fin) | `set_in_match(false)`, `rendre_oreille` (16 `reparent`, 2ᵉ écriture du diagnostic), `arreter_ambiance`, `play_music("music_victory")`, sting, voix d'annonceur, acouphène | game_state.gd:4471-4478 | une fois |
| Au premier usage de chaque fichier | `ResourceLoader.exists` + `load` synchrones | audio_manager.gd:1479-1506 | 96 WAV + 4 Ogg, jamais avant |
| Au démarrage | `_ready` : 34 nœuds (16 + 16 voix, musique, annonceur), 1 `load` de la ressource musicale (7 Ogg, 2,5 Mo), `poser_limiteur`, `accorder_a_la_carte`, `appliquer_force_occlusion` | audio_manager.gd:1392-1462 | une fois |
| **Fil audio** (hors fil principal) | mixage : 4 flux Vorbis en match (base, batterie, arpège, pouls), voix QOA, 7 effets sur 5 bus, limiteur | moteur | non mesuré |

### 2.2 Réponses aux sept questions de la mission

**Q1 — Que fait AudioManager par image ?** Presque rien. [PROUVÉ] `_process` (audio_manager.gd:2880-2929) : (a) recopie
la position d'un nœud dans le relais d'oreille **quand un relais existe** (l. 2886-2888) — c'est-à-dire en vue de dessus
rendue par la racine (`--2d`) et pour J2 en écran scindé ; dans la vue iso par défaut, `Presentation3D` pose
`rendu_racine_autorise = false` (presentation_3d.gd:611, 742), l'oreille est un enfant direct du joueur
(`poser_oreille`, l. 2344-2375) et ce premier bloc ne s'exécute pas ; (b) vérifie que l'oreille écoute encore le bon viewport
(`get_tree().root`, `get_viewport()`, comparaison de `world_2d`, l. 2899-2912) et ne repose l'oreille que sur un changement de
mode de rendu ; (c) teste le ralenti (l. 2914-2916). Il n'y a **aucune boucle sur les 32 voix** (16 `AudioStreamPlayer` + 16 `AudioStreamPlayer2D`,
l. 1396-1419), **aucun rayon par voix et par image**, **aucune mise à jour de position de voix** : une voix 2D est posée
**une fois** à la position du son (`player.global_position = pos`, l. 1644) et ne bouge plus ; l'oreille, elle, est enfant du joueur
(ou d'un relais qui le recopie). Les seules boucles sur les voix sont événementielles : `_occupations` (16 lectures de
`playing` à chaque son, l. 1549-1553) et les 16 `reparent` de `poser_oreille` / `rendre_oreille` à chaque manche
(l. 2312-2314, 2693-2695). Pire cas d'un duel : **0 rayon, 0 boucle, 1 appel de 10 opérations par image**, plus les ≤ 22 voix
qui jouent côté moteur.

**Q2 — Par son joué ?** *Allocation* : pool fixe, **aucun lecteur n'est créé** à la volée (l. 1396-1419) ; en revanche chaque son
positionnel alloue des Dictionary et des chaînes (voir AUD-03). *`load()` au moment de jouer* : **oui**, paresseux, avec cache
(`_stream_cache`, l. 1488-1506) ; aucun préchargement n'existe (AUD-02). *Arbitrage de priorité* : `choisir_voix` (l. 1524-1540)
est **un seul parcours des 16 voix, sans tri**, pur et testé ; les priorités viennent d'une table par famille (l. 1306-1347).
Un son positionnel démarre au prix de **trois rayons d'occlusion** (l. 1664, seulement en frame de physique, et jamais si la
source est à moins de 48 px de l'oreille, l. 1205) ; en vue unique, `GameState` en lance **trois autres** pour le même couple
source/oreille (AUD-03).

**Q3 — Bus et effets, coût continu même silencieux ?** Cinq bus, **sept effets**, aucun compresseur :

| Bus | Envoi | Effets (default_bus_layout.tres) |
|---|---|---|
| Master (0) | — | `AudioEffectHardLimiter` (pré-gain −4,5 dB, plafond −0,5 dB), l. 45 |
| Music (1) | Master | `AudioEffectFilter` (coupure 20 500 Hz, résonance 0,81, `db`=2 → 18 dB/oct), `AudioEffectStereoEnhance` (retard 4,5 ms), l. 53-56 |
| SFX (2) | Master | `AudioEffectReverb` (room 0,15, damping 0,22, hipass 0,25, wet 0,34), `AudioEffectFilter` « EtouffementMonde » (6 dB/oct, 20 500 Hz ↔ 5 000 Hz), l. 63-66 |
| Speaker (3) | Master | aucun |
| SFX_Occlus (4) | SFX | `AudioEffectLowPassFilter` « MurPasseBas » (2 700 Hz au fichier, 12 dB/oct), `AudioEffectReverb` « ReverbOcclus » (dry 0,75, wet 0,525), l. 79-82 |

Le code réécrit les valeurs au démarrage (`poser_limiteur` l. 845, `appliquer_force_occlusion` l. 939, `appliquer_reverb_carte`
l. 1040) et à chaque manche (réverbération selon la carte). Un son occulté traverse **deux réverbérations en série**
(`SFX_Occlus` puis `SFX`) : c'est voulu (« la pièce d'à côté, puis la vôtre », ROADMAP l. 15621-15625). *Coût continu* :
[ESTIMÉ, non mesuré] le moteur 4.x garde actif un bus dont un effet déclare traiter le silence — c'est le cas des
réverbérations, pour leur queue — donc les deux réverbérations tournent en permanence sur le fil audio ; ordre de grandeur,
une réverbération stéréo à 44,1 kHz coûte quelques millions d'opérations par seconde, soit une fraction de pour cent d'un cœur.
Les filtres et le limiteur sont plus légers encore. **Rien de ceci ne touche le fil principal.** Aucune mesure du fil audio
n'existe. La seule trace est une élimination comparative d'août (ROADMAP l. 2946-2948 : « ni les torches, ni les shaders, ni
l'audio, ni le plafond de cadence ne causent les pics », section du 2026-08-25/26) — antérieure à l'occlusion, à la
réverbération par carte (2026-09-09), aux 44 fichiers livrés le 2026-08-27 (45 → 89, l. 9992) et au son rendu visible
(2026-09-29). Et les bancs de cadence tournent **Master coupé**
(`_couper_le_son`, bench_framerate.gd:1548-1555 : `set_bus_mute` + −80 dB, choix assumé contre `--audio-driver Dummy`, « un banc
de cadence ne doit pas mesurer une configuration que personne ne joue ») : le fil principal y paie `play_sfx_2d` en entier, mais
une sourdine de bus ne coupe pas le mixage du fil audio [ESTIMÉ]. Voir AUD-05.

**Q4 — Musique interactive à 170 BPM : générée ou précalculée ?** **Précalculée.** `main_stream_interactive.tres` (3 016
octets) **référence** sept fichiers `.ogg` ; il ne les embarque plus depuis le 2026-08-24 (ROADMAP l. 2789). Le seul coût au
démarrage est un `load()` synchrone dans `AudioManager._ready()` (l. 1427-1440), qui tire les 7 Ogg (intro 146 Ko, menu 582 Ko,
base 450 Ko, batterie 579 Ko, arpège 575 Ko, pouls 12 Ko, victoire 180 Ko : 2,5 Mo) — **non mesuré**, estimé très inférieur à
100 ms, dans l'autoload n° 4, avant la première image. En match, le clip « match » est un `AudioStreamSynchronized` : **quatre
décodeurs Vorbis simultanés** (le moteur mixe tous les sous-flux, y compris le pouls à −60 dB tant qu'il n'est pas appelé
[ESTIMÉ]), sur le fil audio. Au début de chaque manche, `play_music("music_match")` instancie les quatre lecteurs sur le fil
principal (estimé 0,2-1 ms, hors moment décisif). Les fondus (`set_music_intensity`, pouls, ralenti) sont des tweens
déclenchés sur changement d'état seulement.

**Q5 — Formats.** [PROUVÉ] par les fichiers `.import` :

| Dossier | Fichiers | Source (48 kHz, 16 bits, stéréo) | Import | Mono forcé |
|---|---|---|---|---|
| `sfx/` | 64 WAV | 8,0 Mo | **QOA** (`compress/mode=2`) ×64 ; 1 boucle (`fusee_combustion`) | **4** (`flesh_impact`, `footstep`, `wall_impact`, `weapon_shoot`) ; **60 stéréo** |
| `weapons/` | 24 WAV | 3,1 Mo | QOA ×24 | **20** (tirs, percuteurs) ; 4 stéréo (rechargements) |
| `voice/` | 8 WAV | 2,4 Mo | QOA ×8 | 0 (non positionnelles) |
| `music/` | 12 Ogg (7 référencés) | 3,2 Mo | `oggvorbisstr`, boucle, `bpm=170` | — |

`force/max_rate=false` et `edit/normalize=false` partout. Mémoire une fois tout chargé [ESTIMÉ, QOA ≈ 3,2 bits par
échantillon] : WAV ≈ **2,4 Mo**, Ogg ≈ 2,5-3,2 Mo en paquets compressés ⇒ **moins de 6 Mo**. CPU de décodage : QOA est
l'un des codecs les plus légers (une `AudioStreamPlaybackWAV` décode par blocs de 5 120 échantillons) ; les stems Vorbis sont
le poste le plus lourd du fil audio [ESTIMÉ]. `project.godot` ne fixe aucune cadence de mixage : **44 100 Hz par défaut**, alors
que toutes les sources sont à 48 kHz (rééchantillonnage au mixage ; sur Mac la sortie native est en général à 48 kHz, donc
un second rééchantillonnage côté système) : question de qualité plus que de cadence, voir « Questions ouvertes ».

**Q6 — Son rendu visible : coût par son et par image ; que reste-t-il actif quand l'option est coupée ?**
*Par son* [ROADMAP l. 30287] : `vie_de` 0,02-0,08 ms, une fois, à l'arrivée (par vue). *Par image* : voir AUD-01 — c'est le
poste. *Option coupée* : **il n'y a pas d'option joueur** (décision Q51, ROADMAP l. 2478 : « aucun réglage ne coupe le
liseré ; `--sans-son-visible` reste réservé au débogage ») ; le seul interrupteur est ce drapeau, **build de débogage
seulement** (game_state.gd:365-366 ; en release, `son_visible_actif` vaut toujours vrai). Quand il est posé :
`_accorder_sons_aux_vues` rend la main à sa première ligne (l. 6159) — aucun `SonVisibleVue` n'est créé, `son_localise` n'est
pas connecté, et `_annoncer` sort à sa première ligne (`if not son_localise.has_connections(): return`, l. 1732) **sauf si un
bot écoute** (perception_bot_noeud.gd:112). Le niveau, la portée et la fumée sont calculés quoi qu'il arrive : ils servent la
voix elle-même. Hors liserés vivants, un `SonVisibleVue` actif ne coûte rien : `set_process(false)` (l. 221), `_dessiner` sort
sur `_traces.is_empty()` (l. 237). En vue unique, la vue non regardée est retirée de l'arbre et vidée.
*GPU* [ESTIMÉ] : des triangles seulement au bord de l'écran (la bande la plus large et la plus épaisse, 180° × 26 px à
1080p, couvre ~78 000 pixels, soit ~4 % de l'écran ; une bande moyenne 10 000-30 000), mélange additif ; sur un GPU à tuiles
c'est quasi gratuit. Le coût est côté CPU/pilote.

**Q7 — `accorder_a_la_carte`.** Appelée par `rebuild_arena` (game_state.gd:1424), donc **à chaque début de manche**
(rebuild_arena est rappelée à chaque manche, l. 1948) et une fois à l'amorçage de l'autoload (l. 1451). Corps (l. 1056-1064) :
`diagonale_carte` (deux produits), `MapCodec.get_wall_cells(data).size()` — **décode tout le RLE des murs en
`Array[Vector2i]` pour n'en garder que la taille** —, `calculer_reverb_carte` (arithmétique), `appliquer_reverb_carte`
(huit propriétés posées sur deux effets). [ESTIMÉ] 0,2-1 ms, une fois par manche, avant le décompte : négligeable devant le
reste de `rebuild_arena` (collision, occulteurs, décor). Voir AUD-06.

### 2.3 Débit de sons au pire cas [PROUVÉ pour les constantes, ESTIMÉ pour le total]

Un pas toutes les 45 px (player.gd:1858-1884) à 260 px/s (player.gd:70), soit **5,8 pas/s par joueur**, 11,6 à deux ; un
frôlement de mur au même rythme quand on glisse contre une paroi (player.gd:1889-1890) ; chaque tir ajoute la détonation, la
douille (300-500 ms plus tard, `_tinter_la_douille`, player.gd:2940-2943) et l'impact ; la cadence va de 2 à 4 tirs/s jusqu'à
11/s pour l'Occulteur (`cooldown = 0,09`, game_state.gd:5208). Plafond théorique > 60 sons/s ; **réaliste : 15 à 40 par
seconde**. Le pool de 16 voix sature avant (les pas, priorité 0, cèdent leur voix : `choisir_voix`).

## 3. Constats

**Ordre de travail conseillé** : (1) mesurer AUD-01 (une demi-journée de micro-banc) — c'est lui qui décide si le reste du domaine
mérite qu'on s'y arrête ; (2) AUD-02 (préchargement + cache négatif : sûr, petit, retire des à-coups sur les actions décisives) ;
(3) AUD-03 (S, mécanique, gardé par des suites existantes) ; (4) AUD-04 par le script de vérification des canaux, avant toute
décision ; AUD-05/06 seulement si la mesure l'exige ; AUD-07 est à remonter à Adrien, pas à corriger.
Aucune de ces propositions ne touche aux trois gestes de l'oreille (CLAUDE.md), à l'occlusion, aux dosages jugés par Adrien
(`PORTEE_RELATIVE`, `NIVEAU_RELATIF`, courbe 0,40, force d'occlusion 0,45) ni au fil.

### AUD-01 — Le liseré reconstruit toute sa géométrie, trace par trace, à chaque image — et ce coût n'a jamais été mesuré

**Titre** : le dessin du son rendu visible rebâtit, en GDScript, la bande de chaque trace vivante à chaque image rendue.

**Où** : son_visible_vue.gd:212-222 (`_process`), 236-288 (`_dessiner`), 71 (`TRACES_MAX`) ; son_visible.gd:717-746 (`bande`),
653-680 (`etat`).

**Constat** (extraits) :

```gdscript
# son_visible_vue.gd
func _process(delta: float) -> void:
	...
	for i in range(_traces.size() - 1, -1, -1):          # vieillissement
		_traces[i]["age"] = float(_traces[i]["age"]) + delta
	...
	_toile.queue_redraw()                                 # L222 : redessin complet à CHAQUE image

func _dessiner() -> void:
	...
	for t in _traces:                                     # L250
		var etat := SonVisible.etat(t, float(t["age"]))   # L253 : un Dictionary par trace
		var b := SonVisible.bande(origine, float(t["angle"]), float(etat["largeur"]), cadre,
				float(etat["epaisseur"]) * echelle, float(etat["douceur"]))   # L256
		...
		var points := PackedVector2Array()                # L272-274 : trois tableaux neufs par trace
		var couleurs := PackedColorArray()
		var indices := PackedInt32Array()
		for i in n:                                       # 6 append par échantillon
			...
		for i in n - 1:
			indices.append_array([a, a + 1, s, a + 1, s + 1, s,     # L286 : un littéral Array de 12 entiers PAR SEGMENT
				a + 1, a + 2, s + 1, a + 2, s + 2, s + 1])
		RenderingServer.canvas_item_add_triangle_array(toile_rid, indices, points, couleurs)  # L288 : un appel PAR TRACE

# son_visible.gd:717 — le pas angulaire par défaut est 3°
static func bande(origine, angle_centre, largeur_deg, cadre, epaisseur, douceur, pas_deg: float = 3.0) -> Dictionary:
	var n := maxi(2, int(ceil(largeur_deg / maxf(pas_deg, 0.5))))
	...  # Dictionary + 4 Packed*Array + un Array[float] trié (abscisses.sort(), l. 735), puis point_du_bord() par échantillon
```

**Coût** :
- [PROUVÉ] *quand* : à chaque image rendue (fps déplafonnés) tant qu'au moins un liseré vit, **dans chaque vue rendue**. En
  jeu, c'est quasi tout le temps en présence de l'adversaire (chacun de ses pas, tirs, douilles, impacts crée une trace).
- [PROUVÉ] *combien d'échantillons* : `n = max(2, ceil(largeur/3°))`, `n+1` échantillons (+ jusqu'à 4 coins) : **5** à 10°,
  8 à 20°, 16 à 45°, 31 à 90°, **61-65** à 180° ; 4 triangles par segment. La largeur d'un liseré est 10° au contact et grandit
  avec la distance, l'occlusion et la traîne de la salle (jusqu'à 180° en quelques dixièmes de seconde pour un impact en hangar,
  ROADMAP l. 30236) : un pas à mi-portée fait ~45°, un tir démarre à ~12° et finit large.
- [PROUVÉ] *allocations par trace et par image* : 1 Dictionary (`etat`), 1 Dictionary + 4 `Packed*Array` + 1 `Array[float]`
  (`bande`), 3 `Packed*Array` (`_dessiner`), 1 littéral `Array` de 12 entiers par segment, 1 polygone envoyé au moteur.
- [ESTIMÉ] *durée* : ~3 à 8 µs de GDScript par échantillon (`point_du_bord` : une dizaine d'appels de méthodes natives ;
  `profil` ; 6 `append` ; 3 `Color()` ; une trentaine d'appels et d'opérations en tout). Calibrage tiré du dépôt : fusee.gd:339
  rapporte 8,5 ms pour 3 × 16 384 `set_pixel` GDScript, soit ~0,17 µs par appel natif sur la machine de la revue ⇒ **15-40 µs** pour un liseré net (5 échantillons), 50-130 µs à 45°,
  100-250 µs à 90°, **180-490 µs** à 180°. Dans un échange dense (5 à 10 traces de 10 à 45°) : **~0,1 à 1 ms par image**. Il n'y a **aucun
  plafond CPU** : `TRACES_MAX = 48` est un budget visuel ; 48 traces larges feraient > 10 ms (jamais atteint en pratique).
- [ESTIMÉ, moteur] `canvas_item_add_triangle_array` crée côté moteur (compat GLES3) un tampon de polygone par appel, libéré au
  prochain `queue_redraw` : N créations/destructions de tampons GL par image au lieu d'une.
- **Non mesuré** : la ROADMAP ne chiffre que `vie_de` (0,02-0,08 ms, par événement) et la relecture `etat()` « 5 µs par trace
  et par image » (l. 30287-30288) ; le dessin (`bande` + assemblage + polygone) n'y figure pas. La décomposition de la 0.8.0
  (l. 30506) classe « le son visible » dans le bruit **parce qu'aucun liseré n'était dessiné** dans la scène mesurée ; le banc
  de cadence a d'ailleurs une ligne « Son visible : actif — N liserés reçus » (bench_framerate.gd:1286-1303) précisément pour
  qu'on sache si l'on a mesuré avec ou sans — et les deux séries qui jugent la 0.8.0 (Mac, cloud) n'en avaient pas. Les moments qui comptent pour le
  « 1 % bas » (fusillade, mort) sont ceux où il y a le plus de traces et les plus larges.

**Proposition** (par ordre, chaque étape indépendante) :
1. **Mesurer d'abord** (voir « Comment le vérifier ») : si < 0,3 ms en échange dense, rétrograder en MINEUR et ne rien faire.
2. **Sans changer un pixel** : (a) **un seul appel** `canvas_item_add_triangle_array` par image pour toutes les traces
   (tableaux membres vidés par `clear()`, indices décalés de l'offset de sommet) — le mélange est additif, donc commutatif :
   l'image est identique, et les N tampons deviennent un ; (b) **cache du motif d'indices par `n`** (`static var` de
   `PackedInt32Array`) au lieu d'un littéral par segment ; (c) `bande()` jumelle qui **écrit dans les tableaux de l'appelant**
   (pas de Dictionary ni de `Array[float]` par trace), tableaux redimensionnés une fois puis remplis par index ;
   (d) ne plus produire le Dictionary d'`etat` : renvoyer des scalaires.
3. **À juger sur images** (compromis visuel, pas tranché ici) : un pas angulaire adaptatif (3° jusqu'à ~45°, puis 6° ou plus —
   au-delà, le profil est un dégradé large et lisse), ou un plafond d'échantillons par image ; et, sur les écrans > 90 Hz, ne
   reconstruire que 90 fois par seconde (à 240 fps on refait 2 à 4 fois la même géométrie — à vérifier : l'origine suit le
   joueur à l'écran image par image).
4. Variante lourde (Effort L) : porter `point_du_bord` dans un vertex shader (un maillage fixe par trace, huit uniforms) ; non
   recommandé avant la mesure, et il faudrait un `Shader` préchargé (piège du premier usage, CLAUDE.md).

**Gain attendu** [ESTIMÉ] : l'étape 2 divise par 2 à 3 le coût GDScript du dessin et ramène N polygones moteur à un ; l'étape 3
le divise encore par 2 sur les bandes larges.

**Risque** : l'étape 2 est neutre pour le rendu (mêmes sommets, mêmes couleurs, addition commutative) ; `SonVisible.bande` est
pure et gardée par `test_son_visible` (354 contrôles) et `test_son_visible_jeu` (96). L'étape 3 touche l'identité visuelle du
liseré (Adrien juge sur images : `tools/banc_son_visible.gd`) — compromis à lui présenter, pas à trancher. Aucune incidence
réseau, équité (le liseré est identique entre vues, `test_son_visible_jeu`) ni déterminisme des bancs.

**Effort** : M (étape 2) ; S (étape 3, une fois le principe accepté).

**Sévérité** : **MAJEUR** [ESTIMÉ] — MINEUR si la mesure ne dépasse pas ~0,3 ms en échange dense.

**Statut ROADMAP** : NOUVEAU. Contexte : l. 30287-30288 (coût de `vie_de` et de `etat()` seuls), l. 30506, 2466, 30467
(aucun liseré dessiné dans les mesures), l. 30183-30186 (ligne « Son visible » du banc).

**Comment le vérifier** : un micro-banc **headless** (le moteur de rendu factice rend `canvas_item_add_*` sans effet, ce qui
isole la part GDScript) : instancier `son_visible_vue.gd` avec un `Node2D` pour regardeur, lui donner 5, 10, 20 traces de
largeurs 10°/45°/90°/180° via `recevoir()` avec des événements synthétiques, puis chronométrer 1 000 appels directs de
`_dessiner()` par `Time.get_ticks_usec()`. Pour la part pilote/GPU : `bench_framerate.tscn` avec une scène qui joue des sons
(une fusillade scriptée) en A/B `--sans-son-visible`, et la ligne « Son visible : actif — N liserés reçus » comme preuve que le
banc dessinait (fenêtre réelle requise, donc pas dans `run_suites.sh`).

---

### AUD-02 — Aucun préchargement des sons : tout se charge au premier usage, aux moments décisifs ; les fichiers absents se re-sondent à chaque fois

**Où** : audio_manager.gd:1479-1506 (`get_audio_stream`), 1796-1801 (`play_weapon_shot`), 1930-1934 (`play_weapon_reload`),
1971-1972 (`play_percuteur`), 2093-2096 (`jouer_acouphene_mort`).

**Constat** (extrait) :

```gdscript
func get_audio_stream(stream_or_key: Variant) -> AudioStream:
	...
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):                 # un fichier absent n'est JAMAIS mis en cache
		var alt_path := ""
		if path.ends_with(".ogg"): alt_path = path.left(-4) + ".wav"
		elif path.ends_with(".wav"): alt_path = path.left(-4) + ".ogg"
		if alt_path != "" and ResourceLoader.exists(alt_path): path = alt_path
		else: return null                               # 2 sondes de système de fichiers, à CHAQUE appel
	var stream = load(path) as AudioStream              # synchrone, sur le fil principal, au moment de jouer
```

Aucun appelant ne précharge (recherche : `get_audio_stream` n'est appelé hors fichier que par `fusee.gd:305` et
`screen_audio.gd:489`). Le projet connaît pourtant le piège, et a déjà sa doctrine : CLAUDE.md (« un `Shader.new()` à la volée
compile au premier mort : hoquet visible pile sur l'action décisive ») et `Fusee.prechauffer`, appelée par `rebuild_arena()`
(game_state.gd:1565, fusee.gd:338-358), qui « paie hors action ce que le premier lancer paierait pile sur l'action » — les
textures de volutes (8,5 ms mesurées) et la compilation du shader du voile, par un quad invisible dessiné une image. Les
sons n'ont pas leur équivalent.

**Coût** :
- [PROUVÉ] 96 WAV (44 dans `SOUNDS`, 32 variantes de `sfx/`, 16 prises de tir, 4 percuteurs) + 4 stings Ogg se chargent
  **paresseusement**, une variante à la fois, au hasard de son tirage : la première occurrence de chaque prise de tir
  (`randi_range(1, 4)`), de chaque pas (8), douille (4), souffle (6), ricochet (3), frôlement (3) coûte un `exists` + un `load`
  synchrones **dans le tick physique qui joue le son**. Au premier kill d'une session : `hit_center`/`hit_edge`,
  `breath_hit_NN` (au coup), `tinnitus_death` (288 Ko source, chez le perdant), puis le sting (Ogg) et la voix
  (`win`/`defeat`/`spk_*`) à la fin de manche — une poignée d'images, pile sur l'action décisive.
- [ESTIMÉ] 0,1 à 1 ms par fichier sur SSD, davantage à froid ou sur disque dur ; quelques millisecondes au premier kill. Un
  événement par fichier et par session (une trentaine pendant les premières minutes) : peu pour la moyenne, mais ce sont des
  images lentes ajoutées à la traîne du « 1 % bas », pile sur l'action.
- [PROUVÉ] *Fichiers absents* : seules 4 des 10 classes ont des échantillons d'arme (`weapon_{pistolet,fusil,pompe,arbalete}`,
  assets/audio/weapons/) ; fumiste, incendiaire, sentinelle, occulteur, allumeur, spectre (`_classe(...)`, game_state.gd:5162-5238,
  slug = clé des sons, class_data.gd:24-28) n'en ont aucun. Chacun de leurs tirs fait **2 `ResourceLoader.exists` ratés** avant
  de retomber sur le `shoot` générique (l. 1799-1800) ; chacun de leurs rechargements et de leurs clics à vide aussi.
- [ESTIMÉ, moteur] la première trace dessinée utilise un `CanvasItemMaterial` additif non « unshaded » (son_visible_vue.gd:113-118),
  qui n'est pas la clé de matériau des balles/particules (additif + unshaded) : sa variante de shader canvas se compile
  probablement au premier dessin réel. À vérifier ; coût unique par exécution.

**Proposition** :
1. Une méthode `precharger()` d'`AudioManager`, idempotente, qui parcourt les chemins **déjà connus des tables** (`SOUNDS` hors
   musique interactive, `VARIANTES_SFX`, `chemin_tir`/`chemin_percuteur` pour les slugs des classes) et remplit `_stream_cache`.
   Deux façons, au choix d'Adrien : `ResourceLoader.load_threaded_request` lancé dès `_ready()` (aucun à-coup ; `get_audio_stream`
   retombe sur le `load` synchrone d'aujourd'hui si le fil n'a pas fini), ou un appel depuis `rebuild_arena()` à côté de
   `Fusee.prechauffer`, réparti sur quelques images pour ne pas payer ~100 `load` d'un coup au premier démarrage de manche
   [ESTIMÉ 30-100 ms]. Contrôle de présence conservé (les trous restent muets, règle « câbler, taire »).
2. Un **cache négatif** (`_absents: Dictionary`) pour que `get_audio_stream` ne refasse pas deux sondes par tir/recharge/clic
   des classes sans échantillon (l'invalider à l'import à chaud en débogage si besoin).
3. (À vérifier) même idiome que `Fusee.prechauffer` pour le liseré : dessiner une fois, à la création de `SonVisibleVue`, un
   triangle d'alpha 0 dans la toile additive, pour forcer la compilation de sa variante de shader hors du jeu.

**Gain attendu** : retire ~100 chargements synchrones du jeu vivant (première image lente supprimée à chaque premier usage) ;
mémoire +2,4 Mo [ESTIMÉ]. Le cache négatif supprime ~6 sondes de fichiers par seconde pour les six classes concernées.

**Risque** : nul pour le gameplay et le réseau ; veiller à ce que le préchargement ne retarde pas le lancement (fil ou étalement).
Les gardes existantes restent valides : `_test_aucun_son_orphelin` et `_test_aucun_fichier_muet` (tools/test_musique.gd:624,
677), `test_pool_sfx`. Le cache négatif doit rester invisible pour `test_musique` (« absent : câbler, taire »). Déterminisme des bancs : ne changer ni
le nombre ni l'ordre des tirages du `randf()`/`randi()` **global** (variantes, pitch, minuteur d'ambiance) — les bancs de duel
reseedent par image et comparent des flux de hasard (ROADMAP l. 3408-3429) ; le préchargement n'en tire aucun.

**Effort** : S.

**Sévérité** : MINEUR.

**Statut ROADMAP** : NOUVEAU (aucun préchargement audio n'est discuté ; précédent côté shaders et textures : CLAUDE.md,
`Fusee.prechauffer`, game_state.gd:1565).

**Comment le vérifier** : en headless (pilote audio factice), chronométrer `AudioManager.get_audio_stream(chemin)` pour chaque
chemin des tables, à froid puis à chaud ; compter les appels à `ResourceLoader.exists` pendant 100 tirs d'une classe sans
échantillon ; `Time.get_ticks_usec()` autour de `play_sfx_2d` au premier tir de chaque prise.

---

### AUD-03 — L'entonnoir `play_sfx_2d` recalcule huit fois la même classification et lance deux fois les mêmes rayons

**Où** : audio_manager.gd:1590-1713 (`play_sfx_2d`), 382-399 (`famille_de`), 648-649, 766-769, 1543-1547, 1549-1553 (`_occupations`),
1284-1289 (`occultation_fumee`), 1152-1173 (`part_occultee`) ; game_state.gd:6194-6213 (`_sur_son_localise`).

**Constat** : pour **un seul** son positionnel, `famille_de()` — pour un pas : 4 `get_file()`, 2 `get_basename()`, 1 `rsplit`,
1 `is_valid_int`, via `est_un_percuteur` et `est_un_tir` qu'elle rappelle — est évaluée **8 fois** (7 pour un coup de feu, le premier
test étant un `elif`) :

```gdscript
elif famille_de(stream_or_key).begins_with("footstep") and ...                       # L1616 (1)
var niveau_source := volume_final + float(
	_niveau_dose.get(famille_de(stream_or_key),                                       # L1624 (2)
		niveau_relatif_de(stream_or_key)))                                            #   -> famille_de (3), évalué MÊME si la clé existe
var portee_source := portee_courante(stream_or_key) * facteur_portee                  # L1626 -> famille_de x2 (4, 5), L767-768
_annoncer(stream_or_key, ...)                                                         # L1632 -> "famille": famille_de(...) (6), L1736
var prio := priorite_de(stream_or_key)                                                # L1635 -> famille_de (7), L1547
var _fam := famille_de(stream_or_key)                                                 # L1684 (8)
```

Autres redondances sur le même chemin : `Dictionary.get(clé, défaut)` **évalue son défaut** même quand la clé existe — et en jeu
`_niveau_dose` / `_portee_dosee` sont vides (« vides en jeu », l. 651-656) ; `_occupations` lit `playing` par
`bool((p as Node).get("playing"))` sur 16 voix (propriété dynamique) ; `occultation_fumee` appelle
`get_tree().get_nodes_in_group("fusees")` (Array alloué) à chaque son, même sans fusée ; et **en vue unique** (en ligne,
entraînement) l'occlusion du même couple (source, oreille) est calculée **deux fois** : `GameState._sur_son_localise` lance trois
rayons par `part_occultee_entre` (l. 6206-6209) pendant `_annoncer`, puis `part_occultee(pos)` en relance trois (l. 1664 →
1173) — l'oreille est portée par le joueur que la vue regarde. Enfin `_sur_son_localise` lance ses rayons **avant** que
`recevoir` ne rejette ce qui ne dessine rien (famille muette, hors portée, trop près ; l. son_visible_vue.gd:153-166).

**Coût** : [ESTIMÉ] `famille_de` ≈ 3 µs sur un chemin à variante ⇒ ~25 µs par son pour la classification seule ; l'ensemble du
chemin d'un son positionnel est de l'ordre de 150-300 µs (classification ~25-30 %, rayons ~40 µs, `vie_de` 20-80 µs d'après la
ROADMAP, Dictionaries d'annonce et de témoin, démarrage de la voix). À 15-40 sons/s, c'est ~0,5-1 % d'un cœur en moyenne, mais
concentré : 1 à 3 sons dans la même image ajoutent 0,2 à 0,9 ms. Le principe « une requête physique par son » est **accepté**
(ROADMAP l. 15639-15645) ; c'est le doublon en vue unique et l'ordre des gardes qui ne le sont pas. NB : le rapport JOU
(`05_JOU_joueur_balles.md:90`) estime un pas entier — empreinte comprise — à 60-120 µs ; mon estimation du seul chemin
audio + liseré (150-300 µs) est plus haute. Les deux sont des estimations : l'écart se tranche par la mesure, pas ici.

**Proposition** : (1) calculer `var fam := famille_de(stream_or_key)` **une fois** en tête de `play_sfx_2d` et le passer aux
tables (`_niveau_dose.get(fam, NIVEAU_RELATIF.get(fam, …))`, une variante de `portee_courante` prenant la famille,
`SFX_PRIORITE.get(fam, …)`, `_annoncer`, `_sons_par_famille`) — la vérité de classification reste **une seule fonction**
(leçon ROADMAP l. 10035-10041) ; (2) lire `playing` en accès typé (`pool: Array[AudioStreamPlayer2D]`) ; (3) ne pas appeler
`get_nodes_in_group` quand aucune fusée n'existe (`get_tree().get_node_count_in_group("fusees") == 0`, ou un registre statique
tenu par `Fusee`) ; (4) laisser `recevoir` demander la part occultée **après** ses rejets bon marché (catégorie, émetteur,
distance, portée — il les fait déjà, son_visible_vue.gd:153-166) au lieu que `_sur_son_localise` la calcule d'avance, et
réutiliser le résultat de l'oreille quand la vue regardée est celle qu'elle porte (ou le transporter dans l'événement) : une
seule géométrie, déjà partagée par `part_occultee_entre`. La signature de `recevoir(evenement, regardeur, part)` est lue par
`test_son_visible_jeu` : à adapter avec elle.

**Gain attendu** : [ESTIMÉ] 50-100 µs par son (30-40 % du chemin) ; aucune allocation de moins sur le chemin des voix.

**Risque** : ne touche **pas** aux trois gestes de l'oreille ni à l'occlusion ; les gardes existantes couvrent le comportement
(`test_dosage_audio` 70 contrôles, `test_son_visible_jeu` 96 — « ce qui est annoncé est ce que la voix joue » —, `test_oreille`,
`test_pool_sfx`). Aucun effet sur le fil ni l'équité. Déterminisme des bancs : mêmes nombres, mêmes tirages du hasard global (ROADMAP
l. 3408-3429) ; `maintenant`, lu à l'horloge murale (`Time.get_ticks_msec`, l. 1602), reste lu UNE fois par son — le piège
des bancs déroulés plus vite que le jeu (l. 3387-3395) ne doit pas être aggravé.

**Effort** : S.

**Sévérité** : MINEUR.

**Statut ROADMAP** : NOUVEAU (l. 15639-15645 acceptent le coût d'une requête physique par son ; le doublon audio / liseré en vue
unique n'est mentionné nulle part).

**Comment le vérifier** : en headless, 1 000 appels de `play_footstep` / `play_weapon_shot` (pilote audio factice) chronométrés
avant/après ; `part_occultee_entre` compté par un compteur d'appels temporaire pendant un duel de banc.

---

### AUD-04 — 40 sons positionnels sont importés en stéréo, contre le principe écrit « un flux stéréo dilue le panoramique »

**Où** : `assets/audio/sfx/*.wav.import` (`force/mono=false`) ; principe : ROADMAP l. 11166-11169 et 15456-15458 ; garde
existante : `tools/test_musique.gd:229` (`_test_armes`, « toutes en mono » : les 16 prises de tir seulement).

**Constat** [PROUVÉ] : `force/mono=true` ne couvre que 4 fichiers de `sfx/` (les plus anciens) et 20 de `weapons/`. Les 60 autres
de `sfx/` sont importés **stéréo**, dont **40 sont joués en positionnel** : `footstep_a_01..04`, `footstep_b_01..04`,
`ricochet_01..03`, `shell_01..04`, `wall_brush_01..03`, `breath_hit_01..06`, `hit_center`, `hit_edge`, `bolt_flight`,
`fusee_lancer`, `fusee_rebond`, `fusee_atterrit`, `fusee_eteinte`, `fusee_combustion` (boucle), `ambience_01..08` (et
`torch_on`/`torch_off`, positionnels pour les seuls PNJ de l'aventure, player.gd:1818). Or la ROADMAP écrit : « Les fichiers sont forcés en mono à l'import, comme le reste des effets : ils se jouent en
2D positionnel […] Un flux stéréo dans un lecteur positionnel dilue le panoramique — la source cesse d'être un point » (l. 11166-11169).
Les livraisons ultérieures sont au « standard broadcast » **stéréo** (l. 18576) et n'ont pas reçu `force/mono`. Les pas, le
frôlement, les douilles et les impacts sont précisément les sons dont la **direction est l'information**.

```ini
# assets/audio/sfx/footstep_a_01.wav.import (même contenu pour les 59 autres stéréo)
force/mono=false
compress/mode=2
# assets/audio/weapons/weapon_pistolet_01.wav.import (les 20 armes)
force/mono=true
```

**Coût** : [ESTIMÉ] décodage QOA et mixage ×2 sur ces voix (jusqu'à 16 voix + une boucle de combustion par fusée allumée) ;
mémoire : ≈ 2,4 Mo → 1,8 Mo si tous passaient en mono (−0,6 Mo). Négligeable côté cadence. L'enjeu est la **localisation** (qualité
et équité de l'information), pas les millisecondes.

**Proposition** : (1) vérifier si ces sources sont de vrais fichiers stéréo ou du « double mono » (gauche = droite) — dix lignes
de Python (`wave`, comparaison des deux canaux) sur 40 petits fichiers ; (2) si double mono : `force/mono=true` sur les 40 `.import`
est **sans effet audible**, gain pur ; (3) si vrai stéréo : décision d'Adrien (la somme en mono change timbre et niveau, donc
repasser au banc `tools/banc_audio.tscn` / `banc_mixage`), à la lumière de son principe V4.1.

**Gain attendu** : fil audio allégé sur ces voix ; mémoire −0,6 Mo ; panoramique de source ponctuelle rétabli si les fichiers sont
réellement stéréo.

**Risque** : si vrai stéréo, le niveau/timbre jugés par Adrien au banc (2026-08-26) peuvent bouger de quelques dB ; l'enveloppe
du son visible est précalculée sur les **sources** (`enveloppes_sons.py:26`, moyenne des puissances des canaux) et gardée par
empreinte (`test_enveloppes_sons`) : elle ne change pas avec l'import.

**Effort** : S (réimport de 40 fichiers) ; décision d'Adrien pour le cas stéréo.

**Sévérité** : MINEUR.

**Statut ROADMAP** : DÉJÀ-TRANCHÉ pour le principe (l. 11166-11169, 15456-15458) ; l'écart constaté (livraisons du 2026-08-27 et
du 2026-09-08/09 restées en stéréo) est NOUVEAU.

**Comment le vérifier** : script Python hors jeu comparant L et R de chaque source ; puis réimport et A/B au banc audio.

---

### AUD-05 — La chaîne d'effets (7 effets dont 2 réverbérations, 4 flux Vorbis en match) n'a jamais été mesurée sur le fil audio

**Où** : default_bus_layout.tres:45-82 ; audio_manager.gd:1427-1440 (ressource musicale), 845-860, 939-953, 1040-1053.

**Constat** [PROUVÉ] : voir Q3 — 5 bus, 7 effets, deux `AudioEffectReverb` (SFX, SFX_Occlus), un limiteur sur Master, un filtre
18 dB/oct + un « stereo enhance » sur Music, deux filtres sur SFX/SFX_Occlus ; musique : quatre `AudioStreamPlaybackOggVorbis` en
match, un en menu. Aucun relevé de CPU du fil audio n'existe : la ROADMAP range l'audio parmi les « zones franches » sans le
chiffrer (l. 34218).

```ini
# default_bus_layout.tres
bus/2/effect/0/effect = SubResource("AudioEffectReverb_j3pel")      # SFX : réverbération
bus/2/effect/1/effect = SubResource("AudioEffectFilter_monde")      # SFX : « EtouffementMonde »
bus/4/send = &"SFX"                                                # SFX_Occlus se déverse dans SFX
bus/4/effect/1/effect = SubResource("AudioEffectReverb_occlus")     # SFX_Occlus : seconde réverbération
```

**Coût** : [ESTIMÉ] le fil audio, estimé à quelques pour cent d'un cœur (réverbérations en continu, décodage Vorbis ×4, voix
QOA), n'entre pas dans le temps d'image ; il ne compte que sur une machine à peu de cœurs (le cloud en a quatre, un poste de
joueur modeste aussi) par contention avec le fil principal et le fil de rendu. Aucune preuve qu'il pèse.

**Proposition** : **ne rien changer sans mesure.** Mesurer d'abord (voir ci-dessous). Si le fil audio dépasse ~10 % d'un cœur, les
leviers dans l'ordre du moindre risque : mono des voix positionnelles (AUD-04) ; `compress/mode=0` pour les sons très courts et
très fréquents (pas, impacts : moins de décodage contre 5× plus de mémoire pour ces fichiers) ; couper la réverbération de
`SFX_Occlus` quand aucune voix n'y est routée (risque de clics ; arbitrage sonore d'Adrien, ROADMAP l. 15613-15625).

**Gain attendu** : inconnu (non mesuré).

**Risque** : sonore (timbre, clics) ; aucun si l'on se contente de mesurer.

**Effort** : S (mesure).

**Sévérité** : ANECDOTIQUE (tant que non mesuré).

**Statut ROADMAP** : NOUVEAU (l. 34218 classe l'audio « ouvert, zones franches » sans mesure ; la seule élimination comparative,
l. 2946-2948, date du 2026-08-25/26 et précède l'occlusion, la réverbération par carte, les 44 fichiers du 2026-08-27 et le
son rendu visible).

**Comment le vérifier** : en menu (musique seule) puis en match de banc, lancer avec `--audio-driver Dummy` et relever le temps
CPU du processus (`/proc/<pid>/stat`) sur 60 s ; comparer avec `AudioServer.set_bus_effect_enabled(...)` coupé sur les deux
réverbérations, puis avec la musique en pause. Le pilote factice mixe quand même à cadence réelle. Ceci mesure le fil audio, pas la cadence : le banc de cadence refuse
`Dummy` à juste titre (bench_framerate.gd:1545-1547).

---

### AUD-06 — Micro-coûts résiduels et froids

**Où** et **constat** (chacun tient en une ligne de correction) :
- audio_manager.gd:2847-2871 `set_dazzle_level`, appelée **à chaque image** par joueur piloté (player.gd:1376) : écrit un
  Dictionary puis `for v in _dazzle_levels.values()` (l. 2850) alloue un Array par image. Remplacer par un parcours des clés ou
  rendre la main si `amount` n'a pas changé.
- audio_manager.gd:1056-1064 `accorder_a_la_carte`, **à chaque manche** : `MapCodec.get_wall_cells(data).size()` décode tout le RLE
  en `Array[Vector2i]` pour n'en garder que la taille (~0,2-1 ms [ESTIMÉ]). Un compte de longueurs de runs, ou la valeur que
  `rebuild_arena` connaît déjà, suffirait.
- audio_manager.gd:2630-2651 `_tracer_ecoute` : à chaque pose et chaque retrait d'oreille (donc ~2 fois par manche) écrit un bloc
  de ~25 lignes dans `user://diagnostic_ecoute.txt` en **ajout sans borne** (`seek_end`, `flush`) — le fichier croît de ~5 Ko par
  manche pour toute la vie de l'installation ; personne ne le tronque (aucune autre occurrence de `FICHIER_DIAGNOSTIC`).
  Le garder, mais le tronquer au lancement ou ne retenir que les derniers blocs.
- asset_manifest.gd:247-254 `AssetManifest.summary()`, appelée par le panneau **F3** toutes les 0,25 s tant qu'il est ouvert
  (ui.gd:1861-1864) : `missing()` et `placeholders()` parcourent chacune les 90 entrées attendues (`ResourceLoader.exists`, et en
  projet non exporté `FileAccess.file_exists` + `open`/`get_length`/`close`), soit ~270 sondes de fichiers par appel ; le résultat
  ne peut pas changer pendant l'exécution. [ESTIMÉ] 1 à 5 ms toutes les 250 ms tant que F3 est ouvert — c'est-à-dire un à-coup
  périodique dans la cadence qu'on est justement en train de lire sur ce panneau. À calculer une fois et garder (`static var`).
  Hors périmètre strict (le panneau est à l'interface) mais le coût est dans le manifeste audio.

```gdscript
# audio_manager.gd:2848-2851, appelée à chaque image (player.gd:1376)
_dazzle_levels[pid] = amount
var niveau := 0.0
for v in _dazzle_levels.values():         # Array alloué à chaque image
	niveau = maxf(niveau, float(v))
# audio_manager.gd:1062, à chaque manche
ratio_murs = float(MapCodec.get_wall_cells(data).size()) / float(total)   # décode tout le RLE pour un compte
# audio_manager.gd:2641-2651, à chaque pose/retrait d'oreille
var f := FileAccess.open(FICHIER_DIAGNOSTIC, FileAccess.READ_WRITE) ... f.seek_end() ... f.store_string(bloc + "\n") ... f.flush()
```

**Coût** : [ESTIMÉ] quelques microsecondes par image (dazzle), < 1 ms par manche (carte, diagnostic) — hors chemins décisifs.

**Recoupements** (constats indépendants des autres sous-agents, à ne pas compter deux fois) : `09_HUD_interface_en_manche.md`
(HUD-11 : `_tracer_ecoute` en ajout sans plafond), `14_CAR_cartes_replay.md:271` (`accorder_a_la_carte` décode les murs « juste
pour compter »), `05_JOU_joueur_balles.md:60` (`values()` de l'audio dans `Player._process`).

**Proposition / Gain / Risque** : corrections locales sans effet sur le comportement ; aucun risque ; gain négligeable.

**Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU (le diagnostic d'écoute est voulu — audio_manager.gd:2612-2625 explique pourquoi il écrit dans un
fichier en release ; c'est sa croissance sans borne qui n'est pas dite).

**Comment le vérifier** : lecture ; `ls -l` de `user://diagnostic_ecoute.txt` après quelques manches ; pour F3, chronométrer
`AssetManifest.summary()` (`Time.get_ticks_usec()`) dans un export et dans le projet.

---

### AUD-07 — [hors périmètre perf, à signaler] Six classes sur dix n'ont ni tir propre, ni rechargement, ni clic à vide : l'information correspondante est muette ET invisible

**Où** : audio_manager.gd:1796-1801, 1930-1934, 1971-1972, 1590-1593 ; assets/audio/weapons/ ; class_data.gd:24-28.

**Constat** [PROUVÉ] : le slug d'une classe est « la clé de ses sons » (class_data.gd:24-28). Pour fumiste, incendiaire, sentinelle,
occulteur, allumeur, spectre, aucun `weapon_<slug>_NN.wav`, `weapon_dry_<slug>.wav` ni `weapon_reload_<slug>.wav` n'existe.
Le tir retombe sur le `shoot` générique (voulu, l. 1783-1787) ; mais `play_weapon_reload` rend `null` (l. 1932) et `play_percuteur`
→ `play_sfx_2d` rend `null` **avant `_annoncer`** (l. 1591-1593) : le clic à vide et le rechargement de ces classes ne sont
ni audibles ni dessinés au bord de l'écran adverse, alors que ceux des quatre classes d'origine le sont (Q54, ROADMAP l. 2478 :
« oui on le rend audible »). Une classe choisie change donc ce qu'on trahit.

```gdscript
# audio_manager.gd:1971-1972 et 1590-1593
func play_percuteur(slug: String, pos: Vector2, emetteur: int = -1) -> AudioStreamPlayer2D:
	return play_sfx_2d(chemin_percuteur(slug), pos, 1.0, 0.0, BUS_SFX, emetteur)
func play_sfx_2d(...):
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return null                       # AVANT _annoncer() : ni voix, ni liseré
```
`tools/test_musique.gd` (`_test_armes`, `_test_aucun_son_orphelin`) ne boucle que sur `["pistolet", "fusil", "pompe",
"arbalete"]` : rien ne signale l'absence des six autres.

**Coût** : sans objet pour la cadence ; question d'**honnêteté en compétition** (la seconde aune du projet).

**Proposition** : signaler à Adrien ; si c'est un manque de livraison, câbler un repli par arme générique (comme pour le tir) ou
livrer les échantillons ; si c'est voulu (classes plus silencieuses), l'écrire. Ne pas corriger ici.

**Gain / Risque / Effort** : n/a pour la perf ; Effort L si assets à produire. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU
(non trouvé par recherche des noms de slug, des « six classes » et des échantillons).

**Comment le vérifier** : `ls assets/audio/weapons/` ; `play_percuteur("spectre", Vector2.ZERO)` doit rendre `null` en headless (non exécuté ici).

## 4. Ce qui est déjà bien fait (à ne pas casser)

1. **Un pool fixe de 16 + 16 voix**, créé une fois, et un arbitrage de priorité **en un seul parcours sans tri**
   (`choisir_voix`, audio_manager.gd:1524-1540), pur, testé en headless. Les pas cèdent leur voix aux sons qui renseignent.
2. **Aucun travail par voix et par image.** L'occlusion est décidée **au démarrage du son** (trois rayons, uniquement en frame de
   physique, jamais sous 48 px, l. 1205), le bus est choisi à cet instant (une voix, pas deux — audio_manager.gd:1088-1092) ; `_process`
   ne fait que garder l'invariant de l'oreille. Les trois gestes de l'oreille (pool déménagé dans le monde de la vue, viewport
   activé, `AudioListener2D` posé) sont intacts et **hors de toute proposition ci-dessus**.
3. **Rien ne se construit sans abonné** : `_annoncer` sort sur `has_connections()` (l. 1732) ; `set_music_intensity` et
   `set_dazzle_level` sont documentés idempotents ; les tweens (filtre, intensité) ne naissent que sur changement d'état, en
   temps réel quand il faut (`set_ignore_time_scale`, l. 2118).
4. **La forme d'onde du liseré est précalculée hors ligne** (`enveloppes_sons.gd` généré par `tools/enveloppes_sons.py`, gardé par
   empreinte) au lieu d'analyser des WAV au jeu ; la vie d'un liseré se calcule **une fois** à l'arrivée (0,02-0,08 ms), le lissage VU
   est mis en cache par fichier (`_vu_par_chemin`, son_visible.gd:517-530), `SonVisibleVue` s'éteint (`set_process(false)`) sans
   trace, et la toile n'est faite que de triangles au bord de l'écran, jamais d'un plein cadre additif — important sur un GPU à tuiles.
5. **Musique précalculée et référencée** (Ogg, 3 Ko de ressource) ; WAV en QOA (96/96) : mémoire audio < 6 Mo, aucune
   génération à l'exécution.
6. **Une seule classification sonore** (`famille_de`) pour portée, niveau, priorité et son visible — une vérité unique (ROADMAP
   l. 10035-10041). Les corrections proposées (AUD-03) la conservent.
7. **Aucun `print()` en chemin chaud** : le diagnostic d'écoute n'imprime qu'en build de débogage (`if OS.is_debug_build()`, l. 2635),
   ce qui compte avec `flush_stdout_on_print=true`.
8. Un **limiteur unique** sur Master posé par le code, une **marge** plutôt qu'une compression (DA3.9) : pas d'étage de plus qui
   travaille tout le temps (audio_manager.gd:810-815).

## 5. Questions ouvertes

1. **(Mesure, tranche AUD-01)** Combien coûte réellement `_dessiner` en fusillade dense, en GDScript (micro-banc headless) puis
   avec le pilote GPU (banc de cadence, vraie fenêtre, A/B `--sans-son-visible`) ? Les séries de la 0.8.0 ne contenaient pas de sons.
2. **(Mesure, tranche AUD-05)** Quelle part d'un cœur occupe le fil audio (menu seul, match, match sans réverbérations) ?
3. **(Adrien, AUD-04)** Les sons positionnels livrés après V4.1 doivent-ils être mono comme les armes ? Sont-ils de vrais
   stéréos ? Si oui, c'est un choix de rendu du panoramique, pas d'optimisation.
4. **(Adrien, AUD-07)** Les six classes sans échantillons d'arme, de recharge et de clic à vide : manque de livraison ou
   silence voulu ? L'information qu'elles trahissent diffère des quatre autres.
5. **(Adrien, qualité/latence, sans enjeu de cadence)** `audio/driver/mix_rate` n'est pas fixé (44 100 Hz) alors que les sources
   et, en général, la sortie du Mac sont à 48 kHz : deux rééchantillonnages. À juger à l'oreille et à la latence EOS ; non
   traité ici. `output_latency` est aussi au défaut du moteur.
6. **(Hors périmètre perf)** `tinnitus_dazzle.wav` est importé sans boucle (`edit/loop_mode=0`, 2 s) alors que le code et son
   commentaire parlent d'une « boucle » dont le volume suit l'éblouissement (audio_manager.gd:2839-2871) : si l'éblouissement
   dure plus de 2 s à niveau constant, `set_dazzle_level` sort tôt (l. 2854-2855) et ne relance pas le son. À écouter.
7. **(Choix de moment, AUD-02)** Le préchargement doit-il se faire au lancement (fil), à l'écran titre, ou pendant le décompte de
   la première manche ?
8. **(Vérification moteur)** Mes estimations de comportement du moteur 4.7 — tampon de polygone par `canvas_item_add_triangle_array`
   en compat, bus actif tant qu'une réverbération déclare traiter le silence, variantes de shader canvas compilées au premier
   dessin — viennent de ma connaissance de la série 4.x ; elles se vérifient dans le source du moteur ou au profileur.

## Annexe — chiffres de référence

- 96 WAV, 13,57 Mo de sources ; QOA estimé 2,4 Mo (1,8 Mo si les 40 positionnels passaient en mono) ; 12 Ogg, 3,23 Mo (7
  référencés par la ressource interactive : 2,52 Mo).
- 52 entrées dans `SOUNDS` (44 WAV, 7 Ogg, 1 ressource) ; 32 variantes dans `VARIANTES_SFX` ; 4 prises par arme (4 armes).
- Portées (carte par défaut 32×32 tuiles de 35 px, diagonale 1 584 px, facteur 1,8) : pas 1 711 px, tir 2 423 px.
- Liseré : `TRACES_MAX` 48 ; pas angulaire 3° ; 4 triangles par segment ; largeur 10° (net) à 180° ; épaisseur 6-26 px à 1080p.
