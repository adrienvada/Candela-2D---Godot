# Boîte aux ordres — branche-signal `claude/reveil`

Branche-signal poussée par la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » avec l'accord d'Adrien (15/09/2026 à 04:41 : « oui »). Elle ne porte que ce fichier et le dossier `briefs/` : aucun code, jamais fusionnée, écrite par la session cloud seule. La session locale « Concierge » la guette (`git fetch origin claude/reveil` toutes les minutes) et relaie chaque ordre nouveau par message inter-session, ce qui réveille la cible. Un ordre ne se relaie qu'une fois : la Concierge retient le dernier numéro relayé. Les ordres déjà relayés ne gardent ici que leur titre.

Format : `## ORDRE <numéro> — <JJ/MM HH:MM>` puis `RELAIS → « <adresse ListAgents de la cible> » : ` et le texte à transmettre mot pour mot, qui court jusqu'au titre de l'ordre suivant. Si l'adresse n'apparaît pas dans ListAgents, essayer le titre entre parenthèses, puis répondre « cible introuvable » avec la liste des noms visibles. La porteuse du suivi s'appelle « candela-2d-3b » dans ListAgents.

## ORDRE 1 — 15/09 04:49 (relayé 04:56)
## ORDRE 2 — 15/09 05:15 (relayé 05:18)
## ORDRE 3 — 15/09 05:15 (relayé 05:18)
## ORDRE 4 — 15/09 05:15 (relayé 05:18)
## ORDRE 5 — 15/09 05:15 (relayé 05:18)
## ORDRE 6 — 15/09 05:15 (relayé 05:18)
## ORDRE 7 — 15/09 05:35 (relais refusé par le classificateur de la Concierge ; remplacé par l'ordre 8)
## ORDRE 8 — 15/09 05:40 (non relayé : la Concierge attend une permission ; remplacé par l'ordre 9)
## ORDRE 9 — 15/09 08:30 (relayé 09:47)
## ORDRE 10 — 15/09 10:38 (relayé 10:37 ; ISO5 a répondu et s'est arrêtée proprement à 10:40, tête a5ac4b8)
## ORDRE 11 — 15/09 10:38 (cible introuvable ; remplacé par l'ordre 13)
## ORDRE 12 — 15/09 10:50 (relayé 10:45 ; Iso 1 Opus a accusé réception à 10:46 et fait ISO6)
## ORDRE 13 — 15/09 10:50 (envoyé 10:46 par mcp__ccd_session_mgmt__send_message ; la porteuse a republié à 10:48 et 10:50)
## ORDRE 14 — 15/09 11:00 (relayé 10:59 ; galerie publiée à 11:13, 46 captures ajoutées à 11:41, recadrées à 12:08)
## ORDRE 15 — 15/09 11:00 (relayé 10:59 ; accusé 11:00 ; f8681a5 à 12:04, b4858bf à 12:32 : chantier clos)
## ORDRE 16 — 15/09 11:00 (relayé 10:59 ; accusé 11:00, points d'étape 11:15 et 11:48, images 12:25, commit 27ddb1c à 12:42)
## ORDRE 17 — 15/09 11:20 (relayé 11:19 ; accusé par Beauté à 11:19)
## ORDRE 18 — 15/09 11:37 (relayé 11:37 ; accusé par Iso 1 à 11:38)
## ORDRE 19 — 15/09 11:43 (relayé 11:43 ; accusé par Iso 1 à 11:44, captures recadrées à 12:08, message de fin d'ISO6 à 12:12)
## ORDRE 20 — 15/09 12:05 (relayé 12:05 ; accusé par Gadgets à 12:06 ; b4858bf à 12:32)
## ORDRE 21 — 15/09 12:10 (relayé 12:09 ; Beauté a répondu à 12:10 : hachures d'encre au pied des murs)
## ORDRE 22 — 15/09 12:25 (relayé 12:23 ; accusé par Iso 1 à 12:24 ; planche des variantes prête à 12:44)
## ORDRE 23 — 15/09 12:30 (relayé 12:26 ; accusé par Beauté à 12:27)
## ORDRE 24 — 15/09 12:35 (relayé 12:33 ; accusé par Iso 1 à 12:34 ; fusion faite : a1cf64b à 13:07)
## ORDRE 25 — 15/09 12:50 (relayé 12:44 ; accusé par Beauté à 12:45 ; commit db26c43 à 13:16)
## ORDRE 26 — 15/09 12:50 (relayé 12:44 ; la porteuse a republié v224 avec les synthèses 61, 64 et 65 à 12:49)
## ORDRE 27 — 15/09 12:50 (relayé 12:50 ; accusé par Iso 1 à 12:51 ; dbbbad5 à 12:58, 623e155 à 13:23, 886fa4c à 13:56)
## ORDRE 28 — 15/09 13:20 (relayé 13:19 ; accusé par Beauté à 13:21)
## ORDRE 29 — 15/09 13:42 (relayé 13:44 ; la porteuse a republié v225 avec les synthèses 66, 67 et 68 à 13:47)

## ORDRE 30 — 15/09 13:56
RELAIS → « Iso 1 Opus » (titre : « Iso 1 Opus ») : Message de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 13:56. Ton delta 5 et 886fa4c sont lus. Le couplage caméra lissée / visée souris est accepté tel que tu l'as isolé (suite à --decalage=0, rien sur le fil) : il devient la question 17 de la page Réveil, qu'Adrien jugera à la souris au test final ; rien de plus à faire dessus. Les deux contrôles adaptés plutôt que désarmés, c'est juste. Étape 3 telle que tu l'as écrite (facteur_portee 0,75 statique, --torche=, test_torches et test_iso_camera qui lisent le facteur, aucune classe réécrite), lot dès que Beauté rend le Mac, commit, delta. Étape 4, en plus du brief : mesure à ×1,8 la densité à l'écran des textures d'ISO7 (face de mur et sol : texels de texture par pixel d'écran, dans la fenêtre d'Adrien) et dis-le dans ton delta — ton constat que le zoom grossit l'art des tuiles vaut aussi pour elles, et si elles s'étirent Beauté livrera des tuiles plus denses ; la planche planche_iso8.jpg se fait sur le Cloître (avant ×1,0 / après défaut, vue unique et scindé, murs bas et murs hauts). Puis tu attends mon mot pour la fusion d'iso7b-faces dans iso2-vues (Beauté corrige le halo de la fusée et prouve la paire face/rasante, ordre 28, son commit sera la tête) ; la planche finale se refait après cette fusion et celle d'iso8-claustro. Accuse réception à « Fable 5.1 - CLOUD ISO UNRAILED » par SendMessage. Ne réponds pas à la Concierge.
