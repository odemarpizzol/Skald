-- Skald: the Cartographer tab, a collection of the hand-drawn maps. Each land and city that has a map of our own
-- shows its drawing in colour when the diary has seen the character stand there, and faded when not yet. It reads
-- what the diary already keeps (SkaldCharDB.visitedMaps, written by the visit of a zone) and writes nothing.
--
-- Loaded after ZoneCard.lua (its table of maps, ZC.ART) and Goals.lua (the pattern of a tab with a pager).
local _, ns = ...

local UI_TEXT = {
    enUS = {
        TAB = "Cartographer", TITLE = "Cartographer", CHARTED = "%d of %d lands charted", OF = "%d of %d",
        WALKED = "You have walked here.", NOT_YET = "Not yet walked.", EMPTY = "No maps yet.",
    },
    ptBR = {
        TAB = "Cartógrafo", TITLE = "Cartógrafo", CHARTED = "%d de %d terras mapeadas", OF = "%d de %d",
        WALKED = "Você já andou por aqui.", NOT_YET = "Ainda não percorrida.", EMPTY = "Ainda sem mapas.",
    },
    frFR = {
        TAB = "Cartographe", TITLE = "Cartographe", CHARTED = "%d terres sur %d cartographiées", OF = "%d sur %d",
        WALKED = "Vous avez d\195\169j\195\160 march\195\169 ici.", NOT_YET = "Pas encore parcourue.", EMPTY = "Pas encore de cartes.",
    },
}
local UI = UI_TEXT[GetLocale()] or UI_TEXT.enUS

local C = {}
ns.Cartographer = C

C.COLS, C.ROWS = 2, 4                 -- the cells on one page; two pages make a spread
C.PER_PAGE = C.COLS * C.ROWS
C.THUMB_W, C.THUMB_H = 160, 80
C.CELL_W, C.CELL_H = 170, 106

-- The maps of this client with a drawing: the map must exist in the game (a Burning Crusade land does not on an
-- older client), sorted by the name the game gives it, accents and case folded so the order is natural.
local function Fold(s)
    s = string.lower(tostring(s or ""))
    local map = { ["\195\161"] = "a", ["\195\160"] = "a", ["\195\162"] = "a", ["\195\163"] = "a", ["\195\164"] = "a",
        ["\195\169"] = "e", ["\195\168"] = "e", ["\195\170"] = "e", ["\195\173"] = "i", ["\195\174"] = "i",
        ["\195\179"] = "o", ["\195\180"] = "o", ["\195\181"] = "o", ["\195\186"] = "u", ["\195\187"] = "u", ["\195\167"] = "c" }
    return (s:gsub("\195[\128-\191]", function(c) return map[c] or c end))
end

function C.List()
    local zc = ns.ZoneCard
    local art = zc and zc.ART or {}
    local canAsk = C_Map and C_Map.GetMapInfo
    local list = {}
    for id, name in pairs(art) do
        local info = canAsk and C_Map.GetMapInfo(id)
        if info or not canAsk then
            local label = (info and info.name) or name
            list[#list + 1] = { id = id, art = name, name = label, key = Fold(label) }
        end
    end
    table.sort(list, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.id < b.id end)
    return list
end

function C.Walked(id)
    local db = SkaldCharDB
    local maps = db and db.visitedMaps
    return maps and maps["map:" .. tostring(id)] and true or false
end

-- How many of the list the diary has seen the character in.
function C.Count(list)
    local n = 0
    for _, m in ipairs(list) do if C.Walked(m.id) then n = n + 1 end end
    return n
end

local function BuildTab(panel)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\"

    SkaldAPI.PageHeading(panel, UI.TITLE, 0)
    local count = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    count:SetPoint("TOPLEFT", RIGHT_X, -12)
    count:SetWidth(CW)
    count:SetJustifyH("CENTER")
    count:SetTextColor(muted[1], muted[2], muted[3])
    local empty = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    empty:SetPoint("TOP", panel, "TOP", 0, -140)
    empty:SetTextColor(muted[1], muted[2], muted[3])
    empty:SetText(UI.EMPTY)
    empty:Hide()

    local cells = {}
    local spread, spreads = 1, 1
    for side = 0, 1 do
        local x0 = side == 0 and 0 or RIGHT_X
        for i = 1, C.PER_PAGE do
            local col, row = (i - 1) % C.COLS, math.floor((i - 1) / C.COLS)
            local cell = CreateFrame("Button", nil, panel)
            cell:SetSize(C.CELL_W, C.CELL_H)
            cell:SetPoint("TOPLEFT", x0 + col * C.CELL_W, -52 - row * C.CELL_H)
            cell.map = cell:CreateTexture(nil, "ARTWORK")
            cell.map:SetSize(C.THUMB_W, C.THUMB_H)
            cell.map:SetPoint("TOP", 0, -2)
            cell.name = cell:CreateFontString(nil, "OVERLAY", "SkaldSmall")
            cell.name:SetPoint("TOP", cell.map, "BOTTOM", 0, -2)
            cell.name:SetWidth(C.CELL_W - 6)
            cell.name:SetJustifyH("CENTER")
            cell:SetScript("OnEnter", function(self)
                if not self.info then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.info.name, 1, 0.82, 0)
                GameTooltip:AddLine(self.walked and UI.WALKED or UI.NOT_YET, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cells[#cells + 1] = cell
        end
    end

    local function Refresh()
        local list = C.List()
        local per = C.PER_PAGE * 2
        spreads = math.max(1, math.ceil(#list / per))
        spread = math.max(1, math.min(spread, spreads))
        count:SetText(string.format(UI.CHARTED, C.Count(list), #list))
        empty:SetShown(#list == 0)
        for i, cell in ipairs(cells) do
            local info = list[(spread - 1) * per + i]
            cell.info = info
            if not info then
                cell:Hide()
            else
                local walked = C.Walked(info.id)
                cell.walked = walked
                cell:Show()
                cell.map:SetTexture(TEX .. info.art)
                pcall(cell.map.SetDesaturated, cell.map, not walked)
                cell.map:SetAlpha(walked and 0.95 or 0.38)
                cell.name:SetText(info.name)
                if walked then cell.name:SetTextColor(head[1], head[2], head[3])
                else cell.name:SetTextColor(muted[1], muted[2], muted[3]) end
            end
        end
    end

    local pager = {
        Turn = function(delta) spread = math.max(1, math.min(spreads, spread + delta)) end,
        CanPrev = function() return spread > 1 end,
        CanNext = function() return spread < spreads end,
    }
    C.refresh = Refresh
    return Refresh, pager
end

SkaldAPI.AddTab("cartographer", UI.TAB, BuildTab)
