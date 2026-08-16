// POST /functions/v1/standing
//
// Rend le classement du joueur qui demande, son rang, et le haut du tableau.
// Lecture seule : rien n'est recalculé ici, le classement l'ayant été au moment
// où le match s'est réglé.
//
// Corps attendu : { "id_token": "<jwt Epic>" }

import { authenticate, fail, ok, readBody } from "../_shared/http.ts";
import { select } from "../_shared/db.ts";

/** Un tableau qu'on lit d'un coup d'œil. Le rang du demandeur vient à part. */
const TOP = 10;

const COLUMNS = "player_id,nickname,rating,matches,wins,losses,draws,rank";

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
      // s'être identifié ne suffit pas, il faut avoir joué.
      standing: mine.length > 0 ? mine[0] : null,
      top,
    });
  } catch (error) {
    console.error(`standing: ${error}`);
    return fail(500, "base_indisponible", "Classement momentanément indisponible.");
  }
});
