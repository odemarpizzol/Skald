-- Hand-picked quests: a fixed rarity and a text of their own, so a moment that
-- deserves a story does not get a generic line.
--
--   ns.CURATED[questID] = {
--       tier = 5,                       -- 0 Trivial .. 5 Legendary (overrides the automatic rarity)
--       text = {
--           enUS = "{npc} asked the impossible of me in \"{quest}\"...",
--           ptBR = "{npc} pediu o impossível de mim em \"{quest}\"...",
--       },
--   }
--
-- {quest} is the quest title and {npc} whoever handed it in. Any locale left out
-- falls back to enUS. IDs and chain data come from QuestDB (the candidates
-- list was built with the scripts in tools/). Texts follow what each quest asks and
-- avoid claiming lore beyond it.

local _, ns = ...

local C = {}

-- Thunderfury (Legendary) ---------------------------------------------------
C[7785] = { tier = 5, text = {
    enUS = "A vessel, a whisper of wind, and the beginning of a legend: \"{quest}\". {npc} set me on a road few ever walk.",
    ptBR = "Um receptáculo, um sussurro de vento e o começo de uma lenda: \"{quest}\". {npc} me pôs numa estrada que poucos trilham.",
    frFR = "Un réceptacle, un souffle de vent et le début d'une légende\194\160: «\194\160{quest}\194\160». {npc} m'a mis sur une route que peu de gens empruntent.",
} }
C[7786] = { tier = 5, text = {
    enUS = "The wind itself had a name, and I learned it: \"{quest}\". Whatever answers to that name is not to be trifled with.",
    ptBR = "O próprio vento tinha um nome, e eu o aprendi: \"{quest}\". Seja o que for que responde a esse nome, não é para brincadeiras.",
    frFR = "Le vent lui-même avait un nom, et je l'ai appris\194\160: «\194\160{quest}\194\160». Ce qui répond à ce nom ne se prend pas à la légère.",
} }
C[7787] = { tier = 5, text = {
    enUS = "Thunderfury rises. Some blades are forged; this one was earned along a long and fearsome road. \"{quest}\" is a name the world will repeat.",
    ptBR = "Thunderfury se ergue. Algumas lâminas são forjadas; esta foi conquistada numa estrada longa e temível. \"{quest}\" é um nome que o mundo vai repetir.",
    frFR = "Foudrefuria se dresse. Certaines lames sont forgées\194\160; celle-ci a été méritée sur une longue et redoutable route. «\194\160{quest}\194\160» est un nom que le monde répétera.",
} }

-- Atiesh (Legendary) --------------------------------------------------------
C[9250] = { tier = 5, text = {
    enUS = "The frame of a legendary staff, and a road ahead that does not forgive hesitation: \"{quest}\".",
    ptBR = "A armação de um cajado lendário, e uma estrada pela frente que não perdoa hesitação: \"{quest}\".",
    frFR = "La structure d'un bâton légendaire, et une route devant moi qui ne pardonne pas l'hésitation\194\160: «\194\160{quest}\194\160».",
} }
C[9251] = { tier = 5, text = {
    enUS = "A staff that should have been a guardian's, and is now befouled. What I do with it next will matter: \"{quest}\".",
    ptBR = "Um cajado que devia ser de um guardião, e que agora está corrompido. O que farei com ele em seguida vai importar: \"{quest}\".",
    frFR = "Un bâton qui aurait dû appartenir à un gardien, et qui est désormais souillé. Ce que j'en ferai ensuite comptera\194\160: «\194\160{quest}\194\160».",
} }
local ATIESH_WHOLE = { tier = 5, text = {
    enUS = "The greatstaff is whole, and so is the legend: \"{quest}\". Let the guardians of old know it has found a bearer.",
    ptBR = "O grande cajado está inteiro, e a lenda também: \"{quest}\". Que os guardiões de outrora saibam que ele encontrou quem o empunhe.",
    frFR = "Le grand bâton est entier, et la légende aussi\194\160: «\194\160{quest}\194\160». Que les gardiens d'autrefois sachent qu'il a trouvé son porteur.",
} }
for _, id in ipairs({ 9257, 9269, 9270, 9271 }) do C[id] = ATIESH_WHOLE end

-- Attunements and keys (Epic) -----------------------------------------------
C[6502] = { tier = 4, text = {
    enUS = "Step by step I earned it: \"{quest}\". An amulet to open a dragon's door, and the nerve to walk through.",
    ptBR = "Passo a passo, eu a conquistei: \"{quest}\". Um amuleto para abrir a porta de um dragão, e a coragem de atravessá-la.",
    frFR = "Pas à pas, je l'ai mérité\194\160: «\194\160{quest}\194\160». Une amulette pour ouvrir la porte d'un dragon, et le courage de la franchir.",
} }
local KEY = { tier = 4, text = {
    enUS = "A key, long sought and hard won: \"{quest}\". Behind that door waits a place where the bravest are measured.",
    ptBR = "Uma chave, muito procurada e arduamente conquistada: \"{quest}\". Atrás daquela porta há um lugar onde os bravos são medidos.",
    frFR = "Une clé, longtemps cherchée et durement gagnée\194\160: «\194\160{quest}\194\160». Derrière cette porte se trouve un lieu où les plus braves sont mesurés.",
} }
C[5505], C[5511] = KEY, KEY

-- Long chains (Epic and Rare) -----------------------------------------------
C[1267] = { tier = 4, text = {
    enUS = "A man had vanished, and a long trail of favors, letters and doubt led to the end of it: \"{quest}\". Not every hero draws a sword; some follow a thread.",
    ptBR = "Um homem desapareceu, e uma longa trilha de favores, cartas e dúvidas levou ao fim dela: \"{quest}\". Nem todo herói saca a espada; alguns seguem um fio.",
    frFR = "Un homme avait disparu, et une longue piste de faveurs, de lettres et de doutes menait à sa fin\194\160: «\194\160{quest}\194\160». Tous les héros ne tirent pas l'épée\194\160; certains suivent un fil.",
} }
C[5944] = { tier = 4, text = {
    enUS = "I walked into dreams and came back: \"{quest}\". Not every road is paved with stone.",
    ptBR = "Entrei nos sonhos e voltei: \"{quest}\". Nem toda estrada é feita de pedra.",
    frFR = "Je suis entré dans les rêves et j'en suis revenu\194\160: «\194\160{quest}\194\160». Toutes les routes ne sont pas pavées de pierre.",
} }
C[8729] = { tier = 4, text = {
    enUS = "The sea has a temper, and I answered it: \"{quest}\". The tide remembers those who stood before it.",
    ptBR = "O mar tem seu temperamento, e eu o enfrentei: \"{quest}\". A maré se lembra de quem ficou diante dela.",
    frFR = "La mer a son caractère, et j'y ai répondu\194\160: «\194\160{quest}\194\160». La marée se souvient de ceux qui se sont tenus devant elle.",
} }
local SILITHID = { tier = 4, text = {
    enUS = "Something stirs beneath the sands, and I followed it to the end: \"{quest}\". The silithid rise, and so do I.",
    ptBR = "Algo se agita sob as areias, e eu o segui até o fim: \"{quest}\". Os silitídeos se erguem, e eu também.",
    frFR = "Quelque chose remue sous les sables, et je l'ai suivi jusqu'au bout\194\160: «\194\160{quest}\194\160». Les silithides se lèvent, et moi aussi.",
} }
C[4267], C[32] = SILITHID, SILITHID
C[8446] = { tier = 4, text = {
    enUS = "A nightmare closed over me and I walked through it: \"{quest}\".",
    ptBR = "Um pesadelo se fechou sobre mim e eu o atravessei: \"{quest}\".",
    frFR = "Un cauchemar s'est refermé sur moi et je l'ai traversé\194\160: «\194\160{quest}\194\160».",
} }
C[8447] = { tier = 4, text = {
    enUS = "Legends do not wake on their own. \"{quest}\" is what it took.",
    ptBR = "As lendas não despertam sozinhas. \"{quest}\" foi o que custou.",
    frFR = "Les légendes ne s'éveillent pas seules. «\194\160{quest}\194\160» est ce qu'il a fallu.",
} }

-- Duskwood's long tales, and a king's audience (Rare) -----------------------
C[55] = { tier = 3, text = {
    enUS = "The shadow over Duskwood had a name, and the name was \"{quest}\". I followed it until there was nothing left to follow.",
    ptBR = "A sombra sobre Duskwood tinha um nome, e o nome era \"{quest}\". Segui-o até não haver mais nada a seguir.",
    frFR = "L'ombre sur le Bois de la Pénombre avait un nom, et ce nom était «\194\160{quest}\194\160». Je l'ai suivie jusqu'à ce qu'il n'y ait plus rien à suivre.",
} }
C[253] = { tier = 3, text = {
    enUS = "A grim tale reached its grim end: \"{quest}\". Duskwood keeps its secrets, but not this one.",
    ptBR = "Uma história sombria chegou ao seu sombrio fim: \"{quest}\". Duskwood guarda seus segredos, mas não este.",
    frFR = "Un sombre récit a atteint sa sombre fin\194\160: «\194\160{quest}\194\160». Le Bois de la Pénombre garde ses secrets, mais pas celui-ci.",
} }
C[98] = { tier = 3, text = {
    enUS = "The legend of Stalvan, told to its last word: \"{quest}\". Some stories wait in the dark for someone to finish them.",
    ptBR = "A lenda de Stalvan, contada até a última palavra: \"{quest}\". Algumas histórias esperam no escuro por alguém que as termine.",
    frFR = "La légende de Stalvan, racontée jusqu'à son dernier mot\194\160: «\194\160{quest}\194\160». Certaines histoires attendent dans le noir que quelqu'un les termine.",
} }
C[396] = { tier = 3, text = {
    enUS = "At the end of a long climb, an audience with a king: \"{quest}\".",
    ptBR = "No fim de uma longa subida, uma audiência com um rei: \"{quest}\".",
    frFR = "Au bout d'une longue ascension, une audience avec un roi\194\160: «\194\160{quest}\194\160».",
} }

-- Second batch: long chains at the top level, again told only from their names.
C[3628] = { tier = 4, text = {
    enUS = "A name earned in fire: \"{quest}\". I am not the one who began this road.",
    ptBR = "Um nome conquistado no fogo: \"{quest}\". Não sou a mesma pessoa que começou esta estrada.",
    frFR = "Un nom gagné dans le feu\194\160: «\194\160{quest}\194\160». Je ne suis plus celui qui a commencé cette route.",
} }
C[5466] = { tier = 4, text = {
    enUS = "The lich had a name and a cold hall, and I took the road to both: \"{quest}\".",
    ptBR = "O lich tinha um nome e um salão gelado, e tomei a estrada para os dois: \"{quest}\".",
    frFR = "Le liche avait un nom et une salle glacée, et j'ai pris la route vers les deux\194\160: «\194\160{quest}\194\160».",
} }
C[3962] = { tier = 4, text = {
    enUS = "\"{quest}\". Some warnings are worth heeding, and some gifts are worth taking. I did what the road asked.",
    ptBR = "\"{quest}\". Alguns avisos merecem ser ouvidos, e alguns presentes merecem ser aceitos. Fiz o que a estrada pediu.",
    frFR = "«\194\160{quest}\194\160». Certains avertissements valent d'être écoutés, et certains présents d'être acceptés. J'ai fait ce que la route demandait.",
} }

-- Third batch: written from what each quest asks and what the NPC says on the hand-in.
-- Eastern Plaguelands cauldrons: curated so the length of the chain does not make them legendary.
local CAULDRON = { tier = 3, text = {
    enUS = "Reagents in the mix, and the Scourge near it recoiled: \"{quest}\". One less source of the plague.",
    ptBR = "Reagentes na mistura, e o Flagelo ao redor recuou: \"{quest}\". Uma fonte a menos da praga.",
    frFR = "Des composants dans le mélange, et le Fléau s'est reculé devant\194\160: «\194\160{quest}\194\160». Une source de peste en moins.",
} }
for _, id in ipairs({ 5218, 5221, 5224, 5227 }) do C[id] = CAULDRON end

local MISSION_DONE = { tier = 4, text = {
    enUS = "Every cauldron I reworked now turns against the plague that made it: \"{quest}\". Won with reagents and patience, not only steel.",
    ptBR = "Cada caldeirão que refiz agora se volta contra a praga que o criou: \"{quest}\". Vencido com reagentes e paciência, e não só com aço.",
    frFR = "Chaque chaudron que j'ai remanié se retourne désormais contre la peste qui l'a fait naître\194\160: «\194\160{quest}\194\160». Gagné avec des composants et de la patience, pas seulement de l'acier.",
} }
C[5237], C[5238] = MISSION_DONE, MISSION_DONE

C[8182] = { tier = 4, text = {
    enUS = "Legend speaks of the Soulflayer ruling the old troll world through terror, and it may rise again: \"{quest}\" put a name on the threat.",
    ptBR = "A lenda fala de um ser que governou o antigo mundo troll pelo terror, e ele pode se erguer de novo: \"{quest}\" deu um nome à ameaça.",
    frFR = "La légende dit que l'Écorcheur d'âmes régnait sur l'ancien monde troll par la terreur, et qu'il pourrait revenir\194\160: «\194\160{quest}\194\160» a mis un nom sur la menace.",
} }
C[8730] = { tier = 4, text = {
    enUS = "Nefarian is slain and the shard goes back where it belongs: \"{quest}\". The Aspects themselves are watching what I do next.",
    ptBR = "Nefarian está morto e o fragmento volta ao lugar a que pertence: \"{quest}\". Os próprios Aspectos observam o que farei em seguida.",
    frFR = "Nefarian est mort et l'éclat retourne là où il doit être\194\160: «\194\160{quest}\194\160». Les Aspects eux-mêmes observent ce que je ferai ensuite.",
} }

C[5168] = { tier = 3, text = {
    enUS = "A libram and a shield, together again: \"{quest}\". The heroes of Darrowshire are remembered a little more.",
    ptBR = "Um libram e um escudo, juntos de novo: \"{quest}\". Os heróis de Darrowshire são lembrados um pouco mais.",
    frFR = "Un libram et un bouclier, de nouveau réunis\194\160: «\194\160{quest}\194\160». Les héros de Darrowshire sont un peu mieux rappelés.",
} }
C[5181] = { tier = 3, text = {
    enUS = "The skull of a ravager and the shattered sword of a traitor: \"{quest}\". Even villains belong in the annals of Darrowshire.",
    ptBR = "O crânio de um devastador e a espada partida de um traidor: \"{quest}\". Até os vilões têm lugar nos anais de Darrowshire.",
    frFR = "Le crâne d'un ravageur et l'épée brisée d'un traître\194\160: «\194\160{quest}\194\160». Même les infâmes ont leur place dans les annales de Darrowshire.",
} }
C[5242] = { tier = 3, text = {
    enUS = "The straight path down to the bottom, and a head to show for it: \"{quest}\". The Shadow Council will not forget this blow.",
    ptBR = "O caminho reto até o fundo, e uma cabeça como prova: \"{quest}\". O Conselho das Sombras não esquecerá este golpe.",
    frFR = "Le chemin direct jusqu'au fond, et une tête pour le prouver\194\160: «\194\160{quest}\194\160». Le Conseil des ténèbres n'oubliera pas ce coup.",
} }

local EYE = { tier = 4, text = {
    enUS = "Tales of my heroics travel far, and the honour is mine: \"{quest}\". Let the enemy hear it.",
    ptBR = "Contos dos meus feitos viajam longe, e a honra é minha: \"{quest}\". Que o inimigo ouça isso.",
    frFR = "Le récit de mes exploits voyage loin, et l'honneur est pour moi\194\160: «\194\160{quest}\194\160». Que l'ennemi l'entende.",
} }
C[7167], C[7172] = EYE, EYE
C[6187] = { tier = 4, text = {
    enUS = "I led an army against the man who was once Nathanos Marris, and order is restored: \"{quest}\". May his memory rest easier now.",
    ptBR = "Liderei um exército contra aquele que um dia foi Nathanos Marris, e a ordem foi restaurada: \"{quest}\". Que a memória dele descanse em paz agora.",
    frFR = "J'ai mené une armée contre l'homme qui fut autrefois Nathanos Marris, et l'ordre est rétabli\194\160: «\194\160{quest}\194\160». Que sa mémoire repose plus paisiblement.",
} }

C[8587] = { tier = 3, text = {
    enUS = "Five hundred pounds of chicken, carried across Azeroth: \"{quest}\". Not every legend is grim.",
    ptBR = "Mais de duzentos quilos de frango, levados por todo Azeroth: \"{quest}\". Nem toda lenda é sombria.",
    frFR = "Deux cent cinquante kilos de poulet, portés à travers Azeroth\194\160: «\194\160{quest}\194\160». Toutes les légendes ne sont pas sombres.",
} }
C[5121] = { tier = 3, text = {
    enUS = "The Winterfall furbolg were never a warlike people, until a strange substance changed them: \"{quest}\". Their High Chief is down, and the studies can resume.",
    ptBR = "Os furbolgs de Winterfall nunca foram um povo belicoso, até uma substância estranha mudá-los: \"{quest}\". O chefe deles caiu, e os estudos podem continuar.",
    frFR = "Les furbolgs Orfroide n'ont jamais été un peuple belliqueux, jusqu'à ce qu'une étrange substance les change\194\160: «\194\160{quest}\194\160». Leur grand chef est tombé, et les études peuvent reprendre.",
} }
C[1475] = { tier = 3, text = {
    enUS = "Ten tablets from a temple sunk beneath the water: \"{quest}\". An old dwarf's last obligation is kept.",
    ptBR = "Dez tábuas de um templo afundado sob a água: \"{quest}\". A última obrigação de um velho anão foi cumprida.",
    frFR = "Dix tablettes d'un temple englouti sous les eaux\194\160: «\194\160{quest}\194\160». La dernière obligation d'un vieux nain est tenue.",
} }
C[4786] = { tier = 3, text = {
    enUS = "A robe, and a warning with it: defy the corruption of this path with will alone. \"{quest}\".",
    ptBR = "Uma veste, e um aviso com ela: desafie a corrupção deste caminho só com vontade. \"{quest}\".",
    frFR = "Une robe, et un avertissement avec\194\160: défier la corruption de ce chemin par la seule volonté. «\194\160{quest}\194\160».",
} }
C[1958] = { tier = 3, text = {
    enUS = "Many have fallen to the creatures I faced, and I did not. The orb is ready: \"{quest}\".",
    ptBR = "Muitos caíram diante das criaturas que enfrentei, e eu não. O orbe está pronto: \"{quest}\".",
    frFR = "Beaucoup sont tombés devant les créatures que j'ai affrontées, et pas moi. L'orbe est prêt\194\160: «\194\160{quest}\194\160».",
} }
C[667] = { tier = 3, text = {
    enUS = "We held the line against the naga until the tide rose: \"{quest}\". A captain offered me a place on his crew; the road had other plans.",
    ptBR = "Seguramos a linha contra os nagas até a maré subir: \"{quest}\". Um capitão me ofereceu um lugar na tripulação; a estrada tinha outros planos.",
    frFR = "Nous avons tenu la ligne contre les nagas jusqu'à la montée de la marée\194\160: «\194\160{quest}\194\160». Un capitaine m'a offert une place dans son équipage\194\160; la route avait d'autres plans.",
} }

ns.CURATED = C
