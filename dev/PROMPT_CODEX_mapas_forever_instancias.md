# Mapas das masmorras novas do Forever: prompt pronto para o Codex

Corrigido com a lista oficial da Blizzard (via `dev/MAPAS_INSTANCIAS_PENDENTES.md`): o Forever traz 9 masmorras novas e duas raides novas. O Salão dos Thanes já está pronto. Demon Fall Canyon, Karazhan Crypts e Enclave Escarlate aparecem na lista do Spoken, mas não são do anúncio do Forever, então ficam de fora.

## Lote 1: IDs já conhecidos (a lista do Spoken traz o ID)
| Arquivo | Instância | Nível | ID |
|---|---|---|---|
| map_ruins_lordaeron | Ruins of Lordaeron | 15-20 | 2999 |
| map_excavation_wetlands | Excavation Site: Wetlands | 24-29 | 2998 |
| map_dalaran | City of Dalaran (masmorra) | 28-33 | 2959 |

## Lote 2: IDs lidos da tabela Map do Wago (build 1.60.1.70862, a do jogo)
| Arquivo | Instância (pt-BR do jogo) | Nível | ID de instância |
|---|---|---|---|
| map_drowned_city | The Drowned City (A Cidade Afogada) | 35-40 | 2970 |
| map_kroldok | Krol'dok Stronghold (Fortaleza de Krol'Dok) | 40-45 | 3039 |
| map_alcaz_prison | Alcaz Prison (Prisão de Alcaz) | 48-53 | 2994 |
| map_blackmaw_hold | Blackmaw Hold (Gruta Bocanera) | 55-60 | 2974 |
| map_shapers_terrace | The Shaper's Terrace (O Terraço do Moldador) | 58-60 | 3001 |

Os IDs do lote 1 (2999, 2998, 2959) e o do Salão (3065) batem com a mesma tabela. Hyjal Summit e Barrow Deeps ainda não estão na build (abrem em 9/12).

Mesmo prompt do lote 1 (bloco abaixo), trocando a lista das instâncias pelas 5 acima e "faça 3 novas" por "faça 5 novas". Use uma referência real da planta de cada uma, como fez nas outras; não invente salas só pela descrição.

**Antes de colar:** as descrições abaixo vêm só dos nomes e do que se sabe da região, então corrija o "caráter" de cada uma se você já viu o interior.

**Anexe:** `Textures/skald2/map_hall_of_thanes.tga` (convertido para PNG) e duas ou três plantas existentes (por exemplo Scholomance e Sunken Temple) como referência exata de acabamento.

```
Continue os mapas de instância do Skald (addon de World of Warcraft). Anexei as plantas que já existem: faça 3 novas no MESMO estilo, paleta e acabamento delas.

ESTILO: PLANTA vista de cima, como um mapa de masmorra desenhado à mão. Salas, corredores e câmaras aparecem em corte, em tinta marrom escura com hachuras finas e lavados leves de aquarela; luz do alto à esquerda. A rocha, a água ou o terreno em volta esmaecem até o transparente. Pequenos desenhos de colunas, pontes, portões, braseiros e móveis dão vida. SEM nenhum texto, letra ou número; sem moldura.

FUNDO (importante): ALFA REAL. Fora da planta, o fundo é totalmente transparente: nada de branco, papel, mancha, sombra quadrada ou degradê de fundo. As bordas da planta se dissolvem até o transparente. Deixe cerca de 6% de folga nas bordas, para nada encostar na margem. A planta fica centralizada.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px. Salve em output/forever-art/ com o nome do arquivo abaixo.

AS 3 INSTÂNCIAS (arquivo | instância | caráter):
- map_excavation_wetlands | Excavation Site: Wetlands | um sítio de escavação em terreno de pântano: valas e túneis escavados, andaimes e escoras de madeira, trilhos de carrinho, câmaras de relíquias, poças de lama
- map_dalaran | City of Dalaran | uma cidade de magos: praças, torres, bibliotecas e salões ligados por ruas e pátios (confirme com uma referência real da planta antes de desenhar)
- map_ruins_lordaeron | Ruins of Lordaeron | ruínas de uma cidade humana queimada: ruas quebradas, muros caídos, praças, uma torre, escadas para uma cripta, vegetação doentia entre as pedras

Entregue só os 3 PNGs (sem TGA: eu converto). Diga o caminho de cada arquivo e qual referência você seguiu.
```

## Depois que os PNGs chegarem
1. Converto para TGA 32 bits, 512×256, com alfa e centralizado (o mesmo processo do Salão dos Thanes).
2. Ligo no `ZC.INSTANCE_ART` com o ID de cada uma.
3. Acrescento nome em en/pt/fr em `C.INSTANCE_NAMES` e no grupo de masmorras do Cartógrafo.
4. Rodo o `checks.js` e copio para o Forever.
