-- Skald Atlas, now a part of Skald.
-- Pins the pages of the Skald journal on the world map. It stays dormant when the separate
-- Skald Atlas addon (an old install) is also running, so nothing is drawn twice.

local ADDON_NAME = ...

local L = ({
    enUS = {
        LOADED = "loaded. Pages appear on the world map. |cffffffff/skatlas|r toggles pins.",
        ON = "pins shown.",
        OFF = "pins hidden.",
        NEED = "Skald is required.",
        TIER_SET = "showing pages of rarity %d and above.",
        TIER_HELP = "use |cffffffff/skatlas tier 0-5|r (0 shows everything, 5 only legendary). Now: %d.",
    },
    ptBR = {
        LOADED = "carregado. As páginas aparecem no mapa-múndi. |cffffffff/skatlas|r alterna os marcadores.",
        ON = "marcadores visíveis.",
        OFF = "marcadores ocultos.",
        NEED = "O Skald é necessário.",
        TIER_SET = "mostrando páginas de raridade %d ou mais.",
        TIER_HELP = "use |cffffffff/skatlas tier 0-5|r (0 mostra tudo, 5 só lendárias). Agora: %d.",
    },
    frFR = {
        LOADED = "chargé. Les pages apparaissent sur la carte du monde. |cffffffff/skatlas|r affiche ou masque les marqueurs.",
        ON = "marqueurs affichés.",
        OFF = "marqueurs masqués.",
        NEED = "Skald est requis.",
        TIER_SET = "affichage des pages de rareté %d et plus.",
        TIER_HELP = "utilisez |cffffffff/skatlas tier 0-5|r (0 montre tout, 5 seulement les légendaires). Actuel\194\160: %d.",
    },
})[GetLocale()] or nil
if not L then
    L = {
        LOADED = "loaded. Pages appear on the world map. |cffffffff/skatlas|r toggles pins.",
        ON = "pins shown.", OFF = "pins hidden.", NEED = "Skald is required.",
        TIER_SET = "showing pages of rarity %d and above.",
        TIER_HELP = "use |cffffffff/skatlas tier 0-5|r. Now: %d.",
    }
end

local PIN_SIZE = 22
local GLYPH_SIZE = 16
local MAX_TIP = 6
local TEXTURES = "Interface\\AddOns\\Skald\\Textures\\"
local pins = {}
local activePins = 0

-- A page that is not a quest has a fixed rarity, so its medallion has a colour too.
local KIND_TIER = {
    zone = 1, level = 2, milestone = 4, death = 1, dungeon = 3, boss = 4,
    mount = 3, guild = 3, guildleave = 1, party = 2, reunion = 2, achievement = 5,
    skill = 2, profession = 2, quest = 1, tame = 2,
}

-- Which symbol sits inside the medallion.
local GLYPH = {
    quest = "quest", level = "level", milestone = "milestone", death = "death",
    boss = "boss", dungeon = "dungeon", zone = "zone", mount = "mount",
    guild = "guild", guildleave = "guild", party = "party", reunion = "party", tame = "pet",
    achievement = "achievement", skill = "profession", profession = "profession",
}

-- Strings and order for the Map tab (it lives inside the Skald window).
local UI_TEXT = {
    enUS = {
        TAB = "Map", SHOW = "Show pins on the world map", OPEN = "Open the world map",
        SUMMARY = "%s: %d %s, %d %s.", PAGE = "page", PAGES = "pages", PIN = "pin", PINS = "pins",
        HIDDEN = "%d hidden by the filters.", HIDDEN_ONE = "1 hidden by the filters.",
        NONE = "No pages recorded here yet.",
        WHEN = "When", RANGE_ALL = "All", RANGE_SESSION = "This session", RANGE_TODAY = "Today",
        FAVONLY = "Only favourite memories",
        REGION = "This region", FIRST_VISIT = "First visit: %s", R_LINE1 = "Quests: %d   Falls: %d   Foes: %d",
        R_LINE2 = "Levels: %d   Items: %d   Favourites: %d", CLICK_OPEN = "Click to open the page in the book",
        STATUS = "Showing %d of %d pages here.", STATUS_NONE = "No page here matches the filters.",
        OPACITY = "Marker opacity",
        OPACITY_HINT = "Fainter markers let the game's own quest markers show through.",
        RARITY = "Smallest rarity shown", KINDS = "Pages shown",
        KIND = {
            quest = "Quests", level = "Levels", milestone = "Milestones", death = "Deaths",
            boss = "Foes", dungeon = "Dungeons", zone = "Lands", mount = "Mounts",
            guild = "Guild", party = "Group", pet = "Pets", achievement = "Deeds", profession = "Crafts",
        },
    },
    ptBR = {
        TAB = "Mapa", SHOW = "Mostrar marcadores no mapa-múndi", OPEN = "Abrir o mapa-múndi",
        SUMMARY = "%s: %d %s, %d %s.", PAGE = "página", PAGES = "páginas", PIN = "marcador", PINS = "marcadores",
        HIDDEN = "%d escondidas pelos filtros.", HIDDEN_ONE = "1 escondida pelos filtros.",
        NONE = "Nenhuma página registrada aqui ainda.",
        WHEN = "Quando", RANGE_ALL = "Tudo", RANGE_SESSION = "Esta sessão", RANGE_TODAY = "Hoje",
        FAVONLY = "Só memórias favoritas",
        REGION = "Esta região", FIRST_VISIT = "Primeira visita: %s", R_LINE1 = "Missões: %d   Quedas: %d   Inimigos: %d",
        R_LINE2 = "Níveis: %d   Itens: %d   Favoritas: %d", CLICK_OPEN = "Clique para abrir a página no livro",
        STATUS = "Mostrando %d de %d páginas aqui.", STATUS_NONE = "Nenhuma página daqui passa pelos filtros.",
        OPACITY = "Opacidade dos marcadores",
        OPACITY_HINT = "Marcadores mais fracos deixam ver os de missão do jogo por baixo.",
        RARITY = "Menor raridade mostrada", KINDS = "Páginas mostradas",
        KIND = {
            quest = "Missões", level = "Níveis", milestone = "Marcos", death = "Mortes",
            boss = "Inimigos", dungeon = "Masmorras", zone = "Terras", mount = "Montarias",
            guild = "Guild", party = "Grupo", pet = "Companheiros", achievement = "Feitos", profession = "Ofícios",
        },
    },
    frFR = {
        TAB = "Carte", SHOW = "Afficher les marqueurs sur la carte du monde", OPEN = "Ouvrir la carte du monde",
        SUMMARY = "%s\194\160: %d %s, %d %s.", PAGE = "page", PAGES = "pages", PIN = "marqueur", PINS = "marqueurs",
        HIDDEN = "%d masquées par les filtres.", HIDDEN_ONE = "1 masquée par les filtres.",
        NONE = "Aucune page enregistrée ici pour l'instant.",
        WHEN = "Quand", RANGE_ALL = "Tout", RANGE_SESSION = "Cette session", RANGE_TODAY = "Aujourd'hui",
        FAVONLY = "Seulement les souvenirs préférés",
        REGION = "Cette région", FIRST_VISIT = "Première visite\194\160: %s", R_LINE1 = "Quêtes\194\160: %d   Chutes\194\160: %d   Ennemis\194\160: %d",
        R_LINE2 = "Niveaux\194\160: %d   Objets\194\160: %d   Préférés\194\160: %d", CLICK_OPEN = "Cliquez pour ouvrir la page dans le livre",
        STATUS = "%d pages sur %d affichées ici.", STATUS_NONE = "Aucune page d'ici ne passe les filtres.",
        OPACITY = "Opacité des marqueurs",
        OPACITY_HINT = "Des marqueurs plus pâles laissent voir ceux des quêtes du jeu en dessous.",
        RARITY = "Plus faible rareté affichée", KINDS = "Pages affichées",
        KIND = {
            quest = "Quêtes", level = "Niveaux", milestone = "Jalons", death = "Morts",
            boss = "Ennemis", dungeon = "Donjons", zone = "Régions", mount = "Montures",
            guild = "Guilde", party = "Groupe", pet = "Familiers", achievement = "Hauts faits", profession = "Métiers",
        },
    },
}
local UI = UI_TEXT[GetLocale()] or UI_TEXT.enUS
local KIND_ORDER = {
    "quest", "level", "milestone", "death", "boss", "dungeon",
    "zone", "mount", "guild", "party", "pet", "achievement", "profession",
}

-- A page's rarity (0 Trivial .. 5 Legendary): a quest carries its own.
local function TierOf(e)
    if e.kind == "quest" and type(e.tier) == "number" then return e.tier end
    return KIND_TIER[e.kind] or 1
end

local function Say(msg)
    print("|cffffd100Skald Atlas|r: " .. msg)
end

local function Canvas()
    if not WorldMapFrame then return end
    if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
    return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

-- How solid the medallions are (the game's own quest markers sit under or beside them).
local function PinAlpha()
    return (SkaldAtlasDB and SkaldAtlasDB.alpha) or 0.75
end

-- Which pages a marker may show: the smallest rarity, the kinds, when they happened (all, this session,
-- today) and, if asked, only the favourites.
local function MakeFilter(minTier, kinds, range, onlyFav)
    local session = SkaldAPI and SkaldAPI.Session and SkaldAPI.Session()
    local from, to
    if range == "today" then
        local now = date("*t", time())
        from = time({ year = now.year, month = now.month, day = now.day, hour = 0 })
        to = from + 86400
    end
    return function(e)
        if TierOf(e) < minTier then return false end
        if kinds[GLYPH[e.kind] or e.kind] == false then return false end
        if onlyFav and not e.fav then return false end
        if range == "session" and (not session or e.ses ~= session) then return false end
        if from and not (e.t and e.t >= from and e.t < to) then return false end
        return true
    end
end

local function CurrentFilter()
    local db = SkaldAtlasDB
    return MakeFilter(db.minTier or 0, db.kinds or {}, db.range or "all", db.onlyFav)
end

local function ShowTooltip(pin)
    local list = pin.entries
    if not list or #list == 0 then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(pin.title or list[1].zone or "?", 1, 0.82, 0)
    local shown = 0
    for i = #list, 1, -1 do
        if shown >= MAX_TIP then break end
        local e = list[i]
        GameTooltip:AddLine(date(SkaldAPI.DateFormat or "%b %d, %H:%M", e.t), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(SkaldAPI.Render(e), 1, 1, 1, true)
        if e.fav and e.favNote then GameTooltip:AddLine(e.favNote, 1, 0.82, 0, true) end
        shown = shown + 1
    end
    if #list > shown then
        GameTooltip:AddLine(string.format("+%d", #list - shown), 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(UI.CLICK_OPEN, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function GetPin(i, canvas)
    local pin = pins[i]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, canvas)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin:EnableMouse(true)

    pin.medallion = pin:CreateTexture(nil, "ARTWORK")
    pin.medallion:SetAllPoints()
    pin.glyph = pin:CreateTexture(nil, "OVERLAY")
    pin.glyph:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    pin.glyph:SetPoint("CENTER", 0, 1)

    -- The group count: white with a dark outline, so it reads on any part of the map.
    pin.count = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pin.count:SetPoint("LEFT", pin, "RIGHT", 1, 0)
    pcall(function()
        local file, size = GameFontNormalSmall:GetFont()
        if file then pin.count:SetFont(file, (size or 10) + 2, "OUTLINE") end
    end)
    pin.count:SetTextColor(1, 1, 1)
    pin.star = pin:CreateTexture(nil, "OVERLAY", nil, 2)
    pin.star:SetSize(12, 12)
    pin.star:SetPoint("TOPRIGHT", pin, "TOPRIGHT", 4, 4)
    pin.star:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_fav")
    pin.star:Hide()
    -- A click opens the newest page of the marker in the book, and puts the map away.
    pin:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not self.entries or #self.entries == 0 then return end
        local e = self.entries[#self.entries]
        GameTooltip:Hide()
        pcall(function()
            if WorldMapFrame and WorldMapFrame:IsShown() then
                if HideUIPanel then HideUIPanel(WorldMapFrame) else WorldMapFrame:Hide() end
            end
        end)
        if SkaldAPI and SkaldAPI.OpenEntry then SkaldAPI.OpenEntry(e) end
    end)

    -- Faint markers let the game's own show through; the one under the mouse is solid.
    pin:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        ShowTooltip(self)
    end)
    pin:SetScript("OnLeave", function(self)
        self:SetAlpha(PinAlpha())
        GameTooltip:Hide()
    end)

    pins[i] = pin
    return pin
end

local function HideAll()
    for i = 1, #pins do pins[i]:Hide() end
end

-- Pages that would overlap on screen share one marker, which wears the rarity
-- and symbol of its most notable page (rarer first, then newer).
local function Cluster(entries, mapID, w, h, filter)
    local clusters, grid = {}, {}
    local radius2 = PIN_SIZE * PIN_SIZE
    for _, e in ipairs(entries) do
        if e.m == mapID and e.x and e.y and filter(e) then
            local px, py = e.x * w, e.y * h
            local cx, cy = math.floor(px / PIN_SIZE), math.floor(py / PIN_SIZE)
            -- Only the markers in the same or a neighbouring square of the grid can be close enough;
            -- of those the oldest wins, exactly as if every marker had been compared in turn.
            local home
            for gx = cx - 1, cx + 1 do
                for gy = cy - 1, cy + 1 do
                    local bucket = grid[gx * 100003 + gy]
                    if bucket then
                        for _, c in ipairs(bucket) do
                            local dx, dy = c.px - px, c.py - py
                            if dx * dx + dy * dy < radius2 and (not home or c.index < home.index) then home = c end
                        end
                    end
                end
            end
            if home then
                table.insert(home.entries, e)
                if TierOf(e) >= TierOf(home.top) then home.top = e end
                if e.fav then home.fav = true end
            else
                local c = { x = e.x, y = e.y, px = px, py = py, index = #clusters + 1, top = e, entries = { e },
                    fav = e.fav and true or nil }
                clusters[#clusters + 1] = c
                local key = cx * 100003 + cy
                local bucket = grid[key]
                if not bucket then bucket = {}; grid[key] = bucket end
                bucket[#bucket + 1] = c
            end
        end
    end
    return clusters
end

-- On a continent or the world map the pages are not on that map itself but on the zones
-- inside it. Each zone becomes one marker, at the centre of its pages, with their count.
local childCache, rectCache = {}, {}

-- The zone directly under `top` that `mapID` belongs to (or is), if any.
local function ChildUnder(mapID, top)
    local key = mapID .. "/" .. top
    local cached = childCache[key]
    if cached ~= nil then return cached or nil end
    local found = false
    local current = mapID
    for _ = 1, 8 do
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(current)
        if not info or not info.parentMapID or info.parentMapID == 0 then break end
        if info.parentMapID == top then found = current; break end
        current = info.parentMapID
    end
    childCache[key] = found
    return found or nil
end

-- A page's place on `top`, from its place on its own map.
local function ToParent(e, top)
    if not (C_Map and C_Map.GetMapRectOnMap) then return end
    local key = e.m .. "/" .. top
    local rect = rectCache[key]
    if rect == nil then
        local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, e.m, top)
        if ok and type(minX) == "number" and type(maxX) == "number" and maxX > minX and maxY > minY then
            rect = { minX, maxX, minY, maxY }
        else
            rect = false
        end
        rectCache[key] = rect
    end
    if not rect then return end
    return rect[1] + e.x * (rect[2] - rect[1]), rect[3] + e.y * (rect[4] - rect[3])
end

local function ZoneSummaries(entries, top, filter)
    local groups, order = {}, {}
    for _, e in ipairs(entries) do
        if e.m and e.m ~= top and e.x and e.y and filter(e) then
            local child = ChildUnder(e.m, top)
            if child then
                local px, py = ToParent(e, top)
                if px then
                    local g = groups[child]
                    if not g then
                        local info = C_Map.GetMapInfo(child)
                        g = { entries = {}, sx = 0, sy = 0, top = e, title = info and info.name }
                        groups[child] = g
                        order[#order + 1] = g
                    end
                    g.entries[#g.entries + 1] = e
                    if e.fav then g.fav = true end
                    g.sx, g.sy = g.sx + px, g.sy + py
                    if TierOf(e) >= TierOf(g.top) then g.top = e end
                end
            end
        end
    end
    for _, g in ipairs(order) do
        g.x, g.y = g.sx / #g.entries, g.sy / #g.entries
    end
    return order
end

-- How many pages a map holds under a filter: its own and those of the lands inside it.
local function CountPages(entries, mapID, filter)
    local n = 0
    for _, e in ipairs(entries) do
        if e.m and e.x and e.y and filter(e) then
            if e.m == mapID then
                n = n + 1
            else
                local child = ChildUnder(e.m, mapID)
                if child and ToParent(e, mapID) then n = n + 1 end
            end
        end
    end
    return n
end

-- Every marker for a map: the pages on it, then one per zone inside it.
local function CollectPins(entries, mapID, w, h, filter)
    local pins = Cluster(entries, mapID, w, h, filter)
    for _, group in ipairs(ZoneSummaries(entries, mapID, filter)) do
        pins[#pins + 1] = group
    end
    return pins
end

local function Refresh()
    HideAll()
    activePins = 0
    if SkaldAtlasDB.hidden or not SkaldAPI then return end
    if not (WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID) then return end
    local canvas = Canvas()
    if not canvas then return end
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    local w, h = canvas:GetSize()
    if not w or w == 0 then return end

    -- Above the map's own pins, which are stacked from a few hundred upward.
    local level = math.min(9000, canvas:GetFrameLevel() + 3000)
    local n = 0
    for _, c in ipairs(CollectPins(SkaldAPI.GetEntries(), mapID, w, h, CurrentFilter())) do
        n = n + 1
        local pin = GetPin(n, canvas)
        pin.entries = c.entries
        pin.title = c.title
        pin.medallion:SetTexture(TEXTURES .. "pin_med" .. math.max(0, math.min(5, TierOf(c.top))))
        pin.glyph:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_" .. (GLYPH[c.top.kind] or "zone"))   -- the book's own icons
        pin.count:SetText(#c.entries > 1 and #c.entries or "")
        pin.star:SetShown(c.fav and true or false)
        pin:SetFrameLevel(level)
        pin:SetAlpha(PinAlpha())
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", c.x * w, -c.y * h)
        pin:Show()
    end
    activePins = n
end


-- The map settles a moment after it opens or changes zone; look once now and
-- once shortly after.
local function RefreshSoon()
    Refresh()
    if C_Timer and C_Timer.After then C_Timer.After(0.2, Refresh) end
end

-- A star marked or unmarked in the book changes the pins at once.
SkaldAPI.favHook = Refresh
-- (kept reachable for the regression scenarios)
SkaldAPI.AtlasPure = { MakeFilter = MakeFilter, Cluster = Cluster }

-- The world map frame can load on demand, so hook it as soon as it exists.
local hooked = false
local function InstallHooks()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", RefreshSoon)
    WorldMapFrame:HookScript("OnHide", HideAll)
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", RefreshSoon)
    end
end

-- The Map tab inside the Skald window: pins on or off, opacity, the smallest rarity (click a seal),
-- when (all, this session, today), favourites only, what the region you are in holds, and on the
-- right page the kinds of page.
local function BuildMapTab(panel)
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.45, 0.34, 0.20 }
    local syncs = {}
    local function SyncAll() for _, fn in ipairs(syncs) do fn() end end

    SkaldAPI.PageHeading(panel, UI.TAB, 0)

    -- A wax check box with its label; `glyph` (optional) is drawn between them.
    local function Check(text, x, y, get, set, glyph)
        local cb = SkaldAPI.MakeCheck(panel, text, get, function(on)
            set(on)
            Refresh()
            SyncAll()
        end, glyph and ("Interface\\AddOns\\Skald\\Textures\\ev_" .. glyph) or nil)
        cb:SetPoint("TOPLEFT", x, y)
        syncs[#syncs + 1] = cb.Sync
    end

    Check(UI.SHOW, 0, -52,
        function() return not SkaldAtlasDB.hidden end,
        function(on) SkaldAtlasDB.hidden = not on end)

    -- Marker opacity: three steps.
    SkaldAPI.SectionLabel(panel, UI.OPACITY, 0, -88)
    local steps = { 0.5, 0.75, 1 }
    local alphaButtons = {}
    for i, value in ipairs(steps) do
        local b = SkaldAPI.MakeButton(panel, 114, 26, string.format("%d%%", value * 100))
        b:SetPoint("TOPLEFT", (i - 1) * 114, -110)
        b:SetScript("OnClick", function()
            SkaldAtlasDB.alpha = value
            SyncAll()
            Refresh()
        end)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(UI.OPACITY, 1, 0.82, 0)
            GameTooltip:AddLine(UI.OPACITY_HINT, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        alphaButtons[i] = b
    end
    syncs[#syncs + 1] = function()
        local current = PinAlpha()
        for i, b in ipairs(alphaButtons) do
            b:SetActive(math.abs(steps[i] - current) < 0.01)
        end
    end

    SkaldAPI.SectionLabel(panel, UI.RARITY, 0, -148)
    local seals = {}
    for tier = 0, 5 do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(38, 38)
        b:SetPoint("TOPLEFT", tier * 56 + 4, -176)
        -- The chosen seal is circled, as in Skald's Options.
        local ring = SkaldAPI.MakeDisc(b, "BACKGROUND", 48, 0.431, 0.118, 0.102, 0)
        ring:SetPoint("CENTER", 0, 0)
        local inner = SkaldAPI.MakeDisc(b, "BACKGROUND", 44, 0.93, 0.87, 0.72, 1)
        inner:SetPoint("CENTER", 0, 0)
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\AddOns\\Skald\\Textures\\seal" .. tier)
        b.mark, b.inner, b.icon = ring, inner, icon
        b:SetScript("OnClick", function() SkaldAtlasDB.minTier = tier; SyncAll(); Refresh() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine((SkaldAPI.TierName and SkaldAPI.TierName(tier)) or tostring(tier))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        seals[tier] = b
    end
    syncs[#syncs + 1] = function()
        local chosen = SkaldAtlasDB.minTier or 0
        for tier, b in pairs(seals) do
            b.mark:SetShown(tier == chosen)
            b.inner:SetShown(tier == chosen)
            b.icon:SetAlpha(tier >= chosen and 1 or 0.4)
        end
    end

    -- When: all the pages, only those of this session, only today's. Each button says how many pages
    -- it holds, so an empty choice is not a surprise.
    SkaldAPI.SectionLabel(panel, UI.WHEN, 0, -236)
    local rangeButtons = {}
    local ranges = { "all", "session", "today" }
    for i, key in ipairs(ranges) do
        local b = SkaldAPI.MakeButton(panel, 114, 26, UI["RANGE_" .. key:upper()])
        b:SetPoint("TOPLEFT", (i - 1) * 114, -258)
        b:SetScript("OnClick", function()
            SkaldAtlasDB.range = (key ~= "all") and key or nil
            SyncAll()
            Refresh()
        end)
        rangeButtons[key] = b
    end
    syncs[#syncs + 1] = function()
        local current = SkaldAtlasDB.range or "all"
        local entries = SkaldAPI.GetEntries()
        for _, key in ipairs(ranges) do
            local filter = MakeFilter(0, {}, key, false)
            local n = 0
            for _, e in ipairs(entries) do
                if e.m and e.x and e.y and filter(e) then n = n + 1 end
            end
            local b = rangeButtons[key]
            b.text:SetText(UI["RANGE_" .. key:upper()] .. " (" .. n .. ")")
            b:SetActive(key == current)
        end
    end
    Check(UI.FAVONLY, 0, -292,
        function() return SkaldAtlasDB.onlyFav and true or false end,
        function(on) SkaldAtlasDB.onlyFav = on and true or nil end)

    SkaldAPI.PageHeading(panel, UI.KINDS, RIGHT_X)
    for i, kind in ipairs(KIND_ORDER) do
        Check(UI.KIND[kind], RIGHT_X, -52 - (i - 1) * 28,
            function() return (SkaldAtlasDB.kinds or {})[kind] ~= false end,
            function(on)
                SkaldAtlasDB.kinds = SkaldAtlasDB.kinds or {}
                -- (`(not on) and false or nil` is always nil in Lua: false loses the "or".)
                if on then
                    SkaldAtlasDB.kinds[kind] = nil
                else
                    SkaldAtlasDB.kinds[kind] = false
                end
            end, kind)
    end

    -- The region: the land of the map open on screen (or the one you are in), what the diary holds
    -- there, and how much of it the filters show.
    SkaldAPI.SectionLabel(panel, UI.REGION, 0, -326)
    local function Line(y, font, color)
        local fs = panel:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", 0, y)
        fs:SetWidth(342)
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(color[1], color[2], color[3])
        return fs
    end
    local regionName = Line(-346, "SkaldBody", head)
    local fact1, fact2, fact3 = Line(-368, "SkaldBody", body), Line(-386, "SkaldBody", body), Line(-404, "SkaldBody", body)
    local status = Line(-424, "SkaldSmall", muted)
    syncs[#syncs + 1] = function()
        local ok = pcall(function()
            local mapID
            if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID then
                mapID = WorldMapFrame:GetMapID()
            end
            if not mapID and C_Map and C_Map.GetBestMapForUnit then
                mapID = C_Map.GetBestMapForUnit("player")
            end
            if not mapID then
                regionName:SetText(""); fact1:SetText(""); fact2:SetText(""); fact3:SetText(""); status:SetText("")
                return
            end
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            regionName:SetText((info and info.name) or "?")
            local entries = SkaldAPI.GetEntries()
            -- Markers are grouped by how close they are on screen: use the canvas size when the map
            -- has one, a typical size otherwise.
            local w, h = 1000, 667
            local canvas = Canvas()
            if canvas then
                local cw, ch = canvas:GetSize()
                if cw and cw > 0 and ch and ch > 0 then w, h = cw, ch end
            end
            local zoneId = SkaldAPI.ZoneIdOfMap and SkaldAPI.ZoneIdOfMap(mapID)
            local region = zoneId and SkaldAPI.RegionStats and SkaldAPI.RegionStats(zoneId)
            if region then
                fact1:SetText(string.format(UI.FIRST_VISIT, date(SkaldAPI.DayFormat or "%d/%m/%Y", region.first or time())))
                fact2:SetText(string.format(UI.R_LINE1, region.quest, region.death, region.boss))
                fact3:SetText(string.format(UI.R_LINE2, region.level, region.loot, region.fav))
            else
                fact1:SetText(""); fact2:SetText(""); fact3:SetText("")
            end
            local total = CountPages(entries, mapID, MakeFilter(0, {}, "all", false))
            local shown = 0
            for _, c in ipairs(CollectPins(entries, mapID, w, h, CurrentFilter())) do shown = shown + #c.entries end
            if total == 0 then
                status:SetText(UI.NONE)
            elseif shown == 0 then
                status:SetText(UI.STATUS_NONE)
            else
                status:SetText(string.format(UI.STATUS, shown, total))
            end
        end)
        if not ok then
            regionName:SetText(""); fact1:SetText(""); fact2:SetText(""); fact3:SetText(""); status:SetText("")
        end
    end

    return SyncAll
end

-- An old, separate Skald Atlas (0.6 or earlier) does the same work: then this part stays out of
-- its way. The small replacement addon that ships now sets SkaldAtlasStub and does nothing.
local dormant = false
local function SeparateAtlasRunning()
    if _G.SkaldAtlasStub then return false end
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded("SkaldAtlas") end
    return IsAddOnLoaded and IsAddOnLoaded("SkaldAtlas") or false
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME then
            SkaldAtlasDB = SkaldAtlasDB or {}
        elseif name == "Blizzard_WorldMap" and not dormant then
            InstallHooks()
        end
    elseif event == "PLAYER_LOGIN" then
        SkaldAtlasDB = SkaldAtlasDB or {}
        if not SkaldAPI or SeparateAtlasRunning() then
            dormant = true
            return
        end
        InstallHooks()
        if SkaldAPI.AddTab then
            SkaldAPI.AddTab("map", UI.TAB, BuildMapTab)
        end
    end
end)

local function Debug()
    local canvas = Canvas()
    local mapID = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local total, onMap, withPos = 0, 0, 0
    if SkaldAPI then
        for _, e in ipairs(SkaldAPI.GetEntries()) do
            total = total + 1
            if e.x and e.y then withPos = withPos + 1 end
            if e.m == mapID and e.x and e.y then onMap = onMap + 1 end
        end
    end
    local w, h = 0, 0
    if canvas then w, h = canvas:GetSize() end
    Say(string.format("hooked=%s map=%s shown=%s canvas=%s (%.0fx%.0f) hidden=%s",
        tostring(hooked), tostring(mapID), tostring(WorldMapFrame and WorldMapFrame:IsShown()),
        tostring(canvas ~= nil), w or 0, h or 0, tostring(SkaldAtlasDB.hidden)))
    Say(string.format("pages=%d withPosition=%d onThisMap=%d pinsShown=%d",
        total, withPos, onMap, activePins))
end

SLASH_SKALDATLAS1 = "/skatlas"
SLASH_SKALDATLAS2 = "/sa"
SlashCmdList["SKALDATLAS"] = function(msg)
    if dormant then return end
    msg = strtrim((msg or ""):lower())
    local tierArg = msg:match("^tier%s*(%d)")
    if msg:match("^tier") then
        local n = tonumber(tierArg)
        if n and n >= 0 and n <= 5 then
            SkaldAtlasDB.minTier = n
            Say(string.format(L.TIER_SET, n))
            Refresh()
        else
            Say(string.format(L.TIER_HELP, SkaldAtlasDB.minTier or 0))
        end
        return
    end
    if msg == "debug" then
        Refresh()
        Debug()
        return
    end
    SkaldAtlasDB.hidden = not SkaldAtlasDB.hidden
    Say(SkaldAtlasDB.hidden and L.OFF or L.ON)
    Refresh()
end
