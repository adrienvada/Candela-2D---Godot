// Le calcul du classement.
//
// Logique pure : ni base, ni réseau, ni horloge. C'est ce qui la rend testable
// hors ligne, et c'est délibéré — le classement est la partie du système où une
// erreur est la plus difficile à voir après coup.
//
// **Le classement n'est jamais une valeur écrite une fois pour toutes.** Il se
// RECALCULE depuis l'historique des matchs, qui seul fait foi. Conséquence
// directe et voulue : un mauvais facteur K, un mauvais classement de départ, une
// mauvaise pondération du forfait cessent d'être fatals — on change la constante
// et on rejoue. Sans cette propriété, la première erreur de réglage serait
// définitive.

/**
 * Classement de départ. Rond et lisible ; sa valeur exacte n'a aucune
 * importance, seuls les écarts en ont.
 */
export const START_RATING = 1000;

/**
 * Facteur K — de combien un match peut déplacer un classement.
 *
 * 32 est la valeur classique. Volontairement constante pour l'instant : pas de
 * phase provisoire à K élevé, pas de K dégressif. Ces raffinements sont
 * légitimes, mais chacun est une règle inventée de plus, et ils ne coûteront
 * qu'un changement de constante suivi d'un recalcul le jour où le besoin sera
 * démontré plutôt que supposé.
 */
export const K_FACTOR = 32;

/**
 * Poids d'un match gagné par forfait.
 *
 * 1 — un abandon compte plein tarif. C'est la conséquence directe de la décision
 * actée : ne pas rendre l'abandon gratuit. On pourrait objecter qu'un forfait ne
 * dit rien du niveau des deux joueurs ; c'est vrai, et c'est pourquoi ce poids
 * est nommé et isolé. Le baisser est un changement d'une ligne, suivi d'un
 * recalcul.
 */
export const FORFEIT_WEIGHT = 1;

/** Un match réglé, tel que la vue `matches` le rend. */
export interface SettledMatch {
  playerA: string;
  playerB: string;
  /** Gagnant, ou `null` en cas d'égalité. */
  winner: string | null;
  forfeit: boolean;
}

export interface Standing {
  rating: number;
  matches: number;
  wins: number;
  losses: number;
  draws: number;
}

/**
 * Probabilité que `ratingA` l'emporte sur `ratingB`.
 *
 * La formule d'Elo : 400 points d'écart valent dix contre un.
 */
export function expectedScore(ratingA: number, ratingB: number): number {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

/**
 * Nouveau classement après un match.
 *
 * `score` vaut 1 pour une victoire, 0.5 pour une égalité, 0 pour une défaite.
 * `weight` module l'ampleur du déplacement sans toucher à sa direction.
 */
export function nextRating(
  rating: number,
  opponentRating: number,
  score: number,
  weight = 1,
): number {
  return rating + K_FACTOR * weight * (score - expectedScore(rating, opponentRating));
}

function blank(): Standing {
  return { rating: START_RATING, matches: 0, wins: 0, losses: 0, draws: 0 };
}

/**
 * Rejoue tout l'historique et rend le classement de chaque joueur.
 *
 * L'ordre des matchs compte — Elo n'est pas commutatif. C'est à l'appelant de
 * fournir la liste dans l'ordre où les matchs ont été réglés ; cette fonction ne
 * trie rien, pour que le critère de tri reste une décision visible et non un
 * détail enfoui ici.
 *
 * Les classements sont arrondis à l'entier **à la toute fin** seulement : arrondir
 * à chaque match ferait dériver le total au fil des parties.
 */
export function replay(matches: readonly SettledMatch[]): Map<string, Standing> {
  const exact = new Map<string, number>();
  const tally = new Map<string, Standing>();

  const rating = (id: string): number => {
    const known = exact.get(id);
    if (known !== undefined) {
      return known;
    }
    exact.set(id, START_RATING);
    tally.set(id, blank());
    return START_RATING;
  };

  for (const m of matches) {
    // Un match d'un joueur contre lui-même ne veut rien dire et fausserait tout.
    if (m.playerA === m.playerB) {
      continue;
    }
    const before = { a: rating(m.playerA), b: rating(m.playerB) };
    const weight = m.forfeit ? FORFEIT_WEIGHT : 1;

    let scoreA = 0.5;
    if (m.winner === m.playerA) {
      scoreA = 1;
    } else if (m.winner === m.playerB) {
      scoreA = 0;
    }

    // Les deux nouveaux classements se calculent depuis les ANCIENS : mettre à
    // jour A avant de calculer B donnerait un résultat qui dépend de l'ordre
    // des deux joueurs dans la ligne.
    exact.set(m.playerA, nextRating(before.a, before.b, scoreA, weight));
    exact.set(m.playerB, nextRating(before.b, before.a, 1 - scoreA, weight));

    const ta = tally.get(m.playerA)!;
    const tb = tally.get(m.playerB)!;
    ta.matches++;
    tb.matches++;
    if (scoreA === 1) {
      ta.wins++;
      tb.losses++;
    } else if (scoreA === 0) {
      ta.losses++;
      tb.wins++;
    } else {
      ta.draws++;
      tb.draws++;
    }
  }

  for (const [id, standing] of tally) {
    standing.rating = Math.round(exact.get(id)!);
  }
  return tally;
}

// --- l'échelle des rangs -----------------------------------------------------
//
// Même architecture que le classement, et pour la même raison : le rang est une
// **fonction pure du classement**, calculée à l'affichage et jamais écrite en
// base. La table `ratings` est déjà reconstruite par rejeu ; si le rang, lui,
// était stocké, déplacer une borne d'échelle exigerait une migration de
// données. Dérivé, cela ne coûte qu'un redéploiement — et c'est précisément ce
// qui autorise à poser des bornes provisoires sans se lier les mains.

/**
 * Les dix catégories, de l'obscurité vers la lumière, jusqu'au nom du jeu.
 *
 * Ordre validé par Adrien le 2026-08-17 : il ne se réarrange pas au fil de
 * l'eau. La progression n'est pas décorative — elle raconte la seule chose que
 * le jeu donne au joueur, la lumière.
 */
export const RANK_TIERS = [
  "Aveugle",
  "Braise",
  "Bougie",
  "Lanterne",
  "Torche",
  "Brasier",
  "Phare",
  "Aurore",
  "Zénith",
  "Candela",
] as const;

export type RankTier = (typeof RANK_TIERS)[number];

/**
 * Les trois divisions d'une catégorie, de la plus basse à la plus haute.
 *
 * Convention Rocket League, que la ROADMAP donne explicitement pour modèle :
 * la division **I est la plus basse**, la III la plus haute. C'est l'inverse de
 * League of Legends, d'où ce rappel — interverties, les divisions produisent
 * une échelle qui reste parfaitement plausible à l'œil, et l'erreur ne se voit
 * qu'au moment où un joueur se plaint de descendre en gagnant.
 *
 * La dixième catégorie, Candela, n'en a aucune : c'est le sommet, il ne se
 * subdivise pas.
 */
export const DIVISIONS = ["I", "II", "III"] as const;

/** Largeur d'une division, en points de classement. */
export const DIVISION_SPAN = 40;

/**
 * Plancher de l'échelle : en dessous, tout le monde est Aveugle I.
 *
 * 700 et 40 ne valent pas pour eux-mêmes, mais pour l'endroit où ils placent
 * `START_RATING` : **au centre exact de Bougie II**, troisième catégorie sur
 * dix. Un débutant est donc dans la partie basse sans être collé au plancher —
 * il lui reste six catégories et demie devant lui, et deux derrière, ce qui
 * laisse la place de descendre : une échelle dont personne ne peut chuter ne
 * récompense rien.
 *
 * Le détail qui a décidé du centrage : un premier match entre égaux déplace
 * K/2 = 16 points, et la marge de part et d'autre du départ est de 20. Ni la
 * première victoire ni la première défaite ne change donc le rang affiché. Un
 * rang qui saute au premier match ne veut rien dire, et c'est le tout premier
 * match qu'un nouveau joueur regarde.
 *
 * **Ces bornes sont provisoires.** Elles n'ont de sens qu'avec une population
 * réelle, qui n'existe pas encore : les fixer maintenant donne quelque chose à
 * afficher, cela ne prétend pas connaître la distribution. Les déplacer le jour
 * où elle sera connue ne coûtera qu'un redéploiement.
 */
export const RANK_FLOOR = 700;

/** Neuf catégories de trois divisions ; la dixième est indivisible. */
const TOTAL_DIVISIONS = (RANK_TIERS.length - 1) * DIVISIONS.length;

/** Classement à partir duquel on est Candela — le sommet, sans division. */
export const RANK_CEILING = RANK_FLOOR + TOTAL_DIVISIONS * DIVISION_SPAN;

export interface Rank {
  tier: RankTier;
  /** 1 à 10, la numérotation de la ROADMAP (et celle de la Phase 7). */
  tierIndex: number;
  /** 1 (I, la plus basse) à 3 (III) ; `null` pour Candela, qui n'en a pas. */
  division: number | null;
  /** Libellé court, prêt à afficher : « Bougie II », ou « Candela » au sommet. */
  label: string;
  /** Le rang juste au-dessus, ou `null` au sommet. */
  nextLabel: string | null;
  /** Points qui séparent du rang suivant, ou `null` au sommet. */
  pointsToNext: number | null;
}

/** Libellé d'une division par son rang absolu sur l'échelle (0 = Aveugle I). */
function labelAt(index: number): string {
  if (index >= TOTAL_DIVISIONS) {
    return RANK_TIERS[RANK_TIERS.length - 1];
  }
  const tier = RANK_TIERS[Math.floor(index / DIVISIONS.length)];
  return `${tier} ${DIVISIONS[index % DIVISIONS.length]}`;
}

/**
 * Le rang correspondant à un classement.
 *
 * Fonction totale : tout nombre rend un rang. Les classements extrêmes se
 * rabattent sur les extrémités de l'échelle plutôt que de sortir du tableau,
 * parce que le seul appelant est un affichage et qu'un `undefined` y devient un
 * rang vide sans la moindre erreur pour le signaler.
 */
export function rankOf(rating: number): Rank {
  // NaN et ±Infinity n'ont pas de « points restants » qui veuille dire quelque
  // chose : on les épingle aux bornes de l'échelle. `NaN > 0` étant faux, un
  // classement illisible tombe au plancher — le seul choix qui ne flatte
  // personne.
  const value = Number.isFinite(rating) ? rating : (rating > 0 ? RANK_CEILING : RANK_FLOOR);

  // L'index est borné des deux côtés : c'est là, et nulle part ailleurs, que se
  // joue la robustesse aux classements extrêmes.
  const step = Math.floor((value - RANK_FLOOR) / DIVISION_SPAN);
  const index = Math.min(Math.max(step, 0), TOTAL_DIVISIONS);

  const top = index >= TOTAL_DIVISIONS;
  const tierIndex = top ? RANK_TIERS.length : Math.floor(index / DIVISIONS.length) + 1;

  return {
    tier: RANK_TIERS[tierIndex - 1],
    tierIndex,
    division: top ? null : (index % DIVISIONS.length) + 1,
    label: labelAt(index),
    nextLabel: top ? null : labelAt(index + 1),
    // Distance mesurée depuis le classement réel, pas depuis le bas de la
    // division : un joueur très en dessous du plancher doit lire la vraie
    // remontée qui lui reste, pas une valeur rassurante.
    pointsToNext: top ? null : RANK_FLOOR + (index + 1) * DIVISION_SPAN - value,
  };
}
