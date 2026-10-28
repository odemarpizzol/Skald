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
    { id = 53202, len = 54.8, path = "Sound\\Music\\CityMusic\\Stormwind\\stormwind01-moment.mp3" },
    { id = 53680, len = 53.8, path = "Sound\\Music\\ZoneMusic\\Plains\\DayPlains01.mp3" },
    { id = 53737, len = 47.4, path = "Sound\\Music\\ZoneMusic\\TavernAlliance\\TavernAlliance01.mp3" },
    { id = 53492, len = 55.7, path = "Sound\\Music\\ZoneMusic\\Forest\\DayForest01.mp3" },
    { id = 53216, len = 67.0, path = "Sound\\Music\\CityMusic\\Undercity\\undercity01-zone.mp3" },
    { id = 53198, len = 68.9, path = "Sound\\Music\\CityMusic\\Orgrimmar\\orgrimmar01-zone.mp3" },
    { id = 53205, len = 62.3, path = "Sound\\Music\\CityMusic\\Stormwind\\stormwind04-zone.mp3" },
    { id = 53192, len = 123.4, path = "Sound\\Music\\CityMusic\\Ironforge\\ironforge walking 01.mp3" },
    { id = 53184, len = 85.0, path = "Sound\\Music\\CityMusic\\Darnassus\\darnassus walking 1.mp3" },
    { id = 53213, len = 117.5, path = "Sound\\Music\\CityMusic\\ThunderBluff\\thunderbluff walking 01.mp3" },
    { id = 53200, len = 62.3, path = "Sound\\Music\\CityMusic\\Orgrimmar\\orgrimmar02-zone.mp3" },
    { id = 53217, len = 85.6, path = "Sound\\Music\\CityMusic\\Undercity\\undercity02-zone.mp3" },
    { id = 53739, len = 79.2, path = "Sound\\Music\\ZoneMusic\\TavernDwarf\\ra_dwarftavern1a.mp3" },
    { id = 53744, len = 48.5, path = "Sound\\Music\\ZoneMusic\\TavernHorde\\tavernhorde01.mp3" },
    { id = 53748, len = 92.6, path = "Sound\\Music\\ZoneMusic\\TavernHuman\\ra_humantavern1a.mp3" },
    { id = 53754, len = 112.3, path = "Sound\\Music\\ZoneMusic\\TavernNightElf\\ra_templeofthemoona.mp3" },
    { id = 53762, len = 82.9, path = "Sound\\Music\\ZoneMusic\\TavernPirate\\ra_piratetavern1a.mp3" },
    { id = 53747, len = 25.3, path = "Sound\\Music\\ZoneMusic\\TavernHorde\\undead_dance.mp3" },
    { id = 53495, len = 53.2, path = "Sound\\Music\\ZoneMusic\\Forest\\nightforest01.mp3" },
    { id = 53682, len = 58.4, path = "Sound\\Music\\ZoneMusic\\Plains\\nightplains01.mp3" },
    { id = 53432, len = 65.7, path = "Sound\\Music\\ZoneMusic\\Desert\\daydesert01.mp3" },
    { id = 53541, len = 46.1, path = "Sound\\Music\\ZoneMusic\\Jungle\\dayjungle01.mp3" },
    { id = 53577, len = 120.1, path = "Sound\\Music\\ZoneMusic\\Mountain\\daymountain01.mp3" },
    { id = 53426, len = 54.8, path = "Sound\\Music\\ZoneMusic\\CursedLand\\cursedland01.mp3" },
    { id = 53453, len = 49.9, path = "Sound\\Music\\ZoneMusic\\EnchantedForest\\enchantedforest01.mp3" },
    { id = 53695, len = 97.2, path = "Sound\\Music\\ZoneMusic\\SoggyPlace\\soggyplace-zone1.mp3" },
    { id = 53812, len = 72.9, path = "Sound\\Music\\ZoneMusic\\Volcanic\\dayvolcanic01.mp3" },
    { id = 53458, len = 65.3, path = "Sound\\Music\\ZoneMusic\\Eversong\\es_buildingwalkday01.mp3" },
    { id = 53278, len = 191.6, path = "Sound\\Music\\ZoneMusic\\Azuremyst\\ai_draeneiwalkuni05.mp3" },
    { id = 53585, len = 72.8, path = "Sound\\Music\\ZoneMusic\\Nagrand\\na_generalwalkday01.mp3" },
    { id = 53819, len = 81.6, path = "Sound\\Music\\ZoneMusic\\Zangarmarsh\\za_generalwalkuni01.mp3" },
    { id = 53689, len = 67.7, path = "Sound\\Music\\ZoneMusic\\ShadowmoonValley\\sv_generalwalkuni01.mp3" },
    { id = 53620, len = 150.7, path = "Sound\\Music\\ZoneMusic\\Netherstorm\\ns_generalwalkuni01.mp3" },
}

Bard.playing = nil        -- number of the piece that plays, or nil
Bard.last = nil           -- the piece that played last: Play goes back to it after a stop (the game cannot pause)
Bard.since = 0            -- GetTime() when it began
Bard.page = 1             -- the page of the list the left page shows
Bard.history = {}         -- the songs played before, for "before" when the order is by chance
Bard.PER_PAGE = 6

function Bard.Pages() return math.max(1, math.ceil(#Bard.TRACKS / Bard.PER_PAGE)) end
function Bard.PageOf(i) return math.ceil(i / Bard.PER_PAGE) end
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
    if not track or not Bard.MusicOn() or type(PlayMusic) ~= "function" then return false end
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
    local n = #Bard.TRACKS
    if n < 2 then return 1 end
    local i = math.random(1, n - 1)
    if not_this and i >= not_this then i = i + 1 end
    return i
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
    if not i then return Bard.Play(delta > 0 and 1 or n) end
    return Bard.Play((i - 1 + delta) % n + 1)
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
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local GOLD = { 0.62, 0.43, 0.08 }   -- the song that plays

    -- the left page: the title, the staff under it, the six songs, the lute and the staff at the foot
    local staffTop = panel:CreateTexture(nil, "BACKGROUND")
    staffTop:SetSize(CW, CW * 128 / 512)
    staffTop:SetPoint("TOPLEFT", 0, -28)
    staffTop:SetTexture(TEX .. "bard_staff_top")
    local lute = panel:CreateTexture(nil, "ARTWORK")
    lute:SetSize(104, 104)   -- under the last song, not over it
    lute:SetPoint("TOPLEFT", CW - 112, -366)
    lute:SetTexture(TEX .. "bard_lute")
    SkaldAPI.PageHeading(panel, L.BARD_LEFT, 0)
    SkaldAPI.PageHeading(panel, L.BARD_RIGHT, RIGHT_X)

    local rows = {}
    local refresh
    for slot = 1, Bard.PER_PAGE do
        local i = slot   -- the place on the page; the song is (page - 1) * 6 + slot
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW - 20, 40)
        row:SetPoint("TOPLEFT", 0, -112 - (i - 1) * 42)
        row.name = row:CreateFontString(nil, "OVERLAY", "SkaldSec")
        row.name:SetPoint("LEFT", 6, 0)
        row.name:SetWidth(CW - 90)
        row.name:SetJustifyH("LEFT")
        row.disc = row:CreateTexture(nil, "ARTWORK")
        row.disc:SetSize(30, 30)
        row.disc:SetPoint("RIGHT", -4, 0)
        row.disc:SetTexture(TEX .. "bard_play")
        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(1, 0.85, 0.5, 0.14)
        row:SetScript("OnClick", function(self)
            local song = self.song
            if not song then return end
            if Bard.playing == song then Bard.Stop() else Bard.Play(song) end
            if refresh then refresh() end
        end)
        rows[i] = row
    end

    -- under the list: which page of it, and the check box of the chance
    local pageNote = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    pageNote:SetPoint("TOPLEFT", 0, -374)
    pageNote:SetWidth(100)
    pageNote:SetJustifyH("LEFT")
    pageNote:SetTextColor(muted[1], muted[2], muted[3])
    local shuffleCheck = SkaldAPI.MakeCheck(panel, L.BARD_SHUFFLE, function() return Bard.Shuffle() end,
        function(on) if SkaldDB then SkaldDB.bardShuffle = on and true or false end end, nil, nil, 120)
    shuffleCheck:SetPoint("TOPLEFT", 104, -368)
    panel.shuffleCheck = shuffleCheck   -- for the tests

    -- the right page: the state, the hearth, the song, the clock, the buttons, the volume
    local state = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    state:SetPoint("TOPLEFT", RIGHT_X, -48)
    state:SetWidth(CW)
    state:SetJustifyH("CENTER")
    state:SetTextColor(muted[1], muted[2], muted[3])
    local hearth = panel:CreateTexture(nil, "ARTWORK")
    hearth:SetSize(210, 105)
    hearth:SetPoint("TOPLEFT", RIGHT_X + (CW - 210) / 2, -66)
    hearth:SetTexture(TEX .. "bard_hearth")
    local song = panel:CreateFontString(nil, "OVERLAY", "SkaldSec")
    song:SetPoint("TOPLEFT", RIGHT_X, -176)
    song:SetWidth(CW)
    song:SetJustifyH("CENTER")
    song:SetTextColor(head[1], head[2], head[3])
    local clock = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    clock:SetPoint("TOPLEFT", RIGHT_X, -198)
    clock:SetWidth(CW)
    clock:SetJustifyH("CENTER")
    clock:SetTextColor(body[1], body[2], body[3])
    local off = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    off:SetPoint("TOPLEFT", RIGHT_X + 10, -216)
    off:SetWidth(CW - 20)
    off:SetJustifyH("CENTER")
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
    local prev = Disc(48, MID - 24 - 76, -232, L.BARD_TIP_PREV, function() Bard.Step(-1); if refresh then refresh() end end)
    prev.tex:SetTexture(TEX .. "bard_prev")
    local main = Disc(72, MID - 36, -222, function() return Bard.playing and L.BARD_TIP_STOP or L.BARD_TIP_PLAY end, function()
        if Bard.playing then Bard.Stop()
        else Bard.Play(Bard.last or (Bard.Shuffle() and Bard.Random() or 1)) end
        if refresh then refresh() end
    end)
    local nextB = Disc(48, MID - 24 + 76, -232, L.BARD_TIP_NEXT, function() Bard.Step(1); if refresh then refresh() end end)
    nextB.tex:SetTexture(TEX .. "bard_next")

    -- the volume: the speaker, a brass bar and a knob; a click or a drag on the bar sets it
    local volLabel = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    volLabel:SetPoint("TOPLEFT", RIGHT_X, -312)
    volLabel:SetWidth(CW)
    volLabel:SetJustifyH("CENTER")
    volLabel:SetTextColor(muted[1], muted[2], muted[3])
    volLabel:SetText(L.BARD_VOLUME)
    local speaker = panel:CreateTexture(nil, "ARTWORK")
    speaker:SetSize(26, 26)
    speaker:SetPoint("TOPLEFT", RIGHT_X + 8, -330)
    speaker:SetTexture(TEX .. "bard_speaker")
    local BAR_W = CW - 78
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetSize(BAR_W, 14)
    bar:SetPoint("TOPLEFT", RIGHT_X + 46, -336)
    bar:EnableMouse(true)
    bar.frame = bar:CreateTexture(nil, "ARTWORK")
    bar.frame:SetSize(BAR_W * 512 / 434, 17)
    bar.frame:SetPoint("TOPLEFT", -BAR_W * 40 / 434, 1)
    bar.frame:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_bar_frame")
    bar.fill = bar:CreateTexture(nil, "OVERLAY")
    bar.fill:SetTexture("Interface\\AddOns\\Skald\\Textures\\ui_bar_fill")
    bar.fill:SetPoint("TOPLEFT", 8, -3)
    bar.fill:SetHeight(8)
    bar.max = BAR_W - 16
    local knob = CreateFrame("Frame", nil, bar)
    knob:SetSize(30, 30)
    knob:SetFrameLevel(bar:GetFrameLevel() + 3)
    knob.tex = knob:CreateTexture(nil, "OVERLAY")
    knob.tex:SetAllPoints()
    knob.tex:SetTexture(TEX .. "bard_vol_knob")
    local function ShowVolume(fraction)
        bar.value = fraction
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
    panel.volumeBar, panel.volumeKnob = bar, knob   -- for the tests
    panel.ShowVolume = ShowVolume

    -- while a song plays: notes rise by the hearth, the bars of the equaliser move, a note shows on the tab
    local rise = panel:CreateTexture(nil, "OVERLAY")
    rise:SetSize(128, 128)
    rise:SetPoint("TOPLEFT", RIGHT_X + 214, -44)
    rise:Hide()
    local bars = panel:CreateTexture(nil, "ARTWORK")
    bars:SetSize(128, 64)
    bars:SetPoint("TOPLEFT", 8, -404)
    bars:Hide()
    local tabNote
    if panel.tabButton then
        tabNote = panel.tabButton:CreateTexture(nil, "OVERLAY")
        tabNote:SetSize(16, 16)
        tabNote:SetPoint("LEFT", panel.tabButton, "LEFT", 78, 0)
        tabNote:SetTexture(TEX .. "bard_note_on")
        tabNote:Hide()
    end
    -- With the book closed, a small plate says that a song plays: a note, its name and a button to stop it. A click opens
    -- the book at this tab, a drag moves it (the place is kept), a right click hides it until the next song.
    -- The looks of the notice (the Bard tab chooses): "plate" is drawn by the code, the others are pictures (all in 512-wide
    -- canvases shown at half size): where the socket of the note, the button Stop and the name sit, in canvas points.
    -- Each picture is cut in three: the left cap (the socket of the note), a middle that is stretched and the right cap, so
    -- the notice is as wide as the name and the three buttons need (capL and capR are canvas points of the 512-wide art).
    local HUDS = {
        plate = { w = 300, h = 36 },
        bar = { w = 340, h = 64, capL = 132, capR = 440, icon = { 84, 64, 62 }, stop = { 441, 63, 48 }, textX = 132, ink = { 1, 0.94, 0.78 } },
        scroll = { w = 340, h = 64, capL = 170, capR = 420, icon = { 122, 64, 60 }, stop = { 394, 64, 48 }, textX = 160, ink = { 0.25, 0.15, 0.08 } },
        wood = { w = 340, h = 64, capL = 130, capR = 450, icon = { 80, 64, 62 }, stop = { 443, 64, 48 }, textX = 130, ink = { 1, 0.94, 0.78 } },
        medal = { w = 360, h = 128, capL = 232, capR = 440, icon = { 118, 128, 105 }, stop = { 425, 127, 52 }, textX = 232, ink = { 1, 0.94, 0.78 }, lines = 2 },
    }
    local mini = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
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
    local miniStop = SkaldAPI.MakeButton(mini, 56, 24, L.BARD_TIP_STOP)    -- the plate's own button
    miniStop:SetScript("OnClick", function() Bard.Stop(); if refresh then refresh() end end)
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
    local function ApplyHud()
        local key = Bard.HudStyle()
        local h = HUDS[key]
        local W, H = h.w, h.h
        mini:SetSize(W, H)
        -- from the right: Stop, then the song after, then the song before; the name has what is left
        local plate = key == "plate"
        local stopX = plate and (W - 6 - 25) or (W - (512 - h.stop[1]) / 2)
        local stopHalf = plate and 25 or (h.stop[3] / 4)
        local skip = plate and 24 or 26
        local nextX = stopX - stopHalf - 4 - skip / 2
        local prevX = nextX - skip - 4
        local textRight = prevX - skip / 2 - 6
        for _, b in ipairs({ miniPrev, miniNext }) do b:SetSize(skip, skip) end
        miniNext:ClearAllPoints(); miniNext:SetPoint("CENTER", mini, "TOPLEFT", nextX, -H / 2)
        miniPrev:ClearAllPoints(); miniPrev:SetPoint("CENTER", mini, "TOPLEFT", prevX, -H / 2)
        local iconX
        if plate then
            mini:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            mini:SetBackdropColor(0.20, 0.12, 0.07, 0.92)
            mini:SetBackdropBorderColor(0.75, 0.58, 0.25, 1)
            artL:Hide(); artM:Hide(); artR:Hide()
            iconX = 20
            miniIcon:ClearAllPoints(); miniIcon:SetSize(24, 24); miniIcon:SetPoint("CENTER", mini, "TOPLEFT", iconX, -H / 2)
            miniIcon:SetTexture(TEX .. "bard_note_on")
            miniName:ClearAllPoints(); miniName:SetPoint("LEFT", mini, "TOPLEFT", 38, -H / 2)
            miniName:SetWidth(textRight - 38); miniName:SetHeight(0)
            miniName:SetWordWrap(false)
            miniName:SetTextColor(1, 0.94, 0.78)
            miniStop:ClearAllPoints(); miniStop:SetPoint("CENTER", mini, "TOPLEFT", stopX, -H / 2); miniStop:Show()
            miniStopArt:Hide()
        else
            mini:SetBackdrop(nil)
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
            miniName:SetPoint("LEFT", mini, "TOPLEFT", h.textX / 2, -H / 2)
            miniName:SetWidth(textRight - h.textX / 2)
            miniName:SetHeight(h.lines and 36 or 0)
            miniName:SetWordWrap(h.lines ~= nil)
            miniName:SetTextColor(h.ink[1], h.ink[2], h.ink[3])
            miniStop:Hide()
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
        local on = Bard.playing ~= nil
        local closed = SkaldAPI.IsBookOpen and not SkaldAPI.IsBookOpen()
        local deadline = rawget(mini, "previewUntil")
        local preview = deadline and GetTime() < deadline   -- a look just chosen shows for a few seconds
        if (on and closed and rawget(mini, "hiddenFor") ~= Bard.since) or preview then
            miniName:SetText(L.BARD_TRACKS[Bard.playing or Bard.last or 1] or "")
            miniIcon:SetAlpha(0.55 + 0.45 * (0.5 + 0.5 * math.sin(GetTime() * 5)))   -- the note beats, about once in a second and a quarter
            mini:Show()
        else
            mini:Hide()
        end
        local beat = math.floor(GetTime() / 0.4)
        if on then
            rise:SetTexture(TEX .. "bard_notes_" .. (beat % 4 + 1))
            bars:SetTexture(TEX .. "bard_eq_" .. (math.floor(GetTime() / 0.3) % 3 + 1))
            rise:Show(); bars:Show()
            if tabNote then tabNote:Show() end
            clock:SetText(Clock(GetTime() - Bard.since))
        else
            rise:Hide(); bars:Hide()
            if tabNote then tabNote:Hide() end
        end
    end
    panel.Animate, panel.rise, panel.bars, panel.tabNote = Animate, rise, bars, tabNote   -- for the tests

    local note = SkaldAPI.NoteText(panel, RIGHT_X, -364)
    note:SetText(L.BARD_VOL_NOTE)

    -- the look of the notice shown with the book shut: a step back, the name (a click goes on), a step forward
    local HUD_ORDER = { "bar", "scroll", "wood", "medal", "plate" }
    local hudBack = SkaldAPI.MakeButton(panel, 44, 26, "<")
    hudBack:SetPoint("TOPLEFT", RIGHT_X, -412)
    local hudName = SkaldAPI.MakeButton(panel, 244, 26, "")
    hudName:SetPoint("TOPLEFT", RIGHT_X + 46, -412)
    local hudNext = SkaldAPI.MakeButton(panel, 44, 26, ">")
    hudNext:SetPoint("TOPLEFT", RIGHT_X + 292, -412)
    local function ShowHudName()
        local now = Bard.HudStyle()
        for i, key in ipairs(HUD_ORDER) do
            if key == now then hudName.text:SetText(string.format(L.BARD_HUD_LABEL, L.BARD_HUDS[i])) end
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
        Bard.page = math.max(1, math.min(Bard.Pages(), Bard.page or 1))
        for n, row in ipairs(rows) do
            local song = (Bard.page - 1) * Bard.PER_PAGE + n
            if Bard.TRACKS[song] then
                row.song = song
                row.name:SetText(L.BARD_TRACKS[song] or ("#" .. song))
                local on = (i == song)
                row.disc:SetTexture(TEX .. (on and "bard_pause" or "bard_play"))
                if on then row.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else row.name:SetTextColor(body[1], body[2], body[3]) end
                row:Show()
            else
                row.song = nil
                row:Hide()
            end
        end
        pageNote:SetText(string.format("%d / %d", Bard.page, Bard.Pages()))
        shuffleCheck.Sync()
        state:SetText(i and L.BARD_PLAYING or L.BARD_STOPPED)
        song:SetText(i and L.BARD_TRACKS[i] or L.BARD_PICK)
        clock:SetText(i and Clock(GetTime() - Bard.since) or "")
        main.tex:SetTexture(TEX .. (i and "bard_main_pause" or "bard_main"))
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
