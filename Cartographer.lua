-- Skald: the Cartographer tab, a collection of the hand-drawn maps. Each land and city that has a map of our own
-- shows its drawing in colour when the diary has seen the character stand there, and faded when not yet. It reads
-- what the diary already keeps (SkaldCharDB.visitedMaps, written by the visit of a zone) and writes nothing.
--
-- Loaded after ZoneCard.lua (its table of maps, ZC.ART) and Goals.lua (the pattern of a tab with a pager).
local _, ns = ...

local UI_TEXT = {
    enUS = {
        TAB = "Cartographer", TITLE = "Cartographer", CHARTED = "%d of %d lands charted", OF = "%d of %d",
        WALKED = "You have walked here. Click for more.", NOT_YET = "Not yet walked.", EMPTY = "No maps yet.",
        BACK = "Back to the maps", HERE = "Pages written here", NONE_HERE = "No pages were written here yet.", DATE = "%m/%d/%Y",
    },
    ptBR = {
        TAB = "Cartógrafo", TITLE = "Cartógrafo", CHARTED = "%d de %d terras mapeadas", OF = "%d de %d",
        WALKED = "Você já andou por aqui. Clique para ver mais.", NOT_YET = "Ainda não percorrida.", EMPTY = "Ainda sem mapas.",
        BACK = "Voltar aos mapas", HERE = "Páginas escritas aqui", NONE_HERE = "Nenhuma página foi escrita aqui ainda.", DATE = "%d/%m/%Y",
    },
    frFR = {
        TAB = "Cartographe", TITLE = "Cartographe", CHARTED = "%d terres sur %d cartographiées", OF = "%d sur %d",
        WALKED = "Vous avez d\195\169j\195\160 march\195\169 ici. Cliquez pour en savoir plus.", NOT_YET = "Pas encore parcourue.", EMPTY = "Pas encore de cartes.",
        BACK = "Retour aux cartes", HERE = "Pages \195\169crites ici", NONE_HERE = "Aucune page n'a encore \195\169t\195\169 \195\169crite ici.", DATE = "%d/%m/%Y",
    },
}
local UI = UI_TEXT[GetLocale()] or UI_TEXT.enUS

local C = {}
ns.Cartographer = C

C.COLS, C.ROWS = 2, 4                 -- the cells on one page; two pages make a spread
C.PER_PAGE = C.COLS * C.ROWS
C.THUMB_W, C.THUMB_H = 150, 75   -- the frame (map_thumb_frame) leaves 88% of its width free: it is drawn 1/0.88 larger
C.CELL_W, C.CELL_H = 170, 96   -- four rows from y 46 end at 430, inside the 440 of the panel and above the page corner (the curl)

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

-- The pages of the diary written in a land (the newest first, at most `limit`), and how many there are in all.
function C.Pages(mapID, limit)   -- limit: how many to keep (default 700)
    local db = SkaldCharDB
    local entries = db and db.entries
    local zc = ns.ZoneCard
    local out, total, seen = {}, 0, {}
    if not entries then return out, 0 end
    for i = #entries, 1, -1 do
        local e = entries[i]
        local id = e and ((type(e.m) == "number" and e.m) or e.zm)
        if id then
            local zone = id
            if id ~= mapID then
                zone = seen[id]
                if zone == nil then zone = (zc and zc.ZoneMap(id)) or false; seen[id] = zone end
            end
            if zone == mapID then
                total = total + 1
                if #out < (limit or 700) then out[#out + 1] = e end
            end
        end
    end
    return out, total
end

local function BuildTab(panel)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\"

    SkaldAPI.PageHeading(panel, UI.TITLE, 0)
    local seal = panel:CreateTexture(nil, "ARTWORK")
    seal:SetSize(34, 34)
    seal:SetPoint("TOPLEFT", panel, "TOPLEFT", 44, -2)
    seal:SetTexture(TEX .. "map_title_seal")
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
            cell:SetPoint("TOPLEFT", x0 + col * C.CELL_W, -46 - row * C.CELL_H)
            cell.map = cell:CreateTexture(nil, "ARTWORK")
            cell.map:SetSize(C.THUMB_W, C.THUMB_H)
            cell.map:SetPoint("TOP", 0, -2)
            -- the frame of an album over the drawing, and the stamp of the lands walked on its corner
            cell.frame = cell:CreateTexture(nil, "OVERLAY", nil, 1)
            cell.frame:SetSize(C.THUMB_W / 0.88, C.THUMB_H / 0.88)
            cell.frame:SetPoint("CENTER", cell.map, "CENTER", 0, 0)
            cell.frame:SetTexture(TEX .. "map_thumb_frame")
            cell.stamp = cell:CreateTexture(nil, "OVERLAY", nil, 2)
            cell.stamp:SetSize(32, 32)
            cell.stamp:SetPoint("CENTER", cell.map, "BOTTOMRIGHT", -8, 8)
            cell.stamp:SetTexture(TEX .. "map_stamp")
            cell.stamp:SetAlpha(0.92)
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

    -- The detail of a land you have walked: its card (the map, the quests, the creatures) on the left page, the
    -- pages written there on the right one; the left corner of the book, or this button, goes back to the grid.
    local detail, detailPage = nil, 1
    local card
    -- the same brass plate the other tabs use, at the foot of the left page under the card
    local back = SkaldAPI.MakeButton and SkaldAPI.MakeButton(panel, 130, 28, UI.BACK)
        or CreateFrame("Button", nil, panel)
    back:SetPoint("TOP", panel, "TOPLEFT", CW / 2, -410)
    back:Hide()
    local rows = {}
    for i = 1, 7 do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 50)
        row:SetPoint("TOPLEFT", RIGHT_X, -52 - (i - 1) * 56)
        row.date = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.date:SetPoint("TOPLEFT", 0, -2)
        row.date:SetTextColor(muted[1], muted[2], muted[3])
        row.text = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.text:SetPoint("TOPLEFT", 0, -18)
        row.text:SetWidth(CW)
        row.text:SetJustifyH("LEFT")
        row.text:SetTextColor(body[1], body[2], body[3])
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(0.43, 0.12, 0.10, 0.08)
        row.hover:Hide()
        row:SetScript("OnEnter", function(self) self.hover:Show() end)
        row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.entry and SkaldAPI.OpenEntry then SkaldAPI.OpenEntry(self.entry) end
        end)
        row:Hide()
        rows[i] = row
    end
    local none = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    none:SetPoint("TOPLEFT", RIGHT_X, -70)
    none:SetWidth(CW)
    none:SetJustifyH("CENTER")
    none:SetTextColor(muted[1], muted[2], muted[3])
    none:SetText(UI.NONE_HERE)
    none:Hide()

    local Refresh
    local function Close() detail = nil; if Refresh then Refresh() end end
    back:SetScript("OnClick", Close)
    for _, cell in ipairs(cells) do
        cell:SetScript("OnClick", function(self)
            if self.info and self.walked then detail = self.info; detail.list, detail.total = C.Pages(self.info.id); detailPage = 1; Refresh() end
        end)
    end

    function Refresh()
        local list = C.List()
        local inDetail = detail ~= nil
        back:SetShown(inDetail)
        if card then card:SetShown(inDetail) end
        for _, row in ipairs(rows) do row:Hide() end
        none:Hide()
        if inDetail then
            for _, cell in ipairs(cells) do cell:Hide() end
            empty:Hide()
            if not card and ns.ZoneCard then
                local okCard, built = pcall(ns.ZoneCard.Build, panel, CW)
                if okCard then card = built end
            end
            if card then
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -44)
                pcall(card.Set, card, detail.id)
                card:Show()
            end
            local all, total = detail.list or {}, detail.total or 0
            local pagesOf = math.max(1, math.ceil(#all / #rows))
            detailPage = math.max(1, math.min(detailPage, pagesOf))
            count:SetText(UI.HERE .. " (" .. total .. ")" .. (pagesOf > 1 and ("   " .. string.format(UI.OF, detailPage, pagesOf)) or ""))
            local pages = {}
            for i = 1, #rows do pages[i] = all[(detailPage - 1) * #rows + i] end
            for i, row in ipairs(rows) do
                local e = pages[i]
                if e then
                    row.entry = e
                    row.date:SetText(e.t and date(UI.DATE, e.t) or "")
                    local ok, text = pcall(SkaldAPI.Render, e)
                    text = ok and tostring(text or "") or ""
                    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " ")
                    if #text > 96 then text = text:sub(1, 93) .. "..." end
                    row.text:SetText(text)
                    row:Show()
                end
            end
            none:SetShown(#all == 0)
            return
        end
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
                cell.frame:SetAlpha(walked and 1 or 0.5)
                cell.stamp:SetShown(walked)
                cell.name:SetText(info.name)
                if walked then cell.name:SetTextColor(head[1], head[2], head[3])
                else cell.name:SetTextColor(muted[1], muted[2], muted[3]) end
            end
        end
    end

    local pager = {
        Turn = function(delta)
            if detail then
                local pagesOf = math.max(1, math.ceil(#(detail.list or {}) / 7))
                if delta > 0 then detailPage = math.min(pagesOf, detailPage + 1)
                elseif detailPage > 1 then detailPage = detailPage - 1
                else detail = nil end
                return
            end
            spread = math.max(1, math.min(spreads, spread + delta))
        end,
        CanPrev = function() return detail ~= nil or spread > 1 end,
        CanNext = function() if detail then return detailPage < math.ceil(#(detail.list or {}) / 7) end return spread < spreads end,
    }
    C.refresh = Refresh
    C.pager = pager
    return Refresh, pager
end

SkaldAPI.AddTab("cartographer", UI.TAB, BuildTab)
