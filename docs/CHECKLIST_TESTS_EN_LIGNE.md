# Checklist — tests manuels du mode en ligne (2 instances)

Vérification des transitions d'état en ligne : pause, killcam, décompte,
connexion / déconnexion, rematch, changement de carte.

## Préparation

Deux instances sur la même machine (ou deux postes du même réseau local) :

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . &
/Applications/Godot.app/Contents/MacOS/Godot --path . &
```

- Instance **A** = hôte : menu → mode HÔTE → `LANCER LE MATCH`. L'écran d'attente
  affiche l'IP à communiquer.
- Instance **B** = client : menu → mode REJOINDRE → saisir l'IP (`127.0.0.1` en
  local) → `REJOINDRE LE SALON`.
- Suites automatiques à passer avant toute session manuelle :

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/test_netcode.tscn
```

### Simulation de 120 ms de latence (section 8)

macOS, sur l'interface loopback, à activer puis **désactiver impérativement** :

```bash
sudo dnctl pipe 1 config delay 60
```

```bash
echo "dummynet in proto tcp from any to any pipe 1
dummynet in proto udp from any to any pipe 1" | sudo pfctl -f - -E
```

```bash
sudo pfctl -d && sudo dnctl -q flush
```

(60 ms par sens = 120 ms d'aller-retour. Le HUD réseau doit afficher un RTT
proche de 120 ms une fois la partie lancée.)

---

## 1. Pause en ligne

| # | Action | Attendu |
|---|--------|---------|
| 1.1 | Manche en cours, **A** appuie sur ÉCHAP | Le menu s'ouvre **par-dessus** le jeu ; la partie continue : le chrono tourne, B se déplace normalement sur les deux écrans |
| 1.2 | Pendant la pause de A, B tire sur A | A prend des dégâts et peut mourir : il est vulnérable, c'est voulu |
| 1.3 | Pendant sa pause, A appuie sur ses touches de déplacement / tir | Le personnage de A **ne bouge pas et ne tire pas** ; seul le menu réagit |
| 1.4 | A appuie de nouveau sur ÉCHAP (ou `REPRENDRE`) | Le menu se ferme, A reprend la main immédiatement, sans à-coup de position |
| 1.5 | Même série depuis **B** (client) | Idem : monde qui continue, personnage figé, reprise propre. B ne doit pas se téléporter à la reprise |
| 1.6 | Pendant la pause de B, observer B sur l'écran de A | B reste immobile (l'hôte reçoit des commandes neutres, il ne court pas sur la dernière touche) |
| 1.7 | A ouvre la pause, puis B tue A | La killcam démarre et le menu de pause a disparu de l'écran de A (aucun panneau « PAUSE » par-dessus la killcam) |
| 1.8 | **Non-régression local** : partie ÉCRAN PARTAGÉ, ÉCHAP | Le jeu se **fige** réellement (chrono arrêté, aucun mouvement), reprise à l'identique |

## 2. RPC pendant la killcam

| # | Action | Attendu |
|---|--------|---------|
| 2.1 | Un joueur meurt ; pendant la killcam de A, B (qui a fini la sienne plus tôt ou la saute) appuie sur `REJOUER` | Aucun effet visible sur l'écran de A tant que le ralenti dure : ni changement d'arme de P2, ni bascule du libellé du chrono |
| 2.2 | Fin de la killcam de A | L'écran de fin s'affiche, **et seulement là** l'arme choisie par B apparaît sélectionnée et le libellé passe à « EN ATTENTE D'UN ADVERSAIRE… » |
| 2.3 | Pendant la killcam de A, B fait prêt / pas prêt / prêt plusieurs fois | À l'arrivée sur l'écran de fin, l'état affiché correspond au **dernier** choix de B ; aucune manche ne démarre toute seule |
| 2.4 | Pendant la killcam, laisser passer un recalage de chrono (5 s) | Aucun affichage aberrant ; au lancement de la manche suivante le chrono repart à 05:00 des deux côtés |
| 2.5 | B saute sa killcam (touche de saut), A laisse la sienne finir | Chacun retrouve la vitesse normale de son côté ; les deux arrivent sur l'écran de fin avec le même score |

## 3. Déconnexion pendant le décompte

| # | Action | Attendu |
|---|--------|---------|
| 3.1 | Lancer une manche, **fermer B (⌘Q / ALT+F4) pendant le 3-2-1** | A : dialogue « Le Joueur 2 s'est déconnecté », le décompte **disparaît**, écran d'attente avec l'IP, score remis à 0-0 |
| 3.2 | Juste après 3.1, A essaie de bouger | A se déplace librement (bac à sable) : il n'est **pas** figé par un décompte resté en cours |
| 3.3 | Juste après 3.1, A tire | Le tir part normalement |
| 3.4 | Relancer B et se reconnecter | Une manche démarre proprement, décompte 3-2-1 complet, score 0-0 |
| 3.5 | **Fermer A pendant le 3-2-1** | B : dialogue « L'hôte a fermé la partie. Retour au menu principal. », retour au menu, aucun décompte résiduel à l'écran |
| 3.6 | Après 3.5, B relance une partie en local | Tout fonctionne : ni gel, ni ralenti, ni chrono figé |

## 4. Connexion pendant une killcam ou une fin de manche

> ⚠️ **L'attendu de 4.1 est contredit par le code, et personne n'a tranché.**
> Relevé le 2026-08-18 en cherchant comment automatiser cette famille.
>
> La ligne 4.1 attend que A **termine sa killcam en entier**. Or
> `game_state.gd:381` — dans `_on_peer_disconnected` — appelle `_abort_killcam()`
> dès que le pair disparaît : la killcam de A est **coupée**, la vitesse rendue,
> et le dialogue de déconnexion s'affiche.
>
> **Les deux comportements se défendent** et c'est bien le problème. Terminer la
> killcam respecte le joueur qui regarde ; la couper reconnaît que le match est
> fini de toute façon et rend la main plus vite. **Écrire un test contre l'un ou
> l'autre reviendrait à trancher une question de jeu à la place d'Adrien** —
> exactement ce que le 2026-08-18 a passé sa journée à démonter ailleurs.
>
> **Tant que ce n'est pas tranché, la famille 4 n'est pas automatisée**, et son
> absence est un choix, pas un oubli. Les familles 1, 2 (moitié), 3, 5.2, 5.3, 6
> et 7.2 le sont — voir `tools/run_duo.sh`.


| # | Action | Attendu |
|---|--------|---------|
| 4.1 | Manche en cours à deux, B meurt ; pendant la killcam de A, tuer le processus de B, le relancer et rejoindre immédiatement | A termine **sa killcam en entier** (ni coupée, ni accélérée, ni recouverte par un écran d'attente), puis la manche démarre pour les deux |
| 4.2 | Variante : B rejoint alors que A est déjà sur l'écran de fin | La manche démarre tout de suite, décompte 3-2-1 des deux côtés |
| 4.3 | Après 4.1, vérifier le score | Aucun double comptage ; le score repart de 0-0 (la déconnexion remet le match à zéro) |
| 4.4 | Après 4.1, vérifier l'état de A pendant l'attente de reconnexion | Aucun panneau résiduel, vitesse normale, A peut se déplacer et tirer |

## 5. `Engine.time_scale` sur tous les chemins de sortie

Chaque cas se vérifie de la même façon : après l'action, le jeu **et les menus**
doivent réagir à vitesse normale (déplacer le curseur, naviguer dans les
onglets, regarder le chrono).

| # | Action | Attendu |
|---|--------|---------|
| 5.1 | Sauter la killcam avec la touche dédiée | Vitesse normale immédiate |
| 5.2 | Laisser la killcam se terminer d'elle-même | Vitesse normale sur l'écran de fin |
| 5.3 | Déconnecter l'adversaire **pendant le ralenti** | Vitesse normale sur l'écran d'attente |
| 5.4 | `MENU PRINCIPAL` pendant le ralenti (ouvrir la pause pendant la killcam n'est pas possible : passer par l'écran de fin, ou couper la connexion) | Menu principal fluide, animations d'onglets à vitesse normale |
| 5.5 | Depuis le menu principal atteint en 5.4, relancer une partie locale | Le jeu tourne à vitesse normale du début à la fin |
| 5.6 | `QUITTER` pendant un ralenti | L'application se ferme sans traîner |

## 6. Spam prêt / pas prêt pendant les transitions

| # | Action | Attendu |
|---|--------|---------|
| 6.1 | Sur l'écran de fin, A et B martèlent `REJOUER` en alternance pendant 10 s | Une seule manche démarre, exactement quand les deux sont prêts en même temps |
| 6.2 | Répéter 6.1 en partant de la killcam (B spamme pendant que A est encore au ralenti) | Aucun double démarrage, aucun décompte joué deux fois |
| 6.3 | Après plusieurs rematches spammés, comparer les scores affichés sur A et B | Scores identiques et cohérents avec le nombre réel de manches |
| 6.4 | A se met prêt, B se met prêt puis **pas prêt** dans la seconde | La manche ne part pas ; le libellé de A repasse en attente |

## 7. Changement de carte entre deux manches

| # | Action | Attendu |
|---|--------|---------|
| 7.1 | Sur l'écran de fin, A ouvre l'onglet `CARTES` et choisit une autre carte, puis les deux se mettent prêts | La manche suivante se joue sur la **nouvelle** carte des deux côtés, apparitions comprises |
| 7.2 | Sur l'écran de fin, regarder l'écran de B | L'onglet `CARTES` n'est **pas** proposé au client : la carte appartient à l'hôte |
| 7.3 | A choisit une carte **personnalisée** (créée dans l'éditeur, absente du disque de B) | B joue la même géométrie ; aucun message d'erreur de carte |
| 7.4 | A choisit une carte, puis en change d'avis avant que les deux soient prêts | C'est la dernière carte sélectionnée au moment du démarrage qui est jouée |

## 8. Match complet avec 120 ms simulée

Activer la latence (voir Préparation), puis dérouler un match entier.

| # | Point de contrôle | Attendu |
|---|--------------------|---------|
| 8.1 | Connexion et lancement | Le salon se rejoint sans timeout, décompte 3-2-1 synchrone à l'œil |
| 8.2 | Déplacement de son propre personnage | Réponse immédiate aux touches, aucun caoutchouc perceptible |
| 8.3 | Déplacement de l'adversaire | Mouvement fluide (interpolé), sans saccade ni téléportation |
| 8.4 | Tirer | La balle part **immédiatement** côté tireur ; elle n'apparaît jamais en double |
| 8.5 | Tirer sur un adversaire en mouvement, à mi-portée | Les touches attendues comptent : viser ce qu'on voit suffit (compensation de latence) |
| 8.6 | Chronomètre | Écart entre les deux écrans ≤ 1 s tout au long de la manche ; recalage invisible |
| 8.7 | Mort d'un joueur | Les deux écrans passent en killcam ; chacun rejoue **sa** version, ce qui est attendu |
| 8.8 | Enchaîner 3 manches (rematch) | Score identique des deux côtés, aucune manche fantôme, aucun ralenti résiduel |
| 8.9 | Terminer une manche **au chrono** (personne ne meurt) | Égalité annoncée des deux côtés, pas de killcam, écran de fin direct |
| 8.10 | Quitter par `MENU PRINCIPAL` depuis l'écran de fin, des deux côtés | Retour au menu propre, possibilité de relancer un salon dans la foulée |
| 8.11 | **Désactiver la latence** (`sudo pfctl -d && sudo dnctl -q flush`) | Le RTT affiché retombe à quelques millisecondes |
