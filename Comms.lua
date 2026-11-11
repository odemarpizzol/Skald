-- Skald: the talking layer between Skald users (for the shared chronicle, which is still a plan).
--
-- This file only DEFINES things. Loading it sends nothing, registers nothing and makes no frame: a copy of it in the game is
-- harmless until something creates a Comms and feeds it (ns.Comms.New). Nothing in the book uses it yet.
--
-- What it does, and nothing else:
--   * a message (a Lua table of plain values) is turned into text by the diary's own serializer (Backup.Serialize: plain ASCII,
--     typed, parsed by hand, never `load`), cut in chunks of at most 255 bytes (the game's limit for one addon message), each
--     chunk wearing a small header: version, kind, message id, number of the chunk, how many chunks, checksum of the whole;
--   * the chunks are sent through a queue that listens to what the game answers: accepted, throttled (wait and try again),
--     locked (the client refuses addon messages for a while, for example in an encounter: HOLD, never lose the message, and begin
--     again when the lock may have passed), a hard no (not in a guild, not in a group...: drop it, say why), a player who is
--     offline (drop it);
--   * what arrives is validated (prefix, version, sizes, counts, checksum, the shape of the decoded value), put together from
--     chunks that come late, twice or out of order, de-duplicated, and handed over as a table; our own echo is ignored;
--   * every table that grows (messages being put together, messages seen, senders counted) has a ceiling.
-- Which channels to use, and when the lock falls, are for the caller to decide (and for the tests in the game to show).
--
-- It is built as a factory, `ns.Comms.New{ ... }`, so that two Skalds can talk to each other in a test over a fake bus.
local _, ns = ...

local Comms = {}
ns.Comms = Comms

Comms.VERSION = 1
Comms.MAX_BYTES = 255        -- the game's limit for one addon message (prefix + text)
Comms.MAX_CHUNKS = 24        -- one message is at most this many chunks (about 5 KB of text)
Comms.MAX_PARTIAL = 3        -- messages being put together, per sender
Comms.MAX_PARTIAL_ALL = 24   -- ... and in all
Comms.PARTIAL_TTL = 300      -- seconds a half-received message is kept (longer than a hold, see RESTART_AFTER)
Comms.SEEN_MAX = 256         -- the messages already delivered that are remembered (to drop a copy that comes again)
Comms.RATE_MAX = 80          -- chunks accepted from one sender in RATE_WINDOW seconds
Comms.RATE_WINDOW = 60
Comms.GAP = 0.25             -- seconds between two chunks sent
Comms.PER_PUMP = 2           -- chunks sent by one call of Pump
Comms.HOLD_RETRY = 15        -- seconds between two tries while the client says it is locked
Comms.RESTART_AFTER = 60     -- a message held this long begins again from its first chunk (the receiver may have forgotten it)
Comms.MAX_TRIES = 8          -- tries of one chunk the game throttles, before the message is dropped
Comms.QUEUE_MAX = 40         -- messages waiting to be sent

-- What SendAddonMessage answers (Enum.SendAddonMessageResult in the Forever client; older clients answer nothing or a boolean).
Comms.CODE = {
    Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4, NotInGroup = 5,
    TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11,
    TargetOffline = 12,
}
local WAIT = { [3] = true, [8] = true }                      -- throttled: wait, try again
local LOCK = 11                                              -- locked: hold
local GONE = { [1] = "invalid prefix", [2] = "invalid message", [4] = "invalid chat type", [5] = "not in a group",
    [6] = "target required", [7] = "invalid channel", [10] = "not in a guild", [12] = "target offline" }

-- one number out of whatever the client answered: a number is itself, nothing or true is "accepted", false is a general error
local function Code(answer)
    if type(answer) == "number" then return answer end
    if answer == false then return 9 end
    return 0
end
Comms.Code = Code

-- A player's name comes as "Name-Realm" (the usual form) or with a space where the hyphen is ("Name Realm": that is the shape
-- the Forever client's sender was seen in); a realm may also have a space or a mark in its own name. So: the name is up to the
-- first hyphen or space, the realm is what is left with the spaces, hyphens, dots and apostrophes taken out, in lower case.
local function Parts(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local short, rest = name:match("^([^%-%s]+)[%-%s]*(.*)$")
    short = (short or ""):lower()
    rest = (rest or ""):gsub("[%s%-%.']", ""):lower()
    return short, rest
end
-- the same player? (the name must be the same; the realm too when both sides say one)
local function SameName(a, b)
    local sa, ra = Parts(a)
    local sb, rb = Parts(b)
    if sa == "" or sa ~= sb then return false end
    return ra == "" or rb == "" or ra == rb
end
Comms.SameName = SameName

local function Backup() return ns.Backup end

local Methods = {}
Methods.__index = Methods

--[[ opts:
     send(prefix, text, channel, target) -> the game's answer (number, boolean or nothing)
     now() -> seconds (GetTime)
     me -> "Name" or "Name-Realm" (or a function returning it)
     prefix -> the addon prefix
     onMessage(kind, value, sender, channel, id) -> called once for each complete, valid message from someone else
     kinds -> optional set of the kinds accepted ({ chronicle = true }); without it every well-formed kind is accepted
     safe(v) -> optional: turns a value the client may withhold into nil (Safe in Skald.lua)
     encode(value) / decode(text), checksum(text) -> optional, by default the diary's own (Backup.Serialize and so on)
     random() -> optional, for the message ids ]]
function Comms.New(opts)
    opts = opts or {}
    local c = setmetatable({
        send = opts.send, now = opts.now or function() return 0 end, prefix = opts.prefix or "SKALD1", onMessage = opts.onMessage,
        kinds = opts.kinds, safe = opts.safe or function(v) return v end,
        encode = opts.encode, decode = opts.decode, checksum = opts.checksum, rand = opts.random or math.random,
        me = opts.me,
        queue = {}, partial = {}, partialCount = 0, partialBy = {}, seen = {}, seenOrder = {}, rate = {}, rateCount = 0,
        held = false, heldAt = 0, lastSend = -1000, counter = 0,
        stats = { sent = 0, heard = 0, delivered = 0, dup = 0, self = 0, bad = 0, dropped = 0, held = 0, expired = 0, throttled = 0, queued = 0 },
        dropped = {},   -- the last reasons a message was dropped, newest last (at most 10)
    }, Methods)
    return c
end

function Methods:Me()
    local me = self.me
    if type(me) == "function" then me = me() end
    return me
end

local function Encode(self, value)
    if self.encode then return self.encode(value) end
    local b = Backup()
    if not (b and b.Serialize) then error("no serializer") end
    return b.Serialize(value)
end
local function Decode(self, text)
    if self.decode then return self.decode(text) end
    local b = Backup()
    if not (b and b.Deserialize) then error("no parser") end
    return b.Deserialize(text)
end
local function Sum(self, text)
    if self.checksum then return self.checksum(text) end
    local b = Backup()
    if b and b.Checksum then return b.Checksum(text) end
    local h = 5381
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 4294967296 end
    return h
end

-- the header of a chunk: version:kind:id:i:n:checksum:   (the checksum in decimal: %x of a large number is not safe in the game's Lua)
local function Header(kind, id, i, n, sum)
    return string.format("%d:%s:%s:%d:%d:%.0f:", Comms.VERSION, kind, id, i, n, sum)
end

local function Remember(self, why)
    local d = self.dropped
    d[#d + 1] = why
    while #d > 10 do table.remove(d, 1) end
end

-- Sending ----------------------------------------------------------------------------------------------------------------

-- Queue a message: `kind` (letters, up to 8), `value` (a table of plain values), the channel and, for a whisper, the target.
-- Returns the message id, or nil and why. Nothing is sent here: Pump() does that, so a message made in a fight waits for its turn.
function Methods:Send(kind, value, channel, target)
    if type(kind) ~= "string" or not kind:match("^%a%a?%a?%a?%a?%a?%a?%a?$") then return nil, "bad kind" end
    if type(channel) ~= "string" or channel == "" then return nil, "no channel" end
    if #self.queue >= Comms.QUEUE_MAX then self.stats.dropped = self.stats.dropped + 1; Remember(self, "queue full"); return nil, "queue full" end
    local ok, text = pcall(Encode, self, value)
    if not ok or type(text) ~= "string" then return nil, "cannot encode" end
    self.counter = self.counter + 1
    local id = string.format("%d", (math.floor(self.rand(1, 1000000)) * 1000 + self.counter) % 1073741823 + 1)
    local sum = Sum(self, text)
    -- the room left for the text of a chunk, with the longest header the message could wear
    local worst = #Header(kind, id, Comms.MAX_CHUNKS, Comms.MAX_CHUNKS, 4294967295)
    local room = Comms.MAX_BYTES - worst - #self.prefix
    if room < 16 then return nil, "no room" end
    local n = math.max(1, math.ceil(#text / room))
    if n > Comms.MAX_CHUNKS then return nil, "too big" end
    local chunks = {}
    for i = 1, n do
        chunks[i] = Header(kind, id, i, n, sum) .. text:sub((i - 1) * room + 1, i * room)
    end
    self.queue[#self.queue + 1] = { id = id, kind = kind, chunks = chunks, next = 1, channel = channel, target = target,
        tries = 0, notBefore = 0, heldSince = nil }
    self.stats.queued = self.stats.queued + 1
    return id
end

local function Drop(self, item, why)
    for i, it in ipairs(self.queue) do if it == item then table.remove(self.queue, i); break end end
    self.stats.dropped = self.stats.dropped + 1
    Remember(self, why)
    if self.onDrop then pcall(self.onDrop, item.kind, item.id, why, item.target) end
end

-- Send what is due. Called from a timer, after a Send and when the game says a lock may have passed (see Resume). Returns the
-- number of chunks the game took.
function Methods:Pump()
    local now = self.now()
    self:Expire(now)
    if not self.send then return 0 end
    local probing = false
    if self.held then
        if now - self.heldAt < Comms.HOLD_RETRY then return 0 end
        self.heldAt = now
        probing = true   -- one try, to learn whether the lock has passed
    end
    local sent = 0
    while #self.queue > 0 and sent < Comms.PER_PUMP do
        local item = self.queue[1]
        if item.notBefore > now then break end
        if now - self.lastSend < Comms.GAP then break end
        -- a message that waited long under a lock begins again from the first chunk (the receiver may have dropped the rest)
        if item.heldSince and item.next > 1 and now - item.heldSince >= Comms.RESTART_AFTER then item.next = 1 end
        local ok, answer = pcall(self.send, self.prefix, item.chunks[item.next], item.channel, item.target)
        self.lastSend = now
        local code = ok and Code(answer) or 9
        if code == 0 then
            self.stats.sent = self.stats.sent + 1
            sent = sent + 1
            self.held = false
            item.heldSince = nil
            item.tries = 0
            item.next = item.next + 1
            if item.next > #item.chunks then
                table.remove(self.queue, 1)
                if self.onSent then pcall(self.onSent, item.kind, item.id, item.target) end
            end
        elseif code == LOCK then
            if not self.held then self.stats.held = self.stats.held + 1 end
            self.held = true
            self.heldAt = now
            item.heldSince = item.heldSince or now
            break   -- never dropped: it waits for Resume or for the slow retry
        elseif WAIT[code] then
            self.stats.throttled = self.stats.throttled + 1
            item.tries = item.tries + 1
            if item.tries > Comms.MAX_TRIES then Drop(self, item, "throttled too long"); else
                item.notBefore = now + math.min(30, 2 ^ item.tries)
            end
            break
        elseif GONE[code] then
            Drop(self, item, GONE[code])
        else   -- a general error or a code we do not know: a few tries
            item.tries = item.tries + 1
            if item.tries > 3 then Drop(self, item, "error " .. tostring(code)); else item.notBefore = now + 2 * item.tries end
            break
        end
        if probing then break end
    end
    return sent
end

-- The game may have lifted the lock (the fight ended, a boss was done, a loading screen passed): try again at once.
function Methods:Resume()
    self.held = false
    self.heldAt = -1000
    for _, item in ipairs(self.queue) do item.notBefore = 0 end
    return self:Pump()
end

function Methods:Held() return self.held end
function Methods:Waiting() return #self.queue end

-- Receiving --------------------------------------------------------------------------------------------------------------

-- Forget what is too old (half-received messages past their time, senders not heard from in a while).
function Methods:Expire(now)
    now = now or self.now()
    for key, p in pairs(self.partial) do
        if now - p.last > Comms.PARTIAL_TTL then
            self.partial[key] = nil
            self.partialCount = self.partialCount - 1
            self.partialBy[p.sender] = (self.partialBy[p.sender] or 1) - 1
            if self.partialBy[p.sender] <= 0 then self.partialBy[p.sender] = nil end
            self.stats.expired = self.stats.expired + 1
        end
    end
end

local function Seen(self, key)
    if self.seen[key] then return true end
    self.seen[key] = true
    self.seenOrder[#self.seenOrder + 1] = key
    while #self.seenOrder > Comms.SEEN_MAX do self.seen[table.remove(self.seenOrder, 1)] = nil end
    return false
end

local function Bad(self, why)
    self.stats.bad = self.stats.bad + 1
    return "bad: " .. why
end

-- A chunk arrived (CHAT_MSG_ADDON): prefix, text, channel and sender as the game gave them. Returns what became of it, for the
-- tests: "ignored", "self", "dup", "partial", "ok" or "bad: ...".
function Methods:Hear(prefix, text, channel, sender)
    prefix, text, channel, sender = self.safe(prefix), self.safe(text), self.safe(channel), self.safe(sender)
    if prefix ~= self.prefix then return "ignored" end
    if type(text) ~= "string" or type(sender) ~= "string" or sender == "" or #sender > 64 then return Bad(self, "shape") end
    if #text + #prefix > Comms.MAX_BYTES then return Bad(self, "too long") end
    local me = self:Me()
    if me and SameName(sender, me) then self.stats.self = self.stats.self + 1; return "self" end
    local now = self.now()

    -- the sender is not let to flood: a ceiling of chunks in a window
    local r = self.rate[sender]
    if not r or now - r.t0 > Comms.RATE_WINDOW then
        if not r then
            self.rateCount = self.rateCount + 1
            if self.rateCount > 64 then self.rate, self.rateCount = {}, 1 end
        end
        r = { t0 = now, n = 0 }
        self.rate[sender] = r
    end
    r.n = r.n + 1
    if r.n > Comms.RATE_MAX then return Bad(self, "too many") end
    self.stats.heard = self.stats.heard + 1

    local ver, kind, id, i, n, sum, data = text:match("^(%d+):(%a+):(%d+):(%d+):(%d+):(%d+):(.*)$")
    if not ver then return Bad(self, "header") end
    ver, i, n, sum = tonumber(ver), tonumber(i), tonumber(n), tonumber(sum)
    if ver ~= Comms.VERSION then return Bad(self, "version") end
    if #kind > 8 or #id > 10 then return Bad(self, "header") end
    if self.kinds and not self.kinds[kind] then return Bad(self, "kind") end
    if n < 1 or n > Comms.MAX_CHUNKS or i < 1 or i > n then return Bad(self, "count") end
    if sum > 4294967295 then return Bad(self, "sum") end

    local key = sender .. "|" .. id
    if self.seen[key] then self.stats.dup = self.stats.dup + 1; return "dup" end

    local p = self.partial[key]
    if not p then
        if (self.partialBy[sender] or 0) >= Comms.MAX_PARTIAL or self.partialCount >= Comms.MAX_PARTIAL_ALL then
            return Bad(self, "busy")
        end
        p = { n = n, sum = sum, kind = kind, got = {}, have = 0, bytes = 0, sender = sender, first = now, last = now }
        self.partial[key] = p
        self.partialCount = self.partialCount + 1
        self.partialBy[sender] = (self.partialBy[sender] or 0) + 1
    end
    if p.n ~= n or p.sum ~= sum or p.kind ~= kind then return Bad(self, "mismatch") end
    p.last = now
    if p.got[i] then self.stats.dup = self.stats.dup + 1; return "dup" end
    p.bytes = p.bytes + #data
    if p.bytes > Comms.MAX_CHUNKS * Comms.MAX_BYTES then return Bad(self, "too big") end
    p.got[i] = data
    p.have = p.have + 1
    if p.have < p.n then return "partial" end

    -- all the chunks are here
    self.partial[key] = nil
    self.partialCount = self.partialCount - 1
    self.partialBy[sender] = (self.partialBy[sender] or 1) - 1
    if self.partialBy[sender] <= 0 then self.partialBy[sender] = nil end
    local text2 = table.concat(p.got, "", 1, p.n)
    if Sum(self, text2) ~= p.sum then return Bad(self, "checksum") end
    local ok, value = pcall(Decode, self, text2)
    if not ok or type(value) ~= "table" then return Bad(self, "payload") end
    if Seen(self, key) then self.stats.dup = self.stats.dup + 1; return "dup" end
    self.stats.delivered = self.stats.delivered + 1
    if self.onMessage then pcall(self.onMessage, p.kind, value, sender, channel, id) end
    return "ok"
end
