// POST /functions/v1/identify
//
// Le jeu se présente au démarrage avec son jeton Epic ; la fonction vérifie ce
// jeton, puis crée ou retrouve le profil du PUID qu'il porte, et rend le code
// de récupération pour affichage.
//
// Corps attendu : { "id_token": "<jwt Epic>", "nickname": "<facultatif>" }
// Un PUID posté ici n'est jamais lu : seul le `sub` du jeton fait foi.

import { authenticate, fail, ok, readBody } from "../_shared/http.ts";
import { callFunction, PostgrestError, UNIQUE_VIOLATION } from "../_shared/db.ts";
import {
  defaultNickname,
  generateCode,
  sanitizeNickname,
} from "../_shared/recovery_code.ts";

/**
 * Reprises sur collision de code. À 60 bits, une collision relève de la
 * curiosité statistique ; la contrainte d'unicité existe quand même, donc le
 * chemin qu'elle emprunte doit exister aussi.
 */
const CODE_ATTEMPTS = 3;

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

  const nickname = sanitizeNickname(body.nickname) || defaultNickname();

  for (let attempt = 0; attempt < CODE_ATTEMPTS; attempt++) {
    try {
      const profile = await callFunction("identify_player", {
        p_puid: identity.puid,
        // Consommé seulement si une ligne est réellement insérée : un profil
        // déjà connu garde le code que le joueur a peut-être déjà noté.
        p_code: generateCode(),
        p_nickname: nickname,
      });
      if (profile === null) {
        return fail(500, "profil_absent", "Profil introuvable après écriture.");
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
      const collision = error instanceof PostgrestError &&
        error.code === UNIQUE_VIOLATION;
      if (!collision || attempt === CODE_ATTEMPTS - 1) {
        console.error(`identify: ${error}`);
        return fail(500, "base_indisponible", "Classement momentanément indisponible.");
      }
      // Collision de code : on retire, sans rien dire au client.
    }
  }

  return fail(500, "base_indisponible", "Classement momentanément indisponible.");
});
