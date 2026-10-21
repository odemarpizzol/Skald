# Skald tools

Install once (needs Node.js):

```
cd tools
npm install
```

## Checks (before any release)

```
node tools/checks.js
```

Compiles every Lua file, checks that the named textures exist, validates every phrase in English, Portuguese and French, and runs a simulated session (the book opens, every tab exists, the layout audit finds nothing, a hunter's pet, the hearthstone and a resurrection write their pages). It is a simulation: a green run means "no obvious error", not "works in the game".

## Regressions

`node tools/regressions.js` runs twelve scenarios in fresh simulated games, each one a thing that went wrong once: a change of language, a renamed or a loaned pet, old pages told again by id, the old separate Atlas, the reminder on returning, an event that fails, saved positions... `checks.js` runs them too. When a bug is found in the game, add a scenario for it here before fixing it.

## Release in one command

1. Write the bullet points of the new version in `NEXT_CHANGELOG.md` (one `- ...` per change, no header).
2. Run:

```
node tools/release.js 0.31.2-beta
```

It runs the checks, writes the version into `Skald.toc`, adds it to `CHANGELOG.md`, writes `CHANGELOG_<version>_para-colar.md`, refreshes `skald-repo/`, builds `Skald-<version>.zip` (compressed, `Skald/` at its root) and prints the changelog to paste. Nothing is sent anywhere.
3. Upload the zip on CurseForge and paste the changelog.
4. Empty `NEXT_CHANGELOG.md`.

## Upload to CurseForge by the script (optional)

You need a CurseForge API token (your account, "API tokens") in `CF_API_TOKEN`, and the id of the game version Skald targets:

```
set CF_API_TOKEN=your-token
node tools/release.js --list-game-versions
node tools/release.js 0.31.2-beta --upload --game-version <id>
```

This upload has not been tried yet. Run it once with a throwaway beta and look at the result on the project page before relying on it.
