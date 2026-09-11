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

/**
 * Nature du match, dans les mots du type `public.match_kind`. C'est ce qui
 * s'écrit en base et ce que le rejeu relit : un seul vocabulaire des deux côtés.
 */
export const MATCH_KINDS = ["friendly", "ranked"] as const;
export type MatchKind = typeof MATCH_KINDS[number];

/**
 * Le seul mot qui autorise un match à déplacer un classement, et le seul endroit
 * où il est écrit : `ranking.ts` l'importe d'ici plutôt que de le réécrire, sans
 * quoi les deux moitiés du correctif pourraient diverger sans que rien ne casse
 * visiblement.
 */
export const RANKED: MatchKind = "ranked";
export const FRIENDLY: MatchKind = "friendly";

/** 16 octets tirés par l'hôte, rendus en hexadécimal. */
export const MATCH_ID_PATTERN = /^[0-9a-f]{32}$/;

/** Une journée. Aucun format concevable n'en approche ; c'est un garde-fou. */
export const MAX_DURATION_S = 86400;

export const MAX_MAP_ID = 64;
export const MAX_WEAPON = 32;

/**
 * PE2.3 (2026-09-10) — les CONDITIONS du match, telles que `conditions_de_match.gd`
 * les archive côté jeu : cadence par image, lien, machine. Décision d'Adrien :
 * elles voyagent avec le rapport des matchs en ligne, amicaux et classés, pour
 * qu'un relevé de cadence arrive en base sans qu'on ait à le demander à qui
 * que ce soit.
 *
 * Liste BLANCHE, clé par clé, et jamais bloquante : une clé inconnue est
 * ignorée, une valeur du mauvais type est ignorée, un bloc qui n'est pas un
 * objet vaut `null`. Le match a été joué et c'est le rapport qui fait foi — un
 * relevé de cadence mal formé ne doit jamais faire perdre un match au
 * classement (même arbitrage que le format inconnu ramené à BO1).
 */
export type MatchConditions = Record<string, unknown>;

/** Clés numériques du relevé lui-même. */
const CONDITION_NUMBERS = [
  "version", "images", "duree_s", "fps_moyen", "fps_median", "fps_1pc_bas",
  "pire_image_ms", "trous", "rtt_moyen_ms", "rtt_max_ms",
] as const;
/** Clés du bloc `machine`, par type. */
const MACHINE_STRINGS = [
  "version", "build", "os", "os_version", "cpu", "gpu", "gpu_fournisseur",
  "gpu_api", "gpu_pilote", "rendu", "pilote", "fenetre",
] as const;
const MACHINE_NUMBERS = [
  "coeurs", "memoire_mo", "ecran_hz", "vram_mo", "textures_mo",
] as const;
const MACHINE_BOOLEANS = ["plein_ecran"] as const;

/**
 * PE5 (chantier DIX CLASSES, étape 28, lot E, 2026-09-11) — la télémétrie des
 * gadgets, que le jeu glisse DANS les conditions (`MatchRecord.conditions_a_envoyer`) :
 * le jsonb de PE2.3, sans migration. Même tamis, et jamais un motif de refus : un
 * bloc illisible tombe, le rapport passe.
 *
 * ⚠️ Mêmes clés que `TelemetrieGadgets.COMPTEURS + CUMULS` (`telemetrie_gadgets.gd`) :
 * `tools/test_telemetrie_gadgets.gd` compare le tableau `GADGET_NUMBERS` à ces listes,
 * dans les deux sens. Une clé ajoutée d'un seul côté tomberait ici sans bruit.
 *
 * Pour la mine, `allumages` compte aussi les mines ABATTUES : les mines déclenchées
 * par un passage valent **au plus** `allumages − morts_balle` — un majorant, parce
 * qu'une mine abattue meurt 1,6 s plus tard et qu'un match archivé avant sa fin ne
 * compte aucune mort pour elle (revue du 2026-09-11). Chaque côté porte le slug de
 * son GADGET — aucune clé ne contient « classe ».
 */
const GADGETS_NUMBERS = ["version", "fenetre_s", "joueur_local"] as const;
const GADGET_NUMBERS = [
  "poses", "morts_balle", "morts_fin_de_vie", "allumages",
  "bascules_allume", "bascules_eteint", "batterie_vide",
  "morts_adverses_apres_effet", "morts_propres_apres_effet",
  "pv_braises_adversaire", "pv_braises_soi",
] as const;
/** Un slug de gadget (`nappe_braises`) n'a aucune raison de dépasser ça. */
export const MAX_GADGET_SLUG = 32;

/** Un nom de carte graphique ou de pilote n'a aucune raison de dépasser ça. */
export const MAX_CONDITION_TEXT = 96;

export interface MatchReport {
  matchId: string;
  outcome: Outcome;
  forfeit: boolean;
  duration: number;
  map: string;
  weaponSelf: string;
  weaponOpponent: string;
  format: string;
  kind: MatchKind;
  conditions: MatchConditions | null;
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

/** Un nombre FINI, ou rien : `NaN`, `Infinity`, une chaîne, `null` — rien. */
function finite(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

/** Un côté du bloc de gadgets (`j1` ou `j2`), au tamis ; `undefined` s'il n'en reste rien. */
function parseCoteGadget(value: unknown): Record<string, unknown> | undefined {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return undefined;
  const s = value as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const key of GADGET_NUMBERS) {
    const n = finite(s[key]);
    if (n !== undefined) out[key] = n;
  }
  if (typeof s.gadget === "string") out.gadget = text(s.gadget, MAX_GADGET_SLUG);
  return Object.keys(out).length > 0 ? out : undefined;
}

/**
 * PE5 — le bloc de gadgets, au tamis. `undefined` quand aucun des deux côtés ne
 * tient : un client d'avant l'étape 28, ou un bloc qui n'est pas un objet.
 */
export function parseGadgets(value: unknown): Record<string, unknown> | undefined {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return undefined;
  const s = value as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const key of GADGETS_NUMBERS) {
    const n = finite(s[key]);
    if (n !== undefined) out[key] = n;
  }
  for (const cote of ["j1", "j2"] as const) {
    const v = parseCoteGadget(s[cote]);
    if (v) out[cote] = v;
  }
  return out.j1 !== undefined || out.j2 !== undefined ? out : undefined;
}

/**
 * Les conditions, passées au tamis : ce qui est listé et bien typé entre, tout
 * le reste tombe sans bruit. Rend `null` quand il n'y a rien à garder — un
 * client d'avant PE2.3, ou un bloc qui n'est pas un objet.
 */
export function parseConditions(value: unknown): MatchConditions | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const source = value as Record<string, unknown>;
  const out: MatchConditions = {};
  for (const key of CONDITION_NUMBERS) {
    const n = finite(source[key]);
    if (n !== undefined) out[key] = n;
  }
  const rawMachine = source.machine;
  if (typeof rawMachine === "object" && rawMachine !== null && !Array.isArray(rawMachine)) {
    const m = rawMachine as Record<string, unknown>;
    const machine: Record<string, unknown> = {};
    for (const key of MACHINE_STRINGS) {
      if (typeof m[key] === "string") machine[key] = text(m[key], MAX_CONDITION_TEXT);
    }
    for (const key of MACHINE_NUMBERS) {
      const n = finite(m[key]);
      if (n !== undefined) machine[key] = n;
    }
    for (const key of MACHINE_BOOLEANS) {
      if (typeof m[key] === "boolean") machine[key] = m[key];
    }
    if (Object.keys(machine).length > 0) out.machine = machine;
  }
  // PE5 (étape 28, lot E) — la télémétrie des gadgets, rangée dans les conditions.
  const gadgets = parseGadgets(source.gadgets);
  if (gadgets) out.gadgets = gadgets;
  return Object.keys(out).length > 0 ? out : null;
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

  // Le classé est le cas EXPLICITE, l'amical le défaut. Seul un `true` franc
  // compte, exactement comme pour `forfeit` : champ absent, `null`, chaîne
  // « true », 1, mot inconnu — tout cela est amical.
  //
  // Le sens de ce défaut est la moitié du correctif. Un bogue de client peut
  // ainsi faire PERDRE un match au classement, ce qu'un rejeu rattrape dès que
  // la donnée est juste ; il ne peut pas en AJOUTER, ce qui demanderait de
  // retrouver après coup une information que personne n'a écrite.
  //
  // Une nature illisible ne fait donc pas échouer le rapport : le match a été
  // joué, et c'est le rapport qui fait foi — même arbitrage que le format
  // inconnu ramené à BO1.
  //
  // Le champ s'appelle `ranked` sur le fil et `kind` en base. C'est le jeu qui
  // pose le mot du fil (`report_match()` dans `ranked_identity.gd`), et la
  // traduction se fait ici, en un seul endroit, sous test.
  const kind: MatchKind = body.ranked === true ? RANKED : FRIENDLY;

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
      kind,
      // PE2.3 — jamais un motif de refus : voir `parseConditions`.
      conditions: parseConditions(body.conditions),
    },
  };
}
