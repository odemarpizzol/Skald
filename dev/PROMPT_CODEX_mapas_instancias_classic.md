# Mapas de masmorras, raides e campos de batalha (Classic): prompts prontos para colar no Codex

Dois blocos autocontidos: o **A** (4 campos de batalha + 19 masmorras = 23 mapas) e o **B** (7 raides do Classic). Cole um de cada vez e anexe nos dois a folha `output/map-art/contact-sheet.jpg` (os 52 mapas de zona que já existem, como referência de acabamento).

**A diferença para os mapas de zona:** o cartão do Índice ainda **não sabe mostrar** uma instância (ele só mostra zonas). Eu ligo isso depois de validar no jogo o que o cliente informa dentro de uma masmorra. Por isso estes blocos pedem **só a arte, os TGAs e uma tabela por ID de instância**, sem mexer no comportamento do cartão.

**A chave** não é o número de mapa do jogo, e sim o **ID da instância** (o 8º valor de `GetInstanceInfo`), que é o mesmo em todo cliente. Os IDs abaixo vêm do Classic; `/skald probe maps` dentro da masmorra mostra o ID real para conferir.

---

## BLOCO A: 4 campos de batalha + 19 masmorras

```
Continue o trabalho dos mapas do Skald (addon de World of Warcraft). Já existem 52 mapas de zona desenhados (veja a folha de contato anexa). Agora faça os mapas de INSTÂNCIAS: 4 campos de batalha e 19 masmorras do Classic, no MESMO estilo, paleta e nível de acabamento daqueles.

ESTILO: gravura de mapa antigo em tinta marrom escura com hachuras finas e lavados de aquarela leves; luz do alto à esquerda; SEM nenhum texto, letra ou número; sem moldura (as bordas se dissolvem até o transparente, com cerca de 6% de folga); fundo transparente.

COMO DESENHAR UMA INSTÂNCIA (é diferente de uma zona): uma PLANTA vista de cima, como um mapa de masmorra desenhado à mão. As salas, os corredores e os caminhos aparecem em corte, na tinta e no lavado, com a rocha, a água ou o terreno em volta esmaecendo até o transparente. Pequenos desenhos de móveis, colunas, pontes, portões e braseiros dão vida. Nada de rótulos. Nos campos de batalha: uma planta do campo inteiro como um plano de batalha antigo, com as duas bases em pontas opostas marcadas por duas pequenas bandeiras de cor diferente e discreta (azul-acinzentado e vermelho-ocre), sem letras.
A geografia usa o mapa oficial da instância SÓ como referência da disposição geral; redesenhe tudo no nosso traço, sem decalcar.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px (revisão também em 2048 x 1024; coloque em output/map-art/1024 e output/map-art/2048).

AS 23 INSTÂNCIAS (arquivo | instância | ID | caráter):
CAMPOS DE BATALHA
- map_warsong | Warsong Gulch | 489 | um desfiladeiro florestal comprido, uma base em cada ponta, rio no meio, florestas e rochas
- map_arathibasin | Arathi Basin | 529 | um vale com cinco pontos de controle espalhados (uma fazenda, um moinho de ferreiro, uma mina, uma estábulo, um acampamento), duas bases nas pontas
- map_alterac_valley | Alterac Valley | 30 | um vale nevado e muito comprido, montanhas dos dois lados, um forte em cada ponta, pontes e torres no meio
- map_eyestorm | Eye of the Storm | 566 | uma ilha-plataforma flutuante em céu de tempestade com quatro torres nos cantos e uma base ao centro (só vale no TBC)
MASMORRAS
- map_ragefire | Ragefire Chasm | 389 | cavernas de lava sob uma cidade de pedra, túneis estreitos e rios de fogo
- map_deadmines | The Deadmines | 36 | túneis de mina de madeira, trilhos de carrinho, uma fundição goblin, uma doca com um navio no fim
- map_wailingcaverns | Wailing Caverns | 43 | cavernas tortuosas em espiral, raízes e lodo verde, poças, serpentes gigantes ao fundo
- map_shadowfang | Shadowfang Keep | 33 | um castelo gótico sobre uma colina, pátios, torres, salões e uma ala de masmorra, névoa
- map_blackfathom | Blackfathom Deeps | 48 | ruínas élficas submersas, túneis de água, um templo de pedra com um altar azul
- map_stockade | The Stockade | 34 | uma prisão de pedra, celas em duas fileiras, um canal de água no meio, pátios
- map_gnomeregan | Gnomeregan | 90 | uma cidade gnômica tecnológica, canos, engrenagens, um reator, tubos irradiados em verde-doente
- map_razorfenkraul | Razorfen Kraul | 47 | uma toca de espinheiros e vinhas grossas, túneis de espinhos, câmaras de barro
- map_scarletmonastery | Scarlet Monastery | 189 | um mosteiro de pedra clara com telhados vermelhos, cemitério, biblioteca, arsenal e catedral em alas ligadas por pátios
- map_razorfendowns | Razorfen Downs | 129 | uma toca de ossos e espinhos em pântano, câmaras escuras com ossos empilhados
- map_uldaman | Uldaman | 70 | ruínas de pedra de titãs em cavernas de deserto, escavações de anões, câmaras de relíquias
- map_zulfarrak | Zul'Farrak | 209 | uma cidade de trolls no deserto, uma pirâmide escalonada no centro, ruas, tendas
- map_maraudon | Maraudon | 349 | cavernas de centauros, cristais roxos brilhantes e flora luminosa, duas vias que se juntam
- map_sunkentemple | Temple of Atal'Hakkar | 109 | um templo de pântano em degraus (zigurate), câmaras empilhadas, estátuas de dragão verde
- map_blackrockdepths | Blackrock Depths | 230 | uma cidade anã de rocha negra e lava, salões, uma arena redonda, pontes sobre lava
- map_blackrockspire | Blackrock Spire | 229 | uma fortaleza de orcs dentro da montanha, escadarias, salões altos, uma grande câmara no topo
- map_stratholme | Stratholme | 329 | uma cidade murada em ruínas queimadas, praças, a praga em névoa verde, um portão grande
- map_scholomance | Scholomance | 289 | uma escola de necromancia com cripta, salas de aula, um laboratório, corredores em cruz
- map_diremaul | Dire Maul | 429 | ruínas élficas tomadas por plantas, três alas (jardins, salões, um pátio), arcos e estátuas

DEPOIS DE DESENHAR (faça você mesmo):
1. Converta cada PNG em TGA 32 bits SEM compressão (tipo 2), 512 x 256, em Textures/skald2/map_<nome>.tga. NÃO deixe PNG dentro de Textures/.
2. Em ZoneCard.lua, crie uma tabela separada ZC.INSTANCE_ART = { [<ID da instância>] = "map_<nome>", ... } com as 23. Ela fica SEM USO por enquanto (eu ligo a lógica depois). Não mexa em ZC.ART, em ZC.Build, em ZC.CurrentMap nem em nenhum teste existente.
3. Acrescente UMA regressão em dev/tools/regressions.js que confira que todo nome citado em ZC.INSTANCE_ART tem o seu TGA em Textures/skald2.
4. Rode node dev/tools/checks.js e me diga o resultado.
5. Atualize a folha de contato em output/map-art/contact-sheet.jpg com as novas (as de instância em uma seção à parte).
```

---

## BLOCO B: 7 raides do Classic

```
Continue o trabalho dos mapas do Skald (addon de World of Warcraft). Já existem os mapas de zona e os de masmorra e campo de batalha (folha de contato anexa). Agora faça os 7 mapas das RAIDES do Classic, no MESMO estilo, paleta e acabamento, e com o mesmo jeito de desenhar uma instância: uma PLANTA vista de cima, como um mapa de masmorra desenhado à mão, com salas, corredores e câmaras em corte e a rocha em volta esmaecendo até o transparente. SEM nenhum texto; sem moldura; fundo transparente; 6% de folga; luz do alto à esquerda. Use o mapa oficial só como referência da disposição geral e redesenhe no nosso traço, sem decalcar.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px (revisão também em 2048 x 1024; em output/map-art/1024 e output/map-art/2048).

AS 7 RAIDES (arquivo | instância | ID | caráter):
- map_moltencore | Molten Core | 409 | uma caverna vulcânica enorme de lava e basalto, uma sequência de salões e pontes, um lago de fogo no fim
- map_onyxia | Onyxia's Lair | 249 | uma caverna de dragão, câmaras de ovos e uma grande câmara final, ossos e ouro
- map_blackwinglair | Blackwing Lair | 469 | uma fortaleza escura dentro da montanha, salões de pedra negra, ninhos, laboratórios, uma câmara alta final
- map_zulgurub | Zul'Gurub | 309 | uma cidade troll na selva, plataformas, templos e lagos, uma escadaria até a arena do deus
- map_ruinsahnqiraj | Ruins of Ahn'Qiraj | 509 | ruínas de insetos no deserto, câmaras de areia e resina, um grande salão
- map_templeahnqiraj | Temple of Ahn'Qiraj | 531 | um templo enorme de insetos, câmaras de casulos, corredores de ressina, uma câmara final com um olho
- map_naxxramas | Naxxramas | 533 | uma cidadela flutuante com quatro alas ligadas ao centro (aranha, praga, militar, construtos) e uma câmara de gelo no alto

DEPOIS DE DESENHAR (faça você mesmo):
1. Converta cada PNG em TGA 32 bits SEM compressão (tipo 2), 512 x 256, em Textures/skald2/map_<nome>.tga. NÃO deixe PNG dentro de Textures/.
2. Acrescente as 7 entradas à tabela ZC.INSTANCE_ART em ZoneCard.lua (a que o bloco A criou), sem ligar nada. Não mexa em ZC.ART, em ZC.Build, em ZC.CurrentMap nem em testes existentes.
3. Estenda a regressão do bloco A para conferir também estas.
4. Rode node dev/tools/checks.js e me diga o resultado.
5. Atualize a folha de contato.
```

---

## O que vem depois (eu faço, quando os IDs estiverem confirmados no jogo)

1. Ligar o cartão do Índice a `ZC.INSTANCE_ART`: dentro de uma instância (ou se a última página for de uma), mostrar o mapa dela com linhas próprias (chefes derrotados, quedas, vezes que entrou).
2. Mostrar o mapa do campo de batalha na página da partida.
3. Avaliar a aba "Profundezas" (um mapa por instância visitada).
4. Masmorras e raides do TBC (mais ~25 peças) e as arenas, só se a gente decidir registrar partidas de arena.

**Peso:** os 30 mapas destes dois blocos somam ~15 MB no addon e ~+5 MB no pacote compactado (hoje 20,2 MB).
