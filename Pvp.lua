-- Skald: the PvP tab, a war chronicle with separate spreads for the open world, battlegrounds and arena.
-- Battlegrounds read what the diary already keeps: the pages of kind
-- "bg" (one per match, written by Mile.CheckBattleground in Skald.lua, which this file never repeats) and the
-- permanent count per field (SkaldCharDB.stats.bgFields, kept by K.Tally, so it survives the cap on pages).
--
-- Who sees it: a character with a battleground recorded (any realm: a Normal or RP realm fights battlegrounds too), or
-- whoever asks for it with /skald pvp on. The client has no call we trust to tell the type of a realm, and the name of
-- a realm says nothing, so the tab never guesses from either (/skald probe realm lists what this client offers).
--
-- The open world: honorable kills and honour by land, from the game's own count (P.WorldCount, seen in Forever).
-- Blood debts pair a confirmed death with a later kill of the same player GUID, outside instances.
-- Arenas and duels are left out. The restricted combat log is never requested in Forever.
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
        WORLD = "Ehrenhafte Siege außerhalb der Schlachtfelder werden hier nach Gebiet verzeichnet.",
        WORLD_HEAD = "Offene Welt", WORLD_SUM = "Siege: %d · Ehre: %d", WORLD_ZONE = "%d Siege, %d Ehre",
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
        KPROBE_ON = "Sonde für PvP-Siege an: sammelt ohne Chatmeldungen bis /reload oder /skald probe kills off. Bisher gespeichert: %d.",
        KPROBE_OFF = "Sonde für PvP-Siege aus (%d gespeichert).",
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
        WORLD = "Honorable kills outside the battlegrounds are written here, land by land.",
        WORLD_HEAD = "Open world", WORLD_SUM = "Kills: %d · Honor: %d", WORLD_ZONE = "%d kills, %d honor",
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
        KPROBE_ON = "PvP kill probe on: collecting silently until /reload or /skald probe kills off. Kept so far: %d.",
        KPROBE_OFF = "PvP kill probe off (%d kept).",
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
            WORLD = "Las muertes honorables fuera de los campos de batalla se anotan aquí, tierra por tierra.",
            WORLD_HEAD = "Mundo abierto", WORLD_SUM = "Muertes: %d · Honor: %d", WORLD_ZONE = "%d muertes, %d de honor",
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
            KPROBE_ON = "sonda de muertes JcJ activada: recoge datos sin mensajes hasta /reload o /skald probe kills off. Guardados hasta ahora: %d.",
            KPROBE_OFF = "sonda de muertes JcJ desactivada (%d guardados).",
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
        WORLD = "Os abates honrosos fora dos campos de batalha ficam anotados aqui, terra por terra.",
        WORLD_HEAD = "Mundo aberto", WORLD_SUM = "Abates: %d · Honra: %d", WORLD_ZONE = "%d abates, %d de honra",
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
        KPROBE_ON = "sonda de abates JxJ ligada: coleta em silêncio até /reload ou /skald probe kills off. Guardados até agora: %d.",
        KPROBE_OFF = "sonda de abates JxJ desligada (%d guardados).",
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
        WORLD = "Les victoires honorables hors des champs de bataille sont not\195\169es ici, terre par terre.",
        WORLD_HEAD = "Monde ouvert", WORLD_SUM = "Victoires\194\160: %d · Honneur\194\160: %d", WORLD_ZONE = "%d victoires, %d d'honneur",
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
        KPROBE_ON = "sonde des victoires JcJ activ\195\169e\194\160: collecte silencieuse jusqu'\195\160 /reload ou /skald probe kills off. Gard\195\169s jusqu'ici\194\160: %d.",
        KPROBE_OFF = "sonde des victoires JcJ arr\195\170t\195\169e (%d gard\195\169s).",
        PROBE_NAMES = "appels et tables du client avec realm, pvp ou ruleset dans le nom\194\160: %s",
        PROBE_NONE = "aucun trouv\195\169", YES = "oui", NO = "non", UNKNOWN = "inconnu",
    },
}
UI_TEXT.esMX = UI_TEXT.esES
local UI = UI_TEXT[ns.LocaleKey()] or UI_TEXT.enUS

local P = {}
ns.Pvp = P
local R = { cache = {}, MAX_RIVALS = 256, CACHE_MAX = 80, ROWS = 6 }
P.Rivals = R
P.UI = UI
P.TEXTS = UI_TEXT
P.TAB_ID = "pvp"
P.RECENT_ROWS, P.FIELD_ROWS, P.WORLD_ROWS = 5, 6, 6
local CH = ns.PVP_CHAPTER_TEXT[ns.LocaleKey()] or ns.PVP_CHAPTER_TEXT.enUS
local RV = ns.PVP_REVENGE_TEXT[ns.LocaleKey()] or ns.PVP_REVENGE_TEXT.enUS

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
    local w = db.worldPvp
    if type(w) == "table" and type(w.zones) == "table" and next(w.zones) ~= nil then return true end
    if type(w) == "table" and type(w.rivals) == "table" and next(w.rivals) ~= nil then return true end
    return (tonumber(stats.bgWins) or 0) > 0
end

-- /skald probe kills [off]: what the client says when the player slays someone in the open world, kept in
-- SkaldDB.probeKills (at most 30 records) to be read from the saved file. While it is on, its own frame listens to the
-- combat log (only PARTY_KILL, and UNIT_DIED of a player), PLAYER_PVP_KILLS_CHANGED, the honour line of the chat and the death of the player (PLAYER_DEAD);
-- each record says which fields the client withheld (secret), the land, the PvP flag and the game's honorable kills.
-- Nothing of this writes a page: it is to learn which source to trust before the diary uses one.
-- Collection is silent and must be explicitly enabled again after each reload; saved records remain available.
local KP_MAX = 30
local kpFrame
local kpSession
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
-- What the client tells when the player dies, without the combat log (forbidden in Forever): the target and the hostile
-- players whose nameplates are shown, and every Get/Has/Is function of a death recap (DeathRecap*, C_DeathInfo) called
-- without arguments, read at the death and again two seconds later (the recap may come after PLAYER_DEAD).
local function KpUnit(u)
    if not (UnitExists and UnitIsPlayer) then return nil end
    local okE, ex = pcall(UnitExists, u)
    if not okE or Secret(ex) or not ex then return nil end
    local okP, isPlayer = pcall(UnitIsPlayer, u)
    if not okP or Secret(isPlayer) or not isPlayer then return nil end
    local parts = {}
    local okN, name = pcall(UnitName, u); parts[#parts + 1] = (okN and not Secret(name) and name) or "?"
    local okL, lvl = pcall(UnitLevel, u); if okL and not Secret(lvl) then parts[#parts + 1] = tostring(lvl) end
    if UnitCanAttack then
        local okA, foe = pcall(UnitCanAttack, "player", u)
        if okA and not Secret(foe) then parts[#parts + 1] = foe and "hostile" or "friend" end
    end
    return table.concat(parts, " ")
end
local function KpRecap()
    local out = {}
    local function try(label, fn)
        local ok, a, b = pcall(fn)
        if not ok then out[#out + 1] = label .. "=error"
        elseif Secret(a) then out[#out + 1] = label .. "=(secret)"
        elseif type(a) == "table" then out[#out + 1] = label .. "=table#" .. #a
        else out[#out + 1] = label .. "=" .. tostring(a) .. (b ~= nil and ("," .. (Secret(b) and "(secret)" or tostring(b))) or "") end
    end
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "function" and k:find("DeathRecap") then names[#names + 1] = k end
    end
    table.sort(names)
    for _, k in ipairs(names) do
        if k:find("^Get") or k:find("^Has") or k:find("^Is") or k:find("^DeathRecap_Has") or k:find("^DeathRecap_Get") then try(k, _G[k]) end
    end
    local di = type(C_DeathInfo) == "table" and C_DeathInfo
    if di then
        local keys = {}
        for k, v in pairs(di) do if type(v) == "function" then keys[#keys + 1] = k end end
        table.sort(keys)
        out[#out + 1] = "C_DeathInfo:" .. table.concat(keys, ",")
        for _, k in ipairs(keys) do
            if k:find("^Get") or k:find("^Has") or k:find("^Is") then try("C_DeathInfo." .. k, di[k]) end
        end
    end
    return #names > 0 and table.concat(names, ",") or nil, table.concat(out, " ; ")
end
local function KpDeath(when)
    local rec = { ev = "PLAYER_DEAD", sub_ = "PLAYER_DEAD" .. (when and (" +" .. when .. "s") or "") }
    rec.target = KpUnit("target")
    local near = {}
    for i = 1, 40 do
        local u = KpUnit("nameplate" .. i)
        if u and u:find("hostile$") then near[#near + 1] = u end
    end
    rec.hostileNear = #near > 0 and table.concat(near, "; ") or nil
    rec.recapNames, rec.recap = KpRecap()
    if R.ProbeRecap then rec.fatal = R.ProbeRecap() end
    KpRecord(rec)
end
local function KpOnEvent(_, event, ...)
    if not kpSession then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then return KpCombatLog() end
    if event == "PLAYER_DEAD" then
        KpDeath()
        local session = kpSession
        if C_Timer and C_Timer.After then C_Timer.After(2, function() if kpSession == session then pcall(KpDeath, 2) end end) end
        return
    end
    local args = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        args[i] = Secret(v) and "(secret)" or tostring(v)
    end
    KpRecord({ ev = event, sub_ = event, args = table.concat(args, " | ") })
end
-- The Forever client forbids the combat log to addons: asking for it raised the game's "action blocked" window (seen on
-- 2026-11-23). A client with secret values (issecretvalue) is that family, so it is never asked there.
local function KpEvents()
    local list = { "PLAYER_PVP_KILLS_CHANGED", "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_DEAD", "PARTY_KILL" }
    if not _G.issecretvalue then table.insert(list, 1, "COMBAT_LOG_EVENT_UNFILTERED") end
    return list
end
function P.KillProbeSync()
    if SkaldDB then SkaldDB.probeKillsOn = nil end -- discard the old persistent switch
    local on = kpSession ~= nil
    if on and not kpFrame and CreateFrame then
        kpFrame = CreateFrame("Frame")
        kpFrame:SetScript("OnEvent", function(...) pcall(KpOnEvent, ...) end)
    end
    if not kpFrame then return end
    for _, ev in ipairs(KpEvents()) do
        if on then pcall(kpFrame.RegisterEvent, kpFrame, ev) else pcall(kpFrame.UnregisterEvent, kpFrame, ev) end
    end
end
function P.KillProbe(arg)
    if arg == "off" then kpSession = nil else kpSession = {} end
    P.KillProbeSync()
    local n = type(SkaldDB.probeKills) == "table" and #SkaldDB.probeKills or 0
    return kpSession and string.format(UI.KPROBE_ON, n) or string.format(UI.KPROBE_OFF, n)
end

-- The open world: honorable kills and honour outside the battlegrounds, by zone, in SkaldCharDB.worldPvp
-- ({ base = the game's count last read, zones = { [zone map id] = { k = kills, h = honour } } }, in K.DIARY_STATE).
-- Seen in Forever on 2026-11-25: one kill fires PLAYER_PVP_KILLS_CHANGED twice and CHAT_MSG_COMBAT_HONOR_GAIN once
-- ("You have been awarded 8 honor points", no name of the slain), and GetPVPLifetimeStats goes up. So the kills are the
-- difference of the game's count (never the events, which come twice), read again a second later in case the count
-- moves after the event; the honour is the number of the chat line. Inside an instance (a battleground) the count is
-- only followed, never added: the battlegrounds have their own record. A diary started fresh counts from now.
local worldFrame
local function MapName(id, fallback)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
    end
    return fallback
end
local function WorldZone()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, here = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or type(here) ~= "number" or Secret(here) then return nil end
    return (ns.ZoneCard and ns.ZoneCard.ZoneMap and ns.ZoneCard.ZoneMap(here)) or here
end
local function InInstance()
    if not IsInInstance then return false end
    local ok, inside = pcall(IsInInstance)
    return ok and inside and true or false
end
local function WorldDB()
    local db = SkaldCharDB
    if type(db) ~= "table" then return nil end
    if type(db.worldPvp) ~= "table" then db.worldPvp = { zones = {} } end
    if type(db.worldPvp.zones) ~= "table" then db.worldPvp.zones = {} end
    return db.worldPvp
end
local function WorldAdd(field, n)
    local w = WorldDB()
    local zone = w and WorldZone()
    if not zone then return end
    local rec = w.zones[zone]
    if type(rec) ~= "table" then rec = { k = 0, h = 0 }; w.zones[zone] = rec end
    rec[field] = (tonumber(rec[field]) or 0) + n
end
function P.WorldCount()
    local w = WorldDB()
    local hk = LifetimeHK()
    if not w or type(hk) ~= "number" then return end
    local base = tonumber(w.base)
    w.base = hk
    if not base or hk <= base then return end
    if not InInstance() then WorldAdd("k", hk - base) end
    if P.refresh then pcall(P.refresh) end
end
function P.WorldHonor(msg)
    if Secret(msg) or type(msg) ~= "string" or InInstance() then return end
    local n = tonumber(msg:match("(%d+)"))
    if n and n > 0 and n < 100000 then
        WorldAdd("h", n)
        if P.refresh then pcall(P.refresh) end
    end
end
local function WorldEvent(_, event, msg)
    if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then return P.WorldHonor(msg) end
    P.WorldCount()
    if C_Timer and C_Timer.After then C_Timer.After(1, function() pcall(P.WorldCount) end) end
end
function P.WorldStart()
    local w = WorldDB()
    if w and w.base == nil then w.base = LifetimeHK() end
    if worldFrame or not CreateFrame then return end
    worldFrame = CreateFrame("Frame")
    worldFrame:SetScript("OnEvent", function(...) pcall(WorldEvent, ...) end)
    pcall(worldFrame.RegisterEvent, worldFrame, "PLAYER_PVP_KILLS_CHANGED")
    pcall(worldFrame.RegisterEvent, worldFrame, "CHAT_MSG_COMBAT_HONOR_GAIN")
end
-- { rows = { { label, k, h } ... } the most kills first, k = total kills, h = total honour }
function P.World()
    if P.demo then
        return { k = 23, h = 186, rows = { { id = 1442, label = MapName(1442, "Stonetalon Mountains"), k = 14, h = 112 },
            { id = 1417, label = MapName(1417, "Arathi Highlands"), k = 6, h = 51 }, { id = 1424, label = MapName(1424, "Hillsbrad Foothills"), k = 3, h = 23 } } }
    end
    local w = SkaldCharDB and SkaldCharDB.worldPvp
    local out = { k = 0, h = 0, rows = {} }
    if type(w) ~= "table" or type(w.zones) ~= "table" then return out end
    for id, rec in pairs(w.zones) do
        if type(rec) == "table" then
            local k, h = tonumber(rec.k) or 0, tonumber(rec.h) or 0
            out.rows[#out.rows + 1] = { id = id, label = MapName(id, "#" .. tostring(id)), k = k, h = h }
            out.k, out.h = out.k + k, out.h + h
        end
    end
    table.sort(out.rows, function(a, b)
        if a.k ~= b.k then return a.k > b.k end
        if a.h ~= b.h then return a.h > b.h end
        return a.label < b.label
    end)
    return out
end

-- Blood debts. Identity is the player's GUID, never a bare name or the currently selected target.
-- Forever: PARTY_KILL carries attackerGUID and targetGUID (UnitDocumentation.lua, branch forever).
-- The death recap's FIRST row is the killing blow (Blizzard_DeathRecap/Mainline, BuildDataProvider).
-- A readable name there may be resolved only against one recent, readable hostile-player identity.
-- Secret payloads are discarded BEFORE comparing, indexing, formatting or saving them.
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not Secret(v) then return v end
end
function R.OpenWorld() return Read(IsInInstance) == false end
local function PlayerGUID(v)
    return not Secret(v) and type(v) == "string" and v:match("^Player%-%d+%-%x+$") ~= nil
end
local function Name(v)
    if Secret(v) or type(v) ~= "string" or #v == 0 or #v > 160 or v:find("[|%c]") then return nil end
    return v
end
local function RivalDB()
    local w = WorldDB()
    if w and type(w.rivals) ~= "table" then w.rivals = {} end
    return w
end
local function RecapLink()
    local api = type(_G.C_DeathRecap) == "table" and _G.C_DeathRecap
    local link = Read(api and api.GetRecapLink or _G.GetDeathRecapLink)
    return type(link) == "string" and link:match("|Hdeath:(%d+)") or nil
end
local function RecapEvents()
    local api = type(_G.C_DeathRecap) == "table" and _G.C_DeathRecap
    local list = Read(api and api.GetRecapEvents or _G.DeathRecap_GetEvents)
    if type(list) ~= "table" then return nil end
    local row = list[1]
    return not Secret(row) and type(row) == "table" and row or nil
end
function R.ProbeRecap()
    local row = RecapEvents()
    if not row then return nil end
    local out = {}
    for _, key in ipairs({ "sourceGUID", "sourceName", "event", "timestamp", "currentHP", "overkill", "hideCaster" }) do
        local v = row[key]
        if Secret(v) then out[key] = "(secret)"
        elseif type(v) == "number" or type(v) == "boolean" or Name(v) then out[key] = v end
    end
    out.recap = RecapLink()
    return out
end
function R.Sync()
    local w = RivalDB()
    if R.world ~= w then
        R.world, R.cache, R.death, R.fatal = w, {}, nil, nil
        R.lastRecap = RecapLink()
        R.startedAt = Read(_G.GetTime)
    end
    return w
end
function R.Remember(unit)
    if Secret(unit) or type(unit) ~= "string" or not R.OpenWorld() then return end
    if Read(UnitIsPlayer, unit) ~= true or Read(UnitCanAttack, "player", unit) ~= true then return end
    local guid = Read(UnitGUID, unit)
    local name = Name(Read(UnitName, unit))
    if not PlayerGUID(guid) or not name then return end
    local realm
    local ok, _, server = pcall(UnitName, unit)
    if ok then realm = Name(server) end
    local full = realm and (name .. "-" .. realm) or name
    R.cache[guid] = { guid = guid, name = full, short = name, at = time() }
    local n, oldest, oldestAt = 0
    for key, rec in pairs(R.cache) do
        n = n + 1
        if not oldestAt or rec.at < oldestAt then oldest, oldestAt = key, rec.at end
    end
    if n > R.CACHE_MAX then R.cache[oldest] = nil end
end
local function ResolveName(guid)
    if not PlayerGUID(guid) then return nil end
    local api = _G.UnitNameFromGUID
    if type(api) == "function" then
        local ok, name, realm = pcall(api, guid)
        if ok and Name(name) then return Name(realm) and (name .. "-" .. realm) or name end
    end
    if type(_G.GetPlayerInfoByGUID) == "function" then
        local ok, _, _, _, _, _, name, realm = pcall(_G.GetPlayerInfoByGUID, guid)
        if ok and Name(name) then return Name(realm) and (name .. "-" .. realm) or name end
    end
    return R.cache[guid] and R.cache[guid].name or nil
end
local function FatalIdentity(row, at)
    if Secret(row.event) or Secret(row.hideCaster) or row.hideCaster or row.event == "ENVIRONMENTAL_DAMAGE" then return nil end
    if PlayerGUID(row.sourceGUID) then return row.sourceGUID, Name(row.sourceName) or ResolveName(row.sourceGUID) end
    if Secret(row.sourceGUID) or row.sourceGUID ~= nil then return nil end
    local name = Name(row.sourceName)
    if not name then return nil end
    local found
    for _, rec in pairs(R.cache) do
        if at - rec.at >= 0 and at - rec.at <= 10 and (rec.name == name or rec.short == name) then
            if found then return nil end -- the recap did not distinguish two players with the same name
            found = rec
        end
    end
    return found and found.guid, found and found.name
end
local function RefreshRivals()
    if P.Ensure then P.Ensure() end
    if P.refresh then P.refresh() end
    if SkaldAPI.RefreshWindow then SkaldAPI.RefreshWindow() end
end
function R.Loss(guid, name, ctx)
    if not PlayerGUID(guid) or not ctx or not ctx.world or ctx.done or ctx.world ~= R.Sync() or ctx.db ~= SkaldCharDB or not R.OpenWorld() then return false end
    if guid == Read(UnitGUID, "player") then return false end
    local w = R.world
    local rec = w.rivals[guid]
    if not rec then
        local count, oldest, oldestAt = 0
        for key, old in pairs(w.rivals) do
            count = count + 1
            if not old.pending and (not oldestAt or (old.wonAt or 0) < oldestAt) then oldest, oldestAt = key, old.wonAt or 0 end
        end
        if count >= R.MAX_RIVALS then
            if not oldest then return false end -- never discard an unresolved debt to make room
            w.rivals[oldest] = nil
        end
        rec = { guid = guid, deaths = 0, revenges = 0 }
        w.rivals[guid] = rec
    end
    if Name(name) then rec.name = name end
    local kill = ctx.kills and ctx.kills[guid]
    local paid = kill and kill.settled
    if not rec.pending and not paid then rec.since = ctx.at end
    rec.pending, rec.deaths, rec.lastDeath, rec.zone = not paid, (rec.deaths or 0) + 1, ctx.at, ctx.zone
    ctx.done = true
    -- The recap can arrive after a posthumous kill. Reconcile the confirmed kill in event order.
    if kill and not paid then R.Kill(kill.owner, guid) end
    RefreshRivals()
    return true
end
function R.Kill(attacker, victim)
    if Secret(attacker) or type(attacker) ~= "string" or not PlayerGUID(victim) or not R.OpenWorld() then return false end
    local me, pet = Read(UnitGUID, "player"), Read(UnitGUID, "pet")
    if not PlayerGUID(me) or (attacker ~= me and attacker ~= pet) or victim == me then return false end
    local w = R.Sync()
    local rec = w and w.rivals[victim]
    local ctx, kill = R.death
    if ctx and not ctx.done and ctx.world == w and time() - ctx.at <= 3 then
        ctx.kills = ctx.kills or {}
        ctx.kills[victim] = ctx.kills[victim] or { owner = me }
        kill = ctx.kills[victim]
    end
    if not rec or not rec.pending then return false end
    local name = ResolveName(victim)
    if name then rec.name = name end
    rec.pending, rec.wonAt, rec.wonZone = false, time(), WorldZone()
    rec.revenges, w.revengeTotal = (rec.revenges or 0) + 1, (w.revengeTotal or 0) + 1
    if kill then kill.settled = true end
    SkaldAPI.AddEntry("revenge", rec.name or "",
        nil, { rival = victim, rivalWin = rec.revenges, pz = rec.wonZone, debtAt = rec.since })
    RefreshRivals()
    return true
end
function R.TryRecap(ctx)
    if not ctx or ctx ~= R.death or ctx.done or ctx.db ~= SkaldCharDB or ctx.world ~= R.Sync() or not R.OpenWorld() then return end
    local id = RecapLink()
    if not id or id == ctx.before then return end -- the recap of an earlier death is not evidence of this one
    local row = RecapEvents()
    if not row then return end
    if not ctx.before then
        local stamp = row.timestamp
        if Secret(stamp) or type(stamp) ~= "number" or type(ctx.clock) ~= "number"
            or type(R.startedAt) ~= "number" or stamp < R.startedAt or stamp < ctx.clock - 3 or stamp > ctx.clock + 1 then return end
    end
    local guid, name = FatalIdentity(row, ctx.at)
    if guid and R.Loss(guid, name, ctx) then R.lastRecap = id end
end
function R.BeginDeath()
    R.Sync()
    if not R.world or not R.OpenWorld() then return end
    if R.death then
        local fatal = R.fatal
        if fatal and time() - fatal.at >= 0 and time() - fatal.at <= 3 then R.Loss(fatal.guid, fatal.name, R.death) end
        return
    end
    R.Remember("target"); R.Remember("focus")
    for i = 1, 40 do R.Remember("nameplate" .. i) end
    local ctx = { at = time(), zone = WorldZone(), db = SkaldCharDB, world = R.world, before = R.lastRecap, clock = Read(_G.GetTime) }
    R.death = ctx
    local fatal = R.fatal
    if fatal and ctx.at - fatal.at >= 0 and ctx.at - fatal.at <= 3 then R.Loss(fatal.guid, fatal.name, ctx) end
    R.TryRecap(ctx)
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0.3, 1, 2 }) do C_Timer.After(delay, function() R.TryRecap(ctx) end) end
    end
end
function R.CombatLog()
    if _G.issecretvalue or not CombatLogGetCurrentEventInfo or not R.OpenWorld() then return end
    local args = { CombatLogGetCurrentEventInfo() }
    local kind, source, dest = args[2], args[4], args[8]
    if Secret(kind) or Secret(source) or Secret(dest) then return end
    if kind == "PARTY_KILL" then return R.Kill(source, dest) end
    if kind == "UNIT_DIED" and dest == Read(UnitGUID, "player") then return R.BeginDeath() end
    if dest ~= Read(UnitGUID, "player") or not PlayerGUID(source) then return end
    local overkill = kind == "SWING_DAMAGE" and args[13]
        or ((kind == "SPELL_DAMAGE" or kind == "SPELL_PERIODIC_DAMAGE" or kind == "RANGE_DAMAGE") and args[16])
    if not Secret(overkill) and type(overkill) == "number" and overkill >= 0 then
        R.fatal = { guid = source, name = Name(args[5]) or ResolveName(source), at = time() }
    end
end
function R.Event(_, event, a, b)
    R.Sync()
    if event == "PARTY_KILL" then return R.Kill(a, b) end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then return R.CombatLog() end
    if event == "PLAYER_DEAD" then return R.BeginDeath() end
    if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_ENTERING_WORLD" then
        R.death, R.fatal, R.lastRecap = nil, nil, RecapLink()
    end
    if event == "NAME_PLATE_UNIT_ADDED" then R.Remember(a)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then R.Remember("mouseover")
    else R.Remember("target"); R.Remember("focus") end
end
function R.Start()
    R.Sync()
    if R.frame or not CreateFrame then return end
    R.frame = CreateFrame("Frame")
    R.frame:SetScript("OnEvent", function(...)
        local ok, err = pcall(R.Event, ...)
        if not ok and ns.NoteError then ns.NoteError("PvP rivals: " .. tostring(err)) end
    end)
    for _, event in ipairs({ "PARTY_KILL", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD",
        "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }) do
        pcall(R.frame.RegisterEvent, R.frame, event)
    end
    if not _G.issecretvalue and CombatLogGetCurrentEventInfo then
        pcall(R.frame.RegisterEvent, R.frame, "COMBAT_LOG_EVENT_UNFILTERED")
    end
end
function P.RivalData()
    if P.demo then
        return { pending = 2, total = 1, rows = {
            { guid = "sample:1", name = "Aldren", pending = true, lastDeath = time() - 86400, zone = 1417, deaths = 2, revenges = 0 },
            { guid = "sample:2", name = "Vaelis", pending = true, lastDeath = time() - 172800, zone = 1442, deaths = 1, revenges = 0 },
            { guid = "sample:3", name = "Thoren", pending = false, wonAt = time() - 259200, wonZone = 1424, deaths = 1, revenges = 1 },
        } }
    end
    local w = SkaldCharDB and SkaldCharDB.worldPvp
    local out = { pending = 0, total = tonumber(w and w.revengeTotal) or 0, rows = {} }
    for guid, rec in pairs(type(w and w.rivals) == "table" and w.rivals or {}) do
        if type(rec) == "table" then
            local row = {}
            for k, v in pairs(rec) do row[k] = v end
            row.guid = guid
            out.rows[#out.rows + 1] = row
            if rec.pending then out.pending = out.pending + 1 end
        end
    end
    table.sort(out.rows, function(a, b)
        if not not a.pending ~= not not b.pending then return a.pending == true end
        local at, bt = a.pending and a.lastDeath or a.wonAt, b.pending and b.lastDeath or b.wonAt
        if (at or 0) ~= (bt or 0) then return (at or 0) > (bt or 0) end
        return a.guid < b.guid
    end)
    return out
end

-- The tab is added when it is wanted: at the login, when the first match is written and when /skald pvp on is typed.
function P.Ensure()
    pcall(P.KillProbeSync)   -- diagnostic listeners follow only this session's explicit switch
    pcall(P.WorldStart)      -- the open world is counted whether the tab is shown or not
    pcall(R.Start)
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

local function BuildBattleground(panel, sheet)
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
    local chapter = Line(0, -80, CW, "SkaldBody", "CENTER", head)
    chapter:SetText(CH.BG)
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
    wonBanner:SetPoint("TOP", panel, "TOPLEFT", LX, -104)
    wonBanner:SetTexture(TEX .. "pvp_won")
    local lostBanner = panel:CreateTexture(nil, "ARTWORK")
    lostBanner:SetSize(80, 80)
    lostBanner:SetPoint("TOP", panel, "TOPLEFT", RX, -104)
    lostBanner:SetTexture(TEX .. "pvp_lost")
    local wonNum = Centre(LX, -190, 110, "SkaldHead", GREEN)
    local lostNum = Centre(RX, -190, 110, "SkaldHead", WINE)
    local wonWord = Centre(LX, -224, 110, "SkaldSmall", muted)
    wonWord:SetText(UI.WON_WORD)
    local lostWord = Centre(RX, -224, 110, "SkaldSmall", muted)
    lostWord:SetText(UI.LOST_WORD)
    local medal = panel:CreateTexture(nil, "ARTWORK")
    medal:SetSize(78, 78)
    medal:SetPoint("TOP", panel, "TOPLEFT", MX, -114)
    medal:SetTexture(TEX .. "pvp_title_seal")
    medal:SetAlpha(0.3)
    local pctText = Centre(MX, -190, 90, "SkaldHead", head)
    local matches = Line(0, -272, CW, "SkaldBody", "CENTER")
    local story = Line(30, -324, CW - 60, "SkaldBody", "CENTER", body)
    story:SetWordWrap(true)
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
        emptySeal:SetShown(none)
        emptyHint:SetShown(none)
        story:SetShown(not none)
        story:SetText(none and "" or P.Line(data.total))
        for _, region in ipairs({ matches, wonBanner, lostBanner, wonNum, lostNum, wonWord, lostWord, medal, pctText }) do
            region:SetShown(not none)
        end
        recentHead:SetShown(not none)
        if not none then
            matches:SetText(string.format(UI.MATCHES, data.total))
            wonNum:SetText(tostring(data.won))
            lostNum:SetText(tostring(data.lost))
            pctText:SetText(math.floor(100 * data.won / data.total + 0.5) .. "%")
        end
        for i, r in ipairs(fieldRows) do
            local f = data.fields[(sheet() - 1) * P.FIELD_ROWS + i]
            r.name:SetText(f and f.label or "")
            r.rec:SetText(f and string.format(UI.REC, f.won, f.lost) or "")
        end
        -- "Last matches" follows the last field listed, not a fixed place, so a few fields leave no gap
        local listed = math.max(1, math.min(#data.fields - (sheet() - 1) * P.FIELD_ROWS, P.FIELD_ROWS))
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
    return Refresh
end

-- All chapters use the book's inks, including the dark-paper variants. Maps are the existing hand-drawn art.
local function PageKit(panel, rightTitle)
    local cw, rx = SkaldAPI.CW or 342, SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local tex = "Interface\\AddOns\\Skald\\Textures\\skald2\\"
    SkaldAPI.PageHeading(panel, UI.TITLE, 0)
    local rightHeading = SkaldAPI.PageHeading(panel, rightTitle, rx)
    local function Text(x, y, width, text, font, color, align)
        local f = panel:CreateFontString(nil, "OVERLAY", font or "SkaldBody")
        f:SetPoint("TOPLEFT", x, y)
        f:SetWidth(width)
        f:SetJustifyH(align or "CENTER")
        f:SetWordWrap(true)
        local ink = color or body
        ns.ThemeText(f, ink[1], ink[2], ink[3])
        f:SetText(text or "")
        return f
    end
    local function Art(name, x, y, w, h, alpha)
        local t = panel:CreateTexture(nil, "ARTWORK")
        t:SetSize(w, h)
        t:SetPoint("TOPLEFT", x, y)
        t:SetTexture(name:find("\\", 1, true) and name or (tex .. name))
        ns.ThemeAlpha(t, alpha or 1, alpha or 1)
        return t
    end
    return cw, rx, Text, Art, head, muted, tex, rightHeading
end

local function PageLink(panel, label, x, y, click)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(SkaldAPI.CW or 342, 20)
    b:SetPoint("TOPLEFT", x, y)
    b.text = b:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    b.text:SetPoint("CENTER")
    b.text:SetWidth((SkaldAPI.CW or 342) - 20)
    b.text:SetWordWrap(false)
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    ns.ThemeText(b.text, 0.43, 0.12, 0.10)
    b:SetScript("OnClick", click)
    b.hover = b:CreateTexture(nil, "BACKGROUND")
    b.hover:SetAllPoints()
    ns.ThemeFill(b.hover, 0.43, 0.12, 0.10, 0.06, "hover")
    b.hover:Hide()
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    return b
end

local function BuildWorld(panel, sheet, redraw, goRivals)
    local cw, rx, Text, Art, head, muted, tex, rightHeading = PageKit(panel, CH.LANDS)
    local map = Art("map_compass", 16, -88, cw - 32, 170)
    local place = Text(10, -266, cw - 20, "", "SkaldHead2", head)
    place:SetHeight(22)
    local campaign = Text(0, -302, cw, CH.CAMPAIGN, "SkaldSmall", muted)
    local kills = Text(0, -320, cw / 2, "", "SkaldHead", head)
    local honor = Text(cw / 2, -320, cw / 2, "", "SkaldHead", head)
    local killsLabel = Text(0, -349, cw / 2, CH.KILLS, "SkaldSmall", muted)
    local honorLabel = Text(cw / 2, -349, cw / 2, CH.HONOR, "SkaldSmall", muted)
    local story = Text(20, -380, cw - 40, CH.WORLD_STORY, "SkaldSmall", muted)
    story:SetHeight(42)
    local count = Text(rx, -50, cw, "", "SkaldSmall", muted)
    local hint = Text(rx + 12, -390, cw - 24, CH.WORLD_HINT, "SkaldSmall", muted)
    local lifetime = Text(rx, -368, cw, "", "SkaldSmall", muted)
    panel.rivalLink = PageLink(panel, RV.WORLD_LINK, rx, -414, goRivals)
    -- The first opening is a frontispiece, not an empty scoreboard. The existing war illustration is kept square.
    local frontispiece = Art("Interface\\AddOns\\Skald\\Textures\\ui_saga_war", (cw - 166) / 2, -93, 166, 166)
    local motto = Text(35, -267, cw - 70, CH.WORLD_MOTTO, "SkaldItalic", muted)
    motto:SetHeight(42)
    local divider = Art("rule", (cw - 110) / 2, -316, 110, 9)
    divider:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    ns.ThemeTint(divider, "ornament")
    local remembered = Text(0, -341, cw, "", "SkaldHead", head)
    local rememberedLabel = Text(16, -374, cw - 32, CH.LIFETIME_LABEL, "SkaldSmall", muted)
    local unwritten = Text(rx + 28, -105, cw - 56, CH.UNWRITTEN, "SkaldHead2", head, "LEFT")
    local empty = Text(rx + 28, -158, cw - 56, CH.WORLD_EMPTY, "SkaldSaga", nil, "LEFT")
    empty:SetHeight(125)
    local closingRule = Art("rule", rx + (cw - 90) / 2, -307, 90, 8)
    closingRule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
    ns.ThemeTint(closingRule, "ornament")
    local closing = Text(rx + 40, -340, cw - 80, CH.WORLD_CLOSING, "SkaldItalic", muted)
    closing:SetHeight(65)
    local summaryRegions = { map, place, campaign, kills, honor, killsLabel, honorLabel, story, count, hint, lifetime }
    local emptyRegions = { frontispiece, motto, unwritten, empty, closingRule, closing }
    local selected
    local rows = {}
    local function Select(z)
        local name = ns.ZoneCard and ns.ZoneCard.ART and ns.ZoneCard.ART[z.id]
        map:SetTexture(tex .. (name or "map_compass"))
        map:ClearAllPoints()
        map:SetSize(name and (cw - 32) or 100, name and 170 or 100)
        map:SetPoint("TOPLEFT", name and 16 or ((cw - 100) / 2), name and -88 or -124)
        place:SetText(z.label)
    end
    for i = 1, P.WORLD_ROWS do
        local y = -84 - (i - 1) * 48
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(cw, 44)
        b:SetPoint("TOPLEFT", rx, y)
        b.name = Text(rx + 16, y, cw - 24, "", "SkaldBody", head, "LEFT")
        b.name:SetHeight(19)
        b.name:SetWordWrap(false)
        b.rec = Text(rx + 16, y - 21, cw - 24, "", "SkaldSmall", muted, "LEFT")
        b.dot = Art("pvp_won", rx - 3, y - 1, 18, 28, 0.8)
        b.hover = b:CreateTexture(nil, "BACKGROUND")
        b.hover:SetAllPoints()
        ns.ThemeFill(b.hover, head[1], head[2], head[3], 0.07, "hover")
        b.hover:Hide()
        b:SetScript("OnEnter", function(self) self.hover:Show() end)
        b:SetScript("OnLeave", function(self) self.hover:Hide() end)
        b:SetScript("OnClick", function(self)
            if self.zone then selected = self.zone.id; redraw() end
        end)
        rows[i] = b
    end
    panel.rows, panel.map, panel.place = rows, map, place
    panel.summaryRegions, panel.emptyRegions, panel.remembered = summaryRegions, emptyRegions, remembered
    return function()
        local data = P.World()
        local first = (sheet() - 1) * P.WORLD_ROWS + 1
        local chosen
        for i = first, math.min(#data.rows, first + P.WORLD_ROWS - 1) do
            if data.rows[i].id == selected then chosen = data.rows[i] end
        end
        chosen = chosen or data.rows[first]
        selected = chosen and chosen.id
        if chosen then Select(chosen) else place:SetText("") end
        kills:SetText(tostring(data.k))
        honor:SetText(tostring(data.h))
        count:SetText(string.format(CH.TERRITORIES, #data.rows))
        local hk = P.HonorableKills()
        lifetime:SetText(hk and string.format(CH.LIFETIME, hk) or "")
        local populated = #data.rows > 0
        for _, region in ipairs(summaryRegions) do region:SetShown(populated) end
        for _, region in ipairs(emptyRegions) do region:SetShown(not populated) end
        rightHeading:SetText(populated and CH.LANDS or CH.FIRST_MARKS)
        local hasHistory = not populated and hk ~= nil and hk > 0
        remembered:SetShown(hasHistory)
        rememberedLabel:SetShown(hasHistory)
        divider:SetShown(hasHistory)
        remembered:SetText(hasHistory and tostring(hk) or "")
        for i, row in ipairs(rows) do
            local z = data.rows[first + i - 1]
            row.zone = z
            row:SetShown(z ~= nil)
            row.name:SetShown(z ~= nil)
            row.rec:SetShown(z ~= nil)
            row.dot:SetShown(z ~= nil and z.id == selected)
            row.name:SetText(z and z.label or "")
            row.rec:SetText(z and string.format(UI.WORLD_ZONE, z.k, z.h) or "")
        end
    end
end

local function BuildRivals(panel, sheet, goWorld)
    local cw, rx, Text, Art, head, muted = PageKit(panel, RV.TITLE)
    Art("pvp_title_seal", (cw - 112) / 2, -99, 112, 112, 0.9)
    local intro = Text(30, -232, cw - 60, RV.INTRO, "SkaldItalic", muted)
    intro:SetHeight(66)
    local pending = Text(0, -322, cw / 2, "", "SkaldHead", head)
    local won = Text(cw / 2, -322, cw / 2, "", "SkaldHead", head)
    local pendingLabel = Text(0, -354, cw / 2, RV.PENDING, "SkaldSmall", muted)
    local wonLabel = Text(cw / 2, -354, cw / 2, RV.WON, "SkaldSmall", muted)
    local empty = Text(rx + 28, -156, cw - 56, RV.EMPTY, "SkaldSaga", nil, "LEFT")
    empty:SetHeight(150)
    panel.worldLink = PageLink(panel, RV.BACK, rx, -414, goWorld)
    local rows = {}
    for i = 1, R.ROWS do
        local y = -68 - (i - 1) * 50
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(cw, 46)
        b:SetPoint("TOPLEFT", rx, y)
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetPoint("TOPLEFT", 0, 0)
        b.mark:SetSize(23, 33)
        b.name = Text(rx + 30, y, cw - 30, "", "SkaldBody", head, "LEFT")
        b.name:SetWordWrap(false)
        b.status = Text(rx + 30, y - 17, cw - 30, "", "SkaldSmall", muted, "LEFT")
        b.place = Text(rx + 30, y - 31, cw - 30, "", "SkaldSmall", muted, "LEFT")
        b.place:SetWordWrap(false)
        b:SetScript("OnEnter", function(self)
            if self.rival and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.rival.name or RV.UNKNOWN)
                GameTooltip:AddLine(self.place:GetText() or "", 0.9, 0.8, 0.6, true)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b:SetScript("OnClick", function(self)
            if not self.rival or self.rival.pending or P.demo then return end
            local entries = SkaldCharDB and SkaldCharDB.entries or {}
            for at = #entries, 1, -1 do
                local e = entries[at]
                if e.kind == "revenge" and e.rival == self.rival.guid and e.rivalWin == self.rival.revenges then
                    if SkaldAPI.OpenEntry then SkaldAPI.OpenEntry(e) end
                    return
                end
            end
        end)
        rows[i] = b
    end
    panel.rows, panel.empty = rows, empty
    return function()
        local data = P.RivalData()
        local any = #data.rows > 0
        for _, region in ipairs({ pending, won, pendingLabel, wonLabel }) do region:SetShown(any) end
        pending:SetText(tostring(data.pending))
        won:SetText(tostring(data.total))
        empty:SetShown(not any)
        local tex = "Interface\\AddOns\\Skald\\Textures\\skald2\\"
        for i, row in ipairs(rows) do
            local rec = data.rows[(sheet() - 1) * R.ROWS + i]
            row.rival = rec
            row:SetShown(rec ~= nil)
            row.name:SetShown(rec ~= nil); row.status:SetShown(rec ~= nil); row.place:SetShown(rec ~= nil)
            if rec then
                row.mark:SetTexture(tex .. (rec.pending and "pvp_lost" or "pvp_won"))
                row.name:SetText(rec.name or RV.UNKNOWN)
                row.status:SetText(rec.pending and RV.PENDING_ROW or RV.WON_ROW)
                local at, zone = rec.pending and rec.lastDeath or rec.wonAt, rec.pending and rec.zone or rec.wonZone
                row.place:SetText((at and date(UI.DATE, at) or "") .. (zone and (" · " .. MapName(zone, "#" .. zone)) or ""))
            end
        end
    end
end

local function BuildArena(panel)
    local cw, rx, Text, Art, head, muted = PageKit(panel, CH.ARENA_BOOK)
    Text(0, -80, cw, CH.ARENA, "SkaldBody", head)
    Art("pvp_title_seal", (cw - 160) / 2, -128, 160, 160, 0.65)
    Text(30, -312, cw - 60, CH.ARENA_STORY, "SkaldBody", muted)
    Text(rx + 25, -150, cw - 50, CH.ARENA_EMPTY, "SkaldBody", head)
    local hint = Text(rx + 30, -220, cw - 60, CH.ARENA_HINT, "SkaldBody", muted)
    hint:SetHeight(135)
    return function() end
end

-- A chapter uses a full spread. The book corners also turn through long territory/field lists before the next chapter.
local function BuildTab(panel)
    local cw = SkaldAPI.CW or 342
    local current, page = 1, 1
    local subs, refreshes, buttons = {}, {}, {}
    local labels = { CH.WORLD, CH.BG, CH.ARENA }
    local Refresh
    local function WorldPages() return math.max(1, math.ceil(#P.World().rows / P.WORLD_ROWS)) end
    local function Pages(chapter)
        if chapter == 1 then return WorldPages() + math.max(1, math.ceil(#P.RivalData().rows / R.ROWS)) end
        return chapter == 2 and math.max(1, math.ceil(#P.Data().fields / P.FIELD_ROWS)) or 1
    end
    local function Redraw()
        Refresh()
        if SkaldAPI.RefreshWindow then SkaldAPI.RefreshWindow() end
    end
    for i = 1, 3 do
        local sub = CreateFrame("Frame", nil, panel)
        sub:SetAllPoints(panel)
        sub:Hide()
        subs[i] = sub
    end
    local sheet = function() return page end
    local rivalPanel = CreateFrame("Frame", nil, panel)
    rivalPanel:SetAllPoints(panel)
    rivalPanel:Hide()
    local function GoWorld() current, page = 1, 1; Redraw() end
    local function GoRivals() current, page = 1, WorldPages() + 1; Redraw() end
    local refreshRivals = BuildRivals(rivalPanel, function() return page - WorldPages() end, GoWorld)
    refreshes[1] = BuildWorld(subs[1], sheet, Redraw, GoRivals)
    refreshes[2] = BuildBattleground(subs[2], sheet)
    refreshes[3] = BuildArena(subs[3])
    -- Written chapter links on the parchment; the selected chapter has a short underline.
    local widths, left = { cw * 0.31, cw * 0.47, cw * 0.22 }, 0
    for i, label in ipairs(labels) do
        local chapter = i
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(widths[i], 26)
        b:SetPoint("TOPLEFT", left, -42)
        b.text = b:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        b.text:SetPoint("CENTER")
        b.text:SetWidth(widths[i] - 4)
        b.text:SetWordWrap(false)
        b.text:SetText(label)
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetPoint("BOTTOMLEFT", 9, 0)
        b.mark:SetPoint("BOTTOMRIGHT", -9, 0)
        b.mark:SetHeight(1)
        ns.ThemeFill(b.mark, 0.43, 0.12, 0.10, 0.65)
        b:SetScript("OnClick", function() current, page = chapter, 1; Redraw() end)
        b.hover = b:CreateTexture(nil, "BACKGROUND")
        b.hover:SetAllPoints()
        ns.ThemeFill(b.hover, 0.43, 0.12, 0.10, 0.07, "hover")
        b.hover:Hide()
        b:SetScript("OnEnter", function(self) self.hover:Show() end)
        b:SetScript("OnLeave", function(self) self.hover:Hide() end)
        buttons[i] = b
        left = left + widths[i]
    end
    local demo = panel:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    demo:SetPoint("TOPLEFT", 0, -424)
    demo:SetWidth(cw)
    demo:SetJustifyH("CENTER")
    ns.ThemeText(demo, 0.43, 0.12, 0.10)
    demo:SetText(UI.DEMO_NOTE)
    Refresh = function()
        local total = Pages(current)
        page = math.max(1, math.min(total, page))
        local inRivals = current == 1 and page > WorldPages()
        for i, sub in ipairs(subs) do
            sub:SetShown(i == current and not inRivals)
            buttons[i].mark:SetShown(i == current)
            ns.ThemeText(buttons[i].text, i == current and 0.43 or 0.42, i == current and 0.12 or 0.29, i == current and 0.10 or 0.17)
        end
        rivalPanel:SetShown(inRivals)
        if inRivals then refreshRivals() else refreshes[current]() end
        demo:SetShown(P.demo == true and current ~= 3)
        if SkaldAPI.RefreshFooter then SkaldAPI.RefreshFooter() end
    end
    local pager = {
        Turn = function(delta)
            if delta > 0 then
                if page < Pages(current) then page = page + 1
                elseif current < 3 then current, page = current + 1, 1 end
            elseif delta < 0 then
                if page > 1 then page = page - 1
                elseif current > 1 then current = current - 1; page = Pages(current) end
            end
            Refresh()
        end,
        CanPrev = function() return current > 1 or page > 1 end,
        CanNext = function() return current < 3 or page < Pages(current) end,
        Current = function() return current, page end,
        Count = function() return Pages(1) + Pages(2) + Pages(3) end,
        Folio = function()
            local before = 0
            for chapter = 1, current - 1 do before = before + Pages(chapter) end
            return (before + page - 1) * 2 + 1
        end,
    }
    panel.subs, panel.chapterButtons, panel.pager, panel.rivalPanel = subs, buttons, pager, rivalPanel
    P.refresh, P.pager = Refresh, pager
    return Refresh, pager
end
P.Build = BuildTab
