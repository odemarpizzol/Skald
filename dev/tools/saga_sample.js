// Prints the Saga of a simulated diary, to read it: node dev/tools/saga_sample.js [enUS|ptBR|frFR] [female|male] [level]
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');
const ADDONS = path.resolve(__dirname, '../../..');
const FILES = [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua']];
const loc = process.argv[2] || 'ptBR', sex = process.argv[3] === 'male' ? 2 : 3, level = process.argv[4] || '20';
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const exec = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
exec(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'));
for (const [k, f] of FILES) { lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(ADDONS, 'Skald', f), 'utf8'))); lua.lua_setglobal(L, to_luastring(k)); }
const first = 1792000000;
exec(`__locale="${loc}"; frames={}; SkaldDB={}; SkaldCharDB=nil; FONTS={}
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
function runTimers() local t=TIMERS TIMERS={} for _,fn in ipairs(t) do fn() end end
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 100000 end; function UnitXP() return 0 end
function UnitLevel() return ${level} end; function UnitName() return "Oddinha" end; function UnitExists() return false end
function GetQuestID() return 0 end; function UnitGUID() return "P1" end; function UnitSex() return ${sex} end
function UnitClass() return "Guerreira","WARRIOR" end; function UnitRace() return "Elfa Noturna","NightElf" end
C_Map.GetAreaInfo = function(id) if id == 188 then return "Umbravale" end if id == 141 then return "Teldrassil" end end
function GetCategoryList() return { 1 } end; function GetCategoryNumAchievements() return 1 end
function GetAchievementInfo() return 7, "x", 10, true, 10, 10, 26 end
function SetPortraitTexture() end; function GetZoneText() return "Floresta de Elwynn" end
function GetStatisticsCategoryList() return {} end; function GetStatistic() return "--" end; function GetMoney() return 0 end
Minimap=CreateFrame("Frame","Minimap",UIParent); function GetCursorPosition() return 100,100 end
SkaldCharDB = { entries = {
  { t = ${first}, kind = "zone", arg = "Teldrassil", zone = "Teldrassil", idx = 1 },
  { t = ${first + 900000}, kind = "level", arg = 12, zone = "Costa Negra", idx = 1 },
  { t = ${first + 1800000}, kind = "boss", arg = "Hogger", zone = "Floresta de Elwynn", tries = 2, tier = 3, idx = 1 },
}, visited = {}, flags = {}, guid = "P1", stats = { counts = { quest = 87 }, deathZones = { ["Pântano das Lágrimas"] = 4, ["Costa Negra"] = 1 }, tiers = {}, played = 100, first = ${first} },
  companions = { ["Aldor-Sakaldd"] = { first = 1, last = 50 }, ["Brisa-Sakaldd"] = { first = 1, last = 40 }, ["Cato-Sakaldd"] = { first = 1, last = 30 } },
  goals = {}, goalsInit = true, goalsVer = 3 }
ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns)
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns)
function fire(ev,...) for _,f in ipairs(frames) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN"); runTimers(); runTimers()
local out = {}
for _, c in ipairs(ns.BuildSaga()) do out[#out + 1] = "== " .. c.title .. " (" .. #c.text .. ")\\n" .. c.text end
OUT = table.concat(out, "\\n\\n")`);
lua.lua_getglobal(L, to_luastring('OUT'));
console.log(to_jsstring(lua.lua_tolstring(L, -1)));
