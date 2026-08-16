// Le calcul du classement.
//
// Lancer : deno test --allow-net=jsr.io supabase/functions/_shared/
//
// C'est la partie du système où une erreur est la plus difficile à voir après
// coup : un classement faux reste plausible. D'où des tests sur les propriétés
// — symétrie, conservation, monotonie — et pas seulement sur des valeurs.

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  expectedScore,
  K_FACTOR,
  nextRating,
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
