# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Skald is a World of Warcraft "Forever" (beta, `## Interface: 16001`) addon: an epic first-person auto-diary shown as an open leather book. Texts in en/ptBR/frFR. The user replies and works in Portuguese. This clone is the official workspace; the addon is copied into `Interface\AddOns\Skald` of the game folder (under Windows, `D:\Games\World of Warcraft\_classic_beta_`) only to test it in the game. See `dev/HANDOFF.md` for the state of the work and the user's preferences, and `dev/ROTEIRO_TESTE_0.37.md` for the in-game test script.

## Commands

```
npm install --prefix dev/tools        # once
node dev/tools/checks.js              # everything: syntax, textures, lint, phrases en/pt/fr, simulated session, regressions, Reader, speed
node dev/tools/regressions.js         # only the regression scenarios (add one per bug found in the game, before fixing it)
node dev/tools/validate_phrases.js    # only the phrase pools
node dev/tools/lint.js [--update-baseline]   # scope-aware lint; --update-baseline accepts a new game API global
node dev/tools/serve_docs.js          # preview of the web Reader (docs/reader)
```

Run `checks.js` before saying anything is ready. It runs Lua 5.3 in fengari with `dev/tools/mock.lua` standing in for the WoW API: a green run means "no obvious error", **not** "works in the game". Always tell the user the simulation is not the game.

The tools resolve the addon as `<parent of repo>/Skald`, so the clone folder must be named `Skald`. `dev/tools/release.js` still assumes the old `Skald-publish` layout and has not been adapted to this clone.

The release workflow runs `checks.js` first (job `checks`, then `release`); it needs `dev/tools` committed.

Releases: bullets in `dev/NEXT_CHANGELOG.md` (English), version in `Skald.toc` and `CHANGELOG.md`, commit, then push a tag `vX.Y.Z-beta`; GitHub Actions (`.github/workflows/release.yml`, BigWigs packager, secret `CF_API_KEY`) uploads to CurseForge (project 1748824). `.pkgmeta` excludes `dev`, `docs`, `.github`, README and CHANGELOG from the package. Publish only when the user says "publica"; the user picks the version number.

## Architecture

Load order (`Skald.toc`): `Locales.lua`, `Curated.lua`, `XPTiers.lua`, `Skald.lua`, `Atlas.lua`, `Goals.lua`, `Saga.lua`; shared through the addon namespace `ns`. SavedVariables: `SkaldDB`, `SkaldAtlasDB` (account), `SkaldCharDB` (per character).

- Everything the diary knows about a character besides pages (pets, companions, flights, goals, standings...) is listed in `K.DIARY_STATE`: it is cleared with the diary and archived/restored with it. A new per-character key in `SkaldCharDB` must be added there.
- A new goal in `Goals.lua` must carry `since = <the next GOALS_VERSION>` and `GOALS_VERSION` must go up with it; without that every existing diary writes a page and a notice for each goal it finds already done on its next login. Points come from the seal (`tier`) and are never stored.
- **The diary stores IDs, numbers and a phrase index (`idx`), never text.** Page text is built live (`PoolFor` / `RenderEntry` / `Extras` in `Skald.lua`) from phrase pools in `Locales.lua`, so a change of language or of voice rewrites old pages. Anything that rewrites pages in place must bump `ns.layoutRev` (the page layout is cached in `Layout()` inside `CreateWindow`).
- `Skald.lua` (~6400 lines) holds events (`EVENT_HANDLERS` table, dispatched by `HandleEvent`), milestones (`Mile`), the book window (`CreateWindow`, ~1200 lines), settings tabs (`f:AddTab`, order by `TAB_RANK`), export (`BuildExport`, `PlainText`, the Reader format) and the slash commands. Constants and helpers live in the tables `K`, `Mile` and `ns`, because the WoW Lua 5.1 chunk is limited to 200 locals (lint fails past that).
- `Atlas.lua`: world-map pins, built in since 0.31 (standalone SkaldAtlas is only a stub). `Goals.lua`: the clickable Goals tab, using the `AddTab` pattern; new tabs should copy it. `Curated.lua`: hand-written quest stories. `XPTiers.lua`: level/XP tiers.
- `docs/reader`: the web Reader (GitHub Pages, main branch `/docs`), plain HTML/JS with no dependencies. The game exports text with `/skald reader` (header, one line per page, fields separated by a caret `^`, parts with a checksum); the user pastes it in the page, nothing is sent anywhere. `dev/tools/reader_test.js` tests the parser against a real simulated export.
- `Saga.lua`: `ns.BuildSaga()` tells the diary as chapters in the first person (a tab, pages by the size of the letter). Its phrases live in `Saga.lua` (`ns.SagaTexts`), are checked by `validate_phrases.js`, and each is picked by a hash of the diary's first date, so the same diary gives the same Saga. The Saga also travels in the Reader export as `V` lines (parsed in `docs/reader/reader.js`, which skips line types it does not know). Reading aloud (`ns.SpeakTexts`, `/skald read`) uses `C_VoiceChat.SpeakText(voice, text, rate, volume, false)` as DialogueUI does in this client; unverified by the user so far. The larger plan (Saga, shared chronicle, TTS, memories of time) is in the user's plan file `refactored-discovering-aurora.md`.

## Art

All art is made by the user, a human, directly in Claude Design; Claude Code does not draw it. When Claude sees an opportunity for an icon or picture (a new page kind, a family, a seal, a tab, a Reader header), it should say so and write a ready-to-paste prompt for Claude Design. That prompt must follow strictly the style of the art already in the addon (look at `Textures/` and `docs/reader/img` first and describe that style in the prompt: same palette, line, lighting, framing and level of detail), and ask for the size and margin needed (power-of-two canvas, about 8% free space at the edges so nothing touches the border). The user sends the PNGs back (zip in `Interface\` or Downloads); Claude converts them to TGA (32-bit, power of two) with sharp, wires them in code and runs `checks.js`. Never ship a placeholder or an invented picture in place of the user's art.

## Rules that are easy to break

- Lua is the 5.1 of the WoW client: no `\u` escapes, no Lua 5.3 features. Write Lua/JS containing backslashes with the Write/Edit tools; the shell (heredoc, `node -e`) swallows them.
- Every new string or phrase goes in all three locale blocks (en/pt/fr) of `Locales.lua`. French is written by Claude without native review; `Locales.lua` is its source of truth (do not regenerate it), and French punctuation uses NBSP (`\194\160`) before `: ; ? !` and inside «». Pools should have at least 8 variants (`validate_phrases.js` lists the shorter ones as debt, and it fails below 5; today none is below 8); `AddEntry` avoids repeating a phrase within the last 5 of the same kind (a regression covers it). Gendered words use the `{g:he|she}` tag (`ns.Gendered`).
- In the Reader text a bar `|` starts an escape code in the game's text boxes, hence the caret as field separator.
- New textures: TGA 32-bit, power-of-two size, in `Textures/` (all names used in code are checked by `checks.js`). They only show in the game after a full restart, not `/reload`.
- Pages are written when the event fires, in combat too (`AddEntry` has no combat check; only memories wait). Do not claim the contrary in docs; payloads the client withholds are skipped with `Safe()`.
- Several events are still unverified in the real client (see README "Limits").
- User preferences: no TRP3 integration; Goals stay a clickable list; phrase variety is a permanent wish; no tiny versions; art is made by the user in Claude Design (prompt the user, they send PNGs, convert to TGA with sharp).
