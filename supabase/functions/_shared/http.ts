// Enveloppe commune aux deux fonctions : lecture de la requête, vérification du
// jeton Epic, mise en forme des réponses.
//
// Les deux fonctions partagent exactement la même porte d'entrée. La factoriser
// évite qu'un durcissement appliqué à l'une manque à l'autre.

import { EpicIdentity, EpicTokenError, verifyEpicToken } from "./epic.ts";

export function ok(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

/**
 * Réponse d'échec. `raison` est un mot-clé stable, destiné aux journaux et aux
 * tests ; `message` est la phrase que le joueur lira.
 */
export function fail(status: number, raison: string, message: string): Response {
  return new Response(JSON.stringify({ raison, message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** Corps JSON de la requête, ou `null` s'il est illisible. */
export async function readBody(
  request: Request,
): Promise<Record<string, unknown> | null> {
  try {
    const parsed = await request.json();
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

/**
 * Identité Epic du demandeur, ou la réponse d'échec à renvoyer telle quelle.
 *
 * Le PUID éventuellement posté dans le corps est IGNORÉ. Seul le `sub` du jeton
 * vérifié compte : c'est toute la différence entre un classement et un registre
 * de déclarations.
 */
export async function authenticate(
  body: Record<string, unknown>,
): Promise<EpicIdentity | Response> {
  const token = body.id_token;
  if (typeof token !== "string" || token.length === 0) {
    return fail(401, "jeton_absent", "Jeton Epic absent : identité non prouvée.");
  }

  const clientId = Deno.env.get("EPIC_CLIENT_ID") ?? "";
  if (!clientId) {
    // Sans audience attendue, on ne saurait pas distinguer notre jeu d'un autre
    // produit signé par Epic. Mieux vaut une fonction en panne qu'une porte
    // ouverte.
    console.error("EPIC_CLIENT_ID absent de l'environnement");
    return fail(500, "mal_configure", "Classement mal configuré côté serveur.");
  }

  try {
    return await verifyEpicToken(token, {
      clientId,
      deploymentId: Deno.env.get("EPIC_DEPLOYMENT_ID") ?? undefined,
    });
  } catch (error) {
    const raison = error instanceof EpicTokenError ? error.message : "verification_impossible";
    console.warn(`jeton Epic refusé : ${raison}`);
    return fail(401, raison, "Jeton Epic refusé.");
  }
}
