-- Skald
-- Automatically writes an epic chronicle of your journey.
-- Logs: first visit to a zone, quest turned in, level up, death.

local ADDON_NAME, ns = ...

-- Constants live in one table: the main chunk of a Lua file may hold only 200 locals.
local K = {}

-- Keep byte limits without cutting through a UTF-8 character (accents, CJK, etc.).
K.TextPrefix = function(text, limit)
    if #text <= limit then return text end
    local nextByte = limit + 1
    while nextByte > 1 do
        local b = text:byte(nextByte)
        if b < 128 or b >= 192 then break end
        nextByte = nextByte - 1
    end
    return text:sub(1, nextByte - 1)
end

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
    goal        = { 0.65, 0.40, 0.00 },
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
    if SkaldAPI.entryHook then SkaldAPI.entryHook(kind) end
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
local CONTEXT_KINDS = { dungeon = true, boss = true, death = true, zone = true, level = true,
    hearth = true, revive = true, flight = true, home = true, mount = true }   -- the hour of the day, for the line that sets the scene
local WITH_KINDS = { dungeon = true, boss = true, death = true }
-- Another player is told apart by name and by the second part the client gives (the realm in the classic game;
-- in the realmless Forever it comes back as the surname, even for players of one's own world): the key kept in
-- the diary is "Name-Surname", the page tells only the name (K.WhoShort).
K.WhoKey = function(unit)
    if not UnitName then return nil end
    local name, realm = UnitName(unit)
    name, realm = Safe(name), Safe(realm)
    if type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then return name .. "-" .. realm end
    return name
end
K.WhoShort = function(key)
    key = tostring(key or "")
    return key:match("^([^%-]+)%-") or key
end
ns.WhoShort = K.WhoShort

-- What surrounded the moment: the hour of the game, the names in the group, the pet.
AddContext = function(kind, entry)
    if not CONTEXT_KINDS[kind] then return end
    local okTime, hour = pcall(GetGameTime)
    if okTime and type(hour) == "number" then entry.hr = hour end
    if WITH_KINDS[kind] then
        local names = {}
        if IsInGroup and IsInGroup() then
            for i = 1, 4 do
                local who = (not UnitExists or UnitExists("party" .. i)) and K.WhoKey("party" .. i) or nil
                if who then names[#names + 1] = who end
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
    local pick = keys[math.random(#keys)]
    -- A pool of two or three lines repeats at once: it is used in proportion to its size, up to K.FLAVOR_FULL lines.
    local size = #PHRASES[pick]
    if size < K.FLAVOR_FULL and math.random() > size / K.FLAVOR_FULL then return nil end
    return pick
end

K.FLAVOR_FULL = 8   -- the lines a class or race pool needs to be drawn as often as the plain ones
K.CRAFT_MERGE = 1200   -- seconds: making the same thing again within this time adds to the page of the last one
K.QUEST_START_MAX, K.QUEST_START_DAYS = 300, 60   -- quests whose acceptance is kept, and for how long
K.MODEL_REUSE, K.MODEL_RETRY = 20, { 1.5, 4 }   -- seconds: the cover model is not asked for again within K.MODEL_REUSE; retries after the first request
-- How far the camera stands from the model on the cover: the tall races (the Tauren is taller than the arch) are shown from
-- further away so head and hands stay inside the frame.
K.COVER_ZOOM, K.COVER_ZOOM_BY_RACE = 0.8, { Tauren = 1.0 }
K.COVER_UNDRESS = { 16, 17, 18 }   -- inventory slots of the weapons
function ns.CoverZoom()
    local _, raceFile = UnitRace("player")
    return K.COVER_ZOOM_BY_RACE[raceFile or ""] or K.COVER_ZOOM
end
K.GHOST_ART = { epic = "ghost_candle", humble = "ghost_wisp", humor = "ghost_rip" }   -- the picture of the cover for a spirit, by voice
K.FALLS_FORGOTTEN = 7200   -- seconds after the last fall in a dungeon, when it no longer counts for a boss

-- Which pages the diary writes at all (Options: What the quill records).
K.RECORD_FLAG = {
    quest = "quest", level = "level", milestone = "level", death = "death",
    boss = "boss", dungeon = "boss", zone = "zone", skill = "profession", profession = "profession",
    loot = "loot", mark = "mark", home = "mark", rep = "mark", flight = "zone", tame = "mark", revive = "death", hearth = "mark",
}

-- Entries store the event type, its argument and which phrase was drawn;
-- the text is rendered when the window is shown.
-- Permanent progress for the goals that used to be counted from the pages left in the diary: a page that leaves
-- at the cap no longer takes its share with it. Days are kept as a set of dates, so a date seen again counts once.
K.STATS_SCHEMA = 1
K.Tally = function(stats, e)
    local kind = e.kind
    if kind == "quest" then
        if (e.cend or 0) >= 2 then stats.chains = (stats.chains or 0) + 1 end
    elseif kind == "boss" then
        if (e.tries or 0) >= 1 then stats.hardBoss = (stats.hardBoss or 0) + 1 end
    elseif kind == "tame" then
        if e.sub == "level" then stats.petLevel = (stats.petLevel or 0) + 1 end
    elseif kind == "reunion" then
        stats.reunions = (stats.reunions or 0) + 1
    elseif kind == "guild" then
        stats.guild = 1
    end
    if type(e.t) == "number" then
        local d = date("%Y%m%d", e.t)
        stats.dayset = stats.dayset or {}
        if not stats.dayset[d] then
            stats.dayset[d] = true
            stats.daysN = (stats.daysN or 0) + 1
        end
    end
end

-- A favourite or a line written by hand is the reader's own: the cap never takes it.
K.IsPersonal = function(e) return e.fav or e.kind == "note" end

-- Keeps the diary to the cap by letting the oldest pages go, leaving the personal ones. When only those are left
-- the diary stays above the cap: nothing the reader kept is ever deleted. Done in place, as other code holds the table.
K.Trim = function(db)
    local entries = db.entries
    local n = #entries
    local drop = n - MAX_ENTRIES
    if drop > 0 then
        local w = 0
        for i = 1, n do
            local e = entries[i]
            if drop > 0 and not K.IsPersonal(e) then
                drop = drop - 1
            else
                w = w + 1
                entries[w] = e
            end
        end
        for i = n, w + 1, -1 do entries[i] = nil end
        -- inserting a page and dropping an older one leaves the count and the last page as they were
        if w < n then ns.layoutRev = (ns.layoutRev or 0) + 1 end
    end
    if #entries > MAX_ENTRIES and not K.overWarned then
        K.overWarned = true
        Say(string.format(L.OVER_CAP, MAX_ENTRIES))
    end
end

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
    if kind == "quest" and K.PickFact then K.PickFact(db, entry) end
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
    K.Trim(db)

    -- Lifetime counters survive the entry cap.
    local stats = db.stats
    K.Tally(stats, entry)
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
    if SkaldAPI.entryHook then SkaldAPI.entryHook(kind) end
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

-- Words that agree with the one who speaks (the diary is in the first person): {g:he-form|she-form} is
-- written once in the phrase and the character's sex picks the form, as in "tombé{g:|e}".
ns.Gendered = function(text)
    if type(text) ~= "string" or not text:find("{g:", 1, true) then return text end
    local female = UnitSex and UnitSex("player") == 3
    return (text:gsub("{g:([^|}]*)|([^}]*)}", function(masculine, feminine) return female and feminine or masculine end))
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
    return ns.Gendered(text .. " " .. L.DAY_CLOSE[mood])
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
-- A quest page can carry one more sentence about the moment, told only when something about it is true:
-- a fall just before, a long absence, the first quest of the day, the tenth, a fat purse, a quest far above or
-- far below one's level. The page keeps the key (xk), the phrase number (xi) and the number the phrase names
-- (xv); the text is built live, as for everything else. A key is not told again within the last three quests.
K.FACT_ORDER = { "fallen", "back", "first", "milestone", "rich", "above", "below" }
K.FACT_RECENT = 3
K.PickFact = function(db, e)
    local day = db.days and db.days[db.today or ""]
    local before = day and day.q or 0   -- the quests of this day counted before this one
    local entries = db.entries
    local last, fell, recent, quests = nil, false, {}, 0
    for i = #entries, math.max(1, #entries - 60), -1 do
        local p = entries[i]
        if p.kind ~= "day" then
            last = last or p
            if p.kind == "death" and e.t - p.t <= 1200 then fell = true end
            if p.kind == "quest" and quests < K.FACT_RECENT then
                quests = quests + 1
                if p.xk then recent[p.xk] = true end
            end
        end
    end
    local have = {
        fallen = fell,
        back = last and e.t - last.t >= 129600,
        first = before == 0,
        milestone = (before + 1) % 10 == 0,
        rich = type(e.mr) == "number" and e.mr >= 10000,
        above = type(e.ql) == "number" and type(e.pl) == "number" and e.ql - e.pl >= 3,
        below = type(e.ql) == "number" and type(e.pl) == "number" and e.pl - e.ql >= 8,
    }
    local value = {
        milestone = before + 1,
        rich = type(e.mr) == "number" and math.floor(e.mr / 10000) or nil,
        above = type(e.ql) == "number" and type(e.pl) == "number" and e.ql - e.pl or nil,
        below = type(e.ql) == "number" and type(e.pl) == "number" and e.pl - e.ql or nil,
    }
    for _, key in ipairs(K.FACT_ORDER) do
        local list = PHRASES["fact_" .. key]
        if have[key] and not recent[key] and list and #list > 0 then
            db.recentIdx = db.recentIdx or {}
            local mem = "fact:" .. key
            local seen = db.recentIdx[mem] or {}
            local keep = math.min(5, #list - 1)
            local idx = math.random(#list)
            for _ = 1, 30 do
                local again = false
                for i = math.max(1, #seen - keep + 1), #seen do if seen[i] == idx then again = true; break end end
                if not again then break end
                idx = math.random(#list)
            end
            seen[#seen + 1] = idx
            while #seen > 5 do table.remove(seen, 1) end
            db.recentIdx[mem] = seen
            e.xk, e.xi, e.xv = key, idx, value[key]
            return
        end
    end
end
K.FactText = function(e)
    local list = e.xk and PHRASES["fact_" .. e.xk]
    if not list or #list == 0 then return "" end
    local text = list[((e.xi or 1) - 1) % #list + 1]
    text = text:gsub("{diff}", function() return tostring(e.xv or "") end)
    text = text:gsub("{gold}", function() return tostring(e.xv or "") end)
    text = text:gsub("{nth}", function() return tostring(e.xv or "") end)
    return " " .. ns.Gendered(text)
end
Extras = function(e)
    local out = ""
    local idx = e.idx or 1
    if e.kind == "quest" and e.xk then out = K.FactText(e) end
    if type(e.with) == "table" and #e.with > 0 then
        local names = {}
        for i, who in ipairs(e.with) do names[i] = K.WhoShort(who) end
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
        local fam = ns.FamilyLabel and ns.FamilyLabel((rec and rec.fam) or e.fam) or (rec and rec.fam) or e.fam
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

-- A quest is written down with the title the client gave that day. When the game's language changes, ask
-- the client (or the quest database) for the title in the language of now; failing that, keep what was written.
local questTitles = {}
local function QuestTitleNow(e)
    local id = e.q
    if not id then return e.arg end
    local hit = questTitles[id]
    if hit == nil then
        hit = false
        pcall(function()
            local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
            if type(t) ~= "string" or t == "" then
                local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
                local q = qdb and qdb:GetQuest(id)
                t = type(q) == "table" and (q.title or q.name) or nil
            end
            if type(t) == "string" and t ~= "" then hit = t end
        end)
        if hit then questTitles[id] = hit end   -- only a real answer is kept; the client may know more later
    end
    return hit or e.arg
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
            text = text:gsub("{quest}", function() return tostring(QuestTitleNow(e)) end)
            return ns.Gendered((text:gsub("{npc}", function() return npc end)))
        end
    end

    local list = PoolFor(e)
    if not list then return "" end
    local shown = tostring(e.kind == "quest" and QuestTitleNow(e) or e.arg)
    if (e.kind == "zone" or e.kind == "death" or e.kind == "revive") and e.arg == e.zone then shown = tostring(ns.PlaceName(e) or e.arg) end
    if e.kind == "goal" and ns.GoalName then shown = ns.GoalName(e.arg) end
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
    -- what a goal reached is worth belongs to the page itself, so the notice tells it too
    local gain = ""
    if e.kind == "goal" and ns.GoalPoints and L.GOAL_GAIN then
        local points = ns.GoalPoints(e.arg)
        if points then gain = " " .. string.format(L.GOAL_GAIN, points) end
    end
    return ns.Gendered(text) .. gain .. (e.noExtras and "" or Extras(e))
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
    -- Progress the goals read from the pages is kept apart from them, so it no longer shrinks when old pages leave.
    -- Done once per schema, from the pages still there; the highest of the two is kept, so nothing counted drops.
    if (s.sv or 0) < K.STATS_SCHEMA then
        local seen = {}
        for _, e in ipairs(db.entries) do K.Tally(seen, e) end
        for _, key in ipairs({ "chains", "hardBoss", "petLevel", "reunions", "guild" }) do
            s[key] = math.max(s[key] or 0, seen[key] or 0)
        end
        s.dayset = s.dayset or {}
        for d in pairs(seen.dayset or {}) do s.dayset[d] = true end
        local days = 0
        for _ in pairs(s.dayset) do days = days + 1 end
        s.daysN = math.max(s.daysN or 0, days)
        s.sv = K.STATS_SCHEMA
    end
    db.version = DB_VERSION
end

-- Empties the whole diary: pages, zones seen, counters, and what was remembered
-- about guild, group and professions, so everything is detected afresh.
-- Everything else the diary knows about one character (pets, companions, flight paths, goals, standings...).
-- It is set aside with the pages and brought back with them, and emptied with them, so a cleared diary or a new
-- character with an old name never inherits it.
K.DIARY_STATE = { "pets", "petNow", "companions", "questObj", "questStart", "visitedMaps", "resume", "attempts",
    "taxi", "marks", "goals", "goalsInit", "goalsVer", "collInit", "rep", "memoryAt", "recentIdx", "anniv", "zoneKills", "killBase" }

local function TakeState(db)
    local state = {}
    for _, key in ipairs(K.DIARY_STATE) do state[key] = db[key] end
    return state
end

local function ResetJournal(db)
    for _, key in ipairs(K.DIARY_STATE) do db[key] = nil end
    db.entries, db.visited, db.flags = {}, {}, {}
    db.days, db.today = nil, nil
    db.skills, db.skillsInit = nil, nil
    db.guild, db.guildSeen = nil, nil
    db.lastIdx = nil
    db.stats, db.version = nil, nil
    MigrateStats(db)
    ns.layoutRev = (ns.layoutRev or 0) + 1
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
            visited = db.visited, stats = db.stats, state = TakeState(db) })
        while #db.previous > 3 do table.remove(db.previous, 1) end
        ResetJournal(db)
    end
    if guid then db.guid = guid end
    return different
end

-- Brings back the most recently archived diary. The diary in use goes to the archive in
-- its place, so nothing is lost either way. Returns true when something was restored.
-- What describes the moment of play and not the book is not brought back with a diary: the flags, the day in
-- progress and the professions are looked at afresh (silently), and the guild is read again right now, so restoring
-- does not write a "joined" page or a day twice. Used after an archive or a backup is put in place.
ns.ReadAfresh = function(db)
    db.flags = {}
    db.days, db.today = nil, nil            -- the days of the restored diary are not kept
    db.skills, db.skillsInit = nil, nil     -- professions are looked at afresh, silently
    db.lastIdx = nil
    db.guild = (GetGuildInfo and GetGuildInfo("player")) or false
    db.guildSeen = true
    MigrateStats(db)
end

local function RestoreLatestArchive()
    local db = Journal()
    local archive = db and db.previous
    if not archive or #archive == 0 then return false end
    local old = table.remove(archive)

    if #db.entries > 0 then
        table.insert(archive, { guid = db.guid, t = time(), entries = db.entries,
            visited = db.visited, stats = db.stats, state = TakeState(db) })
        while #archive > 3 do table.remove(archive, 1) end
    end

    db.entries = old.entries or {}
    db.visited = old.visited or {}
    db.stats = old.stats
    -- An archive made before this state was kept has none: those parts start afresh (and are read silently).
    for _, key in ipairs(K.DIARY_STATE) do db[key] = old.state and old.state[key] or nil end
    -- Without that state the map keys of the zones are made again from the old pages (else a zone told under its
    -- name in another language would be written twice).
    if not old.state then db.mapKeysDone = nil end
    db.version = DB_VERSION                  -- counters are already right: no recount
    ns.ReadAfresh(db)
    ns.layoutRev = (ns.layoutRev or 0) + 1   -- the pages are other ones, whatever their count and last page
    return true
end

ns.RestoreLatestArchive = RestoreLatestArchive

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
    reunion = "party", goal = "goal",
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
    b.label = label

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
        -- the chosen plate gives off a soft amber light
        if type(rawget(self, "glow")) ~= "table" then
            self.glow = self:CreateTexture(nil, "ARTWORK")
            self.glow:SetPoint("TOPLEFT", 2, -2)
            self.glow:SetPoint("BOTTOMRIGHT", -2, 2)
            self.glow:SetColorTexture(0.95, 0.65, 0.2, 0.18)
            self.glow:SetBlendMode("ADD")
        end
        self.glow:SetShown(self.active)
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
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", self.textX or 0, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", self.textX or 0, 0) end)

    -- The label lives in our own text; the button's native SetText would write to a font string it does not have.
    function b:SetText(label)
        self.text:SetText(label)
        self.label = label
        self:Relayout()
    end
    -- An icon before the label: icon and word sit together in the middle of the button (the icon alone when there is no word).
    function b:SetIcon(path, size)
        self.iconTex = rawget(self, "iconTex") or self:CreateTexture(nil, "OVERLAY")
        self.iconSize = size or 20
        self.iconTex:SetSize(self.iconSize, self.iconSize)
        self.iconTex:SetTexture(path)
        self:Relayout()
    end
    function b:Relayout()
        if not rawget(self, "iconTex") then return end
        local tw = 0
        if self.label and self.label ~= "" then
            tw = self.text.GetStringWidth and self.text:GetStringWidth()
            if type(tw) ~= "number" then tw = 40 end
        end
        local gap = tw > 0 and 6 or 0
        local total = self.iconSize + gap + tw
        self.iconTex:ClearAllPoints()
        self.iconTex:SetPoint("CENTER", self, "CENTER", -total / 2 + self.iconSize / 2, 0)
        self.textX = -total / 2 + self.iconSize + gap + tw / 2
        self.text:ClearAllPoints()
        self.text:SetPoint("CENTER", self.textX, 0)
    end

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
    local note = { t = t, zone = zone or "", kind = "note", arg = text, idx = 1, ses = ses }
    table.insert(db.entries, at + 1, note)
    if db.stats then K.Tally(db.stats, note) end
    -- A page is added in the middle: the count and the last page may stay the same, so the cached layout would
    -- not notice (Trim also bumps it when it lets an older page go).
    ns.layoutRev = (ns.layoutRev or 0) + 1
    K.Trim(db)
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

ns.InsertNote, ns.ResetJournal, ns.MigrateStats = InsertNote, ResetJournal, MigrateStats

-- Fonts of the design (Cinzel, EB Garamond, Caveat; SIL Open Font License, see Fonts/).
-- If the game cannot load one, the quest face of the game stands in at a smaller size.
-- The size of the text in the book is a setting (Small, Normal, Large).
K.TEXT_SIZES = { [0] = 11, [1] = 13, [2] = 15 }
-- By the density of the pages: how full a page of a day is let to get (share of its height), the room the last page of
-- a day keeps free for its doodles (points, never less than the doodles need), the points added to the letter of the
-- entries and how much the doodles grow with the room a looser page leaves.
K.DENSITY = {
    compact = { fill = 1,    band = 0,   font = 0, doodle = 0.85 },
    comfy   = { fill = 0.92, band = 70,  font = 1, doodle = 1 },
    airy    = { fill = 0.84, band = 110, font = 2, doodle = 1.3 },
}
K.DOODLE_MIN = 48          -- the free height a doodle needs at scale 1
K.DOODLE_PAD = 10          -- space between the last block of a day and the doodles
function ns.DensityCfg() return K.DENSITY[SkaldDB and SkaldDB.density or "comfy"] or K.DENSITY.comfy end
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
        local entry = size + ns.DensityCfg().font
        -- pages measured with another letter are stale (the settings load after the first call)
        local sig = size .. ":" .. entry
        if K.fontSig and K.fontSig ~= sig then ns.layoutRev = (ns.layoutRev or 0) + 1 end
        K.fontSig = sig
        Make("SkaldEntry", "EBGaramond.ttf", entry, entry - 2)   -- the text of the entries on the pages of a day
        Make("SkaldSaga", "EBGaramond.ttf", size + 3, size + 1)
        Make("SkaldItalic", "EBGaramond-Italic.ttf", size, size - 2)
        Make("SkaldSmall", "EBGaramond.ttf", 11, 10)
        Make("SkaldTab", "EBGaramond.ttf", 15, 14)   -- the names on the tabs: a size up from the body, over a shadow, so they read on the wood
        Make("SkaldHead", "Cinzel.ttf", 22, 19)
        Make("SkaldHead2", "Cinzel.ttf", 17, 16)
        Make("SkaldSec", "Cinzel.ttf", 13, 12)
        Make("SkaldNote", "Caveat.ttf", 20, 14)
        Make("SkaldDrop", "CinzelDecorative-Bold.ttf", 46, 40)   -- the drop cap of the Saga
    end
    ApplyFonts()
end

K.TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\"
K.PAPER_STYLE_ORDER = { "clean", "travel", "war", "old" }
K.PAPER_TEXTURES = {
    clean = "parchment", travel = "parchment_travel", war = "parchment_war", old = "parchment_old",
}
-- The looks of the tabs (Style tab). Every picture is 256x128 shown at half size, the same leather 110x31 inside, so a
-- look changes the picture and the writing only: where the letters go (x, width) and their colour, shut and open.
K.TAB_STYLE_ORDER = { "leather", "ribbon", "brass", "parchment", "wood" }
K.TAB_STYLES = {
    leather   = { idle = "tab_idle", active = "tab_active", x = 21, w = 78, ink = { 0.97, 0.92, 0.78 }, inkOn = { 1, 0.96, 0.82 }, shadow = true },
    ribbon    = { idle = "tab_ribbon_%s_idle", active = "tab_ribbon_active", x = 14, w = 90, ink = { 1, 0.97, 0.90 }, inkOn = { 0.30, 0.18, 0.05 }, shadow = true },
    brass     = { idle = "tab_brass_idle", active = "tab_brass_active", x = 12, w = 90, ink = { 0.98, 0.93, 0.78 }, inkOn = { 0.30, 0.18, 0.04 }, shadow = true },
    parchment = { idle = "tab_parchment_idle", active = "tab_parchment_active", x = 14, w = 88, ink = { 0.28, 0.17, 0.08 }, inkOn = { 0.28, 0.17, 0.08 } },
    wood      = { idle = "tab_wood_idle", active = "tab_wood_active", x = 22, w = 74, ink = { 1, 0.93, 0.66 }, inkOn = { 1, 0.97, 0.78 }, shadow = true, strap = { x = 120, y = 18.5, w = 9, h = 8 } },
}
-- the shut ribbons are all the wine red of the book; the open one is the golden ribbon
K.RIBBON_COLORS = {}   -- one colour for every shut ribbon (a table, so a colour can be given to a tab later)
function K.TabStyle() return K.TAB_STYLES[SkaldDB and SkaldDB.tabStyle or "leather"] or K.TAB_STYLES.leather end
function K.TabPicture(id, active)
    local st = K.TabStyle()
    if active then return K.TEX .. st.active end
    return K.TEX .. string.format(st.idle, K.RIBBON_COLORS[id] or "red")
end
-- The wax seal that closes the book, by the faction the game reports (anything else is neutral).
function ns.CloseSeal(faction)
    if faction == "Horde" then return "ui_waxseal_horde" end
    if faction == "Alliance" then return "ui_waxseal_alliance" end
    return "ui_waxseal_neutral"
end

-- The typical weather of a land, by the id of its map (the stamp on the first page of a day). Lands not listed
-- have none and keep the plain sun. These are the ids of Classic and TBC; an id the client does not know
-- simply gives no stamp. The weather the game is showing at the moment cannot be read, so this is the
-- climate the land is known for, not the day's.
K.WEATHER = {
    sun = { 1411, 1413, 1418, 1419, 1427, 1428, 1434, 1436, 1449, 1454, 1944 },
    partly = { 1412, 1429, 1432, 1453, 1456, 1457, 1941 },
    cloudy = { 1417, 1424, 1433, 1442, 1458, 1951, 1952 },
    rain = { 1437, 1438, 1439, 1440, 1444, 1445, 1946, 2024, 2025 },
    snow = { 1416, 1426, 1452, 1455 },
    sand = { 1441, 1443, 1446, 1451 },
    fog = { 1420, 1421, 1422, 1423, 1430, 1431, 1435, 1448, 1942 },
    storm = { 1425, 1447, 1948, 1949, 1953 },
}
K.WEATHER_OF = {}
for kind, ids in pairs(K.WEATHER) do for _, id in ipairs(ids) do K.WEATHER_OF[id] = kind end end
-- The weather kind ("sun", "partly", "cloudy", "rain", "snow", "sand", "fog" or "storm") of a map, or nil.
function ns.WeatherOf(mapID)
    if type(mapID) ~= "number" then return nil end
    local zoneMap = ns.ZoneCard and ns.ZoneCard.ZoneMap and ns.ZoneCard.ZoneMap(mapID)
    return K.WEATHER_OF[zoneMap or mapID]
end

-- The doodles the character draws at the foot of a day, by what the day held (up to three, the most
-- present first; the scroll of the quests counts for little, since nearly every day has some).
K.DOODLE_OF = {
    quest = "scroll", level = "star", milestone = "star", death = "skull", boss = "sword", dungeon = "sword",
    zone = "map", flight = "boots", mount = "boots", tame = "paw", skill = "anvil", profession = "anvil",
    hearth = "camp", home = "camp", guild = "mug", rep = "mug",
}
K.DOODLE_ORDER = { "sword", "skull", "map", "star", "camp", "boots", "paw", "anvil", "mug", "scroll" }
K.DOODLE_WEIGHT = { scroll = 0.3 }
function ns.DensityBand()
    local d = ns.DensityCfg()
    if d.band == 0 then return 0 end
    return math.max(d.band, math.ceil(K.DOODLE_MIN * d.doodle) + K.GAP + K.DOODLE_PAD + 2)
end
-- The one way to change the density (the Style tab and /skald density): store it, redo the letter and the pages.
function ns.SetDensity(key)
    if not K.DENSITY[key] then return false end
    Settings().density = key
    ApplyFonts()
    ns.layoutRev = (ns.layoutRev or 0) + 1
    if ns.SyncDensity then ns.SyncDensity() end
    if window then window:Refresh() end
    return true
end
-- Where the i-th of `count` doodles of a day goes in the free room above the quill (`room` points high): the doodles stand in
-- one strip, all of one size, centred in the column and resting on a line, each with room at its side for the count of what
-- it stands for. Returns its size, its left offset in the column, its drop from the top of the room (the strip is at the
-- foot of it) and its tilt (none).
K.DOODLE_SIZE, K.DOODLE_GAP = 34, 26
function ns.DoodleSpot(i, count, dayNumber, room, scale)
    local gap = K.DOODLE_GAP
    local size = math.min(math.floor(K.DOODLE_SIZE * scale), room - 12, math.floor((K.CW - (count - 1) * gap) / count))
    local width = count * size + (count - 1) * gap
    local x = math.max(0, math.min((K.CW - width) / 2 + (i - 1) * (size + gap), K.CW - size))
    return size, x, room - size, 0
end
-- How many entries of a day a doodle stands for (the quills of a day of three quests: 3).
function ns.DoodleCount(entries, name)
    local n = 0
    for _, e in ipairs(entries or {}) do if K.DOODLE_OF[e.kind] == name then n = n + 1 end end
    return n
end
function ns.DoodlesOf(entries, most)
    local score = {}
    for _, e in ipairs(entries or {}) do
        local d = K.DOODLE_OF[e.kind]
        if d then score[d] = math.min((score[d] or 0) + (K.DOODLE_WEIGHT[d] or 1), 3 * (K.DOODLE_WEIGHT[d] or 1)) end
    end
    local picked = {}
    for _, d in ipairs(K.DOODLE_ORDER) do if score[d] then picked[#picked + 1] = d end end
    local rank = {}
    for i, d in ipairs(picked) do rank[d] = i end
    table.sort(picked, function(a, b) if score[a] ~= score[b] then return score[a] > score[b] end return rank[a] < rank[b] end)
    while #picked > (most or 3) do table.remove(picked) end
    return picked
end

-- Inks (design tokens).
K.C_BODY  = { 0.243, 0.165, 0.086 }   -- #3E2A16
K.C_HEAD  = { 0.431, 0.118, 0.102 }   -- #6E1E1A
K.C_SEC   = K.C_HEAD
K.C_MUTED = { 0.420, 0.290, 0.165 }   -- #6B4A2A
K.C_TIME  = { 0.541, 0.416, 0.227 }   -- #8A6A3A
K.C_NOTE  = { 0.353, 0.227, 0.102 }   -- #5A3A1A
K.C_HDR   = { 0.478, 0.290, 0.180 }   -- #7A4A2E
K.INKS = { { 0.353, 0.227, 0.102 }, { 0.180, 0.165, 0.227 }, { 0.431, 0.118, 0.102 } }   -- sepia, iron gall, burgundy

K.BOOK_W, K.BOOK_H = 980, 580
K.BOOK_FIT_W, K.BOOK_FIT_H, K.BOOK_MIN_SCALE = 0.96, 0.94, 0.5   -- how much of the screen the book may take, and the smallest it is drawn
K.BOOK_SIZES = { "auto", 0.8, 1, 1.25, 1.5 }
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
K.INDEX_GAP = 12                         -- the space above a chapter that is not the first on its page

K.ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII" }
K.TAB_FOLIO = { map = 5, style = 7, notices = 9, options = 11 }   -- the first folio of each settings tab
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
            if e.kind ~= "note" then day.zmap = (type(e.m) == "number" and e.m) or e.zm or day.zmap end
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
    mount = true, home = true, rep = true, flight = true, guild = true, tame = true, goal = true,
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
    party = 2, reunion = 2, goal = 3, achievement = 5, skill = 2, profession = 2, tame = 2, mark = 4, home = 1, rep = 3, flight = 1, hearth = 1,
}
local TEXD = "Interface\\AddOns\\Skald\\Textures\\"

local function ShowToast(e, titleText, bodyText, lines, seconds)
    if not toastFrame then
        local fr = CreateFrame("Frame", "SkaldToast", UIParent)
        fr:SetSize(400, 84)
        ns.PlaceNotice(fr)
        fr:SetFrameStrata("DIALOG")
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
        fr.seal:SetPoint("LEFT", 30, 2)
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
        fr.title:SetPoint("TOPLEFT", 102, -19)
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
        fr.bar:SetPoint("BOTTOMLEFT", 102, 24)
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
            self.bar:SetWidth(math.max(1, 266 * (1 - age / life)))
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
        tier = (type(e.tier) == "number" and (e.kind == "quest" or e.kind == "loot" or e.kind == "goal" or e.kind == "boss") and e.tier) or TOAST_TIER[e.kind] or 1
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
    toastFrame:SetHeight(math.max(90, 19 + 14 + 12 + 3 + bodyHeight + 37))
    toastFrame.born = (GetTime and GetTime()) or 0
    -- How long it stays: the player's choice (0 = until clicked); a sample notice keeps the time it was asked for.
    local chosen = SkaldDB and tonumber(SkaldDB.noticeSecs)
    if e and e.sample then
        toastFrame.life = seconds or 6.5
    elseif chosen == 0 then
        toastFrame.life = 1e9
    else
        toastFrame.life = chosen or seconds or 6.5
    end
    toastFrame:SetAlpha(0)
    toastFrame:Show()
    if SkaldDB and SkaldDB.sound ~= false then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836)
    end
end

-- Shows a sample notice that stays for half a minute: drag it where you want the notices to appear.
ns.PreviewNotice = function(seconds)
    local sample = { kind = "level", arg = 5, tier = 2, idx = 1, t = time(), zone = GetZoneText(), sample = true }
    pcall(ShowToast, sample, nil, nil, 3, seconds or 30)
end

-- The card shown on returning to the game: where the last visit ended, the quests still open and
-- the note left for this day, laid out in small sections on a parchment. A click opens the book.
do
local card
ns.ShowResumeCard = function(data)
    if not card then
        local fr = CreateFrame("Frame", "SkaldResume", UIParent)
        fr:SetWidth(380)
        fr:SetClampedToScreen(true)   -- taller than a notice: where the notices were dragged to, it must not leave the screen
        ns.PlaceNotice(fr)
        fr:SetFrameStrata("DIALOG")
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
    -- The book is 980 x 580 of the game's units. A small window, a 4:3 screen or a large interface scale could
    -- leave part of it off the screen, so its scale follows what fits (and the size the player chose, if any).
    function f:FitScale()
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
        local fit = math.min(w * K.BOOK_FIT_W / K.BOOK_W, h * K.BOOK_FIT_H / K.BOOK_H)
        local want = Settings().bookScale
        self:SetScale(math.max(K.BOOK_MIN_SCALE, math.min(type(want) == "number" and want or 1, fit)))
        -- A saved position is in units of the old scale: if the new one leaves the top or the left edge (the tabs)
        -- off the screen, the book goes back to the middle.
        local left, top, scale = self:GetLeft(), self:GetTop(), self:GetEffectiveScale()
        local ui = UIParent:GetEffectiveScale()
        if type(left) == "number" and type(top) == "number" and type(scale) == "number" and type(ui) == "number" and ui > 0 then
            local x, y = left * scale / ui, top * scale / ui
            if x < 0 or x + K.BOOK_W * scale / ui > w + 0.5 or y > h + 0.5 or y - K.BOOK_H * scale / ui < -0.5 then
                self:ClearAllPoints()
                self:SetPoint("CENTER")
                Settings().pos = nil
            end
        end
    end
    f:FitScale()
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

    -- Close: the wax seal of your faction (red for the Horde, blue for the Alliance, brown for neutral),
    -- pressed on the corner of the cover. Esc closes the book too.
    local close = CreateFrame("Button", nil, book)
    close:SetFrameLevel(book:GetFrameLevel() + 6)
    close:SetSize(39, 39)   -- the drawn seal fills more of its picture than the old one did, so it is drawn smaller to look as big
    close:SetPoint("TOPRIGHT", -18, -18)
    local closeTex = close:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetVertexColor(0.85, 0.85, 0.85)
    -- the seal chosen in the Style tab; left on "by faction" it follows the faction the game reports
    function f:ApplySeal()
        local style = Settings().sealStyle
        local faction = (style == "horde" and "Horde") or (style == "alliance" and "Alliance")
        if not faction and style ~= "neutral" then faction = Safe(select(2, pcall(UnitFactionGroup, "player"))) end
        closeTex:SetTexture(K.TEX .. ns.CloseSeal(faction))
    end
    f:ApplySeal()
    close:SetScript("OnEnter", function() closeTex:SetVertexColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() closeTex:SetVertexColor(0.85, 0.85, 0.85) end)
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
        s.paper, s.paperOx, s.paperOy = paper, ox, oy

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
        hr:SetPoint("TOPRIGHT", i == 2 and -52 or -30, -15)   -- the wax seal of the cover sits over the right corner
        hr:SetTextColor(K.C_HDR[1], K.C_HDR[2], K.C_HDR[3])
        hr:SetText(L.HDR_R)
        s.hr = hr
        s.hl = hl
        -- the cover's left page names the book in the middle too (name | diary | Skald)
        s.hm = fr:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        s.hm:SetPoint("TOP", 0, -15)
        s.hm:SetTextColor(K.C_HDR[1], K.C_HDR[2], K.C_HDR[3])
        s.hm:SetText(L.HDR_M)
        s.hm:Hide()
        s.headRules = {}
        for n, alpha in ipairs({ 0.55, 0.22 }) do
            local rule = fr:CreateTexture(nil, "ARTWORK", nil, 3)
            s.headRules[n] = rule
            rule:SetColorTexture(0.43, 0.118, 0.102, alpha)
            rule:SetHeight(1)
            rule:SetPoint("TOPLEFT", 30, -(35 + (n - 1) * 3))
            rule:SetPoint("TOPRIGHT", -30, -(35 + (n - 1) * 3))
        end

        s.quill = fr:CreateTexture(nil, "ARTWORK", nil, 3)
        -- the page number between two sprigs of laurel (s.quill is the left one)
        s.quill:SetSize(56, 28)
        s.quill:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_laurel_l")
        s.num = fr:CreateFontString(nil, "OVERLAY", "SkaldBody")
        s.num:SetPoint("BOTTOM", 0, 16)
        s.quill:SetPoint("RIGHT", s.num, "LEFT", 2, -1)
        s.quill:Hide()
        s.laurelR = fr:CreateTexture(nil, "ARTWORK", nil, 3)
        s.laurelR:SetSize(56, 28)
        s.laurelR:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_laurel_r")
        s.laurelR:SetPoint("LEFT", s.num, "RIGHT", -2, -1)
        s.laurelR:Hide()

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
    local prevButton, nextButton
    local function ApplyCornerStyle()
        local choice = (SkaldDB and SkaldDB.paperStyle) or "clean"
        if choice ~= "travel" and choice ~= "war" and choice ~= "old" then choice = "clean" end
        for _, button in ipairs({ prevButton, nextButton }) do
            if button and button.tex then
                local suffix = choice == "clean" and "" or ("_" .. choice)
                button.tex:SetTexture(K.TEX .. "ui_corner_" .. button.cornerSide .. suffix)
                local hover = button:IsMouseOver()
                local gain = hover and 1.12 or 1
                button.tex:SetVertexColor(gain, gain, gain)
            end
        end
    end
    function f:ApplyPaper()
        local choice = (SkaldDB and SkaldDB.paperStyle) or "clean"
        local texture = K.PAPER_TEXTURES[choice] or K.PAPER_TEXTURES.clean
        for _, side in ipairs(sides) do
            side.paper:SetTexture(K.TEX .. texture, "REPEAT", "REPEAT")
            side.paper:SetTexCoord(side.paperOx / 256, (side.paperOx + K.PAGE_SW) / 256,
                side.paperOy / 256, (side.paperOy + K.PAGE_SH) / 256)
        end
        ApplyCornerStyle()
    end
    f:ApplyPaper()

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
            r.text = s.frame:CreateFontString(nil, "OVERLAY", "SkaldEntry")
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
            -- a warm gold glow behind it while the pointer is over it
            r.star.glow = r.star:CreateTexture(nil, "BACKGROUND")
            r.star.glow:SetSize(34, 34)
            r.star.glow:SetPoint("CENTER", 0, 0)
            r.star.glow:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_splash")
            r.star.glow:SetBlendMode("ADD")
            r.star.glow:SetAlpha(0.55)
            r.star.glow:Hide()
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
                self.glow:Show()
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine(L.FAV_TIP, 1, 0.82, 0)
                GameTooltip:AddLine(L.FAV_HINT, 1, 1, 1, true)
                if self.entry and self.entry.favNote then GameTooltip:AddLine(self.entry.favNote, 0.9, 0.9, 0.9, true) end
                GameTooltip:Show()
            end)
            r.star:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                self.glow:Hide()
                self:SetAlpha((self.entry and self.entry.fav) and 1 or 0.45)
            end)
            r.star:Hide()
            s.rows[n] = r
        end
        return r
    end

    -- Text heights come from a hidden string of the right width.
    local meter = f:CreateFontString(nil, "OVERLAY", "SkaldEntry")
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
    -- a soft shadow under the feet, so the figure stands on the parchment instead of floating
    local footShadow = modelHolder:CreateTexture(nil, "BACKGROUND", nil, 3)
    footShadow:SetSize(210, 52)
    footShadow:SetPoint("BOTTOM", 0, 14)
    footShadow:SetTexture(K.TEX .. "ui_foot")
    local portrait = modelHolder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("CENTER")
    portrait:SetSize(186, 186)
    -- What stands in the arch while the character is a spirit: a picture, in place of the model of the spirit.
    local ghostArt = modelHolder:CreateTexture(nil, "ARTWORK")
    ghostArt:SetPoint("CENTER", 0, 4)
    ghostArt:SetSize(170, 170)
    ghostArt:Hide()
    -- A dressing-room model, which can be told to take the weapons off (see LoadModel); the plain model where the game has none.
    local okModel, model = pcall(CreateFrame, "DressUpModel", nil, modelHolder)
    if not (okModel and model) then okModel, model = pcall(CreateFrame, "PlayerModel", nil, modelHolder) end
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
    -- the lower edge of the arch darkens a little, like the floor of a niche
    local archShade = alcove:CreateTexture(nil, "OVERLAY", nil, -1)
    archShade:SetSize(292, 73)
    archShade:SetPoint("BOTTOM", 0, 20)
    archShade:SetTexture(K.TEX .. "ui_arch")
    -- The model is asked for once, then again a moment later and a little after that: the textures of what
    -- the character wears can still be on their way, and until they arrive the model has white patches.
    local function LoadModel()
        if not (okModel and model) then return false end
        -- The third argument asks for the character in its native form: not as a spirit, and not as
        -- the bear or the cat of a druid. (Where the game ignores it, the model is what it always was.)
        if not pcall(model.SetUnit, model, "player", false, true) then return false end
        pcall(model.SetCamDistanceScale, model, ns.CoverZoom())
        -- A weapon as big as a staff or a spear sticks out of the arch, so the figure stands without weapons
        -- (main hand, off hand, ranged); nothing is taken off the character, only off the picture.
        if model.UndressSlot then
            for _, slot in ipairs(K.COVER_UNDRESS) do pcall(model.UndressSlot, model, slot) end
        end
        pcall(model.SetFacing, model, model.skaldAngle or 0)
        model.skaldLoadedAt = (GetTime and GetTime()) or 0
        return true
    end
    local function ShowModel()
        local works = false
        local now = (GetTime and GetTime()) or 0
        local loadedAt = model and rawget(model, "skaldLoadedAt")
        local ghost = UnitIsGhost and UnitIsGhost("player") and true or false
        if ghost then
            -- As a spirit the character is the model of the spirit (a white wisp, blown out in the frame):
            -- a picture stands in the arch instead until the body is back (a gravestone, in the humorous voice).
            works = false
            ghostArt:SetTexture("Interface\\AddOns\\Skald\\Textures\\" .. (K.GHOST_ART[(SkaldDB and SkaldDB.tone) or "epic"] or K.GHOST_ART.epic))
        elseif loadedAt and now - loadedAt < K.MODEL_REUSE then
            works = true   -- asked for a moment ago: asking again would only restart the loading
        elseif LoadModel() then
            model.skaldAngle = 0
            pcall(model.SetFacing, model, 0)
            works = true
            for _, delay in ipairs(K.MODEL_RETRY) do
                C_Timer.After(delay, function()
                    if model and model:IsShown() and not rawget(model, "skaldDragging") then LoadModel() end
                end)
            end
        end
        if model then model:SetShown(works) end
        ghostArt:SetShown(ghost)
        portrait:SetShown(not works and not ghost)
        for _, t in ipairs(medal) do t:SetShown(not works and not ghost) end
        if not works and not ghost then pcall(SetPortraitTexture, portrait, "player") end
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
        { key = "points",       label = L.S_POINTS,       icon = "pt_gem" },
    }
    local FACT_H = 20
    local factValues, factLabels = {}, {}
    for i, fact in ipairs(FACTS) do
        local y = -98 - (i - 1) * FACT_H
        local icon = stats:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("TOPLEFT", RX, y)
        fact.region = icon
        fact.y = y
        icon:SetTexture(fact.icon:find("\\", 1, true) and fact.icon or ("Interface\\AddOns\\Skald\\Textures\\" .. fact.icon))
        factLabels[fact.key] = JText(stats, "SkaldBody", RX + 32, y - 4)
        factLabels[fact.key]:SetText(fact.label)
        factValues[fact.key] = JText(stats, "SkaldBody", 0, y - 4, "RIGHT")
        factValues[fact.key]:ClearAllPoints()
        factValues[fact.key]:SetPoint("TOPRIGHT", -30, y - 4)
        factValues[fact.key]:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])
        local leader = stats:CreateTexture(nil, "ARTWORK")
        leader:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.22)
        leader:SetHeight(1)
        leader:SetPoint("BOTTOMLEFT", factLabels[fact.key], "BOTTOMRIGHT", 6, 3)
        leader:SetPoint("BOTTOMRIGHT", factValues[fact.key], "BOTTOMLEFT", -6, 3)
        fact.leader = leader
        -- a value with a remark ("305 (Humanoid)"): the remark sits at the margin in small muted italics
        -- and the number stays where the other numbers end
        if fact.key == "topkind" then
            local tag = JText(stats, "SkaldItalic", 0, y - 4, "RIGHT")
            tag:ClearAllPoints()
            tag:SetPoint("TOPRIGHT", -30, y - 3)
            tag:SetTextColor(0.45, 0.31, 0.18)
            factValues.topkindTag = tag
            factValues[fact.key]:ClearAllPoints()
            factValues[fact.key]:SetPoint("TOPRIGHT", tag, "TOPLEFT", -4, 1)
        end
    end

    local rarityTop = -98 - #FACTS * FACT_H - 14
    local rarityRule = stats:CreateTexture(nil, "ARTWORK")
    rarityRule:SetSize(110, 9)
    rarityRule:SetPoint("TOP", 3, rarityTop)
    rarityRule:SetTexture(K.TEX .. "rule")
    rarityRule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    -- the ribbon the seals lean on, with the counts written on it
    local ribbon = stats:CreateTexture(nil, "ARTWORK")
    ribbon:SetSize(400, 50)   -- the drawn ribbon fills 85% of its picture: about 340 points show, the flat of it from 34 to 310
    ribbon:SetPoint("TOPLEFT", RX - 29, rarityTop - 37)
    ribbon:SetTexture(K.TEX .. "ui_ribbon")
    local rarityCounts = {}
    for tier = 0, 5 do
        local cell = CreateFrame("Frame", nil, stats)
        cell:SetSize(50, 60)
        cell:SetPoint("TOPLEFT", RX + 21 + tier * 50, rarityTop - 14)   -- close enough for all six counts to lie on the flat of the ribbon, not on its rolled ends
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
    -- the two notes at the foot are written by hand
    local footerPlayed = JText(stats, "SkaldNote", RX, rarityTop - 90)
    local footerFirst = JText(stats, "SkaldNote", RX, rarityTop - 110)
    footerPlayed:SetTextColor(0.36, 0.24, 0.14)
    footerFirst:SetTextColor(0.36, 0.24, 0.14)

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
        if ns.GoalScore then
            local earned, possible = ns.GoalScore()
            values.points = earned .. " / " .. possible
        else
            values.points = "-"
        end
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
        for key, fs in pairs(factValues) do
            if key ~= "topkindTag" then fs:SetText(tostring(values[key])) end
        end
        -- A line the client cannot answer (the Burning Crusade client has no gold or most-slain statistic) is left
        -- out, and the lines below it move up, rather than a row that always says "none".
        do
            local row = 0
            for _, fact in ipairs(FACTS) do
                local missing = (fact.key == "gold" or fact.key == "topkind") and values[fact.key] == L.S_NONE
                local parts = { fact.region, factLabels[fact.key], factValues[fact.key], fact.leader }
                if fact.key == "topkind" then parts[#parts + 1] = factValues.topkindTag end
                for _, part in ipairs(parts) do
                    if missing then part:Hide() else part:Show() end
                end
                if not missing then
                    local y = -98 - row * FACT_H
                    row = row + 1
                    fact.region:ClearAllPoints(); fact.region:SetPoint("TOPLEFT", RX, y)
                    factLabels[fact.key]:ClearAllPoints(); factLabels[fact.key]:SetPoint("TOPLEFT", RX + 32, y - 4)
                    if fact.key == "topkind" then
                        factValues.topkindTag:ClearAllPoints(); factValues.topkindTag:SetPoint("TOPRIGHT", -30, y - 3)
                        factValues.topkind:ClearAllPoints(); factValues.topkind:SetPoint("TOPRIGHT", factValues.topkindTag, "TOPLEFT", -4, 1)
                    else
                        factValues[fact.key]:ClearAllPoints(); factValues[fact.key]:SetPoint("TOPRIGHT", -30, y - 4)
                    end
                end
            end
        end
        do
            -- "305 (Humanoid)": number apart from the remark in brackets, if the game wrote one
            local number, tag = tostring(values.topkind):match("^(.-)%s*(%b())%s*$")
            if number and number ~= "" then
                factValues.topkind:SetText(number)
                factValues.topkindTag:SetText(tag)
            else
                factValues.topkindTag:SetText("")
            end
        end
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
        -- the rows go page by page by their height: a chapter after the first row of a page has a gap above it
        local chunks, chunk, used = { {} }, 1, 0
        local limit = K.PAGE_H - 50
        for _, row in ipairs(rows) do
            local h = K.INDEX_ROW + ((row.chapter and used > 0) and K.INDEX_GAP or 0)
            if used + h > limit and used > 0 then
                chunk = chunk + 1; chunks[chunk] = {}; used = 0
                h = K.INDEX_ROW
            end
            local list = chunks[chunk]
            list[#list + 1] = row
            used = used + h
        end
        local indexPages = math.max(2, #chunks)
        if indexPages % 2 == 1 then indexPages = indexPages + 1 end   -- the days start on a left page
        local entryPage = {}
        local pages = { { type = "coverL" }, { type = "coverR" } }
        for i = 1, indexPages do
            pages[#pages + 1] = { type = "index", rows = chunks[i] or {}, first = (i == 1), label = RomanLower(i) }
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
                    icon = (e.kind == "loot" and ItemIcon(e)) or (e.kind == "note" and (K.TEX .. "dd_scroll")) or (isQuest and (K.SEAL_PATH .. e.tier)) or EventIconPath(e.kind, e),
                }
            end
            if day.summary then
                blocks[#blocks + 1] = { text = Hex(K.C_HEAD) .. RenderEntry(day.summary) .. "|r", closing = true }
            end

            local page = { type = "day", day = day, blocks = {}, first = true }
            local y = 70
            pages[#pages + 1] = page
            -- the last block of the day leaves room for the quill and the doodles, else it goes to a page of its own
            local fullLimit = math.floor(K.PAGE_H * ns.DensityCfg().fill)
            local lastLimit = math.min(fullLimit, K.PAGE_H - K.NOTE_BTN_H - ns.DensityBand())
            for i, block in ipairs(blocks) do
                local mainH = Measure(block.text, block.closing and (K.CW - 32) or (K.CW - K.ENTRY_X - 22))
                local noteH = block.note and MeasureNote(block.note, K.CW - K.ENTRY_X - 22 - 16) or 0
                block.mainH = mainH
                block.noteH = noteH
                block.h = math.max(24, mainH + (noteH > 0 and (noteH + 6) or 0))
                local limit = (i == #blocks) and lastLimit or fullLimit
                if y + block.h > limit and #page.blocks > 0 then
                    page = { type = "day", day = day, blocks = {}, first = false }
                    pages[#pages + 1] = page
                    y = 40
                end
                page.blocks[#page.blocks + 1] = block
                if block.entry then entryPage[block.entry] = #pages
                elseif block.closing and day.summary then entryPage[day.summary] = #pages end
                y = y + block.h + K.GAP
            end
            page.note = true
            page.usedY = y
            page.doodles = {}
            local weather = ns.WeatherOf(day.zmap)
            if weather then page.doodles[1] = "wxd_" .. weather end
            page.doodleN = {}
            for _, name in ipairs(ns.DoodlesOf(day.entries, 3)) do
                page.doodles[#page.doodles + 1] = "dd_" .. name
                page.doodleN[#page.doodles] = ns.DoodleCount(day.entries, name)
            end
            -- every day closes with its own page of numbers
            pages[#pages + 1] = { type = "daycard", day = day }
        end
        if #pages % 2 == 1 then
            pages[#pages + 1] = { type = "blank" }
        end
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
            (SkaldDB and SkaldDB.textSize) or 1, (SkaldDB and SkaldDB.dayMode) or 0, (SkaldDB and SkaldDB.density) or "", ns.layoutRev or 0 }, ":")
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
        for _, t in ipairs(s.doodles or {}) do t:Hide() end
        for _, t in ipairs(s.doodleN or {}) do t:Hide() end
        if s.doodleLine then s.doodleLine:Hide() end
        if s.timeline then s.timeline:Hide() end
        s.timelineTop = nil
        if s.dayCard then s.dayCard:Hide() end
        s.cover:Hide()
        s.sub:Hide()
        s.rule:Hide()
        s.line:Hide()
        s.quill:Hide()
        s.laurelR:Hide()
        s.num:SetText("")
        -- no running head over a page: only the cover's left page raises it again (DrawPage)
        s.hl:Hide(); s.hr:Hide(); s.hm:Hide()
        if s.zoneCard then s.zoneCard:Hide() end
        for _, rule in ipairs(s.headRules) do rule:Hide() end
    end

    local function DrawPage(s, page, number)
        Clear(s)
        if not page then return end
        s.hl:SetText(Upper(UnitName("player")))
        s.hm:SetShown(page.type == "coverL")
        s.hm:SetText(Upper(L.HDR_M))
        -- only the cover's left page names the book above; every other page opens with its own title
        local bare = page.type ~= "coverL"
        for _, fs in ipairs({ s.hl, s.hr }) do fs:SetShown(not bare) end
        for _, rule in ipairs(s.headRules) do rule:SetShown(not bare) end
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
        s.laurelR:Show()
        local px = s.padL
        if page.type == "daycard" then
            -- the page that closes a day: its numbers
            s.num:SetText(Hex(K.C_MUTED) .. tostring(number - layout.firstDayPage + 1) .. "|r")
            if ns.DayCard then
                if not s.dayCard then
                    local okCard, card = pcall(ns.DayCard.Build, s.frame, K.CW)
                    if okCard then s.dayCard = card else SkaldDB.errors = SkaldDB.errors or {}; table.insert(SkaldDB.errors, tostring(card)) end
                end
                if s.dayCard then
                    s.dayCard:ClearAllPoints()
                    s.dayCard:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px, -(K.TOP_Y + 4))
                    local okSet, err = pcall(s.dayCard.Set, s.dayCard, page.day, (DayTitle(page.day, page.day.number):gsub(":", " -", 1)))
                    if okSet then s.dayCard:Show() else SkaldDB.errors = SkaldDB.errors or {}; table.insert(SkaldDB.errors, tostring(err)) end
                end
            end
            return
        end

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
            if not page.first and #page.rows == 0 and ns.ZoneCard then
                -- the contents ended on the left page: the right one tells about the land the diary last stood in
                local mapID = ns.ZoneCard.CurrentMap()
                if mapID then
                    if not s.zoneCard then
                        local okCard, card = pcall(ns.ZoneCard.Build, s.frame, K.CW)
                        if okCard then s.zoneCard = card else SkaldDB.errors = SkaldDB.errors or {}; table.insert(SkaldDB.errors, tostring(card)) end
                    end
                    if s.zoneCard then
                        s.zoneCard:ClearAllPoints()
                        s.zoneCard:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px, -(K.TOP_Y - 4))
                        local okSet, err = pcall(s.zoneCard.Set, s.zoneCard, mapID)
                        if okSet then s.zoneCard:Show() else SkaldDB.errors = SkaldDB.errors or {}; table.insert(SkaldDB.errors, tostring(err)) end
                    end
                end
            end
            if page.first then
                Heading(L.INDEX_TITLE, K.TOP_Y + 4)
                Rule(s, K.TOP_Y + 32)
                y = K.TOP_Y + 56
                if #page.rows == 0 then
                    local msg = SideText(s, 2)
                    msg:ClearAllPoints()
                    msg:SetPoint("TOPLEFT", px, -(y + 24))
                    msg:SetJustifyH("CENTER")
                    msg:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
                    msg:SetText(L.EMPTY)
                    msg:Show()
                end
            end
            for n, row in ipairs(page.rows) do
                local b = SideLine(s, n)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", px, -y)
                b.text:ClearAllPoints()
                if row.chapter then
                    if n > 1 then
                        y = y + K.INDEX_GAP
                        b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", px, -y)
                    end
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
            -- a land with a weather doodle of its own has it at the foot of the day, so the small sun stays out of the date line
            local weather = ns.WeatherOf(day.zmap)
            local sub = s.sub
            sub:ClearAllPoints()
            sub:SetPoint("TOPLEFT", px, -(K.TOP_Y + 28))
            sub:SetTextColor(1, 1, 1)
            local where = KnownZone(day.zone)
            -- the small sun stays on a day whose land has no weather stamp of its own
            local stamp = weather and "" or (string.format("|T%ssun:18:18:0:0:64:64:0:64:0:64|t", K.TEX) .. " ")
            sub:SetText(string.format("%s%s%s%s|r", stamp, Hex(K.C_MUTED),
                date(L.DAY_DATE, day.t), where and ("  -  " .. where) or ""))
            sub:Show()
            Rule(s, K.TOP_Y + 56)
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
                    s.closeIcon:SetTexCoord(0, 1, 0, 1)
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
                fs:SetFontObject("SkaldEntry")
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
                -- a faint line down the icons: the day runs from one time to the next
                if not s.timeline then
                    s.timeline = s.frame:CreateTexture(nil, "ARTWORK", nil, 1)
                    s.timeline:SetWidth(2)
                    s.timeline:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.3)
                end
                if not s.timelineTop then s.timelineTop = top end
                s.timeline:ClearAllPoints()
                s.timeline:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px + 11, -(s.timelineTop + 12))
                s.timeline:SetPoint("BOTTOMLEFT", s.frame, "TOPLEFT", px + 11, -(top + 12))
                s.timeline:SetShown(top > s.timelineTop)
                r.time:ClearAllPoints()
                r.time:SetPoint("TOPLEFT", px + 32, -(top + 4))
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
                r.star:SetAlpha((block.entry and block.entry.fav) and 1 or 0.45)
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
            -- what the day held, in one strip where the page has room above the quill: the weather of the land, then what the
            -- day was about, each with its count (when more than one), on a line, all of one size and in a row
            local floor = K.PAGE_H - K.NOTE_BTN_H
            local top = (page.usedY or 0) + K.DOODLE_PAD
            local count = page.doodles and #page.doodles or 0
            local dscale = ns.DensityCfg().doodle
            local room = floor - top
            if count > 0 and room >= math.ceil(K.DOODLE_MIN * dscale) then
                s.doodles = s.doodles or {}
                s.doodleN = s.doodleN or {}
                for i, name in ipairs(page.doodles) do
                    local t = s.doodles[i]
                    if not t then
                        t = s.frame:CreateTexture(nil, "ARTWORK", nil, 2)
                        s.doodles[i] = t
                    end
                    local size, x, drop = ns.DoodleSpot(i, count, day.number, room, dscale)
                    t:SetSize(size, size)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px + x, -(K.TOP_Y + top + drop))
                    t:SetTexture(K.TEX .. name)
                    if t.SetRotation then pcall(t.SetRotation, t, 0) end
                    t:Show()
                    local n = page.doodleN and page.doodleN[i] or 0
                    local label = s.doodleN[i]
                    if not label then
                        label = s.frame:CreateFontString(nil, "OVERLAY", "SkaldSmall")
                        label:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
                        s.doodleN[i] = label
                    end
                    if n > 1 then
                        label:ClearAllPoints()
                        label:SetPoint("BOTTOMLEFT", t, "BOTTOMRIGHT", 3, 1)
                        label:SetText("x" .. n)
                        label:Show()
                    else
                        label:Hide()
                    end
                end
                -- the line the strip stands on
                if not s.doodleLine then
                    s.doodleLine = s.frame:CreateTexture(nil, "ARTWORK", nil, 1)
                    s.doodleLine:SetHeight(1)
                end
                s.doodleLine:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.3)
                s.doodleLine:ClearAllPoints()
                local size = ns.DoodleSpot(1, count, day.number, room, dscale)
                local lineY = -(K.TOP_Y + top + room + 4)   -- the strip rests on it: its icons end at the foot of the room
                s.doodleLine:SetPoint("TOPLEFT", s.frame, "TOPLEFT", px, lineY)
                s.doodleLine:SetPoint("TOPRIGHT", s.frame, "TOPLEFT", px + K.CW, lineY)
                s.doodleLine:Show()
            end
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
        -- the art is 256x128 shown at half size: the leather itself is 110x31 and sits 10,7 inside, the glow of the open tab around it
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetSize(128, 64)
        b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", -10, 7)
        b.tex:SetTexture(K.TabPicture(id, false))
        b.text = b:CreateFontString(nil, "OVERLAY", "SkaldTab")
        b.text:SetPoint("LEFT", 21, 0)
        b.text:SetWidth(78)   -- between the notch and the brass strap
        b.text:SetJustifyH("CENTER")
        b.text:SetText(label)
        function b:SetActive(active)
            self.active = active and true or false
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", f, "TOPLEFT", self.active and -26 or -14, self.top)   -- the brass strap shows against the spine
            local st = K.TabStyle()
            self.tex:SetTexture(K.TabPicture(id, self.active))
            -- the open wooden tab is drawn with a buckle at its end; a short strap runs from it to the edge of the book,
            -- so the buckle holds on to something instead of hanging in the air
            if st.strap then
                if not rawget(self, "strap") then
                    self.strap = self:CreateTexture(nil, "ARTWORK", nil, -1)
                    self.strap:SetColorTexture(0.17, 0.10, 0.06, 1)
                    self.strapEdge = self:CreateTexture(nil, "ARTWORK", nil, 0)
                    self.strapEdge:SetColorTexture(0.36, 0.23, 0.12, 1)
                end
                self.strap:ClearAllPoints()
                self.strap:SetPoint("TOPLEFT", self.tex, "TOPLEFT", st.strap.x, -st.strap.y)
                self.strap:SetSize(st.strap.w, st.strap.h)
                self.strapEdge:ClearAllPoints()
                self.strapEdge:SetPoint("TOPLEFT", self.strap, "TOPLEFT", 0, 0)
                self.strapEdge:SetSize(st.strap.w, 1)
                if self.active then self.strap:Show(); self.strapEdge:Show() else self.strap:Hide(); self.strapEdge:Hide() end
            elseif rawget(self, "strap") then   -- another look: the strap of the wooden one goes
                self.strap:Hide(); self.strapEdge:Hide()
            end
            self.text:ClearAllPoints()
            self.text:SetPoint("LEFT", st.x, 0)
            self.text:SetWidth(math.max(30, st.w - (id == "bard" and 18 or 0)))
            local c = self.active and st.inkOn or st.ink
            self.text:SetTextColor(c[1], c[2], c[3])
            if self.text.SetShadowColor then   -- a dark edge to the letters on a dark tab; none on the light one
                if st.shadow and (c[1] + c[2] + c[3]) / 3 > 0.6 then   -- only a light letter gets one
                    self.text:SetShadowColor(0.10, 0.05, 0.02, 0.95)
                    self.text:SetShadowOffset(1, -1)
                else
                    self.text:SetShadowColor(0, 0, 0, 0)
                end
            end
        end
        b:SetActive(false)
        b:SetScript("OnClick", function() f:ShowSection(id) end)
        tabs[id] = b
        return b
    end
    MakeTab("cover", L.SEC_COVER, 1)
    MakeTab("index", L.SEC_INDEX, 2)
    MakeTab("days", L.SEC_DAYS, 3)
    function f:ApplyTabStyle() for _, b in pairs(tabs) do b:SetActive(b.active) end end
    local panels, panelOrder = {}, {}
    -- The tabs in the order of the book: the diary itself, what it holds, then the settings below, a little apart.
    local TAB_RANK = { cover = 1, index = 2, search = 2.5, days = 3, bard = 3.7, goals = 4, saga = 4.5, pets = 5, map = 6, settings = 20 }
    local function LayoutTabs()
        local ids = {}
        for id, b in pairs(tabs) do b:Show(); ids[#ids + 1] = id end
        table.sort(ids, function(a, b)
            local ra, rb = TAB_RANK[a] or 10, TAB_RANK[b] or 10
            if ra ~= rb then return ra < rb end
            return a < b
        end)
        -- the column never runs into the foot of the cover: with many tabs the step between them closes a little
        local step = 40
        if #ids > 1 then step = math.min(40, math.floor((K.BOOK_H - 56 - 86 - 14 - 34) / (#ids - 1))) end
        local y = 86
        for _, id in ipairs(ids) do
            local b = tabs[id]
            if (TAB_RANK[id] or 10) >= 20 and not ids.gap then ids.gap = true; y = y + 14 end
            b.top = -y
            b:SetActive(b.active)
            y = y + step
        end
    end
    function f:AddTab(id, label, build)
        if panels[id] then return panels[id].frame end
        local button = MakeTab(id, label, 4 + #panelOrder)
        local panel = CreateFrame("Frame", nil, book)
        panel:SetFrameLevel(book:GetFrameLevel() + 5)
        panel:SetPoint("TOPLEFT", f, "TOPLEFT", K.PAGE_XS[1] + 30, -(K.PAGE_Y + K.TOP_Y))
        panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -54, 70)
        panel:Hide()
        panel.tabButton = button   -- a tab may mark its own button (the Bard's note while the music plays)
        local entry = { button = button, frame = panel }
        panels[id] = entry
        panelOrder[#panelOrder + 1] = id
        LayoutTabs()
        local ok, refresh, pager = pcall(build, panel)
        if ok and type(refresh) == "function" then entry.refresh = refresh end
        if ok and type(pager) == "table" then entry.pager = pager end   -- { Turn(delta), CanPrev(), CanNext() }
        return panel
    end

    -- Page corners turn the pages. -----------------------------------------------------
    local function MakeCurl(i)
        local b = CreateFrame("Button", nil, book)
        b:SetFrameLevel(book:GetFrameLevel() + 6)
        b:SetSize(76, 76)
        -- the drawn corner has a little clear margin, so it sits a few points outside the page corner
        b:SetPoint(i == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", f, "TOPLEFT",
            i == 1 and (K.PAGE_XS[1] - 8) or (K.PAGE_XS[2] + K.PAGE_SW + 8), -(K.PAGE_Y + K.PAGE_SH) - 8)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.cornerSide = i == 1 and "l" or "r"
        b:SetScript("OnEnter", function() ApplyCornerStyle() end)
        b:SetScript("OnLeave", function() ApplyCornerStyle() end)
        return b
    end
    prevButton = MakeCurl(1)
    prevButton.isPrev = true
    nextButton = MakeCurl(2)
    nextButton.isNext = true
    ApplyCornerStyle()

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
    todayButton.glow = todayButton:CreateTexture(nil, "BACKGROUND")
    todayButton.glow:SetPoint("TOPLEFT", -8, 4)
    todayButton.glow:SetPoint("BOTTOMRIGHT", 8, -4)
    todayButton.glow:SetColorTexture(1, 0.86, 0.5, 0.18)
    todayButton.glow:Hide()
    todayButton:SetScript("OnEnter", function(self) self.text:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3]); self.glow:Show() end)
    todayButton:SetScript("OnLeave", function(self) self.text:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3]); self.glow:Hide() end)
    todayButton:SetScript("OnClick", function() f:ShowSection("days") end)
    todayButton:Hide()

    function f:Refresh()
        if not Journal() then return end
        for _, p in pairs(panels) do p.frame:Hide() end
        local showBook = panels[view] == nil
        local pager = panels[view] and panels[view].pager
        for _, s in ipairs(sides) do s.frame:Show() end
        prevButton:SetShown(showBook or pager ~= nil)
        nextButton:SetShown(showBook or pager ~= nil)
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
            -- the settings tabs are numbered on in Roman figures, between the sprigs of laurel
            local first = (pager and pager.Folio and pager.Folio()) or K.TAB_FOLIO[view]
            if first then
                for i, s in ipairs(sides) do
                    s.num:SetText(Hex(K.C_MUTED) .. RomanLower(first + i - 1) .. "|r")
                    s.quill:Show()
                    s.laurelR:Show()
                end
            end
            panels[view].frame:Show()
            if panels[view].refresh then pcall(panels[view].refresh) end
            if pager then
                local canPrev, canNext = pager.CanPrev(), pager.CanNext()
                prevButton:SetEnabled(canPrev)
                nextButton:SetEnabled(canNext)
                prevButton:SetAlpha(canPrev and 1 or 0.35)
                nextButton:SetAlpha(canNext and 1 or 0.35)
            end
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
        for _, name in ipairs({ "SkaldBody", "SkaldEntry", "SkaldHead", "SkaldNote", "SkaldSec" }) do
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

        -- the tabs (Settings with its three pages, Map...): inside their page, never across the gutter
        for id, p in pairs(panels) do
          for _, settingsPage in ipairs(id == "settings" and K.SETTINGS_PAGES or { false }) do   -- each page of the settings in turn
            view = id
            if settingsPage then p.frame.GoTo(settingsPage.id) end
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

    -- The corners turn the pages of the book, or those of a tab that has pages of its own.
    local function Corner(delta)
        local pager = panels[view] and panels[view].pager
        if pager then
            if (delta < 0 and pager.CanPrev()) or (delta > 0 and pager.CanNext()) then
                pager.Turn(delta)
                TurnSound()
            end
            f:Refresh()
            return
        end
        view = "book"; spread = spread + delta; TurnSound(); f:Refresh()
    end
    prevButton:SetScript("OnClick", function() Corner(-1) end)
    nextButton:SetScript("OnClick", function() Corner(1) end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        local pager = panels[view] and panels[view].pager
        if pager then
            local step = delta > 0 and -1 or 1
            if (step < 0 and pager.CanPrev()) or (step > 0 and pager.CanNext()) then
                pager.Turn(step)
                TurnSound()
                f:Refresh()
            end
            return
        end
        if panels[view] then return end
        local before = spread
        spread = math.max(1, math.min(spread - delta, SpreadCount()))
        if spread ~= before then TurnSound() end
        f:Refresh()
    end)

    f:ApplyCover()

    f.sides = sides   -- for the tests
    function f:PageCount() layout = Layout(); return #layout.pages end   -- for the tests

    -- Opening the book lands on the newest day (or the cover while it is empty).
    f:SetScript("OnShow", function()
        f:FitScale()
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
-- A picture drawn in three parts (a left cap, a stretched middle, a right cap) so the rivets stay round at any width.
-- `cap` is the width of a cap in the picture's own pixels (the picture is `full` wide and 64 high).
local function ThreePart(b, file, cap, full)
    local parts = {}
    local height = b:GetHeight()
    local capW = math.floor((type(height) == "number" and height or 26) * cap / 64 + 0.5)
    local path = "Interface\\AddOns\\Skald\\Textures\\" .. file
    local function Part(u0, u1)
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(path)
        t:SetTexCoord(u0, u1, 0, 1)
        t:Hide()
        parts[#parts + 1] = t
        return t
    end
    local l, m, r = Part(0, cap / full), Part(cap / full, 1 - cap / full), Part(1 - cap / full, 1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(capW)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(capW)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    return function(on) for _, t in ipairs(parts) do t:SetShown(on) end end
end

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
    -- the plain buttons are plates of brass (wine-red when chosen); "strap" is the leather band with gold lettering
    local plated = (style == nil) or style == "strap"
    local showIdle, showActive, showStrap
    if plated then
        if style == "strap" then
            showStrap = ThreePart(b, "ui_strap", 24, 512)
        else
            showIdle, showActive = ThreePart(b, "ui_plate_idle", 24, 256), ThreePart(b, "ui_plate_active", 24, 256)
        end
        b:SetBackdropColor(0, 0, 0, 0)
        b:SetBackdropBorderColor(0, 0, 0, 0)
    end
    function b:SetActive(active)
        self.active = active and true or false
        if plated then
            if showStrap then
                showStrap(true)
                self.text:SetTextColor(0.89, 0.72, 0.36)
            else
                showIdle(not self.active)
                showActive(self.active)
                if self.active then self.text:SetTextColor(0.98, 0.93, 0.82) else self.text:SetTextColor(0.88, 0.82, 0.68) end
            end
            return
        end
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

-- A brass frame round a row of plates (nine pieces, so its rivets stay as drawn): `x`, `y` and `w` are those of the row.
local function PlateGroup(parent, x, y, w, h)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x - 9, y + 8)
    frame:SetSize(w + 18, h + 16)
    local level = parent:GetFrameLevel()
    if type(level) == "number" then frame:SetFrameLevel(level) end   -- under the plates
    local path, M, S, E = "Interface\\AddOns\\Skald\\Textures\\ui_plate_group", 9, 28 / 512, 28 / 128   -- the margin on the page, and in the picture
    local cols = { { 0, S, "LEFT" }, { S, 1 - S, "MID" }, { 1 - S, 1, "RIGHT" } }
    local rows = { { 0, E, "TOP" }, { E, 1 - E, "MID" }, { 1 - E, 1, "BOTTOM" } }
    for _, r in ipairs(rows) do
        for _, c in ipairs(cols) do
            local t = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
            t:SetTexture(path)
            t:SetTexCoord(c[1], c[2], r[1], r[2])
            if c[3] == "LEFT" then t:SetWidth(M) elseif c[3] == "RIGHT" then t:SetWidth(M) end
            if r[3] == "TOP" then t:SetHeight(M) elseif r[3] == "BOTTOM" then t:SetHeight(M) end
            local ax = c[3] == "LEFT" and "LEFT" or c[3] == "RIGHT" and "RIGHT" or ""
            local ay = r[3] == "TOP" and "TOP" or r[3] == "BOTTOM" and "BOTTOM" or ""
            if c[3] == "MID" and r[3] == "MID" then
                t:SetPoint("TOPLEFT", M, -M); t:SetPoint("BOTTOMRIGHT", -M, M)
            elseif c[3] == "MID" then
                t:SetPoint(ay .. "LEFT", M, 0); t:SetPoint(ay .. "RIGHT", -M, 0)
            elseif r[3] == "MID" then
                t:SetPoint("TOP" .. ax, 0, -M); t:SetPoint("BOTTOM" .. ax, 0, M)
            else
                t:SetPoint(ay .. ax)
            end
        end
    end
    return frame
end
SkaldAPI.PlateGroup = PlateGroup

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
    -- without a colour to show, the box is a brass rivet: dark when off, the centre lit amber when on
    local pinOff, pinOn
    if not swatch then
        pinOff = b:CreateTexture(nil, "ARTWORK")
        pinOff:SetSize(24, 24)
        pinOff:SetPoint("LEFT", -1, 0)
        pinOff:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_rivet_off")
        pinOn = b:CreateTexture(nil, "ARTWORK")
        pinOn:SetSize(24, 24)
        pinOn:SetPoint("LEFT", -1, 0)
        pinOn:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_rivet_on")
    end
    local ring = Round("BACKGROUND", 18, K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
    local fill = Round("ARTWORK", 14, 0.91, 0.855, 0.71)
    local mid = Round("ARTWORK", 10, 0.75, 0.29, 0.26)
    local dot = Round("OVERLAY", 6, 0.88, 0.72, 0.29)
    ring:SetShown(swatch ~= nil)
    local anchor = b
    local textX = 28
    if iconPath then
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", 26, 0)
        icon:SetTexture(iconPath)
        pcall(icon.SetDesaturation, icon, 0.3)   -- the picture a little subdued, as inked
        icon:SetAlpha(0.9)
        textX = 50
    end
    -- a soft warm glow under the row while the pointer is on it
    local hover = b:CreateTexture(nil, "BACKGROUND")
    hover:SetPoint("TOPLEFT", -4, 1)
    hover:SetPoint("BOTTOMRIGHT", 0, -1)
    hover:SetColorTexture(0.75, 0.55, 0.22, 0.16)
    hover:Hide()
    b:HookScript("OnEnter", function() hover:Show() end)
    b:HookScript("OnLeave", function() hover:Hide() end)
    local fs = b:CreateFontString(nil, "OVERLAY", "SkaldBody")
    b.caption = label
    fs:SetPoint("LEFT", anchor, "LEFT", textX, 0)
    fs:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
    fs:SetText(label)
    function b.Sync()
        local on = get() and true or false
        if pinOn then
            pinOn:SetShown(on)
            pinOff:SetShown(not on)
            fill:Hide(); mid:Hide(); dot:Hide()
            return
        end
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
    fs.rule = rule
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

-- A short ornamental line that parts two groups on a page.
local function PageRule(panel, x, y)
    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetSize(130, 11)
    rule:SetPoint("TOP", panel, "TOPLEFT", x + K.CW / 2, y)
    rule:SetTexture(K.TEX .. "rule")
    rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    return rule
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
SkaldAPI.CW = K.CW
SkaldAPI.AddEntry = AddEntry
SkaldAPI.RefreshWindow = function() if window and window:IsShown() then window:Refresh() end end
SkaldAPI.IsBookOpen = function() return window ~= nil and window:IsShown() end
SkaldAPI.OpenSection = function(id) if window then window:ShowSection(id); window:Show() end end   -- the book open at a tab
-- What the game itself counts (creatures, dungeons, bosses): more exact than the diary's own estimate.
-- The collections as the game counts them (mounts and companion pets owned). `ready` only when a journal answered
-- with a catalogue, so a journal not yet loaded is not taken for an empty collection. Asked at most every 20 seconds.
K.Collections = function()
    local now = GetTime and GetTime() or 0
    local c = K.collCache
    if c and now - c.at < 20 then return c.v end
    local v = {}
    pcall(function()
        local J = C_MountJournal
        if J and J.GetMountIDs and J.GetMountInfoByID then
            local ids = J.GetMountIDs()
            if type(ids) == "table" and #ids > 0 then
                local n = 0
                for _, id in ipairs(ids) do
                    local r = { J.GetMountInfoByID(id) }
                    if r[11] == true then n = n + 1 end
                end
                v.mounts, v.ready, v.mountsReady = n, true, true
            end
        end
    end)
    pcall(function()
        if GetNumCompanions then v.mounts = math.max(v.mounts or 0, GetNumCompanions("MOUNT") or 0) end
    end)
    pcall(function()
        local P = C_PetJournal
        if P and P.GetNumPets then
            local total, owned = P.GetNumPets()
            if type(owned) == "number" and (total or 0) > 0 then v.critters, v.ready, v.petsReady = owned, true, true end
        end
    end)
    pcall(function()
        if GetNumCompanions then v.critters = math.max(v.critters or 0, GetNumCompanions("CRITTER") or 0) end
    end)
    K.collCache = { at = now, v = v }
    return v
end
SkaldAPI.Collections = K.Collections
SkaldAPI.GameFacts = function()
    local out = {}
    out.quests = GameStat(K.STAT_QUESTS)
    local coll = K.Collections()
    out.mounts, out.critters, out.collReady = coll.mounts, coll.critters, coll.ready
    local kills = KillStat()
    if not kills then
        local byId = GameStat(107)
        if byId and byId > 0 then kills = byId end
    end
    out.kills = kills
    out.bosses = BossWins()
    out.dungeons = GameStat(K.STAT_DUNGEONS)
    out.deaths = GameStat(K.STAT_DEATHS)
    return out
end
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
K.OPTIONAL_EVENTS = {
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_XP_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    "NEW_MOUNT_ADDED", "ACHIEVEMENT_EARNED", "SKILL_LINES_CHANGED", "CHAT_MSG_LOOT",
    "HEARTHSTONE_BOUND", "UPDATE_FACTION", "TAXIMAP_OPENED", "PLAYER_MONEY",
    "LEARNED_SPELL_IN_TAB", "QUEST_ACCEPTED", "CHAT_MSG_ADDON", "VOICE_CHAT_TTS_PLAYBACK_FINISHED",
    "PLAYER_UNGHOST", "PLAYER_ALIVE", "CONFIRM_XP_LOSS", "RESURRECT_REQUEST",
}
for _, ev in ipairs(K.OPTIONAL_EVENTS) do
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
    -- With an encounter under way (where the client announces them), the fall is also credited to that boss.
    local enc = ns.encounter
    if enc and not enc.ended and enc.id and time() - (enc.at or 0) < K.FALLS_FORGOTTEN then
        a.enc = a.enc or {}
        a.enc[enc.id] = (a.enc[enc.id] or 0) + 1
    end
    db.attempts[id] = a
end
K.HARD_DIFFICULTY = { [2] = true, [5] = true, [6] = true, [8] = true, [15] = true, [16] = true, [23] = true }   -- heroic, mythic, challenge
local function BossDown(name, encounterID)
    name = Safe(name)
    if not name or name == "" then return end
    if name == lastBoss and time() - lastBossAt < 30 then return end
    lastBoss, lastBossAt = name, time()
    local db, id = Journal(), InstanceId()
    local tries
    local a = db and id and db.attempts and db.attempts[id]
    if a then
        if a.falls and a.falls > 0 and time() - (a.at or 0) <= K.FALLS_FORGOTTEN then
            -- the falls at this very boss when the client told us which one it was; else all those of the dungeon
            local own = encounterID and a.enc and a.enc[encounterID]
            tries = own or (not (a.enc and next(a.enc)) and a.falls) or nil
        end
        db.attempts[id] = nil
    end
    -- Rarity of the kill: a dungeon boss is rare; a raid, a heroic or harder run, or a fight that took falls lifts it.
    local tier = 3
    local okInfo, _, instanceType, difficultyID = pcall(GetInstanceInfo)
    if not okInfo then instanceType, difficultyID = nil, nil end
    if instanceType == "raid" then tier = tier + 1 end
    if type(difficultyID) == "number" and K.HARD_DIFFICULTY[difficultyID] then tier = tier + 1 end
    if tries and tries >= 2 then tier = tier + 1 end
    if not id then tier = 2 end   -- a world boss or an elite met on the road, away from any dungeon
    AddEntry("boss", name, nil, { tries = tries, tier = math.max(2, math.min(5, tier)) })
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
    local link, src, quantity
    for _, def in ipairs(LootPatterns()) do
        local found, amount = text:match(def[1])
        if found then link, src, quantity = found, def[2], tonumber(amount); break end
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
    local qty = quantity or 1
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
        if ns.CheckAnniversary then pcall(ns.CheckAnniversary) end
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
    local female = UnitSex and UnitSex("player") == 3
    t = t:gsub("%$[Gg]([^:;]*):([^;]*);", function(male, woman)
        return ((female and woman or male):gsub("^%s+", ""):gsub("%s+$", ""))
    end)
    t = t:gsub("%$%w+", "")
    t = t:gsub("%s+", " ")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    if #t > 230 then
        t = K.TextPrefix(t, 230):gsub("%s+%S*$", "") .. "..."
    end
    return t ~= "" and t or nil
end
ns.ExpandQuestText = Expand
local TIP_TIER = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
ns.QuestTip = function(tip, e)
    local col = TIP_TIER[e.tier or 1] or TIP_TIER[1]
    tip:ClearLines()
    pcall(tip.SetMinimumWidth, tip, 260)
    tip:AddLine(tostring(QuestTitleNow(e) or L.UNKNOWN_QUEST), col[1], col[2], col[3], true)

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
    -- In an English client the database's own text wins: what was kept may be in the language the game had then.
    if not (objective and GetLocale() == "enUS") then
        objective = (type(e.ot) == "string" and e.ot ~= "" and Expand(e.ot)) or objective
    end
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
K.FAMILY_ICONS = {
    { "bat", "chauve", "morcego" }, { "bear", "urso", "ours" }, { "boar", "javali", "sanglier" },
    { "carrion", "carni", "charogn", "vulture", "abutre" }, { "croc" }, { "cat", "gato", "f\195\169lin", "felin", "panter" },
    { "crab", "caranguejo" }, { "gorill" }, { "hyen", "hiena" }, { "owl", "coruja", "chouette" }, { "raptor" },
    { "scorp", "escorp" }, { "spider", "aranha", "araign" }, { "strider", "moa", "trotteur" }, { "turtle", "tartaruga", "tortue" },
    { "wind", "vento", "vents" }, { "wolf", "lobo", "loup" },
}
-- Our own pet art (Textures\\pet_<family>.tga) is used once it is in the style of the book; until then, the game's icons.
K.OWN_PET_ART = true
K.FAMILY_GAME_ICONS = {
    "Bat", "Bear", "Boar", "Vulture", "Crocolisk", "Cat", "Crab", "Gorilla", "Hyena", "Owl", "Raptor",
    "Scorpid", "Spider", "TallStrider", "Turtle", "WindSerpent", "Wolf",
}
K.FAMILY_ICON_FILES = {
    "bat", "bear", "boar", "carrion", "crocolisk", "cat", "crab", "gorilla", "hyena", "owl", "raptor",
    "scorpid", "spider", "tallstrider", "turtle", "windserpent", "wolf",
}
-- Where the animal is inside its picture (left, right, top, bottom as fractions): a wide one is drawn
-- at the full width of its place instead of shrunk into a square.
K.FAMILY_BOX = {
    bat = { 0.055, 0.984, 0.148, 0.852 }, bear = { 0.055, 0.945, 0.070, 0.945 }, boar = { 0.102, 0.938, 0.078, 0.930 },
    carrion = { 0.055, 0.961, 0.055, 0.953 }, cat = { 0.078, 0.930, 0.047, 0.961 }, crab = { 0.039, 0.961, 0.086, 0.922 },
    crocolisk = { 0.055, 0.953, 0.133, 0.867 }, gorilla = { 0.078, 0.938, 0.070, 0.930 }, hyena = { 0.047, 0.977, 0.070, 0.930 },
    owl = { 0.188, 0.867, 0.078, 0.914 }, raptor = { 0.133, 0.906, 0.047, 0.953 }, scorpid = { 0.086, 0.945, 0.086, 0.938 },
    spider = { 0.078, 0.938, 0.094, 0.922 }, tallstrider = { 0.180, 0.938, 0.023, 0.977 }, turtle = { 0.047, 0.984, 0.164, 0.836 },
    windserpent = { 0.047, 0.953, 0.031, 0.969 }, wolf = { 0.109, 0.891, 0.078, 0.914 },
}
-- The family is saved as the client gave it, in the language of that day: a pet met in an English client stays "Wolf" in a
-- Portuguese one. A name we know in any of the three languages is shown in the language of now; any other (the game's
-- own word for a family we do not list) is shown as saved.
K.FAMILY_NAMES = {
    { enUS = "Bat", ptBR = "Morcego", frFR = "Chauve-souris" }, { enUS = "Bear", ptBR = "Urso", frFR = "Ours" },
    { enUS = "Boar", ptBR = "Javali", frFR = "Sanglier" }, { enUS = "Carrion Bird", ptBR = "Ave de Carni\195\167a", frFR = "Charognard" },
    { enUS = "Crab", ptBR = "Caranguejo", frFR = "Crabe" }, { enUS = "Crocolisk", ptBR = "Crocolisco", frFR = "Crocolisque" },
    { enUS = "Cat", ptBR = "Gato", frFR = "F\195\169lin" }, { enUS = "Gorilla", ptBR = "Gorila", frFR = "Gorille" },
    { enUS = "Hyena", ptBR = "Hiena", frFR = "Hy\195\168ne" }, { enUS = "Owl", ptBR = "Coruja", frFR = "Chouette" },
    { enUS = "Raptor", ptBR = "Raptor", frFR = "Raptor" }, { enUS = "Scorpid", ptBR = "Escorpi\195\173deo", frFR = "Scorpide" },
    { enUS = "Spider", ptBR = "Aranha", frFR = "Araign\195\169e" }, { enUS = "Wolf", ptBR = "Lobo", frFR = "Loup" },
    { enUS = "Turtle", ptBR = "Tartaruga", frFR = "Tortue" },
}
Mile.FamilyLabel = function(fam)
    if type(fam) ~= "string" or fam == "" then return fam end
    local lower = fam:lower()
    local here = GetLocale()
    for _, names in ipairs(K.FAMILY_NAMES) do
        for _, name in pairs(names) do
            if name:lower() == lower then return names[here] or names.enUS end
        end
    end
    return fam
end
ns.FamilyLabel = Mile.FamilyLabel   -- (the page text is built above, before Mile exists)
-- Puts the picture of a family on a texture, no larger than size x size.
Mile.SetFamilyIcon = function(tex, family, size)
    local path, key = Mile.FamilyIcon(family)
    tex:SetTexture(path)
    local box = K.OWN_PET_ART and key and K.FAMILY_BOX[key]
    if not box then
        tex:SetSize(size, size)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        return
    end
    local pad = 0.01
    local l, r, t, b = math.max(0, box[1] - pad), math.min(1, box[2] + pad), math.max(0, box[3] - pad), math.min(1, box[4] + pad)
    local w, h = r - l, b - t
    local big = math.max(w, h)
    tex:SetTexCoord(l, r, t, b)
    tex:SetSize(size * w / big, size * h / big)
end
Mile.FamilyIcon = function(family)
    local name = type(family) == "string" and family:lower() or ""
    for i, words in ipairs(K.FAMILY_ICONS) do
        for _, w in ipairs(words) do
            if name:find(w, 1, true) then
                if K.OWN_PET_ART then return "Interface\\AddOns\\Skald\\Textures\\pet_" .. K.FAMILY_ICON_FILES[i], K.FAMILY_ICON_FILES[i] end
                return "Interface\\Icons\\Ability_Hunter_Pet_" .. K.FAMILY_GAME_ICONS[i]
            end
        end
    end
    return "Interface\\AddOns\\Skald\\Textures\\ev_pet"
end

Mile.BuildPets = function(panel)
    local petsHead = PageHeading(panel, L.TAB_PETS, 0)
    local nowLabel = SectionLabel(panel, L.PETS_NOW, 0, -52)
    local iconFrame = panel:CreateTexture(nil, "BACKGROUND")
    iconFrame:SetSize(46, 46)
    iconFrame:SetPoint("TOPLEFT", 0, -76)
    if K.OWN_PET_ART then iconFrame:SetColorTexture(0, 0, 0, 0) else iconFrame:SetColorTexture(K.BTN.gold[1], K.BTN.gold[2], K.BTN.gold[3], 1) end
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(K.OWN_PET_ART and 50 or 42, K.OWN_PET_ART and 50 or 42)
    icon:SetPoint("CENTER", iconFrame, "CENTER")
    if not K.OWN_PET_ART then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    icon:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_pet")
    local name = panel:CreateFontString(nil, "OVERLAY", "SkaldHead")
    name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 14, -4)
    name:SetWidth(K.CW - 72)
    name:SetJustifyH("LEFT")
    name:SetTextColor(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3])

    -- The facts, in two columns: a small label over each value.
    local function Cell(col, row, label)
        local x, y = 230, -230 - (row - 1) * 90
        local l = panel:CreateFontString(nil, "OVERLAY", "SkaldSec")
        l:SetPoint("TOPLEFT", x, y)
        l:SetWidth(124)
        l:SetJustifyH("LEFT")
        l:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
        l:SetText(Upper(label))
        local v = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
        v:SetPoint("TOPLEFT", x, y - 16)
        v:SetWidth(124)
        v:SetJustifyH("LEFT")
        v:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        return v, l
    end
    local sinceV, sinceL = Cell(1, 1, L.PETL_SINCE)
    local dietV, dietL = Cell(1, 2, L.PETL_DIET)
    local lastLine = NoteText(panel, 0, -126)
    local subLine = panel:CreateFontString(nil, "OVERLAY", "SkaldNote")
    subLine:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    subLine:SetWidth(K.CW - 72)
    subLine:SetJustifyH("LEFT")
    subLine:SetTextColor(K.C_NOTE[1], K.C_NOTE[2], K.C_NOTE[3])
    PageRule(panel, 0, -146)

    -- The companion itself, standing in an arched frame like the character on the cover. Only the pet
    -- that is out can be drawn; for any other the paw takes its place.
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetSize(191, 226)
    holder:SetPoint("TOPLEFT", 9, -176)
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
            self.skaldZoom = math.max(0.6, math.min(5, (self.skaldZoom or 1.4) - (delta or 0) * 0.25))
            pcall(self.SetCamDistanceScale, self, self.skaldZoom)
        end)
    end
    local emblem = panel:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(48, 48)
    emblem:SetPoint("TOPLEFT", 4, -80)
    emblem:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_pet")
    emblem:SetAlpha(0.6)
    local placeholder = holder:CreateTexture(nil, "ARTWORK")
    placeholder:SetSize(56, 56)
    placeholder:SetPoint("CENTER")
    placeholder:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_pet")
    placeholder:SetAlpha(0.55)
    local alcove = CreateFrame("Frame", nil, panel)
    alcove:SetFrameLevel(holder:GetFrameLevel() + 5)
    alcove:SetSize(209, 246)
    alcove:SetPoint("TOPLEFT", 0, -168)
    local alcoveTex = alcove:CreateTexture(nil, "OVERLAY")
    alcoveTex:SetAllPoints()
    alcoveTex:SetTexture(K.TEX .. "alcove")
    alcoveTex:SetTexCoord(0, 316 / 512, 0, 372 / 512)
    local function ShowPet(petName)
        local out = false
        if okModel and model and petName and UnitExists("pet") and Safe(UnitName("pet")) == petName then
            out = pcall(model.SetUnit, model, "pet")
            if out then
                model.skaldZoom, model.skaldAngle = 1.4, 0.6   -- far enough for the big ones to fit the arch
                pcall(model.SetCamDistanceScale, model, model.skaldZoom)
                pcall(model.SetFacing, model, model.skaldAngle)
            end
        end
        if model then model:SetShown(out) end
        placeholder:SetShown(not out)
    end

    local listHead = PageHeading(panel, L.PETS_ALL, K.RIGHT_X)
    local rows = {}
    for i = 1, 6 do
        local top = -74 - (i - 1) * 58
        local frame = panel:CreateTexture(nil, "BACKGROUND")
        frame:SetSize(46, 46)
        frame:SetPoint("TOPLEFT", K.RIGHT_X, top)
        frame:SetColorTexture(K.C_HEAD[1], K.C_HEAD[2], K.C_HEAD[3], K.OWN_PET_ART and 0 or 0.85)
        local pic = panel:CreateTexture(nil, "ARTWORK")
        pic:SetSize(K.OWN_PET_ART and 34 or 30, K.OWN_PET_ART and 34 or 30)
        pic:SetPoint("CENTER", frame, "CENTER")
        if not K.OWN_PET_ART then pic:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        local a = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
        a:SetPoint("TOPLEFT", K.RIGHT_X + 58, top + 1)
        a:SetWidth(K.CW - 58)
        a:SetJustifyH("LEFT")
        a:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
        local b = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
        b:SetPoint("TOPLEFT", K.RIGHT_X + 58, top - 22)
        b:SetWidth(K.CW - 58)
        b:SetJustifyH("LEFT")
        b:SetTextColor(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3])
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", K.RIGHT_X, top - 54)
        line:SetSize(K.CW, 1)
        line:SetColorTexture(K.C_MUTED[1], K.C_MUTED[2], K.C_MUTED[3], 0.28)
        rows[i] = { a, b, frame, pic, line }
        -- The one at my side: a thin gold outline round its row and a small tag, nothing else moves.
        local mark = {}
        local gold = K.BTN.gold
        local function Edge(p1, p2, w, h)
            local t = panel:CreateTexture(nil, "ARTWORK")
            t:SetPoint(p1, panel, "TOPLEFT", p2[1], p2[2])
            t:SetSize(w, h)
            t:SetColorTexture(gold[1], gold[2], gold[3], 0.9)
            mark[#mark + 1] = t
        end
        Edge("TOPLEFT", { K.RIGHT_X - 3, top + 3 }, K.CW + 6, 1)
        Edge("TOPLEFT", { K.RIGHT_X - 3, top - 54 }, K.CW + 6, 1)
        Edge("TOPLEFT", { K.RIGHT_X - 3, top + 3 }, 1, 58)
        Edge("TOPLEFT", { K.RIGHT_X + K.CW + 2, top + 3 }, 1, 58)
        local tag = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        tag:SetPoint("TOPRIGHT", panel, "TOPLEFT", K.RIGHT_X + K.CW - 4, top - 1)
        tag:SetTextColor(gold[1], gold[2], gold[3])
        tag:SetText(Upper(L.PETS_NOW))
        mark[#mark + 1] = tag
        rows[i].mark = mark
    end
    -- With no companion yet the right page carries one short centred line instead of the list.
    local empty = NoteText(panel, K.RIGHT_X + 20, -52)
    empty:SetWidth(K.CW - 40)
    empty:SetJustifyH("CENTER")
    PageRule(panel, K.RIGHT_X, -436)
    local total = NoteText(panel, K.RIGHT_X, -458)
    total:SetWidth(K.CW)
    total:SetJustifyH("CENTER")

    local facts = { dietV, dietL, sinceV, sinceL }
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
        -- Empty: the big arch is hidden (an empty frame looks unfinished); a small paw stands under the label and
        -- the right page has one short line under its title.
        if #list == 0 then empty:Show(); emblem:Show(); holder:Hide(); alcove:Hide()
        else empty:Hide(); emblem:Hide(); holder:Show(); alcove:Show() end
        nowLabel:SetText(#list == 0 and L.PETS_CURRENT or (out and L.PETS_NOW or L.PETS_NONE_NOW))
        lastLine:SetText("")
        if #list == 0 then
            empty:SetText(L.PETS_NONE)
            name:SetText(""); subLine:SetText(""); total:SetText("")
            icon:Hide(); iconFrame:Hide(); ShowFacts(false)
            ShowPet(nil)
        elseif not out then
            icon:Hide(); iconFrame:Hide(); ShowFacts(false)
            name:SetText(""); subLine:SetText("")
            lastLine:SetText(string.format(L.PETS_LAST, list[1].name))
            total:SetText(string.format(L.PETS_TOTAL, #list))
            ShowPet(nil)
        else
            local rec = out.rec
            icon:Show(); iconFrame:Show(); ShowFacts(true)
            Mile.SetFamilyIcon(icon, rec.fam, K.OWN_PET_ART and 52 or 42)
            name:SetText(out.name)
            subLine:SetText((table.concat({ Mile.FamilyLabel(rec.fam) or "", (rec.lv and rec.lv > 0) and string.format(L.TIP_LEVEL, rec.lv) or "" }, "  -  "):gsub("^  %-  ", ""):gsub("  %-  $", "")))
            local hasDiet = type(rec.diet) == "string" and rec.diet ~= "" and rec.diet ~= "-"
            dietV:SetText(hasDiet and rec.diet or ""); dietL:SetShown(hasDiet)
            sinceV:SetText(date(L.DAY_DATE, rec.t or time()))
            total:SetText(string.format(L.PETS_TOTAL, #list))
            ShowPet(out.name)
        end
        for i = 1, 6 do
            local item = list[i]
            if item then
                Mile.SetFamilyIcon(rows[i][4], item.rec.fam, K.OWN_PET_ART and 36 or 30)
                local atSide = out and item.name == out.name
                rows[i][4]:SetVertexColor(1, 1, 1)
                rows[i][4]:SetAlpha(atSide and 1 or 0.85)
                if not K.OWN_PET_ART then
                    local c = atSide and K.BTN.gold or K.C_HEAD
                    rows[i][3]:SetColorTexture(c[1], c[2], c[3], atSide and 1 or 0.85)
                end
                rows[i][1]:SetTextColor(atSide and K.C_HEAD[1] or K.C_BODY[1], atSide and K.C_HEAD[2] or K.C_BODY[2], atSide and K.C_HEAD[3] or K.C_BODY[3])
                rows[i][1]:SetText(item.name)
                for _, m in ipairs(rows[i].mark) do if atSide then m:Show() else m:Hide() end end
                local parts = {}
                if item.rec.fam then parts[#parts + 1] = Mile.FamilyLabel(item.rec.fam) end
                if item.rec.lv and item.rec.lv > 0 then parts[#parts + 1] = string.format(L.TIP_LEVEL, item.rec.lv) end
                parts[#parts + 1] = date(L.DAY_DATE, item.rec.t or time())
                rows[i][2]:SetText(table.concat(parts, "  -  "))
                for _, part in ipairs(rows[i]) do part:Show() end
            else
                for _, part in ipairs(rows[i]) do part:Hide() end
                for _, m in ipairs(rows[i].mark) do m:Hide() end
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
-- The small picture a page has in the book (the item of a loot, the seal of a quest, the icon of its kind).
SkaldAPI.EntryIcon = function(e)
    return (e.kind == "loot" and ItemIcon(e)) or (e.kind == "note" and (K.TEX .. "dd_scroll"))
        or (e.kind == "quest" and e.tier and (K.SEAL_PATH .. e.tier)) or EventIconPath(e.kind, e)
end
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
        if C_Timer.NewTicker then C_Timer.NewTicker(60, function() pcall(CheckMarks); pcall(Mile.CheckPet); pcall(ns.CheckAnniversary); pcall(Mile.TrackKills) end) end
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

H.UI_SCALE_CHANGED = function(self, event, ...)
    if window then window:FitScale() end
end
H.DISPLAY_SIZE_CHANGED = H.UI_SCALE_CHANGED

H.ZONE_CHANGED_NEW_AREA = function(self, event, ...)
    if window then CheckZone() end
end
H.PLAYER_ENTERING_WORLD = H.ZONE_CHANGED_NEW_AREA

-- What the quest asks, in the client's own language: from the quest dialog when it is offered, and from the
-- quest log when it is handed in. Kept by quest id until the quest is turned in.
K.OBJECTIVE_KEPT = 150
K.OBJECTIVE_LEN, K.OBJECTIVE_MIN_TIER = 240, 2   -- the tooltip shows 230 characters; a page keeps the text only from this rarity up (the saved file stays small)
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
    text = K.TextPrefix(text, K.OBJECTIVE_LEN)
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

-- Creatures slain in each zone: the game counts the total, so the difference since the last look goes to the zone
-- underfoot (the first look only sets the baseline, and kills inside an instance count for no zone).
Mile.TrackKills = function()
    local db = Journal()
    if not ready or not db or not (ns.ZoneCard and C_Map and C_Map.GetBestMapForUnit) then return end
    local total = KillStat()
    if not total then
        local byId = GameStat(107)
        if byId and byId > 0 then total = byId end
    end
    if not total then return end
    local base = db.killBase
    db.killBase = total
    if not base or total <= base then return end
    local ok, here = pcall(C_Map.GetBestMapForUnit, "player")
    local zone = ok and here and ns.ZoneCard.ZoneMap(here)
    if not zone then return end
    db.zoneKills = db.zoneKills or {}
    db.zoneKills[zone] = (db.zoneKills[zone] or 0) + (total - base)
end

ns.TrackKills = Mile.TrackKills

H.PLAYER_XP_UPDATE = function(self, event, ...)
    if ready then OnXPChanged() end
    if ready and not Mile.killsWait then
        Mile.killsWait = true
        C_Timer.After(3, function() Mile.killsWait = false; pcall(Mile.TrackKills) end)
    end
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
              ot = (tier >= K.OBJECTIVE_MIN_TIER) and ((type(ns.pendingObjective) == "string" and ns.pendingObjective ~= "" and ns.pendingObjective)
                  or (Journal() and Journal().questObj and Journal().questObj[questID])) or nil,
              ql = pendingQuestLevel, pl = UnitLevel and UnitLevel("player"), nid = Mile.npcId,
              mr = (type(moneyReward) == "number" and moneyReward > 0) and moneyReward or nil })
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

-- The days of the journey: a quiet notice a week, a month, a hundred days and a year after the first page. A mark is told
-- once, within two weeks of its day; a diary found long after one (an old one, the first time this is looked at) is
-- brought up to date without a word.
K.ANNIV_STEPS, K.ANNIV_WINDOW = { 7, 30, 100, 365 }, 14
ns.CheckAnniversary = function()
    local db = Journal()
    if not ready or not db or not db.stats or not db.stats.first or db.stats.first <= 0 or not window then return end
    local now = time()
    if loginTime and now - loginTime < K.MEMORY_AFTER_LOGIN then return end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return end
    if IsInInstance and IsInInstance() then return end
    local days = math.floor((now - db.stats.first) / 86400)
    local step
    for _, m in ipairs(K.ANNIV_STEPS) do
        if days >= m and m > (db.anniv or 0) then step = m end
    end
    if not step then return end
    db.anniv = step
    if days >= step + K.ANNIV_WINDOW or Settings().memories == false then return end
    local list = PHRASES["anniv" .. step]
    if not list or #list == 0 then return end
    Mile.memoryIdx = Mile.memoryIdx or {}
    local key = "anniv" .. step
    local idx = math.random(#list)
    if #list > 1 and idx == Mile.memoryIdx[key] then idx = idx % #list + 1 end
    Mile.memoryIdx[key] = idx
    ns.ShowNotice(L.MEMORY_TITLE, list[idx], 3, 9, db.entries and db.entries[1])
end

-- Someone I shared a dungeon with has joined my group again after a while: the page tells where we were.
K.REUNION_GAP, K.REUNION_EVERY = 86400, 3 * 86400
Mile.reunionTold = {}

-- After the whole diary is swapped (a backup restored or put back): what the session held about the old one goes,
-- and the book is drawn again.
ns.RefreshDiary = function()
    K.nameSet = nil
    K.overWarned = nil
    Mile.reunionTold = {}
    ns.layoutRev = (ns.layoutRev or 0) + 1
    if window and window:IsShown() then window:Refresh() end
end
Mile.CheckReunion = function()
    local db = Journal()
    if not ready or not db or Settings().companions == false then return end
    if not (IsInGroup and IsInGroup()) then Mile.reunionTold = {}; return end
    local comp = db.companions
    if not comp then return end
    local now = time()
    for i = 1, 4 do
        local name = (not UnitExists or UnitExists("party" .. i)) and K.WhoKey("party" .. i) or nil
        local c = type(name) == "string" and comp[name]
        if c and c.shared and not Mile.reunionTold[name] then
            Mile.reunionTold[name] = true
            local away = now - math.max(c.last or 0, c.seen or 0)
            c.seen = now
            if away >= K.REUNION_GAP and now - (c.told or 0) >= K.REUNION_EVERY then
                c.told = now
                AddEntry("reunion", K.WhoShort(name), nil, { pz = c.pz, pn = c.pn })
            end
        end
    end
end

-- Inviting someone already counts as being in a group for IsInGroup(), even if they decline: the first group
-- only counts once another player is really in it.
K.InGroupWithOthers = function()
    if not (IsInGroup and IsInGroup()) then return false end
    if GetNumGroupMembers then return (GetNumGroupMembers() or 0) >= 2 end
    return UnitExists ~= nil and UnitExists("party1") and true or false
end

H.GROUP_ROSTER_UPDATE = function(self, event, ...)
    local db = Journal()
    if not Mile.reunionWait then
        Mile.reunionWait = true
        C_Timer.After(3, function() Mile.reunionWait = false; pcall(Mile.CheckReunion) end)
    end
    if ready and db and not db.flags.party and K.InGroupWithOthers() then
        db.flags.party = true
        AddEntry("party")
    end
end

-- Probe for talking to other addons (the shared chronicle is only worth planning if the client lets addons
-- talk): /skald probe comms sends one tiny message on each channel that makes sense and keeps what came back.
K.COMMS_PREFIX = "SKALD1"
H.VOICE_CHAT_TTS_PLAYBACK_FINISHED = function() if ns.SpeechFinished then ns.SpeechFinished() end end
H.CHAT_MSG_ADDON = function(self, event, prefix, text, channel, sender)
    local probe = SkaldDB and SkaldDB.commsProbe
    if not probe or prefix ~= K.COMMS_PREFIX then return end
    probe.received = probe.received or {}
    if #probe.received < 10 then
        probe.received[#probe.received + 1] = tostring(channel) .. " <- " .. tostring(Safe(sender) and "sender" or "?") .. ": " .. tostring(Safe(text) or "")
    end
end

ns.ProbeComms = function(whisperTo)
    local api = C_ChatInfo or {}
    local send = api.SendAddonMessage or SendAddonMessage
    local probe = { when = time(), api = {}, sent = {}, received = {} }
    SkaldDB.commsProbe = probe
    for _, name in ipairs({ "RegisterAddonMessagePrefix", "SendAddonMessage", "IsAddonMessagePrefixRegistered" }) do
        probe.api[name] = (type(api[name]) == "function") and "yes" or "no"
    end
    local reg = api.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    local okReg, resReg = false, "no function"
    if reg then okReg, resReg = pcall(reg, K.COMMS_PREFIX); resReg = tostring(resReg) end
    probe.register = (okReg and "ok " or "error ") .. tostring(resReg)
    if send then
        -- SAY answers "invalid chat type" (4) in this client and a whisper to oneself is refused by the game, so
        -- the channels tried are the group, the guild and, if a name is given, a whisper to that player
        local targets = {}
        if whisperTo and whisperTo ~= "" then targets[#targets + 1] = { "WHISPER", whisperTo } end
        if IsInGroup and IsInGroup() then targets[#targets + 1] = { IsInRaid and IsInRaid() and "RAID" or "PARTY" } end
        if IsInGuild and IsInGuild() then targets[#targets + 1] = { "GUILD" } end
        for _, t in ipairs(targets) do
            local ok, res = pcall(send, K.COMMS_PREFIX, "probe", t[1], t[2])
            probe.sent[#probe.sent + 1] = t[1] .. " " .. (ok and "ok " or "error ") .. tostring(res)
        end
    end
    C_Timer.After(4, function()
        if #probe.sent == 0 then Say(L.COMMS_NONE); return end
        Say(string.format(L.COMMS_RESULT, #probe.received, #probe.sent))
    end)
end

H.ENCOUNTER_START = function(self, event, ...)
    local id, name = ...
    ns.encounter = { id = tonumber(id), name = Safe(name), at = time() }
end

H.ENCOUNTER_END = function(self, event, ...)
    local id, name, _, _, success = ...
    if ns.encounter then ns.encounter.ended = true end
    if success == 1 then BossDown(name, tonumber(id)) end
end

H.BOSS_KILL = function(self, event, ...)
    local id, name = ...
    BossDown(name, tonumber(id))
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
    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
        if Settings().probeSpells then pcall(Mile.ProbeEvent, event, ...) end
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
    -- which events this client really fires, for /skald report (only a count per name)
    if SkaldDB then
        local seen = SkaldDB.seenEvents
        if not seen then seen = {}; SkaldDB.seenEvents = seen end
        seen[event] = (seen[event] or 0) + 1
    end
    local ok, err = pcall(HandleEvent, self, event, ...)
    if not ok then
        local report = tostring(event) .. ": " .. tostring(err)
        if not reported[report] then
            reported[report] = true
            if SkaldDB then
                SkaldDB.lastError = report
                SkaldDB.errors = SkaldDB.errors or {}
                table.insert(SkaldDB.errors, report)
                while #SkaldDB.errors > 8 do table.remove(SkaldDB.errors, 1) end
            end
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
    s = s:gsub("|H.-|h(.-)|h", "%1")
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

-- The names of other players (companions of a dungeon, someone met again) are replaced by "a companion" in what
-- is exported, unless the player asks to keep them (a switch in the export window).
-- One pass over the words of the text, looking each one up in a set (a diary of 3000 pages and 200 companions
-- stays fast); the set of the companions is made once for each export (K.nameSet is cleared where one begins).
local function HideNames(text, e)
    if not K.nameSet then
        K.nameSet = {}
        for n in pairs((Journal() and Journal().companions) or {}) do
            K.nameSet[n] = true
            local base = tostring(n):match("^([^%-]+)%-")
            if base then K.nameSet[base] = true end   -- the page may tell only the name, without the realm
        end
    end
    local set = K.nameSet
    local extra
    local function addExtra(n)
        n = tostring(n)
        if set[n] then return end
        extra = extra or {}
        extra[n] = true
        local base = n:match("^([^%-]+)%-")
        if base then extra[base] = true end
    end
    for _, n in ipairs(e.with or {}) do addExtra(n) end
    if e.kind == "reunion" then addExtra(e.arg) end
    local function known(word) return set[word] or (extra and extra[word]) end
    -- "Name-Realm" is one name for the game: it is looked up whole, then by the name alone (and a realm that
    -- begins with a capital after it goes too).
    return (text:gsub("([%w\128-\255]+)(%-?)([%w\128-\255]*)", function(a, dash, b)
        if dash ~= "" and known(a .. dash .. b) then return L.EXPORT_SOMEONE end
        if known(a) then
            if dash ~= "" and b:match("^[%u\192-\222]") then return L.EXPORT_SOMEONE end
            return L.EXPORT_SOMEONE .. dash .. b
        end
        if dash == "" then return nil end
        if known(b) then return a .. dash .. L.EXPORT_SOMEONE end
    end))
end
ns.HideNames = HideNames

local function ExportBlock(e, format)
    local head = date(L.DATE_FMT, e.t) .. " - " .. PlainText(ns.PlaceName(e))
    if e.kind == "quest" and e.tier and e.tier >= 2 and L.TIERS[e.tier] then
        head = head .. "  -  " .. L.TIERS[e.tier]
    end
    local body = PlainText(RenderEntry(e))
    if Settings().exportHideNames ~= false then body = HideNames(body, e) end
    if format == "discord" then
        return "> **" .. head .. "**\n> " .. body
    end
    return "[" .. head .. "]\n" .. body
end

-- The text for the web Reader (the diary read as a book outside the game): one line per field-group, fields
-- separated by "^" (a "^" inside is written backslash-p, a newline backslash-n, a backslash twice). Each part
-- starts with a header line and carries a checksum of its body, so the page knows when something was copied
-- half-way.
K.READER_LIMIT = 16000   -- characters of a part: a text box with much more than this is slow to draw
K.NL, K.BS = string.char(10), string.char(92)
K.ReaderEscape = function(t)
    t = tostring(t or "")
    t = t:gsub(K.BS, K.BS .. K.BS)
    t = t:gsub("%^", K.BS .. "p")
    t = t:gsub(K.NL, K.BS .. "n")
    return t
end
K.ReaderChecksum = function(text)
    local h = 5381
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 4294967296 end
    return h
end
K.ReaderLine = function(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = K.ReaderEscape((select(i, ...))) end
    return table.concat(out, "^")
end
-- What the tooltip of a page shows in the game, as key=value pairs joined by "~", for the Reader to show on hover.
K.ReaderInfo = function(e)
    local pairsOut = {}
    local function Add(key, value)
        if value == nil or value == "" or value == false then return end
        value = PlainText(tostring(value)):gsub("[~=]", " ")
        pairsOut[#pairsOut + 1] = key .. "=" .. value
    end
    if e.kind == "quest" then
        Add("title", e.arg); Add("q", e.q); Add("ql", e.ql); Add("npc", e.npc)
        if type(e.ot) == "string" and e.ot ~= "" then
            local text = ns.ExpandQuestText and ns.ExpandQuestText(e.ot) or e.ot
            Add("ot", text and K.TextPrefix(text, 230))
        end
    elseif e.kind == "loot" then
        Add("title", e.arg); Add("iid", e.iid); Add("n", e.n)
    elseif e.kind == "boss" or e.kind == "dungeon" or e.kind == "tame" or e.kind == "skill" or e.kind == "profession" then
        Add("title", e.arg); Add("tries", e.tries)
    end
    return table.concat(pairsOut, "~")
end
local function BuildReader(scope)
    K.nameSet = nil
    local entries = SelectEntries(scope)
    local db = Journal()
    if #entries == 0 or not db then return {} end
    local hide = Settings().exportHideNames ~= false
    local lines = {}
    local st = db.stats or {}
    lines[#lines + 1] = K.ReaderLine("S", st.first or 0, st.played or 0)
    for kind, n in pairs(st.counts or {}) do lines[#lines + 1] = K.ReaderLine("N", kind, n) end
    for tier, n in pairs(st.tiers or {}) do lines[#lines + 1] = K.ReaderLine("T", tier, n) end
    for id, rec in pairs(db.goals or {}) do
        lines[#lines + 1] = K.ReaderLine("G", id, type(rec) == "table" and rec.t or 0, (type(rec) == "table" and rec.retro) and 1 or 0,
            ns.GoalPoints and ns.GoalPoints(id) or 0)
    end
    -- the Saga, chapter by chapter (the names of the companions hidden like in the pages)
    if ns.BuildSaga then
        local okSaga, chapters = pcall(ns.BuildSaga)
        if okSaga then
            for _, c in ipairs(chapters) do
                local text = c.text
                if hide then text = HideNames(text, {}) end
                lines[#lines + 1] = K.ReaderLine("V", c.key, c.title, text)
            end
        end
    end
    local summary = #lines
    for _, e in ipairs(entries) do
        local body = PlainText(RenderEntry(e))
        if hide then body = HideNames(body, e) end
        local note = (e.fav and type(e.favNote) == "string") and PlainText(e.favNote) or ""
        if hide and note ~= "" then note = HideNames(note, e) end
        local ic = e.kind == "loot" and ("loot:" .. tostring(e.cat or "")) or tostring(e.kind)
        lines[#lines + 1] = K.ReaderLine("P", e.t or 0, e.kind, e.tier or 0, e.fav and 1 or 0,
            PlainText(tostring(ns.PlaceName(e) or "")), ic, K.TextPrefix(body, 700), K.TextPrefix(note, 300), K.ReaderInfo(e))
    end
    -- the parts: the summary lines open the first
    local bodies, current, size = {}, {}, 0
    for _, line in ipairs(lines) do
        if size + #line + 1 > K.READER_LIMIT and #current > 0 then
            bodies[#bodies + 1] = table.concat(current, K.NL)
            current, size = {}, 0
        end
        current[#current + 1] = line
        size = size + #line + 1
    end
    if #current > 0 then bodies[#bodies + 1] = table.concat(current, K.NL) end
    local out = {}
    local name = UnitName and UnitName("player") or "?"
    local class = (UnitClass and select(1, UnitClass("player"))) or ""
    local race = (UnitRace and select(1, UnitRace("player"))) or ""
    for i, body in ipairs(bodies) do
        local header = K.ReaderLine("H", "SKALDREADER1", name, class, race, UnitLevel and UnitLevel("player") or 0,
            (SkaldDB and SkaldDB.tone) or "epic", GetLocale(), #entries, i, #bodies, K.ReaderChecksum(body))
        out[i] = header .. K.NL .. body
    end
    return out
end

-- Reading aloud, with the game's own text-to-speech (the calls the DialogueUI addon makes in this client). The text
-- goes in short pieces, one after the other: the next starts when the game says one has finished (and, if that event
-- never comes in this client, after a time worked out from the length).
K.speech = { queue = {}, id = 0, eventSeen = false }
ns.SpeechOn = false   -- switched off: the voice of the game's text-to-speech was not good enough (set true to bring it back)
ns.SpeechAvailable = function()
    return ns.SpeechOn and C_VoiceChat ~= nil and type(C_VoiceChat.SpeakText) == "function" and C_TTSSettings ~= nil
end
ns.Speaking = function() return K.speech.current ~= nil end
local function SpeechClean(text)
    text = PlainText(tostring(text or ""))
    text = text:gsub("[<>]", ""):gsub("%-%-", ". ")
    return text
end
-- The text in pieces of a sentence or two, so that a long page can be stopped between them.
K.SpeechPieces = function(text, into)
    text = SpeechClean(text)
    for paragraph in (text .. K.NL .. K.NL):gmatch("(.-)" .. K.NL .. K.NL) do
        paragraph = strtrim(paragraph)
        while #paragraph > 0 do
            if #paragraph <= 380 then into[#into + 1] = paragraph; break end
            local cut = paragraph:sub(1, 380):match("^.*()[%.%?!] ")
            cut = cut or paragraph:sub(1, 380):match("^.*() ") or 380
            into[#into + 1] = strtrim(paragraph:sub(1, cut))
            paragraph = strtrim(paragraph:sub(cut + 1))
        end
    end
    return into
end
local SpeakNext
ns.StopSpeaking = function()
    local sp = K.speech
    sp.queue, sp.current = {}, nil
    sp.id = sp.id + 1
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
end
SpeakNext = function()
    local sp = K.speech
    local piece = table.remove(sp.queue, 1)
    if not piece then sp.current = nil; if ns.SpeechChanged then ns.SpeechChanged() end; return end
    sp.id = sp.id + 1
    local mine = sp.id
    sp.current = piece
    local voice, rate, volume = 0, 0, 100
    pcall(function()
        voice = C_TTSSettings.GetVoiceOptionID(0) or 0
        rate = C_TTSSettings.GetSpeechRate() or 0
        volume = C_TTSSettings.GetSpeechVolume() or 100
    end)
    local ok = pcall(C_VoiceChat.SpeakText, voice, piece, rate, volume, false)
    if not ok then ns.StopSpeaking(); if ns.SpeechChanged then ns.SpeechChanged() end; return end
    if not sp.eventSeen and C_Timer and C_Timer.After then
        C_Timer.After(#piece * 0.14 + 4, function() if K.speech.id == mine and K.speech.current then SpeakNext() end end)
    end
end
-- Reads these texts (each may hold paragraphs); false when this client cannot.
ns.SpeakTexts = function(texts)
    if not ns.SpeechAvailable() then return false end
    ns.StopSpeaking()
    local pieces = {}
    for _, t in ipairs(texts) do K.SpeechPieces(t, pieces) end
    if #pieces == 0 then return false end
    K.speech.queue = pieces
    SpeakNext()
    if ns.SpeechChanged then ns.SpeechChanged() end
    return true
end
ns.SpeechFinished = function()
    local sp = K.speech
    sp.eventSeen = true
    if sp.current then SpeakNext() end
end

-- Returns a list of texts, each short enough for one message (empty when there is nothing).
local function BuildExport(format, scope)
    K.nameSet = nil
    if format == "reader" then return BuildReader(scope) end
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
        if #block > K.EXPORT_LIMIT then block = K.TextPrefix(block, K.EXPORT_LIMIT) end
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
    f:SetSize(560, 430)
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
    title:SetPoint("CENTER", f, "TOPLEFT", 314, -28)   -- the middle of the clear band between the book and the right ornament of the banner
    title:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
    title:SetText(L.EXPORT_TITLE)
    local TEXR = "Interface\\AddOns\\Skald\\Textures\\"
    local readerHeader = f:CreateTexture(nil, "ARTWORK")
    readerHeader:SetPoint("TOPLEFT", 6, -1)
    readerHeader:SetSize(548, 54)
    readerHeader:SetTexture(TEXR .. "rd_header")
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
    Label(L.EXPORT_FORMAT, 20, -60)
    for i, choice in ipairs({ { "discord", L.FORMAT_DISCORD, "ex_discord" }, { "plain", L.FORMAT_PLAIN, "ex_plain" }, { "reader", L.FORMAT_READER, "rd_icon" } }) do
        local b = MakeParchmentButton(f, 138, 26, choice[2])
        b:SetPoint("TOPLEFT", 110 + (i - 1) * 144, -54)
        b:SetScript("OnClick", function() format = choice[1]; settings.exportFormat = format; part = 1; f:Refresh() end)
        b:SetIcon(TEXR .. choice[3])
        formatButtons[choice[1]] = b
    end
    Label(L.EXPORT_SCOPE, 20, -97)
    for i, choice in ipairs({ { "recent", L.SCOPE_RECENT, "ex_recent" }, { "notable", L.SCOPE_NOTABLE, "ex_notable" }, { "all", L.SCOPE_ALL, "ex_all" } }) do
        local b = MakeParchmentButton(f, 138, 26, choice[2])
        b:SetPoint("TOPLEFT", 110 + (i - 1) * 144, -92)
        b:SetScript("OnClick", function() scope = choice[1]; settings.exportScope = scope; part = 1; f:Refresh() end)
        b:SetIcon(TEXR .. choice[3])
        scopeButtons[choice[1]] = b
    end

    -- Parts, when the text is longer than one message.
    local prev = MakeParchmentButton(f, 36, 26, "")
    prev:SetIcon(TEXR .. "ex_prev")
    prev:SetPoint("TOPLEFT", 110, -130)
    prev:SetScript("OnClick", function() part = math.max(1, part - 1); f:Refresh() end)
    local nextButton = MakeParchmentButton(f, 36, 26, "")
    nextButton:SetIcon(TEXR .. "ex_next")
    nextButton:SetPoint("TOPLEFT", 152, -130)
    nextButton:SetScript("OnClick", function() part = math.min(#chunks, part + 1); f:Refresh() end)
    local partLabel = f:CreateFontString(nil, "OVERLAY", "QuestFont")
    partLabel:SetPoint("LEFT", nextButton, "RIGHT", 10, 0)
    partLabel:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
    local namesButton = MakeParchmentButton(f, 232, 26, "")
    namesButton:SetPoint("TOPRIGHT", -20, -130)
    namesButton:SetActive(false)
    namesButton:SetScript("OnClick", function()
        settings.exportHideNames = not (settings.exportHideNames ~= false)
        part = 1
        f:Refresh()
    end)

    -- The text: dark box, light letters, selected so Ctrl+C is all that is left to do.
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 20, -170)
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
    edit:SetWidth(496)
    edit:SetTextInsets(2, 2, 2, 2)
    scroll:SetScrollChild(edit)
    local shown = ""
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    -- Read only: anything typed is put back.
    edit:SetScript("OnTextChanged", function(self, byUser)
        if byUser then self:SetText(shown); self:HighlightText() end
    end)

    -- In the Reader format the text is not for reading: a card says what is ready, and the text sits small below it.
    local card = f:CreateFontString(nil, "OVERLAY", "QuestFont")
    card:SetPoint("TOPLEFT", 20, -174)
    card:SetPoint("TOPRIGHT", -20, -174)
    card:SetJustifyH("CENTER")
    card:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
    card:Hide()
    local pasteIcon = f:CreateTexture(nil, "OVERLAY")
    pasteIcon:SetSize(30, 30)
    pasteIcon:SetPoint("BOTTOMLEFT", 20, 14)
    pasteIcon:SetTexture(TEXR .. "rd_paste")
    pasteIcon:Hide()
    local readyIcon = f:CreateTexture(nil, "OVERLAY")
    readyIcon:SetSize(30, 30)
    readyIcon:SetPoint("BOTTOMRIGHT", -20, 14)
    readyIcon:SetTexture(TEXR .. "rd_ready")
    readyIcon:Hide()
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 22, 16)
    hint:SetWidth(516)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.15, 0.10, 0.04)
    hint:SetText(L.EXPORT_HINT)

    function f:Refresh()
        chunks = BuildExport(format, scope)
        part = math.max(1, math.min(part, math.max(1, #chunks)))
        shown = chunks[part] or L.EXPORT_EMPTY
        edit:SetText(shown)
        -- Tall enough for the text, so the scroll frame can scroll it.
        local isReader = format == "reader"
        local _, newlines = shown:gsub("\n", "")
        edit:SetFontObject(isReader and GameFontHighlightSmall or ChatFontNormal)
        edit:SetHeight(math.max(260, (newlines + math.ceil(#shown / (isReader and 96 or 70)) + 2) * (isReader and 12 or 14)))
        scroll:SetVerticalScroll(0)
        edit:HighlightText()
        for key, b in pairs(formatButtons) do b:SetActive(key == format) end
        for key, b in pairs(scopeButtons) do b:SetActive(key == scope) end
        local many = #chunks > 1
        prev:SetShown(many)
        nextButton:SetShown(many)
        partLabel:SetText(many and string.format(L.EXPORT_PART, part, #chunks) or "")
        local hiding = settings.exportHideNames ~= false
        namesButton:SetIcon(TEXR .. (hiding and "ex_names_hidden" or "ex_names_shown"))
        namesButton:SetText(hiding and L.EXPORT_NAMES_HIDDEN or L.EXPORT_NAMES_SHOWN)
        hint:SetText(format == "reader" and L.EXPORT_HINT_READER or L.EXPORT_HINT)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", 20, isReader and -208 or -170)
        box:SetPoint("BOTTOMRIGHT", -20, 62)
        card:SetShown(isReader)
        if isReader then
            local pages = #SelectEntries(scope)
            card:SetText(#chunks == 1 and string.format(L.EXPORT_READER_CARD1, pages) or string.format(L.EXPORT_READER_CARD, pages, #chunks))
        end
        pasteIcon:SetShown(isReader)
        readyIcon:SetShown(isReader and #chunks > 0)
        hint:ClearAllPoints()
        hint:SetPoint("BOTTOMLEFT", isReader and 56 or 22, 16)
        hint:SetWidth(isReader and 444 or 516)
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
        cb:SetPoint("TOPLEFT", ((i - 1) % 2) * 171, -78 - math.floor((i - 1) / 2) * 26)
        boxes[#boxes + 1] = cb
    end

    PageRule(panel, 0, -190)
    SectionLabel(panel, L.OPT_TIER, 0, -210)
    local questSeals = SealRow(-236, function(tier) Settings().minTier = tier end)
    local hint = NoteText(panel, 0, -278)

    PageRule(panel, 0, -318)
    SectionLabel(panel, L.OPT_LOOT, 0, -338)
    local lootSeals = SealRow(-364, function(tier) Settings().lootTier = tier end)
    local lootHint = NoteText(panel, 0, -406)

    -- Right page: how the diary behaves, then its data.
    PageHeading(panel, L.OPT_PAGE, K.RIGHT_X)
    SectionLabel(panel, L.OPT_DAYMODE, K.RIGHT_X, -52)
    local modeButtons = {}
    for i = 0, 1 do
        local b = MakeFlatButton(panel, 171, 26, L.DAYMODE_NAMES[i + 1])
        b:SetPoint("TOPLEFT", K.RIGHT_X + i * 171, -78)
        b:SetScript("OnClick", function() Settings().dayMode = i; Redraw() end)
        modeButtons[i] = b
    end

    local switches = {
        MakeWaxCheck(panel, L.OPT_CLOSING,
            function() return Settings().closing ~= false end,
            function(on) Settings().closing = on and true or false end),
        MakeWaxCheck(panel, L.OPT_LOOTGEAR,
            function() return Settings().lootGear ~= false end,
            function(on) Settings().lootGear = on and true or false end),
        MakeWaxCheck(panel, L.OPT_COMPANIONS,
            function() return Settings().companions ~= false end,
            function(on) Settings().companions = on and true or false end),
        MakeWaxCheck(panel, L.OPT_MEMORIES,
            function() return Settings().memories ~= false end,
            function(on) Settings().memories = on and true or false end),
        MakeWaxCheck(panel, L.OPT_MINIMAP,
            function() return not (Settings().minimap and Settings().minimap.hide) end,
            function(on) SetMinimapButtonShown(on) end),
    }
    PageRule(panel, K.RIGHT_X, -116)
    for i, cb in ipairs(switches) do cb:SetPoint("TOPLEFT", K.RIGHT_X, -138 - (i - 1) * 26) end

    -- The data: diaries set aside when another character took this name, the export, the erase.
    PageRule(panel, K.RIGHT_X, -278)
    SectionLabel(panel, L.OPT_ARCHIVE, K.RIGHT_X, -298)
    local info = NoteText(panel, K.RIGHT_X, -320)
    local restore = MakeFlatButton(panel, 166, 26, L.BTN_RESTORE)
    restore:SetPoint("TOPLEFT", K.RIGHT_X, -362)
    restore:SetScript("OnClick", function()
        if RestoreLatestArchive() then
            Say(L.ARCHIVE_RESTORED)
            if window then window:Refresh() end
        end
    end)
    local discard = MakeFlatButton(panel, 166, 26, L.BTN_DISCARD)
    discard:SetPoint("TOPLEFT", K.RIGHT_X + 176, -362)
    discard:SetScript("OnClick", function() StaticPopup_Show("SKALD_DISCARD") end)
    local exportButton = MakeFlatButton(panel, 166, 28, L.EXPORT_BTN, "gold")
    exportButton:SetPoint("TOPLEFT", K.RIGHT_X, -402)
    exportButton:SetScript("OnClick", function() ShowExport() end)
    local erase = MakeFlatButton(panel, 166, 28, L.BTN_ERASE, "burn")
    erase:SetPoint("TOPLEFT", K.RIGHT_X + 176, -402)
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
        for _, cb in ipairs(switches) do cb.Sync() end
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

local function BuildStyle(panel)
    local refresh
    local function Redraw()
        refresh()
        if window then window:Refresh() end
    end

    -- Left page: the narrator's voice, with an example, and how the text looks.
    PageHeading(panel, L.TAB_STYLE, 0)
    SectionLabel(panel, L.OPT_TONE, 0, -52)
    PlateGroup(panel, 0, -78, 342, 26)
    local toneButtons = {}
    for i, key in ipairs({ "epic", "humble", "humor" }) do
        local b = MakeFlatButton(panel, 114, 26, L.TONE_NAMES[key])
        b:SetPoint("TOPLEFT", (i - 1) * 114, -78)
        b:SetScript("OnClick", function() Settings().tone = key; Redraw() end)
        toneButtons[key] = b
    end
    local toneHint = NoteText(panel, 0, -112)
    SectionLabel(panel, L.TONE_SAMPLE_LABEL, 0, -146)
    local sample = panel:CreateFontString(nil, "OVERLAY", "SkaldNote")
    sample:SetPoint("TOPLEFT", 0, -170)
    sample:SetWidth(K.CW)
    sample:SetJustifyH("LEFT")
    sample:SetJustifyV("TOP")
    sample:SetWordWrap(true)
    sample:SetTextColor(K.C_NOTE[1], K.C_NOTE[2], K.C_NOTE[3])

    PageRule(panel, 0, -246)
    SectionLabel(panel, L.OPT_SIZE, 0, -266)
    PlateGroup(panel, 0, -292, 342, 26)
    local textSizeButtons = {}
    for i = 0, 2 do
        local b = MakeFlatButton(panel, 114, 26, L.SIZE_NAMES[i + 1])
        b:SetPoint("TOPLEFT", i * 114, -292)
        b:SetScript("OnClick", function() Settings().textSize = i; ApplyFonts(); Redraw() end)
        textSizeButtons[i] = b
    end

    -- how full the pages of a day are left (the same as /skald density), in a row under the size of the letter
    PlateGroup(panel, 0, -324, 342, 26)
    local densityButtons = {}
    for i, key in ipairs({ "compact", "comfy", "airy" }) do
        local b = MakeFlatButton(panel, 114, 26, (L.DENSITY_NAMES[key]:gsub("^%l", string.upper)))
        b:SetPoint("TOPLEFT", (i - 1) * 114, -324)
        b:SetScript("OnClick", function() ns.SetDensity(key); Redraw() end)
        densityButtons[key] = b
    end
    ns.SyncDensity = function()   -- also when the command changes it with the tab open
        local now = Settings().density
        if not K.DENSITY[now] then now = "comfy" end
        for key, b in pairs(densityButtons) do b:SetActive(key == now) end
    end

    PageRule(panel, 0, -362)
    SectionLabel(panel, L.OPT_INK, 0, -380)
    local inkBoxes = {}
    for i = 0, 2 do
        local c = K.INKS[i + 1]
        local cb = MakeWaxCheck(panel, L.INK_NAMES[i + 1],
            function() return (Settings().ink or 0) == i end,
            function() Settings().ink = i; Redraw() end, nil, c, 114)
        cb:SetPoint("TOPLEFT", i * 114, -406)
        inkBoxes[#inkBoxes + 1] = cb
    end

    -- Right page: the cover, and the size of the book.
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

    PageRule(panel, K.RIGHT_X, -134)
    SectionLabel(panel, L.OPT_COVERTITLE, K.RIGHT_X, -146)
    local edit = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    edit:SetSize(K.CW, 28)
    edit:SetPoint("TOPLEFT", K.RIGHT_X, -168)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(28)
    edit:SetFontObject("SkaldBody")
    edit:SetTextColor(K.C_BODY[1], K.C_BODY[2], K.C_BODY[3])
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    edit:SetBackdropColor(0.62, 0.48, 0.28, 0.32)   -- a darker scrap of parchment
    edit:SetBackdropBorderColor(0.45, 0.30, 0.14, 1)
    local function SaveTitle()
        local text = (edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        Settings().coverTitle = (text ~= "") and text or nil
        if window then window:Refresh() end
    end
    edit:SetScript("OnEnterPressed", function(self) SaveTitle(); self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:SetText(Settings().coverTitle or ""); self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", SaveTitle)
    NoteText(panel, K.RIGHT_X, -200):SetText(L.COVERTITLE_HINT)

    -- The size of the book (never more than the screen holds).
        PageRule(panel, K.RIGHT_X, -234)
    SectionLabel(panel, L.OPT_BOOKSIZE, K.RIGHT_X, -246)
    PlateGroup(panel, K.RIGHT_X, -268, 336, 26)
    local sizeButtons = {}
    for i, size in ipairs(K.BOOK_SIZES) do
        local b = MakeFlatButton(panel, 64, 26, size == "auto" and L.SIZE_AUTO or string.format("%d%%", size * 100))
        b:SetPoint("TOPLEFT", K.RIGHT_X + (i - 1) * 68, -268)
        b:SetScript("OnClick", function()
            Settings().bookScale = (size ~= "auto") and size or nil
            if window then window:FitScale() end
            for j, other in ipairs(sizeButtons) do other:SetActive(j == i) end
        end)
        sizeButtons[i] = b
    end

    -- The wax seal that closes the book.
    PageRule(panel, K.RIGHT_X, -304)
    SectionLabel(panel, L.OPT_SEAL, K.RIGHT_X, -316)
    PlateGroup(panel, K.RIGHT_X, -338, 336, 26)
    local sealButtons = {}
    for i, key in ipairs({ "auto", "horde", "alliance", "neutral" }) do
        local b = MakeFlatButton(panel, 82, 26, L.SEAL_NAMES[key])
        b:SetPoint("TOPLEFT", K.RIGHT_X + (i - 1) * 85, -338)
        b:SetScript("OnClick", function()
            Settings().sealStyle = (key ~= "auto") and key or nil
            if window then window:ApplySeal() end
            refresh()
        end)
        sealButtons[key] = b
    end

    -- The look of the tabs: a step back, the name (a click goes on), a step forward.
    PageRule(panel, K.RIGHT_X, -374)
    SectionLabel(panel, L.OPT_TABLOOK, K.RIGHT_X, -386)
    PlateGroup(panel, K.RIGHT_X, -408, 336, 26)
    local function StepLook(delta)
        local order, now = K.TAB_STYLE_ORDER, 1
        for i, key in ipairs(order) do if key == (Settings().tabStyle or "leather") then now = i end end
        Settings().tabStyle = order[(now - 1 + delta) % #order + 1]
        if window then window:ApplyTabStyle() end
        refresh()
    end
    local lookBack = MakeFlatButton(panel, 44, 26, "<")
    lookBack:SetPoint("TOPLEFT", K.RIGHT_X, -408)
    lookBack:SetScript("OnClick", function() StepLook(-1) end)
    local lookName = MakeFlatButton(panel, 244, 26, "")
    lookName:SetPoint("TOPLEFT", K.RIGHT_X + 46, -408)
    lookName:SetScript("OnClick", function() StepLook(1) end)
    local lookNext = MakeFlatButton(panel, 44, 26, ">")
    lookNext:SetPoint("TOPLEFT", K.RIGHT_X + 292, -408)
    lookNext:SetScript("OnClick", function() StepLook(1) end)
    panel.lookName, panel.lookBack, panel.lookNext = lookName, lookBack, lookNext   -- for the tests

    refresh = function()
        local s = Settings()
        for i, key in ipairs(K.TAB_STYLE_ORDER) do
            if key == (s.tabStyle or "leather") then lookName.text:SetText(L.TAB_LOOKS[i]) end
        end
        local tone = s.tone or "epic"
        for key, b in pairs(sealButtons) do b:SetActive(key == (s.sealStyle or "auto")) end
        for key, b in pairs(toneButtons) do b:SetActive(key == tone) end
        toneHint:SetText(L.TONE_HINT[tone] or "")
        sample:SetText(L.TONE_SAMPLE[tone] or "")
        local ink = K.INKS[(s.ink or 0) + 1] or K.INKS[1]   -- the example is written in the ink chosen below
        sample:SetTextColor(ink[1], ink[2], ink[3])
        for _, cb in ipairs(colorBoxes) do cb.Sync() end
        for _, cb in ipairs(inkBoxes) do cb.Sync() end
        for i, b in pairs(textSizeButtons) do b:SetActive(i == (s.textSize or 1)) end
        ns.SyncDensity()
        for i, b in ipairs(sizeButtons) do
            local size = K.BOOK_SIZES[i]
            b:SetActive((size == "auto" and not s.bookScale) or size == s.bookScale)
        end
        if not edit:HasFocus() then edit:SetText(s.coverTitle or "") end
    end
    return refresh
end

local function BuildNotices(panel)
    local refresh

    -- Left page: which notices are shown, and the sound.
    PageHeading(panel, L.TAB_NOTICES, 0)
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
        MakeWaxCheck(panel, L.OPT_SOUND,
            function() return Settings().sound ~= false end,
            function(on) Settings().sound = on and true or false end),
        MakeWaxCheck(panel, L.OPT_QUIET,
            function() return not Settings().quiet end,
            function(on) Settings().quiet = not on end),
    }
    for i, cb in ipairs(switches) do cb:SetPoint("TOPLEFT", 0, -70 - (i - 1) * 54) end

    -- Right page: where they appear.
    PageHeading(panel, L.TOAST_PLACE_HEAD, K.RIGHT_X)
    SectionLabel(panel, L.TOAST_WHERE, K.RIGHT_X, -52)
    PlateGroup(panel, K.RIGHT_X, -80, K.CW, 26)
    local placeButtons = {}
    for i, key in ipairs({ "top", "left", "bottom" }) do
        local pw = math.floor((K.CW - 8) / 3)
        local pb = MakeFlatButton(panel, pw, 26, L["TOAST_" .. key:upper()])
        pb:SetPoint("TOPLEFT", K.RIGHT_X + (i - 1) * (pw + 4), -80)
        pb:SetScript("OnClick", function()
            Settings().toastAnchor = key
            Settings().toastPos = nil
            for k, other in pairs(placeButtons) do other:SetActive(k == key) end
            if ns.PreviewNotice then ns.PreviewNotice() end
        end)
        placeButtons[key] = pb
    end
    PageRule(panel, K.RIGHT_X, -150)
    local moveButton = MakeFlatButton(panel, K.CW, 30, L.TOAST_MOVE, "strap")
    moveButton:SetPoint("TOPLEFT", K.RIGHT_X, -184)
    moveButton:SetScript("OnClick", function() if ns.PreviewNotice then ns.PreviewNotice() end end)
    NoteText(panel, K.RIGHT_X, -228):SetText(L.TOAST_MOVE_HINT)

    -- How long a notice stays.
    PageRule(panel, K.RIGHT_X, -300)
    SectionLabel(panel, L.TOAST_TIME, K.RIGHT_X, -312)
    PlateGroup(panel, K.RIGHT_X, -340, K.CW, 26)
    local timeButtons = {}
    local TIMES = { { 4, "4 s", 50 }, { 6.5, "6 s", 50 }, { 10, "10 s", 50 }, { 15, "15 s", 50 }, { 0, L.TOAST_PINNED, K.CW - 4 * 54 } }
    local tx = 0
    for _, choice in ipairs(TIMES) do
        local tb = MakeFlatButton(panel, choice[3], 26, choice[2])
        tb:SetPoint("TOPLEFT", K.RIGHT_X + tx, -340)
        tx = tx + choice[3] + 4
        tb:SetScript("OnClick", function()
            Settings().noticeSecs = choice[1]
            for value, other in pairs(timeButtons) do other:SetActive(value == choice[1]) end
            if ns.PreviewNotice then ns.PreviewNotice(choice[1] == 0 and 12 or choice[1]) end
        end)
        timeButtons[choice[1]] = tb
    end

    -- The paper of the pages.
    SectionLabel(panel, L.OPT_PAPER, K.RIGHT_X, -384)
    PlateGroup(panel, K.RIGHT_X, -404, 336, 26)
    local paperButtons = {}
    for i, key in ipairs(K.PAPER_STYLE_ORDER) do
        local b = MakeFlatButton(panel, 84, 26, L.PAPER_NAMES[key])
        b:SetPoint("TOPLEFT", K.RIGHT_X + (i - 1) * 84, -404)
        b:SetScript("OnClick", function()
            Settings().paperStyle = (key ~= "clean") and key or nil
            if window then window:ApplyPaper() end
            refresh()
        end)
        paperButtons[key] = b
    end
    panel.paperButtons = paperButtons   -- for the tests

    refresh = function()
        local s = Settings()
        for _, cb in ipairs(switches) do cb.Sync() end
        for key, pb in pairs(placeButtons) do pb:SetActive(not s.toastPos and (s.toastAnchor or "top") == key) end
        for value, tb in pairs(timeButtons) do tb:SetActive(value == (tonumber(s.noticeSecs) or 6.5)) end
        local paperStyle = s.paperStyle or "clean"
        if not K.PAPER_TEXTURES[paperStyle] then paperStyle = "clean" end
        for key, b in pairs(paperButtons) do b:SetActive(key == paperStyle) end
    end
    return refresh
end

-- The settings are one tab, "Settings", with three spreads (Style, Notices, Options) that the corners of the book turn, as in
-- any tab with pages of its own; the folio numerals at the foot go on (vii, ix, xi).
K.SETTINGS_PAGES = { { id = "style", build = BuildStyle }, { id = "notices", build = BuildNotices }, { id = "options", build = BuildOptions } }
K.SETTINGS_FOLIO = 7
local function BuildSettings(panel)
    local subs, refreshes = {}, {}
    local current = 1
    for i, page in ipairs(K.SETTINGS_PAGES) do
        local sub = CreateFrame("Frame", nil, panel)
        sub:SetAllPoints(panel)
        sub:Hide()
        local ok, refresh = pcall(page.build, sub)
        if ok and type(refresh) == "function" then refreshes[i] = refresh end
        subs[i] = sub
    end
    local function ShowPage()
        for i, sub in ipairs(subs) do
            if i == current then sub:Show() else sub:Hide() end
        end
        if refreshes[current] then pcall(refreshes[current]) end
    end
    panel.subs = subs   -- for the tests
    function panel.GoTo(id)
        for i, page in ipairs(K.SETTINGS_PAGES) do if page.id == id then current = i end end
        ShowPage()
    end
    local pager = {
        Turn = function(delta) current = math.max(1, math.min(#subs, current + delta)); ShowPage() end,
        CanPrev = function() return current > 1 end,
        CanNext = function() return current < #subs end,
        Folio = function() return K.SETTINGS_FOLIO + (current - 1) * 2 end,
        Current = function() return current end,
    }
    panel.pager = pager
    return ShowPage, pager
end
SkaldAPI.AddTab("settings", L.TAB_SETTINGS, BuildSettings)

local spokenHook = CreateFrame("Frame")
spokenHook:RegisterEvent("PLAYER_LOGIN")
spokenHook:SetScript("OnEvent", function()
    RegisterWithSpoken()
    RegisterMinimapButton()
    -- The button must be on the minimap once the addon is installed: if the library did not draw it, or the
    -- player never chose to hide it, the addon's own button takes its place a moment after the login.
    if C_Timer and C_Timer.After then
        C_Timer.After(3, function()
            local hidden = Settings().minimap and Settings().minimap.hide
            if hidden then return end
            local stub = _G.LibStub
            local dbIcon = stub and stub("LibDBIcon-1.0", true)
            local drawn = dbIcon and dbIcon:IsRegistered(K.MINIMAP_NAME) and dbIcon:GetMinimapButton(K.MINIMAP_NAME)
            if drawn and drawn:IsShown() then return end
            pcall(ns.CreateOwnMinimapButton)
            if ns.minimapButton then ns.minimapButton:Show() end
        end)
    end
end)

-- /skald report: what a bug report needs, in one block of text to copy. No character name, no page text. ----

ns.BuildReport = function()
    local out = {}
    local function Add(...) out[#out + 1] = string.format(...) end
    local db, set = Journal() or {}, Settings() or {}
    local function Meta(field)
        local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ok, v = pcall(fn or function() end, ADDON_NAME, field)
        return ok and v or "?"
    end
    local build, _, _, toc = "?", nil, nil, "?"
    if GetBuildInfo then pcall(function() local v, b, _, t = GetBuildInfo(); build, toc = tostring(v) .. "." .. tostring(b), tostring(t) end) end
    Add("Skald %s | locale %s | client %s (interface %s)", tostring(Meta("Version")), tostring(GetLocale and GetLocale() or "?"), build, toc)
    local class, race
    if UnitClass then class = select(2, UnitClass("player")) end
    if UnitRace then race = select(2, UnitRace("player")) end
    Add("level %s %s %s | voice %s | detail %s", tostring(UnitLevel and UnitLevel("player")), tostring(race), tostring(class),
        tostring(set.voice or "default"), tostring(set.detail or "normal"))
    local kinds, total = {}, 0
    for _, e in ipairs(db.entries or {}) do kinds[e.kind or "?"] = (kinds[e.kind or "?"] or 0) + 1; total = total + 1 end
    local list = {}
    for k, n in pairs(kinds) do list[#list + 1] = k .. "=" .. n end
    table.sort(list)
    Add("pages %d: %s", total, table.concat(list, " "))
    local seen, never = {}, {}
    local counts = set.seenEvents or {}
    local watch = { "PLAYER_LOGIN", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "ZONE_CHANGED_NEW_AREA" }
    for _, ev in ipairs(K.OPTIONAL_EVENTS) do watch[#watch + 1] = ev end
    for _, ev in ipairs(watch) do
        if counts[ev] then seen[#seen + 1] = ev .. "=" .. counts[ev] else never[#never + 1] = ev end
    end
    Add("events seen: %s", #seen > 0 and table.concat(seen, " ") or "none")
    Add("events never seen: %s", #never > 0 and table.concat(never, " ") or "none")
    -- how the client hands out names (a name may have two words in this client): only the shape is shown, the
    -- letters are masked, so the report still carries no real name
    local function Shape(v)
        if v == nil then return "nil" end
        return (tostring(Safe(v) or "?"):gsub("%u", "A"):gsub("%l", "a"))
    end
    local shapes = {}
    for _, unit in ipairs({ "player", "target", "party1" }) do
        if unit == "player" or not UnitExists or UnitExists(unit) then
            local un, ur = nil, nil
            if UnitName then un, ur = UnitName(unit) end
            local fn, fr
            if UnitFullName then fn, fr = UnitFullName(unit) end
            local gn = GetUnitName and GetUnitName(unit, true) or nil
            shapes[#shapes + 1] = string.format("%s: UnitName=%s realm=%s | UnitFullName=%s realm=%s | GetUnitName=%s", unit,
                Shape(un), Shape(ur), Shape(fn), Shape(fr), Shape(gn))
        end
    end
    for _, line in ipairs(shapes) do Add("names %s", line) end
    -- collections: which of the systems the new client may bring are there (mounts, pets, transmog, toys) and a
    -- count where one is cheap to ask; only the presence and the numbers, nothing is written
    local have = {}
    for _, name in ipairs({ "C_MountJournal", "C_PetJournal", "C_PetBattles", "C_TransmogCollection", "C_Transmog",
        "C_ToyBox", "C_CollectionsJournal", "C_Item", "C_AddOns", "C_TTSSettings", "C_VoiceChat" }) do
        have[#have + 1] = name .. "=" .. (type(_G[name]) == "table" and "yes" or "no")
    end
    Add("apis: %s", table.concat(have, " "))
    local counts = {}
    local function Count(label, fn) local ok, v = pcall(fn); counts[#counts + 1] = label .. "=" .. (ok and tostring(v) or "?") end
    if C_MountJournal and C_MountJournal.GetNumMounts then Count("mounts", C_MountJournal.GetNumMounts) end
    if C_MountJournal and C_MountJournal.GetNumDisplayedMounts then Count("mountsShown", C_MountJournal.GetNumDisplayedMounts) end
    if C_PetJournal and C_PetJournal.GetNumPets then Count("petsOwned", function() local _, owned = C_PetJournal.GetNumPets(); return owned end) end
    if GetNumCompanions then
        Count("companionMounts", function() return GetNumCompanions("MOUNT") end)
        Count("companionCritters", function() return GetNumCompanions("CRITTER") end)
    end
    do
        local coll = K.Collections()
        counts[#counts + 1] = "mountsCollected=" .. tostring(coll.mounts) .. " petsCollected=" .. tostring(coll.critters) .. " ready=" .. tostring(coll.ready)
    end
    if #counts > 0 then Add("collections: %s", table.concat(counts, " ")) end
    -- where a race begins (the area names the game gives for the starting places we expect) and the oldest
    -- achievement of this character: what a prologue could be told from, if the client answers
    do
        local okR, _, raceFile = pcall(UnitRace, "player")
        Add("birth: race %s", okR and tostring(raceFile) or "?")
        local areas = {}
        for _, id in ipairs({ 9, 12, 132, 1, 188, 141, 363, 14, 154, 85, 220, 215, 3430, 3524, 3433, 3525 }) do
            local ok, name = pcall(function() return C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id) end)
            areas[#areas + 1] = id .. "=" .. ((ok and name) and tostring(name) or "-")
        end
        Add("birth areas: %s", table.concat(areas, " "))
        local oldest, done
        pcall(function()
            if not (GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo) then return end
            done = 0
            for _, cat in ipairs(GetCategoryList() or {}) do
                for i = 1, GetCategoryNumAchievements(cat) or 0 do
                    local id, _, _, completed, month, day, year = GetAchievementInfo(cat, i)
                    if id and completed and type(year) == "number" and type(month) == "number" and type(day) == "number" then
                        done = done + 1
                        local key = year * 10000 + month * 100 + day
                        if not oldest or key < oldest then oldest = key end
                    end
                end
            end
        end)
        Add("oldest achievement: %s (done %s)", oldest and tostring(oldest) or "none", tostring(done))
    end
    -- the zone card of the Index: what the client can tell about the zone you stand in (map art, explored tiles,
    -- the quests QuestDB places there, the combat log); only presence and numbers, nothing is written
    do
        local function Has(tbl, name) return type(tbl) == "table" and type(tbl[name]) == "function" and "yes" or "no" end
        Add("zone card apis: C_Map.GetMapArtLayers=%s GetMapArtLayerTextures=%s GetMapArtID=%s C_MapExplorationInfo.GetExploredMapTextures=%s C_QuestLog.IsQuestFlaggedCompleted=%s GetQuestsCompleted=%s CombatLogGetCurrentEventInfo=%s",
            Has(C_Map, "GetMapArtLayers"), Has(C_Map, "GetMapArtLayerTextures"), Has(C_Map, "GetMapArtID"),
            Has(C_MapExplorationInfo, "GetExploredMapTextures"), Has(C_QuestLog, "IsQuestFlaggedCompleted"),
            type(GetQuestsCompleted) == "function" and "yes" or Has(C_QuestLog, "GetQuestsCompleted"),
            type(CombatLogGetCurrentEventInfo) == "function" and "yes" or "no")
        local okM, mapID = pcall(function() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end)
        if okM and mapID then
            local okI, info = pcall(function() return C_Map.GetMapInfo(mapID) end)
            Add("zone card map: id=%s type=%s parent=%s", tostring(mapID), tostring(okI and info and info.mapType), tostring(okI and info and info.parentMapID))
            local okL, layers = pcall(function() return C_Map.GetMapArtLayers(mapID) end)
            local layer = okL and type(layers) == "table" and layers[1]
            Add("zone card art: layers=%s size=%sx%s tile=%sx%s", tostring(okL and type(layers) == "table" and #layers or "?"),
                tostring(layer and layer.layerWidth), tostring(layer and layer.layerHeight), tostring(layer and layer.tileWidth), tostring(layer and layer.tileHeight))
            local okT, tiles = pcall(function() return C_Map.GetMapArtLayerTextures(mapID, 1) end)
            Add("zone card tiles: %s first=%s", tostring(okT and type(tiles) == "table" and #tiles or "?"), tostring(okT and type(tiles) == "table" and tiles[1] or "-"))
            local okE, explored = pcall(function() return C_MapExplorationInfo.GetExploredMapTextures(mapID) end)
            Add("zone card explored: %s", tostring(okE and type(explored) == "table" and #explored or (okE and tostring(explored)) or "?"))
            local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
            if qdb and qdb.GetQuestIds and qdb.GetQuest and qdb.GetUiMapId then
                local okQ, total, withZone, here = pcall(function()
                    local all, wz, h = 0, 0, 0
                    for _, id in ipairs(qdb:GetQuestIds() or {}) do
                        all = all + 1
                        local q = qdb:GetQuest(id)
                        local z = q and q.zoneOrSort
                        if type(z) == "number" and z > 0 then
                            wz = wz + 1
                            if qdb:GetUiMapId(z) == mapID then h = h + 1 end
                        end
                    end
                    return all, wz, h
                end)
                Add("zone card questdb: quests=%s withArea=%s hereByMap=%s", tostring(okQ and total or "?"), tostring(okQ and withZone or "?"), tostring(okQ and here or "?"))
            else
                Add("zone card questdb: not installed")
            end
        else
            Add("zone card map: none (stand in a zone and run again)")
        end
        -- the zones the client lists under each continent, with the ids the card would use
        pcall(function()
            local zones = {}
            local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
            for _, cont in ipairs({ 1414, 1415, 1945, 1946 }) do
                local info = C_Map.GetMapInfo(cont)
                local kids = info and C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(cont, zoneType, true)
                if type(kids) == "table" then
                    local names = {}
                    for _, k in ipairs(kids) do names[#names + 1] = k.mapID .. "=" .. tostring(k.name) end
                    zones[#zones + 1] = cont .. " " .. tostring(info.name) .. " (" .. #kids .. "): " .. table.concat(names, ", ")
                end
            end
            for _, line in ipairs(zones) do Add("zone list %s", line) end
            if #zones == 0 then Add("zone list: none") end
        end)
    end
    local cp = set.commsProbe
    if cp then
        Add("comms probe (run %s, %ds ago): register %s | api %s %s %s", date("%H:%M:%S", cp.when or 0), math.max(0, time() - (cp.when or 0)), tostring(cp.register), tostring(cp.api.RegisterAddonMessagePrefix),
            tostring(cp.api.SendAddonMessage), tostring(cp.api.IsAddonMessagePrefixRegistered))
        Add("  sent: %s", #cp.sent > 0 and table.concat(cp.sent, "; ") or "nothing")
        Add("  received: %s", #cp.received > 0 and table.concat(cp.received, "; ") or "nothing")
    end
    local errs = set.errors or {}
    Add("errors caught: %d", #errs)
    for _, e in ipairs(errs) do Add("  %s", e) end
    return table.concat(out, "\n")
end

ns.ShowReport = function()
    local f = ns.reportFrame
    if not f then
        f = CreateFrame("Frame", "SkaldReportFrame", UIParent, "BackdropTemplate")
        ns.reportFrame = f
        f:SetSize(560, 300)
        f:SetPoint("CENTER", 0, 20)
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropBorderColor(0.35, 0.22, 0.10, 1)
        local paper = f:CreateTexture(nil, "BACKGROUND")
        paper:SetPoint("TOPLEFT", 4, -4)
        paper:SetPoint("BOTTOMRIGHT", -4, 4)
        paper:SetColorTexture(0.86, 0.77, 0.58, 1)
        tinsert(UISpecialFrames, "SkaldReportFrame")
        local title = f:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
        title:SetPoint("TOP", 0, -14)
        title:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
        title:SetText(L.REPORT_TITLE)
        CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)
        local hint = f:CreateFontString(nil, "OVERLAY", "QuestFont")
        hint:SetPoint("TOPLEFT", 20, -44)
        hint:SetPoint("TOPRIGHT", -20, -44)
        hint:SetJustifyH("LEFT")
        hint:SetTextColor(K.HEAD_INK[1], K.HEAD_INK[2], K.HEAD_INK[3])
        hint:SetText(L.REPORT_HINT)
        local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
        box:SetPoint("TOPLEFT", 20, -86)
        box:SetPoint("BOTTOMRIGHT", -20, 20)
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
        edit:SetWidth(496)
        edit:SetTextInsets(2, 2, 2, 2)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit
    end
    f.edit:SetText(ns.BuildReport())
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

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
        Say(removed and string.format(L.CMD_PET_FORGOTTEN, removed) or L.CMD_PET_NONE)
    elseif msg == "forgetcompanions" then
        local db = Journal()
        if db then db.companions = nil end
        Mile.reunionTold = {}
        Say(L.CMD_COMPANIONS_FORGOTTEN)
    elseif msg == "density" or msg:match("^density%s") then
        ns.SetDensity(strtrim(msg:sub(8)))
        local now = Settings().density or "comfy"
        Say(string.format(L.CMD_DENSITY, L.DENSITY_NAMES[now] or now))
    elseif msg == "tidy" then
        pcall(Mile.Relocalize)
        Say(string.format(L.CMD_TIDY, Mile.Tidy()))
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
    elseif msg == "probe comms" or msg:match("^probe comms ") then
        ns.ProbeComms(strtrim(raw:sub(13)))
        Say(L.COMMS_SENT)
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
    elseif msg == "backup" then
        if ns.Backup then ns.Backup.ShowExport() end
    elseif msg == "restore" then
        if ns.Backup then ns.Backup.ShowRestore() end
    elseif msg == "restore undo" then
        if ns.Backup then ns.Backup.ConfirmUndo() end
    elseif msg:match("^size") then
        -- /skald size auto|80|100|125|150
        local arg = strtrim(raw:sub(5)):lower():gsub("%%", "")
        local value = tonumber(arg)
        if arg == "auto" then Settings().bookScale = nil
        elseif value and value >= 50 and value <= 200 then Settings().bookScale = value / 100
        else Say(L.CMD_SIZE_HINT); return end
        if window then window:FitScale() end
        Say(L.CMD_SIZE_DONE)
    elseif msg == "report" then
        ns.ShowReport()
    elseif ns.SpeechOn and (msg == "read" or msg == "read stop") then
        -- the newest page aloud (or stop)
        if msg == "read stop" then ns.StopSpeaking(); Say(L.READ_STOPPED); return end
        local entries = Journal() and Journal().entries or {}
        local last = entries[#entries]
        if not ns.SpeechAvailable() then Say(L.READ_NONE); return end
        if not last then Say(L.READ_EMPTY); return end
        if ns.SpeakTexts({ RenderEntry(last) }) then Say(L.READ_START) else Say(L.READ_EMPTY) end
    elseif ns.SpeechOn and msg == "read saga" then
        local chapters = ns.BuildSaga and ns.BuildSaga() or {}
        if not ns.SpeechAvailable() then Say(L.READ_NONE); return end
        local texts = {}
        for _, c in ipairs(chapters) do texts[#texts + 1] = tostring(c.title) .. ". " .. K.NL .. K.NL .. c.text end
        if ns.SpeakTexts(texts) then Say(L.READ_START) else Say(L.READ_EMPTY) end
    elseif msg == "reader" then
        -- the whole diary in the form the web Reader takes, ready to copy
        Settings().exportFormat, Settings().exportScope = "reader", "all"
        ShowExport()
    elseif msg == "help" or msg == "?" then
        Say(L.HELP)
    else
        ToggleWindow()
    end
end
