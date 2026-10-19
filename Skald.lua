-- Skald
-- Automatically writes an epic chronicle of your journey.
-- Logs: first visit to a zone, quest turned in, level up, death.

local ADDON_NAME, ns = ...

-- Constants live in one table: the main chunk of a Lua file may hold only 200 locals.
local K = {}

local MAX_ENTRIES = 3000

-- Localization: texts live in Locales.lua.
local LOCALES = ns.LOCALES

local L = LOCALES[GetLocale()] or LOCALES.enUS
local PHRASES = L.phrases
local TITLE = "Skald"

-- Parchment palette (dark inks that read well on paper).
K.HEAD_INK = { 0.45, 0.38, 0.26 }

K.INK = {
    header = { 0.35, 0.27, 0.15 },
    zone   = { 0.10, 0.28, 0.35 },
    quest  = { 0.15, 0.32, 0.12 },
    level  = { 0.45, 0.30, 0.00 },
    death  = { 0.50, 0.08, 0.08 },
    guild  = { 0.38, 0.18, 0.45 },
    guildleave = { 0.38, 0.30, 0.22 },
    day         = { 0.35, 0.25, 0.12 },
    milestone   = { 0.60, 0.35, 0.00 },
    party       = { 0.12, 0.35, 0.30 },
    reunion     = { 0.12, 0.35, 0.30 },
    dungeon     = { 0.30, 0.15, 0.40 },
    boss        = { 0.55, 0.05, 0.20 },
    mount       = { 0.30, 0.25, 0.10 },
    achievement = { 0.65, 0.40, 0.00 },
    skill       = { 0.25, 0.28, 0.30 },
    profession  = { 0.25, 0.28, 0.30 },
}

-- Ink of a quest page by rarity (dark enough to read on parchment).
K.TIER_INK = {
    [0] = { 0.40, 0.40, 0.40 },
    [1] = { 0.15, 0.32, 0.12 },
    [2] = { 0.05, 0.40, 0.08 },
    [3] = { 0.00, 0.22, 0.65 },
    [4] = { 0.42, 0.08, 0.58 },
    [5] = { 0.72, 0.30, 0.00 },
}

-- State ----------------------------------------------------------------------

local DB_VERSION = 3
local lastZone = nil
local pendingQuestTitle = nil
local pendingNPC, pendingQuestLevel = nil, nil
local pendingObjectiveTypes = nil
local loginTime = nil
local window = nil

local function Settings() return SkaldDB end
local function Journal() return SkaldCharDB end

local function Say(msg)
    print("|cffffd100" .. TITLE .. "|r: " .. msg)
end

-- Event payloads can be withheld ("secret") by the client; skip those.
local function Safe(v)
    if v == nil then return nil end
    if _G.issecretvalue and issecretvalue(v) then return nil end
    return v
end

local RollDay, BumpDay   -- the per-day counters; defined after AddEntry below

-- Counts an event without writing a page (quests below the detail threshold).
local function CountOnly(kind, tier)
    local db = Journal()
    if not db then return end
    RollDay()
    BumpDay(kind)
    local stats = db.stats
    stats.counts[kind] = (stats.counts[kind] or 0) + 1
    if kind == "quest" and tier then
        stats.tiers = stats.tiers or {}
        stats.tiers[tier] = (stats.tiers[tier] or 0) + 1
    end
end

-- Map position (mapID + 0..1 coordinates) so other addons can pin the page.
-- Returns nothing where the client withholds it (instances, loading screens).
local function GetPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local ok, mapID, x, y = pcall(function()
        local m = C_Map.GetBestMapForUnit("player")
        if not m then return end
        local pos = C_Map.GetPlayerMapPosition(m, "player")
        if not pos then return end
        local px, py = pos:GetXY()
        return m, px, py
    end)
    if ok and mapID and type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        -- four decimals are plenty for a pin on a map, and keep the saved file small
        return mapID, math.floor(x * 10000 + 0.5) / 10000, math.floor(y * 10000 + 0.5) / 10000
    end
end

local PoolFor   -- defined with the rendering code below
local Notify, PulseMinimap   -- the toast and the glow of the minimap button (defined further down)

-- Who is writing, and how it went, flavour some pages: a class's own words, a race's, a quest that
-- was hard or easy for your level. The pool chosen is stored with the page, so it reads the same later.
K.FLAVOR_KINDS = { quest = true, level = true, death = true, boss = true, zone = true, dungeon = true }
local AddContext
do
local CONTEXT_KINDS = { dungeon = true, boss = true, death = true, zone = true, level = true }
local WITH_KINDS = { dungeon = true, boss = true, death = true }
-- What surrounded the moment: the hour of the game, the names in the group, the pet.
AddContext = function(kind, entry)
    if not CONTEXT_KINDS[kind] then return end
    local okTime, hour = pcall(GetGameTime)
    if okTime and type(hour) == "number" then entry.hr = hour end
    if WITH_KINDS[kind] then
        local names = {}
        if IsInGroup and IsInGroup() then
            for i = 1, 4 do
                local who = (not UnitExists or UnitExists("party" .. i)) and Safe(UnitName and UnitName("party" .. i)) or nil
                if type(who) == "string" and who ~= "" then names[#names + 1] = who end
            end
        end
        if #names > 0 then entry.with = names end
        local pet = Safe(UnitName and UnitExists and UnitExists("pet") and UnitName("pet"))
        if type(pet) == "string" and pet ~= "" then entry.pet = pet end
    end
end
end
-- Who stood beside me in a dungeon or at a boss, so that meeting them again can be told (Options: remember companions).
K.COMPANIONS_MAX = 200
local function NoteCompanions(entry)
    local db = Journal()
    if not db or Settings().companions == false or type(entry.with) ~= "table" then return end
    db.companions = db.companions or {}
    for _, name in ipairs(entry.with) do
        local c = db.companions[name] or { first = entry.t }
        c.last, c.seen, c.shared = entry.t, entry.t, true
        c.pz, c.pn = entry.zm, entry.zone
        db.companions[name] = c
    end
    local n = 0
    for _ in pairs(db.companions) do n = n + 1 end
    if n > K.COMPANIONS_MAX + 20 then
        local list = {}
        for name, c in pairs(db.companions) do list[#list + 1] = { name, c.seen or c.last or 0 } end
        table.sort(list, function(a, b) return a[2] < b[2] end)
        for i = 1, n - K.COMPANIONS_MAX do db.companions[list[i][1]] = nil end
    end
end

local function PickFlavor(kind, entry)
    if kind == "boss" and entry.tries then return nil end
    if kind == "quest" and (entry.cend or (entry.tier or 1) >= 4 or (ns.CURATED and entry.q and ns.CURATED[entry.q])) then
        return nil
    end
    local tone = SkaldDB and SkaldDB.tone
    if tone and tone ~= "epic" and PHRASES["tone_" .. tone .. "_" .. kind] and math.random() < 0.75 then
        return "tone_" .. tone .. "_" .. kind
    end
    local keys = {}
    local function Offer(name) if PHRASES[name] then keys[#keys + 1] = name end end
    if entry.cls then Offer("class_" .. entry.cls .. "_" .. kind) end
    if entry.race then Offer("race_" .. entry.race .. "_" .. kind) end
    if kind == "quest" then
        if entry.cend or (entry.tier or 1) >= 4 or (ns.CURATED and entry.q and ns.CURATED[entry.q]) then return nil end
        if entry.ql and entry.pl then
            if entry.ql >= entry.pl + 3 then Offer("questHard")
            elseif entry.ql <= entry.pl - 6 then Offer("questEasy") end
        end
    end
    if #keys == 0 or math.random() > 0.4 then return nil end
    return keys[math.random(#keys)]
end

K.CRAFT_MERGE = 1200   -- seconds: making the same thing again within this time adds to the page of the last one
K.QUEST_START_MAX, K.QUEST_START_DAYS = 300, 60   -- quests whose acceptance is kept, and for how long
K.FALLS_FORGOTTEN = 7200   -- seconds after the last fall in a dungeon, when it no longer counts for a boss

-- Which pages the diary writes at all (Options: What the quill records).
K.RECORD_FLAG = {
    quest = "quest", level = "level", milestone = "level", death = "death",
    boss = "boss", dungeon = "boss", zone = "zone", skill = "profession", profession = "profession",
    loot = "loot", mark = "mark", home = "mark", rep = "mark", flight = "zone", tame = "mark", revive = "death", hearth = "mark",
}

-- Entries store the event type, its argument and which phrase was drawn;
-- the text is rendered when the window is shown.
local function AddEntry(kind, arg, zone, extra)
    local db = Journal()
    if not db then return end
    if not PHRASES[kind] then return end
    local flag = K.RECORD_FLAG[kind]
    if flag and (Settings().rec or {})[flag] == false then return end
    -- A new calendar day closes the one before it (with a summary page) first.
    if kind ~= "day" then RollDay() end
    local where = zone or GetZoneText() or "?"
    local m, x, y
    if kind ~= "day" then m, x, y = GetPosition() end

    local entry = {
        t = time(),
        zone = where,
        kind = kind,
        arg = arg,
        idx = 1,
        ses = loginTime,
        m = m, x = x, y = y,
    }
    -- The map of the place (an id, whatever the client's language), even for pages not pinned on the map.
    if kind ~= "day" and C_Map and C_Map.GetBestMapForUnit then
        local okMap, zm = pcall(C_Map.GetBestMapForUnit, "player")
        if okMap and type(zm) == "number" then entry.zm = zm end
    end
    -- Optional extras: a quest's rarity (tier), id (q), type (qtype) and giver (npc).
    if extra then
        for k, v in pairs(extra) do entry[k] = v end
    end

    -- Draw from the pool this page will be told with, never the phrase used
    -- last time for the same kind and type.
    AddContext(kind, entry)
    if kind == "dungeon" or kind == "boss" then NoteCompanions(entry) end
    if K.FLAVOR_KINDS[kind] then
        local okClass, _, classFile = pcall(UnitClass, "player")
        local okRace, _, raceFile = pcall(UnitRace, "player")
        entry.cls = okClass and type(classFile) == "string" and classFile or nil
        entry.race = okRace and type(raceFile) == "string" and raceFile or nil
        entry.fl = PickFlavor(kind, entry)
    end
    local list = PoolFor(entry) or PHRASES[kind]
    -- Not one of the last few phrases told of this kind (as many as the pool allows, up to five).
    db.recentIdx = db.recentIdx or {}
    local key = table.concat({ kind, tostring(entry.qtype or entry.cat or ""), tostring(entry.src or ""),
        tostring(entry.tier or ""), tostring(entry.fl or ""), tostring(entry.tries and math.min(entry.tries, 4) or (entry.since and (entry.since >= 2 and "d" or "y")) or "") }, ":")
    local recent = db.recentIdx[key] or {}
    local keep = math.min(5, #list - 1)
    local idx = math.random(#list)
    for _ = 1, 30 do
        local seen = false
        for i = math.max(1, #recent - keep + 1), #recent do
            if recent[i] == idx then seen = true; break end
        end
        if not seen then break end
        idx = math.random(#list)
    end
    recent[#recent + 1] = idx
    while #recent > 5 do table.remove(recent, 1) end
    db.recentIdx[key] = recent
    entry.idx = idx

    table.insert(db.entries, entry)
    while #db.entries > MAX_ENTRIES do
        table.remove(db.entries, 1)
    end

    -- Lifetime counters survive the entry cap.
    local stats = db.stats
    stats.counts[kind] = (stats.counts[kind] or 0) + 1
    if kind == "quest" and type(entry.tier) == "number" then
        stats.tiers = stats.tiers or {}
        stats.tiers[entry.tier] = (stats.tiers[entry.tier] or 0) + 1
    end
    if kind == "death" then
        stats.deathZones[where] = (stats.deathZones[where] or 0) + 1
    end
    stats.first = stats.first or db.entries[1].t
    if kind ~= "day" then BumpDay(kind, where) end

    if Notify then Notify(entry) end
    if window and window:IsShown() then
        window:Refresh()
    end
end

-- Creatures slain, read from the game's own Statistics panel (Kills > Creatures), which
-- counts exactly and from the character's first day. The statistic is found once by its
-- name among the Statistics categories and its id remembered. Where the name is not known
-- (other languages) this gives nothing, and the estimate from XP is used instead.
K.KILL_STAT_NAMES = { ["creatures killed"] = true, ["criaturas abatidas"] = true,
    ["créatures tuées"] = true, ["creatures tuees"] = true }
local killStatId, killStatSearched

local function FindKillStatistic()
    if killStatId or killStatSearched then return killStatId end
    killStatSearched = true
    if not (GetStatistic and GetStatisticsCategoryList and GetCategoryNumAchievements and GetAchievementInfo) then
        return nil
    end
    local saved = SkaldDB and SkaldDB.killStatId
    if saved and pcall(GetStatistic, saved) then
        killStatId = saved
        return killStatId
    end
    pcall(function()
        for _, category in ipairs(GetStatisticsCategoryList()) do
            for i = 1, (GetCategoryNumAchievements(category) or 0) do
                local id, name = GetAchievementInfo(category, i)
                if id and type(name) == "string" and K.KILL_STAT_NAMES[name:lower()] then
                    killStatId = id
                    if SkaldDB then SkaldDB.killStatId = id end
                    return
                end
            end
        end
    end)
    return killStatId
end

-- The statistic's value as a number ("1.234" and "1,234" alike), or nil when unknown or "--".
local function KillStat()
    local id = FindKillStatistic()
    if not id then return nil end
    local ok, text = pcall(GetStatistic, id)
    if not ok or type(text) ~= "string" then return nil end
    local digits = text:gsub("%D", "")
    if digits == "" then return nil end
    return tonumber(digits)
end

-- A statistic of the game as a number: its value, 0 when the panel shows "--" (never happened),
-- nil when the statistic cannot be read at all.
K.STAT_QUESTS, K.STAT_DEATHS, K.STAT_DUNGEONS, K.CATEGORY_BOSS_WINS = 98, 60, 932, 14821
local function GameStat(id)
    if not GetStatistic then return nil end
    local ok, text = pcall(GetStatistic, id)
    if not ok or type(text) ~= "string" then return nil end
    local digits = text:gsub("%D", "")
    return tonumber(digits) or 0
end

-- The statistic exactly as the game prints it (money with its coin icons, "283 (Humanoide)"), or nil.
local function StatText(id)
    if not GetStatistic then return nil end
    local ok, text = pcall(GetStatistic, id)
    if not ok or type(text) ~= "string" or text == "" or text == "--" then return nil end
    return text
end

-- Bosses: the victories over every boss, summed over the statistics of the dungeon category.
local function BossWins()
    if not (GetCategoryNumAchievements and GetAchievementInfo) then return nil end
    local ok, total = pcall(function()
        local sum, count = 0, GetCategoryNumAchievements(K.CATEGORY_BOSS_WINS) or 0
        if count == 0 then return nil end
        for i = 1, count do
            local id = GetAchievementInfo(K.CATEGORY_BOSS_WINS, i)
            sum = sum + (id and GameStat(id) or 0)
        end
        return sum
    end)
    return ok and total or nil
end

-- Per-day counters, so a day can be closed with a page of its own. A day is closed the
-- first time anything is written on a later date (or at the next login), and only if it
-- held enough: three events, or twenty minutes on the road.
K.DAY_FIELD = {
    quest = "q", level = "l", milestone = "l", death = "d", zone = "z", kill = "k",
    dungeon = "u", boss = "b", achievement = "a",
}
local sessionMark = nil   -- when the time on the road was last added to a day

local function DayKey(t) return date("%Y-%m-%d", t or time()) end
local function NewDay() return { q = 0, l = 0, d = 0, z = 0, u = 0, b = 0, a = 0, k = 0, s = 0 } end

-- Adds the time since the last mark to the day it began on.
local function BankPlayed()
    local db = Journal()
    if not db or not sessionMark then return end
    local now = time()
    db.days = db.days or {}
    local key = DayKey(sessionMark)
    db.days[key] = db.days[key] or NewDay()
    db.days[key].s = (db.days[key].s or 0) + math.max(0, now - sessionMark)
    sessionMark = now
end

local function CloseDay(key)
    local db = Journal()
    local d = db.days and db.days[key]
    if not d or d.done then return end
    d.done = true
    if Settings().closing == false then return end
    local activity = d.q + d.l + d.d + d.z + d.u + d.b + d.a
    if activity >= 3 or (d.s or 0) >= 1200 then
        -- Creatures: the game's own count over the day when it was read at both ends,
        -- the estimate from XP otherwise.
        local kills = d.k or 0
        if d.k0 and d.kEnd and d.kEnd >= d.k0 then kills = d.kEnd - d.k0 end
        AddEntry("day", key, d.zone or "?", {
            t = d.last or time(), m = false, x = false, y = false,
            day = { q = d.q, l = d.l, d = d.d, z = d.z, u = d.u, b = d.b, a = d.a, k = kills, s = d.s or 0 },
        })
    end
end

RollDay = function()
    local db = Journal()
    if not db then return end
    db.days = db.days or {}
    local today = DayKey()
    if db.today ~= today then
        -- Where the game's creature count stood as the old day ended.
        local previous = db.today and db.days[db.today]
        if previous and previous.kEnd == nil then previous.kEnd = KillStat() or false end
        db.today = today
        BankPlayed()
        local pending = {}
        for key, d in pairs(db.days) do
            if key < today and not d.done then pending[#pending + 1] = key end
        end
        table.sort(pending)
        for _, key in ipairs(pending) do CloseDay(key) end
        -- Forget the days long gone.
        local keys = {}
        for key in pairs(db.days) do keys[#keys + 1] = key end
        table.sort(keys)
        while #keys > 45 do db.days[table.remove(keys, 1)] = nil end
    end
    db.days[today] = db.days[today] or NewDay()
    -- Where the game's creature count stood as this day began.
    if db.days[today].k0 == nil then db.days[today].k0 = KillStat() or false end
end

BumpDay = function(kind, where)
    local db = Journal()
    if not db or not db.days then return end
    local d = db.days[db.today or DayKey()]
    if not d then return end
    local field = K.DAY_FIELD[kind]
    if field then d[field] = (d[field] or 0) + 1 end
    d.last = time()
    if where then d.zone = where end
end

-- What a quest asks of you decides how it is told: a letter carried across town
-- is not a battle. Types: fight, gather, explore, delivery.
K.FIGHT_VERBS = {
    kill = true, slay = true, defeat = true, destroy = true, eliminate = true, attack = true,
    clear = true, exterminate = true, hunt = true, drive = true, battle = true, fight = true,
    rid = true, purge = true, cull = true, protect = true, escort = true, defend = true,
    dispatch = true, rescue = true,
}
K.EXPLORE_VERBS = {
    explore = true, discover = true, scout = true, investigate = true,
    travel = true, go = true, journey = true, venture = true, survey = true, reach = true,
}
-- Looking for a person or a thing: told as a search, not as exploring.
K.SEEK_VERBS = { find = true, search = true, locate = true, look = true, seek = true }
local function FirstVerb(sentence)
    if type(sentence) ~= "string" then return nil end
    return sentence:lower():gsub("^[^%a]+", ""):match("^(%a+)")
end

local function QuestTypeFromDB(questID)
    local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
    if not (qdb and questID) then return nil end
    local ok, q = pcall(qdb.GetQuest, qdb, questID)
    if not ok or type(q) ~= "table" or type(q.objectives) ~= "table" then return nil end

    local function count(t) return type(t) == "table" and #t or 0 end
    -- Forever's own quests carry only a title and a level: nothing to judge by.
    local people = count(q.startedBy and q.startedBy.npcs) + count(q.finishedBy and q.finishedBy.npcs)
        + count(q.startedBy and q.startedBy.objects) + count(q.finishedBy and q.finishedBy.objects)
        + count(q.startedBy and q.startedBy.items)
    local o = q.objectives
    local kind
    if count(o.npcs) > 0 then kind = "fight"
    elseif count(o.items) > 0 or count(o.objects) > 0 then kind = "gather"
    elseif count(o.explore) > 0 or count(o.spells) > 0 then kind = "explore"
    elseif people == 0 then return nil
    else kind = "delivery" end

    -- The structure can mislead: an escort or a boss has no list of monsters, and a bounty
    -- lists only the item it drops. The first verb of the objectives sentence settles it.
    if kind ~= "fight" and type(qdb.GetQuestText) == "function" then
        local okText, t = pcall(qdb.GetQuestText, qdb, questID)
        local sentence = okText and type(t) == "table" and t.objectives
        local verb = FirstVerb(sentence)
        if verb then
            if K.FIGHT_VERBS[verb] then
                return "fight"
            elseif kind == "delivery" then
                local s = sentence:lower()
                local hands = s:find("deliver", 1, true) or s:find("give", 1, true)
                    or s:find("bring", 1, true) or s:find("take it to", 1, true)
                -- A trip to talk to someone is an errand, not exploring.
                local talks = s:find("speak", 1, true) or s:find("talk", 1, true)
                    or s:find("contact", 1, true)
                if K.EXPLORE_VERBS[verb] and not hands and not talks then
                    return "explore"
                elseif K.SEEK_VERBS[verb] and not hands and not talks then
                    return "seek"
                end
            end
        end
    end
    return kind
end

-- The same judgement from the objectives the client lists while the quest is
-- in the log (types such as "monster", "item", "object", "event").
local function QuestTypeFromObjectives(types)
    if type(types) ~= "table" then return nil end
    if #types == 0 then return "delivery" end
    local fight, gather
    for _, t in ipairs(types) do
        if t == "monster" or t == "player" then fight = true
        elseif t == "item" or t == "object" then gather = true end
    end
    return (fight and "fight") or (gather and "gather") or "explore"
end

local function Concat(a, b)
    local out = {}
    for _, v in ipairs(a or {}) do out[#out + 1] = v end
    for _, v in ipairs(b or {}) do out[#out + 1] = v end
    return out
end

local lootJoined   -- general loot lines joined with those of a weapon type or an armour material

-- Which phrase pool a page draws from: by quest type and by rarity.
function PoolFor(e)
    if e.fl and PHRASES[e.fl] then return PHRASES[e.fl] end
    -- Learning a profession has lines of its own for each of the twelve.
    if e.kind == "profession" then
        local key = e.pf or (SkaldAPI.ProfessionKey and SkaldAPI.ProfessionKey(nil, e.arg))
        local own = key and PHRASES["profession_" .. key]
        if own then return own end
    end
    if e.kind == "mark" then return PHRASES["mark_" .. (e.mk or "")] or PHRASES.mark end
    -- A hunter's pet: the first one has lines of its own, and so has the day it grows to the hunter's level.
    -- Back from the dead: at the spirit healer, or on the way back to one's own body.
    if e.kind == "revive" then
        if e.sub == "healer" and PHRASES.reviveHealer then return PHRASES.reviveHealer end
        return PHRASES.revive
    end
    if e.kind == "tame" then
        if e.sub == "first" and PHRASES.tameFirst then return PHRASES.tameFirst end
        if e.sub == "level" and PHRASES.tameLevel then return PHRASES.tameLevel end
        return PHRASES.tame
    end
    if e.kind == "loot" then
        if e.src == "craft" and (e.n or 1) >= 2 and PHRASES.lootCraftMany then return PHRASES.lootCraftMany end
        if (e.tier or 0) >= 4 and PHRASES.lootEpic then return PHRASES.lootEpic end
        if e.src == "craft" and PHRASES.lootCraft then return PHRASES.lootCraft end
        if e.src == "gift" and PHRASES.lootGift then return PHRASES.lootGift end
        local names = {
            weapon = "lootWeapon", sword = "lootWeapon", greatsword = "lootWeapon", axe = "lootWeapon", mace = "lootWeapon", staff = "lootWeapon",
            bow = "lootWeapon", gun = "lootWeapon", crossbow = "lootWeapon", wand = "lootWeapon", dagger = "lootWeapon",
            fist = "lootWeapon", polearm = "lootWeapon", thrown = "lootWeapon", warglaive = "lootWeapon",
            armor = "lootArmor", helm = "lootArmor", shoulder = "lootArmor", hands = "lootArmor", legs = "lootArmor",
            feet = "lootArmor", waist = "lootArmor", wrist = "lootArmor", shield = "lootArmor",
            jewel = "lootJewel", ring = "lootJewel", amulet = "lootJewel", trinket = "lootJewel", relic = "lootJewel",
            cloak = "lootCloak", bag = "lootBag", recipe = "lootRecipe",
        }
        local base = PHRASES[names[e.cat or ""] or "loot"] or PHRASES.loot
        local specific = {
            sword = "lootSword", greatsword = "lootSword", axe = "lootAxe", mace = "lootMace", staff = "lootStaff",
            polearm = "lootStaff", bow = "lootRanged", crossbow = "lootRanged", gun = "lootRanged", thrown = "lootRanged",
            dagger = "lootDagger", fist = "lootDagger", wand = "lootWand",
        }
        local material = { [1] = "lootCloth", [2] = "lootLeather", [3] = "lootMail", [4] = "lootPlate" }
        local armourCats = { armor = true, helm = true, shoulder = true, hands = true, legs = true, feet = true,
            waist = true, wrist = true }
        local extraName = specific[e.cat or ""] or (armourCats[e.cat or ""] and material[e.mat or 0])
        local extra = extraName and PHRASES[extraName]
        if extra then
            lootJoined = lootJoined or {}
            lootJoined[extra] = lootJoined[extra] or Concat(base, extra)
            return lootJoined[extra]
        end
        return base
    end
    if e.kind == "boss" and e.tries and e.tries >= 1 then
        local key = (e.tries >= 4 and "bossHardMany") or (e.tries >= 2 and "bossHard") or "bossHardOne"
        if PHRASES[key] then return PHRASES[key] end
    end
    if e.kind ~= "quest" then return PHRASES[e.kind] end
    local tier = e.tier or 1
    local notable = tier >= 3

    -- A chain that took days to finish says so (the day the first quest was accepted comes from the diary).
    if e.cend and e.cend >= 2 and e.since and e.since >= 1 then
        if e.since == 1 and PHRASES.questChainYesterday then return PHRASES.questChainYesterday end
        if e.since >= 2 and PHRASES.questChainDays then
            if e.cend >= 6 and notable and PHRASES.questChain then
                PHRASES.questChainAll = PHRASES.questChainAll or Concat(PHRASES.questChain, PHRASES.questChainDays)
                return PHRASES.questChainAll
            end
            return PHRASES.questChainDays
        end
    end

    -- The last quest of a long chain is told as the end of a journey, whatever it asked.
    if e.cend and e.cend >= 6 and notable and PHRASES.questChain then
        return PHRASES.questChain
    end

    -- Pages written before types existed are typed from QuestDB when possible.
    if e.qtype == nil and e.q then e.qtype = QuestTypeFromDB(e.q) or false end
    local qt = e.qtype or nil

    if qt == "delivery" then
        return (notable and PHRASES.questDeliveryNotable) or PHRASES.questDelivery or PHRASES.quest
    elseif qt == "gather" then
        return (notable and PHRASES.questGatherNotable) or PHRASES.questGather or PHRASES.quest
    elseif qt == "explore" then
        return (notable and PHRASES.questExploreNotable) or PHRASES.questExplore or PHRASES.quest
    elseif qt == "seek" then
        return (notable and PHRASES.questSeekNotable) or PHRASES.questSeek or PHRASES.quest
    end

    -- Fights and quests of unknown type: the rarer the grander.
    if tier >= 4 and PHRASES.questEpic then return PHRASES.questEpic end
    if tier == 3 and PHRASES.questRare then return PHRASES.questRare end
    if qt == "fight" and PHRASES.questFight then
        PHRASES.questFightAll = PHRASES.questFightAll or Concat(PHRASES.quest, PHRASES.questFight)
        return PHRASES.questFightAll
    end
    return PHRASES.quest
end

-- The text of a day's closing page: what the day held, then a line fitting how it went.
local function DayText(e)
    local d = e.day
    local items = {
        { "quests", d.q }, { "kills", d.k }, { "levels", d.l }, { "zones", d.z }, { "dungeons", d.u },
        { "bosses", d.b }, { "achievements", d.a }, { "deaths", d.d },
    }
    local parts = {}
    for _, item in ipairs(items) do
        local words, n = L.DAY_PARTS[item[1]], item[2]
        if words and n and n > 0 then
            parts[#parts + 1] = string.format(n == 1 and words[1] or words[2], n)
        end
    end

    local intros = PHRASES.day
    local text = intros[((e.idx or 1) - 1) % #intros + 1]
    if #parts > 0 then
        local joined = parts[1]
        if #parts > 1 then
            joined = table.concat(parts, ", ", 1, #parts - 1) .. L.DAY_AND .. parts[#parts]
        end
        text = text .. " " .. string.format(L.DAY_LEAD, joined)
    end
    local seconds = d.s or 0
    if seconds >= 60 then
        text = text .. " " .. string.format(L.DAY_TIME,
            string.format(L.DURATION, math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)))
    end

    local activity = (d.q or 0) + (d.l or 0) + (d.d or 0) + (d.z or 0) + (d.u or 0) + (d.b or 0) + (d.a or 0)
    local mood = ((d.d or 0) >= 3 and "deadly") or ((d.l or 0) > 0 and "levels")
        or (activity >= 12 and "busy") or (activity <= 3 and "quiet") or "plain"
    return text .. " " .. L.DAY_CLOSE[mood]
end

K.QUALITY_COLOR = {
    [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80",
    [7] = "00ccff", [8] = "00ccff",
}
K.QUALITY_BY_COLOR = {}
for q, hex in pairs(K.QUALITY_COLOR) do K.QUALITY_BY_COLOR[hex] = K.QUALITY_BY_COLOR[hex] or q end

-- The pieces of an item link: its reference (item:...), its name and its quality (0 grey .. 5 orange).
local function ItemParts(text)
    if type(text) ~= "string" then return nil end
    local ref, name = text:match("|H(item:[^|]*)|h%[(.-)%]|h")
    if not ref then return nil end
    local quality = tonumber(text:match("|cnIQ(%d+):"))
    if not quality then
        local color = text:match("|cff(%x%x%x%x%x%x)")
        quality = color and K.QUALITY_BY_COLOR[color:lower()]
    end
    if not quality then
        local id = tonumber(ref:match("item:(%d+)"))
        local byId = C_Item and C_Item.GetItemQualityByID
        if id and byId then
            local ok, value = pcall(byId, id)
            if ok and type(value) == "number" then quality = value end
        end
    end
    return ref, name, quality or 1
end

K.ITEM_INK = {
    [0] = { 0.42, 0.42, 0.40 }, [1] = { 0.24, 0.16, 0.09 }, [2] = { 0.05, 0.40, 0.08 },
    [3] = { 0.00, 0.25, 0.70 }, [4] = { 0.45, 0.10, 0.62 }, [5] = { 0.75, 0.32, 0.00 },
}
local function ColoredItem(ref, name, quality)
    local c = K.ITEM_INK[quality] or K.ITEM_INK[5]
    local hex = string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    return "|cff" .. hex .. "|H" .. ref .. "|h[" .. name .. "]|h|r"
end

-- What surrounded the moment, told after the page: who was there, the light, the pet.
local Extras
do
local function PartOfDay(hour)
    if hour >= 5 and hour <= 7 then return "dawn" end
    if hour >= 8 and hour <= 11 then return "morning" end
    if hour >= 12 and hour <= 16 then return "afternoon" end
    if hour >= 17 and hour <= 19 then return "dusk" end
    return "night"
end
Extras = function(e)
    local out = ""
    local idx = e.idx or 1
    if type(e.with) == "table" and #e.with > 0 then
        local names = e.with
        local joined = names[1]
        if #names > 1 then joined = table.concat(names, ", ", 1, #names - 1) .. L.DAY_AND .. names[#names] end
        out = out .. " " .. string.format(L.WITH, joined)
    end
    if type(e.hr) == "number" and idx % 2 == 1 and L.AMBIENT then
        local list = L.AMBIENT[PartOfDay(e.hr)]
        if list then out = out .. " " .. list[idx % #list + 1] end
    end
    if e.kind == "tame" and L.PET_FAMILY then
        -- the family as the record of the pet has it now (it is read again in the client's language)
        local db = Journal()
        local rec = db and db.pets and db.pets[tostring(e.arg or "")]
        local fam = (rec and rec.fam) or e.fam
        if type(fam) == "string" and fam ~= "" and tostring(e.arg or ""):lower() ~= fam:lower() then
            local forms = L.PET_FAMILY_FORMS
            local form = forms and forms[((e.idx or 1) - 1) % #forms + 1] or L.PET_FAMILY
            out = out .. " " .. string.format(form, fam)
        end
    end
    if type(e.pet) == "string" and idx % 3 == 1 and L.PET then
        out = out .. " " .. string.format(L.PET[idx % #L.PET + 1], e.pet)
    end
    return out
end
end

-- The name of a place is read from its map id each time it is shown, in the client's language;
-- the name saved on the page is only the fallback (maps the client cannot name, dungeons).
do
local names = {}
ns.ZoneNameOfMap = function(mapID)
    if names[mapID] ~= nil then return names[mapID] or nil end
    local name = false
    pcall(function()
        if not (C_Map and C_Map.GetMapInfo) then return end
        local info = C_Map.GetMapInfo(mapID)
        if not info or info.mapType == 4 then return end   -- not inside a dungeon
        for _ = 1, 8 do
            if info.mapType and info.mapType <= 3 then break end
            if not info.parentMapID or info.parentMapID == 0 then return end
            info = C_Map.GetMapInfo(info.parentMapID)
            if not info then return end
        end
        if info.mapType == 3 and type(info.name) == "string" and info.name ~= "" then name = info.name end
    end)
    names[mapID] = name
    return name or nil
end
ns.PlaceNameById = function(id)
    return id and ns.ZoneNameOfMap(id) or nil
end
ns.PlaceName = function(e)
    if e.kind == "dungeon" or e.kind == "day" then return e.zone end
    local id = (e.zone == "" and e.zm) or (type(e.m) == "number" and e.m) or e.zm
    return (id and ns.ZoneNameOfMap(id)) or e.zone
end
end

local function RenderEntry(e)
    if e.kind == "day" and e.day then return DayText(e) end
    if e.kind == "note" then return tostring(e.arg or "") end
    local npc = e.npc or L.UNKNOWN_NPC

    -- A hand-picked quest tells its own story.
    if e.kind == "quest" and e.q and ns.CURATED then
        local curated = ns.CURATED[e.q]
        local text = curated and curated.text and (curated.text[GetLocale()] or curated.text.enUS)
        if text then
            text = text:gsub("{quest}", function() return tostring(e.arg) end)
            return (text:gsub("{npc}", function() return npc end))
        end
    end

    local list = PoolFor(e)
    if not list then return "" end
    local shown = tostring(e.arg)
    if (e.kind == "zone" or e.kind == "death" or e.kind == "revive") and e.arg == e.zone then shown = tostring(ns.PlaceName(e) or e.arg) end
    if e.kind == "loot" then
        local ref, name, quality = ItemParts(e.arg)
        if ref then
            local id = e.iid or tonumber(ref:match("item:(%d+)"))
            local live
            if id then
                pcall(function()
                    if C_Item and C_Item.GetItemNameByID then live = C_Item.GetItemNameByID(id) end
                    if not live and GetItemInfo then live = GetItemInfo(id) end
                end)
            end
            if type(live) ~= "string" or live == "" then live = nil end
            shown = ColoredItem(ref, live or name, quality)
        end
    end
    local text = string.format(list[((e.idx or 1) - 1) % #list + 1], shown)
    text = text:gsub("{steps}", function() return tostring(e.cend or "") end)
    text = text:gsub("{tries}", function() return tostring(e.tries or "") end)
    text = text:gsub("{days}", function() return tostring(e.since or "") end)
    text = text:gsub("{count}", function() return tostring(e.n or "") end)
    text = text:gsub("{place}", function()
        return tostring((e.pz and ns.ZoneNameOfMap and ns.ZoneNameOfMap(e.pz)) or e.pn or L.UNKNOWN_ZONE)
    end)
    text = text:gsub("{standing}", function() return tostring(e.st or "") end)
    text = text:gsub("{npc}", function() return npc end)
    return text .. (e.noExtras and "" or Extras(e))
end

-- Hooks for companion addons (e.g. Wayfarer): read the pages, and add a tab to the window.
local pendingTabs = {}
SkaldAPI = {
    GetEntries = function() return Journal() and Journal().entries or {} end,
    Render = RenderEntry,
    DateFormat = L.DATE_FMT,
    DayFormat = L.DAY_DATE,
    TierName = function(tier) return L.TIERS[tier] end,
    -- "fight", "gather", "explore" or "delivery" for a quest id (nil without QuestDB data).
    QuestType = QuestTypeFromDB,
    PoolFor = PoolFor,   -- which phrase list a page draws from (diagnostics)
    -- AddTab(id, label, build): build(panel) fills the panel; return a function to refresh it.
    AddTab = function(id, label, build)
        if window then
            window:AddTab(id, label, build)
        else
            pendingTabs[#pendingTabs + 1] = { id, label, build }
        end
    end,
}

-- Fills in stats for characters that already had pages before counters existed.
local function MigrateStats(db)
    db.stats = db.stats or {}
    local s = db.stats
    s.counts = s.counts or {}
    s.deathZones = s.deathZones or {}
    s.played = s.played or 0
    -- Quests by rarity. Diaries written before this existed are counted from their pages
    -- (the trivial ones were never written, so those start at zero).
    if not s.tiers then
        s.tiers = {}
        for _, e in ipairs(db.entries) do
            if e.kind == "quest" and type(e.tier) == "number" then
                s.tiers[e.tier] = (s.tiers[e.tier] or 0) + 1
            end
        end
    end
    if (db.version or 1) < 2 then
        for _, e in ipairs(db.entries) do
            s.counts[e.kind] = (s.counts[e.kind] or 0) + 1
            if e.kind == "death" then
                s.deathZones[e.zone] = (s.deathZones[e.zone] or 0) + 1
            end
        end
        s.first = s.first or (db.entries[1] and db.entries[1].t)
    end
    -- Pages written before the larger phrase lists only hold an index into the
    -- old short ones; draw them again across the full lists, never the same
    -- phrase twice in a row for a kind.
    if (db.version or 1) < 3 then
        local last = {}
        for _, e in ipairs(db.entries) do
            local list = PHRASES[e.kind]
            if list then
                local idx = math.random(#list)
                if #list > 1 and idx == last[e.kind] then idx = idx % #list + 1 end
                e.idx = idx
                last[e.kind] = idx
            end
        end
        db.lastIdx = last
    end
    db.version = DB_VERSION
end

-- Empties the whole diary: pages, zones seen, counters, and what was remembered
-- about guild, group and professions, so everything is detected afresh.
local function ResetJournal(db)
    db.entries, db.visited, db.flags = {}, {}, {}
    db.days, db.today = nil, nil
    db.skills, db.skillsInit = nil, nil
    db.guild, db.guildSeen = nil, nil
    db.lastIdx = nil
    db.stats, db.version = nil, nil
    MigrateStats(db)
end

-- WoW keeps per-character data by NAME, so a character made again with a name that
-- was used before inherits the old diary. The GUID tells them apart. Diaries saved
-- before the GUID was recorded are told apart by level: a character cannot be lower
-- than the highest level its own diary already reached.
local function MaxRecordedLevel(db)
    local highest = 0
    for _, e in ipairs(db.entries) do
        if e.kind == "level" or e.kind == "milestone" then
            local n = tonumber(e.arg)
            if n and n > highest then highest = n end
        end
    end
    return highest
end

-- Returns true when the diary belonged to another character and was set aside.
local function EnsureOwnDiary()
    local db = Journal()
    if not db then return false end
    local guid = UnitGUID and UnitGUID("player")
    local different = false
    if db.guid and guid and db.guid ~= guid then
        different = true
    elseif not db.guid and #db.entries > 0 then
        local level = UnitLevel and UnitLevel("player")
        if level and level < MaxRecordedLevel(db) then different = true end
    end
    if different then
        -- Keep the old diary aside (the last three), then start a fresh one.
        db.previous = db.previous or {}
        table.insert(db.previous, { guid = db.guid, t = time(), entries = db.entries,
            visited = db.visited, stats = db.stats })
        while #db.previous > 3 do table.remove(db.previous, 1) end
        ResetJournal(db)
    end
    if guid then db.guid = guid end
    return different
end

-- Brings back the most recently archived diary. The diary in use goes to the archive in
-- its place, so nothing is lost either way. Returns true when something was restored.
local function RestoreLatestArchive()
    local db = Journal()
    local archive = db and db.previous
    if not archive or #archive == 0 then return false end
    local old = table.remove(archive)

    if #db.entries > 0 then
        table.insert(archive, { guid = db.guid, t = time(), entries = db.entries,
            visited = db.visited, stats = db.stats })
        while #archive > 3 do table.remove(archive, 1) end
    end

    db.entries = old.entries or {}
    db.visited = old.visited or {}
    db.stats = old.stats
    db.flags = {}
    db.days, db.today = nil, nil            -- the days of the restored diary are not kept
    db.skills, db.skillsInit = nil, nil     -- professions are looked at afresh, silently
    db.lastIdx = nil
    -- Guild is read again right now, so restoring does not write a "joined" page.
    db.guild = (GetGuildInfo and GetGuildInfo("player")) or false
    db.guildSeen = true
    db.version = DB_VERSION                  -- counters are already right: no recount
    MigrateStats(db)
    return true
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format(L.DURATION, math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- Spoken (optional) -----------------------------------------------------------
-- Spoken ships zone icons by mapID; borrow them when it is installed.

local function SpokenReady()
    return _G.Spoken and type(Spoken.IsCompatible) == "function" and Spoken:IsCompatible(1)
end

local iconCache = {}
local function ZoneIconTag(mapID)
    if not mapID or not SpokenReady() or not Spoken.ZoneIcon then return "" end
    local cached = iconCache[mapID]
    if cached == nil then
        local ok, path = pcall(Spoken.ZoneIcon, Spoken, mapID)
        cached = (ok and path) and string.format("|T%s:16:16|t ", path) or false
        iconCache[mapID] = cached
    end
    return cached or ""
end

-- Wax seal for a quest's rarity (Textures/seal0..seal5), drawn inline in the page header.
K.SEAL_PATH = "Interface\\AddOns\\Skald\\Textures\\seal"
-- Event icon for every page that is not a quest (Textures/ev_<name>.tga).
K.EVENT_ICON = {
    quest = "quest", level = "level", milestone = "milestone", death = "death", boss = "boss",
    dungeon = "dungeon", zone = "zone", mount = "mount", guild = "guild",
    guildleave = "guild", party = "party", achievement = "achievement",
    skill = "profession", profession = "profession",
    day = "milestone",   -- until a sun or moon icon of its own is drawn
    reunion = "party",
    mark = "milestone", home = "st_hearth", rep = "achievement", flight = "st_flight",
    tame = "pet",
    revive = "revive", hearth = "st_hearth",
}
-- Professions: the game's skill line id says which one it is whatever the language; the
-- name is the fallback (and how pages written before this existed are recognised).
K.PROFESSION_BY_LINE = {
    [171] = "alchemy", [164] = "blacksmithing", [333] = "enchanting", [202] = "engineering",
    [182] = "herbalism", [165] = "leatherworking", [186] = "mining", [393] = "skinning",
    [197] = "tailoring", [185] = "cooking", [129] = "firstaid", [356] = "fishing",
}
K.PROFESSION_BY_NAME = {
    -- enUS
    ["alchemy"] = "alchemy", ["blacksmithing"] = "blacksmithing", ["enchanting"] = "enchanting",
    ["engineering"] = "engineering", ["herbalism"] = "herbalism", ["leatherworking"] = "leatherworking",
    ["mining"] = "mining", ["skinning"] = "skinning", ["tailoring"] = "tailoring",
    ["cooking"] = "cooking", ["first aid"] = "firstaid", ["fishing"] = "fishing",
    -- ptBR
    ["alquimia"] = "alchemy", ["ferraria"] = "blacksmithing", ["encantamento"] = "enchanting",
    ["engenharia"] = "engineering", ["herborismo"] = "herbalism", ["couraria"] = "leatherworking",
    ["mineração"] = "mining", ["esfolamento"] = "skinning", ["alfaiataria"] = "tailoring",
    ["culinária"] = "cooking", ["primeiros socorros"] = "firstaid", ["pesca"] = "fishing",
    -- frFR
    ["alchimie"] = "alchemy", ["forge"] = "blacksmithing", ["enchantement"] = "enchanting",
    ["ingénierie"] = "engineering", ["herboristerie"] = "herbalism", ["travail du cuir"] = "leatherworking",
    ["minage"] = "mining", ["dépeçage"] = "skinning", ["couture"] = "tailoring",
    ["cuisine"] = "cooking", ["secourisme"] = "firstaid", ["pêche"] = "fishing",
}
local function ProfessionKey(skillLine, name)
    local key = skillLine and K.PROFESSION_BY_LINE[tonumber(skillLine)]
    if key then return key end
    if type(name) == "string" then
        -- A "skill" page carries "Name 150": drop the number.
        local bare = name:gsub("%s+%d+$", ""):lower()
        return K.PROFESSION_BY_NAME[bare]
    end
end

SkaldAPI.ProfessionKey = ProfessionKey

local function EventIconPath(kind, entry)
    local name = K.EVENT_ICON[kind]
    if not name then return nil end
    local file = (name:sub(1, 3) == "st_") and name or ("ev_" .. name)
    if kind == "profession" or kind == "skill" then
        local key = (entry and entry.pf) or (entry and ProfessionKey(nil, entry.arg))
        if key then file = "pf_" .. key end
    end
    return "Interface\\AddOns\\Skald\\Textures\\" .. file
end

-- Parchment buttons ----------------------------------------------------------
-- Flat leather tabs that sit on the sheet like the index tabs of a book, in place of
-- the red and gold buttons the game draws, which clash with the parchment.
K.BTN = {
    leather      = { 0.50, 0.36, 0.20 },
    leatherHover = { 0.62, 0.45, 0.25 },
    paper        = { 0.93, 0.85, 0.66 },
    edge         = { 0.28, 0.18, 0.08 },
    textIdle     = { 0.93, 0.85, 0.66 },
    textActive   = { 0.25, 0.16, 0.06 },
    gold         = { 0.85, 0.65, 0.10 },
}

local function MakeParchmentButton(parent, width, height, label)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height)
    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    b.text = b:CreateFontString(nil, "OVERLAY", "QuestFont")
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label)

    -- A gold bar along the top edge of the one you are on, like a bookmark.
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetColorTexture(K.BTN.gold[1], K.BTN.gold[2], K.BTN.gold[3], 1)
    b.bar:SetPoint("TOPLEFT", 1, -1)
    b.bar:SetPoint("TOPRIGHT", -1, -1)
    b.bar:SetHeight(3)
    b.bar:Hide()

    function b:SetActive(active)
        self.active = active and true or false
        self.bar:SetShown(self.active)
        local fill = self.active and K.BTN.paper or K.BTN.leather
        self:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        self:SetBackdropBorderColor(K.BTN.edge[1], K.BTN.edge[2], K.BTN.edge[3], 1)
        local ink = self.active and K.BTN.textActive or K.BTN.textIdle
        self.text:SetTextColor(ink[1], ink[2], ink[3])
    end

    b:SetScript("OnEnter", function(self)
        if not self.active then
            local c = K.BTN.leatherHover
            self:SetBackdropColor(c[1], c[2], c[3], 1)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if not self.active then
            local c = K.BTN.leather
            self:SetBackdropColor(c[1], c[2], c[3], 1)
        end
    end)
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)

    b:SetActive(false)
    return b
end

-- Window ---------------------------------------------------------------------

SkaldAPI.MakeButton = MakeParchmentButton   -- so companion tabs match the tabs

StaticPopupDialogs["SKALD_DISCARD"] = {
    text = L.CONFIRM_DISCARD,
    button1 = L.YES,
    button2 = L.NO,
    OnAccept = function()
        Journal().previous = {}
        if window then window:Refresh() end
        Say(L.ARCHIVE_DISCARDED)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- A note for a favourite memory ("Here I got my first rare sword"): one line, kept on the page.
StaticPopupDialogs["SKALD_FAVNOTE"] = {
    text = L.FAV_NOTE_TEXT,
    button1 = L.FAV_SAVE,
    button2 = L.NO,
    hasEditBox = true,
    maxLetters = 100,
    OnShow = function(self, data)
        local eb = self.editBox or (self.GetEditBox and self:GetEditBox())
        if eb then eb:SetText((data and data.favNote) or ""); eb:HighlightText() end
    end,
    OnAccept = function(self, data)
        local eb = self.editBox or (self.GetEditBox and self:GetEditBox())
        local text = strtrim((eb and eb:GetText()) or "")
        if data then
            data.fav = true
            data.favNote = (text ~= "") and text:sub(1, 100) or nil
            if ns.FavoritesChanged then ns.FavoritesChanged() end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        if parent and parent.button1 then parent.button1:Click() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SKALD_CLEAR"] = {
    text = L.CONFIRM_CLEAR,
    button1 = L.YES,
    button2 = L.NO,
    OnAccept = function()
        ResetJournal(Journal())
        if window then window:Refresh() end
        Say(L.CLEARED)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- The book ---------------------------------------------------------------------
-- A leather-bound open book (design: Skald UI v2, 900x580). Spread 1 is the cover (your 3D
-- character on the left, the journey on the right), then the contents, then one day per
-- page. Leather tabs on the left edge jump between sections; tabs added by other addons
-- (Map, Options) open over the pages. Page corners turn the pages.

-- Notes: a line written by hand becomes a page of the diary, placed in time with the others.
-- A place worth printing: not empty, not the "?" a page gets when the game gave no name.
local function KnownZone(z)
    if type(z) ~= "string" or z == "" or z == "?" then return nil end
    return z
end

local function InsertNote(t, zone, text, ses)
    local db = Journal()
    local at = #db.entries
    while at > 0 and (db.entries[at].t or 0) > t do at = at - 1 end
    table.insert(db.entries, at + 1, { t = t, zone = zone or "", kind = "note", arg = text, idx = 1, ses = ses })
    while #db.entries > MAX_ENTRIES do table.remove(db.entries, 1) end
end

-- A note on a day: now, if it is today; otherwise just after that day's last page.
local function AddNote(day, text)
    local now = time()
    local t = (day.date == DayKey(now) and now) or ((day.lastT or day.t or now) + 1)
    InsertNote(t, day.zone or GetZoneText(), text, day.ses or loginTime)
end

-- Notes kept by earlier versions (one line per day) become pages too.
local function ConvertOldNotes()
    local db = Journal()
    if not db or type(db.notes) ~= "table" then return end
    for key, text in pairs(db.notes) do
        local y, m, d = tostring(key):match("^(%d+)-(%d+)-(%d+)")
        if y and type(text) == "string" and text ~= "" then
            InsertNote(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 23, min = 0, sec = 0 }),
                nil, text)
        end
    end
    db.notes = nil
end

-- Fonts of the design (Cinzel, EB Garamond, Caveat; SIL Open Font License, see Fonts/).
-- If the game cannot load one, the quest face of the game stands in at a smaller size.
-- The size of the text in the book is a setting (Small, Normal, Large).
K.TEXT_SIZES = { [0] = 11, [1] = 13, [2] = 15 }
local ApplyFonts
do
    local FALLBACK = "Fonts\\FRIZQT__.TTF"
    local ok, file = pcall(function() return (QuestFont:GetFont()) end)
    if ok and type(file) == "string" then FALLBACK = file end
    local DIR = "Interface\\AddOns\\Skald\\Fonts\\"
    local function Make(name, file, size, fallbackSize)
        local font = _G[name] or CreateFont(name)
        local loaded = font:SetFont(DIR .. file, size, "")
        if loaded == false then font:SetFont(FALLBACK, fallbackSize, "") end
    end
    ApplyFonts = function()
        local size = K.TEXT_SIZES[(SkaldDB and SkaldDB.textSize) or 1] or 14
        Make("SkaldBody", "EBGaramond.ttf", size, size - 2)
        Make("SkaldItalic", "EBGaramond-Italic.ttf", size, size - 2)
        Make("SkaldSmall", "EBGaramond.ttf", 11, 10)
        Make("SkaldHead", "Cinzel.ttf", 22, 19)
        Make("SkaldHead2", "Cinzel.ttf", 17, 16)
        Make("SkaldSec", "Cinzel.ttf", 13, 12)
        Make("SkaldNote", "Caveat.ttf", 20, 14)
    end
    ApplyFonts()
end

K.TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\"

-- Inks (design tokens).
K.C_BODY  = { 0.243, 0.165, 0.086 }   -- #3E2A16
K.C_HEAD  = { 0.431, 0.118, 0.102 }   -- #6E1E1A
K.C_SEC   = K.C_HEAD
K.C_MUTED = { 0.420, 0.290, 0.165 }   -- #6B4A2A
K.C_TIME  = { 0.541, 0.416, 0.227 }   -- #8A6A3A
K.C_NOTE  = { 0.353, 0.227, 0.102 }   -- #5A3A1A
K.C_HDR   = { 0.478, 0.290, 0.180 }   -- #7A4A2E
K.INKS = { { 0.353, 0.227, 0.102 }, { 0.180, 0.165, 0.227 }, { 0.431, 0.118, 0.102 } }   -- sepia, iron gall, burgundy
K.TAB_OFF = { 0.353, 0.227, 0.141 }   -- #5A3A24
K.TAB_ON  = { 0.722, 0.541, 0.353 }   -- #B88A5A

K.BOOK_W, K.BOOK_H = 980, 580
K.COVER_X, K.COVER_W = 88, 892
K.PAGE_SW, K.PAGE_SH, K.PAGE_Y = 408, 536, 22
K.PAGE_XS = { 112, 548 }
K.CW = K.PAGE_SW - 66                  -- the width of text on a page
K.TOP_Y = 48
K.PAGE_H = 438                          -- the height of text on a page
K.ENTRY_X = 80                          -- icon (24) | time (40) | text, gaps of 8
K.NOTE_BTN_H = 52                       -- the room at the foot of a day for the quill button
K.GAP = 11
K.INDEX_ROW = 22

K.ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII" }
local function RomanLower(n)
    local out, map = "", { { 10, "x" }, { 9, "ix" }, { 5, "v" }, { 4, "iv" }, { 1, "i" } }
    for _, m in ipairs(map) do
        while n >= m[1] do out = out .. m[2]; n = n - m[1] end
    end
    return out
end

local function Hex(c)
    return string.format("|cff%02x%02x%02x",
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- What a day was about, from what it held; picks the title.
local function DayTitle(day, number)
    local counts = { dungeon = 0, boss = 0, level = 0, death = 0, zone = 0, deed = 0 }
    for _, e in ipairs(day.entries) do
        local k = e.kind
        if k == "milestone" then k = "level" end
        if counts[k] then counts[k] = counts[k] + 1 end
        if k == "achievement" or (k == "quest" and (e.tier or 0) >= 4) then counts.deed = counts.deed + 1 end
    end
    local key = (number == 1 and "first") or (counts.boss > 0 and "boss") or (counts.dungeon > 0 and "dungeon")
        or (counts.level >= 2 and "levels") or (counts.death >= 3 and "deadly") or (counts.deed > 0 and "deed")
        or (counts.zone >= 3 and "lands") or (#day.entries >= 12 and "busy") or "plain"
    return string.format(L.DAY_HEADER, number, L.DAY_TITLES[key])
end

-- The pages of the diary, grouped by calendar day (oldest first).
local function BuildDays()
    local days, byKey, lastByDate = {}, {}, {}
    local level = 1
    local bySession = SkaldDB and SkaldDB.dayMode == 1
    for _, e in ipairs(Journal().entries) do
        local when = (e.kind == "day" and tostring(e.arg)) or DayKey(e.t)
        local key = when
        if bySession and e.kind ~= "day" and e.ses then key = when .. "@" .. tostring(e.ses) end
        -- A closing summary belongs to the last page of its date.
        local day = (e.kind == "day" and lastByDate[when]) or byKey[key]
        if not day then
            day = { key = key, date = when, entries = {}, t = e.t, level = level }
            byKey[key] = day
            days[#days + 1] = day
        end
        lastByDate[day.date] = day
        if e.kind == "day" then
            day.summary = e
        else
            day.entries[#day.entries + 1] = e
            if e.kind ~= "note" then day.zone = KnownZone(ns.PlaceName(e)) or day.zone end
            day.lastT = math.max(day.lastT or 0, e.t or 0)
            day.ses = day.ses or e.ses
            if e.kind == "level" or e.kind == "milestone" then
                level = math.max(level, tonumber(e.arg) or level)
            end
        end
        day.level = math.max(day.level, level)
    end
    for i, day in ipairs(days) do day.number = i end
    return days
end

K.ACCENT_UP = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê",
    ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç",
    ["è"] = "È", ["ë"] = "Ë", ["î"] = "Î", ["ï"] = "Ï", ["û"] = "Û", ["ü"] = "Ü", ["ù"] = "Ù" }
local function Upper(s)
    s = tostring(s or ""):upper()
    s = s:gsub("\197\147", "\197\146")
    return (s:gsub("[\195][\128-\191]", K.ACCENT_UP))
end

local function Chapter(level) return math.min(#L.CHAPTERS, math.floor((level or 1) / 10) + 1) end

-- The sound of a page turning (Options can switch it off).
local function TurnSound()
    if SkaldDB and SkaldDB.sound == false then return end
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836)
end

-- The icon of a page of loot: gear (weapons, armour, jewellery, cloaks, bags) has the book's own
-- icons; anything else (meat, pelts, cloth, recipes) shows the game's own icon of the item, which
-- says at a glance what it is.
K.WEAPON_CAT = {
    [0] = "axe", [1] = "axe", [2] = "bow", [3] = "gun", [4] = "mace", [5] = "mace", [6] = "polearm", [7] = "sword",
    [8] = "greatsword", [9] = "warglaive", [10] = "staff", [11] = "fist", [12] = "fist", [13] = "fist",
    [14] = "weapon", [15] = "dagger", [16] = "thrown", [17] = "polearm", [18] = "crossbow", [19] = "wand", [20] = "fishing",
}
K.ARMOR_SLOT = {
    INVTYPE_HEAD = "helm", INVTYPE_SHOULDER = "shoulder", INVTYPE_CHEST = "armor", INVTYPE_ROBE = "armor",
    INVTYPE_BODY = "armor", INVTYPE_HAND = "hands", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet",
    INVTYPE_WAIST = "waist", INVTYPE_WRIST = "wrist", INVTYPE_CLOAK = "cloak", INVTYPE_FINGER = "ring",
    INVTYPE_NECK = "amulet", INVTYPE_TRINKET = "trinket", INVTYPE_SHIELD = "shield", INVTYPE_HOLDABLE = "offhand", INVTYPE_RELIC = "relic", INVTYPE_TABARD = "tabard",
}
-- Professions' tools are weapons of the "miscellaneous" kind in the game; the book draws the knife as a
-- dagger and the pick and the hammers as a mace.
ns.TOOL_CAT = {
    [7005] = "skinningknife",
    [2901] = "pick",     -- Mining Pick
    [5956] = "hammer",   -- Blacksmith Hammer
    [6219] = "spanner",  -- Arclight Spanner
}
-- The kinds that have an icon of their own in the book; every other item shows the game's own icon.
K.ART_ICON = {
    sword = "it_weapon", greatsword = "it_greatsword", dagger = "it_dagger", axe = "it_axe", mace = "it_mace",
    staff = "it_staff", polearm = "it_polearm", fist = "it_fist", bow = "it_bow", crossbow = "it_crossbow",
    gun = "it_gun", thrown = "it_thrown", wand = "it_wand", fishing = "it_fishing", relic = "it_relic", ammo = "it_ammo",
    armor = "it_armor", helm = "it_helm", shoulder = "it_shoulder", hands = "it_hands", legs = "it_legs",
    feet = "it_feet", waist = "it_waist", wrist = "it_wrist", shield = "it_shield", offhand = "it_offhand",
    ring = "it_ring", jewel = "it_ring", amulet = "it_amulet", cloak = "it_cloak", bag = "it_bag", trinket = "it_trinket",
    weapon = "it_weapon", food = "st_food", bandage = "st_bandage",
    skinningknife = "it_skinningknife", pick = "it_pick", hammer = "it_hammer", spanner = "it_spanner", tabard = "it_tabard",
}

-- What an item is, by its reference: a kind (sword, helm, ring, offhand, recipe...) and the game's icon.
local function ItemInfo(ref)
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getInstant or not ref then return "other", nil end
    local ok, _, _, _, equipLoc, icon, classID, subclassID = pcall(getInstant, ref)
    if not ok then return "other", nil end
    local cat = "other"
    local id = type(ref) == "string" and tonumber(ref:match("item:(%d+)"))
    if id and ns.TOOL_CAT[id] then cat = ns.TOOL_CAT[id]
    elseif classID == 2 then cat = K.WEAPON_CAT[subclassID] or "weapon"
    elseif classID == 1 then cat = "bag"
    elseif classID == 6 then cat = "ammo"
    elseif classID == 9 then cat = "recipe"
    elseif classID == 0 and subclassID == 5 then cat = "food"
    elseif classID == 0 and subclassID == 7 then cat = "bandage"
    elseif classID == 7 then cat = "material"
    elseif classID == 4 then cat = K.ARMOR_SLOT[equipLoc] or "armor" end
    return cat, icon, (classID == 4) and subclassID or nil
end

-- Gear: anything you can wear, wield or carry as a bag. Recipes, materials and loose goods are not.
local function IsGear(cat)
    return cat ~= "other" and cat ~= "recipe" and cat ~= "material" and cat ~= "ammo" and cat ~= "food" and cat ~= "bandage"
end

-- The icon of a page of loot: the book's own icon where it has one for that kind of item (judged
-- by the item itself, so pages written earlier follow too), otherwise the game's icon of the item.
local function ItemIcon(e)
    local ref = ItemParts(e.arg)
    local cat = ref and select(1, ItemInfo(ref)) or e.cat
    local art = K.ART_ICON[cat or ""]
    if art then return "Interface\\AddOns\\Skald\\Textures\\" .. art end
    return e.ic or "Interface\\AddOns\\Skald\\Textures\\it_generic"
end

-- The toast: a small parchment that appears when something worth remembering is written while the
-- book is closed; a click opens the book.
do
local toastFrame, lastToast = nil, 0
local NOTIFY_KINDS = {
    level = true, milestone = true, mark = true, boss = true, dungeon = true, achievement = true,
    mount = true, home = true, rep = true, flight = true, guild = true, tame = true,
}
local function PlainLine(s)
    s = tostring(s or "")
    s = s:gsub("|H.-|h(%[.-%])|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return s
end
-- A frame drawn from nine pieces of one texture: four corners, four edges, the middle. `border` is
-- the width of the corners in the texture, `draw` their size on screen.
ns.NineSlice = function(frame, file, texW, texH, border, draw)
    local u, v = border / texW, border / texH
    local function Piece(l, r, t, b2, u0, u1, v0, v1, layer)
        local tex = frame:CreateTexture(nil, "BACKGROUND", nil, layer)
        tex:SetTexture(file)
        tex:SetTexCoord(u0, u1, v0, v1)
        return tex
    end
    local tl = Piece(0, 0, 0, 0, 0, u, 0, v, 2); tl:SetSize(draw, draw); tl:SetPoint("TOPLEFT")
    local tr = Piece(0, 0, 0, 0, 1 - u, 1, 0, v, 2); tr:SetSize(draw, draw); tr:SetPoint("TOPRIGHT")
    local bl = Piece(0, 0, 0, 0, 0, u, 1 - v, 1, 2); bl:SetSize(draw, draw); bl:SetPoint("BOTTOMLEFT")
    local br = Piece(0, 0, 0, 0, 1 - u, 1, 1 - v, 1, 2); br:SetSize(draw, draw); br:SetPoint("BOTTOMRIGHT")
    local top = Piece(0, 0, 0, 0, u, 1 - u, 0, v, 1)
    top:SetPoint("TOPLEFT", draw, 0); top:SetPoint("TOPRIGHT", -draw, 0); top:SetHeight(draw)
    local bottom = Piece(0, 0, 0, 0, u, 1 - u, 1 - v, 1, 1)
    bottom:SetPoint("BOTTOMLEFT", draw, 0); bottom:SetPoint("BOTTOMRIGHT", -draw, 0); bottom:SetHeight(draw)
    local left = Piece(0, 0, 0, 0, 0, u, v, 1 - v, 1)
    left:SetPoint("TOPLEFT", 0, -draw); left:SetPoint("BOTTOMLEFT", 0, draw); left:SetWidth(draw)
    local right = Piece(0, 0, 0, 0, 1 - u, 1, v, 1 - v, 1)
    right:SetPoint("TOPRIGHT", 0, -draw); right:SetPoint("BOTTOMRIGHT", 0, draw); right:SetWidth(draw)
    local center = Piece(0, 0, 0, 0, u, 1 - u, v, 1 - v, 0)
    center:SetPoint("TOPLEFT", draw, -draw); center:SetPoint("BOTTOMRIGHT", -draw, draw)
end

-- `enter` goes from 1 (just starting to come in) to 0 (in place): the notice slides a little.
ns.PlaceNotice = function(fr, enter)
    enter = enter or 0
    local db = SkaldDB
    local pos = db and db.toastPos
    fr:ClearAllPoints()
    if pos then
        fr:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1] - 18 * enter, pos[2])
        return
    end
    local where = db and db.toastAnchor or "top"
    if where == "left" then
        fr:SetPoint("LEFT", UIParent, "LEFT", 24 - 18 * enter, 90)
    elseif where == "bottom" then
        fr:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230 - 14 * enter)
    else
        fr:SetPoint("TOP", UIParent, "TOP", 0, -8 + 14 * enter)
    end
end

-- The rarity of a page that is not a quest, for the colour of its seal (as on the map).
local TOAST_TIER = {
    zone = 1, level = 2, milestone = 4, death = 1, dungeon = 3, boss = 4, mount = 3, guild = 3,
    party = 2, reunion = 2, achievement = 5, skill = 2, profession = 2, tame = 2, mark = 4, home = 1, rep = 3, flight = 1, hearth = 1,
}
local TEXD = "Interface\\AddOns\\Skald\\Textures\\"

local function ShowToast(e, titleText, bodyText, lines, seconds)
    if not toastFrame then
        local fr = CreateFrame("Frame", "SkaldToast", UIParent)
        fr:SetSize(400, 84)
        ns.PlaceNotice(fr)
        fr:SetFrameStrata("HIGH")
        fr:EnableMouse(true)
        fr:SetMovable(true)
        fr:SetClampedToScreen(true)
        fr:RegisterForDrag("LeftButton")
        -- Drag the notice where you want it; the place is kept.
        fr:SetScript("OnDragStart", function(self) self.dragging = true; self:StartMoving() end)
        fr:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self.dragging = false
            self.draggedAt = (GetTime and GetTime()) or 0
            local left, bottom = self:GetLeft(), self:GetBottom()
            if left and bottom and SkaldDB then SkaldDB.toastPos = { left, bottom } end
        end)
        ns.NineSlice(fr, TEXD .. "ui_notice", 512, 128, 38, 26)
        -- the wax seal, with the icon of what happened in its hollow
        fr.seal = fr:CreateTexture(nil, "ARTWORK", nil, 1)
        fr.seal:SetSize(60, 60)
        fr.seal:SetPoint("LEFT", 30, 0)
        fr.seal:SetTexture(TEXD .. "ui_seal1")
        fr.icon = fr:CreateTexture(nil, "ARTWORK", nil, 3)
        fr.icon:SetSize(30, 30)
        fr.icon:SetPoint("CENTER", fr.seal, "CENTER", 0, 0)
        fr.icon:SetTexture(K.TEX .. "quill")
        -- a splash of gold ink that flashes behind the seal as the notice comes in
        fr.splash = fr:CreateTexture(nil, "ARTWORK", nil, 0)
        fr.splash:SetSize(110, 110)
        fr.splash:SetPoint("CENTER", fr.seal, "CENTER", 0, 0)
        fr.splash:SetTexture(TEXD .. "ui_splash")
        fr.splash:SetTexCoord(0, 1, 0, 1)
        fr.splash:SetAlpha(0)
        fr.title = fr:CreateFontString(nil, "OVERLAY", "SkaldSec")
        fr.title:SetPoint("TOPLEFT", 102, -15)
        fr.title:SetWidth(266)
        fr.title:SetJustifyH("LEFT")
        fr.title:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
        fr.rule = fr:CreateTexture(nil, "ARTWORK", nil, 1)
        fr.rule:SetSize(180, 11)
        fr.rule:SetPoint("TOPLEFT", fr.title, "BOTTOMLEFT", -2, -1)
        fr.rule:SetTexture(TEXD .. "ui_divider")
        fr.rule:SetTexCoord(0, 480 / 512, 0, 28 / 32)
        fr.body = fr:CreateFontString(nil, "OVERLAY", "SkaldBody")
        fr.body:SetPoint("TOPLEFT", fr.rule, "BOTTOMLEFT", 2, -3)
        fr.body:SetWidth(266)
        fr.body:SetJustifyH("LEFT")
        fr.body:SetJustifyV("TOP")
        fr.body:SetWordWrap(true)
        fr.body:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        -- how long is left: a thin gold line along the foot that shortens
        fr.bar = fr:CreateTexture(nil, "OVERLAY")
        fr.bar:SetColorTexture(0.85, 0.65, 0.10, 0.85)
        fr.bar:SetHeight(2)
        fr.bar:SetPoint("BOTTOMLEFT", 30, 14)
        fr:SetScript("OnMouseUp", function(self, button)
            -- a drag also ends with a mouse up: it must not open the book
            local draggedAt = rawget(self, "draggedAt")
            if draggedAt and ((GetTime and GetTime()) or 0) - draggedAt < 0.3 then return end
            self:Hide()
            if self.entry and self.entry.sample then return end
            if button == "LeftButton" and window then
                -- the page that was written, lit; without it, the newest day
                if not (self.entry and window:OpenEntry(self.entry)) then window:ShowSection("days", true); window:Show() end
            end
        end)
        -- comes in (a short slide and fade, and the splash), waits while the mouse is over it, goes out softly
        fr:SetScript("OnUpdate", function(self, elapsed)
            if not self.born then return end
            if rawget(self, "dragging") or self:IsMouseOver() then self.born = self.born + (elapsed or 0) end
            local age = ((GetTime and GetTime()) or 0) - self.born
            local life = self.life or 6.5
            if age >= life then self.born = nil; self:Hide(); return end
            local alpha = 1
            if age < 0.28 then alpha = age / 0.28 elseif age > life - 0.7 then alpha = (life - age) / 0.7 end
            self:SetAlpha(math.max(0, math.min(1, alpha)))
            if not rawget(self, "dragging") then ns.PlaceNotice(self, age < 0.28 and (1 - age / 0.28) or 0) end
            self.bar:SetWidth(math.max(1, (self:GetWidth() - 60) * (1 - age / life)))
            if age < 0.8 then
                local t = age / 0.8
                self.splash:SetAlpha(0.9 * (1 - t))
                local size = 70 + 60 * t
                self.splash:SetSize(size, size)
            else
                self.splash:SetAlpha(0)
            end
        end)
        fr:Hide()
        toastFrame = fr
    end

    -- what it is about: the kind of page names it, the page's own icon marks it, the seal shows its rarity
    local kindLabel = e and L.TOAST_KIND and L.TOAST_KIND[e.kind]
    toastFrame.title:SetText(Upper(titleText or kindLabel or L.TOAST_TITLE))
    local icon, tier
    if e then
        if e.kind == "loot" then icon = ItemIcon(e)
        elseif e.kind == "quest" and e.tier then icon = K.SEAL_PATH .. e.tier
        else icon = EventIconPath(e.kind, e) end
        tier = (type(e.tier) == "number" and (e.kind == "quest" or e.kind == "loot") and e.tier) or TOAST_TIER[e.kind] or 1
    end
    toastFrame.icon:SetTexture(icon or (K.TEX .. "quill"))
    toastFrame.seal:SetTexture(TEXD .. "ui_seal" .. math.max(0, math.min(5, tier or 1)))

    local text = bodyText
    if not text and e then
        local bare = {}
        for k, v in pairs(e) do bare[k] = v end
        bare.noExtras = true   -- the toast tells the page only, not who was there or the hour
        text = PlainLine(RenderEntry(bare))
    end
    toastFrame.entry = e
    toastFrame.body:SetText(text or "")
    pcall(toastFrame.body.SetMaxLines, toastFrame.body, lines or 3)
    local bodyHeight = math.max(16, toastFrame.body:GetStringHeight() or 16)
    -- the title, its rule, the text, and room for the burnt edge below
    toastFrame:SetHeight(math.max(84, 15 + 14 + 12 + 3 + bodyHeight + 30))
    toastFrame.born = (GetTime and GetTime()) or 0
    toastFrame.life = seconds or 6.5
    toastFrame:SetAlpha(0)
    toastFrame:Show()
    if SkaldDB and SkaldDB.sound ~= false then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836)
    end
end

-- Shows a sample notice that stays for half a minute: drag it where you want the notices to appear.
ns.PreviewNotice = function()
    local sample = { kind = "level", arg = 5, tier = 2, idx = 1, t = time(), zone = GetZoneText(), sample = true }
    pcall(ShowToast, sample, nil, nil, 3, 30)
end

-- The card shown on returning to the game: where the last visit ended, the quests still open and
-- the note left for this day, laid out in small sections on a parchment. A click opens the book.
do
local card
ns.ShowResumeCard = function(data)
    if not card then
        local fr = CreateFrame("Frame", "SkaldResume", UIParent)
        fr:SetWidth(380)
        ns.PlaceNotice(fr)
        fr:SetFrameStrata("HIGH")
        fr:EnableMouse(true)
        ns.NineSlice(fr, "Interface\\AddOns\\Skald\\Textures\\ui_notice", 512, 128, 38, 30)
        fr.paper = { SetTexCoord = function() end }
        fr.icon = fr:CreateTexture(nil, "ARTWORK")
        fr.icon:SetSize(40, 40)
        fr.icon:SetPoint("TOPLEFT", 34, -26)
        fr.icon:SetTexture(K.TEX .. "quill")
        fr.title = fr:CreateFontString(nil, "OVERLAY", "SkaldHead")
        fr.title:SetPoint("LEFT", fr.icon, "RIGHT", 12, 0)
        fr.title:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
        fr.rule = fr:CreateTexture(nil, "ARTWORK")
        fr.rule:SetSize(130, 11)
        fr.rule:SetPoint("TOPLEFT", fr.icon, "BOTTOMLEFT", 0, -4)
        fr.rule:SetTexture(K.TEX .. "rule")
        fr.rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
        fr.parts = {}
        fr:SetScript("OnMouseUp", function(self, button)
            self:Hide()
            if button == "LeftButton" and window then window:ShowSection("days", true); window:Show() end   -- the newest day, not the tab last used
        end)
        fr:Hide()
        card = fr
    end
    for _, p in ipairs(card.parts) do p:Hide() end
    card.title:SetText(L.TOAST_RESUME)
    local used = 0
    local function Part(font, text, r, g, b, gap)
        used = used + 1
        local p = card.parts[used]
        if not p then
            p = card:CreateFontString(nil, "OVERLAY", font)
            card.parts[used] = p
        end
        p:SetFontObject(font)
        p:ClearAllPoints()
        p:SetWidth(300)
        p:SetJustifyH("LEFT")
        p:SetWordWrap(true)
        p:SetTextColor(r, g, b)
        p:SetText(text)
        p:Show()
        return p, gap
    end
    local y = 86
    local function Place(p, gap)
        p:SetPoint("TOPLEFT", card, "TOPLEFT", 40, -(y + (gap or 0)))
        y = y + (gap or 0) + math.max(14, p:GetStringHeight() or 14)
    end
    Place(Part("SkaldSec", Upper(L.RESUME_LABEL_LAST), K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3]))
    Place(Part("SkaldBody", string.format(L.RESUME_LAST_VALUE, data.zone or L.UNKNOWN_ZONE, data.level or 0),
        K.C_BODY[1], K.C_BODY[2], K.C_BODY[3]), 1)
    if data.quests and #data.quests > 0 then
        Place(Part("SkaldSec", Upper(L.RESUME_LABEL_QUESTS), K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3]), 10)
        for i, title in ipairs(data.quests) do
            Place(Part("SkaldBody", "-  " .. title, K.C_BODY[1], K.C_BODY[2], K.C_BODY[3]), i == 1 and 1 or 0)
        end
    end
    if data.note and data.note ~= "" then
        Place(Part("SkaldSec", Upper(L.RESUME_LABEL_NEXT), K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3]), 10)
        Place(Part("SkaldNote", data.note, K.C_NOTE[1], K.C_NOTE[2], K.C_NOTE[3]), 1)
    end
    Place(Part("SkaldSec", L.RESUME_HINT, K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3]), 12)
    local height = y + 34
    card:SetHeight(height)
    card.paper:SetTexCoord(0, 380 / 256, 0, height / 256)
    ns.PlaceNotice(card)
    card:SetAlpha(1)
    card:Show()
    local stamp = (card.stamp or 0) + 1
    card.stamp = stamp
    C_Timer.After(16, function() if card.stamp == stamp then card:Hide() end end)
    if SkaldDB and SkaldDB.sound ~= false then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836)
    end
    if PulseMinimap then pcall(PulseMinimap) end
end
end

-- A notice of its own (a title and a few lines), used for the reminder on returning to the game.
ns.ShowNotice = function(titleText, bodyText, lines, seconds, entry)
    pcall(ShowToast, entry, titleText, bodyText, lines, seconds)
end

Notify = function(e)
    if not SkaldDB or SkaldDB.toast == false then return end
    if window and window:IsShown() then return end
    local notable = NOTIFY_KINDS[e.kind] or ((e.kind == "loot" or e.kind == "quest") and (e.tier or 0) >= 3)
    if not notable then return end
    local now = (GetTime and GetTime()) or time()
    if now - lastToast < 4 then return end
    lastToast = now
    pcall(ShowToast, e)
    if PulseMinimap then pcall(PulseMinimap) end
end
end

local function CreateWindow()
    -- The frame holds the tabs behind the cover; the book is everything else.
    local f = CreateFrame("Frame", "SkaldFrame", UIParent)
    f:SetSize(K.BOOK_W, K.BOOK_H)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        Settings().pos = { point, relPoint, x, y }
    end)
    f:Hide()
    tinsert(UISpecialFrames, "SkaldFrame")

    local pos = Settings().pos
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER")
    end

    local book = CreateFrame("Frame", nil, f)
    book:SetAllPoints()
    book:SetFrameLevel(f:GetFrameLevel() + 4)

    -- Leather cover: a nine-slice of one texture (corners, edges tiled in 80 px pieces). ---
    local coverParts = {}
    local function Cover(x, y, w, h, u0, u1, v0, v1)
        local t = book:CreateTexture(nil, "BACKGROUND", nil, 0)
        coverParts[#coverParts + 1] = t
        t:SetSize(w, h)
        t:SetPoint("TOPLEFT", x, -y)
        t:SetTexture(K.TEX .. "cover9")
        t:SetTexCoord(u0 / 256, u1 / 256, v0 / 256, v1 / 256)
        return t
    end
    Cover(K.COVER_X, 0, 56, 56, 0, 56, 0, 56)
    Cover(K.COVER_X + K.COVER_W - 56, 0, 56, 56, 136, 192, 0, 56)
    Cover(K.COVER_X, K.BOOK_H - 56, 56, 56, 0, 56, 136, 192)
    Cover(K.COVER_X + K.COVER_W - 56, K.BOOK_H - 56, 56, 56, 136, 192, 136, 192)
    Cover(K.COVER_X + 56, 56, K.COVER_W - 112, K.BOOK_H - 112, 56, 136, 56, 136)
    local x = K.COVER_X + 56
    while x < K.COVER_X + K.COVER_W - 56 do
        local w = math.min(80, K.COVER_X + K.COVER_W - 56 - x)
        Cover(x, 0, w, 56, 56, 56 + w, 0, 56)
        Cover(x, K.BOOK_H - 56, w, 56, 56, 56 + w, 136, 192)
        x = x + 80
    end
    local y = 56
    while y < K.BOOK_H - 56 do
        local h = math.min(80, K.BOOK_H - 56 - y)
        Cover(K.COVER_X, y, 56, h, 0, 56, 56, 56 + h)
        Cover(K.COVER_X + K.COVER_W - 56, y, 56, h, 136, 192, 56, 56 + h)
        y = y + 80
    end

    -- The spine, the stacked page edges, the clasp.
    local spine = book:CreateTexture(nil, "BACKGROUND", nil, 1)
    spine:SetSize(28, 572)
    spine:SetPoint("TOPLEFT", K.PAGE_XS[1] + K.PAGE_SW, -4)
    spine:SetTexture(K.TEX .. "spine", "REPEAT", "REPEAT")
    spine:SetTexCoord(0, 28 / 32, 0, 572 / 256)
    -- Behind each page, the dark of the cover shows around the burnt edges (no stack of page
    -- edges: a pale band showed through the corners of the paper).
    for i = 1, 2 do
        local back = book:CreateTexture(nil, "BACKGROUND", nil, 0)
        back:SetColorTexture(0.13, 0.07, 0.035, 1)
        back:SetSize(K.PAGE_SW + 6, K.PAGE_SH + 12)
        back:SetPoint("TOPLEFT", i == 1 and (K.PAGE_XS[1] - 6) or K.PAGE_XS[2], -(K.PAGE_Y - 6))
    end

    -- Close: a small brass stud pressed into the leather, with a cross scratched on it
    -- (the game's red button did not belong to the book). Esc closes the book too.
    local close = CreateFrame("Button", nil, book)
    close:SetFrameLevel(book:GetFrameLevel() + 6)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -22, -22)
    local function Stud(size, r, g, b)
        local tex = close:CreateTexture(nil, "ARTWORK")
        tex:SetSize(size, size)
        tex:SetPoint("CENTER", 0, 0)
        tex:SetColorTexture(r, g, b, 1)
        local ok, mask = pcall(close.CreateMaskTexture, close)
        if ok and mask then
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            pcall(tex.AddMaskTexture, tex, mask)
        end
        return tex
    end
    Stud(26, 0.10, 0.05, 0.02)            -- dark edge
    local brass = Stud(22, 0.78, 0.59, 0.23)
    Stud(16, 0.24, 0.13, 0.07)            -- the leather showing through
    local bars = {}
    for _, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local bar = close:CreateTexture(nil, "OVERLAY")
        bar:SetSize(12, 2)
        bar:SetPoint("CENTER", 0, 0)
        bar:SetColorTexture(0.88, 0.72, 0.29, 1)
        pcall(bar.SetRotation, bar, angle)
        bars[#bars + 1] = bar
    end
    close:SetScript("OnEnter", function()
        brass:SetColorTexture(0.95, 0.80, 0.40, 1)
        for _, bar in ipairs(bars) do bar:SetColorTexture(1, 0.92, 0.6, 1) end
    end)
    close:SetScript("OnLeave", function()
        brass:SetColorTexture(0.78, 0.59, 0.23, 1)
        for _, bar in ipairs(bars) do bar:SetColorTexture(0.88, 0.72, 0.29, 1) end
    end)
    close:SetScript("OnClick", function() f:Hide() end)

    -- One page of the open book: parchment with burnt edges, header, page number. --------
    local function MakeSide(i)
        local s = { texts = {}, rows = {}, lines = {}, padL = (i == 1) and 30 or 36 }
        local fr = CreateFrame("Frame", nil, book)
        s.frame = fr
        fr:SetSize(K.PAGE_SW, K.PAGE_SH)
        fr:SetPoint("TOPLEFT", K.PAGE_XS[i], -K.PAGE_Y)
        fr:SetFrameLevel(book:GetFrameLevel() + 3)
        pcall(fr.SetClipsChildren, fr, true)
        local paper = fr:CreateTexture(nil, "BACKGROUND", nil, 0)
        -- Inset on the outer sides: the corners of the burnt edge are transparent, and the paper
        -- must not show through them (the dark of the cover does).
        paper:SetPoint("TOPLEFT", (i == 1) and 5 or 0, -5)
        paper:SetPoint("BOTTOMRIGHT", (i == 1) and 0 or -5, 5)
        paper:SetTexture(K.TEX .. "parchment", "REPEAT", "REPEAT")
        local ox, oy = (i == 1) and 0 or 120, (i == 1) and 0 or 80
        paper:SetTexCoord(ox / 256, (ox + K.PAGE_SW) / 256, oy / 256, (oy + K.PAGE_SH) / 256)

        -- Burnt edges on three sides (the side next to the spine stays clean).
        local BURN = 48
        local function Burn(point1, point2, w, h, u0, u1, v0, v1, x1, y1, x2, y2)
            local t = fr:CreateTexture(nil, "ARTWORK", nil, 1)
            t:SetTexture(K.TEX .. "burn9")
            t:SetTexCoord(u0 / 256, u1 / 256, v0 / 256, v1 / 256)
            t:SetPoint(point1, x1, y1)
            if point2 then t:SetPoint(point2, x2, y2) end
            if w then t:SetWidth(w) end
            if h then t:SetHeight(h) end
        end
        if i == 1 then
            Burn("TOPLEFT", nil, BURN, BURN, 0, 64, 0, 64, 0, 0)
            Burn("BOTTOMLEFT", nil, BURN, BURN, 0, 64, 192, 256, 0, 0)
            Burn("TOPLEFT", "BOTTOMLEFT", BURN, nil, 0, 64, 64, 192, 0, -BURN, 0, BURN)
            Burn("TOPLEFT", "TOPRIGHT", nil, BURN, 64, 192, 0, 64, BURN, 0, 0, 0)
            Burn("BOTTOMLEFT", "BOTTOMRIGHT", nil, BURN, 64, 192, 192, 256, BURN, 0, 0, 0)
        else
            Burn("TOPRIGHT", nil, BURN, BURN, 192, 256, 0, 64, 0, 0)
            Burn("BOTTOMRIGHT", nil, BURN, BURN, 192, 256, 192, 256, 0, 0)
            Burn("TOPRIGHT", "BOTTOMRIGHT", BURN, nil, 192, 256, 64, 192, 0, -BURN, 0, BURN)
            Burn("TOPLEFT", "TOPRIGHT", nil, BURN, 64, 192, 0, 64, 0, 0, -BURN, 0)
            Burn("BOTTOMLEFT", "BOTTOMRIGHT", nil, BURN, 64, 192, 192, 256, 0, 0, -BURN, 0)
        end
        local gutter = fr:CreateTexture(nil, "ARTWORK", nil, 2)
        gutter:SetSize(56, K.PAGE_SH)
        gutter:SetPoint(i == 1 and "TOPRIGHT" or "TOPLEFT", 0, 0)
        gutter:SetTexture(K.TEX .. "gutter")
        if i == 1 then gutter:SetTexCoord(0, 56 / 64, 0, 1) else gutter:SetTexCoord(56 / 64, 0, 0, 1) end

        -- Header: small print either side of a thin double rule.
        local hl = fr:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        hl:SetPoint("TOPLEFT", 30, -15)
        hl:SetTextColor(K.C_HDR[1], K.C_HDR[2], K.C_HDR[3])
        hl:SetText(L.HDR_L)
        local hr = fr:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        hr:SetPoint("TOPRIGHT", -30, -15)
        hr:SetTextColor(K.C_HDR[1], K.C_HDR[2], K.C_HDR[3])
        hr:SetText(L.HDR_R)
        s.hr = hr
        s.hl = hl
        for n, alpha in ipairs({ 0.55, 0.22 }) do
            local rule = fr:CreateTexture(nil, "ARTWORK", nil, 3)
            rule:SetColorTexture(0.43, 0.118, 0.102, alpha)
            rule:SetHeight(1)
            rule:SetPoint("TOPLEFT", 30, -(35 + (n - 1) * 3))
            rule:SetPoint("TOPRIGHT", -30, -(35 + (n - 1) * 3))
        end

        s.quill = fr:CreateTexture(nil, "ARTWORK", nil, 3)
        s.quill:SetSize(20, 20)
        s.quill:SetTexture(K.TEX .. "quill")
        s.num = fr:CreateFontString(nil, "OVERLAY", "SkaldBody")
        s.num:SetPoint("BOTTOM", 10, 14)
        s.quill:SetPoint("RIGHT", s.num, "LEFT", -3, 0)
        s.quill:Hide()

        s.sub = fr:CreateFontString(nil, "OVERLAY", "SkaldBody")
        s.sub:SetWidth(K.CW)
        s.sub:SetJustifyH("CENTER")
        s.sub:SetJustifyV("TOP")
        s.sub:Hide()

        s.cover = CreateFrame("Frame", nil, fr)
        s.cover:SetAllPoints()
        s.cover:Hide()
        s.rule = fr:CreateTexture(nil, "ARTWORK", nil, 3)
        s.rule:SetTexture(K.TEX .. "rule")
        s.rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
        s.rule:SetSize(130, 11)
        s.rule:Hide()
        s.line = fr:CreateTexture(nil, "ARTWORK", nil, 3)
        s.line:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.3)
        s.line:SetHeight(1)
        s.line:Hide()
        return s
    end
    local sides = { MakeSide(1), MakeSide(2) }

    local function Rule(s, y)
        s.rule:ClearAllPoints()
        s.rule:SetPoint("TOP", s.frame, "TOP", 0, -y)
        s.rule:Show()
    end

    local function SideText(s, n)
        local fs = s.texts[n]
        if not fs then
            fs = s.frame:CreateFontString(nil, "OVERLAY", "SkaldBody")
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetWordWrap(true)
            fs:SetSpacing(2)
            s.texts[n] = fs
        end
        fs:SetWidth(K.CW)
        fs:SetJustifyH("LEFT")
        fs:SetFontObject("SkaldBody")
        return fs
    end

    -- A diary entry: icon, time, text (the design's three columns).
    local itemTip   -- the tooltip of an item, made when first needed
    local function SideRow(s, n)
        local r = s.rows[n]
        if not r then
            r = {}
            r.icon = s.frame:CreateTexture(nil, "ARTWORK", nil, 3)
            r.icon:SetSize(24, 24)
            r.time = s.frame:CreateFontString(nil, "OVERLAY", "SkaldBody")
            r.time:SetWidth(40)
            r.time:SetJustifyH("LEFT")
            r.time:SetTextColor(K.C_TIME[1], K.C_TIME[2], K.C_TIME[3])
            r.text = s.frame:CreateFontString(nil, "OVERLAY", "SkaldBody")
            r.text:SetJustifyH("LEFT")
            r.text:SetJustifyV("TOP")
            r.text:SetWordWrap(true)
            r.text:SetSpacing(2)
            r.hit = CreateFrame("Button", nil, s.frame)
            r.hit:SetFrameLevel(s.frame:GetFrameLevel() + 2)
            r.hit:Hide()
            r.hit:SetScript("OnEnter", function(self)
                if type(self.link) ~= "string" and not self.entry then return end
                if not itemTip then
                    local ok, tip = pcall(CreateFrame, "GameTooltip", "SkaldItemTooltip", UIParent, "GameTooltipTemplate")
                    itemTip = (ok and tip) or GameTooltip
                end
                itemTip:SetOwner(f, "ANCHOR_NONE")
                itemTip:ClearAllPoints()
                pcall(itemTip.SetClampedToScreen, itemTip, true)
                local scale = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
                local room = (UIParent:GetRight() or 0) - (f:GetRight() or 0) * scale
                if room >= 340 then
                    itemTip:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, -50)
                elseif (f:GetLeft() or 0) * scale >= 340 then
                    itemTip:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, -50)
                else
                    itemTip:SetPoint("BOTTOM", self, "TOP", 0, 6)
                end
                if self.entry and type(self.link) ~= "string" then
                    -- A quest: a short summary (objective, reward, who gave it), not the game's whole tooltip.
                    if ns.QuestTip then pcall(ns.QuestTip, itemTip, self.entry) end
                    itemTip:Show()
                    return
                end
                local ref = self.link:match("|H(item:[^|]*)|h") or self.link
                if not pcall(itemTip.SetHyperlink, itemTip, ref) then itemTip:Hide() return end
                itemTip:Show()
            end)
            r.hit:SetScript("OnLeave", function() if itemTip then itemTip:Hide() end end)
            r.hit:SetScript("OnClick", function(self)
                if type(self.link) == "string" and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(self.link)
                end
            end)
            r.note = s.frame:CreateFontString(nil, "OVERLAY", "SkaldNote")
            r.note:SetJustifyH("LEFT")
            r.note:SetJustifyV("TOP")
            r.note:SetWordWrap(true)
            r.note:SetTextColor(K.C_NOTE[1], K.C_NOTE[2], K.C_NOTE[3])
            r.noteLine = s.frame:CreateTexture(nil, "ARTWORK", nil, 3)
            r.noteLine:SetColorTexture(0.85, 0.65, 0.10, 0.65)
            r.noteLine:SetWidth(2)
            r.flash = s.frame:CreateTexture(nil, "BACKGROUND", nil, 2)
            r.flash:SetColorTexture(0.85, 0.65, 0.10, 0.22)
            r.flash:Hide()
            r.star = CreateFrame("Button", nil, s.frame)
            r.star:SetSize(16, 16)
            r.star:SetFrameLevel(s.frame:GetFrameLevel() + 4)
            r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
            r.star.tex:SetAllPoints()
            r.star.tex:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_fav")
            r.star:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r.star:SetScript("OnClick", function(self, button)
                if not self.entry then return end
                if button == "RightButton" or (IsShiftKeyDown and IsShiftKeyDown()) then
                    ns.EditFavNote(self.entry)
                else
                    ns.ToggleFavorite(self.entry)
                end
            end)
            r.star:SetScript("OnEnter", function(self)
                self:SetAlpha(1)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine(L.FAV_TIP, 1, 0.82, 0)
                GameTooltip:AddLine(L.FAV_HINT, 1, 1, 1, true)
                if self.entry and self.entry.favNote then GameTooltip:AddLine(self.entry.favNote, 0.9, 0.9, 0.9, true) end
                GameTooltip:Show()
            end)
            r.star:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                self:SetAlpha((self.entry and self.entry.fav) and 1 or 0.22)
            end)
            r.star:Hide()
            s.rows[n] = r
        end
        return r
    end

    -- Text heights come from a hidden string of the right width.
    local meter = f:CreateFontString(nil, "OVERLAY", "SkaldBody")
    meter:SetWordWrap(true)
    meter:SetSpacing(2)
    meter:SetAlpha(0)
    local function Measure(text, width)
        meter:SetWidth(width)
        meter:SetText(text)
        return math.max(16, meter:GetStringHeight() or 16)
    end
    local meterNote = f:CreateFontString(nil, "OVERLAY", "SkaldNote")
    meterNote:SetWordWrap(true)
    meterNote:SetAlpha(0)
    local function MeasureNote(text, width)
        meterNote:SetWidth(width)
        meterNote:SetText(text)
        return math.max(18, meterNote:GetStringHeight() or 18)
    end

    -- The note at the foot of a day: ruled lines, your own words; click it to write. ----
    local editor = CreateFrame("EditBox", nil, f)
    editor:SetMultiLine(false)
    editor:SetAutoFocus(false)
    editor:SetMaxLetters(140)
    editor:SetFontObject("SkaldNote")
    editor:SetTextColor(K.C_NOTE[1], K.C_NOTE[2], K.C_NOTE[3])
    editor:SetWidth(K.CW)
    editor:SetHeight(24)
    editor:SetScript("OnTextChanged", function(self)
        for _, side in ipairs(sides) do
            if side.noteArea then side.noteArea.ph:SetShown((self:GetText() or "") == "") end
        end
    end)
    editor:SetFrameLevel(book:GetFrameLevel() + 9)
    editor:Hide()
    local editing, cancelled
    local function SaveNote()
        if not editing then return end
        local text = (editor:GetText() or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if cancelled then text = ""; cancelled = nil end
        local day = editing
        editing = nil
        editor:Hide()
        for _, side in ipairs(sides) do if side.noteArea then side.noteArea:Hide() end end
        if text ~= "" then AddNote(day, text) end
        f:Refresh()
    end
    editor:SetScript("OnEscapePressed", function(self) cancelled = true; self:ClearFocus() end)
    editor:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    editor:SetScript("OnEditFocusLost", SaveNote)

    local function SideNote(s)
        if not s.note then
            -- Writing: the inkwell becomes a ruled line on the page, and you write on it.
            local area = CreateFrame("Frame", nil, s.frame)
            area:SetSize(K.CW, 38)
            area:SetFrameLevel(book:GetFrameLevel() + 8)
            area:Hide()
            local icon = area:CreateTexture(nil, "ARTWORK")
            icon:SetSize(38, 38)
            icon:SetPoint("LEFT", 0, 0)
            icon:SetTexture(K.TEX .. "inkwell_writing_128")
            local rule = area:CreateTexture(nil, "ARTWORK")
            rule:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.45)
            rule:SetHeight(1)
            rule:SetPoint("BOTTOMLEFT", 44, 6)
            rule:SetPoint("BOTTOMRIGHT", 0, 6)
            local ph = area:CreateFontString(nil, "OVERLAY", "SkaldNote")
            ph:SetPoint("BOTTOMLEFT", 46, 8)
            ph:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.6)
            ph:SetText(L.NOTE_PLACEHOLDER)
            area.ph = ph
            s.noteArea = area

            -- The inkwell with its quill, resting on the page: the quill lifts when you reach for it.
            local b = CreateFrame("Button", nil, s.frame)
            b:SetSize(46, 46)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            b.icon:SetTexture(K.TEX .. "inkwell_idle_128")
            b:SetScript("OnEnter", function(self)
                self.icon:SetTexture(K.TEX .. "inkwell_hover_128")
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L.NOTE_BTN, 1, 1, 1)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function(self)
                self.icon:SetTexture(K.TEX .. "inkwell_idle_128")
                GameTooltip:Hide()
            end)
            b:SetScript("OnClick", function(self)
                if type(self.dayRef) ~= "table" then return end
                GameTooltip:Hide()
                editing = self.dayRef
                area:ClearAllPoints()
                area:SetPoint("BOTTOMLEFT", s.frame, "BOTTOMLEFT", self.px, 44)
                area.ph:Show()
                area:Show()
                self:Hide()
                editor:ClearAllPoints()
                editor:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 46, 7)
                editor:SetWidth(K.CW - 46)
                editor:SetText("")
                editor:Show()
                editor:SetFocus()
            end)
            s.note = b
        end
        return s.note
    end

    -- Index line: a day (or a chapter heading), clickable, with its page number at the end.
    local function SideLine(s, n)
        local b = s.lines[n]
        if not b then
            b = CreateFrame("Button", nil, s.frame)
            b:SetSize(K.CW, K.INDEX_ROW)
            b.text = b:CreateFontString(nil, "OVERLAY", "SkaldBody")
            b.text:SetJustifyH("LEFT")
            b.page = b:CreateFontString(nil, "OVERLAY", "SkaldBody")
            b.page:SetPoint("RIGHT", 0, 0)
            b.page:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
            b.leader = b:CreateTexture(nil, "ARTWORK")
            b.leader:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.4)
            b.leader:SetHeight(1)
            b.hl = b:CreateTexture(nil, "BACKGROUND")
            b.hl:SetAllPoints()
            b.hl:SetColorTexture(0.45, 0.30, 0.12, 0.15)
            b.hl:Hide()
            b:SetScript("OnEnter", function(self) if type(self.target) == "number" then self.hl:Show() end end)
            b:SetScript("OnLeave", function(self) self.hl:Hide() end)
            b:SetScript("OnClick", function(self)
                if type(self.target) == "number" then f:GoToPage(self.target) end
            end)
            s.lines[n] = b
        end
        return b
    end

    -- The cover, left: an arched alcove with your 3D character, name, level and class. ---
    local cover1 = sides[1].cover
    local modelHolder = CreateFrame("Frame", nil, cover1)
    modelHolder:SetSize(288, 344)
    modelHolder:SetPoint("TOPLEFT", (K.PAGE_SW - 288) / 2, -64)
    -- The portrait (used while the character is a spirit) sits in a dark round medallion, so the
    -- black behind a portrait reads as part of the frame.
    local medal = {}
    do
        local okDisc, ring = pcall(function() return SkaldAPI.MakeDisc(modelHolder, "BACKGROUND", 206, 0.30, 0.17, 0.08, 1) end)
        if okDisc and ring then
            ring:SetPoint("CENTER")
            local inner = SkaldAPI.MakeDisc(modelHolder, "BACKGROUND", 194, 0.07, 0.04, 0.025, 2)
            inner:SetPoint("CENTER")
            medal = { ring, inner }
        end
    end
    local portrait = modelHolder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("CENTER")
    portrait:SetSize(186, 186)
    local okModel, model = pcall(CreateFrame, "PlayerModel", nil, modelHolder)
    if okModel and model then
        model:SetAllPoints()
        local dragging, lastX
        -- The character stands still, facing the reader; hold the left button and drag to turn it.
        model.skaldAngle = 0
        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then dragging, lastX = true, GetCursorPosition() end
        end)
        model:SetScript("OnMouseUp", function() dragging = false end)
        model:SetScript("OnUpdate", function(self)
            if dragging then
                local x = GetCursorPosition()
                self.skaldAngle = ((self.skaldAngle or 0) + (x - (lastX or x)) * 0.012) % (math.pi * 2)
                lastX = x
                pcall(self.SetFacing, self, self.skaldAngle)
            end
        end)
    end
    local alcove = CreateFrame("Frame", nil, cover1)
    alcove:SetFrameLevel(modelHolder:GetFrameLevel() + 5)
    alcove:SetSize(316, 372)
    alcove:SetPoint("TOPLEFT", (K.PAGE_SW - 316) / 2, -48)
    local alcoveTex = alcove:CreateTexture(nil, "OVERLAY")
    alcoveTex:SetAllPoints()
    alcoveTex:SetTexture(K.TEX .. "alcove")
    alcoveTex:SetTexCoord(0, 316 / 512, 0, 372 / 512)
    local function ShowModel()
        local works = false
        -- The third argument asks for the character in its native form: not as a spirit, and not as
        -- the bear or the cat of a druid. (Where the game ignores it, the model is what it always was.)
        if okModel and model and pcall(model.SetUnit, model, "player", false, true) then
            pcall(model.SetCamDistanceScale, model, 0.8)
            model.skaldAngle = 0
            pcall(model.SetFacing, model, 0)
            works = true
        end
        if model then model:SetShown(works) end
        portrait:SetShown(not works)
        for _, t in ipairs(medal) do t:SetShown(not works) end
        if not works then pcall(SetPortraitTexture, portrait, "player") end
    end
    local coverTitle = cover1:CreateFontString(nil, "OVERLAY", "SkaldHead")
    coverTitle:SetPoint("TOP", 0, -428)
    coverTitle:SetWidth(K.PAGE_SW - 20)
    coverTitle:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
    local coverRule = cover1:CreateTexture(nil, "ARTWORK")
    coverRule:SetSize(130, 11)
    coverRule:SetPoint("TOP", coverTitle, "BOTTOM", 0, -4)
    coverRule:SetTexture(K.TEX .. "rule")
    coverRule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    local coverLevel = cover1:CreateFontString(nil, "OVERLAY", "SkaldBody")
    coverLevel:SetPoint("TOP", coverRule, "BOTTOM", 0, -4)
    coverLevel:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])

    -- The cover, right: the journey in numbers and the quests by rarity. -----------------
    local stats = sides[2].cover
    local function JText(parent, font, x, y, justify, width)
        local fs = parent:CreateFontString(nil, "OVERLAY", font or "SkaldBody")
        fs:SetPoint(justify == "RIGHT" and "TOPRIGHT" or "TOPLEFT", x, y)
        fs:SetJustifyH(justify or "LEFT")
        if width then fs:SetWidth(width) end
        fs:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        return fs
    end
    local RX = sides[2].padL
    local journeyTitle = stats:CreateFontString(nil, "OVERLAY", "SkaldHead")
    journeyTitle:SetPoint("TOP", 3, -50)
    journeyTitle:SetWidth(K.CW)
    journeyTitle:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
    journeyTitle:SetText(L.S_HEADER)
    local journeyRule = stats:CreateTexture(nil, "ARTWORK")
    journeyRule:SetSize(130, 11)
    journeyRule:SetPoint("TOP", 3, -78)
    journeyRule:SetTexture(K.TEX .. "rule")
    journeyRule:SetTexCoord(0, 160 / 256, 0, 14 / 16)

    local FACTS = {
        { key = "zones",        label = L.S_ZONES,        icon = "ev_zone" },
        { key = "quests",       label = L.S_QUESTS,       icon = "ev_quest" },
        { key = "levels",       label = L.S_LEVELS,       icon = "ev_level" },
        { key = "deaths",       label = L.S_DEATHS,       icon = "ev_death" },
        { key = "dungeons",     label = L.S_DUNGEONS,     icon = "ev_dungeon" },
        { key = "kills",        label = L.S_KILLS_EST,    icon = "ev_party" },
        { key = "bosses",       label = L.S_BOSSES,       icon = "ev_boss" },
        { key = "gold",         label = L.S_GOLD,         icon = "st_gold" },
        { key = "topkind",      label = L.S_TOPKIND,      icon = "st_topkind" },
        { key = "flights",      label = L.S_FLIGHTS,      icon = "st_flight" },
        { key = "camps",        label = L.S_CAMPS,        icon = "st_camp" },
    }
    local FACT_H = 22
    local factValues, factLabels = {}, {}
    for i, fact in ipairs(FACTS) do
        local y = -98 - (i - 1) * FACT_H
        local icon = stats:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("TOPLEFT", RX, y)
        fact.region = icon
        icon:SetTexture(fact.icon:find("\\", 1, true) and fact.icon or ("Interface\\AddOns\\Skald\\Textures\\" .. fact.icon))
        factLabels[fact.key] = JText(stats, "SkaldBody", RX + 32, y - 4)
        factLabels[fact.key]:SetText(fact.label)
        factValues[fact.key] = JText(stats, "SkaldBody", 0, y - 4, "RIGHT")
        factValues[fact.key]:ClearAllPoints()
        factValues[fact.key]:SetPoint("TOPRIGHT", -30, y - 4)
        factValues[fact.key]:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
        local leader = stats:CreateTexture(nil, "ARTWORK")
        leader:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.4)
        leader:SetHeight(1)
        leader:SetPoint("BOTTOMLEFT", factLabels[fact.key], "BOTTOMRIGHT", 6, 3)
        leader:SetPoint("BOTTOMRIGHT", factValues[fact.key], "BOTTOMLEFT", -6, 3)
    end

    local rarityTop = -98 - #FACTS * FACT_H - 14
    local rarityRule = stats:CreateTexture(nil, "ARTWORK")
    rarityRule:SetSize(110, 9)
    rarityRule:SetPoint("TOP", 3, rarityTop)
    rarityRule:SetTexture(K.TEX .. "rule")
    rarityRule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    local rarityCounts = {}
    for tier = 0, 5 do
        local cell = CreateFrame("Frame", nil, stats)
        cell:SetSize(57, 60)
        cell:SetPoint("TOPLEFT", RX + tier * 57, rarityTop - 14)
        cell:EnableMouse(true)
        local seal = cell:CreateTexture(nil, "ARTWORK")
        seal:SetSize(38, 38)
        seal:SetPoint("TOP", 0, 0)
        seal:SetTexture(K.SEAL_PATH .. tier)
        local count = cell:CreateFontString(nil, "OVERLAY", "SkaldBody")
        count:SetPoint("TOP", seal, "BOTTOM", 0, -2)
        local ink = K.TIER_INK[tier]
        count:SetTextColor(ink[1], ink[2], ink[3])
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.TIERS[tier] or tostring(tier))
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rarityCounts[tier] = count
    end
    local footerPlayed = JText(stats, "SkaldBody", RX, rarityTop - 80)
    local footerFirst = JText(stats, "SkaldBody", RX, rarityTop - 98)
    footerPlayed:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
    footerFirst:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])

    local function UpdateCover()
        local db = Journal()
        local s = db.stats
        local played = s.played + (loginTime and (time() - loginTime) or 0)
        local values = {
            zones = (db.visitedMaps and CountKeys(db.visitedMaps) > 0) and CountKeys(db.visitedMaps) or CountKeys(db.visited),
            quests = s.counts.quest or 0,
            levels = (s.counts.level or 0) + (s.counts.milestone or 0),
            deaths = s.counts.death or 0,
            dungeons = s.counts.dungeon or 0,
            kills = s.counts.kill or 0,
            bosses = s.counts.boss or 0,
            gold = StatText(328) or L.S_NONE,
            topkind = StatText(1336) or L.S_NONE,
            flights = GameStat(349) or 0,
            camps = GameStat(64222) or 0,
        }
        -- Creatures: found by its name, or by its id in the Forever client (107) when the name is unknown.
        local exactKills = KillStat()
        if not exactKills then
            local byId = GameStat(107)
            if byId and byId > 0 then exactKills = byId end
        end
        values.kills = exactKills or values.kills
        -- The flights row shows the mount of your faction's flight masters: gryphon or wyvern.
        local okFaction, faction = pcall(UnitFactionGroup, "player")
        local flightIcon = (okFaction and faction == "Alliance" and "st_flight_alliance")
            or (okFaction and faction == "Horde" and "st_flight_horde") or "st_flight"
        for _, fact in ipairs(FACTS) do
            if fact.key == "flights" and fact.region then
                fact.region:SetTexture("Interface\\AddOns\\Skald\\Textures\\" .. flightIcon)
            end
        end
        -- The game's own totals where they can be read (the diary's count stays as the fallback).
        values.quests = GameStat(K.STAT_QUESTS) or values.quests
        values.deaths = GameStat(K.STAT_DEATHS) or values.deaths
        values.dungeons = GameStat(K.STAT_DUNGEONS) or values.dungeons
        values.bosses = BossWins() or values.bosses
        local level = UnitLevel and UnitLevel("player")
        if type(level) == "number" and level >= 1 then values.levels = level - 1 end
        factLabels.kills:SetText(exactKills and L.S_KILLS or L.S_KILLS_EST)
        for key, fs in pairs(factValues) do fs:SetText(tostring(values[key])) end
        for tier, fs in pairs(rarityCounts) do fs:SetText(tostring((s.tiers and s.tiers[tier]) or 0)) end
        footerPlayed:SetText(L.S_PLAYED .. ": " .. FormatDuration(played))
        footerFirst:SetText(L.S_FIRST .. ": " .. (s.first and date(L.DATE_FMT, s.first) or L.S_NONE))

        ShowModel()
        local custom = SkaldDB and SkaldDB.coverTitle
        coverTitle:SetText((type(custom) == "string" and custom ~= "") and custom or string.format(L.COVER_TITLE, UnitName("player") or "?"))
        local className = UnitClass and select(1, UnitClass("player")) or ""
        coverLevel:SetText(string.format(L.COVER_LEVEL, UnitLevel("player") or 1, className or ""))
    end

    -- Layout -------------------------------------------------------------------------
    local view = "book"          -- "book" or the id of a tab panel
    local spread = 1
    local layout                 -- { days, pages, indexPages, firstDayPage }

    -- Which pages exist: 1-2 cover, the contents, then the days (each from a new page).
    local function Paginate()
        local days = BuildDays()
        local perPage = math.floor((K.PAGE_H - 50) / K.INDEX_ROW)
        local rows, lastChapter = {}, nil
        local placeCount = {}
        for _, day in ipairs(days) do
            local place = KnownZone(day.zone)
            if place then
                local ch = Chapter(day.level)
                placeCount[ch] = placeCount[ch] or {}
                placeCount[ch][place] = (placeCount[ch][place] or 0) + 1
            end
        end
        local function Dominant(ch)
            local best, bestN
            for place, n in pairs(placeCount[ch] or {}) do
                if not bestN or n > bestN or (n == bestN and place < best) then best, bestN = place, n end
            end
            return best
        end
        for _, day in ipairs(days) do
            local ch = Chapter(day.level)
            if ch ~= lastChapter then
                rows[#rows + 1] = { chapter = ch, place = Dominant(ch) }
                lastChapter = ch
            end
            rows[#rows + 1] = { day = day }
        end
        local indexPages = math.max(2, math.ceil(math.max(1, #rows) / perPage))
        if indexPages % 2 == 1 then indexPages = indexPages + 1 end   -- the days start on a left page
        local entryPage = {}
        local pages = { { type = "coverL" }, { type = "coverR" } }
        for i = 1, indexPages do
            local chunk = {}
            for r = (i - 1) * perPage + 1, math.min(#rows, i * perPage) do chunk[#chunk + 1] = rows[r] end
            pages[#pages + 1] = { type = "index", rows = chunk, first = (i == 1), label = RomanLower(i) }
        end

        local firstDayPage = #pages + 1
        for _, day in ipairs(days) do
            day.page = #pages + 1
            day.label = day.page - firstDayPage + 1
            local blocks, lastZone = {}, nil
            for _, e in ipairs(day.entries) do
                local isQuest = e.kind == "quest" and e.tier
                local ink
                if isQuest and e.tier >= 2 then
                    ink = K.TIER_INK[e.tier]
                elseif e.kind == "death" then
                    ink = K.INK.death
                else
                    ink = K.INKS[((SkaldDB and SkaldDB.ink) or 0) + 1] or K.INKS[1]
                end
                local head = ""
                if e.kind ~= "note" and ns.PlaceName(e) ~= lastZone then
                    local place = ns.PlaceName(e)
                    if KnownZone(place) then head = Hex(K.C_MUTED) .. ZoneIconTag(e.m) .. place .. "|r" end
                    lastZone = place
                end
                if isQuest and e.tier >= 2 and L.TIERS[e.tier] then
                    head = head .. (head ~= "" and "  -  " or "") .. Hex(ink) .. L.TIERS[e.tier] .. "|r"
                end
                local text = RenderEntry(e)
                if e.kind == "loot" then text = text:gsub("|r", "|r" .. Hex(ink)) end
                local body = Hex(ink) .. text .. "|r"
                blocks[#blocks + 1] = {
                    text = (head ~= "" and (head .. "\n") or "") .. body,
                    time = date("%H:%M", e.t),
                    link = (e.kind == "loot" and type(e.arg) == "string") and e.arg or nil,
                    quest = (e.kind == "quest") and e or nil,
                    entry = e,
                    note = (e.fav and e.favNote) or nil,
                    icon = (e.kind == "loot" and ItemIcon(e)) or (e.kind == "note" and (K.TEX .. "quill")) or (isQuest and (K.SEAL_PATH .. e.tier)) or EventIconPath(e.kind, e),
                }
            end
            if day.summary then
                blocks[#blocks + 1] = { text = Hex(K.C_HEAD) .. RenderEntry(day.summary) .. "|r", closing = true }
            end

            local page = { type = "day", day = day, blocks = {}, first = true }
            local y = 70
            pages[#pages + 1] = page
            for i, block in ipairs(blocks) do
                local mainH = Measure(block.text, block.closing and (K.CW - 32) or (K.CW - K.ENTRY_X - 22))
                local noteH = block.note and MeasureNote(block.note, K.CW - K.ENTRY_X - 22 - 16) or 0
                block.mainH = mainH
                block.noteH = noteH
                block.h = math.max(24, mainH + (noteH > 0 and (noteH + 6) or 0))
                local limit = K.PAGE_H - ((i == #blocks) and K.NOTE_BTN_H or 0)
                if y + block.h > limit and #page.blocks > 0 then
                    page = { type = "day", day = day, blocks = {}, first = false }
                    pages[#pages + 1] = page
                    y = 40
                end
                page.blocks[#page.blocks + 1] = block
                if block.entry then entryPage[block.entry] = #pages end
                y = y + block.h + K.GAP
            end
            page.note = true
        end
        if #pages % 2 == 1 then pages[#pages + 1] = { type = "blank" } end
        return { days = days, pages = pages, indexPages = indexPages, firstDayPage = firstDayPage, entryPage = entryPage }
    end

    -- Paginating measures every line of every page, so the result is kept until something it depends
    -- on changes: the pages themselves, the ink, the text size, how days are cut, or ns.layoutRev (bumped
    -- when old pages are rewritten, e.g. brought to a new language).
    local cachedSig, cachedLayout
    local function Layout()
        local entries = Journal().entries
        local last = entries[#entries]
        local sig = table.concat({ #entries, last and last.t or 0, last and last.kind or "", (SkaldDB and SkaldDB.ink) or 0,
            (SkaldDB and SkaldDB.textSize) or 1, (SkaldDB and SkaldDB.dayMode) or 0, ns.layoutRev or 0 }, ":")
        if sig ~= cachedSig then
            cachedLayout = Paginate()
            cachedSig = sig
        end
        return cachedLayout
    end

    local function Clear(s)
        for _, fs in pairs(s.texts) do fs:Hide() end
        for _, r in pairs(s.rows) do r.icon:Hide(); r.time:Hide(); r.text:Hide(); r.hit:Hide(); r.star:Hide(); r.flash:Hide(); r.note:Hide(); r.noteLine:Hide() end
        for _, b in pairs(s.lines) do b:Hide() end
        if s.note then s.note:Hide() end
        if s.noteArea and not editing then s.noteArea:Hide() end
        if s.closeIcon then s.closeIcon:Hide() end
        if s.closeLine then s.closeLine:Hide() end
        s.cover:Hide()
        s.sub:Hide()
        s.rule:Hide()
        s.line:Hide()
        s.quill:Hide()
        s.num:SetText("")
    end

    local function DrawPage(s, page, number)
        Clear(s)
        if not page then return end
        s.hl:SetText(Upper(UnitName("player")))
        if page.type == "index" then
            s.hr:SetText(Upper(L.INDEX_TITLE))
        elseif page.type == "day" then
            s.hr:SetText(Upper(L.CHAPTERS[Chapter(page.day.level)]))
        else
            s.hr:SetText("SKALD")
        end
        if page.type == "coverL" or page.type == "coverR" then
            s.cover:Show()
            return
        end
        if page.type == "blank" then return end
        s.num:SetText(Hex(K.C_MUTED) .. tostring(number) .. "|r")
        s.quill:Show()
        local px = s.padL

        local function Heading(text, y, font)
            local head = SideText(s, 1)
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", px, -y)
            head:SetFontObject(font or "SkaldHead")
            head:SetJustifyH("CENTER")
            head:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
            head:SetText(text)
            head:Show()
            return head
        end

        if page.type == "index" then
            local y = K.TOP_Y + 4
            if page.first then
                Heading(L.INDEX_TITLE, K.TOP_Y + 4)
                Rule(s, K.TOP_Y + 32)
                y = K.TOP_Y + 56
            end
            for n, row in ipairs(page.rows) do
                local b = SideLine(s, n)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", px, -y)
                b.text:ClearAllPoints()
                if row.chapter then
                    b.target = nil
                    b.text:SetPoint("LEFT", 0, 0)
                    b.text:SetFontObject("SkaldSec")
                    b.text:SetText(Hex(K.C_SEC) .. string.format(L.CHAPTER_HEADER, K.ROMAN[row.chapter] or row.chapter,
                        L.CHAPTERS[row.chapter]) .. (row.place and ("  -  " .. row.place) or "") .. "|r")
                    b.page:SetText("")
                    b.leader:Hide()
                else
                    b.target = row.day.page
                    b.text:SetPoint("LEFT", 18, 0)
                    b.text:SetFontObject("SkaldBody")
                    b.text:SetText(Hex(K.C_BODY) .. (DayTitle(row.day, row.day.number):gsub(":", " -", 1)) .. "|r")
                    b.page:SetText(tostring(row.day.label))
                    b.leader:ClearAllPoints()
                    b.leader:SetPoint("BOTTOMLEFT", b.text, "BOTTOMRIGHT", 6, 5)
                    b.leader:SetPoint("BOTTOMRIGHT", b.page, "BOTTOMLEFT", -6, 5)
                    b.leader:Show()
                end
                b:Show()
                y = y + K.INDEX_ROW
            end
            return
        end

        -- A day.
        local day = page.day
        s.num:SetText(Hex(K.C_MUTED) .. tostring(number - layout.firstDayPage + 1) .. "|r")
        local y
        if page.first then
            Heading(DayTitle(day, day.number), K.TOP_Y, "SkaldHead2")
            local sub = s.sub
            sub:ClearAllPoints()
            sub:SetPoint("TOPLEFT", px, -(K.TOP_Y + 28))
            sub:SetTextColor(1, 1, 1)
            local where = KnownZone(day.zone)
            sub:SetText(string.format("|T%ssun:18:18:0:0:64:64:0:48:0:48|t %s%s%s|r", K.TEX, Hex(K.C_MUTED),
                date(L.DAY_DATE, day.t), where and ("  -  " .. where) or ""))
            sub:Show()
            Rule(s, K.TOP_Y + 52)
            y = 70
        else
            Heading(string.format(L.CONTINUED, day.number), K.TOP_Y, "SkaldHead2")
            y = 40
        end
        local n = 0
        for _, block in ipairs(page.blocks) do
            local top = K.TOP_Y + y
            if block.closing then
                if not s.closeLine then
                    s.closeLine = s.frame:CreateTexture(nil, "ARTWORK", nil, 3)
                    s.closeLine:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.3)
                    s.closeLine:SetHeight(1)
                    s.closeIcon = s.frame:CreateTexture(nil, "ARTWORK", nil, 3)
                    s.closeIcon:SetSize(24, 24)
                    s.closeIcon:SetTexture(K.TEX .. "moon")
                    s.closeIcon:SetTexCoord(0, 48 / 64, 0, 48 / 64)
                end
                s.closeLine:ClearAllPoints()
                s.closeLine:SetPoint("TOPLEFT", px, -(top - 6))
                s.closeLine:SetPoint("TOPRIGHT", s.frame, "TOPLEFT", px + K.CW, -(top - 6))
                s.closeLine:Show()
                s.closeIcon:ClearAllPoints()
                s.closeIcon:SetPoint("TOPLEFT", px, -top)
                s.closeIcon:Show()
                n = n + 1
                local fs = SideText(s, 2 + n)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", px + 32, -top)
                fs:SetWidth(K.CW - 32)
                fs:SetTextColor(1, 1, 1)
                fs:SetText(block.text)
                fs:Show()
            else
                n = n + 1
                local r = SideRow(s, n)
                r.icon:ClearAllPoints()
                r.icon:SetPoint("TOPLEFT", px, -top)
                r.icon:SetTexture(block.icon)
                r.icon:Show()
                r.time:ClearAllPoints()
                r.time:SetPoint("TOPLEFT", px + 32, -(top + 2))
                r.time:SetText(block.time)
                r.time:Show()
                r.text:ClearAllPoints()
                r.text:SetPoint("TOPLEFT", px + K.ENTRY_X, -(top + 2))
                r.text:SetWidth(K.CW - K.ENTRY_X - 22)
                r.text:SetText(block.text)
                r.text:Show()
                r.hit:ClearAllPoints()
                r.hit:SetPoint("TOPLEFT", px, -top)
                r.hit:SetSize(K.CW, block.h)
                r.hit.link = block.link
                r.hit.entry = block.quest
                r.hit:SetShown(block.link ~= nil or block.quest ~= nil)
                r.star.entry = block.entry
                r.star:ClearAllPoints()
                r.star:SetPoint("TOPRIGHT", s.frame, "TOPLEFT", px + K.CW, -(top + 3))
                r.star:SetAlpha((block.entry and block.entry.fav) and 1 or 0.22)
                r.star:SetShown(block.entry ~= nil)
                r.flash:ClearAllPoints()
                r.flash:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px - 4, -(top - 2))
                r.flash:SetSize(K.CW + 8, block.h + 4)
                r.flash:SetShown(block.entry ~= nil and block.entry == f.flashEntry)
                if block.note then
                    local noteTop = top + 2 + (block.mainH or 0) + 4
                    r.note:ClearAllPoints()
                    r.note:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px + K.ENTRY_X + 14, -noteTop)
                    r.note:SetWidth(K.CW - K.ENTRY_X - 22 - 16)
                    r.note:SetText(block.note)
                    r.note:Show()
                    r.noteLine:ClearAllPoints()
                    r.noteLine:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px + K.ENTRY_X + 4, -(noteTop + 1))
                    r.noteLine:SetHeight(math.max(14, block.noteH or 16))
                    r.noteLine:Show()
                else
                    r.note:Hide()
                    r.noteLine:Hide()
                end
            end
            y = y + block.h + K.GAP
        end
        if page.note then
            local b = SideNote(s)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", s.frame, "BOTTOMLEFT", px - 4, 40)
            b.dayRef = day
            b.px = px
            b:Show()
        end
    end

    -- Sections: which tab is lit follows where the book is open.
    local function SectionOf(sp)
        if sp == 1 then return "cover" end
        if layout and sp * 2 - 1 >= layout.firstDayPage then return "days" end
        return "index"
    end

    -- Tabs: one grey leather tab texture, tinted, poking out behind the left edge. -------
    local tabs = {}
    local function MakeTab(id, label, order)
        local b = CreateFrame("Button", nil, f)
        b:SetFrameLevel(f:GetFrameLevel() + 2)
        b:SetSize(112, 34)
        b.top = -(86 + (order - 1) * 40)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexture(K.TEX .. "tab")
        b.tex:SetTexCoord(0, 112 / 128, 0, 34 / 64)
        b.text = b:CreateFontString(nil, "OVERLAY", "SkaldBody")
        b.text:SetPoint("LEFT", 17, 0)
        b.text:SetText(label)
        function b:SetActive(active)
            self.active = active and true or false
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", f, "TOPLEFT", self.active and 0 or 12, self.top)
            local c = self.active and K.TAB_ON or K.TAB_OFF
            self.tex:SetVertexColor(c[1], c[2], c[3])
            if self.active then self.text:SetTextColor(0.14, 0.08, 0.04) else self.text:SetTextColor(0.92, 0.86, 0.72) end
        end
        b:SetActive(false)
        b:SetScript("OnClick", function() f:ShowSection(id) end)
        tabs[id] = b
        return b
    end
    MakeTab("cover", L.SEC_COVER, 1)
    MakeTab("index", L.SEC_INDEX, 2)
    MakeTab("days", L.SEC_DAYS, 3)

    local panels, panelOrder = {}, {}
    function f:AddTab(id, label, build)
        if panels[id] then return panels[id].frame end
        local button = MakeTab(id, label, 4 + #panelOrder)
        local panel = CreateFrame("Frame", nil, book)
        panel:SetFrameLevel(book:GetFrameLevel() + 5)
        panel:SetPoint("TOPLEFT", f, "TOPLEFT", K.PAGE_XS[1] + 30, -(K.PAGE_Y + K.TOP_Y))
        panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -54, 70)
        panel:Hide()
        local entry = { button = button, frame = panel }
        panels[id] = entry
        panelOrder[#panelOrder + 1] = id
        local ok, refresh = pcall(build, panel)
        if ok and type(refresh) == "function" then entry.refresh = refresh end
        return panel
    end

    -- Page corners turn the pages. -----------------------------------------------------
    local function MakeCurl(i)
        local b = CreateFrame("Button", nil, book)
        b:SetFrameLevel(book:GetFrameLevel() + 6)
        b:SetSize(56, 56)
        b:SetPoint(i == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", f, "TOPLEFT",
            i == 1 and K.PAGE_XS[1] or (K.PAGE_XS[2] + K.PAGE_SW), -(K.PAGE_Y + K.PAGE_SH))
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexture(K.TEX .. "curl")
        if i == 1 then b.tex:SetTexCoord(56 / 64, 0, 0, 56 / 64) else b.tex:SetTexCoord(0, 56 / 64, 0, 56 / 64) end
        b:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1.15, 1.15, 1.15) end)
        b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1) end)
        return b
    end
    local prevButton = MakeCurl(1)
    prevButton.isPrev = true
    local nextButton = MakeCurl(2)
    nextButton.isNext = true

    -- The clasp over the spine.
    local clasp = book:CreateTexture(nil, "OVERLAY", nil, 2)
    clasp:SetSize(26, 64)
    clasp:SetPoint("TOPLEFT", K.PAGE_XS[1] + K.PAGE_SW + 1, -258)
    clasp:SetTexture(K.TEX .. "clasp")
    clasp:SetTexCoord(0, 26 / 32, 0, 1)

    local function SpreadCount() return layout and math.floor(#layout.pages / 2) or 1 end

    -- "Today": back to the newest day, at the foot of the right page, only when you are away.
    local todayButton = CreateFrame("Button", nil, book)
    todayButton:SetFrameLevel(book:GetFrameLevel() + 6)
    todayButton:SetSize(70, 24)
    todayButton:SetPoint("TOPLEFT", f, "TOPLEFT", K.PAGE_XS[2] + K.PAGE_SW - 132, -(K.PAGE_Y + K.PAGE_SH - 38))
    todayButton.text = todayButton:CreateFontString(nil, "OVERLAY", "SkaldBody")
    todayButton.text:SetPoint("RIGHT", 0, 0)
    todayButton.text:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
    todayButton.text:SetText(L.TODAY)
    todayButton:SetScript("OnEnter", function(self) self.text:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3]) end)
    todayButton:SetScript("OnLeave", function(self) self.text:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3]) end)
    todayButton:SetScript("OnClick", function() f:ShowSection("days") end)
    todayButton:Hide()

    function f:Refresh()
        if not Journal() then return end
        for _, p in pairs(panels) do p.frame:Hide() end
        local showBook = panels[view] == nil
        for _, s in ipairs(sides) do s.frame:Show() end
        prevButton:SetShown(showBook)
        nextButton:SetShown(showBook)
        if not showBook then todayButton:Hide() end
        if showBook then
            layout = Layout()
            local count = SpreadCount()
            spread = math.max(1, math.min(spread, count))
            UpdateCover()
            local lp, rp = layout.pages[spread * 2 - 1], layout.pages[spread * 2]
            DrawPage(sides[1], lp, spread * 2 - 1)
            DrawPage(sides[2], rp, spread * 2)
            -- Front matter is numbered i, ii, iii; the days from 1.
            for i, page in ipairs({ lp or false, rp or false }) do
                if page and page.type == "index" then
                    sides[i].num:SetText(Hex(K.C_MUTED) .. page.label .. "|r")
                end
            end
            local newest
            for i, p in ipairs(layout.pages) do if p.type == "day" then newest = math.floor((i + 1) / 2) end end
            todayButton:SetShown(newest ~= nil and spread ~= newest)
            prevButton:SetEnabled(spread > 1)
            nextButton:SetEnabled(spread < count)
            prevButton:SetAlpha(spread > 1 and 1 or 0.35)
            nextButton:SetAlpha(spread < count and 1 or 0.35)
        else
            for _, s in ipairs(sides) do Clear(s) end
            panels[view].frame:Show()
            if panels[view].refresh then pcall(panels[view].refresh) end
        end
        local current = showBook and SectionOf(spread) or view
        for id, t in pairs(tabs) do t:SetActive(id == current) end
    end

    -- The colour of the leather: a tint over the cover, chosen in the Style tab.
    local COVER_TINT = {
        brown = { 1, 1, 1 }, blue = { 0.55, 0.68, 1 }, green = { 0.62, 0.95, 0.62 },
        wine = { 1, 0.55, 0.58 }, grey = { 0.72, 0.74, 0.82 },
    }
    function f:ApplyCover()
        local choice = (SkaldDB and SkaldDB.cover) or "brown"
        if choice == "faction" then
            local okFaction, faction = pcall(UnitFactionGroup, "player")
            choice = (okFaction and faction == "Horde") and "wine" or (okFaction and faction == "Alliance") and "blue" or "brown"
        end
        local c = COVER_TINT[choice] or COVER_TINT.brown
        for _, part in ipairs(coverParts) do part:SetVertexColor(c[1], c[2], c[3]) end
        f:Refresh()
    end

    -- Layout audit (/skald qa): walks every spread and every tab and measures what is on screen:
    -- text that runs past its width or into the foot of a page, text across the gutter, lines that
    -- overlap, a missing font. The report is kept in SkaldDB.qa (read it after /reload).
    function f:QA()
        local issues = {}
        local function Issue(where, what) issues[#issues + 1] = where .. ": " .. what end
        local savedView, savedSpread = view, spread

        local function Rect(r)
            local l, rt, tp, bt = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
            if l and rt and tp and bt then return l, rt, tp, bt end
        end
        local function Name(fs)
            local text = fs.GetText and fs:GetText() or ""
            text = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
            return '"' .. text:sub(1, 36) .. '"'
        end
        local function Walk(frame, visit)
            for _, region in ipairs({ frame:GetRegions() }) do visit(region) end
            for _, child in ipairs({ frame:GetChildren() }) do
                if child:IsShown() then Walk(child, visit) end
            end
        end

        -- fonts
        for _, name in ipairs({ "SkaldBody", "SkaldHead", "SkaldNote", "SkaldSec" }) do
            local font = _G[name]
            local path = font and font.GetFont and font:GetFont()
            if type(path) == "string" and not path:lower():find("skald", 1, true) then
                Issue("fonts", name .. " uses the game's font (" .. path .. "): the bundled font did not load")
            end
        end

        -- the pages
        view = "book"
        layout = Layout()
        for sp = 1, SpreadCount() do
            spread = sp
            f:Refresh()
            for i, s in ipairs(sides) do
                local where = "spread " .. sp .. (i == 1 and " left" or " right")
                local fl, fr, _, fb = Rect(s.frame)
                if fl then
                    local seen = {}
                    Walk(s.frame, function(r)
                        if r.GetStringWidth and r:IsShown() and r ~= s.num and r ~= s.sub then
                            local text = r:GetText()
                            if text and text ~= "" then
                                local l, rt, tp, bt = Rect(r)
                                if l then
                                    if rt > fr + 1 or l < fl - 1 then Issue(where, Name(r) .. " sticks out of the page") end
                                    if bt < fb + 40 and not (s.note and s.note:IsShown()) then
                                        Issue(where, Name(r) .. " runs into the foot of the page")
                                    end
                                    -- A line that cannot wrap and is wider than its box is cut off.
                                    if not r:CanWordWrap() and (r:GetWidth() or 0) > 0 and (r:GetStringWidth() or 0) > r:GetWidth() + 1 then
                                        Issue(where, Name(r) .. " is wider than its box (cut off?)")
                                    end
                                    seen[#seen + 1] = { r = r, l = l, rt = rt, tp = tp, bt = bt }
                                end
                            end
                        end
                    end)
                    -- two texts drawn over each other
                    for a = 1, #seen do
                        for b = a + 1, #seen do
                            local A, B = seen[a], seen[b]
                            local overlapX = math.min(A.rt, B.rt) - math.max(A.l, B.l)
                            local overlapY = math.min(A.tp, B.tp) - math.max(A.bt, B.bt)
                            if overlapX > 4 and overlapY > 4 then
                                Issue(where, Name(A.r) .. " overlaps " .. Name(B.r))
                            end
                        end
                    end
                end
            end
        end

        -- the tabs (Options, Style, Map): inside their page, never across the gutter
        for id, p in pairs(panels) do
            view = id
            f:Refresh()
            local pl, _, _, pb = Rect(p.frame)
            if pl then
                local gutterLeft = pl + K.CW
                local rightPageLeft = pl + (SkaldAPI.RIGHT_X or 0)
                Walk(p.frame, function(r)
                    if r.GetStringWidth and r:IsShown() then
                        local text = r:GetText()
                        local l, rt, _, bt = Rect(r)
                        if text and text ~= "" and l then
                            local w = r:GetStringWidth() or 0
                            local right = math.min(rt, l + math.max(w, 1))
                            if l < gutterLeft - 2 and right > gutterLeft + 2 then
                                Issue("tab " .. id, Name(r) .. " crosses the gutter")
                            end
                            if bt < pb - 2 then Issue("tab " .. id, Name(r) .. " runs below the page") end
                            if right > rightPageLeft + K.CW + 2 then Issue("tab " .. id, Name(r) .. " sticks out on the right") end
                        end
                    end
                end)
            end
        end

        view, spread = savedView, savedSpread
        f:Refresh()
        SkaldDB.qa = { when = date("%Y-%m-%d %H:%M"), count = #issues, issues = issues }
        return issues
    end

    -- Opens the book at the page of one entry and lights its row for a moment (used by the map pins).
    function f:GetView() return view end

    function f:OpenEntry(e)
        view = "book"
        layout = Layout()
        local page = layout.entryPage and layout.entryPage[e]
        if not page then return false end
        spread = math.floor((page + 1) / 2)
        f.flashEntry = e
        f:Refresh()
        f:Show()
        C_Timer.After(2.5, function()
            if f.flashEntry == e then f.flashEntry = nil; if f:IsShown() then f:Refresh() end end
        end)
        return true
    end

    function f:GoToPage(page)
        view = "book"
        spread = math.floor((page + 1) / 2)
        TurnSound()
        f:Refresh()
    end

    function f:ShowSection(id, quiet)
        if not quiet then TurnSound() end
        if panels[id] then
            view = id
            f:Refresh()
            return
        end
        view = "book"
        layout = Layout()
        if id == "cover" then
            spread = 1
        elseif id == "index" then
            spread = 2
        else
            -- The newest day, on its last page.
            local last
            for i, p in ipairs(layout.pages) do if p.type == "day" then last = i end end
            spread = last and math.floor((last + 1) / 2) or 2
        end
        f:Refresh()
    end

    prevButton:SetScript("OnClick", function() view = "book"; spread = spread - 1; TurnSound(); f:Refresh() end)
    nextButton:SetScript("OnClick", function() view = "book"; spread = spread + 1; TurnSound(); f:Refresh() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if panels[view] then return end
        local before = spread
        spread = math.max(1, math.min(spread - delta, SpreadCount()))
        if spread ~= before then TurnSound() end
        f:Refresh()
    end)

    f:ApplyCover()

    -- Opening the book lands on the newest day (or the cover while it is empty).
    f:SetScript("OnShow", function()
        if panels[view] then f:Refresh() else f:ShowSection(#Journal().entries > 0 and "days" or "cover", true) end
    end)

    return f
end

-- Page widgets ----------------------------------------------------------------------
-- The controls of the Options page (and of companion tabs such as Wayfarer's Map): a title
-- with its rule, section labels, wax-seal check boxes, and flat buttons in the book's inks.
-- A tab panel covers both pages: the left page starts at x = 0, the right page at RIGHT_X.

K.RIGHT_X = K.PAGE_XS[2] + 36 - (K.PAGE_XS[1] + 30)

-- Flat button: "seg" (outlined, burgundy when on), "gold" or "burn" (filled, for the big actions).
local function MakeFlatButton(parent, width, height, label, style)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = (style == "gold" or style == "burn") and 2 or 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "SkaldBody")
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label)
    local fill, border, ink
    if style == "gold" then
        fill, border, ink = { 0.89, 0.72, 0.36 }, { 0.165, 0.10, 0.04 }, { 0.165, 0.10, 0.04 }
    elseif style == "burn" then
        fill, border, ink = { 0.52, 0.16, 0.14 }, { 0.165, 0.10, 0.04 }, { 0.95, 0.89, 0.75 }
    end
    function b:SetActive(active)
        self.active = active and true or false
        if fill then
            self:SetBackdropColor(fill[1], fill[2], fill[3], 1)
            self:SetBackdropBorderColor(border[1], border[2], border[3], 1)
            self.text:SetTextColor(ink[1], ink[2], ink[3])
        elseif self.active then
            self:SetBackdropColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3], 1)
            self:SetBackdropBorderColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 1)
            self.text:SetTextColor(0.96, 0.91, 0.80)
        else
            self:SetBackdropColor(1, 0.97, 0.88, 0.15)
            self:SetBackdropBorderColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 1)
            self.text:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        end
    end
    b:SetScript("OnEnter", function(self) self:SetAlpha(0.88) end)
    b:SetScript("OnLeave", function(self) self:SetAlpha(1) end)
    b:SetActive(false)
    return b
end

-- A flat round disc (a colour texture under a round mask) on `frame`.
local function MakeDisc(frame, layer, size, r, g, bl, sublevel)
    local t = frame:CreateTexture(nil, layer, nil, sublevel or 0)
    t:SetSize(size, size)
    t:SetColorTexture(r, g, bl, 1)
    local ok, mask = pcall(frame.CreateMaskTexture, frame)
    if ok and mask then
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        pcall(t.AddMaskTexture, t, mask)
    end
    return t
end

-- A round wax check box: burgundy with a gold dot when on, pale when off.
local function MakeWaxCheck(parent, label, get, set, iconPath, swatch, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or K.CW, 24)
    local function Round(layer, size, r, g, bl)
        local t = b:CreateTexture(nil, layer)
        t:SetSize(size, size)
        t:SetPoint("LEFT", (18 - size) / 2, 0)
        t:SetColorTexture(r, g, bl, 1)
        local ok, mask = pcall(b.CreateMaskTexture, b)
        if ok and mask then
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            pcall(t.AddMaskTexture, t, mask)
        end
        return t
    end
    local ring = Round("BACKGROUND", 18, K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
    local fill = Round("ARTWORK", 14, 0.91, 0.855, 0.71)
    local mid = Round("ARTWORK", 10, 0.75, 0.29, 0.26)
    local dot = Round("OVERLAY", 6, 0.88, 0.72, 0.29)
    ring:Show()
    local anchor = b
    local textX = 28
    if iconPath then
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", 26, 0)
        icon:SetTexture(iconPath)
        textX = 50
    end
    local fs = b:CreateFontString(nil, "OVERLAY", "SkaldBody")
    b.caption = label
    fs:SetPoint("LEFT", anchor, "LEFT", textX, 0)
    fs:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
    fs:SetText(label)
    function b.Sync()
        local on = get() and true or false
        if swatch then
            fill:SetColorTexture(swatch[1], swatch[2], swatch[3], 1)
        elseif on then
            fill:SetColorTexture(0.45, 0.12, 0.11, 1)
        else
            fill:SetColorTexture(0.91, 0.855, 0.71, 1)
        end
        dot:SetShown(on)
        mid:SetShown(on and not swatch)
    end
    b:SetScript("OnClick", function()
        set(not get())
        b.Sync()
    end)
    b.Sync()
    return b
end

-- A page title with the little rule under it, centred on a page of the panel.
local function PageHeading(panel, text, x)
    local fs = panel:CreateFontString(nil, "OVERLAY", "SkaldHead")
    fs:SetPoint("TOPLEFT", x, 0)
    fs:SetWidth(K.CW)
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
    fs:SetText(text)
    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetSize(130, 11)
    rule:SetPoint("TOP", fs, "BOTTOM", 0, -4)
    rule:SetTexture(K.TEX .. "rule")
    rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    return fs
end

local function SectionLabel(panel, text, x, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "SkaldSec")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(K.CW)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(K.C_SEC[1], K.C_SEC[2], K.C_SEC[3])
    fs:SetText(text)
    return fs
end

local function NoteText(panel, x, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(K.CW)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
    return fs
end

SkaldAPI.MakeButton = MakeFlatButton   -- so companion tabs match the book
SkaldAPI.MakeCheck = MakeWaxCheck
SkaldAPI.PageHeading = PageHeading
SkaldAPI.SectionLabel = SectionLabel
SkaldAPI.NoteText = NoteText
SkaldAPI.MakeDisc = MakeDisc
SkaldAPI.RIGHT_X = K.RIGHT_X
SkaldAPI.C_BODY, SkaldAPI.C_HEAD, SkaldAPI.C_MUTED = K.C_BODY, K.C_HEAD, K.C_MUTED
SkaldAPI.PAGE_W = K.CW


-- Events ---------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")

-- Events that may not exist on every client build: a missing one must not
-- break the addon, so each is registered on its own.
for _, ev in ipairs({
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_XP_UPDATE",
    "NEW_MOUNT_ADDED", "ACHIEVEMENT_EARNED", "SKILL_LINES_CHANGED", "CHAT_MSG_LOOT",
    "HEARTHSTONE_BOUND", "UPDATE_FACTION", "TAXIMAP_OPENED", "PLAYER_MONEY",
    "LEARNED_SPELL_IN_TAB", "QUEST_ACCEPTED",
    "PLAYER_UNGHOST", "PLAYER_ALIVE", "CONFIRM_XP_LOSS", "RESURRECT_REQUEST",
}) do
    pcall(frame.RegisterEvent, frame, ev)
end
-- Spell casts and pet changes fire for every unit in sight (a raid sends hundreds a second): only the
-- player's own are asked for, so the game does not even call this addon for the others.
for _, ev in ipairs({ "UNIT_PET", "UNIT_SPELLCAST_SUCCEEDED" }) do
    if not pcall(frame.RegisterUnitEvent, frame, ev, "player") then pcall(frame.RegisterEvent, frame, ev) end
end
pcall(frame.RegisterUnitEvent, frame, "UNIT_NAME_UPDATE", "pet")   -- a pet that is renamed

-- Becomes true a few seconds after login, once guild, group and skill data have
-- loaded; nothing that compares against saved state runs before then.
local ready = false

-- Milestones of the journey: round numbers of creatures slain, quests, falls and gold. The numbers
-- come from the game's Statistics; the first look only learns where you stand, so a character that
-- already has 500 kills is not told about all of them at once.
local CheckMarks, CheckReputation, CheckFlightPaths
do
local MARKS = {
    kills = { steps = { 100, 500, 1000, 2500, 5000, 10000 }, get = function() return KillStat() or GameStat(107) end },
    quests = { steps = { 10, 25, 50, 100, 250, 500 }, get = function() return GameStat(K.STAT_QUESTS) end },
    deaths = { steps = { 10, 25, 50, 100 }, get = function() return GameStat(K.STAT_DEATHS) end },
    gold = { steps = { 1, 10, 50, 100, 500, 1000 },
        get = function() return GetMoney and math.floor(GetMoney() / 10000) or nil end },
}
CheckMarks = function()
    local db = Journal()
    if not db or not ready or (Settings().rec or {}).mark == false then return end
    local first = db.marks == nil
    db.marks = db.marks or {}
    for key, def in pairs(MARKS) do
        local ok, value = pcall(def.get)
        if ok and type(value) == "number" then
            local reached, top = db.marks[key] or 0, db.marks[key] or 0
            for _, step in ipairs(def.steps) do
                if value >= step and step > top then top = step end
            end
            if top > reached then
                db.marks[key] = top
                if not first then
                    AddEntry("mark", tostring(top), nil, { mk = key, m = false, x = false, y = false })
                end
            end
        end
    end
end

-- Reputation: a standing of Friendly or better, newly reached, becomes a page. (Not seen in the
-- Forever client yet: written with both the old and the new reputation functions.)
local function ReadFactions()
    local list = {}
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        for i = 1, C_Reputation.GetNumFactions() or 0 do
            local d = C_Reputation.GetFactionDataByIndex(i)
            if d and d.name and not d.isHeader and type(d.reaction) == "number" then list[d.name] = d.reaction end
        end
    elseif GetNumFactions and GetFactionInfo then
        for i = 1, GetNumFactions() or 0 do
            local name, _, standing, _, _, _, _, _, isHeader = GetFactionInfo(i)
            if name and not isHeader and type(standing) == "number" then list[name] = standing end
        end
    end
    return list
end
CheckReputation = function()
    ns.repPending = false   -- (a field of ns: this is read by the event handler further down)
    local db = Journal()
    if not db or not ready or (Settings().rec or {}).mark == false then return end
    local ok, now = pcall(ReadFactions)
    if not ok then return end
    local first = db.rep == nil
    db.rep = db.rep or {}
    for name, standing in pairs(now) do
        local before = db.rep[name]
        if before and standing > before and standing >= 5 and not first then
            AddEntry("rep", name, nil, { st = _G["FACTION_STANDING_LABEL" .. standing] or tostring(standing),
                m = false, x = false, y = false })
        end
        db.rep[name] = standing
    end
end

-- Flight paths: a point learned at a flight master. (Not seen in the Forever client yet.)
CheckFlightPaths = function()
    local db = Journal()
    if not db or not ready or not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_Map and C_Map.GetBestMapForUnit) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    for _ = 1, 6 do
        local info = mapID and C_Map.GetMapInfo(mapID)
        if not info or not info.parentMapID or info.mapType <= 2 then break end
        mapID = info.parentMapID
    end
    if not mapID then return end
    local nodes = C_TaxiMap.GetAllTaxiNodes(mapID)
    if type(nodes) ~= "table" then return end
    local state = Enum and Enum.FlightPathState
    local known, here, count = {}, nil, 0
    for _, node in ipairs(nodes) do
        local isCurrent = (state and node.state == state.Current) or (not state and node.state == 0)
        local isKnown = isCurrent or (state and node.state == state.Reachable) or (not state and node.state == 1)
        if isKnown and node.nodeID then
            known[node.nodeID] = node.name or "?"
            count = count + 1
            if isCurrent then here = node.nodeID end
        end
    end
    local firstLook = db.taxi == nil
    db.taxi = db.taxi or {}
    -- Only the master I am standing at can have just taught me its path: the other paths the map shows were
    -- known before the diary looked, so they are kept without a page. (A first look that shows several known
    -- paths is a character that knew them already, the one here included.)
    local fresh = {}
    for id, name in pairs(known) do
        if not db.taxi[id] then
            db.taxi[id] = true
            if id == here and not (firstLook and count > 1) then fresh[#fresh + 1] = name end
        end
    end
    for _, name in ipairs(fresh) do
        AddEntry("flight", name, nil, { m = false, x = false, y = false })
    end
end
end

-- Guild membership. A lone nil is rechecked before it counts as leaving.
local function CheckGuild()
    local db = Journal()
    if not db then return end
    local name = GetGuildInfo("player")

    if not db.guildSeen then
        db.guildSeen = true
        db.guild = name or false
        if name then AddEntry("guild", name) end
        return
    end

    if name and name ~= db.guild then
        db.guild = name
        AddEntry("guild", name)
    elseif not name and db.guild then
        local old = db.guild
        C_Timer.After(3, function()
            if not GetGuildInfo("player") and db.guild == old then
                db.guild = false
                AddEntry("guildleave", old)
            end
        end)
    end
end

-- Professions: a page when one is learned, and at each 75 points of skill.
-- Everything is guarded: the profession API differs between client builds.
local skillPending = false

local function ReadSkills()
    local result, lines = {}, {}
    if not (GetProfessions and GetProfessionInfo) then return result, lines end
    local n = select("#", GetProfessions())
    for i = 1, n do
        local index = select(i, GetProfessions())
        if index then
            local name, _, level, _, _, _, line = GetProfessionInfo(index)
            name = Safe(name)
            if name then
                result[name] = tonumber(level) or 0
                lines[name] = line
            end
        end
    end
    return result, lines
end

local function CheckSkills()
    skillPending = false
    local db = Journal()
    if not db then return end
    local ok, current, lines = pcall(ReadSkills)
    if not ok then return end
    db.skills = db.skills or {}

    -- Professions are remembered by their own key (alchemy, cooking...), not by the name in the
    -- client's language, so changing the language does not make every profession new again.
    -- Names saved by earlier versions are converted here.
    local converted = {}
    for name, step in pairs(db.skills) do
        local key = ProfessionKey(nil, name)
        if key and key ~= name then
            converted[#converted + 1] = { name, key, step }
        end
    end
    for _, c in ipairs(converted) do
        db.skills[c[1]] = nil
        db.skills[c[2]] = math.max(db.skills[c[2]] or 0, c[3])
    end

    for name, level in pairs(current) do
        local step = math.floor(level / 75)
        local pfKey = ProfessionKey(lines and lines[name], name)
        local slot = pfKey or name
        if pfKey then
            ns.profNames = ns.profNames or {}
            ns.profNames[pfKey] = name   -- the name in today's language, for pages written in another
        end
        local known = db.skills[slot]
        local extra = { pf = pfKey }
        if known == nil then
            db.skills[slot] = step
            if db.skillsInit then AddEntry("profession", name, nil, extra) end
        elseif step > known then
            db.skills[slot] = step
            AddEntry("skill", string.format("%s %d", name, step * 75), nil, extra)
        end
    end
    db.skillsInit = true
end

-- Creatures defeated, estimated. Forever keeps the combat log from addons, so a kill is
-- recognised by what it leaves behind: experience. When your XP rises and a quest turn-in
-- does not explain it, one creature fell. Creatures too weak to give XP are not seen.
local lastXP, lastXPLevel, lastQuestAt = nil, nil, -10
local function Clock() return (GetTime and GetTime()) or time() end

local function ReadXP()
    local xp = Safe(UnitXP and UnitXP("player"))
    local level = Safe(UnitLevel and UnitLevel("player"))
    return tonumber(xp), tonumber(level)
end

local function OnXPChanged()
    local xp, level = ReadXP()
    if not xp or not level then return end
    local gained = lastXP and lastXPLevel == level and xp > lastXP
    lastXP, lastXPLevel = xp, level
    if not gained then return end
    -- A quest's reward can reach us just before the turn-in event: wait a moment, then ask.
    local heardAt = Clock()
    C_Timer.After(0.5, function()
        if lastQuestAt < heardAt - 0.6 then CountOnly("kill") end
    end)
end

-- Bosses: ENCOUNTER_END and BOSS_KILL can both fire for one kill.
local lastBoss, lastBossAt = nil, 0
-- Falls in a dungeon or raid since its last boss went down: the client does not say who struck, so the next
-- boss of the same instance is credited with them. Old falls (the last one over two hours ago) are forgotten.
local function InstanceId()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return nil end
    local ok, _, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
    return ok and type(id) == "number" and id or nil
end
local function NoteFall()
    local db, id = Journal(), InstanceId()
    if not db or not id then return end
    db.attempts = db.attempts or {}
    local a = db.attempts[id]
    if a and time() - (a.at or 0) > K.FALLS_FORGOTTEN then a = nil end
    a = a or { falls = 0 }
    a.falls, a.at = a.falls + 1, time()
    db.attempts[id] = a
end
local function BossDown(name)
    name = Safe(name)
    if not name or name == "" then return end
    if name == lastBoss and time() - lastBossAt < 30 then return end
    lastBoss, lastBossAt = name, time()
    local db, id = Journal(), InstanceId()
    local tries
    local a = db and id and db.attempts and db.attempts[id]
    if a then
        if a.falls and a.falls > 0 and time() - (a.at or 0) <= K.FALLS_FORGOTTEN then tries = a.falls end
        db.attempts[id] = nil
    end
    AddEntry("boss", name, nil, tries and { tries = tries } or nil)
end

-- The quest is already gone from the log when QUEST_TURNED_IN fires, so fall
-- back to the title captured from the quest dialog.
local function QuestName(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then return title end
    end
    if pendingQuestTitle and pendingQuestTitle ~= "" then
        return pendingQuestTitle
    end
    return L.UNKNOWN_QUEST
end

-- Quest rarity, like item quality: 0 Trivial (gray) .. 5 Legendary (orange).
-- Every client call is guarded: the quest APIs differ between builds, and /skald
-- probe records what this client actually returns so the rules can be tuned.
local function Try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function ReadSignals(questID, xpReward)
    local s = { level = pendingQuestLevel }
    local maxXP = UnitXPMax and UnitXPMax("player") or 0
    xpReward = tonumber(xpReward) or 0
    s.xp = xpReward
    s.share = (maxXP > 0 and xpReward > 0) and (xpReward / maxXP) or nil

    if C_QuestTag and C_QuestTag.GetQuestTagInfo then
        local info = Try(C_QuestTag.GetQuestTagInfo, questID)
        if type(info) == "table" then
            s.tagID, s.tagName, s.elite = info.tagID, info.tagName, info.isElite
        end
    end
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        s.class = Try(C_QuestInfoSystem.GetQuestClassification, questID)
    end

    -- QuestDB (optional): offline Classic quest data with Forever's client tables.
    local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
    local q = qdb and Try(qdb.GetQuest, qdb, questID)
    if type(q) == "table" then
        s.qdb = true
        s.dbLevel = q.questLevel
        s.sort = q.zoneOrSort            -- negative = the game's own QuestSort category
        s.players = q.suggestedPlayers
        s.flags = tonumber(q.questFlags) or 0
        s.sflags = tonumber(q.specialFlags) or 0     -- bit 1: repeatable
        s.xpFull = Try(qdb.GetQuestXP, qdb, questID)  -- full XP, whatever your level
        local rw = Try(qdb.GetRewards, qdb, questID)
        s.choices = (type(rw) == "table" and type(rw.choices) == "table") and #rw.choices or 0
        -- Position in the quest chain: walk back to its start and forward to its end.
        local back, fwd, seen = 0, 0, { [questID] = true }
        local id = q.preQuestSingle and q.preQuestSingle[1]
        s.chainIds = {}
        while id and not seen[id] and back < 40 do
            seen[id] = true
            back = back + 1
            s.chainIds[back] = id
            local p = Try(qdb.GetQuest, qdb, id)
            id = type(p) == "table" and p.preQuestSingle and p.preQuestSingle[1] or nil
        end
        id = q.nextQuestInChain
        while id and not seen[id] and fwd < 40 do
            seen[id] = true
            fwd = fwd + 1
            local nx = Try(qdb.GetQuest, qdb, id)
            id = type(nx) == "table" and nx.nextQuestInChain or nil
        end
        s.chainBack, s.chainFwd = back, fwd
    end
    return s
end

-- The game's own quest categories (QuestSort, shown as a negative zoneOrSort).
K.SORT_EPIC, K.SORT_LEGENDARY = -1, -344
K.SORT_CLASS = {
    [-61] = true, [-81] = true, [-82] = true, [-141] = true, [-161] = true,
    [-162] = true, [-261] = true, [-262] = true, [-263] = true,
}

-- Which of the seven XP columns of its level a quest's XP is: 1-2 small errand,
-- 3-5 the standard quest, 6-7 a big one. 0 when unknown.
local function XPColumn(level, xp)
    local row = ns.XPTIERS and level and ns.XPTIERS[level]
    xp = tonumber(xp)
    if not row or not xp or xp <= 0 then return 0 end
    local best, bestDist = 0, math.huge
    for i, v in ipairs(row) do
        local d = math.abs(v - xp)
        if d < bestDist then best, bestDist = i, d end
    end
    return best
end

-- Rarity rules, calibrated by running them over every quest QuestDB knows for Forever
-- (about 3,700 with giver data) as a mage or warrior would meet them: roughly 8% gray,
-- 58% white, 24% green, 7.5% blue, 1.4% purple and 0.7% orange, with the green-or-better
-- share between 26% and 41% at every level band. The share of your level was dropped:
-- it only depends on the level and made half of all quests gray once you out-level them.
local function QuestTier(questID, xpReward)
    local s = ReadSignals(questID, xpReward)
    local qtype = QuestTypeFromDB(questID) or QuestTypeFromObjectives(pendingObjectiveTypes)
    s.qtype = qtype

    local playerLevel = UnitLevel and UnitLevel("player")
    local questLevel = (s.dbLevel and s.dbLevel > 0 and s.dbLevel) or s.level or playerLevel
    local len = (s.chainBack or 0) + 1 + (s.chainFwd or 0)
    local isChainEnd = (s.chainBack or 0) >= 1 and (s.chainFwd or 0) == 0

    -- Base from the XP column (the quest's full XP, so out-levelling it changes nothing).
    local col = XPColumn(questLevel, s.xpFull or s.xp)
    s.xpColumn = col
    local tier = (col == 0 and 1) or (col <= 2 and 0) or (col <= 5 and 1) or 2

    -- Carrying a message is everyday work; only a chain, a category or a flag lifts it.
    if qtype == "delivery" then tier = math.min(tier, 1) end
    -- A piece of a longer story is never trivial.
    if len >= 4 and tier < 1 then tier = 1 end
    -- A quest that lets you choose your reward matters a little more.
    if (s.choices or 0) > 0 then tier = math.max(tier, 2) end

    if s.qdb then
        -- The end of a long chain is a payoff; a short one only nudges up.
        if isChainEnd then
            if len >= 12 then tier = math.max(tier, 5)
            elseif len >= 7 then tier = math.max(tier, 4)
            elseif len >= 4 then tier = math.max(tier, 3)
            elseif len >= 3 then tier = math.min(3, tier + 1) end
        end

        -- The game's own category: Legendary, Epic, and class quests (the later ones count more).
        if s.sort == K.SORT_LEGENDARY then tier = 5
        elseif s.sort == K.SORT_EPIC then tier = math.max(tier, 4)
        elseif s.sort and K.SORT_CLASS[s.sort] then
            tier = math.max(tier, (questLevel or 0) >= 20 and 3 or 2)
        end

        -- Flag bits (CMaNGOS): 0x20 epic, 0x40 raid- or battleground-scale, 0x2 shared on accept.
        local flags = s.flags or 0
        if flags % 64 >= 32 then tier = math.max(tier, 4)
        elseif flags % 128 >= 64 then tier = math.max(tier, 2)
        elseif flags % 4 >= 2 then tier = math.max(tier, 2) end

        -- A few quests carry a suggested group size (15 in the data, all 2 or 3 players).
        if s.players and s.players >= 2 then tier = math.max(tier, 3) end

        -- A repeatable quest is never more than everyday work.
        if (s.sflags or 0) % 2 == 1 and tier > 1 then tier = 1 end
    end

    -- Tags from the client, when it provides them (it gave none on Forever so far).
    local qt = Enum and Enum.QuestTag
    if s.elite or (qt and s.tagID and s.tagID == qt.Group) then tier = math.max(tier, 3) end
    if qt and s.tagID and (s.tagID == qt.Dungeon or s.tagID == qt.Raid) then tier = math.max(tier, 4) end

    -- Well above your level is a harder quest than the table says.
    if questLevel and playerLevel and questLevel >= playerLevel + 3 then tier = math.min(3, tier + 1) end

    -- A hand-picked quest has the last word.
    local curated = ns.CURATED and ns.CURATED[questID]
    if curated and curated.tier then tier = curated.tier end

    return tier, s
end

-- Pages written at each detail level: the lowest tier that becomes a page.
K.DETAIL_MIN_TIER = { low = 2, normal = 1, high = 0 }

-- Loot -----------------------------------------------------------------------------
-- Items you receive become pages from a rarity up (Options), with a line chosen by what
-- the item is. A day writes only so many, so a busy day does not drown the diary.
K.LOOT_MIN_TIER = 2      -- green and better, unless Options says otherwise
K.LOOT_DAY_CAP = 12
-- What counts as gear. Anything else (meat, pelts, cloth, herbs, quest papers) is left out
-- unless it is rare (blue or better): that keeps the diary free of junk.
K.LOOT_RARE_TIER = 3

-- The game's own loot messages ("You receive loot: %s."), turned into patterns.
local function LootPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local s = fmt:gsub("%%s", "\1"):gsub("%%d", "\2")
    s = s:gsub("(%W)", "%%%1")
    s = s:gsub("%%\1", "(.-)"):gsub("%%\2", "(%%d+)")
    return "^" .. s .. "$"
end
local lootPatterns
local function LootPatterns()
    if lootPatterns then return lootPatterns end
    lootPatterns = {}
    for _, def in ipairs({
        { "LOOT_ITEM_SELF_MULTIPLE", "loot" }, { "LOOT_ITEM_SELF", "loot" },
        { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "gift" }, { "LOOT_ITEM_PUSHED_SELF", "gift" },
        { "LOOT_ITEM_CREATED_SELF_MULTIPLE", "craft" }, { "LOOT_ITEM_CREATED_SELF", "craft" },
    }) do
        local pattern = LootPattern(_G[def[1]])
        if pattern then lootPatterns[#lootPatterns + 1] = { pattern, def[2] } end
    end
    return lootPatterns
end

local function OnLoot(text)
    local db, s = Journal(), Settings()
    if not db or type(text) ~= "string" then return end
    local link, src
    for _, def in ipairs(LootPatterns()) do
        local found = text:match(def[1])
        if found then link, src = found, def[2]; break end
    end
    if not link then return end
    local ref, name, quality = ItemParts(link)
    if not ref then return end
    local item = "|cff" .. (K.QUALITY_COLOR[quality] or "ffffff") .. "|H" .. ref .. "|h[" .. name .. "]|h|r"
    if quality < (s.lootTier or K.LOOT_MIN_TIER) then return end

    local cat, icon, mat = ItemInfo(ref)

    if s.lootGear ~= false and not IsGear(cat) and quality < K.LOOT_RARE_TIER then return end

    -- Making the same thing again and again is one page that counts them, not a page for each.
    local iid = tonumber(tostring(item):match("item:(%d+)"))
    local qty = tonumber(text:match("|h|rx(%d+)")) or 1
    if src == "craft" and iid then
        local last = db.entries[#db.entries]
        if last and last.kind == "loot" and last.src == "craft" and last.iid == iid
            and time() - (last.t2 or last.t or 0) < K.CRAFT_MERGE then
            if (last.n or 1) < 2 and PHRASES.lootCraftMany then last.idx = math.random(#PHRASES.lootCraftMany) end
            last.n = (last.n or 1) + qty
            last.t2 = time()
            ns.layoutRev = (ns.layoutRev or 0) + 1
            if window and window:IsShown() then window:Refresh() end
            return
        end
    end

    local d = db.days and db.days[DayKey()]
    if d then
        if (d.lo or 0) >= K.LOOT_DAY_CAP then return end
        d.lo = (d.lo or 0) + 1
    end
    -- No position: loot is not pinned on the map.
    AddEntry("loot", item, nil, { iid = iid, n = (src == "craft" and qty > 1) and qty or nil, tier = quality, cat = cat, src = src, ic = icon, mat = mat, m = false, x = false, y = false })
end

-- What the client reports for each turned-in quest, kept in SkaldDB for
-- tuning the rules above, e.g. for a bug report. On by default, capped at 150 quests, kept
-- only in this computer's saved variables. The Options tab has the switch; /skald probe turns
-- it on, /skald probe off stops it, /skald probe clear forgets what it recorded.
local function ProbeQuest(questID, xpReward, moneyReward, tier, s)
    local db = Settings()
    if not db.probe then return end   -- a developer tool: off unless asked for (/skald probe)
    db.probeLog = db.probeLog or {}
    local rec = {
        id = questID, title = pendingQuestTitle, npc = pendingNPC, zone = GetZoneText(),
        xp = xpReward, money = moneyReward, share = s.share,
        playerLevel = UnitLevel and UnitLevel("player"), questLevel = s.level,
        tagID = s.tagID, tagName = s.tagName, elite = s.elite, class = s.class,
        qdb = s.qdb, dbLevel = s.dbLevel, sort = s.sort, players = s.players,
        chainBack = s.chainBack, chainFwd = s.chainFwd, qtype = s.qtype,
        tier = tier,
    }
    table.insert(db.probeLog, rec)
    while #db.probeLog > 150 do table.remove(db.probeLog, 1) end
end

-- Journal only records the first visit to each zone; dungeons and raids get
-- pages of their own.
-- A zone is also known by its map (not only by its name, which changes with the client's language),
-- so changing the language does not write a page for every land again.
local function VisitZone(zone)
    if not zone or zone == "" then return end
    local function ZoneMapKey(mapID)
        if not (C_Map and C_Map.GetMapInfo and mapID) then return nil end
        for _ = 1, 8 do
            local info = C_Map.GetMapInfo(mapID)
            if not info then return nil end
            if info.mapType and info.mapType <= 3 or not info.parentMapID or info.parentMapID == 0 then
                return "map:" .. tostring(mapID)
            end
            mapID = info.parentMapID
        end
        return nil
    end
    local db = Journal()
    local visited = db.visited
    db.visitedMaps = db.visitedMaps or {}
    local maps = db.visitedMaps
    local mapKey
    pcall(function()
        mapKey = C_Map and C_Map.GetBestMapForUnit and ZoneMapKey(C_Map.GetBestMapForUnit("player"))
        if not db.mapKeysDone then
            -- Zones already written get their map keys once, from the position kept on each page.
            db.mapKeysDone = true
            for _, e in ipairs(db.entries) do
                if (e.kind == "zone" or e.kind == "dungeon") and type(e.m) == "number" then
                    local k = ZoneMapKey(e.m)
                    if k then maps[k] = true end
                end
            end
        end
    end)
    if visited[zone] then
        if mapKey then maps[mapKey] = true end
        return
    end
    if mapKey and maps[mapKey] then
        visited[zone] = true   -- seen before, under another name
        return
    end
    visited[zone] = true
    if mapKey then maps[mapKey] = true end
    local inInstance, instanceType = IsInInstance()
    local kind = (inInstance and (instanceType == "party" or instanceType == "raid")) and "dungeon" or "zone"
    AddEntry(kind, zone, zone)
end

local function CheckZone()
    local zone = GetZoneText()
    if zone and zone ~= "" and zone ~= lastZone then
        lastZone = zone
        VisitZone(zone)
        if ns.CheckMemory then pcall(ns.CheckMemory) end
    end
end

-- A hunter's companions, the reminder on returning to the game, and a probe for class events. -----
local Mile = {}
do
-- The hunter's pets, by name. A hunter that already has a pet when the diary first looks at it is
-- not told about it; a new hunter's first pet (level 12 or lower) and every later one are.
Mile.CheckPet = function()
    local db = Journal()
    if not db or not ready or (Settings().rec or {}).mark == false then return end
    local okClass, _, classFile = pcall(UnitClass, "player")
    if not okClass or classFile ~= "HUNTER" then return end
    local firstLook = db.pets == nil
    db.pets = db.pets or {}
    if not UnitExists("pet") then db.petNow = nil; return end   -- no pet out (dismissed, dead, or a loaned one that left)
    local name = Safe(UnitName("pet"))
    if type(name) ~= "string" or name == "" or (UNKNOWN and name == UNKNOWN) then return end
    -- A pet on loan (for a quest) has a time remaining and leaves after a while: it is not a companion.
    local loaned = false
    pcall(function()
        if GetPetTimeRemaining then
            local left = GetPetTimeRemaining()
            if type(left) == "number" and left > 0 then loaned = true end
        end
    end)
    if loaned then db.petNow = nil; return end
    local family
    pcall(function() family = Safe(UnitCreatureFamily("pet")) end)
    local petLevel, myLevel = UnitLevel("pet") or 0, UnitLevel("player") or 0
    -- The same pet under a new name (renamed while out): its record moves to the new name, no new page.
    local guid
    pcall(function() guid = Safe(UnitGUID("pet")) end)
    local previous = db.petNow and db.pets[db.petNow]
    if previous and db.petNow ~= name and guid and previous.guid == guid and not db.pets[name] then
        db.pets[name] = previous
        db.pets[db.petNow] = nil
    end
    local rec = db.pets[name]
    db.petNow = name
    if rec and guid then rec.guid = guid end
    -- What the pet eats (the game tells it only for the pet that is out): kept for the Pets tab.
    local diet
    pcall(function()
        -- this client keeps the pet functions in C_PetInfo (the old global is gone); the answer may be
        -- a list or several values, and only words are kept
        local fn = (C_PetInfo and C_PetInfo.GetPetFoodTypes) or GetPetFoodTypes
        if not fn then return end
        local foods = { fn() }
        if #foods == 1 and type(foods[1]) == "table" then foods = foods[1] end
        local words = {}
        for _, v in ipairs(foods) do if type(v) == "string" and v ~= "" then words[#words + 1] = v end end
        if #words > 0 then diet = table.concat(words, ", ") end
    end)
    if rec then
        rec.lv = petLevel
        if family then rec.fam = family end
        if diet then rec.diet = diet end
    end
    if not rec then
        rec = { t = time(), fam = family, lv = petLevel, diet = diet, guid = guid }
        db.pets[name] = rec
        local alone = next(db.pets, nil) == name and next(db.pets, name) == nil
        if firstLook and myLevel > 12 then
            rec.capped = petLevel >= myLevel   -- an old pet: recorded, not told
            return
        end
        AddEntry("tame", name, nil, { sub = (alone and myLevel <= 12) and "first" or "more", fam = family })
    end
    if not rec.capped and myLevel >= 10 and petLevel >= myLevel then
        rec.capped = true
        AddEntry("tame", name, nil, { sub = "level", fam = family })
    end
end

-- Where the character stands when the game is left, kept for the reminder on the next visit.
Mile.SaveResume = function()
    local db = Journal()
    if not db then return end
    local quests = {}
    pcall(function()
        local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
            or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
        for i = 1, n do
            local title, isHeader
            if C_QuestLog and C_QuestLog.GetInfo then
                local info = C_QuestLog.GetInfo(i)
                if info then title, isHeader = info.title, info.isHeader end
            elseif GetQuestLogTitle then
                local t, _, _, header = GetQuestLogTitle(i)
                title, isHeader = t, header
            end
            title = Safe(title)
            if type(title) == "string" and title ~= "" and not isHeader then
                quests[#quests + 1] = title
                if #quests >= 3 then break end
            end
        end
    end)
    local r = db.resume or {}
    r.t, r.zone, r.level, r.quests = time(), GetZoneText(), UnitLevel("player"), quests
    r.zm = nil
    pcall(function()
        local id = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if type(id) == "number" then r.zm = id end
    end)
    db.resume = r
end

-- The lines of the reminder: where the last visit ended, the quests still open, and the note the
-- player left for the next visit.
Mile.ResumeLines = function()
    local db = Journal()
    local r = db and db.resume
    if not r or not r.zone then return nil end
    local lines = { string.format(L.RESUME_LAST, r.zone, r.level or 0) }
    if type(r.quests) == "table" and #r.quests > 0 then
        lines[#lines + 1] = string.format(L.RESUME_QUESTS, table.concat(r.quests, ", "))
    end
    if type(r.next) == "string" and r.next ~= "" then
        lines[#lines + 1] = string.format(L.RESUME_NEXT, r.next)
    end
    return lines
end

-- Shown on login after a break of twenty minutes or more (a quick /reload does not count).
Mile.ShowResume = function()
    local db = Journal()
    local r = db and db.resume
    if not r or Settings().resume == false or not r.t or time() - r.t < 20 * 60 then return end
    if not r.zone then return end
    local data = { zone = (ns.PlaceNameById and ns.PlaceNameById(r.zm)) or r.zone, level = r.level,
        quests = r.quests, note = r.next }
    r.t = time()
    r.next = nil
    ns.ShowResumeCard(data)
end

-- /skald tidy: removes the pages that repeat an earlier one only because the client's language
-- changed (a profession taken up again, a land discovered again). The first page of each stays.
-- Pages of the same thing made again and again, written one by one before they were counted, become one page.
Mile.MergeCrafts = function()
    local db = Journal()
    if not db then return 0 end
    local kept, merged, last = {}, 0, nil
    for _, e in ipairs(db.entries) do
        if e.kind == "loot" and e.src == "craft" and e.iid and last and last.iid == e.iid
            and (e.t or 0) - (last.t2 or last.t or 0) < K.CRAFT_MERGE then
            last.n = (last.n or 1) + (e.n or 1)
            last.t2 = e.t
            merged = merged + 1
            local counts = db.stats and db.stats.counts
            if counts and (counts.loot or 0) > 0 then counts.loot = counts.loot - 1 end
        else
            last = (e.kind == "loot" and e.src == "craft" and e.iid) and e or nil
            kept[#kept + 1] = e
        end
    end
    if merged > 0 then
        for _, e in ipairs(kept) do
            if e.kind == "loot" and e.src == "craft" and (e.n or 1) >= 2 and PHRASES.lootCraftMany and not e.manyIdx then
                e.idx, e.manyIdx = math.random(#PHRASES.lootCraftMany), true
            end
        end
        db.entries = kept
        ns.layoutRev = (ns.layoutRev or 0) + 1
        if window and window:IsShown() then window:Refresh() end
    end
    return merged
end

Mile.Tidy = function()
    local db = Journal()
    if not db then return 0 end
    local function MapKey(mapID)
        if not (C_Map and C_Map.GetMapInfo and type(mapID) == "number") then return nil end
        for _ = 1, 8 do
            local info = C_Map.GetMapInfo(mapID)
            if not info then return nil end
            if (info.mapType and info.mapType <= 3) or not info.parentMapID or info.parentMapID == 0 then
                return "map:" .. tostring(mapID)
            end
            mapID = info.parentMapID
        end
    end
    local seen, kept, removed = {}, {}, 0
    for _, e in ipairs(db.entries) do
        local key
        if e.kind == "profession" then
            key = "pf:" .. tostring(e.pf or ProfessionKey(nil, e.arg) or e.arg)
        elseif e.kind == "zone" then
            key = MapKey(e.m)
        end
        if key and seen[key] then
            removed = removed + 1
            local counts = db.stats and db.stats.counts
            if counts and counts[e.kind] and counts[e.kind] > 0 then counts[e.kind] = counts[e.kind] - 1 end
            local day = db.days and db.today and db.days[db.today]
            if day and e.kind == "zone" and (day.z or 0) > 0 and e.t and date("%Y-%m-%d", e.t) == db.today then
                day.z = day.z - 1
            end
        else
            if key then seen[key] = true end
            kept[#kept + 1] = e
        end
    end
    if removed > 0 then
        db.entries = kept
        ns.layoutRev = (ns.layoutRev or 0) + 1
        if window and window:IsShown() then window:Refresh() end
    end
    return removed + Mile.MergeCrafts()
end

-- Pages keep the names the client used when they were written. Quests, items, professions and
-- places all have ids, so after a change of language the names are read again by id and the old
-- pages are told in the new language. Whatever cannot be read yet (an item not loaded) stays as it
-- was and is tried again at the next call.
Mile.Relocalize = function()
    local db = Journal()
    if not db then return end
    local changed = 0
    local ZoneNameOfMap = ns.ZoneNameOfMap
    local function ItemName(id)
        local name
        pcall(function()
            if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
            if not name and GetItemInfo then name = GetItemInfo(id) end
            if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        end)
        return Safe(name)
    end
    -- Pages without a map of their own (items, quests) learn it from a page of the same place.
    local mapOfName = {}
    for _, e in ipairs(db.entries) do
        local id = (type(e.m) == "number" and e.m) or e.zm
        if id and e.zone and e.kind ~= "dungeon" and e.kind ~= "day" then mapOfName[e.zone] = id end
    end
    -- A page with no map of its own and a place name nothing else explains (an item picked up
    -- before maps were kept) takes the map of the pages around it, when the ones before and after
    -- agree, or when a single neighbour is within five minutes.
    local list = db.entries
    local function MapOf(e) return (type(e.m) == "number" and e.m) or e.zm end
    for i, e in ipairs(list) do
        local blank = e.zone == ""   -- a page written with no place name: its own map may be a continent
        if (blank or (not MapOf(e) and not mapOfName[e.zone])) and e.t and e.kind ~= "dungeon" and e.kind ~= "day" and e.kind ~= "note" then
            local prevId, prevT, nextId, nextT
            for j = i - 1, math.max(1, i - 40), -1 do
                local id = MapOf(list[j])
                if id and list[j].kind ~= "dungeon" then prevId, prevT = id, list[j].t break end
            end
            for j = i + 1, math.min(#list, i + 40) do
                local id = MapOf(list[j])
                if id and list[j].kind ~= "dungeon" then nextId, nextT = id, list[j].t break end
            end
            local pick
            if blank and nextId and (nextT or 0) - e.t <= 300 then
                pick = nextId   -- the next page, written seconds later, is where the name was missing
            elseif prevId and nextId then
                if prevId == nextId and e.t - (prevT or 0) <= 86400 and (nextT or 0) - e.t <= 86400 then pick = prevId end
            elseif prevId and e.t - (prevT or 0) <= 300 then pick = prevId
            elseif nextId and (nextT or 0) - e.t <= 300 then pick = nextId end
            if pick then e.zm = pick end
        end
    end
    for _, e in ipairs(db.entries) do
        -- the place
        local mapId = (e.zone == "" and e.zm) or (type(e.m) == "number" and e.m) or e.zm or mapOfName[e.zone]
        if mapId and e.kind ~= "dungeon" and e.kind ~= "day" then
            local zone = ZoneNameOfMap(mapId)
            if zone and zone ~= e.zone then
                if e.kind == "death" and db.stats and db.stats.deathZones then
                    local dz = db.stats.deathZones
                    if dz[e.zone] then
                        dz[e.zone] = dz[e.zone] - 1
                        if dz[e.zone] <= 0 then dz[e.zone] = nil end
                    end
                    dz[zone] = (dz[zone] or 0) + 1
                end
                if e.arg == e.zone and (e.kind == "zone" or e.kind == "death" or e.kind == "revive") then e.arg = zone end
                e.zone = zone
                changed = changed + 1
            end
        end
        -- a hand-picked quest has the rarity picked for it, also on pages written before it was picked
        if e.kind == "quest" and e.q and ns.CURATED and ns.CURATED[e.q] and ns.CURATED[e.q].tier
            and e.tier ~= ns.CURATED[e.q].tier then
            e.tier = ns.CURATED[e.q].tier
            changed = changed + 1
        end
        -- the quest's title
        if e.kind == "quest" and e.q and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local ok, title = pcall(C_QuestLog.GetTitleForQuestID, e.q)
            title = ok and Safe(title) or nil
            if type(title) == "string" and title ~= "" and title ~= e.arg then e.arg = title; changed = changed + 1 end
        end
        -- the item's name inside its link
        if e.kind == "loot" and type(e.arg) == "string" then
            local ref, name = ItemParts(e.arg)
            local id = ref and tonumber(ref:match("item:(%d+)"))
            local now = id and ItemName(id)
            if now and now ~= name then
                e.arg = e.arg:gsub("(|h%[).-(%]|h)", function(a, b) return a .. now .. b end, 1)
                changed = changed + 1
            end
        end
        -- the profession's name
        if (e.kind == "profession" or e.kind == "skill") and type(e.arg) == "string" then
            local key = e.pf or ProfessionKey(nil, e.arg)
            local now = key and ns.profNames and ns.profNames[key]
            if now then
                local number = e.kind == "skill" and e.arg:match("%s(%d+)$")
                local text = number and (now .. " " .. number) or now
                if text ~= e.arg then e.arg = text; e.pf = e.pf or key; changed = changed + 1 end
            end
        end
    end
    -- A day's closing page carries the place where the day ended: the last page before it.
    for i, e in ipairs(list) do
        if e.kind == "day" then
            for j = i - 1, math.max(1, i - 60), -1 do
                local z = list[j].zone
                if list[j].kind ~= "day" and type(z) == "string" and z ~= "" then
                    if z ~= e.zone then e.zone = z; changed = changed + 1 end
                    break
                end
            end
        end
    end
    if changed > 0 then
        ns.layoutRev = (ns.layoutRev or 0) + 1
        if window and window:IsShown() then window:Refresh() end
    end
    return changed
end

-- The short quest summary shown when the mouse is over a quest page. The objective and the reward
-- come from QuestDB by the quest id (in the language it has text for); the page supplies the rest.
do
local function Expand(t)
    if type(t) ~= "string" then return nil end
    local name = UnitName and UnitName("player") or ""
    local class = UnitClass and select(1, UnitClass("player")) or ""
    local race = UnitRace and select(1, UnitRace("player")) or ""
    t = t:gsub("%$[Bb]", " ")
    t = t:gsub("%$[Nn]", function() return name end)
    t = t:gsub("%$[Cc]", function() return class end)
    t = t:gsub("%$[Rr]", function() return race end)
    t = t:gsub("%$[Gg]([^:;]*):([^;]*);", function(male) return (male:gsub("^%s+", ""):gsub("%s+$", "")) end)
    t = t:gsub("%$%w+", "")
    t = t:gsub("%s+", " ")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    if #t > 230 then
        t = t:sub(1, 230):gsub("%s+%S*$", "") .. "..."
    end
    return t ~= "" and t or nil
end
ns.ExpandQuestText = Expand
local TIP_TIER = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
ns.QuestTip = function(tip, e)
    local col = TIP_TIER[e.tier or 1] or TIP_TIER[1]
    tip:ClearLines()
    pcall(tip.SetMinimumWidth, tip, 260)
    tip:AddLine(tostring(e.arg or L.UNKNOWN_QUEST), col[1], col[2], col[3], true)

    local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
    local level, objective, xp, money
    if qdb and e.q then
        local okQ, q = pcall(qdb.GetQuest, qdb, e.q)
        if okQ and type(q) == "table" then level = tonumber(q.questLevel) end
        local okT, text = pcall(qdb.GetQuestText, qdb, e.q)
        -- QuestDB only has English: used when the client is in English and the page did not keep the
        -- text in the client's language (as pages written since 0.34 do).
        if okT and type(text) == "table" and GetLocale() == "enUS" then objective = Expand(text.objectives) end
        local okR, rw = pcall(qdb.GetRewards, qdb, e.q)
        if okR and type(rw) == "table" then xp, money = rw.xp, rw.money end
    end
    level = (e.ql and e.ql > 0 and e.ql) or level
    local left = level and string.format(L.TIP_LEVEL, level) or ""
    local right = e.tier and L.TIERS[e.tier] or ""
    if left ~= "" or right ~= "" then
        tip:AddDoubleLine(left, right, 1, 0.82, 0, col[1], col[2], col[3])
    end
    objective = (type(e.ot) == "string" and e.ot ~= "" and Expand(e.ot)) or objective
    if objective then tip:AddLine(objective, 0.9, 0.9, 0.9, true) end

    local reward = {}
    if type(xp) == "number" and xp > 0 then reward[#reward + 1] = string.format(L.TIP_XP, xp) end
    if type(money) == "number" and money > 0 then
        local ok, coins = pcall(GetCoinTextureString or function(c) return string.format("%dg %ds %dc", c / 10000, (c / 100) % 100, c % 100) end, money)
        if ok and coins then reward[#reward + 1] = coins end
    end
    if #reward > 0 then
        tip:AddLine(" ")
        tip:AddLine(L.TIP_REWARD .. ": " .. table.concat(reward, "  -  "), 1, 0.82, 0, true)
    end

    tip:AddLine(" ")
    local foot = {}
    if e.npc then foot[#foot + 1] = string.format(L.TIP_GIVER, e.npc) end
    local place = ns.PlaceName and ns.PlaceName(e) or e.zone
    if place and place ~= "" then foot[#foot + 1] = place end
    if #foot > 0 then tip:AddLine(table.concat(foot, "  -  "), 0.7, 0.7, 0.7, true) end
    tip:AddLine(date(L.DATE_FMT, e.t or 0), 0.5, 0.5, 0.5)
end
end

-- The id of a creature, read from its GUID (Creature-0-server-instance-zone-ID-spawn).
Mile.NpcId = function(unit)
    local ok, guid = pcall(UnitGUID, unit)
    guid = ok and Safe(guid) or nil
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

-- The hunter's tab: the companion at one's side, and every pet there has been.
Mile.BuildPets = function(panel)
    PageHeading(panel, L.TAB_PETS, 0)
    local nowLabel = SectionLabel(panel, L.PETS_NOW, 0, -52)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("TOPLEFT", 0, -76)
    icon:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_pet")
    local name = panel:CreateFontString(nil, "OVERLAY", "SkaldHead")
    name:SetPoint("LEFT", icon, "RIGHT", 14, 0)
    name:SetWidth(K.CW - 58)
    name:SetJustifyH("LEFT")
    name:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])

    -- The facts, in two columns: a small label over each value.
    local function Cell(col, row, label)
        local x, y = (col - 1) * 170, -126 - (row - 1) * 34
        local l = panel:CreateFontString(nil, "OVERLAY", "SkaldSec")
        l:SetPoint("TOPLEFT", x, y)
        l:SetWidth(160)
        l:SetJustifyH("LEFT")
        l:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
        l:SetText(Upper(label))
        local v = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
        v:SetPoint("TOPLEFT", x, y - 15)
        v:SetWidth(160)
        v:SetJustifyH("LEFT")
        v:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        return v, l
    end
    local famV, famL = Cell(1, 1, L.PETL_FAMILY)
    local lvlV, lvlL = Cell(2, 1, L.PETL_LEVEL)
    local dietV, dietL = Cell(1, 2, L.PETL_DIET)
    local sinceV, sinceL = Cell(2, 2, L.PETL_SINCE)
    local lastLine = NoteText(panel, 0, -126)

    -- The companion itself, standing in an arched frame like the character on the cover. Only the pet
    -- that is out can be drawn; for any other the paw takes its place.
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetSize(191, 226)
    holder:SetPoint("TOPLEFT", (K.CW - 209) / 2 + 9, -212)
    local okModel, model = pcall(CreateFrame, "PlayerModel", nil, holder)
    if okModel and model then
        model:SetAllPoints()
        -- The pet stands still in a three-quarter view. Hold the left button and drag to turn it; the
        -- wheel moves the camera closer or further (animals differ a great deal in size).
        local dragging, lastX
        model:EnableMouse(true)
        model:EnableMouseWheel(true)
        model:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then dragging, lastX = true, GetCursorPosition() end
        end)
        model:SetScript("OnMouseUp", function() dragging = false end)
        model:SetScript("OnUpdate", function(self)
            if dragging then
                local x = GetCursorPosition()
                self.skaldAngle = ((self.skaldAngle or 0.6) + (x - (lastX or x)) * 0.012) % (math.pi * 2)
                lastX = x
                pcall(self.SetFacing, self, self.skaldAngle)
            end
        end)
        model:SetScript("OnMouseWheel", function(self, delta)
            self.skaldZoom = math.max(0.8, math.min(5, (self.skaldZoom or 1.3) - (delta or 0) * 0.25))
            pcall(self.SetCamDistanceScale, self, self.skaldZoom)
        end)
    end
    local placeholder = holder:CreateTexture(nil, "ARTWORK")
    placeholder:SetSize(100, 100)
    placeholder:SetPoint("CENTER")
    placeholder:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_pet")
    placeholder:SetAlpha(0.55)
    local alcove = CreateFrame("Frame", nil, panel)
    alcove:SetFrameLevel(holder:GetFrameLevel() + 5)
    alcove:SetSize(209, 246)
    alcove:SetPoint("TOPLEFT", (K.CW - 209) / 2, -204)
    local alcoveTex = alcove:CreateTexture(nil, "OVERLAY")
    alcoveTex:SetAllPoints()
    alcoveTex:SetTexture(K.TEX .. "alcove")
    alcoveTex:SetTexCoord(0, 316 / 512, 0, 372 / 512)
    local function ShowPet(petName)
        local out = false
        if okModel and model and petName and UnitExists("pet") and Safe(UnitName("pet")) == petName then
            out = pcall(model.SetUnit, model, "pet")
            if out then
                model.skaldZoom, model.skaldAngle = 1.3, 0.6
                pcall(model.SetCamDistanceScale, model, model.skaldZoom)
                pcall(model.SetFacing, model, model.skaldAngle)
            end
        end
        if model then model:SetShown(out) end
        placeholder:SetShown(not out)
    end

    PageHeading(panel, L.PETS_ALL, K.RIGHT_X)
    local rows = {}
    for i = 1, 12 do
        local top = -66 - (i - 1) * 36
        local a = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
        a:SetPoint("TOPLEFT", K.RIGHT_X, top)
        a:SetWidth(K.CW)
        a:SetJustifyH("LEFT")
        a:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        local b = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        b:SetPoint("TOPLEFT", K.RIGHT_X, top - 17)
        b:SetWidth(K.CW)
        b:SetJustifyH("LEFT")
        b:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
        rows[i] = { a, b }
    end
    local empty = NoteText(panel, 0, -80)
    local total = NoteText(panel, K.RIGHT_X, -420)

    local facts = { famV, famL, lvlV, lvlL, dietV, dietL, sinceV, sinceL }
    local function ShowFacts(on)
        for _, fs in ipairs(facts) do fs:SetShown(on) end
    end

    return function()
        pcall(Mile.CheckPet)   -- the pet may have changed since the last look (a new name, a new pet)
        local db = Journal()
        local pets, list = (db and db.pets) or {}, {}
        for pname, rec in pairs(pets) do list[#list + 1] = { name = pname, rec = rec } end
        table.sort(list, function(x, y) return (x.rec.t or 0) > (y.rec.t or 0) end)
        -- Who is at the side now: only a pet that is really out. With none out (a loaned pet that left,
        -- one that was dismissed) the page says so and names the last one.
        local out = db and db.petNow and pets[db.petNow] and { name = db.petNow, rec = pets[db.petNow] } or nil
        empty:SetShown(#list == 0)
        nowLabel:SetText(out and L.PETS_NOW or L.PETS_NONE_NOW)
        lastLine:SetText("")
        if #list == 0 then
            empty:SetText(L.PETS_NONE)
            name:SetText(""); total:SetText("")
            icon:Hide(); ShowFacts(false)
            ShowPet(nil)
        elseif not out then
            icon:Hide(); ShowFacts(false)
            name:SetText("")
            lastLine:SetText(string.format(L.PETS_LAST, list[1].name))
            total:SetText(string.format(L.PETS_TOTAL, #list))
            ShowPet(nil)
        else
            local rec = out.rec
            icon:Show(); ShowFacts(true)
            name:SetText(out.name)
            famV:SetText(rec.fam or "-")
            lvlV:SetText((rec.lv and rec.lv > 0) and tostring(rec.lv) or "-")
            dietV:SetText(rec.diet or "-")
            sinceV:SetText(date(L.DAY_DATE, rec.t or time()))
            total:SetText(string.format(L.PETS_TOTAL, #list))
            ShowPet(out.name)
        end
        for i = 1, 12 do
            local item = list[i]
            if item then
                rows[i][1]:SetText(item.name)
                local parts = {}
                if item.rec.fam then parts[#parts + 1] = item.rec.fam end
                if item.rec.lv and item.rec.lv > 0 then parts[#parts + 1] = string.format(L.TIP_LEVEL, item.rec.lv) end
                parts[#parts + 1] = date(L.DAY_DATE, item.rec.t or time())
                rows[i][2]:SetText(table.concat(parts, "  -  "))
                rows[i][1]:Show(); rows[i][2]:Show()
            else
                rows[i][1]:Hide(); rows[i][2]:Hide()
            end
        end
    end
end

-- /skald petinfo (with the pet out) records which pet functions this client really has and what they
-- answer, to find where the diet and the happiness of a pet can be read from (read it after /reload).
Mile.PetInfo = function()
    local info = { t = time(), out = UnitExists("pet") and true or false }
    local function many(fn)
        local ok, r = pcall(function() return { fn() } end)
        if not ok then return "error: " .. tostring(r) end
        local parts = {}
        for i = 1, math.min(#r, 12) do parts[#parts + 1] = tostring(r[i]) end
        return #parts > 0 and table.concat(parts, " | ") or "(nothing)"
    end
    local function dump(v, depth)
        if type(v) ~= "table" then return tostring(v) end
        if (depth or 0) >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 14 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. "=" .. dump(x, (depth or 0) + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    local function call(tbl, name, ...)
        local f = _G[tbl] and _G[tbl][name]
        if type(f) ~= "function" then return "(no such function)" end
        local args = { ... }
        local ok, r = pcall(function() return { f(unpack(args)) } end)
        if not ok then return "error: " .. tostring(r) end
        local parts = {}
        for i = 1, math.min(#r, 8) do parts[#parts + 1] = dump(r[i], 0) end
        return #parts > 0 and table.concat(parts, " | ") or "(nothing)"
    end
    info.C_PetInfo_calls = {
        GetPetFoodTypes = call("C_PetInfo", "GetPetFoodTypes"),
        GetPetHappiness = call("C_PetInfo", "GetPetHappiness"),
        GetPetLoyalty = call("C_PetInfo", "GetPetLoyalty"),
        GetPetTrainingPoints = call("C_PetInfo", "GetPetTrainingPoints"),
        GetPetTalentTree = call("C_PetInfo", "GetPetTalentTree"),
    }
    info.C_StableInfo_calls = {
        GetActivePetList = call("C_StableInfo", "GetActivePetList"),
        GetNumActivePets = call("C_StableInfo", "GetNumActivePets"),
        GetStablePetInfo1 = call("C_StableInfo", "GetStablePetInfo", 1),
        GetStablePetFoodTypes1 = call("C_StableInfo", "GetStablePetFoodTypes", 1),
    }
    info.GetPetTimeRemaining = type(GetPetTimeRemaining) == "function" and many(GetPetTimeRemaining) or type(GetPetTimeRemaining)
    info.answers = {
        GetPetFoodTypes = type(GetPetFoodTypes) == "function" and many(GetPetFoodTypes) or type(GetPetFoodTypes),
        GetPetHappiness = type(GetPetHappiness) == "function" and many(GetPetHappiness) or type(GetPetHappiness),
        GetPetTrainingPoints = type(GetPetTrainingPoints) == "function" and many(GetPetTrainingPoints) or type(GetPetTrainingPoints),
        GetPetExperience = type(GetPetExperience) == "function" and many(GetPetExperience) or type(GetPetExperience),
        HasPetUI = type(HasPetUI) == "function" and many(HasPetUI) or type(HasPetUI),
        UnitCreatureType = many(function() return UnitCreatureType("pet") end),
        UnitCreatureFamily = many(function() return UnitCreatureFamily("pet") end),
    }
    -- every global that looks like a pet function, and what the pet tables hold
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and (k:find("^GetPet") or k:find("^C_Pet") or k:find("^C_Stable") or k:find("Pet.*Food") or k:find("Food.*Pet")
            or k:find("^PetCan") or k:find("^CastPet")) then
            names[#names + 1] = k .. " (" .. type(v) .. ")"
        end
    end
    table.sort(names)
    info.names = names
    for _, tname in ipairs({ "C_PetInfo", "C_StableInfo" }) do
        local t = _G[tname]
        if type(t) == "table" then
            local keys = {}
            for k in pairs(t) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            info[tname] = keys
        end
    end
    Settings().petProbe = info
    return info
end

Mile.SetNext = function(text)
    local db = Journal()
    if not db then return end
    db.resume = db.resume or {}
    text = strtrim(text or "")
    db.resume.next = (text ~= "") and text:sub(1, 120) or nil
    Say(text ~= "" and L.NEXT_SAVED or L.NEXT_CLEARED)
end

-- /skald probe spells keeps what the client reports about learned spells and pets in SkaldDB, to
-- settle which class milestones can be told (read it after /reload).
Mile.ProbeEvent = function(event, ...)
    local s = Settings()
    if not s.probeSpells then return end
    s.spellLog = s.spellLog or {}
    local rec = { t = time(), ev = event, lvl = UnitLevel and UnitLevel("player") }
    for i = 1, math.min(select("#", ...), 4) do
        local v = Safe((select(i, ...)))
        rec[i] = (type(v) == "string" or type(v) == "number" or type(v) == "boolean") and v or tostring(v)
    end
    if event == "LEARNED_SPELL_IN_TAB" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellId = tonumber(event == "UNIT_SPELLCAST_SUCCEEDED" and rec[3] or rec[1])
        if spellId then
            local name
            if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellId)
            elseif GetSpellInfo then name = GetSpellInfo(spellId) end
            rec.spell = Safe(name)
        end
    elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" or event == "CONFIRM_XP_LOSS" or event == "RESURRECT_REQUEST" then
        rec.dead = UnitIsDead and UnitIsDead("player") or false
        rec.ghost = UnitIsGhost and UnitIsGhost("player") or false
        rec.zone = GetZoneText and GetZoneText()
    elseif event == "UNIT_PET" then
        rec.pet = UnitExists("pet") and Safe(UnitName("pet")) or false
        pcall(function() rec.fam = Safe(UnitCreatureFamily("pet")) end)
        rec.petLevel = UnitLevel("pet")
    end
    table.insert(s.spellLog, rec)
    while #s.spellLog > 200 do table.remove(s.spellLog, 1) end
end
end

-- The zone-level map (the land, not a district or a city quarter) that a map belongs to; cached.
do
local zoneIds = {}
ns.ZoneIdOfMap = function(mapID)
    if type(mapID) ~= "number" then return nil end
    if zoneIds[mapID] ~= nil then return zoneIds[mapID] or nil end
    local result = false
    pcall(function()
        if not (C_Map and C_Map.GetMapInfo) then return end
        local id = mapID
        for _ = 1, 8 do
            local info = C_Map.GetMapInfo(id)
            if not info or info.mapType == 4 then return end
            if info.mapType and info.mapType <= 3 then
                if info.mapType == 3 then result = id end
                return
            end
            if not info.parentMapID or info.parentMapID == 0 then return end
            id = info.parentMapID
        end
    end)
    zoneIds[mapID] = result
    return result or nil
end
ns.ZoneIdOfEntry = function(e)
    local id = (type(e.m) == "number" and e.m) or e.zm
    return id and ns.ZoneIdOfMap(id) or nil
end

-- What the diary holds about each land: first visit, quests, falls, foes, levels, items, favourites.
-- Counted once per change of the pages, then read by zone id.
local stats, statsSig
ns.RegionStats = function(zoneId)
    local db = Journal()
    if not db or not zoneId then return nil end
    local sig = #db.entries .. ":" .. (ns.layoutRev or 0)
    if sig ~= statsSig then
        stats, statsSig = {}, sig
        for _, e in ipairs(db.entries) do
            local id = ns.ZoneIdOfEntry(e)
            if id and e.kind ~= "day" then
                local z = stats[id]
                if not z then z = { first = e.t, total = 0, quest = 0, death = 0, boss = 0, level = 0, loot = 0, fav = 0 }; stats[id] = z end
                z.total = z.total + 1
                if e.t and (not z.first or e.t < z.first) then z.first = e.t end
                if e.kind == "quest" then z.quest = z.quest + 1
                elseif e.kind == "death" then z.death = z.death + 1
                elseif e.kind == "boss" or e.kind == "dungeon" then z.boss = z.boss + 1
                elseif e.kind == "level" or e.kind == "milestone" then z.level = z.level + 1
                elseif e.kind == "loot" then z.loot = z.loot + 1 end
                if e.fav then z.fav = z.fav + 1 end
            end
        end
    end
    return stats[zoneId]
end

-- Favourite memories: a star on a page, with a note of one's own.
ns.FavoritesChanged = function()
    ns.layoutRev = (ns.layoutRev or 0) + 1
    if window and window:IsShown() then window:Refresh() end
    if SkaldAPI and SkaldAPI.favHook then pcall(SkaldAPI.favHook) end
end
ns.ToggleFavorite = function(e)
    if not e then return end
    if e.fav then e.fav, e.favNote = nil, nil else e.fav = true end
    ns.FavoritesChanged()
end
ns.EditFavNote = function(e)
    if e then StaticPopup_Show("SKALD_FAVNOTE", nil, nil, e) end
end
SkaldAPI.OpenEntry = function(e) return window and window:OpenEntry(e) or false end
SkaldAPI.Session = function() return loginTime end
SkaldAPI.RegionStats = ns.RegionStats
SkaldAPI.ZoneIdOfMap = ns.ZoneIdOfMap
SkaldAPI.ToggleFavorite = ns.ToggleFavorite
SkaldAPI.EditFavNote = ns.EditFavNote
end

-- One function per event, looked up by name (instead of a long chain of comparisons).
local EVENT_HANDLERS = {}
do
local H = EVENT_HANDLERS
H.ADDON_LOADED = function(self, event, ...)
    local name = ...
    if name ~= ADDON_NAME then return end
    SkaldDB = SkaldDB or {}
    SkaldDB.version = SkaldDB.version or 1
    ApplyFonts()   -- the saved text size (the files ran before the saved variables loaded)
    SkaldCharDB = SkaldCharDB or {}
    local db = SkaldCharDB
    db.entries = db.entries or {}
    db.visited = db.visited or {}
    db.flags = db.flags or {}
    MigrateStats(db)
end

H.PLAYER_LOGIN = function(self, event, ...)
    loginTime = time()
    if EnsureOwnDiary() then Say(L.NEW_CHARACTER) end
    ConvertOldNotes()
    -- Positions saved before were kept with fifteen decimals: shortened once.
    do
        local db = Journal()
        if db and not db.posRounded then
            for _, e in ipairs(db.entries) do
                if type(e.x) == "number" then e.x = math.floor(e.x * 10000 + 0.5) / 10000 end
                if type(e.y) == "number" then e.y = math.floor(e.y * 10000 + 0.5) / 10000 end
            end
            db.posRounded = true
        end
    end
    sessionMark = time()
    RollDay()   -- closes any earlier day with a summary page
    window = CreateWindow()
    for _, t in ipairs(pendingTabs) do window:AddTab(t[1], t[2], t[3]) end
    pendingTabs = {}
    do
        local okClass, _, classFile = pcall(UnitClass, "player")
        if okClass and classFile == "HUNTER" then window:AddTab("pets", L.TAB_PETS, Mile.BuildPets) end
    end
    lastZone = GetZoneText()
    VisitZone(lastZone)
    C_Timer.After(8, function()
        lastXP, lastXPLevel = ReadXP()
        ready = true
        CheckGuild()
        CheckSkills()
        CheckReputation()
        CheckMarks()
        pcall(Mile.CheckPet)
        pcall(Mile.MergeCrafts)
        pcall(Mile.Relocalize)
        C_Timer.After(10, function() pcall(Mile.Relocalize) end)   -- items load a little later
        if C_Timer.NewTicker then C_Timer.NewTicker(60, function() pcall(CheckMarks); pcall(Mile.CheckPet) end) end
        C_Timer.After(2, function() pcall(Mile.ShowResume) end)
    end)
    if not Settings().quiet then
        Say(L.LOADED)
    end
end

H.PLAYER_LOGOUT = function(self, event, ...)
    -- Bank this session's time on the road, and where the creature count stands.
    pcall(Mile.SaveResume)
    BankPlayed()
    do
        local log = Journal()
        local day = log and log.days and log.days[log.today or ""]
        local count = day and KillStat()
        if count then day.kEnd = count end
    end
    local db = Journal()
    if db and loginTime then
        db.stats.played = db.stats.played + (time() - loginTime)
        loginTime = nil
    end
end

H.ZONE_CHANGED_NEW_AREA = function(self, event, ...)
    if window then CheckZone() end
end
H.PLAYER_ENTERING_WORLD = H.ZONE_CHANGED_NEW_AREA

-- What the quest asks, in the client's own language: from the quest dialog when it is offered, and from the
-- quest log when it is handed in. Kept by quest id until the quest is turned in.
K.OBJECTIVE_KEPT = 150
ns.NoteObjective = function(event)
    if event == "QUEST_COMPLETE" then ns.pendingObjective = nil end
    local id = GetQuestID and tonumber(GetQuestID()) or nil
    local text = Safe(GetObjectiveText and GetObjectiveText())
    if (type(text) ~= "string" or text == "") and id and id > 0 then
        pcall(function()
            local index = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
            if index and GetQuestLogQuestText then
                local _, objectives = GetQuestLogQuestText(index)
                text = objectives
            end
        end)
    end
    if type(text) ~= "string" or text == "" then return end
    text = text:sub(1, 400)
    if event == "QUEST_COMPLETE" then ns.pendingObjective = text end
    local db = Journal()
    if db and id and id > 0 then
        db.questObj = db.questObj or {}
        db.questObj[id] = text
        local n = 0
        for _ in pairs(db.questObj) do n = n + 1 end
        if n > K.OBJECTIVE_KEPT then
            for k in pairs(db.questObj) do if k ~= id then db.questObj[k] = nil; break end end
        end
    end
end

H.QUEST_DETAIL = function(self, event, ...)
    pendingQuestTitle = GetTitleText()
    pcall(ns.NoteObjective, event)
    pendingNPC = Safe(UnitName and UnitName("npc")) or pendingNPC
    Mile.npcId = Mile.NpcId("npc") or Mile.npcId
    if event == "QUEST_COMPLETE" then
        local id = GetQuestID and GetQuestID()
        if id and id ~= 0 then
            if C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
                pendingQuestLevel = Try(C_QuestLog.GetQuestDifficultyLevel, id)
            end
            -- What the quest asked for, while it is still in the log.
            pendingObjectiveTypes = nil
            if C_QuestLog and C_QuestLog.GetQuestObjectives then
                local objectives = Try(C_QuestLog.GetQuestObjectives, id)
                if type(objectives) == "table" then
                    pendingObjectiveTypes = {}
                    for _, o in ipairs(objectives) do
                        pendingObjectiveTypes[#pendingObjectiveTypes + 1] = o.type
                    end
                end
            end
        end
    end
end
H.QUEST_COMPLETE = H.QUEST_DETAIL

-- The day a quest was accepted (kept, so the end of its chain can tell how long the story took).
-- The event gives the quest id alone (Mainline) or the log index and then the id (Classic).
H.QUEST_ACCEPTED = function(self, event, a, b)
    local id = tonumber(b) or tonumber(a)
    local db = Journal()
    if not id or id <= 0 or not db then return end
    db.questStart = db.questStart or {}
    if db.questStart[id] then return end
    db.questStart[id] = time()
    local n = 0
    for _ in pairs(db.questStart) do n = n + 1 end
    if n > K.QUEST_START_MAX then
        local cut = time() - K.QUEST_START_DAYS * 86400
        for k, t in pairs(db.questStart) do if t < cut then db.questStart[k] = nil end end
    end
end

H.PLAYER_XP_UPDATE = function(self, event, ...)
    if ready then OnXPChanged() end
end

H.QUEST_TURNED_IN = function(self, event, ...)
    lastQuestAt = Clock()
    local questID, xpReward, moneyReward = ...
    local tier, signals = QuestTier(questID, xpReward)
    local qtype = QuestTypeFromDB(questID) or QuestTypeFromObjectives(pendingObjectiveTypes)
    signals.qtype = qtype
    ProbeQuest(questID, xpReward, moneyReward, tier, signals)
    local minTier = Settings().minTier or K.DETAIL_MIN_TIER[Settings().detail or "normal"] or K.DETAIL_MIN_TIER.normal
    if tier >= minTier then
        -- A quest that ends a chain remembers how long the chain was.
        local cend
        if signals.qdb and (signals.chainBack or 0) >= 1 and (signals.chainFwd or 0) == 0 then
            cend = signals.chainBack + 1
        end
        -- The days since the chain began (the first quest of it that the diary saw being accepted).
        local since
        local starts = Journal() and Journal().questStart
        if cend and starts then
            local first = starts[questID]
            for _, pid in ipairs(signals.chainIds or {}) do
                if starts[pid] and (not first or starts[pid] < first) then first = starts[pid] end
            end
            if first then since = math.floor((time() - first) / 86400) end
            if since and since < 1 then since = nil end
        end
        AddEntry("quest", QuestName(questID), nil,
            { tier = tier, q = questID, npc = pendingNPC, qtype = qtype or false, cend = cend, since = since,
              ot = (type(ns.pendingObjective) == "string" and ns.pendingObjective ~= "" and ns.pendingObjective)
                  or (Journal() and Journal().questObj and Journal().questObj[questID]) or nil,
              ql = pendingQuestLevel, pl = UnitLevel and UnitLevel("player"), nid = Mile.npcId })
    else
        CountOnly("quest", tier)
    end
    pendingQuestTitle, pendingNPC, pendingQuestLevel = nil, nil, nil
    ns.pendingObjective = nil
    if Journal() and Journal().questObj then Journal().questObj[questID] = nil end
    pendingObjectiveTypes = nil
    Mile.npcId = nil
end

H.PLAYER_LEVEL_UP = function(self, event, ...)
    local level = tonumber((...))
    if level and level % 10 == 0 then
        AddEntry("milestone", level)
    else
        AddEntry("level", level)
    end
    if ready then C_Timer.After(3, function() pcall(Mile.CheckPet) end) end
end

H.UNIT_SPELLCAST_SUCCEEDED = function(self, event, ...)
    -- The Hearthstone (item 6948) casts spell 8690. A page only when it takes the character
    -- somewhere else: using it while already at the inn's place writes nothing.
    local unit, _, spellID = ...
    if ready and unit == "player" and Safe(spellID) == 8690 then
        local okBind, bind = pcall(GetBindLocation)
        bind = okBind and Safe(bind) or nil
        local here = GetZoneText()
        if type(bind) == "string" and bind ~= "" and bind ~= here then
            AddEntry("hearth", bind, nil, { m = false, x = false, y = false })
        end
    end
end

H.CONFIRM_XP_LOSS = function(self, event, ...)
    Mile.healerAt = time()   -- the spirit healer is offering to bring the character back
end

H.PLAYER_UNGHOST = function(self, event, ...)
    -- Seen in the client: PLAYER_ALIVE when the spirit is released, CONFIRM_XP_LOSS when the
    -- healer's offer is accepted, and PLAYER_UNGHOST a moment later.
    if ready then
        local fromHealer = Mile.healerAt and (time() - Mile.healerAt) < 120
        Mile.healerAt = nil
        local where = GetZoneText()
        if not where or where == "" then where = L.UNKNOWN_ZONE end
        AddEntry("revive", where, nil, { sub = fromHealer and "healer" or "corpse" })
    end
end

H.PLAYER_ALIVE = function(self, event, ...)
    -- only recorded by the probe (above)
end
H.RESURRECT_REQUEST = H.PLAYER_ALIVE

H.UNIT_PET = function(self, event, ...)
    if ready and (...) == "player" then C_Timer.After(1.5, function() pcall(Mile.CheckPet) end) end
end

H.UNIT_NAME_UPDATE = function(self, event, ...)
    if ready and (...) == "pet" then C_Timer.After(0.5, function() pcall(Mile.CheckPet) end) end
end

H.LEARNED_SPELL_IN_TAB = function(self, event, ...)
    -- only recorded by the probe (above)
end

H.CHAT_MSG_LOOT = function(self, event, ...)
    if ready then pcall(OnLoot, ...) end
end

H.PLAYER_DEAD = function(self, event, ...)
    -- The zone text can be empty at the moment of death: fall back to the minimap's.
    local where = GetZoneText()
    if not where or where == "" then where = GetMinimapZoneText and GetMinimapZoneText() end
    if not where or where == "" then where = L.UNKNOWN_ZONE end
    AddEntry("death", where)
    pcall(NoteFall)
end

H.PLAYER_GUILD_UPDATE = function(self, event, ...)
    if ready then CheckGuild() end
end

-- Coming back to a land where something worth remembering happened: a quiet notice, now and then.
-- Pages that qualify: favourites, the first pet of a hunter, a boss that cost some falls.
K.MEMORY_ZONE_DAYS, K.MEMORY_GAP, K.MEMORY_AFTER_LOGIN, K.MEMORY_MIN_AGE = 7, 600, 20, 86400
local function Remembered(e)
    if e.fav then return "memoryFav", 2 end
    if e.kind == "tame" and e.sub == "first" then return "memoryTame", 1 end
    if e.kind == "boss" and (e.tries or 0) >= 2 then return "memoryBoss", 1 end
end
ns.CheckMemory = function()
    local db = Journal()
    if not ready or not db or Settings().memories == false or not window then return end
    local now = time()
    if loginTime and now - loginTime < K.MEMORY_AFTER_LOGIN then return end
    if now - (Mile.lastMemory or 0) < K.MEMORY_GAP then return end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return end
    if IsInInstance and IsInInstance() then return end
    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    local zid = okMap and ns.ZoneIdOfMap(mapID) or nil
    if not zid then return end
    db.memoryAt = db.memoryAt or {}
    if now - (db.memoryAt[zid] or 0) < K.MEMORY_ZONE_DAYS * 86400 then return end
    -- the pages of this land that deserve it, favourites first
    local best, bestRank, bestPool
    for _, e in ipairs(db.entries) do
        local pool, rank = Remembered(e)
        if pool and now - (e.t or now) >= K.MEMORY_MIN_AGE and ns.ZoneIdOfEntry(e) == zid then
            if not best or rank > bestRank or (rank == bestRank and math.random(2) == 1) then best, bestRank, bestPool = e, rank, pool end
        end
    end
    if not best then return end
    db.memoryAt[zid] = now
    Mile.lastMemory = now
    local text = best.fav and type(best.favNote) == "string" and best.favNote ~= "" and ("\"" .. best.favNote .. "\"")
    if not text then
        local list = PHRASES[bestPool]
        if not list or #list == 0 then return end
        Mile.memoryIdx = Mile.memoryIdx or {}
        local idx = math.random(#list)
        if #list > 1 and idx == Mile.memoryIdx[bestPool] then idx = idx % #list + 1 end
        Mile.memoryIdx[bestPool] = idx
        text = string.format(list[idx], tostring(ns.ZoneNameOfMap(zid) or best.zone or L.UNKNOWN_ZONE))
    end
    ns.ShowNotice(L.MEMORY_TITLE, text, 3, 9, best)
end

-- Someone I shared a dungeon with has joined my group again after a while: the page tells where we were.
K.REUNION_GAP, K.REUNION_EVERY = 86400, 3 * 86400
Mile.reunionTold = {}
Mile.CheckReunion = function()
    local db = Journal()
    if not ready or not db or Settings().companions == false then return end
    if not (IsInGroup and IsInGroup()) then Mile.reunionTold = {}; return end
    local comp = db.companions
    if not comp then return end
    local now = time()
    for i = 1, 4 do
        local name = (not UnitExists or UnitExists("party" .. i)) and Safe(UnitName and UnitName("party" .. i)) or nil
        local c = type(name) == "string" and comp[name]
        if c and c.shared and not Mile.reunionTold[name] then
            Mile.reunionTold[name] = true
            local away = now - math.max(c.last or 0, c.seen or 0)
            c.seen = now
            if away >= K.REUNION_GAP and now - (c.told or 0) >= K.REUNION_EVERY then
                c.told = now
                AddEntry("reunion", name, nil, { pz = c.pz, pn = c.pn })
            end
        end
    end
end

H.GROUP_ROSTER_UPDATE = function(self, event, ...)
    local db = Journal()
    if not Mile.reunionWait then
        Mile.reunionWait = true
        C_Timer.After(3, function() Mile.reunionWait = false; pcall(Mile.CheckReunion) end)
    end
    if ready and db and not db.flags.party and IsInGroup() then
        db.flags.party = true
        AddEntry("party")
    end
end

H.ENCOUNTER_END = function(self, event, ...)
    local _, name, _, _, success = ...
    if success == 1 then BossDown(name) end
end

H.BOSS_KILL = function(self, event, ...)
    local _, name = ...
    BossDown(name)
end

H.HEARTHSTONE_BOUND = function(self, event, ...)
    local ok, where = pcall(GetBindLocation)
    where = ok and Safe(where) or nil
    if ready then AddEntry("home", (type(where) == "string" and where ~= "") and where or (GetZoneText() or "?"), nil, { m = false, x = false, y = false }) end
end

H.UPDATE_FACTION = function(self, event, ...)
    if ready and not ns.repPending then
        ns.repPending = true
        C_Timer.After(2, CheckReputation)
    end
end

H.TAXIMAP_OPENED = function(self, event, ...)
    if ready then pcall(CheckFlightPaths) end
end

H.PLAYER_MONEY = function(self, event, ...)
    -- Money changes on every sale and pick-up: one look at the milestones is enough per few seconds.
    if ready and not ns.moneyPending then
        ns.moneyPending = true
        C_Timer.After(3, function() ns.moneyPending = false; CheckMarks() end)
    end
end

H.NEW_MOUNT_ADDED = function(self, event, ...)
    local mountID = ...
    local ok, name = pcall(function()
        return (C_MountJournal.GetMountInfoByID(mountID))
    end)
    name = ok and Safe(name) or nil
    if name then AddEntry("mount", name) end
end

H.ACHIEVEMENT_EARNED = function(self, event, ...)
    local achievementID = ...
    local ok, name = pcall(function()
        return (select(2, GetAchievementInfo(achievementID)))
    end)
    name = ok and Safe(name) or nil
    if name then AddEntry("achievement", name) end
end

H.SKILL_LINES_CHANGED = function(self, event, ...)
    -- Fires in bursts; look once, shortly after the last.
    if ready and not skillPending then
        skillPending = true
        C_Timer.After(2, CheckSkills)
    end
end

end

local function HandleEvent(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if (...) == "player" and Settings().probeSpells then pcall(Mile.ProbeEvent, event, ...) end
    elseif event == "UNIT_PET" or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE"
        or event == "CONFIRM_XP_LOSS" or event == "RESURRECT_REQUEST" then
        pcall(Mile.ProbeEvent, event, ...)
    end
    local handler = EVENT_HANDLERS[event]
    if handler then handler(self, event, ...) end
end

-- A failing event must not stop the others: it is reported once (and kept in SkaldDB.lastError
-- for a bug report) and the diary carries on.
local reported = {}
frame:SetScript("OnEvent", function(self, event, ...)
    local ok, err = pcall(HandleEvent, self, event, ...)
    if not ok then
        local report = tostring(event) .. ": " .. tostring(err)
        if not reported[report] then
            reported[report] = true
            if SkaldDB then SkaldDB.lastError = report end
            Say("|cffff6060" .. L.ERROR_PREFIX .. "|r " .. report)
        end
    end
end)


-- Spoken minimap menu ----------------------------------------------------------

local function ToggleWindow()
    if not window then return end
    if window:IsShown() then
        window:Hide()
    else
        window:Refresh()
        window:Show()
    end
end

-- Adds "Skald" to Spoken's minimap button menu. Spoken lists an unknown
-- source with its own on/off switch, so this registers a silent source.
local function RegisterWithSpoken()
    if not (SpokenReady() and Spoken.RegisterSource and Spoken.Minimap
            and Spoken.Minimap.AddEntry) then
        return
    end
    pcall(function()
        if not Spoken:GetSource("skald") then
            Spoken:RegisterSource("skald", {
                title = TITLE,
                addon = ADDON_NAME,
                order = 90,
            })
        end
        Spoken.Minimap:AddEntry("skald", {
            id = "Skald",
            text = L.OPEN_JOURNAL,
            order = 1,
            onClick = ToggleWindow,
        })
    end)
end

-- Own minimap button (LibDataBroker + LibDBIcon). Spoken embeds both; without
-- them there is simply no button and /skald keeps working.
K.MINIMAP_NAME = "Skald"

-- Without those libraries (Skald installed alone) the addon makes a round button of its own on the
-- edge of the minimap: click to open the book, drag to move it around the minimap.
ns.CreateOwnMinimapButton = function()
    if ns.minimapButton or not Minimap then return ns.minimapButton end
    local s = Settings()
    s.minimap = s.minimap or {}
    local b = CreateFrame("Button", "SkaldMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    local back = b:CreateTexture(nil, "BACKGROUND")
    back:SetSize(22, 22)
    back:SetPoint("CENTER", 0, 1)
    back:SetColorTexture(0.10, 0.06, 0.03, 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\AddOns\\Skald\\icon.tga")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function Place()
        local angle = math.rad(s.minimap.angle or 215)
        local radius = (Minimap:GetWidth() or 140) / 2 + 5
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
            s.minimap.angle = math.deg(atan2(cy - my, cx - mx))
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function() ToggleWindow() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(L.MINIMAP_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    b:SetShown(not s.minimap.hide)
    ns.minimapButton = b
    return b
end

local function RegisterMinimapButton()
    local stub = _G.LibStub
    local ldb = stub and stub("LibDataBroker-1.1", true)
    local dbIcon = stub and stub("LibDBIcon-1.0", true)
    if not (ldb and dbIcon) then
        pcall(ns.CreateOwnMinimapButton)
        return
    end

    local s = Settings()
    s.minimap = s.minimap or {}

    local object = ldb:GetDataObjectByName(K.MINIMAP_NAME) or ldb:NewDataObject(K.MINIMAP_NAME, {
        type = "launcher",
        text = TITLE,
        icon = "Interface\\AddOns\\Skald\\icon.tga",
        OnClick = function() ToggleWindow() end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(TITLE, 1, 0.82, 0)
            tooltip:AddLine(L.MINIMAP_TIP, 1, 1, 1)
        end,
    })
    if not dbIcon:IsRegistered(K.MINIMAP_NAME) then
        dbIcon:Register(K.MINIMAP_NAME, object, s.minimap)
    end
end

-- The button of the minimap glows for a few seconds when a page is written.
PulseMinimap = function()
    local stub = _G.LibStub
    local dbIcon = stub and stub("LibDBIcon-1.0", true)
    local button = dbIcon and dbIcon:IsRegistered(K.MINIMAP_NAME) and dbIcon:GetMinimapButton(K.MINIMAP_NAME)
    button = button or ns.minimapButton
    if not button then return end
    if not button.skaldGlow then
        local glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetPoint("CENTER")
        glow:SetSize(52, 52)
        glow:SetTexture("Interface\\Cooldown\\star4")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 0.85, 0.4)
        glow:Hide()
        button.skaldGlow = glow
    end
    local glow = button.skaldGlow
    glow:Show()
    local started = (GetTime and GetTime()) or 0
    button:SetScript("OnUpdate", function(self)
        local elapsed = ((GetTime and GetTime()) or 0) - started
        if elapsed > 8 then
            glow:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        glow:SetAlpha(0.45 + 0.45 * math.sin(elapsed * 5))
    end)
end

local function SetMinimapButtonShown(show)
    local stub = _G.LibStub
    local dbIcon = stub and stub("LibDBIcon-1.0", true)
    if ns.minimapButton then
        Settings().minimap = Settings().minimap or {}
        Settings().minimap.hide = not show
        ns.minimapButton:SetShown(show and true or false)
        return true
    end
    if not (dbIcon and dbIcon:IsRegistered(K.MINIMAP_NAME)) then return false end
    Settings().minimap.hide = not show
    if show then dbIcon:Show(K.MINIMAP_NAME) else dbIcon:Hide(K.MINIMAP_NAME) end
    return true
end

-- Export -----------------------------------------------------------------------
-- The diary as text to copy (an addon cannot write files or post to Discord). Pages go
-- oldest first, in parts that fit a Discord message.
K.EXPORT_LIMIT = 1900   -- Discord takes 2000 characters a message; the rest is margin

local function PlainText(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return s
end

-- "Notable": rare quests and above, and the events that mark a journey.
K.NOTABLE_KINDS = {
    milestone = true, dungeon = true, boss = true, achievement = true,
    mount = true, guild = true, day = true, note = true,
}
local function IsNotable(e)
    if e.kind == "quest" then return (e.tier or 1) >= 3 end
    return K.NOTABLE_KINDS[e.kind] == true
end

local function SelectEntries(scope)
    local all = Journal().entries
    local picked = {}
    if scope == "all" then
        for _, e in ipairs(all) do picked[#picked + 1] = e end
    elseif scope == "notable" then
        for _, e in ipairs(all) do
            if IsNotable(e) then picked[#picked + 1] = e end
        end
    else
        for i = math.max(1, #all - 14), #all do picked[#picked + 1] = all[i] end
    end
    return picked
end

local function ExportBlock(e, format)
    local head = date(L.DATE_FMT, e.t) .. " - " .. PlainText(ns.PlaceName(e))
    if e.kind == "quest" and e.tier and e.tier >= 2 and L.TIERS[e.tier] then
        head = head .. "  -  " .. L.TIERS[e.tier]
    end
    local body = PlainText(RenderEntry(e))
    if format == "discord" then
        return "> **" .. head .. "**\n> " .. body
    end
    return "[" .. head .. "]\n" .. body
end

-- Returns a list of texts, each short enough for one message (empty when there is nothing).
local function BuildExport(format, scope)
    local entries = SelectEntries(scope)
    if #entries == 0 then return {} end

    local name = UnitName and UnitName("player") or "?"
    local level = UnitLevel and UnitLevel("player") or 0
    local class = (UnitClass and UnitClass("player")) or ""
    local title = PlainText(string.format(L.EXPORT_HEADER, name, level, class))
    local blocks = { format == "discord" and ("**" .. title .. "**") or title }
    for _, e in ipairs(entries) do blocks[#blocks + 1] = ExportBlock(e, format) end

    local chunks, current = {}, ""
    for _, block in ipairs(blocks) do
        if #block > K.EXPORT_LIMIT then block = block:sub(1, K.EXPORT_LIMIT) end
        if #current > 0 and #current + #block + 2 > K.EXPORT_LIMIT then
            chunks[#chunks + 1] = current
            current = ""
        end
        current = current .. block .. "\n\n"
    end
    if #current > 0 then chunks[#chunks + 1] = current end

    if #chunks > 1 then
        for i, chunk in ipairs(chunks) do
            local marker = string.format(L.EXPORT_PART, i, #chunks)
            chunks[i] = (format == "discord" and ("*" .. marker .. "*") or marker) .. "\n" .. chunk
        end
    end
    return chunks
end
SkaldAPI.BuildExport = BuildExport

local exportFrame
local function ShowExport()
    if exportFrame then
        exportFrame:Refresh()
        exportFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "SkaldExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 400)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropBorderColor(0.35, 0.22, 0.10, 1)
    local paper = f:CreateTexture(nil, "BACKGROUND")
    paper:SetPoint("TOPLEFT", 4, -4)
    paper:SetPoint("BOTTOMRIGHT", -4, 4)
    paper:SetColorTexture(0.86, 0.77, 0.58, 1)
    tinsert(UISpecialFrames, "SkaldExportFrame")

    local title = f:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    title:SetPoint("TOP", 0, -14)
    title:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
    title:SetText(L.EXPORT_TITLE)
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 20, -42)
    rule:SetPoint("TOPRIGHT", -20, -42)
    rule:SetHeight(1)
    rule:SetColorTexture(0.35, 0.22, 0.10, 0.7)
    CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)

    local function Label(text, x, y)
        local fs = f:CreateFontString(nil, "OVERLAY", "QuestFont")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
        fs:SetText(text)
        return fs
    end

    local settings = Settings()
    local format = settings.exportFormat or "discord"
    local scope = settings.exportScope or "recent"
    local part, chunks = 1, {}

    -- Choosers: one button per choice, the chosen one lit.
    local formatButtons, scopeButtons = {}, {}
    Label(L.EXPORT_FORMAT, 20, -58)
    for i, choice in ipairs({ { "discord", L.FORMAT_DISCORD }, { "plain", L.FORMAT_PLAIN } }) do
        local b = MakeParchmentButton(f, 120, 24, choice[2])
        b:SetPoint("TOPLEFT", 110 + (i - 1) * 124, -54)
        b:SetScript("OnClick", function() format = choice[1]; settings.exportFormat = format; part = 1; f:Refresh() end)
        formatButtons[choice[1]] = b
    end
    Label(L.EXPORT_SCOPE, 20, -90)
    for i, choice in ipairs({ { "recent", L.SCOPE_RECENT }, { "notable", L.SCOPE_NOTABLE }, { "all", L.SCOPE_ALL } }) do
        local b = MakeParchmentButton(f, 100, 24, choice[2])
        b:SetPoint("TOPLEFT", 110 + (i - 1) * 104, -86)
        b:SetScript("OnClick", function() scope = choice[1]; settings.exportScope = scope; part = 1; f:Refresh() end)
        scopeButtons[choice[1]] = b
    end

    -- Parts, when the text is longer than one message.
    local prev = MakeParchmentButton(f, 34, 24, "<")
    prev:SetPoint("TOPLEFT", 20, -120)
    prev:SetScript("OnClick", function() part = math.max(1, part - 1); f:Refresh() end)
    local nextButton = MakeParchmentButton(f, 34, 24, ">")
    nextButton:SetPoint("TOPLEFT", 60, -120)
    nextButton:SetScript("OnClick", function() part = math.min(#chunks, part + 1); f:Refresh() end)
    local partLabel = f:CreateFontString(nil, "OVERLAY", "QuestFont")
    partLabel:SetPoint("LEFT", nextButton, "RIGHT", 10, 0)
    partLabel:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])

    -- The text: dark box, light letters, selected so Ctrl+C is all that is left to do.
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 20, -152)
    box:SetPoint("BOTTOMRIGHT", -20, 62)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0.12, 0.08, 0.04, 0.92)
    box:SetBackdropBorderColor(0.35, 0.22, 0.10, 1)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(430)
    edit:SetTextInsets(2, 2, 2, 2)
    scroll:SetScrollChild(edit)
    local shown = ""
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    -- Read only: anything typed is put back.
    edit:SetScript("OnTextChanged", function(self, byUser)
        if byUser then self:SetText(shown); self:HighlightText() end
    end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 22, 16)
    hint:SetWidth(456)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.15, 0.10, 0.04)
    hint:SetText(L.EXPORT_HINT)

    function f:Refresh()
        chunks = BuildExport(format, scope)
        part = math.max(1, math.min(part, math.max(1, #chunks)))
        shown = chunks[part] or L.EXPORT_EMPTY
        edit:SetText(shown)
        -- Tall enough for the text, so the scroll frame can scroll it.
        local _, newlines = shown:gsub("\n", "")
        edit:SetHeight(math.max(260, (newlines + math.ceil(#shown / 62) + 2) * 14))
        scroll:SetVerticalScroll(0)
        edit:HighlightText()
        for key, b in pairs(formatButtons) do b:SetActive(key == format) end
        for key, b in pairs(scopeButtons) do b:SetActive(key == scope) end
        local many = #chunks > 1
        prev:SetShown(many)
        nextButton:SetShown(many)
        partLabel:SetText(many and string.format(L.EXPORT_PART, part, #chunks) or "")
    end

    exportFrame = f
    f:Refresh()
    f:Show()
end


-- Options tab ------------------------------------------------------------------
local function BuildOptions(panel)
    local refresh
    local function Redraw()
        refresh()
        if window then window:Refresh() end
    end

    -- A row of six rarity seals: the chosen one is circled, the ones below it are faded.
    local function SealRow(y, set)
        local row = {}
        for tier = 0, 5 do
            local b = CreateFrame("Button", nil, panel)
            b:SetSize(34, 34)
            b:SetPoint("TOPLEFT", tier * 56 + 4, y)
            local ring = MakeDisc(b, "BACKGROUND", 44, K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3], 0)
            ring:SetPoint("CENTER", 0, 0)
            local inner = MakeDisc(b, "BACKGROUND", 40, 0.93, 0.87, 0.72, 1)
            inner:SetPoint("CENTER", 0, 0)
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexture(K.SEAL_PATH .. tier)
            b.ring, b.inner, b.icon = ring, inner, icon
            b:SetScript("OnClick", function() set(tier); Redraw() end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(L.TIERS[tier] or tostring(tier))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row[tier] = b
        end
        return row
    end
    local function ShowSeals(row, chosen)
        for t, b in pairs(row) do
            b.ring:SetShown(t == chosen)
            b.inner:SetShown(t == chosen)
            b.icon:SetAlpha(t >= chosen and 1 or 0.4)
        end
    end

    -- Left page: what the quill records, and from which rarity.
    PageHeading(panel, L.TAB_OPTIONS, 0)
    SectionLabel(panel, L.OPT_RECORDS, 0, -52)
    local boxes = {}
    for i, key in ipairs({ "quest", "level", "death", "boss", "zone", "profession", "loot" }) do
        local cb = MakeWaxCheck(panel, L.REC_NAMES[key],
            function() return (Settings().rec or {})[key] ~= false end,
            function(on)
                Settings().rec = Settings().rec or {}
                Settings().rec[key] = on and true or false
            end, nil, nil, 171)
        cb:SetPoint("TOPLEFT", ((i - 1) % 2) * 171, -78 - math.floor((i - 1) / 2) * 24)
        boxes[#boxes + 1] = cb
    end

    SectionLabel(panel, L.OPT_TIER, 0, -184)
    local questSeals = SealRow(-208, function(tier) Settings().minTier = tier end)
    local hint = NoteText(panel, 0, -248)

    SectionLabel(panel, L.OPT_LOOT, 0, -272)
    local lootSeals = SealRow(-296, function(tier) Settings().lootTier = tier end)
    local lootHint = NoteText(panel, 0, -336)

    -- Diaries set aside when another character took this name.
    SectionLabel(panel, L.OPT_ARCHIVE, 0, -360)
    local info = NoteText(panel, 0, -380)
    local restore = MakeFlatButton(panel, 166, 26, L.BTN_RESTORE)
    restore:SetPoint("TOPLEFT", 0, -410)
    restore:SetScript("OnClick", function()
        if RestoreLatestArchive() then
            Say(L.ARCHIVE_RESTORED)
            if window then window:Refresh() end
        end
    end)
    local discard = MakeFlatButton(panel, 166, 26, L.BTN_DISCARD)
    discard:SetPoint("TOPLEFT", 176, -410)
    discard:SetScript("OnClick", function() StaticPopup_Show("SKALD_DISCARD") end)

    -- Right page: the page itself, and the switches.
    PageHeading(panel, L.OPT_PAGE, K.RIGHT_X)
    SectionLabel(panel, L.OPT_SIZE, K.RIGHT_X, -52)
    local sizeButtons = {}
    for i = 0, 2 do
        local b = MakeFlatButton(panel, 114, 26, L.SIZE_NAMES[i + 1])
        b:SetPoint("TOPLEFT", K.RIGHT_X + i * 114, -76)
        b:SetScript("OnClick", function() Settings().textSize = i; ApplyFonts(); Redraw() end)
        sizeButtons[i] = b
    end

    SectionLabel(panel, L.OPT_INK, K.RIGHT_X, -116)
    local inkBoxes = {}
    for i = 0, 2 do
        local c = K.INKS[i + 1]
        local cb = MakeWaxCheck(panel, L.INK_NAMES[i + 1],
            function() return (Settings().ink or 0) == i end,
            function() Settings().ink = i; Redraw() end, nil, c, 114)
        cb:SetPoint("TOPLEFT", K.RIGHT_X + i * 114, -140)
        inkBoxes[#inkBoxes + 1] = cb
    end

    SectionLabel(panel, L.OPT_DAYMODE, K.RIGHT_X, -180)
    local modeButtons = {}
    for i = 0, 1 do
        local b = MakeFlatButton(panel, 171, 26, L.DAYMODE_NAMES[i + 1])
        b:SetPoint("TOPLEFT", K.RIGHT_X + i * 171, -204)
        b:SetScript("OnClick", function() Settings().dayMode = i; Redraw() end)
        modeButtons[i] = b
    end

    local switches = {
        MakeWaxCheck(panel, L.OPT_CLOSING,
            function() return Settings().closing ~= false end,
            function(on) Settings().closing = on and true or false end),
        MakeWaxCheck(panel, L.OPT_SOUND,
            function() return Settings().sound ~= false end,
            function(on) Settings().sound = on and true or false end),
        MakeWaxCheck(panel, L.OPT_LOOTGEAR,
            function() return Settings().lootGear ~= false end,
            function(on) Settings().lootGear = on and true or false end),
        MakeWaxCheck(panel, L.OPT_MINIMAP,
            function() return not (Settings().minimap and Settings().minimap.hide) end,
            function(on) SetMinimapButtonShown(on) end),
        MakeWaxCheck(panel, L.OPT_QUIET,
            function() return not Settings().quiet end,
            function(on) Settings().quiet = not on end),
        MakeWaxCheck(panel, L.OPT_COMPANIONS,
            function() return Settings().companions ~= false end,
            function(on) Settings().companions = on and true or false end),
        MakeWaxCheck(panel, L.OPT_MEMORIES,
            function() return Settings().memories ~= false end,
            function(on) Settings().memories = on and true or false end),
    }
    for i, cb in ipairs(switches) do cb:SetPoint("TOPLEFT", K.RIGHT_X, -244 - (i - 1) * 23) end

    local exportButton = MakeFlatButton(panel, 166, 28, L.EXPORT_BTN, "gold")
    exportButton:SetPoint("TOPLEFT", K.RIGHT_X, -410)
    exportButton:SetScript("OnClick", function() ShowExport() end)
    local erase = MakeFlatButton(panel, 166, 28, L.BTN_ERASE, "burn")
    erase:SetPoint("TOPLEFT", K.RIGHT_X + 176, -410)
    erase:SetScript("OnClick", function() StaticPopup_Show("SKALD_CLEAR") end)

    refresh = function()
        local s = Settings()
        local tier = s.minTier or K.DETAIL_MIN_TIER[s.detail or "normal"] or 1
        ShowSeals(questSeals, tier)
        hint:SetText(string.format(L.TIER_HINT, L.TIERS[tier] or tostring(tier)))
        local loot = s.lootTier or K.LOOT_MIN_TIER
        ShowSeals(lootSeals, loot)
        lootHint:SetText(string.format(L.LOOT_HINT, L.TIERS[loot] or tostring(loot)))
        for _, cb in ipairs(boxes) do cb.Sync() end
        for _, cb in ipairs(inkBoxes) do cb.Sync() end
        for _, cb in ipairs(switches) do cb.Sync() end
        for i, b in pairs(sizeButtons) do b:SetActive(i == (s.textSize or 1)) end
        for i, b in pairs(modeButtons) do b:SetActive(i == (s.dayMode or 0)) end

        local archive = Journal() and Journal().previous or {}
        local count = #archive
        if count > 0 then
            local latest = archive[count]
            info:SetText(string.format(L.ARCHIVE_LATEST, count,
                date(L.DATE_FMT, latest.t or 0), latest.entries and #latest.entries or 0)
                .. "\n" .. L.ARCHIVE_HINT)
        else
            info:SetText(L.ARCHIVE_NONE)
        end
        for _, b in ipairs({ restore, discard }) do
            b:SetAlpha(count > 0 and 1 or 0.4)
            b:EnableMouse(count > 0)
        end
    end
    return refresh
end
SkaldAPI.AddTab("options", L.TAB_OPTIONS, BuildOptions)

local function BuildStyle(panel)
    local refresh
    local function Redraw()
        refresh()
        if window then window:Refresh() end
    end

    -- Left page: the narrator's voice.
    PageHeading(panel, L.TAB_STYLE, 0)
    SectionLabel(panel, L.OPT_TONE, 0, -52)
    local toneButtons = {}
    for i, key in ipairs({ "epic", "humble", "humor" }) do
        local b = MakeFlatButton(panel, 114, 26, L.TONE_NAMES[key])
        b:SetPoint("TOPLEFT", (i - 1) * 114, -78)
        b:SetScript("OnClick", function() Settings().tone = key; Redraw() end)
        toneButtons[key] = b
    end
    local toneHint = NoteText(panel, 0, -114)
    SectionLabel(panel, L.TONE_SAMPLE_LABEL, 0, -168)
    local sample = panel:CreateFontString(nil, "OVERLAY", "SkaldNote")
    sample:SetPoint("TOPLEFT", 0, -192)
    sample:SetWidth(K.CW)
    sample:SetJustifyH("LEFT")
    sample:SetJustifyV("TOP")
    sample:SetWordWrap(true)
    sample:SetTextColor(K.C_NOTE[1], K.C_NOTE[2], K.C_NOTE[3])

    -- Right page: the cover, and the notices.
    PageHeading(panel, L.OPT_COVER, K.RIGHT_X)
    SectionLabel(panel, L.OPT_COLOR, K.RIGHT_X, -52)
    local SWATCH = {
        brown = { 0.42, 0.26, 0.15 }, blue = { 0.25, 0.35, 0.65 }, green = { 0.25, 0.5, 0.28 },
        wine = { 0.55, 0.15, 0.18 }, grey = { 0.45, 0.46, 0.52 }, faction = { 0.85, 0.7, 0.3 },
    }
    local colorBoxes = {}
    for i, key in ipairs({ "brown", "blue", "green", "wine", "grey", "faction" }) do
        local cb = MakeWaxCheck(panel, L.COVER_COLORS[key],
            function() return ((Settings().cover or "brown") == key) end,
            function()
                Settings().cover = key
                if window then window:ApplyCover() end
                refresh()
            end, nil, SWATCH[key], 114)
        cb:SetPoint("TOPLEFT", K.RIGHT_X + ((i - 1) % 3) * 114, -78 - math.floor((i - 1) / 3) * 28)
        colorBoxes[#colorBoxes + 1] = cb
    end

    SectionLabel(panel, L.OPT_COVERTITLE, K.RIGHT_X, -150)
    local edit = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    edit:SetSize(K.CW, 28)
    edit:SetPoint("TOPLEFT", K.RIGHT_X, -176)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(28)
    edit:SetFontObject("SkaldBody")
    edit:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    edit:SetBackdropColor(1, 0.97, 0.88, 0.2)
    edit:SetBackdropBorderColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 1)
    local function SaveTitle()
        local text = (edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        Settings().coverTitle = (text ~= "") and text or nil
        if window then window:Refresh() end
    end
    edit:SetScript("OnEnterPressed", function(self) SaveTitle(); self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:SetText(Settings().coverTitle or ""); self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", SaveTitle)
    NoteText(panel, K.RIGHT_X, -210):SetText(L.COVERTITLE_HINT)

    local switches = {
        MakeWaxCheck(panel, L.OPT_TOAST,
            function() return Settings().toast ~= false end,
            function(on) Settings().toast = on and true or false end),
        MakeWaxCheck(panel, L.OPT_MARKS,
            function() return (Settings().rec or {}).mark ~= false end,
            function(on)
                Settings().rec = Settings().rec or {}
                Settings().rec.mark = on and true or false
            end),
        MakeWaxCheck(panel, L.OPT_RESUME,
            function() return Settings().resume ~= false end,
            function(on) Settings().resume = on and true or false end),
    }
    for i, cb in ipairs(switches) do cb:SetPoint("TOPLEFT", K.RIGHT_X, -262 - (i - 1) * 28) end
    -- Where the notices appear: a sample to drag to the place you like.
    local placeButtons = {}
    for i, key in ipairs({ "top", "left", "bottom" }) do
        local pb = MakeFlatButton(panel, 72, 26, L["TOAST_" .. key:upper()])
        pb:SetPoint("TOPLEFT", K.RIGHT_X + (i - 1) * 74, -352)
        pb:SetScript("OnClick", function()
            Settings().toastAnchor = key
            Settings().toastPos = nil
            for k, other in pairs(placeButtons) do other:SetActive(k == key) end
            if ns.PreviewNotice then ns.PreviewNotice() end
        end)
        placeButtons[key] = pb
    end
    local moveButton = MakeFlatButton(panel, 220, 26, L.TOAST_MOVE)
    moveButton:SetPoint("TOPLEFT", K.RIGHT_X, -384)
    moveButton:SetScript("OnClick", function() if ns.PreviewNotice then ns.PreviewNotice() end end)
    moveButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.TOAST_MOVE, 1, 0.82, 0)
        GameTooltip:AddLine(L.TOAST_MOVE_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    moveButton:HookScript("OnLeave", function() GameTooltip:Hide() end)

    refresh = function()
        local s = Settings()
        local tone = s.tone or "epic"
        for key, b in pairs(toneButtons) do b:SetActive(key == tone) end
        toneHint:SetText(L.TONE_HINT[tone] or "")
        sample:SetText(L.TONE_SAMPLE[tone] or "")
        for _, cb in ipairs(colorBoxes) do cb.Sync() end
        for _, cb in ipairs(switches) do cb.Sync() end
        for key, pb in pairs(placeButtons) do pb:SetActive(not s.toastPos and (s.toastAnchor or "top") == key) end
        if not edit:HasFocus() then edit:SetText(s.coverTitle or "") end
    end
    return refresh
end
SkaldAPI.AddTab("style", L.TAB_STYLE, BuildStyle)

local spokenHook = CreateFrame("Frame")
spokenHook:RegisterEvent("PLAYER_LOGIN")
spokenHook:SetScript("OnEvent", function()
    RegisterWithSpoken()
    RegisterMinimapButton()
end)

-- Commands -------------------------------------------------------------------

SLASH_SKALD1 = "/skald"
SLASH_SKALD2 = "/sk"
SlashCmdList["SKALD"] = function(msg)
    if not window then return end
    local raw = strtrim(msg or "")
    msg = raw:lower()
    if msg == "next" or msg:match("^next%s") then
        Mile.SetNext(raw:sub(5))
    elseif msg == "petinfo" then
        local info = Mile.PetInfo()
        Say(string.format("pet out: %s; %d pet functions found. Food: %s. Type /reload to save the report.",
            tostring(info.out), #info.names, tostring(info.C_PetInfo_calls.GetPetFoodTypes)))
    elseif msg:match("^forgetpet") then
        -- /skald forgetpet <name>: takes a companion out of the list (a loaned pet, a duplicate).
        local target = strtrim(raw:sub(10))
        local db = Journal()
        local removed
        for pname in pairs((db and db.pets) or {}) do
            if pname:lower() == target:lower() then
                db.pets[pname] = nil
                if db.petNow == pname then db.petNow = nil end
                removed = pname
                break
            end
        end
        Say(removed and (removed .. ": removed from the companions.") or "no companion with that name (/skald forgetpet <name>).")
    elseif msg == "forgetcompanions" then
        local db = Journal()
        if db then db.companions = nil end
        Mile.reunionTold = {}
        Say("the companions I remembered are forgotten.")
    elseif msg == "tidy" then
        pcall(Mile.Relocalize)
        Say(string.format("%d repeated page(s) removed.", Mile.Tidy()))
    elseif msg == "resume" then
        for _, line in ipairs(Mile.ResumeLines() or {}) do Say(line) end
    elseif msg == "probe spells" or msg == "probe spells off" then
        Settings().probeSpells = (msg == "probe spells")
        Say(Settings().probeSpells and L.PROBE_SPELLS_ON or L.PROBE_SPELLS_OFF)
    elseif msg == "clear" then
        StaticPopup_Show("SKALD_CLEAR")
    elseif msg == "quiet" then
        local s = Settings()
        s.quiet = not s.quiet
        Say(s.quiet and L.QUIET_ON or L.QUIET_OFF)
    elseif msg:match("^detail") then
        local choice = strtrim(msg:sub(7))
        if K.DETAIL_MIN_TIER[choice] then
            Settings().detail = choice
            Settings().minTier = nil
            Say(string.format(L.DETAIL_SET, choice))
        else
            Say(string.format(L.DETAIL_BAD, Settings().detail or "normal"))
        end
    elseif msg == "qa" then
        if window then
            window:Show()
            local ok, issues = pcall(window.QA, window)
            if ok then
                Say(string.format("layout audit: %d issue(s). Type /reload to save the report.", #issues))
                for i = 1, math.min(#issues, 10) do Say("  " .. issues[i]) end
            else
                Say("the audit failed: " .. tostring(issues))
            end
        end
    elseif msg == "stats" then
        -- Lists every statistic the game keeps for this character into SkaldDB.statDump (read it
        -- after /reload): the ids are the same in every language, so the diary can use them.
        local dump = {}
        local ok = pcall(function()
            for _, cat in ipairs(GetStatisticsCategoryList()) do
                for i = 1, GetCategoryNumAchievements(cat) do
                    local id, name = GetAchievementInfo(cat, i)
                    if id then
                        dump[#dump + 1] = { cat = cat, id = id, name = name, value = GetStatistic(id) }
                    end
                end
            end
        end)
        Settings().statDump = dump
        Say(ok and string.format("%d statistics listed. Type /reload to save them.", #dump) or "could not read the statistics.")
    elseif msg:match("^probe") then
        local arg = strtrim(msg:sub(6))
        if arg == "clear" then
            Settings().probeLog = nil
            Say(L.PROBE_CLEARED)
        else
            Settings().probe = (arg ~= "off")
            Say(Settings().probe and L.PROBE_ON or L.PROBE_OFF)
        end
    elseif msg == "minimap" then
        local shown = Settings().minimap and Settings().minimap.hide
        if SetMinimapButtonShown(shown and true or false) then
            Say(shown and L.MINIMAP_ON or L.MINIMAP_OFF)
        else
            Say(L.MINIMAP_NONE)
        end
    elseif msg == "export" then
        ShowExport()
    elseif msg == "help" or msg == "?" then
        Say(L.HELP)
    else
        ToggleWindow()
    end
end
