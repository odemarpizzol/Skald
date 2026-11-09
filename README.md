# Skald

**An epic first-person diary of your journey through Azeroth, written as you play and kept in a painted, leather-bound book.**

Skald listens to what happens on the road (quests, levels, deaths, new lands, dungeons, bosses, battlegrounds, achievements, professions) and writes each event as a short page in the first person. Quests are told by what they asked of you, and the rarer the deed, the grander the telling. Open the book any time to read your story, one day per page, and write a line of your own at the foot of each day.

> **Version 1.0.** The core of the diary (quests, levels, deaths, lands, dungeons and bosses, groups, guild, flights, professions) has been seen working in a real Forever session. Some events have not been seen in a real session yet: battlegrounds, mounts, achievements, weather and the Skyborne lines (see Limits). Please report what you find.

Made for **World of Warcraft: Forever** (1.60.1, from 4 November 2026) and **TBC Classic Anniversary** (2.5.6). Texts in **English**, **Brazilian Portuguese**, **French** and **Spanish** (French and Spanish not yet reviewed by a native speaker): the diary follows your game client's language.

## Features

- **A real book.** Cover with your 3D character and the story so far, a contents page with chapters by level, one day per page, page-turning corners, and tabs on the edge in five looks (leather, ribbon, brass, parchment, carved wood). The pages come in four papers (clean, travel, battle, old book).
- **Written for you, not logged.** Every event becomes a sentence in the first person. Quest pages change with the kind of quest: a battle is not told like a letter you carried across town.
- **Quest rarity, like item quality.** Quests are graded from grey to orange from their reward, their chain and their story. Tiny errands can stay unwritten (you choose how many quests are written); long chains and epic deeds get a page of their own, and a few hand-picked stories are told in their own words.
- **One day, one page (Journeys).** Each calendar day gets a title, a date, the places you visited, the weather of the land, little drawings of what the day held (with a count when there is more than one) and a closing line for the night.
- **Search.** Type a word of a quest, a place, a giver, a companion or a note and the pages found are listed, newest first, with the words found painted; a click opens the page.
- **Items you find.** Gear you receive (weapons, armour, rings, amulets, cloaks, bags) becomes a page with an icon of its kind and a line chosen by what it is and how it came to you (found, crafted, a reward). Meat, pelts and other loose goods are left out unless they are rare, so the diary stays clean. You choose the smallest rarity; a day writes only so many.
- **Make it yours.** In Options: choose what the quill records (quests, levels, deaths, bosses and dungeons, lands, professions), the smallest quest rarity that becomes a page (click a seal), the text size, the ink (sepia, iron gall, burgundy), whether a new page starts each real day or each login, and whether each night gets a closing line.
- **It writes back.** A small notice when something worth remembering is written, milestones of the journey (100 creatures, 100 quests, your first gold...), the companions who stood with you, the hour of the day, your pet.
- **Your voice.** In the Style tab: the narrator's voice (of my people, epic, humble, playful; "of my people", the voice of a new install, speaks as your race in the time of the game, with no numbers of level or points), the colour of the leather cover (or by faction), your own title on the cover, the look of the tabs and the size of the book. The paper of the pages is chosen on the Notices page.
- **Your own notes.** Reach for the inkwell at the foot of a day and write a line in your own hand; it becomes a page of the diary, dated and kept in order.
- **The journey in numbers.** Lands discovered, quests, levels, deaths, dungeons, creatures slain (read from the game's own Statistics panel), bosses, achievements, your deadliest land, time on the road, and a count of quests by rarity.
- **One diary per character.** If a new character takes the name of an old one, the old diary is set aside and can be restored.
- **Story, not just a log.** A boss beaten after you fell to the dungeon says so; the last quest of a chain tells how many days the story took; someone who stood beside you in a dungeon and joins your group again is told as old company; coming back to a land where something dear happened brings a quiet memory (all can be switched off in Options).
- **Deeds and points.** A tab of 74 goals in eight groups (the road, exploration, stories, war, crafts, beasts, company, fortune and renown): levels, lands, flight paths, quests and chains, dungeons, bosses, battlegrounds won, creatures, trades, pets, companions, guild, group, gold and reputation. Each goal is worth points by the rarity of its seal (5, 10, 25, 50 or 100) and the total earns a title. The diary checks them by itself, so what you did before counts; each goal reached becomes a page that says its points. Goals added in a later version are marked quietly the first time, without pages.
- **Saga.** The diary told again as chapters, in the first person.
- **Bard.** A jukebox of 33 pieces of the game's own music (27 in Forever, which is set before the time of Outland), with shuffle, skip and the volume of the game's music. With the book shut, a notice on the screen (four looks) shows the song that plays; the game cannot pause or seek a piece.
- **Backup and restore.** `/skald backup` writes the whole diary as text, in parts; `/skald restore` takes it back, only on the character it came from, and keeps one copy to undo. Favourites and notes are never dropped, whatever the size of the book.
- **Cartographer (Charts).** A collection of hand-drawn maps: the lands, the cities and 44 dungeons, raids and battlegrounds, in colour where the character has stood and faded elsewhere. The Index page draws the map of the dungeon or battleground you stand in.
- **Weather.** Rain, snow or a sandstorm strong enough becomes a page of its own (at most one every 45 minutes).
- **Battlegrounds.** A match won or lost becomes a page (Darkspear Islands and the older fields), and wins count for three goals.
- **Skyborne.** Forever's new race has lines of its own for new lands, levels and falls, and the Saga names the isle where the character was born.
- **Crafts counted.** Making the same thing again and again is one page that says how many.
- **Skald Reader.** Read your diary as a book outside the game: type `/skald reader`, copy the text and paste it on the Reader page (odemarpizzol.github.io/Skald/reader). It runs in your browser, sends nothing anywhere, and can be saved as a PDF.
- **Export.** Copy your diary as plain text or Discord-ready markdown, split into parts that fit a message. The names of other players are hidden unless you choose to show them.
- **Works with Spoken and QuestDB (optional).** QuestDB gives Skald the quest data used for rarity and quest type; without it Skald still works. Spoken gets a menu entry.

## Companion addons

Skald is one addon. The world-map pins (formerly the separate Skald Atlas) are built in.

### Map pins (built in since 0.31)

The map pins show the pages of your diary on the world map, as medallions coloured by rarity. **Click a pin to open its page in the book.** The **Atlas** tab of the book sets the pins on or off, their opacity, the smallest rarity, the kinds of page, **when** (all, this session, today) and **only favourite memories**; it also sums up the region you are in (first visit, quests, falls, foes, levels, items, favourites). In the book, the star beside a page marks it as a favourite memory (right-click it to write a note, which also shows on the map).

## Using it

Open the book with the minimap button, or type `/skald` (or `/sk`).

| Command | What it does |
| --- | --- |
| `/skald` | open or close the book |
| `/skald clear` | erase this character's diary (asks first) |
| `/skald detail low\|normal\|high` | how many quests are written |
| `/skald quiet` | toggle the message at login |
| `/skald minimap` | show or hide the minimap button |
| `/skald export` | export the diary as text |
| `/skald backup` / `/skald restore` | save the whole diary as text / bring it back (`restore undo` goes back one step) |
| `/skald retention` | review and accept the 5,000-page limit; pages are kept until you explicitly accept |
| `/skald density compact\|comfy\|airy` | how full the pages are |
| `/skald report` | text of what happened, for a bug report |
| `/skald reader` | the whole diary as text for the web Reader |
| `/skald forgetcompanions` | forget the companions the diary remembers |
| `/skald help` | list the commands |

The **Settings** tab has three pages, turned with the corners of the book: **Style** (voice, ink, text size, density, cover, tabs), **Notices** (the notices, where they appear and for how long, the paper) and **Options** (what the quill records, the smallest rarity, the day and night, the page-turn sound, the export button and the archive of old diaries).

## Limits (be aware)

- The diary warns as it approaches 5,000 pages. It keeps every page until you explicitly accept the limit. After acceptance, the oldest ordinary pages are removed as new ones arrive; favourites and personal notes are always kept. Save a copy with `/skald backup` before accepting. You can postpone the choice and review it later with `/skald retention`.
- Skald writes pages as events happen, even in combat (a level gained at the end of a fight, for example), but it never reads anything the game withholds from addons in combat; only the quiet memories wait for the fight to end.
- Forever is a client of the modern (Mainline) family that hides some values from addons; Skald skips them instead of guessing, so a boss or an item the game withholds in a fight may go unwritten. Tested in the real Forever client (quests, levels, deaths, dungeons, bosses, groups, guild) and in a simulation of it; the battleground pages, mounts, achievements, weather pages, the Skyborne lines and the maps of the newer instances (their ids come from the game's data and have not all been read inside the instance) have not been seen in a real session yet; if one fails, please report it.
- In the Forever client some pieces of Bard music (from the expansions) may be silent.
- Quest rarity is an estimate from the data available; if you see an odd grade, tell us which quest.

## Credits

- Quest data: the **QuestDB** addon by Pimptasty (MIT), whose data comes from the **CMaNGOS** project (classic-db and tbc-db, GPL-3.0, facts re-expressed). The quests of each land that the Index counts travel with Skald in `QuestZones.lua`, derived from QuestDB's data (the notice is in the file); WoW Forever's own quests come from TOGTools through QuestDB.
- Fonts: **Cinzel**, **EB Garamond** and **Caveat**, under the SIL Open Font License (licences in `Fonts/`).
- All book art, icons and seals are original to Skald.

## Feedback

Please report problems and suggestions on the project page. Include your game language and, if there is a Lua error, the full text.
