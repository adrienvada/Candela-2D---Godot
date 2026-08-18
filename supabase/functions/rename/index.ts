// POST /functions/v1/rename
//
// Change le pseudo du profil rattaché à cette machine, sur présentation d'un
// jeton Epic valide — et de rien d'autre.
//
// Le PUID vient du jeton, jamais du corps de la requête. Accepter un
// identifiant de profil laisserait renommer celui d'un autre à qui saurait le
// deviner ; le jeton, lui, ne prouve qu'une chose et c'est la bonne : « je suis
// cette machine ».
//
// Corps attendu : { "id_token": "<jwt Epic>", "nickname": "<nouveau pseudo>" }

import { authenticate, fail, ok, readBody } from "../_shared/http.ts";
import { callFunction } from "../_shared/db.ts";
import { sanitizeNickname } from "../_shared/recovery_code.ts";

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

  // Le client nettoie déjà la saisie, mais il ne fait pas autorité : le pseudo
  // arrive ici tel que le joueur l'a tapé. `sanitizeNickname` retire les
  // caractères de contrôle — ceux-là traverseraient jusqu'à l'écran de
  // l'adversaire — et plafonne la longueur.
  const nickname = sanitizeNickname(body.nickname);
  if (nickname.length < 1) {
    // Un pseudo vide n'est pas un pseudo. On refuse plutôt que de retomber sur
    // un « Joueur-XXXX » : le joueur croirait avoir renommé, et découvrirait
    // autre chose sur l'écran de fin de son adversaire.
    return fail(400, "pseudo_vide", "Le pseudo ne peut pas être vide.");
  }

  try {
    const profile = await callFunction("rename_profile", {
      p_puid: identity.puid,
      p_nickname: nickname,
    });
    if (profile === null) {
      return fail(404, "profil_inconnu", "Aucun profil sur cette machine.");
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
    console.error(`rename: ${error}`);
    return fail(500, "base_indisponible", "Classement momentanément indisponible.");
  }
});
