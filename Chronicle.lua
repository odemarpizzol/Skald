-- Skald: the data of the shared chronicle (a plan; nothing in the book uses this file yet).
--
-- Pure functions, no frames, no sends, no saved variables of their own: it only defines things. Its job is to take what a player
-- shares about an adventure (a CONTRIBUTION), keep what other players shared (a STORE), and put the contributions of the same
-- adventure together into one CHAPTER, with no double counting.
--
--   * Facts, not text. A contribution carries ids (the instance, the encounters) and numbers; the reader's own client tells them
--     in its own language and voice. Free text is only the author's short note, and it is cleaned on the way in.
--   * No negotiated adventure id (the group channel is not proven yet): contributions of the same adventure are recognised by what
--     they say: the same instance, windows of time that overlap, and a boss or a person in common.
--   * A contribution is keyed by its author and its adventure; a newer revision replaces an older one, a copy that comes again
--     changes nothing. The author is always the sender the game reported, never what the payload claims.
--   * Everything has a ceiling (contributions, bosses, people, note, bytes).
--
-- The store is a plain table of numbers and strings, so it survives a /reload and travels in a backup. Where it lives (the
-- account's SkaldDB by guild, or each character) is decided where it is wired in, not here.
local _, ns = ...

local Chronicle = {}
ns.Chronicle = Chronicle

Chronicle.VERSION = 1
Chronicle.MAX_CONTRIBS = 200     -- contributions kept in a store (the oldest go first)
Chronicle.MAX_BOSSES = 20        -- encounters in one contribution
Chronicle.MAX_WITH = 10          -- people one contribution names
Chronicle.MAX_NOTE = 280         -- characters of a note
Chronicle.MAX_NAME = 24          -- characters of a name
Chronicle.MAX_BYTES = 1800       -- bytes of one contribution once written as text (a few chunks of Comms)
Chronicle.SLACK = 600            -- seconds of room between two windows that still count as the same adventure

-- Text from another player ------------------------------------------------------------------------------------------------

-- The game's text boxes take a bar (|) as the start of a code (a colour, a link, a picture). A note from someone else must carry
-- none: the bar goes, and so does every control character; spaces are tidied and the length is capped.
function Chronicle.CleanText(s, limit)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|", ""):gsub("[%c\127]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    -- cut by characters, not in the middle of a letter of more than one byte
    if #s > limit then
        local cut = limit
        while cut > 0 do
            local b = s:byte(cut + 1)
            if not b or b < 128 or b >= 192 then break end   -- the next byte begins a letter: cut here
            cut = cut - 1
        end
        s = s:sub(1, cut)
    end
    if s == "" then return nil end
    return s
end

local function Int(v, low, high)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    v = math.floor(v)
    if v < low or v > high then return nil end
    return v
end

-- A contribution -----------------------------------------------------------------------------------------------------------

-- What a player shares, built from pages of the diary: `entries` are the pages of the adventure (boss pages carry `enc`, the id of
-- the encounter, and `iid`, the instance; a page without them tells nothing the chronicle can compare, so it is left out).
-- opts: with = names the author chose to show, note = a short text, rev = the revision, t0/t1 = the window (else from the pages).
function Chronicle.Build(entries, opts)
    opts = opts or {}
    local iid, t0, t1
    local seen, bosses = {}, {}
    for _, e in ipairs(entries or {}) do
        if type(e) == "table" and e.kind == "boss" and type(e.enc) == "number" and type(e.iid) == "number" then
            if not iid then iid = e.iid end
            if e.iid == iid then
                if not seen[e.enc] then
                    seen[e.enc] = true
                    bosses[#bosses + 1] = { enc = e.enc, t = Int(e.t, 0, 4102444800), tries = Int(e.tries, 0, 99) }
                end
                if type(e.t) == "number" then
                    t0 = (not t0 or e.t < t0) and e.t or t0
                    t1 = (not t1 or e.t > t1) and e.t or t1
                end
            end
        end
    end
    if not iid then return nil, "no boss with an id" end
    local c = { v = Chronicle.VERSION, iid = iid, t0 = Int(opts.t0 or t0, 0, 4102444800), t1 = Int(opts.t1 or t1, 0, 4102444800),
        rev = Int(opts.rev or 1, 1, 1000000), bosses = bosses }
    if opts.with then c.with = opts.with end
    if opts.note then c.note = opts.note end
    return Chronicle.Sanitize(c)
end

-- Make a contribution safe to keep and to show: only the fields we know, with the types, limits and counts we allow. Returns the
-- clean contribution, or nil and why. Used on what we build and, above all, on what comes from outside.
function Chronicle.Sanitize(c)
    if type(c) ~= "table" then return nil, "not a table" end
    if c.v ~= Chronicle.VERSION then return nil, "version" end
    local iid = Int(c.iid, 1, 100000)
    local t0, t1 = Int(c.t0, 0, 4102444800), Int(c.t1, 0, 4102444800)
    local rev = Int(c.rev, 1, 1000000)
    if not (iid and t0 and t1 and rev) or t1 < t0 then return nil, "fields" end
    local out = { v = Chronicle.VERSION, iid = iid, t0 = t0, t1 = t1, rev = rev, bosses = {} }
    if type(c.bosses) ~= "table" then return nil, "bosses" end
    local seen = {}
    for _, b in ipairs(c.bosses) do
        if #out.bosses >= Chronicle.MAX_BOSSES then break end
        if type(b) == "table" then
            local enc = Int(b.enc, 1, 10000000)
            if enc and not seen[enc] then
                seen[enc] = true
                out.bosses[#out.bosses + 1] = { enc = enc, t = Int(b.t, 0, 4102444800), tries = Int(b.tries, 0, 99) }
            end
        end
    end
    if #out.bosses == 0 then return nil, "no boss" end
    if type(c.with) == "table" then
        out.with = {}
        for _, name in ipairs(c.with) do
            if #out.with >= Chronicle.MAX_WITH then break end
            local clean = Chronicle.CleanText(name, Chronicle.MAX_NAME)
            if clean then out.with[#out.with + 1] = clean end
        end
        if #out.with == 0 then out.with = nil end
    end
    out.note = Chronicle.CleanText(c.note, Chronicle.MAX_NOTE)
    -- one more ceiling, on the whole: the note is the part that gives way
    local b = ns.Backup
    if b and b.Serialize then
        local ok, text = pcall(b.Serialize, out)
        if not ok then return nil, "cannot write" end
        if #text > Chronicle.MAX_BYTES and out.note then
            out.note = out.note:sub(1, math.max(0, Chronicle.MAX_NOTE - (#text - Chronicle.MAX_BYTES)))
            out.note = Chronicle.CleanText(out.note, Chronicle.MAX_NOTE)
            ok, text = pcall(b.Serialize, out)
        end
        if not ok or #text > Chronicle.MAX_BYTES then return nil, "too big" end
    end
    return out
end

-- The store ------------------------------------------------------------------------------------------------------------------

function Chronicle.NewStore() return { contribs = {}, order = {} } end

local function KeyOf(author, c) return author .. "|" .. c.iid .. "|" .. c.t0 end

-- Put a contribution from `author` in the store. Returns "added", "replaced", "stale" (an older or equal revision of what we
-- have: nothing changes) or "bad: why". The author is the sender the game reported; the payload has no say.
function Chronicle.Add(store, author, contribution)
    if type(author) ~= "string" or author == "" or #author > 64 then return "bad: author" end
    local c, why = Chronicle.Sanitize(contribution)
    if not c then return "bad: " .. tostring(why) end
    c.by = author
    local key = KeyOf(author, c)
    local old = store.contribs[key]
    if old then
        if c.rev <= old.rev then return "stale" end
        store.contribs[key] = c
        return "replaced"
    end
    store.contribs[key] = c
    store.order[#store.order + 1] = key
    while #store.order > Chronicle.MAX_CONTRIBS do   -- the oldest adventure goes first
        local oldest, at = nil, 1
        for i, k in ipairs(store.order) do
            local x = store.contribs[k]
            if x and (not oldest or x.t1 < oldest.t1) then oldest, at = x, i end
        end
        store.contribs[table.remove(store.order, at)] = nil
    end
    return "added"
end

-- What Comms hands over: a message of kind "chron" from a sender.
function Chronicle.Receive(store, kind, value, sender)
    if kind ~= "chron" then return "ignored" end
    return Chronicle.Add(store, sender, value)
end

-- Chapters --------------------------------------------------------------------------------------------------------------------

local function Named(list, who)
    for _, name in ipairs(list or {}) do
        if ns.Comms and ns.Comms.SameName and ns.Comms.SameName(name, who) then return true end
    end
    return false
end

-- Do two contributions tell the same adventure? The same instance, windows that overlap (with a little room), and a boss or a
-- person in common.
function Chronicle.SameAdventure(a, b)
    if a.iid ~= b.iid then return false end
    if a.t0 > b.t1 + Chronicle.SLACK or b.t0 > a.t1 + Chronicle.SLACK then return false end
    local inA = {}
    for _, x in ipairs(a.bosses) do inA[x.enc] = true end
    for _, x in ipairs(b.bosses) do if inA[x.enc] then return true end end
    if a.by and b.by and (Named(a.with, b.by) or Named(b.with, a.by)) then return true end
    return false
end

-- The chapters of a store: contributions that tell the same adventure become one, newest chapter first. Bosses are the union by
-- the id of the encounter (never a sum), with the most tries anyone counted; authors and notes are listed once each.
function Chronicle.Chapters(store)
    local list = {}
    for _, c in pairs(store.contribs) do list[#list + 1] = c end
    table.sort(list, function(x, y) if x.t0 ~= y.t0 then return x.t0 < y.t0 end return (x.by or "") < (y.by or "") end)
    -- the groups of contributions that tell the same adventure (a person joins what any member of the group shares)
    local group = {}
    for i = 1, #list do group[i] = i end
    local function Find(i) while group[i] ~= i do group[i] = group[group[i]]; i = group[i] end return i end
    for i = 1, #list do
        for j = i + 1, #list do
            if Find(i) ~= Find(j) and Chronicle.SameAdventure(list[i], list[j]) then group[Find(j)] = Find(i) end
        end
    end
    local byRoot, chapters = {}, {}
    for i, c in ipairs(list) do
        local root = Find(i)
        local ch = byRoot[root]
        if not ch then
            ch = { iid = c.iid, t0 = c.t0, t1 = c.t1, bosses = {}, bossAt = {}, authors = {}, notes = {}, count = 0 }
            byRoot[root] = ch
            chapters[#chapters + 1] = ch
        end
        ch.count = ch.count + 1
        ch.t0, ch.t1 = math.min(ch.t0, c.t0), math.max(ch.t1, c.t1)
        for _, b in ipairs(c.bosses) do
            local x = ch.bossAt[b.enc]
            if not x then
                x = { enc = b.enc, t = b.t, tries = b.tries, by = {} }
                ch.bossAt[b.enc] = x
                ch.bosses[#ch.bosses + 1] = x
            else
                if b.tries and (not x.tries or b.tries > x.tries) then x.tries = b.tries end
                if b.t and (not x.t or b.t < x.t) then x.t = b.t end
            end
            x.by[#x.by + 1] = c.by
        end
        ch.authors[#ch.authors + 1] = c.by
        if c.note then ch.notes[#ch.notes + 1] = { by = c.by, text = c.note } end
    end
    for _, ch in ipairs(chapters) do
        ch.bossAt = nil
        table.sort(ch.bosses, function(x, y) if (x.t or 0) ~= (y.t or 0) then return (x.t or 0) < (y.t or 0) end return x.enc < y.enc end)
        table.sort(ch.authors)
    end
    table.sort(chapters, function(x, y) return x.t0 > y.t0 end)
    return chapters
end
