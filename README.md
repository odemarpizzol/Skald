# Skald

**An epic first-person diary of your journey through Azeroth, written as you play and kept in a leather-bound book.**

Skald listens to what happens on the road (quests, levels, deaths, new lands, dungeons, bosses, achievements, professions) and writes each event as a short page in the first person. Quests are told by what they asked of you, and the rarer the deed, the grander the telling. Open the book any time to read your story, one day per page, and write a line of your own at the foot of each day.

> **Beta.** Skald is in beta, like the game it is made for. It works, but some events have not been seen in a real session yet (see Limits). Please report what you find.

Made for **World of Warcraft: Forever** (beta). Texts in **English**, **Brazilian Portuguese** and **French** (French not yet reviewed by a native speaker): the diary follows your game client's language.

## Features

- **A real book.** Cover with your 3D character and the story so far, a contents page with chapters by level, one day per page, page-turning corners, leather tabs on the edge.
- **Written for you, not logged.** Every event becomes a sentence in the first person. Quest pages change with the kind of quest: a battle is not told like a letter you carried across town.
- **Quest rarity, like item quality.** Quests are graded from grey to orange from their reward, their chain and their story. Tiny errands can stay unwritten (you choose how many quests are written); long chains and epic deeds get a page of their own, and a few hand-picked stories are told in their own words.
- **One day, one page.** Each calendar day gets a title, a date, the places you visited, and a closing line for the night.
- **Items you find.** Gear you receive (weapons, armour, rings, amulets, cloaks, bags) becomes a page with an icon of its kind and a line chosen by what it is and how it came to you (found, crafted, a reward). Meat, pelts and other loose goods are left out unless they are rare, so the diary stays clean. You choose the smallest rarity; a day writes only so many.
- **Make it yours.** In Options: choose what the quill records (quests, levels, deaths, bosses and dungeons, lands, professions), the smallest quest rarity that becomes a page (click a seal), the text size, the ink (sepia, iron gall, burgundy), whether a new page starts each real day or each login, and whether each night gets a closing line.
- **It writes back.** A small notice when something worth remembering is written, milestones of the journey (100 creatures, 100 quests, your first gold...), the companions who stood with you, the hour of the day, your pet.
- **Your voice.** In the Style tab: the narrator's voice (epic, humble, playful), the colour of the leather cover (or by faction) and your own title on the cover.
- **Your own notes.** Reach for the inkwell at the foot of a day and write a line in your own hand; it becomes a page of the diary, dated and kept in order.
- **The journey in numbers.** Lands discovered, quests, levels, deaths, dungeons, creatures slain (read from the game's own Statistics panel), bosses, achievements, your deadliest land, time on the road, and a count of quests by rarity.
- **One diary per character.** If a new character takes the name of an old one, the old diary is set aside and can be restored.
- **Export.** Copy your diary as plain text or Discord-ready markdown, split into parts that fit a message.
- **Works with Spoken and QuestDB (optional).** QuestDB gives Skald the quest data used for rarity and quest type; without it Skald still works. Spoken gets a menu entry.

## Companion addons

Skald is one addon. The world-map pins (formerly the separate Skald Atlas) are built in.

### Map pins (built in since 0.31)

The map pins show the pages of your diary on the world map, as medallions coloured by rarity. **Click a pin to open its page in the book.** The **Map** tab of the book sets the pins on or off, their opacity, the smallest rarity, the kinds of page, **when** (all, this session, today) and **only favourite memories**; it also sums up the region you are in (first visit, quests, falls, foes, levels, items, favourites). In the book, the star beside a page marks it as a favourite memory (right-click it to write a note, which also shows on the map).

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
| `/skald help` | list the commands |

The **Options** tab holds the same switches, the text size, the ink, whether a new day starts each real day or each login, the page-turn sound,, the export button and the archive of old diaries.

## Limits (be aware)

- Skald writes only **out of combat**. Forever limits what addons can read in combat, and the diary never needs it.
- Skald is a **beta**. Developed and tested on the Forever beta. Some events (dungeons, bosses, groups, mounts, achievements, guild) are wired up but have not been seen in a real game session yet; if one fails, please report it.
- Quest rarity is an estimate from the data available; if you see an odd grade, tell us which quest.

## Credits

- Quest data (optional): the **QuestDB** addon, whose data comes from the CMaNGOS project.
- Fonts: **Cinzel**, **EB Garamond** and **Caveat**, under the SIL Open Font License (licences in `Fonts/`).
- All book art, icons and seals are original to Skald.

## Feedback

Please report problems and suggestions on the project page. Include your game language and, if there is a Lua error, the full text.
