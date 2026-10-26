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
        POINTS = "%d of %d points", PTS = "%d pts", WORTH = "Worth %d points", NEXT_TITLE = "Next title: %s, at %d points.",
        TITLES = { [0] = "Newcomer", [50] = "Wanderer", [150] = "Wayfarer", [300] = "Trailblazer", [500] = "Storied One", [750] = "Legend of the Road", [1100] = "A Name in the Songs", [1600] = "Keeper of Long Tales", [2200] = "Immortal of Azeroth" },
        EMPTY = "Nothing here yet.",
        EVID = { chain = "\"%s\", a chain of %d quests.", hard = "%s (falls before it: %d).", reunion = "Met again: %s.", pet = "%s (%s).", petlevel = "%s reached my level.", with = "With: %s." },
        OPEN_HINT = "Click to open the page in the book.",
        CATS = { explorer = "Exploration", road = "The Road", story = "Stories", war = "War", craft = "Crafts", beasts = "Beasts", company = "Company", collection = "Collection", renown = "Fortune & Renown" },
        FACT = {
            days = "Write pages on %d different days.",
            zones = "Discover %d lands.", flights = "Learn %d flight paths.", level = "Reach level %d.",
            quests = "Complete %d quests.", chains = "Quest chains finished: %d.", rareQ = "Complete a rare quest or better.",
            epicQ = "Complete an epic quest or better.", dungeons = "Dungeons visited: %d.", bosses = "Bosses defeated: %d.",
            hardBoss = "Defeat a boss after falling to it.", kills = "Creatures defeated: %d.", profs = "Trades learned: %d.",
            skillStep = "Reach %d skill in a trade.", pets = "Companions tamed: %d.", petLevel = "See a companion reach your level.",
            companions = "Companions of the road remembered: %d.", reunions = "Meet again someone from a dungeon.",
            guild = "Join a guild.", party = "Join a group for the first time.",
            mounts = "Mounts collected: %d.", critters = "Companion pets collected: %d.",
            gold = "Hold %d gold.", repFriendly = "Become Friendly with a faction.", repHonored = "Become Honored with a faction.", repExalted = "Reach Exalted with a faction.",
        },
        NAMES = {
            quests800 = "Eight Hundred Doors Knocked", quests1500 = "A Life Written in Errands", quests3000 = "The Tavern's Longest Tale",
            kills10000 = "A Harvest of Ten Thousand", kills25000 = "The Reaper's Ledger", bosses50 = "Fifty Thrones Toppled", bosses100 = "A Hundred Crowns in the Dust",
            dungeons15 = "At Home in the Dark", dungeons30 = "Every Cellar, Every Crypt", zones25 = "Half the World Underfoot", zones35 = "No Corner Left Blank",
            flights30 = "The Gryphon Masters Know Me", gold5000 = "A King's Ransom", critters50 = "A Menagerie in My Pockets", mounts20 = "A Stable Fit for a Warlord",
            days7 = "A Week of Pages", days30 = "A Month by Candlelight", days100 = "A Hundred Days Inked", days365 = "A Year in the Book",
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
            mounts1 = "The First Stirrup", mounts5 = "A Stable of My Own", mounts10 = "Hooves, Wings and Scales",
            critters1 = "A Small Companion", critters10 = "Pockets Full of Friends", critters25 = "A Little Ark of Critters",
            gold10 = "A Few Good Coins", gold100 = "A Heavy Purse", gold1000 = "A Dragon's Hoard",
            repFriendly = "A Friendly Face", repHonored = "Honored Guest", repExalted = "Among the Exalted",
        },
    },
    ptBR = {
        TAB = "Metas", OF = "%d de %d", DONE_ON = "Cumprida em %s", BEFORE = "Cumprida antes do diário contar", SECRET = "???",
        SECRET_HINT = "Uma meta ainda por descobrir.", DATE = "%d/%m/%Y", TOTAL = "%d de %d metas cumpridas",
        POINTS = "%d de %d pontos", PTS = "%d pts", WORTH = "Vale %d pontos", NEXT_TITLE = "Próximo título: %s, com %d pontos.",
        TITLES = { [0] = "Recém-chegad{g:o|a}", [50] = "Caminhante", [150] = "Viajante", [300] = "Desbravador{g:|a}", [500] = "Personagem de Lendas", [750] = "Lenda da Estrada", [1100] = "Um Nome nas Canções", [1600] = "Guardi{g:ão|ã} das Longas Histórias", [2200] = "Imortal de Azeroth" },
        EMPTY = "Nada aqui ainda.",
        EVID = { chain = "\"%s\", uma cadeia de %d missões.", hard = "%s (quedas antes dele: %d).", reunion = "Reencontro com %s.", pet = "%s (%s).", petlevel = "%s alcançou o meu nível.", with = "Com: %s." },
        OPEN_HINT = "Clique para abrir a página no livro.",
        CATS = { explorer = "Exploração", road = "A Estrada", story = "Histórias", war = "Guerra", craft = "Ofícios", beasts = "Feras", company = "Companhia", collection = "Coleção", renown = "Fortuna e Renome" },
        FACT = {
            days = "Escreva páginas em %d dias diferentes.",
            zones = "Descubra %d terras.", flights = "Aprenda %d rotas de voo.", level = "Chegue ao nível %d.",
            quests = "Cumpra %d missões.", chains = "Cadeias de missões concluídas: %d.", rareQ = "Cumpra uma missão rara ou melhor.",
            epicQ = "Cumpra uma missão épica ou melhor.", dungeons = "Masmorras visitadas: %d.", bosses = "Chefes derrotados: %d.",
            hardBoss = "Derrote um chefe depois de cair para ele.", kills = "Criaturas vencidas: %d.", profs = "Ofícios aprendidos: %d.",
            skillStep = "Alcance %d de habilidade num ofício.", pets = "Companheiros domados: %d.", petLevel = "Veja um companheiro alcançar o seu nível.",
            companions = "Companheiros de estrada lembrados: %d.", reunions = "Reencontre alguém de uma masmorra.",
            guild = "Entre numa guilda.", party = "Junte-se a um grupo pela primeira vez.",
            mounts = "Montarias reunidas: %d.", critters = "Mascotes reunidos: %d.",
            gold = "Tenha %d de ouro.", repFriendly = "Torne-se Amistoso com uma facção.", repHonored = "Torne-se Honrado com uma facção.", repExalted = "Chegue a Exaltado com uma facção.",
        },
        NAMES = {
            quests800 = "Oitocentas Portas Batidas", quests1500 = "Uma Vida Escrita em Recados", quests3000 = "O Conto Mais Longo da Taverna",
            kills10000 = "Uma Colheita de Dez Mil", kills25000 = "O Livro de Contas do Ceifador", bosses50 = "Cinquenta Tronos Derrubados", bosses100 = "Cem Coroas no Pó",
            dungeons15 = "À Vontade no Escuro", dungeons30 = "Cada Porão, Cada Cripta", zones25 = "Metade do Mundo Sob os Pés", zones35 = "Nenhum Canto em Branco",
            flights30 = "Os Mestres de Voo Me Conhecem", gold5000 = "O Resgate de um Rei", critters50 = "Um Zoológico nos Bolsos", mounts20 = "Um Estábulo Digno de um Senhor da Guerra",
            days7 = "Uma Semana de Páginas", days30 = "Um Mês à Luz de Vela", days100 = "Cem Dias em Tinta", days365 = "Um Ano no Livro",
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
            mounts1 = "O Primeiro Estribo", mounts5 = "Uma Cocheira Só Minha", mounts10 = "Cascos, Asas e Escamas",
            critters1 = "Um Pequeno Companheiro", critters10 = "Bolsos Cheios de Amigos", critters25 = "Uma Arca de Bichinhos",
            gold10 = "Algumas Boas Moedas", gold100 = "Uma Bolsa Pesada", gold1000 = "O Tesouro de um Dragão",
            repFriendly = "Um Rosto Amigo", repHonored = "Hóspede de Honra", repExalted = "Entre os Exaltados",
        },
    },
    frFR = {
        TAB = "Objectifs", OF = "%d sur %d", DONE_ON = "Accompli le %s", BEFORE = "Accompli avant que le journal compte", SECRET = "???",
        SECRET_HINT = "Un objectif encore à découvrir.", DATE = "%d/%m/%Y", TOTAL = "%d objectifs atteints sur %d",
        POINTS = "%d points sur %d", PTS = "%d pts", WORTH = "Vaut %d points", NEXT_TITLE = "Prochain titre\194\160: %s, à %d points.",
        TITLES = { [0] = "Nouv{g:el|elle} arrivant{g:|e}", [50] = "Voyageu{g:r|se}", [150] = "Routi{g:er|ère}", [300] = "Pionni{g:er|ère}", [500] = "Personnage de légende", [750] = "Légende de la route", [1100] = "Un nom dans les chansons", [1600] = "Gardien{g:|ne} des longs récits", [2200] = "Immortel{g:|le} d'Azeroth" },
        EMPTY = "Rien ici pour l'instant.",
        EVID = { chain = "«\194\160%s\194\160», une chaîne de %d quêtes.", hard = "%s (chutes avant lui\194\160: %d).", reunion = "Retrouvailles avec %s.", pet = "%s (%s).", petlevel = "%s a atteint mon niveau.", with = "Avec\194\160: %s." },
        OPEN_HINT = "Cliquez pour ouvrir la page dans le livre.",
        CATS = { explorer = "Exploration", road = "La Route", story = "Histoires", war = "Guerre", craft = "Métiers", beasts = "Bêtes", company = "Compagnie", collection = "Collection", renown = "Fortune et renom" },
        FACT = {
            days = "Écrivez des pages pendant %d jours différents.",
            zones = "Découvrez %d contrées.", flights = "Apprenez %d routes aériennes.", level = "Atteignez le niveau %d.",
            quests = "Accomplissez %d quêtes.", chains = "Chaînes de quêtes terminées\194\160: %d.", rareQ = "Accomplissez une quête rare ou mieux.",
            epicQ = "Accomplissez une quête épique ou mieux.", dungeons = "Donjons visités\194\160: %d.", bosses = "Boss vaincus\194\160: %d.",
            hardBoss = "Vainquez un boss après être tombé devant lui.", kills = "Créatures vaincues\194\160: %d.", profs = "Métiers appris\194\160: %d.",
            skillStep = "Atteignez %d de compétence dans un métier.", pets = "Compagnons apprivoisés\194\160: %d.", petLevel = "Voyez un compagnon atteindre votre niveau.",
            companions = "Compagnons de route dont on se souvient\194\160: %d.", reunions = "Retrouvez quelqu'un d'un donjon.",
            guild = "Rejoignez une guilde.", party = "Rejoignez un groupe pour la première fois.",
            mounts = "Montures réunies\194\160: %d.", critters = "Mascottes réunies\194\160: %d.",
            gold = "Possédez %d pièces d'or.", repFriendly = "Devenez Amical avec une faction.", repHonored = "Devenez Honoré avec une faction.", repExalted = "Atteignez Exalté avec une faction.",
        },
        NAMES = {
            quests800 = "Huit cents portes frappées", quests1500 = "Une vie écrite en courses", quests3000 = "Le plus long récit de la taverne",
            kills10000 = "Une moisson de dix mille", kills25000 = "Le registre du faucheur", bosses50 = "Cinquante trônes renversés", bosses100 = "Cent couronnes dans la poussière",
            dungeons15 = "Chez moi dans l'obscurité", dungeons30 = "Chaque cave, chaque crypte", zones25 = "La moitié du monde sous mes pas", zones35 = "Aucun coin laissé en blanc",
            flights30 = "Les maîtres de vol me connaissent", gold5000 = "La rançon d'un roi", critters50 = "Une ménagerie dans mes poches", mounts20 = "Une écurie digne d'un chef de guerre",
            days7 = "Une semaine de pages", days30 = "Un mois à la chandelle", days100 = "Cent jours à l'encre", days365 = "Une année dans le livre",
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
            mounts1 = "Le premier étrier", mounts5 = "Une écurie bien à moi", mounts10 = "Sabots, ailes et écailles",
            critters1 = "Un petit compagnon", critters10 = "Des poches pleines d'amis", critters25 = "Une petite arche de bestioles",
            gold10 = "Quelques bonnes pièces", gold100 = "Une bourse bien lourde", gold1000 = "Le trésor d'un dragon",
            repFriendly = "Un visage ami", repHonored = "Hôte d'honneur", repExalted = "Parmi les exaltés",
        },
    },
}
local UI = UI_TEXT[GetLocale()] or UI_TEXT.enUS
local TEX = "Interface\\AddOns\\Skald\\Textures\\"

-- The categories, with the page icon that stands for each.
local CATS = {
    { key = "road", icon = "ev_level" }, { key = "explorer", icon = "ev_zone" }, { key = "story", icon = "ev_quest" },
    { key = "war", icon = "ev_boss" }, { key = "craft", icon = "ev_profession" },
    { key = "beasts", icon = "ev_pet" }, { key = "company", icon = "ev_party" }, { key = "collection", icon = "ev_mount" },
    { key = "renown", icon = "st_gold" },
}

-- The goals: `fact` is read from the diary, `target` is what it must reach, `tier` is the rarity of the seal,
-- `secret` keeps the name hidden until the feat is done.
-- `since` is the version of the list in which a goal came: a diary that already looked at the list marks the ones that
-- came later quietly (no page, no notice), whatever they find already done.
local GOALS_VERSION = 4
local GOALS = {
    { id = "level10", cat = "road", tier = 1, fact = "level", target = 10, since = 2 },
    { id = "level20", cat = "road", tier = 2, fact = "level", target = 20, since = 2 },
    { id = "level30", cat = "road", tier = 3, fact = "level", target = 30, since = 2 },
    { id = "level40", cat = "road", tier = 3, fact = "level", target = 40, since = 2 },
    { id = "level50", cat = "road", tier = 4, fact = "level", target = 50, since = 2 },
    { id = "level60", cat = "road", tier = 5, fact = "level", target = 60, since = 2 },
    { id = "zones3", cat = "explorer", tier = 1, fact = "zones", target = 3, since = 2 },
    { id = "zones8", cat = "explorer", tier = 2, fact = "zones", target = 8, since = 2 },
    { id = "zones15", cat = "explorer", tier = 3, fact = "zones", target = 15, since = 2 },
    { id = "flights5", cat = "explorer", tier = 1, fact = "flights", target = 5 },
    { id = "flights15", cat = "explorer", tier = 3, fact = "flights", target = 15 },
    { id = "quests50", cat = "story", tier = 1, fact = "quests", target = 50, since = 3 },
    { id = "quests150", cat = "story", tier = 2, fact = "quests", target = 150, since = 3 },
    { id = "quests400", cat = "story", tier = 4, fact = "quests", target = 400, since = 3 },
    { id = "rareQ", cat = "story", tier = 2, fact = "rareQ", target = 1, since = 2 },
    { id = "epicQ", cat = "story", tier = 4, fact = "epicQ", target = 1, since = 2 },
    { id = "chains1", cat = "story", tier = 3, fact = "chains", target = 1, secret = true },
    { id = "chains5", cat = "story", tier = 4, fact = "chains", target = 5, secret = true },
    { id = "dungeons1", cat = "war", tier = 2, fact = "dungeons", target = 1, since = 2 },
    { id = "dungeons5", cat = "war", tier = 3, fact = "dungeons", target = 5, since = 2 },
    { id = "bosses1", cat = "war", tier = 2, fact = "bosses", target = 1, since = 2 },
    { id = "bosses10", cat = "war", tier = 4, fact = "bosses", target = 10, since = 2 },
    { id = "hardBoss", cat = "war", tier = 3, fact = "hardBoss", target = 1, secret = true },
    { id = "kills500", cat = "war", tier = 2, fact = "kills", target = 500, since = 2 },
    { id = "kills2500", cat = "war", tier = 4, fact = "kills", target = 2500, since = 2 },
    { id = "profs1", cat = "craft", tier = 1, fact = "profs", target = 1, since = 2 },
    { id = "profs2", cat = "craft", tier = 2, fact = "profs", target = 2, since = 2 },
    { id = "skill1", cat = "craft", tier = 1, fact = "skillStep", target = 1, mult = 75, since = 2 },
    { id = "skill2", cat = "craft", tier = 2, fact = "skillStep", target = 2, mult = 75, since = 2 },
    { id = "skill3", cat = "craft", tier = 3, fact = "skillStep", target = 3, mult = 75, since = 2 },
    { id = "skill4", cat = "craft", tier = 4, fact = "skillStep", target = 4, mult = 75, since = 2 },
    { id = "pets1", cat = "beasts", tier = 1, fact = "pets", target = 1 },
    { id = "pets5", cat = "beasts", tier = 2, fact = "pets", target = 5 },
    { id = "pets10", cat = "beasts", tier = 3, fact = "pets", target = 10 },
    { id = "petLevel", cat = "beasts", tier = 3, fact = "petLevel", target = 1 },
    { id = "companions1", cat = "company", tier = 2, fact = "companions", target = 1 },
    { id = "companions5", cat = "company", tier = 3, fact = "companions", target = 5 },
    { id = "reunions", cat = "company", tier = 3, fact = "reunions", target = 1, secret = true },
    { id = "guild", cat = "company", tier = 1, fact = "guild", target = 1, since = 2 },
    { id = "party", cat = "company", tier = 1, fact = "party", target = 1, since = 2 },
    { id = "mounts1", cat = "collection", tier = 2, fact = "mounts", target = 1, since = 3, coll = "mounts" },
    { id = "mounts5", cat = "collection", tier = 3, fact = "mounts", target = 5, since = 3, coll = "mounts" },
    { id = "mounts10", cat = "collection", tier = 4, fact = "mounts", target = 10, since = 3, coll = "mounts" },
    { id = "critters1", cat = "collection", tier = 1, fact = "critters", target = 1, since = 3, coll = "critters" },
    { id = "critters10", cat = "collection", tier = 2, fact = "critters", target = 10, since = 3, coll = "critters" },
    { id = "critters25", cat = "collection", tier = 3, fact = "critters", target = 25, since = 3, coll = "critters" },
    { id = "gold10", cat = "renown", tier = 1, fact = "gold", target = 10, since = 2 },
    { id = "gold100", cat = "renown", tier = 3, fact = "gold", target = 100, since = 2 },
    { id = "gold1000", cat = "renown", tier = 4, fact = "gold", target = 1000, since = 2 },
    { id = "repFriendly", cat = "renown", tier = 2, fact = "repFriendly", target = 1, since = 2 },
    { id = "repHonored", cat = "renown", tier = 3, fact = "repHonored", target = 1, since = 2 },
    { id = "repExalted", cat = "renown", tier = 5, fact = "repExalted", target = 1, since = 2 },
    -- the long haul (version 4): it takes weeks of play, or a year of pages
    { id = "quests800", cat = "story", tier = 4, fact = "quests", target = 800, since = 4 },
    { id = "quests1500", cat = "story", tier = 5, fact = "quests", target = 1500, since = 4 },
    { id = "quests3000", cat = "story", tier = 5, fact = "quests", target = 3000, since = 4 },
    { id = "kills10000", cat = "war", tier = 4, fact = "kills", target = 10000, since = 4 },
    { id = "kills25000", cat = "war", tier = 5, fact = "kills", target = 25000, since = 4 },
    { id = "bosses50", cat = "war", tier = 4, fact = "bosses", target = 50, since = 4 },
    { id = "bosses100", cat = "war", tier = 5, fact = "bosses", target = 100, since = 4 },
    { id = "dungeons15", cat = "war", tier = 4, fact = "dungeons", target = 15, since = 4 },
    { id = "dungeons30", cat = "war", tier = 5, fact = "dungeons", target = 30, since = 4 },
    { id = "zones25", cat = "explorer", tier = 3, fact = "zones", target = 25, since = 4 },
    { id = "zones35", cat = "explorer", tier = 4, fact = "zones", target = 35, since = 4 },
    { id = "flights30", cat = "explorer", tier = 3, fact = "flights", target = 30, since = 4 },
    { id = "gold5000", cat = "renown", tier = 5, fact = "gold", target = 5000, since = 4 },
    { id = "critters50", cat = "collection", tier = 4, fact = "critters", target = 50, since = 4, coll = "critters" },
    { id = "mounts20", cat = "collection", tier = 5, fact = "mounts", target = 20, since = 4, coll = "mounts" },
    { id = "days7", cat = "road", tier = 1, fact = "days", target = 7, since = 4 },
    { id = "days30", cat = "road", tier = 2, fact = "days", target = 30, since = 4 },
    { id = "days100", cat = "road", tier = 4, fact = "days", target = 100, since = 4 },
    { id = "days365", cat = "road", tier = 5, fact = "days", target = 365, since = 4 },
}
-- Points follow the rarity of the seal (common .. legendary). They are worked out when shown, from the goals reached,
-- so a change of value needs no change to what is saved.
local POINTS = { 5, 10, 25, 50, 100 }
-- (The names of feats dropped from the list stay in the texts below: a page already written may name one.)
local GOAL_BY_ID = {}
for _, g in ipairs(GOALS) do GOAL_BY_ID[g.id] = g end

ns.GoalName = function(id) return UI.NAMES[id] or tostring(id) end
ns.GoalPoints = function(id)
    local g = GOAL_BY_ID[id]
    return g and POINTS[g.tier] or nil
end
-- What the goals reached are worth, and what all of them are worth.
-- (the beasts are shown only to a hunter, or to whoever has had a pet: the same rule for the tab and the points)
-- A collection goal is listed only when this client's journal answered for it (or when it was already reached):
-- a system the client lacks would leave a goal that can never be done.
local function Listed(g, db)
    if not g.coll then return true end
    if db and db.goals and db.goals[g.id] then return true end
    local c = SkaldAPI.Collections and SkaldAPI.Collections() or {}
    return (g.coll == "mounts" and c.mountsReady or g.coll == "critters" and c.petsReady) and true or false
end
local function CategoryShown(key, db)
    if key == "collection" then
        for _, g in ipairs(GOALS) do if g.cat == key and Listed(g, db) then return true end end
        return false
    end
    if key ~= "beasts" then return true end
    local isHunter = false
    pcall(function() isHunter = select(2, UnitClass("player")) == "HUNTER" end)
    if isHunter then return true end
    for _ in pairs((db and db.pets) or {}) do return true end
    return false
end
ns.GoalScore = function()
    local db = SkaldCharDB
    local done, all = 0, 0
    for _, g in ipairs(GOALS) do
        local p = POINTS[g.tier] or 0
        if not CategoryShown(g.cat, db) or not Listed(g, db) then p = 0 end
        all = all + p
        if db and db.goals and db.goals[g.id] then done = done + p end
    end
    return done, all
end
-- The title the points earn: the highest step reached.
ns.GoalTitle = function(points)
    local best
    for step in pairs(UI.TITLES) do
        if points >= step and (not best or step > best) then best = step end
    end
    return best and ns.Gendered(UI.TITLES[best]) or ""
end
ns.GoalList = GOALS
ns.GoalUI = UI

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- The calendar days with a page. Worked out again only when the pages change (the count and the last one), as the
-- tab and the check ask for the facts often.
local daysCache
local function DaysWritten(entries)
    local n, last = #entries, entries[#entries]
    local lastT = last and last.t or 0
    if daysCache and daysCache.entries == entries and daysCache.n == n and daysCache.lastT == lastT then return daysCache.days end
    local seen, days = {}, 0
    for _, e in ipairs(entries) do
        if type(e.t) == "number" then
            local d = date("%Y%m%d", e.t)
            if not seen[d] then seen[d] = true; days = days + 1 end
        end
    end
    daysCache = { entries = entries, n = n, lastT = lastT, days = days }
    return days
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
    if type(exact.quests) == "number" then f.quests = math.max(f.quests, exact.quests) end
    f.mounts, f.critters, f.collReady = exact.mounts or 0, exact.critters or 0, exact.collReady
    f.profs = Count(db.skills)
    local best = 0
    for _, step in pairs(db.skills or {}) do if type(step) == "number" and step > best then best = step end end
    f.skillStep = best
    f.pets = Count(db.pets)
    -- gold held now (once a goal is reached it is kept, whatever is spent later) and the standings the diary has seen
    local copper = GetMoney and GetMoney()
    f.gold = type(copper) == "number" and math.floor(copper / 10000) or 0
    local friendly, honored, exalted = 0, 0, 0
    for _, standing in pairs(db.rep or {}) do
        if type(standing) == "number" then
            if standing >= 5 then friendly = friendly + 1 end
            if standing >= 6 then honored = honored + 1 end
            if standing >= 8 then exalted = exalted + 1 end
        end
    end
    f.repFriendly, f.repHonored, f.repExalted = friendly, honored, exalted
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
    f.days = DaysWritten(db.entries or {})
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
    local seenVersion = db.goalsVer or 1
    local facts = Facts()
    for _, g in ipairs(GOALS) do
        -- a collection is read only once the game's journal has answered (an unloaded journal is not an empty one)
        if not db.goals[g.id] and (facts[g.fact] or 0) >= g.target and Listed(g, db) then
            -- a goal that came with a later version of the list is marked quietly the first time it is looked at;
            -- so is a collection the first time the journal is read (what was owned before the diary is no feat of today)
            local quiet = silent or seenVersion < (g.since or 1) or (g.coll and not db.collInit)
            db.goals[g.id] = { t = time(), retro = quiet or nil }
            if not quiet then
                SkaldAPI.AddEntry("goal", g.id, nil, { tier = g.tier, m = false, x = false, y = false })
            end
        end
    end
    if facts.collReady then db.collInit = true end
    db.goalsInit = true
    db.goalsVer = GOALS_VERSION
end
ns.CheckGoals = Check

-- What a goal reached was about: a line naming the quest, the boss, the companion, and the page it is written
-- on (to open it in the book). Read from the pages of the diary, so goals reached before it counted have it too.
local function Evidence(g, db)
    local entries = db.entries or {}
    local function nth(match, n)
        local c = 0
        for _, e in ipairs(entries) do
            if match(e) then
                c = c + 1
                if c == n then return e end
            end
        end
    end
    local fact = g.fact
    local e
    if fact == "chains" then
        e = nth(function(x) return x.kind == "quest" and (x.cend or 0) >= 2 end, g.target)
        if e then return string.format(UI.EVID.chain, tostring(e.arg), e.cend), e end
    elseif fact == "hardBoss" then
        e = nth(function(x) return x.kind == "boss" and (x.tries or 0) >= 1 end, g.target)
        if e then return string.format(UI.EVID.hard, tostring(e.arg), e.tries), e end
    elseif fact == "reunions" then
        e = nth(function(x) return x.kind == "reunion" end, g.target)
        if e then return string.format(UI.EVID.reunion, tostring(e.arg)), e end
    elseif fact == "pets" then
        e = nth(function(x) return x.kind == "tame" end, g.target)
        if e then
            local rec = db.pets and db.pets[tostring(e.arg)]
            local fam = rec and rec.fam or e.fam
            if ns.FamilyLabel then fam = ns.FamilyLabel(fam) end
            if type(fam) == "string" and fam ~= "" and fam:lower() ~= tostring(e.arg):lower() then
                return string.format(UI.EVID.pet, tostring(e.arg), fam), e
            end
            return tostring(e.arg), e
        end
    elseif fact == "petLevel" then
        e = nth(function(x) return x.kind == "tame" and x.sub == "level" end, g.target)
        if e then return string.format(UI.EVID.petlevel, tostring(e.arg)), e end
    elseif fact == "companions" then
        local names = {}
        for name, c in pairs(db.companions or {}) do names[#names + 1] = { name, c.first or 0 } end
        table.sort(names, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
        local list = {}
        for i = 1, math.min(#names, g.target, 5) do list[#list + 1] = names[i][1] end
        if #list > 0 then return string.format(UI.EVID["with"], table.concat(list, ", ")) end
    end
end

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

-- The tab: the categories on the left page, the goals of the chosen one on the right page. -------------------
local function BuildGoalsTab(panel)
    local CW = SkaldAPI.CW or 342
    local RIGHT_X = SkaldAPI.RIGHT_X or 402
    local body = SkaldAPI.C_BODY or { 0.24, 0.16, 0.09 }
    local head = SkaldAPI.C_HEAD or { 0.43, 0.12, 0.10 }
    local muted = SkaldAPI.C_MUTED or { 0.42, 0.29, 0.17 }
    local sealPath = "Interface\\AddOns\\Skald\\Textures\\seal"

    SkaldAPI.PageHeading(panel, UI.TAB, 0)
    local total, titleLine, pointsBar, header   -- the band under the heading, made once the bar is defined
    local rightTitle = SkaldAPI.PageHeading(panel, "", RIGHT_X)

    -- A bar: the frame of the picture over a gold fill.
    local function MakeBar(parent, width, height)
        local bar = CreateFrame("Frame", nil, parent)
        bar:SetSize(width, height)
        -- the brass frame fills 85% of its picture (434 of 512 across), so the picture is drawn wider than the bar
        bar.frame = bar:CreateTexture(nil, "ARTWORK")
        bar.frame:SetSize(width * 512 / 434, height + 3)
        bar.frame:SetPoint("TOPLEFT", -width * 40 / 434, 1)
        bar.frame:SetTexture(TEX .. "ui_bar_frame")
        bar.fill = bar:CreateTexture(nil, "OVERLAY")
        bar.fill:SetTexture(TEX .. "ui_bar_fill")
        bar.fill:SetPoint("TOPLEFT", 8, -3)
        bar.fill:SetHeight(height - 6)
        bar.max = width - 16
        function bar:Set(fraction)
            fraction = math.max(0, math.min(1, fraction or 0))
            self.fill:SetWidth(math.max(0.01, self.max * fraction))
            self.fill:SetShown(fraction > 0)
        end
        return bar
    end

    -- The band under the heading: the title the points earn, the goals and points, and a bar toward the next title.
    header = CreateFrame("Frame", nil, panel)
    header:SetSize(CW, 48)
    header:SetPoint("TOPLEFT", 0, -42)   -- below the rule of the heading
    header:EnableMouse(true)
    local emblem = header:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(26, 26)
    titleLine = header:CreateFontString(nil, "OVERLAY", "SkaldSec")
    titleLine:SetPoint("TOP", 0, 0)
    titleLine:SetWidth(CW)
    titleLine:SetJustifyH("CENTER")
    titleLine:SetTextColor(head[1], head[2], head[3])
    total = header:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    total:SetPoint("TOP", 0, -18)
    total:SetWidth(CW)
    total:SetJustifyH("CENTER")
    total:SetTextColor(muted[1], muted[2], muted[3])
    pointsBar = MakeBar(header, CW - 70, 14)
    pointsBar:SetPoint("TOP", 0, -33)
    header:SetScript("OnEnter", function(self)
        if not self.nextTitle then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(string.format(UI.NEXT_TITLE, self.nextTitle, self.nextAt), 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local categoryRows, goalRows = {}, {}
    local chosen = 1
    local goalPage = 1   -- the right page shows seven goals at a time: a long category goes over more pages
    local visibleCats

    for i, cat in ipairs(CATS) do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 38)
        row:SetPoint("TOPLEFT", 0, -98 - (i - 1) * 42)
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
        row.mark = row:CreateTexture(nil, "BACKGROUND")
        -- the brush stroke of ink under the chosen category (its picture has a clear margin: 433 of 512 across)
        row.mark:SetSize(CW * 512 / 433, 44)
        row.mark:SetPoint("LEFT", row, "LEFT", -CW * 39 / 433, 0)
        row.mark:SetTexture(TEX .. "ui_ink")
        row.mark:Hide()
        row:SetScript("OnClick", function() chosen = i; goalPage = 1; if refreshTab then refreshTab() end end)
        row.cat = cat
        categoryRows[i] = row
    end

    for i = 1, 7 do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(CW, 50)
        row:SetPoint("TOPLEFT", RIGHT_X, -52 - (i - 1) * 52)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(36, 36)
        row.icon:SetPoint("TOPLEFT", 0, -4)
        row.name = row:CreateFontString(nil, "OVERLAY", "SkaldBody")
        row.name:SetPoint("TOPLEFT", 46, -2)
        row.name:SetWidth(CW - 50)
        row.name:SetJustifyH("LEFT")
        -- the points: one column on the right edge (the gem and the number, no "pts": the heading says points); the
        -- count of the goal sits under it on the same edge, level with the bar
        row.points = row:CreateFontString(nil, "OVERLAY", "SkaldSec")
        -- a block aligned to the left at 62 px from the right edge: the gem, the number touching it, and the count
        -- starting on the same vertical as the gem
        row.points:SetWidth(36)
        row.points:SetJustifyH("LEFT")
        row.points:SetPoint("TOPLEFT", row, "TOPRIGHT", -38, -3)
        row.gem = row:CreateTexture(nil, "ARTWORK")
        row.gem:SetSize(20, 20)
        row.gem:SetPoint("RIGHT", row.points, "LEFT", -4, 0)
        row.gem:SetTexture(TEX .. "pt_gem")
        row.name:SetWidth(CW - 116)
        row.desc = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.desc:SetPoint("TOPLEFT", 46, -20)
        row.desc:SetWidth(CW - 50)
        row.desc:SetJustifyH("LEFT")
        row.desc:SetTextColor(muted[1], muted[2], muted[3])
        row.bar = MakeBar(row, CW - 116, 14)
        row.bar:SetPoint("TOPLEFT", 46, -34)
        row.count = row:CreateFontString(nil, "OVERLAY", "SkaldSmall")
        row.count:SetWidth(62)
        row.count:SetJustifyH("LEFT")
        row.count:SetPoint("LEFT", row, "TOPRIGHT", -62, -41)
        row.count:SetTextColor(muted[1], muted[2], muted[3])
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(0.43, 0.12, 0.10, 0.08)
        row.hover:Hide()
        row:SetScript("OnEnter", function(self)
            if not self.worth then return end
            self.hover:Show()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.title or "", 1, 0.82, 0)
            GameTooltip:AddLine(string.format(UI.WORTH, self.worth), 0.8, 0.8, 0.8)
            if self.evidence then GameTooltip:AddLine(self.evidence, 1, 1, 1, true) end
            if self.entry then GameTooltip:AddLine(UI.OPEN_HINT, 0.7, 0.7, 0.7, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.entry and SkaldAPI.OpenEntry then SkaldAPI.OpenEntry(self.entry) end
        end)
        goalRows[i] = row
    end

    -- the pager, at the right of the heading: previous, "2/3", next (the wheel over the goals turns it too)
    local pager = CreateFrame("Frame", nil, panel)
    pager:SetSize(76, 20)
    pager:SetPoint("TOPRIGHT", panel, "TOPLEFT", RIGHT_X + CW, -12)
    local function PagerButton(label, x, step)
        local b = CreateFrame("Button", nil, pager)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", x, 0)
        b.text = b:CreateFontString(nil, "OVERLAY", "SkaldSec")
        b.text:SetPoint("CENTER")
        b.text:SetText(label)
        b.text:SetTextColor(head[1], head[2], head[3])
        b:SetScript("OnClick", function() goalPage = goalPage + step; if refreshTab then refreshTab() end end)
        b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(self) self.text:SetTextColor(head[1], head[2], head[3]) end)
        return b
    end
    local prevButton, nextButton = PagerButton("<", 0, -1), PagerButton(">", 56, 1)
    local pageLabel = pager:CreateFontString(nil, "OVERLAY", "SkaldSmall")
    pageLabel:SetPoint("CENTER", 0, 0)
    pageLabel:SetTextColor(muted[1], muted[2], muted[3])
    pager.label = pageLabel   -- for the tests
    for _, row in ipairs(goalRows) do
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta) goalPage = goalPage - delta; if refreshTab then refreshTab() end end)
    end

    refreshTab = function()
        local db = SkaldCharDB
        if not db then return end
        local facts = Facts()
        local done = db.goals or {}
        local totalDone, totalAll = 0, 0
        -- the categories (the beasts only for a hunter, or whoever has had a pet)
        local shown = 0
        visibleCats = {}
        for i, row in ipairs(categoryRows) do
            local cat = row.cat
            local show = CategoryShown(cat.key, db)
            local n, d = 0, 0
            for _, g in ipairs(GOALS) do
                if g.cat == cat.key and Listed(g, db) then n = n + 1; if done[g.id] then d = d + 1 end end
            end
            row:SetShown(show)
            if show then
                shown = shown + 1
                visibleCats[#visibleCats + 1] = i
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -98 - (shown - 1) * 42)
                row.count:SetText(string.format(UI.OF, d, n))
                row.bar:Set(n > 0 and d / n or 0)
                totalDone, totalAll = totalDone + d, totalAll + n
            end
        end
        local earned, possible = ns.GoalScore()
        total:SetText(string.format(UI.TOTAL, totalDone, totalAll) .. "  -  " .. string.format(UI.POINTS, earned, possible))
        titleLine:SetText(ns.GoalTitle(earned))
        -- the emblem of the title sits before it (the steps in order: one emblem for each)
        local steps = {}
        for step in pairs(UI.TITLES) do steps[#steps + 1] = step end
        table.sort(steps)
        local rank = 1
        for i, step in ipairs(steps) do if earned >= step then rank = i end end
        emblem:SetTexture(TEX .. "pt_title" .. (rank - 1))
        local tw = titleLine.GetStringWidth and titleLine:GetStringWidth()
        if type(tw) ~= "number" then tw = 80 end
        emblem:ClearAllPoints()
        emblem:SetPoint("RIGHT", titleLine, "CENTER", -tw / 2 - 5, 0)
        local current, nextAt = 0, nil
        for step in pairs(UI.TITLES) do
            if step <= earned and step > current then current = step end
            if step > earned and (not nextAt or step < nextAt) then nextAt = step end
        end
        pointsBar:Set(nextAt and (earned - current) / (nextAt - current) or 1)
        header.nextAt = nextAt
        header.nextTitle = nextAt and ns.Gendered(UI.TITLES[nextAt]) or nil
        if not categoryRows[chosen] or not categoryRows[chosen]:IsShown() then chosen = visibleCats[1] or 1 end
        for i, row in ipairs(categoryRows) do row.mark:SetShown(i == chosen) end

        -- the goals of the chosen category
        local cat = CATS[chosen]
        rightTitle:SetText(UI.CATS[cat.key])
        local list = {}
        for _, g in ipairs(GOALS) do if g.cat == cat.key and Listed(g, db) then list[#list + 1] = g end end
        local perPage = #goalRows
        local pages = math.max(1, math.ceil(#list / perPage))
        goalPage = math.max(1, math.min(goalPage, pages))
        pager:SetShown(pages > 1)
        pageLabel:SetText(goalPage .. "/" .. pages)
        prevButton:SetAlpha(goalPage > 1 and 1 or 0.35)
        nextButton:SetAlpha(goalPage < pages and 1 or 0.35)
        for i, row in ipairs(goalRows) do
            local g = list[(goalPage - 1) * perPage + i]
            if not g then
                row:Hide()
            else
                row:Show()
                local rec = done[g.id]
                local value = facts[g.fact] or 0
                local target = g.target
                row.evidence, row.entry = nil, nil
                row.worth, row.title = (not g.secret or rec) and (POINTS[g.tier] or 0) or nil, UI.NAMES[g.id]
                row.points:SetText((g.secret and not rec) and "?" or tostring(POINTS[g.tier] or 0))
                if rec then
                    row.points:SetTextColor(head[1], head[2], head[3])
                    row.gem:SetAlpha(1)
                else
                    row.points:SetTextColor(muted[1], muted[2], muted[3])
                    row.gem:SetAlpha(0.45)
                end
                -- a goal still to do shows its seal faded and without colour; one reached shows it in full
                pcall(row.icon.SetDesaturated, row.icon, not rec and not g.secret)
                if rec then
                    row.icon:SetTexture(TEX .. "goal_medal" .. g.tier)
                    row.icon:SetAlpha(1)
                    row.name:SetText(UI.NAMES[g.id])
                    row.name:SetTextColor(head[1], head[2], head[3])
                    local line, entry = Evidence(g, db)
                    row.evidence, row.entry, row.title = line, entry, UI.NAMES[g.id]
                    row.desc:SetText(line or (rec.retro and UI.BEFORE or string.format(UI.DONE_ON, date(UI.DATE, rec.t or time()))))
                    row.bar:Set(1)
                    row.count:SetText((not rec.retro and rec.t) and date(UI.DATE, rec.t) or "")
                elseif g.secret then
                    row.icon:SetTexture(TEX .. "goal_locked")
                    row.icon:SetAlpha(0.8)
                    row.name:SetText(UI.SECRET)
                    row.name:SetTextColor(muted[1], muted[2], muted[3])
                    row.desc:SetText(UI.SECRET_HINT)
                    row.bar:Set(0)
                    row.count:SetText("")
                else
                    row.icon:SetTexture(TEX .. "goal_medal" .. g.tier)
                    row.icon:SetAlpha(0.6)
                    row.name:SetText(UI.NAMES[g.id])
                    row.name:SetTextColor(body[1], body[2], body[3])
                    local shownTarget = target * (g.mult or 1)
                    row.desc:SetText(string.format(UI.FACT[g.fact], shownTarget))
                    row.bar:Set(math.min(value, target) / target)
                    row.count:SetText(string.format(UI.OF, math.min(value, target) * (g.mult or 1), shownTarget))
                end
            end
        end
    end
    pcall(Check)
    return refreshTab
end

SkaldAPI.AddTab("goals", UI.TAB, BuildGoalsTab)

-- A first look a little after the game has settled (marks what is already done, without pages).
if C_Timer and C_Timer.After then C_Timer.After(8, function() pcall(Check) end) end
