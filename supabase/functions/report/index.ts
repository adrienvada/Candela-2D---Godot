// POST /functions/v1/report
//
// Chaque pair déclare le match qu'il vient de jouer, et ne parle que de lui :
// « j'ai gagné », jamais « untel a perdu ». Le serveur apparie les deux rapports
// par leur `match_id` et apprend les deux identités des deux jetons Epic.
//
// Corps attendu :
//   { "id_token": "<jwt Epic>", "match_id": "<32 hex>", "outcome": "win|loss|draw",
//     "forfeit": false, "duration": 187.25, "map": "default",
//     "weapon_self": "Pompe", "weapon_opponent": "Fusil", "format": "BO1" }
//
// Aucun ELO n'est calculé ici. On archive, c'est tout.

import { authenticate, fail, ok, readBody } from "../_shared/http.ts";
import { callFunction, Row } from "../_shared/db.ts";
import { parseReport } from "../_shared/match_report.ts";
import { recomputeRatings } from "../_shared/ranking.ts";

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

  const parsed = parseReport(body);
  if (!parsed.ok) {
    return fail(400, parsed.reason, "Rapport de match invalide.");
  }
  const report = parsed.report;

  try {
    const saved = await callFunction<Row>("report_match", {
      p_puid: identity.puid,
      p_match_id: report.matchId,
      p_outcome: report.outcome,
      p_forfeit: report.forfeit,
      p_duration: report.duration,
      p_map: report.map,
      p_weapon_self: report.weaponSelf,
      p_weapon_opponent: report.weaponOpponent,
      p_format: report.format,
    });

    if (saved === null) {
      // Deux causes possibles, volontairement indistinctes du dehors : un PUID
      // jamais identifié, ou un troisième larron sur un match déjà complet.
      return fail(409, "rapport_refuse", "Rapport de match refusé.");
    }
    // Le second rapport vient peut-être de régler le match : on recalcule.
    // L'échec du recalcul ne doit PAS faire échouer le rapport — celui-ci est
    // déjà écrit, et c'est lui qui fait foi. Un classement en retard se rattrape
    // au match suivant ; un rapport perdu, jamais.
    let ranked = false;
    try {
      await recomputeRatings();
      ranked = true;
    } catch (error) {
      console.error(`report: recalcul du classement — ${error}`);
    }

    return ok({
      report: { id: saved.id, match_id: report.matchId, outcome: report.outcome },
      ranked,
    });
  } catch (error) {
    console.error(`report: ${error}`);
    return fail(500, "base_indisponible", "Classement momentanément indisponible.");
  }
});
