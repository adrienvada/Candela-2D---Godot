// POST /functions/v1/link
//
// Rattache la machine courante à un profil existant, sur présentation du code
// de récupération ET d'un jeton Epic valide. Les deux sont exigés : le code
// seul est un secret au porteur, le jeton seul ne dit rien du profil visé.
//
// Corps attendu : { "id_token": "<jwt Epic>", "recovery_code": "ABCD-EFGH-JKLM" }

import { authenticate, fail, ok, readBody } from "../_shared/http.ts";
import { callFunction } from "../_shared/db.ts";
import { isValidCode, sanitizeCode } from "../_shared/recovery_code.ts";

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

  // Le client nettoie déjà la saisie, mais il ne fait pas autorité : le code
  // arrive ici sous la forme que le joueur a tapée, tirets et espaces compris.
  const code = sanitizeCode(body.recovery_code);
  if (!isValidCode(code)) {
    return fail(400, "code_incomplet", "Code de récupération incomplet.");
  }

  try {
    const profile = await callFunction("link_profile", {
      p_code: code,
      p_puid: identity.puid,
    });
    if (profile === null) {
      // Un seul et même message pour « code faux » et « code d'un autre » :
      // rien n'apprend à celui qui essaie s'il approche.
      return fail(404, "code_inconnu", "Code de récupération inconnu.");
    }
    return ok({
      profile: {
        id: profile.id,
        nickname: profile.nickname,
        recovery_code: profile.code,
        arbitration: profile.arbitration,
        created_at: profile.created_at,
      },
    });
  } catch (error) {
    console.error(`link: ${error}`);
    return fail(500, "base_indisponible", "Classement momentanément indisponible.");
  }
});
