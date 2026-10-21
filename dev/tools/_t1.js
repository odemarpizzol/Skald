const fs=require('fs');let s=fs.readFileSync('regressions.js','utf8');
const add = `
const DUNGEON = \`function IsInInstance() return true, "party" end
function GetInstanceInfo() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end\`;
const BOSSES = (n) => \`local function boss(name) fire("BOSS_KILL", 1, name); runTimers() end
local function last() return SkaldCharDB.entries[#SkaldCharDB.entries] end\`;

run('a boss after falls in the same dungeon is told as a hard-won victory, by number', {
  pre: DUNGEON,
  body: \`\${BOSSES()}
fire("PLAYER_DEAD"); fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
boss("Edwin VanCleef")
local e = last()
local text = SkaldAPI.Render(e)
fire("PLAYER_DEAD"); NOW = NOW + 100
boss("Rhahk'Zor")
local next = last()
RES = (e.kind == "boss" and e.tries == 3 and text:find("VanCleef", 1, true) and next.arg == "Rhahk'Zor" and next.tries == nil)
  and "ok" or ("tries=" .. tostring(e.tries) .. " text=" .. text .. " next=" .. tostring(next.tries))\`,
});

run('a boss without falls, or with falls long forgotten, is told as usual', {
  pre: DUNGEON,
  body: \`\${BOSSES()}
boss("Rhahk'Zor")
local plain = last().tries
fire("PLAYER_DEAD"); NOW = NOW + 3 * 3600
boss("Sneed's Shredder")
RES = (plain == nil and last().tries == nil) and "ok" or "a stale fall counted"\`,
});

run('falls outside a dungeon do not count for a boss', {
  body: \`\${BOSSES()}
fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "The Deadmines", "party", 1, "", 5, 0, false, 36 end
boss("Edwin VanCleef")
RES = (last().tries == nil) and "ok" or "falls outside were counted"\`,
});

run('twelve hard-won victories in a row do not repeat a sentence', {
  pre: DUNGEON,
  body: \`\${BOSSES()}
local seen, same = {}, 0
for i = 1, 8 do
  fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
  boss("Boss " .. i); NOW = NOW + 60
  local t = SkaldAPI.Render(last()):gsub("Boss %d+", "B")
  if seen[t] then same = same + 1 end
  seen[t] = true
end
RES = same == 0 and "ok" or (same .. " repeated")\`,
});
`;
const k = s.indexOf("console.log(failed ?"); s = s.slice(0, k) + add + "
" + s.slice(k);
fs.writeFileSync('regressions.js',s);
