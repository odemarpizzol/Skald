# Prompt de arte: o mapa da zona no Índice

Hoje o cartão da página direita do Índice mostra o mapa do próprio jogo (as peças do mapa, em sépia). Funciona para qualquer zona, mas o desenho é do jogo e destoa do livro. O plano é **híbrido**:

1. **Peças nossas** que enfeitam o cartão de **qualquer** zona (cantos e rosa dos ventos). Seção A.
2. **Um mapa desenhado por nós** das zonas iniciais das raças. Onde existir, ele toma o lugar do mapa do jogo; nas outras zonas fica o mapa do jogo, esmaecido no pergaminho. Seção B.

Anexe como referência, em todas as peças: `Textures/skald2/dd_map.tga` (o rabisco de mapa que já existe no livro), `Textures/skald2/rule.tga` e `Textures/skald2/ui_corner_l.tga` (o canto da página), e um **print do Índice** (o pergaminho e o couro em volta do cartão). Aponte também para as ilustrações dos ícones de página (`Textures/ev_*.tga`) como o "nível de acabamento" esperado.

---

## O estilo (vale para tudo)

- **Gravura de mapa antigo, em tinta e aguada:** linhas de tinta marrom escura (quase preta) com hachuras finas e relevo desenhado em perspectiva baixa (montanhas e árvores como "montinhos" desenhados à mão), e lavados de aquarela **muito leves** por cima.
- **Paleta:** tinta marrom escura; lavados de **sépia e ocre** como base; só um toque suave de cor por tipo de terreno (verde-acinzentado nas florestas, azul-acinzentado nos lagos e no mar, ocre-avermelhado nos desertos, branco-azulado nas neves), sempre dessaturado, para não brigar com o pergaminho do livro.
- **Luz:** a mesma dos ícones do livro, vinda do alto à esquerda, com sombra suave à direita e embaixo do relevo.
- **Sem texto.** Nenhuma letra, nome, número ou legenda no desenho: o nome da zona e os rótulos vêm do jogo, em cada idioma. Pode haver **pequenos desenhos** de construções (torre, vila, ponte, acampamento) sem letras.
- **Bordas que se dissolvem:** o desenho não tem moldura. Nas bordas a tinta e os lavados vão sumindo até o **transparente**, como um mapa desenhado direto na página. O fundo fora do desenho é **transparente** (PNG com alfa).
- Nada encostando na borda do canvas: cerca de **6% de folga** em cada lado.

---

## A. Peças que enfeitam qualquer mapa

### A1. Canto (`map_corner`)
**Um canto** de moldura de mapa antigo: duas linhas de tinta finas e paralelas saindo do canto, com um pequeno arabesco de ouro velho e uma folha, no mesmo acabamento das pontas de página (`ui_corner_l`). Eu giro o desenho para fazer os quatro cantos, então ele deve ser o **canto superior esquerdo**, com as linhas saindo para a direita e para baixo.

Formato: PNG com fundo transparente, **128 x 128 px**, o desenho ocupando no máximo 88% da área. Mande também uma versão de **512 x 512 px**.
Nome: `map_corner.png`.

### A2. Rosa dos ventos (`map_compass`)
Uma **rosa dos ventos** pequena e elegante, em tinta marrom e ouro velho, com a ponta norte (para cima) mais marcada, uma fleur-de-lis ou uma pequena seta. Sem a letra N ou qualquer letra. Sem círculo de fundo.

Formato: PNG com fundo transparente, **128 x 128 px**, o desenho ocupando no máximo 84% da área. Mande também uma versão de **512 x 512 px**.
Nome: `map_compass.png`.

---

## B. Os mapas das zonas iniciais (8 peças)

Para **cada zona** abaixo, um mapa no estilo acima, em **proporção 2:1**.

**Geografia:** use o **mapa oficial da zona como referência só para a posição** da costa, dos rios, lagos, montanhas e estradas principais, e **redesenhe tudo no nosso estilo**. Não decalque nem copie o desenho da Blizzard: a forma geral e a disposição devem ser reconhecíveis, o traço e a pintura são nossos.

**Formato:** PNG com fundo transparente, **1024 x 512 px**. Mande também uma versão de **2048 x 1024 px** para conferir os detalhes.

| Arquivo | Zona (nome em inglês, como no jogo) | Quem começa ali | Caráter do desenho |
|---|---|---|---|
| `map_elwynn.png` | Elwynn Forest | Humano | Colinas verdes suaves, fazendas e vinhedos, um rio, lagos, a cidade de pedra ao norte, o vale da abadia no canto noroeste |
| `map_dunmorogh.png` | Dun Morogh | Anão e Gnomo | Montanhas nevadas, vales cobertos de neve, a cidade da montanha ao norte, o vale inicial a oeste, o lago congelado |
| `map_teldrassil.png` | Teldrassil | Elfo Noturno | Uma ilha-árvore: um tronco imenso, galhos largos e clareiras sob um crepúsculo violeta, a costa ao redor |
| `map_durotar.png` | Durotar | Orc e Troll | Deserto vermelho rochoso, desfiladeiros, a fortaleza de pedra a noroeste, o vale inicial a sudoeste, a aldeia da costa a sudeste e as ilhas ao largo |
| `map_mulgore.png` | Mulgore | Tauren | Pradarias douradas, mesas e platôs altos com pontes, tendas e totens, um rio |
| `map_tirisfal.png` | Tirisfal Glades | Morto-vivo | Floresta escura e torta, névoa, cemitérios, as ruínas de uma capital no centro, um lago |
| `map_eversong.png` | Eversong Woods | Elfo Sangrento (TBC) | Floresta dourada de outono, torres de cristal e arcos élficos, uma ilha ao nordeste |
| `map_azuremyst.png` | Azuremyst Isle | Draenei (TBC) | Uma ilha com cristais azuis, os restos de uma nave caída num dos lados, bosques claros, a costa |

As duas últimas só valem para o cliente do Anniversary (TBC). Se a primeira leva for grande, comece pelas seis primeiras. O Skyborne (Forever) fica para depois do dia 04, quando a gente souber a ilha.

Nome dos arquivos: exatamente os da tabela, em minúsculas.

---

## Depois que os PNGs chegarem

1. Converter para TGA 32 bits **sem compressão** (tipo 2, como os outros do addon), potência de 2, em `Textures/skald2/`: `map_corner.tga` e `map_compass.tga` (128 x 128), e `map_<zona>.tga` (512 x 256; o de 1024 x 512 pesa 2 MB por zona, o que não vale a pena).
2. `ZoneCard.lua`: uma tabela `ZC.ART = { [mapID] = "map_<zona>" }` para as zonas com desenho (a chave é o número do mapa: Elwynn 1429, Dun Morogh 1426, Durotar 1411, Mulgore 1412, Teldrassil 1438, Tirisfal 1420, Eversong 1941, Azuremyst 1943; confere no jogo antes de publicar). Onde houver arte, o cartão usa a imagem no lugar das peças do jogo; onde não houver, fica o mapa do jogo esmaecido. Os quatro cantos e a rosa dos ventos entram nos dois casos.
3. Rodar `node dev/tools/checks.js` (ele confere se cada textura citada existe).
4. Textura nova só aparece depois de **reiniciar o jogo por completo**, não com `/reload`.
5. Uma observação de projeto: com um mapa desenhado, o cartão deixa de mostrar **as regiões descobertas** sobre o mapa (a arte é uma só). Elas continuam na linha "Regiões descobertas" do cartão.
