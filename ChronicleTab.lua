-- G2: a local, fictional guild chronicle. Only the visibility switch is saved.
-- Contributions, the note, the preview choices and the suggestion preference live in this module's memory.
local _, ns = ...
local L = ns.LOCALES[GetLocale()] or ns.LOCALES.enUS
local UI = L.CHRONICLE
local C = { TAB_ID = "chronicle", T0 = 1794484800, IID = 36, TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\" }
ns.ChronicleTab = C

-- These encounter numbers identify fixtures only; they are not advertised as client encounter IDs.
C.BOSSES = { 900001, 900002, 900003 }
C.AUTHORS = { "Lucien", "Aelyndra" }
C.MAP, C.MAP_W, C.MAP_H, C.NOTE_VIEW = "map_deadmines", 280, 140, 34   -- the hand-drawn map of the instance (512x256), the note box's visible height
C.MAP_FRAME_EDGE = 241 / 256   -- the outer lower ink rule in map_thumb_frame, before its transparent bottom margin
C.FRAME = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

function C.Sample()
    local chron = ns.Chronicle
    local store = chron.NewStore()
    local function Contribution(first, second, offset, note, companion)
        return assert(chron.Build({
            { kind = "boss", iid = C.IID, enc = first, t = C.T0 + offset, tries = first == C.BOSSES[2] and 2 or 1 },
            { kind = "boss", iid = C.IID, enc = second, t = C.T0 + offset + 900, tries = second == C.BOSSES[2] and 2 or 1 },
        }, { t0 = C.T0, t1 = C.T0 + 2400, note = note, with = { companion } }))
    end
    local own = Contribution(C.BOSSES[1], C.BOSSES[2], 300, UI.AUTHOR_NOTES[1], C.AUTHORS[2])
    local other = Contribution(C.BOSSES[2], C.BOSSES[3], 1200, UI.AUTHOR_NOTES[2], C.AUTHORS[1])
    assert(chron.Add(store, C.AUTHORS[1], own) == "added")
    assert(chron.Add(store, C.AUTHORS[2], other) == "added")
    return { store = store, chapter = chron.Chapters(store)[1], own = own, authors = { C.AUTHORS[1], C.AUTHORS[2] } }
end

-- Local package metadata declares the optional art actually shipped. Without the declaration the
-- prototype never requests missing textures: it draws empty frames and a plain ink rule instead.
function C.ArtAvailable(name)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(get) ~= "function" then return false end
    local ok, names = pcall(get, "Skald", "X-Skald-Chronicle-Art")
    if not ok or type(names) ~= "string" then return false end
    for item in names:gmatch("[%a_]+") do if item == name then return true end end
    return false
end

local function BossNames(bosses)
    local names = {}
    for _, boss in ipairs(bosses) do
        for i, id in ipairs(C.BOSSES) do if boss.enc == id then names[#names + 1] = UI.BOSS_NAMES[i]; break end end
    end
    return names
end

local function Build(panel)
    local CW, RX = SkaldAPI.CW, SkaldAPI.RIGHT_X
    local body, head, muted = SkaldAPI.C_BODY, SkaldAPI.C_HEAD, SkaldAPI.C_MUTED
    local function Text(x, y, width, font, color, height, just)
        local fs = panel:CreateFontString(nil, "OVERLAY", font or "SkaldBody")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetWidth(width)
        if height then fs:SetHeight(height) end
        fs:SetJustifyH(just or "LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        color = color or body
        ns.ThemeText(fs, color[1], color[2], color[3])
        return fs
    end
    local function Art(name, x, y, size)
        local frame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        frame:SetPoint("TOPLEFT", x, y)
        frame:SetSize(size, size)
        frame:SetBackdrop(C.FRAME)
        local tex = frame:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        ns.ThemeAlpha(tex, 1, 0.95)
        return { frame = frame, texture = tex, name = name }
    end
    local function ShowArt(art)
        local shown = C.ArtAvailable(art.name)
        if shown then art.texture:SetTexture(C.TEX .. "guild_" .. art.name) end
        art.texture:SetShown(shown)
        if shown then
            ns.ThemeBackdrop(art.frame, {0,0,0,0}, {0,0,0,0})
        else
            ns.ThemeBackdrop(art.frame, {0,0,0,0}, {muted[1],muted[2],muted[3],0.7}, "input")
        end
        return shown
    end
    local function StateIcon(x, y)
        local art = Art("state", x, y, 20)
        return art
    end
    local function ShowState(art, state)
        local index = ({ draft = 0, private = 0, queued = 1, received = 2 })[state]
        local shown = index ~= nil and ShowArt(art)
        if shown then art.texture:SetTexCoord(index / 4, (index + 1) / 4, 0, 1) end
        art.frame:SetShown(index ~= nil)
    end
    -- LEFT PAGE: the chapter, all on the centre line of the page (map as the picture, the crest as a medal on its lower edge).
    -- RIGHT PAGE: the signed memories, then the preview and the choices, all on the left edge of the page.
    local MID = math.floor(CW / 2)
    SkaldAPI.PageHeading(panel, UI.TITLE, 0)
    SkaldAPI.PageHeading(panel, UI.MEMORIES, RX)
    Text(0, -42, CW, "SkaldSmall", muted, 14, "CENTER"):SetText(UI.DEMO_GUILD .. " · " .. UI.DEMO_LABEL)
    local hero = panel:CreateTexture(nil, "ARTWORK")
    hero:SetSize(C.MAP_W, C.MAP_H)
    hero:SetPoint("TOP", panel, "TOPLEFT", MID, -66)
    hero:SetTexture(C.TEX .. C.MAP)
    ns.ThemeAlpha(hero, 1, 0.85)
    local heroFrame = panel:CreateTexture(nil, "OVERLAY", nil, 1)
    local frameHeight = C.MAP_H / 0.88
    heroFrame:SetSize(C.MAP_W / 0.88, frameHeight)
    heroFrame:SetPoint("CENTER", hero, "CENTER", 0, 0)
    heroFrame:SetTexture(C.TEX .. "map_thumb_frame")
    ns.ThemeAlpha(heroFrame, 1, 0.9)
    -- Centre the visible medal on the frame's ink rule, accounting for the frame texture's alpha margin.
    -- The title still starts below the whole medal.
    local crestSize, titleHeight, metaHeight = 56, 44, 16
    local frameEdge = 66 + C.MAP_H / 2 + (C.MAP_FRAME_EDGE - 0.5) * frameHeight
    local crestTop = frameEdge - crestSize / 2
    local titleTop = crestTop + crestSize + 12
    local metaTop = titleTop + titleHeight + 4
    local crest = Art("crest", MID - crestSize / 2, -crestTop, crestSize)
    local title = Text(0, -titleTop, CW, "SkaldHead2", head, titleHeight, "CENTER")
    title:SetText(UI.CHAPTER_HEADING)
    local meta = Text(0, -metaTop, CW, "SkaldSmall", muted, metaHeight, "CENTER")
    meta:SetText(date(UI.DATE_FORMAT, C.T0) .. " · " .. UI.INSTANCE)
    local ornamentY = -(metaTop + metaHeight + 10)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    ns.ThemeTint(divider, "ornament")
    divider:SetSize(CW, 15)
    divider:SetPoint("TOPLEFT", 0, ornamentY)
    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 0, ornamentY - 7)
    rule:SetSize(CW, 1)
    ns.ThemeFill(rule, muted[1], muted[2], muted[3], 0.45)
    Text(0, ornamentY - 22, CW, "SkaldSec", head, 18, "CENTER"):SetText(UI.BOSSES)
    local bossLine = Text(0, ornamentY - 42, CW, "SkaldBody", body, 18, "CENTER")
    local synthesis = Text(0, ornamentY - 68, CW, "SkaldItalic", body, 34, "CENTER")

    Text(RX, -42, CW, "SkaldSmall", muted, 14, "CENTER"):SetText(UI.DEMO_NOTICE)
    local memories = {}
    for i = 1, 2 do
        local y = -62 - (i - 1) * 54
        memories[i] = {
            seal = Art("quill", RX, y - 1, 28),
            author = Text(RX + 38, y, CW - 190, "SkaldBody", head, 17),
            state = Text(RX + CW - 150, y + 1, 128, "SkaldSmall", muted, 16, "RIGHT"),
            icon = StateIcon(RX + CW - 20, y),
            note = Text(RX + 38, y - 19, CW - 38, "SkaldItalic", body, 32),
        }
    end
    local divider2 = panel:CreateTexture(nil, "ARTWORK")
    ns.ThemeTint(divider2, "ornament")
    divider2:SetSize(CW, 15)
    divider2:SetPoint("TOPLEFT", RX, -172)
    local rule2 = panel:CreateTexture(nil, "ARTWORK")
    rule2:SetPoint("TOPLEFT", RX, -179)
    rule2:SetSize(CW, 1)
    ns.ThemeFill(rule2, muted[1], muted[2], muted[3], 0.45)

    Text(RX, -194, CW, "SkaldSec", head, 18):SetText(UI.PREVIEW)
    local suggested = Text(RX, -214, CW, "SkaldBody", head, 17)
    suggested:SetText(UI.CHAPTER_TITLE)
    local facts = Text(RX, -233, CW, "SkaldBody", body, 36)
    Text(RX, -271, CW, "SkaldSmall", muted, 14):SetText(UI.NAMES)
    local names = Text(RX, -285, CW, "SkaldBody", body, 17)
    local noteFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    noteFrame:SetPoint("TOPLEFT", RX, -308)
    noteFrame:SetSize(CW, 44)
    noteFrame:SetBackdrop(C.FRAME)
    ns.ThemeBackdrop(noteFrame, {0.62,0.48,0.28,0.16}, {0.45,0.30,0.14,0.75}, "input")
    local placeholder = noteFrame:CreateFontString(nil, "OVERLAY", "SkaldItalic")
    placeholder:SetPoint("TOPLEFT", 7, -6)
    placeholder:SetWidth(CW - 14)
    placeholder:SetJustifyH("LEFT")
    ns.ThemeText(placeholder, muted[1], muted[2], muted[3])
    placeholder:SetText(UI.NOTE_PLACEHOLDER)
    local scroll = CreateFrame("ScrollFrame", nil, noteFrame)
    scroll:SetPoint("TOPLEFT", 7, -5)
    scroll:SetPoint("BOTTOMRIGHT", -7, 5)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 20)))
    end)
    local note = CreateFrame("EditBox", nil, scroll)
    note:SetSize(CW - 14, C.NOTE_VIEW)
    note:SetMultiLine(true)
    note:SetAutoFocus(false)
    note:SetFontObject("SkaldBody")
    note:SetMaxLetters(ns.Chronicle.MAX_NOTE)
    ns.ThemeText(note, body[1],body[2],body[3])
    scroll:SetScrollChild(note)
    local meter = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    meter:SetWidth(CW - 14)
    meter:SetWordWrap(true)
    meter:Hide()
    local status = Text(RX + 26, -386, 120, "SkaldSmall", head, 16)
    local stateIcon = StateIcon(RX, -385)
    local feedback = Text(RX + 150, -386, CW - 150, "SkaldSmall", muted, 16, "RIGHT")
    local refresh, editing = nil, false
    local function CommitNote()
        if not C.state then return end
        local clean = ns.Chronicle.CleanText(note:GetText() or "", ns.Chronicle.MAX_NOTE) or ""
        C.state.note = clean
        editing = true
        note:SetText(clean)
        editing = false
    end
    note:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "")
        meter:SetText((self:GetText() or ""):gsub("|", "||"))
        local ok, height = pcall(meter.GetStringHeight, meter)
        if ok and type(height) == "number" then self:SetHeight(math.max(C.NOTE_VIEW, height + 8)) end
        if C.state and not editing then C.state.note = ns.Chronicle.CleanText(self:GetText() or "", ns.Chronicle.MAX_NOTE) or "" end
    end)
    note:SetScript("OnCursorChanged", function(_, _, y, _, height)
        if type(y) ~= "number" or type(height) ~= "number" then return end
        local top, current = -y, scroll:GetVerticalScroll()
        if top < current then scroll:SetVerticalScroll(math.max(0, top))
        elseif top + height > current + C.NOTE_VIEW then scroll:SetVerticalScroll(math.max(0, top + height - C.NOTE_VIEW)) end
    end)
    note:SetScript("OnEditFocusLost", CommitNote)
    note:SetScript("OnEscapePressed", function(self) CommitNote(); self:ClearFocus() end)
    local actions = {}
    local function Action(key, caption, x, width, state, style)
        local button = SkaldAPI.MakeButton(panel, width, 25, caption, style)
        button:SetPoint("TOPLEFT", RX + x, -358)
        button:SetScript("OnClick", function()
            if not C.state then return end
            CommitNote()
            C.state.status = state
            C.state.feedback = UI.NOT_SENT
            note:ClearFocus()
            refresh()
        end)
        actions[key] = button
    end
    local first, second = math.floor(CW * 0.31), math.floor(CW * 0.40)
    Action("share", UI.SHARE, 0, first, "queued", "gold")
    Action("private", UI.PRIVATE, first + 4, second, "private", "seg")
    Action("dismiss", UI.DISMISS, first + second + 8, CW - first - second - 8, "dismissed", "seg")
    local optOut = SkaldAPI.MakeCheck(panel, UI.SUGGESTIONS_OFF,
        function() return C.state and C.state.suppressSuggestions end,
        function(on) if C.state then C.state.suppressSuggestions = on end end, nil, nil, CW)
    optOut:SetPoint("TOPLEFT", RX, -412)

    local function StateLabel(state)
        return UI["STATUS_" .. state:upper()] or UI.STATUS_DRAFT
    end
    local function FitText(fs, text, font, height)
        fs:SetFontObject(font)
        fs:SetHeight(0)
        fs:SetText(text)
        local ok, measured = pcall(fs.GetStringHeight, fs)
        if ok and type(measured) == "number" and measured > height then fs:SetFontObject("SkaldSmall") end
        fs:SetHeight(height)
    end
    refresh = function()
        if not C.demo or not C.state then return end
        local data = C.state.data
        local chapter = data.chapter
        local bosses = BossNames(chapter.bosses)
        bossLine:SetText(table.concat(bosses, " · "))
        FitText(synthesis, string.format(UI.SYNTHESIS, chapter.count, #chapter.bosses), "SkaldItalic", 34)
        ShowArt(crest)
        local withDivider = C.ArtAvailable("divider")
        if withDivider then divider:SetTexture(C.TEX .. "guild_divider") end
        if withDivider then divider2:SetTexture(C.TEX .. "guild_divider") end
        divider:SetShown(withDivider)
        divider2:SetShown(withDivider)
        rule:SetShown(not withDivider)
        rule2:SetShown(not withDivider)
        ns.ThemeAlpha(divider, 0.9, 1)
        ns.ThemeAlpha(divider2, 0.9, 1)
        for i, memory in ipairs(memories) do
            local signed = chapter.notes[i]
            memory.author:SetText(signed.by)
            FitText(memory.note, signed.text, "SkaldItalic", 32)
            local state = signed.by == C.AUTHORS[1] and C.state.status or "received"
            memory.state:SetText(StateLabel(state))
            ShowArt(memory.seal)
            ShowState(memory.icon, state)
        end
        local when = date(UI.DATE_FORMAT, data.own.t0) .. " · " .. date("%H:%M", data.own.t0) .. "–" .. date("%H:%M", data.own.t1)
        facts:SetText(string.format(UI.FACTS_BODY, UI.INSTANCE, when, table.concat(BossNames(data.own.bosses), ", ")))
        names:SetText(string.format(UI.NAMES_BODY, data.authors[1], data.authors[2]))
        status:SetText(StateLabel(C.state.status))
        ShowState(stateIcon, C.state.status)
        feedback:SetText(C.state.feedback or UI.NOT_SENT)
        if (note:GetText() or "") ~= C.state.note then editing = true; note:SetText(C.state.note); editing = false end
        placeholder:SetShown((note:GetText() or "") == "")
        optOut.Sync()
    end
    panel.crest, panel.memories, panel.noteBox, panel.actions = crest, memories, note, actions
    panel.status, panel.feedback, panel.optOut, panel.facts, panel.noteFrame = status, feedback, optOut, facts, noteFrame
    panel.notePlaceholder = placeholder
    C.panel, C.Refresh = panel, refresh
    ns.ThemeWatch(panel, function() if C.demo then refresh() end end)
    note:SetText(C.state and C.state.note or "")
    refresh()
    return refresh
end

function C.Wanted() return C.demo == true end
function C.Command(arg)
    arg = tostring(arg or ""):lower()
    if arg == "demo" then
        C.state = { data = C.Sample(), note = "", status = "draft", suppressSuggestions = false }
        C.demo = true
        if SkaldDB then SkaldDB.chronicleTab = true end
        SkaldAPI.AddTab(C.TAB_ID, UI.TAB, Build)
        SkaldAPI.SetTabShown(C.TAB_ID, true)
        if C.Refresh then C.Refresh() end
        if SkaldAPI.OpenSection then SkaldAPI.OpenSection(C.TAB_ID) end
        return { UI.DEMO_ON }
    elseif arg == "off" then
        C.demo, C.state = nil, nil
        if SkaldDB then SkaldDB.chronicleTab = false end
        SkaldAPI.SetTabShown(C.TAB_ID, false)
        return { UI.DEMO_OFF }
    end
    return { UI.USAGE }
end
