// POST /functions/v1/standing
//
// Rend le classement du joueur qui demande, son rang, et le haut du tableau.
// Lecture seule : rien n'est recalculé ici, le classement l'ayant été au moment
// où le match s'est réglé.
//
// Corps attendu : { "id_token": "<jwt Epic>" }

import { authenticate, fail, ok, readBody } from "../_shared/http.ts";
import { select } from "../_shared/db.ts";
import { Rank, rankOf } from "../_shared/elo.ts";

/** Un tableau qu'on lit d'un coup d'œil. Le rang du demandeur vient à part. */
const TOP = 10;

const COLUMNS = "player_id,nickname,rating,matches,wins,losses,draws,rank";

/**
 * Deux « rangs » cohabitent ici, et les confondre produirait un affichage faux
 * sans jamais lever d'erreur :
 *
 * - `rank` vient de la base : c'est la **position** au classement général
 *   (1er, 2e, 3e…), calculée par un `rank() over` dans la vue `leaderboard` ;
 * - `tier` vient de `rankOf` : c'est la **catégorie** de l'échelle (« Bougie II »),
 *   dérivée du seul classement.
 *
 * Le premier dépend de tous les autres joueurs, le second de personne. Ils ne
 * bougent pas ensemble : gagner peut changer la catégorie sans changer la
 * position, et l'inverse. D'où deux clés distinctes, jamais une seule.
 */
interface Row {
  player_id: string;
  nickname: string;
  rating: number;
  matches: number;
  wins: number;
  losses: number;
  draws: number;
  rank: number;
}

interface RankedRow extends Row {
  tier: Rank;
}

/**
 * La catégorie est calculée ici plutôt que stockée : c'est la même décision que
 * pour la table `ratings`, reconstruite par rejeu. Déplacer une borne d'échelle
 * ne doit coûter qu'un redéploiement, jamais une migration de données.
 *
 * Elle est calculée **côté serveur** plutôt que dans le jeu pour une raison
 * différente : deux implémentations de la même échelle divergeraient, et c'est
 * le classement affiché qui aurait tort.
 */
function withTier(row: Row): RankedRow {
  return { ...row, tier: rankOf(row.rating) };
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return fail(405, "methode", "POST attendu.");
  }

  const body = await readBody(request);
  if (body === null) {
    return fail(400, "corps_illisible", "Corps de requête illisible.");
  }

  const identity = await authenticate(body);
  if (identity instanceof Response) {
    return identity;
  }

  try {
    const me = await select<{ id: string }>(
      "players",
      "id",
      `puid=eq.${encodeURIComponent(identity.puid)}`,
    );
    if (me.length === 0) {
      return fail(404, "profil_inconnu", "Profil inconnu du classement.");
    }

    const top = await select<Row>("leaderboard", COLUMNS, `order=rank.asc&limit=${TOP}`);
    // Le demandeur peut être hors du haut du tableau : on le cherche à part
    // plutôt que d'élargir la liste, qui n'a pas à grandir avec le nombre de
    // joueurs.
    const mine = await select<Row>(
      "leaderboard",
      COLUMNS,
      `player_id=eq.${me[0].id}`,
    );

    return ok({
      // Absent du classement tant qu'aucun match concordant ne le concerne :
      // s'être identifié ne suffit pas, il faut avoir joué. Le jeu ne doit donc
      // jamais afficher de catégorie à quelqu'un qui n'a pas de ligne ici —
      // « Aveugle I » pour un joueur qui n'a jamais joué serait un rang inventé.
      standing: mine.length > 0 ? withTier(mine[0]) : null,
      top: top.map(withTier),
    });
  } catch (error) {
    console.error(`standing: ${error}`);
    return fail(500, "base_indisponible", "Classement momentanément indisponible.");
  }
});
