// Validation d'un rapport de match.
//
// Lancer : deno test --allow-net=jsr.io supabase/functions/_shared/
//
// Le client nettoie déjà sa saisie ; ces tests vérifient qu'on ne le croit pas
// sur parole. Chaque refus porte un mot-clé stable, sur lequel le jeu et les
// journaux s'appuient.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  MAX_DURATION_S,
  MAX_MAP_ID,
  MAX_WEAPON,
  parseReport,
} from "./match_report.ts";

const VALIDE = {
  match_id: "0123456789abcdef0123456789abcdef",
  outcome: "win",
  forfeit: false,
  duration: 187.25,
  map: "default",
  weapon_self: "Pompe",
  weapon_opponent: "Fusil",
  format: "BO1",
};

function refus(body: Record<string, unknown>): string {
  const r = parseReport(body);
  assert(!r.ok, "attendu un refus, obtenu un rapport valide");
  return r.reason;
}

function accepte(body: Record<string, unknown>) {
  const r = parseReport(body);
  assert(r.ok, "attendu un rapport valide, refusé pour « " + (r as { reason: string }).reason + " »");
  return r.report;
}

Deno.test("un rapport complet passe et garde ses valeurs", () => {
  const r = accepte({ ...VALIDE });
  assertEquals(r.matchId, VALIDE.match_id);
  assertEquals(r.outcome, "win");
  assertEquals(r.forfeit, false);
  assertEquals(r.duration, 187.25);
  assertEquals(r.map, "default");
  assertEquals(r.weaponSelf, "Pompe");
  assertEquals(r.weaponOpponent, "Fusil");
  assertEquals(r.format, "BO1");
});

Deno.test("l'identifiant de match est strictement contrôlé", () => {
  assertEquals(refus({ ...VALIDE, match_id: "" }), "match_id_invalide");
  assertEquals(refus({ ...VALIDE, match_id: "trop-court" }), "match_id_invalide");
  // Majuscules refusées : l'hôte n'en produit pas, et deux graphies du même
  // identifiant n'apparieraient pas les deux rapports.
  assertEquals(refus({ ...VALIDE, match_id: "0123456789ABCDEF0123456789ABCDEF" }), "match_id_invalide");
  assertEquals(refus({ ...VALIDE, match_id: "0123456789abcdef0123456789abcdeff" }), "match_id_invalide");
  assertEquals(refus({ ...VALIDE, match_id: "0123456789abcdef0123456789abcde!" }), "match_id_invalide");
  assertEquals(refus({ ...VALIDE, match_id: 42 }), "match_id_invalide");
});

Deno.test("les trois seules issues déclarables", () => {
  for (const outcome of ["win", "loss", "draw"]) {
    assertEquals(accepte({ ...VALIDE, outcome }).outcome, outcome);
  }
  // Personne ne déclare le sort d'un autre : « opponent_loss » n'existe pas.
  assertEquals(refus({ ...VALIDE, outcome: "opponent_loss" }), "issue_invalide");
  assertEquals(refus({ ...VALIDE, outcome: "WIN" }), "issue_invalide");
  assertEquals(refus({ ...VALIDE, outcome: "" }), "issue_invalide");
  assertEquals(refus({ ...VALIDE, outcome: null }), "issue_invalide");
});

Deno.test("la durée refuse tout ce qui n'est pas un nombre sensé", () => {
  assertEquals(refus({ ...VALIDE, duration: -1 }), "duree_invalide");
  assertEquals(refus({ ...VALIDE, duration: MAX_DURATION_S + 1 }), "duree_invalide");
  assertEquals(refus({ ...VALIDE, duration: Number.NaN }), "duree_invalide");
  assertEquals(refus({ ...VALIDE, duration: Number.POSITIVE_INFINITY }), "duree_invalide");
  // Le piège : Number("") et Number(null) valent 0, ce qui aurait fait passer
  // un champ absent pour un match d'une durée nulle.
  assertEquals(refus({ ...VALIDE, duration: "" }), "duree_invalide");
  assertEquals(refus({ ...VALIDE, duration: null }), "duree_invalide");
  assertEquals(refus({ ...VALIDE, duration: undefined }), "duree_invalide");
  assertEquals(refus({ ...VALIDE, duration: "abc" }), "duree_invalide");

  // Un abandon à la première seconde reste un match : zéro est légitime.
  assertEquals(accepte({ ...VALIDE, duration: 0 }).duration, 0);
  assertEquals(accepte({ ...VALIDE, duration: "42.5" }).duration, 42.5);
});

Deno.test("la durée est arrondie au centième, comme la colonne", () => {
  assertEquals(accepte({ ...VALIDE, duration: 12.3456 }).duration, 12.35);
});

Deno.test("la carte est obligatoire et bornée", () => {
  assertEquals(refus({ ...VALIDE, map: "" }), "carte_absente");
  assertEquals(refus({ ...VALIDE, map: 7 }), "carte_absente");
  assertEquals(accepte({ ...VALIDE, map: "x".repeat(200) }).map.length, MAX_MAP_ID);
});

Deno.test("les armes sont tronquées, jamais refusées", () => {
  // Un nom d'arme trop long est une bizarrerie, pas une attaque : perdre le
  // rapport d'un match joué serait la mauvaise réaction.
  const r = accepte({ ...VALIDE, weapon_self: "a".repeat(99), weapon_opponent: 12345 });
  assertEquals(r.weaponSelf.length, MAX_WEAPON);
  assertEquals(r.weaponOpponent, "");
});

Deno.test("un format inconnu retombe sur BO1 au lieu de tout perdre", () => {
  assertEquals(accepte({ ...VALIDE, format: "BO7" }).format, "BO1");
  assertEquals(accepte({ ...VALIDE, format: 3 }).format, "BO1");
  assertEquals(accepte({ ...VALIDE, format: "BO3" }).format, "BO3");
});

Deno.test("le forfait n'est vrai que s'il est vrai", () => {
  assertEquals(accepte({ ...VALIDE, forfeit: true }).forfeit, true);
  // Une chaîne « true » venue d'un client bricolé ne suffit pas.
  assertEquals(accepte({ ...VALIDE, forfeit: "true" }).forfeit, false);
  assertEquals(accepte({ ...VALIDE, forfeit: 1 }).forfeit, false);
  assertEquals(accepte({ ...VALIDE, forfeit: undefined }).forfeit, false);
});

Deno.test("un corps vide est refusé sur le premier contrôle", () => {
  assertEquals(refus({}), "match_id_invalide");
});
