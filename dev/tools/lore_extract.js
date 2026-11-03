// Turns what /skald probe lore saved (SkaldDB.loreProbe, in the saved variables of the game) into text to read.
//
//   node dev/tools/lore_extract.js "<path>/WTF/Account/<account>/SavedVariables/Skald.lua" [out.md]
//
// Without an out file it writes dev/lore/lore_<date>.md. The texts are the game's own (Blizzard's): dev/lore is in .gitignore and
// must never be committed to the public repository; it is for reading, and for writing the lines of a race from what the game says.
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const fs = require('fs');
const path = require('path');

// A Lua program that reads SkaldDB.loreProbe and builds the text (in Lua, so the saved format needs no parser of its own).
const BUILD = `
local nl = string.char(10)
local log = SkaldDB and SkaldDB.loreProbe
if type(log) ~= "table" or type(log.items) ~= "table" or #log.items == 0 then RES = "(nothing saved: /skald probe lore was not on, or nothing was said)"; return end
local out, m = {}, log.meta or {}
out[#out + 1] = "# Lore kept by the Skald probe"
out[#out + 1] = ""
out[#out + 1] = "Race: " .. tostring(m.race) .. " | Class: " .. tostring(m.class) .. " | Faction: " .. tostring(m.faction) .. " | Client: " .. tostring(m.locale) .. " " .. tostring(m.build)
out[#out + 1] = "Texts: " .. #log.items
out[#out + 1] = ""
local zones, order = {}, {}
for _, r in ipairs(log.items) do
    local z = r.z or "?"
    if not zones[z] then zones[z] = {}; order[#order + 1] = z end
    zones[z][#zones[z] + 1] = r
end
for _, z in ipairs(order) do
    out[#out + 1] = "## " .. z
    out[#out + 1] = ""
    for _, r in ipairs(zones[z]) do
        local head = "**[" .. tostring(r.k) .. "]"
        if r.n then head = head .. " " .. r.n end
        if r.title then head = head .. " - " .. r.title end
        head = head .. "**"
        local where = {}
        if r.sz and r.sz ~= "" then where[#where + 1] = r.sz end
        if r.q then where[#where + 1] = "quest " .. r.q end
        if r.r then where[#where + 1] = r.r end
        if #where > 0 then head = head .. " (" .. table.concat(where, ", ") .. ")" end
        out[#out + 1] = head
        if r.text then out[#out + 1] = "> " .. r.text:gsub(nl, nl .. "> ") end
        if r.obj then out[#out + 1] = "> Objective: " .. r.obj end
        out[#out + 1] = ""
    end
end
RES = table.concat(out, nl)
`;

function toMarkdown(luaSource) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const run = c => { if (lauxlib.luaL_dostring(L, to_luastring(c))) throw new Error(to_jsstring(lua.lua_tolstring(L, -1))); };
  run(luaSource);
  run(BUILD);
  lua.lua_getglobal(L, to_luastring('RES'));
  return to_jsstring(lua.lua_tolstring(L, -1));
}

module.exports = { toMarkdown };

if (require.main === module) {
  const [, , input, output] = process.argv;
  if (!input) { console.error('usage: node dev/tools/lore_extract.js <SavedVariables/Skald.lua> [out.md]'); process.exit(1); }
  const md = toMarkdown(fs.readFileSync(input, 'utf8'));
  const out = output || path.join(__dirname, '..', 'lore', 'lore_' + new Date().toISOString().slice(0, 10) + '.md');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, md + '\n');
  console.log('written: ' + out + ' (' + md.split('\n').length + ' lines)');
}
