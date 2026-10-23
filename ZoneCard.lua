-- Skald: the zone card of the Index. When the contents end on the left page, the right page tells about the land
-- the diary last stood in: its map drawn from the game's own tiles in the colours of old parchment, the regions
-- found, the quests of the zone done out of those QuestDB places there, and the creatures slain there since the
-- diary began to count them.
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

-- The land to tell about: the last zone a page was written in, else the one underfoot.
function ZC.CurrentMap()
    local db = SkaldCharDB
    local entries = db and db.entries
    if entries then
        for i = #entries, 1, -1 do
            local e = entries[i]
            local id = e and ((type(e.m) == "number" and e.m) or e.zm)
            local zone = id and ZC.ZoneMap(id)
            if zone then return zone end
            if i < #entries - 400 then break end
        end
    end
    local ok, here = pcall(function() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end)
    return ok and here and ZC.ZoneMap(here) or nil
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
local function QuestIndex()
    local qdb = _G.LibStub and LibStub("LibQuestDB-1.0", true)
    if not (qdb and qdb.GetQuestIds and qdb.GetQuest and qdb.GetUiMapId) then return nil end
    local okR, _, _, raceID = pcall(UnitRace, "player")
    local okC, _, _, classID = pcall(UnitClass, "player")
    local key = tostring(okR and raceID) .. ":" .. tostring(okC and classID)
    if byMap and builtFor == key then return byMap end
    local index = {}
    local ok = pcall(function()
        for _, id in ipairs(qdb:GetQuestIds() or {}) do
            local q = qdb:GetQuest(id)
            local zone = q and q.zoneOrSort
            if type(zone) == "number" and zone > 0 and not q.hidden then
                local special = q.specialFlags or 0
                local repeatable = special % 2 == 1 or math.floor(special / 2) % 2 == 1
                local races, classes = q.requiredRaces or 0, q.requiredClasses or 0
                local raceOk = races == 0 or not okR or type(raceID) ~= "number" or HasBit(races, raceID)
                local classOk = classes == 0 or not okC or type(classID) ~= "number" or HasBit(classes, classID)
                if not repeatable and raceOk and classOk then
                    local map = qdb:GetUiMapId(zone)
                    if map then
                        index[map] = index[map] or {}
                        index[map][#index[map] + 1] = id
                    end
                end
            end
        end
    end)
    if not ok then return nil end
    byMap, builtFor = index, key
    return index
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
    local edge = {}
    for i = 1, 4 do
        edge[i] = card:CreateTexture(nil, "OVERLAY")
        edge[i]:SetColorTexture(0.24, 0.13, 0.07, 0.85)
    end
    card.edge = edge

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
        { key = "kills", icon = "ev_party" },
    }
    for i, spec in ipairs(ROWS) do
        local row = { key = spec.key }
        row.icon = card:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
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
            card.found[n] = tex
        end
        return tex
    end

    function card:Set(mapID)
        local t = T()
        local y = 0
        local drawn = 0
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
        for n = drawn + 1, #card.tiles do card.tiles[n]:Hide() end
        for _, e in ipairs(card.edge) do e:SetShown(mapBox:IsShown()) end
        if mapBox:IsShown() then
            local h = mapBox:GetHeight()
            card.edge[1]:ClearAllPoints(); card.edge[1]:SetPoint("TOPLEFT", mapBox, "TOPLEFT"); card.edge[1]:SetPoint("TOPRIGHT", mapBox, "TOPRIGHT"); card.edge[1]:SetHeight(2)
            card.edge[2]:ClearAllPoints(); card.edge[2]:SetPoint("BOTTOMLEFT", mapBox, "BOTTOMLEFT"); card.edge[2]:SetPoint("BOTTOMRIGHT", mapBox, "BOTTOMRIGHT"); card.edge[2]:SetHeight(2)
            card.edge[3]:ClearAllPoints(); card.edge[3]:SetPoint("TOPLEFT", mapBox, "TOPLEFT"); card.edge[3]:SetPoint("BOTTOMLEFT", mapBox, "BOTTOMLEFT"); card.edge[3]:SetWidth(2)
            card.edge[4]:ClearAllPoints(); card.edge[4]:SetPoint("TOPRIGHT", mapBox, "TOPRIGHT"); card.edge[4]:SetPoint("BOTTOMRIGHT", mapBox, "BOTTOMRIGHT"); card.edge[4]:SetWidth(2)
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
            row.label:SetPoint("TOPLEFT", card, "TOPLEFT", 30, -(y + 3))
            row.label:SetText(t[row.key:upper()])
            row.value:ClearAllPoints()
            row.value:SetPoint("TOPRIGHT", card, "TOPLEFT", width - 4, -(y + 3))
            row.value:SetText(values[row.key])
            row.leader:ClearAllPoints()
            row.leader:SetPoint("BOTTOMLEFT", row.label, "BOTTOMRIGHT", 6, 3)
            row.leader:SetPoint("BOTTOMRIGHT", row.value, "BOTTOMLEFT", -6, 3)
            y = y + 26
        end
    end
    card:Hide()
    return card
end
