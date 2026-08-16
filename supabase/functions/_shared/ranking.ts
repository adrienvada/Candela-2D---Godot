// Le pont entre l'historique des matchs et la table des classements.
//
// Le rejeu est intégral : on relit TOUS les matchs concordants et on réécrit
// tous les classements. C'est plus coûteux qu'une mise à jour incrémentale, et
// c'est délibéré — il n'existe alors aucun chemin par lequel la table pourrait
// diverger de l'historique, donc aucune classe de bugs à traquer.
//
// À l'échelle de ce jeu, quelques milliers de matchs se rejouent en une fraction
// de seconde. Le jour où ce ne sera plus vrai, la mise à jour incrémentale
// deviendra une optimisation — avec ce rejeu comme référence pour la vérifier.

import { replay, type SettledMatch } from "./elo.ts";
import { select, callRaw } from "./db.ts";

/** Ligne de la vue `matches`, telle que PostgREST la rend. */
interface MatchRow {
  player_a: string;
  player_b: string;
  winner: string | null;
  concordant: boolean;
  forfeit: boolean;
}

/**
 * Recalcule et réécrit tous les classements. Rend le nombre de joueurs classés.
 *
 * Ne retient que les matchs **concordants** : deux récits qui se contredisent ne
 * disent pas qui a gagné, et inventer une réponse serait pire que de ne pas
 * compter le match. Les litiges restent en base, visibles, en attente d'une
 * règle qu'on écrira le jour où ils existeront vraiment.
 *
 * L'ordre est celui du règlement — le moment où le second rapport est arrivé.
 * Elo n'étant pas commutatif, ce tri est une décision, pas un détail.
 */
export async function recomputeRatings(): Promise<number> {
  const rows = await select<MatchRow>(
    "matches",
    "player_a,player_b,winner,concordant,forfeit",
    "concordant=is.true&order=settled_at.asc",
  );

  const history: SettledMatch[] = rows.map((r) => ({
    playerA: r.player_a,
    playerB: r.player_b,
    winner: r.winner,
    forfeit: r.forfeit,
  }));

  const standings = [...replay(history)].map(([player_id, s]) => ({
    player_id,
    rating: s.rating,
    matches: s.matches,
    wins: s.wins,
    losses: s.losses,
    draws: s.draws,
  }));

  const applied = await callRaw("apply_ratings", { p_rows: standings });
  return typeof applied === "number" ? applied : standings.length;
}
