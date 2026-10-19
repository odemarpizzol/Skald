# Changelog

## 0.31.7-beta

- **Pets tab:** the companion at your side is shown in 3D, turning in an arched frame like your character on the cover (when the pet is not out, the paw takes its place), together with its diet. The total number of companions moved to the right page.

## 0.31.6-beta

- **Faster book:** turning pages in a long diary no longer measures every line again (the layout is kept until something changes): about a hundred times faster in a diary of 3000 pages.
- **Lighter on the game:** spell casts and pet changes are only requested for your own character, so Skald is no longer called for every cast in a raid; money changes are looked at once every few seconds.
- Fix: reputation changes after the first one were not noticed until the next login (a mistake in the check that avoids repeated looks).
- Developer: the code was tidied (constants gathered, dead code removed, about 65 free slots of the 200-local limit of Lua), and the release checks now include a lint and a speed test.

## 0.31.5-beta

- **New icons:** the resurrection page has a winged ankh, the Skinning Knife, the Mining Pick, the blacksmith's hammer and the engineer's spanner have their own drawings, tabards are drawn as a tabard, and the pet's paw matches the new set.

## 0.31.4-beta

- The hunter's tab is called "Pets" (it was cut off in the tab) and its right page has a shorter title, so the list no longer touches the rule.

## 0.31.3-beta

- **Hunters: the companions tab.** A new "Companions" tab in the book shows the pet at your side (name, family, level, since when) and every pet you have had. Pet pages now have their own paw icon and tell the family of the animal.
- Skald's map pins: pets have their own kind of marker and filter.

## 0.31.2-beta

- While your character is a spirit, the cover shows the portrait in a round medallion (the model returns when you are alive again).

## 0.31.1-beta

- **The Hearthstone.** A new page when you use the hearthstone to go home, told with the name of the place where you land. Nothing is written when you use it at the very place it takes you.
- Developer: `/skald probe spells` also records the spells you cast yourself.

## 0.31.0-beta

- **Skald Atlas is now part of Skald.** The pins of your journal on the world map, the "Map" tab (show or hide the markers, smallest rarity, kinds of page, opacity) and the `/skatlas` command are built in: there is nothing else to download. If you had the separate Skald Atlas addon, update it to its last version (it only says that it can be removed) and delete it; until then Skald keeps out of its way and nothing is drawn twice.

## 0.30.5-beta

- **Back from the dead.** A new page when your character returns to life: one voice for the spirit healer, another for the walk back to your own body.

## 0.30.4-beta

- **Icons reviewed.** Claws, spears and "miscellaneous" weapons now use the book's weapon icons instead of the game's square one; food and drink and bandages have drawn icons; the "home bound" page uses the hearthstone.

## 0.30.3-beta

- The Skinning Knife is drawn as a dagger, and the Mining Pick and the blacksmith's hammers as a mace, like the other weapons of the book (they showed the game's own square icon).

## 0.30.2-beta

- **A minimap button of its own.** Skald installed alone now has its round button on the edge of the minimap (click to open the book, drag to move it around the minimap). It no longer needs the Spoken addon for that; with Spoken installed, the button stays in Spoken's menu as before. It can still be hidden in the Style tab or with `/skald minimap`.
- **"Where was I?" redone:** a parchment card with small sections: where the last visit ended, the quests still open, and your note in handwriting. The place is told in the current language of the game. A click opens the book.

## 0.30.1-beta

- **Quest summary on hover:** pass the mouse over a quest page to see a short summary: the title in the colour of its rarity, level and rarity, the objective in plain words, the reward (experience and money), who gave the quest, the place and the date. The objective and the reward come from QuestDB (optional).
- **Pages follow the language of the game.** Quests, items, professions and places are now kept by their id and told in the current language of the client, so changing the language no longer leaves old pages in the old one (and no longer writes a page again for every profession and land already visited). Old pages are brought along at login; `/skald tidy` does it on demand and removes the pages that were repeated by a change of language.
- Pages now remember the id of the item, the map of their place and the creature who gave the quest.
- Fix: the cover shows your portrait instead of a pale wisp while you are a spirit.
- Fix: a death while the zone name is empty no longer leaves a blank in the page.

## 0.30.0-beta

- **Where was I?** On returning after a break of twenty minutes or more, a small parchment recalls where you left off (place and level), the quests still open and an optional note to yourself. Leave the note with `/skald next <text>`; `/skald resume` shows it again in the chat. Can be switched off in the Style tab.
- **Hunters: your companions.** A new page when a pet joins you (the first pet of a new hunter, and each pet after), and another on the day a pet grows to your own level. A hunter who already has a pet when the diary first looks is not told about it.
- Developer: `/skald probe spells` records the spells you learn and the pet events the client reports, to prepare the class milestones of the next versions.

## 0.29.0-beta

- **Français.** The whole diary is now available in French (frFR): every page of the chronicle (quests, items, bosses, levels, deaths, classes, races, narrator's voices), the book, the options, the export and the curated stories of legendary quests. Skald Atlas is translated too. The French was written with Claude and has not yet been read by a native speaker: corrections are welcome.

## 0.28.2-beta

- Fix: the layout audit (`/skald qa`) no longer reports text that simply wraps onto several lines as "cut off".

## 0.28.1-beta

- Developer: `/skald qa` audits the layout of every page and tab (text cut off, running into the foot of a page, across the gutter, drawn over other text, a font that did not load) and keeps the report in the saved variables.

## 0.28.0-beta

- **A notice when a page is written** while the book is closed (level, boss, dungeon, rare item or quest, achievement, mount, milestone...): a small parchment with the quill and a page-turn sound; the minimap button glows for a few seconds. A click opens the book. Can be switched off in the Style tab.
- **Milestones of the journey:** pages for round numbers of creatures slain (100, 500, 1000...), quests, falls and gold.
- **New pages:** home bound at an inn, reputation reached (Friendly and above), a flight path learned. (These three have not been seen in a real Forever session yet.)
- **Who was there:** dungeons, bosses and falls name the companions in your group; a line of the hour of the day (dawn, morning, afternoon, dusk, night); your pet at your side.
- **Chapters carry the name of the place** where most of their days were spent.
- **Style tab:** the narrator's voice (epic, humble, playful), the colour of the leather (brown, blue, green, wine, grey, or by faction), your own title on the cover, the notices on or off.

## 0.27.0-beta

- **Pages that know who you are.** The nine classes (warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid) have their own lines for quests, levels, deaths and bosses; the eight races (human, dwarf, night elf, gnome, orc, undead, tauren, troll) for new lands, deaths and levels. About four pages in ten are told in your class's or your race's voice.
- **Quests that were hard or easy for your level** have lines of their own.
- **Items by kind:** swords, axes, maces, staves, ranged weapons, daggers and wands, and cloth, leather, mail and plate each add their own lines.
- About 200 new phrases in English and in Portuguese.

## 0.26.3-beta

- **Less repetition:** about 120 new phrases in English and in Portuguese (quests of every kind, items, new lands, levels, deaths, bosses, dungeons, the closing line of the day), and the diary no longer tells one of the last five phrases of a kind again.
- The map row of the cover reads "Flights taken" (was "Flight paths taken"); the flight icon is the gryphon (Alliance) or the wyvern (Horde).

## 0.26.2-beta

- **Icons for every kind of weapon and more:** dagger, greatsword, polearm, fist weapon, bow, crossbow, gun, thrown weapon, wand, fishing pole, relic and ammo; plus helm, shoulders, gloves, legs, boots, belt, bracers, shield, off-hand, axe, mace and staff. Items without a drawn icon keep the game's own.
- **Cover:** two more rows (flight paths taken, camps made) and drawn icons for gold earned, creature type slain most, flight paths and camps.

## 0.26.1-beta

- **The cover now shows the game's own totals** (Statistics): quests, deaths, dungeons entered, bosses, creatures slain; levels follow your level. New rows: gold earned and the creature type you have slain most. Where a number cannot be read the diary's own count is used.
- **Items:** hover an item page to read its tooltip (beside the book, without the comparison); shift-click puts the link in chat. Item names are written in the dark ink of their rarity so they read on parchment; the item's kind decides its icon (helm, gloves, boots, belt, bracers, legs, shoulders, shield, off-hand, axe, mace, staff, sword, armour, ring, amulet, trinket, cloak, bag); anything else shows the game's own icon. Shields and off-hand items count as gear.
- Fixes: the quality of an item is read from the new client's colour codes; the page header shows your character and the chapter.
- Developer: `/skald stats` lists every statistic of the game into the saved variables; `/skald probe` records quest data.

## 0.26.0-beta — first public beta

- **Items.** Gear you receive (weapons, armour, rings, amulets, trinkets, cloaks, bags) becomes a page with its own icon and a line by kind and by how you got it. Other goods only if rare (blue or better); switch in Options. Smallest rarity and a daily limit keep it tidy.
- **Notes.** The inkwell at the foot of a day opens a ruled line on the page; what you write becomes a dated page of the diary. Old one-line notes are converted.
- **Options redesigned:** what the quill records, smallest rarity for quests and for items (click a seal), text size, ink (sepia, iron gall, burgundy), a new day each real day or each login, closing line each night, page-turn sound.
- **Book:** new rarity seals and icons, a "Today" button when you are away from the newest day, a brass close stud, a header with your character and the chapter, a day with no place shows only its date.
- Page-turn sound; an event that fails is reported once instead of repeating.
- The diary now keeps up to 3000 pages (it was 500).
- Fixes: the saved text size now applies at login; the date line no longer shifts left when turning pages; the note box no longer covers the entries; the corners of the pages no longer show a pale wedge.

## 0.25.0 — first build as Skald

- Renamed from the working title *Chronicler* to **Skald**. Commands are now `/skald` and `/sk`.
- New window: a leather-bound open book with a cover (3D character and the story so far), contents by chapter, one day per page, notes of your own, leather tabs and page-turning corners. Cinzel, EB Garamond and Caveat fonts bundled (OFL).
- Options and Map pages redesigned for the book.
- Saved variables renamed (`SkaldDB`, `SkaldCharDB`); the first run with the new name starts from the files copied from the old addon.

## Before the rename (internal builds, as Chronicler)

- Quest rarity (grey to orange) from the reward, chain and story; curated stories for a few legendary quests; detail levels (few, normal, all).
- Quest type (fight, gather, explore, seek, delivery) chooses the wording of the page.
- Creatures slain read from the game's Statistics panel, with an estimate as fallback.
- One diary per character (tracked by character GUID), archive of old diaries with restore.
- Day summary pages, export for Discord and plain text, profession and event icons.
- Map companion (now Skald Atlas): pins on the world map by rarity, with filters.
