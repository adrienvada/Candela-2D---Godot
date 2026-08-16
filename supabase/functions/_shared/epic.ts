// Vérification du jeton d'identité Epic.
//
// C'est la pièce sur laquelle repose tout le classement : un PUID posté en
// clair ne prouve rien, n'importe qui pourrait en envoyer un. Le client joint
// donc le jeton signé par Epic (`EOS.Connect.ConnectInterface.copy_id_token`),
// et rien n'est écrit avant que ce jeton n'ait été vérifié ICI, contre les clés
// publiques publiées par Epic.
//
// Aucune dépendance externe : tout tient dans Web Crypto, présent dans Deno.
// Une fonction qui garde la porte d'entrée du classement n'a rien à gagner à
// dépendre d'un paquet tiers.

/** Clés publiques d'Epic. Les entrées n'y portent pas de champ `alg`. */
const JWKS_URL = "https://api.epicgames.dev/auth/v1/oauth/jwks";

/** L'émetteur doit commencer par cette base — exigence documentée par Epic. */
const ISSUER_PREFIX = "https://api.epicgames.dev";

/** Seul algorithme accepté. Tout le reste — à commencer par `none` — est refusé. */
const ALGORITHM = "RS256";

/** Tolérance d'horloge, dans les deux sens. */
const CLOCK_SKEW_S = 60;

/** Durée de vie du cache de clés. */
const JWKS_TTL_MS = 10 * 60 * 1000;

/** Intervalle minimal entre deux rafraîchissements forcés (kid inconnu). */
const JWKS_REFRESH_COOLDOWN_MS = 60 * 1000;

/** Garde-fou : un jeton Epic tient largement là-dedans. */
const MAX_TOKEN_LENGTH = 8192;

export class EpicTokenError extends Error {}

export interface EpicIdentity {
  /** PUID, extrait du `sub` — digne de confiance seulement après vérification. */
  puid: string;
  /** Déploiement EOS annoncé par le jeton (`pfdid`), quand il est présent. */
  deployment: string | null;
}

export interface VerifyOptions {
  /** Client ID EOS attendu en `aud`. Obligatoire : sans lui, rien n'est vérifié. */
  clientId: string;
  /** Déploiement EOS attendu en `pfdid`. Facultatif, mais recommandé. */
  deploymentId?: string;
  /** Instant de référence, en secondes. Injectable pour les tests. */
  now?: number;
  /** Source des clés publiques. Injectable pour les tests. */
  fetchJwks?: () => Promise<unknown>;
}

interface JsonWebKey {
  kty?: string;
  kid?: string;
  n?: string;
  e?: string;
  alg?: string;
  use?: string;
}

let cachedKeys: Map<string, JsonWebKey> | null = null;
let cachedAt = 0;
let lastRefreshAt = 0;

/**
 * Vérifie un jeton et rend le PUID qu'il porte.
 *
 * Lève `EpicTokenError` au moindre doute. Les messages restent volontairement
 * pauvres côté appelant : un attaquant n'a pas à apprendre où il a buté.
 */
export async function verifyEpicToken(
  token: string,
  options: VerifyOptions,
): Promise<EpicIdentity> {
  if (!options.clientId) {
    // Sans audience attendue, la vérification laisserait passer le jeton d'un
    // tout autre jeu signé par la même autorité. Refuser vaut mieux qu'accepter.
    throw new EpicTokenError("client_id_absent");
  }
  if (typeof token !== "string" || token.length === 0) {
    throw new EpicTokenError("jeton_absent");
  }
  if (token.length > MAX_TOKEN_LENGTH) {
    throw new EpicTokenError("jeton_trop_long");
  }

  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new EpicTokenError("jeton_malforme");
  }
  const [rawHeader, rawPayload, rawSignature] = parts;

  const header = decodeJsonSegment(rawHeader);
  // Le contrôle qui compte le plus, et le premier : un jeton `alg: none` est
  // valide au sens du format et signé par personne.
  if (header.alg !== ALGORITHM) {
    throw new EpicTokenError("algorithme_refuse");
  }
  const kid = typeof header.kid === "string" ? header.kid : "";
  if (!kid) {
    throw new EpicTokenError("kid_absent");
  }

  const jwk = await findKey(kid, options.fetchJwks);
  if (!jwk) {
    throw new EpicTokenError("cle_inconnue");
  }

  const signed = new TextEncoder().encode(`${rawHeader}.${rawPayload}`);
  const signature = base64UrlDecode(rawSignature);
  const key = await importKey(jwk);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signature,
    signed,
  );
  if (!valid) {
    throw new EpicTokenError("signature_invalide");
  }

  // À partir d'ici la signature est bonne : le contenu vient bien d'Epic. Reste
  // à vérifier qu'il nous est destiné, et qu'il est d'actualité.
  const payload = decodeJsonSegment(rawPayload);
  const now = options.now ?? Math.floor(Date.now() / 1000);

  const issuer = typeof payload.iss === "string" ? payload.iss : "";
  if (!isEpicIssuer(issuer)) {
    throw new EpicTokenError("emetteur_inattendu");
  }

  const exp = numeric(payload.exp);
  if (exp === null || exp + CLOCK_SKEW_S <= now) {
    throw new EpicTokenError("jeton_expire");
  }

  const iat = numeric(payload.iat);
  if (iat !== null && iat - CLOCK_SKEW_S > now) {
    throw new EpicTokenError("jeton_du_futur");
  }

  // `aud` est une chaîne ou un tableau, selon la lettre de la RFC.
  const audiences = Array.isArray(payload.aud)
    ? payload.aud.map((a) => String(a))
    : [String(payload.aud ?? "")];
  if (!audiences.includes(options.clientId)) {
    throw new EpicTokenError("audience_inattendue");
  }

  const deployment = typeof payload.pfdid === "string" ? payload.pfdid : null;
  // Le déploiement sépare la production du bac à sable : un jeton de test ne
  // doit pas ouvrir un profil classé. Le contrôle ne s'applique que si le
  // déploiement attendu est configuré ET annoncé par le jeton.
  if (options.deploymentId && deployment && deployment !== options.deploymentId) {
    throw new EpicTokenError("deploiement_inattendu");
  }

  const puid = typeof payload.sub === "string" ? payload.sub.trim() : "";
  if (!puid) {
    throw new EpicTokenError("puid_absent");
  }

  return { puid, deployment };
}

// ---------------------------------------------------------------------------
// CLÉS PUBLIQUES
// ---------------------------------------------------------------------------

/**
 * Cherche la clé du `kid` annoncé, en rafraîchissant le cache si elle manque.
 *
 * Epic ajoute des clés au fil du temps : un `kid` inconnu est le cas normal
 * d'une rotation, pas une attaque. Le rafraîchissement est bridé pour qu'un
 * flot de jetons à `kid` inventé ne se transforme pas en flot de requêtes vers
 * Epic.
 */
async function findKey(
  kid: string,
  fetchJwks?: () => Promise<unknown>,
): Promise<JsonWebKey | null> {
  const source = fetchJwks ?? defaultFetchJwks;
  const now = Date.now();

  if (!cachedKeys || now - cachedAt > JWKS_TTL_MS) {
    await refresh(source, now);
  }
  const hit = cachedKeys?.get(kid);
  if (hit) {
    return hit;
  }
  if (now - lastRefreshAt > JWKS_REFRESH_COOLDOWN_MS) {
    await refresh(source, now);
  }
  return cachedKeys?.get(kid) ?? null;
}

async function refresh(
  source: () => Promise<unknown>,
  now: number,
): Promise<void> {
  lastRefreshAt = now;
  const document = await source();
  const keys = (document as { keys?: unknown })?.keys;
  if (!Array.isArray(keys)) {
    throw new EpicTokenError("jwks_illisible");
  }
  const parsed = new Map<string, JsonWebKey>();
  for (const entry of keys as JsonWebKey[]) {
    if (entry?.kty === "RSA" && typeof entry.kid === "string" && entry.n && entry.e) {
      parsed.set(entry.kid, entry);
    }
  }
  if (parsed.size === 0) {
    throw new EpicTokenError("jwks_vide");
  }
  cachedKeys = parsed;
  cachedAt = now;
}

async function defaultFetchJwks(): Promise<unknown> {
  const response = await fetch(JWKS_URL, {
    headers: { accept: "application/json" },
  });
  if (!response.ok) {
    throw new EpicTokenError("jwks_injoignable");
  }
  return await response.json();
}

function importKey(jwk: JsonWebKey): Promise<CryptoKey> {
  // `alg` est forcé à RS256 : les entrées d'Epic n'en portent pas, et importer
  // sans algorithme laisserait la clé utilisable par autre chose.
  return crypto.subtle.importKey(
    "jwk",
    { kty: "RSA", n: jwk.n, e: jwk.e, alg: ALGORITHM, ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

/** Vide le cache de clés. Réservé aux tests. */
export function resetJwksCache(): void {
  cachedKeys = null;
  cachedAt = 0;
  lastRefreshAt = 0;
}

// ---------------------------------------------------------------------------
// OUTILS
// ---------------------------------------------------------------------------

function decodeJsonSegment(segment: string): Record<string, unknown> {
  let text: string;
  try {
    text = new TextDecoder().decode(base64UrlDecode(segment));
  } catch {
    throw new EpicTokenError("segment_illisible");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new EpicTokenError("segment_illisible");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new EpicTokenError("segment_illisible");
  }
  return parsed as Record<string, unknown>;
}

function base64UrlDecode(segment: string): Uint8Array<ArrayBuffer> {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded + "=".repeat((4 - (padded.length % 4)) % 4));
  // Tampon explicite : Web Crypto n'accepte pas une vue sur un ArrayBufferLike
  // qui pourrait être partagé entre threads.
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/**
 * L'émetteur doit être la base d'Epic, ou un chemin sous cette base.
 *
 * Le simple préfixe ne suffit pas : `https://api.epicgames.dev.attaquant.test`
 * commence bien par la base attendue tout en désignant un autre domaine. Exiger
 * la base exacte ou une barre oblique juste après ferme ce détournement.
 */
function isEpicIssuer(issuer: string): boolean {
  return issuer === ISSUER_PREFIX || issuer.startsWith(`${ISSUER_PREFIX}/`);
}

/** Un `exp` rendu sous forme de chaîne reste exploitable ; un NaN, non. */
function numeric(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}
