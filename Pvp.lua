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
    deDE = {
        TAB = "PvP",
        TITLE = "Kriegschronik",
        FIELDS = "Nach Schlachtfeld",
        RECENT = "Letzte Schlachten",
        WON_WORD = "Siege",
        LOST_WORD = "Niederlagen",
        MATCHES = "Gespielte Schlachtfelder: %d",
        WON = "Siege: %d",
        LOST = "Niederlagen: %d",
        RATE = "%d%% davon gewonnen",
        HK = "Ehrenhafte Siege",
        SEP = ": ",
        EMPTY = "Noch kein Schlachtfeld. Das erste wird hier festgehalten.",
        EMPTY_HINT = "Jede Schlacht, gewonnen oder verloren, wird hier nach Schlachtfeld verzeichnet.",
        REC = "%d Siege, %d Niederlagen",
        WON_TAG = "gewonnen",
        LOST_TAG = "verloren",
        DATE = "%d.%m.%Y",
        WORLD = "Hier zeichne ich vorerst nur die Kämpfe auf Schlachtfeldern auf.",
        LINES = {
            "Die Banner fielen und wurden wieder erhoben; unter jedem von ihnen war ich dabei.",
            "Ein Feld ist nur Erde, bis jemand darauf blutet. Dann erhält es einen Namen.",
            "Ich trug meine Farben aufs Feld, und das Feld behielt, was es wollte.",
            "Manche Kriege misst man in Jahren. Meinen misst man in Nachmittagen voller Staub und Stahl.",
            "Die Hörner klingen mir noch in den Ohren, und das nächste Feld ruft bereits.",
            "Jede Fahne, die ich hob, hatte vor mir jemand getragen. Ich trage sie für jene, die nach mir kommen.",
            "Ich zähle nicht die Gefallenen. Ich zähle die Morgen, an denen ich wieder zu den Waffen griff.",
            "Sieg schmeckt nach Staub, Niederlage nach Eisen. Beides habe ich geschluckt.",
            "Der Krieg verlangt von der Feder nur eines: dass sie sich erinnert.",
            "Hinter mir liegt ein langer Weg aus Schlachtfeldern. Vor mir wartet ein Banner darauf, erhoben zu werden.",
        },
        ON = "Die PvP-Seite wird auf diesem Realm immer angezeigt.",
        OFF = "Die PvP-Seite ist auf diesem Realm ausgeblendet.",
        AUTO = "Auf diesem Realm erscheint die PvP-Seite nach dem ersten aufgezeichneten Schlachtfeld.",
        USAGE = "/skald pvp on | off | auto | demo",
        DEMO_ON = "Vorschau mit Beispielzahlen: Im Tagebuch wird nichts gespeichert. /skald pvp demo beendet die Vorschau.",
        DEMO_OFF = "Vorschau beendet.",
        DEMO_NOTE = "Beispielzahlen, nicht deine",
        PROBE_HEAD = "Realm und PvP laut diesem Client (auf dem zu prüfenden Realm ausführen):",
        PROBE_FLAG = "Für PvP markiert: %s",
        PROBE_ZONE = "PvP-Status dieses Gebiets: %s",
        PROBE_WANT = "PvP selbst eingeschaltet: %s; PvP-Timer läuft: %s",
        PROBE_WAR = "Kriegsmodus: gibt es %s, gewünscht %s, aktiv %s; C_PvP dazu: %s",
        KPROBE_ON = "Sonde für PvP-Siege an: Besiege einen Spieler der anderen Fraktion, dann /reload. Bisher gespeichert: %d.",
        KPROBE_OFF = "Sonde für PvP-Siege aus (%d gespeichert).",
        KPROBE_SEEN = "Sonde: %s gesehen (%d gespeichert).",
        PROBE_NAMES = "Clientfunktionen und Tabellen mit realm, pvp oder ruleset im Namen: %s",
        PROBE_NONE = "keine gefunden",
        YES = "ja",
        NO = "nein",
        UNKNOWN = "unbekannt",
    },
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
        PROBE_WANT = "PvP switched on by you: %s; leaving timer running: %s",
        PROBE_WAR = "War Mode: exists %s, wanted %s, active %s; C_PvP about it: %s",
        KPROBE_ON = "PvP kill probe on: slay a player of the other faction, then /reload. Kept so far: %d.",
        KPROBE_OFF = "PvP kill probe off (%d kept).", KPROBE_SEEN = "probe: %s seen (%d kept).",
        PROBE_NAMES = "calls and tables of the client with realm, pvp or ruleset in the name: %s",
        PROBE_NONE = "none found", YES = "yes", NO = "no", UNKNOWN = "unknown",
    }, esES = {
            TAB = "JcJ",
            TITLE = "Crónica de guerra",
            FIELDS = "Por campo",
            RECENT = "Últimos encuentros",
            WON_WORD = "victorias",
            LOST_WORD = "derrotas",
            MATCHES = "Campos disputados: %d",
            WON = "Victorias: %d",
            LOST = "Derrotas: %d",
            RATE = "%d%% de victorias",
            HK = "Muertes con honor",
            SEP = ": ",
            EMPTY = "Aún no hay campos de batalla. El primero tendrá su lugar aquí.",
            EMPTY_HINT = "Cada encuentro, ganado o perdido, quedará marcado campo por campo.",
            REC = "%d victorias, %d derrotas",
            WON_TAG = "victoria",
            LOST_TAG = "derrota",
            DATE = "%d/%m/%Y",
            WORLD = "Por ahora guardo aquí solo las batallas de los campos de batalla.",
            LINES = {
                "He visto caer y alzarse nuestros estandartes, y he seguido bajo sus colores.",
                "El campo guarda el recuerdo de quienes lo cruzamos cuando sonaron los cuernos.",
                "Llevé mis colores hasta el encuentro y regresé con una historia distinta.",
                "Mis batallas tienen tardes de polvo, hierro y nombres que no olvido.",
                "Todavía escucho los cuernos cuando el siguiente campo empieza a llamar.",
                "Alcé una bandera que alguien llevó antes que yo; algún día la llevarán otras manos.",
                "Recuerdo cada amanecer en que volví a reunir el ánimo para partir.",
                "He conocido el polvo de la victoria y el peso de la derrota.",
                "Mis páginas no cambian el resultado de la batalla, pero pueden impedir que se pierda.",
                "Detrás de mí quedan los campos recorridos; delante, unos colores que aún quiero sostener.",
            },
            ON = "la pestaña JcJ se muestra siempre en este reino.",
            OFF = "la pestaña JcJ está oculta en este reino.",
            AUTO = "en este reino la pestaña JcJ aparece cuando se registra un campo de batalla.",
            USAGE = "/skald pvp on | off | auto | demo",
            DEMO_ON = "vista de ejemplo: no escribe nada en el diario. Usa /skald pvp demo otra vez para salir.",
            DEMO_OFF = "vista de ejemplo cerrada.",
            DEMO_NOTE = "Cifras de ejemplo, no las tuyas",
            PROBE_HEAD = "Reino y JcJ según este cliente (ejecuta la prueba en el reino que quieras comprobar):",
            PROBE_FLAG = "marcado para JcJ: %s",
            PROBE_ZONE = "estado JcJ de esta zona: %s",
            PROBE_WANT = "JcJ activado por ti: %s; temporizador de salida en marcha: %s",
            PROBE_WAR = "Modo Guerra: existe %s, deseado %s, activo %s; C_PvP al respecto: %s",
            KPROBE_ON = "sonda de muertes JcJ activada: mata a un jugador de la otra facción y luego /reload. Guardados hasta ahora: %d.",
            KPROBE_OFF = "sonda de muertes JcJ desactivada (%d guardados).",
            KPROBE_SEEN = "sonda: %s visto (%d guardados).",
            PROBE_NAMES = "funciones y tablas del cliente con realm, pvp o ruleset en el nombre: %s",
            PROBE_NONE = "no se encontró ninguna",
            YES = "sí",
            NO = "no",
            UNKNOWN = "desconocido",
        },
    ptBR = {
        TAB = "JxJ", TITLE = "Crônica de Guerra", FIELDS = "Por campo", RECENT = "Últimas partidas",
        WON_WORD = "vitórias", LOST_WORD = "derrotas", MATCHES = "Campos de batalha disputados: %d", WON = "Vencidos: %d", LOST = "Perdidos: %d", RATE = "%d%% deles vencidos",
        HK = "Mortes honrosas", SEP = ": ",
        EMPTY = "Nenhum campo de batalha ainda. O primeiro será escrito aqui.",
        EMPTY_HINT = "Cada partida, vencida ou perdida, será marcada aqui, campo por campo.",
        REC = "Vitórias: %d; derrotas: %d", WON_TAG = "vitória", LOST_TAG = "derrota", DATE = "%d/%m/%Y",
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
        PROBE_WANT = "JxJ ligado por você: %s; contador de saída correndo: %s",
        PROBE_WAR = "Modo Guerra: existe %s, desejado %s, ativo %s; C_PvP sobre isso: %s",
        KPROBE_ON = "sonda de abates JxJ ligada: mate um jogador da outra facção e depois /reload. Guardados até agora: %d.",
        KPROBE_OFF = "sonda de abates JxJ desligada (%d guardados).", KPROBE_SEEN = "sonda: %s visto (%d guardados).",
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
        PROBE_WANT = "JcJ activ\195\169 par vous\194\160: %s\194\160; minuteur de sortie en cours\194\160: %s",
        PROBE_WAR = "Mode Guerre\194\160: existe %s, souhait\195\169 %s, actif %s\194\160; C_PvP \195\160 ce sujet\194\160: %s",
        KPROBE_ON = "sonde des victoires JcJ activ\195\169e\194\160: tuez un joueur de l'autre faction, puis /reload. Gard\195\169s jusqu'ici\194\160: %d.",
        KPROBE_OFF = "sonde des victoires JcJ arr\195\170t\195\169e (%d gard\195\169s).", KPROBE_SEEN = "sonde\194\160: %s vu (%d gard\195\169s).",
        PROBE_NAMES = "appels et tables du client avec realm, pvp ou ruleset dans le nom\194\160: %s",
        PROBE_NONE = "aucun trouv\195\169", YES = "oui", NO = "non", UNKNOWN = "inconnu",
    },
}
UI_TEXT.esMX = UI_TEXT.esES
local UI = UI_TEXT[ns.LocaleKey()] or UI_TEXT.enUS

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

-- Wanted: the client says the server is PvP, a battleground is recorded (the permanent count, or an old page of the
-- diary), or the player asked for it.
-- The switch is kept by realm (account-wide, so a diary cleared keeps it): "the realm where I fight" is the user's
-- own word, and an alt on a Normal realm is not shown a tab it did not ask for.
local function Realm()
    local ok, name = pcall(GetRealmName)
    return ok and type(name) == "string" and name ~= "" and name or "?"
end
local function Setting()
    local all = SkaldDB and SkaldDB.pvpTab
    if type(all) ~= "table" then return nil end
    return all[Realm()]   -- false is kept as false: "off" must win over a match recorded or a PvP server
end
local function SetSetting(v)
    if type(SkaldDB.pvpTab) ~= "table" then SkaldDB.pvpTab = {} end
    SkaldDB.pvpTab[Realm()] = v
end
-- The kind of server, where the client says it: the Forever client keeps it among its game rules (Enum.GameRule.PvPRuleset,
-- read on a PvP realm as active with the value 1; /skald probe server shows it). A client without the rule says nothing
-- and the tab waits for a battleground as before; the realm's name is never used to guess.
function P.PvPRealm()
    local rule = type(Enum) == "table" and type(Enum.GameRule) == "table" and Enum.GameRule.PvPRuleset
    local rules = type(C_GameRules) == "table" and C_GameRules
    if not (rule and rules and type(rules.IsGameRuleActive) == "function" and type(rules.GetGameRuleAsFloat) == "function") then
        return false
    end
    local okA, active = pcall(rules.IsGameRuleActive, rule)
    if not (okA and active) then return false end
    local okV, v = pcall(rules.GetGameRuleAsFloat, rule)
    return okV and v == 1
end
function P.Wanted()
    if P.demo then return true end
    local setting = Setting()
    if setting == false then return false end
    if setting == true then return true end
    if P.PvPRealm() then return true end
    local db = SkaldCharDB
    local stats = db and db.stats
    if not stats then return false end
    if type(stats.bgFields) == "table" and next(stats.bgFields) ~= nil then return true end
    return (tonumber(stats.bgWins) or 0) > 0
end

-- /skald probe kills [off]: what the client says when the player slays someone in the open world, kept in
-- SkaldDB.probeKills (at most 30 records) to be read from the saved file. While it is on, its own frame listens to the
-- combat log (only PARTY_KILL, and UNIT_DIED of a player), PLAYER_PVP_KILLS_CHANGED and the honour line of the chat;
-- each record says which fields the client withheld (secret), the land, the PvP flag and the game's honorable kills.
-- Nothing of this writes a page: it is to learn which source to trust before the diary uses one.
local KP_MAX = 30
local kpFrame
local function KpSay(msg) print("|cffffd100Skald|r: " .. msg) end
local function Secret(v) return _G.issecretvalue and issecretvalue(v) or false end
local function LifetimeHK()
    if not GetPVPLifetimeStats then return nil end
    local ok, hk = pcall(GetPVPLifetimeStats)
    if ok and not Secret(hk) then return hk end
end
local function KpRecord(rec)
    local list = SkaldDB.probeKills
    if type(list) ~= "table" then list = {}; SkaldDB.probeKills = list end
    rec.t = time and time() or nil
    rec.hk = LifetimeHK()
    local okZ, zone = pcall(GetRealZoneText); rec.zone = okZ and not Secret(zone) and zone or nil
    local okS, sub = pcall(GetSubZoneText); rec.sub = okS and not Secret(sub) and sub ~= "" and sub or nil
    if UnitIsPVP then local okF, f = pcall(UnitIsPVP, "player"); if okF and not Secret(f) then rec.flagged = f and true or false end end
    list[#list + 1] = rec
    while #list > KP_MAX do table.remove(list, 1) end
    KpSay(string.format(UI.KPROBE_SEEN, tostring(rec.sub_ or rec.ev), #list))
end
local function KpCombatLog()
    if not CombatLogGetCurrentEventInfo then return end
    local ok, _, sub, _, srcGUID, _, srcFlags, _, destGUID, _, destFlags = pcall(CombatLogGetCurrentEventInfo)
    if not ok then return end
    if Secret(sub) then
        -- the client hides even the kind of event: kept once in a while, to know that it does
        local list = SkaldDB.probeKills
        if not (type(list) == "table" and list.secretSeen) then
            KpRecord({ ev = "CLEU", sub_ = "CLEU (secret)", secret = "sub" })
            SkaldDB.probeKills.secretSeen = true
        end
        return
    end
    if sub ~= "PARTY_KILL" and sub ~= "UNIT_DIED" then return end
    local destPlayer = (not Secret(destGUID)) and type(destGUID) == "string" and destGUID:find("^Player%-") ~= nil or nil
    if sub == "UNIT_DIED" and not destPlayer then return end
    local me = UnitGUID and UnitGUID("player")
    local hidden = {}
    for name, v in pairs({ src = srcGUID, srcFlags = srcFlags, dest = destGUID, destFlags = destFlags }) do
        if Secret(v) then hidden[#hidden + 1] = name end
    end
    table.sort(hidden)
    local rec = { ev = "CLEU", sub_ = sub, destPlayer = destPlayer, secret = #hidden > 0 and table.concat(hidden, ",") or nil }
    if not Secret(srcGUID) then rec.mine = (srcGUID == me) end
    if not Secret(destFlags) and type(destFlags) == "number" and bit and bit.band then
        rec.hostile = bit.band(destFlags, 0x40) ~= 0          -- COMBATLOG_OBJECT_REACTION_HOSTILE
        rec.destIsPlayerType = bit.band(destFlags, 0x400) ~= 0 -- COMBATLOG_OBJECT_TYPE_PLAYER
        rec.destFlags = string.format("0x%X", destFlags)
    end
    if not Secret(srcFlags) and type(srcFlags) == "number" then rec.srcFlags = string.format("0x%X", srcFlags) end
    KpRecord(rec)
end
local function KpOnEvent(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then return KpCombatLog() end
    local args = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        args[i] = Secret(v) and "(secret)" or tostring(v)
    end
    KpRecord({ ev = event, sub_ = event, args = table.concat(args, " | ") })
end
local KP_EVENTS = { "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_PVP_KILLS_CHANGED", "CHAT_MSG_COMBAT_HONOR_GAIN" }
function P.KillProbeSync()
    local on = SkaldDB and SkaldDB.probeKillsOn and true or false
    if on and not kpFrame and CreateFrame then
        kpFrame = CreateFrame("Frame")
        kpFrame:SetScript("OnEvent", function(...) pcall(KpOnEvent, ...) end)
    end
    if not kpFrame then return end
    for _, ev in ipairs(KP_EVENTS) do
        if on then pcall(kpFrame.RegisterEvent, kpFrame, ev) else pcall(kpFrame.UnregisterEvent, kpFrame, ev) end
    end
end
function P.KillProbe(arg)
    if arg == "off" then SkaldDB.probeKillsOn = nil else SkaldDB.probeKillsOn = true end
    P.KillProbeSync()
    local n = type(SkaldDB.probeKills) == "table" and #SkaldDB.probeKills or 0
    return SkaldDB.probeKillsOn and string.format(UI.KPROBE_ON, n) or string.format(UI.KPROBE_OFF, n)
end

-- The tab is added when it is wanted: at the login, when the first match is written and when /skald pvp on is typed.
function P.Ensure()
    pcall(P.KillProbeSync)   -- a kill probe left on goes on listening after a /reload
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
    -- the names first and the readings last, so the readings are the lines left in sight at the foot of the chat;
    -- frames (tables that are not a C_ namespace) are left out, they are windows of the interface, not answers
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and (type(v) == "function" or (type(v) == "table" and k:find("^C_"))) then
            local low = k:lower()
            if (low:find("realm", 1, true) or low:find("pvp", 1, true) or low:find("ruleset", 1, true)) and not low:find("^skald") then
                names[#names + 1] = k
            end
        end
    end
    table.sort(names)
    local shown = {}
    for i = 1, math.min(#names, 60) do shown[i] = names[i] end
    lines[#lines + 1] = string.format(UI.PROBE_NAMES, #names > 0 and (table.concat(shown, ", ") .. (#names > 60 and " ..." or "")) or UI.PROBE_NONE)
    local flagged
    if UnitIsPVP then local ok, f = pcall(UnitIsPVP, "player"); if ok then flagged = f and true or false end end
    lines[#lines + 1] = string.format(UI.PROBE_FLAG, Yn(flagged))
    -- the land's status with the place it was read in (and the faction the client names, if any)
    local status, place = UI.UNKNOWN, {}
    if GetZonePVPInfo then
        local okZ, st, _, faction = pcall(GetZonePVPInfo)
        if okZ and type(st) == "string" then status = st end
        if okZ and type(faction) == "string" and faction ~= "" then place[#place + 1] = faction end
    end
    for _, fn in ipairs({ GetRealZoneText, GetSubZoneText }) do
        local okN, n = pcall(fn)
        if okN and type(n) == "string" and n ~= "" then place[#place + 1] = n end
    end
    if #place > 0 then status = status .. " (" .. table.concat(place, ", ") .. ")" end
    lines[#lines + 1] = string.format(UI.PROBE_ZONE, status)
    -- a PvP realm marks the player in a contested land without asking: flagged, not desired, no timer running
    local desired, timer
    if GetPVPDesired then local okD, d = pcall(GetPVPDesired); if okD and d ~= nil then desired = d and true or false end end
    if IsPVPTimerRunning then local okT, t = pcall(IsPVPTimerRunning); if okT and t ~= nil then timer = t and true or false end end
    lines[#lines + 1] = string.format(UI.PROBE_WANT, Yn(desired), Yn(timer))
    -- a modern client may have War Mode in place of realm types: whether it exists, is wanted and is on, and the
    -- names of C_PvP that speak of war, realms, rules or flags (names only, nothing else is called)
    local pvp = type(C_PvP) == "table" and C_PvP or {}
    local function Ask(name)
        if type(pvp[name]) ~= "function" then return nil end
        local okA, v = pcall(pvp[name])
        if okA and v ~= nil then return v and true or false end
    end
    local warNames = {}
    for k, v in pairs(pvp) do
        if type(k) == "string" and type(v) == "function" then
            local low = k:lower()
            if low:find("war", 1, true) or low:find("realm", 1, true) or low:find("rule", 1, true) or low:find("flag", 1, true) or low:find("inactive", 1, true) then
                warNames[#warNames + 1] = k
            end
        end
    end
    table.sort(warNames)
    lines[#lines + 1] = string.format(UI.PROBE_WAR, Yn(Ask("IsWarModeFeatureEnabled")), Yn(Ask("IsWarModeDesired")),
        Yn(Ask("IsWarModeActive")), #warNames > 0 and table.concat(warNames, ", ") or UI.PROBE_NONE)
    return lines
end

-- /skald probe server: every call of the client with realm, server or ruleset in its name (C_ namespaces too), and
-- the answers of those that only read (Get/Is/Can with no argument), to look for the type of the realm.
local function Show(v)
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do
            if #parts >= 12 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and "{...}" or tostring(x))
        end
        return "{" .. table.concat(parts, " ") .. "}"
    end
    return tostring(v)
end
local function Answer(fn)
    local res = { pcall(fn) }
    if not res[1] then return "(erro)" end
    local out = {}
    for i = 2, math.max(#res, 2) do out[#out + 1] = Show(res[i]) end
    return table.concat(out, ", ")
end
local function Wanted(k)
    local low = k:lower()
    return low:find("realm", 1, true) or low:find("server", 1, true) or low:find("ruleset", 1, true)
end
function P.ServerLines()
    local lines = { UI.PROBE_HEAD }
    local found = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and not k:lower():find("^skald") then
            if type(v) == "function" and Wanted(k) then
                found[#found + 1] = { k, v }
            elseif type(v) == "table" and k:find("^C_") then
                for fk, fv in pairs(v) do
                    if type(fk) == "string" and type(fv) == "function" and (Wanted(k) or Wanted(fk)) then
                        found[#found + 1] = { k .. "." .. fk, fv }
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return a[1] < b[1] end)
    for _, f in ipairs(found) do
        local short = f[1]:match("([^%.]+)$")
        if short:find("^Get") or short:find("^Is") or short:find("^Can") then
            lines[#lines + 1] = f[1] .. "() = " .. Answer(f[2])
        else
            lines[#lines + 1] = f[1]
        end
    end
    if #found == 0 then lines[#lines + 1] = UI.PROBE_NONE end
    -- a modern client may say the kind of server through its game rules and game modes, not through the realm
    local rules = type(C_GameRules) == "table" and C_GameRules or nil
    if rules then
        local names = {}
        for k, v in pairs(rules) do if type(k) == "string" and type(v) == "function" then names[#names + 1] = k end end
        table.sort(names)
        for _, k in ipairs(names) do
            if k:find("^Get") or k:find("^Is") or k:find("^Does") or k:find("^Has") then
                lines[#lines + 1] = "C_GameRules." .. k .. "() = " .. Answer(rules[k])
            else
                lines[#lines + 1] = "C_GameRules." .. k
            end
        end
    end
    -- every enum about game rules or game modes: the keys that speak of PvP or of the realm, and what the rules say of them
    local enum = type(Enum) == "table" and Enum or {}
    local enums = {}
    for k, v in pairs(enum) do
        local low = type(k) == "string" and k:lower() or ""
        if type(v) == "table" and (low:find("gamerule", 1, true) or low:find("gamemode", 1, true) or low:find("ruleset", 1, true) or low:find("realm", 1, true)) then
            enums[#enums + 1] = k
        end
    end
    table.sort(enums)
    for _, en in ipairs(enums) do
        local keys = {}
        for k, v in pairs(enum[en]) do
            local low = tostring(k):lower()
            if low:find("pvp", 1, true) or low:find("war", 1, true) or low:find("realm", 1, true) or low:find("mode", 1, true) or low:find("flag", 1, true) then
                local said = ""
                if rules and en:lower():find("gamerule", 1, true) then
                    for _, fn in ipairs({ "IsGameRuleActive", "GetGameRuleAsFloat" }) do
                        if type(rules[fn]) == "function" then
                            local okR, r = pcall(rules[fn], v)
                            said = said .. " " .. fn .. "=" .. (okR and Show(r) or "(erro)")
                        end
                    end
                end
                keys[#keys + 1] = tostring(k) .. "=" .. tostring(v) .. said
            end
        end
        table.sort(keys)
        local count = 0
        for _ in pairs(enum[en]) do count = count + 1 end
        lines[#lines + 1] = "Enum." .. en .. " (" .. count .. "): " .. (#keys > 0 and table.concat(keys, "; ") or "-")
    end
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
        ns.ThemeText(fs, c[1], c[2], c[3])
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
        ns.ThemeText(fs, color[1], color[2], color[3])
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
        ns.ThemeText(row.date, muted[1], muted[2], muted[3])
        row.text = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.text:SetPoint("LEFT", 104, 0)
        row.text:SetWidth(CW - 104)
        row.text:SetJustifyH("LEFT")
        ns.ThemeText(row.text, body[1], body[2], body[3])
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        ns.ThemeFill(row.hover, 0.43, 0.12, 0.10, 0.08, "hover")
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
