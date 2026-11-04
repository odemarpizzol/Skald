-- Skald: the PvP tab, a war chronicle of the battlegrounds. It reads what the diary already keeps: the pages of kind
-- "bg" (one per match, written by Mile.CheckBattleground in Skald.lua, which this file never repeats) and the
-- permanent count per field (SkaldCharDB.stats.bgFields, kept by K.Tally, so it survives the cap on pages).
--
-- Who sees it: a character with a battleground recorded (any realm: a Normal or RP realm fights battlegrounds too), or
-- whoever asks for it with /skald pvp on. The client has no call we trust to tell the type of a realm, and the name of
-- a realm says nothing, so the tab never guesses from either (/skald probe realm lists what this client offers).
--
-- Not here yet: the open world (who struck the blow that killed you, honour, kills by land), arenas and duels. None of
-- it has been tested in a client (the combat log may hold the last hit taken before a death, with the kind of its
-- source; it is a candidate to probe, not a finding), and nothing is invented without a source that was checked.
--
-- Loaded after Cartographer.lua; it uses SkaldAPI (AddTab, Render, OpenEntry, MakeButton...).
local _, ns = ...

local UI_TEXT = {
    enUS = {
        TAB = "PvP", TITLE = "War Chronicle", FIELDS = "By field", RECENT = "Last matches",
        MATCHES = "Battlegrounds fought: %d", WON = "Won: %d", LOST = "Lost: %d", RATE = "%d%% of them won",
        HK = "Honorable kills", SEP = ": ",
        EMPTY = "No battleground yet. The first one will be written here.",
        REC = "%d won, %d lost", WON_TAG = "won", LOST_TAG = "lost", DATE = "%m/%d/%Y",
        WORLD = "The open world is not told here: the game does not say, in a way I can trust, who struck the last blow.",
        ON = "the PvP tab is always shown on this realm.", OFF = "the PvP tab is hidden on this realm (type /reload to take it away now).",
        AUTO = "on this realm the PvP tab shows itself once a battleground is written.", USAGE = "/skald pvp on | off | auto",
        PROBE_HEAD = "Realm and PvP, as this client answers (run it on the realm you want to know):",
        PROBE_FLAG = "marked for PvP: %s", PROBE_ZONE = "this land's PvP status: %s",
        PROBE_NAMES = "calls and tables of the client with realm, pvp or ruleset in the name: %s",
        PROBE_NONE = "none found", YES = "yes", NO = "no", UNKNOWN = "unknown",
    },
    ptBR = {
        TAB = "JxJ", TITLE = "Crônica de Guerra", FIELDS = "Por campo", RECENT = "Últimas partidas",
        MATCHES = "Campos de batalha disputados: %d", WON = "Vencidos: %d", LOST = "Perdidos: %d", RATE = "%d%% deles vencidos",
        HK = "Mortes honrosas", SEP = ": ",
        EMPTY = "Nenhum campo de batalha ainda. O primeiro será escrito aqui.",
        REC = "%d vencidos, %d perdidos", WON_TAG = "vitória", LOST_TAG = "derrota", DATE = "%d/%m/%Y",
        WORLD = "O mundo aberto não é contado aqui: o jogo não diz, de um jeito em que eu possa confiar, quem deu o golpe final.",
        ON = "a aba JxJ fica sempre visível neste reino.", OFF = "a aba JxJ fica escondida neste reino (digite /reload para tirá-la agora).",
        AUTO = "neste reino a aba JxJ aparece quando um campo de batalha for escrito.", USAGE = "/skald pvp on | off | auto",
        PROBE_HEAD = "Reino e JxJ, como este cliente responde (rode no reino que você quer conhecer):",
        PROBE_FLAG = "marcado para JxJ: %s", PROBE_ZONE = "estado de JxJ desta terra: %s",
        PROBE_NAMES = "chamadas e tabelas do cliente com realm, pvp ou ruleset no nome: %s",
        PROBE_NONE = "nenhuma encontrada", YES = "sim", NO = "não", UNKNOWN = "desconhecido",
    },
    frFR = {
        TAB = "JcJ", TITLE = "Chronique de guerre", FIELDS = "Par champ", RECENT = "Dernières parties",
        MATCHES = "Champs de bataille disput\195\169s\194\160: %d", WON = "Gagn\195\169s\194\160: %d", LOST = "Perdus\194\160: %d", RATE = "%d%% gagn\195\169s",
        HK = "Victoires honorables", SEP = "\194\160: ",
        EMPTY = "Pas encore de champ de bataille. Le premier sera \195\169crit ici.",
        REC = "%d gagn\195\169s, %d perdus", WON_TAG = "victoire", LOST_TAG = "d\195\169faite", DATE = "%d/%m/%Y",
        WORLD = "Le monde ouvert n'est pas racont\195\169 ici\194\160: le jeu ne dit pas, de fa\195\167on s\195\187re, qui a port\195\169 le dernier coup.",
        ON = "l'onglet JcJ est toujours montr\195\169 sur ce royaume.", OFF = "l'onglet JcJ est cach\195\169 sur ce royaume (tapez /reload pour l'enlever maintenant).",
        AUTO = "sur ce royaume l'onglet JcJ appara\195\174t quand un champ de bataille est \195\169crit.", USAGE = "/skald pvp on | off | auto",
        PROBE_HEAD = "Royaume et JcJ, comme ce client r\195\169pond (lancez-le sur le royaume que vous voulez conna\195\174tre)\194\160:",
        PROBE_FLAG = "marqu\195\169 pour le JcJ\194\160: %s", PROBE_ZONE = "\195\169tat JcJ de cette terre\194\160: %s",
        PROBE_NAMES = "appels et tables du client avec realm, pvp ou ruleset dans le nom\194\160: %s",
        PROBE_NONE = "aucun trouv\195\169", YES = "oui", NO = "non", UNKNOWN = "inconnu",
    },
}
local UI = UI_TEXT[GetLocale()] or UI_TEXT.enUS

local P = {}
ns.Pvp = P
P.UI = UI
P.TAB_ID = "pvp"
P.RECENT_ROWS, P.FIELD_ROWS = 5, 6

-- The battlegrounds of the diary, by field: { label, won, lost } for each, the busiest first, and the totals. The count
-- is the permanent one (stats.bgFields); a field told before its id was kept is listed by the name it was written with,
-- and two keys that end up with the same name in this language become one row.
function P.Data()
    local db = SkaldCharDB
    local fields = db and db.stats and db.stats.bgFields
    local byLabel, order = {}, {}
    local won, lost = 0, 0
    for key, rec in pairs(type(fields) == "table" and fields or {}) do
        if type(rec) == "table" then
            local w, l = tonumber(rec.w) or 0, tonumber(rec.l) or 0
            local label
            local id = type(key) == "string" and tonumber(key:match("^i:(%d+)$"))
            if id and GetRealZoneText then
                local ok, name = pcall(GetRealZoneText, id)
                if ok and type(name) == "string" and name ~= "" then label = name end
            end
            label = label or (type(rec.n) == "string" and rec.n ~= "" and rec.n) or (type(key) == "string" and key:gsub("^%a:", "")) or "?"
            local row = byLabel[label]
            if not row then
                row = { label = label, won = 0, lost = 0 }
                byLabel[label] = row
                order[#order + 1] = row
            end
            row.won, row.lost = row.won + w, row.lost + l
            won, lost = won + w, lost + l
        end
    end
    table.sort(order, function(a, b)
        local na, nb = a.won + a.lost, b.won + b.lost
        if na ~= nb then return na > nb end
        return a.label < b.label
    end)
    return { fields = order, won = won, lost = lost, total = won + lost }
end

-- The newest matches (pages of kind "bg"), at most `limit`.
function P.Recent(limit)
    local entries = SkaldCharDB and SkaldCharDB.entries
    local out = {}
    if not entries then return out end
    for i = #entries, 1, -1 do
        if entries[i].kind == "bg" then
            out[#out + 1] = entries[i]
            if #out >= (limit or P.RECENT_ROWS) then break end
        end
    end
    return out
end

-- The game's own count of honorable kills, when this client keeps one (the lifetime statistics of the Classic clients).
-- Nothing is shown when it does not answer with a number. (The achievement statistic 588 may hold it in Forever: not
-- used until a probe in the game confirms the id.)
function P.HonorableKills()
    if GetPVPLifetimeStats then
        local ok, hk = pcall(GetPVPLifetimeStats)
        if ok and type(hk) == "number" and hk == hk then return hk end
    end
    return nil
end

-- Wanted: a battleground is recorded (the permanent count, or an old page of the diary), or the player asked for it.
-- The switch is kept by realm (account-wide, so a diary cleared keeps it): "the realm where I fight" is the user's
-- own word, and an alt on a Normal realm is not shown a tab it did not ask for.
local function Realm()
    local ok, name = pcall(GetRealmName)
    return ok and type(name) == "string" and name ~= "" and name or "?"
end
local function Setting()
    local all = SkaldDB and SkaldDB.pvpTab
    return type(all) == "table" and all[Realm()] or nil
end
local function SetSetting(v)
    if type(SkaldDB.pvpTab) ~= "table" then SkaldDB.pvpTab = {} end
    SkaldDB.pvpTab[Realm()] = v
end
function P.Wanted()
    local setting = Setting()
    if setting == false then return false end
    if setting == true then return true end
    local db = SkaldCharDB
    local stats = db and db.stats
    if not stats then return false end
    if type(stats.bgFields) == "table" and next(stats.bgFields) ~= nil then return true end
    return (tonumber(stats.bgWins) or 0) > 0
end

-- The tab is added when it is wanted: at the login, when the first match is written and when /skald pvp on is typed.
function P.Ensure()
    if P.Wanted() and SkaldAPI and SkaldAPI.AddTab then SkaldAPI.AddTab(P.TAB_ID, UI.TAB, P.Build) end
end

-- /skald pvp [on|off|auto]: the lines to say.
function P.Command(arg)
    arg = tostring(arg or ""):lower()
    if arg == "on" then SetSetting(true); P.Ensure(); return { UI.ON }
    elseif arg == "off" then SetSetting(false); return { UI.OFF }
    elseif arg == "auto" then SetSetting(nil); P.Ensure(); return { UI.AUTO }
    end
    local now = Setting()
    return { now == true and UI.ON or now == false and UI.OFF or UI.AUTO, UI.USAGE }
end

-- /skald probe realm: what this client says about the realm and about PvP, to be read on a realm of each type. It lists
-- the names of the calls and tables that have realm, pvp or ruleset in them (names only, nothing is called).
function P.ProbeLines()
    local lines = { UI.PROBE_HEAD }
    local function Yn(v) if v == nil then return UI.UNKNOWN end return v and UI.YES or UI.NO end
    local ok, flagged = false, nil
    if UnitIsPVP then ok, flagged = pcall(UnitIsPVP, "player") end
    lines[#lines + 1] = string.format(UI.PROBE_FLAG, Yn(ok and flagged or nil))
    local status
    if GetZonePVPInfo then local okZ, s = pcall(GetZonePVPInfo); if okZ and type(s) == "string" then status = s end end
    lines[#lines + 1] = string.format(UI.PROBE_ZONE, status or UI.UNKNOWN)
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and (type(v) == "function" or type(v) == "table") then
            local low = k:lower()
            if (low:find("realm", 1, true) or low:find("pvp", 1, true) or low:find("ruleset", 1, true)) and not low:find("^skald") then
                names[#names + 1] = k
            end
        end
    end
    table.sort(names)
    local shown = {}
    for i = 1, math.min(#names, 40) do shown[i] = names[i] end
    lines[#lines + 1] = string.format(UI.PROBE_NAMES, #names > 0 and (table.concat(shown, ", ") .. (#names > 40 and " ..." or "")) or UI.PROBE_NONE)
    return lines
end

local function BuildTab(panel)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }

    local TEX = "Interface\\AddOns\\Skald\\Textures\\skald2\\"
    SkaldAPI.PageHeading(panel, UI.TITLE, 0)
    SkaldAPI.PageHeading(panel, UI.FIELDS, RIGHT_X)
    local seal = panel:CreateTexture(nil, "ARTWORK")
    seal:SetSize(34, 34)
    seal:SetPoint("TOPLEFT", panel, "TOPLEFT", 44, -2)
    seal:SetTexture(TEX .. "pvp_title_seal")

    local function Line(x, y, width, font, justify, color)
        local fs = panel:CreateFontString(nil, "OVERLAY", font or "SkaldBody")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetWidth(width)
        fs:SetJustifyH(justify or "LEFT")
        local c = color or body
        fs:SetTextColor(c[1], c[2], c[3])
        return fs
    end

    -- the left page: the totals, a bar of won against lost, the game's own count and the word about the open world
    local matches = Line(0, -60, CW, "SkaldBody")
    local wonLine = Line(0, -86, CW, "SkaldBody")
    local lostLine = Line(0, -108, CW, "SkaldBody")
    local rate = Line(0, -134, CW, "SkaldBody", "LEFT", head)
    local barBack = panel:CreateTexture(nil, "ARTWORK")
    barBack:SetPoint("TOPLEFT", 0, -164)
    barBack:SetSize(CW - 20, 10)
    barBack:SetColorTexture(0.43, 0.12, 0.10, 0.55)
    local barWon = panel:CreateTexture(nil, "OVERLAY")
    barWon:SetPoint("TOPLEFT", 0, -164)
    barWon:SetSize(1, 10)
    barWon:SetColorTexture(0.25, 0.42, 0.20, 0.85)
    local honor = Line(0, -192, CW, "SkaldBody")
    local world = Line(0, -330, CW - 20, "SkaldSmall", "LEFT", muted)
    world:SetWordWrap(true)
    world:SetText(UI.WORLD)
    local empty = Line(0, -140, CW, "SkaldBody", "CENTER", muted)
    empty:SetText(UI.EMPTY)
    empty:Hide()

    -- the right page: one row per field, then the newest matches (a click opens the page in the book)
    local fieldRows = {}
    for i = 1, P.FIELD_ROWS do
        local y = -54 - (i - 1) * 26
        fieldRows[i] = { name = Line(RIGHT_X, y, CW - 150, "SkaldBody"), rec = Line(RIGHT_X + CW - 150, y, 150, "SkaldSmall", "RIGHT", muted) }
    end
    local recentHead = Line(RIGHT_X, -54 - P.FIELD_ROWS * 26 - 14, CW, "SkaldBody", "LEFT", head)
    recentHead:SetText(UI.RECENT)
    local recentRows = {}
    for i = 1, P.RECENT_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 24)
        row:SetPoint("TOPLEFT", RIGHT_X, -54 - P.FIELD_ROWS * 26 - 40 - (i - 1) * 26)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetSize(22, 22)
        row.mark:SetPoint("LEFT", 0, 0)
        row.date = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.date:SetPoint("LEFT", 28, 0)
        row.date:SetWidth(72)
        row.date:SetJustifyH("LEFT")
        row.date:SetTextColor(muted[1], muted[2], muted[3])
        row.text = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.text:SetPoint("LEFT", 104, 0)
        row.text:SetWidth(CW - 104)
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
        recentRows[i] = row
    end

    local function Refresh()
        local data = P.Data()
        local none = data.total == 0
        empty:SetShown(none)
        for _, fs in ipairs({ matches, wonLine, lostLine, rate, honor }) do fs:SetShown(not none) end
        barBack:SetShown(not none)
        barWon:SetShown(not none)
        recentHead:SetShown(not none)
        if not none then
            matches:SetText(string.format(UI.MATCHES, data.total))
            wonLine:SetText(string.format(UI.WON, data.won))
            lostLine:SetText(string.format(UI.LOST, data.lost))
            local pct = math.floor(100 * data.won / data.total + 0.5)
            rate:SetText(string.format(UI.RATE, pct))
            barWon:SetWidth(math.max(1, (CW - 20) * data.won / data.total))
            local hk = P.HonorableKills()
            honor:SetText(hk and ((type(HONORABLE_KILLS) == "string" and HONORABLE_KILLS ~= "" and HONORABLE_KILLS or UI.HK) .. UI.SEP .. hk) or "")
        end
        for i, r in ipairs(fieldRows) do
            local f = data.fields[i]
            r.name:SetText(f and f.label or "")
            r.rec:SetText(f and string.format(UI.REC, f.won, f.lost) or "")
        end
        local recent = P.Recent()
        for i, row in ipairs(recentRows) do
            local e = recent[i]
            row.entry = e
            if e then
                row.mark:SetTexture(TEX .. (e.won and "pvp_won" or "pvp_lost"))
                row.date:SetText(e.t and date(UI.DATE, e.t) or "")
                row.text:SetText(tostring(e.arg or "?") .. ", " .. (e.won and UI.WON_TAG or UI.LOST_TAG))
                row:Show()
            else
                row:Hide()
            end
        end
    end
    P.refresh = Refresh
    return Refresh
end
P.Build = BuildTab
