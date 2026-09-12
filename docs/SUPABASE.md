# Supabase — déploiement du classement

> Phase 4, étape 1 : **l'identité, et rien d'autre**. Aucun ELO n'est calculé.
> Ce document dit ce qu'il y a à déployer et comment. Le pourquoi est dans
> [ROADMAP.md](ROADMAP.md).

**Déployé et vérifié en production le 2026-08-16.** Ce document reste la marche
à suivre : pour une seconde machine, pour un projet neuf, ou pour redéployer
après une modification. Les commandes marquées ✅ ont déjà été passées sur le
projet ci-dessous.

| | |
|---|---|
| Projet | `Candela 2D - Godot` |
| Référence | `obnlcnwlkuojmplksxtu` |
| Région | AWS `eu-west-1` |

---

## Ce qui est déployé

```
supabase/
├── config.toml                        les deux fonctions, sans jeton Supabase
├── migrations/
│   ├── 20260816160000_players_identity.sql
│   └── 20260816183000_functions_return_setof.sql
└── functions/
    ├── _shared/
    │   ├── epic.ts                    vérification du jeton signé par Epic
    │   ├── recovery_code.ts           tirage et validation du code
    │   ├── db.ts                      appel des fonctions SQL
    │   ├── http.ts                    porte d'entrée commune
    │   ├── epic_test.ts               ⟵ tests, jamais déployés
    │   └── recovery_code_test.ts      ⟵ tests, jamais déployés
    ├── identify/index.ts              POST — crée ou retrouve le profil
    └── link/index.ts                  POST — rattache une machine par code
```

Les fichiers `*_test.ts` ne font pas partie du paquet envoyé : `supabase
functions deploy` ne remonte que ce que `index.ts` importe réellement.

---

## Les commandes, dans l'ordre

Toutes se lancent depuis la racine du dépôt.

### 1. Installer la CLI — ✅ fait le 2026-08-16

Installée en **binaire autonome** dans `~/.local/bin`, déjà présent dans le
`PATH`. Version 2.114.0, vérifiée : `supabase --version`.

**Pourquoi pas Homebrew.** `brew install supabase/tap/supabase` échoue sur cette
machine : Homebrew 6 sur macOS 26 exige des Command Line Tools 26.3, celles
installées sont en 16.4. Les remettre à niveau coûte ~2 Go et un mot de passe
administrateur, pour un outil qui n'a besoin ni de l'un ni de l'autre.

Pour refaire l'opération ailleurs (ou après une purge) :

```bash
curl -fsSL -o /tmp/supabase.tar.gz https://github.com/supabase/cli/releases/download/v2.114.0/supabase_darwin_arm64.tar.gz && curl -fsSL -o /tmp/checksums.txt https://github.com/supabase/cli/releases/download/v2.114.0/checksums.txt
```

Vérifier l'empreinte **avant** d'extraire — l'archive fait 39 Mo et s'installe
dans un dossier du `PATH` :

```bash
grep _darwin_arm64.tar.gz /tmp/checksums.txt | sed 's/supabase_2\.114\.0_darwin_arm64\.tar\.gz/supabase.tar.gz/' > /tmp/verif.sha256 && (cd /tmp && shasum -a 256 -c verif.sha256)
```

```bash
mkdir -p ~/.local/bin && tar -xzf /tmp/supabase.tar.gz -C ~/.local/bin supabase supabase-go && chmod +x ~/.local/bin/supabase ~/.local/bin/supabase-go
```

L'archive contient **deux** binaires : `supabase` délègue une partie de son
travail à `supabase-go`. N'extraire que le premier laisse une CLI qui répond à
`--version` mais peut échouer plus loin.

Sur une machine Intel, remplacer `darwin_arm64` par `darwin_amd64`.

### 2. S'authentifier — ✅ fait

Ouvre un navigateur.

```bash
supabase login
```

### 3. Rattacher le dépôt au projet — ✅ fait

Demande le mot de passe de la base (celui choisi à la création du projet). Il est
retenu ensuite : `db push` ne le redemande pas. L'état local du lien vit dans
`supabase/.temp/`, ignoré par git — il est propre à une machine.

```bash
supabase link --project-ref obnlcnwlkuojmplksxtu
```

### 4. Pousser le schéma — ✅ fait

Crée la table, ferme la Row Level Security, installe les deux fonctions SQL.

```bash
supabase db push
```

### 5. Donner à Epic ses identifiants — ✅ fait

`EPIC_CLIENT_ID` est ce que le jeton doit annoncer en `aud` ; `EPIC_DEPLOYMENT_ID`
sépare la production du bac à sable. **Sans `EPIC_CLIENT_ID`, les fonctions
refusent tout** — une configuration incomplète ne dégrade jamais en « on laisse
passer ».

La commande les lit dans `eos_credentials.gd` sans les afficher :

```bash
supabase secrets set EPIC_CLIENT_ID="$(sed -n 's/^const CLIENT_ID := "\(.*\)"/\1/p' eos_credentials.gd)" EPIC_DEPLOYMENT_ID="$(sed -n 's/^const DEPLOYMENT_ID := "\(.*\)"/\1/p' eos_credentials.gd)"
```

Vérifier que les deux sont bien posées (la commande n'affiche que des empreintes,
jamais les valeurs) :

```bash
supabase secrets list
```

### 6. Déployer les deux fonctions — ✅ fait

```bash
supabase functions deploy identify --no-verify-jwt
```

```bash
supabase functions deploy link --no-verify-jwt
```

`--no-verify-jwt` est délibéré et redondant avec `config.toml` : ces fonctions ne
sont pas protégées par un jeton Supabase. **Leur authentification est le jeton
signé par Epic**, qu'elles vérifient elles-mêmes. Exiger en plus un jeton
Supabase n'ajouterait rien — la clé publiable est embarquée dans le jeu, donc
connue de tous.

---

## Vérifier que c'est en place

### Un PUID posté sans jeton valide est refusé

C'est le contrôle qui compte le plus. Les trois doivent échouer.

```bash
curl -s -X POST "https://obnlcnwlkuojmplksxtu.supabase.co/functions/v1/identify" -H "Content-Type: application/json" -d '{"puid":"0002fb8a4c6d4f8e9b1c2d3e4f5a6b7c"}'
```

Attendu : `401` — `{"raison":"jeton_absent",…}`. Le PUID posté n'est même pas lu.

```bash
curl -s -X POST "https://obnlcnwlkuojmplksxtu.supabase.co/functions/v1/identify" -H "Content-Type: application/json" -d '{"id_token":"nimportequoi"}'
```

Attendu : `401` — `{"raison":"jeton_malforme",…}`.

```bash
curl -s -X POST "https://obnlcnwlkuojmplksxtu.supabase.co/functions/v1/link" -H "Content-Type: application/json" -d '{"recovery_code":"ABCDEFGHJKLM"}'
```

Attendu : `401` — le code seul ne suffit jamais.

### La table est bien fermée

Avec la clé publiable — celle qui est dans le jeu :

```bash
curl -s "https://obnlcnwlkuojmplksxtu.supabase.co/rest/v1/players?select=*" -H "apikey: $(sed -n 's/^const PUBLISHABLE_KEY := "\(.*\)"/\1/p' supabase_config.gd)"
```

Attendu : `{"code":"42501",…,"message":"permission denied for table players"}`.

Mieux qu'un `[]` : la table n'est pas seulement vide pour cette clé, elle lui est
**inaccessible**. Les révocations de droits répondent avant même que la RLS n'ait
à trancher. Un `[]` conviendrait aussi — il signifierait que la RLS filtre — mais
le refus de privilège est plus franc.

### Le chemin nominal, depuis le jeu

1. Lancer deux instances avec une identité Epic jetable, sans quoi elles
   partagent le PUID de la machine et donc le profil :

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --eos-ephemeral
```

2. Onglet **PROFIL** dans chacune : deux codes de récupération **différents**.
3. Copier le code de l'instance A, le coller dans le champ « REPRENDRE UN PROFIL
   SUR CETTE MACHINE » de l'instance B, puis **RATTACHER**. B doit annoncer le
   pseudo de A.

Chaque lancement en `--eos-ephemeral` crée un PUID neuf, donc un profil de plus :
c'est le prix du test à deux instances sur une seule machine, et c'est visible
dans le tableau de bord. Les lignes se suppriment à la main quand elles gênent.

Ce parcours a été validé le 2026-08-16 **hors interface**, en pilotant
directement l'autoload : deux identités éphémères ont bien obtenu deux profils
distincts, et une troisième a repris le profil de la première sur présentation
de son code. Reste à le refaire **à la souris**, dans l'onglet PROFIL — c'est la
seule partie que ces essais n'ont pas touchée.

---

## Retoucher plus tard

Après toute modification de `supabase/migrations/` :

```bash
supabase db push
```

Après toute modification d'une fonction ou de `_shared/` — **redéployer les
deux**, elles partagent le même code :

```bash
supabase functions deploy identify --no-verify-jwt && supabase functions deploy link --no-verify-jwt
```

Journaux d'une fonction, quand un refus reste incompréhensible :

```bash
supabase functions logs identify
```

---

## Tests hors ligne

Vérification du jeton Epic et code de récupération, sans réseau ni secret : les
tests fabriquent leur propre paire de clés et signent leurs jetons.

```bash
deno test --allow-net=jsr.io supabase/functions/_shared/
```

100 tests au 2026-09-11 (34 à l'ouverture), dont le refus d'un jeton `alg: none`,
d'un jeton signé par une autre clé, d'une charge utile modifiée après
signature, d'un jeton expiré, d'un jeton destiné à un autre jeu — et, depuis
PE2.3, le tamis des conditions de match ; depuis PE5 (étape 28 du chantier DIX
CLASSES), celui de la télémétrie des gadgets.

---

## Vérifié en production le 2026-08-16

| Contrôle | Résultat |
|---|---|
| Migrations appliquées (`db push`) | ✅ les deux |
| Table inaccessible à la clé publiable | ✅ `42501 permission denied`, en lecture comme en écriture |
| PUID posté sans jeton | ✅ `401 jeton_absent` |
| Jeton inventé / `alg: none` | ✅ `401 jeton_malforme` / `401 algorithme_refuse` |
| Vrai jeton Epic → profil créé | ✅ code rendu et lisible |
| Deux identités distinctes → deux profils | ✅ |
| Code valide → rattachement | ✅ le profil suit la nouvelle machine |
| Code inconnu → refus | ✅ `404 code_inconnu` (après correctif, voir plus bas) |

Les profils créés par ces essais ont été supprimés : la table est repartie vide.

**Un défaut trouvé et corrigé au passage.** La première version des fonctions SQL
rendait `public.players` et signalait « code inconnu » par un `NULL`. Vu du
client, ce `NULL` n'existe pas : PostgREST sérialise un composite NULL en **objet
de champs nuls** — `{"id":null,…}` — et non en `null`. L'Edge Function y voyait un
profil valide et répondait `200`. Un code inventé était donc accepté. Les
fonctions rendent désormais un `setof` : zéro ligne devient `[]`, sans ambiguïté
possible. Migration `20260816183000_functions_return_setof.sql`.

## PE2.3 — les conditions de match remontent avec le rapport (2026-09-10)

**Décision d'Adrien, 2026-09-10.** Chaque rapport de match **en ligne**, amical
ou classé, emporte désormais les conditions du match telles que le jeu les
archive déjà en local (schéma 5 de `match_record.gd`, voir
`conditions_de_match.gd`) : cadence par image (médiane, 1 % bas, pire image),
lien (RTT moyen et max), et machine (système, processeur, carte graphique,
pilote, fenêtre, mémoire vidéo). Le but : lire dans la base, sans rien
demander à personne, sur quelles machines le jeu tourne et où il rame. L'écran
scindé et l'entraînement ne rapportent rien et n'envoient donc rien.

Trois pièces, livrées ensemble :

| Pièce | Où | Ce qu'elle fait |
|---|---|---|
| Migration `20260910120000_match_conditions.sql` | `supabase/migrations/` | colonne `conditions jsonb` sur `match_reports`, `report_match` reçoit `p_conditions` en dernier avec un défaut, vue `conditions_de_match` |
| Tamis `parseConditions` | `functions/_shared/match_report.ts` | liste blanche clé par clé ; jamais un motif de refus du rapport |
| Le jeu | `game_state.gd`, `ranked_identity.gd` | le corps du rapport porte `conditions`, le rejeu du journal aussi |

### Déployer — jalon H14, deux commandes

```bash
supabase db push
supabase functions deploy report --no-verify-jwt
```

Dans cet ordre, et l'une juste après l'autre : entre les deux, l'ancienne
fonction appelle `report_match` sans `p_conditions`, et le défaut `null` lui
évite d'échouer — un rapport sans conditions, jamais un rapport perdu. Seule
`report` importe le module modifié (`ranking.ts` l'importe aussi, mais aucune
autre fonction n'importe `ranking.ts`) : rien d'autre à redéployer.

### Lire

Dans l'éditeur SQL du tableau de bord :

```sql
-- Les derniers matchs, machine et cadence
select reported_at, kind, os, gpu, fenetre, fps_median, fps_1pc_bas, pire_image_ms, rtt_moyen_ms
from public.conditions_de_match order by reported_at desc limit 50;

-- Le 1 % bas médian par carte graphique — la question du chantier PE3
select gpu, count(*) as matchs, percentile_cont(0.5) within group (order by fps_1pc_bas) as bas_1pc_median
from public.conditions_de_match group by gpu order by matchs desc;
```

Un `vram_mo` à **0** est un pilote qui ne compte pas la mémoire vidéo, pas une
absence de textures ; un `vram_mo` **NULL** est un client qui n'a pas envoyé la
clé.

### Vérifier après déploiement

- `select column_name from information_schema.columns where table_name = 'match_reports' and column_name = 'conditions';` rend une ligne ;
- un match en ligne joué avec un client à jour fait apparaître une ligne dans
  `conditions_de_match` ; un client d'avant PE2.3 continue de rapporter, avec
  `conditions` à NULL ;
- `deno test --allow-net=jsr.io supabase/functions/_shared/` reste vert (102 depuis le
  lot H, le 2026-09-12 ; 100 à PE5, 95 à PE2.3).

### La phrase aux testeurs

À mettre dans le message qui accompagne le lien, puisque c'est là qu'Adrien a
choisi de le dire :

> Quand tu joues en ligne, le jeu envoie avec le résultat du match un relevé de
> cadence, la description de ta machine (système, processeur, carte graphique,
> pilote, résolution) et ce que les gadgets ont fait pendant le match (poses,
> allumages, dégâts de braises), rattachés à ton identité Epic. Ça sert à savoir
> où le jeu rame et sur quoi, et si les gadgets servent à quelque chose. Rien
> d'autre n'est envoyé, et rien hors ligne.

**Amendée le 2026-09-11** (étape 28 du chantier DIX CLASSES, lot E ; relevé par la
revue du lot). La version de PE2.3 s'arrêtait à la machine et finissait par « Rien
d'autre n'est envoyé » — c'était vrai le 2026-09-10, et faux dès que le rapport a
emporté la télémétrie des gadgets, dans ces mêmes `conditions`. Cette phrase décrit
ce qui part de la machine du testeur : elle doit suivre ce qui part, sinon elle ne
vaut rien.

⚠️ **Le même texte vit DANS le jeu** — `ui.gd`, `AVIS_PHASE_DE_TEST`, affiché au menu,
« mot pour mot comme Adrien l'a écrit le 2026-09-10 ». **Complété le 2026-09-12**
(étape 28, lot H ; Adrien : « compléter l'avis, texte proposé ») : il énumérait encore
l'ancienne liste tout en promettant « Rien d'autre n'est envoyé », et c'est la version
que liront les joueurs de la 0.6. Une seule incise s'y est insérée — *« ainsi qu'un
décompte de l'usage de tes gadgets »* —, **pas un caractère de son texte n'a bougé**, et
`tools/test_menus_finitions.gd` relie désormais cet avis à l'ENVOI lui-même : il rougit
si le rapport emporte les gadgets sans que l'avis le dise, et dans l'autre sens aussi.

⚠️ **Ce que ni l'une ni l'autre des deux phrases ne dit**, recensé clé par clé et non
déduit (le premier recensement du lot H se croyait complet et manquait le premier
point — corrigé en revue le 2026-09-12) :

- **la mesure du LIEN** : `rtt_moyen_ms` et `rtt_max_ms`, la latence moyenne et le pic
  de la connexion du testeur pendant la manche (`ConditionsDeMatch.resume()`, acceptés
  par le tamis, et déjà interrogés par la requête de diagnostic plus haut). Ni
  « relevé de cadence » ni « description de ta machine » ne nomme une mesure de réseau,
  et le dépôt sépare bien les trois. **« Rien d'autre n'est envoyé » reste donc inexact
  sur ce point**, dans les deux phrases. Rien n'a été réécrit d'initiative : c'est le
  texte d'Adrien, et c'est à lui de trancher — compléter l'incise (« …et de ta
  connexion »), ou cesser d'envoyer le RTT. **À trancher avant le tag de la 0.6.0** ;
- **les deux côtés du bloc de gadgets** : le gadget de l'adversaire et ses compteurs,
  pas seulement ceux du rapporteur, même si le serveur ne lit que son côté ;
- **`weapon_self`, `weapon_opponent`, `map`, `duration` et le format**, que les deux
  phrases rangent implicitement dans « le résultat du match ».

## PE5 — la télémétrie des gadgets (2026-09-11)

**Chantier DIX CLASSES, étape 28, lot E** (suggestion 8, retenue par Adrien). H11
est ouvert : les dix gadgets n'avaient jamais servi en match, et rien ne disait si
l'un d'eux sert, tue, ou jamais. L'archive du jeu passe au **schéma 6** : un bloc
`gadgets` compte, par joueur, les poses, les morts de gadget (par balle ou en fin
de vie), les allumages (par passage ou par balle, deux colonnes depuis le lot H), les
bascules du grésillement, les PV infligés par les braises, et les morts survenues
dans les **5 s** qui suivent un effet de gadget (`telemetrie_gadgets.gd`).

**Amendé le 2026-09-12 — le bloc passe en version 2** (étape 28, lot H ; décision
d'Adrien : « le comptage des mines devient exact avant la publication »).
`rpc_allumer_gadget` porte désormais sa CAUSE, donc `allumages` se scinde en
`allumages_passage` et `allumages_balle`, et les clés de `GADGET_NUMBERS` suivent — la
suite du jeu compare les deux listes dans les deux sens. Le moment n'est pas
arbitraire : le protocole 17 n'est pas publié, et après le tag de la 0.6.0 la même
correction imposerait un protocole 18, donc une coupure entre joueurs.

**Aucune migration.** Le bloc voyage DANS `conditions`, le jsonb de PE2.3
(`MatchRecord.conditions_a_envoyer`, seule fusion, appelée par l'envoi comme par le
rejeu du journal), et le tamis `parseGadgets` de `functions/_shared/match_report.ts`
le passe à la liste blanche — jamais un motif de refus. Borné à moins de 1 Ko, pour
un plafond de 8 Ko au-delà duquel les conditions retombent à NULL sans refus.

**Déployer** : rien de plus que H14 — `supabase functions deploy report
--no-verify-jwt` emporte le nouveau tamis. Sans ce redéploiement, l'ancien tamis
jette `gadgets` sans bruit : les conditions arrivent, la télémétrie non, et aucun
rapport n'est refusé.

### Lire

Chaque match en ligne est rapporté par ses DEUX pairs, et chacun porte les deux
côtés du bloc. Pour ne compter chaque gadget qu'une fois, on ne lit que le côté du
**rapporteur** (`joueur_local` : 0 pour l'hôte, J1 ; 1 pour le client, J2) :

```sql
-- Par gadget : ce qu'il fait, match après match.
select g.value->>'gadget' as gadget,
       count(*) as matchs,
       sum((g.value->>'poses')::int) as poses,
       sum((g.value->>'allumages_passage')::int) as allumages_passage,
       sum((g.value->>'allumages_balle')::int) as allumages_balle,
       sum((g.value->>'morts_balle')::int) as abattus,
       sum((g.value->>'morts_fin_de_vie')::int) as fins_de_vie,
       sum((g.value->>'morts_adverses_apres_effet')::int) as adversaires_morts_dans_la_fenetre,
       sum((g.value->>'morts_propres_apres_effet')::int) as poseur_mort_dans_la_fenetre,
       round(sum((g.value->>'pv_braises_adversaire')::numeric), 1) as pv_braises_adversaire,
       round(sum((g.value->>'pv_braises_soi')::numeric), 1) as pv_braises_soi
from public.match_reports r,
     jsonb_each(r.conditions->'gadgets') g
where r.conditions ? 'gadgets'
  -- Lot H (2026-09-12) : la version du bloc est passée à 2, `allumages` s'y étant
  -- scindé en deux colonnes. Un bloc en version 1 peut encore arriver — rejoué
  -- depuis le journal local d'un poste de test —, et l'agréger avec les autres
  -- mélangerait deux formes. C'est exactement ce pour quoi `version` voyage.
  -- ⚠️ Ce 2 est le même que `TelemetrieGadgets.VERSION` (`telemetrie_gadgets.gd`), et
  -- `tools/test_telemetrie_gadgets.gd` lit ce littéral-ci pour les tenir ensemble :
  -- sans lui, un numéro qui bougeait d'un seul côté faisait rendre ZÉRO ligne à cette
  -- requête, pour tous les matchs, sans un mot (contrôle ajouté en revue le
  -- 2026-09-12, défaut reproduit). Changer ce nombre ici sans le changer là-bas
  -- rougit désormais la suite.
  and (r.conditions->'gadgets'->>'version')::int = 2
  and g.key = case r.conditions->'gadgets'->>'joueur_local' when '0' then 'j1' else 'j2' end
group by 1 order by matchs desc;
```

Et la preuve, sur le terrain, que les deux archives d'un match disent la même
chose — `joueur_local` mis à part, qui diffère par construction :

```sql
-- Cohérence : 1 attendu partout. Une ligne rendue ici est un match dont les deux
-- rapports divergent.
select match_id, count(distinct (conditions->'gadgets') - 'joueur_local') as versions
from public.match_reports
where conditions ? 'gadgets'
group by match_id
having count(*) = 2 and count(distinct (conditions->'gadgets') - 'joueur_local') > 1;
```

Seuls les deux compteurs de fenêtre (`morts_*_apres_effet`) peuvent y apparaître,
et c'est écrit : chaque pair date les événements à leur arrivée, et une mort qui
tombe pile à 5 s d'un effet peut se ranger d'un côté de la fenêtre chez l'hôte et
de l'autre chez le client, à la gigue du lien près. Toute autre clé divergente est
un défaut.

**Lire les chiffres :**
- pour la mine, `allumages_passage` et `allumages_balle` sont **deux comptes exacts**
  depuis le lot H (2026-09-12) : l'ordre d'allumage porte sa cause, décidée chez
  l'hôte et rejouée telle quelle chez le client. ⚠️ **Ce qu'ils remplacent, et
  pourquoi** : la colonne unique `allumages` obligeait à retrancher `morts_balle` pour
  deviner les passages, et ce n'était qu'un **majorant** — une mine touchée demande
  l'allumage au lieu de mourir, elle meurt de son embrasement 1,6 s plus tard, et un
  match archivé avant ne lui compte aucune mort : elle passait pour un passage (revue
  du 2026-09-11). Les blocs en **version 1** portent encore l'ancienne colonne, que le
  tamis laisse tomber — d'où le filtre sur `version` dans la requête ci-dessus ;
- les colonnes de MORT ne comptent que les gadgets passés par `detruire()` AVANT
  l'archive. **Trois sorties n'y passent pas**, et la troisième est la plus fréquente
  (liste rétablie en revue le 2026-09-12 — la première rédaction n'avait gardé que la
  première, alors que les deux autres sont ordinaires) : un gadget **encore debout à
  la fin du match** ; un gadget **purgé au départ de manche** (`_do_start_round` vide
  le conteneur au `queue_free()`, donc dans un BO3 tout gadget vivant en fin de manche
  quitte ainsi le match, que la télémétrie compte pourtant sur le MATCH entier) ; et un
  gadget **REMPLACÉ** (un seul gadget debout par joueur, `queue_free()` sans
  `detruire()` — avec une recharge de 60 s dans un match de 5 min, c'est le cas
  ordinaire). Dans les trois cas c'est une **absence**, pas une attribution fausse :
  aucune colonne ne dit plus autre chose que ce qu'elle compte. Un décompte exhaustif
  des morts de gadget n'est donc pas ici ; ce que ces colonnes disent, c'est **comment**
  meurent celles qui meurent — n'écrivez pas de requête qui rapproche `poses` de
  `morts_*` comme d'un bilan ;
- un **effet** est une pose (sauf une bobine posée éteinte), un allumage, une
  bascule vers allumé, ou un PV de braises. Les gadgets passifs (voile, ombre,
  leurre, suie, poussière, torche, poudre) ne sont donc vus que par leur pose, et
  une bobine allumée depuis plus de 5 s n'ouvre plus de fenêtre : **angle mort
  assumé** ;
- `fenetre_s` et `version` voyagent dans le bloc : si la fenêtre ou la définition
  d'« effet » change, les échantillons ne se mélangent pas — filtrer dessus ;
- chaque côté porte le slug de son **gadget** (`nappe_braises`, `gresillement`…),
  jamais celui de la classe, et aucune clé du bloc ne contient « classe ».

## Ce qui n'est pas fait

- **Aucune limitation de débit** sur `link`. Un code fait 60 bits, ce qui met une
  attaque par essais hors de portée, mais rien n'empêche aujourd'hui d'essayer.
  À reprendre si le classement prend de la valeur.
- **Le code de récupération est stocké en clair.** Il le faut : le jeu le
  réaffiche à chaque lancement. Un condensat l'interdirait.
- **Aucun ELO, aucune table de matchs.** C'était le périmètre de l'étape.
