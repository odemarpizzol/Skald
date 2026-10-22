// Static lint for the addon's Lua files (scope-aware, built on luaparse).
//   node tools/lint.js            prints a report, exit code 1 on a global leak or a limit breach
//
// It looks for
//   - global writes that are not intended (a missing `local`),
//   - locals that are declared and never read,
//   - the number of locals in each file's main chunk (WoW's Lua allows 200),
//   - the longest functions.
// It cannot know the game's own API names, so global reads are not judged.
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const ADDONS = path.resolve(__dirname, '../../..');
const FILES = ['Skald/Skald.lua', 'Skald/Atlas.lua', 'Skald/Goals.lua', 'Skald/Saga.lua', 'Skald/Locales.lua', 'Skald/Curated.lua', 'Skald/XPTiers.lua'].concat(fs.existsSync(path.join(ADDONS, 'SkaldAtlas')) ? ['SkaldAtlas/SkaldAtlas.lua'] : []);
const INTENDED_GLOBALS = new Set(['SkaldAPI', 'SkaldDB', 'SkaldCharDB', 'SkaldAtlasDB', 'SkaldAtlasStub',
  'SLASH_SKALD1', 'SLASH_SKALD2', 'SLASH_SKALDATLAS1', 'SLASH_SKALDATLAS2', 'SLASH_SKALD3']);
const LOCAL_LIMIT = 200, LOCAL_WARN = 185;

let leaks = 0, breaches = 0;
const BASELINE = path.join(__dirname, 'lint_baseline.json');
const baseline = fs.existsSync(BASELINE) ? JSON.parse(fs.readFileSync(BASELINE, 'utf8')) : null;
const update = process.argv.includes('--update-baseline');
const seenNow = {};
const sourcePath = file => {
  const installed = path.join(ADDONS, file);
  return file === 'SkaldAtlas/SkaldAtlas.lua' && !fs.existsSync(installed)
    ? path.resolve(__dirname, '../skald-atlas-repo/SkaldAtlas.lua') : installed;
};

function analyse(file) {
  const src = fs.readFileSync(sourcePath(file), 'utf8');
  const ast = luaparse.parse(src, { luaVersion: '5.1', locations: true });
  const unused = [], globalWrites = new Map(), functions = [], globalReads = new Set();
  let mainLocals = 0;

  const newScope = parent => ({ vars: new Map(), parent });
  const lookup = (scope, name) => { for (let s = scope; s; s = s.parent) if (s.vars.has(name)) return s.vars.get(name); return null; };
  const declare = (scope, id, kind) => {
    if (!id || id.type !== 'Identifier') return;
    scope.vars.set(id.name, { name: id.name, line: id.loc.start.line, reads: 0, kind });
  };
  const closeScope = scope => {
    for (const v of scope.vars.values()) {
      if (v.kind === 'local' && v.reads === 0 && !v.name.startsWith('_')) unused.push(`${v.name} (line ${v.line})`);
    }
  };

  function visitList(list, scope) { for (const n of list || []) visit(n, scope); }
  function visitBlock(body, parent) { const s = newScope(parent); visitList(body, s); closeScope(s); }

  function fn(node, scope) {
    const s = newScope(scope);
    for (const p of node.parameters || []) if (p.type === 'Identifier') declare(s, p, 'param');
    const start = node.loc.start.line, end = node.loc.end.line;
    const label = node.identifier ? (node.identifier.name || (node.identifier.identifier && node.identifier.identifier.name) || '?') : '(anonymous)';
    functions.push({ label, line: start, length: end - start + 1 });
    visitList(node.body, s);
    closeScope(s);
  }

  function visit(node, scope) {
    if (!node) return;
    switch (node.type) {
      case 'LocalStatement':
        visitList(node.init, scope);
        for (const v of node.variables) declare(scope, v, 'local');
        if (scope.parent === null || scope.isMain) mainLocals += node.variables.length;
        break;
      case 'AssignmentStatement':
        visitList(node.init, scope);
        for (const v of node.variables) {
          if (v.type === 'Identifier') {
            const found = lookup(scope, v.name);
            if (!found) globalWrites.set(v.name, (globalWrites.get(v.name) || 0) + 1);
          } else visit(v, scope);
        }
        break;
      case 'FunctionDeclaration':
        if (node.identifier && node.isLocal) {
          declare(scope, node.identifier, 'local');
          if (scope.isMain) mainLocals += 1;
        } else if (node.identifier && node.identifier.type === 'Identifier') {
          const found = lookup(scope, node.identifier.name);
          if (found) found.reads++;
          else globalWrites.set(node.identifier.name, (globalWrites.get(node.identifier.name) || 0) + 1);
        } else if (node.identifier) visit(node.identifier, scope);
        fn(node, scope);
        break;
      case 'IfStatement': for (const c of node.clauses) { visit(c.condition, scope); visitBlock(c.body, scope); } break;
      case 'WhileStatement': visit(node.condition, scope); visitBlock(node.body, scope); break;
      case 'RepeatStatement': { const s = newScope(scope); visitList(node.body, s); visit(node.condition, s); closeScope(s); break; }
      case 'DoStatement': visitBlock(node.body, scope); break;
      case 'ForNumericStatement': {
        visit(node.start, scope); visit(node.end, scope); visit(node.step, scope);
        const s = newScope(scope); declare(s, node.variable, 'loop'); visitList(node.body, s); closeScope(s); break;
      }
      case 'ForGenericStatement': {
        visitList(node.iterators, scope);
        const s = newScope(scope); for (const v of node.variables) declare(s, v, 'loop'); visitList(node.body, s); closeScope(s); break;
      }
      case 'ReturnStatement': visitList(node.arguments, scope); break;
      case 'CallStatement': visit(node.expression, scope); break;
      case 'Identifier': { const v = lookup(scope, node.name); if (v) v.reads++; else globalReads.add(node.name); break; }
      case 'MemberExpression': visit(node.base, scope); break;
      case 'IndexExpression': visit(node.base, scope); visit(node.index, scope); break;
      case 'CallExpression': visit(node.base, scope); visitList(node.arguments, scope); break;
      case 'TableCallExpression': visit(node.base, scope); visit(node.arguments, scope); break;
      case 'StringCallExpression': visit(node.base, scope); break;
      case 'BinaryExpression': case 'LogicalExpression': visit(node.left, scope); visit(node.right, scope); break;
      case 'UnaryExpression': visit(node.argument, scope); break;
      case 'TableConstructorExpression': for (const f of node.fields) visit(f, scope); break;
      case 'TableKey': visit(node.key, scope); visit(node.value, scope); break;
      case 'TableKeyString': visit(node.value, scope); break;
      case 'TableValue': visit(node.value, scope); break;
      default: break;
    }
  }

  const main = newScope(null);
  main.isMain = true;
  main.parent = null;
  visitList(ast.body, main);
  closeScope(main);
  return { unused, globalWrites, functions, mainLocals, globalReads };
}

console.log('Lint\n');
for (const file of FILES) {
  if (!fs.existsSync(sourcePath(file))) { console.log(file + ': missing'); breaches++; continue; }
  let r;
  try { r = analyse(file); } catch (e) { console.log(file + ': cannot parse: ' + e.message); breaches++; continue; }
  const lines = fs.readFileSync(sourcePath(file), 'utf8').split('\n').length;
  console.log(`${file}  (${lines} lines)`);
  const state = r.mainLocals >= LOCAL_LIMIT ? 'OVER THE LIMIT' : r.mainLocals >= LOCAL_WARN ? 'close to the limit' : 'ok';
  console.log(`  main-chunk locals: ${r.mainLocals} / ${LOCAL_LIMIT}  ${state}`);
  if (r.mainLocals >= LOCAL_LIMIT) breaches++;
  const bad = [...r.globalWrites.keys()].filter(n => !INTENDED_GLOBALS.has(n));
  if (bad.length) { leaks += bad.length; console.log('  GLOBAL WRITES (a missing "local"?): ' + bad.join(', ')); }
  else console.log('  global writes: only the intended ones');
  if (r.unused.length) console.log('  unused locals (' + r.unused.length + '): ' + r.unused.slice(0, 25).join(', ') + (r.unused.length > 25 ? ' ...' : ''));
  seenNow[file] = [...r.globalReads].sort();
  if (baseline && !update) {
    const fresh = seenNow[file].filter(n => !(baseline[file] || []).includes(n));
    if (fresh.length) { leaks += fresh.length; console.log('  NEW GLOBAL NAMES (a typo, or a game function to accept with --update-baseline): ' + fresh.join(', ')); }
  }
  const longest = r.functions.sort((a, b) => b.length - a.length).slice(0, 5).filter(f => f.length > 120);
  if (longest.length) console.log('  long functions: ' + longest.map(f => `${f.label} line ${f.line} (${f.length} lines)`).join('; '));
  console.log('');
}
if (update) { fs.writeFileSync(BASELINE, JSON.stringify(seenNow, null, 1) + '\n'); console.log('Baseline written: ' + BASELINE); }
console.log(leaks || breaches ? `${leaks} leak(s), ${breaches} limit breach(es)` : 'No leaks, no limit breaches');
process.exit(leaks || breaches ? 1 : 0);
