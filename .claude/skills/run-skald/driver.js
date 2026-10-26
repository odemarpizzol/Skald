// Drives Skald in the simulated game (fengari = Lua 5.3 + dev/tools/mock.lua standing in for the WoW API).
// It is NOT the game: use it to poke the addon, not to prove it works in the client.
//
//   node .claude/skills/run-skald/driver.js [--locale ptBR|frFR] [--saved '<lua table for SkaldCharDB>'] [--level N] '<lua body>'
//   echo '<lua body>' | node .claude/skills/run-skald/driver.js
//
// The body runs after ADDON_LOADED + PLAYER_LOGIN. Helpers in scope: fire(event, ...), runTimers(), count(kind),
// btn(label), ns (addon namespace), SkaldAPI, SkaldCharDB, SkaldDB. Whatever it print()s is shown; set RES to
// return a value (printed last).
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '../../..');
const TOOLS = path.join(ROOT, 'dev/tools');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(TOOLS, 'node_modules/fengari'));

const args = process.argv.slice(2);
const opt = n => { const i = args.indexOf(n); if (i < 0) return null; return args.splice(i, 2)[1]; };
const locale = opt('--locale') || 'enUS';
const saved = opt('--saved');
const level = opt('--level') || '20';
const body = args.length ? args.join(' ') : fs.readFileSync(0, 'utf8');

const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const exec = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
const FILES = [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua'], ['ZC', 'ZoneCard.lua']];

exec(fs.readFileSync(path.join(TOOLS, 'mock.lua'), 'utf8'));
for (const [k, f] of FILES) set(k, fs.readFileSync(path.join(ROOT, f), 'utf8'));
exec(`__locale="${locale}"; frames={}; SkaldDB={}; SkaldCharDB=nil; FONTS={}
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
function runTimers() local t=TIMERS TIMERS={} for _,fn in ipairs(t) do fn() end end
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 100000 end; function UnitXP() return 0 end
function UnitLevel() return ${Number(level)} end; function UnitName() return "Tester" end; function UnitExists() return false end
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
${saved ? 'SkaldCharDB = ' + saved : ''}
ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns)
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns); assert(load(ZC,"=Z"))("Skald",ns)
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN"); runTimers(); runTimers()
RES = nil`);
try {
  exec(`print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end io.write(table.concat(t, "\\t"), "\\n") end
local ok, err = pcall(function()\n${body}\nend)\nif not ok then print("ERROR: " .. tostring(err)) end\nif RES ~= nil then print("RES: " .. tostring(RES)) end`);
} catch (e) { console.log('ERROR: ' + e.message); process.exit(1); }
