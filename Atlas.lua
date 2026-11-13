-- Skald Atlas, now a part of Skald.
-- Pins the pages of the Skald journal on the world map. It stays dormant when the separate
-- Skald Atlas addon (an old install) is also running, so nothing is drawn twice.

local ADDON_NAME, ns = ...

local L = ({
    enUS = {
        LOADED = "loaded. Pages appear on the world map. |cffffffff/skatlas|r toggles pins.",
        ON = "pins shown.",
        OFF = "pins hidden.",
        NEED = "Skald is required.",
        TIER_SET = "showing pages of rarity %d and above.",
        TIER_HELP = "use |cffffffff/skatlas tier 0-5|r (0 shows everything, 5 only legendary). Now: %d.",
    }, esES = {
            LOADED = "cargado. Las páginas aparecen en el mapa del mundo. |cffffffff/skatlas|r alterna los marcadores.",
            ON = "marcadores visibles.",
            OFF = "marcadores ocultos.",
            NEED = "Se necesita Skald.",
            TIER_SET = "mostrando páginas de rareza %d o superior.",
            TIER_HELP = "usa |cffffffff/skatlas tier 0-5|r (0 muestra todo, 5 solo lo legendario). Actual: %d.",
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
})[GetLocale() == "esMX" and "esES" or GetLocale()] or nil
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
local lastScale = 1

-- OpenMap (one stitched world map) zooms by scaling the canvas itself, from the whole world down to the street, so a frame
-- of fixed size on the canvas would grow with the zoom (a medallion as big as a zone). Its own icons are rescaled by the game
-- (OnCanvasScaleChanged); ours are children of the canvas, so they take the inverse of the canvas scale. Without OpenMap the
-- scale is 1: nothing changes in the game's own map.
local function Stitched()
    local api = _G.OpenMapAPI
    if not (api and type(api.IsStitched) == "function") then return false end
    local ok, on = pcall(api.IsStitched)
    return ok and on and true or false
end
local function PinScale()
    if not Stitched() or not WorldMapFrame or not WorldMapFrame.GetCanvasScale then return 1 end
    local ok, scale = pcall(WorldMapFrame.GetCanvasScale, WorldMapFrame)
    if not ok or type(scale) ~= "number" or scale ~= scale or scale <= 0 then return 1 end
    return math.max(0.02, math.min(4, 1 / scale))
end
local function PlacePin(pin, canvas, w, h, scale)
    pin:SetScale(scale)
    pin:ClearAllPoints()
    -- (an offset is told in the units of the frame that has it: the pin's own scale)
    pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.nx * w / scale, -pin.ny * h / scale)
end

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

-- The picture on a medallion: the book's own icon of the kind; a trade page has the picture of its trade (the generic
-- generic trade icon is only for a trade without one).
local function PinGlyph(entry)
    local own = (entry.kind == "profession" or entry.kind == "skill") and SkaldAPI.EventIconPath and SkaldAPI.EventIconPath(entry.kind, entry)
    return own or ("Interface\\AddOns\\Skald\\Textures\\ev_" .. (GLYPH[entry.kind] or "zone"))
end

-- The pages a click on a marker tries, in order: the one whose picture the marker shows (the top of its group), then
-- the others, newest first. (A click used to open the newest, which was not the page of the picture when a marker held
-- several, so some markers led to the page they showed and others to another.)
local function PinTargets(top, entries)
    local list = {}
    if top then list[1] = top end
    for i = #(entries or {}), 1, -1 do
        if entries[i] ~= top then list[#list + 1] = entries[i] end
    end
    return list
end

-- The same pages starting at the one the next click opens: every click of a marker that holds several goes to the next
-- page, so no page is out of reach because another of the group shares its picture. nextIndex counts from 1.
local function PinOrder(top, entries, nextIndex)
    local base = PinTargets(top, entries)
    local n = #base
    if n == 0 then return base end
    local k = ((nextIndex or 1) - 1) % n
    local out = {}
    for i = 1, n do out[i] = base[(i - 1 + k) % n + 1] end
    return out
end

-- Strings and order for the Map tab (it lives inside the Skald window).
local UI_TEXT = {
    enUS = {
        TAB = "Atlas", SHOW = "Show pins on the world map", OPEN = "Open the world map",
        SUMMARY = "%s: %d %s, %d %s.", PAGE = "page", PAGES = "pages", PIN = "pin", PINS = "pins",
        HIDDEN = "%d hidden by the filters.", HIDDEN_ONE = "1 hidden by the filters.",
        NONE = "No pages recorded here yet.",
        WHEN = "When", RANGE_ALL = "All", RANGE_SESSION = "This session", RANGE_TODAY = "Today",
        FAVONLY = "Only favourite memories",
        REGION = "This region", FIRST_VISIT = "First visit: %s", R_LINE1 = "Quests: %d   Falls: %d   Foes: %d",
        R_LINE2 = "Levels: %d   Items: %d   Favourites: %d", CLICK_OPEN = "Click to open the page in the book", NOT_SHOWN = "The book does not show that page.",
        STATUS = "Showing %d of %d pages here.", STATUS_NONE = "No page here matches the filters.",
        OPACITY = "Marker opacity",
        OPACITY_HINT = "Fainter markers let the game's own quest markers show through.",
        RARITY = "Smallest rarity shown", KINDS = "Pages shown",
        KIND = {
            quest = "Quests", level = "Levels", milestone = "Milestones", death = "Deaths",
            boss = "Foes", dungeon = "Dungeons", zone = "Lands", mount = "Mounts",
            guild = "Guild", party = "Group", pet = "Pets", achievement = "Deeds", profession = "Crafts",
        },
    }, esES = {
            TAB = "Atlas",
            SHOW = "Mostrar marcadores en el mapa del mundo",
            OPEN = "Abrir el mapa del mundo",
            SUMMARY = "%s: %d %s, %d %s.",
            PAGE = "página",
            PAGES = "páginas",
            PIN = "marcador",
            PINS = "marcadores",
            HIDDEN = "%d ocultos por los filtros.",
            HIDDEN_ONE = "1 oculto por los filtros.",
            NONE = "Aún no hay páginas de este lugar.",
            WHEN = "Fecha",
            RANGE_ALL = "Todas",
            RANGE_SESSION = "Esta sesión",
            RANGE_TODAY = "Hoy",
            FAVONLY = "Solo recuerdos favoritos",
            REGION = "Esta región",
            FIRST_VISIT = "Primera visita: %s",
            R_LINE1 = "Misiones: %d   Caídas: %d   Enemigos: %d",
            R_LINE2 = "Niveles: %d   Objetos: %d   Favoritos: %d",
            CLICK_OPEN = "Haz clic para abrir la página en el libro",
            NOT_SHOWN = "El libro no muestra esa página.",
            STATUS = "Mostrando %d de %d páginas de este lugar.",
            STATUS_NONE = "Ninguna página de aquí coincide con los filtros.",
            OPACITY = "Opacidad de los marcadores",
            OPACITY_HINT = "Los marcadores más tenues dejan ver los de las misiones del juego.",
            RARITY = "Rareza mínima mostrada",
            KINDS = "Páginas visibles",
            KIND = {
                quest = "Misiones",
                level = "Niveles",
                milestone = "Hitos",
                death = "Muertes",
                boss = "Enemigos",
                dungeon = "Mazmorras",
                zone = "Tierras",
                mount = "Monturas",
                guild = "Hermandad",
                party = "Grupo",
                pet = "Mascotas",
                achievement = "Hazañas",
                profession = "Oficios",
            },
        },
    ptBR = {
        TAB = "Atlas", SHOW = "Mostrar marcadores no mapa-múndi", OPEN = "Abrir o mapa-múndi",
        SUMMARY = "%s: %d %s, %d %s.", PAGE = "página", PAGES = "páginas", PIN = "marcador", PINS = "marcadores",
        HIDDEN = "%d escondidas pelos filtros.", HIDDEN_ONE = "1 escondida pelos filtros.",
        NONE = "Nenhuma página registrada aqui ainda.",
        WHEN = "Quando", RANGE_ALL = "Tudo", RANGE_SESSION = "Esta sessão", RANGE_TODAY = "Hoje",
        FAVONLY = "Só memórias favoritas",
        REGION = "Esta região", FIRST_VISIT = "Primeira visita: %s", R_LINE1 = "Missões: %d   Quedas: %d   Inimigos: %d",
        R_LINE2 = "Níveis: %d   Itens: %d   Favoritas: %d", CLICK_OPEN = "Clique para abrir a página no livro", NOT_SHOWN = "O livro não mostra essa página.",
        STATUS = "Mostrando %d de %d páginas aqui.", STATUS_NONE = "Nenhuma página daqui passa pelos filtros.",
        OPACITY = "Opacidade dos marcadores",
        OPACITY_HINT = "Marcadores mais fracos deixam ver os de missão do jogo por baixo.",
        RARITY = "Menor raridade mostrada", KINDS = "Páginas mostradas",
        KIND = {
            quest = "Missões", level = "Níveis", milestone = "Marcos", death = "Mortes",
            boss = "Inimigos", dungeon = "Masmorras", zone = "Terras", mount = "Montarias",
            guild = "Guilda", party = "Grupo", pet = "Companheiros", achievement = "Feitos", profession = "Ofícios",
        },
    },
    frFR = {
        TAB = "Atlas", SHOW = "Afficher les marqueurs sur la carte du monde", OPEN = "Ouvrir la carte du monde",
        SUMMARY = "%s\194\160: %d %s, %d %s.", PAGE = "page", PAGES = "pages", PIN = "marqueur", PINS = "marqueurs",
        HIDDEN = "%d masquées par les filtres.", HIDDEN_ONE = "1 masquée par les filtres.",
        NONE = "Aucune page enregistrée ici pour l'instant.",
        WHEN = "Quand", RANGE_ALL = "Tout", RANGE_SESSION = "Cette session", RANGE_TODAY = "Aujourd'hui",
        FAVONLY = "Seulement les souvenirs préférés",
        REGION = "Cette région", FIRST_VISIT = "Première visite\194\160: %s", R_LINE1 = "Quêtes\194\160: %d   Chutes\194\160: %d   Ennemis\194\160: %d",
        R_LINE2 = "Niveaux\194\160: %d   Objets\194\160: %d   Préférés\194\160: %d", CLICK_OPEN = "Cliquez pour ouvrir la page dans le livre", NOT_SHOWN = "Le livre ne montre pas cette page.",
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
UI_TEXT.esMX = UI_TEXT.esES
local UI = UI_TEXT[GetLocale() == "esMX" and "esES" or GetLocale()] or UI_TEXT.enUS
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

-- One reusable selector for crowded pins. Everything here is transient; the diary keeps its original coordinates.
local Wheel = { size = 212, height = 196, rowHeight = 26, header = 30, footer = 26, limit = 6, delay = 0.3 }
Wheel.text = (ns.LOCALES[GetLocale()] or ns.LOCALES.enUS).ATLAS_WHEEL
Wheel.backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } }

function Wheel.Groups(entries)
    local byKind, groups = {}, {}
    for _, e in ipairs(entries) do
        local key = GLYPH[e.kind] or e.kind
        if not UI.KIND[key] then key = "other" end
        local group = byKind[key]
        if not group then
            group = { key = key, label = UI.KIND[key] or Wheel.text.OTHER, entries = {}, top = e }
            byKind[key] = group
        end
        group.entries[#group.entries + 1] = e
        if TierOf(e) > TierOf(group.top) then group.top = e end
        if e.fav then group.fav = true end
    end
    for _, key in ipairs(KIND_ORDER) do if byKind[key] then groups[#groups + 1] = byKind[key] end end
    if byKind.other then groups[#groups + 1] = byKind.other end
    return groups
end

function Wheel.Source() return Wheel.group and Wheel.entries or Wheel.groups end
function Wheel.Count(n) return n == 1 and Wheel.text.COUNT_ONE or string.format(Wheel.text.COUNT, n) end

local function ShowTooltip(pin)
    local list = pin.entries
    if type(list) ~= "table" or #list == 0 then return end
    Wheel.tip = pin
    GameTooltip:SetOwner(Wheel.owner and Wheel.frame or pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(pin.title or list[1].zone or "?", 1, 0.82, 0)
    local shown = 0
    -- the first line is the page a click opens (the picture of the marker), then the newest of the others
    local order = PinOrder(pin.top, list, pin.nextPage)
    for i = 1, #order do
        if shown >= MAX_TIP then break end
        local e = order[i]
        GameTooltip:AddLine(date(SkaldAPI.DateFormat or "%b %d, %H:%M", e.t), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(SkaldAPI.Render(e), 1, 1, 1, true)
        if e.fav and e.favNote then GameTooltip:AddLine(e.favNote, 1, 0.82, 0, true) end
        shown = shown + 1
    end
    if #list > shown then
        GameTooltip:AddLine(string.format("+%d", #list - shown), 0.6, 0.6, 0.6)
    end
    local n = #order
    GameTooltip:AddLine(n > 1 and string.format("%s (%d/%d)", UI.CLICK_OPEN, ((pin.nextPage or 1) - 1) % n + 1, n) or UI.CLICK_OPEN, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function Wheel.HideTip(widget)
    if Wheel.tip and (not widget or Wheel.tip == widget) then GameTooltip:Hide(); Wheel.tip = nil end
end

function Wheel.Close()
    local owner = Wheel.owner
    Wheel.owner, Wheel.hover, Wheel.closeIn, Wheel.entries = nil, nil, nil, nil
    Wheel.all, Wheel.groups, Wheel.group, Wheel.groupPage = nil, nil, nil, nil
    Wheel.HideTip()
    for _, b in ipairs(Wheel.buttons or {}) do b.entry, b.top, b.entries, b.group = nil, nil, nil, nil; b:Hide() end
    if Wheel.frame then Wheel.frame:Hide() end
    if owner then owner:SetAlpha(PinAlpha()) end
end

local function OpenPinEntry(entry)
    Wheel.Close()
    pcall(function()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            if HideUIPanel then HideUIPanel(WorldMapFrame) else WorldMapFrame:Hide() end
        end
    end)
    if SkaldAPI and SkaldAPI.OpenEntry and not SkaldAPI.OpenEntry(entry) then
        print("|cffffd100Skald|r: " .. UI.NOT_SHOWN)
    end
end

function Wheel.ClickPin(self, button)
    if button ~= "LeftButton" or not self.entries or #self.entries == 0 then return end
    local targets = PinTargets(self.top, self.entries)
    local n = #targets
    local index = ((self.nextPage or 1) - 1) % n + 1
    self.nextPage = index % n + 1
    OpenPinEntry(targets[index])
end

function Wheel.Stay(widget)
    Wheel.hover, Wheel.closeIn = widget, nil
end

function Wheel.Leave(widget)
    Wheel.HideTip(widget)
    if Wheel.hover == widget then Wheel.hover, Wheel.closeIn = nil, Wheel.delay end
end

function Wheel.Summary(widget, caption)
    if not Wheel.owner then return end
    Wheel.Stay(widget)
    Wheel.tip = widget
    GameTooltip:SetOwner(Wheel.frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(Wheel.group and Wheel.group.label or Wheel.owner.title or Wheel.owner.top.zone or "?", 1, 0.82, 0)
    GameTooltip:AddLine(Wheel.Count(#Wheel.entries), 1, 1, 1)
    GameTooltip:AddLine(caption or (Wheel.group and Wheel.text.SELECT or Wheel.text.SELECT_TYPE), 0.8, 0.8, 0.8, true)
    if #Wheel.Source() > Wheel.limit then GameTooltip:AddLine(Wheel.text.SCROLL, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

function Wheel.Describe(widget)
    Wheel.Stay(widget)
    widget:SetAlpha(1)
    if type(widget.highlight) == "table" or type(widget.highlight) == "userdata" then widget.highlight:Show() end
    if type(widget.group) ~= "table" then ShowTooltip(widget); return end
    Wheel.tip = widget
    GameTooltip:SetOwner(Wheel.frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(widget.group.label, 1, 0.82, 0)
    GameTooltip:AddLine(Wheel.Count(#widget.group.entries), 1, 1, 1)
    GameTooltip:AddLine(Wheel.text.SELECT_TYPE, 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

function Wheel.SelectGroup(group)
    if not Wheel.owner then return end
    for _, candidate in ipairs(Wheel.groups) do
        if candidate == group then
            Wheel.groupPage = Wheel.page
            Wheel.group, Wheel.entries, Wheel.page = group, group.entries, 1
            Wheel.Draw()
            return
        end
    end
end

function Wheel.Back()
    if not Wheel.owner then return end
    if Wheel.group and #Wheel.groups > 1 then
        Wheel.group, Wheel.entries, Wheel.page = nil, Wheel.all, Wheel.groupPage or 1
        Wheel.Draw()
    else
        Wheel.dismissed = Wheel.owner   -- hiding the panel exposes this same pin under the pointer
        Wheel.Close()
    end
end

-- Canvas units divided by the pin scale are the selector's own units, including with OpenMap zoomed in.
function Wheel.Position(owner, canvas, scale)
    local w, h = canvas:GetSize()
    local halfW, halfH = Wheel.size / 2, Wheel.height / 2
    local minX, maxX, minY, maxY = halfW, w / scale - halfW, halfH, h / scale - halfH
    local view = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
    if view and type(view.GetLeft) == "function" and type(view.GetEffectiveScale) == "function" then
        local cs, vs = canvas:GetEffectiveScale(), view:GetEffectiveScale()
        local cl, ct = canvas:GetLeft(), canvas:GetTop()
        local vl, vr, vt, vb = view:GetLeft(), view:GetRight(), view:GetTop(), view:GetBottom()
        if type(cs) == "number" and cs > 0 and type(vs) == "number" and vs > 0
            and type(cl) == "number" and type(ct) == "number" and type(vl) == "number" and type(vr) == "number"
            and type(vt) == "number" and type(vb) == "number" and vr > vl and vt > vb then
            local unit = cs * scale
            minX, maxX = (vl * vs - cl * cs) / unit + halfW, (vr * vs - cl * cs) / unit - halfW
            minY, maxY = (ct * cs - vt * vs) / unit + halfH, (ct * cs - vb * vs) / unit - halfH
        end
    end
    local function Fit(value, lo, hi) return hi < lo and (lo + hi) / 2 or math.max(lo, math.min(hi, value)) end
    local px, py = owner.nx * w / scale, owner.ny * h / scale
    local gap = PIN_SIZE / 2 + 6
    local x = px + halfW + gap
    if x > maxX then x = px - halfW - gap end
    -- Keep the heading beside the pin when the menu gains rows, instead of growing around the pointer.
    return Fit(x, minX, maxX), Fit(py + halfH - 15, minY, maxY)
end

function Wheel.Page(delta)
    if not Wheel.owner then return end
    Wheel.page = ((Wheel.page - 1 + delta) % math.ceil(#Wheel.Source() / Wheel.limit)) + 1
    Wheel.Draw()
end

function Wheel.Build(canvas)
    if Wheel.frame then return end
    -- A map's unit-position overlay can draw over its own children. This popup lives beside the map on UIParent.
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    Wheel.frame, Wheel.buttons = frame, {}
    frame.skaldPin = true   -- this is never a terrain layer for PinLevel
    frame:SetSize(Wheel.size, Wheel.height)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetBackdrop(Wheel.backdrop)
    ns.ThemeBackdrop(frame, {0.095,0.075,0.05,1}, {0.53,0.40,0.22,1}, "list")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnEnter", function(self) Wheel.Summary(self) end)
    frame:SetScript("OnLeave", Wheel.Leave)
    frame:SetScript("OnMouseWheel", function(_, delta) Wheel.Page(delta > 0 and -1 or 1) end)
    frame:SetScript("OnHide", function() if Wheel.owner then Wheel.Close() end end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not Wheel.owner then return end
        if not WorldMapFrame or not WorldMapFrame:IsShown() or not Wheel.owner:IsShown()
            or (WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() ~= Wheel.mapID) then Wheel.Close(); return end
        if Wheel.closeIn then
            Wheel.closeIn = Wheel.closeIn - elapsed
            if Wheel.closeIn <= 0 then
                -- The transparent space between the icons is part of the selector too.
                if self:IsMouseOver() == true then Wheel.Stay(self) else Wheel.Close() end
            end
        end
    end)
    local hub = CreateFrame("Frame", nil, frame)
    Wheel.hub = hub
    hub:SetSize(52, 24)
    hub:SetPoint("TOPLEFT", 6, -3)
    hub.text = hub:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hub.text:SetAllPoints()
    ns.ThemeText(hub.text, 0.88, 0.82, 0.68)
    hub:EnableMouse(true)
    hub:SetScript("OnEnter", function(self) Wheel.Summary(self, Wheel.group and #Wheel.groups > 1 and Wheel.text.BACK or Wheel.text.CLOSE) end)
    hub:SetScript("OnLeave", Wheel.Leave)
    hub:EnableMouseWheel(true)
    hub:SetScript("OnMouseWheel", function(_, delta) Wheel.Page(delta > 0 and -1 or 1) end)
    hub:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then Wheel.Back() end
    end)
    for i = 1, Wheel.limit do
        local b = CreateFrame("Frame", nil, frame)
        Wheel.buttons[i] = b
        b:SetSize(Wheel.size - 12, Wheel.rowHeight)
        b:EnableMouse(true)
        b:EnableMouseWheel(true)
        b.highlight = b:CreateTexture(nil, "BACKGROUND"); b.highlight:SetAllPoints()
        ns.ThemeFill(b.highlight, 0.84, 0.70, 0.40, 0.15, "selection"); b.highlight:Hide()
        b.medallion = b:CreateTexture(nil, "ARTWORK"); b.medallion:SetSize(20, 20); b.medallion:SetPoint("LEFT", 3, 0)
        b.glyph = b:CreateTexture(nil, "OVERLAY"); b.glyph:SetSize(14, 14); b.glyph:SetPoint("CENTER", b.medallion, "CENTER", 0, 1)
        b.star = b:CreateTexture(nil, "OVERLAY", nil, 2); b.star:SetSize(10, 10); b.star:SetPoint("TOPRIGHT", b.medallion, "TOPRIGHT", 3, 3)
        b.star:SetTexture(TEXTURES .. "ev_fav")
        b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.count:SetPoint("RIGHT", -6, 0)
        b.count:SetWidth(32); b.count:SetJustifyH("RIGHT")
        ns.ThemeText(b.count, 0.88, 0.82, 0.68)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("LEFT", 31, 0); b.label:SetWidth(Wheel.size - 90)
        b.label:SetJustifyH("LEFT"); b.label:SetWordWrap(false)
        ns.ThemeText(b.label, 0.92, 0.88, 0.78)
        b:SetScript("OnEnter", Wheel.Describe)
        b:SetScript("OnLeave", function(self) self.highlight:Hide(); Wheel.Leave(self) end)
        b:SetScript("OnMouseWheel", function(_, delta) Wheel.Page(delta > 0 and -1 or 1) end)
        b:SetScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" or not Wheel.owner then return end
            if type(self.group) == "table" then Wheel.SelectGroup(self.group)
            elseif type(self.entry) == "table" then OpenPinEntry(self.entry) end
        end)
    end
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.title:SetPoint("TOPLEFT", 58, -10)
    frame.title:SetWidth(Wheel.size - 68); frame.title:SetJustifyH("LEFT")
    ns.ThemeText(frame.title, 0.84, 0.70, 0.40)
    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.pageText:SetPoint("BOTTOM", 0, 10)
    ns.ThemeText(frame.pageText, 0.78, 0.73, 0.63)
    local function Nav(x, delta, caption)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(22, 20); b:SetPoint("BOTTOM", x, 5)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.text:SetAllPoints(); b.text:SetText(delta < 0 and "<" or ">")
        ns.ThemeText(b.text, 0.88, 0.82, 0.68)
        b:SetScript("OnEnter", function(self) Wheel.Summary(self, caption) end)
        b:SetScript("OnLeave", Wheel.Leave)
        b:SetScript("OnClick", function() Wheel.Page(delta) end)
        return b
    end
    Wheel.previous, Wheel.next = Nav(-84, -1, Wheel.text.PREVIOUS), Nav(84, 1, Wheel.text.NEXT)
end

function Wheel.Place()
    if not Wheel.owner then return end
    local canvas, scale = Canvas(), PinScale()
    if not canvas then return end
    local cs, us = canvas:GetEffectiveScale(), UIParent:GetEffectiveScale()
    Wheel.frame:SetScale(cs * scale / us)
    local x, y = Wheel.Position(Wheel.owner, canvas, scale)
    Wheel.frame:ClearAllPoints(); Wheel.frame:SetPoint("CENTER", canvas, "TOPLEFT", x, -y)
end

function Wheel.Draw()
    Wheel.HideTip()
    local source = Wheel.Source()
    local first = (Wheel.page - 1) * Wheel.limit + 1
    local count = math.min(Wheel.limit, #source - first + 1)
    local paged = #source > Wheel.limit
    Wheel.height = Wheel.header + count * Wheel.rowHeight + (paged and Wheel.footer or 8)
    Wheel.frame:SetSize(Wheel.size, Wheel.height)
    Wheel.Place()
    for i, b in ipairs(Wheel.buttons) do
        local item = i <= count and source[first + i - 1] or nil
        local group = not Wheel.group and item or nil
        local entry = Wheel.group and item or nil
        b.entry, b.top, b.entries, b.nextPage = entry, entry, entry and { entry } or nil, 1
        b.group = group
        if item then
            local top = group and group.top or entry
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", Wheel.frame, "TOPLEFT", 6, -Wheel.header - (i - 1) * Wheel.rowHeight)
            b.medallion:SetTexture(TEXTURES .. "pin_med" .. math.max(0, math.min(5, TierOf(top))))
            b.glyph:SetTexture(group and (TEXTURES .. "ev_" .. (group.key == "other" and "zone" or group.key)) or PinGlyph(entry))
            b.star:SetShown((group and group.fav or entry and entry.fav) and true or false)
            b.count:SetText(group and #group.entries or date("%H:%M", entry.t))
            local label = group and group.label or entry.arg
            if type(label) ~= "string" or label == "" then label = SkaldAPI.Render(entry) end
            b.label:SetText(label:gsub("[\r\n]", " "))
            b.highlight:SetShown(Wheel.hover == b)
            b:SetAlpha(1); b:Show()
        else b:Hide() end
    end
    Wheel.previous:SetShown(paged); Wheel.next:SetShown(paged)
    Wheel.frame.title:SetText(Wheel.group and Wheel.group.label or Wheel.text.TYPES)
    local back = Wheel.group and #Wheel.groups > 1
    Wheel.hub.text:SetText(back and ("‹ " .. Wheel.text.BACK) or "×")
    Wheel.hub:SetSize(back and 54 or 22, 24)
    Wheel.hub:ClearAllPoints()
    Wheel.hub:SetPoint(back and "TOPLEFT" or "TOPRIGHT", back and 6 or -6, -3)
    Wheel.frame.title:ClearAllPoints(); Wheel.frame.title:SetPoint("TOPLEFT", back and 64 or 12, -10)
    Wheel.frame.title:SetWidth(Wheel.size - (back and 76 or 44))
    Wheel.frame.pageText:SetText(string.format(Wheel.text.RANGE, first, first + count - 1, #source))
    Wheel.frame.pageText:SetShown(paged)
    if Wheel.hover and (type(Wheel.hover.entry) == "table" or type(Wheel.hover.group) == "table") then
        if Wheel.hover:IsShown() then Wheel.Describe(Wheel.hover) else Wheel.hover, Wheel.closeIn = nil, Wheel.delay end
    elseif Wheel.hover and not Wheel.hover:IsShown() then
        Wheel.hover, Wheel.closeIn = nil, Wheel.delay
    end
end

function Wheel.Open(owner)
    local canvas = Canvas()
    if not canvas or not owner.entries or #owner.entries < 2 then return end
    if Wheel.owner == owner then Wheel.Stay(owner); return end
    Wheel.Close()
    Wheel.Build(canvas)
    Wheel.owner, Wheel.all, Wheel.page = owner, PinTargets(owner.top, owner.entries), 1
    Wheel.groups = Wheel.Groups(Wheel.all)
    Wheel.group = #Wheel.groups == 1 and Wheel.groups[1] or nil
    Wheel.entries = Wheel.group and Wheel.group.entries or Wheel.all
    Wheel.mapID = WorldMapFrame:GetMapID()
    Wheel.frame:SetFrameLevel(owner:GetFrameLevel() + 10)
    Wheel.Stay(owner); owner:SetAlpha(1)
    Wheel.Draw(); Wheel.frame:Show(); Wheel.Summary(owner)
end

local function GetPin(i, canvas)
    local pin = pins[i]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, canvas)
    pin.skaldPin = true
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
    ns.ThemeText(pin.count, 1, 1, 1)
    pin.star = pin:CreateTexture(nil, "OVERLAY", nil, 2)
    pin.star:SetSize(12, 12)
    pin.star:SetPoint("TOPRIGHT", pin, "TOPRIGHT", 4, 4)
    pin.star:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_fav")
    pin.star:Hide()
    -- A click opens the page whose picture the marker shows (else the newest), and puts the map away.
    pin:SetScript("OnMouseUp", Wheel.ClickPin)

    -- Faint markers let the game's own show through; the one under the mouse is solid.
    pin:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        if Wheel.dismissed == self then return end
        if self.entries and #self.entries > 1 then Wheel.Open(self) else Wheel.Close(); self:SetAlpha(1); ShowTooltip(self) end
    end)
    pin:SetScript("OnLeave", function(self)
        if Wheel.dismissed == self then Wheel.dismissed = nil end
        if Wheel.owner == self then Wheel.Leave(self) else self:SetAlpha(PinAlpha()); Wheel.HideTip(self) end
    end)

    pins[i] = pin
    return pin
end

local function HideAll()
    Wheel.dismissed = nil
    Wheel.Close()
    for i = 1, #pins do pins[i]:Hide() end
end

-- Pages that would overlap on screen share one marker, which wears the rarity
-- and symbol of its most notable page (rarer first, then newer).
local function Cluster(entries, mapID, w, h, filter, size)
    size = size or PIN_SIZE   -- how big a marker looks in canvas units (smaller than PIN_SIZE when OpenMap has zoomed in)
    local clusters, grid = {}, {}
    local radius2 = size * size
    for _, e in ipairs(entries) do
        if e.m == mapID and e.x and e.y and filter(e) then
            local px, py = e.x * w, e.y * h
            local cx, cy = math.floor(px / size), math.floor(py / size)
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
local function CollectPins(entries, mapID, w, h, filter, size)
    local pins = Cluster(entries, mapID, w, h, filter, size)
    for _, group in ipairs(ZoneSummaries(entries, mapID, filter)) do
        pins[#pins + 1] = group
    end
    return pins
end

local function PinLevel(canvas)
    local base = canvas:GetFrameLevel()
    local lowest, layers = nil, {}
    for _, child in ipairs({ canvas:GetChildren() }) do
        if not rawget(child, "skaldPin") and child:IsShown() then
            local w = child:GetWidth()
            local lv = child:GetFrameLevel()
            if w and w >= 120 then
                layers[#layers + 1] = lv   -- a layer as wide as the map (the picture, the explored overlay, a pin container)
            elseif w and w > 0 and child:IsMouseEnabled() then
                if not lowest or lv < lowest then lowest = lv end   -- a marker of the game
            end
        end
    end
    -- A marker has to be above the layers of the map, or it is under the picture: the mouse finds it (the tooltip shows) and the
    -- eye does not. The layers above the game's own small pins (a long line of another addon) are not a reason to rise over those.
    local floor = base + 150   -- never down among the terrain layers
    local api = _G.OpenMapAPI
    if api and type(api.ArtTopLevel) == "function" then   -- the stitched art of OpenMap reaches up to a level of its own
        local okArt, art = pcall(api.ArtTopLevel)
        if okArt and type(art) == "number" then floor = math.max(floor, art + 1) end
    end
    for _, lv in ipairs(layers) do
        if not lowest or lv <= lowest then floor = math.max(floor, lv + 1) end
    end
    if lowest then return math.max(floor, lowest - 1) end   -- just under the game's pins, so that they stay the ones clicked
    return math.max(floor, base + 600)
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

    -- Just below the lowest of the map's own pins (quests, flight masters, the player's arrow): where a marker
    -- of the game and one of the diary meet, the game's is the one that is clicked, and the diary's stays
    -- visible around it. With none of the game's pins to be seen, well above the terrain.
    local level = PinLevel(canvas)
    local scale = PinScale()
    lastScale = scale
    local n = 0
    for _, c in ipairs(CollectPins(SkaldAPI.GetEntries(), mapID, w, h, CurrentFilter(), PIN_SIZE * scale)) do
        n = n + 1
        local pin = GetPin(n, canvas)
        pin.entries = c.entries
        pin.title = c.title
        if pin.cycleTop ~= c.top then pin.cycleTop, pin.nextPage = c.top, 1 end
        pin.top = c.top
        pin.medallion:SetTexture(TEXTURES .. "pin_med" .. math.max(0, math.min(5, TierOf(c.top))))
        pin.glyph:SetTexture(PinGlyph(c.top))
        pin.count:SetText(#c.entries > 1 and #c.entries or "")
        pin.star:SetShown(c.fav and true or false)
        pin:SetFrameLevel(level)
        pin:SetAlpha(PinAlpha())
        pin.nx, pin.ny = c.x, c.y
        PlacePin(pin, canvas, w, h, scale)
        pin:Show()
    end
    activePins = n
end

-- The zoom of OpenMap moves every frame it is dragged: the markers keep their size on the screen at once, and are grouped again
-- (a new grouping costs a few tens of milliseconds with a big diary) only when the zoom has settled.
local settle = 0
local function Rescale()
    Wheel.Close()
    if lastScale == 1 and not Stitched() then return end
    local canvas = Canvas()
    if not canvas or activePins == 0 then return end
    local w, h = canvas:GetSize()
    if not w or w == 0 then return end
    local scale = PinScale()
    for i = 1, activePins do
        local pin = pins[i]
        if pin and pin.nx then PlacePin(pin, canvas, w, h, scale) end
    end
    if C_Timer and C_Timer.After then
        settle = settle + 1
        local mine = settle
        C_Timer.After(0.3, function()
            if mine == settle and lastScale and math.abs(PinScale() - lastScale) > lastScale * 0.1 then Refresh() end
        end)
    end
end


-- The map settles a moment after it opens or changes zone; look once now and
-- once shortly after.
local function RefreshSoon()
    Refresh()
    if C_Timer and C_Timer.After then C_Timer.After(0.2, Refresh); C_Timer.After(1, Refresh) end   -- the game's quest markers can arrive late
end

-- A star marked or unmarked in the book changes the pins at once.
SkaldAPI.favHook = Refresh
-- (kept reachable for the regression scenarios)
SkaldAPI.AtlasPure = { Wheel = Wheel, Pins = function() return pins, activePins end, Refresh = Refresh, Rescale = Rescale, PinScale = PinScale, MakeFilter = MakeFilter, Cluster = Cluster, PinLevel = PinLevel, PinGlyph = PinGlyph, PinTargets = PinTargets, PinOrder = PinOrder }

-- The world map frame can load on demand, so hook it as soon as it exists.
local hooked = false
local debugArmed, debugLines, DebugLines   -- /skatlas debug with the map shut: it looks when the map opens and tells when it is shut again
local function FlushDebug()
    if debugArmed and debugLines then
        for _, line in ipairs(debugLines) do Say(line) end
    end
    debugArmed, debugLines = false, nil
end
local function InstallHooks()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", function()
        RefreshSoon()
        if debugArmed and C_Timer and C_Timer.After then
            C_Timer.After(2, function()
                if debugArmed and WorldMapFrame:IsShown() and DebugLines then debugLines = DebugLines() end
            end)
        end
    end)
    WorldMapFrame:HookScript("OnHide", function() HideAll(); FlushDebug() end)
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", RefreshSoon)
    end
    if WorldMapFrame.OnCanvasScaleChanged then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function() pcall(Rescale) end)
    end
end

-- OpenMap (an addon that stitches the world map into one) has an interface of its own: a switch in its menu, and a word when
-- it changes between its map and the game's. Everything here is optional and guarded: without OpenMap nothing is registered.
local openMapDone = false
local openMapOwner = {}
local function InstallOpenMap()
    if openMapDone then return end
    local api = _G.OpenMapAPI
    if not api then return end
    openMapDone = true
    if type(api.RegisterMenuToggle) == "function" then
        pcall(api.RegisterMenuToggle, "Skald", { id = "pins", label = UI.SHOW or "Skald", icon = "Interface\\AddOns\\Skald\\icon",
            get = function() return not SkaldAtlasDB.hidden end,
            set = function(on) SkaldAtlasDB.hidden = not on; Refresh() end })
    end
    if type(api.RegisterCallback) == "function" then
        pcall(api.RegisterCallback, openMapOwner, "OpenMap_StitchedChanged", function() RefreshSoon() end)
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
    if SkaldAPI.PlateGroup then SkaldAPI.PlateGroup(panel, 0, -110, 342, 26) end
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
        ns.ThemeFill(ring, 0.431, 0.118, 0.102, 1)
        ring:SetPoint("CENTER", 0, 0)
        local inner = SkaldAPI.MakeDisc(b, "BACKGROUND", 44, 0.93, 0.87, 0.72, 1)
        ns.ThemeFill(inner, 0.93, 0.87, 0.72, 1, "paper")
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
    if SkaldAPI.PlateGroup then SkaldAPI.PlateGroup(panel, 0, -258, 342, 26) end
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
    -- two columns (seven and six) instead of one long list
    local COL_W, PER_COL = 172, 7
    for i, kind in ipairs(KIND_ORDER) do
        local col, row = math.floor((i - 1) / PER_COL), (i - 1) % PER_COL
        Check(UI.KIND[kind], RIGHT_X + col * COL_W, -56 - row * 40,
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
    -- the card: a tinted parchment with a thin brass-brown edge
    local card = CreateFrame("Frame", nil, panel)
    card:SetPoint("TOPLEFT", -6, -338)
    card:SetSize(354, 108)
    local fillT = card:CreateTexture(nil, "BACKGROUND")
    fillT:SetAllPoints()
    fillT:SetColorTexture(0.80, 0.68, 0.45, 0.35)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
                         { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
        local edge = card:CreateTexture(nil, "BORDER")
        edge:SetPoint(e[1]); edge:SetPoint(e[2])
        if e[3] then edge:SetWidth(e[3]) else edge:SetHeight(e[4]) end
        edge:SetColorTexture(0.55, 0.38, 0.16, 0.9)
    end
    SkaldAPI.SectionLabel(panel, UI.REGION, 4, -342)
    local function Line(y, font, color)
        local fs = panel:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", 4, y)
        fs:SetWidth(334)
        fs:SetJustifyH("LEFT")
        ns.ThemeText(fs, color[1], color[2], color[3])
        return fs
    end
    local regionName = Line(-362, "SkaldBody", head)
    local fact1, fact2, fact3 = Line(-382, "SkaldBody", body), Line(-398, "SkaldBody", body), Line(-414, "SkaldBody", body)
    local status = Line(-430, "SkaldSmall", muted)
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
        elseif name == "OpenMap" and not dormant and SkaldAPI then
            InstallOpenMap()
        end
    elseif event == "PLAYER_LOGIN" then
        SkaldAtlasDB = SkaldAtlasDB or {}
        if not SkaldAPI or SeparateAtlasRunning() then
            dormant = true
            return
        end
        InstallHooks()
        InstallOpenMap()
        if SkaldAPI.AddTab then
            SkaldAPI.AddTab("map", UI.TAB, BuildMapTab)
        end
    end
end)

DebugLines = function()
    local out = {}
    local function Say(line) out[#out + 1] = line end
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
    Say(string.format("OpenMap=%s stitched=%s canvasScale=%s pinScale=%.3f lastScale=%.3f firstPinScale=%s",
        tostring(_G.OpenMapAPI ~= nil), tostring(Stitched()), tostring(WorldMapFrame and WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()),
        PinScale(), lastScale, tostring(pins[1] and pins[1]:GetScale())))
    -- where the markers sit among the frames of the map (a marker that is drawn but not seen is under something)
    pcall(function()
        if not canvas then return end
        local n, lo, hi = 0, nil, nil
        for _, child in ipairs({ canvas:GetChildren() }) do
            n = n + 1
            local lv = child:GetFrameLevel()
            lo = lo and math.min(lo, lv) or lv
            hi = hi and math.max(hi, lv) or lv
        end
        Say(string.format("canvas: level=%s strata=%s children=%d (levels %s..%s) markerLevel=%s",
            tostring(canvas:GetFrameLevel()), tostring(canvas:GetFrameStrata()), n, tostring(lo), tostring(hi), tostring(PinLevel(canvas))))
        for i, child in ipairs({ canvas:GetChildren() }) do
            if i > 12 then break end
            Say(string.format("  child %d: level=%s width=%.0f shown=%s mouse=%s%s", i, tostring(child:GetFrameLevel()), child:GetWidth() or 0,
                tostring(child:IsShown()), tostring(child:IsMouseEnabled()), rawget(child, "skaldPin") and " (a Skald marker)" or ""))
        end
        local p = pins[1]
        if p then
            local point, _, _, x, y = p:GetPoint()
            Say(string.format("marker 1: shown=%s visible=%s alpha=%.2f size=%.0fx%.0f level=%s strata=%s onCanvas=%s at=%s %.0f,%.0f",
                tostring(p:IsShown()), tostring(p:IsVisible()), p:GetEffectiveAlpha(), p:GetWidth(), p:GetHeight(),
                tostring(p:GetFrameLevel()), tostring(p:GetFrameStrata()), tostring(p:GetParent() == canvas), tostring(point), x or 0, y or 0))
            Say("medallion=" .. tostring(p.medallion:GetTexture()) .. " glyph=" .. tostring(p.glyph:GetTexture()))
        end
    end)
    return out
end
local function Debug()
    for _, line in ipairs(DebugLines()) do Say(line) end
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
        if WorldMapFrame and WorldMapFrame:IsShown() then
            Refresh()
            Debug()
        else
            debugArmed, debugLines = true, nil
            Say("debug armed: open the world map, wait three seconds and shut it; the lines are written here when it is shut.")
        end
        return
    end
    SkaldAtlasDB.hidden = not SkaldAtlasDB.hidden
    Say(SkaldAtlasDB.hidden and L.OFF or L.ON)
    Refresh()
end
