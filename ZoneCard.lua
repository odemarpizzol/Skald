-- Skald: the zone card of the Index. When the contents end on the left page, the right page tells about the land
-- the diary last stood in: Skald's hand-drawn map for the starting zones, otherwise the game's tiles in old-paper
-- colours, along with regions found, local quests done and creatures slain there since the diary began to count them.
--
-- Loaded after Saga.lua: it uses the saved diary SkaldCharDB and, when it is installed, QuestDB (found through
-- LibStub at the moment of use, never at load).
local _, ns = ...

local TEXTS = {
    enUS = { TITLE = "%s in numbers", REGIONS = "Regions found", QUESTS = "Local quests", KILLS = "Creatures slain here", NONE = "No land yet." },
    ptBR = { TITLE = "%s em números", REGIONS = "Regiões descobertas", QUESTS = "Missões locais", KILLS = "Criaturas derrotadas aqui", NONE = "Nenhuma terra ainda." },
    frFR = { TITLE = "%s en chiffres", REGIONS = "Régions découvertes", QUESTS = "Quêtes locales", KILLS = "Créatures vaincues ici", NONE = "Aucune terre pour l'instant." },
}
local function T()
    local loc = GetLocale and GetLocale() or "enUS"
    return TEXTS[loc] or TEXTS.enUS
end

local ZC = {}
ns.ZoneCard = ZC

local TEX = "Interface\\AddOns\\Skald\\Textures\\"
local MAP_W = 342
-- Custom instance maps are catalogued by GetInstanceInfo's instance ID. The Index does not render them yet.
ZC.INSTANCE_ART = {
    [489] = "map_warsong",
    [529] = "map_arathibasin",
    [30] = "map_alterac_valley",
    [566] = "map_eyestorm",
    [389] = "map_ragefire",
    [36] = "map_deadmines",
    [43] = "map_wailingcaverns",
    [33] = "map_shadowfang",
    [48] = "map_blackfathom",
    [34] = "map_stockade",
    [90] = "map_gnomeregan",
    [47] = "map_razorfenkraul",
    [189] = "map_scarletmonastery",
    [129] = "map_razorfendowns",
    [70] = "map_uldaman",
    [209] = "map_zulfarrak",
    [349] = "map_maraudon",
    [109] = "map_sunkentemple",
    [230] = "map_blackrockdepths",
    [229] = "map_blackrockspire",
    [329] = "map_stratholme",
    [289] = "map_scholomance",
    [429] = "map_diremaul",
    [409] = "map_moltencore",
    [249] = "map_onyxia",
    [469] = "map_blackwinglair",
    [309] = "map_zulgurub",
    [509] = "map_ruinsahnqiraj",
    [531] = "map_templeahnqiraj",
    [533] = "map_naxxramas",
}
-- Hand-drawn map art for supported zones. Other zones keep the client's explored-map tiles.
ZC.ART = {
    [1429] = "map_elwynn",
    [1426] = "map_dunmorogh",
    [1438] = "map_teldrassil",
    [1411] = "map_durotar",
    [1412] = "map_mulgore",
    [1420] = "map_tirisfal",
    [1941] = "map_eversong",
    [1943] = "map_azuremyst",
    [1436] = "map_westfall",
    [1432] = "map_lochmodan",
    [1439] = "map_darkshore",
    [1421] = "map_silverpine",
    [1413] = "map_barrens",
    [1433] = "map_redridge",
    [1431] = "map_duskwood",
    [1437] = "map_wetlands",
    [1440] = "map_ashenvale",
    [1424] = "map_hillsbrad",
    [1442] = "map_stonetalon",
    [1441] = "map_thousandneedles",
    [1445] = "map_dustwallow",
    [1443] = "map_desolace",
    [1444] = "map_feralas",
    [1417] = "map_arathi",
    [1416] = "map_alterac",
    [1418] = "map_badlands",
    [1435] = "map_swampsorrows",
    [1425] = "map_hinterlands",
    [1434] = "map_stranglethorn",
    [1446] = "map_tanaris",
    [1449] = "map_ungoro",
    [1447] = "map_azshara",
    [1448] = "map_felwood",
    [1452] = "map_winterspring",
    [1451] = "map_silithus",
    [1450] = "map_moonglade",
    [1427] = "map_searinggorge",
    [1428] = "map_burningsteppes",
    [1419] = "map_blastedlands",
    [1430] = "map_deadwind",
    [1422] = "map_westernplague",
    [1423] = "map_easternplague",
    [1942] = "map_ghostlands",
    [1950] = "map_bloodmyst",
    [1957] = "map_quel_danas",
    [1944] = "map_hellfire",
    [1946] = "map_zangarmarsh",
    [1952] = "map_terokkar",
    [1951] = "map_nagrand",
    [1949] = "map_bladesedge",
    [1953] = "map_netherstorm",
    [1948] = "map_shadowmoon",
    [1453] = "map_stormwind",
    [1455] = "map_ironforge",
    [1457] = "map_darnassus",
    [1947] = "map_exodar",
    [1454] = "map_orgrimmar",
    [1456] = "map_thunderbluff",
    [1458] = "map_undercity",
    [1954] = "map_silvermoon",
    [1955] = "map_shattrath",
}
-- How the map of the zone sits on the page: it is a drawing of the old kind, not a window. The unfound part is faint (the
-- ink of the map, thin on the paper), the regions found are darker, and the borders fade into the paper in steps (no frame).
ZC.TILE_ALPHA, ZC.FOUND_ALPHA = 0.5, 0.92
ZC.PAPER = { 0.97, 0.89, 0.73 }   -- the colour of the page the map fades into
ZC.FADE, ZC.FADE_STEPS = 30, 15   -- how far (in pixels) the border fades, and in how many strips

-- The game reads a picture from the disk the first time it is drawn, and that is the small stop felt when the map is
-- opened for the first time. So the pictures are shown once, nearly clear and the size of a dot, a little after the
-- player arrives somewhere (the map of the place, the corners, the compass), one at a time, so the book finds them in memory.
function ZC.Preload()
    if ZC.preloading or not (CreateFrame and C_Timer and C_Timer.After and UIParent) then return end
    local names = { "skald2\\map_corner", "skald2\\map_compass", "skald2\\rule" }
    local ok, mapID = pcall(ZC.CurrentMap)
    local art = ok and mapID and ZC.ART[mapID]
    if art then table.insert(names, 1, "skald2\\" .. art) end
    local todo = {}
    ZC.warmed = ZC.warmed or {}
    for _, n in ipairs(names) do if not ZC.warmed[n] then todo[#todo + 1] = n end end
    if #todo == 0 then return end
    ZC.preloading = true
    local frame = ZC.warmFrame
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(8, 8)
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        frame:SetFrameStrata("BACKGROUND")
        frame.tex = frame:CreateTexture(nil, "BACKGROUND")
        frame.tex:SetAllPoints()
        frame.tex:SetAlpha(0.02)
        ZC.warmFrame = frame
    end
    local i = 0
    local function Step()
        i = i + 1
        local n = todo[i]
        if not n then
            frame:Hide()
            ZC.preloading = false
            return
        end
        ZC.warmed[n] = true
        pcall(frame.tex.SetTexture, frame.tex, TEX .. n)
        frame:Show()
        C_Timer.After(0.3, Step)
    end
    Step()
end

-- The map of the zone that holds a map (a city district, a cave) : climb until a zone (type 3) is reached.
function ZC.ZoneMap(mapID)
    if type(mapID) ~= "number" or not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, found = pcall(function()
        local id = mapID
        for _ = 1, 8 do
            local info = C_Map.GetMapInfo(id)
            if not info then return nil end
            if info.mapType == 3 then return id end
            if info.mapType == 4 or not info.parentMapID or info.parentMapID == 0 then return nil end
            id = info.parentMapID
        end
    end)
    return ok and found or nil
end

-- The land to tell about: the zone underfoot (cities and instances have none), else the last zone a page was written in.
function ZC.CurrentMap()
    local ok, here = pcall(function() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end)
    local zone = ok and here and ZC.ZoneMap(here)
    if zone then return zone end
    local db = SkaldCharDB
    local entries = db and db.entries
    if entries then
        for i = #entries, math.max(1, #entries - 400), -1 do
            local e = entries[i]
            local id = e and ((type(e.m) == "number" and e.m) or e.zm)
            zone = id and ZC.ZoneMap(id)
            if zone then return zone end
        end
    end
    return nil
end

function ZC.Name(mapID)
    local ok, info = pcall(function() return C_Map.GetMapInfo(mapID) end)
    return ok and info and info.name or nil
end

-- Regions of the zone the game says are found (it has no total to tell what is left).
function ZC.Regions(mapID)
    local ok, list = pcall(function() return C_MapExplorationInfo.GetExploredMapTextures(mapID) end)
    if ok and type(list) == "table" then return #list end
    return nil
end

-- Quests of the zone for this character: the ones QuestDB places there that the race and class may take, without
-- the hidden and the repeatable ones. Built once, when first asked, and kept.
local byMap, builtFor
local function HasBit(mask, n) return math.floor(mask / 2 ^ (n - 1)) % 2 == 1 end
-- The quest data knows the eight races of old. A newer race (Forever's Skyborne) has no bit in its masks, so a
-- quest is open to it when the mask holds every old race of its faction (a quest "for the Alliance" or "for the Horde").
local OLD_RACES = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true }
local FACTION_RACES = { Alliance = { 1, 3, 4, 7 }, Horde = { 2, 5, 6, 8 } }
local function RaceAllowed(mask, raceID)
    if HasBit(mask, raceID) then return true end
    if OLD_RACES[raceID] then return false end
    local okF, faction = pcall(UnitFactionGroup, "player")
    local own = okF and FACTION_RACES[faction]
    if not own then return true end
    for _, r in ipairs(own) do if not HasBit(mask, r) then return false end end
    return true
end
-- The index is built from every quest of QuestDB (thousands): that is the stop felt the first time the Index is opened.
-- So it is built in steps, a few at a time, about 5 ms per step, a little after login (ZC.WarmQuests); if the book is opened
-- before it ends, what is left is built then (QuestIndex), from where the steps stopped.
local build   -- { key, ids, pos, index, qdb, raceID, classID, okR, okC }
local function QuestStep(st, count)
    local qdb = st.qdb
    local last = math.min(#st.ids, st.pos + count - 1)
    for i = st.pos, last do
        local id = st.ids[i]
        local q = qdb:GetQuest(id)
        local zone = q and q.zoneOrSort
        if type(zone) == "number" and zone > 0 and not q.hidden then
            local special = q.specialFlags or 0
            local repeatable = special % 2 == 1 or math.floor(special / 2) % 2 == 1
            local races, classes = q.requiredRaces or 0, q.requiredClasses or 0
            local raceOk = races == 0 or not st.okR or type(st.raceID) ~= "number" or RaceAllowed(races, st.raceID)
            local classOk = classes == 0 or not st.okC or type(st.classID) ~= "number" or HasBit(classes, st.classID)
            if not repeatable and raceOk and classOk then
                local map = qdb:GetUiMapId(zone)
                if map then
                    st.index[map] = st.index[map] or {}
                    st.index[map][#st.index[map] + 1] = id
                end
            end
        end
    end
    st.pos = last + 1
    return st.pos > #st.ids
end
local function QuestKey()
    local okR, _, _, raceID = pcall(UnitRace, "player")
    local okC, _, _, classID = pcall(UnitClass, "player")
    return tostring(okR and raceID) .. ":" .. tostring(okC and classID), okR, raceID, okC, classID
end
-- count = how many quests to read now (nil = all that are left)
local function QuestAdvance(count)
    local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
    if not (qdb and qdb.GetQuestIds and qdb.GetQuest and qdb.GetUiMapId) then return nil end
    local key, okR, raceID, okC, classID = QuestKey()
    if byMap and builtFor == key then return byMap end
    if not build or build.key ~= key then
        local okI, ids = pcall(function() return qdb:GetQuestIds() or {} end)
        if not okI then return nil end
        build = { key = key, ids = ids, pos = 1, index = {}, qdb = qdb, raceID = raceID, classID = classID, okR = okR, okC = okC }
    end
    local ok, finished = pcall(QuestStep, build, count or #build.ids)
    if not ok then build = nil; return nil end
    if finished then
        byMap, builtFor, build = build.index, key, nil
        return byMap
    end
    return nil, true   -- not finished yet
end
local function QuestIndex()
    return (QuestAdvance(nil))
end

-- For /skald perf: how far the quest index is.
function ZC.QuestState()
    if byMap then return "ready" end
    if build then return build.pos .. " of " .. #build.ids end
    return "not started"
end

-- Reads the quests in the background, a step of about 5 ms every twentieth of a second.
function ZC.WarmQuests()
    if not (C_Timer and C_Timer.After) then return end
    -- each step is held to about 5 ms (a frame is 16), so the game never feels it
    local clock = debugprofilestop
    local function Step()
        local started = clock and clock()
        local more = true
        repeat
            local index, left = QuestAdvance(20)
            more = left
        until not more or not clock or clock() - started > 5
        if more then C_Timer.After(0.05, Step) end
    end
    pcall(Step)
end

-- Quests done in the zone, out of the total QuestDB knows (nil without QuestDB or without data for the zone).
function ZC.Quests(mapID)
    local index = QuestIndex()
    local list = index and index[mapID]
    if list and #list > 0 and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local done = 0
        for _, id in ipairs(list) do
            local ok, flagged = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
            if ok and flagged then done = done + 1 end
        end
        return done, #list
    end
    -- without the data: the quests the diary itself wrote in this zone
    local done, seen = 0, {}
    for _, e in ipairs((SkaldCharDB and SkaldCharDB.entries) or {}) do
        if e.kind == "quest" and e.q and not seen[e.q] then
            local id = (type(e.m) == "number" and e.m) or e.zm
            if id and ZC.ZoneMap(id) == mapID then seen[e.q] = true; done = done + 1 end
        end
    end
    return done, nil
end

function ZC.Kills(mapID)
    local kills = SkaldCharDB and SkaldCharDB.zoneKills
    return kills and kills[mapID] or 0
end

-- The card: one frame the book places on a page. card:Set(mapID) fills it.
function ZC.Build(parent, width)
    width = width or MAP_W
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, 440)
    card.tiles = {}
    card.found = {}
    local mapBox = CreateFrame("Frame", nil, card)
    mapBox:SetPoint("TOPLEFT", 0, 0)
    mapBox:SetClipsChildren(true)
    card.mapBox = mapBox
    -- four sets of strips of the colour of the paper, each fainter than the one outside it: the map melts into the page.
    -- They are on the map box itself (a frame's own textures lie under its children, not over them).
    local fade = {}
    for side = 1, 4 do
        fade[side] = {}
        for i = 1, ZC.FADE_STEPS do
            local strip = mapBox:CreateTexture(nil, "OVERLAY")
            local k = (i - 1) / ZC.FADE_STEPS                  -- 0 at the border, nearly 1 inside
            strip:SetColorTexture(ZC.PAPER[1], ZC.PAPER[2], ZC.PAPER[3], 0.96 * (1 - k) ^ 1.7)
            fade[side][i] = strip
        end
    end
    card.fade = fade

    -- These small ornaments frame both our own zone drawings and the game's faded map tiles.
    local corners = {
        { "TOPLEFT", 0 }, { "TOPRIGHT", math.pi / 2 },
        { "BOTTOMRIGHT", math.pi }, { "BOTTOMLEFT", math.pi * 1.5 },
    }
    card.mapCorners = {}
    for i, spec in ipairs(corners) do
        local corner = mapBox:CreateTexture(nil, "OVERLAY", nil, 3)
        corner:SetSize(32, 32)
        corner:SetPoint(spec[1], mapBox, spec[1], 0, 0)
        corner:SetTexture(TEX .. "skald2\\map_corner")
        corner:SetRotation(spec[2])
        card.mapCorners[i] = corner
    end
    local compass = mapBox:CreateTexture(nil, "OVERLAY", nil, 4)
    compass:SetSize(22, 22)
    compass:SetPoint("TOP", mapBox, "TOP", 0, -3)
    compass:SetTexture(TEX .. "skald2\\map_compass")
    card.compass = compass

    local title = card:CreateFontString(nil, "OVERLAY", "SkaldHead2")
    title:SetWidth(width)
    title:SetJustifyH("CENTER")
    title:SetTextColor(SkaldAPI.C_HEAD[1], SkaldAPI.C_HEAD[2], SkaldAPI.C_HEAD[3])
    card.title = title
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetSize(130, 11)
    rule:SetTexture("Interface\\AddOns\\Skald\\Textures\\skald2\\rule")
    rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    card.rule = rule

    card.rows = {}
    local ROWS = {
        { key = "regions", icon = "ev_zone" },
        { key = "quests", icon = "ev_quest" },
        { key = "kills", icon = "ev_claw" },
    }
    for i, spec in ipairs(ROWS) do
        local row = { key = spec.key }
        row.icon = card:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetTexture(TEX .. spec.icon)
        row.label = card:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.label:SetTextColor(SkaldAPI.C_BODY[1], SkaldAPI.C_BODY[2], SkaldAPI.C_BODY[3])
        row.value = card:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.value:SetJustifyH("RIGHT")
        row.value:SetTextColor(SkaldAPI.C_HEAD[1], SkaldAPI.C_HEAD[2], SkaldAPI.C_HEAD[3])
        row.leader = card:CreateTexture(nil, "ARTWORK")
        row.leader:SetColorTexture(SkaldAPI.C_MUTED[1], SkaldAPI.C_MUTED[2], SkaldAPI.C_MUTED[3], 0.22)
        row.leader:SetHeight(1)
        card.rows[i] = row
    end

    -- The tiles of the map: one texture each, made once and given a new picture when the zone changes.
    local function Tile(n)
        local tex = card.tiles[n]
        if not tex then
            tex = mapBox:CreateTexture(nil, "ARTWORK")
            tex:SetDesaturated(true)
            tex:SetVertexColor(0.93, 0.80, 0.60)
            tex:SetAlpha(ZC.TILE_ALPHA)
            card.tiles[n] = tex
        end
        return tex
    end

    -- The regions already found lie over the grey base in pieces of their own (the game cuts each one in tiles of 256).
    local function Found(n)
        local tex = card.found[n]
        if not tex then
            tex = mapBox:CreateTexture(nil, "ARTWORK", nil, 1)
            tex:SetDesaturated(true)
            tex:SetVertexColor(0.93, 0.80, 0.60)
            tex:SetAlpha(ZC.FOUND_ALPHA)
            card.found[n] = tex
        end
        return tex
    end

    function card:Set(mapID)
        local t = T()
        local y = 0
        local drawn = 0
        local artName = ZC.ART[mapID]
        if artName then
            local height = math.floor(width / 2 + 0.5)
            mapBox:SetSize(width, height)
            local tex = Tile(1)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", mapBox, "TOPLEFT", 0, 0)
            tex:SetSize(width, height)
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetTexture(TEX .. "skald2\\" .. artName)
            tex:SetDesaturated(false)
            tex:SetVertexColor(1, 1, 1)
            tex:SetAlpha(0.88)
            tex:Show()
            drawn = 1
            for _, tex in ipairs(card.found) do tex:Hide() end
            mapBox:Show()
            y = height + 22
        else
            local okL, layers = pcall(function() return C_Map.GetMapArtLayers(mapID) end)
            local layer = okL and type(layers) == "table" and layers[1]
            local okT, files = pcall(function() return C_Map.GetMapArtLayerTextures(mapID, 1) end)
            if layer and layer.layerWidth and layer.layerWidth > 0 and okT and type(files) == "table" and #files > 0 then
                local scale = width / layer.layerWidth
                local tw, th = layer.tileWidth or 256, layer.tileHeight or 256
                local cols = math.ceil(layer.layerWidth / tw)
                local height = math.floor(layer.layerHeight * scale + 0.5)
                mapBox:SetSize(width, height)
                for n, file in ipairs(files) do
                    local col, rowN = (n - 1) % cols, math.floor((n - 1) / cols)
                    local tex = Tile(n)
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", mapBox, "TOPLEFT", col * tw * scale, -(rowN * th * scale))
                    tex:SetSize(tw * scale + 0.5, th * scale + 0.5)
                    tex:SetTexture(file)
                    tex:SetDesaturated(true)
                    tex:SetVertexColor(0.93, 0.80, 0.60)
                    tex:SetAlpha(ZC.TILE_ALPHA)
                    tex:Show()
                    drawn = n
                end
                local used = 0
                local okE, regions = pcall(function() return C_MapExplorationInfo.GetExploredMapTextures(mapID) end)
                if okE and type(regions) == "table" then
                    for _, r in ipairs(regions) do
                        if type(r) == "table" and type(r.fileDataIDs) == "table" and not r.isShownByMouseOver
                            and r.textureWidth and r.textureHeight and r.textureWidth > 0 and r.textureHeight > 0 then
                            local cols = math.ceil(r.textureWidth / 256)
                            for i, file in ipairs(r.fileDataIDs) do
                                local col, rowN = (i - 1) % cols, math.floor((i - 1) / cols)
                                local w = math.min(256, r.textureWidth - col * 256)
                                local h = math.min(256, r.textureHeight - rowN * 256)
                                if w > 0 and h > 0 then
                                    used = used + 1
                                    local tex = Found(used)
                                    tex:ClearAllPoints()
                                    tex:SetPoint("TOPLEFT", mapBox, "TOPLEFT", ((r.offsetX or 0) + col * 256) * scale, -(((r.offsetY or 0) + rowN * 256) * scale))
                                    tex:SetSize(w * scale + 0.5, h * scale + 0.5)
                                    tex:SetTexCoord(0, w / 256, 0, h / 256)
                                    tex:SetTexture(file)
                                    tex:Show()
                                end
                            end
                        end
                    end
                end
                for n = used + 1, #card.found do card.found[n]:Hide() end
                mapBox:Show()
                y = height + 22
            else
                mapBox:Hide()
                for _, tex in ipairs(card.found) do tex:Hide() end
                y = 20
            end
        end
        for n = drawn + 1, #card.tiles do card.tiles[n]:Hide() end
        local shown = mapBox:IsShown()
        for side = 1, 4 do for _, strip in ipairs(card.fade[side]) do strip:SetShown(shown) end end
        if shown then
            local step = ZC.FADE / ZC.FADE_STEPS
            for i = 1, ZC.FADE_STEPS do
                local at = (i - 1) * step
                local top, bottom, left, right = card.fade[1][i], card.fade[2][i], card.fade[3][i], card.fade[4][i]
                top:ClearAllPoints(); top:SetPoint("TOPLEFT", mapBox, "TOPLEFT", 0, -at); top:SetPoint("TOPRIGHT", mapBox, "TOPRIGHT", 0, -at); top:SetHeight(step)
                bottom:ClearAllPoints(); bottom:SetPoint("BOTTOMLEFT", mapBox, "BOTTOMLEFT", 0, at); bottom:SetPoint("BOTTOMRIGHT", mapBox, "BOTTOMRIGHT", 0, at); bottom:SetHeight(step)
                left:ClearAllPoints(); left:SetPoint("TOPLEFT", mapBox, "TOPLEFT", at, 0); left:SetPoint("BOTTOMLEFT", mapBox, "BOTTOMLEFT", at, 0); left:SetWidth(step)
                right:ClearAllPoints(); right:SetPoint("TOPRIGHT", mapBox, "TOPRIGHT", -at, 0); right:SetPoint("BOTTOMRIGHT", mapBox, "BOTTOMRIGHT", -at, 0); right:SetWidth(step)
            end
        end

        local name = ZC.Name(mapID) or "?"
        card.title:ClearAllPoints()
        card.title:SetPoint("TOP", card, "TOPLEFT", width / 2, -y)
        card.title:SetText(string.format(t.TITLE, name))
        card.rule:ClearAllPoints()
        card.rule:SetPoint("TOP", card.title, "BOTTOM", 0, -6)
        y = y + 44

        local regions = ZC.Regions(mapID)
        local done, total = ZC.Quests(mapID)
        local values = {
            regions = regions and tostring(regions) or "-",
            quests = total and (done .. " / " .. total) or tostring(done),
            kills = tostring(ZC.Kills(mapID)),
        }
        for _, row in ipairs(card.rows) do
            row.icon:ClearAllPoints()
            row.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", card, "TOPLEFT", 40, -(y + 7))
            row.label:SetText(t[row.key:upper()])
            row.value:ClearAllPoints()
            row.value:SetPoint("TOPRIGHT", card, "TOPLEFT", width - 4, -(y + 7))
            row.value:SetText(values[row.key])
            row.leader:ClearAllPoints()
            row.leader:SetPoint("BOTTOMLEFT", row.label, "BOTTOMRIGHT", 6, 3)
            row.leader:SetPoint("BOTTOMRIGHT", row.value, "BOTTOMLEFT", -6, 3)
            y = y + 38
        end
    end
    card:Hide()
    return card
end

-- The summing up of a day, for the right page when the newest day ended on the left one.
local DC = {}
ns.DayCard = DC

local DAY_TEXTS = {
    enUS = { TITLE = "The day in numbers", LEVEL = "Level reached", QUESTS = "Quests done", ZONES = "Lands found", FALLS = "Falls", GOALS = "Goals reached", PAGES = "Pages written" },
    ptBR = { TITLE = "O dia em números", LEVEL = "Nível alcançado", QUESTS = "Missões cumpridas", ZONES = "Terras descobertas", FALLS = "Quedas", GOALS = "Metas cumpridas", PAGES = "Páginas escritas" },
    frFR = { TITLE = "Le jour en chiffres", LEVEL = "Niveau atteint", QUESTS = "Quêtes accomplies", ZONES = "Terres découvertes", FALLS = "Chutes", GOALS = "Objectifs atteints", PAGES = "Pages écrites" },
}

function DC.Count(day)
    local out = { level = day.level or 1, quests = 0, zones = 0, falls = 0, goals = 0, pages = 0 }
    for _, e in ipairs(day.entries or {}) do
        out.pages = out.pages + 1
        if e.kind == "quest" then out.quests = out.quests + 1
        elseif e.kind == "zone" then out.zones = out.zones + 1
        elseif e.kind == "death" then out.falls = out.falls + 1
        elseif e.kind == "goal" then out.goals = out.goals + 1 end
    end
    return out
end

function DC.Build(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, 440)
    local title = card:CreateFontString(nil, "OVERLAY", "SkaldHead2")
    title:SetWidth(width)
    title:SetJustifyH("CENTER")
    title:SetPoint("TOP", card, "TOP", 0, 0)
    title:SetTextColor(SkaldAPI.C_HEAD[1], SkaldAPI.C_HEAD[2], SkaldAPI.C_HEAD[3])
    card.title = title
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetSize(130, 11)
    rule:SetPoint("TOP", title, "BOTTOM", 0, -6)
    rule:SetTexture("Interface\\AddOns\\Skald\\Textures\\skald2\\rule")
    rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    -- which day the numbers are of, in the muted ink under the rule
    local sub = card:CreateFontString(nil, "OVERLAY", "SkaldBody")
    sub:SetWidth(width)
    sub:SetJustifyH("CENTER")
    sub:SetPoint("TOP", rule, "BOTTOM", 0, -8)
    sub:SetTextColor(SkaldAPI.C_MUTED[1], SkaldAPI.C_MUTED[2], SkaldAPI.C_MUTED[3])
    card.sub = sub
    card.rows = {}
    local ROWS = { { "level", "ev_level" }, { "quests", "ev_quest" }, { "zones", "ev_zone" }, { "falls", "ev_death" },
        { "goals", "ev_goal" }, { "pages", "ev_milestone" } }
    for i, spec in ipairs(ROWS) do
        local y = 76 + (i - 1) * 38
        local row = { key = spec[1] }
        row.icon = card:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
        row.icon:SetTexture(TEX .. spec[2])
        row.label = card:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.label:SetPoint("TOPLEFT", card, "TOPLEFT", 40, -(y + 7))
        row.label:SetTextColor(SkaldAPI.C_BODY[1], SkaldAPI.C_BODY[2], SkaldAPI.C_BODY[3])
        row.value = card:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.value:SetPoint("TOPRIGHT", card, "TOPLEFT", width - 4, -(y + 7))
        row.value:SetJustifyH("RIGHT")
        row.value:SetTextColor(SkaldAPI.C_HEAD[1], SkaldAPI.C_HEAD[2], SkaldAPI.C_HEAD[3])
        row.leader = card:CreateTexture(nil, "ARTWORK")
        row.leader:SetColorTexture(SkaldAPI.C_MUTED[1], SkaldAPI.C_MUTED[2], SkaldAPI.C_MUTED[3], 0.22)
        row.leader:SetHeight(1)
        row.leader:SetPoint("BOTTOMLEFT", row.label, "BOTTOMRIGHT", 6, 3)
        row.leader:SetPoint("BOTTOMRIGHT", row.value, "BOTTOMLEFT", -6, 3)
        card.rows[i] = row
    end
    function card:Set(day, reference)
        local loc = GetLocale and GetLocale() or "enUS"
        local t = DAY_TEXTS[loc] or DAY_TEXTS.enUS
        local n = DC.Count(day)
        card.title:SetText(t.TITLE)
        card.sub:SetText(reference or "")
        for _, row in ipairs(card.rows) do
            row.label:SetText(t[row.key:upper()])
            row.value:SetText(tostring(n[row.key]))
        end
    end
    card:Hide()
    return card
end
