---
name: run-skald
description: Run, start, drive, test and deploy the Skald WoW addon. Use to "run Skald", poke the addon in the simulated game, run the checks/regressions, or copy the addon to the game folder to test it in the real client.
---

Skald is a World of Warcraft (Classic family) addon (Lua 5.1 in the client). It cannot run in this container: the real app is the game client on the user's Windows machine (WSL sees it as `/mnt/d`), so no screenshot is possible here. Here it is driven in a **simulation** (fengari, Lua 5.3, with `dev/tools/mock.lua` faking the WoW API). The simulation is NOT the game: always tell the user so. Paths below are relative to the repo root.

## Setup (once)

```bash
npm install --prefix dev/tools
```

The tools find the addon as `<parent of repo>/Skald`, so the clone folder must be named `Skald`.

## Run (agent path): the driver

```bash
node .claude/skills/run-skald/driver.js 'fire("PLAYER_LEVEL_UP", 7); print(count("level")); RES = SkaldCharDB.entries[#SkaldCharDB.entries].kind'
node .claude/skills/run-skald/driver.js --locale ptBR 'fire("PLAYER_LEVEL_UP", 7); print(table.concat(SkaldAPI.BuildExport("plain","all")," "))'
echo 'SlashCmdList.SKALD("density airy"); print(ns.DensityOf())' | node .claude/skills/run-skald/driver.js
```

The body is Lua run after `ADDON_LOADED` + `PLAYER_LOGIN`. In scope: `fire(event, ...)`, `runTimers()`, `count(kind)`, `btn(label)`, `ns` (includes Saga and ZoneCard), `SkaldAPI`, `SkaldCharDB`, `SkaldDB`. `print` shows on stdout (the addon's chat messages too); set `RES` to print a value last. Options: `--locale enUS|ptBR|frFR`, `--saved '<lua table>'` (starts with that `SkaldCharDB`), `--level N`. A Lua error prints `ERROR: ...`.

For a new scenario worth keeping, add it to `dev/tools/regressions.js` (look at the existing `run(...)` entries) instead of only running it once.

## Checks and tests

```bash
node dev/tools/checks.js          # syntax, textures, lint, phrases en/pt/fr, simulated session, regressions, Reader, speed
node dev/tools/regressions.js     # only the regression scenarios
node dev/tools/validate_phrases.js
```

Run `checks.js` before saying anything is ready. Green means "no obvious error", not "works in the game".

## Test in the real game (human path)

The user tests in the client. Copy only what the game uses (the folder in WSL is the D: drive):

```bash
D="/mnt/d/Games/World of Warcraft/_anniversary_/Interface/AddOns/Skald"
rsync -rcn --itemize-changes --exclude=.git --exclude=.github --exclude=.gitignore --exclude=.pkgmeta --exclude=.claude --exclude=dev --exclude=docs --exclude=CLAUDE.md --exclude=README.md --exclude=CHANGELOG.md --exclude=LICENSE ./ "$D/"
```

The repo keeps `## Interface: 16001`; the Anniversary client needs 20506, set **only in the copy** (`sed -i "s/^## Interface:.*/## Interface: 20506/" "$D/Skald.toc"`). Never copy `dev` into `_retail_` (that has its own branch/worktree `retail`). That is a dry run (`-n`): it lists what differs. To copy, run it again without `-n`, or `cp` the changed file (what was done so far for `Skald.lua`). Then tell the user to `/reload` in the game; **new textures need a full game restart**.

## Gotchas

- `print` is captured by `mock.lua` into a table; the driver replaces it with a stdout writer. `dev/tools/regressions.js` does not, so there use `RES`.
- Lua with backslashes: write files with Write/Edit, not heredocs or `node -e` (the shell eats them). Python heredocs are fine unless the text has `\n`-style escapes: check the result.
- The simulation fakes the window: layout cache and real drawing are not exercised (only that `ns.layoutRev` changes). A visual change needs the user's screenshot from the game.
