// Regression scenarios: things that went wrong once (or nearly), each run in a fresh simulated game.
// Run: node tools/regressions.js   (also run by checks.js; exit code 1 when one fails)
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');

const ADDONS = path.resolve(__dirname, '../../..');
const FILES = [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua'], ['ZC', 'ZoneCard.lua']];
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
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns); assert(load(ZC,"=Z"))("Skald",ns)
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
RES = (unready and first and later and mountPages == 1 and withPets - without == 40) and "ok" or ("unready=" .. tostring(unready) .. " first=" .. tostring(first) .. " later=" .. tostring(later) .. " pages=" .. count("goal") .. " " .. (function() local t = {} for _, x in ipairs(SkaldCharDB.entries) do if x.kind == "goal" then t[#t+1] = x.arg end end return table.concat(t, ",") end)())`,
});

run('goals that came with a later list are marked quietly in a diary that already looked, and the points follow the seals', {
  pre: SAVED('{}', 'version = 99, goalsInit = true, goals = { flights5 = { t = 5 } }, taxi = { true, true, true, true, true, true, true }, stats = { counts = { quest = 120, dungeon = 3, boss = 2, kill = 600 }, deathZones = {}, tiers = {}, played = 1, first = 1 }'),
  body: `local g = SkaldCharDB.goals
local earned, possible = ns.GoalScore()
-- flights5 was there before (5 points); the new ones (level 10 and 20, quests50, dungeons, bosses1, kills500) came quietly
local quiet = g.level10 and g.level10.retro and g.level20 and g.level20.retro and g.quests50 and g.quests50.retro and g.kills500 and g.kills500.retro
RES = (count("goal") == 0 and quiet and SkaldCharDB.goalsVer == 3 and earned > 5 and possible > 800 and ns.GoalPoints("level60") == 100
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

console.log(failed ? `\n${failed} regression(s) FAILED` : '\nAll regressions passed');
process.exit(failed ? 1 : 0);
