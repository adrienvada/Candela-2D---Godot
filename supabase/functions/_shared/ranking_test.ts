// La porte par laquelle un match entre — ou n'entre pas — dans le classement.
//
// Lancer : deno test --allow-net=jsr.io supabase/functions/_shared/
//
// Une erreur ici ne se voit pas. Un classement faux reste plausible, et un match
// amical qui aurait compté ne se distinguera plus jamais d'un vrai match, faute
// que la distinction ait été écrite. D'où des tests de PROPRIÉTÉS plutôt que de
// valeurs — et d'abord celle qui ne doit jamais régresser : retirer les amicaux
// d'un historique ne change aucun classement.
//
// `rankedHistory` est pure : rien de ce fichier ne touche à la base.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { type MatchRow, rankedHistory } from "./ranking.ts";
import { replay, START_RATING, type Standing } from "./elo.ts";
import { FRIENDLY, RANKED } from "./match_report.ts";

const A = "aaaa";
const B = "bbbb";
const C = "cccc";
const D = "dddd";

/** Une ligne de la vue `matches` : concordante, classée, A gagne, sauf mention. */
function row(over: Partial<MatchRow> = {}): MatchRow {
  return {
    player_a: A,
    player_b: B,
    winner: A,
    concordant: true,
    forfeit: false,
    kind: RANKED,
    ...over,
  };
}

function total(standings: Map<string, Standing>): number {
  return [...standings.values()].reduce((s, x) => s + x.rating, 0);
}

// --- ce qui compte, ce qui ne compte pas ------------------------------------

Deno.test("un match amical ne bouge aucun classement", () => {
  // Pas « bouge peu » : il n'entre pas du tout dans le rejeu, et les deux joueurs
  // n'apparaissent donc même pas au classement.
  const r = replay(rankedHistory([row({ kind: FRIENDLY })]));
  assertEquals(r.size, 0);
});

Deno.test("un match classé bouge les classements, et le total se conserve", () => {
  const r = replay(rankedHistory([row()]));
  assertEquals(r.size, 2);
  assert(r.get(A)!.rating > START_RATING, `${r.get(A)!.rating} pour le vainqueur`);
  assert(r.get(B)!.rating < START_RATING, `${r.get(B)!.rating} pour le vaincu`);
  // Elo est à somme nulle : ce que l'un gagne, l'autre le perd.
  assertEquals(total(r), 2 * START_RATING);
});

Deno.test("deux pairs qui se contredisent sur la nature ne comptent pour rien", () => {
  // C'est la vue `matches` qui tranche, et elle le dit deux fois : `kind` devient
  // `null` et `concordant` devient faux. Chacun des deux suffit à écarter le
  // match — on les vérifie séparément, pour qu'aucun ne devienne l'unique rempart
  // sans que personne s'en aperçoive.
  assertEquals(rankedHistory([row({ kind: null, concordant: false })]).length, 0);
  assertEquals(rankedHistory([row({ kind: null })]).length, 0);
  assertEquals(rankedHistory([row({ concordant: false })]).length, 0);
});

Deno.test("champ absent, null ou mot inconnu valent amical", () => {
  // Règle non négociable : le classé est le cas explicite. Un bogue de client
  // peut faire perdre un match au classement — un rejeu le rattrape —, jamais en
  // ajouter un, ce qui demanderait une information que personne n'a écrite.
  const douteuses: MatchRow[] = [
    row({ kind: null }),
    row({ kind: undefined }),
    row({ kind: "" }),
    row({ kind: "RANKED" }),
    row({ kind: "Ranked" }),
    row({ kind: "ranked " }),
    row({ kind: "classe" }),
    row({ kind: "friendly" }),
    // Un client bricolé, ou un JSON relu de travers : ni un booléen ni un nombre
    // ne valent le mot.
    row({ kind: true as unknown as string }),
    row({ kind: 1 as unknown as string }),
  ];
  for (const ligne of douteuses) {
    assertEquals(rankedHistory([ligne]).length, 0, JSON.stringify(ligne.kind));
  }

  // Et la colonne peut manquer tout court : vue d'une version antérieure, ou
  // faute de frappe dans la liste des colonnes demandées.
  const sansColonne = row();
  delete sansColonne.kind;
  assertEquals(rankedHistory([sansColonne]).length, 0);
});

// --- LA propriété -----------------------------------------------------------

/**
 * Un historique mêlé, tel que la vue le rendrait : des classés, des amicaux, un
 * litige d'issue, un litige de nature, et un joueur qui n'a JAMAIS joué classé.
 */
const MELANGE: MatchRow[] = [
  row({ winner: A }),
  row({ kind: FRIENDLY, winner: B }),
  row({ player_a: A, player_b: C, winner: C }),
  row({ kind: FRIENDLY, player_a: A, player_b: D, winner: D }),
  row({ winner: null }),
  row({ kind: null, player_a: B, player_b: C, winner: B }),
  row({ player_a: B, player_b: C, winner: B, forfeit: true }),
  row({ concordant: false, player_a: A, player_b: C, winner: A }),
  row({ kind: FRIENDLY, player_a: C, player_b: D, winner: C }),
  row({ winner: B }),
];

/**
 * Le même historique, privé de ses amicaux et de ses litiges — écrit à la main
 * plutôt que filtré.
 *
 * Ce n'est pas une redite : filtrer `MELANGE` avec le prédicat testé rendrait le
 * test circulaire, et il passerait encore si ce prédicat devenait faux.
 */
const CLASSES_SEULS: MatchRow[] = [
  row({ winner: A }),
  row({ player_a: A, player_b: C, winner: C }),
  row({ winner: null }),
  row({ player_a: B, player_b: C, winner: B, forfeit: true }),
  row({ winner: B }),
];

Deno.test("retirer les amicaux d'un historique ne change aucun classement", () => {
  // **C'est LA propriété à ne jamais laisser régresser.** Tout le correctif tient
  // dans cette phrase : le classement est une fonction des seuls matchs classés.
  // Si elle tombe, un match amical déplace un classement — et plus rien, en base,
  // ne dira lesquels il aurait fallu écarter.
  assert(MELANGE.length > CLASSES_SEULS.length, "l'historique mêlé doit l'être");
  assertEquals(replay(rankedHistory(MELANGE)), replay(rankedHistory(CLASSES_SEULS)));
});

Deno.test("jouer des amicaux ne fait pas entrer au classement", () => {
  // D n'a que des amicaux à son nom : il ne doit pas exister au classement. Le
  // sortir du tableau et l'y laisser à 1000 points ne sont pas la même chose —
  // un rang affiché à qui n'a jamais joué classé serait un rang inventé.
  const classement = replay(rankedHistory(MELANGE));
  assertEquals(classement.has(D), false);
  assertEquals(classement.has(A), true);
});

Deno.test("un amical ne compte pas non plus dans le décompte des matchs", () => {
  // Le décompte voyage avec le classement dans la même table : un amical qui
  // gonflerait le nombre de matchs serait la même fuite, en plus discrète.
  const classement = replay(rankedHistory(MELANGE));
  const attendu = replay(rankedHistory(CLASSES_SEULS));
  assertEquals(classement.get(A)!.matches, attendu.get(A)!.matches);
  assertEquals(classement.get(A)!.wins, attendu.get(A)!.wins);
});

// --- fidélité de la traduction ----------------------------------------------

Deno.test("l'ordre reçu est préservé, amicaux retirés", () => {
  // Elo n'est pas commutatif et l'appelant a trié par `settled_at` : réordonner
  // ici donnerait des classements faux et parfaitement plausibles.
  const histoire = rankedHistory([
    row({ winner: A }),
    row({ kind: FRIENDLY, winner: A }),
    row({ winner: B }),
    row({ kind: null, winner: A }),
    row({ winner: null }),
  ]);
  assertEquals(histoire.map((m) => m.winner), [A, B, null]);
});

Deno.test("la ligne de la vue se traduit champ pour champ", () => {
  // Une inversion de `player_a` et `player_b` dans la traduction n'exploserait
  // jamais : elle attribuerait juste les points à l'autre.
  assertEquals(
    rankedHistory([row({ player_a: C, player_b: D, winner: D, forfeit: true })]),
    [{ playerA: C, playerB: D, winner: D, forfeit: true }],
  );
  // Une égalité garde son `null` : `undefined` ne serait égal à aucun joueur, ce
  // qui donnerait par chance le même résultat — jusqu'au jour où ce ne serait
  // plus le cas.
  assertEquals(rankedHistory([row({ winner: null })])[0].winner, null);
});

Deno.test("un historique vide ne classe personne", () => {
  assertEquals(rankedHistory([]).length, 0);
  assertEquals(replay(rankedHistory([])).size, 0);
});
