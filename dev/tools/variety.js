// How often a phrase comes back in a long journey (a measure, not a test): the diary is run in the simulated game, a
// long climb is written page by page (quests, deaths, levels, bosses) and, for each kind, the lines told are counted.
//
//   node dev/tools/variety.js [race] [class] [tone]       e.g.  node dev/tools/variety.js Orc WARRIOR kin
//
// It prints, for each kind: pages, distinct lines, the line told most often, and the mean number of pages of that
// kind between two tellings of the same line (the higher, the better the diary reads). Not part of checks.js.
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');

const ADDONS = path.resolve(__dirname, '../../..');
const [, , race = 'Orc', cls = 'WARRIOR', tone = 'kin', locale = 'enUS'] = process.argv;

// The scenario runner of regressions.js, taken from its own source so the simulated game is the same one.
const src = fs.readFileSync(path.join(__dirname, 'regressions.js'), 'utf8');
const start = src.indexOf('const FILES');
const end = src.indexOf('const SAVED');
const runner = src.slice(start, end)
  .replace(/if \(res === 'ok'\)[^\n]*\n[^\n]*\n/, 'console.log(res);\n');
const run = new Function('lua', 'lauxlib', 'lualib', 'to_luastring', 'to_jsstring', 'fs', 'path', 'ADDONS', '__dirname',
  runner + '\nreturn run;')(lua, lauxlib, lualib, to_luastring, to_jsstring, fs, path, ADDONS, __dirname);

// A climb of sixty levels: about 700 quests (most of them small), 100 falls, 60 levels, 150 fights with a boss.
const body = `
SkaldDB.tone = "${tone}"; __locale = "${locale}"
local P = ns.LOCALES.${locale}.phrases
local function told(e) local pool = SkaldAPI.PoolFor(e); local ph = pool and pool[e.idx]; return ph end
local report = {}
local function Measure(kind, n, make)
  local counts, last, gaps, gapN, pages, order = {}, {}, 0, 0, 0, {}
  for i = 1, n do
    make(i)
    local e = SkaldCharDB.entries[#SkaldCharDB.entries]
    if e and e.kind == kind then
      local ph = told(e)
      if ph then
        pages = pages + 1
        counts[ph] = (counts[ph] or 0) + 1
        if last[ph] then gaps = gaps + (pages - last[ph]); gapN = gapN + 1 end
        last[ph] = pages
      end
    end
  end
  local distinct, top, topPh = 0, 0, nil
  for ph, c in pairs(counts) do distinct = distinct + 1; if c > top then top = c; topPh = ph end end
  report[#report + 1] = string.format("%-8s pages %4d | distinct %3d | top line %3d times (%4.1f%%) | mean gap between repeats %5.1f pages", kind, pages, distinct, top, pages > 0 and 100 * top / pages or 0, gapN > 0 and gaps / gapN or 0)
  if os.getenv and os.getenv("VARIETY_TOP") then
    local list = {}
    for ph, c in pairs(counts) do list[#list + 1] = { ph, c } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(4, #list) do report[#report + 1] = string.format("    %3d  %s", list[i][2], list[i][1]:sub(1, 90)) end
  end
  return counts
end
local zone = "Somewhere"
local QT = { "fight", "gather", "explore", "seek", "delivery" }
local qi = 0
Measure("quest", 700, function(i)
  qi = qi + 1
  local r = math.random()
  local tier = r < 0.78 and 1 or r < 0.9 and 2 or r < 0.96 and 3 or r < 0.99 and 4 or 5
  SkaldAPI.AddEntry("quest", "Quest " .. qi, zone, { tier = tier, q = 90000 + qi, qtype = QT[math.random(#QT)], ql = 10, pl = 10 })
end)
Measure("death", 100, function(i) SkaldAPI.AddEntry("death", zone) end)
Measure("level", 60, function(i) SkaldAPI.AddEntry("level", i + 1) end)
Measure("boss", 150, function(i)
  local r = math.random()   -- most bosses fall at the first try; some after one fall, a few after many
  local tries
  if r >= 0.85 then tries = (r < 0.95 and 1) or (r < 0.99 and 2) or 4 end
  SkaldAPI.AddEntry("boss", "Boss " .. i, zone, { tries = tries, tier = 2 + (i % 3) })
end)
RES = table.concat(report, "\\n")
`;
console.log(`race ${race} | class ${cls} | voice ${tone} | ${locale}`);
run('variety', {
  pre: `function UnitRace() return "${race}", "${race}", 2 end
function UnitClass() return "Class", "${cls}" end
function UnitLevel() return 30 end`,
  body,
});
