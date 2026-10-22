-- Skald: the Saga. The whole diary told as one short book of chapters, in the first person, from what the diary
-- already knows (pages, counters, the game's own statistics, companions, goals). Nothing is stored: the text is built
-- when asked, so a change of language rewrites it, and the same diary always gives the same Saga (each phrase is
-- picked by a hash of stable data, never by chance).
--
-- Loaded after Goals.lua: it uses SkaldAPI (AddTab, PageHeading, GameFacts...) and the saved diary SkaldCharDB.
local _, ns = ...

-- Every phrase of a pool is written so that its number works for one as for many ("the count is {n}").
-- Tags: {name} {race} {class} {date} {place} {level} {days} {n} {boss} {tries} {names} {points} {title} {pages}
-- and {g:he|she} for words that agree with the one who speaks.
local TEXT = {
    enUS = {
        TAB = "Saga", EMPTY = "The saga begins with the first page.", AND = " and ", DATE = "%m/%d/%Y",
        TITLES = {
            prologue = "Prologue", road = "The Road", stories = "Errands and Oaths", war = "Thrones Toppled",
            falls = "The Falls", company = "Company", marks = "Seals and Renown", epilogue = "Epilogue",
        },
        POOLS = {
            prologue = {
                "My name is {name}. I am a {race} {class}, and my story begins on {date}, in {place}, with a first page and no notion of where the road would lead.",
                "On {date}, in {place}, I first set quill to paper. {name} the {race} {class}: a name that meant little then, and means more with every page.",
                "Every saga starts small. Mine started in {place}, on {date}, when a {race} {class} named {name} decided that the road deserved to be remembered.",
                "I did not set out to become a tale. I set out from {place} on {date}, a {race} {class}, and the tale simply followed me.",
                "They will say it began in {place}. It did, on {date}, with a {class} who had yet to learn what the road would ask.",
                "Let it be written: on {date}, in {place}, {name} took the first step. A {race} {class}, with a satchel, a name, and a long road ahead.",
                "The first page is dated {date}, and it was written in {place}. I was only a {race} {class} then, and I am still, but now I have a story to prove it.",
                "Before the legend, the beginning: {place}, {date}, a {race} {class} called {name}. Small things, true things, the kind every saga is built on.",
            },
            road = {
                "Level by level the road taught me its lessons. I stand at level {level} now, and it was in {place} that I last climbed; the count of the days on my road is {days}.",
                "Level {level} is where this page finds me, and {place} is where I last grew. Days walked, by honest count: {days}.",
                "I have not hurried, and I have not stopped. Level {level}, with {place} behind me and the count of the days of road at {days}.",
                "The road does not measure a traveler in years but in steps, and mine have brought me to level {level}. The last of them was taken in {place}; the count of the days is {days}.",
                "Every level was a door, and {place} was the last one I opened. Level {level} waits on the other side, and the count of the days of the road is {days}.",
                "If you ask how far I have come: level {level}, and the last stretch was in {place}. If you ask for how long: the count of days, in these pages, is {days}.",
                "I measure the road in levels, and today the measure reads {level}. It was in {place} that it last rose; the count of the days behind it is {days}.",
                "Strong legs, light pack, level {level}. {place} marks the last time I felt myself grow, and since the first page the count of days is {days}.",
            },
            stories = {
                "Quests were the pages of my days: errands, oaths, small promises kept. The count of those I carried to their end is {n}.",
                "Every quest is a promise, and I have tried to keep them all. The ledger of promises kept reads {n}.",
                "Some tasks were small, some became tales worth telling. Together they make a tally of {n}, and I would not trade one.",
                "I never refused a stranger who needed a hand. The quests I saw through, from the first errand to the latest: {n}.",
                "A road is made of errands. Mine, finished and signed, come to a total of {n}, and each left its mark on the way I walk.",
                "Ask the villages what I did for them and they will tell you of errands. I can tell you the number: {n}.",
                "The quest log is a book of its own, and in it the total of closed entries is {n}. I carry them all, lightly.",
                "What is a hero but someone who answers when called? By that measure, the count of my answers is {n}, and the calling has not stopped.",
            },
            war = {
                "Some foes do not fall to a sword alone. They fall to patience, to friends, to the third try. The count of the great ones I brought down is {n}.",
                "I have stood in halls where the walls remember every blow. The bosses I left fallen behind me: {n}.",
                "A boss is a question the dungeon asks, and each time I answered with steel and company. The count of answers is {n}.",
                "They guarded their thrones with everything they had, and it was not enough. Thrones I have seen emptied: {n}.",
                "The war-horns of the deep places sound for me now. Bosses defeated: {n}.",
                "I came to the depths to be tested, and I was. Of the champions among my foes, those who now lie still: {n}.",
                "Blood, noise, and then the silence after the fall of the great one. The tally of those silences is {n}.",
                "No song of mine is without a clash of arms. The great adversaries who ended in it: {n}.",
            },
            warHard = {
                "{boss} did not yield easily. I fell before it, and rose, and the count of falls before the victory was {tries}.",
                "Of all the great ones, {boss} cost me the most: the tally of my falls, before it finally lay still, was {tries}.",
                "{boss} taught me humility first and victory after. Falls before the end: {tries}.",
                "I remember {boss} best, because I lost to it before I won. The count of lost attempts: {tries}.",
                "Victory over {boss} was sweeter for the road it took. Falls on that road, by count: {tries}.",
                "Some wins are clean. The one over {boss} was not, and I would not have it otherwise: the falls before it, {tries}.",
                "They will tell of {boss} as the one that nearly beat me. The falls before the win: {tries}.",
                "{boss} stood between me and the next chapter, and charged a toll in falls: {tries}. I paid, and passed.",
            },
            falls = {
                "I have fallen, and I will not pretend otherwise. The count of my falls is {n}, and it was in {place} that I fell most.",
                "A hero is measured by the rising as much as by the glory. The tally of my falls is {n}, with {place} as the harshest teacher.",
                "Death has been a stranger to no one on this road. Mine came to a tally of {n}, and in {place} it called the loudest.",
                "The spirit healer knows my face. The count of my falls: {n}; the land that asked the most of me: {place}.",
                "Not every page is a triumph. Some are the quiet after a fall, and their count is {n}, with {place} the author of most of them.",
                "I fell in {place} more than anywhere, and I got up every time. The count of my falls, in all: {n}.",
                "Ask me about the ground I know best and I will say {place}, from lying on it. All my falls together: {n}.",
                "Every fall left a lesson, and {place} gave the hardest. The tally of the lessons is {n}.",
            },
            company = {
                "I did not walk alone. The count of faces I have chosen to remember along the road is {n}.",
                "A road is lighter with company. The companions I carry in memory: {n}.",
                "Names matter more than gold. The companions I have kept in the diary: {n}.",
                "Some strangers stay in the memory because they stood beside me when it counted. Their count is {n}.",
                "Dungeons and long roads make friends of strangers. My book of companions holds {n}.",
                "No saga is told by one voice alone. The others who walked with me, remembered here: {n}.",
                "I keep them as one keeps a lamp: companions of the road, counted at {n}, each a small light.",
                "Fellowship was the best treasure of the road. The tally of companions I remember is {n}.",
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
                "The road also asked for deeds worth a seal. The count of goals reached is {n}, the points are {points}, and the title they earned me is {title}.",
                "I have gathered {points} points of renown in goals reached, the count is {n}, and with them the title of {title}.",
                "A seal here, a seal there: the count of goals reached is {n}, that of points {points}, and the title they bring is {title}.",
                "Renown is a ledger, and I keep mine. Goals reached: {n}. Points: {points}. They call me {title}.",
                "Not all that matters is counted, but some of it is. Goals reached: {n}; points: {points}; my title, {title}.",
                "{title}: that is what {points} points of renown, from the goals reached (the count is {n}), have made of me.",
                "The seals of the book hold my goals: reached, {n}; worth, {points} points; and the title, {title}.",
                "Small goals, larger ones, a few that took patience: reached, {n}; points won, {points}; and the name {title} to wear.",
            },
            epilogue = {
                "The story is not over, only paused where this page ends. I stand at level {level}, the count of the pages written is {pages}, and the road still opens ahead of {name}.",
                "Here I close the book for now. Level {level}, pages in the diary: {pages}. The rest is road, and the road is long.",
                "If this were the last page, I would be content: pages kept, {pages}; level {level} reached; and a name that was mine to write. But there is more road.",
                "Saga, they call it. I call it the road so far: level {level}, pages kept, {pages}. The next chapter waits for {name} outside the door.",
                "Let whoever reads this know that {name} was here, reached level {level}, and kept pages to prove it: {pages}. The story goes on.",
                "The ink is dry on pages counted at {pages}, and the road is not. Level {level} is only where I stand today.",
                "What is a saga but a road remembered? Mine, so far: level {level}, pages kept, {pages}, and the rest still unwritten.",
                "Close the book gently, and leave the quill nearby. {name}, level {level}, has more to tell.",
            },
            epilogueTop = {
                "Level sixty. The top of the world, and the page where a saga might rightly end. It will not: {name} has pages kept, the count is {pages}, and the road still has its turns.",
                "I reached the summit, and the view was worth every page I wrote on the way, the count is {pages}. Now I look at the horizon, because there is always one more.",
                "From the top of the world, {name} looks back along the road: pages kept, {pages}; and every one a step.",
                "This is the end of the climb and the beginning of the legend. Pages written: {pages}. The title: {title}.",
                "They said the road had a top. They were right, and I stood on it. Of the pages written on the way, the count is {pages}.",
                "At the top, one thing is clear: the story was never the level, it was the road. The road, in this book, has its pages counted at {pages}, and it is still open.",
                "Sixty levels, and the diary kept me honest, with pages counted at {pages}. {name}, {title}, closes the book only to open another.",
                "A saga's last chapter is the promise of the next. I have kept pages, the count is {pages}, and I have kept the promise too.",
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
                "Meu nome é {name}. Sou {g:um|uma} {race} {class}, e a minha história começa em {date}, em {place}, com uma primeira página e nenhuma ideia de aonde a estrada me levaria.",
                "Em {date}, em {place}, pus a pena no papel pela primeira vez. {name}, {g:um|uma} {race} {class}: um nome que pouco dizia então e que diz mais a cada página.",
                "Toda saga começa pequena. A minha começou em {place}, em {date}, quando {g:um|uma} {race} {class} chamad{g:o|a} {name} decidiu que a estrada merecia ser lembrada.",
                "Não parti para virar história. Parti de {place} em {date}, {g:um|uma} {race} {class}, e a história simplesmente me seguiu.",
                "Dirão que tudo começou em {place}. Começou, sim, em {date}, com {g:um|uma} {class} que ainda não sabia o que a estrada iria pedir.",
                "Fique escrito: em {date}, em {place}, {name} deu o primeiro passo. {g:Um|Uma} {race} {class}, com uma bolsa, um nome e uma longa estrada pela frente.",
                "A primeira página tem a data de {date} e foi escrita em {place}. Eu era só {g:um|uma} {race} {class} então, e ainda sou, mas agora tenho uma história para provar.",
                "Antes da lenda, o começo: {place}, {date}, {g:um|uma} {race} {class} chamad{g:o|a} {name}. Coisas pequenas, coisas verdadeiras, aquelas de que toda saga é feita.",
            },
            road = {
                "Nível a nível a estrada me ensinou as suas lições. Estou no nível {level}, e foi em {place} que subi pela última vez; a conta dos dias da minha estrada é {days}.",
                "O nível {level} é onde esta página me encontra, e {place} é onde cresci pela última vez. Dias caminhados, em conta honesta: {days}.",
                "Não apressei o passo e não parei. Nível {level}, com {place} para trás e a conta dos dias de estrada em {days}.",
                "A estrada não mede quem viaja em anos, mas em passos, e os meus me trouxeram ao nível {level}. O último foi dado em {place}; a conta dos dias é {days}.",
                "Cada nível foi uma porta, e {place} foi a última que abri. O nível {level} espera do outro lado, e a conta dos dias da estrada é {days}.",
                "Se perguntarem até onde cheguei: nível {level}, e o último trecho foi em {place}. Se perguntarem há quanto tempo: a conta dos dias, nestas páginas, é {days}.",
                "Meço a estrada em níveis, e hoje a medida marca {level}. Foi em {place} que ela subiu da última vez; a conta dos dias, atrás dela, é {days}.",
                "Pernas fortes, bagagem leve, nível {level}. {place} marca a última vez que me senti crescer, e desde a primeira página a conta de dias é {days}.",
            },
            stories = {
                "As missões foram as páginas dos meus dias: recados, juramentos, pequenas promessas cumpridas. A conta das que levei até o fim é {n}.",
                "Cada missão é uma promessa, e tentei cumprir todas. O livro-caixa das promessas cumpridas marca {n}.",
                "Algumas tarefas foram pequenas, outras viraram histórias dignas de contar. Juntas, fazem a conta de {n}, e não trocaria nenhuma.",
                "Nunca recusei um desconhecido que precisava de uma mão. As missões que vi até o fim, do primeiro recado ao mais recente: {n}.",
                "Uma estrada é feita de recados. Os meus, terminados e assinados, chegam ao total de {n}, e cada um deixou marca no jeito como caminho.",
                "Pergunte às aldeias o que fiz por elas e falarão de recados. Eu lhe digo o número: {n}.",
                "O diário de missões é um livro à parte, e nele o total de entradas fechadas é {n}. Carrego todas, com leveza.",
                "O que é um herói senão alguém que responde quando chamado? Por essa medida, a conta das minhas respostas é {n}, e o chamado não parou.",
            },
            war = {
                "Alguns inimigos não caem só pela espada. Caem pela paciência, pelos amigos, pela terceira tentativa. A conta dos grandes que derrubei é {n}.",
                "Estive em salões onde as paredes guardam a memória de cada golpe. Os chefes que deixei caídos atrás de mim: {n}.",
                "Um chefe é uma pergunta que a masmorra faz, e a cada vez respondi com aço e companhia. A conta das respostas é {n}.",
                "Guardaram os seus tronos com tudo o que tinham, e não bastou. Tronos que vi esvaziados: {n}.",
                "As trompas de guerra dos lugares fundos agora soam para mim. Chefes derrotados: {n}.",
                "Desci às profundezas para ser {g:posto|posta} à prova, e fui. Dos campeões entre os meus inimigos, os que agora jazem quietos: {n}.",
                "Sangue, ruído e depois o silêncio que vem após a queda do grande. A conta desses silêncios é {n}.",
                "Nenhuma canção minha existe sem o choque das armas. Os grandes adversários que nela chegaram ao fim: {n}.",
            },
            warHard = {
                "{boss} não cedeu com facilidade. Caí diante dele, e me levantei, e a conta das quedas antes da vitória foi {tries}.",
                "De todos os grandes, {boss} foi o que mais me custou: a conta das minhas quedas, antes que ele enfim jazesse quieto, foi {tries}.",
                "{boss} me ensinou primeiro a humildade e depois a vitória. Quedas antes do fim: {tries}.",
                "Lembro de {boss} melhor que dos outros, porque perdi antes de vencer. A conta das tentativas perdidas: {tries}.",
                "A vitória sobre {boss} foi mais doce pelo caminho que custou. Quedas nesse caminho, em conta: {tries}.",
                "Algumas vitórias são limpas. A de {boss} não foi, e não a quereria de outro modo: as quedas antes dela, {tries}.",
                "Contarão de {boss} como aquele que quase me venceu. As quedas antes da vitória: {tries}.",
                "{boss} se pôs entre mim e o capítulo seguinte, e cobrou um pedágio em quedas: {tries}. Paguei, e passei.",
            },
            falls = {
                "Caí, e não vou fingir o contrário. A conta das minhas quedas é {n}, e foi em {place} que mais caí.",
                "Um herói se mede tanto pelo levantar quanto pela glória. A conta das minhas quedas é {n}, e {place} foi a mestra mais dura.",
                "A morte não foi estranha a ninguém nesta estrada. A minha chegou à conta de {n}, e em {place} chamou mais alto.",
                "O curandeiro de espíritos conhece o meu rosto. A conta das minhas quedas: {n}; a terra que mais me exigiu: {place}.",
                "Nem toda página é triunfo. Algumas são o silêncio depois de uma queda, e a conta delas é {n}, com {place} como autora da maioria.",
                "Caí em {place} mais do que em qualquer lugar, e me levantei todas as vezes. A conta das quedas, ao todo: {n}.",
                "Pergunte-me pelo chão que melhor conheço e direi {place}, de tanto deitar nele. Todas as quedas juntas: {n}.",
                "Cada queda deixou uma lição, e {place} deu a mais dura. A conta das lições é {n}.",
            },
            company = {
                "Não caminhei {g:sozinho|sozinha}. A conta dos rostos que escolhi lembrar ao longo da estrada é {n}.",
                "Uma estrada fica mais leve com companhia. Os companheiros que carrego na memória: {n}.",
                "Nomes valem mais que ouro. Os companheiros que guardei no diário: {n}.",
                "Alguns desconhecidos ficam na memória porque estiveram ao meu lado quando importava. A conta deles é {n}.",
                "Masmorras e longas estradas fazem amigos de desconhecidos. O meu livro de companheiros guarda {n}.",
                "Nenhuma saga é contada por uma voz só. Os outros que caminharam comigo, lembrados aqui: {n}.",
                "Guardo-os como se guarda uma lamparina: companheiros da estrada, contados em {n}, cada um uma pequena luz.",
                "A companhia foi o melhor tesouro da estrada. A conta dos companheiros que lembro é {n}.",
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
                "A estrada também pediu feitos dignos de um selo. A conta das metas cumpridas é {n}, os pontos são {points}, e o título que me renderam é {title}.",
                "Juntei {points} pontos de renome em metas cumpridas, a conta é {n}, e com eles o título de {title}.",
                "Um selo aqui, outro ali: a conta das metas cumpridas é {n}, a dos pontos {points}, e o título que trazem é {title}.",
                "Renome é um livro-caixa e eu mantenho o meu. Metas cumpridas: {n}. Pontos: {points}. Chamam-me {title}.",
                "Nem tudo o que importa se conta, mas parte se conta. Metas cumpridas: {n}; pontos: {points}; o meu título, {title}.",
                "{title}: é o que {points} pontos de renome, vindos das metas cumpridas (a conta é {n}), fizeram de mim.",
                "Os selos do livro guardam as minhas metas: cumpridas, {n}; valor, {points} pontos; e o título, {title}.",
                "Metas pequenas, outras maiores, algumas que pediram paciência: cumpridas, {n}; pontos ganhos, {points}; e o nome {title} para vestir.",
            },
            epilogue = {
                "A história não terminou, só fez uma pausa onde esta página acaba. Estou no nível {level}, a conta das páginas escritas é {pages}, e a estrada ainda se abre diante de {name}.",
                "Aqui fecho o livro, por ora. Nível {level}, páginas no diário: {pages}. O resto é estrada, e a estrada é longa.",
                "Se esta fosse a última página, eu ficaria contente: páginas guardadas, {pages}; nível {level} alcançado; e um nome que coube a mim escrever. Mas há mais estrada.",
                "Saga, dizem. Eu digo a estrada até aqui: nível {level}, páginas guardadas, {pages}. O próximo capítulo espera {name} do lado de fora da porta.",
                "Saiba quem ler isto que {name} esteve aqui, chegou ao nível {level} e guardou páginas para provar: {pages}. A história continua.",
                "A tinta secou em páginas contadas em {pages}, e a estrada não secou. O nível {level} é só onde estou hoje.",
                "O que é uma saga senão uma estrada lembrada? A minha, até aqui: nível {level}, páginas guardadas, {pages}, e o resto ainda por escrever.",
                "Feche o livro com delicadeza e deixe a pena por perto. {name}, nível {level}, ainda tem o que contar.",
            },
            epilogueTop = {
                "Nível sessenta. O topo do mundo, e a página em que uma saga poderia terminar com razão. Não termina: {name} tem páginas guardadas, a conta é {pages}, e a estrada ainda tem curvas.",
                "Cheguei ao cume, e a vista valeu cada página que escrevi pelo caminho, a conta é {pages}. Agora olho o horizonte, porque há sempre mais um.",
                "Do topo do mundo, {name} olha para trás ao longo da estrada: páginas guardadas, {pages}; e cada uma um passo.",
                "Este é o fim da subida e o começo da lenda. Páginas escritas: {pages}. O título: {title}.",
                "Diziam que a estrada tinha um topo. Tinham razão, e estive nele. Das páginas escritas no caminho, a conta é {pages}.",
                "No topo, uma coisa fica clara: a história nunca foi o nível, foi a estrada. A estrada, neste livro, tem as páginas contadas em {pages}, e continua aberta.",
                "Sessenta níveis, e o diário me manteve {g:honesto|honesta}, com páginas contadas em {pages}. {name}, {title}, fecha o livro só para abrir outro.",
                "O último capítulo de uma saga é a promessa do próximo. Guardei páginas, a conta é {pages}, e guardei também a promessa.",
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
                "Je m'appelle {name}. Je suis {g:un|une} {race} {class}, et mon histoire commence le {date}, à {place}, avec une première page et nulle idée de là où la route me mènerait.",
                "Le {date}, à {place}, j'ai posé la plume sur le papier pour la première fois. {name}, {g:un|une} {race} {class}\194\160: un nom qui disait peu alors, et qui en dit plus à chaque page.",
                "Toute saga commence petite. La mienne a commencé à {place}, le {date}, quand {g:un|une} {race} {class} nommé{g:|e} {name} a décidé que la route méritait d'être retenue.",
                "Je ne suis pas parti{g:|e} pour devenir une histoire. Je suis parti{g:|e} de {place} le {date}, {g:un|une} {race} {class}, et l'histoire m'a simplement suivi{g:|e}.",
                "On dira que tout a commencé à {place}. C'est vrai, le {date}, avec {g:un|une} {class} qui ignorait encore ce que la route allait lui demander.",
                "Qu'il soit écrit\194\160: le {date}, à {place}, {name} a fait le premier pas. {g:Un|Une} {race} {class}, avec une besace, un nom et une longue route devant soi.",
                "La première page porte la date du {date} et fut écrite à {place}. Je n'étais alors qu'{g:un|une} {race} {class}, et je le suis encore, mais j'ai désormais une histoire pour le prouver.",
                "Avant la légende, le commencement\194\160: {place}, le {date}, {g:un|une} {race} {class} nommé{g:|e} {name}. Des choses petites, des choses vraies, celles dont toute saga est faite.",
            },
            road = {
                "Niveau après niveau, la route m'a enseigné ses leçons. Je suis au niveau {level}, et c'est à {place} que j'ai grandi pour la dernière fois\194\160; le compte des jours de ma route est de {days}.",
                "Le niveau {level} est l'endroit où cette page me trouve, et {place} celui où j'ai grandi pour la dernière fois. Jours de marche, en compte honnête\194\160: {days}.",
                "Je n'ai pas pressé le pas et je ne me suis pas arrêté{g:|e}. Niveau {level}, {place} derrière moi, et le compte des jours de route est de {days}.",
                "La route ne mesure pas un voyageur en années mais en pas, et les miens m'ont mené{g:|e} au niveau {level}. Le dernier fut fait à {place}\194\160; le compte des jours est de {days}.",
                "Chaque niveau fut une porte, et {place} fut la dernière que j'ai ouverte. Le niveau {level} attend de l'autre côté, et le compte des jours de route est de {days}.",
                "Si l'on demande jusqu'où je suis venu{g:|e}\194\160: niveau {level}, et le dernier tronçon fut à {place}. Si l'on demande depuis quand\194\160: le compte des jours, dans ces pages, est de {days}.",
                "Je mesure la route en niveaux, et aujourd'hui la mesure indique {level}. C'est à {place} qu'elle a monté la dernière fois\194\160; le compte des jours derrière elle est de {days}.",
                "Jambes solides, bagage léger, niveau {level}. {place} marque la dernière fois où je me suis senti{g:|e} grandir, et depuis la première page le compte des jours est de {days}.",
            },
            stories = {
                "Les quêtes furent les pages de mes jours\194\160: courses, serments, petites promesses tenues. Le compte de celles que j'ai menées à leur terme est de {n}.",
                "Chaque quête est une promesse, et j'ai tenté de les tenir toutes. Le registre des promesses tenues indique {n}.",
                "Certaines tâches furent petites, d'autres devinrent des récits dignes d'être contés. Ensemble, elles font le compte de {n}, et je n'en échangerais aucune.",
                "Je n'ai jamais refusé un inconnu qui avait besoin d'un coup de main. Les quêtes que j'ai menées jusqu'au bout, de la première course à la plus récente\194\160: {n}.",
                "Une route est faite de courses. Les miennes, terminées et signées, atteignent le total de {n}, et chacune a laissé sa marque sur mon pas.",
                "Demandez aux villages ce que j'ai fait pour eux, ils vous parleront de courses. Moi, je vous donne le chiffre\194\160: {n}.",
                "Le journal de quêtes est un livre à part, et le total des entrées closes y est de {n}. Je les porte toutes, légèrement.",
                "Qu'est-ce qu'un héros, sinon quelqu'un qui répond quand on l'appelle\194\160? Selon cette mesure, le compte de mes réponses est de {n}, et les appels n'ont pas cessé.",
            },
            war = {
                "Certains ennemis ne tombent pas par la seule épée. Ils tombent par la patience, par les amis, au troisième essai. Le compte des grands que j'ai abattus est de {n}.",
                "J'ai tenu dans des salles dont les murs se souviennent de chaque coup. Les boss laissés à terre derrière moi\194\160: {n}.",
                "Un boss est une question que le donjon pose, et chaque fois j'ai répondu par l'acier et la compagnie. Le compte des réponses est de {n}.",
                "Ils gardaient leurs trônes de toutes leurs forces, et ce ne fut pas assez. Trônes que j'ai vus vidés\194\160: {n}.",
                "Les cors de guerre des lieux profonds sonnent désormais pour moi. Boss vaincus\194\160: {n}.",
                "Je suis descendu{g:|e} aux profondeurs pour être mis{g:|e} à l'épreuve, et je l'ai été. Parmi mes ennemis, les champions désormais immobiles\194\160: {n}.",
                "Du sang, du bruit, puis le silence après la chute du grand. Le compte de ces silences est de {n}.",
                "Aucune de mes chansons ne vit sans le choc des armes. Les grands adversaires qui s'y sont achevés\194\160: {n}.",
            },
            warHard = {
                "{boss} n'a pas cédé aisément. Je suis tombé{g:|e} devant lui, et je me suis relevé{g:|e}\194\160; le compte des chutes avant la victoire fut de {tries}.",
                "De tous les grands, {boss} fut celui qui m'a coûté le plus\194\160: le compte de mes chutes, avant qu'il ne repose enfin, fut de {tries}.",
                "{boss} m'a appris d'abord l'humilité, puis la victoire. Chutes avant la fin\194\160: {tries}.",
                "Je me souviens de {boss} mieux que des autres, car j'ai perdu avant de vaincre. Le compte des tentatives perdues\194\160: {tries}.",
                "La victoire sur {boss} fut plus douce à cause du chemin qu'elle a coûté. Chutes sur ce chemin, au compte\194\160: {tries}.",
                "Certaines victoires sont nettes. Celle de {boss} ne le fut pas, et je ne la voudrais pas autrement\194\160: les chutes avant elle, {tries}.",
                "On parlera de {boss} comme de celui qui a failli me vaincre. Les chutes avant la victoire\194\160: {tries}.",
                "{boss} s'est dressé entre moi et le chapitre suivant, et a exigé un péage en chutes\194\160: {tries}. J'ai payé, et je suis passé{g:|e}.",
            },
            falls = {
                "Je suis tombé{g:|e}, et je ne ferai pas semblant du contraire. Le compte de mes chutes est de {n}, et c'est à {place} que je suis le plus tombé{g:|e}.",
                "On mesure un héros autant à son relèvement qu'à sa gloire. Le compte de mes chutes est de {n}, et {place} fut la maîtresse la plus dure.",
                "La mort n'a été étrangère à personne sur cette route. La mienne a atteint le compte de {n}, et c'est à {place} qu'elle a appelé le plus fort.",
                "Le guérisseur des esprits connaît mon visage. Le compte de mes chutes\194\160: {n}\194\160; la contrée qui m'a le plus demandé\194\160: {place}.",
                "Toutes les pages ne sont pas des triomphes. Certaines sont le silence après une chute, et leur compte est de {n}, avec {place} pour auteur de la plupart.",
                "Je suis tombé{g:|e} à {place} plus qu'ailleurs, et je me suis relevé{g:|e} chaque fois. Le compte des chutes, au total\194\160: {n}.",
                "Demandez-moi quel sol je connais le mieux et je dirai {place}, à force d'y être couché{g:|e}. Toutes les chutes ensemble\194\160: {n}.",
                "Chaque chute a laissé une leçon, et {place} a donné la plus dure. Le compte des leçons est de {n}.",
            },
            company = {
                "Je n'ai pas marché seul{g:|e}. Le compte des visages que j'ai choisi de retenir le long de la route est de {n}.",
                "Une route est plus légère en compagnie. Les compagnons que je porte en mémoire\194\160: {n}.",
                "Les noms valent plus que l'or. Les compagnons que j'ai gardés dans le journal\194\160: {n}.",
                "Certains inconnus restent en mémoire parce qu'ils étaient à mes côtés quand cela comptait. Leur compte est de {n}.",
                "Les donjons et les longues routes font des amis d'inconnus. Mon livre de compagnons en garde {n}.",
                "Aucune saga n'est contée par une seule voix. Les autres qui ont marché avec moi, retenus ici\194\160: {n}.",
                "Je les garde comme on garde une lampe\194\160: des compagnons de route, comptés à {n}, chacun une petite lumière.",
                "La compagnie fut le meilleur trésor de la route. Le compte des compagnons dont je me souviens est de {n}.",
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
                "La route a aussi demandé des exploits dignes d'un sceau. Le compte des objectifs atteints est de {n}, les points sont de {points}, et le titre qu'ils m'ont valu est {title}.",
                "J'ai réuni {points} points de renom en objectifs atteints, le compte est de {n}, et avec eux le titre de {title}.",
                "Un sceau ici, un autre là\194\160: le compte des objectifs atteints est de {n}, celui des points de {points}, et le titre qu'ils apportent est {title}.",
                "Le renom est un registre et je tiens le mien. Objectifs atteints\194\160: {n}. Points\194\160: {points}. On m'appelle {title}.",
                "Tout ce qui compte ne se compte pas, mais une partie, si. Objectifs atteints\194\160: {n}\194\160; points\194\160: {points}\194\160; mon titre, {title}.",
                "{title}\194\160: voilà ce que {points} points de renom, venus des objectifs atteints (le compte est de {n}), ont fait de moi.",
                "Les sceaux du livre gardent mes objectifs\194\160: atteints, {n}\194\160; valeur, {points} points\194\160; et le titre, {title}.",
                "Des objectifs petits, d'autres plus grands, quelques-uns qui ont demandé de la patience\194\160: atteints, {n}\194\160; points gagnés, {points}\194\160; et le nom {title} à porter.",
            },
            epilogue = {
                "L'histoire n'est pas finie, seulement en pause là où cette page s'achève. Je suis au niveau {level}, le compte des pages écrites est de {pages}, et la route s'ouvre encore devant {name}.",
                "Ici je ferme le livre, pour l'heure. Niveau {level}, pages dans le journal\194\160: {pages}. Le reste est route, et la route est longue.",
                "Si c'était la dernière page, je serais content{g:|e}\194\160: pages gardées, {pages}\194\160; niveau {level} atteint\194\160; et un nom qu'il m'a appartenu d'écrire. Mais il y a encore de la route.",
                "Saga, dit-on. Moi, je dis la route jusqu'ici\194\160: niveau {level}, pages gardées, {pages}. Le prochain chapitre attend {name} derrière la porte.",
                "Que celui qui lit ceci sache que {name} est passé{g:|e} par ici, a atteint le niveau {level} et gardé des pages pour le prouver\194\160: {pages}. L'histoire continue.",
                "L'encre a séché sur des pages comptées à {pages}, et la route n'a pas séché. Le niveau {level} n'est que là où je me tiens aujourd'hui.",
                "Qu'est-ce qu'une saga, sinon une route retenue\194\160? La mienne, jusqu'ici\194\160: niveau {level}, pages gardées, {pages}, et le reste encore à écrire.",
                "Fermez le livre doucement et laissez la plume à portée. {name}, niveau {level}, a encore à conter.",
            },
            epilogueTop = {
                "Niveau soixante. Le sommet du monde, et la page où une saga pourrait finir à bon droit. Elle ne finira pas\194\160: {name} a des pages gardées, le compte est de {pages}, et la route a encore des détours.",
                "J'ai atteint le sommet, et la vue valait chaque page écrite en chemin, le compte est de {pages}. Je regarde maintenant l'horizon, car il y en a toujours un autre.",
                "Du sommet du monde, {name} regarde en arrière le long de la route\194\160: pages gardées, {pages}\194\160; et chacune un pas.",
                "Voici la fin de la montée et le début de la légende. Pages écrites\194\160: {pages}. Le titre\194\160: {title}.",
                "On disait que la route avait un sommet. On avait raison, et j'y suis monté{g:|e}. Des pages écrites en chemin, le compte est de {pages}.",
                "Au sommet, une chose est claire\194\160: l'histoire n'a jamais été le niveau, c'était la route. La route, dans ce livre, a ses pages comptées à {pages}, et reste ouverte.",
                "Soixante niveaux, et le journal m'a gardé{g:|e} honnête, avec des pages comptées à {pages}. {name}, {title}, ne ferme le livre que pour en ouvrir un autre.",
                "Le dernier chapitre d'une saga est la promesse du suivant. J'ai gardé des pages, le compte est de {pages}, et j'ai gardé aussi la promesse.",
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
    local text = phrase:gsub("{(%a+)}", function(key)
        local v = vars[key]
        if v == nil then return "" end
        return tostring(v)
    end)
    return ns.Gendered(text)
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
    local base = { name = v.name, race = v.race, class = v.class, date = when, place = v.place, level = v.level,
        days = v.days, pages = v.pages, title = v.title }
    Add("prologue", { { "prologue", base } })
    Add("road", { { "road", { level = v.level, place = v.levelPlace, days = v.days } } })
    if v.quests > 0 then Add("stories", { { "stories", { n = v.quests } } }) end
    if v.bosses > 0 then
        local parts = { { "war", { n = v.bosses } } }
        if v.hardBoss then parts[#parts + 1] = { "warHard", { boss = v.hardBoss, tries = v.hardTries } } end
        Add("war", parts)
    end
    if v.deaths > 0 then
        Add("falls", { { "falls", { n = v.deaths, place = v.deathPlace or ns.LOCALES[GetLocale()] and ns.LOCALES[GetLocale()].UNKNOWN_ZONE or "?" } } })
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

-- The chapters go onto pages by weight (characters, the title counted as some), as many to a page as the size of the
-- letter lets fit: the same in the simulation and in the game, whatever the font. Never a chapter split.
local TITLE_WEIGHT, PAGE_WEIGHT_AT_15 = 90, 760
ns.SagaPages = function(chapters, size)
    size = (type(size) == "number" and size > 0) and size or 13
    local budget = PAGE_WEIGHT_AT_15 * (15 / size) * (15 / size)
    local pages, page, used = {}, {}, 0
    for _, c in ipairs(chapters) do
        local w = #c.text + TITLE_WEIGHT
        if #page > 0 and (used + w > budget or #page >= 3) then
            pages[#pages + 1] = page
            page, used = {}, 0
        end
        page[#page + 1] = c
        used = used + w
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
