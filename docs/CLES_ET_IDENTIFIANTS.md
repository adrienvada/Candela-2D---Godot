# Les clés dont Candela a besoin pour tourner

**Ce document est une CARTE, pas une source.** Chaque clé était déjà décrite
quelque part — dans le README, dans `PROTOCOLE_TEST_EOS.md`, dans `SUPABASE.md`,
dans `MISE_A_JOUR.md` — et c'est justement le problème : personne ne pouvait
répondre d'un coup d'œil à « de quoi ce jeu a-t-il besoin pour démarrer ». La
colonne de droite renvoie donc au document qui fait foi, et **le détail ne se
recopie pas ici** : une carte qui redit ce qu'elle indique se met à mentir dès
que la source bouge.

Dernière vérification contre le code : 2026-08-27.

---

## La carte

| Clé | Où elle vit | Nature | Sans elle | Le détail est dans |
|---|---|---|---|---|
| `PRODUCT_NAME`, `PRODUCT_VERSION`, `PRODUCT_ID`, `SANDBOX_ID`, `DEPLOYMENT_ID`, `CLIENT_ID` | `res://eos_credentials.gd` — **ignoré par git** | identifiants Epic, **publics** | EOS « non configuré » : le jeu démarre, seul ENet reste | [PROTOCOLE_TEST_EOS.md](PROTOCOLE_TEST_EOS.md) |
| `CLIENT_SECRET`, `ENCRYPTION_KEY` | même fichier | **SECRETS — jamais commités** | idem : la validation exige les huit constantes, pas six | [PROTOCOLE_TEST_EOS.md](PROTOCOLE_TEST_EOS.md) |
| Le **Device ID** Epic | nulle part sur cette machine — voir plus bas | ancre du PUID | rien de mesurable | ce document |
| `PROJECT_URL`, `PUBLISHABLE_KEY`, `PROJECT_REF`, `REGION` | `res://supabase_config.gd` — **ignoré par git** | la clé publiable est **embarquée exprès** dans le jeu, décision actée | « classement non configuré » : le duel marche, le classement se tait | [SUPABASE.md](SUPABASE.md) |
| `CLE_PUBLIQUE` (RSA) | [`update_manager.gd`](../update_manager.gd) — **versionnée** | publique par nature | « mises à jour non configurées », rien ne s'installe | [MISE_A_JOUR.md](MISE_A_JOUR.md) |
| `CANDELA_MAJ_CLE_PRIVEE` | secret de CI, **jamais sur une machine de dev** | secret | aucune publication possible | [MISE_A_JOUR.md](MISE_A_JOUR.md) |

**Le patron est le même partout, et c'est lui qu'il faut retenir plutôt que le
tableau : une clé absente DÉGRADE une fonction et nomme sa dégradation.** Aucune
n'empêche le jeu de démarrer. C'est ce qui permet de cloner le dépôt et de jouer
en écran partagé sans rien configurer.

## Ce qu'il faut pour jouer, par mode

| Mode | Ce qu'il exige |
|---|---|
| Écran partagé, entraînement | **rien** |
| 1v1 en réseau local (ENet) | **rien** — c'est ce que prouve `--no-eos`, dont tous les bancs à deux instances se servent |
| 1v1 en ligne (EOS) | `eos_credentials.gd`, et le Device ID (voir plus bas) |
| Classé, classement | + `supabase_config.gd` |
| Mise à jour en jeu | `CLE_PUBLIQUE`, déjà versionnée |

---

## Le trousseau macOS — ce qu'on a cru, et ce qui est mesuré

Le 2026-08-26, une boîte macOS revenait en boucle : *« Trousseau introuvable —
impossible de trouver un trousseau pour stocker "ad4842…9388" »*. Cette chaîne de
32 hexadécimaux **est le `PRODUCT_ID` EOS de Candela** : c'est donc le SDK Epic,
à l'intérieur de Godot, qui la réclame — par
[`create_device_id`](../network_manager.gd), le seul appel qui cherche à faire
persister une identité.

> ⚠️ **Première conclusion, fausse, et elle valait une leçon.** La boîte a
> d'abord été attribuée à VLC, sur la foi d'une corrélation d'horodatage :
> VLC démarré à 21:38:12, trousseau écrit à 21:38. Deux faits vrais, une
> conclusion fausse. **Une coïncidence à la minute près sur une machine qui fait
> vingt choses n'est pas une preuve** — l'identifiant, lui, en était une, et il
> était lisible depuis le début.

### Ce que la mesure dit

Deux lancements successifs du jeu avec Epic, identité **persistante** :

    NetworkManager: EOS prêt (puid 0002…21ef)     ← lancement 1
    NetworkManager: EOS prêt (puid 0002…21ef)     ← lancement 2

- **le PUID est stable** d'un lancement à l'autre ;
- **aucun fichier n'est écrit** sous `Application Support`, `Preferences` ou
  `Caches` pendant ces lancements ;
- **aucune entrée de trousseau** ne porte le `PRODUCT_ID`, ni en service ni en
  libellé — l'écriture que réclame la boîte n'a jamais abouti ;
- **aucun avertissement** `create_device_id` dans la trace ;
- et la boîte **n'est pas réapparue** pendant ces deux lancements : elle est
  intermittente, et on ne sait pas la déclencher à volonté.

### Ce qu'on en déduit, et ce qu'on ne déduit pas

L'ancre du PUID **n'est pas locale**. Le dépôt le disait déjà sans le formuler
ainsi : « deux instances locales partagent le même Device ID », d'où
`--eos-ephemeral` pour les tests à deux fenêtres. C'est cohérent avec ce qu'on
mesure — le Device ID est tenu **du côté d'Epic**, rattaché à la machine, et non
par un secret posé sur le disque. Le trousseau ne porte donc pas l'identité, et
son refus ne la menace pas.

**Ce qui n'est PAS établi** : ce que le SDK cherchait exactement à y ranger
(vraisemblablement un jeton d'authentification mis en cache), ni pourquoi la
boîte apparaît à certains lancements et pas à d'autres. Personne n'a lu le SDK.

**Ce que ça coûte, mesuré : rien.** Ce n'est donc pas un chantier ; c'est une
gêne d'affichage. Si elle revient : « Annuler », jamais « Rétablir les valeurs
par défaut » — ce bouton touche à la liste des trousseaux, qui, elle, est saine.

### Refaire la mesure

Deux lancements, puis comparer. **Surtout pas `--eos-ephemeral`** : il détruit et
recrée le Device ID à chaque appel, donc il produirait deux PUID différents et
prouverait exactement le contraire de ce qu'on cherche.

```bash
for n in 1 2; do
  godot --headless --path . res://tools/test_online_match.tscn -- --host \
    2>&1 | grep -m1 "EOS prêt"
done
```

Deux PUID identiques : l'identité tient. Deux PUID différents : l'ancre a été
perdue, et **là** ce serait un vrai chantier réseau — le commentaire de
`_login_persistent_async()` dit ce qui s'écroule avec elle.

---

## Poser ces clés sur une machine neuve

1. `cp eos_credentials.example.gd eos_credentials.gd`, puis remplir les huit
   constantes depuis le portail Epic. Sans ce fichier, le jeu démarre et se
   déclare « non configuré » — c'est voulu.
2. Idem pour `supabase_config.example.gd` → `supabase_config.gd`.
3. Rien à faire pour `CLE_PUBLIQUE` : elle est versionnée.
4. Rien à faire pour le trousseau : le Device ID se crée tout seul au premier
   lancement en ligne.

**Les deux fichiers réels sont ignorés par git, et ce n'est pas une convention
de politesse** : `CLIENT_SECRET` et `ENCRYPTION_KEY` ouvrent le produit Epic, et
le dépôt est public.
