# Inventário de mapas de instâncias — 07/11/2026

Comparação de `ZC.INSTANCE_ART` em `ZoneCard.lua`, `C.INSTANCE_NAMES`/grupos do Cartógrafo, arquivos em `Textures/skald2/` e o lote planejado em `dev/PROMPT_CODEX_mapas_instancias_classic.md`.

## Estado após a integração dos dez PNGs — 07/11/2026

- Catálogo atual: **44 artes**, distribuídas em **30 masmorras, 8 raides e 6 campos de batalha**. Os dez TGAs novos existem em 512×256, 32 bits, com alfa visível.
- As nove masmorras anunciadas do Forever têm arte e cadastro. Gilneas e Darkspear estão no grupo de campos de batalha. Demon Fall Canyon e Karazhan Crypts estão em masmorras; **Scarlet Enclave está em raides**, conforme sua [classificação publicada pela Blizzard](https://worldofwarcraft.blizzard.com/en-us/news/24188044).
- Darkspear usa **Ilhas Lançanegra** em português e **Îles des Sombrelances** em francês, conforme os artigos oficiais em [pt-BR](https://worldofwarcraft.blizzard.com/pt-br/news/24307308/combatti-per-le-darkspear-islands-in-world-of-warcraft-forever) e [fr-FR](https://worldofwarcraft.blizzard.com/fr-fr/news/24307308). Os demais nomes novos em francês ainda precisam de revisão; Blackmaw Hold mantém o nome inglês como alternativa provisória.
- Os IDs da tabela `Map` ainda precisam de conferência dentro das instâncias com `/skald probe maps`, exceto o Salão dos Thanes, já lido no jogo. Cadastro no cliente não comprova disponibilidade para entrar ou enfrentar chefes no Forever.
- Pendências de arte: Demon Fall representa apenas o cânion e a entrada da gruta; falta referência do subsolo. Karazhan e Scarlet Enclave usam plantas de SoD para os interiores e precisam de conferência no Forever. Darkspear foi girada 90° como um todo para o formato horizontal; sua posição não deve ser usada como orientação norte/sul.
- Hyjal Summit, Barrow Deeps e a coleção de instâncias de TBC continuam pendentes.

O levantamento abaixo registra a situação **anterior à integração**; os números e ausências históricos não descrevem o catálogo atual.

## O que já existe

- 19 masmorras clássicas, 7 raides clássicas e 4 campos de batalha do lote original.
- Hall of Thanes: `map_hall_of_thanes.tga`, ID 3065. Cadastrada no Índice e no Cartógrafo, com nomes nos três idiomas. TGA validado: 512×256, 32 bits, alpha visível.
- Total: 31 artes de instâncias. Nenhuma referência cadastrada aponta para um arquivo ausente.
- As alas de Monastério Escarlate, Gládio Cruel e Pico da Rocha Negra são representadas pelos mapas agrupados do lote original; não são peças separadas.

## Forever: oito novas masmorras ainda sem arte e cadastro

O anúncio oficial apresenta nove novas masmorras. Só Hall of Thanes está no catálogo atual do addon. Comparação com a [lista oficial da Blizzard](https://worldofwarcraft.blizzard.com/en-us/news/24301455):

| Masmorra | Faixa anunciada | Situação no addon |
| --- | --- | --- |
| Ruins of Lordaeron | 15–20 | Sem arte/cadastro de instância |
| Excavation Site — Wetlands | 24–29 | Sem arte/cadastro de instância |
| City of Dalaran | 28–33 | Sem arte/cadastro de instância |
| The Drowned City | 35–40 | Sem arte/cadastro de instância |
| Krol’dok Stronghold | 40–45 | Sem arte/cadastro de instância |
| Alcaz Prison | 48–53 | Sem arte/cadastro de instância |
| Blackmaw Hold | 55–60 | Sem arte/cadastro de instância |
| Shaper’s Terrace | 58–60 | Sem arte/cadastro de instância |

São ausências de cobertura, não arquivos perdidos de mapas já cadastrados. Os nomes e faixas seguem o anúncio consultado; o cliente deve confirmar nomes e IDs antes da integração.

Para cada peça: obter referência real da planta e o resultado de `/skald probe maps` dentro da instância; desenhar seguindo as referências do conjunto; exportar TGA 32 bits com alpha e dimensões de potência de dois; cadastrar o ID em `ZC.INSTANCE_ART`, os nomes em `C.INSTANCE_NAMES`, atualizar os checks e conferir no jogo. Não inventar IDs, disposição de salas ou corredores a partir da descrição da aventura.

## Outras coberturas que continuam pendentes

- As novas raides anunciadas para Forever, **Hyjal Summit** e **Barrow Deeps**, também não têm arte de instância no catálogo. A existência de `map_hyjal` representa o mapa da zona e não comprova uma planta de raide. Fonte: [recapitulação oficial da Blizzard](https://worldofwarcraft.blizzard.com/en-us/news/24303862/world-of-warcraft-forever-whats-next).
- Masmorras e raides de TBC ainda não têm coleção própria de plantas. As artes de Terralém existentes são de zonas/cidades. O próprio plano do lote Classic deixou as peças de TBC para uma etapa posterior.

Este levantamento não acrescentou mapas provisórios nem mudou o catálogo. A próxima masmorra na sequência de níveis anunciada é Ruins of Lordaeron.

## Atualização: IDs de instância (tabela Map do Wago, build 1.60.1.70862)

Fonte: CSV da tabela `Map` da mesma build do jogo. Confirma 2959, 2998, 2999 e 3065. Sem arte ainda: The Drowned City 2970, Blackmaw Hold 2974, Alcaz Prison 2994, The Shaper's Terrace 3001, Krol'dok Stronghold 3039. Hyjal Summit e Barrow Deeps não estão na build.
Outras linhas com tipo de instância na mesma tabela, ainda sem arte e fora do anúncio das 9 masmorras: Battle for Gilneas 3005 e Darkspear Islands 2997 (campos de batalha, tipo 3), Demon Fall Canyon 2784, Karazhan Crypts 2875, Scarlet Enclave 2856.
