// Rough timing with a big diary (3000 pages): is anything slow? Run: node tools/perf.js
// fengari is slower than the game's Lua, so read the numbers as relative, not as milliseconds in game.
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');
const ADDONS = path.resolve(__dirname, '../../..');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const run = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
run(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'));
for (const [k, f] of [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua'], ['ZC', 'ZoneCard.lua']])
  set(k, fs.readFileSync(path.join(ADDONS, 'Skald', f), 'utf8'));
run(`__locale="enUS"; frames={}; SkaldDB={}; SkaldCharDB=nil; FONTS={}
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
local function runTimers() local t=TIMERS TIMERS={} for _,fn in ipairs(t) do fn() end end
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 100000 end; function UnitXP() return 0 end
function UnitLevel() return 40 end; function UnitName() return "Tester" end; function UnitExists() return false end
function GetQuestID() return 0 end; function UnitGUID() return "P1" end
function UnitClass() return "Warrior","WARRIOR" end; function UnitRace() return "Human","Human" end
function SetPortraitTexture() end; function GetZoneText() return "Elwynn Forest" end
NOW = os.time({year=2026,month=1,day=1,hour=8,min=0,sec=0}); function time(t) if t then return os.time(t) end return NOW end
function GetStatisticsCategoryList() return {} end; function GetStatistic() return "--" end; function GetMoney() return 0 end
Minimap=CreateFrame("Frame","Minimap",UIParent); function GetCursorPosition() return 100,100 end
local ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns)
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns); assert(load(ZC,"=Z"))("Skald",ns)
local function fire(ev,...) for _,f in ipairs(frames) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN"); runTimers()
local function clock(label, fn, n) local t=os.clock(); for i=1,(n or 1) do fn() end return string.format("%-34s %8.1f ms", label, (os.clock()-t)*1000/(n or 1)) end
local out = {}
-- fill: 3000 pages over 120 days
local kinds = { "quest", "loot", "zone", "death", "level", "boss" }
local zones = { "Elwynn Forest", "Westfall", "Duskwood", "Redridge Mountains" }
for i = 1, 3000 do
  NOW = NOW + 1800
  local k = kinds[i % #kinds + 1]
  local e = { t = NOW, kind = k, zone = zones[i % #zones + 1], arg = (k == "level") and (i % 60) or ("Thing " .. i), idx = 1, tier = i % 5, m = 1429, zm = 1429, q = 100 + i }
  if k == "loot" then e.arg = "|cffffffff|Hitem:" .. (1000 + i) .. "::::::::15:::::|h[Item " .. i .. "]|h|r"; e.cat = "sword" end
  table.insert(SkaldCharDB.entries, e)
end
local win = _G.SkaldFrame
out[#out+1] = clock("show the book (cover)", function() win:Show(); if win._OnShow then win._OnShow(win) end end)
out[#out+1] = clock("Refresh() with 3000 pages", function() win:Refresh() end, 3)
out[#out+1] = clock("go to a page far away", function() win:GoToPage(60) end, 3)
out[#out+1] = clock("AddEntry (new page) x50", function() fire("PLAYER_DEAD") end, 50)
-- the map markers for a big diary on one map (3000 pages at random places)
local big = {}
math.randomseed(7)
for i = 1, 3000 do big[i] = { kind = "quest", tier = i % 5, m = 1439, x = math.random(), y = math.random(), t = NOW + i } end
local keep = function() return true end
out[#out+1] = clock("map markers (3000 pages, one map)", function() SkaldAPI.AtlasPure.Cluster(big, 1439, 1000, 667, keep) end, 3)
out[#out+1] = clock("/skald tidy (Relocalize + Tidy)", function() SlashCmdList.SKALD("tidy") end, 3)
out[#out+1] = clock("export text (all pages)", function() SlashCmdList.SKALD("export") end, 1)
-- the newer paths: goals, names hidden in exports (200 companions), the text for the web Reader
SkaldCharDB.companions = {}
for i = 1, 200 do SkaldCharDB.companions["Player" .. i] = { first = 1, last = 1, seen = 1, shared = true } end
for i = 1, 3000, 25 do SkaldCharDB.entries[i].with = { "Player" .. (i % 200 + 1), "Player" .. ((i + 7) % 200 + 1) } end
out[#out+1] = clock("goal facts (3000 pages)", function() ns.GoalFacts() end, 5)
ns.CheckGoals()   -- the first look writes the goals that are new; the next ones find nothing
out[#out+1] = clock("goals check, nothing new (3000)", function() ns.CheckGoals() end, 5)
out[#out+1] = clock("saga (3000 pages)", function() ns.BuildSaga() end, 5)
out[#out+1] = clock("export plain, names hidden (3000)", function() SkaldAPI.BuildExport("plain", "all") end, 1)
out[#out+1] = clock("text for the Reader (3000 pages)", function() SkaldAPI.BuildExport("reader", "all") end, 1)
-- the saved file, as the game would write it: about one line per field (a rough serializer, enough to see growth)
local function Bytes(v)
  if type(v) == "table" then local n = 4 for k, x in pairs(v) do n = n + #tostring(k) + 6 + Bytes(x) end return n end
  return #tostring(v) + 2
end
out[#out+1] = string.format("saved file (3000) %d KB", math.floor((Bytes(SkaldCharDB) + Bytes(SkaldDB)) / 1024))
RES = table.concat(out, string.char(10))`);
lua.lua_getglobal(L, to_luastring('RES'));
console.log(to_jsstring(lua.lua_tolstring(L, -1)));
