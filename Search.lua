-- Skald: search in the book. A tab with a box to type in, a few filters (kind of page, favourites, how far back) and
-- the pages found, newest first; a click opens the page in the book.
--
-- Loaded after Backup.lua. The matching (`Search.Run`) is a plain function over the pages and has no window in it, so
-- it can be tested alone. It searches the text each page is told with now (in the language of the game, as the book
-- shows it), the place, the giver, the companions and the note of a favourite; accents and capitals do not matter.
local _, ns = ...

local L = ns.LOCALES[GetLocale()] or ns.LOCALES.enUS
local Search = {}
ns.Search = Search

Search.MAX = 300       -- pages listed at most; the count says how many there are
Search.ROWS = 7        -- rows on the right page

-- The kinds of page, grouped as the filter offers them (the first group is everything; day summaries and the book's
-- own pages are found only there).
Search.GROUPS = {
    { key = "all" },
    { key = "quests",  kinds = { quest = true } },
    { key = "battles", kinds = { boss = true, dungeon = true, death = true, revive = true } },
    { key = "loot",    kinds = { loot = true } },
    { key = "company", kinds = { party = true, reunion = true, guild = true, guildleave = true, tame = true } },
    { key = "journeys", kinds = { zone = true, flight = true, hearth = true, home = true, mount = true } },
    { key = "deeds",   kinds = { level = true, milestone = true, achievement = true, skill = true, profession = true, rep = true, goal = true, mark = true } },
    { key = "notes",   kinds = { note = true } },
}
Search.DAYS = { 0, 7, 30, 365 }   -- how far back, in days (0: any time)

-- Capitals and accents folded away, so "Ironforge", "ironforge" and "Quête" / "quete" meet. The accented letters
-- of Latin text are the two bytes 195 then 128..191.
local FOLD = {}
do
    local function Set(letter, from, to) for b = from, to do FOLD[b] = letter end end
    Set("a", 128, 133); Set("c", 135, 135); Set("e", 136, 139); Set("i", 140, 143); Set("n", 145, 145)
    Set("o", 146, 150); Set("u", 153, 156); Set("y", 157, 157)
    Set("a", 160, 165); Set("c", 167, 167); Set("e", 168, 171); Set("i", 172, 175); Set("n", 177, 177)
    Set("o", 178, 182); Set("u", 185, 188); Set("y", 189, 189); Set("y", 191, 191)
end
local function Fold(s)
    s = tostring(s or "")
    s = s:gsub("\195([\128-\191])", function(c) return FOLD[c:byte()] end)
    return (s:lower())
end
Search.Fold = Fold

local function Plain(s)
    s = tostring(s or "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return s
end

-- The words of a query: lowercase, folded, split on spaces. A page must hold all of them.
Search.Terms = function(query)
    local terms = {}
    for word in Fold(query):gmatch("%S+") do terms[#terms + 1] = word end
    return terms
end

-- What a page says, as plain text: the story, the place, who gave it, who came along, the note of a favourite.
-- Told again when the book's pages change (ns.layoutRev) or the language does.
local cache = setmetatable({}, { __mode = "k" })
local function Text(e)
    local stamp = tostring(ns.layoutRev or 0) .. GetLocale()
    local hit = cache[e]
    if hit and hit.stamp == stamp then return hit.text end
    local parts = {}
    local ok, body = pcall(SkaldAPI.Render, e)
    parts[#parts + 1] = ok and Plain(body) or ""
    local okPlace, place = pcall(ns.PlaceName, e)
    if okPlace and place then parts[#parts + 1] = Plain(place) end
    if type(e.npc) == "string" then parts[#parts + 1] = e.npc end
    if type(e.favNote) == "string" then parts[#parts + 1] = e.favNote end
    if type(e.with) == "table" then
        for _, name in ipairs(e.with) do if type(name) == "string" then parts[#parts + 1] = name end end
    end
    local text = Fold(table.concat(parts, " "))
    cache[e] = { stamp = stamp, text = text }
    return text
end
Search.Text = Text

-- The pages that fit: `opts.group` (a key of GROUPS), `opts.favs` (only favourites), `opts.days` (how far back; 0 or
-- nil for any time) and `opts.now`. Returns the pages newest first (at most Search.MAX) and how many fit in all.
Search.Run = function(entries, query, opts)
    opts = opts or {}
    local terms = Search.Terms(query)
    local kinds
    for _, g in ipairs(Search.GROUPS) do if g.key == opts.group then kinds = g.kinds end end
    local since = (opts.days and opts.days > 0) and ((opts.now or time()) - opts.days * 86400) or nil
    local found, total = {}, 0
    for i = #entries, 1, -1 do
        local e = entries[i]
        local fits = type(e) == "table"
        if fits and kinds and not kinds[e.kind] then fits = false end
        if fits and opts.favs and not e.fav then fits = false end
        if fits and since and (type(e.t) ~= "number" or e.t < since) then fits = false end
        if fits and #terms > 0 then
            local text = Text(e)
            for _, word in ipairs(terms) do
                if not text:find(word, 1, true) then fits = false; break end
            end
        end
        if fits then
            total = total + 1
            if #found < Search.MAX then found[#found + 1] = e end
        end
    end
    return found, total
end

-- Where the words of a query lie in a text, as ranges of bytes of the text as it is written. The text is folded one
-- letter at a time, so the places are those of the original, accents and all. Overlapping places are joined.
Search.Ranges = function(text, terms)
    local flat, from, to, n = {}, {}, {}, 0
    for start, ch in text:gmatch("()([\1-\127\194-\244][\128-\191]*)") do
        local folded = Fold(ch)
        for k = 1, #folded do
            n = n + 1
            flat[n] = folded:sub(k, k)
            from[n], to[n] = start, start + #ch - 1
        end
    end
    local line = table.concat(flat)
    local marks = {}
    for _, term in ipairs(terms) do
        local init = 1
        while term ~= "" do
            local a, b = line:find(term, init, true)
            if not a then break end
            marks[#marks + 1] = { from[a], to[b] }
            init = b + 1
        end
    end
    table.sort(marks, function(x, y) return x[1] < y[1] end)
    local joined = {}
    for _, m in ipairs(marks) do
        local last = joined[#joined]
        if last and m[1] <= last[2] + 1 then last[2] = math.max(last[2], m[2]) else joined[#joined + 1] = { m[1], m[2] } end
    end
    return joined
end

-- A text for a row of the list: at most `limit` letters (cut at a space, with "..."), the cut chosen so the first
-- word found shows, and the words found painted in `color` ("ffRRGGBB"). A bar in the text is doubled, as the game
-- reads it as the start of a code.
Search.Highlight = function(text, terms, color, limit)
    text = tostring(text or "")
    limit = limit or 120
    local marks = Search.Ranges(text, terms)
    local a, b = 1, #text
    local cutStart, cutEnd = false, false
    if #text > limit then
        if marks[1] and marks[1][2] > limit * 0.7 then
            a = math.max(1, marks[1][1] - 30)
            while a < #text and text:byte(a) >= 128 and text:byte(a) <= 191 do a = a + 1 end
            local sp = text:find(" ", a, true)
            if sp and sp - a < 15 then a = sp + 1 end
            cutStart = a > 1
        end
        b = a + limit - 1
        if b >= #text then
            b = #text
        else
            while b > a and text:byte(b + 1) >= 128 and text:byte(b + 1) <= 191 do b = b - 1 end
            local sp = text:sub(a, b):match(".*() ")
            if sp and sp > limit * 0.6 then b = a + sp - 2 end
            cutEnd = true
        end
    end
    local function Plain(s) return (s:gsub("|", "||")) end
    local out, at = {}, a
    for _, m in ipairs(marks) do
        if m[2] >= a and m[1] <= b then
            local s, e = math.max(m[1], a), math.min(m[2], b)
            if s > at then out[#out + 1] = Plain(text:sub(at, s - 1)) end
            out[#out + 1] = "|c" .. color .. Plain(text:sub(s, e)) .. "|r"
            at = e + 1
        end
    end
    if at <= b then out[#out + 1] = Plain(text:sub(at, b)) end
    return (cutStart and "..." or "") .. table.concat(out) .. (cutEnd and "..." or "")
end

-- The tab. ----------------------------------------------------------------------------------------------------
local FOUND = "ff9c1f12"   -- the ink of the words found: a wine red that reads on the parchment

local function BuildTab(panel)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local FRAME = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

    SkaldAPI.PageHeading(panel, L.SEARCH_TAB, 0)
    local rightTitle = SkaldAPI.PageHeading(panel, L.SEARCH_RESULTS, RIGHT_X)
    panel.rightTitle = rightTitle   -- for the tests

    local state = { query = "", group = 1, favs = false, whenIx = 1, page = 1 }
    local results, total = {}, 0
    local refresh
    local selects = {}
    local function CloseSelects(except)
        for _, s in ipairs(selects) do if s ~= except and s.list:IsShown() then s.list:Hide() end end
    end

    -- the box, with a faint word in it while it is empty
    local edit = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    edit:SetSize(CW, 28)
    edit:SetPoint("TOPLEFT", 0, -52)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(60)
    edit:SetFontObject("SkaldBody")
    edit:SetTextColor(body[1], body[2], body[3])
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetBackdrop(FRAME)
    edit:SetBackdropColor(0.62, 0.48, 0.28, 0.32)   -- a darker scrap of parchment, as in the settings
    edit:SetBackdropBorderColor(0.45, 0.30, 0.14, 1)
    local placeholder = edit:CreateFontString(nil, "OVERLAY", "SkaldBody")
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetTextColor(muted[1], muted[2], muted[3])
    placeholder:SetAlpha(0.7)
    placeholder:SetText(L.SEARCH_TYPE_HERE)
    local focused = false
    local function ShowPlaceholder()
        if (edit:GetText() or "") == "" and not focused then placeholder:Show() else placeholder:Hide() end
    end
    edit:SetScript("OnEditFocusGained", function() focused = true; CloseSelects(); ShowPlaceholder() end)
    edit:SetScript("OnEditFocusLost", function() focused = false; ShowPlaceholder() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- a word is looked for a moment after the last key, not at every key
    local token = 0
    edit:SetScript("OnTextChanged", function(self)
        state.query = self:GetText() or ""
        state.page = 1
        ShowPlaceholder()
        token = token + 1
        local mine = token
        C_Timer.After(0.25, function() if mine == token and refresh then refresh() end end)
    end)
    ShowPlaceholder()
    panel.searchBox, panel.placeholder = edit, placeholder   -- for the tests

    -- a choice: a plate that shows what is chosen and opens a short list of everything that can be
    local function MakeSelect(y, names, pick)
        local s = { names = names, items = {} }
        s.button = SkaldAPI.MakeButton(panel, CW, 26, "")
        s.button:SetPoint("TOPLEFT", 0, y)
        s.list = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        s.list:SetFrameLevel(panel:GetFrameLevel() + 20)
        s.list:SetPoint("TOPLEFT", s.button, "BOTTOMLEFT", 0, -2)
        s.list:SetSize(CW, #names * 26 + 6)
        s.list:SetBackdrop(FRAME)
        s.list:SetBackdropColor(0.80, 0.68, 0.45, 1)    -- opaque: what lies under it must not show through
        s.list:SetBackdropBorderColor(0.45, 0.30, 0.14, 1)
        s.list:Hide()
        for i, name in ipairs(names) do
            local item = SkaldAPI.MakeButton(s.list, CW - 6, 24, name)
            item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 26)
            item:SetScript("OnClick", function() s.list:Hide(); state.page = 1; pick(i); refresh() end)
            s.items[i] = item
        end
        s.button:SetScript("OnClick", function()
            edit:ClearFocus()
            CloseSelects(s)
            if s.list:IsShown() then s.list:Hide() else s.list:Show() end
        end)
        selects[#selects + 1] = s
        return s
    end
    local kindSelect = MakeSelect(-92, L.SEARCH_KINDS, function(i) state.group = i end)
    local whenSelect = MakeSelect(-124, L.SEARCH_WHENS, function(i) state.whenIx = i end)
    panel:HookScript("OnHide", function() CloseSelects() end)
    local favCheck = SkaldAPI.MakeCheck(panel, L.SEARCH_FAVS, function() return state.favs end,
        function(on) state.favs = on and true or false; state.page = 1; refresh() end, nil, nil, CW)
    favCheck:SetPoint("TOPLEFT", 0, -158)
    -- for the tests
    panel.kindButton, panel.whenButton, panel.favButton = kindSelect.button, whenSelect.button, favCheck
    panel.kindList, panel.whenList, panel.kindItems, panel.whenItems = kindSelect.list, whenSelect.list, kindSelect.items, whenSelect.items

    local hint = SkaldAPI.NoteText(panel, 0, -200)
    hint:SetText(L.SEARCH_HINT)
    -- the count sits at the foot of the page, under what the box and the choices leave empty
    local count = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    count:SetPoint("TOPLEFT", 0, -430)
    count:SetWidth(CW)
    count:SetJustifyH("CENTER")
    count:SetTextColor(head[1], head[2], head[3])
    local capNote = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    capNote:SetPoint("TOPLEFT", 0, -452)
    capNote:SetWidth(CW)
    capNote:SetJustifyH("CENTER")
    capNote:SetTextColor(muted[1], muted[2], muted[3])

    local pageLabel = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    pageLabel:SetPoint("TOPLEFT", RIGHT_X, -430)
    pageLabel:SetWidth(CW)
    pageLabel:SetJustifyH("CENTER")
    pageLabel:SetTextColor(body[1], body[2], body[3])

    -- the pages found, on the right: the picture of the page, when and where, and the story with the words found
    local rows = {}
    for i = 1, Search.ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 50)
        row:SetPoint("TOPLEFT", RIGHT_X, -52 - (i - 1) * 52)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(34, 34)
        row.icon:SetPoint("TOPLEFT", 0, -6)
        row.star = row:CreateTexture(nil, "OVERLAY")
        row.star:SetSize(14, 14)
        row.star:SetPoint("TOPRIGHT", -2, -2)
        row.star:SetTexture("Interface\\AddOns\\Skald\\Textures\\ev_fav")
        row.when = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.when:SetPoint("TOPLEFT", 42, -2)
        row.when:SetWidth(CW - 62)
        row.when:SetJustifyH("LEFT")
        row.when:SetTextColor(muted[1], muted[2], muted[3])
        row.text = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.text:SetPoint("TOPLEFT", 42, -16)
        row.text:SetWidth(CW - 42)
        row.text:SetHeight(32)
        row.text:SetJustifyH("LEFT")
        row.text:SetJustifyV("TOP")
        row.text:SetTextColor(body[1], body[2], body[3])
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(0.43, 0.12, 0.10, 0.08)
        row.hover:Hide()
        row:SetScript("OnEnter", function(self)
            if not self.entry then return end
            self.hover:Show()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.SEARCH_OPEN, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if not self.entry then return end
            GameTooltip:Hide()
            if not (SkaldAPI.OpenEntry and SkaldAPI.OpenEntry(self.entry)) then
                print("|cffffd100Skald|r: " .. L.SEARCH_HIDDEN)
            end
        end)
        rows[i] = row
    end
    panel.rows = rows   -- for the tests

    local pages = 1
    refresh = function()
        local db = SkaldCharDB
        local entries = db and db.entries or {}
        local group = Search.GROUPS[state.group]
        local days = Search.DAYS[state.whenIx]
        kindSelect.button.text:SetText(string.format(L.SEARCH_KIND, L.SEARCH_KINDS[state.group]))
        whenSelect.button.text:SetText(string.format(L.SEARCH_WHEN, L.SEARCH_WHENS[state.whenIx]))
        -- a choice away from the usual one shows as chosen, and the list marks the one in use
        kindSelect.button:SetActive(state.group > 1)
        whenSelect.button:SetActive(state.whenIx > 1)
        for i, item in ipairs(kindSelect.items) do item:SetActive(i == state.group) end
        for i, item in ipairs(whenSelect.items) do item:SetActive(i == state.whenIx) end
        favCheck.Sync()
        local terms = Search.Terms(state.query)
        local searching = #terms > 0 or state.group > 1 or state.favs or days > 0
        if searching then
            results, total = Search.Run(entries, state.query, { group = group.key, favs = state.favs, days = days })
        else
            results, total = {}, 0
        end
        hint:SetShown(not searching)
        count:SetShown(searching)
        capNote:SetShown(searching and total > #results)
        if searching then
            count:SetText(total > 0 and string.format(L.SEARCH_FOUND, total) or L.SEARCH_NONE)
            capNote:SetText(string.format(L.SEARCH_SHOWN, #results))
        end
        pages = math.max(1, math.ceil(#results / Search.ROWS))
        state.page = math.max(1, math.min(state.page, pages))
        pageLabel:SetShown(pages > 1)
        pageLabel:SetText(string.format("%d / %d", state.page, pages))
        for i, row in ipairs(rows) do
            local e = results[(state.page - 1) * Search.ROWS + i]
            row.entry = e
            if not e then
                row:Hide()
            else
                row:Show()
                local icon = SkaldAPI.EntryIcon and SkaldAPI.EntryIcon(e)
                if icon then row.icon:SetTexture(icon); row.icon:Show() else row.icon:Hide() end
                if e.fav then row.star:Show() else row.star:Hide() end
                local line = date(SkaldAPI.DateFormat or "%d/%m/%Y", e.t or 0)
                local okPlace, place = pcall(ns.PlaceName, e)
                if okPlace and place and place ~= "" then
                    line = line .. "  -  " .. Search.Highlight(Plain(place), terms, FOUND, 40)
                end
                row.when:SetText(line)
                local ok, text = pcall(SkaldAPI.Render, e)
                row.text:SetText(ok and Search.Highlight(Plain(text), terms, FOUND, 120) or "")
            end
        end
    end

    local pager = {
        Turn = function(delta) state.page = math.max(1, math.min(pages, state.page + delta)) end,
        CanPrev = function() return state.page > 1 end,
        CanNext = function() return state.page < pages end,
    }
    refresh()
    return refresh, pager
end

SkaldAPI.AddTab("search", L.SEARCH_TAB, BuildTab)
