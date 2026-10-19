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
    mount = 3, guild = 3, guildleave = 1, party = 2, achievement = 5,
    skill = 2, profession = 2, quest = 1, tame = 2,
}

-- Which symbol sits inside the medallion.
local GLYPH = {
    quest = "quest", level = "level", milestone = "milestone", death = "death",
    boss = "boss", dungeon = "dungeon", zone = "zone", mount = "mount",
    guild = "guild", guildleave = "guild", party = "party", tame = "pet",
    achievement = "achievement", skill = "profession", profession = "profession",
}

-- Strings and order for the Map tab (it lives inside the Skald window).
local UI_TEXT = {
    enUS = {
        TAB = "Map", SHOW = "Show pins on the world map", OPEN = "Open the world map",
        SUMMARY = "%s: %d %s, %d %s.", PAGE = "page", PAGES = "pages", PIN = "pin", PINS = "pins",
        HIDDEN = "%d hidden by the filters.", HIDDEN_ONE = "1 hidden by the filters.",
        NONE = "No pages recorded here yet.",
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
        shown = shown + 1
    end
    if #list > shown then
        GameTooltip:AddLine(string.format("+%d", #list - shown), 0.6, 0.6, 0.6)
    end
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
local function Cluster(entries, mapID, w, h, minTier, kinds)
    local clusters = {}
    for _, e in ipairs(entries) do
        if e.m == mapID and e.x and e.y and TierOf(e) >= minTier
            and kinds[GLYPH[e.kind] or e.kind] ~= false then
            local home
            for _, c in ipairs(clusters) do
                local dx, dy = (c.x - e.x) * w, (c.y - e.y) * h
                if dx * dx + dy * dy < PIN_SIZE * PIN_SIZE then home = c break end
            end
            if home then
                table.insert(home.entries, e)
                if TierOf(e) >= TierOf(home.top) then home.top = e end
            else
                table.insert(clusters, { x = e.x, y = e.y, top = e, entries = { e } })
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

local function ZoneSummaries(entries, top, minTier, kinds)
    local groups, order = {}, {}
    for _, e in ipairs(entries) do
        if e.m and e.m ~= top and e.x and e.y and TierOf(e) >= minTier
            and kinds[GLYPH[e.kind] or e.kind] ~= false then
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

-- Every marker for a map: the pages on it, then one per zone inside it.
local function CollectPins(entries, mapID, w, h, minTier, kinds)
    local pins = Cluster(entries, mapID, w, h, minTier, kinds)
    for _, group in ipairs(ZoneSummaries(entries, mapID, minTier, kinds)) do
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
    local minTier = SkaldAtlasDB.minTier or 0

    local n = 0
    for _, c in ipairs(CollectPins(SkaldAPI.GetEntries(), mapID, w, h, minTier, SkaldAtlasDB.kinds or {})) do
        n = n + 1
        local pin = GetPin(n, canvas)
        pin.entries = c.entries
        pin.title = c.title
        pin.medallion:SetTexture(TEXTURES .. "pin_med" .. math.max(0, math.min(5, TierOf(c.top))))
        pin.glyph:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_" .. (GLYPH[c.top.kind] or "zone"))   -- the book's own icons
        pin.count:SetText(#c.entries > 1 and #c.entries or "")
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

-- The Map tab inside the Skald window: pins on or off, the smallest rarity
-- shown (click a seal) and which kinds of page appear.
local function BuildMapTab(panel)
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local syncs = {}
    local function SyncAll() for _, fn in ipairs(syncs) do fn() end end

    -- Left page: the pins and the smallest rarity. Right page: the kinds of page.
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
    SkaldAPI.SectionLabel(panel, UI.OPACITY, 0, -92)
    local steps = { 0.5, 0.75, 1 }
    local alphaButtons = {}
    for i, value in ipairs(steps) do
        local b = SkaldAPI.MakeButton(panel, 114, 26, string.format("%d%%", value * 100))
        b:SetPoint("TOPLEFT", (i - 1) * 114, -116)
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

    SkaldAPI.SectionLabel(panel, UI.RARITY, 0, -164)
    local seals = {}
    for tier = 0, 5 do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(38, 38)
        b:SetPoint("TOPLEFT", tier * 56 + 4, -192)
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

    -- What the map you are on holds: pages recorded here, the pins they make, and how many
    -- the filters above hide. The map open on screen counts; otherwise the zone you are in.
    local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("TOPLEFT", 0, -250)
    summary:SetWidth(342)
    summary:SetJustifyH("LEFT")
    summary:SetSpacing(2)
    summary:SetTextColor(0.15, 0.10, 0.04)
    syncs[#syncs + 1] = function()
        local ok = pcall(function()
            local mapID
            if WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID then
                mapID = WorldMapFrame:GetMapID()
            end
            if not mapID and C_Map and C_Map.GetBestMapForUnit then
                mapID = C_Map.GetBestMapForUnit("player")
            end
            if not mapID then summary:SetText(""); return end

            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            local entries = SkaldAPI.GetEntries()
            -- Pins are grouped by how close they are on screen: use the canvas size when the
            -- map has one, a typical size otherwise.
            local w, h = 1000, 667
            local canvas = Canvas()
            if canvas then
                local cw, ch = canvas:GetSize()
                if cw and cw > 0 and ch and ch > 0 then w, h = cw, ch end
            end

            -- Pages that belong to this map (its own and its zones'), with no filter, against
            -- the markers the filters leave.
            local function Count(list)
                local n = 0
                for _, c in ipairs(list) do n = n + #c.entries end
                return n
            end
            local total = Count(CollectPins(entries, mapID, w, h, 0, {}))
            local clusters = CollectPins(entries, mapID, w, h, SkaldAtlasDB.minTier or 0, SkaldAtlasDB.kinds or {})
            local shown = Count(clusters)

            local pins = #clusters
            local text = string.format(UI.SUMMARY, (info and info.name) or "?",
                total, total == 1 and UI.PAGE or UI.PAGES, pins, pins == 1 and UI.PIN or UI.PINS)
            if total == 0 then
                text = text .. "\n" .. UI.NONE
            elseif total > shown then
                local hidden = total - shown
                text = text .. "\n" .. (hidden == 1 and UI.HIDDEN_ONE or string.format(UI.HIDDEN, hidden))
            end
            summary:SetText(text)
        end)
        if not ok then summary:SetText("") end
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
