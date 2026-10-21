// Skald release in one command.
//
//   node tools/release.js 0.31.2-beta                   builds everything (nothing is sent anywhere)
//   node tools/release.js 0.31.2-beta --upload          ... and uploads the zip to CurseForge
//   node tools/release.js --list-game-versions          prints the CurseForge game version ids
//
// What it does, in order:
//   1. runs tools/checks.js and stops if anything fails;
//   2. reads the notes of this version from Skald-publish/NEXT_CHANGELOG.md (bullet points, no header);
//   3. writes the version into Skald/Skald.toc;
//   4. adds the version to CHANGELOG.md and writes CHANGELOG_<version>_para-colar.md;
//   5. copies the addon into skald-repo/ (the folder for GitHub) with README.md, LICENSE and CHANGELOG.md;
//   6. builds Skald-<version>.zip (a folder "Skald/" at its root, compressed) and checks it;
//   7. with --upload: sends the zip to CurseForge as a beta (needs CF_API_TOKEN and the game version id).
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');                 // Skald-publish
const ADDONS = path.resolve(ROOT, '../Interface/AddOns');
const TOC = path.join(ADDONS, 'Skald/Skald.toc');
const args = process.argv.slice(2);
const flag = n => args.includes(n);
const value = n => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const die = msg => { console.error('\nSTOP: ' + msg); process.exit(1); };

const API = 'https://wow.curseforge.com/api';
const projectId = () => (fs.readFileSync(TOC, 'utf8').match(/^## X-Curse-Project-ID:\s*(\d+)/m) || [])[1];

async function listGameVersions() {
  const token = process.env.CF_API_TOKEN;
  if (!token) die('set CF_API_TOKEN first (CurseForge: your account > API tokens).');
  const res = await fetch(API + '/game/versions', { headers: { 'X-Api-Token': token } });
  if (!res.ok) die('CurseForge answered ' + res.status + ' ' + (await res.text()).slice(0, 200));
  const list = await res.json();
  for (const v of list) console.log(v.id + '\t' + v.name + '\t(type ' + v.gameVersionTypeID + ')');
}

async function upload(zip, version, notes) {
  const token = process.env.CF_API_TOKEN;
  const gv = (value('--game-version') || process.env.CF_GAME_VERSION || '').split(',').filter(Boolean).map(Number);
  const id = projectId();
  if (!token) die('--upload needs CF_API_TOKEN in the environment.');
  if (!gv.length) die('--upload needs the game version id: --game-version <id> (find it with --list-game-versions).');
  if (!id) die('no X-Curse-Project-ID in Skald.toc.');
  const metadata = { changelog: notes, changelogType: 'markdown', displayName: 'Skald ' + version,
    gameVersions: gv, releaseType: /-alpha/.test(version) ? 'alpha' : /-beta/.test(version) ? 'beta' : 'release' };
  const form = new FormData();
  form.append('metadata', JSON.stringify(metadata));
  form.append('file', new Blob([fs.readFileSync(zip)]), path.basename(zip));
  console.log('Uploading to CurseForge project ' + id + ' ...');
  const res = await fetch(`${API}/projects/${id}/upload-file`, { method: 'POST', headers: { 'X-Api-Token': token }, body: form });
  const text = await res.text();
  if (!res.ok) die('CurseForge answered ' + res.status + ': ' + text.slice(0, 300));
  console.log('Uploaded: ' + text);
}

(async () => {
  if (flag('--list-game-versions')) return listGameVersions();

  const version = args.find(a => /^\d+\.\d+\.\d+(-(alpha|beta))?$/.test(a));
  if (!version) die('give the version, e.g.  node tools/release.js 0.31.2-beta');

  console.log(`\n== Skald ${version} ==\n`);
  console.log('1. Checks');
  const checks = spawnSync(process.execPath, [path.join(__dirname, 'checks.js')], { stdio: 'inherit' });
  if (checks.status !== 0) die('the checks failed; nothing was changed.');

  console.log('\n2. Notes');
  const notesFile = value('--notes') || path.join(ROOT, 'NEXT_CHANGELOG.md');
  if (!fs.existsSync(notesFile)) die(`no notes: write the bullet points of this version in ${notesFile}`);
  const notes = fs.readFileSync(notesFile, 'utf8').trim();
  if (!notes) die(notesFile + ' is empty.');
  console.log(notes.split('\n').length + ' line(s) from ' + path.basename(notesFile));

  console.log('\n3. Version in Skald.toc');
  let toc = fs.readFileSync(TOC, 'utf8');
  toc = toc.replace(/^## Version:.*$/m, '## Version: ' + version);
  fs.writeFileSync(TOC, toc);

  console.log('4. Changelog');
  const entry = `## ${version}\n\n${notes}\n`;
  const changelog = path.join(ROOT, 'CHANGELOG.md');
  let all = fs.readFileSync(changelog, 'utf8');
  if (!all.includes('## ' + version)) {
    all = all.replace(/^# Changelog\s*\n+/, '# Changelog\n\n' + entry + '\n');
    fs.writeFileSync(changelog, all);
  }
  const paste = path.join(ROOT, `CHANGELOG_${version}_para-colar.md`);
  fs.writeFileSync(paste, entry);

  console.log('5. Repository folder (skald-repo)');
  const repo = path.join(ROOT, 'skald-repo');
  fs.mkdirSync(repo, { recursive: true });
  fs.cpSync(path.join(ADDONS, 'Skald'), repo, { recursive: true, force: true });
  for (const f of ['README.md', 'CHANGELOG.md']) fs.copyFileSync(path.join(ROOT, f), path.join(repo, f));

  console.log('6. Zip');
  const zip = path.join(ROOT, `Skald-${version}.zip`);
  if (fs.existsSync(zip)) fs.rmSync(zip);
  const tar = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe');
  const built = spawnSync(fs.existsSync(tar) ? tar : 'tar', ['-a', '-cf', zip, 'Skald'], { cwd: ADDONS, encoding: 'utf8' });
  if (built.status !== 0) die('could not build the zip: ' + (built.stderr || ''));
  const list = spawnSync(fs.existsSync(tar) ? tar : 'tar', ['-tf', zip], { encoding: 'utf8' }).stdout.split(/\r?\n/).filter(Boolean);
  const raw = list.filter(n => !n.endsWith('/')).reduce((sum, n) => {
    try { return sum + fs.statSync(path.join(ADDONS, n)).size; } catch { return sum; }
  }, 0);
  const size = fs.statSync(zip).size;
  if (size > raw * 0.9) die(`the zip is not compressed (${size} bytes for ${raw} of files): use Windows' tar.exe.`);
  if (!list.some(n => n === 'Skald/Skald.toc')) die('the zip has no Skald/Skald.toc.');
  console.log(`${path.basename(zip)}: ${list.length} entries, ${(size / 1048576).toFixed(2)} MB`);

  if (flag('--upload')) await upload(zip, version, notes);

  console.log('\nDone. To publish: upload ' + zip);
  console.log('\n----- changelog to paste -----\n' + entry + '------------------------------\n');
  console.log('Then clear ' + path.basename(notesFile) + ' for the next version.');
})();
