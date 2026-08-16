// Accès à la base, réduit au strict nécessaire.
//
// Appel direct à PostgREST plutôt que la bibliothèque supabase-js : deux appels
// de fonction ne justifient pas de faire dépendre d'un paquet distant la seule
// porte d'entrée du classement. Tout tient en `fetch`.
//
// La clé employée ici est la clé SECRÈTE, injectée par Supabase dans
// l'environnement de la fonction. Elle contourne la Row Level Security — c'est
// précisément pour ça que le jeu ne la voit jamais.

export class DatabaseError extends Error {}

/** Profil tel que le rendent les deux fonctions SQL. */
export interface PlayerProfile {
  id: string;
  puid: string;
  code: string;
  nickname: string;
  arbitration: string;
  created_at: string;
  seen_at: string;
}

/** Code Postgres d'une violation de contrainte d'unicité. */
export const UNIQUE_VIOLATION = "23505";

export class PostgrestError extends Error {
  constructor(readonly code: string, readonly detail: string) {
    super(`postgrest ${code}: ${detail}`);
  }
}

function environment(): { url: string; key: string } {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  // `SUPABASE_SECRET_KEY` est le nouveau nom, `SUPABASE_SERVICE_ROLE_KEY`
  // l'ancien. Les deux contournent la RLS ; accepter les deux évite de dépendre
  // de la génération de clés du projet.
  const key = Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new DatabaseError("configuration_absente");
  }
  return { url, key };
}

/**
 * Appelle une fonction SQL. Rend `null` quand la fonction rend NULL — c'est le
 * signal d'échec de `link_profile`.
 */
export async function callFunction(
  name: string,
  args: Record<string, unknown>,
): Promise<PlayerProfile | null> {
  const { url, key } = environment();
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: key,
      authorization: `Bearer ${key}`,
      accept: "application/json",
    },
    body: JSON.stringify(args),
  });

  const text = await response.text();
  if (!response.ok) {
    let code = String(response.status);
    let detail = text;
    try {
      const parsed = JSON.parse(text);
      code = String(parsed.code ?? code);
      detail = String(parsed.message ?? detail);
    } catch {
      // Réponse non JSON : on garde le texte brut.
    }
    throw new PostgrestError(code, detail);
  }

  return firstRow(text);
}

/**
 * PostgREST rend tantôt l'objet seul, tantôt un tableau d'une entrée, selon la
 * version et la forme de la fonction appelée. Les deux mènent au même profil ;
 * l'absence de ligne, elle, doit rester distinguable — c'est le « code inconnu »
 * de `link_profile`.
 *
 * Le dernier contrôle n'est pas décoratif : une fonction SQL qui rendait un
 * composite NULL se présentait ici en OBJET DE CHAMPS NULS, pas en `null`, et
 * passait donc pour un profil valide. Les fonctions rendent désormais un
 * `setof`, ce qui lève l'ambiguïté à la source ; ce garde-fou reste pour qu'une
 * régression du même genre échoue bruyamment au lieu d'inventer un profil.
 */
function firstRow(text: string): PlayerProfile | null {
  if (text === "" || text === "null") {
    return null;
  }
  const parsed = JSON.parse(text);
  if (parsed === null) {
    return null;
  }
  const row = Array.isArray(parsed)
    ? (parsed.length > 0 ? parsed[0] : null)
    : parsed;
  if (row === null || typeof row !== "object" || typeof row.id !== "string") {
    return null;
  }
  return row as PlayerProfile;
}
