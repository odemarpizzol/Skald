-- Skald: the goals tab. Goals the diary checks by itself, from what it already knows (pages, counters, pets,
-- companions, trades, flight paths, lands). A goal reached is written as a page of its own; the ones already
-- reached when the diary first looks are marked quietly, without a page.
--
-- Loaded after Skald.lua: it uses SkaldAPI (AddTab, AddEntry, entryHook...) and the saved diary SkaldCharDB.
local _, ns = ...

-- Texts of the tab and of every goal (the page of a goal reached has its own phrases in Locales.lua).
local UI_TEXT = {
    enUS = {
        TAB = "Goals", OF = "%d of %d", DONE_ON = "Done on %s", BEFORE = "Done before the diary counted", SECRET = "???",
        SECRET_HINT = "A goal still to be found.", DATE = "%m/%d/%Y", TOTAL = "%d of %d goals reached",
        EMPTY = "Nothing here yet.",
        PAGE = "Page %d of %d", NEAR = "Nearest", ALLDONE = "Every goal of the book is reached.",
        INTRO_SUMMARY = "Small marks that only this diary can tell. Turn the corner of the page to read the next chapter.",
        INTRO = { road = "Roads and sky roads: the places I learned to reach.", story = "Some tales are told to the end. These are the ones the diary remembers best.", beasts = "A hunter is never alone for long. Every friend from the wild leaves a mark in the book.", company = "The road is better with someone beside you. The diary remembers who was there." },
        CATS = { explorer = "Exploration", road = "The Road", story = "Stories", war = "War", craft = "Crafts", beasts = "Beasts", company = "Company" },
        FACT = {
            zones = "Discover %d lands.", flights = "Learn %d flight paths.", level = "Reach level %d.",
            quests = "Complete %d quests.", chains = "Quest chains finished: %d.", rareQ = "Complete a rare quest or better.",
            epicQ = "Complete an epic quest or better.", dungeons = "Dungeons visited: %d.", bosses = "Bosses defeated: %d.",
            hardBoss = "Defeat a boss after falling to it.", kills = "Creatures defeated: %d.", profs = "Trades learned: %d.",
            skillStep = "Reach %d skill in a trade.", pets = "Companions tamed: %d.", petLevel = "See a companion reach your level.",
            companions = "Companions of the road remembered: %d.", reunions = "Meet again someone from a dungeon.",
            guild = "Join a guild.", party = "Join a group for the first time.",
        },
        NAMES = {
            zones3 = "First Horizons", zones8 = "Boots on Many Roads", zones15 = "The Map Has My Name",
            flights5 = "A Seat Above the Clouds", flights15 = "Sky Roads of Azeroth",
            level10 = "Past the First Threshold", level20 = "A Name in the Taverns", level30 = "The Road in the Bones",
            level40 = "Time for a Mount", level50 = "The Long Climb", level60 = "At the Top of the World",
            quests50 = "Errands and Oaths", quests150 = "A Hundred Small Promises", quests400 = "The Quest Log Is a Book",
            chains1 = "A Story Told to the End", chains5 = "Five Long Roads", rareQ = "Worth a Seal", epicQ = "A Tale for the Bards",
            dungeons1 = "Into the Depths", dungeons5 = "Ever Deeper", bosses1 = "The First Fall of a Foe", bosses10 = "Ten Thrones Toppled",
            hardBoss = "Victory After the Hard Road", kills500 = "A Field of Fallen Foes", kills2500 = "The Wild Remembers",
            profs1 = "Hands Learning", profs2 = "Two Trades, One Pair of Hands", skill1 = "The Apprentice's Mark",
            skill2 = "The Journeyman's Pride", skill3 = "Expert Hands", skill4 = "Master of the Trade",
            pets1 = "A Friend from the Wild", pets5 = "A Pack on the Road", pets10 = "The Whole Bestiary",
            petLevel = "Side by Side, Level for Level", companions1 = "The Road Has Company", companions5 = "A Circle of Friends",
            reunions = "Old Company, Met Again", guild = "Under One Banner", party = "Strength in Numbers",
        },
    },
    ptBR = {
        TAB = "Metas", OF = "%d de %d", DONE_ON = "Cumprida em %s", BEFORE = "Cumprida antes do diário contar", SECRET = "???",
        SECRET_HINT = "Uma meta ainda por descobrir.", DATE = "%d/%m/%Y", TOTAL = "%d de %d metas cumpridas",
        EMPTY = "Nada aqui ainda.",
        PAGE = "Página %d de %d", NEAR = "Mais perto", ALLDONE = "Todas as metas do livro foram cumpridas.",
        INTRO_SUMMARY = "Pequenas marcas que só este diário sabe contar. Vire o canto da página para ler o próximo capítulo.",
        INTRO = { road = "Estradas e rotas do céu: os lugares que aprendi a alcançar.", story = "Algumas histórias são contadas até o fim. Estas são as que o diário lembra melhor.", beasts = "Um caçador nunca fica sozinho por muito tempo. Cada amigo da natureza deixa uma marca no livro.", company = "A estrada é melhor com alguém ao lado. O diário lembra quem esteve lá." },
        CATS = { explorer = "Exploração", road = "A Estrada", story = "Histórias", war = "Guerra", craft = "Ofícios", beasts = "Feras", company = "Companhia" },
        FACT = {
            zones = "Descubra %d terras.", flights = "Aprenda %d rotas de voo.", level = "Chegue ao nível %d.",
            quests = "Cumpra %d missões.", chains = "Cadeias de missões concluídas: %d.", rareQ = "Cumpra uma missão rara ou melhor.",
            epicQ = "Cumpra uma missão épica ou melhor.", dungeons = "Masmorras visitadas: %d.", bosses = "Chefes derrotados: %d.",
            hardBoss = "Derrote um chefe depois de cair para ele.", kills = "Criaturas vencidas: %d.", profs = "Ofícios aprendidos: %d.",
            skillStep = "Alcance %d de habilidade num ofício.", pets = "Companheiros domados: %d.", petLevel = "Veja um companheiro alcançar o seu nível.",
            companions = "Companheiros de estrada lembrados: %d.", reunions = "Reencontre alguém de uma masmorra.",
            guild = "Entre numa guilda.", party = "Junte-se a um grupo pela primeira vez.",
        },
        NAMES = {
            zones3 = "Primeiros Horizontes", zones8 = "Botas em Muitas Estradas", zones15 = "O Mapa Tem o Meu Nome",
            flights5 = "Um Assento Acima das Nuvens", flights15 = "Estradas do Céu de Azeroth",
            level10 = "Além do Primeiro Limiar", level20 = "Um Nome nas Tavernas", level30 = "A Estrada nos Ossos",
            level40 = "Hora da Montaria", level50 = "A Longa Subida", level60 = "No Topo do Mundo",
            quests50 = "Recados e Juramentos", quests150 = "Cem Pequenas Promessas", quests400 = "O Diário de Missões É um Livro",
            chains1 = "Uma História Contada até o Fim", chains5 = "Cinco Longas Estradas", rareQ = "Digna de um Selo", epicQ = "Um Conto para os Bardos",
            dungeons1 = "Rumo às Profundezas", dungeons5 = "Cada Vez Mais Fundo", bosses1 = "A Primeira Queda de um Inimigo", bosses10 = "Dez Tronos Derrubados",
            hardBoss = "Vitória Depois do Caminho Difícil", kills500 = "Um Campo de Inimigos Caídos", kills2500 = "A Natureza Se Lembra",
            profs1 = "Mãos que Aprendem", profs2 = "Dois Ofícios, Um Par de Mãos", skill1 = "A Marca do Aprendiz",
            skill2 = "O Orgulho do Oficial", skill3 = "Mãos de Perito", skill4 = "Mestre do Ofício",
            pets1 = "Um Amigo da Natureza", pets5 = "Uma Matilha na Estrada", pets10 = "Todo o Bestiário",
            petLevel = "Lado a Lado, Nível a Nível", companions1 = "A Estrada Tem Companhia", companions5 = "Um Círculo de Amigos",
            reunions = "Velha Companhia, Reencontrada", guild = "Sob Uma Só Bandeira", party = "A Força do Grupo",
        },
    },
    frFR = {
        TAB = "Objectifs", OF = "%d sur %d", DONE_ON = "Accompli le %s", BEFORE = "Accompli avant que le journal compte", SECRET = "???",
        SECRET_HINT = "Un objectif encore à découvrir.", DATE = "%d/%m/%Y", TOTAL = "%d objectifs atteints sur %d",
        EMPTY = "Rien ici pour l'instant.",
        PAGE = "Page %d sur %d", NEAR = "Les plus proches", ALLDONE = "Tous les objectifs du livre sont atteints.",
        INTRO_SUMMARY = "De petites marques que seul ce journal sait raconter. Tournez le coin de la page pour lire le chapitre suivant.",
        INTRO = { road = "Routes de terre et du ciel94p: les lieux que j'ai appris à rejoindre.", story = "Certaines histoires sont menées jusqu'au bout. Ce sont celles dont le journal se souvient le mieux.", beasts = "Un chasseur n'est jamais seul longtemps. Chaque ami de la nature laisse une marque dans le livre.", company = "La route est meilleure avec quelqu'un à ses côtés. Le journal se souvient de qui était là." },
        CATS = { explorer = "Exploration", road = "La Route", story = "Histoires", war = "Guerre", craft = "Métiers", beasts = "Bêtes", company = "Compagnie" },
        FACT = {
            zones = "Découvrez %d contrées.", flights = "Apprenez %d routes aériennes.", level = "Atteignez le niveau %d.",
            quests = "Accomplissez %d quêtes.", chains = "Chaînes de quêtes terminées\194\160: %d.", rareQ = "Accomplissez une quête rare ou mieux.",
            epicQ = "Accomplissez une quête épique ou mieux.", dungeons = "Donjons visités\194\160: %d.", bosses = "Boss vaincus\194\160: %d.",
            hardBoss = "Vainquez un boss après être tombé devant lui.", kills = "Créatures vaincues\194\160: %d.", profs = "Métiers appris\194\160: %d.",
            skillStep = "Atteignez %d de compétence dans un métier.", pets = "Compagnons apprivoisés\194\160: %d.", petLevel = "Voyez un compagnon atteindre votre niveau.",
            companions = "Compagnons de route dont on se souvient\194\160: %d.", reunions = "Retrouvez quelqu'un d'un donjon.",
            guild = "Rejoignez une guilde.", party = "Rejoignez un groupe pour la première fois.",
        },
        NAMES = {
            zones3 = "Premiers horizons", zones8 = "Des bottes sur bien des routes", zones15 = "La carte porte mon nom",
            flights5 = "Une place au-dessus des nuages", flights15 = "Routes du ciel d'Azeroth",
            level10 = "Au-delà du premier seuil", level20 = "Un nom dans les tavernes", level30 = "La route dans les os",
            level40 = "L'heure de la monture", level50 = "La longue ascension", level60 = "Au sommet du monde",
            quests50 = "Courses et serments", quests150 = "Cent petites promesses", quests400 = "Le journal de quêtes est un livre",
            chains1 = "Une histoire menée à son terme", chains5 = "Cinq longues routes", rareQ = "Digne d'un sceau", epicQ = "Un récit pour les bardes",
            dungeons1 = "Vers les profondeurs", dungeons5 = "Toujours plus profond", bosses1 = "La première chute d'un ennemi", bosses10 = "Dix trônes renversés",
            hardBoss = "Victoire après le dur chemin", kills500 = "Un champ d'ennemis tombés", kills2500 = "La nature s'en souvient",
            profs1 = "Des mains qui apprennent", profs2 = "Deux métiers, une paire de mains", skill1 = "La marque de l'apprenti",
            skill2 = "La fierté du compagnon", skill3 = "Des mains d'expert", skill4 = "Maître du métier",
            pets1 = "Un ami de la nature", pets5 = "Une meute sur la route", pets10 = "Tout le bestiaire",
            petLevel = "Côte à côte, niveau pour niveau", companions1 = "La route a de la compagnie", companions5 = "Un cercle d'amis",
            reunions = "Vieille compagnie, retrouvée", guild = "Sous une seule bannière", party = "La force du nombre",
        },
    },
}
local UI = UI_TEXT[GetLocale()] or UI_TEXT.enUS
local TEX = "Interface\\AddOns\\Skald\\Textures\\"

-- The categories, with the page icon that stands for each.
local CATS = {
    { key = "road", icon = "ev_level" }, { key = "story", icon = "ev_quest" },
    { key = "beasts", icon = "ev_pet" }, { key = "company", icon = "ev_party" },
}

-- The goals: `fact` is read from the diary, `target` is what it must reach, `tier` is the rarity of the seal,
-- `secret` keeps the name hidden until the feat is done.
local GOALS = {
    { id = "flights5", cat = "road", tier = 1, fact = "flights", target = 5 },
    { id = "flights15", cat = "road", tier = 3, fact = "flights", target = 15 },
    { id = "chains1", cat = "story", tier = 3, fact = "chains", target = 1, secret = true },
    { id = "chains5", cat = "story", tier = 4, fact = "chains", target = 5, secret = true },
    { id = "hardBoss", cat = "story", tier = 3, fact = "hardBoss", target = 1, secret = true },
    { id = "pets1", cat = "beasts", tier = 1, fact = "pets", target = 1 },
    { id = "pets5", cat = "beasts", tier = 2, fact = "pets", target = 5 },
    { id = "pets10", cat = "beasts", tier = 3, fact = "pets", target = 10 },
    { id = "petLevel", cat = "beasts", tier = 3, fact = "petLevel", target = 1 },
    { id = "companions1", cat = "company", tier = 2, fact = "companions", target = 1 },
    { id = "companions5", cat = "company", tier = 3, fact = "companions", target = 5 },
    { id = "reunions", cat = "company", tier = 3, fact = "reunions", target = 1, secret = true },
}
-- (The names of feats dropped from the list stay in the texts below: a page already written may name one.)
local GOAL_BY_ID = {}
for _, g in ipairs(GOALS) do GOAL_BY_ID[g.id] = g end

ns.GoalName = function(id) return UI.NAMES[id] or tostring(id) end
ns.GoalList = GOALS
ns.GoalUI = UI

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- What the diary knows, as numbers. Read from the saved diary, so goals already met by old pages count too.
local function Facts()
    local db = SkaldCharDB
    local f = {}
    if not db then return f end
    local stats = db.stats or {}
    local counts = stats.counts or {}
    f.zones = math.max(Count(db.visitedMaps), Count(db.visited))
    f.flights = Count(db.taxi)
    f.level = (UnitLevel and UnitLevel("player")) or 1
    f.quests = counts.quest or 0
    f.dungeons = counts.dungeon or 0
    f.bosses = counts.boss or 0
    f.kills = counts.kill or 0
    -- the game's own numbers, when it gives them (the diary's are an estimate for creatures)
    local exact = SkaldAPI.GameFacts and SkaldAPI.GameFacts() or {}
    if type(exact.kills) == "number" then f.kills = math.max(f.kills, exact.kills) end
    if type(exact.bosses) == "number" then f.bosses = math.max(f.bosses, exact.bosses) end
    if type(exact.dungeons) == "number" then f.dungeons = math.max(f.dungeons, exact.dungeons) end
    f.profs = Count(db.skills)
    local best = 0
    for _, step in pairs(db.skills or {}) do if type(step) == "number" and step > best then best = step end end
    f.skillStep = best
    f.pets = Count(db.pets)
    f.companions = Count(db.companions)
    f.guild = (db.guild and 1) or 0
    f.party = (db.flags and db.flags.party) and 1 or 0
    local rare, epic = 0, 0
    for tier, n in pairs(stats.tiers or {}) do
        if type(tier) == "number" and type(n) == "number" then
            if tier >= 3 then rare = rare + n end
            if tier >= 4 then epic = epic + n end
        end
    end
    f.rareQ, f.epicQ = rare, epic
    local chains, hard, petLevel, reunions = 0, 0, 0, 0
    for _, e in ipairs(db.entries or {}) do
        local kind = e.kind
        if kind == "quest" then
            if (e.cend or 0) >= 2 then chains = chains + 1 end
        elseif kind == "boss" then
            if (e.tries or 0) >= 1 then hard = hard + 1 end
        elseif kind == "tame" then
            if e.sub == "level" then petLevel = petLevel + 1 end
        elseif kind == "reunion" then
            reunions = reunions + 1
        elseif kind == "guild" then
            f.guild = 1
        end
    end
    f.chains, f.hardBoss, f.petLevel, f.reunions = chains, hard, petLevel, reunions
    return f
end
ns.GoalFacts = Facts

-- Looks for goals newly reached. The first look only marks the ones already reached (no pages); after that
-- each goal reached is written as a page.
local function Check()
    local db = SkaldCharDB
    if not db or not SkaldAPI or not SkaldAPI.AddEntry then return end
    db.goals = db.goals or {}
    local silent = not db.goalsInit
    local facts = Facts()
    for _, g in ipairs(GOALS) do
        if not db.goals[g.id] and (facts[g.fact] or 0) >= g.target then
            db.goals[g.id] = { t = time(), retro = silent or nil }
            if not silent then
                SkaldAPI.AddEntry("goal", g.id, nil, { tier = g.tier, m = false, x = false, y = false })
            end
        end
    end
    db.goalsInit = true
end
ns.CheckGoals = Check

-- Pages and counters change often: one look a moment after the last change is enough.
local refreshTab
local pending = false
SkaldAPI.entryHook = function(kind)
    if kind == "goal" or pending then return end
    pending = true
    C_Timer.After(2, function()
        pending = false
        pcall(Check)
        if refreshTab then pcall(refreshTab) end
    end)
end

-- The tab, as a little book of its own: a summary spread, then one chapter for each kind of goal. The corners
-- of the page (and the mouse wheel) turn the pages; a chapter with more goals than a page holds goes on. ------
local PER_PAGE = 7

local function BuildGoalsTab(panel)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local sealPath = "Interface\\AddOns\\Skald\\Textures\\seal"

    local leftHeading = SkaldAPI.PageHeading(panel, UI.TAB, 0)
    local leftNote = SkaldAPI.NoteText(panel, 0, -34)
    leftNote:SetJustifyH("CENTER")
    local rightHeading = SkaldAPI.PageHeading(panel, "", RIGHT_X)
    local footer = SkaldAPI.NoteText(panel, 0, -412)
    footer:SetJustifyH("CENTER")

    -- A bar: the frame of the picture, with a gold fill over it.
    local function MakeBar(parent, width, height)
        local bar = CreateFrame("Frame", nil, parent)
        bar:SetSize(width, height)
        bar.frame = bar:CreateTexture(nil, "ARTWORK")
        bar.frame:SetAllPoints()
        bar.frame:SetTexture(TEX .. "ui_bar")
        bar.fill = bar:CreateTexture(nil, "OVERLAY")
        bar.fill:SetColorTexture(0.80, 0.58, 0.08, 0.95)
        bar.fill:SetPoint("TOPLEFT", 6, -4)
        bar.fill:SetHeight(height - 8)
        bar.max = width - 12
        function bar:Set(fraction)
            fraction = math.max(0, math.min(1, fraction or 0))
            self.fill:SetWidth(math.max(0.01, self.max * fraction))
            self.fill:SetShown(fraction > 0)
        end
        return bar
    end

    local pageIndex = 1
    local spreads = {}
    local refreshTab

    -- The left page of the summary: the chapters, each with its count and bar; a click opens the chapter.
    local chapterRows = {}
    for i, cat in ipairs(CATS) do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 46)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexture(TEX .. cat.icon)
        row.name = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.name:SetPoint("TOPLEFT", 44, -4)
        row.name:SetTextColor(body[1], body[2], body[3])
        row.name:SetText(UI.CATS[cat.key])
        row.count = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.count:SetPoint("TOPRIGHT", -6, -6)
        row.count:SetTextColor(muted[1], muted[2], muted[3])
        row.bar = MakeBar(row, CW - 54, 14)
        row.bar:SetPoint("BOTTOMLEFT", 44, 4)
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(0.43, 0.12, 0.10, 0.10)
        row.hover:Hide()
        row:SetScript("OnEnter", function(self) self.hover:Show() end)
        row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        row.cat = cat
        row:SetScript("OnClick", function(self)
            for n, sp in ipairs(spreads) do
                if sp.cat == self.cat.key then pageIndex = n; break end
            end
            if refreshTab then refreshTab() end
            if SkaldAPI.RefreshWindow then SkaldAPI.RefreshWindow() end
        end)
        chapterRows[i] = row
    end

    -- The left page of a chapter: a large icon, the count with its bar, and a few lines to open it.
    local art = panel:CreateTexture(nil, "ARTWORK")
    art:SetSize(72, 72)
    art:SetPoint("TOP", panel, "TOPLEFT", CW / 2, -66)
    local chapterCount = SkaldAPI.NoteText(panel, 0, -146)
    chapterCount:SetJustifyH("CENTER")
    local chapterBar = MakeBar(panel, CW - 40, 14)
    chapterBar:SetPoint("TOPLEFT", 20, -166)
    local intro = SkaldAPI.NoteText(panel, 12, -200)
    intro:SetWidth(CW - 24)
    intro:SetJustifyH("CENTER")
    local introSummary = SkaldAPI.NoteText(panel, 12, -58)
    introSummary:SetWidth(CW - 24)
    introSummary:SetJustifyH("CENTER")

    -- The right page: up to seven goals.
    local goalRows = {}
    for i = 1, PER_PAGE do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(CW, 50)
        row:SetPoint("TOPLEFT", RIGHT_X, -52 - (i - 1) * 54)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(36, 36)
        row.icon:SetPoint("TOPLEFT", 0, -4)
        row.name = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.name:SetPoint("TOPLEFT", 46, -2)
        row.name:SetWidth(CW - 50)
        row.name:SetJustifyH("LEFT")
        row.desc = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.desc:SetPoint("TOPLEFT", 46, -20)
        row.desc:SetWidth(CW - 50)
        row.desc:SetJustifyH("LEFT")
        row.desc:SetTextColor(muted[1], muted[2], muted[3])
        row.bar = MakeBar(row, CW - 110, 14)
        row.bar:SetPoint("TOPLEFT", 46, -34)
        row.count = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.count:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)
        row.count:SetTextColor(muted[1], muted[2], muted[3])
        goalRows[i] = row
    end
    local allDone = SkaldAPI.NoteText(panel, RIGHT_X, -60)
    allDone:SetJustifyH("CENTER")
    allDone:SetText(UI.ALLDONE)

    local function FillRow(row, g, facts, done)
        row:Show()
        local rec = done[g.id]
        local value = facts[g.fact] or 0
        if rec then
            row.icon:SetTexture(TEX .. "goal_done")
            row.icon:SetAlpha(1)
            row.name:SetText(UI.NAMES[g.id])
            row.name:SetTextColor(head[1], head[2], head[3])
            row.desc:SetText(rec.retro and UI.BEFORE or string.format(UI.DONE_ON, date(UI.DATE, rec.t or time())))
            row.bar:Set(1)
            row.count:SetText("")
        elseif g.secret then
            row.icon:SetTexture(TEX .. "goal_locked")
            row.icon:SetAlpha(0.8)
            row.name:SetText(UI.SECRET)
            row.name:SetTextColor(muted[1], muted[2], muted[3])
            row.desc:SetText(UI.SECRET_HINT)
            row.bar:Set(0)
            row.count:SetText("")
        else
            row.icon:SetTexture(sealPath .. g.tier)
            row.icon:SetAlpha(0.55)
            row.name:SetText(UI.NAMES[g.id])
            row.name:SetTextColor(body[1], body[2], body[3])
            local mult = g.mult or 1
            row.desc:SetText(string.format(UI.FACT[g.fact], g.target * mult))
            row.bar:Set(math.min(value, g.target) / g.target)
            row.count:SetText(string.format(UI.OF, math.min(value, g.target) * mult, g.target * mult))
        end
    end

    -- The pages: a summary, then each chapter (a beast chapter only for a hunter, or whoever has had a pet).
    local function Spreads()
        local db = SkaldCharDB
        local list = { { summary = true } }
        local isHunter = false
        pcall(function() isHunter = select(2, UnitClass("player")) == "HUNTER" end)
        for _, cat in ipairs(CATS) do
            if cat.key ~= "beasts" or isHunter or Count(db and db.pets) > 0 then
                local goals = {}
                for _, g in ipairs(GOALS) do if g.cat == cat.key then goals[#goals + 1] = g end end
                local parts = math.max(1, math.ceil(#goals / PER_PAGE))
                for part = 1, parts do
                    local slice = {}
                    for k = (part - 1) * PER_PAGE + 1, math.min(#goals, part * PER_PAGE) do slice[#slice + 1] = goals[k] end
                    list[#list + 1] = { cat = cat.key, icon = cat.icon, goals = slice, part = part, parts = parts, all = goals }
                end
            end
        end
        return list
    end

    refreshTab = function()
        local db = SkaldCharDB
        if not db then return end
        local facts = Facts()
        local done = db.goals or {}
        spreads = Spreads()
        pageIndex = math.max(1, math.min(pageIndex, #spreads))
        local sp = spreads[pageIndex]
        footer:SetText(string.format(UI.PAGE, pageIndex, #spreads))

        local function Progress(goals)
            local d = 0
            for _, g in ipairs(goals) do if done[g.id] then d = d + 1 end end
            return d, #goals
        end

        -- the chapters listed on the summary, with their counts
        local visible = {}
        for _, s in ipairs(spreads) do if s.cat and s.part == 1 then visible[s.cat] = s end end
        local totalDone, totalAll, shown = 0, 0, 0
        for _, row in ipairs(chapterRows) do
            local s = visible[row.cat.key]
            if s then
                local d, n = Progress(s.all)
                totalDone, totalAll = totalDone + d, totalAll + n
                row.count:SetText(string.format(UI.OF, d, n))
                row.bar:Set(n > 0 and d / n or 0)
                shown = shown + 1
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -112 - (shown - 1) * 50)
            end
            row:SetShown(sp.summary and s ~= nil)
        end

        art:SetShown(not sp.summary)
        chapterCount:SetShown(not sp.summary)
        chapterBar:SetShown(not sp.summary)
        intro:SetShown(not sp.summary)
        introSummary:SetShown(sp.summary and true or false)
        for _, row in ipairs(goalRows) do row:Hide() end
        allDone:Hide()

        if sp.summary then
            leftHeading:SetText(UI.TAB)
            leftNote:SetText(string.format(UI.TOTAL, totalDone, totalAll))
            introSummary:SetText(UI.INTRO_SUMMARY)
            -- on the right page: the goals nearest to being reached
            rightHeading:SetText(UI.NEAR)
            local open = {}
            for _, s in ipairs(spreads) do
                for _, g in ipairs(s.goals or {}) do
                    if not done[g.id] and not g.secret then
                        open[#open + 1] = { g = g, f = math.min(1, (facts[g.fact] or 0) / g.target) }
                    end
                end
            end
            table.sort(open, function(a, b) return a.f > b.f end)
            for i = 1, math.min(PER_PAGE, #open) do FillRow(goalRows[i], open[i].g, facts, done) end
            if #open == 0 then allDone:Show() end
        else
            local d, n = Progress(sp.all)
            local title = UI.CATS[sp.cat]
            if sp.parts > 1 then title = title .. " " .. sp.part .. "/" .. sp.parts end
            leftHeading:SetText(UI.CATS[sp.cat])
            leftNote:SetText("")
            art:SetTexture(TEX .. sp.icon)
            chapterCount:SetText(string.format(UI.OF, d, n))
            chapterBar:Set(n > 0 and d / n or 0)
            intro:SetText(UI.INTRO[sp.cat] or "")
            rightHeading:SetText(title)
            for i, g in ipairs(sp.goals) do FillRow(goalRows[i], g, facts, done) end
        end
    end

    local pager = {
        Turn = function(delta)
            spreads = Spreads()
            pageIndex = math.max(1, math.min(pageIndex + delta, #spreads))
        end,
        CanPrev = function() return pageIndex > 1 end,
        CanNext = function()
            if #spreads == 0 then spreads = Spreads() end
            return pageIndex < #spreads
        end,
    }
    ns.GoalPageInfo = function() return pageIndex, #spreads end   -- for the regression scenarios
    pcall(Check)
    return refreshTab, pager
end

SkaldAPI.AddTab("goals", UI.TAB, BuildGoalsTab)

-- A first look a little after the game has settled (marks what is already done, without pages).
if C_Timer and C_Timer.After then C_Timer.After(8, function() pcall(Check) end) end
