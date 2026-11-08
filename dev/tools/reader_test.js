// The web Reader: the text that "/skald reader" makes (in the simulated game, from a small fixture diary) must be
// read back by the page's own code, with its checksum, escapes and pages. Prints "  ok" / "  FAIL" lines.
// Run: node tools/reader_test.js   (also run by checks.js)
const fs = require('fs');
const os = require('os');
const path = require('path');
const vm = require('vm');
const { spawnSync } = require('child_process');

let failed = 0;
const ok = m => console.log('  ok    ' + m);
const fail = m => { failed++; console.log('  FAIL  ' + m); };
const check = (cond, m, detail) => (cond ? ok(m) : fail(m + (detail ? ': ' + detail : '')));

const out = path.join(os.tmpdir(), 'skald_reader_fixture.txt');
const made = spawnSync(process.execPath, [path.join(__dirname, 'reader_sample.js'), path.join(__dirname, 'fixtures/reader_saved.lua'), out, 'enUS'], { encoding: 'utf8' });
if (require('./check_helpers').toolFailure(made, /written/)) { fail('the game produced the Reader text: ' + (made.stderr || made.stdout)); process.exit(1); }
const text = fs.readFileSync(out, 'utf8');

// the page's code, with just enough of a browser around it
const sandbox = { window: {}, navigator: { language: 'en-US' }, document: { readyState: 'loading', addEventListener() {}, documentElement: {} }, TextEncoder, console, getComputedStyle: () => ({}) };
sandbox.window = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.resolve(__dirname, '../../docs/reader/reader.js'), 'utf8'), sandbox);
const R = sandbox.SkaldReader;

const parts = R.readParts(text);
check(parts.length === 1 && parts[0].valid, 'the text of the game is one part and its checksum matches', JSON.stringify(parts.map(p => [p.index, p.count, p.valid])));
const model = R.build(parts);
check(model.name === 'Tester' && model.total === model.pages.length, 'the header carries the name and the number of pages');
check(model.counts.quest === 3 && model.tiers[3] === 1 && model.goals >= 1 && model.points > 0 && model.first === 1792000000 && model.played === 3700, 'the summary lines are read');
check(model.saga.length >= 3 && model.saga.every(c => c.key && c.title && c.text) && !/[{}]/.test(model.saga.map(c => c.text).join(' ')), 'the Saga chapters are read, with their paragraphs', JSON.stringify(model.saga.map(c => c.key)));
const note = model.pages.find(p => p.kind === 'note');
check(note && note.text === 'a caret ^ and a line\nbreak, with \\ a backslash' && note.note === 'my note ^ with a caret' && note.fav, 'a caret, a line break and a backslash survive the trip', JSON.stringify(note));
check(model.pages.length >= 5 && model.pages.every((p, i, a) => i === 0 || a[i - 1].t <= p.t), 'the pages come in time order', String(model.pages.length));

// a copy that stopped half-way, or was touched, is told apart
const cut = R.readParts(text.slice(0, text.length - 12));
check(cut.length === 1 && !cut[0].valid, 'a copy that was cut short is not valid');
const touched = R.readParts(text.replace('Elwynn', 'Elwynx'));
check(touched.length === 1 && !touched[0].valid, 'a copy that was changed is not valid');
// Windows line ends from the clipboard are fine
check(R.readParts(text.replace(/\n/g, '\r\n'))[0].valid, 'line ends of Windows do not break the checksum');
// two parts pasted together are separated
const twice = R.readParts(text + '\n' + text);
check(twice.length === 2 && twice.every(p => p.valid), 'two parts pasted in one go are separated');

// Chapter illustrations are part of the export, and older diaries still get appropriate art.
check(model.saga.every(c => /^ui_saga_(camp_alliance|camp_horde|walker|scroll|war|falls|company|seals|epilogue)$/.test(c.art)), 'the game exports its own Saga chapter illustrations');
check(R.sagaArtFor({ key: 'prologue', art: 'ui_saga_camp_horde' }, { race: 'Night Elf' }) === 'ui_saga_camp_horde', 'explicit chapter art preserves the exported faction');
check(R.sagaArtFor({ key: 'prologue' }, { race: 'Elfo Noturno' }) === 'ui_saga_camp_alliance' && R.sagaArtFor({ key: 'prologue' }, { race: 'Mort-vivant' }) === 'ui_saga_camp_horde', 'legacy chapters infer known factions from localized races');
check(R.sagaArtFor({ key: 'prologue' }, { race: 'Unknown' }) === 'ui_saga_walker', 'unknown legacy races use a neutral illustration');
check(R.sagaArtFor({ key: 'epilogue', art: '../../external' }, {}) === 'ui_saga_epilogue' && R.sagaArtFor({ key: 'unknown', art: 'https://example.com/image.png' }, {}) === null, 'only bundled Saga artwork can be selected');

// New metadata is optional; the same parser still reads exports made before it existed.
check(model.prefs.paper === 'clean' && model.prefs.textSize === '1' && ['forever', 'classic', 'tbc'].includes(model.era), 'the current game exports reading preferences and the client edition');
check(Object.keys(model.days).length >= 2 && model.pages.every(p => p.day && model.days[p.day] && model.days[p.day].title), 'entries carry the actual day groups and their localized titles');
const legacyBody = parts[0].body.split('\n').filter(l => !/^[MD]\^/.test(l)).map(l => l.startsWith('P^') ? l.split('^').slice(0, 10).join('^') : l).join('\n');
function encodePart(body, index = 1, count = 1, snapshot = '', total = model.total) {
  return ['H', 'SKALDREADER1', 'Tester', 'Mage', 'Night Elf', '20', 'epic', 'enUS', total, index, count, R.checksum(body)].concat(snapshot ? [snapshot] : []).join('^') + '\n' + body;
}
const legacy = R.build(R.readParts(encodePart(legacyBody)));
check(legacy.pages.length === model.pages.length && Object.keys(legacy.days).length === 0 && legacy.era === 'forever', 'legacy exports open with the original defaults');
check(R.build(twice).pages.length === model.pages.length, 'pasting the same export twice does not duplicate entries');
const lines = legacyBody.split('\n'), half = Math.floor(lines.length / 2);
const bodies = [lines.slice(0, half).join('\n'), lines.slice(half).join('\n')];
const snap = String(R.checksum(bodies.join('\n')));
const multi = bodies.map((b, i) => encodePart(b, i + 1, 2, snap));
check(R.build(R.readParts(multi[1] + '\n' + multi[0])).pages.length === model.pages.length, 'multipart exports are assembled in order');
check(R.collectParts(R.readParts(multi[0])).state === 'incomplete', 'a missing part keeps the book closed');
const different = bodies[1].replace('Darkshore', 'Elsewhere');
const conflict = R.readParts(multi.join('\n') + '\n' + encodePart(different, 2, 2, snap));
check(R.collectParts(conflict).state === 'mixed', 'conflicting copies of the same part are rejected');
check(R.collectParts(R.readParts(multi[0] + '\n' + encodePart(bodies[1], 2, 2, '123'))).state === 'mixed', 'parts from different snapshots are rejected');
let rejectsSnapshot = false, rejectsTotal = false;
try { R.build(R.readParts(multi[0] + '\n' + encodePart(different, 2, 2, snap))); } catch (e) { rejectsSnapshot = true; }
try { R.build(R.readParts(encodePart(legacyBody, 1, 1, '', 999))); } catch (e) { rejectsTotal = true; }
check(rejectsSnapshot && rejectsTotal, 'whole-export checksum and entry count prevent incomplete books');
check(!R.readParts(encodePart(legacyBody).replace('^1^1^', '^1^NaN^'))[0].valid, 'malformed part counts are invalid');
['forever', 'tbc', 'classic'].forEach(era => check(R.lookupUrl({ kind: 'quest', info: { q: '77' } }, era) === 'https://www.wowhead.com/' + era + '/quest=77', 'quest links use the ' + era + ' edition'));
check(R.lookupUrl({ kind: 'loot', info: { iid: '2000' } }, 'tbc') === 'https://www.wowhead.com/tbc/item=2000' && R.lookupUrl({ kind: 'quest', info: { q: 'javascript:bad' } }, 'tbc') === null, 'item links follow the edition and invalid IDs cannot become links');

// Exercise the Lua exporter with nondefault styles, sessions and long saved notes.
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'skald-reader-'));
try {
  for (const [era, toc] of [['tbc', 20506], ['forever', 16001]]) {
    const saved = path.join(temp, era + '.lua'), output = path.join(temp, era + '.txt');
    const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/reader_saved.lua'), 'utf8') + `
SkaldDB = { paperStyle = "travel", ink = 2, textSize = 2, density = "airy", dayMode = 1, coverTitle = "My road" }
function GetBuildInfo() return "test", "1", "today", ${toc} end
SkaldCharDB.entries[1].ses = 11
SkaldCharDB.entries[2].ses = 22
SkaldCharDB.entries[2].arg = string.rep("long note ", 120) .. "END"
SkaldCharDB.entries[2].favNote = string.rep("margin ", 60) .. "END"
`;
    fs.writeFileSync(saved, fixture);
    const made = spawnSync(process.execPath, [path.join(__dirname, 'reader_sample.js'), saved, output, 'enUS'], { encoding: 'utf8' });
    const error = require('./check_helpers').toolFailure(made, /written/);
    check(!error, era + ' export fixture runs', error || made.stderr);
    if (error) continue;
    const m = R.build(R.readParts(fs.readFileSync(output, 'utf8')));
    check(m.era === era && m.prefs.paper === 'travel' && m.prefs.ink === '2' && m.prefs.textSize === '2' && m.prefs.density === 'airy' && m.prefs.coverTitle === 'My road', era + ' edition and visual preferences survive the actual exporter');
    const n = m.pages.find(p => p.kind === 'note');
    check(n.text === 'long note '.repeat(120) + 'END' && n.note === 'margin '.repeat(60) + 'END', era + ' notes are exported in full beyond the old character limits');
    const z = m.pages.find(p => p.kind === 'zone' && p.place === 'Elwynn Forest');
    check(n.day !== z.day && n.day.endsWith('@22') && z.day.endsWith('@11') && m.days[n.day].date === m.days[z.day].date, era + ' keeps two sessions on the same calendar date separate');
  }
} finally { fs.rmSync(temp, { recursive: true, force: true }); }

console.log(failed ? `\n${failed} reader check(s) FAILED` : '\nAll reader checks passed');
process.exit(failed ? 1 : 0);
