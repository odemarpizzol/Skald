// Grammar check of everything the addon can say in one language, with a local LanguageTool server.
// Not part of checks.js: it needs LanguageTool running on this machine (nothing is sent anywhere else):
//   docker run -d --name skald-lt -p 127.0.0.1:8010:8010 erikvl87/languagetool
//   node dev/tools/lang_check.js <enUS|ptBR|frFR|esES|deDE> [report.md] [--picky] [--server=http://127.0.0.1:8010]
// Every phrase is told the way the book tells it: the placeholders are filled with real names of that language (a land in
// the plural, a masculine one, an island, a proper name, a land with its own article), the articles are put in by
// ns.PlaceArticles, a {g:he|she} is told both ways, and the counted nouns of the Saga are told for one and for many.
// LanguageTool then reads the result. Words of the game the speller does not know, and findings already reviewed and judged
// right ("!RULE text-id", the id without the name in brackets), live in lang_check/<locale>.txt. Every other finding is listed.
const fs = require('fs');
const path = require('path');
const parse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const args = process.argv.slice(2);
const picky = args.includes('--picky');
const server = (args.find(a => a.startsWith('--server=')) || '--server=http://127.0.0.1:8010').slice(9);
const plain = args.filter(a => !a.startsWith('--'));
const locale = plain[0];
const root = path.resolve(__dirname, '../..');

// The names each language tells its pages with. place: plural, masculine, island, feminine/other, proper, own article.
const CONFIG = {
  enUS: { lt: 'en-GB', places: ['The Barrens', 'Duskwood', 'Azuremyst Isle', 'Swamp of Sorrows', 'Durotar', 'The Deadmines'],
    boss: ['Edwin VanCleef', 'Onyxia'], item: '[Shortsword]', pet: 'Greysnout', guild: 'Keepers of the Flame', mount: 'Brown Wolf',
    rep: ['Stormwind', 'The Aldor'], mark: '1000 quests', bg: 'Warsong Gulch', friend: 'Thalia', flight: 'Stormwind, Elwynn',
    quest: 'The Defense of Goldshire', npc: 'Marshal Dughan', weather: 'rain', standing: 'Honored', dungeon: 'The Deadmines',
    prof: { alchemy: 'Alchemy', blacksmithing: 'Blacksmithing', enchanting: 'Enchanting', engineering: 'Engineering', herbalism: 'Herbalism',
      leatherworking: 'Leatherworking', mining: 'Mining', skinning: 'Skinning', tailoring: 'Tailoring', cooking: 'Cooking', firstaid: 'First Aid',
      fishing: 'Fishing', jewelcrafting: 'Jewelcrafting' }, skill: 'Tailoring 75',
    saga: { name: 'Thalia', race: 'Night Elf', class: 'Hunter', date: '11/05/2026', boss: 'Edwin VanCleef', names: 'Ayla and Bren',
      title: 'Well Travelled', place: 'Swamp of Sorrows', home: 'Shadowglen', land: 'Teldrassil' },
    curated: ['The Call of the Sentinels', 'Tyrande Whisperwind'] },
  ptBR: { lt: 'pt-BR', places: ['Sertões', 'Bosque do Crepúsculo', 'Ilha Névoa Lazúli', 'Floresta de Elwynn', 'Durotar', 'Minas Mortas'],
    boss: ['Edwin VanCleef', 'Onyxia'], item: '[Espada Curta]', pet: 'Focinho Cinza', guild: 'Guardiões da Chama', mount: 'Lobo Marrom',
    rep: ['Ventobravo', 'Os Aldor'], mark: '1000 missões', bg: 'Ravina Brado Guerreiro', friend: 'Thalia', flight: 'Ventobravo, Elwynn',
    quest: 'A Defesa de Vila Dourada', npc: 'Marechal Dughan', weather: 'chuva', standing: 'Honrado', dungeon: 'Minas Mortas',
    prof: { alchemy: 'Alquimia', blacksmithing: 'Ferraria', enchanting: 'Encantamento', engineering: 'Engenharia', herbalism: 'Herborismo',
      leatherworking: 'Couraria', mining: 'Mineração', skinning: 'Esfolamento', tailoring: 'Alfaiataria', cooking: 'Culinária', firstaid: 'Primeiros Socorros',
      fishing: 'Pesca', jewelcrafting: 'Joalheria' }, skill: 'Alfaiataria 75',
    saga: { name: 'Thalia', race: 'Elfa Noturna', class: 'Caçadora', date: '05/11/2026', boss: 'Edwin VanCleef', names: 'Ayla e Bren',
      title: 'Viajante', place: 'Pântano das Mágoas', home: 'Vale Sombrio', land: 'Teldrassil' },
    curated: ['O Chamado das Sentinelas', 'Tyrande Murmuréter'] },
  frFR: { lt: 'fr', places: ['Les Tarides', 'Bois de la Pénombre', 'Île de Brume-Azur', 'Marais des Chagrins', 'Durotar', 'Les Mortemines'],
    boss: ['Edwin VanCleef', 'Onyxia'], item: '[Épée courte]', pet: 'Museau-Gris', guild: 'Gardiens de la Flamme', mount: 'Loup brun',
    rep: ['Hurlevent', "L'Aldor"], mark: '1000 quêtes', bg: 'Goulet des Chanteguerres', friend: 'Thalia', flight: 'Hurlevent, Elwynn',
    quest: 'La défense de Comté-de-l\'Or', npc: 'Le maréchal Dughan', weather: 'pluie', standing: 'Honoré', dungeon: 'Les Mortemines',
    prof: { alchemy: 'Alchimie', blacksmithing: 'Forge', enchanting: 'Enchantement', engineering: 'Ingénierie', herbalism: 'Herboristerie',
      leatherworking: 'Travail du cuir', mining: 'Minage', skinning: 'Dépeçage', tailoring: 'Couture', cooking: 'Cuisine', firstaid: 'Secourisme',
      fishing: 'Pêche', jewelcrafting: 'Joaillerie' }, skill: 'Couture 75',
    saga: { name: 'Thalia', race: 'Elfe de la nuit', class: 'Chasseresse', date: '05/11/2026', boss: 'Edwin VanCleef', names: 'Ayla et Bren',
      title: 'Grand voyageur', place: 'Marais des Chagrins', home: 'Sombrevallon', land: 'Teldrassil' },
    curated: ["L'appel des Sentinelles", 'Tyrande Murmevent'] },
  esES: { lt: 'es', places: ['Los Baldíos', 'Bosque del Ocaso', 'Isla Bruma Azur', 'Pantano de las Penas', 'Durotar', 'El Exodar'],
    boss: ['Edwin VanCleef', 'Onyxia'], item: '[Espada corta]', pet: 'Hocico Gris', guild: 'Guardianes de la Llama', mount: 'Lobo pardo',
    rep: ['Ventormenta', 'Los Aldor'], mark: '1000 misiones', bg: 'Garganta Grito de Guerra', friend: 'Thalia', flight: 'Ventormenta, Elwynn',
    quest: 'La defensa de Villadorada', npc: 'El alguacil Dughan', weather: 'lluvia', standing: 'Honorable', dungeon: 'Las Minas de la Muerte',
    prof: { alchemy: 'Alquimia', blacksmithing: 'Herrería', enchanting: 'Encantamiento', engineering: 'Ingeniería', herbalism: 'Herboristería',
      leatherworking: 'Peletería', mining: 'Minería', skinning: 'Desuello', tailoring: 'Sastrería', cooking: 'Cocina', firstaid: 'Primeros auxilios',
      fishing: 'Pesca', jewelcrafting: 'Joyería' }, skill: 'Sastrería 75',
    saga: { name: 'Thalia', race: 'Elfa de la noche', class: 'Cazadora', date: '05/11/2026', boss: 'Edwin VanCleef', names: 'Ayla y Bren',
      title: 'Viajera', place: 'Pantano de las Penas', home: 'Cañada Umbría', land: 'Teldrassil' },
    curated: ['La llamada de las centinelas', 'Tyrande Susurravientos'] },
  deDE: { lt: 'de-DE', places: ['Sümpfe des Elends', 'Dämmerwald', 'Azurmythosinsel', 'Brachland', 'Westfall', 'Die Todesminen'],
    boss: ['Edwin van Cleef', 'Onyxia'], item: '[Kurzschwert]', pet: 'Grauschnauze', guild: 'Hüter der Flamme', mount: 'Brauner Wolf',
    rep: ['Sturmwind', 'Die Aldor'], mark: '1000 Quests', bg: 'Warsongschlucht', friend: 'Thalia', flight: 'Sturmwind, Elwynn',
    quest: 'Die Verteidigung von Goldhain', npc: 'Marschall Dughan', weather: 'Regen', standing: 'Wohlwollend', dungeon: 'Die Todesminen',
    prof: { alchemy: 'Alchimie', blacksmithing: 'Schmiedekunst', enchanting: 'Verzauberkunst', engineering: 'Ingenieurskunst', herbalism: 'Kräuterkunde',
      leatherworking: 'Lederverarbeitung', mining: 'Bergbau', skinning: 'Kürschnerei', tailoring: 'Schneiderei', cooking: 'Kochkunst', firstaid: 'Erste Hilfe',
      fishing: 'Angeln', jewelcrafting: 'Juwelenschleifen' }, skill: 'Schneiderei 75',
    saga: { name: 'Thalia', race: 'Nachtelfe', class: 'Jägerin', date: '05.11.2026', boss: 'Edwin van Cleef', names: 'Ayla und Bren',
      title: 'Weit gereist', place: 'Sümpfe des Elends', home: 'Schattenhain', land: 'Teldrassil' },
    curated: ['Der Ruf der Schildwachen', 'Tyrande Wisperwind'] },
};
// rules that compare neighbouring sentences: the texts are read in batches, so their neighbours are other texts
const DISABLED = ['GERMAN_WORD_REPEAT_BEGINNING_RULE', 'DE_REPEATEDWORDS_NUN', 'DE_REPEATEDWORDS_MEIST', 'DE_REPEATEDWORDS_AUCH', 'DE_REPEATEDWORDS',
  'ENGLISH_WORD_REPEAT_BEGINNING_RULE', 'PORTUGUESE_WORD_REPEAT_BEGINNING_RULE', 'FRENCH_WORD_REPEAT_BEGINNING_RULE', 'SPANISH_WORD_REPEAT_BEGINNING_RULE',
  'PT_WORD_REPEAT_BEGINNING_RULE', 'ES_REPEATEDWORDS', 'FR_REPEATEDWORDS', 'PT_REPEATEDWORDS', 'EN_REPEATEDWORDS', 'STYLE_REPEATED_WORD_RULE_PT',
  'STYLE_REPEATED_SENTENCE_BEGINNING', 'REPEATED_VERBS_PT'].join(',');

const cfg = CONFIG[locale];
if (!cfg) { console.error('usage: node dev/tools/lang_check.js <' + Object.keys(CONFIG).join('|') + '> [report.md] [--picky]'); process.exit(2); }
const out = plain[1] || path.join(root, 'output', 'lang-check', locale + '.md');
const listFile = path.join(__dirname, 'lang_check', locale + '.txt');

// ---------------------------------------------------------------- the corpus, built by the addon itself (Lua)
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const run = code => { if (lauxlib.luaL_dostring(L, to_luastring(code))) throw Error(to_jsstring(lua.lua_tolstring(L, -1))); };
const set = (k, v) => { lua.lua_pushstring(L, to_luastring(v)); lua.lua_setglobal(L, to_luastring(k)); };
const get = k => { lua.lua_getglobal(L, to_luastring(k)); const s = lua.lua_tolstring(L, -1); lua.lua_pop(L, 1); return s ? to_jsstring(s) : ''; };
run(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'));
for (const [k, f] of [['LOC', 'Locales.lua'], ['CUR', 'Curated.lua'], ['XPT', 'XPTiers.lua'], ['MAIN', 'Skald.lua'], ['SAGA', 'Saga.lua']])
  set(k, fs.readFileSync(path.join(root, f), 'utf8'));
const toLua = v => typeof v === 'string' ? JSON.stringify(v) : Array.isArray(v) ? '{' + v.map(toLua).join(',') + '}'
  : '{' + Object.entries(v).map(([k, x]) => '[' + JSON.stringify(k) + ']=' + toLua(x)).join(',') + '}';
set('CFG', 'return ' + toLua(cfg));
set('LOCALE', locale);

// the tables of the other files (Goals, Atlas, PvP...) for this language, by their source, as validate_locales.js finds them
const aux = [];
function walk(node, source, file) {
  if (!node || typeof node !== 'object') return;
  if (node.type === 'TableConstructorExpression') {
    const own = node.fields.find(f => f.type === 'TableKeyString' && f.key.name === locale);
    const en = node.fields.find(f => f.type === 'TableKeyString' && f.key.name === 'enUS');
    if (own && en && own.value.type === 'TableConstructorExpression') aux.push([file + ':' + own.loc.start.line, source.slice(...own.value.range)]);
  }
  for (const [key, value] of Object.entries(node)) {
    if (key === 'range' || key === 'loc') continue;
    if (Array.isArray(value)) value.forEach(n => walk(n, source, file));
    else if (value && typeof value === 'object') walk(value, source, file);
  }
}
for (const file of ['Atlas.lua', 'Goals.lua', 'ZoneCard.lua', 'Pvp.lua', 'Cartographer.lua', 'Bard.lua', 'Search.lua', 'Backup.lua', 'ChronicleTab.lua', 'Chronicle.lua']) {
  const p = path.join(root, file);
  if (!fs.existsSync(p)) continue;
  const source = fs.readFileSync(p, 'utf8');
  walk(parse.parse(source, { ranges: true, locations: true, luaVersion: '5.1' }), source, file);
}
set('AUXSRC', 'return {' + aux.map(([where, src]) => '{' + JSON.stringify(where) + ',' + src + '}').join(',\n') + '}');

run(`__locale=LOCALE; frames={}; SkaldDB=nil; SkaldCharDB=nil
TIMERS={}; C_Timer={After=function(t,fn) table.insert(TIMERS,fn) end}
function GetGuildInfo() return nil end; function IsInInstance() return false,"none" end
function UnitXPMax() return 1000 end; function UnitLevel() return 10 end; function UnitName() return "x" end; function GetQuestID() return 0 end
local ns={}
assert(load(LOC,"=L"))("Skald",ns); assert(load(CUR,"=U"))("Skald",ns); assert(load(XPT,"=X"))("Skald",ns); assert(load(MAIN,"=C"))("Skald",ns); assert(load(SAGA,"=S"))("Skald",ns)
local C = assert(load(CFG))()
local key = ns.LocaleKey(LOCALE)
local OUT = {}
local function add(id, text)
  local function clean(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\\n", " ")) end
  if text:find("{g:", 1, true) then   -- told for a man and for a woman (before the colour codes go: "|r" is also "{g:x|rest}")
    OUT[#OUT + 1] = id .. " [m]\\t" .. clean((text:gsub("{g:([^|}]*)|([^}]*)}", "%1")))
    OUT[#OUT + 1] = id .. " [f]\\t" .. clean((text:gsub("{g:([^|}]*)|([^}]*)}", "%2")))
  else
    text = clean(text)
    OUT[#OUT + 1] = id .. "\\t" .. text
  end
end
local TAGS = { tries = "3", days = "5", npc = C.npc, weather = C.weather, standing = C.standing, nth = "10",
  diff = "4", gold = "12", count = "5", steps = "7", place = C.dungeon }
local function tags(text)
  return (text:gsub("{(%a+)}", function(k) return TAGS[k] end))
end
local function isPlace(k)
  return k:find("_zone$") or k:find("_death$") or k:find("_hearth$") or k:find("_dungeon$") or k:find("_start$")
    or k:find("^weather") or k:find("_weather$") or k:find("^memory") or k:find("^bg")
    or ({ zone = 1, death = 1, hearth = 1, home = 1, dungeon = 1, revive = 1, reviveHealer = 1 })[k]
end
local function fillers(k)
  if k:find("^bg") then return { C.bg }, true end
  if isPlace(k) then return C.places, true end
  -- French elides a foe or a pet like a land: "d'Edwin", "qu'Onyxia"
  if LOCALE == "frFR" and (k:find("[Bb]oss") or k:find("^tame")) then return (k:find("^tame") and { C.pet } or C.boss), true end
  if k:find("[Bb]oss") then return C.boss end
  if k == "level" or k == "milestone" or k:find("_level$") then return { "23" } end
  if k:find("^loot") then return { C.item } end
  if k:find("^profession_") then return { C.prof[k:sub(12)] or C.skill } end
  if k == "profession" then return { C.prof.tailoring } end
  if k == "skill" then return { C.skill } end
  if k:find("^tame") then return { C.pet } end
  if k:find("^guild") then return { C.guild } end
  if k == "mount" then return { C.mount } end
  if k == "rep" then return C.rep end
  if k:find("^mark_") then return { "1000" } end
  if k == "mark" then return { C.mark } end
  if k == "reunion" then return { C.friend } end
  if k == "flight" then return { C.flight } end
  return { C.quest }   -- quests, deeds, goals: told inside quotes
end
local P = ns.LOCALES[key].phrases
local keys = {}
for k in pairs(P) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
  local list, place = fillers(k)
  for i, line in ipairs(P[k]) do
    for _, name in ipairs(list) do
      local phrase = line
      if place then phrase = ns.PlaceArticles(phrase, name, "%s") end
      if k == "reunion" then phrase = ns.PlaceArticles(phrase, TAGS.place, "{place}") end
      local ok, text = pcall(string.format, phrase, name)
      add("phrases." .. k .. "[" .. i .. "] (" .. name .. ")", tags(ok and text or phrase))
    end
  end
end
-- the interface: every other string of the table
local function ui(t, pathName)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(ks) do
    local v, name = t[k], pathName .. "." .. tostring(k)
    if type(v) == "table" and k ~= "phrases" then ui(v, name)
    elseif type(v) == "string" and not v:find("%%[mYHMy]") then
      add(name, (v:gsub("%%%%", "\\1"):gsub("%%0?%d?d", "3"):gsub("%%s", C.friend):gsub("\\1", "%%")))
    end
  end
end
ui(ns.LOCALES[key], "L")
-- the Saga: told for one and for many
local S = ns.SagaTexts[key]
local V = C.saga
V.level = "23"
for _, k in ipairs((function() local t = {} for k in pairs(S.POOLS) do t[#t + 1] = k end table.sort(t) return t end)()) do
  for i, line in ipairs(S.POOLS[k]) do
    for _, n in ipairs({ 1, 5 }) do
      local phrase = line
      for _, tag in ipairs({ "home", "land", "place", "boss" }) do phrase = ns.PlaceArticles(phrase, V[tag], "{" .. tag .. "}") end
      phrase = phrase:gsub("{#(%a+):([^|}]*)|([^}]*)}", function(_, one, many) return n .. " " .. (n == 1 and one or many) end)
      phrase = phrase:gsub("{(%a+)}", function(tag) return V[tag] or tostring(n) end)
      add("Saga." .. k .. "[" .. i .. "] (n=" .. n .. ")", phrase)
    end
  end
end
ui(S.TITLES, "Saga.TITLES")
-- the hand-written quest stories
local ids = {}
for id, c in pairs(ns.CURATED or {}) do if c.text and c.text[key] then ids[#ids + 1] = id end end
table.sort(ids)
for _, id in ipairs(ids) do
  add("Curated[" .. id .. "]", (ns.CURATED[id].text[key]:gsub("{quest}", C.curated[1]):gsub("{npc}", C.curated[2])))
end
-- the tables of the other files
for _, entry in ipairs(assert(load(AUXSRC))()) do ui(entry[2], entry[1]) end
CORPUS = table.concat(OUT, "\\n")`);
const items = get('CORPUS').split('\n').map(line => { const t = line.indexOf('\t'); return { id: line.slice(0, t), text: line.slice(t + 1) }; })
  .filter(it => /\p{L}{2}/u.test(it.text) && !/^\/skald|^%?\d|^[A-Z_]+$/.test(it.text));

// ---------------------------------------------------------------- LanguageTool
const listed = fs.existsSync(listFile) ? fs.readFileSync(listFile, 'utf8').split('\n').map(w => w.trim()).filter(w => w && !w.startsWith('#')) : [];
const known = new Set(listed.filter(w => !w.startsWith('!')));
const accepted = new Set(listed.filter(w => w.startsWith('!')).map(w => w.slice(1).replace(/\s+/, ' ')));
const idOf = id => id.replace(/ \(.*?\)/, '').replace(/ \[[mf]\]$/, '');
async function check(text) {
  const body = new URLSearchParams({ language: cfg.lt, text, disabledRules: DISABLED });
  if (picky) body.set('level', 'picky');
  const res = await fetch(server + '/v2/check', { method: 'POST', body });
  if (!res.ok) throw Error('LanguageTool answered ' + res.status + ': ' + (await res.text()).slice(0, 200));
  return (await res.json()).matches;
}
(async () => {
  try { await fetch(server + '/v2/languages'); } catch (e) {
    console.error('No LanguageTool at ' + server + '. Start it with:\n  docker run -d --name skald-lt -p 127.0.0.1:8010:8010 erikvl87/languagetool');
    process.exit(2);
  }
  const findings = [], unknown = new Map();
  const SEP = '\n\n';
  for (let i = 0; i < items.length;) {
    const batch = [];
    let size = 0;
    while (i < items.length && size < 12000) { batch.push(items[i]); size += items[i].text.length + SEP.length; i++; }
    const starts = [];
    let pos = 0;
    for (const it of batch) { starts.push(pos); pos += it.text.length + SEP.length; }
    for (const m of await check(batch.map(it => it.text).join(SEP))) {
      let j = starts.length - 1;
      while (j > 0 && starts[j] > m.offset) j--;
      const it = batch[j], word = it.text.substr(m.offset - starts[j], m.length);
      if (m.rule.issueType === 'misspelling' || /SPELLER|MORFOLOGIK|HUNSPELL/.test(m.rule.id)) {
        if (known.has(word) || word.split(/['’-]/).every(w => !w || known.has(w))) continue;
        if (!unknown.has(word)) unknown.set(word, []);
        unknown.get(word).push(it.id);
        continue;
      }
      if (accepted.has(m.rule.id + ' ' + idOf(it.id))) continue;
      findings.push({ id: it.id, text: it.text, word, rule: m.rule.id, message: m.message, fix: m.replacements.slice(0, 3).map(r => r.value) });
    }
    if (process.stdout.isTTY) process.stdout.write('\r' + i + ' / ' + items.length + ' texts read');
  }
  // one finding per rule, text and word: the same line told with several names finds the same thing once
  const seen = new Set(), unique = findings.filter(f => { const k = f.rule + '|' + idOf(f.id) + '|' + f.word; if (seen.has(k)) return false; seen.add(k); return true; });
  const byRule = new Map();
  for (const f of unique) { if (!byRule.has(f.rule)) byRule.set(f.rule, []); byRule.get(f.rule).push(f); }
  const lines = ['# ' + locale + ' check (LanguageTool ' + cfg.lt + (picky ? ', picky' : '') + ')', '',
    items.length + ' texts read, ' + unique.length + ' findings, ' + unknown.size + ' words the speller does not know.', '',
    'This is a grammar tool reading the simulated text, not a native speaker and not the game.', ''];
  for (const [rule, list] of [...byRule].sort((a, b) => b[1].length - a[1].length)) {
    lines.push('## ' + rule + ' (' + list.length + ')', '');
    for (const f of list) lines.push('- `' + f.id + '`: ' + f.message + (f.fix.length ? ' → ' + f.fix.join(' / ') : '') + '  ', '  ' + f.text,
      '  (found: **' + f.word + '**; to accept: `!' + f.rule + ' ' + idOf(f.id) + '`)', '');
  }
  lines.push('## Unknown words', '', 'Add the names of the game to dev/tools/lang_check/' + locale + '.txt; the rest are typos.', '');
  for (const [word, where] of [...unknown].sort((a, b) => b[1].length - a[1].length)) lines.push('- ' + word + ' (' + where.length + '): ' + where.slice(0, 3).join(', '));
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, lines.join('\n') + '\n');
  console.log((process.stdout.isTTY ? '\n' : '') + locale + ': ' + items.length + ' texts, ' + unique.length + ' findings, ' + unknown.size + ' unknown words: ' + out);
})().catch(e => { console.error(e.message); process.exit(1); });
