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

34 tests, dont le refus d'un jeton `alg: none`, d'un jeton signé par une autre
clé, d'une charge utile modifiée après signature, d'un jeton expiré, et d'un
jeton destiné à un autre jeu.

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

## Ce qui n'est pas fait

- **Aucune limitation de débit** sur `link`. Un code fait 60 bits, ce qui met une
  attaque par essais hors de portée, mais rien n'empêche aujourd'hui d'essayer.
  À reprendre si le classement prend de la valeur.
- **Le code de récupération est stocké en clair.** Il le faut : le jeu le
  réaffiche à chaque lancement. Un condensat l'interdirait.
- **Aucun ELO, aucune table de matchs.** C'était le périmètre de l'étape.
