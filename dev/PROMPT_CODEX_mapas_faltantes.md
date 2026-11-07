# Todos os mapas de instância que faltam: um prompt para o Codex

IDs lidos da tabela `Map` do Wago (build 1.60.1.70862, a do jogo). Nomes em português lidos do jogo. Os 4 mapas já feitos (Salão dos Thanes, Ruínas de Lordaeron, Sítio de Escavação, Dalaran) ficam de fora.

## Os 10 mapas

**Masmorras novas do Forever (5)**
| Arquivo | Instância (pt-BR) | Nível | ID |
|---|---|---|---|
| map_drowned_city | The Drowned City (A Cidade Afogada) | 35-40 | 2970 |
| map_kroldok | Krol'dok Stronghold (Fortaleza de Krol'Dok) | 40-45 | 3039 |
| map_alcaz_prison | Alcaz Prison (Prisão de Alcaz) | 48-53 | 2994 |
| map_blackmaw_hold | Blackmaw Hold (Gruta Bocanera) | 55-60 | 2974 |
| map_shapers_terrace | The Shaper's Terrace (O Terraço do Moldador) | 58-60 | 3001 |

**Campos de batalha (2)**
| Arquivo | Instância | ID |
|---|---|---|
| map_gilneas_bg | Battle for Gilneas | 3005 |
| map_darkspear_bg | Darkspear Islands | 2997 |

**Fora do anúncio das 9 masmorras, mas presentes na tabela (3)**
| Arquivo | Instância | ID |
|---|---|---|
| map_demon_fall_canyon | Demon Fall Canyon | 2784 |
| map_karazhan_crypts | Karazhan Crypts | 2875 |
| map_scarlet_enclave | Scarlet Enclave | 2856 |

Faltam ainda as raides **Hyjal Summit** e **Barrow Deeps**: não estão na tabela desta build (abrem em 9 de dezembro). Ficam para depois.

Não entram: Deadwind Pass, Dalaran City, Hyjal Crater, The Searing Basin, Shadow Hold, Burning of Andorhal, Starfall Barrow Den, The Scarab Dais, Naxxramas (2921) e Manor Mistmantle. São cenários, zonas ou versões especiais, não masmorras do catálogo. Se algum for importante, avise.

**Anexe:** o Salão dos Thanes, a Excavation Site e a Dalaran (já convertidos) e duas plantas clássicas (Scholomance, Sunken Temple). Para os campos de batalha, anexe também a planta de Warsong Gulch (`map_warsong`).

```
Continue os mapas de instância do Skald (addon de World of Warcraft). Anexei as plantas que já existem: faça 10 novas no MESMO estilo, paleta e acabamento delas.

REFERÊNCIA: para cada instância, use uma planta REAL do jogo (mapa oficial, wiki ou guia) como base da disposição das salas, pátios e caminhos, e redesenhe tudo no nosso traço, sem decalcar e sem inventar salas a partir do nome. Diga qual referência usou.

ESTILO: PLANTA vista de cima, como um mapa de masmorra desenhado à mão. Salas, corredores e câmaras em corte, em tinta marrom escura com hachuras finas e lavados leves de aquarela; luz do alto à esquerda. A rocha, a água ou o terreno em volta esmaecem até o transparente. Pequenos desenhos de colunas, pontes, portões, braseiros e móveis dão vida. SEM nenhum texto, letra ou número; sem moldura.

CAMPOS DE BATALHA (map_gilneas_bg e map_darkspear_bg): uma planta do campo inteiro como um plano de batalha antigo, com as duas bases em pontas opostas marcadas por duas pequenas bandeiras de cor diferente e discreta (azul-acinzentado e vermelho-ocre), sem letras.

FUNDO (importante): ALFA REAL. Fora da planta, o fundo é totalmente transparente: nada de branco, papel, mancha, sombra quadrada ou degradê de fundo. As bordas se dissolvem até o transparente, com cerca de 6% de folga, e a planta fica centralizada.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px. Salve em output/forever-art/ com o nome do arquivo.

AS 10 INSTÂNCIAS (arquivo | instância | referência a usar):
- map_drowned_city | The Drowned City (35-40) | uma cidade submersa/afundada em Stranglethorn Vale
- map_kroldok | Krol'dok Stronghold (40-45) | uma fortaleza em Riverglades
- map_alcaz_prison | Alcaz Prison (48-53) | uma prisão na Ilha Alcaz, perto de Dustwallow Marsh
- map_blackmaw_hold | Blackmaw Hold (55-60) | uma fortaleza de furbolgs no norte de Azshara; grande, maior que Blackrock Depths
- map_shapers_terrace | The Shaper's Terrace (58-60) | Un'Goro Crater: uma grande área aberta com um poço de piche e o Pillar of Assimilation no centro
- map_gilneas_bg | Battle for Gilneas | campo de batalha na cidade de Gilneas
- map_darkspear_bg | Darkspear Islands | campo de batalha nas Ilhas Lança Sombria
- map_demon_fall_canyon | Demon Fall Canyon | um cânion fundo em Ashenvale com trilhas e plataformas
- map_karazhan_crypts | Karazhan Crypts | catacumbas sob a torre, em Deadwind Pass
- map_scarlet_enclave | Scarlet Enclave | uma área escarlate em Eastern Plaguelands

Entregue só os 10 PNGs (sem TGA: eu converto). Diga o caminho de cada arquivo e qual referência você seguiu.
```

## Depois que os PNGs chegarem
1. Converto para TGA 32 bits, 512×256, com alfa (o mesmo processo das outras).
2. Ligo cada ID no `ZC.INSTANCE_ART`, ponho os nomes en/pt/fr em `C.INSTANCE_NAMES`, e os dois campos de batalha em `C.BGS`.
3. Confiro os IDs dos campos de batalha: eles precisam aparecer como campos de batalha no jogo (`GetInstanceInfo`) para o Índice usar a planta.
4. Rodo o `checks.js` e copio para o Forever.
