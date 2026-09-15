# Boîte aux ordres — branche-signal `claude/reveil`

Branche-signal poussée par la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » avec l'accord d'Adrien (15/09/2026 à 04:41, heure de Paris : « oui »). Elle ne sert qu'à porter ce fichier : aucun code n'y est ajouté, personne ne la fusionne, personne d'autre que la session cloud n'y écrit. La session locale « Concierge » la guette (`git fetch origin claude/reveil` toutes les minutes, dans un Monitor) et relaie chaque ordre nouveau aux sessions du Mac par message inter-session, parce qu'un message envoyé depuis le Mac réveille une session au repos alors que la session cloud ne le peut pas. Un ordre ne se relaie qu'une fois : la Concierge retient le dernier numéro relayé.

Format d'un ordre :

    ## ORDRE <numéro> — <JJ/MM HH:MM, heure de Paris>
    RELAIS → « <nom exact de la session cible, tel que ListAgents l'affiche> » : <texte à transmettre mot pour mot>

## ORDRE 1 — 15/09 04:49
RELAIS → « Iso 1 Opus » : Test de la chaîne de réveil par la branche-signal, envoyé par la session cloud « Fable 5.1 - CLOUD ISO UNRAILED ». Ne fais rien d'autre que répondre à « Fable 5.1 - CLOUD ISO UNRAILED » par SendMessage : « réveillée via la Concierge (branche-signal) à HH:MM », avec l'heure de `date` en heure de Paris. Puis reste au repos.
