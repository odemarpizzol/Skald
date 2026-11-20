// Auxiliary locale tables are not all in Locales.lua. Check literal UI/story/family
// tables as well, so a new English key cannot silently fall back in German.
const fs = require('fs');
const path = require('path');
const parse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const root = path.resolve(__dirname, '../..');
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
function execute(code) {
  if (lauxlib.luaL_dostring(state, to_luastring(code))) throw Error(to_jsstring(lua.lua_tolstring(state, -1)));
}
execute(`problems={}; leaves=0
local function signature(text)
  local out={}
  text=text:gsub("%%%%", "")
  for spec in text:gmatch("%%[%.%d]*([sdif])") do out[#out+1]=spec end
  return table.concat(out)
end
function compare(base, translated, where)
  if type(base)~=type(translated) then problems[#problems+1]=where..": missing/wrong type"; return end
  if type(base)=="table" then
    for k,v in pairs(base) do compare(v,translated[k],where.."."..tostring(k)) end
  elseif type(base)=="string" then
    leaves=leaves+1
    if translated=="" then problems[#problems+1]=where..": empty translation" end
    if signature(base)~=signature(translated) then problems[#problems+1]=where..": format arguments" end
  end
end`);
let tables = 0;
function walk(node, source, file) {
  if (!node || typeof node !== 'object') return;
  if (node.type === 'TableConstructorExpression') {
    const english = node.fields.find(f => f.type === 'TableKeyString' && f.key.name === 'enUS');
    if (english) {
      const german = node.fields.find(f => f.type === 'TableKeyString' && f.key.name === 'deDE');
      const where = file + ':' + english.loc.start.line;
      if (!german) throw Error(where + ': missing deDE table');
      execute('compare(' + source.slice(...english.value.range) + ',' + source.slice(...german.value.range) + ',' + JSON.stringify(where) + ')');
      tables++;
    }
  }
  for (const [key, value] of Object.entries(node)) {
    if (key === 'range' || key === 'loc') continue;
    if (Array.isArray(value)) value.forEach(n => walk(n, source, file));
    else if (value && typeof value === 'object') walk(value, source, file);
  }
}
try {
  for (const file of ['Skald.lua', 'Atlas.lua', 'Goals.lua', 'Saga.lua', 'ZoneCard.lua', 'Pvp.lua', 'Cartographer.lua', 'Curated.lua']) {
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    walk(parse.parse(source, { ranges: true, locations: true, luaVersion: '5.1' }), source, file);
  }
  execute('RESULT=table.concat(problems,"\\n"); COUNT=tostring(leaves)');
  lua.lua_getglobal(state, to_luastring('RESULT'));
  const problems = to_jsstring(lua.lua_tolstring(state, -1));
  if (problems) throw Error(problems);
  lua.lua_getglobal(state, to_luastring('COUNT'));
  console.log('Auxiliary German localization: ' + tables + ' tables, ' + to_jsstring(lua.lua_tolstring(state, -1)) + ' strings; all keys and format arguments covered.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
