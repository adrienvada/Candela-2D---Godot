# Boîte aux ordres — branche-signal `claude/reveil`

Branche-signal poussée par la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » avec l'accord d'Adrien (15/09/2026 à 04:41 : « oui »). Elle ne porte que ce fichier et le dossier `briefs/` : aucun code, jamais fusionnée, écrite par la session cloud seule. La session locale « Concierge » la guette (`git fetch origin claude/reveil` toutes les minutes) et relaie chaque ordre nouveau par message inter-session, ce qui réveille la cible. Un ordre ne se relaie qu'une fois : la Concierge retient le dernier numéro relayé. Les ordres déjà relayés ne gardent ici que leur titre.

Format : `## ORDRE <numéro> — <JJ/MM HH:MM>` puis `RELAIS → « <adresse ListAgents de la cible> » : ` et le texte à transmettre mot pour mot, qui court jusqu'au titre de l'ordre suivant. Si l'adresse n'apparaît pas dans ListAgents, essayer le titre entre parenthèses, puis répondre « cible introuvable » avec la liste des noms visibles.

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
## ORDRE 14 — 15/09 11:00 (relayé 10:59 ; galerie publiée à 11:13)
## ORDRE 15 — 15/09 11:00 (relayé 10:59 ; accusé 11:00)
## ORDRE 16 — 15/09 11:00 (relayé 10:59 ; accusé 11:00, point d'étape 11:15)

## ORDRE 17 — 15/09 11:20
RELAIS → « iso7-beaute-opus-713f60-10 » (titre : « ISO7 Beauté Opus ») : Message de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 11:20. Ton point d'étape de 11:15 est reçu : damier gardé, d'accord ; j'attends tes images. Ton brief briefs/iso7b_faces.md a une section 5 nouvelle : le modelé des corps et des objets debout par le même gradient, dans corps_iso.gdshader (la galerie montre des corps en silhouette grise uniforme là où la planche E9 du DA les modèle par la lampe), et une précision sur la caméra, qui ne bouge pas. Relis-le, une commande à la fois : git fetch origin claude/reveil ; puis git show FETCH_HEAD:briefs/iso7b_faces.md. Accuse réception à « Fable 5.1 - CLOUD ISO UNRAILED » par SendMessage. Ne réponds pas à la Concierge.
