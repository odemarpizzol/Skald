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
        WON_WORD = "victories", LOST_WORD = "defeats", MATCHES = "Battlegrounds fought: %d", WON = "Won: %d", LOST = "Lost: %d", RATE = "%d%% of them won",
        HK = "Honorable kills", SEP = ": ",
        EMPTY = "No battleground yet. The first one will be written here.",
        EMPTY_HINT = "Each match, won or lost, will be marked here, field by field.",
        REC = "%d victories, %d defeats", WON_TAG = "won", LOST_TAG = "lost", DATE = "%m/%d/%Y",
        WORLD = "For now, I record here only the battles of the battlegrounds.",
        LINES = {
            "The banners have fallen and risen again, and I was there under each.",
            "A field is only ground until someone bleeds on it. Then it is a name.",
            "I carried my colours to the field, and the field kept what it wanted.",
            "Some wars are told in years. Mine is told in afternoons of dust and steel.",
            "The horns still ring in my ears, and the next field is already calling.",
            "Every flag I raised was carried by someone before me. I carry it for someone after.",
            "I do not count the fallen. I count the dawns I took up arms again.",
            "Victory tastes of dust, and defeat of iron. I have swallowed both.",
            "The war asks nothing of the pen, only that it remember.",
            "Behind me, a long road of battlefields. Ahead, a banner waiting to be lifted.",
        },
        ON = "the PvP tab is always shown on this realm.", OFF = "the PvP tab is hidden on this realm.",
        AUTO = "on this realm the PvP tab shows itself once a battleground is written.", USAGE = "/skald pvp on | off | auto | demo",
        DEMO_ON = "preview with example numbers: nothing is written in the diary. Type /skald pvp demo again to leave it.", DEMO_OFF = "preview ended.", DEMO_NOTE = "Example numbers, not yours",
        PROBE_HEAD = "Realm and PvP, as this client answers (run it on the realm you want to know):",
        PROBE_FLAG = "marked for PvP: %s", PROBE_ZONE = "this land's PvP status: %s",
        PROBE_NAMES = "calls and tables of the client with realm, pvp or ruleset in the name: %s",
        PROBE_NONE = "none found", YES = "yes", NO = "no", UNKNOWN = "unknown",
    },
    ptBR = {
        TAB = "JxJ", TITLE = "Crônica de Guerra", FIELDS = "Por campo", RECENT = "Últimas partidas",
        WON_WORD = "vitórias", LOST_WORD = "derrotas", MATCHES = "Campos de batalha disputados: %d", WON = "Vencidos: %d", LOST = "Perdidos: %d", RATE = "%d%% deles vencidos",
        HK = "Mortes honrosas", SEP = ": ",
        EMPTY = "Nenhum campo de batalha ainda. O primeiro será escrito aqui.",
        EMPTY_HINT = "Cada partida, vencida ou perdida, será marcada aqui, campo por campo.",
        REC = "%d vitórias, %d derrotas", WON_TAG = "vitória", LOST_TAG = "derrota", DATE = "%d/%m/%Y",
        WORLD = "Por ora, registro aqui apenas as batalhas nos campos.",
        LINES = {
            "As bandeiras caíram e se ergueram de novo, e eu estive sob cada uma delas.",
            "Um campo é só chão até que alguém sangre nele. Depois, é um nome.",
            "Levei minhas cores ao campo, e o campo guardou o que quis.",
            "Algumas guerras se contam em anos. A minha se conta em tardes de poeira e aço.",
            "As trompas ainda ecoam nos meus ouvidos, e o próximo campo já chama.",
            "Cada bandeira que ergui foi carregada por alguém antes de mim. Eu a carrego por alguém depois.",
            "Não conto os caídos. Conto as manhãs em que peguei em armas de novo.",
            "A vitória tem gosto de poeira, e a derrota, de ferro. Engoli as duas.",
            "A guerra nada pede à pena, só que ela se lembre.",
            "Atrás de mim, uma longa estrada de campos de batalha. À frente, uma bandeira esperando para ser erguida.",
        },
        ON = "a aba JxJ fica sempre visível neste reino.", OFF = "a aba JxJ fica escondida neste reino.",
        AUTO = "neste reino a aba JxJ aparece quando um campo de batalha for escrito.", USAGE = "/skald pvp on | off | auto | demo",
        DEMO_ON = "prévia com números de exemplo: nada é escrito no diário. Digite /skald pvp demo de novo para sair.", DEMO_OFF = "prévia encerrada.", DEMO_NOTE = "Números de exemplo, não são seus",
        PROBE_HEAD = "Reino e JxJ, como este cliente responde (rode no reino que você quer conhecer):",
        PROBE_FLAG = "marcado para JxJ: %s", PROBE_ZONE = "estado de JxJ desta terra: %s",
        PROBE_NAMES = "chamadas e tabelas do cliente com realm, pvp ou ruleset no nome: %s",
        PROBE_NONE = "nenhuma encontrada", YES = "sim", NO = "não", UNKNOWN = "desconhecido",
    },
    frFR = {
        TAB = "JcJ", TITLE = "Chronique de guerre", FIELDS = "Par champ", RECENT = "Dernières parties",
        WON_WORD = "victoires", LOST_WORD = "d\195\169faites", MATCHES = "Champs de bataille disput\195\169s\194\160: %d", WON = "Gagn\195\169s\194\160: %d", LOST = "Perdus\194\160: %d", RATE = "%d%% gagn\195\169s",
        HK = "Victoires honorables", SEP = "\194\160: ",
        EMPTY = "Pas encore de champ de bataille. Le premier sera \195\169crit ici.",
        EMPTY_HINT = "Chaque partie, gagn\195\169e ou perdue, sera marqu\195\169e ici, champ par champ.",
        REC = "%d victoires, %d d\195\169faites", WON_TAG = "victoire", LOST_TAG = "d\195\169faite", DATE = "%d/%m/%Y",
        WORLD = "Pour l'instant, je ne consigne ici que les batailles des champs.",
        LINES = {
            "Les banni\195\168res sont tomb\195\169es et se sont relev\195\169es, et j'\195\169tais l\195\160 sous chacune d'elles.",
            "Un champ n'est que de la terre jusqu'\195\160 ce que quelqu'un y saigne. Ensuite, c'est un nom.",
            "J'ai port\195\169 mes couleurs jusqu'au champ, et le champ a gard\195\169 ce qu'il voulait.",
            "Certaines guerres se racontent en ann\195\169es. La mienne se raconte en longs apr\195\168s-midi de poussi\195\168re et d'acier.",
            "Les cors r\195\169sonnent encore \195\160 mes oreilles, et le prochain champ m'appelle d\195\169j\195\160.",
            "Chaque drapeau que j'ai dress\195\169, quelqu'un l'avait port\195\169 avant moi. Je le porte pour quelqu'un apr\195\168s moi.",
            "Je ne compte pas les tomb\195\169s. Je compte les aubes o\195\185 j'ai repris les armes.",
            "La victoire a un go\195\187t de poussi\195\168re, la d\195\169faite un go\195\187t de fer. J'ai aval\195\169 les deux.",
            "La guerre ne demande rien \195\160 la plume, seulement qu'elle se souvienne.",
            "Derri\195\168re moi, une longue route de champs de bataille. Devant, une banni\195\168re qui attend d'\195\170tre lev\195\169e.",
        },
        ON = "l'onglet JcJ est toujours montr\195\169 sur ce royaume.", OFF = "l'onglet JcJ est cach\195\169 sur ce royaume.",
        AUTO = "sur ce royaume l'onglet JcJ appara\195\174t quand un champ de bataille est \195\169crit.", USAGE = "/skald pvp on | off | auto | demo",
        DEMO_ON = "aper\195\167u avec des chiffres d'exemple\194\160: rien n'est \195\169crit dans le journal. Tapez /skald pvp demo \195\160 nouveau pour le quitter.", DEMO_OFF = "aper\195\167u termin\195\169.", DEMO_NOTE = "Chiffres d'exemple, pas les v\195\180tres",
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
P.TEXTS = UI_TEXT
P.TAB_ID = "pvp"
P.RECENT_ROWS, P.FIELD_ROWS = 5, 6

-- The battlegrounds of the diary, by field: { label, won, lost } for each, the busiest first, and the totals. The count
-- is the permanent one (stats.bgFields); a field told before its id was kept is listed by the name it was written with,
-- and two keys that end up with the same name in this language become one row.
-- /skald pvp demo: the tab drawn with example numbers, to see how it looks before a battleground is fought. The
-- numbers are made here and shown only; nothing is written in the diary, and it ends with the session.
local function Zone(id, fallback)
    if GetRealZoneText then
        local ok, name = pcall(GetRealZoneText, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return fallback
end
function P.Sample()
    local fields = {
        { label = Zone(489, "Warsong Gulch"), won = 9, lost = 5 },
        { label = Zone(529, "Arathi Basin"), won = 6, lost = 4 },
        { label = Zone(30, "Alterac Valley"), won = 3, lost = 2 },
        { label = Zone(566, "Eye of the Storm"), won = 2, lost = 3 },
    }
    local won, lost = 0, 0
    for _, f in ipairs(fields) do won, lost = won + f.won, lost + f.lost end
    return { fields = fields, won = won, lost = lost, total = won + lost }
end
function P.SampleRecent()
    local now = time()
    local out = {}
    for i, row in ipairs({ { 489, "Warsong Gulch", true }, { 529, "Arathi Basin", false }, { 489, "Warsong Gulch", true },
        { 30, "Alterac Valley", true }, { 566, "Eye of the Storm", false } }) do
        out[i] = { kind = "bg", t = now - i * 86400, arg = Zone(row[1], row[2]), won = row[3], sample = true }
    end
    return out
end

-- A line of the diary for the page: drawn from the list by the date of the diary's first page and the matches
-- fought, so it holds still while the page is open and moves on with each match. None of them has a number.
function P.Line(total)
    local list = UI.LINES
    if type(list) ~= "table" or #list == 0 then return "" end
    local stats = SkaldCharDB and SkaldCharDB.stats
    local first = tonumber(stats and stats.first) or 0
    return list[(math.floor(first) + (total or 0)) % #list + 1]
end

function P.Data()
    if P.demo then return P.Sample() end
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
    if P.demo then return P.SampleRecent() end
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
    if P.demo then return 1234 end
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
    if P.demo then return true end
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
    if not (SkaldAPI and SkaldAPI.AddTab) then return end
    if P.Wanted() then
        SkaldAPI.AddTab(P.TAB_ID, UI.TAB, P.Build)
        if SkaldAPI.SetTabShown then SkaldAPI.SetTabShown(P.TAB_ID, true) end
    elseif SkaldAPI.SetTabShown then
        SkaldAPI.SetTabShown(P.TAB_ID, false)
    end
end

-- /skald pvp [on|off|auto]: the lines to say.
function P.Command(arg)
    arg = tostring(arg or ""):lower()
    if arg == "demo" then
        P.demo = not P.demo or nil
        P.Ensure()
        if P.demo and SkaldAPI.OpenSection then SkaldAPI.OpenSection(P.TAB_ID) end
        if P.refresh then pcall(P.refresh) end
        return { P.demo and UI.DEMO_ON or UI.DEMO_OFF }
    end
    if arg == "on" then SetSetting(true); P.Ensure(); return { UI.ON }
    elseif arg == "off" then SetSetting(false); P.Ensure(); return { UI.OFF }
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
    SkaldAPI.PageHeading(panel, UI.FIELDS, RIGHT_X)
    -- the seal stands to the left of the title's own letters, whatever the language makes of their width
    local title = SkaldAPI.PageHeading(panel, UI.TITLE, 0)
    local seal = panel:CreateTexture(nil, "ARTWORK")
    seal:SetSize(40, 40)
    local okW, titleW = pcall(function() return title:GetStringWidth() end)
    titleW = (okW and type(titleW) == "number") and titleW or 200
    seal:SetPoint("TOPRIGHT", panel, "TOPLEFT", CW / 2 - titleW / 2 - 6, 2)
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
    local demoNote = Line(0, -44, CW, "SkaldSmall", "CENTER", head)
    demoNote:SetText(UI.DEMO_NOTE)
    demoNote:Hide()
    -- two banners side by side, the numbers large under each and the share of wins in a faded seal between them
    local function Centre(cx, y, width, font, color)
        local fs = panel:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOP", panel, "TOPLEFT", cx, y)
        fs:SetWidth(width)
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(color[1], color[2], color[3])
        return fs
    end
    local GREEN, WINE = { 0.25, 0.42, 0.20 }, { 0.43, 0.12, 0.10 }
    local LX, MX, RX = CW * 0.2, CW * 0.5, CW * 0.8
    local wonBanner = panel:CreateTexture(nil, "ARTWORK")
    wonBanner:SetSize(80, 80)
    wonBanner:SetPoint("TOP", panel, "TOPLEFT", LX, -66)
    wonBanner:SetTexture(TEX .. "pvp_won")
    local lostBanner = panel:CreateTexture(nil, "ARTWORK")
    lostBanner:SetSize(80, 80)
    lostBanner:SetPoint("TOP", panel, "TOPLEFT", RX, -66)
    lostBanner:SetTexture(TEX .. "pvp_lost")
    local wonNum = Centre(LX, -150, 110, "SkaldHead", GREEN)
    local lostNum = Centre(RX, -150, 110, "SkaldHead", WINE)
    local wonWord = Centre(LX, -184, 110, "SkaldSmall", muted)
    wonWord:SetText(UI.WON_WORD)
    local lostWord = Centre(RX, -184, 110, "SkaldSmall", muted)
    lostWord:SetText(UI.LOST_WORD)
    local medal = panel:CreateTexture(nil, "ARTWORK")
    medal:SetSize(78, 78)
    medal:SetPoint("TOP", panel, "TOPLEFT", MX, -76)
    medal:SetTexture(TEX .. "pvp_title_seal")
    medal:SetAlpha(0.3)
    local pctText = Centre(MX, -150, 90, "SkaldHead", head)
    local matches = Line(0, -226, CW, "SkaldBody", "CENTER")
    local honor = Line(0, -252, CW, "SkaldBody", "CENTER")
    local story = Line(30, -300, CW - 60, "SkaldBody", "CENTER", body)
    story:SetWordWrap(true)
    local world = Line(0, -380, CW - 20, "SkaldSmall", "LEFT", muted)
    world:SetWordWrap(true)
    world:SetText(UI.WORLD)
    local empty = Line(0, -140, CW, "SkaldBody", "CENTER", muted)
    empty:SetText(UI.EMPTY)
    empty:Hide()
    -- the right page of a diary with no battleground yet: the seal large and faded, and a line under it
    local emptySeal = panel:CreateTexture(nil, "ARTWORK")
    emptySeal:SetSize(110, 110)
    emptySeal:SetPoint("TOP", panel, "TOPLEFT", RIGHT_X + CW / 2, -120)
    emptySeal:SetTexture(TEX .. "pvp_title_seal")
    emptySeal:SetAlpha(0.4)
    emptySeal:Hide()
    local emptyHint = Line(RIGHT_X + 20, -250, CW - 40, "SkaldBody", "CENTER", muted)
    emptyHint:SetWordWrap(true)
    emptyHint:SetText(UI.EMPTY_HINT)
    emptyHint:Hide()

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
        demoNote:SetShown(P.demo == true)
        emptySeal:SetShown(none)
        emptyHint:SetShown(none)
        story:SetShown(not none)
        story:SetText(none and "" or P.Line(data.total))
        for _, region in ipairs({ matches, honor, wonBanner, lostBanner, wonNum, lostNum, wonWord, lostWord, medal, pctText }) do
            region:SetShown(not none)
        end
        recentHead:SetShown(not none)
        if not none then
            matches:SetText(string.format(UI.MATCHES, data.total))
            wonNum:SetText(tostring(data.won))
            lostNum:SetText(tostring(data.lost))
            pctText:SetText(math.floor(100 * data.won / data.total + 0.5) .. "%")
            local hk = P.HonorableKills()
            honor:SetText(hk and ((type(HONORABLE_KILLS) == "string" and HONORABLE_KILLS ~= "" and HONORABLE_KILLS or UI.HK) .. UI.SEP .. hk) or "")
        end
        for i, r in ipairs(fieldRows) do
            local f = data.fields[i]
            r.name:SetText(f and f.label or "")
            r.rec:SetText(f and string.format(UI.REC, f.won, f.lost) or "")
        end
        -- "Last matches" follows the last field listed, not a fixed place, so a few fields leave no gap
        local listed = math.max(1, math.min(#data.fields, P.FIELD_ROWS))
        local top = -54 - listed * 26 - 22
        recentHead:ClearAllPoints()
        recentHead:SetPoint("TOPLEFT", RIGHT_X, top)
        for i, row in ipairs(recentRows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", RIGHT_X, top - 28 - (i - 1) * 28)
        end
        local recent = P.Recent()
        for i, row in ipairs(recentRows) do
            local e = recent[i]
            row.entry = e and not e.sample and e or nil   -- an example page is not in the book
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
