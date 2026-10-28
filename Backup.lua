-- Skald: backup of the whole diary of a character, and its restoring (/skald backup, /skald restore).
--
-- Loaded after ZoneCard.lua: it reads and writes the saved diary SkaldCharDB. The text is data and is never run as
-- Lua: it is written and read by the small typed serializer below (strings, numbers, booleans, tables), which keeps
-- the type of every key and value, and is plain ASCII, so a text box cannot mangle it (a bar `|` starts an escape
-- code there). It is cut in parts, each with a header and a checksum; the parts are collected, checked and
-- parsed into a candidate that touches nothing, and only a confirmed restore swaps it in.
local _, ns = ...

local L = ns.LOCALES[GetLocale()] or ns.LOCALES.enUS
local Backup = {}
ns.Backup = Backup

local MAGIC = "SKALDBACKUP1"
Backup.FORMAT = 1
Backup.PART_LIMIT = 16000   -- characters of the body of a part
Backup.MAX_DEPTH = 12
Backup.MAX_NODES = 2000000
Backup.MAX_PARTS = 400

-- Kept out of the backup and out of a restore: the old diaries set aside, the debug log, and the undo copy itself.
-- Everything else in SkaldCharDB travels, whatever it is called, so a key added later is not forgotten.
local EXCLUDE = { previous = true, probeLog = true, restoreUndo = true }
Backup.EXCLUDE = EXCLUDE

local NL = string.char(10)

local function Say(msg) print("|cffffd100Skald|r: " .. msg) end

-- 32-bit checksum of a text (with its length, kept apart) to know when something was cut or changed on the way.
local function Checksum(text)
    local h = 5381
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 4294967296 end
    return h
end

-- Text -------------------------------------------------------------------------

-- Plain ASCII only: the bytes that a text box or this format would take for something else, spaces (a part must
-- not begin or end with one, as pasting may trim it), and anything outside the printable range, are written as a
-- backslash and two hex digits.
local function EscByte(c) return string.format("\\%02X", c:byte()) end
local function Esc(s) return (tostring(s):gsub('[%c%s"\\|^\127-\255]', EscByte)) end
local function Unesc(s)
    if s:find("\\[^%x]") or s:find("\\%x[^%x]") or s:find("\\%x?$") then return nil end
    return (s:gsub("\\(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function SortKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta == "number" end
        return a < b
    end)
    return keys
end

local function IsArray(t)
    local n = #t
    if n == 0 then return false end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count == n
end

-- Serializer: t true, f false, n<number>; , "<string>" , [ array ] , { key value ... } . Keys are strings or numbers
-- and keep their type. What cannot be saved (functions, other keys) is left out.
local function Ser(v, out, depth)
    local tv = type(v)
    if tv == "boolean" then out[#out + 1] = v and "t" or "f"
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then v = 0 end
        out[#out + 1] = "n" .. string.format("%.17g", v) .. ";"
    elseif tv == "string" then out[#out + 1] = '"' .. Esc(v) .. '"'
    elseif tv == "table" then
        if depth >= Backup.MAX_DEPTH then error("too deep") end
        if IsArray(v) then
            out[#out + 1] = "["
            for i = 1, #v do Ser(v[i], out, depth + 1) end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            for _, k in ipairs(SortKeys(v)) do
                local tk, val = type(k), v[k]
                local tval = type(val)
                if (tk == "string" or tk == "number") and (tval == "string" or tval == "number" or tval == "boolean" or tval == "table") then
                    Ser(k, out, depth + 1)
                    Ser(val, out, depth + 1)
                end
            end
            out[#out + 1] = "}"
        end
    else
        error("cannot save a " .. tv)
    end
end

Backup.Serialize = function(v)
    local out = {}
    Ser(v, out, 0)
    return table.concat(out)
end

-- Parser: a cursor over the text, no load/loadstring anywhere. Errors are raised and caught by the caller.
Backup.Deserialize = function(text)
    local pos, nodes = 1, 0
    local function Fail(why) error("at " .. pos .. ": " .. why, 0) end
    local Value
    local function Key()
        local c = text:sub(pos, pos)
        if c == '"' or c == "n" then return Value(0, true) end
        Fail("a key must be a string or a number")
    end
    Value = function(depth, scalarOnly)
        nodes = nodes + 1
        if nodes > Backup.MAX_NODES then Fail("too big") end
        local c = text:sub(pos, pos)
        if c == "t" then pos = pos + 1; return true
        elseif c == "f" then pos = pos + 1; return false
        elseif c == "n" then
            local stop = text:find(";", pos, true)
            if not stop then Fail("a number is not closed") end
            local raw = text:sub(pos + 1, stop - 1)
            if not raw:match("^%-?%d[%d%.]*[eE]?[%+%-]?%d*$") then Fail("not a number") end
            local num = tonumber(raw)
            if not num or num ~= num or num == math.huge or num == -math.huge then Fail("not a number") end
            pos = stop + 1
            return num
        elseif c == '"' then
            local stop = text:find('"', pos + 1, true)
            if not stop then Fail("a string is not closed") end
            local s = Unesc(text:sub(pos + 1, stop - 1))
            if not s then Fail("a bad escape") end
            pos = stop + 1
            return s
        elseif (c == "[" or c == "{") and not scalarOnly then
            if depth >= Backup.MAX_DEPTH then Fail("too deep") end
            pos = pos + 1
            local t = {}
            if c == "[" then
                local i = 0
                while text:sub(pos, pos) ~= "]" do
                    if pos > #text then Fail("an array is not closed") end
                    i = i + 1
                    t[i] = Value(depth + 1)
                end
            else
                while text:sub(pos, pos) ~= "}" do
                    if pos > #text then Fail("a table is not closed") end
                    local k = Key()
                    if t[k] ~= nil then Fail("a key twice") end
                    t[k] = Value(depth + 1)
                end
            end
            pos = pos + 1
            return t
        end
        Fail("unexpected '" .. c .. "'")
    end
    local ok, result = pcall(function()
        local v = Value(0)
        if pos <= #text then Fail("text after the end") end
        return v
    end)
    if ok then return result end
    return nil, tostring(result)
end

-- What goes in -------------------------------------------------------------------

local function Capture(db)
    local state = {}
    for k, v in pairs(db) do
        if not EXCLUDE[k] then state[k] = v end
    end
    return state
end
Backup.Capture = Capture

local function Counts(entries)
    local first, last
    for _, e in ipairs(entries or {}) do
        if type(e.t) == "number" then
            if not first or e.t < first then first = e.t end
            if not last or e.t > last then last = e.t end
        end
    end
    return first or 0, last or 0
end

-- The parts of a state as text: { parts = { text... }, meta = { ... } }. `override` replaces fields of the header
-- (for the tests, to make a backup that lies).
Backup.BuildFrom = function(state, override)
    local payload = Backup.Serialize(state)
    local entries = type(state.entries) == "table" and state.entries or {}
    local first, last = Counts(entries)
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local meta = {
        guid = state.guid or (UnitGUID and UnitGUID("player")) or "",
        name = UnitName("player") or "?", class = class or "", race = race or "",
        level = (UnitLevel and UnitLevel("player")) or 0,
        made = time(), first = first, last = last, count = #entries,
        sum = Checksum(payload), size = #payload,
    }
    for k, v in pairs(override or {}) do meta[k] = v end
    local n = math.max(1, math.ceil(#payload / Backup.PART_LIMIT))
    local parts = {}
    for i = 1, n do
        local body = payload:sub((i - 1) * Backup.PART_LIMIT + 1, i * Backup.PART_LIMIT)
        local header = { MAGIC, meta.guid, meta.name, meta.class, meta.race, meta.level, meta.made, meta.first,
            meta.last, meta.count, i, n, #body, Checksum(body), meta.size, meta.sum }
        for j = 2, #header do header[j] = Esc(header[j]) end
        parts[i] = table.concat(header, "^") .. NL .. body
    end
    return { parts = parts, meta = meta }
end

-- The backup of the diary in use, or nil when it is empty.
Backup.Build = function()
    local db = SkaldCharDB
    if not db or type(db.entries) ~= "table" or #db.entries == 0 then return nil end
    return Backup.BuildFrom(Capture(db))
end

Backup.Checksum = Checksum

-- What comes in ------------------------------------------------------------------

-- A part: header line, then the body. Returns the part, or nil and a reason code.
local function ReadPart(text)
    local header, body = text:match("^([^\n]*)\n(.*)$")
    if not header then return nil, "notbackup" end
    local f = {}
    for field in (header .. "^"):gmatch("([^%^]*)%^") do f[#f + 1] = field end
    if f[1] ~= MAGIC then
        if f[1] and f[1]:match("^SKALDBACKUP%d") then return nil, "newer", tonumber(f[1]:match("%d+")) end
        return nil, "notbackup"
    end
    if #f ~= 16 then return nil, "badpart" end
    local part = {
        guid = Unesc(f[2]), name = Unesc(f[3]), class = Unesc(f[4]), race = Unesc(f[5]),
        level = tonumber(f[6]), made = tonumber(f[7]), first = tonumber(f[8]), last = tonumber(f[9]),
        count = tonumber(f[10]), i = tonumber(f[11]), n = tonumber(f[12]), len = tonumber(f[13]),
        sum = tonumber(f[14]), size = tonumber(f[15]), total = tonumber(f[16]), body = body,
    }
    for _, key in ipairs({ "level", "made", "first", "last", "count", "i", "n", "len", "sum", "size", "total" }) do
        if not part[key] then return nil, "badpart" end
    end
    if not (part.guid and part.name and part.class and part.race) then return nil, "badpart" end
    if part.i < 1 or part.n < 1 or part.n > Backup.MAX_PARTS or part.i > part.n or part.i ~= math.floor(part.i) or part.n ~= math.floor(part.n) then
        return nil, "badpart"
    end
    if #body ~= part.len or Checksum(body) ~= part.sum then return nil, "badpart", part.i end
    return part
end

-- The parts pasted so far. Add takes any text (one part, several, with Windows line ends) and answers one
-- result per part found: { ok = bool, code = ..., i = part number }.
Backup.NewImport = function() return { parts = {} } end

local function SplitParts(text)
    text = NL .. text:gsub("\r\n?", NL)
    -- a part starts a line (a body is one line: a note that happens to say the name does not start one)
    local starts, from = {}, 1
    while true do
        local s = text:find(NL .. "SKALDBACKU", from, true)   -- also catches a newer format
        if not s then break end
        starts[#starts + 1] = s + 1
        from = s + 1
    end
    local out = {}
    for k, s in ipairs(starts) do
        out[k] = strtrim(text:sub(s, (starts[k + 1] or #text + 1) - 1))
    end
    return out
end

Backup.Add = function(imp, text)
    local results = {}
    local pieces = SplitParts(tostring(text or ""))
    if #pieces == 0 then return { { ok = false, code = "notbackup" } } end
    for _, piece in ipairs(pieces) do
        local part, code, extra = ReadPart(piece)
        if not part then
            results[#results + 1] = { ok = false, code = code, i = (code == "badpart") and extra or nil, format = (code == "newer") and extra or nil }
        elseif imp.total and (part.total ~= imp.total or part.size ~= imp.size or part.n ~= imp.n or part.guid ~= imp.guid) then
            results[#results + 1] = { ok = false, code = "other", i = part.i }
        else
            local have = imp.parts[part.i]
            if have then
                results[#results + 1] = { ok = false, code = (have.body == part.body) and "dup" or "conflict", i = part.i }
            else
                if not imp.total then
                    imp.total, imp.size, imp.n, imp.guid = part.total, part.size, part.n, part.guid
                    imp.meta = { guid = part.guid, name = part.name, class = part.class, race = part.race, level = part.level,
                        made = part.made, first = part.first, last = part.last, count = part.count }
                end
                imp.parts[part.i] = part
                results[#results + 1] = { ok = true, code = "added", i = part.i }
            end
        end
    end
    return results
end

-- The numbers of the parts still to come, in order.
Backup.Missing = function(imp)
    local missing = {}
    if not imp.n then return missing end
    for i = 1, imp.n do
        if not imp.parts[i] then missing[#missing + 1] = i end
    end
    return missing
end

Backup.Received = function(imp)
    local n = 0
    for _ in pairs(imp.parts) do n = n + 1 end
    return n
end

-- The checks the candidate must pass before anything is touched. Returns nil, or the reason.
local function Validate(state, meta)
    if type(state) ~= "table" then return "not a table" end
    for k in pairs(state) do
        if type(k) ~= "string" or #k > 64 then return "a key that is not a name" end
        if EXCLUDE[k] then return "a key that does not belong (" .. k .. ")" end
    end
    local entries = state.entries
    if type(entries) ~= "table" then return "no pages" end
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    if count ~= #entries then return "the pages are not in order" end
    for i, e in ipairs(entries) do
        if type(e) ~= "table" or type(e.t) ~= "number" or type(e.kind) ~= "string" or e.kind == "" then
            return "page " .. i .. " is not a page"
        end
    end
    for _, key in ipairs({ "stats", "visited", "flags" }) do
        if state[key] ~= nil and type(state[key]) ~= "table" then return key .. " is not a table" end
    end
    if state.version ~= nil and type(state.version) ~= "number" then return "version is not a number" end
    if type(state.guid) ~= "string" or state.guid == "" then return "no character" end
    if state.guid ~= meta.guid then return "the character does not match the header" end
    if #entries ~= meta.count then return "the number of pages does not match the header" end
    local first, last = Counts(entries)
    if first ~= meta.first or last ~= meta.last then return "the period does not match the header" end
    return nil
end

-- All parts in: joins them, checks the whole, parses it and checks the structure. Returns the candidate
-- (state and meta) or nil and a reason code and text. Nothing of the diary in use is touched.
Backup.Finish = function(imp)
    if not imp.n then return nil, "empty" end
    if #Backup.Missing(imp) > 0 then return nil, "missing" end
    local pieces = {}
    for i = 1, imp.n do pieces[i] = imp.parts[i].body end
    local payload = table.concat(pieces)
    if #payload ~= imp.size or Checksum(payload) ~= imp.total then return nil, "damaged", "the whole does not match its checksum" end
    local state, why = Backup.Deserialize(payload)
    if not state then return nil, "damaged", why end
    why = Validate(state, imp.meta)
    if why then return nil, "damaged", why end
    return { state = state, meta = imp.meta }
end

-- Whether this backup may be restored on the character in use (for now only the one it came from).
Backup.CanRestore = function(meta)
    local guid = UnitGUID and UnitGUID("player")
    local db = SkaldCharDB
    if type(guid) ~= "string" or guid == "" or type(meta.guid) ~= "string" or meta.guid ~= guid then return false end
    if db and db.guid and db.guid ~= guid then return false end
    return true
end

-- The swap -----------------------------------------------------------------------

local function Swap(db, state)
    for k in pairs(db) do
        if not EXCLUDE[k] then db[k] = nil end
    end
    for k, v in pairs(state) do db[k] = v end
end

-- Puts a candidate in place of the diary in use. The diary replaced is kept whole as the one undo copy
-- (db.restoreUndo, outside db.previous, which holds three and would let one go). If anything fails after the swap,
-- the old diary is put back. Returns true, or false and the reason.
Backup.Apply = function(candidate)
    local db = SkaldCharDB
    if not db then return false, "no diary" end
    if candidate.used then return false, "already used" end
    if not Backup.CanRestore(candidate.meta) then return false, "wrong character" end
    -- its tables become the diary: it cannot be put in place a second time
    candidate.used = true
    local oldFirst, oldLast = Counts(db.entries)
    local undo = { t = time(), count = #(db.entries or {}), first = oldFirst, last = oldLast, state = Capture(db) }
    local previousUndo = db.restoreUndo
    Swap(db, candidate.state)
    db.restoreUndo = undo
    local ok, err = pcall(function()
        db.guid = candidate.meta.guid
        ns.ReadAfresh(db)
        ns.RefreshDiary()
    end)
    if not ok then
        Swap(db, undo.state)
        db.restoreUndo = previousUndo
        pcall(ns.RefreshDiary)
        return false, tostring(err)
    end
    return true
end

-- What the undo copy is, for the window: { count, first, last, t } or nil.
Backup.UndoInfo = function()
    local u = SkaldCharDB and SkaldCharDB.restoreUndo
    if type(u) ~= "table" or type(u.state) ~= "table" then return nil end
    return u
end

-- Brings the undo copy back; the diary in use becomes the undo copy in its place (so it can be undone again).
Backup.Undo = function()
    local db = SkaldCharDB
    local u = Backup.UndoInfo()
    if not (db and u) then return false, "none" end
    local guid = UnitGUID and UnitGUID("player")
    if type(guid) ~= "string" or u.state.guid ~= guid then return false, "wrong character" end
    local first, last = Counts(db.entries)
    local swapped = { t = time(), count = #(db.entries or {}), first = first, last = last, state = Capture(db) }
    Swap(db, u.state)
    db.restoreUndo = swapped
    ns.RefreshDiary()
    return true
end

-- What is said -------------------------------------------------------------------

local function Day(t) return date("%Y-%m-%d", t) end

local function ClassName(file)
    return (_G.LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file
end

Backup.Summary = function(meta)
    return string.format(L.BK_SUMMARY, meta.name, ClassName(meta.class), meta.level, meta.count, Day(meta.first), Day(meta.last), Day(meta.made))
end

-- 1, 2, 3, 7 -> "1-3, 7"
Backup.List = function(numbers)
    local out, i = {}, 1
    while i <= #numbers do
        local j = i
        while numbers[j + 1] == numbers[j] + 1 do j = j + 1 end
        out[#out + 1] = (j > i) and (numbers[i] .. "-" .. numbers[j]) or tostring(numbers[i])
        i = j + 1
    end
    return table.concat(out, ", ")
end

-- The words for what Add answered about a part.
Backup.Why = function(r)
    local code = r.code
    if code == "added" then return nil
    elseif code == "notbackup" then return L.BK_ERR_NOTBACKUP
    elseif code == "newer" then return string.format(L.BK_ERR_NEWER, r.format or 0)
    elseif code == "badpart" then return r.i and string.format(L.BK_ERR_BADPART_N, r.i) or L.BK_ERR_BADPART
    elseif code == "other" then return string.format(L.BK_ERR_OTHER, r.i or 0)
    elseif code == "dup" then return string.format(L.BK_ERR_DUP, r.i or 0)
    elseif code == "conflict" then return string.format(L.BK_ERR_CONFLICT, r.i or 0) end
    return L.BK_ERR_NOTBACKUP
end

-- Windows ----------------------------------------------------------------------

local INK = { 0.35, 0.27, 0.15 }

-- A plain parchment window with a title, a close button and a read-only or pasteable text box.
local function MakeWindow(name, title, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(560, height)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropBorderColor(0.35, 0.22, 0.10, 1)
    local paper = f:CreateTexture(nil, "BACKGROUND")
    paper:SetPoint("TOPLEFT", 4, -4)
    paper:SetPoint("BOTTOMRIGHT", -4, 4)
    paper:SetColorTexture(0.86, 0.77, 0.58, 1)
    tinsert(UISpecialFrames, name)
    local head = f:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    head:SetPoint("TOP", 0, -18)
    head:SetTextColor(INK[1], INK[2], INK[3])
    head:SetText(title)
    CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)
    return f
end

local function MakeText(f, x, y, width, size)
    local fs = f:CreateFontString(nil, "OVERLAY", size or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetTextColor(0.15, 0.10, 0.04)
    return fs
end

-- A dark box with a scrolling edit box inside. Returns the box and the edit box.
local function MakeBox(f, top, bottom)
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 20, top)
    box:SetPoint("BOTTOMRIGHT", -20, bottom)
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
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(496)
    edit:SetTextInsets(2, 2, 2, 2)
    -- No limit: a part is long, and a text cut short would only be caught by its checksum.
    if edit.SetMaxLetters then edit:SetMaxLetters(0) end
    if edit.SetMaxBytes then edit:SetMaxBytes(0) end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    return box, edit, scroll
end

local exportFrame
Backup.ShowExport = function()
    if not exportFrame then
        local f = MakeWindow("SkaldBackupFrame", L.BK_EXPORT_TITLE, 400)
        local hint = MakeText(f, 24, -50, 512)
        hint:SetText(L.BK_EXPORT_HINT)
        local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        prev:SetSize(30, 24); prev:SetText("<"); prev:SetPoint("TOPLEFT", 24, -116)
        local nextButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        nextButton:SetSize(30, 24); nextButton:SetText(">"); nextButton:SetPoint("TOPLEFT", 58, -116)
        local label = MakeText(f, 98, -121, 300, "QuestFont")
        local _, edit, scroll = MakeBox(f, -148, 20)
        local build, part, shown = nil, 1, ""
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- Read only: anything typed is put back.
        edit:SetScript("OnTextChanged", function(self, byUser)
            if byUser then self:SetText(shown); self:HighlightText() end
        end)
        function f:Refresh()
            build = Backup.Build()
            local n = build and #build.parts or 0
            part = math.max(1, math.min(part, math.max(1, n)))
            shown = build and build.parts[part] or L.BK_EXPORT_EMPTY
            edit:SetText(shown)
            edit:SetHeight(math.max(240, math.ceil(#shown / 96) * 12 + 24))
            scroll:SetVerticalScroll(0)
            edit:HighlightText()
            prev:SetShown(n > 1)
            nextButton:SetShown(n > 1)
            label:SetText(n > 0 and string.format(L.BK_PART, part, n) or "")
        end
        prev:SetScript("OnClick", function() part = part - 1; f:Refresh() end)
        nextButton:SetScript("OnClick", function() part = part + 1; f:Refresh() end)
        exportFrame = f
    end
    exportFrame:Refresh()
    exportFrame:Show()
    return exportFrame
end

local restoreFrame, importing, pending

-- Says where the pasted parts stand, and when all are in, what would be restored.
local function ShowState(f, results)
    local lines = {}
    for _, r in ipairs(results or {}) do
        local why = Backup.Why(r)
        if why then lines[#lines + 1] = "|cffa01010" .. why .. "|r" end
    end
    pending = nil
    local n, got = importing.n, Backup.Received(importing)
    if n then
        local missing = Backup.Missing(importing)
        if #missing > 0 then
            lines[#lines + 1] = string.format(L.BK_PROGRESS, got, n, Backup.List(missing))
        else
            local candidate, code, why = Backup.Finish(importing)
            if not candidate then
                lines[#lines + 1] = "|cffa01010" .. string.format(L.BK_ERR_DAMAGED, tostring(why or code)) .. "|r"
            elseif not Backup.CanRestore(candidate.meta) then
                lines[#lines + 1] = "|cffa01010" .. string.format(L.BK_ERR_CHAR, candidate.meta.name) .. "|r"
            else
                pending = candidate
                lines[#lines + 1] = string.format(L.BK_READY, n)
                lines[#lines + 1] = Backup.Summary(candidate.meta)
            end
        end
    end
    f.status:SetText(table.concat(lines, "\n"))
    f.restoreButton:SetEnabled(pending ~= nil)
end

Backup.ShowRestore = function()
    if not restoreFrame then
        local f = MakeWindow("SkaldRestoreFrame", L.BK_RESTORE_TITLE, 420)
        local hint = MakeText(f, 24, -50, 512)
        hint:SetText(L.BK_RESTORE_HINT)
        local _, edit = MakeBox(f, -118, 150)
        edit:SetHeight(200)
        f.status = MakeText(f, 24, -280, 512, "GameFontHighlightSmall")
        f.status:SetHeight(80)
        local restoreButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        restoreButton:SetSize(140, 26); restoreButton:SetText(L.BK_RESTORE_BTN); restoreButton:SetPoint("BOTTOMRIGHT", -24, 18)
        local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        reset:SetSize(140, 26); reset:SetText(L.BK_RESET_BTN); reset:SetPoint("BOTTOMLEFT", 24, 18)
        f.restoreButton = restoreButton
        edit:SetScript("OnTextChanged", function(self, byUser)
            if not byUser then return end
            local text = self:GetText() or ""
            if text == "" then return end
            self:SetText("")
            ShowState(f, Backup.Add(importing, text))
        end)
        reset:SetScript("OnClick", function()
            importing = Backup.NewImport()
            ShowState(f, {})
        end)
        restoreButton:SetScript("OnClick", function()
            if not pending then return end
            local text = Backup.Summary(pending.meta)
            if Backup.UndoInfo() then text = text .. "\n\n" .. L.BK_UNDO_REPLACED end
            StaticPopup_Show("SKALD_BACKUP_RESTORE", text)
        end)
        f.edit = edit
        restoreFrame = f
    end
    importing = Backup.NewImport()
    ShowState(restoreFrame, {})
    restoreFrame.edit:SetText("")
    restoreFrame:Show()
    return restoreFrame
end

-- The restore, after the window and the question. Reports; the diary is untouched if it fails.
Backup.DoRestore = function()
    local candidate = pending
    if not candidate then return false end
    local ok, why = Backup.Apply(candidate)
    if ok then
        Say(string.format(L.BK_DONE, #SkaldCharDB.entries))
        pending, importing = nil, Backup.NewImport()
        if restoreFrame then ShowState(restoreFrame, {}); restoreFrame:Hide() end
    else
        Say(string.format(L.BK_FAILED, tostring(why)))
    end
    return ok
end

Backup.ConfirmUndo = function()
    local u = Backup.UndoInfo()
    if not u then Say(L.BK_UNDO_NONE); return end
    StaticPopup_Show("SKALD_BACKUP_UNDO", string.format(L.BK_UNDO_INFO, u.count, Day(u.first), Day(u.last), Day(u.t)))
end

Backup.DoUndo = function()
    local ok, why = Backup.Undo()
    if ok then Say(string.format(L.BK_UNDO_DONE, #SkaldCharDB.entries)) else Say(string.format(L.BK_FAILED, tostring(why))) end
    return ok
end

StaticPopupDialogs["SKALD_BACKUP_RESTORE"] = {
    text = L.BK_CONFIRM,
    button1 = L.YES,
    button2 = L.NO,
    OnAccept = function() Backup.DoRestore() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SKALD_BACKUP_UNDO"] = {
    text = L.BK_UNDO_CONFIRM,
    button1 = L.YES,
    button2 = L.NO,
    OnAccept = function() Backup.DoUndo() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
