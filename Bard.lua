-- Skald: the Bard's jukebox. A tab that plays six pieces of the game's own music (the music of the cities, the taverns
-- and the lands), chosen from a list; play, stop, the song before and the song after, and the volume of the game's music.
--
-- Loaded after Search.lua. The game can play a piece of music (PlayMusic) and stop it (StopMusic, which gives the sky back
-- to the music of the land), but it cannot pause, jump to a place in the song, say how long it is or say when it ends. So
-- there is a clock of the time played (counted here) and no bar of progress, and a song plays over and over until it is
-- stopped. Each piece is asked for by the number of its file and by its path (see Bard.Play).
local _, ns = ...

local L = ns.LOCALES[GetLocale()] or ns.LOCALES.enUS
local Bard = {}
ns.Bard = Bard

local TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\"

-- The pieces: the number of the music file in the game and its path (the names are in Locales.lua, BARD_TRACKS, in this order;
-- the first six are the first the Bard had). `len` is the length of the file in seconds (read from the file itself), which is how the
-- Bard knows a song has ended: the game plays a piece over and over and says nothing when it comes round. Each number was checked against the community listing of the game's files; whether the
-- Anniversary client has every file is only known by playing it.
Bard.TRACKS = {
    { id = 53202, side = "A", len = 54.8, path = "Sound\\Music\\CityMusic\\Stormwind\\stormwind01-moment.mp3" },
    { id = 53680, side = "H", len = 53.8, path = "Sound\\Music\\ZoneMusic\\Plains\\DayPlains01.mp3" },
    { id = 53737, side = "A", len = 47.4, path = "Sound\\Music\\ZoneMusic\\TavernAlliance\\TavernAlliance01.mp3" },
    { id = 53492, side = "A", len = 55.7, path = "Sound\\Music\\ZoneMusic\\Forest\\DayForest01.mp3" },
    { id = 53216, side = "H", len = 67.0, path = "Sound\\Music\\CityMusic\\Undercity\\undercity01-zone.mp3" },
    { id = 53198, side = "H", len = 68.9, path = "Sound\\Music\\CityMusic\\Orgrimmar\\orgrimmar01-zone.mp3" },
    { id = 53205, side = "A", len = 62.3, path = "Sound\\Music\\CityMusic\\Stormwind\\stormwind04-zone.mp3" },
    { id = 53192, side = "A", len = 123.4, path = "Sound\\Music\\CityMusic\\Ironforge\\ironforge walking 01.mp3" },
    { id = 53184, side = "A", len = 85.0, path = "Sound\\Music\\CityMusic\\Darnassus\\darnassus walking 1.mp3" },
    { id = 53213, side = "H", len = 117.5, path = "Sound\\Music\\CityMusic\\ThunderBluff\\thunderbluff walking 01.mp3" },
    { id = 53200, side = "H", len = 62.3, path = "Sound\\Music\\CityMusic\\Orgrimmar\\orgrimmar02-zone.mp3" },
    { id = 53217, side = "H", len = 85.6, path = "Sound\\Music\\CityMusic\\Undercity\\undercity02-zone.mp3" },
    { id = 53739, side = "A", len = 79.2, path = "Sound\\Music\\ZoneMusic\\TavernDwarf\\ra_dwarftavern1a.mp3" },
    { id = 53744, side = "H", len = 48.5, path = "Sound\\Music\\ZoneMusic\\TavernHorde\\tavernhorde01.mp3" },
    { id = 53748, side = "A", len = 92.6, path = "Sound\\Music\\ZoneMusic\\TavernHuman\\ra_humantavern1a.mp3" },
    { id = 53754, side = "A", len = 112.3, path = "Sound\\Music\\ZoneMusic\\TavernNightElf\\ra_templeofthemoona.mp3" },
    { id = 53762, len = 82.9, path = "Sound\\Music\\ZoneMusic\\TavernPirate\\ra_piratetavern1a.mp3" },
    { id = 53747, side = "H", len = 25.3, path = "Sound\\Music\\ZoneMusic\\TavernHorde\\undead_dance.mp3" },
    { id = 53495, len = 53.2, path = "Sound\\Music\\ZoneMusic\\Forest\\nightforest01.mp3" },
    { id = 53682, len = 58.4, path = "Sound\\Music\\ZoneMusic\\Plains\\nightplains01.mp3" },
    { id = 53432, len = 65.7, path = "Sound\\Music\\ZoneMusic\\Desert\\daydesert01.mp3" },
    { id = 53541, len = 46.1, path = "Sound\\Music\\ZoneMusic\\Jungle\\dayjungle01.mp3" },
    { id = 53577, len = 120.1, path = "Sound\\Music\\ZoneMusic\\Mountain\\daymountain01.mp3" },
    { id = 53426, len = 54.8, path = "Sound\\Music\\ZoneMusic\\CursedLand\\cursedland01.mp3" },
    { id = 53453, len = 49.9, path = "Sound\\Music\\ZoneMusic\\EnchantedForest\\enchantedforest01.mp3" },
    { id = 53695, len = 97.2, path = "Sound\\Music\\ZoneMusic\\SoggyPlace\\soggyplace-zone1.mp3" },
    { id = 53812, len = 72.9, path = "Sound\\Music\\ZoneMusic\\Volcanic\\dayvolcanic01.mp3" },
    { id = 53458, side = "H", era = "tbc", len = 65.3, path = "Sound\\Music\\ZoneMusic\\Eversong\\es_buildingwalkday01.mp3" },
    { id = 53278, side = "A", era = "tbc", len = 191.6, path = "Sound\\Music\\ZoneMusic\\Azuremyst\\ai_draeneiwalkuni05.mp3" },
    { id = 53585, era = "tbc", len = 72.8, path = "Sound\\Music\\ZoneMusic\\Nagrand\\na_generalwalkday01.mp3" },
    { id = 53819, era = "tbc", len = 81.6, path = "Sound\\Music\\ZoneMusic\\Zangarmarsh\\za_generalwalkuni01.mp3" },
    { id = 53689, era = "tbc", len = 67.7, path = "Sound\\Music\\ZoneMusic\\ShadowmoonValley\\sv_generalwalkuni01.mp3" },
    { id = 53620, era = "tbc", len = 150.7, path = "Sound\\Music\\ZoneMusic\\Netherstorm\\ns_generalwalkuni01.mp3" },
}

-- The pieces of the burning crusade (Eversong, Azuremyst and the lands of Outland) belong to a later time than Forever's,
-- which is set before the first raids and long before the Dark Portal opens again: there the Bard does not know them.
-- They are the last of the list, so the names in L.BARD_TRACKS keep their numbers.
if ns.IsForever and ns.IsForever() then
    for i = #Bard.TRACKS, 1, -1 do
        if Bard.TRACKS[i].era == "tbc" then table.remove(Bard.TRACKS, i) end
    end
end

Bard.playing = nil        -- number of the piece that plays, or nil
Bard.last = nil           -- the piece that played last: Play goes back to it after a stop (the game cannot pause)
Bard.since = 0            -- GetTime() when it began
Bard.page = 1             -- the page of the list the left page shows
Bard.history = {}         -- the songs played before, for "before" when the order is by chance
Bard.PER_PAGE = 6

-- The playlist: all the pieces, or only those of the Alliance or of the Horde (`side` in Bard.TRACKS; a piece without one, the
-- music of the lands, belongs to both). The choice is kept in SkaldDB.bardSide ("A", "H" or nothing). The list on the page,
-- "next", "before", the chance and the end of a song all keep to it; the numbers of the pieces (and their names) do not change.
function Bard.Side() local s = SkaldDB and SkaldDB.bardSide; if s == "A" or s == "H" then return s end return nil end
function Bard.InPool(i)
    local t = Bard.TRACKS[i]
    if not t then return false end
    local s = Bard.Side()
    return s == nil or t.side == nil or t.side == s
end
function Bard.Pool()
    local pool = {}
    for i = 1, #Bard.TRACKS do if Bard.InPool(i) then pool[#pool + 1] = i end end
    return pool
end
function Bard.SetSide(side)
    if SkaldDB then SkaldDB.bardSide = (side == "A" or side == "H") and side or nil end
    Bard.page = 1
end
function Bard.Pages() return math.max(1, math.ceil(#Bard.Pool() / Bard.PER_PAGE)) end
function Bard.PageOf(i)
    for k, v in ipairs(Bard.Pool()) do if v == i then return math.ceil(k / Bard.PER_PAGE) end end
    return Bard.page or 1
end
-- the order of the songs left to chance (the check box "Shuffle"; the game does not say when a song ends, so it
-- is "next" and "before", and the big button when nothing played yet, that choose by chance)
function Bard.Shuffle() return SkaldDB ~= nil and SkaldDB.bardShuffle == true end

-- Is the music of the game turned on? (an unknown answer counts as on)
function Bard.MusicOn()
    if type(GetCVar) ~= "function" then return true end
    local ok, all = pcall(GetCVar, "Sound_EnableAllSound")
    local ok2, music = pcall(GetCVar, "Sound_EnableMusic")
    if ok and all == "0" then return false end
    if ok2 and music == "0" then return false end
    return true
end

function Bard.Play(i)
    local track = Bard.TRACKS[i]
    if not track or type(PlayMusic) ~= "function" then return false end
    if not Bard.MusicOn() then
        -- the music of the game is off (Ctrl+M): say so in the chat too, not only on the page, once in a while
        if not Bard.warned or GetTime() - Bard.warned > 8 then
            Bard.warned = GetTime()
            print("|cffffd100Skald|r: " .. L.BARD_MUSIC_OFF)
        end
        return false
    end
    -- the number first, then the path of the same file: a client that does not know one of the two knows the other,
    -- and one that knows both just begins the same piece again at once
    local ok = pcall(PlayMusic, track.id)
    local ok2 = track.path and pcall(PlayMusic, track.path)
    if not ok and not ok2 then return false end
    if Bard.last and Bard.last ~= i and not Bard.goingBack then
        Bard.history[#Bard.history + 1] = Bard.last
        if #Bard.history > 30 then table.remove(Bard.history, 1) end
    end
    Bard.playing = i
    Bard.last = i
    Bard.page = Bard.PageOf(i)   -- the list shows the song that plays
    Bard.since = GetTime()
    return true
end

-- Called a few times a second: when the song that plays has run its length, the next one begins (by chance with Shuffle). The
-- end is a little early (a third of a second) so the first bars of the same piece are never heard again. True when it changed.
Bard.TAIL = 0.3
function Bard.Tick()
    local i = Bard.playing
    local track = i and Bard.TRACKS[i]
    if not track or not track.len then return false end
    if GetTime() - Bard.since < track.len - Bard.TAIL then return false end
    if not Bard.Step(1) then Bard.Stop() end   -- the music was turned off meanwhile: do not try again and again
    return true
end

-- a song other than the one given, by chance
function Bard.Random(not_this)
    local pool = Bard.Pool()
    local cand = {}
    for _, v in ipairs(pool) do if v ~= not_this then cand[#cand + 1] = v end end
    if #cand == 0 then return pool[1] or 1 end
    return cand[math.random(1, #cand)]
end

function Bard.Stop()
    if type(StopMusic) == "function" then pcall(StopMusic) end
    Bard.playing = nil
end

-- the song after / before, going round; stopped, it goes on from the last one played (the first / the last if none)
function Bard.Step(delta)
    local n = #Bard.TRACKS
    local i = Bard.playing or Bard.last
    if Bard.Shuffle() then
        if delta < 0 and #Bard.history > 0 then
            local back = table.remove(Bard.history)
            Bard.goingBack = true
            local ok = Bard.Play(back)
            Bard.goingBack = nil
            return ok
        end
        return Bard.Play(Bard.Random(i))
    end
    local pool = Bard.Pool()
    if #pool == 0 then return false end
    if not i then return Bard.Play(delta > 0 and pool[1] or pool[#pool]) end
    -- the next (or the one before) that is on the playlist, going round; a piece that is not on it (the side was changed) is passed
    for k = 1, n do
        local j = (i - 1 + delta * k) % n + 1
        if Bard.InPool(j) then return Bard.Play(j) end
    end
    return false
end

-- the volume of the game's music, 0..1
function Bard.Volume()
    if type(GetCVar) ~= "function" then return 1 end
    local ok, v = pcall(GetCVar, "Sound_MusicVolume")
    v = ok and tonumber(v) or 1
    return math.max(0, math.min(1, v))
end

function Bard.SetVolume(fraction)
    fraction = math.max(0, math.min(1, fraction or 0))
    if type(SetCVar) == "function" then pcall(SetCVar, "Sound_MusicVolume", string.format("%.2f", fraction)) end
    return fraction
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
Bard.Clock = Clock

local function BuildTab(panel)
    -- The footer controls reach the paper's lower margin, beyond the usual text pane.
    panel:SetPoint("BOTTOMRIGHT", panel:GetParent(), "BOTTOMRIGHT", -54, 28)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    -- The shared panes have 30/36-point pads; both Bard columns use 33 for a common page centre.
    local LEFT_X = 3
    RIGHT_X = RIGHT_X - 3
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local GOLD = { 0.62, 0.43, 0.08 }   -- the song that plays

    -- The book's own headings and fine rules frame the two pages.
    local function Heading(text, x)
        local title = SkaldAPI.PageHeading(panel, text, x)
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", x, 4)
        title:SetHeight(32)
        title:SetWordWrap(false)
    end
    Heading(L.BARD_LEFT, LEFT_X)
    Heading(L.BARD_RIGHT, RIGHT_X)

    local rows = {}
    local refresh
    for slot = 1, Bard.PER_PAGE do
        local i = slot   -- the place on the page; the song is (page - 1) * 6 + slot
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 40)
        row:SetPoint("TOPLEFT", LEFT_X, -137 - (i - 1) * 44)
        row.number = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.number:SetPoint("LEFT", 2, 0)
        row.number:SetWidth(17)
        row.number:SetJustifyH("LEFT")
        row.number:SetTextColor(muted[1], muted[2], muted[3])
        row.name = row:CreateFontString(nil, "OVERLAY", "SkaldSec")
        row.name:SetPoint("LEFT", 30, 0)
        row.name:SetWidth(CW - 57)
        row.name:SetJustifyH("LEFT")
        row.disc = row:CreateTexture(nil, "ARTWORK")
        row.disc:SetSize(20, 20)
        row.disc:SetPoint("RIGHT", -7, 0)
        row.disc:SetTexture(TEX .. "bard_play")
        row.disc:Hide()
        row.shade = row:CreateTexture(nil, "BACKGROUND")
        row.shade:SetAllPoints()
        row.shade:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
        row.shade:Hide()
        row.line = row:CreateTexture(nil, "ARTWORK")
        row.line:SetPoint("BOTTOMLEFT", 0, 0)
        row.line:SetPoint("BOTTOMRIGHT", 0, 0)
        row.line:SetHeight(1)
        row.line:SetColorTexture(muted[1], muted[2], muted[3], 0.12)
        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(1, 0.85, 0.5, 0.14)
        row:SetScript("OnClick", function(self)
            local song = self.song
            if not song then return end
            if Bard.playing == song then Bard.Stop() else Bard.Play(song) end
            if refresh then refresh() end
        end)
        row.hovered = false
        row:SetScript("OnEnter", function(self)
            self.hovered = true
            if self.song and Bard.playing ~= self.song then
                self.disc:SetTexture(TEX .. "bard_play")
                self.disc:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.hovered = false
            self.disc:SetTexture(TEX .. "bard_note_on")
            self.disc:SetShown(self.song ~= nil and Bard.playing == self.song)
        end)
        rows[i] = row
    end

    -- Repertoire above the songs; a handwritten line and folio below them.
    local pageNote = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    pageNote:SetPoint("TOPLEFT", LEFT_X, -455)
    pageNote:SetWidth(CW)
    pageNote:SetJustifyH("CENTER")
    pageNote:SetTextColor(muted[1], muted[2], muted[3])
    local quote = panel:CreateFontString(nil, "OVERLAY", "SkaldNote")
    quote:SetPoint("TOPLEFT", LEFT_X, -418)
    quote:SetSize(CW, 26)
    quote:SetJustifyH("CENTER")
    quote:SetTextColor(muted[1], muted[2], muted[3])
    quote:SetText(L.BARD_FOOTNOTE)
    local repertoire = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    repertoire:SetPoint("TOPLEFT", LEFT_X, -59)
    repertoire:SetWidth(CW)
    repertoire:SetJustifyH("CENTER")
    repertoire:SetTextColor(muted[1], muted[2], muted[3])
    repertoire:SetText(L.BARD_REPERTOIRE)
    local sideItems = {}
    local sealWidth = (CW - 16) / 3
    for n, key in ipairs({ "all", "A", "H" }) do
        local item = CreateFrame("Button", nil, panel)
        item:SetSize(sealWidth, 39)
        item:SetPoint("TOPLEFT", LEFT_X + (n - 1) * (sealWidth + 8), -78)
        item.seal = item:CreateTexture(nil, "ARTWORK")
        item.seal:SetSize(28, 28)
        item.seal:SetPoint("LEFT", 12, 0)
        if key == "all" then
            item.seal:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_seal0")
            local note = item:CreateTexture(nil, "OVERLAY")
            note:SetSize(13, 16)
            note:SetPoint("CENTER", item.seal, "CENTER", 0, 0)
            note:SetTexture(TEX .. "bard_note_on")
        else
            item.seal:SetTexture(TEX .. (key == "A" and "ui_waxseal_alliance" or "ui_waxseal_horde"))
        end
        item.text = item:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        item.text:SetPoint("LEFT", 46, 0)
        item.text:SetSize(sealWidth - 48, 20)
        item.text:SetJustifyH("LEFT")
        item.text:SetText(L.BARD_SIDE[key])
        item.line = item:CreateTexture(nil, "ARTWORK")
        item.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
        item.line:SetPoint("BOTTOMLEFT", 0, 0)
        item.line:SetPoint("BOTTOMRIGHT", 0, 0)
        item.line:SetHeight(1)
        item.hover = item:CreateTexture(nil, "HIGHLIGHT")
        item.hover:SetAllPoints()
        item.hover:SetColorTexture(1, 0.85, 0.5, 0.14)
        item.key = key
        function item.SetActive(self, on)
            self.active = on and true or false
            self.seal:SetAlpha(on and 1 or 0.65)
            if on then self.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]); self.line:Show()
            else self.text:SetTextColor(muted[1], muted[2], muted[3]); self.line:Hide() end
        end
        item:SetScript("OnClick", function()
            Bard.SetSide(key)
            if refresh then refresh() end
        end)
        item:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.BARD_SIDE_TIP, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        item:SetScript("OnLeave", function() GameTooltip:Hide() end)
        sideItems[key] = item
    end
    panel.sideItems = sideItems   -- for the tests
    local orderItems = {}
    for _, key in ipairs({ "sequential", "shuffle" }) do
        local item = CreateFrame("Button", nil, panel)
        item.mark = item:CreateTexture(nil, "ARTWORK")
        item.mark:SetSize(13, 13)
        item.mark:SetPoint("LEFT", 0, 0)
        item.text = item:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        item.text:SetPoint("LEFT", 19, 0)
        item.text:SetJustifyH("LEFT")
        item.text:SetText(key == "shuffle" and L.BARD_SHUFFLE or L.BARD_SEQUENTIAL)
        local textWidth = item.text:GetStringWidth()
        item.width = 19 + (type(textWidth) == "number" and textWidth or 65)
        item:SetSize(item.width, 23)
        item.hover = item:CreateTexture(nil, "HIGHLIGHT")
        item.hover:SetAllPoints()
        item.hover:SetColorTexture(1, 0.85, 0.5, 0.14)
        function item.SetActive(self, on)
            self.active = on and true or false
            self.mark:SetTexture("Interface\\AddOns\\Skald\\Textures\\" .. (on and "ui_rivet_on" or "ui_rivet_off"))
            local color = on and GOLD or muted
            self.text:SetTextColor(color[1], color[2], color[3])
        end
        item:SetScript("OnClick", function()
            if SkaldDB then SkaldDB.bardShuffle = key == "shuffle" end
            if refresh then refresh() end
        end)
        orderItems[key] = item
    end
    local orderWidth = orderItems.sequential.width + 26 + orderItems.shuffle.width
    local orderX = RIGHT_X + (CW - orderWidth) / 2
    orderItems.sequential:SetPoint("TOPLEFT", orderX, -368)
    orderItems.shuffle:SetPoint("TOPLEFT", orderX + orderItems.sequential.width + 26, -368)
    panel.orderItems = orderItems   -- for the tests

    -- the right page: the state, the hearth, the song, the clock, the buttons, the volume
    local state = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    state:SetPoint("TOPLEFT", RIGHT_X, -57)
    state:SetWidth(CW)
    state:SetJustifyH("CENTER")
    state:SetTextColor(muted[1], muted[2], muted[3])
    local hearth = panel:CreateTexture(nil, "ARTWORK")
    hearth:SetSize(316, 158)
    hearth:SetPoint("TOPLEFT", RIGHT_X + (CW - 316) / 2, -64)
    hearth:SetTexture(TEX .. "bard_hearth")
    local song = panel:CreateFontString(nil, "OVERLAY", "SkaldHead2")
    song:SetPoint("TOPLEFT", RIGHT_X, -229)
    song:SetSize(CW, 28)
    song:SetWordWrap(false)
    song:SetJustifyH("CENTER")
    song:SetTextColor(head[1], head[2], head[3])
    local songFont, songSize, songFlags = song:GetFont()
    local function SetSongTitle(text)
        song:SetText(text)
        if type(songFont) == "string" and type(songSize) == "number" then
            song:SetFont(songFont, songSize, songFlags)
            local width = song:GetStringWidth()
            if type(width) == "number" and width > CW then
                song:SetFont(songFont, math.max(12, songSize * CW / width), songFlags)
            end
        end
    end
    local clock = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    clock:SetPoint("TOPLEFT", RIGHT_X, -261)
    clock:SetWidth(CW)
    clock:SetJustifyH("CENTER")
    clock:SetTextColor(body[1], body[2], body[3])
    local off = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    off:SetPoint("TOPLEFT", RIGHT_X + 10, -76)
    off:SetSize(CW - 20, 100)
    off:SetJustifyH("CENTER")
    off:SetJustifyV("MIDDLE")
    off:SetTextColor(head[1], head[2], head[3])

    local function Disc(size, x, y, tip, onClick)
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(size, size)
        b:SetPoint("TOPLEFT", RIGHT_X + x, y)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            self.tex:SetVertexColor(1.15, 1.1, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(type(tip) == "function" and tip() or tip, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1); GameTooltip:Hide() end)
        return b
    end
    local MID = CW / 2
    local prev = Disc(39, MID - 113, -298.5, L.BARD_TIP_PREV, function() Bard.Step(-1); if refresh then refresh() end end)
    prev.tex:SetTexture(TEX .. "bard_prev")
    local main = Disc(60, MID - 30, -288, function() return Bard.playing and L.BARD_TIP_STOP or L.BARD_TIP_PLAY end, function()
        if Bard.playing then Bard.Stop()
        else
            local from = Bard.last
            if from and not Bard.InPool(from) then from = nil end   -- the playlist was changed since
            Bard.Play(from or (Bard.Shuffle() and Bard.Random() or Bard.Pool()[1] or 1))
        end
        if refresh then refresh() end
    end)
    local nextB = Disc(39, MID + 74, -298.5, L.BARD_TIP_NEXT, function() Bard.Step(1); if refresh then refresh() end end)
    nextB.tex:SetTexture(TEX .. "bard_next")

    -- the volume: the speaker, a brass bar and a knob; a click or a drag on the bar sets it
    local volLabel = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    local BAR_W = CW - 112
    local BAR_X = RIGHT_X + (CW - BAR_W) / 2
    volLabel:SetPoint("TOPLEFT", BAR_X, -403)
    volLabel:SetWidth(BAR_W)
    volLabel:SetJustifyH("LEFT")
    volLabel:SetTextColor(muted[1], muted[2], muted[3])
    volLabel:SetText(L.BARD_GAME_VOLUME)
    local volValue = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    volValue:SetPoint("TOPLEFT", BAR_X, -403)
    volValue:SetWidth(BAR_W)
    volValue:SetJustifyH("RIGHT")
    volValue:SetTextColor(muted[1], muted[2], muted[3])
    local speaker = panel:CreateTexture(nil, "ARTWORK")
    speaker:SetSize(21, 21)
    speaker:SetPoint("TOPLEFT", BAR_X - 28, -423)
    speaker:SetTexture(TEX .. "bard_speaker")
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetSize(BAR_W, 10)
    bar:SetPoint("TOPLEFT", BAR_X, -429)
    bar:EnableMouse(true)
    bar.frame = bar:CreateTexture(nil, "ARTWORK")
    bar.frame:SetSize(BAR_W * 512 / 434, 10)
    bar.frame:SetPoint("TOPLEFT", -BAR_W * 40 / 434, 1)
    bar.frame:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_bar_frame")
    bar.fill = bar:CreateTexture(nil, "OVERLAY")
    bar.fill:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_bar_fill")
    bar.fill:SetPoint("TOPLEFT", 8, -3)
    bar.fill:SetHeight(3)
    bar.max = BAR_W - 16
    local knob = CreateFrame("Frame", nil, bar)
    knob:SetSize(23, 23)
    knob:SetFrameLevel(bar:GetFrameLevel() + 3)
    knob.tex = knob:CreateTexture(nil, "OVERLAY")
    knob.tex:SetAllPoints()
    knob.tex:SetTexture(TEX .. "bard_vol_knob")
    local function ShowVolume(fraction)
        bar.value = fraction
        volValue:SetText(string.format("%d%%", math.floor(fraction * 100 + 0.5)))
        bar.fill:SetWidth(math.max(0.01, bar.max * fraction))
        bar.fill:SetShown(fraction > 0)
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", bar, "LEFT", 8 + bar.max * fraction, 0)
    end
    local function FromCursor()
        local left = bar.GetLeft and bar:GetLeft()
        if type(left) ~= "number" or not GetCursorPosition then return end
        local x = GetCursorPosition() / (bar:GetEffectiveScale() or 1)
        ShowVolume(Bard.SetVolume((x - left - 8) / bar.max))
    end
    bar:SetScript("OnMouseDown", function(self) self.dragging = true; FromCursor() end)
    bar:SetScript("OnMouseUp", function(self) self.dragging = false end)
    bar:SetScript("OnHide", function(self) self.dragging = false end)
    bar:SetScript("OnUpdate", function(self) if self.dragging then FromCursor() end end)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.BARD_VOL_NOTE, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.volumeBar, panel.volumeKnob = bar, knob   -- for the tests
    panel.ShowVolume = ShowVolume

    -- Playback is marked on its row and on the tab; the hearth remains one quiet illustration.
    local tabNote
    if panel.tabButton then
        tabNote = panel.tabButton:CreateTexture(nil, "OVERLAY")
        tabNote:SetSize(14, 14)
        tabNote:SetPoint("RIGHT", panel.tabButton, "RIGHT", -9, 0)
        tabNote:SetTexture(TEX .. "bard_note_on")
        tabNote:Hide()
    end
    -- With the book closed, a small plate says that a song plays: a note, its name and a button to stop it. A click opens
    -- the book at this tab, a drag moves it (the place is kept), a right click hides it until the next song.
    -- The looks of the notice (the Bard tab chooses): pictures (all in 512-wide
    -- canvases shown at half size): where the socket of the note, the button Stop and the name sit, in canvas points.
    -- Each picture is cut in three: the left cap (the socket of the note), a middle that is stretched and the right cap, so
    -- the notice is as wide as the name and the three buttons need (capL and capR are canvas points of the 512-wide art).
    local HUDS = {
        bar = { w = 340, h = 64, capL = 132, capR = 440, icon = { 82, 67, 76 }, stop = { 420, 67, 48 }, cy = 67, textX = 132, ink = { 1, 0.94, 0.78 } },
        scroll = { w = 340, h = 64, capL = 170, capR = 420, icon = { 122.5, 63, 62 }, stop = { 394, 63, 48 }, cy = 63, textX = 160, ink = { 0.25, 0.15, 0.08 } },
        wood = { w = 340, h = 64, capL = 130, capR = 450, icon = { 75.5, 66, 62 }, stop = { 415, 66, 48 }, cy = 66, textX = 130, ink = { 1, 0.94, 0.78 } },
        -- The medal's text stays in its dark inset while the center of the frame stretches to fit it.
        medal = { w = 420, h = 128, capL = 232, capR = 440, icon = { 115.5, 131, 105 }, stop = { 425, 131, 52 }, cy = 131, textX = 232, scale = 0.72, ink = { 1, 0.94, 0.78 } },
    }
    local mini = CreateFrame("Button", nil, UIParent)
    mini:SetSize(236, 36)
    mini:SetFrameStrata("HIGH")   -- over the book too: a choice of look shows at once
    mini:SetClampedToScreen(true)
    mini:SetMovable(true)
    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mini:RegisterForDrag("LeftButton")
    local pos = SkaldDB and SkaldDB.bardPos
    mini:ClearAllPoints()
    if type(pos) == "table" and pos.point and tonumber(pos.x) and tonumber(pos.y) then
        mini:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        mini:SetPoint("TOP", UIParent, "TOP", 0, -110)
    end
    local artL = mini:CreateTexture(nil, "BACKGROUND")
    local artM = mini:CreateTexture(nil, "BACKGROUND")
    local artR = mini:CreateTexture(nil, "BACKGROUND")
    local miniIcon = mini:CreateTexture(nil, "ARTWORK")
    local miniName = mini:CreateFontString(nil, "OVERLAY", "SkaldBody")
    miniName:SetJustifyH("LEFT")
    miniName:SetJustifyV("MIDDLE")
    local miniNameFont, miniNameBaseSize, miniNameFlags = miniName:GetFont()
    local nameShown, nameLook
    local function SetMiniName(text)
        local look = Bard.HudStyle and Bard.HudStyle()
        if nameShown == text and nameLook == look then return end   -- Animate asks every tick: the font is set again only for a new name or look
        nameShown, nameLook = text, look
        miniName:SetFont(miniNameFont, miniNameBaseSize, miniNameFlags)
        miniName:SetText(text or "")
        local width, textWidth = tonumber(miniName:GetWidth()), tonumber(miniName:GetStringWidth())
        if width and textWidth and width > 0 and textWidth > width then
            miniName:SetFont(miniNameFont, math.max(9, miniNameBaseSize * width / textWidth), miniNameFlags)
        end
    end
    local miniStopArt = CreateFrame("Button", nil, mini)                     -- the button Stop of a picture
    miniStopArt.tex = miniStopArt:CreateTexture(nil, "ARTWORK")
    miniStopArt.tex:SetAllPoints()
    miniStopArt:SetScript("OnClick", function() Bard.Stop(); if refresh then refresh() end end)
    miniStopArt:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(1.2, 1.15, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.BARD_TIP_STOP, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    miniStopArt:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1); GameTooltip:Hide() end)
    -- the song before and the song after, under the notice (the notice has room for the name and Stop only)
    local function SkipButton(delta, art, tip)
        local b = CreateFrame("Button", nil, mini)
        b:SetSize(26, 26)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexture(TEX .. art)
        b:SetScript("OnClick", function() Bard.Step(delta); if refresh then refresh() end end)
        b:SetScript("OnEnter", function(self)
            self.tex:SetVertexColor(1.2, 1.15, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1); GameTooltip:Hide() end)
        return b
    end
    local miniPrev = SkipButton(-1, "bard_prev", L.BARD_TIP_PREV)
    local miniNext = SkipButton(1, "bard_next", L.BARD_TIP_NEXT)

    function Bard.HudStyle()
        local key = SkaldDB and SkaldDB.bardHud
        return HUDS[key] and key or "bar"
    end
    -- Where the things of a look stand, in points from the left of the notice: from the right, Stop, then the song after, then the
    -- song before; the name has what is left (and, in a picture with a slot for it, not more than the slot).
    local function HudLayout(key)
        local h = HUDS[key] or HUDS.bar
        local W = h.w
        local stopX = W - (512 - h.stop[1]) / 2
        local stopHalf = h.stop[3] / 4
        local skip = 26
        local nextX = stopX - stopHalf - 4 - skip / 2
        local prevX = nextX - skip - 4
        local textRight = prevX - skip / 2 - 6
        if h.slot then
            local left, right = h.capL / 2, (512 - h.capR) / 2
            local slotEnd = left + (h.slot - h.capL) / (h.capR - h.capL) * (W - left - right)   -- the middle is stretched
            textRight = math.min(textRight, slotEnd - 6)
        end
        return { w = W, cy = h.cy and h.cy / 2 or h.h / 2,   -- the line the name and the buttons stand on, in points from the top
             scale = h.scale or 1, stopX = stopX, nextX = nextX, prevX = prevX, skip = skip, textLeft = h.textX / 2, textRight = textRight }
    end
    Bard.HudLayout = HudLayout
    local function ApplyHud()
        local key = Bard.HudStyle()
        local h = HUDS[key]
        local lay = HudLayout(key)
        local W, H = h.w, h.h
        mini:SetSize(W, H)
        mini:SetScale(lay.scale)
        local stopX, nextX, prevX, skip, textRight = lay.stopX, lay.nextX, lay.prevX, lay.skip, lay.textRight
        for _, b in ipairs({ miniPrev, miniNext }) do b:SetSize(skip, skip) end
        miniNext:ClearAllPoints(); miniNext:SetPoint("CENTER", mini, "TOPLEFT", nextX, -lay.cy)
        miniPrev:ClearAllPoints(); miniPrev:SetPoint("CENTER", mini, "TOPLEFT", prevX, -lay.cy)
        local iconX
        do
            local picture = TEX .. "hud_" .. key
            local left, right = h.capL / 2, (512 - h.capR) / 2
            artL:ClearAllPoints(); artL:SetPoint("TOPLEFT", mini, "TOPLEFT", 0, 0); artL:SetSize(left, H)
            artL:SetTexture(picture); artL:SetTexCoord(0, h.capL / 512, 0, 1)
            artR:ClearAllPoints(); artR:SetPoint("TOPRIGHT", mini, "TOPRIGHT", 0, 0); artR:SetSize(right, H)
            artR:SetTexture(picture); artR:SetTexCoord(h.capR / 512, 1, 0, 1)
            artM:ClearAllPoints(); artM:SetPoint("TOPLEFT", mini, "TOPLEFT", left, 0); artM:SetPoint("BOTTOMRIGHT", mini, "BOTTOMRIGHT", -right, 0)
            artM:SetTexture(picture); artM:SetTexCoord(h.capL / 512, h.capR / 512, 0, 1)
            artL:Show(); artM:Show(); artR:Show()
            iconX = h.icon[1] / 2
            miniIcon:ClearAllPoints(); miniIcon:SetSize(h.icon[3] / 2, h.icon[3] / 2)
            miniIcon:SetPoint("CENTER", mini, "TOPLEFT", iconX, -h.icon[2] / 2)
            miniIcon:SetTexture(TEX .. "hud_" .. key .. "_icon")
            miniName:ClearAllPoints()
            miniName:SetPoint("LEFT", mini, "TOPLEFT", h.textX / 2, -lay.cy)
            miniName:SetWidth(textRight - h.textX / 2)
            miniName:SetHeight(24)
            miniName:SetWordWrap(false)   -- one line: a name that is too long is cut at the end of the room, never put on a second line
            miniName:SetTextColor(h.ink[1], h.ink[2], h.ink[3])
            miniStopArt:ClearAllPoints(); miniStopArt:SetSize(h.stop[3] / 2, h.stop[3] / 2)
            miniStopArt:SetPoint("CENTER", mini, "TOPLEFT", stopX, -h.stop[2] / 2)
            miniStopArt.tex:SetTexture(TEX .. "hud_" .. key .. "_stop")
            miniStopArt:Show()
        end
    end
    ApplyHud()
    mini:SetScript("OnClick", function(self, button)
        if button == "RightButton" then rawset(self, "hiddenFor", Bard.since); rawset(self, "previewUntil", nil); self:Hide()
        elseif SkaldAPI.OpenSection then SkaldAPI.OpenSection("bard") end
    end)
    mini:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mini:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if SkaldDB and point and tonumber(x) and tonumber(y) then SkaldDB.bardPos = { point = point, x = x, y = y } end
    end)
    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.BARD_MINI_TIP, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mini:Hide()
    panel.mini, panel.miniStopArt, panel.ApplyHud = mini, miniStopArt, ApplyHud
    panel.miniPrev, panel.miniNext = miniPrev, miniNext   -- for the tests

    local function Animate()
        local musicOn = Bard.MusicOn()
        off:SetText(musicOn and "" or L.BARD_MUSIC_OFF)
        hearth:SetShown(musicOn)
        local on = Bard.playing ~= nil
        local closed = SkaldAPI.IsBookOpen and not SkaldAPI.IsBookOpen()
        local deadline = rawget(mini, "previewUntil")
        local preview = deadline and GetTime() < deadline   -- a look just chosen shows for a few seconds
        if (on and closed and rawget(mini, "hiddenFor") ~= Bard.since) or preview then
            SetMiniName(L.BARD_TRACKS[Bard.playing or Bard.last or 1] or "")
            miniIcon:SetAlpha(0.55 + 0.45 * (0.5 + 0.5 * math.sin(GetTime() * 5)))   -- the note beats, about once in a second and a quarter
            mini:Show()
        else
            mini:Hide()
        end
        if on then
            if tabNote then tabNote:Show() end
            clock:SetText(Clock(GetTime() - Bard.since))
        else
            if tabNote then tabNote:Hide() end
        end
    end
    panel.Animate, panel.tabNote = Animate, tabNote   -- for the tests

    -- the look of the notice shown with the book shut: a step back, the name (a click goes on), a step forward
    local HUD_ORDER = { "bar", "scroll", "wood", "medal" }
    local caption = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    caption:SetPoint("TOPLEFT", RIGHT_X + 44, -457)
    caption:SetSize(86, 20)
    caption:SetJustifyH("RIGHT")
    caption:SetTextColor(muted[1], muted[2], muted[3])
    caption:SetText(L.BARD_HUD_CLOSED)
    local function HudChoice(text, x, width)
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(width, 20)
        button:SetPoint("TOPLEFT", RIGHT_X + x, -457)
        button.text = button:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        button.text:SetAllPoints()
        button.text:SetJustifyH("CENTER")
        button.text:SetTextColor(muted[1], muted[2], muted[3])
        button.text:SetText(text)
        button:SetScript("OnEnter", function(self)
            self.text:SetTextColor(head[1], head[2], head[3])
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L.BARD_HUD_TIP, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            self.text:SetTextColor(muted[1], muted[2], muted[3])
            GameTooltip:Hide()
        end)
        return button
    end
    local hudBack = HudChoice("‹", 134, 18)
    local hudName = HudChoice("", 156, 120)
    local hudNext = HudChoice("›", 280, 18)
    local function ShowHudName()
        local now = Bard.HudStyle()
        for i, key in ipairs(HUD_ORDER) do
            if key == now then hudName.text:SetText(L.BARD_HUDS[i]) end
        end
    end
    local function StepHud(delta)
        local now = 1
        for i, key in ipairs(HUD_ORDER) do if key == Bard.HudStyle() then now = i end end
        if SkaldDB then SkaldDB.bardHud = HUD_ORDER[(now - 1 + delta) % #HUD_ORDER + 1] end
        ApplyHud()
        rawset(mini, "hiddenFor", nil)
        rawset(mini, "previewUntil", GetTime() + 5)
        ShowHudName()
        Animate()
    end
    hudBack:SetScript("OnClick", function() StepHud(-1) end)
    hudName:SetScript("OnClick", function() StepHud(1) end)
    hudNext:SetScript("OnClick", function() StepHud(1) end)
    panel.hudName, panel.hudBack, panel.hudNext = hudName, hudBack, hudNext   -- for the tests

    -- a frame of its own (the page's frames sleep while the page is hidden) moves the pictures a few times a second
    local driver = CreateFrame("Frame")
    local acc = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.15 then return end
        acc = 0
        local changed = Bard.Tick()
        if changed and refresh then refresh() end
        Animate()
    end)

    refresh = function()
        local i = Bard.playing
        local pool = Bard.Pool()
        Bard.page = math.max(1, math.min(Bard.Pages(), Bard.page or 1))
        for n, row in ipairs(rows) do
            local song = pool[(Bard.page - 1) * Bard.PER_PAGE + n]
            if song then
                row.song = song
                row.name:SetText(L.BARD_TRACKS[song] or ("#" .. song))
                row.number:SetText(string.format("%02d", (Bard.page - 1) * Bard.PER_PAGE + n))
                local on = (i == song)
                row.active = on
                row.shade:SetShown(on)
                row.disc:SetTexture(TEX .. (on and "bard_note_on" or "bard_play"))
                row.disc:SetShown(on or row.hovered)
                row.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.4 or 0.12)
                if on then row.name:SetTextColor(head[1], head[2], head[3]) else row.name:SetTextColor(body[1], body[2], body[3]) end
                row:Show()
            else
                row.song = nil
                row:Hide()
            end
        end
        pageNote:SetText(string.format("%d / %d", Bard.page, Bard.Pages()))
        orderItems.sequential:SetActive(not Bard.Shuffle())
        orderItems.shuffle:SetActive(Bard.Shuffle())
        for _, key in ipairs({ "all", "A", "H" }) do sideItems[key]:SetActive(key == (Bard.Side() or "all")) end
        state:SetText(i and L.BARD_PLAYING or L.BARD_STOPPED)
        SetSongTitle(i and L.BARD_TRACKS[i] or L.BARD_PICK)
        clock:SetText(i and Clock(GetTime() - Bard.since) or "")
        main.tex:SetTexture(TEX .. (i and "hud_medal_stop" or "bard_main"))
        off:SetText(Bard.MusicOn() and "" or L.BARD_MUSIC_OFF)
        ShowHudName()
        Animate()
        ShowVolume(Bard.Volume())
    end
    panel.rows, panel.state, panel.song, panel.clock, panel.mainButton = rows, state, song, clock, main   -- for the tests
    panel.prevButton, panel.nextButton, panel.off, panel.Refresh = prev, nextB, off, refresh
    panel:HookScript("OnShow", refresh)
    refresh()
    -- the corners of the book turn the pages of the list
    local pager = {
        Turn = function(delta) Bard.page = math.max(1, math.min(Bard.Pages(), (Bard.page or 1) + delta)) end,
        CanPrev = function() return (Bard.page or 1) > 1 end,
        CanNext = function() return (Bard.page or 1) < Bard.Pages() end,
    }
    panel.pager = pager
    return refresh, pager
end

SkaldAPI.AddTab("bard", L.BARD_TAB, BuildTab)
