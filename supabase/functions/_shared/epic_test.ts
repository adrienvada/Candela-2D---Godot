// Vérification du jeton Epic — c'est ce fichier qui répond au critère
// « un PUID posté sans jeton valide est refusé ».
//
// Lancer : deno test supabase/functions/_shared/
//
// Les tests signent leurs propres jetons avec une paire de clés fabriquée à la
// volée, et injectent le JWKS correspondant. Aucun appel réseau, aucun secret :
// ce qui est vérifié, c'est la logique de refus, pas la disponibilité d'Epic.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { EpicTokenError, resetJwksCache, verifyEpicToken } from "./epic.ts";

const CLIENT_ID = "xyza7891CandelaClientId";
const DEPLOYMENT_ID = "deployment-de-production";
const PUID = "0002fb8a4c6d4f8e9b1c2d3e4f5a6b7c";
const KID = "2026-01-01T00:00:00.000Z";

const encoder = new TextEncoder();

// --- Fabrique de jetons -----------------------------------------------------

interface Signer {
  jwks: unknown;
  sign: (
    payload: Record<string, unknown>,
    header?: Record<string, unknown>,
  ) => Promise<string>;
}

async function makeSigner(kid = KID): Promise<Signer> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  // Les entrées d'Epic ne portent pas de champ `alg` : on reproduit cette forme
  // plutôt qu'une forme complaisante, sinon le test ne prouverait rien de la
  // réalité.
  const published = { kty: "RSA", use: "sig", kid, n: jwk.n, e: jwk.e };

  return {
    jwks: { keys: [published] },
    sign: async (payload, header = {}) => {
      const head = base64Url(JSON.stringify({ alg: "RS256", kid, ...header }));
      const body = base64Url(JSON.stringify(payload));
      const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        pair.privateKey,
        encoder.encode(`${head}.${body}`),
      );
      return `${head}.${body}.${base64UrlBytes(new Uint8Array(signature))}`;
    },
  };
}

function base64Url(text: string): string {
  return base64UrlBytes(encoder.encode(text));
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

const NOW = 1_800_000_000;

function claims(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    iss: "https://api.epicgames.dev/epic/oauth/v2",
    sub: PUID,
    aud: CLIENT_ID,
    iat: NOW - 30,
    exp: NOW + 3600,
    pfdid: DEPLOYMENT_ID,
    ...extra,
  };
}

/** Chaque test repart d'un cache vide : les clés changent d'un test à l'autre. */
async function verify(
  token: string,
  signer: Signer,
  options: Record<string, unknown> = {},
) {
  resetJwksCache();
  return await verifyEpicToken(token, {
    clientId: CLIENT_ID,
    deploymentId: DEPLOYMENT_ID,
    now: NOW,
    fetchJwks: () => Promise.resolve(signer.jwks),
    ...options,
  });
}

async function refusal(
  token: string,
  signer: Signer,
  options: Record<string, unknown> = {},
): Promise<string> {
  const error = await assertRejects(
    () => verify(token, signer, options),
    EpicTokenError,
  );
  return error.message;
}

// --- Le chemin nominal ------------------------------------------------------

Deno.test("un jeton signé, à jour et destiné au jeu rend le PUID", async () => {
  const signer = await makeSigner();
  const identity = await verify(await signer.sign(claims()), signer);
  assertEquals(identity.puid, PUID);
  assertEquals(identity.deployment, DEPLOYMENT_ID);
});

Deno.test("le PUID vient du jeton, jamais de ce que le client raconte", async () => {
  // Le corps de la requête peut annoncer n'importe quel PUID : seul `sub` est lu.
  const signer = await makeSigner();
  const identity = await verify(await signer.sign(claims({ sub: PUID })), signer);
  assertEquals(identity.puid, PUID);
});

// --- Les refus --------------------------------------------------------------

Deno.test("rien à vérifier : jeton vide ou malformé", async () => {
  const signer = await makeSigner();
  assertEquals(await refusal("", signer), "jeton_absent");
  assertEquals(await refusal("pas-un-jeton", signer), "jeton_malforme");
  assertEquals(await refusal("a.b", signer), "jeton_malforme");
  assertEquals(await refusal("@@@.@@@.@@@", signer), "segment_illisible");
  assertEquals(await refusal("x".repeat(9000), signer), "jeton_trop_long");
});

Deno.test("« alg: none » — le jeton que personne n'a signé", async () => {
  // Le piège classique : la charge utile est bien formée, l'en-tête déclare
  // qu'il n'y a pas de signature, et un vérificateur naïf l'accepte.
  const signer = await makeSigner();
  const head = base64Url(JSON.stringify({ alg: "none", kid: KID }));
  const body = base64Url(JSON.stringify(claims()));
  assertEquals(await refusal(`${head}.${body}.`, signer), "algorithme_refuse");
});

Deno.test("un algorithme symétrique est refusé avant tout calcul", async () => {
  const signer = await makeSigner();
  const head = base64Url(JSON.stringify({ alg: "HS256", kid: KID }));
  const body = base64Url(JSON.stringify(claims()));
  assertEquals(await refusal(`${head}.${body}.zzzz`, signer), "algorithme_refuse");
});

Deno.test("un jeton signé par une AUTRE clé est refusé", async () => {
  // Le cas qui compte vraiment : un attaquant capable de fabriquer un JWT
  // parfaitement formé, avec le PUID de sa victime, mais pas la clé d'Epic.
  const epic = await makeSigner();
  const imposteur = await makeSigner();
  const token = await imposteur.sign(claims());
  // Même `kid` : la clé publiée est celle d'Epic, la signature celle de l'autre.
  assertEquals(await refusal(token, epic), "signature_invalide");
});

Deno.test("une charge utile modifiée après signature est refusée", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims());
  const [head, , signature] = token.split(".");
  const falsifie = base64Url(JSON.stringify(claims({ sub: "puid-de-la-victime" })));
  assertEquals(
    await refusal(`${head}.${falsifie}.${signature}`, signer),
    "signature_invalide",
  );
});

Deno.test("un jeton d'un autre client EOS n'ouvre pas notre classement", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims({ aud: "un-autre-jeu" }));
  assertEquals(await refusal(token, signer), "audience_inattendue");
});

Deno.test("l'audience est acceptée aussi sous forme de tableau", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims({ aud: ["un-autre-jeu", CLIENT_ID] }));
  const identity = await verify(token, signer);
  assertEquals(identity.puid, PUID);
});

Deno.test("sans client_id attendu, la vérification refuse de conclure", async () => {
  // Une configuration incomplète ne doit jamais dégrader en « on laisse passer ».
  const signer = await makeSigner();
  assertEquals(
    await refusal(await signer.sign(claims()), signer, { clientId: "" }),
    "client_id_absent",
  );
});

Deno.test("un jeton expiré est refusé", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims({ exp: NOW - 120 }));
  assertEquals(await refusal(token, signer), "jeton_expire");
});

Deno.test("la tolérance d'horloge couvre une minute, pas davantage", async () => {
  const signer = await makeSigner();
  const limite = await signer.sign(claims({ exp: NOW - 30 }));
  const identity = await verify(limite, signer);
  assertEquals(identity.puid, PUID, "30 s de retard restent acceptables");

  const trop = await signer.sign(claims({ exp: NOW - 90 }));
  assertEquals(await refusal(trop, signer), "jeton_expire");
});

Deno.test("un jeton sans expiration est refusé", async () => {
  const signer = await makeSigner();
  const sans = claims();
  delete sans.exp;
  assertEquals(await refusal(await signer.sign(sans), signer), "jeton_expire");
});

Deno.test("un jeton émis dans le futur est refusé", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims({ iat: NOW + 600 }));
  assertEquals(await refusal(token, signer), "jeton_du_futur");
});

Deno.test("un émetteur qui n'est pas Epic est refusé", async () => {
  const signer = await makeSigner();
  for (
    const usurpateur of [
      // Le piège du préfixe : ce domaine commence bien par la base attendue.
      "https://api.epicgames.dev.attaquant.test",
      "https://api.epicgames.development/oauth",
      "http://api.epicgames.dev/epic/oauth/v2",
      "",
    ]
  ) {
    const token = await signer.sign(claims({ iss: usurpateur }));
    assertEquals(await refusal(token, signer), "emetteur_inattendu", usurpateur);
  }
});

Deno.test("les émetteurs légitimes d'Epic passent", async () => {
  const signer = await makeSigner();
  for (
    const emetteur of [
      "https://api.epicgames.dev",
      "https://api.epicgames.dev/epic/oauth/v2",
      "https://api.epicgames.dev/auth/v1/oauth",
    ]
  ) {
    const identity = await verify(await signer.sign(claims({ iss: emetteur })), signer);
    assertEquals(identity.puid, PUID, emetteur);
  }
});

Deno.test("un jeton d'un autre déploiement EOS est refusé", async () => {
  // Sépare le bac à sable de la production : un jeton de test ne doit pas
  // ouvrir un profil classé.
  const signer = await makeSigner();
  const token = await signer.sign(claims({ pfdid: "deployment-bac-a-sable" }));
  assertEquals(await refusal(token, signer), "deploiement_inattendu");
});

Deno.test("sans déploiement attendu, le contrôle ne s'applique pas", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims({ pfdid: "n-importe-lequel" }));
  const identity = await verify(token, signer, { deploymentId: undefined });
  assertEquals(identity.puid, PUID);
});

Deno.test("un jeton sans sub ne désigne personne", async () => {
  const signer = await makeSigner();
  const sans = claims();
  delete sans.sub;
  assertEquals(await refusal(await signer.sign(sans), signer), "puid_absent");
  assertEquals(await refusal(await signer.sign(claims({ sub: "   " })), signer), "puid_absent");
});

Deno.test("un kid inconnu ne trouve aucune clé", async () => {
  const epic = await makeSigner("kid-publie");
  const autre = await makeSigner("kid-inconnu");
  assertEquals(await refusal(await autre.sign(claims()), epic), "cle_inconnue");
});

Deno.test("un en-tête sans kid est refusé", async () => {
  const signer = await makeSigner();
  const head = base64Url(JSON.stringify({ alg: "RS256" }));
  const body = base64Url(JSON.stringify(claims()));
  assertEquals(await refusal(`${head}.${body}.zzzz`, signer), "kid_absent");
});

Deno.test("un JWKS illisible ne laisse rien passer", async () => {
  const signer = await makeSigner();
  const token = await signer.sign(claims());
  assertEquals(
    await refusal(token, signer, { fetchJwks: () => Promise.resolve({}) }),
    "jwks_illisible",
  );
  assertEquals(
    await refusal(token, signer, { fetchJwks: () => Promise.resolve({ keys: [] }) }),
    "jwks_vide",
  );
});

Deno.test("les clés publiques ne sont pas retéléchargées à chaque jeton", async () => {
  // Une fonction appelée à chaque lancement de partie n'a pas à marteler
  // l'infrastructure d'Epic.
  const signer = await makeSigner();
  let appels = 0;
  const source = () => {
    appels++;
    return Promise.resolve(signer.jwks);
  };
  resetJwksCache();
  for (let i = 0; i < 5; i++) {
    const identity = await verifyEpicToken(await signer.sign(claims()), {
      clientId: CLIENT_ID,
      now: NOW,
      fetchJwks: source,
    });
    assertEquals(identity.puid, PUID);
  }
  assertEquals(appels, 1, `JWKS téléchargé ${appels} fois`);
});

Deno.test("un kid inconnu ne relance qu'un seul téléchargement", async () => {
  // Rotation de clé côté Epic : le premier jeton au nouveau kid doit provoquer
  // un rafraîchissement, mais un flot de kid inventés ne doit pas en provoquer
  // un par jeton.
  const signer = await makeSigner();
  const inconnu = await makeSigner("kid-jamais-publie");
  let appels = 0;
  const source = () => {
    appels++;
    return Promise.resolve(signer.jwks);
  };
  resetJwksCache();
  for (let i = 0; i < 4; i++) {
    const token = await inconnu.sign(claims());
    const error = await assertRejects(
      () =>
        verifyEpicToken(token, {
          clientId: CLIENT_ID,
          now: NOW,
          fetchJwks: source,
        }),
      EpicTokenError,
    );
    assertEquals(error.message, "cle_inconnue");
  }
  assert(appels <= 2, `JWKS téléchargé ${appels} fois`);
});
