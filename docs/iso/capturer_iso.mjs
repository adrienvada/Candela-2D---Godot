#!/usr/bin/env node
// Captures du prototype iso (docs/iso/proto_iso.html) avec Playwright + Chromium headless.
//
// Usage :
//   node docs/iso/capturer_iso.mjs [--brut DIR] [--three CHEMIN] [--seulement nom1,nom2]
//                                  [--largeur 1920] [--hauteur 1080] [--sans-planche]
//
// Écrit un PNG brut par capture dans DIR (défaut : <tmp>/candela_iso_brut) plus un
// manifeste.json, puis lance planche_iso.py qui compresse vers docs/iso/captures/ et
// compose docs/iso/planche_iso.jpg.
//
// Playwright : `npm i playwright` puis `npx playwright install chromium` (ou une
// installation globale lue par NODE_PATH — l'import passe par createRequire pour cela).
// Sans GPU, Chromium rend WebGL par SwiftShader (arguments ci-dessous) : ~6 s par image.
//
// Three.js : la page le charge depuis cdnjs. Si le réseau est fermé, poser `three.min.js`
// (r128) à côté de ce script ou le désigner par --three : il sera servi sous l'URL du CDN
// par page.route(), sans modifier la page.

import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { spawnSync } from 'node:child_process';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const ICI = path.dirname(fileURLToPath(import.meta.url));
const PAGE = path.join(ICI, 'proto_iso.html');
const URL_THREE = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';

// ---------------------------------------------------------------------------
// Le catalogue. Le yaw est choisi pour placer la caméra DERRIÈRE J1 : la torche
// éclaire les faces tournées vers J1, et la caméra ne voit que celles tournées vers
// elle — elles ne coïncident que si la caméra regarde dans le sens de la visée.
// La capture 12 montre volontairement le cas inverse.
// ---------------------------------------------------------------------------
const COMMUN = 'zoom=1.5&hud=0';
export const CAPTURES = [
  { nom: '01_default_unrailed', legende: 'Arène Standard · Unrailed ¾ · les deux torches face à face (19 tuiles)',
    params: 'carte=default&preset=unrailed&yaw=315' },
  { nom: '02_arene_circulaire_unrailed', legende: 'Arène Circulaire · Unrailed ¾ · bloc central entre les spawns',
    params: 'carte=arene_circulaire&preset=unrailed&yaw=315' },
  { nom: '03_le_cloitre_unrailed', legende: 'Le Cloître · Unrailed ¾ · pilier central dans le faisceau',
    params: 'carte=map_001_le_cloitre&preset=unrailed&yaw=315' },
  { nom: '04_l_usine_unrailed', legende: "L'Usine · Unrailed ¾ · murs et piliers",
    params: 'carte=map_002_l_usine&preset=unrailed&yaw=315' },
  { nom: '05_la_croisee_unrailed', legende: 'La Croisée · Unrailed ¾ · visée en diagonale (caméra au nord-ouest)',
    params: 'carte=map_003_la_croisee&preset=unrailed&yaw=225' },
  { nom: '06_le_bunker_unrailed', legende: 'Le Bunker · Unrailed ¾ · le faisceau passe la porte',
    params: 'carte=map_004_le_bunker&preset=unrailed&yaw=315' },
  { nom: '07_default_preset_unrailed', legende: 'Arène Standard · Unrailed ¾ (52°) · J2 à 8 tuiles, dans le faisceau',
    params: 'carte=default&preset=unrailed&yaw=315&j2=14,16' },
  { nom: '08_default_preset_iso', legende: 'Arène Standard · Isométrique vraie (35,26°)',
    params: 'carte=default&preset=iso&yaw=315&j2=14,16' },
  { nom: '09_default_preset_incline', legende: 'Arène Standard · Dessus incliné (70°)',
    params: 'carte=default&preset=incline&yaw=270&j2=14,16' },
  { nom: '10_default_preset_dessus', legende: 'Arène Standard · Dessus (90°) — la vue actuelle du jeu',
    params: 'carte=default&preset=dessus&j2=14,16' },
  { nom: '11_default_flash', legende: 'Arène Standard · flash de tir figé au pic (torche allumée)',
    params: 'carte=default&preset=unrailed&yaw=315&j2=14,16&flash=1' },
  { nom: '12_le_cloitre_contre_champ', legende: 'Le Cloître · CONTRE-CHAMP (yaw 45) · visée vers la caméra, faces cachées',
    params: 'carte=map_001_le_cloitre&preset=unrailed&yaw=45' },
];

function lireOptions(argv) {
  const o = { brut: path.join(os.tmpdir(), 'candela_iso_brut'), three: null, seulement: null, largeur: 1920, hauteur: 1080, planche: true };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--brut') o.brut = path.resolve(argv[++i]);
    else if (a === '--three') o.three = path.resolve(argv[++i]);
    else if (a === '--seulement') o.seulement = argv[++i].split(',');
    else if (a === '--largeur') o.largeur = parseInt(argv[++i], 10);
    else if (a === '--hauteur') o.hauteur = parseInt(argv[++i], 10);
    else if (a === '--sans-planche') o.planche = false;
    else { console.error('option inconnue :', a); process.exit(2); }
  }
  return o;
}

async function principal() {
  const opt = lireOptions(process.argv.slice(2));
  if (!fs.existsSync(PAGE)) throw new Error('page introuvable : ' + PAGE);
  fs.mkdirSync(opt.brut, { recursive: true });

  // Copie locale de Three.js : explicite, sinon à côté du script.
  let threeLocal = opt.three;
  if (!threeLocal && fs.existsSync(path.join(ICI, 'three.min.js'))) threeLocal = path.join(ICI, 'three.min.js');
  if (threeLocal && !fs.existsSync(threeLocal)) throw new Error('three.min.js introuvable : ' + threeLocal);

  const lancement = { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] };
  if (!threeLocal && process.env.HTTPS_PROXY) lancement.proxy = { server: process.env.HTTPS_PROXY };
  const navigateur = await chromium.launch(lancement);
  const contexte = await navigateur.newContext({
    viewport: { width: opt.largeur, height: opt.hauteur }, deviceScaleFactor: 1, ignoreHTTPSErrors: true,
  });
  const page = await contexte.newPage();
  const journal = [];
  page.on('console', m => { if (m.type() === 'error') journal.push('console.error : ' + m.text()); });
  page.on('pageerror', e => journal.push('pageerror : ' + e.message));
  page.on('requestfailed', r => journal.push('requête échouée : ' + r.url()));
  if (threeLocal) {
    await page.route('**/three.min.js', route => route.fulfill({ path: threeLocal, contentType: 'application/javascript' }));
    console.log('Three.js servi depuis', threeLocal);
  }

  const liste = opt.seulement ? CAPTURES.filter(c => opt.seulement.includes(c.nom)) : CAPTURES;
  const manifeste = [];
  let echecs = 0;
  for (const c of liste) {
    journal.length = 0;
    const url = 'file://' + PAGE + '?' + c.params + '&' + COMMUN;
    const t0 = Date.now();
    await page.goto(url, { waitUntil: 'load', timeout: 60000 });
    await page.waitForFunction(() => window.__pret === true, null, { timeout: 180000 });
    const info = await page.evaluate(() => ({ stats: window.__stats, erreurs: window.__erreurs }));
    const fichier = path.join(opt.brut, c.nom + '.png');
    await page.screenshot({ path: fichier, type: 'png' });
    const erreurs = journal.concat(info.erreurs || []);
    if (erreurs.length) { echecs++; console.error(c.nom, 'ERREURS :', erreurs.join(' | ')); }
    console.log(`${c.nom}  ${info.stats.grid[0]}×${info.stats.grid[1]}  ${info.stats.murs} murs  ${Date.now() - t0} ms`);
    manifeste.push({ nom: c.nom, legende: c.legende, params: c.params + '&' + COMMUN, fichier, stats: info.stats, erreurs });
  }
  await navigateur.close();

  // Avec --seulement, les entrées refaites remplacent les leurs dans le manifeste existant :
  // la planche garde les autres captures.
  const cheminManifeste = path.join(opt.brut, 'manifeste.json');
  let fusion = manifeste;
  if (opt.seulement && fs.existsSync(cheminManifeste)) {
    const ancien = JSON.parse(fs.readFileSync(cheminManifeste, 'utf8'));
    const refaits = new Map(manifeste.map(m => [m.nom, m]));
    fusion = ancien.map(m => refaits.get(m.nom) || m);
    manifeste.forEach(m => { if (!ancien.some(a => a.nom === m.nom)) fusion.push(m); });
    fusion.sort((a, b) => a.nom.localeCompare(b.nom));
  }
  fs.writeFileSync(cheminManifeste, JSON.stringify(fusion, null, 1));
  console.log(liste.length, 'captures brutes dans', opt.brut, echecs ? `(${echecs} avec erreurs)` : '(aucune erreur)');

  if (opt.planche) {
    const r = spawnSync('python3', [path.join(ICI, 'planche_iso.py'), '--brut', opt.brut], { stdio: 'inherit' });
    if (r.status !== 0) { console.error('planche_iso.py a échoué (Pillow installé ? `pip install pillow`)'); process.exit(1); }
  }
  if (echecs) process.exit(1);
}

principal().catch(e => { console.error(e); process.exit(1); });
