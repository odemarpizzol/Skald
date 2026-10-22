// Validates every phrase pool in every language and every (type x rarity) choice. Exit code 1 on a problem.
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const POOL_AIM = 8, POOL_FLOOR = 5;
const A = require('path').resolve(__dirname, '../../..') + '/';
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const run = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) { console.log('ERR', to_jsstring(lua.lua_tolstring(L, -1))); process.exit(1); } };
const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
const get = k => { lua.lua_getglobal(L, to_luastring(k)); return to_jsstring(lua.lua_tolstring(L, -1)); };
run(fs.readFileSync(__dirname + '/mock.lua', 'utf8'));
for (const [k, f] of [['LOC', 'Skald/Locales.lua'], ['CUR', 'Skald/Curated.lua'], ['XPT', 'Skald/XPTiers.lua'], ['MAIN', 'Skald/Skald.lua'], ['SAGA', 'Skald/Saga.lua']])
  set(k, fs.readFileSync(A + f, 'utf8'));

const FORBID = {
  en: ['battle', 'blade', 'steel', 'fight', 'fought', 'slain', 'blood', 'sweat', 'sword', 'enemy', 'foe', 'kill', 'war'],
  pt: ['batalha', 'lâmina', 'lamina', 'aço', 'luta', 'sangue', 'suor', 'espada', 'inimigo', 'matar', 'guerra'],
};
// phrases that name a forbidden word only to deny it
const ALLOW = [/not every deed needs a sword/, /no blood was spilled/, /nem todo feito pede uma espada/, /nenhum sangue foi derramado/,
  /not every hero wields a sword/, /nem todo herói empunha uma espada/];
const QUEST_POOLS = ['questDelivery', 'questDeliveryNotable', 'questGather', 'questGatherNotable',
  'questExplore', 'questExploreNotable', 'questSeek', 'questSeekNotable', 'questChain'];

for (const loc of ['enUS', 'ptBR', 'frFR']) {
  run(`__locale="${loc}"; frames={}; SkaldDB=nil; SkaldCharDB=nil
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 1000 end; function UnitLevel() return 10 end; function UnitName() return "x" end; function GetQuestID() return 0 end
local ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns); assert(load(MAIN,"=C"))("Skald",ns); assert(load(SAGA,"=S"))("Skald",ns)
local function fire(ev,...) for _,f in ipairs(frames) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
fire("ADDON_LOADED","Skald"); fire("PLAYER_LOGIN")
local P = ns.LOCALES["${loc}"].phrases
local problems = {}
-- UI translations must keep every key and the same format arguments as English.
local function Signature(s)
    local args = {}
    s = s:gsub("%%%%", "")
    for spec in s:gmatch("%%[%.%d]*([sdif])") do args[#args + 1] = spec end
    return table.concat(args)
end
local function CheckUI(base, translated, path)
    for key, value in pairs(base) do
        if key ~= "phrases" then
            local name = path .. "." .. tostring(key)
            local other = translated[key]
            if type(other) ~= type(value) then
                problems[#problems + 1] = "UI KEY/TYPE " .. name
            elseif type(value) == "table" then
                CheckUI(value, other, name)
            elseif type(value) == "string" and Signature(value) ~= Signature(other) then
                problems[#problems + 1] = "UI FORMAT " .. name
            end
        end
    end
end
CheckUI(ns.LOCALES.enUS, ns.LOCALES["${loc}"], "${loc}")
local NO_NAME = { party = true, day = true }
local KNOWN = { ["{npc}"] = true, ["{steps}"] = true, ["{standing}"] = true, ["{tries}"] = true, ["{days}"] = true, ["{place}"] = true, ["{count}"] = true }
for kind, list in pairs(P) do
  for i, ph in ipairs(list) do
    if not pcall(string.format, ph, "NAME") then problems[#problems+1] = "FORMAT " .. kind .. "#" .. i end
    local n = select(2, ph:gsub("%%s", ""))
    if n ~= 1 and not NO_NAME[kind] then problems[#problems+1] = "NAMECOUNT(" .. n .. ") " .. kind .. "#" .. i end
    for tag in ph:gmatch("{[^}]*}") do
      if not KNOWN[tag] and not tag:match("^{g:[^|}]*|[^}]*}$") then problems[#problems+1] = "UNKNOWN TAG " .. tag .. " in " .. kind .. "#" .. i end
    end
  end
end
local pools = {}
for _, qt in ipairs({ "fight", "gather", "explore", "seek", "delivery", "unknown" }) do
  local sizes = {}
  for tier = 0, 5 do
    local e = { kind = "quest", tier = tier, qtype = (qt ~= "unknown") and qt or false }
    local list = SkaldAPI.PoolFor(e)
    sizes[#sizes+1] = list and #list or "NIL"
  end
  pools[#pools+1] = qt .. ": " .. table.concat(sizes, "/")
end
-- The Saga: pools of whole paragraphs (the tags each pool may use, the words it may not, French punctuation)
do
    local T = ns.SagaTexts["${loc}"]
    local E = ns.SagaTexts.enUS
    local ALLOWED = {
        prologue = "name race class date place a A", birth = "name race class home land a A", firstPage = "date place", earliest = "born", road = "level place days", stories = "n", war = "n", warHard = "boss tries",
        falls = "n", fallsPlace = "place", company = "n", companyNames = "names", marks = "n points title", epilogue = "name level pages title",
        epilogueTop = "name pages title",
    }
    local MUST = { prologue = "date place", birth = "home land", firstPage = "date place", earliest = "born", road = "level place", stories = "n", war = "n", warHard = "boss tries",
        falls = "n", fallsPlace = "place", company = "n", companyNames = "names", marks = "n points title", epilogue = "level", epilogueTop = "pages" }
    local COMBAT = { war = true, warHard = true, falls = true, fallsPlace = true }
    local words = { ${FORBID[loc === 'enUS' ? 'en' : 'pt'].map(w => JSON.stringify(w)).join(', ')} }
    local nbsp = string.char(194, 160)
    for key in pairs(E.TITLES) do if not T.TITLES[key] then problems[#problems+1] = "SAGA TITLE " .. key end end
    for key in pairs(E.POOLS) do
        local pool = T.POOLS[key]
        if not pool then problems[#problems+1] = "SAGA POOL missing " .. key
        else
            if #pool < ${POOL_AIM} then problems[#problems+1] = "SAGA POOL " .. key .. " has " .. #pool .. " (aim ${POOL_AIM})" end
            for i, ph in ipairs(pool) do
                local where = "SAGA " .. key .. "#" .. i
                local seen = {}
                for tag in ph:gmatch("{#(%a+):") do
                    seen[tag] = true
                    if not (" " .. ALLOWED[key] .. " "):find(" " .. tag .. " ", 1, true) then problems[#problems+1] = where .. " tag {#" .. tag .. "}" end
                end
                for tag in ph:gmatch("{(%a+)}") do
                    seen[tag] = true
                    if not (" " .. ALLOWED[key] .. " "):find(" " .. tag .. " ", 1, true) then problems[#problems+1] = where .. " tag {" .. tag .. "}" end
                end
                for must in MUST[key]:gmatch("%a+") do
                    if not seen[must] then problems[#problems+1] = where .. " lacks {" .. must .. "}" end
                end
                for tag in ph:gmatch("{[^}]*}") do
                    if not tag:match("^{%a+}$") and not tag:match("^{g:[^|}]*|[^}]*}$") and not tag:match("^{#%a+:[^|}]*|[^}]*}$") then problems[#problems+1] = where .. " bad tag " .. tag end
                end
                if #ph > 330 then problems[#problems+1] = where .. " too long (" .. #ph .. ")" end
                local low = ph:lower()
                if not COMBAT[key] then
                    for _, w in ipairs(words) do
                        if low:find(w, 1, true) then problems[#problems+1] = where .. " combat word " .. w end
                    end
                end
                if "${loc}" == "frFR" then
                    local plain = (ph:gsub("{g:[^}]*}", "")):gsub("{#[^}]*}", "")
                    for _, mark in ipairs({ ":", ";", "?", "!" }) do
                        local at = 1
                        while true do
                            local a = plain:find(mark, at, true)
                            if not a then break end
                            local before = plain:sub(math.max(1, a - 2), a - 1)
                            if before ~= nbsp then problems[#problems+1] = where .. " needs a non-breaking space before " .. mark end
                            at = a + 1
                        end
                    end
                end
                -- the same text must not appear twice in a pool
                for j = 1, i - 1 do if pool[j] == ph then problems[#problems+1] = where .. " repeats #" .. j end end
            end
        end
    end
    for key in pairs(T.POOLS) do if not E.POOLS[key] then problems[#problems+1] = "SAGA POOL extra " .. key end end
end
PROBLEMS = table.concat(problems, " ; ")
POOLS = table.concat(pools, "   ")
local dump = {}
for _, name in ipairs({ "${QUEST_POOLS.join('", "')}" }) do
  for _, ph in ipairs(P[name] or {}) do dump[#dump+1] = name .. " :: " .. ph end
end
POOLTEXT = table.concat(dump, string.char(10))`);
  console.log(`\n=== ${loc} ===`);
  const prob = get('PROBLEMS'); console.log('phrase problems:', prob || 'none'); if (prob) process.exitCode = 1;
  console.log('pool size by rarity 0..5 ->', get('POOLS'));
  // Variety: the aim is eight sentences or more for each kind of page; the pools below that are listed (a warning,
  // the debt to pay), and none may fall under the floor of five, so the five-page window still has room.
  const short = [], tiny = [];
  for (const part of get('POOLS').split('   ')) {
    const [kind, sizes] = part.split(': ');
    sizes.split('/').forEach((n, tier) => {
      if (n === 'NIL' || Number(n) < POOL_FLOOR) tiny.push(`${kind}@${tier}=${n}`);
      else if (Number(n) < POOL_AIM) short.push(`${kind}@${tier}=${n}`);
    });
  }
  console.log(`pools under ${POOL_AIM} (to widen):`, short.length ? short.join(' ') : 'none');
  console.log(`pools under ${POOL_FLOOR} (not allowed):`, tiny.length ? tiny.join(' ') : 'none'); if (tiny.length) process.exitCode = 1;
  const words = FORBID[loc === 'enUS' ? 'en' : 'pt'];
  const bad = get('POOLTEXT').split('\n').filter(l => {
    const ph = l.split(' :: ')[1].toLowerCase();
    return words.some(w => ph.includes(w)) && !ALLOW.some(re => re.test(ph));
  });
  console.log('combat words in non-combat pools:', bad.length ? bad.join(' || ') : 'none'); if (bad.length) process.exitCode = 1;
}
