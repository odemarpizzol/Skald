# Lotes 5 e 6 dos mapas: prompts prontos para colar no Codex

Cada bloco abaixo é **autocontido**: cole um por vez (primeiro o lote 5, depois o 6). Anexe, nos dois, a folha `output/map-art/contact-sheet.jpg` (as 28 que já existem, como referência de acabamento).

O Codex já integrou as levas anteriores sozinho. Os blocos pedem o mesmo: desenhar, converter, ligar em `ZoneCard.lua` e rodar as verificações. O prompt completo de cada zona também está em `dev/PROMPT_ARTE_mapas_2.md` (lotes 5 e 6).

---

## LOTE 5 (14 mapas, níveis 40 a 60)

```
Continue o trabalho dos mapas do Índice do Skald (addon de World of Warcraft). Já existem 28 mapas desenhados (veja a folha de contato anexa); faça os 14 mapas do lote 5, no MESMO estilo, paleta e nível de acabamento daqueles.

ESTILO (igual aos já feitos): gravura de mapa antigo em tinta marrom escura com hachuras finas e relevo desenhado à mão (montinhos de montanha, copas de árvore), com lavados de aquarela leves por tipo de terreno; luz do alto à esquerda; SEM nenhum texto, letra ou número (pode haver pequenos desenhos de construções); sem moldura: as bordas se dissolvem até o transparente, com cerca de 6% de folga; fundo transparente. Zonas vizinhas parecidas devem se diferenciar pela paleta e pelo clima. A geografia usa o mapa oficial da zona SÓ como referência de posição (costa, rios, montanhas, estradas); redesenhe tudo no nosso traço, sem decalcar.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px (revisão também em 2048 x 1024; coloque em output/map-art/1024 e output/map-art/2048).

AS 14 ZONAS (arquivo | zona | ID do mapa | caráter):
- map_stranglethorn | Stranglethorn Vale | 1434 | selva densa e enorme, ruínas trolls cobertas de cipó, baías e vilas de piratas na costa, uma montanha ao centro
- map_tanaris | Tanaris | 1446 | deserto de dunas, ruínas antigas, uma cidade-porto de goblins na costa, um oásis, rochas
- map_ungoro | Un'Goro Crater | 1449 | uma cratera fechada de selva, dinossauros pequenos desenhados, cristais coloridos, um gêiser e um vulcão
- map_azshara | Azshara | 1447 | costa de ruínas élficas antigas, estátuas gigantes caídas, penhascos sobre o mar, bosques violeta
- map_felwood | Felwood | 1448 | floresta corrompida, árvores retorcidas e doentes em verde-enfermo, poças tóxicas, névoa amarela
- map_winterspring | Winterspring | 1452 | montanhas nevadas, um lago congelado, tempestade de neve, uma vila pequena de lenhadores
- map_silithus | Silithus | 1451 | deserto de areia clara, colmeias de insetos gigantes, cristais, uma estrutura de pedra antiga ao fundo
- map_moonglade | Moonglade | 1450 | um pequeno vale sagrado, um lago com reflexo de lua, um templo de pedra e árvores muito antigas
- map_searinggorge | Searing Gorge | 1427 | garganta vulcânica, forjas fumegantes, rios de lava estreitos, paredes de rocha negra
- map_burningsteppes | Burning Steppes | 1428 | estepe vulcânica, cinzas, fortalezas de pedra negra, rios de lava, céu enfumaçado
- map_blastedlands | Blasted Lands | 1419 | terra devastada em vermelho, um portal escuro ao sul, cristais demoníacos, uma cicatriz no chão, torres arruinadas
- map_deadwind | Deadwind Pass | 1430 | uma passagem estreita e escura entre montanhas, uma torre assombrada, árvores secas e névoa
- map_westernplague | Western Plaguelands | 1422 | campos arruinados e mortos, fazendas abandonadas, torres, uma névoa esverdeada
- map_easternplague | Eastern Plaguelands | 1423 | terras pútridas, uma igreja com cripta, uma cidade queimada, lagos de peste, árvores mortas

DEPOIS DE DESENHAR (faça você mesmo, como nas levas anteriores):
1. Converta cada PNG em TGA 32 bits SEM compressão (tipo 2), 512 x 256, em Textures/skald2/map_<zona>.tga. NÃO deixe PNG dentro de Textures/ (só os TGAs; os PNGs ficam em output/map-art).
2. Em ZoneCard.lua, tabela ZC.ART, acrescente [<ID>] = "map_<zona>" para cada uma.
3. Acrescente uma regressão em dev/tools/regressions.js no mesmo formato da de "middle-zone maps" (cada ID resolve para a sua arte). Os testes do mapa do jogo usam o mapa 99999 (que nunca terá arte); não os mude.
4. Rode node dev/tools/checks.js e me diga o resultado.
5. Atualize a folha de contato em output/map-art/contact-sheet.jpg com as novas.
```

---

## LOTE 6 (10 mapas, Burning Crusade; só valem no cliente do Anniversary)

```
Continue o trabalho dos mapas do Índice do Skald (addon de World of Warcraft). Já existem os mapas dos lotes anteriores (veja a folha de contato anexa; inclui Eversong Woods e Azuremyst Isle, que são do Burning Crusade); faça os 10 mapas do lote 6 (zonas de Outland e do TBC), no MESMO estilo, paleta e nível de acabamento daqueles.

ESTILO (igual aos já feitos): gravura de mapa antigo em tinta marrom escura com hachuras finas e relevo desenhado à mão (montinhos de montanha, copas de árvore), com lavados de aquarela leves por tipo de terreno; luz do alto à esquerda; SEM nenhum texto, letra ou número (pode haver pequenos desenhos de construções); sem moldura: as bordas se dissolvem até o transparente, com cerca de 6% de folga; fundo transparente. As zonas de Outland podem ter céu e luz mais estranhos (roxos, verdes luminosos), mas SEMPRE dessaturados e na mesma gravura, para combinar com o livro. A geografia usa o mapa oficial da zona SÓ como referência de posição; redesenhe tudo no nosso traço, sem decalcar.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px (revisão também em 2048 x 1024; coloque em output/map-art/1024 e output/map-art/2048).

AS 10 ZONAS (arquivo | zona | ID do mapa | caráter):
- map_ghostlands | Ghostlands | 1942 | floresta dourada morta dos elfos sangrentos, torres de cristal escurecidas, neblina de praga, lago pálido
- map_bloodmyst | Bloodmyst Isle | 1950 | uma ilha com cristais e mato em vermelho-sangue, a costa, uma estrutura caída de nave
- map_quel_danas | Isle of Quel'Danas | 1957 | uma ilha pequena, templo dourado no centro, um portal em arco, a costa
- map_hellfire | Hellfire Peninsula | 1944 | deserto vermelho de rocha, um portal escuro, fortalezas de pedra e metal, crateras
- map_zangarmarsh | Zangarmarsh | 1946 | pântano de cogumelos gigantes luminosos, lagos azul-turquesa, ilhas de juncos
- map_terokkar | Terokkar Forest | 1952 | floresta de árvores doentes, torres de pedra e uma cidade em ruína ao centro, trilhas
- map_nagrand | Nagrand | 1951 | pradarias verdes e douradas, ilhas de pedra flutuantes, cachoeiras, mesas ao longe
- map_bladesedge | Blade's Edge Mountains | 1949 | picos pontiagudos e agulhas de pedra, vales abertos, plataformas de pedra, ossos gigantes
- map_netherstorm | Netherstorm | 1953 | terra quebrada em ilhas flutuantes, estruturas de energia roxa, cristais, céu estrelado
- map_shadowmoon | Shadowmoon Valley | 1948 | vale vulcânico e escuro, uma lua grande no céu, uma fortaleza, rios de brilho verde

DEPOIS DE DESENHAR (faça você mesmo, como nas levas anteriores):
1. Converta cada PNG em TGA 32 bits SEM compressão (tipo 2), 512 x 256, em Textures/skald2/map_<zona>.tga. NÃO deixe PNG dentro de Textures/.
2. Em ZoneCard.lua, tabela ZC.ART, acrescente [<ID>] = "map_<zona>" para cada uma.
3. Acrescente uma regressão em dev/tools/regressions.js no mesmo formato da de "middle-zone maps". Os testes do mapa do jogo usam o mapa 99999; não os mude.
4. Rode node dev/tools/checks.js e me diga o resultado.
5. Atualize a folha de contato em output/map-art/contact-sheet.jpg com as novas.
```

---

## Depois que o Codex terminar (para quem for revisar)

- Conferir se sobrou algum PNG em `Textures/` (apagar) e se o `checks.js` passa.
- **Os IDs:** em cada cliente, `/skald probe maps` lista os desenhados com o nome que o jogo dá a cada número; um número errado aparece como outra zona ou "?". Para o Forever, os números podem ser outros (o cartão cai no mapa do jogo esmaecido nesse caso; nada quebra).
- As texturas novas só aparecem depois de **reiniciar o jogo por completo**.
- Peso: com os 24 mapas, o pacote compactado fica perto de 20 MB (hoje 14,3 MB).
