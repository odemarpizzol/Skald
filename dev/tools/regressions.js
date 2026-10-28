// Regression scenarios: things that went wrong once (or nearly), each run in a fresh simulated game.
// Run: node tools/regressions.js   (also run by checks.js; exit code 1 when one fails)
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');

const ADDONS = path.resolve(__dirname, '../../..');
const FILES = [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua'], ['ZC', 'ZoneCard.lua'], ['BK', 'Backup.lua'], ['SR', 'Search.lua'], ['BD', 'Bard.lua']];
let failed = 0;

// The game, as far as the addon can tell. `pre` runs before the addon loads (saved data, game answers);
// `body` runs after the login and must leave "ok" or a message in RES.
function run(name, { pre = '', body }) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const exec = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
  const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
  try {
    exec(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'));
    for (const [k, f] of FILES) set(k, fs.readFileSync(path.join(ADDONS, 'Skald', f), 'utf8'));
    exec(`__locale="enUS"; frames={}; SkaldDB={}; SkaldCharDB=nil; FONTS={}
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
function runTimers() local t=TIMERS TIMERS={} for _,fn in ipairs(t) do fn() end end
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 100000 end; function UnitXP() return 0 end
function UnitLevel() return 20 end; function UnitName() return "Tester" end; function UnitExists() return false end
function GetQuestID() return 0 end; function UnitGUID() return "P1" end
function UnitClass() return "Hunter","HUNTER" end; function UnitRace() return "Human","Human" end
function SetPortraitTexture() end; function GetZoneText() return "Elwynn Forest" end
NOW = os.time({year=2026,month=10,day=20,hour=10,min=0,sec=0}); function time(t) if t then return os.time(t) end return NOW end
function GetStatisticsCategoryList() return {} end; function GetStatistic() return "--" end; function GetMoney() return 0 end
Minimap=CreateFrame("Frame","Minimap",UIParent); function GetCursorPosition() return 100,100 end
C_Map={GetMapInfo=function(id) if id==1439 then return {mapType=3,name="Darkshore",parentMapID=12} end if id==12 then return {mapType=2,name="Kalimdor",parentMapID=0} end end,
  GetBestMapForUnit=function() return 1439 end}
C_QuestLog={GetTitleForQuestID=function(q) if q==77 then return "Wanted: Jai'vhanel" end end}
C_Item={GetItemNameByID=function(id) if id==555 then return "Worn Hatchet" end end}
function fire(ev,...) for _,f in ipairs(frames) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
function btn(label) for i=#frames,1,-1 do local f=frames[i]; local tx=rawget(f,"text"); if tx and rawget(tx,"_text")==label and f._OnClick then return f end end end
function count(k) local n=0 for _,e in ipairs(SkaldCharDB.entries) do if e.kind==k then n=n+1 end end return n end
${pre}
ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns)
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns); assert(load(ZC,"=Z"))("Skald",ns); assert(load(BK,"=B"))("Skald",ns); assert(load(SR,"=R"))("Skald",ns); assert(load(BD,"=D"))("Skald",ns)
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN"); runTimers(); runTimers()
RES = "no result"
local okRun, err = pcall(function()
${body}
end)
if not okRun then RES = "error: " .. tostring(err) end`);
    lua.lua_getglobal(L, to_luastring('RES'));
    const res = to_jsstring(lua.lua_tolstring(L, -1));
    if (res === 'ok') console.log('  ok    ' + name);
    else { failed++; console.log('  FAIL  ' + name + ': ' + res); }
  } catch (e) { failed++; console.log('  FAIL  ' + name + ': ' + e.message); }
}

const SAVED = (entries, extra = '') => `SkaldCharDB = { entries = ${entries}, visited = {}, flags = {}, guid = "P1", ${extra} }`;

console.log('Regressions');

run('changing the language does not write the professions again', {
  pre: `${SAVED('{}', 'skills = { ["Culinária"] = 0, ["Pesca"] = 0 }, skillsInit = true')}
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) if i == 1 then return "Cooking", nil, 1, nil, nil, nil, 185 end return "Fishing", nil, 1, nil, nil, nil, 356 end`,
  body: `fire("SKILL_LINES_CHANGED"); runTimers()
RES = (count("profession") == 0 and SkaldCharDB.skills.cooking ~= nil and SkaldCharDB.skills["Culinária"] == nil) and "ok" or ("professions: " .. count("profession"))`,
});

run('old pages are told in the current language, by id', {
  pre: `${SAVED(`{
  { t = 1792000000, kind = "zone", arg = "Costa Negra", zone = "Costa Negra", m = 1439, idx = 1 },
  { t = 1792000100, kind = "loot", arg = "|cffffffff|Hitem:555::::::::15:::::|h[Machadinha Desgastada]|h|r", zone = "Costa Negra", m = false, idx = 1 },
  { t = 1792000200, kind = "quest", arg = "PROCURA-SE: Jai'vhanel", q = 77, zone = "Costa Negra", m = 1439, tier = 1, idx = 1 },
  { t = 1792000300, kind = "skill", arg = "Esfolamento 75", zone = "Costa Negra", m = 1439, idx = 1 },
}`, 'skills = { skinning = 1 }, skillsInit = true')}
function GetProfessions() return 1 end
function GetProfessionInfo() return "Skinning", nil, 80, nil, nil, nil, 393 end`,
  body: `fire("SKILL_LINES_CHANGED"); runTimers(); SlashCmdList.SKALD("tidy")
local e = SkaldCharDB.entries
local bad = {}
for i = 1, 4 do if e[i].zone ~= "Darkshore" then bad[#bad+1] = "zone " .. i .. "=" .. tostring(e[i].zone) end end
if not e[2].arg:find("Worn Hatchet", 1, true) then bad[#bad+1] = "item " .. e[2].arg end
if e[3].arg ~= "Wanted: Jai'vhanel" then bad[#bad+1] = "quest " .. e[3].arg end
if e[4].arg ~= "Skinning 75" then bad[#bad+1] = "skill " .. e[4].arg end
RES = #bad == 0 and "ok" or table.concat(bad, "; ")`,
});

run('/skald tidy removes a repeated profession or land, keeping the first', {
  pre: SAVED(`{
  { t = 1792000000, kind = "profession", arg = "Culinária", pf = "cooking", zone = "x", idx = 1 },
  { t = 1792000100, kind = "profession", arg = "Cooking", pf = "cooking", zone = "x", idx = 1 },
  { t = 1792000200, kind = "profession", arg = "Fishing", zone = "x", idx = 1 },
  { t = 1792000300, kind = "profession", arg = "Pesca", zone = "x", idx = 1 },
}`),
  body: `SlashCmdList.SKALD("tidy")
RES = count("profession") == 2 and "ok" or ("professions left: " .. count("profession"))`,
});

run('/skald forgetpet removes a companion from the list', {
  pre: SAVED('{}', 'pets = { Rex = { t = 1, fam = "Wolf", lv = 5 }, Luna = { t = 2, fam = "Cat", lv = 6 } }'),
  body: `SlashCmdList.SKALD("forgetpet rex")
RES = (SkaldCharDB.pets.Rex == nil and SkaldCharDB.pets.Luna ~= nil) and "ok" or "the pet is still there"`,
});

run('a pet on loan is not a companion', {
  pre: `function UnitExists(u) return u == "pet" end
function UnitName(u) if u == "pet" then return "Loaner" end return "Tester" end
function UnitCreatureFamily() return "Bear" end
function GetPetTimeRemaining() return 900000 end`,
  body: `fire("UNIT_PET", "player"); runTimers()
RES = (count("tame") == 0 and next(SkaldCharDB.pets or {}) == nil) and "ok" or "the loaned pet was written"`,
});

run('a renamed pet keeps its record (no second companion)', {
  pre: `PETNAME = "Rex"
function UnitLevel(u) if u == "pet" then return 5 end return 8 end
function UnitExists(u) return u == "pet" end
function UnitName(u) if u == "pet" then return PETNAME end return "Tester" end
function UnitCreatureFamily() return "Wolf" end`,
  body: `fire("UNIT_PET", "player"); runTimers()
local first = count("tame")
PETNAME = "Rexy"; fire("UNIT_NAME_UPDATE", "pet"); runTimers()
local n = 0 for _ in pairs(SkaldCharDB.pets) do n = n + 1 end
RES = (first == 1 and count("tame") == 1 and n == 1 and SkaldCharDB.pets.Rexy) and "ok" or ("pets: " .. n .. ", pages: " .. count("tame"))`,
});

run('when no pet is out the Pets tab says so', {
  pre: SAVED('{}', 'pets = { Rex = { t = 1, fam = "Wolf", lv = 5 } }, petNow = "Rex"'),
  body: `local pb = btn(ns.LOCALES.enUS.TAB_PETS)
pb._OnClick(pb)
local said = false
for _, fs in ipairs(FONTS) do if rawget(fs, "_text") == ns.LOCALES.enUS.PETS_NONE_NOW then said = true end end
RES = (said and SkaldCharDB.petNow == nil) and "ok" or "the tab still shows a pet that is gone"`,
});

run('the reminder on returning shows where the last visit ended', {
  pre: SAVED('{}', 'resume = { t = 1, zone = "Darkshore", level = 12, quests = { "A Lost Boot" }, next = "Skin the wolves" }'),
  body: `NOW = NOW + 7200
SkaldCharDB.resume.t = NOW - 7200
fire("PLAYER_LOGIN"); runTimers(); runTimers()
local card = _G.SkaldResume
local text = {}
if card then for _, p in ipairs(card.parts) do text[#text+1] = tostring(rawget(p, "_text")) end end
local all = table.concat(text, " ")
RES = (all:find("A Lost Boot", 1, true) and all:find("Skin the wolves", 1, true)) and "ok" or ("card: " .. all)`,
});

run('clicking the reminder opens the book at the newest day, not at the tab used last', {
  pre: SAVED('{}', 'resume = { t = 1, zone = "Darkshore", level = 12, quests = {}, next = "x" }'),
  body: `local pb = btn(ns.LOCALES.enUS.TAB_PETS)
pb._OnClick(pb)
local before = SkaldFrame:GetView()
NOW = NOW + 7200
SkaldCharDB.resume.t = NOW - 7200
fire("PLAYER_LOGIN"); runTimers(); runTimers()
local card = _G.SkaldResume
card._OnMouseUp(card, "LeftButton")
RES = (before ~= "book" and SkaldFrame:GetView() == "book" and SkaldFrame:IsShown()) and "ok" or ("view before: " .. tostring(before) .. ", after: " .. tostring(SkaldFrame:GetView()))`,
});

run('clicking the notice of a new page opens the book at that page', {
  pre: SAVED(`{ { t = 1792000000, kind = "level", arg = 5, zone = "Elwynn Forest", idx = 1 } }`),
  body: `local pb = btn(ns.LOCALES.enUS.TAB_PETS)
pb._OnClick(pb)
SkaldFrame:Hide()
fire("PLAYER_LEVEL_UP", 6)
local toast = _G.SkaldToast
toast._OnMouseUp(toast, "LeftButton")
RES = (toast.entry ~= nil and SkaldFrame:GetView() == "book" and SkaldFrame:IsShown()) and "ok" or ("entry " .. tostring(toast.entry) .. ", view " .. tostring(SkaldFrame:GetView()))`,
});

run('the notices stand at the top unless the player chose another place', {
  body: `ns.PreviewNotice()
local toast = _G.SkaldToast
local top = rawget(toast, "_pt") or {}
SkaldDB.toastAnchor = "left"
ns.PlaceNotice(toast, 0)
local left = rawget(toast, "_pt") or {}
SkaldDB.toastAnchor = "bottom"
ns.PlaceNotice(toast, 0)
local bottom = rawget(toast, "_pt") or {}
RES = (top[1] == "TOP" and left[1] == "LEFT" and bottom[1] == "BOTTOM") and "ok" or ("anchors: " .. tostring(top[1]) .. " " .. tostring(left[1]) .. " " .. tostring(bottom[1]))`,
});

run('the notices stand where the player put them', {
  body: `SkaldDB.toastPos = { 120, 340 }
ns.PreviewNotice()
local toast = _G.SkaldToast
local pt = rawget(toast, "_pt") or {}
RES = (pt[1] == "BOTTOMLEFT" and pt[4] == 120 and pt[5] == 340 and toast.entry.sample) and "ok" or ("anchor: " .. tostring(pt[1]) .. " " .. tostring(pt[4]) .. " " .. tostring(pt[5]))`,
});

run('the first lessons of the hunter are told as a class milestone, in each language', {
  body: `local C = ns.CURATED[6064]
local e = { kind = "quest", q = 6064, arg = "Taming the Beast", tier = C and C.tier, idx = 1, t = NOW }
local text = SkaldAPI.Render(e)
local seen, same = {}, 0
for _, id in ipairs({ 6061, 6062, 6063, 6064, 6082, 6083, 6084, 6085, 6087, 6088, 6101, 6102 }) do
  local c = ns.CURATED[id]
  if not (c and c.tier == 3 and c.text.enUS and c.text.ptBR and c.text.frFR) then same = -99 end
  if c then
    if seen[c.text.enUS] then same = same + 1 end
    seen[c.text.enUS] = true
  end
end
RES = (C and C.tier == 3 and text:find("Taming the Beast", 1, true) and same == 0) and "ok" or ("text: " .. text .. " repeated=" .. same)`,
});

run('an old page of a hand-picked quest gets the rarity picked for it', {
  pre: SAVED(`{ { t = 1792000000, kind = "quest", q = 6064, arg = "Taming the Beast", tier = 2, zone = "Dun Morogh", idx = 1 } }`),
  body: `runTimers(); runTimers()
RES = SkaldCharDB.entries[1].tier == 3 and "ok" or ("tier " .. tostring(SkaldCharDB.entries[1].tier))`,
});

run('the family on a pet page follows the record of the pet', {
  pre: SAVED(`{ { t = 1792000000, kind = "tame", arg = "Rex", fam = "Lobo", zone = "x", idx = 1 } }`, 'pets = { Rex = { t = 1, fam = "Wolf", lv = 5 } }'),
  body: `local text = SkaldAPI.Render(SkaldCharDB.entries[1])
RES = (text:find("Wolf", 1, true) and not text:find("Lobo", 1, true)) and "ok" or ("text: " .. text)`,
});

run('an old separate Skald Atlas keeps the built-in map out of the way', {
  pre: `function IsAddOnLoaded(n) return n == "SkaldAtlas" end`,
  body: `RES = (btn("Map") == nil) and "ok" or "the map tab is drawn twice"`,
});

run('the small replacement Atlas lets Skald take over', {
  pre: `function IsAddOnLoaded(n) return n == "SkaldAtlas" end
SkaldAtlasStub = true`,
  body: `RES = (btn("Map") ~= nil) and "ok" or "the map tab is missing"`,
});

run('saved positions are shortened to four decimals', {
  pre: SAVED(`{ { t = 1792000000, kind = "zone", arg = "x", zone = "x", m = 1439, x = 0.123456789012, y = 0.987654321098, idx = 1 } }`),
  body: `local e = SkaldCharDB.entries[1]
RES = (e.x == 0.1235 and e.y == 0.9877) and "ok" or ("x=" .. tostring(e.x) .. " y=" .. tostring(e.y))`,
});

const THREE_DAYS = SAVED(`{
  { t = 1792000000, kind = "quest", arg = "One", zone = "Darkshore", zm = 1439, m = 1439, x = 0.4, y = 0.4, idx = 1, tier = 1 },
  { t = 1792090000, kind = "quest", arg = "Two", zone = "Darkshore", zm = 1439, m = 1439, x = 0.5, y = 0.5, idx = 1, tier = 1 },
  { t = 1792180000, kind = "death", arg = "Darkshore", zone = "Darkshore", zm = 1439, m = 1439, x = 0.6, y = 0.6, idx = 1 },
}`);

run('a map pin can open the page of an entry in the book', {
  pre: THREE_DAYS,
  body: `local e = SkaldCharDB.entries[2]
local opened = SkaldAPI.OpenEntry(e)
local missing = SkaldAPI.OpenEntry({ kind = "zone", t = 1 })
RES = (opened == true and missing == false and SkaldFrame:IsShown()) and "ok" or ("opened: " .. tostring(opened) .. ", unknown entry: " .. tostring(missing))`,
});

run('a favourite memory keeps its note and the page tells it', {
  pre: THREE_DAYS,
  body: `local e = SkaldCharDB.entries[1]
SkaldAPI.ToggleFavorite(e)
local starred = e.fav
local fake = { editBox = { GetText = function() return "My first rare sword" end, SetText = function() end, HighlightText = function() end } }
StaticPopupDialogs.SKALD_FAVNOTE.OnAccept(fake, e)
SkaldAPI.OpenEntry(e)
local seen = false
for _, fs in ipairs(FONTS) do local t = rawget(fs, "_text"); if t and tostring(t):find("My first rare sword", 1, true) then seen = true end end
SkaldAPI.ToggleFavorite(e)
RES = (starred and e.fav == nil and e.favNote == nil and seen) and "ok" or ("starred " .. tostring(starred) .. ", note shown " .. tostring(seen) .. ", cleared " .. tostring(e.fav == nil and e.favNote == nil))`,
});

run('the map filters: this session, today, favourites only', {
  body: `local F = SkaldAPI.AtlasPure.MakeFilter
local sess = SkaldAPI.Session()
local a = { kind = "quest", tier = 1, t = NOW, ses = sess }
local b = { kind = "quest", tier = 1, t = NOW - 5 * 86400, ses = sess - 100 }
local c = { kind = "quest", tier = 1, t = NOW - 3600, ses = sess - 100, fav = true }
local all, session, today, fav = F(0, {}, "all", false), F(0, {}, "session", false), F(0, {}, "today", false), F(0, {}, "all", true)
local r = {
  all(a) and all(b) and all(c),
  session(a) and not session(b) and not session(c),
  today(a) and today(c) and not today(b),
  fav(c) and not fav(a),
}
RES = (r[1] and r[2] and r[3] and r[4]) and "ok" or ("all " .. tostring(r[1]) .. ", session " .. tostring(r[2]) .. ", today " .. tostring(r[3]) .. ", favourites " .. tostring(r[4]))`,
});

run('the Map tab says how many pages each choice of "when" holds', {
  pre: THREE_DAYS,
  body: `local mb = btn("Map")
mb._OnClick(mb)
local seen = {}
for _, fs in ipairs(FONTS) do local t = rawget(fs, "_text"); if t then seen[tostring(t)] = true end end
RES = (seen["All (3)"] and seen["This session (0)"] and seen["Today (0)"]) and "ok" or "the buttons do not show the counts"`,
});

run('the summary of a region counts what the diary holds there', {
  pre: SAVED(`{
  { t = 1792000000, kind = "quest", zone = "Darkshore", zm = 1439, idx = 1, tier = 1, arg = "a" },
  { t = 1792000100, kind = "quest", zone = "Darkshore", zm = 1439, idx = 1, tier = 1, arg = "b" },
  { t = 1792000200, kind = "death", zone = "Darkshore", zm = 1439, idx = 1, arg = "x" },
  { t = 1792000300, kind = "boss", zone = "Darkshore", zm = 1439, idx = 1, arg = "y" },
  { t = 1792000400, kind = "level", zone = "Darkshore", zm = 1439, idx = 1, arg = 12 },
  { t = 1792000500, kind = "loot", zone = "Darkshore", zm = 1439, idx = 1, arg = "z", fav = true },
  { t = 1792000600, kind = "quest", zone = "Elsewhere", zm = 999, idx = 1, tier = 1, arg = "c" },
}`),
  body: `local z = SkaldAPI.RegionStats(SkaldAPI.ZoneIdOfMap(1439))
RES = (z and z.quest == 2 and z.death == 1 and z.boss == 1 and z.level == 1 and z.loot == 1 and z.fav == 1 and z.first == 1792000000)
  and "ok" or "counts are wrong"`,
});

run('a marker that holds a favourite carries the star', {
  body: `local cl = SkaldAPI.AtlasPure.Cluster({
  { kind = "quest", tier = 1, m = 1439, x = 0.5, y = 0.5, t = 1 },
  { kind = "quest", tier = 1, m = 1439, x = 0.5, y = 0.5, t = 2, fav = true },
}, 1439, 1000, 667, function() return true end)
RES = (#cl == 1 and cl[1].fav == true and #cl[1].entries == 2) and "ok" or "the star flag is missing"`,
});

run('map markers group the same pages as comparing every marker in turn', {
  body: `local PIN = 22
local function plain(entries, w, h)
  local clusters = {}
  for _, e in ipairs(entries) do
    local home
    for _, c in ipairs(clusters) do
      local dx, dy = (c.x - e.x) * w, (c.y - e.y) * h
      if dx * dx + dy * dy < PIN * PIN then home = c break end
    end
    if home then table.insert(home.entries, e) else table.insert(clusters, { x = e.x, y = e.y, entries = { e } }) end
  end
  return clusters
end
math.randomseed(11)
local list = {}
for i = 1, 600 do list[i] = { kind = "quest", tier = 1, m = 1439, x = math.random(), y = math.random(), t = i } end
local a = SkaldAPI.AtlasPure.Cluster(list, 1439, 1000, 667, function() return true end)
local b = plain(list, 1000, 667)
local same = #a == #b
if same then for i = 1, #a do if #a[i].entries ~= #b[i].entries or a[i].entries[1] ~= b[i].entries[1] then same = false break end end end
RES = same and "ok" or ("markers: " .. #a .. " against " .. #b)`,
});

run('an event nobody listens to does nothing', {
  body: `fire("SOME_EVENT_THAT_DOES_NOT_EXIST", 1, 2, 3)
RES = "ok"`,
});

run('an event that fails is reported once and the diary carries on', {
  body: `local printed = 0
local realPrint = print
print = function(...) printed = printed + 1 end
function GetZoneText() error("boom") end
fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
print = realPrint
function GetZoneText() return "Elwynn Forest" end
fire("PLAYER_DEAD")
RES = (printed == 1 and SkaldDB.lastError ~= nil and count("death") >= 1) and "ok" or ("messages: " .. printed .. ", lastError: " .. tostring(SkaldDB.lastError) .. ", deaths: " .. count("death"))`,
});

run('/skald report lists the events seen and never seen, and the errors, without the character name', {
  body: `function GetZoneText() error("boom") end
fire("PLAYER_DEAD")
function GetZoneText() return "Elwynn Forest" end
local text = ns.BuildReport()
local ok = text:find("events seen:", 1, true) and text:find("PLAYER_DEAD=", 1, true) and text:find("events never seen:", 1, true)
  and text:find("BOSS_KILL", 1, true) and text:find("errors caught: 1", 1, true) and text:find("boom", 1, true)
  and not text:find("Tester", 1, true)
  and text:find("names player: UnitName=Aaaaaa", 1, true)
SlashCmdList["SKALD"]("report")
RES = (ok and ns.reportFrame and ns.reportFrame.edit) and "ok" or ("report: " .. text)`,
});

run('the comms probe sends on the channels that apply, keeps what came back and shows it in the report', {
  body: `local sent = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, text, channel, target) sent[#sent + 1] = channel; fire("CHAT_MSG_ADDON", prefix, text, channel, "Tester") return 0 end }
function IsInGroup() return true end; function IsInRaid() return false end; function IsInGuild() return false end
SlashCmdList["SKALD"]("probe comms Amigo")
runTimers()
local text = ns.BuildReport()
RES = (#sent == 2 and sent[1] == "WHISPER" and sent[2] == "PARTY" and #SkaldDB.commsProbe.received == 2
  and text:find("register ok true", 1, true) and text:find("received: WHISPER", 1, true)) and "ok" or ("sent " .. #sent .. " " .. text)`,
});

const DUNGEON = `function IsInInstance() return true, "party" end
function GetInstanceInfo() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end`;
const BOSSES = `local function boss(name) fire("BOSS_KILL", 1, name); runTimers() end
local function last() for i = #SkaldCharDB.entries, 1, -1 do if SkaldCharDB.entries[i].kind ~= "goal" then return SkaldCharDB.entries[i] end end end`;

run('a boss after falls in the same dungeon is told as a hard-won victory, by number', {
  pre: DUNGEON,
  body: `${BOSSES}
fire("PLAYER_DEAD"); fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
boss("Edwin VanCleef")
local e = last()
local text = SkaldAPI.Render(e)
fire("PLAYER_DEAD"); NOW = NOW + 100
boss("Rhahk'Zor")
local nxt = last()
RES = (e.kind == "boss" and e.tries == 3 and text:find("VanCleef", 1, true) and nxt.arg == "Rhahk'Zor" and nxt.tries == 1)
  and "ok" or ("tries=" .. tostring(e.tries) .. " text=" .. text .. " next=" .. tostring(nxt.tries))`,
});

run('a boss without falls, or with falls long forgotten, is told as usual', {
  pre: DUNGEON,
  body: `${BOSSES}
boss("Rhahk'Zor")
local plain = last().tries
fire("PLAYER_DEAD"); NOW = NOW + 3 * 3600
boss("Sneed's Shredder")
RES = (plain == nil and last().tries == nil) and "ok" or "a stale fall counted"`,
});

run('falls outside a dungeon do not count for a boss', {
  body: `${BOSSES}
fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end
boss("Edwin VanCleef")
RES = (last().tries == nil) and "ok" or "falls outside were counted"`,
});

run('five hard-won victories in a row do not repeat a sentence', {
  pre: DUNGEON,
  body: `${BOSSES}
local seen, same = {}, 0
for i = 1, 5 do
  fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
  boss("Boss " .. i); NOW = NOW + 60
  local t = SkaldAPI.Render(last()):gsub("Boss %d+", "B")
  if seen[t] then same = same + 1 end
  seen[t] = true
end
RES = same == 0 and "ok" or (same .. " repeated")`,
});


const CHAIN = `LibStub = function(name) if name ~= "LibQuestDB-1.0" then return nil end return { GetQuest = function(_, id)
  if id == 100 then return { questLevel = 10, nextQuestInChain = 101 } end
  if id == 101 then return { questLevel = 10, preQuestSingle = { 100 }, nextQuestInChain = 102 } end
  if id == 102 then return { questLevel = 10, preQuestSingle = { 101 } } end
end } end`;

run('the end of a chain tells how many days the story took', {
  pre: CHAIN,
  body: `fire("QUEST_ACCEPTED", 1, 100); NOW = NOW + 4 * 86400 + 600
fire("QUEST_ACCEPTED", 2, 102)
fire("QUEST_TURNED_IN", 102, 5000, 0); runTimers()
local e; for i = #SkaldCharDB.entries, 1, -1 do if SkaldCharDB.entries[i].kind == "quest" then e = SkaldCharDB.entries[i]; break end end
local text = SkaldAPI.Render(e)
RES = (e.kind == "quest" and e.since == 4 and text:find("4 days", 1, true) and not text:find("{", 1, true))
  and "ok" or ("since=" .. tostring(e.since) .. " text=" .. text)`,
});

run('a chain finished the next day says yesterday; the same day, nothing special', {
  pre: CHAIN,
  body: `fire("QUEST_ACCEPTED", 1, 100); NOW = NOW + 86400 + 60
fire("QUEST_TURNED_IN", 102, 5000, 0); runTimers()
local one; for i = #SkaldCharDB.entries, 1, -1 do if SkaldCharDB.entries[i].kind == "quest" then one = SkaldCharDB.entries[i]; break end end
local text = SkaldAPI.Render(one)
NOW = NOW + 10
SkaldCharDB.questStart = {}
fire("QUEST_ACCEPTED", 1, 100); fire("QUEST_TURNED_IN", 102, 5000, 0); runTimers()
local same; for i = #SkaldCharDB.entries, 1, -1 do if SkaldCharDB.entries[i].kind == "quest" then same = SkaldCharDB.entries[i]; break end end
RES = (one.since == 1 and text:find("esterday", 1, true) and same.since == nil) and "ok" or ("one=" .. tostring(one.since) .. " same=" .. tostring(same.since) .. " " .. text)`,
});

run('the days a chain took stay out of the saved file once old and numerous', {
  body: `for i = 1, 305 do fire("QUEST_ACCEPTED", i, 9000 + i) end
SkaldCharDB.questStart[9001] = NOW - 90 * 86400
fire("QUEST_ACCEPTED", 1, 99999)
local n = 0 for _ in pairs(SkaldCharDB.questStart) do n = n + 1 end
RES = (SkaldCharDB.questStart[9001] == nil and n <= 306) and "ok" or ("kept " .. n)`,
});


const GROUP = `function IsInGroup() return true end
function UnitExists(u) return u == "party1" end
local realName = UnitName
function UnitName(u) if u == "party1" then return "Thorgar" end return "Tester" end`;
const COMPANION = (ago, extra = '') => SAVED('{}', `companions = { Thorgar = { first = NOW - 9 * 86400, last = NOW - ${ago}, seen = NOW - ${ago}, shared = true, pn = "The Deadmines" ${extra} } }`);

run('meeting again someone from a dungeon, after a while, is told with the place', {
  pre: `${GROUP}\n${COMPANION('3 * 86400')}`,
  body: `fire("GROUP_ROSTER_UPDATE"); runTimers()
local first = count("reunion")
local e
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "reunion" then e = x end end
local text = e and SkaldAPI.Render(e) or ""
fire("GROUP_ROSTER_UPDATE"); runTimers()
RES = (first == 1 and count("reunion") == 1 and text:find("Thorgar", 1, true) and text:find("Deadmines", 1, true) and not text:find("{", 1, true))
  and "ok" or ("reunions " .. first .. "/" .. count("reunion") .. " text=" .. text)`,
});

run('a companion seen a few hours ago, or any when the option is off, is not a reunion', {
  pre: `${GROUP}\n${COMPANION('3 * 3600')}`,
  body: `fire("GROUP_ROSTER_UPDATE"); runTimers()
local recent = count("reunion")
SkaldCharDB.companions.Thorgar.seen = NOW - 5 * 86400; SkaldCharDB.companions.Thorgar.last = NOW - 5 * 86400
SkaldDB.companions = false
fire("GROUP_ROSTER_UPDATE"); runTimers()
RES = (recent == 0 and count("reunion") == 0) and "ok" or ("recent=" .. recent .. " off=" .. count("reunion"))`,
});

run('a boss in a group remembers who was there, and forgetting clears them', {
  pre: `${GROUP}\n${DUNGEON}`,
  body: `fire("BOSS_KILL", 1, "Edwin VanCleef"); runTimers()
local c = SkaldCharDB.companions and SkaldCharDB.companions.Thorgar
local kept = c and c.shared and c.pn
SlashCmdList.SKALD("forgetcompanions")
RES = (kept and SkaldCharDB.companions == nil) and "ok" or ("kept=" .. tostring(kept))`,
});

run('inviting someone who declines is not a group: no page and no goal until another player is in it', {
  body: `function IsInGroup() return true end
local members = 1
function GetNumGroupMembers() return members end
fire("GROUP_ROSTER_UPDATE"); runTimers()
local declined = count("party") + (SkaldCharDB.flags.party and 1 or 0)
members = 2
fire("GROUP_ROSTER_UPDATE"); runTimers()
RES = (declined == 0 and count("party") == 1 and SkaldCharDB.flags.party) and "ok" or ("after the invite: " .. declined .. ", after joining: " .. count("party"))`,
});

run('in a realmless world two players with the same first name and different surnames are two companions, and the page tells only the name', {
  body: `function IsInGroup() return true end
function UnitExists(u) return u == "party1" or u == "party2" end
function UnitName(u) if u == "party1" then return "Adson", "Flexhota" elseif u == "party2" then return "Adson", "Marvik" end return "Tester" end
function IsInInstance() return true, "party" end
function GetInstanceInfo() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end
fire("BOSS_KILL", 1, "Edwin VanCleef"); runTimers()
local c = SkaldCharDB.companions or {}
local boss
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "boss" then boss = x end end
local text = boss and SkaldAPI.Render(boss) or ""
local hidden = boss and ns.HideNames(text, boss) or ""
RES = (c["Adson-Flexhota"] and c["Adson-Marvik"] and not c.Adson and text:find("Adson", 1, true) and not text:find("Flexhota", 1, true)
  and not hidden:find("Adson", 1, true)) and "ok" or ("companions: " .. tostring(c["Adson-Flexhota"]) .. "/" .. tostring(c["Adson-Marvik"]) .. " text=" .. text .. " hidden=" .. hidden)`,
});

run('the companions kept are no more than the cap, the oldest dropped', {
  body: `local entry
SkaldCharDB.companions = {}
for i = 1, 230 do SkaldCharDB.companions["P" .. i] = { first = 1, last = i, seen = i, shared = true } end
function IsInGroup() return true end
function UnitExists(u) return u == "party1" end
function UnitName(u) if u == "party1" then return "New" end return "Tester" end
IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end
fire("BOSS_KILL", 1, "Edwin VanCleef"); runTimers()
local n = 0 for _ in pairs(SkaldCharDB.companions) do n = n + 1 end
RES = (n <= 200 and SkaldCharDB.companions.New and SkaldCharDB.companions.P1 == nil) and "ok" or ("kept " .. n)`,
});

const MEMORY = (extra = '', note = '') => `${SAVED(`{ { t = NOW - 5 * 86400, kind = "zone", arg = "Darkshore", zone = "Darkshore", m = 1439, fav = true, ${note} idx = 1 } }`, extra)}
function UnitAffectingCombat() return false end`;
const GO_TO_DARKSHORE = `NOW = NOW + 60
SEEN = nil
local old = ns.ShowNotice
ns.ShowNotice = function(title, text, lines, secs, entry) SEEN = { title = title, text = text, entry = entry } end
function GetZoneText() return "Darkshore" end
fire("ZONE_CHANGED_NEW_AREA")`;

run('coming back to a land with a favourite page shows a quiet memory, once in a while', {
  pre: MEMORY(),
  body: `${GO_TO_DARKSHORE}
local first = SEEN and SEEN.text
SEEN = nil
function GetZoneText() return "Elwynn Forest" end; fire("ZONE_CHANGED_NEW_AREA")
NOW = NOW + 700
function GetZoneText() return "Darkshore" end; fire("ZONE_CHANGED_NEW_AREA")
RES = (first and first:find("Darkshore", 1, true) and SEEN == nil) and "ok" or ("first=" .. tostring(first) .. " again=" .. tostring(SEEN and SEEN.text))`,
});

run('a favourite note is the memory itself, in the player\'s own words', {
  pre: MEMORY('', 'favNote = "The best tea of my life",'),
  body: `${GO_TO_DARKSHORE}
RES = (SEEN and SEEN.text == '"The best tea of my life"' and SEEN.entry and SEEN.entry.fav) and "ok" or ("text=" .. tostring(SEEN and SEEN.text))`,
});

const ANNIV = (daysAgo, extra = '') => `${SAVED(`{ { t = NOW - ${daysAgo} * 86400, kind = "zone", arg = "Darkshore", zone = "Darkshore", m = 1439, idx = 1 } }`, `stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = NOW - ${daysAgo} * 86400 } ${extra}`)}
function UnitAffectingCombat() return false end`;
const ANNIV_CHECK = `SEEN = nil
ns.ShowNotice = function(title, text, lines, secs, entry) SEEN = { title = title, text = text, entry = entry } end
ns.CheckAnniversary()`;
const ANNIV_RUN = `NOW = NOW + 60
${ANNIV_CHECK}`;
run('a week after the first page a quiet notice marks it, once', {
  pre: ANNIV(8),
  body: `${ANNIV_RUN}
local first = SEEN and SEEN.text
SEEN = nil; NOW = NOW + 3600; ns.CheckAnniversary()
RES = (first and not first:find("%", 1, true) and SkaldCharDB.anniv == 7 and SEEN == nil and SkaldAPI and true) and "ok" or ("first=" .. tostring(first) .. " anniv=" .. tostring(SkaldCharDB.anniv) .. " again=" .. tostring(SEEN))`,
});
run('a diary found long after a mark is brought up to date in silence', {
  pre: ANNIV(200),
  body: `${ANNIV_RUN}
RES = (SEEN == nil and SkaldCharDB.anniv == 100) and "ok" or ("seen=" .. tostring(SEEN and SEEN.text) .. " anniv=" .. tostring(SkaldCharDB.anniv))`,
});
run('no journey notice in a fresh diary, in combat, with memories off, or in a dungeon (and it waits, it is not lost)', {
  pre: ANNIV(3),
  body: `${ANNIV_RUN}
local fresh = SEEN
SkaldCharDB.stats.first = NOW - 8 * 86400
function UnitAffectingCombat() return true end
ns.CheckAnniversary()
local combat = SEEN
function UnitAffectingCombat() return false end
IsInInstance = function() return true, "party" end
ns.CheckAnniversary()
local dungeon = SEEN
IsInInstance = function() return false, "none" end
SkaldDB.memories = false
ns.CheckAnniversary()
local off = SEEN
RES = (fresh == nil and combat == nil and dungeon == nil and off == nil and SkaldCharDB.anniv == 7) and "ok" or ("fresh=" .. tostring(fresh) .. " combat=" .. tostring(combat) .. " dungeon=" .. tostring(dungeon) .. " off=" .. tostring(off))`,
});
run('the journey notices of every mark are told in the language of the client, with no stray tag', {
  pre: `__locale = "frFR"; ${ANNIV(8)}`,
  body: `NOW = NOW + 60
local all = {}
for _, step in ipairs({ 7, 30, 100, 365 }) do
  SkaldCharDB.anniv = nil
  SkaldCharDB.stats.first = NOW - step * 86400
  ${ANNIV_CHECK}
  all[#all + 1] = SEEN and SEEN.text or "NOTHING"
end
local text = table.concat(all, " | ")
RES = (not text:find("NOTHING", 1, true) and not text:find("{", 1, true) and not text:find("%s", 1, true)) and "ok" or text`,
});

run('no memory when the option is off, in combat, in a dungeon, or for a page of today', {
  pre: MEMORY(),
  body: `SkaldDB.memories = false
${GO_TO_DARKSHORE}
local off = SEEN
SkaldDB.memories = nil
function UnitAffectingCombat() return true end
function GetZoneText() return "Elwynn Forest" end; fire("ZONE_CHANGED_NEW_AREA")
function GetZoneText() return "Darkshore" end; fire("ZONE_CHANGED_NEW_AREA")
local combat = SEEN
function UnitAffectingCombat() return false end
SkaldCharDB.entries[1].t = NOW - 3600
function GetZoneText() return "Elwynn Forest" end; fire("ZONE_CHANGED_NEW_AREA")
function GetZoneText() return "Darkshore" end; fire("ZONE_CHANGED_NEW_AREA")
RES = (off == nil and combat == nil and SEEN == nil) and "ok" or ("off=" .. tostring(off) .. " combat=" .. tostring(combat) .. " young=" .. tostring(SEEN))`,
});


run('making the same thing again is one page that counts them', {
  pre: `LOOT_ITEM_CREATED_SELF = "You create: %s."; LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."`,
  body: `local link = "|cff0070dd|Hitem:555::::::::15:::::|h[Worn Hatchet]|h|r"
local other = "|cff0070dd|Hitem:556::::::::15:::::|h[Worn Axe]|h|r"
fire("CHAT_MSG_LOOT", "You create: " .. link .. "."); runTimers()
fire("CHAT_MSG_LOOT", "You create: " .. link .. "."); runTimers()
fire("CHAT_MSG_LOOT", "You create: " .. link .. "x2."); runTimers()
local pages = count("loot")
local e = SkaldCharDB.entries[#SkaldCharDB.entries]
local text = SkaldAPI.Render(e)
fire("CHAT_MSG_LOOT", "You create: " .. other .. "."); runTimers()
NOW = NOW + 3000
fire("CHAT_MSG_LOOT", "You create: " .. link .. "."); runTimers()
RES = (pages == 1 and e.n == 4 and text:find("4", 1, true) and not text:find("{", 1, true) and count("loot") == 3)
  and "ok" or ("pages=" .. pages .. " n=" .. tostring(e.n) .. " text=" .. text .. " total=" .. count("loot"))`,
});


run('old pages of the same thing made again and again become one page', {
  pre: SAVED(`{
  { t = NOW - 600, kind = "loot", arg = "|cff0070dd|Hitem:555::::::::15:::::|h[Worn Hatchet]|h|r", src = "craft", iid = 555, tier = 3, zone = "x", m = false, idx = 1 },
  { t = NOW - 590, kind = "loot", arg = "|cff0070dd|Hitem:555::::::::15:::::|h[Worn Hatchet]|h|r", src = "craft", iid = 555, tier = 3, zone = "x", m = false, idx = 2 },
  { t = NOW - 580, kind = "loot", arg = "|cff0070dd|Hitem:555::::::::15:::::|h[Worn Hatchet]|h|r", src = "craft", iid = 555, tier = 3, zone = "x", m = false, idx = 3 },
  { t = NOW - 570, kind = "loot", arg = "|cff0070dd|Hitem:556::::::::15:::::|h[Worn Axe]|h|r", src = "craft", iid = 556, tier = 3, zone = "x", m = false, idx = 1 },
}`),
  body: `local e = SkaldCharDB.entries
local loot = {} for _, x in ipairs(e) do if x.kind == "loot" then loot[#loot + 1] = x end end
RES = (#loot == 2 and loot[1].n == 3 and loot[2].iid == 556 and not (SkaldAPI.Render(loot[1]):find("{", 1, true))) and "ok" or ("pages=" .. #e .. " n=" .. tostring(e[1].n))`,
});


const TAXI = `Enum = { FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 } }
C_TaxiMap = { GetAllTaxiNodes = function() return {
  { nodeID = 1, name = "Auberdine", state = 0 }, { nodeID = 2, name = "Rut'theran Village", state = 1 }, { nodeID = 3, name = "Far", state = 2 } } end }`;

run('a flight path is a page only for the master I am standing at, not for the ones I already knew', {
  pre: `${TAXI}\n${SAVED('{}', 'taxi = {}')}`,
  body: `fire("TAXIMAP_OPENED"); runTimers()
local e
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "flight" then e = x end end
RES = (count("flight") == 1 and e.arg == "Auberdine" and SkaldCharDB.taxi[2] == true) and "ok" or ("pages " .. count("flight"))`,
});

run('a first look at the flight map of a character that knew several paths writes nothing', {
  pre: TAXI,
  body: `fire("TAXIMAP_OPENED"); runTimers()
RES = (count("flight") == 0 and SkaldCharDB.taxi[1] == true) and "ok" or ("pages " .. count("flight"))`,
});


const TIPLINES = `local lines = {}
local tip = setmetatable({ ClearLines = function() end, SetMinimumWidth = function() end,
  AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function() end }, { __index = function() return function() end end })`;

run('a quest page keeps the objective in the client language and the tooltip shows it', {
  pre: `function GetObjectiveText() return "Destrua o Selo da Lua Antigo." end
LibStub = function(name) if name ~= "LibQuestDB-1.0" then return nil end return {
  GetQuest = function() return { questLevel = 13 } end,
  GetQuestText = function() return { objectives = "Destroy the Ancient Moonstone Seal." } end,
  GetRewards = function() return {} end } end`,
  body: `__locale = "ptBR"
fire("QUEST_COMPLETE"); fire("QUEST_TURNED_IN", 102, 5000, 0); runTimers()
local e
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "quest" then e = x end end
${TIPLINES}
ns.QuestTip(tip, e)
local all = table.concat(lines, "|")
RES = (e and e.ot == "Destrua o Selo da Lua Antigo." and all:find("Selo da Lua", 1, true) and not all:find("Destroy", 1, true))
  and "ok" or ("ot=" .. tostring(e and e.ot) .. " tip=" .. all)`,
});

run('an old quest page does not show the English text of QuestDB in another language', {
  pre: `LibStub = function(name) if name ~= "LibQuestDB-1.0" then return nil end return {
  GetQuest = function() return { questLevel = 13 } end,
  GetQuestText = function() return { objectives = "Destroy the Ancient Moonstone Seal." } end,
  GetRewards = function() return {} end } end
function GetLocale() return "ptBR" end`,
  body: `${TIPLINES}
ns.QuestTip(tip, { kind = "quest", arg = "Bashal'Aran", q = 1, tier = 3 })
local all = table.concat(lines, "|")
RES = (not all:find("Destroy", 1, true)) and "ok" or ("english shown: " .. all)`,
});


run('the quest text offered at the start is kept by quest id and used when it is handed in', {
  pre: `local current = 0; local text = "Mate as criaturas da praia."
function GetQuestID() return current end
function GetObjectiveText() return text end`,
  body: `current = 102; fire("QUEST_DETAIL")
text = ""; fire("QUEST_COMPLETE")
fire("QUEST_TURNED_IN", 102, 5000, 0); runTimers()
local e
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "quest" then e = x end end
RES = (e and e.ot == "Mate as criaturas da praia." and (SkaldCharDB.questObj or {})[102] == nil) and "ok" or ("ot=" .. tostring(e and e.ot))`,
});

run('the quest text comes from the quest log when the dialog does not give it', {
  pre: `function GetQuestID() return 102 end
function GetObjectiveText() return "" end
C_QuestLog.GetLogIndexForQuestID = function() return 3 end
function GetQuestLogQuestText() return "Historia.", "Traga dez peles." end`,
  body: `fire("QUEST_COMPLETE")
fire("QUEST_TURNED_IN", 102, 5000, 0); runTimers()
local e
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "quest" then e = x end end
RES = (e and e.ot == "Traga dez peles.") and "ok" or ("ot=" .. tostring(e and e.ot))`,
});


run('quest summaries select the gender of the player and expand localized tokens', {
  body: `function UnitSex() return 3 end
local female = ns.ExpandQuestText("$N, $G bravo: brava; $C de $R.$BVolte.")
function UnitSex() return 2 end
local male = ns.ExpandQuestText("$G bravo: brava;")
UnitSex = nil
local unknown = ns.ExpandQuestText("$G bravo: brava;")
RES = (female == "Tester, brava Hunter de Human. Volte." and male == "bravo" and unknown == "bravo")
  and "ok" or tostring(female)`,
});

run('crafted quantities follow the localized loot format including spacing and multiplication signs', {
  pre: `LOOT_ITEM_CREATED_SELF_MULTIPLE = "Voce cria: %s × %d."`,
  body: `local link = "|cff0070dd|Hitem:555::::::::15:::::|h[Worn Hatchet]|h|r"
fire("CHAT_MSG_LOOT", "Voce cria: " .. link .. " × 3."); runTimers()
fire("CHAT_MSG_LOOT", "Voce cria: " .. link .. " × 2."); runTimers()
local e = SkaldCharDB.entries[#SkaldCharDB.entries]
RES = (count("loot") == 1 and e.n == 5) and "ok" or ("quantity=" .. tostring(e.n))`,
});

run('words that agree with the speaker follow the sex of the character', {
  body: `local text = "Je suis tombé{g:|e} et {g:content|contente}."
local male = ns.Gendered(text)
function UnitSex() return 3 end
local female = ns.Gendered(text)
RES = (male == "Je suis tombé et content." and female == "Je suis tombée et contente." and ns.Gendered("sem marca") == "sem marca")
  and "ok" or (male .. " / " .. female)`,
});

run('a page that carries a gender tag shows the right form, whatever the language', {
  pre: `function UnitSex() return 3 end`,
  body: `__locale = "frFR"
local e = { kind = "boss", arg = "Edwin VanCleef", tries = 3, zone = "x", t = NOW, idx = 1 }
local seen = false
for i = 1, 20 do e.idx = i; local t = SkaldAPI.Render(e); if t:find("{g:", 1, true) then seen = "tag left: " .. t end end
local r = { kind = "revive", arg = "Elwynn", zone = "Elwynn", t = NOW, idx = 1 }
for i = 1, 20 do r.idx = i; local t = SkaldAPI.Render(r); if t:find("{g:", 1, true) then seen = "tag left: " .. t end end
RES = seen == false and "ok" or seen`,
});


run('item exports keep the item name without game hyperlink codes', {
  pre: SAVED(`{ {t=NOW, kind="loot", arg="|cff0070dd|Hitem:555::::::::15:::::|h[Worn Hatchet]|h|r", iid=555, tier=3, zone="Elwynn", idx=1} }`),
  body: `for _, format in ipairs({"plain", "discord"}) do
local text = table.concat(SkaldAPI.BuildExport(format, "all"))
assert(text:find("Worn Hatchet", 1, true), text)
assert(not text:find("|H", 1, true) and not text:find("|h", 1, true) and not text:find("item:555", 1, true), text)
end
RES = "ok"`,
});

run('long quest summaries and stored objectives never split accented or four-byte characters', {
  body: `for _, letter in ipairs({"é", "😀"}) do
local result = ns.ExpandQuestText(string.rep("a", 229) .. letter .. "fim")
assert(utf8.len(result) and result == string.rep("a", 229) .. "...", "broken summary")
function GetQuestID() return 102 end
function GetObjectiveText() return string.rep("a", 239) .. letter .. "fim" end
fire("QUEST_DETAIL")
assert(SkaldCharDB.questObj[102] == string.rep("a", 239), "broken stored objective")
end
RES = "ok"`,
});

run('long exported notes remain valid UTF-8 at the message boundary', {
  pre: SAVED(`{ {t=NOW, kind="note", arg=string.rep("é",1100), zone="Elwynn", idx=1},
{t=NOW, kind="note", arg="a"..string.rep("é",1100), zone="Elwynn", idx=1} }`),
  body: `for _, format in ipairs({"plain", "discord"}) do
for _, text in ipairs(SkaldAPI.BuildExport(format, "all")) do
assert(utf8.len(text), "invalid UTF-8 in " .. format .. " export")
end end
RES = "ok"`,
});

/*GOALTESTS*/
run('goals already met when the diary first looks are marked quietly, without pages', {
  pre: SAVED('{}', 'taxi = { true, true, true, true, true, true }, companions = { Thorgar = { first = 1, last = 1, seen = 1, shared = true } }'),
  body: `local g = SkaldCharDB.goals or {}
RES = (count("goal") == 0 and g.flights5 and g.flights5.retro and g.companions1 and g.companions1.retro and not g.flights15 and not g.companions5)
  and "ok" or ("pages=" .. count("goal") .. " flights5=" .. tostring(g.flights5))`,
});

run('a goal reached after that is written as a page, with its name', {
  pre: `${GROUP}\n${DUNGEON}`,
  body: `fire("BOSS_KILL", 1, "Edwin VanCleef"); runTimers()
local e
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "goal" and x.arg == "companions1" then e = x end end
local text = e and SkaldAPI.Render(e) or ""
RES = (e and e.arg == "companions1" and e.tier == 2 and text:find("The Road Has Company", 1, true) and text:find("(+10 points)", 1, true) and not text:find("{", 1, true)
  and SkaldCharDB.goals.companions1 and not SkaldCharDB.goals.companions1.retro) and "ok" or ("goal page: " .. text)`,
});

run('a goal is written once, and a goal page does not make another check run forever', {
  pre: `${GROUP}\n${DUNGEON}`,
  body: `fire("BOSS_KILL", 1, "Edwin VanCleef"); runTimers(); runTimers()
NOW = NOW + 100
fire("BOSS_KILL", 1, "Rhahk'Zor"); runTimers(); runTimers()
local n = 0
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "goal" and x.arg == "companions1" then n = n + 1 end end
RES = (n == 1) and "ok" or ("companions1 written " .. n .. " times")`,
});

run('the goals tab opens and every goal has its name and text in each language', {
  pre: `__locale = "ptBR"`,
  body: `local tab = btn("Metas")
local missing = {}
for _, g in ipairs(ns.GoalList) do
  if not ns.GoalUI.NAMES[g.id] then missing[#missing + 1] = "name " .. g.id end
  if not ns.GoalUI.FACT[g.fact] then missing[#missing + 1] = "fact " .. g.fact end
end
RES = (tab ~= nil and #missing == 0) and "ok" or ("tab=" .. tostring(tab) .. " missing: " .. table.concat(missing, ","))`,
});

run('the goals of the French client are all named', {
  pre: `__locale = "frFR"`,
  body: `local missing = {}
for _, g in ipairs(ns.GoalList) do
  if not ns.GoalUI.NAMES[g.id] then missing[#missing + 1] = g.id end
end
RES = (#missing == 0 and btn("Objectifs") ~= nil) and "ok" or ("missing: " .. table.concat(missing, ","))`,
});

run('building and refreshing the goals tab raises no error', {
  pre: `local realPcall = pcall
ERRS = ""
pcall = function(f, ...)
  local r = { realPcall(f, ...) }
  if not r[1] and tostring(r[2]):find("G:", 1, true) then ERRS = ERRS .. tostring(r[2]) .. "; " end
  return table.unpack(r)
end`,
  body: `local tab = btn("Goals")
if tab and tab._OnClick then tab._OnClick(tab) end
fire("BOSS_KILL", 1, "Edwin VanCleef"); runTimers(); runTimers()
RES = (tab ~= nil and ERRS == "") and "ok" or ("tab=" .. tostring(tab) .. " errors: " .. ERRS)`,
});




run('a goal reached says what it was about, and its row opens the page', {
  pre: `${SAVED(`{
  { t = 1792000000, kind = "quest", arg = "A Lenda do Vento", q = 5, cend = 4, tier = 3, zone = "x", m = false, idx = 1 },
}`, 'goals = { chains1 = { t = 1, retro = true } }, goalsInit = true')}
local opened
`,
  body: `local tab = btn("Goals")
tab._OnClick(tab)
for i = #frames, 1, -1 do local f = frames[i]; local c = rawget(f, "cat"); if c and c.key == "story" and f._OnClick then f._OnClick(f); break end end
SkaldAPI.OpenEntry = function(e) opened = e end
local rowWithEvidence
for i = #frames, 1, -1 do
  local f = frames[i]
  if rawget(f, "evidence") then rowWithEvidence = f; break end
end
RES = (rowWithEvidence and rowWithEvidence.evidence:find("A Lenda do Vento", 1, true) and rowWithEvidence.evidence:find("4", 1, true)
  and rowWithEvidence.entry and rowWithEvidence.entry.kind == "quest") and "ok"
  or ("row: " .. tostring(rowWithEvidence and rowWithEvidence.evidence))`,
});


run('where the client announces encounters, the falls are those at that very boss', {
  pre: DUNGEON,
  body: `${BOSSES}
fire("PLAYER_DEAD"); fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
fire("ENCOUNTER_START", 573, "Edwin VanCleef")
fire("PLAYER_DEAD")
fire("ENCOUNTER_END", 573, "Edwin VanCleef", 1, 5, 1); runTimers()
local e = last()
RES = (e.kind == "boss" and e.tries == 1) and "ok" or ("tries=" .. tostring(e.tries))`,
});

run('a boss killed with no falls at him, after falls at another, is told as usual', {
  pre: DUNGEON,
  body: `${BOSSES}
fire("ENCOUNTER_START", 1, "Rhahk'Zor"); fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
fire("ENCOUNTER_END", 1, "Rhahk'Zor", 1, 5, 0)
fire("ENCOUNTER_START", 2, "Sneed's Shredder"); fire("ENCOUNTER_END", 2, "Sneed's Shredder", 1, 5, 1); runTimers()
local e = last()
RES = (e.kind == "boss" and e.arg == "Sneed's Shredder" and e.tries == nil) and "ok" or ("tries=" .. tostring(e.tries))`,
});


run('the export hides the names of other players unless asked to show them', {
  pre: SAVED(`{ { t = 1792000000, kind = "reunion", arg = "Thorgar", zone = "x", pn = "The Deadmines", idx = 1 },
  { t = 1792000100, kind = "boss", arg = "Edwin VanCleef", with = { "Thorgar", "Mira" }, zone = "x", idx = 1 } }`, 'companions = { Thorgar = { first = 1, last = 1, shared = true }, Mira = { first = 1, last = 1, shared = true } }'),
  body: `local hidden = table.concat(SkaldAPI.BuildExport("plain", "all"), " ")
SkaldDB.exportHideNames = false
local shown = table.concat(SkaldAPI.BuildExport("plain", "all"), " ")
RES = (not hidden:find("Thorgar", 1, true) and not hidden:find("Mira", 1, true) and hidden:find("a companion", 1, true)
  and shown:find("Thorgar", 1, true)) and "ok" or ("hidden: " .. hidden)`,
});


run('the Reader text has a header, the pages, escapes, and a checksum that matches its body', {
  pre: SAVED(`{ { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", idx = 1 },
  { t = 1792000100, kind = "note", arg = "a caret ^ and a line" .. string.char(10) .. "break", zone = "x", fav = true, favNote = "my note" },
  { t = 1792000200, kind = "level", arg = 5, zone = "x", idx = 1 } }`, 'stats = { counts = { quest = 3 }, deathZones = {}, tiers = { [2] = 1 }, played = 600, first = 1792000000 }, goals = { pets1 = { t = 5, retro = true } }'),
  body: `local parts = SkaldAPI.BuildExport("reader", "all")
local text = parts[1] or ""
local nl = string.char(10)
local header, body = text:match("^([^" .. nl .. "]*)" .. nl .. "(.*)$")
local fields = {}
for f in (header .. "^"):gmatch("([^%^]*)%^") do fields[#fields + 1] = f end
local h = 5381
for i = 1, #body do h = (h * 31 + body:byte(i)) % 4294967296 end
local pages = 0
for line in (body .. nl):gmatch("([^" .. nl .. "]*)" .. nl) do if line:sub(1, 2) == "P^" then pages = pages + 1 end end
local escaped = body:find(string.char(92) .. "p", 1, true) and body:find(string.char(92) .. "n", 1, true)
RES = (#parts == 1 and fields[1] == "H" and fields[2] == "SKALDREADER1" and tonumber(fields[9]) == pages and tonumber(fields[10]) == 1 and tonumber(fields[11]) == 1
  and tonumber(fields[12]) == h and pages >= 3 and escaped and body:find("N^quest^3", 1, true) and body:find("G^pets1", 1, true) and body:find("my note", 1, true))
  and "ok" or ("header=" .. tostring(header) .. " pages=" .. pages .. " sum=" .. tostring(fields[12]) .. "/" .. h)`,
});

run('a long diary comes in several parts, each with its own checksum, and no page is cut in two', {
  body: `local nl = string.char(10)
for i = 1, 400 do
  table.insert(SkaldCharDB.entries, { t = 1792000000 + i, kind = "note", arg = string.rep("word ", 60) .. i, zone = "x" })
end
local parts = SkaldAPI.BuildExport("reader", "all")
local total, ok = 0, true
for n, text in ipairs(parts) do
  local header, body = text:match("^([^" .. nl .. "]*)" .. nl .. "(.*)$")
  local fields = {}
  for f in (header .. "^"):gmatch("([^%^]*)%^") do fields[#fields + 1] = f end
  local h = 5381
  for i = 1, #body do h = (h * 31 + body:byte(i)) % 4294967296 end
  if tonumber(fields[12]) ~= h or tonumber(fields[10]) ~= n or tonumber(fields[11]) ~= #parts then ok = false end
  for line in (body .. nl):gmatch("([^" .. nl .. "]*)" .. nl) do
    if line:sub(1, 2) == "P^" then total = total + 1 end
    if line ~= "" and not line:match("^[SNTGVP]%^") then ok = false end
  end
end
RES = (#parts >= 2 and ok and total >= 400) and "ok" or ("parts=" .. #parts .. " ok=" .. tostring(ok) .. " pages=" .. total)`,
});


run('only quests of some rarity keep their description on the page', {
  pre: `function GetQuestID() return 102 end
function GetObjectiveText() return "Do the thing." end`,
  body: `fire("QUEST_DETAIL"); fire("QUEST_COMPLETE")
local function turnIn(id, xp) fire("QUEST_TURNED_IN", id, xp, 0); runTimers() end
turnIn(102, 100000)
local rich
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "quest" then rich = x end end
RES = (rich and (rich.tier or 0) >= 2 and rich.ot == "Do the thing.") and "ok" or ("rich tier=" .. tostring(rich and rich.tier) .. " ot=" .. tostring(rich and rich.ot))`,
});


const FLAVOR_COUNT = `math.randomseed(11)
for i = 1, 600 do NOW = NOW + 60; fire("PLAYER_LEVEL_UP", 5 + i % 30) end
local flavored, pages = 0, 0
for _, e in ipairs(SkaldCharDB.entries) do if e.kind == "level" then pages = pages + 1; if e.fl then flavored = flavored + 1 end end end`;

run('class and race pools of eight lines are drawn as often as the plain ones', {
  body: `${FLAVOR_COUNT}
RES = (pages >= 100 and flavored / pages > 0.25) and "ok" or ("flavoured " .. flavored .. " of " .. pages)`,
});

run('a short class or race pool is drawn less often, so it does not repeat at once', {
  body: `local P = ns.LOCALES.enUS.phrases
P.class_HUNTER_level = { "one %s", "two %s" }
P.race_Human_level = { "three %s", "four %s" }
${FLAVOR_COUNT}
RES = (pages >= 100 and flavored / pages < 0.2) and "ok" or ("flavoured " .. flavored .. " of " .. pages)`,
});



const SCALE_AT = `function scaleAt(w, h, want)
  UIParent.GetWidth = function() return w end
  UIParent.GetHeight = function() return h end
  SkaldDB.bookScale = want
  local got
  SkaldFrame.SetScale = function(_, v) got = v end
  fire("DISPLAY_SIZE_CHANGED")
  return got
end
local function near(a, b) return a and math.abs(a - b) < 0.01 end`;

run('the book is drawn smaller on a small screen, never larger than the player chose', {
  body: `${SCALE_AT}
RES = (near(scaleAt(1920, 1080, nil), 1) and near(scaleAt(1024, 768, nil), 1.0) and near(scaleAt(800, 600, nil), 0.7837)
  and near(scaleAt(400, 300, nil), 0.5)) and "ok"
  or ("1920x1080=" .. tostring(scaleAt(1920, 1080, nil)) .. " 800x600=" .. tostring(scaleAt(800, 600, nil)))`,
});

run('the size the player chose is kept within what the screen holds', {
  body: `${SCALE_AT}
RES = (near(scaleAt(1920, 1080, 1.5), 1.5) and near(scaleAt(1366, 768, 1.5), 1.2447) and near(scaleAt(1920, 1080, 0.8), 0.8))
  and "ok" or ("1.5@1080=" .. tostring(scaleAt(1920, 1080, 1.5)) .. " 1.5@768=" .. tostring(scaleAt(1366, 768, 1.5)))`,
});

run('/skald size sets the size of the book, and auto takes it back', {
  body: `${SCALE_AT}
SlashCmdList.SKALD("size 125")
local set = SkaldDB.bookScale
SlashCmdList.SKALD("size auto")
local auto = SkaldDB.bookScale
SlashCmdList.SKALD("size banana")
RES = (set == 1.25 and auto == nil and SkaldDB.bookScale == nil) and "ok" or ("set=" .. tostring(set) .. " auto=" .. tostring(auto))`,
});

const OTHER_STATE = `pets = { Wolf = { n = 1 } }, petNow = "Wolf", companions = { Thorgar = { first = 1, last = 1 } }, taxi = { [5] = true }, goals = { pets1 = { t = 5 } }, goalsInit = true, rep = { Stormwind = 3 }, questStart = { [9] = 1 }, attempts = { Boss = 2 }, resume = { next = "go" }`;

run('a diary of another character takes its pets, companions, flights and goals with it, and gives them back', {
  pre: `SkaldCharDB = { entries = { { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "x", idx = 1 } }, visited = {}, flags = {}, guid = "OLD", ${OTHER_STATE} }`,
  body: `local db = SkaldCharDB
local function has(t, k) return type(t) == "table" and t[k] ~= nil end
local clean = not has(db.pets, "Wolf") and not has(db.companions, "Thorgar") and not has(db.taxi, 5) and not has(db.goals, "pets1")
  and not has(db.rep, "Stormwind") and not has(db.questStart, 9) and not has(db.attempts, "Boss") and db.petNow ~= "Wolf"
  and not (db.resume and db.resume.next == "go")
local kept = db.previous and db.previous[1] and db.previous[1].state and db.previous[1].state.pets and db.previous[1].state.companions
if not clean or not kept then RES = "clean=" .. tostring(clean) .. " kept=" .. tostring(kept) return end
db.pets = { Cat = {} }
ns.RestoreLatestArchive()
RES = (db.pets and db.pets.Wolf and not db.pets.Cat and db.companions and db.companions.Thorgar and db.taxi and db.taxi[5]
  and db.goals and db.goals.pets1 and db.petNow == "Wolf" and db.previous[1].state.pets.Cat) and "ok" or "not restored"`,
});

run('erasing the diary erases what it knew about the character as well', {
  pre: SAVED(`{ { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "x", idx = 1 } }`, OTHER_STATE),
  body: `StaticPopupDialogs.SKALD_CLEAR.OnAccept()
local db = SkaldCharDB
RES = (#db.entries == 0 and db.pets == nil and db.companions == nil and db.taxi == nil and db.goals == nil and db.rep == nil
  and db.questStart == nil and db.attempts == nil and db.resume == nil) and "ok" or "something stayed"`,
});

run('a name with its realm is hidden in an export, and so is the note of a favourite page', {
  pre: SAVED(`{ { t = 1792000000, kind = "boss", arg = "Edwin VanCleef", with = { "Alice-Realm" }, zone = "x", idx = 1, fav = true, favNote = "Alice saved me" },
  { t = 1792000100, kind = "reunion", arg = "Bob-Area52", zone = "x", pn = "The Deadmines", idx = 1 } }`, 'companions = { ["Alice-Realm"] = { first = 1, last = 1, shared = true } }'),
  body: `local plain = table.concat(SkaldAPI.BuildExport("plain", "all"), " ")
local reader = table.concat(SkaldAPI.BuildExport("reader", "all"), " ")
local leak = plain:find("Alice", 1, true) or plain:find("Realm", 1, true) or plain:find("Bob", 1, true) or plain:find("Area52", 1, true)
  or reader:find("Alice", 1, true) or reader:find("Realm", 1, true) or reader:find("Bob", 1, true)
SkaldDB.exportHideNames = false
local shown = table.concat(SkaldAPI.BuildExport("reader", "all"), " ")
RES = (not leak and shown:find("Alice saved me", 1, true)) and "ok" or ("leak: " .. tostring(leak) .. " | " .. reader:sub(1, 300))`,
});

run('a phrase is not told again within five pages of the same kind', {
  body: `for i = 1, 60 do fire("PLAYER_LEVEL_UP", 1 + (i % 9)) end
local lastSeen, bad = {}, nil
for _, e in ipairs(SkaldCharDB.entries) do
  if e.kind == "level" then
    local list = SkaldAPI.PoolFor(e)
    local key = tostring(e.fl)
    local seen = lastSeen[key] or {}
    local keep = math.min(5, #list - 1)
    for i = math.max(1, #seen - keep + 1), #seen do if seen[i] == e.idx then bad = "repeated " .. e.idx .. " in a pool of " .. #list end end
    seen[#seen + 1] = e.idx
    lastSeen[key] = seen
  end
end
RES = (count("level") >= 50 and not bad) and "ok" or (bad or "no pages")`,
});

run('a note, a restored diary and an erased diary make the book measure its pages again', {
  pre: `SkaldCharDB = { entries = { { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "x", idx = 1 } }, visited = {}, flags = {}, guid = "OLD" }`,
  body: `local rev = ns.layoutRev or 0
ns.RestoreLatestArchive()
local afterRestore = ns.layoutRev or 0
StaticPopupDialogs.SKALD_CLEAR.OnAccept()
local afterClear = ns.layoutRev or 0
RES = (afterRestore > rev and afterClear > afterRestore) and "ok" or ("rev " .. rev .. " -> " .. afterRestore .. " -> " .. afterClear)`,
});

run('turning old one-line notes into pages makes the book measure its pages again', {
  pre: SAVED(`{ { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "x", idx = 1 } }`, 'notes = { ["2026-10-01"] = "an old note" }'),
  body: `RES = ((ns.layoutRev or 0) > 0 and count("note") == 1) and "ok" or ("rev " .. tostring(ns.layoutRev) .. " notes " .. count("note"))`,
});

run('an old archive without map keys makes them again from its pages, so a zone is not told twice', {
  pre: `SkaldCharDB = { entries = { { t = 1792000000, kind = "zone", arg = "Darkshore", zone = "Darkshore", idx = 1, m = 1439 } }, visited = { Darkshore = true }, flags = {}, guid = "P1", mapKeysDone = true,
  previous = { { guid = "OLD", t = 1, entries = { { t = 1791000000, kind = "zone", arg = "Darkshore", zone = "Darkshore", idx = 1, m = 1439 } }, visited = { Darkshore = true }, stats = nil } } }`,
  body: `ns.RestoreLatestArchive()
local before = count("zone")
function GetZoneText() return "Costa Negra" end
fire("ZONE_CHANGED_NEW_AREA"); runTimers()
RES = (before == 1 and count("zone") == 1) and "ok" or ("zones " .. before .. " -> " .. count("zone"))`,
});

run('the export window shows the label of the player-names button, in every format', {
  pre: SAVED(`{ { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "x", idx = 1 } }`),
  body: `SlashCmdList.SKALD("export")
local hidden = btn("Player names: hidden")
SkaldDB.exportFormat = "reader"
SlashCmdList.SKALD("export")
local inReader = btn("Player names: hidden")
if hidden then hidden._OnClick(hidden) end
RES = (hidden and inReader and btn("Player names: shown")) and "ok" or ("hidden=" .. tostring(hidden) .. " reader=" .. tostring(inReader))`,
});

run('a pet family saved in another language is shown in the language of now', {
  pre: `__locale = "ptBR"
` + SAVED(`{}`),
  body: `local a, b, c = ns.FamilyLabel("Wolf"), ns.FamilyLabel("lobo"), ns.FamilyLabel("Wild Beast")
RES = (a == "Lobo" and b == "Lobo" and c == "Wild Beast" and ns.FamilyLabel(nil) == nil) and "ok" or (tostring(a) .. " " .. tostring(b) .. " " .. tostring(c))`,
});

run('a notice stays as long as the player chose: a number of seconds, until clicked, and a sample keeps its own time', {
  body: `local function life() for i = #frames, 1, -1 do local l = rawget(frames[i], "life") if l then return l end end end
ns.ShowNotice("T", "b", 3, 9, nil); local standard = life()
SkaldDB.noticeSecs = 10; ns.ShowNotice("T", "b", 3, 9, nil); local ten = life()
SkaldDB.noticeSecs = 0; ns.ShowNotice("T", "b", 3, 9, nil); local pinned = life()
SkaldDB.noticeSecs = 4; ns.PreviewNotice(12); local sample = life()
RES = (standard == 9 and ten == 10 and pinned >= 1e9 and sample == 12) and "ok" or (tostring(standard) .. " " .. tostring(ten) .. " " .. tostring(pinned) .. " " .. tostring(sample))`,
});

run('collection goals: an unready journal marks nothing, the first read marks quietly, a later mount is a page', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 3'),
  body: `local ids = {}
C_MountJournal = { GetMountIDs = function() return ids end, GetMountInfoByID = function(id) return "m" .. id, 0, 0, false, true, 0, false, false, nil, false, id <= SKALD_OWNED, id end }
SKALD_OWNED = 0
local clock = 1000
GetTime = function() clock = clock + 30; return clock end
local function look() ns.CheckGoals() end
look()
local g = SkaldCharDB.goals
local unready = not g.mounts1 and not SkaldCharDB.collInit
for i = 1, 20 do ids[i] = i end
SKALD_OWNED = 6
look()
local first = g.mounts1 and g.mounts1.retro and g.mounts5 and g.mounts5.retro and not g.mounts10 and SkaldCharDB.collInit
SKALD_OWNED = 10
look()
local later = g.mounts10 and not g.mounts10.retro
local mountPages = 0
for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "goal" and tostring(x.arg):find("^mounts") then mountPages = mountPages + 1 end end
local _, without = ns.GoalScore()
C_PetJournal = { GetNumPets = function() return 5, 0 end }
clock = clock + 60
local _, withPets = ns.GoalScore()
RES = (unready and first and later and mountPages == 1 and withPets - without == 90) and "ok" or ("unready=" .. tostring(unready) .. " first=" .. tostring(first) .. " later=" .. tostring(later) .. " pages=" .. count("goal") .. " " .. (function() local t = {} for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "goal" then t[#t+1] = x.arg end end return table.concat(t, ",") end)())`,
});

run('goals that came with a later list are marked quietly in a diary that already looked, and the points follow the seals', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goals = { flights5 = { t = 5 } }, taxi = { true, true, true, true, true, true, true }, stats = { counts = { quest = 120, dungeon = 3, boss = 2, kill = 600 }, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: `local g = SkaldCharDB.goals
local earned, possible = ns.GoalScore()
-- flights5 was there before (5 points); the new ones (level 10 and 20, quests50, dungeons, bosses1, kills500) came quietly
local quiet = g.level10 and g.level10.retro and g.level20 and g.level20.retro and g.quests50 and g.quests50.retro and g.kills500 and g.kills500.retro
RES = (count("goal") == 0 and quiet and SkaldCharDB.goalsVer == 4 and earned > 5 and possible > 800 and ns.GoalPoints("level60") == 100
  and ns.GoalPoints("flights5") == 5) and "ok" or ("pages=" .. count("goal") .. " quiet=" .. tostring(quiet) .. " ver=" .. tostring(SkaldCharDB.goalsVer) .. " score=" .. earned .. "/" .. possible)`,
});

const SAGA_DIARY = (first = 1792000000, counts = 'quest = 80, boss = 3, death = 5', extra = '') => SAVED(`{
  { t = ${first}, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", idx = 1 },
  { t = ${first + 90000}, kind = "level", arg = 10, zone = "Westfall", idx = 1 },
  { t = ${first + 180000}, kind = "boss", arg = "Hogger", zone = "Elwynn Forest", tries = 2, tier = 3, idx = 1 },
  { t = ${first + 260000}, kind = "death", arg = "Duskwood", zone = "Duskwood", idx = 1 },
}`, `stats = { counts = { ${counts} }, deathZones = { Duskwood = 3, Westfall = 1 }, tiers = {}, played = 100, first = ${first} },
  companions = { ["Aldor-Sakaldd"] = { first = 1, last = 50 }, ["Brisa-Sakaldd"] = { first = 1, last = 40 }, ["Cato-Sakaldd"] = { first = 1, last = 30 }, ["Dora-Sakaldd"] = { first = 1, last = 20 } },
  goals = { level10 = { t = 1, retro = true }, flights5 = { t = 2, retro = true } }, goalsInit = true, goalsVer = 3 ${extra}`);

run('the Saga: the same diary tells the same Saga, with every chapter, no stray tag and a page-sized text', {
  pre: SAGA_DIARY(),
  body: `local a, b = ns.BuildSaga(), ns.BuildSaga()
local same = #a == #b
for i = 1, #a do if not b[i] or a[i].text ~= b[i].text or a[i].title ~= b[i].title then same = false end end
local keys, worst, stray = {}, 0, ""
for _, c in ipairs(a) do
  keys[#keys + 1] = c.key
  if #c.text > worst then worst = #c.text end
  if c.text:find("{", 1, true) or c.text:find("}", 1, true) then stray = c.key end
end
local names = a[6] and a[6].text or ""
local wanted = "prologue,road,stories,war,falls,company,marks,epilogue"
RES = (same and table.concat(keys, ",") == wanted and worst <= 640 and stray == "" and names:find("Aldor", 1, true) and names:find("Cato", 1, true)
  and not names:find("Sakaldd", 1, true) and not names:find("Dora", 1, true) and a[4].text:find("Hogger", 1, true) and a[5].text:find("Duskwood", 1, true))
  and "ok" or ("same=" .. tostring(same) .. " keys=" .. table.concat(keys, ",") .. " worst=" .. worst .. " stray=" .. stray)`,
});

run('the Saga leaves out a chapter that has nothing to say, and never tells a zero', {
  pre: SAVED(`{
  { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", idx = 1 },
  { t = 1792090000, kind = "level", arg = 10, zone = "Westfall", idx = 1 },
}`, 'stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1792000000 }, goals = {}, goalsInit = true, goalsVer = 3'),
  body: `local keys, zero = {}, false
for _, c in ipairs(ns.BuildSaga()) do
  keys[#keys + 1] = c.key
  if c.text:find("%f[%d]0%f[%D]") then zero = true end
end
local c = SkaldCharDB.stats.counts
RES = (table.concat(keys, ",") == "prologue,road,marks,epilogue" and not zero) and "ok" or (table.concat(keys, ",") .. " zero=" .. tostring(zero) .. " boss=" .. tostring(c.boss) .. " death=" .. tostring(c.death) .. " goals=" .. tostring(next(SkaldCharDB.goals)))`,
});

run('the Saga picks different phrases for different diaries, and each pool is reachable', {
  pre: SAGA_DIARY(),
  body: `local seen, n = {}, 0
for i = 1, 40 do
  SkaldCharDB.stats.first = 1792000000 + i * 7919
  local text = ns.BuildSaga()[1].text
  if not seen[text:sub(1, 14) .. text:len()] then seen[text:sub(1, 14) .. text:len()] = true; n = n + 1 end
end
RES = (n >= 6) and "ok" or ("only " .. n .. " different prologues in 40 diaries")`,
});

for (const [loc, who] of [['ptBR', 'Aldor'], ['frFR', 'Aldor']]) {
  run(`the Saga of a woman in ${loc}: every form agrees, no tag is left, the names are the first names`, {
    pre: `__locale = "${loc}"; function UnitSex() return 3 end
${SAGA_DIARY(1792000000, 'quest = 80, boss = 3, death = 5', ', level = 60')}`,
    body: `local all = {}
for i = 1, 25 do
  SkaldCharDB.stats.first = 1792000000 + i * 104729
  for _, c in ipairs(ns.BuildSaga()) do all[#all + 1] = c.text end
end
local text = table.concat(all, " ")
local stray = text:find("{", 1, true) or text:find("}", 1, true)
RES = (not stray and #all >= 200 and not text:find("Sakaldd", 1, true) and text:find("${who}", 1, true)) and "ok" or ("stray=" .. tostring(stray) .. " n=" .. #all)`,
  });
}

run('the Saga goes onto pages by the size of the letter: no chapter lost, none split, never more than three to a page', {
  pre: SAGA_DIARY(),
  body: `local chapters = ns.BuildSaga()
local ok, why = true, ""
local counts = {}
for _, size in ipairs({ 11, 13, 15, 20 }) do
  local pages = ns.SagaPages(chapters, size)
  local n, order = 0, {}
  for _, page in ipairs(pages) do
    if #page > 3 or #page == 0 then ok, why = false, "page of " .. #page .. " at " .. size end
    for _, c in ipairs(page) do n = n + 1; order[#order + 1] = c.key end
  end
  if n ~= #chapters then ok, why = false, "chapters lost at " .. size end
  for i, c in ipairs(chapters) do if order[i] ~= c.key then ok, why = false, "order at " .. size end end
  counts[#counts + 1] = #pages
end
RES = (ok and counts[1] <= counts[3] and counts[3] <= counts[4] and counts[4] > counts[1]) and "ok" or (why .. " pages=" .. table.concat(counts, "/"))`,
});

for (const [loc, pats] of [['enUS', ['count', 'tally']], ['ptBR', ['%f[%a]conta%f[%A]']], ['frFR', ['%f[%a]compte%f[%A]']]]) {
  run(`the Saga of ${loc} does not count in every chapter: at most two chapters use the counting formula`, {
    pre: `__locale = "${loc}"; ${SAGA_DIARY()}`,
    body: `local worst, at = 0, 0
for i = 1, 60 do
  SkaldCharDB.stats.first = 1792000000 + i * 7919
  local n = 0
  for _, c in ipairs(ns.BuildSaga()) do
    local low = c.text:lower()
    for _, p in ipairs({ ${pats.map(p => JSON.stringify(p)).join(', ')} }) do
      if low:find(p) then n = n + 1; break end
    end
  end
  if n > worst then worst, at = n, i end
end
RES = (worst <= 2) and "ok" or ("a Saga counted in " .. worst .. " chapters (seed " .. at .. ")")`,
  });
}

run('the Saga writes the singular for one and the plural for many', {
  pre: SAGA_DIARY(1792000000, 'quest = 1, boss = 1, death = 1'),
  body: `local text = {}
for i = 1, 40 do
  SkaldCharDB.stats.first = 1792000000 + i * 7919
  for _, c in ipairs(ns.BuildSaga()) do text[#text + 1] = c.text end
end
local all = table.concat(text, " ")
RES = (not all:find("1 quests", 1, true) and not all:find("1 falls", 1, true) and not all:find("1 bosses", 1, true) and not all:find("1 days", 1, true)
  and all:find("1 quest", 1, true) and not all:find("{", 1, true)) and "ok" or "plural form wrong"`,
});

run('the Saga of falls the diary does not place does not invent a place, and the prologue only says where the first page was written', {
  pre: SAVED(`{
  { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", idx = 1 },
  { t = 1792090000, kind = "level", arg = 10, zone = "Westfall", idx = 1 },
}`, 'stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1792000000 }, goals = {}, goalsInit = true, goalsVer = 3') + `
function GetStatistic(id) if id == 60 then return "7" end return "--" end`,
  body: `local seen, bad = false, nil
for i = 1, 40 do
  SkaldCharDB.stats.first = 1792000000 + i * 7919
  for _, c in ipairs(ns.BuildSaga()) do
    if c.key == "falls" then seen = true; if c.text:find("Duskwood") or c.text:lower():find("unknown") or c.text:find("?", 1, true) then bad = c.text end end
    if c.key == "prologue" and (c.text:find("set out from") or c.text:find("starts in") or c.text:find("began in")) then bad = c.text end
  end
end
RES = (seen and not bad) and "ok" or tostring(bad or "no falls chapter")`,
});

for (const [loc, home, land] of [['enUS', 'Shadowglen', 'Teldrassil'], ['ptBR', 'Umbravale', 'Teldrassil'], ['frFR', 'Sylvarde', 'Teldrassil']]) {
  run(`the Saga of ${loc} tells where a race is born, and the first page only when it was written elsewhere`, {
    pre: `__locale = "${loc}"; ${SAGA_DIARY()}
function UnitRace() return "Night Elf", "NightElf" end
C_Map.GetAreaInfo = function(id) if id == 188 then return "${home}" end if id == 141 then return "${land}" end end
function GetCategoryList() return { 1 } end
function GetCategoryNumAchievements() return 2 end
function GetAchievementInfo(cat, i) if i == 1 then return 7, "x", 10, true, 10, 10, 26 end return 8, "y", 10, true, 10, 12, 26 end`,
    body: `local texts = {}
for i = 1, 30 do
  SkaldCharDB.stats.first = 1792000000 + i * 7919
  texts[#texts + 1] = ns.BuildSaga()[1].text
end
local all = table.concat(texts, " ")
-- the first page was written in Darkshore, not where a Night Elf is born: it is told too
local born = all:find("${home}", 1, true) and all:find("${land}", 1, true)
local firstPage = all:find("Darkshore", 1, true)
-- written where the race begins: no first page sentence
SkaldCharDB.entries[1].zone = "${home}"
local same = ns.BuildSaga()[1].text
RES = (born and firstPage and not same:find("Darkshore", 1, true) and not all:find("{", 1, true)) and "ok"
  or ("born=" .. tostring(born) .. " first=" .. tostring(firstPage) .. " same=" .. same)`,
  });
}

run('the Saga of a race it does not know is told without a birthplace', {
  pre: SAGA_DIARY() + `
function UnitRace() return "Pandaren", "Pandaren" end`,
  body: `local text = ns.BuildSaga()[1].text
RES = (text:find("Darkshore", 1, true) and not text:find("born", 1, true)) and "ok" or text`,
});

const TTS = `SPOKEN = {}
C_VoiceChat = { SpeakText = function(voice, text, rate, volume, overlap) SPOKEN[#SPOKEN + 1] = { voice = voice, text = text, rate = rate, volume = volume } end,
  StopSpeakingText = function() STOPPED = (STOPPED or 0) + 1 end }
C_TTSSettings = { GetVoiceOptionID = function() return 3 end, GetSpeechRate = function() return 1 end, GetSpeechVolume = function() return 80 end }`;
run('/skald read speaks the newest page with the voice settings of the game, and stops on request', {
  pre: TTS + `\n` + SAGA_DIARY(),
  body: `ns.SpeechOn = true
SlashCmdList.SKALD("read")
local first = SPOKEN[1]
local e = SkaldCharDB.entries[#SkaldCharDB.entries]
SlashCmdList.SKALD("read stop")
RES = (first and first.voice == 3 and first.rate == 1 and first.volume == 80 and #first.text > 10 and not first.text:find("{", 1, true) and STOPPED and not ns.Speaking()) and "ok"
  or ("spoken=" .. tostring(first and first.text) .. " stopped=" .. tostring(STOPPED))`,
});

run('/skald read saga speaks the chapters one piece after the other, advancing when the game says a piece is done', {
  pre: TTS + `\n` + SAGA_DIARY(),
  body: `ns.SpeechOn = true
SlashCmdList.SKALD("read saga")
local n0 = #SPOKEN
local guard = 0
while ns.Speaking() and guard < 80 do fire("VOICE_CHAT_TTS_PLAYBACK_FINISHED"); guard = guard + 1 end
local joined = {}
for _, s in ipairs(SPOKEN) do joined[#joined + 1] = s.text; if #s.text > 400 then joined = nil; break end end
RES = (n0 == 1 and #SPOKEN >= 8 and joined and not ns.Speaking() and table.concat(joined, " "):find("Prologue", 1, true)) and "ok"
  or ("first=" .. n0 .. " total=" .. #SPOKEN)`,
});

run('/skald read says so when the client has no text-to-speech, and when there is nothing to read', {
  pre: SAGA_DIARY(),
  body: `SlashCmdList.SKALD("read")
local off = not ns.SpeechAvailable() and SPOKEN == nil
ns.SpeechOn = true
RES = (off and not ns.SpeechAvailable() and SPOKEN == nil) and "ok" or "spoke without an API or with the switch off"`,
});

run('the Saga says "an Orc" and "an Undead", never "a Orc"', {
  pre: SAGA_DIARY() + `
function UnitRace() return "Orc", "Orc" end`,
  body: `local bad
for i = 1, 40 do
  SkaldCharDB.stats.first = 1792000000 + i * 7919
  local text = ns.BuildSaga()[1].text
  if text:find("[Aa] Orc") then bad = text end
end
UnitRace = function() return "Undead", "Scourge" end
for i = 1, 40 do
  SkaldCharDB.stats.first = 1792000000 + i * 104729
  local text = ns.BuildSaga()[1].text
  if text:find("[Aa] Undead") then bad = text end
end
RES = (not bad) and "ok" or bad`,
});

run('goals whose source changed come quietly to a diary that already looked (the game counts more quests than the diary)', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 2, goals = { level10 = { t = 1 }, level20 = { t = 1 } }, stats = { counts = { quest = 30 }, deathZones = {}, tiers = {}, played = 1, first = 1 }') + `
function GetStatistic(id) if id == 98 then return "200" end return "--" end`,
  body: `local g = SkaldCharDB.goals
RES = (count("goal") == 0 and g.quests50 and g.quests50.retro and g.quests150 and g.quests150.retro and not g.quests400)
  and "ok" or ("pages=" .. count("goal") .. " q50=" .. tostring(g.quests50 and g.quests50.retro))`,
});

run('the Saga tab turns its pages through the corners: the first spread cannot go back, the last cannot go on, and both can turn in between', {
  pre: SAGA_DIARY(),
  body: `local tab = btn("Saga")
tab._OnClick(tab)
local prev, nextB
for _, f in ipairs(frames) do
  if f._OnClick and rawget(f, "tex") and rawget(f, "_alpha") then
    if f._alpha < 1 then prev = f else nextB = f end
  end
end
if not (prev and nextB) then RES = "corners not found" else
  local first = prev._alpha < 1 and nextB._alpha == 1
  local guard = 0
  while nextB._alpha == 1 and guard < 10 do nextB._OnClick(nextB); guard = guard + 1 end
  local last = nextB._alpha < 1 and prev._alpha == 1
  prev._OnClick(prev)
  local back = nextB._alpha == 1
  RES = (first and last and back and guard >= 1 and SkaldDB.errors == nil) and "ok"
    or ("first=" .. tostring(first) .. " last=" .. tostring(last) .. " back=" .. tostring(back) .. " turns=" .. guard)
end`,
});

run('the Saga tab opens, turns its pages and raises no error', {
  pre: SAGA_DIARY(),
  body: `local tab = btn("Saga")
if not tab then RES = "no Saga tab" else
  tab._OnClick(tab)
  RES = (SkaldDB.errors == nil) and "ok" or ("errors: " .. tostring(SkaldDB.errors[1]))
end`,
});

const ZONE_STUBS = `C_Map.GetMapInfo = function(id) return { mapType = 3, name = "Teldrassil", parentMapID = 1414 } end
C_Map.GetBestMapForUnit = function() return 1438 end
function UnitRace() return "Human", "Human", 1 end
function UnitClass() return "Mage", "MAGE", 8 end`;
const ZONE_ART = `C_Map.GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
C_Map.GetMapArtLayerTextures = function() local t = {} for i = 1, 12 do t[i] = 1000 + i end return t end
C_MapExplorationInfo = { GetExploredMapTextures = function() return { { textureWidth = 300, textureHeight = 200, offsetX = 100, offsetY = 50, fileDataIDs = { 11, 12 } }, { textureWidth = 256, textureHeight = 256, offsetX = 0, offsetY = 0, fileDataIDs = { 13 } }, { isShownByMouseOver = true, textureWidth = 256, textureHeight = 256, fileDataIDs = { 14 } } } end }`;
const ZONE_DB = `local quests = {
  [1] = { zoneOrSort = 10 }, [2] = { zoneOrSort = 10 }, [3] = { zoneOrSort = 10, hidden = "retired" },
  [4] = { zoneOrSort = 10, requiredRaces = 2 }, [5] = { zoneOrSort = 10, specialFlags = 1 }, [6] = { zoneOrSort = -22 },
}
local qdb = { GetQuestIds = function() return { 1, 2, 3, 4, 5, 6 } end, GetQuest = function(_, id) return quests[id] end,
  GetUiMapId = function() return 1438 end }
_G.LibStub = function() return qdb end
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return id == 2 end }`;

run('the zone card counts the quests of the zone for the race and class, not the hidden nor the repeatable ones', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 3, goals = {}, stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: ZONE_STUBS + '\n' + ZONE_ART + '\n' + ZONE_DB + `
local done, total = ns.ZoneCard.Quests(1438)
RES = (done == 1 and total == 2) and "ok" or ("done " .. tostring(done) .. " of " .. tostring(total))`,
});

run('the zone card builds from the tiles of the game and raises no error', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 3, goals = {}, stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: ZONE_STUBS + '\n' + ZONE_ART + '\n' + ZONE_DB + `
local card = ns.ZoneCard.Build(UIParent, 342)
card:Set(1438)
RES = (#card.tiles == 12 and ns.ZoneCard.Regions(1438) == 3 and #card.found == 3) and "ok" or ("tiles " .. #card.tiles .. " found " .. #card.found)`,
});

run('the zone card still comes out without the map art and without QuestDB', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 3, goals = {}, stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: ZONE_STUBS + `
C_Map.GetMapArtLayers = nil
C_MapExplorationInfo = nil
_G.LibStub = nil
local card = ns.ZoneCard.Build(UIParent, 342)
card:Set(1438)
local done, total = ns.ZoneCard.Quests(1438)
RES = (total == nil and done == 0 and ns.ZoneCard.Regions(1438) == nil) and "ok" or ("done " .. tostring(done) .. " total " .. tostring(total))`,
});

run('the Index shows the zone card on the right page when the contents fit on the left', {
  pre: SAGA_DIARY(),
  body: ZONE_STUBS + '\n' + ZONE_ART + '\n' + ZONE_DB + `
local tab = btn("Contents")
if not tab then RES = "no Contents tab" else
  tab._OnClick(tab)
  local made = 0
  for _, fr in ipairs(frames) do if rawget(fr, "tiles") and fr:IsShown() then made = made + 1 end end
  RES = (SkaldDB.errors == nil and made == 1) and "ok" or ("errors: " .. tostring(SkaldDB.errors and SkaldDB.errors[1]) .. " cards shown: " .. made)
end`,
});

run('the Days tab turns to the last spread: the day card sums up the day, with no error', {
  pre: SAGA_DIARY(),
  body: `local tab = btn("Days")
if not tab then RES = "no Days tab" else
  tab._OnClick(tab)
  local shown = 0
  for _, fr in ipairs(frames) do
    local rows = rawget(fr, "rows")
    if rows and rows[1] and rawget(rows[1], "key") == "level" and fr:IsShown() then shown = shown + 1 end
  end
  local c = ns.DayCard.Count({ level = 7, entries = { { kind = "quest" }, { kind = "quest" }, { kind = "zone" }, { kind = "death" }, { kind = "goal" } } })
  RES = (SkaldDB.errors == nil and c.level == 7 and c.quests == 2 and c.zones == 1 and c.falls == 1 and c.goals == 1 and c.pages == 5)
    and "ok" or ("errors: " .. tostring(SkaldDB.errors and SkaldDB.errors[1]) .. " shown " .. shown)
end`,
});

run('creatures slain are counted for the zone underfoot, the first look only sets the baseline', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 3, goals = {}, stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: ZONE_STUBS + `
local KILLS = 100
function GetStatistic(id) if id == 107 then return tostring(KILLS) end return "--" end
runTimers()
ns.TrackKills()
local first = SkaldCharDB.zoneKills
KILLS = 112
ns.TrackKills()
RES = (first == nil and SkaldCharDB.zoneKills[1438] == 12) and "ok" or ("first " .. tostring(first) .. " then " .. tostring(SkaldCharDB.zoneKills and SkaldCharDB.zoneKills[1438]))`,
});

run('the title follows the points and the form of the character', {
  body: `local low, mid = ns.GoalTitle(0), ns.GoalTitle(160)
RES = (low ~= "" and mid ~= low and not low:find("{", 1, true) and not mid:find("{", 1, true) and ns.GoalTitle(5000) ~= mid) and "ok" or (low .. " | " .. mid)`,
});

run('titles come out right for a woman in French and Portuguese, and the notice of a goal tells its points', {
  pre: `__locale = "frFR"; function UnitSex() return 3 end`,
  body: `local fr = { ns.GoalTitle(0), ns.GoalTitle(60), ns.GoalTitle(160), ns.GoalTitle(320) }
local e = { kind = "goal", arg = "level10", tier = 1, idx = 1, t = 1, noExtras = true }
local text = SkaldAPI.Render(e)
local want = { "Nouvelle arrivante", "Voyageuse", "Routière", "Pionnière" }
for i = 1, 4 do if fr[i] ~= want[i] then RES = "fr " .. i .. ": " .. tostring(fr[i]) return end end
RES = text:find("(+5 points)", 1, true) and "ok" or ("no points in the notice text: " .. text)`,
});

run('a character who is not a hunter and has no pets is not counted the beasts in the points', {
  pre: SAVED('{}', 'goalsInit = true, version = 99, goalsVer = 2, goals = {}, stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1 }')
    + '\nfunction UnitClass() return "Mage","MAGE" end',
  body: `local earned, possible = ns.GoalScore()
SkaldCharDB.pets = { Wolf = { t = 1 } }
local _, withPets = ns.GoalScore()
RES = (withPets - possible == 65) and "ok" or ("without " .. possible .. " with " .. withPets)`,
});

run('gold held and standings seen count for the goals of fortune and renown', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goalsVer = 2, goals = {}, rep = { Stormwind = 8, Darnassus = 5 }, stats = { counts = {}, deathZones = {}, tiers = {}, played = 1, first = 1 }')
    + '\nfunction GetMoney() return 5000000 end',
  body: `local f = ns.GoalFacts()
SkaldAPI.entryHook("quest"); runTimers(); runTimers()
local g = SkaldCharDB.goals
RES = (f.gold == 500 and f.repFriendly == 2 and f.repHonored == 1 and f.repExalted == 1 and g.gold100 and not g.gold1000 and g.repExalted and count("goal") >= 3)
  and "ok" or ("gold=" .. tostring(f.gold) .. " rep=" .. tostring(f.repFriendly) .. "/" .. tostring(f.repHonored) .. "/" .. tostring(f.repExalted) .. " pages=" .. count("goal"))`,
});

run('the seal that closes the book follows the faction, and anything unknown is neutral', {
  pre: SAVED('{}'),
  body: `RES = (ns.CloseSeal("Horde") == "ui_waxseal_horde" and ns.CloseSeal("Alliance") == "ui_waxseal_alliance"
  and ns.CloseSeal("Neutral") == "ui_waxseal_neutral" and ns.CloseSeal(nil) == "ui_waxseal_neutral" and ns.CloseSeal(false) == "ui_waxseal_neutral")
  and "ok" or "wrong seal"`,
});

run('a day in a land with a known climate has its weather doodle at the foot, and any other land does not', {
  pre: THREE_DAYS,
  body: `local function drawn()
  local out = ""
  for _, side in ipairs(SkaldFrame.sides) do
    for _, t in ipairs(rawget(side, "doodles") or {}) do if rawget(t, "_shown") then out = out .. rawget(t, "_tex") end end
  end
  return out
end
SkaldAPI.OpenEntry(SkaldCharDB.entries[1])
local rain = drawn()
local ids = ns.WeatherOf(1411) == "sun" and ns.WeatherOf(1426) == "snow" and ns.WeatherOf(1429) == "partly" and ns.WeatherOf(1424) == "cloudy" and ns.WeatherOf(99999) == nil and ns.WeatherOf(nil) == nil
for _, e in ipairs(SkaldCharDB.entries) do e.m, e.zm = 99999, 99999 end
ns.layoutRev = (ns.layoutRev or 0) + 1
SkaldAPI.OpenEntry(SkaldCharDB.entries[2])
local plain = drawn()
RES = (rain:find("wxd_rain", 1, true) and ids and not plain:find("wxd_", 1, true)) and "ok"
  or ("doodles " .. rain .. ", ids " .. tostring(ids) .. ", on an unknown land " .. plain)`,
});

run('a day ends with the doodles of what it held, the most present first, three at most', {
  pre: THREE_DAYS,
  body: `local picked = ns.DoodlesOf({ { kind = "boss" }, { kind = "death" }, { kind = "death" }, { kind = "quest" }, { kind = "quest" }, { kind = "zone" }, { kind = "level" } }, 3)
local order = table.concat(picked, ",")
local none = #ns.DoodlesOf({ { kind = "loot" } }, 3)
SkaldAPI.OpenEntry(SkaldCharDB.entries[3])
local drawn = ""
for _, side in ipairs(SkaldFrame.sides) do
  for _, t in ipairs(rawget(side, "doodles") or {}) do if rawget(t, "_shown") then drawn = drawn .. rawget(t, "_tex") end end
end
RES = (order == "skull,sword,map" and none == 0 and drawn:find("dd_skull", 1, true)) and "ok"
  or ("order " .. order .. ", loot only " .. none .. ", drawn " .. tostring(drawn))`,
});

run('a looser page density spreads a long day over more pages, and the command tells the choice', {
  pre: SAVED('{' + Array.from({ length: 90 }, (_, i) => `{ t = ${1792000000 + i * 60}, kind = "quest", arg = "Q${i}", zone = "Darkshore", zm = 1439, m = 1439, x = 0.4, y = 0.4, idx = 1, tier = 1 }`).join(',') + '}'),
  body: `SkaldAPI.OpenEntry(SkaldCharDB.entries[1])
SlashCmdList.SKALD("density compact")
local compact = SkaldFrame:PageCount()
SlashCmdList.SKALD("density airy")
local airy = SkaldFrame:PageCount()
SlashCmdList.SKALD("density nonsense")
RES = (compact < airy and SkaldDB.density == "airy") and "ok" or ("compact " .. compact .. " airy " .. airy .. " chosen " .. tostring(SkaldDB.density))`,
});

run('the density keeps room for the doodles in each choice, ignores a command that only starts like it, and an unknown value reads as comfy', {
  body: `local bad
for _, key in ipairs({ "compact", "comfy", "airy" }) do
  SlashCmdList.SKALD("density " .. key)
  local d = ns.DensityCfg()
  local band = ns.DensityBand()
  if key ~= "compact" and band - 11 - 10 < math.ceil(48 * d.doodle) then bad = key .. " band " .. band end
end
SlashCmdList.SKALD("density densityairy")
SlashCmdList.SKALD("density compact")
SlashCmdList.SKALD("densityairy")
local kept = SkaldDB.density
SkaldDB.density = "bogus"
local cfg = ns.DensityCfg()
RES = (not bad and kept == "compact" and cfg.fill == 0.92) and "ok" or ("band " .. tostring(bad) .. " kept " .. tostring(kept) .. " fill " .. tostring(cfg.fill))`,
});

run('every doodle of a day lies inside the column and the room above the quill, whatever the density, the count and the day', {
  body: `local bad
for _, scale in ipairs({ 0.85, 1, 1.3 }) do
  for count = 1, 4 do
    for day = 1, 12 do
      for _, room in ipairs({ 48, 63, 90 }) do
        for i = 1, count do
          local size, x, drop = ns.DoodleSpot(i, count, day, room, scale)
          if size < 1 or x < 0 or x + size > SkaldAPI.CW + 0.001 or drop < 0 or drop + size > room + 0.001 then
            bad = bad or ("scale " .. scale .. " count " .. count .. " day " .. day .. " room " .. room .. " i " .. i .. " size " .. size .. " x " .. x .. " drop " .. drop)
          end
        end
      end
    end
  end
end
RES = bad or "ok"`,
});

run('the long-haul goals of version 4 come quietly to an old diary that is already past them, and the days with a page are counted', {
  pre: SAVED('{ { t = 1792000000, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", idx = 1 }, { t = 1792003600, kind = "zone", arg = "Westfall", zone = "Westfall", idx = 1 }, { t = 1792090000, kind = "zone", arg = "Duskwood", zone = "Duskwood", idx = 1 } }',
    'version = 99, goalsInit = true, goalsVer = 3, goals = {}, stats = { counts = { quest = 1600, kill = 12000 }, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: `local g = SkaldCharDB.goals
local f = ns.GoalFacts()
local quiet = g.quests800 and g.quests800.retro and g.quests1500 and g.quests1500.retro and g.kills10000 and g.kills10000.retro
local top = 0
for _, x in ipairs(ns.GoalList) do if x.id == "days365" then top = x.target end end
local newPages = 0
for _, x in ipairs(SkaldCharDB.entries) do
  if x.kind == "goal" and (tostring(x.arg):find("^quests") or tostring(x.arg):find("^kills") or tostring(x.arg):find("^days")) and x.arg ~= "quests50" and x.arg ~= "quests150" and x.arg ~= "quests400" and x.arg ~= "kills500" and x.arg ~= "kills2500" then newPages = newPages + 1 end
end
RES = (newPages == 0 and quiet and not g.quests3000 and not g.days7 and f.days >= 2 and top == 365
  and ns.GoalTitle(2300) ~= ns.GoalTitle(750)) and "ok" or ("newPages=" .. newPages .. " quiet=" .. tostring(quiet) .. " days=" .. tostring(f.days))`,
});

run('a long category of goals goes over more pages: the corners of the book turn them and stay inside the range', {
  body: `local tab = btn("Goals")
tab._OnClick(tab)
for i = #frames, 1, -1 do local f = frames[i]; local c = rawget(f, "cat"); if c and c.key == "war" and f._OnClick then f._OnClick(f); break end end
local pager
for i = #frames, 1, -1 do if rawget(frames[i], "label") then pager = frames[i]; break end end
local function label() return rawget(pager.label, "_text") end
local first = label()
local prev, nextB
for _, f in ipairs(frames) do
  if f._OnClick and rawget(f, "tex") and rawget(f, "_alpha") then
    if f._alpha < 1 then prev = f else nextB = f end
  end
end
if not (prev and nextB) then RES = "corners not found" else
nextB._OnClick(nextB); nextB._OnClick(nextB); nextB._OnClick(nextB)   -- past the last page: it stays on it
local last = label()
prev._OnClick(prev)
RES = (first == "1 of 2" and last == "2 of 2" and label() == "1 of 2") and "ok" or ("first " .. tostring(first) .. " last " .. tostring(last) .. " back " .. tostring(label()))
end`,
});

const FACT_PRE = `function GetQuestID() return 102 end; C_QuestLog.GetQuestDifficultyLevel = function() return 20 end`;
const FACT_HELP = `local function turn(money) NOW = NOW + 60; fire("QUEST_COMPLETE"); fire("QUEST_TURNED_IN", 102, 5000, money or 0); runTimers()
  local e; for i = #SkaldCharDB.entries, 1, -1 do if SkaldCharDB.entries[i].kind == "quest" then e = SkaldCharDB.entries[i]; break end end
  return e end
local function level(n) C_QuestLog.GetQuestDifficultyLevel = function() return n end end`;

run('a quest page tells one more thing only when it is true: the first of the day, a fat purse, a quest far above or below, a long absence, a fall, the tenth', {
  pre: FACT_PRE,
  body: `${FACT_HELP}
local got = {}
local function note(name, e, key, value) if e.xk ~= key or e.xv ~= value then got[#got + 1] = name .. "=" .. tostring(e.xk) .. "/" .. tostring(e.xv) end end
note("first", turn(0), "first", nil)
note("rich", turn(25000), "rich", 2)
level(30); note("above", turn(0), "above", 10)
level(5); note("below", turn(0), "below", 15)
level(20); note("plain", turn(0), nil, nil)
NOW = NOW + 3 * 86400; note("back", turn(0), "back", nil)
table.insert(SkaldCharDB.entries, { t = NOW + 30, kind = "death", arg = "x", zone = "Elwynn Forest", idx = 1 }); NOW = NOW + 30
note("fallen", turn(0), "fallen", nil)
SkaldCharDB.days[SkaldCharDB.today].q = 9; NOW = NOW + 4000
note("tenth", turn(0), "milestone", 10)
local e = turn(25000); local shown = SkaldAPI.Render(e)
RES = (#got == 0 and not shown:find("{", 1, true)) and "ok" or table.concat(got, " ")`,
});

run('the extra sentence of a quest page is told after the main one, and a page without it reads as it always did', {
  pre: FACT_PRE,
  body: `${FACT_HELP}
local e = turn(0)
local plain = SkaldAPI.Render({ kind = "quest", arg = "Q", tier = 1, idx = 1, t = NOW, npc = "Bob" })
local base = SkaldAPI.Render({ kind = "quest", arg = "Q", tier = 1, idx = 1, t = NOW, npc = "Bob", xk = "first", xi = 1 })
local pool = ns.LOCALES.enUS.phrases.fact_first
RES = (base == plain .. " " .. pool[1] and plain ~= base) and "ok" or (plain .. " || " .. base)`,
});

run('thirty quests that all have something to tell: no key twice among three pages, no phrase twice among five of its key', {
  pre: FACT_PRE,
  body: `${FACT_HELP}
level(40)
local keys, per, bad = {}, {}, nil
for i = 1, 60 do
  local e = turn(30000)
  keys[#keys + 1] = e.xk or "-"
  if e.xk then
    local list = per[e.xk] or {}; per[e.xk] = list
    for j = math.max(1, #list - 4), #list do if list[j] == e.xi then bad = bad or (e.xk .. " repeats phrase " .. e.xi .. " at page " .. i) end end
    list[#list + 1] = e.xi
  end
end
for i = 1, #keys do
  for j = i + 1, math.min(i + 2, #keys) do if keys[i] ~= "-" and keys[i] == keys[j] then bad = bad or ("key " .. keys[i] .. " at " .. i .. " and " .. j) end end
end
local told = 0; for _, k in ipairs(keys) do if k ~= "-" then told = told + 1 end end
RES = (not bad and told >= 15) and "ok" or (bad or ("only " .. told .. " told: " .. table.concat(keys, ",")))`,
});

// The cap on pages (3000) lets the oldest go, but never a favourite or a note, and never the progress the goals read.
const CAP_PRE = (mark) => `local es = {}
for i = 1, 3000 do es[i] = { t = NOW - (3001 - i) * 60, zone = "Z", kind = "zone", arg = "e" .. i, idx = 1 } end
${mark}
${SAVED('es')}`;
const has = `local function has(arg) for _, e in ipairs(SkaldCharDB.entries) do if e.arg == arg then return true end end return false end`;

run('at the cap a favourite and a note stay while the plain pages go, oldest first', {
  pre: CAP_PRE('es[1].fav = true; es[2].kind = "note"'),
  body: `${has}
SkaldAPI.AddEntry("zone", "new")
RES = (#SkaldCharDB.entries == 3000 and has("e1") and has("e2") and not has("e3") and has("new")) and "ok"
  or ("n=" .. #SkaldCharDB.entries .. " e1=" .. tostring(has("e1")) .. " e2=" .. tostring(has("e2")) .. " e3=" .. tostring(has("e3")))`,
});

run('when only favourites and notes are left the diary grows past the cap and loses nothing', {
  pre: CAP_PRE('for i = 1, 3000 do if i % 2 == 0 then es[i].fav = true else es[i].kind = "note" end end'),
  body: `${has}
SkaldAPI.AddEntry("zone", "new")
SkaldAPI.AddEntry("zone", "newer")
local all = true
for i = 1, 3000 do if not has("e" .. i) then all = false end end
RES = (all and #SkaldCharDB.entries >= 3000) and "ok" or ("lost some, n=" .. #SkaldCharDB.entries)`,
});

run('a note written at the cap lets an older plain page go and the book redraws', {
  pre: CAP_PRE('es[1].fav = true'),
  body: `${has}
local rev = ns.layoutRev or 0
ns.InsertNote(NOW - 30, "Z", "hello")
local note = false
for _, e in ipairs(SkaldCharDB.entries) do if e.kind == "note" and e.arg == "hello" then note = true end end
RES = (#SkaldCharDB.entries == 3000 and note and has("e1") and not has("e2") and (ns.layoutRev or 0) > rev) and "ok"
  or ("n=" .. #SkaldCharDB.entries .. " note=" .. tostring(note) .. " e2=" .. tostring(has("e2")))`,
});

run('goal progress counted from pages does not shrink when those pages leave the cap', {
  pre: CAP_PRE(`es[1].kind, es[1].cend = "quest", 3
es[2].kind, es[2].tries = "boss", 1
es[3].kind = "reunion"
es[4].kind, es[4].sub = "tame", "level"
es[5].kind = "guild"`),
  body: `local f0 = ns.GoalFacts()
for i = 1, 8 do SkaldAPI.AddEntry("zone", "n" .. i) end
local f1 = ns.GoalFacts()
local gone = true
for _, e in ipairs(SkaldCharDB.entries) do if e.arg == "e1" or e.arg == "e5" then gone = false end end
local ok = gone and f0.chains >= 1 and f0.hardBoss >= 1 and f0.reunions >= 1 and f0.petLevel >= 1 and f0.guild == 1
  and f1.chains == f0.chains and f1.hardBoss == f0.hardBoss and f1.reunions == f0.reunions and f1.petLevel == f0.petLevel and f1.guild == 1
RES = ok and "ok" or ("gone=" .. tostring(gone) .. " chains " .. f0.chains .. "->" .. f1.chains .. " reunions " .. f0.reunions .. "->" .. f1.reunions)`,
});

run('days written count distinct dates once, a note counts, and a date that left the cap still counts', {
  pre: CAP_PRE(''),
  body: `local d0 = ns.GoalFacts().days
ns.InsertNote(NOW - 90, "Z", "same day")
local d1 = ns.GoalFacts().days
ns.InsertNote(NOW - 40 * 86400, "Z", "another day")
local d2 = ns.GoalFacts().days
ns.InsertNote(NOW - 40 * 86400 + 5, "Z", "that day again")
local d3 = ns.GoalFacts().days
for i = 1, 20 do SkaldAPI.AddEntry("zone", "n" .. i) end
local d4 = ns.GoalFacts().days
RES = (d1 == d0 and d2 == d0 + 1 and d3 == d2 and d4 >= d3) and "ok" or (d0 .. "," .. d1 .. "," .. d2 .. "," .. d3 .. "," .. d4)`,
});

run('running the progress migration again neither doubles nor lowers anything', {
  pre: CAP_PRE(`es[1].kind, es[1].cend = "quest", 3; es[2].kind = "reunion"
`),
  body: `local s = SkaldCharDB.stats
local a = { s.chains, s.reunions, s.daysN, s.sv }
s.sv = nil
ns.MigrateStats(SkaldCharDB)
ns.MigrateStats(SkaldCharDB)
local b = { s.chains, s.reunions, s.daysN, s.sv }
local ok = a[1] == 1 and a[2] == 1 and a[4] == 1 and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and b[4] == 1
-- a higher figure already kept is not lowered by a smaller count of the pages left
s.sv = nil; s.chains = 50
ns.MigrateStats(SkaldCharDB)
RES = (ok and s.chains == 50) and "ok" or (table.concat(a, ",") .. " | " .. table.concat(b, ",") .. " chains=" .. s.chains)`,
});

run('clearing the diary zeroes the progress, and restoring an archived diary brings its progress back', {
  pre: `local es = {}
for i = 1, 5 do es[i] = { t = NOW - i * 86400, zone = "Z", kind = "quest", arg = "q" .. i, idx = 1, tier = 1, cend = 3 } end
SkaldCharDB = { entries = es, visited = {}, flags = {}, guid = "OLD" }`,
  body: `local before = ns.GoalFacts().chains
local back = ns.RestoreLatestArchive()
local restored = ns.GoalFacts().chains
ns.ResetJournal(SkaldCharDB)
local f = ns.GoalFacts()
RES = (before == 0 and back and restored == 5 and f.chains == 0 and f.days == 0 and SkaldCharDB.stats.sv == 1) and "ok"
  or ("before=" .. before .. " back=" .. tostring(back) .. " restored=" .. restored .. " after=" .. f.chains .. "/" .. f.days)`,
});


// The backup: the whole diary as text, in parts, and its restoring. Anything that goes wrong must leave the diary as it was.
const BK_PRE = `local es = {}
for i = 1, 40 do es[i] = { t = NOW - (41 - i) * 3600, zone = "Elwynn Forest", kind = "zone", arg = "e" .. i, idx = 1, x = 0.41234567891234, y = 1 / 3 } end
local q, bar, nl, quote, bs, caret = string.char(34), string.char(124), string.char(10), string.char(34), string.char(92), string.char(94)
es[3].kind = "note"
es[3].arg = "Pipe " .. bar .. " accents " .. string.char(195, 167, 195, 163) .. " " .. string.char(230, 151, 165) .. " quote " .. quote .. " slash " .. bs .. " caret " .. caret .. " line1" .. nl .. "line2 SKALDBACKUP1" .. caret .. "x"
es[4].fav, es[4].favNote = true, "my note"
es[5].kind, es[5].qtype, es[5].cend, es[5].tier = "quest", false, 3, 2
SkaldCharDB = { entries = es, visited = { Elwynn = true }, flags = {}, guid = "P1", version = 3,
  pets = { Rex = { fam = "Wolf", lvl = 5 } }, companions = { Bob = { n = 2, pz = false } },
  goals = { first = { t = 100, retro = true } }, taxi = { [1] = true, ["Stormwind"] = true }, skills = { Mining = 5 }, skillsInit = true,
  futureThing = { a = 1, [7] = "seven", list = { 1, 2, 3 } },
  previous = { { guid = "A", t = 1, entries = { { t = 1, kind = "zone" } } }, { guid = "B", t = 2, entries = { { t = 2, kind = "zone" } } }, { guid = "C", t = 3, entries = { { t = 3, kind = "zone" } } } } }`;
const BK = `local B = ns.Backup
local function snap() return B.Serialize(SkaldCharDB) end
local function part(b, i) return b.parts[i] end
local function importAll(parts) local imp = B.NewImport(); for _, p in ipairs(parts) do B.Add(imp, p) end; return imp end
local function noteOf(state) for _, e in ipairs(state.entries) do if e.kind == "note" then return e.arg end end end
local function bodyOf(p) return p:match("^[^\\n]*\\n(.*)$") end
local function headerOf(p) return p:match("^([^\\n]*)\\n") end`;

run('a backup comes back as the same diary, key by key and type by type, with the special characters kept', {
  pre: BK_PRE,
  body: `${BK}
local b = B.Build()
local want = B.Serialize(B.Capture(SkaldCharDB))
local imp = importAll(b.parts)
local cand, code, why = B.Finish(imp)
if not cand then RES = "finish: " .. tostring(code) .. " " .. tostring(why); return end
local got = B.Serialize(cand.state)
local st = cand.state.stats
local keysOk = cand.state.futureThing[7] == "seven" and cand.state.taxi[1] == true and cand.state.taxi.Stormwind == true
  and type(next(st.dayset)) == "string" and cand.state.entries[5].qtype == false and cand.state.entries[1].x == SkaldCharDB.entries[1].x
  and cand.state.entries[1].y == SkaldCharDB.entries[1].y and cand.state.companions.Bob.pz == false
local note = noteOf(cand.state) == noteOf(B.Capture(SkaldCharDB))
local ascii = true
for _, p in ipairs(b.parts) do if p:find("[^\\n\\32-\\126]") or p:find(string.char(124), 1, true) then ascii = false end end
local excluded = cand.state.previous == nil and cand.state.restoreUndo == nil
local detail = {}
for _, k in ipairs({ "futureThing", "taxi", "stats", "petNow", "pets", "companions", "entries", "goals" }) do detail[#detail + 1] = k .. "=" .. tostring(SkaldCharDB[k] ~= nil and B.Serialize(cand.state[k]) == B.Serialize(SkaldCharDB[k])) end
detail[#detail + 1] = "dayset=" .. type(next(st.dayset)) .. " q=" .. tostring(cand.state.entries[5].qtype) .. " x=" .. tostring(cand.state.entries[1].x == SkaldCharDB.entries[1].x) .. " t1=" .. tostring(cand.state.taxi[1]) .. " ft7=" .. tostring(cand.state.futureThing[7])
RES = (got == want and keysOk and note and ascii and excluded and cand.meta.count == #SkaldCharDB.entries) and "ok"
  or ("same=" .. tostring(got == want) .. " keys=" .. tostring(keysOk) .. " note=" .. tostring(note) .. " ascii=" .. tostring(ascii) .. " excl=" .. tostring(excluded) .. " " .. table.concat(detail, " "))`,
});

run('parts can come in any order, with Windows line ends, several at once, and are collected until all are there', {
  pre: BK_PRE,
  body: `${BK}
B.PART_LIMIT = 300
local b = B.Build()
if #b.parts < 4 then RES = "too few parts: " .. #b.parts; return end
local imp = B.NewImport()
for i = #b.parts, 2, -1 do
  local r = B.Add(imp, b.parts[i]:gsub("\\n", "\\r\\n"))
  if not r[1].ok then RES = "part " .. i .. ": " .. tostring(r[1].code); return end
end
local missing = B.Missing(imp)
local c1, code1 = B.Finish(imp)
local r = B.Add(imp, b.parts[1] .. "\\r\\n\\r\\n")
local c2 = B.Finish(imp)
-- all of them pasted in one go
local imp2 = B.NewImport()
local rs = B.Add(imp2, table.concat(b.parts, "\\n\\n"))
local c3 = B.Finish(imp2)
RES = (#missing == 1 and missing[1] == 1 and c1 == nil and code1 == "missing" and r[1].ok and c2 and #rs == #b.parts and c3
  and B.Serialize(c3.state) == B.Serialize(B.Capture(SkaldCharDB))) and "ok" or ("missing=" .. #missing .. " code=" .. tostring(code1) .. " parts=" .. #rs)`,
});

run('a missing, repeated, foreign, changed, cut or unrelated part is refused and never used', {
  pre: BK_PRE,
  body: `${BK}
B.PART_LIMIT = 300
local b = B.Build()
local before = snap()
local imp = B.NewImport()
local bad = {}
local function expect(label, r, code) if r[1].ok or r[1].code ~= code then bad[#bad + 1] = label .. "=" .. tostring(r[1].code) end end
B.Add(imp, b.parts[1])
expect("dup", B.Add(imp, b.parts[1]), "dup")
-- the same number with other content, its own checksum right: refused as a conflict
local h, body = headerOf(b.parts[1]), bodyOf(b.parts[1])
local f = {}; for x in (h .. "^"):gmatch("([^%^]*)%^") do f[#f + 1] = x end
local other = body:sub(1, -2) .. (body:sub(-1) == "a" and "b" or "a")
f[13], f[14] = tostring(#other), tostring(B.Checksum(other))
expect("conflict", B.Add(imp, table.concat(f, "^") .. "\\n" .. other), "conflict")
-- a changed letter, a cut part, an empty body
local p2 = b.parts[2]
local flipped = p2:sub(1, -2) .. (p2:sub(-1) == "a" and "b" or "a")
expect("changed", B.Add(imp, flipped), "badpart")
expect("cut", B.Add(imp, p2:sub(1, -20)), "badpart")
expect("nobody", B.Add(imp, headerOf(p2)), "notbackup")
-- another backup (one more page): the header says the whole is not the same
SkaldCharDB.entries[#SkaldCharDB.entries + 1] = { t = NOW, zone = "Z", kind = "zone", arg = "late", idx = 1 }
local b2 = B.Build()
expect("foreign", B.Add(imp, b2.parts[2]), "other")
SkaldCharDB.entries[#SkaldCharDB.entries] = nil
-- unrelated text
expect("text", B.Add(imp, "hello"), "notbackup")
expect("empty", B.Add(imp, ""), "notbackup")
expect("lua", B.Add(imp, "os.exit(1) SKALDBACKUP1"), "notbackup")
expect("header only", B.Add(imp, "SKALDBACKUP1^a^b"), "notbackup")
expect("short header", B.Add(imp, "SKALDBACKUP1^a^b" .. string.char(10) .. "body"), "badpart")
expect("newer", B.Add(imp, (p2:gsub("^SKALDBACKUP1", "SKALDBACKUP2"))), "newer")
local cand = B.Finish(imp)
RES = (#bad == 0 and cand == nil and B.Received(imp) == 1 and snap() == before) and "ok" or (table.concat(bad, " ") .. " got=" .. B.Received(imp))`,
});

run('a payload that is damaged inside, however well wrapped, is refused before anything is touched', {
  pre: BK_PRE,
  body: `${BK}
local good = B.Capture(SkaldCharDB)
local before = snap()
local function mine(state, override) return B.BuildFrom(state, override) end
local function copy() local c = {}; for k, v in pairs(good) do c[k] = v end; return c end
local bad = {}
local function refuse(label, state, override)
  local cand, code, why = B.Finish(importAll(mine(state, override).parts))
  if cand then bad[#bad + 1] = label end
end
local s1 = copy(); s1.entries = "not pages"; refuse("entries type", s1)
local s2 = copy(); s2.entries = { { t = 1, kind = "zone" }, { kind = "zone" } }; refuse("no t", s2)
local s3 = copy(); s3.entries = { { t = 1 } }; refuse("no kind", s3)
local s4 = copy(); s4.stats = "x"; refuse("stats type", s4)
local s5 = copy(); s5.guid = nil; refuse("no guid", s5)
local s6 = copy(); s6.previous = {}; refuse("excluded key", s6)
local s7 = copy(); s7.version = "three"; refuse("version type", s7)
local s8 = copy(); s8.entries = { [1] = { t = 1, kind = "zone" }, [3] = { t = 2, kind = "zone" } }; refuse("holes", s8)
refuse("count lies", copy(), { count = 999 })
refuse("period lies", copy(), { first = 1 })
refuse("guid lies", copy(), { guid = "OTHER" })
local deep = copy(); local node = deep; for i = 1, 20 do node.x = {}; node = node.x end
local okDeep = pcall(B.Serialize, deep)
local function bare(text) local v, err = B.Deserialize(text); return v == nil and err end
local inputs = { "", "[", "[]]", "{" .. string.char(34) .. "a" .. string.char(34) .. "}", "n12", "nnan;", "n1e999;", "n-;", "n0x10;", "q",
  "{n1;n1;n1;n2;}", "{[]t}", "[tt", string.char(34) .. "abc", string.char(34) .. "a" .. string.char(92) .. "zz" .. string.char(34), string.char(34) .. "a" .. string.char(92) .. string.char(34),
  "[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]", "t t" }
for _, text in ipairs(inputs) do if not bare(text) then bad[#bad + 1] = "parsed: " .. text end end
RES = (#bad == 0 and not okDeep and snap() == before) and "ok" or (table.concat(bad, " | ") .. " deepSaved=" .. tostring(okDeep))`,
});

run('only the character a backup came from can restore it, and a refusal leaves the diary as it was', {
  pre: BK_PRE,
  body: `${BK}
local state = B.Capture(SkaldCharDB)
state.guid = "SOMEONE-ELSE"
local cand = B.Finish(importAll(B.BuildFrom(state).parts))
local before = snap()
local ok, why = B.Apply(cand)
RES = (cand and B.CanRestore(cand.meta) == false and ok == false and why == "wrong character" and snap() == before) and "ok"
  or ("cand=" .. tostring(cand) .. " ok=" .. tostring(ok) .. " why=" .. tostring(why))`,
});

run('restoring replaces the diary, keeps the old one whole as the undo copy, and does not touch the archive of three', {
  pre: BK_PRE,
  body: `${BK}
local b = B.Build()
local backedUp = B.Serialize(B.Capture(SkaldCharDB))
local cand = B.Finish(importAll(b.parts))
local archiveBefore = B.Serialize(SkaldCharDB.previous)
-- the diary moves on after the backup
SkaldAPI.AddEntry("zone", "after the backup")
SkaldCharDB.pets.Rex = nil
SkaldCharDB.futureThing = nil
local moved = B.Serialize(B.Capture(SkaldCharDB))
local movedCount = #SkaldCharDB.entries
local ok = B.Apply(cand)
local now = SkaldCharDB
local function same(key, a, c) return a[key] ~= nil and c[key] ~= nil and B.Serialize(a[key]) == B.Serialize(c[key]) end
local kept = true
for _, key in ipairs({ "entries", "stats", "visited", "pets", "companions", "goals", "taxi", "futureThing", "guid", "version" }) do
  if not same(key, now, cand.state) then kept = false end
end
local afresh = next(now.flags) == nil and now.days == nil and now.today == nil and now.skills == nil and now.skillsInit == nil
local undo = B.UndoInfo()
local undoOk = undo and undo.count == movedCount and B.Serialize(undo.state) == moved
RES = (ok and kept and afresh and undoOk and B.Serialize(now.previous) == archiveBefore and #now.previous == 3 and now.restoreUndo ~= nil
  and now.futureThing and now.pets.Rex) and "ok"
  or ("ok=" .. tostring(ok) .. " kept=" .. tostring(kept) .. " afresh=" .. tostring(afresh) .. " undo=" .. tostring(undoOk))`,
});

run('undo brings the earlier diary back and sets the one replaced in its place; a second restore replaces the undo copy', {
  pre: BK_PRE,
  body: `${BK}
local parts = B.Build().parts
local function fresh() return B.Finish(importAll(parts)) end
SkaldAPI.AddEntry("zone", "after the backup")
local moved = B.Serialize(B.Capture(SkaldCharDB))
B.Apply(fresh())
local restored = B.Serialize(B.Capture(SkaldCharDB))
local ok1 = B.Undo()
local afterUndo = B.Serialize(B.Capture(SkaldCharDB))
local ok2 = B.Undo()
local afterRedo = B.Serialize(B.Capture(SkaldCharDB))
-- another restore: the undo copy is now the diary it replaced
B.Apply(fresh())
SkaldAPI.AddEntry("zone", "more")
local third = B.Serialize(B.Capture(SkaldCharDB))
local used = fresh()
B.Apply(used)
local undo = B.UndoInfo()
local thirdKept = undo and B.Serialize(undo.state) == third
local twice, whyTwice = B.Apply(used)       -- a candidate is put in place once
-- another character's undo copy is never brought back
SkaldCharDB.restoreUndo.state.guid = "SOMEONE-ELSE"
local before = snap()
local ok3, why3 = B.Undo()
RES = (ok1 and ok2 and afterUndo == moved and afterRedo == restored and thirdKept
  and twice == false and whyTwice == "already used" and not ok3 and why3 == "wrong character" and snap() == before) and "ok"
  or ("undo=" .. tostring(afterUndo == moved) .. " redo=" .. tostring(afterRedo == restored) .. " third=" .. tostring(thirdKept) .. " twice=" .. tostring(twice))`,
});

run('if the restore fails half-way the diary and the undo copy are put back as they were', {
  pre: BK_PRE,
  body: `${BK}
local parts = B.Build().parts
SkaldAPI.AddEntry("zone", "after the backup")
B.Apply(B.Finish(importAll(parts)))           -- one undo copy exists
SkaldAPI.AddEntry("zone", "later")
local before = snap()
local original = ns.ReadAfresh
ns.ReadAfresh = function() error("boom") end
local ok, why = B.Apply(B.Finish(importAll(parts)))
ns.ReadAfresh = original
RES = (ok == false and tostring(why):find("boom") and snap() == before) and "ok" or ("ok=" .. tostring(ok) .. " why=" .. tostring(why) .. " same=" .. tostring(snap() == before))`,
});

run('the windows: parts pasted into the restore box are checked, the button waits for all of them, and the question restores', {
  pre: BK_PRE,
  body: `${BK}
B.PART_LIMIT = 400
local b = B.Build()
local backedUp = B.Serialize(B.Capture(SkaldCharDB))
local exp = B.ShowExport()
local f = B.ShowRestore()
local function paste(text) f.edit:SetText(text); f.edit._OnTextChanged(f.edit, true) end
local log = {}
for i = 1, #b.parts - 1 do paste(b.parts[i]); log[#log + 1] = tostring(f.status._text):sub(1, 60) end
local waiting = f.restoreButton._enabled ~= true
paste(b.parts[1])      -- a repeat: said, harmless
paste(b.parts[#b.parts])
SkaldAPI.AddEntry("zone", "after the backup")
f.restoreButton._OnClick(f.restoreButton)
local asked = __popup == "SKALD_BACKUP_RESTORE"
StaticPopupDialogs["SKALD_BACKUP_RESTORE"].OnAccept()
RES = (exp and waiting and asked and B.Serialize(SkaldCharDB.entries) == B.Serialize(B.Finish(importAll(b.parts)).state.entries)) and "ok"
  or ("exp=" .. tostring(exp ~= nil) .. " waiting=" .. tostring(waiting) .. " asked=" .. tostring(asked) .. " status=" .. tostring(f.status._text) .. " | " .. log[1] .. " | " .. log[2])`,
});

// Search in the book ---------------------------------------------------------------------------------------------
const SEARCH_PAGES = `local R = ns.Search
local DAY = 86400
local es = {
  { t = NOW - 400 * DAY, kind = "quest", arg = "Old Debt", zone = "Elwynn Forest", m = false, idx = 1, tier = 1 },
  { t = NOW - 20 * DAY, kind = "quest", arg = "Miss\\195\\163o dos Fantasmas", zone = "Elwynn Forest", m = false, idx = 1, tier = 1 },
  { t = NOW - 10 * DAY, kind = "quest", arg = "Wanted: Jai'vhanel", q = 77, zone = "Darkshore", m = 1439, idx = 1, tier = 1, npc = "Thaelrin" },
  { t = NOW - 5 * DAY, kind = "note", arg = "Lembrei da Ponte de Ferro", zone = "Elwynn Forest", m = false, fav = true },
  { t = NOW - 3 * DAY, kind = "quest", arg = "Plain Task", zone = "Elwynn Forest", m = false, idx = 1, tier = 1, fav = true, favNote = "remember the Hatchet" },
  { t = NOW - 1 * DAY, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", m = false, idx = 1 },
}
local function ids(list) local o = {} for i, e in ipairs(list) do for j, x in ipairs(es) do if x == e then o[#o + 1] = j end end end return table.concat(o, ",") end
`;

run('search finds a page by its story, place, giver, note and favourite note, ignoring capitals and accents', {
  pre: SAVED('{}'),
  body: `${SEARCH_PAGES}
local a = ids((R.Run(es, "JAI'VHANEL")))
local b = ids((R.Run(es, "missao fantasmas")))
local c = ids((R.Run(es, "PONTE ferro")))
local d = ids((R.Run(es, "ponte zzz")))
local e = ids((R.Run(es, "hatchet")))
local f = ids((R.Run(es, "darkshore")))
local g = ids((R.Run(es, "thaelrin")))
RES = (a == "3" and b == "2" and c == "4" and d == "" and e == "5" and f == "3" and g == "3") and "ok"
  or ("jai=" .. a .. " missao=" .. b .. " ponte=" .. c .. " none=" .. d .. " hatchet=" .. e .. " place=" .. f .. " giver=" .. g)`,
});

run('search lists the newest first and the filters (kind, favourites, how far back) narrow it', {
  pre: SAVED('{}'),
  body: `${SEARCH_PAGES}
local all, total = R.Run(es, "")
local notes = ids((R.Run(es, "", { group = "notes" })))
local quests = ids((R.Run(es, "", { group = "quests" })))
local favs = ids((R.Run(es, "", { favs = true })))
local week = ids((R.Run(es, "", { days = 7, now = NOW })))
local month = ids((R.Run(es, "", { days = 30, now = NOW })))
local both = ids((R.Run(es, "plain", { group = "quests", favs = true })))
RES = (ids(all) == "6,5,4,3,2,1" and total == 6 and notes == "4" and quests == "5,3,2,1" and favs == "5,4" and week == "6,5,4"
  and month == "6,5,4,3,2" and both == "5") and "ok"
  or ("all=" .. ids(all) .. " notes=" .. notes .. " quests=" .. quests .. " favs=" .. favs .. " week=" .. week .. " month=" .. month .. " both=" .. both)`,
});

run('search lists at most Search.MAX pages but counts all of them', {
  pre: SAVED('{}'),
  body: `${SEARCH_PAGES}
local many = {}
for i = 1, 350 do many[i] = { t = NOW - (351 - i), kind = "note", arg = "note number " .. i, zone = "x", m = false } end
local list, total = R.Run(many, "note")
RES = (#list == R.MAX and total == 350 and list[1] == many[350] and list[#list] == many[350 - R.MAX + 1]) and "ok"
  or ("listed=" .. #list .. " total=" .. total)`,
});

run('search tells a changed page again after the pages are rewritten (layoutRev)', {
  pre: SAVED('{}'),
  body: `${SEARCH_PAGES}
local n = es[4]
local before = ids((R.Run(es, "ponte")))
n.arg = "Agora uma torre"
local stale = ids((R.Run(es, "torre")))      -- still the old text in the cache: the page is not told again yet
ns.layoutRev = (ns.layoutRev or 0) + 1
local fresh = ids((R.Run(es, "torre")))
local gone = ids((R.Run(es, "ponte")))
RES = (before == "4" and fresh == "4" and gone == "") and "ok" or ("before=" .. before .. " stale=" .. stale .. " fresh=" .. fresh .. " gone=" .. gone)`,
});

run('the search tab: typing lists the pages after a moment, a click opens the page, a hidden page is said', {
  pre: SAVED(`{
  { t = 1792000000, kind = "note", arg = "A nota da ponte", zone = "x", m = false, fav = true },
  { t = 1792000100, kind = "note", arg = "Outra coisa", zone = "x", m = false },
  { t = 1792000200, kind = "note", arg = "A ponte de novo", zone = "x", m = false },
}`),
  body: `local tab = btn("Search")
tab._OnClick(tab)
local p
for i = #frames, 1, -1 do if rawget(frames[i], "searchBox") then p = frames[i]; break end end
local box = p.searchBox
local function shown() local n = 0 for _, r in ipairs(p.rows) do if r._shown then n = n + 1 end end return n end
local idle = shown()
box:SetText("PONTE"); box._OnTextChanged(box, true)
local early = shown()          -- the word is looked for a moment after the last key
runTimers()
local found = shown()
local first = rawget(p.rows[1].text, "_text")
local firstPlain = (first:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
local opened
SkaldAPI.OpenEntry = function(e) opened = e; return true end
p.rows[1]._OnClick(p.rows[1])
local said
local realPrint = print
print = function(m) said = m end
SkaldAPI.OpenEntry = function() return false end
p.rows[2]._OnClick(p.rows[2])
print = realPrint
p.favButton._OnClick(p.favButton)
local onlyFav = shown()
RES = (idle == 0 and early == 0 and found == 2 and firstPlain == "A ponte de novo" and first:find("|cff9c1f12ponte|r", 1, true) and opened and opened.arg == "A ponte de novo"
  and said and said:find("does not show", 1, true) and onlyFav == 1) and "ok"
  or ("idle=" .. idle .. " early=" .. early .. " found=" .. found .. " first=" .. tostring(first) .. " opened=" .. tostring(opened and opened.arg) .. " said=" .. tostring(said) .. " onlyFav=" .. onlyFav)`,
});

run('the search tab has its words in every language', {
  pre: SAVED('{}'),
  body: `local miss = {}
for loc, L in pairs(ns.LOCALES) do
  for _, k in ipairs({ "SEARCH_TAB", "SEARCH_HINT", "SEARCH_FOUND", "SEARCH_SHOWN", "SEARCH_NONE", "SEARCH_KIND", "SEARCH_WHEN", "SEARCH_FAVS", "SEARCH_OPEN", "SEARCH_HIDDEN" }) do
    if type(L[k]) ~= "string" then miss[#miss + 1] = loc .. "." .. k end
  end
  if #L.SEARCH_KINDS ~= #ns.Search.GROUPS then miss[#miss + 1] = loc .. ".SEARCH_KINDS" end
  if #L.SEARCH_WHENS ~= #ns.Search.DAYS then miss[#miss + 1] = loc .. ".SEARCH_WHENS" end
end
RES = (#miss == 0) and "ok" or table.concat(miss, ",")`,
});

// The Bard's jukebox ---------------------------------------------------------------------------------------------
run('the Bard: play sends the number of the song, stop stops the music, next and before go round, a closed music option plays nothing', {
  pre: 'GetTime = function() return 100 end\n' + SAVED('{}'),
  body: `local B = ns.Bard
local ids = {}
for i, t in ipairs(B.TRACKS) do ids[#ids + 1] = t.id end
B.Play(2)
local first = MUSIC.played[#MUSIC.played - 1] == B.TRACKS[2].id and MUSIC.played[#MUSIC.played] == B.TRACKS[2].path and B.playing == 2
B.Step(1)
local nextOk = B.playing == 3 and MUSIC.played[#MUSIC.played - 1] == B.TRACKS[3].id
B.Play(#B.TRACKS); B.Step(1)
local wrapNext = B.playing == 1
B.Step(-1)
local wrapPrev = B.playing == #B.TRACKS
B.Stop()
local stopped = B.playing == nil and MUSIC.stopped >= 1
B.last = nil; B.Step(1)
local fromNothing = B.playing == 1
B.Stop()
B.Play(4); B.Stop(); B.Play(B.last)
local again = B.playing == 4 and MUSIC.played[#MUSIC.played - 1] == B.TRACKS[4].id
B.Stop()
local before = #MUSIC.played
MUSIC.cvars.Sound_EnableMusic = "0"
local refused = B.Play(1) == false and #MUSIC.played == before and B.playing == nil
MUSIC.cvars.Sound_EnableMusic = "1"
B.SetVolume(0.25)
local vol = MUSIC.cvars.Sound_MusicVolume == "0.25" and math.abs(B.Volume() - 0.25) < 0.001
B.SetVolume(7)
local clamp = MUSIC.cvars.Sound_MusicVolume == "1.00"
RES = (first and nextOk and wrapNext and wrapPrev and stopped and fromNothing and again and refused and vol and clamp and #ids == #B.TRACKS and #ids >= 30) and "ok"
  or ("first=" .. tostring(first) .. " next=" .. tostring(nextOk) .. " wrapNext=" .. tostring(wrapNext) .. " wrapPrev=" .. tostring(wrapPrev)
    .. " stopped=" .. tostring(stopped) .. " fromNothing=" .. tostring(fromNothing) .. " refused=" .. tostring(refused) .. " vol=" .. tostring(vol) .. " clamp=" .. tostring(clamp))`,
});

run('the Bard tab: a click on a song plays it and shows it, a second click stops it, the buttons work, the clock counts, and the words are in every language', {
  pre: 'GetTime = function() return 100 end\n' + SAVED('{}'),
  body: `local tab = btn("Bard")
tab._OnClick(tab)
local p
for i = #frames, 1, -1 do if rawget(frames[i], "rows") and rawget(frames[i], "mainButton") then p = frames[i]; break end end
local B = ns.Bard
B.Stop()
p.rows[3]._OnClick(p.rows[3])
local playsRow = B.playing == 3 and rawget(p.song, "_text") == ns.LOCALES.enUS.BARD_TRACKS[3] and rawget(p.state, "_text") == ns.LOCALES.enUS.BARD_PLAYING
  and tostring(rawget(p.rows[3].disc, "_tex")):find("bard_pause", 1, true) and tostring(rawget(p.rows[2].disc, "_tex")):find("bard_play", 1, true)
p.nextButton._OnClick(p.nextButton)
local nextOk = B.playing == 4
p.prevButton._OnClick(p.prevButton)
p.prevButton._OnClick(p.prevButton)
local prevOk = B.playing == 2
p.rows[2]._OnClick(p.rows[2])
local stopsRow = B.playing == nil and rawget(p.state, "_text") == ns.LOCALES.enUS.BARD_STOPPED and rawget(p.clock, "_text") == ""
p.mainButton._OnClick(p.mainButton)
local mainPlays = B.playing == 2   -- after a stop the big button plays the piece that was playing, not the first
p.mainButton._OnClick(p.mainButton)
local mainStops = B.playing == nil
p.rows[4]._OnClick(p.rows[4]); p.Animate()
local pictureOn = rawget(p.rise, "_shown") == true and rawget(p.bars, "_shown") == true and rawget(p.tabNote, "_shown") == true
  and tostring(rawget(p.rise, "_tex")):find("bard_notes_", 1, true) and tostring(rawget(p.bars, "_tex")):find("bard_eq_", 1, true)
p.rows[4]._OnClick(p.rows[4]); p.Animate()
local pictureOff = rawget(p.rise, "_shown") ~= true and rawget(p.bars, "_shown") ~= true and rawget(p.tabNote, "_shown") ~= true
local ticks = 1000
GetTime = function() ticks = ticks + 1; return ticks end   -- each song begins at its own moment
local open = false
SkaldAPI.IsBookOpen = function() return open end
local opened
SkaldAPI.OpenSection = function(id) opened = id end
B.Play(5); p.Animate()
local miniShown = rawget(p.mini, "_shown") == true
open = true; p.Animate()
local miniHidesOpen = rawget(p.mini, "_shown") ~= true
open = false; p.Animate()
p.mini._OnClick(p.mini, "LeftButton")
local miniOpens = opened == "bard"
p.mini._OnClick(p.mini, "RightButton"); p.Animate()
local miniDismissed = rawget(p.mini, "_shown") ~= true
B.Play(5); p.Animate()
local miniBack = rawget(p.mini, "_shown") == true
B.Stop(); p.Animate()
local miniGone = rawget(p.mini, "_shown") ~= true
local miniOk = miniShown and miniHidesOpen and miniOpens and miniDismissed and miniBack and miniGone
local clockOk = B.Clock(65) == "01:05" and B.Clock(0) == "00:00" and B.Clock(-3) == "00:00"
MUSIC.cvars.Sound_EnableMusic = "0"
p.rows[1]._OnClick(p.rows[1])
local offSaid = B.playing == nil and rawget(p.off, "_text") == ns.LOCALES.enUS.BARD_MUSIC_OFF
MUSIC.cvars.Sound_EnableMusic = "1"
local miss = {}
for _, loc in ipairs({ "enUS", "ptBR", "frFR" }) do
  local L = ns.LOCALES[loc]
  for _, k in ipairs({ "BARD_TAB", "BARD_LEFT", "BARD_RIGHT", "BARD_PLAYING", "BARD_STOPPED", "BARD_PICK", "BARD_VOLUME", "BARD_VOL_NOTE", "BARD_MUSIC_OFF", "BARD_TIP_PLAY", "BARD_TIP_STOP", "BARD_TIP_PREV", "BARD_TIP_NEXT" }) do
    if type(L[k]) ~= "string" or L[k] == "" then miss[#miss + 1] = loc .. "." .. k end
  end
  if type(L.BARD_TRACKS) ~= "table" or #L.BARD_TRACKS ~= #B.TRACKS then miss[#miss + 1] = loc .. ".BARD_TRACKS" end
end
RES = (playsRow and nextOk and prevOk and stopsRow and mainPlays and mainStops and pictureOn and pictureOff and miniOk and clockOk and offSaid and #miss == 0) and "ok"
  or ("playsRow=" .. tostring(playsRow) .. " next=" .. tostring(nextOk) .. " prev=" .. tostring(prevOk) .. " stopsRow=" .. tostring(stopsRow)
    .. " mainPlays=" .. tostring(mainPlays) .. " mainStops=" .. tostring(mainStops) .. " picOn=" .. tostring(pictureOn) .. " picOff=" .. tostring(pictureOff) .. " mini=" .. tostring(miniShown) .. tostring(miniHidesOpen) .. tostring(miniOpens) .. tostring(miniDismissed) .. tostring(miniBack) .. tostring(miniGone) .. " clock=" .. tostring(clockOk) .. " offSaid=" .. tostring(offSaid) .. " missing: " .. table.concat(miss, ","))`,
});

run('the Bard: the list has pages the corners turn, the song that plays brings its page, and the order left to chance never repeats the song and goes back through what played', {
  pre: 'GetTime = function() return 100 end\n' + SAVED('{}'),
  body: `local B = ns.Bard
local tab = btn("Bard"); tab._OnClick(tab)
local p
for i = #frames, 1, -1 do if rawget(frames[i], "shuffleCheck") then p = frames[i]; break end end
B.Stop(); B.last = nil; B.history = {}; B.page = 1
local pages = B.Pages() == math.ceil(#B.TRACKS / 6) and B.Pages() >= 5
local rows1 = p.rows[1]._shown == true and rawget(p.rows[1], "song") == 1 and rawget(p.rows[6], "song") == 6
p.pager.Turn(1)
p.pager.Turn(0)
local turned = B.page == 2
p.mainButton._OnClick(p.mainButton)   -- nothing played yet, not by chance: the first song, and the list shows its page
local firstBack = B.playing == 1 and B.page == 1
B.Play(#B.TRACKS)
local follows = B.page == B.Pages()
p.Refresh()
local lastRows = 0
for _, r in ipairs(p.rows) do if rawget(r, "song") then lastRows = lastRows + 1 end end
local partial = lastRows == #B.TRACKS - (B.Pages() - 1) * 6
local atEnd = not p.pager.CanNext() and p.pager.CanPrev()
SkaldDB.bardShuffle = true
B.Stop(); B.last = nil; B.history = {}
B.Play(5)
local never, distinct = true, {}
for k = 1, 60 do
  local before = B.playing
  B.Step(1)
  if B.playing == before then never = false end
  distinct[B.playing] = true
end
local spread = 0
for _ in pairs(distinct) do spread = spread + 1 end
B.Play(7); B.Play(9); B.Step(1)
local landed = B.playing
B.Step(-1)
local wentBack = B.playing == 9
B.Step(-1)
local wentBack2 = B.playing == 7
SkaldDB.bardShuffle = false
B.Play(1); B.Step(1)
local ordered = B.playing == 2
RES = (pages and rows1 and turned and firstBack and follows and partial and atEnd and never and spread >= 10 and wentBack and wentBack2 and ordered) and "ok"
  or ("pages=" .. tostring(pages) .. " rows1=" .. tostring(rows1) .. " turned=" .. tostring(turned) .. " firstBack=" .. tostring(firstBack) .. " follows=" .. tostring(follows)
    .. " partial=" .. tostring(partial) .. "(" .. lastRows .. "/" .. B.Pages() .. "/" .. #B.TRACKS .. ")" .. " atEnd=" .. tostring(atEnd) .. " never=" .. tostring(never) .. " spread=" .. spread .. " back=" .. tostring(wentBack) .. tostring(wentBack2) .. " ordered=" .. tostring(ordered))`,
});

run('the Bard goes on by itself: when a song has run its length the next begins (by chance with Shuffle), nothing changes before, a stopped Bard stays stopped, and every song has a length', {
  pre: SAVED('{}'),
  body: `local B = ns.Bard
local now = 5000
GetTime = function() return now end
local allLen = true
for _, t in ipairs(B.TRACKS) do if type(t.len) ~= "number" or t.len < 10 or t.len > 400 then allLen = false end end
SkaldDB.bardShuffle = false
B.Stop(); B.last = nil; B.history = {}
B.Play(3)
local len = B.TRACKS[3].len
now = now + len - 5
local early = B.Tick() == false and B.playing == 3
now = now + 5
local advanced = B.Tick() == true and B.playing == 4 and B.since == now
now = now + 1
local notYet = B.Tick() == false and B.playing == 4
B.Play(#B.TRACKS); now = now + B.TRACKS[#B.TRACKS].len
local wraps = B.Tick() == true and B.playing == 1
SkaldDB.bardShuffle = true
B.Play(2); now = now + B.TRACKS[2].len
local chance = B.Tick() == true and B.playing ~= 2 and B.playing ~= nil
SkaldDB.bardShuffle = false
B.Stop(); now = now + 1000
local stays = B.Tick() == false and B.playing == nil
B.Play(1); now = now + B.TRACKS[1].len
MUSIC.cvars.Sound_EnableMusic = "0"
local quits = B.Tick() == true and B.playing == nil
MUSIC.cvars.Sound_EnableMusic = "1"
RES = (allLen and early and advanced and notYet and wraps and chance and stays and quits) and "ok"
  or ("allLen=" .. tostring(allLen) .. " early=" .. tostring(early) .. " advanced=" .. tostring(advanced) .. " notYet=" .. tostring(notYet) .. " wraps=" .. tostring(wraps)
    .. " chance=" .. tostring(chance) .. " stays=" .. tostring(stays) .. " quits=" .. tostring(quits))`,
});

run('the Bard notice: five looks stepped through on the Bard tab, a look just chosen shows at once with the book open, the button Stop of a picture stops, and the names are in every language', {
  pre: 'GetTime = function() return 100 end\n' + SAVED('{}'),
  body: `local B = ns.Bard
local tab = btn("Bard"); tab._OnClick(tab)
local p
for i = #frames, 1, -1 do if rawget(frames[i], "hudName") then p = frames[i]; break end end
SkaldDB.bardHud = nil
SkaldAPI.IsBookOpen = function() return true end
B.Stop(); B.last = nil
p.Refresh()
local default = B.HudStyle() == "bar"
local function art() return tostring(rawget(p.mini.tex or p.mini, "_tex")) end
p.hudNext._OnClick(p.hudNext)
local scroll = SkaldDB.bardHud == "scroll" and p.mini._shown == true   -- shown with the book open, for a moment, though nothing plays
local stopArt = tostring(rawget(p.miniStopArt.tex, "_tex")):find("hud_scroll_stop", 1, true) ~= nil
p.hudNext._OnClick(p.hudNext); p.hudNext._OnClick(p.hudNext)
local medal = SkaldDB.bardHud == "medal" and tostring(rawget(p.miniStopArt.tex, "_tex")):find("hud_medal_stop", 1, true) ~= nil
p.hudNext._OnClick(p.hudNext)
local plate = SkaldDB.bardHud == "plate" and p.miniStopArt._shown ~= true
p.hudNext._OnClick(p.hudNext)
local round = SkaldDB.bardHud == "bar"
p.hudBack._OnClick(p.hudBack)
local back = SkaldDB.bardHud == "plate"
p.hudBack._OnClick(p.hudBack)
local named = rawget(p.hudName.text, "_text") == string.format(ns.LOCALES.enUS.BARD_HUD_LABEL, ns.LOCALES.enUS.BARD_HUDS[4])
SkaldDB.bardHud = "wood"; p.ApplyHud()
B.Play(1)
SkaldAPI.IsBookOpen = function() return false end
p.Animate()
local shown = p.mini._shown == true
SkaldDB.bardShuffle = false
B.Play(5)
p.miniNext._OnClick(p.miniNext)
local skipNext = B.playing == 6
p.miniPrev._OnClick(p.miniPrev); p.miniPrev._OnClick(p.miniPrev)
local skipPrev = B.playing == 4
p.miniStopArt._OnClick(p.miniStopArt)
local stopped = B.playing == nil and skipNext and skipPrev
local miss = {}
for _, loc in ipairs({ "enUS", "ptBR", "frFR" }) do
  local L = ns.LOCALES[loc]
  if type(L.BARD_HUD_LABEL) ~= "string" or not L.BARD_HUD_LABEL:find("%s", 1, true) or type(L.BARD_HUDS) ~= "table" or #L.BARD_HUDS ~= 5 then miss[#miss + 1] = loc end
end
RES = (default and scroll and stopArt and medal and plate and round and back and named and shown and stopped and #miss == 0) and "ok"
  or ("default=" .. tostring(default) .. " scroll=" .. tostring(scroll) .. " stopArt=" .. tostring(stopArt) .. " medal=" .. tostring(medal) .. " plate=" .. tostring(plate)
    .. " round=" .. tostring(round) .. " back=" .. tostring(back) .. " named=" .. tostring(named) .. " shown=" .. tostring(shown) .. " stopped=" .. tostring(stopped) .. " missing: " .. table.concat(miss, ","))`,
});

// every picture of the notice is in the folder
{
  const names = [];
  for (const k of ['bar', 'scroll', 'wood', 'medal']) names.push('hud_' + k, 'hud_' + k + '_icon', 'hud_' + k + '_stop');
  const lost = names.filter(n => !fs.existsSync(path.join(ADDONS, 'Skald', 'Textures', 'skald2', n + '.tga')));
  if (!lost.length) console.log('  ok    every picture of the looks of the Bard notice is in the folder (' + names.length + ')');
  else { failed++; console.log('  FAIL  pictures of the looks of the Bard notice missing: ' + lost.join(', ')); }
}

run('the column of tabs: ten for a hunter, always; Settings is one tab whose three pages (Style, Notices, Options) are turned by the corners of the book; the cover has its tab; the open tab has its own picture; the column stays above the foot of the cover', {
  pre: SAVED('{}'),
  body: `local function column()
  local n, lowest, names = 0, 0, {}
  for _, f in ipairs(frames) do
    local top = rawget(f, "top")
    if type(top) == "number" and rawget(f, "tex") and rawget(f, "text") and f._shown == true then
      n = n + 1; lowest = math.max(lowest, -top + 34); names[#names + 1] = tostring(rawget(f.text, "_text"))
    end
  end
  return n, lowest, table.concat(names, ",")
end
local function lit(label) local b = btn(label); return b and b.active == true end
local n0, low0, names0 = column()
local coverLit = lit("Cover")
local artOn = tostring(rawget(btn("Cover").tex, "_tex")):find("tab_active", 1, true) and tostring(rawget(btn("Days").tex, "_tex")):find("tab_idle", 1, true)
local settings = btn("Settings"); settings._OnClick(settings)
local n1, low1, names1 = column()
local settingsLit = lit("Settings")
local panel
for i = #frames, 1, -1 do if rawget(frames[i], "subs") then panel = frames[i]; break end end
local page1 = panel.pager.Current() == 1 and panel.subs[1]._shown == true and panel.subs[2]._shown ~= true
local folio1 = panel.pager.Folio()
panel.pager.Turn(1)
local page2 = panel.pager.Current() == 2 and panel.subs[2]._shown == true and panel.subs[1]._shown ~= true and panel.pager.Folio() == folio1 + 2
panel.pager.Turn(1); panel.pager.Turn(1)
local page3 = panel.pager.Current() == 3 and not panel.pager.CanNext() and panel.pager.CanPrev()
panel.GoTo("style")
local goTo = panel.pager.Current() == 1 and not panel.pager.CanPrev()
local days = btn("Days"); days._OnClick(days)
local n2, _, names2 = column()
settings._OnClick(settings)
local back = lit("Settings")
RES = (n0 == 10 and names0:find("Cover", 1, true) and coverLit and artOn and n1 == 10 and n2 == 10 and settingsLit and back
  and not names1:find("Style", 1, true) and not names1:find("Options", 1, true)
  and page1 and page2 and page3 and goTo and low0 <= 580 - 56 and low1 <= 580 - 56) and "ok"
  or ("closed=" .. n0 .. " (" .. names0 .. ") coverLit=" .. tostring(coverLit) .. " art=" .. tostring(artOn) .. " open=" .. n1 .. " (" .. names1 .. ") settingsLit=" .. tostring(settingsLit)
    .. " pages=" .. tostring(page1) .. tostring(page2) .. tostring(page3) .. tostring(goTo) .. " after=" .. n2 .. " back=" .. tostring(back) .. " lowest=" .. low0 .. "/" .. low1)`,
});

run('every page the search can list opens in the real book, the summary of a closed day included', {
  pre: `local yesterday = NOW - 86400
${SAVED(`{
  { t = yesterday, kind = "quest", arg = "Plain Task", zone = "Elwynn Forest", m = false, idx = 1, tier = 1, fav = true },
  { t = yesterday + 60, kind = "note", arg = "A lembrança da ponte", zone = "Elwynn Forest", m = false },
  { t = yesterday + 120, kind = "zone", arg = "Elwynn Forest", zone = "Elwynn Forest", m = false, idx = 1 },
  { t = yesterday + 3600, kind = "day", arg = date("%Y-%m-%d", yesterday), zone = "Elwynn Forest", m = false, idx = 1,
    day = { q = 2, l = 0, d = 0, z = 1, u = 0, b = 0, a = 0, k = 5, s = 1300 } },
}`)}`,
  body: `local R = ns.Search
local list = R.Run(SkaldCharDB.entries, "")
local kinds, bad = {}, {}
for _, e in ipairs(list) do
  kinds[e.kind] = true
  if SkaldAPI.OpenEntry(e) ~= true then bad[#bad + 1] = tostring(e.kind) end
end
RES = (kinds.quest and kinds.note and kinds.zone and kinds.day and #bad == 0) and "ok"
  or ("kinds: quest=" .. tostring(kinds.quest) .. " note=" .. tostring(kinds.note) .. " zone=" .. tostring(kinds.zone) .. " day=" .. tostring(kinds.day) .. " did not open: " .. table.concat(bad, ","))`,
});

run('search paints the words found, cuts a long text where the first one shows, and keeps a bar of the text from being read as a code', {
  pre: SAVED('{}'),
  body: `local R = ns.Search
local C = "ff9c1f12"
local function H(text, q, limit) return R.Highlight(text, R.Terms(q), C, limit) end
local a = H("Miss\\195\\163o dos Fantasmas", "MISSAO fant")
local b = H("o mar, o mar e o mar", "mar")
local c = H("ponte pontes", "pont ponte")
local long = string.rep("palavra ", 30) .. "tesouro " .. string.rep("fim ", 30)
local d = H(long, "tesouro", 100)
local e = H("a|nb ponte", "ponte")
local f = H("nada a destacar aqui", "")
local ok1 = a == "|c" .. C .. "Miss\\195\\163o|r dos |c" .. C .. "Fant|rasmas"
local ok2 = b == "o |c" .. C .. "mar|r, o |c" .. C .. "mar|r e o |c" .. C .. "mar|r"
local ok3 = c == "|c" .. C .. "ponte|r |c" .. C .. "ponte|rs"
local ok4 = d:sub(1, 3) == "..." and d:find("|c" .. C .. "tesouro|r", 1, true) and d:sub(-3) == "..." and #d < 160
local ok5 = e == "a||nb |c" .. C .. "ponte|r"
local ok6 = f == "nada a destacar aqui"
RES = (ok1 and ok2 and ok3 and ok4 and ok5 and ok6) and "ok" or ("accents=" .. tostring(ok1) .. " repeat=" .. tostring(ok2) .. " joined=" .. tostring(ok3) .. " cut=" .. tostring(ok4) .. " bar=" .. tostring(ok5) .. " plain=" .. tostring(ok6) .. " d=" .. d)`,
});

run('the search tab: the kind and the time are chosen from a list, one list open at a time, and a choice away from the usual shows as chosen', {
  pre: SAVED(`{
  { t = NOW - 86400, kind = "note", arg = "uma nota rara", zone = "x", m = false },
  { t = NOW - 86400 * 40, kind = "quest", arg = "velha tarefa rara", zone = "x", m = false, idx = 1, tier = 1 },
  { t = NOW - 3600, kind = "quest", arg = "tarefa rara de hoje", zone = "x", m = false, idx = 1, tier = 1 },
}`),
  body: `local tab = btn("Search")
tab._OnClick(tab)
local p
for i = #frames, 1, -1 do if rawget(frames[i], "searchBox") then p = frames[i]; break end end
local function shown() local n = 0 for _, r in ipairs(p.rows) do if r._shown == true then n = n + 1 end end return n end
p.searchBox:SetText("rara"); p.searchBox._OnTextChanged(p.searchBox, true); runTimers()
local base = shown()                                  -- the three pages
local closed = p.kindList._shown ~= true and p.whenList._shown ~= true
p.kindButton._OnClick(p.kindButton)
local kindOpen = p.kindList._shown == true
p.whenButton._OnClick(p.whenButton)
local oneAtATime = p.whenList._shown == true and p.kindList._shown ~= true
p.whenItems[3]._OnClick(p.whenItems[3])             -- the last 30 days
local pickedClosed = p.whenList._shown ~= true
local month = shown()
local whenText = rawget(p.whenButton.text, "_text")
local whenChosen = p.whenButton.active
p.kindButton._OnClick(p.kindButton)
p.kindItems[2]._OnClick(p.kindItems[2])             -- quests
local quests = shown()
local kindText = rawget(p.kindButton.text, "_text")
p.kindItems[8]._OnClick(p.kindItems[8])             -- notes
local notes = shown()
p.kindItems[1]._OnClick(p.kindItems[1])             -- everything again
p.whenItems[1]._OnClick(p.whenItems[1])             -- any time
local all = shown()
RES = (base == 3 and closed and kindOpen and oneAtATime and pickedClosed and month == 2 and quests == 1 and notes == 1 and all == 3
  and whenText:find("30", 1, true) and kindText:find("Quests", 1, true) and whenChosen == true and p.kindButton.active == false) and "ok"
  or ("base=" .. base .. " closed=" .. tostring(closed) .. " open=" .. tostring(kindOpen) .. " one=" .. tostring(oneAtATime) .. " picked=" .. tostring(pickedClosed)
    .. " month=" .. month .. " quests=" .. quests .. " notes=" .. notes .. " all=" .. all .. " when=" .. tostring(whenText) .. " kind=" .. tostring(kindText) .. " chosen=" .. tostring(whenChosen))`,
});

run('the search tab shows the picture of each page, the star of a favourite and a faint word in the empty box', {
  pre: SAVED(`{
  { t = NOW - 7200, kind = "note", arg = "a nota rara", zone = "x", m = false, fav = true },
  { t = NOW - 3600, kind = "quest", arg = "a tarefa rara", zone = "x", m = false, idx = 1, tier = 3 },
}`),
  body: `local tab = btn("Search")
tab._OnClick(tab)
local p
for i = #frames, 1, -1 do if rawget(frames[i], "searchBox") then p = frames[i]; break end end
p.searchBox:SetText(""); p.searchBox._OnTextChanged(p.searchBox, true)
local before = p.placeholder._shown
p.searchBox:SetText("rara"); p.searchBox._OnTextChanged(p.searchBox, true); runTimers()
local typed = p.placeholder._shown
local quest, note = p.rows[1], p.rows[2]
RES = (before == true and typed == false and rawget(quest.icon, "_tex") and rawget(quest.icon, "_tex"):find("seal3", 1, true)
  and rawget(note.icon, "_tex") and rawget(note.icon, "_tex"):find("dd_scroll", 1, true) and note.star._shown == true and quest.star._shown == false
  and rawget(p.rightTitle, "_text") == "Results") and "ok"
  or ("placeholder " .. tostring(before) .. "/" .. tostring(typed) .. " quest=" .. tostring(rawget(quest.icon, "_tex")) .. " note=" .. tostring(rawget(note.icon, "_tex"))
    .. " stars " .. tostring(note.star._shown) .. "/" .. tostring(quest.star._shown) .. " title=" .. tostring(rawget(p.rightTitle, "_text")))`,
});

run('the look of the tabs: the Style tab steps through five looks, each tab takes the picture and the ink of the look, the ribbon has a colour for each shut tab, and the choice is kept', {
  pre: SAVED('{}'),
  body: `local p
local st = btn("Settings"); st._OnClick(st)
for i = #frames, 1, -1 do if rawget(frames[i], "lookName") then p = frames[i]; break end end
local days, cover = btn("Days"), btn("Cover")
local function pic(b) return tostring(rawget(b.tex, "_tex")) end
local first = pic(days):find("tab_idle", 1, true) ~= nil and SkaldDB.tabStyle == nil
p.lookNext._OnClick(p.lookNext)
local ribbon = SkaldDB.tabStyle == "ribbon" and pic(days):find("tab_ribbon_red_idle", 1, true) ~= nil and rawget(p.lookName.text, "_text") == ns.LOCALES.enUS.TAB_LOOKS[2] and pic(cover):find("tab_ribbon_red_idle", 1, true) ~= nil and pic(btn("Settings")):find("tab_ribbon_active", 1, true) ~= nil   -- Settings is the open one
p.lookNext._OnClick(p.lookNext); p.lookNext._OnClick(p.lookNext)
local parchment = SkaldDB.tabStyle == "parchment" and pic(days):find("tab_parchment_idle", 1, true) ~= nil
p.lookNext._OnClick(p.lookNext); p.lookNext._OnClick(p.lookNext)
local round = SkaldDB.tabStyle == "leather" and pic(days):find("tab_idle", 1, true) ~= nil   -- five steps go round
p.lookBack._OnClick(p.lookBack)
local back = SkaldDB.tabStyle == "wood" and pic(days):find("tab_wood_idle", 1, true) ~= nil
local miss = {}
for _, loc in ipairs({ "enUS", "ptBR", "frFR" }) do
  local L = ns.LOCALES[loc]
  if type(L.OPT_TABLOOK) ~= "string" or type(L.TAB_LOOKS) ~= "table" or #L.TAB_LOOKS ~= 5 then miss[#miss + 1] = loc end
end
RES = (first and ribbon and parchment and round and back and #miss == 0) and "ok"
  or ("first=" .. tostring(first) .. " ribbon=" .. tostring(ribbon) .. " parchment=" .. tostring(parchment) .. " round=" .. tostring(round) .. " back=" .. tostring(back) .. " missing: " .. table.concat(miss, ","))`,
});

// every picture a look can ask for is in the folder
{
  const src = fs.readFileSync(path.join(ADDONS, 'Skald', 'Skald.lua'), 'utf8');
  const names = new Set();
  for (const m of src.matchAll(/(?:idle|active) = "(tab_[a-z_%]+)"/g)) {
    if (m[1].includes('%s')) for (const c of ['red', 'blue', 'green', 'gold']) names.add(m[1].replace('%s', c));
    else names.add(m[1]);
  }
  const lost = [...names].filter(n => !fs.existsSync(path.join(ADDONS, 'Skald', 'Textures', 'skald2', n + '.tga')));
  if (names.size >= 11 && !lost.length) console.log('  ok    every picture of the looks of the tabs is in the folder (' + names.size + ')');
  else { failed++; console.log('  FAIL  pictures of the looks of the tabs: ' + names.size + ' named, missing: ' + lost.join(', ')); }
}

console.log(failed ? `\n${failed} regression(s) FAILED` : '\nAll regressions passed');
process.exit(failed ? 1 : 0);
