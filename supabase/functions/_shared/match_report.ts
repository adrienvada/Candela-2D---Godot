// Validation d'un rapport de match.
//
// Extraite du point d'entrée pour être testable hors ligne, comme le code de
// récupération. C'est la moitié du travail qui n'a besoin ni de réseau, ni de
// base, ni de secret — et c'est là que se logent les fautes d'inattention.
//
// Le client nettoie déjà sa saisie, mais il ne fait jamais autorité : tout ce
// qui arrive ici est retesté.

/** Ce que le RAPPORTEUR dit de lui-même. Jamais du sort d'un autre. */
export const OUTCOMES = ["win", "loss", "draw"] as const;
export type Outcome = typeof OUTCOMES[number];

export const FORMATS = ["BO1", "BO3", "BO5"] as const;

/** 16 octets tirés par l'hôte, rendus en hexadécimal. */
export const MATCH_ID_PATTERN = /^[0-9a-f]{32}$/;

/** Une journée. Aucun format concevable n'en approche ; c'est un garde-fou. */
export const MAX_DURATION_S = 86400;

export const MAX_MAP_ID = 64;
export const MAX_WEAPON = 32;

export interface MatchReport {
  matchId: string;
  outcome: Outcome;
  forfeit: boolean;
  duration: number;
  map: string;
  weaponSelf: string;
  weaponOpponent: string;
  format: string;
}

/**
 * Résultat de la validation : soit un rapport propre, soit le mot-clé du refus.
 * Ce mot-clé part tel quel au client et dans les journaux — il doit rester
 * stable, c'est sur lui que les tests s'appuient.
 */
export type ParseResult =
  | { ok: true; report: MatchReport }
  | { ok: false; reason: string };

/** Tronque plutôt que refuser : un nom d'arme trop long n'est pas une attaque. */
function text(value: unknown, max: number): string {
  return typeof value === "string" ? value.slice(0, max) : "";
}

export function parseReport(body: Record<string, unknown>): ParseResult {
  const matchId = typeof body.match_id === "string" ? body.match_id : "";
  if (!MATCH_ID_PATTERN.test(matchId)) {
    return { ok: false, reason: "match_id_invalide" };
  }

  const outcome = typeof body.outcome === "string" ? body.outcome : "";
  if (!(OUTCOMES as readonly string[]).includes(outcome)) {
    return { ok: false, reason: "issue_invalide" };
  }

  // `Number` sur une chaîne vide rend 0, et sur null rend 0 aussi : on exige
  // donc un nombre ou une chaîne numérique, et on rejette le reste.
  const raw = body.duration;
  const duration = typeof raw === "number" || (typeof raw === "string" && raw.trim() !== "")
    ? Number(raw)
    : Number.NaN;
  if (!Number.isFinite(duration) || duration < 0 || duration > MAX_DURATION_S) {
    return { ok: false, reason: "duree_invalide" };
  }

  const map = text(body.map, MAX_MAP_ID);
  if (map.length === 0) {
    return { ok: false, reason: "carte_absente" };
  }

  // Un format inconnu ne fait pas échouer le rapport : il retombe sur le seul
  // format réellement implémenté. Perdre un match parce qu'une version future a
  // inventé un sigle serait pire que de le ranger en BO1.
  const format = typeof body.format === "string"
      && (FORMATS as readonly string[]).includes(body.format)
    ? body.format
    : "BO1";

  return {
    ok: true,
    report: {
      matchId,
      outcome: outcome as Outcome,
      forfeit: body.forfeit === true,
      // Deux décimales : la base stocke numeric(8,2), inutile d'envoyer plus.
      duration: Number(duration.toFixed(2)),
      map,
      weaponSelf: text(body.weapon_self, MAX_WEAPON),
      weaponOpponent: text(body.weapon_opponent, MAX_WEAPON),
      format,
    },
  };
}
