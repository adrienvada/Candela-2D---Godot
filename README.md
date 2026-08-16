# Candela 2D

Duel 1v1 en vue de dessus, dans le noir absolu. La seule information est la
lumière : sa propre torche, qui révèle mais trahit, le flash d'un tir, la
rétrodiffusion sur un mur. Être vu, c'est être mort.

Godot 4.7 · GDScript · écran partagé local et 1v1 en ligne hôte-autoritaire.

---

## 👉 Commencer ici

**[docs/ROADMAP.md](docs/ROADMAP.md) est le document de référence du projet.**
Il dit où en est le jeu, ce qui est décidé, ce qui est validé, et ce qui reste.

**État des branches** — `main` porte tout ce qui est terminé : Phases 1 à 4
incluses (identité classée, matchs en base, classement ELO). Le travail en cours
vit sur une branche dédiée jusqu'à sa clôture, puis y est fusionné — c'est ce qui
s'est fait pour `eos-transport` puis `supabase-elo`. `main` et `supabase-elo`
sont à jour sur GitHub depuis le 2026-08-16.

---

## Protocole de travail (humains et agents)

### Avant d'agir — toujours

1. **Lire [docs/ROADMAP.md](docs/ROADMAP.md) en entier.** Il contient l'état des
   phases, les décisions actées et une section « Pièges connus » qui recense des
   erreurs déjà payées une fois. Les redécouvrir coûte des heures.
2. Vérifier la branche courante et l'étape en cours. Le travail avance par
   **étapes numérotées** ; ne pas anticiper une étape suivante sans demande
   explicite.
3. Respecter le périmètre annoncé. Aucune refonte opportuniste : si un problème
   hors périmètre est repéré, le signaler plutôt que le corriger.

### Après avoir agi — obligatoire

Mettre à jour `docs/ROADMAP.md` **dans le même commit que le travail décrit**,
jamais dans un commit séparé « mise à jour de la doc ». Concrètement :

| Ce que tu as fait | Ce que tu mets à jour |
|---|---|
| Terminé une étape | La ligne d'état de la phase + le hash du commit |
| Pris une décision durable | Une ligne dans **Décisions actées**, avec sa raison |
| Perdu du temps sur un écueil | Une ligne dans **Pièges connus** |
| Identifié un besoin d'intervention humaine | Une ligne dans **Jalons humains** |
| Changé l'ordre des priorités | La section **Prochaines étapes** |
| Rien de tout cela | La date de dernière mise à jour uniquement |

Règles de rédaction : expliquer **pourquoi**, pas **quoi** — le code dit déjà le
quoi. Rester factuel : une chose non testée est écrite comme non testée.

### Sessions parallèles

Plusieurs sessions peuvent travailler en même temps sur ce dépôt, sans pouvoir
se parler. **Le canal est [docs/JOURNAL_SESSIONS.md](docs/JOURNAL_SESSIONS.md)**,
à lire avant d'écrire une seule ligne : il dit quels fichiers sont réservés à
quelle session.

- **Le partage se fait par fichier, pas par sujet.** Deux agents sur « des
  sujets différents » dans le même fichier produisent un conflit à chaque
  poussée ; sur des fichiers disjoints, aucun.
- **Ne jamais changer de branche** (`git checkout`) sans avoir vérifié qu'aucune
  autre session ne travaille sur l'arbre : cela modifie les fichiers sous ses
  pieds. Utiliser un worktree si un travail sur une autre branche est nécessaire.
- Dans `docs/ROADMAP.md`, n'écrire que dans ses propres sections, et **ne jamais
  reformater celle d'une autre session** — une correction de forme sur un
  paragraphe voisin transforme un diff d'une ligne en conflit de section entière.
- Récupérer `main` **avant** chaque poussée, et pousser souvent : plus une
  branche vit longtemps, plus sa fusion coûte cher.
- Ne jamais pousser sur GitHub sans demande explicite d'Adrien.

---

## Lancer et tester

```bash
# Le jeu
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

```bash
# Suites de tests headless — toutes doivent passer avant tout commit
for t in test_map_codec test_map_geometry test_arena_build test_editor_tools test_match_format test_pause_menu test_menu_hub test_audio_settings; do
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/$t.gd
done
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/test_netcode.tscn
```

```bash
# Classement : vérification du jeton Epic et code de récupération (Deno)
deno test --allow-net=jsr.io supabase/functions/_shared/
```

Ces suites tournent aussi en CI (GitHub Actions,
[.github/workflows/tests.yml](.github/workflows/tests.yml)) sur chaque poussée,
avec Godot 4.7.1 Linux headless — plus un test de fumée qui charge le jeu
complet en écran partagé. La CI ne remplace pas la boucle locale : elle rattrape
ce qui lui aurait échappé.

Bancs d'essai réseau (EOS/ENet) : voir
[docs/PROTOCOLE_TEST_EOS.md](docs/PROTOCOLE_TEST_EOS.md).
Tests manuels du mode en ligne : voir
[docs/CHECKLIST_TESTS_EN_LIGNE.md](docs/CHECKLIST_TESTS_EN_LIGNE.md).

En jeu, **F3** ouvre le panneau de diagnostic : images par seconde, ping,
transport, lien direct ou relayé, type de NAT, lumières et particules actives.

---

## Configuration Epic Online Services

Le mode en ligne passe par EOS. Recopier `eos_credentials.example.gd` en
`res://eos_credentials.gd` (ignoré par git) et y coller les identifiants du
portail Epic Developer.

**Sans ce fichier, le jeu démarre normalement** : EOS reste « non configuré » et
seul le transport ENet (LAN/debug) est disponible.

`CLIENT_SECRET` et `ENCRYPTION_KEY` sont des secrets : ne jamais les commiter ni
les transmettre par un canal public.

---

## Configuration Supabase

Le classement passe par Supabase. Recopier `supabase_config.example.gd` en
`res://supabase_config.gd` (ignoré par git) et y coller l'URL du projet et la
**clé publiable**.

**Sans ce fichier, le jeu démarre et se joue normalement** : le classement reste
« non configuré », et rien d'autre ne change.

La clé publiable est faite pour vivre dans le client — ce qui protège les
tables, c'est la Row Level Security, pas le secret de cette clé. La clé
**secrète**, elle, n'entre jamais dans le jeu : les Edge Functions la reçoivent
par variable d'environnement.

Déploiement du schéma et des fonctions : [docs/SUPABASE.md](docs/SUPABASE.md).

---

## Repères de code

| Fichier | Rôle |
|---|---|
| `game_state.gd` | Orchestration : manches, RPC, killcam, spawn des balles |
| `player.gd` | Joueur : simulation, prédiction, interpolation, lumières |
| `network_manager.gd` | Transport interchangeable EOS/ENet, identité, ping |
| `ui.gd` | HUD, menus, lobby, killcam, navigation à deux curseurs |
| `menu_hub.gd` · `menu_theme.gd` | Ossature de navigation du menu (pile d'écrans) et palette partagée |
| `asset_manifest.gd` | Les 76 ressources attendues : ce qui manque, et ce qui est là mais vide |
| `bullet.gd` | Balles : trajectoire, rebonds, compensation de latence |
| `match_record.gd` | Format de match et archivage des résultats |
| `ranked_identity.gd` | Profil classé : identification vérifiée auprès d'Epic, code de récupération |
| `recovery_code.gd` · `lobby_code.gd` | Codes lus à voix haute : nettoyage, validation, mise en forme |
| `supabase/` | Schéma SQL, Row Level Security et Edge Functions du classement |
| `map_data.gd` · `map_codec.gd` · `map_geometry.gd` | Cartes : stockage, partage, géométrie |
