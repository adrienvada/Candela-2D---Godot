// Le pont entre l'historique des matchs et la table des classements.
//
// Le rejeu est intégral : on relit TOUS les matchs classés et concordants et on
// réécrit tous les classements. C'est plus coûteux qu'une mise à jour
// incrémentale, et c'est délibéré — il n'existe alors aucun chemin par lequel la
// table pourrait diverger de l'historique, donc aucune classe de bugs à traquer.
//
// À l'échelle de ce jeu, quelques milliers de matchs se rejouent en une fraction
// de seconde. Le jour où ce ne sera plus vrai, la mise à jour incrémentale
// deviendra une optimisation — avec ce rejeu comme référence pour la vérifier.

import { replay, type SettledMatch } from "./elo.ts";
import { RANKED } from "./match_report.ts";
import { select, callRaw } from "./db.ts";

/** Ligne de la vue `matches`, telle que PostgREST la rend. */
export interface MatchRow {
  player_a: string;
  player_b: string;
  winner: string | null;
  concordant: boolean;
  forfeit: boolean;
  /**
   * Nature retenue : `ranked`, `friendly`, ou `null` quand les deux pairs ne
   * s'accordent pas dessus.
   *
   * Déclarée facultative à dessein. La colonne peut manquer pour de vrai — vue
   * d'une version antérieure, colonne renommée, faute de frappe dans la liste
   * des colonnes — et il faut alors que le code traite le cas au lieu de se fier
   * au type. Ce qu'il en fait est le sens sûr : pas de nature, pas de
   * classement.
   */
  kind?: string | null;
}

/**
 * Les matchs qui ont le droit de déplacer un classement, dans l'ordre reçu.
 *
 * Deux conditions, et il faut les deux :
 *
 * - **concordant** — deux récits qui se contredisent ne disent pas qui a gagné,
 *   et inventer une réponse serait pire que de ne pas compter le match. Depuis la
 *   migration `20260817150000_match_kind`, la concordance porte aussi sur la
 *   nature : classé pour l'un et amical pour l'autre est un litige comme un
 *   autre. Les litiges restent en base, visibles.
 * - **classé, et EXPLICITEMENT** — l'amical est le défaut. Tout le reste est
 *   écarté : amical déclaré, nature sur laquelle les deux pairs se contredisent
 *   (la vue rend alors `null`), colonne absente, mot inconnu.
 *
 * Le sens de ce défaut est délibéré. Le pire cas est un match classé qui ne
 * compte pas : le rejeu étant intégral, il comptera dès que la donnée sera juste.
 * L'inverse — un amical entré au classement — ne se rattrape pas, faute d'avoir
 * jamais été distingué.
 *
 * Fonction pure, exportée pour être testée hors ligne : c'est ici que se joue la
 * séparation, et pas seulement dans la requête, qui filtre déjà mais qu'on peut
 * réécrire.
 */
export function rankedHistory(rows: readonly MatchRow[]): SettledMatch[] {
  return rows
    .filter((r) => r.concordant === true && r.kind === RANKED)
    .map((r) => ({
      playerA: r.player_a,
      playerB: r.player_b,
      winner: r.winner,
      forfeit: r.forfeit,
    }));
}

/**
 * Recalcule et réécrit tous les classements. Rend le nombre de joueurs classés.
 *
 * Ce qui est retenu, et pourquoi : voir `rankedHistory`.
 *
 * L'ordre est celui du règlement — le moment où le second rapport est arrivé.
 * Elo n'étant pas commutatif, ce tri est une décision, pas un détail.
 */
export async function recomputeRatings(): Promise<number> {
  const rows = await select<MatchRow>(
    "matches",
    "player_a,player_b,winner,concordant,forfeit,kind",
    // Le filtre SQL et `rankedHistory` disent la même chose deux fois, et c'est
    // voulu : le premier évite de rapatrier ce qui ne compte pas, le second tient
    // encore si quelqu'un réécrit la requête. Aucun des deux n'est l'unique
    // rempart, ce qui est la seule façon d'être tranquille sur un défaut dont la
    // manifestation est un silence.
    `concordant=is.true&kind=eq.${RANKED}&order=settled_at.asc`,
  );

  const history: SettledMatch[] = rankedHistory(rows);

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
