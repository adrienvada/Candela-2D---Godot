// Code de récupération — moitié serveur.
//
// Le code est tiré ICI et jamais par le client : c'est ce qui empêche un joueur
// de se choisir le code d'un autre. La moitié Godot (recovery_code.gd) ne sait
// que le nettoyer, le valider et le mettre en forme.
//
// L'alphabet est celui des codes de salon (lobby_code.gd) : ni I, ni O, ni 0,
// ni 1. Ces quatre-là se confondent deux à deux à l'oral comme à l'écrit, et ce
// code-ci sera lu à voix haute et recopié à la main.

export const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

/**
 * 12 caractères sur 32, soit 60 bits.
 *
 * Un code de salon en fait 6 : suffisant pour désigner un salon qui vit dix
 * minutes, dérisoire pour un secret au porteur qui donne accès à un profil
 * classé à vie. Le doublement de longueur est ce qui met une attaque en ligne
 * hors de portée.
 */
export const LENGTH = 12;

/** Groupes de lecture, pour l'affichage seulement — le stockage reste brut. */
export const GROUP = 4;

/**
 * Tire un code.
 *
 * `crypto.getRandomValues` et non `Math.random` : le code est un secret, pas un
 * identifiant. 256 est un multiple exact de 32, donc `octet % 32` ne biaise
 * aucun caractère — inutile de rejeter des tirages.
 */
export function generateCode(): string {
  const bytes = new Uint8Array(LENGTH);
  crypto.getRandomValues(bytes);
  let code = "";
  for (const byte of bytes) {
    code += ALPHABET[byte % ALPHABET.length];
  }
  return code;
}

/**
 * Ramène ce que le joueur a tapé à sa forme canonique : majuscules, tirets et
 * espaces retirés, caractères hors alphabet écartés, longueur plafonnée.
 *
 * Aucune substitution : « I » ne devient pas « J ». Deviner à la place du
 * joueur rattacherait le profil d'un autre, alors qu'un code refusé se retape.
 */
export function sanitizeCode(raw: unknown): string {
  if (typeof raw !== "string") {
    return "";
  }
  let out = "";
  for (const character of raw.toUpperCase()) {
    if (ALPHABET.includes(character)) {
      out += character;
      if (out.length === LENGTH) {
        break;
      }
    }
  }
  return out;
}

/** Vrai seulement si le code fait LENGTH caractères, tous dans l'alphabet. */
export function isValidCode(code: unknown): boolean {
  if (typeof code !== "string" || code.length !== LENGTH) {
    return false;
  }
  for (const character of code) {
    if (!ALPHABET.includes(character)) {
      return false;
    }
  }
  return true;
}

/** Forme lisible, par groupes de GROUP : « ABCD-EFGH-JKLM ». */
export function formatCode(code: string): string {
  const groups: string[] = [];
  for (let i = 0; i < code.length; i += GROUP) {
    groups.push(code.slice(i, i + GROUP));
  }
  return groups.join("-");
}

/**
 * Pseudo par défaut d'un profil neuf.
 *
 * Tiré indépendamment du code de récupération : en dériver le pseudo afficherait
 * en clair un morceau d'un secret.
 */
export function defaultNickname(): string {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  let suffix = "";
  for (const byte of bytes) {
    suffix += ALPHABET[byte % ALPHABET.length];
  }
  return `Joueur-${suffix}`;
}

/** Longueur maximale d'un pseudo, alignée sur la contrainte du schéma. */
export const NICKNAME_MAX = 24;

/**
 * Nettoie un pseudo proposé par le client. Rend une chaîne vide si rien
 * d'utilisable n'en sort, à charge de l'appelant de retomber sur le pseudo
 * par défaut.
 */
export function sanitizeNickname(raw: unknown): string {
  if (typeof raw !== "string") {
    return "";
  }
  // Les caractères de contrôle traverseraient jusqu'à l'écran de l'adversaire.
  const cleaned = raw.replace(/[\p{C}]/gu, " ").replace(/\s+/g, " ").trim();
  return cleaned.slice(0, NICKNAME_MAX);
}
