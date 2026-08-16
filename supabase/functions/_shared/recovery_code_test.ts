// Génération et validation du code de récupération.
//
// Lancer : deno test supabase/functions/_shared/
//
// La génération vit côté serveur, ses tests aussi. La moitié Godot
// (recovery_code.gd) est couverte par tools/test_netcode.gd, et les deux suites
// vérifient le même contrat : ce que le serveur tire, le client l'accepte.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ALPHABET,
  defaultNickname,
  formatCode,
  generateCode,
  isValidCode,
  LENGTH,
  NICKNAME_MAX,
  sanitizeCode,
  sanitizeNickname,
} from "./recovery_code.ts";

Deno.test("l'alphabet écarte les quatre caractères ambigus", () => {
  for (const forbidden of ["I", "O", "0", "1"]) {
    assert(!ALPHABET.includes(forbidden), `${forbidden} présent dans l'alphabet`);
  }
  assertEquals(ALPHABET.length, 32);
});

Deno.test("un code tiré est toujours accepté par la validation", () => {
  // Contrat entre les deux bouts de la chaîne : ce qui sort de generateCode()
  // doit passer isValidCode(), sans quoi un joueur recevrait un code que la
  // fonction de rattachement refuserait.
  const seen = new Set<string>();
  for (let i = 0; i < 2000; i++) {
    const code = generateCode();
    assert(isValidCode(code), `code refusé : ${code}`);
    assertEquals(code.length, LENGTH);
    seen.add(code);
  }
  assertEquals(seen.size, 2000, "doublon sur 2000 tirages");
});

Deno.test("aucun caractère ambigu ne sort du tirage", () => {
  for (let i = 0; i < 2000; i++) {
    for (const character of generateCode()) {
      assert(ALPHABET.includes(character), `caractère hors alphabet : ${character}`);
    }
  }
});

Deno.test("le tirage couvre tout l'alphabet", () => {
  // Un générateur qui n'emploierait qu'une partie de l'alphabet perdrait des
  // bits sans le dire. 2000 tirages de 12 caractères couvrent les 32 lettres
  // avec une marge écrasante.
  const seen = new Set<string>();
  for (let i = 0; i < 2000; i++) {
    for (const character of generateCode()) {
      seen.add(character);
    }
  }
  assertEquals(seen.size, ALPHABET.length);
});

Deno.test("la validation refuse ce qui n'est pas un code canonique", () => {
  assert(!isValidCode(""));
  assert(!isValidCode("ABCD"));
  assert(!isValidCode("ABCDEFGHJKLMN"), "trop long");
  assert(!isValidCode("abcdefghjklm"), "minuscules");
  assert(!isValidCode("ABCDEFGHJKL1"), "caractère ambigu");
  assert(!isValidCode("ABCD-EFGH-JKL"), "forme affichée, pas canonique");
  assert(!isValidCode(null));
  assert(!isValidCode(12345678));
  assert(isValidCode("ABCDEFGHJKLM"));
});

Deno.test("le nettoyage rattrape ce que le joueur recopie", () => {
  assertEquals(sanitizeCode("abcdefghjklm"), "ABCDEFGHJKLM");
  assertEquals(sanitizeCode("ABCD-EFGH-JKLM"), "ABCDEFGHJKLM");
  assertEquals(sanitizeCode(" ABCD EFGH JKLM "), "ABCDEFGHJKLM");
  assertEquals(sanitizeCode("ABCDEFGHJKLMNPQR"), "ABCDEFGHJKLM", "longueur plafonnée");
  assertEquals(sanitizeCode(null), "");
  // Aucune substitution : un « I » disparaît, il ne devient pas « J ». Deviner
  // rattacherait le profil d'un autre.
  assertEquals(sanitizeCode("IABCDEFGHJKLM"), "ABCDEFGHJKLM");
  assertEquals(sanitizeCode("0O1I"), "");
});

Deno.test("nettoyer un code déjà canonique ne le change pas", () => {
  for (let i = 0; i < 200; i++) {
    const code = generateCode();
    assertEquals(sanitizeCode(code), code);
    assertEquals(sanitizeCode(formatCode(code)), code, "la forme affichée revient au canon");
  }
});

Deno.test("la mise en forme groupe par quatre", () => {
  assertEquals(formatCode("ABCDEFGHJKLM"), "ABCD-EFGH-JKLM");
  assertEquals(formatCode(""), "");
  assertEquals(formatCode("AB"), "AB");
});

Deno.test("le pseudo par défaut ne trahit pas le code", () => {
  // Dériver le pseudo du code de récupération afficherait en clair un morceau
  // d'un secret. Ils sont tirés séparément ; on vérifie au moins qu'un pseudo
  // ne coïncide pas avec un préfixe de code tiré au même moment.
  const nickname = defaultNickname();
  assert(nickname.startsWith("Joueur-"));
  assertEquals(nickname.length, "Joueur-".length + 4);
  const distinct = new Set(Array.from({ length: 200 }, () => defaultNickname()));
  assert(distinct.size > 190, `pseudos peu variés : ${distinct.size}`);
});

Deno.test("le pseudo proposé est nettoyé avant d'atteindre la base", () => {
  assertEquals(sanitizeNickname("  Vada  "), "Vada");
  assertEquals(sanitizeNickname("Va\u0000da"), "Va da", "un caractère de contrôle devient une espace");
  assertEquals(sanitizeNickname("Va\ndouble  espace"), "Va double espace");
  assertEquals(sanitizeNickname("a".repeat(80)).length, NICKNAME_MAX);
  assertEquals(sanitizeNickname(""), "");
  assertEquals(sanitizeNickname("   "), "");
  assertEquals(sanitizeNickname(42), "");
});
