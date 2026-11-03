# Mapas das capitais (Classic e TBC): prompt pronto para colar no Codex

Um bloco autocontido, 9 mapas. Anexe `output/map-art/contact-sheet.jpg` (os mapas de zona e de instância que já existem, como referência de acabamento).

**Diferença para os lotes de zona:** são cidades, então o desenho é uma **planta de cidade vista do alto**, não um terreno. **Diferença para as instâncias:** aqui os mapas entram direto em `ZC.ART` (a chave é o ID do mapa do jogo), porque o cartão do Índice já mostra uma capital quando o jogador está nela. Os IDs vêm de memória: confira no jogo com `/skald probe maps` dentro de cada cidade (um ID errado aparece como outra zona ou "?").

Booty Bay, Gadgetzan e Ratchet ficam de fora: não têm mapa próprio no jogo, são pontos dentro de Stranglethorn, Tanaris e Barrens.

```
Continue o trabalho dos mapas do Índice do Skald (addon de World of Warcraft). Já existem os mapas de zona e de instância (veja a folha de contato anexa). Agora faça os 9 mapas das CAPITAIS, no MESMO estilo, paleta e nível de acabamento daqueles.

ESTILO: gravura de mapa antigo em tinta marrom escura com hachuras finas e lavados de aquarela leves; luz do alto à esquerda; SEM nenhum texto, letra ou número; sem moldura: as bordas se dissolvem até o transparente, com cerca de 6% de folga; fundo transparente. Cada cidade deve ser reconhecível de relance pela forma e pela paleta.

COMO DESENHAR UMA CIDADE: uma PLANTA vista do alto, em leve perspectiva, como o mapa de uma cidade desenhado à mão: muralhas, ruas, praças, canais, pontes, torres e telhados desenhados em tinta e lavado, com o terreno em volta esmaecendo até o transparente. Pequenos desenhos (fontes, estátuas, bandeiras sem letras, barcos, tendas) dão vida. Use o mapa oficial da cidade SÓ como referência da disposição geral e redesenhe tudo no nosso traço, sem decalcar.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px (revisão também em 2048 x 1024; coloque em output/map-art/1024 e output/map-art/2048).

AS 9 CAPITAIS (arquivo | cidade | ID do mapa | caráter):
- map_stormwind | Stormwind City | 1453 | cidade humana de pedra clara, muralhas altas, um grande castelo ao norte, canais e um porto a leste, a catedral, bairros de casas com telhados azuis e ardósia, um vale de pontes
- map_ironforge | Ironforge | 1455 | cidade anã dentro da montanha, uma grande forja central com lava, salões redondos e pontes de pedra, a entrada em arco, túneis, tons de pedra cinza e brasa
- map_darnassus | Darnassus | 1457 | cidade élfica em copas de árvores gigantes, plataformas e pontes de madeira clara, um templo da lua, lagos e arcos, tons violeta e prata
- map_exodar | The Exodar | 1947 | uma nave cristalina caída, estruturas curvas azul-acinzentadas e cristais, pátios luminosos mas dessaturados, uma passarela central (só vale no TBC)
- map_orgrimmar | Orgrimmar | 1454 | fortaleza orc de pedra vermelha e ferro dentro de um desfiladeiro, portões com presas, uma muralha de espinhos, vales internos, bairros de tendas e fornalhas, tons de ocre e vermelho
- map_thunderbluff | Thunder Bluff | 1456 | cidade tauren sobre mesas altas ligadas por pontes de corda, tendas e totens, plataformas redondas, uma grande mesa central, tons de ouro e terra
- map_undercity | Undercity | 1458 | cidade de morto-vivos em esgotos e câmaras subterrâneas, abóbadas de pedra, um anel de salões, poços de praga verde-doente, tons de verde e roxo apagados
- map_silvermoon | Silvermoon City | 1954 | cidade dos elfos sangrentos de pedra clara e telhados vermelhos e dourados, uma praça central, torres de cristal, arcos e jardins, uma fonte de energia dourada no centro (só vale no TBC)
- map_shattrath | Shattrath City | 1955 | uma cidade de refugiados em um planalto, praças e terraços em degraus, um grande terraço central de luz, tendas e prédios de pedra, tons quentes e dessaturados (só vale no TBC)

DEPOIS DE DESENHAR (faça você mesmo, como nas levas de zona):
1. Converta cada PNG em TGA 32 bits SEM compressão (tipo 2), 512 x 256, em Textures/skald2/map_<nome>.tga. NÃO deixe PNG dentro de Textures/.
2. Em ZoneCard.lua, tabela ZC.ART, acrescente [<ID>] = "map_<nome>" para cada uma.
3. Acrescente uma regressão em dev/tools/regressions.js no mesmo formato da de "middle-zone maps" (cada ID resolve para a sua arte). Os testes do mapa do jogo usam o mapa 99999 (que nunca terá arte); não os mude.
4. Rode node dev/tools/checks.js e me diga o resultado.
5. Atualize a folha de contato em output/map-art/contact-sheet.jpg (as cidades em uma seção à parte).
```

---

## Depois que o Codex terminar (eu faço)

- Conferir se sobrou PNG em `Textures/` e rodar `checks.js`.
- **IDs:** em cada cidade, `/skald probe maps` mostra o número do mapa onde você está e, para cada desenhado, o nome que o jogo dá a ele. Os mais incertos são os do TBC (Exodar 1947, Silvermoon 1954, Shattrath 1955); os do Classic são bem conhecidos. Um ID errado só faz o cartão cair no mapa do jogo, nada quebra.
- Peso: ~+5 MB no addon e ~+1,7 MB no pacote.
