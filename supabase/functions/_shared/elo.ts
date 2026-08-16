// Le calcul du classement.
//
// Logique pure : ni base, ni réseau, ni horloge. C'est ce qui la rend testable
// hors ligne, et c'est délibéré — le classement est la partie du système où une
// erreur est la plus difficile à voir après coup.
//
// **Le classement n'est jamais une valeur écrite une fois pour toutes.** Il se
// RECALCULE depuis l'historique des matchs, qui seul fait foi. Conséquence
// directe et voulue : un mauvais facteur K, un mauvais classement de départ, une
// mauvaise pondération du forfait cessent d'être fatals — on change la constante
// et on rejoue. Sans cette propriété, la première erreur de réglage serait
// définitive.

/**
 * Classement de départ. Rond et lisible ; sa valeur exacte n'a aucune
 * importance, seuls les écarts en ont.
 */
export const START_RATING = 1000;

/**
 * Facteur K — de combien un match peut déplacer un classement.
 *
 * 32 est la valeur classique. Volontairement constante pour l'instant : pas de
 * phase provisoire à K élevé, pas de K dégressif. Ces raffinements sont
 * légitimes, mais chacun est une règle inventée de plus, et ils ne coûteront
 * qu'un changement de constante suivi d'un recalcul le jour où le besoin sera
 * démontré plutôt que supposé.
 */
export const K_FACTOR = 32;

/**
 * Poids d'un match gagné par forfait.
 *
 * 1 — un abandon compte plein tarif. C'est la conséquence directe de la décision
 * actée : ne pas rendre l'abandon gratuit. On pourrait objecter qu'un forfait ne
 * dit rien du niveau des deux joueurs ; c'est vrai, et c'est pourquoi ce poids
 * est nommé et isolé. Le baisser est un changement d'une ligne, suivi d'un
 * recalcul.
 */
export const FORFEIT_WEIGHT = 1;

/** Un match réglé, tel que la vue `matches` le rend. */
export interface SettledMatch {
  playerA: string;
  playerB: string;
  /** Gagnant, ou `null` en cas d'égalité. */
  winner: string | null;
  forfeit: boolean;
}

export interface Standing {
  rating: number;
  matches: number;
  wins: number;
  losses: number;
  draws: number;
}

/**
 * Probabilité que `ratingA` l'emporte sur `ratingB`.
 *
 * La formule d'Elo : 400 points d'écart valent dix contre un.
 */
export function expectedScore(ratingA: number, ratingB: number): number {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

/**
 * Nouveau classement après un match.
 *
 * `score` vaut 1 pour une victoire, 0.5 pour une égalité, 0 pour une défaite.
 * `weight` module l'ampleur du déplacement sans toucher à sa direction.
 */
export function nextRating(
  rating: number,
  opponentRating: number,
  score: number,
  weight = 1,
): number {
  return rating + K_FACTOR * weight * (score - expectedScore(rating, opponentRating));
}

function blank(): Standing {
  return { rating: START_RATING, matches: 0, wins: 0, losses: 0, draws: 0 };
}

/**
 * Rejoue tout l'historique et rend le classement de chaque joueur.
 *
 * L'ordre des matchs compte — Elo n'est pas commutatif. C'est à l'appelant de
 * fournir la liste dans l'ordre où les matchs ont été réglés ; cette fonction ne
 * trie rien, pour que le critère de tri reste une décision visible et non un
 * détail enfoui ici.
 *
 * Les classements sont arrondis à l'entier **à la toute fin** seulement : arrondir
 * à chaque match ferait dériver le total au fil des parties.
 */
export function replay(matches: readonly SettledMatch[]): Map<string, Standing> {
  const exact = new Map<string, number>();
  const tally = new Map<string, Standing>();

  const rating = (id: string): number => {
    const known = exact.get(id);
    if (known !== undefined) {
      return known;
    }
    exact.set(id, START_RATING);
    tally.set(id, blank());
    return START_RATING;
  };

  for (const m of matches) {
    // Un match d'un joueur contre lui-même ne veut rien dire et fausserait tout.
    if (m.playerA === m.playerB) {
      continue;
    }
    const before = { a: rating(m.playerA), b: rating(m.playerB) };
    const weight = m.forfeit ? FORFEIT_WEIGHT : 1;

    let scoreA = 0.5;
    if (m.winner === m.playerA) {
      scoreA = 1;
    } else if (m.winner === m.playerB) {
      scoreA = 0;
    }

    // Les deux nouveaux classements se calculent depuis les ANCIENS : mettre à
    // jour A avant de calculer B donnerait un résultat qui dépend de l'ordre
    // des deux joueurs dans la ligne.
    exact.set(m.playerA, nextRating(before.a, before.b, scoreA, weight));
    exact.set(m.playerB, nextRating(before.b, before.a, 1 - scoreA, weight));

    const ta = tally.get(m.playerA)!;
    const tb = tally.get(m.playerB)!;
    ta.matches++;
    tb.matches++;
    if (scoreA === 1) {
      ta.wins++;
      tb.losses++;
    } else if (scoreA === 0) {
      ta.losses++;
      tb.wins++;
    } else {
      ta.draws++;
      tb.draws++;
    }
  }

  for (const [id, standing] of tally) {
    standing.rating = Math.round(exact.get(id)!);
  }
  return tally;
}
