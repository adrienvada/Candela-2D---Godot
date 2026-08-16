// Le calcul du classement.
//
// Lancer : deno test --allow-net=jsr.io supabase/functions/_shared/
//
// C'est la partie du système où une erreur est la plus difficile à voir après
// coup : un classement faux reste plausible. D'où des tests sur les propriétés
// — symétrie, conservation, monotonie — et pas seulement sur des valeurs.

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  DIVISION_SPAN,
  DIVISIONS,
  expectedScore,
  K_FACTOR,
  nextRating,
  RANK_CEILING,
  RANK_FLOOR,
  RANK_TIERS,
  rankOf,
  replay,
  type SettledMatch,
  START_RATING,
} from "./elo.ts";

const A = "aaaa";
const B = "bbbb";
const C = "cccc";

function match(winner: string | null, forfeit = false, a = A, b = B): SettledMatch {
  return { playerA: a, playerB: b, winner, forfeit };
}

// --- score attendu ----------------------------------------------------------

Deno.test("à niveau égal, une chance sur deux", () => {
  assertAlmostEquals(expectedScore(1000, 1000), 0.5, 1e-12);
});

Deno.test("400 points d'écart valent dix contre un", () => {
  assertAlmostEquals(expectedScore(1400, 1000), 10 / 11, 1e-12);
  assertAlmostEquals(expectedScore(1000, 1400), 1 / 11, 1e-12);
});

Deno.test("les deux espérances se complètent toujours", () => {
  for (const [a, b] of [[1000, 1000], [1200, 800], [1, 3000], [2400, 2399]]) {
    assertAlmostEquals(expectedScore(a, b) + expectedScore(b, a), 1, 1e-12);
  }
});

// --- un match ---------------------------------------------------------------

Deno.test("gagner monte, perdre descend, et jamais l'inverse", () => {
  assert(nextRating(1000, 1000, 1) > 1000);
  assert(nextRating(1000, 1000, 0) < 1000);
  assertAlmostEquals(nextRating(1000, 1000, 0.5), 1000, 1e-12);
});

Deno.test("à niveau égal, un match déplace exactement K/2", () => {
  assertAlmostEquals(nextRating(1000, 1000, 1) - 1000, K_FACTOR / 2, 1e-12);
});

Deno.test("battre plus fort rapporte davantage que battre plus faible", () => {
  const contreFort = nextRating(1000, 1400, 1) - 1000;
  const contreFaible = nextRating(1000, 600, 1) - 1000;
  assert(contreFort > contreFaible, `${contreFort} devrait dépasser ${contreFaible}`);
});

Deno.test("perdre contre plus faible coûte davantage que perdre contre plus fort", () => {
  const contreFaible = 1000 - nextRating(1000, 600, 0);
  const contreFort = 1000 - nextRating(1000, 1400, 0);
  assert(contreFaible > contreFort);
});

Deno.test("un poids nul ne déplace rien, un poids double déplace le double", () => {
  assertAlmostEquals(nextRating(1000, 1200, 1, 0), 1000, 1e-12);
  const simple = nextRating(1000, 1200, 1, 1) - 1000;
  const double = nextRating(1000, 1200, 1, 2) - 1000;
  assertAlmostEquals(double, simple * 2, 1e-9);
});

// --- rejeu ------------------------------------------------------------------

Deno.test("sans match, personne n'est classé", () => {
  assertEquals(replay([]).size, 0);
});

Deno.test("un premier match part du classement de départ", () => {
  const r = replay([match(A)]);
  assertEquals(r.get(A)!.rating, START_RATING + K_FACTOR / 2);
  assertEquals(r.get(B)!.rating, START_RATING - K_FACTOR / 2);
});

Deno.test("le total des classements se conserve", () => {
  // Elo est un jeu à somme nulle : ce que l'un gagne, l'autre le perd. Une
  // dérive du total trahirait une erreur de calcul ou d'arrondi.
  const matches = [match(A), match(B), match(null), match(A), match(B, true)];
  const r = replay(matches);
  const total = [...r.values()].reduce((s, x) => s + x.rating, 0);
  assertEquals(total, 2 * START_RATING);
});

Deno.test("l'ordre des matchs change le résultat, et c'est normal", () => {
  // Elo n'est pas commutatif. Le test existe pour que personne ne « corrige »
  // un jour cette propriété en croyant à un défaut.
  const avant = replay([match(A), match(B, false, A, C)]);
  const apres = replay([match(B, false, A, C), match(A)]);
  assert(avant.get(A)!.rating !== apres.get(A)!.rating);
});

Deno.test("le décompte des matchs suit", () => {
  const r = replay([match(A), match(B), match(null)]);
  const a = r.get(A)!;
  assertEquals([a.matches, a.wins, a.losses, a.draws], [3, 1, 1, 1]);
  const b = r.get(B)!;
  assertEquals([b.matches, b.wins, b.losses, b.draws], [3, 1, 1, 1]);
});

Deno.test("une égalité entre égaux ne bouge rien", () => {
  const r = replay([match(null)]);
  assertEquals(r.get(A)!.rating, START_RATING);
  assertEquals(r.get(B)!.rating, START_RATING);
});

Deno.test("un forfait compte plein tarif", () => {
  // Conséquence directe de la décision actée : l'abandon ne doit pas être
  // gratuit. Si ce test tombe, c'est que le poids du forfait a bougé — ce qui
  // est permis, mais doit être délibéré.
  const joue = replay([match(A, false)]);
  const abandon = replay([match(A, true)]);
  assertEquals(joue.get(A)!.rating, abandon.get(A)!.rating);
});

Deno.test("les deux joueurs se calculent depuis les anciens classements", () => {
  // Mettre à jour A avant de calculer B rendrait le résultat dépendant de
  // l'ordre des deux joueurs dans la ligne — un défaut invisible à l'œil nu.
  const direct = replay([{ playerA: A, playerB: B, winner: A, forfeit: false }]);
  const inverse = replay([{ playerA: B, playerB: A, winner: A, forfeit: false }]);
  assertEquals(direct.get(A)!.rating, inverse.get(A)!.rating);
  assertEquals(direct.get(B)!.rating, inverse.get(B)!.rating);
});

Deno.test("un match d'un joueur contre lui-même est ignoré", () => {
  assertEquals(replay([{ playerA: A, playerB: A, winner: A, forfeit: false }]).size, 0);
});

Deno.test("rejouer deux fois le même historique donne le même résultat", () => {
  // C'est toute la promesse de l'architecture : le classement est une fonction
  // de l'historique, et rien d'autre.
  const matches: SettledMatch[] = [
    match(A), match(B), match(null), match(A, true),
    match(C, false, B, C), match(null, false, A, C),
  ];
  const un = replay(matches);
  const deux = replay(matches);
  for (const [id, s] of un) {
    assertEquals(deux.get(id)!.rating, s.rating, id);
  }
});

Deno.test("gagner tous ses matchs finit par payer, sans exploser", () => {
  const matches = Array.from({ length: 50 }, () => match(A));
  const r = replay(matches);
  assert(r.get(A)!.rating > START_RATING + 200);
  // Le classement converge : les gains fondent à mesure que l'écart grandit.
  assert(r.get(A)!.rating < START_RATING + 800, String(r.get(A)!.rating));
  assertEquals(r.get(A)!.wins, 50);
});

Deno.test("un joueur qui n'a jamais joué n'apparaît pas", () => {
  const r = replay([match(A)]);
  assertEquals(r.has(C), false);
});

// --- rangs ------------------------------------------------------------------
//
// Les bornes de l'échelle sont provisoires : les tester par des valeurs écrites
// en dur reviendrait à figer ce qu'on a justement prévu de déplacer. Ce qui doit
// tenir quelles que soient les bornes, ce sont les propriétés — monotonie,
// couverture, totalité — et c'est cela seul qu'on vérifie ici.

/**
 * L'échelle reconstruite indépendamment de `rankOf`, du bas vers le haut.
 *
 * Ce n'est pas une redite du code testé : c'est l'autre bout de la chaîne. Si
 * `rankOf` produit un libellé absent d'ici, ou les produit dans le désordre, la
 * position dans cette liste le dira.
 */
const ECHELLE: string[] = [
  ...RANK_TIERS.slice(0, -1).flatMap((tier) => DIVISIONS.map((d) => `${tier} ${d}`)),
  RANK_TIERS[RANK_TIERS.length - 1],
];

/** Position d'un classement sur l'échelle, 0 tout en bas. */
function position(rating: number): number {
  const rang = rankOf(rating);
  const i = ECHELLE.indexOf(rang.label);
  assert(i >= 0, `libellé hors échelle : « ${rang.label} » pour ${rating}`);
  return i;
}

Deno.test("les dix catégories sont celles qui ont été validées", () => {
  // Décision d'Adrien du 2026-08-17. Le test existe pour qu'un changement
  // d'ordre ou de nom soit délibéré, jamais collatéral.
  assertEquals(RANK_TIERS.length, 10);
  assertEquals(RANK_TIERS[0], "Aveugle");
  assertEquals(RANK_TIERS[RANK_TIERS.length - 1], "Candela");
});

Deno.test("un meilleur classement ne rend jamais un rang inférieur", () => {
  let precedent = -1;
  for (let r = -5000; r <= 12000; r += 7) {
    const ici = position(r);
    assert(ici >= precedent, `${r} redescend à ${ECHELLE[ici]}`);
    precedent = ici;
  }
});

Deno.test("l'échelle ne laisse ni trou ni chevauchement", () => {
  // Un pas de 1 sur toute la fenêtre utile : la position ne peut que rester la
  // même ou avancer d'un cran. Un saut de deux serait un rang inatteignable,
  // un recul un chevauchement de bornes.
  let precedent = 0;
  const vus = new Set<number>([0]);
  for (let r = RANK_FLOOR - 300; r <= RANK_CEILING + 300; r++) {
    const ici = position(r);
    assert(
      ici === precedent || ici === precedent + 1,
      `saut de ${ECHELLE[precedent]} à ${ECHELLE[ici]} au classement ${r}`,
    );
    vus.add(ici);
    precedent = ici;
  }
  // Et chaque rang doit être atteignable, sans quoi il ne sert à rien.
  assertEquals(vus.size, ECHELLE.length);
});

Deno.test("aucun classement, si extrême soit-il, ne sort de l'échelle", () => {
  // La fonction est totale : c'est la seule garantie qui compte côté affichage,
  // où un `undefined` deviendrait un rang vide sans la moindre erreur.
  const extremes = [
    0,
    -1,
    -1e9,
    1e9,
    Number.MAX_SAFE_INTEGER,
    Number.MIN_SAFE_INTEGER,
    Number.NaN,
    Number.POSITIVE_INFINITY,
    Number.NEGATIVE_INFINITY,
  ];
  for (const r of extremes) {
    const rang = rankOf(r);
    assert(ECHELLE.includes(rang.label), `${r} rend « ${rang.label} »`);
    assert(RANK_TIERS.includes(rang.tier), `${r} rend la catégorie ${rang.tier}`);
    assert(rang.tierIndex >= 1 && rang.tierIndex <= RANK_TIERS.length, String(r));
    assert(rang.division === null || (rang.division >= 1 && rang.division <= 3), String(r));
  }
  // Les extrémités se rabattent, elles ne débordent pas.
  assertEquals(rankOf(-1e9).label, ECHELLE[0]);
  assertEquals(rankOf(1e9).label, ECHELLE[ECHELLE.length - 1]);
  // NaN n'est ni haut ni bas : il tombe au plancher, faute de mieux.
  assertEquals(rankOf(Number.NaN).label, ECHELLE[0]);
});

Deno.test("le sommet est le seul rang sans division", () => {
  const sommet = rankOf(RANK_CEILING);
  assertEquals(sommet.tier, "Candela");
  assertEquals(sommet.division, null);
  assertEquals(sommet.label, "Candela");
  assertEquals(sommet.nextLabel, null);
  assertEquals(sommet.pointsToNext, null);

  // Et réciproquement : partout ailleurs, la division est renseignée.
  for (let r = RANK_FLOOR - 200; r < RANK_CEILING; r += 3) {
    const rang = rankOf(r);
    assert(rang.division !== null, `${r} (${rang.label}) n'a pas de division`);
    assert(rang.tier !== "Candela", `${r} est Candela sous le seuil`);
  }
});

Deno.test("la distance au rang suivant tombe pile sur la borne", () => {
  for (let r = RANK_FLOOR - 200; r < RANK_CEILING; r++) {
    const rang = rankOf(r);
    const reste = rang.pointsToNext;
    assert(reste !== null && rang.nextLabel !== null, `${r} n'a pas de suite`);
    assert(reste > 0, `${r} annonce ${reste} points restants`);
    // Les points annoncés amènent exactement au rang annoncé, et pas un de moins.
    assertEquals(rankOf(r + reste).label, rang.nextLabel, `${r} + ${reste}`);
    assertEquals(rankOf(r + reste - 1).label, rang.label, `${r} + ${reste} - 1`);
  }
});

Deno.test("dans l'échelle, il ne reste jamais plus d'une division à franchir", () => {
  // Sous le plancher, en revanche, la distance dit la vraie remontée : c'est
  // voulu, une valeur rassurante y serait un mensonge.
  for (let r = RANK_FLOOR; r < RANK_CEILING; r += 3) {
    const reste = rankOf(r).pointsToNext!;
    assert(reste <= DIVISION_SPAN, `${r} annonce ${reste} points`);
  }
  assert(rankOf(RANK_FLOOR - 500).pointsToNext! > DIVISION_SPAN);
});

Deno.test("un débutant est dans la partie basse, sans être collé au plancher", () => {
  const depart = rankOf(START_RATING);
  assert(depart.tierIndex > 1, `un débutant démarre ${depart.label} : rien à perdre`);
  assert(
    depart.tierIndex <= RANK_TIERS.length / 2,
    `un débutant démarre ${depart.label} : trop haut`,
  );
});

Deno.test("le premier match d'un débutant ne change pas son rang", () => {
  // Un rang qui saute au tout premier match ne veut rien dire — et c'est
  // justement ce match-là qu'un nouveau joueur regarde. Si ce test tombe, le
  // classement de départ n'est plus centré dans sa division.
  const depart = rankOf(START_RATING).label;
  assertEquals(rankOf(nextRating(START_RATING, START_RATING, 1)).label, depart);
  assertEquals(rankOf(nextRating(START_RATING, START_RATING, 0)).label, depart);
});

Deno.test("dominer cinquante fois le même adversaire ne mène pas au sommet", () => {
  // L'échelle doit laisser de la marge au-dessus d'un joueur qui écrase un seul
  // adversaire : Elo converge, et Candela ne doit pas s'obtenir en s'acharnant.
  const r = replay(Array.from({ length: 50 }, () => match(A)));
  const rang = rankOf(r.get(A)!.rating);
  assert(rang.tier !== "Candela", `cinquante victoires suffisent à finir ${rang.label}`);
  assert(rang.tierIndex > rankOf(START_RATING).tierIndex, `resté ${rang.label}`);
});

Deno.test("le rang est une fonction pure du classement", () => {
  // Aucun état, aucune mémoire : c'est ce qui permet de déplacer une borne sans
  // migrer quoi que ce soit.
  for (const r of [0, RANK_FLOOR, START_RATING, RANK_CEILING, 3000]) {
    assertEquals(rankOf(r), rankOf(r));
  }
});
