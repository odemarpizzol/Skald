-- Skald: the Saga. The whole diary told as one short book of chapters, in the first person, from what the diary
-- already knows (pages, counters, the game's own statistics, companions, goals). Nothing is stored: the text is built
-- when asked, so a change of language rewrites it, and the same diary always gives the same Saga (each phrase is
-- picked by a hash of stable data, never by chance).
--
-- Loaded after Goals.lua: it uses SkaldAPI (AddTab, PageHeading, GameFacts...) and the saved diary SkaldCharDB.
local _, ns = ...

-- Tags: {name} {race} {class} {date} {place} {level} {days} {n} {boss} {tries} {names} {points} {title} {pages},
-- {g:he|she} for words that agree with the one who speaks, and {#n:quest|quests} for a number with its noun (the
-- singular for one). A bare number ("the count is {n}") is kept for a few phrases only: a Saga that counted in
-- every chapter would read like a ledger.
local TEXT = {
    enUS = {
        TAB = "Saga", EMPTY = "The saga begins with the first page.", AND = " and ", DATE = "%m/%d/%Y",
        TITLES = {
            prologue = "Prologue", road = "The Road", stories = "Errands and Oaths", war = "Thrones Toppled",
            falls = "The Falls", company = "Company", marks = "Seals and Renown", epilogue = "Epilogue",
        },
        POOLS = {
            prologue = {
                "My name is {name}. I am {a} {race} {class}, and the first page of this diary was written on {date}, in {place}, with no notion of where the road would lead.",
                "On {date}, in {place}, I first set quill to paper. {name} the {race} {class}: a name that meant little then, and means more with every page.",
                "Every saga starts small. Mine begins on a page written in {place}, on {date}, by {a} {race} {class} named {name}, who decided that the road deserved to be remembered.",
                "I did not set out to become a tale. I only began to write, on {date}, in {place}, {a} {race} {class}, and the tale simply followed the quill.",
                "They will say the story begins where the diary does. It does: {place}, {date}, with {a} {class} who had yet to learn what the road would ask.",
                "Let it be written: on {date}, in {place}, {name} opened this book. {A} {race} {class}, with a satchel, a name, and a long road ahead.",
                "The first page is dated {date}, and it was written in {place}. I was only {a} {race} {class} then, and I am still, but now I have a story to prove it.",
                "Before the legend, the first page: {place}, {date}, {a} {race} {class} called {name}. Small things, true things, the kind every saga is built on.",
            },
            birth = {
                "My name is {name}, {a} {race} {class}. I was born in {home}, in {land}, and everything I have done since began there.",
                "I came into the world in {home}, in {land}. A small place for a story that has grown larger with every page.",
                "Every people has its beginning, and mine was {home}, in {land}. The road leads away from it, but it never quite forgets the way back.",
                "{name}, {a} {race} {class}, born in {home}, in {land}. Little more was known of me then than the name of that place.",
                "Let it be told where it began: {home}, in {land}, among my own, with a name, a satchel, and a long road to learn.",
                "They say a saga should start where its hero was born, and mine starts in {home}, in {land}, where {a} {race} named {name} first looked at the sky.",
                "Before the roads, before the quests, there was {home}, in {land}: the place where I, {name}, {a} {race} {class}, took my first steps.",
                "I was born in {home}, in {land}. Whatever the road makes of me, that is where I come from.",
            },
            firstPage = {
                "The first page of this diary was written on {date}, in {place}.",
                "I began to write on {date}, in {place}, and I have not stopped since.",
                "This diary opens on {date}, in {place}, with a first page.",
                "The quill first touched the paper on {date}, in {place}.",
                "It was on {date}, in {place}, that I decided the road deserved a book.",
                "The record of these pages starts on {date}, in {place}.",
                "On {date}, in {place}, the first line of this book was written.",
                "From {date}, in {place}, the road has been kept on paper.",
            },
            earliest = {
                "The oldest deed the game remembers of me is dated {born}.",
                "By the game's own memory, my first deed goes back to {born}.",
                "The earliest mark I left in the world is from {born}.",
                "The world has known me since {born}, at the least.",
                "Long before this diary, on {born}, the game already held a deed of mine.",
                "My oldest recorded deed is from {born}.",
                "The game holds a deed of mine from {born}, older than any page here.",
                "{born}: the date of the oldest deed the world remembers of me.",
            },
            road = {
                "Level by level the road taught me its lessons. I stand at level {level} now, and it was in {place} that I last climbed.",
                "Level {level} is where this page finds me, and {place} is where I last grew. {#days:day|days} of road lie behind me.",
                "I have not hurried, and I have not stopped. Level {level}, with {place} behind me and {#days:day|days} on the road.",
                "The road does not measure a traveler in years but in steps, and mine have brought me to level {level}. The last of them was taken in {place}.",
                "Every level was a door, and {place} was the last one I opened. Level {level} waits on the other side.",
                "If you ask how far I have come: level {level}, and the last stretch was in {place}. If you ask for how long: {#days:day|days}, by these pages.",
                "I measure the road in levels, and today the measure reads {level}. It last rose in {place}; the day count behind it is {days}.",
                "Strong legs, light pack, level {level}. {place} marks the last time I felt myself grow, and the first page is {#days:day|days} old.",
            },
            stories = {
                "Quests were the pages of my days: errands, oaths, small promises kept. I saw {#n:quest|quests} through to their end.",
                "Every quest is a promise, and I have tried to keep them all: {#n:promise|promises} kept so far.",
                "Some tasks were small, some became tales worth telling. Together they are {#n:quest|quests}, and I would not trade one.",
                "I never refused a stranger who needed a hand, and the log proves it: {#n:quest|quests} seen through, from the first errand to the latest.",
                "A road is made of errands. Mine, finished and signed, are {#n:quest|quests}, and each left its mark on the way I walk.",
                "Ask the villages what I did for them and they will tell you of errands. I can tell you the number: {n}.",
                "The quest log is a book of its own, and it holds {#n:closed entry|closed entries}. I carry them all, lightly.",
                "What is a hero but someone who answers when called? I have answered {#n:time|times}, and the calling has not stopped.",
            },
            war = {
                "Some foes do not fall to a sword alone. They fall to patience, to friends, to the third try. I brought down {#n:great one|great ones}.",
                "I have stood in halls where the walls remember every blow, and left {#n:boss|bosses} fallen behind me.",
                "A boss is a question the dungeon asks, and each time I answered with steel and company. I have answered {#n:time|times}.",
                "They guarded their thrones with everything they had, and it was not enough. I have seen {#n:throne|thrones} emptied.",
                "The war-horns of the deep places sound for me now. Bosses defeated: {n}.",
                "I came to the depths to be tested, and I was. Among my foes, {#n:champion lies|champions lie} still because of me.",
                "Blood, noise, and then the silence after the fall of the great one. I have heard that silence {#n:time|times}.",
                "No song of mine is without a clash of arms. {#n:great adversary|great adversaries} ended in it.",
            },
            warHard = {
                "{boss} did not yield easily. I fell before it, and rose, and the victory cost me {#tries:fall|falls}.",
                "Of all the great ones, {boss} cost me the most: {#tries:fall|falls} before it finally lay still.",
                "{boss} taught me humility first and victory after, at the price of {#tries:fall|falls}.",
                "I remember {boss} best, because I lost to it before I won: {#tries:lost attempt|lost attempts}.",
                "Victory over {boss} was sweeter for the road it took, a road of {#tries:fall|falls}.",
                "Some wins are clean. The one over {boss} was not, and I would not have it otherwise: {#tries:fall|falls} came first.",
                "They will tell of {boss} as the one that nearly beat me. {#tries:fall|falls} before the win.",
                "{boss} stood between me and the next chapter, and charged a toll of {#tries:fall|falls}. I paid, and passed.",
            },
            falls = {
                "I have fallen, and I will not pretend otherwise: {#n:fall|falls} in all.",
                "A hero is measured by the rising as much as by the glory. I have risen after {#n:fall|falls}.",
                "Death has been a stranger to no one on this road. I met it {#n:time|times}.",
                "The spirit healer knows my face: {#n:visit|visits}.",
                "Not every page is a triumph. Some are the quiet after a fall: {#n:page|pages} of them.",
                "I got up every time, after {#n:fall|falls} in all.",
                "Every fall left a lesson: {#n:lesson|lessons} learned the hard way.",
                "I have lain on the ground more often than I like to admit: {#n:fall|falls}, and every one earned.",
            },
            fallsPlace = {
                "It was in {place} that I fell most.",
                "{place} was the harshest teacher.",
                "In {place}, death called the loudest.",
                "The land that asked the most of me was {place}.",
                "I know the ground of {place} better than most, from lying on it.",
                "{place} took more from me than any other land.",
                "If I fall again, I would rather it not be in {place}.",
                "Ask me where it hurt most and I will say {place}.",
            },
            company = {
                "I did not walk alone. I have chosen to remember {#n:face|faces} along the road.",
                "A road is lighter with company. I carry {#n:companion|companions} in memory.",
                "Names matter more than gold, and my diary keeps {#n:name|names} of those who walked beside me.",
                "Some strangers stay in the memory because they stood beside me when it mattered: {#n:stranger|strangers} in all.",
                "Dungeons and long roads make friends of strangers. My book of companions holds {#n:name|names}.",
                "No saga is told by one voice alone. {#n:voice|voices} walked with me and are remembered here.",
                "I keep them as one keeps a lamp: {#n:companion|companions} of the road, each a small light.",
                "Fellowship was the best treasure of the road, and I remember {#n:companion|companions}.",
            },
            companyNames = {
                "Among them, I remember best: {names}.",
                "I think most often of {names}.",
                "If the road ever takes me back to {names}, the ale is on me.",
                "The names that stay brightest: {names}.",
                "Let it be written that I walked with {names}.",
                "To {names}: thank you for the company.",
                "Of all of them, those I would walk with again: {names}.",
                "I raise a cup, in memory, to {names}.",
            },
            marks = {
                "The road also asked for deeds worth a seal. I reached {#n:goal|goals}, worth {#points:point|points}, and the title they earned me is {title}.",
                "I have gathered {#points:point|points} of renown in goals reached, {n} in all, and with them the title of {title}.",
                "A seal here, a seal there: {#n:goal|goals} reached, {#points:point|points} won, and the title they bring is {title}.",
                "Renown is a ledger, and I keep mine. Goals reached: {n}. Points: {points}. They call me {title}.",
                "Not everything that matters can be measured, but some of it can. Goals reached: {n}; points: {points}; my title, {title}.",
                "{title}: that is what {#points:point|points} of renown, won in {#n:goal|goals}, have made of me.",
                "The seals of the book hold my goals: reached, {n}; worth, {#points:point|points}; and the title, {title}.",
                "Small goals, larger ones, a few that took patience: {#n:goal|goals} reached, {#points:point|points} won, and the name {title} to wear.",
            },
            epilogue = {
                "The story is not over, only paused where this page ends. I stand at level {level}, with {#pages:page|pages} written, and the road still opens ahead of {name}.",
                "Here I close the book for now. Level {level}, and the diary count stands at {pages}. The rest is road, and the road is long.",
                "If this were the last page, I would be content: {#pages:page|pages} kept, level {level} reached, and a name that was mine to write. But there is more road.",
                "Saga, they call it. I call it the road so far: level {level}, {#pages:page|pages} kept. The next chapter waits for {name} outside the door.",
                "Let whoever reads this know that {name} was here, reached level {level}, and kept {#pages:page|pages} to prove it. The story goes on.",
                "The ink is dry on {#pages:page|pages}, and the road is not. Level {level} is only where I stand today.",
                "What is a saga but a road remembered? Mine, so far: level {level}, {#pages:page|pages} kept, and the rest still unwritten.",
                "Close the book gently, and leave the quill nearby. {name}, level {level}, has more to tell. The page tally so far: {pages}.",
            },
            epilogueTop = {
                "Level sixty. The top of the world, and the page where a saga might rightly end. It will not: {name} has {#pages:page|pages} kept, and the road still has its turns.",
                "I reached the summit, and the view was worth every one of {#pages:page|pages} written on the way. Now I look at the horizon, because there is always one more.",
                "From the top of the world, {name} looks back along the road: {#pages:page|pages} kept, and every one a step.",
                "This is the end of the climb and the beginning of the legend. {#pages:page|pages} written. The title: {title}.",
                "They said the road had a top. They were right, and I stood on it. The page count on the way: {pages}.",
                "At the top, one thing is clear: the story was never the level, it was the road. In this book the road runs {#pages:page|pages} long, and it is still open.",
                "Sixty levels, and the diary kept me honest across {#pages:page|pages}. {name}, {title}, closes the book only to open another.",
                "A saga's last chapter is the promise of the next. I have kept {#pages:page|pages}, and I have kept the promise too.",
            },
        },
    },
    ptBR = {
        TAB = "Saga", EMPTY = "A saga começa com a primeira página.", AND = " e ", DATE = "%d/%m/%Y",
        TITLES = {
            prologue = "Prólogo", road = "A Estrada", stories = "Recados e Juramentos", war = "Tronos Derrubados",
            falls = "As Quedas", company = "Companhia", marks = "Selos e Renome", epilogue = "Epílogo",
        },
        POOLS = {
            prologue = {
                "Meu nome é {name}. Sou {g:um|uma} {race} {class}, e a primeira página deste diário foi escrita em {date}, em {place}, sem ideia de aonde a estrada me levaria.",
                "Em {date}, em {place}, pus a pena no papel pela primeira vez. {name}, {g:um|uma} {race} {class}: um nome que pouco dizia então e que diz mais a cada página.",
                "Toda saga começa pequena. A minha começa numa página escrita em {place}, em {date}, por {g:um|uma} {race} {class} chamad{g:o|a} {name}, que decidiu que a estrada merecia ser lembrada.",
                "Não parti para virar história. Só comecei a escrever, em {date}, em {place}, {g:um|uma} {race} {class}, e a história seguiu a pena.",
                "Dirão que a história começa onde o diário começa. Começa: {place}, {date}, com {g:um|uma} {class} que ainda não sabia o que a estrada iria pedir.",
                "Fique escrito: em {date}, em {place}, {name} abriu este livro. {g:Um|Uma} {race} {class}, com uma bolsa, um nome e uma longa estrada pela frente.",
                "A primeira página tem a data de {date} e foi escrita em {place}. Eu era só {g:um|uma} {race} {class} então, e ainda sou, mas agora tenho uma história para provar.",
                "Antes da lenda, a primeira página: {place}, {date}, {g:um|uma} {race} {class} chamad{g:o|a} {name}. Coisas pequenas, coisas verdadeiras, aquelas de que toda saga é feita.",
            },
            birth = {
                "Meu nome é {name}, {g:um|uma} {race} {class}. Nasci em {home}, em {land}, e tudo o que fiz desde então começou ali.",
                "Vim ao mundo em {home}, em {land}. Um lugar pequeno para uma história que cresceu a cada página.",
                "Todo povo tem um começo, e o meu foi {home}, em {land}. A estrada leva para longe dele, mas nunca esquece de todo o caminho de volta.",
                "{name}, {g:um|uma} {race} {class}, nascid{g:o|a} em {home}, em {land}. Pouco mais se sabia de mim, então, do que o nome daquele lugar.",
                "Fique dito onde tudo começou: {home}, em {land}, entre os meus, com um nome, uma bolsa e uma longa estrada por aprender.",
                "Dizem que uma saga deve começar onde nasceu o seu herói, e a minha começa em {home}, em {land}, onde {g:um|uma} {race} chamad{g:o|a} {name} olhou o céu pela primeira vez.",
                "Antes das estradas, antes das missões, havia {home}, em {land}: o lugar onde eu, {name}, {g:um|uma} {race} {class}, dei os primeiros passos.",
                "Nasci em {home}, em {land}. Seja o que a estrada fizer de mim, é de lá que venho.",
            },
            firstPage = {
                "A primeira página deste diário foi escrita em {date}, em {place}.",
                "Comecei a escrever em {date}, em {place}, e não parei mais.",
                "Este diário se abre em {date}, em {place}, com uma primeira página.",
                "A pena tocou o papel pela primeira vez em {date}, em {place}.",
                "Foi em {date}, em {place}, que decidi que a estrada merecia um livro.",
                "O registro destas páginas começa em {date}, em {place}.",
                "Em {date}, em {place}, foi escrita a primeira linha deste livro.",
                "Desde {date}, em {place}, a estrada é guardada no papel.",
            },
            earliest = {
                "O feito mais antigo de que o jogo se lembra, em meu nome, tem a data de {born}.",
                "Pela memória do próprio jogo, o meu primeiro feito remonta a {born}.",
                "A marca mais antiga que deixei no mundo é de {born}.",
                "O mundo me conhece desde {born}, pelo menos.",
                "Muito antes deste diário, em {born}, o jogo já guardava um feito meu.",
                "O meu feito registrado mais antigo é de {born}.",
                "O jogo guarda um feito meu de {born}, mais antigo que qualquer página daqui.",
                "{born}: a data do feito mais antigo de que o mundo se lembra de mim.",
            },
            road = {
                "Nível a nível a estrada me ensinou as suas lições. Estou no nível {level}, e foi em {place} que subi pela última vez.",
                "O nível {level} é onde esta página me encontra, e {place} é onde cresci pela última vez. Deixei para trás {#days:dia|dias} de estrada.",
                "Não apressei o passo e não parei. Nível {level}, com {place} para trás e {#days:dia|dias} de estrada.",
                "A estrada não mede quem viaja em anos, mas em passos, e os meus me trouxeram ao nível {level}. O último foi dado em {place}.",
                "Cada nível foi uma porta, e {place} foi a última que abri. O nível {level} espera do outro lado.",
                "Se perguntarem até onde cheguei: nível {level}, e o último trecho foi em {place}. Se perguntarem há quanto tempo: {#days:dia|dias}, por estas páginas.",
                "Meço a estrada em níveis, e hoje a medida marca {level}. Foi em {place} que ela subiu da última vez; a conta dos dias, atrás dela, é {days}.",
                "Pernas fortes, bagagem leve, nível {level}. {place} marca a última vez que me senti crescer, e a primeira página tem {#days:dia|dias}.",
            },
            stories = {
                "As missões foram as páginas dos meus dias: recados, juramentos, pequenas promessas cumpridas. Levei {#n:missão|missões} até o fim.",
                "Cada missão é uma promessa, e tentei cumprir todas: até aqui, {#n:promessa cumprida|promessas cumpridas}.",
                "Algumas tarefas foram pequenas, outras viraram histórias dignas de serem ouvidas. Juntas são {#n:missão|missões}, e não trocaria nenhuma.",
                "Nunca recusei um desconhecido que precisava de uma mão, e o diário prova: {#n:missão|missões} vistas até o fim, do primeiro recado ao mais recente.",
                "Uma estrada é feita de recados. Os meus, terminados e assinados, são {#n:missão|missões}, e cada um deixou marca no jeito como caminho.",
                "Pergunte às aldeias o que fiz por elas e falarão de recados. Eu lhe digo o número: {n}.",
                "O diário de missões é um livro à parte, e nele estão {#n:entrada fechada|entradas fechadas}. Carrego todas, com leveza.",
                "O que é um herói senão alguém que responde quando chamado? Respondi {#n:vez|vezes}, e o chamado não parou.",
            },
            war = {
                "Alguns inimigos não caem só pela espada. Caem pela paciência, pelos amigos, pela terceira tentativa. Derrubei {#n:grande|grandes}.",
                "Estive em salões onde as paredes guardam a memória de cada golpe, e deixei {#n:chefe caído|chefes caídos} atrás de mim.",
                "Um chefe é uma pergunta que a masmorra faz, e a cada vez respondi com aço e companhia. Respondi {#n:vez|vezes}.",
                "Guardaram os seus tronos com tudo o que tinham, e não bastou. Vi {#n:trono esvaziado|tronos esvaziados}.",
                "As trompas de guerra dos lugares fundos agora soam para mim. Chefes derrotados: {n}.",
                "Desci às profundezas para ser {g:posto|posta} à prova, e fui. Entre os meus inimigos, {#n:campeão jaz quieto|campeões jazem quietos} por minha causa.",
                "Sangue, ruído e depois o silêncio que vem após a queda do grande. Conheci esse silêncio {#n:vez|vezes}.",
                "Nenhuma canção minha existe sem o choque das armas. {#n:grande adversário terminou|grandes adversários terminaram} nela.",
            },
            warHard = {
                "{boss} não cedeu com facilidade. Caí diante dele, e me levantei, e a vitória me custou {#tries:queda|quedas}.",
                "De todos os grandes, {boss} foi o que mais me custou: {#tries:queda|quedas} antes que ele enfim jazesse quieto.",
                "{boss} me ensinou primeiro a humildade e depois a vitória, ao preço de {#tries:queda|quedas}.",
                "Lembro de {boss} melhor que dos outros, porque perdi antes de vencer: {#tries:tentativa perdida|tentativas perdidas}.",
                "A vitória sobre {boss} foi mais doce pelo caminho que custou, um caminho de {#tries:queda|quedas}.",
                "Algumas vitórias são limpas. A de {boss} não foi, e não a quereria de outro modo. Antes dela, {#tries:queda|quedas}.",
                "Contarão de {boss} como aquele que quase me venceu. Antes da vitória, {#tries:queda|quedas}.",
                "{boss} se pôs entre mim e o capítulo seguinte, e cobrou um pedágio de {#tries:queda|quedas}. Paguei, e passei.",
            },
            falls = {
                "Caí, e não vou fingir o contrário: {#n:queda|quedas} ao todo.",
                "Um herói se mede tanto pelo levantar quanto pela glória. Levantei-me depois de {#n:queda|quedas}.",
                "A morte não foi estranha a ninguém nesta estrada. Encontrei-a {#n:vez|vezes}.",
                "O curandeiro de espíritos conhece o meu rosto: {#n:visita|visitas}.",
                "Nem toda página é triunfo. Algumas são o silêncio depois de uma queda: {#n:página|páginas} delas.",
                "Levantei-me todas as vezes, depois de {#n:queda|quedas} ao todo.",
                "Cada queda deixou uma lição: {#n:lição aprendida|lições aprendidas} do jeito difícil.",
                "Deitei no chão mais vezes do que gosto de admitir: {#n:queda|quedas}, e cada uma bem ganha.",
            },
            fallsPlace = {
                "Foi em {place} que mais caí.",
                "{place} foi a mestra mais dura.",
                "Em {place}, a morte chamou mais alto.",
                "A terra que mais me exigiu foi {place}.",
                "Conheço o chão de {place} melhor que a maioria, de tanto deitar nele.",
                "{place} me tomou mais do que qualquer outra terra.",
                "Se eu cair de novo, preferiria que não fosse em {place}.",
                "Pergunte onde mais doeu e direi {place}.",
            },
            company = {
                "Não caminhei {g:sozinho|sozinha}. Escolhi lembrar {#n:rosto|rostos} ao longo da estrada.",
                "Uma estrada fica mais leve com companhia. Carrego na memória {#n:companheiro|companheiros}.",
                "Nomes valem mais que ouro, e o meu diário guarda {#n:nome|nomes} de quem caminhou ao meu lado.",
                "Alguns desconhecidos ficam na memória porque estiveram ao meu lado quando importava: {#n:desconhecido|desconhecidos} ao todo.",
                "Masmorras e longas estradas fazem amigos de desconhecidos. O meu livro de companheiros guarda {#n:nome|nomes}.",
                "Nenhuma saga é narrada por uma voz só. Comigo caminhou gente: {#n:pessoa lembrada|pessoas lembradas} aqui.",
                "Guardo-os como se guarda uma lamparina: {#n:companheiro|companheiros} da estrada, cada um uma pequena luz.",
                "A companhia foi o melhor tesouro da estrada, e lembro de {#n:companheiro|companheiros}.",
            },
            companyNames = {
                "Entre eles, lembro melhor de: {names}.",
                "Penso mais vezes em {names}.",
                "Se a estrada um dia me levar de volta a {names}, a cerveja é por minha conta.",
                "Os nomes que ficam mais claros: {names}.",
                "Fique escrito que caminhei com {names}.",
                "A {names}: {g:obrigado|obrigada} pela companhia.",
                "De todos eles, aqueles com quem caminharia de novo: {names}.",
                "Levanto um copo, em memória, a {names}.",
            },
            marks = {
                "A estrada também pediu feitos dignos de um selo. Cumpri {#n:meta|metas}, que valem {#points:ponto|pontos}, e o título que me renderam é {title}.",
                "Juntei {#points:ponto|pontos} de renome em metas cumpridas, {n} ao todo, e com eles o título de {title}.",
                "Um selo aqui, outro ali: {#n:meta cumprida|metas cumpridas}, {#points:ponto ganho|pontos ganhos}, e o título que trazem é {title}.",
                "Renome é um livro-caixa e eu mantenho o meu. Metas cumpridas: {n}. Pontos: {points}. Chamam-me {title}.",
                "Nem tudo o que importa se mede, mas parte se mede. Metas cumpridas: {n}; pontos: {points}; o meu título, {title}.",
                "{title}: é o que {#points:ponto|pontos} de renome, ganhos em {#n:meta|metas}, fizeram de mim.",
                "Os selos do livro guardam as minhas metas: cumpridas, {n}; valor, {#points:ponto|pontos}; e o título, {title}.",
                "Metas pequenas, outras maiores, algumas que pediram paciência: {#n:meta cumprida|metas cumpridas}, {#points:ponto ganho|pontos ganhos}, e o nome {title} para vestir.",
            },
            epilogue = {
                "A história não terminou, só fez uma pausa onde esta página acaba. Estou no nível {level}, com {#pages:página escrita|páginas escritas}, e a estrada ainda se abre diante de {name}.",
                "Aqui fecho o livro, por ora. Nível {level}, e a conta do diário está em {pages}. O resto é estrada, e a estrada é longa.",
                "Se esta fosse a última página, eu ficaria contente: {#pages:página guardada|páginas guardadas}, nível {level} alcançado e um nome que coube a mim escrever. Mas há mais estrada.",
                "Saga, dizem. Eu digo a estrada até aqui: nível {level}, {#pages:página guardada|páginas guardadas}. O próximo capítulo espera {name} do lado de fora da porta.",
                "Saiba quem ler isto que {name} esteve aqui, chegou ao nível {level} e guardou {#pages:página|páginas} para provar. A história continua.",
                "A tinta secou em {#pages:página|páginas}, e a estrada não secou. O nível {level} é só onde estou hoje.",
                "O que é uma saga senão uma estrada lembrada? A minha, até aqui: nível {level}, {#pages:página guardada|páginas guardadas}, e o resto ainda por escrever.",
                "Feche o livro com delicadeza e deixe a pena por perto. {name}, nível {level}, ainda tem o que contar. A conta de páginas até aqui: {pages}.",
            },
            epilogueTop = {
                "Nível sessenta. O topo do mundo, e a página em que uma saga poderia terminar com razão. Não termina: {name} tem {#pages:página guardada|páginas guardadas}, e a estrada ainda tem curvas.",
                "Cheguei ao cume, e a vista valeu cada uma das {#pages:página escrita|páginas escritas} pelo caminho. Agora olho o horizonte, porque há sempre mais um.",
                "Do topo do mundo, {name} olha para trás ao longo da estrada: {#pages:página guardada|páginas guardadas}, e cada uma um passo.",
                "Este é o fim da subida e o começo da lenda. {#pages:página escrita|páginas escritas}. O título: {title}.",
                "Diziam que a estrada tinha um topo. Tinham razão, e estive nele. A conta de páginas no caminho: {pages}.",
                "No topo, uma coisa fica clara: a história nunca foi o nível, foi a estrada. Neste livro ela tem {#pages:página|páginas} de comprimento, e continua aberta.",
                "Sessenta níveis, e o diário me manteve {g:honesto|honesta} ao longo de {#pages:página|páginas}. {name}, {title}, fecha o livro só para abrir outro.",
                "O último capítulo de uma saga é a promessa do próximo. Guardei {#pages:página|páginas}, e guardei também a promessa.",
            },
        },
    },
    frFR = {
        TAB = "Saga", EMPTY = "La saga commence avec la première page.", AND = " et ", DATE = "%d/%m/%Y",
        TITLES = {
            prologue = "Prologue", road = "La route", stories = "Courses et serments", war = "Trônes renversés",
            falls = "Les chutes", company = "Compagnie", marks = "Sceaux et renom", epilogue = "Épilogue",
        },
        POOLS = {
            prologue = {
                "Je m'appelle {name}. Je suis {g:un|une} {race} {class}, et la première page de ce journal a été écrite le {date}, à {place}, sans nulle idée de là où la route me mènerait.",
                "Le {date}, à {place}, j'ai posé la plume sur le papier pour la première fois. {name}, {g:un|une} {race} {class}\194\160: un nom qui disait peu alors, et qui en dit plus à chaque page.",
                "Toute saga commence petite. La mienne commence par une page écrite à {place}, le {date}, par {g:un|une} {race} {class} nommé{g:|e} {name}, qui a décidé que la route méritait d'être retenue.",
                "Je ne suis pas parti{g:|e} pour devenir une histoire. J'ai seulement commencé à écrire, le {date}, à {place}, {g:un|une} {race} {class}, et l'histoire a suivi la plume.",
                "On dira que l'histoire commence là où commence le journal. C'est vrai\194\160: {place}, le {date}, avec {g:un|une} {class} qui ignorait encore ce que la route allait lui demander.",
                "Qu'il soit écrit\194\160: le {date}, à {place}, {name} a ouvert ce livre. {g:Un|Une} {race} {class}, avec une besace, un nom et une longue route devant soi.",
                "La première page porte la date du {date} et fut écrite à {place}. Je n'étais alors qu'{g:un|une} {race} {class}, et je le suis encore, mais j'ai désormais une histoire pour le prouver.",
                "Avant la légende, la première page\194\160: {place}, le {date}, {g:un|une} {race} {class} nommé{g:|e} {name}. Des choses petites, des choses vraies, celles dont toute saga est faite.",
            },
            birth = {
                "Je m'appelle {name}, {g:un|une} {race} {class}. Je suis né{g:|e} à {home}, à {land}, et tout ce que j'ai fait depuis a commencé là.",
                "Je suis venu{g:|e} au monde à {home}, à {land}. Un petit lieu pour une histoire qui a grandi à chaque page.",
                "Chaque peuple a un commencement, et le mien fut {home}, à {land}. La route s'en éloigne, mais n'oublie jamais tout à fait le chemin du retour.",
                "{name}, {g:un|une} {race} {class}, né{g:|e} à {home}, à {land}. On ne savait alors de moi guère plus que le nom de ce lieu.",
                "Qu'on dise où tout a commencé\194\160: {home}, à {land}, parmi les miens, avec un nom, une besace et une longue route à apprendre.",
                "On dit qu'une saga doit commencer là où est né son héros, et la mienne commence à {home}, à {land}, où {g:un|une} {race} nommé{g:|e} {name} a levé les yeux vers le ciel pour la première fois.",
                "Avant les routes, avant les quêtes, il y avait {home}, à {land}\194\160: le lieu où moi, {name}, {g:un|une} {race} {class}, j'ai fait mes premiers pas.",
                "Je suis né{g:|e} à {home}, à {land}. Quoi que la route fasse de moi, c'est de là que je viens.",
            },
            firstPage = {
                "La première page de ce journal a été écrite le {date}, à {place}.",
                "J'ai commencé à écrire le {date}, à {place}, et je n'ai plus cessé.",
                "Ce journal s'ouvre le {date}, à {place}, par une première page.",
                "La plume a touché le papier pour la première fois le {date}, à {place}.",
                "C'est le {date}, à {place}, que j'ai décidé que la route méritait un livre.",
                "Le registre de ces pages commence le {date}, à {place}.",
                "Le {date}, à {place}, la première ligne de ce livre a été écrite.",
                "Depuis le {date}, à {place}, la route est gardée sur le papier.",
            },
            earliest = {
                "L'exploit le plus ancien dont le jeu se souvienne, à mon nom, est daté du {born}.",
                "D'après la mémoire du jeu lui-même, mon premier exploit remonte au {born}.",
                "La plus ancienne marque que j'aie laissée dans le monde date du {born}.",
                "Le monde me connaît depuis le {born}, au moins.",
                "Bien avant ce journal, le {born}, le jeu gardait déjà un exploit de moi.",
                "Mon plus ancien exploit enregistré date du {born}.",
                "Le jeu garde de moi un exploit du {born}, plus ancien que toute page d'ici.",
                "{born}\194\160: la date du plus ancien exploit dont le monde se souvienne de moi.",
            },
            road = {
                "Niveau après niveau, la route m'a enseigné ses leçons. Je suis au niveau {level}, et c'est à {place} que j'ai grandi pour la dernière fois.",
                "Le niveau {level} est l'endroit où cette page me trouve, et {place} celui où j'ai grandi pour la dernière fois. J'ai laissé derrière moi {#days:jour|jours} de route.",
                "Je n'ai pas pressé le pas et je ne me suis pas arrêté{g:|e}. Niveau {level}, {place} derrière moi et {#days:jour|jours} de route.",
                "La route ne mesure pas un voyageur en années mais en pas, et les miens m'ont mené{g:|e} au niveau {level}. Le dernier fut fait à {place}.",
                "Chaque niveau fut une porte, et {place} fut la dernière que j'ai ouverte. Le niveau {level} attend de l'autre côté.",
                "Si l'on demande jusqu'où je suis venu{g:|e}\194\160: niveau {level}, et le dernier tronçon fut à {place}. Si l'on demande depuis quand\194\160: {#days:jour|jours}, d'après ces pages.",
                "Je mesure la route en niveaux, et aujourd'hui la mesure indique {level}. C'est à {place} qu'elle a monté la dernière fois\194\160; le compte des jours derrière elle est de {days}.",
                "Jambes solides, bagage léger, niveau {level}. {place} marque la dernière fois où je me suis senti{g:|e} grandir, et la première page date de {#days:jour|jours}.",
            },
            stories = {
                "Les quêtes furent les pages de mes jours\194\160: courses, serments, petites promesses tenues. J'ai mené jusqu'au bout {#n:quête|quêtes}.",
                "Chaque quête est une promesse, et j'ai tenté de les tenir toutes\194\160: {#n:promesse tenue|promesses tenues} jusqu'ici.",
                "Certaines tâches furent petites, d'autres devinrent des récits dignes d'être narrés. Ensemble, {#n:quête|quêtes}, et je n'en échangerais aucune.",
                "Je n'ai jamais refusé un inconnu qui avait besoin d'un coup de main, et le journal le prouve\194\160: {#n:quête menée|quêtes menées} jusqu'au bout, de la première course à la plus récente.",
                "Une route est faite de courses. J'ai terminé et signé {#n:quête|quêtes}, et chacune a laissé sa marque sur mon pas.",
                "Demandez aux villages ce que j'ai fait pour eux, ils vous parleront de courses. Moi, je vous donne le chiffre\194\160: {n}.",
                "Le journal de quêtes est un livre à part, et il garde {#n:entrée close|entrées closes}. Je les porte toutes, légèrement.",
                "Qu'est-ce qu'un héros, sinon quelqu'un qui répond quand on l'appelle\194\160? J'ai répondu {#n:fois|fois}, et les appels n'ont pas cessé.",
            },
            war = {
                "Certains ennemis ne tombent pas par la seule épée. Ils tombent par la patience, par les amis, au troisième essai. J'ai abattu {#n:grand|grands}.",
                "J'ai tenu dans des salles dont les murs se souviennent de chaque coup, et laissé {#n:boss tombé|boss tombés} derrière moi.",
                "Un boss est une question que le donjon pose, et chaque fois j'ai répondu par l'acier et la compagnie. J'ai répondu {#n:fois|fois}.",
                "Ils gardaient leurs trônes de toutes leurs forces, et ce ne fut pas assez. J'ai vu {#n:trône vidé|trônes vidés}.",
                "Les cors de guerre des lieux profonds sonnent désormais pour moi. Boss vaincus\194\160: {n}.",
                "Je suis descendu{g:|e} aux profondeurs pour être mis{g:|e} à l'épreuve, et je l'ai été. Parmi mes ennemis, {#n:champion gît désormais immobile|champions gisent désormais immobiles}.",
                "Du sang, du bruit, puis le silence après la chute du grand. J'ai connu ce silence {#n:fois|fois}.",
                "Aucune de mes chansons ne vit sans le choc des armes. {#n:grand adversaire s'y est achevé|grands adversaires s'y sont achevés}.",
            },
            warHard = {
                "{boss} n'a pas cédé aisément. Je suis tombé{g:|e} devant lui, et je me suis relevé{g:|e}\194\160; la victoire m'a coûté {#tries:chute|chutes}.",
                "De tous les grands, {boss} fut celui qui m'a coûté le plus\194\160: {#tries:chute|chutes} avant qu'il ne repose enfin.",
                "{boss} m'a appris d'abord l'humilité, puis la victoire, au prix de {#tries:chute|chutes}.",
                "Je me souviens de {boss} mieux que des autres, car j'ai perdu avant de vaincre\194\160: {#tries:tentative perdue|tentatives perdues}.",
                "La victoire sur {boss} fut plus douce à cause du chemin parcouru, un chemin de {#tries:chute|chutes}.",
                "Certaines victoires sont nettes. Celle de {boss} ne le fut pas, et je ne la voudrais pas autrement. Avant elle, {#tries:chute|chutes}.",
                "On parlera de {boss} comme de celui qui a failli me vaincre. Avant la victoire, {#tries:chute|chutes}.",
                "{boss} s'est dressé entre moi et le chapitre suivant, et a exigé un péage de {#tries:chute|chutes}. J'ai payé, et je suis passé{g:|e}.",
            },
            falls = {
                "Je suis tombé{g:|e}, et je ne ferai pas semblant du contraire\194\160: {#n:chute|chutes} au total.",
                "On mesure un héros autant à son relèvement qu'à sa gloire. Je me suis relevé{g:|e} après {#n:chute|chutes}.",
                "La mort n'a été étrangère à personne sur cette route. Je l'ai croisée {#n:fois|fois}.",
                "Le guérisseur des esprits connaît mon visage\194\160: {#n:visite|visites}.",
                "Toutes les pages ne sont pas des triomphes. Certaines sont le silence après une chute\194\160: {#n:page|pages} de cette sorte.",
                "Je me suis relevé{g:|e} chaque fois, après {#n:chute|chutes} au total.",
                "Chaque chute a laissé une leçon\194\160: {#n:leçon apprise|leçons apprises} à la dure.",
                "J'ai goûté le sol plus souvent que je ne l'avoue\194\160: {#n:chute|chutes}, et chacune bien méritée.",
            },
            fallsPlace = {
                "C'est à {place} que je suis le plus tombé{g:|e}.",
                "{place} fut la maîtresse la plus dure.",
                "À {place}, la mort a appelé le plus fort.",
                "La contrée qui m'a le plus demandé fut {place}.",
                "Je connais le sol de {place} mieux que la plupart, à force d'y être couché{g:|e}.",
                "{place} m'a pris plus que toute autre contrée.",
                "Si je tombe encore, je préférerais que ce ne soit pas à {place}.",
                "Demandez-moi où cela a fait le plus mal et je dirai {place}.",
            },
            company = {
                "Je n'ai pas marché seul{g:|e}. J'ai choisi de retenir {#n:visage|visages} le long de la route.",
                "Une route est plus légère en compagnie. Je porte en mémoire {#n:compagnon|compagnons}.",
                "Les noms valent plus que l'or, et mon journal garde {#n:nom|noms} de ceux qui ont marché à mes côtés.",
                "Certains inconnus restent en mémoire parce qu'ils étaient là quand cela importait\194\160: {#n:inconnu|inconnus} en tout.",
                "Les donjons et les longues routes font des amis d'inconnus. Mon livre de compagnons garde {#n:nom|noms}.",
                "Aucune saga n'est contée par une seule voix. Du monde a marché avec moi\194\160: {#n:personne retenue|personnes retenues} ici.",
                "Je les garde comme on garde une lampe\194\160: {#n:compagnon|compagnons} de route, chacun une petite lumière.",
                "La compagnie fut le meilleur trésor de la route, et je me souviens de {#n:compagnon|compagnons}.",
            },
            companyNames = {
                "Parmi eux, je me souviens surtout de\194\160: {names}.",
                "Je pense le plus souvent à {names}.",
                "Si la route me ramène un jour auprès de {names}, la bière est pour moi.",
                "Les noms qui restent les plus clairs\194\160: {names}.",
                "Qu'il soit écrit que j'ai marché avec {names}.",
                "À {names}\194\160: merci pour la compagnie.",
                "De tous, ceux avec qui je marcherais de nouveau\194\160: {names}.",
                "Je lève une coupe, en mémoire, à {names}.",
            },
            marks = {
                "La route a aussi demandé des exploits dignes d'un sceau. J'ai atteint {#n:objectif|objectifs}, qui valent {#points:point|points}, et le titre qu'ils m'ont valu est {title}.",
                "J'ai réuni {#points:point|points} de renom en objectifs atteints, {n} au total, et avec eux le titre de {title}.",
                "Un sceau ici, un autre là\194\160: {#n:objectif atteint|objectifs atteints}, {#points:point gagné|points gagnés}, et le titre qu'ils apportent est {title}.",
                "Le renom est un registre et je tiens le mien. Objectifs atteints\194\160: {n}. Points\194\160: {points}. On m'appelle {title}.",
                "Tout ce qui importe ne se mesure pas, mais une partie, si. Objectifs atteints\194\160: {n}\194\160; points\194\160: {points}\194\160; mon titre, {title}.",
                "{title}\194\160: voilà ce que {#points:point|points} de renom, gagnés en {#n:objectif|objectifs}, ont fait de moi.",
                "Les sceaux du livre gardent mes objectifs\194\160: atteints, {n}\194\160; valeur, {#points:point|points}\194\160; et le titre, {title}.",
                "Des objectifs petits, d'autres plus grands, quelques-uns qui ont demandé de la patience\194\160: {#n:objectif atteint|objectifs atteints}, {#points:point gagné|points gagnés}, et le nom {title} à porter.",
            },
            epilogue = {
                "L'histoire n'est pas finie, seulement en pause là où cette page s'achève. Je suis au niveau {level}, avec {#pages:page écrite|pages écrites}, et la route s'ouvre encore devant {name}.",
                "Ici je ferme le livre, pour l'heure. Niveau {level}, et le compte du journal s'élève à {pages}. Le reste est route, et la route est longue.",
                "Si c'était la dernière page, je serais content{g:|e}\194\160: {#pages:page gardée|pages gardées}, niveau {level} atteint et un nom qu'il m'a appartenu d'écrire. Mais il y a encore de la route.",
                "Saga, dit-on. Moi, je dis la route jusqu'ici\194\160: niveau {level}, {#pages:page gardée|pages gardées}. Le prochain chapitre attend {name} derrière la porte.",
                "Que celui qui lit ceci sache que {name} est passé{g:|e} par ici, a atteint le niveau {level} et gardé {#pages:page|pages} pour le prouver. L'histoire continue.",
                "L'encre a séché sur {#pages:page|pages}, et la route n'a pas séché. Le niveau {level} n'est que là où je me tiens aujourd'hui.",
                "Qu'est-ce qu'une saga, sinon une route retenue\194\160? La mienne, jusqu'ici\194\160: niveau {level}, {#pages:page gardée|pages gardées}, et le reste encore à écrire.",
                "Fermez le livre doucement et laissez la plume à portée. {name}, niveau {level}, a encore à conter. Le compte des pages jusqu'ici\194\160: {pages}.",
            },
            epilogueTop = {
                "Niveau soixante. Le sommet du monde, et la page où une saga pourrait finir à bon droit. Elle ne finira pas\194\160: {name} a {#pages:page gardée|pages gardées}, et la route a encore des détours.",
                "J'ai atteint le sommet, et la vue valait chacune des {#pages:page écrite|pages écrites} en chemin. Je regarde maintenant l'horizon, car il y en a toujours un autre.",
                "Du sommet du monde, {name} regarde en arrière le long de la route\194\160: {#pages:page gardée|pages gardées}, et chacune un pas.",
                "Voici la fin de la montée et le début de la légende. {#pages:page écrite|pages écrites}. Le titre\194\160: {title}.",
                "On disait que la route avait un sommet. On avait raison, et j'y suis monté{g:|e}. Le compte des pages en chemin\194\160: {pages}.",
                "Au sommet, une chose est claire\194\160: l'histoire n'a jamais été le niveau, c'était la route. Dans ce livre elle s'étend sur {#pages:page|pages}, et reste ouverte.",
                "Soixante niveaux, et le journal m'a gardé{g:|e} honnête sur {#pages:page|pages}. {name}, {title}, ne ferme le livre que pour en ouvrir un autre.",
                "Le dernier chapitre d'une saga est la promesse du suivant. J'ai gardé {#pages:page|pages}, et j'ai gardé aussi la promesse.",
            },
        },
    },
}
ns.SagaTexts = TEXT
local UI = TEXT[GetLocale()] or TEXT.enUS

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- A number from the text of a name, steady between runs and between machines (Lua 5.1 arithmetic only).
local function Hash(s)
    local h = 7
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483629 end
    return h
end

-- The phrase of a pool for this diary: always the same one for the same diary and the same pool.
local function Pick(pool, name, seed)
    if not pool or #pool == 0 then return nil end
    return pool[Hash(name .. ":" .. tostring(seed)) % #pool + 1]
end

local function Fill(phrase, vars)
    -- {#n:one|many}: the number and its noun, in the singular for one ("1 quest") and the plural otherwise
    local counted = phrase:gsub("{#(%a+):([^|}]*)|([^}]*)}", function(key, one, many)
        local n = tonumber(vars[key])
        if not n then return "" end
        return tostring(n) .. " " .. (n == 1 and one or many)
    end)
    local text = counted:gsub("{(%a+)}", function(key)
        local v = vars[key]
        if v == nil then return "" end
        return tostring(v)
    end)
    return ns.Gendered(text)
end

-- Where each race is born: the area of its starting valley and the one of its land (the game names them in the
-- language of the client). Races not listed are told without a birthplace.
local RACE_HOME = {
    Human = { 9, 12 }, Dwarf = { 132, 1 }, Gnome = { 132, 1 }, NightElf = { 188, 141 },
    Orc = { 363, 14 }, Troll = { 363, 14 }, Scourge = { 154, 85 }, Tauren = { 220, 215 },
}
local function AreaName(id)
    local ok, name = pcall(function() return C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id) end)
    return (ok and type(name) == "string" and name ~= "") and name or nil
end

-- The oldest achievement of the character (the game dates it): about when the character began. Asked once for a
-- while: it goes through every category of the achievements.
local oldestCache
local function OldestDeed()
    if oldestCache and (oldestCache.t or oldestCache.tries >= 3) then return oldestCache.t end
    oldestCache = oldestCache or { tries = 0 }
    oldestCache.tries = oldestCache.tries + 1
    pcall(function()
        if not (GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo) then return end
        local best
        for _, cat in ipairs(GetCategoryList() or {}) do
            for i = 1, GetCategoryNumAchievements(cat) or 0 do
                local id, _, _, completed, month, day, year = GetAchievementInfo(cat, i)
                if id and completed and type(year) == "number" and type(month) == "number" and type(day) == "number" then
                    local full = year < 100 and year + 2000 or year
                    local key = full * 10000 + month * 100 + day
                    if not best or key < best then best = key end
                end
            end
        end
        if best then
            oldestCache.t = time({ year = math.floor(best / 10000), month = math.floor(best / 100) % 100, day = best % 100, hour = 12 })
        end
    end)
    return oldestCache.t
end

-- What the diary knows, as plain values.
local function Gather(db)
    local v = { entries = db.entries or {} }
    local stats = db.stats or {}
    local counts = stats.counts or {}
    local exact = SkaldAPI.GameFacts and SkaldAPI.GameFacts() or {}
    local first = v.entries[1]
    v.seed = stats.first or (first and first.t) or 0
    v.first = first
    v.name = UnitName and UnitName("player") or "?"
    v.race = (UnitRace and UnitRace("player")) or ""
    v.class = (UnitClass and UnitClass("player")) or ""
    v.level = (UnitLevel and UnitLevel("player")) or 1
    local last = v.entries[#v.entries]
    v.days = (first and last) and (math.floor(((last.t or 0) - (first.t or 0)) / 86400) + 1) or 1
    v.place = first and first.zone or ""
    v.levelPlace = v.place
    for i = #v.entries, 1, -1 do
        local e = v.entries[i]
        if e.kind == "level" and e.zone and e.zone ~= "" then v.levelPlace = e.zone; break end
    end
    v.quests = math.max(counts.quest or 0, type(exact.quests) == "number" and exact.quests or 0)
    v.bosses = math.max(counts.boss or 0, type(exact.bosses) == "number" and exact.bosses or 0)
    v.deaths = math.max(counts.death or 0, type(exact.deaths) == "number" and exact.deaths or 0)
    -- the boss that cost the most falls
    local hardTries = 0
    for _, e in ipairs(v.entries) do
        if e.kind == "boss" and (e.tries or 0) > hardTries and type(e.arg) == "string" then
            hardTries, v.hardBoss = e.tries, e.arg
        end
    end
    v.hardTries = hardTries
    -- the land where I fell most
    local worst, worstN = nil, 0
    for zone, n in pairs(stats.deathZones or {}) do
        if type(n) == "number" and (n > worstN or (n == worstN and tostring(zone) < tostring(worst))) then worst, worstN = zone, n end
    end
    v.deathPlace = worst
    -- companions: the ones seen most recently first (a tie is broken by the name, so the order is steady)
    local people = {}
    for key, c in pairs(db.companions or {}) do
        people[#people + 1] = { key = key, last = type(c) == "table" and (c.last or c.seen) or 0 }
    end
    table.sort(people, function(a, b)
        if a.last ~= b.last then return a.last > b.last end
        return tostring(a.key) < tostring(b.key)
    end)
    v.companions = #people
    v.people = people
    v.goals = Count(db.goals)
    if ns.GoalScore then v.points = ns.GoalScore() end
    v.title = ns.GoalTitle and ns.GoalTitle(v.points or 0) or ""
    v.pages = #v.entries
    local okR, _, raceFile = pcall(UnitRace, "player")
    local areas = okR and RACE_HOME[raceFile]
    if areas then
        v.home, v.land = AreaName(areas[1]), AreaName(areas[2])
        if not (v.home and v.land) then v.home, v.land = nil, nil end
    end
    v.born = OldestDeed()
    return v
end

local function NameList(v, hide)
    local names = {}
    for i = 1, math.min(3, #v.people) do names[#names + 1] = ns.WhoShort(v.people[i].key) end
    if #names == 0 then return nil end
    if #names == 1 then return names[1] end
    return table.concat(names, ", ", 1, #names - 1) .. UI.AND .. names[#names]
end

-- The chapters of this diary: { key, title, text }, in order. A chapter with nothing to say is left out.
ns.BuildSaga = function()
    local db = SkaldCharDB
    if not db or not db.entries or #db.entries == 0 then return {} end
    local v = Gather(db)
    local pools = UI.POOLS
    local chapters = {}
    local function Add(key, parts)
        local texts = {}
        for _, p in ipairs(parts) do
            local phrase = Pick(pools[p[1]], p[1], v.seed)
            if phrase then texts[#texts + 1] = Fill(phrase, p[2]) end
        end
        if #texts > 0 then chapters[#chapters + 1] = { key = key, title = UI.TITLES[key], text = table.concat(texts, "\n\n") } end
    end
    local when = date(UI.DATE, v.seed > 0 and v.seed or time())
    -- "a Human" but "an Orc" (only English tells the article by the sound of the next word)
    local article = v.race:sub(1, 1):lower():match("[aeiou]") and "an" or "a"
    local base = { name = v.name, race = v.race, class = v.class, date = when, place = v.place, level = v.level,
        days = v.days, pages = v.pages, title = v.title, a = article, A = article:sub(1, 1):upper() .. article:sub(2) }
    local function Day(t) return date("%Y%m%d", t) end
    local parts = {}
    if v.home then
        parts[1] = { "birth", { name = v.name, race = v.race, class = v.class, home = v.home, land = v.land, a = base.a, A = base.A } }
    else
        parts[1] = { "prologue", base }
    end
    -- the oldest deed the game dated, when it is older than the first page of the diary
    if v.born and v.seed > 0 and Day(v.born) < Day(v.seed) then
        parts[#parts + 1] = { "earliest", { born = date(UI.DATE, v.born) } }
    end
    -- the first page of the diary, when it was not written where the character was born (the other opening already says it)
    local here = tostring(v.place):lower()
    if v.home and v.place ~= "" and here ~= v.home:lower() and here ~= v.land:lower() then
        parts[#parts + 1] = { "firstPage", { date = when, place = v.place } }
    end
    Add("prologue", parts)
    Add("road", { { "road", { level = v.level, place = v.levelPlace, days = v.days } } })
    if v.quests > 0 then Add("stories", { { "stories", { n = v.quests } } }) end
    if v.bosses > 0 then
        local parts = { { "war", { n = v.bosses } } }
        if v.hardBoss then parts[#parts + 1] = { "warHard", { boss = v.hardBoss, tries = v.hardTries } } end
        Add("war", parts)
    end
    if v.deaths > 0 then
        local parts = { { "falls", { n = v.deaths } } }
        if v.deathPlace then parts[#parts + 1] = { "fallsPlace", { place = v.deathPlace } } end
        Add("falls", parts)
    end
    if v.companions > 0 then
        local parts = { { "company", { n = v.companions } } }
        local list = NameList(v)
        if list then parts[#parts + 1] = { "companyNames", { names = list } } end
        Add("company", parts)
    end
    if v.goals > 0 then Add("marks", { { "marks", { n = v.goals, points = v.points or 0, title = v.title } } }) end
    Add("epilogue", { { v.level >= 60 and "epilogueTop" or "epilogue", base } })
    return chapters
end

-- The chapters go onto pages by an estimate of their height (the width of the page, the size of the letter), as many
-- to a page as fit, never a chapter split. The estimate is cautious (it counts the bytes of a line, so accents make
-- it longer) and was checked against the real fonts.
local PAGE_HEIGHT = 415          -- the room of a page (440) less a margin
local TITLE_HEIGHT, SLOT_GAP = 51, 26
local function ChapterHeight(c, size, width)
    local perLine = math.max(10, math.floor(width / (size * 0.42)))
    local lineHeight = size * 1.4 + 4
    local lines = 0
    for paragraph in (c.text .. "\n\n"):gmatch("(.-)\n\n") do
        lines = lines + math.max(1, math.ceil(#paragraph / perLine)) + 1
    end
    return TITLE_HEIGHT + (lines - 1) * lineHeight
end
ns.SagaPages = function(chapters, size, width)
    size = (type(size) == "number" and size > 0) and size or 13
    width = width or (SkaldAPI.CW or 342)
    local pages, page, used = {}, {}, 0
    for _, c in ipairs(chapters) do
        local h = ChapterHeight(c, size, width)
        local needed = used + (#page > 0 and SLOT_GAP or 0) + h
        if #page > 0 and (needed > PAGE_HEIGHT or #page >= 3) then
            pages[#pages + 1] = page
            page, used, needed = {}, 0, h
        end
        page[#page + 1] = c
        used = needed
    end
    if #page > 0 then pages[#pages + 1] = page end
    return pages
end

-- The tab: two pages at a time (several short chapters to a page); the corners turn the pages.
local function BuildSagaTab(panel)
    local CW, RX = SkaldAPI.CW, SkaldAPI.RIGHT_X
    local sides = {}
    for i, x in ipairs({ 0, RX }) do
        local side = { slots = {} }
        for n = 1, 3 do
            local slot = {}
            slot.title = panel:CreateFontString(nil, "OVERLAY", "SkaldHead2")
            slot.title:SetWidth(CW)
            slot.title:SetJustifyH("CENTER")
            slot.title:SetTextColor(SkaldAPI.C_HEAD[1], SkaldAPI.C_HEAD[2], SkaldAPI.C_HEAD[3])
            slot.rule = panel:CreateTexture(nil, "ARTWORK")
            slot.rule:SetSize(130, 11)
            slot.rule:SetPoint("TOP", slot.title, "BOTTOM", 0, -3)
            slot.rule:SetTexture("Interface\\AddOns\\Skald\\Textures\\rule")
            slot.rule:SetTexCoord(0, 160 / 256, 0, 14 / 16)
            slot.body = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
            slot.body:SetWidth(CW)
            slot.body:SetJustifyH("LEFT")
            slot.body:SetJustifyV("TOP")
            slot.body:SetSpacing(4)
            slot.body:SetWordWrap(true)
            slot.body:SetTextColor(SkaldAPI.C_BODY[1], SkaldAPI.C_BODY[2], SkaldAPI.C_BODY[3])
            slot.body:SetPoint("TOPLEFT", slot.title, "BOTTOMLEFT", 0, -20)
            if n == 1 then slot.title:SetPoint("TOPLEFT", x, 0)
            else slot.title:SetPoint("TOPLEFT", side.slots[n - 1].body, "BOTTOMLEFT", 0, -26) end
            side.slots[n] = slot
        end
        sides[i] = side
    end
    local empty = panel:CreateFontString(nil, "OVERLAY", "SkaldBody")
    empty:SetPoint("TOPLEFT", 0, -10)
    empty:SetWidth(CW)
    empty:SetJustifyH("LEFT")
    empty:SetTextColor(SkaldAPI.C_BODY[1], SkaldAPI.C_BODY[2], SkaldAPI.C_BODY[3])
    local pages, spread = {}, 1
    local function Spreads() return math.max(1, math.ceil(#pages / 2)) end
    local function Show()
        empty:SetText(#pages == 0 and UI.EMPTY or "")
        for i, side in ipairs(sides) do
            local page = pages[(spread - 1) * 2 + i] or {}
            for n, slot in ipairs(side.slots) do
                local c = page[n]
                slot.title:SetShown(c ~= nil)
                slot.rule:SetShown(c ~= nil)
                slot.body:SetShown(c ~= nil)
                if c then slot.title:SetText(c.title); slot.body:SetText(c.text) end
            end
        end
    end
    local function Refresh()
        local ok, built = pcall(ns.BuildSaga)
        if not ok then
            SkaldDB.errors = SkaldDB.errors or {}
            table.insert(SkaldDB.errors, "saga: " .. tostring(built))
            while #SkaldDB.errors > 8 do table.remove(SkaldDB.errors, 1) end
            built = {}
        end
        local size
        pcall(function() size = select(2, SkaldBody:GetFont()) end)
        pages = ns.SagaPages(built, size)
        if spread > Spreads() then spread = Spreads() end
        Show()
    end
    local pager = {
        Turn = function(delta) spread = math.max(1, math.min(Spreads(), spread + delta)); Show() end,
        CanPrev = function() return spread > 1 end,
        CanNext = function() return spread < Spreads() end,
    }
    Refresh()
    return Refresh, pager
end

SkaldAPI.AddTab("saga", UI.TAB, BuildSagaTab)
