// Checks before a release. Run: node tools/checks.js   (exit code 1 when something fails)
//  1. every Lua file compiles;  2. every phrase pool is valid in every language;
//  3. a simulated login: the book opens, every tab exists, the layout audit finds nothing,
//     a hunter's pet and the hearthstone write their pages.
// None of this is the real game: it runs the files in a Lua 5.3 interpreter with a mock of the
// game's interface, so a passing run means "no obvious error", not "works in the client".
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ADDONS = path.resolve(__dirname, '../../..');
let failed = 0;
const fail = msg => { failed++; console.log('  FAIL  ' + msg); };
const ok = msg => console.log('  ok    ' + msg);

// 1. syntax
console.log('Syntax');
for (const f of ['Skald/Locales.lua', 'Skald/Curated.lua', 'Skald/XPTiers.lua', 'Skald/Skald.lua', 'Skald/Atlas.lua', 'Skald/Goals.lua', 'Skald/Saga.lua', 'Skald/ZoneCard.lua', 'Skald/Backup.lua', 'Skald/Search.lua', 'Skald/Bard.lua'].concat(fs.existsSync(path.join(ADDONS, 'SkaldAtlas')) ? ['SkaldAtlas/SkaldAtlas.lua'] : [])) {
  const installed = path.join(ADDONS, f);
  const p = f === 'SkaldAtlas/SkaldAtlas.lua' && !fs.existsSync(installed)
    ? path.resolve(__dirname, '../skald-atlas-repo/SkaldAtlas.lua') : installed;
  if (!fs.existsSync(p)) { fail(f + ' is missing'); continue; }
  const L = lauxlib.luaL_newstate();
  const r = lauxlib.luaL_loadbuffer(L, to_luastring(fs.readFileSync(p, 'utf8')), null, to_luastring(f));
  if (r === 0) ok(f); else fail(f + ': ' + to_jsstring(lua.lua_tolstring(L, -1)));
}

// no stray control characters in the Lua files (an escape lost on the way, such as a backslash-1 becoming a byte)
for (const f of fs.readdirSync(path.join(ADDONS, 'Skald')).filter(n => n.endsWith('.lua'))) {
  const text = fs.readFileSync(path.join(ADDONS, 'Skald', f), 'utf8');
  let bad = 0;
  for (const c of text) { const k = c.charCodeAt(0); if (k < 32 && k !== 10 && k !== 13 && k !== 9) bad++; }
  if (bad) fail(f + ' has ' + bad + ' control character(s): an escape was lost'); else ok(f + ': no stray control characters');
}

// every texture the .toc-listed files name must exist
console.log('Textures');
{
  const tex = new Set(['Textures', 'Textures/skald2'].flatMap(d => fs.readdirSync(path.join(ADDONS, 'Skald', d)).filter(f => f.endsWith('.tga')).map(f => f.replace(/\.tga$/, ''))));
  const src = fs.readFileSync(path.join(ADDONS, 'Skald/Skald.lua'), 'utf8') + fs.readFileSync(path.join(ADDONS, 'Skald/Atlas.lua'), 'utf8') + fs.readFileSync(path.join(ADDONS, 'Skald/Goals.lua'), 'utf8') + fs.readFileSync(path.join(ADDONS, 'Skald/Saga.lua'), 'utf8') + fs.readFileSync(path.join(ADDONS, 'Skald/ZoneCard.lua'), 'utf8');
  const wanted = new Set();
  for (const m of src.matchAll(/"((?:it|ev|st|pf|ui|ghost|goal|rd)_[a-z_0-9]+)"/g)) wanted.add(m[1]);
  for (const m of src.matchAll(/"(goal_medal)" \.\./g)) { wanted.delete('goal_medal'); for (let i = 0; i <= 5; i++) wanted.add('goal_medal' + i); }
  for (const m of src.matchAll(/"(pin_med)" \.\./g)) for (let i = 0; i <= 5; i++) wanted.add('pin_med' + i);
  const ev = (src.match(/local EVENT_ICON = \{([\s\S]*?)\n\}/) || [])[1] || '';
  for (const m of ev.matchAll(/= "([a-z_]+)"/g)) wanted.add(m[1].startsWith('st_') ? m[1] : 'ev_' + m[1]);
  if (wanted.has('ui_seal')) { wanted.delete('ui_seal'); for (let i = 0; i <= 5; i++) wanted.add('ui_seal' + i); }
  const missing = [...wanted].filter(n => !tex.has(n) && n !== 'pf_' && n !== 'ev_');
  if (missing.length) fail('missing textures: ' + missing.join(', ')); else ok(wanted.size + ' named textures exist');
}

// 1b. lint: leaks, the 200-local limit, new global names
console.log('Lint');
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'lint.js')], { encoding: 'utf8' });
  if (r.status === 0) ok('no global leaks, no new global names, locals under the limit'); else { fail('lint'); console.log(r.stdout); }
}

// 2. phrases
console.log('Phrases');
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'validate_phrases.js')], { encoding: 'utf8' });
  const lines = (r.stdout || '').split('\n').filter(l => /phrase problems|combat words/.test(l));
  if (r.status === 0) ok('all languages: ' + lines.length + ' checks clean'); else { fail('phrase validation'); console.log(r.stdout); }
}

// 3. simulated session
console.log('Simulated session');
function session(locale) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const run = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
  const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
  run(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'));
  for (const [k, f] of [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua'], ['ZC', 'ZoneCard.lua'], ['BK', 'Backup.lua'], ['SR', 'Search.lua'], ['BD', 'Bard.lua']])
    set(k, fs.readFileSync(path.join(ADDONS, 'Skald', f), 'utf8'));
  run(`__locale="${locale}"; frames={}; SkaldDB={}; SkaldCharDB=nil; FONTS={}
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
local function runTimers() local t=TIMERS TIMERS={} for _,fn in ipairs(t) do fn() end end
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 100000 end; function UnitXP() return 0 end
MYLVL=8; PETLVL=5
function UnitLevel(u) if u=="pet" then return PETLVL end return MYLVL end
PETNAME="Rex"
function UnitName(u) if u=="pet" then return PETNAME end return "Tester" end
function UnitExists(u) return u=="pet" end
function UnitCreatureFamily() return "Wolf" end
function GetQuestID() return 0 end; function UnitGUID() return "P1" end
function UnitClass() return "Hunter","HUNTER" end; function UnitRace() return "Night Elf","NightElf" end
function SetPortraitTexture() end
function GetPetFoodTypes() return "Meat","Fish" end
function GetZoneText() return "Elwynn Forest" end
function GetBindLocation() return "Anvilmar" end
NOW = os.time({year=2026,month=10,day=20,hour=10,min=0,sec=0}); function time(t) if t then return os.time(t) end return NOW end
function GetStatisticsCategoryList() return {} end
function GetStatistic(id) return "--" end
function GetMoney() return 0 end
Minimap=CreateFrame("Frame","Minimap",UIParent); function GetCursorPosition() return 100,100 end
local ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns)
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns); assert(load(ZC,"=Z"))("Skald",ns); assert(load(BK,"=B"))("Skald",ns); assert(load(SR,"=R"))("Skald",ns); assert(load(BD,"=D"))("Skald",ns)
local function fire(ev,...) for _,f in ipairs(frames) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN"); runTimers()
local out={}
local function btn(label) for i=#frames,1,-1 do local f=frames[i]; local tx=rawget(f,"text"); if tx and rawget(tx,"_text")==label and f._OnClick then return f end end end
local win=_G.SkaldFrame; win:Show(); if win._OnShow then win._OnShow(win) end
out.book = win ~= nil
local settingsBtn = btn(ns.LOCALES["${locale}"].TAB_SETTINGS)
out.tabStyle = settingsBtn ~= nil and select(1, pcall(settingsBtn._OnClick, settingsBtn))
local mapLabel = ({enUS="Map",ptBR="Mapa",frFR="Carte"})["${locale}"]
out.tabJourney = false
for _, f in ipairs(frames) do local subs = rawget(f, "subs"); if type(subs) == "table" and #subs == 3 then out.tabJourney = true end end
local mapBtn = btn(mapLabel)
out.tabMap = mapBtn ~= nil and select(1, pcall(mapBtn._OnClick, mapBtn))
out.minimap = ns.minimapButton ~= nil
local pb = btn(ns.LOCALES["${locale}"].TAB_PETS)
out.tabPets = pb ~= nil and select(1, pcall(pb._OnClick, pb)) or false
local dietSeen = false
for _, fs in ipairs(FONTS) do local t = rawget(fs, "_text"); if t and tostring(t):find("Meat, Fish", 1, true) then dietSeen = true end end
local okqa, issues = pcall(win.QA, win)
out.qa = okqa and type(issues)=="table" and #issues or -1
local function count(k) local n=0 for _,e in ipairs(SkaldCharDB.entries) do if e.kind==k then n=n+1 end end return n end
fire("UNIT_PET","player"); runTimers()
out.pet = count("tame")
PETNAME = "Rexy"; fire("UNIT_NAME_UPDATE", "pet"); runTimers()
local renamedOk = SkaldCharDB.pets["Rexy"] ~= nil and SkaldCharDB.pets["Rex"] == nil and count("tame") == out.pet
out.diet = dietSeen and renamedOk and (pcall(SlashCmdList.SKALD, "petinfo"))
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",8690)
out.hearth = count("hearth")
fire("CONFIRM_XP_LOSS"); fire("PLAYER_UNGHOST")
out.revive = count("revive")
local texts={}
for _,e in ipairs(SkaldCharDB.entries) do if e.kind=="tame" or e.kind=="hearth" or e.kind=="revive" then texts[#texts+1]=SkaldAPI.Render(e) end end
out.texts=#texts
RES=string.format("%s|%s|%s|%d|%d|%d|%d|%d|%s|%s|%s", tostring(out.book), tostring(out.tabStyle), tostring(out.tabMap), out.qa, out.pet, out.hearth, out.revive, out.texts, tostring(out.tabJourney), tostring(out.minimap), tostring(out.tabPets and out.diet))`);
  lua.lua_getglobal(L, to_luastring('RES'));
  return to_jsstring(lua.lua_tolstring(L, -1)).split('|');
}
for (const loc of ['enUS', 'ptBR', 'frFR']) {
  try {
    const [book, style, mapTab, qa, pet, hearth, revive, texts, journey, minimap, petsTab] = session(loc);
    const problems = [];
    if (book !== 'true') problems.push('the book did not open');
    if (style !== 'true') problems.push('no Settings tab');
    if (journey !== 'true') problems.push('the Settings tab does not hold its three pages');
    if (mapTab !== 'true') problems.push('no Map tab (the map pins built into Skald)');
    if (petsTab !== 'true') problems.push('no Pets tab for a hunter, or the diet does not show, or a renamed pet is not followed');
    if (minimap !== 'true') problems.push('no minimap button of its own');
    if (qa !== '0') problems.push('layout audit: ' + qa + ' issue(s)');
    if (pet !== '1') problems.push('pet page: ' + pet);
    if (hearth !== '1') problems.push('hearthstone page: ' + hearth);
    if (revive !== '1') problems.push('revive page: ' + revive);
    if (problems.length) fail(loc + ': ' + problems.join('; ')); else ok(loc + ': book, tabs, layout audit, pet, hearthstone, revive');
  } catch (e) { fail(loc + ': ' + e.message); }
}

// 3b. regressions: things that went wrong once
console.log('Regressions');
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'regressions.js')], { encoding: 'utf8' });
  const lines = (r.stdout || '').split(/\r?\n/).filter(l => /^ {2}(ok|FAIL)/.test(l));
  for (const l of lines) console.log(l);
  if (r.status !== 0) failed++;
}

// the web Reader reads back what the game writes for it
console.log('Reader');
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'reader_test.js')], { encoding: 'utf8' });
  const lines = (r.stdout || '').split(/\r?\n/).filter(l => /^ {2}(ok|FAIL)/.test(l));
  for (const l of lines) console.log(l);
  if (r.status !== 0) failed++;
}

// 4. speed: a diary of 3000 pages must still turn pages quickly (numbers are fengari's, slower than the game)
console.log('Speed');
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'perf.js')], { encoding: 'utf8' });
  const ms = label => {
    const line = (r.stdout || '').split('\n').find(l => l.startsWith(label));
    const m = line && line.match(/([0-9.]+) ms/);
    return m ? Number(m[1]) : NaN;
  };
  const turn = ms('Refresh() with 3000 pages'), first = ms('show the book (cover)');
  if (!(turn < 60)) fail('turning a page takes ' + turn + ' ms (limit 60): the layout is probably no longer cached');
  else if (!(first < 2500)) fail('opening the book takes ' + first + ' ms (limit 2500)');
  else if (!(ms('map markers (3000 pages, one map)') < 400)) fail('the map markers of 3000 pages take ' + ms('map markers (3000 pages, one map)') + ' ms (limit 400)');
  else if (!(ms('saga (3000 pages)') < 100)) fail('the Saga takes ' + ms('saga (3000 pages)') + ' ms (limit 100): it is built when its tab opens');
  else if (!(ms('goals check, nothing new (3000)') < 100)) fail('the check of the goals takes ' + ms('goals check, nothing new (3000)') + ' ms (limit 100): it runs after every change of the pages');
  else if (!(ms('export plain, names hidden (3000)') < 3000)) fail('exporting 3000 pages with the names hidden takes ' + ms('export plain, names hidden (3000)') + ' ms (limit 3000)');
  else if (!(ms('text for the Reader (3000 pages)') < 5000)) fail('the text for the Reader takes ' + ms('text for the Reader (3000 pages)') + ' ms (limit 5000)');
  else if (!((m => m && Number(m[1]) < 4096)((r.stdout || '').match(/saved file \(3000\) (\d+) KB/)))) fail('the saved file of 3000 pages is over 4 MB: ' + ((r.stdout || '').match(/saved file \(3000\) (\d+) KB/) || [])[1] + ' KB')
  else ok('3000 pages: open ' + first.toFixed(0) + ' ms, turn a page ' + turn.toFixed(1) + ' ms, map markers ' + ms('map markers (3000 pages, one map)').toFixed(0) + ' ms, goals ' + ms('goals check, nothing new (3000)').toFixed(0) + ' ms, Saga ' + ms('saga (3000 pages)').toFixed(0) + ' ms, export ' + ms('export plain, names hidden (3000)').toFixed(0) + ' ms, Reader text ' + ms('text for the Reader (3000 pages)').toFixed(0) + ' ms');
}

console.log(failed ? `\n${failed} check(s) FAILED` : '\nAll checks passed');
process.exit(failed ? 1 : 0);
