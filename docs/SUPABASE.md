# Supabase — déploiement du classement

> Phase 4, étape 1 : **l'identité, et rien d'autre**. Aucun ELO n'est calculé.
> Ce document dit ce qu'il y a à déployer et comment. Le pourquoi est dans
> [ROADMAP.md](ROADMAP.md).

Tout le code est écrit et versionné. Il reste à le **pousser vers le projet
Supabase**, ce qui exige une authentification : c'est le seul geste qu'un agent
ne peut pas faire à la place d'Adrien.

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
│   └── 20260816160000_players_identity.sql
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

### 1. Installer la CLI

```bash
brew install supabase/tap/supabase
```

### 2. S'authentifier

Ouvre un navigateur.

```bash
supabase login
```

### 3. Rattacher le dépôt au projet

Demande le mot de passe de la base (celui choisi à la création du projet).

```bash
supabase link --project-ref obnlcnwlkuojmplksxtu
```

### 4. Pousser le schéma

Crée la table, ferme la Row Level Security, installe les deux fonctions SQL.

```bash
supabase db push
```

### 5. Donner à Epic ses identifiants

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

### 6. Déployer les deux fonctions

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

Attendu : `[]` — jamais une ligne. C'est la RLS qui répond, pas la chance : la
table est vide pour tout le monde sauf la clé secrète.

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

## Ce qui n'est pas fait

- **Aucune limitation de débit** sur `link`. Un code fait 60 bits, ce qui met une
  attaque par essais hors de portée, mais rien n'empêche aujourd'hui d'essayer.
  À reprendre si le classement prend de la valeur.
- **Le code de récupération est stocké en clair.** Il le faut : le jeu le
  réaffiche à chaque lancement. Un condensat l'interdirait.
- **Aucun ELO, aucune table de matchs.** C'était le périmètre de l'étape.
