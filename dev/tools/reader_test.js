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
if (made.status !== 0) { fail('the game produced the Reader text: ' + (made.stderr || made.stdout)); process.exit(1); }
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
check(model.counts.quest === 3 && model.tiers[3] === 1 && model.goals === 1 && model.first === 1792000000 && model.played === 3700, 'the summary lines are read');
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

console.log(failed ? `\n${failed} reader check(s) FAILED` : '\nAll reader checks passed');
process.exit(failed ? 1 : 0);
