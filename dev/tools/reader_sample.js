// Makes the text of "/skald reader" from a saved diary, in the simulated game (not the real one), to try the web Reader.
// node tools/reader_sample.js <path to a character's SavedVariables/Skald.lua> <output file> [locale]
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');

const ADDONS = path.resolve(__dirname, '../../..');
const FILES = [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['CH', 'Skald.lua'], ['AT', 'Atlas.lua'], ['GL', 'Goals.lua'], ['SG', 'Saga.lua'], ['ZC', 'ZoneCard.lua']];
const [saved, out, locale = 'ptBR'] = process.argv.slice(2);
if (!saved || !out) { console.log('usage: node tools/reader_sample.js <Skald.lua> <output> [locale]'); process.exit(1); }

const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const exec = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
exec(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'));
for (const [k, f] of FILES) set(k, fs.readFileSync(path.join(ADDONS, 'Skald', f), 'utf8'));
set('SAVED_VARIABLES', fs.readFileSync(saved, 'utf8'));
exec(`__locale="${locale}"; frames={}; SkaldDB={}; SkaldCharDB=nil; FONTS={}
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
function runTimers() local t=TIMERS TIMERS={} for _,fn in ipairs(t) do fn() end end
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 100000 end; function UnitXP() return 0 end
function UnitLevel() return 20 end; function UnitName() return "Tester" end; function UnitExists() return false end
function GetQuestID() return 0 end; function UnitGUID() return "P1" end
function UnitClass() return "Mage","MAGE" end; function UnitRace() return "Night Elf","NightElf" end
function SetPortraitTexture() end; function GetZoneText() return "Elwynn Forest" end
function time(t) if t then return os.time(t) end return os.time() end
function GetStatisticsCategoryList() return {} end; function GetStatistic() return "--" end; function GetMoney() return 0 end
Minimap=CreateFrame("Frame","Minimap",UIParent); function GetCursorPosition() return 100,100 end
C_Map={GetMapInfo=function() return nil end, GetBestMapForUnit=function() return nil end}
C_QuestLog={}; C_Item={}
function fire(ev,...) for _,f in ipairs(frames) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
local chunk, loadError = (loadstring or load)(SAVED_VARIABLES)
assert(chunk, loadError)
chunk()
local savedGuid = SkaldCharDB and SkaldCharDB.guid
function UnitGUID() return savedGuid or "P1" end   -- the diary belongs to this character: it is not archived
-- the saved file sets SkaldDB and SkaldCharDB as globals
ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns)
assert(load(CH,"=C"))("Skald",ns); assert(load(AT,"=A"))("Skald",ns); assert(load(GL,"=G"))("Skald",ns); assert(load(SG,"=S"))("Skald",ns); assert(load(ZC,"=Z"))("Skald",ns)
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN"); runTimers(); runTimers()
PARTS = SkaldAPI.BuildExport("reader", "all")
OUT = table.concat(PARTS, "\\n===PART===\\n")`);
lua.lua_getglobal(L, to_luastring('OUT'));
const text = to_jsstring(lua.lua_tolstring(L, -1));
fs.writeFileSync(out, text.split('===PART===').map(p => p.replace(/^\n|\n$/g, '')).join('\n'));
console.log('written', out, text.length, 'characters');
